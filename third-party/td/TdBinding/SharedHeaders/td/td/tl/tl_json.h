//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/TlDowncastHelper.h"

#include <type_traits>

namespace td {

struct JsonInt64 {
  int64 value;
};

inline void to_json(JsonValueScope &jv, const JsonInt64 json_int64) {
  jv << JsonString(PSLICE() << json_int64.value);
}

struct JsonVectorInt64 {
  const vector<int64> &value;
};

inline void to_json(JsonValueScope &jv, const JsonVectorInt64 &vec) {
  auto ja = jv.enter_array();
  for (auto &value : vec.value) {
    ja.enter_value() << ToJson(JsonInt64{value});
  }
}

template <class T>
void to_json(JsonValueScope &jv, const tl_object_ptr<T> &value) {
  if (value) {
    to_json(jv, *value);
  } else {
    jv << JsonNull();
  }
}

template <class T>
void to_json(JsonValueScope &jv, const vector<T> &v) {
  auto ja = jv.enter_array();
  for (auto &value : v) {
    ja.enter_value() << ToJson(value);
  }
}

inline Status from_json(int32 &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Number && from.type() != JsonValue::Type::String) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Number, but receive " << from.type());
  }
  Slice number = from.type() == JsonValue::Type::String ? from.get_string() : from.get_number();
  TRY_RESULT_ASSIGN(to, to_integer_safe<int32>(number));
  return Status::OK();
}

inline Status from_json(bool &to, JsonValue from) {
  auto from_type = from.type();
  if (from_type != JsonValue::Type::Boolean) {
    if (from_type == JsonValue::Type::Null) {
      return Status::OK();
    }
    int32 x = 0;
    auto status = from_json(x, std::move(from));
    if (status.is_ok()) {
      to = x != 0;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Boolean, but receive " << from_type);
  }
  to = from.get_boolean();
  return Status::OK();
}

inline Status from_json(int64 &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Number && from.type() != JsonValue::Type::String) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected String or Number, but receive " << from.type());
  }
  Slice number = from.type() == JsonValue::Type::String ? from.get_string() : from.get_number();
  TRY_RESULT_ASSIGN(to, to_integer_safe<int64>(number));
  return Status::OK();
}

inline Status from_json(double &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Number) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Number, but receive " << from.type());
  }
  to = to_double(from.get_number());
  return Status::OK();
}

inline Status from_json(string &to, JsonValue from) {
  if (from.type() != JsonValue::Type::String) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected String, but receive " << from.type());
  }
  to = from.get_string().str();
  return Status::OK();
}

inline Status from_json_bytes(string &to, JsonValue from) {
  if (from.type() != JsonValue::Type::String) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected String, but receive " << from.type());
  }
  TRY_RESULT_ASSIGN(to, base64_decode(from.get_string()));
  return Status::OK();
}

template <class T>
Status from_json(vector<T> &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Array) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Array, but receive " << from.type());
  }
  to = vector<T>(from.get_array().size());
  size_t i = 0;
  for (auto &value : from.get_array()) {
    TRY_STATUS(from_json(to[i], std::move(value)));
    i++;
  }
  return Status::OK();
}

inline Status from_json_bytes(vector<string> &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Array) {
    if (from.type() == JsonValue::Type::Null) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Array, but receive " << from.type());
  }
  to = vector<string>(from.get_array().size());
  size_t i = 0;
  for (auto &value : from.get_array()) {
    TRY_STATUS(from_json_bytes(to[i], std::move(value)));
    i++;
  }
  return Status::OK();
}

template <class T>
std::enable_if_t<!std::is_constructible<T>::value, Status> from_json(tl_object_ptr<T> &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Object) {
    if (from.type() == JsonValue::Type::Null) {
      to = nullptr;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Object, but receive " << from.type());
  }

  auto &object = from.get_object();
  TRY_RESULT(constructor_value, object.extract_required_field("@type", JsonValue::Type::Null));
  int32 constructor = 0;
  if (constructor_value.type() == JsonValue::Type::Number) {
    constructor = to_integer<int32>(constructor_value.get_number());
  } else if (constructor_value.type() == JsonValue::Type::String) {
    TRY_RESULT_ASSIGN(constructor, tl_constructor_from_string(to.get(), constructor_value.get_string().str()));
  } else {
    return Status::Error(PSLICE() << "Expected String or Integer, but receive " << constructor_value.type());
  }

  TlDowncastHelper<T> helper(constructor);
  Status status;
  bool ok = downcast_call(static_cast<T &>(helper), [&](auto &dummy) {
    auto result = make_tl_object<std::decay_t<decltype(dummy)>>();
    status = from_json(*result, object);
    to = std::move(result);
  });
  TRY_STATUS(std::move(status));
  if (!ok) {
    return Status::Error(PSLICE() << "Unknown constructor " << format::as_hex(constructor));
  }

  return Status::OK();
}

template <class T>
std::enable_if_t<std::is_constructible<T>::value, Status> from_json(tl_object_ptr<T> &to, JsonValue from) {
  if (from.type() != JsonValue::Type::Object) {
    if (from.type() == JsonValue::Type::Null) {
      to = nullptr;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected Object, but receive " << from.type());
  }
  to = make_tl_object<T>();
  return from_json(*to, from.get_object());
}

}  // namespace td
