//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/tl/tl_generate.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_core.h"
#include "td/tl/tl_file_utils.h"
#include "td/tl/tl_outputer.h"
#include "td/tl/tl_string_outputer.h"
#include "td/tl/tl_writer.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace td {
namespace tl {

static bool is_reachable_for_parser(int parser_type, const std::string &name,
                                    const std::set<std::string> &request_types,
                                    const std::set<std::string> &result_types, const TL_writer &w) {
  TL_writer::Mode mode = w.get_parser_mode(parser_type);
  if (mode == TL_writer::Client) {
    return result_types.count(name) > 0;
  }
  if (mode == TL_writer::Server) {
    return request_types.count(name) > 0;
  }
  return true;
}

static bool is_reachable_for_storer(int storer_type, const std::string &name,
                                    const std::set<std::string> &request_types,
                                    const std::set<std::string> &result_types, const TL_writer &w) {
  TL_writer::Mode mode = w.get_storer_mode(storer_type);
  if (mode == TL_writer::Client) {
    return request_types.count(name) > 0;
  }
  if (mode == TL_writer::Server) {
    return result_types.count(name) > 0;
  }
  return true;
}

static void get_children_types(const tl_tree *tree, const TL_writer &w, std::map<std::string, bool> &children_types) {
  if (tree->get_type() != NODE_TYPE_TYPE) {
    return;
  }
  const tl_tree_type *tree_type = static_cast<const tl_tree_type *>(tree);
  for (std::size_t i = 0; i < tree_type->children.size(); i++) {
    get_children_types(tree_type->children[i], w, children_types);
  }

  const tl_type *t = tree_type->type;
  if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) || w.is_built_in_complex_type(t->name) ||
      (t->flags & FLAG_COMPLEX)) {  // built-in or complex types
    return;
  }

  assert(t->flags == 0);

  if (t->simple_constructors != 1) {
    children_types.emplace(w.gen_main_class_name(t), true);
  } else {
    for (std::size_t i = 0; i < t->constructors_num; i++) {
      if (w.is_combinator_supported(t->constructors[i])) {
        children_types.emplace(w.gen_class_name(t->constructors[i]->name), false);
      }
    }
  }
}

static std::map<std::string, bool> get_children_types(const tl_combinator *t, const TL_writer &w) {
  std::map<std::string, bool> children_types;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    get_children_types(t->args[i].type, w, children_types);
  }
  get_children_types(t->result, w, children_types);
  return children_types;
}

static std::map<std::string, bool> get_children_types(const tl_type *t, const TL_writer &w) {
  std::map<std::string, bool> children_types;
  for (std::size_t i = 0; i < t->constructors_num; i++) {
    if (w.is_combinator_supported(t->constructors[i])) {
      for (std::size_t j = 0; j < t->constructors[i]->args.size(); j++) {
        get_children_types(t->constructors[i]->args[j].type, w, children_types);
      }
    }
  }
  return children_types;
}

static void write_forward_declarations(tl_outputer &out, const std::map<std::string, bool> &children_types,
                                       const TL_writer &w) {
  for (std::map<std::string, bool>::const_iterator it = children_types.begin(); it != children_types.end(); ++it) {
    out.append(w.gen_forward_class_declaration(it->first, it->second));
  }
}

static void write_class_constructor(tl_outputer &out, const tl_combinator *t, const std::string &class_name,
                                    bool is_default, const TL_writer &w) {
  //  std::fprintf(stderr, "Gen constructor %s\n", class_name.c_str());
  int field_count = 0;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    field_count += !w.gen_constructor_parameter(field_count, class_name, t->args[i], is_default).empty();
  }

  out.append(w.gen_constructor_begin(field_count, class_name, is_default));
  int field_num = 0;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    std::string parameter_init = w.gen_constructor_parameter(field_num, class_name, t->args[i], is_default);
    if (!parameter_init.empty()) {
      out.append(parameter_init);
      field_num++;
    }
  }
  assert(field_num == field_count);

  field_num = 0;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    std::string field_init = w.gen_constructor_field_init(field_num, class_name, t->args[i], is_default);
    if (!field_init.empty()) {
      out.append(field_init);
      field_num++;
    }
  }

  out.append(w.gen_constructor_end(t, field_num, is_default));
}

static void write_function_fetch(tl_outputer &out, const std::string &parser_name, const tl_combinator *t,
                                 const std::string &class_name, const std::set<std::string> &request_types,
                                 const std::set<std::string> &result_types, const TL_writer &w) {
  //  std::fprintf(stderr, "Write function fetch %s\n", class_name.c_str());
  int parser_type = w.get_parser_type(t, parser_name);

  if (!is_reachable_for_parser(parser_type, t->name, request_types, result_types, w)) {
    return;
  }

  std::vector<var_description> vars(t->var_count);
  out.append(w.gen_fetch_function_begin(parser_name, class_name, class_name, 0, static_cast<int>(t->args.size()), vars,
                                        parser_type));
  out.append(w.gen_vars(t, NULL, vars));
  int field_num = 0;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    std::string field_fetch = w.gen_field_fetch(field_num, t->args[i], vars, false, parser_type);
    if (!field_fetch.empty()) {
      out.append(field_fetch);
      field_num++;
    }
  }

  out.append(w.gen_fetch_function_end(false, field_num, vars, parser_type));
}

