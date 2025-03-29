//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_writer.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {

class TD_TL_writer_java final : public tl::TL_writer {
  static const int MAX_ARITY = 0;

  static const std::string base_type_class_names[MAX_ARITY + 1];
  static const std::string base_tl_class_name;
  static const std::string base_function_class_name;

  const std::string package_name;

 public:
  TD_TL_writer_java(const std::string &tl_name, const std::string &package_name)
      : TL_writer(tl_name), package_name(package_name) {
  }

  int get_max_arity() const final;

  bool is_built_in_simple_type(const std::string &name) const final;
  bool is_built_in_complex_type(const std::string &name) const final;
  bool is_type_bare(const tl::tl_type *t) const final;
  bool is_combinator_supported(const tl::tl_combinator *constructor) const final;

  int get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const final;
  int get_storer_type(const tl::tl_combinator *t, const std::string &storer_name) const final;
  std::vector<std::string> get_parsers() const final;
  std::vector<std::string> get_storers() const final;

  std::string gen_base_tl_class_name() const final;
  std::string gen_base_type_class_name(int arity) const final;
  std::string gen_base_function_class_name() const final;
  std::string gen_class_name(std::string name) const final;
  std::string gen_field_name(std::string name) const final;
  std::string gen_var_name(const tl::var_description &desc) const final;
  std::string gen_parameter_name(int index) const final;
  std::string gen_type_name(const tl::tl_tree_type *tree_type) const final;
  std::string gen_array_type_name(const tl::tl_tree_array *arr, const std::string &field_name) const final;
  std::string gen_var_type_name() const final;

  std::string gen_int_const(const tl::tl_tree *tree_c, const std::vector<tl::var_description> &vars) const final;

  std::string gen_output_begin(const std::string &additional_imports) const final;
  std::string gen_output_begin_once() const final;
  std::string gen_output_end() const final;

  std::string gen_import_declaration(const std::string &name, bool is_system) const final;

  std::string gen_package_suffix() const final;

  std::string gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const final;

  std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name, bool is_proxy,
                              const tl::tl_tree *result) const final;
  std::string gen_class_end() const final;

  std::string gen_class_alias(const std::string &class_name, const std::string &alias_name) const final;

  std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                   const std::string &field_name) const final;

  std::string gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                       std::vector<tl::var_description> &vars) const final;
  std::string gen_function_vars(const tl::tl_combinator *t, std::vector<tl::var_description> &vars) const final;
  std::string gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                      bool check_negative) const final;
  std::string gen_constructor_id_store(std::int32_t id, int storer_type) const final;
  std::string gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                              int parser_type) const final;
  std::string gen_field_store(const tl::arg &a, const std::vector<tl::arg> &args,
                              std::vector<tl::var_description> &vars, bool flat, int storer_type) const final;
  std::string gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int parser_type) const final;
  std::string gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int storer_type) const final;
  std::string gen_var_type_fetch(const tl::arg &a) const final;

  std::string gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const final;

  std::string gen_function_result_type(const tl::tl_tree *result) const final;

  std::string gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                       const std::string &parent_class_name, int arity, int field_count,
                                       std::vector<tl::var_description> &vars, int parser_type) const final;
  std::string gen_fetch_function_end(bool has_parent, int field_count, const std::vector<tl::var_description> &vars,
                                     int parser_type) const final;

  std::string gen_fetch_function_result_begin(const std::string &parser_name, const std::string &class_name,
                                              const tl::tl_tree *result) const final;
  std::string gen_fetch_function_result_end() const final;
  std::string gen_fetch_function_result_any_begin(const std::string &parser_name, const std::string &class_name,
                                                  bool is_proxy) const final;
  std::string gen_fetch_function_result_any_end(bool is_proxy) const final;

  std::string gen_store_function_begin(const std::string &storer_name, const std::string &class_name, int arity,
                                       std::vector<tl::var_description> &vars, int storer_type) const final;
  std::string gen_store_function_end(const std::vector<tl::var_description> &vars, int storer_type) const final;

  std::string gen_fetch_switch_begin() const final;
  std::string gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const final;
  std::string gen_fetch_switch_end() const final;

  std::string gen_constructor_begin(int field_count, const std::string &class_name, bool is_default) const final;
  std::string gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                        bool is_default) const final;
  std::string gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                         bool is_default) const final;
  std::string gen_constructor_end(const tl::tl_combinator *t, int field_count, bool is_default) const final;
};

}  // namespace td
