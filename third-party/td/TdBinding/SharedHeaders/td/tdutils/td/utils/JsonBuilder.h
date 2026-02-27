//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Parser.h"
#include "td/utils/Slice.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <functional>
#include <new>
#include <type_traits>
#include <utility>

namespace td {

class JsonTrue {
 public:
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonTrue &val) {
    return sb << "true";
  }
};

class JsonFalse {
 public:
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonFalse &val) {
    return sb << "false";
  }
};

class JsonNull {
 public:
  friend StringBuilder &operator<<(StringBuilder &sb, JsonNull val) {
    return sb << "null";
  }
};

class JsonBool {
 public:
  explicit JsonBool(bool value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonBool &val) {
    if (val.value_) {
      return sb << JsonTrue();
    } else {
      return sb << JsonFalse();
    }
  }

 private:
  bool value_;
};

class JsonInt {
 public:
  explicit JsonInt(int32 value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonInt &val) {
    return sb << val.value_;
  }

 private:
  int32 value_;
};

class JsonLong {
 public:
  explicit JsonLong(int64 value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonLong &val) {
    return sb << val.value_;
  }

 private:
  int64 value_;
};

class JsonFloat {
 public:
  explicit JsonFloat(double value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonFloat &val) {
    return sb << val.value_;
  }

 private:
  double value_;
};

class JsonOneChar {
 public:
  explicit JsonOneChar(uint32 c) : c_(c) {
  }

  friend StringBuilder &operator<<(StringBuilder &sb, const JsonOneChar &val) {
    auto c = val.c_;
    return sb << '\\' << 'u' << "0123456789abcdef"[c >> 12] << "0123456789abcdef"[(c >> 8) & 15]
              << "0123456789abcdef"[(c >> 4) & 15] << "0123456789abcdef"[c & 15];
  }

 private:
  uint32 c_;
};

class JsonChar {
 public:
  explicit JsonChar(uint32 c) : c_(c) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonChar &val) {
    auto c = val.c_;
    if (c < 0x10000) {
      if (0xD7FF < c && c < 0xE000) {
        // UTF-8 correctness has already been checked
        UNREACHABLE();
      }
      return sb << JsonOneChar(c);
    } else if (c <= 0x10ffff) {
      return sb << JsonOneChar(0xD7C0 + (c >> 10)) << JsonOneChar(0xDC00 + (c & 0x3FF));
    } else {
      // UTF-8 correctness has already been checked
      UNREACHABLE();
    }
  }

 private:
  uint32 c_;
};

class JsonRaw {
 public:
  explicit JsonRaw(Slice value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonRaw &val) {
    return sb << val.value_;
  }

 private:
  Slice value_;
};

class JsonRawString {
 public:
  explicit JsonRawString(Slice value) : value_(value) {
  }
  friend StringBuilder &operator<<(StringBuilder &sb, const JsonRawString &val);

 private:
  Slice value_;
};

class JsonString {
 public:
  explicit JsonString(Slice str) : str_(str) {
  }

  friend StringBuilder &operator<<(StringBuilder &sb, const JsonString &val);

 private:
  Slice str_;
};

class JsonScope;
class JsonValueScope;
class JsonArrayScope;
class JsonObjectScope;

class JsonBuilder {
 public:
  explicit JsonBuilder(StringBuilder &&sb = {}, int32 offset = -1) : sb_(std::move(sb)), offset_(offset) {
  }
  StringBuilder &string_builder() {
    return sb_;
  }
  friend class JsonScope;
  JsonValueScope enter_value() TD_WARN_UNUSED_RESULT;
  JsonArrayScope enter_array() TD_WARN_UNUSED_RESULT;
  JsonObjectScope enter_object() TD_WARN_UNUSED_RESULT;

  int32 offset() const {
    return offset_;
  }
  bool is_pretty() const {
    return offset_ >= 0;
  }
  void print_offset() {
    if (offset_ >= 0) {
      sb_ << '\n';
      for (int x = 0; x < offset_; x++) {
        sb_ << "   ";
      }
    }
  }
  void dec_offset() {
    if (offset_ >= 0) {
      CHECK(offset_ > 0);
      offset_--;
    }
  }
  void inc_offset() {
    if (offset_ >= 0) {
      offset_++;
    }
  }

 private:
  StringBuilder sb_;
  JsonScope *scope_ = nullptr;
  int32 offset_;
};

