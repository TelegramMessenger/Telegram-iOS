//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/InputInvoice.h"

#include "td/telegram/MessageEntity.hpp"
#include "td/telegram/MessageExtendedMedia.hpp"
#include "td/telegram/Photo.hpp"
#include "td/telegram/Version.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void InputInvoice::Invoice::store(StorerT &storer) const {
  using td::store;
  bool has_tip = max_tip_amount_ != 0;
  bool is_recurring = !recurring_payment_terms_of_service_url_.empty();
  bool has_terms_of_service = !terms_of_service_url_.empty();
  bool has_subscription_period = subscription_period_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_test_);
  STORE_FLAG(need_name_);
  STORE_FLAG(need_phone_number_);
  STORE_FLAG(need_email_address_);
  STORE_FLAG(need_shipping_address_);
  STORE_FLAG(is_flexible_);
  STORE_FLAG(send_phone_number_to_provider_);
  STORE_FLAG(send_email_address_to_provider_);
  STORE_FLAG(has_tip);
  STORE_FLAG(is_recurring);
  STORE_FLAG(has_terms_of_service);
  STORE_FLAG(has_subscription_period);
  END_STORE_FLAGS();
  store(currency_, storer);
  store(price_parts_, storer);
  if (has_tip) {
    store(max_tip_amount_, storer);
    store(suggested_tip_amounts_, storer);
  }
  if (is_recurring) {
    store(recurring_payment_terms_of_service_url_, storer);
  }
  if (has_terms_of_service) {
    store(terms_of_service_url_, storer);
  }
  if (has_subscription_period) {
    store(subscription_period_, storer);
  }
}

template <class ParserT>
void InputInvoice::Invoice::parse(ParserT &parser) {
  using td::parse;
  bool has_tip;
  bool is_recurring;
  bool has_terms_of_service;
  bool has_subscription_period;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_test_);
  PARSE_FLAG(need_name_);
  PARSE_FLAG(need_phone_number_);
  PARSE_FLAG(need_email_address_);
  PARSE_FLAG(need_shipping_address_);
  PARSE_FLAG(is_flexible_);
  PARSE_FLAG(send_phone_number_to_provider_);
  PARSE_FLAG(send_email_address_to_provider_);
  PARSE_FLAG(has_tip);
  PARSE_FLAG(is_recurring);
  PARSE_FLAG(has_terms_of_service);
  PARSE_FLAG(has_subscription_period);
  END_PARSE_FLAGS();
  parse(currency_, parser);
  parse(price_parts_, parser);
  if (has_tip) {
    parse(max_tip_amount_, parser);
    parse(suggested_tip_amounts_, parser);
  }
  if (is_recurring) {
    parse(recurring_payment_terms_of_service_url_, parser);
  }
  if (has_terms_of_service) {
    parse(terms_of_service_url_, parser);
  }
  if (has_subscription_period) {
    parse(subscription_period_, parser);
  }
}

template <class StorerT>
void InputInvoice::store(StorerT &storer) const {
  using td::store;
  bool has_description = !description_.empty();
  bool has_photo = !photo_.is_empty();
  bool has_start_parameter = !start_parameter_.empty();
  bool has_payload = !payload_.empty();
  bool has_provider_token = !provider_token_.empty();
  bool has_provider_data = !provider_data_.empty();
  bool has_total_amount = total_amount_ != 0;
  bool has_receipt_message_id = receipt_message_id_.is_valid();
  bool has_extended_media = !extended_media_.is_empty();
  bool has_extended_media_caption = !extended_media_caption_.text.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_description);
  STORE_FLAG(has_photo);
  STORE_FLAG(has_start_parameter);
  STORE_FLAG(has_payload);
  STORE_FLAG(has_provider_token);
  STORE_FLAG(has_provider_data);
  STORE_FLAG(has_total_amount);
  STORE_FLAG(has_receipt_message_id);
  STORE_FLAG(has_extended_media);
  STORE_FLAG(has_extended_media_caption);
  END_STORE_FLAGS();
  store(title_, storer);
  if (has_description) {
    store(description_, storer);
  }
  if (has_photo) {
    store(photo_, storer);
  }
  if (has_start_parameter) {
    store(start_parameter_, storer);
  }
  store(invoice_, storer);
  if (has_payload) {
    store(payload_, storer);
  }
  if (has_provider_token) {
    store(provider_token_, storer);
  }
  if (has_provider_data) {
    store(provider_data_, storer);
  }
  if (has_total_amount) {
    store(total_amount_, storer);
  }
  if (has_receipt_message_id) {
    store(receipt_message_id_, storer);
  }
  if (has_extended_media) {
    store(extended_media_, storer);
  }
  if (has_extended_media_caption) {
    store(extended_media_caption_, storer);
  }
}

template <class ParserT>
void InputInvoice::parse(ParserT &parser) {
  using td::parse;
  bool has_description;
  bool has_photo;
  bool has_start_parameter;
  bool has_payload;
  bool has_provider_token;
  bool has_provider_data;
  bool has_total_amount;
  bool has_receipt_message_id;
  bool has_extended_media;
  bool has_extended_media_caption = false;
  if (parser.version() >= static_cast<int32>(Version::AddInputInvoiceFlags)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_description);
    PARSE_FLAG(has_photo);
    PARSE_FLAG(has_start_parameter);
    PARSE_FLAG(has_payload);
    PARSE_FLAG(has_provider_token);
    PARSE_FLAG(has_provider_data);
    PARSE_FLAG(has_total_amount);
    PARSE_FLAG(has_receipt_message_id);
    PARSE_FLAG(has_extended_media);
    PARSE_FLAG(has_extended_media_caption);
    END_PARSE_FLAGS();
  } else {
    has_description = true;
    has_photo = true;
    has_start_parameter = true;
    has_payload = true;
    has_provider_token = true;
    has_provider_data = parser.version() >= static_cast<int32>(Version::AddMessageInvoiceProviderData);
    has_total_amount = true;
    has_receipt_message_id = true;
    has_extended_media = false;
  }
  parse(title_, parser);
  if (has_description) {
    parse(description_, parser);
  }
  if (has_photo) {
    parse(photo_, parser);
  }
  if (has_start_parameter) {
    parse(start_parameter_, parser);
  }
  parse(invoice_, parser);
  if (has_payload) {
    parse(payload_, parser);
  }
  if (has_provider_token) {
    parse(provider_token_, parser);
  }
  if (has_provider_data) {
    parse(provider_data_, parser);
  }
  if (has_total_amount) {
    parse(total_amount_, parser);
  }
  if (has_receipt_message_id) {
    parse(receipt_message_id_, parser);
  }
  if (has_extended_media) {
    parse(extended_media_, parser);
  }
  if (has_extended_media_caption) {
    parse(extended_media_caption_, parser);
  }
}

}  // namespace td
