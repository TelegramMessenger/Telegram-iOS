//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/crypto.h"

#include "td/utils/as.h"
#include "td/utils/BigNum.h"
#include "td/utils/bits.h"
#include "td/utils/common.h"
#include "td/utils/Destructor.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"

#if TD_HAVE_OPENSSL
#include <openssl/aes.h>
#include <openssl/bio.h>
#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/md5.h>
#include <openssl/opensslv.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/sha.h>
#endif

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
#include <openssl/core_names.h>
#include <openssl/params.h>
#endif

#if TD_HAVE_ZLIB
#include <zlib.h>
#endif

#if TD_HAVE_CRC32C
#include "crc32c/crc32c.h"
#endif

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <mutex>
#include <utility>

namespace td {

static uint64 pq_gcd(uint64 a, uint64 b) {
  if (a == 0) {
    return b;
  }
  while ((a & 1) == 0) {
    a >>= 1;
  }
  DCHECK((b & 1) != 0);

  while (true) {
    if (a > b) {
      a = (a - b) >> 1;
      while ((a & 1) == 0) {
        a >>= 1;
      }
    } else if (b > a) {
      b = (b - a) >> 1;
      while ((b & 1) == 0) {
        b >>= 1;
      }
    } else {
      return a;
    }
  }
}

// returns (c + a * b) % pq
static uint64 pq_add_mul(uint64 c, uint64 a, uint64 b, uint64 pq) {
  while (b) {
    if (b & 1) {
      c += a;
      if (c >= pq) {
        c -= pq;
      }
    }
    a += a;
    if (a >= pq) {
      a -= pq;
    }
    b >>= 1;
  }
  return c;
}

uint64 pq_factorize(uint64 pq) {
  if (pq <= 2 || pq > (static_cast<uint64>(1) << 63)) {
    return 1;
  }
  if ((pq & 1) == 0) {
    return 2;
  }
  uint64 g = 0;
  for (int i = 0, iter = 0; i < 3 || iter < 1000; i++) {
    uint64 q = Random::fast(17, 32) % (pq - 1);
    uint64 x = Random::fast_uint64() % (pq - 1) + 1;
    uint64 y = x;
    int lim = 1 << (min(5, i) + 18);
    for (int j = 1; j < lim; j++) {
      iter++;
      x = pq_add_mul(q, x, x, pq);
      uint64 z = x < y ? pq + x - y : x - y;
      g = pq_gcd(z, pq);
      if (g != 1) {
        break;
      }

      if (!(j & (j - 1))) {
        y = x;
      }
    }
    if (g > 1 && g < pq) {
      break;
    }
  }
  if (g != 0) {
    uint64 other = pq / g;
    if (other < g) {
      g = other;
    }
  }
  return g;
}

#if TD_HAVE_OPENSSL
void init_crypto() {
  static bool is_inited = [] {
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
    bool result = OPENSSL_init_crypto(0, nullptr) != 0;
#else
    OpenSSL_add_all_algorithms();
    bool result = true;
#endif
    clear_openssl_errors("Init crypto");
    return result;
  }();
  CHECK(is_inited);
}

template <class FromT>
static string as_big_endian_string(const FromT &from) {
  char res[sizeof(FromT)];
  as<FromT>(res) = from;

  size_t i = sizeof(FromT);
  while (i && res[i - 1] == 0) {
    i--;
  }

  std::reverse(res, res + i);
  return string(res, res + i);
}

static int pq_factorize_big(Slice pq_str, string *p_str, string *q_str) {
  // TODO: qsieve?
  // do not work for pq == 1
  BigNumContext context;
  BigNum a;
  BigNum b;
  BigNum p;
  BigNum q;
  BigNum one;
  one.set_value(1);

  BigNum pq = BigNum::from_binary(pq_str);

  bool found = false;
  for (int i = 0, iter = 0; !found && (i < 3 || iter < 1000); i++) {
    int32 t = Random::fast(17, 32);
    a.set_value(Random::fast_uint32());
    b = a;

    int32 lim = 1 << (i + 23);
    for (int j = 1; j < lim; j++) {
      iter++;
      BigNum::mod_mul(a, a, a, pq, context);
      a += t;
      if (BigNum::compare(a, pq) >= 0) {
        BigNum tmp;
        BigNum::sub(tmp, a, pq);
        a = std::move(tmp);
      }
      if (BigNum::compare(a, b) > 0) {
        BigNum::sub(q, a, b);
      } else {
        BigNum::sub(q, b, a);
      }
      BigNum::gcd(p, q, pq, context);
      if (BigNum::compare(p, one) != 0) {
        found = true;
        break;
      }
      if ((j & (j - 1)) == 0) {
        b = a;
      }
    }
  }

  if (found) {
    BigNum::div(&q, nullptr, pq, p, context);
    if (BigNum::compare(p, q) > 0) {
      std::swap(p, q);
    }

    *p_str = p.to_binary();
    *q_str = q.to_binary();

    return 0;
  }

  return -1;
}

int pq_factorize(Slice pq_str, string *p_str, string *q_str) {
  size_t size = pq_str.size();
  if (static_cast<int>(size) > 8 || (static_cast<int>(size) == 8 && (pq_str.begin()[0] & 128) != 0)) {
    return pq_factorize_big(pq_str, p_str, q_str);
  }

  auto ptr = pq_str.ubegin();
  uint64 pq = 0;
  for (int i = 0; i < static_cast<int>(size); i++) {
    pq = (pq << 8) | ptr[i];
  }

  uint64 p = pq_factorize(pq);
  if (p == 0 || pq % p != 0) {
    return -1;
  }
  *p_str = as_big_endian_string(p);
  *q_str = as_big_endian_string(pq / p);

  // std::string p2, q2;
  // pq_factorize_big(pq_str, &p2, &q2);
  // CHECK(*p_str == p2);
  // CHECK(*q_str == q2);
  return 0;
}

struct AesBlock {
  uint64 hi;
  uint64 lo;

  uint8 *raw() {
    return reinterpret_cast<uint8 *>(this);
  }
  const uint8 *raw() const {
    return reinterpret_cast<const uint8 *>(this);
  }
  Slice as_slice() const {
    return Slice(raw(), AES_BLOCK_SIZE);
  }

  AesBlock operator^(const AesBlock &b) const {
    AesBlock res;
    res.hi = hi ^ b.hi;
    res.lo = lo ^ b.lo;
    return res;
  }
  void operator^=(const AesBlock &b) {
    hi ^= b.hi;
    lo ^= b.lo;
  }

  void load(const uint8 *from) {
    *this = as<AesBlock>(from);
  }
  void store(uint8 *to) {
    as<AesBlock>(to) = *this;
  }

