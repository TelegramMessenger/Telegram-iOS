//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/HttpTransport.h"

#include "td/net/HttpHeaderCreator.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

// TODO: do I need \r\n as delimiter?

#include <tuple>

namespace td {
namespace mtproto {
namespace http {

Result<size_t> Transport::read_next(BufferSlice *message, uint32 *quick_ack) {
  CHECK(can_read());
  auto r_size = reader_.read_next(&http_query_);
  if (r_size.is_error() || r_size.ok() != 0) {
    return r_size;
  }
  if (http_query_.type_ != HttpQuery::Type::Response) {
    return Status::Error("Unexpected HTTP query type");
  }
  if (http_query_.container_.size() != 2u) {
    return Status::Error("Wrong response");
  }
  *message = std::move(http_query_.container_[1]);
  turn_ = Write;
  return 0;
}

void Transport::write(BufferWriter &&message, bool quick_ack) {
  CHECK(can_write());
  CHECK(!quick_ack);
  /*
   * POST /api HTTP/1.1
   * Content-Length: [message->size()]
   * Host: url
   */
  HttpHeaderCreator hc;
  Slice host;
  Slice proxy_authorizarion;
  std::tie(host, proxy_authorizarion) = split(Slice(secret_), '|');
  if (host.empty()) {
    hc.init_post("/api");
    hc.add_header("Host", "");
    hc.set_keep_alive();
  } else {
    hc.init_post(PSLICE() << "HTTP://" << host << ":80/api");
    hc.add_header("Host", host);
    hc.add_header("User-Agent", "curl/7.35.0");
    hc.add_header("Accept", "*/*");
    hc.add_header("Proxy-Connection", "keep-alive");
    if (!proxy_authorizarion.empty()) {
      hc.add_header("Proxy-Authorization", proxy_authorizarion);
    }
  }
  hc.set_content_size(message.size());
  auto r_head = hc.finish();
  CHECK(r_head.is_ok());
  Slice src = r_head.ok();
  // LOG(DEBUG) << src;
  MutableSlice dst = message.prepare_prepend();
  dst.substr(dst.size() - src.size()).copy_from(src);
  message.confirm_prepend(src.size());
  output_->append(message.as_buffer_slice());
  turn_ = Read;
}

bool Transport::can_read() const {
  return turn_ == Read;
}

bool Transport::can_write() const {
  return turn_ == Write;
}

size_t Transport::max_prepend_size() const {
  if (secret_.empty()) {
    return 96;
  } else {
    return (secret_.size() + 1) / 2 * 4 + 156;
  }
}

size_t Transport::max_append_size() const {
  return 0;
}

bool Transport::use_random_padding() const {
  return false;
}

}  // namespace http
}  // namespace mtproto
}  // namespace td
