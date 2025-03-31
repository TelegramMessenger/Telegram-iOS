/*
    This file is part of tl-parser 

    tl-parser is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    tl-parser is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this tl-parser.  If not, see <http://www.gnu.org/licenses/>.

    Copyright Vitaly Valtman 2014

    It is derivative work of VK/KittenPHP-DB-Engine (https://github.com/vk-com/kphp-kdb/)
    Copyright 2012-2013 Vkontakte Ltd
              2012-2013 Vitaliy Valtman

*/

#define _FILE_OFFSET_BITS 64

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <time.h>
#include "portable_endian.h"
#include "tl-parser-tree.h"
#include "tl-parser.h"
#include "crc32.h"
#include "tl-tl.h"

extern int verbosity;
extern int schema_version;
extern int output_expressions;


int total_types_num;
int total_constructors_num;
int total_functions_num;


/*char *tstrdup (const char *s) {
  assert (s);
  char *r = talloc (strlen (s) + 1);
  memcpy (r, s, strlen (s) + 1);
  return r;
}*/

#define talloc(a) malloc(a)
#define tfree(a,b) free (a)
#define talloc0(a) calloc(a,1)
#define tstrdup(a) strdup(a)

typedef char error_int_must_be_4_byte[(sizeof (int) == 4) ? 1 : -1];
typedef char error_long_long_must_be_8_byte[(sizeof (long long) == 8) ? 1 : -1];

char curch;
struct parse parse;

struct tree *tree;

struct tree *tree_alloc (void) {
  struct tree *T = talloc (sizeof (*T));
  assert (T);
  memset (T, 0, sizeof (*T));
  return T;
}

void tree_add_child (struct tree *P, struct tree *C) {
  if (P->nc == P->size) {
    void **t = talloc (sizeof (void *) * (++P->size));
    memcpy (t, P->c, sizeof (void *) * (P->size - 1));
    if (P->c) {
      tfree (P->c, sizeof (void *) * (P->size - 1));
    }
    P->c = (void *)t;
    assert (P->c);
  }
  P->c[P->nc ++] = C;
}

void tree_delete (struct tree *T) {
  assert (T);
  int i;
  for (i = 0; i < T->nc; i++) {
    assert (T->c[i]);
    tree_delete (T->c[i]);
  }
  if (T->c) {
    tfree (T->c, sizeof (void *) * T->nc);
  }
  tfree (T, sizeof (*T));
}

void tree_del_child (struct tree *P) {
  assert (P->nc);
  tree_delete (P->c[--P->nc]);
}


char nextch (void) {
  if (parse.pos < parse.len - 1) {
    curch = parse.text[++parse.pos];
  } else {
    curch = 0;
  }
  if (curch == 10) {
    parse.line ++;
    parse.line_pos = 0;
  } else {
    if (curch) {
      parse.line_pos ++;
    }
  }
  return curch;
}


struct parse save_parse (void) {
  return parse;
}

void load_parse (struct parse _parse) {
  parse = _parse;
  curch = parse.pos > parse.len ? 0:  parse.text[parse.pos] ;
}

int is_whitespace (char c) {
  return (c <= 32);
}

int is_uletter (char c) {
  return (c >= 'A' && c <= 'Z');
}

int is_lletter (char c) {
  return (c >= 'a' && c <= 'z');
}

int is_letter (char c) {
  return is_uletter (c) || is_lletter (c);
}

int is_digit (char c) {
  return (c >= '0' && c <= '9');
}

int is_hexdigit (char c) {
  return is_digit (c) || (c >= 'a' && c <= 'f');
}

int is_ident_char (char c) {
  return is_digit (c) || is_letter (c) || c == '_';
}

int last_error_pos;
int last_error_line;
int last_error_line_pos;
char *last_error;

void parse_error (const char *e) {
  if (parse.pos > last_error_pos) {
    last_error_pos = parse.pos;
    last_error_line = parse.line;
    last_error_line_pos = parse.line_pos;
    if (last_error) {
      tfree (last_error, strlen (last_error) + 1);
    }
    last_error = tstrdup (e);
  }
}

void tl_print_parse_error (void) {
  fprintf (stderr, "Error near line %d pos %d: `%s`\n", last_error_line + 1, last_error_line_pos + 1, last_error);
}

char *parse_lex (void) {
  while (1) {   
    while (curch && is_whitespace (curch)) { nextch (); }
    if (curch == '/' && nextch () == '/') {
      while (nextch () != 10);
      nextch ();
    } else {
      break;
    }
  }
  if (!curch) {
    parse.lex.len = 0;
    parse.lex.type = lex_eof;
    return (parse.lex.ptr = 0);
  }
  char *p = parse.text + parse.pos;
  parse.lex.flags = 0;
  switch (curch) {
  case '-':
    if (nextch () != '-' || nextch () != '-') {
      parse_error ("Can not parse triple minus");
      parse.lex.type = lex_error;
      return (parse.lex.ptr = (void *)-1);
    } else {
      parse.lex.len = 3;
      parse.lex.type = lex_triple_minus;
      nextch ();
      return (parse.lex.ptr = p);
    }
  case ':':
  case ';':
  case '(':
  case ')':
  case '[':
  case ']':
  case '{':
  case '}':
  case '=':
  case '#':
  case '?':
  case '%':
  case '<':
  case '>':
  case '+':
  case ',':
  case '*':
  case '_':
  case '!':
  case '.':
    nextch ();
    parse.lex.len = 1;
    parse.lex.type = lex_char;   
    return (parse.lex.ptr = p);
  case 'a':
  case 'b':
  case 'c':
  case 'd':
  case 'e':
  case 'f':
  case 'g':
  case 'h':
  case 'i':
  case 'j':
  case 'k':
  case 'l':
  case 'm':
  case 'n':
  case 'o':
  case 'p':
  case 'q':
  case 'r':
  case 's':
  case 't':
  case 'u':
  case 'v':
  case 'w':
  case 'x':
  case 'y':
  case 'z':
  case 'A':
  case 'B':
  case 'C':
  case 'D':
  case 'E':
  case 'F':
  case 'G':
  case 'H':
  case 'I':
  case 'J':
  case 'K':
  case 'L':
  case 'M':
  case 'N':
  case 'O':
  case 'P':
  case 'Q':
  case 'R':
  case 'S':
  case 'T':
  case 'U':
  case 'V':
  case 'W':
  case 'X':
  case 'Y':
  case 'Z':
    parse.lex.flags = 0;
    if (is_uletter (curch)) {
      while (is_ident_char (nextch ()));
      parse.lex.len = parse.text + parse.pos - p;
      parse.lex.ptr = p;
      if (parse.lex.len == 5 && !memcmp (parse.lex.ptr, "Final", 5)) {
        parse.lex.type = lex_final;
      } else if (parse.lex.len == 3 && !memcmp (parse.lex.ptr, "New", 3)) {
        parse.lex.type = lex_new;
      } else if (parse.lex.len == 5 && !memcmp (parse.lex.ptr, "Empty", 5)) {
        parse.lex.type = lex_empty;
      } else {
        parse.lex.type = lex_uc_ident;
      }
      return (parse.lex.ptr = p);
    }
    while (is_ident_char (nextch ()));
    if (curch == '.' && !is_letter (parse.text[parse.pos + 1])) {
      parse.lex.len = parse.text + parse.pos - p;
      parse.lex.type = lex_lc_ident;
      return (parse.lex.ptr = p);
    }
    while (curch == '.') {
      parse.lex.flags |= 1;
      nextch ();
      if (is_uletter (curch)) {
        while (is_ident_char (nextch ()));
        parse.lex.len = parse.text + parse.pos - p;
        parse.lex.type = lex_uc_ident;
        return (parse.lex.ptr = p);
      }
      if (is_lletter (curch)) {
        while (is_ident_char (nextch ()));
      } else {
        parse_error ("Expected letter");
        parse.lex.type = lex_error;
        return (parse.lex.ptr = (void *)-1);
      }
    }
    if (curch == '#') {
      parse.lex.flags |= 2;
      int i;
      int ok = 1;
      for (i = 0; i < 8; i++) {
        if (!is_hexdigit (nextch())) {
          if (curch ==  ' ' && i >= 5) { 
            ok = 2;
            break;
          } else {                     
            parse_error ("Hex digit expected");
            parse.lex.type = lex_error;
            return (parse.lex.ptr = (void *)-1);
          }
        }
      }
      if (ok == 1) {
        nextch ();
      }
    }
    parse.lex.len = parse.text + parse.pos - p;
    parse.lex.type = lex_lc_ident;
    return (parse.lex.ptr = p);
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
    while (is_digit (nextch ()));
    parse.lex.len = parse.text + parse.pos - p;
    parse.lex.type = lex_num;
    return (parse.lex.ptr = p);
  default:
    parse_error ("Unknown lexem");
    parse.lex.type = lex_error;
    return (parse.lex.ptr = (void *)-1);
  }
 
}

int expect (char *s) {
  if (!parse.lex.ptr || parse.lex.ptr == (void *)-1 || parse.lex.type == lex_error || parse.lex.type == lex_none || parse.lex.len != (int)strlen (s) || memcmp (s, parse.lex.ptr, parse.lex.len)) {
    static char buf[1000];
    sprintf (buf, "Expected %s", s);
    parse_error (buf);
    return -1;
  } else {
    parse_lex ();
  }
  return 1;
}

struct parse *tl_init_parse_file (const char *fname) {
  FILE *f = fopen (fname, "rb");
  if (f == NULL) {
    fprintf (stderr, "Failed to open the input file.\n");
    return NULL;
  }
  if (fseek (f, 0, SEEK_END) != 0) {
    fprintf (stderr, "Can't seek to the end of the input file.\n");
    return NULL;
  }
  long size = ftell (f);
  if (size <= 0 || size > INT_MAX) {
    fprintf (stderr, "Size is %ld. Too small or too big.\n", size);
    return NULL;
  }
  fseek (f, 0, SEEK_SET);

  static struct parse save;
  save.text = talloc ((size_t)size);
  save.len = fread (save.text, 1, (size_t)size, f);
  assert (save.len == size);
  fclose (f);
  save.pos = 0;
  save.line = 0;
  save.line_pos = 0;
  save.lex.ptr = save.text;
  save.lex.len = 0;
  save.lex.type = lex_none;
  return &save;
}

#define PARSE_INIT(_type) struct parse save = save_parse (); struct tree *T = tree_alloc (); T->type = (_type); T->lex_line = parse.line; T->lex_line_pos = parse.line_pos; struct tree *S __attribute__ ((unused));
#define PARSE_FAIL load_parse (save); tree_delete (T); return 0;
#define PARSE_OK return T;
#define PARSE_TRY_PES(x) if (!(S = x ())) { PARSE_FAIL; } { tree_add_child (T, S); }
#define PARSE_TRY_OPT(x) if ((S = x ())) { tree_add_child (T, S); PARSE_OK }
#define PARSE_TRY(x) S = x ();
#define PARSE_ADD(_type) S = tree_alloc (); S->type = _type; tree_add_child (T, S);
#define EXPECT(s) if (expect (s) < 0) { PARSE_FAIL; }
#define LEX_CHAR(c) (parse.lex.type == lex_char && *parse.lex.ptr == c)
struct tree *parse_args (void);
struct tree *parse_expr (void);

struct tree *parse_boxed_type_ident (void) {
  PARSE_INIT (type_boxed_type_ident);
  if (parse.lex.type != lex_uc_ident) {
    parse_error ("Can not parse boxed type");
    PARSE_FAIL;
  } else {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  }
}

struct tree *parse_full_combinator_id (void) {
  PARSE_INIT (type_full_combinator_id);
  if (parse.lex.type == lex_lc_ident || LEX_CHAR('_')) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse full combinator id");
    PARSE_FAIL;
  } 
}

struct tree *parse_combinator_id (void) {
  PARSE_INIT (type_combinator_id);
  if (parse.lex.type == lex_lc_ident && !(parse.lex.flags & 2)) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse combinator id");
    PARSE_FAIL;
  } 
}

