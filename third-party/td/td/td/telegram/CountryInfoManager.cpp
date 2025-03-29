//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CountryInfoManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/Gzip.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Time.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/utf8.h"

namespace td {

class GetNearestDcQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit GetNearestDcQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create_unauth(telegram_api::help_getNearestDc()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getNearestDc>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    promise_.set_value(std::move(result->country_));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status) && status.message() != "BOT_METHOD_INVALID") {
      LOG(ERROR) << "GetNearestDc returned " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class GetCountriesListQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::help_CountriesList>> promise_;

 public:
  explicit GetCountriesListQuery(Promise<tl_object_ptr<telegram_api::help_CountriesList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &language_code, int32 hash) {
    send_query(G()->net_query_creator().create_unauth(telegram_api::help_getCountriesList(language_code, hash)));
  }

  void on_result(BufferSlice packet) final {
    // LOG(ERROR) << base64url_encode(gzencode(packet, 0.9));
    auto result_ptr = fetch_result<telegram_api::help_getCountriesList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "GetCountriesList returned " << status;
    }
    promise_.set_error(std::move(status));
  }
};

struct CountryInfoManager::CallingCodeInfo {
  string calling_code;
  vector<string> prefixes;
  vector<string> patterns;
};

struct CountryInfoManager::CountryInfo {
  string country_code;
  string default_name;
  string name;
  vector<CallingCodeInfo> calling_codes;
  bool is_hidden = false;

  td_api::object_ptr<td_api::countryInfo> get_country_info_object() const {
    return td_api::make_object<td_api::countryInfo>(
        country_code, name.empty() ? default_name : name, default_name, is_hidden,
        transform(calling_codes, [](const CallingCodeInfo &info) { return info.calling_code; }));
  }
};

struct CountryInfoManager::CountryList {
  vector<CountryInfo> countries;
  int32 hash = 0;
  double next_reload_time = 0.0;

  td_api::object_ptr<td_api::countries> get_countries_object() const {
    return td_api::make_object<td_api::countries>(
        transform(countries, [](const CountryInfo &info) { return info.get_country_info_object(); }));
  }
};

CountryInfoManager::CountryInfoManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  on_update_fragment_prefixes();
}

CountryInfoManager::~CountryInfoManager() = default;

void CountryInfoManager::start_up() {
  std::lock_guard<std::mutex> country_lock(country_mutex_);
  manager_count_++;
}

void CountryInfoManager::tear_down() {
  parent_.reset();

  std::lock_guard<std::mutex> country_lock(country_mutex_);
  manager_count_--;
  if (manager_count_ == 0 && !countries_.empty()) {
    LOG(INFO) << "Clear country info";
    countries_.clear();
  }
}

bool CountryInfoManager::is_fragment_phone_number(string phone_number) {
  if (phone_number.empty()) {
    return false;
  }
  if (fragment_prefixes_.empty()) {
    fragment_prefixes_str_ = "888";
    fragment_prefixes_.push_back(fragment_prefixes_str_);
  }
  clean_phone_number(phone_number);
  for (auto &prefix : fragment_prefixes_) {
    if (begins_with(phone_number, prefix)) {
      return true;
    }
  }
  return false;
}

void CountryInfoManager::on_update_fragment_prefixes() {
  if (G()->close_flag()) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  if (!td_->option_manager_->have_option("fragment_prefixes")) {
    return;
  }

  auto fragment_prefixes_str = td_->option_manager_->get_option_string("fragment_prefixes", "888");
  std::lock_guard<std::mutex> country_lock(country_mutex_);
  if (fragment_prefixes_str == fragment_prefixes_str_) {
    return;
  }
  fragment_prefixes_str_ = std::move(fragment_prefixes_str);
  fragment_prefixes_ = full_split(fragment_prefixes_str_, ',');
}

string CountryInfoManager::get_main_language_code() {
  return to_lower(td_->language_pack_manager_.get_actor_unsafe()->get_main_language_code());
}

