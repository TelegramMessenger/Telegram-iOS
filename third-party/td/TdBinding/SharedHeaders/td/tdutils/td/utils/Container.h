//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <limits>

namespace td {

// 1. Allocates all objects in vector. (but vector never shrinks)
// 2. Id is safe way to reach this object.
// 3. All ids are unique.
// 4. All ids are non-zero.
template <class DataT>
class Container {
 public:
  using Id = uint64;
  DataT *get(Id id) {
    int32 slot_id = decode_id(id);
    if (slot_id == -1) {
      return nullptr;
    }
    return &slots_[slot_id].data;
  }

  const DataT *get(Id id) const {
    int32 slot_id = decode_id(id);
    if (slot_id == -1) {
      return nullptr;
    }
    return &slots_[slot_id].data;
  }

  void erase(Id id) {
    int32 slot_id = decode_id(id);
    if (slot_id == -1) {
      return;
    }
    release(slot_id);
  }

  DataT extract(Id id) {
    int32 slot_id = decode_id(id);
    CHECK(slot_id != -1);
    auto res = std::move(slots_[slot_id].data);
    release(slot_id);
    return res;
  }

  Id create(DataT &&data = DataT(), uint8 type = 0) {
    int32 id = store(std::move(data), type);
    return encode_id(id);
  }

  Id reset_id(Id id) {
    int32 slot_id = decode_id(id);
    CHECK(slot_id != -1);
    inc_generation(slot_id);
    return encode_id(slot_id);
  }

  static uint8 type_from_id(Id id) {
    return static_cast<uint8>(id);
  }

  vector<Id> ids() const {
    vector<bool> is_bad(slots_.size(), false);
    for (auto id : empty_slots_) {
      is_bad[id] = true;
    }
    vector<Id> res;
    for (size_t i = 0, n = slots_.size(); i < n; i++) {
      if (!is_bad[i]) {
        res.push_back(encode_id(static_cast<int32>(i)));
      }
    }
    return res;
  }

  template <class F>
  void for_each(const F &f) {
    auto ids = this->ids();
    for (auto id : ids) {
      f(id, *get(id));
    }
  }

  template <class F>
  void for_each(const F &f) const {
    auto ids = this->ids();
    for (auto id : ids) {
      f(id, *get(id));
    }
  }

  size_t size() const {
    CHECK(empty_slots_.size() <= slots_.size());
    return slots_.size() - empty_slots_.size();
  }

  bool empty() const {
    return size() == 0;
  }

  void clear() {
    *this = Container<DataT>();
  }

 private:
  static constexpr uint32 GENERATION_STEP = 1 << 8;
  static constexpr uint32 TYPE_MASK = (1 << 8) - 1;
  struct Slot {
    uint32 generation;
    DataT data;
  };
  vector<Slot> slots_;
  vector<int32> empty_slots_;

  Id encode_id(int32 id) const {
    return (static_cast<uint64>(id) << 32) | slots_[id].generation;
  }

  int32 decode_id(Id id) const {
    auto slot_id = static_cast<int32>(id >> 32);
    auto generation = static_cast<uint32>(id);
    if (slot_id < 0 || slot_id >= static_cast<int32>(slots_.size())) {
      return -1;
    }
    if (generation != slots_[slot_id].generation) {
      return -1;
    }
    return slot_id;
  }

  int32 store(DataT &&data, uint8 type) {
    int32 pos;
    if (!empty_slots_.empty()) {
      pos = empty_slots_.back();
      empty_slots_.pop_back();
      slots_[pos].data = std::move(data);
      slots_[pos].generation ^= (slots_[pos].generation & TYPE_MASK) ^ type;
    } else {
      CHECK(slots_.size() <= static_cast<size_t>(std::numeric_limits<int32>::max()));
      pos = static_cast<int32>(slots_.size());
      slots_.push_back(Slot{GENERATION_STEP + type, std::move(data)});
    }
    return pos;
  }

  void release(int32 id) {
    inc_generation(id);
    slots_[id].data = DataT();
    if (slots_[id].generation & ~TYPE_MASK) {  // generation overflow. Can't use this identifier anymore
      empty_slots_.push_back(id);
    }
  }

  void inc_generation(int32 id) {
    slots_[id].generation += GENERATION_STEP;
  }
};

}  // namespace td
