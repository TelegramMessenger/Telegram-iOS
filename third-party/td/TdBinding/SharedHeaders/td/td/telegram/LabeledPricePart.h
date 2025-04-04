//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct LabeledPricePart {
  string label;
  int64 amount = 0;

  LabeledPricePart() = default;
  LabeledPricePart(string &&label, int64 amount) : label(std::move(label)), amount(amount) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_string(label);
    storer.store_binary(amount);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    label = parser.template fetch_string<string>();
    amount = parser.fetch_long();
  }
};

inline bool operator==(const LabeledPricePart &lhs, const LabeledPricePart &rhs) {
  return lhs.label == rhs.label && lhs.amount == rhs.amount;
}

inline bool operator!=(const LabeledPricePart &lhs, const LabeledPricePart &rhs) {
  return !(lhs == rhs);
}

inline StringBuilder &operator<<(StringBuilder &string_builder, const LabeledPricePart &labeled_price_part) {
  return string_builder << '[' << labeled_price_part.label << ": " << labeled_price_part.amount << ']';
}

}  // namespace td
