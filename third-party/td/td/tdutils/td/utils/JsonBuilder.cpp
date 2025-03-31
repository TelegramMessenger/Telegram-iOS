//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/JsonBuilder.h"

#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/utf8.h"

namespace td {

StringBuilder &operator<<(StringBuilder &sb, const JsonRawString &val) {
  sb << '"';
  SCOPE_EXIT {
    sb << '"';
  };
  auto *s = val.value_.begin();
  auto len = val.value_.size();

  for (size_t pos = 0; pos < len; pos++) {
    auto ch = static_cast<unsigned char>(s[pos]);
    switch (ch) {
      case '"':
        sb << '\\' << '"';
        break;
      case '\\':
        sb << '\\' << '\\';
        break;
      case '\b':
        sb << '\\' << 'b';
        break;
      case '\f':
        sb << '\\' << 'f';
        break;
      case '\n':
        sb << '\\' << 'n';
        break;
      case '\r':
        sb << '\\' << 'r';
        break;
      case '\t':
        sb << '\\' << 't';
        break;
      default:
        if (ch <= 31) {
          sb << JsonOneChar(s[pos]);
          break;
        }
        sb << s[pos];
        break;
    }
  }
  return sb;
}

StringBuilder &operator<<(StringBuilder &sb, const JsonString &val) {
  sb << '"';
  SCOPE_EXIT {
    sb << '"';
  };
  auto *s = val.str_.begin();
  auto len = val.str_.size();

  for (size_t pos = 0; pos < len; pos++) {
    auto ch = static_cast<unsigned char>(s[pos]);
    switch (ch) {
      case '"':
        sb << '\\' << '"';
        break;
      case '\\':
        sb << '\\' << '\\';
        break;
      case '\b':
        sb << '\\' << 'b';
        break;
      case '\f':
        sb << '\\' << 'f';
        break;
      case '\n':
        sb << '\\' << 'n';
        break;
      case '\r':
        sb << '\\' << 'r';
        break;
      case '\t':
        sb << '\\' << 't';
        break;
      default:
        if (ch <= 31) {
          sb << JsonOneChar(s[pos]);
          break;
        }
        if (128 <= ch) {
          uint32 a = ch;
          CHECK((a & 0x40) != 0);

          CHECK(pos + 1 < len);
          uint32 b = static_cast<unsigned char>(s[++pos]);
          CHECK((b & 0xc0) == 0x80);
          if ((a & 0x20) == 0) {
            CHECK((a & 0x1e) > 0);
            sb << JsonChar(((a & 0x1f) << 6) | (b & 0x3f));
            break;
          }

          CHECK(pos + 1 < len);
          uint32 c = static_cast<unsigned char>(s[++pos]);
          CHECK((c & 0xc0) == 0x80);
          if ((a & 0x10) == 0) {
            CHECK(((a & 0x0f) | (b & 0x20)) > 0);
            sb << JsonChar(((a & 0x0f) << 12) | ((b & 0x3f) << 6) | (c & 0x3f));
            break;
          }

          CHECK(pos + 1 < len);
          uint32 d = static_cast<unsigned char>(s[++pos]);
          CHECK((d & 0xc0) == 0x80);
          if ((a & 0x08) == 0) {
            CHECK(((a & 0x07) | (b & 0x30)) > 0);
            sb << JsonChar(((a & 0x07) << 18) | ((b & 0x3f) << 12) | ((c & 0x3f) << 6) | (d & 0x3f));
            break;
          }

          UNREACHABLE();
          break;
        }
        sb << s[pos];
        break;
    }
  }
  return sb;
}

Result<MutableSlice> json_string_decode(Parser &parser) {
  if (!parser.try_skip('"')) {
    return Status::Error("Opening '\"' expected");
  }
  auto data = parser.data();
  auto *result_start = data.ubegin();
  auto *cur_src = result_start;
  auto *cur_dest = result_start;
  auto *end = data.uend();

  while (true) {
    if (cur_src == end) {
      return Status::Error("Closing '\"' not found");
    }
    if (*cur_src == '"') {
      parser.advance(cur_src + 1 - result_start);
      return data.substr(0, cur_dest - result_start);
    }
    if (*cur_src == '\\') {
      cur_src++;
      if (cur_src == end) {
        return Status::Error("Closing '\"' not found");
      }
      switch (*cur_src) {
        case 'b':
          *cur_dest++ = '\b';
          cur_src++;
          break;
        case 'f':
          *cur_dest++ = '\f';
          cur_src++;
          break;
        case 'n':
          *cur_dest++ = '\n';
          cur_src++;
          break;
        case 'r':
          *cur_dest++ = '\r';
          cur_src++;
          break;
        case 't':
          *cur_dest++ = '\t';
          cur_src++;
          break;
        case 'u': {
          cur_src++;
          if (cur_src + 4 > end) {
            return Status::Error("\\u has less than 4 symbols");
          }
          uint32 num = 0;
          for (int i = 0; i < 4; i++, cur_src++) {
            int d = hex_to_int(*cur_src);
            if (d == 16) {
              return Status::Error("Invalid \\u -- not hex digit");
            }
            num = num * 16 + d;
          }
          if (0xD7FF < num && num < 0xE000) {
            if (cur_src + 6 <= end && cur_src[0] == '\\' && cur_src[1] == 'u') {
              cur_src += 2;
              int new_num = 0;
              for (int i = 0; i < 4; i++, cur_src++) {
                int d = hex_to_int(*cur_src);
                if (d == 16) {
                  return Status::Error("Invalid \\u -- not hex digit");
                }
                new_num = new_num * 16 + d;
              }
              if (0xD7FF < new_num && new_num < 0xE000) {
                num = (((num & 0x3FF) << 10) | (new_num & 0x3FF)) + 0x10000;
              } else {
                cur_src -= 6;
              }
            }
          }

          cur_dest = append_utf8_character_unsafe(cur_dest, num);
          break;
        }
        default:
          *cur_dest++ = *cur_src++;
          break;
      }
    } else {
      *cur_dest++ = *cur_src++;
    }
  }
  UNREACHABLE();
  return {};
}

Status json_string_skip(Parser &parser) {
  if (!parser.try_skip('"')) {
    return Status::Error("Opening '\"' expected");
  }
  auto data = parser.data();
  auto *cur_src = data.ubegin();
  auto *end = data.uend();

  while (true) {
    if (cur_src == end) {
      return Status::Error("Closing '\"' not found");
    }
    if (*cur_src == '"') {
      parser.advance(cur_src + 1 - data.ubegin());
      return Status::OK();
    }
    if (*cur_src == '\\') {
      cur_src++;
      if (cur_src == end) {
        return Status::Error("Closing '\"' not found");
      }
      switch (*cur_src) {
        case 'u': {
          cur_src++;
          if (cur_src + 4 > end) {
            return Status::Error("\\u has less than 4 symbols");
          }
          int num = 0;
          for (int i = 0; i < 4; i++, cur_src++) {
            int d = hex_to_int(*cur_src);
            if (d == 16) {
              return Status::Error("Invalid \\u -- not hex digit");
            }
            num = num * 16 + d;
          }
          if (0xD7FF < num && num < 0xE000) {
            if (cur_src + 6 <= end && cur_src[0] == '\\' && cur_src[1] == 'u') {
              cur_src += 2;
              int new_num = 0;
              for (int i = 0; i < 4; i++, cur_src++) {
                int d = hex_to_int(*cur_src);
                if (d == 16) {
                  return Status::Error("Invalid \\u -- not hex digit");
                }
                new_num = new_num * 16 + d;
              }
              if (0xD7FF < new_num && new_num < 0xE000) {
                // num = (((num & 0x3FF) << 10) | (new_num & 0x3FF)) + 0x10000;
              } else {
                cur_src -= 6;
              }
            }
          }
          break;
        }
        default:
          cur_src++;
          break;
      }
    } else {
      cur_src++;
    }
  }
  UNREACHABLE();
  return Status::OK();
}

Result<JsonValue> do_json_decode(Parser &parser, int32 max_depth) {
  if (max_depth < 0) {
    return Status::Error("Too big object depth");
  }

  parser.skip_whitespaces();
  switch (parser.peek_char()) {
    case 'f':
      if (parser.try_skip("false")) {
        return JsonValue::create_boolean(false);
      }
      return Status::Error("Token starts with 'f' -- false expected");
    case 't':
      if (parser.try_skip("true")) {
        return JsonValue::create_boolean(true);
      }
      return Status::Error("Token starts with 't' -- true expected");
    case 'n':
      if (parser.try_skip("null")) {
        return JsonValue();
      }
      return Status::Error("Token starts with 'n' -- null expected");
    case '"': {
      TRY_RESULT(slice, json_string_decode(parser));
      return JsonValue::create_string(slice);
    }
    case '[': {
      parser.skip('[');
      parser.skip_whitespaces();
      vector<JsonValue> res;
      if (parser.try_skip(']')) {
        return JsonValue::create_array(std::move(res));
      }
      while (true) {
        if (parser.empty()) {
          return Status::Error("Unexpected string end");
        }
        TRY_RESULT(value, do_json_decode(parser, max_depth - 1));
        res.emplace_back(std::move(value));

        parser.skip_whitespaces();
        if (parser.try_skip(']')) {
          break;
        }
        if (parser.try_skip(',')) {
          parser.skip_whitespaces();
          continue;
        }
        if (parser.empty()) {
          return Status::Error("Unexpected string end");
        }
        return Status::Error("Unexpected symbol while parsing JSON Array");
      }
      return JsonValue::create_array(std::move(res));
    }
    case '{': {
      parser.skip('{');
      parser.skip_whitespaces();
      if (parser.try_skip('}')) {
        return JsonValue::make_object(JsonObject());
      }
      vector<std::pair<Slice, JsonValue>> field_values;
      while (true) {
        if (parser.empty()) {
          return Status::Error("Unexpected string end");
        }
        TRY_RESULT(field, json_string_decode(parser));
        parser.skip_whitespaces();
        if (!parser.try_skip(':')) {
          return Status::Error("':' expected");
        }
        TRY_RESULT(value, do_json_decode(parser, max_depth - 1));
        field_values.emplace_back(field, std::move(value));

        parser.skip_whitespaces();
        if (parser.try_skip('}')) {
          break;
        }
        if (parser.try_skip(',')) {
          parser.skip_whitespaces();
          continue;
        }
        if (parser.empty()) {
          return Status::Error("Unexpected string end");
        }
        return Status::Error("Unexpected symbol while parsing JSON Object");
      }
      return JsonValue::make_object(JsonObject(std::move(field_values)));
    }
    case '-':
    case '+':
    case '.':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
      auto num = parser.read_while(
          [](char c) { return c == '-' || ('0' <= c && c <= '9') || c == 'e' || c == 'E' || c == '+' || c == '.'; });
      return JsonValue::create_number(num);
    }
    case 0:
      return Status::Error("Unexpected string end");
    default: {
      char next = parser.peek_char();
      if (0 < next && next < 127) {
        return Status::Error(PSLICE() << "Unexpected symbol '" << parser.peek_char() << "'");
      } else {
        return Status::Error("Unexpected symbol");
      }
    }
  }
  UNREACHABLE();
}

