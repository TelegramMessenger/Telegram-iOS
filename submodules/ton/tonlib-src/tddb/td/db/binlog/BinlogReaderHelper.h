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

#include "td/utils/Status.h"
#include "td/utils/Slice.h"

namespace td {

class BinlogReaderInterface;

// Usually we have data available in chunks and we can't control chunk's sizes
// And some events will be in multiple chunks.
// We suggest that all events are small, chunks are big and only small
// portion of events will lie on chunk's border.
// This helper will store this rare events locally and will feed them
// to BinlogReaderInterface as single memory chunk each.
class BinlogReaderHelper {
 public:
  td::Status parse(BinlogReaderInterface& reader, td::Slice data);

  size_t unparsed_size() const;

 private:
  alignas(16) std::array<char, 1024> buf_;
  size_t prefix_size_{0};
  size_t expected_prefix_size_{0};
};

}  // namespace td