static void write_function_store(tl_outputer &out, const std::string &storer_name, const tl_combinator *t,
                                 const std::string &class_name, std::vector<var_description> &vars,
                                 const std::set<std::string> &request_types, const std::set<std::string> &result_types,
                                 const TL_writer &w) {
  //  std::fprintf(stderr, "Write function store %s\n", class_name.c_str());
  int storer_type = w.get_storer_type(t, storer_name);

  if (!is_reachable_for_storer(storer_type, t->name, request_types, result_types, w)) {
    return;
  }

  out.append(w.gen_store_function_begin(storer_name, class_name, 0, vars, storer_type));
  out.append(w.gen_constructor_id_store(t->id, storer_type));
  for (std::size_t i = 0; i < t->args.size(); i++) {
    out.append(w.gen_field_store(t->args[i], t->args, vars, false, storer_type));
  }

  out.append(w.gen_store_function_end(vars, storer_type));
}

static void write_function_result_fetch(tl_outputer &out, const std::string &parser_name, const tl_combinator *t,
                                        const std::string &class_name, const tl_tree *result,
                                        const std::vector<var_description> &vars, const TL_writer &w) {
  //  std::fprintf(stderr, "Write function result fetch %s\n", class_name.c_str());
  int parser_type = w.get_parser_type(t, parser_name);

  out.append(w.gen_fetch_function_result_begin(parser_name, class_name, result));

  if (result->get_type() == NODE_TYPE_VAR_TYPE) {
    const tl_tree_var_type *result_var_type = static_cast<const tl_tree_var_type *>(result);

    for (std::size_t i = 0; i < t->args.size(); i++) {
      const arg &a = t->args[i];

      int arg_type = a.type->get_type();
      if (arg_type == NODE_TYPE_VAR_TYPE) {
        const tl_tree_var_type *tree_var_type = static_cast<const tl_tree_var_type *>(a.type);
        assert(a.flags & FLAG_EXCL);
        assert(tree_var_type->var_num >= 0);
        if (tree_var_type->var_num == result_var_type->var_num) {
          out.append(w.gen_var_type_fetch(a));
        }
      }
    }
  } else {
    assert(result->get_type() == NODE_TYPE_TYPE);
    const tl_tree_type *result_type = static_cast<const tl_tree_type *>(result);
    out.append(w.gen_type_fetch("", result_type, vars, parser_type));
  }

  out.append(w.gen_fetch_function_result_end());

  out.append(w.gen_fetch_function_result_any_begin(parser_name, class_name, false));
  out.append(w.gen_fetch_function_result_any_end(false));
}

static void write_constructor_fetch(tl_outputer &out, const std::string &parser_name, const tl_combinator *t,
                                    const std::string &class_name, const std::string &parent_class_name,
                                    const tl_tree_type *result_type, bool is_flat,
                                    const std::set<std::string> &request_types,
                                    const std::set<std::string> &result_types, const TL_writer &w) {
  int parser_type = w.get_parser_type(t, parser_name);

  if (!is_reachable_for_parser(parser_type, t->name, request_types, result_types, w)) {
    return;
  }

  std::vector<var_description> vars(t->var_count);
  out.append(w.gen_fetch_function_begin(parser_name, class_name, parent_class_name,
                                        static_cast<int>(result_type->children.size()),
                                        static_cast<int>(t->args.size()), vars, parser_type));
  out.append(w.gen_vars(t, result_type, vars));
  out.append(w.gen_uni(result_type, vars, true));
  int field_num = 0;
  for (std::size_t i = 0; i < t->args.size(); i++) {
    std::string field_fetch = w.gen_field_fetch(field_num, t->args[i], vars, is_flat, parser_type);
    if (!field_fetch.empty()) {
      out.append(field_fetch);
      field_num++;
    }
  }

  out.append(w.gen_fetch_function_end(class_name != parent_class_name, field_num, vars, parser_type));
}

static void write_constructor_store(tl_outputer &out, const std::string &storer_name, const tl_combinator *t,
                                    const std::string &class_name, const tl_tree_type *result_type, bool is_flat,
                                    const std::set<std::string> &request_types,
                                    const std::set<std::string> &result_types, const TL_writer &w) {
  std::vector<var_description> vars(t->var_count);
  int storer_type = w.get_storer_type(t, storer_name);

  if (!is_reachable_for_storer(storer_type, t->name, request_types, result_types, w)) {
    return;
  }

  out.append(w.gen_store_function_begin(storer_name, class_name, static_cast<int>(result_type->children.size()), vars,
                                        storer_type));
  out.append(w.gen_vars(t, result_type, vars));
  out.append(w.gen_uni(result_type, vars, false));
  for (std::size_t i = 0; i < t->args.size(); i++) {
    //  std::fprintf(stderr, "%s: %s\n", result_type->type->name.c_str(), t->name.c_str());
    out.append(w.gen_field_store(t->args[i], t->args, vars, is_flat, storer_type));
  }

  out.append(w.gen_store_function_end(vars, storer_type));
}

