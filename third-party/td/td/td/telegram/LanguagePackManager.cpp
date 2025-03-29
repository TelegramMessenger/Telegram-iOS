//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/LanguagePackManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/db/DbKey.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteKeyValue.h"

#include "td/utils/algorithm.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <atomic>
#include <limits>
#include <map>
#include <utility>

namespace td {

struct LanguagePackManager::PluralizedString {
  string zero_value_;
  string one_value_;
  string two_value_;
  string few_value_;
  string many_value_;
  string other_value_;

  PluralizedString(string &&zero_value, string &&one_value, string &&two_value, string &&few_value, string &&many_value,
                   string &&other_value)
      : zero_value_(std::move(zero_value))
      , one_value_(std::move(one_value))
      , two_value_(std::move(two_value))
      , few_value_(std::move(few_value))
      , many_value_(std::move(many_value))
      , other_value_(std::move(other_value)) {
  }
};

struct LanguagePackManager::Language {
  std::mutex mutex_;
  std::atomic<int32> version_{-1};
  std::atomic<int32> key_count_{0};
  std::string base_language_code_;
  bool is_full_ = false;
  bool was_loaded_full_ = false;
  bool has_get_difference_query_ = false;
  vector<Promise<Unit>> get_difference_queries_;
  FlatHashMap<string, string> ordinary_strings_;
  FlatHashMap<string, unique_ptr<PluralizedString>> pluralized_strings_;
  FlatHashSet<string> deleted_strings_;
  SqliteKeyValue kv_;  // usages must be guarded by database_->mutex_
};

struct LanguagePackManager::LanguageInfo {
  string name_;
  string native_name_;
  string base_language_code_;
  string plural_code_;
  bool is_official_ = false;
  bool is_rtl_ = false;
  bool is_beta_ = false;
  bool is_from_database_ = false;
  int32 total_string_count_ = 0;  // TODO move to LanguagePack and calculate as max(total_string_count)
  int32 translated_string_count_ = 0;
  string translation_url_;

  friend bool operator==(const LanguageInfo &lhs, const LanguageInfo &rhs) {
    return lhs.name_ == rhs.name_ && lhs.native_name_ == rhs.native_name_ &&
           lhs.base_language_code_ == rhs.base_language_code_ && lhs.plural_code_ == rhs.plural_code_ &&
           lhs.is_official_ == rhs.is_official_ && lhs.is_rtl_ == rhs.is_rtl_ && lhs.is_beta_ == rhs.is_beta_ &&
           lhs.total_string_count_ == rhs.total_string_count_ &&
           lhs.translated_string_count_ == rhs.translated_string_count_ && lhs.translation_url_ == rhs.translation_url_;
  }
};

struct LanguagePackManager::LanguagePack {
  std::mutex mutex_;
  SqliteKeyValue pack_kv_;                                              // usages must be guarded by database_->mutex_
  std::map<string, LanguageInfo> custom_language_pack_infos_;           // sorted by language_code
  vector<std::pair<string, LanguageInfo>> server_language_pack_infos_;  // sorted by server
  FlatHashMap<string, unique_ptr<LanguageInfo>> all_server_language_pack_infos_;
  FlatHashMap<string, unique_ptr<Language>> languages_;
};

struct LanguagePackManager::LanguageDatabase {
  std::mutex mutex_;
  string path_;
  SqliteDb database_;
  FlatHashMap<string, unique_ptr<LanguagePack>> language_packs_;
};

LanguagePackManager::~LanguagePackManager() = default;

bool LanguagePackManager::check_language_pack_name(Slice name) {
  for (auto c : name) {
    if (c != '_' && !is_alpha(c)) {
      return false;
    }
  }
  return name.size() <= 64;
}

bool LanguagePackManager::check_language_code_name(Slice name) {
  for (auto c : name) {
    if (c != '-' && !is_alpha(c) && !is_digit(c)) {
      return false;
    }
  }
  return name.size() <= 64 && (is_custom_language_code(name) || name.empty() || name.size() >= 2);
}

bool LanguagePackManager::is_custom_language_code(Slice language_code) {
  return !language_code.empty() && language_code[0] == 'X';
}

static Result<SqliteDb> open_database(const string &path) {
  TRY_RESULT(database, SqliteDb::open_with_key(path, true, DbKey::empty()));
  TRY_STATUS(database.exec("PRAGMA journal_mode=WAL"));
  return std::move(database);
}

static int32 load_database_language_version(SqliteKeyValue *kv) {
  CHECK(kv != nullptr);
  if (kv->empty()) {
    return -1;
  }
  string str_version = kv->get("!version");
  if (str_version.empty()) {
    return -1;
  }

  return to_integer<int32>(str_version);
}

static int32 load_database_language_key_count(SqliteKeyValue *kv) {
  CHECK(kv != nullptr);
  if (kv->empty()) {
    return 0;
  }
  string str_key_count = kv->get("!key_count");
  if (str_key_count.empty()) {
    // calculate key count once for the database and cache it
    int key_count = 0;
    for (auto &str : kv->get_all()) {
      key_count += str.first[0] != '!' && (str.second[0] == '1' || str.second[0] == '2');
    }
    LOG(INFO) << "Set language pack key count in database to " << key_count;
    kv->set("!key_count", to_string(key_count));
    return key_count;
  }

  return to_integer<int32>(str_key_count);
}

static string load_database_language_base_language_code(SqliteKeyValue *kv) {
  CHECK(kv != nullptr);
  if (kv->empty()) {
    return string();
  }
  return kv->get("!base_language_code");
}

LanguagePackManager::LanguageDatabase *LanguagePackManager::add_language_database(string path) {
  auto it = language_databases_.find(path);
  if (it != language_databases_.end()) {
    return it->second.get();
  }

  SqliteDb database;
  if (!path.empty()) {
    auto r_database = open_database(path);
    if (r_database.is_error()) {
      LOG(ERROR) << "Can't open language pack database " << path << ": " << r_database.error();
      return add_language_database(string());
    }

    database = r_database.move_as_ok();
  }

  it = language_databases_.emplace(path, make_unique<LanguageDatabase>()).first;
  it->second->path_ = std::move(path);
  it->second->database_ = std::move(database);
  return it->second.get();
}

LanguagePackManager::LanguagePackManager(ActorShared<> parent) : parent_(std::move(parent)) {
  std::lock_guard<std::mutex> database_lock(language_database_mutex_);
  manager_count_++;
  language_pack_ = G()->get_option_string("localization_target");
  language_code_ = G()->get_option_string("language_pack_id");
  CHECK(check_language_pack_name(language_pack_));
  CHECK(check_language_code_name(language_code_));

  database_ = add_language_database(G()->get_option_string("language_pack_database_path"));
  if (!language_pack_.empty() && !language_code_.empty()) {
    auto language = add_language(database_, language_pack_, language_code_);

    std::lock_guard<std::mutex> language_lock(language->mutex_);
    base_language_code_ = language->base_language_code_;
    if (!check_language_code_name(base_language_code_)) {
      LOG(ERROR) << "Have invalid base language pack ID \"" << base_language_code_ << '"';
      base_language_code_.clear();
    }
    if (!base_language_code_.empty()) {
      add_language(database_, language_pack_, base_language_code_);
    }

    LOG(INFO) << "Use localization target \"" << language_pack_ << "\" with language pack \"" << language_code_
              << "\" based on \"" << base_language_code_ << "\" of version " << language->version_.load()
              << " with database \"" << database_->path_ << '"';
  }
}

void LanguagePackManager::start_up() {
  if (language_pack_.empty() || language_code_.empty()) {
    return;
  }

  auto language = get_language(database_, language_pack_, language_code_);
  CHECK(language != nullptr);
  if (language->version_ == -1) {
    load_empty_language_pack(language_code_);
  }
  repair_chosen_language_info();

  if (!base_language_code_.empty()) {
    auto base_language = get_language(database_, language_pack_, base_language_code_);
    CHECK(base_language != nullptr);
    if (base_language->version_ == -1) {
      load_empty_language_pack(base_language_code_);
    }
  }

  on_language_pack_version_changed(false, -1);
  on_language_pack_version_changed(true, -1);
}

void LanguagePackManager::tear_down() {
  if (ExitGuard::is_exited()) {
    return;
  }
  std::lock_guard<std::mutex> lock(language_database_mutex_);
  manager_count_--;
  if (manager_count_ == 0) {
    // can't clear language packs, because they can be accessed later using synchronous requests
    // LOG(INFO) << "Clear language packs";
    // language_databases_.clear();
  }
}

string LanguagePackManager::get_main_language_code() {
  if (language_pack_.empty() || language_code_.empty()) {
    return "en";
  }
  if (language_code_.size() == 2) {
    return language_code_;
  }

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());

