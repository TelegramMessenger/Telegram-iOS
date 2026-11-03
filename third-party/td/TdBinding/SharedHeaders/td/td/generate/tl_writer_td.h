//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_writer.h"

#include <string>
#include <vector>

namespace td {

class TD_TL_writer : public tl::TL_writer {
  static const int MAX_ARITY = 0;

  static const std::string base_type_class_names[MAX_ARITY + 1];
  static const std::string base_tl_class_name;
  static const std::string base_function_class_name;

 protected:
  const std::string string_type;
  const std::string bytes_type;

 public:
  TD_TL_writer(const std::string &tl_name, const std::string &string_type, const std::string &bytes_type)
      : TL_writer(tl_name), string_type(string_type), bytes_type(bytes_type) {
  }

  int get_max_arity() const override;

  bool is_built_in_simple_type(const std::string &name) const override;
  bool is_built_in_complex_type(const std::string &name) const override;
  bool is_type_bare(const tl::tl_type *t) const override;
  bool is_combinator_supported(const tl::tl_combinator *constructor) const override;
  bool is_default_constructor_generated(const tl::tl_combinator *t, bool can_be_parsed,
                                        bool can_be_stored) const override;
  bool is_full_constructor_generated(const tl::tl_combinator *t, bool can_be_parsed, bool can_be_stored) const override;

  int get_storer_type(const tl::tl_combinator *t, const std::string &storer_name) const override;
  Mode get_parser_mode(int type) const override;
  Mode get_storer_mode(int type) const override;
  std::vector<std::string> get_parsers() const override;
  std::vector<std::string> get_storers() const override;

  std::string gen_import_declaration(const std::string &package_name, bool is_system) const override;
  std::string gen_package_suffix() const override;
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

  std::string gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                        bool is_default) const override;
};

}  // namespace td