  AesBlock inc() const {
#if SIZE_MAX == UINT64_MAX
    AesBlock res;
    res.lo = host_to_big_endian64(big_endian_to_host64(lo) + 1);
    if (res.lo == 0) {
      res.hi = host_to_big_endian64(big_endian_to_host64(hi) + 1);
    } else {
      res.hi = hi;
    }
    return res;
#else
    AesBlock res = *this;
    auto ptr = res.raw();
    if (++ptr[15] == 0) {
      for (int i = 14; i >= 0; i--) {
        if (++ptr[i] != 0) {
          break;
        }
      }
    }
    return res;
#endif
  }
};
static_assert(sizeof(AesBlock) == 16, "");
static_assert(sizeof(AesBlock) == AES_BLOCK_SIZE, "");

class Evp {
 public:
  Evp() {
    ctx_ = EVP_CIPHER_CTX_new();
    LOG_IF(FATAL, ctx_ == nullptr);
  }
  Evp(const Evp &) = delete;
  Evp &operator=(const Evp &) = delete;
  Evp(Evp &&) = delete;
  Evp &operator=(Evp &&) = delete;
  ~Evp() {
    CHECK(ctx_ != nullptr);
    EVP_CIPHER_CTX_free(ctx_);
  }

  void init_encrypt_ecb(Slice key) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;
    if (unlikely(evp_cipher == nullptr)) {
      init_thread_local_evp_cipher(evp_cipher, "AES-256-ECB");
    }
#else
    const EVP_CIPHER *evp_cipher = EVP_aes_256_ecb();
#endif
    init(true, evp_cipher, key);
  }

  void init_decrypt_ecb(Slice key) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;
    if (unlikely(evp_cipher == nullptr)) {
      init_thread_local_evp_cipher(evp_cipher, "AES-256-ECB");
    }
#else
    const EVP_CIPHER *evp_cipher = EVP_aes_256_ecb();
#endif
    init(false, evp_cipher, key);
  }

  void init_encrypt_cbc(Slice key) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;
    if (unlikely(evp_cipher == nullptr)) {
      init_thread_local_evp_cipher(evp_cipher, "AES-256-CBC");
    }
#else
    const EVP_CIPHER *evp_cipher = EVP_aes_256_cbc();
#endif
    init(true, evp_cipher, key);
  }

  void init_decrypt_cbc(Slice key) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;
    if (unlikely(evp_cipher == nullptr)) {
      init_thread_local_evp_cipher(evp_cipher, "AES-256-CBC");
    }
#else
    const EVP_CIPHER *evp_cipher = EVP_aes_256_cbc();
#endif
    init(false, evp_cipher, key);
  }

#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  void init_encrypt_ctr(Slice key) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;
    if (unlikely(evp_cipher == nullptr)) {
      init_thread_local_evp_cipher(evp_cipher, "AES-256-CTR");
    }
#else
    const EVP_CIPHER *evp_cipher = EVP_aes_256_ctr();
#endif
    init(true, evp_cipher, key);
  }
#endif

  void init_iv(Slice iv) {
    int res = EVP_CipherInit_ex(ctx_, nullptr, nullptr, nullptr, iv.ubegin(), -1);
    LOG_IF(FATAL, res != 1);
  }

  void encrypt(const uint8 *src, uint8 *dst, int size) {
    int len;
    int res = EVP_EncryptUpdate(ctx_, dst, &len, src, size);
    LOG_IF(FATAL, res != 1);
    CHECK(len == size);
  }

  void decrypt(const uint8 *src, uint8 *dst, int size) {
    CHECK(size % AES_BLOCK_SIZE == 0);
    int len;
    int res = EVP_DecryptUpdate(ctx_, dst, &len, src, size);
    LOG_IF(FATAL, res != 1);
    CHECK(len == size);
  }

 private:
  EVP_CIPHER_CTX *ctx_{nullptr};

  void init(bool is_encrypt, const EVP_CIPHER *evp_cipher, Slice key) {
    int res = EVP_CipherInit_ex(ctx_, evp_cipher, nullptr, key.ubegin(), nullptr, is_encrypt ? 1 : 0);
    LOG_IF(FATAL, res != 1);
    EVP_CIPHER_CTX_set_padding(ctx_, 0);
  }

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static void init_thread_local_evp_cipher(const EVP_CIPHER *&evp_cipher, const char *algorithm) {
    evp_cipher = EVP_CIPHER_fetch(nullptr, algorithm, nullptr);
    LOG_IF(FATAL, evp_cipher == nullptr);
    detail::add_thread_local_destructor(create_destructor([&evp_cipher]() mutable {
      EVP_CIPHER_free(const_cast<EVP_CIPHER *>(evp_cipher));
      evp_cipher = nullptr;
    }));
  }
#endif
};

struct AesState::Impl {
  Evp evp;
};

AesState::AesState() = default;
AesState::AesState(AesState &&) noexcept = default;
AesState &AesState::operator=(AesState &&) noexcept = default;
AesState::~AesState() = default;

void AesState::init(Slice key, bool encrypt) {
  CHECK(key.size() == 32);
  if (!impl_) {
    impl_ = make_unique<Impl>();
  }
  if (encrypt) {
    impl_->evp.init_encrypt_ecb(key);
  } else {
    impl_->evp.init_decrypt_ecb(key);
  }
}

void AesState::encrypt(const uint8 *src, uint8 *dst, int size) {
  CHECK(impl_);
  impl_->evp.encrypt(src, dst, size);
}

void AesState::decrypt(const uint8 *src, uint8 *dst, int size) {
  CHECK(impl_);
  impl_->evp.decrypt(src, dst, size);
}

class AesIgeStateImpl {
 public:
  void init(Slice key, Slice iv, bool encrypt) {
    CHECK(key.size() == 32);
    CHECK(iv.size() == 32);
    if (encrypt) {
      evp_.init_encrypt_cbc(key);
    } else {
      evp_.init_decrypt_ecb(key);
    }

    encrypted_iv_.load(iv.ubegin());
    plaintext_iv_.load(iv.ubegin() + AES_BLOCK_SIZE);
  }

  void get_iv(MutableSlice iv) {
    CHECK(iv.size() == 32);
    encrypted_iv_.store(iv.ubegin());
    plaintext_iv_.store(iv.ubegin() + AES_BLOCK_SIZE);
  }

