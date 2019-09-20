/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "tonlib/ClientJson.h"

#include "auto/tl/tonlib_api_json.h"

#include "tl/tl_json.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Status.h"

#include <utility>

namespace tonlib {

static td::Result<std::pair<tonlib_api::object_ptr<tonlib_api::Function>, std::string>> to_request(td::Slice request) {
  auto request_str = request.str();
  TRY_RESULT(json_value, td::json_decode(request_str));
  if (json_value.type() != td::JsonValue::Type::Object) {
    return td::Status::Error("Expected an Object");
  }

  std::string extra;
  if (has_json_object_field(json_value.get_object(), "@extra")) {
    extra = td::json_encode<std::string>(
        get_json_object_field(json_value.get_object(), "@extra", td::JsonValue::Type::Null).move_as_ok());
  }

  tonlib_api::object_ptr<tonlib_api::Function> func;
  TRY_STATUS(from_json(func, json_value));
  return std::make_pair(std::move(func), extra);
}

static std::string from_response(const tonlib_api::Object &object, const td::string &extra) {
  auto str = td::json_encode<td::string>(td::ToJson(object));
  CHECK(!str.empty() && str.back() == '}');
  if (!extra.empty()) {
    str.pop_back();
    str.reserve(str.size() + 11 + extra.size());
    str += ",\"@extra\":";
    str += extra;
    str += '}';
  }
  return str;
}

static TD_THREAD_LOCAL std::string *current_output;

static td::CSlice store_string(std::string str) {
  td::init_thread_local<std::string>(current_output);
  *current_output = std::move(str);
  return *current_output;
}

void ClientJson::send(td::Slice request) {
  auto r_request = to_request(request);
  if (r_request.is_error()) {
    LOG(ERROR) << "Failed to parse " << tag("request", td::format::escaped(request)) << " " << r_request.error();
    return;
  }

  std::uint64_t extra_id = extra_id_.fetch_add(1, std::memory_order_relaxed);
  if (!r_request.ok_ref().second.empty()) {
    std::lock_guard<std::mutex> guard(mutex_);
    extra_[extra_id] = std::move(r_request.ok_ref().second);
  }
  client_.send(Client::Request{extra_id, std::move(r_request.ok_ref().first)});
}

td::CSlice ClientJson::receive(double timeout) {
  auto response = client_.receive(timeout);
  if (!response.object) {
    return {};
  }

  std::string extra;
  if (response.id != 0) {
    std::lock_guard<std::mutex> guard(mutex_);
    auto it = extra_.find(response.id);
    if (it != extra_.end()) {
      extra = std::move(it->second);
      extra_.erase(it);
    }
  }
  return store_string(from_response(*response.object, extra));
}

td::CSlice ClientJson::execute(td::Slice request) {
  auto r_request = to_request(request);
  if (r_request.is_error()) {
    LOG(ERROR) << "Failed to parse " << tag("request", td::format::escaped(request)) << " " << r_request.error();
    return {};
  }

  return store_string(from_response(*Client::execute(Client::Request{0, std::move(r_request.ok_ref().first)}).object,
                                    r_request.ok().second));
}

}  // namespace tonlib