static int gen_field_definitions(tl_outputer &out, const tl_combinator *t, const std::string &class_name,
                                 const TL_writer &w) {
  int required_args = 0;

  for (std::size_t i = 0; i < t->args.size(); i++) {
    const arg &a = t->args[i];

    assert(-1 <= a.var_num && a.var_num < t->var_count);

    required_args += !(a.flags & FLAG_OPT_VAR);

    if (a.flags & FLAG_OPT_VAR) {
      //    continue;
    }

    std::string type_name = w.gen_field_type(a);
    if (!type_name.empty()) {
      out.append(w.gen_field_definition(class_name, type_name, w.gen_field_name(a.name)));
    }
  }

  return required_args;
}

static void write_function(tl_outputer &out, const tl_combinator *t, const std::set<std::string> &request_types,
                           const std::set<std::string> &result_types, const TL_writer &w) {
  assert(w.is_combinator_supported(t));

  write_forward_declarations(out, get_children_types(t, w), w);

  std::string class_name = w.gen_class_name(t->name);

  out.append(w.gen_class_begin(class_name, w.gen_base_function_class_name(), false, t->result));

  int required_args = gen_field_definitions(out, t, class_name, w);
  out.append(w.gen_flags_definitions(t, true));

  std::vector<var_description> vars(t->var_count);
  out.append(w.gen_function_vars(t, vars));

  if (w.is_default_constructor_generated(t, false, true)) {
    write_class_constructor(out, t, class_name, true, w);
  }
  if (required_args && w.is_full_constructor_generated(t, false, true)) {
    write_class_constructor(out, t, class_name, false, w);
  }

  out.append(w.gen_get_id(class_name, t->id, false));

  out.append(w.gen_function_result_type(t->result));

  //  PARSER
  std::vector<std::string> parsers = w.get_parsers();
  for (std::size_t i = 0; i < parsers.size(); i++) {
    write_function_fetch(out, parsers[i], t, class_name, request_types, result_types, w);
  }

  //  STORER
  std::vector<std::string> storers = w.get_storers();
  for (std::size_t i = 0; i < storers.size(); i++) {
    write_function_store(out, storers[i], t, class_name, vars, request_types, result_types, w);
  }

  //  PARSE RESULT
  for (std::size_t i = 0; i < parsers.size(); i++) {
    if (w.get_parser_mode(-1) == TL_writer::Server) {
      continue;
    }

    write_function_result_fetch(out, parsers[i], t, class_name, t->result, vars, w);
  }

  //  ADDITIONAL FUNCTIONS
  std::vector<std::string> additional_functions = w.get_additional_functions();
  for (std::size_t i = 0; i < additional_functions.size(); i++) {
    out.append(w.gen_additional_function(additional_functions[i], t, true));
  }

  out.append(w.gen_class_end());
}

static void write_constructor(tl_outputer &out, const tl_combinator *t, const std::string &base_class,
                              const std::string &parent_class, bool is_proxy,
                              const std::set<std::string> &request_types, const std::set<std::string> &result_types,
                              const TL_writer &w) {
  assert(w.is_combinator_supported(t));

  std::string class_name = w.gen_class_name(t->name);

  out.append(w.gen_class_begin(class_name, base_class, is_proxy, t->result));
  int required_args = gen_field_definitions(out, t, class_name, w);

  bool can_be_parsed = false;
  bool is_can_be_parsed_inited = false;
  std::vector<std::string> parsers = w.get_parsers();
  for (std::size_t i = 0; i < parsers.size(); i++) {
    int parser_type = w.get_parser_type(t, parsers[i]);
    if (w.get_parser_mode(parser_type) != TL_writer::All) {
      can_be_parsed |= is_reachable_for_parser(parser_type, t->name, request_types, result_types, w);
      is_can_be_parsed_inited = true;
    }
  }
  if (!is_can_be_parsed_inited) {
    can_be_parsed = true;
  }

  bool can_be_stored = false;
  bool is_can_be_stored_inited = false;
  std::vector<std::string> storers = w.get_storers();
  for (std::size_t i = 0; i < storers.size(); i++) {
    int storer_type = w.get_storer_type(t, storers[i]);
    if (w.get_storer_mode(storer_type) != TL_writer::All) {
      can_be_stored |= is_reachable_for_storer(storer_type, t->name, request_types, result_types, w);
      is_can_be_stored_inited = true;
    }
  }
  if (!is_can_be_stored_inited) {
    can_be_stored = true;
  }

  out.append(w.gen_flags_definitions(t, can_be_stored));
  if (w.is_default_constructor_generated(t, can_be_parsed, can_be_stored)) {
    write_class_constructor(out, t, class_name, true, w);
  }
  if (required_args && w.is_full_constructor_generated(t, can_be_parsed, can_be_stored)) {
    write_class_constructor(out, t, class_name, false, w);
  }

  out.append(w.gen_get_id(class_name, t->id, false));

  //  PARSER
  assert(t->result->get_type() == NODE_TYPE_TYPE);
  const tl_tree_type *result_type = static_cast<const tl_tree_type *>(t->result);

  for (std::size_t i = 0; i < parsers.size(); i++) {
    write_constructor_fetch(out, parsers[i], t, class_name, parent_class, result_type,
                            required_args == 1 && result_type->type->simple_constructors == 1, request_types,
                            result_types, w);
  }

  //  STORER
  for (std::size_t i = 0; i < storers.size(); i++) {
    write_constructor_store(out, storers[i], t, class_name, result_type,
                            required_args == 1 && result_type->type->simple_constructors == 1, request_types,
                            result_types, w);
  }

  //  ADDITIONAL FUNCTIONS
  std::vector<std::string> additional_functions = w.get_additional_functions();
  for (std::size_t i = 0; i < additional_functions.size(); i++) {
    out.append(w.gen_additional_function(additional_functions[i], t, false));
  }

  out.append(w.gen_class_end());
}

