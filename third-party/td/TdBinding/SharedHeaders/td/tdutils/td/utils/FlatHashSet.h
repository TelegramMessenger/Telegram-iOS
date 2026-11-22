//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

//#include "td/utils/FlatHashMapChunks.h"
#include "td/utils/FlatHashTable.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/SetNode.h"

#include <functional>
//#include <unordered_set>

namespace td {

template <class KeyT, class HashT = Hash<KeyT>, class EqT = std::equal_to<KeyT>>
using FlatHashSet = FlatHashTable<SetNode<KeyT, EqT>, HashT, EqT>;
//using FlatHashSet = FlatHashSetChunks<KeyT, HashT, EqT>;
//using FlatHashSet = std::unordered_set<KeyT, HashT, EqT>;

}  // namespace td
