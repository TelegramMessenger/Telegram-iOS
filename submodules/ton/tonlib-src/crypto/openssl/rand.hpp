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
#include <string>
#include <cassert>

namespace prng {

// use this generator unless need a separate one
class RandomGen;
RandomGen &rand_gen();

class RandomGen {
 public:
  struct rand_error {};
  void randomize(bool force = true);
  void seed_add(const void *data, std::size_t size, double entropy = 0);
  bool ok() const;
  RandomGen() {
    randomize(false);
  }
  RandomGen(const void *seed, std::size_t size) {
    seed_add(seed, size);
    randomize(false);
  }
  bool rand_bytes(void *data, std::size_t size, bool strong = false);
  bool strong_rand_bytes(void *data, std::size_t size) {
    return rand_bytes(data, size, true);
  }
  template <class T>
  bool rand_obj(T &obj) {
    return rand_bytes(&obj, sizeof(T));
  }
  template <class T>
  bool rand_objs(T *ptr, std::size_t count) {
    return rand_bytes(ptr, sizeof(T) * count);
  }
  std::string rand_string(std::size_t size, bool strong = false);
};
}  // namespace prng
