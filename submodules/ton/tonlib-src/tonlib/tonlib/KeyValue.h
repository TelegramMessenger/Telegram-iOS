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
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <functional>

namespace tonlib {
class KeyValue {
 public:
  virtual ~KeyValue() = default;
  virtual td::Status add(td::Slice key, td::Slice value) = 0;
  virtual td::Status set(td::Slice key, td::Slice value) = 0;
  virtual td::Status erase(td::Slice key) = 0;
  virtual td::Result<td::SecureString> get(td::Slice key) = 0;
  virtual void foreach_key(std::function<void(td::Slice)> f) = 0;

  static td::Result<td::unique_ptr<KeyValue>> create_dir(td::CSlice dir);
  static td::Result<td::unique_ptr<KeyValue>> create_inmemory();
};
}  // namespace tonlib
