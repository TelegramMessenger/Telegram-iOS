//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Hash.h"

#if TD_HAVE_ABSL
#include <absl/container/flat_hash_map.h>
#else
#include <unordered_map>
#endif

namespace td {

#if TD_HAVE_ABSL
template <class Key, class Value, class H = AbslHash<Key>>
using HashMap = absl::flat_hash_map<Key, Value, H>;
#else
template <class Key, class Value, class H = AbslHash<Key>>
using HashMap = std::unordered_map<Key, Value, H>;
#endif

}  // namespace td
