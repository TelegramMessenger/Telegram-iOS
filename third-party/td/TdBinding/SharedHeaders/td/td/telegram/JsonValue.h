//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

Result<td_api::object_ptr<td_api::JsonValue>> get_json_value(MutableSlice json);

Result<telegram_api::object_ptr<telegram_api::JSONValue>> get_input_json_value(MutableSlice json);

td_api::object_ptr<td_api::JsonValue> convert_json_value_object(
    const tl_object_ptr<telegram_api::JSONValue> &json_value);

tl_object_ptr<telegram_api::JSONValue> convert_json_value(td_api::object_ptr<td_api::JsonValue> &&json_value);

string get_json_string(const td_api::JsonValue *json_value);

bool get_json_value_bool(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name);

int32 get_json_value_int(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name);

int64 get_json_value_long(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name);

double get_json_value_double(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name);

string get_json_value_string(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name);

}  // namespace td
