//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <memory>
#include <utility>

namespace td {

class KeyValueSyncInterface;
class Td;
class TsSeqKeyValue;

class OptionManager {
 public:
  explicit OptionManager(Td *td);
  OptionManager(const OptionManager &) = delete;
  OptionManager &operator=(const OptionManager &) = delete;
  OptionManager(OptionManager &&) = delete;
  OptionManager &operator=(OptionManager &&) = delete;
  ~OptionManager();

  void update_premium_options();

  void on_td_inited();

  void set_option_boolean(Slice name, bool value);

  void set_option_empty(Slice name);

  void set_option_integer(Slice name, int64 value);

  void set_option_string(Slice name, Slice value);

  bool have_option(Slice name) const;

  bool get_option_boolean(Slice name, bool default_value = false) const;

  int64 get_option_integer(Slice name, int64 default_value = 0) const;

  string get_option_string(Slice name, string default_value = "") const;

  void on_update_server_time_difference();

  void get_option(const string &name, Promise<td_api::object_ptr<td_api::OptionValue>> &&promise);

  void set_option(const string &name, td_api::object_ptr<td_api::OptionValue> &&value, Promise<Unit> &&promise);

  static bool is_synchronous_option(Slice name);

  static td_api::object_ptr<td_api::OptionValue> get_option_synchronously(Slice name);

  static void get_common_state(vector<td_api::object_ptr<td_api::Update>> &updates);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  void set_option(Slice name, Slice value);

  void on_option_updated(Slice name);

  string get_option(Slice name) const;

  static bool is_internal_option(Slice name);

  td_api::object_ptr<td_api::Update> get_internal_option_update(Slice name) const;

  static const vector<Slice> &get_synchronous_options();

  static td_api::object_ptr<td_api::OptionValue> get_unix_time_option_value_object();

  static td_api::object_ptr<td_api::OptionValue> get_option_value_object(Slice value);

  void send_unix_time_update();

  Td *td_;
  bool is_td_inited_ = false;
  vector<std::pair<string, Promise<td_api::object_ptr<td_api::OptionValue>>>> pending_get_options_;

  int32 current_scheduler_id_ = -1;
  unique_ptr<TsSeqKeyValue> options_;
  std::shared_ptr<KeyValueSyncInterface> option_pmc_;

  std::atomic<double> last_sent_server_time_difference_{1e100};
};

}  // namespace td