  LanguageInfo *info = nullptr;
  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> languages_lock(pack->mutex_);
  if (is_custom_language_code(language_code_)) {
    auto custom_it = pack->custom_language_pack_infos_.find(language_code_);
    if (custom_it != pack->custom_language_pack_infos_.end()) {
      info = &custom_it->second;
    }
  } else {
    for (auto &server_info : pack->server_language_pack_infos_) {
      if (server_info.first == language_code_) {
        info = &server_info.second;
      }
    }
  }

  if (info == nullptr) {
    LOG(INFO) << "Failed to find information about chosen language " << language_code_
              << ", ensure that valid language pack ID is used";
    if (!is_custom_language_code(language_code_)) {
      get_languages(false, Auto());
    }
  } else {
    if (!info->base_language_code_.empty()) {
      return info->base_language_code_;
    }
    if (!info->plural_code_.empty()) {
      return info->plural_code_;
    }
  }
  return "en";
}

vector<string> LanguagePackManager::get_used_language_codes() {
  if (language_pack_.empty() || language_code_.empty()) {
    return {};
  }

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());

  LanguageInfo *info = nullptr;
  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> languages_lock(pack->mutex_);
  if (is_custom_language_code(language_code_)) {
    auto custom_it = pack->custom_language_pack_infos_.find(language_code_);
    if (custom_it != pack->custom_language_pack_infos_.end()) {
      info = &custom_it->second;
    }
  } else {
    for (auto &server_info : pack->server_language_pack_infos_) {
      if (server_info.first == language_code_) {
        info = &server_info.second;
      }
    }
  }

  vector<string> result;
  if (language_code_.size() == 2) {
    result.push_back(language_code_);
  }
  if (info == nullptr) {
    LOG(INFO) << "Failed to find information about chosen language " << language_code_
              << ", ensure that valid language pack ID is used";
    if (!is_custom_language_code(language_code_)) {
      get_languages(false, Auto());
    }
  } else {
    if (!info->base_language_code_.empty()) {
      result.push_back(info->base_language_code_);
    }
    if (!info->plural_code_.empty()) {
      result.push_back(info->plural_code_);
    }
  }
  return result;
}

void LanguagePackManager::on_language_pack_changed() {
  auto new_language_pack = G()->get_option_string("localization_target");
  if (new_language_pack == language_pack_) {
    return;
  }

  language_pack_ = std::move(new_language_pack);
  CHECK(check_language_pack_name(language_pack_));
  inc_generation();
}

void LanguagePackManager::on_language_code_changed() {
  auto new_language_code = G()->get_option_string("language_pack_id");
  if (new_language_code == language_code_) {
    return;
  }

  language_code_ = std::move(new_language_code);
  CHECK(check_language_code_name(language_code_));
  inc_generation();
}

void LanguagePackManager::on_language_pack_version_changed(bool is_base, int32 new_version) {
  if (language_pack_.empty() || language_code_.empty()) {
    return;
  }

  Language *language = get_language(database_, language_pack_, language_code_);
  int32 version = language == nullptr ? static_cast<int32>(-1) : language->version_.load();
  LOG(INFO) << (is_base ? "Base" : "Main") << " language pack version has changed from main " << version << " to "
            << new_version;
  if (version == -1) {
    return load_empty_language_pack(language_code_);
  }

  if (new_version < 0) {
    Slice version_key = is_base ? Slice("base_language_pack_version") : Slice("language_pack_version");
    new_version = narrow_cast<int32>(G()->get_option_integer(version_key, -1));
  }
  if (new_version <= 0) {
    return;
  }

  string language_code;
  if (is_base) {
    language_code = base_language_code_;
    if (language_code.empty()) {
      LOG(ERROR) << "Have no base language, but received new version " << new_version;
      return;
    }
    language = get_language(database_, language_pack_, language_code);
    version = language == nullptr ? static_cast<int32>(-1) : language->version_.load();
    if (version == -1) {
      return load_empty_language_pack(language_code);
    }
  } else {
    language_code = language_code_;
  }
  if (is_custom_language_code(language_code) || new_version <= version) {
    return;
  }

  LOG(INFO) << (is_base ? "Base" : "Main") << " language pack " << language_code << " version has changed to "
            << new_version;
  send_language_get_difference_query(language, std::move(language_code), version, Auto());
}

void LanguagePackManager::send_language_get_difference_query(Language *language, string language_code, int32 version,
                                                             Promise<Unit> &&promise) {
  std::lock_guard<std::mutex> lock(language->mutex_);
  language->get_difference_queries_.push_back(std::move(promise));
  if (language->has_get_difference_query_) {
    return;
  }

  CHECK(language->get_difference_queries_.size() == 1);
  language->has_get_difference_query_ = true;
  auto request_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_, language_code,
                              from_version = version](Result<NetQueryPtr> r_query) mutable {
        auto r_result = fetch_result<telegram_api::langpack_getDifference>(std::move(r_query));
        if (r_result.is_error()) {
          send_closure(actor_id, &LanguagePackManager::on_failed_get_difference, std::move(language_pack),
                       std::move(language_code), r_result.move_as_error());
          return;
        }

        auto result = r_result.move_as_ok();
        LOG(INFO) << "Receive language pack difference for language pack " << result->lang_code_ << " from version "
                  << result->from_version_ << " with version " << result->version_ << " of size "
                  << result->strings_.size();
        to_lower_inplace(result->lang_code_);
        LOG_IF(ERROR, result->lang_code_ != language_code)
            << "Receive strings for " << result->lang_code_ << " instead of " << language_code;
        LOG_IF(ERROR, result->from_version_ != from_version)
            << "Receive strings from " << result->from_version_ << " instead of " << from_version;
        send_closure(actor_id, &LanguagePackManager::on_get_language_pack_strings, std::move(language_pack),
                     std::move(language_code), result->version_, true, vector<string>(), std::move(result->strings_),
                     Promise<td_api::object_ptr<td_api::languagePackStrings>>());
      });
  send_with_promise(G()->net_query_creator().create_unauth(
                        telegram_api::langpack_getDifference(language_pack_, language_code, version)),
                    std::move(request_promise));
}

void LanguagePackManager::on_language_pack_too_long(string language_code) {
  if (language_code == language_code_) {
    return on_language_pack_version_changed(false, std::numeric_limits<int32>::max());
  }
  if (language_code == base_language_code_) {
    return on_language_pack_version_changed(true, std::numeric_limits<int32>::max());
  }
  LOG(WARNING) << "Receive languagePackTooLong for language " << language_code << ", but use language "
               << language_code_ << " with base language " << base_language_code_;
}

void LanguagePackManager::on_update_language_pack(tl_object_ptr<telegram_api::langPackDifference> difference) {
  LOG(INFO) << "Receive update language pack difference for language pack " << difference->lang_code_
            << " from version " << difference->from_version_ << " with version " << difference->version_ << " of size "
            << difference->strings_.size();
  to_lower_inplace(difference->lang_code_);
  if (language_code_.empty()) {
    LOG(INFO) << "Ignore difference for language pack " << difference->lang_code_
              << ", because have no used language pack";
    return;
  }
  if (language_pack_.empty()) {
    LOG(WARNING) << "Ignore difference for language pack " << difference->lang_code_
                 << ", because localization target is not set";
    return;
  }
  if (difference->lang_code_ != language_code_ && difference->lang_code_ != base_language_code_) {
    LOG(WARNING) << "Ignore difference for language pack " << difference->lang_code_ << ", because using language pack "
                 << language_code_ << " based on " << base_language_code_;
    return;
  }
  if (is_custom_language_code(difference->lang_code_) || difference->lang_code_.empty()) {
    LOG(ERROR) << "Ignore difference for language pack " << difference->lang_code_;
    return;
  }

  Language *language = get_language(database_, language_pack_, difference->lang_code_);
  int32 version = language == nullptr ? static_cast<int32>(-1) : language->version_.load();
  if (difference->version_ <= version) {
    LOG(INFO) << "Skip applying already applied language pack updates";
    return;
  }
  if (version == -1 || version < difference->from_version_) {
    LOG(INFO) << "Can't apply language pack difference";
    return on_language_pack_version_changed(difference->lang_code_ != language_code_, difference->version_);
  }

  on_get_language_pack_strings(language_pack_, std::move(difference->lang_code_), difference->version_, true,
                               vector<string>(), std::move(difference->strings_),
                               Promise<td_api::object_ptr<td_api::languagePackStrings>>());
}

void LanguagePackManager::inc_generation() {
  G()->set_option_empty("language_pack_version");
  G()->set_option_empty("base_language_pack_version");

  if (!language_pack_.empty() && !language_code_.empty()) {
    LOG(INFO) << "Add main language " << language_code_;
    CHECK(check_language_code_name(language_code_));
    auto language = add_language(database_, language_pack_, language_code_);
    on_language_pack_version_changed(false, std::numeric_limits<int32>::max());
    repair_chosen_language_info();

    {
      std::lock_guard<std::mutex> lock(language->mutex_);
      base_language_code_ = language->base_language_code_;
    }
    if (!check_language_code_name(base_language_code_)) {
      LOG(ERROR) << "Have invalid base language pack ID \"" << base_language_code_ << '"';
      base_language_code_.clear();
    }
    if (!base_language_code_.empty()) {
      CHECK(base_language_code_ != language_code_);
      LOG(INFO) << "Add base language " << base_language_code_;
      add_language(database_, language_pack_, base_language_code_);
      on_language_pack_version_changed(true, std::numeric_limits<int32>::max());
    }
  }
  LOG(INFO) << "Finished to apply new language pack";
}

