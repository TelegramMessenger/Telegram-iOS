//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Slice.h"

#include <map>
#include <unordered_map>
#include <utility>

namespace td {

// TODO template KeyT
class Hints {
  using KeyT = int64;
  using RatingT = int64;

 public:
  void add(KeyT key, Slice name);

  void remove(KeyT key) {
    add(key, "");
  }

  void set_rating(KeyT key, RatingT rating);

  std::pair<size_t, vector<KeyT>> search(
      Slice query, int32 limit,
      bool return_all_for_empty_query = false) const;  // TODO sort by name instead of sort by rating

  bool has_key(KeyT key) const;

  string key_to_string(KeyT key) const;

  std::pair<size_t, vector<KeyT>> search_empty(int32 limit) const;  // == search("", limit, true)

  size_t size() const;

  static vector<string> fix_words(vector<string> words);

 private:
  std::map<string, vector<KeyT>> word_to_keys_;
  std::map<string, vector<KeyT>> translit_word_to_keys_;
  std::unordered_map<KeyT, string, Hash<KeyT>> key_to_name_;
  std::unordered_map<KeyT, RatingT, Hash<KeyT>> key_to_rating_;

  static void add_word(const string &word, KeyT key, std::map<string, vector<KeyT>> &word_to_keys);
  static void delete_word(const string &word, KeyT key, std::map<string, vector<KeyT>> &word_to_keys);

  static vector<string> get_words(Slice name);

  static void add_search_results(vector<KeyT> &results, const string &word,
                                 const std::map<string, vector<KeyT>> &word_to_keys);

  vector<KeyT> search_word(const string &word) const;

  class CompareByRating {
    const std::unordered_map<KeyT, RatingT, Hash<KeyT>> &key_to_rating_;

    RatingT get_rating(const KeyT &key) const {
      auto it = key_to_rating_.find(key);
      if (it == key_to_rating_.end()) {
        return RatingT();
      }
      return it->second;
    }

   public:
    explicit CompareByRating(const std::unordered_map<KeyT, RatingT, Hash<KeyT>> &key_to_rating)
        : key_to_rating_(key_to_rating) {
    }

    bool operator()(const KeyT &lhs, const KeyT &rhs) const {
      auto lhs_rating = get_rating(lhs);
      auto rhs_rating = get_rating(rhs);
      return lhs_rating < rhs_rating || (lhs_rating == rhs_rating && lhs < rhs);
    }
  };
};

}  // namespace td
