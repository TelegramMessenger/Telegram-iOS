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
#include "IntCtx.h"

namespace fift {

td::StringBuilder& operator<<(td::StringBuilder& os, const IntCtx& ctx) {
  if (ctx.include_depth) {
    return os << ctx.filename << ":" << ctx.line_no << ": ";
  } else {
    return os;
  }
}

std::ostream& operator<<(std::ostream& os, const IntCtx& ctx) {
  return os << (PSLICE() << ctx).c_str();
}

void CharClassifier::import_from_string(td::Slice str, int space_cls) {
  set_char_class(' ', space_cls);
  set_char_class('\t', space_cls);
  int cls = 3;
  for (char c : str) {
    if (c == ' ') {
      cls--;
    } else {
      set_char_class(c, cls);
    }
  }
}

void CharClassifier::import_from_string(std::string str, int space_cls) {
  import_from_string(td::Slice{str}, space_cls);
}

void CharClassifier::import_from_string(const char* str, int space_cls) {
  import_from_string(td::Slice{str}, space_cls);
}

CharClassifier CharClassifier::from_string(td::Slice str, int space_cls) {
  return CharClassifier{str, space_cls};
}

void CharClassifier::set_char_class(int c, int cl) {
  c &= 0xff;
  cl &= 3;
  int offs = (c & 3) * 2;
  int mask = (3 << offs);
  cl <<= offs;
  unsigned char* p = data_ + (c >> 2);
  *p = static_cast<unsigned char>((*p & ~mask) | cl);
}

IntCtx::Savepoint::Savepoint(IntCtx& _ctx, std::string new_filename, std::string new_current_dir,
                             std::istream* new_input_stream)
    : ctx(_ctx)
    , old_line_no(_ctx.line_no)
    , old_need_line(_ctx.need_line)
    , old_filename(_ctx.filename)
    , old_current_dir(_ctx.currentd_dir)
    , old_input_stream(_ctx.input_stream)
    , old_curline(_ctx.str)
    , old_curpos(_ctx.input_ptr - _ctx.str.c_str()) {
  ctx.line_no = 0;
  ctx.filename = new_filename;
  ctx.currentd_dir = new_current_dir;
  ctx.input_stream = new_input_stream;
  ctx.str = "";
  ctx.input_ptr = 0;
  ++(ctx.include_depth);
}

IntCtx::Savepoint::~Savepoint() {
  ctx.line_no = old_line_no;
  ctx.need_line = old_need_line;
  ctx.filename = old_filename;
  ctx.currentd_dir = old_current_dir;
  ctx.input_stream = old_input_stream;
  ctx.str = old_curline;
  ctx.input_ptr = ctx.str.c_str() + old_curpos;
  --(ctx.include_depth);
}

bool IntCtx::load_next_line() {
  if (!std::getline(*input_stream, str)) {
    return false;
  }
  need_line = false;
  if (!str.empty() && str.back() == '\r') {
    str.pop_back();
  }
  set_input(str);
  return true;
}

bool IntCtx::is_sb() const {
  return !eof() && line_no == 1 && *input_ptr == '#' && input_ptr[1] == '!';
}

td::Slice IntCtx::scan_word_to(char delim, bool err_endl) {
  load_next_line_ifreq();
  auto ptr = input_ptr;
  while (*ptr && *ptr != delim) {
    ptr++;
  }
  if (*ptr) {
    std::swap(ptr, input_ptr);
    return td::Slice{ptr, input_ptr++};
  } else if (err_endl && delim) {
    throw IntError{std::string{"end delimiter `"} + delim + "` not found"};
  } else {
    need_line = true;
    std::swap(ptr, input_ptr);
    return td::Slice{ptr, input_ptr};
  }
}

td::Slice IntCtx::scan_word() {
  skipspc(true);
  auto ptr = input_ptr;
  while (*ptr && *ptr != ' ' && *ptr != '\t' && *ptr != '\r') {
    ptr++;
  }
  auto ptr2 = ptr;
  std::swap(ptr, input_ptr);
  skipspc();
  return td::Slice{ptr, ptr2};
}

td::Slice IntCtx::scan_word_ext(const CharClassifier& classifier) {
  skipspc(true);
  auto ptr = input_ptr;
  while (*ptr && *ptr != '\r' && *ptr != '\n') {
    int c = classifier.classify(*ptr);
    if ((c & 1) && ptr != input_ptr) {
      break;
    }
    ptr++;
    if (c & 2) {
      break;
    }
  }
  std::swap(ptr, input_ptr);
  return td::Slice{ptr, input_ptr};
}

void IntCtx::skipspc(bool skip_eol) {
  do {
    while (*input_ptr == ' ' || *input_ptr == '\t' || *input_ptr == '\r') {
      ++input_ptr;
    }
    if (!skip_eol || *input_ptr) {
      break;
    }
  } while (load_next_line());
}

void check_compile(const IntCtx& ctx) {
  if (ctx.state <= 0) {
    throw IntError{"compilation mode only"};
  }
}

void check_execute(const IntCtx& ctx) {
  if (ctx.state != 0) {
    throw IntError{"interpret mode only"};
  }
}

void check_not_int_exec(const IntCtx& ctx) {
  if (ctx.state < 0) {
    throw IntError{"not allowed in internal interpret mode"};
  }
}

void check_int_exec(const IntCtx& ctx) {
  if (ctx.state >= 0) {
    throw IntError{"internal interpret mode only"};
  }
}
}  // namespace fift
