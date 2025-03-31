//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Birthdate.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void Birthdate::store(StorerT &storer) const {
  td::store(birthdate_, storer);
}

template <class ParserT>
void Birthdate::parse(ParserT &parser) {
  td::parse(birthdate_, parser);
}

}  // namespace td
