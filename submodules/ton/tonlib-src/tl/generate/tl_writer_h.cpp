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
#include "tl_writer_h.h"

#include <cassert>
#include <utility>

namespace td {

std::string TD_TL_writer_h::forward_declaration(std::string type) {
  std::string prefix;
  std::string suffix;
  do {
    std::size_t pos = type.find("::");
    if (pos == std::string::npos) {
      return prefix + "class " + type + ";\n" + suffix;
    }
    std::string namespace_name = type.substr(0, pos);
    type = type.substr(pos + 2);
    prefix += "namespace " + namespace_name + " {\n";
    suffix += "}  // namespace " + namespace_name + "\n";
  } while (true);
  assert(false);
  return "";
}

std::string TD_TL_writer_h::gen_output_begin() const {
  std::string ext_include_str;
  for (auto &it : ext_include) {
    ext_include_str += "#include " + it + "\n";
  }
  if (!ext_include_str.empty()) {
    ext_include_str += "\n";
  }
  std::string ext_forward_declaration;
  for (auto &storer_name : get_storers()) {
    ext_forward_declaration += forward_declaration(storer_name);
  }
  for (auto &parser_name : get_parsers()) {
    ext_forward_declaration += forward_declaration(parser_name);
  }
  if (!ext_forward_declaration.empty()) {
    ext_forward_declaration += "\n";
  }
  return "#pragma once\n\n"
         "#include \"tl/TlObject.h\"\n\n"
         "#include \"td/utils/int_types.h\"\n\n" +
         ext_include_str +
         "#include <cstdint>\n"
         "#include <memory>\n"
         "#include <utility>\n"
         "#include <vector>\n\n" +
         ext_forward_declaration + "namespace ton {\n" + "namespace " + tl_name + "{\n" +
         "using BaseObject = ::ton::TlObject;\n\n"
         "template <class Type>\n"
         "using object_ptr = ::ton::tl_object_ptr<Type>;\n\n"
         "template <class Type, class... Args>\n"
         "object_ptr<Type> make_object(Args &&... args) {\n"
         "  return object_ptr<Type>(new Type(std::forward<Args>(args)...));\n"
         "}\n\n"

         "template <class ToType, class FromType>\n"
         "object_ptr<ToType> move_object_as(FromType &&from) {\n"
         "  return object_ptr<ToType>(static_cast<ToType *>(from.release()));\n"
         "}\n\n"

         "std::string to_string(const BaseObject &value);\n\n"

         "template <class T>\n"
         "std::string to_string(const object_ptr<T> &value) {\n"
         "  if (value == nullptr) {\n"
         "    return \"null\";\n"
         "  }\n"
         "\n"
         "  return to_string(*value);\n"
         "}\n\n";
}

std::string TD_TL_writer_h::gen_output_end() const {
  return "}  // namespace " + tl_name +
         "\n"
         "}  // namespace ton\n";
}

std::string TD_TL_writer_h::gen_field_definition(const std::string &class_name, const std::string &type_name,
                                                 const std::string &field_name) const {
  return "  " + type_name + (type_name.empty() || type_name[type_name.size() - 1] == ' ' ? "" : " ") + field_name +
         ";\n";
}

std::string TD_TL_writer_h::gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                                     std::vector<tl::var_description> &vars) const {
  return "";
}

std::string TD_TL_writer_h::gen_function_vars(const tl::tl_combinator *t,
                                              std::vector<tl::var_description> &vars) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    vars[i].index = static_cast<int>(i);
    vars[i].is_stored = false;
    vars[i].is_type = false;
    vars[i].parameter_num = -1;
    vars[i].function_arg_num = -1;
  }

  for (std::size_t i = 0; i < t->args.size(); i++) {
    const tl::arg &a = t->args[i];

    int arg_type = a.type->get_type();
    if (arg_type == tl::NODE_TYPE_VAR_TYPE) {
      const tl::tl_tree_var_type *var_type = static_cast<const tl::tl_tree_var_type *>(a.type);
      assert(a.flags & tl::FLAG_EXCL);
      assert(var_type->var_num >= 0);
      assert(!vars[var_type->var_num].is_type);
      vars[var_type->var_num].is_type = true;
      vars[var_type->var_num].function_arg_num = static_cast<int>(i);
    }
  }

  std::string res;
  for (std::size_t i = 0; i < vars.size(); i++) {
    if (!vars[i].is_type) {
      assert(vars[i].parameter_num == -1);
      assert(vars[i].function_arg_num == -1);
      assert(vars[i].is_stored == false);
      res += "  mutable " + gen_class_name("#") + " " + gen_var_name(vars[i]) + ";\n";
    }
  }
  return res;
}