  void encrypt(Slice from, MutableSlice to) {
    CHECK(from.size() % AES_BLOCK_SIZE == 0);
    CHECK(to.size() >= from.size());
    auto len = to.size() / AES_BLOCK_SIZE;
    auto in = from.ubegin();
    auto out = to.ubegin();

    static constexpr size_t BLOCK_COUNT = 31;
    while (len != 0) {
      AesBlock data[BLOCK_COUNT];
      AesBlock data_xored[BLOCK_COUNT];

      auto count = td::min(BLOCK_COUNT, len);
      std::memcpy(data, in, AES_BLOCK_SIZE * count);
      data_xored[0] = data[0];
      if (count > 1) {
        data_xored[1] = plaintext_iv_ ^ data[1];
        for (size_t i = 2; i < count; i++) {
          data_xored[i] = data[i - 2] ^ data[i];
        }
      }

      evp_.init_iv(encrypted_iv_.as_slice());
      auto inlen = static_cast<int>(AES_BLOCK_SIZE * count);
      evp_.encrypt(data_xored[0].raw(), data_xored[0].raw(), inlen);

      data_xored[0] ^= plaintext_iv_;
      for (size_t i = 1; i < count; i++) {
        data_xored[i] ^= data[i - 1];
      }
      plaintext_iv_ = data[count - 1];
      encrypted_iv_ = data_xored[count - 1];

      std::memcpy(out, data_xored, AES_BLOCK_SIZE * count);
      len -= count;
      in += AES_BLOCK_SIZE * count;
      out += AES_BLOCK_SIZE * count;
    }
  }

  void decrypt(Slice from, MutableSlice to) {
    CHECK(from.size() % AES_BLOCK_SIZE == 0);
    CHECK(to.size() >= from.size());
    auto len = to.size() / AES_BLOCK_SIZE;
    auto in = from.ubegin();
    auto out = to.ubegin();

    AesBlock encrypted;

    while (len) {
      encrypted.load(in);

      plaintext_iv_ ^= encrypted;
      evp_.decrypt(plaintext_iv_.raw(), plaintext_iv_.raw(), AES_BLOCK_SIZE);
      plaintext_iv_ ^= encrypted_iv_;

      plaintext_iv_.store(out);
      encrypted_iv_ = encrypted;

      --len;
      in += AES_BLOCK_SIZE;
      out += AES_BLOCK_SIZE;
    }
  }

 private:
  Evp evp_;
  AesBlock encrypted_iv_;
  AesBlock plaintext_iv_;
};

AesIgeState::AesIgeState() = default;
AesIgeState::AesIgeState(AesIgeState &&) noexcept = default;
AesIgeState &AesIgeState::operator=(AesIgeState &&) noexcept = default;
AesIgeState::~AesIgeState() = default;

void AesIgeState::init(Slice key, Slice iv, bool encrypt) {
  if (!impl_) {
    impl_ = make_unique<AesIgeStateImpl>();
  }

  impl_->init(key, iv, encrypt);
}

void AesIgeState::encrypt(Slice from, MutableSlice to) {
  impl_->encrypt(from, to);
}

void AesIgeState::decrypt(Slice from, MutableSlice to) {
  impl_->decrypt(from, to);
}

void aes_ige_encrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to) {
  AesIgeStateImpl state;
  state.init(aes_key, aes_iv, true);
  state.encrypt(from, to);
  state.get_iv(aes_iv);
}

void aes_ige_decrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to) {
  AesIgeStateImpl state;
  state.init(aes_key, aes_iv, false);
  state.decrypt(from, to);
  state.get_iv(aes_iv);
}

void aes_cbc_encrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to) {
  CHECK(from.size() <= to.size());
  CHECK(from.size() % 16 == 0);

  Evp evp;
  evp.init_encrypt_cbc(aes_key);
  evp.init_iv(aes_iv);
  evp.encrypt(from.ubegin(), to.ubegin(), narrow_cast<int>(from.size()));
  aes_iv.copy_from(to.substr(from.size() - 16));
}

void aes_cbc_decrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to) {
  CHECK(from.size() <= to.size());
  CHECK(from.size() % 16 == 0);

  Evp evp;
  evp.init_decrypt_cbc(aes_key);
  evp.init_iv(aes_iv);
  aes_iv.copy_from(from.substr(from.size() - 16));
  evp.decrypt(from.ubegin(), to.ubegin(), narrow_cast<int>(from.size()));
}

struct AesCbcState::Impl {
  Evp evp_;
};

AesCbcState::AesCbcState(Slice key256, Slice iv128) : raw_{SecureString(key256), SecureString(iv128)} {
  CHECK(raw_.key.size() == 32);
  CHECK(raw_.iv.size() == 16);
}

AesCbcState::AesCbcState(AesCbcState &&) noexcept = default;
AesCbcState &AesCbcState::operator=(AesCbcState &&) noexcept = default;
AesCbcState::~AesCbcState() = default;

void AesCbcState::encrypt(Slice from, MutableSlice to) {
  if (from.empty()) {
    return;
  }

  CHECK(from.size() <= to.size());
  CHECK(from.size() % 16 == 0);
  if (ctx_ == nullptr) {
    ctx_ = make_unique<AesCbcState::Impl>();
    ctx_->evp_.init_encrypt_cbc(raw_.key.as_slice());
    ctx_->evp_.init_iv(raw_.iv.as_slice());
    is_encrypt_ = true;
  } else {
    CHECK(is_encrypt_);
  }
  ctx_->evp_.encrypt(from.ubegin(), to.ubegin(), narrow_cast<int>(from.size()));
  raw_.iv.as_mutable_slice().copy_from(to.substr(from.size() - 16));
}

void AesCbcState::decrypt(Slice from, MutableSlice to) {
  if (from.empty()) {
    return;
  }

  CHECK(from.size() <= to.size());
  CHECK(from.size() % 16 == 0);
  if (ctx_ == nullptr) {
    ctx_ = make_unique<AesCbcState::Impl>();
    ctx_->evp_.init_decrypt_cbc(raw_.key.as_slice());
    ctx_->evp_.init_iv(raw_.iv.as_slice());
    is_encrypt_ = false;
  } else {
    CHECK(!is_encrypt_);
  }
  raw_.iv.as_mutable_slice().copy_from(from.substr(from.size() - 16));
  ctx_->evp_.decrypt(from.ubegin(), to.ubegin(), narrow_cast<int>(from.size()));
}

struct AesCtrState::Impl {
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  Evp evp_;
#else
  AES_KEY aes_key_;
  uint8 counter_[AES_BLOCK_SIZE];
  uint8 encrypted_counter_[AES_BLOCK_SIZE];
  uint8 current_pos_;
#endif
};

AesCtrState::AesCtrState() = default;
AesCtrState::AesCtrState(AesCtrState &&) noexcept = default;
AesCtrState &AesCtrState::operator=(AesCtrState &&) noexcept = default;
AesCtrState::~AesCtrState() = default;

