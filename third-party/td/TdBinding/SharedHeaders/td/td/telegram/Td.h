//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryStats.h"
#include "td/telegram/td_api.h"
#include "td/telegram/TdCallback.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <memory>
#include <unordered_map>
#include <utility>

namespace td {

class AccountManager;
class AlarmManager;
class AnimationsManager;
class AttachMenuManager;
class AudiosManager;
class AuthManager;
class AutosaveManager;
class BackgroundManager;
class BoostManager;
class BotInfoManager;
class BotRecommendationManager;
class BusinessConnectionManager;
class BusinessManager;
class CallManager;
class CallbackQueriesManager;
class ChannelRecommendationManager;
class ChatManager;
class CommonDialogManager;
class ConfigManager;
class ConnectionStateManager;
class CountryInfoManager;
class DeviceTokenManager;
class DialogActionManager;
class DialogFilterManager;
class DialogInviteLinkManager;
class DialogManager;
class DialogParticipantManager;
class DocumentsManager;
class DownloadManager;
class FileManager;
class FileReferenceManager;
class ForumTopicManager;
class GameManager;
class GroupCallManager;
class InlineMessageManager;
class InlineQueriesManager;
class HashtagHints;
class LanguagePackManager;
class LinkManager;
class MessageImportManager;
class MessageQueryManager;
class MessagesManager;
class NetStatsManager;
class NotificationManager;
class NotificationSettingsManager;
class OnlineManager;
class OptionManager;
class PasswordManager;
class PeopleNearbyManager;
class PhoneNumberManager;
class PollManager;
class PrivacyManager;
class PromoDataManager;
class QuickReplyManager;
class ReactionManager;
class ReferralProgramManager;
class Requests;
class SavedMessagesManager;
class SecureManager;
class SecretChatsManager;
class SponsoredMessageManager;
class StarGiftManager;
class StarManager;
class StateManager;
class StatisticsManager;
class StickersManager;
class StorageManager;
class StoryManager;
class SuggestedActionManager;
class TermsOfServiceManager;
class ThemeManager;
class TimeZoneManager;
class TopDialogManager;
class TranscriptionManager;
class TranslationManager;
class UpdatesManager;
class UserManager;
class VideoNotesManager;
class VideosManager;
class VoiceNotesManager;
class WebAppManager;
class WebPagesManager;

extern int VERBOSITY_NAME(td_init);
extern int VERBOSITY_NAME(td_requests);

// Td may start closing after explicit "close" or "destroy" query.
// Or it may start closing by itself, because authorization is lost.
// It any case the parent will be notified via updateAuthorizationState.
//
// Td needs a way to know that it will receive no more queries.
// It happens after "hangup".
//
// Parent needs a way to know that it will receive no more updates.
// It happens after destruction of callback
class Td final : public Actor {
 public:
  Td(const Td &) = delete;
  Td(Td &&) = delete;
  Td &operator=(const Td &) = delete;
  Td &operator=(Td &&) = delete;
  ~Td() final;

  struct Options {
    std::shared_ptr<NetQueryStats> net_query_stats;
  };

  Td(unique_ptr<TdCallback> callback, Options options);

  void request(uint64 id, tl_object_ptr<td_api::Function> function);

  void destroy();

  void on_update(telegram_api::object_ptr<telegram_api::Updates> updates, uint64 auth_key_id);

  void on_result(NetQueryPtr query);

  bool can_ignore_background_updates() const {
    return can_ignore_background_updates_;
  }

  bool ignore_background_updates() const;

  unique_ptr<AudiosManager> audios_manager_;
  unique_ptr<CallbackQueriesManager> callback_queries_manager_;
  unique_ptr<DocumentsManager> documents_manager_;
  unique_ptr<OptionManager> option_manager_;
  unique_ptr<VideosManager> videos_manager_;