static void write_class(tl_outputer &out, const tl_type *t, const std::set<std::string> &request_types,
                        const std::set<std::string> &result_types, const TL_writer &w) {
  assert(t->constructors_num > 0);
  assert(!w.is_built_in_simple_type(t->name));
  assert(!w.is_built_in_complex_type(t->name));
  assert(!(t->flags & FLAG_COMPLEX));

  assert(t->arity >= 0);
  assert(t->simple_constructors > 0);
  assert(t->flags == 0);

  const std::string base_class = w.gen_base_type_class_name(t->arity);
  const std::string class_name = w.gen_class_name(t->name);

  write_forward_declarations(out, get_children_types(t, w), w);

  std::vector<var_description> empty_vars;
  bool optimize_one_constructor = (t->simple_constructors == 1);
  if (!optimize_one_constructor) {
    out.append(w.gen_class_begin(class_name, base_class, true, nullptr));

    out.append(w.gen_get_id(class_name, 0, true));

    std::vector<std::string> parsers = w.get_parsers();
    for (std::size_t i = 0; i < parsers.size(); i++) {
      if (!is_reachable_for_parser(-1, t->name, request_types, result_types, w)) {
        continue;
      }

      out.append(w.gen_fetch_function_begin(parsers[i], class_name, class_name, t->arity, -1, empty_vars, -1));
      out.append(w.gen_fetch_switch_begin());
      for (std::size_t j = 0; j < t->constructors_num; j++) {
        if (w.is_combinator_supported(t->constructors[j])) {
          out.append(w.gen_fetch_switch_case(t->constructors[j], t->arity));
        }
      }

      out.append(w.gen_fetch_switch_end());
      out.append(w.gen_fetch_function_end(false, -1, empty_vars, -1));
    }

    std::vector<std::string> storers = w.get_storers();
    for (std::size_t i = 0; i < storers.size(); i++) {
      if (!is_reachable_for_storer(-1, t->name, request_types, result_types, w)) {
        continue;
      }

      out.append(w.gen_store_function_begin(storers[i], class_name, t->arity, empty_vars, -1));
      out.append(w.gen_store_function_end(empty_vars, -1));
    }

    std::vector<std::string> additional_functions = w.get_additional_functions();
    for (std::size_t i = 0; i < additional_functions.size(); i++) {
      out.append(w.gen_additional_proxy_function_begin(additional_functions[i], t, class_name, t->arity, false));
      for (std::size_t j = 0; j < t->constructors_num; j++) {
        if (w.is_combinator_supported(t->constructors[j])) {
          out.append(
              w.gen_additional_proxy_function_case(additional_functions[i], t, t->constructors[j], t->arity, false));
        }
      }

      out.append(w.gen_additional_proxy_function_end(additional_functions[i], t, false));
    }

    out.append(w.gen_class_end());
  }

  int written_constructors = 0;
  for (std::size_t i = 0; i < t->constructors_num; i++) {
    if (w.is_combinator_supported(t->constructors[i])) {
      if (optimize_one_constructor) {
        write_constructor(out, t->constructors[i], base_class, w.gen_class_name(t->constructors[i]->name), false,
                          request_types, result_types, w);
        out.append(w.gen_class_alias(w.gen_class_name(t->constructors[i]->name), class_name));
      } else {
        write_constructor(out, t->constructors[i], class_name, class_name, false, request_types, result_types, w);
      }
      written_constructors++;
    } else {
      std::fprintf(stderr, "Skip complex constructor %s of %s\n", t->constructors[i]->name.c_str(), t->name.c_str());
    }
  }
  (void)written_constructors;
  assert(written_constructors == t->simple_constructors);
}

static void dfs_type(const tl_type *t, std::set<std::string> &found, const TL_writer &w);

