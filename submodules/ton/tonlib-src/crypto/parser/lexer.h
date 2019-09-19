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
#include <array>
#include <memory>
#include <cstring>

namespace src {

/*
 *
 *   LEXER
 *
 */

int lexem_is_special(std::string str);  // return 0 if no special lexems are needed

struct Lexem {
  enum { Undefined = -2, Eof = -1, Unknown = 0, Ident = 0, Number = 1, Special = 2, String = 3 };
  int tp;
  int val;
  std::string str;
  SrcLocation loc;
  int classify();
  Lexem(std::string _str = "", const SrcLocation& _loc = {}, int _tp = Unknown, int _val = 0)
      : tp(_tp), val(_val), str(_str), loc(_loc) {
    classify();
  }
  int set(std::string _str = "", const SrcLocation& _loc = {}, int _tp = Unknown, int _val = 0);
  Lexem& clear(const SrcLocation& _loc = {}, int _tp = Unknown, int _val = 0) {
    tp = _tp;
    val = _val;
    loc = _loc;
    str = "";
    return *this;
  }
  bool valid() const {
    return tp != Undefined;
  }
  std::string name_str() const;
  void error(std::string _str) const {
    throw ParseError{loc, _str};
  }
  void error_at(std::string str1, std::string str2) const {
    error(str1 + str + str2);
  }

  static std::string lexem_name_str(int idx);
};

class Lexer {
  SourceReader& src;
  bool eof;
  Lexem lexem, peek_lexem;
  unsigned char char_class[128];
  std::array<int, 3> eol_cmt, cmt_op, cmt_cl;
  enum cc { left_active = 2, right_active = 1, active = 3, allow_repeat = 4, quote_char = 8 };

 public:
  bool eof_found() const {
    return eof;
  }
  Lexer(SourceReader& _src, bool init = false, std::string active_chars = ";,() ~.", std::string eol_cmts = ";;",
        std::string open_cmts = "{-", std::string close_cmts = "-}", std::string quote_chars = "\"");
  const Lexem& next();
  const Lexem& cur() const {
    return lexem;
  }
  const Lexem& peek();
  int tp() const {
    return lexem.tp;
  }
  void expect(int exp_tp, const char* msg = 0);
  int classify_char(unsigned c) const {
    return c < 0x80 ? char_class[c] : 0;
  }
  bool is_active(int c) const {
    return (classify_char(c) & cc::active) == cc::active;
  }
  bool is_left_active(int c) const {
    return (classify_char(c) & cc::left_active);
  }
  bool is_right_active(int c) const {
    return (classify_char(c) & cc::right_active);
  }
  bool is_repeatable(int c) const {
    return (classify_char(c) & cc::allow_repeat);
  }
  bool is_quote_char(int c) const {
    return (classify_char(c) & cc::quote_char);
  }

 private:
  void set_spec(std::array<int, 3>& arr, std::string setup);
};

}  // namespace src