LanguagePackManager::Language *LanguagePackManager::get_language(LanguageDatabase *database,
                                                                 const string &language_pack,
                                                                 const string &language_code) {
  std::unique_lock<std::mutex> lock(database->mutex_);
  auto it = database->language_packs_.find(language_pack);
  if (it == database->language_packs_.end()) {
    return nullptr;
  }
  LanguagePack *pack = it->second.get();
  lock.unlock();
  return get_language(pack, language_code);
}

LanguagePackManager::Language *LanguagePackManager::get_language(LanguagePack *language_pack,
                                                                 const string &language_code) {
  CHECK(language_pack != nullptr);
  std::lock_guard<std::mutex> lock(language_pack->mutex_);
  auto it = language_pack->languages_.find(language_code);
  if (it == language_pack->languages_.end()) {
    return nullptr;
  }
  return it->second.get();
}

static string get_database_table_name(const string &language_pack, const string &language_code) {
  return PSTRING() << "\"kv_" << language_pack << '_' << language_code << '"';
}

LanguagePackManager::Language *LanguagePackManager::add_language(LanguageDatabase *database,
                                                                 const string &language_pack,
                                                                 const string &language_code) {
  std::lock_guard<std::mutex> packs_lock(database->mutex_);
  auto pack_it = database->language_packs_.find(language_pack);
  if (pack_it == database->language_packs_.end()) {
    auto pack = make_unique<LanguagePack>();
    if (!database->database_.empty()) {
      pack->pack_kv_.init_with_connection(database->database_.clone(), get_database_table_name(language_pack, "0"))
          .ensure();
      bool need_drop_server = false;
      for (auto &lang : pack->pack_kv_.get_all()) {
        auto as_bool = [](Slice data) {
          if (data == "true") {
            return true;
          }
          if (data != "false") {
            LOG(ERROR) << "Have invalid boolean value \"" << data << "\" in the database";
          }
          return false;
        };

        if (lang.first == "!server") {
          // legacy info format, drop cache
          need_drop_server = true;
          continue;
        }
        if (lang.first == "!server2") {
          auto all_infos = full_split(lang.second, '\x00');
          if (all_infos.size() % 11 == 0) {
            for (size_t i = 0; i < all_infos.size(); i += 11) {
              if (all_infos[i].empty()) {
                LOG(ERROR) << "Have empty info about a language pack";
                continue;
              }
              LanguageInfo info;
              info.name_ = std::move(all_infos[i + 1]);
              info.native_name_ = std::move(all_infos[i + 2]);
              info.base_language_code_ = std::move(all_infos[i + 3]);
              info.plural_code_ = std::move(all_infos[i + 4]);
              info.is_official_ = as_bool(all_infos[i + 5]);
              info.is_rtl_ = as_bool(all_infos[i + 6]);
              info.is_beta_ = as_bool(all_infos[i + 7]);
              info.is_from_database_ = true;
              info.total_string_count_ = to_integer<int32>(all_infos[i + 8]);
              info.translated_string_count_ = to_integer<int32>(all_infos[i + 9]);
              info.translation_url_ = std::move(all_infos[i + 10]);
              pack->all_server_language_pack_infos_.emplace(all_infos[i], td::make_unique<LanguageInfo>(info));
              pack->server_language_pack_infos_.emplace_back(std::move(all_infos[i]), std::move(info));
            }
          } else {
            LOG(ERROR) << "Have wrong language pack info \"" << lang.second << "\" in the database";
          }
          continue;
        }

        auto all_infos = full_split(lang.second, '\x00');
        if (all_infos.size() < 2) {
          LOG(ERROR) << "Have wrong custom language pack info \"" << lang.second << '"';
          continue;
        }
        auto &info = pack->custom_language_pack_infos_[lang.first];
        info.name_ = std::move(all_infos[0]);
        info.native_name_ = std::move(all_infos[1]);
        if (all_infos.size() > 2) {
          CHECK(all_infos.size() == 10);
          info.base_language_code_ = std::move(all_infos[2]);
          info.plural_code_ = std::move(all_infos[3]);
          info.is_official_ = as_bool(all_infos[4]);
          info.is_rtl_ = as_bool(all_infos[5]);
          info.is_beta_ = as_bool(all_infos[6]);
          info.total_string_count_ = to_integer<int32>(all_infos[7]);
          info.translated_string_count_ = to_integer<int32>(all_infos[8]);
          info.translation_url_ = std::move(all_infos[9]);
        }
        info.is_from_database_ = true;
      }
      if (need_drop_server) {
        LOG(INFO) << "Drop old server language pack info cache";
        pack->pack_kv_.erase("!server");
      }
    }
    pack_it = database->language_packs_.emplace(language_pack, std::move(pack)).first;
  }
  LanguagePack *pack = pack_it->second.get();

  std::lock_guard<std::mutex> languages_lock(pack->mutex_);
  auto code_it = pack->languages_.find(language_code);
  if (code_it == pack->languages_.end()) {
    auto language = make_unique<Language>();
    if (!database->database_.empty()) {
      language->kv_
          .init_with_connection(database->database_.clone(), get_database_table_name(language_pack, language_code))
          .ensure();
      language->version_ = load_database_language_version(&language->kv_);
      language->key_count_ = load_database_language_key_count(&language->kv_);
      language->base_language_code_ = load_database_language_base_language_code(&language->kv_);
      LOG(INFO) << "Loaded language " << language_code << " with version " << language->version_.load()
                << ", key count " << language->key_count_.load() << " and base language "
                << language->base_language_code_;
    }
    code_it = pack->languages_.emplace(language_code, std::move(language)).first;
  }
  return code_it->second.get();
}

bool LanguagePackManager::language_has_string_unsafe(const Language *language, const string &key) {
  return language->ordinary_strings_.count(key) != 0 || language->pluralized_strings_.count(key) != 0 ||
         language->deleted_strings_.count(key) != 0;
}

bool LanguagePackManager::language_has_strings(Language *language, const vector<string> &keys) {
  if (language == nullptr) {
    return false;
  }

  std::lock_guard<std::mutex> lock(language->mutex_);
  if (language->is_full_) {
    return true;
  }
  if (keys.empty()) {
    return false;  // language is already checked to be not full
  }
  for (auto &key : keys) {
    if (!language_has_string_unsafe(language, key)) {
      return false;
    }
  }
  return true;
}

void LanguagePackManager::load_language_string_unsafe(Language *language, const string &key, const string &value) {
  CHECK(is_valid_key(key));
  if (value[0] == '1') {
    language->ordinary_strings_.emplace(key, value.substr(1));
    return;
  }

  if (value[0] == '2') {
    auto all = full_split(Slice(value).substr(1), '\x00');
    if (all.size() == 6) {
      language->pluralized_strings_.emplace(
          key, td::make_unique<PluralizedString>(all[0].str(), all[1].str(), all[2].str(), all[3].str(), all[4].str(),
                                                 all[5].str()));
      return;
    }
  }

  LOG_IF(ERROR, !value.empty() && value != "3") << "Have invalid value \"" << value << '"';
  if (!language->is_full_) {
    language->deleted_strings_.insert(key);
  }
}

bool LanguagePackManager::load_language_strings(LanguageDatabase *database, Language *language,
                                                const vector<string> &keys) {
  if (language == nullptr) {
    return false;
  }

  std::lock_guard<std::mutex> database_lock(database->mutex_);
  std::lock_guard<std::mutex> language_lock(language->mutex_);
  if (language->is_full_) {
    LOG(DEBUG) << "The language pack is already full in memory";
    return true;
  }
  if (language->kv_.empty()) {
    LOG(DEBUG) << "The language pack has no database";
    return false;
  }
  LOG(DEBUG) << "Begin to load a language pack from database";
  if (keys.empty()) {
    if (language->version_ == -1 && language->was_loaded_full_) {
      LOG(DEBUG) << "The language pack has already been loaded";
      return false;
    }

    auto all_strings = language->kv_.get_all();
    for (auto &str : all_strings) {
      if (str.first[0] == '!') {
        continue;
      }

      if (!language_has_string_unsafe(language, str.first)) {
        LOG(DEBUG) << "Load string with key " << str.first << " from database";
        load_language_string_unsafe(language, str.first, str.second);
      }
    }
    language->was_loaded_full_ = true;

    if (language->version_ == -1) {
      return false;
    }

    language->is_full_ = true;
    language->deleted_strings_.clear();
    return true;
  }

  bool have_all = true;
  for (auto &key : keys) {
    if (!language_has_string_unsafe(language, key)) {
      auto value = language->kv_.get(key);
      if (value.empty()) {
        if (language->version_ == -1) {
          LOG(DEBUG) << "Have no string with key " << key << " in the database";
          have_all = false;
          continue;
        }

        // have full language in the database, so this string is just deleted
      }
      LOG(DEBUG) << "Load string with key " << key << " from database";
      load_language_string_unsafe(language, key, value);
    }
  }
  return have_all;
}

