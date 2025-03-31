//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageContent.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AnimationsManager.hpp"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/AudiosManager.hpp"
#include "td/telegram/AuthManager.h"
#include "td/telegram/BackgroundInfo.hpp"
#include "td/telegram/CallDiscardReason.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Contact.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/Dimensions.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/DocumentsManager.hpp"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileId.hpp"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/ForumTopicEditedData.h"
#include "td/telegram/ForumTopicEditedData.hpp"
#include "td/telegram/ForumTopicIcon.h"
#include "td/telegram/ForumTopicIcon.hpp"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/Game.h"
#include "td/telegram/Game.hpp"
#include "td/telegram/GiveawayParameters.h"
#include "td/telegram/GiveawayParameters.hpp"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/HashtagHints.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/InputInvoice.h"
#include "td/telegram/InputInvoice.hpp"
#include "td/telegram/InputMessageText.h"
#include "td/telegram/Location.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageEntity.hpp"
#include "td/telegram/MessageExtendedMedia.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSearchFilter.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/OrderInfo.h"
#include "td/telegram/OrderInfo.hpp"
#include "td/telegram/Photo.h"
#include "td/telegram/Photo.hpp"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/PollId.h"
#include "td/telegram/PollId.hpp"
#include "td/telegram/PollManager.h"
#include "td/telegram/RepliedMessageInfo.h"
#include "td/telegram/secret_api.hpp"
#include "td/telegram/SecureValue.h"
#include "td/telegram/SecureValue.hpp"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/SharedDialog.h"
#include "td/telegram/SharedDialog.hpp"
#include "td/telegram/StarGift.h"
#include "td/telegram/StarGift.hpp"
#include "td/telegram/StarGiftId.h"
#include "td/telegram/StarGiftManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/StickerType.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TopDialogManager.h"
#include "td/telegram/TranscriptionManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Venue.h"
#include "td/telegram/Version.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VideoNotesManager.hpp"
#include "td/telegram/VideosManager.h"
#include "td/telegram/VideosManager.hpp"
#include "td/telegram/VoiceNotesManager.h"
#include "td/telegram/VoiceNotesManager.hpp"
#include "td/telegram/WebApp.h"
#include "td/telegram/WebApp.hpp"
#include "td/telegram/WebPageId.h"
#include "td/telegram/WebPagesManager.h"

#include "td/actor/actor.h"
#include "td/actor/MultiPromise.h"

#include "td/utils/algorithm.h"
#include "td/utils/emoji.h"
#include "td/utils/HttpUrl.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

#include <limits>
#include <unordered_set>
#include <utility>

namespace td {

class MessageText final : public MessageContent {
 public:
  FormattedText text;
  WebPageId web_page_id;
  bool force_small_media = false;
  bool force_large_media = false;
  bool skip_web_page_confirmation = false;
  string web_page_url;

  MessageText() = default;
  MessageText(FormattedText text, WebPageId web_page_id, bool force_small_media, bool force_large_media,
              bool skip_web_page_confirmation, string web_page_url)
      : text(std::move(text))
      , web_page_id(web_page_id)
      , force_small_media(force_small_media)
      , force_large_media(force_large_media)
      , skip_web_page_confirmation(skip_web_page_confirmation)
      , web_page_url(std::move(web_page_url)) {
    if (this->web_page_url.empty()) {
      this->force_small_media = false;
      this->force_large_media = false;
    } else if (this->force_large_media) {
      this->force_small_media = false;
    }
  }

  MessageContentType get_type() const final {
    return MessageContentType::Text;
  }
};

class MessageAnimation final : public MessageContent {
 public:
  FileId file_id;

  FormattedText caption;
  bool has_spoiler = false;

  MessageAnimation() = default;
  MessageAnimation(FileId file_id, FormattedText &&caption, bool has_spoiler)
      : file_id(file_id), caption(std::move(caption)), has_spoiler(has_spoiler) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Animation;
  }
};

class MessageAudio final : public MessageContent {
 public:
  FileId file_id;

  FormattedText caption;

  MessageAudio() = default;
  MessageAudio(FileId file_id, FormattedText &&caption) : file_id(file_id), caption(std::move(caption)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Audio;
  }
};

class MessageDocument final : public MessageContent {
 public:
  FileId file_id;

  FormattedText caption;

  MessageDocument() = default;
  MessageDocument(FileId file_id, FormattedText &&caption) : file_id(file_id), caption(std::move(caption)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Document;
  }
};

class MessagePhoto final : public MessageContent {
 public:
  Photo photo;

  FormattedText caption;
  bool has_spoiler = false;

  MessagePhoto() = default;
  MessagePhoto(Photo &&photo, FormattedText &&caption, bool has_spoiler)
      : photo(std::move(photo)), caption(std::move(caption)), has_spoiler(has_spoiler) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Photo;
  }
};

class MessageSticker final : public MessageContent {
 public:
  FileId file_id;
  bool is_premium = false;

  MessageSticker() = default;
  MessageSticker(FileId file_id, bool is_premium) : file_id(file_id), is_premium(is_premium) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Sticker;
  }
};

class MessageVideo final : public MessageContent {
 public:
  FileId file_id;
  vector<FileId> alternative_file_ids;
  vector<FileId> hls_file_ids;
  Photo cover;
  int32 start_timestamp = 0;

  FormattedText caption;
  bool has_spoiler = false;

  MessageVideo() = default;
  MessageVideo(FileId file_id, vector<FileId> &&alternative_file_ids, vector<FileId> &&hls_file_ids, Photo &&cover,
               int32 start_timestamp, FormattedText &&caption, bool has_spoiler)
      : file_id(file_id)
      , alternative_file_ids(std::move(alternative_file_ids))
      , hls_file_ids(std::move(hls_file_ids))
      , cover(std::move(cover))
      , start_timestamp(start_timestamp)
      , caption(std::move(caption))
      , has_spoiler(has_spoiler) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Video;
  }
};

class MessageVoiceNote final : public MessageContent {
 public:
  FileId file_id;

  FormattedText caption;
  bool is_listened = false;

  MessageVoiceNote() = default;
  MessageVoiceNote(FileId file_id, FormattedText &&caption, bool is_listened)
      : file_id(file_id), caption(std::move(caption)), is_listened(is_listened) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::VoiceNote;
  }
};

class MessageContact final : public MessageContent {
 public:
  Contact contact;

  MessageContact() = default;
  explicit MessageContact(Contact &&contact) : contact(std::move(contact)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Contact;
  }
};

class MessageLocation final : public MessageContent {
 public:
  Location location;

  MessageLocation() = default;
  explicit MessageLocation(Location &&location) : location(std::move(location)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Location;
  }
};

class MessageVenue final : public MessageContent {
 public:
  Venue venue;

  MessageVenue() = default;
  explicit MessageVenue(Venue &&venue) : venue(std::move(venue)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Venue;
  }
};

class MessageChatCreate final : public MessageContent {
 public:
  string title;
  vector<UserId> participant_user_ids;

  MessageChatCreate() = default;
  MessageChatCreate(string &&title, vector<UserId> &&participant_user_ids)
      : title(std::move(title)), participant_user_ids(std::move(participant_user_ids)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatCreate;
  }
};

class MessageChatChangeTitle final : public MessageContent {
 public:
  string title;

  MessageChatChangeTitle() = default;
  explicit MessageChatChangeTitle(string &&title) : title(std::move(title)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatChangeTitle;
  }
};

class MessageChatChangePhoto final : public MessageContent {
 public:
  Photo photo;

  MessageChatChangePhoto() = default;
  explicit MessageChatChangePhoto(Photo &&photo) : photo(std::move(photo)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatChangePhoto;
  }
};

class MessageChatDeletePhoto final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::ChatDeletePhoto;
  }
};

class MessageChatDeleteHistory final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::ChatDeleteHistory;
  }
};

class MessageChatAddUsers final : public MessageContent {
 public:
  vector<UserId> user_ids;

  MessageChatAddUsers() = default;
  explicit MessageChatAddUsers(vector<UserId> &&user_ids) : user_ids(std::move(user_ids)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatAddUsers;
  }
};

class MessageChatJoinedByLink final : public MessageContent {
 public:
  bool is_approved = false;

  MessageChatJoinedByLink() = default;
  explicit MessageChatJoinedByLink(bool is_approved) : is_approved(is_approved) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatJoinedByLink;
  }
};

class MessageChatDeleteUser final : public MessageContent {
 public:
  UserId user_id;

  MessageChatDeleteUser() = default;
  explicit MessageChatDeleteUser(UserId user_id) : user_id(user_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatDeleteUser;
  }
};

class MessageChatMigrateTo final : public MessageContent {
 public:
  ChannelId migrated_to_channel_id;

  MessageChatMigrateTo() = default;
  explicit MessageChatMigrateTo(ChannelId migrated_to_channel_id) : migrated_to_channel_id(migrated_to_channel_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatMigrateTo;
  }
};

class MessageChannelCreate final : public MessageContent {
 public:
  string title;

  MessageChannelCreate() = default;
  explicit MessageChannelCreate(string &&title) : title(std::move(title)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChannelCreate;
  }
};

class MessageChannelMigrateFrom final : public MessageContent {
 public:
  string title;
  ChatId migrated_from_chat_id;

  MessageChannelMigrateFrom() = default;
  MessageChannelMigrateFrom(string &&title, ChatId migrated_from_chat_id)
      : title(std::move(title)), migrated_from_chat_id(migrated_from_chat_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChannelMigrateFrom;
  }
};

class MessagePinMessage final : public MessageContent {
 public:
  MessageId message_id;

  MessagePinMessage() = default;
  explicit MessagePinMessage(MessageId message_id) : message_id(message_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PinMessage;
  }
};

class MessageGame final : public MessageContent {
 public:
  Game game;

  MessageGame() = default;
  explicit MessageGame(Game &&game) : game(std::move(game)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Game;
  }
};

class MessageGameScore final : public MessageContent {
 public:
  MessageId game_message_id;
  int64 game_id = 0;
  int32 score = 0;

  MessageGameScore() = default;
  MessageGameScore(MessageId game_message_id, int64 game_id, int32 score)
      : game_message_id(game_message_id), game_id(game_id), score(score) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GameScore;
  }
};

class MessageScreenshotTaken final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::ScreenshotTaken;
  }
};

class MessageChatSetTtl final : public MessageContent {
 public:
  int32 ttl = 0;
  UserId from_user_id;

  MessageChatSetTtl() = default;
  MessageChatSetTtl(int32 ttl, UserId from_user_id) : ttl(ttl), from_user_id(from_user_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatSetTtl;
  }
};

class MessageUnsupported final : public MessageContent {
 public:
  static constexpr int32 CURRENT_VERSION = 39;
  int32 version = CURRENT_VERSION;

  MessageUnsupported() = default;
  explicit MessageUnsupported(int32 version) : version(version) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Unsupported;
  }
};

class MessageCall final : public MessageContent {
 public:
  int64 call_id = 0;
  int32 duration = 0;
  CallDiscardReason discard_reason;
  bool is_video = false;

  MessageCall() = default;
  MessageCall(int64 call_id, int32 duration, CallDiscardReason discard_reason, bool is_video)
      : call_id(call_id), duration(duration), discard_reason(discard_reason), is_video(is_video) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Call;
  }
};

class MessageInvoice final : public MessageContent {
 public:
  InputInvoice input_invoice;

  MessageInvoice() = default;
  explicit MessageInvoice(InputInvoice &&input_invoice) : input_invoice(std::move(input_invoice)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Invoice;
  }
};

class MessagePaymentSuccessful final : public MessageContent {
 public:
  DialogId invoice_dialog_id;
  MessageId invoice_message_id;
  string currency;
  int64 total_amount = 0;
  string invoice_payload;  // or invoice_slug for users
  int32 subscription_until_date = false;
  bool is_recurring = false;
  bool is_first_recurring = false;

  // bots only part
  string shipping_option_id;
  unique_ptr<OrderInfo> order_info;
  string telegram_payment_charge_id;
  string provider_payment_charge_id;

  MessagePaymentSuccessful() = default;
  MessagePaymentSuccessful(DialogId invoice_dialog_id, MessageId invoice_message_id, string &&currency,
                           int64 total_amount, string &&invoice_payload, int32 subscription_until_date,
                           bool is_recurring, bool is_first_recurring)
      : invoice_dialog_id(invoice_dialog_id)
      , invoice_message_id(invoice_message_id)
      , currency(std::move(currency))
      , total_amount(total_amount)
      , invoice_payload(std::move(invoice_payload))
      , subscription_until_date(subscription_until_date)
      , is_recurring(is_recurring || is_first_recurring)
      , is_first_recurring(is_first_recurring) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PaymentSuccessful;
  }
};

class MessageVideoNote final : public MessageContent {
 public:
  FileId file_id;

  bool is_viewed = false;

  MessageVideoNote() = default;
  MessageVideoNote(FileId file_id, bool is_viewed) : file_id(file_id), is_viewed(is_viewed) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::VideoNote;
  }
};

class MessageContactRegistered final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::ContactRegistered;
  }
};

class MessageExpiredPhoto final : public MessageContent {
 public:
  MessageExpiredPhoto() = default;

  MessageContentType get_type() const final {
    return MessageContentType::ExpiredPhoto;
  }
};

class MessageExpiredVideo final : public MessageContent {
 public:
  MessageExpiredVideo() = default;

  MessageContentType get_type() const final {
    return MessageContentType::ExpiredVideo;
  }
};

class MessageLiveLocation final : public MessageContent {
 public:
  Location location;
  int32 period = 0;
  int32 heading = 0;
  int32 proximity_alert_radius = 0;

  MessageLiveLocation() = default;
  MessageLiveLocation(Location &&location, int32 period, int32 heading, int32 proximity_alert_radius)
      : location(std::move(location))
      , period(period)
      , heading(heading)
      , proximity_alert_radius(proximity_alert_radius) {
    if (period < 0) {
      this->period = 0;
    }
    if (heading < 0 || heading > 360) {
      LOG(ERROR) << "Receive wrong heading " << heading;
      this->heading = 0;
    }
    if (proximity_alert_radius < 0) {
      this->proximity_alert_radius = 0;
    }
  }

  MessageContentType get_type() const final {
    return MessageContentType::LiveLocation;
  }
};

class MessageCustomServiceAction final : public MessageContent {
 public:
  string message;

  MessageCustomServiceAction() = default;
  explicit MessageCustomServiceAction(string &&message) : message(std::move(message)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::CustomServiceAction;
  }
};

class MessageWebsiteConnected final : public MessageContent {
 public:
  string domain_name;

  MessageWebsiteConnected() = default;
  explicit MessageWebsiteConnected(string &&domain_name) : domain_name(std::move(domain_name)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::WebsiteConnected;
  }
};

class MessagePassportDataSent final : public MessageContent {
 public:
  vector<SecureValueType> types;

  MessagePassportDataSent() = default;
  explicit MessagePassportDataSent(vector<SecureValueType> &&types) : types(std::move(types)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PassportDataSent;
  }
};

class MessagePassportDataReceived final : public MessageContent {
 public:
  vector<EncryptedSecureValue> values;
  EncryptedSecureCredentials credentials;

  MessagePassportDataReceived() = default;
  MessagePassportDataReceived(vector<EncryptedSecureValue> &&values, EncryptedSecureCredentials &&credentials)
      : values(std::move(values)), credentials(std::move(credentials)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PassportDataReceived;
  }
};

class MessagePoll final : public MessageContent {
 public:
  PollId poll_id;

  MessagePoll() = default;
  explicit MessagePoll(PollId poll_id) : poll_id(poll_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Poll;
  }
};

class MessageDice final : public MessageContent {
 public:
  string emoji;
  int32 dice_value = 0;

  static constexpr const char *DEFAULT_EMOJI = "🎲";

  MessageDice() = default;
  MessageDice(const string &emoji, int32 dice_value)
      : emoji(emoji.empty() ? string(DEFAULT_EMOJI) : remove_emoji_modifiers(emoji)), dice_value(dice_value) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Dice;
  }

  bool is_valid() const {
    if (dice_value < 0) {
      return false;
    }
    if (emoji == DEFAULT_EMOJI || emoji == "🎯") {
      return dice_value <= 6;
    }
    return dice_value <= 1000;
  }
};

class MessageProximityAlertTriggered final : public MessageContent {
 public:
  DialogId traveler_dialog_id;
  DialogId watcher_dialog_id;
  int32 distance = 0;

  MessageProximityAlertTriggered() = default;
  MessageProximityAlertTriggered(DialogId traveler_dialog_id, DialogId watcher_dialog_id, int32 distance)
      : traveler_dialog_id(traveler_dialog_id), watcher_dialog_id(watcher_dialog_id), distance(distance) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ProximityAlertTriggered;
  }
};

class MessageGroupCall final : public MessageContent {
 public:
  InputGroupCallId input_group_call_id;
  int32 duration = -1;
  int32 schedule_date = -1;

  MessageGroupCall() = default;
  MessageGroupCall(InputGroupCallId input_group_call_id, int32 duration, int32 schedule_date)
      : input_group_call_id(input_group_call_id), duration(duration), schedule_date(schedule_date) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GroupCall;
  }
};

class MessageInviteToGroupCall final : public MessageContent {
 public:
  InputGroupCallId input_group_call_id;
  vector<UserId> user_ids;

  MessageInviteToGroupCall() = default;
  MessageInviteToGroupCall(InputGroupCallId input_group_call_id, vector<UserId> &&user_ids)
      : input_group_call_id(input_group_call_id), user_ids(std::move(user_ids)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::InviteToGroupCall;
  }
};

class MessageChatSetTheme final : public MessageContent {
 public:
  string emoji;

  MessageChatSetTheme() = default;
  explicit MessageChatSetTheme(string &&emoji) : emoji(std::move(emoji)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::ChatSetTheme;
  }
};

class MessageWebViewDataSent final : public MessageContent {
 public:
  string button_text;

  MessageWebViewDataSent() = default;
  explicit MessageWebViewDataSent(string &&button_text) : button_text(std::move(button_text)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::WebViewDataSent;
  }
};

class MessageWebViewDataReceived final : public MessageContent {
 public:
  string button_text;
  string data;

  MessageWebViewDataReceived() = default;
  MessageWebViewDataReceived(string &&button_text, string &&data)
      : button_text(std::move(button_text)), data(std::move(data)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::WebViewDataReceived;
  }
};

class MessageGiftPremium final : public MessageContent {
 public:
  FormattedText text;
  string currency;
  int64 amount = 0;
  string crypto_currency;
  int64 crypto_amount = 0;
  int32 months = 0;

  MessageGiftPremium() = default;
  MessageGiftPremium(FormattedText &&text, string &&currency, int64 amount, string &&crypto_currency,
                     int64 crypto_amount, int32 months)
      : text(std::move(text))
      , currency(std::move(currency))
      , amount(amount)
      , crypto_currency(std::move(crypto_currency))
      , crypto_amount(crypto_amount)
      , months(months) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiftPremium;
  }
};

class MessageTopicCreate final : public MessageContent {
 public:
  string title;
  ForumTopicIcon icon;

  MessageTopicCreate() = default;
  MessageTopicCreate(string &&title, ForumTopicIcon &&icon) : title(std::move(title)), icon(std::move(icon)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::TopicCreate;
  }
};

class MessageTopicEdit final : public MessageContent {
 public:
  ForumTopicEditedData edited_data;

  MessageTopicEdit() = default;
  explicit MessageTopicEdit(ForumTopicEditedData &&edited_data) : edited_data(std::move(edited_data)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::TopicEdit;
  }
};

class MessageSuggestProfilePhoto final : public MessageContent {
 public:
  Photo photo;

  MessageSuggestProfilePhoto() = default;
  explicit MessageSuggestProfilePhoto(Photo &&photo) : photo(std::move(photo)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::SuggestProfilePhoto;
  }
};

class MessageWriteAccessAllowed final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::WriteAccessAllowed;
  }
};

class MessageRequestedDialog final : public MessageContent {
 public:
  vector<DialogId> shared_dialog_ids;
  int32 button_id = 0;

  MessageRequestedDialog() = default;
  MessageRequestedDialog(vector<DialogId> &&shared_dialog_ids, int32 button_id)
      : shared_dialog_ids(std::move(shared_dialog_ids)), button_id(button_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::RequestedDialog;
  }
};

class MessageWebViewWriteAccessAllowed final : public MessageContent {
 public:
  WebApp web_app;

  MessageWebViewWriteAccessAllowed() = default;
  explicit MessageWebViewWriteAccessAllowed(WebApp &&web_app) : web_app(std::move(web_app)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::WebViewWriteAccessAllowed;
  }
};

class MessageSetBackground final : public MessageContent {
 public:
  MessageId old_message_id;
  BackgroundInfo background_info;
  bool for_both = false;

  MessageSetBackground() = default;
  MessageSetBackground(MessageId old_message_id, BackgroundInfo background_info, bool for_both)
      : old_message_id(old_message_id), background_info(std::move(background_info)), for_both(for_both) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::SetBackground;
  }
};

class MessageStory final : public MessageContent {
 public:
  StoryFullId story_full_id;
  bool via_mention = false;

  MessageStory() = default;
  MessageStory(StoryFullId story_full_id, bool via_mention) : story_full_id(story_full_id), via_mention(via_mention) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Story;
  }
};

class MessageWriteAccessAllowedByRequest final : public MessageContent {
 public:
  MessageContentType get_type() const final {
    return MessageContentType::WriteAccessAllowedByRequest;
  }
};

class MessageGiftCode final : public MessageContent {
 public:
  DialogId creator_dialog_id;
  FormattedText text;
  int32 months = 0;
  string currency;
  int64 amount = 0;
  string crypto_currency;
  int64 crypto_amount = 0;
  bool via_giveaway = false;
  bool is_unclaimed = false;
  string code;

  MessageGiftCode() = default;
  MessageGiftCode(DialogId creator_dialog_id, FormattedText &&text, int32 months, string &&currency, int64 amount,
                  string &&crypto_currency, int64 crypto_amount, bool via_giveaway, bool is_unclaimed, string &&code)
      : creator_dialog_id(creator_dialog_id)
      , text(std::move(text))
      , months(months)
      , currency(std::move(currency))
      , amount(amount)
      , crypto_currency(std::move(crypto_currency))
      , crypto_amount(crypto_amount)
      , via_giveaway(via_giveaway || is_unclaimed)
      , is_unclaimed(is_unclaimed)
      , code(std::move(code)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiftCode;
  }
};

class MessageGiveaway final : public MessageContent {
 public:
  GiveawayParameters giveaway_parameters;
  int32 quantity = 0;
  int32 months = 0;
  int64 star_count = 0;

  MessageGiveaway() = default;
  MessageGiveaway(GiveawayParameters giveaway_parameters, int32 quantity, int32 months, int64 star_count)
      : giveaway_parameters(std::move(giveaway_parameters))
      , quantity(quantity)
      , months(months)
      , star_count(star_count) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::Giveaway;
  }
};

class MessageGiveawayLaunch final : public MessageContent {
 public:
  int64 star_count = 0;

  MessageGiveawayLaunch() = default;
  explicit MessageGiveawayLaunch(int64 star_count) : star_count(star_count) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiveawayLaunch;
  }
};

class MessageGiveawayResults final : public MessageContent {
 public:
  MessageId giveaway_message_id;
  int32 winner_count = 0;
  int32 unclaimed_count = 0;
  bool is_star_giveaway = false;

  MessageGiveawayResults() = default;
  MessageGiveawayResults(MessageId giveaway_message_id, int32 winner_count, int32 unclaimed_count,
                         bool is_star_giveaway)
      : giveaway_message_id(giveaway_message_id)
      , winner_count(winner_count)
      , unclaimed_count(unclaimed_count)
      , is_star_giveaway(is_star_giveaway) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiveawayResults;
  }
};

class MessageGiveawayWinners final : public MessageContent {
 public:
  MessageId giveaway_message_id;
  ChannelId boosted_channel_id;
  int32 additional_dialog_count = 0;
  int32 month_count = 0;
  int64 star_count = 0;
  string prize_description;
  int32 winners_selection_date = 0;
  bool only_new_subscribers = false;
  bool was_refunded = false;
  int32 winner_count = 0;
  int32 unclaimed_count = 0;
  vector<UserId> winner_user_ids;

  MessageGiveawayWinners() = default;
  MessageGiveawayWinners(MessageId giveaway_message_id, ChannelId boosted_channel_id, int32 additional_dialog_count,
                         int32 month_count, int64 star_count, string &&prize_description, int32 winners_selection_date,
                         bool only_new_subscribers, bool was_refunded, int32 winner_count, int32 unclaimed_count,
                         vector<UserId> &&winner_user_ids)
      : giveaway_message_id(giveaway_message_id)
      , boosted_channel_id(boosted_channel_id)
      , additional_dialog_count(additional_dialog_count)
      , month_count(month_count)
      , star_count(star_count)
      , prize_description(std::move(prize_description))
      , winners_selection_date(winners_selection_date)
      , only_new_subscribers(only_new_subscribers)
      , was_refunded(was_refunded)
      , winner_count(winner_count)
      , unclaimed_count(unclaimed_count)
      , winner_user_ids(std::move(winner_user_ids)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiveawayWinners;
  }
};

class MessageExpiredVideoNote final : public MessageContent {
 public:
  MessageExpiredVideoNote() = default;

  MessageContentType get_type() const final {
    return MessageContentType::ExpiredVideoNote;
  }
};

class MessageExpiredVoiceNote final : public MessageContent {
 public:
  MessageExpiredVoiceNote() = default;

  MessageContentType get_type() const final {
    return MessageContentType::ExpiredVoiceNote;
  }
};

class MessageBoostApply final : public MessageContent {
 public:
  int32 boost_count = 0;

  MessageBoostApply() = default;
  explicit MessageBoostApply(int32 boost_count) : boost_count(boost_count) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::BoostApply;
  }
};

class MessageDialogShared final : public MessageContent {
 public:
  vector<SharedDialog> shared_dialogs;
  int32 button_id = 0;

  MessageDialogShared() = default;
  MessageDialogShared(vector<SharedDialog> &&shared_dialogs, int32 button_id)
      : shared_dialogs(std::move(shared_dialogs)), button_id(button_id) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::DialogShared;
  }
};

class MessagePaidMedia final : public MessageContent {
 public:
  vector<MessageExtendedMedia> media;
  FormattedText caption;
  int64 star_count = 0;
  string payload;

  MessagePaidMedia() = default;
  MessagePaidMedia(vector<MessageExtendedMedia> &&media, FormattedText &&caption, int64 star_count, string payload)
      : media(std::move(media)), caption(std::move(caption)), star_count(star_count), payload(std::move(payload)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PaidMedia;
  }
};

class MessagePaymentRefunded final : public MessageContent {
 public:
  DialogId dialog_id;
  string currency;
  int64 total_amount = 0;
  string invoice_payload;
  string telegram_payment_charge_id;
  string provider_payment_charge_id;

  MessagePaymentRefunded() = default;
  MessagePaymentRefunded(DialogId dialog_id, string currency, int64 total_amount, string invoice_payload,
                         string telegram_payment_charge_id, string provider_payment_charge_id)
      : dialog_id(dialog_id)
      , currency(std::move(currency))
      , total_amount(total_amount)
      , invoice_payload(std::move(invoice_payload))
      , telegram_payment_charge_id(std::move(telegram_payment_charge_id))
      , provider_payment_charge_id(std::move(provider_payment_charge_id)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PaymentRefunded;
  }
};

class MessageGiftStars final : public MessageContent {
 public:
  string currency;
  int64 amount = 0;
  string crypto_currency;
  int64 crypto_amount = 0;
  int64 star_count = 0;
  string transaction_id;

  MessageGiftStars() = default;
  MessageGiftStars(string &&currency, int64 amount, string &&crypto_currency, int64 crypto_amount, int64 star_count,
                   string &&transaction_id)
      : currency(std::move(currency))
      , amount(amount)
      , crypto_currency(std::move(crypto_currency))
      , crypto_amount(crypto_amount)
      , star_count(star_count)
      , transaction_id(std::move(transaction_id)) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::GiftStars;
  }
};

class MessagePrizeStars final : public MessageContent {
 public:
  int64 star_count = 0;
  string transaction_id;
  DialogId boosted_dialog_id;
  MessageId giveaway_message_id;
  bool is_unclaimed = false;

  MessagePrizeStars() = default;
  MessagePrizeStars(int64 star_count, string &&transaction_id, DialogId boosted_dialog_id,
                    MessageId giveaway_message_id, bool is_unclaimed)
      : star_count(star_count)
      , transaction_id(std::move(transaction_id))
      , boosted_dialog_id(boosted_dialog_id)
      , giveaway_message_id(giveaway_message_id)
      , is_unclaimed(is_unclaimed) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::PrizeStars;
  }
};

class MessageStarGift final : public MessageContent {
 public:
  StarGift star_gift;
  DialogId sender_dialog_id;
  DialogId owner_dialog_id;
  int64 saved_id = 0;
  FormattedText text;
  int64 convert_star_count = 0;
  int64 upgrade_star_count = 0;
  MessageId upgrade_message_id;
  bool name_hidden = false;
  bool is_saved = false;
  bool can_upgrade = false;
  bool was_converted = false;
  bool was_upgraded = false;
  bool was_refunded = false;

  MessageStarGift() = default;
  MessageStarGift(StarGift &&star_gift, DialogId sender_dialog_id, DialogId owner_dialog_id, int64 saved_id,
                  FormattedText &&text, int64 convert_star_count, int64 upgrade_star_count,
                  MessageId upgrade_message_id, bool name_hidden, bool is_saved, bool can_upgrade, bool was_converted,
                  bool was_upgraded, bool was_refunded)
      : star_gift(std::move(star_gift))
      , sender_dialog_id(sender_dialog_id)
      , owner_dialog_id(owner_dialog_id)
      , saved_id(saved_id)
      , text(std::move(text))
      , convert_star_count(convert_star_count)
      , upgrade_star_count(upgrade_star_count)
      , upgrade_message_id(upgrade_message_id)
      , name_hidden(name_hidden)
      , is_saved(is_saved)
      , can_upgrade(can_upgrade)
      , was_converted(was_converted)
      , was_upgraded(was_upgraded)
      , was_refunded(was_refunded) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::StarGift;
  }
};

class MessageStarGiftUnique final : public MessageContent {
 public:
  StarGift star_gift;
  DialogId sender_dialog_id;
  DialogId owner_dialog_id;
  int64 saved_id = 0;
  int64 transfer_star_count = 0;
  int32 can_export_at = 0;
  bool is_saved = false;
  bool is_upgrade = false;
  bool can_transfer = false;
  bool was_transferred = false;
  bool was_refunded = false;

  MessageStarGiftUnique() = default;
  MessageStarGiftUnique(StarGift &&star_gift, DialogId sender_dialog_id, DialogId owner_dialog_id, int64 saved_id,
                        int64 transfer_star_count, int32 can_export_at, bool is_saved, bool is_upgrade,
                        bool can_transfer, bool was_transferred, bool was_refunded)
      : star_gift(std::move(star_gift))
      , sender_dialog_id(sender_dialog_id)
      , owner_dialog_id(owner_dialog_id)
      , saved_id(saved_id)
      , transfer_star_count(transfer_star_count)
      , can_export_at(can_export_at)
      , is_saved(is_saved)
      , is_upgrade(is_upgrade)
      , can_transfer(can_transfer)
      , was_transferred(was_transferred)
      , was_refunded(was_refunded) {
  }

  MessageContentType get_type() const final {
    return MessageContentType::StarGiftUnique;
  }
};

template <class StorerT>
static void store(const MessageContent *content, StorerT &storer) {
  CHECK(content != nullptr);

  Td *td = storer.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  auto content_type = content->get_type();
  store(content_type, storer);

  switch (content_type) {
    case MessageContentType::Animation: {
      const auto *m = static_cast<const MessageAnimation *>(content);
      td->animations_manager_->store_animation(m->file_id, storer);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->has_spoiler);
      END_STORE_FLAGS();
      store(m->caption, storer);
      break;
    }
    case MessageContentType::Audio: {
      const auto *m = static_cast<const MessageAudio *>(content);
      td->audios_manager_->store_audio(m->file_id, storer);
      store(m->caption, storer);
      store(true, storer);
      break;
    }
    case MessageContentType::Contact: {
      const auto *m = static_cast<const MessageContact *>(content);
      store(m->contact, storer);
      break;
    }
    case MessageContentType::Document: {
      const auto *m = static_cast<const MessageDocument *>(content);
      td->documents_manager_->store_document(m->file_id, storer);
      store(m->caption, storer);
      break;
    }
    case MessageContentType::Game: {
      const auto *m = static_cast<const MessageGame *>(content);
      store(m->game, storer);
      break;
    }
    case MessageContentType::Invoice: {
      const auto *m = static_cast<const MessageInvoice *>(content);
      store(m->input_invoice, storer);
      break;
    }
    case MessageContentType::LiveLocation: {
      const auto *m = static_cast<const MessageLiveLocation *>(content);
      store(m->location, storer);
      store(m->period, storer);
      store(m->heading, storer);
      store(m->proximity_alert_radius, storer);
      break;
    }
    case MessageContentType::Location: {
      const auto *m = static_cast<const MessageLocation *>(content);
      store(m->location, storer);
      break;
    }
    case MessageContentType::Photo: {
      const auto *m = static_cast<const MessagePhoto *>(content);
      store(m->photo, storer);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->has_spoiler);
      END_STORE_FLAGS();
      store(m->caption, storer);
      break;
    }
    case MessageContentType::Sticker: {
      const auto *m = static_cast<const MessageSticker *>(content);
      td->stickers_manager_->store_sticker(m->file_id, false, storer, "MessageSticker");
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->is_premium);
      END_STORE_FLAGS();
      break;
    }
    case MessageContentType::Text: {
      const auto *m = static_cast<const MessageText *>(content);
      bool has_web_page_id = m->web_page_id.is_valid();
      bool has_web_page_url = !m->web_page_url.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_web_page_id);
      STORE_FLAG(m->force_small_media);
      STORE_FLAG(m->force_large_media);
      STORE_FLAG(has_web_page_url);
      STORE_FLAG(m->skip_web_page_confirmation);
      END_STORE_FLAGS();
      store(m->text, storer);
      if (has_web_page_id) {
        store(m->web_page_id, storer);
      }
      if (has_web_page_url) {
        store(m->web_page_url, storer);
      }
      break;
    }
    case MessageContentType::Unsupported: {
      const auto *m = static_cast<const MessageUnsupported *>(content);
      store(m->version, storer);
      break;
    }
    case MessageContentType::Venue: {
      const auto *m = static_cast<const MessageVenue *>(content);
      store(m->venue, storer);
      break;
    }
    case MessageContentType::Video: {
      const auto *m = static_cast<const MessageVideo *>(content);
      td->videos_manager_->store_video(m->file_id, storer);
      bool has_alternative_videos = !m->alternative_file_ids.empty();
      bool has_hls_files = !m->hls_file_ids.empty();
      bool has_cover = !m->cover.is_empty();
      bool has_start_timestamp = m->start_timestamp != 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->has_spoiler);
      STORE_FLAG(has_alternative_videos);
      STORE_FLAG(has_hls_files);
      STORE_FLAG(has_cover);
      STORE_FLAG(has_start_timestamp);
      END_STORE_FLAGS();
      store(m->caption, storer);
      if (has_alternative_videos) {
        store(static_cast<int32>(m->alternative_file_ids.size()), storer);
        for (auto file_id : m->alternative_file_ids) {
          td->videos_manager_->store_video(file_id, storer);
        }
      }
      if (has_hls_files) {
        store(static_cast<int32>(m->hls_file_ids.size()), storer);
        for (auto file_id : m->hls_file_ids) {
          td->documents_manager_->store_document(file_id, storer);
        }
      }
      if (has_cover) {
        store(m->cover, storer);
      }
      if (has_start_timestamp) {
        store(m->start_timestamp, storer);
      }
      break;
    }
    case MessageContentType::VideoNote: {
      const auto *m = static_cast<const MessageVideoNote *>(content);
      td->video_notes_manager_->store_video_note(m->file_id, storer);
      store(m->is_viewed, storer);
      break;
    }
    case MessageContentType::VoiceNote: {
      const auto *m = static_cast<const MessageVoiceNote *>(content);
      td->voice_notes_manager_->store_voice_note(m->file_id, storer);
      store(m->caption, storer);
      store(m->is_listened, storer);
      break;
    }
    case MessageContentType::ChatCreate: {
      const auto *m = static_cast<const MessageChatCreate *>(content);
      store(m->title, storer);
      store(m->participant_user_ids, storer);
      break;
    }
    case MessageContentType::ChatChangeTitle: {
      const auto *m = static_cast<const MessageChatChangeTitle *>(content);
      store(m->title, storer);
      break;
    }
    case MessageContentType::ChatChangePhoto: {
      const auto *m = static_cast<const MessageChatChangePhoto *>(content);
      store(m->photo, storer);
      break;
    }
    case MessageContentType::ChatDeletePhoto:
      break;
    case MessageContentType::ChatDeleteHistory:
      break;
    case MessageContentType::ChatAddUsers: {
      const auto *m = static_cast<const MessageChatAddUsers *>(content);
      store(m->user_ids, storer);
      break;
    }
    case MessageContentType::ChatJoinedByLink: {
      auto m = static_cast<const MessageChatJoinedByLink *>(content);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->is_approved);
      END_STORE_FLAGS();
      break;
    }
    case MessageContentType::ChatDeleteUser: {
      const auto *m = static_cast<const MessageChatDeleteUser *>(content);
      store(m->user_id, storer);
      break;
    }
    case MessageContentType::ChatMigrateTo: {
      const auto *m = static_cast<const MessageChatMigrateTo *>(content);
      store(m->migrated_to_channel_id, storer);
      break;
    }
    case MessageContentType::ChannelCreate: {
      const auto *m = static_cast<const MessageChannelCreate *>(content);
      store(m->title, storer);
      break;
    }
    case MessageContentType::ChannelMigrateFrom: {
      const auto *m = static_cast<const MessageChannelMigrateFrom *>(content);
      store(m->title, storer);
      store(m->migrated_from_chat_id, storer);
      break;
    }
    case MessageContentType::PinMessage: {
      const auto *m = static_cast<const MessagePinMessage *>(content);
      store(m->message_id, storer);
      break;
    }
    case MessageContentType::GameScore: {
      const auto *m = static_cast<const MessageGameScore *>(content);
      store(m->game_message_id, storer);
      store(m->game_id, storer);
      store(m->score, storer);
      break;
    }
    case MessageContentType::ScreenshotTaken:
      break;
    case MessageContentType::ChatSetTtl: {
      const auto *m = static_cast<const MessageChatSetTtl *>(content);
      bool has_from_user_id = m->from_user_id.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_from_user_id);
      END_STORE_FLAGS();
      store(m->ttl, storer);
      if (has_from_user_id) {
        store(m->from_user_id, storer);
      }
      break;
    }
    case MessageContentType::Call: {
      const auto *m = static_cast<const MessageCall *>(content);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->is_video);
      END_STORE_FLAGS();
      store(m->call_id, storer);
      store(m->duration, storer);
      store(m->discard_reason.type_, storer);
      break;
    }
    case MessageContentType::PaymentSuccessful: {
      const auto *m = static_cast<const MessagePaymentSuccessful *>(content);
      bool has_payload = !m->invoice_payload.empty();
      bool has_shipping_option_id = !m->shipping_option_id.empty();
      bool has_order_info = m->order_info != nullptr;
      bool has_telegram_payment_charge_id = !m->telegram_payment_charge_id.empty();
      bool has_provider_payment_charge_id = !m->provider_payment_charge_id.empty();
      bool has_invoice_message_id = m->invoice_message_id.is_valid();
      bool is_correctly_stored = true;
      bool has_invoice_dialog_id = m->invoice_dialog_id.is_valid();
      bool has_subscription_until_date = m->subscription_until_date != 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_payload);
      STORE_FLAG(has_shipping_option_id);
      STORE_FLAG(has_order_info);
      STORE_FLAG(has_telegram_payment_charge_id);
      STORE_FLAG(has_provider_payment_charge_id);
      STORE_FLAG(has_invoice_message_id);
      STORE_FLAG(is_correctly_stored);
      STORE_FLAG(has_invoice_dialog_id);
      STORE_FLAG(m->is_recurring);
      STORE_FLAG(m->is_first_recurring);
      STORE_FLAG(has_subscription_until_date);
      END_STORE_FLAGS();
      store(m->currency, storer);
      store(m->total_amount, storer);
      if (has_payload) {
        store(m->invoice_payload, storer);
      }
      if (has_shipping_option_id) {
        store(m->shipping_option_id, storer);
      }
      if (has_order_info) {
        store(m->order_info, storer);
      }
      if (has_telegram_payment_charge_id) {
        store(m->telegram_payment_charge_id, storer);
      }
      if (has_provider_payment_charge_id) {
        store(m->provider_payment_charge_id, storer);
      }
      if (has_invoice_message_id) {
        store(m->invoice_message_id, storer);
      }
      if (has_invoice_dialog_id) {
        store(m->invoice_dialog_id, storer);
      }
      if (has_subscription_until_date) {
        store(m->subscription_until_date, storer);
      }
      break;
    }
    case MessageContentType::ContactRegistered:
      break;
    case MessageContentType::ExpiredPhoto:
      break;
    case MessageContentType::ExpiredVideo:
      break;
    case MessageContentType::CustomServiceAction: {
      const auto *m = static_cast<const MessageCustomServiceAction *>(content);
      store(m->message, storer);
      break;
    }
    case MessageContentType::WebsiteConnected: {
      const auto *m = static_cast<const MessageWebsiteConnected *>(content);
      store(m->domain_name, storer);
      break;
    }
    case MessageContentType::PassportDataSent: {
      const auto *m = static_cast<const MessagePassportDataSent *>(content);
      store(m->types, storer);
      break;
    }
    case MessageContentType::PassportDataReceived: {
      const auto *m = static_cast<const MessagePassportDataReceived *>(content);
      store(m->values, storer);
      store(m->credentials, storer);
      break;
    }
    case MessageContentType::Poll: {
      const auto *m = static_cast<const MessagePoll *>(content);
      store(m->poll_id, storer);
      break;
    }
    case MessageContentType::Dice: {
      const auto *m = static_cast<const MessageDice *>(content);
      store(m->emoji, storer);
      store(m->dice_value, storer);
      break;
    }
    case MessageContentType::ProximityAlertTriggered: {
      const auto *m = static_cast<const MessageProximityAlertTriggered *>(content);
      store(m->traveler_dialog_id, storer);
      store(m->watcher_dialog_id, storer);
      store(m->distance, storer);
      break;
    }
    case MessageContentType::GroupCall: {
      const auto *m = static_cast<const MessageGroupCall *>(content);
      bool has_duration = m->duration >= 0;
      bool has_schedule_date = m->schedule_date > 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_duration);
      STORE_FLAG(has_schedule_date);
      END_STORE_FLAGS();
      store(m->input_group_call_id, storer);
      if (has_duration) {
        store(m->duration, storer);
      }
      if (has_schedule_date) {
        store(m->schedule_date, storer);
      }
      break;
    }
    case MessageContentType::InviteToGroupCall: {
      const auto *m = static_cast<const MessageInviteToGroupCall *>(content);
      store(m->input_group_call_id, storer);
      store(m->user_ids, storer);
      break;
    }
    case MessageContentType::ChatSetTheme: {
      const auto *m = static_cast<const MessageChatSetTheme *>(content);
      store(m->emoji, storer);
      break;
    }
    case MessageContentType::WebViewDataSent: {
      const auto *m = static_cast<const MessageWebViewDataSent *>(content);
      store(m->button_text, storer);
      break;
    }
    case MessageContentType::WebViewDataReceived: {
      const auto *m = static_cast<const MessageWebViewDataReceived *>(content);
      store(m->button_text, storer);
      store(m->data, storer);
      break;
    }
    case MessageContentType::GiftPremium: {
      const auto *m = static_cast<const MessageGiftPremium *>(content);
      bool has_crypto_amount = !m->crypto_currency.empty();
      bool has_text = !m->text.text.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_crypto_amount);
      STORE_FLAG(has_text);
      END_STORE_FLAGS();
      store(m->currency, storer);
      store(m->amount, storer);
      store(m->months, storer);
      if (has_crypto_amount) {
        store(m->crypto_currency, storer);
        store(m->crypto_amount, storer);
      }
      if (has_text) {
        store(m->text, storer);
      }
      break;
    }
    case MessageContentType::TopicCreate: {
      const auto *m = static_cast<const MessageTopicCreate *>(content);
      store(m->title, storer);
      store(m->icon, storer);
      break;
    }
    case MessageContentType::TopicEdit: {
      const auto *m = static_cast<const MessageTopicEdit *>(content);
      store(m->edited_data, storer);
      break;
    }
    case MessageContentType::SuggestProfilePhoto: {
      const auto *m = static_cast<const MessageSuggestProfilePhoto *>(content);
      store(m->photo, storer);
      break;
    }
    case MessageContentType::WriteAccessAllowed:
      break;
    case MessageContentType::RequestedDialog: {
      const auto *m = static_cast<const MessageRequestedDialog *>(content);
      bool has_one_shared_dialog = m->shared_dialog_ids.size() == 1;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_one_shared_dialog);
      END_STORE_FLAGS();
      if (has_one_shared_dialog) {
        store(m->shared_dialog_ids[0], storer);
      } else {
        store(m->shared_dialog_ids, storer);
      }
      store(m->button_id, storer);
      break;
    }
    case MessageContentType::WebViewWriteAccessAllowed: {
      const auto *m = static_cast<const MessageWebViewWriteAccessAllowed *>(content);
      store(m->web_app, storer);
      break;
    }
    case MessageContentType::SetBackground: {
      const auto *m = static_cast<const MessageSetBackground *>(content);
      bool has_message_id = m->old_message_id.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_message_id);
      STORE_FLAG(m->for_both);
      END_STORE_FLAGS();
      if (has_message_id) {
        store(m->old_message_id, storer);
      }
      store(m->background_info, storer);
      break;
    }
    case MessageContentType::Story: {
      const auto *m = static_cast<const MessageStory *>(content);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->via_mention);
      END_STORE_FLAGS();
      store(m->story_full_id, storer);
      break;
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      break;
    case MessageContentType::GiftCode: {
      const auto *m = static_cast<const MessageGiftCode *>(content);
      bool has_creator_dialog_id = m->creator_dialog_id.is_valid();
      bool has_currency = !m->currency.empty();
      bool has_amount = m->amount > 0;
      bool has_crypto_currency = !m->crypto_currency.empty();
      bool has_crypto_amount = m->crypto_amount > 0;
      bool has_text = !m->text.text.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->via_giveaway);
      STORE_FLAG(has_creator_dialog_id);
      STORE_FLAG(m->is_unclaimed);
      STORE_FLAG(has_currency);
      STORE_FLAG(has_amount);
      STORE_FLAG(has_crypto_currency);
      STORE_FLAG(has_crypto_amount);
      STORE_FLAG(has_text);
      END_STORE_FLAGS();
      if (has_creator_dialog_id) {
        store(m->creator_dialog_id, storer);
      }
      store(m->months, storer);
      store(m->code, storer);
      if (has_currency) {
        store(m->currency, storer);
      }
      if (has_amount) {
        store(m->amount, storer);
      }
      if (has_crypto_currency) {
        store(m->crypto_currency, storer);
      }
      if (has_crypto_amount) {
        store(m->crypto_amount, storer);
      }
      if (has_text) {
        store(m->text, storer);
      }
      break;
    }
    case MessageContentType::Giveaway: {
      const auto *m = static_cast<const MessageGiveaway *>(content);
      bool has_star_count = m->star_count != 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_star_count);
      END_STORE_FLAGS();
      store(m->giveaway_parameters, storer);
      store(m->quantity, storer);
      store(m->months, storer);
      if (has_star_count) {
        store(m->star_count, storer);
      }
      break;
    }
    case MessageContentType::GiveawayLaunch: {
      const auto *m = static_cast<const MessageGiveawayLaunch *>(content);
      bool has_star_count = m->star_count != 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_star_count);
      END_STORE_FLAGS();
      if (has_star_count) {
        store(m->star_count, storer);
      }
      break;
    }
    case MessageContentType::GiveawayResults: {
      const auto *m = static_cast<const MessageGiveawayResults *>(content);
      bool has_winner_count = m->winner_count != 0;
      bool has_unclaimed_count = m->unclaimed_count != 0;
      bool has_giveaway_message_id = m->giveaway_message_id.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_winner_count);
      STORE_FLAG(has_unclaimed_count);
      STORE_FLAG(has_giveaway_message_id);
      STORE_FLAG(m->is_star_giveaway);
      END_STORE_FLAGS();
      if (has_winner_count) {
        store(m->winner_count, storer);
      }
      if (has_unclaimed_count) {
        store(m->unclaimed_count, storer);
      }
      if (has_giveaway_message_id) {
        store(m->giveaway_message_id, storer);
      }
      break;
    }
    case MessageContentType::GiveawayWinners: {
      const auto *m = static_cast<const MessageGiveawayWinners *>(content);
      bool has_giveaway_message_id = m->giveaway_message_id.is_valid();
      bool has_boosted_channel_id = m->boosted_channel_id.is_valid();
      bool has_additional_dialog_count = m->additional_dialog_count != 0;
      bool has_month_count = m->month_count != 0;
      bool has_prize_description = !m->prize_description.empty();
      bool has_winners_selection_date = m->winners_selection_date != 0;
      bool has_winner_count = m->winner_count != 0;
      bool has_unclaimed_count = m->unclaimed_count != 0;
      bool has_winner_user_ids = !m->winner_user_ids.empty();
      bool has_star_count = m->star_count != 0;
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->only_new_subscribers);
      STORE_FLAG(m->was_refunded);
      STORE_FLAG(has_giveaway_message_id);
      STORE_FLAG(has_boosted_channel_id);
      STORE_FLAG(has_additional_dialog_count);
      STORE_FLAG(has_month_count);
      STORE_FLAG(has_prize_description);
      STORE_FLAG(has_winners_selection_date);
      STORE_FLAG(has_winner_count);
      STORE_FLAG(has_unclaimed_count);
      STORE_FLAG(has_winner_user_ids);
      STORE_FLAG(has_star_count);
      END_STORE_FLAGS();
      if (has_giveaway_message_id) {
        store(m->giveaway_message_id, storer);
      }
      if (has_boosted_channel_id) {
        store(m->boosted_channel_id, storer);
      }
      if (has_additional_dialog_count) {
        store(m->additional_dialog_count, storer);
      }
      if (has_month_count) {
        store(m->month_count, storer);
      }
      if (has_prize_description) {
        store(m->prize_description, storer);
      }
      if (has_winners_selection_date) {
        store(m->winners_selection_date, storer);
      }
      if (has_winner_count) {
        store(m->winner_count, storer);
      }
      if (has_unclaimed_count) {
        store(m->unclaimed_count, storer);
      }
      if (has_winner_user_ids) {
        store(m->winner_user_ids, storer);
      }
      if (has_star_count) {
        store(m->star_count, storer);
      }
      break;
    }
    case MessageContentType::ExpiredVideoNote:
      break;
    case MessageContentType::ExpiredVoiceNote:
      break;
    case MessageContentType::BoostApply: {
      const auto *m = static_cast<const MessageBoostApply *>(content);
      BEGIN_STORE_FLAGS();
      END_STORE_FLAGS();
      store(m->boost_count, storer);
      break;
    }
    case MessageContentType::DialogShared: {
      const auto *m = static_cast<const MessageDialogShared *>(content);
      BEGIN_STORE_FLAGS();
      END_STORE_FLAGS();
      store(m->shared_dialogs, storer);
      store(m->button_id, storer);
      break;
    }
    case MessageContentType::PaidMedia: {
      const auto *m = static_cast<const MessagePaidMedia *>(content);
      bool has_caption = !m->caption.text.empty();
      bool has_payload = !m->payload.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_caption);
      STORE_FLAG(has_payload);
      END_STORE_FLAGS();
      store(m->media, storer);
      if (has_caption) {
        store(m->caption, storer);
      }
      store(m->star_count, storer);
      if (has_payload) {
        store(m->payload, storer);
      }
      break;
    }
    case MessageContentType::PaymentRefunded: {
      const auto *m = static_cast<const MessagePaymentRefunded *>(content);
      bool has_invoice_payload = !m->invoice_payload.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_invoice_payload);
      END_STORE_FLAGS();
      store(m->dialog_id, storer);
      store(m->currency, storer);
      store(m->total_amount, storer);
      if (has_invoice_payload) {
        store(m->invoice_payload, storer);
      }
      store(m->telegram_payment_charge_id, storer);
      store(m->provider_payment_charge_id, storer);
      break;
    }
    case MessageContentType::GiftStars: {
      const auto *m = static_cast<const MessageGiftStars *>(content);
      bool has_crypto_amount = !m->crypto_currency.empty();
      bool has_transaction_id = !m->transaction_id.empty();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_crypto_amount);
      STORE_FLAG(has_transaction_id);
      END_STORE_FLAGS();
      store(m->currency, storer);
      store(m->amount, storer);
      store(m->star_count, storer);
      if (has_crypto_amount) {
        store(m->crypto_currency, storer);
        store(m->crypto_amount, storer);
      }
      if (has_transaction_id) {
        store(m->transaction_id, storer);
      }
      break;
    }
    case MessageContentType::PrizeStars: {
      const auto *m = static_cast<const MessagePrizeStars *>(content);
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->is_unclaimed);
      END_STORE_FLAGS();
      store(m->star_count, storer);
      store(m->transaction_id, storer);
      store(m->boosted_dialog_id, storer);
      store(m->giveaway_message_id, storer);
      break;
    }
    case MessageContentType::StarGift: {
      const auto *m = static_cast<const MessageStarGift *>(content);
      bool has_text = !m->text.text.empty();
      bool has_upgrade_star_count = m->upgrade_star_count != 0;
      bool has_upgrade_message_id = m->upgrade_message_id.is_valid();
      bool has_owner_dialog_id = m->owner_dialog_id.is_valid();
      bool has_saved_id = m->saved_id != 0;
      bool has_sender_dialog_id = m->sender_dialog_id.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(m->name_hidden);
      STORE_FLAG(m->is_saved);
      STORE_FLAG(m->was_converted);
      STORE_FLAG(has_text);
      STORE_FLAG(m->was_upgraded);
      STORE_FLAG(m->can_upgrade);
      STORE_FLAG(has_upgrade_star_count);
      STORE_FLAG(m->was_refunded);
      STORE_FLAG(has_upgrade_message_id);
      STORE_FLAG(has_owner_dialog_id);
      STORE_FLAG(has_saved_id);
      STORE_FLAG(has_sender_dialog_id);
      END_STORE_FLAGS();
      store(m->star_gift, storer);
      if (has_text) {
        store(m->text, storer);
      }
      store(m->convert_star_count, storer);
      if (has_upgrade_star_count) {
        store(m->upgrade_star_count, storer);
      }
      if (has_upgrade_message_id) {
        store(m->upgrade_message_id, storer);
      }
      if (has_owner_dialog_id) {
        store(m->owner_dialog_id, storer);
      }
      if (has_saved_id) {
        store(m->saved_id, storer);
      }
      if (has_sender_dialog_id) {
        store(m->sender_dialog_id, storer);
      }
      break;
    }
    case MessageContentType::StarGiftUnique: {
      const auto *m = static_cast<const MessageStarGiftUnique *>(content);
      bool has_transfer_star_count = m->transfer_star_count != 0;
      bool has_can_export_at = m->can_export_at != 0;
      bool has_owner_dialog_id = m->owner_dialog_id.is_valid();
      bool has_saved_id = m->saved_id != 0;
      bool has_sender_dialog_id = m->sender_dialog_id.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_transfer_star_count);
      STORE_FLAG(has_can_export_at);
      STORE_FLAG(m->is_saved);
      STORE_FLAG(m->is_upgrade);
      STORE_FLAG(m->was_transferred);
      STORE_FLAG(m->can_transfer);
      STORE_FLAG(m->was_refunded);
      STORE_FLAG(has_owner_dialog_id);
      STORE_FLAG(has_saved_id);
      STORE_FLAG(has_sender_dialog_id);
      END_STORE_FLAGS();
      store(m->star_gift, storer);
      if (has_transfer_star_count) {
        store(m->transfer_star_count, storer);
      }
      if (has_can_export_at) {
        store(m->can_export_at, storer);
      }
      if (has_owner_dialog_id) {
        store(m->owner_dialog_id, storer);
      }
      if (has_saved_id) {
        store(m->saved_id, storer);
      }
      if (has_sender_dialog_id) {
        store(m->sender_dialog_id, storer);
      }
      break;
    }
    default:
      UNREACHABLE();
  }
}

template <class ParserT>
static void parse_caption(FormattedText &caption, ParserT &parser) {
  parse(caption.text, parser);
  if (parser.version() >= static_cast<int32>(Version::AddCaptionEntities)) {
    parse(caption.entities, parser);
    remove_empty_entities(caption.entities);
  } else {
    if (!check_utf8(caption.text)) {
      caption.text.clear();
    }
    caption.entities = find_entities(caption.text, false, true);
  }
}

template <class ParserT>
static void parse(unique_ptr<MessageContent> &content, ParserT &parser) {
  Td *td = parser.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  MessageContentType content_type;
  parse(content_type, parser);

  bool is_bad = false;
  switch (content_type) {
    case MessageContentType::Animation: {
      auto m = make_unique<MessageAnimation>();
      m->file_id = td->animations_manager_->parse_animation(parser);
      if (parser.version() >= static_cast<int32>(Version::AddMessageMediaSpoiler)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->has_spoiler);
        END_PARSE_FLAGS();
      }
      parse_caption(m->caption, parser);
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::Audio: {
      auto m = make_unique<MessageAudio>();
      m->file_id = td->audios_manager_->parse_audio(parser);
      parse_caption(m->caption, parser);
      bool legacy_is_listened;
      parse(legacy_is_listened, parser);
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::Contact: {
      auto m = make_unique<MessageContact>();
      parse(m->contact, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Document: {
      auto m = make_unique<MessageDocument>();
      m->file_id = td->documents_manager_->parse_document(parser);
      parse_caption(m->caption, parser);
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::Game: {
      auto m = make_unique<MessageGame>();
      parse(m->game, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Invoice: {
      auto m = make_unique<MessageInvoice>();
      parse(m->input_invoice, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::LiveLocation: {
      auto m = make_unique<MessageLiveLocation>();
      parse(m->location, parser);
      parse(m->period, parser);
      if (parser.version() >= static_cast<int32>(Version::AddLiveLocationHeading)) {
        parse(m->heading, parser);
      } else {
        m->heading = 0;
      }
      if (parser.version() >= static_cast<int32>(Version::AddLiveLocationProximityAlertDistance)) {
        parse(m->proximity_alert_radius, parser);
      } else {
        m->proximity_alert_radius = 0;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::Location: {
      auto m = make_unique<MessageLocation>();
      parse(m->location, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Photo: {
      auto m = make_unique<MessagePhoto>();
      parse(m->photo, parser);
      is_bad |= m->photo.is_bad();
      if (parser.version() >= static_cast<int32>(Version::AddMessageMediaSpoiler)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->has_spoiler);
        END_PARSE_FLAGS();
      }
      parse_caption(m->caption, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Sticker: {
      auto m = make_unique<MessageSticker>();
      m->file_id = td->stickers_manager_->parse_sticker(false, parser);
      if (parser.version() >= static_cast<int32>(Version::AddMessageStickerFlags)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->is_premium);
        END_PARSE_FLAGS();
      }
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::Text: {
      auto m = make_unique<MessageText>();
      bool has_web_page_id = true;
      bool has_web_page_url = false;
      if (parser.version() >= static_cast<int32>(Version::AddMessageTextFlags)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(has_web_page_id);
        PARSE_FLAG(m->force_small_media);
        PARSE_FLAG(m->force_large_media);
        PARSE_FLAG(has_web_page_url);
        PARSE_FLAG(m->skip_web_page_confirmation);
        END_PARSE_FLAGS();
      }
      parse(m->text, parser);
      if (has_web_page_id) {
        parse(m->web_page_id, parser);
      }
      if (has_web_page_url) {
        parse(m->web_page_url, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::Unsupported: {
      auto m = make_unique<MessageUnsupported>();
      if (parser.version() >= static_cast<int32>(Version::AddMessageUnsupportedVersion)) {
        parse(m->version, parser);
      } else {
        m->version = 0;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::Venue: {
      auto m = make_unique<MessageVenue>();
      parse(m->venue, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Video: {
      auto m = make_unique<MessageVideo>();
      m->file_id = td->videos_manager_->parse_video(parser);
      bool has_alternative_videos = false;
      bool has_hls_files = false;
      bool has_cover = false;
      bool has_start_timestamp = false;
      if (parser.version() >= static_cast<int32>(Version::AddMessageMediaSpoiler)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->has_spoiler);
        PARSE_FLAG(has_alternative_videos);
        PARSE_FLAG(has_hls_files);
        PARSE_FLAG(has_cover);
        PARSE_FLAG(has_start_timestamp);
        END_PARSE_FLAGS();
      }
      parse_caption(m->caption, parser);
      if (has_alternative_videos) {
        int32 video_count = 0;
        parse(video_count, parser);
        for (int32 i = 0; i < video_count; i++) {
          auto file_id = td->videos_manager_->parse_video(parser);
          if (!file_id.is_valid()) {
            is_bad = true;
          } else {
            m->alternative_file_ids.push_back(file_id);
          }
        }
      }
      if (has_hls_files) {
        int32 file_count = 0;
        parse(file_count, parser);
        for (int32 i = 0; i < file_count; i++) {
          auto file_id = td->documents_manager_->parse_document(parser);
          if (!file_id.is_valid()) {
            is_bad = true;
          } else {
            m->hls_file_ids.push_back(file_id);
          }
        }
      }
      if (has_cover) {
        parse(m->cover, parser);
      }
      if (has_start_timestamp) {
        parse(m->start_timestamp, parser);
      }

      if (!m->file_id.is_valid()) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::VideoNote: {
      auto m = make_unique<MessageVideoNote>();
      m->file_id = td->video_notes_manager_->parse_video_note(parser);
      parse(m->is_viewed, parser);
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::VoiceNote: {
      auto m = make_unique<MessageVoiceNote>();
      m->file_id = td->voice_notes_manager_->parse_voice_note(parser);
      parse_caption(m->caption, parser);
      parse(m->is_listened, parser);
      is_bad = !m->file_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatCreate: {
      auto m = make_unique<MessageChatCreate>();
      parse(m->title, parser);
      parse(m->participant_user_ids, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatChangeTitle: {
      auto m = make_unique<MessageChatChangeTitle>();
      parse(m->title, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatChangePhoto: {
      auto m = make_unique<MessageChatChangePhoto>();
      parse(m->photo, parser);
      if (m->photo.is_empty()) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatDeletePhoto:
      content = make_unique<MessageChatDeletePhoto>();
      break;
    case MessageContentType::ChatDeleteHistory:
      content = make_unique<MessageChatDeleteHistory>();
      break;
    case MessageContentType::ChatAddUsers: {
      auto m = make_unique<MessageChatAddUsers>();
      parse(m->user_ids, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatJoinedByLink: {
      auto m = make_unique<MessageChatJoinedByLink>();
      if (parser.version() >= static_cast<int32>(Version::AddInviteLinksRequiringApproval)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->is_approved);
        END_PARSE_FLAGS();
      } else {
        m->is_approved = false;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatDeleteUser: {
      auto m = make_unique<MessageChatDeleteUser>();
      parse(m->user_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatMigrateTo: {
      auto m = make_unique<MessageChatMigrateTo>();
      parse(m->migrated_to_channel_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChannelCreate: {
      auto m = make_unique<MessageChannelCreate>();
      parse(m->title, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChannelMigrateFrom: {
      auto m = make_unique<MessageChannelMigrateFrom>();
      parse(m->title, parser);
      parse(m->migrated_from_chat_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::PinMessage: {
      auto m = make_unique<MessagePinMessage>();
      parse(m->message_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::GameScore: {
      auto m = make_unique<MessageGameScore>();
      parse(m->game_message_id, parser);
      parse(m->game_id, parser);
      parse(m->score, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ScreenshotTaken:
      content = make_unique<MessageScreenshotTaken>();
      break;
    case MessageContentType::ChatSetTtl: {
      auto m = make_unique<MessageChatSetTtl>();
      bool has_from_user_id = false;
      if (parser.version() >= static_cast<int32>(Version::AddMessageChatSetTtlFlags)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(has_from_user_id);
        END_PARSE_FLAGS();
      }
      parse(m->ttl, parser);
      if (has_from_user_id) {
        parse(m->from_user_id, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::Call: {
      auto m = make_unique<MessageCall>();
      if (parser.version() >= static_cast<int32>(Version::AddVideoCallsSupport)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(m->is_video);
        END_PARSE_FLAGS();
      } else {
        m->is_video = false;
      }
      parse(m->call_id, parser);
      parse(m->duration, parser);
      parse(m->discard_reason.type_, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::PaymentSuccessful: {
      auto m = make_unique<MessagePaymentSuccessful>();
      bool has_payload;
      bool has_shipping_option_id;
      bool has_order_info;
      bool has_telegram_payment_charge_id;
      bool has_provider_payment_charge_id;
      bool has_invoice_message_id;
      bool is_correctly_stored;
      bool has_invoice_dialog_id;
      bool has_subscription_until_date;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_payload);
      PARSE_FLAG(has_shipping_option_id);
      PARSE_FLAG(has_order_info);
      PARSE_FLAG(has_telegram_payment_charge_id);
      PARSE_FLAG(has_provider_payment_charge_id);
      PARSE_FLAG(has_invoice_message_id);
      PARSE_FLAG(is_correctly_stored);
      PARSE_FLAG(has_invoice_dialog_id);
      PARSE_FLAG(m->is_recurring);
      PARSE_FLAG(m->is_first_recurring);
      PARSE_FLAG(has_subscription_until_date);
      END_PARSE_FLAGS();
      parse(m->currency, parser);
      parse(m->total_amount, parser);
      if (is_correctly_stored) {
        if (has_payload) {
          parse(m->invoice_payload, parser);
        }
        if (has_shipping_option_id) {
          parse(m->shipping_option_id, parser);
        }
      } else {
        if (has_payload) {
          parse(m->total_amount, parser);
        }
        if (has_shipping_option_id) {
          parse(m->invoice_payload, parser);
        }
      }
      if (has_order_info) {
        parse(m->order_info, parser);
      }
      if (has_telegram_payment_charge_id) {
        parse(m->telegram_payment_charge_id, parser);
      }
      if (has_provider_payment_charge_id) {
        parse(m->provider_payment_charge_id, parser);
      }
      if (has_invoice_message_id) {
        parse(m->invoice_message_id, parser);
      }
      if (has_invoice_dialog_id) {
        parse(m->invoice_dialog_id, parser);
      }
      if (has_subscription_until_date) {
        parse(m->subscription_until_date, parser);
      }
      if (is_correctly_stored) {
        content = std::move(m);
      } else {
        content = make_unique<MessageUnsupported>(0);
      }
      break;
    }
    case MessageContentType::ContactRegistered:
      content = make_unique<MessageContactRegistered>();
      break;
    case MessageContentType::ExpiredPhoto:
      content = make_unique<MessageExpiredPhoto>();
      break;
    case MessageContentType::ExpiredVideo:
      content = make_unique<MessageExpiredVideo>();
      break;
    case MessageContentType::CustomServiceAction: {
      auto m = make_unique<MessageCustomServiceAction>();
      parse(m->message, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::WebsiteConnected: {
      auto m = make_unique<MessageWebsiteConnected>();
      parse(m->domain_name, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::PassportDataSent: {
      auto m = make_unique<MessagePassportDataSent>();
      parse(m->types, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::PassportDataReceived: {
      auto m = make_unique<MessagePassportDataReceived>();
      parse(m->values, parser);
      parse(m->credentials, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Poll: {
      auto m = make_unique<MessagePoll>();
      parse(m->poll_id, parser);
      is_bad = !m->poll_id.is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::Dice: {
      auto m = make_unique<MessageDice>();
      if (parser.version() >= static_cast<int32>(Version::AddDiceEmoji)) {
        parse(m->emoji, parser);
        remove_emoji_modifiers_in_place(m->emoji);
      } else {
        m->emoji = MessageDice::DEFAULT_EMOJI;
      }
      parse(m->dice_value, parser);
      is_bad = !m->is_valid();
      content = std::move(m);
      break;
    }
    case MessageContentType::ProximityAlertTriggered: {
      auto m = make_unique<MessageProximityAlertTriggered>();
      parse(m->traveler_dialog_id, parser);
      parse(m->watcher_dialog_id, parser);
      parse(m->distance, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::GroupCall: {
      auto m = make_unique<MessageGroupCall>();
      bool has_duration;
      bool has_schedule_date;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_duration);
      PARSE_FLAG(has_schedule_date);
      END_PARSE_FLAGS();
      parse(m->input_group_call_id, parser);
      if (has_duration) {
        parse(m->duration, parser);
      }
      if (has_schedule_date) {
        parse(m->schedule_date, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::InviteToGroupCall: {
      auto m = make_unique<MessageInviteToGroupCall>();
      parse(m->input_group_call_id, parser);
      parse(m->user_ids, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::ChatSetTheme: {
      auto m = make_unique<MessageChatSetTheme>();
      parse(m->emoji, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::WebViewDataSent: {
      auto m = make_unique<MessageWebViewDataSent>();
      parse(m->button_text, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::WebViewDataReceived: {
      auto m = make_unique<MessageWebViewDataReceived>();
      parse(m->button_text, parser);
      parse(m->data, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::GiftPremium: {
      auto m = make_unique<MessageGiftPremium>();
      bool has_crypto_amount;
      bool has_text;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_crypto_amount);
      PARSE_FLAG(has_text);
      END_PARSE_FLAGS();
      parse(m->currency, parser);
      parse(m->amount, parser);
      parse(m->months, parser);
      if (has_crypto_amount) {
        parse(m->crypto_currency, parser);
        parse(m->crypto_amount, parser);
      }
      if (has_text) {
        parse(m->text, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::TopicCreate: {
      auto m = make_unique<MessageTopicCreate>();
      parse(m->title, parser);
      parse(m->icon, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::TopicEdit: {
      auto m = make_unique<MessageTopicEdit>();
      parse(m->edited_data, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::SuggestProfilePhoto: {
      auto m = make_unique<MessageSuggestProfilePhoto>();
      parse(m->photo, parser);
      if (m->photo.is_empty()) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::WriteAccessAllowed:
      content = make_unique<MessageWriteAccessAllowed>();
      break;
    case MessageContentType::RequestedDialog: {
      auto m = make_unique<MessageRequestedDialog>();
      bool has_one_shared_dialog = true;
      if (parser.version() >= static_cast<int32>(Version::SupportMultipleSharedUsers)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(has_one_shared_dialog);
        END_PARSE_FLAGS();
      }
      if (has_one_shared_dialog) {
        DialogId dialog_id;
        parse(dialog_id, parser);
        m->shared_dialog_ids = {dialog_id};
      } else {
        parse(m->shared_dialog_ids, parser);
        if (m->shared_dialog_ids.size() > 1) {
          for (auto dialog_id : m->shared_dialog_ids) {
            if (dialog_id.get_type() != DialogType::User) {
              is_bad = true;
            }
          }
        }
      }
      if (m->shared_dialog_ids.empty() || !m->shared_dialog_ids[0].is_valid()) {
        is_bad = true;
      }
      parse(m->button_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::WebViewWriteAccessAllowed: {
      auto m = make_unique<MessageWebViewWriteAccessAllowed>();
      parse(m->web_app, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::SetBackground: {
      auto m = make_unique<MessageSetBackground>();
      bool has_message_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_message_id);
      PARSE_FLAG(m->for_both);
      END_PARSE_FLAGS();
      if (has_message_id) {
        parse(m->old_message_id, parser);
      }
      parse(m->background_info, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::Story: {
      auto m = make_unique<MessageStory>();
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(m->via_mention);
      END_PARSE_FLAGS();
      parse(m->story_full_id, parser);
      if (!m->story_full_id.is_server()) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      content = make_unique<MessageWriteAccessAllowedByRequest>();
      break;
    case MessageContentType::GiftCode: {
      auto m = make_unique<MessageGiftCode>();
      bool has_creator_dialog_id;
      bool has_currency;
      bool has_amount;
      bool has_crypto_currency;
      bool has_crypto_amount;
      bool has_text;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(m->via_giveaway);
      PARSE_FLAG(has_creator_dialog_id);
      PARSE_FLAG(m->is_unclaimed);
      PARSE_FLAG(has_currency);
      PARSE_FLAG(has_amount);
      PARSE_FLAG(has_crypto_currency);
      PARSE_FLAG(has_crypto_amount);
      PARSE_FLAG(has_text);
      END_PARSE_FLAGS();
      if (has_creator_dialog_id) {
        parse(m->creator_dialog_id, parser);
      }
      parse(m->months, parser);
      parse(m->code, parser);
      if (has_currency) {
        parse(m->currency, parser);
      }
      if (has_amount) {
        parse(m->amount, parser);
      }
      if (has_crypto_currency) {
        parse(m->crypto_currency, parser);
      }
      if (has_crypto_amount) {
        parse(m->crypto_amount, parser);
      }
      if (has_text) {
        parse(m->text, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::Giveaway: {
      auto m = make_unique<MessageGiveaway>();
      bool has_star_count;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_star_count);
      END_PARSE_FLAGS();
      parse(m->giveaway_parameters, parser);
      parse(m->quantity, parser);
      parse(m->months, parser);
      if (has_star_count) {
        parse(m->star_count, parser);
      }
      if (!m->giveaway_parameters.is_valid()) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::GiveawayLaunch: {
      auto m = make_unique<MessageGiveawayLaunch>();
      bool has_star_count = false;
      if (parser.version() >= static_cast<int32>(Version::SupportStarGiveaways)) {
        BEGIN_PARSE_FLAGS();
        PARSE_FLAG(has_star_count);
        END_PARSE_FLAGS();
      }
      if (has_star_count) {
        parse(m->star_count, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::GiveawayResults: {
      auto m = make_unique<MessageGiveawayResults>();
      bool has_winner_count;
      bool has_unclaimed_count;
      bool has_giveaway_message_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_winner_count);
      PARSE_FLAG(has_unclaimed_count);
      PARSE_FLAG(has_giveaway_message_id);
      PARSE_FLAG(m->is_star_giveaway);
      END_PARSE_FLAGS();
      if (has_winner_count) {
        parse(m->winner_count, parser);
      }
      if (has_unclaimed_count) {
        parse(m->unclaimed_count, parser);
      }
      if (has_giveaway_message_id) {
        parse(m->giveaway_message_id, parser);
      }
      if (m->winner_count < 0 || m->unclaimed_count < 0) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::GiveawayWinners: {
      auto m = make_unique<MessageGiveawayWinners>();
      bool has_giveaway_message_id;
      bool has_boosted_channel_id;
      bool has_additional_dialog_count;
      bool has_month_count;
      bool has_prize_description;
      bool has_winners_selection_date;
      bool has_winner_count;
      bool has_unclaimed_count;
      bool has_winner_user_ids;
      bool has_star_count;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(m->only_new_subscribers);
      PARSE_FLAG(m->was_refunded);
      PARSE_FLAG(has_giveaway_message_id);
      PARSE_FLAG(has_boosted_channel_id);
      PARSE_FLAG(has_additional_dialog_count);
      PARSE_FLAG(has_month_count);
      PARSE_FLAG(has_prize_description);
      PARSE_FLAG(has_winners_selection_date);
      PARSE_FLAG(has_winner_count);
      PARSE_FLAG(has_unclaimed_count);
      PARSE_FLAG(has_winner_user_ids);
      PARSE_FLAG(has_star_count);
      END_PARSE_FLAGS();
      if (has_giveaway_message_id) {
        parse(m->giveaway_message_id, parser);
      }
      if (has_boosted_channel_id) {
        parse(m->boosted_channel_id, parser);
      }
      if (has_additional_dialog_count) {
        parse(m->additional_dialog_count, parser);
      }
      if (has_month_count) {
        parse(m->month_count, parser);
      }
      if (has_prize_description) {
        parse(m->prize_description, parser);
      }
      if (has_winners_selection_date) {
        parse(m->winners_selection_date, parser);
      }
      if (has_winner_count) {
        parse(m->winner_count, parser);
      }
      if (has_unclaimed_count) {
        parse(m->unclaimed_count, parser);
      }
      if (has_winner_user_ids) {
        parse(m->winner_user_ids, parser);
      }
      if (has_star_count) {
        parse(m->star_count, parser);
      }
      if (m->winner_count < 0 || m->unclaimed_count < 0) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::ExpiredVideoNote:
      content = make_unique<MessageExpiredVideoNote>();
      break;
    case MessageContentType::ExpiredVoiceNote:
      content = make_unique<MessageExpiredVoiceNote>();
      break;
    case MessageContentType::BoostApply: {
      auto m = make_unique<MessageBoostApply>();
      BEGIN_PARSE_FLAGS();
      END_PARSE_FLAGS();
      parse(m->boost_count, parser);
      if (m->boost_count < 0) {
        is_bad = true;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::DialogShared: {
      auto m = make_unique<MessageDialogShared>();
      BEGIN_PARSE_FLAGS();
      END_PARSE_FLAGS();
      parse(m->shared_dialogs, parser);
      if (m->shared_dialogs.empty() ||
          any_of(m->shared_dialogs, [](const auto &shared_dialog) { return !shared_dialog.is_valid(); })) {
        is_bad = true;
      }
      parse(m->button_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::PaidMedia: {
      auto m = make_unique<MessagePaidMedia>();
      bool has_caption;
      bool has_payload;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_caption);
      PARSE_FLAG(has_payload);
      END_PARSE_FLAGS();
      parse(m->media, parser);
      if (has_caption) {
        parse(m->caption, parser);
      }
      parse(m->star_count, parser);
      if (has_payload) {
        parse(m->payload, parser);
      }

      for (auto &media : m->media) {
        if (media.is_empty()) {
          is_bad = true;
        }
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::PaymentRefunded: {
      auto m = make_unique<MessagePaymentRefunded>();
      bool has_invoice_payload;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_invoice_payload);
      END_PARSE_FLAGS();
      parse(m->dialog_id, parser);
      parse(m->currency, parser);
      parse(m->total_amount, parser);
      if (has_invoice_payload) {
        parse(m->invoice_payload, parser);
      }
      parse(m->telegram_payment_charge_id, parser);
      parse(m->provider_payment_charge_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::GiftStars: {
      auto m = make_unique<MessageGiftStars>();
      bool has_crypto_amount;
      bool has_transaction_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_crypto_amount);
      PARSE_FLAG(has_transaction_id);
      END_PARSE_FLAGS();
      parse(m->currency, parser);
      parse(m->amount, parser);
      parse(m->star_count, parser);
      if (has_crypto_amount) {
        parse(m->crypto_currency, parser);
        parse(m->crypto_amount, parser);
      }
      if (has_transaction_id) {
        parse(m->transaction_id, parser);
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::PrizeStars: {
      auto m = make_unique<MessagePrizeStars>();
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(m->is_unclaimed);
      END_PARSE_FLAGS();
      parse(m->star_count, parser);
      parse(m->transaction_id, parser);
      parse(m->boosted_dialog_id, parser);
      parse(m->giveaway_message_id, parser);
      content = std::move(m);
      break;
    }
    case MessageContentType::StarGift: {
      auto m = make_unique<MessageStarGift>();
      bool has_text;
      bool has_upgrade_star_count;
      bool has_upgrade_message_id;
      bool has_owner_dialog_id;
      bool has_saved_id;
      bool has_sender_dialog_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(m->name_hidden);
      PARSE_FLAG(m->is_saved);
      PARSE_FLAG(m->was_converted);
      PARSE_FLAG(has_text);
      PARSE_FLAG(m->was_upgraded);
      PARSE_FLAG(m->can_upgrade);
      PARSE_FLAG(has_upgrade_star_count);
      PARSE_FLAG(m->was_refunded);
      PARSE_FLAG(has_upgrade_message_id);
      PARSE_FLAG(has_owner_dialog_id);
      PARSE_FLAG(has_saved_id);
      PARSE_FLAG(has_sender_dialog_id);
      END_PARSE_FLAGS();
      parse(m->star_gift, parser);
      if (has_text) {
        parse(m->text, parser);
      }
      parse(m->convert_star_count, parser);
      if (has_upgrade_star_count) {
        parse(m->upgrade_star_count, parser);
      }
      if (has_upgrade_message_id) {
        parse(m->upgrade_message_id, parser);
      }
      if (has_owner_dialog_id) {
        parse(m->owner_dialog_id, parser);
      }
      if (has_saved_id) {
        parse(m->saved_id, parser);
      }
      if (has_sender_dialog_id) {
        parse(m->sender_dialog_id, parser);
      }
      if (!m->star_gift.is_valid() || m->star_gift.is_unique()) {
        is_bad = true;
        break;
      }
      content = std::move(m);
      break;
    }
    case MessageContentType::StarGiftUnique: {
      auto m = make_unique<MessageStarGiftUnique>();
      bool has_transfer_star_count;
      bool has_can_export_at;
      bool has_owner_dialog_id;
      bool has_saved_id;
      bool has_sender_dialog_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_transfer_star_count);
      PARSE_FLAG(has_can_export_at);
      PARSE_FLAG(m->is_saved);
      PARSE_FLAG(m->is_upgrade);
      PARSE_FLAG(m->was_transferred);
      PARSE_FLAG(m->can_transfer);
      PARSE_FLAG(m->was_refunded);
      PARSE_FLAG(has_owner_dialog_id);
      PARSE_FLAG(has_saved_id);
      PARSE_FLAG(has_sender_dialog_id);
      END_PARSE_FLAGS();
      parse(m->star_gift, parser);
      if (has_transfer_star_count) {
        parse(m->transfer_star_count, parser);
      }
      if (has_can_export_at) {
        parse(m->can_export_at, parser);
      }
      if (has_owner_dialog_id) {
        parse(m->owner_dialog_id, parser);
      }
      if (has_saved_id) {
        parse(m->saved_id, parser);
      }
      if (has_sender_dialog_id) {
        parse(m->sender_dialog_id, parser);
      }
      if (!m->star_gift.is_valid() || m->star_gift.is_unique() == m->was_refunded) {
        is_bad = true;
        break;
      }
      content = std::move(m);
      break;
    }

    default:
      is_bad = true;
  }
  if (is_bad) {
    LOG(ERROR) << "Load a message with an invalid content of type " << content_type;
    content = make_unique<MessageUnsupported>(0);
  }
}

void store_message_content(const MessageContent *content, LogEventStorerCalcLength &storer) {
  store(content, storer);
}

void store_message_content(const MessageContent *content, LogEventStorerUnsafe &storer) {
  store(content, storer);
}

void parse_message_content(unique_ptr<MessageContent> &content, LogEventParser &parser) {
  parse(content, parser);
}

InlineMessageContent create_inline_message_content(Td *td, FileId file_id,
                                                   tl_object_ptr<telegram_api::BotInlineMessage> &&bot_inline_message,
                                                   int32 allowed_media_content_id, Photo *photo, Game *game) {
  CHECK(bot_inline_message != nullptr);
  CHECK((allowed_media_content_id == td_api::inputMessagePhoto::ID) == (photo != nullptr));
  CHECK((allowed_media_content_id == td_api::inputMessageGame::ID) == (game != nullptr));
  CHECK((allowed_media_content_id != td_api::inputMessagePhoto::ID &&
         allowed_media_content_id != td_api::inputMessageGame::ID && allowed_media_content_id != -1) ==
        file_id.is_valid());

  InlineMessageContent result;
  tl_object_ptr<telegram_api::ReplyMarkup> reply_markup;
  result.disable_web_page_preview = false;
  result.invert_media = false;
  switch (bot_inline_message->get_id()) {
    case telegram_api::botInlineMessageText::ID: {
      auto inline_message = telegram_api::move_object_as<telegram_api::botInlineMessageText>(bot_inline_message);
      auto text = get_formatted_text(td->user_manager_.get(), std::move(inline_message->message_),
                                     std::move(inline_message->entities_), false, false, "botInlineMessageText");
      result.disable_web_page_preview = inline_message->no_webpage_;
      result.invert_media = inline_message->invert_media_;
      WebPageId web_page_id;
      if (!result.disable_web_page_preview) {
        web_page_id = td->web_pages_manager_->get_web_page_by_url(get_first_url(text).str());
      }
      result.message_content =
          td::make_unique<MessageText>(std::move(text), web_page_id, false, false, false, string());
      reply_markup = std::move(inline_message->reply_markup_);
      break;
    }
    case telegram_api::botInlineMessageMediaWebPage::ID: {
      auto inline_message =
          telegram_api::move_object_as<telegram_api::botInlineMessageMediaWebPage>(bot_inline_message);
      string web_page_url;
      if (inline_message->manual_) {
        web_page_url = std::move(inline_message->url_);
      }
      auto text =
          get_formatted_text(td->user_manager_.get(), std::move(inline_message->message_),
                             std::move(inline_message->entities_), false, false, "botInlineMessageMediaWebPage");
      auto web_page_id =
          td->web_pages_manager_->get_web_page_by_url(web_page_url.empty() ? get_first_url(text).str() : web_page_url);
      result.message_content = td::make_unique<MessageText>(
          std::move(text), web_page_id, inline_message->force_small_media_, inline_message->force_large_media_,
          inline_message->safe_, std::move(web_page_url));
      reply_markup = std::move(inline_message->reply_markup_);
      result.invert_media = inline_message->invert_media_;
      break;
    }
    case telegram_api::botInlineMessageMediaInvoice::ID: {
      auto inline_message =
          telegram_api::move_object_as<telegram_api::botInlineMessageMediaInvoice>(bot_inline_message);
      reply_markup = std::move(inline_message->reply_markup_);
      result.message_content = make_unique<MessageInvoice>(InputInvoice(std::move(inline_message), td, DialogId()));
      break;
    }
    case telegram_api::botInlineMessageMediaGeo::ID: {
      auto inline_message = telegram_api::move_object_as<telegram_api::botInlineMessageMediaGeo>(bot_inline_message);
      if (inline_message->period_ > 0) {
        result.message_content =
            make_unique<MessageLiveLocation>(Location(td, inline_message->geo_), inline_message->period_,
                                             inline_message->heading_, inline_message->proximity_notification_radius_);
      } else {
        result.message_content = make_unique<MessageLocation>(Location(td, inline_message->geo_));
      }
      reply_markup = std::move(inline_message->reply_markup_);
      break;
    }
    case telegram_api::botInlineMessageMediaVenue::ID: {
      auto inline_message = telegram_api::move_object_as<telegram_api::botInlineMessageMediaVenue>(bot_inline_message);
      result.message_content = make_unique<MessageVenue>(
          Venue(td, inline_message->geo_, std::move(inline_message->title_), std::move(inline_message->address_),
                std::move(inline_message->provider_), std::move(inline_message->venue_id_),
                std::move(inline_message->venue_type_)));
      reply_markup = std::move(inline_message->reply_markup_);
      break;
    }
    case telegram_api::botInlineMessageMediaContact::ID: {
      auto inline_message =
          telegram_api::move_object_as<telegram_api::botInlineMessageMediaContact>(bot_inline_message);
      result.message_content = make_unique<MessageContact>(
          Contact(std::move(inline_message->phone_number_), std::move(inline_message->first_name_),
                  std::move(inline_message->last_name_), std::move(inline_message->vcard_), UserId()));
      reply_markup = std::move(inline_message->reply_markup_);
      break;
    }
    case telegram_api::botInlineMessageMediaAuto::ID: {
      auto inline_message = telegram_api::move_object_as<telegram_api::botInlineMessageMediaAuto>(bot_inline_message);
      auto caption =
          get_message_text(td->user_manager_.get(), inline_message->message_, std::move(inline_message->entities_),
                           true, false, 0, false, "create_inline_message_content");
      if (allowed_media_content_id == td_api::inputMessageAnimation::ID) {
        result.message_content = make_unique<MessageAnimation>(file_id, std::move(caption), false);
      } else if (allowed_media_content_id == td_api::inputMessageAudio::ID) {
        result.message_content = make_unique<MessageAudio>(file_id, std::move(caption));
      } else if (allowed_media_content_id == td_api::inputMessageDocument::ID) {
        result.message_content = make_unique<MessageDocument>(file_id, std::move(caption));
      } else if (allowed_media_content_id == td_api::inputMessageGame::ID) {
        CHECK(game != nullptr);
        // TODO game->set_short_name(std::move(caption));
        result.message_content = make_unique<MessageGame>(std::move(*game));
      } else if (allowed_media_content_id == td_api::inputMessagePhoto::ID) {
        result.message_content = make_unique<MessagePhoto>(std::move(*photo), std::move(caption), false);
      } else if (allowed_media_content_id == td_api::inputMessageSticker::ID) {
        result.message_content = make_unique<MessageSticker>(file_id, false);
      } else if (allowed_media_content_id == td_api::inputMessageVideo::ID) {
        result.message_content = td::make_unique<MessageVideo>(file_id, vector<FileId>(), vector<FileId>(), Photo(), 0,
                                                               std::move(caption), false);
      } else if (allowed_media_content_id == td_api::inputMessageVoiceNote::ID) {
        result.message_content = make_unique<MessageVoiceNote>(file_id, std::move(caption), true);
      } else {
        LOG(WARNING) << "Unallowed bot inline message " << to_string(inline_message);
      }

      result.invert_media = inline_message->invert_media_;
      reply_markup = std::move(inline_message->reply_markup_);
      break;
    }
    default:
      UNREACHABLE();
  }
  result.message_reply_markup = get_reply_markup(std::move(reply_markup), td->auth_manager_->is_bot(), true, false);
  return result;
}

unique_ptr<MessageContent> create_text_message_content(string text, vector<MessageEntity> entities,
                                                       WebPageId web_page_id, bool force_small_media,
                                                       bool force_large_media, bool skip_confirmation,
                                                       string &&web_page_url) {
  return td::make_unique<MessageText>(FormattedText{std::move(text), std::move(entities)}, web_page_id,
                                      force_small_media, force_large_media, skip_confirmation, std::move(web_page_url));
}

unique_ptr<MessageContent> create_photo_message_content(Photo photo) {
  return make_unique<MessagePhoto>(std::move(photo), FormattedText(), false);
}

unique_ptr<MessageContent> create_video_message_content(FileId file_id, Photo cover, int32 start_timestamp) {
  return td::make_unique<MessageVideo>(file_id, vector<FileId>(), vector<FileId>(), std::move(cover), start_timestamp,
                                       FormattedText(), false);
}

unique_ptr<MessageContent> create_contact_registered_message_content() {
  return make_unique<MessageContactRegistered>();
}

unique_ptr<MessageContent> create_screenshot_taken_message_content() {
  return make_unique<MessageScreenshotTaken>();
}

unique_ptr<MessageContent> create_chat_set_ttl_message_content(int32 ttl, UserId from_user_id) {
  return make_unique<MessageChatSetTtl>(ttl, from_user_id);
}

td_api::object_ptr<td_api::formattedText> extract_input_caption(
    td_api::object_ptr<td_api::InputMessageContent> &input_message_content) {
  switch (input_message_content->get_id()) {
    case td_api::inputMessageAnimation::ID: {
      auto input_animation = static_cast<td_api::inputMessageAnimation *>(input_message_content.get());
      return std::move(input_animation->caption_);
    }
    case td_api::inputMessageAudio::ID: {
      auto input_audio = static_cast<td_api::inputMessageAudio *>(input_message_content.get());
      return std::move(input_audio->caption_);
    }
    case td_api::inputMessageDocument::ID: {
      auto input_document = static_cast<td_api::inputMessageDocument *>(input_message_content.get());
      return std::move(input_document->caption_);
    }
    case td_api::inputMessagePaidMedia::ID: {
      auto input_paid_media = static_cast<td_api::inputMessagePaidMedia *>(input_message_content.get());
      return std::move(input_paid_media->caption_);
    }
    case td_api::inputMessagePhoto::ID: {
      auto input_photo = static_cast<td_api::inputMessagePhoto *>(input_message_content.get());
      return std::move(input_photo->caption_);
    }
    case td_api::inputMessageVideo::ID: {
      auto input_video = static_cast<td_api::inputMessageVideo *>(input_message_content.get());
      return std::move(input_video->caption_);
    }
    case td_api::inputMessageVoiceNote::ID: {
      auto input_voice_note = static_cast<td_api::inputMessageVoiceNote *>(input_message_content.get());
      return std::move(input_voice_note->caption_);
    }
    default:
      return nullptr;
  }
}

bool extract_input_invert_media(const td_api::object_ptr<td_api::InputMessageContent> &input_message_content) {
  switch (input_message_content->get_id()) {
    case td_api::inputMessageAnimation::ID: {
      auto input_animation = static_cast<const td_api::inputMessageAnimation *>(input_message_content.get());
      return input_animation->show_caption_above_media_;
    }
    case td_api::inputMessagePaidMedia::ID: {
      auto input_paid_media = static_cast<const td_api::inputMessagePaidMedia *>(input_message_content.get());
      return input_paid_media->show_caption_above_media_;
    }
    case td_api::inputMessagePhoto::ID: {
      auto input_photo = static_cast<const td_api::inputMessagePhoto *>(input_message_content.get());
      return input_photo->show_caption_above_media_;
    }
    case td_api::inputMessageVideo::ID: {
      auto input_video = static_cast<const td_api::inputMessageVideo *>(input_message_content.get());
      return input_video->show_caption_above_media_;
    }
    default:
      return false;
  }
}

static Result<InputMessageContent> create_input_message_content(
    DialogId dialog_id, tl_object_ptr<td_api::InputMessageContent> &&input_message_content, Td *td,
    FormattedText caption, FileId file_id, PhotoSize thumbnail, vector<FileId> sticker_file_ids, bool is_premium) {
  CHECK(input_message_content != nullptr);
  LOG(INFO) << "Create InputMessageContent with file " << file_id << " and thumbnail " << thumbnail.file_id;

  FileView file_view;
  string file_name;
  string mime_type;
  if (file_id.is_valid()) {
    file_view = td->file_manager_->get_file_view(file_id);
    auto suggested_path = file_view.suggested_path();
    const PathView path_view(suggested_path);
    file_name = path_view.file_name().str();
    mime_type = MimeType::from_extension(path_view.extension());
  }

  bool disable_web_page_preview = false;
  bool invert_media = false;
  bool clear_draft = false;
  unique_ptr<MessageContent> content;
  UserId via_bot_user_id;
  td_api::object_ptr<td_api::MessageSelfDestructType> self_destruct_type;
  string emoji;
  bool is_bot = td->auth_manager_->is_bot();
  bool is_secret = dialog_id.get_type() == DialogType::SecretChat;
  switch (input_message_content->get_id()) {
    case td_api::inputMessageText::ID: {
      TRY_RESULT(input_message_text,
                 process_input_message_text(td, dialog_id, std::move(input_message_content), is_bot));
      auto web_page_url = std::move(input_message_text.web_page_url);
      disable_web_page_preview = input_message_text.disable_web_page_preview;
      invert_media = input_message_text.show_above_text;
      clear_draft = input_message_text.clear_draft;

      if (is_bot && static_cast<int64>(utf8_length(input_message_text.text.text)) >
                        G()->get_option_integer("message_text_length_max")) {
        return Status::Error(400, "Message is too long");
      }

      WebPageId web_page_id;
      bool can_add_web_page_previews =
          dialog_id.get_type() != DialogType::Channel ||
          td->chat_manager_->get_channel_permissions(dialog_id.get_channel_id()).can_add_web_page_previews();
      if (!is_bot && !disable_web_page_preview && can_add_web_page_previews) {
        web_page_id = td->web_pages_manager_->get_web_page_by_url(
            web_page_url.empty() ? get_first_url(input_message_text.text).str() : web_page_url);
      }
      content = td::make_unique<MessageText>(std::move(input_message_text.text), web_page_id,
                                             input_message_text.force_small_media, input_message_text.force_large_media,
                                             false, std::move(web_page_url));
      break;
    }
    case td_api::inputMessageAnimation::ID: {
      auto input_animation = static_cast<td_api::inputMessageAnimation *>(input_message_content.get());

      invert_media = input_animation->show_caption_above_media_ && !is_secret;

      bool has_stickers = !sticker_file_ids.empty();
      td->animations_manager_->create_animation(
          file_id, string(), std::move(thumbnail), AnimationSize(), has_stickers, std::move(sticker_file_ids),
          std::move(file_name), std::move(mime_type), input_animation->duration_,
          get_dimensions(input_animation->width_, input_animation->height_, nullptr), false);

      content = make_unique<MessageAnimation>(file_id, std::move(caption), input_animation->has_spoiler_ && !is_secret);
      break;
    }
    case td_api::inputMessageAudio::ID: {
      auto input_audio = static_cast<td_api::inputMessageAudio *>(input_message_content.get());

      if (!clean_input_string(input_audio->title_)) {
        return Status::Error(400, "Audio title must be encoded in UTF-8");
      }
      if (!clean_input_string(input_audio->performer_)) {
        return Status::Error(400, "Audio performer must be encoded in UTF-8");
      }

      td->audios_manager_->create_audio(file_id, string(), std::move(thumbnail), std::move(file_name),
                                        std::move(mime_type), input_audio->duration_, std::move(input_audio->title_),
                                        std::move(input_audio->performer_), 0, false);

      content = make_unique<MessageAudio>(file_id, std::move(caption));
      break;
    }
    case td_api::inputMessageDice::ID: {
      auto input_dice = static_cast<td_api::inputMessageDice *>(input_message_content.get());
      if (!clean_input_string(input_dice->emoji_)) {
        return Status::Error(400, "Dice emoji must be encoded in UTF-8");
      }
      content = td::make_unique<MessageDice>(input_dice->emoji_, 0);
      clear_draft = input_dice->clear_draft_;
      break;
    }
    case td_api::inputMessageDocument::ID:
      td->documents_manager_->create_document(file_id, string(), std::move(thumbnail), std::move(file_name),
                                              std::move(mime_type), false);

      content = make_unique<MessageDocument>(file_id, std::move(caption));
      break;
    case td_api::inputMessagePaidMedia::ID: {
      auto input_paid_media = static_cast<td_api::inputMessagePaidMedia *>(input_message_content.get());

      invert_media = input_paid_media->show_caption_above_media_ && !is_secret;

      if (input_paid_media->star_count_ <= 0 ||
          input_paid_media->star_count_ >
              td->option_manager_->get_option_integer("paid_media_message_star_count_max")) {
        return Status::Error(400, "Invalid media price specified");
      }
      vector<MessageExtendedMedia> extended_media;
      for (auto &paid_media : input_paid_media->paid_media_) {
        TRY_RESULT(media, MessageExtendedMedia::get_message_extended_media(td, std::move(paid_media), dialog_id));
        if (media.is_empty()) {
          return Status::Error(400, "Paid media must be non-empty");
        }
        extended_media.push_back(std::move(media));
      }
      static constexpr size_t MAX_PAID_MEDIA = 10;  // server side limit
      if (extended_media.empty() || extended_media.size() > MAX_PAID_MEDIA) {
        return Status::Error(400, "Invalid number of paid media specified");
      }

      content = td::make_unique<MessagePaidMedia>(std::move(extended_media), std::move(caption),
                                                  input_paid_media->star_count_, std::move(input_paid_media->payload_));
      break;
    }
    case td_api::inputMessagePhoto::ID: {
      auto input_photo = static_cast<td_api::inputMessagePhoto *>(input_message_content.get());

      invert_media = input_photo->show_caption_above_media_ && !is_secret;
      self_destruct_type = std::move(input_photo->self_destruct_type_);

      TRY_RESULT(photo, create_photo(td->file_manager_.get(), file_id, std::move(thumbnail), input_photo->width_,
                                     input_photo->height_, std::move(sticker_file_ids)));

      content =
          make_unique<MessagePhoto>(std::move(photo), std::move(caption), input_photo->has_spoiler_ && !is_secret);
      break;
    }
    case td_api::inputMessageSticker::ID: {
      auto input_sticker = static_cast<td_api::inputMessageSticker *>(input_message_content.get());

      emoji = std::move(input_sticker->emoji_);

      td->stickers_manager_->create_sticker(file_id, FileId(), string(), std::move(thumbnail),
                                            get_dimensions(input_sticker->width_, input_sticker->height_, nullptr),
                                            nullptr, nullptr, StickerFormat::Unknown, nullptr);

      content = make_unique<MessageSticker>(file_id, is_premium);
      break;
    }
    case td_api::inputMessageVideo::ID: {
      auto input_video = static_cast<td_api::inputMessageVideo *>(input_message_content.get());

      invert_media = input_video->show_caption_above_media_ && !is_secret;
      self_destruct_type = std::move(input_video->self_destruct_type_);

      Photo cover;
      if (!is_secret && self_destruct_type == nullptr) {
        TRY_RESULT(cover_file_id, td->file_manager_->get_input_file_id(FileType::Photo, input_video->cover_, dialog_id,
                                                                       true, is_secret, false));
        if (cover_file_id.is_valid()) {
          TRY_RESULT_ASSIGN(cover, create_photo(td->file_manager_.get(), cover_file_id, PhotoSize(),
                                                input_video->width_, input_video->height_, Auto()));
        }
      }

      bool has_stickers = !sticker_file_ids.empty();
      td->videos_manager_->create_video(file_id, string(), std::move(thumbnail), AnimationSize(), has_stickers,
                                        std::move(sticker_file_ids), std::move(file_name), std::move(mime_type),
                                        input_video->duration_, input_video->duration_,
                                        get_dimensions(input_video->width_, input_video->height_, nullptr),
                                        input_video->supports_streaming_, false, 0, 0.0, string(), false);

      content = td::make_unique<MessageVideo>(file_id, vector<FileId>(), vector<FileId>(), std::move(cover),
                                              max(0, input_video->start_timestamp_), std::move(caption),
                                              input_video->has_spoiler_ && !is_secret);
      break;
    }
    case td_api::inputMessageVideoNote::ID: {
      auto input_video_note = static_cast<td_api::inputMessageVideoNote *>(input_message_content.get());
      self_destruct_type = std::move(input_video_note->self_destruct_type_);

      auto length = input_video_note->length_;
      if (length < 0 || length > 640) {
        return Status::Error(400, "Wrong video note length");
      }

      td->video_notes_manager_->create_video_note(file_id, string(), std::move(thumbnail), input_video_note->duration_,
                                                  get_dimensions(length, length, nullptr), string(), false);

      content = make_unique<MessageVideoNote>(file_id, false);
      break;
    }
    case td_api::inputMessageVoiceNote::ID: {
      auto input_voice_note = static_cast<td_api::inputMessageVoiceNote *>(input_message_content.get());
      self_destruct_type = std::move(input_voice_note->self_destruct_type_);

      td->voice_notes_manager_->create_voice_note(file_id, std::move(mime_type), input_voice_note->duration_,
                                                  std::move(input_voice_note->waveform_), false);

      content = make_unique<MessageVoiceNote>(file_id, std::move(caption), false);
      break;
    }
    case td_api::inputMessageLocation::ID: {
      TRY_RESULT(location, process_input_message_location(std::move(input_message_content)));
      if (location.live_period == 0) {
        content = make_unique<MessageLocation>(std::move(location.location));
      } else {
        content = make_unique<MessageLiveLocation>(std::move(location.location), location.live_period, location.heading,
                                                   location.proximity_alert_radius);
      }
      break;
    }
    case td_api::inputMessageVenue::ID: {
      TRY_RESULT(venue, process_input_message_venue(std::move(input_message_content)));
      content = make_unique<MessageVenue>(std::move(venue));
      break;
    }
    case td_api::inputMessageContact::ID: {
      TRY_RESULT(contact, process_input_message_contact(td, std::move(input_message_content)));
      content = make_unique<MessageContact>(std::move(contact));
      break;
    }
    case td_api::inputMessageGame::ID: {
      TRY_RESULT(game, process_input_message_game(td->user_manager_.get(), std::move(input_message_content)));
      via_bot_user_id = game.get_bot_user_id();
      if (via_bot_user_id == td->user_manager_->get_my_id()) {
        via_bot_user_id = UserId();
      }

      content = make_unique<MessageGame>(std::move(game));
      break;
    }
    case td_api::inputMessageInvoice::ID: {
      if (!is_bot) {
        return Status::Error(400, "Invoices can be sent only by bots");
      }

      TRY_RESULT(input_invoice,
                 InputInvoice::process_input_message_invoice(std::move(input_message_content), td, dialog_id));
      content = make_unique<MessageInvoice>(std::move(input_invoice));
      break;
    }
    case td_api::inputMessagePoll::ID: {
      const size_t MAX_POLL_QUESTION_LENGTH = is_bot ? 300 : 255;  // server-side limit
      constexpr size_t MAX_POLL_OPTION_LENGTH = 100;               // server-side limit
      constexpr size_t MAX_POLL_OPTIONS = 10;                      // server-side limit
      auto input_poll = static_cast<td_api::inputMessagePoll *>(input_message_content.get());
      TRY_RESULT(question,
                 get_formatted_text(td, dialog_id, std::move(input_poll->question_), is_bot, false, true, false));
      if (utf8_length(question.text) > MAX_POLL_QUESTION_LENGTH) {
        return Status::Error(400, PSLICE() << "Poll question length must not exceed " << MAX_POLL_QUESTION_LENGTH);
      }
      if (input_poll->options_.size() <= 1) {
        return Status::Error(400, "Poll must have at least 2 option");
      }
      if (input_poll->options_.size() > MAX_POLL_OPTIONS) {
        return Status::Error(400, PSLICE() << "Poll can't have more than " << MAX_POLL_OPTIONS << " options");
      }
      vector<FormattedText> options;
      for (auto &input_option : input_poll->options_) {
        TRY_RESULT(option, get_formatted_text(td, dialog_id, std::move(input_option), is_bot, false, true, false));
        if (utf8_length(option.text) > MAX_POLL_OPTION_LENGTH) {
          return Status::Error(400, PSLICE() << "Poll options length must not exceed " << MAX_POLL_OPTION_LENGTH);
        }
        options.push_back(std::move(option));
      }

      bool allow_multiple_answers = false;
      bool is_quiz = false;
      int32 correct_option_id = -1;
      FormattedText explanation;
      if (input_poll->type_ == nullptr) {
        return Status::Error(400, "Poll type must be non-empty");
      }
      switch (input_poll->type_->get_id()) {
        case td_api::pollTypeRegular::ID: {
          auto type = td_api::move_object_as<td_api::pollTypeRegular>(input_poll->type_);
          allow_multiple_answers = type->allow_multiple_answers_;
          break;
        }
        case td_api::pollTypeQuiz::ID: {
          auto type = td_api::move_object_as<td_api::pollTypeQuiz>(input_poll->type_);
          is_quiz = true;
          correct_option_id = type->correct_option_id_;
          if (correct_option_id < 0 || correct_option_id >= static_cast<int32>(input_poll->options_.size())) {
            return Status::Error(400, "Wrong correct option ID specified");
          }
          TRY_RESULT_ASSIGN(
              explanation, get_formatted_text(td, dialog_id, std::move(type->explanation_), is_bot, true, true, false));
          break;
        }
        default:
          UNREACHABLE();
      }

      int32 open_period = is_bot ? input_poll->open_period_ : 0;
      int32 close_date = is_bot ? input_poll->close_date_ : 0;
      if (open_period != 0) {
        close_date = 0;
      }
      bool is_closed = is_bot ? input_poll->is_closed_ : false;
      content = make_unique<MessagePoll>(td->poll_manager_->create_poll(
          std::move(question), std::move(options), input_poll->is_anonymous_, allow_multiple_answers, is_quiz,
          correct_option_id, std::move(explanation), open_period, close_date, is_closed));
      break;
    }
    case td_api::inputMessageStory::ID: {
      auto input_story = static_cast<td_api::inputMessageStory *>(input_message_content.get());
      DialogId story_sender_dialog_id(input_story->story_sender_chat_id_);
      StoryId story_id(input_story->story_id_);
      StoryFullId story_full_id(story_sender_dialog_id, story_id);
      if (!td->story_manager_->have_story_force(story_full_id)) {
        return Status::Error(400, "Story not found");
      }
      if (!story_id.is_server()) {
        return Status::Error(400, "Story can't be forwarded");
      }
      if (td->dialog_manager_->get_input_peer(story_sender_dialog_id, AccessRights::Read) == nullptr) {
        return Status::Error(400, "Can't access the story");
      }
      content = make_unique<MessageStory>(story_full_id, false);
      break;
    }
    default:
      UNREACHABLE();
  }

  TRY_RESULT(ttl, MessageSelfDestructType::get_message_self_destruct_type(std::move(self_destruct_type)));
  if (!ttl.is_empty() && dialog_id.get_type() != DialogType::User) {
    return Status::Error(400, "Messages can self-destruct only in private chats");
  }

  return InputMessageContent{std::move(content), disable_web_page_preview, invert_media, clear_draft, ttl,
                             via_bot_user_id,    std::move(emoji)};
}

Result<InputMessageContent> get_input_message_content(
    DialogId dialog_id, tl_object_ptr<td_api::InputMessageContent> &&input_message_content, Td *td, bool is_premium) {
  if (input_message_content == nullptr) {
    return Status::Error(400, "Input message content must be non-empty");
  }

  td_api::object_ptr<td_api::InputFile> input_file;
  auto file_type = FileType::None;
  auto allow_get_by_hash = false;
  td_api::object_ptr<td_api::inputThumbnail> input_thumbnail;
  vector<FileId> sticker_file_ids;
  switch (input_message_content->get_id()) {
    case td_api::inputMessageAnimation::ID: {
      auto input_message = static_cast<td_api::inputMessageAnimation *>(input_message_content.get());
      file_type = FileType::Animation;
      input_file = std::move(input_message->animation_);
      allow_get_by_hash = true;
      input_thumbnail = std::move(input_message->thumbnail_);
      if (!input_message->added_sticker_file_ids_.empty()) {
        sticker_file_ids = td->stickers_manager_->get_attached_sticker_file_ids(input_message->added_sticker_file_ids_);
      }
      break;
    }
    case td_api::inputMessageAudio::ID: {
      auto input_message = static_cast<td_api::inputMessageAudio *>(input_message_content.get());
      file_type = FileType::Audio;
      input_file = std::move(input_message->audio_);
      input_thumbnail = std::move(input_message->album_cover_thumbnail_);
      break;
    }
    case td_api::inputMessageDocument::ID: {
      auto input_message = static_cast<td_api::inputMessageDocument *>(input_message_content.get());
      file_type = input_message->disable_content_type_detection_ ? FileType::DocumentAsFile : FileType::Document;
      input_file = std::move(input_message->document_);
      allow_get_by_hash = true;
      input_thumbnail = std::move(input_message->thumbnail_);
      break;
    }
    case td_api::inputMessagePhoto::ID: {
      auto input_message = static_cast<td_api::inputMessagePhoto *>(input_message_content.get());
      file_type = input_message->self_destruct_type_ != nullptr ? FileType::SelfDestructingPhoto : FileType::Photo;
      input_file = std::move(input_message->photo_);
      input_thumbnail = std::move(input_message->thumbnail_);
      if (!input_message->added_sticker_file_ids_.empty()) {
        sticker_file_ids = td->stickers_manager_->get_attached_sticker_file_ids(input_message->added_sticker_file_ids_);
      }
      break;
    }
    case td_api::inputMessageSticker::ID: {
      auto input_message = static_cast<td_api::inputMessageSticker *>(input_message_content.get());
      file_type = FileType::Sticker;
      input_file = std::move(input_message->sticker_);
      input_thumbnail = std::move(input_message->thumbnail_);
      break;
    }
    case td_api::inputMessageVideo::ID: {
      auto input_message = static_cast<td_api::inputMessageVideo *>(input_message_content.get());
      file_type = input_message->self_destruct_type_ != nullptr ? FileType::SelfDestructingVideoNote : FileType::Video;
      input_file = std::move(input_message->video_);
      input_thumbnail = std::move(input_message->thumbnail_);
      if (!input_message->added_sticker_file_ids_.empty()) {
        sticker_file_ids = td->stickers_manager_->get_attached_sticker_file_ids(input_message->added_sticker_file_ids_);
      }
      break;
    }
    case td_api::inputMessageVideoNote::ID: {
      auto input_message = static_cast<td_api::inputMessageVideoNote *>(input_message_content.get());
      file_type =
          input_message->self_destruct_type_ != nullptr ? FileType::SelfDestructingVideoNote : FileType::VideoNote;
      input_file = std::move(input_message->video_note_);
      input_thumbnail = std::move(input_message->thumbnail_);
      break;
    }
    case td_api::inputMessageVoiceNote::ID: {
      auto input_message = static_cast<td_api::inputMessageVoiceNote *>(input_message_content.get());
      file_type =
          input_message->self_destruct_type_ != nullptr ? FileType::SelfDestructingVoiceNote : FileType::VoiceNote;
      input_file = std::move(input_message->voice_note_);
      break;
    }
    default:
      break;
  }
  // TODO path of files must be stored in bytes instead of UTF-8 string

  bool is_secret = dialog_id.get_type() == DialogType::SecretChat;

  FileId file_id;
  if (file_type != FileType::None) {
    TRY_RESULT_ASSIGN(file_id, td->file_manager_->get_input_file_id(file_type, input_file, dialog_id, false, is_secret,
                                                                    allow_get_by_hash));
    CHECK(file_id.is_valid());
  }

  bool is_bot = td->auth_manager_->is_bot();
  TRY_RESULT(caption, get_formatted_text(td, dialog_id, extract_input_caption(input_message_content), is_bot, true,
                                         false, false));
  if (is_bot && static_cast<int64>(utf8_length(caption.text)) > G()->get_option_integer("message_caption_length_max")) {
    return Status::Error(400, "Message caption is too long");
  }
  return create_input_message_content(
      dialog_id, std::move(input_message_content), td, std::move(caption), file_id,
      get_input_thumbnail_photo_size(td->file_manager_.get(), input_thumbnail.get(), dialog_id, is_secret),
      std::move(sticker_file_ids), is_premium);
}

Status check_message_group_message_contents(const vector<InputMessageContent> &message_contents) {
  static constexpr size_t MAX_GROUPED_MESSAGES = 10;  // server side limit
  if (message_contents.size() > MAX_GROUPED_MESSAGES) {
    return Status::Error(400, "Too many messages to send as an album");
  }
  if (message_contents.empty()) {
    return Status::Error(400, "There are no messages to send");
  }

  std::unordered_set<MessageContentType, MessageContentTypeHash> message_content_types;
  for (const auto &message_content : message_contents) {
    auto message_content_type = message_content.content->get_type();
    if (!is_allowed_media_group_content(message_content_type)) {
      return Status::Error(400, "Invalid message content type");
    }
    if (message_content.invert_media != message_contents[0].invert_media) {
      return Status::Error(400, "Parameter show_caption_above_media must be the same for all messages");
    }
    message_content_types.insert(message_content_type);
  }
  if (message_content_types.size() > 1) {
    for (auto message_content_type : message_content_types) {
      if (is_homogenous_media_group_content(message_content_type)) {
        return Status::Error(400, PSLICE() << message_content_type << " can't be mixed with other media types");
      }
    }
  }
  return Status::OK();
}

bool can_message_content_have_input_media(const Td *td, const MessageContent *content, bool is_server) {
  switch (content->get_type()) {
    case MessageContentType::Game:
      return is_server || static_cast<const MessageGame *>(content)->game.has_input_media();
    case MessageContentType::Poll:
      return td->poll_manager_->has_input_media(static_cast<const MessagePoll *>(content)->poll_id);
    case MessageContentType::Story: {
      auto story_full_id = static_cast<const MessageStory *>(content)->story_full_id;
      auto dialog_id = story_full_id.get_dialog_id();
      return td->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read) != nullptr;
    }
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayWinners:
      return is_server;
    case MessageContentType::PaidMedia:
      if (is_server) {
        return true;
      }
      for (const auto &media : static_cast<const MessagePaidMedia *>(content)->media) {
        if (!media.has_input_media()) {
          return false;
        }
      }
      return true;
    case MessageContentType::Unsupported:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      return false;
    case MessageContentType::Animation:
    case MessageContentType::Audio:
    case MessageContentType::Contact:
    case MessageContentType::Dice:
    case MessageContentType::Document:
    case MessageContentType::Invoice:
    case MessageContentType::LiveLocation:
    case MessageContentType::Location:
    case MessageContentType::Photo:
    case MessageContentType::Sticker:
    case MessageContentType::Text:
    case MessageContentType::Venue:
    case MessageContentType::Video:
    case MessageContentType::VideoNote:
    case MessageContentType::VoiceNote:
      return true;
    default:
      UNREACHABLE();
  }
}

SecretInputMedia get_message_content_secret_input_media(
    const MessageContent *content, Td *td, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
    BufferSlice thumbnail, int32 layer) {
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      const auto *m = static_cast<const MessageAnimation *>(content);
      return td->animations_manager_->get_secret_input_media(m->file_id, std::move(input_file), m->caption.text,
                                                             std::move(thumbnail), layer);
    }
    case MessageContentType::Audio: {
      const auto *m = static_cast<const MessageAudio *>(content);
      return td->audios_manager_->get_secret_input_media(m->file_id, std::move(input_file), m->caption.text,
                                                         std::move(thumbnail), layer);
    }
    case MessageContentType::Contact: {
      const auto *m = static_cast<const MessageContact *>(content);
      return m->contact.get_secret_input_media_contact();
    }
    case MessageContentType::Document: {
      const auto *m = static_cast<const MessageDocument *>(content);
      return td->documents_manager_->get_secret_input_media(m->file_id, std::move(input_file), m->caption.text,
                                                            std::move(thumbnail), layer);
    }
    case MessageContentType::Location: {
      const auto *m = static_cast<const MessageLocation *>(content);
      return m->location.get_secret_input_media_geo_point();
    }
    case MessageContentType::Photo: {
      const auto *m = static_cast<const MessagePhoto *>(content);
      return photo_get_secret_input_media(td->file_manager_.get(), m->photo, std::move(input_file), m->caption.text,
                                          std::move(thumbnail));
    }
    case MessageContentType::Sticker: {
      const auto *m = static_cast<const MessageSticker *>(content);
      return td->stickers_manager_->get_secret_input_media(m->file_id, std::move(input_file), std::move(thumbnail),
                                                           layer);
    }
    case MessageContentType::Text: {
      CHECK(input_file == nullptr);
      CHECK(thumbnail.empty());
      const auto *m = static_cast<const MessageText *>(content);
      if (m->web_page_url.empty()) {
        return SecretInputMedia{};
      }
      return SecretInputMedia{nullptr, make_tl_object<secret_api::decryptedMessageMediaWebPage>(m->web_page_url)};
    }
    case MessageContentType::Venue: {
      const auto *m = static_cast<const MessageVenue *>(content);
      return m->venue.get_secret_input_media_venue();
    }
    case MessageContentType::Video: {
      const auto *m = static_cast<const MessageVideo *>(content);
      return td->videos_manager_->get_secret_input_media(m->file_id, std::move(input_file), m->caption.text,
                                                         std::move(thumbnail), layer);
    }
    case MessageContentType::VideoNote: {
      const auto *m = static_cast<const MessageVideoNote *>(content);
      return td->video_notes_manager_->get_secret_input_media(m->file_id, std::move(input_file), std::move(thumbnail),
                                                              layer);
    }
    case MessageContentType::VoiceNote: {
      const auto *m = static_cast<const MessageVoiceNote *>(content);
      return td->voice_notes_manager_->get_secret_input_media(m->file_id, std::move(input_file), m->caption.text,
                                                              layer);
    }
    case MessageContentType::Call:
    case MessageContentType::Dice:
    case MessageContentType::Game:
    case MessageContentType::Invoice:
    case MessageContentType::LiveLocation:
    case MessageContentType::Poll:
    case MessageContentType::Story:
    case MessageContentType::Unsupported:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaidMedia:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      break;
    default:
      UNREACHABLE();
  }
  return SecretInputMedia{};
}

static telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media_impl(
    const MessageContent *content, int32 media_pos, Td *td,
    telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, MessageSelfDestructType ttl,
    const string &emoji) {
  if (!can_message_content_have_input_media(td, content, false)) {
    return nullptr;
  }
  if (media_pos >= 0) {
    CHECK(content->get_type() == MessageContentType::PaidMedia);
  }
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      const auto *m = static_cast<const MessageAnimation *>(content);
      return td->animations_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail),
                                                      m->has_spoiler);
    }
    case MessageContentType::Audio: {
      const auto *m = static_cast<const MessageAudio *>(content);
      return td->audios_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail));
    }
    case MessageContentType::Contact: {
      const auto *m = static_cast<const MessageContact *>(content);
      return m->contact.get_input_media_contact();
    }
    case MessageContentType::Dice: {
      const auto *m = static_cast<const MessageDice *>(content);
      return make_tl_object<telegram_api::inputMediaDice>(m->emoji);
    }
    case MessageContentType::Document: {
      const auto *m = static_cast<const MessageDocument *>(content);
      return td->documents_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail));
    }
    case MessageContentType::Game: {
      const auto *m = static_cast<const MessageGame *>(content);
      return m->game.get_input_media_game(td);
    }
    case MessageContentType::Invoice: {
      const auto *m = static_cast<const MessageInvoice *>(content);
      return m->input_invoice.get_input_media_invoice(td, std::move(input_file), std::move(input_thumbnail));
    }
    case MessageContentType::LiveLocation: {
      const auto *m = static_cast<const MessageLiveLocation *>(content);
      int32 flags = telegram_api::inputMediaGeoLive::PERIOD_MASK;
      if (m->heading != 0) {
        flags |= telegram_api::inputMediaGeoLive::HEADING_MASK;
      }
      flags |= telegram_api::inputMediaGeoLive::PROXIMITY_NOTIFICATION_RADIUS_MASK;
      return make_tl_object<telegram_api::inputMediaGeoLive>(flags, false, m->location.get_input_geo_point(),
                                                             m->heading, m->period, m->proximity_alert_radius);
    }
    case MessageContentType::Location: {
      const auto *m = static_cast<const MessageLocation *>(content);
      return m->location.get_input_media_geo_point();
    }
    case MessageContentType::PaidMedia: {
      const auto *m = static_cast<const MessagePaidMedia *>(content);
      if (media_pos >= 0) {
        CHECK(static_cast<size_t>(media_pos) < m->media.size());
        return m->media[media_pos].get_input_media(td, std::move(input_file), std::move(input_thumbnail));
      }
      CHECK(m->media.size() == 1u || (input_file == nullptr && input_thumbnail == nullptr));
      vector<telegram_api::object_ptr<telegram_api::InputMedia>> input_media;
      for (auto &extended_media : m->media) {
        auto media = extended_media.get_input_media(td, std::move(input_file), std::move(input_thumbnail));
        if (media == nullptr) {
          return nullptr;
        }
        input_media.push_back(std::move(media));
      }
      int32 flags = 0;
      if (!m->payload.empty()) {
        flags |= telegram_api::inputMediaPaidMedia::PAYLOAD_MASK;
      }
      return telegram_api::make_object<telegram_api::inputMediaPaidMedia>(flags, m->star_count, std::move(input_media),
                                                                          m->payload);
    }
    case MessageContentType::Photo: {
      const auto *m = static_cast<const MessagePhoto *>(content);
      return photo_get_input_media(td->file_manager_.get(), m->photo, std::move(input_file), ttl.get_input_ttl(),
                                   m->has_spoiler);
    }
    case MessageContentType::Poll: {
      const auto *m = static_cast<const MessagePoll *>(content);
      return td->poll_manager_->get_input_media(m->poll_id);
    }
    case MessageContentType::Sticker: {
      const auto *m = static_cast<const MessageSticker *>(content);
      return td->stickers_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail),
                                                    emoji);
    }
    case MessageContentType::Story: {
      const auto *m = static_cast<const MessageStory *>(content);
      return td->story_manager_->get_input_media(m->story_full_id);
    }
    case MessageContentType::Venue: {
      const auto *m = static_cast<const MessageVenue *>(content);
      return m->venue.get_input_media_venue();
    }
    case MessageContentType::Video: {
      const auto *m = static_cast<const MessageVideo *>(content);
      return td->videos_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail),
                                                  m->cover, m->start_timestamp, ttl.get_input_ttl(), m->has_spoiler);
    }
    case MessageContentType::VideoNote: {
      const auto *m = static_cast<const MessageVideoNote *>(content);
      return td->video_notes_manager_->get_input_media(m->file_id, std::move(input_file), std::move(input_thumbnail),
                                                       ttl.get_input_ttl());
    }
    case MessageContentType::VoiceNote: {
      const auto *m = static_cast<const MessageVoiceNote *>(content);
      return td->voice_notes_manager_->get_input_media(m->file_id, std::move(input_file), ttl.get_input_ttl());
    }
    case MessageContentType::Text:
    case MessageContentType::Unsupported:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      break;
    default:
      UNREACHABLE();
  }
  return nullptr;
}

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media(
    const MessageContent *content, int32 media_pos, Td *td,
    telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, FileUploadId file_upload_id,
    FileUploadId thumbnail_file_upload_id, MessageSelfDestructType ttl, const string &emoji, bool force) {
  bool had_input_file = input_file != nullptr;
  bool had_input_thumbnail = input_thumbnail != nullptr;
  auto input_media = get_message_content_input_media_impl(content, media_pos, td, std::move(input_file),
                                                          std::move(input_thumbnail), ttl, emoji);
  auto was_uploaded = FileManager::extract_was_uploaded(input_media);
  if (had_input_file) {
    if (!was_uploaded) {
      // if we had InputFile, but has failed to use it, then we need to immediately cancel file upload
      // so the next upload with the same file can succeed
      CHECK(file_upload_id.is_valid());
      td->file_manager_->cancel_upload(file_upload_id);
      if (had_input_thumbnail) {
        CHECK(thumbnail_file_upload_id.is_valid());
        td->file_manager_->cancel_upload(thumbnail_file_upload_id);
      }
    }
  } else {
    CHECK(!had_input_thumbnail);
  }
  if (!was_uploaded) {
    auto file_references = FileManager::extract_file_references(input_media);
    for (auto &file_reference : file_references) {
      if (file_reference == FileReferenceView::invalid_file_reference()) {
        if (!force) {
          LOG(INFO) << "Have invalid file reference for " << file_upload_id;
          return nullptr;
        }
        LOG(ERROR) << "Have invalid file reference for " << file_upload_id << ", but we are forced to use it";
      }
    }
  }
  return input_media;
}

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media(const MessageContent *content,
                                                                                   Td *td, MessageSelfDestructType ttl,
                                                                                   const string &emoji, bool force,
                                                                                   int32 media_pos) {
  auto input_media = get_message_content_input_media_impl(content, media_pos, td, nullptr, nullptr, ttl, emoji);
  auto file_references = FileManager::extract_file_references(input_media);
  for (size_t i = 0; i < file_references.size(); i++) {
    if (file_references[i] == FileReferenceView::invalid_file_reference()) {
      auto file_ids = get_message_content_any_file_ids(content);
      CHECK(file_ids.size() == file_references.size());
      auto file_id = file_ids[i];
      if (!force) {
        LOG(INFO) << "File " << file_id << " has invalid file reference";
        return nullptr;
      }
      LOG(ERROR) << "File " << file_id << " has invalid file reference, but we are forced to use it";
    }
  }
  return input_media;
}

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_fake_input_media(
    Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file, FileId file_id) {
  FileView file_view = td->file_manager_->get_file_view(file_id);
  auto file_type = file_view.get_type();
  if (is_document_file_type(file_type)) {
    vector<telegram_api::object_ptr<telegram_api::DocumentAttribute>> attributes;
    auto file_path = file_view.suggested_path();
    const PathView path_view(file_path);
    Slice file_name = path_view.file_name();
    if (!file_name.empty()) {
      attributes.push_back(telegram_api::make_object<telegram_api::documentAttributeFilename>(file_name.str()));
    }
    string mime_type = MimeType::from_extension(path_view.extension());
    auto nosound_video = (file_type == FileType::Video || file_type == FileType::VideoStory ||
                          file_type == FileType::SelfDestructingVideo);
    auto force_file = (file_type == FileType::DocumentAsFile);
    return telegram_api::make_object<telegram_api::inputMediaUploadedDocument>(
        0, nosound_video, force_file, false, std::move(input_file), nullptr, mime_type, std::move(attributes),
        vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), nullptr, 0, 0);
  } else {
    CHECK(file_type == FileType::Photo || file_type == FileType::PhotoStory ||
          file_type == FileType::SelfDestructingPhoto);
    return telegram_api::make_object<telegram_api::inputMediaUploadedPhoto>(
        0, false, std::move(input_file), vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), 0);
  }
}

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media_web_page(
    const Td *td, const MessageContent *content) {
  CHECK(content != nullptr);
  if (content->get_type() != MessageContentType::Text) {
    return nullptr;
  }
  auto *text = static_cast<const MessageText *>(content);
  if (text->web_page_url.empty()) {
    return nullptr;
  }
  bool is_optional = !text->text.text.empty();
  return telegram_api::make_object<telegram_api::inputMediaWebPage>(0, text->force_large_media, text->force_small_media,
                                                                    is_optional, text->web_page_url);
}

bool is_uploaded_input_media(telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  CHECK(input_media != nullptr);
  LOG(DEBUG) << "Have " << to_string(input_media);
  switch (input_media->get_id()) {
    case telegram_api::inputMediaUploadedDocument::ID:
      static_cast<telegram_api::inputMediaUploadedDocument *>(input_media.get())->nosound_video_ = true;
    // fallthrough
    case telegram_api::inputMediaUploadedPhoto::ID:
    case telegram_api::inputMediaDocumentExternal::ID:
    case telegram_api::inputMediaPhotoExternal::ID:
      return false;
    case telegram_api::inputMediaDocument::ID:
    case telegram_api::inputMediaPhoto::ID:
      return true;
    case telegram_api::inputMediaPaidMedia::ID:
    default:
      UNREACHABLE();
      return false;
  }
}

void delete_message_content_thumbnail(MessageContent *content, Td *td, int32 media_pos) {
  if (media_pos != -1) {
    CHECK(content->get_type() == MessageContentType::PaidMedia);
  }
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      auto *m = static_cast<MessageAnimation *>(content);
      return td->animations_manager_->delete_animation_thumbnail(m->file_id);
    }
    case MessageContentType::Audio: {
      auto *m = static_cast<MessageAudio *>(content);
      return td->audios_manager_->delete_audio_thumbnail(m->file_id);
    }
    case MessageContentType::Document: {
      auto *m = static_cast<MessageDocument *>(content);
      return td->documents_manager_->delete_document_thumbnail(m->file_id);
    }
    case MessageContentType::Invoice: {
      auto *m = static_cast<MessageInvoice *>(content);
      return m->input_invoice.delete_thumbnail(td);
    }
    case MessageContentType::PaidMedia: {
      auto *m = static_cast<MessagePaidMedia *>(content);
      if (media_pos == -1) {
        CHECK(m->media.size() == 1u);
        media_pos = 0;
      } else {
        CHECK(static_cast<size_t>(media_pos) < m->media.size());
      }
      m->media[media_pos].delete_thumbnail(td);
      break;
    }
    case MessageContentType::Photo: {
      auto *m = static_cast<MessagePhoto *>(content);
      return photo_delete_thumbnail(m->photo);
    }
    case MessageContentType::Sticker: {
      auto *m = static_cast<MessageSticker *>(content);
      return td->stickers_manager_->delete_sticker_thumbnail(m->file_id);
    }
    case MessageContentType::Video: {
      auto *m = static_cast<MessageVideo *>(content);
      return td->videos_manager_->delete_video_thumbnail(m->file_id);
    }
    case MessageContentType::VideoNote: {
      auto *m = static_cast<MessageVideoNote *>(content);
      return td->video_notes_manager_->delete_video_note_thumbnail(m->file_id);
    }
    case MessageContentType::Contact:
    case MessageContentType::Dice:
    case MessageContentType::Game:
    case MessageContentType::LiveLocation:
    case MessageContentType::Location:
    case MessageContentType::Story:
    case MessageContentType::Venue:
    case MessageContentType::VoiceNote:
    case MessageContentType::Text:
    case MessageContentType::Unsupported:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::Poll:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      break;
    default:
      UNREACHABLE();
  }
}

Status can_send_message_content(DialogId dialog_id, const MessageContent *content, bool is_forward,
                                bool check_permissions, const Td *td) {
  auto dialog_type = dialog_id.get_type();
  RestrictedRights permissions = [&] {
    if (!check_permissions) {
      return RestrictedRights(true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
                              true, true, ChannelType::Unknown);
    }
    switch (dialog_type) {
      case DialogType::User:
        return td->user_manager_->get_user_default_permissions(dialog_id.get_user_id());
      case DialogType::Chat:
        return td->chat_manager_->get_chat_permissions(dialog_id.get_chat_id()).get_effective_restricted_rights();
      case DialogType::Channel:
        return td->chat_manager_->get_channel_permissions(dialog_id.get_channel_id()).get_effective_restricted_rights();
      case DialogType::SecretChat:
        return td->user_manager_->get_secret_chat_default_permissions(dialog_id.get_secret_chat_id());
      case DialogType::None:
      default:
        UNREACHABLE();
        return td->user_manager_->get_user_default_permissions(UserId());
    }
  }();

  auto content_type = content->get_type();
  if (dialog_type == DialogType::SecretChat && !can_send_message_content_to_secret_chat(content_type)) {
    return Status::Error(400, "Message can't be sent to a secret chat");
  }
  switch (content_type) {
    case MessageContentType::Animation:
      if (!permissions.can_send_animations()) {
        return Status::Error(400, "Not enough rights to send animations to the chat");
      }
      break;
    case MessageContentType::Audio:
      if (!permissions.can_send_audios()) {
        return Status::Error(400, "Not enough rights to send music to the chat");
      }
      break;
    case MessageContentType::Contact:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send contacts to the chat");
      }
      break;
    case MessageContentType::Dice:
      if (!permissions.can_send_stickers()) {
        return Status::Error(400, "Not enough rights to send dice to the chat");
      }
      break;
    case MessageContentType::Document:
      if (!permissions.can_send_documents()) {
        return Status::Error(400, "Not enough rights to send documents to the chat");
      }
      break;
    case MessageContentType::Game:
      if (dialog_type == DialogType::Channel && td->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id())) {
        // return Status::Error(400, "Games can't be sent to channel chats");
      }
      if (!permissions.can_send_games()) {
        return Status::Error(400, "Not enough rights to send games to the chat");
      }
      break;
    case MessageContentType::Giveaway:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send giveaways to the chat");
      }
      break;
    case MessageContentType::GiveawayWinners:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send giveaway winners to the chat");
      }
      break;
    case MessageContentType::Invoice:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send invoice messages to the chat");
      }
      break;
    case MessageContentType::LiveLocation:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send live locations to the chat");
      }
      break;
    case MessageContentType::Location:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send locations to the chat");
      }
      break;
    case MessageContentType::PaidMedia:
      if (is_forward) {
        if (!permissions.can_send_photos() || !permissions.can_send_videos()) {
          return Status::Error(400, "Not enough rights to send paid media to the chat");
        }
      } else {
        if (!td->auth_manager_->is_bot() && (dialog_type != DialogType::Channel ||
                                             !td->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id()))) {
          return Status::Error(400, "Paid media can be sent only in channel chats");
        }
      }
      break;
    case MessageContentType::Photo:
      if (!permissions.can_send_photos()) {
        return Status::Error(400, "Not enough rights to send photos to the chat");
      }
      break;
    case MessageContentType::Poll:
      if (!permissions.can_send_polls()) {
        return Status::Error(400, "Not enough rights to send polls to the chat");
      }
      if (dialog_type == DialogType::Channel && td->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id()) &&
          !td->poll_manager_->get_poll_is_anonymous(static_cast<const MessagePoll *>(content)->poll_id)) {
        return Status::Error(400, "Non-anonymous polls can't be sent to channel chats");
      }
      if (dialog_type == DialogType::User && !is_forward && !td->auth_manager_->is_bot() &&
          !td->user_manager_->is_user_bot(dialog_id.get_user_id())) {
        return Status::Error(400, "Polls can't be sent to the private chat");
      }
      break;
    case MessageContentType::Sticker:
      if (!permissions.can_send_stickers()) {
        return Status::Error(400, "Not enough rights to send stickers to the chat");
      }
      if (get_message_content_sticker_type(td, content) == StickerType::CustomEmoji) {
        return Status::Error(400, "Can't send emoji stickers in messages");
      }
      break;
    case MessageContentType::Story:
      if (!permissions.can_send_photos() || !permissions.can_send_videos()) {
        return Status::Error(400, "Not enough rights to send stories to the chat");
      }
      break;
    case MessageContentType::Text:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send text messages to the chat");
      }
      break;
    case MessageContentType::Venue:
      if (!permissions.can_send_messages()) {
        return Status::Error(400, "Not enough rights to send venues to the chat");
      }
      break;
    case MessageContentType::Video:
      if (!permissions.can_send_videos()) {
        return Status::Error(400, "Not enough rights to send videos to the chat");
      }
      break;
    case MessageContentType::VideoNote:
      if (!permissions.can_send_video_notes()) {
        return Status::Error(400, "Not enough rights to send video notes to the chat");
      }
      if (dialog_type == DialogType::User &&
          td->user_manager_->get_user_voice_messages_forbidden(dialog_id.get_user_id())) {
        return Status::Error(400, "User restricted receiving of voice messages");
      }
      break;
    case MessageContentType::VoiceNote:
      if (!permissions.can_send_voice_notes()) {
        return Status::Error(400, "Not enough rights to send voice notes to the chat");
      }
      if (dialog_type == DialogType::User &&
          td->user_manager_->get_user_voice_messages_forbidden(dialog_id.get_user_id())) {
        return Status::Error(400, "User restricted receiving of video messages");
      }
      break;
    case MessageContentType::None:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Unsupported:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      UNREACHABLE();
  }
  return Status::OK();
}

bool can_forward_message_content(const MessageContent *content) {
  auto content_type = content->get_type();
  if (content_type == MessageContentType::Text) {
    auto *text = static_cast<const MessageText *>(content);
    // text must be non-empty if there is no link preview
    return !is_empty_string(text->text.text) || text->web_page_id.is_valid() || !text->web_page_url.empty();
  }
  if (content_type == MessageContentType::Poll) {
    auto *poll = static_cast<const MessagePoll *>(content);
    return !PollManager::is_local_poll_id(poll->poll_id);
  }

  return !is_service_message_content(content_type) && content_type != MessageContentType::Unsupported &&
         !is_expired_message_content(content_type);
}

bool update_opened_message_content(MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::VideoNote: {
      auto video_note_content = static_cast<MessageVideoNote *>(content);
      if (video_note_content->is_viewed) {
        return false;
      }
      video_note_content->is_viewed = true;
      return true;
    }
    case MessageContentType::VoiceNote: {
      auto voice_note_content = static_cast<MessageVoiceNote *>(content);
      if (voice_note_content->is_listened) {
        return false;
      }
      voice_note_content->is_listened = true;
      return true;
    }
    default:
      return false;
  }
}

static int32 get_message_content_text_index_mask(const MessageContent *content) {
  const FormattedText *text = get_message_content_text(content);
  if (text == nullptr || content->get_type() == MessageContentType::Game) {
    return 0;
  }

  for (auto &entity : text->entities) {
    if (entity.type == MessageEntity::Type::Url || entity.type == MessageEntity::Type::EmailAddress ||
        entity.type == MessageEntity::Type::TextUrl) {
      return message_search_filter_index_mask(MessageSearchFilter::Url);
    }
  }
  return 0;
}

static int32 get_message_content_media_index_mask(const MessageContent *content, const Td *td, bool is_outgoing) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return message_search_filter_index_mask(MessageSearchFilter::Animation);
    case MessageContentType::Audio:
      return message_search_filter_index_mask(MessageSearchFilter::Audio);
    case MessageContentType::Document:
      return message_search_filter_index_mask(MessageSearchFilter::Document);
    case MessageContentType::Photo:
      return message_search_filter_index_mask(MessageSearchFilter::Photo) |
             message_search_filter_index_mask(MessageSearchFilter::PhotoAndVideo);
    case MessageContentType::Video:
      return message_search_filter_index_mask(MessageSearchFilter::Video) |
             message_search_filter_index_mask(MessageSearchFilter::PhotoAndVideo);
    case MessageContentType::VideoNote:
      return message_search_filter_index_mask(MessageSearchFilter::VideoNote) |
             message_search_filter_index_mask(MessageSearchFilter::VoiceAndVideoNote);
    case MessageContentType::VoiceNote:
      return message_search_filter_index_mask(MessageSearchFilter::VoiceNote) |
             message_search_filter_index_mask(MessageSearchFilter::VoiceAndVideoNote);
    case MessageContentType::ChatChangePhoto:
      return message_search_filter_index_mask(MessageSearchFilter::ChatPhoto);
    case MessageContentType::Call: {
      int32 index_mask = message_search_filter_index_mask(MessageSearchFilter::Call);
      const auto *m = static_cast<const MessageCall *>(content);
      if (!is_outgoing && (m->discard_reason.type_ == CallDiscardReason::Type::Declined ||
                           m->discard_reason.type_ == CallDiscardReason::Type::Missed)) {
        index_mask |= message_search_filter_index_mask(MessageSearchFilter::MissedCall);
      }
      return index_mask;
    }
    case MessageContentType::Text:
    case MessageContentType::Contact:
    case MessageContentType::Game:
    case MessageContentType::Invoice:
    case MessageContentType::LiveLocation:
    case MessageContentType::Location:
    case MessageContentType::Sticker:
    case MessageContentType::Story:
    case MessageContentType::Unsupported:
    case MessageContentType::Venue:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::Poll:
    case MessageContentType::Dice:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaidMedia:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      return 0;
    default:
      UNREACHABLE();
      return 0;
  }
  return 0;
}

int32 get_message_content_index_mask(const MessageContent *content, const Td *td, bool is_outgoing) {
  return get_message_content_text_index_mask(content) | get_message_content_media_index_mask(content, td, is_outgoing);
}

vector<unique_ptr<MessageContent>> get_individual_message_contents(const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::PaidMedia);
  const auto *m = static_cast<const MessagePaidMedia *>(content);
  return transform(m->media, [](const MessageExtendedMedia &media) { return media.get_message_content(); });
}

StickerType get_message_content_sticker_type(const Td *td, const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::Sticker);
  return td->stickers_manager_->get_sticker_type(static_cast<const MessageSticker *>(content)->file_id);
}

MessageId get_message_content_pinned_message_id(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::PinMessage:
      return static_cast<const MessagePinMessage *>(content)->message_id;
    default:
      return MessageId();
  }
}

BackgroundInfo get_message_content_my_background_info(const MessageContent *content, bool is_outgoing) {
  switch (content->get_type()) {
    case MessageContentType::SetBackground: {
      const auto *set_background = static_cast<const MessageSetBackground *>(content);
      if (is_outgoing || set_background->for_both) {
        return set_background->background_info;
      }
      break;
    }
    default:
      break;
  }
  return BackgroundInfo();
}

string get_message_content_theme_name(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::ChatSetTheme:
      return static_cast<const MessageChatSetTheme *>(content)->emoji;
    default:
      return string();
  }
}

MessageFullId get_message_content_replied_message_id(DialogId dialog_id, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::PinMessage:
      return {dialog_id, static_cast<const MessagePinMessage *>(content)->message_id};
    case MessageContentType::GameScore:
      return {dialog_id, static_cast<const MessageGameScore *>(content)->game_message_id};
    case MessageContentType::PaymentSuccessful: {
      auto *m = static_cast<const MessagePaymentSuccessful *>(content);
      if (!m->invoice_message_id.is_valid()) {
        return MessageFullId();
      }

      auto reply_in_dialog_id = m->invoice_dialog_id.is_valid() ? m->invoice_dialog_id : dialog_id;
      return {reply_in_dialog_id, m->invoice_message_id};
    }
    case MessageContentType::SetBackground: {
      auto *m = static_cast<const MessageSetBackground *>(content);
      if (!m->old_message_id.is_valid()) {
        return MessageFullId();
      }

      return {dialog_id, m->old_message_id};
    }
    case MessageContentType::GiveawayResults: {
      auto *m = static_cast<const MessageGiveawayResults *>(content);
      if (!m->giveaway_message_id.is_valid()) {
        return MessageFullId();
      }

      return {dialog_id, m->giveaway_message_id};
    }
    default:
      return MessageFullId();
  }
}

std::pair<InputGroupCallId, bool> get_message_content_group_call_info(const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::GroupCall);
  const auto *m = static_cast<const MessageGroupCall *>(content);
  return {m->input_group_call_id, m->duration >= 0};
}

static vector<UserId> get_formatted_text_user_ids(const FormattedText *formatted_text) {
  vector<UserId> user_ids;
  if (formatted_text != nullptr) {
    for (auto &entity : formatted_text->entities) {
      if (entity.user_id.is_valid()) {
        user_ids.push_back(entity.user_id);
      }
    }
  }
  return user_ids;
}

vector<UserId> get_message_content_min_user_ids(const Td *td, const MessageContent *message_content) {
  CHECK(message_content != nullptr);
  switch (message_content->get_type()) {
    case MessageContentType::Text: {
      const auto *content = static_cast<const MessageText *>(message_content);
      auto user_ids = get_formatted_text_user_ids(&content->text);
      if (content->web_page_id.is_valid()) {
        combine(user_ids, td->web_pages_manager_->get_web_page_user_ids(content->web_page_id));
      }
      return user_ids;
    }
    case MessageContentType::Animation:
      break;
    case MessageContentType::Audio:
      break;
    case MessageContentType::Contact: {
      const auto *content = static_cast<const MessageContact *>(message_content);
      auto user_id = content->contact.get_user_id();
      if (user_id.is_valid()) {
        return {user_id};
      }
      break;
    }
    case MessageContentType::Document:
      break;
    case MessageContentType::Game: {
      const auto *content = static_cast<const MessageGame *>(message_content);
      auto user_id = content->game.get_bot_user_id();
      if (user_id.is_valid()) {
        return {user_id};
      }
      break;
    }
    case MessageContentType::Invoice:
      break;
    case MessageContentType::LiveLocation:
      break;
    case MessageContentType::Location:
      break;
    case MessageContentType::Photo:
      break;
    case MessageContentType::Sticker:
      break;
    case MessageContentType::Venue:
      break;
    case MessageContentType::Video:
      break;
    case MessageContentType::VideoNote:
      break;
    case MessageContentType::VoiceNote:
      break;
    case MessageContentType::ChatCreate: {
      const auto *content = static_cast<const MessageChatCreate *>(message_content);
      return content->participant_user_ids;
    }
    case MessageContentType::ChatChangeTitle:
      break;
    case MessageContentType::ChatChangePhoto:
      break;
    case MessageContentType::ChatDeletePhoto:
      break;
    case MessageContentType::ChatDeleteHistory:
      break;
    case MessageContentType::ChatAddUsers: {
      const auto *content = static_cast<const MessageChatAddUsers *>(message_content);
      return content->user_ids;
    }
    case MessageContentType::ChatJoinedByLink:
      break;
    case MessageContentType::ChatDeleteUser: {
      const auto *content = static_cast<const MessageChatDeleteUser *>(message_content);
      return {content->user_id};
    }
    case MessageContentType::ChatMigrateTo:
      break;
    case MessageContentType::ChannelCreate:
      break;
    case MessageContentType::ChannelMigrateFrom:
      break;
    case MessageContentType::PinMessage:
      break;
    case MessageContentType::GameScore:
      break;
    case MessageContentType::ScreenshotTaken:
      break;
    case MessageContentType::ChatSetTtl:
      // the content->from_user_id user can't be min
      break;
    case MessageContentType::Unsupported:
      break;
    case MessageContentType::Call:
      break;
    case MessageContentType::PaymentSuccessful:
      break;
    case MessageContentType::ContactRegistered:
      break;
    case MessageContentType::ExpiredPhoto:
      break;
    case MessageContentType::ExpiredVideo:
      break;
    case MessageContentType::CustomServiceAction:
      break;
    case MessageContentType::WebsiteConnected:
      break;
    case MessageContentType::PassportDataSent:
      break;
    case MessageContentType::PassportDataReceived:
      break;
    case MessageContentType::Poll:
      break;
    case MessageContentType::Dice:
      break;
    case MessageContentType::ProximityAlertTriggered: {
      const auto *content = static_cast<const MessageProximityAlertTriggered *>(message_content);
      vector<UserId> user_ids;
      if (content->traveler_dialog_id.get_type() == DialogType::User) {
        user_ids.push_back(content->traveler_dialog_id.get_user_id());
      }
      if (content->watcher_dialog_id.get_type() == DialogType::User) {
        user_ids.push_back(content->watcher_dialog_id.get_user_id());
      }
      return user_ids;
    }
    case MessageContentType::GroupCall:
      break;
    case MessageContentType::InviteToGroupCall: {
      const auto *content = static_cast<const MessageInviteToGroupCall *>(message_content);
      return content->user_ids;
    }
    case MessageContentType::ChatSetTheme:
      break;
    case MessageContentType::WebViewDataSent:
      break;
    case MessageContentType::WebViewDataReceived:
      break;
    case MessageContentType::GiftPremium:
      break;
    case MessageContentType::TopicCreate:
      break;
    case MessageContentType::TopicEdit:
      break;
    case MessageContentType::SuggestProfilePhoto:
      break;
    case MessageContentType::WriteAccessAllowed:
      break;
    case MessageContentType::RequestedDialog:
      break;
    case MessageContentType::WebViewWriteAccessAllowed:
      break;
    case MessageContentType::SetBackground:
      break;
    case MessageContentType::Story: {
      const auto *content = static_cast<const MessageStory *>(message_content);
      auto dialog_id = content->story_full_id.get_dialog_id();
      if (dialog_id.get_type() == DialogType::User) {
        return {dialog_id.get_user_id()};
      }
      break;
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      break;
    case MessageContentType::GiftCode:
      break;
    case MessageContentType::Giveaway:
      break;
    case MessageContentType::GiveawayLaunch:
      break;
    case MessageContentType::GiveawayResults:
      break;
    case MessageContentType::GiveawayWinners: {
      const auto *content = static_cast<const MessageGiveawayWinners *>(message_content);
      return content->winner_user_ids;
    }
    case MessageContentType::ExpiredVideoNote:
      break;
    case MessageContentType::ExpiredVoiceNote:
      break;
    case MessageContentType::BoostApply:
      break;
    case MessageContentType::DialogShared:
      // private chats only
      break;
    case MessageContentType::PaidMedia:
      break;
    case MessageContentType::PaymentRefunded:
      // private chats only
      break;
    case MessageContentType::GiftStars:
      break;
    case MessageContentType::PrizeStars:
      // private chats only
      break;
    case MessageContentType::StarGift:
      // private chats only
      break;
    case MessageContentType::StarGiftUnique:
      // private chats only
      break;
    default:
      UNREACHABLE();
      break;
  }
  return get_formatted_text_user_ids(get_message_content_text(message_content));
}

vector<ChannelId> get_message_content_min_channel_ids(const Td *td, const MessageContent *message_content) {
  CHECK(message_content != nullptr);
  switch (message_content->get_type()) {
    case MessageContentType::Text: {
      const auto *content = static_cast<const MessageText *>(message_content);
      if (content->web_page_id.is_valid()) {
        return td->web_pages_manager_->get_web_page_channel_ids(content->web_page_id);
      }
      break;
    }
    case MessageContentType::ProximityAlertTriggered: {
      const auto *content = static_cast<const MessageProximityAlertTriggered *>(message_content);
      vector<ChannelId> channel_ids;
      if (content->traveler_dialog_id.get_type() == DialogType::Channel) {
        channel_ids.push_back(content->traveler_dialog_id.get_channel_id());
      }
      if (content->watcher_dialog_id.get_type() == DialogType::Channel) {
        channel_ids.push_back(content->watcher_dialog_id.get_channel_id());
      }
      return channel_ids;
    }
    case MessageContentType::Story: {
      const auto *content = static_cast<const MessageStory *>(message_content);
      auto dialog_id = content->story_full_id.get_dialog_id();
      if (dialog_id.get_type() == DialogType::Channel) {
        return {dialog_id.get_channel_id()};
      }
      break;
    }
    case MessageContentType::Giveaway: {
      const auto *content = static_cast<const MessageGiveaway *>(message_content);
      return content->giveaway_parameters.get_channel_ids();
    }
    case MessageContentType::GiveawayWinners: {
      const auto *content = static_cast<const MessageGiveawayWinners *>(message_content);
      return {content->boosted_channel_id};
    }
    default:
      break;
  }
  return {};
}

vector<UserId> get_message_content_added_user_ids(const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::ChatAddUsers);
  return static_cast<const MessageChatAddUsers *>(content)->user_ids;
}

UserId get_message_content_deleted_user_id(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::ChatDeleteUser:
      return static_cast<const MessageChatDeleteUser *>(content)->user_id;
    default:
      return UserId();
  }
}

int32 get_message_content_live_location_period(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::LiveLocation:
      return static_cast<const MessageLiveLocation *>(content)->period;
    default:
      return 0;
  }
}

bool get_message_content_poll_is_anonymous(const Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Poll:
      return td->poll_manager_->get_poll_is_anonymous(static_cast<const MessagePoll *>(content)->poll_id);
    default:
      return false;
  }
}

bool get_message_content_poll_is_closed(const Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Poll:
      return td->poll_manager_->get_poll_is_closed(static_cast<const MessagePoll *>(content)->poll_id);
    default:
      return true;
  }
}

const Venue *get_message_content_venue(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Venue:
      return &static_cast<const MessageVenue *>(content)->venue;
    default:
      return nullptr;
  }
}

bool has_message_content_web_page(const MessageContent *content) {
  if (content->get_type() == MessageContentType::Text) {
    return static_cast<const MessageText *>(content)->web_page_id.is_valid();
  }
  return false;
}

void remove_message_content_web_page(MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::Text);
  auto message_text = static_cast<MessageText *>(content);
  message_text->web_page_id = WebPageId();
  message_text->force_small_media = false;
  message_text->force_large_media = false;
  message_text->skip_web_page_confirmation = false;
  message_text->web_page_url = string();
}

bool can_message_content_have_media_timestamp(const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Audio:
    case MessageContentType::Story:
    case MessageContentType::Video:
    case MessageContentType::VideoNote:
    case MessageContentType::VoiceNote:
      return true;
    case MessageContentType::Invoice: {
      const auto *m = static_cast<const MessageInvoice *>(content);
      return m->input_invoice.has_media_timestamp();
    }
    default:
      return has_message_content_web_page(content);
  }
}

void set_message_content_poll_answer(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                     vector<int32> &&option_ids, Promise<Unit> &&promise) {
  CHECK(content->get_type() == MessageContentType::Poll);
  td->poll_manager_->set_poll_answer(static_cast<const MessagePoll *>(content)->poll_id, message_full_id,
                                     std::move(option_ids), std::move(promise));
}

void get_message_content_poll_voters(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                     int32 option_id, int32 offset, int32 limit,
                                     Promise<td_api::object_ptr<td_api::messageSenders>> &&promise) {
  CHECK(content->get_type() == MessageContentType::Poll);
  td->poll_manager_->get_poll_voters(static_cast<const MessagePoll *>(content)->poll_id, message_full_id, option_id,
                                     offset, limit, std::move(promise));
}

void stop_message_content_poll(Td *td, const MessageContent *content, MessageFullId message_full_id,
                               unique_ptr<ReplyMarkup> &&reply_markup, Promise<Unit> &&promise) {
  CHECK(content->get_type() == MessageContentType::Poll);
  td->poll_manager_->stop_poll(static_cast<const MessagePoll *>(content)->poll_id, message_full_id,
                               std::move(reply_markup), std::move(promise));
}

static void merge_location_access_hash(const Location &first, const Location &second) {
  if (second.get_access_hash() != 0) {
    first.set_access_hash(second.get_access_hash());
  } else {
    second.set_access_hash(first.get_access_hash());
  }
}

static bool need_message_text_changed_warning(const MessageText *old_content, const MessageText *new_content) {
  const int32 MAX_CUSTOM_ENTITIES_COUNT = 100;  // server-side limit
  if (old_content->text.entities.size() > MAX_CUSTOM_ENTITIES_COUNT) {
    return false;
  }
  if (new_content->text.text == "Unsupported characters" ||
      new_content->text.text == "This channel is blocked because it was used to spread pornographic content." ||
      begins_with(new_content->text.text,
                  "This group has been temporarily suspended to give its moderators time to clean up after users who "
                  "posted illegal pornographic content.")) {
    // message contained unsupported characters or is restricted, text is replaced
    return false;
  }
  if (/* old_message->message_id.is_yet_unsent() && */ !old_content->text.entities.empty() &&
      old_content->text.entities[0].offset == 0 &&
      (new_content->text.entities.empty() || new_content->text.entities[0] != old_content->text.entities[0]) &&
      old_content->text.text != new_content->text.text && ends_with(old_content->text.text, new_content->text.text)) {
    // server has deleted first entity and left-trimed the message
    return false;
  }
  return true;
}

static bool need_message_entities_changed_warning(const vector<MessageEntity> &old_entities,
                                                  const vector<MessageEntity> &new_entities) {
  size_t old_pos = 0;
  size_t new_pos = 0;
  // compare entities, skipping some known to be different
  while (old_pos < old_entities.size() || new_pos < new_entities.size()) {
    // TODO remove after find_phone_numbers is implemented
    while (new_pos < new_entities.size() && new_entities[new_pos].type == MessageEntity::Type::PhoneNumber) {
      new_pos++;
    }

    if (old_pos < old_entities.size() && new_pos < new_entities.size() &&
        old_entities[old_pos] == new_entities[new_pos]) {
      old_pos++;
      new_pos++;
      continue;
    }
    if (old_pos < old_entities.size() && new_pos < new_entities.size() &&
        (old_entities[old_pos].type == MessageEntity::Type::Pre ||
         old_entities[old_pos].type == MessageEntity::Type::PreCode) &&
        new_entities[new_pos].type == MessageEntity::Type::PreCode && old_entities[old_pos].argument.empty() &&
        old_entities[old_pos].offset == new_entities[new_pos].offset &&
        old_entities[old_pos].length == new_entities[new_pos].length) {
      // server can add recognized language code
      old_pos++;
      new_pos++;
      continue;
    }

    if (old_pos < old_entities.size() && (old_entities[old_pos].type == MessageEntity::Type::MentionName ||
                                          old_entities[old_pos].type == MessageEntity::Type::CustomEmoji)) {
      // server can delete some MentionName and CustomEmoji entities
      old_pos++;
      continue;
    }

    if (old_pos < old_entities.size() || new_pos < new_entities.size()) {
      return true;
    }
  }

  return false;
}

void merge_message_contents(Td *td, const MessageContent *old_content, MessageContent *new_content,
                            bool need_message_changed_warning, DialogId dialog_id, bool need_merge_files,
                            bool &is_content_changed, bool &need_update) {
  MessageContentType content_type = new_content->get_type();
  CHECK(old_content->get_type() == content_type);

  switch (content_type) {
    case MessageContentType::Text: {
      const auto *old_ = static_cast<const MessageText *>(old_content);
      const auto *new_ = static_cast<const MessageText *>(new_content);
      auto get_content_object = [td, dialog_id](const MessageContent *content) {
        return to_string(get_message_content_object(content, td, dialog_id, MessageId(), false, -1, false, false,
                                                    std::numeric_limits<int32>::max(), false, false));
      };
      if (old_->text.text != new_->text.text) {
        if (need_message_changed_warning && need_message_text_changed_warning(old_, new_)) {
          LOG(ERROR) << "Message text has changed for a message in " << dialog_id << " from "
                     << get_content_object(old_content) << " to " << get_content_object(new_content);
        }
      }
      if (old_->text.entities != new_->text.entities) {
        if (need_message_changed_warning && need_message_text_changed_warning(old_, new_) &&
            need_message_entities_changed_warning(old_->text.entities, new_->text.entities) &&
            td->option_manager_->get_option_integer("session_count") <= 1) {
          LOG(WARNING) << "Entities have changed for a message in " << dialog_id << " from "
                       << get_content_object(old_content) << " to " << get_content_object(new_content);
        }
      }
      break;
    }
    case MessageContentType::Animation: {
      const auto *old_ = static_cast<const MessageAnimation *>(old_content);
      const auto *new_ = static_cast<const MessageAnimation *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->animations_manager_->merge_animations(new_->file_id, old_->file_id);
      }
      break;
    }
    case MessageContentType::Audio: {
      const auto *old_ = static_cast<const MessageAudio *>(old_content);
      const auto *new_ = static_cast<const MessageAudio *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->audios_manager_->merge_audios(new_->file_id, old_->file_id);
      }
      break;
    }
    case MessageContentType::Document: {
      const auto *old_ = static_cast<const MessageDocument *>(old_content);
      const auto *new_ = static_cast<const MessageDocument *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->documents_manager_->merge_documents(new_->file_id, old_->file_id);
      }
      break;
    }
    case MessageContentType::Invoice: {
      const auto *old_ = static_cast<const MessageInvoice *>(old_content);
      auto *new_ = static_cast<MessageInvoice *>(new_content);
      new_->input_invoice.update_from(old_->input_invoice);
      break;
    }
    case MessageContentType::LiveLocation: {
      const auto *old_ = static_cast<const MessageLiveLocation *>(old_content);
      const auto *new_ = static_cast<const MessageLiveLocation *>(new_content);
      if (old_->location.get_access_hash() != new_->location.get_access_hash()) {
        merge_location_access_hash(old_->location, new_->location);
      }
      break;
    }
    case MessageContentType::Location: {
      const auto *old_ = static_cast<const MessageLocation *>(old_content);
      const auto *new_ = static_cast<const MessageLocation *>(new_content);
      if (old_->location.get_access_hash() != new_->location.get_access_hash()) {
        merge_location_access_hash(old_->location, new_->location);
      }
      break;
    }
    case MessageContentType::PaidMedia: {
      const auto *old_ = static_cast<const MessagePaidMedia *>(old_content);
      auto *new_ = static_cast<MessagePaidMedia *>(new_content);
      if (old_->media.size() != new_->media.size()) {
        LOG(ERROR) << "Had " << old_->media.size() << " paid media, but now have " << new_->media.size();
      } else {
        for (size_t i = 0; i < old_->media.size(); i++) {
          old_->media[i].merge_files(td, new_->media[i], dialog_id, need_merge_files, is_content_changed, need_update);
        }
      }
      break;
    }
    case MessageContentType::Photo: {
      const auto *old_ = static_cast<const MessagePhoto *>(old_content);
      auto *new_ = static_cast<MessagePhoto *>(new_content);
      merge_photos(td, &old_->photo, &new_->photo, dialog_id, need_merge_files, is_content_changed, need_update);
      break;
    }
    case MessageContentType::Sticker: {
      const auto *old_ = static_cast<const MessageSticker *>(old_content);
      const auto *new_ = static_cast<const MessageSticker *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->stickers_manager_->merge_stickers(new_->file_id, old_->file_id);
      }
      break;
    }
    case MessageContentType::Venue: {
      const auto *old_ = static_cast<const MessageVenue *>(old_content);
      const auto *new_ = static_cast<const MessageVenue *>(new_content);
      if (old_->venue.location().get_access_hash() != new_->venue.location().get_access_hash()) {
        merge_location_access_hash(old_->venue.location(), new_->venue.location());
      }
      break;
    }
    case MessageContentType::Video: {
      const auto *old_ = static_cast<const MessageVideo *>(old_content);
      const auto *new_ = static_cast<const MessageVideo *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->videos_manager_->merge_videos(new_->file_id, old_->file_id);
      }
      break;
    }
    case MessageContentType::VideoNote: {
      const auto *old_ = static_cast<const MessageVideoNote *>(old_content);
      auto *new_ = static_cast<MessageVideoNote *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->video_notes_manager_->merge_video_notes(new_->file_id, old_->file_id);
      }
      if (old_->is_viewed) {
        new_->is_viewed = true;
      }
      break;
    }
    case MessageContentType::VoiceNote: {
      const auto *old_ = static_cast<const MessageVoiceNote *>(old_content);
      auto *new_ = static_cast<MessageVoiceNote *>(new_content);
      if (old_->file_id != new_->file_id && need_merge_files) {
        td->voice_notes_manager_->merge_voice_notes(new_->file_id, old_->file_id);
      }
      if (old_->is_listened) {
        new_->is_listened = true;
      }
      break;
    }
    case MessageContentType::Contact:
    case MessageContentType::Game:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::Poll:
    case MessageContentType::Dice:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::Unsupported:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::Story:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      break;
    default:
      UNREACHABLE();
      break;
  }
}

bool merge_message_content_file_id(Td *td, MessageContent *message_content, FileId new_file_id) {
  if (!new_file_id.is_valid()) {
    return false;
  }

  // secret chats only
  LOG(INFO) << "Merge message content of a message with file " << new_file_id;
  MessageContentType content_type = message_content->get_type();
  switch (content_type) {
    case MessageContentType::Animation: {
      auto content = static_cast<MessageAnimation *>(message_content);
      if (new_file_id != content->file_id) {
        td->animations_manager_->merge_animations(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::Audio: {
      auto content = static_cast<MessageAudio *>(message_content);
      if (new_file_id != content->file_id) {
        td->audios_manager_->merge_audios(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::Document: {
      auto content = static_cast<MessageDocument *>(message_content);
      if (new_file_id != content->file_id) {
        td->documents_manager_->merge_documents(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::Photo: {
      auto content = static_cast<MessagePhoto *>(message_content);
      Photo *photo = &content->photo;
      if (!photo->photos.empty() && photo->photos.back().type == 'i') {
        FileId &old_file_id = photo->photos.back().file_id;
        if (old_file_id != new_file_id) {
          LOG_STATUS(td->file_manager_->merge(new_file_id, old_file_id));
          old_file_id = new_file_id;
          return true;
        }
      }
      break;
    }
    case MessageContentType::Sticker: {
      auto content = static_cast<MessageSticker *>(message_content);
      if (new_file_id != content->file_id) {
        td->stickers_manager_->merge_stickers(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::Video: {
      auto content = static_cast<MessageVideo *>(message_content);
      if (new_file_id != content->file_id) {
        td->videos_manager_->merge_videos(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::VideoNote: {
      auto content = static_cast<MessageVideoNote *>(message_content);
      if (new_file_id != content->file_id) {
        td->video_notes_manager_->merge_video_notes(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::VoiceNote: {
      auto content = static_cast<MessageVoiceNote *>(message_content);
      if (new_file_id != content->file_id) {
        td->voice_notes_manager_->merge_voice_notes(new_file_id, content->file_id);
        content->file_id = new_file_id;
        return true;
      }
      break;
    }
    case MessageContentType::Contact:
    case MessageContentType::Game:
    case MessageContentType::Invoice:
    case MessageContentType::LiveLocation:
    case MessageContentType::Location:
    case MessageContentType::PaidMedia:
    case MessageContentType::Story:
    case MessageContentType::Text:
    case MessageContentType::Venue:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Unsupported:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::Poll:
    case MessageContentType::Dice:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      LOG(ERROR) << "Receive new file " << new_file_id << " in a sent message of the type " << content_type;
      break;
    default:
      UNREACHABLE();
      break;
  }
  return false;
}

void compare_message_contents(Td *td, const MessageContent *old_content, const MessageContent *new_content,
                              bool &is_content_changed, bool &need_update) {
  if (old_content == nullptr) {
    if (new_content != nullptr) {
      need_update = true;
    }
    return;
  }
  MessageContentType content_type = old_content->get_type();
  if (new_content == nullptr || new_content->get_type() != content_type) {
    need_update = true;
    return;
  }

  switch (content_type) {
    case MessageContentType::Text: {
      const auto *lhs = static_cast<const MessageText *>(old_content);
      const auto *rhs = static_cast<const MessageText *>(new_content);
      if (lhs->text.text != rhs->text.text || lhs->text.entities != rhs->text.entities ||
          lhs->web_page_url != rhs->web_page_url || lhs->force_small_media != rhs->force_small_media ||
          lhs->force_large_media != rhs->force_large_media) {
        need_update = true;
      } else if (lhs->web_page_id != rhs->web_page_id ||
                 lhs->skip_web_page_confirmation != rhs->skip_web_page_confirmation) {
        is_content_changed = true;
        if (td == nullptr || td->web_pages_manager_->have_web_page(lhs->web_page_id) ||
            td->web_pages_manager_->have_web_page(rhs->web_page_id)) {
          need_update = true;
        }
      }
      break;
    }
    case MessageContentType::Animation: {
      const auto *lhs = static_cast<const MessageAnimation *>(old_content);
      const auto *rhs = static_cast<const MessageAnimation *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->caption != rhs->caption || lhs->has_spoiler != rhs->has_spoiler) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Audio: {
      const auto *lhs = static_cast<const MessageAudio *>(old_content);
      const auto *rhs = static_cast<const MessageAudio *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->caption != rhs->caption) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Contact: {
      const auto *lhs = static_cast<const MessageContact *>(old_content);
      const auto *rhs = static_cast<const MessageContact *>(new_content);
      if (lhs->contact != rhs->contact) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Document: {
      const auto *lhs = static_cast<const MessageDocument *>(old_content);
      const auto *rhs = static_cast<const MessageDocument *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->caption != rhs->caption) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Game: {
      const auto *lhs = static_cast<const MessageGame *>(old_content);
      const auto *rhs = static_cast<const MessageGame *>(new_content);
      if (lhs->game != rhs->game) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Invoice: {
      const auto *lhs = static_cast<const MessageInvoice *>(old_content);
      const auto *rhs = static_cast<const MessageInvoice *>(new_content);
      if (lhs->input_invoice != rhs->input_invoice) {
        need_update = true;
      } else if (lhs->input_invoice.is_equal_but_different(rhs->input_invoice)) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::LiveLocation: {
      const auto *lhs = static_cast<const MessageLiveLocation *>(old_content);
      const auto *rhs = static_cast<const MessageLiveLocation *>(new_content);
      if (lhs->location != rhs->location || lhs->period != rhs->period || lhs->heading != rhs->heading ||
          lhs->proximity_alert_radius != rhs->proximity_alert_radius) {
        need_update = true;
      } else if (lhs->location.get_access_hash() != rhs->location.get_access_hash()) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::Location: {
      const auto *lhs = static_cast<const MessageLocation *>(old_content);
      const auto *rhs = static_cast<const MessageLocation *>(new_content);
      if (lhs->location != rhs->location) {
        need_update = true;
      } else if (lhs->location.get_access_hash() != rhs->location.get_access_hash()) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::Photo: {
      const auto *lhs = static_cast<const MessagePhoto *>(old_content);
      const auto *rhs = static_cast<const MessagePhoto *>(new_content);
      if (lhs->caption != rhs->caption || lhs->has_spoiler != rhs->has_spoiler) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Sticker: {
      const auto *lhs = static_cast<const MessageSticker *>(old_content);
      const auto *rhs = static_cast<const MessageSticker *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->is_premium != rhs->is_premium) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Venue: {
      const auto *lhs = static_cast<const MessageVenue *>(old_content);
      const auto *rhs = static_cast<const MessageVenue *>(new_content);
      if (lhs->venue != rhs->venue) {
        need_update = true;
      } else if (lhs->venue.location().get_access_hash() != rhs->venue.location().get_access_hash()) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::Video: {
      const auto *lhs = static_cast<const MessageVideo *>(old_content);
      const auto *rhs = static_cast<const MessageVideo *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->alternative_file_ids != rhs->alternative_file_ids ||
          lhs->hls_file_ids != rhs->hls_file_ids || lhs->cover != rhs->cover ||
          lhs->start_timestamp != rhs->start_timestamp || lhs->caption != rhs->caption ||
          lhs->has_spoiler != rhs->has_spoiler) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::VideoNote: {
      const auto *lhs = static_cast<const MessageVideoNote *>(old_content);
      const auto *rhs = static_cast<const MessageVideoNote *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->is_viewed != rhs->is_viewed) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::VoiceNote: {
      const auto *lhs = static_cast<const MessageVoiceNote *>(old_content);
      const auto *rhs = static_cast<const MessageVoiceNote *>(new_content);
      if (lhs->file_id != rhs->file_id || lhs->caption != rhs->caption || lhs->is_listened != rhs->is_listened) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatCreate: {
      const auto *lhs = static_cast<const MessageChatCreate *>(old_content);
      const auto *rhs = static_cast<const MessageChatCreate *>(new_content);
      if (lhs->title != rhs->title || lhs->participant_user_ids != rhs->participant_user_ids) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatChangeTitle: {
      const auto *lhs = static_cast<const MessageChatChangeTitle *>(old_content);
      const auto *rhs = static_cast<const MessageChatChangeTitle *>(new_content);
      if (lhs->title != rhs->title) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatChangePhoto: {
      const auto *lhs = static_cast<const MessageChatChangePhoto *>(old_content);
      const auto *rhs = static_cast<const MessageChatChangePhoto *>(new_content);
      if (lhs->photo != rhs->photo) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatDeletePhoto:
      break;
    case MessageContentType::ChatDeleteHistory:
      break;
    case MessageContentType::ChatAddUsers: {
      const auto *lhs = static_cast<const MessageChatAddUsers *>(old_content);
      const auto *rhs = static_cast<const MessageChatAddUsers *>(new_content);
      if (lhs->user_ids != rhs->user_ids) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatJoinedByLink: {
      auto lhs = static_cast<const MessageChatJoinedByLink *>(old_content);
      auto rhs = static_cast<const MessageChatJoinedByLink *>(new_content);
      if (lhs->is_approved != rhs->is_approved) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatDeleteUser: {
      const auto *lhs = static_cast<const MessageChatDeleteUser *>(old_content);
      const auto *rhs = static_cast<const MessageChatDeleteUser *>(new_content);
      if (lhs->user_id != rhs->user_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChatMigrateTo: {
      const auto *lhs = static_cast<const MessageChatMigrateTo *>(old_content);
      const auto *rhs = static_cast<const MessageChatMigrateTo *>(new_content);
      if (lhs->migrated_to_channel_id != rhs->migrated_to_channel_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChannelCreate: {
      const auto *lhs = static_cast<const MessageChannelCreate *>(old_content);
      const auto *rhs = static_cast<const MessageChannelCreate *>(new_content);
      if (lhs->title != rhs->title) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ChannelMigrateFrom: {
      const auto *lhs = static_cast<const MessageChannelMigrateFrom *>(old_content);
      const auto *rhs = static_cast<const MessageChannelMigrateFrom *>(new_content);
      if (lhs->title != rhs->title || lhs->migrated_from_chat_id != rhs->migrated_from_chat_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::PinMessage: {
      const auto *lhs = static_cast<const MessagePinMessage *>(old_content);
      const auto *rhs = static_cast<const MessagePinMessage *>(new_content);
      if (lhs->message_id != rhs->message_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GameScore: {
      const auto *lhs = static_cast<const MessageGameScore *>(old_content);
      const auto *rhs = static_cast<const MessageGameScore *>(new_content);
      if (lhs->game_message_id != rhs->game_message_id || lhs->game_id != rhs->game_id || lhs->score != rhs->score) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ScreenshotTaken:
      break;
    case MessageContentType::ChatSetTtl: {
      const auto *lhs = static_cast<const MessageChatSetTtl *>(old_content);
      const auto *rhs = static_cast<const MessageChatSetTtl *>(new_content);
      if (lhs->ttl != rhs->ttl || lhs->from_user_id != rhs->from_user_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Call: {
      const auto *lhs = static_cast<const MessageCall *>(old_content);
      const auto *rhs = static_cast<const MessageCall *>(new_content);
      if (lhs->duration != rhs->duration || lhs->discard_reason != rhs->discard_reason ||
          lhs->is_video != rhs->is_video) {
        need_update = true;
      } else if (lhs->call_id != rhs->call_id) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::PaymentSuccessful: {
      const auto *lhs = static_cast<const MessagePaymentSuccessful *>(old_content);
      const auto *rhs = static_cast<const MessagePaymentSuccessful *>(new_content);
      if (lhs->invoice_dialog_id != rhs->invoice_dialog_id || lhs->invoice_message_id != rhs->invoice_message_id ||
          lhs->currency != rhs->currency || lhs->total_amount != rhs->total_amount ||
          lhs->invoice_payload != rhs->invoice_payload || lhs->shipping_option_id != rhs->shipping_option_id ||
          lhs->telegram_payment_charge_id != rhs->telegram_payment_charge_id ||
          lhs->provider_payment_charge_id != rhs->provider_payment_charge_id ||
          ((lhs->order_info != nullptr || rhs->order_info != nullptr) &&
           (lhs->order_info == nullptr || rhs->order_info == nullptr || *lhs->order_info != *rhs->order_info)) ||
          lhs->is_recurring != rhs->is_recurring || lhs->is_first_recurring != rhs->is_first_recurring ||
          lhs->subscription_until_date != rhs->subscription_until_date) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ContactRegistered:
      break;
    case MessageContentType::ExpiredPhoto:
      break;
    case MessageContentType::ExpiredVideo:
      break;
    case MessageContentType::CustomServiceAction: {
      const auto *lhs = static_cast<const MessageCustomServiceAction *>(old_content);
      const auto *rhs = static_cast<const MessageCustomServiceAction *>(new_content);
      if (lhs->message != rhs->message) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WebsiteConnected: {
      const auto *lhs = static_cast<const MessageWebsiteConnected *>(old_content);
      const auto *rhs = static_cast<const MessageWebsiteConnected *>(new_content);
      if (lhs->domain_name != rhs->domain_name) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::PassportDataSent: {
      const auto *lhs = static_cast<const MessagePassportDataSent *>(old_content);
      const auto *rhs = static_cast<const MessagePassportDataSent *>(new_content);
      if (lhs->types != rhs->types) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::PassportDataReceived: {
      const auto *lhs = static_cast<const MessagePassportDataReceived *>(old_content);
      const auto *rhs = static_cast<const MessagePassportDataReceived *>(new_content);
      if (lhs->values != rhs->values || lhs->credentials != rhs->credentials) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Poll: {
      const auto *lhs = static_cast<const MessagePoll *>(old_content);
      const auto *rhs = static_cast<const MessagePoll *>(new_content);
      if (lhs->poll_id != rhs->poll_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Dice: {
      const auto *lhs = static_cast<const MessageDice *>(old_content);
      const auto *rhs = static_cast<const MessageDice *>(new_content);
      if (lhs->emoji != rhs->emoji || lhs->dice_value != rhs->dice_value) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ProximityAlertTriggered: {
      const auto *lhs = static_cast<const MessageProximityAlertTriggered *>(old_content);
      const auto *rhs = static_cast<const MessageProximityAlertTriggered *>(new_content);
      if (lhs->traveler_dialog_id != rhs->traveler_dialog_id || lhs->watcher_dialog_id != rhs->watcher_dialog_id ||
          lhs->distance != rhs->distance) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GroupCall: {
      const auto *lhs = static_cast<const MessageGroupCall *>(old_content);
      const auto *rhs = static_cast<const MessageGroupCall *>(new_content);
      if (lhs->input_group_call_id != rhs->input_group_call_id || lhs->duration != rhs->duration ||
          lhs->schedule_date != rhs->schedule_date) {
        need_update = true;
      } else if (!lhs->input_group_call_id.is_identical(rhs->input_group_call_id)) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::InviteToGroupCall: {
      const auto *lhs = static_cast<const MessageInviteToGroupCall *>(old_content);
      const auto *rhs = static_cast<const MessageInviteToGroupCall *>(new_content);
      if (lhs->input_group_call_id != rhs->input_group_call_id || lhs->user_ids != rhs->user_ids) {
        need_update = true;
      } else if (!lhs->input_group_call_id.is_identical(rhs->input_group_call_id)) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::ChatSetTheme: {
      const auto *lhs = static_cast<const MessageChatSetTheme *>(old_content);
      const auto *rhs = static_cast<const MessageChatSetTheme *>(new_content);
      if (lhs->emoji != rhs->emoji) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WebViewDataSent: {
      const auto *lhs = static_cast<const MessageWebViewDataSent *>(old_content);
      const auto *rhs = static_cast<const MessageWebViewDataSent *>(new_content);
      if (lhs->button_text != rhs->button_text) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WebViewDataReceived: {
      const auto *lhs = static_cast<const MessageWebViewDataReceived *>(old_content);
      const auto *rhs = static_cast<const MessageWebViewDataReceived *>(new_content);
      if (lhs->button_text != rhs->button_text || lhs->data != rhs->data) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GiftPremium: {
      const auto *lhs = static_cast<const MessageGiftPremium *>(old_content);
      const auto *rhs = static_cast<const MessageGiftPremium *>(new_content);
      if (lhs->text != rhs->text || lhs->currency != rhs->currency || lhs->amount != rhs->amount ||
          lhs->crypto_currency != rhs->crypto_currency || lhs->crypto_amount != rhs->crypto_amount ||
          lhs->months != rhs->months) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::TopicCreate: {
      const auto *lhs = static_cast<const MessageTopicCreate *>(old_content);
      const auto *rhs = static_cast<const MessageTopicCreate *>(new_content);
      if (lhs->title != rhs->title || lhs->icon != rhs->icon) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::TopicEdit: {
      const auto *lhs = static_cast<const MessageTopicEdit *>(old_content);
      const auto *rhs = static_cast<const MessageTopicEdit *>(new_content);
      if (lhs->edited_data != rhs->edited_data) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Unsupported: {
      const auto *lhs = static_cast<const MessageUnsupported *>(old_content);
      const auto *rhs = static_cast<const MessageUnsupported *>(new_content);
      if (lhs->version != rhs->version) {
        is_content_changed = true;
      }
      break;
    }
    case MessageContentType::SuggestProfilePhoto: {
      const auto *lhs = static_cast<const MessageSuggestProfilePhoto *>(old_content);
      const auto *rhs = static_cast<const MessageSuggestProfilePhoto *>(new_content);
      if (lhs->photo != rhs->photo) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WriteAccessAllowed:
      break;
    case MessageContentType::RequestedDialog: {
      const auto *lhs = static_cast<const MessageRequestedDialog *>(old_content);
      const auto *rhs = static_cast<const MessageRequestedDialog *>(new_content);
      if (lhs->shared_dialog_ids != rhs->shared_dialog_ids || lhs->button_id != rhs->button_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WebViewWriteAccessAllowed: {
      const auto *lhs = static_cast<const MessageWebViewWriteAccessAllowed *>(old_content);
      const auto *rhs = static_cast<const MessageWebViewWriteAccessAllowed *>(new_content);
      if (lhs->web_app != rhs->web_app) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::SetBackground: {
      const auto *lhs = static_cast<const MessageSetBackground *>(old_content);
      const auto *rhs = static_cast<const MessageSetBackground *>(new_content);
      if (lhs->old_message_id != rhs->old_message_id || lhs->background_info != rhs->background_info ||
          lhs->for_both != rhs->for_both) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Story: {
      const auto *lhs = static_cast<const MessageStory *>(old_content);
      const auto *rhs = static_cast<const MessageStory *>(new_content);
      if (lhs->story_full_id != rhs->story_full_id || lhs->via_mention != rhs->via_mention) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      break;
    case MessageContentType::GiftCode: {
      const auto *lhs = static_cast<const MessageGiftCode *>(old_content);
      const auto *rhs = static_cast<const MessageGiftCode *>(new_content);
      if (lhs->creator_dialog_id != rhs->creator_dialog_id || lhs->text != rhs->text || lhs->months != rhs->months ||
          lhs->currency != rhs->currency || lhs->amount != rhs->amount ||
          lhs->crypto_currency != rhs->crypto_currency || lhs->crypto_amount != rhs->crypto_amount ||
          lhs->via_giveaway != rhs->via_giveaway || lhs->is_unclaimed != rhs->is_unclaimed || lhs->code != rhs->code) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::Giveaway: {
      const auto *lhs = static_cast<const MessageGiveaway *>(old_content);
      const auto *rhs = static_cast<const MessageGiveaway *>(new_content);
      if (lhs->giveaway_parameters != rhs->giveaway_parameters || lhs->quantity != rhs->quantity ||
          lhs->months != rhs->months || lhs->star_count != rhs->star_count) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GiveawayLaunch: {
      const auto *lhs = static_cast<const MessageGiveawayLaunch *>(old_content);
      const auto *rhs = static_cast<const MessageGiveawayLaunch *>(new_content);
      if (lhs->star_count != rhs->star_count) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GiveawayResults: {
      const auto *lhs = static_cast<const MessageGiveawayResults *>(old_content);
      const auto *rhs = static_cast<const MessageGiveawayResults *>(new_content);
      if (lhs->giveaway_message_id != rhs->giveaway_message_id || lhs->winner_count != rhs->winner_count ||
          lhs->unclaimed_count != rhs->unclaimed_count || lhs->is_star_giveaway != rhs->is_star_giveaway) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GiveawayWinners: {
      const auto *lhs = static_cast<const MessageGiveawayWinners *>(old_content);
      const auto *rhs = static_cast<const MessageGiveawayWinners *>(new_content);
      if (lhs->giveaway_message_id != rhs->giveaway_message_id || lhs->boosted_channel_id != rhs->boosted_channel_id ||
          lhs->additional_dialog_count != rhs->additional_dialog_count || lhs->month_count != rhs->month_count ||
          lhs->star_count != rhs->star_count || lhs->prize_description != rhs->prize_description ||
          lhs->winners_selection_date != rhs->winners_selection_date ||
          lhs->only_new_subscribers != rhs->only_new_subscribers || lhs->was_refunded != rhs->was_refunded ||
          lhs->winner_count != rhs->winner_count || lhs->unclaimed_count != rhs->unclaimed_count ||
          lhs->winner_user_ids != rhs->winner_user_ids) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::ExpiredVideoNote:
      break;
    case MessageContentType::ExpiredVoiceNote:
      break;
    case MessageContentType::BoostApply: {
      const auto *lhs = static_cast<const MessageBoostApply *>(old_content);
      const auto *rhs = static_cast<const MessageBoostApply *>(new_content);
      if (lhs->boost_count != rhs->boost_count) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::DialogShared: {
      const auto *lhs = static_cast<const MessageDialogShared *>(old_content);
      const auto *rhs = static_cast<const MessageDialogShared *>(new_content);
      if (lhs->shared_dialogs != rhs->shared_dialogs || lhs->button_id != rhs->button_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::PaidMedia: {
      const auto *lhs = static_cast<const MessagePaidMedia *>(old_content);
      const auto *rhs = static_cast<const MessagePaidMedia *>(new_content);
      if (lhs->caption != rhs->caption || lhs->star_count != rhs->star_count ||
          lhs->media.size() != rhs->media.size()) {
        need_update = true;
      } else {
        for (size_t i = 0; i < lhs->media.size(); i++) {
          if (lhs->media[i] != rhs->media[i]) {
            need_update = true;
          } else if (lhs->media[i].is_equal_but_different(rhs->media[i])) {
            is_content_changed = true;
          }
        }
        if (lhs->payload != rhs->payload) {
          is_content_changed = true;
        }
      }
      break;
    }
    case MessageContentType::PaymentRefunded: {
      const auto *lhs = static_cast<const MessagePaymentRefunded *>(old_content);
      const auto *rhs = static_cast<const MessagePaymentRefunded *>(new_content);
      if (lhs->dialog_id != rhs->dialog_id || lhs->currency != rhs->currency ||
          lhs->total_amount != rhs->total_amount || lhs->invoice_payload != rhs->invoice_payload ||
          lhs->telegram_payment_charge_id != rhs->telegram_payment_charge_id ||
          lhs->provider_payment_charge_id != rhs->provider_payment_charge_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::GiftStars: {
      const auto *lhs = static_cast<const MessageGiftStars *>(old_content);
      const auto *rhs = static_cast<const MessageGiftStars *>(new_content);
      if (lhs->currency != rhs->currency || lhs->amount != rhs->amount ||
          lhs->crypto_currency != rhs->crypto_currency || lhs->crypto_amount != rhs->crypto_amount ||
          lhs->star_count != rhs->star_count || lhs->transaction_id != rhs->transaction_id) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::PrizeStars: {
      const auto *lhs = static_cast<const MessagePrizeStars *>(old_content);
      const auto *rhs = static_cast<const MessagePrizeStars *>(new_content);
      if (lhs->star_count != rhs->star_count || lhs->transaction_id != rhs->transaction_id ||
          lhs->boosted_dialog_id != rhs->boosted_dialog_id || lhs->giveaway_message_id != rhs->giveaway_message_id ||
          lhs->is_unclaimed != rhs->is_unclaimed) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::StarGift: {
      const auto *lhs = static_cast<const MessageStarGift *>(old_content);
      const auto *rhs = static_cast<const MessageStarGift *>(new_content);
      if (lhs->star_gift != rhs->star_gift || lhs->sender_dialog_id != rhs->sender_dialog_id ||
          lhs->owner_dialog_id != rhs->owner_dialog_id || lhs->saved_id != rhs->saved_id || lhs->text != rhs->text ||
          lhs->convert_star_count != rhs->convert_star_count || lhs->upgrade_star_count != rhs->upgrade_star_count ||
          lhs->upgrade_message_id != rhs->upgrade_message_id || lhs->name_hidden != rhs->name_hidden ||
          lhs->is_saved != rhs->is_saved || lhs->can_upgrade != rhs->can_upgrade ||
          lhs->was_converted != rhs->was_converted || lhs->was_upgraded != rhs->was_upgraded ||
          lhs->was_refunded != rhs->was_refunded) {
        need_update = true;
      }
      break;
    }
    case MessageContentType::StarGiftUnique: {
      const auto *lhs = static_cast<const MessageStarGiftUnique *>(old_content);
      const auto *rhs = static_cast<const MessageStarGiftUnique *>(new_content);
      if (lhs->star_gift != rhs->star_gift || lhs->sender_dialog_id != rhs->sender_dialog_id ||
          lhs->owner_dialog_id != rhs->owner_dialog_id || lhs->saved_id != rhs->saved_id ||
          lhs->transfer_star_count != rhs->transfer_star_count || lhs->can_export_at != rhs->can_export_at ||
          lhs->is_saved != rhs->is_saved || lhs->is_upgrade != rhs->is_upgrade ||
          lhs->can_transfer != rhs->can_transfer || lhs->was_transferred != rhs->was_transferred ||
          lhs->was_refunded != rhs->was_refunded) {
        need_update = true;
      }
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

static bool can_be_animated_emoji(const FormattedText &text) {
  if (!is_emoji(text.text)) {
    return false;
  }
  if (text.entities.empty()) {
    return true;
  }
  if (text.entities.size() == 1 && text.entities[0].type == MessageEntity::Type::CustomEmoji &&
      text.entities[0].offset == 0 && static_cast<size_t>(text.entities[0].length) == utf8_utf16_length(text.text) &&
      text.entities[0].custom_emoji_id.is_valid()) {
    return true;
  }
  return false;
}

static CustomEmojiId get_custom_emoji_id(const FormattedText &text) {
  return text.entities.empty() ? CustomEmojiId() : text.entities[0].custom_emoji_id;
}

static bool need_register_message_content_for_bots(MessageContentType content_type) {
  return content_type == MessageContentType::Poll;
}

void register_message_content(Td *td, const MessageContent *content, MessageFullId message_full_id,
                              const char *source) {
  auto content_type = content->get_type();
  if (td->auth_manager_->is_bot() && !need_register_message_content_for_bots(content_type)) {
    return;
  }
  switch (content_type) {
    case MessageContentType::Text: {
      auto text = static_cast<const MessageText *>(content);
      if (text->web_page_id.is_valid()) {
        td->web_pages_manager_->register_web_page(text->web_page_id, message_full_id, source);
      } else if (can_be_animated_emoji(text->text)) {
        td->stickers_manager_->register_emoji(text->text.text, get_custom_emoji_id(text->text), message_full_id, {},
                                              source);
      }
      return;
    }
    case MessageContentType::VideoNote:
      return td->transcription_manager_->register_voice(static_cast<const MessageVideoNote *>(content)->file_id,
                                                        content_type, message_full_id, source);
    case MessageContentType::VoiceNote:
      return td->transcription_manager_->register_voice(static_cast<const MessageVoiceNote *>(content)->file_id,
                                                        content_type, message_full_id, source);
    case MessageContentType::Poll:
      return td->poll_manager_->register_poll(static_cast<const MessagePoll *>(content)->poll_id, message_full_id,
                                              source);
    case MessageContentType::Dice: {
      auto dice = static_cast<const MessageDice *>(content);
      return td->stickers_manager_->register_dice(dice->emoji, dice->dice_value, message_full_id, {}, source);
    }
    case MessageContentType::GiftPremium:
      return td->stickers_manager_->register_premium_gift(static_cast<const MessageGiftPremium *>(content)->months, 0,
                                                          message_full_id, source);
    case MessageContentType::GiftCode:
      return td->stickers_manager_->register_premium_gift(static_cast<const MessageGiftCode *>(content)->months, 0,
                                                          message_full_id, source);
    case MessageContentType::Giveaway: {
      auto giveaway = static_cast<const MessageGiveaway *>(content);
      return td->stickers_manager_->register_premium_gift(giveaway->months, giveaway->star_count, message_full_id,
                                                          source);
    }
    case MessageContentType::SuggestProfilePhoto:
      return td->user_manager_->register_suggested_profile_photo(
          static_cast<const MessageSuggestProfilePhoto *>(content)->photo);
    case MessageContentType::Story:
      return td->story_manager_->register_story(static_cast<const MessageStory *>(content)->story_full_id,
                                                message_full_id, {}, source);
    case MessageContentType::GiftStars: {
      auto star_count = static_cast<const MessageGiftStars *>(content)->star_count;
      return td->stickers_manager_->register_premium_gift(0, star_count, message_full_id, source);
    }
    case MessageContentType::PrizeStars: {
      auto star_count = static_cast<const MessagePrizeStars *>(content)->star_count;
      return td->stickers_manager_->register_premium_gift(0, star_count, message_full_id, source);
    }
    case MessageContentType::StarGift: {
      auto star_gift = static_cast<const MessageStarGift *>(content);
      td->star_gift_manager_->on_get_star_gift(star_gift->star_gift, false);
      return td->star_gift_manager_->register_gift(message_full_id, source);
    }
    case MessageContentType::StarGiftUnique: {
      auto star_gift = static_cast<const MessageStarGiftUnique *>(content);
      td->star_gift_manager_->on_get_star_gift(star_gift->star_gift, false);
      return td->star_gift_manager_->register_gift(message_full_id, source);
    }
    default:
      return;
  }
}

void reregister_message_content(Td *td, const MessageContent *old_content, const MessageContent *new_content,
                                MessageFullId message_full_id, const char *source) {
  auto old_content_type = old_content->get_type();
  auto new_content_type = new_content->get_type();
  if (old_content_type == new_content_type) {
    if (td->auth_manager_->is_bot() && !need_register_message_content_for_bots(new_content_type)) {
      return;
    }
    switch (old_content_type) {
      case MessageContentType::Text: {
        auto old_text = static_cast<const MessageText *>(old_content);
        auto new_text = static_cast<const MessageText *>(new_content);
        if (old_text->web_page_id == new_text->web_page_id &&
            (old_text->text == new_text->text ||
             (!can_be_animated_emoji(old_text->text) && !can_be_animated_emoji(new_text->text)))) {
          return;
        }
        break;
      }
      case MessageContentType::VideoNote:
        if (static_cast<const MessageVideoNote *>(old_content)->file_id ==
            static_cast<const MessageVideoNote *>(new_content)->file_id) {
          return;
        }
        break;
      case MessageContentType::VoiceNote:
        if (static_cast<const MessageVoiceNote *>(old_content)->file_id ==
            static_cast<const MessageVoiceNote *>(new_content)->file_id) {
          return;
        }
        break;
      case MessageContentType::Poll:
        if (static_cast<const MessagePoll *>(old_content)->poll_id ==
            static_cast<const MessagePoll *>(new_content)->poll_id) {
          return;
        }
        break;
      case MessageContentType::Dice:
        if (static_cast<const MessageDice *>(old_content)->emoji ==
                static_cast<const MessageDice *>(new_content)->emoji &&
            static_cast<const MessageDice *>(old_content)->dice_value ==
                static_cast<const MessageDice *>(new_content)->dice_value) {
          return;
        }
        break;
      case MessageContentType::GiftPremium:
        if (static_cast<const MessageGiftPremium *>(old_content)->months ==
            static_cast<const MessageGiftPremium *>(new_content)->months) {
          return;
        }
        break;
      case MessageContentType::GiftCode:
        if (static_cast<const MessageGiftCode *>(old_content)->months ==
            static_cast<const MessageGiftCode *>(new_content)->months) {
          return;
        }
        break;
      case MessageContentType::Giveaway:
        if (static_cast<const MessageGiveaway *>(old_content)->months ==
                static_cast<const MessageGiveaway *>(new_content)->months &&
            static_cast<const MessageGiveaway *>(old_content)->star_count ==
                static_cast<const MessageGiveaway *>(new_content)->star_count) {
          return;
        }
        break;
      case MessageContentType::Story:
        if (static_cast<const MessageStory *>(old_content)->story_full_id ==
            static_cast<const MessageStory *>(new_content)->story_full_id) {
          return;
        }
        break;
      case MessageContentType::GiftStars:
        if (static_cast<const MessageGiftStars *>(old_content)->star_count ==
            static_cast<const MessageGiftStars *>(new_content)->star_count) {
          return;
        }
        break;
      case MessageContentType::PrizeStars:
        if (static_cast<const MessagePrizeStars *>(old_content)->star_count ==
            static_cast<const MessagePrizeStars *>(new_content)->star_count) {
          return;
        }
        break;
      default:
        return;
    }
  }
  unregister_message_content(td, old_content, message_full_id, source);
  register_message_content(td, new_content, message_full_id, source);
}

void unregister_message_content(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                const char *source) {
  auto content_type = content->get_type();
  if (td->auth_manager_->is_bot() && !need_register_message_content_for_bots(content_type)) {
    return;
  }
  switch (content_type) {
    case MessageContentType::Text: {
      auto text = static_cast<const MessageText *>(content);
      if (text->web_page_id.is_valid()) {
        td->web_pages_manager_->unregister_web_page(text->web_page_id, message_full_id, source);
      } else if (can_be_animated_emoji(text->text)) {
        td->stickers_manager_->unregister_emoji(text->text.text, get_custom_emoji_id(text->text), message_full_id, {},
                                                source);
      }
      return;
    }
    case MessageContentType::VideoNote:
      return td->transcription_manager_->unregister_voice(static_cast<const MessageVideoNote *>(content)->file_id,
                                                          content_type, message_full_id, source);
    case MessageContentType::VoiceNote:
      return td->transcription_manager_->unregister_voice(static_cast<const MessageVoiceNote *>(content)->file_id,
                                                          content_type, message_full_id, source);
    case MessageContentType::Poll:
      return td->poll_manager_->unregister_poll(static_cast<const MessagePoll *>(content)->poll_id, message_full_id,
                                                source);
    case MessageContentType::Dice: {
      auto dice = static_cast<const MessageDice *>(content);
      return td->stickers_manager_->unregister_dice(dice->emoji, dice->dice_value, message_full_id, {}, source);
    }
    case MessageContentType::GiftPremium:
      return td->stickers_manager_->unregister_premium_gift(static_cast<const MessageGiftPremium *>(content)->months, 0,
                                                            message_full_id, source);
    case MessageContentType::GiftCode:
      return td->stickers_manager_->unregister_premium_gift(static_cast<const MessageGiftCode *>(content)->months, 0,
                                                            message_full_id, source);
    case MessageContentType::Giveaway: {
      auto giveaway = static_cast<const MessageGiveaway *>(content);
      return td->stickers_manager_->unregister_premium_gift(giveaway->months, giveaway->star_count, message_full_id,
                                                            source);
    }
    case MessageContentType::Story:
      return td->story_manager_->unregister_story(static_cast<const MessageStory *>(content)->story_full_id,
                                                  message_full_id, {}, source);
    case MessageContentType::GiftStars: {
      auto star_count = static_cast<const MessageGiftStars *>(content)->star_count;
      return td->stickers_manager_->unregister_premium_gift(0, star_count, message_full_id, source);
    }
    case MessageContentType::PrizeStars: {
      auto star_count = static_cast<const MessagePrizeStars *>(content)->star_count;
      return td->stickers_manager_->unregister_premium_gift(0, star_count, message_full_id, source);
    }
    case MessageContentType::StarGift:
      return td->star_gift_manager_->unregister_gift(message_full_id, source);
    case MessageContentType::StarGiftUnique:
      return td->star_gift_manager_->unregister_gift(message_full_id, source);
    default:
      return;
  }
}

void register_reply_message_content(Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Poll:
      return td->poll_manager_->register_reply_poll(static_cast<const MessagePoll *>(content)->poll_id);
    default:
      return;
  }
}

void unregister_reply_message_content(Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Poll:
      return td->poll_manager_->unregister_reply_poll(static_cast<const MessagePoll *>(content)->poll_id);
    default:
      return;
  }
}

void register_quick_reply_message_content(Td *td, const MessageContent *content,
                                          QuickReplyMessageFullId message_full_id, const char *source) {
  switch (content->get_type()) {
    case MessageContentType::Text: {
      auto text = static_cast<const MessageText *>(content);
      if (text->web_page_id.is_valid()) {
        td->web_pages_manager_->register_quick_reply_web_page(text->web_page_id, message_full_id, source);
      } else if (can_be_animated_emoji(text->text)) {
        td->stickers_manager_->register_emoji(text->text.text, get_custom_emoji_id(text->text), {}, message_full_id,
                                              source);
      }
      return;
    }
    case MessageContentType::Dice: {
      auto dice = static_cast<const MessageDice *>(content);
      return td->stickers_manager_->register_dice(dice->emoji, dice->dice_value, {}, message_full_id, source);
    }
    case MessageContentType::Story:
      return td->story_manager_->register_story(static_cast<const MessageStory *>(content)->story_full_id, {},
                                                message_full_id, source);
    default:
      return;
  }
}

void unregister_quick_reply_message_content(Td *td, const MessageContent *content,
                                            QuickReplyMessageFullId message_full_id, const char *source) {
  switch (content->get_type()) {
    case MessageContentType::Text: {
      auto text = static_cast<const MessageText *>(content);
      if (text->web_page_id.is_valid()) {
        td->web_pages_manager_->unregister_quick_reply_web_page(text->web_page_id, message_full_id, source);
      } else if (can_be_animated_emoji(text->text)) {
        td->stickers_manager_->unregister_emoji(text->text.text, get_custom_emoji_id(text->text), {}, message_full_id,
                                                source);
      }
      return;
    }
    case MessageContentType::Dice: {
      auto dice = static_cast<const MessageDice *>(content);
      return td->stickers_manager_->unregister_dice(dice->emoji, dice->dice_value, {}, message_full_id, source);
    }
    case MessageContentType::Story:
      return td->story_manager_->unregister_story(static_cast<const MessageStory *>(content)->story_full_id, {},
                                                  message_full_id, source);
    default:
      return;
  }
}

template <class ToT, class FromT>
static tl_object_ptr<ToT> secret_to_telegram(FromT &from);

// photoSizeEmpty type:string = PhotoSize;
static auto secret_to_telegram(secret_api::photoSizeEmpty &empty) {
  if (!clean_input_string(empty.type_)) {
    empty.type_.clear();
  }
  return make_tl_object<telegram_api::photoSizeEmpty>(empty.type_);
}

// photoSize type:string location:FileLocation w:int h:int size:int = PhotoSize;
static auto secret_to_telegram(secret_api::photoSize &photo_size) {
  if (!clean_input_string(photo_size.type_)) {
    photo_size.type_.clear();
  }
  return make_tl_object<telegram_api::photoSize>(photo_size.type_, photo_size.w_, photo_size.h_, photo_size.size_);
}

// photoCachedSize type:string location:FileLocation w:int h:int bytes:bytes = PhotoSize;
static auto secret_to_telegram(secret_api::photoCachedSize &photo_size) {
  if (!clean_input_string(photo_size.type_)) {
    photo_size.type_.clear();
  }
  return make_tl_object<telegram_api::photoCachedSize>(photo_size.type_, photo_size.w_, photo_size.h_,
                                                       photo_size.bytes_.clone());
}

// documentAttributeImageSize w:int h:int = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeImageSize &image_size) {
  return make_tl_object<telegram_api::documentAttributeImageSize>(image_size.w_, image_size.h_);
}

// documentAttributeAnimated = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeAnimated &animated) {
  return make_tl_object<telegram_api::documentAttributeAnimated>();
}

// documentAttributeSticker23 = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeSticker23 &sticker) {
  return make_tl_object<telegram_api::documentAttributeSticker>(
      0, false, "", make_tl_object<telegram_api::inputStickerSetEmpty>(), nullptr);
}

static auto secret_to_telegram(secret_api::inputStickerSetEmpty &sticker_set) {
  return make_tl_object<telegram_api::inputStickerSetEmpty>();
}

static auto secret_to_telegram(secret_api::inputStickerSetShortName &sticker_set) {
  if (!clean_input_string(sticker_set.short_name_)) {
    sticker_set.short_name_.clear();
  }
  return make_tl_object<telegram_api::inputStickerSetShortName>(sticker_set.short_name_);
}

// documentAttributeSticker alt:string stickerset:InputStickerSet = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeSticker &sticker) {
  if (!clean_input_string(sticker.alt_)) {
    sticker.alt_.clear();
  }
  return make_tl_object<telegram_api::documentAttributeSticker>(
      0, false, sticker.alt_, secret_to_telegram<telegram_api::InputStickerSet>(*sticker.stickerset_), nullptr);
}

// documentAttributeVideo23 duration:int w:int h:int = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeVideo23 &video) {
  return make_tl_object<telegram_api::documentAttributeVideo>(0, false, false, false, video.duration_, video.w_,
                                                              video.h_, 0, 0.0, string());
}

// documentAttributeFilename file_name:string = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeFilename &filename) {
  if (!clean_input_string(filename.file_name_)) {
    filename.file_name_.clear();
  }
  return make_tl_object<telegram_api::documentAttributeFilename>(filename.file_name_);
}

// documentAttributeVideo flags:# round_message:flags.0?true duration:int w:int h:int = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeVideo &video) {
  return make_tl_object<telegram_api::documentAttributeVideo>(
      video.round_message_ ? telegram_api::documentAttributeVideo::ROUND_MESSAGE_MASK : 0, video.round_message_, false,
      false, video.duration_, video.w_, video.h_, 0, 0.0, string());
}

static auto telegram_documentAttributeAudio(bool is_voice_note, int duration, string title, string performer,
                                            BufferSlice waveform) {
  if (!clean_input_string(title)) {
    title.clear();
  }
  if (!clean_input_string(performer)) {
    performer.clear();
  }

  int32 flags = 0;
  if (is_voice_note) {
    flags |= telegram_api::documentAttributeAudio::VOICE_MASK;
  }
  if (!title.empty()) {
    flags |= telegram_api::documentAttributeAudio::TITLE_MASK;
  }
  if (!performer.empty()) {
    flags |= telegram_api::documentAttributeAudio::PERFORMER_MASK;
  }
  if (!waveform.empty()) {
    flags |= telegram_api::documentAttributeAudio::WAVEFORM_MASK;
  }
  return make_tl_object<telegram_api::documentAttributeAudio>(flags, is_voice_note, duration, std::move(title),
                                                              std::move(performer), std::move(waveform));
}

// documentAttributeAudio23 duration:int = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeAudio23 &audio) {
  return telegram_documentAttributeAudio(false, audio.duration_, "", "", Auto());
}
// documentAttributeAudio45 duration:int title:string performer:string = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeAudio45 &audio) {
  return telegram_documentAttributeAudio(false, audio.duration_, audio.title_, audio.performer_, Auto());
}

// documentAttributeAudio flags:# voice:flags.10?true duration:int title:flags.0?string
//    performer:flags.1?string waveform:flags.2?bytes = DocumentAttribute;
static auto secret_to_telegram(secret_api::documentAttributeAudio &audio) {
  return telegram_documentAttributeAudio(audio.voice_, audio.duration_, audio.title_, audio.performer_,
                                         audio.waveform_.clone());
}

static auto secret_to_telegram(std::vector<tl_object_ptr<secret_api::DocumentAttribute>> &attributes) {
  std::vector<tl_object_ptr<telegram_api::DocumentAttribute>> res;
  for (auto &attribute : attributes) {
    auto telegram_attribute = secret_to_telegram<telegram_api::DocumentAttribute>(*attribute);
    if (telegram_attribute) {
      res.push_back(std::move(telegram_attribute));
    }
  }
  return res;
}

// decryptedMessageMediaExternalDocument id:long access_hash:long date:int mime_type:string size:int
// thumb:PhotoSize dc_id:int attributes:Vector<DocumentAttribute> = DecryptedMessageMedia;
static auto secret_to_telegram_document(secret_api::decryptedMessageMediaExternalDocument &from) {
  if (!clean_input_string(from.mime_type_)) {
    from.mime_type_.clear();
  }
  vector<telegram_api::object_ptr<telegram_api::PhotoSize>> thumbnails;
  thumbnails.push_back(secret_to_telegram<telegram_api::PhotoSize>(*from.thumb_));
  return make_tl_object<telegram_api::document>(0, from.id_, from.access_hash_, BufferSlice(), from.date_,
                                                from.mime_type_, from.size_, std::move(thumbnails), Auto(), from.dc_id_,
                                                secret_to_telegram(from.attributes_));
}

template <class ToT, class FromT>
static tl_object_ptr<ToT> secret_to_telegram(FromT &from) {
  tl_object_ptr<ToT> res;
  downcast_call(from, [&](auto &p) { res = secret_to_telegram(p); });
  return res;
}

static unique_ptr<MessageContent> get_document_message_content(Document &&parsed_document, FormattedText &&caption,
                                                               bool is_opened, bool is_premium, bool has_spoiler,
                                                               vector<FileId> &&alternative_file_ids,
                                                               vector<FileId> &&hls_file_ids, Photo &&video_cover,
                                                               int32 video_timestamp) {
  auto file_id = parsed_document.file_id;
  if (!parsed_document.empty()) {
    CHECK(file_id.is_valid());
  }
  if (!alternative_file_ids.empty() && parsed_document.type != Document::Type::Video) {
    LOG(ERROR) << "Receive alternative videos for " << parsed_document;
  }
  switch (parsed_document.type) {
    case Document::Type::Animation:
      return make_unique<MessageAnimation>(file_id, std::move(caption), has_spoiler);
    case Document::Type::Audio:
      return make_unique<MessageAudio>(file_id, std::move(caption));
    case Document::Type::General:
      return make_unique<MessageDocument>(file_id, std::move(caption));
    case Document::Type::Sticker:
      return make_unique<MessageSticker>(file_id, is_premium);
    case Document::Type::Unknown:
      return make_unique<MessageUnsupported>();
    case Document::Type::Video:
      return td::make_unique<MessageVideo>(file_id, std::move(alternative_file_ids), std::move(hls_file_ids),
                                           std::move(video_cover), video_timestamp, std::move(caption), has_spoiler);
    case Document::Type::VideoNote:
      return make_unique<MessageVideoNote>(file_id, is_opened);
    case Document::Type::VoiceNote:
      return make_unique<MessageVoiceNote>(file_id, std::move(caption), is_opened);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

static unique_ptr<MessageContent> get_document_message_content(Td *td, tl_object_ptr<telegram_api::document> &&document,
                                                               DialogId owner_dialog_id, bool is_self_destructing,
                                                               FormattedText &&caption, bool is_opened, bool is_premium,
                                                               bool has_spoiler, vector<FileId> &&alternative_file_ids,
                                                               vector<FileId> &&hls_file_ids, Photo &&video_cover,
                                                               int32 start_timestamp,
                                                               MultiPromiseActor *load_data_multipromise_ptr) {
  return get_document_message_content(
      td->documents_manager_->on_get_document(std::move(document), owner_dialog_id, is_self_destructing,
                                              load_data_multipromise_ptr),
      std::move(caption), is_opened, is_premium, has_spoiler, std::move(alternative_file_ids), std::move(hls_file_ids),
      std::move(video_cover), start_timestamp);
}

unique_ptr<MessageContent> get_secret_message_content(
    Td *td, string message_text, unique_ptr<EncryptedFile> file,
    tl_object_ptr<secret_api::DecryptedMessageMedia> &&media_ptr,
    vector<tl_object_ptr<secret_api::MessageEntity>> &&secret_entities, DialogId owner_dialog_id,
    MultiPromiseActor &load_data_multipromise, bool is_premium) {
  int32 constructor_id = media_ptr == nullptr ? secret_api::decryptedMessageMediaEmpty::ID : media_ptr->get_id();
  auto caption = [&] {
    switch (constructor_id) {
      case secret_api::decryptedMessageMediaVideo::ID: {
        auto media = static_cast<secret_api::decryptedMessageMediaVideo *>(media_ptr.get());
        return std::move(media->caption_);
      }
      case secret_api::decryptedMessageMediaPhoto::ID: {
        auto media = static_cast<secret_api::decryptedMessageMediaPhoto *>(media_ptr.get());
        return std::move(media->caption_);
      }
      case secret_api::decryptedMessageMediaDocument46::ID: {
        auto media = static_cast<secret_api::decryptedMessageMediaDocument46 *>(media_ptr.get());
        return std::move(media->caption_);
      }
      case secret_api::decryptedMessageMediaDocument::ID: {
        auto media = static_cast<secret_api::decryptedMessageMediaDocument *>(media_ptr.get());
        return std::move(media->caption_);
      }
      default:
        return string();
    }
  }();
  if (!clean_input_string(caption)) {
    caption.clear();
  }

  if (message_text.empty()) {
    message_text = std::move(caption);
  } else if (!caption.empty()) {
    message_text = message_text + "\n\n" + caption;
  }

  auto entities = get_message_entities(td, std::move(secret_entities), is_premium, load_data_multipromise);
  auto status = fix_formatted_text(message_text, entities, true, false, true, td->auth_manager_->is_bot(), false);
  if (status.is_error()) {
    LOG(WARNING) << "Receive error " << status << " while parsing secret message \"" << message_text
                 << "\" with entities " << entities;
    if (!clean_input_string(message_text)) {
      message_text.clear();
    }
    entities = find_entities(message_text, true, td->auth_manager_->is_bot());
  }

  // support of old layer and old constructions
  switch (constructor_id) {
    case secret_api::decryptedMessageMediaDocument46::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaDocument46>(media_ptr);
      media_ptr = make_tl_object<secret_api::decryptedMessageMediaDocument>(
          std::move(media->thumb_), media->thumb_w_, media->thumb_h_, media->mime_type_, media->size_,
          std::move(media->key_), std::move(media->iv_), std::move(media->attributes_), string());

      constructor_id = secret_api::decryptedMessageMediaDocument::ID;
      break;
    }
    case secret_api::decryptedMessageMediaVideo::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaVideo>(media_ptr);
      vector<tl_object_ptr<secret_api::DocumentAttribute>> attributes;
      attributes.emplace_back(
          make_tl_object<secret_api::documentAttributeVideo>(0, false, media->duration_, media->w_, media->h_));
      media_ptr = make_tl_object<secret_api::decryptedMessageMediaDocument>(
          std::move(media->thumb_), media->thumb_w_, media->thumb_h_, media->mime_type_, media->size_,
          std::move(media->key_), std::move(media->iv_), std::move(attributes), string());

      constructor_id = secret_api::decryptedMessageMediaDocument::ID;
      break;
    }
    default:
      break;
  }

  bool is_media_empty = false;
  switch (constructor_id) {
    case secret_api::decryptedMessageMediaEmpty::ID:
      if (message_text.empty()) {
        LOG(ERROR) << "Receive empty message text and media";
      }
      is_media_empty = true;
      break;
    case secret_api::decryptedMessageMediaGeoPoint::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaGeoPoint>(media_ptr);

      auto m = make_unique<MessageLocation>(Location(media));
      if (m->location.empty()) {
        is_media_empty = true;
        break;
      }

      return std::move(m);
    }
    case secret_api::decryptedMessageMediaVenue::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaVenue>(media_ptr);

      if (!clean_input_string(media->title_)) {
        media->title_.clear();
      }
      if (!clean_input_string(media->address_)) {
        media->address_.clear();
      }
      if (!clean_input_string(media->provider_)) {
        media->provider_.clear();
      }
      if (!clean_input_string(media->venue_id_)) {
        media->venue_id_.clear();
      }

      auto m = make_unique<MessageVenue>(Venue(Location(td, media->lat_, media->long_, 0.0, 0),
                                               std::move(media->title_), std::move(media->address_),
                                               std::move(media->provider_), std::move(media->venue_id_), string()));
      if (m->venue.empty()) {
        is_media_empty = true;
        break;
      }

      return std::move(m);
    }
    case secret_api::decryptedMessageMediaContact::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaContact>(media_ptr);
      if (!clean_input_string(media->phone_number_)) {
        media->phone_number_.clear();
      }
      if (!clean_input_string(media->first_name_)) {
        media->first_name_.clear();
      }
      if (!clean_input_string(media->last_name_)) {
        media->last_name_.clear();
      }
      return make_unique<MessageContact>(Contact(std::move(media->phone_number_), std::move(media->first_name_),
                                                 std::move(media->last_name_), string(), UserId()));
    }
    case secret_api::decryptedMessageMediaWebPage::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaWebPage>(media_ptr);
      if (!clean_input_string(media->url_)) {
        media->url_.clear();
      }
      auto r_http_url = parse_url(media->url_);
      if (r_http_url.is_error()) {
        is_media_empty = true;
        break;
      }
      auto url = r_http_url.ok().get_url();

      auto result = td::make_unique<MessageText>(FormattedText{std::move(message_text), std::move(entities)},
                                                 WebPageId(), false, false, false, url);
      td->web_pages_manager_->fetch_web_page_by_url(
          url,
          PromiseCreator::lambda([&web_page_id = result->web_page_id, promise = load_data_multipromise.get_promise()](
                                     Result<WebPageId> r_web_page_id) mutable {
            if (r_web_page_id.is_ok()) {
              web_page_id = r_web_page_id.move_as_ok();
            }
            promise.set_value(Unit());
          }));
      return std::move(result);
    }
    case secret_api::decryptedMessageMediaExternalDocument::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaExternalDocument>(media_ptr);
      return get_document_message_content(td, secret_to_telegram_document(*media), owner_dialog_id, false,
                                          FormattedText{std::move(message_text), std::move(entities)}, false,
                                          is_premium, false, {}, {}, Photo(), 0, &load_data_multipromise);
    }
    default:
      break;
  }
  if (file == nullptr && !is_media_empty) {
    LOG(ERROR) << "Receive secret message with media, but without a file";
    is_media_empty = true;
  }
  if (is_media_empty) {
    return create_text_message_content(std::move(message_text), std::move(entities), WebPageId(), false, false, false,
                                       string());
  }
  switch (constructor_id) {
    case secret_api::decryptedMessageMediaPhoto::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaPhoto>(media_ptr);
      return make_unique<MessagePhoto>(
          get_encrypted_file_photo(td->file_manager_.get(), std::move(file), std::move(media), owner_dialog_id),
          FormattedText{std::move(message_text), std::move(entities)}, false);
    }
    case secret_api::decryptedMessageMediaDocument::ID: {
      auto media = secret_api::move_object_as<secret_api::decryptedMessageMediaDocument>(media_ptr);
      if (!clean_input_string(media->mime_type_)) {
        media->mime_type_.clear();
      }
      auto attributes = secret_to_telegram(media->attributes_);
      for (auto &attribute : attributes) {
        CHECK(attribute != nullptr);
        if (attribute->get_id() == telegram_api::documentAttributeSticker::ID) {
          auto attribute_sticker = static_cast<telegram_api::documentAttributeSticker *>(attribute.get());
          CHECK(attribute_sticker->stickerset_ != nullptr);
          if (attribute_sticker->stickerset_->get_id() != telegram_api::inputStickerSetEmpty::ID) {
            attribute_sticker->stickerset_ = make_tl_object<telegram_api::inputStickerSetEmpty>();
          }
        }
      }

      media->attributes_.clear();
      auto document = td->documents_manager_->on_get_document(
          {std::move(file), std::move(media), std::move(attributes)}, owner_dialog_id, false);
      return get_document_message_content(std::move(document), {std::move(message_text), std::move(entities)}, false,
                                          false, false, {}, {}, Photo(), 0);
    }
    default:
      LOG(ERROR) << "Unsupported: " << to_string(media_ptr);
      return make_unique<MessageUnsupported>();
  }
}

unique_ptr<MessageContent> get_message_content(Td *td, FormattedText message,
                                               tl_object_ptr<telegram_api::MessageMedia> &&media_ptr,
                                               DialogId owner_dialog_id, int32 message_date, bool is_content_read,
                                               UserId via_bot_user_id, MessageSelfDestructType *ttl,
                                               bool *disable_web_page_preview, const char *source) {
  if (!G()->close_flag() && !td->auth_manager_->was_authorized() && media_ptr != nullptr &&
      media_ptr->get_id() != telegram_api::messageMediaEmpty::ID) {
    LOG(ERROR) << "Receive without authorization from " << source << ": " << to_string(media_ptr);
    media_ptr = nullptr;
  }
  if (disable_web_page_preview != nullptr) {
    *disable_web_page_preview = false;
  }

  switch (media_ptr == nullptr ? telegram_api::messageMediaEmpty::ID : media_ptr->get_id()) {
    case telegram_api::messageMediaEmpty::ID:
      if (message.text.empty()) {
        LOG(ERROR) << "Receive empty message text and media from " << source;
      }
      if (disable_web_page_preview != nullptr && !get_first_url(message).empty()) {
        *disable_web_page_preview = true;
      }
      return td::make_unique<MessageText>(std::move(message), WebPageId(), false, false, false, string());
    case telegram_api::messageMediaPhoto::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaPhoto>(media_ptr);
      if (media->photo_ == nullptr) {
        if ((media->flags_ & telegram_api::messageMediaPhoto::TTL_SECONDS_MASK) == 0) {
          LOG(ERROR) << "Receive messageMediaPhoto without photo and self-destruct timer from " << source << ": "
                     << oneline(to_string(media));
          break;
        }

        return make_unique<MessageExpiredPhoto>();
      }

      bool is_self_destructing = (media->flags_ & telegram_api::messageMediaPhoto::TTL_SECONDS_MASK) != 0;
      auto photo = get_photo(td, std::move(media->photo_), owner_dialog_id,
                             is_self_destructing ? FileType::SelfDestructingPhoto : FileType::Photo);
      if (photo.is_empty()) {
        return make_unique<MessageExpiredPhoto>();
      }

      if (ttl != nullptr && is_self_destructing) {
        *ttl = MessageSelfDestructType(media->ttl_seconds_, true);
      }
      return make_unique<MessagePhoto>(std::move(photo), std::move(message), media->spoiler_);
    }
    case telegram_api::messageMediaDice::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaDice>(media_ptr);

      auto m = td::make_unique<MessageDice>(media->emoticon_, media->value_);
      if (!m->is_valid()) {
        break;
      }

      return std::move(m);
    }
    case telegram_api::messageMediaGeo::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaGeo>(media_ptr);

      auto m = make_unique<MessageLocation>(Location(td, media->geo_));
      if (m->location.empty()) {
        break;
      }

      return std::move(m);
    }
    case telegram_api::messageMediaGeoLive::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaGeoLive>(media_ptr);
      auto location = Location(td, media->geo_);
      if (location.empty()) {
        break;
      }

      int32 period = media->period_;
      if (period <= 0) {
        LOG(ERROR) << "Receive wrong live location period = " << period << " from " << source;
        return make_unique<MessageLocation>(std::move(location));
      }
      return make_unique<MessageLiveLocation>(std::move(location), period, media->heading_,
                                              media->proximity_notification_radius_);
    }
    case telegram_api::messageMediaVenue::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaVenue>(media_ptr);
      auto m = make_unique<MessageVenue>(Venue(td, media->geo_, std::move(media->title_), std::move(media->address_),
                                               std::move(media->provider_), std::move(media->venue_id_),
                                               std::move(media->venue_type_)));
      if (m->venue.empty()) {
        break;
      }

      return std::move(m);
    }
    case telegram_api::messageMediaContact::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaContact>(media_ptr);
      if (media->user_id_ != 0) {
        td->user_manager_->get_user_id_object(UserId(media->user_id_),
                                              "MessageMediaContact");  // to ensure updateUser
      }
      return make_unique<MessageContact>(Contact(std::move(media->phone_number_), std::move(media->first_name_),
                                                 std::move(media->last_name_), std::move(media->vcard_),
                                                 UserId(media->user_id_)));
    }
    case telegram_api::messageMediaDocument::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaDocument>(media_ptr);
      if (media->document_ == nullptr) {
        if ((media->flags_ & telegram_api::messageMediaDocument::TTL_SECONDS_MASK) == 0) {
          LOG(ERROR) << "Receive messageMediaDocument without document and self-destruct timer from " << source << ": "
                     << oneline(to_string(media));
          break;
        }
        if (media->voice_) {
          return make_unique<MessageExpiredVoiceNote>();
        }
        if (media->round_) {
          return make_unique<MessageExpiredVideoNote>();
        }
        if (media->video_) {
          return make_unique<MessageExpiredVideo>();
        }
        LOG(ERROR) << "Receive messageMediaDocument without document and media type from " << source << ": "
                   << oneline(to_string(media));

        return make_unique<MessageExpiredVideo>();
      }

      auto document_ptr = std::move(media->document_);
      int32 document_id = document_ptr->get_id();
      if (document_id == telegram_api::documentEmpty::ID) {
        break;
      }
      CHECK(document_id == telegram_api::document::ID);

      bool is_self_destructing = (media->flags_ & telegram_api::messageMediaDocument::TTL_SECONDS_MASK) != 0;
      if (ttl != nullptr && is_self_destructing) {
        *ttl = MessageSelfDestructType(media->ttl_seconds_, true);
      }
      vector<FileId> alternative_file_ids;
      vector<FileId> hls_file_ids;
      for (auto &alt_document_ptr : media->alt_documents_) {
        int32 alt_document_id = alt_document_ptr->get_id();
        if (alt_document_id == telegram_api::documentEmpty::ID) {
          LOG(ERROR) << "Receive alternative " << to_string(alt_document_ptr);
        } else {
          CHECK(alt_document_id == telegram_api::document::ID);
          auto document = telegram_api::move_object_as<telegram_api::document>(alt_document_ptr);
          if (document->mime_type_ == "application/x-mpegurl") {
            auto parsed_hls_file = td->documents_manager_->on_get_document(std::move(document), owner_dialog_id, false);
            if (parsed_hls_file.empty() || parsed_hls_file.type != Document::Type::General) {
              LOG(ERROR) << "Receive invalid HLS file " << parsed_hls_file;
            } else {
              hls_file_ids.push_back(parsed_hls_file.file_id);
            }
            continue;
          }
          auto parsed_alt_document = td->documents_manager_->on_get_document(std::move(document), owner_dialog_id,
                                                                             false, nullptr, Document::Type::Video);
          if (parsed_alt_document.empty() || parsed_alt_document.type != Document::Type::Video) {
            LOG(ERROR) << "Receive invalid alternative video " << parsed_alt_document;
          } else {
            alternative_file_ids.push_back(parsed_alt_document.file_id);
          }
        }
      }
      Photo video_cover;
      if (media->video_cover_ != nullptr) {
        video_cover = get_photo(td, std::move(media->video_cover_), owner_dialog_id,
                                is_self_destructing ? FileType::SelfDestructingPhoto : FileType::Photo);
      }
      return get_document_message_content(
          td, telegram_api::move_object_as<telegram_api::document>(document_ptr), owner_dialog_id, is_self_destructing,
          std::move(message), is_content_read, !media->nopremium_, media->spoiler_, std::move(alternative_file_ids),
          std::move(hls_file_ids), std::move(video_cover), media->video_timestamp_, nullptr);
    }
    case telegram_api::messageMediaGame::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaGame>(media_ptr);

      auto m = make_unique<MessageGame>(
          Game(td, via_bot_user_id, std::move(media->game_), std::move(message), owner_dialog_id));
      if (m->game.is_empty()) {
        break;
      }
      return std::move(m);
    }
    case telegram_api::messageMediaInvoice::ID:
      return td::make_unique<MessageInvoice>(
          InputInvoice(telegram_api::move_object_as<telegram_api::messageMediaInvoice>(media_ptr), td, owner_dialog_id,
                       std::move(message)));
    case telegram_api::messageMediaWebPage::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaWebPage>(media_ptr);
      string web_page_url;
      if (media->manual_ || media->force_small_media_ || media->force_large_media_) {
        web_page_url = WebPagesManager::get_web_page_url(media->webpage_);
        if (web_page_url.empty()) {
          LOG(ERROR) << "Have no URL in " << to_string(media);
        }
      } else if (td->auth_manager_->is_bot()) {
        web_page_url = WebPagesManager::get_web_page_url(media->webpage_);
      }
      auto web_page_id = td->web_pages_manager_->on_get_web_page(std::move(media->webpage_), owner_dialog_id);
      return td::make_unique<MessageText>(std::move(message), web_page_id, media->force_small_media_,
                                          media->force_large_media_, media->safe_, std::move(web_page_url));
    }
    case telegram_api::messageMediaPoll::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaPoll>(media_ptr);
      auto poll_id =
          td->poll_manager_->on_get_poll(PollId(), std::move(media->poll_), std::move(media->results_), source);
      if (!poll_id.is_valid()) {
        break;
      }
      return make_unique<MessagePoll>(poll_id);
    }
    case telegram_api::messageMediaStory::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaStory>(media_ptr);
      auto dialog_id = DialogId(media->peer_);
      auto story_id = StoryId(media->id_);
      auto story_full_id = StoryFullId(dialog_id, story_id);
      if (!story_full_id.is_server()) {
        LOG(ERROR) << "Receive " << to_string(media);
        break;
      }
      if (media->story_ != nullptr && !td->auth_manager_->is_bot()) {
        auto actual_story_id = td->story_manager_->on_get_story(dialog_id, std::move(media->story_));
        if (story_id != actual_story_id) {
          LOG(ERROR) << "Receive " << actual_story_id << " instead of " << story_id;
        }
      }
      td->dialog_manager_->force_create_dialog(dialog_id, "messageMediaStory", true);
      return make_unique<MessageStory>(story_full_id, media->via_mention_);
    }
    case telegram_api::messageMediaGiveaway::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaGiveaway>(media_ptr);
      vector<ChannelId> channel_ids;
      for (auto channel : media->channels_) {
        ChannelId channel_id(channel);
        if (channel_id.is_valid()) {
          channel_ids.push_back(channel_id);
          td->dialog_manager_->force_create_dialog(DialogId(channel_id), "messageMediaGiveaway", true);
        }
      }
      if (channel_ids.empty() || media->quantity_ <= 0 || (media->months_ <= 0 && media->stars_ <= 0) ||
          media->until_date_ < 0) {
        if (message_date >= 1700000000) {  // approximate release date
          LOG(ERROR) << "Receive " << to_string(media);
        }
        break;
      }
      auto boosted_channel_id = channel_ids[0];
      channel_ids.erase(channel_ids.begin());
      return td::make_unique<MessageGiveaway>(
          GiveawayParameters{boosted_channel_id, std::move(channel_ids), media->only_new_subscribers_,
                             media->winners_are_visible_, media->until_date_, std::move(media->countries_iso2_),
                             std::move(media->prize_description_)},
          media->quantity_, media->months_, StarManager::get_star_count(media->stars_));
    }
    case telegram_api::messageMediaGiveawayResults::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaGiveawayResults>(media_ptr);
      auto giveaway_message_id = MessageId(ServerMessageId(media->launch_msg_id_));
      auto boosted_channel_id = ChannelId(media->channel_id_);
      if (!giveaway_message_id.is_valid() || !boosted_channel_id.is_valid() || media->additional_peers_count_ < 0 ||
          (media->months_ <= 0 && media->stars_ <= 0) || media->until_date_ <= 0 || media->winners_count_ < 0 ||
          media->unclaimed_count_ < 0) {
        LOG(ERROR) << "Receive " << to_string(media);
        break;
      }
      td->dialog_manager_->force_create_dialog(DialogId(boosted_channel_id), "messageMediaGiveawayResults", true);
      vector<UserId> winner_user_ids;
      for (auto winner : media->winners_) {
        UserId winner_user_id(winner);
        if (winner_user_id.is_valid()) {
          winner_user_ids.push_back(winner_user_id);
        } else {
          LOG(ERROR) << "Receive " << to_string(media);
          break;
        }
      }
      return td::make_unique<MessageGiveawayWinners>(
          giveaway_message_id, boosted_channel_id, media->additional_peers_count_, media->months_,
          StarManager::get_star_count(media->stars_), std::move(media->prize_description_), media->until_date_,
          media->only_new_subscribers_, media->refunded_, media->winners_count_, media->unclaimed_count_,
          std::move(winner_user_ids));
    }
    case telegram_api::messageMediaPaidMedia::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaPaidMedia>(media_ptr);
      auto extended_media = transform(std::move(media->extended_media_), [&](auto &&extended_media) {
        return MessageExtendedMedia(td, std::move(extended_media), owner_dialog_id);
      });
      return td::make_unique<MessagePaidMedia>(std::move(extended_media), std::move(message),
                                               StarManager::get_star_count(media->stars_amount_), string());
    }
    case telegram_api::messageMediaUnsupported::ID:
      return make_unique<MessageUnsupported>();
    default:
      UNREACHABLE();
  }

  // explicit empty media message
  if (disable_web_page_preview != nullptr && !get_first_url(message).empty()) {
    *disable_web_page_preview = true;
  }
  return td::make_unique<MessageText>(std::move(message), WebPageId(), false, false, false, string());
}

unique_ptr<MessageContent> dup_message_content(Td *td, DialogId dialog_id, const MessageContent *content,
                                               MessageContentDupType type, MessageCopyOptions &&copy_options) {
  CHECK(content != nullptr);
  if (copy_options.send_copy) {
    CHECK(type == MessageContentDupType::Copy || type == MessageContentDupType::ServerCopy);
  }
  if (type != MessageContentDupType::Forward && type != MessageContentDupType::SendViaBot &&
      !can_message_content_have_input_media(td, content, type == MessageContentDupType::ServerCopy)) {
    return nullptr;
  }

  bool to_secret = dialog_id.get_type() == DialogType::SecretChat;
  auto fix_file_id = [dialog_id, to_secret, file_manager = td->file_manager_.get()](FileId file_id) {
    auto file_view = file_manager->get_file_view(file_id);
    if (to_secret && !file_view.is_encrypted_secret()) {
      return file_manager->copy_file_id(file_id, FileType::Encrypted, dialog_id, "copy message content to secret");
    }
    return file_id;
  };

  auto replace_caption = (type == MessageContentDupType::Copy || type == MessageContentDupType::ServerCopy) &&
                         copy_options.replace_caption;
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      auto result = make_unique<MessageAnimation>(*static_cast<const MessageAnimation *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->animations_manager_->dup_animation(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::Audio: {
      auto result = make_unique<MessageAudio>(*static_cast<const MessageAudio *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->audios_manager_->dup_audio(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::Contact:
      return make_unique<MessageContact>(*static_cast<const MessageContact *>(content));
    case MessageContentType::Dice: {
      auto result = td::make_unique<MessageDice>(*static_cast<const MessageDice *>(content));
      if (type != MessageContentDupType::Forward) {
        result->dice_value = 0;
      }
      return std::move(result);
    }
    case MessageContentType::Document: {
      auto result = make_unique<MessageDocument>(*static_cast<const MessageDocument *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->documents_manager_->dup_document(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::Game:
      return make_unique<MessageGame>(*static_cast<const MessageGame *>(content));
    case MessageContentType::Giveaway:
      if (type != MessageContentDupType::Forward) {
        return nullptr;
      }
      return make_unique<MessageGiveaway>(*static_cast<const MessageGiveaway *>(content));
    case MessageContentType::GiveawayWinners:
      if (type != MessageContentDupType::Forward) {
        return nullptr;
      }
      return make_unique<MessageGiveawayWinners>(*static_cast<const MessageGiveawayWinners *>(content));
    case MessageContentType::Invoice:
      if (type == MessageContentDupType::Copy) {
        return nullptr;
      }
      return make_unique<MessageInvoice>(*static_cast<const MessageInvoice *>(content));
    case MessageContentType::LiveLocation:
      if (!to_secret && (type == MessageContentDupType::Send || type == MessageContentDupType::SendViaBot)) {
        return make_unique<MessageLiveLocation>(*static_cast<const MessageLiveLocation *>(content));
      } else {
        return make_unique<MessageLocation>(Location(static_cast<const MessageLiveLocation *>(content)->location));
      }
    case MessageContentType::Location:
      return make_unique<MessageLocation>(*static_cast<const MessageLocation *>(content));
    case MessageContentType::PaidMedia: {
      if (type == MessageContentDupType::Copy || type == MessageContentDupType::ServerCopy) {
        return nullptr;
      }
      CHECK(!to_secret);
      auto result = make_unique<MessagePaidMedia>(*static_cast<const MessagePaidMedia *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      return std::move(result);
    }
    case MessageContentType::Photo: {
      auto result = make_unique<MessagePhoto>(*static_cast<const MessagePhoto *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }

      CHECK(!result->photo.photos.empty());
      if (!to_secret) {
        return std::move(result);
      }

      result->photo = dup_photo(result->photo);
      result->photo.photos.back().file_id = fix_file_id(result->photo.photos.back().file_id);
      return std::move(result);
    }
    case MessageContentType::Poll:
      if (type == MessageContentDupType::Copy || type == MessageContentDupType::ServerCopy) {
        return make_unique<MessagePoll>(
            td->poll_manager_->dup_poll(dialog_id, static_cast<const MessagePoll *>(content)->poll_id));
      } else {
        return make_unique<MessagePoll>(*static_cast<const MessagePoll *>(content));
      }
    case MessageContentType::Sticker: {
      auto result = make_unique<MessageSticker>(*static_cast<const MessageSticker *>(content));
      result->is_premium = td->option_manager_->get_option_boolean("is_premium");
      if (to_secret && !td->stickers_manager_->has_secret_input_media(result->file_id)) {
        auto file_id = fix_file_id(result->file_id);
        if (file_id != result->file_id) {
          result->file_id = td->stickers_manager_->dup_sticker(file_id, result->file_id);
        }
      }
      return std::move(result);
    }
    case MessageContentType::Story:
      return make_unique<MessageStory>(static_cast<const MessageStory *>(content)->story_full_id, false);
    case MessageContentType::Text: {
      auto result = td::make_unique<MessageText>(*static_cast<const MessageText *>(content));
      if (type == MessageContentDupType::Copy || type == MessageContentDupType::ServerCopy) {
        remove_unallowed_entities(td, result->text, dialog_id);
      }
      return std::move(result);
    }
    case MessageContentType::Venue:
      return make_unique<MessageVenue>(*static_cast<const MessageVenue *>(content));
    case MessageContentType::Video: {
      auto result = make_unique<MessageVideo>(*static_cast<const MessageVideo *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->videos_manager_->dup_video(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::VideoNote: {
      auto result = make_unique<MessageVideoNote>(*static_cast<const MessageVideoNote *>(content));
      result->is_viewed = false;
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->video_notes_manager_->dup_video_note(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::VoiceNote: {
      auto result = make_unique<MessageVoiceNote>(*static_cast<const MessageVoiceNote *>(content));
      if (replace_caption) {
        result->caption = std::move(copy_options.new_caption);
      }
      result->is_listened = false;
      auto file_id = fix_file_id(result->file_id);
      if (file_id != result->file_id) {
        result->file_id = td->voice_notes_manager_->dup_voice_note(file_id, result->file_id);
      }
      return std::move(result);
    }
    case MessageContentType::Unsupported:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::GiftPremium:
    case MessageContentType::TopicCreate:
    case MessageContentType::TopicEdit:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::GiftCode:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
    case MessageContentType::StarGift:
    case MessageContentType::StarGiftUnique:
      return nullptr;
    default:
      UNREACHABLE();
  }
  UNREACHABLE();
  return nullptr;
}

unique_ptr<MessageContent> get_action_message_content(Td *td, tl_object_ptr<telegram_api::MessageAction> &&action_ptr,
                                                      DialogId owner_dialog_id, int32 message_date,
                                                      const RepliedMessageInfo &replied_message_info,
                                                      bool is_business_message) {
  CHECK(action_ptr != nullptr);
  if (is_business_message) {
    switch (action_ptr->get_id()) {
      case telegram_api::messageActionEmpty::ID:
      case telegram_api::messageActionChatCreate::ID:
      case telegram_api::messageActionChatEditTitle::ID:
      case telegram_api::messageActionChatEditPhoto::ID:
      case telegram_api::messageActionChatDeletePhoto::ID:
      case telegram_api::messageActionChatAddUser::ID:
      case telegram_api::messageActionChatJoinedByLink::ID:
      case telegram_api::messageActionChatDeleteUser::ID:
      case telegram_api::messageActionChatMigrateTo::ID:
      case telegram_api::messageActionChannelCreate::ID:
      case telegram_api::messageActionChannelMigrateFrom::ID:
      case telegram_api::messageActionBotAllowed::ID:
      case telegram_api::messageActionSecureValuesSent::ID:
      case telegram_api::messageActionSecureValuesSentMe::ID:
      case telegram_api::messageActionGroupCall::ID:
      case telegram_api::messageActionInviteToGroupCall::ID:
      case telegram_api::messageActionGroupCallScheduled::ID:
      case telegram_api::messageActionChatJoinedByRequest::ID:
      case telegram_api::messageActionWebViewDataSent::ID:
      case telegram_api::messageActionWebViewDataSentMe::ID:
      case telegram_api::messageActionTopicCreate::ID:
      case telegram_api::messageActionTopicEdit::ID:
      case telegram_api::messageActionRequestedPeer::ID:
      case telegram_api::messageActionGiveawayLaunch::ID:
      case telegram_api::messageActionGiveawayResults::ID:
      case telegram_api::messageActionBoostApply::ID:
        LOG(ERROR) << "Receive business " << to_string(action_ptr);
        break;
      case telegram_api::messageActionHistoryClear::ID:
      case telegram_api::messageActionPinMessage::ID:
      case telegram_api::messageActionGameScore::ID:
      case telegram_api::messageActionPhoneCall::ID:
      case telegram_api::messageActionPaymentSent::ID:
      case telegram_api::messageActionPaymentSentMe::ID:
      case telegram_api::messageActionScreenshotTaken::ID:
      case telegram_api::messageActionCustomAction::ID:
      case telegram_api::messageActionContactSignUp::ID:
      case telegram_api::messageActionGeoProximityReached::ID:
      case telegram_api::messageActionSetMessagesTTL::ID:
      case telegram_api::messageActionSetChatTheme::ID:
      case telegram_api::messageActionGiftPremium::ID:
      case telegram_api::messageActionSuggestProfilePhoto::ID:
      case telegram_api::messageActionSetChatWallPaper::ID:
      case telegram_api::messageActionGiftCode::ID:
      case telegram_api::messageActionRequestedPeerSentMe::ID:
      case telegram_api::messageActionPaymentRefunded::ID:
      case telegram_api::messageActionGiftStars::ID:
      case telegram_api::messageActionPrizeStars::ID:
      case telegram_api::messageActionStarGift::ID:
      case telegram_api::messageActionStarGiftUnique::ID:
        // ok
        break;
      default:
        UNREACHABLE();
    }
  }
  switch (action_ptr->get_id()) {
    case telegram_api::messageActionEmpty::ID:
      LOG(ERROR) << "Receive empty message action in " << owner_dialog_id;
      break;
    case telegram_api::messageActionChatCreate::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatCreate>(action_ptr);

      vector<UserId> participant_user_ids;
      participant_user_ids.reserve(action->users_.size());
      for (auto &user : action->users_) {
        UserId user_id(user);
        if (user_id.is_valid()) {
          participant_user_ids.push_back(user_id);
        } else {
          LOG(ERROR) << "Receive messageActionChatCreate with invalid " << user_id << " in " << owner_dialog_id;
        }
      }

      return td::make_unique<MessageChatCreate>(std::move(action->title_), std::move(participant_user_ids));
    }
    case telegram_api::messageActionChatEditTitle::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatEditTitle>(action_ptr);
      return td::make_unique<MessageChatChangeTitle>(std::move(action->title_));
    }
    case telegram_api::messageActionChatEditPhoto::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatEditPhoto>(action_ptr);
      auto photo = get_photo(td, std::move(action->photo_), owner_dialog_id);
      if (photo.is_empty()) {
        break;
      }
      return make_unique<MessageChatChangePhoto>(std::move(photo));
    }
    case telegram_api::messageActionChatDeletePhoto::ID:
      return make_unique<MessageChatDeletePhoto>();
    case telegram_api::messageActionHistoryClear::ID:
      return make_unique<MessageChatDeleteHistory>();
    case telegram_api::messageActionChatAddUser::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatAddUser>(action_ptr);

      vector<UserId> user_ids;
      user_ids.reserve(action->users_.size());
      for (auto &user : action->users_) {
        UserId user_id(user);
        if (user_id.is_valid()) {
          user_ids.push_back(user_id);
        } else {
          LOG(ERROR) << "Receive messageActionChatAddUser with invalid " << user_id << " in " << owner_dialog_id;
        }
      }

      return td::make_unique<MessageChatAddUsers>(std::move(user_ids));
    }
    case telegram_api::messageActionChatJoinedByLink::ID:
      return make_unique<MessageChatJoinedByLink>(false);
    case telegram_api::messageActionChatDeleteUser::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatDeleteUser>(action_ptr);

      UserId user_id(action->user_id_);
      if (!user_id.is_valid()) {
        LOG(ERROR) << "Receive messageActionChatDeleteUser with invalid " << user_id << " in " << owner_dialog_id;
        break;
      }

      return make_unique<MessageChatDeleteUser>(user_id);
    }
    case telegram_api::messageActionChatMigrateTo::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChatMigrateTo>(action_ptr);

      ChannelId migrated_to_channel_id(action->channel_id_);
      if (!migrated_to_channel_id.is_valid()) {
        LOG(ERROR) << "Receive messageActionChatMigrateTo with invalid " << migrated_to_channel_id << " in "
                   << owner_dialog_id;
        break;
      }

      return make_unique<MessageChatMigrateTo>(migrated_to_channel_id);
    }
    case telegram_api::messageActionChannelCreate::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChannelCreate>(action_ptr);
      return td::make_unique<MessageChannelCreate>(std::move(action->title_));
    }
    case telegram_api::messageActionChannelMigrateFrom::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionChannelMigrateFrom>(action_ptr);
      ChatId chat_id(action->chat_id_);
      LOG_IF(ERROR, !chat_id.is_valid()) << "Receive messageActionChannelMigrateFrom with invalid " << chat_id << " in "
                                         << owner_dialog_id;

      return td::make_unique<MessageChannelMigrateFrom>(std::move(action->title_), chat_id);
    }
    case telegram_api::messageActionPinMessage::ID: {
      auto reply_to_message_id = replied_message_info.get_same_chat_reply_to_message_id(true);
      if (!reply_to_message_id.is_valid()) {
        // possible in basic groups
        LOG(INFO) << "Receive pinned message with " << reply_to_message_id << " in " << owner_dialog_id;
        reply_to_message_id = MessageId();
      }
      return make_unique<MessagePinMessage>(reply_to_message_id);
    }
    case telegram_api::messageActionGameScore::ID: {
      auto reply_to_message_id = replied_message_info.get_same_chat_reply_to_message_id(true);
      if (!reply_to_message_id.is_valid()) {
        // possible in basic groups
        LOG(INFO) << "Receive game score with " << reply_to_message_id << " in " << owner_dialog_id;
        reply_to_message_id = MessageId();
      }
      auto action = telegram_api::move_object_as<telegram_api::messageActionGameScore>(action_ptr);
      return make_unique<MessageGameScore>(reply_to_message_id, action->game_id_, action->score_);
    }
    case telegram_api::messageActionPhoneCall::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionPhoneCall>(action_ptr);
      auto duration = action->duration_;
      if (duration < 0) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }
      return make_unique<MessageCall>(action->call_id_, duration, get_call_discard_reason(action->reason_),
                                      action->video_);
    }
    case telegram_api::messageActionPaymentSent::ID: {
      if (!is_business_message && td->auth_manager_->is_bot()) {
        LOG(ERROR) << "Receive MessageActionPaymentSent in " << owner_dialog_id;
        break;
      }
      auto action = telegram_api::move_object_as<telegram_api::messageActionPaymentSent>(action_ptr);
      auto message_full_id = replied_message_info.get_reply_message_full_id(DialogId(), true);
      if (!message_full_id.get_message_id().is_valid()) {
        if (message_full_id.get_message_id() != MessageId()) {
          LOG(ERROR) << "Receive successful payment message with " << message_full_id << " in " << owner_dialog_id;
        }
        message_full_id = {};
      }
      if (action->total_amount_ <= 0 || !check_currency_amount(action->total_amount_)) {
        LOG(ERROR) << "Receive invalid total amount " << action->total_amount_;
        action->total_amount_ = 0;
      }
      return td::make_unique<MessagePaymentSuccessful>(
          message_full_id.get_dialog_id(), message_full_id.get_message_id(), std::move(action->currency_),
          action->total_amount_, std::move(action->invoice_slug_), action->subscription_until_date_,
          action->recurring_used_, action->recurring_init_);
    }
    case telegram_api::messageActionPaymentSentMe::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionPaymentSentMe>(action_ptr);
      if (action->total_amount_ <= 0 || !check_currency_amount(action->total_amount_)) {
        LOG(ERROR) << "Receive invalid total amount " << action->total_amount_;
        action->total_amount_ = 0;
      }
      auto result = td::make_unique<MessagePaymentSuccessful>(DialogId(), MessageId(), std::move(action->currency_),
                                                              action->total_amount_, action->payload_.as_slice().str(),
                                                              action->subscription_until_date_, action->recurring_used_,
                                                              action->recurring_init_);
      result->shipping_option_id = std::move(action->shipping_option_id_);
      result->order_info = get_order_info(std::move(action->info_));
      result->telegram_payment_charge_id = std::move(action->charge_->id_);
      result->provider_payment_charge_id = std::move(action->charge_->provider_charge_id_);
      return std::move(result);
    }
    case telegram_api::messageActionScreenshotTaken::ID:
      return make_unique<MessageScreenshotTaken>();
    case telegram_api::messageActionCustomAction::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionCustomAction>(action_ptr);
      return td::make_unique<MessageCustomServiceAction>(std::move(action->message_));
    }
    case telegram_api::messageActionBotAllowed::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionBotAllowed>(action_ptr);
      if (action->attach_menu_) {
        return td::make_unique<MessageWriteAccessAllowed>();
      }
      if (!action->domain_.empty()) {
        return td::make_unique<MessageWebsiteConnected>(std::move(action->domain_));
      }
      if (action->app_ != nullptr && action->app_->get_id() == telegram_api::botApp::ID) {
        return td::make_unique<MessageWebViewWriteAccessAllowed>(
            WebApp(td, telegram_api::move_object_as<telegram_api::botApp>(action->app_), owner_dialog_id));
      }
      if (action->from_request_) {
        return td::make_unique<MessageWriteAccessAllowedByRequest>();
      }
      return td::make_unique<MessageUnsupported>();
    }
    case telegram_api::messageActionSecureValuesSent::ID: {
      LOG_IF(ERROR, td->auth_manager_->is_bot()) << "Receive MessageActionSecureValuesSent in " << owner_dialog_id;
      auto action = telegram_api::move_object_as<telegram_api::messageActionSecureValuesSent>(action_ptr);
      return td::make_unique<MessagePassportDataSent>(get_secure_value_types(action->types_));
    }
    case telegram_api::messageActionSecureValuesSentMe::ID: {
      LOG_IF(ERROR, !td->auth_manager_->is_bot()) << "Receive MessageActionSecureValuesSentMe in " << owner_dialog_id;
      auto action = telegram_api::move_object_as<telegram_api::messageActionSecureValuesSentMe>(action_ptr);
      return td::make_unique<MessagePassportDataReceived>(
          get_encrypted_secure_values(td->file_manager_.get(), std::move(action->values_)),
          get_encrypted_secure_credentials(std::move(action->credentials_)));
    }
    case telegram_api::messageActionContactSignUp::ID:
      if (!is_business_message && td->auth_manager_->is_bot()) {
        LOG(ERROR) << "Receive ContactRegistered in " << owner_dialog_id;
      }
      return td::make_unique<MessageContactRegistered>();
    case telegram_api::messageActionGeoProximityReached::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGeoProximityReached>(action_ptr);
      DialogId traveler_id(action->from_id_);
      DialogId watcher_id(action->to_id_);
      int32 distance = action->distance_;
      if (!traveler_id.is_valid() || !watcher_id.is_valid() || distance < 0) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }

      return make_unique<MessageProximityAlertTriggered>(traveler_id, watcher_id, distance);
    }
    case telegram_api::messageActionGroupCall::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGroupCall>(action_ptr);
      int32 duration = -1;
      if ((action->flags_ & telegram_api::messageActionGroupCall::DURATION_MASK) != 0) {
        duration = action->duration_;
        if (duration < 0) {
          LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
          break;
        }
      }
      return make_unique<MessageGroupCall>(InputGroupCallId(action->call_), duration, -1);
    }
    case telegram_api::messageActionInviteToGroupCall::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionInviteToGroupCall>(action_ptr);

      vector<UserId> user_ids;
      user_ids.reserve(action->users_.size());
      for (auto &user : action->users_) {
        UserId user_id(user);
        if (user_id.is_valid()) {
          user_ids.push_back(user_id);
        } else {
          LOG(ERROR) << "Receive messageActionInviteToGroupCall with invalid " << user_id << " in " << owner_dialog_id;
        }
      }

      return td::make_unique<MessageInviteToGroupCall>(InputGroupCallId(action->call_), std::move(user_ids));
    }
    case telegram_api::messageActionSetMessagesTTL::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionSetMessagesTTL>(action_ptr);
      UserId from_user_id(action->auto_setting_from_);
      if (action->period_ < 0 || !(from_user_id == UserId() || from_user_id.is_valid())) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }
      return make_unique<MessageChatSetTtl>(action->period_, from_user_id);
    }
    case telegram_api::messageActionGroupCallScheduled::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGroupCallScheduled>(action_ptr);
      if (action->schedule_date_ <= 0) {
        LOG(ERROR) << "Receive wrong schedule_date = " << action->schedule_date_;
        break;
      }
      return make_unique<MessageGroupCall>(InputGroupCallId(action->call_), -1, action->schedule_date_);
    }
    case telegram_api::messageActionSetChatTheme::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionSetChatTheme>(action_ptr);
      return td::make_unique<MessageChatSetTheme>(std::move(action->emoticon_));
    }
    case telegram_api::messageActionChatJoinedByRequest::ID:
      return make_unique<MessageChatJoinedByLink>(true);
    case telegram_api::messageActionWebViewDataSent::ID: {
      if (td->auth_manager_->is_bot()) {
        LOG(ERROR) << "Receive messageActionWebViewDataSent in " << owner_dialog_id;
        break;
      }
      auto action = telegram_api::move_object_as<telegram_api::messageActionWebViewDataSent>(action_ptr);
      return td::make_unique<MessageWebViewDataSent>(std::move(action->text_));
    }
    case telegram_api::messageActionWebViewDataSentMe::ID: {
      if (!td->auth_manager_->is_bot()) {
        LOG(ERROR) << "Receive messageActionWebViewDataSentMe in " << owner_dialog_id;
        break;
      }
      auto action = telegram_api::move_object_as<telegram_api::messageActionWebViewDataSentMe>(action_ptr);
      return td::make_unique<MessageWebViewDataReceived>(std::move(action->text_), std::move(action->data_));
    }
    case telegram_api::messageActionGiftPremium::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGiftPremium>(action_ptr);
      if (action->amount_ <= 0 || !check_currency_amount(action->amount_)) {
        LOG(ERROR) << "Receive invalid premium gift price " << action->amount_;
        action->amount_ = 0;
      }
      if (action->crypto_currency_.empty()) {
        if (action->crypto_amount_ != 0) {
          LOG(ERROR) << "Receive premium gift crypto price " << action->crypto_amount_ << " without currency";
          action->crypto_amount_ = 0;
        }
      } else if (action->crypto_amount_ <= 0) {
        LOG(ERROR) << "Receive invalid premium gift crypto amount " << action->crypto_amount_;
        action->crypto_amount_ = 0;
      }
      auto text = get_formatted_text(td->user_manager_.get(), std::move(action->message_), true, false,
                                     "messageActionGiftPremium");
      return td::make_unique<MessageGiftPremium>(std::move(text), std::move(action->currency_), action->amount_,
                                                 std::move(action->crypto_currency_), action->crypto_amount_,
                                                 action->months_);
    }
    case telegram_api::messageActionTopicCreate::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionTopicCreate>(action_ptr);
      return td::make_unique<MessageTopicCreate>(std::move(action->title_),
                                                 ForumTopicIcon(action->icon_color_, action->icon_emoji_id_));
    }
    case telegram_api::messageActionTopicEdit::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionTopicEdit>(action_ptr);
      auto edit_icon_custom_emoji_id = (action->flags_ & telegram_api::messageActionTopicEdit::ICON_EMOJI_ID_MASK) != 0;
      auto edit_is_closed = (action->flags_ & telegram_api::messageActionTopicEdit::CLOSED_MASK) != 0;
      auto edit_is_hidden = (action->flags_ & telegram_api::messageActionTopicEdit::HIDDEN_MASK) != 0;
      return td::make_unique<MessageTopicEdit>(
          ForumTopicEditedData{std::move(action->title_), edit_icon_custom_emoji_id, action->icon_emoji_id_,
                               edit_is_closed, action->closed_, edit_is_hidden, action->hidden_});
    }
    case telegram_api::messageActionSuggestProfilePhoto::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionSuggestProfilePhoto>(action_ptr);
      auto photo = get_photo(td, std::move(action->photo_), owner_dialog_id);
      if (photo.is_empty()) {
        break;
      }
      return make_unique<MessageSuggestProfilePhoto>(std::move(photo));
    }
    case telegram_api::messageActionRequestedPeer::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionRequestedPeer>(action_ptr);
      vector<DialogId> shared_dialog_ids;
      for (const auto &peer : action->peers_) {
        DialogId dialog_id(peer);
        if (dialog_id.is_valid()) {
          shared_dialog_ids.push_back(dialog_id);
        }
      }
      if (shared_dialog_ids.size() > 1) {
        for (auto dialog_id : shared_dialog_ids) {
          if (dialog_id.get_type() != DialogType::User) {
            shared_dialog_ids.clear();
            break;
          }
        }
      }
      if (shared_dialog_ids.empty() || shared_dialog_ids.size() != action->peers_.size()) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }

      return td::make_unique<MessageRequestedDialog>(std::move(shared_dialog_ids), action->button_id_);
    }
    case telegram_api::messageActionSetChatWallPaper::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionSetChatWallPaper>(action_ptr);
      BackgroundInfo background_info(td, std::move(action->wallpaper_), true);
      if (!background_info.is_valid()) {
        break;
      }
      auto reply_to_message_id = replied_message_info.get_same_chat_reply_to_message_id(true);
      if (!reply_to_message_id.is_valid() || !action->same_) {
        reply_to_message_id = MessageId();
      }
      return make_unique<MessageSetBackground>(reply_to_message_id, std::move(background_info), action->for_both_);
    }
    case telegram_api::messageActionGiveawayLaunch::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGiveawayLaunch>(action_ptr);
      return td::make_unique<MessageGiveawayLaunch>(StarManager::get_star_count(action->stars_));
    }
    case telegram_api::messageActionGiftCode::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGiftCode>(action_ptr);
      DialogId dialog_id;
      if (action->boost_peer_ != nullptr) {
        dialog_id = DialogId(action->boost_peer_);
        if (!dialog_id.is_valid()) {
          LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
          break;
        }
        if (dialog_id.get_type() != DialogType::User) {
          td->dialog_manager_->force_create_dialog(dialog_id, "messageActionGiftCode", true);
        }
      }
      auto text = get_formatted_text(td->user_manager_.get(), std::move(action->message_), true, false,
                                     "messageActionGiftCode");
      return td::make_unique<MessageGiftCode>(dialog_id, std::move(text), action->months_, std::move(action->currency_),
                                              action->amount_, std::move(action->crypto_currency_),
                                              action->crypto_amount_, action->via_giveaway_, action->unclaimed_,
                                              std::move(action->slug_));
    }
    case telegram_api::messageActionGiveawayResults::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGiveawayResults>(action_ptr);
      auto reply_to_message_id = replied_message_info.get_same_chat_reply_to_message_id(true);
      if (!reply_to_message_id.is_valid() && reply_to_message_id != MessageId()) {
        LOG(ERROR) << "Receive giveaway results message with " << reply_to_message_id << " in " << owner_dialog_id;
        reply_to_message_id = MessageId();
      }
      return td::make_unique<MessageGiveawayResults>(reply_to_message_id, action->winners_count_,
                                                     action->unclaimed_count_,
                                                     StarManager::get_star_count(action->stars_));
    }
    case telegram_api::messageActionBoostApply::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionBoostApply>(action_ptr);
      return make_unique<MessageBoostApply>(max(action->boosts_, 0));
    }
    case telegram_api::messageActionRequestedPeerSentMe::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionRequestedPeerSentMe>(action_ptr);
      vector<SharedDialog> shared_dialogs;
      for (auto &peer : action->peers_) {
        SharedDialog shared_dialog(td, std::move(peer));
        if (shared_dialog.is_valid()) {
          shared_dialogs.push_back(std::move(shared_dialog));
        }
      }
      if (shared_dialogs.size() > 1) {
        for (auto shared_dialog : shared_dialogs) {
          if (!shared_dialog.is_user()) {
            shared_dialogs.clear();
            break;
          }
        }
      }
      if (shared_dialogs.empty() || shared_dialogs.size() != action->peers_.size()) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }

      return td::make_unique<MessageDialogShared>(std::move(shared_dialogs), action->button_id_);
    }
    case telegram_api::messageActionPaymentRefunded::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionPaymentRefunded>(action_ptr);
      if (action->total_amount_ <= 0 || !check_currency_amount(action->total_amount_)) {
        LOG(ERROR) << "Receive invalid refunded payment amount " << action->total_amount_;
        action->total_amount_ = 0;
      }
      return td::make_unique<MessagePaymentRefunded>(DialogId(action->peer_), std::move(action->currency_),
                                                     action->total_amount_, action->payload_.as_slice().str(),
                                                     std::move(action->charge_->id_),
                                                     std::move(action->charge_->provider_charge_id_));
    }
    case telegram_api::messageActionGiftStars::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionGiftStars>(action_ptr);
      if (action->amount_ <= 0 || !check_currency_amount(action->amount_)) {
        LOG(ERROR) << "Receive invalid gifted star price " << action->amount_;
        action->amount_ = 0;
      }
      if (action->crypto_currency_.empty()) {
        if (action->crypto_amount_ != 0) {
          LOG(ERROR) << "Receive gifted star crypto price " << action->crypto_amount_ << " without currency";
          action->crypto_amount_ = 0;
        }
      } else if (action->crypto_amount_ <= 0) {
        LOG(ERROR) << "Receive invalid gifted star crypto amount " << action->crypto_amount_;
        action->crypto_amount_ = 0;
      }
      return td::make_unique<MessageGiftStars>(
          std::move(action->currency_), action->amount_, std::move(action->crypto_currency_), action->crypto_amount_,
          StarManager::get_star_count(action->stars_), std::move(action->transaction_id_));
    }
    case telegram_api::messageActionPrizeStars::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionPrizeStars>(action_ptr);
      DialogId boosted_dialog_id = DialogId(action->boost_peer_);
      if (!boosted_dialog_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << oneline(to_string(action));
        break;
      }
      td->dialog_manager_->force_create_dialog(boosted_dialog_id, "messageActionPrizeStars", true);
      return td::make_unique<MessagePrizeStars>(
          StarManager::get_star_count(action->stars_), std::move(action->transaction_id_), boosted_dialog_id,
          MessageId(ServerMessageId(action->giveaway_msg_id_)), action->unclaimed_);
    }
    case telegram_api::messageActionStarGift::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionStarGift>(action_ptr);
      StarGift star_gift(td, std::move(action->gift_), false);
      if (!star_gift.is_valid() || star_gift.is_unique()) {
        break;
      }
      auto upgrade_message_id = MessageId(ServerMessageId(action->upgrade_msg_id_));
      if (upgrade_message_id != MessageId() && !upgrade_message_id.is_valid()) {
        LOG(ERROR) << "Receive " << upgrade_message_id;
        upgrade_message_id = MessageId();
      }
      FormattedText text = get_formatted_text(td->user_manager_.get(), std::move(action->message_), true, false,
                                              "messageActionStarGift");
      DialogId gift_sender_dialog_id;
      DialogId gift_owner_dialog_id;
      int64 saved_id = 0;
      if (action->from_id_ != nullptr) {
        gift_sender_dialog_id = DialogId(action->from_id_);
      }
      if (action->peer_ != nullptr) {
        gift_owner_dialog_id = DialogId(action->peer_);
        saved_id = action->saved_id_;
      }
      return td::make_unique<MessageStarGift>(
          std::move(star_gift), gift_sender_dialog_id, gift_owner_dialog_id, saved_id, std::move(text),
          StarManager::get_star_count(action->convert_stars_), StarManager::get_star_count(action->upgrade_stars_),
          upgrade_message_id, action->name_hidden_, action->saved_, action->can_upgrade_, action->converted_,
          action->upgraded_, action->refunded_);
    }
    case telegram_api::messageActionStarGiftUnique::ID: {
      auto action = telegram_api::move_object_as<telegram_api::messageActionStarGiftUnique>(action_ptr);
      StarGift star_gift(td, std::move(action->gift_), true);
      if (!star_gift.is_valid() || star_gift.is_unique() == action->refunded_) {
        break;
      }
      DialogId gift_sender_dialog_id;
      DialogId gift_owner_dialog_id;
      int64 saved_id = 0;
      if (action->from_id_ != nullptr) {
        gift_sender_dialog_id = DialogId(action->from_id_);
      }
      if (action->peer_ != nullptr) {
        gift_owner_dialog_id = DialogId(action->peer_);
        saved_id = action->saved_id_;
      }
      return td::make_unique<MessageStarGiftUnique>(
          std::move(star_gift), gift_sender_dialog_id, gift_owner_dialog_id, saved_id,
          StarManager::get_star_count(action->transfer_stars_), max(0, action->can_export_at_), action->saved_,
          action->upgrade_, (action->flags_ & telegram_api::messageActionStarGiftUnique::TRANSFER_STARS_MASK) != 0,
          action->transferred_, action->refunded_);
    }
    default:
      UNREACHABLE();
  }
  // explicit empty or wrong action
  return td::make_unique<MessageText>(FormattedText(), WebPageId(), false, false, false, string());
}

td_api::object_ptr<td_api::MessageContent> get_message_content_object(const MessageContent *content, Td *td,
                                                                      DialogId dialog_id, MessageId message_id,
                                                                      bool is_outgoing, int32 message_date,
                                                                      bool is_content_secret, bool skip_bot_commands,
                                                                      int32 max_media_timestamp, bool invert_media,
                                                                      bool disable_web_page_preview) {
  CHECK(content != nullptr);
  auto is_server =
      message_id != MessageId() && message_id.is_any_server() && dialog_id.get_type() != DialogType::SecretChat;
  auto get_text_object = [&](const FormattedText &text) {
    return get_formatted_text_object(is_server ? td->user_manager_.get() : nullptr, text, skip_bot_commands,
                                     max_media_timestamp);
  };
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      const auto *m = static_cast<const MessageAnimation *>(content);
      return make_tl_object<td_api::messageAnimation>(td->animations_manager_->get_animation_object(m->file_id),
                                                      get_text_object(m->caption), invert_media, m->has_spoiler,
                                                      is_content_secret);
    }
    case MessageContentType::Audio: {
      const auto *m = static_cast<const MessageAudio *>(content);
      return make_tl_object<td_api::messageAudio>(td->audios_manager_->get_audio_object(m->file_id),
                                                  get_text_object(m->caption));
    }
    case MessageContentType::Contact: {
      const auto *m = static_cast<const MessageContact *>(content);
      return make_tl_object<td_api::messageContact>(m->contact.get_contact_object(td));
    }
    case MessageContentType::Document: {
      const auto *m = static_cast<const MessageDocument *>(content);
      return make_tl_object<td_api::messageDocument>(
          td->documents_manager_->get_document_object(m->file_id, PhotoFormat::Jpeg), get_text_object(m->caption));
    }
    case MessageContentType::Game: {
      const auto *m = static_cast<const MessageGame *>(content);
      return make_tl_object<td_api::messageGame>(m->game.get_game_object(td, is_server, skip_bot_commands));
    }
    case MessageContentType::Invoice: {
      const auto *m = static_cast<const MessageInvoice *>(content);
      return m->input_invoice.get_message_invoice_object(td, is_server, skip_bot_commands, max_media_timestamp);
    }
    case MessageContentType::LiveLocation: {
      const auto *m = static_cast<const MessageLiveLocation *>(content);
      auto passed = max(G()->unix_time() - message_date, 0);
      auto expires_in = m->period == std::numeric_limits<int32>::max() ? m->period : max(0, m->period - passed);
      auto heading = expires_in == 0 ? 0 : m->heading;
      auto proximity_alert_radius = expires_in == 0 ? 0 : m->proximity_alert_radius;
      return make_tl_object<td_api::messageLocation>(m->location.get_location_object(), m->period, expires_in, heading,
                                                     proximity_alert_radius);
    }
    case MessageContentType::Location: {
      const auto *m = static_cast<const MessageLocation *>(content);
      return make_tl_object<td_api::messageLocation>(m->location.get_location_object(), 0, 0, 0, 0);
    }
    case MessageContentType::Photo: {
      const auto *m = static_cast<const MessagePhoto *>(content);
      auto photo = get_photo_object(td->file_manager_.get(), m->photo);
      if (photo == nullptr) {
        LOG(ERROR) << "Have empty " << m->photo;
        return make_tl_object<td_api::messageExpiredPhoto>();
      }
      return make_tl_object<td_api::messagePhoto>(std::move(photo), get_text_object(m->caption), invert_media,
                                                  m->has_spoiler, is_content_secret);
    }
    case MessageContentType::Sticker: {
      const auto *m = static_cast<const MessageSticker *>(content);
      auto sticker = td->stickers_manager_->get_sticker_object(m->file_id);
      CHECK(sticker != nullptr);
      auto is_premium =
          m->is_premium && sticker->full_type_->get_id() == td_api::stickerFullTypeRegular::ID &&
          static_cast<const td_api::stickerFullTypeRegular *>(sticker->full_type_.get())->premium_animation_ != nullptr;
      return make_tl_object<td_api::messageSticker>(std::move(sticker), is_premium);
    }
    case MessageContentType::Text: {
      const auto *m = static_cast<const MessageText *>(content);
      if (can_be_animated_emoji(m->text) && !m->web_page_id.is_valid()) {
        auto animated_emoji =
            td->stickers_manager_->get_animated_emoji_object(m->text.text, get_custom_emoji_id(m->text));
        if (animated_emoji != nullptr) {
          return td_api::make_object<td_api::messageAnimatedEmoji>(std::move(animated_emoji), m->text.text);
        }
      }
      auto web_page = td->web_pages_manager_->get_link_preview_object(
          m->web_page_id, m->force_small_media, m->force_large_media, m->skip_web_page_confirmation, invert_media);
      if (web_page != nullptr && !web_page->skip_confirmation_ && is_visible_url(m->text, web_page->url_)) {
        web_page->skip_confirmation_ = true;
      }
      if (web_page == nullptr && get_first_url(m->text).empty()) {
        disable_web_page_preview = false;
      } else if (disable_web_page_preview && web_page != nullptr) {
        LOG(ERROR) << "Have " << m->web_page_id << " in a message with link preview disabled";
        web_page = nullptr;
      }
      td_api::object_ptr<td_api::linkPreviewOptions> link_preview_options;
      if (disable_web_page_preview || !m->web_page_url.empty() || m->force_small_media || m->force_large_media ||
          invert_media) {
        link_preview_options = td_api::make_object<td_api::linkPreviewOptions>(
            disable_web_page_preview, m->web_page_url, m->force_small_media, m->force_large_media, invert_media);
      }
      return make_tl_object<td_api::messageText>(get_text_object(m->text), std::move(web_page),
                                                 std::move(link_preview_options));
    }
    case MessageContentType::Unsupported:
      return make_tl_object<td_api::messageUnsupported>();
    case MessageContentType::Venue: {
      const auto *m = static_cast<const MessageVenue *>(content);
      return make_tl_object<td_api::messageVenue>(m->venue.get_venue_object());
    }
    case MessageContentType::Video: {
      const auto *m = static_cast<const MessageVideo *>(content);
      vector<td_api::object_ptr<td_api::alternativeVideo>> alternative_videos;
      if (!td->option_manager_->get_option_boolean("video_ignore_alt_documents")) {
        for (auto file_id : m->alternative_file_ids) {
          auto video = td->videos_manager_->get_alternative_video_object(file_id, m->hls_file_ids);
          if (video != nullptr) {
            alternative_videos.push_back(std::move(video));
          }
        }
      }
      return make_tl_object<td_api::messageVideo>(
          td->videos_manager_->get_video_object(m->file_id), std::move(alternative_videos),
          get_photo_object(td->file_manager_.get(), m->cover), m->start_timestamp, get_text_object(m->caption),
          invert_media, m->has_spoiler, is_content_secret);
    }
    case MessageContentType::VideoNote: {
      const auto *m = static_cast<const MessageVideoNote *>(content);
      return make_tl_object<td_api::messageVideoNote>(td->video_notes_manager_->get_video_note_object(m->file_id),
                                                      m->is_viewed, is_content_secret);
    }
    case MessageContentType::VoiceNote: {
      const auto *m = static_cast<const MessageVoiceNote *>(content);
      return make_tl_object<td_api::messageVoiceNote>(td->voice_notes_manager_->get_voice_note_object(m->file_id),
                                                      get_text_object(m->caption), m->is_listened);
    }
    case MessageContentType::ChatCreate: {
      const auto *m = static_cast<const MessageChatCreate *>(content);
      return make_tl_object<td_api::messageBasicGroupChatCreate>(
          m->title, td->user_manager_->get_user_ids_object(m->participant_user_ids, "MessageChatCreate"));
    }
    case MessageContentType::ChatChangeTitle: {
      const auto *m = static_cast<const MessageChatChangeTitle *>(content);
      return make_tl_object<td_api::messageChatChangeTitle>(m->title);
    }
    case MessageContentType::ChatChangePhoto: {
      const auto *m = static_cast<const MessageChatChangePhoto *>(content);
      auto photo = get_chat_photo_object(td->file_manager_.get(), m->photo);
      if (photo == nullptr) {
        LOG(ERROR) << "Have empty chat " << m->photo;
        return make_tl_object<td_api::messageChatDeletePhoto>();
      }
      return make_tl_object<td_api::messageChatChangePhoto>(std::move(photo));
    }
    case MessageContentType::ChatDeletePhoto:
      return make_tl_object<td_api::messageChatDeletePhoto>();
    case MessageContentType::ChatDeleteHistory:
      return make_tl_object<td_api::messageUnsupported>();
    case MessageContentType::ChatAddUsers: {
      const auto *m = static_cast<const MessageChatAddUsers *>(content);
      return make_tl_object<td_api::messageChatAddMembers>(
          td->user_manager_->get_user_ids_object(m->user_ids, "MessageChatAddUsers"));
    }
    case MessageContentType::ChatJoinedByLink: {
      const MessageChatJoinedByLink *m = static_cast<const MessageChatJoinedByLink *>(content);
      if (m->is_approved) {
        return make_tl_object<td_api::messageChatJoinByRequest>();
      }
      return make_tl_object<td_api::messageChatJoinByLink>();
    }
    case MessageContentType::ChatDeleteUser: {
      const auto *m = static_cast<const MessageChatDeleteUser *>(content);
      return make_tl_object<td_api::messageChatDeleteMember>(
          td->user_manager_->get_user_id_object(m->user_id, "MessageChatDeleteMember"));
    }
    case MessageContentType::ChatMigrateTo: {
      const auto *m = static_cast<const MessageChatMigrateTo *>(content);
      return make_tl_object<td_api::messageChatUpgradeTo>(
          td->chat_manager_->get_supergroup_id_object(m->migrated_to_channel_id, "MessageChatUpgradeTo"));
    }
    case MessageContentType::ChannelCreate: {
      const auto *m = static_cast<const MessageChannelCreate *>(content);
      return make_tl_object<td_api::messageSupergroupChatCreate>(m->title);
    }
    case MessageContentType::ChannelMigrateFrom: {
      const auto *m = static_cast<const MessageChannelMigrateFrom *>(content);
      return make_tl_object<td_api::messageChatUpgradeFrom>(
          m->title, td->chat_manager_->get_basic_group_id_object(m->migrated_from_chat_id, "MessageChatUpgradeFrom"));
    }
    case MessageContentType::PinMessage: {
      const auto *m = static_cast<const MessagePinMessage *>(content);
      return make_tl_object<td_api::messagePinMessage>(m->message_id.get());
    }
    case MessageContentType::GameScore: {
      const auto *m = static_cast<const MessageGameScore *>(content);
      return make_tl_object<td_api::messageGameScore>(m->game_message_id.get(), m->game_id, m->score);
    }
    case MessageContentType::ScreenshotTaken:
      return make_tl_object<td_api::messageScreenshotTaken>();
    case MessageContentType::ChatSetTtl: {
      const auto *m = static_cast<const MessageChatSetTtl *>(content);
      return make_tl_object<td_api::messageChatSetMessageAutoDeleteTime>(
          m->ttl, td->user_manager_->get_user_id_object(m->from_user_id, "MessageChatSetTtl"));
    }
    case MessageContentType::Call: {
      const auto *m = static_cast<const MessageCall *>(content);
      return make_tl_object<td_api::messageCall>(m->is_video, get_call_discard_reason_object(m->discard_reason),
                                                 m->duration);
    }
    case MessageContentType::PaymentSuccessful: {
      const auto *m = static_cast<const MessagePaymentSuccessful *>(content);
      if (!m->telegram_payment_charge_id.empty() || !m->provider_payment_charge_id.empty()) {
        return make_tl_object<td_api::messagePaymentSuccessfulBot>(
            m->currency, m->total_amount, m->subscription_until_date, m->is_recurring, m->is_first_recurring,
            m->invoice_payload, m->shipping_option_id, get_order_info_object(m->order_info),
            m->telegram_payment_charge_id, m->provider_payment_charge_id);
      } else {
        auto invoice_dialog_id = m->invoice_dialog_id.is_valid() ? m->invoice_dialog_id : dialog_id;
        return make_tl_object<td_api::messagePaymentSuccessful>(
            td->dialog_manager_->get_chat_id_object(invoice_dialog_id, "messagePaymentSuccessful"),
            m->invoice_message_id.get(), m->currency, m->total_amount, m->subscription_until_date, m->is_recurring,
            m->is_first_recurring, m->invoice_payload);
      }
    }
    case MessageContentType::ContactRegistered:
      return make_tl_object<td_api::messageContactRegistered>();
    case MessageContentType::ExpiredPhoto:
      return make_tl_object<td_api::messageExpiredPhoto>();
    case MessageContentType::ExpiredVideo:
      return make_tl_object<td_api::messageExpiredVideo>();
    case MessageContentType::CustomServiceAction: {
      const auto *m = static_cast<const MessageCustomServiceAction *>(content);
      return make_tl_object<td_api::messageCustomServiceAction>(m->message);
    }
    case MessageContentType::WebsiteConnected: {
      const auto *m = static_cast<const MessageWebsiteConnected *>(content);
      return td_api::make_object<td_api::messageBotWriteAccessAllowed>(
          td_api::make_object<td_api::botWriteAccessAllowReasonConnectedWebsite>(m->domain_name));
    }
    case MessageContentType::PassportDataSent: {
      const auto *m = static_cast<const MessagePassportDataSent *>(content);
      return make_tl_object<td_api::messagePassportDataSent>(get_passport_element_types_object(m->types));
    }
    case MessageContentType::PassportDataReceived: {
      const auto *m = static_cast<const MessagePassportDataReceived *>(content);
      return make_tl_object<td_api::messagePassportDataReceived>(
          get_encrypted_passport_element_object(td->file_manager_.get(), m->values),
          get_encrypted_credentials_object(m->credentials));
    }
    case MessageContentType::Poll: {
      const auto *m = static_cast<const MessagePoll *>(content);
      return make_tl_object<td_api::messagePoll>(td->poll_manager_->get_poll_object(m->poll_id));
    }
    case MessageContentType::Dice: {
      const auto *m = static_cast<const MessageDice *>(content);
      auto initial_state = td->stickers_manager_->get_dice_stickers_object(m->emoji, 0);
      auto final_state =
          m->dice_value == 0 ? nullptr : td->stickers_manager_->get_dice_stickers_object(m->emoji, m->dice_value);
      auto success_animation_frame_number =
          td->stickers_manager_->get_dice_success_animation_frame_number(m->emoji, m->dice_value);
      return make_tl_object<td_api::messageDice>(std::move(initial_state), std::move(final_state), m->emoji,
                                                 m->dice_value, success_animation_frame_number);
    }
    case MessageContentType::ProximityAlertTriggered: {
      const auto *m = static_cast<const MessageProximityAlertTriggered *>(content);
      return make_tl_object<td_api::messageProximityAlertTriggered>(
          get_message_sender_object(td, m->traveler_dialog_id, "messageProximityAlertTriggered 1"),
          get_message_sender_object(td, m->watcher_dialog_id, "messageProximityAlertTriggered 2"), m->distance);
    }
    case MessageContentType::GroupCall: {
      const auto *m = static_cast<const MessageGroupCall *>(content);
      if (m->duration >= 0) {
        return make_tl_object<td_api::messageVideoChatEnded>(m->duration);
      } else {
        auto group_call_id = td->group_call_manager_->get_group_call_id(m->input_group_call_id, DialogId()).get();
        if (m->schedule_date > 0) {
          return make_tl_object<td_api::messageVideoChatScheduled>(group_call_id, m->schedule_date);
        } else {
          return make_tl_object<td_api::messageVideoChatStarted>(group_call_id);
        }
      }
    }
    case MessageContentType::InviteToGroupCall: {
      const auto *m = static_cast<const MessageInviteToGroupCall *>(content);
      return make_tl_object<td_api::messageInviteVideoChatParticipants>(
          td->group_call_manager_->get_group_call_id(m->input_group_call_id, DialogId()).get(),
          td->user_manager_->get_user_ids_object(m->user_ids, "MessageInviteToGroupCall"));
    }
    case MessageContentType::ChatSetTheme: {
      const auto *m = static_cast<const MessageChatSetTheme *>(content);
      return make_tl_object<td_api::messageChatSetTheme>(m->emoji);
    }
    case MessageContentType::WebViewDataSent: {
      const auto *m = static_cast<const MessageWebViewDataSent *>(content);
      return make_tl_object<td_api::messageWebAppDataSent>(m->button_text);
    }
    case MessageContentType::WebViewDataReceived: {
      const auto *m = static_cast<const MessageWebViewDataReceived *>(content);
      return make_tl_object<td_api::messageWebAppDataReceived>(m->button_text, m->data);
    }
    case MessageContentType::GiftPremium: {
      const auto *m = static_cast<const MessageGiftPremium *>(content);
      int64 gifter_user_id = 0;
      int64 receiver_user_id = 0;
      if (dialog_id.get_type() == DialogType::User) {
        auto user_id = dialog_id.get_user_id();
        if (is_outgoing) {
          receiver_user_id = td->user_manager_->get_user_id_object(user_id, "MessageGiftPremium 2");
        } else {
          if (user_id != UserManager::get_service_notifications_user_id() && !td->user_manager_->is_user_bot(user_id) &&
              !td->user_manager_->is_user_support(user_id)) {
            gifter_user_id = td->user_manager_->get_user_id_object(user_id, "MessageGiftPremium 3");
          }
        }
      } else {
        LOG(ERROR) << "Receive gifted premium in " << dialog_id;
      }
      return td_api::make_object<td_api::messageGiftedPremium>(
          gifter_user_id, receiver_user_id, get_text_object(m->text), m->currency, m->amount, m->crypto_currency,
          m->crypto_amount, m->months, td->stickers_manager_->get_premium_gift_sticker_object(m->months, 0));
    }
    case MessageContentType::TopicCreate: {
      const auto *m = static_cast<const MessageTopicCreate *>(content);
      return td_api::make_object<td_api::messageForumTopicCreated>(m->title, m->icon.get_forum_topic_icon_object());
    }
    case MessageContentType::TopicEdit: {
      const auto *m = static_cast<const MessageTopicEdit *>(content);
      return m->edited_data.get_message_content_object();
    }
    case MessageContentType::SuggestProfilePhoto: {
      const auto *m = static_cast<const MessageSuggestProfilePhoto *>(content);
      auto photo = get_chat_photo_object(td->file_manager_.get(), m->photo);
      if (photo == nullptr) {
        LOG(ERROR) << "Have empty suggested profile " << m->photo;
        return make_tl_object<td_api::messageUnsupported>();
      }
      return make_tl_object<td_api::messageSuggestProfilePhoto>(std::move(photo));
    }
    case MessageContentType::WriteAccessAllowed:
      return td_api::make_object<td_api::messageBotWriteAccessAllowed>(
          td_api::make_object<td_api::botWriteAccessAllowReasonAddedToAttachmentMenu>());
    case MessageContentType::RequestedDialog: {
      const auto *m = static_cast<const MessageRequestedDialog *>(content);
      CHECK(!m->shared_dialog_ids.empty());
      if (m->shared_dialog_ids[0].get_type() == DialogType::User) {
        vector<td_api::object_ptr<td_api::sharedUser>> users;
        for (auto shared_dialog_id : m->shared_dialog_ids) {
          users.push_back(SharedDialog(shared_dialog_id).get_shared_user_object(td));
        }
        return make_tl_object<td_api::messageUsersShared>(std::move(users), m->button_id);
      }
      CHECK(m->shared_dialog_ids.size() == 1);
      return make_tl_object<td_api::messageChatShared>(SharedDialog(m->shared_dialog_ids[0]).get_shared_chat_object(td),
                                                       m->button_id);
    }
    case MessageContentType::WebViewWriteAccessAllowed: {
      const auto *m = static_cast<const MessageWebViewWriteAccessAllowed *>(content);
      return td_api::make_object<td_api::messageBotWriteAccessAllowed>(
          td_api::make_object<td_api::botWriteAccessAllowReasonLaunchedWebApp>(m->web_app.get_web_app_object(td)));
    }
    case MessageContentType::SetBackground: {
      const auto *m = static_cast<const MessageSetBackground *>(content);
      return td_api::make_object<td_api::messageChatSetBackground>(
          m->old_message_id.get(), m->background_info.get_chat_background_object(td), !m->for_both);
    }
    case MessageContentType::Story: {
      const auto *m = static_cast<const MessageStory *>(content);
      return td_api::make_object<td_api::messageStory>(
          td->dialog_manager_->get_chat_id_object(m->story_full_id.get_dialog_id(), "messageStory"),
          m->story_full_id.get_story_id().get(), m->via_mention);
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      return td_api::make_object<td_api::messageBotWriteAccessAllowed>(
          td_api::make_object<td_api::botWriteAccessAllowReasonAcceptedRequest>());
    case MessageContentType::GiftCode: {
      const auto *m = static_cast<const MessageGiftCode *>(content);
      return td_api::make_object<td_api::messagePremiumGiftCode>(
          m->creator_dialog_id.is_valid()
              ? get_message_sender_object(td, m->creator_dialog_id, "messagePremiumGiftCode")
              : nullptr,
          get_text_object(m->text), m->via_giveaway, m->is_unclaimed, m->currency, m->amount, m->crypto_currency,
          m->crypto_amount, m->months, td->stickers_manager_->get_premium_gift_sticker_object(m->months, 0), m->code);
    }
    case MessageContentType::Giveaway: {
      const auto *m = static_cast<const MessageGiveaway *>(content);
      td_api::object_ptr<td_api::GiveawayPrize> prize;
      if (m->months != 0) {
        prize = td_api::make_object<td_api::giveawayPrizePremium>(m->months);
      } else {
        prize = td_api::make_object<td_api::giveawayPrizeStars>(m->star_count);
      }
      return td_api::make_object<td_api::messageGiveaway>(
          m->giveaway_parameters.get_giveaway_parameters_object(td), m->quantity, std::move(prize),
          td->stickers_manager_->get_premium_gift_sticker_object(m->months, m->star_count));
    }
    case MessageContentType::GiveawayLaunch: {
      const auto *m = static_cast<const MessageGiveawayLaunch *>(content);
      return td_api::make_object<td_api::messageGiveawayCreated>(m->star_count);
    }
    case MessageContentType::GiveawayResults: {
      const auto *m = static_cast<const MessageGiveawayResults *>(content);
      return td_api::make_object<td_api::messageGiveawayCompleted>(m->giveaway_message_id.get(), m->winner_count,
                                                                   m->is_star_giveaway, m->unclaimed_count);
    }
    case MessageContentType::GiveawayWinners: {
      const auto *m = static_cast<const MessageGiveawayWinners *>(content);
      td_api::object_ptr<td_api::GiveawayPrize> prize;
      if (m->month_count != 0) {
        prize = td_api::make_object<td_api::giveawayPrizePremium>(m->month_count);
      } else {
        prize = td_api::make_object<td_api::giveawayPrizeStars>(m->star_count);
      }
      return td_api::make_object<td_api::messageGiveawayWinners>(
          td->dialog_manager_->get_chat_id_object(DialogId(m->boosted_channel_id), "messageGiveawayWinners"),
          m->giveaway_message_id.get(), m->additional_dialog_count, m->winners_selection_date, m->only_new_subscribers,
          m->was_refunded, std::move(prize), m->prize_description, m->winner_count,
          td->user_manager_->get_user_ids_object(m->winner_user_ids, "messageGiveawayWinners"), m->unclaimed_count);
    }
    case MessageContentType::ExpiredVideoNote:
      return make_tl_object<td_api::messageExpiredVideoNote>();
    case MessageContentType::ExpiredVoiceNote:
      return make_tl_object<td_api::messageExpiredVoiceNote>();
    case MessageContentType::BoostApply: {
      const auto *m = static_cast<const MessageBoostApply *>(content);
      return td_api::make_object<td_api::messageChatBoost>(m->boost_count);
    }
    case MessageContentType::DialogShared: {
      const auto *m = static_cast<const MessageDialogShared *>(content);
      CHECK(!m->shared_dialogs.empty());
      if (m->shared_dialogs[0].is_user()) {
        vector<td_api::object_ptr<td_api::sharedUser>> users;
        for (const auto &shared_dialog : m->shared_dialogs) {
          users.push_back(shared_dialog.get_shared_user_object(td));
        }
        return td_api::make_object<td_api::messageUsersShared>(std::move(users), m->button_id);
      }
      CHECK(m->shared_dialogs.size() == 1);
      return td_api::make_object<td_api::messageChatShared>(m->shared_dialogs[0].get_shared_chat_object(td),
                                                            m->button_id);
    }
    case MessageContentType::PaidMedia: {
      const auto *m = static_cast<const MessagePaidMedia *>(content);
      return td_api::make_object<td_api::messagePaidMedia>(
          m->star_count, transform(m->media, [&](const auto &media) { return media.get_paid_media_object(td); }),
          get_text_object(m->caption), invert_media);
    }
    case MessageContentType::PaymentRefunded: {
      const auto *m = static_cast<const MessagePaymentRefunded *>(content);
      return td_api::make_object<td_api::messagePaymentRefunded>(
          get_message_sender_object(td, m->dialog_id, "messagePaymentRefunded"), m->currency, m->total_amount,
          m->invoice_payload, m->telegram_payment_charge_id, m->provider_payment_charge_id);
    }
    case MessageContentType::GiftStars: {
      const auto *m = static_cast<const MessageGiftStars *>(content);
      int64 gifter_user_id = 0;
      int64 receiver_user_id = 0;
      if (dialog_id.get_type() == DialogType::User) {
        auto user_id = dialog_id.get_user_id();
        if (is_outgoing) {
          receiver_user_id = td->user_manager_->get_user_id_object(user_id, "MessageGiftStars 2");
        } else {
          if (user_id != UserManager::get_service_notifications_user_id() && !td->user_manager_->is_user_bot(user_id) &&
              !td->user_manager_->is_user_support(user_id)) {
            gifter_user_id = td->user_manager_->get_user_id_object(user_id, "MessageGiftStars 3");
          }
        }
      } else {
        LOG(ERROR) << "Receive gifted stars in " << dialog_id;
      }
      return td_api::make_object<td_api::messageGiftedStars>(
          gifter_user_id, receiver_user_id, m->currency, m->amount, m->crypto_currency, m->crypto_amount, m->star_count,
          m->transaction_id, td->stickers_manager_->get_premium_gift_sticker_object(0, m->star_count));
    }
    case MessageContentType::PrizeStars: {
      const auto *m = static_cast<const MessagePrizeStars *>(content);
      return td_api::make_object<td_api::messageGiveawayPrizeStars>(
          m->star_count, m->transaction_id,
          td->dialog_manager_->get_chat_id_object(m->boosted_dialog_id, "messageGiveawayPrizeStars"),
          m->giveaway_message_id.get(), m->is_unclaimed,
          td->stickers_manager_->get_premium_gift_sticker_object(0, m->star_count));
    }
    case MessageContentType::StarGift: {
      const auto *m = static_cast<const MessageStarGift *>(content);
      StarGiftId star_gift_id;
      if (m->owner_dialog_id != DialogId()) {
        star_gift_id = StarGiftId(m->owner_dialog_id, m->saved_id);
      } else if (dialog_id.get_type() == DialogType::User && !is_outgoing && is_server && message_id.is_server()) {
        auto user_id = dialog_id.get_user_id();
        if (user_id != UserManager::get_service_notifications_user_id()) {
          star_gift_id = StarGiftId(message_id.get_server_message_id());
        }
      }
      DialogId sender_dialog_id;
      if (m->sender_dialog_id != DialogId()) {
        sender_dialog_id = m->sender_dialog_id;
      } else {
        if (is_outgoing) {
          sender_dialog_id = td->dialog_manager_->get_my_dialog_id();
        } else {
          sender_dialog_id = dialog_id;
        }
      }
      return td_api::make_object<td_api::messageGift>(
          m->star_gift.get_gift_object(td), get_message_sender_object(td, sender_dialog_id, "messageGift"),
          star_gift_id.get_star_gift_id(), get_text_object(m->text), m->convert_star_count, m->upgrade_star_count,
          m->name_hidden, m->is_saved, m->can_upgrade, m->was_converted, m->was_upgraded, m->was_refunded,
          StarGiftId(m->upgrade_message_id.get_server_message_id()).get_star_gift_id());
    }
    case MessageContentType::StarGiftUnique: {
      const auto *m = static_cast<const MessageStarGiftUnique *>(content);
      DialogId sender_dialog_id;
      if (m->sender_dialog_id != DialogId()) {
        sender_dialog_id = m->sender_dialog_id;
      } else {
        if (is_outgoing) {
          sender_dialog_id = td->dialog_manager_->get_my_dialog_id();
        } else {
          sender_dialog_id = dialog_id;
        }
      }
      if (m->was_refunded) {
        return td_api::make_object<td_api::messageRefundedUpgradedGift>(
            m->star_gift.get_gift_object(td),
            get_message_sender_object(td, sender_dialog_id, "messageRefundedUpgradedGift"), m->is_upgrade);
      }
      StarGiftId star_gift_id;
      if (m->owner_dialog_id != DialogId()) {
        star_gift_id = StarGiftId(m->owner_dialog_id, m->saved_id);
      } else if (dialog_id.get_type() == DialogType::User && m->is_upgrade == is_outgoing && is_server &&
                 message_id.is_server()) {
        auto user_id = dialog_id.get_user_id();
        if (user_id != UserManager::get_service_notifications_user_id() || m->is_upgrade) {
          star_gift_id = StarGiftId(message_id.get_server_message_id());
        }
      }
      return td_api::make_object<td_api::messageUpgradedGift>(
          m->star_gift.get_upgraded_gift_object(td),
          sender_dialog_id == DialogId(UserManager::get_service_notifications_user_id())
              ? nullptr
              : get_message_sender_object(td, sender_dialog_id, "messageUpgradedGift"),
          star_gift_id.get_star_gift_id(), m->is_upgrade, m->is_saved, m->can_transfer, m->was_transferred,
          m->transfer_star_count, m->can_export_at);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
  UNREACHABLE();
  return nullptr;
}

td_api::object_ptr<td_api::upgradeGiftResult> get_message_content_upgrade_gift_result_object(
    const MessageContent *content, Td *td, DialogId dialog_id, MessageId message_id) {
  switch (content->get_type()) {
    case MessageContentType::StarGiftUnique: {
      const auto *m = static_cast<const MessageStarGiftUnique *>(content);
      StarGiftId star_gift_id;
      if (m->owner_dialog_id != DialogId()) {
        star_gift_id = StarGiftId(m->owner_dialog_id, m->saved_id);
      } else if (dialog_id.get_type() == DialogType::User && message_id.is_valid() && message_id.is_server()) {
        star_gift_id = StarGiftId(message_id.get_server_message_id());
      }
      return td_api::make_object<td_api::upgradeGiftResult>(m->star_gift.get_upgraded_gift_object(td),
                                                            star_gift_id.get_star_gift_id(), m->is_saved,
                                                            m->can_transfer, m->transfer_star_count, m->can_export_at);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

FormattedText *get_message_content_text_mutable(MessageContent *content) {
  return const_cast<FormattedText *>(get_message_content_text(content));
}

const FormattedText *get_message_content_text(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Text:
      return &static_cast<const MessageText *>(content)->text;
    case MessageContentType::Game:
      return &static_cast<const MessageGame *>(content)->game.get_text();
    case MessageContentType::GiftPremium:
      return &static_cast<const MessageGiftPremium *>(content)->text;
    case MessageContentType::GiftCode:
      return &static_cast<const MessageGiftCode *>(content)->text;
    case MessageContentType::StarGift:
      return &static_cast<const MessageStarGift *>(content)->text;
    default:
      return get_message_content_caption(content);
  }
}

const FormattedText *get_message_content_caption(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return &static_cast<const MessageAnimation *>(content)->caption;
    case MessageContentType::Audio:
      return &static_cast<const MessageAudio *>(content)->caption;
    case MessageContentType::Document:
      return &static_cast<const MessageDocument *>(content)->caption;
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_caption();
    case MessageContentType::PaidMedia:
      return &static_cast<const MessagePaidMedia *>(content)->caption;
    case MessageContentType::Photo:
      return &static_cast<const MessagePhoto *>(content)->caption;
    case MessageContentType::Video:
      return &static_cast<const MessageVideo *>(content)->caption;
    case MessageContentType::VoiceNote:
      return &static_cast<const MessageVoiceNote *>(content)->caption;
    default:
      return nullptr;
  }
}

static bool get_message_content_has_spoiler(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return static_cast<const MessageAnimation *>(content)->has_spoiler;
    case MessageContentType::Photo:
      return static_cast<const MessagePhoto *>(content)->has_spoiler;
    case MessageContentType::Video:
      return static_cast<const MessageVideo *>(content)->has_spoiler;
    default:
      return false;
  }
}

static void set_message_content_has_spoiler(MessageContent *content, bool has_spoiler) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      static_cast<MessageAnimation *>(content)->has_spoiler = has_spoiler;
      break;
    case MessageContentType::Photo:
      static_cast<MessagePhoto *>(content)->has_spoiler = has_spoiler;
      break;
    case MessageContentType::Video:
      static_cast<MessageVideo *>(content)->has_spoiler = has_spoiler;
      break;
    default:
      break;
  }
}

unique_ptr<MessageContent> get_uploaded_message_content(
    Td *td, const MessageContent *old_content, int32 media_pos,
    telegram_api::object_ptr<telegram_api::MessageMedia> &&media_ptr, DialogId owner_dialog_id, int32 message_date,
    const char *source) {
  if (media_pos >= 0) {
    CHECK(old_content->get_type() == MessageContentType::PaidMedia);
    auto paid_media = static_cast<const MessagePaidMedia *>(old_content);
    CHECK(static_cast<size_t>(media_pos) < paid_media->media.size());
    auto content = make_unique<MessagePaidMedia>(*paid_media);
    auto media = MessageExtendedMedia(td, std::move(media_ptr), owner_dialog_id);
    if (!media.has_input_media()) {
      if (!media.is_unsupported()) {
        LOG(ERROR) << "Receive invalid uploaded paid media";
      }
    } else {
      bool is_content_changed = false;
      bool need_update = false;
      content->media[media_pos].merge_files(td, media, owner_dialog_id, true, is_content_changed, need_update);
    }
    return std::move(content);
  }
  auto caption = get_message_content_caption(old_content);
  auto has_spoiler = get_message_content_has_spoiler(old_content);
  auto content = get_message_content(td, caption == nullptr ? FormattedText() : *caption, std::move(media_ptr),
                                     owner_dialog_id, message_date, false, UserId(), nullptr, nullptr, source);
  set_message_content_has_spoiler(content.get(), has_spoiler);
  return content;
}

int64 get_message_content_star_count(const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::PaidMedia);
  return static_cast<const MessagePaidMedia *>(content)->star_count;
}

string get_message_content_payload(const MessageContent *content) {
  CHECK(content->get_type() == MessageContentType::PaidMedia);
  return static_cast<const MessagePaidMedia *>(content)->payload;
}

int32 get_message_content_duration(const MessageContent *content, const Td *td) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Animation: {
      auto animation_file_id = static_cast<const MessageAnimation *>(content)->file_id;
      return td->animations_manager_->get_animation_duration(animation_file_id);
    }
    case MessageContentType::Audio: {
      auto audio_file_id = static_cast<const MessageAudio *>(content)->file_id;
      return td->audios_manager_->get_audio_duration(audio_file_id);
    }
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_duration(td);
    case MessageContentType::PaidMedia: {
      int32 result = -1;
      for (auto &media : static_cast<const MessagePaidMedia *>(content)->media) {
        result = max(result, media.get_duration(td));
      }
      return result;
    }
    case MessageContentType::Video: {
      auto video_file_id = static_cast<const MessageVideo *>(content)->file_id;
      return td->videos_manager_->get_video_duration(video_file_id);
    }
    case MessageContentType::VideoNote: {
      auto video_note_file_id = static_cast<const MessageVideoNote *>(content)->file_id;
      return td->video_notes_manager_->get_video_note_duration(video_note_file_id);
    }
    case MessageContentType::VoiceNote: {
      auto voice_file_id = static_cast<const MessageVoiceNote *>(content)->file_id;
      return td->voice_notes_manager_->get_voice_note_duration(voice_file_id);
    }
    default:
      return -1;
  }
}

int32 get_message_content_media_duration(const MessageContent *content, const Td *td) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Audio: {
      auto audio_file_id = static_cast<const MessageAudio *>(content)->file_id;
      return td->audios_manager_->get_audio_duration(audio_file_id);
    }
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_duration(td);
    case MessageContentType::PaidMedia: {
      int32 result = -1;
      for (const auto &media : static_cast<const MessagePaidMedia *>(content)->media) {
        result = max(result, media.get_duration(td));
      }
      return result;
    }
    case MessageContentType::Story: {
      auto story_full_id = static_cast<const MessageStory *>(content)->story_full_id;
      return td->story_manager_->get_story_duration(story_full_id);
    }
    case MessageContentType::Text: {
      auto web_page_id = static_cast<const MessageText *>(content)->web_page_id;
      return td->web_pages_manager_->get_web_page_media_duration(web_page_id);
    }
    case MessageContentType::Video: {
      auto video_file_id = static_cast<const MessageVideo *>(content)->file_id;
      return td->videos_manager_->get_video_duration(video_file_id);
    }
    case MessageContentType::VideoNote: {
      auto video_note_file_id = static_cast<const MessageVideoNote *>(content)->file_id;
      return td->video_notes_manager_->get_video_note_duration(video_note_file_id);
    }
    case MessageContentType::VoiceNote: {
      auto voice_file_id = static_cast<const MessageVoiceNote *>(content)->file_id;
      return td->voice_notes_manager_->get_voice_note_duration(voice_file_id);
    }
    default:
      return -1;
  }
}

const Photo *get_message_content_cover(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Video: {
      const auto *cover = &static_cast<const MessageVideo *>(content)->cover;
      if (cover->is_empty()) {
        return nullptr;
      }
      return cover;
    }
    default:
      return nullptr;
  }
}

vector<const Photo *> get_message_content_need_to_upload_covers(Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Video: {
      const auto *cover = &static_cast<const MessageVideo *>(content)->cover;
      if (cover->is_empty() ||
          photo_get_cover_input_media(td->file_manager_.get(), *cover, td->auth_manager_->is_bot(), false) != nullptr) {
        break;
      }
      return {cover};
    }
    case MessageContentType::PaidMedia: {
      vector<const Photo *> result;
      for (const auto &media : static_cast<const MessagePaidMedia *>(content)->media) {
        const auto *cover = media.get_video_cover();
        if (cover == nullptr || cover->is_empty() ||
            photo_get_cover_input_media(td->file_manager_.get(), *cover, td->auth_manager_->is_bot(), false) !=
                nullptr) {
          continue;
        }
        result.push_back(cover);
      }
      return result;
    }
    default:
      break;
  }
  return {};
}

const Photo *get_message_content_photo(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Photo:
      return &static_cast<const MessagePhoto *>(content)->photo;
    default:
      break;
  }
  return nullptr;
}

FileId get_message_content_any_file_id(const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return static_cast<const MessageAnimation *>(content)->file_id;
    case MessageContentType::Audio:
      return static_cast<const MessageAudio *>(content)->file_id;
    case MessageContentType::Document:
      return static_cast<const MessageDocument *>(content)->file_id;
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_any_file_id();
    case MessageContentType::Photo:
      return get_photo_any_file_id(static_cast<const MessagePhoto *>(content)->photo);
    case MessageContentType::Sticker:
      return static_cast<const MessageSticker *>(content)->file_id;
    case MessageContentType::Video:
      return static_cast<const MessageVideo *>(content)->file_id;
    case MessageContentType::VideoNote:
      return static_cast<const MessageVideoNote *>(content)->file_id;
    case MessageContentType::VoiceNote:
      return static_cast<const MessageVoiceNote *>(content)->file_id;
    case MessageContentType::PaidMedia:
      UNREACHABLE();
      break;
    default:
      break;
  }
  return FileId();
}

vector<FileId> get_message_content_any_file_ids(const MessageContent *content) {
  if (content->get_type() == MessageContentType::PaidMedia) {
    return transform(static_cast<const MessagePaidMedia *>(content)->media,
                     [](const MessageExtendedMedia &media) { return media.get_any_file_id(); });
  }
  auto file_id = get_message_content_any_file_id(content);
  if (file_id.is_valid()) {
    return {file_id};
  }
  return {};
}

FileId get_message_content_cover_any_file_id(const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Video: {
      auto video = static_cast<const MessageVideo *>(content);
      if (!video->cover.is_empty()) {
        return get_photo_any_file_id(video->cover);
      }
      break;
    }
    case MessageContentType::PaidMedia:
      UNREACHABLE();
      break;
    default:
      break;
  }
  return {};
}

vector<FileId> get_message_content_cover_any_file_ids(const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Video: {
      auto video = static_cast<const MessageVideo *>(content);
      if (!video->cover.is_empty()) {
        return {get_photo_any_file_id(video->cover)};
      }
      break;
    }
    case MessageContentType::PaidMedia:
      return transform(static_cast<const MessagePaidMedia *>(content)->media,
                       [](const MessageExtendedMedia &media) { return media.get_cover_any_file_id(); });
      break;
    default:
      break;
  }
  return {};
}

void update_message_content_file_id_remote(MessageContent *content, FileId file_id) {
  if (file_id.get_remote() == 0) {
    return;
  }
  FileId *old_file_id = [&] {
    switch (content->get_type()) {
      case MessageContentType::Animation:
        return &static_cast<MessageAnimation *>(content)->file_id;
      case MessageContentType::Audio:
        return &static_cast<MessageAudio *>(content)->file_id;
      case MessageContentType::Document:
        return &static_cast<MessageDocument *>(content)->file_id;
      case MessageContentType::Sticker:
        return &static_cast<MessageSticker *>(content)->file_id;
      case MessageContentType::Video:
        return &static_cast<MessageVideo *>(content)->file_id;
      case MessageContentType::VideoNote:
        return &static_cast<MessageVideoNote *>(content)->file_id;
      case MessageContentType::VoiceNote:
        return &static_cast<MessageVoiceNote *>(content)->file_id;
      case MessageContentType::PaidMedia:
        UNREACHABLE();
        return static_cast<FileId *>(nullptr);
      default:
        return static_cast<FileId *>(nullptr);
    }
  }();
  if (old_file_id != nullptr && *old_file_id == file_id && old_file_id->get_remote() == 0) {
    *old_file_id = file_id;
  }
}

void update_message_content_file_id_remotes(MessageContent *content, const vector<FileId> &file_ids) {
  if (content->get_type() == MessageContentType::PaidMedia) {
    auto &media = static_cast<MessagePaidMedia *>(content)->media;
    if (file_ids.size() != media.size()) {
      return;
    }
    for (size_t i = 0; i < file_ids.size(); i++) {
      media[i].update_file_id_remote(file_ids[i]);
    }
    return;
  }
  if (file_ids.size() != 1) {
    return;
  }
  update_message_content_file_id_remote(content, file_ids[0]);
}

FileId get_message_content_thumbnail_file_id(const MessageContent *content, const Td *td) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return td->animations_manager_->get_animation_thumbnail_file_id(
          static_cast<const MessageAnimation *>(content)->file_id);
    case MessageContentType::Audio:
      return td->audios_manager_->get_audio_thumbnail_file_id(static_cast<const MessageAudio *>(content)->file_id);
    case MessageContentType::Document:
      return td->documents_manager_->get_document_thumbnail_file_id(
          static_cast<const MessageDocument *>(content)->file_id);
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_thumbnail_file_id(td);
    case MessageContentType::Photo:
      return get_photo_thumbnail_file_id(static_cast<const MessagePhoto *>(content)->photo);
    case MessageContentType::Sticker:
      return td->stickers_manager_->get_sticker_thumbnail_file_id(
          static_cast<const MessageSticker *>(content)->file_id);
    case MessageContentType::Video:
      return td->videos_manager_->get_video_thumbnail_file_id(static_cast<const MessageVideo *>(content)->file_id);
    case MessageContentType::VideoNote:
      return td->video_notes_manager_->get_video_note_thumbnail_file_id(
          static_cast<const MessageVideoNote *>(content)->file_id);
    case MessageContentType::VoiceNote:
      return FileId();
    case MessageContentType::PaidMedia:
      UNREACHABLE();
      return FileId();
    default:
      break;
  }
  return FileId();
}

vector<FileId> get_message_content_thumbnail_file_ids(const MessageContent *content, const Td *td) {
  if (content->get_type() == MessageContentType::PaidMedia) {
    return transform(static_cast<const MessagePaidMedia *>(content)->media,
                     [&](const MessageExtendedMedia &media) { return media.get_thumbnail_file_id(td); });
  }
  auto file_id = get_message_content_thumbnail_file_id(content, td);
  if (file_id.is_valid()) {
    return {file_id};
  }
  return {};
}

vector<FileId> get_message_content_file_ids(const MessageContent *content, const Td *td) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Photo:
      return photo_get_file_ids(static_cast<const MessagePhoto *>(content)->photo);
    case MessageContentType::Animation:
    case MessageContentType::Audio:
    case MessageContentType::Document:
    case MessageContentType::Sticker:
    case MessageContentType::VideoNote:
    case MessageContentType::VoiceNote: {
      auto document_type = [&] {
        switch (content->get_type()) {
          case MessageContentType::Animation:
            return Document::Type::Animation;
          case MessageContentType::Audio:
            return Document::Type::Audio;
          case MessageContentType::Document:
            return Document::Type::General;
          case MessageContentType::Sticker:
            return Document::Type::Sticker;
          case MessageContentType::VideoNote:
            return Document::Type::VideoNote;
          case MessageContentType::VoiceNote:
            return Document::Type::VoiceNote;
          default:
            UNREACHABLE();
            return Document::Type::Unknown;
        }
      }();
      return Document(document_type, get_message_content_any_file_id(content)).get_file_ids(td);
    }
    case MessageContentType::Video: {
      auto video = static_cast<const MessageVideo *>(content);
      auto file_ids = Document(Document::Type::Video, video->file_id).get_file_ids(td);
      for (auto file_id : video->alternative_file_ids) {
        append(file_ids, Document(Document::Type::Video, file_id).get_file_ids(td));
      }
      for (auto file_id : video->hls_file_ids) {
        append(file_ids, Document(Document::Type::General, file_id).get_file_ids(td));
      }
      if (!video->cover.is_empty()) {
        append(file_ids, photo_get_file_ids(video->cover));
      }
      return file_ids;
    }
    case MessageContentType::Game:
      return static_cast<const MessageGame *>(content)->game.get_file_ids(td);
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.get_file_ids(td);
    case MessageContentType::ChatChangePhoto:
      return photo_get_file_ids(static_cast<const MessageChatChangePhoto *>(content)->photo);
    case MessageContentType::PassportDataReceived: {
      vector<FileId> result;
      for (auto &value : static_cast<const MessagePassportDataReceived *>(content)->values) {
        auto process_encrypted_secure_file = [&result](const EncryptedSecureFile &file) {
          if (file.file.file_id.is_valid()) {
            result.push_back(file.file.file_id);
          }
        };
        for (auto &file : value.files) {
          process_encrypted_secure_file(file);
        }
        process_encrypted_secure_file(value.front_side);
        process_encrypted_secure_file(value.reverse_side);
        process_encrypted_secure_file(value.selfie);
        for (auto &file : value.translations) {
          process_encrypted_secure_file(file);
        }
      }
      return result;
    }
    case MessageContentType::SuggestProfilePhoto:
      return photo_get_file_ids(static_cast<const MessageSuggestProfilePhoto *>(content)->photo);
    case MessageContentType::WebViewWriteAccessAllowed:
      return static_cast<const MessageWebViewWriteAccessAllowed *>(content)->web_app.get_file_ids(td);
    case MessageContentType::SetBackground:
      // background file references are repaired independently
      return {};
    case MessageContentType::Story:
      // story file references are repaired independently
      return {};
    case MessageContentType::PaidMedia: {
      vector<FileId> result;
      for (const auto &media : static_cast<const MessagePaidMedia *>(content)->media) {
        media.append_file_ids(td, result);
      }
      return result;
    }
    default:
      return {};
  }
}

StoryFullId get_message_content_story_full_id(const Td *td, const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Text:
      return td->web_pages_manager_->get_web_page_story_full_id(static_cast<const MessageText *>(content)->web_page_id);
    case MessageContentType::Story:
      return static_cast<const MessageStory *>(content)->story_full_id;
    default:
      return StoryFullId();
  }
}

string get_message_content_search_text(const Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Text: {
      const auto *text = static_cast<const MessageText *>(content);
      if (!text->web_page_id.is_valid()) {
        return text->text.text;
      }
      return PSTRING() << text->text.text << ' ' << td->web_pages_manager_->get_web_page_search_text(text->web_page_id);
    }
    case MessageContentType::Animation: {
      const auto *animation = static_cast<const MessageAnimation *>(content);
      return PSTRING() << td->animations_manager_->get_animation_search_text(animation->file_id) << ' '
                       << animation->caption.text;
    }
    case MessageContentType::Audio: {
      const auto *audio = static_cast<const MessageAudio *>(content);
      return PSTRING() << td->audios_manager_->get_audio_search_text(audio->file_id) << ' ' << audio->caption.text;
    }
    case MessageContentType::Document: {
      const auto *document = static_cast<const MessageDocument *>(content);
      return PSTRING() << td->documents_manager_->get_document_search_text(document->file_id) << ' '
                       << document->caption.text;
    }
    case MessageContentType::Invoice: {
      const auto *invoice = static_cast<const MessageInvoice *>(content);
      return invoice->input_invoice.get_caption()->text;
    }
    case MessageContentType::PaidMedia: {
      const auto *paid_media = static_cast<const MessagePaidMedia *>(content);
      return paid_media->caption.text;
    }
    case MessageContentType::Photo: {
      const auto *photo = static_cast<const MessagePhoto *>(content);
      return photo->caption.text;
    }
    case MessageContentType::Video: {
      const auto *video = static_cast<const MessageVideo *>(content);
      return PSTRING() << td->videos_manager_->get_video_search_text(video->file_id) << " " << video->caption.text;
    }
    case MessageContentType::Poll: {
      const auto *poll = static_cast<const MessagePoll *>(content);
      return td->poll_manager_->get_poll_search_text(poll->poll_id);
    }
    case MessageContentType::TopicCreate: {
      const auto *topic_create = static_cast<const MessageTopicCreate *>(content);
      return topic_create->title;
    }
    case MessageContentType::TopicEdit: {
      const auto *topic_edit = static_cast<const MessageTopicEdit *>(content);
      return topic_edit->edited_data.get_title();
    }
    case MessageContentType::GiftPremium: {
      const auto *m = static_cast<const MessageGiftPremium *>(content);
      return m->text.text;
    }
    case MessageContentType::GiftCode: {
      const auto *m = static_cast<const MessageGiftCode *>(content);
      return m->text.text;
    }
    case MessageContentType::StarGift: {
      const auto *m = static_cast<const MessageStarGift *>(content);
      return m->text.text;
    }
    case MessageContentType::Contact:
    case MessageContentType::Game:
    case MessageContentType::LiveLocation:
    case MessageContentType::Location:
    case MessageContentType::Sticker:
    case MessageContentType::Story:
    case MessageContentType::Unsupported:
    case MessageContentType::Venue:
    case MessageContentType::VideoNote:
    case MessageContentType::VoiceNote:
    case MessageContentType::ChatCreate:
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatDeleteHistory:
    case MessageContentType::ChatAddUsers:
    case MessageContentType::ChatJoinedByLink:
    case MessageContentType::ChatDeleteUser:
    case MessageContentType::ChatMigrateTo:
    case MessageContentType::ChannelCreate:
    case MessageContentType::ChannelMigrateFrom:
    case MessageContentType::PinMessage:
    case MessageContentType::GameScore:
    case MessageContentType::ScreenshotTaken:
    case MessageContentType::ChatSetTtl:
    case MessageContentType::Call:
    case MessageContentType::PaymentSuccessful:
    case MessageContentType::ContactRegistered:
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::CustomServiceAction:
    case MessageContentType::WebsiteConnected:
    case MessageContentType::PassportDataSent:
    case MessageContentType::PassportDataReceived:
    case MessageContentType::Dice:
    case MessageContentType::ProximityAlertTriggered:
    case MessageContentType::GroupCall:
    case MessageContentType::InviteToGroupCall:
    case MessageContentType::ChatSetTheme:
    case MessageContentType::WebViewDataSent:
    case MessageContentType::WebViewDataReceived:
    case MessageContentType::SuggestProfilePhoto:
    case MessageContentType::WriteAccessAllowed:
    case MessageContentType::RequestedDialog:
    case MessageContentType::WebViewWriteAccessAllowed:
    case MessageContentType::SetBackground:
    case MessageContentType::WriteAccessAllowedByRequest:
    case MessageContentType::Giveaway:
    case MessageContentType::GiveawayLaunch:
    case MessageContentType::GiveawayResults:
    case MessageContentType::GiveawayWinners:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
    case MessageContentType::BoostApply:
    case MessageContentType::DialogShared:
    case MessageContentType::PaymentRefunded:
    case MessageContentType::GiftStars:
    case MessageContentType::PrizeStars:
      return string();
    default:
      UNREACHABLE();
      return string();
  }
}

bool update_message_content_extended_media(
    MessageContent *content, vector<telegram_api::object_ptr<telegram_api::MessageExtendedMedia>> extended_media,
    DialogId owner_dialog_id, Td *td) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Invoice:
      if (extended_media.size() != 1) {
        LOG(ERROR) << "Receive " << extended_media.size() << " extended media in " << owner_dialog_id;
        return false;
      }
      return static_cast<MessageInvoice *>(content)->input_invoice.update_extended_media(std::move(extended_media[0]),
                                                                                         owner_dialog_id, td);
    case MessageContentType::PaidMedia: {
      auto &media = static_cast<MessagePaidMedia *>(content)->media;
      if (extended_media.size() != media.size()) {
        LOG(ERROR) << "Receive " << extended_media.size() << " paid media instead of " << media.size() << " in "
                   << owner_dialog_id;
        return false;
      }
      bool result = false;
      for (size_t i = 0; i < media.size(); i++) {
        if (media[i].update_to(td, std::move(extended_media[i]), owner_dialog_id)) {
          result = true;
        }
      }
      return result;
    }
    case MessageContentType::Unsupported:
      return false;
    default:
      LOG(ERROR) << "Receive updateMessageExtendedMedia for a message of type " << content->get_type() << " in "
                 << owner_dialog_id;
      return false;
  }
}

bool need_poll_message_content_extended_media(const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Invoice:
      return static_cast<const MessageInvoice *>(content)->input_invoice.need_poll_extended_media();
    case MessageContentType::PaidMedia: {
      const auto &media = static_cast<const MessagePaidMedia *>(content)->media;
      for (auto &extended_media : media) {
        if (extended_media.need_poll()) {
          return true;
        }
      }
      return false;
    }
    default:
      return false;
  }
}

void set_message_content_video_start_timestamp(MessageContent *content, int32 start_timestamp) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Video:
      static_cast<MessageVideo *>(content)->start_timestamp = start_timestamp;
      return;
    default:
      return;
  }
}

void get_message_content_animated_emoji_click_sticker(const MessageContent *content, MessageFullId message_full_id,
                                                      Td *td, Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  if (content->get_type() != MessageContentType::Text) {
    return promise.set_error(Status::Error(400, "Message is not an animated emoji message"));
  }

  const auto &text = static_cast<const MessageText *>(content)->text;
  if (!can_be_animated_emoji(text)) {
    return promise.set_error(Status::Error(400, "Message is not an animated emoji message"));
  }
  td->stickers_manager_->get_animated_emoji_click_sticker(text.text, message_full_id, std::move(promise));
}

void on_message_content_animated_emoji_clicked(const MessageContent *content, MessageFullId message_full_id, Td *td,
                                               string &&emoji, string &&data) {
  if (content->get_type() != MessageContentType::Text) {
    return;
  }

  remove_emoji_modifiers_in_place(emoji);
  auto &text = static_cast<const MessageText *>(content)->text;
  if (!text.entities.empty() || remove_emoji_modifiers(text.text) != emoji) {
    return;
  }
  auto error = td->stickers_manager_->on_animated_emoji_message_clicked(std::move(emoji), message_full_id, data);
  if (error.is_error()) {
    LOG(WARNING) << "Failed to process animated emoji click with data \"" << data << "\": " << error;
  }
}

bool need_reget_message_content(const MessageContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case MessageContentType::Unsupported: {
      const auto *m = static_cast<const MessageUnsupported *>(content);
      return m->version != MessageUnsupported::CURRENT_VERSION;
    }
    case MessageContentType::Invoice: {
      const auto *m = static_cast<const MessageInvoice *>(content);
      return m->input_invoice.need_reget();
    }
    case MessageContentType::PaidMedia: {
      const auto *m = static_cast<const MessagePaidMedia *>(content);
      for (const auto &media : m->media) {
        if (media.need_reget()) {
          return true;
        }
      }
      return false;
    }
    default:
      return false;
  }
}

bool need_delay_message_content_notification(const MessageContent *content, UserId my_user_id) {
  switch (content->get_type()) {
    case MessageContentType::ChatChangeTitle:
    case MessageContentType::ChatChangePhoto:
    case MessageContentType::ChatDeletePhoto:
    case MessageContentType::ChatJoinedByLink:
      return true;
    case MessageContentType::ChatAddUsers: {
      auto &added_user_ids = static_cast<const MessageChatAddUsers *>(content)->user_ids;
      return !td::contains(added_user_ids, my_user_id);
    }
    case MessageContentType::ChatDeleteUser:
      return static_cast<const MessageChatDeleteUser *>(content)->user_id != my_user_id;
    default:
      return false;
  }
}

void update_expired_message_content(unique_ptr<MessageContent> &content) {
  switch (content->get_type()) {
    case MessageContentType::Photo:
      content = make_unique<MessageExpiredPhoto>();
      break;
    case MessageContentType::Video:
      content = make_unique<MessageExpiredVideo>();
      break;
    case MessageContentType::Unsupported:
      // can happen if message content file identifier is broken
      break;
    case MessageContentType::VideoNote:
      content = make_unique<MessageExpiredVideoNote>();
      break;
    case MessageContentType::VoiceNote:
      content = make_unique<MessageExpiredVoiceNote>();
      break;
    case MessageContentType::ExpiredPhoto:
    case MessageContentType::ExpiredVideo:
    case MessageContentType::ExpiredVideoNote:
    case MessageContentType::ExpiredVoiceNote:
      // can happen if message content has been reget from somewhere
      break;
    case MessageContentType::Animation:
    case MessageContentType::Audio:
    case MessageContentType::Document:
    case MessageContentType::Sticker:
      // can happen if server will send a document with a wrong content
      content = make_unique<MessageExpiredVideo>();
      break;
    default:
      UNREACHABLE();
  }
}

void update_failed_to_send_message_content(Td *td, unique_ptr<MessageContent> &content) {
  // do not forget about failed to send message forwards
  switch (content->get_type()) {
    case MessageContentType::Poll: {
      const auto *message_poll = static_cast<const MessagePoll *>(content.get());
      if (PollManager::is_local_poll_id(message_poll->poll_id)) {
        td->poll_manager_->stop_local_poll(message_poll->poll_id);
      }
      break;
    }
    default:
      // nothing to do
      break;
  }
}

void add_message_content_dependencies(Dependencies &dependencies, const MessageContent *message_content, bool is_bot) {
  CHECK(message_content != nullptr);
  switch (message_content->get_type()) {
    case MessageContentType::Text: {
      const auto *content = static_cast<const MessageText *>(message_content);
      dependencies.add(content->web_page_id);
      break;
    }
    case MessageContentType::Animation:
      break;
    case MessageContentType::Audio:
      break;
    case MessageContentType::Contact: {
      const auto *content = static_cast<const MessageContact *>(message_content);
      dependencies.add(content->contact.get_user_id());
      break;
    }
    case MessageContentType::Document:
      break;
    case MessageContentType::Game: {
      const auto *content = static_cast<const MessageGame *>(message_content);
      dependencies.add(content->game.get_bot_user_id());
      break;
    }
    case MessageContentType::Invoice:
      break;
    case MessageContentType::LiveLocation:
      break;
    case MessageContentType::Location:
      break;
    case MessageContentType::Photo:
      break;
    case MessageContentType::Sticker:
      break;
    case MessageContentType::Venue:
      break;
    case MessageContentType::Video:
      break;
    case MessageContentType::VideoNote:
      break;
    case MessageContentType::VoiceNote:
      break;
    case MessageContentType::ChatCreate: {
      const auto *content = static_cast<const MessageChatCreate *>(message_content);
      for (auto &participant_user_id : content->participant_user_ids) {
        dependencies.add(participant_user_id);
      }
      break;
    }
    case MessageContentType::ChatChangeTitle:
      break;
    case MessageContentType::ChatChangePhoto:
      break;
    case MessageContentType::ChatDeletePhoto:
      break;
    case MessageContentType::ChatDeleteHistory:
      break;
    case MessageContentType::ChatAddUsers: {
      const auto *content = static_cast<const MessageChatAddUsers *>(message_content);
      for (auto &user_id : content->user_ids) {
        dependencies.add(user_id);
      }
      break;
    }
    case MessageContentType::ChatJoinedByLink:
      break;
    case MessageContentType::ChatDeleteUser: {
      const auto *content = static_cast<const MessageChatDeleteUser *>(message_content);
      dependencies.add(content->user_id);
      break;
    }
    case MessageContentType::ChatMigrateTo: {
      const auto *content = static_cast<const MessageChatMigrateTo *>(message_content);
      dependencies.add(content->migrated_to_channel_id);
      break;
    }
    case MessageContentType::ChannelCreate:
      break;
    case MessageContentType::ChannelMigrateFrom: {
      const auto *content = static_cast<const MessageChannelMigrateFrom *>(message_content);
      dependencies.add(content->migrated_from_chat_id);
      break;
    }
    case MessageContentType::PinMessage:
      break;
    case MessageContentType::GameScore:
      break;
    case MessageContentType::ScreenshotTaken:
      break;
    case MessageContentType::ChatSetTtl: {
      const auto *content = static_cast<const MessageChatSetTtl *>(message_content);
      dependencies.add(content->from_user_id);
      break;
    }
    case MessageContentType::Unsupported:
      break;
    case MessageContentType::Call:
      break;
    case MessageContentType::PaymentSuccessful: {
      const auto *content = static_cast<const MessagePaymentSuccessful *>(message_content);
      dependencies.add_dialog_and_dependencies(content->invoice_dialog_id);
      break;
    }
    case MessageContentType::ContactRegistered:
      break;
    case MessageContentType::ExpiredPhoto:
      break;
    case MessageContentType::ExpiredVideo:
      break;
    case MessageContentType::CustomServiceAction:
      break;
    case MessageContentType::WebsiteConnected:
      break;
    case MessageContentType::PassportDataSent:
      break;
    case MessageContentType::PassportDataReceived:
      break;
    case MessageContentType::Poll:
      // no need to add poll dependencies, because they are forcely loaded with the poll
      break;
    case MessageContentType::Dice:
      break;
    case MessageContentType::ProximityAlertTriggered: {
      const auto *content = static_cast<const MessageProximityAlertTriggered *>(message_content);
      dependencies.add_message_sender_dependencies(content->traveler_dialog_id);
      dependencies.add_message_sender_dependencies(content->watcher_dialog_id);
      break;
    }
    case MessageContentType::GroupCall:
      break;
    case MessageContentType::InviteToGroupCall: {
      const auto *content = static_cast<const MessageInviteToGroupCall *>(message_content);
      for (auto &user_id : content->user_ids) {
        dependencies.add(user_id);
      }
      break;
    }
    case MessageContentType::ChatSetTheme:
      break;
    case MessageContentType::WebViewDataSent:
      break;
    case MessageContentType::WebViewDataReceived:
      break;
    case MessageContentType::GiftPremium:
      break;
    case MessageContentType::TopicCreate:
      break;
    case MessageContentType::TopicEdit:
      break;
    case MessageContentType::SuggestProfilePhoto:
      break;
    case MessageContentType::WriteAccessAllowed:
      break;
    case MessageContentType::RequestedDialog: {
      const auto *content = static_cast<const MessageRequestedDialog *>(message_content);
      if (!is_bot) {
        for (auto dialog_id : content->shared_dialog_ids) {
          if (dialog_id.get_type() == DialogType::User) {
            dependencies.add(dialog_id.get_user_id());
          } else {
            dependencies.add_dialog_and_dependencies(dialog_id);
          }
        }
      }
      break;
    }
    case MessageContentType::WebViewWriteAccessAllowed:
      break;
    case MessageContentType::SetBackground:
      break;
    case MessageContentType::Story: {
      const auto *content = static_cast<const MessageStory *>(message_content);
      dependencies.add(content->story_full_id);
      break;
    }
    case MessageContentType::WriteAccessAllowedByRequest:
      break;
    case MessageContentType::GiftCode: {
      const auto *content = static_cast<const MessageGiftCode *>(message_content);
      dependencies.add_message_sender_dependencies(content->creator_dialog_id);
      break;
    }
    case MessageContentType::Giveaway: {
      const auto *content = static_cast<const MessageGiveaway *>(message_content);
      content->giveaway_parameters.add_dependencies(dependencies);
      break;
    }
    case MessageContentType::GiveawayLaunch:
      break;
    case MessageContentType::GiveawayResults:
      break;
    case MessageContentType::GiveawayWinners: {
      const auto *content = static_cast<const MessageGiveawayWinners *>(message_content);
      dependencies.add_dialog_and_dependencies(DialogId(content->boosted_channel_id));
      for (auto &user_id : content->winner_user_ids) {
        dependencies.add(user_id);
      }
      break;
    }
    case MessageContentType::ExpiredVideoNote:
      break;
    case MessageContentType::ExpiredVoiceNote:
      break;
    case MessageContentType::BoostApply:
      break;
    case MessageContentType::DialogShared:
      break;
    case MessageContentType::PaidMedia:
      break;
    case MessageContentType::PaymentRefunded: {
      const auto *content = static_cast<const MessagePaymentRefunded *>(message_content);
      dependencies.add_message_sender_dependencies(content->dialog_id);
      break;
    }
    case MessageContentType::GiftStars:
      break;
    case MessageContentType::PrizeStars: {
      const auto *content = static_cast<const MessagePrizeStars *>(message_content);
      dependencies.add_dialog_and_dependencies(DialogId(content->boosted_dialog_id));
      break;
    }
    case MessageContentType::StarGift: {
      const auto *content = static_cast<const MessageStarGift *>(message_content);
      content->star_gift.add_dependencies(dependencies);
      dependencies.add_dialog_and_dependencies(content->sender_dialog_id);
      dependencies.add_dialog_and_dependencies(content->owner_dialog_id);
      break;
    }
    case MessageContentType::StarGiftUnique: {
      const auto *content = static_cast<const MessageStarGiftUnique *>(message_content);
      content->star_gift.add_dependencies(dependencies);
      dependencies.add_dialog_and_dependencies(content->sender_dialog_id);
      dependencies.add_dialog_and_dependencies(content->owner_dialog_id);
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
  add_formatted_text_dependencies(dependencies, get_message_content_text(message_content));
}

void update_forum_topic_info_by_service_message_content(Td *td, const MessageContent *content, DialogId dialog_id,
                                                        MessageId top_thread_message_id) {
  if (!top_thread_message_id.is_valid()) {
    return;
  }
  switch (content->get_type()) {
    case MessageContentType::TopicEdit:
      return td->forum_topic_manager_->on_forum_topic_edited(
          dialog_id, top_thread_message_id, static_cast<const MessageTopicEdit *>(content)->edited_data);
    default:
      // nothing to do
      return;
  }
}

void on_sent_message_content(Td *td, const MessageContent *content) {
  switch (content->get_type()) {
    case MessageContentType::Animation:
      return td->animations_manager_->add_saved_animation_by_id(get_message_content_any_file_id(content));
    case MessageContentType::Sticker:
      return td->stickers_manager_->add_recent_sticker_by_id(false, get_message_content_any_file_id(content));
    default:
      // nothing to do
      return;
  }
}

void move_message_content_sticker_set_to_top(Td *td, const MessageContent *content) {
  CHECK(content != nullptr);
  if (content->get_type() == MessageContentType::Sticker) {
    td->stickers_manager_->move_sticker_set_to_top_by_sticker_id(get_message_content_any_file_id(content));
    return;
  }

  auto text = get_message_content_text(content);
  if (text == nullptr) {
    return;
  }
  vector<CustomEmojiId> custom_emoji_ids;
  for (auto &entity : text->entities) {
    if (entity.type == MessageEntity::Type::CustomEmoji) {
      custom_emoji_ids.push_back(entity.custom_emoji_id);
    }
  }
  if (!custom_emoji_ids.empty()) {
    td->stickers_manager_->move_sticker_set_to_top_by_custom_emoji_ids(custom_emoji_ids);
  }
}

void on_dialog_used(TopDialogCategory category, DialogId dialog_id, int32 date) {
  send_closure(G()->top_dialog_manager(), &TopDialogManager::on_dialog_used, category, dialog_id, date);
}

void update_used_hashtags(Td *td, const MessageContent *content) {
  const FormattedText *text = get_message_content_text(content);
  if (text == nullptr || text->text.empty()) {
    return;
  }

  const unsigned char *ptr = Slice(text->text).ubegin();
  const unsigned char *end = Slice(text->text).uend();
  int32 utf16_pos = 0;
  uint32 skipped_code = 0;
  for (auto &entity : text->entities) {
    if (entity.type != MessageEntity::Type::Hashtag) {
      continue;
    }
    while (utf16_pos < entity.offset && ptr < end) {
      utf16_pos += 1 + (ptr[0] >= 0xf0);
      ptr = next_utf8_unsafe(ptr, &skipped_code);
    }
    CHECK(utf16_pos == entity.offset);
    auto from = ptr;

    while (utf16_pos < entity.offset + entity.length && ptr < end) {
      utf16_pos += 1 + (ptr[0] >= 0xf0);
      ptr = next_utf8_unsafe(ptr, &skipped_code);
    }
    CHECK(utf16_pos == entity.offset + entity.length);
    auto to = ptr;

    send_closure(td->hashtag_hints_, &HashtagHints::hashtag_used, Slice(from + 1, to).str());
  }
}

}  // namespace td
