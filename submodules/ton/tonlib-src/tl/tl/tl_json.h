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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Status.h"
#include "td/utils/tl_storers.h"

#include <type_traits>

namespace td {
struct JsonInt64 {
  int64 value;
};

inline void to_json(JsonValueScope &jv, const JsonInt64 json_int64) {
  jv << JsonString(PSLICE() << json_int64.value);
}
struct JsonVectorInt64 {
  const std::vector<int64> &value;
};

inline void to_json(JsonValueScope &jv, const JsonVectorInt64 &vec) {
  auto ja = jv.enter_array();
  for (auto &value : vec.value) {
    ja.enter_value() << ToJson(JsonInt64{value});
  }
}
struct JsonBytes {
  td::Slice bytes;
};

inline void to_json(JsonValueScope &jv, const JsonBytes json_bytes) {
  jv << JsonString(PSLICE() << base64_encode(json_bytes.bytes));
}
template <class T>
struct JsonVectorBytesImpl {
  const std::vector<T> &value;
};

template <class T>
auto JsonVectorBytes(const std::vector<T> &value) {
  return JsonVectorBytesImpl<T>{value};
}

template <class T>
void to_json(JsonValueScope &jv, const JsonVectorBytesImpl<T> &vec) {
  auto ja = jv.enter_array();
  for (auto &value : vec.value) {
    ja.enter_value() << ToJson(JsonBytes{value});
  }
}
template <unsigned size>
inline void to_json(JsonValueScope &jv, const td::BitArray<size> &vec) {
  to_json(jv, base64_encode(as_slice(vec)));
}

template <class T>
void to_json(JsonValueScope &jv, const ton::tl_object_ptr<T> &value) {
  if (value) {
    to_json(jv, *value);
  } else {
    jv << JsonNull();
  }
}

template <class T>
void to_json(JsonValueScope &jv, const std::vector<T> &v) {
  auto ja = jv.enter_array();
  for (auto &value : v) {
    ja.enter_value() << ToJson(value);
  }
}

inline Status from_json(std::int32_t &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Number && from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected number, got " << from.type());
  }
  Slice number = from.type() == JsonValue::Type::String ? from.get_string() : from.get_number();
  TRY_RESULT(res, to_integer_safe<int32>(number));
  to = res;
  return Status::OK();
}

inline Status from_json(bool &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Boolean) {
    int32 x;
    auto status = from_json(x, from);
    if (status.is_ok()) {
      to = x != 0;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected bool, got " << from.type());
  }
  to = from.get_boolean();
  return Status::OK();
}

inline Status from_json(std::int64_t &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Number && from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected number, got " << from.type());
  }
  Slice number = from.type() == JsonValue::Type::String ? from.get_string() : from.get_number();
  TRY_RESULT(res, to_integer_safe<int64>(number));
  to = res;
  return Status::OK();
}
inline Status from_json(double &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Number) {
    return Status::Error(PSLICE() << "Expected number, got " << from.type());
  }
  to = to_double(from.get_number().str());
  return Status::OK();
}

inline Status from_json(string &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  to = from.get_string().str();
  return Status::OK();
}

inline Status from_json(SecureString &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  to = SecureString(from.get_string().str());
  return Status::OK();
}

inline Status from_json(Slice &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  to = from.get_string();
  return Status::OK();
}

inline Status from_json_bytes(string &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  TRY_RESULT(decoded, base64_decode(from.get_string()));
  to = std::move(decoded);
  return Status::OK();
}

inline Status from_json_bytes(SecureString &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  TRY_RESULT(decoded, base64_decode_secure(from.get_string()));
  to = std::move(decoded);
  return Status::OK();
}

inline Status from_json_bytes(BufferSlice &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  TRY_RESULT(decoded, base64_decode(from.get_string()));
  to = BufferSlice(decoded);
  return Status::OK();
}

inline Status from_json_bytes(Slice &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::String) {
    return Status::Error(PSLICE() << "Expected string, got " << from.type());
  }
  TRY_RESULT(decoded, base64_decode(from.get_string()));
  from.get_string().copy_from(decoded);
  from.get_string().truncate(decoded.size());
  to = from.get_string();
  return Status::OK();
}

template <unsigned size>
inline Status from_json(td::BitArray<size> &to, JsonValue &from) {
  string raw;
  TRY_STATUS(from_json_bytes(raw, from));
  auto S = to.as_slice();
  if (raw.size() != S.size()) {
    return Status::Error("Wrong length for UInt");
  }
  S.copy_from(raw);
  return Status::OK();
}

template <class T>
Status from_json(std::vector<T> &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Array) {
    return Status::Error(PSLICE() << "Expected array, got " << from.type());
  }
  to = std::vector<T>(from.get_array().size());
  size_t i = 0;
  for (auto &value : from.get_array()) {
    TRY_STATUS(from_json(to[i], value));
    i++;
  }
  return Status::OK();
}

template <class T>
inline Status from_json_vector_bytes(std::vector<T> &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Array) {
    return Status::Error(PSLICE() << "Expected array, got " << from.type());
  }
  to = std::vector<T>(from.get_array().size());
  size_t i = 0;
  for (auto &value : from.get_array()) {
    TRY_STATUS(from_json_bytes(to[i], value));
    i++;
  }
  return Status::OK();
}

template <class T>
class DowncastHelper : public T {
 public:
  explicit DowncastHelper(int32 constructor) : constructor_(constructor) {
  }
  int32 get_id() const override {
    return constructor_;
  }
  void store(TlStorerToString &s, const char *field_name) const override {
  }

 private:
  int32 constructor_{0};
};

template <class T>
std::enable_if_t<!std::is_constructible<T>::value, Status> from_json(ton::tl_object_ptr<T> &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Object) {
    if (from.type() == JsonValue::Type::Null) {
      to = nullptr;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected object, got " << from.type());
  }

  auto &object = from.get_object();
  TRY_RESULT(constructor_value, get_json_object_field(object, "@type", JsonValue::Type::Null, false));
  int32 constructor = 0;
  if (constructor_value.type() == JsonValue::Type::Number) {
    constructor = to_integer<int32>(constructor_value.get_number());
  } else if (constructor_value.type() == JsonValue::Type::String) {
    TRY_RESULT(t_constructor, tl_constructor_from_string(to.get(), constructor_value.get_string().str()));
    constructor = t_constructor;
  } else {
    return Status::Error(PSLICE() << "Expected string or int, got " << constructor_value.type());
  }

  DowncastHelper<T> helper(constructor);
  Status status;
  bool ok = downcast_call(static_cast<T &>(helper), [&](auto &dummy) {
    auto result = ton::create_tl_object<std::decay_t<decltype(dummy)>>();
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
std::enable_if_t<std::is_constructible<T>::value, Status> from_json(ton::tl_object_ptr<T> &to, JsonValue &from) {
  if (from.type() != JsonValue::Type::Object) {
    if (from.type() == JsonValue::Type::Null) {
      to = nullptr;
      return Status::OK();
    }
    return Status::Error(PSLICE() << "Expected object, got " << from.type());
  }
  to = ton::create_tl_object<T>();
  return from_json(*to, from.get_object());
}

}  // namespace td