void CountryInfoManager::get_countries(Promise<td_api::object_ptr<td_api::countries>> &&promise) {
  do_get_countries(get_main_language_code(), false, std::move(promise));
}

void CountryInfoManager::do_get_countries(string language_code, bool is_recursive,
                                          Promise<td_api::object_ptr<td_api::countries>> &&promise) {
  if (is_recursive) {
    auto main_language_code = get_main_language_code();
    if (language_code != main_language_code) {
      language_code = std::move(main_language_code);
      is_recursive = false;
    }
  }

  {
    std::lock_guard<std::mutex> country_lock(country_mutex_);
    auto list = get_country_list(this, language_code);
    if (list != nullptr) {
      return promise.set_value(list->get_countries_object());
    }
  }

  if (is_recursive) {
    return promise.set_error(Status::Error(500, "Requested data is inaccessible"));
  }
  if (language_code.empty()) {
    return promise.set_error(Status::Error(400, "Invalid language code specified"));
  }
  load_country_list(language_code, 0,
                    PromiseCreator::lambda([actor_id = actor_id(this), language_code,
                                            promise = std::move(promise)](Result<Unit> &&result) mutable {
                      if (result.is_error()) {
                        return promise.set_error(result.move_as_error());
                      }
                      send_closure(actor_id, &CountryInfoManager::do_get_countries, std::move(language_code), true,
                                   std::move(promise));
                    }));
}

void CountryInfoManager::get_phone_number_info(string phone_number_prefix,
                                               Promise<td_api::object_ptr<td_api::phoneNumberInfo>> &&promise) {
  clean_phone_number(phone_number_prefix);
  if (phone_number_prefix.empty()) {
    return promise.set_value(td_api::make_object<td_api::phoneNumberInfo>(nullptr, string(), string(), false));
  }
  do_get_phone_number_info(std::move(phone_number_prefix), get_main_language_code(), false, std::move(promise));
}

void CountryInfoManager::do_get_phone_number_info(string phone_number_prefix, string language_code, bool is_recursive,
                                                  Promise<td_api::object_ptr<td_api::phoneNumberInfo>> &&promise) {
  if (is_recursive) {
    auto main_language_code = get_main_language_code();
    if (language_code != main_language_code) {
      language_code = std::move(main_language_code);
      is_recursive = false;
    }
  }
  {
    std::lock_guard<std::mutex> country_lock(country_mutex_);
    auto list = get_country_list(this, language_code);
    if (list != nullptr) {
      return promise.set_value(get_phone_number_info_object(list, phone_number_prefix));
    }
  }

  if (is_recursive) {
    return promise.set_error(Status::Error(500, "Requested data is inaccessible"));
  }
  if (language_code.empty()) {
    return promise.set_error(Status::Error(400, "Invalid language code specified"));
  }
  load_country_list(language_code, 0,
                    PromiseCreator::lambda([actor_id = actor_id(this), phone_number_prefix, language_code,
                                            promise = std::move(promise)](Result<Unit> &&result) mutable {
                      if (result.is_error()) {
                        return promise.set_error(result.move_as_error());
                      }
                      send_closure(actor_id, &CountryInfoManager::do_get_phone_number_info,
                                   std::move(phone_number_prefix), std::move(language_code), true, std::move(promise));
                    }));
}

td_api::object_ptr<td_api::phoneNumberInfo> CountryInfoManager::get_phone_number_info_sync(const string &language_code,
                                                                                           string phone_number_prefix) {
  clean_phone_number(phone_number_prefix);
  if (phone_number_prefix.empty()) {
    return td_api::make_object<td_api::phoneNumberInfo>(nullptr, string(), string(), false);
  }

  std::lock_guard<std::mutex> country_lock(country_mutex_);
  auto list = get_country_list(nullptr, language_code);
  if (list == nullptr) {
    list = get_country_list(nullptr, "en");
  }

  return get_phone_number_info_object(list, phone_number_prefix);
}