td_api::object_ptr<td_api::LanguagePackStringValue> LanguagePackManager::get_language_pack_string_value_object(
    const string &value) {
  return td_api::make_object<td_api::languagePackStringValueOrdinary>(value);
}

td_api::object_ptr<td_api::LanguagePackStringValue> LanguagePackManager::get_language_pack_string_value_object(
    const PluralizedString &value) {
  return td_api::make_object<td_api::languagePackStringValuePluralized>(
      value.zero_value_, value.one_value_, value.two_value_, value.few_value_, value.many_value_, value.other_value_);
}

td_api::object_ptr<td_api::LanguagePackStringValue> LanguagePackManager::get_language_pack_string_value_object() {
  return td_api::make_object<td_api::languagePackStringValueDeleted>();
}

td_api::object_ptr<td_api::languagePackString> LanguagePackManager::get_language_pack_string_object(
    const string &key, const string &value) {
  return td_api::make_object<td_api::languagePackString>(key, get_language_pack_string_value_object(value));
}

td_api::object_ptr<td_api::languagePackString> LanguagePackManager::get_language_pack_string_object(
    const string &key, const PluralizedString &value) {
  return td_api::make_object<td_api::languagePackString>(key, get_language_pack_string_value_object(value));
}

td_api::object_ptr<td_api::languagePackString> LanguagePackManager::get_language_pack_string_object(const string &key) {
  return td_api::make_object<td_api::languagePackString>(key, get_language_pack_string_value_object());
}

td_api::object_ptr<td_api::LanguagePackStringValue> LanguagePackManager::get_language_pack_string_value_object(
    const Language *language, const string &key) {
  CHECK(language != nullptr);
  auto ordinary_it = language->ordinary_strings_.find(key);
  if (ordinary_it != language->ordinary_strings_.end()) {
    return get_language_pack_string_value_object(ordinary_it->second);
  }
  auto pluralized_it = language->pluralized_strings_.find(key);
  if (pluralized_it != language->pluralized_strings_.end()) {
    return get_language_pack_string_value_object(*pluralized_it->second);
  }
  LOG_IF(ERROR, !language->is_full_ && language->deleted_strings_.count(key) == 0) << "Have no string for key " << key;
  return get_language_pack_string_value_object();
}

td_api::object_ptr<td_api::languagePackString> LanguagePackManager::get_language_pack_string_object(
    const Language *language, const string &key) {
  return td_api::make_object<td_api::languagePackString>(key, get_language_pack_string_value_object(language, key));
}

td_api::object_ptr<td_api::languagePackStrings> LanguagePackManager::get_language_pack_strings_object(
    Language *language, const vector<string> &keys) {
  CHECK(language != nullptr);

  std::lock_guard<std::mutex> lock(language->mutex_);
  vector<td_api::object_ptr<td_api::languagePackString>> strings;
  if (keys.empty()) {
    for (auto &str : language->ordinary_strings_) {
      strings.push_back(get_language_pack_string_object(str.first, str.second));
    }
    for (auto &str : language->pluralized_strings_) {
      strings.push_back(get_language_pack_string_object(str.first, *str.second));
    }
  } else {
    for (auto &key : keys) {
      strings.push_back(get_language_pack_string_object(language, key));
    }
  }

  return td_api::make_object<td_api::languagePackStrings>(std::move(strings));
}

void LanguagePackManager::get_languages(bool only_local,
                                        Promise<td_api::object_ptr<td_api::localizationTargetInfo>> promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }

  if (only_local) {
    return on_get_languages(vector<tl_object_ptr<telegram_api::langPackLanguage>>(), language_pack_, true,
                            std::move(promise));
  }

  auto request_promise = PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_,
                                                 promise = std::move(promise)](Result<NetQueryPtr> r_query) mutable {
    TRY_RESULT_PROMISE(promise, result, fetch_result<telegram_api::langpack_getLanguages>(std::move(r_query)));
    send_closure(actor_id, &LanguagePackManager::on_get_languages, std::move(result), std::move(language_pack), false,
                 std::move(promise));
  });
  send_with_promise(G()->net_query_creator().create_unauth(telegram_api::langpack_getLanguages(language_pack_)),
                    std::move(request_promise));
}

void LanguagePackManager::search_language_info(string language_code,
                                               Promise<td_api::object_ptr<td_api::languagePackInfo>> promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }

  auto request_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_, language_code,
                              promise = std::move(promise)](Result<NetQueryPtr> r_query) mutable {
        TRY_RESULT_PROMISE(promise, result, fetch_result<telegram_api::langpack_getLanguage>(std::move(r_query)));
        LOG(INFO) << "Receive " << to_string(result);
        send_closure(actor_id, &LanguagePackManager::on_get_language, std::move(result), std::move(language_pack),
                     std::move(language_code), std::move(promise));
      });
  send_with_promise(
      G()->net_query_creator().create_unauth(telegram_api::langpack_getLanguage(language_pack_, language_code)),
      std::move(request_promise));
}

void LanguagePackManager::repair_chosen_language_info() {
  CHECK(!language_pack_.empty() && !language_code_.empty());
  if (is_custom_language_code(language_code_)) {
    return;
  }

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());

  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> languages_lock(pack->mutex_);
  for (auto &server_info : pack->server_language_pack_infos_) {
    if (server_info.first == language_code_) {
      return;
    }
  }

  LOG(INFO) << "Repair info about language " << language_code_;
  search_language_info(language_code_, Auto());
}

td_api::object_ptr<td_api::languagePackInfo> LanguagePackManager::get_language_pack_info_object(
    const string &language_code, const LanguageInfo &info) {
  return td_api::make_object<td_api::languagePackInfo>(language_code, info.base_language_code_, info.name_,
                                                       info.native_name_, info.plural_code_, info.is_official_,
                                                       info.is_rtl_, info.is_beta_, false, info.total_string_count_,
                                                       info.translated_string_count_, 0, info.translation_url_);
}

string LanguagePackManager::get_language_info_string(const LanguageInfo &info) {
  return PSTRING() << info.name_ << '\x00' << info.native_name_ << '\x00' << info.base_language_code_ << '\x00'
                   << info.plural_code_ << '\x00' << info.is_official_ << '\x00' << info.is_rtl_ << '\x00'
                   << info.is_beta_ << '\x00' << info.total_string_count_ << '\x00' << info.translated_string_count_
                   << '\x00' << info.translation_url_;
}

void LanguagePackManager::on_get_language_info(const string &language_pack,
                                               td_api::languagePackInfo *language_pack_info) {
  CHECK(language_pack_info != nullptr);
  auto language = add_language(database_, language_pack, language_pack_info->id_);
  language_pack_info->local_string_count_ = language->key_count_;
  SqliteKeyValue *kv = nullptr;
  bool was_updated_base_language_code = false;
  {
    std::lock_guard<std::mutex> lock(language->mutex_);
    if (language_pack_info->base_language_pack_id_ != language->base_language_code_) {
      language->base_language_code_ = language_pack_info->base_language_pack_id_;
      if (language_pack == language_pack_ && language_pack_info->id_ == language_code_) {
        base_language_code_ = language->base_language_code_;
        was_updated_base_language_code = true;
      }
      if (!language->kv_.empty()) {
        kv = &language->kv_;
      }
    }
  }
  if (was_updated_base_language_code) {
    G()->set_option_empty("base_language_pack_version");
    if (!base_language_code_.empty()) {
      add_language(database_, language_pack_, base_language_code_);
      on_language_pack_version_changed(true, std::numeric_limits<int32>::max());
    }
  }
  if (kv != nullptr) {
    std::lock_guard<std::mutex> lock(database_->mutex_);
    kv->set("!base_language_code", language_pack_info->base_language_pack_id_);
  }
}

void LanguagePackManager::save_server_language_pack_infos(LanguagePack *pack) {
  // mutexes are locked by the caller
  if (pack->pack_kv_.empty()) {
    return;
  }

  LOG(INFO) << "Save changes server language pack infos";
  vector<string> all_strings;
  all_strings.reserve(2 * pack->server_language_pack_infos_.size());
  for (auto &info : pack->server_language_pack_infos_) {
    all_strings.push_back(info.first);
    all_strings.push_back(get_language_info_string(info.second));
  }

  pack->pack_kv_.set("!server2", implode(all_strings, '\x00'));
}

