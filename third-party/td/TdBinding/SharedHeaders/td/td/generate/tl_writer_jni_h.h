//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "tl_writer_h.h"

#include <string>
#include <vector>

namespace td {

class TD_TL_writer_jni_h final : public TD_TL_writer_h {
 public:
  TD_TL_writer_jni_h(const std::string &tl_name, const std::string &string_type, const std::string &bytes_type,
                     const std::vector<std::string> &ext_include)
      : TD_TL_writer_h(tl_name, string_type, bytes_type, ext_include) {
  }

  bool is_built_in_simple_type(const std::string &name) const final;
  bool is_built_in_complex_type(const std::string &name) const final;

  int get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const final;
  int get_additional_function_type(const std::string &additional_function_name) const final;
  std::vector<std::string> get_parsers() const final;
  std::vector<std::string> get_storers() const final;
  std::vector<std::string> get_additional_functions() const final;

  std::string gen_base_type_class_name(int arity) const final;
  std::string gen_base_tl_class_name() const final;

  std::string gen_output_begin(const std::string &additional_imports) const final;
  std::string gen_output_begin_once() const final;

  std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name, bool is_proxy,
                              const tl::tl_tree *result) const final;

  std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                   const std::string &field_name) const final;

  std::string gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                      bool is_function) const final;
  std::string gen_additional_proxy_function_begin(const std::string &function_name, const tl::tl_type *type,
                                                  const std::string &class_name, int arity,
                                                  bool is_function) const final;
  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const std::string &class_name, int arity) const final;
  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const tl::tl_combinator *t, int arity, bool is_function) const final;
  std::string gen_additional_proxy_function_end(const std::string &function_name, const tl::tl_type *type,
                                                bool is_function) const final;
};

}  // namespace td
