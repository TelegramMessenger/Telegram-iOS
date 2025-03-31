//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/FileReferenceManager.hpp"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/Td.h"

namespace td {

template <class StorerT>
void store(FileSourceId file_source_id, StorerT &storer) {
  Td *td = storer.context()->td().get_actor_unsafe();
  td->file_reference_manager_->store_file_source(file_source_id, storer);
}

template <class ParserT>
void parse(FileSourceId &file_source_id, ParserT &parser) {
  Td *td = parser.context()->td().get_actor_unsafe();
  file_source_id = td->file_reference_manager_->parse_file_source(td, parser);
}

}  // namespace td