std::string TD_TL_writer_h::gen_flags_definitions(const tl::tl_combinator *t) const {
  std::vector<std::pair<std::string, std::int32_t>> flags;

  for (std::size_t i = 0; i < t->args.size(); i++) {
    const tl::arg &a = t->args[i];

    if (a.exist_var_num != -1) {
      auto name = a.name;
      for (auto &c : name) {
        c = to_upper(c);
      }
      flags.push_back(std::make_pair(name, a.exist_var_bit));
    }
  }
  std::string res;
  if (!flags.empty()) {
    res += "  enum Flags : std::int32_t {";
    bool first = true;
    for (auto &p : flags) {
      if (first) {
        first = false;
      } else {
        res += ", ";
      }
      res += p.first + "_MASK = " + int_to_string(1 << p.second);
    }
    res += "};\n";
  }
  return res;
}

std::string TD_TL_writer_h::gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                                    bool check_negative) const {
  return "";
}

std::string TD_TL_writer_h::gen_constructor_id_store(std::int32_t id, int storer_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars,
                                            bool flat, int parser_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_field_store(const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                                            int storer_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                           const std::vector<tl::var_description> &vars, int parser_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                           const std::vector<tl::var_description> &vars, int storer_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_var_type_fetch(const tl::arg &a) const {
  assert(false);
  return "";
}

std::string TD_TL_writer_h::gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const {
  return "class " + class_name + ";\n\n";
}

std::string TD_TL_writer_h::gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                            bool is_proxy) const {
  return "class " + class_name + (!is_proxy ? " final " : "") + ": public " + base_class_name +
         " {\n"
         " public:\n";
}

std::string TD_TL_writer_h::gen_class_end() const {
  return "};\n\n";
}

std::string TD_TL_writer_h::gen_class_alias(const std::string &class_name, const std::string &alias_name) const {
  return "";
  //  return "typedef " + class_name + " " + alias_name + ";\n\n\n";
}

std::string TD_TL_writer_h::gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const {
  if (is_proxy) {
    if (class_name == gen_base_tl_class_name()) {
      return "\n  virtual std::int32_t get_id() const = 0;\n";
    }

    return "";
  }

  return "\n"
         "  static const std::int32_t ID = " +
         int_to_string(id) +
         ";\n"
         "  std::int32_t get_id() const final {\n"
         "    return ID;\n"
         "  }\n";
}

std::string TD_TL_writer_h::gen_function_result_type(const tl::tl_tree *result) const {
  assert(result->get_type() == tl::NODE_TYPE_TYPE);
  const tl::tl_tree_type *result_type = static_cast<const tl::tl_tree_type *>(result);
  std::string fetched_type = gen_type_name(result_type);

  if (!fetched_type.empty() && fetched_type[fetched_type.size() - 1] == ' ') {
    fetched_type.pop_back();
  }

  return "\n"
         "  using ReturnType = " +
         fetched_type + ";\n";
}

std::string TD_TL_writer_h::gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                                     const std::string &parent_class_name, int arity,
                                                     std::vector<tl::var_description> &vars, int parser_type) const {
  std::string returned_type = "object_ptr<" + parent_class_name + "> ";

  if (parser_type == 0) {
    return "\n"
           "  static " +
           returned_type + "fetch(" + parser_name + " &p);\n\n" + "  explicit " + class_name + "(" + parser_name +
           " &p);\n";
  }

  assert(arity == 0);
  return "\n"
         "  static " +
         returned_type + "fetch(" + parser_name + " &p);\n";
}

std::string TD_TL_writer_h::gen_fetch_function_end(bool has_parent, int field_num,
                                                   const std::vector<tl::var_description> &vars,
                                                   int parser_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_function_result_begin(const std::string &parser_name,
                                                            const std::string &class_name,
                                                            const tl::tl_tree *result) const {
  return "\n"
         "  static ReturnType fetch_result(" +
         parser_name + " &p);\n";
}

std::string TD_TL_writer_h::gen_fetch_function_result_end() const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_function_result_any_begin(const std::string &parser_name,
                                                                const std::string &class_name, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_function_result_any_end(bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_h::gen_store_function_begin(const std::string &storer_name, const std::string &class_name,
                                                     int arity, std::vector<tl::var_description> &vars,
                                                     int storer_type) const {
  assert(arity == 0);
  if (storer_type == -1) {
    return "";
  }
  return "\n"
         "  void store(" +
         storer_name + " &s" + std::string(storer_type == 0 ? "" : ", const char *field_name") + ") const final;\n";
}

std::string TD_TL_writer_h::gen_store_function_end(const std::vector<tl::var_description> &vars,
                                                   int storer_type) const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_switch_begin() const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const {
  return "";
}

std::string TD_TL_writer_h::gen_fetch_switch_end() const {
  return "";
}

std::string TD_TL_writer_h::gen_constructor_begin(int fields_num, const std::string &class_name,
                                                  bool is_default) const {
  return "\n"
         "  " +
         std::string(fields_num == 1 ? "explicit " : "") + class_name + "(";
}

std::string TD_TL_writer_h::gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                                       bool is_default) const {
  return "";
}

std::string TD_TL_writer_h::gen_constructor_end(const tl::tl_combinator *t, int fields_num, bool is_default) const {
  return ");\n";
}

}  // namespace td
