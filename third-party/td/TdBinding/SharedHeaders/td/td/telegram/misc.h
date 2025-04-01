//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

// cleans user name/dialog title
string clean_name(string str, size_t max_length) TD_WARN_UNUSED_RESULT;

// prepares username/stickername for search
string clean_username(string str) TD_WARN_UNUSED_RESULT;

// prepares phone number for search
void clean_phone_number(string &phone_number);

// replaces some offending characters without changing string length
void replace_offending_characters(string &str);

// removes control characters from the string, will fail if input string is not in UTF-8
bool clean_input_string(string &str) TD_WARN_UNUSED_RESULT;

// strips empty characters and ensures that string length is no more than max_length
string strip_empty_characters(string str, size_t max_length, bool strip_rtlo = false) TD_WARN_UNUSED_RESULT;

// checks if string is empty after strip_empty_characters
bool is_empty_string(const string &str) TD_WARN_UNUSED_RESULT;

// checks whether a string could be a valid username
bool is_valid_username(Slice username);

// checks whether a string can be set as a username
bool is_allowed_username(Slice username);

// calculates truncated MD5 hash of a string
uint64 get_md5_string_hash(const string &str) TD_WARN_UNUSED_RESULT;

// calculates hash of list of uint64
int64 get_vector_hash(const vector<uint64> &numbers) TD_WARN_UNUSED_RESULT;

// returns emoji corresponding to the specified number
string get_emoji_fingerprint(uint64 num);

// checks whether currency amount is valid
bool check_currency_amount(int64 amount);

// checks whether language code is valid for bot settings
Status validate_bot_language_code(const string &language_code);

// returns 0-based indexes of strings matching the query by prefixes
vector<int32> search_strings_by_prefix(const vector<string> &strings, const string &query, int32 limit,
                                       bool return_all_for_empty_query, int32 &total_count);

}  // namespace td
