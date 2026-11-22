//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/IStreamTransport.h"
#include "td/mtproto/ProxySecret.h"
#include "td/mtproto/TransportType.h"

#include "td/net/HttpQuery.h"
#include "td/net/HttpReader.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {
namespace http {

class Transport final : public IStreamTransport {
 public:
  explicit Transport(string secret) : secret_(std::move(secret)) {
  }

  Result<size_t> read_next(BufferSlice *message, uint32 *quick_ack) final TD_WARN_UNUSED_RESULT;
  bool support_quick_ack() const final {
    return false;
  }
  void write(BufferWriter &&message, bool quick_ack) final;
  bool can_read() const final;
  bool can_write() const final;
  void init(ChainBufferReader *input, ChainBufferWriter *output) final {
    reader_.init(input);
    output_ = output;
  }

  size_t max_prepend_size() const final;
  size_t max_append_size() const final;
  TransportType get_type() const final {
    return {TransportType::Http, 0, ProxySecret::from_raw(secret_)};
  }
  bool use_random_padding() const final;

 private:
  string secret_;
  HttpReader reader_;
  HttpQuery http_query_;
  ChainBufferWriter *output_ = nullptr;
  enum { Write, Read } turn_ = Write;
};

}  // namespace http
}  // namespace mtproto
}  // namespace td
