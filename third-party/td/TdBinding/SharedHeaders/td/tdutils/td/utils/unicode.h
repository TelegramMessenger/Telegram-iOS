//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

enum class UnicodeSimpleCategory { Unknown, Letter, DecimalNumber, Number, Separator };

UnicodeSimpleCategory get_unicode_simple_category(uint32 code);

/**
 * Prepares unicode character for search, leaving only digits and lowercased letters.
 * Returns code of replacing character or 0 if the character should be skipped.
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
