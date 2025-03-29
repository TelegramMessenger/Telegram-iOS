//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_json_converter.h"

#include "td/tl/tl_simple.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

using Mode = tl::TL_writer::Mode;

static bool need_bytes(const tl::simple::Type *type) {
  return type->type == tl::simple::Type::Bytes ||
         (type->type == tl::simple::Type::Vector && need_bytes(type->vector_value_type));
}

template <class T>
void gen_to_json_constructor(StringBuilder &sb, const T *constructor, bool is_header) {
  sb << "void to_json(JsonValueScope &jv, "
     << "const td_api::" << tl::simple::gen_cpp_name(constructor->name) << " &object)";
  if (is_header) {
    sb << ";\n\n";
    return;
  }
  sb << " {\n";
  sb << "  auto jo = jv.enter_object();\n";
  sb << "  jo(\"@type\", \"" << tl::simple::gen_cpp_name(constructor->name) << "\");\n";
  for (auto &arg : constructor->args) {
    auto field_name = tl::simple::gen_cpp_field_name(arg.name);
    bool is_custom = arg.type->type == tl::simple::Type::Custom;

    auto object = PSTRING() << "object." << field_name;
    if (is_custom) {
      sb << "  if (" << object << ") {\n  ";
    }
    if (arg.type->type == tl::simple::Type::Bytes) {
      object = PSTRING() << "base64_encode(" << object << ")";
    } else if (need_bytes(arg.type)) {
      object = "UNSUPPORTED STORED VECTOR OF BYTES";
    } else if (arg.type->type == tl::simple::Type::Bool) {
      object = PSTRING() << "JsonBool{" << object << "}";
    } else if (arg.type->type == tl::simple::Type::Int64) {
      object = PSTRING() << "JsonInt64{" << object << "}";
    } else if (arg.type->type == tl::simple::Type::Vector &&
               arg.type->vector_value_type->type == tl::simple::Type::Int64) {
      object = PSTRING() << "JsonVectorInt64{" << object << "}";
    }
    if (is_custom) {
      sb << "  jo(\"" << arg.name << "\", ToJson(*" << object << "));\n";
    } else if (arg.type->type == tl::simple::Type::Int64 || arg.type->type == tl::simple::Type::Vector) {
      sb << "  jo(\"" << arg.name << "\", ToJson(" << object << "));\n";
    } else {
      sb << "  jo(\"" << arg.name << "\", " << object << ");\n";
    }
    if (is_custom) {
      sb << "  }\n";
    }
  }
  sb << "}\n\n";
}

void gen_to_json(StringBuilder &sb, const tl::simple::Schema &schema, bool is_header, Mode mode) {
  for (auto *custom_type : schema.custom_types) {
    if (!((custom_type->is_query_ && mode != Mode::Server) || (custom_type->is_result_ && mode != Mode::Client))) {
      continue;
    }
    if (custom_type->constructors.size() > 1) {
      auto type_name = tl::simple::gen_cpp_name(custom_type->name);
      sb << "void to_json(JsonValueScope &jv, const td_api::" << type_name << " &object)";
      if (is_header) {
        sb << ";\n\n";
      } else {
        sb << " {\n"
           << "  td_api::downcast_call(const_cast<td_api::" << type_name
           << " &>(object), [&jv](const auto &object) { "
              "to_json(jv, object); });\n"
           << "}\n\n";
      }
    }
    for (auto *constructor : custom_type->constructors) {
      gen_to_json_constructor(sb, constructor, is_header);
    }
  }
  if (mode == Mode::Server) {
    return;
  }
  for (auto *function : schema.functions) {
    gen_to_json_constructor(sb, function, is_header);
  }
}

template <class T>
void gen_from_json_constructor(StringBuilder &sb, const T *constructor, bool is_header) {
  sb << "Status from_json(td_api::" << tl::simple::gen_cpp_name(constructor->name) << " &to, JsonObject &from)";
  if (is_header) {
    sb << ";\n\n";
  } else {
    sb << " {\n";
    for (auto &arg : constructor->args) {
      sb << "  TRY_STATUS(from_json" << (need_bytes(arg.type) ? "_bytes" : "") << "(to."
         << tl::simple::gen_cpp_field_name(arg.name) << ", from.extract_field(\"" << tl::simple::gen_cpp_name(arg.name)
         << "\")));\n";
    }
    sb << "  return Status::OK();\n";
    sb << "}\n\n";
  }
}

void gen_from_json(StringBuilder &sb, const tl::simple::Schema &schema, bool is_header, Mode mode) {
  for (auto *custom_type : schema.custom_types) {
    if (!((custom_type->is_query_ && mode != Mode::Client) || (custom_type->is_result_ && mode != Mode::Server))) {
      continue;
    }
    for (auto *constructor : custom_type->constructors) {
      gen_from_json_constructor(sb, constructor, is_header);
    }
  }
  if (mode == Mode::Client) {
    return;
  }
  for (auto *function : schema.functions) {
    gen_from_json_constructor(sb, function, is_header);
  }
}

