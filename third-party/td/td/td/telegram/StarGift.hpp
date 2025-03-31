//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Global.h"
#include "td/telegram/StarGift.h"
#include "td/telegram/StarGiftAttribute.hpp"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StarGift::store(StorerT &storer) const {
  CHECK(is_valid());
  Td *td = storer.context()->td().get_actor_unsafe();
  bool is_limited = availability_total_ != 0;
  bool has_default_sell_star_count = default_sell_star_count_ != star_count_ * 85 / 100;
  bool has_first_sale_date = first_sale_date_ != 0;
  bool has_last_sale_date = last_sale_date_ != 0;
  bool has_original_details = original_details_.is_valid();
  bool has_upgrade_star_count = upgrade_star_count_ != 0;
  bool has_owner_name = !owner_name_.empty();
  bool has_slug = !slug_.empty();
  bool has_owner_dialog_id = owner_dialog_id_.is_valid();
  bool has_owner_address = !owner_address_.empty();
  bool has_gift_address = !gift_address_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_limited);
  STORE_FLAG(has_default_sell_star_count);
  STORE_FLAG(has_first_sale_date);
  STORE_FLAG(has_last_sale_date);
  STORE_FLAG(is_for_birthday_);
  STORE_FLAG(is_unique_);
  STORE_FLAG(has_original_details);
  STORE_FLAG(false);  // has_owner_user_id
  STORE_FLAG(has_upgrade_star_count);
  STORE_FLAG(has_owner_name);
  STORE_FLAG(has_slug);
  STORE_FLAG(has_owner_dialog_id);
  STORE_FLAG(has_owner_address);
  STORE_FLAG(has_gift_address);
  END_STORE_FLAGS();
  td::store(id_, storer);
  if (!is_unique_) {
    td->stickers_manager_->store_sticker(sticker_file_id_, false, storer, "StarGift");
    td::store(star_count_, storer);
  }
  if (is_limited) {
    td::store(availability_remains_, storer);
    td::store(availability_total_, storer);
  }
  if (has_default_sell_star_count) {
    td::store(default_sell_star_count_, storer);
  }
  if (has_first_sale_date) {
    td::store(first_sale_date_, storer);
  }
  if (has_last_sale_date) {
    td::store(last_sale_date_, storer);
  }
  if (has_upgrade_star_count) {
    td::store(upgrade_star_count_, storer);
  }
  if (is_unique_) {
    td::store(model_, storer);
    td::store(pattern_, storer);
    td::store(backdrop_, storer);
    if (has_original_details) {
      td::store(original_details_, storer);
    }
    td::store(title_, storer);
    if (has_owner_dialog_id) {
      td::store(owner_dialog_id_, storer);
    }
    if (has_owner_name) {
      td::store(owner_name_, storer);
    }
    td::store(num_, storer);
    td::store(unique_availability_issued_, storer);
    td::store(unique_availability_total_, storer);
    if (has_slug) {
      td::store(slug_, storer);
    }
    if (has_owner_address) {
      td::store(owner_address_, storer);
    }
    if (has_gift_address) {
      td::store(gift_address_, storer);
    }
  }
}

template <class ParserT>
void StarGift::parse(ParserT &parser) {
  Td *td = parser.context()->td().get_actor_unsafe();
  bool is_limited;
  bool has_default_sell_star_count;
  bool has_first_sale_date;
  bool has_last_sale_date;
  bool has_original_details;
  bool has_owner_user_id;
  bool has_upgrade_star_count;
  bool has_owner_name;
  bool has_slug;
  bool has_owner_dialog_id;
  bool has_owner_address;
  bool has_gift_address;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_limited);
  PARSE_FLAG(has_default_sell_star_count);
  PARSE_FLAG(has_first_sale_date);
  PARSE_FLAG(has_last_sale_date);
  PARSE_FLAG(is_for_birthday_);
  PARSE_FLAG(is_unique_);
  PARSE_FLAG(has_original_details);
  PARSE_FLAG(has_owner_user_id);
  PARSE_FLAG(has_upgrade_star_count);
  PARSE_FLAG(has_owner_name);
  PARSE_FLAG(has_slug);
  PARSE_FLAG(has_owner_dialog_id);
  PARSE_FLAG(has_owner_address);
  PARSE_FLAG(has_gift_address);
  END_PARSE_FLAGS();
  td::parse(id_, parser);
  if (!is_unique_) {
    sticker_file_id_ = td->stickers_manager_->parse_sticker(false, parser);
    td::parse(star_count_, parser);
  }
  if (is_limited) {
    td::parse(availability_remains_, parser);
    td::parse(availability_total_, parser);
  }
  if (has_default_sell_star_count) {
    td::parse(default_sell_star_count_, parser);
  } else {
    default_sell_star_count_ = star_count_ * 85 / 100;
  }
  if (has_first_sale_date) {
    td::parse(first_sale_date_, parser);
  }
  if (has_last_sale_date) {
    td::parse(last_sale_date_, parser);
  }
  if (has_upgrade_star_count) {
    td::parse(upgrade_star_count_, parser);
  }
  if (is_unique_) {
    td::parse(model_, parser);
    td::parse(pattern_, parser);
    td::parse(backdrop_, parser);
    if (has_original_details) {
      td::parse(original_details_, parser);
    }
    td::parse(title_, parser);
    if (has_owner_user_id) {
      UserId owner_user_id;
      td::parse(owner_user_id, parser);
      owner_dialog_id_ = DialogId(owner_user_id);
    }
    if (has_owner_dialog_id) {
      td::parse(owner_dialog_id_, parser);
    }
    if (has_owner_name) {
      td::parse(owner_name_, parser);
    }
    td::parse(num_, parser);
    td::parse(unique_availability_issued_, parser);
    td::parse(unique_availability_total_, parser);
    if (has_slug) {
      td::parse(slug_, parser);
    }
    if (has_owner_address) {
      td::parse(owner_address_, parser);
    }
    if (has_gift_address) {
      td::parse(gift_address_, parser);
    }
  }
}

}  // namespace td
