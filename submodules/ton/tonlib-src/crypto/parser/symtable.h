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
#pragma once
#include "srcread.h"
#include "lexer.h"
#include <vector>

namespace sym {

/*
 *
 *   SYMBOL VALUES (DECLARED)
 *
 */

typedef int var_idx_t;

struct SymValBase {
  enum { _Param, _Var, _Func, _Typename, _GlobVar };
  int type;
  int idx;
  SymValBase(int _type, int _idx) : type(_type), idx(_idx) {
  }
  virtual ~SymValBase() = default;
};

/*
 *
 *   SYMBOL TABLE
 *
 */

// defined outside this module (by the end user)
int compute_symbol_subclass(std::string str);  // return 0 if unneeded

typedef int sym_idx_t;

struct Symbol {
  std::string str;
  sym_idx_t idx;
  int subclass;
  Symbol(std::string _str, sym_idx_t _idx, int _sc) : str(_str), idx(_idx), subclass(_sc) {
  }
  Symbol(std::string _str, sym_idx_t _idx) : str(_str), idx(_idx) {
    subclass = compute_symbol_subclass(std::move(_str));
  }
  static std::string unknown_symbol_name(sym_idx_t i);
};

class SymTableBase {
  unsigned p;
  std::unique_ptr<Symbol>* sym_table;
  sym_idx_t def_kw, def_sym;
  static constexpr int max_kw_idx = 10000;
  sym_idx_t keywords[max_kw_idx];

 public:
  SymTableBase(unsigned p_, std::unique_ptr<Symbol>* sym_table_)
      : p(p_), sym_table(sym_table_), def_kw(0x100), def_sym(0) {
    std::memset(keywords, 0, sizeof(keywords));
  }
  static constexpr sym_idx_t not_found = 0;
  SymTableBase& add_keyword(std::string str, sym_idx_t idx = 0);
  SymTableBase& add_kw_char(char c) {
    return add_keyword(std::string{c}, c);
  }
  sym_idx_t lookup(std::string str, int mode = 0) {
    return gen_lookup(str, mode);
  }
  sym_idx_t lookup_add(std::string str) {
    return gen_lookup(str, 1);
  }
  Symbol* operator[](sym_idx_t i) const {
    return sym_table[i].get();
  }
  bool is_keyword(sym_idx_t i) const {
    return sym_table[i] && sym_table[i]->idx < 0;
  }
  std::string get_name(sym_idx_t i) const {
    return sym_table[i] ? sym_table[i]->str : Symbol::unknown_symbol_name(i);
  }
  int get_subclass(sym_idx_t i) const {
    return sym_table[i] ? sym_table[i]->subclass : 0;
  }
  Symbol* get_keyword(int i) const {
    return ((unsigned)i < (unsigned)max_kw_idx) ? sym_table[keywords[i]].get() : nullptr;
  }

 protected:
  sym_idx_t gen_lookup(std::string str, int mode = 0, sym_idx_t idx = 0);
};

template <unsigned pp>
class SymTable : public SymTableBase {
 public:
  static constexpr int hprime = pp;
  static int size() {
    return pp + 1;
  }

 private:
  std::unique_ptr<Symbol> sym[pp + 1];

 public:
  SymTable() : SymTableBase(pp, sym) {
  }
  SymTable& add_keyword(std::string str, sym_idx_t idx = 0) {
    SymTableBase::add_keyword(str, idx);
    return *this;
  }
  SymTable& add_kw_char(char c) {
    return add_keyword(std::string{c}, c);
  }
};

struct SymTableOverflow {
  int sym_def;
  SymTableOverflow(int x) : sym_def(x) {
  }
};

struct SymTableKwRedef {
  std::string kw;
  SymTableKwRedef(std::string _kw) : kw(_kw) {
  }
};

extern SymTable<100003> symbols;

extern int scope_level;

struct SymDef {
  int level;
  sym_idx_t sym_idx;
  SymValBase* value;
  src::SrcLocation loc;
  SymDef(int lvl, sym_idx_t idx, const src::SrcLocation& _loc = {}, SymValBase* val = 0)
      : level(lvl), sym_idx(idx), value(val), loc(_loc) {
  }
  bool has_name() const {
    return sym_idx;
  }
  std::string name() const {
    return symbols.get_name(sym_idx);
  }
};

extern SymDef* sym_def[symbols.hprime];
extern SymDef* global_sym_def[symbols.hprime];
extern std::vector<std::pair<int, SymDef>> symbol_stack;
extern std::vector<src::SrcLocation> scope_opened_at;

void open_scope(src::Lexer& lex);
void close_scope(src::Lexer& lex);
SymDef* lookup_symbol(sym_idx_t idx, int flags = 3);
SymDef* lookup_symbol(std::string name, int flags = 3);

SymDef* define_global_symbol(sym_idx_t name_idx, bool force_new = false, const src::SrcLocation& loc = {});
SymDef* define_symbol(sym_idx_t name_idx, bool force_new = false, const src::SrcLocation& loc = {});

}  // namespace sym
