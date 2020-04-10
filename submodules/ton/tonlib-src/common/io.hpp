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

#include "td/utils/buffer.h"
#include "td/utils/misc.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/base64.h"
#include "tl-utils/tl-utils.hpp"

#include "common/errorcode.h"
#include "common/status.h"
#include "keys/keys.hpp"

#include "crypto/common/bitstring.h"

namespace td {

template <unsigned size>
StringBuilder &operator<<(StringBuilder &stream, const td::BitArray<size> &x) {
  return stream << td::base64_encode(as_slice(x));
}

inline StringBuilder &operator<<(StringBuilder &stream, const ton::PublicKeyHash &value) {
  return stream << value.bits256_value();
}

}  // namespace td