struct tree *parse_var_ident (void) {
  PARSE_INIT (type_var_ident);
  if ((parse.lex.type == lex_lc_ident || parse.lex.type == lex_uc_ident) && !(parse.lex.flags & 3)) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse var ident");
    PARSE_FAIL;
  }
}

struct tree *parse_var_ident_opt (void) {
  PARSE_INIT (type_var_ident_opt);
  if ((parse.lex.type == lex_lc_ident || parse.lex.type == lex_uc_ident)&& !(parse.lex.flags & 3)) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else if (LEX_CHAR ('_')) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse var ident opt");
    PARSE_FAIL;
  }
}

struct tree *parse_nat_const (void) {
  PARSE_INIT (type_nat_const);
  if (parse.lex.type == lex_num) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse nat const");
    PARSE_FAIL;
  }
}

struct tree *parse_type_ident (void) {
  PARSE_INIT (type_type_ident);
  if (parse.lex.type == lex_uc_ident && !(parse.lex.flags & 2)) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else if (parse.lex.type == lex_lc_ident && !(parse.lex.flags & 2)) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else if (LEX_CHAR ('#')) {
    T->text = parse.lex.ptr;
    T->len = parse.lex.len;
    T->flags = parse.lex.flags;
    parse_lex ();
    PARSE_OK;
  } else {
    parse_error ("Can not parse type ident");
    PARSE_FAIL;
  }
}

struct tree *parse_term (void) {
  PARSE_INIT (type_term);
  while (LEX_CHAR ('%')) {
    EXPECT ("%")
    PARSE_ADD (type_percent);
  }
  if (LEX_CHAR ('(')) {
    EXPECT ("(");
    PARSE_TRY_PES (parse_expr);
    EXPECT (")");
    PARSE_OK;
  }
  PARSE_TRY (parse_type_ident);
  if (S) {
    tree_add_child (T, S);
    if (LEX_CHAR ('<')) {
      EXPECT ("<");
      while (1) {
        PARSE_TRY_PES (parse_expr);
        if (LEX_CHAR ('>')) { break; }
        EXPECT (",");
      }
      EXPECT (">");
    }
    PARSE_OK;
  }
  PARSE_TRY_OPT (parse_type_ident);
  PARSE_TRY_OPT (parse_var_ident);
  PARSE_TRY_OPT (parse_nat_const);
  PARSE_FAIL;
}

struct tree *parse_nat_term (void) {
  PARSE_INIT (type_nat_term);
  PARSE_TRY_PES (parse_term);
  PARSE_OK;
}

struct tree *parse_subexpr (void) {
  PARSE_INIT (type_subexpr);
  int was_term = 0;
  int cc = 0;

  while (1) {
    PARSE_TRY (parse_nat_const);
    if (S) {
      tree_add_child (T, S);
    } else if (!was_term) {
      was_term = 1;
      PARSE_TRY (parse_term);
      if (S) {
        tree_add_child (T, S);       
      } else {
        break;
      }
    }
    cc ++;
    if (!LEX_CHAR ('+')) {
      break;
    }
    EXPECT ("+");
  }
  if (!cc) {
    PARSE_FAIL;
  } else {
    PARSE_OK;
  }
}

struct tree *parse_expr (void) {
  PARSE_INIT (type_expr);
  int cc = 0;
  while (1) {
    PARSE_TRY (parse_subexpr);
    if (S) {
      tree_add_child (T, S);
      cc ++;
    } else {
      if (cc < 1) { PARSE_FAIL; }
      else { PARSE_OK; }
    }
  }
}



struct tree *parse_final_empty (void) {
  PARSE_INIT (type_final_empty);
  EXPECT ("Empty");
  PARSE_TRY_PES (parse_boxed_type_ident);
  PARSE_OK;
}

struct tree *parse_final_new (void) {
  PARSE_INIT (type_final_new);
  EXPECT ("New");
  PARSE_TRY_PES (parse_boxed_type_ident);
  PARSE_OK;
}

struct tree *parse_final_final (void) {
  PARSE_INIT (type_final_final);
  EXPECT ("Final");
  PARSE_TRY_PES (parse_boxed_type_ident);
  PARSE_OK;
}

struct tree *parse_partial_comb_app_decl (void) {
  PARSE_INIT (type_partial_comb_app_decl);
  PARSE_TRY_PES (parse_combinator_id);
  while (1) {
    PARSE_TRY_PES (parse_subexpr);
    if (LEX_CHAR (';')) { break; }
  }
  PARSE_OK;
}

struct tree *parse_partial_type_app_decl (void) {
  PARSE_INIT (type_partial_type_app_decl);
  PARSE_TRY_PES (parse_boxed_type_ident);
  if (LEX_CHAR ('<')) {
    EXPECT ("<");
    while (1) {
      PARSE_TRY_PES (parse_expr);
      if (LEX_CHAR ('>')) { break; }
      EXPECT (",");
    }
    EXPECT (">");
    PARSE_OK;
  } else {
    while (1) {
      PARSE_TRY_PES (parse_subexpr);
      if (LEX_CHAR (';')) { break; }
    }
    PARSE_OK;
  }
}




struct tree *parse_multiplicity (void) {
  PARSE_INIT (type_multiplicity);
  PARSE_TRY_PES (parse_nat_term);
  PARSE_OK;
}


struct tree *parse_type_term (void) {
  PARSE_INIT (type_type_term);
  PARSE_TRY_PES (parse_term);
  PARSE_OK;
}

struct tree *parse_optional_arg_def (void) {
  PARSE_INIT (type_optional_arg_def);
  PARSE_TRY_PES (parse_var_ident);
  EXPECT (".");
  PARSE_TRY_PES (parse_nat_const);
  EXPECT ("?");
  PARSE_OK;
}

struct tree *parse_args4 (void) {
  PARSE_INIT (type_args4);
  struct parse so = save_parse ();
  PARSE_TRY (parse_optional_arg_def);
  if (S) {
    tree_add_child (T, S);
  } else {
    load_parse (so);    
  }
  if (LEX_CHAR ('!')) {
    PARSE_ADD (type_exclam);
    EXPECT ("!");
  }
  PARSE_TRY_PES (parse_type_term);
  PARSE_OK;
}

struct tree *parse_args3 (void) {
  PARSE_INIT (type_args3);
  PARSE_TRY_PES (parse_var_ident_opt);
  EXPECT (":");
  struct parse so = save_parse ();
  PARSE_TRY (parse_optional_arg_def);
  if (S) {
    tree_add_child (T, S);
  } else {
    load_parse (so);    
  }
  if (LEX_CHAR ('!')) {
    PARSE_ADD (type_exclam);
    EXPECT ("!");
  }
  PARSE_TRY_PES (parse_type_term);
  PARSE_OK;
}

struct tree *parse_args2 (void) {
  PARSE_INIT (type_args2);
  PARSE_TRY (parse_var_ident_opt);
  if (S && LEX_CHAR (':')) {
    tree_add_child (T, S);
    EXPECT (":");
  } else {
    load_parse (save);
  }
  struct parse so = save_parse ();
  PARSE_TRY (parse_optional_arg_def);
  if (S) {
    tree_add_child (T, S);
  } else {
    load_parse (so);    
  }
  struct parse save2 = save_parse ();
  PARSE_TRY (parse_multiplicity);
  if (S && LEX_CHAR ('*')) {
    tree_add_child (T, S);
    EXPECT ("*");
  } else {
    load_parse (save2);
  }
  EXPECT ("[");
  while (1) {
    if (LEX_CHAR (']')) { break; }
    PARSE_TRY_PES (parse_args);
  }
  EXPECT ("]");
  PARSE_OK;
}

struct tree *parse_args1 (void) {
  PARSE_INIT (type_args1);
  EXPECT ("(");
  while (1) {
    PARSE_TRY_PES (parse_var_ident_opt);
    if (LEX_CHAR(':')) { break; }
  }
  EXPECT (":");
  struct parse so = save_parse ();
  PARSE_TRY (parse_optional_arg_def);
  if (S) {
    tree_add_child (T, S);
  } else {
    load_parse (so);    
  }
  if (LEX_CHAR ('!')) {
    PARSE_ADD (type_exclam);
    EXPECT ("!");
  }
  PARSE_TRY_PES (parse_type_term);
  EXPECT (")");
  PARSE_OK;
}

struct tree *parse_args (void) {
  PARSE_INIT (type_args);
  PARSE_TRY_OPT (parse_args1);
  PARSE_TRY_OPT (parse_args2);
  PARSE_TRY_OPT (parse_args3);
  PARSE_TRY_OPT (parse_args4);
  PARSE_FAIL;
}

struct tree *parse_opt_args (void) {
  PARSE_INIT (type_opt_args);
  while (1) {
    PARSE_TRY_PES (parse_var_ident);
    if (parse.lex.type == lex_char && *parse.lex.ptr == ':') { break;}
  }
  EXPECT (":");
  PARSE_TRY_PES (parse_type_term);
  PARSE_OK;
}

struct tree *parse_final_decl (void) {
  PARSE_INIT (type_final_decl);
  PARSE_TRY_OPT (parse_final_new);
  PARSE_TRY_OPT (parse_final_final);
  PARSE_TRY_OPT (parse_final_empty);
  PARSE_FAIL;
}

struct tree *parse_partial_app_decl (void) {
  PARSE_INIT (type_partial_app_decl);
  PARSE_TRY_OPT (parse_partial_type_app_decl);
  PARSE_TRY_OPT (parse_partial_comb_app_decl);
  PARSE_FAIL;
}

struct tree *parse_result_type (void) {
  PARSE_INIT (type_result_type);
  PARSE_TRY_PES (parse_boxed_type_ident);
  if (LEX_CHAR ('<')) {
    EXPECT ("<");
    while (1) {
      PARSE_TRY_PES (parse_expr);
      if (LEX_CHAR ('>')) { break; }
      EXPECT (",");
    }
    EXPECT (">");
    PARSE_OK;
  } else {
    while (1) {
      if (LEX_CHAR (';')) { PARSE_OK; }
      PARSE_TRY_PES (parse_subexpr);
    }
  }
}

struct tree *parse_combinator_decl (void) {
  PARSE_INIT (type_combinator_decl);
  PARSE_TRY_PES (parse_full_combinator_id)
  while (1) {
    if (LEX_CHAR ('{')) {
      parse_lex ();
      PARSE_TRY_PES (parse_opt_args);
      EXPECT ("}");
    } else {
      break;
    }
  }
  while (1) {
    if (LEX_CHAR ('=')) { break; }
    PARSE_TRY_PES (parse_args);
  }
  EXPECT ("=");
  PARSE_ADD (type_equals);

  PARSE_TRY_PES (parse_result_type);
  PARSE_OK;
}

struct tree *parse_builtin_combinator_decl (void) {
  PARSE_INIT (type_builtin_combinator_decl);
  PARSE_TRY_PES (parse_full_combinator_id)
  EXPECT ("?");
  EXPECT ("=");
  PARSE_TRY_PES (parse_boxed_type_ident);
  PARSE_OK;
}

struct tree *parse_declaration (void) {
  PARSE_INIT (type_declaration);
  PARSE_TRY_OPT (parse_combinator_decl);
  PARSE_TRY_OPT (parse_partial_app_decl);
  PARSE_TRY_OPT (parse_final_decl);
  PARSE_TRY_OPT (parse_builtin_combinator_decl);
  PARSE_FAIL;
}

struct tree *parse_constr_declarations (void) {
  PARSE_INIT (type_constr_declarations);
  if (parse.lex.type == lex_triple_minus || parse.lex.type == lex_eof) { PARSE_OK; }
  while (1) {
    PARSE_TRY_PES (parse_declaration);
    EXPECT (";");
    if (parse.lex.type == lex_eof || parse.lex.type == lex_triple_minus) { PARSE_OK; }
  }
}

struct tree *parse_fun_declarations (void) {
  PARSE_INIT (type_fun_declarations);
  if (parse.lex.type == lex_triple_minus || parse.lex.type == lex_eof) { PARSE_OK; }
  while (1) {
    PARSE_TRY_PES (parse_declaration);
    EXPECT (";");
    if (parse.lex.type == lex_eof || parse.lex.type == lex_triple_minus) { PARSE_OK; }
  }
}