void AesCtrState::init(Slice key, Slice iv) {
  CHECK(key.size() == 32);
  CHECK(iv.size() == 16);
  ctx_ = make_unique<AesCtrState::Impl>();
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  ctx_->evp_.init_encrypt_ctr(key);
  ctx_->evp_.init_iv(iv);
#else
  if (AES_set_encrypt_key(key.ubegin(), 256, &ctx_->aes_key_) < 0) {
    LOG(FATAL) << "Failed to set encrypt key";
  }
  MutableSlice(ctx_->counter_, AES_BLOCK_SIZE).copy_from(iv);
  ctx_->current_pos_ = 0;
#endif
}

void AesCtrState::encrypt(Slice from, MutableSlice to) {
  CHECK(from.size() <= to.size());
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  ctx_->evp_.encrypt(from.ubegin(), to.ubegin(), narrow_cast<int>(from.size()));
#else
  auto from_ptr = from.ubegin();
  auto to_ptr = to.ubegin();
  for (size_t i = 0; i < from.size(); i++) {
    if (ctx_->current_pos_ == 0) {
      AES_encrypt(ctx_->counter_, ctx_->encrypted_counter_, &ctx_->aes_key_);
      for (int j = 15; j >= 0; j--) {
        if (++ctx_->counter_[j] != 0) {
          break;
        }
      }
    }
    to_ptr[i] = static_cast<uint8>(from_ptr[i] ^ ctx_->encrypted_counter_[ctx_->current_pos_]);
    ctx_->current_pos_ = (ctx_->current_pos_ + 1) & 15;
  }
#endif
}

void AesCtrState::decrypt(Slice from, MutableSlice to) {
  encrypt(from, to);
}

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
static void make_digest(Slice data, MutableSlice output, const EVP_MD_CTX *evp_md_ctx) {
  static TD_THREAD_LOCAL EVP_MD_CTX *ctx;
  if (unlikely(ctx == nullptr)) {
    ctx = EVP_MD_CTX_new();
    LOG_IF(FATAL, ctx == nullptr);
    detail::add_thread_local_destructor(create_destructor([] {
      EVP_MD_CTX_free(ctx);
      ctx = nullptr;
    }));
  }
  int res = EVP_MD_CTX_copy_ex(ctx, evp_md_ctx);
  LOG_IF(FATAL, res != 1);
  res = EVP_DigestUpdate(ctx, data.ubegin(), data.size());
  LOG_IF(FATAL, res != 1);
  res = EVP_DigestFinal_ex(ctx, output.ubegin(), nullptr);
  LOG_IF(FATAL, res != 1);
  EVP_MD_CTX_reset(ctx);
}

static void init_thread_local_evp_md_ctx(const EVP_MD_CTX *&evp_md_ctx, const char *algorithm) {
  EVP_MD *evp_md = EVP_MD_fetch(nullptr, algorithm, nullptr);
  LOG_IF(FATAL, evp_md == nullptr);
  evp_md_ctx = EVP_MD_CTX_new();
  int res = EVP_DigestInit_ex(const_cast<EVP_MD_CTX *>(evp_md_ctx), evp_md, nullptr);
  LOG_IF(FATAL, res != 1);
  EVP_MD_free(evp_md);
  detail::add_thread_local_destructor(create_destructor([&evp_md_ctx]() mutable {
    EVP_MD_CTX_free(const_cast<EVP_MD_CTX *>(evp_md_ctx));
    evp_md_ctx = nullptr;
  }));
}
#endif

void sha1(Slice data, unsigned char output[20]) {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;
  if (unlikely(evp_md_ctx == nullptr)) {
    init_thread_local_evp_md_ctx(evp_md_ctx, "sha1");
  }
  make_digest(data, MutableSlice(output, 20), evp_md_ctx);
#else
  auto result = SHA1(data.ubegin(), data.size(), output);
  CHECK(result == output);
#endif
}

void sha256(Slice data, MutableSlice output) {
  CHECK(output.size() >= 32);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;
  if (unlikely(evp_md_ctx == nullptr)) {
    init_thread_local_evp_md_ctx(evp_md_ctx, "sha256");
  }
  make_digest(data, output, evp_md_ctx);
#else
  auto result = SHA256(data.ubegin(), data.size(), output.ubegin());
  CHECK(result == output.ubegin());
#endif
}

void sha512(Slice data, MutableSlice output) {
  CHECK(output.size() >= 64);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;
  if (unlikely(evp_md_ctx == nullptr)) {
    init_thread_local_evp_md_ctx(evp_md_ctx, "sha512");
  }
  make_digest(data, output, evp_md_ctx);
#else
  auto result = SHA512(data.ubegin(), data.size(), output.ubegin());
  CHECK(result == output.ubegin());
#endif
}

string sha1(Slice data) {
  string result(20, '\0');
  sha1(data, MutableSlice(result).ubegin());
  return result;
}

string sha256(Slice data) {
  string result(32, '\0');
  sha256(data, result);
  return result;
}

string sha512(Slice data) {
  string result(64, '\0');
  sha512(data, result);
  return result;
}

class Sha256State::Impl {
 public:
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  EVP_MD_CTX *ctx_;

  Impl() {
    ctx_ = EVP_MD_CTX_new();
    LOG_IF(FATAL, ctx_ == nullptr);
  }
  ~Impl() {
    CHECK(ctx_ != nullptr);
    EVP_MD_CTX_free(ctx_);
  }
#else
  SHA256_CTX ctx_;
  Impl() = default;
  ~Impl() = default;
#endif

  Impl(const Impl &) = delete;
  Impl &operator=(const Impl &) = delete;
  Impl(Impl &&) = delete;
  Impl &operator=(Impl &&) = delete;
};

Sha256State::Sha256State() = default;

Sha256State::Sha256State(Sha256State &&other) noexcept {
  impl_ = std::move(other.impl_);
  is_inited_ = other.is_inited_;
  other.is_inited_ = false;
}

Sha256State &Sha256State::operator=(Sha256State &&other) noexcept {
  Sha256State copy(std::move(other));
  using std::swap;
  swap(impl_, copy.impl_);
  swap(is_inited_, copy.is_inited_);
  return *this;
}

Sha256State::~Sha256State() {
  if (is_inited_) {
    char result[32];
    extract(MutableSlice{result, 32});
    CHECK(!is_inited_);
  }
}

void Sha256State::init() {
  if (!impl_) {
    impl_ = make_unique<Sha256State::Impl>();
  }
  CHECK(!is_inited_);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;
  if (unlikely(evp_md_ctx == nullptr)) {
    init_thread_local_evp_md_ctx(evp_md_ctx, "sha256");
  }
  int err = EVP_MD_CTX_copy_ex(impl_->ctx_, evp_md_ctx);
#else
  int err = SHA256_Init(&impl_->ctx_);
#endif
  LOG_IF(FATAL, err != 1);
  is_inited_ = true;
}

