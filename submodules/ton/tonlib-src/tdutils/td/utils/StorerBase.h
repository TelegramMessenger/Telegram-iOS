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

#include "td/utils/int_types.h"

namespace td {

class Storer {
 public:
  Storer() = default;
  Storer(const Storer &) = delete;
  Storer &operator=(const Storer &) = delete;
  Storer(Storer &&) = default;
  Storer &operator=(Storer &&) = default;
  virtual ~Storer() = default;
  virtual size_t size() const = 0;
  virtual size_t store(uint8 *ptr) const TD_WARN_UNUSED_RESULT = 0;
};

}  // namespace td
