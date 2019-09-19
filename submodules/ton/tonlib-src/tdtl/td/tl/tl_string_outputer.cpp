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
#include "tl_string_outputer.h"

namespace td {
namespace tl {

void tl_string_outputer::append(const std::string &str) {
  result += str;
}

std::string tl_string_outputer::get_result() const {
#if defined(_WIN32)
  std::string fixed_result;
  for (std::size_t i = 0; i < result.size(); i++) {
    if (result[i] == '\n') {
      fixed_result += '\r';
    }
    fixed_result += result[i];
  }
  return fixed_result;
#else
  return result;
#endif
}

}  // namespace tl
}  // namespace td
