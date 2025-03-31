//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/PhotoSizeType.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(const PhotoSizeType &type, StorerT &storer) {
  store(type.type, storer);
}

template <class ParserT>
void parse(PhotoSizeType &type, ParserT &parser) {
  parse(type.type, parser);
  if (type.type < 0 || type.type >= 128) {
    parser.set_error("Wrong photo size type");
  }
}

}  // namespace td
