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

#include "auto/tl/ton_api.h"

#include "tl/tl_object_parse.h"
#include "td/utils/tl_parsers.h"

#include "crypto/common/bitstring.h"

#include "common-utils.hpp"

namespace ton {
td::BufferSlice serialize_tl_object(const ton_api::Object *T, bool boxed);
td::BufferSlice serialize_tl_object(const ton_api::Function *T, bool boxed);
td::BufferSlice serialize_tl_object(const ton_api::Object *T, bool boxed, td::BufferSlice &&suffix);
td::BufferSlice serialize_tl_object(const ton_api::Function *T, bool boxed, td::BufferSlice &&suffix);
td::BufferSlice serialize_tl_object(const ton_api::Object *T, bool boxed, td::Slice suffix);
td::BufferSlice serialize_tl_object(const ton_api::Function *T, bool boxed, td::Slice suffix);

td::UInt256 get_tl_object_sha256(const ton_api::Object *T);

template <class Tp, std::enable_if_t<std::is_base_of<ton_api::Object, Tp>::value>>
td::UInt256 get_tl_object_sha256(const Tp &T) {
  return get_tl_object_sha256(static_cast<const ton_api::Object *>(&T));
}

td::Bits256 get_tl_object_sha_bits256(const ton_api::Object *T);

template <class Tp, std::enable_if_t<std::is_base_of<ton_api::Object, Tp>::value>>
td::Bits256 get_tl_object_sha_bits256(const Tp &T) {
  return get_tl_object_sha_bits256(static_cast<const ton_api::Object *>(&T));
}
}  // namespace ton