  unique_ptr<AccountManager> account_manager_;
  ActorOwn<AccountManager> account_manager_actor_;
  unique_ptr<AnimationsManager> animations_manager_;
  ActorOwn<AnimationsManager> animations_manager_actor_;
  unique_ptr<AttachMenuManager> attach_menu_manager_;
  ActorOwn<AttachMenuManager> attach_menu_manager_actor_;
  unique_ptr<AuthManager> auth_manager_;
  ActorOwn<AuthManager> auth_manager_actor_;
  unique_ptr<AutosaveManager> autosave_manager_;
  ActorOwn<AutosaveManager> autosave_manager_actor_;
  unique_ptr<BackgroundManager> background_manager_;
  ActorOwn<BackgroundManager> background_manager_actor_;
  unique_ptr<BoostManager> boost_manager_;
  ActorOwn<BoostManager> boost_manager_actor_;
  unique_ptr<BotInfoManager> bot_info_manager_;
  ActorOwn<BotInfoManager> bot_info_manager_actor_;
  unique_ptr<BotRecommendationManager> bot_recommendation_manager_;
  ActorOwn<BotRecommendationManager> bot_recommendation_manager_actor_;
  unique_ptr<BusinessConnectionManager> business_connection_manager_;
  ActorOwn<BusinessConnectionManager> business_connection_manager_actor_;
  unique_ptr<BusinessManager> business_manager_;
  ActorOwn<BusinessManager> business_manager_actor_;
  unique_ptr<CallManager> call_manager_;
  ActorOwn<CallManager> call_manager_actor_;
  unique_ptr<ChannelRecommendationManager> channel_recommendation_manager_;
  ActorOwn<ChannelRecommendationManager> channel_recommendation_manager_actor_;
  unique_ptr<ChatManager> chat_manager_;
  ActorOwn<ChatManager> chat_manager_actor_;
  unique_ptr<CommonDialogManager> common_dialog_manager_;
  ActorOwn<CommonDialogManager> common_dialog_manager_actor_;
  unique_ptr<ConnectionStateManager> connection_state_manager_;
  ActorOwn<ConnectionStateManager> connection_state_manager_actor_;
  unique_ptr<CountryInfoManager> country_info_manager_;
  ActorOwn<CountryInfoManager> country_info_manager_actor_;
  unique_ptr<DialogActionManager> dialog_action_manager_;
  ActorOwn<DialogActionManager> dialog_action_manager_actor_;
  unique_ptr<DialogFilterManager> dialog_filter_manager_;
  ActorOwn<DialogFilterManager> dialog_filter_manager_actor_;
  unique_ptr<DialogInviteLinkManager> dialog_invite_link_manager_;
  ActorOwn<DialogInviteLinkManager> dialog_invite_link_manager_actor_;
  unique_ptr<DialogManager> dialog_manager_;
  ActorOwn<DialogManager> dialog_manager_actor_;
  unique_ptr<DialogParticipantManager> dialog_participant_manager_;
  ActorOwn<DialogParticipantManager> dialog_participant_manager_actor_;
  unique_ptr<DownloadManager> download_manager_;
  ActorOwn<DownloadManager> download_manager_actor_;
  unique_ptr<FileManager> file_manager_;
  ActorOwn<FileManager> file_manager_actor_;
  unique_ptr<FileReferenceManager> file_reference_manager_;
  ActorOwn<FileReferenceManager> file_reference_manager_actor_;
  unique_ptr<ForumTopicManager> forum_topic_manager_;
  ActorOwn<ForumTopicManager> forum_topic_manager_actor_;
  unique_ptr<GameManager> game_manager_;
  ActorOwn<GameManager> game_manager_actor_;
  unique_ptr<GroupCallManager> group_call_manager_;
  ActorOwn<GroupCallManager> group_call_manager_actor_;
  unique_ptr<InlineMessageManager> inline_message_manager_;
  ActorOwn<InlineMessageManager> inline_message_manager_actor_;
  unique_ptr<InlineQueriesManager> inline_queries_manager_;
  ActorOwn<InlineQueriesManager> inline_queries_manager_actor_;
  unique_ptr<LinkManager> link_manager_;
  ActorOwn<LinkManager> link_manager_actor_;
  unique_ptr<MessageImportManager> message_import_manager_;
  ActorOwn<MessageImportManager> message_import_manager_actor_;
  unique_ptr<MessageQueryManager> message_query_manager_;
  ActorOwn<MessageQueryManager> message_query_manager_actor_;
  unique_ptr<MessagesManager> messages_manager_;
  ActorOwn<MessagesManager> messages_manager_actor_;
  unique_ptr<NotificationManager> notification_manager_;
  ActorOwn<NotificationManager> notification_manager_actor_;
  unique_ptr<NotificationSettingsManager> notification_settings_manager_;
  ActorOwn<NotificationSettingsManager> notification_settings_manager_actor_;
  unique_ptr<OnlineManager> online_manager_;
  ActorOwn<OnlineManager> online_manager_actor_;
  unique_ptr<PeopleNearbyManager> people_nearby_manager_;
  ActorOwn<PeopleNearbyManager> people_nearby_manager_actor_;
  unique_ptr<PhoneNumberManager> phone_number_manager_;
  ActorOwn<PhoneNumberManager> phone_number_manager_actor_;
  unique_ptr<PollManager> poll_manager_;
  ActorOwn<PollManager> poll_manager_actor_;
  unique_ptr<PrivacyManager> privacy_manager_;
  ActorOwn<PrivacyManager> privacy_manager_actor_;
  unique_ptr<PromoDataManager> promo_data_manager_;
  ActorOwn<PromoDataManager> promo_data_manager_actor_;
  unique_ptr<QuickReplyManager> quick_reply_manager_;
  ActorOwn<QuickReplyManager> quick_reply_manager_actor_;
  unique_ptr<ReactionManager> reaction_manager_;
  ActorOwn<ReactionManager> reaction_manager_actor_;
  unique_ptr<ReferralProgramManager> referral_program_manager_;
  ActorOwn<ReferralProgramManager> referral_program_manager_actor_;
  unique_ptr<SavedMessagesManager> saved_messages_manager_;
  ActorOwn<SavedMessagesManager> saved_messages_manager_actor_;
  unique_ptr<SponsoredMessageManager> sponsored_message_manager_;
  ActorOwn<SponsoredMessageManager> sponsored_message_manager_actor_;
  unique_ptr<StarGiftManager> star_gift_manager_;
  ActorOwn<StarGiftManager> star_gift_manager_actor_;
  unique_ptr<StarManager> star_manager_;
  ActorOwn<StarManager> star_manager_actor_;
  unique_ptr<StatisticsManager> statistics_manager_;
  ActorOwn<StatisticsManager> statistics_manager_actor_;
  unique_ptr<StickersManager> stickers_manager_;
  ActorOwn<StickersManager> stickers_manager_actor_;
  unique_ptr<StoryManager> story_manager_;
  ActorOwn<StoryManager> story_manager_actor_;
  unique_ptr<SuggestedActionManager> suggested_action_manager_;
  ActorOwn<SuggestedActionManager> suggested_action_manager_actor_;
  unique_ptr<TermsOfServiceManager> terms_of_service_manager_;
  ActorOwn<TermsOfServiceManager> terms_of_service_manager_actor_;
  unique_ptr<ThemeManager> theme_manager_;
  ActorOwn<ThemeManager> theme_manager_actor_;
  unique_ptr<TimeZoneManager> time_zone_manager_;
  ActorOwn<TimeZoneManager> time_zone_manager_actor_;
  unique_ptr<TopDialogManager> top_dialog_manager_;
  ActorOwn<TopDialogManager> top_dialog_manager_actor_;
  unique_ptr<TranscriptionManager> transcription_manager_;
  ActorOwn<TranscriptionManager> transcription_manager_actor_;
  unique_ptr<TranslationManager> translation_manager_;
  ActorOwn<TranslationManager> translation_manager_actor_;
  unique_ptr<UpdatesManager> updates_manager_;
  ActorOwn<UpdatesManager> updates_manager_actor_;
  unique_ptr<UserManager> user_manager_;
  ActorOwn<UserManager> user_manager_actor_;
  unique_ptr<VideoNotesManager> video_notes_manager_;
  ActorOwn<VideoNotesManager> video_notes_manager_actor_;
  unique_ptr<VoiceNotesManager> voice_notes_manager_;
  ActorOwn<VoiceNotesManager> voice_notes_manager_actor_;
  unique_ptr<WebAppManager> web_app_manager_;
  ActorOwn<WebAppManager> web_app_manager_actor_;
  unique_ptr<WebPagesManager> web_pages_manager_;
  ActorOwn<WebPagesManager> web_pages_manager_actor_;

