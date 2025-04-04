//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#if TD_HAVE_OPENSSL

#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class BigNumContext {
 public:
  BigNumContext();
  BigNumContext(const BigNumContext &) = delete;
  BigNumContext &operator=(const BigNumContext &) = delete;
  BigNumContext(BigNumContext &&other) noexcept;
  BigNumContext &operator=(BigNumContext &&other) noexcept;
  ~BigNumContext();

 private:
  class Impl;
  unique_ptr<Impl> impl_;

  friend class BigNum;
};

class BigNum {
 public:
  BigNum();
  BigNum(const BigNum &other);
  BigNum &operator=(const BigNum &other);
  BigNum(BigNum &&other) noexcept;
  BigNum &operator=(BigNum &&other) noexcept;
  ~BigNum();

  static BigNum from_binary(Slice str);

  static BigNum from_le_binary(Slice str);

  static Result<BigNum> from_decimal(CSlice str);

  static Result<BigNum> from_hex(CSlice str);

  static BigNum from_raw(void *openssl_big_num);

  void set_value(uint32 new_value);

  int get_num_bits() const;

  int get_num_bytes() const;

  void set_bit(int num);

  void clear_bit(int num);

  bool is_bit_set(int num) const;

  bool is_prime(BigNumContext &context) const;

  BigNum clone() const;

  string to_binary(int exact_size = -1) const;

  string to_le_binary(int exact_size = -1) const;

  string to_decimal() const;

  void operator+=(uint32 value);

  void operator-=(uint32 value);

  void operator*=(uint32 value);

  void operator/=(uint32 value);

  uint32 operator%(uint32 value) const;

  static void random(BigNum &r, int bits, int top, int bottom);

  static void add(BigNum &r, const BigNum &a, const BigNum &b);

  static void sub(BigNum &r, const BigNum &a, const BigNum &b);

  static void mul(BigNum &r, BigNum &a, BigNum &b, BigNumContext &context);

  static void mod_add(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context);

  static void mod_sub(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context);

  static void mod_mul(BigNum &r, BigNum &a, BigNum &b, const BigNum &m, BigNumContext &context);

  static void mod_inverse(BigNum &r, BigNum &a, const BigNum &m, BigNumContext &context);

  static void div(BigNum *quotient, BigNum *remainder, const BigNum &dividend, const BigNum &divisor,
                  BigNumContext &context);

  static void mod_exp(BigNum &r, const BigNum &a, const BigNum &p, const BigNum &m, BigNumContext &context);

  static void gcd(BigNum &r, BigNum &a, BigNum &b, BigNumContext &context);

  static int compare(const BigNum &a, const BigNum &b);

 private:
  class Impl;
  unique_ptr<Impl> impl_;

  explicit BigNum(unique_ptr<Impl> &&impl);
};

StringBuilder &operator<<(StringBuilder &sb, const BigNum &bn);

}  // namespace td

#endif
