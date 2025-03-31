//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/misc.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/Hints.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/utf8.h"

#include <cstring>
#include <limits>

namespace td {

string clean_name(string str, size_t max_length) {
  str = strip_empty_characters(str, max_length);
  size_t new_len = 0;
  bool is_previous_space = false;
  for (size_t i = 0; i < str.size(); i++) {
    if (str[i] == ' ' || str[i] == '\n') {
      if (!is_previous_space) {
        str[new_len++] = ' ';
        is_previous_space = true;
      }
      continue;
    }
    if (static_cast<unsigned char>(str[i]) == 0xC2 && static_cast<unsigned char>(str[i + 1]) == 0xA0) {  // &nbsp;
      if (!is_previous_space) {
        str[new_len++] = ' ';
        is_previous_space = true;
      }
      i++;
      continue;
    }

    str[new_len++] = str[i];
    is_previous_space = false;
  }
  str.resize(new_len);
  return trim(str);
}

string clean_username(string str) {
  td::remove(str, '.');
  to_lower_inplace(str);
  return trim(str);
}

void clean_phone_number(string &phone_number) {
  td::remove_if(phone_number, [](char c) { return !is_digit(c); });
}

void replace_offending_characters(string &str) {
  // "(\xe2\x80\x8f|\xe2\x80\x8e){N}(\xe2\x80\x8f|\xe2\x80\x8e)" -> "(\xe2\x80\x8c){N}$2"
  auto s = MutableSlice(str).ubegin();
  for (size_t pos = 0; pos < str.size(); pos++) {
    if (s[pos] == 0xe2 && s[pos + 1] == 0x80 && (s[pos + 2] == 0x8e || s[pos + 2] == 0x8f)) {
      while (s[pos + 3] == 0xe2 && s[pos + 4] == 0x80 && (s[pos + 5] == 0x8e || s[pos + 5] == 0x8f)) {
        s[pos + 2] = static_cast<unsigned char>(0x8c);
        pos += 3;
      }
      pos += 2;
    }
  }
}

bool clean_input_string(string &str) {
  constexpr size_t LENGTH_LIMIT = 35000;  // server side limit
  if (!check_utf8(str)) {
    return false;
  }

  size_t str_size = str.size();
  size_t new_size = 0;
  for (size_t pos = 0; pos < str_size; pos++) {
    auto c = static_cast<unsigned char>(str[pos]);
    switch (c) {
      // remove control characters
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
      case 9:
      // allow '\n'
      case 11:
      case 12:
      // ignore '\r'
      case 14:
      case 15:
      case 16:
      case 17:
      case 18:
      case 19:
      case 20:
      case 21:
      case 22:
      case 23:
      case 24:
      case 25:
      case 26:
      case 27:
      case 28:
      case 29:
      case 30:
      case 31:
      case 32:
        str[new_size++] = ' ';
        break;
      case '\r':
        // skip
        break;
      default:
        // remove \xe2\x80[\xa8-\xae]
        if (c == 0xe2 && pos + 2 < str_size) {
          auto next = static_cast<unsigned char>(str[pos + 1]);
          if (next == 0x80) {
            next = static_cast<unsigned char>(str[pos + 2]);
            if (0xa8 <= next && next <= 0xae) {
              pos += 2;
              break;
            }
          }
        }
        // remove vertical lines \xcc[\xb3\xbf\x8a]
        if (c == 0xcc && pos + 1 < str_size) {
          auto next = static_cast<unsigned char>(str[pos + 1]);
          if (next == 0xb3 || next == 0xbf || next == 0x8a) {
            pos++;
            break;
          }
        }

        str[new_size++] = str[pos];
        break;
    }
    if (new_size >= LENGTH_LIMIT - 3 && is_utf8_character_first_code_unit(str[new_size - 1])) {
      new_size--;
      break;
    }
  }

  str.resize(new_size);

  replace_offending_characters(str);

  return true;
}

string strip_empty_characters(string str, size_t max_length, bool strip_rtlo) {
  static const char *space_characters[] = {u8"\u1680", u8"\u180E", u8"\u2000", u8"\u2001", u8"\u2002",
                                           u8"\u2003", u8"\u2004", u8"\u2005", u8"\u2006", u8"\u2007",
                                           u8"\u2008", u8"\u2009", u8"\u200A", u8"\u202E", u8"\u202F",
                                           u8"\u205F", u8"\u2800", u8"\u3000", u8"\uFFFC"};
  static bool can_be_first[std::numeric_limits<unsigned char>::max() + 1];
  static bool can_be_first_inited = [&] {
    for (auto space_ch : space_characters) {
      CHECK(std::strlen(space_ch) == 3);
      can_be_first[static_cast<unsigned char>(space_ch[0])] = true;
    }
    can_be_first[0xF3] = true;
    return true;
  }();
  CHECK(can_be_first_inited);

  // replace all occurrences of space characters with a space
  size_t i = 0;
  while (i < str.size() && !can_be_first[static_cast<unsigned char>(str[i])]) {
    i++;
  }
  size_t new_len = i;
  while (i < str.size()) {
    if (can_be_first[static_cast<unsigned char>(str[i])] && i + 3 <= str.size()) {
      if (static_cast<unsigned char>(str[i]) == 0xF3) {
        if (static_cast<unsigned char>(str[i + 1]) == 0xA0 && (static_cast<unsigned char>(str[i + 2]) & 0xFE) == 0x80 &&
            i + 4 <= str.size()) {
          str[new_len++] = ' ';
          i += 4;
          continue;
        }
      } else {
        bool found = false;
        for (auto space_ch : space_characters) {
          if (space_ch[0] == str[i] && space_ch[1] == str[i + 1] && space_ch[2] == str[i + 2]) {
            if (static_cast<unsigned char>(str[i + 2]) != 0xAE || static_cast<unsigned char>(str[i + 1]) != 0x80 ||
                static_cast<unsigned char>(str[i]) != 0xE2 || strip_rtlo) {
              found = true;
            }
            break;
          }
        }
        if (found) {
          str[new_len++] = ' ';
          i += 3;
          continue;
        }
      }
    }
    str[new_len++] = str[i++];
  }
  Slice trimmed = trim(utf8_truncate(trim(Slice(str.c_str(), new_len)), max_length));

  // check if there is some non-empty character, empty characters:
  // "\xE2\x80\x8B", ZERO WIDTH SPACE
  // "\xE2\x80\x8C", ZERO WIDTH NON-JOINER
  // "\xE2\x80\x8D", ZERO WIDTH JOINER
  // "\xE2\x80\x8E", LEFT-TO-RIGHT MARK
  // "\xE2\x80\x8F", RIGHT-TO-LEFT MARK
  // "\xE2\x80\xAE", RIGHT-TO-LEFT OVERRIDE
  // "\xEF\xBB\xBF", ZERO WIDTH NO-BREAK SPACE aka BYTE ORDER MARK
  // "\xC2\xA0", NO-BREAK SPACE
  for (i = 0;;) {
    if (i == trimmed.size()) {
      // if all characters are empty, return an empty string
      return string();
    }

    if (trimmed[i] == ' ' || trimmed[i] == '\n') {
      i++;
      continue;
    }
    if (static_cast<unsigned char>(trimmed[i]) == 0xE2 && static_cast<unsigned char>(trimmed[i + 1]) == 0x80) {
      auto next = static_cast<unsigned char>(trimmed[i + 2]);
      if ((0x8B <= next && next <= 0x8F) || next == 0xAE) {
        i += 3;
        continue;
      }
    }
    if (static_cast<unsigned char>(trimmed[i]) == 0xEF && static_cast<unsigned char>(trimmed[i + 1]) == 0xBB &&
        static_cast<unsigned char>(trimmed[i + 2]) == 0xBF) {
      i += 3;
      continue;
    }
    if (static_cast<unsigned char>(trimmed[i]) == 0xC2 && static_cast<unsigned char>(trimmed[i + 1]) == 0xA0) {
      i += 2;
      continue;
    }
    break;
  }
  return trimmed.str();
}

bool is_empty_string(const string &str) {
  return strip_empty_characters(str, str.size()).empty();
}

bool is_valid_username(Slice username) {
  if (username.empty() || username.size() > 32) {
    return false;
  }
  if (!is_alpha(username[0])) {
    return false;
  }
  for (auto c : username) {
    if (!is_alpha(c) && !is_digit(c) && c != '_') {
      return false;
    }
  }
  if (username.back() == '_') {
    return false;
  }
  for (size_t i = 1; i < username.size(); i++) {
    if (username[i - 1] == '_' && username[i] == '_') {
      return false;
    }
  }

  return true;
}

bool is_allowed_username(Slice username) {
  if (!is_valid_username(username)) {
    return false;
  }
  if (username.size() < 5) {
    return false;
  }
  auto username_lowered = to_lower(username);
  if (username_lowered.find("admin") == 0 || username_lowered.find("telegram") == 0 ||
      username_lowered.find("support") == 0 || username_lowered.find("security") == 0 ||
      username_lowered.find("settings") == 0 || username_lowered.find("contacts") == 0 ||
      username_lowered.find("service") == 0 || username_lowered.find("telegraph") == 0) {
    return false;
  }
  return true;
}

uint64 get_md5_string_hash(const string &str) {
  unsigned char hash[16];
  md5(str, {hash, sizeof(hash)});
  uint64 result = 0;
  for (int i = 0; i <= 7; i++) {
    result += static_cast<uint64>(hash[i]) << (56 - 8 * i);
  }
  return result;
}

int64 get_vector_hash(const vector<uint64> &numbers) {
  uint64 acc = 0;
  for (auto number : numbers) {
    acc ^= acc >> 21;
    acc ^= acc << 35;
    acc ^= acc >> 4;
    acc += number;
  }
  return static_cast<int64>(acc);
}

string get_emoji_fingerprint(uint64 num) {
  static const vector<Slice> emojis{
      u8"\U0001f609", u8"\U0001f60d", u8"\U0001f61b", u8"\U0001f62d", u8"\U0001f631", u8"\U0001f621", u8"\U0001f60e",
      u8"\U0001f634", u8"\U0001f635", u8"\U0001f608", u8"\U0001f62c", u8"\U0001f607", u8"\U0001f60f", u8"\U0001f46e",
      u8"\U0001f477", u8"\U0001f482", u8"\U0001f476", u8"\U0001f468", u8"\U0001f469", u8"\U0001f474", u8"\U0001f475",
      u8"\U0001f63b", u8"\U0001f63d", u8"\U0001f640", u8"\U0001f47a", u8"\U0001f648", u8"\U0001f649", u8"\U0001f64a",
      u8"\U0001f480", u8"\U0001f47d", u8"\U0001f4a9", u8"\U0001f525", u8"\U0001f4a5", u8"\U0001f4a4", u8"\U0001f442",
      u8"\U0001f440", u8"\U0001f443", u8"\U0001f445", u8"\U0001f444", u8"\U0001f44d", u8"\U0001f44e", u8"\U0001f44c",
      u8"\U0001f44a", u8"\u270c", u8"\u270b", u8"\U0001f450", u8"\U0001f446", u8"\U0001f447", u8"\U0001f449",
      u8"\U0001f448", u8"\U0001f64f", u8"\U0001f44f", u8"\U0001f4aa", u8"\U0001f6b6", u8"\U0001f3c3", u8"\U0001f483",
      u8"\U0001f46b", u8"\U0001f46a", u8"\U0001f46c", u8"\U0001f46d", u8"\U0001f485", u8"\U0001f3a9", u8"\U0001f451",
      u8"\U0001f452", u8"\U0001f45f", u8"\U0001f45e", u8"\U0001f460", u8"\U0001f455", u8"\U0001f457", u8"\U0001f456",
      u8"\U0001f459", u8"\U0001f45c", u8"\U0001f453", u8"\U0001f380", u8"\U0001f484", u8"\U0001f49b", u8"\U0001f499",
      u8"\U0001f49c", u8"\U0001f49a", u8"\U0001f48d", u8"\U0001f48e", u8"\U0001f436", u8"\U0001f43a", u8"\U0001f431",
      u8"\U0001f42d", u8"\U0001f439", u8"\U0001f430", u8"\U0001f438", u8"\U0001f42f", u8"\U0001f428", u8"\U0001f43b",
      u8"\U0001f437", u8"\U0001f42e", u8"\U0001f417", u8"\U0001f434", u8"\U0001f411", u8"\U0001f418", u8"\U0001f43c",
      u8"\U0001f427", u8"\U0001f425", u8"\U0001f414", u8"\U0001f40d", u8"\U0001f422", u8"\U0001f41b", u8"\U0001f41d",
      u8"\U0001f41c", u8"\U0001f41e", u8"\U0001f40c", u8"\U0001f419", u8"\U0001f41a", u8"\U0001f41f", u8"\U0001f42c",
      u8"\U0001f40b", u8"\U0001f410", u8"\U0001f40a", u8"\U0001f42b", u8"\U0001f340", u8"\U0001f339", u8"\U0001f33b",
      u8"\U0001f341", u8"\U0001f33e", u8"\U0001f344", u8"\U0001f335", u8"\U0001f334", u8"\U0001f333", u8"\U0001f31e",
      u8"\U0001f31a", u8"\U0001f319", u8"\U0001f30e", u8"\U0001f30b", u8"\u26a1", u8"\u2614", u8"\u2744", u8"\u26c4",
      u8"\U0001f300", u8"\U0001f308", u8"\U0001f30a", u8"\U0001f393", u8"\U0001f386", u8"\U0001f383", u8"\U0001f47b",
      u8"\U0001f385", u8"\U0001f384", u8"\U0001f381", u8"\U0001f388", u8"\U0001f52e", u8"\U0001f3a5", u8"\U0001f4f7",
      u8"\U0001f4bf", u8"\U0001f4bb", u8"\u260e", u8"\U0001f4e1", u8"\U0001f4fa", u8"\U0001f4fb", u8"\U0001f509",
      u8"\U0001f514", u8"\u23f3", u8"\u23f0", u8"\u231a", u8"\U0001f512", u8"\U0001f511", u8"\U0001f50e",
      u8"\U0001f4a1", u8"\U0001f526", u8"\U0001f50c", u8"\U0001f50b", u8"\U0001f6bf", u8"\U0001f6bd", u8"\U0001f527",
      u8"\U0001f528", u8"\U0001f6aa", u8"\U0001f6ac", u8"\U0001f4a3", u8"\U0001f52b", u8"\U0001f52a", u8"\U0001f48a",
      u8"\U0001f489", u8"\U0001f4b0", u8"\U0001f4b5", u8"\U0001f4b3", u8"\u2709", u8"\U0001f4eb", u8"\U0001f4e6",
      u8"\U0001f4c5", u8"\U0001f4c1", u8"\u2702", u8"\U0001f4cc", u8"\U0001f4ce", u8"\u2712", u8"\u270f",
      u8"\U0001f4d0", u8"\U0001f4da", u8"\U0001f52c", u8"\U0001f52d", u8"\U0001f3a8", u8"\U0001f3ac", u8"\U0001f3a4",
      u8"\U0001f3a7", u8"\U0001f3b5", u8"\U0001f3b9", u8"\U0001f3bb", u8"\U0001f3ba", u8"\U0001f3b8", u8"\U0001f47e",
      u8"\U0001f3ae", u8"\U0001f0cf", u8"\U0001f3b2", u8"\U0001f3af", u8"\U0001f3c8", u8"\U0001f3c0", u8"\u26bd",
      u8"\u26be", u8"\U0001f3be", u8"\U0001f3b1", u8"\U0001f3c9", u8"\U0001f3b3", u8"\U0001f3c1", u8"\U0001f3c7",
      u8"\U0001f3c6", u8"\U0001f3ca", u8"\U0001f3c4", u8"\u2615", u8"\U0001f37c", u8"\U0001f37a", u8"\U0001f377",
      u8"\U0001f374", u8"\U0001f355", u8"\U0001f354", u8"\U0001f35f", u8"\U0001f357", u8"\U0001f371", u8"\U0001f35a",
      u8"\U0001f35c", u8"\U0001f361", u8"\U0001f373", u8"\U0001f35e", u8"\U0001f369", u8"\U0001f366", u8"\U0001f382",
      u8"\U0001f370", u8"\U0001f36a", u8"\U0001f36b", u8"\U0001f36d", u8"\U0001f36f", u8"\U0001f34e", u8"\U0001f34f",
      u8"\U0001f34a", u8"\U0001f34b", u8"\U0001f352", u8"\U0001f347", u8"\U0001f349", u8"\U0001f353", u8"\U0001f351",
      u8"\U0001f34c", u8"\U0001f350", u8"\U0001f34d", u8"\U0001f346", u8"\U0001f345", u8"\U0001f33d", u8"\U0001f3e1",
      u8"\U0001f3e5", u8"\U0001f3e6", u8"\u26ea", u8"\U0001f3f0", u8"\u26fa", u8"\U0001f3ed", u8"\U0001f5fb",
      u8"\U0001f5fd", u8"\U0001f3a0", u8"\U0001f3a1", u8"\u26f2", u8"\U0001f3a2", u8"\U0001f6a2", u8"\U0001f6a4",
      u8"\u2693", u8"\U0001f680", u8"\u2708", u8"\U0001f681", u8"\U0001f682", u8"\U0001f68b", u8"\U0001f68e",
      u8"\U0001f68c", u8"\U0001f699", u8"\U0001f697", u8"\U0001f695", u8"\U0001f69b", u8"\U0001f6a8", u8"\U0001f694",
      u8"\U0001f692", u8"\U0001f691", u8"\U0001f6b2", u8"\U0001f6a0", u8"\U0001f69c", u8"\U0001f6a6", u8"\u26a0",
      u8"\U0001f6a7", u8"\u26fd", u8"\U0001f3b0", u8"\U0001f5ff", u8"\U0001f3aa", u8"\U0001f3ad",
      u8"\U0001f1ef\U0001f1f5", u8"\U0001f1f0\U0001f1f7", u8"\U0001f1e9\U0001f1ea", u8"\U0001f1e8\U0001f1f3",
      u8"\U0001f1fa\U0001f1f8", u8"\U0001f1eb\U0001f1f7", u8"\U0001f1ea\U0001f1f8", u8"\U0001f1ee\U0001f1f9",
      u8"\U0001f1f7\U0001f1fa", u8"\U0001f1ec\U0001f1e7", u8"\u0031\u20e3", u8"\u0032\u20e3", u8"\u0033\u20e3",
      u8"\u0034\u20e3", u8"\u0035\u20e3", u8"\u0036\u20e3", u8"\u0037\u20e3", u8"\u0038\u20e3", u8"\u0039\u20e3",
      u8"\u0030\u20e3", u8"\U0001f51f", u8"\u2757", u8"\u2753", u8"\u2665", u8"\u2666", u8"\U0001f4af", u8"\U0001f517",
      u8"\U0001f531", u8"\U0001f534", u8"\U0001f535", u8"\U0001f536",
      // comment for clang-format
      u8"\U0001f537"};

  return emojis[static_cast<size_t>((num & 0x7FFFFFFFFFFFFFFF) % emojis.size())].str();
}

bool check_currency_amount(int64 amount) {
  constexpr int64 MAX_AMOUNT = 9999'9999'9999;
  return -MAX_AMOUNT <= amount && amount <= MAX_AMOUNT;
}

Status validate_bot_language_code(const string &language_code) {
  if (language_code.empty()) {
    return Status::OK();
  }
  if (language_code.size() == 2 && 'a' <= language_code[0] && language_code[0] <= 'z' && 'a' <= language_code[1] &&
      language_code[1] <= 'z') {
    return Status::OK();
  }
  return Status::Error(400, "Invalid language code specified");
}

vector<int32> search_strings_by_prefix(const vector<string> &strings, const string &query, int32 limit,
                                       bool return_all_for_empty_query, int32 &total_count) {
  Hints hints;
  for (size_t i = 0; i < strings.size(); i++) {
    const auto &str = strings[i];
    hints.add(i, str.empty() ? Slice(" ") : Slice(str));
    hints.set_rating(i, i);
  }
  auto result = hints.search(query, limit, return_all_for_empty_query);
  total_count = narrow_cast<int32>(result.first);
  return transform(result.second, [](int64 key) { return narrow_cast<int32>(key); });
}

}  // namespace td
