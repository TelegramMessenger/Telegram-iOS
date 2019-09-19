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

#include "td/utils/common.h"

namespace td {

enum class UnicodeSimpleCategory { Unknown, Letter, DecimalNumber, Number, Separator };

UnicodeSimpleCategory get_unicode_simple_category(uint32 code);

/**
 * Prepares unicode character for search, leaving only digits and lowercased letters.
 * Return code of replacing character or 0 if the character should be skipped.
 */
uint32 prepare_search_character(uint32 code);

/**
 * Converts unicode character to lower case.
 */
uint32 unicode_to_lower(uint32 code);

/**
 * Removes diacritics from a unicode character.
 */
uint32 remove_diacritics(uint32 code);

}  // namespace td