static void dfs_tree(const tl_tree *t, std::set<std::string> &found, const TL_writer &w) {
  int type = t->get_type();

  if (type == NODE_TYPE_ARRAY) {
    const tl_tree_array *arr = static_cast<const tl_tree_array *>(t);
    for (std::size_t i = 0; i < arr->args.size(); i++) {
      dfs_tree(arr->args[i].type, found, w);
    }
  } else if (type == NODE_TYPE_TYPE) {
    const tl_tree_type *tree_type = static_cast<const tl_tree_type *>(t);
    dfs_type(tree_type->type, found, w);
    for (std::size_t i = 0; i < tree_type->children.size(); i++) {
      dfs_tree(tree_type->children[i], found, w);
    }
  } else {
    assert(type == NODE_TYPE_VAR_TYPE);
  }
}

static void dfs_combinator(const tl_combinator *constructor, std::set<std::string> &found, const TL_writer &w) {
  if (!w.is_combinator_supported(constructor)) {
    return;
  }

  if (!found.insert(constructor->name).second) {
    return;
  }

  for (std::size_t i = 0; i < constructor->args.size(); i++) {
    dfs_tree(constructor->args[i].type, found, w);
  }
}

static void dfs_type(const tl_type *t, std::set<std::string> &found, const TL_writer &w) {
  if (!found.insert(t->name).second) {
    return;
  }

  if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) || w.is_built_in_complex_type(t->name)) {
    return;
  }

  assert(!(t->flags & FLAG_COMPLEX));

  for (std::size_t i = 0; i < t->constructors_num; i++) {
    dfs_combinator(t->constructors[i], found, w);
  }
}

static void find_complex_types(const tl_config &config, const TL_writer &w) {
  for (std::size_t type = 0; type < config.get_type_count(); type++) {
    tl_type *t = config.get_type_by_num(type);
    assert(t->constructors_num == t->constructors.size());
    if (t->constructors_num == 0) {  // built-in dummy types
      if (t->name == "Type") {
        assert(t->id == ID_VAR_TYPE);
        t->flags |= FLAG_COMPLEX;
      }
      continue;
    }

    for (std::size_t j = 0; j < t->constructors_num; j++) {
      tl_combinator *constructor = t->constructors[j];
      assert(constructor->type_id == t->id);
      assert(constructor->result->get_type() == NODE_TYPE_TYPE);
      assert(static_cast<const tl_tree_type *>(constructor->result)->type == t);
      assert(static_cast<const tl_tree_type *>(constructor->result)->children.size() ==
             static_cast<std::size_t>(t->arity));
      assert(static_cast<const tl_tree_type *>(constructor->result)->flags == (t->arity > 0 ? 0 : FLAG_NOVAR));

      for (std::size_t k = 0; k < constructor->args.size(); k++) {
        const arg &a = constructor->args[k];

        assert(-1 <= a.var_num && a.var_num <= constructor->var_count);

        int arg_type = a.type->get_type();
        assert(arg_type == NODE_TYPE_TYPE || arg_type == NODE_TYPE_VAR_TYPE || arg_type == NODE_TYPE_ARRAY);
        if (a.var_num >= 0) {
          assert(arg_type == NODE_TYPE_TYPE);
          assert(static_cast<const tl_tree_type *>(a.type)->type->id == ID_VAR_NUM ||
                 static_cast<const tl_tree_type *>(a.type)->type->id == ID_VAR_TYPE);
        }

        if (arg_type == NODE_TYPE_ARRAY) {
          const tl_tree_array *arr = static_cast<const tl_tree_array *>(a.type);
          assert(arr->multiplicity->get_type() == NODE_TYPE_NAT_CONST ||
                 arr->multiplicity->get_type() == NODE_TYPE_VAR_NUM);
          for (std::size_t l = 0; l < arr->args.size(); l++) {
            const arg &b = arr->args[l];
            int b_arg_type = b.type->get_type();
            if (b_arg_type == NODE_TYPE_VAR_TYPE || b_arg_type == NODE_TYPE_ARRAY || b.var_num != -1 ||
                b.exist_var_num != -1) {
              if (!w.is_built_in_complex_type(t->name)) {
                t->flags |= FLAG_COMPLEX;
              }
            } else {
              assert(b_arg_type == NODE_TYPE_TYPE);
            }
            assert(b.flags == FLAG_NOVAR || b.flags == 0);
          }
        }
      }
    }

    for (int i = 0; i < t->arity; i++) {
      int main_type = static_cast<const tl_tree_type *>(t->constructors[0]->result)->children[i]->get_type();
      for (std::size_t j = 1; j < t->constructors_num; j++) {
        assert(static_cast<const tl_tree_type *>(t->constructors[j]->result)->children[i]->get_type() == main_type);
      }
      assert(main_type == NODE_TYPE_VAR_TYPE || main_type == NODE_TYPE_VAR_NUM);
      if (main_type == NODE_TYPE_VAR_TYPE) {
        if (!w.is_built_in_complex_type(t->name)) {
          t->flags |= FLAG_COMPLEX;
        }
      }
    }
  }

  while (true) {
    bool found_complex = false;
    for (std::size_t type = 0; type < config.get_type_count(); type++) {
      tl_type *t = config.get_type_by_num(type);
      if (t->constructors_num == 0 || w.is_built_in_complex_type(t->name)) {  // built-in dummy or complex types
        continue;
      }
      if (t->flags & FLAG_COMPLEX) {  // already complex
        continue;
      }

      t->simple_constructors = 0;
      for (std::size_t i = 0; i < t->constructors_num; i++) {
        t->simple_constructors += w.is_combinator_supported(t->constructors[i]);
      }
      if (t->simple_constructors == 0) {
        t->flags |= FLAG_COMPLEX;
        found_complex = true;
        //  std::fprintf(stderr, "Found complex %s\n", t->name.c_str());
      }
    }
    if (!found_complex) {
      break;
    }
  }
}