struct tree *parse_program (void) {
  PARSE_INIT (type_tl_program);
  while (1) {
    PARSE_TRY_PES (parse_constr_declarations);
    if (parse.lex.type == lex_eof) { PARSE_OK; }
    if (parse.lex.type == lex_error || expect ("---") < 0 || expect ("functions") < 0 || expect ("---") < 0) { PARSE_FAIL; }

    PARSE_TRY_PES (parse_fun_declarations);
    if (parse.lex.type == lex_eof) { PARSE_OK; }
    if (parse.lex.type == lex_error || expect ("---") < 0 || expect ("types") < 0 || expect ("---") < 0) { PARSE_FAIL; }
  }
}

struct tree *tl_parse_lex (struct parse *_parse) {
  assert (_parse);
  load_parse (*_parse);
  if (parse.lex.type == lex_none) {
    parse_lex ();
  }
  if (parse.lex.type == lex_error) {
    return 0;
  }
  return parse_program ();
}

int mystrcmp2 (const char *b, int len, const char *a) {
  int c = strncmp (b, a, len);
  return c ? a[len] ? -1 : 0 : c;
}

char *mystrdup (const char *a, int len) {
  char *z = talloc (len + 1);
  memcpy (z, a, len);
  z[len] = 0;
  return z;
}

struct tl_program *tl_program_cur;
#define TL_TRY_PES(x) if (!(x)) { return 0; }

#define tl_type_cmp(a,b) (strcmp (a->id, b->id))
DEFINE_TREE (tl_type,struct tl_type *,tl_type_cmp,0)
struct tree_tl_type *tl_type_tree;

DEFINE_TREE (tl_constructor,struct tl_constructor *,tl_type_cmp,0)
struct tree_tl_constructor *tl_constructor_tree;
struct tree_tl_constructor *tl_function_tree;

DEFINE_TREE (tl_var,struct tl_var *,tl_type_cmp,0)

struct tl_var_value {
  struct tl_combinator_tree *ptr;
  struct tl_combinator_tree *val;
  int num_val;
};

#define tl_var_value_cmp(a,b) (((char *)a.ptr) - ((char *)b.ptr))
struct tl_var_value empty;
DEFINE_TREE (var_value, struct tl_var_value, tl_var_value_cmp, empty)
//tree_tl_var_t *tl_var_tree;

DEFINE_TREE (tl_field,char *,strcmp, 0)
//tree_tl_field_t *tl_field_tree;
#define TL_FAIL return 0;
#define TL_INIT(x) struct tl_combinator_tree *x = 0;
#define TL_TRY(f,x) { struct tl_combinator_tree *_t = f; if (!_t) { TL_FAIL;} x = tl_union (x, _t); if (!x) { TL_FAIL; }}
#define TL_ERROR(...) fprintf (stderr, __VA_ARGS__);
#define TL_WARNING(...) fprintf (stderr, __VA_ARGS__);

void tl_set_var_value (struct tree_var_value **T, struct tl_combinator_tree *var, struct tl_combinator_tree *value) {
  struct tl_var_value t = {.ptr = var, .val = value, .num_val = 0};
  if (tree_lookup_var_value (*T, t).ptr) {
    *T = tree_delete_var_value (*T, t);
  }
  *T = tree_insert_var_value (*T, t, lrand48 ());
}

void tl_set_var_value_num (struct tree_var_value **T, struct tl_combinator_tree *var, struct tl_combinator_tree *value, long long num_value) {
  struct tl_var_value t = {.ptr = var, .val = value, .num_val = num_value};
  if (tree_lookup_var_value (*T, t).ptr) {
    *T = tree_delete_var_value (*T, t);
  }
  *T = tree_insert_var_value (*T, t, lrand48 ());
}

struct tl_combinator_tree *tl_get_var_value (struct tree_var_value **T, struct tl_combinator_tree *var) {
  struct tl_var_value t = {.ptr = var, .val = 0, .num_val = 0};
  struct tl_var_value r = tree_lookup_var_value (*T, t);
  return r.ptr ? r.val : 0;
}

int tl_get_var_value_num (struct tree_var_value **T, struct tl_combinator_tree *var) {
  struct tl_var_value t = {.ptr = var, .val = 0};
  struct tl_var_value r = tree_lookup_var_value (*T, t);
  return r.ptr ? r.num_val : 0;
}

int namespace_level;

struct tree_tl_var *vars[10];
struct tree_tl_field *fields[10];
struct tl_var *last_num_var[10];

int tl_is_type_name (const char *id, int len) {
  if (len == 1 && *id == '#') { return 1;}
  int ok = id[0] >= 'A' && id[0] <= 'Z';
  int i;
  for (i = 0; i < len - 1; i++) if (id[i] == '.') {
    ok = id[i + 1] >= 'A' && id[i + 1] <= 'Z';
  }
  return ok;
}

int tl_add_field (char *id) {
  assert (namespace_level < 10);
  assert (namespace_level >= 0);
  if (tree_lookup_tl_field (fields[namespace_level], id)) {
    return 0;
  }
  fields[namespace_level] = tree_insert_tl_field (fields[namespace_level], id, lrand48 ());
  return 1;
}

void tl_clear_fields (void) {
//  tree_act_tl_field (fields[namespace_level], (void *)free); 
  fields[namespace_level] = tree_clear_tl_field (fields[namespace_level]); 
}

struct tl_var *tl_add_var (char *id, struct tl_combinator_tree *ptr, int type) {
  struct tl_var *v = talloc (sizeof (*v));
  v->id = tstrdup (id);
  v->type = type;
  v->ptr = ptr;
  v->flags = 0;
  if (tree_lookup_tl_var (vars[namespace_level], v)) {
    return 0;
  }
  vars[namespace_level] = tree_insert_tl_var (vars[namespace_level], v, lrand48 ());
  if (type) {
    last_num_var[namespace_level] = v;
  }
  return v;
}

void tl_del_var (struct tl_var *v) {
//  free (v->id);
  tfree (v, sizeof (*v));
}

void tl_clear_vars (void) {
  tree_act_tl_var (vars[namespace_level], tl_del_var);
  vars[namespace_level] = tree_clear_tl_var (vars[namespace_level]);
  last_num_var[namespace_level] = 0;
}

struct tl_var *tl_get_last_num_var (void) {
  return last_num_var[namespace_level];
}

struct tl_var *tl_get_var (char *_id, int len) {
  char *id = mystrdup (_id, len);
  struct tl_var v = {.id = id};
  int i;
  for (i = namespace_level; i >= 0; i--) {
    struct tl_var *w = tree_lookup_tl_var (vars[i], &v);
    if (w) {
      tfree (id, len + 1);
      return w;
    }
  }
  tfree (id, len + 1);
  return 0;
}

void namespace_push (void) {
  namespace_level ++;
  assert (namespace_level < 10);
  tl_clear_vars ();
  tl_clear_fields ();
}

void namespace_pop (void) {
  namespace_level --;
  assert (namespace_level >= 0);
}

struct tl_type *tl_get_type (const char *_id, int len) {
  char *id = mystrdup (_id, len);
  struct tl_type _t = {.id = id};
  struct tl_type *r = tree_lookup_tl_type (tl_type_tree, &_t);
  tfree (id, len + 1);
  return r;
}

struct tl_type *tl_add_type (const char *_id, int len, int params_num, long long params_types) {
  char *id = talloc (len + 1);
  memcpy (id, _id, len);
  id[len] = 0;
  struct tl_type _t = {.id = id};
  struct tl_type *_r = 0;
  if ((_r = tree_lookup_tl_type (tl_type_tree, &_t))) {
    tfree (id, len + 1);
    if (params_num >= 0 && (_r->params_num != params_num || _r->params_types != params_types)) {
      TL_ERROR ("Wrong params_num or types for type %s\n", _r->id);
      return 0;
    }
    return _r;
  }
  struct tl_type *t = talloc (sizeof (*t));
  t->id = id;
  t->print_id = tstrdup (t->id);
  int i;
  for (i = 0; i < len; i++) if (t->print_id[i] == '.' || t->print_id[i] == '#' || t->print_id[i] == ' ') {
    t->print_id[i] = '$';
  }
  t->name = 0;
  t->constructors_num = 0;
  t->constructors = 0;
  t->flags = 0;
  t->real_id = 0;
  if (params_num >= 0) {
    assert (params_num <= 64);
    t->params_num = params_num;
    t->params_types = params_types;
  } else {
    t->flags |= 4;
    t->params_num = -1;
  }
  tl_type_tree = tree_insert_tl_type (tl_type_tree, t, lrand48 ());
  total_types_num ++;
  return t;
}

void tl_add_type_param (struct tl_type *t, int x) {
  assert (t->flags & 4);
  assert (t->params_num <= 64); 
  if (x) {
    t->params_types |= (1ull << (t->params_num ++));   
  } else {
    t->params_num ++;
  }
}

int tl_type_set_params (struct tl_type *t, int x, long long y) {
  if (t->flags & 4) {
    t->params_num = x;
    t->params_types = y;
    t->flags &= ~4;
  } else {
    if (t->params_num != x || t->params_types != y) {
      fprintf (stderr, "Wrong num of params (type %s)\n", t->id);
      return 0;
    }
  }
  return 1;
}

void tl_type_finalize (struct tl_type *t) {
  t->flags &= ~4;
}

struct tl_constructor *tl_get_constructor (const char *_id, int len) {
  char *id = mystrdup (_id, len);
  struct tl_constructor _t = {.id = id};
  struct tl_constructor *r = tree_lookup_tl_constructor (tl_constructor_tree, &_t);
  tfree (id, len + 1);
  return r;
}

struct tl_constructor *tl_add_constructor (struct tl_type *a, const char *_id, int len, int force_magic) {
  assert (a);
  if (a->flags & 1) {
    TL_ERROR ("New constructor for type `%s` after final statement\n", a->id);
    return 0;
  }
  int x = 0;
  while (x < len && (_id[x] != '#' || force_magic)) { x++; }
  char *id = talloc (x + 1);
  memcpy (id, _id, x);
  id[x] = 0;

  unsigned magic = 0;
  if (x < len) {
    assert (len - x >= 6 && len - x <= 9);
    int i;
    for (i = 1; i < len - x; i++) {
      magic = (magic << 4) + (_id[x + i] <= '9' ? _id[x + i] - '0' : _id[x + i] - 'a' + 10);
    }
    assert (magic && magic != (unsigned)-1);
  }

  len = x;
  if (*id != '_') {
    struct tl_constructor _t = {.id = id};
    if (tree_lookup_tl_constructor (tl_constructor_tree, &_t)) {
      TL_ERROR ("Duplicate constructor id `%s`\n", id);
      tfree (id, len + 1);
      return 0;
    }
  } else {
    assert (len == 1);
  }

  struct tl_constructor *t = talloc (sizeof (*t));
  t->type = a;
  t->name = magic;
  t->id = id; 
  t->print_id = tstrdup (id);
  t->real_id = 0;

  int i;
  for (i = 0; i < len; i++) if (t->print_id[i] == '.' || t->print_id[i] == '#' || t->print_id[i] == ' ') {
    t->print_id[i] = '$';
  }

  t->left = t->right = 0;
  a->constructors = realloc (a->constructors, sizeof (void *) * (a->constructors_num + 1));
  assert (a->constructors);
  a->constructors[a->constructors_num ++] = t;
  if (*id != '_') {
    tl_constructor_tree = tree_insert_tl_constructor (tl_constructor_tree, t, lrand48 ());
  } else {
    a->flags |= FLAG_DEFAULT_CONSTRUCTOR;
  }
  total_constructors_num ++;
  return t;
}

struct tl_constructor *tl_get_function (const char *_id, int len) {
  char *id = mystrdup (_id, len);
  struct tl_constructor _t = {.id = id};
  struct tl_constructor *r = tree_lookup_tl_constructor (tl_function_tree, &_t);
  tfree (id, len + 1);
  return r;
}

