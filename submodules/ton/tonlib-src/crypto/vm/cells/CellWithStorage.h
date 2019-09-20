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

namespace vm {
namespace detail {
template <class CellT, size_t Size = 0>
class CellWithArrayStorage : public CellT {
 public:
  template <class... ArgsT>
  CellWithArrayStorage(ArgsT&&... args) : CellT(std::forward<ArgsT>(args)...) {
  }
  ~CellWithArrayStorage() {
    CellT::destroy_storage(get_storage());
  }
  template <class... ArgsT>
  static std::unique_ptr<CellT> create(size_t storage_size, ArgsT&&... args) {
    static_assert(CellT::max_storage_size <= 40 * 8, "");
    //size = 128 + 32 + 8;
    auto size = (storage_size + 7) / 8;
#define CASE(size) \
  case (size):     \
    return std::make_unique<CellWithArrayStorage<CellT, (size)*8>>(std::forward<ArgsT>(args)...);
#define CASE2(offset) CASE(offset) CASE(offset + 1)
#define CASE8(offset) CASE2(offset) CASE2(offset + 2) CASE2(offset + 4) CASE2(offset + 6)
#define CASE32(offset) CASE8(offset) CASE8(offset + 8) CASE8(offset + 16) CASE8(offset + 24)
    switch (size) { CASE32(0) CASE8(32) }
#undef CASE
#undef CASE2
#undef CASE8
#undef CASE32
    LOG(FATAL) << "TOO BIG " << storage_size;
    UNREACHABLE();
  }

 private:
  alignas(alignof(void*)) char storage_[Size];

  const char* get_storage() const final {
    return storage_;
  }
  char* get_storage() final {
    return storage_;
  }
};

template <class CellT>
class CellWithUniquePtrStorage : public CellT {
 public:
  template <class... ArgsT>
  CellWithUniquePtrStorage(size_t storage_size, ArgsT&&... args)
      : CellT(std::forward<ArgsT>(args)...), storage_(std::make_unique<char[]>(storage_size)) {
  }
  ~CellWithUniquePtrStorage() {
    CellT::destroy_storage(get_storage());
  }

  template <class... ArgsT>
  static std::unique_ptr<CellT> create(size_t storage_size, ArgsT&&... args) {
    return std::make_unique<CellWithUniquePtrStorage>(storage_size, std::forward<ArgsT>(args)...);
  }

 private:
  std::unique_ptr<char[]> storage_;

  const char* get_storage() const final {
    CHECK(storage_);
    return storage_.get();
  }
  char* get_storage() final {
    CHECK(storage_);
    return storage_.get();
  }
};
}  // namespace detail
}  // namespace vm
