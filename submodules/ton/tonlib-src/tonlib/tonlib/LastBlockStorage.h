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

#include "tonlib/LastBlock.h"

#include "tonlib/KeyValue.h"

namespace tonlib {
class LastBlockStorage {
 public:
  void set_key_value(std::shared_ptr<KeyValue> kv);
  td::Result<LastBlockState> get_state(td::Slice name);
  void save_state(td::Slice name, LastBlockState state);

 private:
  std::shared_ptr<KeyValue> kv_;
};
}  // namespace tonlib
