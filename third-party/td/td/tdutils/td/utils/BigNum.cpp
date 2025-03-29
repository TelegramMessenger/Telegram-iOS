//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/BigNum.h"

char disable_linker_warning_about_empty_file_bignum_cpp TD_UNUSED;

#if TD_HAVE_OPENSSL

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

#include <openssl/bn.h>
#include <openssl/crypto.h>

#include <algorithm>

namespace td {

class BigNumContext::Impl {
 public:
  BN_CTX *big_num_context;

  Impl() : big_num_context(BN_CTX_new()) {
    LOG_IF(FATAL, big_num_context == nullptr);
  }
  Impl(const Impl &) = delete;
  Impl &operator=(const Impl &) = delete;
  Impl(Impl &&) = delete;
  Impl &operator=(Impl &&) = delete;
  ~Impl() {
    BN_CTX_free(big_num_context);
  }
};

BigNumContext::BigNumContext() : impl_(make_unique<Impl>()) {
}

BigNumContext::BigNumContext(BigNumContext &&) noexcept = default;
BigNumContext &BigNumContext::operator=(BigNumContext &&) noexcept = default;
BigNumContext::~BigNumContext() = default;

class BigNum::Impl {
 public:
  BIGNUM *big_num;

  Impl() : Impl(BN_new()) {
  }
  explicit Impl(BIGNUM *big_num) : big_num(big_num) {
    LOG_IF(FATAL, big_num == nullptr);
  }
  Impl(const Impl &) = delete;
  Impl &operator=(const Impl &) = delete;
  Impl(Impl &&) = delete;
  Impl &operator=(Impl &&) = delete;
  ~Impl() {
    BN_clear_free(big_num);
  }
};

BigNum::BigNum() : impl_(make_unique<Impl>()) {
}

BigNum::BigNum(const BigNum &other) : BigNum() {
  *this = other;
}

BigNum &BigNum::operator=(const BigNum &other) {
  if (this == &other) {
    return *this;
  }
  CHECK(impl_ != nullptr);
  CHECK(other.impl_ != nullptr);
  BIGNUM *result = BN_copy(impl_->big_num, other.impl_->big_num);
  LOG_IF(FATAL, result == nullptr);
  return *this;
}

BigNum::BigNum(BigNum &&) noexcept = default;
BigNum &BigNum::operator=(BigNum &&) noexcept = default;
BigNum::~BigNum() = default;

BigNum BigNum::from_binary(Slice str) {
  return BigNum(make_unique<Impl>(BN_bin2bn(str.ubegin(), narrow_cast<int>(str.size()), nullptr)));
}

BigNum BigNum::from_le_binary(Slice str) {
#if defined(OPENSSL_IS_BORINGSSL)
  return BigNum(make_unique<Impl>(BN_le2bn(str.ubegin(), narrow_cast<int>(str.size()), nullptr)));
#elif OPENSSL_VERSION_NUMBER >= 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)
  return BigNum(make_unique<Impl>(BN_lebin2bn(str.ubegin(), narrow_cast<int>(str.size()), nullptr)));
#else
  string str_copy = str.str();
  std::reverse(str_copy.begin(), str_copy.end());
  return from_binary(str_copy);
#endif
}

Result<BigNum> BigNum::from_decimal(CSlice str) {
  BigNum result;
  int res = BN_dec2bn(&result.impl_->big_num, str.c_str());
  if (res == 0 || static_cast<size_t>(res) != str.size()) {
    return Status::Error(PSLICE() << "Failed to parse \"" << str << "\" as BigNum");
  }
  return result;
}

Result<BigNum> BigNum::from_hex(CSlice str) {
  BigNum result;
  int res = BN_hex2bn(&result.impl_->big_num, str.c_str());
  if (res == 0 || static_cast<size_t>(res) != str.size()) {
    return Status::Error(PSLICE() << "Failed to parse \"" << str << "\" as hexadecimal BigNum");
  }
  return result;
}

BigNum BigNum::from_raw(void *openssl_big_num) {
  return BigNum(make_unique<Impl>(static_cast<BIGNUM *>(openssl_big_num)));
}

BigNum::BigNum(unique_ptr<Impl> &&impl) : impl_(std::move(impl)) {
}

int BigNum::get_num_bits() const {
  return BN_num_bits(impl_->big_num);
}

int BigNum::get_num_bytes() const {
  return BN_num_bytes(impl_->big_num);
}

void BigNum::set_bit(int num) {
  int result = BN_set_bit(impl_->big_num, num);
  LOG_IF(FATAL, result != 1);
}

void BigNum::clear_bit(int num) {
  int result = BN_clear_bit(impl_->big_num, num);
  LOG_IF(FATAL, result != 1);
}

bool BigNum::is_bit_set(int num) const {
  return BN_is_bit_set(impl_->big_num, num) != 0;
}

bool BigNum::is_prime(BigNumContext &context) const {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  int result = BN_check_prime(impl_->big_num, context.impl_->big_num_context, nullptr);
#else
  int result =
      BN_is_prime_ex(impl_->big_num, get_num_bits() > 2048 ? 128 : 64, context.impl_->big_num_context, nullptr);
#endif
  LOG_IF(FATAL, result == -1);
  return result == 1;
}

void BigNum::operator+=(uint32 value) {
  int result = BN_add_word(impl_->big_num, value);
  LOG_IF(FATAL, result != 1);
}

void BigNum::operator-=(uint32 value) {
  int result = BN_sub_word(impl_->big_num, value);
  LOG_IF(FATAL, result != 1);
}

void BigNum::operator*=(uint32 value) {
  int result = BN_mul_word(impl_->big_num, value);
  LOG_IF(FATAL, result != 1);
}

void BigNum::operator/=(uint32 value) {
  BN_ULONG result = BN_div_word(impl_->big_num, value);
  LOG_IF(FATAL, result == static_cast<BN_ULONG>(-1));
}

uint32 BigNum::operator%(uint32 value) const {
  BN_ULONG result = BN_mod_word(impl_->big_num, value);
  LOG_IF(FATAL, result == static_cast<BN_ULONG>(-1));
  return narrow_cast<uint32>(result);
}

void BigNum::set_value(uint32 new_value) {
  if (new_value == 0) {
    BN_zero(impl_->big_num);
  } else {
    int result = BN_set_word(impl_->big_num, new_value);
    LOG_IF(FATAL, result != 1);
  }
}

BigNum BigNum::clone() const {
  BIGNUM *result = BN_dup(impl_->big_num);
  LOG_IF(FATAL, result == nullptr);
  return BigNum(make_unique<Impl>(result));
}

string BigNum::to_binary(int exact_size) const {
  int num_size = get_num_bytes();
  if (exact_size == -1) {
    exact_size = num_size;
  } else {
    CHECK(exact_size >= num_size);
  }
  string res(exact_size, '\0');
  BN_bn2bin(impl_->big_num, MutableSlice(res).ubegin() + (exact_size - num_size));
  return res;
}

string BigNum::to_le_binary(int exact_size) const {
#if OPENSSL_VERSION_NUMBER >= 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER) || defined(OPENSSL_IS_BORINGSSL)
  int num_size = get_num_bytes();
  if (exact_size == -1) {
    exact_size = num_size;
  } else {
    CHECK(exact_size >= num_size);
  }
  string result(exact_size, '\0');
#if defined(OPENSSL_IS_BORINGSSL)
  BN_bn2le_padded(MutableSlice(result).ubegin(), exact_size, impl_->big_num);
#else
  BN_bn2lebinpad(impl_->big_num, MutableSlice(result).ubegin(), exact_size);
#endif
  return result;
#else
  string result = to_binary(exact_size);
  std::reverse(result.begin(), result.end());
  return result;
#endif
}

string BigNum::to_decimal() const {
  char *result = BN_bn2dec(impl_->big_num);
  CHECK(result != nullptr);
  string res(result);
  OPENSSL_free(result);
  return res;
}

void BigNum::random(BigNum &r, int bits, int top, int bottom) {
  int result = BN_rand(r.impl_->big_num, bits, top, bottom);
  LOG_IF(FATAL, result != 1);
}

void BigNum::add(BigNum &r, const BigNum &a, const BigNum &b) {
  int result = BN_add(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num);
  LOG_IF(FATAL, result != 1);
}

void BigNum::sub(BigNum &r, const BigNum &a, const BigNum &b) {
  CHECK(r.impl_->big_num != a.impl_->big_num);
  CHECK(r.impl_->big_num != b.impl_->big_num);
  int result = BN_sub(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mul(BigNum &r, BigNum &a, BigNum &b, BigNumContext &context) {
  int result = BN_mul(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num, context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mod_add(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context) {
  int result = BN_mod_add(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num, m.impl_->big_num,
                          context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mod_sub(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context) {
  int result = BN_mod_sub(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num, m.impl_->big_num,
                          context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mod_mul(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context) {
  int result = BN_mod_mul(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num, m.impl_->big_num,
                          context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mod_inverse(BigNum &r, BigNum &a, const BigNum &m, BigNumContext &context) {
  auto result = BN_mod_inverse(r.impl_->big_num, a.impl_->big_num, m.impl_->big_num, context.impl_->big_num_context);
  LOG_IF(FATAL, result != r.impl_->big_num);
}

void BigNum::div(BigNum *quotient, BigNum *remainder, const BigNum &dividend, const BigNum &divisor,
                 BigNumContext &context) {
  auto q = quotient == nullptr ? nullptr : quotient->impl_->big_num;
  auto r = remainder == nullptr ? nullptr : remainder->impl_->big_num;
  if (q == nullptr && r == nullptr) {
    return;
  }

  auto result = BN_div(q, r, dividend.impl_->big_num, divisor.impl_->big_num, context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::mod_exp(BigNum &r, const BigNum &a, const BigNum &p, const BigNum &m, BigNumContext &context) {
  int result = BN_mod_exp(r.impl_->big_num, a.impl_->big_num, p.impl_->big_num, m.impl_->big_num,
                          context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

void BigNum::gcd(BigNum &r, BigNum &a, BigNum &b, BigNumContext &context) {
  int result = BN_gcd(r.impl_->big_num, a.impl_->big_num, b.impl_->big_num, context.impl_->big_num_context);
  LOG_IF(FATAL, result != 1);
}

int BigNum::compare(const BigNum &a, const BigNum &b) {
  return BN_cmp(a.impl_->big_num, b.impl_->big_num);
}

StringBuilder &operator<<(StringBuilder &sb, const BigNum &bn) {
  return sb << bn.to_decimal();
}

}  // namespace td
#endif
