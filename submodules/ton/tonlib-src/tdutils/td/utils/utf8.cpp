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
#include "td/utils/utf8.h"

#include "td/utils/logging.h"  // for UNREACHABLE
#include "td/utils/unicode.h"

namespace td {

bool check_utf8(CSlice str) {
  const char *data = str.data();
  const char *data_end = data + str.size();
  do {
    unsigned int a = static_cast<unsigned char>(*data++);
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

    unsigned int b = static_cast<unsigned char>(*data++);
    ENSURE((b & 0xc0) == 0x80);
    if ((a & 0x20) == 0) {
      ENSURE((a & 0x1e) > 0);
      continue;
    }

    unsigned int c = static_cast<unsigned char>(*data++);
    ENSURE((c & 0xc0) == 0x80);
    if ((a & 0x10) == 0) {
      int x = (((a & 0x0f) << 6) | (b & 0x20));
      ENSURE(x != 0 && x != 0x360);  // surrogates
      continue;
    }

    unsigned int d = static_cast<unsigned char>(*data++);
    ENSURE((d & 0xc0) == 0x80);
    if ((a & 0x08) == 0) {
      int t = (((a & 0x07) << 6) | (b & 0x30));
      ENSURE(0 < t && t < 0x110);  // end of unicode
      continue;
    }

    return false;
#undef ENSURE
  } while (true);

  UNREACHABLE();
  return false;
}

void append_utf8_character(string &str, uint32 ch) {
  if (ch <= 0x7f) {
    str.push_back(static_cast<char>(ch));
  } else if (ch <= 0x7ff) {
    str.push_back(static_cast<char>(0xc0 | (ch >> 6)));  // implementation-defined
    str.push_back(static_cast<char>(0x80 | (ch & 0x3f)));
  } else if (ch <= 0xffff) {
    str.push_back(static_cast<char>(0xe0 | (ch >> 12)));  // implementation-defined
    str.push_back(static_cast<char>(0x80 | ((ch >> 6) & 0x3f)));
    str.push_back(static_cast<char>(0x80 | (ch & 0x3f)));
  } else {
    str.push_back(static_cast<char>(0xf0 | (ch >> 18)));  // implementation-defined
    str.push_back(static_cast<char>(0x80 | ((ch >> 12) & 0x3f)));
    str.push_back(static_cast<char>(0x80 | ((ch >> 6) & 0x3f)));
    str.push_back(static_cast<char>(0x80 | (ch & 0x3f)));
  }
}

const unsigned char *next_utf8_unsafe(const unsigned char *ptr, uint32 *code, const char *source) {
  uint32 a = ptr[0];
  if ((a & 0x80) == 0) {
    if (code) {
      *code = a;
    }
    return ptr + 1;
  } else if ((a & 0x20) == 0) {
    if (code) {
      *code = ((a & 0x1f) << 6) | (ptr[1] & 0x3f);
    }
    return ptr + 2;
  } else if ((a & 0x10) == 0) {
    if (code) {
      *code = ((a & 0x0f) << 12) | ((ptr[1] & 0x3f) << 6) | (ptr[2] & 0x3f);
    }
    return ptr + 3;
  } else if ((a & 0x08) == 0) {
    if (code) {
      *code = ((a & 0x07) << 18) | ((ptr[1] & 0x3f) << 12) | ((ptr[2] & 0x3f) << 6) | (ptr[3] & 0x3f);
    }
    return ptr + 4;
  }
  LOG(FATAL) << a << " " << source;
  if (code) {
    *code = 0;
  }
  return ptr;
}

string utf8_to_lower(Slice str) {
  string result;
  auto pos = str.ubegin();
  auto end = str.uend();
  while (pos != end) {
    uint32 code;
    pos = next_utf8_unsafe(pos, &code, "utf8_to_lower");
    append_utf8_character(result, unicode_to_lower(code));
  }
  return result;
}

}  // namespace td
