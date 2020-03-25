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
#pragma once

#include <string>
#include <vector>
#include <iostream>

namespace src {

/*
 *
 *   SOURCE FILE READER
 *
 */

struct FileDescr {
  std::string filename;
  std::string text;
  std::vector<long> line_offs;
  bool is_stdin;
  FileDescr(std::string _fname, bool _stdin = false) : filename(std::move(_fname)), is_stdin(_stdin) {
  }
  const char* push_line(std::string new_line);
  const char* convert_offset(long offset, long* line_no, long* line_pos, long* line_size = nullptr) const;
};

struct Fatal {
  std::string message;
  Fatal(std::string _msg) : message(std::move(_msg)) {
  }
  std::string get_msg() const {
    return message;
  }
};

std::ostream& operator<<(std::ostream& os, const Fatal& fatal);

struct SrcLocation {
  const FileDescr* fdescr;
  long char_offs;
  SrcLocation() : fdescr(nullptr), char_offs(-1) {
  }
  SrcLocation(const FileDescr* _fdescr, long offs = -1) : fdescr(_fdescr), char_offs(-1) {
  }
  bool defined() const {
    return fdescr;
  }
  bool eof() const {
    return char_offs == -1;
  }
  void set_eof() {
    char_offs = -1;
  }
  const char* convert_pos(long* line_no, long* line_pos, long* line_size = nullptr) const {
    return defined() ? fdescr->convert_offset(char_offs, line_no, line_pos, line_size) : nullptr;
  }
  void show(std::ostream& os) const;
  bool show_context(std::ostream& os) const;
  void show_gen_error(std::ostream& os, std::string message, std::string err_type = "") const;
  void show_note(std::string err_msg) const {
    show_gen_error(std::cerr, err_msg, "note");
  }
  void show_warning(std::string err_msg) const {
    show_gen_error(std::cerr, err_msg, "warning");
  }
  void show_error(std::string err_msg) const {
    show_gen_error(std::cerr, err_msg, "error");
  }
};

std::ostream& operator<<(std::ostream& os, const SrcLocation& loc);

struct Error {
  virtual ~Error() = default;
  virtual void show(std::ostream& os) const = 0;
};

std::ostream& operator<<(std::ostream& os, const Error& error);

struct ParseError : Error {
  SrcLocation where;
  std::string message;
  ParseError(const SrcLocation& _where, std::string _msg) : where(_where), message(_msg) {
  }
  ParseError(const SrcLocation* _where, std::string _msg) : message(_msg) {
    if (_where) {
      where = *_where;
    }
  }
  ~ParseError() override = default;
  void show(std::ostream& os) const override;
};

class SourceReader {
  std::istream* ifs;
  FileDescr* fdescr;
  SrcLocation loc;
  bool eof;
  std::string cur_line;
  int cur_line_len;
  void set_eof();
  const char *start, *cur, *end;

 public:
  SourceReader(std::istream* _is, FileDescr* _fdescr);
  bool load_line();
  bool is_eof() const {
    return eof;
  }
  int is_eoln() const {
    return cur == end;
  }
  int skip_spc();
  bool seek_eoln() {
    skip_spc();
    return is_eoln();
  }
  bool seek_eof();
  const char* cur_line_cstr() const {
    return cur_line.c_str();
  }
  const SrcLocation& here() const {
    return loc;
  }
  char cur_char() const {
    return *cur;
  }
  char next_char() const {
    return cur[1];
  }
  const char* get_ptr() const {
    return cur;
  }
  const char* get_end_ptr() const {
    return end;
  }
  const char* set_ptr(const char* ptr);
  void advance(int n) {
    set_ptr(get_ptr() + n);
  }
  void error(std::string err_msg) {
    throw ParseError{loc, err_msg};
  }
};

}  // namespace src
