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

#include "td/utils/port/config.h"
#include "td/utils/port/platform.h"
#include "td/utils/Status.h"

namespace td {

enum class RlimitType { nofile, rss };

td::Status change_rlimit(RlimitType rlim_type, td::uint64 value, td::uint64 cap = 0);
td::Status change_maximize_rlimit(RlimitType rlim, td::uint64 value);

}  // namespace td
