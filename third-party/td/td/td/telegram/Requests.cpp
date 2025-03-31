//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Requests.h"

#include "td/telegram/AccentColorId.h"
#include "td/telegram/AccountManager.h"
#include "td/telegram/AlarmManager.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/Application.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/AutoDownloadSettings.h"
#include "td/telegram/AutosaveManager.h"
#include "td/telegram/BackgroundId.h"
#include "td/telegram/BackgroundManager.h"
#include "td/telegram/BackgroundType.h"
#include "td/telegram/Birthdate.h"
#include "td/telegram/BoostManager.h"
#include "td/telegram/BotCommand.h"
#include "td/telegram/BotInfoManager.h"
#include "td/telegram/BotMenuButton.h"
#include "td/telegram/BotQueries.h"
#include "td/telegram/BotRecommendationManager.h"
#include "td/telegram/BusinessAwayMessage.h"
#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/BusinessConnectionManager.h"
#include "td/telegram/BusinessGreetingMessage.h"
#include "td/telegram/BusinessIntro.h"
#include "td/telegram/BusinessManager.h"
#include "td/telegram/BusinessWorkHours.h"
#include "td/telegram/CallbackQueriesManager.h"
#include "td/telegram/CallId.h"
#include "td/telegram/CallManager.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelRecommendationManager.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/CommonDialogManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/ConnectionStateManager.h"
#include "td/telegram/CountryInfoManager.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DeviceTokenManager.h"
#include "td/telegram/DialogAction.h"
#include "td/telegram/DialogActionManager.h"
#include "td/telegram/DialogBoostLinkInfo.h"
#include "td/telegram/DialogEventLog.h"
#include "td/telegram/DialogFilterId.h"
#include "td/telegram/DialogFilterManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogInviteLinkManager.h"
#include "td/telegram/DialogListId.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/DialogParticipantFilter.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/DownloadManager.h"
#include "td/telegram/DownloadManagerCallback.h"
#include "td/telegram/EmailVerification.h"
#include "td/telegram/EmojiGroupType.h"
#include "td/telegram/EmojiStatus.h"
#include "td/telegram/files/FileGcParameters.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileStats.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/GameManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/GlobalPrivacySettings.h"
#include "td/telegram/GroupCallId.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/HashtagHints.h"
#include "td/telegram/InlineMessageManager.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/JsonValue.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/Location.h"
#include "td/telegram/MessageCopyOptions.h"
#include "td/telegram/MessageEffectId.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageImportManager.h"
#include "td/telegram/MessageLinkInfo.h"
#include "td/telegram/MessageQueryManager.h"
#include "td/telegram/MessageReaction.h"
#include "td/telegram/MessageSearchFilter.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/MessageSource.h"
#include "td/telegram/MessageThreadInfo.h"
#include "td/telegram/MessageTtl.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetStatsManager.h"
#include "td/telegram/net/NetType.h"
#include "td/telegram/net/Proxy.h"
#include "td/telegram/NotificationGroupId.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/NotificationObjectId.h"
#include "td/telegram/NotificationSettingsManager.h"
#include "td/telegram/NotificationSettingsScope.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/Payments.h"
#include "td/telegram/PhoneNumberManager.h"
#include "td/telegram/Premium.h"
#include "td/telegram/PrivacyManager.h"
#include "td/telegram/PublicDialogType.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/ReactionNotificationSettings.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/ReferralProgramManager.h"
#include "td/telegram/ReferralProgramParameters.h"
#include "td/telegram/ReferralProgramSortOrder.h"
#include "td/telegram/ReportReason.h"
#include "td/telegram/RequestActor.h"
#include "td/telegram/SavedMessagesManager.h"
#include "td/telegram/SavedMessagesTopicId.h"
#include "td/telegram/ScopeNotificationSettings.h"
#include "td/telegram/SecretChatId.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/SecureManager.h"
#include "td/telegram/SecureValue.h"
#include "td/telegram/SentEmailCode.h"
#include "td/telegram/SponsoredMessageManager.h"
#include "td/telegram/StarGiftId.h"
#include "td/telegram/StarGiftManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StarSubscriptionPricing.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/StatisticsManager.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickerListType.h"
#include "td/telegram/StickerSetId.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickerType.h"
#include "td/telegram/StorageManager.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/StoryListId.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Support.h"
#include "td/telegram/SynchronousRequests.h"
#include "td/telegram/td_api.hpp"
#include "td/telegram/TdDb.h"
#include "td/telegram/TermsOfServiceManager.h"
#include "td/telegram/TimeZoneManager.h"
#include "td/telegram/TopDialogCategory.h"
#include "td/telegram/TopDialogManager.h"
#include "td/telegram/TranscriptionManager.h"
#include "td/telegram/TranslationManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/WebAppManager.h"
#include "td/telegram/WebAppOpenParameters.h"
#include "td/telegram/WebPageId.h"
#include "td/telegram/WebPagesManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <tuple>
#include <type_traits>
#include <utility>

namespace td {

class GetMeRequest final : public RequestActor<> {
  UserId user_id_;

  void do_run(Promise<Unit> &&promise) final {
    user_id_ = td_->user_manager_->get_me(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_user_object(user_id_));
  }

 public:
  GetMeRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class GetUserRequest final : public RequestActor<> {
  UserId user_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->user_manager_->get_user(user_id_, get_tries(), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_user_object(user_id_));
  }

 public:
  GetUserRequest(ActorShared<Td> td, uint64 request_id, int64 user_id)
      : RequestActor(std::move(td), request_id), user_id_(user_id) {
    set_tries(3);
  }
};

class GetUserFullInfoRequest final : public RequestActor<> {
  UserId user_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->user_manager_->load_user_full(user_id_, get_tries() < 2, std::move(promise), "GetUserFullInfoRequest");
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_user_full_info_object(user_id_));
  }

 public:
  GetUserFullInfoRequest(ActorShared<Td> td, uint64 request_id, int64 user_id)
      : RequestActor(std::move(td), request_id), user_id_(user_id) {
  }
};

class GetGroupRequest final : public RequestActor<> {
  ChatId chat_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->chat_manager_->get_chat(chat_id_, get_tries(), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->chat_manager_->get_basic_group_object(chat_id_));
  }

 public:
  GetGroupRequest(ActorShared<Td> td, uint64 request_id, int64 chat_id)
      : RequestActor(std::move(td), request_id), chat_id_(chat_id) {
    set_tries(3);
  }
};

class GetGroupFullInfoRequest final : public RequestActor<> {
  ChatId chat_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->chat_manager_->load_chat_full(chat_id_, get_tries() < 2, std::move(promise), "getBasicGroupFullInfo");
  }

  void do_send_result() final {
    send_result(td_->chat_manager_->get_basic_group_full_info_object(chat_id_));
  }

 public:
  GetGroupFullInfoRequest(ActorShared<Td> td, uint64 request_id, int64 chat_id)
      : RequestActor(std::move(td), request_id), chat_id_(chat_id) {
  }
};

class GetSupergroupRequest final : public RequestActor<> {
  ChannelId channel_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->chat_manager_->get_channel(channel_id_, get_tries(), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->chat_manager_->get_supergroup_object(channel_id_));
  }

 public:
  GetSupergroupRequest(ActorShared<Td> td, uint64 request_id, int64 channel_id)
      : RequestActor(std::move(td), request_id), channel_id_(channel_id) {
    set_tries(3);
  }
};

class GetSupergroupFullInfoRequest final : public RequestActor<> {
  ChannelId channel_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->chat_manager_->load_channel_full(channel_id_, get_tries() < 2, std::move(promise),
                                          "GetSupergroupFullInfoRequest");
  }

  void do_send_result() final {
    send_result(td_->chat_manager_->get_supergroup_full_info_object(channel_id_));
  }

 public:
  GetSupergroupFullInfoRequest(ActorShared<Td> td, uint64 request_id, int64 channel_id)
      : RequestActor(std::move(td), request_id), channel_id_(channel_id) {
  }
};

class GetSecretChatRequest final : public RequestActor<> {
  SecretChatId secret_chat_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->user_manager_->get_secret_chat(secret_chat_id_, get_tries() < 2, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_secret_chat_object(secret_chat_id_));
  }

 public:
  GetSecretChatRequest(ActorShared<Td> td, uint64 request_id, int32 secret_chat_id)
      : RequestActor(std::move(td), request_id), secret_chat_id_(secret_chat_id) {
  }
};

class GetChatRequest final : public RequestActor<> {
  DialogId dialog_id_;

  bool dialog_found_ = false;

  void do_run(Promise<Unit> &&promise) final {
    dialog_found_ = td_->messages_manager_->load_dialog(dialog_id_, get_tries(), std::move(promise));
  }

  void do_send_result() final {
    if (!dialog_found_) {
      send_error(Status::Error(400, "Chat is not accessible"));
    } else {
      send_result(td_->messages_manager_->get_chat_object(dialog_id_, "GetChatRequest"));
    }
  }

 public:
  GetChatRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id)
      : RequestActor(std::move(td), request_id), dialog_id_(dialog_id) {
    set_tries(3);
  }
};

class SearchUserByPhoneNumberRequest final : public RequestActor<> {
  string phone_number_;
  bool only_local_;

  UserId user_id_;

  void do_run(Promise<Unit> &&promise) final {
    user_id_ = td_->user_manager_->search_user_by_phone_number(phone_number_, only_local_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_user_object(user_id_));
  }

 public:
  SearchUserByPhoneNumberRequest(ActorShared<Td> td, uint64 request_id, string &&phone_number, bool only_local)
      : RequestActor(std::move(td), request_id), phone_number_(std::move(phone_number)), only_local_(only_local) {
  }
};

class LoadChatsRequest final : public RequestActor<> {
  DialogListId dialog_list_id_;
  DialogDate offset_;
  int32 limit_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->get_dialogs(dialog_list_id_, offset_, limit_, false, get_tries() < 2, std::move(promise));
  }

 public:
  LoadChatsRequest(ActorShared<Td> td, uint64 request_id, DialogListId dialog_list_id, DialogDate offset, int32 limit)
      : RequestActor(std::move(td), request_id), dialog_list_id_(dialog_list_id), offset_(offset), limit_(limit) {
    // 1 for database + 1 for server request + 1 for server request at the end + 1 for return + 1 just in case
    set_tries(5);

    if (limit_ > 100) {
      limit_ = 100;
    }
  }
};

class SearchPublicChatRequest final : public RequestActor<> {
  string username_;

  DialogId dialog_id_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_id_ = td_->dialog_manager_->search_public_dialog(username_, get_tries() < 3, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_chat_object(dialog_id_, "SearchPublicChatRequest"));
  }

 public:
  SearchPublicChatRequest(ActorShared<Td> td, uint64 request_id, string username)
      : RequestActor(std::move(td), request_id), username_(std::move(username)) {
    set_tries(4);  // 1 for server request + 1 for reload voice chat + 1 for reload dialog + 1 for result
  }
};

class SearchPublicChatsRequest final : public RequestActor<> {
  string query_;

  vector<DialogId> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->dialog_manager_->search_public_dialogs(query_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(-1, dialog_ids_, "SearchPublicChatsRequest"));
  }

 public:
  SearchPublicChatsRequest(ActorShared<Td> td, uint64 request_id, string query)
      : RequestActor(std::move(td), request_id), query_(std::move(query)) {
  }
};

class SearchChatsRequest final : public RequestActor<> {
  string query_;
  int32 limit_;

  std::pair<int32, vector<DialogId>> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->messages_manager_->search_dialogs(query_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(dialog_ids_, "SearchChatsRequest"));
  }

 public:
  SearchChatsRequest(ActorShared<Td> td, uint64 request_id, string query, int32 limit)
      : RequestActor(std::move(td), request_id), query_(std::move(query)), limit_(limit) {
  }
};

class SearchChatsOnServerRequest final : public RequestActor<> {
  string query_;
  int32 limit_;

  vector<DialogId> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->dialog_manager_->search_dialogs_on_server(query_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(-1, dialog_ids_, "SearchChatsOnServerRequest"));
  }

 public:
  SearchChatsOnServerRequest(ActorShared<Td> td, uint64 request_id, string query, int32 limit)
      : RequestActor(std::move(td), request_id), query_(std::move(query)), limit_(limit) {
  }
};

class GetGroupsInCommonRequest final : public RequestActor<> {
  UserId user_id_;
  DialogId offset_dialog_id_;
  int32 limit_;

  std::pair<int32, vector<DialogId>> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->common_dialog_manager_->get_common_dialogs(user_id_, offset_dialog_id_, limit_, get_tries() < 2,
                                                                  std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(dialog_ids_, "GetGroupsInCommonRequest"));
  }

 public:
  GetGroupsInCommonRequest(ActorShared<Td> td, uint64 request_id, int64 user_id, int64 offset_dialog_id, int32 limit)
      : RequestActor(std::move(td), request_id), user_id_(user_id), offset_dialog_id_(offset_dialog_id), limit_(limit) {
  }
};

class GetSuitableDiscussionChatsRequest final : public RequestActor<> {
  vector<DialogId> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->chat_manager_->get_dialogs_for_discussion(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(-1, dialog_ids_, "GetSuitableDiscussionChatsRequest"));
  }

 public:
  GetSuitableDiscussionChatsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class GetInactiveSupergroupChatsRequest final : public RequestActor<> {
  vector<DialogId> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->chat_manager_->get_inactive_channels(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(-1, dialog_ids_, "GetInactiveSupergroupChatsRequest"));
  }

 public:
  GetInactiveSupergroupChatsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class SearchRecentlyFoundChatsRequest final : public RequestActor<> {
  string query_;
  int32 limit_;

  std::pair<int32, vector<DialogId>> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->dialog_manager_->search_recently_found_dialogs(query_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(dialog_ids_, "SearchRecentlyFoundChatsRequest"));
  }

 public:
  SearchRecentlyFoundChatsRequest(ActorShared<Td> td, uint64 request_id, string query, int32 limit)
      : RequestActor(std::move(td), request_id), query_(std::move(query)), limit_(limit) {
  }
};

class GetRecentlyOpenedChatsRequest final : public RequestActor<> {
  int32 limit_;

  std::pair<int32, vector<DialogId>> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->dialog_manager_->get_recently_opened_dialogs(limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->dialog_manager_->get_chats_object(dialog_ids_, "GetRecentlyOpenedChatsRequest"));
  }

 public:
  GetRecentlyOpenedChatsRequest(ActorShared<Td> td, uint64 request_id, int32 limit)
      : RequestActor(std::move(td), request_id), limit_(limit) {
  }
};

class GetMessageRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->get_message(message_full_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "GetMessageRequest"));
  }

 public:
  GetMessageRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id)
      : RequestOnceActor(std::move(td), request_id), message_full_id_(DialogId(dialog_id), MessageId(message_id)) {
  }
};

class GetRepliedMessageRequest final : public RequestOnceActor {
  DialogId dialog_id_;
  MessageId message_id_;

  MessageFullId replied_message_id_;

  void do_run(Promise<Unit> &&promise) final {
    replied_message_id_ =
        td_->messages_manager_->get_replied_message(dialog_id_, message_id_, get_tries() < 3, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(replied_message_id_, "GetRepliedMessageRequest"));
  }

 public:
  GetRepliedMessageRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id)
      : RequestOnceActor(std::move(td), request_id), dialog_id_(dialog_id), message_id_(message_id) {
    set_tries(3);  // 1 to get initial message, 1 to get the reply and 1 for result
  }
};

class GetMessageThreadRequest final : public RequestActor<MessageThreadInfo> {
  DialogId dialog_id_;
  MessageId message_id_;

  MessageThreadInfo message_thread_info_;

  void do_run(Promise<MessageThreadInfo> &&promise) final {
    if (get_tries() < 2) {
      promise.set_value(std::move(message_thread_info_));
      return;
    }
    td_->messages_manager_->get_message_thread(dialog_id_, message_id_, std::move(promise));
  }

  void do_set_result(MessageThreadInfo &&result) final {
    message_thread_info_ = std::move(result);
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_thread_info_object(message_thread_info_));
  }

 public:
  GetMessageThreadRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id)
      : RequestActor(std::move(td), request_id), dialog_id_(dialog_id), message_id_(message_id) {
  }
};

class GetChatPinnedMessageRequest final : public RequestOnceActor {
  DialogId dialog_id_;

  MessageId pinned_message_id_;

  void do_run(Promise<Unit> &&promise) final {
    pinned_message_id_ = td_->messages_manager_->get_dialog_pinned_message(dialog_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(
        td_->messages_manager_->get_message_object({dialog_id_, pinned_message_id_}, "GetChatPinnedMessageRequest"));
  }

 public:
  GetChatPinnedMessageRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id)
      : RequestOnceActor(std::move(td), request_id), dialog_id_(dialog_id) {
    set_tries(3);  // 1 to get pinned_message_id, 1 to get the message and 1 for result
  }
};

class GetCallbackQueryMessageRequest final : public RequestOnceActor {
  DialogId dialog_id_;
  MessageId message_id_;
  int64 callback_query_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->get_callback_query_message(dialog_id_, message_id_, callback_query_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(
        td_->messages_manager_->get_message_object({dialog_id_, message_id_}, "GetCallbackQueryMessageRequest"));
  }

 public:
  GetCallbackQueryMessageRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                                 int64 callback_query_id)
      : RequestOnceActor(std::move(td), request_id)
      , dialog_id_(dialog_id)
      , message_id_(message_id)
      , callback_query_id_(callback_query_id) {
  }
};

class GetMessagesRequest final : public RequestOnceActor {
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->get_messages(dialog_id_, message_ids_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_messages_object(-1, dialog_id_, message_ids_, false, "GetMessagesRequest"));
  }

 public:
  GetMessagesRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, const vector<int64> &message_ids)
      : RequestOnceActor(std::move(td), request_id)
      , dialog_id_(dialog_id)
      , message_ids_(MessageId::get_message_ids(message_ids)) {
  }
};

class GetMessageEmbeddingCodeRequest final : public RequestActor<> {
  MessageFullId message_full_id_;
  bool for_group_;

  string html_;

  void do_run(Promise<Unit> &&promise) final {
    html_ = td_->messages_manager_->get_message_embedding_code(message_full_id_, for_group_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::text>(html_));
  }

 public:
  GetMessageEmbeddingCodeRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                                 bool for_group)
      : RequestActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , for_group_(for_group) {
  }
};

class GetMessageLinkInfoRequest final : public RequestActor<MessageLinkInfo> {
  string url_;

  MessageLinkInfo message_link_info_;

  void do_run(Promise<MessageLinkInfo> &&promise) final {
    if (get_tries() < 2) {
      promise.set_value(std::move(message_link_info_));
      return;
    }
    td_->messages_manager_->get_message_link_info(url_, std::move(promise));
  }

  void do_set_result(MessageLinkInfo &&result) final {
    message_link_info_ = std::move(result);
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_link_info_object(message_link_info_));
  }

 public:
  GetMessageLinkInfoRequest(ActorShared<Td> td, uint64 request_id, string url)
      : RequestActor(std::move(td), request_id), url_(std::move(url)) {
  }
};

class GetDialogBoostLinkInfoRequest final : public RequestActor<DialogBoostLinkInfo> {
  string url_;

  DialogBoostLinkInfo dialog_boost_link_info_;

  void do_run(Promise<DialogBoostLinkInfo> &&promise) final {
    if (get_tries() < 2) {
      promise.set_value(std::move(dialog_boost_link_info_));
      return;
    }
    td_->boost_manager_->get_dialog_boost_link_info(url_, std::move(promise));
  }

  void do_set_result(DialogBoostLinkInfo &&result) final {
    dialog_boost_link_info_ = std::move(result);
  }

  void do_send_result() final {
    send_result(td_->boost_manager_->get_chat_boost_link_info_object(dialog_boost_link_info_));
  }

 public:
  GetDialogBoostLinkInfoRequest(ActorShared<Td> td, uint64 request_id, string url)
      : RequestActor(std::move(td), request_id), url_(std::move(url)) {
  }
};

class EditMessageTextRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;
  td_api::object_ptr<td_api::ReplyMarkup> reply_markup_;
  td_api::object_ptr<td_api::InputMessageContent> input_message_content_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->edit_message_text(message_full_id_, std::move(reply_markup_),
                                              std::move(input_message_content_), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "EditMessageTextRequest"));
  }

 public:
  EditMessageTextRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                         td_api::object_ptr<td_api::ReplyMarkup> reply_markup,
                         td_api::object_ptr<td_api::InputMessageContent> input_message_content)
      : RequestOnceActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , reply_markup_(std::move(reply_markup))
      , input_message_content_(std::move(input_message_content)) {
  }
};

class EditMessageLiveLocationRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;
  td_api::object_ptr<td_api::ReplyMarkup> reply_markup_;
  td_api::object_ptr<td_api::location> location_;
  int32 live_period_;
  int32 heading_;
  int32 proximity_alert_radius_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->edit_message_live_location(message_full_id_, std::move(reply_markup_), std::move(location_),
                                                       live_period_, heading_, proximity_alert_radius_,
                                                       std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "EditMessageLiveLocationRequest"));
  }

 public:
  EditMessageLiveLocationRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                                 td_api::object_ptr<td_api::ReplyMarkup> reply_markup,
                                 td_api::object_ptr<td_api::location> location, int32 live_period, int32 heading,
                                 int32 proximity_alert_radius)
      : RequestOnceActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , reply_markup_(std::move(reply_markup))
      , location_(std::move(location))
      , live_period_(live_period)
      , heading_(heading)
      , proximity_alert_radius_(proximity_alert_radius) {
  }
};

class EditMessageMediaRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;
  td_api::object_ptr<td_api::ReplyMarkup> reply_markup_;
  td_api::object_ptr<td_api::InputMessageContent> input_message_content_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->edit_message_media(message_full_id_, std::move(reply_markup_),
                                               std::move(input_message_content_), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "EditMessageMediaRequest"));
  }

 public:
  EditMessageMediaRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                          td_api::object_ptr<td_api::ReplyMarkup> reply_markup,
                          td_api::object_ptr<td_api::InputMessageContent> input_message_content)
      : RequestOnceActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , reply_markup_(std::move(reply_markup))
      , input_message_content_(std::move(input_message_content)) {
  }
};

class EditMessageCaptionRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;
  td_api::object_ptr<td_api::ReplyMarkup> reply_markup_;
  td_api::object_ptr<td_api::formattedText> caption_;
  bool invert_media_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->edit_message_caption(message_full_id_, std::move(reply_markup_), std::move(caption_),
                                                 invert_media_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "EditMessageCaptionRequest"));
  }

 public:
  EditMessageCaptionRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                            td_api::object_ptr<td_api::ReplyMarkup> reply_markup,
                            td_api::object_ptr<td_api::formattedText> caption, bool invert_media)
      : RequestOnceActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , reply_markup_(std::move(reply_markup))
      , caption_(std::move(caption))
      , invert_media_(invert_media) {
  }
};

class EditMessageReplyMarkupRequest final : public RequestOnceActor {
  MessageFullId message_full_id_;
  td_api::object_ptr<td_api::ReplyMarkup> reply_markup_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->edit_message_reply_markup(message_full_id_, std::move(reply_markup_), std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_message_object(message_full_id_, "EditMessageReplyMarkupRequest"));
  }

 public:
  EditMessageReplyMarkupRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                                td_api::object_ptr<td_api::ReplyMarkup> reply_markup)
      : RequestOnceActor(std::move(td), request_id)
      , message_full_id_(DialogId(dialog_id), MessageId(message_id))
      , reply_markup_(std::move(reply_markup)) {
  }
};

class GetChatHistoryRequest final : public RequestActor<> {
  DialogId dialog_id_;
  MessageId from_message_id_;
  int32 offset_;
  int32 limit_;
  bool only_local_;

  td_api::object_ptr<td_api::messages> messages_;

  void do_run(Promise<Unit> &&promise) final {
    messages_ = td_->messages_manager_->get_dialog_history(dialog_id_, from_message_id_, offset_, limit_,
                                                           get_tries() - 1, only_local_, std::move(promise));
  }

  void do_send_result() final {
    send_result(std::move(messages_));
  }

 public:
  GetChatHistoryRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 from_message_id, int32 offset,
                        int32 limit, bool only_local)
      : RequestActor(std::move(td), request_id)
      , dialog_id_(dialog_id)
      , from_message_id_(from_message_id)
      , offset_(offset)
      , limit_(limit)
      , only_local_(only_local) {
    if (!only_local_) {
      set_tries(4);
    }
  }
};

class GetMessageThreadHistoryRequest final : public RequestActor<> {
  DialogId dialog_id_;
  MessageId message_id_;
  MessageId from_message_id_;
  int32 offset_;
  int32 limit_;
  int64 random_id_;

  std::pair<DialogId, vector<MessageId>> messages_;

  void do_run(Promise<Unit> &&promise) final {
    messages_ = td_->messages_manager_->get_message_thread_history(dialog_id_, message_id_, from_message_id_, offset_,
                                                                   limit_, random_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_messages_object(-1, messages_.first, messages_.second, true,
                                                            "GetMessageThreadHistoryRequest"));
  }

