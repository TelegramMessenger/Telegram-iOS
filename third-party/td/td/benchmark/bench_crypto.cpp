//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/benchmark.h"

#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/UInt.h"

#include <openssl/evp.h>
#include <openssl/sha.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <iterator>
#include <random>
#include <string>
#include <vector>

static constexpr std::size_t DATA_SIZE = 8 << 10;
static constexpr std::size_t SHORT_DATA_SIZE = 64;

#if OPENSSL_VERSION_NUMBER <= 0x10100000L
class SHA1Bench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "SHA1 OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    for (int i = 0; i < n; i++) {
      unsigned char md[20];
      SHA1(data, DATA_SIZE, md);
    }
  }
};
#endif

class SHA1ShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "SHA1 [" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    unsigned char md[20];
    for (int i = 0; i < n; i++) {
      td::sha1(td::Slice(data, SHORT_DATA_SIZE), md);
    }
  }
};

class SHA256ShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "SHA256 [" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    unsigned char md[32];
    for (int i = 0; i < n; i++) {
      td::sha256(td::Slice(data, SHORT_DATA_SIZE), td::MutableSlice(md, 32));
    }
  }
};

class SHA512ShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "SHA512 [" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    unsigned char md[64];
    for (int i = 0; i < n; i++) {
      td::sha512(td::Slice(data, SHORT_DATA_SIZE), td::MutableSlice(md, 64));
    }
  }
};

class HmacSha256ShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "HMAC-SHA256 [" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    unsigned char md[32];
    for (int i = 0; i < n; i++) {
      td::hmac_sha256(td::Slice(data, SHORT_DATA_SIZE), td::Slice(data, SHORT_DATA_SIZE), td::MutableSlice(md, 32));
    }
  }
};

class HmacSha512ShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "HMAC-SHA512 [" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    unsigned char md[32];
    for (int i = 0; i < n; i++) {
      td::hmac_sha256(td::Slice(data, SHORT_DATA_SIZE), td::Slice(data, SHORT_DATA_SIZE), td::MutableSlice(md, 32));
    }
  }
};

class AesEcbBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt256 iv;

  std::string get_description() const final {
    return PSTRING() << "AES ECB OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(key.raw, sizeof(key));
    td::Random::secure_bytes(iv.raw, sizeof(iv));
  }

  void run(int n) final {
    td::AesState state;
    state.init(td::as_slice(key), true);
    td::MutableSlice data_slice(data, DATA_SIZE);
    for (int i = 0; i <= n; i++) {
      size_t step = 16;
      for (size_t offset = 0; offset + step <= data_slice.size(); offset += step) {
        state.encrypt(data_slice.ubegin() + offset, data_slice.ubegin() + offset, static_cast<int>(step));
      }
    }
  }
};

class AesIgeEncryptBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt256 iv;

  std::string get_description() const final {
    return PSTRING() << "AES IGE OpenSSL encrypt [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(key.raw, sizeof(key));
    td::Random::secure_bytes(iv.raw, sizeof(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, DATA_SIZE);
    td::AesIgeState state;
    state.init(as_slice(key), as_slice(iv), true);
    for (int i = 0; i < n; i++) {
      state.encrypt(data_slice, data_slice);
    }
  }
};

class AesIgeDecryptBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt256 iv;

  std::string get_description() const final {
    return PSTRING() << "AES IGE OpenSSL decrypt [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(key.raw, sizeof(key));
    td::Random::secure_bytes(iv.raw, sizeof(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, DATA_SIZE);
    td::AesIgeState state;
    state.init(as_slice(key), as_slice(iv), false);
    for (int i = 0; i < n; i++) {
      state.decrypt(data_slice, data_slice);
    }
  }
};

class AesCtrBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt128 iv;

  std::string get_description() const final {
    return PSTRING() << "AES CTR OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(key.raw, sizeof(key));
    td::Random::secure_bytes(iv.raw, sizeof(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, DATA_SIZE);
    td::AesCtrState state;
    state.init(as_slice(key), as_slice(iv));
    for (int i = 0; i < n; i++) {
      state.encrypt(data_slice, data_slice);
    }
  }
};

#if OPENSSL_VERSION_NUMBER >= 0x10100000L
class AesCtrOpenSSLBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt128 iv;

  std::string get_description() const final {
    return PSTRING() << "AES CTR RAW OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(key.raw, sizeof(key));
    td::Random::secure_bytes(iv.raw, sizeof(iv));
  }

  void run(int n) final {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex(ctx, EVP_aes_256_ctr(), nullptr, key.raw, iv.raw);

    td::MutableSlice data_slice(data, DATA_SIZE);
    td::AesCtrState state;
    state.init(as_slice(key), as_slice(iv));
    for (int i = 0; i < n; i++) {
      int len = 0;
      auto int_size = static_cast<int>(DATA_SIZE);
      EVP_EncryptUpdate(ctx, data_slice.ubegin(), &len, data_slice.ubegin(), int_size);
      CHECK(len == int_size);
    }

    EVP_CIPHER_CTX_free(ctx);
  }
};
#endif

class AesCbcDecryptBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt128 iv;

  std::string get_description() const final {
    return PSTRING() << "AES CBC Decrypt OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(as_mutable_slice(key));
    td::Random::secure_bytes(as_mutable_slice(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, DATA_SIZE);
    for (int i = 0; i < n; i++) {
      td::aes_cbc_decrypt(as_slice(key), as_mutable_slice(iv), data_slice, data_slice);
    }
  }
};

class AesCbcEncryptBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];
  td::UInt256 key;
  td::UInt128 iv;

  std::string get_description() const final {
    return PSTRING() << "AES CBC Encrypt OpenSSL [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(as_mutable_slice(key));
    td::Random::secure_bytes(as_mutable_slice(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, DATA_SIZE);
    for (int i = 0; i < n; i++) {
      td::aes_cbc_encrypt(as_slice(key), as_mutable_slice(iv), data_slice, data_slice);
    }
  }
};

template <bool use_state>
class AesIgeShortBench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[SHORT_DATA_SIZE];
  td::UInt256 key;
  td::UInt256 iv;

  std::string get_description() const final {
    return PSTRING() << "AES IGE OpenSSL " << (use_state ? "EVP" : "C  ") << "[" << SHORT_DATA_SIZE << "B]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
    td::Random::secure_bytes(as_mutable_slice(key));
    td::Random::secure_bytes(as_mutable_slice(iv));
  }

  void run(int n) final {
    td::MutableSlice data_slice(data, SHORT_DATA_SIZE);
    for (int i = 0; i < n; i++) {
      if (use_state) {
        td::AesIgeState ige;
        ige.init(as_slice(key), as_slice(iv), false);
        ige.decrypt(data_slice, data_slice);
      } else {
        td::aes_ige_decrypt(as_slice(key), as_mutable_slice(iv), data_slice, data_slice);
      }
    }
  }
};

BENCH(Rand, "std_rand") {
  int res = 0;
  for (int i = 0; i < n; i++) {
    res ^= std::rand();
  }
  td::do_not_optimize_away(res);
}

BENCH(CppRand, "mt19937_rand") {
  std::uint_fast32_t res = 0;
  std::mt19937 g(123);
  for (int i = 0; i < n; i++) {
    res ^= g();
  }
  td::do_not_optimize_away(res);
}

BENCH(TdRand32, "td_rand_fast32") {
  td::uint32 res = 0;
  for (int i = 0; i < n; i++) {
    res ^= td::Random::fast_uint32();
  }
  td::do_not_optimize_away(res);
}

BENCH(TdRandFast, "td_rand_fast") {
  int res = 0;
  for (int i = 0; i < n; i++) {
    res ^= td::Random::fast(0, RAND_MAX);
  }
  td::do_not_optimize_away(res);
}

#if !TD_THREAD_UNSUPPORTED
BENCH(SslRand, "ssl_rand_int32") {
  std::vector<td::thread> v;
  std::atomic<td::uint32> sum{0};
  for (int i = 0; i < 3; i++) {
    v.emplace_back([&sum, n] {
      td::int32 res = 0;
      for (int j = 0; j < n; j++) {
        res ^= td::Random::secure_int32();
      }
      sum += res;
    });
  }
  for (auto &x : v) {
    x.join();
  }
  v.clear();
  td::do_not_optimize_away(sum.load());
}
#endif

BENCH(SslRandBuf, "ssl_rand_bytes") {
  td::int32 res = 0;
  std::array<td::int32, 1000> buf;
  for (int i = 0; i < n; i += static_cast<int>(buf.size())) {
    td::Random::secure_bytes(reinterpret_cast<td::uint8 *>(buf.data()), sizeof(buf[0]) * buf.size());
    for (auto x : buf) {
      res ^= x;
    }
  }
  td::do_not_optimize_away(res);
}

BENCH(Pbkdf2, "pbkdf2") {
  std::string password = "cucumber";
  std::string salt = "abcdefghijklmnopqrstuvw";
  std::string key(32, ' ');
  td::pbkdf2_sha256(password, salt, n, key);
}

class Crc32Bench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "CRC32 zlib [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    td::uint64 res = 0;
    for (int i = 0; i < n; i++) {
      res += td::crc32(td::Slice(data, DATA_SIZE));
    }
    td::do_not_optimize_away(res);
  }
};

class Crc64Bench final : public td::Benchmark {
 public:
  alignas(64) unsigned char data[DATA_SIZE];

  std::string get_description() const final {
    return PSTRING() << "CRC64 Anton [" << (DATA_SIZE >> 10) << "KB]";
  }

  void start_up() final {
    std::fill(std::begin(data), std::end(data), static_cast<unsigned char>(123));
  }

  void run(int n) final {
    td::uint64 res = 0;
    for (int i = 0; i < n; i++) {
      res += td::crc64(td::Slice(data, DATA_SIZE));
    }
    td::do_not_optimize_away(res);
  }
};

int main() {
  td::init_openssl_threads();
  td::bench(AesCtrBench());
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  td::bench(AesCtrOpenSSLBench());
#endif

  td::bench(AesCbcDecryptBench());
  td::bench(AesCbcEncryptBench());
  td::bench(AesIgeShortBench<true>());
  td::bench(AesIgeShortBench<false>());
  td::bench(AesIgeEncryptBench());
  td::bench(AesIgeDecryptBench());
  td::bench(AesEcbBench());

  td::bench(Pbkdf2Bench());
  td::bench(RandBench());
  td::bench(CppRandBench());
  td::bench(TdRand32Bench());
  td::bench(TdRandFastBench());
#if !TD_THREAD_UNSUPPORTED
  td::bench(SslRandBench());
#endif
  td::bench(SslRandBufBench());
#if OPENSSL_VERSION_NUMBER <= 0x10100000L
  td::bench(SHA1Bench());
#endif
  td::bench(SHA1ShortBench());
  td::bench(SHA256ShortBench());
  td::bench(SHA512ShortBench());
  td::bench(HmacSha256ShortBench());
  td::bench(HmacSha512ShortBench());
  td::bench(Crc32Bench());
  td::bench(Crc64Bench());
}