Status do_json_skip(Parser &parser, int32 max_depth) {
  if (max_depth < 0) {
    return Status::Error("Too big object depth");
  }

  parser.skip_whitespaces();
  switch (parser.peek_char()) {
    case 'f':
      if (parser.try_skip("false")) {
        return Status::OK();
      }
      return Status::Error("Starts with 'f' -- false expected");
    case 't':
      if (parser.try_skip("true")) {
        return Status::OK();
      }
      return Status::Error("Starts with 't' -- true expected");
    case 'n':
      if (parser.try_skip("null")) {
        return Status::OK();
      }
      return Status::Error("Starts with 'n' -- null expected");
    case '"': {
      return json_string_skip(parser);
    }
    case '[': {
      parser.skip('[');
      parser.skip_whitespaces();
      if (parser.try_skip(']')) {
        return Status::OK();
      }
      while (true) {
        if (parser.empty()) {
          return Status::Error("Unexpected end");
        }
        TRY_STATUS(do_json_skip(parser, max_depth - 1));

        parser.skip_whitespaces();
        if (parser.try_skip(']')) {
          break;
        }
        if (parser.try_skip(',')) {
          parser.skip_whitespaces();
          continue;
        }
        return Status::Error("Unexpected symbol");
      }
      return Status::OK();
    }
    case '{': {
      parser.skip('{');
      parser.skip_whitespaces();
      if (parser.try_skip('}')) {
        return Status::OK();
      }
      while (true) {
        if (parser.empty()) {
          return Status::Error("Unexpected end");
        }
        TRY_STATUS(json_string_skip(parser));
        parser.skip_whitespaces();
        if (!parser.try_skip(':')) {
          return Status::Error("':' expected");
        }
        TRY_STATUS(do_json_skip(parser, max_depth - 1));

        parser.skip_whitespaces();
        if (parser.try_skip('}')) {
          break;
        }
        if (parser.try_skip(',')) {
          parser.skip_whitespaces();
          continue;
        }
        return Status::Error("Unexpected symbol");
      }
      return Status::OK();
    }
    case '-':
    case '+':
    case '.':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
      parser.read_while(
          [](char c) { return c == '-' || ('0' <= c && c <= '9') || c == 'e' || c == 'E' || c == '+' || c == '.'; });
      return Status::OK();
    }
    case 0:
      return Status::Error("Unexpected end");
    default: {
      char next = parser.peek_char();
      if (0 < next && next < 127) {
        return Status::Error(PSLICE() << "Unexpected symbol '" << parser.peek_char() << "'");
      } else {
        return Status::Error("Unexpected symbol");
      }
    }
  }
  return Status::Error("Can't parse");
}