void Sha256State::feed(Slice data) {
  CHECK(impl_);
  CHECK(is_inited_);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  int err = EVP_DigestUpdate(impl_->ctx_, data.ubegin(), data.size());
#else
  int err = SHA256_Update(&impl_->ctx_, data.ubegin(), data.size());
#endif
  LOG_IF(FATAL, err != 1);
}

void Sha256State::extract(MutableSlice output, bool destroy) {
  CHECK(output.size() >= 32);
  CHECK(impl_);
  CHECK(is_inited_);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  int err = EVP_DigestFinal_ex(impl_->ctx_, output.ubegin(), nullptr);
#else
  int err = SHA256_Final(output.ubegin(), &impl_->ctx_);
#endif
  LOG_IF(FATAL, err != 1);
  is_inited_ = false;
  if (destroy) {
    impl_.reset();
  }
}

void md5(Slice input, MutableSlice output) {
  CHECK(output.size() >= 16);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;
  if (unlikely(evp_md_ctx == nullptr)) {
    init_thread_local_evp_md_ctx(evp_md_ctx, "md5");
  }
  make_digest(input, output, evp_md_ctx);
#else
  auto result = MD5(input.ubegin(), input.size(), output.ubegin());
  CHECK(result == output.ubegin());
#endif
}

static void pbkdf2_impl(Slice password, Slice salt, int iteration_count, MutableSlice dest, const EVP_MD *evp_md) {
  CHECK(evp_md != nullptr);
  int hash_size = EVP_MD_size(evp_md);
  CHECK(dest.size() == static_cast<size_t>(hash_size));
  CHECK(iteration_count > 0);
#if OPENSSL_VERSION_NUMBER < 0x10000000L
  HMAC_CTX ctx;
  HMAC_CTX_init(&ctx);
  unsigned char counter[4] = {0, 0, 0, 1};
  auto password_len = narrow_cast<int>(password.size());
  HMAC_Init_ex(&ctx, password.data(), password_len, evp_md, nullptr);
  HMAC_Update(&ctx, salt.ubegin(), narrow_cast<int>(salt.size()));
  HMAC_Update(&ctx, counter, 4);
  HMAC_Final(&ctx, dest.ubegin(), nullptr);
  HMAC_CTX_cleanup(&ctx);

  if (iteration_count > 1) {
    CHECK(hash_size <= 64);
    unsigned char buf[64];
    std::copy(dest.ubegin(), dest.uend(), buf);
    for (int iter = 1; iter < iteration_count; iter++) {
      if (HMAC(evp_md, password.data(), password_len, buf, hash_size, buf, nullptr) == nullptr) {
        LOG(FATAL) << "Failed to HMAC";
      }
      for (int i = 0; i < hash_size; i++) {
        dest[i] = static_cast<unsigned char>(dest[i] ^ buf[i]);
      }
    }
  }
#else
  int err = PKCS5_PBKDF2_HMAC(password.data(), narrow_cast<int>(password.size()), salt.ubegin(),
                              narrow_cast<int>(salt.size()), iteration_count, evp_md, narrow_cast<int>(dest.size()),
                              dest.ubegin());
  LOG_IF(FATAL, err != 1);
#endif
}

void pbkdf2_sha256(Slice password, Slice salt, int iteration_count, MutableSlice dest) {
  pbkdf2_impl(password, salt, iteration_count, dest, EVP_sha256());
}

void pbkdf2_sha512(Slice password, Slice salt, int iteration_count, MutableSlice dest) {
  pbkdf2_impl(password, salt, iteration_count, dest, EVP_sha512());
}

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
static void hmac_impl(const char *digest, Slice key, Slice message, MutableSlice dest) {
  EVP_MAC *hmac = EVP_MAC_fetch(nullptr, "HMAC", nullptr);
  LOG_IF(FATAL, hmac == nullptr);

  EVP_MAC_CTX *ctx = EVP_MAC_CTX_new(hmac);
  LOG_IF(FATAL, ctx == nullptr);

  OSSL_PARAM params[2];
  params[0] = OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST, const_cast<char *>(digest), 0);
  params[1] = OSSL_PARAM_construct_end();

  int res = EVP_MAC_init(ctx, const_cast<unsigned char *>(key.ubegin()), key.size(), params);
  LOG_IF(FATAL, res != 1);
  res = EVP_MAC_update(ctx, message.ubegin(), message.size());
  LOG_IF(FATAL, res != 1);
  res = EVP_MAC_final(ctx, dest.ubegin(), nullptr, dest.size());
  LOG_IF(FATAL, res != 1);

  EVP_MAC_CTX_free(ctx);
  EVP_MAC_free(hmac);
}
#else
static void hmac_impl(const EVP_MD *evp_md, Slice key, Slice message, MutableSlice dest) {
  unsigned int len = 0;
  auto result = HMAC(evp_md, key.ubegin(), narrow_cast<int>(key.size()), message.ubegin(),
                     narrow_cast<int>(message.size()), dest.ubegin(), &len);
  CHECK(result == dest.ubegin());
  CHECK(len == dest.size());
}
#endif

void hmac_sha256(Slice key, Slice message, MutableSlice dest) {
  CHECK(dest.size() == 256 / 8);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  hmac_impl("SHA256", key, message, dest);
#else
  hmac_impl(EVP_sha256(), key, message, dest);
#endif
}

void hmac_sha512(Slice key, Slice message, MutableSlice dest) {
  CHECK(dest.size() == 512 / 8);
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  hmac_impl("SHA512", key, message, dest);
#else
  hmac_impl(EVP_sha512(), key, message, dest);
#endif
}

static int get_evp_pkey_type(EVP_PKEY *pkey) {
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  return EVP_PKEY_type(pkey->type);
#else
  return EVP_PKEY_base_id(pkey);
#endif
}

