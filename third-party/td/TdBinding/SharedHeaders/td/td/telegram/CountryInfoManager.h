//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <mutex>

namespace td {

class Td;

class CountryInfoManager final : public Actor {
 public:
  CountryInfoManager(Td *td, ActorShared<> parent);

  void get_countries(Promise<td_api::object_ptr<td_api::countries>> &&promise);

  void get_current_country_code(Promise<string> &&promise);

  void get_phone_number_info(string phone_number_prefix,
                             Promise<td_api::object_ptr<td_api::phoneNumberInfo>> &&promise);

  static td_api::object_ptr<td_api::phoneNumberInfo> get_phone_number_info_sync(const string &language_code,
                                                                                string phone_number_prefix);

  static string get_country_flag_emoji(const string &country_code);

  void on_update_fragment_prefixes();

  CountryInfoManager(const CountryInfoManager &) = delete;
  CountryInfoManager &operator=(const CountryInfoManager &) = delete;
  CountryInfoManager(CountryInfoManager &&) = delete;
  CountryInfoManager &operator=(CountryInfoManager &&) = delete;
  ~CountryInfoManager() final;

 private:
  void start_up() final;
  void tear_down() final;

  struct CallingCodeInfo;
  struct CountryInfo;
  struct CountryList;

  string get_main_language_code();

  static bool is_fragment_phone_number(string phone_number);

  void do_get_countries(string language_code, bool is_recursive,
                        Promise<td_api::object_ptr<td_api::countries>> &&promise);

  void do_get_phone_number_info(string phone_number_prefix, string language_code, bool is_recursive,
                                Promise<td_api::object_ptr<td_api::phoneNumberInfo>> &&promise);

  void load_country_list(string language_code, int32 hash, Promise<Unit> &&promise);

  void on_get_country_list(const string &language_code,
                           Result<tl_object_ptr<telegram_api::help_CountriesList>> r_country_list);

  static void on_get_country_list_impl(const string &language_code,
                                       tl_object_ptr<telegram_api::help_CountriesList> country_list);

  static const CountryList *get_country_list(CountryInfoManager *manager, const string &language_code);

  static td_api::object_ptr<td_api::phoneNumberInfo> get_phone_number_info_object(const CountryList *list,
                                                                                  Slice phone_number);

  static std::mutex country_mutex_;

  static int32 manager_count_;

  static FlatHashMap<string, unique_ptr<CountryList>> countries_;

  static string fragment_prefixes_str_;
  static vector<string> fragment_prefixes_;

  FlatHashMap<string, vector<Promise<Unit>>> pending_load_country_queries_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