struct tl_constructor *tl_add_function (struct tl_type *a, const char *_id, int len, int force_magic) {
//  assert (a);
  int x = 0;
  while (x < len && ((_id[x] != '#') || force_magic)) { x++; }
  char *id = talloc (x + 1);
  memcpy (id, _id, x);
  id[x] = 0;

  unsigned magic = 0;
  if (x < len) {
    assert (len - x >= 6 && len - x <= 9);
    int i;
    for (i = 1; i < len - x; i++) {
      magic = (magic << 4) + (_id[x + i] <= '9' ? _id[x + i] - '0' : _id[x + i] - 'a' + 10);
    }
    assert (magic && magic != (unsigned)-1);
  }

  len = x;

  struct tl_constructor _t = {.id = id};
  if (tree_lookup_tl_constructor (tl_function_tree, &_t)) {
    TL_ERROR ("Duplicate function id `%s`\n", id);
    tfree (id, len + 1);
    return 0;
  }

  struct tl_constructor *t = talloc (sizeof (*t));
  t->type = a;
  t->name = magic;
  t->id = id; 
  t->print_id = tstrdup (id);
  t->real_id = 0;

  int i;
  for (i = 0; i < len; i++) if (t->print_id[i] == '.' || t->print_id[i] == '#' || t->print_id[i] == ' ') {
    t->print_id[i] = '$';
  }

  t->left = t->right = 0;
  tl_function_tree = tree_insert_tl_constructor (tl_function_tree, t, lrand48 ());
  total_functions_num ++;
  return t;
}

static char buf[(1 << 20)];
int buf_pos;

struct tl_combinator_tree *alloc_ctree_node (void) {
  struct tl_combinator_tree *T = talloc (sizeof (*T));
  assert (T);
  memset (T, 0, sizeof (*T));
  return T;
}

struct tl_combinator_tree *tl_tree_dup (struct tl_combinator_tree *T) {
  if (!T) { return 0; }
  struct tl_combinator_tree *S = talloc (sizeof (*S));
  memcpy (S, T, sizeof (*S));
  S->left = tl_tree_dup (T->left);
  S->right = tl_tree_dup (T->right);
  return S;
}

struct tl_type *tl_tree_get_type (struct tl_combinator_tree *T) {
  assert (T->type == type_type);
  if (T->act == act_array) { return 0;}
  while (T->left) {
    T = T->left;
    if (T->act == act_array) { return 0;}
    assert (T->type == type_type);
  }
  assert (T->act == act_type || T->act == act_var || T->act == act_array);
  return T->act == act_type ? T->data : 0;
}

void tl_tree_set_len (struct tl_combinator_tree *T) {
  TL_INIT (H);
  H = T;
  while (H->left) {
    H->left->type_len = H->type_len + 1;
    H = H->left;
  }
  assert (H->type == type_type);
  struct tl_type *t = H->data;
  assert (t);
  assert (H->type_len == t->params_num);
}

void tl_buf_reset (void) {
  buf_pos = 0;
}

void tl_buf_add_string (char *s, int len) {
  if (len < 0) { len = strlen (s); }
  buf[buf_pos ++] = ' ';
  memcpy (buf + buf_pos, s, len); buf_pos += len;
  buf[buf_pos] = 0;
}

void tl_buf_add_string_nospace (char *s, int len) {
  if (len < 0) { len = strlen (s); }
//  if (buf_pos) { buf[buf_pos ++] = ' '; }
  memcpy (buf + buf_pos, s, len); buf_pos += len;
  buf[buf_pos] = 0;
}

void tl_buf_add_string_q (char *s, int len, int x) {
  if (x) {
    tl_buf_add_string (s, len);
  } else {
    tl_buf_add_string_nospace (s, len);
  }
}


void tl_buf_add_tree (struct tl_combinator_tree *T, int x) {
  if (!T) { return; }
  assert (T != (void *)-1l && T != (void *)-2l);
  switch (T->act) {
  case act_question_mark:
    tl_buf_add_string_q ("?", -1, x);
    return;
  case act_type:
    if ((T->flags & 1) && !(T->flags & 4)) {
      tl_buf_add_string_q ("%", -1, x);
      x = 0;
    }
    if (T->flags & 2) {
      tl_buf_add_string_q ((char *)T->data, -1, x);
    } else {
      struct tl_type *t = T->data;
      if (T->flags & 4) {
        assert (t->constructors_num == 1);
        tl_buf_add_string_q (t->constructors[0]->real_id ? t->constructors[0]->real_id : t->constructors[0]->id, -1, x);
      } else {
        tl_buf_add_string_q (t->real_id ? t->real_id : t->id, -1, x);
      }
    }
    return;
  case act_field:
    if (T->data) {
      tl_buf_add_string_q ((char *)T->data, -1, x);
      x = 0;
      tl_buf_add_string_q (":", -1, 0);
    }
    tl_buf_add_tree (T->left, x);
    tl_buf_add_tree (T->right, 1);
    return;
  case act_union:
    tl_buf_add_tree (T->left, x);
    tl_buf_add_tree (T->right, 1);
    return;
  case act_var:
    {
      if (T->data == (void *)-1l) { return; }
      struct tl_combinator_tree *v = T->data;
      tl_buf_add_string_q ((char *)v->data, -1, x);
      if (T->type == type_num && T->type_flags) {
        static char _buf[30];
        sprintf (_buf, "+%lld", T->type_flags);
        tl_buf_add_string_q (_buf, -1, 0);
      }
    }
    return;
  case act_arg:
    tl_buf_add_tree (T->left, x);
    tl_buf_add_tree (T->right, 1);
    return;
  case act_array:
    if (T->left && !(T->left->flags & 128)) {
      tl_buf_add_tree (T->left, x);
      x = 0;
      tl_buf_add_string_q ("*", -1, x);
    }
    tl_buf_add_string_q ("[", -1, x);
    tl_buf_add_tree (T->right, 1);
    tl_buf_add_string_q ("]", -1, 1);
    return;
  case act_plus:
    tl_buf_add_tree (T->left, x);
    tl_buf_add_string_q ("+", -1, 0);
    tl_buf_add_tree (T->right, 0);
    return;
  case act_nat_const:
    {
      static char _buf[30];
      snprintf (_buf, 29, "%lld", T->type_flags);
      tl_buf_add_string_q (_buf, -1, x);
      return;
    }
  case act_opt_field:
    {
      struct tl_combinator_tree *v = T->left->data;
      tl_buf_add_string_q ((char *)v->data, -1, x);
      tl_buf_add_string_q (".", -1, 0);
      static char _buf[30];
      sprintf (_buf, "%lld", T->left->type_flags);
      tl_buf_add_string_q (_buf, -1, 0);
      tl_buf_add_string_q ("?", -1, 0);
      tl_buf_add_tree (T->right, 0);
      return;
    }
    
  default:
    fprintf (stderr, "%s %s\n", TL_ACT (T->act), TL_TYPE (T->type));
    assert (0);
    return;
  }
}

int tl_count_combinator_name (struct tl_constructor *c) {
  assert (c);
  tl_buf_reset ();
  tl_buf_add_string_nospace (c->real_id ? c->real_id : c->id, -1);
  tl_buf_add_tree (c->left, 1);
  tl_buf_add_string ("=", -1);
  tl_buf_add_tree (c->right, 1);
  //fprintf (stderr, "%.*s\n", buf_pos, buf);
  if (!c->name) {
    c->name = compute_crc32 (buf, buf_pos);
  }
  return c->name;
}

int tl_print_combinator (struct tl_constructor *c) {
  tl_buf_reset ();
  tl_buf_add_string_nospace (c->real_id ? c->real_id : c->id, -1);
  static char _buf[10];
  sprintf (_buf, "#%08x", c->name);
  tl_buf_add_string_nospace (_buf, -1);
  tl_buf_add_tree (c->left, 1);
  tl_buf_add_string ("=", -1);
  tl_buf_add_tree (c->right, 1);
  if (output_expressions >= 1) {
    fprintf (stderr, "%.*s\n", buf_pos, buf);
  }
/*  if (!c->name) {
    c->name = compute_crc32 (buf, buf_pos);
  }*/
  return c->name;
}

int _tl_finish_subtree (struct tl_combinator_tree *R, int x, long long y) {
  assert (R->type == type_type);
  assert (R->type_len < 0);
  assert (R->act == act_arg || R->act == act_type);
  R->type_len = x;
  R->type_flags = y;
  if (R->act == act_type) {
    struct tl_type *t = R->data;
    assert (t);
    return tl_type_set_params (t, x, y);
  }
  assert ((R->right->type == type_type && R->right->type_len == 0) || R->right->type == type_num || R->right->type == type_num_value);
  return _tl_finish_subtree (R->left, x + 1, y * 2 + (R->right->type == type_num || R->right->type == type_num_value));
}

int tl_finish_subtree (struct tl_combinator_tree *R) {
  assert (R);
  if (R->type != type_type) {
    return 1;
  }
  if (R->type_len >= 0) {
    if (R->type_len > 0) {
      TL_ERROR ("Not enough params\n");
      return 0;
    }
    return 1;
  }
  return _tl_finish_subtree (R, 0, 0);
}

struct tl_combinator_tree *tl_union (struct tl_combinator_tree *L, struct tl_combinator_tree *R) {
  if (!L) { return R; }
  if (!R) { return L; }
  TL_INIT (v);
  v = alloc_ctree_node ();
  v->left = L;
  v->right = R;
  switch (L->type) {
  case type_num:
    if (R->type != type_num_value) {
      TL_ERROR ("Union: type mistmatch\n");
      return 0;
    }
    tfree (v, sizeof (*v));
    L->type_flags += R->type_flags;
    return L;
  case type_num_value:
    if (R->type != type_num_value && R->type != type_num) {
      TL_ERROR ("Union: type mistmatch\n");
      return 0;
    }
    tfree (v, sizeof (*v));
    R->type_flags += L->type_flags;
    return R;
  case type_list_item:   
  case type_list:
    if (R->type != type_list_item) {
      TL_ERROR ("Union: type mistmatch\n");
      return 0;
    }
    v->type = type_list;
    v->act = act_union;
    return v;
  case type_type:
    if (L->type_len == 0) {
      TL_ERROR ("Arguments number exceeds type arity\n");
      return 0;     
    }
    if (R->type != type_num && R->type != type_type && R->type != type_num_value) {
      TL_ERROR ("Union: type mistmatch\n");
      return 0;
    }
    if (R->type_len < 0) {
      if (!tl_finish_subtree (R)) {
        return 0;
      }
    }
    if (R->type_len > 0) {
      TL_ERROR ("Argument type must have full number of arguments\n");
      return 0;     
    }
    if (L->type_len > 0 && ((L->type_flags & 1) != (R->type == type_num || R->type == type_num_value))) {
      TL_ERROR ("Argument types mistmatch: L->type_flags = %lld, R->type = %s\n", L->flags, TL_TYPE (R->type));
      return 0;
    }
    v->type = type_type;
    v->act = act_arg;
    v->type_len = L->type_len > 0 ? L->type_len - 1 : -1;
    v->type_flags = L->type_flags >> 1;
    return v;
  default:
    assert (0);
    return 0;
  }
}

struct tl_combinator_tree *tl_parse_any_term (struct tree *T, int s);
struct tl_combinator_tree *tl_parse_term (struct tree *T, int s) {
  assert (T->type == type_term);
  int i = 0;
  while (i < T->nc && T->c[i]->type == type_percent) { i ++; s ++; } 
  assert (i < T->nc);
  TL_INIT (L);
  while (i < T->nc) {
    TL_TRY (tl_parse_any_term (T->c[i], s), L);
    s = 0;
    i ++;
  }
  return L;
}


struct tl_combinator_tree *tl_parse_type_term (struct tree *T, int s) {
  assert (T->type == type_type_term);
  assert (T->nc == 1);
  struct tl_combinator_tree *Z = tl_parse_term (T->c[0], s); 
  if (!Z || Z->type != type_type) { if (Z) { TL_ERROR ("type_term: found type %s\n", TL_TYPE (Z->type)); } TL_FAIL; }
  return Z;
}

