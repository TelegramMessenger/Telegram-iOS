//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/Slice.h"

#if TD_HAVE_OPENSSL
#include <openssl/crypto.h>
#endif

namespace td {

void MutableSlice::fill(char c) {
  std::memset(data(), c, size());
}

void MutableSlice::fill_zero() {
  fill('\0');
}

void MutableSlice::fill_zero_secure() {
#if TD_HAVE_OPENSSL
  OPENSSL_cleanse(begin(), size());
#else
  volatile char *ptr = begin();
  for (size_t i = 0; i < size(); i++) {
    ptr[i] = '\0';
  }
#endif
}

}  // namespace td
