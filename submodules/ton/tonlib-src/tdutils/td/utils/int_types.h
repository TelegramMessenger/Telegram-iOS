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

#include "td/utils/port/platform.h"

#include <cstddef>
#include <cstdint>

namespace td {

#if !TD_WINDOWS
using size_t = std::size_t;
#endif

using int8 = std::int8_t;
using int16 = std::int16_t;
using uint16 = std::uint16_t;
using int32 = std::int32_t;
using uint32 = std::uint32_t;
using int64 = std::int64_t;
using uint64 = std::uint64_t;

static_assert(sizeof(std::uint8_t) == sizeof(unsigned char), "Unsigned char expected to be 8-bit");
using uint8 = unsigned char;

#if TD_MSVC
#pragma warning(push)
#pragma warning(disable : 4309)
#endif

static_assert(static_cast<char>(128) == -128 || static_cast<char>(128) == 128,
              "Unexpected cast to char implementation-defined behaviour");
static_assert(static_cast<char>(256) == 0, "Unexpected cast to char implementation-defined behaviour");
static_assert(static_cast<char>(-256) == 0, "Unexpected cast to char implementation-defined behaviour");

#if TD_MSVC
#pragma warning(pop)
#endif

}  // namespace td
