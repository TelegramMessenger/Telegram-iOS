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

#include "tl_writer_td.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {

class TD_TL_writer_cpp : public TD_TL_writer {
  std::string gen_constructor_id_store_raw(const std::string &id) const;

  std::string gen_fetch_class_name(const tl::tl_tree_type *tree_type) const;

  std::string gen_full_fetch_class_name(const tl::tl_tree_type *tree_type) const;

  std::string gen_store_class_name(const tl::tl_tree_type *tree_type) const;

  std::string gen_full_store_class_name(const tl::tl_tree_type *tree_type) const;

  std::vector<std::string> ext_include;

 protected:
  std::string gen_vector_store(const std::string &field_name, const tl::tl_tree_type *t,
                               const std::vector<tl::var_description> &vars, int storer_type) const;

  virtual std::string get_pretty_field_name(std::string field_name) const;

  virtual std::string get_pretty_class_name(std::string class_name) const;

 public:
  TD_TL_writer_cpp(const std::string &tl_name, const std::string &string_type, const std::string &bytes_type,
                   const std::string &secure_string_type, const std::string &secure_bytes_type,
                   const std::vector<std::string> &ext_include)
      : TD_TL_writer(tl_name, string_type, bytes_type, secure_string_type, secure_bytes_type)
      , ext_include(ext_include) {
  }

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
  std::string gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                         bool is_default) const override;
  std::string gen_constructor_end(const tl::tl_combinator *t, int fields_num, bool is_default) const override;
};

}  // namespace td
