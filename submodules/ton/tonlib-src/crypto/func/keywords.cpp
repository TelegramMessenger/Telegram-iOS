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
#include "func.h"

namespace src {

int lexem_is_special(std::string str) {
  return 0;  // no special lexems
}

}  // namespace src

namespace funC {

/*
 * 
 *   KEYWORD DEFINITION
 * 
 */

void define_keywords() {
  sym::symbols.add_kw_char('+')
      .add_kw_char('-')
      .add_kw_char('*')
      .add_kw_char('/')
      .add_kw_char('%')
      .add_kw_char('?')
      .add_kw_char(':')
      .add_kw_char(',')
      .add_kw_char(';')
      .add_kw_char('(')
      .add_kw_char(')')
      .add_kw_char('{')
      .add_kw_char('}')
      .add_kw_char('=')
      .add_kw_char('_')
      .add_kw_char('<')
      .add_kw_char('>')
      .add_kw_char('&')
      .add_kw_char('|')
      .add_kw_char('^')
      .add_kw_char('~');

  using Kw = funC::Keyword;
  sym::symbols.add_keyword("==", Kw::_Eq)
      .add_keyword("!=", Kw::_Neq)
      .add_keyword("<=", Kw::_Leq)
      .add_keyword(">=", Kw::_Geq)
      .add_keyword("<=>", Kw::_Spaceship)
      .add_keyword("<<", Kw::_Lshift)
      .add_keyword(">>", Kw::_Rshift)
      .add_keyword("~>>", Kw::_RshiftR)
      .add_keyword("^>>", Kw::_RshiftC)
      .add_keyword("~/", Kw::_DivR)
      .add_keyword("^/", Kw::_DivC)
      .add_keyword("~%", Kw::_ModR)
      .add_keyword("^%", Kw::_ModC)
      .add_keyword("/%", Kw::_DivMod)
      .add_keyword("+=", Kw::_PlusLet)
      .add_keyword("-=", Kw::_MinusLet)
      .add_keyword("*=", Kw::_TimesLet)
      .add_keyword("/=", Kw::_DivLet)
      .add_keyword("~/=", Kw::_DivRLet)
      .add_keyword("^/=", Kw::_DivCLet)
      .add_keyword("%=", Kw::_ModLet)
      .add_keyword("~%=", Kw::_ModRLet)
      .add_keyword("^%=", Kw::_ModCLet)
      .add_keyword("<<=", Kw::_LshiftLet)
      .add_keyword(">>=", Kw::_RshiftLet)
      .add_keyword("~>>=", Kw::_RshiftRLet)
      .add_keyword("^>>=", Kw::_RshiftCLet)
      .add_keyword("&=", Kw::_AndLet)
      .add_keyword("|=", Kw::_OrLet)
      .add_keyword("^=", Kw::_XorLet);

  sym::symbols.add_keyword("return", Kw::_Return)
      .add_keyword("var", Kw::_Var)
      .add_keyword("repeat", Kw::_Repeat)
      .add_keyword("do", Kw::_Do)
      .add_keyword("while", Kw::_While)
      .add_keyword("until", Kw::_Until)
      .add_keyword("if", Kw::_If)
      .add_keyword("ifnot", Kw::_Ifnot)
      .add_keyword("then", Kw::_Then)
      .add_keyword("else", Kw::_Else)
      .add_keyword("elseif", Kw::_Elseif)
      .add_keyword("elseifnot", Kw::_Elseifnot);

  sym::symbols.add_keyword("int", Kw::_Int)
      .add_keyword("cell", Kw::_Cell)
      .add_keyword("slice", Kw::_Slice)
      .add_keyword("builder", Kw::_Builder)
      .add_keyword("cont", Kw::_Cont)
      .add_keyword("tuple", Kw::_Tuple)
      .add_keyword("type", Kw::_Type)
      .add_keyword("->", Kw::_Mapsto)
      .add_keyword("forall", Kw::_Forall);

  sym::symbols.add_keyword("extern", Kw::_Extern)
      .add_keyword("asm", Kw::_Asm)
      .add_keyword("impure", Kw::_Impure)
      .add_keyword("inline", Kw::_Inline)
      .add_keyword("inline_ref", Kw::_InlineRef)
      .add_keyword("method_id", Kw::_MethodId)
      .add_keyword("operator", Kw::_Operator)
      .add_keyword("infix", Kw::_Infix)
      .add_keyword("infixl", Kw::_Infixl)
      .add_keyword("infixr", Kw::_Infixr);
}

}  // namespace funC
