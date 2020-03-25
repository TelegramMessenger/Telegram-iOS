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
#pragma once

#include "common/refcnt.hpp"
#include "common/bigint.hpp"
#include <utility>
#include <string>

namespace td {
class StringBuilder;

extern template class Cnt<BigInt256>;
extern template class Ref<Cnt<BigInt256>>;
typedef Cnt<BigInt256> CntInt256;
typedef Ref<CntInt256> RefInt256;

extern RefInt256 operator+(RefInt256 x, RefInt256 y);
extern RefInt256 operator+(RefInt256 x, long long y);
extern RefInt256 operator+(RefInt256 x, const BigInt256& y);
extern RefInt256 operator-(RefInt256 x, RefInt256 y);
extern RefInt256 operator-(RefInt256 x, long long y);
extern RefInt256 operator-(RefInt256 x, const BigInt256& y);
extern RefInt256 operator*(RefInt256 x, RefInt256 y);
extern RefInt256 operator*(RefInt256 x, long long y);
extern RefInt256 operator*(RefInt256 x, const BigInt256& y);
extern RefInt256 operator/(RefInt256 x, RefInt256 y);
extern RefInt256 operator%(RefInt256 x, RefInt256 y);
extern RefInt256 div(RefInt256 x, RefInt256 y, int round_mode = -1);
extern RefInt256 mod(RefInt256 x, RefInt256 y, int round_mode = -1);
extern std::pair<RefInt256, RefInt256> divmod(RefInt256 x, RefInt256 y, int round_mode = -1);
extern RefInt256 muldiv(RefInt256 x, RefInt256 y, RefInt256 z, int round_mode = -1);
extern std::pair<RefInt256, RefInt256> muldivmod(RefInt256 x, RefInt256 y, RefInt256 z, int round_mode = -1);
extern RefInt256 operator-(RefInt256 x);
extern RefInt256 operator&(RefInt256 x, RefInt256 y);
extern RefInt256 operator|(RefInt256 x, RefInt256 y);
extern RefInt256 operator^(RefInt256 x, RefInt256 y);
extern RefInt256 operator~(RefInt256 x);
extern RefInt256 operator<<(RefInt256 x, int y);
extern RefInt256 operator>>(RefInt256 x, int y);
extern RefInt256 rshift(RefInt256 x, int y, int round_mode = -1);

extern RefInt256& operator+=(RefInt256& x, RefInt256 y);
extern RefInt256& operator+=(RefInt256& x, long long y);
extern RefInt256& operator+=(RefInt256& x, const BigInt256& y);
extern RefInt256& operator-=(RefInt256& x, RefInt256 y);
extern RefInt256& operator-=(RefInt256& x, long long y);
extern RefInt256& operator-=(RefInt256& x, const BigInt256& y);
extern RefInt256& operator*=(RefInt256& x, RefInt256 y);
extern RefInt256& operator*=(RefInt256& x, long long y);
extern RefInt256& operator*=(RefInt256& x, const BigInt256& y);
extern RefInt256& operator/=(RefInt256& x, RefInt256 y);
extern RefInt256& operator%=(RefInt256& x, RefInt256 y);

extern RefInt256& operator&=(RefInt256& x, RefInt256 y);
extern RefInt256& operator|=(RefInt256& x, RefInt256 y);
extern RefInt256& operator^=(RefInt256& x, RefInt256 y);
extern RefInt256& operator<<=(RefInt256& x, int y);
extern RefInt256& operator>>=(RefInt256& x, int y);

template <typename T>
bool operator==(RefInt256 x, T y) {
  return cmp(x, y) == 0;
}

template <typename T>
bool operator!=(RefInt256 x, T y) {
  return cmp(x, y) != 0;
}

template <typename T>
bool operator<(RefInt256 x, T y) {
  return cmp(x, y) < 0;
}

template <typename T>
bool operator>(RefInt256 x, T y) {
  return cmp(x, y) > 0;
}

template <typename T>
bool operator<=(RefInt256 x, T y) {
  return cmp(x, y) <= 0;
}

template <typename T>
bool operator>=(RefInt256 x, T y) {
  return cmp(x, y) >= 0;
}

extern int cmp(RefInt256 x, RefInt256 y);
extern int cmp(RefInt256 x, long long y);
extern int sgn(RefInt256 x);

template <typename... Args>
RefInt256 make_refint(Args&&... args) {
  return td::RefInt256{true, std::forward<Args>(args)...};
}

extern RefInt256 make_refint(long long x);

extern RefInt256 zero_refint();
extern RefInt256 bits_to_refint(td::ConstBitPtr bits, int n, bool sgnd = false);

extern std::string dec_string(RefInt256 x);
extern std::string dec_string2(RefInt256&& x);
extern std::string hex_string(RefInt256 x, bool upcase = false);
extern std::string binary_string(RefInt256 x);

extern RefInt256 dec_string_to_int256(const std::string& s);
extern RefInt256 dec_string_to_int256(td::Slice s);
extern RefInt256 hex_string_to_int256(const std::string& s);
extern RefInt256 hex_string_to_int256(td::Slice s);
extern RefInt256 string_to_int256(const std::string& s);
extern RefInt256 string_to_int256(td::Slice s);

extern std::ostream& operator<<(std::ostream& os, const RefInt256& x);
extern std::ostream& operator<<(std::ostream& os, RefInt256&& x);
extern td::StringBuilder& operator<<(td::StringBuilder& os, const RefInt256& x);

namespace literals {

extern RefInt256 operator""_ri256(const char* str, std::size_t str_len);
extern RefInt256 operator""_rx256(const char* str, std::size_t str_len);

}  // namespace literals
}  // namespace td
