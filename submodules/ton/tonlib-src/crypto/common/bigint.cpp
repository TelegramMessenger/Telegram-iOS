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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "common/bigint.hpp"

namespace td {

template class AnyIntView<BigIntInfo>;
template class BigIntG<257, BigIntInfo>;

namespace literals {
BigInt256 operator""_i256(const char* str, std::size_t str_len) {
  BigInt256 x;
  x.enforce(x.parse_dec(str, (int)str_len) == (int)str_len);
  return x;
}

BigInt256 operator""_x256(const char* str, std::size_t str_len) {
  BigInt256 x;
  x.enforce(x.parse_hex(str, (int)str_len) == (int)str_len);
  return x;
}

}  // namespace literals

}  // namespace td
