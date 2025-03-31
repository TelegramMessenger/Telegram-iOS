//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Payments.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/BusinessConnectionManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogInviteLink.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/GiveawayParameters.h"
#include "td/telegram/Global.h"
#include "td/telegram/InputInvoice.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/Photo.h"
#include "td/telegram/Premium.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"

namespace td {

namespace {

struct InputInvoiceInfo {
  DialogId dialog_id_;
  telegram_api::object_ptr<telegram_api::InputInvoice> input_invoice_;
  int64 star_count_ = 0;
};

Result<InputInvoiceInfo> get_input_invoice_info(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice) {
  if (input_invoice == nullptr) {
    return Status::Error(400, "Input invoice must be non-empty");
  }

  InputInvoiceInfo result;
  switch (input_invoice->get_id()) {
    case td_api::inputInvoiceMessage::ID: {
      auto invoice = td_api::move_object_as<td_api::inputInvoiceMessage>(input_invoice);
      DialogId dialog_id(invoice->chat_id_);
      MessageId message_id(invoice->message_id_);
      TRY_RESULT(invoice_message_info, td->messages_manager_->get_invoice_message_info({dialog_id, message_id}));

      auto input_peer = td->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
      if (input_peer == nullptr) {
        return Status::Error(400, "Can't access the chat");
      }

      result.dialog_id_ = dialog_id;
      result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoiceMessage>(
          std::move(input_peer), invoice_message_info.server_message_id_.get());
      result.star_count_ = invoice_message_info.star_count_;
      break;
    }
    case td_api::inputInvoiceName::ID: {
      auto invoice = td_api::move_object_as<td_api::inputInvoiceName>(input_invoice);
      result.input_invoice_ = make_tl_object<telegram_api::inputInvoiceSlug>(invoice->name_);
      break;
    }
    case td_api::inputInvoiceTelegram::ID: {
      auto invoice = td_api::move_object_as<td_api::inputInvoiceTelegram>(input_invoice);
      if (invoice->purpose_ == nullptr) {
        return Status::Error(400, "Purpose must be non-empty");
      }
      switch (invoice->purpose_->get_id()) {
        case td_api::telegramPaymentPurposePremiumGift::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposePremiumGift *>(invoice->purpose_.get());
          TRY_RESULT(input_user, td->user_manager_->get_input_user(UserId(p->user_id_)));
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          TRY_RESULT(text, get_premium_gift_text(td, std::move(p->text_)));

          if (p->currency_ == "XTR") {
            int32 flags = 0;
            if (text != nullptr) {
              flags |= telegram_api::inputInvoicePremiumGiftStars::MESSAGE_MASK;
            }
            result.star_count_ = max(p->amount_, static_cast<int64>(0));
            result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoicePremiumGiftStars>(
                flags, std::move(input_user), p->month_count_, std::move(text));
            break;
          }

          int32 flags = 0;
          if (text != nullptr) {
            flags |= telegram_api::inputStorePaymentPremiumGiftCode::MESSAGE_MASK;
          }
          auto option = telegram_api::make_object<telegram_api::premiumGiftCodeOption>(0, 1, p->month_count_, string(),
                                                                                       0, p->currency_, p->amount_);
          vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
          input_users.push_back(std::move(input_user));
          auto purpose = telegram_api::make_object<telegram_api::inputStorePaymentPremiumGiftCode>(
              flags, std::move(input_users), nullptr, p->currency_, p->amount_, std::move(text));

          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoicePremiumGiftCode>(
              std::move(purpose), std::move(option));
          break;
        }
        case td_api::telegramPaymentPurposePremiumGiftCodes::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposePremiumGiftCodes *>(invoice->purpose_.get());
          vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
          for (auto user_id : p->user_ids_) {
            TRY_RESULT(input_user, td->user_manager_->get_input_user(UserId(user_id)));
            input_users.push_back(std::move(input_user));
          }
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          DialogId boosted_dialog_id(p->boosted_chat_id_);
          TRY_RESULT(boost_input_peer, get_boost_input_peer(td, boosted_dialog_id));
          TRY_RESULT(text, get_premium_gift_text(td, std::move(p->text_)));

          int32 flags = telegram_api::inputStorePaymentPremiumGiftCode::BOOST_PEER_MASK;
          if (text != nullptr) {
            flags |= telegram_api::inputStorePaymentPremiumGiftCode::MESSAGE_MASK;
          }
          auto option = telegram_api::make_object<telegram_api::premiumGiftCodeOption>(
              0, static_cast<int32>(input_users.size()), p->month_count_, string(), 0, p->currency_, p->amount_);
          auto purpose = telegram_api::make_object<telegram_api::inputStorePaymentPremiumGiftCode>(
              flags, std::move(input_users), std::move(boost_input_peer), p->currency_, p->amount_, std::move(text));

          result.dialog_id_ = boosted_dialog_id;
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoicePremiumGiftCode>(
              std::move(purpose), std::move(option));
          break;
        }
        case td_api::telegramPaymentPurposePremiumGiveaway::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposePremiumGiveaway *>(invoice->purpose_.get());
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          TRY_RESULT(parameters, GiveawayParameters::get_giveaway_parameters(td, p->parameters_.get()));
          auto option = telegram_api::make_object<telegram_api::premiumGiftCodeOption>(
              0, p->winner_count_, p->month_count_, string(), 0, p->currency_, p->amount_);
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoicePremiumGiftCode>(
              parameters.get_input_store_payment_premium_giveaway(td, p->currency_, p->amount_), std::move(option));
          break;
        }
        case td_api::telegramPaymentPurposeStars::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposeStars *>(invoice->purpose_.get());
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::StarsSubscriptionLowBalance},
                                   Promise<Unit>());
          auto purpose = telegram_api::make_object<telegram_api::inputStorePaymentStarsTopup>(p->star_count_,
                                                                                              p->currency_, p->amount_);
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoiceStars>(std::move(purpose));
          break;
        }
        case td_api::telegramPaymentPurposeGiftedStars::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposeGiftedStars *>(invoice->purpose_.get());
          UserId user_id(p->user_id_);
          TRY_RESULT(input_user, td->user_manager_->get_input_user(user_id));
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          auto purpose = telegram_api::make_object<telegram_api::inputStorePaymentStarsGift>(
              std::move(input_user), p->star_count_, p->currency_, p->amount_);
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoiceStars>(std::move(purpose));
          break;
        }
        case td_api::telegramPaymentPurposeStarGiveaway::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposeStarGiveaway *>(invoice->purpose_.get());
          TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
          TRY_RESULT(parameters, GiveawayParameters::get_giveaway_parameters(td, p->parameters_.get()));
          auto purpose = parameters.get_input_store_payment_stars_giveaway(td, p->currency_, p->amount_,
                                                                           p->winner_count_, p->star_count_);
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoiceStars>(std::move(purpose));
          break;
        }
        case td_api::telegramPaymentPurposeJoinChat::ID: {
          auto p = static_cast<td_api::telegramPaymentPurposeJoinChat *>(invoice->purpose_.get());
          if (!DialogInviteLink::is_valid_invite_link(p->invite_link_)) {
            return Status::Error(400, "Invalid invite link");
          }
          auto hash = LinkManager::get_dialog_invite_link_hash(p->invite_link_);
          if (!clean_input_string(hash)) {
            return Status::Error(400, "Invalid invite link");
          }
          result.input_invoice_ = telegram_api::make_object<telegram_api::inputInvoiceChatInviteSubscription>(hash);
          break;
        }
        default:
          UNREACHABLE();
      }
      break;
    }
    default:
      UNREACHABLE();
  }
  return std::move(result);
}

}  // namespace

class SetBotShippingAnswerQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetBotShippingAnswerQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 shipping_query_id, const string &error_message,
            vector<tl_object_ptr<telegram_api::shippingOption>> &&shipping_options) {
    int32 flags = 0;
    if (!error_message.empty()) {
      flags |= telegram_api::messages_setBotShippingResults::ERROR_MASK;
    }
    if (!shipping_options.empty()) {
      flags |= telegram_api::messages_setBotShippingResults::SHIPPING_OPTIONS_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_setBotShippingResults(
        flags, shipping_query_id, error_message, std::move(shipping_options))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setBotShippingResults>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      LOG(INFO) << "Sending answer to a shipping query has failed";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetBotPreCheckoutAnswerQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetBotPreCheckoutAnswerQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 pre_checkout_query_id, const string &error_message) {
    int32 flags = 0;
    if (!error_message.empty()) {
      flags |= telegram_api::messages_setBotPrecheckoutResults::ERROR_MASK;
    } else {
      flags |= telegram_api::messages_setBotPrecheckoutResults::SUCCESS_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_setBotPrecheckoutResults(
        flags, false /*ignored*/, pre_checkout_query_id, error_message)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setBotPrecheckoutResults>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      LOG(INFO) << "Sending answer to a pre-checkout query has failed";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

static tl_object_ptr<td_api::labeledPricePart> convert_labeled_price(
    tl_object_ptr<telegram_api::labeledPrice> labeled_price) {
  CHECK(labeled_price != nullptr);
  if (!check_currency_amount(labeled_price->amount_)) {
    LOG(ERROR) << "Receive invalid labeled price amount " << labeled_price->amount_;
    labeled_price->amount_ = (labeled_price->amount_ < 0 ? -1 : 1) * (static_cast<int64>(1) << 40);
  }
  return make_tl_object<td_api::labeledPricePart>(std::move(labeled_price->label_), labeled_price->amount_);
}

static tl_object_ptr<td_api::invoice> convert_invoice(tl_object_ptr<telegram_api::invoice> invoice) {
  CHECK(invoice != nullptr);

  auto labeled_prices = transform(std::move(invoice->prices_), convert_labeled_price);
  bool is_test = (invoice->flags_ & telegram_api::invoice::TEST_MASK) != 0;
  bool need_name = (invoice->flags_ & telegram_api::invoice::NAME_REQUESTED_MASK) != 0;
  bool need_phone_number = (invoice->flags_ & telegram_api::invoice::PHONE_REQUESTED_MASK) != 0;
  bool need_email_address = (invoice->flags_ & telegram_api::invoice::EMAIL_REQUESTED_MASK) != 0;
  bool need_shipping_address = (invoice->flags_ & telegram_api::invoice::SHIPPING_ADDRESS_REQUESTED_MASK) != 0;
  bool send_phone_number_to_provider = (invoice->flags_ & telegram_api::invoice::PHONE_TO_PROVIDER_MASK) != 0;
  bool send_email_address_to_provider = (invoice->flags_ & telegram_api::invoice::EMAIL_TO_PROVIDER_MASK) != 0;
  bool is_flexible = (invoice->flags_ & telegram_api::invoice::FLEXIBLE_MASK) != 0;
  if (send_phone_number_to_provider) {
    need_phone_number = true;
  }
  if (send_email_address_to_provider) {
    need_email_address = true;
  }
  if (is_flexible) {
    need_shipping_address = true;
  }

  if (invoice->max_tip_amount_ < 0 || !check_currency_amount(invoice->max_tip_amount_)) {
    LOG(ERROR) << "Receive invalid maximum tip amount " << invoice->max_tip_amount_;
    invoice->max_tip_amount_ = 0;
  }
  td::remove_if(invoice->suggested_tip_amounts_,
                [](int64 amount) { return amount < 0 || !check_currency_amount(amount); });
  if (invoice->suggested_tip_amounts_.size() > 4) {
    invoice->suggested_tip_amounts_.resize(4);
  }

  string recurring_terms_url;
  string terms_url;
  if (invoice->recurring_) {
    recurring_terms_url = std::move(invoice->terms_url_);
  } else {
    terms_url = std::move(invoice->terms_url_);
  }
  return td_api::make_object<td_api::invoice>(
      std::move(invoice->currency_), std::move(labeled_prices), max(invoice->subscription_period_, 0),
      invoice->max_tip_amount_, std::move(invoice->suggested_tip_amounts_), recurring_terms_url, terms_url, is_test,
      need_name, need_phone_number, need_email_address, need_shipping_address, send_phone_number_to_provider,
      send_email_address_to_provider, is_flexible);
}

static tl_object_ptr<td_api::PaymentProvider> convert_payment_provider(
    const string &native_provider_name, tl_object_ptr<telegram_api::dataJSON> native_parameters, bool is_test) {
  if (native_parameters == nullptr) {
    return nullptr;
  }

  if (native_provider_name == "smartglocal") {
    string data = native_parameters->data_;
    auto r_value = json_decode(data);
    if (r_value.is_error()) {
      LOG(ERROR) << "Can't parse JSON object \"" << native_parameters->data_ << "\": " << r_value.error();
      return nullptr;
    }

    auto value = r_value.move_as_ok();
    if (value.type() != JsonValue::Type::Object) {
      LOG(ERROR) << "Wrong JSON data \"" << native_parameters->data_ << '"';
      return nullptr;
    }

    const auto &object = value.get_object();
    auto r_public_token = object.get_required_string_field("public_token");
    if (r_public_token.is_error()) {
      LOG(ERROR) << "Unsupported JSON data \"" << native_parameters->data_ << '"';
      return nullptr;
    }
    string tokenize_url = is_test ? "https://tgb-playground.smart-glocal.com/cds/v1/tokenize/card"
                                  : "https://tgb.smart-glocal.com/cds/v1/tokenize/card";
    auto r_tokenize_url = object.get_optional_string_field("tokenize_url");
    if (r_tokenize_url.is_ok() && begins_with(r_tokenize_url.ok(), "https://") &&
        ends_with(r_tokenize_url.ok(), ".smart-glocal.com/cds/v1/tokenize/card")) {
      tokenize_url = r_tokenize_url.move_as_ok();
    }
    if (object.field_count() > 2) {
      LOG(ERROR) << "Unsupported JSON data \"" << native_parameters->data_ << '"';
    }
    return make_tl_object<td_api::paymentProviderSmartGlocal>(r_public_token.move_as_ok(), tokenize_url);
  }
  if (native_provider_name == "stripe") {
    string data = native_parameters->data_;
    auto r_value = json_decode(data);
    if (r_value.is_error()) {
      LOG(ERROR) << "Can't parse JSON object \"" << native_parameters->data_ << "\": " << r_value.error();
      return nullptr;
    }

    auto value = r_value.move_as_ok();
    if (value.type() != JsonValue::Type::Object) {
      LOG(ERROR) << "Wrong JSON data \"" << native_parameters->data_ << '"';
      return nullptr;
    }

    const auto &object = value.get_object();
    auto r_need_country = object.get_required_bool_field("need_country");
    auto r_need_postal_code = object.get_required_bool_field("need_zip");
    auto r_need_cardholder_name = object.get_required_bool_field("need_cardholder_name");
    auto r_publishable_key = object.get_required_string_field("publishable_key");
    // TODO support "gpay_parameters":{"gateway":"stripe","stripe:publishableKey":"...","stripe:version":"..."}

    if (r_need_country.is_error() || r_need_postal_code.is_error() || r_need_cardholder_name.is_error() ||
        r_publishable_key.is_error()) {
      LOG(ERROR) << "Unsupported JSON data \"" << native_parameters->data_ << '"';
      return nullptr;
    }
    if (object.field_count() != 5) {
      LOG(ERROR) << "Unsupported JSON data \"" << native_parameters->data_ << '"';
    }

    return make_tl_object<td_api::paymentProviderStripe>(r_publishable_key.move_as_ok(), r_need_country.move_as_ok(),
                                                         r_need_postal_code.move_as_ok(),
                                                         r_need_cardholder_name.move_as_ok());
  }

  return nullptr;
}

static tl_object_ptr<td_api::address> convert_address(tl_object_ptr<telegram_api::postAddress> address) {
  if (address == nullptr) {
    return nullptr;
  }
  return make_tl_object<td_api::address>(std::move(address->country_iso2_), std::move(address->state_),
                                         std::move(address->city_), std::move(address->street_line1_),
                                         std::move(address->street_line2_), std::move(address->post_code_));
}

static tl_object_ptr<telegram_api::postAddress> convert_address(tl_object_ptr<td_api::address> address) {
  if (address == nullptr) {
    return nullptr;
  }
  return make_tl_object<telegram_api::postAddress>(std::move(address->street_line1_), std::move(address->street_line2_),
                                                   std::move(address->city_), std::move(address->state_),
                                                   std::move(address->country_code_), std::move(address->postal_code_));
}

static tl_object_ptr<td_api::orderInfo> convert_order_info(
    tl_object_ptr<telegram_api::paymentRequestedInfo> order_info) {
  if (order_info == nullptr) {
    return nullptr;
  }
  return make_tl_object<td_api::orderInfo>(std::move(order_info->name_), std::move(order_info->phone_),
                                           std::move(order_info->email_),
                                           convert_address(std::move(order_info->shipping_address_)));
}

static tl_object_ptr<td_api::shippingOption> convert_shipping_option(
    tl_object_ptr<telegram_api::shippingOption> shipping_option) {
  if (shipping_option == nullptr) {
    return nullptr;
  }

  return make_tl_object<td_api::shippingOption>(std::move(shipping_option->id_), std::move(shipping_option->title_),
                                                transform(std::move(shipping_option->prices_), convert_labeled_price));
}

static tl_object_ptr<telegram_api::paymentRequestedInfo> convert_order_info(
    tl_object_ptr<td_api::orderInfo> order_info) {
  if (order_info == nullptr) {
    return nullptr;
  }
  int32 flags = 0;
  if (!order_info->name_.empty()) {
    flags |= telegram_api::paymentRequestedInfo::NAME_MASK;
  }
  if (!order_info->phone_number_.empty()) {
    flags |= telegram_api::paymentRequestedInfo::PHONE_MASK;
  }
  if (!order_info->email_address_.empty()) {
    flags |= telegram_api::paymentRequestedInfo::EMAIL_MASK;
  }
  if (order_info->shipping_address_ != nullptr) {
    flags |= telegram_api::paymentRequestedInfo::SHIPPING_ADDRESS_MASK;
  }
  return make_tl_object<telegram_api::paymentRequestedInfo>(
      flags, std::move(order_info->name_), std::move(order_info->phone_number_), std::move(order_info->email_address_),
      convert_address(std::move(order_info->shipping_address_)));
}

static vector<tl_object_ptr<td_api::savedCredentials>> convert_saved_credentials(
    vector<tl_object_ptr<telegram_api::paymentSavedCredentialsCard>> saved_credentials) {
  return transform(
      std::move(saved_credentials), [](tl_object_ptr<telegram_api::paymentSavedCredentialsCard> &&credentials) {
        return make_tl_object<td_api::savedCredentials>(std::move(credentials->id_), std::move(credentials->title_));
      });
}

class GetPaymentFormQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<td_api::paymentForm>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetPaymentFormQuery(Promise<tl_object_ptr<td_api::paymentForm>> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputInvoiceInfo &&input_invoice_info, tl_object_ptr<telegram_api::dataJSON> &&theme_parameters) {
    dialog_id_ = input_invoice_info.dialog_id_;

    int32 flags = 0;
    if (theme_parameters != nullptr) {
      flags |= telegram_api::payments_getPaymentForm::THEME_PARAMS_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::payments_getPaymentForm(
        flags, std::move(input_invoice_info.input_invoice_), std::move(theme_parameters))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getPaymentForm>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto payment_form_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPaymentFormQuery: " << to_string(payment_form_ptr);
    switch (payment_form_ptr->get_id()) {
      case telegram_api::payments_paymentForm::ID: {
        auto payment_form = telegram_api::move_object_as<telegram_api::payments_paymentForm>(payment_form_ptr);

        td_->user_manager_->on_get_users(std::move(payment_form->users_), "GetPaymentFormQuery 1");

        UserId payments_provider_user_id(payment_form->provider_id_);
        if (!payments_provider_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid payments provider " << payments_provider_user_id;
          return on_error(Status::Error(500, "Receive invalid payments provider identifier"));
        }
        UserId seller_bot_user_id(payment_form->bot_id_);
        if (!seller_bot_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid seller " << seller_bot_user_id;
          return on_error(Status::Error(500, "Receive invalid seller identifier"));
        }
        bool can_save_credentials = payment_form->can_save_credentials_;
        bool need_password = payment_form->password_missing_;
        auto photo = get_web_document_photo(td_->file_manager_.get(), std::move(payment_form->photo_), dialog_id_);
        auto payment_provider = convert_payment_provider(
            payment_form->native_provider_, std::move(payment_form->native_params_), payment_form->invoice_->test_);
        if (payment_provider == nullptr) {
          payment_provider = td_api::make_object<td_api::paymentProviderOther>(std::move(payment_form->url_));
        }
        auto additional_payment_options =
            transform(payment_form->additional_methods_,
                      [](const telegram_api::object_ptr<telegram_api::paymentFormMethod> &method) {
                        return td_api::make_object<td_api::paymentOption>(method->title_, method->url_);
                      });
        auto type = td_api::make_object<td_api::paymentFormTypeRegular>(
            convert_invoice(std::move(payment_form->invoice_)),
            td_->user_manager_->get_user_id_object(payments_provider_user_id, "paymentForm provider"),
            std::move(payment_provider), std::move(additional_payment_options),
            convert_order_info(std::move(payment_form->saved_info_)),
            convert_saved_credentials(std::move(payment_form->saved_credentials_)), can_save_credentials,
            need_password);
        promise_.set_value(td_api::make_object<td_api::paymentForm>(
            payment_form->form_id_, std::move(type),
            td_->user_manager_->get_user_id_object(seller_bot_user_id, "paymentForm seller"),
            get_product_info_object(td_, payment_form->title_, payment_form->description_, photo)));
        break;
      }
      case telegram_api::payments_paymentFormStars::ID: {
        auto payment_form = telegram_api::move_object_as<telegram_api::payments_paymentFormStars>(payment_form_ptr);

        td_->user_manager_->on_get_users(std::move(payment_form->users_), "GetPaymentFormQuery 2");

        UserId seller_bot_user_id(payment_form->bot_id_);
        if (!seller_bot_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid seller " << seller_bot_user_id;
          return on_error(Status::Error(500, "Receive invalid seller identifier"));
        }
        if (payment_form->invoice_->prices_.size() != 1u) {
          LOG(ERROR) << "Receive invalid prices " << to_string(payment_form->invoice_->prices_);
          return on_error(Status::Error(500, "Receive invalid price"));
        }
        auto photo = get_web_document_photo(td_->file_manager_.get(), std::move(payment_form->photo_), dialog_id_);
        auto star_count = StarManager::get_star_count(payment_form->invoice_->prices_[0]->amount_);
        td_api::object_ptr<td_api::PaymentFormType> type;
        if (payment_form->invoice_->subscription_period_ > 0) {
          type = td_api::make_object<td_api::paymentFormTypeStarSubscription>(
              td_api::make_object<td_api::starSubscriptionPricing>(payment_form->invoice_->subscription_period_,
                                                                   star_count));
        } else {
          type = td_api::make_object<td_api::paymentFormTypeStars>(star_count);
        }
        promise_.set_value(td_api::make_object<td_api::paymentForm>(
            payment_form->form_id_, std::move(type),
            td_->user_manager_->get_user_id_object(seller_bot_user_id, "paymentForm seller"),
            get_product_info_object(td_, payment_form->title_, payment_form->description_, photo)));
        break;
      }
      case telegram_api::payments_paymentFormStarGift::ID:
        LOG(ERROR) << "Receive " << to_string(payment_form_ptr);
        promise_.set_error(Status::Error(500, "Unsupported"));
        break;
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPaymentFormQuery");
    promise_.set_error(std::move(status));
  }
};

class ValidateRequestedInfoQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<td_api::validatedOrderInfo>> promise_;
  DialogId dialog_id_;

 public:
  explicit ValidateRequestedInfoQuery(Promise<tl_object_ptr<td_api::validatedOrderInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputInvoiceInfo &&input_invoice_info, tl_object_ptr<telegram_api::paymentRequestedInfo> requested_info,
            bool allow_save) {
    dialog_id_ = input_invoice_info.dialog_id_;

    int32 flags = 0;
    if (allow_save) {
      flags |= telegram_api::payments_validateRequestedInfo::SAVE_MASK;
    }
    if (requested_info == nullptr) {
      requested_info = make_tl_object<telegram_api::paymentRequestedInfo>();
      requested_info->flags_ = 0;
    }
    send_query(G()->net_query_creator().create(telegram_api::payments_validateRequestedInfo(
        flags, false /*ignored*/, std::move(input_invoice_info.input_invoice_), std::move(requested_info))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_validateRequestedInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto validated_order_info = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ValidateRequestedInfoQuery: " << to_string(validated_order_info);

    promise_.set_value(make_tl_object<td_api::validatedOrderInfo>(
        std::move(validated_order_info->id_),
        transform(std::move(validated_order_info->shipping_options_), convert_shipping_option)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ValidateRequestedInfoQuery");
    promise_.set_error(std::move(status));
  }
};

class SendPaymentFormQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<td_api::paymentResult>> promise_;
  DialogId dialog_id_;

 public:
  explicit SendPaymentFormQuery(Promise<tl_object_ptr<td_api::paymentResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputInvoiceInfo &&input_invoice_info, int64 payment_form_id, const string &order_info_id,
            const string &shipping_option_id, tl_object_ptr<telegram_api::InputPaymentCredentials> input_credentials,
            int64 tip_amount) {
    CHECK(input_credentials != nullptr);

    dialog_id_ = input_invoice_info.dialog_id_;

    int32 flags = 0;
    if (!order_info_id.empty()) {
      flags |= telegram_api::payments_sendPaymentForm::REQUESTED_INFO_ID_MASK;
    }
    if (!shipping_option_id.empty()) {
      flags |= telegram_api::payments_sendPaymentForm::SHIPPING_OPTION_ID_MASK;
    }
    if (tip_amount != 0) {
      flags |= telegram_api::payments_sendPaymentForm::TIP_AMOUNT_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::payments_sendPaymentForm(
        flags, payment_form_id, std::move(input_invoice_info.input_invoice_), order_info_id, shipping_option_id,
        std::move(input_credentials), tip_amount)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_sendPaymentForm>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto payment_result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendPaymentFormQuery: " << to_string(payment_result);

    switch (payment_result->get_id()) {
      case telegram_api::payments_paymentResult::ID: {
        auto result = move_tl_object_as<telegram_api::payments_paymentResult>(payment_result);
        td_->updates_manager_->on_get_updates(
            std::move(result->updates_), PromiseCreator::lambda([promise = std::move(promise_)](Unit) mutable {
              promise.set_value(make_tl_object<td_api::paymentResult>(true, string()));
            }));
        return;
      }
      case telegram_api::payments_paymentVerificationNeeded::ID: {
        auto result = move_tl_object_as<telegram_api::payments_paymentVerificationNeeded>(payment_result);
        promise_.set_value(make_tl_object<td_api::paymentResult>(false, std::move(result->url_)));
        return;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendPaymentFormQuery");
    promise_.set_error(std::move(status));
  }
};

class SendStarPaymentFormQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::paymentResult>> promise_;
  DialogId dialog_id_;
  int64 star_count_;

 public:
  explicit SendStarPaymentFormQuery(Promise<td_api::object_ptr<td_api::paymentResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputInvoiceInfo &&input_invoice_info, int64 payment_form_id) {
    dialog_id_ = input_invoice_info.dialog_id_;
    star_count_ = input_invoice_info.star_count_;
    td_->star_manager_->add_pending_owned_star_count(-star_count_, false);

    send_query(G()->net_query_creator().create(
        telegram_api::payments_sendStarsForm(payment_form_id, std::move(input_invoice_info.input_invoice_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_sendStarsForm>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto payment_result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendStarPaymentFormQuery: " << to_string(payment_result);

    td_->star_manager_->add_pending_owned_star_count(star_count_, true);
    switch (payment_result->get_id()) {
      case telegram_api::payments_paymentResult::ID: {
        auto result = telegram_api::move_object_as<telegram_api::payments_paymentResult>(payment_result);
        td_->updates_manager_->on_get_updates(
            std::move(result->updates_), PromiseCreator::lambda([promise = std::move(promise_)](Unit) mutable {
              promise.set_value(td_api::make_object<td_api::paymentResult>(true, string()));
            }));
        return;
      }
      case telegram_api::payments_paymentVerificationNeeded::ID: {
        auto result = telegram_api::move_object_as<telegram_api::payments_paymentVerificationNeeded>(payment_result);
        promise_.set_value(td_api::make_object<td_api::paymentResult>(false, std::move(result->url_)));
        return;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendStarPaymentFormQuery");
    td_->star_manager_->add_pending_owned_star_count(star_count_, false);
    promise_.set_error(std::move(status));
  }
};

class GetPaymentReceiptQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<td_api::paymentReceipt>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetPaymentReceiptQuery(Promise<tl_object_ptr<td_api::paymentReceipt>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, ServerMessageId server_message_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(
        telegram_api::payments_getPaymentReceipt(std::move(input_peer), server_message_id.get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getPaymentReceipt>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPaymentReceiptQuery: " << to_string(ptr);
    switch (ptr->get_id()) {
      case telegram_api::payments_paymentReceiptStars::ID: {
        auto payment_receipt = telegram_api::move_object_as<telegram_api::payments_paymentReceiptStars>(ptr);

        td_->user_manager_->on_get_users(std::move(payment_receipt->users_), "GetPaymentReceiptQuery 1");
        UserId seller_bot_user_id(payment_receipt->bot_id_);
        if (!seller_bot_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid seller " << seller_bot_user_id;
          return on_error(Status::Error(500, "Receive invalid seller identifier"));
        }
        auto photo = get_web_document_photo(td_->file_manager_.get(), std::move(payment_receipt->photo_), dialog_id_);
        if (payment_receipt->invoice_->prices_.size() != 1u) {
          LOG(ERROR) << "Receive invalid prices " << to_string(payment_receipt->invoice_->prices_);
          return on_error(Status::Error(500, "Receive invalid price"));
        }
        promise_.set_value(td_api::make_object<td_api::paymentReceipt>(
            get_product_info_object(td_, payment_receipt->title_, payment_receipt->description_, photo),
            payment_receipt->date_, td_->user_manager_->get_user_id_object(seller_bot_user_id, "paymentReceipt seller"),
            td_api::make_object<td_api::paymentReceiptTypeStars>(
                StarManager::get_star_count(payment_receipt->invoice_->prices_[0]->amount_),
                payment_receipt->transaction_id_)));
        break;
      }
      case telegram_api::payments_paymentReceipt::ID: {
        auto payment_receipt = telegram_api::move_object_as<telegram_api::payments_paymentReceipt>(ptr);

        td_->user_manager_->on_get_users(std::move(payment_receipt->users_), "GetPaymentReceiptQuery 2");

        UserId payments_provider_user_id(payment_receipt->provider_id_);
        if (!payments_provider_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid payments provider " << payments_provider_user_id;
          return on_error(Status::Error(500, "Receive invalid payments provider identifier"));
        }
        UserId seller_bot_user_id(payment_receipt->bot_id_);
        if (!seller_bot_user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid seller " << seller_bot_user_id;
          return on_error(Status::Error(500, "Receive invalid seller identifier"));
        }
        auto photo = get_web_document_photo(td_->file_manager_.get(), std::move(payment_receipt->photo_), dialog_id_);
        if (payment_receipt->tip_amount_ < 0 || !check_currency_amount(payment_receipt->tip_amount_)) {
          LOG(ERROR) << "Receive invalid tip amount " << payment_receipt->tip_amount_;
          payment_receipt->tip_amount_ = 0;
        }

        promise_.set_value(td_api::make_object<td_api::paymentReceipt>(
            get_product_info_object(td_, payment_receipt->title_, payment_receipt->description_, photo),
            payment_receipt->date_, td_->user_manager_->get_user_id_object(seller_bot_user_id, "paymentReceipt seller"),
            td_api::make_object<td_api::paymentReceiptTypeRegular>(
                td_->user_manager_->get_user_id_object(payments_provider_user_id, "paymentReceipt provider"),
                convert_invoice(std::move(payment_receipt->invoice_)),
                convert_order_info(std::move(payment_receipt->info_)),
                convert_shipping_option(std::move(payment_receipt->shipping_)),
                std::move(payment_receipt->credentials_title_), payment_receipt->tip_amount_)));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPaymentReceiptQuery");
    promise_.set_error(std::move(status));
  }
};

class GetSavedInfoQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<td_api::orderInfo>> promise_;

 public:
  explicit GetSavedInfoQuery(Promise<tl_object_ptr<td_api::orderInfo>> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::payments_getSavedInfo()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getSavedInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto saved_info = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetSavedInfoQuery: " << to_string(saved_info);
    promise_.set_value(convert_order_info(std::move(saved_info->saved_info_)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ClearSavedInfoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ClearSavedInfoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool clear_credentials, bool clear_order_info) {
    CHECK(clear_credentials || clear_order_info);
    int32 flags = 0;
    if (clear_credentials) {
      flags |= telegram_api::payments_clearSavedInfo::CREDENTIALS_MASK;
    }
    if (clear_order_info) {
      flags |= telegram_api::payments_clearSavedInfo::INFO_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::payments_clearSavedInfo(flags, false /*ignored*/, false /*ignored*/)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_clearSavedInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ExportInvoiceQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit ExportInvoiceQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessConnectionId business_connection_id,
            telegram_api::object_ptr<telegram_api::inputMediaInvoice> &&input_media_invoice) {
    send_query(G()->net_query_creator().create_with_prefix(
        business_connection_id.get_invoke_prefix(),
        telegram_api::payments_exportInvoice(std::move(input_media_invoice)),
        td_->business_connection_manager_->get_business_connection_dc_id(business_connection_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_exportInvoice>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto link = result_ptr.move_as_ok();
    promise_.set_value(std::move(link->url_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetBankCardInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::bankCardInfo>> promise_;

 public:
  explicit GetBankCardInfoQuery(Promise<td_api::object_ptr<td_api::bankCardInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &bank_card_number) {
    send_query(G()->net_query_creator().create(telegram_api::payments_getBankCardData(bank_card_number), {},
                                               G()->get_webfile_dc_id()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getBankCardData>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto response = result_ptr.move_as_ok();
    auto actions = transform(response->open_urls_, [](auto &open_url) {
      return td_api::make_object<td_api::bankCardActionOpenUrl>(open_url->name_, open_url->url_);
    });
    promise_.set_value(td_api::make_object<td_api::bankCardInfo>(response->title_, std::move(actions)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetCollectibleInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::collectibleItemInfo>> promise_;

 public:
  explicit GetCollectibleInfoQuery(Promise<td_api::object_ptr<td_api::collectibleItemInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputCollectible> &&input_collectible) {
    send_query(
        G()->net_query_creator().create(telegram_api::fragment_getCollectibleInfo(std::move(input_collectible))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::fragment_getCollectibleInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    if (result->amount_ <= 0 || !check_currency_amount(result->amount_)) {
      LOG(ERROR) << "Receive invalid collectible item price " << result->amount_;
      result->amount_ = 0;
    }
    if (result->crypto_currency_.empty() || result->crypto_amount_ <= 0) {
      LOG(ERROR) << "Receive invalid collectible item cryptocurrency price " << result->crypto_amount_;
      result->crypto_amount_ = 0;
    }
    promise_.set_value(td_api::make_object<td_api::collectibleItemInfo>(result->purchase_date_, result->currency_,
                                                                        result->amount_, result->crypto_currency_,
                                                                        result->crypto_amount_, result->url_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

void answer_shipping_query(Td *td, int64 shipping_query_id,
                           vector<tl_object_ptr<td_api::shippingOption>> &&shipping_options,
                           const string &error_message, Promise<Unit> &&promise) {
  vector<tl_object_ptr<telegram_api::shippingOption>> options;
  for (auto &option : shipping_options) {
    if (option == nullptr) {
      return promise.set_error(Status::Error(400, "Shipping option must be non-empty"));
    }
    if (!clean_input_string(option->id_)) {
      return promise.set_error(Status::Error(400, "Shipping option identifier must be encoded in UTF-8"));
    }
    if (!clean_input_string(option->title_)) {
      return promise.set_error(Status::Error(400, "Shipping option title must be encoded in UTF-8"));
    }

    vector<tl_object_ptr<telegram_api::labeledPrice>> prices;
    for (auto &price_part : option->price_parts_) {
      if (price_part == nullptr) {
        return promise.set_error(Status::Error(400, "Shipping option price part must be non-empty"));
      }
      if (!clean_input_string(price_part->label_)) {
        return promise.set_error(Status::Error(400, "Shipping option price part label must be encoded in UTF-8"));
      }
      if (!check_currency_amount(price_part->amount_)) {
        return promise.set_error(Status::Error(400, "Too big amount of the currency specified"));
      }

      prices.push_back(make_tl_object<telegram_api::labeledPrice>(std::move(price_part->label_), price_part->amount_));
    }

    options.push_back(make_tl_object<telegram_api::shippingOption>(std::move(option->id_), std::move(option->title_),
                                                                   std::move(prices)));
  }

  td->create_handler<SetBotShippingAnswerQuery>(std::move(promise))
      ->send(shipping_query_id, error_message, std::move(options));
}

void answer_pre_checkout_query(Td *td, int64 pre_checkout_query_id, const string &error_message,
                               Promise<Unit> &&promise) {
  td->create_handler<SetBotPreCheckoutAnswerQuery>(std::move(promise))->send(pre_checkout_query_id, error_message);
}

void get_payment_form(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice,
                      const td_api::object_ptr<td_api::themeParameters> &theme,
                      Promise<tl_object_ptr<td_api::paymentForm>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_invoice_info, get_input_invoice_info(td, std::move(input_invoice)));

  tl_object_ptr<telegram_api::dataJSON> theme_parameters;
  if (theme != nullptr) {
    theme_parameters = make_tl_object<telegram_api::dataJSON>(string());
    theme_parameters->data_ = ThemeManager::get_theme_parameters_json_string(theme);
  }
  td->create_handler<GetPaymentFormQuery>(std::move(promise))
      ->send(std::move(input_invoice_info), std::move(theme_parameters));
}

void validate_order_info(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice,
                         td_api::object_ptr<td_api::orderInfo> &&order_info, bool allow_save,
                         Promise<td_api::object_ptr<td_api::validatedOrderInfo>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_invoice_info, get_input_invoice_info(td, std::move(input_invoice)));

  if (order_info != nullptr) {
    if (!clean_input_string(order_info->name_)) {
      return promise.set_error(Status::Error(400, "Name must be encoded in UTF-8"));
    }
    if (!clean_input_string(order_info->phone_number_)) {
      return promise.set_error(Status::Error(400, "Phone number must be encoded in UTF-8"));
    }
    if (!clean_input_string(order_info->email_address_)) {
      return promise.set_error(Status::Error(400, "Email address must be encoded in UTF-8"));
    }
    if (order_info->shipping_address_ != nullptr) {
      if (!clean_input_string(order_info->shipping_address_->country_code_)) {
        return promise.set_error(Status::Error(400, "Country code must be encoded in UTF-8"));
      }
      if (!clean_input_string(order_info->shipping_address_->state_)) {
        return promise.set_error(Status::Error(400, "State must be encoded in UTF-8"));
      }
      if (!clean_input_string(order_info->shipping_address_->city_)) {
        return promise.set_error(Status::Error(400, "City must be encoded in UTF-8"));
      }
      if (!clean_input_string(order_info->shipping_address_->street_line1_)) {
        return promise.set_error(Status::Error(400, "Street address must be encoded in UTF-8"));
      }
      if (!clean_input_string(order_info->shipping_address_->street_line2_)) {
        return promise.set_error(Status::Error(400, "Street address must be encoded in UTF-8"));
      }
      if (!clean_input_string(order_info->shipping_address_->postal_code_)) {
        return promise.set_error(Status::Error(400, "Postal code must be encoded in UTF-8"));
      }
    }
  }

  td->create_handler<ValidateRequestedInfoQuery>(std::move(promise))
      ->send(std::move(input_invoice_info), convert_order_info(std::move(order_info)), allow_save);
}

void send_payment_form(Td *td, td_api::object_ptr<td_api::InputInvoice> &&input_invoice, int64 payment_form_id,
                       const string &order_info_id, const string &shipping_option_id,
                       const td_api::object_ptr<td_api::InputCredentials> &credentials, int64 tip_amount,
                       Promise<td_api::object_ptr<td_api::paymentResult>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_invoice_info, get_input_invoice_info(td, std::move(input_invoice)));

  if (credentials == nullptr) {
    if (tip_amount != 0 || !order_info_id.empty() || !shipping_option_id.empty()) {
      return promise.set_error(Status::Error(400, "Invalid payment form parameters specified"));
    }
    if (!td->star_manager_->has_owned_star_count(input_invoice_info.star_count_)) {
      return promise.set_error(Status::Error(400, "Have not enough Telegram Stars to complete payment"));
    }
    td->create_handler<SendStarPaymentFormQuery>(std::move(promise))
        ->send(std::move(input_invoice_info), payment_form_id);
    return;
  }

  tl_object_ptr<telegram_api::InputPaymentCredentials> input_credentials;
  switch (credentials->get_id()) {
    case td_api::inputCredentialsSaved::ID: {
      auto credentials_saved = static_cast<const td_api::inputCredentialsSaved *>(credentials.get());
      auto credentials_id = credentials_saved->saved_credentials_id_;
      if (!clean_input_string(credentials_id)) {
        return promise.set_error(Status::Error(400, "Credentials identifier must be encoded in UTF-8"));
      }
      auto temp_password_state = PasswordManager::get_temp_password_state_sync();
      if (!temp_password_state.has_temp_password) {
        return promise.set_error(Status::Error(400, "Temporary password required to use saved credentials"));
      }

      input_credentials = make_tl_object<telegram_api::inputPaymentCredentialsSaved>(
          std::move(credentials_id), BufferSlice(temp_password_state.temp_password));
      break;
    }
    case td_api::inputCredentialsNew::ID: {
      auto credentials_new = static_cast<const td_api::inputCredentialsNew *>(credentials.get());
      int32 flags = 0;
      if (credentials_new->allow_save_) {
        flags |= telegram_api::inputPaymentCredentials::SAVE_MASK;
      }

      input_credentials = make_tl_object<telegram_api::inputPaymentCredentials>(
          flags, false /*ignored*/, make_tl_object<telegram_api::dataJSON>(credentials_new->data_));
      break;
    }
    case td_api::inputCredentialsGooglePay::ID: {
      auto credentials_google_pay = static_cast<const td_api::inputCredentialsGooglePay *>(credentials.get());
      input_credentials = make_tl_object<telegram_api::inputPaymentCredentialsGooglePay>(
          make_tl_object<telegram_api::dataJSON>(credentials_google_pay->data_));
      break;
    }
    case td_api::inputCredentialsApplePay::ID: {
      auto credentials_apple_pay = static_cast<const td_api::inputCredentialsApplePay *>(credentials.get());
      input_credentials = make_tl_object<telegram_api::inputPaymentCredentialsApplePay>(
          make_tl_object<telegram_api::dataJSON>(credentials_apple_pay->data_));
      break;
    }
    default:
      UNREACHABLE();
  }

  td->create_handler<SendPaymentFormQuery>(std::move(promise))
      ->send(std::move(input_invoice_info), payment_form_id, order_info_id, shipping_option_id,
             std::move(input_credentials), tip_amount);
}

void get_payment_receipt(Td *td, MessageFullId message_full_id,
                         Promise<tl_object_ptr<td_api::paymentReceipt>> &&promise) {
  TRY_RESULT_PROMISE(promise, server_message_id,
                     td->messages_manager_->get_payment_successful_message_id(message_full_id));
  td->create_handler<GetPaymentReceiptQuery>(std::move(promise))
      ->send(message_full_id.get_dialog_id(), server_message_id);
}

void get_saved_order_info(Td *td, Promise<tl_object_ptr<td_api::orderInfo>> &&promise) {
  td->create_handler<GetSavedInfoQuery>(std::move(promise))->send();
}

void delete_saved_order_info(Td *td, Promise<Unit> &&promise) {
  td->create_handler<ClearSavedInfoQuery>(std::move(promise))->send(false, true);
}

void delete_saved_credentials(Td *td, Promise<Unit> &&promise) {
  td->create_handler<ClearSavedInfoQuery>(std::move(promise))->send(true, false);
}

void export_invoice(Td *td, BusinessConnectionId business_connection_id,
                    td_api::object_ptr<td_api::InputMessageContent> &&invoice, Promise<string> &&promise) {
  if (invoice == nullptr) {
    return promise.set_error(Status::Error(400, "Invoice must be non-empty"));
  }
  TRY_RESULT_PROMISE(promise, input_invoice,
                     InputInvoice::process_input_message_invoice(std::move(invoice), td, DialogId()));
  if (business_connection_id.is_valid()) {
    TRY_STATUS_PROMISE(promise, td->business_connection_manager_->check_business_connection(
                                    business_connection_id, td->dialog_manager_->get_my_dialog_id()));
  }

  auto input_media = input_invoice.get_input_media_invoice(td, nullptr, nullptr);
  CHECK(input_media != nullptr);
  td->create_handler<ExportInvoiceQuery>(std::move(promise))
      ->send(std::move(business_connection_id), std::move(input_media));
}

void get_bank_card_info(Td *td, const string &bank_card_number,
                        Promise<td_api::object_ptr<td_api::bankCardInfo>> &&promise) {
  td->create_handler<GetBankCardInfoQuery>(std::move(promise))->send(bank_card_number);
}

void get_collectible_info(Td *td, td_api::object_ptr<td_api::CollectibleItemType> type,
                          Promise<td_api::object_ptr<td_api::collectibleItemInfo>> &&promise) {
  if (type == nullptr) {
    return promise.set_error(Status::Error(400, "Item type must be non-empty"));
  }
  switch (type->get_id()) {
    case td_api::collectibleItemTypeUsername::ID: {
      auto username = td_api::move_object_as<td_api::collectibleItemTypeUsername>(type);
      if (!clean_input_string(username->username_)) {
        return promise.set_error(Status::Error(400, "Username must be encoded in UTF-8"));
      }
      td->create_handler<GetCollectibleInfoQuery>(std::move(promise))
          ->send(telegram_api::make_object<telegram_api::inputCollectibleUsername>(username->username_));
      break;
    }
    case td_api::collectibleItemTypePhoneNumber::ID: {
      auto phone_number = td_api::move_object_as<td_api::collectibleItemTypePhoneNumber>(type);
      if (!clean_input_string(phone_number->phone_number_)) {
        return promise.set_error(Status::Error(400, "Phone number must be encoded in UTF-8"));
      }
      td->create_handler<GetCollectibleInfoQuery>(std::move(promise))
          ->send(telegram_api::make_object<telegram_api::inputCollectiblePhone>(phone_number->phone_number_));
      break;
    }
    default:
      UNREACHABLE();
  }
}

}  // namespace td
