//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/wstring_convert.h"

char disable_linker_warning_about_empty_file_wstring_convert_cpp TD_UNUSED;

#if TD_PORT_WINDOWS

#include "td/utils/base64.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/utf8.h"

#include <cwchar>

namespace td {

Result<std::wstring> to_wstring(CSlice slice) {
  if (!check_utf8(slice)) {
    return Status::Error(PSLICE() << "String was expected to be encoded in UTF-8: " << base64_encode(slice));
  }

  size_t wstring_len = utf8_utf16_length(slice);

  std::wstring result(wstring_len, static_cast<wchar_t>(0));
  if (wstring_len) {
    wchar_t *res = &result[0];
    for (size_t i = 0; i < slice.size();) {
      uint32 a = static_cast<unsigned char>(slice[i++]);
      if (a >= 0x80) {
        uint32 b = static_cast<unsigned char>(slice[i++]);
        if (a >= 0xe0) {
          uint32 c = static_cast<unsigned char>(slice[i++]);
          if (a >= 0xf0) {
            uint32 d = static_cast<unsigned char>(slice[i++]);
            uint32 val = ((a & 0x07) << 18) + ((b & 0x3f) << 12) + ((c & 0x3f) << 6) + (d & 0x3f) - 0x10000;
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
    uint32 cur = begin[i];
    if ((cur & 0xF800) == 0xD800) {
      if (i < size) {
        uint32 next = begin[++i];
        if ((next & 0xFC00) == 0xDC00 && (cur & 0x400) == 0) {
          result_len += 4;
          continue;
        }
      }

      return Status::Error("Wrong wstring encoding");
    }
    result_len += 1 + (cur >= 0x80) + (cur >= 0x800);
  }

  std::string result(result_len, '\0');
  if (result_len) {
    char *res = &result[0];
    for (size_t i = 0; i < size; i++) {
      uint32 cur = begin[i];
      // TODO conversion uint32 -> signed char is implementation defined
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
        uint32 next = begin[++i];
        uint32 val = ((cur - 0xD800) << 10) + next - 0xDC00 + 0x10000;

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
