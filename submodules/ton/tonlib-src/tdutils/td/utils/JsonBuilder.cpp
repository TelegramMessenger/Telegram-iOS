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
#include "td/utils/JsonBuilder.h"

#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"

#include <cstring>

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
          int a = s[pos];
          CHECK((a & 0x40) != 0);

          CHECK(pos + 1 < len);
          int b = s[++pos];
          CHECK((b & 0xc0) == 0x80);
          if ((a & 0x20) == 0) {
            CHECK((a & 0x1e) > 0);
            sb << JsonChar(((a & 0x1f) << 6) | (b & 0x3f));
            break;
          }

          CHECK(pos + 1 < len);
          int c = s[++pos];
          CHECK((c & 0xc0) == 0x80);
          if ((a & 0x10) == 0) {
            CHECK(((a & 0x0f) | (b & 0x20)) > 0);
            sb << JsonChar(((a & 0x0f) << 12) | ((b & 0x3f) << 6) | (c & 0x3f));
            break;
          }

          CHECK(pos + 1 < len);
          int d = s[++pos];
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
  auto *cur_src = parser.data().data();
  auto *end_src = parser.data().end();
  auto *end = cur_src;
  while (end < end_src && end[0] != '"') {
    if (end[0] == '\\') {
      end++;
    }
    end++;
  }
  if (end >= end_src) {
    return Status::Error("Closing '\"' not found");
  }
  parser.advance(end + 1 - cur_src);
  end_src = end;

  auto *cur_dest = cur_src;
  auto *begin_dest = cur_src;

  while (cur_src != end_src) {
    auto *slash = static_cast<char *>(std::memchr(cur_src, '\\', end_src - cur_src));
    if (slash == nullptr) {
      slash = end_src;
    }
    std::memmove(cur_dest, cur_src, slash - cur_src);
    cur_dest += slash - cur_src;
    cur_src = slash;
    if (cur_src != end_src) {
      cur_src++;
      if (cur_src == end_src) {
        // TODO UNREACHABLE();
        return Status::Error("Unexpected end of string");
      }
      switch (*cur_src) {
        case '"':
        case '\\':
        case '/':
          *cur_dest++ = *cur_src++;
          break;
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
          if (cur_src + 4 > end_src) {
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
            if (cur_src + 6 <= end_src && cur_src[0] == '\\' && cur_src[1] == 'u') {
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

          if (num < 128) {
            *cur_dest++ = static_cast<char>(num);
          } else if (num < 0x800) {
            *cur_dest++ = static_cast<char>(0xc0 + (num >> 6));
            *cur_dest++ = static_cast<char>(0x80 + (num & 63));
          } else if (num <= 0xffff) {
            *cur_dest++ = static_cast<char>(0xe0 + (num >> 12));
            *cur_dest++ = static_cast<char>(0x80 + ((num >> 6) & 63));
            *cur_dest++ = static_cast<char>(0x80 + (num & 63));
          } else {
            *cur_dest++ = static_cast<char>(0xf0 + (num >> 18));
            *cur_dest++ = static_cast<char>(0x80 + ((num >> 12) & 63));
            *cur_dest++ = static_cast<char>(0x80 + ((num >> 6) & 63));
            *cur_dest++ = static_cast<char>(0x80 + (num & 63));
          }
          break;
        }
      }
    }
  }
  CHECK(cur_dest <= end_src);
  return MutableSlice(begin_dest, cur_dest);
}

