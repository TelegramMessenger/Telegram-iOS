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
#include "tl_writer_java.h"

#include <cassert>

namespace td {

const int TD_TL_writer_java::MAX_ARITY;

const std::string TD_TL_writer_java::base_type_class_names[MAX_ARITY + 1] = {"Object"};
const std::string TD_TL_writer_java::base_tl_class_name = "Object";
const std::string TD_TL_writer_java::base_function_class_name = "Function";

int TD_TL_writer_java::get_max_arity() const {
  return MAX_ARITY;
}

bool TD_TL_writer_java::is_built_in_simple_type(const std::string &name) const {
  return name == "Bool" || name == "Int32" || name == "Int53" || name == "Int64" || name == "Double" ||
         name == "String" || name == "Bytes" || name == "SecureString" || name == "SecureBytes" || name == "Object" ||
         name == "Function";
}

bool TD_TL_writer_java::is_built_in_complex_type(const std::string &name) const {
  return name == "Vector";
}

bool TD_TL_writer_java::is_type_bare(const tl::tl_type *t) const {
  return t->simple_constructors == 1 || (is_built_in_simple_type(t->name) && t->name != "Bool") ||
         is_built_in_complex_type(t->name);
}

bool TD_TL_writer_java::is_combinator_supported(const tl::tl_combinator *constructor) const {
  if (!TL_writer::is_combinator_supported(constructor)) {
    return false;
  }

  for (std::size_t i = 0; i < constructor->args.size(); i++) {
    if (constructor->args[i].type->get_type() == tl::NODE_TYPE_VAR_TYPE) {
      return false;
    }
  }

  return true;
}

int TD_TL_writer_java::get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const {
  return 0;
}

int TD_TL_writer_java::get_storer_type(const tl::tl_combinator *t, const std::string &storer_name) const {
  return 0;
}

std::vector<std::string> TD_TL_writer_java::get_parsers() const {
  std::vector<std::string> parsers;
  parsers.push_back("<inlined>");
  return parsers;
}

std::vector<std::string> TD_TL_writer_java::get_storers() const {
  return std::vector<std::string>();
}

std::string TD_TL_writer_java::gen_base_tl_class_name() const {
  return base_tl_class_name;
}

std::string TD_TL_writer_java::gen_base_type_class_name(int arity) const {
  assert(arity == 0);
  return base_type_class_names[arity];
}

std::string TD_TL_writer_java::gen_base_function_class_name() const {
  return base_function_class_name;
}

std::string TD_TL_writer_java::gen_class_name(std::string name) const {
  if (name == "Object" || name == "#") {
    assert(false);
  }
  bool next_to_upper = true;
  std::string result;
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      next_to_upper = true;
      continue;
    }
    if (next_to_upper) {
      result += to_upper(name[i]);
      next_to_upper = false;
    } else {
      result += name[i];
    }
  }
  return result;
}

std::string TD_TL_writer_java::gen_field_name(std::string name) const {
  assert(name.size() > 0);
  assert(is_alnum(name.back()));

  bool next_to_upper = false;
  std::string result;
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      next_to_upper = true;
      continue;
    }
    if (next_to_upper) {
      result += to_upper(name[i]);
      next_to_upper = false;
    } else {
      result += name[i];
    }
  }
  return result;
}