void LanguagePackManager::on_get_languages(vector<tl_object_ptr<telegram_api::langPackLanguage>> languages,
                                           string language_pack, bool only_local,
                                           Promise<td_api::object_ptr<td_api::localizationTargetInfo>> promise) {
  auto results = td_api::make_object<td_api::localizationTargetInfo>();
  FlatHashSet<string> added_languages;

  auto add_language_info = [&results, &added_languages](const string &language_code, const LanguageInfo &info,
                                                        bool is_installed) {
    if (!language_code.empty() && added_languages.insert(language_code).second) {
      results->language_packs_.push_back(get_language_pack_info_object(language_code, info));
      results->language_packs_.back()->is_installed_ = is_installed;
    }
  };

  {
    std::lock_guard<std::mutex> packs_lock(database_->mutex_);
    auto pack_it = database_->language_packs_.find(language_pack);
    if (pack_it != database_->language_packs_.end()) {
      LanguagePack *pack = pack_it->second.get();
      std::lock_guard<std::mutex> pack_lock(pack->mutex_);
      for (auto &info : pack->custom_language_pack_infos_) {
        add_language_info(info.first, info.second, true);
      }
      if (only_local) {
        for (auto &info : pack->server_language_pack_infos_) {
          add_language_info(info.first, info.second, false);
        }
      }
    }
  }

  vector<std::pair<string, LanguageInfo>> all_server_infos;
  for (auto &language : languages) {
    auto r_info = get_language_info(language.get());
    if (r_info.is_error()) {
      continue;
    }

    add_language_info(language->lang_code_, r_info.ok(), false);
    all_server_infos.emplace_back(std::move(language->lang_code_), r_info.move_as_ok());
  }

  for (auto &language_pack_info : results->language_packs_) {
    on_get_language_info(language_pack, language_pack_info.get());
  }

  if (!only_local) {
    std::lock_guard<std::mutex> packs_lock(database_->mutex_);
    auto pack_it = database_->language_packs_.find(language_pack);
    if (pack_it != database_->language_packs_.end()) {
      LanguagePack *pack = pack_it->second.get();
      std::lock_guard<std::mutex> pack_lock(pack->mutex_);
      if (pack->server_language_pack_infos_ != all_server_infos) {
        for (auto &info : all_server_infos) {
          pack->all_server_language_pack_infos_[info.first] = td::make_unique<LanguageInfo>(info.second);
        }
        pack->server_language_pack_infos_ = std::move(all_server_infos);

        save_server_language_pack_infos(pack);
      }
    }
  }
  promise.set_value(std::move(results));
}

void LanguagePackManager::on_get_language(tl_object_ptr<telegram_api::langPackLanguage> lang_pack_language,
                                          string language_pack, string language_code,
                                          Promise<td_api::object_ptr<td_api::languagePackInfo>> promise) {
  CHECK(lang_pack_language != nullptr);
  TRY_RESULT_PROMISE(promise, language_info, get_language_info(lang_pack_language.get()));
  auto result = get_language_pack_info_object(lang_pack_language->lang_code_, language_info);

  on_get_language_info(language_pack, result.get());

  // updating languages cache
  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack);
  if (pack_it != database_->language_packs_.end()) {
    LanguagePack *pack = pack_it->second.get();
    std::lock_guard<std::mutex> pack_lock(pack->mutex_);

    result->is_installed_ = pack->custom_language_pack_infos_.count(lang_pack_language->lang_code_) != 0 ||
                            pack->custom_language_pack_infos_.count(language_code) != 0;

    bool is_changed = false;
    for (auto &info : pack->server_language_pack_infos_) {
      if (info.first == lang_pack_language->lang_code_ || info.first == language_code) {
        if (!(info.second == language_info)) {
          LOG(INFO) << "Language pack " << info.first << " was changed";
          is_changed = true;
          info.second = language_info;
        }
      }
    }
    pack->all_server_language_pack_infos_[lang_pack_language->lang_code_] =
        td::make_unique<LanguageInfo>(std::move(language_info));

    if (is_changed) {
      save_server_language_pack_infos(pack);
    }
  } else {
    LOG(ERROR) << "Failed to find localization target " << language_pack;
  }

  promise.set_value(std::move(result));
}

void LanguagePackManager::get_language_pack_strings(string language_code, vector<string> keys,
                                                    Promise<td_api::object_ptr<td_api::languagePackStrings>> promise) {
  if (!check_language_code_name(language_code) || language_code.empty()) {
    return promise.set_error(Status::Error(400, "Language pack ID is invalid"));
  }
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }
  for (auto &key : keys) {
    if (!is_valid_key(key)) {
      return promise.set_error(Status::Error(400, "Invalid key name"));
    }
  }

  Language *language = add_language(database_, language_pack_, language_code);
  if (language_has_strings(language, keys)) {
    return promise.set_value(get_language_pack_strings_object(language, keys));
  }
  if (load_language_strings(database_, language, keys)) {
    return promise.set_value(get_language_pack_strings_object(language, keys));
  }

  if (is_custom_language_code(language_code)) {
    return promise.set_error(Status::Error(400, "Custom language pack not found"));
  }

  if (keys.empty()) {
    auto &queries = get_all_language_pack_strings_queries_[language_pack_][language_code].queries_;
    queries.push_back(std::move(promise));
    if (queries.size() != 1) {
      // send request only once
      return;
    }

    auto result_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_, language_code](
                                   Result<td_api::object_ptr<td_api::languagePackStrings>> r_strings) mutable {
          send_closure(actor_id, &LanguagePackManager::on_get_all_language_pack_strings, std::move(language_pack),
                       std::move(language_code), std::move(r_strings));
        });
    auto request_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_, language_code,
                                promise = std::move(result_promise)](Result<NetQueryPtr> r_query) mutable {
          TRY_RESULT_PROMISE(promise, result, fetch_result<telegram_api::langpack_getLangPack>(std::move(r_query)));
          to_lower_inplace(result->lang_code_);
          LOG(INFO) << "Receive language pack " << result->lang_code_ << " from version " << result->from_version_
                    << " with version " << result->version_ << " of size " << result->strings_.size();
          LOG_IF(ERROR, result->lang_code_ != language_code)
              << "Receive strings for " << result->lang_code_ << " instead of " << language_code;
          LOG_IF(ERROR, result->from_version_ != 0) << "Receive language pack from version " << result->from_version_;
          send_closure(actor_id, &LanguagePackManager::on_get_language_pack_strings, std::move(language_pack),
                       std::move(language_code), result->version_, false, vector<string>(), std::move(result->strings_),
                       std::move(promise));
        });
    send_with_promise(
        G()->net_query_creator().create_unauth(telegram_api::langpack_getLangPack(language_pack_, language_code)),
        std::move(request_promise));
  } else {
    auto request_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), language_pack = language_pack_, language_code, keys,
                                promise = std::move(promise)](Result<NetQueryPtr> r_query) mutable {
          TRY_RESULT_PROMISE(promise, result, fetch_result<telegram_api::langpack_getStrings>(std::move(r_query)));
          send_closure(actor_id, &LanguagePackManager::on_get_language_pack_strings, std::move(language_pack),
                       std::move(language_code), -1, false, std::move(keys), std::move(result), std::move(promise));
        });
    send_with_promise(G()->net_query_creator().create_unauth(
                          telegram_api::langpack_getStrings(language_pack_, language_code, std::move(keys))),
                      std::move(request_promise));
  }
}

void LanguagePackManager::load_empty_language_pack(const string &language_code) {
  if (is_custom_language_code(language_code)) {
    return;
  }
  get_language_pack_strings(language_code, vector<string>(), Auto());
}

void LanguagePackManager::synchronize_language_pack(string language_code, Promise<Unit> promise) {
  if (!check_language_code_name(language_code) || language_code.empty()) {
    return promise.set_error(Status::Error(400, "Language pack ID is invalid"));
  }
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }
  if (is_custom_language_code(language_code)) {
    return promise.set_value(Unit());
  }

  Language *language = add_language(database_, language_pack_, language_code);
  load_language_strings(database_, language, vector<string>());

  int32 version = language->version_.load();
  if (version == -1) {
    version = 0;
  }
  send_language_get_difference_query(language, std::move(language_code), version, std::move(promise));
}