struct tl_combinator_tree *tl_parse_nat_term (struct tree *T, int s) {
  assert (T->type == type_nat_term);
  assert (T->nc == 1);
  struct tl_combinator_tree *Z = tl_parse_term (T->c[0], s);
  if (!Z || (Z->type != type_num && Z->type != type_num_value)) { if (Z) { TL_ERROR ("nat_term: found type %s\n", TL_TYPE (Z->type)); }TL_FAIL; }
  return Z;
}

struct tl_combinator_tree *tl_parse_subexpr (struct tree *T, int s) {
  assert (T->type == type_subexpr);
  assert (T->nc >= 1);
  int i;
  TL_INIT (L);
  for (i = 0; i < T->nc; i++) {
    TL_TRY (tl_parse_any_term (T->c[i], s), L);
    s = 0;
  }
  return L;
}

struct tl_combinator_tree *tl_parse_expr (struct tree *T, int s) {
  assert (T->type == type_expr);
  assert (T->nc >= 1);
  int i;
  TL_INIT (L);
  for (i = 0; i < T->nc; i++) {
    TL_TRY (tl_parse_subexpr (T->c[i], s), L);
    s = 0;
  }
  return L;
}

struct tl_combinator_tree *tl_parse_nat_const (struct tree *T, int s) {
  assert (T->type == type_nat_const);
  assert (!T->nc);
  if (s > 0) {
    TL_ERROR ("Nat const can not preceed with %%\n");
    TL_FAIL;
  }
  assert (T->type == type_nat_const);
  assert (!T->nc);
  TL_INIT (L);
  L = alloc_ctree_node ();
  L->act = act_nat_const;
  L->type = type_num_value;
  int i;
  long long x = 0;
  for (i = 0; i < T->len; i++) {
    x = x * 10 + T->text[i] - '0';
  }
  L->type_flags = x;
  return L;
}

struct tl_combinator_tree *tl_parse_ident (struct tree *T, int s) {
  assert (T->type == type_type_ident || T->type == type_var_ident || T->type == type_boxed_type_ident);
  assert (!T->nc);
  struct tl_var *v = tl_get_var (T->text, T->len);
  TL_INIT (L);
  if (v) {   
    L = alloc_ctree_node ();
    L->act = act_var;
    L->type = v->type ? type_num : type_type;
    if (L->type == type_num && s) {
      TL_ERROR ("Nat var can not preceed with %%\n");
      TL_FAIL;
    } else {
      if (s) {
        L->flags |= 1;
      }
    }
    L->type_len = 0;
    L->type_flags = 0;
    L->data = v->ptr;
    return L;
  }

/*  if (!mystrcmp2 (T->text, T->len, "#") || !mystrcmp2 (T->text, T->len, "Type")) {
    L = alloc_ctree_node ();
    L->act = act_type;
    L->flags |= 2;
    L->data = tl_get_type (T->text, T->len);
    assert (L->data);
    L->type = type_type;
    L->type_len = 0;
    L->type_flags = 0;
    return L;
  }*/

  struct tl_constructor *c = tl_get_constructor (T->text, T->len);
  if (c) {
    assert (c->type);
    if (c->type->constructors_num != 1) {
      TL_ERROR ("Constructor can be used only if it is the only constructor of the type\n");
      return 0;
    }
    c->type->flags |= 1;
    L = alloc_ctree_node ();
    L->act = act_type;
    L->flags |= 5;
    L->data = c->type;
    L->type = type_type;
    L->type_len = c->type->params_num;
    L->type_flags = c->type->params_types;
    return L;
  }
  int x = tl_is_type_name (T->text, T->len);
  if (x) {
    struct tl_type *t = tl_add_type (T->text, T->len, -1, 0);
    L = alloc_ctree_node ();
    if (s) {
      L->flags |= 1;
      t->flags |= 8;
    }
    L->act = act_type;
    L->data = t;
    L->type = type_type;
    L->type_len = t->params_num;
    L->type_flags = t->params_types;   
    return L;
  } else {
    TL_ERROR ("Not a type/var ident `%.*s`\n", T->len, T->text);
    return 0;
  }
}

struct tl_combinator_tree *tl_parse_any_term (struct tree *T, int s) {
  switch (T->type) {
  case type_type_term:
    return tl_parse_type_term (T, s);
  case type_nat_term:
    return tl_parse_nat_term (T, s);
  case type_term:
    return tl_parse_term (T, s);
  case type_expr:
    return tl_parse_expr (T, s);
  case type_subexpr:
    return tl_parse_subexpr (T, s);
  case type_nat_const:
    return tl_parse_nat_const (T, s);
  case type_type_ident:
  case type_var_ident:
    return tl_parse_ident (T, s);
  default:
    fprintf (stderr, "type = %d\n", T->type);
    assert (0);
    return 0;    
  }
}

struct tl_combinator_tree *tl_parse_multiplicity (struct tree *T) {
  assert (T->type == type_multiplicity);
  assert (T->nc == 1);
  return tl_parse_nat_term (T->c[0], 0);
}

struct tl_combinator_tree *tl_parse_opt_args (struct tree *T) {
  assert (T);
  assert (T->type == type_opt_args);
  assert (T->nc >= 2);
  TL_INIT (R);
  TL_TRY (tl_parse_type_term (T->c[T->nc - 1], 0), R);
  assert (R->type == type_type && !R->type_len);
  assert (tl_finish_subtree (R));
  struct tl_type *t = tl_tree_get_type (R);
  //assert (t);
  int tt = -1;
  if (t && !strcmp (t->id, "#")) {
    tt = 1;
  } else if (t && !strcmp (t->id, "Type")) {
    tt = 0;
  }
  if (tt < 0) {
    TL_ERROR ("Optargs can be only of type # or Type\n");
    TL_FAIL;
  }

  int i;
  for (i = 0; i < T->nc - 1; i++) {
    if (T->c[i]->type != type_var_ident) {
      TL_ERROR ("Variable name expected\n");
      TL_FAIL;
    }
    if (T->c[i]->len == 1 && *T->c[i]->text == '_') {
      TL_ERROR ("Variables can not be unnamed\n");
      TL_FAIL;
    }
  }
  TL_INIT (H);
//  for (i = T->nc - 2; i >= (T->nc >= 2 ? 0 : -1); i--) {
  for (i = 0; i <= T->nc - 2; i++) {
    TL_INIT (S); S = alloc_ctree_node ();
    S->left = (i == T->nc - 2) ? R : tl_tree_dup (R) ; S->right = 0;
    S->type = type_list_item;
    S->type_len = 0;
    S->act = act_field;
    S->data = i >= 0 ? mystrdup (T->c[i]->text, T->c[i]->len) : 0;
    if (tt >= 0) {
      assert (S->data);
      tl_add_var (S->data, S, tt);
    }
    S->flags = 33;
    H = tl_union (H, S);
  }
  return H;
}

struct tl_combinator_tree *tl_parse_args (struct tree *T);
struct tl_combinator_tree *tl_parse_args2 (struct tree *T) {
  assert (T);
  assert (T->type == type_args2);
  assert (T->nc >= 1);
  TL_INIT (R);
  TL_INIT (L);
  int x = 0;
  char *field_name = 0;
  if (T->c[x]->type == type_var_ident_opt || T->c[x]->type == type_var_ident) {
    field_name = mystrdup (T->c[x]->text, T->c[x]->len);
    if (!tl_add_field (field_name)) {
      TL_ERROR ("Duplicate field name %s\n", field_name);     
      TL_FAIL;
    }
    x ++;
  } 
  //fprintf (stderr, "%d %d\n", x, T->nc);
  if (T->c[x]->type == type_multiplicity) {
    L = tl_parse_multiplicity (T->c[x]);
    if (!L) { TL_FAIL;}
    x ++;
  } else {
    struct tl_var *v = tl_get_last_num_var ();
    if (!v) { 
      TL_ERROR ("Expected multiplicity or nat var\n");
      TL_FAIL;
    }
    L = alloc_ctree_node ();
    L->act = act_var;
    L->type = type_num;
    L->flags |= 128;
    L->type_len = 0;
    L->type_flags = 0;
    L->data = v->ptr;
    ((struct tl_combinator_tree *)(v->ptr))->flags |= 256;
  }
  namespace_push ();
  while (x < T->nc) {
    TL_TRY (tl_parse_args (T->c[x]), R);
    x ++;
  }
  namespace_pop ();
  struct tl_combinator_tree *S = alloc_ctree_node ();
  S->type = type_type;
  S->type_len = 0;
  S->act = act_array;
  S->left = L;
  S->right = R;
  //S->data = field_name;

  struct tl_combinator_tree *H = alloc_ctree_node ();
  H->type = type_list_item;
  H->act = act_field;
  H->left = S;
  H->right = 0;
  H->data = field_name;
  H->type_len = 0;
 
  return H;
}

void tl_mark_vars (struct tl_combinator_tree *T);
struct tl_combinator_tree *tl_parse_args134 (struct tree *T) {
  assert (T);
  assert (T->type == type_args1 || T->type == type_args3 || T->type == type_args4);
  assert (T->nc >= 1);
  TL_INIT (R);
  TL_TRY (tl_parse_type_term (T->c[T->nc - 1], 0), R);
  assert (tl_finish_subtree (R));
  assert (R->type == type_type && !R->type_len);
  struct tl_type *t = tl_tree_get_type (R);
  //assert (t);
  int tt = -1;
  if (t && !strcmp (t->id, "#")) {
    tt = 1;
  } else if (t && !strcmp (t->id, "Type")) {
    tt = 0;
  }

/*  if (tt >= 0 && T->nc == 1) {
    TL_ERROR ("Variables can not be unnamed (type %d)\n", tt);
  }*/
  int last = T->nc - 2;
  int excl = 0;
  if (last >= 0 && T->c[last]->type == type_exclam) {
    excl ++;
    tl_mark_vars (R);
    last --;
  }
  if (last >= 0 && T->c[last]->type == type_optional_arg_def) {
    assert (T->c[last]->nc == 2);
    TL_INIT (E); E = alloc_ctree_node ();
    E->type = type_type;
    E->act = act_opt_field;
    E->left = tl_parse_ident (T->c[last]->c[0], 0);
    int i;
    long long x = 0;
    for (i = 0; i < T->c[last]->c[1]->len; i++) {
      x = x * 10 + T->c[last]->c[1]->text[i] - '0';
    }
    E->left->type_flags = x;
    E->type_flags = R->type_flags;
    E->type_len = R->type_len;
    E->right = R;
    R = E;
    last --;
  }
  int i;
  for (i = 0; i < last; i++) {
    if (T->c[i]->type != type_var_ident && T->c[i]->type != type_var_ident_opt) {
      TL_ERROR ("Variable name expected\n");
      TL_FAIL;
    }
/*    if (tt >= 0 && (T->nc == 1 || (T->c[i]->len == 1 && *T->c[i]->text == '_'))) {
      TL_ERROR ("Variables can not be unnamed\n");
      TL_FAIL;
    }*/
  }
  TL_INIT (H);
//  for (i = T->nc - 2; i >= (T->nc >= 2 ? 0 : -1); i--) {
  for (i = (last >= 0 ? 0 : -1); i <= last; i++) {
    TL_INIT (S); S = alloc_ctree_node ();
    S->left = (i == last) ? R : tl_tree_dup (R) ; S->right = 0;
    S->type = type_list_item;
    S->type_len = 0;
    S->act = act_field;
    S->data = i >= 0 ? mystrdup (T->c[i]->text, T->c[i]->len) : 0;
    if (excl) {
      S->flags |= FLAG_EXCL;
    }
    if (S->data && (T->c[i]->len >= 2 || *T->c[i]->text != '_')) {
      if (!tl_add_field (S->data)) {
        TL_ERROR ("Duplicate field name %s\n", (char *)S->data);
        TL_FAIL;
      }
    }
    if (tt >= 0) {
      //assert (S->data);
      char *name = S->data;
      if (!name) {
        static char s[20];
        sprintf (s, "%lld", lrand48 () * (1ll << 32) + lrand48 ());
        name = s;
      }
      struct tl_var *v = tl_add_var (name, S, tt);
      if (!v) {TL_FAIL;}
      v->flags |= 2;
    }
    
    H = tl_union (H, S);
  }
  return H;
}