class Jsonable {};

class JsonScope {
 public:
  explicit JsonScope(JsonBuilder *jb) : sb_(&jb->sb_), jb_(jb), save_scope_(jb->scope_) {
    jb_->scope_ = this;
    CHECK(is_active());
  }
  JsonScope(const JsonScope &) = delete;
  JsonScope &operator=(const JsonScope &) = delete;
  JsonScope(JsonScope &&other) noexcept : sb_(other.sb_), jb_(other.jb_), save_scope_(other.save_scope_) {
    other.jb_ = nullptr;
  }
  JsonScope &operator=(JsonScope &&) = delete;
  ~JsonScope() {
    if (jb_) {
      leave();
    }
  }
  void leave() {
    CHECK(is_active());
    jb_->scope_ = save_scope_;
  }

 protected:
  StringBuilder *sb_;

  // For CHECK
  JsonBuilder *jb_;
  JsonScope *save_scope_;

  bool is_active() const {
    return jb_ && jb_->scope_ == this;
  }

  JsonScope &operator<<(JsonTrue x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(JsonFalse x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(JsonNull x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonBool &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonInt &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonLong &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonFloat &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonString &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonRawString &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(const JsonRaw &x) {
    *sb_ << x;
    return *this;
  }
  JsonScope &operator<<(bool x) = delete;
  JsonScope &operator<<(int32 x) {
    return *this << JsonInt(x);
  }
  JsonScope &operator<<(int64 x) {
    return *this << JsonLong(x);
  }
  JsonScope &operator<<(double x) {
    return *this << JsonFloat(x);
  }
  template <size_t N>
  JsonScope &operator<<(const char (&x)[N]) {
    return *this << JsonString(Slice(x));
  }
  JsonScope &operator<<(const char *x) {
    return *this << JsonString(Slice(x));
  }
  JsonScope &operator<<(Slice x) {
    return *this << JsonString(x);
  }
};

class JsonValueScope final : public JsonScope {
 public:
  using JsonScope::JsonScope;
  template <class T>
  std::enable_if_t<std::is_base_of<Jsonable, typename std::decay<T>::type>::value, JsonValueScope &> operator<<(
      const T &x) {
    x.store(this);
    return *this;
  }
  template <class T>
  std::enable_if_t<!std::is_base_of<Jsonable, typename std::decay<T>::type>::value, JsonValueScope &> operator<<(
      const T &x) {
    CHECK(!was_);
    was_ = true;
    JsonScope::operator<<(x);
    return *this;
  }

  JsonArrayScope enter_array() TD_WARN_UNUSED_RESULT;
  JsonObjectScope enter_object() TD_WARN_UNUSED_RESULT;

 private:
  bool was_ = false;
};

class JsonArrayScope final : public JsonScope {
 public:
  explicit JsonArrayScope(JsonBuilder *jb) : JsonScope(jb) {
    jb->inc_offset();
    *sb_ << "[";
  }
  JsonArrayScope(const JsonArrayScope &) = delete;
  JsonArrayScope &operator=(const JsonArrayScope &) = delete;
  JsonArrayScope(JsonArrayScope &&) = default;
  JsonArrayScope &operator=(JsonArrayScope &&) = delete;
  ~JsonArrayScope() {
    if (jb_) {
      leave();
    }
  }
  void leave() {
    jb_->dec_offset();
    jb_->print_offset();
    *sb_ << "]";
  }
  template <class T>
  JsonArrayScope &operator<<(const T &x) {
    return (*this)(x);
  }
  template <class T>
  JsonArrayScope &operator()(const T &x) {
    enter_value() << x;
    return *this;
  }
  JsonValueScope enter_value() {
    CHECK(is_active());
    if (is_first_) {
      *sb_ << ",";
    } else {
      is_first_ = true;
    }
    jb_->print_offset();
    return jb_->enter_value();
  }

 private:
  bool is_first_ = false;
};

class JsonObjectScope final : public JsonScope {
 public:
  explicit JsonObjectScope(JsonBuilder *jb) : JsonScope(jb) {
    jb->inc_offset();
    *sb_ << "{";
  }
  JsonObjectScope(const JsonObjectScope &) = delete;
  JsonObjectScope &operator=(const JsonObjectScope &) = delete;
  JsonObjectScope(JsonObjectScope &&) = default;
  JsonObjectScope &operator=(JsonObjectScope &&) = delete;
  ~JsonObjectScope() {
    if (jb_) {
      leave();
    }
  }
  void leave() {
    jb_->dec_offset();
    jb_->print_offset();
    *sb_ << "}";
  }
  template <class T>
  JsonObjectScope &operator()(Slice field, T &&value) {
    CHECK(is_active());
    if (is_first_) {
      *sb_ << ",";
    } else {
      is_first_ = true;
    }
    jb_->print_offset();
    jb_->enter_value() << field;
    if (jb_->is_pretty()) {
      *sb_ << " : ";
    } else {
      *sb_ << ":";
    }
    jb_->enter_value() << value;
    return *this;
  }
  JsonObjectScope &operator<<(const JsonRaw &field_value) {
    CHECK(is_active());
    is_first_ = true;
    jb_->enter_value() << field_value;
    return *this;
  }

 private:
  bool is_first_ = false;
};

inline JsonArrayScope JsonValueScope::enter_array() {
  CHECK(!was_);
  was_ = true;
  return JsonArrayScope(jb_);
}
inline JsonObjectScope JsonValueScope::enter_object() {
  CHECK(!was_);
  was_ = true;
  return JsonObjectScope(jb_);
}
inline JsonValueScope JsonBuilder::enter_value() {
  return JsonValueScope(this);
}
inline JsonObjectScope JsonBuilder::enter_object() {
  return JsonObjectScope(this);
}
inline JsonArrayScope JsonBuilder::enter_array() {
  return JsonArrayScope(this);
}

class JsonValue;

enum class JsonValueType { Null, Number, Boolean, String, Array, Object };

using JsonArray = vector<JsonValue>;

class JsonObject {
  const JsonValue *get_field(Slice name) const;

 public:
  vector<std::pair<Slice, JsonValue>> field_values_;

  JsonObject() = default;

  explicit JsonObject(vector<std::pair<Slice, JsonValue>> &&field_values);

  JsonObject(const JsonObject &) = delete;
  JsonObject &operator=(const JsonObject &) = delete;
  JsonObject(JsonObject &&) = default;
  JsonObject &operator=(JsonObject &&) = default;
  ~JsonObject() = default;

  size_t field_count() const;

  JsonValue extract_field(Slice name);

  Result<JsonValue> extract_optional_field(Slice name, JsonValueType type);

  Result<JsonValue> extract_required_field(Slice name, JsonValueType type);

  bool has_field(Slice name) const;

  Result<bool> get_optional_bool_field(Slice name, bool default_value = false) const;

  Result<bool> get_required_bool_field(Slice name) const;

  Result<int32> get_optional_int_field(Slice name, int32 default_value = 0) const;

  Result<int32> get_required_int_field(Slice name) const;

  Result<int64> get_optional_long_field(Slice name, int64 default_value = 0) const;

  Result<int64> get_required_long_field(Slice name) const;

  Result<double> get_optional_double_field(Slice name, double default_value = 0.0) const;

  Result<double> get_required_double_field(Slice name) const;

  Result<string> get_optional_string_field(Slice name, string default_value = string()) const;

  Result<string> get_required_string_field(Slice name) const;

  void foreach(const std::function<void(Slice name, const JsonValue &value)> &callback) const;
};

class JsonValue final : private Jsonable {
 public:
  using Type = JsonValueType;

  static Slice get_type_name(Type type);

  JsonValue() {
  }
  ~JsonValue() {
    destroy();
  }
  JsonValue(JsonValue &&other) noexcept : JsonValue() {
    init(std::move(other));
  }
  JsonValue &operator=(JsonValue &&other) noexcept {
    if (&other == this) {
      return *this;
    }
    destroy();
    init(std::move(other));
    return *this;
  }
  JsonValue(const JsonValue &) = delete;
  JsonValue &operator=(const JsonValue &) = delete;

  Type type() const {
    return type_;
  }

  MutableSlice &get_string() {
    CHECK(type_ == Type::String);
    return string_;
  }
  const MutableSlice &get_string() const {
    CHECK(type_ == Type::String);
    return string_;
  }
  bool &get_boolean() {
    CHECK(type_ == Type::Boolean);
    return boolean_;
  }
  const bool &get_boolean() const {
    CHECK(type_ == Type::Boolean);
    return boolean_;
  }

  MutableSlice &get_number() {
    CHECK(type_ == Type::Number);
    return number_;
  }
  const MutableSlice &get_number() const {
    CHECK(type_ == Type::Number);
    return number_;
  }

  JsonArray &get_array() {
    CHECK(type_ == Type::Array);
    return array_;
  }
  const JsonArray &get_array() const {
    CHECK(type_ == Type::Array);
    return array_;
  }

  JsonObject &get_object() {
    CHECK(type_ == Type::Object);
    return object_;
  }
  const JsonObject &get_object() const {
    CHECK(type_ == Type::Object);
    return object_;
  }

  static JsonValue create_boolean(bool val) {
    JsonValue res;
    res.init_boolean(val);
    return res;
  }

  static JsonValue create_number(MutableSlice number) {
    JsonValue res;
    res.init_number(number);
    return res;
  }

  static JsonValue create_string(MutableSlice str) {
    JsonValue res;
    res.init_string(str);
    return res;
  }

  static JsonValue create_array(JsonArray v) {
    JsonValue res;
    res.init_array(std::move(v));
    return res;
  }

  static JsonValue make_object(JsonObject c) {
    JsonValue res;
    res.init_object(std::move(c));
    return res;
  }

  void store(JsonValueScope *scope) const {
    switch (type_) {
      case Type::Null:
        *scope << JsonRaw("null");
        break;
      case Type::Boolean:
        if (get_boolean()) {
          *scope << JsonRaw("true");
        } else {
          *scope << JsonRaw("false");
        }
        break;
      case Type::Number:
        *scope << JsonRaw(get_number());
        break;
      case Type::String:
        *scope << JsonString(get_string());
        break;
      case Type::Array: {
        auto arr = scope->enter_array();
        for (auto &val : get_array()) {
          arr << val;
        }
        break;
      }
      case Type::Object: {
        auto object = scope->enter_object();
        for (auto &field_value : get_object().field_values_) {
          object(field_value.first, field_value.second);
        }
        break;
      }
    }
  };

 private:
  Type type_{Type::Null};
  union {
    MutableSlice number_;
    bool boolean_;
    MutableSlice string_;
    JsonArray array_;
    JsonObject object_;
  };

  void init_null() {
    type_ = Type::Null;
  }
  void init_number(MutableSlice number) {
    type_ = Type::Number;
    new (&number_) MutableSlice(number);
  }
  void init_boolean(bool boolean) {
    type_ = Type::Boolean;
    boolean_ = boolean;
  }
  void init_string(MutableSlice slice) {
    type_ = Type::String;
    new (&string_) MutableSlice(slice);
  }
  void init_array(JsonArray array) {
    type_ = Type::Array;
    new (&array_) JsonArray(std::move(array));
  }
  void init_object(JsonObject object) {
    type_ = Type::Object;
    new (&object_) JsonObject(std::move(object));
  }

  void init(JsonValue &&other) {
    switch (other.type_) {
      case Type::Null:
        break;
      case Type::Number:
        init_number(other.number_);
        break;
      case Type::Boolean:
        init_boolean(other.boolean_);
        break;
      case Type::String:
        init_string(other.string_);
        break;
      case Type::Array:
        init_array(std::move(other.array_));
        break;
      case Type::Object:
        init_object(std::move(other.object_));
        break;
    }
    other.destroy();
  }

  void destroy() {
    switch (type_) {
      case Type::Null:
      case Type::Boolean:
        break;
      case Type::Number:
        number_.~MutableSlice();
        break;
      case Type::String:
        string_.~MutableSlice();
        break;
      case Type::Array:
        array_.~vector<JsonValue>();
        break;
      case Type::Object:
        object_.~JsonObject();
        break;
    }
    type_ = Type::Null;
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, JsonValue::Type type) {
  switch (type) {
    case JsonValue::Type::Null:
      return sb << "Null";
    case JsonValue::Type::Number:
      return sb << "Number";
    case JsonValue::Type::Boolean:
      return sb << "Boolean";
    case JsonValue::Type::String:
      return sb << "String";
    case JsonValue::Type::Array:
      return sb << "Array";
    case JsonValue::Type::Object:
      return sb << "Object";
    default:
      UNREACHABLE();
      return sb;
  }
}

class VirtuallyJsonable : private Jsonable {
 public:
  virtual void store(JsonValueScope *scope) const = 0;
  VirtuallyJsonable() = default;
  VirtuallyJsonable(const VirtuallyJsonable &) = delete;
  VirtuallyJsonable &operator=(const VirtuallyJsonable &) = delete;
  VirtuallyJsonable(VirtuallyJsonable &&) = default;
  VirtuallyJsonable &operator=(VirtuallyJsonable &&) = default;
  virtual ~VirtuallyJsonable() = default;
};

class VirtuallyJsonableInt final : public VirtuallyJsonable {
 public:
  explicit VirtuallyJsonableInt(int32 value) : value_(value) {
  }
  void store(JsonValueScope *scope) const final {
    *scope << JsonInt(value_);
  }

 private:
  int32 value_;
};

class VirtuallyJsonableLong final : public VirtuallyJsonable {
 public:
  explicit VirtuallyJsonableLong(int64 value) : value_(value) {
  }
  void store(JsonValueScope *scope) const final {
    *scope << JsonLong(value_);
  }

 private:
  int64 value_;
};

class VirtuallyJsonableString final : public VirtuallyJsonable {
 public:
  explicit VirtuallyJsonableString(Slice value) : value_(value) {
  }
  void store(JsonValueScope *scope) const final {
    *scope << JsonString(value_);
  }

 private:
  Slice value_;
};

Result<MutableSlice> json_string_decode(Parser &parser) TD_WARN_UNUSED_RESULT;
Status json_string_skip(Parser &parser) TD_WARN_UNUSED_RESULT;

Result<JsonValue> do_json_decode(Parser &parser, int32 max_depth) TD_WARN_UNUSED_RESULT;
Status do_json_skip(Parser &parser, int32 max_depth) TD_WARN_UNUSED_RESULT;

inline Result<JsonValue> json_decode(MutableSlice json) {
  Parser parser(json);
  const int32 DEFAULT_MAX_DEPTH = 100;
  auto result = do_json_decode(parser, DEFAULT_MAX_DEPTH);
  if (result.is_ok()) {
    parser.skip_whitespaces();
    if (!parser.empty()) {
      return Status::Error("Expected string end");
    }
  }
  return result;
}

template <class StrT, class ValT>
StrT json_encode(const ValT &val, bool pretty = false) {
  auto buf_len = 1 << 18;
  auto buf = StackAllocator::alloc(buf_len);
  JsonBuilder jb(StringBuilder(buf.as_slice(), true), pretty ? 0 : -1);
  jb.enter_value() << val;
  if (pretty) {
    jb.string_builder() << "\n";
  }
  LOG_IF(ERROR, jb.string_builder().is_error()) << "JSON buffer overflow";
  auto slice = jb.string_builder().as_cslice();
  return StrT(slice.begin(), slice.size());
}

template <class T>
class ToJsonImpl final : private Jsonable {
 public:
  explicit ToJsonImpl(const T &value) : value_(value) {
  }
  void store(JsonValueScope *scope) const {
    to_json(*scope, value_);
  }

 private:
  const T &value_;
};

template <class T>
auto ToJson(const T &value) {
  return ToJsonImpl<T>(value);
}

template <class T>
void to_json(JsonValueScope &jv, const T &value) {
  jv << value;
}

template <class F>
class JsonObjectImpl : private Jsonable {
 public:
  explicit JsonObjectImpl(F &&f) : f_(std::forward<F>(f)) {
  }
  void store(JsonValueScope *scope) const {
    auto object = scope->enter_object();
    f_(object);
  }

 private:
  F f_;
};

template <class F>
auto json_object(F &&f) {
  return JsonObjectImpl<F>(std::forward<F>(f));
}

template <class F>
class JsonArrayImpl : private Jsonable {
 public:
  explicit JsonArrayImpl(F &&f) : f_(std::forward<F>(f)) {
  }
  void store(JsonValueScope *scope) const {
    auto array = scope->enter_array();
    f_(array);
  }

 private:
  F f_;
};

template <class F>
auto json_array(F &&f) {
  return JsonArrayImpl<F>(std::forward<F>(f));
}

template <class A, class F>
auto json_array(const A &a, F &&f) {
  return json_array([&a, &f](auto &arr) {
    for (auto &x : a) {
      arr(f(x));
    }
  });
}

}  // namespace td
