//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/TlsInit.h"

#include "td/mtproto/ProxySecret.h"

#include "td/utils/as.h"
#include "td/utils/BigNum.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Span.h"
#include "td/utils/Time.h"

#include <algorithm>
#include <cstring>

namespace td {
namespace mtproto {

void Grease::init(MutableSlice res) {
  Random::secure_bytes(res);
  for (auto &c : res) {
    c = static_cast<char>((c & 0xF0) + 0x0A);
  }
  for (size_t i = 1; i < res.size(); i += 2) {
    if (res[i] == res[i - 1]) {
      res[i] ^= 0x10;
    }
  }
}

class TlsHello {
 public:
  struct Op {
    enum class Type { String, Random, Zero, Domain, Grease, Key, BeginScope, EndScope, Permutation };
    Type type;
    int length;
    int seed;
    string data;
    vector<vector<Op>> parts;

    static Op str(Slice str) {
      Op res;
      res.type = Type::String;
      res.data = str.str();
      return res;
    }
    static Op random(int length) {
      Op res;
      res.type = Type::Random;
      res.length = length;
      return res;
    }
    static Op zero(int length) {
      Op res;
      res.type = Type::Zero;
      res.length = length;
      return res;
    }
    static Op domain() {
      Op res;
      res.type = Type::Domain;
      return res;
    }
    static Op grease(int seed) {
      Op res;
      res.type = Type::Grease;
      res.seed = seed;
      return res;
    }
    static Op begin_scope() {
      Op res;
      res.type = Type::BeginScope;
      return res;
    }
    static Op end_scope() {
      Op res;
      res.type = Type::EndScope;
      return res;
    }
    static Op key() {
      Op res;
      res.type = Type::Key;
      return res;
    }
    static Op permutation(vector<vector<Op>> parts) {
      Op res;
      res.type = Type::Permutation;
      res.parts = std::move(parts);
      return res;
    }
  };

  static const TlsHello &get_default() {
    static TlsHello result = [] {
      TlsHello res;
#if TD_DARWIN
      res.ops_ = {
          Op::str("\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03"),
          Op::zero(32),
          Op::str("\x20"),
          Op::random(32),
          Op::str("\x00\x2a"),
          Op::grease(0),
          Op::str("\x13\x01\x13\x02\x13\x03\xc0\x2c\xc0\x2b\xcc\xa9\xc0\x30\xc0\x2f\xcc\xa8\xc0\x0a\xc0\x09\xc0\x14"
                  "\xc0\x13\x00\x9d\x00\x9c\x00\x35\x00\x2f\xc0\x08\xc0\x12\x00\x0a\x01\x00\x01\x89"),
          Op::grease(2),
          Op::str("\x00\x00\x00\x00"),
          Op::begin_scope(),
          Op::begin_scope(),
          Op::str("\x00"),
          Op::begin_scope(),
          Op::domain(),
          Op::end_scope(),
          Op::end_scope(),
          Op::end_scope(),
          Op::str("\x00\x17\x00\x00\xff\x01\x00\x01\x00\x00\x0a\x00\x0c\x00\x0a"),
          Op::grease(4),
          Op::str("\x00\x1d\x00\x17\x00\x18\x00\x19\x00\x0b\x00\x02\x01\x00\x00\x10\x00\x0e\x00\x0c\x02\x68\x32\x08"
                  "\x68\x74\x74\x70\x2f\x31\x2e\x31\x00\x05\x00\x05\x01\x00\x00\x00\x00\x00\x0d\x00\x18\x00\x16\x04"
                  "\x03\x08\x04\x04\x01\x05\x03\x02\x03\x08\x05\x08\x05\x05\x01\x08\x06\x06\x01\x02\x01\x00\x12\x00"
                  "\x00\x00\x33\x00\x2b\x00\x29"),
          Op::grease(4),
          Op::str("\x00\x01\x00\x00\x1d\x00\x20"),
          Op::key(),
          Op::str("\x00\x2d\x00\x02\x01\x01\x00\x2b\x00\x0b\x0a"),
          Op::grease(6),
          Op::str("\x03\x04\x03\x03\x03\x02\x03\x01\x00\x1b\x00\x03\x02\x00\x01"),
          Op::grease(3),
          Op::str("\x00\x01\x00\x00\x15")};
#else
      res.ops_ = {
          Op::str("\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03"),
          Op::zero(32),
          Op::str("\x20"),
          Op::random(32),
          Op::str("\x00\x20"),
          Op::grease(0),
          Op::str("\x13\x01\x13\x02\x13\x03\xc0\x2b\xc0\x2f\xc0\x2c\xc0\x30\xcc\xa9\xcc\xa8\xc0\x13\xc0\x14\x00\x9c"
                  "\x00\x9d\x00\x2f\x00\x35\x01\x00\x01\x93"),
          Op::grease(2),
          Op::str("\x00\x00"),

          Op::permutation(
              {vector<Op>{Op::str("\x00\x00"), Op::begin_scope(), Op::begin_scope(), Op::str("\x00"), Op::begin_scope(),
                          Op::domain(), Op::end_scope(), Op::end_scope(), Op::end_scope()},
               vector<Op>{Op::str("\x00\x05\x00\x05\x01\x00\x00\x00\x00")},
               vector<Op>{Op::str("\x00\x0a\x00\x0a\x00\x08"), Op::grease(4), Op::str("\x00\x1d\x00\x17\x00\x18")},
               vector<Op>{Op::str("\x00\x0b\x00\x02\x01\x00")},
               vector<Op>{
                   Op::str("\x00\x0d\x00\x12\x00\x10\x04\x03\x08\x04\x04\x01\x05\x03\x08\x05\x05\x01\x08\x06\x06\x01")},
               vector<Op>{Op::str("\x00\x10\x00\x0e\x00\x0c\x02\x68\x32\x08\x68\x74\x74\x70\x2f\x31\x2e\x31")},
               vector<Op>{Op::str("\x00\x12\x00\x00")}, vector<Op>{Op::str("\x00\x17\x00\x00")},
               vector<Op>{Op::str("\x00\x1b\x00\x03\x02\x00\x02")}, vector<Op>{Op::str("\x00\x23\x00\x00")},
               vector<Op>{Op::str("\x00\x2b\x00\x07\x06"), Op::grease(6), Op::str("\x03\x04\x03\x03")},
               vector<Op>{Op::str("\x00\x2d\x00\x02\x01\x01")},
               vector<Op>{Op::str("\x00\x33\x00\x2b\x00\x29"), Op::grease(4), Op::str("\x00\x01\x00\x00\x1d\x00\x20"),
                          Op::key()},
               vector<Op>{Op::str("\x44\x69\x00\x05\x00\x03\x02\x68\x32")},
               vector<Op>{Op::str("\xff\x01\x00\x01\x00")}}),
          Op::grease(3),
          Op::str("\x00\x01\x00\x00\x15")};
#endif
      return res;
    }();
    return result;
  }

