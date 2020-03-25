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

    Copyright 2020 Telegram Systems LLP
*/
namespace td {

class LinearAllocator {
  std::size_t size;
  char *ptr, *cur, *end;

 public:
  LinearAllocator(std::size_t _size) : size(_size) {
    cur = ptr = (char*)malloc(size);
    if (!ptr) {
      throw std::bad_alloc();
    }
    end = ptr + size;
  }
  ~LinearAllocator() {
    free(ptr);
  }
  void* allocate(std::size_t count) {
    char* t = cur;
    cur += (count + 7) & -8;
    if (cur > end) {
      throw std::bad_alloc();
    }
    return (void*)t;
  }
};

}  // namespace td

inline void* operator new(std::size_t count, td::LinearAllocator& alloc) {
  return alloc.allocate(count);
}
