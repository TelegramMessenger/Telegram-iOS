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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/Hash.h"

#if TD_HAVE_ABSL
#include <absl/container/flat_hash_set.h>
#else
#include <unordered_set>
#endif

namespace td {

#if TD_HAVE_ABSL
template <class Key, class H = Hash<Key>>
using HashSet = absl::flat_hash_set<Key, H>;
#else
template <class Key, class H = Hash<Key>>
using HashSet = std::unordered_set<Key, H>;
#endif

}  // namespace td
