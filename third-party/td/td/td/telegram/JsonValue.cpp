//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/JsonValue.h"

#include "td/telegram/misc.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/utf8.h"

#include <utility>

namespace td {

static td_api::object_ptr<td_api::JsonValue> get_json_value_object(const JsonValue &json_value) {
  switch (json_value.type()) {
    case JsonValue::Type::Null:
      return td_api::make_object<td_api::jsonValueNull>();
    case JsonValue::Type::Boolean:
      return td_api::make_object<td_api::jsonValueBoolean>(json_value.get_boolean());
    case JsonValue::Type::Number:
      return td_api::make_object<td_api::jsonValueNumber>(to_double(json_value.get_number()));
    case JsonValue::Type::String:
      return td_api::make_object<td_api::jsonValueString>(json_value.get_string().str());
    case JsonValue::Type::Array:
      return td_api::make_object<td_api::jsonValueArray>(transform(json_value.get_array(), get_json_value_object));
    case JsonValue::Type::Object: {
      vector<td_api::object_ptr<td_api::jsonObjectMember>> members;
      json_value.get_object().foreach([&members](Slice name, const JsonValue &value) {
        members.push_back(td_api::make_object<td_api::jsonObjectMember>(name.str(), get_json_value_object(value)));
      });
      return td_api::make_object<td_api::jsonValueObject>(std::move(members));
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

Result<td_api::object_ptr<td_api::JsonValue>> get_json_value(MutableSlice json) {
  TRY_RESULT(json_value, json_decode(json));
  return get_json_value_object(json_value);
}

Result<telegram_api::object_ptr<telegram_api::JSONValue>> get_input_json_value(MutableSlice json) {
  TRY_RESULT(json_value, get_json_value(json));
  return convert_json_value(std::move(json_value));
}

static td_api::object_ptr<td_api::jsonObjectMember> convert_json_value_member_object(
    const telegram_api::object_ptr<telegram_api::jsonObjectValue> &json_object_value) {
  CHECK(json_object_value != nullptr);
  return td_api::make_object<td_api::jsonObjectMember>(json_object_value->key_,
                                                       convert_json_value_object(json_object_value->value_));
}

td_api::object_ptr<td_api::JsonValue> convert_json_value_object(
    const tl_object_ptr<telegram_api::JSONValue> &json_value) {
  CHECK(json_value != nullptr);
  switch (json_value->get_id()) {
    case telegram_api::jsonNull::ID:
      return td_api::make_object<td_api::jsonValueNull>();
    case telegram_api::jsonBool::ID:
      return td_api::make_object<td_api::jsonValueBoolean>(
          static_cast<const telegram_api::jsonBool *>(json_value.get())->value_);
    case telegram_api::jsonNumber::ID:
      return td_api::make_object<td_api::jsonValueNumber>(
          static_cast<const telegram_api::jsonNumber *>(json_value.get())->value_);
    case telegram_api::jsonString::ID:
      return td_api::make_object<td_api::jsonValueString>(
          static_cast<const telegram_api::jsonString *>(json_value.get())->value_);
    case telegram_api::jsonArray::ID:
      return td_api::make_object<td_api::jsonValueArray>(
          transform(static_cast<const telegram_api::jsonArray *>(json_value.get())->value_, convert_json_value_object));
    case telegram_api::jsonObject::ID:
      return td_api::make_object<td_api::jsonValueObject>(transform(
          static_cast<const telegram_api::jsonObject *>(json_value.get())->value_, convert_json_value_member_object));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

static telegram_api::object_ptr<telegram_api::jsonObjectValue> convert_json_value_member(
    td_api::object_ptr<td_api::jsonObjectMember> &&json_object_member) {
  CHECK(json_object_member != nullptr);
  if (!clean_input_string(json_object_member->key_)) {
    json_object_member->key_.clear();
  }
  return telegram_api::make_object<telegram_api::jsonObjectValue>(
      json_object_member->key_, convert_json_value(std::move(json_object_member->value_)));
}

tl_object_ptr<telegram_api::JSONValue> convert_json_value(td_api::object_ptr<td_api::JsonValue> &&json_value) {
  if (json_value == nullptr) {
    return td_api::make_object<telegram_api::jsonNull>();
  }
  switch (json_value->get_id()) {
    case td_api::jsonValueNull::ID:
      return telegram_api::make_object<telegram_api::jsonNull>();
    case td_api::jsonValueBoolean::ID:
      return telegram_api::make_object<telegram_api::jsonBool>(
          static_cast<const td_api::jsonValueBoolean *>(json_value.get())->value_);
    case td_api::jsonValueNumber::ID:
      return telegram_api::make_object<telegram_api::jsonNumber>(
          static_cast<const td_api::jsonValueNumber *>(json_value.get())->value_);
    case td_api::jsonValueString::ID: {
      auto &str = static_cast<td_api::jsonValueString *>(json_value.get())->value_;
      if (!clean_input_string(str)) {
        str.clear();
      }
      return telegram_api::make_object<telegram_api::jsonString>(str);
    }
    case td_api::jsonValueArray::ID:
      return telegram_api::make_object<telegram_api::jsonArray>(
          transform(std::move(static_cast<td_api::jsonValueArray *>(json_value.get())->values_), convert_json_value));
    case td_api::jsonValueObject::ID:
      return telegram_api::make_object<telegram_api::jsonObject>(transform(
          std::move(static_cast<td_api::jsonValueObject *>(json_value.get())->members_), convert_json_value_member));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

namespace {

class JsonableJsonValue final : public Jsonable {
 public:
  explicit JsonableJsonValue(const td_api::JsonValue *json_value) : json_value_(json_value) {
  }
  void store(JsonValueScope *scope) const {
    if (json_value_ == nullptr) {
      *scope << JsonNull();
      return;
    }
    switch (json_value_->get_id()) {
      case td_api::jsonValueNull::ID:
        *scope << JsonNull();
        break;
      case td_api::jsonValueBoolean::ID:
        *scope << JsonBool(static_cast<const td_api::jsonValueBoolean *>(json_value_)->value_);
        break;
      case td_api::jsonValueNumber::ID:
        *scope << static_cast<const td_api::jsonValueNumber *>(json_value_)->value_;
        break;
      case td_api::jsonValueString::ID: {
        auto &str = static_cast<const td_api::jsonValueString *>(json_value_)->value_;
        if (!check_utf8(str)) {
          LOG(ERROR) << "Have incorrect UTF-8 string " << str;
          *scope << "";
        } else {
          *scope << str;
        }
        break;
      }
      case td_api::jsonValueArray::ID: {
        auto array = scope->enter_array();
        for (auto &value : static_cast<const td_api::jsonValueArray *>(json_value_)->values_) {
          array << JsonableJsonValue(value.get());
        }
        break;
      }
      case td_api::jsonValueObject::ID: {
        auto object = scope->enter_object();
        for (auto &member : static_cast<const td_api::jsonValueObject *>(json_value_)->members_) {
          if (member != nullptr) {
            if (!check_utf8(member->key_)) {
              LOG(ERROR) << "Have incorrect UTF-8 object key " << member->key_;
            } else {
              object(member->key_, JsonableJsonValue(member->value_.get()));
            }
          }
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }

 private:
  const td_api::JsonValue *json_value_;
};

}  // namespace

string get_json_string(const td_api::JsonValue *json_value) {
  return json_encode<string>(JsonableJsonValue(json_value));
}

bool get_json_value_bool(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name) {
  CHECK(json_value != nullptr);
  if (json_value->get_id() == telegram_api::jsonBool::ID) {
    return static_cast<const telegram_api::jsonBool *>(json_value.get())->value_;
  }
  LOG(ERROR) << "Expected Boolean as " << name << ", but found " << to_string(json_value);
  return false;
}

int32 get_json_value_int(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name) {
  CHECK(json_value != nullptr);
  if (json_value->get_id() == telegram_api::jsonNumber::ID) {
    return static_cast<int32>(static_cast<const telegram_api::jsonNumber *>(json_value.get())->value_);
  }
  LOG(ERROR) << "Expected Integer as " << name << ", but found " << to_string(json_value);
  return 0;
}

int64 get_json_value_long(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name) {
  CHECK(json_value != nullptr);
  if (json_value->get_id() == telegram_api::jsonString::ID) {
    return to_integer<int64>(static_cast<const telegram_api::jsonString *>(json_value.get())->value_);
  }
  if (json_value->get_id() == telegram_api::jsonNumber::ID) {
    return static_cast<int64>(static_cast<const telegram_api::jsonNumber *>(json_value.get())->value_);
  }
  LOG(ERROR) << "Expected Long as " << name << ", but found " << to_string(json_value);
  return 0;
}

double get_json_value_double(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name) {
  CHECK(json_value != nullptr);
  if (json_value->get_id() == telegram_api::jsonNumber::ID) {
    return static_cast<const telegram_api::jsonNumber *>(json_value.get())->value_;
  }
  LOG(ERROR) << "Expected Double as " << name << ", but found " << to_string(json_value);
  return 0.0;
}

string get_json_value_string(telegram_api::object_ptr<telegram_api::JSONValue> &&json_value, Slice name) {
  CHECK(json_value != nullptr);
  if (json_value->get_id() == telegram_api::jsonString::ID) {
    return std::move(static_cast<telegram_api::jsonString *>(json_value.get())->value_);
  }
  LOG(ERROR) << "Expected String as " << name << ", but found " << to_string(json_value);
  return string();
}

}  // namespace td
