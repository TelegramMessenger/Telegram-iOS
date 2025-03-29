//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
  constexpr size_t BUF_SIZE = 512;
  static TD_THREAD_LOCAL unsigned char *buf;  // static zero-initialized
  static TD_THREAD_LOCAL size_t buf_pos;
  static TD_THREAD_LOCAL int64 generation;
  if (init_thread_local<unsigned char[]>(buf, BUF_SIZE)) {
    buf_pos = BUF_SIZE;
    generation = 0;
  }
  if (ptr == nullptr) {
    MutableSlice(buf, BUF_SIZE).fill_zero_secure();
    buf_pos = BUF_SIZE;
    return;
  }
  if (generation != random_seed_generation.load(std::memory_order_relaxed)) {
    generation = random_seed_generation.load(std::memory_order_acquire);
    buf_pos = BUF_SIZE;
  }

  auto ready = min(size, BUF_SIZE - buf_pos);
  if (ready != 0) {
    std::memcpy(ptr, buf + buf_pos, ready);
    buf_pos += ready;
    ptr += ready;
    size -= ready;
    if (size == 0) {
      return;
    }
  }
  if (size < BUF_SIZE) {
    int err = RAND_bytes(buf, static_cast<int>(BUF_SIZE));
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

int Random::fast(int min_value, int max_value) {
  if (min_value == std::numeric_limits<int>::min() && max_value == std::numeric_limits<int>::max()) {
    // to prevent integer overflow and division by zero
    min_value++;
  }
  DCHECK(min_value <= max_value);
  return static_cast<int>(min_value + fast_uint32() % (max_value - min_value + 1));  // TODO signed_cast
}

double Random::fast(double min_value, double max_value) {
  DCHECK(min_value <= max_value);
  return min_value + fast_uint32() * 1.0 / std::numeric_limits<uint32>::max() * (max_value - min_value);
}

bool Random::fast_bool() {
  return (fast_uint32() & 1) != 0;
}

Random::Xorshift128plus::Xorshift128plus(uint64 seed) {
  auto next = [&] {
    // splitmix64
    seed += static_cast<uint64>(0x9E3779B97F4A7C15ull);
    uint64 z = seed;
    z = (z ^ (z >> 30)) * static_cast<uint64>(0xBF58476D1CE4E5B9ull);
    z = (z ^ (z >> 27)) * static_cast<uint64>(0x94D049BB133111EBull);
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

int Random::Xorshift128plus::fast(int min_value, int max_value) {
  return static_cast<int>((*this)() % (max_value - min_value + 1) + min_value);
}
int64 Random::Xorshift128plus::fast64(int64 min_value, int64 max_value) {
  return static_cast<int64>((*this)() % (max_value - min_value + 1) + min_value);
}

void Random::Xorshift128plus::bytes(MutableSlice dest) {
  int cnt = 0;
  uint64 buf = 0;
  for (auto &c : dest) {
    if (cnt == 0) {
      buf = operator()();
      cnt = 8;
    }
    cnt--;
    c = static_cast<char>(buf & 255);
    buf >>= 8;
  }
}

}  // namespace td
