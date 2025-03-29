//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpContentLengthByteFlow.h"

#include "td/utils/Status.h"

namespace td {

bool HttpContentLengthByteFlow::loop() {
  auto ready_size = input_->size();
  if (ready_size > len_) {
    ready_size = len_;
  }
  auto need_size = min(MIN_UPDATE_SIZE, len_);
  if (ready_size < need_size) {
    set_need_size(need_size);
    return false;
  }
  output_.append(input_->cut_head(ready_size));
  len_ -= ready_size;
  if (len_ == 0) {
    finish(Status::OK());
    return false;
  }
  if (!is_input_active_) {
    finish(Status::Error("Unexpected end of stream"));
    return false;
  }
  return true;
}

}  // namespace td
