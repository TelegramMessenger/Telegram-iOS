//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_core.h"
#include "td/tl/tl_simple_parser.h"

#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace td {
namespace tl {

class tl_config {
  std::vector<tl_type *> types;
  std::map<std::int32_t, tl_type *> id_to_type;
  std::map<std::string, tl_type *> name_to_type;

  std::vector<tl_combinator *> functions;
  std::map<std::int32_t, tl_combinator *> id_to_function;
  std::map<std::string, tl_combinator *> name_to_function;

 public:
  void add_type(tl_type *type);

  tl_type *get_type(std::int32_t type_id) const;

  tl_type *get_type(const std::string &type_name);

  void add_function(tl_combinator *function);

  tl_combinator *get_function(std::int32_t function_id);

  tl_combinator *get_function(const std::string &function_name);

  std::size_t get_type_count() const;

  tl_type *get_type_by_num(std::size_t num) const;

  std::size_t get_function_count() const;

  tl_combinator *get_function_by_num(std::size_t num) const;
};

class tl_config_parser {
  tl_simple_parser p;
  int schema_version;
  tl_config config;

  static int get_schema_version(std::int32_t version_id);

  tl_tree *read_num_const();
  tl_tree *read_num_var(int *var_count);
  tl_tree *read_type_var(int *var_count);
  tl_tree *read_array(int *var_count);
  tl_tree *read_type(int *var_count);
  tl_tree *read_type_expr(int *var_count);
  tl_tree *read_nat_expr(int *var_count);
  tl_tree *read_expr(int *var_count);
  std::vector<arg> read_args_list(int *var_count);

  tl_combinator *read_combinator();
  tl_type *read_type();

  template <class T>
  T try_parse(const T &res) const;

  std::int32_t try_parse_int();
  std::int64_t try_parse_long();
  std::string try_parse_string();

 public:
  tl_config_parser(const char *s, std::size_t len) : p(s, len), schema_version(-1) {
  }

  tl_config parse_config();
};

}  // namespace tl
}  // namespace td
