//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/BinlogEvent.h"

#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

namespace td {

void BinlogEvent::init(string raw_event) {
  TlParser parser(as_slice(raw_event));
  size_ = static_cast<uint32>(parser.fetch_int());
  LOG_CHECK(size_ == raw_event.size()) << size_ << ' ' << raw_event.size() << debug_info_;
  id_ = static_cast<uint64>(parser.fetch_long());
  type_ = parser.fetch_int();
  flags_ = parser.fetch_int();
  extra_ = static_cast<uint64>(parser.fetch_long());
  CHECK(size_ >= MIN_SIZE);
  parser.template fetch_string_raw<Slice>(size_ - MIN_SIZE);  // skip data
  crc32_ = static_cast<uint32>(parser.fetch_int());
  raw_event_ = std::move(raw_event);
}

Slice BinlogEvent::get_data() const {
  CHECK(raw_event_.size() >= MIN_SIZE);
  return Slice(as_slice(raw_event_).data() + HEADER_SIZE, raw_event_.size() - MIN_SIZE);
}

Status BinlogEvent::validate() const {
  if (raw_event_.size() < MIN_SIZE) {
    return Status::Error("Too small event");
  }
  TlParser parser(as_slice(raw_event_));
  auto size = static_cast<uint32>(parser.fetch_int());
  if (size_ != size || size_ != raw_event_.size()) {
    return Status::Error(PSLICE() << "Size of event changed: " << tag("was", size_) << tag("now", size)
                                  << tag("real size", raw_event_.size()));
  }
  parser.template fetch_string_raw<Slice>(size_ - TAIL_SIZE - sizeof(int));  // skip
  auto stored_crc32 = static_cast<uint32>(parser.fetch_int());
  auto calculated_crc = crc32(Slice(as_slice(raw_event_).data(), size_ - TAIL_SIZE));
  if (calculated_crc != crc32_ || calculated_crc != stored_crc32) {
    return Status::Error(PSLICE() << "CRC mismatch " << tag("actual", format::as_hex(calculated_crc))
                                  << tag("expected", format::as_hex(crc32_)) << public_to_string());
  }
  return Status::OK();
}

BufferSlice BinlogEvent::create_raw(uint64 id, int32 type, int32 flags, const Storer &storer) {
  auto raw_event = BufferSlice{storer.size() + MIN_SIZE};

  TlStorerUnsafe tl_storer(raw_event.as_mutable_slice().ubegin());
  tl_storer.store_int(narrow_cast<int32>(raw_event.size()));
  tl_storer.store_long(id);
  tl_storer.store_int(type);
  tl_storer.store_int(flags);
  tl_storer.store_long(0);

  CHECK(tl_storer.get_buf() == raw_event.as_slice().ubegin() + HEADER_SIZE);
  tl_storer.store_storer(storer);

  CHECK(tl_storer.get_buf() == raw_event.as_slice().uend() - TAIL_SIZE);
  tl_storer.store_int(crc32(raw_event.as_slice().truncate(raw_event.size() - TAIL_SIZE)));

  return raw_event;
}

}  // namespace td
