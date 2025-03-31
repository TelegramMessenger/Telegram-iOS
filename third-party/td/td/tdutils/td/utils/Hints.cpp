//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/Hints.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/translit.h"
#include "td/utils/utf8.h"

#include <algorithm>

namespace td {

vector<string> Hints::fix_words(vector<string> words) {
  std::sort(words.begin(), words.end());

  size_t new_words_size = 0;
  for (size_t i = 0; i != words.size(); i++) {
    if (i == words.size() - 1 || !begins_with(words[i + 1], words[i])) {
      if (i != new_words_size) {
        words[new_words_size] = std::move(words[i]);
      }
      new_words_size++;
    }
  }
  if (new_words_size == 1 && words[0].empty()) {
    new_words_size = 0;
  }
  words.resize(new_words_size);
  return words;
}

vector<string> Hints::get_words(Slice name) {
  return fix_words(utf8_get_search_words(name));
}

void Hints::add_word(const string &word, KeyT key, std::map<string, vector<KeyT>> &word_to_keys) {
  vector<KeyT> &keys = word_to_keys[word];
  CHECK(!td::contains(keys, key));
  keys.push_back(key);
}

void Hints::delete_word(const string &word, KeyT key, std::map<string, vector<KeyT>> &word_to_keys) {
  vector<KeyT> &keys = word_to_keys[word];
  auto key_it = std::find(keys.begin(), keys.end(), key);
  CHECK(key_it != keys.end());
  if (keys.size() == 1) {
    word_to_keys.erase(word);
  } else {
    CHECK(keys.size() > 1);
    *key_it = keys.back();
    keys.pop_back();
  }
}

void Hints::add(KeyT key, Slice name) {
  // LOG(ERROR) << "Add " << key << ": " << name;
  auto it = key_to_name_.find(key);
  if (it != key_to_name_.end()) {
    if (it->second == name) {
      return;
    }
    vector<string> old_transliterations;
    for (auto &old_word : get_words(it->second)) {
      delete_word(old_word, key, word_to_keys_);

      for (auto &w : get_word_transliterations(old_word, false)) {
        if (w != old_word) {
          old_transliterations.push_back(std::move(w));
        }
      }
    }
    for (auto &word : fix_words(old_transliterations)) {
      delete_word(word, key, translit_word_to_keys_);
    }
  }
  if (name.empty()) {
    if (it != key_to_name_.end()) {
      key_to_name_.erase(it);
    }
    key_to_rating_.erase(key);
    return;
  }

  vector<string> transliterations;
  for (auto &word : get_words(name)) {
    add_word(word, key, word_to_keys_);

    for (auto &w : get_word_transliterations(word, false)) {
      if (w != word) {
        transliterations.push_back(std::move(w));
      }
    }
  }
  for (auto &word : fix_words(transliterations)) {
    add_word(word, key, translit_word_to_keys_);
  }

  key_to_name_[key] = name.str();
}

void Hints::set_rating(KeyT key, RatingT rating) {
  // LOG(ERROR) << "Set rating " << key << ": " << rating;
  key_to_rating_[key] = rating;
}

void Hints::add_search_results(vector<KeyT> &results, const string &word,
                               const std::map<string, vector<KeyT>> &word_to_keys) {
  LOG(DEBUG) << "Search for word " << word;
  auto it = word_to_keys.lower_bound(word);
  while (it != word_to_keys.end() && begins_with(it->first, word)) {
    append(results, it->second);
    ++it;
  }
}

vector<Hints::KeyT> Hints::search_word(const string &word) const {
  vector<KeyT> results;
  add_search_results(results, word, translit_word_to_keys_);
  for (const auto &w : get_word_transliterations(word, true)) {
    add_search_results(results, w, word_to_keys_);
  }

  td::unique(results);
  return results;
}

std::pair<size_t, vector<Hints::KeyT>> Hints::search(Slice query, int32 limit, bool return_all_for_empty_query) const {
  // LOG(ERROR) << "Search " << query;
  vector<KeyT> results;

  if (limit < 0) {
    return {key_to_name_.size(), std::move(results)};
  }

  auto words = get_words(query);
  if (return_all_for_empty_query && words.empty()) {
    results.reserve(key_to_name_.size());
    for (auto &it : key_to_name_) {
      results.push_back(it.first);
    }
  }

  for (size_t i = 0; i < words.size(); i++) {
    vector<KeyT> keys = search_word(words[i]);
    if (i == 0) {
      results = std::move(keys);
      continue;
    }

    // now need to intersect two lists
    size_t results_pos = 0;
    size_t keys_pos = 0;
    size_t new_results_size = 0;
    while (results_pos != results.size() && keys_pos != keys.size()) {
      if (results[results_pos] < keys[keys_pos]) {
        results_pos++;
      } else if (results[results_pos] > keys[keys_pos]) {
        keys_pos++;
      } else {
        results[new_results_size++] = results[results_pos];
        results_pos++;
        keys_pos++;
      }
    }
    results.resize(new_results_size);
  }

  auto total_size = results.size();
  if (total_size < static_cast<size_t>(limit)) {
    std::sort(results.begin(), results.end(), CompareByRating(key_to_rating_));
  } else {
    std::partial_sort(results.begin(), results.begin() + limit, results.end(), CompareByRating(key_to_rating_));
    results.resize(limit);
  }

  return {total_size, std::move(results)};
}

bool Hints::has_key(KeyT key) const {
  return key_to_name_.count(key) > 0;
}

string Hints::key_to_string(KeyT key) const {
  auto it = key_to_name_.find(key);
  if (it == key_to_name_.end()) {
    return string();
  }
  return it->second;
}

std::pair<size_t, vector<Hints::KeyT>> Hints::search_empty(int32 limit) const {
  return search(Slice(), limit, true);
}

size_t Hints::size() const {
  return key_to_name_.size();
}

}  // namespace td
