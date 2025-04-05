//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/MessageId.h"

#include "td/utils/Random.h"
#include "td/utils/StorerBase.h"

namespace td {
namespace mtproto {

class NoCryptoImpl {
 public:
  NoCryptoImpl(MessageId message_id, const Storer &data, bool need_pad = true) : message_id_(message_id), data_(data) {
    if (need_pad) {
      size_t pad_size = -static_cast<int>(data_.size()) & 15;
      pad_size += 16 * (static_cast<size_t>(Random::secure_int32()) % 16);
      pad_.resize(pad_size);
      Random::secure_bytes(pad_);
    }
  }

  template <class StorerT>
  void do_store(StorerT &storer) const {
    storer.store_binary(message_id_.get());
    storer.store_binary(static_cast<int32>(data_.size() + pad_.size()));
    storer.store_storer(data_);
    storer.store_slice(pad_);
  }

 private:
  MessageId message_id_;
  const Storer &data_;
  std::string pad_;
};

}  // namespace mtproto
}  // namespace td
