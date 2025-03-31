//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/TransportType.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

class IStreamTransport {
 public:
  IStreamTransport() = default;
  IStreamTransport(const IStreamTransport &) = delete;
  IStreamTransport &operator=(const IStreamTransport &) = delete;
  virtual ~IStreamTransport() = default;
  virtual Result<size_t> read_next(BufferSlice *message, uint32 *quick_ack) = 0;
  virtual bool support_quick_ack() const = 0;
  virtual void write(BufferWriter &&message, bool quick_ack) = 0;
  virtual bool can_read() const = 0;
  virtual bool can_write() const = 0;
  virtual void init(ChainBufferReader *input, ChainBufferWriter *output) = 0;
  virtual size_t max_prepend_size() const = 0;
  virtual size_t max_append_size() const = 0;
  virtual TransportType get_type() const = 0;
  virtual bool use_random_padding() const = 0;
};

unique_ptr<IStreamTransport> create_transport(TransportType type);

}  // namespace mtproto
}  // namespace td