 public:
  GetMessageThreadHistoryRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, int64 message_id,
                                 int64 from_message_id, int32 offset, int32 limit)
      : RequestActor(std::move(td), request_id)
      , dialog_id_(dialog_id)
      , message_id_(message_id)
      , from_message_id_(from_message_id)
      , offset_(offset)
      , limit_(limit)
      , random_id_(0) {
    set_tries(3);
  }
};

class SearchChatMessagesRequest final : public RequestActor<> {
  DialogId dialog_id_;
  string query_;
  td_api::object_ptr<td_api::MessageSender> sender_id_;
  MessageId from_message_id_;
  int32 offset_;
  int32 limit_;
  MessageSearchFilter filter_;
  MessageId top_thread_message_id_;
  SavedMessagesTopicId saved_messages_topic_id_;
  ReactionType tag_;
  int64 random_id_;

  MessagesManager::FoundDialogMessages messages_;

  void do_run(Promise<Unit> &&promise) final {
    messages_ = td_->messages_manager_->search_dialog_messages(
        dialog_id_, query_, sender_id_, from_message_id_, offset_, limit_, filter_, top_thread_message_id_,
        saved_messages_topic_id_, tag_, random_id_, get_tries() == 3, std::move(promise));
  }

  void do_send_result() final {
    send_result(
        td_->messages_manager_->get_found_chat_messages_object(dialog_id_, messages_, "SearchChatMessagesRequest"));
  }

  void do_send_error(Status &&status) final {
    if (status.message() == "SEARCH_QUERY_EMPTY") {
      messages_ = {};
      return do_send_result();
    }
    send_error(std::move(status));
  }

 public:
  SearchChatMessagesRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id, string query,
                            td_api::object_ptr<td_api::MessageSender> sender_id, int64 from_message_id, int32 offset,
                            int32 limit, td_api::object_ptr<td_api::SearchMessagesFilter> filter,
                            int64 message_thread_id, SavedMessagesTopicId saved_messages_topic_id, ReactionType tag)
      : RequestActor(std::move(td), request_id)
      , dialog_id_(dialog_id)
      , query_(std::move(query))
      , sender_id_(std::move(sender_id))
      , from_message_id_(from_message_id)
      , offset_(offset)
      , limit_(limit)
      , filter_(get_message_search_filter(filter))
      , top_thread_message_id_(message_thread_id)
      , saved_messages_topic_id_(saved_messages_topic_id)
      , tag_(std::move(tag))
      , random_id_(0) {
    set_tries(3);
  }
};

class GetChatScheduledMessagesRequest final : public RequestActor<> {
  DialogId dialog_id_;

  vector<MessageId> message_ids_;

  void do_run(Promise<Unit> &&promise) final {
    message_ids_ =
        td_->messages_manager_->get_dialog_scheduled_messages(dialog_id_, get_tries() < 2, false, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_messages_object(-1, dialog_id_, message_ids_, true,
                                                            "GetChatScheduledMessagesRequest"));
  }

 public:
  GetChatScheduledMessagesRequest(ActorShared<Td> td, uint64 request_id, int64 dialog_id)
      : RequestActor(std::move(td), request_id), dialog_id_(dialog_id) {
    set_tries(4);
  }
};

class GetWebPageInstantViewRequest final : public RequestActor<WebPageId> {
  string url_;
  bool only_local_;

  WebPageId web_page_id_;

  void do_run(Promise<WebPageId> &&promise) final {
    if (get_tries() < 2) {
      promise.set_value(std::move(web_page_id_));
      return;
    }
    td_->web_pages_manager_->get_web_page_instant_view(url_, only_local_, std::move(promise));
  }

  void do_set_result(WebPageId &&result) final {
    web_page_id_ = result;
  }

  void do_send_result() final {
    send_result(td_->web_pages_manager_->get_web_page_instant_view_object(web_page_id_));
  }

 public:
  GetWebPageInstantViewRequest(ActorShared<Td> td, uint64 request_id, string url, bool only_local)
      : RequestActor(std::move(td), request_id), url_(std::move(url)), only_local_(only_local) {
  }
};

class CreateChatRequest final : public RequestActor<> {
  DialogId dialog_id_;
  bool force_;

  void do_run(Promise<Unit> &&promise) final {
    td_->messages_manager_->create_dialog(dialog_id_, force_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->messages_manager_->get_chat_object(dialog_id_, "CreateChatRequest"));
  }

 public:
  CreateChatRequest(ActorShared<Td> td, uint64 request_id, DialogId dialog_id, bool force)
      : RequestActor<>(std::move(td), request_id), dialog_id_(dialog_id), force_(force) {
  }
};

class CheckChatInviteLinkRequest final : public RequestActor<> {
  string invite_link_;

  void do_run(Promise<Unit> &&promise) final {
    td_->dialog_invite_link_manager_->check_dialog_invite_link(invite_link_, get_tries() < 2, std::move(promise));
  }

  void do_send_result() final {
    auto result = td_->dialog_invite_link_manager_->get_chat_invite_link_info_object(invite_link_);
    CHECK(result != nullptr);
    send_result(std::move(result));
  }

 public:
  CheckChatInviteLinkRequest(ActorShared<Td> td, uint64 request_id, string invite_link)
      : RequestActor(std::move(td), request_id), invite_link_(std::move(invite_link)) {
  }
};

class JoinChatByInviteLinkRequest final : public RequestActor<DialogId> {
  string invite_link_;

  DialogId dialog_id_;

  void do_run(Promise<DialogId> &&promise) final {
    if (get_tries() < 2) {
      promise.set_value(std::move(dialog_id_));
      return;
    }
    td_->dialog_invite_link_manager_->import_dialog_invite_link(invite_link_, std::move(promise));
  }

  void do_set_result(DialogId &&result) final {
    dialog_id_ = result;
  }

  void do_send_result() final {
    CHECK(dialog_id_.is_valid());
    td_->dialog_manager_->force_create_dialog(dialog_id_, "join chat via an invite link");
    send_result(td_->messages_manager_->get_chat_object(dialog_id_, "JoinChatByInviteLinkRequest"));
  }

 public:
  JoinChatByInviteLinkRequest(ActorShared<Td> td, uint64 request_id, string invite_link)
      : RequestActor(std::move(td), request_id), invite_link_(std::move(invite_link)) {
  }
};

class ImportContactsRequest final : public RequestActor<> {
  vector<Contact> contacts_;
  int64 random_id_;

  std::pair<vector<UserId>, vector<int32>> imported_contacts_;

  void do_run(Promise<Unit> &&promise) final {
    imported_contacts_ = td_->user_manager_->import_contacts(contacts_, random_id_, std::move(promise));
  }

  void do_send_result() final {
    CHECK(imported_contacts_.first.size() == contacts_.size());
    CHECK(imported_contacts_.second.size() == contacts_.size());
    send_result(td_api::make_object<td_api::importedContacts>(transform(imported_contacts_.first,
                                                                        [this](UserId user_id) {
                                                                          return td_->user_manager_->get_user_id_object(
                                                                              user_id, "ImportContactsRequest");
                                                                        }),
                                                              std::move(imported_contacts_.second)));
  }

 public:
  ImportContactsRequest(ActorShared<Td> td, uint64 request_id, vector<Contact> &&contacts)
      : RequestActor(std::move(td), request_id), contacts_(std::move(contacts)), random_id_(0) {
    set_tries(3);  // load_contacts + import_contacts
  }
};

class SearchContactsRequest final : public RequestActor<> {
  string query_;
  int32 limit_;

  std::pair<int32, vector<UserId>> user_ids_;

  void do_run(Promise<Unit> &&promise) final {
    user_ids_ = td_->user_manager_->search_contacts(query_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_users_object(user_ids_.first, user_ids_.second));
  }

 public:
  SearchContactsRequest(ActorShared<Td> td, uint64 request_id, string query, int32 limit)
      : RequestActor(std::move(td), request_id), query_(std::move(query)), limit_(limit) {
  }
};

class RemoveContactsRequest final : public RequestActor<> {
  vector<UserId> user_ids_;

  void do_run(Promise<Unit> &&promise) final {
    td_->user_manager_->remove_contacts(user_ids_, std::move(promise));
  }

 public:
  RemoveContactsRequest(ActorShared<Td> td, uint64 request_id, vector<UserId> &&user_ids)
      : RequestActor(std::move(td), request_id), user_ids_(std::move(user_ids)) {
    set_tries(3);  // load_contacts + delete_contacts
  }
};

class GetImportedContactCountRequest final : public RequestActor<> {
  int32 imported_contact_count_ = 0;

  void do_run(Promise<Unit> &&promise) final {
    imported_contact_count_ = td_->user_manager_->get_imported_contact_count(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::count>(imported_contact_count_));
  }

 public:
  GetImportedContactCountRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class ChangeImportedContactsRequest final : public RequestActor<> {
  vector<Contact> contacts_;
  size_t contacts_size_;
  int64 random_id_;

  std::pair<vector<UserId>, vector<int32>> imported_contacts_;

  void do_run(Promise<Unit> &&promise) final {
    imported_contacts_ = td_->user_manager_->change_imported_contacts(contacts_, random_id_, std::move(promise));
  }

  void do_send_result() final {
    CHECK(imported_contacts_.first.size() == contacts_size_);
    CHECK(imported_contacts_.second.size() == contacts_size_);
    send_result(td_api::make_object<td_api::importedContacts>(transform(imported_contacts_.first,
                                                                        [this](UserId user_id) {
                                                                          return td_->user_manager_->get_user_id_object(
                                                                              user_id, "ChangeImportedContactsRequest");
                                                                        }),
                                                              std::move(imported_contacts_.second)));
  }

 public:
  ChangeImportedContactsRequest(ActorShared<Td> td, uint64 request_id, vector<Contact> &&contacts)
      : RequestActor(std::move(td), request_id)
      , contacts_(std::move(contacts))
      , contacts_size_(contacts_.size())
      , random_id_(0) {
    set_tries(4);  // load_contacts + load_local_contacts + (import_contacts + delete_contacts)
  }
};

class GetCloseFriendsRequest final : public RequestActor<> {
  vector<UserId> user_ids_;

  void do_run(Promise<Unit> &&promise) final {
    user_ids_ = td_->user_manager_->get_close_friends(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_users_object(-1, user_ids_));
  }

 public:
  GetCloseFriendsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class GetRecentInlineBotsRequest final : public RequestActor<> {
  vector<UserId> user_ids_;

  void do_run(Promise<Unit> &&promise) final {
    user_ids_ = td_->inline_queries_manager_->get_recent_inline_bots(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->user_manager_->get_users_object(-1, user_ids_));
  }

 public:
  GetRecentInlineBotsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class GetChatNotificationSettingsExceptionsRequest final : public RequestActor<> {
  NotificationSettingsScope scope_;
  bool filter_scope_;
  bool compare_sound_;

  vector<DialogId> dialog_ids_;

  void do_run(Promise<Unit> &&promise) final {
    dialog_ids_ = td_->messages_manager_->get_dialog_notification_settings_exceptions(
        scope_, filter_scope_, compare_sound_, get_tries() < 3, std::move(promise));
  }

  void do_send_result() final {
    send_result(
        td_->dialog_manager_->get_chats_object(-1, dialog_ids_, "GetChatNotificationSettingsExceptionsRequest"));
  }

 public:
  GetChatNotificationSettingsExceptionsRequest(ActorShared<Td> td, uint64 request_id, NotificationSettingsScope scope,
                                               bool filter_scope, bool compare_sound)
      : RequestActor(std::move(td), request_id)
      , scope_(scope)
      , filter_scope_(filter_scope)
      , compare_sound_(compare_sound) {
    set_tries(3);
  }
};

class GetScopeNotificationSettingsRequest final : public RequestActor<> {
  NotificationSettingsScope scope_;

  const ScopeNotificationSettings *notification_settings_ = nullptr;

  void do_run(Promise<Unit> &&promise) final {
    notification_settings_ =
        td_->notification_settings_manager_->get_scope_notification_settings(scope_, std::move(promise));
  }

  void do_send_result() final {
    CHECK(notification_settings_ != nullptr);
    send_result(get_scope_notification_settings_object(notification_settings_));
  }

 public:
  GetScopeNotificationSettingsRequest(ActorShared<Td> td, uint64 request_id, NotificationSettingsScope scope)
      : RequestActor(std::move(td), request_id), scope_(scope) {
  }
};

class GetStickersRequest final : public RequestActor<> {
  StickerType sticker_type_;
  string query_;
  int32 limit_;
  DialogId dialog_id_;

  vector<FileId> sticker_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_ids_ = td_->stickers_manager_->get_stickers(sticker_type_, query_, limit_, dialog_id_, get_tries() < 2,
                                                        std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_stickers_object(sticker_ids_));
  }

 public:
  GetStickersRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type, string &&query, int32 limit,
                     int64 dialog_id)
      : RequestActor(std::move(td), request_id)
      , sticker_type_(sticker_type)
      , query_(std::move(query))
      , limit_(limit)
      , dialog_id_(dialog_id) {
    set_tries(4);
  }
};

class GetAllStickerEmojisRequest final : public RequestActor<> {
  StickerType sticker_type_;
  string query_;
  DialogId dialog_id_;
  bool return_only_main_emoji_;

  vector<FileId> sticker_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_ids_ = td_->stickers_manager_->get_stickers(sticker_type_, query_, 1000000, dialog_id_, get_tries() < 2,
                                                        std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_emojis_object(sticker_ids_, return_only_main_emoji_));
  }

 public:
  GetAllStickerEmojisRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type, string &&query,
                             int64 dialog_id, bool return_only_main_emoji)
      : RequestActor(std::move(td), request_id)
      , sticker_type_(sticker_type)
      , query_(std::move(query))
      , dialog_id_(dialog_id)
      , return_only_main_emoji_(return_only_main_emoji) {
    set_tries(4);
  }
};

class GetInstalledStickerSetsRequest final : public RequestActor<> {
  StickerType sticker_type_;

  vector<StickerSetId> sticker_set_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_ids_ = td_->stickers_manager_->get_installed_sticker_sets(sticker_type_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_sets_object(-1, sticker_set_ids_, 1));
  }

 public:
  GetInstalledStickerSetsRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type)
      : RequestActor(std::move(td), request_id), sticker_type_(sticker_type) {
  }
};

class GetArchivedStickerSetsRequest final : public RequestActor<> {
  StickerType sticker_type_;
  StickerSetId offset_sticker_set_id_;
  int32 limit_;

  int32 total_count_ = -1;
  vector<StickerSetId> sticker_set_ids_;

  void do_run(Promise<Unit> &&promise) final {
    std::tie(total_count_, sticker_set_ids_) = td_->stickers_manager_->get_archived_sticker_sets(
        sticker_type_, offset_sticker_set_id_, limit_, get_tries() < 2, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_sets_object(total_count_, sticker_set_ids_, 1));
  }

 public:
  GetArchivedStickerSetsRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type,
                                int64 offset_sticker_set_id, int32 limit)
      : RequestActor(std::move(td), request_id)
      , sticker_type_(sticker_type)
      , offset_sticker_set_id_(offset_sticker_set_id)
      , limit_(limit) {
  }
};

class GetTrendingStickerSetsRequest final : public RequestActor<> {
  td_api::object_ptr<td_api::trendingStickerSets> result_;
  StickerType sticker_type_;
  int32 offset_;
  int32 limit_;

  void do_run(Promise<Unit> &&promise) final {
    result_ = td_->stickers_manager_->get_featured_sticker_sets(sticker_type_, offset_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(std::move(result_));
  }

 public:
  GetTrendingStickerSetsRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type, int32 offset,
                                int32 limit)
      : RequestActor(std::move(td), request_id), sticker_type_(sticker_type), offset_(offset), limit_(limit) {
    set_tries(3);
  }
};

class GetAttachedStickerSetsRequest final : public RequestActor<> {
  FileId file_id_;

  vector<StickerSetId> sticker_set_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_ids_ = td_->stickers_manager_->get_attached_sticker_sets(file_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_sets_object(-1, sticker_set_ids_, 5));
  }

 public:
  GetAttachedStickerSetsRequest(ActorShared<Td> td, uint64 request_id, int32 file_id)
      : RequestActor(std::move(td), request_id), file_id_(file_id, 0) {
  }
};

class GetStickerSetRequest final : public RequestActor<> {
  StickerSetId set_id_;

  StickerSetId sticker_set_id_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_id_ = td_->stickers_manager_->get_sticker_set(set_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_set_object(sticker_set_id_));
  }

 public:
  GetStickerSetRequest(ActorShared<Td> td, uint64 request_id, int64 set_id)
      : RequestActor(std::move(td), request_id), set_id_(set_id) {
    set_tries(3);
  }
};

class SearchStickerSetRequest final : public RequestActor<> {
  string name_;
  bool ignore_cache_;

  StickerSetId sticker_set_id_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_id_ =
        td_->stickers_manager_->search_sticker_set(name_, ignore_cache_ && get_tries() >= 3, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_set_object(sticker_set_id_));
  }

 public:
  SearchStickerSetRequest(ActorShared<Td> td, uint64 request_id, string &&name, bool ignore_cache)
      : RequestActor(std::move(td), request_id), name_(std::move(name)), ignore_cache_(ignore_cache) {
    set_tries(3);
  }
};

class SearchInstalledStickerSetsRequest final : public RequestActor<> {
  StickerType sticker_type_;
  string query_;
  int32 limit_;

  std::pair<int32, vector<StickerSetId>> sticker_set_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_ids_ =
        td_->stickers_manager_->search_installed_sticker_sets(sticker_type_, query_, limit_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_sets_object(sticker_set_ids_.first, sticker_set_ids_.second, 5));
  }

 public:
  SearchInstalledStickerSetsRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type, string &&query,
                                    int32 limit)
      : RequestActor(std::move(td), request_id), sticker_type_(sticker_type), query_(std::move(query)), limit_(limit) {
  }
};

class SearchStickerSetsRequest final : public RequestActor<> {
  StickerType sticker_type_;
  string query_;

  vector<StickerSetId> sticker_set_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_set_ids_ = td_->stickers_manager_->search_sticker_sets(sticker_type_, query_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_sticker_sets_object(-1, sticker_set_ids_, 5));
  }

 public:
  SearchStickerSetsRequest(ActorShared<Td> td, uint64 request_id, StickerType sticker_type, string &&query)
      : RequestActor(std::move(td), request_id), sticker_type_(sticker_type), query_(std::move(query)) {
  }
};

class ChangeStickerSetRequest final : public RequestOnceActor {
  StickerSetId set_id_;
  bool is_installed_;
  bool is_archived_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->change_sticker_set(set_id_, is_installed_, is_archived_, std::move(promise));
  }

 public:
  ChangeStickerSetRequest(ActorShared<Td> td, uint64 request_id, int64 set_id, bool is_installed, bool is_archived)
      : RequestOnceActor(std::move(td), request_id)
      , set_id_(set_id)
      , is_installed_(is_installed)
      , is_archived_(is_archived) {
    set_tries(4);
  }
};

class GetRecentStickersRequest final : public RequestActor<> {
  bool is_attached_;

  vector<FileId> sticker_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_ids_ = td_->stickers_manager_->get_recent_stickers(is_attached_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_stickers_object(sticker_ids_));
  }

 public:
  GetRecentStickersRequest(ActorShared<Td> td, uint64 request_id, bool is_attached)
      : RequestActor(std::move(td), request_id), is_attached_(is_attached) {
  }
};