td_api::object_ptr<td_api::phoneNumberInfo> CountryInfoManager::get_phone_number_info_object(const CountryList *list,
                                                                                             Slice phone_number) {
  CHECK(list != nullptr);
  const CountryInfo *best_country = nullptr;
  const CallingCodeInfo *best_calling_code = nullptr;
  size_t best_length = 0;
  bool is_prefix = false;  // is phone number a prefix of a valid country_code + prefix
  bool is_anonymous = is_fragment_phone_number(phone_number.str());
  for (auto &country : list->countries) {
    for (auto &calling_code : country.calling_codes) {
      if (begins_with(phone_number, calling_code.calling_code)) {
        auto calling_code_size = calling_code.calling_code.size();
        for (auto &prefix : calling_code.prefixes) {
          if (begins_with(prefix, phone_number.substr(calling_code_size))) {
            is_prefix = true;
          }
          if (calling_code_size + prefix.size() > best_length &&
              begins_with(phone_number.substr(calling_code_size), prefix)) {
            best_country = &country;
            best_calling_code = &calling_code;
            best_length = calling_code_size + prefix.size();
          }
        }
      }
      if (begins_with(calling_code.calling_code, phone_number)) {
        is_prefix = true;
      }
    }
  }
  if (best_country == nullptr) {
    return td_api::make_object<td_api::phoneNumberInfo>(nullptr, is_prefix ? phone_number.str() : string(),
                                                        is_prefix ? string() : phone_number.str(), is_anonymous);
  }

  Slice formatted_part = phone_number.substr(best_calling_code->calling_code.size());
  string formatted_phone_number;
  size_t max_matched_digits = 0;
  for (auto &pattern : best_calling_code->patterns) {
    string result;
    size_t current_pattern_pos = 0;
    bool is_failed_match = false;
    size_t matched_digits = 0;
    for (auto &c : formatted_part) {
      while (current_pattern_pos < pattern.size() && pattern[current_pattern_pos] != 'X' &&
             !is_digit(pattern[current_pattern_pos])) {
        result += pattern[current_pattern_pos++];
      }
      if (current_pattern_pos == pattern.size()) {
        // result += ' ';
      }
      if (current_pattern_pos >= pattern.size() || pattern[current_pattern_pos] == 'X') {
        result += c;
        current_pattern_pos++;
      } else {
        CHECK(is_digit(pattern[current_pattern_pos]));
        if (c == pattern[current_pattern_pos]) {
          matched_digits++;
          result += c;
          current_pattern_pos++;
        } else {
          is_failed_match = true;
          break;
        }
      }
    }
    for (size_t i = current_pattern_pos; i < pattern.size(); i++) {
      if (is_digit(pattern[i])) {
        is_failed_match = true;
      }
    }
    if (!is_failed_match && matched_digits >= max_matched_digits) {
      max_matched_digits = matched_digits;
      while (current_pattern_pos < pattern.size()) {
        if (pattern[current_pattern_pos] == 'X') {
          result.push_back('-');
        } else {
          CHECK(!is_digit(pattern[current_pattern_pos]));
          result.push_back(' ');
        }
        current_pattern_pos++;
      }
      formatted_phone_number = std::move(result);
    }
  }

  return td_api::make_object<td_api::phoneNumberInfo>(
      best_country->get_country_info_object(), best_calling_code->calling_code,
      formatted_phone_number.empty() ? formatted_part.str() : formatted_phone_number, is_anonymous);
}

void CountryInfoManager::get_current_country_code(Promise<string> &&promise) {
  td_->create_handler<GetNearestDcQuery>(std::move(promise))->send();
}

void CountryInfoManager::load_country_list(string language_code, int32 hash, Promise<Unit> &&promise) {
  auto &queries = pending_load_country_queries_[language_code];
  if (!promise && !queries.empty()) {
    return;
  }
  queries.push_back(std::move(promise));
  if (queries.size() == 1) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), language_code](Result<tl_object_ptr<telegram_api::help_CountriesList>> &&result) {
          send_closure(actor_id, &CountryInfoManager::on_get_country_list, language_code, std::move(result));
        });
    td_->create_handler<GetCountriesListQuery>(std::move(query_promise))->send(language_code, hash);
  }
}