std::string TD_TL_writer_java::gen_var_name(const tl::var_description &desc) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer_java::gen_parameter_name(int index) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer_java::gen_type_name(const tl::tl_tree_type *tree_type) const {
  const tl::tl_type *t = tree_type->type;
  const std::string &name = t->name;

  if (name == "#") {
    assert(false);
  }
  if (name == "Bool") {
    return "boolean";
  }
  if (name == "Int32") {
    return "int";
  }
  if (name == "Int53" || name == "Int64") {
    return "long";
  }
  if (name == "Double") {
    return "double";
  }
  if (name == "String" || name == "SecureString") {
    return "String";
  }
  if (name == "Bytes" || name == "SecureBytes") {
    return "byte[]";
  }
  if (name == "Object") {
    return gen_base_type_class_name(0);
  }
  if (name == "Function") {
    return gen_base_function_class_name();
  }

  if (name == "Vector") {
    assert(t->arity == 1);
    assert(tree_type->children.size() == 1);
    assert(tree_type->children[0]->get_type() == tl::NODE_TYPE_TYPE);
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

    return gen_type_name(child) + "[]";
  }

  assert(!is_built_in_simple_type(name) && !is_built_in_complex_type(name));

  for (std::size_t i = 0; i < tree_type->children.size(); i++) {
    assert(tree_type->children[i]->get_type() == tl::NODE_TYPE_NAT_CONST);
  }

  return gen_main_class_name(t);
}

std::string TD_TL_writer_java::gen_array_type_name(const tl::tl_tree_array *arr, const std::string &field_name) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer_java::gen_var_type_name() const {
  return gen_base_function_class_name();
}

std::string TD_TL_writer_java::gen_int_const(const tl::tl_tree *tree_c,
                                             const std::vector<tl::var_description> &vars) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer_java::gen_output_begin() const {
  return "package " + package_name +
         ";\n\n"
         "public class " +
         tl_name + " {\n";
}

std::string TD_TL_writer_java::gen_output_end() const {
  return "}\n";
}

std::string TD_TL_writer_java::gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_java::gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                               bool is_proxy) const {
  std::string full_class_name = "static class " + class_name;
  if (class_name != gen_base_tl_class_name()) {
    full_class_name += " extends " + base_class_name;
  }
  std::string result = "    public " + std::string(is_proxy ? "abstract " : "") + full_class_name + " {\n";
  if (class_name == gen_base_tl_class_name() || class_name == gen_base_function_class_name()) {
    result += "        public native String toString();\n";
  }

  return result;
}

std::string TD_TL_writer_java::gen_class_end() const {
  return "    }\n\n";
}

std::string TD_TL_writer_java::gen_class_alias(const std::string &class_name, const std::string &alias_name) const {
  return "";
}

std::string TD_TL_writer_java::gen_field_definition(const std::string &class_name, const std::string &type_name,
                                                    const std::string &field_name) const {
  return "        public " + type_name + " " + field_name + ";\n";
}

std::string TD_TL_writer_java::gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                                        std::vector<tl::var_description> &vars) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    vars[i].index = static_cast<int>(i);
    vars[i].is_stored = false;
    vars[i].is_type = false;
    vars[i].parameter_num = -1;
    vars[i].function_arg_num = -1;
  }

  if (result_type != nullptr) {
    assert(result_type->children.empty());
  }

  for (std::size_t i = 0; i < t->args.size(); i++) {
    assert(t->args[i].type->get_type() != tl::NODE_TYPE_VAR_TYPE);
  }

  for (std::size_t i = 0; i < vars.size(); i++) {
    assert(vars[i].is_type);
  }
  return "";
}

std::string TD_TL_writer_java::gen_function_vars(const tl::tl_combinator *t,
                                                 std::vector<tl::var_description> &vars) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    vars[i].index = static_cast<int>(i);
    vars[i].is_stored = false;
    vars[i].is_type = false;
    vars[i].parameter_num = -1;
    vars[i].function_arg_num = -1;
  }

  for (std::size_t i = 0; i < t->args.size(); i++) {
    assert(t->args[i].type->get_type() != tl::NODE_TYPE_VAR_TYPE);
  }

  for (std::size_t i = 0; i < vars.size(); i++) {
    assert(vars[i].is_type);
  }
  return "";
}

std::string TD_TL_writer_java::gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                                       bool check_negative) const {
  assert(result_type->children.empty());
  return "";
}