using Vec = std::vector<std::pair<int32, std::string>>;
void gen_tl_constructor_from_string(StringBuilder &sb, Slice name, const Vec &vec, bool is_header) {
  sb << "Result<int32> tl_constructor_from_string(td_api::" << name << " *object, const std::string &str)";
  if (is_header) {
    sb << ";\n\n";
    return;
  }
  sb << " {\n";
  sb << "  static const FlatHashMap<Slice, int32, SliceHash> m = {\n";

  bool is_first = true;
  for (auto &p : vec) {
    if (is_first) {
      is_first = false;
    } else {
      sb << ",\n";
    }
    sb << "    {\"" << p.second << "\", " << p.first << "}";
  }
  sb << "\n  };\n";
  sb << "  auto it = m.find(str);\n";
  sb << "  if (it == m.end()) {\n"
     << "    return Status::Error(PSLICE() << \"Unknown class \\\"\" << str << \"\\\"\");\n"
     << "  }\n"
     << "  return it->second;\n";
  sb << "}\n\n";
}

void gen_tl_constructor_from_string(StringBuilder &sb, const tl::simple::Schema &schema, bool is_header, Mode mode) {
  Vec vec_for_nullary;
  for (auto *custom_type : schema.custom_types) {
    if (!((custom_type->is_query_ && mode != Mode::Client) || (custom_type->is_result_ && mode != Mode::Server))) {
      continue;
    }
    Vec vec;
    for (auto *constructor : custom_type->constructors) {
      vec.emplace_back(constructor->id, constructor->name);
      vec_for_nullary.push_back(vec.back());
    }

    if (vec.size() > 1) {
      gen_tl_constructor_from_string(sb, tl::simple::gen_cpp_name(custom_type->name), vec, is_header);
    }
  }
  gen_tl_constructor_from_string(sb, "Object", vec_for_nullary, is_header);

  if (mode == Mode::Client) {
    return;
  }
  Vec vec_for_function;
  for (auto *function : schema.functions) {
    vec_for_function.emplace_back(function->id, function->name);
  }
  gen_tl_constructor_from_string(sb, "Function", vec_for_function, is_header);
}

void gen_json_converter_file(const tl::simple::Schema &schema, const std::string &file_name_base, bool is_header,
                             Mode mode) {
  auto file_name = is_header ? file_name_base + ".h" : file_name_base + ".cpp";
  auto old_file_content = [&] {
    auto r_content = read_file(file_name);
    if (r_content.is_error()) {
      return BufferSlice();
    }
    return r_content.move_as_ok();
  }();

  std::string buf(2000000, ' ');
  StringBuilder sb(buf);

  if (is_header) {
    sb << "#pragma once\n\n";

    sb << "#include \"td/telegram/td_api.h\"\n\n";

    sb << "#include \"td/utils/JsonBuilder.h\"\n";
    sb << "#include \"td/utils/Status.h\"\n\n";
  } else {
    sb << "#include \"" << file_name_base << ".h\"\n\n";

    sb << "#include \"td/telegram/td_api.h\"\n";
    sb << "#include \"td/telegram/td_api.hpp\"\n\n";

    sb << "#include \"td/tl/tl_json.h\"\n\n";

    sb << "#include \"td/utils/base64.h\"\n";
    sb << "#include \"td/utils/common.h\"\n";
    sb << "#include \"td/utils/FlatHashMap.h\"\n";
    sb << "#include \"td/utils/Slice.h\"\n\n";

    sb << "#include <functional>\n\n";
  }
  sb << "namespace td {\n";
  sb << "namespace td_api {\n";
  if (is_header) {
    sb << "\nvoid to_json(JsonValueScope &jv, const tl_object_ptr<Object> &value);\n";
    sb << "\nStatus from_json(tl_object_ptr<Function> &to, td::JsonValue from);\n";
    sb << "\nvoid to_json(JsonValueScope &jv, const Object &object);\n";
    sb << "\nvoid to_json(JsonValueScope &jv, const Function &object);\n\n";
  } else {
    sb << R"ABCD(
void to_json(JsonValueScope &jv, const tl_object_ptr<Object> &value) {
  td::to_json(jv, std::move(value));
}

Status from_json(tl_object_ptr<Function> &to, td::JsonValue from) {
  return td::from_json(to, std::move(from));
}

template <class T>
auto lazy_to_json(JsonValueScope &jv, const T &t) -> decltype(td_api::to_json(jv, t)) {
  return td_api::to_json(jv, t);
}

template <class T>
void lazy_to_json(std::reference_wrapper<JsonValueScope>, const T &t) {
  UNREACHABLE();
}

void to_json(JsonValueScope &jv, const Object &object) {
  downcast_call(const_cast<Object &>(object), [&jv](const auto &object) { lazy_to_json(jv, object); });
}

void to_json(JsonValueScope &jv, const Function &object) {
  downcast_call(const_cast<Function &>(object), [&jv](const auto &object) { lazy_to_json(jv, object); });
}

)ABCD";
  }
  gen_tl_constructor_from_string(sb, schema, is_header, mode);
  gen_from_json(sb, schema, is_header, mode);
  gen_to_json(sb, schema, is_header, mode);
  sb << "}  // namespace td_api\n";
  sb << "}  // namespace td\n";

  CHECK(!sb.is_error());
  buf.resize(sb.as_cslice().size());
#if TD_WINDOWS
  string new_file_content;
  for (auto c : buf) {
    if (c == '\n') {
      new_file_content += '\r';
    }
    new_file_content += c;
  }
#else
  auto new_file_content = std::move(buf);
#endif
  if (new_file_content != old_file_content.as_slice()) {
    write_file(file_name, new_file_content).ensure();
  }
}

void gen_json_converter(const tl::tl_config &config, const std::string &file_name, Mode mode) {
  tl::simple::Schema schema(config);
  gen_json_converter_file(schema, file_name, true, mode);
  gen_json_converter_file(schema, file_name, false, mode);
}

}  // namespace td