  ActorOwn<AlarmManager> alarm_manager_;
  ActorOwn<HashtagHints> cashtag_search_hints_;
  ActorOwn<ConfigManager> config_manager_;
  ActorOwn<DeviceTokenManager> device_token_manager_;
  ActorOwn<HashtagHints> hashtag_hints_;
  ActorOwn<HashtagHints> hashtag_search_hints_;
  ActorOwn<LanguagePackManager> language_pack_manager_;
  ActorOwn<NetStatsManager> net_stats_manager_;
  ActorOwn<PasswordManager> password_manager_;
  ActorOwn<SecretChatsManager> secret_chats_manager_;
  ActorOwn<SecureManager> secure_manager_;
  ActorOwn<StateManager> state_manager_;
  ActorOwn<StorageManager> storage_manager_;

  class ResultHandler : public std::enable_shared_from_this<ResultHandler> {
   public:
    ResultHandler() = default;
    ResultHandler(const ResultHandler &) = delete;
    ResultHandler &operator=(const ResultHandler &) = delete;
    virtual ~ResultHandler() = default;

    virtual void on_result(BufferSlice packet) {
      UNREACHABLE();
    }

    virtual void on_error(Status status) {
      UNREACHABLE();
    }

    friend class Td;

   protected:
    void send_query(NetQueryPtr query);

