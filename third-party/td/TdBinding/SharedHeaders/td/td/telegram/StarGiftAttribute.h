//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class StarGiftAttributeSticker {
  string name_;
  FileId sticker_file_id_;
  int32 rarity_permille_ = 0;

  friend bool operator==(const StarGiftAttributeSticker &lhs, const StarGiftAttributeSticker &rhs);

 public:
  StarGiftAttributeSticker() = default;

  StarGiftAttributeSticker(Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributeModel> &&attribute);

  StarGiftAttributeSticker(Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributePattern> &&attribute);

  bool is_valid() const {
    return 0 < rarity_permille_ && rarity_permille_ <= 1000 && sticker_file_id_.is_valid();
  }

  td_api::object_ptr<td_api::upgradedGiftModel> get_upgraded_gift_model_object(const Td *td) const;

  td_api::object_ptr<td_api::upgradedGiftSymbol> get_upgraded_gift_symbol_object(const Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarGiftAttributeSticker &lhs, const StarGiftAttributeSticker &rhs);

inline bool operator!=(const StarGiftAttributeSticker &lhs, const StarGiftAttributeSticker &rhs) {
  return !(lhs == rhs);
}

class StarGiftAttributeBackdrop {
  string name_;
  int32 center_color_ = 0;
  int32 edge_color_ = 0;
  int32 pattern_color_ = 0;
  int32 text_color_ = 0;
  int32 rarity_permille_ = 0;

  friend bool operator==(const StarGiftAttributeBackdrop &lhs, const StarGiftAttributeBackdrop &rhs);

  bool is_valid_color(int32 color) const {
    return 0 <= color && color <= 0xFFFFFF;
  }

 public:
  StarGiftAttributeBackdrop() = default;

  explicit StarGiftAttributeBackdrop(telegram_api::object_ptr<telegram_api::starGiftAttributeBackdrop> &&attribute);

  bool is_valid() const {
    return 0 < rarity_permille_ && rarity_permille_ <= 1000 && is_valid_color(center_color_) &&
           is_valid_color(edge_color_) && is_valid_color(pattern_color_) && is_valid_color(text_color_);
  }

  td_api::object_ptr<td_api::upgradedGiftBackdrop> get_upgraded_gift_backdrop_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarGiftAttributeBackdrop &lhs, const StarGiftAttributeBackdrop &rhs);

inline bool operator!=(const StarGiftAttributeBackdrop &lhs, const StarGiftAttributeBackdrop &rhs) {
  return !(lhs == rhs);
}

class StarGiftAttributeOriginalDetails {
  DialogId sender_dialog_id_;
  DialogId receiver_dialog_id_;
  int32 date_ = 0;
  FormattedText message_;

  friend bool operator==(const StarGiftAttributeOriginalDetails &lhs, const StarGiftAttributeOriginalDetails &rhs);

 public:
  StarGiftAttributeOriginalDetails() = default;

  StarGiftAttributeOriginalDetails(
      Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributeOriginalDetails> &&attribute);

  bool is_valid() const {
    return (sender_dialog_id_ == DialogId() || sender_dialog_id_.is_valid()) && receiver_dialog_id_.is_valid() &&
           date_ > 0;
  }

  td_api::object_ptr<td_api::upgradedGiftOriginalDetails> get_upgraded_gift_original_details_object(Td *td) const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarGiftAttributeOriginalDetails &lhs, const StarGiftAttributeOriginalDetails &rhs);

inline bool operator!=(const StarGiftAttributeOriginalDetails &lhs, const StarGiftAttributeOriginalDetails &rhs) {
  return !(lhs == rhs);
}

}  // namespace td
