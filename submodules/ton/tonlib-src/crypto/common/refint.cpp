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
#include "common/refint.h"
#include <utility>
#include <iostream>

#include "td/utils/StringBuilder.h"
#include "td/utils/Slice.h"

namespace td {

template class Cnt<BigInt256>;
template class Ref<Cnt<BigInt256>>;

RefInt256 operator+(RefInt256 x, RefInt256 y) {
  (x.write() += *y).normalize();
  return x;
}

RefInt256 operator+(RefInt256 x, long long y) {
  x.write().add_tiny(y).normalize();
  return x;
}

RefInt256 operator+(RefInt256 x, const BigInt256& y) {
  (x.write() += y).normalize();
  return x;
}

RefInt256 operator-(RefInt256 x, RefInt256 y) {
  (x.write() -= *y).normalize();
  return x;
}

RefInt256 operator-(RefInt256 x, long long y) {
  x.write().add_tiny(-y).normalize();
  return x;
}

RefInt256 operator-(RefInt256 x, const BigInt256& y) {
  (x.write() -= y).normalize();
  return x;
}

RefInt256 operator-(RefInt256 x) {
  x.write().negate().normalize();
  return x;
}

RefInt256 operator~(RefInt256 x) {
  x.write().logical_not().normalize();
  return x;
}

RefInt256 operator*(RefInt256 x, RefInt256 y) {
  RefInt256 z{true, 0};
  z.write().add_mul(*x, *y).normalize();
  return z;
}

RefInt256 operator*(RefInt256 x, long long y) {
  x.write().mul_short_opt(y).normalize();
  return x;
}

RefInt256 operator*(RefInt256 x, const BigInt256& y) {
  RefInt256 z{true, 0};
  z.write().add_mul(*x, y).normalize();
  return z;
}

RefInt256 operator/(RefInt256 x, RefInt256 y) {
  RefInt256 quot{true};
  x.write().mod_div(*y, quot.write());
  quot.write().normalize();
  return quot;
}

RefInt256 div(RefInt256 x, RefInt256 y, int round_mode) {
  RefInt256 quot{true};
  x.write().mod_div(*y, quot.write(), round_mode);
  quot.write().normalize();
  return quot;
}

RefInt256 operator%(RefInt256 x, RefInt256 y) {
  BigInt256 quot;
  x.write().mod_div(*y, quot);
  return x;
}

RefInt256 mod(RefInt256 x, RefInt256 y, int round_mode) {
  BigInt256 quot;
  x.write().mod_div(*y, quot, round_mode);
  return x;
}

std::pair<RefInt256, RefInt256> divmod(RefInt256 x, RefInt256 y, int round_mode) {
  RefInt256 quot{true};
  x.write().mod_div(*y, quot.write(), round_mode);
  quot.write().normalize();
  return std::make_pair(std::move(quot), std::move(x));
}

RefInt256 muldiv(RefInt256 x, RefInt256 y, RefInt256 z, int round_mode) {
  typename td::BigInt256::DoubleInt tmp{0};
  tmp.add_mul(*x, *y);
  RefInt256 quot{true};
  tmp.mod_div(*z, quot.unique_write(), round_mode);
  quot.write().normalize();
  return quot;
}

std::pair<RefInt256, RefInt256> muldivmod(RefInt256 x, RefInt256 y, RefInt256 z, int round_mode) {
  typename td::BigInt256::DoubleInt tmp{0};
  tmp.add_mul(*x, *y);
  RefInt256 quot{true};
  tmp.mod_div(*z, quot.unique_write(), round_mode);
  quot.write().normalize();
  return std::make_pair(std::move(quot), td::make_refint(tmp));
}

RefInt256 operator&(RefInt256 x, RefInt256 y) {
  x.write() &= *y;
  return x;
}

RefInt256 operator|(RefInt256 x, RefInt256 y) {
  x.write() |= *y;
  return x;
}

RefInt256 operator^(RefInt256 x, RefInt256 y) {
  x.write() ^= *y;
  return x;
}

RefInt256 operator<<(RefInt256 x, int y) {
  (x.write() <<= y).normalize();
  return x;
}

RefInt256 operator>>(RefInt256 x, int y) {
  (x.write() >>= y).normalize();
  return x;
}

RefInt256 rshift(RefInt256 x, int y, int round_mode) {
  x.write().rshift(y, round_mode).normalize();
  return x;
}

RefInt256& operator+=(RefInt256& x, RefInt256 y) {
  (x.write() += *y).normalize();
  return x;
}

RefInt256& operator+=(RefInt256& x, long long y) {
  x.write().add_tiny(y).normalize();
  return x;
}

RefInt256& operator+=(RefInt256& x, const BigInt256& y) {
  (x.write() += y).normalize();
  return x;
}

RefInt256& operator-=(RefInt256& x, RefInt256 y) {
  (x.write() -= *y).normalize();
  return x;
}

RefInt256& operator-=(RefInt256& x, long long y) {
  x.write().add_tiny(-y).normalize();
  return x;
}

RefInt256& operator-=(RefInt256& x, const BigInt256& y) {
  (x.write() -= y).normalize();
  return x;
}

RefInt256& operator*=(RefInt256& x, RefInt256 y) {
  RefInt256 z{true, 0};
  z.write().add_mul(*x, *y).normalize();
  return x = z;
}

RefInt256& operator*=(RefInt256& x, long long y) {
  x.write().mul_short_opt(y).normalize();
  return x;
}

RefInt256& operator*=(RefInt256& x, const BigInt256& y) {
  RefInt256 z{true, 0};
  z.write().add_mul(*x, y).normalize();
  return x = z;
}

RefInt256& operator/=(RefInt256& x, RefInt256 y) {
  RefInt256 quot{true};
  x.write().mod_div(*y, quot.write());
  quot.write().normalize();
  return x = quot;
}

RefInt256& operator%=(RefInt256& x, RefInt256 y) {
  BigInt256 quot;
  x.write().mod_div(*y, quot);
  return x;
}

RefInt256& operator&=(RefInt256& x, RefInt256 y) {
  x.write() &= *y;
  return x;
}

RefInt256& operator|=(RefInt256& x, RefInt256 y) {
  x.write() |= *y;
  return x;
}

RefInt256& operator^=(RefInt256& x, RefInt256 y) {
  x.write() ^= *y;
  return x;
}

RefInt256& operator<<=(RefInt256& x, int y) {
  (x.write() <<= y).normalize();
  return x;
}

RefInt256& operator>>=(RefInt256& x, int y) {
  (x.write() >>= y).normalize();
  return x;
}

int cmp(RefInt256 x, RefInt256 y) {
  return x->cmp(*y);
}

int cmp(RefInt256 x, long long y) {
  return x->cmp(y);
}

int sgn(RefInt256 x) {
  return x->sgn();
}

RefInt256 make_refint(long long x) {
  return td::RefInt256{true, td::Normalize(), x};
}

RefInt256 zero_refint() {
  //  static RefInt256 Zero = td::RefInt256{true, 0};
  //  return Zero;
  return td::RefInt256{true, 0};
}

RefInt256 bits_to_refint(td::ConstBitPtr bits, int n, bool sgnd) {
  td::RefInt256 x{true};
  x.unique_write().import_bits(bits, n, sgnd);
  return x;
}

std::string dec_string(RefInt256 x) {
  return x.is_null() ? "(null)" : (x.is_unique() ? x.unique_write().to_dec_string_destroy() : x->to_dec_string());
}

std::string dec_string2(RefInt256&& x) {
  return x.is_null() ? "(null)" : (x.is_unique() ? x.unique_write().to_dec_string_destroy() : x->to_dec_string());
}

std::string hex_string(RefInt256 x, bool upcase) {
  return x.is_null() ? "(null)" : x->to_hex_string(upcase);
}

std::string binary_string(RefInt256 x) {
  return x.is_null() ? "(null)" : x->to_binary_string();
}

std::ostream& operator<<(std::ostream& os, const RefInt256& x) {
  //std::cout << "<a|";
  return os << dec_string(std::move(x));
  //std::cout << "|a>";
  //return os;
}

std::ostream& operator<<(std::ostream& os, RefInt256&& x) {
  //std::cout << "<A|";
  return os << dec_string2(std::move(x));
  //std::cout << "|A>";
  //return os;
}

StringBuilder& operator<<(StringBuilder& sb, const RefInt256& x) {
  return sb << dec_string(x);
}

RefInt256 dec_string_to_int256(const std::string& s) {
  return dec_string_to_int256(td::Slice{s});
}

RefInt256 dec_string_to_int256(td::Slice s) {
  if (s.size() > 255) {
    return {};
  }
  RefInt256 x{true};
  if (x.unique_write().parse_dec(s.begin(), (int)s.size()) == (int)s.size()) {
    return x;
  } else {
    return {};
  }
}

RefInt256 hex_string_to_int256(const std::string& s) {
  return hex_string_to_int256(td::Slice{s});
}

RefInt256 hex_string_to_int256(td::Slice s) {
  if (s.size() > 255) {
    return {};
  }
  RefInt256 x{true};
  if (x.unique_write().parse_hex(s.begin(), (int)s.size()) == (int)s.size()) {
    return x;
  } else {
    return {};
  }
}

RefInt256 string_to_int256(const std::string& s) {
  return string_to_int256(td::Slice{s});
}

RefInt256 string_to_int256(td::Slice s) {
  if (s.size() >= 3 && s[0] == '-' && s[1] == '0' && s[2] == 'x') {
    auto x = hex_string_to_int256(td::Slice(s.begin() + 3, s.end()));
    if (x.not_null()) {
      x.write().negate();
    }
    return x;
  } else if (s.size() >= 2 && s[0] == '0' && s[1] == 'x') {
    return hex_string_to_int256(td::Slice(s.begin() + 2, s.end()));
  } else {
    return dec_string_to_int256(s);
  }
}

namespace literals {

RefInt256 operator""_ri256(const char* str, std::size_t str_len) {
  RefInt256 x{true};
  x->enforce(x.unique_write().parse_dec(str, (int)str_len) == (int)str_len);
  return x;
}

RefInt256 operator""_rx256(const char* str, std::size_t str_len) {
  RefInt256 x{true};
  x->enforce(x.unique_write().parse_hex(str, (int)str_len) == (int)str_len);
  return x;
}

}  // namespace literals
}  // namespace td
