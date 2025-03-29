//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileBitmask.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"

namespace td {

Bitmask::Bitmask(Decode, Slice data) : data_(zero_one_decode(data)) {
}

Bitmask::Bitmask(Ones, int64 count) : data_(narrow_cast<size_t>((count + 7) / 8), '\0') {
  for (int64 i = 0; i < count; i++) {
    set(i);
  }
}

Bitmask Bitmask::compress(int k) const {
  Bitmask res;
  for (int64 i = 0; i * k < size(); i++) {
    bool f = true;
    for (int64 j = 0; j < k && f; j++) {
      f &= get(i * k + j);
    }
    if (f) {
      res.set(i);
    }
  }
  return res;
}

std::string Bitmask::encode(int32 prefix_count) {
  // remove zeroes at the end to make encoding deterministic
  Slice data(data_);

  int save_i = -1;
  char save_c;
  if (prefix_count != -1) {
    auto truncated_size = (prefix_count + 7) / 8;
    data.truncate(truncated_size);
    if (prefix_count % 8 != 0) {
      save_i = truncated_size - 1;
      save_c = data_[save_i];
      auto mask = 0xff >> (8 - prefix_count % 8);
      data_[save_i] = static_cast<char>(data_[save_i] & mask);
    }
  }
  SCOPE_EXIT {
    if (save_i != -1) {
      data_[save_i] = save_c;
    }
  };
  while (!data.empty() && data.back() == '\0') {
    data.remove_suffix(1);
  }
  return zero_one_encode(data);
}

int64 Bitmask::get_ready_prefix_size(int64 offset, int64 part_size, int64 file_size) const {
  if (offset < 0) {
    return 0;
  }
  if (part_size == 0) {
    return 0;
  }
  CHECK(part_size > 0);
  auto offset_part = offset / part_size;
  auto ones = get_ready_parts(offset_part);
  if (ones == 0) {
    return 0;
  }
  auto ready_parts_end = (offset_part + ones) * part_size;
  if (file_size != 0 && ready_parts_end > file_size) {
    ready_parts_end = file_size;
    if (offset > file_size) {
      offset = file_size;
    }
  }
  auto res = ready_parts_end - offset;
  CHECK(res >= 0);
  return res;
}

int64 Bitmask::get_total_size(int64 part_size, int64 file_size) const {
  int64 res = 0;
  for (int64 i = 0; i < size(); i++) {
    if (get(i)) {
      auto from = i * part_size;
      auto to = from + part_size;
      if (file_size != 0 && file_size < to) {
        to = file_size;
      }
      if (from < to) {
        res += to - from;
      }
    }
  }
  return res;
}

bool Bitmask::get(int64 offset_part) const {
  if (offset_part < 0) {
    return false;
  }
  auto index = narrow_cast<size_t>(offset_part / 8);
  if (index >= data_.size()) {
    return false;
  }
  return (static_cast<uint8>(data_[index]) & (1 << static_cast<int>(offset_part % 8))) != 0;
}

int64 Bitmask::get_ready_parts(int64 offset_part) const {
  int64 res = 0;
  while (get(offset_part + res)) {
    res++;
  }
  return res;
}

std::vector<int32> Bitmask::as_vector() const {
  std::vector<int32> res;
  auto size = narrow_cast<int32>(data_.size() * 8);
  for (int32 i = 0; i < size; i++) {
    if (get(i)) {
      res.push_back(i);
    }
  }
  return res;
}

void Bitmask::set(int64 offset_part) {
  CHECK(offset_part >= 0);
  auto need_size = narrow_cast<size_t>(offset_part / 8 + 1);
  if (need_size > data_.size()) {
    data_.resize(need_size, '\0');
  }
  data_[need_size - 1] = static_cast<char>(data_[need_size - 1] | (1 << (offset_part % 8)));
}

int64 Bitmask::size() const {
  return static_cast<int64>(data_.size()) * 8;
}

StringBuilder &operator<<(StringBuilder &sb, const Bitmask &mask) {
  bool prev = false;
  int32 cnt = 0;
  for (int64 i = 0; i <= mask.size(); i++) {
    bool cur = mask.get(i);
    if (cur != prev) {  // zeros at the end are intentionally skipped
      if (cnt < 5) {
        while (cnt > 0) {
          sb << (prev ? '1' : '0');
          cnt--;
        }
      } else {
        sb << (prev ? '1' : '0') << "(x" << cnt << ')';
        cnt = 0;
      }
    }
    prev = cur;
    cnt++;
  }
  return sb;
}

}  // namespace td
