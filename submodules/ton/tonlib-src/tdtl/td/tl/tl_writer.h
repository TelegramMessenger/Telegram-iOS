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

#include "tl_core.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {
namespace tl {

class var_description {
 public:
  int index;
  bool is_stored;
  bool is_type;
  int parameter_num;
  int function_arg_num;

  var_description() : index(-1), is_stored(false), is_type(false), parameter_num(-1), function_arg_num(-1) {
  }
};

class TL_writer {
  TL_writer(const TL_writer &other);
  TL_writer &operator=(const TL_writer &other);

 protected:
  const std::string tl_name;

 public:
  enum Mode { All, Client, Server };

  explicit TL_writer(const std::string &tl_name) : tl_name(tl_name) {
  }

  virtual ~TL_writer() {
  }

  virtual int get_max_arity() const = 0;

  static std::string int_to_string(int x);
  static bool is_alnum(char c);
  static char to_lower(char c);
  static char to_upper(char c);

  virtual bool is_built_in_simple_type(const std::string &name) const = 0;
  virtual bool is_built_in_complex_type(const std::string &name) const = 0;
  virtual bool is_type_supported(const tl_tree_type *tree_type) const;
  virtual bool is_type_bare(const tl_type *t) const = 0;
  virtual bool is_combinator_supported(const tl_combinator *constructor) const;
  virtual bool is_documentation_generated() const;

  virtual int get_parser_type(const tl_combinator *t, const std::string &parser_name) const;
  virtual int get_storer_type(const tl_combinator *t, const std::string &storer_name) const;
  virtual int get_additional_function_type(const std::string &additional_function_name) const;
  virtual Mode get_parser_mode(int type) const;
  virtual Mode get_storer_mode(int type) const;
  virtual std::vector<std::string> get_parsers() const = 0;
  virtual std::vector<std::string> get_storers() const = 0;
  virtual std::vector<std::string> get_additional_functions() const;

  virtual std::string gen_base_tl_class_name() const = 0;
  virtual std::string gen_base_type_class_name(int arity) const = 0;
  virtual std::string gen_base_function_class_name() const = 0;
  virtual std::string gen_class_name(std::string name) const = 0;
  virtual std::string gen_field_name(std::string name) const = 0;
  virtual std::string gen_var_name(const var_description &desc) const = 0;
  virtual std::string gen_parameter_name(int index) const = 0;
  virtual std::string gen_main_class_name(const tl_type *t) const;
  virtual std::string gen_field_type(const arg &a) const;
  virtual std::string gen_type_name(const tl_tree_type *tree_type) const = 0;
  virtual std::string gen_array_type_name(const tl_tree_array *arr, const std::string &field_name) const = 0;
  virtual std::string gen_var_type_name() const = 0;

  virtual std::string gen_int_const(const tl_tree *tree_c, const std::vector<var_description> &vars) const = 0;

  virtual std::string gen_output_begin() const = 0;
  virtual std::string gen_output_end() const = 0;

  virtual std::string gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const = 0;

  virtual std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                      bool is_proxy) const = 0;
  virtual std::string gen_class_end() const = 0;

  virtual std::string gen_class_alias(const std::string &class_name, const std::string &alias_name) const = 0;

  virtual std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                           const std::string &field_name) const = 0;
  virtual std::string gen_flags_definitions(const tl_combinator *t) const {
    return "";
  }

  virtual std::string gen_vars(const tl_combinator *t, const tl_tree_type *result_type,
                               std::vector<var_description> &vars) const = 0;
  virtual std::string gen_function_vars(const tl_combinator *t, std::vector<var_description> &vars) const = 0;
  virtual std::string gen_uni(const tl_tree_type *result_type, std::vector<var_description> &vars,
                              bool check_negative) const = 0;
  virtual std::string gen_constructor_id_store(std::int32_t id, int storer_type) const = 0;
  virtual std::string gen_field_fetch(int field_num, const arg &a, std::vector<var_description> &vars, bool flat,
                                      int parser_type) const = 0;
  virtual std::string gen_field_store(const arg &a, std::vector<var_description> &vars, bool flat,
                                      int storer_type) const = 0;
  virtual std::string gen_type_fetch(const std::string &field_name, const tl_tree_type *tree_type,
                                     const std::vector<var_description> &vars, int parser_type) const = 0;
  virtual std::string gen_type_store(const std::string &field_name, const tl_tree_type *tree_type,
                                     const std::vector<var_description> &vars, int storer_type) const = 0;
  virtual std::string gen_var_type_fetch(const arg &a) const = 0;

  virtual std::string gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const = 0;

  virtual std::string gen_function_result_type(const tl_tree *result) const = 0;

  virtual std::string gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                               const std::string &parent_class_name, int arity,
                                               std::vector<var_description> &vars, int parser_type) const = 0;
  virtual std::string gen_fetch_function_end(bool has_parent, int field_num, const std::vector<var_description> &vars,
                                             int parser_type) const = 0;

  virtual std::string gen_fetch_function_result_begin(const std::string &parser_name, const std::string &class_name,
                                                      const tl_tree *result) const = 0;
  virtual std::string gen_fetch_function_result_end() const = 0;
  virtual std::string gen_fetch_function_result_any_begin(const std::string &parser_name, const std::string &class_name,
                                                          bool is_proxy) const = 0;
  virtual std::string gen_fetch_function_result_any_end(bool is_proxy) const = 0;

  virtual std::string gen_store_function_begin(const std::string &storer_name, const std::string &class_name, int arity,
                                               std::vector<var_description> &vars, int storer_type) const = 0;
  virtual std::string gen_store_function_end(const std::vector<var_description> &vars, int storer_type) const = 0;

  virtual std::string gen_fetch_switch_begin() const = 0;
  virtual std::string gen_fetch_switch_case(const tl_combinator *t, int arity) const = 0;
  virtual std::string gen_fetch_switch_end() const = 0;

  virtual std::string gen_constructor_begin(int fields_num, const std::string &class_name, bool is_default) const = 0;
  virtual std::string gen_constructor_parameter(int field_num, const std::string &class_name, const arg &a,
                                                bool is_default) const = 0;
  virtual std::string gen_constructor_field_init(int field_num, const std::string &class_name, const arg &a,
                                                 bool is_default) const = 0;
  virtual std::string gen_constructor_end(const tl_combinator *t, int fields_num, bool is_default) const = 0;

  virtual std::string gen_additional_function(const std::string &function_name, const tl_combinator *t,
                                              bool is_function) const;
  virtual std::string gen_additional_proxy_function_begin(const std::string &function_name, const tl_type *type,
                                                          const std::string &class_name, int arity,
                                                          bool is_function) const;
  virtual std::string gen_additional_proxy_function_case(const std::string &function_name, const tl_type *type,
                                                         const std::string &class_name, int arity) const;
  virtual std::string gen_additional_proxy_function_case(const std::string &function_name, const tl_type *type,
                                                         const tl_combinator *t, int arity, bool is_function) const;
  virtual std::string gen_additional_proxy_function_end(const std::string &function_name, const tl_type *type,
                                                        bool is_function) const;
};

}  // namespace tl
}  // namespace td
