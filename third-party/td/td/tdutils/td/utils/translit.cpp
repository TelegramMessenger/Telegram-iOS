//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/translit.h"

#include "td/utils/algorithm.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/misc.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <utility>

namespace td {

static const FlatHashMap<uint32, string> &get_en_to_ru_simple_rules() {
  static const FlatHashMap<uint32, string> rules{
      {'a', "а"}, {'b', "б"}, {'c', "к"}, {'d', "д"}, {'e', "е"}, {'f', "ф"},  {'g', "г"}, {'h', "х"}, {'i', "и"},
      {'j', "й"}, {'k', "к"}, {'l', "л"}, {'m', "м"}, {'n', "н"}, {'o', "о"},  {'p', "п"}, {'q', "к"}, {'r', "р"},
      {'s', "с"}, {'t', "т"}, {'u', "у"}, {'v', "в"}, {'w', "в"}, {'x', "кс"}, {'y', "и"}, {'z', "з"}};
  return rules;
}

static const std::vector<std::pair<string, string>> &get_en_to_ru_complex_rules() {
  static const std::vector<std::pair<string, string>> rules{
      {"ch", "ч"}, {"ei", "ей"}, {"ey", "ей"}, {"ia", "ия"},  {"iy", "ий"}, {"jo", "е"},
      {"ju", "ю"}, {"ja", "я"},  {"kh", "х"},  {"shch", "щ"}, {"sh", "ш"},  {"sch", "щ"},
      {"ts", "ц"}, {"yo", "е"},  {"yu", "ю"},  {"ya", "я"},   {"zh", "ж"}};
  return rules;
}

static const FlatHashMap<uint32, string> &get_ru_to_en_simple_rules() {
  static const FlatHashMap<uint32, string> rules{
      {0x430, "a"},  {0x431, "b"},  {0x432, "v"},  {0x433, "g"},  {0x434, "d"},  {0x435, "e"},   {0x451, "e"},
      {0x436, "zh"}, {0x437, "z"},  {0x438, "i"},  {0x439, "y"},  {0x43a, "k"},  {0x43b, "l"},   {0x43c, "m"},
      {0x43d, "n"},  {0x43e, "o"},  {0x43f, "p"},  {0x440, "r"},  {0x441, "s"},  {0x442, "t"},   {0x443, "u"},
      {0x444, "f"},  {0x445, "kh"}, {0x446, "ts"}, {0x447, "ch"}, {0x448, "sh"}, {0x449, "sch"}, {0x44a, ""},
      {0x44b, "y"},  {0x44c, ""},   {0x44d, "e"},  {0x44e, "yu"}, {0x44f, "ya"}};
  return rules;
}

static const std::vector<std::pair<string, string>> &get_ru_to_en_complex_rules() {
  static const std::vector<std::pair<string, string>> rules{
      {"ий", "y"}, {"ия", "ia"}, {"кс", "x"}, {"yo", "e"}, {"jo", "e"}};
  return rules;
}

static void add_word_transliterations(vector<string> &result, Slice word, bool allow_partial,
                                      const FlatHashMap<uint32, string> &simple_rules,
                                      const vector<std::pair<string, string>> &complex_rules) {
  string s;
  auto pos = word.ubegin();
  auto end = word.uend();
  while (pos != end) {
    uint32 code;
    pos = next_utf8_unsafe(pos, &code);
    auto it = simple_rules.find(code);
    if (it != simple_rules.end()) {
      s += it->second;
    } else {
      append_utf8_character(s, code);
    }
  }
  if (!s.empty()) {
    result.push_back(std::move(s));
    s.clear();
  }

  pos = word.ubegin();
  while (pos != end) {
    auto suffix = Slice(pos, end);
    bool found = false;
    for (auto &rule : complex_rules) {
      if (begins_with(suffix, rule.first)) {
        found = true;
        pos += rule.first.size();
        s.append(rule.second);
        break;
      }
      if (allow_partial && begins_with(rule.first, suffix)) {
        result.push_back(s + rule.second);
      }
    }
    if (found) {
      continue;
    }

    uint32 code;
    pos = next_utf8_unsafe(pos, &code);
    auto it = simple_rules.find(code);
    if (it != simple_rules.end()) {
      s += it->second;
    } else {
      append_utf8_character(s, code);
    }
  }
  if (!s.empty()) {
    result.push_back(std::move(s));
  }
}

vector<string> get_word_transliterations(Slice word, bool allow_partial) {
  vector<string> result;

  add_word_transliterations(result, word, allow_partial, get_en_to_ru_simple_rules(), get_en_to_ru_complex_rules());
  add_word_transliterations(result, word, allow_partial, get_ru_to_en_simple_rules(), get_ru_to_en_complex_rules());

  td::unique(result);
  return result;
}

}  // namespace td
