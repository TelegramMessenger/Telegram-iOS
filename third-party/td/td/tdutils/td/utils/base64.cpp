//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/base64.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <algorithm>
#include <iterator>

namespace td {

template <bool is_url>
static const char *get_characters() {
  return is_url ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
                : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
}

template <bool is_url>
static const unsigned char *get_character_table() {
  static unsigned char char_to_value[256];
  static bool is_inited = [] {
    auto characters = get_characters<is_url>();
    std::fill(std::begin(char_to_value), std::end(char_to_value), static_cast<unsigned char>(64));
    for (unsigned char i = 0; i < 64; i++) {
      char_to_value[static_cast<size_t>(characters[i])] = i;
    }
    return true;
  }();
  CHECK(is_inited);
  return char_to_value;
}

template <bool is_url>
string base64_encode_impl(Slice input) {
  auto characters = get_characters<is_url>();
  string base64;
  base64.reserve((input.size() + 2) / 3 * 4);
  for (size_t i = 0; i < input.size();) {
    size_t left = min(input.size() - i, static_cast<size_t>(3));
    int c = input.ubegin()[i++] << 16;
    base64 += characters[c >> 18];
    if (left != 1) {
      c |= input.ubegin()[i++] << 8;
    }
    base64 += characters[(c >> 12) & 63];
    if (left == 3) {
      c |= input.ubegin()[i++];
    }
    if (left != 1) {
      base64 += characters[(c >> 6) & 63];
    } else if (!is_url) {
      base64 += '=';
    }
    if (left == 3) {
      base64 += characters[c & 63];
    } else if (!is_url) {
      base64 += '=';
    }
  }
  return base64;
}

string base64_encode(Slice input) {
  return base64_encode_impl<false>(input);
}

string base64url_encode(Slice input) {
  return base64_encode_impl<true>(input);
}

template <bool is_url>
Result<Slice> base64_drop_padding(Slice base64) {
  size_t padding_length = 0;
  while (!base64.empty() && base64.back() == '=') {
    base64.remove_suffix(1);
    padding_length++;
  }
  if (padding_length >= 3) {
    return Status::Error("Wrong string padding");
  }
  if ((!is_url || padding_length > 0) && ((base64.size() + padding_length) & 3) != 0) {
    return Status::Error("Wrong padding length");
  }
  if (is_url && (base64.size() & 3) == 1) {
    return Status::Error("Wrong string length");
  }
  return base64;
}

static Status do_base64_decode_impl(Slice base64, const unsigned char *table, char *ptr) {
  for (size_t i = 0; i < base64.size();) {
    size_t left = min(base64.size() - i, static_cast<size_t>(4));
    int c = 0;
    for (size_t t = 0; t < left; t++) {
      auto value = table[base64.ubegin()[i++]];
      if (value == 64) {
        return Status::Error("Wrong character in the string");
      }
      c |= value << ((3 - t) * 6);
    }
    *ptr++ = static_cast<char>(static_cast<unsigned char>(c >> 16));  // implementation-defined
    if (left == 2) {
      if ((c & ((1 << 16) - 1)) != 0) {
        return Status::Error("Wrong padding in the string");
      }
    } else {
      *ptr++ = static_cast<char>(static_cast<unsigned char>(c >> 8));  // implementation-defined
      if (left == 3) {
        if ((c & ((1 << 8) - 1)) != 0) {
          return Status::Error("Wrong padding in the string");
        }
      } else {
        *ptr++ = static_cast<char>(static_cast<unsigned char>(c));  // implementation-defined
      }
    }
  }
  return Status::OK();
}

template <class T>
static T create_empty(size_t size);

template <>
string create_empty<string>(size_t size) {
  return string(size, '\0');
}

template <>
SecureString create_empty<SecureString>(size_t size) {
  return SecureString{size};
}

template <bool is_url, class T>
static Result<T> base64_decode_impl(Slice base64) {
  TRY_RESULT_ASSIGN(base64, base64_drop_padding<is_url>(base64));

  T result = create_empty<T>(base64.size() / 4 * 3 + ((base64.size() & 3) + 1) / 2);
  TRY_STATUS(do_base64_decode_impl(base64, get_character_table<is_url>(), as_mutable_slice(result).begin()));
  return std::move(result);
}

Result<string> base64_decode(Slice base64) {
  return base64_decode_impl<false, string>(base64);
}

Result<SecureString> base64_decode_secure(Slice base64) {
  return base64_decode_impl<false, SecureString>(base64);
}

Result<string> base64url_decode(Slice base64) {
  return base64_decode_impl<true, string>(base64);
}
Result<SecureString> base64url_decode_secure(Slice base64) {
  return base64_decode_impl<true, SecureString>(base64);
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

  auto table = get_character_table<is_url>();
  for (auto c : input) {
    if (table[static_cast<unsigned char>(c)] == 64) {
      return false;
    }
  }

  if ((input.size() & 3) == 2) {
    auto value = table[static_cast<unsigned char>(input.back())];
    if ((value & 15) != 0) {
      return false;
    }
  }
  if ((input.size() & 3) == 3) {
    auto value = table[static_cast<unsigned char>(input.back())];
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

template <bool is_url>
static bool is_base64_characters_impl(Slice input) {
  auto table = get_character_table<is_url>();
  for (auto c : input) {
    if (table[static_cast<unsigned char>(c)] == 64) {
      return false;
    }
  }
  return true;
}

bool is_base64_characters(Slice input) {
  return is_base64_characters_impl<false>(input);
}

bool is_base64url_characters(Slice input) {
  return is_base64_characters_impl<true>(input);
}

string base64_filter(Slice input) {
  auto table = get_character_table<false>();
  string res;
  res.reserve(input.size());
  for (auto c : input) {
    if (table[static_cast<unsigned char>(c)] != 64 || c == '=') {
      res += c;
    }
  }
  return res;
}

static const char *get_base32_characters(bool upper_case) {
  return upper_case ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" : "abcdefghijklmnopqrstuvwxyz234567";
}

static const unsigned char *get_base32_character_table() {
  static unsigned char char_to_value[256];
  static bool is_inited = [] {
    std::fill(std::begin(char_to_value), std::end(char_to_value), static_cast<unsigned char>(32));
    auto characters_lc = get_base32_characters(false);
    auto characters_uc = get_base32_characters(true);
    for (unsigned char i = 0; i < 32; i++) {
      char_to_value[static_cast<size_t>(characters_lc[i])] = i;
      char_to_value[static_cast<size_t>(characters_uc[i])] = i;
    }
    return true;
  }();
  CHECK(is_inited);
  return char_to_value;
}

string base32_encode(Slice input, bool upper_case) {
  auto *characters = get_base32_characters(upper_case);
  string base32;
  base32.reserve((input.size() * 8 + 4) / 5);
  uint32 c = 0;
  uint32 length = 0;
  for (size_t i = 0; i < input.size(); i++) {
    c = (c << 8) | input.ubegin()[i];
    length += 8;
    while (length >= 5) {
      length -= 5;
      base32.push_back(characters[(c >> length) & 31]);
    }
  }
  if (length != 0) {
    base32.push_back(characters[(c << (5 - length)) & 31]);
  }
  //TODO: optional padding
  return base32;
}

Result<string> base32_decode(Slice base32) {
  string res;
  res.reserve(base32.size() * 5 / 8);
  uint32 c = 0;
  uint32 length = 0;
  auto *table = get_base32_character_table();
  for (size_t i = 0; i < base32.size(); i++) {
    auto value = table[base32.ubegin()[i]];
    if (value == 32) {
      return Status::Error("Wrong character in the string");
    }
    c = (c << 5) | value;
    length += 5;
    if (length >= 8) {
      length -= 8;
      res.push_back(static_cast<char>((c >> length) & 255));
    }
  }
  if ((c & ((1 << length) - 1)) != 0) {
    return Status::Error("Nonzero padding");
  }
  //TODO: check padding
  return res;
}

}  // namespace td