struct tl_combinator_tree *tl_parse_args (struct tree *T) {
  assert (T->type == type_args);
  assert (T->nc == 1);
  switch (T->c[0]->type) {
  case type_args1:
    return tl_parse_args134 (T->c[0]);
  case type_args2:
    return tl_parse_args2 (T->c[0]);
  case type_args3:
    return tl_parse_args134 (T->c[0]);
  case type_args4:
    return tl_parse_args134 (T->c[0]);
  default:
    assert (0);
    return 0;
  } 
}

void tl_mark_vars (struct tl_combinator_tree *T) {
  if (!T) { return; }
  if (T->act == act_var) {
    char *id = ((struct tl_combinator_tree *)(T->data))->data;
    struct tl_var *v = tl_get_var (id, strlen (id));
    assert (v);
    v->flags |= 1;
  }
  tl_mark_vars (T->left);
  tl_mark_vars (T->right);
}

struct tl_combinator_tree *tl_parse_result_type (struct tree *T) {
  assert (T->type == type_result_type);
  assert (T->nc >= 1);
  assert (T->nc <= 64);
  
  TL_INIT (L);

  if (tl_get_var (T->c[0]->text, T->c[0]->len)) {
    if (T->nc != 1) {
      TL_ERROR ("Variable can not take params\n");
      TL_FAIL;
    }
    L = alloc_ctree_node ();
    L->act = act_var;
    L->type = type_type;
    struct tl_var *v = tl_get_var (T->c[0]->text, T->c[0]->len);
    if (v->type) {
      TL_ERROR ("Type mistmatch\n");
      TL_FAIL;
    }
    L->data = v->ptr;
//    assert (v->ptr);
  } else {
    L = alloc_ctree_node ();
    L->act = act_type;
    L->type = type_type;
    struct tl_type *t = tl_add_type (T->c[0]->text, T->c[0]->len, -1, 0);
    assert (t);
    L->type_len = t->params_num;
    L->type_flags = t->params_types;
    L->data = t;

    int i;
    for (i = 1; i < T->nc; i++) {
      TL_TRY (tl_parse_any_term (T->c[i], 0), L);
      assert (L->right);   
      assert (L->right->type == type_num || L->right->type == type_num_value || (L->right->type == type_type && L->right->type_len == 0));
    }
  }

  if (!tl_finish_subtree (L)) {
    TL_FAIL;
  }

  tl_mark_vars (L);
  return L;
}

int __ok;
void tl_var_check_used (struct tl_var *v) {
  __ok = __ok && (v->flags & 3);
}

int tl_parse_combinator_decl (struct tree *T, int fun) {
  assert (T->type == type_combinator_decl);
  assert (T->nc >= 3);
  namespace_level = 0;
  tl_clear_vars ();
  tl_clear_fields ();
  TL_INIT (L);
  TL_INIT (R);

  int i = 1;
  while (i < T->nc - 2 && T->c[i]->type == type_opt_args) {
    TL_TRY (tl_parse_opt_args (T->c[i]), L);
    i++;
  }
  while (i < T->nc - 2 && T->c[i]->type == type_args) {
    TL_TRY (tl_parse_args (T->c[i]), L);
    i++;
  }
  assert (i == T->nc - 2 && T->c[i]->type == type_equals);
  i ++;

  R = tl_parse_result_type (T->c[i]);
  if (!R) { TL_FAIL; }

  struct tl_type *t = tl_tree_get_type (R);
  if (!fun && !t) {
    TL_ERROR ("Only functions can return variables\n");
  }
  assert (t || fun);
 
  assert (namespace_level == 0);
  __ok = 1;
  tree_act_tl_var (vars[0], tl_var_check_used);
  if (!__ok) {
    TL_ERROR ("Not all variables are used in right side\n");
    TL_FAIL;
  }
 
  if (tl_get_constructor (T->c[0]->text, T->c[0]->len) || tl_get_function (T->c[0]->text, T->c[0]->len)) {
    TL_ERROR ("Duplicate combinator id %.*s\n", T->c[0]->len, T->c[0]->text);
    return 0;
  }
  struct tl_constructor *c = !fun ? tl_add_constructor (t, T->c[0]->text, T->c[0]->len, 0) : tl_add_function (t, T->c[0]->text, T->c[0]->len, 0);
  if (!c) { TL_FAIL; }
  c->left = L;
  c->right = R;
 
  if (!c->name) {
    tl_count_combinator_name (c);
  }
  tl_print_combinator (c);

  return 1;
}

void change_var_ptrs (struct tl_combinator_tree *O, struct tl_combinator_tree *D, struct tree_var_value **V) {
  if (!O || !D) {
    assert (!O && !D);
    return;
  }
  if (O->act == act_field) {
    struct tl_type *t = tl_tree_get_type (O->left);
    if (t && (!strcmp (t->id, "#") || !strcmp (t->id, "Type"))) {
      tl_set_var_value (V, O, D);
    }
  }
  if (O->act == act_var) {
    assert (D->data == O->data);
    D->data = tl_get_var_value (V, O->data);
    assert (D->data);
  }
  change_var_ptrs (O->left, D->left, V);
  change_var_ptrs (O->right, D->right, V);
}

struct tl_combinator_tree *change_first_var (struct tl_combinator_tree *O, struct tl_combinator_tree **X, struct tl_combinator_tree *Y) {
  if (!O) { return (void *)-2l; };
  if (O->act == act_field && !*X) {
    struct tl_type *t = tl_tree_get_type (O->left);
    if (t && !strcmp (t->id, "#")) {
      if (Y->type != type_num && Y->type != type_num_value) {
        TL_ERROR ("change_var: Type mistmatch\n");
        return 0;
      } else {
        *X = O;
        return (void *)-1l;
      }
    }
    if (t && !strcmp (t->id, "Type")) {
      if (Y->type != type_type || Y->type_len != 0) {
        TL_ERROR ("change_var: Type mistmatch\n");
        return 0;
      } else {
        *X = O;
        return (void *)-1l;
      }
    }
  }
  if (O->act == act_var) {
    if (O->data == *X) {
      struct tl_combinator_tree *R = tl_tree_dup (Y);
      if (O->type == type_num || O->type == type_num_value) { R->type_flags += O->type_flags; }
      return R;      
    }
  }
  struct tl_combinator_tree *t;
  t = change_first_var (O->left, X, Y);
  if (!t) { return 0;}
  if (t == (void *)-1l) {
    t = change_first_var (O->right, X, Y);
    if (!t) { return 0;}
    if (t == (void *)-1l) { return (void *)-1l; }
    if (t != (void *)-2l) { return t;}
    return (void *)-1l;   
  }
  if (t != (void *)-2l) {
    O->left = t;
  }
  t = change_first_var (O->right, X, Y);
  if (!t) { return 0;}
  if (t == (void *)-1l) {
    return O->left;   
  }
  if (t != (void *)-2l) {
    O->right = t;
  }
  return O;
}


int uniformize (struct tl_combinator_tree *L, struct tl_combinator_tree *R, struct tree_var_value **T);
struct tree_var_value **_T;
int __tok;
void check_nat_val (struct tl_var_value v) {
  if (!__tok) { return; }
  long long x = v.num_val;
  struct tl_combinator_tree *L = v.val;
  if (L->type == type_type) { return;}
  while (1) {
    if (L->type == type_num_value) {
      if (x + L->type_flags < 0) {
        __tok = 0;
        return;
      } else {
        return;
      }
    }
    assert (L->type == type_num);
    x += L->type_flags;
    x += tl_get_var_value_num (_T, L->data);
    L = tl_get_var_value (_T, L->data);
    if (!L) { return;}
  }
}

int check_constructors_equal (struct tl_combinator_tree *L, struct tl_combinator_tree *R, struct tree_var_value **T) {
  if (!uniformize (L, R, T)) { return 0; }
  __tok = 1;
  _T = T;
  tree_act_var_value (*T, check_nat_val);
  return __tok;
}

struct tl_combinator_tree *reduce_type (struct tl_combinator_tree *A, struct tl_type *t) {
  assert  (A);
  if (A->type_len == t->params_num) {
    assert (A->type_flags == t->params_types);
    A->act = act_type;
    A->type = type_type;
    A->left = A->right = 0;
    A->data = t;
    return A;
  }
  A->left = reduce_type (A->left, t);
  return A;
}

struct tl_combinator_tree *change_value_var (struct tl_combinator_tree *O, struct tree_var_value **X) {
  if (!O) { return (void *)-2l; };
  while (O->act == act_var) {
    assert (O->data);
    if (!tl_get_var_value (X, O->data)) {
      break;
    }
    if (O->type == type_type) {
      O = tl_tree_dup (tl_get_var_value (X, O->data));
    } else {
      long long n = tl_get_var_value_num (X, O->data);
      struct tl_combinator_tree *T = tl_get_var_value (X, O->data);
      O->data = T->data;
      O->type = T->type;
      O->act = T->act;
      O->type_flags = O->type_flags + n + T->type_flags;
    }
  }
  if (O->act == act_field) {
    if (tl_get_var_value (X, O)) { return (void *)-1l; }
  }
  struct tl_combinator_tree *t;
  t = change_value_var (O->left, X);
  if (!t) { return 0;}
  if (t == (void *)-1l) {
    t = change_value_var (O->right, X);
    if (!t) { return 0;}
    if (t == (void *)-1l) { return (void *)-1l; }
    if (t != (void *)-2l) { return t;}
    return (void *)-1l;   
  }
  if (t != (void *)-2l) {
    O->left = t;
  }
  t = change_value_var (O->right, X);
  if (!t) { return 0;}
  if (t == (void *)-1l) {
    return O->left;   
  }
  if (t != (void *)-2l) {
    O->right = t;
  }
  return O;
}

int tl_parse_partial_type_app_decl (struct tree *T) {
  assert (T->type == type_partial_type_app_decl);
  assert (T->nc >= 1);

  assert (T->c[0]->type == type_boxed_type_ident);
  struct tl_type *t = tl_get_type (T->c[0]->text, T->c[0]->len);
  if (!t) {
    TL_ERROR ("Can not make partial app for unknown type\n");
    return 0;
  }

  tl_type_finalize (t);

  struct tl_combinator_tree *L = tl_parse_ident (T->c[0], 0);
  assert (L);
  int i;
  tl_buf_reset ();
  int cc = T->nc - 1;
  for (i = 1; i < T->nc; i++) {
    TL_TRY (tl_parse_any_term (T->c[i], 0), L);
    tl_buf_add_tree (L->right, 1);
  }

  while (L->type_len) {
    struct tl_combinator_tree *C = alloc_ctree_node ();
    C->act = act_var;
    C->type = (L->type_flags & 1) ? type_num : type_type;
    C->type_len = 0;
    C->type_flags = 0;
    C->data = (void *)-1l;
    L = tl_union (L, C);
    if (!L) { return 0; }
  }


  static char _buf[100000];
  snprintf (_buf, 100000, "%s%.*s", t->id, buf_pos, buf);
  struct tl_type *nt = tl_add_type (_buf, strlen (_buf), t->params_num - cc, t->params_types >> cc);
  assert (nt);
  //snprintf (_buf, 100000, "%s #", t->id);
  //nt->real_id = strdup (_buf);
 
  for (i = 0; i < t->constructors_num; i++) {
    struct tl_constructor *c = t->constructors[i];
    struct tree_var_value *V = 0;
    TL_INIT (A);
    TL_INIT (B);
    A = tl_tree_dup (c->left);
    B = tl_tree_dup (c->right);
   
    struct tree_var_value *W = 0;
    change_var_ptrs (c->left, A, &W);
    change_var_ptrs (c->right, B, &W);


    if (!check_constructors_equal (B, L, &V)) { continue; }
    B = reduce_type (B, nt);
    A = change_value_var (A, &V);
    if (A == (void *)-1l) { A = 0;}
    B = change_value_var (B, &V);
    assert (B != (void *)-1l);
    snprintf (_buf, 100000, "%s%.*s", c->id, buf_pos, buf);

    struct tl_constructor *r = tl_add_constructor (nt, _buf, strlen (_buf), 1);
    snprintf (_buf, 100000, "%s", c->id);
    r->real_id = tstrdup (_buf);
   
    r->left = A;
    r->right = B;
    if (!r->name) {
      tl_count_combinator_name (r);
    }
    tl_print_combinator (r);
  }

  return 1;
}