Status json_string_skip(Parser &parser) {
  if (!parser.try_skip('"')) {
    return Status::Error("Opening '\"' expected");
  }
  auto *begin_src = parser.data().data();
  auto *cur_src = begin_src;
  auto *end_src = parser.data().end();
  auto *end = cur_src;
  while (end < end_src && *end != '"') {
    if (*end == '\\') {
      end++;
    }
    end++;
  }
  if (end >= end_src) {
    return Status::Error("Closing '\"' not found");
  }
  parser.advance(end + 1 - cur_src);
  end_src = end;

  while (cur_src != end_src) {
    auto *slash = static_cast<char *>(std::memchr(cur_src, '\\', end_src - cur_src));
    if (slash == nullptr) {
      slash = end_src;
    }
    cur_src = slash;
    if (cur_src != end_src) {
      cur_src++;
      if (cur_src == end_src) {
        // TODO UNREACHABLE();
        return Status::Error("Unexpected end of string");
      }
      switch (*cur_src) {
        case '"':
        case '\\':
        case '/':
        case 'b':
        case 'f':
        case 'n':
        case 'r':
        case 't':
          cur_src++;
          break;
        case 'u': {
          cur_src++;
          if (cur_src + 4 > end_src) {
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
            if (cur_src + 6 <= end_src && cur_src[0] == '\\' && cur_src[1] == 'u') {
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
      }
    }
  }
  return Status::OK();
}

Result<JsonValue> do_json_decode(Parser &parser, int32 max_depth) {
  if (max_depth < 0) {
    return Status::Error("Too big object depth");
  }

  parser.skip_whitespaces();
  switch (parser.peek_char()) {
    case 'f':
      if (parser.skip_start_with("false")) {
        return JsonValue::create_boolean(false);
      }
      return Status::Error("Token starts with 'f' -- false expected");
    case 't':
      if (parser.skip_start_with("true")) {
        return JsonValue::create_boolean(true);
      }
      return Status::Error("Token starts with 't' -- true expected");
    case 'n':
      if (parser.skip_start_with("null")) {
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
      std::vector<JsonValue> res;
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
      std::vector<std::pair<MutableSlice, JsonValue> > res;
      if (parser.try_skip('}')) {
        return JsonValue::make_object(std::move(res));
      }
      while (true) {
        if (parser.empty()) {
          return Status::Error("Unexpected string end");
        }
        TRY_RESULT(key, json_string_decode(parser));
        parser.skip_whitespaces();
        if (!parser.try_skip(':')) {
          return Status::Error("':' expected");
        }
        TRY_RESULT(value, do_json_decode(parser, max_depth - 1));
        res.emplace_back(std::move(key), std::move(value));

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
      return JsonValue::make_object(std::move(res));
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
      if (parser.skip_start_with("false")) {
        return Status::OK();
      }
      return Status::Error("Starts with 'f' -- false expected");
    case 't':
      if (parser.skip_start_with("true")) {
        return Status::OK();
      }
      return Status::Error("Starts with 't' -- true expected");
    case 'n':
      if (parser.skip_start_with("null")) {
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

bool has_json_object_field(const JsonObject &object, Slice name) {
  for (auto &field_value : object) {
    if (field_value.first == name) {
      return true;
    }
  }
  return false;
}

Result<JsonValue> get_json_object_field(JsonObject &object, Slice name, JsonValue::Type type, bool is_optional) {
  for (auto &field_value : object) {
    if (field_value.first == name) {
      if (type != JsonValue::Type::Null && field_value.second.type() != type) {
        return Status::Error(400, PSLICE()
                                      << "Field \"" << name << "\" must be of type " << JsonValue::get_type_name(type));
      }

      return std::move(field_value.second);
    }
  }
  if (!is_optional) {
    return Status::Error(400, PSLICE() << "Can't find field \"" << name << "\"");
  }
  return JsonValue();
}

Result<bool> get_json_object_bool_field(JsonObject &object, Slice name, bool is_optional, bool default_value) {
  TRY_RESULT(value, get_json_object_field(object, name, JsonValue::Type::Boolean, is_optional));
  if (value.type() == JsonValue::Type::Null) {
    return default_value;
  }
  return value.get_boolean();
}

Result<int32> get_json_object_int_field(JsonObject &object, Slice name, bool is_optional, int32 default_value) {
  for (auto &field_value : object) {
    if (field_value.first == name) {
      if (field_value.second.type() == JsonValue::Type::String) {
        return to_integer_safe<int32>(field_value.second.get_string());
      }
      if (field_value.second.type() == JsonValue::Type::Number) {
        return to_integer_safe<int32>(field_value.second.get_number());
      }

      return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type Number");
    }
  }
  if (is_optional) {
    return default_value;
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << "\"");
}

Result<int64> get_json_object_long_field(JsonObject &object, Slice name, bool is_optional, int64 default_value) {
  for (auto &field_value : object) {
    if (field_value.first == name) {
      if (field_value.second.type() == JsonValue::Type::String) {
        return to_integer_safe<int64>(field_value.second.get_string());
      }
      if (field_value.second.type() == JsonValue::Type::Number) {
        return to_integer_safe<int64>(field_value.second.get_number());
      }

      return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be a Number");
    }
  }
  if (is_optional) {
    return default_value;
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << "\"");
}

Result<double> get_json_object_double_field(JsonObject &object, Slice name, bool is_optional, double default_value) {
  TRY_RESULT(value, get_json_object_field(object, name, JsonValue::Type::Number, is_optional));
  if (value.type() == JsonValue::Type::Null) {
    return default_value;
  }
  return to_double(value.get_number());
}

Result<string> get_json_object_string_field(JsonObject &object, Slice name, bool is_optional, string default_value) {
  for (auto &field_value : object) {
    if (field_value.first == name) {
      if (field_value.second.type() == JsonValue::Type::String) {
        return field_value.second.get_string().str();
      }
      if (field_value.second.type() == JsonValue::Type::Number) {
        return field_value.second.get_number().str();
      }

      return Status::Error(400, PSLICE() << "Field \"" << name << "\" must be of type String");
    }
  }
  if (is_optional) {
    return default_value;
  }
  return Status::Error(400, PSLICE() << "Can't find field \"" << name << "\"");
}

}  // namespace td
