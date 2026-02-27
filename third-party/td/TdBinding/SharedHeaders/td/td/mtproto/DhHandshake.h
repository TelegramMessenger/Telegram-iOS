//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/BigNum.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {
namespace mtproto {

class DhCallback;

class DhHandshake {
 public:
  void set_config(int32 g_int, Slice prime_str);

  static Status check_config(int32 g_int, Slice prime_str, DhCallback *callback);

  bool has_config() const {
    return has_config_;
  }
  void set_g_a_hash(Slice g_a_hash);
  void set_g_a(Slice g_a_str);
  bool has_g_a() const {
    return has_g_a_;
  }
  string get_g_a() const;
  string get_g_b() const;
  string get_g_b_hash() const;
  Status run_checks(bool skip_config_check, DhCallback *callback) TD_WARN_UNUSED_RESULT;

  BigNum get_g() const;
  BigNum get_p() const;
  BigNum get_b() const;
  BigNum get_g_ab();

  std::pair<int64, string> gen_key();

  static int64 calc_key_id(Slice auth_key);

  enum Flags { HasConfig = 1, HasGA = 2 };

  template <class StorerT>
  void store(StorerT &storer) const {
    auto flags = 0;
    if (has_config_) {
      flags |= HasConfig;
    }
    if (has_g_a_) {
      flags |= HasGA;
    }
    storer.store_int(flags);

    if (has_config_) {
      // prime_, prime_str_, b_, g_, g_int_, g_b_
      storer.store_string(prime_str_);
      storer.store_string(b_.to_binary());
      storer.store_int(g_int_);
      storer.store_string(g_b_.to_binary());
    }
    if (has_g_a_) {
      storer.store_string(g_a_.to_binary());
    }
  }
  template <class ParserT>
  void parse(ParserT &parser) {
    auto flags = parser.fetch_int();
    if (flags & HasConfig) {
      has_config_ = true;
    }
    if (flags & HasGA) {
      has_g_a_ = true;
    }
    if (has_config_) {
      // prime_, prime_str_, b_, g_, g_int_, g_b_
      prime_str_ = parser.template fetch_string<std::string>();
      prime_ = BigNum::from_binary(prime_str_);

      b_ = BigNum::from_binary(parser.template fetch_string<string>());

      g_int_ = parser.fetch_int();
      g_.set_value(g_int_);

      g_b_ = BigNum::from_binary(parser.template fetch_string<string>());
    }
    if (has_g_a_) {
      g_a_ = BigNum::from_binary(parser.template fetch_string<string>());
    }
  }

 private:
  static Status check_config(Slice prime_str, const BigNum &prime, int32 g_int, BigNumContext &ctx,
                             DhCallback *callback) TD_WARN_UNUSED_RESULT;

  static Status dh_check(const BigNum &prime, const BigNum &g_a, const BigNum &g_b) TD_WARN_UNUSED_RESULT;

  string prime_str_;
  BigNum prime_;
  BigNum g_;
  int32 g_int_ = 0;
  BigNum b_;
  BigNum g_b_;
  BigNum g_a_;

  string g_a_hash_;
  bool has_g_a_hash_{false};
  bool ok_g_a_hash_{false};

  bool has_config_ = false;
  bool has_g_a_ = false;

  BigNumContext ctx_;
};

}  // namespace mtproto
}  // namespace td
