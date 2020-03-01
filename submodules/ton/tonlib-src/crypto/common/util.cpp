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
#include "util.h"

#include <limits>

#include "td/utils/crypto.h"
#include "td/utils/base64.h"

namespace td {

std::size_t compute_base64_encoded_size(size_t bindata_size) {
  return ((bindata_size + 2) / 3) << 2;
}

const char base64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const char base64_url_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
const unsigned char base64_dec_table[256] = {
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0x7e, 0,    0xbe, 0,    0x7f, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc,
    0xfd, 0,    0,    0,    1,    0,    0,    0,    0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca,
    0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0,    0,    0,    0,
    0xbf, 0,    0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
    0xeb, 0xec, 0xed, 0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf3, 0,    0,    0,    0,    0};

std::size_t buff_base64_encode(td::MutableSlice buffer, td::Slice raw, bool base64_url) {
  std::size_t orig_size = raw.size(), res_size = compute_base64_encoded_size(orig_size);
  if (res_size > buffer.size()) {
    return 0;
  }
  const char *table = base64_url ? base64_url_table : base64_table;
  char *wptr = buffer.data();
  unsigned x;
  std::size_t i;
  for (i = 0; i < orig_size - 2; i += 3) {
    x = (((unsigned)(unsigned char)raw[i]) << 16) | (((unsigned)(unsigned char)raw[i + 1]) << 8) |
        ((unsigned)(unsigned char)raw[i + 2]);
    *wptr++ = table[(x >> 18) & 0x3f];
    *wptr++ = table[(x >> 12) & 0x3f];
    *wptr++ = table[(x >> 6) & 0x3f];
    *wptr++ = table[x & 0x3f];
  }
  switch (orig_size - i) {
    case 1:
      x = (((unsigned)(unsigned char)raw[i]) << 16);
      *wptr++ = table[(x >> 18) & 0x3f];
      *wptr++ = table[(x >> 12) & 0x3f];
      *wptr++ = '=';
      *wptr++ = '=';
      break;
    case 2:
      x = (((unsigned)(unsigned char)raw[i]) << 16) | (((unsigned)(unsigned char)raw[i + 1]) << 8);
      *wptr++ = table[(x >> 18) & 0x3f];
      *wptr++ = table[(x >> 12) & 0x3f];
      *wptr++ = table[(x >> 6) & 0x3f];
      *wptr++ = '=';
  }
  CHECK(wptr == buffer.data() + res_size);
  return res_size;
}

std::string str_base64_encode(td::Slice raw, bool base64_url) {
  std::size_t res_size = compute_base64_encoded_size(raw.size());
  std::string s;
  s.resize(res_size);
  if (res_size) {
    buff_base64_encode(td::MutableSlice{const_cast<char *>(s.data()), s.size()}, raw, base64_url);
  }
  return s;
}

bool is_valid_base64(td::Slice encoded, bool allow_base64_url) {
  const unsigned char *ptr = (const unsigned char *)encoded.data(), *end = ptr + encoded.size();
  if (encoded.size() & 3) {
    return false;
  }
  unsigned mode = (allow_base64_url ? 0xc0 : 0x40);
  while (ptr < end && (base64_dec_table[*ptr] & mode)) {
    ptr++;
  }
  std::size_t d = end - ptr;
  if (d > 2) {
    return false;
  }
  while (ptr < end && *ptr == '=') {
    ptr++;
  }
  return ptr == end;
}

td::int32 decoded_base64_size(td::Slice encoded, bool allow_base64_url) {
  const unsigned char *ptr = (const unsigned char *)encoded.data(), *end = ptr + encoded.size();
  if (encoded.size() & 3) {
    return -1;
  }
  if (encoded.size() > static_cast<size_t>(std::numeric_limits<td::int32>::max())) {
    return -1;
  }
  if (end == ptr) {
    return 0;
  }
  auto s = static_cast<td::int32>((encoded.size() >> 2) * 3);
  if (end[-1] == '=') {
    s--;
    if (end[-2] == '=') {
      s--;
    }
  }
  return s;
}

std::size_t buff_base64_decode(td::MutableSlice buffer, td::Slice encoded, bool allow_base64_url) {
  if ((encoded.size() & 3) || !encoded.size()) {
    return 0;
  }
  std::size_t n = (encoded.size() >> 2);
  const unsigned char *ptr = (const unsigned char *)encoded.data(), *end = ptr + encoded.size();
  unsigned q = (end[-1] == '=' ? (end[-2] == '=' ? 2 : 1) : 0);
  if (buffer.size() + q < n * 3) {
    return 0;
  }
  unsigned char *wptr = (unsigned char *)buffer.data(), *wend = wptr + buffer.size();
  unsigned mode = (allow_base64_url ? 0xc0 : 0x40);
  for (std::size_t i = 0; i < n; i++) {
    unsigned x = 0;
    for (std::size_t j = 0; j < 4; j++) {
      unsigned z = base64_dec_table[ptr[4 * i + j]];
      if (!(z & mode) && z != 1 && (i < n - 1 || j + q < 4)) {
        return 0;
      }
      x = (x << 6) | (z & 0x3f);
    }
    if (i < n - 1) {
      *wptr++ = (unsigned char)(x >> 16);
      *wptr++ = (unsigned char)(x >> 8);
      *wptr++ = (unsigned char)x;
    } else {
      for (; q < 3; q++) {
        *wptr++ = (unsigned char)(x >> 16);
        x <<= 8;
      }
      break;
    }
  }
  CHECK(wptr <= wend);
  return wptr - (unsigned char *)buffer.data();
}

td::BufferSlice base64_decode(td::Slice encoded, bool allow_base64_url) {
  auto s = decoded_base64_size(encoded, allow_base64_url);
  if (s <= 0) {
    return td::BufferSlice{};
  }
  td::BufferSlice res{static_cast<std::size_t>(s)};
  auto r = buff_base64_decode(res.as_slice(), encoded, allow_base64_url);
  if (!r) {
    return td::BufferSlice{};
  }
  CHECK(r == static_cast<std::size_t>(s));
  return res;
}

std::string str_base64_decode(td::Slice encoded, bool allow_base64_url) {
  auto s = decoded_base64_size(encoded, allow_base64_url);
  if (s <= 0) {
    return std::string{};
  }
  std::string res;
  res.resize(static_cast<std::size_t>(s));
  auto r = buff_base64_decode(td::MutableSlice{const_cast<char *>(res.data()), res.size()}, encoded, allow_base64_url);
  if (!r) {
    return std::string{};
  }
  CHECK(r == static_cast<std::size_t>(s));
  return res;
}

td::Result<std::string> adnl_id_encode(td::Slice id, bool upper_case) {
  if (id.size() != 32) {
    return td::Status::Error("Wrong andl id size");
  }
  td::uint8 buf[35];
  td::MutableSlice buf_slice(buf, 35);
  buf_slice[0] = 0x2d;
  buf_slice.substr(1).copy_from(id);
  auto hash = td::crc16(buf_slice.substr(0, 33));
  buf[33] = static_cast<td::uint8>((hash >> 8) & 255);
  buf[34] = static_cast<td::uint8>(hash & 255);
  return td::base32_encode(buf_slice, upper_case).substr(1);
}

std::string adnl_id_encode(td::Bits256 adnl_addr, bool upper_case) {
  return adnl_id_encode(adnl_addr.as_slice(), upper_case).move_as_ok();
}

td::Result<Bits256> adnl_id_decode(td::Slice id) {
  if (id.size() != 55) {
    return td::Status::Error("Wrong length of adnl id");
  }
  td::uint8 buf[56];
  buf[0] = 'f';
  td::MutableSlice buf_slice(buf, 56);
  buf_slice.substr(1).copy_from(id);
  TRY_RESULT(decoded_str, td::base32_decode(buf_slice));
  auto decoded = td::Slice(decoded_str);
  if (decoded[0] != 0x2d) {
    return td::Status::Error("Invalid first byte");
  }
  auto got_hash = (decoded.ubegin()[33] << 8) | decoded.ubegin()[34];
  auto hash = td::crc16(decoded.substr(0, 33));
  if (hash != got_hash) {
    return td::Status::Error("Hash mismatch");
  }
  Bits256 res;
  res.as_slice().copy_from(decoded.substr(1, 32));
  return res;
}

}  // namespace td
