//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/utf8.h"

#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/unicode.h"

namespace td {

bool check_utf8(CSlice str) {
  const char *data = str.data();
  const char *data_end = data + str.size();
  do {
    uint32 a = static_cast<unsigned char>(*data++);
    if ((a & 0x80) == 0) {
      if (data == data_end + 1) {
        return true;
      }
      continue;
    }

#define ENSURE(condition) \
  if (!(condition)) {     \
    return false;         \
  }

    ENSURE((a & 0x40) != 0);

    uint32 b = static_cast<unsigned char>(*data++);
    ENSURE((b & 0xc0) == 0x80);
    if ((a & 0x20) == 0) {
      ENSURE((a & 0x1e) > 0);
      continue;
    }

    uint32 c = static_cast<unsigned char>(*data++);
    ENSURE((c & 0xc0) == 0x80);
    if ((a & 0x10) == 0) {
      uint32 x = (((a & 0x0f) << 6) | (b & 0x20));
      ENSURE(x != 0 && x != 0x360);  // surrogates
      continue;
    }

    uint32 d = static_cast<unsigned char>(*data++);
    ENSURE((d & 0xc0) == 0x80);
    if ((a & 0x08) == 0) {
      uint32 t = (((a & 0x07) << 6) | (b & 0x30));
      ENSURE(0 < t && t < 0x110);  // end of unicode
      continue;
    }

    return false;
#undef ENSURE
  } while (true);

  UNREACHABLE();
  return false;
}

const unsigned char *next_utf8_unsafe(const unsigned char *ptr, uint32 *code) {
  uint32 a = ptr[0];
  if ((a & 0x80) == 0) {
    *code = a;
    return ptr + 1;
  } else if ((a & 0x20) == 0) {
    *code = ((a & 0x1f) << 6) | (ptr[1] & 0x3f);
    return ptr + 2;
  } else if ((a & 0x10) == 0) {
    *code = ((a & 0x0f) << 12) | ((ptr[1] & 0x3f) << 6) | (ptr[2] & 0x3f);
    return ptr + 3;
  } else if ((a & 0x08) == 0) {
    *code = ((a & 0x07) << 18) | ((ptr[1] & 0x3f) << 12) | ((ptr[2] & 0x3f) << 6) | (ptr[3] & 0x3f);
    return ptr + 4;
  }
  UNREACHABLE();
  *code = 0;
  return ptr;
}

unsigned char *append_utf8_character_unsafe(unsigned char *ptr, uint32 code) {
  if (code <= 0x7f) {
    *ptr++ = static_cast<unsigned char>(code);
  } else if (code <= 0x7ff) {
    *ptr++ = static_cast<unsigned char>(0xc0 | (code >> 6));
    *ptr++ = static_cast<unsigned char>(0x80 | (code & 0x3f));
  } else if (code <= 0xffff) {
    *ptr++ = static_cast<unsigned char>(0xe0 | (code >> 12));
    *ptr++ = static_cast<unsigned char>(0x80 | ((code >> 6) & 0x3f));
    *ptr++ = static_cast<unsigned char>(0x80 | (code & 0x3f));
  } else {
    *ptr++ = static_cast<unsigned char>(0xf0 | (code >> 18));
    *ptr++ = static_cast<unsigned char>(0x80 | ((code >> 12) & 0x3f));
    *ptr++ = static_cast<unsigned char>(0x80 | ((code >> 6) & 0x3f));
    *ptr++ = static_cast<unsigned char>(0x80 | (code & 0x3f));
  }
  return ptr;
}

string utf8_to_lower(Slice str) {
  string result;
  auto pos = str.ubegin();
  auto end = str.uend();
  while (pos != end) {
    uint32 code;
    pos = next_utf8_unsafe(pos, &code);
    append_utf8_character(result, unicode_to_lower(code));
  }
  return result;
}

vector<string> utf8_get_search_words(Slice str) {
  bool in_word = false;
  string word;
  vector<string> words;
  auto pos = str.ubegin();
  auto end = str.uend();
  while (pos != end) {
    uint32 code;
    pos = next_utf8_unsafe(pos, &code);

    code = prepare_search_character(code);
    if (code == 0) {
      continue;
    }
    if (code == ' ') {
      if (in_word) {
        words.push_back(std::move(word));
        word.clear();
        in_word = false;
      }
    } else {
      in_word = true;
      code = remove_diacritics(code);
      append_utf8_character(word, code);
    }
  }
  if (in_word) {
    words.push_back(std::move(word));
  }
  return words;
}

string utf8_prepare_search_string(Slice str) {
  return implode(utf8_get_search_words(str));
}

string utf8_encode(CSlice data) {
  if (check_utf8(data)) {
    return data.str();
  }
  return PSTRING() << "url_decode(" << url_encode(data) << ')';
}

size_t utf8_utf16_length(Slice str) {
  size_t result = 0;
  for (auto c : str) {
    result += is_utf8_character_first_code_unit(c) + ((c & 0xf8) == 0xf0);
  }
  return result;
}

Slice utf8_utf16_truncate(Slice str, size_t length) {
  for (size_t i = 0; i < str.size(); i++) {
    auto c = static_cast<unsigned char>(str[i]);
    if (is_utf8_character_first_code_unit(c)) {
      if (length <= 0) {
        return str.substr(0, i);
      } else {
        length--;
        if (c >= 0xf0) {  // >= 4 bytes in symbol => surrogate pair
          length--;
        }
      }
    }
  }
  return str;
}

Slice utf8_utf16_substr(Slice str, size_t offset) {
  if (offset == 0) {
    return str;
  }
  auto offset_pos = utf8_utf16_truncate(str, offset).size();
  return str.substr(offset_pos);
}

Slice utf8_utf16_substr(Slice str, size_t offset, size_t length) {
  return utf8_utf16_truncate(utf8_utf16_substr(str, offset), length);
}

}  // namespace td
