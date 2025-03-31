//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Premium.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/Application.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/GiveawayParameters.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageQuote.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/PremiumGiftOption.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <algorithm>

namespace td {

static td_api::object_ptr<td_api::PremiumFeature> get_premium_feature_object(Slice premium_feature) {
  if (premium_feature == "double_limits") {
    return td_api::make_object<td_api::premiumFeatureIncreasedLimits>();
  }
  if (premium_feature == "more_upload") {
    return td_api::make_object<td_api::premiumFeatureIncreasedUploadFileSize>();
  }
  if (premium_feature == "faster_download") {
    return td_api::make_object<td_api::premiumFeatureImprovedDownloadSpeed>();
  }
  if (premium_feature == "voice_to_text") {
    return td_api::make_object<td_api::premiumFeatureVoiceRecognition>();
  }
  if (premium_feature == "no_ads") {
    return td_api::make_object<td_api::premiumFeatureDisabledAds>();
  }
  if (premium_feature == "unique_reactions" || premium_feature == "infinite_reactions") {
    return td_api::make_object<td_api::premiumFeatureUniqueReactions>();
  }
  if (premium_feature == "premium_stickers") {
    return td_api::make_object<td_api::premiumFeatureUniqueStickers>();
  }
  if (premium_feature == "animated_emoji") {
    return td_api::make_object<td_api::premiumFeatureCustomEmoji>();
  }
  if (premium_feature == "advanced_chat_management") {
    return td_api::make_object<td_api::premiumFeatureAdvancedChatManagement>();
  }
  if (premium_feature == "profile_badge") {
    return td_api::make_object<td_api::premiumFeatureProfileBadge>();
  }
  if (premium_feature == "emoji_status") {
    return td_api::make_object<td_api::premiumFeatureEmojiStatus>();
  }
  if (premium_feature == "animated_userpics") {
    return td_api::make_object<td_api::premiumFeatureAnimatedProfilePhoto>();
  }
  if (premium_feature == "forum_topic_icon") {
    return td_api::make_object<td_api::premiumFeatureForumTopicIcon>();
  }
  if (premium_feature == "app_icons") {
    return td_api::make_object<td_api::premiumFeatureAppIcons>();
  }
  if (premium_feature == "translations") {
    return td_api::make_object<td_api::premiumFeatureRealTimeChatTranslation>();
  }
  if (premium_feature == "stories") {
    return td_api::make_object<td_api::premiumFeatureUpgradedStories>();
  }
  if (premium_feature == "channel_boost") {
    return td_api::make_object<td_api::premiumFeatureChatBoost>();
  }
  if (premium_feature == "peer_colors") {
    return td_api::make_object<td_api::premiumFeatureAccentColor>();
  }
  if (premium_feature == "wallpapers") {
    return td_api::make_object<td_api::premiumFeatureBackgroundForBoth>();
  }
  if (premium_feature == "saved_tags") {
    return td_api::make_object<td_api::premiumFeatureSavedMessagesTags>();
  }
  if (premium_feature == "message_privacy") {
    return td_api::make_object<td_api::premiumFeatureMessagePrivacy>();
  }
  if (premium_feature == "last_seen") {
    return td_api::make_object<td_api::premiumFeatureLastSeenTimes>();
  }
  if (premium_feature == "business") {
    return td_api::make_object<td_api::premiumFeatureBusiness>();
  }
  if (premium_feature == "effects") {
    return td_api::make_object<td_api::premiumFeatureMessageEffects>();
  }
  if (G()->is_test_dc()) {
    LOG(ERROR) << "Receive unsupported premium feature " << premium_feature;
  }
  return nullptr;
}

static td_api::object_ptr<td_api::BusinessFeature> get_business_feature_object(Slice business_feature) {
  if (business_feature == "business_location") {
    return td_api::make_object<td_api::businessFeatureLocation>();
  }
  if (business_feature == "business_hours") {
    return td_api::make_object<td_api::businessFeatureOpeningHours>();
  }
  if (business_feature == "quick_replies") {
    return td_api::make_object<td_api::businessFeatureQuickReplies>();
  }
  if (business_feature == "greeting_message") {
    return td_api::make_object<td_api::businessFeatureGreetingMessage>();
  }
  if (business_feature == "away_message") {
    return td_api::make_object<td_api::businessFeatureAwayMessage>();
  }
  if (business_feature == "business_links") {
    return td_api::make_object<td_api::businessFeatureAccountLinks>();
  }
  if (business_feature == "business_intro") {
    return td_api::make_object<td_api::businessFeatureStartPage>();
  }
  if (business_feature == "business_bots") {
    return td_api::make_object<td_api::businessFeatureBots>();
  }
  if (business_feature == "emoji_status") {
    return td_api::make_object<td_api::businessFeatureEmojiStatus>();
  }
  if (business_feature == "folder_tags") {
    return td_api::make_object<td_api::businessFeatureChatFolderTags>();
  }
  if (business_feature == "stories") {
    return td_api::make_object<td_api::businessFeatureUpgradedStories>();
  }
  if (G()->is_test_dc()) {
    LOG(ERROR) << "Receive unsupported business feature " << business_feature;
  }
  return nullptr;
}

Status check_payment_amount(string &currency, int64 amount) {
  if (amount <= 0 || !check_currency_amount(amount)) {
    return Status::Error(400, "Invalid amount of the currency specified");
  }
  if (!clean_input_string(currency)) {
    return Status::Error(400, "Strings must be encoded in UTF-8");
  }
  return Status::OK();
}

Result<telegram_api::object_ptr<telegram_api::InputPeer>> get_boost_input_peer(Td *td, DialogId dialog_id) {
  if (!td->dialog_manager_->have_dialog_force(dialog_id, "get_boost_input_peer")) {
    return Status::Error(400, "Chat to boost not found");
  }
  if (dialog_id.get_type() != DialogType::Channel) {
    return Status::Error(400, "Can't boost the chat");
  }
  if (!td->chat_manager_->get_channel_status(dialog_id.get_channel_id()).is_administrator()) {
    return Status::Error(400, "Not enough rights in the chat");
  }
  auto boost_input_peer = td->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
  CHECK(boost_input_peer != nullptr);
  return std::move(boost_input_peer);
}

Result<telegram_api::object_ptr<telegram_api::textWithEntities>> get_premium_gift_text(
    Td *td, td_api::object_ptr<td_api::formattedText> &&text) {
  TRY_RESULT(message, get_formatted_text(td, td->dialog_manager_->get_my_dialog_id(), std::move(text), false, true,
                                         true, false));
  MessageQuote::remove_unallowed_quote_entities(message);
  if (!message.text.empty()) {
    return get_input_text_with_entities(td->user_manager_.get(), message, "get_premium_gift_text");
  }
  return nullptr;
}

static Result<tl_object_ptr<telegram_api::InputStorePaymentPurpose>> get_input_store_payment_purpose(
    Td *td, td_api::object_ptr<td_api::StorePaymentPurpose> &purpose) {
  if (purpose == nullptr) {
    return Status::Error(400, "Purchase purpose must be non-empty");
  }

  switch (purpose->get_id()) {
    case td_api::storePaymentPurposePremiumSubscription::ID: {
      auto p = static_cast<td_api::storePaymentPurposePremiumSubscription *>(purpose.get());
      int32 flags = 0;
      if (p->is_restore_) {
        flags |= telegram_api::inputStorePaymentPremiumSubscription::RESTORE_MASK;
      }
      if (p->is_upgrade_) {
        flags |= telegram_api::inputStorePaymentPremiumSubscription::UPGRADE_MASK;
      }
      return make_tl_object<telegram_api::inputStorePaymentPremiumSubscription>(flags, false /*ignored*/,
                                                                                false /*ignored*/);
    }
    case td_api::storePaymentPurposePremiumGift::ID: {
      auto p = static_cast<td_api::storePaymentPurposePremiumGift *>(purpose.get());
      vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
      TRY_RESULT(input_user, td->user_manager_->get_input_user(UserId(p->user_id_)));
      input_users.push_back(std::move(input_user));
      TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
      TRY_RESULT(text, get_premium_gift_text(td, std::move(p->text_)));

      int32 flags = 0;
      if (text != nullptr) {
        flags |= telegram_api::inputStorePaymentPremiumGiftCode::MESSAGE_MASK;
      }
      return telegram_api::make_object<telegram_api::inputStorePaymentPremiumGiftCode>(
          flags, std::move(input_users), nullptr, p->currency_, p->amount_, std::move(text));
    }
    case td_api::storePaymentPurposePremiumGiftCodes::ID: {
      auto p = static_cast<td_api::storePaymentPurposePremiumGiftCodes *>(purpose.get());
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
      return telegram_api::make_object<telegram_api::inputStorePaymentPremiumGiftCode>(
          flags, std::move(input_users), std::move(boost_input_peer), p->currency_, p->amount_, std::move(text));
    }
    case td_api::storePaymentPurposePremiumGiveaway::ID: {
      auto p = static_cast<td_api::storePaymentPurposePremiumGiveaway *>(purpose.get());
      TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
      TRY_RESULT(parameters, GiveawayParameters::get_giveaway_parameters(td, p->parameters_.get()));
      return parameters.get_input_store_payment_premium_giveaway(td, p->currency_, p->amount_);
    }
    case td_api::storePaymentPurposeStarGiveaway::ID: {
      auto p = static_cast<td_api::storePaymentPurposeStarGiveaway *>(purpose.get());
      TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
      if (p->winner_count_ <= 0 || p->star_count_ <= 0) {
        return Status::Error(400, "Invalid giveaway parameters specified");
      }
      TRY_RESULT(parameters, GiveawayParameters::get_giveaway_parameters(td, p->parameters_.get()));
      return parameters.get_input_store_payment_stars_giveaway(td, p->currency_, p->amount_, p->winner_count_,
                                                               p->star_count_);
    }
    case td_api::storePaymentPurposeStars::ID: {
      auto p = static_cast<td_api::storePaymentPurposeStars *>(purpose.get());
      TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
      dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::StarsSubscriptionLowBalance}, Promise<Unit>());
      return telegram_api::make_object<telegram_api::inputStorePaymentStarsTopup>(p->star_count_, p->currency_,
                                                                                  p->amount_);
    }
    case td_api::storePaymentPurposeGiftedStars::ID: {
      auto p = static_cast<td_api::storePaymentPurposeGiftedStars *>(purpose.get());
      UserId user_id(p->user_id_);
      TRY_RESULT(input_user, td->user_manager_->get_input_user(user_id));
      TRY_STATUS(check_payment_amount(p->currency_, p->amount_));
      return telegram_api::make_object<telegram_api::inputStorePaymentStarsGift>(std::move(input_user), p->star_count_,
                                                                                 p->currency_, p->amount_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

class GetPremiumPromoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::premiumState>> promise_;

 public:
  explicit GetPremiumPromoQuery(Promise<td_api::object_ptr<td_api::premiumState>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_getPremiumPromo()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getPremiumPromo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto promo = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPremiumPromoQuery: " << to_string(promo);

    td_->user_manager_->on_get_users(std::move(promo->users_), "GetPremiumPromoQuery");

    auto state = get_message_text(td_->user_manager_.get(), std::move(promo->status_text_),
                                  std::move(promo->status_entities_), true, true, 0, false, "GetPremiumPromoQuery");

    if (promo->video_sections_.size() != promo->videos_.size()) {
      return on_error(Status::Error(500, "Receive wrong number of videos"));
    }

    vector<td_api::object_ptr<td_api::premiumFeaturePromotionAnimation>> animations;
    vector<td_api::object_ptr<td_api::businessFeaturePromotionAnimation>> business_animations;
    FlatHashSet<string> video_sections;
    for (size_t i = 0; i < promo->video_sections_.size(); i++) {
      if (promo->video_sections_[i].empty() || !video_sections.insert(promo->video_sections_[i]).second) {
        LOG(ERROR) << "Receive duplicate Premium feature animation " << promo->video_sections_[i];
        continue;
      }

      auto video = std::move(promo->videos_[i]);
      if (video->get_id() != telegram_api::document::ID) {
        LOG(ERROR) << "Receive " << to_string(video) << " for " << promo->video_sections_[i];
        continue;
      }

      auto parsed_document = td_->documents_manager_->on_get_document(
          move_tl_object_as<telegram_api::document>(video), DialogId(), false, nullptr, Document::Type::Animation);

      if (parsed_document.type != Document::Type::Animation) {
        LOG(ERROR) << "Receive " << parsed_document.type << " for " << promo->video_sections_[i];
        continue;
      }

      auto feature = get_premium_feature_object(promo->video_sections_[i]);
      if (feature != nullptr) {
        auto animation_object = td_->animations_manager_->get_animation_object(parsed_document.file_id);
        animations.push_back(td_api::make_object<td_api::premiumFeaturePromotionAnimation>(
            std::move(feature), std::move(animation_object)));
      } else {
        auto business_feature = get_business_feature_object(promo->video_sections_[i]);
        if (business_feature != nullptr) {
          auto animation_object = td_->animations_manager_->get_animation_object(parsed_document.file_id);
          business_animations.push_back(td_api::make_object<td_api::businessFeaturePromotionAnimation>(
              std::move(business_feature), std::move(animation_object)));
        } else if (G()->is_test_dc()) {
          LOG(ERROR) << "Receive unsupported feature " << promo->video_sections_[i];
        }
      }
    }

    auto period_options = get_premium_gift_options(std::move(promo->period_options_));
    promise_.set_value(
        td_api::make_object<td_api::premiumState>(get_formatted_text_object(td_->user_manager_.get(), state, true, 0),
                                                  get_premium_state_payment_options_object(period_options),
                                                  std::move(animations), std::move(business_animations)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetPremiumGiftOptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::premiumGiftPaymentOptions>> promise_;

 public:
  explicit GetPremiumGiftOptionsQuery(Promise<td_api::object_ptr<td_api::premiumGiftPaymentOptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::payments_getPremiumGiftCodeOptions(0, nullptr)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getPremiumGiftCodeOptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    td::remove_if(results, [](const telegram_api::object_ptr<telegram_api::premiumGiftCodeOption> &payment_option) {
      return payment_option->users_ != 1 || payment_option->months_ <= 0 || payment_option->amount_ <= 0 ||
             payment_option->currency_.empty() || payment_option->store_quantity_ > 1;
    });
    auto get_monthly_price = [](const telegram_api::object_ptr<telegram_api::premiumGiftCodeOption> &payment_option) {
      return static_cast<double>(payment_option->amount_) / static_cast<double>(payment_option->months_);
    };
    FlatHashMap<string, double> max_prices;
    FlatHashMap<int32, int64> star_prices;
    for (auto &result : results) {
      if (result->currency_ == "XTR") {
        if (!star_prices.emplace(result->months_, StarManager::get_star_count(result->amount_)).second) {
          LOG(ERROR) << "Receive duplicate Telegram Star price for " << result->months_;
        }
        continue;
      }
      auto &max_price = max_prices[result->currency_];
      auto price = get_monthly_price(result);
      if (price > max_price) {
        max_price = price;
      }
    }

    vector<td_api::object_ptr<td_api::premiumGiftPaymentOption>> options;
    for (auto &result : results) {
      if (result->currency_ == "XTR") {
        continue;
      }
      double relative_price = get_monthly_price(result) / max_prices[result->currency_];
      options.push_back(td_api::make_object<td_api::premiumGiftPaymentOption>(
          result->currency_, result->amount_, star_prices[result->months_],
          static_cast<int32>(100 * (1.0 - relative_price)), result->months_, result->store_product_,
          td_->stickers_manager_->get_premium_gift_sticker_object(result->months_, 0)));
    }
    std::sort(options.begin(), options.end(),
              [](const auto &lhs, const auto &rhs) { return lhs->month_count_ < rhs->month_count_; });
    promise_.set_value(td_api::make_object<td_api::premiumGiftPaymentOptions>(std::move(options)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetPremiumGiveawayOptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::premiumGiveawayPaymentOptions>> promise_;
  DialogId boosted_dialog_id_;

 public:
  explicit GetPremiumGiveawayOptionsQuery(Promise<td_api::object_ptr<td_api::premiumGiveawayPaymentOptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId boosted_dialog_id) {
    auto r_boost_input_peer = get_boost_input_peer(td_, boosted_dialog_id);
    if (r_boost_input_peer.is_error()) {
      return on_error(r_boost_input_peer.move_as_error());
    }
    auto boost_input_peer = r_boost_input_peer.move_as_ok();

    int32 flags = telegram_api::payments_getPremiumGiftCodeOptions::BOOST_PEER_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::payments_getPremiumGiftCodeOptions(flags, std::move(boost_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getPremiumGiftCodeOptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    td::remove_if(results, [](const telegram_api::object_ptr<telegram_api::premiumGiftCodeOption> &payment_option) {
      return payment_option->users_ <= 0 || payment_option->months_ <= 0 || payment_option->amount_ <= 0 ||
             payment_option->currency_.empty() || payment_option->currency_ == "XTR";
    });

    vector<td_api::object_ptr<td_api::premiumGiveawayPaymentOption>> options;
    for (auto &result : results) {
      if (result->store_product_.empty()) {
        result->store_quantity_ = 0;
      } else if (result->store_quantity_ <= 0) {
        result->store_quantity_ = 1;
      }
      options.push_back(td_api::make_object<td_api::premiumGiveawayPaymentOption>(
          result->currency_, result->amount_, result->users_, result->months_, result->store_product_,
          result->store_quantity_));
    }

    promise_.set_value(td_api::make_object<td_api::premiumGiveawayPaymentOptions>(std::move(options)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(boosted_dialog_id_, status, "GetPremiumGiveawayOptionsQuery");
    promise_.set_error(std::move(status));
  }
};

class CheckGiftCodeQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::premiumGiftCodeInfo>> promise_;

 public:
  explicit CheckGiftCodeQuery(Promise<td_api::object_ptr<td_api::premiumGiftCodeInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &code) {
    send_query(G()->net_query_creator().create(telegram_api::payments_checkGiftCode(code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_checkGiftCode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CheckGiftCodeQuery: " << to_string(result);
    td_->user_manager_->on_get_users(std::move(result->users_), "CheckGiftCodeQuery");
    td_->chat_manager_->on_get_chats(std::move(result->chats_), "CheckGiftCodeQuery");

    if (result->date_ <= 0 || result->months_ <= 0 || result->used_date_ < 0) {
      LOG(ERROR) << "Receive " << to_string(result);
      return on_error(Status::Error(500, "Receive invalid response"));
    }

    DialogId creator_dialog_id;
    if (result->from_id_ != nullptr) {
      creator_dialog_id = DialogId(result->from_id_);
      if (!creator_dialog_id.is_valid() ||
          !td_->dialog_manager_->have_dialog_info_force(creator_dialog_id, "CheckGiftCodeQuery")) {
        LOG(ERROR) << "Receive " << to_string(result);
        return on_error(Status::Error(500, "Receive invalid response"));
      }
      if (creator_dialog_id.get_type() != DialogType::User) {
        td_->dialog_manager_->force_create_dialog(creator_dialog_id, "CheckGiftCodeQuery", true);
      }
    }
    UserId user_id(result->to_id_);
    if (!user_id.is_valid() && user_id != UserId()) {
      LOG(ERROR) << "Receive " << to_string(result);
      user_id = UserId();
    }
    MessageId message_id(ServerMessageId(result->giveaway_msg_id_));
    if (!message_id.is_valid() && message_id != MessageId()) {
      LOG(ERROR) << "Receive " << to_string(result);
      message_id = MessageId();
    }
    if (message_id != MessageId() && creator_dialog_id.get_type() != DialogType::Channel) {
      LOG(ERROR) << "Receive " << to_string(result);
      message_id = MessageId();
    }
    promise_.set_value(td_api::make_object<td_api::premiumGiftCodeInfo>(
        creator_dialog_id == DialogId() ? nullptr
                                        : get_message_sender_object(td_, creator_dialog_id, "premiumGiftCodeInfo"),
        result->date_, result->via_giveaway_, message_id.get(), result->months_,
        td_->user_manager_->get_user_id_object(user_id, "premiumGiftCodeInfo"), result->used_date_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ApplyGiftCodeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ApplyGiftCodeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &code) {
    send_query(G()->net_query_creator().create(telegram_api::payments_applyGiftCode(code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_applyGiftCode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ApplyGiftCodeQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class LaunchPrepaidGiveawayQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit LaunchPrepaidGiveawayQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 giveaway_id, const GiveawayParameters &parameters, int32 user_count, int64 star_count) {
    auto dialog_id = parameters.get_boosted_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    telegram_api::object_ptr<telegram_api::InputStorePaymentPurpose> purpose;
    if (star_count == 0) {
      purpose = parameters.get_input_store_payment_premium_giveaway(td_, string(), 0);
    } else {
      purpose = parameters.get_input_store_payment_stars_giveaway(td_, string(), 12345, user_count, star_count);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::payments_launchPrepaidGiveaway(std::move(input_peer), giveaway_id, std::move(purpose))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_launchPrepaidGiveaway>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for LaunchPrepaidGiveawayQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGiveawayInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::GiveawayInfo>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetGiveawayInfoQuery(Promise<td_api::object_ptr<td_api::GiveawayInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, ServerMessageId server_message_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::payments_getGiveawayInfo(std::move(input_peer), server_message_id.get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getGiveawayInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetGiveawayInfoQuery: " << to_string(ptr);
    switch (ptr->get_id()) {
      case telegram_api::payments_giveawayInfo::ID: {
        auto info = telegram_api::move_object_as<telegram_api::payments_giveawayInfo>(ptr);
        auto status = [&]() -> td_api::object_ptr<td_api::GiveawayParticipantStatus> {
          if (info->joined_too_early_date_ > 0) {
            return td_api::make_object<td_api::giveawayParticipantStatusAlreadyWasMember>(info->joined_too_early_date_);
          }
          if (info->admin_disallowed_chat_id_ > 0) {
            ChannelId channel_id(info->admin_disallowed_chat_id_);
            if (!channel_id.is_valid() || !td_->chat_manager_->have_channel_force(channel_id, "GetGiveawayInfoQuery")) {
              LOG(ERROR) << "Receive " << to_string(info);
            } else {
              DialogId dialog_id(channel_id);
              td_->dialog_manager_->force_create_dialog(dialog_id, "GetGiveawayInfoQuery");
              return td_api::make_object<td_api::giveawayParticipantStatusAdministrator>(
                  td_->dialog_manager_->get_chat_id_object(dialog_id, "giveawayParticipantStatusAdministrator"));
            }
          }
          if (!info->disallowed_country_.empty()) {
            return td_api::make_object<td_api::giveawayParticipantStatusDisallowedCountry>(info->disallowed_country_);
          }
          if (info->participating_) {
            return td_api::make_object<td_api::giveawayParticipantStatusParticipating>();
          }
          return td_api::make_object<td_api::giveawayParticipantStatusEligible>();
        }();
        promise_.set_value(td_api::make_object<td_api::giveawayInfoOngoing>(
            max(0, info->start_date_), std::move(status), info->preparing_results_));
        break;
      }
      case telegram_api::payments_giveawayInfoResults::ID: {
        auto info = telegram_api::move_object_as<telegram_api::payments_giveawayInfoResults>(ptr);
        auto winner_count = info->winners_count_;
        auto activated_count = info->activated_count_;
        if (activated_count < 0 || activated_count > winner_count) {
          LOG(ERROR) << "Receive " << to_string(info);
          if (activated_count < 0) {
            activated_count = 0;
          }
          if (winner_count < 0) {
            winner_count = 0;
          }
          if (activated_count > winner_count) {
            activated_count = winner_count;
          }
        }
        promise_.set_value(td_api::make_object<td_api::giveawayInfoCompleted>(
            max(0, info->start_date_), max(0, info->finish_date_), info->refunded_, info->winner_, winner_count,
            activated_count, info->gift_code_slug_, StarManager::get_star_count(info->stars_prize_)));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetGiveawayInfoQuery");
    promise_.set_error(std::move(status));
  }
};

class CanPurchasePremiumQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit CanPurchasePremiumQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose) {
    auto r_input_purpose = get_input_store_payment_purpose(td_, purpose);
    if (r_input_purpose.is_error()) {
      return on_error(r_input_purpose.move_as_error());
    }

    send_query(
        G()->net_query_creator().create(telegram_api::payments_canPurchasePremium(r_input_purpose.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_canPurchasePremium>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Premium can't be purchased"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AssignAppStoreTransactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AssignAppStoreTransactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &receipt, td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose) {
    auto r_input_purpose = get_input_store_payment_purpose(td_, purpose);
    if (r_input_purpose.is_error()) {
      return on_error(r_input_purpose.move_as_error());
    }

    send_query(G()->net_query_creator().create(
        telegram_api::payments_assignAppStoreTransaction(BufferSlice(receipt), r_input_purpose.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_assignAppStoreTransaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AssignAppStoreTransactionQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AssignPlayMarketTransactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AssignPlayMarketTransactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &package_name, const string &store_product_id, const string &purchase_token,
            td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose) {
    auto r_input_purpose = get_input_store_payment_purpose(td_, purpose);
    if (r_input_purpose.is_error()) {
      return on_error(r_input_purpose.move_as_error());
    }
    auto receipt = make_tl_object<telegram_api::dataJSON>(string());
    receipt->data_ = json_encode<string>(json_object([&](auto &o) {
      o("packageName", package_name);
      o("purchaseToken", purchase_token);
      o("productId", store_product_id);
    }));
    send_query(G()->net_query_creator().create(
        telegram_api::payments_assignPlayMarketTransaction(std::move(receipt), r_input_purpose.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_assignPlayMarketTransaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AssignPlayMarketTransactionQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

const vector<Slice> &get_premium_limit_keys() {
  static const vector<Slice> limit_keys{"channels",
                                        "saved_gifs",
                                        "stickers_faved",
                                        "dialog_filters",
                                        "dialog_filters_chats",
                                        "dialogs_pinned",
                                        "dialogs_folder_pinned",
                                        "channels_public",
                                        "caption_length",
                                        "about_length",
                                        "chatlist_invites",
                                        "chatlists_joined",
                                        "story_expiring",
                                        "story_caption_length",
                                        "stories_sent_weekly",
                                        "stories_sent_monthly",
                                        "stories_suggested_reactions",
                                        "recommended_channels",
                                        "saved_dialogs_pinned"};
  return limit_keys;
}

static Slice get_limit_type_key(const td_api::PremiumLimitType *limit_type) {
  CHECK(limit_type != nullptr);
  switch (limit_type->get_id()) {
    case td_api::premiumLimitTypeSupergroupCount::ID:
      return Slice("channels");
    case td_api::premiumLimitTypeSavedAnimationCount::ID:
      return Slice("saved_gifs");
    case td_api::premiumLimitTypeFavoriteStickerCount::ID:
      return Slice("stickers_faved");
    case td_api::premiumLimitTypeChatFolderCount::ID:
      return Slice("dialog_filters");
    case td_api::premiumLimitTypeChatFolderChosenChatCount::ID:
      return Slice("dialog_filters_chats");
    case td_api::premiumLimitTypePinnedChatCount::ID:
      return Slice("dialogs_pinned");
    case td_api::premiumLimitTypePinnedArchivedChatCount::ID:
      return Slice("dialogs_folder_pinned");
    case td_api::premiumLimitTypePinnedSavedMessagesTopicCount::ID:
      return Slice("saved_dialogs_pinned");
    case td_api::premiumLimitTypeCreatedPublicChatCount::ID:
      return Slice("channels_public");
    case td_api::premiumLimitTypeCaptionLength::ID:
      return Slice("caption_length");
    case td_api::premiumLimitTypeBioLength::ID:
      return Slice("about_length");
    case td_api::premiumLimitTypeChatFolderInviteLinkCount::ID:
      return Slice("chatlist_invites");
    case td_api::premiumLimitTypeShareableChatFolderCount::ID:
      return Slice("chatlists_joined");
    case td_api::premiumLimitTypeActiveStoryCount::ID:
      return Slice("story_expiring");
    case td_api::premiumLimitTypeStoryCaptionLength::ID:
      return Slice("story_caption_length");
    case td_api::premiumLimitTypeWeeklySentStoryCount::ID:
      return Slice("stories_sent_weekly");
    case td_api::premiumLimitTypeMonthlySentStoryCount::ID:
      return Slice("stories_sent_monthly");
    case td_api::premiumLimitTypeStorySuggestedReactionAreaCount::ID:
      return Slice("stories_suggested_reactions");
    case td_api::premiumLimitTypeSimilarChatCount::ID:
      return Slice("recommended_channels");
    default:
      UNREACHABLE();
      return Slice();
  }
}

static string get_premium_source(const td_api::PremiumLimitType *limit_type) {
  if (limit_type == nullptr) {
    return string();
  }

  return PSTRING() << "double_limits__" << get_limit_type_key(limit_type);
}

static string get_premium_source(const td_api::PremiumFeature *feature) {
  if (feature == nullptr) {
    return string();
  }

  switch (feature->get_id()) {
    case td_api::premiumFeatureIncreasedLimits::ID:
      return "double_limits";
    case td_api::premiumFeatureIncreasedUploadFileSize::ID:
      return "more_upload";
    case td_api::premiumFeatureImprovedDownloadSpeed::ID:
      return "faster_download";
    case td_api::premiumFeatureVoiceRecognition::ID:
      return "voice_to_text";
    case td_api::premiumFeatureDisabledAds::ID:
      return "no_ads";
    case td_api::premiumFeatureUniqueReactions::ID:
      return "infinite_reactions";
    case td_api::premiumFeatureUniqueStickers::ID:
      return "premium_stickers";
    case td_api::premiumFeatureCustomEmoji::ID:
      return "animated_emoji";
    case td_api::premiumFeatureAdvancedChatManagement::ID:
      return "advanced_chat_management";
    case td_api::premiumFeatureProfileBadge::ID:
      return "profile_badge";
    case td_api::premiumFeatureEmojiStatus::ID:
      return "emoji_status";
    case td_api::premiumFeatureAnimatedProfilePhoto::ID:
      return "animated_userpics";
    case td_api::premiumFeatureForumTopicIcon::ID:
      return "forum_topic_icon";
    case td_api::premiumFeatureAppIcons::ID:
      return "app_icons";
    case td_api::premiumFeatureRealTimeChatTranslation::ID:
      return "translations";
    case td_api::premiumFeatureUpgradedStories::ID:
      return "stories";
    case td_api::premiumFeatureChatBoost::ID:
      return "channel_boost";
    case td_api::premiumFeatureAccentColor::ID:
      return "peer_colors";
    case td_api::premiumFeatureBackgroundForBoth::ID:
      return "wallpapers";
    case td_api::premiumFeatureSavedMessagesTags::ID:
      return "saved_tags";
    case td_api::premiumFeatureMessagePrivacy::ID:
      return "message_privacy";
    case td_api::premiumFeatureLastSeenTimes::ID:
      return "last_seen";
    case td_api::premiumFeatureBusiness::ID:
      return "business";
    case td_api::premiumFeatureMessageEffects::ID:
      return "effects";
    default:
      UNREACHABLE();
  }
  return string();
}

static string get_premium_source(const td_api::BusinessFeature *feature) {
  if (feature == nullptr) {
    return "business";
  }

  switch (feature->get_id()) {
    case td_api::businessFeatureLocation::ID:
      return "business_location";
    case td_api::businessFeatureOpeningHours::ID:
      return "business_hours";
    case td_api::businessFeatureQuickReplies::ID:
      return "quick_replies";
    case td_api::businessFeatureGreetingMessage::ID:
      return "greeting_message";
    case td_api::businessFeatureAwayMessage::ID:
      return "away_message";
    case td_api::businessFeatureAccountLinks::ID:
      return "business_links";
    case td_api::businessFeatureStartPage::ID:
      return "business_intro";
    case td_api::businessFeatureBots::ID:
      return "business_bots";
    case td_api::businessFeatureEmojiStatus::ID:
      return "emoji_status";
    case td_api::businessFeatureChatFolderTags::ID:
      return "folder_tags";
    case td_api::businessFeatureUpgradedStories::ID:
      return "stories";
    default:
      UNREACHABLE();
  }
  return string();
}

static string get_premium_source(const td_api::PremiumStoryFeature *feature) {
  if (feature == nullptr) {
    return string();
  }

  switch (feature->get_id()) {
    case td_api::premiumStoryFeaturePriorityOrder::ID:
      return "stories__priority_order";
    case td_api::premiumStoryFeatureStealthMode::ID:
      return "stories__stealth_mode";
    case td_api::premiumStoryFeaturePermanentViewsHistory::ID:
      return "stories__permanent_views_history";
    case td_api::premiumStoryFeatureCustomExpirationDuration::ID:
      return "stories__expiration_durations";
    case td_api::premiumStoryFeatureSaveStories::ID:
      return "stories__save_stories_to_gallery";
    case td_api::premiumStoryFeatureLinksAndFormatting::ID:
      return "stories__links_and_formatting";
    case td_api::premiumStoryFeatureVideoQuality::ID:
      return "stories__quality";
    default:
      UNREACHABLE();
      return string();
  }
}

static string get_premium_source(const td_api::object_ptr<td_api::PremiumSource> &source) {
  if (source == nullptr) {
    return string();
  }
  switch (source->get_id()) {
    case td_api::premiumSourceLimitExceeded::ID: {
      auto *limit_type = static_cast<const td_api::premiumSourceLimitExceeded *>(source.get())->limit_type_.get();
      return get_premium_source(limit_type);
    }
    case td_api::premiumSourceFeature::ID: {
      auto *feature = static_cast<const td_api::premiumSourceFeature *>(source.get())->feature_.get();
      return get_premium_source(feature);
    }
    case td_api::premiumSourceBusinessFeature::ID: {
      auto *feature = static_cast<const td_api::premiumSourceBusinessFeature *>(source.get())->feature_.get();
      return get_premium_source(feature);
    }
    case td_api::premiumSourceStoryFeature::ID: {
      auto *feature = static_cast<const td_api::premiumSourceStoryFeature *>(source.get())->feature_.get();
      return get_premium_source(feature);
    }
    case td_api::premiumSourceLink::ID: {
      auto &referrer = static_cast<const td_api::premiumSourceLink *>(source.get())->referrer_;
      if (referrer.empty()) {
        return "deeplink";
      }
      return PSTRING() << "deeplink_" << referrer;
    }
    case td_api::premiumSourceSettings::ID:
      return "settings";
    default:
      UNREACHABLE();
      return string();
  }
}

static td_api::object_ptr<td_api::premiumLimit> get_premium_limit_object(Slice key) {
  auto default_limit = static_cast<int32>(G()->get_option_integer(PSLICE() << key << "_limit_default"));
  auto premium_limit = static_cast<int32>(G()->get_option_integer(PSLICE() << key << "_limit_premium"));
  if (default_limit <= 0 || premium_limit <= default_limit) {
    return nullptr;
  }
  auto type = [&]() -> td_api::object_ptr<td_api::PremiumLimitType> {
    if (key == "channels") {
      return td_api::make_object<td_api::premiumLimitTypeSupergroupCount>();
    }
    if (key == "saved_gifs") {
      return td_api::make_object<td_api::premiumLimitTypeSavedAnimationCount>();
    }
    if (key == "stickers_faved") {
      return td_api::make_object<td_api::premiumLimitTypeFavoriteStickerCount>();
    }
    if (key == "dialog_filters") {
      return td_api::make_object<td_api::premiumLimitTypeChatFolderCount>();
    }
    if (key == "dialog_filters_chats") {
      return td_api::make_object<td_api::premiumLimitTypeChatFolderChosenChatCount>();
    }
    if (key == "dialogs_pinned") {
      return td_api::make_object<td_api::premiumLimitTypePinnedChatCount>();
    }
    if (key == "dialogs_folder_pinned") {
      return td_api::make_object<td_api::premiumLimitTypePinnedArchivedChatCount>();
    }
    if (key == "saved_dialogs_pinned") {
      return td_api::make_object<td_api::premiumLimitTypePinnedSavedMessagesTopicCount>();
    }
    if (key == "channels_public") {
      return td_api::make_object<td_api::premiumLimitTypeCreatedPublicChatCount>();
    }
    if (key == "caption_length") {
      return td_api::make_object<td_api::premiumLimitTypeCaptionLength>();
    }
    if (key == "about_length") {
      return td_api::make_object<td_api::premiumLimitTypeBioLength>();
    }
    if (key == "chatlist_invites") {
      return td_api::make_object<td_api::premiumLimitTypeChatFolderInviteLinkCount>();
    }
    if (key == "chatlists_joined") {
      return td_api::make_object<td_api::premiumLimitTypeShareableChatFolderCount>();
    }
    if (key == "story_expiring") {
      return td_api::make_object<td_api::premiumLimitTypeActiveStoryCount>();
    }
    if (key == "story_caption_length") {
      return td_api::make_object<td_api::premiumLimitTypeStoryCaptionLength>();
    }
    if (key == "stories_sent_weekly") {
      return td_api::make_object<td_api::premiumLimitTypeWeeklySentStoryCount>();
    }
    if (key == "stories_sent_monthly") {
      return td_api::make_object<td_api::premiumLimitTypeMonthlySentStoryCount>();
    }
    if (key == "stories_suggested_reactions") {
      return td_api::make_object<td_api::premiumLimitTypeStorySuggestedReactionAreaCount>();
    }
    if (key == "recommended_channels") {
      return td_api::make_object<td_api::premiumLimitTypeSimilarChatCount>();
    }
    UNREACHABLE();
    return nullptr;
  }();
  return td_api::make_object<td_api::premiumLimit>(std::move(type), default_limit, premium_limit);
}

void get_premium_limit(const td_api::object_ptr<td_api::PremiumLimitType> &limit_type,
                       Promise<td_api::object_ptr<td_api::premiumLimit>> &&promise) {
  if (limit_type == nullptr) {
    return promise.set_error(Status::Error(400, "Limit type must be non-empty"));
  }

  promise.set_value(get_premium_limit_object(get_limit_type_key(limit_type.get())));
}

void get_premium_features(Td *td, const td_api::object_ptr<td_api::PremiumSource> &source,
                          Promise<td_api::object_ptr<td_api::premiumFeatures>> &&promise) {
  auto premium_features =
      full_split(G()->get_option_string(
                     "premium_features",
                     "stories,more_upload,double_limits,last_seen,voice_to_text,faster_download,translations,animated_"
                     "emoji,emoji_status,saved_tags,peer_colors,wallpapers,profile_badge,message_privacy,advanced_chat_"
                     "management,no_ads,app_icons,infinite_reactions,animated_userpics,premium_stickers,effects"),
                 ',');
  vector<td_api::object_ptr<td_api::PremiumFeature>> features;
  for (const auto &premium_feature : premium_features) {
    auto feature = get_premium_feature_object(premium_feature);
    if (feature != nullptr) {
      features.push_back(std::move(feature));
    }
  }

  auto limits = transform(get_premium_limit_keys(), get_premium_limit_object);
  td::remove_if(limits, [](auto &limit) { return limit == nullptr; });

  auto source_str = get_premium_source(source);
  if (!source_str.empty()) {
    vector<tl_object_ptr<telegram_api::jsonObjectValue>> data;
    vector<tl_object_ptr<telegram_api::JSONValue>> promo_order;
    for (const auto &premium_feature : premium_features) {
      promo_order.push_back(make_tl_object<telegram_api::jsonString>(premium_feature));
    }
    data.push_back(make_tl_object<telegram_api::jsonObjectValue>(
        "premium_promo_order", make_tl_object<telegram_api::jsonArray>(std::move(promo_order))));
    data.push_back(
        make_tl_object<telegram_api::jsonObjectValue>("source", make_tl_object<telegram_api::jsonString>(source_str)));
    save_app_log(td, "premium.promo_screen_show", DialogId(), make_tl_object<telegram_api::jsonObject>(std::move(data)),
                 Promise<Unit>());
  }

  td_api::object_ptr<td_api::InternalLinkType> payment_link;
  auto premium_bot_username = G()->get_option_string("premium_bot_username");
  if (!premium_bot_username.empty()) {
    payment_link = td_api::make_object<td_api::internalLinkTypeBotStart>(premium_bot_username, source_str, true);
  } else {
    auto premium_invoice_slug = G()->get_option_string("premium_invoice_slug");
    if (!premium_invoice_slug.empty()) {
      payment_link = td_api::make_object<td_api::internalLinkTypeInvoice>(premium_invoice_slug);
    }
  }

  promise.set_value(
      td_api::make_object<td_api::premiumFeatures>(std::move(features), std::move(limits), std::move(payment_link)));
}

void get_business_features(Td *td, const td_api::object_ptr<td_api::BusinessFeature> &source,
                           Promise<td_api::object_ptr<td_api::businessFeatures>> &&promise) {
  auto business_features =
      full_split(G()->get_option_string("business_features",
                                        "business_location,business_hours,quick_replies,greeting_message,away_message,"
                                        "business_links,business_intro,business_bots,emoji_status,folder_tags,stories"),
                 ',');
  vector<td_api::object_ptr<td_api::BusinessFeature>> features;
  for (const auto &business_feature : business_features) {
    auto feature = get_business_feature_object(business_feature);
    if (feature != nullptr) {
      features.push_back(std::move(feature));
    }
  }

  auto source_str = get_premium_source(source.get());
  if (!source_str.empty()) {
    vector<telegram_api::object_ptr<telegram_api::jsonObjectValue>> data;
    vector<telegram_api::object_ptr<telegram_api::JSONValue>> promo_order;
    for (const auto &business_feature : business_features) {
      promo_order.push_back(telegram_api::make_object<telegram_api::jsonString>(business_feature));
    }
    data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
        "business_promo_order", telegram_api::make_object<telegram_api::jsonArray>(std::move(promo_order))));
    data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
        "source", telegram_api::make_object<telegram_api::jsonString>(source_str)));
    save_app_log(td, "business.promo_screen_show", DialogId(),
                 telegram_api::make_object<telegram_api::jsonObject>(std::move(data)), Promise<Unit>());
  }

  promise.set_value(td_api::make_object<td_api::businessFeatures>(std::move(features)));
}

void view_premium_feature(Td *td, const td_api::object_ptr<td_api::PremiumFeature> &feature, Promise<Unit> &&promise) {
  auto source = get_premium_source(feature.get());
  if (source.empty()) {
    return promise.set_error(Status::Error(400, "Feature must be non-empty"));
  }

  vector<tl_object_ptr<telegram_api::jsonObjectValue>> data;
  data.push_back(
      make_tl_object<telegram_api::jsonObjectValue>("item", make_tl_object<telegram_api::jsonString>(source)));
  save_app_log(td, "premium.promo_screen_tap", DialogId(), make_tl_object<telegram_api::jsonObject>(std::move(data)),
               std::move(promise));
}

void click_premium_subscription_button(Td *td, Promise<Unit> &&promise) {
  vector<tl_object_ptr<telegram_api::jsonObjectValue>> data;
  save_app_log(td, "premium.promo_screen_accept", DialogId(), make_tl_object<telegram_api::jsonObject>(std::move(data)),
               std::move(promise));
}

void get_premium_state(Td *td, Promise<td_api::object_ptr<td_api::premiumState>> &&promise) {
  td->create_handler<GetPremiumPromoQuery>(std::move(promise))->send();
}

void get_premium_gift_payment_options(Td *td,
                                      Promise<td_api::object_ptr<td_api::premiumGiftPaymentOptions>> &&promise) {
  td->stickers_manager_->load_premium_gift_sticker_set(
      PromiseCreator::lambda([td, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          TRY_STATUS_PROMISE(promise, G()->close_status());
          td->create_handler<GetPremiumGiftOptionsQuery>(std::move(promise))->send();
        }
      }));
}

void get_premium_giveaway_options(Td *td, DialogId boosted_dialog_id,
                                  Promise<td_api::object_ptr<td_api::premiumGiveawayPaymentOptions>> &&promise) {
  td->create_handler<GetPremiumGiveawayOptionsQuery>(std::move(promise))->send(boosted_dialog_id);
}

void check_premium_gift_code(Td *td, const string &code,
                             Promise<td_api::object_ptr<td_api::premiumGiftCodeInfo>> &&promise) {
  td->create_handler<CheckGiftCodeQuery>(std::move(promise))->send(code);
}

void apply_premium_gift_code(Td *td, const string &code, Promise<Unit> &&promise) {
  td->create_handler<ApplyGiftCodeQuery>(std::move(promise))->send(code);
}

void launch_prepaid_premium_giveaway(Td *td, int64 giveaway_id,
                                     td_api::object_ptr<td_api::giveawayParameters> &&parameters, int32 user_count,
                                     int64 star_count, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, giveaway_parameters, GiveawayParameters::get_giveaway_parameters(td, parameters.get()));
  td->create_handler<LaunchPrepaidGiveawayQuery>(std::move(promise))
      ->send(giveaway_id, giveaway_parameters, user_count, star_count);
}

void get_premium_giveaway_info(Td *td, MessageFullId message_full_id,
                               Promise<td_api::object_ptr<td_api::GiveawayInfo>> &&promise) {
  TRY_RESULT_PROMISE(promise, server_message_id, td->messages_manager_->get_giveaway_message_id(message_full_id));
  td->create_handler<GetGiveawayInfoQuery>(std::move(promise))
      ->send(message_full_id.get_dialog_id(), server_message_id);
}

void can_purchase_premium(Td *td, td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose, Promise<Unit> &&promise) {
  td->create_handler<CanPurchasePremiumQuery>(std::move(promise))->send(std::move(purpose));
}

void assign_app_store_transaction(Td *td, const string &receipt,
                                  td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose, Promise<Unit> &&promise) {
  if (purpose != nullptr && purpose->get_id() == td_api::storePaymentPurposePremiumSubscription::ID) {
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::UpgradePremium}, Promise<Unit>());
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::SubscribeToAnnualPremium}, Promise<Unit>());
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::RestorePremium}, Promise<Unit>());
  }
  td->create_handler<AssignAppStoreTransactionQuery>(std::move(promise))->send(receipt, std::move(purpose));
}

void assign_play_market_transaction(Td *td, const string &package_name, const string &store_product_id,
                                    const string &purchase_token,
                                    td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose,
                                    Promise<Unit> &&promise) {
  if (purpose != nullptr && purpose->get_id() == td_api::storePaymentPurposePremiumSubscription::ID) {
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::UpgradePremium}, Promise<Unit>());
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::SubscribeToAnnualPremium}, Promise<Unit>());
    dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::RestorePremium}, Promise<Unit>());
  }
  td->create_handler<AssignPlayMarketTransactionQuery>(std::move(promise))
      ->send(package_name, store_product_id, purchase_token, std::move(purpose));
}

}  // namespace td
