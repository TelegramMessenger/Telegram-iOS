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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "tl_writer.h"

#include "tl_core.h"

#include <cassert>
#include <cstdio>

namespace td {
namespace tl {

std::string TL_writer::int_to_string(int x) {
  char buf[15];
  std::sprintf(buf, "%d", x);
  return buf;
}

bool TL_writer::is_alnum(char c) {
  return ('0' <= c && c <= '9') || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z');
}

char TL_writer::to_lower(char c) {
  return 'A' <= c && c <= 'Z' ? static_cast<char>(c - 'A' + 'a') : c;
}

char TL_writer::to_upper(char c) {
  return 'a' <= c && c <= 'z' ? static_cast<char>(c - 'a' + 'A') : c;
}

std::vector<std::string> TL_writer::get_additional_functions() const {
  return std::vector<std::string>();
}

bool TL_writer::is_type_supported(const tl_tree_type *tree_type) const {
  if (tree_type->type->flags & FLAG_COMPLEX) {
    return false;
  }

  for (std::size_t i = 0; i < tree_type->children.size(); i++) {
    const tl_tree *child = tree_type->children[i];
    assert(child->get_type() == NODE_TYPE_TYPE || child->get_type() == NODE_TYPE_VAR_TYPE ||
           child->get_type() == NODE_TYPE_NAT_CONST || child->get_type() == NODE_TYPE_VAR_NUM);

    if (child->get_type() == NODE_TYPE_TYPE) {
      if (!is_type_supported(static_cast<const tl_tree_type *>(child))) {
        return false;
      }
    }
    if (child->get_type() == NODE_TYPE_VAR_TYPE) {
      return false;  // TODO
    }
  }

  return true;
}

bool TL_writer::is_combinator_supported(const tl_combinator *constructor) const {
  std::vector<bool> is_function_result(constructor->var_count);
  for (std::size_t i = 0; i < constructor->args.size(); i++) {
    const arg &a = constructor->args[i];

    int arg_type = a.type->get_type();
    if (arg_type == NODE_TYPE_VAR_TYPE) {
      const tl_tree_var_type *t = static_cast<const tl_tree_var_type *>(a.type);
      if (a.flags & FLAG_EXCL) {
        assert(t->var_num >= 0);
        if (is_function_result[t->var_num]) {
          return false;  // lazy to check that result of two function calls is the same
        }
        is_function_result[t->var_num] = true;
      } else {
        return false;  // do not support generic types
      }
    }
  }

  for (std::size_t i = 0; i < constructor->args.size(); i++) {
    const arg &a = constructor->args[i];

    int arg_type = a.type->get_type();
    if (a.var_num >= 0) {
      assert(arg_type == NODE_TYPE_TYPE);
      const tl_tree_type *a_type = static_cast<const tl_tree_type *>(a.type);
      if (a_type->type->id == ID_VAR_TYPE) {
        assert(!(a_type->flags & FLAG_EXCL));
        if (!is_function_result[a.var_num]) {
          assert(false);  // not possible, otherwise type is an argument of a type, but all types with type arguments
                          // are already marked complex
          return false;
        } else {
          continue;
        }
      }
    }

    if (arg_type == NODE_TYPE_VAR_TYPE) {
      continue;
    } else if (arg_type == NODE_TYPE_TYPE) {
      if (!is_type_supported(static_cast<const tl_tree_type *>(a.type))) {
        return false;
      }
    } else {
      assert(arg_type == NODE_TYPE_ARRAY);
      const tl_tree_array *arr = static_cast<const tl_tree_array *>(a.type);
      for (std::size_t j = 0; j < arr->args.size(); j++) {
        const arg &b = arr->args[j];
        assert(b.type->get_type() == NODE_TYPE_TYPE && b.var_num == -1);
        if (!is_type_supported(static_cast<const tl_tree_type *>(b.type))) {
          return false;
        }
      }
    }
  }

  tl_tree *result = constructor->result;
  if (result->get_type() == NODE_TYPE_TYPE) {
    if (!is_type_supported(static_cast<const tl_tree_type *>(result))) {
      return false;
    }
  } else {
    assert(result->get_type() == NODE_TYPE_VAR_TYPE);
    const tl_tree_var_type *t = static_cast<const tl_tree_var_type *>(result);
    return is_function_result[t->var_num];
  }

  return true;
}

bool TL_writer::is_documentation_generated() const {
  return false;
}

std::string TL_writer::gen_main_class_name(const tl_type *t) const {
  if (t->simple_constructors == 1) {
    for (std::size_t i = 0; i < t->constructors_num; i++) {
      if (is_combinator_supported(t->constructors[i])) {
        return gen_class_name(t->constructors[i]->name);
      }
    }
  }

  return gen_class_name(t->name);
}

int TL_writer::get_parser_type(const tl_combinator *t, const std::string &parser_name) const {
  return t->var_count > 0;
}

int TL_writer::get_storer_type(const tl_combinator *t, const std::string &storer_name) const {
  return 0;
}

int TL_writer::get_additional_function_type(const std::string &additional_function_name) const {
  return 0;
}

TL_writer::Mode TL_writer::get_parser_mode(int type) const {
  return All;
}

TL_writer::Mode TL_writer::get_storer_mode(int type) const {
  return All;
}

std::string TL_writer::gen_field_type(const arg &a) const {
  if (a.flags & FLAG_EXCL) {
    assert(a.flags == FLAG_EXCL);
    assert(a.type->get_type() == NODE_TYPE_VAR_TYPE);

    return gen_var_type_name();
  }

  assert(a.flags == FLAG_NOVAR || a.flags == 0 || a.flags == (FLAG_OPT_VAR | FLAG_NOVAR | FLAG_BARE));

  if (a.type->get_type() == NODE_TYPE_TYPE) {
    const tl_tree_type *arg_type = static_cast<const tl_tree_type *>(a.type);
    assert(arg_type->children.size() == static_cast<std::size_t>(arg_type->type->arity));

    if (arg_type->type->id == ID_VAR_TYPE) {
      return std::string();
    }

    return gen_type_name(arg_type);
  } else {
    assert(a.flags == FLAG_NOVAR || a.flags == 0);

    assert(a.type->get_type() == NODE_TYPE_ARRAY);
    const tl_tree_array *arg_array = static_cast<const tl_tree_array *>(a.type);
    assert((arg_array->flags & ~FLAG_NOVAR) == 0);
    return gen_array_type_name(arg_array, a.name);
  }
}

std::string TL_writer::gen_additional_function(const std::string &function_name, const tl_combinator *t,
                                               bool is_function) const {
  assert(false);
  return "";
}

std::string TL_writer::gen_additional_proxy_function_begin(const std::string &function_name, const tl_type *type,
                                                           const std::string &class_name, int arity,
                                                           bool is_function) const {
  assert(false);
  return "";
}

std::string TL_writer::gen_additional_proxy_function_case(const std::string &function_name, const tl_type *type,
                                                          const std::string &class_name, int arity) const {
  assert(false);
  return "";
}

std::string TL_writer::gen_additional_proxy_function_case(const std::string &function_name, const tl_type *type,
                                                          const tl_combinator *t, int arity, bool is_function) const {
  assert(false);
  return "";
}

std::string TL_writer::gen_additional_proxy_function_end(const std::string &function_name, const tl_type *type,
                                                         bool is_function) const {
  assert(false);
  return "";
}

}  // namespace tl
}  // namespace td
