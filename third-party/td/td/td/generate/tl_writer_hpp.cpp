//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_hpp.h"

#include <cassert>

namespace td {

bool TD_TL_writer_hpp::is_documentation_generated() const {
#ifdef DISABLE_HPP_DOCUMENTATION
  return false;
#else
  return true;
#endif
}

int TD_TL_writer_hpp::get_additional_function_type(const std::string &additional_function_name) const {
  assert(additional_function_name == "downcast_call");
  return 2;
}

std::vector<std::string> TD_TL_writer_hpp::get_additional_functions() const {
  std::vector<std::string> additional_functions;
  additional_functions.push_back("downcast_call");
  return additional_functions;
}

std::string TD_TL_writer_hpp::gen_base_type_class_name(int arity) const {
  assert(arity == 0);
  return "Object";
}

std::string TD_TL_writer_hpp::gen_base_tl_class_name() const {
  return "BaseObject";
}

std::string TD_TL_writer_hpp::gen_output_begin(const std::string &additional_imports) const {
  return "#pragma once\n"
         "\n"
#ifndef DISABLE_HPP_DOCUMENTATION
         "/**\n"
         " * \\file\n"
         " * Contains downcast_call methods for calling a function object on downcasted to\n"
         " * the most derived class TDLib API object.\n"
         " */\n"
#endif
         "#include \"" +
         tl_name +
         ".h\"\n"
         "\n"
         "namespace td {\n"
         "namespace " +
         tl_name + " {\n\n";
}

std::string TD_TL_writer_hpp::gen_output_begin_once() const {
  return std::string();
}

std::string TD_TL_writer_hpp::gen_output_end() const {
  return "}  // namespace " + tl_name +
         "\n"
         "}  // namespace td\n";
}

std::string TD_TL_writer_hpp::gen_field_definition(const std::string &class_name, const std::string &type_name,
                                                   const std::string &field_name) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                                       std::vector<tl::var_description> &vars) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_function_vars(const tl::tl_combinator *t,
                                                std::vector<tl::var_description> &vars) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                                      bool check_negative) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_constructor_id_store(std::int32_t id, int storer_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars,
                                              bool flat, int parser_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_field_store(const tl::arg &a, const std::vector<tl::arg> &args,
                                              std::vector<tl::var_description> &vars, bool flat,
                                              int storer_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                             const std::vector<tl::var_description> &vars, int parser_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                             const std::vector<tl::var_description> &vars, int storer_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_var_type_fetch(const tl::arg &a) const {
  assert(false);
  return "";
}

std::string TD_TL_writer_hpp::gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                              bool is_proxy, const tl::tl_tree *result) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_class_end() const {
  return "";
}

std::string TD_TL_writer_hpp::gen_class_alias(const std::string &class_name, const std::string &alias_name) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_function_result_type(const tl::tl_tree *result) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                                       const std::string &parent_class_name, int arity, int field_count,
                                                       std::vector<tl::var_description> &vars, int parser_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_end(bool has_parent, int field_count,
                                                     const std::vector<tl::var_description> &vars,
                                                     int parser_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_result_begin(const std::string &parser_name,
                                                              const std::string &class_name,
                                                              const tl::tl_tree *result) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_result_end() const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_result_any_begin(const std::string &parser_name,
                                                                  const std::string &class_name, bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_function_result_any_end(bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_store_function_begin(const std::string &storer_name, const std::string &class_name,
                                                       int arity, std::vector<tl::var_description> &vars,
                                                       int storer_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_store_function_end(const std::vector<tl::var_description> &vars,
                                                     int storer_type) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_switch_begin() const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_fetch_switch_end() const {
  return "";
}

std::string TD_TL_writer_hpp::gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                                      bool is_function) const {
  assert(function_name == "downcast_call");
  return "";
}

std::string TD_TL_writer_hpp::gen_additional_proxy_function_begin(const std::string &function_name,
                                                                  const tl::tl_type *type,
                                                                  const std::string &class_name, int arity,
                                                                  bool is_function) const {
  assert(function_name == "downcast_call");
  return
#ifndef DISABLE_HPP_DOCUMENTATION
      "/**\n"
      " * Calls the specified function object with the given object downcasted to its most derived type.\n"
      " * \\param[in] obj Object to pass as an argument to the function object.\n"
      " * \\param[in] func Function object to which the object will be passed.\n"
      " * \\returns Whether function object call has happened. Should always return true for correct parameters.\n"
      " */\n"
#endif
      "template <class T>\n"
      "bool downcast_call(" +
      class_name +
      " &obj, const T &func) {\n"
      "  switch (obj.get_id()) {\n";
}

std::string TD_TL_writer_hpp::gen_additional_proxy_function_case(const std::string &function_name,
                                                                 const tl::tl_type *type, const std::string &class_name,
                                                                 int arity) const {
  assert(function_name == "downcast_call");
  assert(false);
  return "";
}

std::string TD_TL_writer_hpp::gen_additional_proxy_function_case(const std::string &function_name,
                                                                 const tl::tl_type *type, const tl::tl_combinator *t,
                                                                 int arity, bool is_function) const {
  assert(function_name == "downcast_call");
  return "    case " + gen_class_name(t->name) +
         "::ID:\n"
         "      func(static_cast<" +
         gen_class_name(t->name) +
         " &>(obj));\n"
         "      return true;\n";
}

std::string TD_TL_writer_hpp::gen_additional_proxy_function_end(const std::string &function_name,
                                                                const tl::tl_type *type, bool is_function) const {
  assert(function_name == "downcast_call");
  return "    default:\n"
         "      return false;\n"
         "  }\n"
         "}\n\n";
}

std::string TD_TL_writer_hpp::gen_constructor_begin(int field_count, const std::string &class_name,
                                                    bool is_default) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                                        bool is_default) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                                         bool is_default) const {
  return "";
}

std::string TD_TL_writer_hpp::gen_constructor_end(const tl::tl_combinator *t, int field_count, bool is_default) const {
  return "";
}

}  // namespace td
