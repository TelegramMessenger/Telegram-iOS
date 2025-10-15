//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/LabeledPricePart.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageExtendedMedia.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class InputInvoice {
  struct Invoice {
    string currency_;
    vector<LabeledPricePart> price_parts_;
    int32 subscription_period_ = 0;
    int64 max_tip_amount_ = 0;
    vector<int64> suggested_tip_amounts_;
    string recurring_payment_terms_of_service_url_;
    string terms_of_service_url_;
    bool is_test_ = false;
    bool need_name_ = false;
    bool need_phone_number_ = false;
    bool need_email_address_ = false;
    bool need_shipping_address_ = false;
    bool send_phone_number_to_provider_ = false;
    bool send_email_address_to_provider_ = false;
    bool is_flexible_ = false;

    Invoice() = default;
    Invoice(string &&currency, bool is_test, bool need_shipping_address)
        : currency_(std::move(currency)), is_test_(is_test), need_shipping_address_(need_shipping_address) {
    }

    tl_object_ptr<telegram_api::invoice> get_input_invoice() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  string title_;
  string description_;
  Photo photo_;
  string start_parameter_;
  Invoice invoice_;
  string payload_;
  string provider_token_;
  string provider_data_;
  MessageExtendedMedia extended_media_;
  FormattedText extended_media_caption_;

  int64 total_amount_ = 0;
  MessageId receipt_message_id_;

  friend bool operator==(const InputInvoice &lhs, const InputInvoice &rhs);

 public:
  InputInvoice() = default;

  InputInvoice(tl_object_ptr<telegram_api::messageMediaInvoice> &&message_invoice, Td *td, DialogId owner_dialog_id,
               FormattedText &&message);

  InputInvoice(tl_object_ptr<telegram_api::botInlineMessageMediaInvoice> &&message_invoice, Td *td,
               DialogId owner_dialog_id);

  static Result<InputInvoice> process_input_message_invoice(
      td_api::object_ptr<td_api::InputMessageContent> &&input_message_content, Td *td, DialogId owner_dialog_id);

  td_api::object_ptr<td_api::messageInvoice> get_message_invoice_object(Td *td, bool is_server, bool skip_bot_commands,
                                                                        int32 max_media_timestamp) const;

  tl_object_ptr<telegram_api::inputMediaInvoice> get_input_media_invoice(
      Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file,
      telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const;

  tl_object_ptr<telegram_api::inputBotInlineMessageMediaInvoice> get_input_bot_inline_message_media_invoice(
      tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup, Td *td) const;

  vector<FileId> get_file_ids(const Td *td) const;

  void delete_thumbnail(Td *td);

  bool need_reget() const;

  bool has_media_timestamp() const;

  bool is_equal_but_different(const InputInvoice &other) const;

  const FormattedText *get_caption() const;

  int32 get_duration(const Td *td) const;

  FileId get_any_file_id() const;

  FileId get_thumbnail_file_id(const Td *td) const;

  void update_from(const InputInvoice &old_input_invoice);

  bool update_extended_media(telegram_api::object_ptr<telegram_api::MessageExtendedMedia> extended_media,
                             DialogId owner_dialog_id, Td *td);

  bool need_poll_extended_media() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const InputInvoice &lhs, const InputInvoice &rhs);
bool operator!=(const InputInvoice &lhs, const InputInvoice &rhs);

td_api::object_ptr<td_api::productInfo> get_product_info_object(Td *td, const string &title, const string &description,
                                                                const Photo &photo);

}  // namespace td
