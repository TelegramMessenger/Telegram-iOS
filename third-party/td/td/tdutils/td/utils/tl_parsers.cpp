//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/tl_parsers.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/utf8.h"

namespace td {

alignas(4) const unsigned char TlParser::empty_data[sizeof(UInt512)] = {};  // static zero-initialized

TlParser::TlParser(Slice slice) {
  data_len = left_len = slice.size();
  if (is_aligned_pointer<4>(slice.begin())) {
    data = slice.ubegin();
  } else {
    int32 *buf;
    if (data_len <= small_data_array.size() * sizeof(int32)) {
      buf = &small_data_array[0];
    } else {
      LOG(ERROR) << "Unexpected big unaligned data pointer of length " << slice.size() << " at " << slice.begin();
      data_buf = std::make_unique<int32[]>(1 + data_len / sizeof(int32));
      buf = data_buf.get();
    }
    std::memcpy(buf, slice.begin(), slice.size());
    data = reinterpret_cast<unsigned char *>(buf);
  }
}

void TlParser::set_error(const string &error_message) {
  if (error.empty()) {
    CHECK(!error_message.empty());
    error = error_message;
    error_pos = data_len - left_len;
    data = empty_data;
    left_len = 0;
    data_len = 0;
  } else {
    LOG_CHECK(error_pos != std::numeric_limits<size_t>::max() && data_len == 0 && left_len == 0)
        << data_len << ' ' << left_len << ' ' << data << ' ' << &empty_data[0] << ' ' << error_pos << ' ' << error;
    data = empty_data;
  }
}

BufferSlice TlBufferParser::as_buffer_slice(Slice slice) {
  if (slice.empty()) {
    return BufferSlice();
  }
  if (is_aligned_pointer<4>(slice.data())) {
    return parent_->from_slice(slice);
  }
  return BufferSlice(slice);
}

bool TlBufferParser::is_valid_utf8(CSlice str) const {
  if (check_utf8(str)) {
    return true;
  }
  LOG(WARNING) << "Wrong UTF-8 string [[" << str << "]] in " << format::as_hex_dump<4>(parent_->as_slice());
  return false;
}

size_t TlBufferParser::last_utf8_character_position(Slice str) {
  CHECK(!str.empty());
  size_t position = str.size() - 1;
  while (position != 0 && !is_utf8_character_first_code_unit(static_cast<unsigned char>(str[position]))) {
    position--;
  }
  return position;
}

}  // namespace td