void CountryInfoManager::on_get_country_list(const string &language_code,
                                             Result<tl_object_ptr<telegram_api::help_CountriesList>> r_country_list) {
  auto query_it = pending_load_country_queries_.find(language_code);
  CHECK(query_it != pending_load_country_queries_.end());
  auto promises = std::move(query_it->second);
  CHECK(!promises.empty());
  pending_load_country_queries_.erase(query_it);

  if (r_country_list.is_error()) {
    {
      std::lock_guard<std::mutex> country_lock(country_mutex_);
      auto it = countries_.find(language_code);
      if (it != countries_.end()) {
        // don't try to reload countries more often than once in 1-2 minutes
        it->second->next_reload_time = max(Time::now() + Random::fast(60, 120), it->second->next_reload_time);

        // if we have data for the language, then we don't need to fail promises
        set_promises(promises);
        return;
      }
    }
    fail_promises(promises, r_country_list.move_as_error());
    return;
  }

  {
    std::lock_guard<std::mutex> country_lock(country_mutex_);
    on_get_country_list_impl(language_code, r_country_list.move_as_ok());
  }

  set_promises(promises);
}

void CountryInfoManager::on_get_country_list_impl(const string &language_code,
                                                  tl_object_ptr<telegram_api::help_CountriesList> country_list) {
  CHECK(country_list != nullptr);
  LOG(DEBUG) << "Receive " << to_string(country_list);
  auto &countries = countries_[language_code];
  switch (country_list->get_id()) {
    case telegram_api::help_countriesListNotModified::ID:
      if (countries == nullptr) {
        LOG(ERROR) << "Receive countriesListNotModified for unknown list with language code " << language_code;
        countries_.erase(language_code);
      } else {
        LOG(INFO) << "List of countries with language code " << language_code << " is not modified";
        countries->next_reload_time = Time::now() + Random::fast(86400, 2 * 86400);
      }
      break;
    case telegram_api::help_countriesList::ID: {
      auto list = move_tl_object_as<telegram_api::help_countriesList>(country_list);
      if (countries == nullptr) {
        countries = make_unique<CountryList>();
      } else {
        countries->countries.clear();
      }
      for (auto &c : list->countries_) {
        CountryInfo info;
        info.country_code = std::move(c->iso2_);
        info.default_name = std::move(c->default_name_);
        info.name = std::move(c->name_);
        info.is_hidden = c->hidden_;
        for (auto &code : c->country_codes_) {
          auto r_calling_code = to_integer_safe<int32>(code->country_code_);
          if (r_calling_code.is_error() || r_calling_code.ok() <= 0) {
            LOG(ERROR) << "Receive invalid calling code " << code->country_code_ << " for country "
                       << info.country_code;
          } else {
            CallingCodeInfo calling_code_info;
            calling_code_info.calling_code = std::move(code->country_code_);
            calling_code_info.prefixes = std::move(code->prefixes_);
            if (calling_code_info.prefixes.empty()) {
              calling_code_info.prefixes.resize(1);
            }
            calling_code_info.patterns = std::move(code->patterns_);
            info.calling_codes.push_back(std::move(calling_code_info));
          }
        }
        if (info.calling_codes.empty()) {
          LOG(ERROR) << "Receive empty list of calling codes for " << info.country_code;
          continue;
        }

        countries->countries.push_back(std::move(info));
      }
      countries->hash = list->hash_;
      countries->next_reload_time = Time::now() + Random::fast(86400, 2 * 86400);
      break;
    }
    default:
      UNREACHABLE();
  }
}

