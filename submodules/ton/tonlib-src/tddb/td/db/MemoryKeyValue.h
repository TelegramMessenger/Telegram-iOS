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
#include "td/db/KeyValue.h"

#include <map>

namespace td {
class MemoryKeyValue : public KeyValue {
 public:
  Result<GetStatus> get(Slice key, std::string &value) override;
  Status set(Slice key, Slice value) override;
  Status erase(Slice key) override;
  Result<size_t> count(Slice prefix) override;

  Status begin_transaction() override;
  Status commit_transaction() override;
  Status abort_transaction() override;

  std::unique_ptr<KeyValueReader> snapshot() override;

  std::string stats() const override;

 private:
  std::map<std::string, std::string, std::less<>> map_;
  int64 get_count_{0};
};
}  // namespace td
