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
#include "td/utils/find_boundary.h"

#include <cstring>

namespace td {

bool find_boundary(ChainBufferReader range, Slice boundary, size_t &already_read) {
  range.advance(already_read);

  const int MAX_BOUNDARY_LENGTH = 70;
  CHECK(boundary.size() <= MAX_BOUNDARY_LENGTH + 4);
  while (!range.empty()) {
    Slice ready = range.prepare_read();
    if (ready[0] == boundary[0]) {
      if (range.size() < boundary.size()) {
        return false;
      }
      auto save_range = range.clone();
      char x[MAX_BOUNDARY_LENGTH + 4];
      range.advance(boundary.size(), {x, sizeof(x)});
      if (Slice(x, boundary.size()) == boundary) {
        return true;
      }

      // not a boundary, restoring previous state and skip one symbol
      range = std::move(save_range);
      range.advance(1);
      already_read++;
    } else {
      const char *ptr = static_cast<const char *>(std::memchr(ready.data(), boundary[0], ready.size()));
      size_t shift;
      if (ptr == nullptr) {
        shift = ready.size();
      } else {
        shift = ptr - ready.data();
      }
      already_read += shift;
      range.advance(shift);
    }
  }

  return false;
}

}  // namespace td