Result<BufferSlice> rsa_encrypt_pkcs1_oaep(Slice public_key, Slice data) {
  BIO *mem_bio = BIO_new_mem_buf(const_cast<void *>(static_cast<const void *>(public_key.data())),
                                 narrow_cast<int>(public_key.size()));
  SCOPE_EXIT {
    BIO_vfree(mem_bio);
  };

  EVP_PKEY *pkey = PEM_read_bio_PUBKEY(mem_bio, nullptr, nullptr, nullptr);
  if (!pkey) {
    return Status::Error("Cannot read public key");
  }
  SCOPE_EXIT {
    EVP_PKEY_free(pkey);
  };
  if (get_evp_pkey_type(pkey) != EVP_PKEY_RSA) {
    return Status::Error("Wrong key type, expected RSA");
  }

#if OPENSSL_VERSION_NUMBER < 0x10000000L
  RSA *rsa = pkey->pkey.rsa;
  int outlen = RSA_size(rsa);
  BufferSlice res(outlen);
  if (RSA_public_encrypt(narrow_cast<int>(data.size()), const_cast<unsigned char *>(data.ubegin()),
                         res.as_mutable_slice().ubegin(), rsa, RSA_PKCS1_OAEP_PADDING) != outlen) {
#else
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(pkey, nullptr);
  if (!ctx) {
    return Status::Error("Cannot create EVP_PKEY_CTX");
  }
  SCOPE_EXIT {
    EVP_PKEY_CTX_free(ctx);
  };

  if (EVP_PKEY_encrypt_init(ctx) <= 0) {
    return Status::Error("Cannot init EVP_PKEY_CTX");
  }
  if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
    return Status::Error("Cannot set RSA_PKCS1_OAEP padding in EVP_PKEY_CTX");
  }

  size_t outlen;
  if (EVP_PKEY_encrypt(ctx, nullptr, &outlen, data.ubegin(), data.size()) <= 0) {
    return Status::Error("Cannot calculate encrypted length");
  }
  BufferSlice res(outlen);
  if (EVP_PKEY_encrypt(ctx, res.as_mutable_slice().ubegin(), &outlen, data.ubegin(), data.size()) <= 0) {
#endif
    return Status::Error("Cannot encrypt");
  }
  return std::move(res);
}

Result<BufferSlice> rsa_decrypt_pkcs1_oaep(Slice private_key, Slice data) {
  BIO *mem_bio = BIO_new_mem_buf(const_cast<void *>(static_cast<const void *>(private_key.data())),
                                 narrow_cast<int>(private_key.size()));
  SCOPE_EXIT {
    BIO_vfree(mem_bio);
  };

  EVP_PKEY *pkey = PEM_read_bio_PrivateKey(mem_bio, nullptr, nullptr, nullptr);
  if (!pkey) {
    return Status::Error("Cannot read private key");
  }
  SCOPE_EXIT {
    EVP_PKEY_free(pkey);
  };
  if (get_evp_pkey_type(pkey) != EVP_PKEY_RSA) {
    return Status::Error("Wrong key type, expected RSA");
  }

#if OPENSSL_VERSION_NUMBER < 0x10000000L
  RSA *rsa = pkey->pkey.rsa;
  size_t outlen = RSA_size(rsa);
  BufferSlice res(outlen);
  auto inlen = RSA_private_decrypt(narrow_cast<int>(data.size()), const_cast<unsigned char *>(data.ubegin()),
                                   res.as_mutable_slice().ubegin(), rsa, RSA_PKCS1_OAEP_PADDING);
  if (inlen == -1) {
    return Status::Error("Cannot decrypt");
  }
  res.truncate(inlen);
#else
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(pkey, nullptr);
  if (!ctx) {
    return Status::Error("Cannot create EVP_PKEY_CTX");
  }
  SCOPE_EXIT {
    EVP_PKEY_CTX_free(ctx);
  };

  if (EVP_PKEY_decrypt_init(ctx) <= 0) {
    return Status::Error("Cannot init EVP_PKEY_CTX");
  }
  if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
    return Status::Error("Cannot set RSA_PKCS1_OAEP padding in EVP_PKEY_CTX");
  }

  size_t outlen;
  if (EVP_PKEY_decrypt(ctx, nullptr, &outlen, data.ubegin(), data.size()) <= 0) {
    return Status::Error("Cannot calculate decrypted length");
  }
  BufferSlice res(outlen);
  if (EVP_PKEY_decrypt(ctx, res.as_mutable_slice().ubegin(), &outlen, data.ubegin(), data.size()) <= 0) {
    return Status::Error("Cannot decrypt");
  }
#endif
  return std::move(res);
}

#if OPENSSL_VERSION_NUMBER < 0x10100000L
namespace {
std::vector<RwMutex> &openssl_mutexes() {
  static std::vector<RwMutex> mutexes(CRYPTO_num_locks());
  return mutexes;
}

#if OPENSSL_VERSION_NUMBER >= 0x10000000L
void openssl_threadid_callback(CRYPTO_THREADID *thread_id) {
  static TD_THREAD_LOCAL int id;
  CRYPTO_THREADID_set_pointer(thread_id, &id);
}
#endif

void openssl_locking_function(int mode, int n, const char *file, int line) {
  auto &mutexes = openssl_mutexes();
  if (mode & CRYPTO_LOCK) {
    if (mode & CRYPTO_READ) {
      mutexes[n].lock_read_unsafe();
    } else {
      mutexes[n].lock_write_unsafe();
    }
  } else {
    if (mode & CRYPTO_READ) {
      mutexes[n].unlock_read_unsafe();
    } else {
      mutexes[n].unlock_write_unsafe();
    }
  }
}
}  // namespace
#endif

void init_openssl_threads() {
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  static std::mutex init_mutex;
  std::lock_guard<std::mutex> lock(init_mutex);
  if (CRYPTO_get_locking_callback() == nullptr) {
#if OPENSSL_VERSION_NUMBER >= 0x10000000L
    CRYPTO_THREADID_set_callback(openssl_threadid_callback);
#endif
    CRYPTO_set_locking_callback(openssl_locking_function);
  }
#endif
}

Status create_openssl_error(int code, Slice message) {
  const int max_result_size = 1 << 12;
  auto result = StackAllocator::alloc(max_result_size);
  StringBuilder sb(result.as_slice());

  sb << message;
  while (unsigned long error_code = ERR_get_error()) {
    char error_buf[1024];
    ERR_error_string_n(error_code, error_buf, sizeof(error_buf));
    Slice error(error_buf, std::strlen(error_buf));
    sb << "{" << error << "}";
  }
  LOG_IF(ERROR, sb.is_error()) << "OpenSSL error buffer overflow";
  LOG(DEBUG) << sb.as_cslice();
  return Status::Error(code, sb.as_cslice());
}

void clear_openssl_errors(Slice source) {
  if (ERR_peek_error() != 0) {
    auto error = create_openssl_error(0, "Unprocessed OPENSSL_ERROR");
    if (!ends_with(error.message(), ":def_load:system lib}")) {
      LOG(ERROR) << source << ": " << error;
    }
  }
#if TD_PORT_WINDOWS
  WSASetLastError(0);
#else
  errno = 0;
#endif
}

#endif

#if TD_HAVE_ZLIB
uint32 crc32(Slice data) {
  return static_cast<uint32>(::crc32(0, data.ubegin(), static_cast<uint32>(data.size())));
}
#endif

