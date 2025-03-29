//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/InputInvoice.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Dimensions.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/misc.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/PhotoSizeType.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/HttpUrl.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/PathView.h"

namespace td {

bool operator==(const InputInvoice &lhs, const InputInvoice &rhs) {
  auto are_invoice_equal = [](const InputInvoice::Invoice &lhs, const InputInvoice::Invoice &rhs) {
    return lhs.is_test_ == rhs.is_test_ && lhs.need_name_ == rhs.need_name_ &&
           lhs.need_phone_number_ == rhs.need_phone_number_ && lhs.need_email_address_ == rhs.need_email_address_ &&
           lhs.need_shipping_address_ == rhs.need_shipping_address_ &&
           lhs.send_phone_number_to_provider_ == rhs.send_phone_number_to_provider_ &&
           lhs.send_email_address_to_provider_ == rhs.send_email_address_to_provider_ &&
           lhs.is_flexible_ == rhs.is_flexible_ && lhs.currency_ == rhs.currency_ &&
           lhs.price_parts_ == rhs.price_parts_ && lhs.subscription_period_ == rhs.subscription_period_ &&
           lhs.max_tip_amount_ == rhs.max_tip_amount_ && lhs.suggested_tip_amounts_ == rhs.suggested_tip_amounts_ &&
           lhs.recurring_payment_terms_of_service_url_ == rhs.recurring_payment_terms_of_service_url_ &&
           lhs.terms_of_service_url_ == rhs.terms_of_service_url_;
  };

  return lhs.title_ == rhs.title_ && lhs.description_ == rhs.description_ && lhs.photo_ == rhs.photo_ &&
         lhs.start_parameter_ == rhs.start_parameter_ && are_invoice_equal(lhs.invoice_, rhs.invoice_) &&
         lhs.payload_ == rhs.payload_ && lhs.provider_token_ == rhs.provider_token_ &&
         lhs.provider_data_ == rhs.provider_data_ && lhs.extended_media_ == rhs.extended_media_ &&
         lhs.extended_media_caption_ == rhs.extended_media_caption_ && lhs.total_amount_ == rhs.total_amount_ &&
         lhs.receipt_message_id_ == rhs.receipt_message_id_;
}

bool operator!=(const InputInvoice &lhs, const InputInvoice &rhs) {
  return !(lhs == rhs);
}

InputInvoice::InputInvoice(tl_object_ptr<telegram_api::messageMediaInvoice> &&message_invoice, Td *td,
                           DialogId owner_dialog_id, FormattedText &&message) {
  title_ = std::move(message_invoice->title_);
  description_ = std::move(message_invoice->description_);
  photo_ = get_web_document_photo(td->file_manager_.get(), std::move(message_invoice->photo_), owner_dialog_id);
  start_parameter_ = std::move(message_invoice->start_param_);
  invoice_.currency_ = std::move(message_invoice->currency_);
  invoice_.is_test_ = message_invoice->test_;
  invoice_.need_shipping_address_ = message_invoice->shipping_address_requested_;
  // payload_ = string();
  // provider_token_ = string();
  // provider_data_ = string();
  extended_media_ = MessageExtendedMedia(td, std::move(message_invoice->extended_media_), owner_dialog_id);
  if (!extended_media_.is_empty()) {
    extended_media_caption_ = std::move(message);
  }
  if (message_invoice->total_amount_ <= 0 || !check_currency_amount(message_invoice->total_amount_)) {
    LOG(ERROR) << "Receive invalid total amount " << message_invoice->total_amount_;
    message_invoice->total_amount_ = 0;
  }
  total_amount_ = message_invoice->total_amount_;
  if ((message_invoice->flags_ & telegram_api::messageMediaInvoice::RECEIPT_MSG_ID_MASK) != 0) {
    receipt_message_id_ = MessageId(ServerMessageId(message_invoice->receipt_msg_id_));
    if (!receipt_message_id_.is_valid()) {
      LOG(ERROR) << "Receive as receipt message " << receipt_message_id_ << " in " << owner_dialog_id;
      receipt_message_id_ = MessageId();
    }
  }
}

InputInvoice::InputInvoice(tl_object_ptr<telegram_api::botInlineMessageMediaInvoice> &&message_invoice, Td *td,
                           DialogId owner_dialog_id) {
  title_ = std::move(message_invoice->title_);
  description_ = std::move(message_invoice->description_);
  photo_ = get_web_document_photo(td->file_manager_.get(), std::move(message_invoice->photo_), owner_dialog_id);
  // start_parameter_ = string();
  invoice_.currency_ = std::move(message_invoice->currency_);
  invoice_.is_test_ = message_invoice->test_;
  invoice_.need_shipping_address_ = message_invoice->shipping_address_requested_;
  // payload_ = string();
  // provider_token_ = string();
  // provider_data_ = string();
  // extended_media_ = MessageExtendedMedia();
  // extended_media_caption_ = FormattedText();
  if (message_invoice->total_amount_ <= 0 || !check_currency_amount(message_invoice->total_amount_)) {
    LOG(ERROR) << "Receive invalid total amount " << message_invoice->total_amount_;
    message_invoice->total_amount_ = 0;
  }
  total_amount_ = message_invoice->total_amount_;
  // receipt_message_id_ = MessageId();
}

Result<InputInvoice> InputInvoice::process_input_message_invoice(
    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content, Td *td, DialogId owner_dialog_id) {
  CHECK(input_message_content != nullptr);
  CHECK(input_message_content->get_id() == td_api::inputMessageInvoice::ID);
  auto input_invoice = move_tl_object_as<td_api::inputMessageInvoice>(input_message_content);
  if (input_invoice->invoice_ == nullptr) {
    return Status::Error(400, "Invoice must be non-empty");
  }

  if (!clean_input_string(input_invoice->title_)) {
    return Status::Error(400, "Invoice title must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->description_)) {
    return Status::Error(400, "Invoice description must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->photo_url_)) {
    return Status::Error(400, "Invoice photo URL must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->start_parameter_)) {
    return Status::Error(400, "Invoice bot start parameter must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->provider_token_)) {
    return Status::Error(400, "Invoice provider token must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->provider_data_)) {
    return Status::Error(400, "Invoice provider data must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->invoice_->currency_)) {
    return Status::Error(400, "Invoice currency must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->invoice_->recurring_payment_terms_of_service_url_)) {
    return Status::Error(400, "Invoice terms of service URL must be encoded in UTF-8");
  }
  if (!clean_input_string(input_invoice->invoice_->terms_of_service_url_)) {
    return Status::Error(400, "Invoice terms of service URL must be encoded in UTF-8");
  }

  InputInvoice result;
  result.title_ = std::move(input_invoice->title_);
  result.description_ = std::move(input_invoice->description_);

  auto r_http_url = parse_url(input_invoice->photo_url_);
  if (r_http_url.is_error()) {
    if (!input_invoice->photo_url_.empty()) {
      LOG(INFO) << "Can't register URL " << input_invoice->photo_url_;
    }
  } else {
    auto url = r_http_url.ok().get_url();
    auto r_invoice_file_id = td->file_manager_->from_persistent_id(url, FileType::Temp);
    if (r_invoice_file_id.is_error()) {
      LOG(INFO) << "Can't register URL " << url;
    } else {
      auto invoice_file_id = r_invoice_file_id.move_as_ok();

      PhotoSize s;
      s.type = PhotoSizeType('n');
      s.dimensions = get_dimensions(input_invoice->photo_width_, input_invoice->photo_height_, nullptr);
      s.size = input_invoice->photo_size_;  // TODO use invoice_file_id size
      s.file_id = invoice_file_id;

      result.photo_.id = 0;
      result.photo_.photos.push_back(s);
    }
  }
  result.start_parameter_ = std::move(input_invoice->start_parameter_);

  result.invoice_.currency_ = std::move(input_invoice->invoice_->currency_);
  result.invoice_.price_parts_.reserve(input_invoice->invoice_->price_parts_.size());
  int64 total_amount = 0;
  for (auto &price : input_invoice->invoice_->price_parts_) {
    if (!clean_input_string(price->label_)) {
      return Status::Error(400, "Invoice price label must be encoded in UTF-8");
    }
    if (!check_currency_amount(price->amount_)) {
      return Status::Error(400, "Too big amount of the currency specified");
    }
    result.invoice_.price_parts_.emplace_back(std::move(price->label_), price->amount_);
    total_amount += price->amount_;
  }
  if (total_amount <= 0) {
    return Status::Error(400, "Total price must be positive");
  }
  if (!check_currency_amount(total_amount)) {
    return Status::Error(400, "Total price is too big");
  }
  result.total_amount_ = total_amount;
  result.invoice_.subscription_period_ = max(input_invoice->invoice_->subscription_period_, 0);

  if (input_invoice->invoice_->max_tip_amount_ < 0 ||
      !check_currency_amount(input_invoice->invoice_->max_tip_amount_)) {
    return Status::Error(400, "Invalid max_tip_amount of the currency specified");
  }
  for (auto tip_amount : input_invoice->invoice_->suggested_tip_amounts_) {
    if (tip_amount <= 0) {
      return Status::Error(400, "Suggested tip amount must be positive");
    }
    if (tip_amount > input_invoice->invoice_->max_tip_amount_) {
      return Status::Error(400, "Suggested tip amount can't be bigger than max_tip_amount");
    }
  }
  if (input_invoice->invoice_->suggested_tip_amounts_.size() > 4) {
    return Status::Error(400, "There can be at most 4 suggested tip amounts");
  }

  result.invoice_.max_tip_amount_ = input_invoice->invoice_->max_tip_amount_;
  result.invoice_.suggested_tip_amounts_ = std::move(input_invoice->invoice_->suggested_tip_amounts_);
  result.invoice_.recurring_payment_terms_of_service_url_ =
      std::move(input_invoice->invoice_->recurring_payment_terms_of_service_url_);
  result.invoice_.terms_of_service_url_ = std::move(input_invoice->invoice_->terms_of_service_url_);
  result.invoice_.is_test_ = input_invoice->invoice_->is_test_;
  result.invoice_.need_name_ = input_invoice->invoice_->need_name_;
  result.invoice_.need_phone_number_ = input_invoice->invoice_->need_phone_number_;
  result.invoice_.need_email_address_ = input_invoice->invoice_->need_email_address_;
  result.invoice_.need_shipping_address_ = input_invoice->invoice_->need_shipping_address_;
  result.invoice_.send_phone_number_to_provider_ = input_invoice->invoice_->send_phone_number_to_provider_;
  result.invoice_.send_email_address_to_provider_ = input_invoice->invoice_->send_email_address_to_provider_;
  result.invoice_.is_flexible_ = input_invoice->invoice_->is_flexible_;
  if (result.invoice_.send_phone_number_to_provider_) {
    result.invoice_.need_phone_number_ = true;
  }
  if (result.invoice_.send_email_address_to_provider_) {
    result.invoice_.need_email_address_ = true;
  }
  if (result.invoice_.is_flexible_) {
    result.invoice_.need_shipping_address_ = true;
  }

  result.payload_ = std::move(input_invoice->payload_);
  result.provider_token_ = std::move(input_invoice->provider_token_);
  result.provider_data_ = std::move(input_invoice->provider_data_);

  TRY_RESULT(extended_media, MessageExtendedMedia::get_message_extended_media(td, std::move(input_invoice->paid_media_),
                                                                              owner_dialog_id));
  result.extended_media_ = std::move(extended_media);
  if (!result.extended_media_.is_empty()) {
    bool is_bot = td->auth_manager_->is_bot();
    TRY_RESULT(extended_media_caption,
               get_formatted_text(td, owner_dialog_id, std::move(input_invoice->paid_media_caption_), is_bot, true,
                                  false, false));
    result.extended_media_caption_ = std::move(extended_media_caption);
  }

  return result;
}

td_api::object_ptr<td_api::messageInvoice> InputInvoice::get_message_invoice_object(Td *td, bool is_server,
                                                                                    bool skip_bot_commands,
                                                                                    int32 max_media_timestamp) const {
  auto extended_media_object = extended_media_.get_paid_media_object(td);
  auto extended_media_caption_object =
      extended_media_object == nullptr
          ? nullptr
          : get_formatted_text_object(is_server ? td->user_manager_.get() : nullptr, extended_media_caption_,
                                      skip_bot_commands, max_media_timestamp);
  return td_api::make_object<td_api::messageInvoice>(
      get_product_info_object(td, title_, description_, photo_), invoice_.currency_, total_amount_, start_parameter_,
      invoice_.is_test_, invoice_.need_shipping_address_, receipt_message_id_.get(), std::move(extended_media_object),
      std::move(extended_media_caption_object));
}

tl_object_ptr<telegram_api::invoice> InputInvoice::Invoice::get_input_invoice() const {
  int32 flags = 0;
  if (is_test_) {
    flags |= telegram_api::invoice::TEST_MASK;
  }
  if (need_name_) {
    flags |= telegram_api::invoice::NAME_REQUESTED_MASK;
  }
  if (need_phone_number_) {
    flags |= telegram_api::invoice::PHONE_REQUESTED_MASK;
  }
  if (need_email_address_) {
    flags |= telegram_api::invoice::EMAIL_REQUESTED_MASK;
  }
  if (need_shipping_address_) {
    flags |= telegram_api::invoice::SHIPPING_ADDRESS_REQUESTED_MASK;
  }
  if (send_phone_number_to_provider_) {
    flags |= telegram_api::invoice::PHONE_TO_PROVIDER_MASK;
  }
  if (send_email_address_to_provider_) {
    flags |= telegram_api::invoice::EMAIL_TO_PROVIDER_MASK;
  }
  if (is_flexible_) {
    flags |= telegram_api::invoice::FLEXIBLE_MASK;
  }
  if (max_tip_amount_ != 0) {
    flags |= telegram_api::invoice::MAX_TIP_AMOUNT_MASK;
  }
  if (subscription_period_ != 0) {
    flags |= telegram_api::invoice::SUBSCRIPTION_PERIOD_MASK;
  }
  string terms_of_service_url;
  if (!recurring_payment_terms_of_service_url_.empty()) {
    flags |= telegram_api::invoice::RECURRING_MASK;
    flags |= telegram_api::invoice::TERMS_URL_MASK;
    terms_of_service_url = recurring_payment_terms_of_service_url_;
  } else if (!terms_of_service_url_.empty()) {
    flags |= telegram_api::invoice::TERMS_URL_MASK;
    terms_of_service_url = terms_of_service_url_;
  }

  auto prices = transform(price_parts_, [](const LabeledPricePart &price) {
    return telegram_api::make_object<telegram_api::labeledPrice>(price.label, price.amount);
  });
  return make_tl_object<telegram_api::invoice>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, currency_, std::move(prices),
      max_tip_amount_, vector<int64>(suggested_tip_amounts_), terms_of_service_url, subscription_period_);
}

static telegram_api::object_ptr<telegram_api::inputWebDocument> get_input_web_document(const FileManager *file_manager,
                                                                                       const Photo &photo) {
  if (photo.is_empty()) {
    return nullptr;
  }

  CHECK(photo.photos.size() == 1);
  const PhotoSize &size = photo.photos[0];
  CHECK(size.file_id.is_valid());

  vector<tl_object_ptr<telegram_api::DocumentAttribute>> attributes;
  if (size.dimensions.width != 0 && size.dimensions.height != 0) {
    attributes.push_back(
        make_tl_object<telegram_api::documentAttributeImageSize>(size.dimensions.width, size.dimensions.height));
  }

  auto file_view = file_manager->get_file_view(size.file_id);
  const auto *url = file_view.get_url();
  CHECK(url != nullptr);

  auto file_name = get_url_file_name(*url);
  return telegram_api::make_object<telegram_api::inputWebDocument>(
      *url, size.size, MimeType::from_extension(PathView(file_name).extension(), "image/jpeg"), std::move(attributes));
}

tl_object_ptr<telegram_api::inputMediaInvoice> InputInvoice::get_input_media_invoice(
    Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const {
  int32 flags = 0;
  if (!start_parameter_.empty()) {
    flags |= telegram_api::inputMediaInvoice::START_PARAM_MASK;
  }
  auto input_web_document = get_input_web_document(td->file_manager_.get(), photo_);
  if (input_web_document != nullptr) {
    flags |= telegram_api::inputMediaInvoice::PHOTO_MASK;
  }
  telegram_api::object_ptr<telegram_api::InputMedia> extended_media;
  if (!extended_media_.is_empty()) {
    flags |= telegram_api::inputMediaInvoice::EXTENDED_MEDIA_MASK;
    extended_media = extended_media_.get_input_media(td, std::move(input_file), std::move(input_thumbnail));
    if (extended_media == nullptr) {
      return nullptr;
    }
  }
  if (!provider_token_.empty()) {
    flags |= telegram_api::inputMediaInvoice::PROVIDER_MASK;
  }

  return make_tl_object<telegram_api::inputMediaInvoice>(
      flags, title_, description_, std::move(input_web_document), invoice_.get_input_invoice(), BufferSlice(payload_),
      provider_token_,
      telegram_api::make_object<telegram_api::dataJSON>(provider_data_.empty() ? "null" : provider_data_),
      start_parameter_, std::move(extended_media));
}

tl_object_ptr<telegram_api::inputBotInlineMessageMediaInvoice> InputInvoice::get_input_bot_inline_message_media_invoice(
    tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup, Td *td) const {
  int32 flags = 0;
  if (reply_markup != nullptr) {
    flags |= telegram_api::inputBotInlineMessageMediaInvoice::REPLY_MARKUP_MASK;
  }
  auto input_web_document = get_input_web_document(td->file_manager_.get(), photo_);
  if (input_web_document != nullptr) {
    flags |= telegram_api::inputBotInlineMessageMediaInvoice::PHOTO_MASK;
  }
  return make_tl_object<telegram_api::inputBotInlineMessageMediaInvoice>(
      flags, title_, description_, std::move(input_web_document), invoice_.get_input_invoice(), BufferSlice(payload_),
      provider_token_,
      telegram_api::make_object<telegram_api::dataJSON>(provider_data_.empty() ? "null" : provider_data_),
      std::move(reply_markup));
}

vector<FileId> InputInvoice::get_file_ids(const Td *td) const {
  auto file_ids = photo_get_file_ids(photo_);
  extended_media_.append_file_ids(td, file_ids);
  return file_ids;
}

void InputInvoice::delete_thumbnail(Td *td) {
  extended_media_.delete_thumbnail(td);
}

bool InputInvoice::need_reget() const {
  return extended_media_.need_reget();
}

bool InputInvoice::has_media_timestamp() const {
  return extended_media_.has_media_timestamp();
}

bool InputInvoice::is_equal_but_different(const InputInvoice &other) const {
  return extended_media_.is_equal_but_different(other.extended_media_);
}

const FormattedText *InputInvoice::get_caption() const {
  return &extended_media_caption_;
}

int32 InputInvoice::get_duration(const Td *td) const {
  return extended_media_.get_duration(td);
}

FileId InputInvoice::get_any_file_id() const {
  return extended_media_.get_any_file_id();
}

FileId InputInvoice::get_thumbnail_file_id(const Td *td) const {
  return extended_media_.get_thumbnail_file_id(td);
}

void InputInvoice::update_from(const InputInvoice &old_input_invoice) {
  extended_media_.update_from(old_input_invoice.extended_media_);
}

bool InputInvoice::update_extended_media(telegram_api::object_ptr<telegram_api::MessageExtendedMedia> extended_media,
                                         DialogId owner_dialog_id, Td *td) {
  return extended_media_.update_to(td, std::move(extended_media), owner_dialog_id);
}

bool InputInvoice::need_poll_extended_media() const {
  return extended_media_.need_poll();
}

td_api::object_ptr<td_api::productInfo> get_product_info_object(Td *td, const string &title, const string &description,
                                                                const Photo &photo) {
  FormattedText formatted_description;
  formatted_description.text = description;
  formatted_description.entities = find_entities(formatted_description.text, true, true);
  return td_api::make_object<td_api::productInfo>(
      title, get_formatted_text_object(td->user_manager_.get(), formatted_description, true, 0),
      get_photo_object(td->file_manager_.get(), photo));
}

}  // namespace td
