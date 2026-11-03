//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class BusinessIntro {
 public:
  BusinessIntro() = default;

  BusinessIntro(Td *td, telegram_api::object_ptr<telegram_api::businessIntro> intro);

  BusinessIntro(Td *td, td_api::object_ptr<td_api::inputBusinessStartPage> intro);

  td_api::object_ptr<td_api::businessStartPage> get_business_start_page_object(Td *td) const;

  telegram_api::object_ptr<telegram_api::inputBusinessIntro> get_input_business_intro(Td *td) const;

  bool is_empty() const {
    return title_.empty() && description_.empty() && !sticker_file_id_.is_valid();
  }

  vector<FileId> get_file_ids(const Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  string title_;
  string description_;
  FileId sticker_file_id_;

  friend bool operator==(const BusinessIntro &lhs, const BusinessIntro &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessIntro &intro);
};

bool operator==(const BusinessIntro &lhs, const BusinessIntro &rhs);

inline bool operator!=(const BusinessIntro &lhs, const BusinessIntro &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessIntro &intro);

}  // namespace td
