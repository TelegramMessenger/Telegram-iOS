//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <mutex>
#include <unordered_map>
#include <utility>

namespace td {

class SqliteKeyValue;

class LanguagePackManager final : public NetQueryCallback {
 public:
  explicit LanguagePackManager(ActorShared<> parent);
  LanguagePackManager(const LanguagePackManager &) = delete;
  LanguagePackManager &operator=(const LanguagePackManager &) = delete;
  LanguagePackManager(LanguagePackManager &&) = delete;
  LanguagePackManager &operator=(LanguagePackManager &&) = delete;
  ~LanguagePackManager() final;

  static bool check_language_pack_name(Slice name);

  static bool check_language_code_name(Slice name);

  static bool is_custom_language_code(Slice language_code);

  string get_main_language_code();

  vector<string> get_used_language_codes();

  void on_language_pack_changed();

  void on_language_code_changed();

  void on_language_pack_version_changed(bool is_base, int32 new_version);

  void on_language_pack_too_long(string language_code);

  void get_languages(bool only_local, Promise<td_api::object_ptr<td_api::localizationTargetInfo>> promise);

  void search_language_info(string language_code, Promise<td_api::object_ptr<td_api::languagePackInfo>> promise);

  void get_language_pack_strings(string language_code, vector<string> keys,
                                 Promise<td_api::object_ptr<td_api::languagePackStrings>> promise);

  static td_api::object_ptr<td_api::Object> get_language_pack_string(const string &database_path,
                                                                     const string &language_pack,
                                                                     const string &language_code, const string &key);

  void synchronize_language_pack(string language_code, Promise<Unit> promise);

  void on_update_language_pack(tl_object_ptr<telegram_api::langPackDifference> difference);

  void add_custom_server_language(string language_code, Promise<Unit> &&promise);

  void set_custom_language(td_api::object_ptr<td_api::languagePackInfo> &&language_pack_info,
                           vector<tl_object_ptr<td_api::languagePackString>> strings, Promise<Unit> &&promise);

  void edit_custom_language_info(td_api::object_ptr<td_api::languagePackInfo> &&language_pack_info,
                                 Promise<Unit> &&promise);

  void set_custom_language_string(string language_code, tl_object_ptr<td_api::languagePackString> str,
                                  Promise<Unit> &&promise);

  void delete_language(string language_code, Promise<Unit> &&promise);

 private:
  struct PluralizedString;
  struct Language;
  struct LanguageInfo;
  struct LanguagePack;
  struct LanguageDatabase;

  ActorShared<> parent_;

  string language_pack_;
  string language_code_;
  string base_language_code_;
  LanguageDatabase *database_ = nullptr;

  struct PendingQueries {
    vector<Promise<td_api::object_ptr<td_api::languagePackStrings>>> queries_;
  };

  FlatHashMap<string, FlatHashMap<string, PendingQueries>> get_all_language_pack_strings_queries_;

  static int32 manager_count_;

  static std::mutex language_database_mutex_;
  static std::unordered_map<string, unique_ptr<LanguageDatabase>, Hash<string>> language_databases_;

  static LanguageDatabase *add_language_database(string path);

  static Language *get_language(LanguageDatabase *database, const string &language_pack, const string &language_code);
  static Language *get_language(LanguagePack *language_pack, const string &language_code);

  static Language *add_language(LanguageDatabase *database, const string &language_pack, const string &language_code);

  static bool language_has_string_unsafe(const Language *language, const string &key);
  static bool language_has_strings(Language *language, const vector<string> &keys);

  static void load_language_string_unsafe(Language *language, const string &key, const string &value);
  static bool load_language_strings(LanguageDatabase *database, Language *language, const vector<string> &keys);

  static td_api::object_ptr<td_api::LanguagePackStringValue> get_language_pack_string_value_object(const string &value);
  static td_api::object_ptr<td_api::LanguagePackStringValue> get_language_pack_string_value_object(
      const PluralizedString &value);
  static td_api::object_ptr<td_api::LanguagePackStringValue> get_language_pack_string_value_object();

  static td_api::object_ptr<td_api::languagePackString> get_language_pack_string_object(const string &key,
                                                                                        const string &value);
  static td_api::object_ptr<td_api::languagePackString> get_language_pack_string_object(const string &key,
                                                                                        const PluralizedString &value);
  static td_api::object_ptr<td_api::languagePackString> get_language_pack_string_object(const string &key);

  static td_api::object_ptr<td_api::LanguagePackStringValue> get_language_pack_string_value_object(
      const Language *language, const string &key);

  static td_api::object_ptr<td_api::languagePackString> get_language_pack_string_object(const Language *language,
                                                                                        const string &key);

  static td_api::object_ptr<td_api::languagePackStrings> get_language_pack_strings_object(Language *language,
                                                                                          const vector<string> &keys);

  static td_api::object_ptr<td_api::languagePackInfo> get_language_pack_info_object(const string &language_code,
                                                                                    const LanguageInfo &info);

  static Result<LanguageInfo> get_language_info(telegram_api::langPackLanguage *language);

  static Result<LanguageInfo> get_language_info(td_api::languagePackInfo *language_pack_info);

  static string get_language_info_string(const LanguageInfo &info);

  static Result<tl_object_ptr<telegram_api::LangPackString>> convert_to_telegram_api(
      tl_object_ptr<td_api::languagePackString> &&str);

  void inc_generation();

  void repair_chosen_language_info();

  static bool is_valid_key(Slice key);

  void save_strings_to_database(SqliteKeyValue *kv, int32 new_version, bool new_is_full, int32 new_key_count,
                                vector<std::pair<string, string>> &&strings);

  void load_empty_language_pack(const string &language_code);

  void on_get_language_pack_strings(string language_pack, string language_code, int32 version, bool is_diff,
                                    vector<string> &&keys, vector<tl_object_ptr<telegram_api::LangPackString>> results,
                                    Promise<td_api::object_ptr<td_api::languagePackStrings>> promise);

  void on_get_all_language_pack_strings(string language_pack, string language_code,
                                        Result<td_api::object_ptr<td_api::languagePackStrings>> r_strings);

  void send_language_get_difference_query(Language *language, string language_code, int32 version,
                                          Promise<Unit> &&promise);

  void on_failed_get_difference(string language_pack, string language_code, Status error);

  void on_get_language_info(const string &language_pack, td_api::languagePackInfo *language_pack_info);

  static void save_server_language_pack_infos(LanguagePack *pack);

  void on_get_languages(vector<tl_object_ptr<telegram_api::langPackLanguage>> languages, string language_pack,
                        bool only_local, Promise<td_api::object_ptr<td_api::localizationTargetInfo>> promise);

  void on_get_language(tl_object_ptr<telegram_api::langPackLanguage> lang_pack_language, string language_pack,
                       string language_code, Promise<td_api::object_ptr<td_api::languagePackInfo>> promise);

  Status do_delete_language(const string &language_code);

  void on_result(NetQueryPtr query) final;

  void start_up() final;
  void hangup() final;
  void tear_down() final;

  Container<Promise<NetQueryPtr>> container_;
  void send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise);
};

}  // namespace td
