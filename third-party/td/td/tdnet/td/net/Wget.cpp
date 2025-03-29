//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/Wget.h"

#include "td/net/HttpHeaderCreator.h"
#include "td/net/HttpOutboundConnection.h"
#include "td/net/SslStream.h"

#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/HttpUrl.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <limits>

namespace td {

Wget::Wget(Promise<unique_ptr<HttpQuery>> promise, string url, std::vector<std::pair<string, string>> headers,
           int32 timeout_in, int32 ttl, bool prefer_ipv6, SslCtx::VerifyPeer verify_peer, string content,
           string content_type)
    : promise_(std::move(promise))
    , input_url_(std::move(url))
    , headers_(std::move(headers))
    , timeout_in_(timeout_in)
    , ttl_(ttl)
    , prefer_ipv6_(prefer_ipv6)
    , verify_peer_(verify_peer)
    , content_(std::move(content))
    , content_type_(std::move(content_type)) {
}

Status Wget::try_init() {
  TRY_RESULT(url, parse_url(input_url_));
  TRY_RESULT_ASSIGN(url.host_, idn_to_ascii(url.host_));

  HttpHeaderCreator hc;
  if (content_.empty()) {
    hc.init_get(url.query_);
  } else {
    hc.init_post(url.query_);
    hc.set_content_size(content_.size());
    if (!content_type_.empty()) {
      hc.set_content_type(content_type_);
    }
  }
  bool was_host = false;
  bool was_accept_encoding = false;
  for (auto &header : headers_) {
    auto header_lower = to_lower(header.first);
    if (header_lower == "host") {
      was_host = true;
    }
    if (header_lower == "accept-encoding") {
      was_accept_encoding = true;
    }
    hc.add_header(header.first, header.second);
  }
  if (!was_host) {
    hc.add_header("Host", url.host_);
  }
  if (!was_accept_encoding) {
    hc.add_header("Accept-Encoding", "gzip, deflate");
  }
  TRY_RESULT(header, hc.finish(content_));

  IPAddress addr;
  TRY_STATUS(addr.init_host_port(url.host_, url.port_, prefer_ipv6_));

  TRY_RESULT(fd, SocketFd::open(addr));
  if (fd.empty()) {
    return Status::Error("Sockets are not supported");
  }
  if (url.protocol_ == HttpUrl::Protocol::Http) {
    connection_ = create_actor<HttpOutboundConnection>("Connect", BufferedFd<SocketFd>(std::move(fd)), SslStream{},
                                                       std::numeric_limits<std::size_t>::max(), 0, 0,
                                                       ActorOwn<HttpOutboundConnection::Callback>(actor_id(this)));
  } else {
    TRY_RESULT(ssl_ctx, SslCtx::create(CSlice() /* certificate */, verify_peer_));
    TRY_RESULT(ssl_stream, SslStream::create(url.host_, std::move(ssl_ctx)));
    connection_ = create_actor<HttpOutboundConnection>(
        "Connect", BufferedFd<SocketFd>(std::move(fd)), std::move(ssl_stream), std::numeric_limits<std::size_t>::max(),
        0, 0, ActorOwn<HttpOutboundConnection::Callback>(actor_id(this)));
  }

  send_closure(connection_, &HttpOutboundConnection::write_next, BufferSlice(header));
  send_closure(connection_, &HttpOutboundConnection::write_ok);
  return Status::OK();
}

void Wget::loop() {
  if (connection_.empty()) {
    auto status = try_init();
    if (status.is_error()) {
      return on_error(std::move(status));
    }
  }
}

void Wget::handle(unique_ptr<HttpQuery> result) {
  on_ok(std::move(result));
}

void Wget::on_connection_error(Status error) {
  on_error(std::move(error));
}

void Wget::on_ok(unique_ptr<HttpQuery> http_query_ptr) {
  CHECK(promise_);
  CHECK(http_query_ptr);
  if ((http_query_ptr->code_ == 301 || http_query_ptr->code_ == 302 || http_query_ptr->code_ == 307 ||
       http_query_ptr->code_ == 308) &&
      ttl_ > 0) {
    LOG(DEBUG) << *http_query_ptr;
    input_url_ = http_query_ptr->get_header("location").str();
    LOG(DEBUG) << input_url_;
    ttl_--;
    connection_.reset();
    yield();
  } else if (http_query_ptr->code_ >= 200 && http_query_ptr->code_ < 300) {
    promise_.set_value(std::move(http_query_ptr));
    stop();
  } else {
    on_error(Status::Error(PSLICE() << "HTTP error: " << http_query_ptr->code_));
  }
}

void Wget::on_error(Status error) {
  CHECK(error.is_error());
  CHECK(promise_);
  promise_.set_error(std::move(error));
  stop();
}

void Wget::start_up() {
  set_timeout_in(timeout_in_);
  loop();
}

void Wget::timeout_expired() {
  on_error(Status::Error("Response timeout expired"));
}

void Wget::tear_down() {
  if (promise_) {
    on_error(Status::Error("Canceled"));
  }
}

}  // namespace td