class AddRecentStickerRequest final : public RequestActor<> {
  bool is_attached_;
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->add_recent_sticker(is_attached_, input_file_, std::move(promise));
  }

 public:
  AddRecentStickerRequest(ActorShared<Td> td, uint64 request_id, bool is_attached,
                          td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestActor(std::move(td), request_id), is_attached_(is_attached), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class RemoveRecentStickerRequest final : public RequestActor<> {
  bool is_attached_;
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->remove_recent_sticker(is_attached_, input_file_, std::move(promise));
  }

 public:
  RemoveRecentStickerRequest(ActorShared<Td> td, uint64 request_id, bool is_attached,
                             td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestActor(std::move(td), request_id), is_attached_(is_attached), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class ClearRecentStickersRequest final : public RequestActor<> {
  bool is_attached_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->clear_recent_stickers(is_attached_, std::move(promise));
  }

 public:
  ClearRecentStickersRequest(ActorShared<Td> td, uint64 request_id, bool is_attached)
      : RequestActor(std::move(td), request_id), is_attached_(is_attached) {
    set_tries(3);
  }
};

class GetFavoriteStickersRequest final : public RequestActor<> {
  vector<FileId> sticker_ids_;

  void do_run(Promise<Unit> &&promise) final {
    sticker_ids_ = td_->stickers_manager_->get_favorite_stickers(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->stickers_manager_->get_stickers_object(sticker_ids_));
  }

 public:
  GetFavoriteStickersRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class AddFavoriteStickerRequest final : public RequestOnceActor {
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->add_favorite_sticker(input_file_, std::move(promise));
  }

 public:
  AddFavoriteStickerRequest(ActorShared<Td> td, uint64 request_id, td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestOnceActor(std::move(td), request_id), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class RemoveFavoriteStickerRequest final : public RequestOnceActor {
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->stickers_manager_->remove_favorite_sticker(input_file_, std::move(promise));
  }

 public:
  RemoveFavoriteStickerRequest(ActorShared<Td> td, uint64 request_id,
                               td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestOnceActor(std::move(td), request_id), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class GetStickerEmojisRequest final : public RequestActor<> {
  td_api::object_ptr<td_api::InputFile> input_file_;

  vector<string> emojis_;

  void do_run(Promise<Unit> &&promise) final {
    emojis_ = td_->stickers_manager_->get_sticker_emojis(input_file_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::emojis>(std::move(emojis_)));
  }

 public:
  GetStickerEmojisRequest(ActorShared<Td> td, uint64 request_id, td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestActor(std::move(td), request_id), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class SearchEmojisRequest final : public RequestActor<> {
  string text_;
  vector<string> input_language_codes_;

  vector<std::pair<string, string>> emoji_keywords_;

  void do_run(Promise<Unit> &&promise) final {
    emoji_keywords_ =
        td_->stickers_manager_->search_emojis(text_, input_language_codes_, get_tries() < 2, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::emojiKeywords>(
        transform(emoji_keywords_, [](const std::pair<string, string> &emoji_keyword) {
          return td_api::make_object<td_api::emojiKeyword>(emoji_keyword.first, emoji_keyword.second);
        })));
  }

 public:
  SearchEmojisRequest(ActorShared<Td> td, uint64 request_id, string &&text, vector<string> &&input_language_codes)
      : RequestActor(std::move(td), request_id)
      , text_(std::move(text))
      , input_language_codes_(std::move(input_language_codes)) {
    set_tries(3);
  }
};

class GetKeywordEmojisRequest final : public RequestActor<> {
  string text_;
  vector<string> input_language_codes_;

  vector<string> emojis_;

  void do_run(Promise<Unit> &&promise) final {
    emojis_ =
        td_->stickers_manager_->get_keyword_emojis(text_, input_language_codes_, get_tries() < 2, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::emojis>(std::move(emojis_)));
  }

 public:
  GetKeywordEmojisRequest(ActorShared<Td> td, uint64 request_id, string &&text, vector<string> &&input_language_codes)
      : RequestActor(std::move(td), request_id)
      , text_(std::move(text))
      , input_language_codes_(std::move(input_language_codes)) {
    set_tries(3);
  }
};

class GetSavedAnimationsRequest final : public RequestActor<> {
  vector<FileId> animation_ids_;

  void do_run(Promise<Unit> &&promise) final {
    animation_ids_ = td_->animations_manager_->get_saved_animations(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::animations>(transform(animation_ids_, [td = td_](FileId animation_id) {
      return td->animations_manager_->get_animation_object(animation_id);
    })));
  }

 public:
  GetSavedAnimationsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class AddSavedAnimationRequest final : public RequestOnceActor {
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->animations_manager_->add_saved_animation(input_file_, std::move(promise));
  }

 public:
  AddSavedAnimationRequest(ActorShared<Td> td, uint64 request_id, td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestOnceActor(std::move(td), request_id), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class RemoveSavedAnimationRequest final : public RequestOnceActor {
  td_api::object_ptr<td_api::InputFile> input_file_;

  void do_run(Promise<Unit> &&promise) final {
    td_->animations_manager_->remove_saved_animation(input_file_, std::move(promise));
  }

 public:
  RemoveSavedAnimationRequest(ActorShared<Td> td, uint64 request_id, td_api::object_ptr<td_api::InputFile> &&input_file)
      : RequestOnceActor(std::move(td), request_id), input_file_(std::move(input_file)) {
    set_tries(3);
  }
};

class GetSavedNotificationSoundRequest final : public RequestActor<> {
  int64 ringtone_id_;
  FileId ringtone_file_id_;

  void do_run(Promise<Unit> &&promise) final {
    ringtone_file_id_ = td_->notification_settings_manager_->get_saved_ringtone(ringtone_id_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->audios_manager_->get_notification_sound_object(ringtone_file_id_));
  }

 public:
  GetSavedNotificationSoundRequest(ActorShared<Td> td, uint64 request_id, int64 ringtone_id)
      : RequestActor(std::move(td), request_id), ringtone_id_(ringtone_id) {
  }
};

class GetSavedNotificationSoundsRequest final : public RequestActor<> {
  vector<FileId> ringtone_file_ids_;

  void do_run(Promise<Unit> &&promise) final {
    ringtone_file_ids_ = td_->notification_settings_manager_->get_saved_ringtones(std::move(promise));
  }

  void do_send_result() final {
    send_result(td_api::make_object<td_api::notificationSounds>(
        transform(ringtone_file_ids_, [td = td_](FileId ringtone_file_id) {
          return td->audios_manager_->get_notification_sound_object(ringtone_file_id);
        })));
  }

 public:
  GetSavedNotificationSoundsRequest(ActorShared<Td> td, uint64 request_id) : RequestActor(std::move(td), request_id) {
  }
};

class RemoveSavedNotificationSoundRequest final : public RequestOnceActor {
  int64 ringtone_id_;

  void do_run(Promise<Unit> &&promise) final {
    td_->notification_settings_manager_->remove_saved_ringtone(ringtone_id_, std::move(promise));
  }

 public:
  RemoveSavedNotificationSoundRequest(ActorShared<Td> td, uint64 request_id, int64 ringtone_id)
      : RequestOnceActor(std::move(td), request_id), ringtone_id_(ringtone_id) {
    set_tries(3);
  }
};

class SearchBackgroundRequest final : public RequestActor<> {
  string name_;

  std::pair<BackgroundId, BackgroundType> background_;

  void do_run(Promise<Unit> &&promise) final {
    background_ = td_->background_manager_->search_background(name_, std::move(promise));
  }

  void do_send_result() final {
    send_result(td_->background_manager_->get_background_object(background_.first, false, &background_.second));
  }

 public:
  SearchBackgroundRequest(ActorShared<Td> td, uint64 request_id, string &&name)
      : RequestActor(std::move(td), request_id), name_(std::move(name)) {
    set_tries(3);
  }
};

Requests::Requests(Td *td) : td_(td), td_actor_(td->actor_id(td)) {
}

void Requests::run_request(uint64 id, td_api::object_ptr<td_api::Function> &&function) {
  CHECK(td_ != nullptr);
  downcast_call(*function, [this, id](auto &request) { this->on_request(id, request); });
}

void Requests::send_error_raw(uint64 id, int32 code, CSlice error) {
  send_closure(td_actor_, &Td::send_error_impl, id, td_api::make_object<td_api::error>(code, error.str()));
}

void Requests::answer_ok_query(uint64 id, Status status) {
  if (status.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, std::move(status));
  } else {
    send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
  }
}

Promise<Unit> Requests::create_ok_request_promise(uint64 id) {
  return PromiseCreator::lambda([actor_id = td_actor_, id](Result<Unit> result) {
    if (result.is_error()) {
      send_closure(actor_id, &Td::send_error, id, result.move_as_error());
    } else {
      send_closure(actor_id, &Td::send_result, id, td_api::make_object<td_api::ok>());
    }
  });
}

Promise<string> Requests::create_text_request_promise(uint64 id) {
  return PromiseCreator::lambda([actor_id = td_actor_, id](Result<string> result) mutable {
    if (result.is_error()) {
      send_closure(actor_id, &Td::send_error, id, result.move_as_error());
    } else {
      send_closure(actor_id, &Td::send_result, id, td_api::make_object<td_api::text>(result.move_as_ok()));
    }
  });
}

Promise<string> Requests::create_http_url_request_promise(uint64 id) {
  return PromiseCreator::lambda([actor_id = td_actor_, id](Result<string> result) mutable {
    if (result.is_error()) {
      send_closure(actor_id, &Td::send_error, id, result.move_as_error());
    } else {
      send_closure(actor_id, &Td::send_result, id, td_api::make_object<td_api::httpUrl>(result.move_as_ok()));
    }
  });
}

#define CLEAN_INPUT_STRING(field_name)                                  \
  if (!clean_input_string(field_name)) {                                \
    return send_error_raw(id, 400, "Strings must be encoded in UTF-8"); \
  }
#define CHECK_IS_BOT()                                              \
  if (!td_->auth_manager_->is_bot()) {                              \
    return send_error_raw(id, 400, "Only bots can use the method"); \
  }
#define CHECK_IS_USER()                                                    \
  if (td_->auth_manager_->is_bot()) {                                      \
    return send_error_raw(id, 400, "The method is not available to bots"); \
  }

#define CREATE_NO_ARGS_REQUEST(name)                                                \
  auto slot_id = td_->request_actors_.create(ActorOwn<>(), Td::RequestActorIdType); \
  td_->inc_request_actor_refcnt();                                                  \
  *td_->request_actors_.get(slot_id) = create_actor<name>(#name, td_->actor_shared(td_, slot_id), id);
#define CREATE_REQUEST(name, ...)                                                   \
  auto slot_id = td_->request_actors_.create(ActorOwn<>(), Td::RequestActorIdType); \
  td_->inc_request_actor_refcnt();                                                  \
  *td_->request_actors_.get(slot_id) = create_actor<name>(#name, td_->actor_shared(td_, slot_id), id, __VA_ARGS__);

#define CREATE_REQUEST_PROMISE() auto promise = create_request_promise<std::decay_t<decltype(request)>::ReturnType>(id)
#define CREATE_OK_REQUEST_PROMISE()                                                                                    \
  static_assert(std::is_same<std::decay_t<decltype(request)>::ReturnType, td_api::object_ptr<td_api::ok>>::value, ""); \
  auto promise = create_ok_request_promise(id)
#define CREATE_TEXT_REQUEST_PROMISE()                                                                               \
  static_assert(std::is_same<std::decay_t<decltype(request)>::ReturnType, td_api::object_ptr<td_api::text>>::value, \
                "");                                                                                                \
  auto promise = create_text_request_promise(id)
#define CREATE_HTTP_URL_REQUEST_PROMISE()                                                                              \
  static_assert(std::is_same<std::decay_t<decltype(request)>::ReturnType, td_api::object_ptr<td_api::httpUrl>>::value, \
                "");                                                                                                   \
  auto promise = create_http_url_request_promise(id)

void Requests::on_request(uint64 id, const td_api::setTdlibParameters &request) {
  send_error_raw(id, 400, "Unexpected setTdlibParameters");
}

void Requests::on_request(uint64 id, td_api::setDatabaseEncryptionKey &request) {
  CREATE_OK_REQUEST_PROMISE();
  G()->td_db()->get_binlog()->change_key(TdDb::as_db_key(std::move(request.new_encryption_key_)), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getAuthorizationState &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::get_state, id);
}

void Requests::on_request(uint64 id, td_api::setAuthenticationPhoneNumber &request) {
  CLEAN_INPUT_STRING(request.phone_number_);
  send_closure(td_->auth_manager_actor_, &AuthManager::set_phone_number, id, std::move(request.phone_number_),
               std::move(request.settings_));
}

void Requests::on_request(uint64 id, td_api::sendAuthenticationFirebaseSms &request) {
  CLEAN_INPUT_STRING(request.token_);
  send_closure(td_->auth_manager_actor_, &AuthManager::set_firebase_token, id, std::move(request.token_));
}

void Requests::on_request(uint64 id, td_api::reportAuthenticationCodeMissing &request) {
  CLEAN_INPUT_STRING(request.mobile_network_code_);
  send_closure(td_->auth_manager_actor_, &AuthManager::report_missing_code, id,
               std::move(request.mobile_network_code_));
}

void Requests::on_request(uint64 id, td_api::setAuthenticationEmailAddress &request) {
  CLEAN_INPUT_STRING(request.email_address_);
  send_closure(td_->auth_manager_actor_, &AuthManager::set_email_address, id, std::move(request.email_address_));
}

void Requests::on_request(uint64 id, td_api::resendAuthenticationCode &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::resend_authentication_code, id, std::move(request.reason_));
}

void Requests::on_request(uint64 id, td_api::checkAuthenticationEmailCode &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::check_email_code, id,
               EmailVerification(std::move(request.code_)));
}

void Requests::on_request(uint64 id, td_api::checkAuthenticationCode &request) {
  CLEAN_INPUT_STRING(request.code_);
  send_closure(td_->auth_manager_actor_, &AuthManager::check_code, id, std::move(request.code_));
}

void Requests::on_request(uint64 id, td_api::registerUser &request) {
  CLEAN_INPUT_STRING(request.first_name_);
  CLEAN_INPUT_STRING(request.last_name_);
  send_closure(td_->auth_manager_actor_, &AuthManager::register_user, id, std::move(request.first_name_),
               std::move(request.last_name_), request.disable_notification_);
}

void Requests::on_request(uint64 id, const td_api::requestQrCodeAuthentication &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::request_qr_code_authentication, id,
               UserId::get_user_ids(request.other_user_ids_));
}

void Requests::on_request(uint64 id, const td_api::resetAuthenticationEmailAddress &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::reset_email_address, id);
}

void Requests::on_request(uint64 id, td_api::checkAuthenticationPassword &request) {
  CLEAN_INPUT_STRING(request.password_);
  send_closure(td_->auth_manager_actor_, &AuthManager::check_password, id, std::move(request.password_));
}

void Requests::on_request(uint64 id, const td_api::requestAuthenticationPasswordRecovery &request) {
  send_closure(td_->auth_manager_actor_, &AuthManager::request_password_recovery, id);
}

void Requests::on_request(uint64 id, td_api::checkAuthenticationPasswordRecoveryCode &request) {
  CLEAN_INPUT_STRING(request.recovery_code_);
  send_closure(td_->auth_manager_actor_, &AuthManager::check_password_recovery_code, id,
               std::move(request.recovery_code_));
}

void Requests::on_request(uint64 id, td_api::recoverAuthenticationPassword &request) {
  CLEAN_INPUT_STRING(request.recovery_code_);
  CLEAN_INPUT_STRING(request.new_password_);
  CLEAN_INPUT_STRING(request.new_hint_);
  send_closure(td_->auth_manager_actor_, &AuthManager::recover_password, id, std::move(request.recovery_code_),
               std::move(request.new_password_), std::move(request.new_hint_));
}

void Requests::on_request(uint64 id, const td_api::logOut &request) {
  // will call Td::destroy later
  send_closure(td_->auth_manager_actor_, &AuthManager::log_out, id);
}

void Requests::on_request(uint64 id, const td_api::close &request) {
  // send response before actually closing
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
  send_closure(td_actor_, &Td::close);
}

void Requests::on_request(uint64 id, const td_api::destroy &request) {
  // send response before actually destroying
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
  send_closure(td_actor_, &Td::destroy);
}

void Requests::on_request(uint64 id, td_api::checkAuthenticationBotToken &request) {
  CLEAN_INPUT_STRING(request.token_);
  send_closure(td_->auth_manager_actor_, &AuthManager::check_bot_token, id, std::move(request.token_));
}

void Requests::on_request(uint64 id, td_api::confirmQrCodeAuthentication &request) {
  CLEAN_INPUT_STRING(request.link_);
  CREATE_REQUEST_PROMISE();
  td_->account_manager_->confirm_qr_code_authentication(request.link_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCurrentState &request) {
  vector<td_api::object_ptr<td_api::Update>> updates;

  td_->option_manager_->get_current_state(updates);

  auto state = td_->auth_manager_->get_current_authorization_state_object();
  if (state != nullptr) {
    updates.push_back(td_api::make_object<td_api::updateAuthorizationState>(std::move(state)));
  }

  td_->connection_state_manager_->get_current_state(updates);

  if (td_->auth_manager_->is_authorized()) {
    td_->user_manager_->get_current_state(updates);

    td_->chat_manager_->get_current_state(updates);

    td_->background_manager_->get_current_state(updates);

    td_->animations_manager_->get_current_state(updates);

    td_->attach_menu_manager_->get_current_state(updates);

    td_->stickers_manager_->get_current_state(updates);

    td_->reaction_manager_->get_current_state(updates);

    td_->notification_settings_manager_->get_current_state(updates);

    td_->dialog_filter_manager_->get_current_state(updates);

    td_->messages_manager_->get_current_state(updates);

    td_->dialog_participant_manager_->get_current_state(updates);

    td_->notification_manager_->get_current_state(updates);

    td_->quick_reply_manager_->get_current_state(updates);

    td_->saved_messages_manager_->get_current_state(updates);

    td_->story_manager_->get_current_state(updates);

    td_->suggested_action_manager_->get_current_state(updates);

    td_->transcription_manager_->get_current_state(updates);

    td_->autosave_manager_->get_current_state(updates);

    td_->account_manager_->get_current_state(updates);

    td_->business_connection_manager_->get_current_state(updates);

    td_->terms_of_service_manager_->get_current_state(updates);

    td_->star_manager_->get_current_state(updates);

    // TODO updateFileGenerationStart generation_id:int64 original_path:string destination_path:string conversion:string = Update;
    // TODO updateCall call:call = Update;
    // TODO updateGroupCall call:groupCall = Update;
  }

  // send response synchronously to prevent "Request aborted" or other changes of the current state
  td_->send_result(id, td_api::make_object<td_api::updates>(std::move(updates)));
}

void Requests::on_request(uint64 id, const td_api::getPasswordState &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::get_state, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setPassword &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.old_password_);
  CLEAN_INPUT_STRING(request.new_password_);
  CLEAN_INPUT_STRING(request.new_hint_);
  CLEAN_INPUT_STRING(request.new_recovery_email_address_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::set_password, std::move(request.old_password_),
               std::move(request.new_password_), std::move(request.new_hint_), request.set_recovery_email_address_,
               std::move(request.new_recovery_email_address_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setLoginEmailAddress &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.new_login_email_address_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<SentEmailCode> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_email_address_authentication_code_info_object());
    }
  });
  send_closure(td_->password_manager_, &PasswordManager::set_login_email_address,
               std::move(request.new_login_email_address_), std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::resendLoginEmailAddressCode &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<SentEmailCode> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_email_address_authentication_code_info_object());
    }
  });
  send_closure(td_->password_manager_, &PasswordManager::resend_login_email_address_code, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::checkLoginEmailAddressCode &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::check_login_email_address_code,
               EmailVerification(std::move(request.code_)), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setRecoveryEmailAddress &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CLEAN_INPUT_STRING(request.new_recovery_email_address_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::set_recovery_email_address, std::move(request.password_),
               std::move(request.new_recovery_email_address_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getRecoveryEmailAddress &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::get_recovery_email_address, std::move(request.password_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkRecoveryEmailAddressCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.code_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::check_recovery_email_address_code, std::move(request.code_),
               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::resendRecoveryEmailAddressCode &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::resend_recovery_email_address_code, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::cancelRecoveryEmailAddressVerification &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::cancel_recovery_email_address_verification,
               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::requestPasswordRecovery &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<SentEmailCode> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_email_address_authentication_code_info_object());
    }
  });
  send_closure(td_->password_manager_, &PasswordManager::request_password_recovery, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::checkPasswordRecoveryCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.recovery_code_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::check_password_recovery_code,
               std::move(request.recovery_code_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::recoverPassword &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.recovery_code_);
  CLEAN_INPUT_STRING(request.new_password_);
  CLEAN_INPUT_STRING(request.new_hint_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::recover_password, std::move(request.recovery_code_),
               std::move(request.new_password_), std::move(request.new_hint_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::resetPassword &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::reset_password, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::cancelPasswordReset &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::cancel_password_reset, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getTemporaryPasswordState &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::get_temp_password_state, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createTemporaryPassword &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::create_temp_password, std::move(request.password_),
               request.valid_for_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::processPushNotification &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.payload_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->notification_manager(), &NotificationManager::process_push_notification,
               std::move(request.payload_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::registerDevice &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->device_token_manager_, &DeviceTokenManager::register_device, std::move(request.device_token_),
               UserId::get_user_ids(request.other_user_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getUserPrivacySettingRules &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->privacy_manager_->get_privacy(std::move(request.setting_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setUserPrivacySettingRules &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->privacy_manager_->set_privacy(std::move(request.setting_), std::move(request.rules_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultMessageAutoDeleteTime &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<int32> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::messageAutoDeleteTime>(result.ok()));
    }
  });
  td_->account_manager_->get_default_message_ttl(std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::setDefaultMessageAutoDeleteTime &request) {
  CHECK_IS_USER();
  if (request.message_auto_delete_time_ == nullptr) {
    return send_error_raw(id, 400, "New default message auto-delete time must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->set_default_message_ttl(request.message_auto_delete_time_->time_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getAccountTtl &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<int32> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::accountTtl>(result.ok()));
    }
  });
  td_->account_manager_->get_account_ttl(std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::setAccountTtl &request) {
  CHECK_IS_USER();
  if (request.ttl_ == nullptr) {
    return send_error_raw(id, 400, "New account TTL must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->set_account_ttl(request.ttl_->days_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteAccount &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.reason_);
  send_closure(td_->auth_manager_actor_, &AuthManager::delete_account, id, request.reason_, request.password_);
}

void Requests::on_request(uint64 id, td_api::sendPhoneNumberCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.phone_number_);
  CREATE_REQUEST_PROMISE();
  td_->phone_number_manager_->set_phone_number(std::move(request.phone_number_), std::move(request.settings_),
                                               std::move(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendPhoneNumberFirebaseSms &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.token_);
  CREATE_OK_REQUEST_PROMISE();
  td_->phone_number_manager_->send_firebase_sms(std::move(request.token_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reportPhoneNumberCodeMissing &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.mobile_network_code_);
  CREATE_OK_REQUEST_PROMISE();
  td_->phone_number_manager_->report_missing_code(std::move(request.mobile_network_code_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::resendPhoneNumberCode &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->phone_number_manager_->resend_authentication_code(std::move(request.reason_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkPhoneNumberCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.code_);
  CREATE_OK_REQUEST_PROMISE();
  td_->phone_number_manager_->check_code(std::move(request.code_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getUserLink &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->account_manager_->get_user_link(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchUserByToken &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.token_);
  CREATE_REQUEST_PROMISE();
  td_->account_manager_->import_contact_token(std::move(request.token_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getActiveSessions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->account_manager_->get_active_sessions(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::terminateSession &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->terminate_session(request.session_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::terminateAllOtherSessions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->terminate_all_other_sessions(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::confirmSession &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->confirm_session(request.session_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSessionCanAcceptCalls &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->toggle_session_can_accept_calls(request.session_id_, request.can_accept_calls_,
                                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSessionCanAcceptSecretChats &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->toggle_session_can_accept_secret_chats(request.session_id_, request.can_accept_secret_chats_,
                                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setInactiveSessionTtl &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->set_inactive_session_ttl_days(request.inactive_session_ttl_days_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getConnectedWebsites &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->account_manager_->get_connected_websites(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::disconnectWebsite &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->disconnect_website(request.website_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::disconnectAllWebsites &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->account_manager_->disconnect_all_websites(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMe &request) {
  CREATE_NO_ARGS_REQUEST(GetMeRequest);
}

void Requests::on_request(uint64 id, const td_api::getUser &request) {
  CREATE_REQUEST(GetUserRequest, request.user_id_);
}

void Requests::on_request(uint64 id, const td_api::getUserFullInfo &request) {
  CREATE_REQUEST(GetUserFullInfoRequest, request.user_id_);
}

void Requests::on_request(uint64 id, const td_api::getBasicGroup &request) {
  CREATE_REQUEST(GetGroupRequest, request.basic_group_id_);
}

void Requests::on_request(uint64 id, const td_api::getBasicGroupFullInfo &request) {
  CREATE_REQUEST(GetGroupFullInfoRequest, request.basic_group_id_);
}

void Requests::on_request(uint64 id, const td_api::getSupergroup &request) {
  CREATE_REQUEST(GetSupergroupRequest, request.supergroup_id_);
}

void Requests::on_request(uint64 id, const td_api::getSupergroupFullInfo &request) {
  CREATE_REQUEST(GetSupergroupFullInfoRequest, request.supergroup_id_);
}

void Requests::on_request(uint64 id, const td_api::getSecretChat &request) {
  CREATE_REQUEST(GetSecretChatRequest, request.secret_chat_id_);
}

void Requests::on_request(uint64 id, const td_api::getChat &request) {
  CREATE_REQUEST(GetChatRequest, request.chat_id_);
}

void Requests::on_request(uint64 id, const td_api::getMessage &request) {
  CREATE_REQUEST(GetMessageRequest, request.chat_id_, request.message_id_);
}

void Requests::on_request(uint64 id, const td_api::getMessageLocally &request) {
  MessageFullId message_full_id(DialogId(request.chat_id_), MessageId(request.message_id_));
  send_closure(td_actor_, &Td::send_result, id,
               td_->messages_manager_->get_message_object(message_full_id, "getMessageLocally"));
}

void Requests::on_request(uint64 id, const td_api::getRepliedMessage &request) {
  CREATE_REQUEST(GetRepliedMessageRequest, request.chat_id_, request.message_id_);
}

void Requests::on_request(uint64 id, const td_api::getChatPinnedMessage &request) {
  CREATE_REQUEST(GetChatPinnedMessageRequest, request.chat_id_);
}

void Requests::on_request(uint64 id, const td_api::getCallbackQueryMessage &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST(GetCallbackQueryMessageRequest, request.chat_id_, request.message_id_, request.callback_query_id_);
}

void Requests::on_request(uint64 id, const td_api::getMessages &request) {
  CREATE_REQUEST(GetMessagesRequest, request.chat_id_, request.message_ids_);
}

void Requests::on_request(uint64 id, const td_api::getMessageProperties &request) {
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_message_properties(DialogId(request.chat_id_), MessageId(request.message_id_),
                                                 std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatSponsoredMessages &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->sponsored_message_manager_->get_dialog_sponsored_messages(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clickChatSponsoredMessage &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->sponsored_message_manager_->click_sponsored_message(DialogId(request.chat_id_), MessageId(request.message_id_),
                                                           request.is_media_click_, request.from_fullscreen_,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reportChatSponsoredMessage &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->sponsored_message_manager_->report_sponsored_message(DialogId(request.chat_id_), MessageId(request.message_id_),
                                                            request.option_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageThread &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetMessageThreadRequest, request.chat_id_, request.message_id_);
}

void Requests::on_request(uint64 id, const td_api::getMessageReadDate &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_message_read_date({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageViewers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->get_message_viewers({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                   std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageLink &request) {
  auto r_message_link = td_->messages_manager_->get_message_link(
      {DialogId(request.chat_id_), MessageId(request.message_id_)}, request.media_timestamp_, request.for_album_,
      request.in_message_thread_);
  if (r_message_link.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_message_link.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id,
                 td_api::make_object<td_api::messageLink>(r_message_link.ok().first, r_message_link.ok().second));
  }
}

void Requests::on_request(uint64 id, const td_api::getMessageEmbeddingCode &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetMessageEmbeddingCodeRequest, request.chat_id_, request.message_id_, request.for_album_);
}

void Requests::on_request(uint64 id, td_api::getMessageLinkInfo &request) {
  CLEAN_INPUT_STRING(request.url_);
  CREATE_REQUEST(GetMessageLinkInfoRequest, std::move(request.url_));
}

void Requests::on_request(uint64 id, td_api::translateText &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.to_language_code_);
  CREATE_REQUEST_PROMISE();
  td_->translation_manager_->translate_text(std::move(request.text_), request.to_language_code_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::translateMessageText &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.to_language_code_);
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->translate_message_text({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                 request.to_language_code_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::recognizeSpeech &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->transcription_manager_->recognize_speech({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::rateSpeechRecognition &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->transcription_manager_->rate_speech_recognition({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                       request.is_good_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getFile &request) {
  auto file_object = td_->file_manager_->get_file_object(FileId(request.file_id_, 0));
  if (file_object->id_ == 0) {
    file_object = nullptr;
  } else {
    file_object->id_ = request.file_id_;
  }
  send_closure(td_actor_, &Td::send_result, id, std::move(file_object));
}

void Requests::on_request(uint64 id, td_api::getRemoteFile &request) {
  CLEAN_INPUT_STRING(request.remote_file_id_);
  auto file_type = request.file_type_ == nullptr ? FileType::Temp : get_file_type(*request.file_type_);
  auto r_file_id = td_->file_manager_->from_persistent_id(request.remote_file_id_, file_type);
  if (r_file_id.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_file_id.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, td_->file_manager_->get_file_object(r_file_id.ok()));
  }
}

void Requests::on_request(uint64 id, const td_api::getStorageStatistics &request) {
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<FileStats> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_storage_statistics_object());
    }
  });
  send_closure(td_->storage_manager_, &StorageManager::get_storage_stats, false /*need_all_files*/, request.chat_limit_,
               std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getStorageStatisticsFast &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<FileStatsFast> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_storage_statistics_fast_object());
    }
  });
  send_closure(td_->storage_manager_, &StorageManager::get_storage_stats_fast, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getDatabaseStatistics &request) {
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<DatabaseStats> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_database_statistics_object());
    }
  });
  send_closure(td_->storage_manager_, &StorageManager::get_database_stats, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::optimizeStorage &request) {
  std::vector<FileType> file_types;
  for (auto &file_type : request.file_types_) {
    if (file_type == nullptr) {
      return send_error_raw(id, 400, "File type must be non-empty");
    }

    file_types.push_back(get_file_type(*file_type));
  }
  FileGcParameters parameters(request.size_, request.ttl_, request.count_, request.immunity_delay_,
                              std::move(file_types), DialogId::get_dialog_ids(request.chat_ids_),
                              DialogId::get_dialog_ids(request.exclude_chat_ids_), request.chat_limit_);

  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<FileStats> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_storage_statistics_object());
    }
  });
  send_closure(td_->storage_manager_, &StorageManager::run_gc, std::move(parameters),
               request.return_deleted_file_statistics_, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getNetworkStatistics &request) {
  if (td_->net_stats_manager_.empty()) {
    return send_error_raw(id, 400, "Network statistics are disabled");
  }
  if (!request.only_current_ && G()->get_option_boolean("disable_persistent_network_statistics")) {
    return send_error_raw(id, 400, "Persistent network statistics are disabled");
  }
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<NetworkStats> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_network_statistics_object());
    }
  });
  send_closure(td_->net_stats_manager_, &NetStatsManager::get_network_stats, request.only_current_,
               std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::resetNetworkStatistics &request) {
  if (td_->net_stats_manager_.empty()) {
    return send_error_raw(id, 400, "Network statistics are disabled");
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->net_stats_manager_, &NetStatsManager::reset_network_stats);
  promise.set_value(Unit());
}

void Requests::on_request(uint64 id, td_api::addNetworkStatistics &request) {
  if (request.entry_ == nullptr) {
    return send_error_raw(id, 400, "Network statistics entry must be non-empty");
  }
  if (td_->net_stats_manager_.empty()) {
    return send_error_raw(id, 400, "Network statistics are disabled");
  }

  NetworkStatsEntry entry;
  switch (request.entry_->get_id()) {
    case td_api::networkStatisticsEntryFile::ID: {
      auto file_entry = move_tl_object_as<td_api::networkStatisticsEntryFile>(request.entry_);
      entry.is_call = false;
      if (file_entry->file_type_ != nullptr) {
        entry.file_type = get_file_type(*file_entry->file_type_);
      }
      entry.net_type = get_net_type(file_entry->network_type_);
      entry.rx = file_entry->received_bytes_;
      entry.tx = file_entry->sent_bytes_;
      break;
    }
    case td_api::networkStatisticsEntryCall::ID: {
      auto call_entry = move_tl_object_as<td_api::networkStatisticsEntryCall>(request.entry_);
      entry.is_call = true;
      entry.net_type = get_net_type(call_entry->network_type_);
      entry.rx = call_entry->received_bytes_;
      entry.tx = call_entry->sent_bytes_;
      entry.duration = call_entry->duration_;
      break;
    }
    default:
      UNREACHABLE();
  }

  if (entry.net_type == NetType::None) {
    return send_error_raw(id, 400, "Network statistics entry can't be increased for NetworkTypeNone");
  }
  if (entry.rx > (static_cast<int64>(1) << 40) || entry.rx < 0) {
    return send_error_raw(id, 400, "Wrong received bytes value");
  }
  if (entry.tx > (static_cast<int64>(1) << 40) || entry.tx < 0) {
    return send_error_raw(id, 400, "Wrong sent bytes value");
  }
  if (entry.count > (1 << 30) || entry.count < 0) {
    return send_error_raw(id, 400, "Wrong count value");
  }
  if (entry.duration > (1 << 30) || entry.duration < 0) {
    return send_error_raw(id, 400, "Wrong duration value");
  }

  send_closure(td_->net_stats_manager_, &NetStatsManager::add_network_stats, entry);
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::setNetworkType &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->state_manager_, &StateManager::on_network, get_net_type(request.type_));
  promise.set_value(Unit());
}

void Requests::on_request(uint64 id, const td_api::getAutoDownloadSettingsPresets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_auto_download_settings_presets(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setAutoDownloadSettings &request) {
  CHECK_IS_USER();
  if (request.settings_ == nullptr) {
    return send_error_raw(id, 400, "New settings must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  set_auto_download_settings(td_, get_net_type(request.type_), get_auto_download_settings(request.settings_),
                             std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getAutosaveSettings &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->autosave_manager_->get_autosave_settings(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setAutosaveSettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->autosave_manager_->set_autosave_settings(std::move(request.scope_), std::move(request.settings_),
                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clearAutosaveSettingsExceptions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->autosave_manager_->clear_autosave_settings_exceptions(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getRecommendedChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->channel_recommendation_manager_->get_recommended_channels(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatSimilarChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->channel_recommendation_manager_->get_channel_recommendations(DialogId(request.chat_id_), false,
                                                                    std::move(promise), Auto());
}

void Requests::on_request(uint64 id, const td_api::getChatSimilarChatCount &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->channel_recommendation_manager_->get_channel_recommendations(DialogId(request.chat_id_), request.return_local_,
                                                                    Auto(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::openChatSimilarChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->channel_recommendation_manager_->open_channel_recommended_channel(
      DialogId(request.chat_id_), DialogId(request.opened_chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotSimilarBots &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_recommendation_manager_->get_bot_recommendations(UserId(request.bot_user_id_), false, std::move(promise),
                                                            Auto());
}

void Requests::on_request(uint64 id, const td_api::getBotSimilarBotCount &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_recommendation_manager_->get_bot_recommendations(UserId(request.bot_user_id_), request.return_local_, Auto(),
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::openBotSimilarBot &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_recommendation_manager_->open_bot_recommended_bot(UserId(request.bot_user_id_),
                                                             UserId(request.opened_bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getTopChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->top_dialog_manager_actor_, &TopDialogManager::get_top_dialogs,
               get_top_dialog_category(request.category_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeTopChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->top_dialog_manager_actor_, &TopDialogManager::remove_dialog,
               get_top_dialog_category(request.category_), DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadChats &request) {
  CHECK_IS_USER();

  DialogListId dialog_list_id(request.chat_list_);
  auto r_offset = td_->messages_manager_->get_dialog_list_last_date(dialog_list_id);
  if (r_offset.is_error()) {
    return send_error_raw(id, 400, r_offset.error().message());
  }
  auto offset = r_offset.move_as_ok();
  if (offset == MAX_DIALOG_DATE) {
    return send_closure(td_actor_, &Td::send_result, id, nullptr);
  }

  CREATE_REQUEST(LoadChatsRequest, dialog_list_id, offset, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::getChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_dialogs_from_list(DialogListId(request.chat_list_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadSavedMessagesTopics &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->saved_messages_manager_->load_saved_messages_topics(request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSavedMessagesTopicHistory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->saved_messages_manager_->get_saved_messages_topic_history(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), MessageId(request.from_message_id_),
      request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSavedMessagesTopicMessageByDate &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->saved_messages_manager_->get_saved_messages_topic_message_by_date(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), request.date_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteSavedMessagesTopicHistory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->saved_messages_manager_->delete_saved_messages_topic_history(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteSavedMessagesTopicMessagesByDate &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->saved_messages_manager_->delete_saved_messages_topic_messages_by_date(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), request.min_date_,
      request.max_date_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSavedMessagesTopicIsPinned &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->saved_messages_manager_->toggle_saved_messages_topic_is_pinned(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), request.is_pinned_,
      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setPinnedSavedMessagesTopics &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->saved_messages_manager_->set_pinned_saved_messages_topics(
      td_->saved_messages_manager_->get_topic_ids(request.saved_messages_topic_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchPublicChat &request) {
  CLEAN_INPUT_STRING(request.username_);
  CREATE_REQUEST(SearchPublicChatRequest, request.username_);
}

void Requests::on_request(uint64 id, td_api::searchPublicChats &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchPublicChatsRequest, request.query_);
}

void Requests::on_request(uint64 id, td_api::searchChats &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchChatsRequest, request.query_, request.limit_);
}

void Requests::on_request(uint64 id, td_api::searchChatsOnServer &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchChatsOnServerRequest, request.query_, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::getGroupsInCommon &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetGroupsInCommonRequest, request.user_id_, request.offset_chat_id_, request.limit_);
}

void Requests::on_request(uint64 id, td_api::checkChatUsername &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda(
      [promise = std::move(promise)](Result<DialogManager::CheckDialogUsernameResult> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(DialogManager::get_check_chat_username_result_object(result.ok()));
        }
      });
  td_->dialog_manager_->check_dialog_username(DialogId(request.chat_id_), request.username_, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getCreatedPublicChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->chat_manager_->get_created_public_dialogs(get_public_dialog_type(request.type_), std::move(promise), false);
}

void Requests::on_request(uint64 id, const td_api::checkCreatedPublicChatsLimit &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->check_created_public_dialogs_limit(get_public_dialog_type(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSuitableDiscussionChats &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetSuitableDiscussionChatsRequest);
}

void Requests::on_request(uint64 id, const td_api::getInactiveSupergroupChats &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetInactiveSupergroupChatsRequest);
}

void Requests::on_request(uint64 id, const td_api::getSuitablePersonalChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->chat_manager_->get_created_public_dialogs(PublicDialogType::ForPersonalDialog, std::move(promise), false);
}

void Requests::on_request(uint64 id, td_api::searchRecentlyFoundChats &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchRecentlyFoundChatsRequest, request.query_, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::addRecentlyFoundChat &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->dialog_manager_->add_recently_found_dialog(DialogId(request.chat_id_)));
}

void Requests::on_request(uint64 id, const td_api::removeRecentlyFoundChat &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->dialog_manager_->remove_recently_found_dialog(DialogId(request.chat_id_)));
}

void Requests::on_request(uint64 id, const td_api::clearRecentlyFoundChats &request) {
  CHECK_IS_USER();
  td_->dialog_manager_->clear_recently_found_dialogs();
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::getRecentlyOpenedChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetRecentlyOpenedChatsRequest, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::openChat &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->open_dialog(DialogId(request.chat_id_)));
}

void Requests::on_request(uint64 id, const td_api::closeChat &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->close_dialog(DialogId(request.chat_id_)));
}

void Requests::on_request(uint64 id, const td_api::viewMessages &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->view_messages(DialogId(request.chat_id_),
                                                            MessageId::get_message_ids(request.message_ids_),
                                                            get_message_source(request.source_), request.force_read_));
}

void Requests::on_request(uint64 id, const td_api::openMessageContent &request) {
  CHECK_IS_USER();
  answer_ok_query(
      id, td_->messages_manager_->open_message_content({DialogId(request.chat_id_), MessageId(request.message_id_)}));
}

void Requests::on_request(uint64 id, const td_api::clickAnimatedEmojiMessage &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->click_animated_emoji_message({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                       std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getInternalLink &request) {
  auto r_link = LinkManager::get_internal_link(request.type_, !request.is_http_);
  if (r_link.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_link.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::httpUrl>(r_link.move_as_ok()));
  }
}

void Requests::on_request(uint64 id, const td_api::getInternalLinkType &request) {
  auto type = LinkManager::parse_internal_link(request.link_);
  send_closure(td_actor_, &Td::send_result, id, type == nullptr ? nullptr : type->get_internal_link_type_object());
}

void Requests::on_request(uint64 id, td_api::getExternalLinkInfo &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.link_);
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_external_link_info(std::move(request.link_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getExternalLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.link_);
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_link_login_url(request.link_, request.allow_write_access_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatHistory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetChatHistoryRequest, request.chat_id_, request.from_message_id_, request.offset_, request.limit_,
                 request.only_local_);
}

void Requests::on_request(uint64 id, const td_api::deleteChatHistory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->delete_dialog_history(DialogId(request.chat_id_), request.remove_from_chat_list_,
                                                request.revoke_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  DialogId dialog_id(request.chat_id_);
  auto query_promise = [actor_id = td_->messages_manager_actor_.get(), dialog_id,
                        promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &MessagesManager::on_dialog_deleted, dialog_id, std::move(promise));
    }
  };
  td_->dialog_manager_->delete_dialog(dialog_id, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageThreadHistory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetMessageThreadHistoryRequest, request.chat_id_, request.message_id_, request.from_message_id_,
                 request.offset_, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::getChatMessageCalendar &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_dialog_message_calendar(
      DialogId(request.chat_id_), td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_),
      MessageId(request.from_message_id_), get_message_search_filter(request.filter_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchChatMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchChatMessagesRequest, request.chat_id_, std::move(request.query_), std::move(request.sender_id_),
                 request.from_message_id_, request.offset_, request.limit_, std::move(request.filter_),
                 request.message_thread_id_,
                 td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), ReactionType());
}

void Requests::on_request(uint64 id, td_api::searchSecretMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->offline_search_messages(DialogId(request.chat_id_), std::move(request.query_),
                                                  std::move(request.offset_), request.limit_,
                                                  get_message_search_filter(request.filter_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->search_messages(
      DialogListId(request.chat_list_), request.chat_list_ == nullptr, std::move(request.query_),
      std::move(request.offset_), request.limit_, get_message_search_filter(request.filter_),
      std::move(request.chat_type_filter_), request.min_date_, request.max_date_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchSavedMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchChatMessagesRequest, td_->dialog_manager_->get_my_dialog_id().get(), std::move(request.query_),
                 nullptr, request.from_message_id_, request.offset_, request.limit_, nullptr, 0,
                 td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_),
                 ReactionType(request.tag_));
}

void Requests::on_request(uint64 id, const td_api::searchCallMessages &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->search_call_messages(request.offset_, request.limit_, request.only_missed_,
                                               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchOutgoingDocumentMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->search_outgoing_document_messages(request.query_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchPublicMessagesByTag &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.tag_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->search_hashtag_posts(std::move(request.tag_), std::move(request.offset_), request.limit_,
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchPublicStoriesByTag &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.tag_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->search_hashtag_posts(DialogId(request.story_sender_chat_id_), std::move(request.tag_),
                                            std::move(request.offset_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchPublicStoriesByLocation &request) {
  CHECK_IS_USER();
  if (request.address_ == nullptr) {
    return send_error_raw(id, 400, "Address must be non-empty");
  }
  CLEAN_INPUT_STRING(request.address_->country_code_);
  CLEAN_INPUT_STRING(request.address_->state_);
  CLEAN_INPUT_STRING(request.address_->city_);
  CLEAN_INPUT_STRING(request.address_->street_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->search_location_posts(std::move(request.address_), std::move(request.offset_), request.limit_,
                                             std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchPublicStoriesByVenue &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.venue_provider_);
  CLEAN_INPUT_STRING(request.venue_id_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->search_venue_posts(std::move(request.venue_provider_), std::move(request.venue_id_),
                                          std::move(request.offset_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getSearchedForTags &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.tag_prefix_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<vector<string>> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::hashtags>(result.move_as_ok()));
    }
  });
  send_closure(request.tag_prefix_[0] == '$' ? td_->cashtag_search_hints_ : td_->hashtag_search_hints_,
               &HashtagHints::query, std::move(request.tag_prefix_), request.limit_, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::removeSearchedForTag &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.tag_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(request.tag_[0] == '$' ? td_->cashtag_search_hints_ : td_->hashtag_search_hints_,
               &HashtagHints::remove_hashtag, std::move(request.tag_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clearSearchedForTags &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(request.clear_cashtags_ ? td_->cashtag_search_hints_ : td_->hashtag_search_hints_, &HashtagHints::clear,
               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteAllCallMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->delete_all_call_messages(request.revoke_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::searchChatRecentLocationMessages &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->search_dialog_recent_location_messages(DialogId(request.chat_id_), request.limit_,
                                                                      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatMessageByDate &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_dialog_message_by_date(DialogId(request.chat_id_), request.date_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatSparseMessagePositions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_dialog_sparse_message_positions(
      DialogId(request.chat_id_), td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_),
      get_message_search_filter(request.filter_), MessageId(request.from_message_id_), request.limit_,
      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatMessageCount &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<int32> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::count>(result.move_as_ok()));
    }
  });
  td_->messages_manager_->get_dialog_message_count(
      DialogId(request.chat_id_), td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_),
      get_message_search_filter(request.filter_), request.return_local_, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getChatMessagePosition &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<int32> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::count>(result.move_as_ok()));
    }
  });
  td_->messages_manager_->get_dialog_message_position(
      {DialogId(request.chat_id_), MessageId(request.message_id_)}, get_message_search_filter(request.filter_),
      MessageId(request.message_thread_id_),
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getChatScheduledMessages &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetChatScheduledMessagesRequest, request.chat_id_);
}

void Requests::on_request(uint64 id, const td_api::getEmojiReaction &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->reaction_manager_->get_emoji_reaction(request.emoji_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCustomEmojiReactionAnimations &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_custom_emoji_reaction_generic_animations(false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageAvailableReactions &request) {
  CHECK_IS_USER();
  auto r_reactions = td_->messages_manager_->get_message_available_reactions(
      {DialogId(request.chat_id_), MessageId(request.message_id_)}, request.row_size_);
  if (r_reactions.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_reactions.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_reactions.move_as_ok());
  }
}

void Requests::on_request(uint64 id, const td_api::clearRecentReactions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->reaction_manager_->clear_recent_reactions(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::addMessageReaction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->add_message_reaction({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                               ReactionType(request.reaction_type_), request.is_big_,
                                               request.update_recent_reactions_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatAvailablePaidMessageReactionSenders &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->message_query_manager_->get_paid_message_reaction_senders(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::addPendingPaidMessageReaction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->add_paid_message_reaction({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                    request.star_count_, request.type_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::commitPendingPaidMessageReactions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->commit_paid_message_reactions({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                        std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removePendingPaidMessageReactions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->remove_paid_message_reactions({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                        std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setPaidMessageReactionType &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_paid_message_reaction_type({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                         request.type_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeMessageReaction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->remove_message_reaction({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                  ReactionType(request.reaction_type_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setMessageReactions &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  set_message_reactions(td_, {DialogId(request.chat_id_), MessageId(request.message_id_)},
                        ReactionType::get_reaction_types(request.reaction_types_), request.is_big_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getMessageAddedReactions &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  get_message_added_reactions(td_, {DialogId(request.chat_id_), MessageId(request.message_id_)},
                              ReactionType(request.reaction_type_), std::move(request.offset_), request.limit_,
                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setDefaultReactionType &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->reaction_manager_->set_default_reaction(ReactionType(request.reaction_type_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSavedMessagesTags &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->reaction_manager_->get_saved_messages_tags(
      td_->saved_messages_manager_->get_topic_id(request.saved_messages_topic_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setSavedMessagesTagLabel &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.label_);
  CREATE_OK_REQUEST_PROMISE();
  td_->reaction_manager_->set_saved_messages_tag_title(ReactionType(request.tag_), std::move(request.label_),
                                                       std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageEffect &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->reaction_manager_->get_message_effect(MessageEffectId(request.effect_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getMessagePublicForwards &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_message_public_forwards({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                        std::move(request.offset_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getStoryPublicForwards &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_story_public_forwards(
      {DialogId(request.story_sender_chat_id_), StoryId(request.story_id_)}, std::move(request.offset_), request.limit_,
      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeNotification &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->notification_manager_actor_, &NotificationManager::remove_notification,
               NotificationGroupId(request.notification_group_id_), NotificationId(request.notification_id_), false,
               true, std::move(promise), "td_api::removeNotification");
}

void Requests::on_request(uint64 id, const td_api::removeNotificationGroup &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->notification_manager_actor_, &NotificationManager::remove_notification_group,
               NotificationGroupId(request.notification_group_id_), NotificationId(request.max_notification_id_),
               NotificationObjectId(), -1, true, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteMessages &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->delete_messages(DialogId(request.chat_id_), MessageId::get_message_ids(request.message_ids_),
                                          request.revoke_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChatMessagesBySender &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, sender_dialog_id, get_message_sender_dialog_id(td_, request.sender_id_, false, false));
  td_->messages_manager_->delete_dialog_messages_by_sender(DialogId(request.chat_id_), sender_dialog_id,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChatMessagesByDate &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->delete_dialog_messages_by_date(DialogId(request.chat_id_), request.min_date_,
                                                         request.max_date_, request.revoke_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::readAllChatMentions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->read_all_dialog_mentions(DialogId(request.chat_id_), MessageId(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::readAllMessageThreadMentions &request) {
  CHECK_IS_USER();
  if (request.message_thread_id_ == 0) {
    return send_error_raw(id, 400, "Invalid message thread identifier specified");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->read_all_dialog_mentions(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                   std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::readAllChatReactions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->read_all_dialog_reactions(DialogId(request.chat_id_), MessageId(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::readAllMessageThreadReactions &request) {
  CHECK_IS_USER();
  if (request.message_thread_id_ == 0) {
    return send_error_raw(id, 400, "Invalid message thread identifier specified");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->read_all_dialog_reactions(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatAvailableMessageSenders &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_dialog_send_message_as_dialog_ids(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatMessageSender &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, message_sender_dialog_id,
                     get_message_sender_dialog_id(td_, request.message_sender_id_, true, false));
  td_->messages_manager_->set_dialog_default_send_message_as_dialog_id(DialogId(request.chat_id_),
                                                                       message_sender_dialog_id, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendMessage &request) {
  auto r_sent_message = td_->messages_manager_->send_message(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), std::move(request.reply_to_),
      std::move(request.options_), std::move(request.reply_markup_), std::move(request.input_message_content_));
  if (r_sent_message.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_sent_message.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_sent_message.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::sendMessageAlbum &request) {
  auto r_messages = td_->messages_manager_->send_message_group(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), std::move(request.reply_to_),
      std::move(request.options_), std::move(request.input_message_contents_));
  if (r_messages.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_messages.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_messages.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::sendBotStartMessage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.parameter_);

  DialogId dialog_id(request.chat_id_);
  auto r_new_message_id =
      td_->messages_manager_->send_bot_start_message(UserId(request.bot_user_id_), dialog_id, request.parameter_);
  if (r_new_message_id.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_new_message_id.move_as_error());
  }

  CHECK(r_new_message_id.ok().is_valid() || r_new_message_id.ok().is_valid_scheduled());
  send_closure(td_actor_, &Td::send_result, id,
               td_->messages_manager_->get_message_object({dialog_id, r_new_message_id.ok()}, "sendBotStartMessage"));
}

void Requests::on_request(uint64 id, td_api::sendInlineQueryResultMessage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.result_id_);

  auto r_sent_message = td_->messages_manager_->send_inline_query_result_message(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), std::move(request.reply_to_),
      std::move(request.options_), request.query_id_, request.result_id_, request.hide_via_bot_);
  if (r_sent_message.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_sent_message.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_sent_message.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::addLocalMessage &request) {
  CHECK_IS_USER();

  DialogId dialog_id(request.chat_id_);
  auto r_new_message_id = td_->messages_manager_->add_local_message(
      dialog_id, std::move(request.sender_id_), std::move(request.reply_to_), request.disable_notification_,
      std::move(request.input_message_content_));
  if (r_new_message_id.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_new_message_id.move_as_error());
  }

  CHECK(r_new_message_id.ok().is_valid());
  send_closure(td_actor_, &Td::send_result, id,
               td_->messages_manager_->get_message_object({dialog_id, r_new_message_id.ok()}, "addLocalMessage"));
}

void Requests::on_request(uint64 id, td_api::editMessageText &request) {
  CREATE_REQUEST(EditMessageTextRequest, request.chat_id_, request.message_id_, std::move(request.reply_markup_),
                 std::move(request.input_message_content_));
}

void Requests::on_request(uint64 id, td_api::editMessageLiveLocation &request) {
  CREATE_REQUEST(EditMessageLiveLocationRequest, request.chat_id_, request.message_id_,
                 std::move(request.reply_markup_), std::move(request.location_), request.live_period_, request.heading_,
                 request.proximity_alert_radius_);
}

void Requests::on_request(uint64 id, td_api::editMessageMedia &request) {
  CREATE_REQUEST(EditMessageMediaRequest, request.chat_id_, request.message_id_, std::move(request.reply_markup_),
                 std::move(request.input_message_content_));
}

void Requests::on_request(uint64 id, td_api::editMessageCaption &request) {
  CREATE_REQUEST(EditMessageCaptionRequest, request.chat_id_, request.message_id_, std::move(request.reply_markup_),
                 std::move(request.caption_), request.show_caption_above_media_);
}

void Requests::on_request(uint64 id, td_api::editMessageReplyMarkup &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST(EditMessageReplyMarkupRequest, request.chat_id_, request.message_id_,
                 std::move(request.reply_markup_));
}

void Requests::on_request(uint64 id, td_api::editInlineMessageText &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->edit_inline_message_text(request.inline_message_id_, std::move(request.reply_markup_),
                                                         std::move(request.input_message_content_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editInlineMessageLiveLocation &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->edit_inline_message_live_location(
      request.inline_message_id_, std::move(request.reply_markup_), std::move(request.location_), request.live_period_,
      request.heading_, request.proximity_alert_radius_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editInlineMessageMedia &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->edit_inline_message_media(request.inline_message_id_, std::move(request.reply_markup_),
                                                          std::move(request.input_message_content_),
                                                          std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editInlineMessageCaption &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->edit_inline_message_caption(
      request.inline_message_id_, std::move(request.reply_markup_), std::move(request.caption_),
      request.show_caption_above_media_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editInlineMessageReplyMarkup &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->edit_inline_message_reply_markup(request.inline_message_id_,
                                                                 std::move(request.reply_markup_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editMessageSchedulingState &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->edit_message_scheduling_state({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                        std::move(request.scheduling_state_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setMessageFactCheck &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_message_fact_check({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                 std::move(request.text_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendBusinessMessage &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->send_message(BusinessConnectionId(std::move(request.business_connection_id_)),
                                                  DialogId(request.chat_id_), std::move(request.reply_to_),
                                                  request.disable_notification_, request.protect_content_,
                                                  MessageEffectId(request.effect_id_), std::move(request.reply_markup_),
                                                  std::move(request.input_message_content_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendBusinessMessageAlbum &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->send_message_album(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      std::move(request.reply_to_), request.disable_notification_, request.protect_content_,
      MessageEffectId(request.effect_id_), std::move(request.input_message_contents_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessMessageText &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->edit_business_message_text(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      MessageId(request.message_id_), std::move(request.reply_markup_), std::move(request.input_message_content_),
      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessMessageLiveLocation &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->edit_business_message_live_location(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      MessageId(request.message_id_), std::move(request.reply_markup_), std::move(request.location_),
      request.live_period_, request.heading_, request.proximity_alert_radius_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessMessageMedia &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->edit_business_message_media(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      MessageId(request.message_id_), std::move(request.reply_markup_), std::move(request.input_message_content_),
      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessMessageCaption &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->edit_business_message_caption(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      MessageId(request.message_id_), std::move(request.reply_markup_), std::move(request.caption_),
      request.show_caption_above_media_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessMessageReplyMarkup &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->edit_business_message_reply_markup(
      BusinessConnectionId(std::move(request.business_connection_id_)), DialogId(request.chat_id_),
      MessageId(request.message_id_), std::move(request.reply_markup_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::stopBusinessPoll &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->stop_poll(BusinessConnectionId(std::move(request.business_connection_id_)),
                                               DialogId(request.chat_id_), MessageId(request.message_id_),
                                               std::move(request.reply_markup_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessMessageIsPinned &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->pin_dialog_message(BusinessConnectionId(std::move(request.business_connection_id_)),
                                             DialogId(request.chat_id_), MessageId(request.message_id_), true, false,
                                             !request.is_pinned_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadQuickReplyShortcuts &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->get_quick_reply_shortcuts(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setQuickReplyShortcutName &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->set_quick_reply_shortcut_name(QuickReplyShortcutId(request.shortcut_id_), request.name_,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteQuickReplyShortcut &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->delete_quick_reply_shortcut(QuickReplyShortcutId(request.shortcut_id_),
                                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reorderQuickReplyShortcuts &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->reorder_quick_reply_shortcuts(
      QuickReplyShortcutId::get_quick_reply_shortcut_ids(request.shortcut_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadQuickReplyShortcutMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->get_quick_reply_shortcut_messages(QuickReplyShortcutId(request.shortcut_id_),
                                                               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteQuickReplyShortcutMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->delete_quick_reply_shortcut_messages(
      QuickReplyShortcutId(request.shortcut_id_), MessageId::get_message_ids(request.message_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addQuickReplyShortcutMessage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.shortcut_name_);
  auto r_sent_message = td_->quick_reply_manager_->send_message(
      request.shortcut_name_, MessageId(request.reply_to_message_id_), std::move(request.input_message_content_));
  if (r_sent_message.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_sent_message.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_sent_message.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::addQuickReplyShortcutInlineQueryResultMessage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.shortcut_name_);
  CLEAN_INPUT_STRING(request.result_id_);
  auto r_sent_message = td_->quick_reply_manager_->send_inline_query_result_message(
      request.shortcut_name_, MessageId(request.reply_to_message_id_), request.query_id_, request.result_id_,
      request.hide_via_bot_);
  if (r_sent_message.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_sent_message.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_sent_message.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::addQuickReplyShortcutMessageAlbum &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.shortcut_name_);
  auto r_messages = td_->quick_reply_manager_->send_message_group(
      request.shortcut_name_, MessageId(request.reply_to_message_id_), std::move(request.input_message_contents_));
  if (r_messages.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_messages.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_messages.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::readdQuickReplyShortcutMessages &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.shortcut_name_);
  auto r_messages = td_->quick_reply_manager_->resend_messages(request.shortcut_name_,
                                                               MessageId::get_message_ids(request.message_ids_));
  if (r_messages.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_messages.move_as_error());
  }
  send_closure(td_actor_, &Td::send_result, id, r_messages.move_as_ok());
}

void Requests::on_request(uint64 id, td_api::editQuickReplyMessage &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->quick_reply_manager_->edit_quick_reply_message(QuickReplyShortcutId(request.shortcut_id_),
                                                      MessageId(request.message_id_),
                                                      std::move(request.input_message_content_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCurrentWeather &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->inline_queries_manager_->get_weather(Location(request.location_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_story(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                 request.only_local_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatsToSendStories &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_dialogs_to_send_stories(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::canSendStory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->can_send_story(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendStory &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->send_story(DialogId(request.chat_id_), std::move(request.content_), std::move(request.areas_),
                                  std::move(request.caption_), std::move(request.privacy_settings_),
                                  request.active_period_, std::move(request.from_story_full_id_),
                                  request.is_posted_to_chat_page_, request.protect_content_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editStory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->edit_story(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                  std::move(request.content_), std::move(request.areas_), std::move(request.caption_),
                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::editStoryCover &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->edit_story_cover(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                        request.cover_frame_timestamp_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStoryPrivacySettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->set_story_privacy_settings(StoryId(request.story_id_), std::move(request.privacy_settings_),
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleStoryIsPostedToChatPage &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->toggle_story_is_pinned(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                              request.is_posted_to_chat_page_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteStory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->delete_story(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                    std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadActiveStories &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->load_active_stories(StoryListId(request.story_list_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatActiveStoriesList &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->toggle_dialog_stories_hidden(DialogId(request.chat_id_), StoryListId(request.story_list_),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getForumTopicDefaultIcons &request) {
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_topic_icons(false, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createForumTopic &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->forum_topic_manager_->create_forum_topic(DialogId(request.chat_id_), std::move(request.name_),
                                                std::move(request.icon_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editForumTopic &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->edit_forum_topic(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                              std::move(request.name_), request.edit_icon_custom_emoji_,
                                              CustomEmojiId(request.icon_custom_emoji_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getForumTopic &request) {
  CREATE_REQUEST_PROMISE();
  td_->forum_topic_manager_->get_forum_topic(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                             std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getForumTopicLink &request) {
  CREATE_REQUEST_PROMISE();
  td_->forum_topic_manager_->get_forum_topic_link(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getForumTopics &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST_PROMISE();
  td_->forum_topic_manager_->get_forum_topics(DialogId(request.chat_id_), std::move(request.query_),
                                              request.offset_date_, MessageId(request.offset_message_id_),
                                              MessageId(request.offset_message_thread_id_), request.limit_,
                                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleForumTopicIsClosed &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->toggle_forum_topic_is_closed(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), request.is_closed_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGeneralForumTopicIsHidden &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->toggle_forum_topic_is_hidden(DialogId(request.chat_id_), request.is_hidden_,
                                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleForumTopicIsPinned &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->toggle_forum_topic_is_pinned(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), request.is_pinned_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setPinnedForumTopics &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->set_pinned_forum_topics(
      DialogId(request.chat_id_), MessageId::get_message_ids(request.message_thread_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteForumTopic &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->forum_topic_manager_->delete_forum_topic(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setGameScore &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->game_manager_->set_game_score({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                     request.edit_message_, UserId(request.user_id_), request.score_, request.force_,
                                     std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setInlineGameScore &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_message_manager_->set_inline_game_score(request.inline_message_id_, request.edit_message_,
                                                      UserId(request.user_id_), request.score_, request.force_,
                                                      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGameHighScores &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->game_manager_->get_game_high_scores({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                           UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getInlineGameHighScores &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.inline_message_id_);
  CREATE_REQUEST_PROMISE();
  td_->inline_message_manager_->get_inline_game_high_scores(request.inline_message_id_, UserId(request.user_id_),
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChatReplyMarkup &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->delete_dialog_reply_markup(DialogId(request.chat_id_),
                                                                         MessageId(request.message_id_)));
}

void Requests::on_request(uint64 id, td_api::sendChatAction &request) {
  CLEAN_INPUT_STRING(request.business_connection_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_action_manager_->send_dialog_action(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                  BusinessConnectionId(std::move(request.business_connection_id_)),
                                                  DialogAction(std::move(request.action_)), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::forwardMessages &request) {
  auto input_message_ids = MessageId::get_message_ids(request.message_ids_);
  auto message_copy_options =
      transform(input_message_ids, [send_copy = request.send_copy_, remove_caption = request.remove_caption_](
                                       MessageId) { return MessageCopyOptions(send_copy, remove_caption); });
  auto r_messages = td_->messages_manager_->forward_messages(
      DialogId(request.chat_id_), MessageId(request.message_thread_id_), DialogId(request.from_chat_id_),
      std::move(input_message_ids), std::move(request.options_), false, -1, std::move(message_copy_options));
  if (r_messages.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_messages.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_messages.move_as_ok());
  }
}

void Requests::on_request(uint64 id, const td_api::sendQuickReplyShortcutMessages &request) {
  auto r_messages = td_->messages_manager_->send_quick_reply_shortcut_messages(
      DialogId(request.chat_id_), QuickReplyShortcutId(request.shortcut_id_), request.sending_id_);
  if (r_messages.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_messages.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, r_messages.move_as_ok());
  }
}

void Requests::on_request(uint64 id, td_api::resendMessages &request) {
  DialogId dialog_id(request.chat_id_);
  auto r_message_ids =
      td_->messages_manager_->resend_messages(dialog_id, MessageId::get_message_ids(request.message_ids_),
                                              std::move(request.quote_), request.paid_message_star_count_);
  if (r_message_ids.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_message_ids.move_as_error());
  }

  send_closure(td_actor_, &Td::send_result, id,
               td_->messages_manager_->get_messages_object(-1, dialog_id, r_message_ids.ok(), false, "resendMessages"));
}

void Requests::on_request(uint64 id, td_api::getLinkPreview &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->web_pages_manager_->get_web_page_preview(std::move(request.text_), std::move(request.link_preview_options_),
                                                std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getWebPageInstantView &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.url_);
  CREATE_REQUEST(GetWebPageInstantViewRequest, std::move(request.url_), request.only_local_);
}

void Requests::on_request(uint64 id, const td_api::createPrivateChat &request) {
  CREATE_REQUEST(CreateChatRequest, DialogId(UserId(request.user_id_)), request.force_);
}

void Requests::on_request(uint64 id, const td_api::createBasicGroupChat &request) {
  CREATE_REQUEST(CreateChatRequest, DialogId(ChatId(request.basic_group_id_)), request.force_);
}

void Requests::on_request(uint64 id, const td_api::createSupergroupChat &request) {
  CREATE_REQUEST(CreateChatRequest, DialogId(ChannelId(request.supergroup_id_)), request.force_);
}

void Requests::on_request(uint64 id, const td_api::createSecretChat &request) {
  CREATE_REQUEST(CreateChatRequest, DialogId(SecretChatId(request.secret_chat_id_)), true);
}

void Requests::on_request(uint64 id, td_api::createNewBasicGroupChat &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.title_);
  CREATE_REQUEST_PROMISE();
  td_->chat_manager_->create_new_chat(UserId::get_user_ids(request.user_ids_), std::move(request.title_),
                                      MessageTtl(request.message_auto_delete_time_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createNewSupergroupChat &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.title_);
  CLEAN_INPUT_STRING(request.description_);
  CREATE_REQUEST_PROMISE();
  td_->chat_manager_->create_new_channel(std::move(request.title_), request.is_forum_, !request.is_channel_,
                                         std::move(request.description_), DialogLocation(std::move(request.location_)),
                                         request.for_import_, MessageTtl(request.message_auto_delete_time_),
                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::createNewSecretChat &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->user_manager_->create_new_secret_chat(UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::createCall &request) {
  CHECK_IS_USER();

  if (request.protocol_ == nullptr) {
    return send_error_raw(id, 400, "Call protocol must be non-empty");
  }

  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<CallId> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_call_id_object());
    }
  });
  send_closure(G()->call_manager(), &CallManager::create_call, UserId(request.user_id_),
               CallProtocol(*request.protocol_), request.is_video_, GroupCallId(request.group_call_id_),
               std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::acceptCall &request) {
  CHECK_IS_USER();
  if (request.protocol_ == nullptr) {
    return send_error_raw(id, 400, "Call protocol must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::accept_call, CallId(request.call_id_),
               CallProtocol(*request.protocol_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendCallSignalingData &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::send_call_signaling_data, CallId(request.call_id_),
               std::move(request.data_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::discardCall &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::discard_call, CallId(request.call_id_), request.is_disconnected_,
               request.duration_, request.is_video_, request.connection_id_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendCallRating &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.comment_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::rate_call, CallId(request.call_id_), request.rating_,
               std::move(request.comment_), std::move(request.problems_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendCallDebugInformation &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.debug_information_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::send_call_debug_information, CallId(request.call_id_),
               std::move(request.debug_information_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendCallLog &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::send_call_log, CallId(request.call_id_), std::move(request.log_file_),
               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getVideoChatAvailableParticipants &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->group_call_manager_->get_group_call_join_as(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setVideoChatDefaultParticipant &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, default_join_as_dialog_id,
                     get_message_sender_dialog_id(td_, request.default_participant_id_, true, false));
  td_->group_call_manager_->set_group_call_default_join_as(DialogId(request.chat_id_), default_join_as_dialog_id,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createVideoChat &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.title_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<GroupCallId> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::groupCallId>(result.ok().get()));
    }
  });
  td_->group_call_manager_->create_voice_chat(DialogId(request.chat_id_), std::move(request.title_),
                                              request.start_date_, request.is_rtmp_stream_, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::createGroupCall &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->call_manager(), &CallManager::create_conference_call, CallId(request.call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getVideoChatRtmpUrl &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->group_call_manager_->get_voice_chat_rtmp_stream_url(DialogId(request.chat_id_), false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::replaceVideoChatRtmpUrl &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->group_call_manager_->get_voice_chat_rtmp_stream_url(DialogId(request.chat_id_), true, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGroupCall &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->group_call_manager_->get_group_call(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::startScheduledGroupCall &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->start_scheduled_group_call(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallEnabledStartNotification &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_start_subscribed(GroupCallId(request.group_call_id_),
                                                               request.enabled_start_notification_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::joinGroupCall &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_hash_);
  CLEAN_INPUT_STRING(request.payload_);
  CREATE_TEXT_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, join_as_dialog_id,
                     get_message_sender_dialog_id(td_, request.participant_id_, true, true));
  td_->group_call_manager_->join_group_call(GroupCallId(request.group_call_id_), join_as_dialog_id,
                                            request.audio_source_id_, std::move(request.payload_), request.is_muted_,
                                            request.is_my_video_enabled_, request.invite_hash_,
                                            request.key_fingerprint_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::startGroupCallScreenSharing &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.payload_);
  CREATE_TEXT_REQUEST_PROMISE();
  td_->group_call_manager_->start_group_call_screen_sharing(
      GroupCallId(request.group_call_id_), request.audio_source_id_, std::move(request.payload_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallScreenSharingIsPaused &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_is_my_presentation_paused(GroupCallId(request.group_call_id_),
                                                                        request.is_paused_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::endGroupCallScreenSharing &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->end_group_call_screen_sharing(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setGroupCallTitle &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.title_);
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->set_group_call_title(GroupCallId(request.group_call_id_), std::move(request.title_),
                                                 std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallMuteNewParticipants &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_mute_new_participants(GroupCallId(request.group_call_id_),
                                                                    request.mute_new_participants_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::revokeGroupCallInviteLink &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->revoke_group_call_invite_link(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::inviteGroupCallParticipants &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->invite_group_call_participants(GroupCallId(request.group_call_id_),
                                                           UserId::get_user_ids(request.user_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGroupCallInviteLink &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->group_call_manager_->get_group_call_invite_link(GroupCallId(request.group_call_id_), request.can_self_unmute_,
                                                       std::move(promise));
}

void Requests::on_request(uint64 id, td_api::startGroupCallRecording &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.title_);
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_recording(GroupCallId(request.group_call_id_), true,
                                                        std::move(request.title_), request.record_video_,
                                                        request.use_portrait_orientation_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::endGroupCallRecording &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_recording(GroupCallId(request.group_call_id_), false, string(), false,
                                                        false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallIsMyVideoPaused &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_is_my_video_paused(GroupCallId(request.group_call_id_),
                                                                 request.is_my_video_paused_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallIsMyVideoEnabled &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->toggle_group_call_is_my_video_enabled(GroupCallId(request.group_call_id_),
                                                                  request.is_my_video_enabled_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setGroupCallParticipantIsSpeaking &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->set_group_call_participant_is_speaking(
      GroupCallId(request.group_call_id_), request.audio_source_, request.is_speaking_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallParticipantIsMuted &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.participant_id_, true, false));
  td_->group_call_manager_->toggle_group_call_participant_is_muted(
      GroupCallId(request.group_call_id_), participant_dialog_id, request.is_muted_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setGroupCallParticipantVolumeLevel &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.participant_id_, true, false));
  td_->group_call_manager_->set_group_call_participant_volume_level(
      GroupCallId(request.group_call_id_), participant_dialog_id, request.volume_level_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGroupCallParticipantIsHandRaised &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.participant_id_, true, false));
  td_->group_call_manager_->toggle_group_call_participant_is_hand_raised(
      GroupCallId(request.group_call_id_), participant_dialog_id, request.is_hand_raised_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::loadGroupCallParticipants &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->load_group_call_participants(GroupCallId(request.group_call_id_), request.limit_,
                                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::leaveGroupCall &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->leave_group_call(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::endGroupCall &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->group_call_manager_->discard_group_call(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGroupCallStreams &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->group_call_manager_->get_group_call_streams(GroupCallId(request.group_call_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getGroupCallStreamSegment &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<string> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      auto file_part = td_api::make_object<td_api::filePart>();
      file_part->data_ = result.move_as_ok();
      promise.set_value(std::move(file_part));
    }
  });
  td_->group_call_manager_->get_group_call_stream_segment(GroupCallId(request.group_call_id_), request.time_offset_,
                                                          request.scale_, request.channel_id_,
                                                          std::move(request.video_quality_), std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::upgradeBasicGroupChatToSupergroupChat &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_manager_->migrate_dialog_to_megagroup(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatListsToAddChat &request) {
  CHECK_IS_USER();
  auto dialog_lists = td_->messages_manager_->get_dialog_lists_to_add_dialog(DialogId(request.chat_id_));
  auto chat_lists =
      transform(dialog_lists, [](DialogListId dialog_list_id) { return dialog_list_id.get_chat_list_object(); });
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::chatLists>(std::move(chat_lists)));
}

void Requests::on_request(uint64 id, const td_api::addChatToList &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->add_dialog_to_list(DialogId(request.chat_id_), DialogListId(request.chat_list_),
                                             std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatFolder &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_dialog_filter(DialogFilterId(request.chat_folder_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getRecommendedChatFolders &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_recommended_dialog_filters(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createChatFolder &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->create_dialog_filter(std::move(request.folder_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editChatFolder &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->edit_dialog_filter(DialogFilterId(request.chat_folder_id_), std::move(request.folder_),
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChatFolder &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->delete_dialog_filter(
      DialogFilterId(request.chat_folder_id_), DialogId::get_dialog_ids(request.leave_chat_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatFolderChatsToLeave &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_leave_dialog_filter_suggestions(DialogFilterId(request.chat_folder_id_),
                                                                   std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatFolderChatCount &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<int32> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::count>(result.move_as_ok()));
    }
  });
  td_->messages_manager_->get_dialog_filter_dialog_count(std::move(request.folder_), std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::reorderChatFolders &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->reorder_dialog_filters(
      transform(request.chat_folder_ids_, [](int32 id) { return DialogFilterId(id); }),
      request.main_chat_list_position_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleChatFolderTags &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->toggle_dialog_filter_tags(request.are_tags_enabled_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatsForChatFolderInviteLink &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_dialogs_for_dialog_filter_invite_link(DialogFilterId(request.chat_folder_id_),
                                                                         std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createChatFolderInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->create_dialog_filter_invite_link(
      DialogFilterId(request.chat_folder_id_), std::move(request.name_), DialogId::get_dialog_ids(request.chat_ids_),
      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatFolderInviteLinks &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_dialog_filter_invite_links(DialogFilterId(request.chat_folder_id_),
                                                              std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editChatFolderInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->edit_dialog_filter_invite_link(
      DialogFilterId(request.chat_folder_id_), std::move(request.invite_link_), std::move(request.name_),
      DialogId::get_dialog_ids(request.chat_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteChatFolderInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->delete_dialog_filter_invite_link(DialogFilterId(request.chat_folder_id_),
                                                                std::move(request.invite_link_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkChatFolderInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->check_dialog_filter_invite_link(std::move(request.invite_link_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addChatFolderByInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->add_dialog_filter_by_invite_link(
      std::move(request.invite_link_), DialogId::get_dialog_ids(request.chat_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatFolderNewChats &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_filter_manager_->get_dialog_filter_new_chats(DialogFilterId(request.chat_folder_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::processChatFolderNewChats &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_filter_manager_->add_dialog_filter_new_chats(
      DialogFilterId(request.chat_folder_id_), DialogId::get_dialog_ids(request.added_chat_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getArchiveChatListSettings &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<GlobalPrivacySettings> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(result.ok().get_archive_chat_list_settings_object());
        }
      });
  GlobalPrivacySettings::get_global_privacy_settings(td_, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::setArchiveChatListSettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  GlobalPrivacySettings::set_global_privacy_settings(td_, GlobalPrivacySettings(std::move(request.settings_)),
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getReadDatePrivacySettings &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<GlobalPrivacySettings> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(result.ok().get_read_date_privacy_settings_object());
        }
      });
  GlobalPrivacySettings::get_global_privacy_settings(td_, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::setReadDatePrivacySettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  GlobalPrivacySettings::set_global_privacy_settings(td_, GlobalPrivacySettings(std::move(request.settings_)),
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getNewChatPrivacySettings &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<GlobalPrivacySettings> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(result.ok().get_new_chat_privacy_settings_object());
        }
      });
  GlobalPrivacySettings::get_global_privacy_settings(td_, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::setNewChatPrivacySettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  GlobalPrivacySettings::set_global_privacy_settings(td_, GlobalPrivacySettings(std::move(request.settings_)),
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPaidMessageRevenue &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_paid_message_revenue(UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::allowUnpaidMessagesFromUser &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->privacy_manager_->allow_unpaid_messages(UserId(request.user_id_), request.refund_payments_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatPaidMessageStarCount &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_send_paid_messages_star_count(DialogId(request.chat_id_),
                                                                request.paid_message_star_count_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::canSendMessageToUser &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->user_manager_->can_send_message_to_user(UserId(request.user_id_), request.only_local_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatTitle &request) {
  CLEAN_INPUT_STRING(request.title_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_title(DialogId(request.chat_id_), request.title_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatPhoto &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_photo(DialogId(request.chat_id_), request.photo_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatAccentColor &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_accent_color(DialogId(request.chat_id_), AccentColorId(request.accent_color_id_),
                                                CustomEmojiId(request.background_custom_emoji_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatProfileAccentColor &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_profile_accent_color(
      DialogId(request.chat_id_), AccentColorId(request.profile_accent_color_id_),
      CustomEmojiId(request.profile_background_custom_emoji_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatMessageAutoDeleteTime &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_dialog_message_ttl(DialogId(request.chat_id_), request.message_auto_delete_time_,
                                                 std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatEmojiStatus &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_emoji_status(
      DialogId(request.chat_id_), EmojiStatus::get_emoji_status(request.emoji_status_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatPermissions &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_permissions(DialogId(request.chat_id_), request.permissions_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatBackground &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->background_manager_->set_dialog_background(DialogId(request.chat_id_), request.background_.get(),
                                                  request.type_.get(), request.dark_theme_dimming_,
                                                  !request.only_for_self_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteChatBackground &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->background_manager_->delete_dialog_background(DialogId(request.chat_id_), request.restore_previous_,
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatTheme &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.theme_name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_dialog_theme(DialogId(request.chat_id_), request.theme_name_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatDraftMessage &request) {
  CHECK_IS_USER();
  answer_ok_query(
      id, td_->messages_manager_->set_dialog_draft_message(
              DialogId(request.chat_id_), MessageId(request.message_thread_id_), std::move(request.draft_message_)));
}

void Requests::on_request(uint64 id, const td_api::toggleChatHasProtectedContent &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->toggle_dialog_has_protected_content(DialogId(request.chat_id_), request.has_protected_content_,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleChatIsPinned &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->toggle_dialog_is_pinned(DialogListId(request.chat_list_),
                                                                      DialogId(request.chat_id_), request.is_pinned_));
}

void Requests::on_request(uint64 id, const td_api::toggleChatViewAsTopics &request) {
  CHECK_IS_USER();
  answer_ok_query(
      id, td_->messages_manager_->toggle_dialog_view_as_messages(DialogId(request.chat_id_), !request.view_as_topics_));
}

void Requests::on_request(uint64 id, const td_api::toggleChatIsTranslatable &request) {
  CHECK_IS_USER();
  answer_ok_query(
      id, td_->messages_manager_->toggle_dialog_is_translatable(DialogId(request.chat_id_), request.is_translatable_));
}

void Requests::on_request(uint64 id, const td_api::toggleChatIsMarkedAsUnread &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->toggle_dialog_is_marked_as_unread(DialogId(request.chat_id_),
                                                                                request.is_marked_as_unread_));
}

void Requests::on_request(uint64 id, const td_api::setMessageSenderBlockList &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->set_message_sender_block_list(request.sender_id_, request.block_list_));
}

void Requests::on_request(uint64 id, const td_api::toggleChatDefaultDisableNotification &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->toggle_dialog_silent_send_message(DialogId(request.chat_id_),
                                                                                request.default_disable_notification_));
}

void Requests::on_request(uint64 id, const td_api::setPinnedChats &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->set_pinned_dialogs(DialogListId(request.chat_list_),
                                                                 DialogId::get_dialog_ids(request.chat_ids_)));
}

void Requests::on_request(uint64 id, const td_api::readChatList &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->read_all_dialogs_from_list(DialogListId(request.chat_list_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStoryNotificationSettingsExceptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->notification_settings_manager_->get_story_notification_settings_exceptions(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatActiveStories &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_dialog_expiring_stories(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatPostedToChatPageStories &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_dialog_pinned_stories(DialogId(request.chat_id_), StoryId(request.from_story_id_),
                                                 request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatArchivedStories &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_story_archive(DialogId(request.chat_id_), StoryId(request.from_story_id_), request.limit_,
                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatPinnedStories &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->set_pinned_stories(DialogId(request.chat_id_), StoryId::get_story_ids(request.story_ids_),
                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::openStory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->open_story(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::closeStory &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->close_story(DialogId(request.story_sender_chat_id_), StoryId(request.story_id_),
                                   std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStoryAvailableReactions &request) {
  CHECK_IS_USER();
  send_closure(td_actor_, &Td::send_result, id, td_->reaction_manager_->get_available_reactions(request.row_size_));
}

void Requests::on_request(uint64 id, const td_api::setStoryReaction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->set_story_reaction({DialogId(request.story_sender_chat_id_), StoryId(request.story_id_)},
                                          ReactionType(request.reaction_type_), request.update_recent_reactions_,
                                          std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getStoryInteractions &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_story_interactions(StoryId(request.story_id_), request.query_, request.only_contacts_,
                                              request.prefer_forwards_, request.prefer_with_reaction_, request.offset_,
                                              request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatStoryInteractions &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->get_dialog_story_interactions(
      {DialogId(request.story_sender_chat_id_), StoryId(request.story_id_)}, ReactionType(request.reaction_type_),
      request.prefer_forwards_, request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reportStory &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.text_);
  CREATE_REQUEST_PROMISE();
  td_->story_manager_->report_story({DialogId(request.story_sender_chat_id_), StoryId(request.story_id_)},
                                    request.option_id_, request.text_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::activateStoryStealthMode &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->story_manager_->activate_stealth_mode(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatBoostLevelFeatures &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  promise.set_value(td_->boost_manager_->get_chat_boost_level_features_object(!request.is_channel_, request.level_));
}

void Requests::on_request(uint64 id, const td_api::getChatBoostFeatures &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  promise.set_value(td_->boost_manager_->get_chat_boost_features_object(!request.is_channel_));
}

void Requests::on_request(uint64 id, const td_api::getAvailableChatBoostSlots &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->boost_manager_->get_boost_slots(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatBoostStatus &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->boost_manager_->get_dialog_boost_status(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::boostChat &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->boost_manager_->boost_dialog(DialogId(request.chat_id_), std::move(request.slot_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatBoostLink &request) {
  auto r_boost_link = td_->boost_manager_->get_dialog_boost_link(DialogId(request.chat_id_));
  if (r_boost_link.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_boost_link.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id,
                 td_api::make_object<td_api::chatBoostLink>(r_boost_link.ok().first, r_boost_link.ok().second));
  }
}

void Requests::on_request(uint64 id, td_api::getChatBoostLinkInfo &request) {
  CLEAN_INPUT_STRING(request.url_);
  CREATE_REQUEST(GetDialogBoostLinkInfoRequest, std::move(request.url_));
}

void Requests::on_request(uint64 id, td_api::getChatBoosts &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->boost_manager_->get_dialog_boosts(DialogId(request.chat_id_), request.only_gift_codes_, request.offset_,
                                         request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getUserChatBoosts &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->boost_manager_->get_user_dialog_boosts(DialogId(request.chat_id_), UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getAttachmentMenuBot &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->attach_menu_manager_->get_attach_menu_bot(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleBotIsAddedToAttachmentMenu &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->attach_menu_manager_->toggle_bot_is_added_to_attach_menu(UserId(request.bot_user_id_), request.is_added_,
                                                                request.allow_write_access_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatAvailableReactions &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_dialog_available_reactions(DialogId(request.chat_id_),
                                                         std::move(request.available_reactions_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatClientData &request) {
  answer_ok_query(
      id, td_->messages_manager_->set_dialog_client_data(DialogId(request.chat_id_), std::move(request.client_data_)));
}

void Requests::on_request(uint64 id, td_api::setChatDescription &request) {
  CLEAN_INPUT_STRING(request.description_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_description(DialogId(request.chat_id_), request.description_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatDiscussionGroup &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_discussion_group(DialogId(request.chat_id_), DialogId(request.discussion_chat_id_),
                                                   std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatLocation &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->set_dialog_location(DialogId(request.chat_id_), DialogLocation(std::move(request.location_)),
                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatSlowModeDelay &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_slow_mode_delay(DialogId(request.chat_id_), request.slow_mode_delay_,
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::pinChatMessage &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->pin_dialog_message(BusinessConnectionId(), DialogId(request.chat_id_),
                                             MessageId(request.message_id_), request.disable_notification_,
                                             request.only_for_self_, false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::unpinChatMessage &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->pin_dialog_message(BusinessConnectionId(), DialogId(request.chat_id_),
                                             MessageId(request.message_id_), false, false, true, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::unpinAllChatMessages &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->unpin_all_dialog_messages(DialogId(request.chat_id_), MessageId(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::unpinAllMessageThreadMessages &request) {
  if (request.message_thread_id_ == 0) {
    return send_error_raw(id, 400, "Invalid message thread identifier specified");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->unpin_all_dialog_messages(DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::joinChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_participant_manager_->add_dialog_participant(
      DialogId(request.chat_id_), td_->user_manager_->get_my_id(), 0,
      DialogParticipantManager::wrap_failed_to_add_members_promise(std::move(promise)));
}

void Requests::on_request(uint64 id, const td_api::leaveChat &request) {
  CREATE_OK_REQUEST_PROMISE();
  DialogId dialog_id(request.chat_id_);
  td_api::object_ptr<td_api::ChatMemberStatus> new_status = td_api::make_object<td_api::chatMemberStatusLeft>();
  if (dialog_id.get_type() == DialogType::Channel && td_->dialog_manager_->have_dialog_force(dialog_id, "leaveChat")) {
    auto status = td_->chat_manager_->get_channel_status(dialog_id.get_channel_id());
    if (status.is_creator()) {
      if (!status.is_member()) {
        return promise.set_value(Unit());
      }

      new_status =
          td_api::make_object<td_api::chatMemberStatusCreator>(status.get_rank(), status.is_anonymous(), false);
    }
  }
  td_->dialog_participant_manager_->set_dialog_participant_status(dialog_id, td_->dialog_manager_->get_my_dialog_id(),
                                                                  std::move(new_status), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::addChatMember &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_participant_manager_->add_dialog_participant(DialogId(request.chat_id_), UserId(request.user_id_),
                                                           request.forward_limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::addChatMembers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_participant_manager_->add_dialog_participants(
      DialogId(request.chat_id_), UserId::get_user_ids(request.user_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatMemberStatus &request) {
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.member_id_, false, false));
  td_->dialog_participant_manager_->set_dialog_participant_status(DialogId(request.chat_id_), participant_dialog_id,
                                                                  std::move(request.status_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::banChatMember &request) {
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.member_id_, false, false));
  td_->dialog_participant_manager_->ban_dialog_participant(DialogId(request.chat_id_), participant_dialog_id,
                                                           request.banned_until_date_, request.revoke_messages_,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::canTransferOwnership &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda(
      [promise = std::move(promise)](Result<DialogParticipantManager::CanTransferOwnershipResult> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(DialogParticipantManager::get_can_transfer_ownership_result_object(result.ok()));
        }
      });
  td_->dialog_participant_manager_->can_transfer_ownership(std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::transferChatOwnership &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_participant_manager_->transfer_dialog_ownership(DialogId(request.chat_id_), UserId(request.user_id_),
                                                              request.password_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatMember &request) {
  CREATE_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, participant_dialog_id,
                     get_message_sender_dialog_id(td_, request.member_id_, false, false));
  td_->dialog_participant_manager_->get_dialog_participant(DialogId(request.chat_id_), participant_dialog_id,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchChatMembers &request) {
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise), td = td_](Result<DialogParticipants> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(result.ok().get_chat_members_object(td, "searchChatMembers"));
        }
      });
  td_->dialog_participant_manager_->search_dialog_participants(DialogId(request.chat_id_), request.query_,
                                                               request.limit_, DialogParticipantFilter(request.filter_),
                                                               std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getChatAdministrators &request) {
  CREATE_REQUEST_PROMISE();
  td_->dialog_participant_manager_->get_dialog_administrators(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::replacePrimaryChatInviteLink &request) {
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->export_dialog_invite_link(
      DialogId(request.chat_id_), string(), 0, 0, false, StarSubscriptionPricing(), false, true, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createChatInviteLink &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->export_dialog_invite_link(
      DialogId(request.chat_id_), std::move(request.name_), request.expiration_date_, request.member_limit_,
      request.creates_join_request_, StarSubscriptionPricing(), false, false, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createChatSubscriptionInviteLink &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->export_dialog_invite_link(
      DialogId(request.chat_id_), std::move(request.name_), 0, 0, false,
      StarSubscriptionPricing(std::move(request.subscription_pricing_)), true, false, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editChatInviteLink &request) {
  CLEAN_INPUT_STRING(request.name_);
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->edit_dialog_invite_link(
      DialogId(request.chat_id_), request.invite_link_, std::move(request.name_), request.expiration_date_,
      request.member_limit_, request.creates_join_request_, false, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editChatSubscriptionInviteLink &request) {
  CLEAN_INPUT_STRING(request.name_);
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->edit_dialog_invite_link(DialogId(request.chat_id_), request.invite_link_,
                                                            std::move(request.name_), 0, 0, false, true,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->get_dialog_invite_link(DialogId(request.chat_id_), request.invite_link_,
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatInviteLinkCounts &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->get_dialog_invite_link_counts(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatInviteLinks &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->get_dialog_invite_links(
      DialogId(request.chat_id_), UserId(request.creator_user_id_), request.is_revoked_, request.offset_date_,
      request.offset_invite_link_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatInviteLinkMembers &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->get_dialog_invite_link_users(
      DialogId(request.chat_id_), request.invite_link_, request.only_with_expired_subscription_,
      std::move(request.offset_member_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getChatJoinRequests &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_participant_manager_->get_dialog_join_requests(DialogId(request.chat_id_), request.invite_link_,
                                                             request.query_, std::move(request.offset_request_),
                                                             request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::processChatJoinRequest &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_participant_manager_->process_dialog_join_request(DialogId(request.chat_id_), UserId(request.user_id_),
                                                                request.approve_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::processChatJoinRequests &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_participant_manager_->process_dialog_join_requests(DialogId(request.chat_id_), request.invite_link_,
                                                                 request.approve_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::revokeChatInviteLink &request) {
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->revoke_dialog_invite_link(DialogId(request.chat_id_), request.invite_link_,
                                                              std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteRevokedChatInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->delete_revoked_dialog_invite_link(DialogId(request.chat_id_), request.invite_link_,
                                                                      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteAllRevokedChatInviteLinks &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_invite_link_manager_->delete_all_revoked_dialog_invite_links(
      DialogId(request.chat_id_), UserId(request.creator_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkChatInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST(CheckChatInviteLinkRequest, request.invite_link_);
}

void Requests::on_request(uint64 id, td_api::joinChatByInviteLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.invite_link_);
  CREATE_REQUEST(JoinChatByInviteLinkRequest, request.invite_link_);
}

void Requests::on_request(uint64 id, td_api::getChatEventLog &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST_PROMISE();
  get_dialog_event_log(td_, DialogId(request.chat_id_), std::move(request.query_), request.from_event_id_,
                       request.limit_, std::move(request.filters_), UserId::get_user_ids(request.user_ids_),
                       std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getTimeZones &request) {
  CREATE_REQUEST_PROMISE();
  td_->time_zone_manager_->get_time_zones(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clearAllDraftMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->clear_all_draft_messages(request.exclude_secret_chats_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::downloadFile &request) {
  CREATE_REQUEST_PROMISE();
  td_->file_manager_->download_file(FileId(request.file_id_, 0), request.priority_, request.offset_, request.limit_,
                                    request.synchronous_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getFileDownloadedPrefixSize &request) {
  if (request.offset_ < 0) {
    return send_error_raw(id, 400, "Parameter offset must be non-negative");
  }
  auto file_view = td_->file_manager_->get_file_view(FileId(request.file_id_, 0));
  if (file_view.empty()) {
    return send_closure(td_actor_, &Td::send_error, id, Status::Error(400, "Unknown file ID"));
  }
  send_closure(td_actor_, &Td::send_result, id,
               td_api::make_object<td_api::fileDownloadedPrefixSize>(file_view.downloaded_prefix(request.offset_)));
}

void Requests::on_request(uint64 id, const td_api::cancelDownloadFile &request) {
  td_->file_manager_->cancel_download(FileId(request.file_id_, 0), 0, request.only_if_pending_);
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::getSuggestedFileName &request) {
  Result<string> r_file_name =
      td_->file_manager_->get_suggested_file_name(FileId(request.file_id_, 0), request.directory_);
  if (r_file_name.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_file_name.move_as_error());
  }
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::text>(r_file_name.ok()));
}

void Requests::on_request(uint64 id, const td_api::preliminaryUploadFile &request) {
  CREATE_REQUEST_PROMISE();
  auto file_type = request.file_type_ == nullptr ? FileType::Temp : get_file_type(*request.file_type_);
  td_->file_manager_->preliminary_upload_file(request.file_, file_type, request.priority_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::cancelPreliminaryUploadFile &request) {
  td_->file_manager_->cancel_upload({FileId(request.file_id_, 0), 0});

  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, td_api::writeGeneratedFilePart &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->file_manager_actor_, &FileManager::external_file_generate_write_part, request.generation_id_,
               request.offset_, std::move(request.data_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setFileGenerationProgress &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->file_manager_actor_, &FileManager::external_file_generate_progress, request.generation_id_,
               request.expected_size_, request.local_prefix_size_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::finishFileGeneration &request) {
  Status status;
  if (request.error_ != nullptr) {
    CLEAN_INPUT_STRING(request.error_->message_);
    status = Status::Error(request.error_->code_, request.error_->message_);
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->file_manager_actor_, &FileManager::external_file_generate_finish, request.generation_id_,
               std::move(status), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::readFilePart &request) {
  CREATE_REQUEST_PROMISE();
  send_closure(td_->file_manager_actor_, &FileManager::read_file_part, FileId(request.file_id_, 0), request.offset_,
               request.count_, 2, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteFile &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->file_manager_actor_, &FileManager::delete_file, FileId(request.file_id_, 0), std::move(promise),
               "td_api::deleteFile");
}

void Requests::on_request(uint64 id, const td_api::addFileToDownloads &request) {
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->add_message_file_to_downloads(
      MessageFullId(DialogId(request.chat_id_), MessageId(request.message_id_)), FileId(request.file_id_, 0),
      request.priority_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleDownloadIsPaused &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->download_manager_actor_, &DownloadManager::toggle_is_paused, FileId(request.file_id_, 0),
               request.is_paused_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleAllDownloadsArePaused &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->download_manager_actor_, &DownloadManager::toggle_all_is_paused, request.are_paused_,
               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeFileFromDownloads &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->download_manager_actor_, &DownloadManager::remove_file, FileId(request.file_id_, 0), FileSourceId(),
               request.delete_from_cache_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeAllFilesFromDownloads &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->download_manager_actor_, &DownloadManager::remove_all_files, request.only_active_,
               request.only_completed_, request.delete_from_cache_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchFileDownloads &request) {
  CLEAN_INPUT_STRING(request.query_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->download_manager_actor_, &DownloadManager::search, std::move(request.query_), request.only_active_,
               request.only_completed_, std::move(request.offset_), request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setApplicationVerificationToken &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.token_);
  CREATE_OK_REQUEST_PROMISE();
  G()->net_query_dispatcher().set_verification_token(request.verification_id_, std::move(request.token_),
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getMessageFileType &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.message_file_head_);
  CREATE_REQUEST_PROMISE();
  td_->message_import_manager_->get_message_file_type(request.message_file_head_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageImportConfirmationText &request) {
  CHECK_IS_USER();
  CREATE_TEXT_REQUEST_PROMISE();
  td_->message_import_manager_->get_message_import_confirmation_text(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::importMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->message_import_manager_->import_messages(DialogId(request.chat_id_), request.message_file_,
                                                request.attached_files_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::blockMessageSenderFromReplies &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->block_message_sender_from_replies(MessageId(request.message_id_), request.delete_message_,
                                                            request.delete_all_messages_, request.report_spam_,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBlockedMessageSenders &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->dialog_manager_->get_blocked_dialogs(request.block_list_, request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addContact &request) {
  CHECK_IS_USER();
  auto r_contact = get_contact(td_, std::move(request.contact_));
  if (r_contact.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_contact.move_as_error());
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->add_contact(r_contact.move_as_ok(), request.share_phone_number_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::importContacts &request) {
  CHECK_IS_USER();
  vector<Contact> contacts;
  contacts.reserve(request.contacts_.size());
  for (auto &contact : request.contacts_) {
    auto r_contact = get_contact(td_, std::move(contact));
    if (r_contact.is_error()) {
      return send_closure(td_actor_, &Td::send_error, id, r_contact.move_as_error());
    }
    contacts.push_back(r_contact.move_as_ok());
  }
  CREATE_REQUEST(ImportContactsRequest, std::move(contacts));
}

void Requests::on_request(uint64 id, const td_api::getContacts &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(SearchContactsRequest, string(), 1000000);
}

void Requests::on_request(uint64 id, td_api::searchContacts &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchContactsRequest, request.query_, request.limit_);
}

void Requests::on_request(uint64 id, const td_api::removeContacts &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(RemoveContactsRequest, UserId::get_user_ids(request.user_ids_));
}

void Requests::on_request(uint64 id, const td_api::getImportedContactCount &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetImportedContactCountRequest);
}

void Requests::on_request(uint64 id, td_api::changeImportedContacts &request) {
  CHECK_IS_USER();
  vector<Contact> contacts;
  contacts.reserve(request.contacts_.size());
  for (auto &contact : request.contacts_) {
    auto r_contact = get_contact(td_, std::move(contact));
    if (r_contact.is_error()) {
      return send_closure(td_actor_, &Td::send_error, id, r_contact.move_as_error());
    }
    contacts.push_back(r_contact.move_as_ok());
  }
  CREATE_REQUEST(ChangeImportedContactsRequest, std::move(contacts));
}

void Requests::on_request(uint64 id, const td_api::clearImportedContacts &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->clear_imported_contacts(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCloseFriends &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetCloseFriendsRequest);
}

void Requests::on_request(uint64 id, const td_api::setCloseFriends &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_close_friends(UserId::get_user_ids(request.user_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setUserPersonalProfilePhoto &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_user_profile_photo(UserId(request.user_id_), request.photo_, false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::suggestUserProfilePhoto &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_user_profile_photo(UserId(request.user_id_), request.photo_, true, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleBotCanManageEmojiStatus &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->toggle_user_can_manage_emoji_status(UserId(request.bot_user_id_),
                                                          request.can_manage_emoji_status_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setUserEmojiStatus &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_user_emoji_status(UserId(request.user_id_),
                                            EmojiStatus::get_emoji_status(request.emoji_status_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchUserByPhoneNumber &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.phone_number_);
  CREATE_REQUEST(SearchUserByPhoneNumberRequest, std::move(request.phone_number_), request.only_local_);
}

void Requests::on_request(uint64 id, const td_api::sharePhoneNumber &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->share_phone_number(UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getRecentInlineBots &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetRecentInlineBotsRequest);
}

void Requests::on_request(uint64 id, const td_api::getOwnedBots &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_info_manager_->get_owned_bots(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setName &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.first_name_);
  CLEAN_INPUT_STRING(request.last_name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_name(request.first_name_, request.last_name_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBio &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.bio_);
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_bio(request.bio_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setUsername &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_username(request.username_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::toggleUsernameIsActive &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->toggle_username_is_active(std::move(request.username_), request.is_active_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reorderActiveUsernames &request) {
  CHECK_IS_USER();
  for (auto &username : request.usernames_) {
    CLEAN_INPUT_STRING(username);
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->reorder_usernames(std::move(request.usernames_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBirthdate &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_birthdate(Birthdate(std::move(request.birthdate_)), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setPersonalChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_personal_channel(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setEmojiStatus &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_emoji_status(EmojiStatus::get_emoji_status(request.emoji_status_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleHasSponsoredMessagesEnabled &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->toggle_sponsored_messages(request.has_sponsored_messages_enabled_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getThemedEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_emoji_statuses(false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getThemedChatEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_channel_emoji_statuses(false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_default_emoji_statuses(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultChatEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_default_channel_emoji_statuses(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getRecentEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_recent_emoji_statuses(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getUpgradedGiftEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_upgraded_gift_emoji_statuses(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clearRecentEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  clear_recent_emoji_statuses(td_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setCommands &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  set_commands(td_, std::move(request.scope_), std::move(request.language_code_), std::move(request.commands_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteCommands &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  delete_commands(td_, std::move(request.scope_), std::move(request.language_code_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getCommands &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  get_commands(td_, std::move(request.scope_), std::move(request.language_code_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setMenuButton &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  set_menu_button(td_, UserId(request.user_id_), std::move(request.menu_button_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMenuButton &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  get_menu_button(td_, UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setDefaultGroupAdministratorRights &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->set_default_group_administrator_rights(
      AdministratorRights(request.default_group_administrator_rights_, ChannelType::Megagroup), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setDefaultChannelAdministratorRights &request) {
  CHECK_IS_BOT();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->set_default_channel_administrator_rights(
      AdministratorRights(request.default_channel_administrator_rights_, ChannelType::Broadcast), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::canBotSendMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->can_bot_send_messages(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::allowBotToSendMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->allow_bot_to_send_messages(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendWebAppCustomRequest &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.method_);
  CLEAN_INPUT_STRING(request.parameters_);
  CREATE_REQUEST_PROMISE();
  td_->web_app_manager_->invoke_web_view_custom_method(UserId(request.bot_user_id_), request.method_,
                                                       request.parameters_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotMediaPreviews &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_info_manager_->get_bot_media_previews(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotMediaPreviewInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_info_manager_->get_bot_media_preview_info(UserId(request.bot_user_id_), request.language_code_,
                                                     std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addBotMediaPreview &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_info_manager_->add_bot_media_preview(UserId(request.bot_user_id_), request.language_code_,
                                                std::move(request.content_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBotMediaPreview &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->bot_info_manager_->edit_bot_media_preview(UserId(request.bot_user_id_), request.language_code_,
                                                 FileId(request.file_id_, 0), std::move(request.content_),
                                                 std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reorderBotMediaPreviews &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->reorder_bot_media_previews(UserId(request.bot_user_id_), request.language_code_,
                                                     request.file_ids_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteBotMediaPreviews &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->delete_bot_media_previews(UserId(request.bot_user_id_), request.language_code_,
                                                    request.file_ids_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBotName &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->set_bot_name(UserId(request.bot_user_id_), request.language_code_, request.name_,
                                       std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotName &request) {
  CREATE_TEXT_REQUEST_PROMISE();
  td_->bot_info_manager_->get_bot_name(UserId(request.bot_user_id_), request.language_code_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setBotProfilePhoto &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_bot_profile_photo(UserId(request.bot_user_id_), request.photo_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::toggleBotUsernameIsActive &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->toggle_bot_username_is_active(UserId(request.bot_user_id_), std::move(request.username_),
                                                    request.is_active_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reorderBotActiveUsernames &request) {
  CHECK_IS_USER();
  for (auto &username : request.usernames_) {
    CLEAN_INPUT_STRING(username);
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->reorder_bot_usernames(UserId(request.bot_user_id_), std::move(request.usernames_),
                                            std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBotInfoDescription &request) {
  CLEAN_INPUT_STRING(request.description_);
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->set_bot_info_description(UserId(request.bot_user_id_), request.language_code_,
                                                   request.description_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotInfoDescription &request) {
  CREATE_TEXT_REQUEST_PROMISE();
  td_->bot_info_manager_->get_bot_info_description(UserId(request.bot_user_id_), request.language_code_,
                                                   std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBotInfoShortDescription &request) {
  CLEAN_INPUT_STRING(request.short_description_);
  CREATE_OK_REQUEST_PROMISE();
  td_->bot_info_manager_->set_bot_info_about(UserId(request.bot_user_id_), request.language_code_,
                                             request.short_description_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBotInfoShortDescription &request) {
  CREATE_TEXT_REQUEST_PROMISE();
  td_->bot_info_manager_->get_bot_info_about(UserId(request.bot_user_id_), request.language_code_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setMessageSenderBotVerification &request) {
  CLEAN_INPUT_STRING(request.custom_description_);
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, request.verified_id_, true, false));
  td_->bot_info_manager_->set_custom_bot_verification(UserId(request.bot_user_id_), dialog_id, true,
                                                      request.custom_description_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeMessageSenderBotVerification &request) {
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, request.verified_id_, true, false));
  td_->bot_info_manager_->set_custom_bot_verification(UserId(request.bot_user_id_), dialog_id, false, string(),
                                                      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessLocation &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_location(DialogLocation(std::move(request.location_)), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessOpeningHours &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_work_hours(BusinessWorkHours(std::move(request.opening_hours_)),
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessGreetingMessageSettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_greeting_message(
      BusinessGreetingMessage(std::move(request.greeting_message_settings_)), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessAwayMessageSettings &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_away_message(BusinessAwayMessage(std::move(request.away_message_settings_)),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessStartPage &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_intro(BusinessIntro(td_, std::move(request.start_page_)), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setProfilePhoto &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_profile_photo(request.photo_, request.is_public_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteProfilePhoto &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->delete_profile_photo(request.profile_photo_id_, false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getUserProfilePhotos &request) {
  CREATE_REQUEST_PROMISE();
  td_->user_manager_->get_user_profile_photos(UserId(request.user_id_), request.offset_, request.limit_,
                                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setAccentColor &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_accent_color(AccentColorId(request.accent_color_id_),
                                       CustomEmojiId(request.background_custom_emoji_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setProfileAccentColor &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->user_manager_->set_profile_accent_color(AccentColorId(request.profile_accent_color_id_),
                                               CustomEmojiId(request.profile_background_custom_emoji_id_),
                                               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBusinessConnectedBot &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->business_manager_->get_business_connected_bot(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBusinessConnectedBot &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->set_business_connected_bot(std::move(request.bot_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteBusinessConnectedBot &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->delete_business_connected_bot(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleBusinessConnectedBotChatIsPaused &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->toggle_business_connected_bot_dialog_is_paused(DialogId(request.chat_id_), request.is_paused_,
                                                                         std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeBusinessConnectedBotFromChat &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->remove_business_connected_bot_from_dialog(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBusinessChatLinks &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->business_manager_->get_business_chat_links(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createBusinessChatLink &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->business_manager_->create_business_chat_link(std::move(request.link_info_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editBusinessChatLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.link_);
  CREATE_REQUEST_PROMISE();
  td_->business_manager_->edit_business_chat_link(request.link_, std::move(request.link_info_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteBusinessChatLink &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.link_);
  CREATE_OK_REQUEST_PROMISE();
  td_->business_manager_->delete_business_chat_link(request.link_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getBusinessChatLinkInfo &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.link_name_);
  CREATE_REQUEST_PROMISE();
  td_->business_manager_->get_business_chat_link_info(request.link_name_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setSupergroupUsername &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_username(ChannelId(request.supergroup_id_), request.username_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::toggleSupergroupUsernameIsActive &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_username_is_active(ChannelId(request.supergroup_id_), std::move(request.username_),
                                                        request.is_active_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::disableAllSupergroupUsernames &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->disable_all_channel_usernames(ChannelId(request.supergroup_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reorderSupergroupActiveUsernames &request) {
  CHECK_IS_USER();
  for (auto &username : request.usernames_) {
    CLEAN_INPUT_STRING(username);
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->reorder_channel_usernames(ChannelId(request.supergroup_id_), std::move(request.usernames_),
                                                std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setSupergroupStickerSet &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_sticker_set(ChannelId(request.supergroup_id_), StickerSetId(request.sticker_set_id_),
                                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setSupergroupCustomEmojiStickerSet &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_emoji_sticker_set(
      ChannelId(request.supergroup_id_), StickerSetId(request.custom_emoji_sticker_set_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setSupergroupUnrestrictBoostCount &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->set_channel_unrestrict_boost_count(ChannelId(request.supergroup_id_),
                                                         request.unrestrict_boost_count_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupSignMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_sign_messages(ChannelId(request.supergroup_id_), request.sign_messages_,
                                                   request.show_message_sender_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupJoinToSendMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_join_to_send(ChannelId(request.supergroup_id_), request.join_to_send_messages_,
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupJoinByRequest &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_join_request(ChannelId(request.supergroup_id_), request.join_by_request_,
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupIsAllHistoryAvailable &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_is_all_history_available(ChannelId(request.supergroup_id_),
                                                              request.is_all_history_available_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupCanHaveSponsoredMessages &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_can_have_sponsored_messages(
      ChannelId(request.supergroup_id_), request.can_have_sponsored_messages_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupHasHiddenMembers &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_has_hidden_participants(ChannelId(request.supergroup_id_),
                                                             request.has_hidden_members_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupHasAggressiveAntiSpamEnabled &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_has_aggressive_anti_spam_enabled(
      ChannelId(request.supergroup_id_), request.has_aggressive_anti_spam_enabled_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupIsForum &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->toggle_channel_is_forum(ChannelId(request.supergroup_id_), request.is_forum_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleSupergroupIsBroadcastGroup &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->convert_channel_to_gigagroup(ChannelId(request.supergroup_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reportSupergroupSpam &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->report_channel_spam(ChannelId(request.supergroup_id_),
                                          MessageId::get_message_ids(request.message_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reportSupergroupAntiSpamFalsePositive &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->chat_manager_->report_channel_anti_spam_false_positive(ChannelId(request.supergroup_id_),
                                                              MessageId(request.message_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getSupergroupMembers &request) {
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise), td = td_](Result<DialogParticipants> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(result.ok().get_chat_members_object(td, "getSupergroupMembers"));
        }
      });
  td_->dialog_participant_manager_->get_channel_participants(ChannelId(request.supergroup_id_),
                                                             std::move(request.filter_), string(), request.offset_,
                                                             request.limit_, -1, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::closeSecretChat &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->secret_chats_manager_, &SecretChatsManager::cancel_chat, SecretChatId(request.secret_chat_id_),
               false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStickerOutline &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  promise.set_value(td_->stickers_manager_->get_sticker_outline_object(
      FileId(request.sticker_file_id_, 0), request.for_animated_emoji_, request.for_clicked_animated_emoji_message_));
}

void Requests::on_request(uint64 id, td_api::getStickers &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(GetStickersRequest, get_sticker_type(request.sticker_type_), std::move(request.query_), request.limit_,
                 request.chat_id_);
}

void Requests::on_request(uint64 id, td_api::getAllStickerEmojis &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(GetAllStickerEmojisRequest, get_sticker_type(request.sticker_type_), std::move(request.query_),
                 request.chat_id_, request.return_only_main_emoji_);
}

void Requests::on_request(uint64 id, td_api::searchStickers &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.emojis_);
  CLEAN_INPUT_STRING(request.query_);
  for (auto &input_language_code : request.input_language_codes_) {
    CLEAN_INPUT_STRING(input_language_code);
  }
  CREATE_REQUEST_PROMISE();
  auto sticker_type = get_sticker_type(request.sticker_type_);
  if (sticker_type == StickerType::Regular && request.query_.empty()) {
    // legacy
    if (request.emojis_ == "⭐️⭐️") {
      request.emojis_ = "⭐️";
    } else if (request.emojis_ == "📂⭐️") {
      request.emojis_ = "📂";
    } else if (request.emojis_ == "👋⭐️") {
      request.emojis_ = "👋";
    }
  }
  td_->stickers_manager_->search_stickers(sticker_type, std::move(request.emojis_), request.query_,
                                          request.input_language_codes_, request.offset_, request.limit_,
                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGreetingStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->search_stickers(StickerType::Regular, "👋⭐️", string(), vector<string>(), 0, 100,
                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_premium_stickers(request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getInstalledStickerSets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetInstalledStickerSetsRequest, get_sticker_type(request.sticker_type_));
}

void Requests::on_request(uint64 id, const td_api::getArchivedStickerSets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetArchivedStickerSetsRequest, get_sticker_type(request.sticker_type_), request.offset_sticker_set_id_,
                 request.limit_);
}

void Requests::on_request(uint64 id, const td_api::getTrendingStickerSets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetTrendingStickerSetsRequest, get_sticker_type(request.sticker_type_), request.offset_,
                 request.limit_);
}

void Requests::on_request(uint64 id, const td_api::getAttachedStickerSets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetAttachedStickerSetsRequest, request.file_id_);
}

void Requests::on_request(uint64 id, const td_api::getStickerSet &request) {
  CREATE_REQUEST(GetStickerSetRequest, request.set_id_);
}

void Requests::on_request(uint64 id, const td_api::getStickerSetName &request) {
  CREATE_TEXT_REQUEST_PROMISE();
  td_->stickers_manager_->get_sticker_set_name(StickerSetId(request.set_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchStickerSet &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST(SearchStickerSetRequest, std::move(request.name_), request.ignore_cache_);
}

void Requests::on_request(uint64 id, td_api::searchInstalledStickerSets &request) {
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchInstalledStickerSetsRequest, get_sticker_type(request.sticker_type_), std::move(request.query_),
                 request.limit_);
}

void Requests::on_request(uint64 id, td_api::searchStickerSets &request) {
  CLEAN_INPUT_STRING(request.query_);
  CREATE_REQUEST(SearchStickerSetsRequest, get_sticker_type(request.sticker_type_), std::move(request.query_));
}

void Requests::on_request(uint64 id, const td_api::changeStickerSet &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(ChangeStickerSetRequest, request.set_id_, request.is_installed_, request.is_archived_);
}

void Requests::on_request(uint64 id, const td_api::viewTrendingStickerSets &request) {
  CHECK_IS_USER();
  td_->stickers_manager_->view_featured_sticker_sets(
      StickersManager::convert_sticker_set_ids(request.sticker_set_ids_));
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::reorderInstalledStickerSets &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->reorder_installed_sticker_sets(
      get_sticker_type(request.sticker_type_), StickersManager::convert_sticker_set_ids(request.sticker_set_ids_),
      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::uploadStickerFile &request) {
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->upload_sticker_file(UserId(request.user_id_), get_sticker_format(request.sticker_format_),
                                              std::move(request.sticker_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getSuggestedStickerSetName &request) {
  CLEAN_INPUT_STRING(request.title_);
  CREATE_TEXT_REQUEST_PROMISE();
  td_->stickers_manager_->get_suggested_sticker_set_name(std::move(request.title_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkStickerSetName &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda(
      [promise = std::move(promise)](Result<StickersManager::CheckStickerSetNameResult> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(StickersManager::get_check_sticker_set_name_result_object(result.ok()));
        }
      });
  td_->stickers_manager_->check_sticker_set_name(request.name_, std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::createNewStickerSet &request) {
  CLEAN_INPUT_STRING(request.title_);
  CLEAN_INPUT_STRING(request.name_);
  CLEAN_INPUT_STRING(request.source_);
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->create_new_sticker_set(UserId(request.user_id_), std::move(request.title_),
                                                 std::move(request.name_), get_sticker_type(request.sticker_type_),
                                                 request.needs_repainting_, std::move(request.stickers_),
                                                 std::move(request.source_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addStickerToSet &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->add_sticker_to_set(UserId(request.user_id_), std::move(request.name_),
                                             std::move(request.sticker_), nullptr, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::replaceStickerInSet &request) {
  CLEAN_INPUT_STRING(request.name_);
  if (request.old_sticker_ == nullptr) {
    return send_error_raw(id, 400, "Old sticker must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->add_sticker_to_set(UserId(request.user_id_), std::move(request.name_),
                                             std::move(request.new_sticker_), std::move(request.old_sticker_),
                                             std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStickerSetThumbnail &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_set_thumbnail(UserId(request.user_id_), std::move(request.name_),
                                                    std::move(request.thumbnail_), get_sticker_format(request.format_),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setCustomEmojiStickerSetThumbnail &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_custom_emoji_sticker_set_thumbnail(
      std::move(request.name_), CustomEmojiId(request.custom_emoji_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStickerSetTitle &request) {
  CLEAN_INPUT_STRING(request.name_);
  CLEAN_INPUT_STRING(request.title_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_set_title(std::move(request.name_), std::move(request.title_),
                                                std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteStickerSet &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->delete_sticker_set(std::move(request.name_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setStickerPositionInSet &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_position_in_set(request.sticker_, request.position_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeStickerFromSet &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->remove_sticker_from_set(request.sticker_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStickerEmojis &request) {
  CLEAN_INPUT_STRING(request.emojis_);
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_emojis(request.sticker_, request.emojis_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStickerKeywords &request) {
  for (auto &keyword : request.keywords_) {
    CLEAN_INPUT_STRING(keyword);
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_keywords(request.sticker_, std::move(request.keywords_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setStickerMaskPosition &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->stickers_manager_->set_sticker_mask_position(request.sticker_, std::move(request.mask_position_),
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getOwnedStickerSets &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_created_sticker_sets(StickerSetId(request.offset_sticker_set_id_), request.limit_,
                                                   std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getRecentStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetRecentStickersRequest, request.is_attached_);
}

void Requests::on_request(uint64 id, td_api::addRecentSticker &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(AddRecentStickerRequest, request.is_attached_, std::move(request.sticker_));
}

void Requests::on_request(uint64 id, td_api::removeRecentSticker &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(RemoveRecentStickerRequest, request.is_attached_, std::move(request.sticker_));
}

void Requests::on_request(uint64 id, const td_api::clearRecentStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(ClearRecentStickersRequest, request.is_attached_);
}

void Requests::on_request(uint64 id, const td_api::getFavoriteStickers &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetFavoriteStickersRequest);
}

void Requests::on_request(uint64 id, td_api::addFavoriteSticker &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(AddFavoriteStickerRequest, std::move(request.sticker_));
}

void Requests::on_request(uint64 id, td_api::removeFavoriteSticker &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(RemoveFavoriteStickerRequest, std::move(request.sticker_));
}

void Requests::on_request(uint64 id, td_api::getStickerEmojis &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetStickerEmojisRequest, std::move(request.sticker_));
}

void Requests::on_request(uint64 id, td_api::searchEmojis &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.text_);
  for (auto &input_language_code : request.input_language_codes_) {
    CLEAN_INPUT_STRING(input_language_code);
  }
  CREATE_REQUEST(SearchEmojisRequest, std::move(request.text_), std::move(request.input_language_codes_));
}

void Requests::on_request(uint64 id, td_api::getKeywordEmojis &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.text_);
  for (auto &input_language_code : request.input_language_codes_) {
    CLEAN_INPUT_STRING(input_language_code);
  }
  CREATE_REQUEST(GetKeywordEmojisRequest, std::move(request.text_), std::move(request.input_language_codes_));
}

void Requests::on_request(uint64 id, const td_api::getEmojiCategories &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_emoji_groups(get_emoji_group_type(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getAnimatedEmoji &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.emoji_);
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_animated_emoji(std::move(request.emoji_), false, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getEmojiSuggestionsUrl &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_code_);
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->stickers_manager_->get_emoji_suggestions_url(request.language_code_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCustomEmojiStickers &request) {
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_custom_emoji_stickers(CustomEmojiId::get_custom_emoji_ids(request.custom_emoji_ids_),
                                                    true, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultChatPhotoCustomEmojiStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::DialogPhoto, false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultProfilePhotoCustomEmojiStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::UserProfilePhoto, false,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDefaultBackgroundCustomEmojiStickers &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::Background, false, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getDisallowedChatEmojiStatuses &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->get_sticker_list_emoji_statuses(StickerListType::DisallowedChannelEmojiStatus, false,
                                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSavedAnimations &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetSavedAnimationsRequest);
}

void Requests::on_request(uint64 id, td_api::addSavedAnimation &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(AddSavedAnimationRequest, std::move(request.animation_));
}

void Requests::on_request(uint64 id, td_api::removeSavedAnimation &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(RemoveSavedAnimationRequest, std::move(request.animation_));
}

void Requests::on_request(uint64 id, const td_api::getSavedNotificationSound &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(GetSavedNotificationSoundRequest, request.notification_sound_id_);
}

void Requests::on_request(uint64 id, const td_api::getSavedNotificationSounds &request) {
  CHECK_IS_USER();
  CREATE_NO_ARGS_REQUEST(GetSavedNotificationSoundsRequest);
}

void Requests::on_request(uint64 id, td_api::addSavedNotificationSound &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->notification_settings_manager_->add_saved_ringtone(std::move(request.sound_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeSavedNotificationSound &request) {
  CHECK_IS_USER();
  CREATE_REQUEST(RemoveSavedNotificationSoundRequest, request.notification_sound_id_);
}

void Requests::on_request(uint64 id, const td_api::getChatNotificationSettingsExceptions &request) {
  CHECK_IS_USER();
  bool filter_scope = false;
  NotificationSettingsScope scope = NotificationSettingsScope::Private;
  if (request.scope_ != nullptr) {
    filter_scope = true;
    scope = get_notification_settings_scope(request.scope_);
  }
  CREATE_REQUEST(GetChatNotificationSettingsExceptionsRequest, scope, filter_scope, request.compare_sound_);
}

void Requests::on_request(uint64 id, const td_api::getScopeNotificationSettings &request) {
  CHECK_IS_USER();
  if (request.scope_ == nullptr) {
    return send_error_raw(id, 400, "Scope must be non-empty");
  }
  CREATE_REQUEST(GetScopeNotificationSettingsRequest, get_notification_settings_scope(request.scope_));
}

void Requests::on_request(uint64 id, const td_api::removeChatActionBar &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->remove_dialog_action_bar(DialogId(request.chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reportChat &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.text_);
  CREATE_REQUEST_PROMISE();
  td_->dialog_manager_->report_dialog(DialogId(request.chat_id_), request.option_id_,
                                      MessageId::get_message_ids(request.message_ids_), request.text_,
                                      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reportChatPhoto &request) {
  CHECK_IS_USER();
  auto r_report_reason = ReportReason::get_report_reason(std::move(request.reason_), std::move(request.text_));
  if (r_report_reason.is_error()) {
    return send_error_raw(id, r_report_reason.error().code(), r_report_reason.error().message());
  }
  CREATE_OK_REQUEST_PROMISE();
  td_->dialog_manager_->report_dialog_photo(DialogId(request.chat_id_), FileId(request.file_id_, 0),
                                            r_report_reason.move_as_ok(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::reportMessageReactions &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, sender_dialog_id, get_message_sender_dialog_id(td_, request.sender_id_, false, false));
  report_message_reactions(td_, {DialogId(request.chat_id_), MessageId(request.message_id_)}, sender_dialog_id,
                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatStatistics &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_channel_statistics(DialogId(request.chat_id_), request.is_dark_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatRevenueStatistics &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_dialog_revenue_statistics(DialogId(request.chat_id_), request.is_dark_,
                                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatRevenueWithdrawalUrl &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->statistics_manager_->get_dialog_revenue_withdrawal_url(DialogId(request.chat_id_), request.password_,
                                                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getChatRevenueTransactions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_dialog_revenue_transactions(DialogId(request.chat_id_), request.offset_, request.limit_,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarRevenueStatistics &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_revenue_statistics(request.owner_id_, request.is_dark_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarWithdrawalUrl &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->star_manager_->get_star_withdrawal_url(request.owner_id_, request.star_count_, request.password_,
                                              std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarAdAccountUrl &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->star_manager_->get_star_ad_account_url(request.owner_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getMessageStatistics &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_channel_message_statistics({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                           request.is_dark_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStoryStatistics &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->get_channel_story_statistics({DialogId(request.chat_id_), StoryId(request.story_id_)},
                                                         request.is_dark_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getStatisticalGraph &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.token_);
  CREATE_REQUEST_PROMISE();
  td_->statistics_manager_->load_statistics_graph(DialogId(request.chat_id_), std::move(request.token_), request.x_,
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setChatNotificationSettings &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->messages_manager_->set_dialog_notification_settings(
                          DialogId(request.chat_id_), std::move(request.notification_settings_)));
}

void Requests::on_request(uint64 id, td_api::setForumTopicNotificationSettings &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->forum_topic_manager_->set_forum_topic_notification_settings(
                          DialogId(request.chat_id_), MessageId(request.message_thread_id_),
                          std::move(request.notification_settings_)));
}

void Requests::on_request(uint64 id, td_api::setScopeNotificationSettings &request) {
  CHECK_IS_USER();
  if (request.scope_ == nullptr) {
    return send_error_raw(id, 400, "Scope must be non-empty");
  }
  answer_ok_query(id, td_->notification_settings_manager_->set_scope_notification_settings(
                          get_notification_settings_scope(request.scope_), std::move(request.notification_settings_)));
}

void Requests::on_request(uint64 id, td_api::setReactionNotificationSettings &request) {
  CHECK_IS_USER();
  answer_ok_query(id, td_->notification_settings_manager_->set_reaction_notification_settings(
                          ReactionNotificationSettings(std::move(request.notification_settings_))));
}

void Requests::on_request(uint64 id, const td_api::resetAllNotificationSettings &request) {
  CHECK_IS_USER();
  td_->notification_settings_manager_->reset_all_notification_settings();
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::getMapThumbnailFile &request) {
  DialogId dialog_id(request.chat_id_);
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "getMapThumbnailFile")) {
    dialog_id = DialogId();
  }

  auto r_file_id = td_->file_manager_->get_map_thumbnail_file_id(
      Location(request.location_), request.zoom_, request.width_, request.height_, request.scale_, dialog_id);
  if (r_file_id.is_error()) {
    send_closure(td_actor_, &Td::send_error, id, r_file_id.move_as_error());
  } else {
    send_closure(td_actor_, &Td::send_result, id, td_->file_manager_->get_file_object(r_file_id.ok()));
  }
}

void Requests::on_request(uint64 id, const td_api::getLocalizationTargetInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::get_languages, request.only_local_,
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getLanguagePackInfo &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::search_language_info, request.language_pack_id_,
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getLanguagePackStrings &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  for (auto &key : request.keys_) {
    CLEAN_INPUT_STRING(key);
  }
  CREATE_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::get_language_pack_strings,
               std::move(request.language_pack_id_), std::move(request.keys_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::synchronizeLanguagePack &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::synchronize_language_pack,
               std::move(request.language_pack_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addCustomServerLanguagePack &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::add_custom_server_language,
               std::move(request.language_pack_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setCustomLanguagePack &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::set_custom_language, std::move(request.info_),
               std::move(request.strings_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editCustomLanguagePackInfo &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::edit_custom_language_info, std::move(request.info_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setCustomLanguagePackString &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::set_custom_language_string,
               std::move(request.language_pack_id_), std::move(request.new_string_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::deleteLanguagePack &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.language_pack_id_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->language_pack_manager_, &LanguagePackManager::delete_language, std::move(request.language_pack_id_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getOption &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->option_manager_->get_option(request.name_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setOption &request) {
  CLEAN_INPUT_STRING(request.name_);
  CREATE_OK_REQUEST_PROMISE();
  td_->option_manager_->set_option(request.name_, std::move(request.value_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setPollAnswer &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->set_poll_answer({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                          std::move(request.option_ids_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPollVoters &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->messages_manager_->get_poll_voters({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                          request.option_id_, request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::stopPoll &request) {
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->stop_poll({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                    std::move(request.reply_markup_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::hideSuggestedAction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  dismiss_suggested_action(SuggestedAction(request.action_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::hideContactCloseBirthdays &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->option_manager_->set_option_boolean("dismiss_birthday_contact_today", true);
  td_->user_manager_->hide_contact_birthdays(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getBusinessConnection &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.connection_id_);
  CREATE_REQUEST_PROMISE();
  td_->business_connection_manager_->get_business_connection(BusinessConnectionId(std::move(request.connection_id_)),
                                                             std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getLoginUrlInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_login_url_info({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                         request.button_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getLoginUrl &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_login_url({DialogId(request.chat_id_), MessageId(request.message_id_)}, request.button_id_,
                                    request.allow_write_access_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::shareUsersWithBot &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  auto user_ids = UserId::get_user_ids(request.shared_user_ids_);
  auto dialog_ids = transform(user_ids, [](UserId user_id) { return DialogId(user_id); });
  td_->messages_manager_->share_dialogs_with_bot({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                 request.button_id_, std::move(dialog_ids), true, request.only_check_,
                                                 std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::shareChatWithBot &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->messages_manager_->share_dialogs_with_bot({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                 request.button_id_, {DialogId(request.shared_chat_id_)}, false,
                                                 request.only_check_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getInlineQueryResults &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.query_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->inline_queries_manager_->send_inline_query(UserId(request.bot_user_id_), DialogId(request.chat_id_),
                                                  Location(request.user_location_), request.query_, request.offset_,
                                                  std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerInlineQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.next_offset_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_queries_manager_->answer_inline_query(request.inline_query_id_, request.is_personal_,
                                                    std::move(request.button_), std::move(request.results_),
                                                    request.cache_time_, request.next_offset_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::savePreparedInlineMessage &request) {
  CHECK_IS_BOT();
  CREATE_REQUEST_PROMISE();
  td_->inline_queries_manager_->save_prepared_inline_message(UserId(request.user_id_), std::move(request.result_),
                                                             std::move(request.chat_types_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPreparedInlineMessage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.prepared_message_id_);
  CREATE_REQUEST_PROMISE();
  td_->inline_queries_manager_->get_prepared_inline_message(UserId(request.bot_user_id_), request.prepared_message_id_,
                                                            std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getGrossingWebAppBots &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->web_app_manager_->get_popular_app_bots(request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchWebApp &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.web_app_short_name_);
  CREATE_REQUEST_PROMISE();
  td_->web_app_manager_->get_web_app(UserId(request.bot_user_id_), request.web_app_short_name_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getWebAppPlaceholder &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->user_manager_->get_web_app_placeholder(UserId(request.bot_user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getWebAppLinkUrl &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.web_app_short_name_);
  CLEAN_INPUT_STRING(request.start_parameter_);
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->web_app_manager_->request_app_web_view(
      DialogId(request.chat_id_), UserId(request.bot_user_id_), std::move(request.web_app_short_name_),
      std::move(request.start_parameter_), WebAppOpenParameters(std::move(request.parameters_)),
      request.allow_write_access_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getMainWebApp &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.start_parameter_);
  CREATE_REQUEST_PROMISE();
  td_->web_app_manager_->request_main_web_view(
      DialogId(request.chat_id_), UserId(request.bot_user_id_), std::move(request.start_parameter_),
      WebAppOpenParameters(std::move(request.parameters_)), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getWebAppUrl &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.url_);
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->inline_queries_manager_->get_simple_web_view_url(UserId(request.bot_user_id_), std::move(request.url_),
                                                        WebAppOpenParameters(std::move(request.parameters_)),
                                                        std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendWebAppData &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.button_text_);
  CLEAN_INPUT_STRING(request.data_);
  CREATE_OK_REQUEST_PROMISE();
  td_->inline_queries_manager_->send_web_view_data(UserId(request.bot_user_id_), std::move(request.button_text_),
                                                   std::move(request.data_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::openWebApp &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.url_);
  CREATE_REQUEST_PROMISE();
  td_->web_app_manager_->request_web_view(DialogId(request.chat_id_), UserId(request.bot_user_id_),
                                          MessageId(request.message_thread_id_), std::move(request.reply_to_),
                                          std::move(request.url_), WebAppOpenParameters(std::move(request.parameters_)),
                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::closeWebApp &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->web_app_manager_->close_web_view(request.web_app_launch_id_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerWebAppQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.web_app_query_id_);
  CREATE_REQUEST_PROMISE();
  td_->inline_queries_manager_->answer_web_view_query(request.web_app_query_id_, std::move(request.result_),
                                                      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkWebAppFileDownload &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.file_name_);
  CLEAN_INPUT_STRING(request.url_);
  CREATE_OK_REQUEST_PROMISE();
  td_->web_app_manager_->check_download_file_params(UserId(request.bot_user_id_), request.file_name_, request.url_,
                                                    std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getCallbackQueryAnswer &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->callback_queries_manager_->send_callback_query({DialogId(request.chat_id_), MessageId(request.message_id_)},
                                                      std::move(request.payload_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerCallbackQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.text_);
  CLEAN_INPUT_STRING(request.url_);
  CREATE_OK_REQUEST_PROMISE();
  td_->callback_queries_manager_->answer_callback_query(request.callback_query_id_, request.text_, request.show_alert_,
                                                        request.url_, request.cache_time_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerShippingQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.error_message_);
  CREATE_OK_REQUEST_PROMISE();
  answer_shipping_query(td_, request.shipping_query_id_, std::move(request.shipping_options_), request.error_message_,
                        std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerPreCheckoutQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.error_message_);
  CREATE_OK_REQUEST_PROMISE();
  answer_pre_checkout_query(td_, request.pre_checkout_query_id_, request.error_message_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getBankCardInfo &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.bank_card_number_);
  CREATE_REQUEST_PROMISE();
  get_bank_card_info(td_, request.bank_card_number_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPaymentForm &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_payment_form(td_, std::move(request.input_invoice_), request.theme_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::validateOrderInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  validate_order_info(td_, std::move(request.input_invoice_), std::move(request.order_info_), request.allow_save_,
                      std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendPaymentForm &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.order_info_id_);
  CLEAN_INPUT_STRING(request.shipping_option_id_);
  CREATE_REQUEST_PROMISE();
  send_payment_form(td_, std::move(request.input_invoice_), request.payment_form_id_, request.order_info_id_,
                    request.shipping_option_id_, request.credentials_, request.tip_amount_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPaymentReceipt &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_payment_receipt(td_, {DialogId(request.chat_id_), MessageId(request.message_id_)}, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSavedOrderInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_saved_order_info(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteSavedOrderInfo &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  delete_saved_order_info(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteSavedCredentials &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  delete_saved_credentials(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getAvailableGifts &request) {
  CREATE_REQUEST_PROMISE();
  td_->star_gift_manager_->get_gift_payment_options(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendGift &request) {
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, owner_dialog_id, get_message_sender_dialog_id(td_, request.owner_id_, true, false));
  td_->star_gift_manager_->send_gift(request.gift_id_, owner_dialog_id, std::move(request.text_), request.is_private_,
                                     request.pay_for_upgrade_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::sellGift &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->star_gift_manager_->convert_gift(StarGiftId(request.received_gift_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleGiftIsSaved &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->star_gift_manager_->save_gift(StarGiftId(request.received_gift_id_), request.is_saved_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setPinnedGifts &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, owner_dialog_id, get_message_sender_dialog_id(td_, request.owner_id_, true, false));
  td_->star_gift_manager_->set_dialog_pinned_gifts(
      owner_dialog_id,
      transform(request.received_gift_ids_,
                [](const string &received_gift_id) { return StarGiftId(received_gift_id); }),
      std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::toggleChatGiftNotifications &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->star_gift_manager_->toggle_chat_star_gift_notifications(DialogId(request.chat_id_), request.are_enabled_,
                                                               std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGiftUpgradePreview &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_gift_manager_->get_gift_upgrade_preview(request.gift_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::upgradeGift &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_gift_manager_->upgrade_gift(StarGiftId(request.received_gift_id_), request.keep_original_details_,
                                        request.star_count_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::transferGift &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, owner_dialog_id, get_message_sender_dialog_id(td_, request.new_owner_id_, true, false));
  td_->star_gift_manager_->transfer_gift(StarGiftId(request.received_gift_id_), owner_dialog_id, request.star_count_,
                                         std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getReceivedGifts &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  TRY_RESULT_PROMISE(promise, owner_dialog_id, get_message_sender_dialog_id(td_, request.owner_id_, true, false));
  td_->star_gift_manager_->get_saved_star_gifts(owner_dialog_id, request.exclude_unsaved_, request.exclude_saved_,
                                                request.exclude_unlimited_, request.exclude_limited_,
                                                request.exclude_upgraded_, request.sort_by_price_, request.offset_,
                                                request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getReceivedGift &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_gift_manager_->get_saved_star_gift(StarGiftId(request.received_gift_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getUpgradedGift &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST_PROMISE();
  td_->star_gift_manager_->get_upgraded_gift(request.name_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getUpgradedGiftWithdrawalUrl &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  td_->star_gift_manager_->get_star_gift_withdrawal_url(StarGiftId(request.received_gift_id_), request.password_,
                                                        std::move(promise));
}

void Requests::on_request(uint64 id, td_api::createInvoiceLink &request) {
  CLEAN_INPUT_STRING(request.business_connection_id_);
  CHECK_IS_BOT();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  export_invoice(td_, BusinessConnectionId(std::move(request.business_connection_id_)), std::move(request.invoice_),
                 std::move(promise));
}

void Requests::on_request(uint64 id, td_api::refundStarPayment &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.telegram_payment_charge_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->star_manager_->refund_star_payment(UserId(request.user_id_), request.telegram_payment_charge_id_,
                                          std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPassportElement &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  if (request.type_ == nullptr) {
    return send_error_raw(id, 400, "Type must be non-empty");
  }
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::get_secure_value, std::move(request.password_),
               get_secure_value_type_td_api(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getAllPassportElements &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::get_all_secure_values, std::move(request.password_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setPassportElement &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  auto r_secure_value = get_secure_value(td_->file_manager_.get(), std::move(request.element_));
  if (r_secure_value.is_error()) {
    return send_error_raw(id, 400, r_secure_value.error().message());
  }
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::set_secure_value, std::move(request.password_),
               r_secure_value.move_as_ok(), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deletePassportElement &request) {
  CHECK_IS_USER();
  if (request.type_ == nullptr) {
    return send_error_raw(id, 400, "Type must be non-empty");
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::delete_secure_value, get_secure_value_type_td_api(request.type_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setPassportElementErrors &request) {
  CHECK_IS_BOT();
  auto r_input_user = td_->user_manager_->get_input_user(UserId(request.user_id_));
  if (r_input_user.is_error()) {
    return send_error_raw(id, r_input_user.error().code(), r_input_user.error().message());
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::set_secure_value_errors, td_, r_input_user.move_as_ok(),
               std::move(request.errors_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPreferredCountryLanguage &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.country_code_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::get_preferred_country_language, std::move(request.country_code_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendEmailAddressVerificationCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.email_address_);
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<SentEmailCode> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_email_address_authentication_code_info_object());
    }
  });
  send_closure(td_->password_manager_, &PasswordManager::send_email_address_verification_code,
               std::move(request.email_address_), std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::resendEmailAddressVerificationCode &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<SentEmailCode> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(result.ok().get_email_address_authentication_code_info_object());
    }
  });
  send_closure(td_->password_manager_, &PasswordManager::resend_email_address_verification_code,
               std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::checkEmailAddressVerificationCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.code_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->password_manager_, &PasswordManager::check_email_address_verification_code,
               std::move(request.code_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPassportAuthorizationForm &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.public_key_);
  CLEAN_INPUT_STRING(request.scope_);
  CLEAN_INPUT_STRING(request.nonce_);
  UserId bot_user_id(request.bot_user_id_);
  if (!bot_user_id.is_valid()) {
    return send_error_raw(id, 400, "Bot user identifier invalid");
  }
  if (request.nonce_.empty()) {
    return send_error_raw(id, 400, "Nonce must be non-empty");
  }
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::get_passport_authorization_form, bot_user_id,
               std::move(request.scope_), std::move(request.public_key_), std::move(request.nonce_),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getPassportAuthorizationFormAvailableElements &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.password_);
  CREATE_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::get_passport_authorization_form_available_elements,
               request.authorization_form_id_, std::move(request.password_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendPassportAuthorizationForm &request) {
  CHECK_IS_USER();
  for (auto &type : request.types_) {
    if (type == nullptr) {
      return send_error_raw(id, 400, "Type must be non-empty");
    }
  }

  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->secure_manager_, &SecureManager::send_passport_authorization_form, request.authorization_form_id_,
               get_secure_value_types_td_api(request.types_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSupportUser &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->user_manager_->get_support_user(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getInstalledBackgrounds &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->background_manager_->get_backgrounds(request.for_dark_theme_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getBackgroundUrl &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.name_);
  Result<string> r_url = LinkManager::get_background_url(request.name_, std::move(request.type_));
  if (r_url.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_url.move_as_error());
  }

  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::httpUrl>(r_url.ok()));
}

void Requests::on_request(uint64 id, td_api::searchBackground &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.name_);
  CREATE_REQUEST(SearchBackgroundRequest, std::move(request.name_));
}

void Requests::on_request(uint64 id, const td_api::setDefaultBackground &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->background_manager_->set_background(request.background_.get(), request.type_.get(), request.for_dark_theme_,
                                           std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::deleteDefaultBackground &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->background_manager_->delete_background(request.for_dark_theme_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeInstalledBackground &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->background_manager_->remove_background(BackgroundId(request.background_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::resetInstalledBackgrounds &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->background_manager_->reset_backgrounds(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getRecentlyVisitedTMeUrls &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.referrer_);
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_recent_me_urls(request.referrer_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setBotUpdatesStatus &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.error_message_);
  CREATE_OK_REQUEST_PROMISE();
  set_bot_updates_status(td_, request.pending_update_count_, request.error_message_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::sendCustomRequest &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.method_);
  CLEAN_INPUT_STRING(request.parameters_);
  CREATE_REQUEST_PROMISE();
  send_bot_custom_query(td_, request.method_, request.parameters_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::answerCustomQuery &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.data_);
  CREATE_OK_REQUEST_PROMISE();
  answer_bot_custom_query(td_, request.custom_query_id_, request.data_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setAlarm &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->alarm_manager_, &AlarmManager::set_alarm, request.seconds_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchHashtags &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.prefix_);
  CREATE_REQUEST_PROMISE();
  auto query_promise =
      PromiseCreator::lambda([promise = std::move(promise)](Result<std::vector<string>> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(td_api::make_object<td_api::hashtags>(result.move_as_ok()));
        }
      });
  send_closure(td_->hashtag_hints_, &HashtagHints::query, std::move(request.prefix_), request.limit_,
               std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::removeRecentHashtag &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.hashtag_);
  CREATE_OK_REQUEST_PROMISE();
  send_closure(td_->hashtag_hints_, &HashtagHints::remove_hashtag, std::move(request.hashtag_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumLimit &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_limit(request.limit_type_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumFeatures &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_features(td_, request.source_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumStickerExamples &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->search_stickers(StickerType::Regular, "⭐️⭐️", string(), vector<string>(), 0, 100,
                                          std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumInfoSticker &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->stickers_manager_->load_premium_gift_sticker(request.month_count_, 0, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::viewPremiumFeature &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  view_premium_feature(td_, request.feature_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::clickPremiumSubscriptionButton &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  click_premium_subscription_button(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumState &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_state(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumGiftPaymentOptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_gift_payment_options(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPremiumGiveawayPaymentOptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_giveaway_options(td_, DialogId(request.boosted_chat_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::checkPremiumGiftCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.code_);
  CREATE_REQUEST_PROMISE();
  check_premium_gift_code(td_, request.code_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::applyPremiumGiftCode &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.code_);
  CREATE_OK_REQUEST_PROMISE();
  apply_premium_gift_code(td_, request.code_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::launchPrepaidGiveaway &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  launch_prepaid_premium_giveaway(td_, request.giveaway_id_, std::move(request.parameters_), request.winner_count_,
                                  request.star_count_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getGiveawayInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_premium_giveaway_info(td_, {DialogId(request.chat_id_), MessageId(request.message_id_)}, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarPaymentOptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_payment_options(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarGiftPaymentOptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_gift_payment_options(UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getStarGiveawayPaymentOptions &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_giveaway_payment_options(std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getStarTransactions &request) {
  CLEAN_INPUT_STRING(request.subscription_id_);
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_transactions(std::move(request.owner_id_), request.subscription_id_, request.offset_,
                                            request.limit_, std::move(request.direction_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getStarSubscriptions &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->star_manager_->get_star_subscriptions(request.only_expiring_, request.offset_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editStarSubscription &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.subscription_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->star_manager_->edit_star_subscription(request.subscription_id_, request.is_canceled_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editUserStarSubscription &request) {
  CHECK_IS_BOT();
  CLEAN_INPUT_STRING(request.telegram_payment_charge_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->star_manager_->edit_user_star_subscription(UserId(request.user_id_), request.telegram_payment_charge_id_,
                                                  request.is_canceled_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::reuseStarSubscription &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.subscription_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->star_manager_->reuse_star_subscription(request.subscription_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::setChatAffiliateProgram &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  td_->referral_program_manager_->set_dialog_referral_program(
      DialogId(request.chat_id_), ReferralProgramParameters(request.parameters_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchChatAffiliateProgram &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.username_);
  CLEAN_INPUT_STRING(request.referrer_);
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->search_dialog_referral_program(request.username_, request.referrer_,
                                                                 std::move(promise));
}

void Requests::on_request(uint64 id, td_api::searchAffiliatePrograms &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->search_referral_programs(request.affiliate_,
                                                           get_referral_program_sort_order(request.sort_order_),
                                                           request.offset_, request.limit_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::connectAffiliateProgram &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->connect_referral_program(request.affiliate_, UserId(request.bot_user_id_),
                                                           std::move(promise));
}

void Requests::on_request(uint64 id, td_api::disconnectAffiliateProgram &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.url_);
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->revoke_referral_program(request.affiliate_, request.url_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getConnectedAffiliateProgram &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->get_connected_referral_program(request.affiliate_, UserId(request.bot_user_id_),
                                                                 std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getConnectedAffiliatePrograms &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.offset_);
  CREATE_REQUEST_PROMISE();
  td_->referral_program_manager_->get_connected_referral_programs(request.affiliate_, request.offset_, request.limit_,
                                                                  std::move(promise));
}

void Requests::on_request(uint64 id, td_api::canPurchaseFromStore &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  can_purchase_premium(td_, std::move(request.purpose_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::assignAppStoreTransaction &request) {
  CHECK_IS_USER();
  CREATE_OK_REQUEST_PROMISE();
  assign_app_store_transaction(td_, request.receipt_, std::move(request.purpose_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::assignGooglePlayTransaction &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.package_name_);
  CLEAN_INPUT_STRING(request.store_product_id_);
  CLEAN_INPUT_STRING(request.purchase_token_);
  CREATE_OK_REQUEST_PROMISE();
  assign_play_market_transaction(td_, request.package_name_, request.store_product_id_, request.purchase_token_,
                                 std::move(request.purpose_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getBusinessFeatures &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_business_features(td_, request.source_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::acceptTermsOfService &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.terms_of_service_id_);
  CREATE_OK_REQUEST_PROMISE();
  td_->terms_of_service_manager_->accept_terms_of_service(std::move(request.terms_of_service_id_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCountries &request) {
  CREATE_REQUEST_PROMISE();
  td_->country_info_manager_->get_countries(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getCountryCode &request) {
  CREATE_TEXT_REQUEST_PROMISE();
  td_->country_info_manager_->get_current_country_code(std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getPhoneNumberInfo &request) {
  CREATE_REQUEST_PROMISE();
  td_->country_info_manager_->get_phone_number_info(request.phone_number_prefix_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getCollectibleItemInfo &request) {
  CREATE_REQUEST_PROMISE();
  get_collectible_info(td_, std::move(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getApplicationDownloadLink &request) {
  CHECK_IS_USER();
  CREATE_HTTP_URL_REQUEST_PROMISE();
  get_invite_text(td_, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::getDeepLinkInfo &request) {
  CLEAN_INPUT_STRING(request.link_);
  CREATE_REQUEST_PROMISE();
  td_->link_manager_->get_deep_link_info(request.link_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getApplicationConfig &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  send_closure(G()->config_manager(), &ConfigManager::get_app_config, std::move(promise));
}

void Requests::on_request(uint64 id, td_api::saveApplicationLogEvent &request) {
  CHECK_IS_USER();
  CLEAN_INPUT_STRING(request.type_);
  CREATE_OK_REQUEST_PROMISE();
  save_app_log(td_, request.type_, DialogId(request.chat_id_), convert_json_value(std::move(request.data_)),
               std::move(promise));
}

void Requests::on_request(uint64 id, td_api::addProxy &request) {
  CLEAN_INPUT_STRING(request.server_);
  CREATE_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::add_proxy, -1, std::move(request.server_), request.port_,
               request.enable_, std::move(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::editProxy &request) {
  if (request.proxy_id_ < 0) {
    return send_error_raw(id, 400, "Proxy identifier invalid");
  }
  CLEAN_INPUT_STRING(request.server_);
  CREATE_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::add_proxy, request.proxy_id_, std::move(request.server_),
               request.port_, request.enable_, std::move(request.type_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::enableProxy &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::enable_proxy, request.proxy_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::disableProxy &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::disable_proxy, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::removeProxy &request) {
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::remove_proxy, request.proxy_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getProxies &request) {
  CREATE_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::get_proxies, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getProxyLink &request) {
  CREATE_HTTP_URL_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::get_proxy_link, request.proxy_id_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::pingProxy &request) {
  CREATE_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<double> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(td_api::make_object<td_api::seconds>(result.move_as_ok()));
    }
  });
  send_closure(G()->connection_creator(), &ConnectionCreator::ping_proxy, request.proxy_id_, std::move(query_promise));
}

void Requests::on_request(uint64 id, const td_api::getUserSupportInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  get_user_info(td_, UserId(request.user_id_), std::move(promise));
}

void Requests::on_request(uint64 id, td_api::setUserSupportInfo &request) {
  CHECK_IS_USER();
  CREATE_REQUEST_PROMISE();
  set_user_info(td_, UserId(request.user_id_), std::move(request.message_), std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::getSupportName &request) {
  CHECK_IS_USER();
  CREATE_TEXT_REQUEST_PROMISE();
  get_support_name(td_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::searchQuote &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getTextEntities &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::parseTextEntities &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::parseMarkdown &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getMarkdownText &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::searchStringsByPrefix &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::checkQuickReplyShortcutName &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getCountryFlagEmoji &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getFileMimeType &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getFileExtension &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::cleanFileName &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getLanguagePackString &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getPhoneNumberInfoSync &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getPushReceiverId &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getChatFolderDefaultIconName &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getJsonValue &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getJsonString &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getThemeParametersJsonString &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::setLogStream &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getLogStream &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::setLogVerbosityLevel &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getLogVerbosityLevel &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getLogTags &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::setLogTagVerbosityLevel &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::getLogTagVerbosityLevel &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::addLogMessage &request) {
  UNREACHABLE();
}

// test
void Requests::on_request(uint64 id, const td_api::testNetwork &request) {
  CREATE_OK_REQUEST_PROMISE();
  auto query_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<string> result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      promise.set_value(Unit());
    }
  });
  td_->country_info_manager_->get_current_country_code(std::move(query_promise));
}

void Requests::on_request(uint64 id, td_api::testProxy &request) {
  auto r_proxy = Proxy::create_proxy(std::move(request.server_), request.port_, request.type_.get());
  if (r_proxy.is_error()) {
    return send_closure(td_actor_, &Td::send_error, id, r_proxy.move_as_error());
  }
  CREATE_OK_REQUEST_PROMISE();
  send_closure(G()->connection_creator(), &ConnectionCreator::test_proxy, r_proxy.move_as_ok(), request.dc_id_,
               request.timeout_, std::move(promise));
}

void Requests::on_request(uint64 id, const td_api::testGetDifference &request) {
  td_->updates_manager_->get_difference("testGetDifference");
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::testUseUpdate &request) {
  send_closure(td_actor_, &Td::send_result, id, nullptr);
}

void Requests::on_request(uint64 id, const td_api::testReturnError &request) {
  UNREACHABLE();
}

void Requests::on_request(uint64 id, const td_api::testCallEmpty &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::ok>());
}

void Requests::on_request(uint64 id, const td_api::testSquareInt &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::testInt>(request.x_ * request.x_));
}

void Requests::on_request(uint64 id, td_api::testCallString &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::testString>(std::move(request.x_)));
}

void Requests::on_request(uint64 id, td_api::testCallBytes &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::testBytes>(std::move(request.x_)));
}

void Requests::on_request(uint64 id, td_api::testCallVectorInt &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::testVectorInt>(std::move(request.x_)));
}

void Requests::on_request(uint64 id, td_api::testCallVectorIntObject &request) {
  send_closure(td_actor_, &Td::send_result, id,
               td_api::make_object<td_api::testVectorIntObject>(std::move(request.x_)));
}

void Requests::on_request(uint64 id, td_api::testCallVectorString &request) {
  send_closure(td_actor_, &Td::send_result, id, td_api::make_object<td_api::testVectorString>(std::move(request.x_)));
}

void Requests::on_request(uint64 id, td_api::testCallVectorStringObject &request) {
  send_closure(td_actor_, &Td::send_result, id,
               td_api::make_object<td_api::testVectorStringObject>(std::move(request.x_)));
}

#undef CLEAN_INPUT_STRING
#undef CHECK_IS_BOT
#undef CHECK_IS_USER
#undef CREATE_NO_ARGS_REQUEST
#undef CREATE_REQUEST
#undef CREATE_REQUEST_PROMISE
#undef CREATE_OK_REQUEST_PROMISE
#undef CREATE_TEXT_REQUEST_PROMISE
#undef CREATE_HTTP_URL_REQUEST_PROMISE

}  // namespace td