#if TD_HAVE_CRC32C
uint32 crc32c(Slice data) {
  return crc32c::Crc32c(data.data(), data.size());
}

uint32 crc32c_extend(uint32 old_crc, Slice data) {
  return crc32c::Extend(old_crc, data.ubegin(), data.size());
}

namespace {

uint32 gf32_matrix_times(const uint32 *matrix, uint32 vector) {
  uint32 sum = 0;
  while (vector) {
    if (vector & 1) {
      sum ^= *matrix;
    }
    vector >>= 1;
    matrix++;
  }
  return sum;
}

void gf32_matrix_square(uint32 *square, const uint32 *matrix) {
  for (int n = 0; n < 32; n++) {
    square[n] = gf32_matrix_times(matrix, matrix[n]);
  }
}

}  // namespace

uint32 crc32c_extend(uint32 old_crc, uint32 data_crc, size_t data_size) {
  static uint32 power_buf_raw[1024];
  static const uint32 *power_buf = [&] {
    auto *buf = power_buf_raw;
    buf[0] = 0x82F63B78u;
    for (int n = 0; n < 31; n++) {
      buf[n + 1] = 1u << n;
    }
    for (int n = 1; n < 32; n++) {
      gf32_matrix_square(buf + (n << 5), buf + ((n - 1) << 5));
    }
    return buf;
  }();

  if (data_size == 0) {
    return old_crc;
  }

  const uint32 *p = power_buf + 64;
  do {
    p += 32;
    if (data_size & 1) {
      old_crc = gf32_matrix_times(p, old_crc);
    }
    data_size >>= 1;
  } while (data_size != 0);
  return old_crc ^ data_crc;
}

#endif

static const uint64 crc64_table[256] = {
    0x0000000000000000, 0xb32e4cbe03a75f6f, 0xf4843657a840a05b, 0x47aa7ae9abe7ff34, 0x7bd0c384ff8f5e33,
    0xc8fe8f3afc28015c, 0x8f54f5d357cffe68, 0x3c7ab96d5468a107, 0xf7a18709ff1ebc66, 0x448fcbb7fcb9e309,
    0x0325b15e575e1c3d, 0xb00bfde054f94352, 0x8c71448d0091e255, 0x3f5f08330336bd3a, 0x78f572daa8d1420e,
    0xcbdb3e64ab761d61, 0x7d9ba13851336649, 0xceb5ed8652943926, 0x891f976ff973c612, 0x3a31dbd1fad4997d,
    0x064b62bcaebc387a, 0xb5652e02ad1b6715, 0xf2cf54eb06fc9821, 0x41e11855055bc74e, 0x8a3a2631ae2dda2f,
    0x39146a8fad8a8540, 0x7ebe1066066d7a74, 0xcd905cd805ca251b, 0xf1eae5b551a2841c, 0x42c4a90b5205db73,
    0x056ed3e2f9e22447, 0xb6409f5cfa457b28, 0xfb374270a266cc92, 0x48190ecea1c193fd, 0x0fb374270a266cc9,
    0xbc9d3899098133a6, 0x80e781f45de992a1, 0x33c9cd4a5e4ecdce, 0x7463b7a3f5a932fa, 0xc74dfb1df60e6d95,
    0x0c96c5795d7870f4, 0xbfb889c75edf2f9b, 0xf812f32ef538d0af, 0x4b3cbf90f69f8fc0, 0x774606fda2f72ec7,
    0xc4684a43a15071a8, 0x83c230aa0ab78e9c, 0x30ec7c140910d1f3, 0x86ace348f355aadb, 0x3582aff6f0f2f5b4,
    0x7228d51f5b150a80, 0xc10699a158b255ef, 0xfd7c20cc0cdaf4e8, 0x4e526c720f7dab87, 0x09f8169ba49a54b3,
    0xbad65a25a73d0bdc, 0x710d64410c4b16bd, 0xc22328ff0fec49d2, 0x85895216a40bb6e6, 0x36a71ea8a7ace989,
    0x0adda7c5f3c4488e, 0xb9f3eb7bf06317e1, 0xfe5991925b84e8d5, 0x4d77dd2c5823b7ba, 0x64b62bcaebc387a1,
    0xd7986774e864d8ce, 0x90321d9d438327fa, 0x231c512340247895, 0x1f66e84e144cd992, 0xac48a4f017eb86fd,
    0xebe2de19bc0c79c9, 0x58cc92a7bfab26a6, 0x9317acc314dd3bc7, 0x2039e07d177a64a8, 0x67939a94bc9d9b9c,
    0xd4bdd62abf3ac4f3, 0xe8c76f47eb5265f4, 0x5be923f9e8f53a9b, 0x1c4359104312c5af, 0xaf6d15ae40b59ac0,
    0x192d8af2baf0e1e8, 0xaa03c64cb957be87, 0xeda9bca512b041b3, 0x5e87f01b11171edc, 0x62fd4976457fbfdb,
    0xd1d305c846d8e0b4, 0x96797f21ed3f1f80, 0x2557339fee9840ef, 0xee8c0dfb45ee5d8e, 0x5da24145464902e1,
    0x1a083bacedaefdd5, 0xa9267712ee09a2ba, 0x955cce7fba6103bd, 0x267282c1b9c65cd2, 0x61d8f8281221a3e6,
    0xd2f6b4961186fc89, 0x9f8169ba49a54b33, 0x2caf25044a02145c, 0x6b055fede1e5eb68, 0xd82b1353e242b407,
    0xe451aa3eb62a1500, 0x577fe680b58d4a6f, 0x10d59c691e6ab55b, 0xa3fbd0d71dcdea34, 0x6820eeb3b6bbf755,
    0xdb0ea20db51ca83a, 0x9ca4d8e41efb570e, 0x2f8a945a1d5c0861, 0x13f02d374934a966, 0xa0de61894a93f609,
    0xe7741b60e174093d, 0x545a57dee2d35652, 0xe21ac88218962d7a, 0x5134843c1b317215, 0x169efed5b0d68d21,
    0xa5b0b26bb371d24e, 0x99ca0b06e7197349, 0x2ae447b8e4be2c26, 0x6d4e3d514f59d312, 0xde6071ef4cfe8c7d,
    0x15bb4f8be788911c, 0xa6950335e42fce73, 0xe13f79dc4fc83147, 0x521135624c6f6e28, 0x6e6b8c0f1807cf2f,
    0xdd45c0b11ba09040, 0x9aefba58b0476f74, 0x29c1f6e6b3e0301b, 0xc96c5795d7870f42, 0x7a421b2bd420502d,
    0x3de861c27fc7af19, 0x8ec62d7c7c60f076, 0xb2bc941128085171, 0x0192d8af2baf0e1e, 0x4638a2468048f12a,
    0xf516eef883efae45, 0x3ecdd09c2899b324, 0x8de39c222b3eec4b, 0xca49e6cb80d9137f, 0x7967aa75837e4c10,
    0x451d1318d716ed17, 0xf6335fa6d4b1b278, 0xb199254f7f564d4c, 0x02b769f17cf11223, 0xb4f7f6ad86b4690b,
    0x07d9ba1385133664, 0x4073c0fa2ef4c950, 0xf35d8c442d53963f, 0xcf273529793b3738, 0x7c0979977a9c6857,
    0x3ba3037ed17b9763, 0x888d4fc0d2dcc80c, 0x435671a479aad56d, 0xf0783d1a7a0d8a02, 0xb7d247f3d1ea7536,
    0x04fc0b4dd24d2a59, 0x3886b22086258b5e, 0x8ba8fe9e8582d431, 0xcc0284772e652b05, 0x7f2cc8c92dc2746a,
    0x325b15e575e1c3d0, 0x8175595b76469cbf, 0xc6df23b2dda1638b, 0x75f16f0cde063ce4, 0x498bd6618a6e9de3,
    0xfaa59adf89c9c28c, 0xbd0fe036222e3db8, 0x0e21ac88218962d7, 0xc5fa92ec8aff7fb6, 0x76d4de52895820d9,
    0x317ea4bb22bfdfed, 0x8250e80521188082, 0xbe2a516875702185, 0x0d041dd676d77eea, 0x4aae673fdd3081de,
    0xf9802b81de97deb1, 0x4fc0b4dd24d2a599, 0xfceef8632775faf6, 0xbb44828a8c9205c2, 0x086ace348f355aad,
    0x34107759db5dfbaa, 0x873e3be7d8faa4c5, 0xc094410e731d5bf1, 0x73ba0db070ba049e, 0xb86133d4dbcc19ff,
    0x0b4f7f6ad86b4690, 0x4ce50583738cb9a4, 0xffcb493d702be6cb, 0xc3b1f050244347cc, 0x709fbcee27e418a3,
    0x3735c6078c03e797, 0x841b8ab98fa4b8f8, 0xadda7c5f3c4488e3, 0x1ef430e13fe3d78c, 0x595e4a08940428b8,
    0xea7006b697a377d7, 0xd60abfdbc3cbd6d0, 0x6524f365c06c89bf, 0x228e898c6b8b768b, 0x91a0c532682c29e4,
    0x5a7bfb56c35a3485, 0xe955b7e8c0fd6bea, 0xaeffcd016b1a94de, 0x1dd181bf68bdcbb1, 0x21ab38d23cd56ab6,
    0x9285746c3f7235d9, 0xd52f0e859495caed, 0x6601423b97329582, 0xd041dd676d77eeaa, 0x636f91d96ed0b1c5,
    0x24c5eb30c5374ef1, 0x97eba78ec690119e, 0xab911ee392f8b099, 0x18bf525d915feff6, 0x5f1528b43ab810c2,
    0xec3b640a391f4fad, 0x27e05a6e926952cc, 0x94ce16d091ce0da3, 0xd3646c393a29f297, 0x604a2087398eadf8,
    0x5c3099ea6de60cff, 0xef1ed5546e415390, 0xa8b4afbdc5a6aca4, 0x1b9ae303c601f3cb, 0x56ed3e2f9e224471,
    0xe5c372919d851b1e, 0xa26908783662e42a, 0x114744c635c5bb45, 0x2d3dfdab61ad1a42, 0x9e13b115620a452d,
    0xd9b9cbfcc9edba19, 0x6a978742ca4ae576, 0xa14cb926613cf817, 0x1262f598629ba778, 0x55c88f71c97c584c,
    0xe6e6c3cfcadb0723, 0xda9c7aa29eb3a624, 0x69b2361c9d14f94b, 0x2e184cf536f3067f, 0x9d36004b35545910,
    0x2b769f17cf112238, 0x9858d3a9ccb67d57, 0xdff2a94067518263, 0x6cdce5fe64f6dd0c, 0x50a65c93309e7c0b,
    0xe388102d33392364, 0xa4226ac498dedc50, 0x170c267a9b79833f, 0xdcd7181e300f9e5e, 0x6ff954a033a8c131,
    0x28532e49984f3e05, 0x9b7d62f79be8616a, 0xa707db9acf80c06d, 0x14299724cc279f02, 0x5383edcd67c06036,
    0xe0ada17364673f59};

