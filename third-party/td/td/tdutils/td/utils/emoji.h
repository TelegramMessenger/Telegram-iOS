//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

// checks whether the string is an emoji; variation selectors are ignored
bool is_emoji(Slice str);

// checks whether emoji ends on a Fitzpatrick modifier and returns it's number or 0
int get_fitzpatrick_modifier(Slice emoji);

// removes all Fitzpatrick modifier from the end of the string
Slice remove_fitzpatrick_modifier(Slice emoji);

// removes all emoji modifiers from the string
string remove_emoji_modifiers(Slice emoji, bool remove_selectors = true);

// removes all emoji modifiers from the string in-place
void remove_emoji_modifiers_in_place(string &emoji, bool remove_selectors = true);

// removes all emoji selectors from the string if it is an emoji
string remove_emoji_selectors(Slice emoji);

}  // namespace td
