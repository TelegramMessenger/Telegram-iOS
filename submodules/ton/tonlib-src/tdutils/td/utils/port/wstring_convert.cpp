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
#include "td/utils/port/wstring_convert.h"

char disable_linker_warning_about_empty_file_wstring_convert_cpp TD_UNUSED;

#if TD_PORT_WINDOWS

#include "td/utils/utf8.h"

#include <cwchar>

namespace td {

Result<std::wstring> to_wstring(CSlice slice) {
  if (!check_utf8(slice)) {
    return Status::Error("Wrong encoding");
  }

  size_t wstring_len = 0;
  for (auto c : slice) {
    wstring_len += ((c & 0xc0) != 0x80) + ((c & 0xf8) == 0xf0);
  }

  std::wstring result(wstring_len, static_cast<wchar_t>(0));
  if (wstring_len) {
    wchar_t *res = &result[0];
    for (size_t i = 0; i < slice.size();) {
      unsigned int a = static_cast<unsigned char>(slice[i++]);
      if (a >= 0x80) {
        unsigned int b = static_cast<unsigned char>(slice[i++]);
        if (a >= 0xe0) {
          unsigned int c = static_cast<unsigned char>(slice[i++]);
          if (a >= 0xf0) {
            unsigned int d = static_cast<unsigned char>(slice[i++]);
            unsigned int val = ((a & 0x07) << 18) + ((b & 0x3f) << 12) + ((c & 0x3f) << 6) + (d & 0x3f) - 0x10000;
            *res++ = static_cast<wchar_t>(0xD800 + (val >> 10));
            *res++ = static_cast<wchar_t>(0xDC00 + (val & 0x3ff));
          } else {
            *res++ = static_cast<wchar_t>(((a & 0x0f) << 12) + ((b & 0x3f) << 6) + (c & 0x3f));
          }
        } else {
          *res++ = static_cast<wchar_t>(((a & 0x1f) << 6) + (b & 0x3f));
        }
      } else {
        *res++ = static_cast<wchar_t>(a);
      }
    }
    CHECK(res == &result[0] + wstring_len);
  }
  return result;
}

Result<string> from_wstring(const wchar_t *begin, size_t size) {
  size_t result_len = 0;
  for (size_t i = 0; i < size; i++) {
    unsigned int cur = begin[i];
    if ((cur & 0xF800) == 0xD800) {
      if (i < size) {
        unsigned int next = begin[++i];
        if ((next & 0xFC00) == 0xDC00 && (cur & 0x400) == 0) {
          result_len += 4;
          continue;
        }
      }

      return Status::Error("Wrong encoding");
    }
    result_len += 1 + (cur >= 0x80) + (cur >= 0x800);
  }

  std::string result(result_len, '\0');
  if (result_len) {
    char *res = &result[0];
    for (size_t i = 0; i < size; i++) {
      unsigned int cur = begin[i];
      // TODO conversion unsigned int -> signed char is implementation defined
      if (cur <= 0x7f) {
        *res++ = static_cast<char>(cur);
      } else if (cur <= 0x7ff) {
        *res++ = static_cast<char>(0xc0 | (cur >> 6));
        *res++ = static_cast<char>(0x80 | (cur & 0x3f));
      } else if ((cur & 0xF800) != 0xD800) {
        *res++ = static_cast<char>(0xe0 | (cur >> 12));
        *res++ = static_cast<char>(0x80 | ((cur >> 6) & 0x3f));
        *res++ = static_cast<char>(0x80 | (cur & 0x3f));
      } else {
        unsigned int next = begin[++i];
        unsigned int val = ((cur - 0xD800) << 10) + next - 0xDC00 + 0x10000;

        *res++ = static_cast<char>(0xf0 | (val >> 18));
        *res++ = static_cast<char>(0x80 | ((val >> 12) & 0x3f));
        *res++ = static_cast<char>(0x80 | ((val >> 6) & 0x3f));
        *res++ = static_cast<char>(0x80 | (val & 0x3f));
      }
    }
  }
  return result;
}

Result<string> from_wstring(const std::wstring &str) {
  return from_wstring(str.data(), str.size());
}

Result<string> from_wstring(const wchar_t *begin) {
  return from_wstring(begin, std::wcslen(begin));
}

}  // namespace td

#endif
