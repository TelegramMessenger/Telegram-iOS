/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "auto/tl/tonlib_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace tonlib {
namespace tonlib_api = ton::tonlib_api;

class Logging {
 public:
  static td::Status set_current_stream(tonlib_api::object_ptr<tonlib_api::LogStream> stream);

  static td::Result<tonlib_api::object_ptr<tonlib_api::LogStream>> get_current_stream();

  static td::Status set_verbosity_level(int new_verbosity_level);

  static int get_verbosity_level();

  static std::vector<std::string> get_tags();

  static td::Status set_tag_verbosity_level(td::Slice tag, int new_verbosity_level);

  static td::Result<int> get_tag_verbosity_level(td::Slice tag);

  static void add_message(int log_verbosity_level, td::Slice message);
};

}  // namespace tonlib
