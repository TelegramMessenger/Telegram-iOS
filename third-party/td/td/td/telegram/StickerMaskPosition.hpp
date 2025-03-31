//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StickerMaskPosition.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StickerMaskPosition::store(StorerT &storer) const {
  td::store(point_, storer);
  td::store(x_shift_, storer);
  td::store(y_shift_, storer);
  td::store(scale_, storer);
}

template <class ParserT>
void StickerMaskPosition::parse(ParserT &parser) {
  td::parse(point_, parser);
  td::parse(x_shift_, parser);
  td::parse(y_shift_, parser);
  td::parse(scale_, parser);
}

}  // namespace td
