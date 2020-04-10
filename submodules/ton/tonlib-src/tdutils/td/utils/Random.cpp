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
#include "td/utils/Random.h"

#include "td/utils/logging.h"
#include "td/utils/port/thread_local.h"

#if TD_HAVE_OPENSSL
#include <openssl/rand.h>
#endif

#include <atomic>
#include <cstring>
#include <limits>
#include <random>

namespace td {

#if TD_HAVE_OPENSSL

namespace {
std::atomic<int64> random_seed_generation{0};
}  // namespace

void Random::secure_bytes(MutableSlice dest) {
  Random::secure_bytes(dest.ubegin(), dest.size());
}

void Random::secure_bytes(unsigned char *ptr, size_t size) {
  constexpr size_t buf_size = 512;
  static TD_THREAD_LOCAL unsigned char *buf;  // static zero-initialized
  static TD_THREAD_LOCAL size_t buf_pos;
  static TD_THREAD_LOCAL int64 generation;
  if (init_thread_local<unsigned char[]>(buf, buf_size)) {
    buf_pos = buf_size;
    generation = 0;
  }
  if (ptr == nullptr) {
    td::MutableSlice(buf, buf_size).fill_zero_secure();
    buf_pos = buf_size;
    return;
  }
  if (generation != random_seed_generation.load(std::memory_order_relaxed)) {
    generation = random_seed_generation.load(std::memory_order_acquire);
    buf_pos = buf_size;
  }

  auto ready = min(size, buf_size - buf_pos);
  if (ready != 0) {
    std::memcpy(ptr, buf + buf_pos, ready);
    buf_pos += ready;
    ptr += ready;
    size -= ready;
    if (size == 0) {
      return;
    }
  }
  if (size < buf_size) {
    int err = RAND_bytes(buf, static_cast<int>(buf_size));
    // TODO: it CAN fail
    LOG_IF(FATAL, err != 1);
    buf_pos = size;
    std::memcpy(ptr, buf, size);
    return;
  }

  CHECK(size <= static_cast<size_t>(std::numeric_limits<int>::max()));
  int err = RAND_bytes(ptr, static_cast<int>(size));
  // TODO: it CAN fail
  LOG_IF(FATAL, err != 1);
}

int32 Random::secure_int32() {
  int32 res = 0;
  secure_bytes(reinterpret_cast<unsigned char *>(&res), sizeof(int32));
  return res;
}

int64 Random::secure_int64() {
  int64 res = 0;
  secure_bytes(reinterpret_cast<unsigned char *>(&res), sizeof(int64));
  return res;
}

uint32 Random::secure_uint32() {
  uint32 res = 0;
  secure_bytes(reinterpret_cast<unsigned char *>(&res), sizeof(uint32));
  return res;
}

uint64 Random::secure_uint64() {
  uint64 res = 0;
  secure_bytes(reinterpret_cast<unsigned char *>(&res), sizeof(uint64));
  return res;
}

void Random::add_seed(Slice bytes, double entropy) {
  RAND_add(bytes.data(), static_cast<int>(bytes.size()), entropy);
  random_seed_generation++;
}

void Random::secure_cleanup() {
  Random::secure_bytes(nullptr, 0);
}
#endif

static unsigned int rand_device_helper() {
  static TD_THREAD_LOCAL std::random_device *rd;
  init_thread_local<std::random_device>(rd);
  return (*rd)();
}

uint32 Random::fast_uint32() {
  static TD_THREAD_LOCAL std::mt19937 *gen;
  if (!gen) {
    auto &rg = rand_device_helper;
    std::seed_seq seq{rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg()};
    init_thread_local<std::mt19937>(gen, seq);
  }
  return static_cast<uint32>((*gen)());
}

uint64 Random::fast_uint64() {
  static TD_THREAD_LOCAL std::mt19937_64 *gen;
  if (!gen) {
    auto &rg = rand_device_helper;
    std::seed_seq seq{rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg(), rg()};
    init_thread_local<std::mt19937_64>(gen, seq);
  }
  return static_cast<uint64>((*gen)());
}

int Random::fast(int min, int max) {
  if (min == std::numeric_limits<int>::min() && max == std::numeric_limits<int>::max()) {
    // to prevent integer overflow and division by zero
    min++;
  }
  DCHECK(min <= max);
  return static_cast<int>(min + fast_uint32() % (max - min + 1));  // TODO signed_cast
}

double Random::fast(double min, double max) {
  DCHECK(min <= max);
  return min +
         fast_uint32() * 1.0 /
             (static_cast<double>(std::numeric_limits<td::uint32>::max()) - std::numeric_limits<td::uint32>::min()) *
             (max - min);
}

Random::Xorshift128plus::Xorshift128plus(uint64 seed) {
  auto next = [&]() {
    // splitmix64
    seed += static_cast<uint64>(0x9E3779B97F4A7C15);
    uint64 z = seed;
    z = (z ^ (z >> 30)) * static_cast<uint64>(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)) * static_cast<uint64>(0x94D049BB133111EB);
    return z ^ (z >> 31);
  };
  seed_[0] = next();
  seed_[1] = next();
}

Random::Xorshift128plus::Xorshift128plus(uint64 seed_a, uint64 seed_b) {
  seed_[0] = seed_a;
  seed_[1] = seed_b;
}

uint64 Random::Xorshift128plus::operator()() {
  uint64 x = seed_[0];
  const uint64 y = seed_[1];
  seed_[0] = y;
  x ^= x << 23;
  seed_[1] = x ^ y ^ (x >> 17) ^ (y >> 26);
  return seed_[1] + y;
}
int Random::Xorshift128plus::fast(int min, int max) {
  return static_cast<int>((*this)() % (max - min + 1) + min);
}

}  // namespace td