std::string TD_TL_writer_java::gen_constructor_id_store(std::int32_t id, int storer_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars,
                                               bool flat, int parser_type) const {
  assert(parser_type >= 0);

  assert(a.exist_var_num == -1);
  assert(a.type->get_type() != tl::NODE_TYPE_VAR_TYPE);

  assert(!(a.flags & tl::FLAG_EXCL));
  assert(!(a.flags & tl::FLAG_OPT_VAR));

  if (flat) {
    //    TODO
    //    return gen_field_fetch(const tl::arg &a, std::vector<tl::var_description> &vars, int num, bool flat);
  }

  assert(a.var_num == -1);
  assert(a.type->get_type() == tl::NODE_TYPE_TYPE);
  return "";
}

std::string TD_TL_writer_java::gen_field_store(const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                                               int storer_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                              const std::vector<tl::var_description> &vars, int parser_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                              const std::vector<tl::var_description> &vars, int storer_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_var_type_fetch(const tl::arg &a) const {
  assert(false);
  return "";
}

std::string TD_TL_writer_java::gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const {
  if (is_proxy) {
    return class_name == gen_base_tl_class_name() ? "\n        public abstract int getConstructor();\n" : "";
  }

  return "\n"
         "        public static final int CONSTRUCTOR = " +
         int_to_string(id) +
         ";\n\n"
         "        @Override\n"
         "        public int getConstructor() {\n"
         "            return CONSTRUCTOR;\n"
         "        }\n";
}

std::string TD_TL_writer_java::gen_function_result_type(const tl::tl_tree *result) const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                                        const std::string &parent_class_name, int arity,
                                                        std::vector<tl::var_description> &vars, int parser_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_end(bool has_parent, int field_num,
                                                      const std::vector<tl::var_description> &vars,
                                                      int parser_type) const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_result_begin(const std::string &parser_name,
                                                               const std::string &class_name,
                                                               const tl::tl_tree *result) const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_result_end() const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_result_any_begin(const std::string &parser_name,
                                                                   const std::string &class_name, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_function_result_any_end(bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_java::gen_store_function_begin(const std::string &storer_name, const std::string &class_name,
                                                        int arity, std::vector<tl::var_description> &vars,
                                                        int storer_type) const {
  assert(false);
  return "";
}

std::string TD_TL_writer_java::gen_store_function_end(const std::vector<tl::var_description> &vars,
                                                      int storer_type) const {
  assert(false);
  return "";
}

std::string TD_TL_writer_java::gen_fetch_switch_begin() const {
  return "";
}

std::string TD_TL_writer_java::gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const {
  assert(arity == 0);
  return "";
}

std::string TD_TL_writer_java::gen_fetch_switch_end() const {
  return "";
}

std::string TD_TL_writer_java::gen_constructor_begin(int fields_num, const std::string &class_name,
                                                     bool is_default) const {
  return "\n"
         "        public " +
         class_name + "(";
}

std::string TD_TL_writer_java::gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                                         bool is_default) const {
  if (is_default) {
    return "";
  }

  std::string field_type = gen_field_type(a);
  if (field_type.empty()) {
    return "";
  }

  if (field_type[field_type.size() - 1] != ' ') {
    field_type += ' ';
  }

  return (field_num == 0 ? "" : ", ") + field_type + gen_field_name(a.name);
}

std::string TD_TL_writer_java::gen_constructor_field_init(int field_num, const std::string &class_name,
                                                          const tl::arg &a, bool is_default) const {
  std::string field_type = gen_field_type(a);
  if (field_type.empty()) {
    return "";
  }

  if (is_default) {
    return (field_num == 0 ? ") {\n" : "");
  }

  return std::string(field_num == 0 ? ") {\n" : "") + "            this." + gen_field_name(a.name) + " = " +
         gen_field_name(a.name) + ";\n";
}

std::string TD_TL_writer_java::gen_constructor_end(const tl::tl_combinator *t, int fields_num, bool is_default) const {
  if (fields_num == 0) {
    return ") {\n"
           "        }\n";
  }
  return "        }\n";
}

}  // namespace td
