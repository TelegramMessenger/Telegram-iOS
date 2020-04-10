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
#include "td/db/MemoryKeyValue.h"

#include "td/utils/format.h"

namespace td {
Result<MemoryKeyValue::GetStatus> MemoryKeyValue::get(Slice key, std::string &value) {
  auto it = map_.find(key);
  if (it == map_.end()) {
    return GetStatus::NotFound;
  }
  value = it->second;
  return GetStatus::Ok;
}
Status MemoryKeyValue::set(Slice key, Slice value) {
  map_[key.str()] = value.str();
  return Status::OK();
}
Status MemoryKeyValue::erase(Slice key) {
  auto it = map_.find(key);
  if (it != map_.end()) {
    map_.erase(it);
  }
  return Status::OK();
}

Result<size_t> MemoryKeyValue::count(Slice prefix) {
  size_t res = 0;
  for (auto it = map_.lower_bound(prefix); it != map_.end(); it++) {
    if (Slice(it->first).truncate(prefix.size()) != prefix) {
      break;
    }
    res++;
  }
  return res;
}

std::unique_ptr<KeyValueReader> MemoryKeyValue::snapshot() {
  auto res = std::make_unique<MemoryKeyValue>();
  res->map_ = map_;
  return std::move(res);
}

std::string MemoryKeyValue::stats() const {
  return PSTRING() << "MemoryKeyValueStats{" << tag("get_count", get_count_) << "}";
}

Status MemoryKeyValue::begin_transaction() {
  UNREACHABLE();
}
Status MemoryKeyValue::commit_transaction() {
  UNREACHABLE();
}
Status MemoryKeyValue::abort_transaction() {
  UNREACHABLE();
}
}  // namespace td