int tl_parse_partial_comb_app_decl (struct tree *T, int fun) {
  assert (T->type == type_partial_comb_app_decl);

  struct tl_constructor *c = !fun ? tl_get_constructor (T->c[0]->text, T->c[0]->len) : tl_get_function (T->c[0]->text, T->c[0]->len);
  if (!c) {
    TL_ERROR ("Can not make partial app for undefined combinator\n");
    return 0;
  }

  //TL_INIT (K);
  //static char buf[1000];
  //int x = sprintf (buf, "%s", c->id);
  TL_INIT (L);
  TL_INIT (R);
  L = tl_tree_dup (c->left);
  R = tl_tree_dup (c->right);
 
 
  struct tree_var_value *V = 0;
  change_var_ptrs (c->left, L, &V);
  change_var_ptrs (c->right, R, &V);
  V = tree_clear_var_value (V);

  int i;
  tl_buf_reset ();
  for (i = 1; i < T->nc; i++) {
    TL_INIT (X);
    TL_INIT (Z);
    X = tl_parse_any_term (T->c[i], 0);
    struct tl_combinator_tree *K = 0;
    if (!(Z = change_first_var (L, &K, X))) {    
      TL_FAIL;
    }
    L = Z;
    if (!K) {
      TL_ERROR ("Partial app: not enougth variables (i = %d)\n", i);
      TL_FAIL;
    }
    if (!(Z = change_first_var (R, &K, X))) {
      TL_FAIL;
    }
    assert (Z == R);
    tl_buf_add_tree (X, 1);
  }

  static char _buf[100000];
  snprintf (_buf, 100000, "%s%.*s", c->id, buf_pos, buf);
//  fprintf (stderr, "Local id: %s\n", _buf);

  struct tl_constructor *r = !fun ? tl_add_constructor (c->type, _buf, strlen (_buf), 1) : tl_add_function (c->type, _buf, strlen (_buf), 1);
  r->left = L;
  r->right = R;
  snprintf (_buf, 100000, "%s", c->id);
  r->real_id = tstrdup (_buf);
  if (!r->name) {
    tl_count_combinator_name (r);
  }
  tl_print_combinator (r);
  return 1;
}


int tl_parse_partial_app_decl (struct tree *T, int fun) {
  assert (T->type == type_partial_app_decl);
  assert (T->nc == 1);
  if (T->c[0]->type == type_partial_comb_app_decl) {
    return tl_parse_partial_comb_app_decl (T->c[0], fun);
  } else {
    if (fun) {
      TL_ERROR ("Partial type app in functions block\n");
      TL_FAIL;
    }
    return tl_parse_partial_type_app_decl (T->c[0]);
  }
}

int tl_parse_final_final (struct tree *T) {
  assert (T->type == type_final_final);
  assert (T->nc == 1);
  struct tl_type *R;
  if ((R = tl_get_type (T->c[0]->text, T->c[0]->len))) {
    R->flags |= 1;
    return 1;
  } else {
    TL_ERROR ("Final statement for type `%.*s` before declaration\n", T->c[0]->len, T->c[0]->text);
    TL_FAIL;
  }
}

int tl_parse_final_new (struct tree *T) {
  assert (T->type == type_final_new);
  assert (T->nc == 1);
  if (tl_get_type (T->c[0]->text, T->c[0]->len)) {
    TL_ERROR ("New statement: type `%.*s` already declared\n", T->c[0]->len, T->c[0]->text);
    TL_FAIL;
  } else {
    return 1;
  }
}

int tl_parse_final_empty (struct tree *T) {
  assert (T->type == type_final_empty);
  assert (T->nc == 1);
  if (tl_get_type (T->c[0]->text, T->c[0]->len)) {
    TL_ERROR ("New statement: type `%.*s` already declared\n", T->c[0]->len, T->c[0]->text);
    TL_FAIL;
  }
  struct tl_type *t = tl_add_type (T->c[0]->text, T->c[0]->len, 0, 0);
  assert (t);
  t->flags |= 1 | FLAG_EMPTY;
  return 1;
}

int tl_parse_final_decl (struct tree *T, int fun) {
  assert (T->type == type_final_decl);
  assert (!fun);
  assert (T->nc == 1);
  switch (T->c[0]->type) {
  case type_final_new:
    return tl_parse_final_new (T->c[0]);
  case type_final_final:
    return tl_parse_final_final (T->c[0]);
  case type_final_empty:
    return tl_parse_final_empty (T->c[0]);
  default:
    assert (0);
    return 0;
  }
}

int tl_parse_builtin_combinator_decl (struct tree *T, int fun) {
  if (fun) {
    TL_ERROR ("Builtin type can not be described in function block\n");
    return -1;
  }
  assert (T->type == type_builtin_combinator_decl);
  assert (T->nc == 2);
  assert (T->c[0]->type == type_full_combinator_id);
  assert (T->c[1]->type == type_boxed_type_ident);


  if ((!mystrcmp2 (T->c[0]->text, T->c[0]->len, "int") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "Int")) ||
      (!mystrcmp2 (T->c[0]->text, T->c[0]->len, "long") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "Long")) ||
      (!mystrcmp2 (T->c[0]->text, T->c[0]->len, "double") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "Double")) ||
      (!mystrcmp2 (T->c[0]->text, T->c[0]->len, "object") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "Object")) ||
      (!mystrcmp2 (T->c[0]->text, T->c[0]->len, "function") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "Function")) ||
      (!mystrcmp2 (T->c[0]->text, T->c[0]->len, "string") && !mystrcmp2 (T->c[1]->text, T->c[1]->len, "String"))) {
    struct tl_type *t = tl_add_type (T->c[1]->text, T->c[1]->len, 0, 0);
    if (!t) {
      return 0;
    }
    struct tl_constructor *c = tl_add_constructor (t, T->c[0]->text, T->c[0]->len, 0);
    if (!c) {
      return 0;
    }
   
    c->left = alloc_ctree_node ();
    c->left->act = act_question_mark;
    c->left->type = type_list_item;

    c->right = alloc_ctree_node ();
    c->right->act = act_type;
    c->right->data = t;
    c->right->type = type_type;

    if (!c->name) {
      tl_count_combinator_name (c);
    }
    tl_print_combinator (c);
  } else {
    TL_ERROR ("Unknown builting type `%.*s`\n", T->c[0]->len, T->c[0]->text);
    return 0;
  }

  return 1;
}

int tl_parse_declaration (struct tree *T, int fun) {
  assert (T->type == type_declaration);
  assert (T->nc == 1);
  switch (T->c[0]->type) {
  case type_combinator_decl:
    return tl_parse_combinator_decl (T->c[0], fun);
  case type_partial_app_decl:
    return tl_parse_partial_app_decl (T->c[0], fun);
  case type_final_decl:
    return tl_parse_final_decl (T->c[0], fun);
  case type_builtin_combinator_decl:
    return tl_parse_builtin_combinator_decl (T->c[0], fun);
  default:
    assert (0);
    return 0;
  }
}

int tl_parse_constr_declarations (struct tree *T) {
  assert (T->type == type_constr_declarations);
  int i;
  for (i = 0; i < T->nc; i++) {
    TL_TRY_PES (tl_parse_declaration (T->c[i], 0));
  }
  return 1;
}

int tl_parse_fun_declarations (struct tree *T) {
  assert (T->type == type_fun_declarations);
  int i;
  for (i = 0; i < T->nc; i++) {
    TL_TRY_PES (tl_parse_declaration (T->c[i], 1));
  }
  return 1;
}

int tl_tree_lookup_value (struct tl_combinator_tree *L, void *var, struct tree_var_value **T) {
  if (!L) {
    return -1;
  }
  if (L->act == act_var && L->data == var) {
    return 0;
  }
  if (L->act == act_var) {
    struct tl_combinator_tree *E = tl_get_var_value (T, L->data);
    if (!E) { return -1;}
    else { return tl_tree_lookup_value (E, var, T); }
  }
  if (tl_tree_lookup_value (L->left, var, T) >= 0) { return 1; }
  if (tl_tree_lookup_value (L->right, var, T) >= 0) { return 1; }
  return -1;
}

int tl_tree_lookup_value_nat (struct tl_combinator_tree *L, void *var, long long x, struct tree_var_value **T) {
  assert (L);
  if (L->type == type_num_value) { return -1; }
  assert (L->type == type_num);
  assert (L->act == act_var);
  if (L->data == var) {
    return x == L->type_flags ? 0 : 1;
  } else {
    if (!tl_get_var_value (T, L->data)) {
      return -1;
    }
    return tl_tree_lookup_value_nat (tl_get_var_value (T, L->data), var, x + tl_get_var_value_num (T, L->data), T);
  }

}

int uniformize (struct tl_combinator_tree *L, struct tl_combinator_tree *R, struct tree_var_value **T) {
  if (!L || !R) {
    assert (!L && !R);
    return 1;
  }
  if (R->act == act_var) {
    struct tl_combinator_tree *_ = R; R = L; L = _;
  }
 
  if (L->type == type_type) {
    if (R->type != type_type || L->type_len != R->type_len || L->type_flags != R->type_flags) {
      return 0;
    }
    if (R->data == (void *)-1l || L->data == (void *)-1l) { return 1;}
    if (L->act == act_var) {
      int x = tl_tree_lookup_value (R, L->data, T);
      if (x > 0) {
//      if (tl_tree_lookup_value (R, L->data, T) > 0) {
        return 0;
      }
      if (x == 0) {
        return 1;
      }
      struct tl_combinator_tree *E = tl_get_var_value (T, L->data);
      if (!E) {
        tl_set_var_value (T, L->data, R);
        return 1;
      } else {
        return uniformize (E, R, T);
      }
    } else {
      if (L->act != R->act || L->data != R->data) {
        return 0;
      }
      return uniformize (L->left, R->left, T) && uniformize (L->right, R->right, T);
    }
  } else {
    assert (L->type == type_num || L->type == type_num_value);
    if (R->type != type_num && R->type != type_num_value) {
      return 0;
    }
    assert (R->type == type_num || R->type == type_num_value);
    if (R->data == (void *)-1l || L->data == (void *)-1l) { return 1;}
    long long x = 0;
    struct tl_combinator_tree *K = L;
    while (1) {
      x += K->type_flags;
      if (K->type == type_num_value) {
        break;
      }
      if (!tl_get_var_value (T, K->data)) {
        int s = tl_tree_lookup_value_nat (R, K->data, K->type_flags, T);
        if (s > 0) {
          return 0;
        }
        if (s == 0) {
          return 1;
        }
        /*tl_set_var_value_num (T, K->data, R, -x);
        return 1;*/
        break;
      }
      x += tl_get_var_value_num (T, K->data);
      K = tl_get_var_value (T, K->data);
    }
    long long y = 0;
    struct tl_combinator_tree *M = R;
    while (1) {
      y += M->type_flags;
      if (M->type == type_num_value) {
        break;
      }
      if (!tl_get_var_value (T, M->data)) {
        int s = tl_tree_lookup_value_nat (L, M->data, M->type_flags, T);
        if (s > 0) {
          return 0;
        }
        if (s == 0) {
          return 1;
        }
        /*tl_set_var_value_num (T, M->data, L, -y);
        return 1;*/
        break;
      }
      y += tl_get_var_value_num (T, M->data);
      M = tl_get_var_value (T, M->data);
    }
    if (K->type == type_num_value && M->type == type_num_value) {
      return x == y;     
    }
    if (M->type == type_num_value) {
      tl_set_var_value_num (T, K->data, M, -(x - y + M->type_flags));
      return 1;     
    } else if (K->type == type_num_value) {
      tl_set_var_value_num (T, M->data, K, -(y - x + K->type_flags));
      return 1;     
    } else {
      if (x >= y) {
        tl_set_var_value_num (T, K->data, M, -(x - y + M->type_flags));
      } else {
        tl_set_var_value_num (T, M->data, K, -(y - x + K->type_flags));
      }
      return 1;
    }
  }
  return 0;
}