static void write_base_object_classes(const tl_config &config, tl_outputer &out,
                                      const std::set<std::string> &request_types,
                                      const std::set<std::string> &result_types, const TL_writer &w) {
  std::vector<var_description> empty_vars;
  for (int i = 0; i <= w.get_max_arity(); i++) {
    out.append(w.gen_class_begin(w.gen_base_type_class_name(i), w.gen_base_tl_class_name(), true, nullptr));

    out.append(w.gen_get_id(w.gen_base_type_class_name(i), 0, true));

    std::vector<std::string> parsers = w.get_parsers();
    for (std::size_t j = 0; j < parsers.size(); j++) {
      int case_count = 0;
      for (std::size_t type = 0; type < config.get_type_count(); type++) {
        tl_type *t = config.get_type_by_num(type);
        if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) || w.is_built_in_complex_type(t->name) ||
            (t->flags & FLAG_COMPLEX)) {  // built-in or complex types
          continue;
        }
        if (t->arity != i) {  // additional condition
          continue;
        }

        for (std::size_t k = 0; k < t->constructors_num; k++) {
          if (w.is_combinator_supported(t->constructors[k]) &&
              is_reachable_for_parser(-1, t->constructors[k]->name, request_types, result_types, w)) {
            case_count++;
          }
        }
      }

      if (case_count == 0) {
        continue;
      }

      out.append(w.gen_fetch_function_begin(parsers[j], w.gen_base_type_class_name(i), w.gen_base_type_class_name(i), i,
                                            -1, empty_vars, -1));
      out.append(w.gen_fetch_switch_begin());
      for (std::size_t type = 0; type < config.get_type_count(); type++) {
        tl_type *t = config.get_type_by_num(type);
        if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) || w.is_built_in_complex_type(t->name) ||
            (t->flags & FLAG_COMPLEX)) {  // built-in or complex types
          continue;
        }
        if (t->arity != i) {  // additional condition
          continue;
        }

        for (std::size_t k = 0; k < t->constructors_num; k++) {
          if (w.is_combinator_supported(t->constructors[k]) &&
              is_reachable_for_parser(-1, t->constructors[k]->name, request_types, result_types, w)) {
            out.append(w.gen_fetch_switch_case(t->constructors[k], i));
          }
        }
      }
      out.append(w.gen_fetch_switch_end());
      out.append(w.gen_fetch_function_end(false, -1, empty_vars, -1));
    }

    std::vector<std::string> additional_functions = w.get_additional_functions();
    for (std::size_t j = 0; j < additional_functions.size(); j++) {
      out.append(w.gen_additional_proxy_function_begin(additional_functions[j], NULL, w.gen_base_type_class_name(i), i,
                                                       false));
      for (std::size_t type = 0; type < config.get_type_count(); type++) {
        tl_type *t = config.get_type_by_num(type);
        if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) || w.is_built_in_complex_type(t->name) ||
            (t->flags & FLAG_COMPLEX)) {  // built-in or complex types
          continue;
        }
        if (t->arity != i) {  // additional condition
          continue;
        }

        int function_type = w.get_additional_function_type(additional_functions[j]);
        if ((function_type & 1) && t->simple_constructors != 1) {
          out.append(w.gen_additional_proxy_function_case(additional_functions[j], NULL, w.gen_class_name(t->name), i));
        }
        if ((function_type & 2) || ((function_type & 1) && t->simple_constructors == 1)) {
          for (std::size_t k = 0; k < t->constructors_num; k++) {
            if (w.is_combinator_supported(t->constructors[k])) {
              out.append(
                  w.gen_additional_proxy_function_case(additional_functions[j], NULL, t->constructors[k], i, false));
            }
          }
        }
      }

      out.append(w.gen_additional_proxy_function_end(additional_functions[j], NULL, false));
    }

    std::vector<std::string> storers = w.get_storers();
    for (std::size_t j = 0; j < storers.size(); j++) {
      out.append(w.gen_store_function_begin(storers[j], w.gen_base_type_class_name(i), i, empty_vars, -1));
      out.append(w.gen_store_function_end(empty_vars, -1));
    }

    out.append(w.gen_class_end());
  }
}