static td_api::object_ptr<td_api::LanguagePackStringValue> copy_language_pack_string_value(
    const td_api::LanguagePackStringValue *value) {
  switch (value->get_id()) {
    case td_api::languagePackStringValueOrdinary::ID: {
      auto old_value = static_cast<const td_api::languagePackStringValueOrdinary *>(value);
      return make_tl_object<td_api::languagePackStringValueOrdinary>(old_value->value_);
    }
    case td_api::languagePackStringValuePluralized::ID: {
      auto old_value = static_cast<const td_api::languagePackStringValuePluralized *>(value);
      return make_tl_object<td_api::languagePackStringValuePluralized>(
          std::move(old_value->zero_value_), std::move(old_value->one_value_), std::move(old_value->two_value_),
          std::move(old_value->few_value_), std::move(old_value->many_value_), std::move(old_value->other_value_));
    }
    case td_api::languagePackStringValueDeleted::ID:
      return make_tl_object<td_api::languagePackStringValueDeleted>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void LanguagePackManager::on_get_all_language_pack_strings(
    string language_pack, string language_code, Result<td_api::object_ptr<td_api::languagePackStrings>> r_strings) {
  auto &queries = get_all_language_pack_strings_queries_[language_pack][language_code].queries_;
  auto promises = std::move(queries);
  CHECK(!promises.empty());
  auto it = get_all_language_pack_strings_queries_.find(language_pack);
  it->second.erase(language_code);
  if (it->second.empty()) {
    get_all_language_pack_strings_queries_.erase(it);
  }

  if (r_strings.is_error()) {
    fail_promises(promises, r_strings.move_as_error());
    return;
  }

  auto strings = r_strings.move_as_ok();
  size_t left_non_empty_promise_count = 0;
  for (auto &promise : promises) {
    if (promise) {
      left_non_empty_promise_count++;
    }
  }
  for (auto &promise : promises) {
    if (promise) {
      if (left_non_empty_promise_count == 1) {
        LOG(DEBUG) << "Set last non-empty promise";
        promise.set_value(std::move(strings));
      } else {
        LOG(DEBUG) << "Set non-empty promise";
        vector<td_api::object_ptr<td_api::languagePackString>> strings_copy;
        for (auto &result : strings->strings_) {
          CHECK(result != nullptr);
          strings_copy.push_back(td_api::make_object<td_api::languagePackString>(
              result->key_, copy_language_pack_string_value(result->value_.get())));
        }
        promise.set_value(td_api::make_object<td_api::languagePackStrings>(std::move(strings_copy)));
      }
      left_non_empty_promise_count--;
    } else {
      LOG(DEBUG) << "Set empty promise";
      promise.set_value(nullptr);
    }
  }
  CHECK(left_non_empty_promise_count == 0);
}

td_api::object_ptr<td_api::Object> LanguagePackManager::get_language_pack_string(const string &database_path,
                                                                                 const string &language_pack,
                                                                                 const string &language_code,
                                                                                 const string &key) {
  if (!check_language_pack_name(language_pack) || language_pack.empty()) {
    return td_api::make_object<td_api::error>(400, "Localization target is invalid");
  }
  if (!check_language_code_name(language_code) || language_code.empty()) {
    return td_api::make_object<td_api::error>(400, "Language pack ID is invalid");
  }
  if (!is_valid_key(key)) {
    return td_api::make_object<td_api::error>(400, "Key is invalid");
  }

  std::unique_lock<std::mutex> language_databases_lock(language_database_mutex_);
  LanguageDatabase *database = add_language_database(database_path);
  CHECK(database != nullptr);
  language_databases_lock.unlock();

  Language *language = add_language(database, language_pack, language_code);
  vector<string> keys{key};
  if (language_has_strings(language, keys)) {
    std::lock_guard<std::mutex> lock(language->mutex_);
    return get_language_pack_string_value_object(language, key);
  }
  if (load_language_strings(database, language, keys)) {
    std::lock_guard<std::mutex> lock(language->mutex_);
    return get_language_pack_string_value_object(language, key);
  }
  return td_api::make_object<td_api::error>(404, "Not Found");
}

bool LanguagePackManager::is_valid_key(Slice key) {
  for (auto c : key) {
    if (!is_alnum(c) && c != '_' && c != '.' && c != '-') {
      return false;
    }
  }
  return !key.empty();
}

void LanguagePackManager::save_strings_to_database(SqliteKeyValue *kv, int32 new_version, bool new_is_full,
                                                   int32 new_key_count, vector<std::pair<string, string>> &&strings) {
  LOG(DEBUG) << "Save to database a language pack with new version " << new_version << " and " << strings.size()
             << " new strings";
  if (new_version == -1 && strings.empty()) {
    return;
  }

  std::lock_guard<std::mutex> lock(database_->mutex_);
  CHECK(kv != nullptr);
  if (kv->empty()) {
    LOG(DEBUG) << "There is no associated database key-value";
    return;
  }
  auto old_version = load_database_language_version(kv);
  if (old_version > new_version || (old_version == new_version && strings.empty())) {
    LOG(DEBUG) << "Language pack version doesn't increased from " << old_version;
    return;
  }

  kv->begin_write_transaction().ensure();
  for (const auto &str : strings) {
    if (!is_valid_key(str.first)) {
      LOG(ERROR) << "Have invalid key \"" << str.first << '"';
      continue;
    }

    if (new_is_full && str.second == "3") {
      kv->erase(str.first);
    } else {
      kv->set(str.first, str.second);
    }
    LOG(DEBUG) << "Save language pack string with key " << str.first << " to database";
  }
  if (old_version != new_version) {
    LOG(DEBUG) << "Set language pack version in database to " << new_version;
    kv->set("!version", to_string(new_version));
  }
  if (new_key_count != -1) {
    LOG(DEBUG) << "Set language pack key count in database to " << new_key_count;
    kv->set("!key_count", to_string(new_key_count));
  }
  kv->commit_transaction().ensure();
}

void LanguagePackManager::on_get_language_pack_strings(
    string language_pack, string language_code, int32 version, bool is_diff, vector<string> &&keys,
    vector<tl_object_ptr<telegram_api::LangPackString>> results,
    Promise<td_api::object_ptr<td_api::languagePackStrings>> promise) {
  Language *language = get_language(database_, language_pack, language_code);
  bool is_version_changed = false;
  int32 new_database_version = -1;
  int32 new_key_count = -1;
  bool new_is_full = false;
  vector<std::pair<string, string>> database_strings;
  if (language == nullptr || language->version_ < version || !keys.empty()) {
    if (language == nullptr) {
      language = add_language(database_, language_pack, language_code);
      CHECK(language != nullptr);
    }
    load_language_strings(database_, language, keys);

    std::lock_guard<std::mutex> lock(language->mutex_);
    int32 key_count_delta = 0;
    if (language->version_ < version || !keys.empty()) {
      auto is_first = language->version_ == -1;
      vector<td_api::object_ptr<td_api::languagePackString>> strings;
      if (language->version_ < version) {
        LOG(INFO) << "Set language pack " << language_code << " version to " << version;
        language->version_ = version;
        new_database_version = version;
        is_version_changed = true;
      }

      for (auto &result : results) {
        CHECK(result != nullptr);
        switch (result->get_id()) {
          case telegram_api::langPackString::ID: {
            auto str = telegram_api::move_object_as<telegram_api::langPackString>(result);
            if (!is_valid_key(str->key_)) {
              LOG(ERROR) << "Receive invalid key \"" << str->key_ << '"';
              break;
            }
            auto it = language->ordinary_strings_.find(str->key_);
            if (it == language->ordinary_strings_.end()) {
              key_count_delta++;
              it = language->ordinary_strings_.emplace(str->key_, std::move(str->value_)).first;
            } else {
              it->second = std::move(str->value_);
            }
            key_count_delta -= static_cast<int32>(language->pluralized_strings_.erase(str->key_));
            language->deleted_strings_.erase(str->key_);
            if (is_diff) {
              strings.push_back(get_language_pack_string_object(it->first, it->second));
            }
            database_strings.emplace_back(std::move(str->key_), PSTRING() << '1' << it->second);
            break;
          }
          case telegram_api::langPackStringPluralized::ID: {
            auto str = telegram_api::move_object_as<telegram_api::langPackStringPluralized>(result);
            if (!is_valid_key(str->key_)) {
              LOG(ERROR) << "Receive invalid key \"" << str->key_ << '"';
              break;
            }
            auto value = td::make_unique<PluralizedString>(std::move(str->zero_value_), std::move(str->one_value_),
                                                           std::move(str->two_value_), std::move(str->few_value_),
                                                           std::move(str->many_value_), std::move(str->other_value_));
            auto it = language->pluralized_strings_.find(str->key_);
            if (it == language->pluralized_strings_.end()) {
              key_count_delta++;
              it = language->pluralized_strings_.emplace(str->key_, std::move(value)).first;
            } else {
              it->second = std::move(value);
            }
            key_count_delta -= static_cast<int32>(language->ordinary_strings_.erase(str->key_));
            language->deleted_strings_.erase(str->key_);
            if (is_diff) {
              strings.push_back(get_language_pack_string_object(it->first, *it->second));
            }
            database_strings.emplace_back(
                std::move(str->key_), PSTRING()
                                          << '2' << it->second->zero_value_ << '\x00' << it->second->one_value_
                                          << '\x00' << it->second->two_value_ << '\x00' << it->second->few_value_
                                          << '\x00' << it->second->many_value_ << '\x00' << it->second->other_value_);
            break;
          }
          case telegram_api::langPackStringDeleted::ID: {
            auto str = telegram_api::move_object_as<telegram_api::langPackStringDeleted>(result);
            if (!is_valid_key(str->key_)) {
              LOG(ERROR) << "Receive invalid key \"" << str->key_ << '"';
              break;
            }
            key_count_delta -= static_cast<int32>(language->ordinary_strings_.erase(str->key_));
            key_count_delta -= static_cast<int32>(language->pluralized_strings_.erase(str->key_));
            language->deleted_strings_.insert(str->key_);
            if (is_diff) {
              strings.push_back(get_language_pack_string_object(str->key_));
            }
            database_strings.emplace_back(std::move(str->key_), "3");
            break;
          }
          default:
            UNREACHABLE();
            break;
        }
      }
      if (!language->is_full_) {
        for (const auto &key : keys) {
          if (!language_has_string_unsafe(language, key)) {
            LOG(ERROR) << "Doesn't receive key " << key << " from server";
            language->deleted_strings_.insert(key);
            if (is_diff) {
              strings.push_back(get_language_pack_string_object(key));
            }
            database_strings.emplace_back(key, "3");
          }
        }
      }

      if (key_count_delta != 0) {
        new_key_count = language->key_count_ + key_count_delta;
        language->key_count_ = new_key_count;
      }

      if (keys.empty() && !is_diff) {
        CHECK(new_database_version >= 0);
        language->is_full_ = true;
        language->deleted_strings_.clear();
      }
      new_is_full = language->is_full_;

      if (is_diff || (new_is_full && is_first)) {
        send_closure(
            G()->td(), &Td::send_update,
            td_api::make_object<td_api::updateLanguagePackStrings>(language_pack, language_code, std::move(strings)));
      }
    }
  }
  if (is_custom_language_code(language_code) && new_database_version == -1) {
    new_database_version = 1;
  }

  save_strings_to_database(&language->kv_, new_database_version, new_is_full, new_key_count,
                           std::move(database_strings));

  if (is_diff) {
    CHECK(language != nullptr);
    vector<Promise<Unit>> get_difference_queries;
    {
      std::lock_guard<std::mutex> lock(language->mutex_);
      if (language->has_get_difference_query_) {
        language->has_get_difference_query_ = false;
        get_difference_queries = std::move(language->get_difference_queries_);
        reset_to_empty(language->get_difference_queries_);
        is_version_changed = true;
      }
    }
    for (auto &query : get_difference_queries) {
      query.set_value(Unit());
    }
  }
  if (is_version_changed && language_pack == language_pack_ &&
      (language_code == language_code_ || language_code == base_language_code_)) {
    send_closure_later(actor_id(this), &LanguagePackManager::on_language_pack_version_changed,
                       language_code != language_code_, -1);
  }

  if (promise) {
    promise.set_value(get_language_pack_strings_object(language, keys));
  }
}

void LanguagePackManager::on_failed_get_difference(string language_pack, string language_code, Status error) {
  Language *language = get_language(database_, language_pack, language_code);
  CHECK(language != nullptr);
  vector<Promise<Unit>> get_difference_queries;
  {
    std::lock_guard<std::mutex> lock(language->mutex_);
    if (language->has_get_difference_query_) {
      language->has_get_difference_query_ = false;
      if (language_pack == language_pack_ &&
          (language_code == language_code_ || language_code == base_language_code_)) {
        send_closure_later(actor_id(this), &LanguagePackManager::on_language_pack_version_changed,
                           language_code != language_code_, -1);
      }
      get_difference_queries = std::move(language->get_difference_queries_);
      reset_to_empty(language->get_difference_queries_);
    }
  }
  fail_promises(get_difference_queries, std::move(error));
}

void LanguagePackManager::add_custom_server_language(string language_code, Promise<Unit> &&promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }
  if (!check_language_code_name(language_code)) {
    return promise.set_error(Status::Error(400, "Language pack ID must contain only letters, digits and hyphen"));
  }
  if (is_custom_language_code(language_code)) {
    return promise.set_error(
        Status::Error(400, "Custom local language pack can't be added through addCustomServerLanguagePack"));
  }

  if (get_language(database_, language_pack_, language_code) == nullptr) {
    return promise.set_error(Status::Error(400, "Language pack not found"));
  }

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());
  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> pack_lock(pack->mutex_);
  auto it = pack->all_server_language_pack_infos_.find(language_code);
  if (it == pack->all_server_language_pack_infos_.end()) {
    return promise.set_error(Status::Error(400, "Language pack info not found"));
  }
  auto &info = pack->custom_language_pack_infos_[language_code];
  info = *it->second;
  if (!pack->pack_kv_.empty()) {
    pack->pack_kv_.set(language_code, get_language_info_string(info));
  }

  promise.set_value(Unit());
}