  Span<Op> get_ops() const {
    return ops_;
  }

  size_t get_grease_size() const {
    return grease_size_;
  }

 private:
  std::vector<Op> ops_;
  size_t grease_size_ = 7;
};

class TlsHelloContext {
 public:
  TlsHelloContext(size_t grease_size, string domain) : grease_(grease_size, '\0'), domain_(std::move(domain)) {
    Grease::init(grease_);
  }

  char get_grease(size_t i) const {
    CHECK(i < grease_.size());
    return grease_[i];
  }
  size_t get_grease_size() const {
    return grease_.size();
  }
  Slice get_domain() const {
    return Slice(domain_).substr(0, ProxySecret::MAX_DOMAIN_LENGTH);
  }

 private:
  string grease_;
  string domain_;
};

class TlsHelloCalcLength {
 public:
  void do_op(const TlsHello::Op &op, const TlsHelloContext *context) {
    if (status_.is_error()) {
      return;
    }
    using Type = TlsHello::Op::Type;
    switch (op.type) {
      case Type::String:
        size_ += op.data.size();
        break;
      case Type::Random:
        if (op.length <= 0 || op.length > 1024) {
          return on_error(Status::Error("Invalid random length"));
        }
        size_ += op.length;
        break;
      case Type::Zero:
        if (op.length <= 0 || op.length > 1024) {
          return on_error(Status::Error("Invalid zero length"));
        }
        size_ += op.length;
        break;
      case Type::Domain:
        CHECK(context);
        size_ += context->get_domain().size();
        break;
      case Type::Grease:
        CHECK(context);
        if (op.seed < 0 || static_cast<size_t>(op.seed) >= context->get_grease_size()) {
          return on_error(Status::Error("Invalid grease seed"));
        }
        size_ += 2;
        break;
      case Type::Key:
        size_ += 32;
        break;
      case Type::BeginScope:
        size_ += 2;
        scope_offset_.push_back(size_);
        break;
      case Type::EndScope: {
        if (scope_offset_.empty()) {
          return on_error(Status::Error("Unbalanced scopes"));
        }
        auto begin_offset = scope_offset_.back();
        scope_offset_.pop_back();
        auto end_offset = size_;
        auto size = end_offset - begin_offset;
        if (size >= (1 << 14)) {
          return on_error(Status::Error("Scope is too big"));
        }
        break;
      }
      case Type::Permutation: {
        for (const auto &part : op.parts) {
          for (auto &nested_op : part) {
            do_op(nested_op, context);
          }
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  size_t get_length() const {
    return size_;
  }

  Result<size_t> finish() {
    if (status_.is_error()) {
      return std::move(status_);
    }
    if (size_ > 514) {
      return Status::Error("Too long for zero padding");
    }
    if (size_ < 11 + 32) {
      return Status::Error("Too small for hash");
    }
    int zero_pad = 515 - static_cast<int>(size_);
    using Op = TlsHello::Op;
    do_op(Op::begin_scope(), nullptr);
    do_op(Op::zero(zero_pad), nullptr);
    do_op(Op::end_scope(), nullptr);
    if (!scope_offset_.empty()) {
      return Status::Error("Unbalanced scopes");
    }
    return size_;
  }

 private:
  size_t size_{0};
  Status status_;
  std::vector<size_t> scope_offset_;

  void on_error(Status error) {
    if (status_.is_ok()) {
      status_ = std::move(error);
    }
  }
};

class TlsHelloStore {
 public:
  explicit TlsHelloStore(MutableSlice dest) : data_(dest), dest_(dest) {
  }
  void do_op(const TlsHello::Op &op, const TlsHelloContext *context) {
    using Type = TlsHello::Op::Type;
    switch (op.type) {
      case Type::String:
        dest_.copy_from(op.data);
        dest_.remove_prefix(op.data.size());
        break;
      case Type::Random:
        Random::secure_bytes(dest_.substr(0, op.length));
        dest_.remove_prefix(op.length);
        break;
      case Type::Zero:
        std::memset(dest_.begin(), 0, op.length);
        dest_.remove_prefix(op.length);
        break;
      case Type::Domain: {
        CHECK(context);
        auto domain = context->get_domain();
        dest_.copy_from(domain);
        dest_.remove_prefix(domain.size());
        break;
      }
      case Type::Grease: {
        CHECK(context);
        auto grease = context->get_grease(op.seed);
        dest_[0] = grease;
        dest_[1] = grease;
        dest_.remove_prefix(2);
        break;
      }
      case Type::Key: {
        BigNum mod = BigNum::from_hex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed").move_as_ok();
        BigNumContext big_num_context;
        auto key = dest_.substr(0, 32);
        while (true) {
          Random::secure_bytes(key);
          key[31] = static_cast<char>(key[31] & 127);

          BigNum x = BigNum::from_binary(key);
          BigNum y = get_y2(x, mod, big_num_context);
          if (is_quadratic_residue(y)) {
            for (int i = 0; i < 3; i++) {
              x = get_double_x(x, mod, big_num_context);
            }
            key.copy_from(x.to_le_binary(32));
            break;
          }
        }
        dest_.remove_prefix(32);
        break;
      }
      case Type::BeginScope:
        scope_offset_.push_back(get_offset());
        dest_.remove_prefix(2);
        break;
      case Type::EndScope: {
        CHECK(!scope_offset_.empty());
        auto begin_offset = scope_offset_.back();
        scope_offset_.pop_back();
        auto end_offset = get_offset();
        size_t size = end_offset - begin_offset - 2;
        CHECK(size < (1 << 14));
        data_[begin_offset] = static_cast<char>((size >> 8) & 0xff);
        data_[begin_offset + 1] = static_cast<char>(size & 0xff);
        break;
      }
      case Type::Permutation: {
        vector<string> parts;
        for (const auto &part : op.parts) {
          TlsHelloCalcLength calc_length;
          for (auto &nested_op : part) {
            calc_length.do_op(nested_op, context);
          }
          auto length = calc_length.get_length();
          string data(length, '\0');
          TlsHelloStore storer(data);
          for (auto &nested_op : part) {
            storer.do_op(nested_op, context);
          }
          CHECK(storer.get_offset() == data.size());
          parts.push_back(std::move(data));
        }
        Random::shuffle(parts);
        for (auto &part : parts) {
          dest_.copy_from(part);
          dest_.remove_prefix(part.size());
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void finish(Slice secret, int32 unix_time) {
    int zero_pad = 515 - static_cast<int>(get_offset());
    using Op = TlsHello::Op;
    do_op(Op::begin_scope(), nullptr);
    do_op(Op::zero(zero_pad), nullptr);
    do_op(Op::end_scope(), nullptr);

    auto hash_dest = data_.substr(11, 32);
    hmac_sha256(secret, data_, hash_dest);
    int32 old = as<int32>(hash_dest.substr(28).data());
    as<int32>(hash_dest.substr(28).data()) = old ^ unix_time;
    CHECK(dest_.empty());
  }

 private:
  MutableSlice data_;
  MutableSlice dest_;
  vector<size_t> scope_offset_;

  static BigNum get_y2(BigNum &x, const BigNum &mod, BigNumContext &big_num_context) {
    // returns y = x^3 + 486662 * x^2 + x
    BigNum y = x.clone();
    BigNum coef = BigNum::from_decimal("486662").move_as_ok();
    BigNum::mod_add(y, y, coef, mod, big_num_context);
    BigNum::mod_mul(y, y, x, mod, big_num_context);
    BigNum one = BigNum::from_decimal("1").move_as_ok();
    BigNum::mod_add(y, y, one, mod, big_num_context);
    BigNum::mod_mul(y, y, x, mod, big_num_context);
    return y;
  }

  static BigNum get_double_x(BigNum &x, const BigNum &mod, BigNumContext &big_num_context) {
    // returns x_2 = (x^2 - 1)^2/(4*y^2)
    BigNum denominator = get_y2(x, mod, big_num_context);
    BigNum coef = BigNum::from_decimal("4").move_as_ok();
    BigNum::mod_mul(denominator, denominator, coef, mod, big_num_context);

    BigNum numerator;
    BigNum::mod_mul(numerator, x, x, mod, big_num_context);
    BigNum one = BigNum::from_decimal("1").move_as_ok();
    BigNum::mod_sub(numerator, numerator, one, mod, big_num_context);
    BigNum::mod_mul(numerator, numerator, numerator, mod, big_num_context);

    BigNum::mod_inverse(denominator, denominator, mod, big_num_context);
    BigNum::mod_mul(numerator, numerator, denominator, mod, big_num_context);
    return numerator;
  }

  static bool is_quadratic_residue(const BigNum &a) {
    // 2^255 - 19
    BigNum mod = BigNum::from_hex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed").move_as_ok();
    // (mod - 1) / 2 = 2^254 - 10
    BigNum pow = BigNum::from_hex("3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6").move_as_ok();

    BigNumContext context;
    BigNum r;
    BigNum::mod_exp(r, a, pow, mod, context);

    return r.to_decimal() == "1";
  }

  size_t get_offset() const {
    return data_.size() - dest_.size();
  }
};

class TlsObfusaction {
 public:
  static string generate_header(string domain, Slice secret, int32 unix_time) {
    CHECK(!domain.empty());
    CHECK(secret.size() == 16);

    auto &hello = TlsHello::get_default();
    TlsHelloContext context(hello.get_grease_size(), std::move(domain));
    TlsHelloCalcLength calc_length;
    for (auto &op : hello.get_ops()) {
      calc_length.do_op(op, &context);
    }
    auto length = calc_length.finish().move_as_ok();
    string data(length, '\0');
    TlsHelloStore storer(data);
    for (auto &op : hello.get_ops()) {
      storer.do_op(op, &context);
    }
    storer.finish(secret, unix_time);
    return data;
  }
};

void TlsInit::send_hello() {
  auto hello =
      TlsObfusaction::generate_header(username_, password_, static_cast<int32>(Time::now() + server_time_difference_));
  hello_rand_ = hello.substr(11, 32);
  fd_.output_buffer().append(hello);
  state_ = State::WaitHelloResponse;
}

Status TlsInit::wait_hello_response() {
  auto it = fd_.input_buffer().clone();
  for (auto prefix : {Slice("\x16\x03\x03"), Slice("\x14\x03\x03\x00\x01\x01\x17\x03\x03")}) {
    if (it.size() < prefix.size() + 2) {
      return Status::OK();
    }

    string response_prefix(prefix.size(), '\0');
    it.advance(prefix.size(), response_prefix);
    if (prefix != response_prefix) {
      return Status::Error("First part of response to hello is invalid");
    }

    uint8 tmp[2];
    it.advance(2, MutableSlice(tmp, 2));
    size_t skip_size = (tmp[0] << 8) + tmp[1];
    if (it.size() < skip_size) {
      return Status::OK();
    }
    it.advance(skip_size);
  }

  auto response = fd_.input_buffer().cut_head(it.begin().clone()).move_as_buffer_slice();
  auto response_rand_slice = response.as_mutable_slice().substr(11, 32);
  auto response_rand = response_rand_slice.str();
  std::fill(response_rand_slice.begin(), response_rand_slice.end(), '\0');
  string hash_dest(32, '\0');
  hmac_sha256(password_, PSLICE() << hello_rand_ << response.as_slice(), hash_dest);
  if (hash_dest != response_rand) {
    return Status::Error("Response hash mismatch");
  }

  stop();
  return Status::OK();
}

Status TlsInit::loop_impl() {
  switch (state_) {
    case State::SendHello:
      send_hello();
      break;
    case State::WaitHelloResponse:
      TRY_STATUS(wait_hello_response());
      break;
  }
  return Status::OK();
}

}  // namespace mtproto
}  // namespace td
