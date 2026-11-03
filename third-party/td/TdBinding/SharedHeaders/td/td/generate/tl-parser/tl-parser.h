/*
    This file is part of tgl-libary/tlc

    Tgl-library/tlc is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    Tgl-library/tlc is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this tgl-library/tlc.  If not, see <http://www.gnu.org/licenses/>.

    Copyright Vitaly Valtman 2014

    It is derivative work of VK/KittenPHP-DB-Engine (https://github.com/vk-com/kphp-kdb/)
    Copyright 2012-2013 Vkontakte Ltd
              2012-2013 Vitaliy Valtman

*/

#ifndef __TL_PARSER_NEW_H__
#define __TL_PARSER_NEW_H__

#include <stdio.h>

enum lex_type {
  lex_error,
  lex_char, 
  lex_triple_minus,
  lex_uc_ident,
  lex_lc_ident,
  lex_eof,
  lex_final,
  lex_new,
  lex_none,
  lex_num,
  lex_empty
};


struct curlex {
  char *ptr;
  int len;
  enum lex_type type;
  int flags;
};

struct parse {
  char *text;
  int pos;
  int len;
  int line;
  int line_pos;
  struct curlex lex;
};


enum tree_type {
  type_tl_program,
  type_fun_declarations,
  type_constr_declarations,
  type_declaration,
  type_combinator_decl,
  type_equals,
  type_partial_app_decl,
  type_final_decl,
  type_full_combinator_id,
  type_opt_args,
  type_args,
  type_args1,
  type_args2,
  type_args3,
  type_args4,
  type_boxed_type_ident,
  type_subexpr,
  type_partial_comb_app_decl,
  type_partial_type_app_decl,
  type_final_new,
  type_final_final,
  type_final_empty,
//  type_type,
  type_var_ident,
  type_var_ident_opt,
  type_multiplicity,
  type_type_term,
  type_term,
  type_percent,
  type_result_type,
  type_expr,
  type_nat_term,
  type_combinator_id,
  type_nat_const,
  type_type_ident,
  type_builtin_combinator_decl,
  type_exclam,
  type_optional_arg_def
};

struct tree {
  char *text;
  int len;
  enum tree_type type;
  int lex_line;
  int lex_line_pos;
  int flags;
  int size;
  int nc;
  struct tree **c;
};


#define TL_ACT(x) (x == act_var ? "act_var" : x == act_field ? "act_field" : x == act_plus ? "act_plus" : x == act_type ? "act_type" : x == act_nat_const ? "act_nat_const" : x == act_array ? "act_array" : x == act_question_mark ? "act_question_mark" : \
    x == act_union ? "act_union" : x == act_arg ? "act_arg" : x == act_opt_field ? "act_opt_field" : "act_unknown")

#define TL_TYPE(x) (x == type_num ? "type_num" : x == type_type ? "type_type" : x == type_list_item ? "type_list_item" : x == type_list ? "type_list" : x == type_num_value ? "type_num_value" : "type_unknown")
enum combinator_tree_action {
  act_var,
  act_field,
  act_plus,
  act_type,
  act_nat_const,
  act_array,
  act_question_mark,
  act_union,
  act_arg,
  act_opt_field
};

enum combinator_tree_type {
  type_num,
  type_num_value,
  type_type,
  type_list_item,
  type_list
};

struct tl_combinator_tree {
  enum combinator_tree_action act;
  struct tl_combinator_tree *left, *right;
  char *name;
  void *data;
  long long flags;
  enum combinator_tree_type type;
  int type_len;
  long long type_flags;
};


struct tl_program {
  int types_num;
  int functions_num;
  int constructors_num;
  struct tl_type **types;
  struct tl_function **functions;
//  struct tl_constuctor **constructors;
};

struct tl_type {
  char *id;
  char *print_id;
  char *real_id;
  unsigned name;
  int flags;

  int params_num;  
  long long params_types;

  int constructors_num;
  struct tl_constructor **constructors;
};

struct tl_constructor {
  char *id;
  char *print_id;
  char *real_id;
  unsigned name;
  struct tl_type *type;

  struct tl_combinator_tree *left;
  struct tl_combinator_tree *right;
};

struct tl_var {
  char *id;
  struct tl_combinator_tree *ptr;
  int type;
  int flags;
};

struct parse *tl_init_parse_file (const char *fname);
struct tree *tl_parse_lex (struct parse *P);
void tl_print_parse_error (void);
struct tl_program *tl_parse (struct tree *T);

void write_types (FILE *f);

#define FLAG_BARE 1
#define FLAG_OPT_VAR (1 << 17)
#define FLAG_EXCL (1 << 18)
#define FLAG_OPT_FIELD (1 << 20)
#define FLAG_IS_VAR (1 << 21)
#define FLAG_DEFAULT_CONSTRUCTOR (1 << 25)
#define FLAG_EMPTY (1 << 10)

#ifdef NDEBUG
#undef assert
#define assert(x) if (!(x)) { fprintf(stderr, "Assertion error!\n"); abort(); }
#endif

#ifdef _WIN32
#include "wgetopt.h"

#define __attribute__(x)

#define lrand48() rand()
#define strdup _strdup
#endif

#endif
