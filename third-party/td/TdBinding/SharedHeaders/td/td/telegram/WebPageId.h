//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

#include <type_traits>

namespace td {

class WebPageId {
  int64 id = 0;

 public:
  WebPageId() = default;

  explicit constexpr WebPageId(int64 web_page_id) : id(web_page_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  WebPageId(T web_page_id) = delete;

  int64 get() const {
    return id;
  }

  bool operator==(const WebPageId &other) const {
    return id == other.id;
  }

  bool operator!=(const WebPageId &other) const {
    return id != other.id;
  }

  bool is_valid() const {
    return id != 0;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(id, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(id, parser);
  }
};

struct WebPageIdHash {
  uint32 operator()(WebPageId web_page_id) const {
    return Hash<int64>()(web_page_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, WebPageId web_page_id) {
  return string_builder << "link preview " << web_page_id.get();
}

}  // namespace td