Slice JsonValue::get_type_name(Type type) {
  switch (type) {
    case Type::Null:
      return Slice("Null");
    case Type::Number:
      return Slice("Number");
    case Type::Boolean:
      return Slice("Boolean");
    case Type::String:
      return Slice("String");
    case Type::Array:
      return Slice("Array");
    case Type::Object:
      return Slice("Object");
    default:
      UNREACHABLE();
      return Slice("Unknown");
  }
}

JsonObject::JsonObject(vector<std::pair<Slice, JsonValue>> &&field_values) : field_values_(std::move(field_values)) {
}

size_t JsonObject::field_count() const {
  return field_values_.size();
}

JsonValue JsonObject::extract_field(Slice name) {
  for (auto &field_value : field_values_) {
    if (field_value.first == name) {
      return std::move(field_value.second);
    }
  }
  return JsonValue();
}

Result<JsonValue> JsonObject::extract_optional_field(Slice name, JsonValueType type) {
  for (auto &field_value : field_values_) {
    if (field_value.first == name) {
      if (type != JsonValue::Type::Null && field_value.second.type() != type) {
        return Status::Error(400, PSLICE()
                                      << "Field \"" << name << "\" must be of type " << JsonValue::get_type_name(type));
      }

      return std::move(field_value.second);
    }
  }
  return JsonValue();
}

