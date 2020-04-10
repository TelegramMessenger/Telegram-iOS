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
#include "td/utils/Slice.h"
#if TD_HAVE_OPENSSL
#include <openssl/crypto.h>
#endif

namespace td {

void MutableSlice::fill(char c) {
  std::memset(data(), c, size());
}
void MutableSlice::fill_zero() {
  fill(0);
}
void MutableSlice::fill_zero_secure() {
#if TD_HAVE_OPENSSL
  OPENSSL_cleanse(begin(), size());
#else
  volatile char *ptr = begin();
  for (size_t i = 0; i < size(); i++) {
    ptr[i] = 0;
  }
#endif
}

}  // namespace td
