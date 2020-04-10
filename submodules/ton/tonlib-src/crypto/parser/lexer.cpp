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
#include "lexer.h"
#include "symtable.h"
#include <sstream>
#include <cassert>

namespace src {

/*
 *
 *   LEXER
 *
 */

std::string Lexem::lexem_name_str(int idx) {
  if (idx == Eof) {
    return "end of file";
  } else if (idx == Ident) {
    return "identifier";
  } else if (idx == Number) {
    return "number";
  } else if (idx == String) {
    return "string";
  } else if (idx == Special) {
    return "special";
  } else if (sym::symbols.get_keyword(idx)) {
    return "`" + sym::symbols.get_keyword(idx)->str + "`";
  } else {
    std::ostringstream os{"<unknown lexem of type "};
    os << idx << ">";
    return os.str();
  }
}

std::string Lexem::name_str() const {
  if (tp == Ident) {
    return std::string{"identifier `"} + sym::symbols.get_name(val) + "`";
  } else if (tp == String) {
    return std::string{"string \""} + str + '"';
  } else {
    return lexem_name_str(tp);
  }
}

bool is_number(std::string str) {
  auto st = str.begin(), en = str.end();
  if (st == en) {
    return false;
  }
  if (*st == '-') {
    st++;
  }
  bool hex = false;
  if (st + 1 < en && *st == '0' && st[1] == 'x') {
    st += 2;
    hex = true;
  }
  if (st == en) {
    return false;
  }
  while (st < en) {
    int c = *st;
    if (c >= '0' && c <= '9') {
      ++st;
      continue;
    }
    if (!hex) {
      return false;
    }
    c |= 0x20;
    if (c < 'a' || c > 'f') {
      return false;
    }
    ++st;
  }
  return true;
}

int Lexem::classify() {
  if (tp != Unknown) {
    return tp;
  }
  sym::sym_idx_t i = sym::symbols.lookup(str);
  if (i) {
    assert(str == sym::symbols[i]->str);
    str = sym::symbols[i]->str;
    sym::sym_idx_t idx = sym::symbols[i]->idx;
    tp = (idx < 0 ? -idx : Ident);
    val = i;
  } else if (is_number(str)) {
    tp = Number;
  } else {
    tp = lexem_is_special(str);
  }
  if (tp == Unknown) {
    tp = Ident;
    val = sym::symbols.lookup(str, 1);
  }
  return tp;
}

int Lexem::set(std::string _str, const SrcLocation& _loc, int _tp, int _val) {
  str = _str;
  loc = _loc;
  tp = _tp;
  val = _val;
  return classify();
}

Lexer::Lexer(SourceReader& _src, bool init, std::string active_chars, std::string eol_cmts, std::string open_cmts,
             std::string close_cmts, std::string quote_chars)
    : src(_src), eof(false), lexem("", src.here(), Lexem::Undefined), peek_lexem("", {}, Lexem::Undefined) {
  std::memset(char_class, 0, sizeof(char_class));
  unsigned char activity = cc::active;
  for (char c : active_chars) {
    if (c == ' ') {
      if (!--activity) {
        activity = cc::allow_repeat;
      }
    } else if ((unsigned)c < 0x80) {
      char_class[(unsigned)c] |= activity;
    }
  }
  set_spec(eol_cmt, eol_cmts);
  set_spec(cmt_op, open_cmts);
  set_spec(cmt_cl, close_cmts);
  for (int c : quote_chars) {
    if (c > ' ' && c <= 0x7f) {
      char_class[(unsigned)c] |= cc::quote_char;
    }
  }
  if (init) {
    next();
  }
}

void Lexer::set_spec(std::array<int, 3>& arr, std::string setup) {
  arr[0] = arr[1] = arr[2] = -0x100;
  std::size_t n = setup.size(), i;
  for (i = 0; i < n; i++) {
    if (setup[i] == ' ') {
      continue;
    }
    if (i == n - 1 || setup[i + 1] == ' ') {
      arr[0] = setup[i];
    } else if (i == n - 2 || (i < n - 2 && setup[i + 2] == ' ')) {
      arr[1] = setup[i];
      arr[2] = setup[++i];
    } else {
      while (i < n && setup[i] != ' ') {
        i++;
      }
    }
  }
}

void Lexer::expect(int exp_tp, const char* msg) {
  if (tp() != exp_tp) {
    throw ParseError{lexem.loc, (msg ? std::string{msg} : Lexem::lexem_name_str(exp_tp)) + " expected instead of " +
                                    cur().name_str()};
  }
  next();
}

const Lexem& Lexer::next() {
  if (peek_lexem.valid()) {
    lexem = std::move(peek_lexem);
    peek_lexem.clear({}, Lexem::Undefined);
    eof = (lexem.tp == Lexem::Eof);
    return lexem;
  }
  if (eof) {
    return lexem.clear(src.here(), Lexem::Eof);
  }
  long long comm = 1;
  while (!src.seek_eof()) {
    int cc = src.cur_char(), nc = src.next_char();
    if (cc == eol_cmt[0] || (cc == eol_cmt[1] && nc == eol_cmt[2])) {
      src.load_line();
    } else if (cc == cmt_op[1] && nc == cmt_op[2]) {
      src.advance(2);
      comm = comm * 2 + 1;
    } else if (cc == cmt_op[0]) {
      src.advance(1);
      comm *= 2;
    } else if (comm == 1) {
      break;
    } else if (cc == cmt_cl[1] && nc == cmt_cl[2]) {
      if (!(comm & 1)) {
        src.error(std::string{"a `"} + (char)cmt_op[0] + "` comment closed by `" + (char)cmt_cl[1] + (char)cmt_cl[2] +
                  "`");
      }
      comm >>= 1;
      src.advance(2);
    } else if (cc == cmt_cl[0]) {
      if (!(comm & 1)) {
        src.error(std::string{"a `"} + (char)cmt_op[1] + (char)cmt_op[2] + "` comment closed by `" + (char)cmt_cl[0] +
                  "`");
      }
      comm >>= 1;
      src.advance(1);
    } else {
      src.advance(1);
    }
    if (comm < 0) {
      src.error("too many nested comments");
    }
  }
  if (src.seek_eof()) {
    eof = true;
    if (comm > 1) {
      if (comm & 1) {
        src.error(std::string{"`"} + (char)cmt_op[1] + (char)cmt_op[2] + "` comment extends past end of file");
      } else {
        src.error(std::string{"`"} + (char)cmt_op[0] + "` comment extends past end of file");
      }
    }
    return lexem.clear(src.here(), Lexem::Eof);
  }
  int c = src.cur_char();
  const char* end = src.get_ptr();
  if (is_quote_char(c) || c == '`') {
    int qc = c;
    ++end;
    while (end < src.get_end_ptr() && *end != qc) {
      ++end;
    }
    if (*end != qc) {
      src.error(qc == '`' ? "a `back-quoted` token extends past end of line" : "string extends past end of line");
    }
    lexem.set(std::string{src.get_ptr() + 1, end}, src.here(), qc == '`' ? Lexem::Unknown : Lexem::String);
    src.set_ptr(end + 1);
    // std::cerr << lexem.name_str() << ' ' << lexem.str << std::endl;
    return lexem;
  }
  int len = 0, pc = -0x100;
  while (end < src.get_end_ptr()) {
    c = *end;
    bool repeated = (c == pc && is_repeatable(c));
    if (c == ' ' || c == 9 || (len && is_left_active(c) && !repeated)) {
      break;
    }
    ++len;
    ++end;
    if (is_right_active(c) && !repeated) {
      break;
    }
    pc = c;
  }
  lexem.set(std::string{src.get_ptr(), end}, src.here());
  src.set_ptr(end);
  // std::cerr << lexem.name_str() << ' ' << lexem.str << std::endl;
  return lexem;
}

const Lexem& Lexer::peek() {
  if (peek_lexem.valid()) {
    return peek_lexem;
  }
  if (eof) {
    return lexem.clear(src.here(), Lexem::Eof);
  }
  Lexem keep = std::move(lexem);
  next();
  peek_lexem = std::move(lexem);
  lexem = std::move(keep);
  eof = false;
  return peek_lexem;
}

}  // namespace src