Result<JsonValue> JsonObject::extract_required_field(Slice name, JsonValueType type) {
  for (auto &field_value : field_values_) {
    if (field_value.first == name) {
      if (type != JsonValue::Type::Null && field_value.second.type() != type) {
        return Status::Error(400, PSLICE()
                                      << "Field \"" << name << "\" must be of type " << JsonValue::get_type_name(type));
      }

      return std::move(field_value.second);
    }
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << "\"");
}

const JsonValue *JsonObject::get_field(Slice name) const {
  for (auto &field_value : field_values_) {
    if (field_value.first == name) {
      return &field_value.second;
    }
  }
  return nullptr;
}

bool JsonObject::has_field(Slice name) const {
  return get_field(name) != nullptr;
}

Result<bool> JsonObject::get_optional_bool_field(Slice name, bool default_value) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::Boolean) {
      return value->get_boolean();
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type Boolean");
  }
  return default_value;
}

Result<bool> JsonObject::get_required_bool_field(Slice name) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::Boolean) {
      return value->get_boolean();
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type Boolean");
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << '"');
}

template <class T>
static Result<T> get_integer_field(Slice name, Slice value) {
  auto r_int = to_integer_safe<T>(value);
  if (r_int.is_ok()) {
    return r_int.ok();
  }
  return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a valid Number");
}

Result<int32> JsonObject::get_optional_int_field(Slice name, int32 default_value) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return get_integer_field<int32>(name, value->get_string());
    }
    if (value->type() == JsonValue::Type::Number) {
      return get_integer_field<int32>(name, value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a Number");
  }
  return default_value;
}

Result<int32> JsonObject::get_required_int_field(Slice name) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return get_integer_field<int32>(name, value->get_string());
    }
    if (value->type() == JsonValue::Type::Number) {
      return get_integer_field<int32>(name, value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a Number");
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << '"');
}

Result<int64> JsonObject::get_optional_long_field(Slice name, int64 default_value) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return get_integer_field<int64>(name, value->get_string());
    }
    if (value->type() == JsonValue::Type::Number) {
      return get_integer_field<int64>(name, value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a Number");
  }
  return default_value;
}

Result<int64> JsonObject::get_required_long_field(Slice name) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return get_integer_field<int64>(name, value->get_string());
    }
    if (value->type() == JsonValue::Type::Number) {
      return get_integer_field<int64>(name, value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a Number");
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << '"');
}

Result<double> JsonObject::get_optional_double_field(Slice name, double default_value) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::Number) {
      return to_double(value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type Number");
  }
  return default_value;
}

Result<double> JsonObject::get_required_double_field(Slice name) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::Number) {
      return to_double(value->get_number());
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type Number");
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << '"');
}

Result<string> JsonObject::get_optional_string_field(Slice name, string default_value) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return value->get_string().str();
    }
    if (value->type() == JsonValue::Type::Number) {
      return value->get_number().str();
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type String");
  }
  return std::move(default_value);
}

Result<string> JsonObject::get_required_string_field(Slice name) const {
  auto value = get_field(name);
  if (value != nullptr) {
    if (value->type() == JsonValue::Type::String) {
      return value->get_string().str();
    }
    if (value->type() == JsonValue::Type::Number) {
      return value->get_number().str();
    }
    return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type String");
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << '"');
}

void JsonObject::foreach(const std::function<void(Slice name, const JsonValue &value)> &callback) const {
  for (auto &field_value : field_values_) {
    callback(field_value.first, field_value.second);
  }
}

}  // namespace td
