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
#include "td/utils/base64.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include "td/utils/format.h"

#include <algorithm>
#include <iterator>

namespace td {
//TODO: fix copypaste

static const char *const symbols32_lc = "abcdefghijklmnopqrstuvwxyz234567";
static const char *const symbols32_uc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

string base32_encode(Slice input, bool upper_case) {
  auto *symbols32 = (upper_case ? symbols32_uc : symbols32_lc);
  string base32;
  base32.reserve((input.size() * 8 + 4) / 5);
  uint32 c = 0;
  uint32 length = 0;
  for (size_t i = 0; i < input.size(); i++) {
    c = (c << 8) | input.ubegin()[i];
    length += 8;
    while (length >= 5) {
      length -= 5;
      base32.push_back(symbols32[(c >> length) & 31]);
    }
  }
  if (length != 0) {
    base32.push_back(symbols32[(c << (5 - length)) & 31]);
  }
  //TODO: optional padding
  return base32;
}

static unsigned char b32_char_to_value[256];
static void init_base32_table() {
  static bool is_inited = [] {
    std::fill(std::begin(b32_char_to_value), std::end(b32_char_to_value), static_cast<unsigned char>(32));
    for (unsigned char i = 0; i < 32; i++) {
      b32_char_to_value[static_cast<size_t>(symbols32_lc[i])] = i;
      b32_char_to_value[static_cast<size_t>(symbols32_uc[i])] = i;
    }
    return true;
  }();
  CHECK(is_inited);
}

Result<string> base32_decode(Slice base32) {
  init_base32_table();
  string res;
  res.reserve(base32.size() * 5 / 8);
  uint32 c = 0;
  uint32 length = 0;
  for (size_t i = 0; i < base32.size(); i++) {
    auto value = b32_char_to_value[base32.ubegin()[i]];
    if (value == 32) {
      return Status::Error("Wrong character in the string");
    }
    c = (c << 5) | value;
    length += 5;
    while (length >= 8) {
      length -= 8;
      res.push_back(td::uint8((c >> length) & 255));
    }
  }
  if ((c & ((1 << length) - 1)) != 0) {
    return Status::Error("Nonzero padding");
  }
  //TODO: check padding
  return res;
}

static const char *const symbols64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

string base64_encode(Slice input) {
  string base64;
  base64.reserve((input.size() + 2) / 3 * 4);
  for (size_t i = 0; i < input.size();) {
    size_t left = min(input.size() - i, static_cast<size_t>(3));
    int c = input.ubegin()[i++] << 16;
    base64 += symbols64[c >> 18];
    if (left != 1) {
      c |= input.ubegin()[i++] << 8;
    }
    base64 += symbols64[(c >> 12) & 63];
    if (left == 3) {
      c |= input.ubegin()[i++];
    }
    if (left != 1) {
      base64 += symbols64[(c >> 6) & 63];
    } else {
      base64 += '=';
    }
    if (left == 3) {
      base64 += symbols64[c & 63];
    } else {
      base64 += '=';
    }
  }
  return base64;
}

static unsigned char char_to_value[256];
static void init_base64_table() {
  static bool is_inited = [] {
    std::fill(std::begin(char_to_value), std::end(char_to_value), static_cast<unsigned char>(64));
    for (unsigned char i = 0; i < 64; i++) {
      char_to_value[static_cast<size_t>(symbols64[i])] = i;
    }
    return true;
  }();
  CHECK(is_inited);
}

Result<Slice> base64_drop_padding(Slice base64) {
  if ((base64.size() & 3) != 0) {
    return Status::Error("Wrong string length");
  }

  size_t padding_length = 0;
  while (!base64.empty() && base64.back() == '=') {
    base64.remove_suffix(1);
    padding_length++;
  }
  if (padding_length >= 3) {
    return Status::Error("Wrong string padding");
  }
  return base64;
}

template <class F>
Status base64_do_decode(Slice base64, F &&append) {
  for (size_t i = 0; i < base64.size();) {
    size_t left = min(base64.size() - i, static_cast<size_t>(4));
    int c = 0;
    for (size_t t = 0; t < left; t++) {
      auto value = char_to_value[base64.ubegin()[i++]];
      if (value == 64) {
        return Status::Error("Wrong character in the string");
      }
      c |= value << ((3 - t) * 6);
    }
    append(static_cast<char>(static_cast<unsigned char>(c >> 16)));  // implementation-defined
    if (left == 2) {
      if ((c & ((1 << 16) - 1)) != 0) {
        return Status::Error("Wrong padding in the string");
      }
    } else {
      append(static_cast<char>(static_cast<unsigned char>(c >> 8)));  // implementation-defined
      if (left == 3) {
        if ((c & ((1 << 8) - 1)) != 0) {
          return Status::Error("Wrong padding in the string");
        }
      } else {
        append(static_cast<char>(static_cast<unsigned char>(c)));  // implementation-defined
      }
    }
  }
  return Status::OK();
}

Result<string> base64_decode(Slice base64) {
  init_base64_table();

  TRY_RESULT(tmp, base64_drop_padding(base64));
  base64 = tmp;

  string output;
  output.reserve(((base64.size() + 3) >> 2) * 3);
  TRY_STATUS(base64_do_decode(base64, [&output](char c) { output += c; }));
  return output;
}

Result<SecureString> base64_decode_secure(Slice base64) {
  init_base64_table();

  TRY_RESULT(tmp, base64_drop_padding(base64));
  base64 = tmp;

  SecureString output(((base64.size() + 3) >> 2) * 3);
  char *ptr = output.as_mutable_slice().begin();
  TRY_STATUS(base64_do_decode(base64, [&ptr](char c) { *ptr++ = c; }));
  size_t size = ptr - output.as_mutable_slice().begin();
  if (size == output.size()) {
    return std::move(output);
  }
  return SecureString(output.as_slice().substr(0, size));
}

static const char *const url_symbols64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

string base64url_encode(Slice input) {
  string base64;
  base64.reserve((input.size() + 2) / 3 * 4);
  for (size_t i = 0; i < input.size();) {
    size_t left = min(input.size() - i, static_cast<size_t>(3));
    int c = input.ubegin()[i++] << 16;
    base64 += url_symbols64[c >> 18];
    if (left != 1) {
      c |= input.ubegin()[i++] << 8;
    }
    base64 += url_symbols64[(c >> 12) & 63];
    if (left == 3) {
      c |= input.ubegin()[i++];
    }
    if (left != 1) {
      base64 += url_symbols64[(c >> 6) & 63];
    }
    if (left == 3) {
      base64 += url_symbols64[c & 63];
    }
  }
  return base64;
}

static unsigned char url_char_to_value[256];
static void init_base64url_table() {
  static bool is_inited = [] {
    std::fill(std::begin(url_char_to_value), std::end(url_char_to_value), static_cast<unsigned char>(64));
    for (unsigned char i = 0; i < 64; i++) {
      url_char_to_value[static_cast<size_t>(url_symbols64[i])] = i;
    }
    return true;
  }();
  CHECK(is_inited);
}

Result<string> base64url_decode(Slice base64) {
  init_base64url_table();

  size_t padding_length = 0;
  while (!base64.empty() && base64.back() == '=') {
    base64.remove_suffix(1);
    padding_length++;
  }
  if (padding_length >= 3 || (padding_length > 0 && ((base64.size() + padding_length) & 3) != 0)) {
    return Status::Error("Wrong string padding");
  }

  if ((base64.size() & 3) == 1) {
    return Status::Error("Wrong string length");
  }

  string output;
  output.reserve(((base64.size() + 3) >> 2) * 3);
  for (size_t i = 0; i < base64.size();) {
    size_t left = min(base64.size() - i, static_cast<size_t>(4));
    int c = 0;
    for (size_t t = 0; t < left; t++) {
      auto value = url_char_to_value[base64.ubegin()[i++]];
      if (value == 64) {
        return Status::Error("Wrong character in the string");
      }
      c |= value << ((3 - t) * 6);
    }
    output += static_cast<char>(static_cast<unsigned char>(c >> 16));  // implementation-defined
    if (left == 2) {
      if ((c & ((1 << 16) - 1)) != 0) {
        return Status::Error("Wrong padding in the string");
      }
    } else {
      output += static_cast<char>(static_cast<unsigned char>(c >> 8));  // implementation-defined
      if (left == 3) {
        if ((c & ((1 << 8) - 1)) != 0) {
          return Status::Error("Wrong padding in the string");
        }
      } else {
        output += static_cast<char>(static_cast<unsigned char>(c));  // implementation-defined
      }
    }
  }
  return output;
}

template <bool is_url>
static bool is_base64_impl(Slice input) {
  size_t padding_length = 0;
  while (!input.empty() && input.back() == '=') {
    input.remove_suffix(1);
    padding_length++;
  }
  if (padding_length >= 3) {
    return false;
  }
  if ((!is_url || padding_length > 0) && ((input.size() + padding_length) & 3) != 0) {
    return false;
  }
  if (is_url && (input.size() & 3) == 1) {
    return false;
  }

  unsigned char *table;
  if (is_url) {
    init_base64url_table();
    table = url_char_to_value;
  } else {
    init_base64_table();
    table = char_to_value;
  }
  for (auto c : input) {
    if (table[static_cast<unsigned char>(c)] == 64) {
      return false;
    }
  }

  if ((input.size() & 3) == 2) {
    auto value = table[static_cast<int>(input.back())];
    if ((value & 15) != 0) {
      return false;
    }
  }
  if ((input.size() & 3) == 3) {
    auto value = table[static_cast<int>(input.back())];
    if ((value & 3) != 0) {
      return false;
    }
  }

  return true;
}

bool is_base64(Slice input) {
  return is_base64_impl<false>(input);
}

bool is_base64url(Slice input) {
  return is_base64_impl<true>(input);
}

string base64_filter(Slice input) {
  string res;
  res.reserve(input.size());
  init_base64_table();
  for (auto c : input) {
    if (char_to_value[static_cast<unsigned char>(c)] != 64 || c == '=') {
      res += c;
    }
  }
  return res;
}

}  // namespace td
