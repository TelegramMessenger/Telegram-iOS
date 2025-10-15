//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class HttpHeaderCreator {
 public:
  static constexpr size_t MAX_HEADER = 4096;
  HttpHeaderCreator() : sb_(MutableSlice{header_, MAX_HEADER}) {
  }
  void init_ok() {
    sb_ = StringBuilder(MutableSlice{header_, MAX_HEADER});
    sb_ << "HTTP/1.1 200 OK\r\n";
  }
  void init_get(Slice url) {
    sb_ = StringBuilder(MutableSlice{header_, MAX_HEADER});
    sb_ << "GET " << url << " HTTP/1.1\r\n";
  }
  void init_post(Slice url) {
    sb_ = StringBuilder(MutableSlice{header_, MAX_HEADER});
    sb_ << "POST " << url << " HTTP/1.1\r\n";
  }
  void init_error(int code, Slice reason) {
    sb_ = StringBuilder(MutableSlice{header_, MAX_HEADER});
    sb_ << "HTTP/1.1 " << code << " " << reason << "\r\n";
  }
  void init_status_line(int http_status_code) {
    init_error(http_status_code, get_status_line(http_status_code));
  }
  void add_header(Slice key, Slice value) {
    sb_ << key << ": " << value << "\r\n";
  }
  void set_content_type(Slice type) {
    add_header("Content-Type", type);
  }
  void set_content_size(size_t size) {
    add_header("Content-Length", PSLICE() << size);
  }
  void set_keep_alive() {
    add_header("Connection", "keep-alive");
  }

  Result<Slice> finish(Slice content = {}) TD_WARN_UNUSED_RESULT {
    sb_ << "\r\n";
    if (!content.empty()) {
      sb_ << content;
    }
    if (sb_.is_error()) {
      return Status::Error("Too many headers");
    }
    return sb_.as_cslice();
  }

 private:
  static CSlice get_status_line(int http_status_code) {
    if (http_status_code == 200) {
      return CSlice("OK");
    }
    switch (http_status_code) {
      case 201:
        return CSlice("Created");
      case 202:
        return CSlice("Accepted");
      case 204:
        return CSlice("No Content");
      case 206:
        return CSlice("Partial Content");
      case 301:
        return CSlice("Moved Permanently");
      case 302:
        return CSlice("Found");
      case 303:
        return CSlice("See Other");
      case 304:
        return CSlice("Not Modified");
      case 307:
        return CSlice("Temporary Redirect");
      case 308:
        return CSlice("Permanent Redirect");
      case 400:
        return CSlice("Bad Request");
      case 401:
        return CSlice("Unauthorized");
      case 403:
        return CSlice("Forbidden");
      case 404:
        return CSlice("Not Found");
      case 405:
        return CSlice("Method Not Allowed");
      case 406:
        return CSlice("Not Acceptable");
      case 408:
        return CSlice("Request Timeout");
      case 409:
        return CSlice("Conflict");
      case 410:
        return CSlice("Gone");
      case 411:
        return CSlice("Length Required");
      case 412:
        return CSlice("Precondition Failed");
      case 413:
        return CSlice("Request Entity Too Large");
      case 414:
        return CSlice("Request-URI Too Long");
      case 415:
        return CSlice("Unsupported Media Type");
      case 416:
        return CSlice("Range Not Satisfiable");
      case 417:
        return CSlice("Expectation Failed");
      case 418:
        return CSlice("I'm a teapot");
      case 421:
        return CSlice("Misdirected Request");
      case 426:
        return CSlice("Upgrade Required");
      case 429:
        return CSlice("Too Many Requests");
      case 431:
        return CSlice("Request Header Fields Too Large");
      case 480:
        return CSlice("Temporarily Unavailable");
      case 501:
        return CSlice("Not Implemented");
      case 502:
        return CSlice("Bad Gateway");
      case 503:
        return CSlice("Service Unavailable");
      case 505:
        return CSlice("HTTP Version Not Supported");
      default:
        LOG_IF(ERROR, http_status_code != 500) << "Unsupported status code " << http_status_code << " returned";
        return CSlice("Internal Server Error");
    }
  }

  char header_[MAX_HEADER];
  StringBuilder sb_;
};

}  // namespace td