static uint64 crc64_partial(Slice data, uint64 crc) {
  const char *p = data.begin();
  for (auto len = data.size(); len > 0; len--) {
    crc = crc64_table[(crc ^ *p++) & 0xff] ^ (crc >> 8);
  }
  return crc;
}

uint64 crc64(Slice data) {
  return crc64_partial(data, static_cast<uint64>(-1)) ^ static_cast<uint64>(-1);
}

static const uint16 crc16_table[256] = {
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad,
    0xe1ce, 0xf1ef, 0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6, 0x9339, 0x8318, 0xb37b, 0xa35a,
    0xd3bd, 0xc39c, 0xf3ff, 0xe3de, 0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485, 0xa56a, 0xb54b,
    0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d, 0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc, 0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861,
    0x2802, 0x3823, 0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b, 0x5af5, 0x4ad4, 0x7ab7, 0x6a96,
    0x1a71, 0x0a50, 0x3a33, 0x2a12, 0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a, 0x6ca6, 0x7c87,
    0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41, 0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70, 0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a,
    0x9f59, 0x8f78, 0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f, 0x1080, 0x00a1, 0x30c2, 0x20e3,
    0x5004, 0x4025, 0x7046, 0x6067, 0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e, 0x02b1, 0x1290,
    0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256, 0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e,
    0xc71d, 0xd73c, 0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634, 0xd94c, 0xc96d, 0xf90e, 0xe92f,
    0x99c8, 0x89e9, 0xb98a, 0xa9ab, 0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3, 0xcb7d, 0xdb5c,
    0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a, 0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9, 0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83,
    0x1ce0, 0x0cc1, 0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8, 0x6e17, 0x7e36, 0x4e55, 0x5e74,
    0x2e93, 0x3eb2, 0x0ed1, 0x1ef0};

uint16 crc16(Slice data) {
  uint32 crc = 0;
  for (auto c : data) {
    auto t = (static_cast<unsigned char>(c) ^ (crc >> 8)) & 0xff;
    crc = crc16_table[t] ^ (crc << 8);
  }
  return static_cast<uint16>(crc);
}

}  // namespace td