static void write_base_function_class(const tl_config &config, tl_outputer &out,
                                      const std::set<std::string> &request_types,
                                      const std::set<std::string> &result_types, const TL_writer &w) {
  out.append(w.gen_class_begin(w.gen_base_function_class_name(), w.gen_base_tl_class_name(), true, nullptr));

  out.append(w.gen_get_id(w.gen_base_function_class_name(), 0, true));

  std::vector<var_description> empty_vars;
  std::vector<std::string> parsers = w.get_parsers();
  for (std::size_t j = 0; j < parsers.size(); j++) {
    if (w.get_parser_mode(-1) == TL_writer::Client) {
      continue;
    }

    out.append(w.gen_fetch_function_begin(parsers[j], w.gen_base_function_class_name(),
                                          w.gen_base_function_class_name(), 0, -1, empty_vars, -1));
    out.append(w.gen_fetch_switch_begin());
    for (std::size_t function = 0; function < config.get_function_count(); function++) {
      tl_combinator *t = config.get_function_by_num(function);

      if (w.is_combinator_supported(t)) {
        out.append(w.gen_fetch_switch_case(t, 0));
      }
    }
    out.append(w.gen_fetch_switch_end());
    out.append(w.gen_fetch_function_end(false, -1, empty_vars, -1));
  }

  std::vector<std::string> storers = w.get_storers();
  for (std::size_t j = 0; j < storers.size(); j++) {
    if (w.get_storer_mode(-1) == TL_writer::Server) {
      continue;
    }

    out.append(w.gen_store_function_begin(storers[j], w.gen_base_function_class_name(), 0, empty_vars, -1));
    out.append(w.gen_store_function_end(empty_vars, -1));
  }

  for (std::size_t j = 0; j < parsers.size(); j++) {
    if (w.get_parser_mode(-1) == TL_writer::Server) {
      continue;
    }

    out.append(w.gen_fetch_function_result_any_begin(parsers[j], w.gen_base_function_class_name(), true));
    out.append(w.gen_fetch_function_result_any_end(true));
  }

  std::vector<std::string> additional_functions = w.get_additional_functions();
  for (std::size_t j = 0; j < additional_functions.size(); j++) {
    out.append(w.gen_additional_proxy_function_begin(additional_functions[j], NULL, w.gen_base_function_class_name(), 0,
                                                     true));
    for (std::size_t function = 0; function < config.get_function_count(); function++) {
      tl_combinator *t = config.get_function_by_num(function);

      if (w.is_combinator_supported(t)) {
        out.append(w.gen_additional_proxy_function_case(additional_functions[j], NULL, t, 0, true));
      }
    }

    out.append(w.gen_additional_proxy_function_end(additional_functions[j], NULL, true));
  }

  out.append(w.gen_class_end());
}

void write_tl(const tl_config &config, tl_outputer &out, const TL_writer &w) {
  find_complex_types(config, w);

  out.append(w.gen_output_begin(std::string()));
  out.append(w.gen_output_begin_once());

  std::set<std::string> request_types;
  std::set<std::string> result_types;
  for (std::size_t function = 0; function < config.get_function_count(); function++) {
    const tl_combinator *t = config.get_function_by_num(function);
    dfs_combinator(t, request_types, w);
    dfs_tree(t->result, result_types, w);
  }

  write_base_object_classes(config, out, request_types, result_types, w);

  write_base_function_class(config, out, request_types, result_types, w);

  for (std::size_t type = 0; type < config.get_type_count(); type++) {
    tl_type *t = config.get_type_by_num(type);
    if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) ||
        w.is_built_in_complex_type(t->name)) {  // built-in dummy or complex types
      continue;
    }

    if (t->flags & FLAG_COMPLEX) {
      std::fprintf(stderr, "Can't generate class %s\n", t->name.c_str());
      continue;
    }

    write_class(out, t, request_types, result_types, w);
  }

  for (std::size_t function = 0; function < config.get_function_count(); function++) {
    tl_combinator *t = config.get_function_by_num(function);
    if (!w.is_combinator_supported(t)) {
      // std::fprintf(stderr, "Function %s is too hard to store\n", t->name.c_str());
      continue;
    }

    write_function(out, t, request_types, result_types, w);
  }
  out.append(w.gen_output_end());

  for (std::size_t type = 0; type < config.get_type_count(); type++) {
    tl_type *t = config.get_type_by_num(type);
    if (t->flags & FLAG_COMPLEX) {
      t->flags &= ~FLAG_COMPLEX;  // remove temporary flag
    }
  }
}

tl_config read_tl_config_from_file(const std::string &file_name) {
  std::string config = get_file_contents(file_name);
  if (config.empty()) {
    std::fprintf(stderr, "Config file %s is empty\n", file_name.c_str());
    std::abort();
  }
  if (config.size() % sizeof(std::int32_t) != 0) {
    std::fprintf(stderr, "Config size = %d is not multiple of %d\n", static_cast<int>(config.size()),
                 static_cast<int>(sizeof(std::int32_t)));
    std::abort();
  }

  tl_config_parser parser(config.c_str(), config.size());
  return parser.parse_config();
}