void tl_type_check (struct tl_type *t) {
  if (!__ok) return;
  if (!strcmp (t->id, "#")) { t->name = 0x70659eff; return; }
  if (!strcmp (t->id, "Type")) { t->name = 0x2cecf817; return; }
  if (t->constructors_num <= 0 && !(t->flags & FLAG_EMPTY)) { 
    TL_ERROR ("Type %s has no constructors\n", t->id);
    __ok = 0;
    return;
  }
  int i, j;
  t->name = 0;
  for (i = 0; i < t->constructors_num; i++) {
    t->name ^= t->constructors[i]->name;
  }
  for (i = 0; i < t->constructors_num; i++) {
    for (j = i + 1; j < t->constructors_num; j++) {
      struct tree_var_value *v = 0;
      if (check_constructors_equal (t->constructors[i]->right, t->constructors[j]->right, &v)) {
        t->flags |= 16;
      }
    }
  }
  if ((t->flags & 24) == 24) {
    TL_WARNING ("Warning: Type %s has overlapping costructors, but it is used with `%%`\n", t->id);   
  }
  int z = 0;
  int sid = 0;
  for (i = 0; i < t->constructors_num; i++) if (*t->constructors[i]->id == '_') {
    z ++;
    sid = i;
  }
  if (z > 1) {
    TL_ERROR ("Type %s has %d default constructors\n", t->id, z);
    __ok = 0;
    return;
  }
  if (z == 1 && (t->flags & 8)) {
    TL_ERROR ("Type %s has default constructors and used bare\n", t->id);
    __ok = 0;
    return;
  }
  if (z) {
    struct tl_constructor *c;
    c = t->constructors[sid];
    t->constructors[sid] = t->constructors[t->constructors_num - 1];
    t->constructors[t->constructors_num - 1] = c;
  }
}

struct tl_program *tl_parse (struct tree *T) {
  assert (T);
  assert (T->type == type_tl_program);
  int i;
  tl_program_cur = talloc (sizeof (*tl_program_cur));
  tl_add_type ("#", 1, 0, 0);
  tl_add_type ("Type", 4, 0, 0);
  for (i = 0; i < T->nc; i++) {
    if (T->c[i]->type == type_constr_declarations) { TL_TRY_PES (tl_parse_constr_declarations (T->c[i])); }
    else { TL_TRY_PES (tl_parse_fun_declarations (T->c[i])) }
  }
  __ok = 1;
  tree_act_tl_type (tl_type_tree, tl_type_check);
  if (!__ok) {
    return 0;
  }
  return tl_program_cur;
}

FILE *__f;
int num = 0;

void wint (int a) {
//  printf ("%d ", a);
  a = htole32 (a);
  assert (fwrite (&a, 1, 4, __f) == 4);
}

void wdata (const void *x, int len) {
  assert (fwrite (x, 1, len, __f) == len);
}

void wstr (const char *s) {
  if (s) {
//    printf ("\"%s\" ", s);
    int x = strlen (s);
    if (x <= 254) {
      unsigned char x_c = (unsigned char)x;
      assert (fwrite (&x_c, 1, 1, __f) == 1);
    } else {
      fprintf (stderr, "String is too big...\n");
      assert (0);
    }
    wdata (s, x);
    x ++; // The header, containing the length, which is 1 byte
    int t = 0;
    if (x & 3) {
      // Let's hope it's truly zero on every platform
      wdata (&t, 4 - (x & 3));
    }
  } else {
//    printf ("<none> ");
    wint (0);
  }
}

void wll (long long a) {
//  printf ("%lld ", a);
  a = htole64 (a);
  assert (fwrite (&a, 1, 8, __f) == 8);
}

int count_list_size (struct tl_combinator_tree *T) {
  assert (T->type == type_list || T->type == type_list_item);
  if (T->type == type_list_item) {
    return 1;
  } else {
    return count_list_size (T->left) + count_list_size (T->right);
  }
}

void write_type_flags (long long flags) {
  int new_flags = 0;
  if (flags & 1) {
    new_flags |= FLAG_BARE;
  }
  if (flags & FLAG_DEFAULT_CONSTRUCTOR) {
    new_flags |= FLAG_DEFAULT_CONSTRUCTOR;
  }
  wint (new_flags);
}

void write_field_flags (long long flags) {
  int new_flags = 0;
  //fprintf (stderr, "%lld\n", flags);
  if (flags & 1) {
    new_flags |= FLAG_BARE;
  }
  if (flags & 32) {
    new_flags |= FLAG_OPT_VAR;
  }
  if (flags & FLAG_EXCL) {
    new_flags |= FLAG_EXCL;
  }
  if (flags & FLAG_OPT_FIELD) {
   // new_flags |= FLAG_OPT_FIELD;
    new_flags |= 2;
  }
  if (flags & (1 << 21)) {
    new_flags |= 4;
  }
  wint (new_flags);
}

void write_var_type_flags (long long flags) {
  int new_flags = 0;
  if (flags & 1) {
    new_flags |= FLAG_BARE;
  }
  if (new_flags & FLAG_BARE) {
    TL_ERROR ("Sorry, bare vars are not (yet ?) supported.\n");
    assert (!(new_flags & FLAG_BARE));
  }
  wint (new_flags);
}

void write_tree (struct tl_combinator_tree *T, int extra, struct tree_var_value **v, int *last_var);
void write_args (struct tl_combinator_tree *T, struct tree_var_value **v, int *last_var) {
  assert (T->type == type_list || T->type == type_list_item);
  if (T->type == type_list) {
    assert (T->act == act_union);
    assert (T->left);
    assert (T->right);
    write_args (T->left, v, last_var);
    write_args (T->right, v, last_var);
    return;
  }
  wint (TLS_ARG_V2);
  assert (T->act == act_field);
  assert (T->left);
  wstr (T->data && strcmp (T->data, "_") ? T->data : 0);
  long long f = T->flags;
  if (T->left->act == act_opt_field) {
    f |= (1 << 20);
  }
  if (T->left->act == act_type && T->left->data && (!strcmp (((struct tl_type *)T->left->data)->id, "#") || !strcmp (((struct tl_type *)T->left->data)->id, "Type"))) {
    write_field_flags (f | (1 << 21));
    wint (*last_var);
    *last_var = (*last_var) + 1;
    tl_set_var_value_num (v, T, 0, (*last_var) - 1);
  } else {
    write_field_flags (f);
  } 
  write_tree (T->left, 0, v, last_var);
}

void write_array (struct tl_combinator_tree *T, struct tree_var_value **v, int *last_var) {
  wint (TLS_ARRAY);
  write_tree (T->left, 0, v, last_var);
  write_tree (T->right, 0, v, last_var);
}

void write_type_rec (struct tl_combinator_tree *T, int cc, struct tree_var_value **v, int *last_var) {
  if (T->act == act_arg) {
    write_type_rec (T->left, cc + 1, v, last_var);
    if (T->right->type == type_num_value || T->right->type == type_num) {
      wint (TLS_EXPR_NAT);
    } else {
      wint (TLS_EXPR_TYPE);
    }
    write_tree (T->right, 0, v, last_var);
  } else {
    assert (T->act == act_var || T->act == act_type);
    if (T->act == act_var) {
      assert (!cc);
      wint (TLS_TYPE_VAR);
      wint (tl_get_var_value_num (v, T->data));
      write_var_type_flags (T->flags);
      //wint (T->flags);
    } else {
      wint (TLS_TYPE_EXPR);
      struct tl_type *t = T->data;
      wint (t->name);
      write_type_flags (T->flags);
//      wint (T->flags);
      wint (cc);
//      fprintf (stderr, "cc = %d\n", cc);
    }
  }
}

void write_opt_type (struct tl_combinator_tree *T, struct tree_var_value **v, int *last_var) {
  wint (tl_get_var_value_num (v, T->left->data));
  wint (T->left->type_flags);
//  write_tree (T->right, 0, v, last_var);
  assert (T);
  T = T->right;
  switch (T->type) {
  case type_type:
    if (T->act == act_array) {
      write_array (T, v, last_var);
    } else if (T->act == act_type || T->act == act_var || T->act == act_arg) {
      write_type_rec (T, 0, v, last_var);
    } else {
      assert (0);
    }
    break;
  default:
    assert (0);
  }
}

void write_tree (struct tl_combinator_tree *T, int extra, struct tree_var_value **v, int *last_var) {
  assert (T);
  switch (T->type) {
  case type_list_item:
  case type_list:
    if (extra) {
      wint (TLS_COMBINATOR_RIGHT_V2);
    }
    wint (count_list_size (T));
    write_args (T, v, last_var);
    break;
  case type_num_value:
    wint ((int)TLS_NAT_CONST);
    wint (T->type_flags);
    break;
  case type_num:
    wint ((int)TLS_NAT_VAR);
    wint (T->type_flags);
    wint (tl_get_var_value_num (v, T->data));
    break;
  case type_type:
    if (T->act == act_array) {
      write_array (T, v, last_var);
    } else if (T->act == act_type || T->act == act_var || T->act == act_arg) {
      write_type_rec (T, 0, v, last_var);
    } else {
      assert (T->act == act_opt_field);
      write_opt_type (T, v, last_var);
    }
    break;
  default:
    assert (0);
  }
}

void write_type (struct tl_type *t) {
  wint (TLS_TYPE);
  wint (t->name);
  wstr (t->id);
  wint (t->constructors_num);
  wint (t->flags);
  wint (t->params_num);
  wll (t->params_types);
}

int is_builtin_type (const char *id) {
  return !strcmp (id, "int") || !strcmp (id, "long") || !strcmp (id, "double") || !strcmp (id, "string")
    || !strcmp(id, "object") || !strcmp(id, "function");
}

void write_combinator (struct tl_constructor *c) {
  wint (c->name);
  wstr (c->id);
  wint (c->type ? c->type->name : 0);
  struct tree_var_value *T = 0;
  int x = 0;
  assert (c->right);
  if (c->left) {
    if (is_builtin_type (c->id)) {
      wint (TLS_COMBINATOR_LEFT_BUILTIN);
    } else {
      wint (TLS_COMBINATOR_LEFT);
      // FIXME: What is that?
//      wint (count_list_size (c->left));
      write_tree (c->left, 0, &T, &x);
    }
  } else {
    wint (TLS_COMBINATOR_LEFT);
    wint (0);
  }
  wint (TLS_COMBINATOR_RIGHT_V2);
  write_tree (c->right, 1, &T, &x);
}

void write_constructor (struct tl_constructor *c) {
  wint (TLS_COMBINATOR);
  write_combinator (c);
}

void write_function (struct tl_constructor *c) {
  wint (TLS_COMBINATOR);
  write_combinator (c);
}

void write_type_constructors (struct tl_type *t) {
  int i;
  for (i = 0; i < t->constructors_num; i++) {
    write_constructor (t->constructors[i]);
  }
}

void write_types (FILE *f) {
  __f = f;
  wint (TLS_SCHEMA_V2);
  wint (0);
#ifdef TL_PARSER_NEED_TIME
  wint (time (0));
#else
  /* Make the tlo reproducible by default. Rationale: https://wiki.debian.org/ReproducibleBuilds/Howto#Introduction */
  wint (0);
#endif
  num = 0;
  wint (total_types_num);
  tree_act_tl_type (tl_type_tree, write_type);
  wint (total_constructors_num);
  tree_act_tl_type (tl_type_tree, write_type_constructors);
  wint (total_functions_num);
  tree_act_tl_constructor (tl_function_tree, write_function);
}