Result<tl_object_ptr<telegram_api::LangPackString>> LanguagePackManager::convert_to_telegram_api(
    tl_object_ptr<td_api::languagePackString> &&str) {
  if (str == nullptr) {
    return Status::Error(400, "Language pack strings must be non-empty");
  }

  string key = std::move(str->key_);
  if (!is_valid_key(key)) {
    return Status::Error(400, "Key is invalid");
  }

  if (str->value_ == nullptr) {
    return make_tl_object<telegram_api::langPackStringDeleted>(std::move(key));
  }
  switch (str->value_->get_id()) {
    case td_api::languagePackStringValueOrdinary::ID: {
      auto value = static_cast<td_api::languagePackStringValueOrdinary *>(str->value_.get());
      if (!clean_input_string(value->value_)) {
        return Status::Error(400, "Language pack string value must be encoded in UTF-8");
      }
      return make_tl_object<telegram_api::langPackString>(std::move(key), std::move(value->value_));
    }
    case td_api::languagePackStringValuePluralized::ID: {
      auto value = static_cast<td_api::languagePackStringValuePluralized *>(str->value_.get());
      if (!clean_input_string(value->zero_value_) || !clean_input_string(value->one_value_) ||
          !clean_input_string(value->two_value_) || !clean_input_string(value->few_value_) ||
          !clean_input_string(value->many_value_) || !clean_input_string(value->other_value_)) {
        return Status::Error(400, "Language pack string value must be encoded in UTF-8");
      }
      return make_tl_object<telegram_api::langPackStringPluralized>(
          31, std::move(key), std::move(value->zero_value_), std::move(value->one_value_), std::move(value->two_value_),
          std::move(value->few_value_), std::move(value->many_value_), std::move(value->other_value_));
    }
    case td_api::languagePackStringValueDeleted::ID:
      // there is no reason to save deleted strings in a custom language pack to database
      return make_tl_object<telegram_api::langPackStringDeleted>(std::move(key));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

Result<LanguagePackManager::LanguageInfo> LanguagePackManager::get_language_info(
    telegram_api::langPackLanguage *language) {
  if (!check_language_code_name(language->lang_code_) || language->lang_code_.empty()) {
    LOG(ERROR) << "Receive unsupported language pack ID " << language->lang_code_ << " from server";
    return Status::Error(500, "Unsupported language pack ID");
  }
  if (is_custom_language_code(language->lang_code_)) {
    LOG(ERROR) << "Receive custom language pack ID \"" << language->lang_code_ << "\" from server";
    return Status::Error(500, "Unallowed custom language pack ID");
  }
  to_lower_inplace(language->lang_code_);

  LanguageInfo info;
  info.name_ = std::move(language->name_);
  info.native_name_ = std::move(language->native_name_);
  info.base_language_code_ = std::move(language->base_lang_code_);
  info.plural_code_ = std::move(language->plural_code_);
  info.is_official_ = language->official_;
  info.is_rtl_ = language->rtl_;
  info.is_beta_ = language->beta_;
  info.is_from_database_ = false;
  info.total_string_count_ = language->strings_count_;
  info.translated_string_count_ = language->translated_count_;
  info.translation_url_ = language->translations_url_;

  if (!check_language_code_name(info.base_language_code_)) {
    LOG(ERROR) << "Have invalid base language pack ID \"" << info.base_language_code_ << '"';
    info.base_language_code_.clear();
  }
  if (is_custom_language_code(info.base_language_code_)) {
    LOG(ERROR) << "Receive custom base language pack ID \"" << info.base_language_code_ << "\" from server";
    info.base_language_code_.clear();
  }
  if (info.base_language_code_ == language->lang_code_) {
    LOG(ERROR) << "Receive language pack \"" << info.base_language_code_ << "\"based on self";
    info.base_language_code_.clear();
  }
  return std::move(info);
}

Result<LanguagePackManager::LanguageInfo> LanguagePackManager::get_language_info(
    td_api::languagePackInfo *language_pack_info) {
  if (language_pack_info == nullptr) {
    return Status::Error(400, "Language pack info must be non-empty");
  }

  if (!clean_input_string(language_pack_info->id_)) {
    return Status::Error(400, "Language pack ID must be encoded in UTF-8");
  }
  if (!clean_input_string(language_pack_info->base_language_pack_id_)) {
    return Status::Error(400, "Base language pack ID must be encoded in UTF-8");
  }
  if (!clean_input_string(language_pack_info->name_)) {
    return Status::Error(400, "Language pack name must be encoded in UTF-8");
  }
  if (!clean_input_string(language_pack_info->native_name_)) {
    return Status::Error(400, "Language pack native name must be encoded in UTF-8");
  }
  if (!clean_input_string(language_pack_info->plural_code_)) {
    return Status::Error(400, "Language pack plural code must be encoded in UTF-8");
  }
  if (!clean_input_string(language_pack_info->translation_url_)) {
    return Status::Error(400, "Language pack translation URL must be encoded in UTF-8");
  }
  if (language_pack_info->total_string_count_ < 0) {
    language_pack_info->total_string_count_ = 0;
  }
  if (language_pack_info->translated_string_count_ < 0) {
    language_pack_info->translated_string_count_ = 0;
  }
  if (!check_language_code_name(language_pack_info->id_)) {
    return Status::Error(400, "Language pack ID must contain only letters, digits and hyphen");
  }

  if (is_custom_language_code(language_pack_info->id_)) {
    language_pack_info->base_language_pack_id_.clear();
    language_pack_info->is_official_ = false;
    language_pack_info->is_rtl_ = false;
    language_pack_info->is_beta_ = false;
    language_pack_info->translation_url_.clear();
  }

  LanguageInfo info;
  info.name_ = std::move(language_pack_info->name_);
  info.native_name_ = std::move(language_pack_info->native_name_);
  info.base_language_code_ = std::move(language_pack_info->base_language_pack_id_);
  info.plural_code_ = std::move(language_pack_info->plural_code_);
  info.is_official_ = language_pack_info->is_official_;
  info.is_rtl_ = language_pack_info->is_rtl_;
  info.is_beta_ = language_pack_info->is_beta_;
  info.is_from_database_ = true;
  info.total_string_count_ = language_pack_info->total_string_count_;
  info.translated_string_count_ = language_pack_info->translated_string_count_;
  info.translation_url_ = std::move(language_pack_info->translation_url_);

  return std::move(info);
}

void LanguagePackManager::set_custom_language(td_api::object_ptr<td_api::languagePackInfo> &&language_pack_info,
                                              vector<tl_object_ptr<td_api::languagePackString>> strings,
                                              Promise<Unit> &&promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }

  TRY_RESULT_PROMISE(promise, language_info, get_language_info(language_pack_info.get()));
  auto language_code = std::move(language_pack_info->id_);
  if (!is_custom_language_code(language_code)) {
    return promise.set_error(Status::Error(400, "Custom language pack ID must begin with 'X'"));
  }

  vector<tl_object_ptr<telegram_api::LangPackString>> server_strings;
  for (auto &str : strings) {
    TRY_RESULT_PROMISE(promise, result, convert_to_telegram_api(std::move(str)));
    server_strings.push_back(std::move(result));
  }

  // TODO atomic replace
  do_delete_language(language_code).ensure();
  on_get_language_pack_strings(language_pack_, language_code, 1, false, vector<string>(), std::move(server_strings),
                               Auto());
  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());
  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> pack_lock(pack->mutex_);
  auto &info = pack->custom_language_pack_infos_[language_code];
  info = std::move(language_info);
  if (!pack->pack_kv_.empty()) {
    pack->pack_kv_.set(language_code, get_language_info_string(info));
  }

  promise.set_value(Unit());
}

