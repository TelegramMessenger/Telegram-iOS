//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Dimensions.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(Dimensions dimensions, StorerT &storer) {
  store(static_cast<uint32>((static_cast<uint32>(dimensions.width) << 16) | dimensions.height), storer);
}

template <class ParserT>
void parse(Dimensions &dimensions, ParserT &parser) {
  uint32 width_height;
  parse(width_height, parser);
  dimensions.width = static_cast<uint16>(width_height >> 16);
  dimensions.height = static_cast<uint16>(width_height & 0xFFFF);
}

}  // namespace td