const CountryInfoManager::CountryList *CountryInfoManager::get_country_list(CountryInfoManager *manager,
                                                                            const string &language_code) {
  auto it = countries_.find(language_code);
  if (it == countries_.end()) {
    if (language_code == "en") {
      static const BufferSlice en = gzdecode(
          base64url_decode(
              "eJyNW81y40hyrib13-qe6d3ZWR8cE4xwxHod4dkg8UfgyH9RJCg2AervViRryBqBgAYEpKVeYG8--AH2sgfHHnyzn6Dtky9-Ar-"
              "AD34FJ0hRAIlkoSO6pzVUZVVWVuaXX2YV_xz-959-8x___rf_Swj5u3_60xf4h-QqdXJccSee79Pod-_gs__7z3w1B__m5bK2-"
              "ezk9raw-rMl2yDfDV0esEmh4tNRoTHnPg3YAn6XmssolzafvV9NtPp7G8_VJO8rP01n1OWLgLq78jlDJgn5twli-"
              "Rb5VHEDPg1p4XeFKvVH4YSm9TgoSZqe0O9ko8jWvtrkpOJOQ-"
              "44FNlLNIeSOUcX7OqMYDuIXVVVbAsTZP05Q2XLyuazs1g2se4VOQLdPdA8JSspitiGA3Ja8acMzOju2G71e1VJrGORj5U58_"
              "mYugWLzr30egclTc-2kw17DReBn95rTonP_Gwju7XXIegbyVKHI2ed00oJn1lJ79j5hhxW_HCEyOYloyzW-56cVV6YP6L8Z-oi_"
              "m4owjOuVsh3VW8BRwzuesH8Fzb1nlZmT88l62XhmVer5CTyeDrxsNgDf1W0rHOo1slZlbpTh07YYpbWQdeLYh0a5LjKnCkP56lzkKW3-"
              "c5vN0CygyXVJjmvhv4DmKDQpAsPs4Mkads2Xf-J52iBHUJnSn2-a0eyjjsjHnsB-"
              "tKZT3kKawCr5M1np7exsWLZNsiGfuhOeFpHdeesCts-W70kh1WIbBfdnyG2sRnZ2J8DsqXPWFFKmWfcI5-qoDbjhTr1w8WCOnSO6KHF-"
              "8fnuQI9PIc_IfikGqV4D29un5D9TH6oei7lPvvHgsXdoNCACKYBDxcQCBYd0fS5qUbi3AbkqOrTF-"
              "6k411V3z77sIGL1NlZq3Onc7rA4kTKtKEN68_CAI35sio-"
              "vxvwTy9YPFM8ziUtI87vVjEWHR2SF8Q5pXoPejOHvzDEvsXS27hahRzVQL_J9jnk4d93pbXOv49klKKcV_"
              "VyvqwX87qk5iVZA98v5rWiAv4j5ctlPS_Bz4pcgvm1fLlo5I0ifK5LURxDLjLykm7kZUXOy5qaV0oajC3n1ZKRVxU9r5XkvKbA_"
              "EU1rxfLIBuN0WEM_IV11JKSV8swVi_ldZDRyzAPrKPJ8HNsx_NEnts6x1qdfKp5kCgLv6-z-R8KA_b4h3_"
              "AzkSRhXatNcl3NciYkIMKlZ_W6TCaCz1fWYxftRY5f9XpVR1MH0mszwV5bz3zAFKTQ91JOqcmcyIm3yYfa1_-LWCFyd-"
              "3nzwIUwyn1O04K6TjrNaJ9uI9FNqLSI_dvLTyO02X4vFdclibcYcheVzVxHm8ZpKTGgUy4nkubvc3f0DxvNZbrb3LeVZr61oSUxKrJ-"
              "WvYH3P8eajVN5Z61_ezX-IPw7IWc0DJCwMwIfSe4AYEu9hSA5qKyqDrJ_kUQgm165hbfrICtfMn2DnLetCTKwBrtVCn375F7qbt9-"
              "94vfms3dGUu4OsGb5CHCGcB4148zuwU9f2HgWRVs4cvg4PYciFRO-nua7deAsLcin1F2muK5ixGvVL8lJ_Wc-8sKAo_"
              "6lysK4rnfIcZ25c-o_pOMxzlnoPuvg23Vvzt3IKzBuV9bKJCNn1a_Ix80cr-gUjc9vzaMXjT3zJMZIXzFG2Tcm1uc-"
              "qo2mDOH8eakk78RKmis2auS4MQ6B7voI_"
              "xDjdQPOvLEIPLy2kpJ6r7Nvct0WOWxMl48BEmNSMRnjSZhIyA9gbZ8HPkP2HfOm0zj1J2Qtcmg9Uow35mRFXBs3bHLSCGbce0TxCfw3w"
              "dkQ3tEEvtvk7m4-Ies41eNxl-SgyX9GY0QrG0KfaHbIt03qPESLiHKGWizGMiY5M_nY91y24Ahv1IyY1zSvyIcm9T0WT46cwRvOHe_"
              "asAm8s-lTd5zGx5wsJ3JEYctpI_l3K3k76k947nLuAdPthfMR8zEddH2lQ_Tzob72ARQXWhVy2KIjD60jlG0O_qpMLFslH1_"
              "7Nh3uTifePL0nZdunNsV3PEcdsNNnEVFEapGynIUBrRX2ev4UiUPDUIX-3GrCWcLaAP6tkFOsVwE4oMTjL8BWs9S419wmxotWm5y2-"
              "AjoXUB9rDZXi3HcYufUBXmfsVX0oD5n7PW5lkmOWnTFKhAOVhTbtweyIXcZKivuA7X65KwF8MocL3xE-"
              "IBqvK29F6Nbn8mnxi8hDTxAeafwqgrmq-Ic3YK4i-yHxt0W5uK8qmWD_UENNqcOtr5alLZiZZcbtYBXgfwcwbSDklbOrLlbN-TDevM_"
              "VjlU3CFqA1U8x110lsvIgZGziPWHn7V1mMayFx1yegE1RaED_8HwRhXv_6JHTkB-AvQO7euqRUXo_xeQ82q-BwU-"
              "km91cb18YZPDC8oj0oWsa4jXHZLji9CdUn-Z9huNCH2uXSenbXfymlaQvmLcz0L7km3AtrbPsPoL8EKMN-0uOWovfMrS_"
              "Y28URbXfm2oY0BvVGejtI3nr1rHslfkvM4Z1J4t6o_38ARFE_pp-zM5aPv0F0zW0JTMWG0PVvJYDZcz9OxYb1tg9_E-"
              "uyti3cHX2gF1lhi_MrLXvjTJ8SWdU6DYaZzQy5n918srcnTp-RO0r6Qlzh2pfy_75PCSPlKMG-qlpO44L-"
              "00yGGHuUsUn1Vxrui0yFln6U-XLwu8J2ZowljpXKxq95E3wX1OV8UY0WmTkw73-YjitZmmi-"
              "vmDpxbzZt7vpfuqUmamLN2euTXFo16mB0eBFH_sseeONJX1LXMmqjTJ-97nh_MAKh36gOytkPMezsD8t6CYhQZuz5zKRnrb2cey9-"
              "Qo074DMiK-Zoqttcd1N10CTXzG5FO71eGqjZrv_fgN_SFPsxSfrPqNZbX8tF877T4_9cc-"
              "80RClu6dSvkoEvROxCwn5aQLyRcKSFfJcddNqJA01P2N7S4lujWwP6rc--"
              "G43Reg5pczbxj7LbJhy5n41nA3EXA0PsARRL34buQ2y2fF7rUfUAxX9n1g23c6EJu7vIRXofL4vvarhXZauEFMw-"
              "JG00Ys13gZF0ezMLodhTj1OUtTr3GjOS-h-SsG_6RAWqE_"
              "hTj5Mk8mcas7jU56tLgCePVcrkkXvuOHILNcKws6UKbmRVybALSjMeIzUri3G7WyJHpuXTsYTqLe2VmPVrXmXhPWM9DFp6V2YAa23PBS"
              "9nU3157FRdyoodrQi4woSCc0sUYiiXEL95se56MwaRPmxfkW5P6ixl1HGHv2Eis2yHfrLHTpGM2wXs7epIvbtJQYt0uOTCpg_"
              "f3JPF9oAk5xAR6Pqf-rp45Q02MAy5tRv19B891Rnknbna4uHlFDmGHaA2hqxk69snfrGzEfBfM5Edl8x77bmqbYhaGmZ-j8_"
              "YD7vJfQuxeydDisYNobOjzYBX0iI0lsf7W2g8XzPdpOm-BvtlvMkw7sh8U8mgdL76bMYfkdK0_"
              "D9HekSzuA5jXcPbUmfCnPe9jNHE9b0LOBnn6zLG4Et_9mbcgy_7Ix-"
              "n4zalSYo27lY50uUDvz3NaMTH2PjqPl6g7sXv2r7xRjIU9wMIenfMRlns08duJXo186LHnQo0662hH75bK8Xjgtz0-ZVj_"
              "RpLKwnPvNclHiJufPGdzlYWsVY6xqNeCffE9vW05WQPhXLzXJqc9KCJ8Og0xP1WLYn7W6wKPZFGYr0I7XcvE9QDWq1zPAbUI7PmZLpG-"
              "YHyXdfbGwRIY1YNapMceqYPiWzl7_wOQhzgLsTMtxz293pAc9Dh4Hnr2cjzuPrLHc-GeUfQ-"
              "VIs5EmrPK5McXM3RmhRiVhfK9ivkqA84O0fv88Q5u98gB30WmQG5z9uu5VP8pt8k3772R_"
              "ues3xtY2B2it9V9Fvk2z59DGkhstamXYedgRrLXJD3_Rl3-OMjDE_7mhb3xffWzf0OOenTh9WjP2yvRurtEDJHF-"
              "zspWJz7a96hq1M8ts1l-9zSC0MijgzQjQHqQHUYnzX0YcarB8yP_CiC1tvU6skagB9371cPMaQM-vCvkVO-4BzC8iyyN04xNRu_3QbK_"
              "s22BfyfjiNQhLLeyWxfW7IIay_yzle_SeuSft30TmuUGuJraNm9PQ_V8jhZ4r32I2MN4-DBjkZfPlr6PI99_-"
              "auB4YXJHjgTfH3mrmlKLYfwYWObKYj_"
              "boZV18rzYYkl8NwgVEp1tosgkDYhPtYHeeZO27NwYGwA8GzxACGLdSd31kew9WhZxbNJzw1TPePdxU2-"
              "FHO35mVck3VvQGwntrDCDYEedkq0bOLLYcz5gDzo31GvXYdnGSiuXr5NAKJ1jPK3pbJNa1AWf2DAZP2zqnbPWGEdkW1NzcndJHz8feqm"
              "gZ9_nWRWTrCG8umMPe3oHlknaSlHLifujt7I52_cdqkxPL8Z6Yi5-ZrIvrcKuzlgf4ReUVSYwNVhf2EqEmLXSZ5-"
              "7m4lfOI4l1MMEP6LokcbH6shxjrtUjx1ZUiFIH4XHifoUFMW5BjDsYL1MzdByAnYD6QyZH96hmvBW2rE2_buWxSO2fobtNvre-_"
              "MUr2N78y18hQ_X9L__qjjl2NyfJyZ7lpn2R0OWavG84BYs6T_j7iaK4jrRuozMH9zUpVH4Mw1vIfVKJZOQ16w7id-mj_R9Dk8V-"
              "d09OGotnGhWeqM9l8DK7Rr63Q_8h6tjWKGTvhaCXqWW_Z7Hr5KA2oxPc_3dqs536wm6RA9ub7nnvrAv90r4gJ_aM8vXVMoJFGe_"
              "m7EtyZtOf-Sv7Sp-DIe5J2R1ybHsPDNhBGuuNmBvYUJPYfO75P3aBxzAkLyTGmuQ8Opvo2w97OCHolfTRdC_"
              "HBpywgQ0s0PdFYky0r8ih7QG-o9w37mfYA3IU6cmQGsn4intp2yafbIAUPqETcEPbG9HICdL-p2d_X8W-"
              "jnR5ok6IcbQYP23gCDblz9hZ67omjDkbYs6m7gvdk2ukjO-0DKHeHz5Ez-1ZSlaOv1tw_ia70xcctsjRcLqP34i5ydAi-"
              "aFVSfGq0lfwquEd6O2HEa1FcH-bo-z264b35Gz4MmL740vP3Pd1jfyw5gvX3B0z-Pd3BajuC-"
              "u3N1HZheFv9vdurhvk9Bpy6QuUOggG59SvuG-9bpHvq1FHbDED7fwpF90JSV-"
              "hU5t8Glq7U6H3S8XMuQADrjkLIGfvxkROT3yP6XoI46gb0gDBsAT3uGmSb26o4_AoaTTDIHTTd3SaHt8R3UTv9VZfi8JiclVDR5_"
              "lblvkh5YD0e8UTG_EHQapOQBOzAP4aQloOU_L64l1bjvkqOMtvCfsXkDfm8vXa1-T79tuwHx3VXiACj0WPHuQGNOcVNelxM9xf-"
              "WuQQ7v2JxhPNzQyvswZbX-HdTtdz-m6vbV7xQpvv9T1jXQ25r3Ub2y4lPrF_"
              "cIHuWkMhFiwr1Jju73va2Ke7G47A05uefzER0945xXQ994_M8_z__r_wF2XX6H")
              .ok());
      TlBufferParser parser(&en);
      auto result = telegram_api::help_getCountriesList::fetch_result(parser);
      parser.fetch_end();
      CHECK(parser.get_error() == nullptr);
      on_get_country_list_impl(language_code, std::move(result));

      it = countries_.find(language_code);
      CHECK(it != countries_.end());
      auto *country = it->second.get();
      if (manager != nullptr) {
        manager->load_country_list(language_code, country->hash, Auto());
      }
      return country;
    }
    return nullptr;
  }

  auto *country = it->second.get();
  CHECK(country != nullptr);
  if (manager != nullptr && country->next_reload_time < Time::now()) {
    manager->load_country_list(language_code, country->hash, Auto());
  }

  return country;
}