void LanguagePackManager::edit_custom_language_info(td_api::object_ptr<td_api::languagePackInfo> &&language_pack_info,
                                                    Promise<Unit> &&promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }

  TRY_RESULT_PROMISE(promise, language_info, get_language_info(language_pack_info.get()));
  auto language_code = std::move(language_pack_info->id_);
  if (!is_custom_language_code(language_code)) {
    return promise.set_error(Status::Error(400, "Custom language pack ID must begin with 'X'"));
  }

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());
  LanguagePack *pack = pack_it->second.get();
  std::lock_guard<std::mutex> pack_lock(pack->mutex_);
  auto language_info_it = pack->custom_language_pack_infos_.find(language_code);
  if (language_info_it == pack->custom_language_pack_infos_.end()) {
    return promise.set_error(Status::Error(400, "Custom language pack is not found"));
  }
  auto &info = language_info_it->second;
  info = std::move(language_info);
  if (!pack->pack_kv_.empty()) {
    pack->pack_kv_.set(language_code, get_language_info_string(info));
  }

  promise.set_value(Unit());
}

void LanguagePackManager::set_custom_language_string(string language_code,
                                                     tl_object_ptr<td_api::languagePackString> str,
                                                     Promise<Unit> &&promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }
  if (!check_language_code_name(language_code)) {
    return promise.set_error(Status::Error(400, "Language pack ID must contain only letters, digits and hyphen"));
  }
  if (!is_custom_language_code(language_code)) {
    return promise.set_error(Status::Error(400, "Custom language pack ID must begin with 'X'"));
  }

  if (get_language(database_, language_pack_, language_code) == nullptr) {
    return promise.set_error(Status::Error(400, "Custom language pack not found"));
  }
  if (str == nullptr) {
    return promise.set_error(Status::Error(400, "Language pack strings must not be null"));
  }

  vector<string> keys{str->key_};

  TRY_RESULT_PROMISE(promise, lang_pack_string, convert_to_telegram_api(std::move(str)));

  vector<tl_object_ptr<telegram_api::LangPackString>> server_strings;
  server_strings.push_back(std::move(lang_pack_string));

  on_get_language_pack_strings(language_pack_, language_code, 1, true, std::move(keys), std::move(server_strings),
                               Auto());
  promise.set_value(Unit());
}

void LanguagePackManager::delete_language(string language_code, Promise<Unit> &&promise) {
  if (language_pack_.empty()) {
    return promise.set_error(Status::Error(400, "Option \"localization_target\" needs to be set first"));
  }
  if (!check_language_code_name(language_code)) {
    return promise.set_error(Status::Error(400, "Language pack ID is invalid"));
  }
  if (language_code.empty()) {
    return promise.set_error(Status::Error(400, "Language pack ID is empty"));
  }
  if (language_code_ == language_code || base_language_code_ == language_code) {
    return promise.set_error(Status::Error(400, "Currently used language pack can't be deleted"));
  }

  auto status = do_delete_language(language_code);
  if (status.is_error()) {
    promise.set_error(std::move(status));
  } else {
    promise.set_value(Unit());
  }
}

Status LanguagePackManager::do_delete_language(const string &language_code) {
  add_language(database_, language_pack_, language_code);

  std::lock_guard<std::mutex> packs_lock(database_->mutex_);
  auto pack_it = database_->language_packs_.find(language_pack_);
  CHECK(pack_it != database_->language_packs_.end());
  LanguagePack *pack = pack_it->second.get();

  std::lock_guard<std::mutex> languages_lock(pack->mutex_);
  auto code_it = pack->languages_.find(language_code);
  CHECK(code_it != pack->languages_.end());
  auto language = code_it->second.get();
  if (language->has_get_difference_query_) {
    return Status::Error(400, "Language pack can't be deleted now, try again later");
  }
  if (!language->kv_.empty()) {
    language->kv_.drop().ignore();
    CHECK(language->kv_.empty());
    CHECK(!database_->database_.empty());
    language->kv_
        .init_with_connection(database_->database_.clone(), get_database_table_name(language_pack_, language_code))
        .ensure();
  }
  std::lock_guard<std::mutex> language_lock(language->mutex_);
  language->version_ = -1;
  language->key_count_ = load_database_language_key_count(&language->kv_);
  language->is_full_ = false;
  language->ordinary_strings_.clear();
  language->pluralized_strings_.clear();
  language->deleted_strings_.clear();

  if (!pack->pack_kv_.empty()) {
    pack->pack_kv_.erase(language_code);
  }
  pack->custom_language_pack_infos_.erase(language_code);

  return Status::OK();
}

void LanguagePackManager::on_result(NetQueryPtr query) {
  auto token = get_link_token();
  container_.extract(token).set_value(std::move(query));
}

void LanguagePackManager::send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise) {
  auto id = container_.create(std::move(promise));
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this, id));
}

void LanguagePackManager::hangup() {
  container_.for_each(
      [](auto id, Promise<NetQueryPtr> &promise) { promise.set_error(Global::request_aborted_error()); });
  stop();
}

int32 LanguagePackManager::manager_count_ = 0;
std::mutex LanguagePackManager::language_database_mutex_;
std::unordered_map<string, unique_ptr<LanguagePackManager::LanguageDatabase>, Hash<string>>
    LanguagePackManager::language_databases_;

}  // namespace td
