//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/KeyValueSyncInterface.h"

#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <memory>

namespace td {

class SecretChatDb {
 public:
  SecretChatDb(std::shared_ptr<KeyValueSyncInterface> pmc, int32 chat_id);

  // TODO: some other interface for PFS
  // two keys should be supported
  template <class ValueT>
  void set_value(const ValueT &data) {
    auto key = PSTRING() << "secret" << chat_id_ << ValueT::key();
    pmc_->set(std::move(key), serialize(data));
  }
  template <class ValueT>
  void erase_value(const ValueT &data) {
    auto key = PSTRING() << "secret" << chat_id_ << ValueT::key();
    pmc_->erase(std::move(key));
  }
  template <class ValueT>
  Result<ValueT> get_value() {
    ValueT value;
    auto key = PSTRING() << "secret" << chat_id_ << ValueT::key();
    auto value_str = pmc_->get(std::move(key));
    TRY_STATUS(unserialize(value, value_str));
    return std::move(value);
  }

 private:
  std::shared_ptr<KeyValueSyncInterface> pmc_;
  int32 chat_id_;
};

}  // namespace td