string CountryInfoManager::get_country_flag_emoji(const string &country_code) {
  if (country_code.size() != 2 || !is_alpha(country_code[0]) || !is_alpha(country_code[1])) {
    return string();
  }
  char first = to_upper(country_code[0]);
  char second = to_upper(country_code[1]);
  if (first == 'Y' && second == 'L') {
    return string();
  }
  if (first == 'F' && second == 'T') {
    return "\xF0\x9F\x8F\xB4\xE2\x80\x8D\xE2\x98\xA0\xEF\xB8\x8F";  // pirate flag
  }
  if (first == 'X' && second == 'G') {
    return "\xF0\x9F\x9B\xB0";  // satellite
  }
  if (first == 'X' && second == 'V') {
    return "\xF0\x9F\x8C\x8D";  // globe showing Europe-Africa
  }
  string result;
  result.reserve(8);
  append_utf8_character(result, 0x1F1A5 + first);
  append_utf8_character(result, 0x1F1A5 + second);
  CHECK(result.size() == 8);
  return result;
}

int32 CountryInfoManager::manager_count_ = 0;
std::mutex CountryInfoManager::country_mutex_;
FlatHashMap<string, unique_ptr<CountryInfoManager::CountryList>> CountryInfoManager::countries_;
string CountryInfoManager::fragment_prefixes_str_;
vector<string> CountryInfoManager::fragment_prefixes_;

}  // namespace td
