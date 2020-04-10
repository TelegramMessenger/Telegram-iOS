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
#include "tl_file_outputer.h"

#include <cassert>

namespace td {
namespace tl {

void tl_file_outputer::append(const std::string &str) {
  assert(f != NULL);
  std::fprintf(f, "%s", str.c_str());
}

tl_file_outputer::tl_file_outputer() : f(NULL) {
}

void tl_file_outputer::close() {
  if (f) {
    std::fclose(f);
  }
}

bool tl_file_outputer::open(const std::string &file_name) {
  close();

  f = std::fopen(file_name.c_str(), "w");

  return (f != NULL);
}

tl_file_outputer::~tl_file_outputer() {
  close();
}

}  // namespace tl
}  // namespace td
