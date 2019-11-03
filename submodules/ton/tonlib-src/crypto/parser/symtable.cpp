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
#include "symtable.h"
#include <sstream>
#include <cassert>

namespace sym {

/*
 *
 *   SYMBOL VALUES (DECLARED)
 *
 */

int scope_level;

SymTable<100003> symbols;

SymDef* sym_def[symbols.hprime];
SymDef* global_sym_def[symbols.hprime];
std::vector<std::pair<int, SymDef>> symbol_stack;
std::vector<src::SrcLocation> scope_opened_at;

std::string Symbol::unknown_symbol_name(sym_idx_t i) {
  if (!i) {
    return "_";
  } else {
    std::ostringstream os;
    os << "SYM#" << i;
    return os.str();
  }
}

sym_idx_t SymTableBase::gen_lookup(std::string str, int mode, sym_idx_t idx) {
  unsigned long long h1 = 1, h2 = 1;
  for (char c : str) {
    h1 = ((h1 * 239) + (unsigned char)(c)) % p;
    h2 = ((h2 * 17) + (unsigned char)(c)) % (p - 1);
  }
  ++h2;
  ++h1;
  while (true) {
    if (sym_table[h1]) {
      if (sym_table[h1]->str == str) {
        return (mode & 2) ? not_found : sym_idx_t(h1);
      }
      h1 += h2;
      if (h1 > p) {
        h1 -= p;
      }
    } else {
      if (!(mode & 1)) {
        return not_found;
      }
      if (def_sym >= ((long long)p * 3) / 4) {
        throw SymTableOverflow{def_sym};
      }
      sym_table[h1] = std::make_unique<Symbol>(str, idx <= 0 ? sym_idx_t(h1) : -idx);
      ++def_sym;
      return sym_idx_t(h1);
    }
  }
}

SymTableBase& SymTableBase::add_keyword(std::string str, sym_idx_t idx) {
  if (idx <= 0) {
    idx = ++def_kw;
  }
  sym_idx_t res = gen_lookup(str, -1, idx);
  if (!res) {
    throw SymTableKwRedef{str};
  }
  if (idx < max_kw_idx) {
    keywords[idx] = res;
  }
  return *this;
}

void open_scope(src::Lexer& lex) {
  ++scope_level;
  scope_opened_at.push_back(lex.cur().loc);
}

void close_scope(src::Lexer& lex) {
  if (!scope_level) {
    throw src::Fatal{"cannot close the outer scope"};
  }
  while (!symbol_stack.empty() && symbol_stack.back().first == scope_level) {
    SymDef old_def = symbol_stack.back().second;
    auto idx = old_def.sym_idx;
    symbol_stack.pop_back();
    SymDef* cur_def = sym_def[idx];
    assert(cur_def);
    assert(cur_def->level == scope_level && cur_def->sym_idx == idx);
    //std::cerr << "restoring local symbol `" << old_def.name << "` of level " << scope_level << " to its previous level " << old_def.level << std::endl;
    if (cur_def->value) {
      //std::cerr << "deleting value of symbol " << old_def.name << ":" << old_def.level << " at " << (const void*) it->second.value << std::endl;
      delete cur_def->value;
    }
    if (!old_def.level && !old_def.value) {
      delete cur_def;  // ??? keep the definition always?
      sym_def[idx] = nullptr;
    } else {
      cur_def->value = std::move(old_def.value);
      cur_def->level = old_def.level;
    }
    old_def.value = nullptr;
  }
  --scope_level;
  scope_opened_at.pop_back();
}

SymDef* lookup_symbol(sym_idx_t idx, int flags) {
  if (!idx) {
    return nullptr;
  }
  if ((flags & 1) && sym_def[idx]) {
    return sym_def[idx];
  }
  if ((flags & 2) && global_sym_def[idx]) {
    return global_sym_def[idx];
  }
  return nullptr;
}

SymDef* lookup_symbol(std::string name, int flags) {
  return lookup_symbol(symbols.lookup(name), flags);
}

SymDef* define_global_symbol(sym_idx_t name_idx, bool force_new, const src::SrcLocation& loc) {
  if (!name_idx) {
    return nullptr;
  }
  auto found = global_sym_def[name_idx];
  if (found) {
    return force_new && found->value ? nullptr : found;
  }
  return global_sym_def[name_idx] = new SymDef(0, name_idx, loc);
}

SymDef* define_symbol(sym_idx_t name_idx, bool force_new, const src::SrcLocation& loc) {
  if (!name_idx) {
    return nullptr;
  }
  if (!scope_level) {
    return define_global_symbol(name_idx, force_new, loc);
  }
  auto found = sym_def[name_idx];
  if (found) {
    if (found->level < scope_level) {
      symbol_stack.push_back(std::make_pair(scope_level, *found));
      found->level = scope_level;
    } else if (found->value && force_new) {
      return nullptr;
    }
    found->value = 0;
    found->loc = loc;
    return found;
  }
  found = sym_def[name_idx] = new SymDef(scope_level, name_idx, loc);
  symbol_stack.push_back(std::make_pair(scope_level, SymDef{0, name_idx}));
  return found;
}

}  // namespace sym