    Td *td_ = nullptr;
    bool is_query_sent_ = false;

   private:
    void set_td(Td *td);
  };

  template <class HandlerT, class... Args>
  std::shared_ptr<HandlerT> create_handler(Args &&...args) {
    LOG_CHECK(close_flag_ < 2) << close_flag_
#if TD_CLANG || TD_GCC
                               << ' ' << __PRETTY_FUNCTION__
#endif
        ;
    auto ptr = std::make_shared<HandlerT>(std::forward<Args>(args)...);
    ptr->set_td(this);
    return ptr;
  }

  void send_update(tl_object_ptr<td_api::Update> &&object);

  static td_api::object_ptr<td_api::Object> static_request(td_api::object_ptr<td_api::Function> function);

 private:
  void run_request(uint64 id, td_api::object_ptr<td_api::Function> function);

  void send_result(uint64 id, tl_object_ptr<td_api::Object> object);

  void send_error(uint64 id, Status error);

  void send_error_impl(uint64 id, tl_object_ptr<td_api::error> error);

  ActorShared<Td> create_reference();

  void inc_actor_refcnt();
  void dec_actor_refcnt();

  void inc_request_actor_refcnt();
  void dec_request_actor_refcnt();

  void close();
  void on_closed();

  void dec_stop_cnt();

  unique_ptr<TdCallback> callback_;
  Options td_options_;

  MtprotoHeader::Options options_;

  unique_ptr<Requests> requests_;
  std::unordered_multimap<uint64, int32> request_set_;
  int actor_refcnt_ = 0;
  int request_actor_refcnt_ = 0;
  int stop_cnt_ = 2;
  bool destroy_flag_ = false;
  int close_flag_ = 0;

  enum class State : int32 { WaitParameters, Run, Close } state_ = State::WaitParameters;
  uint64 set_parameters_request_id_ = 0;

  FlatHashMap<uint64, std::shared_ptr<ResultHandler>> result_handlers_;
  enum : int8 { RequestActorIdType = 1, ActorIdType = 2 };
  Container<ActorOwn<Actor>> request_actors_;

  bool can_ignore_background_updates_ = false;

  vector<std::pair<uint64, td_api::object_ptr<td_api::Function>>> pending_preauthentication_requests_;

  vector<std::pair<uint64, td_api::object_ptr<td_api::Function>>> pending_set_parameters_requests_;

  vector<std::pair<uint64, td_api::object_ptr<td_api::Function>>> pending_init_requests_;

  template <class T>
  void complete_pending_preauthentication_requests(const T &func);

  td_api::object_ptr<td_api::AuthorizationState> get_fake_authorization_state_object() const;

  vector<td_api::object_ptr<td_api::Update>> get_fake_current_state() const;

  template <class T>
  friend class RequestActor;  // uses send_result/send_error
  friend class AuthManager;   // uses send_result/send_error, TODO pass Promise<>
  friend class Requests;

  void add_handler(uint64 id, std::shared_ptr<ResultHandler> handler);
  std::shared_ptr<ResultHandler> extract_handler(uint64 id);

  void clear_requests();

  std::shared_ptr<ActorContext> old_context_;

  static bool is_authentication_request(int32 id);

  static bool is_preinitialization_request(int32 id);

  static bool is_preauthentication_request(int32 id);

  struct Parameters {
    int32 api_id_ = 0;
    string api_hash_;
    bool use_secret_chats_ = false;
  };

  void finish_set_parameters();

  void init(Parameters parameters, Result<TdDb::OpenedDatabase> r_opened_database);

  void init_options_and_network();

  void init_file_manager();

  void init_non_actor_managers();

  void init_managers();

  void init_pure_actor_managers();

  void process_binlog_events(TdDb::OpenedDatabase &&events);

  void clear();

  void close_impl(bool destroy_flag);

  Result<std::pair<Parameters, TdDb::Parameters>> get_parameters(
      td_api::object_ptr<td_api::setTdlibParameters> parameters) TD_WARN_UNUSED_RESULT;

  static td_api::object_ptr<td_api::error> make_error(int32 code, CSlice error) {
    return td_api::make_object<td_api::error>(code, error.str());
  }

  // Actor
  void start_up() final;
  void tear_down() final;
  void hangup_shared() final;
  void hangup() final;
};

}  // namespace td
