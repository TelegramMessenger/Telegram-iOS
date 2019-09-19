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
#include "td/utils/common.h"

#include "StreamInterface.h"

namespace td {
class ChainBuffer {
 public:
  struct Options {
    Options() {
    }
    size_t chunk_size{1024 * 1024 / 8};  // default size of one chunk in chain buffer
    size_t max_io_slices{128};           // size of buffer for writev
  };
  using Reader = StreamReader;
  using Writer = StreamWriter;
  static std::pair<Reader, Writer> create(Options options = {});
};
}  // namespace td
