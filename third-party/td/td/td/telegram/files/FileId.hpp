//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"

#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileManager.hpp"
#include "td/telegram/Td.h"

namespace td {

template <class StorerT>
void store(const FileId &file_id, StorerT &storer) {
  storer.context()->td().get_actor_unsafe()->file_manager_->store_file(file_id, storer);
}

template <class ParserT>
void parse(FileId &file_id, ParserT &parser) {
  file_id = parser.context()->td().get_actor_unsafe()->file_manager_->parse_file(parser);
}

}  // namespace td