bool write_tl_to_file(const tl_config &config, const std::string &file_name, const TL_writer &w) {
  tl_string_outputer out;
  write_tl(config, out, w);
  return put_file_contents(file_name, out.get_result(), w.is_documentation_generated());
}

static std::string get_additional_imports(const std::map<std::string, bool> &types, const std::string base_class_name,
                                          const std::string &file_name_prefix, const std::string &file_name_suffix,
                                          const TL_writer &w) {
  std::string result =
      w.gen_import_declaration(file_name_prefix + "_" + base_class_name + w.gen_package_suffix(), false);
  if (w.gen_package_suffix() != file_name_suffix) {
    for (std::map<std::string, bool>::const_iterator it = types.begin(); it != types.end(); ++it) {
      std::string package_name = file_name_prefix + "_" + it->first + w.gen_package_suffix();
      result += w.gen_import_declaration(package_name, false);
    }
  }
  result += "\n";
  return result;
}

bool write_tl_to_multiple_files(const tl_config &config, const std::string &file_name_prefix,
                                const std::string &file_name_suffix, const TL_writer &w) {
  find_complex_types(config, w);

  std::map<std::string, tl_string_outputer> outs;

  tl_string_outputer *out = &outs["common"];
  out->append(w.gen_output_begin(std::string()));
  out->append(w.gen_output_begin_once());
  out->append(w.gen_output_end());

  std::set<std::string> request_types;
  std::set<std::string> result_types;
  for (std::size_t function = 0; function < config.get_function_count(); function++) {
    const tl_combinator *t = config.get_function_by_num(function);
    dfs_combinator(t, request_types, w);
    dfs_tree(t->result, result_types, w);
  }

  std::map<std::string, bool> object_types;
  for (std::size_t type = 0; type < config.get_type_count(); type++) {
    tl_type *t = config.get_type_by_num(type);
    if (t->constructors_num == 0 || w.is_built_in_simple_type(t->name) ||
        w.is_built_in_complex_type(t->name)) {  // built-in dummy or complex types
      continue;
    }

    if (t->flags & FLAG_COMPLEX) {
      std::fprintf(stderr, "Can't generate class %s\n", t->name.c_str());
      continue;
    }

    object_types[w.gen_main_class_name(t)] = (t->simple_constructors != 1);
    out = &outs[w.gen_main_class_name(t)];
    auto additional_imports =
        get_additional_imports(get_children_types(t, w), "Object", file_name_prefix, file_name_suffix, w);
    out->append(w.gen_output_begin(additional_imports));
    write_class(*out, t, request_types, result_types, w);
    out->append(w.gen_output_end());
  }

  std::map<std::string, bool> function_types;
  for (std::size_t function = 0; function < config.get_function_count(); function++) {
    tl_combinator *t = config.get_function_by_num(function);
    if (!w.is_combinator_supported(t)) {
      // std::fprintf(stderr, "Function %s is too hard to store\n", t->name.c_str());
      continue;
    }

    function_types[w.gen_class_name(t->name)] = false;
    out = &outs[w.gen_class_name(t->name)];
    auto additional_imports =
        get_additional_imports(get_children_types(t, w), "Function", file_name_prefix, file_name_suffix, w);
    out->append(w.gen_output_begin(additional_imports));
    write_function(*out, t, request_types, result_types, w);
    out->append(w.gen_output_end());
  }

  for (std::size_t type = 0; type < config.get_type_count(); type++) {
    tl_type *t = config.get_type_by_num(type);
    if (t->flags & FLAG_COMPLEX) {
      t->flags &= ~FLAG_COMPLEX;  // remove temporary flag
    }
  }

  out = &outs["Object"];
  out->append(
      w.gen_output_begin(get_additional_imports(object_types, "common", file_name_prefix, file_name_suffix, w)));
  write_base_object_classes(config, *out, request_types, result_types, w);
  out->append(w.gen_output_end());

  out = &outs["Function"];
  out->append(
      w.gen_output_begin(get_additional_imports(function_types, "common", file_name_prefix, file_name_suffix, w)));
  write_base_function_class(config, *out, request_types, result_types, w);
  out->append(w.gen_output_end());

  std::string additional_main_imports;
  for (std::map<std::string, tl_string_outputer>::const_iterator it = outs.begin(); it != outs.end(); ++it) {
    std::string file_name = file_name_prefix + "_" + it->first + file_name_suffix;
    if (!put_file_contents(file_name, it->second.get_result(), w.is_documentation_generated())) {
      return false;
    }

    if (file_name_suffix == w.gen_package_suffix()) {
      additional_main_imports += w.gen_import_declaration(file_name, false);
    }
  }
  if (!additional_main_imports.empty()) {
    additional_main_imports += "\n";
  }

  tl_string_outputer main_out;
  main_out.append(w.gen_output_begin(additional_main_imports));
  main_out.append(w.gen_output_end());

  return put_file_contents(file_name_prefix + file_name_suffix, main_out.get_result(), w.is_documentation_generated());
}

}  // namespace tl
}  // namespace td
