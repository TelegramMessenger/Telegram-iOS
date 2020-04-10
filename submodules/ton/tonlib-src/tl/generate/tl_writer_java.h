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

#include "td/tl/tl_writer.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {

class TD_TL_writer_java : public tl::TL_writer {
  static const int MAX_ARITY = 0;

  static const std::string base_type_class_names[MAX_ARITY + 1];
  static const std::string base_tl_class_name;
  static const std::string base_function_class_name;

  const std::string package_name;

 public:
  TD_TL_writer_java(const std::string &tl_name, const std::string &package_name)
      : TL_writer(tl_name), package_name(package_name) {
  }

  int get_max_arity() const override;

  bool is_built_in_simple_type(const std::string &name) const override;
  bool is_built_in_complex_type(const std::string &name) const override;
  bool is_type_bare(const tl::tl_type *t) const override;
  bool is_combinator_supported(const tl::tl_combinator *constructor) const override;

  int get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const override;
  int get_storer_type(const tl::tl_combinator *t, const std::string &storer_name) const override;
  std::vector<std::string> get_parsers() const override;
  std::vector<std::string> get_storers() const override;

  std::string gen_base_tl_class_name() const override;
  std::string gen_base_type_class_name(int arity) const override;
  std::string gen_base_function_class_name() const override;
  std::string gen_class_name(std::string name) const override;
  std::string gen_field_name(std::string name) const override;
  std::string gen_var_name(const tl::var_description &desc) const override;
  std::string gen_parameter_name(int index) const override;
  std::string gen_type_name(const tl::tl_tree_type *tree_type) const override;
  std::string gen_array_type_name(const tl::tl_tree_array *arr, const std::string &field_name) const override;
  std::string gen_var_type_name() const override;

  std::string gen_int_const(const tl::tl_tree *tree_c, const std::vector<tl::var_description> &vars) const override;

  std::string gen_output_begin() const override;
  std::string gen_output_end() const override;

  std::string gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const override;

  std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                              bool is_proxy) const override;
  std::string gen_class_end() const override;

  std::string gen_class_alias(const std::string &class_name, const std::string &alias_name) const override;

  std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                   const std::string &field_name) const override;

  std::string gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                       std::vector<tl::var_description> &vars) const override;
  std::string gen_function_vars(const tl::tl_combinator *t, std::vector<tl::var_description> &vars) const override;
  std::string gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                      bool check_negative) const override;
  std::string gen_constructor_id_store(std::int32_t id, int storer_type) const override;
  std::string gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                              int parser_type) const override;
  std::string gen_field_store(const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                              int storer_type) const override;
  std::string gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int parser_type) const override;
  std::string gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int storer_type) const override;
  std::string gen_var_type_fetch(const tl::arg &a) const override;

  std::string gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const override;

  std::string gen_function_result_type(const tl::tl_tree *result) const override;

  std::string gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                       const std::string &parent_class_name, int arity,
                                       std::vector<tl::var_description> &vars, int parser_type) const override;
  std::string gen_fetch_function_end(bool has_parent, int field_num, const std::vector<tl::var_description> &vars,
                                     int parser_type) const override;

  std::string gen_fetch_function_result_begin(const std::string &parser_name, const std::string &class_name,
                                              const tl::tl_tree *result) const override;
  std::string gen_fetch_function_result_end() const override;
  std::string gen_fetch_function_result_any_begin(const std::string &parser_name, const std::string &class_name,
                                                  bool is_proxy) const override;
  std::string gen_fetch_function_result_any_end(bool is_proxy) const override;

  std::string gen_store_function_begin(const std::string &storer_name, const std::string &class_name, int arity,
                                       std::vector<tl::var_description> &vars, int storer_type) const override;
  std::string gen_store_function_end(const std::vector<tl::var_description> &vars, int storer_type) const override;

  std::string gen_fetch_switch_begin() const override;
  std::string gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const override;
  std::string gen_fetch_switch_end() const override;

  std::string gen_constructor_begin(int fields_num, const std::string &class_name, bool is_default) const override;
  std::string gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                        bool is_default) const override;
  std::string gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                         bool is_default) const override;
  std::string gen_constructor_end(const tl::tl_combinator *t, int fields_num, bool is_default) const override;
};

}  // namespace td
