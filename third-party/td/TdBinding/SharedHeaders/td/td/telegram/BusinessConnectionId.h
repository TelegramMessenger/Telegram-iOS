//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

class BusinessConnectionId {
  string business_connection_id_;

 public:
  BusinessConnectionId() = default;

  explicit BusinessConnectionId(string &&business_connection_id)
      : business_connection_id_(std::move(business_connection_id)) {
  }

  explicit BusinessConnectionId(const string &business_connection_id)
      : business_connection_id_(business_connection_id) {
  }

  bool is_empty() const {
    return business_connection_id_.empty();
  }

  bool is_valid() const {
    return !business_connection_id_.empty();
  }

  const string &get() const {
    return business_connection_id_;
  }

  bool operator==(const BusinessConnectionId &other) const {
    return business_connection_id_ == other.business_connection_id_;
  }

  bool operator!=(const BusinessConnectionId &other) const {
    return business_connection_id_ != other.business_connection_id_;
  }

  telegram_api::object_ptr<telegram_api::Function> get_invoke_prefix() const {
    if (is_empty()) {
      return nullptr;
    }
    return telegram_api::make_object<telegram_api::invokeWithBusinessConnectionPrefix>(business_connection_id_);
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_string(business_connection_id_);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    business_connection_id_ = parser.template fetch_string<string>();
  }
};

struct BusinessConnectionIdHash {
  uint32 operator()(BusinessConnectionId business_connection_id) const {
    return Hash<string>()(business_connection_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, BusinessConnectionId business_connection_id) {
  return string_builder << "business connection " << business_connection_id.get();
}

}  // namespace td
