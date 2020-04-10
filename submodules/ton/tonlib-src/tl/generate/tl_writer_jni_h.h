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

#include "tl_writer_h.h"

#include <string>
#include <vector>

namespace td {

class TD_TL_writer_jni_h : public TD_TL_writer_h {
 public:
  TD_TL_writer_jni_h(const std::string &tl_name, const std::string &string_type, const std::string &bytes_type,
                     const std::string &secure_string_type, const std::string &secure_bytes_type,
                     const std::vector<std::string> &ext_include)
      : TD_TL_writer_h(tl_name, string_type, bytes_type, secure_string_type, secure_bytes_type, ext_include) {
  }

  bool is_built_in_simple_type(const std::string &name) const override;
  bool is_built_in_complex_type(const std::string &name) const override;

  int get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const override;
  int get_additional_function_type(const std::string &additional_function_name) const override;
  std::vector<std::string> get_parsers() const override;
  std::vector<std::string> get_storers() const override;
  std::vector<std::string> get_additional_functions() const override;

  std::string gen_base_type_class_name(int arity) const override;
  std::string gen_base_tl_class_name() const override;

  std::string gen_output_begin() const override;

  std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                              bool is_proxy) const override;

  std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                   const std::string &field_name) const override;

  std::string gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                      bool is_function) const override;
  std::string gen_additional_proxy_function_begin(const std::string &function_name, const tl::tl_type *type,
                                                  const std::string &class_name, int arity,
                                                  bool is_function) const override;
  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const std::string &class_name, int arity) const override;
  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const tl::tl_combinator *t, int arity,
                                                 bool is_function) const override;
  std::string gen_additional_proxy_function_end(const std::string &function_name, const tl::tl_type *type,
                                                bool is_function) const override;
};

}  // namespace td
