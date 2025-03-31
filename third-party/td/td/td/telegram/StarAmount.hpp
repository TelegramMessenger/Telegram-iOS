//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StarAmount.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StarAmount::store(StorerT &storer) const {
  td::store(star_count_, storer);
  td::store(nanostar_count_, storer);
}

template <class ParserT>
void StarAmount::parse(ParserT &parser) {
  td::parse(star_count_, parser);
  td::parse(nanostar_count_, parser);
}

}  // namespace td
