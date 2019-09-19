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

#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class BinlogReaderInterface {
 public:
  virtual ~BinlogReaderInterface() {
  }
  // returns error or size
  // negative size means reader expects data.size() to be at least -size
  // positive size means first size bytes of data are processed and could be skipped
  virtual td::Result<td::int64> parse(td::Slice data) = 0;

  // called when all passed slices are invalidated
  // Till it is called reader may resue all slices given to it.
  // It makes possible to calculate crc32c in larger chunks
  // TODO: maybe we should just process all data that we can at once
  virtual void flush() {
  }
};
}  // namespace td
