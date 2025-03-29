//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Td.h"

#include "td/telegram/AccountManager.h"
#include "td/telegram/AlarmManager.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/Application.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/AutosaveManager.h"
#include "td/telegram/BackgroundManager.h"
#include "td/telegram/BoostManager.h"
#include "td/telegram/BotInfoManager.h"
#include "td/telegram/BotRecommendationManager.h"
#include "td/telegram/BusinessConnectionManager.h"
#include "td/telegram/BusinessManager.h"
#include "td/telegram/CallbackQueriesManager.h"
#include "td/telegram/CallManager.h"
#include "td/telegram/ChannelRecommendationManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/CommonDialogManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/ConnectionStateManager.h"
#include "td/telegram/CountryInfoManager.h"
#include "td/telegram/DeviceTokenManager.h"
#include "td/telegram/DialogActionManager.h"
#include "td/telegram/DialogFilterManager.h"
#include "td/telegram/DialogInviteLinkManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/DownloadManager.h"
#include "td/telegram/DownloadManagerCallback.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/GameManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/HashtagHints.h"
#include "td/telegram/InlineMessageManager.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/MessageImportManager.h"
#include "td/telegram/MessageQueryManager.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetStatsManager.h"
#include "td/telegram/net/Proxy.h"
#include "td/telegram/net/TempAuthKeyWatchdog.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/NotificationSettingsManager.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/PeopleNearbyManager.h"
#include "td/telegram/PhoneNumberManager.h"
#include "td/telegram/PhotoSizeSource.h"
#include "td/telegram/PollManager.h"
#include "td/telegram/PrivacyManager.h"
#include "td/telegram/PromoDataManager.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/ReferralProgramManager.h"
#include "td/telegram/RequestActor.h"
#include "td/telegram/Requests.h"
#include "td/telegram/SavedMessagesManager.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/SecureManager.h"
#include "td/telegram/SponsoredMessageManager.h"
#include "td/telegram/StarGiftManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/StatisticsManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StorageManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/SynchronousRequests.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/TermsOfServiceManager.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/TimeZoneManager.h"
#include "td/telegram/TopDialogManager.h"
#include "td/telegram/TranscriptionManager.h"
#include "td/telegram/TranslationManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VideosManager.h"
#include "td/telegram/VoiceNotesManager.h"
#include "td/telegram/WebAppManager.h"
#include "td/telegram/WebPagesManager.h"

#include "td/db/binlog/BinlogEvent.h"

#include "td/actor/actor.h"

#include "td/utils/misc.h"
#include "td/utils/port/uname.h"
#include "td/utils/Timer.h"

namespace td {

int VERBOSITY_NAME(td_init) = VERBOSITY_NAME(DEBUG) + 3;
int VERBOSITY_NAME(td_requests) = VERBOSITY_NAME(INFO);

void Td::ResultHandler::set_td(Td *td) {
  CHECK(td_ == nullptr);
  td_ = td;
}

void Td::ResultHandler::send_query(NetQueryPtr query) {
  CHECK(!is_query_sent_);
  is_query_sent_ = true;
  td_->add_handler(query->id(), shared_from_this());
  query->debug("Send to NetQueryDispatcher");
  G()->net_query_dispatcher().dispatch(std::move(query));
}

Td::Td(unique_ptr<TdCallback> callback, Options options)
    : callback_(std::move(callback)), td_options_(std::move(options)) {
  CHECK(callback_ != nullptr);
  LOG(INFO) << "Create Td with layer " << MTPROTO_LAYER << ", database version " << current_db_version()
            << " and version " << static_cast<int32>(Version::Next) - 1 << " on "
            << Scheduler::instance()->sched_count() << " threads";
}

Td::~Td() = default;

bool Td::ignore_background_updates() const {
  return can_ignore_background_updates_ && option_manager_->get_option_boolean("ignore_background_updates");
}

bool Td::is_authentication_request(int32 id) {
  switch (id) {
    case td_api::setTdlibParameters::ID:
    case td_api::getAuthorizationState::ID:
    case td_api::setAuthenticationPhoneNumber::ID:
    case td_api::sendAuthenticationFirebaseSms::ID:
    case td_api::reportAuthenticationCodeMissing::ID:
    case td_api::setAuthenticationEmailAddress::ID:
    case td_api::resendAuthenticationCode::ID:
    case td_api::checkAuthenticationEmailCode::ID:
    case td_api::checkAuthenticationCode::ID:
    case td_api::registerUser::ID:
    case td_api::requestQrCodeAuthentication::ID:
    case td_api::resetAuthenticationEmailAddress::ID:
    case td_api::checkAuthenticationPassword::ID:
    case td_api::requestAuthenticationPasswordRecovery::ID:
    case td_api::checkAuthenticationPasswordRecoveryCode::ID:
    case td_api::recoverAuthenticationPassword::ID:
    case td_api::deleteAccount::ID:
    case td_api::logOut::ID:
    case td_api::close::ID:
    case td_api::destroy::ID:
    case td_api::checkAuthenticationBotToken::ID:
      return true;
    default:
      return false;
  }
}

bool Td::is_preinitialization_request(int32 id) {
  switch (id) {
    case td_api::getCurrentState::ID:
    case td_api::setAlarm::ID:
    case td_api::testUseUpdate::ID:
    case td_api::testCallEmpty::ID:
    case td_api::testSquareInt::ID:
    case td_api::testCallString::ID:
    case td_api::testCallBytes::ID:
    case td_api::testCallVectorInt::ID:
    case td_api::testCallVectorIntObject::ID:
    case td_api::testCallVectorString::ID:
    case td_api::testCallVectorStringObject::ID:
    case td_api::testProxy::ID:
      return true;
    default:
      return false;
  }
}

bool Td::is_preauthentication_request(int32 id) {
  switch (id) {
    case td_api::getInternalLink::ID:
    case td_api::getInternalLinkType::ID:
    case td_api::getLocalizationTargetInfo::ID:
    case td_api::getLanguagePackInfo::ID:
    case td_api::getLanguagePackStrings::ID:
    case td_api::synchronizeLanguagePack::ID:
    case td_api::addCustomServerLanguagePack::ID:
    case td_api::setCustomLanguagePack::ID:
    case td_api::editCustomLanguagePackInfo::ID:
    case td_api::setCustomLanguagePackString::ID:
    case td_api::deleteLanguagePack::ID:
    case td_api::processPushNotification::ID:
    case td_api::getOption::ID:
    case td_api::setOption::ID:
    case td_api::getStorageStatistics::ID:
    case td_api::getStorageStatisticsFast::ID:
    case td_api::getDatabaseStatistics::ID:
    case td_api::setNetworkType::ID:
    case td_api::getNetworkStatistics::ID:
    case td_api::addNetworkStatistics::ID:
    case td_api::resetNetworkStatistics::ID:
    case td_api::setApplicationVerificationToken::ID:
    case td_api::getCountries::ID:
    case td_api::getCountryCode::ID:
    case td_api::getPhoneNumberInfo::ID:
    case td_api::getDeepLinkInfo::ID:
    case td_api::getApplicationConfig::ID:
    case td_api::saveApplicationLogEvent::ID:
    case td_api::addProxy::ID:
    case td_api::editProxy::ID:
    case td_api::enableProxy::ID:
    case td_api::disableProxy::ID:
    case td_api::removeProxy::ID:
    case td_api::getProxies::ID:
    case td_api::getProxyLink::ID:
    case td_api::pingProxy::ID:
    case td_api::testNetwork::ID:
      return true;
    default:
      return false;
  }
}

td_api::object_ptr<td_api::AuthorizationState> Td::get_fake_authorization_state_object() const {
  switch (state_) {
    case State::WaitParameters:
      return td_api::make_object<td_api::authorizationStateWaitTdlibParameters>();
    case State::Run:
      UNREACHABLE();
      return nullptr;
    case State::Close:
      if (close_flag_ == 5) {
        return td_api::make_object<td_api::authorizationStateClosed>();
      } else {
        return td_api::make_object<td_api::authorizationStateClosing>();
      }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

vector<td_api::object_ptr<td_api::Update>> Td::get_fake_current_state() const {
  CHECK(state_ != State::Run);
  vector<td_api::object_ptr<td_api::Update>> updates;
  OptionManager::get_common_state(updates);
  updates.push_back(td_api::make_object<td_api::updateAuthorizationState>(get_fake_authorization_state_object()));
  return updates;
}

void Td::request(uint64 id, tl_object_ptr<td_api::Function> function) {
  if (id == 0) {
    LOG(ERROR) << "Ignore request with ID == 0: " << to_string(function);
    return;
  }

  if (function == nullptr) {
    return callback_->on_error(id, make_error(400, "Request is empty"));
  }

  VLOG(td_requests) << "Receive request " << id << ": " << to_string(function);
  request_set_.emplace(id, function->get_id());
  if (SynchronousRequests::is_synchronous_request(function.get())) {
    // send response synchronously
    return send_result(id, static_request(std::move(function)));
  }

  run_request(id, std::move(function));
}

void Td::run_request(uint64 id, td_api::object_ptr<td_api::Function> function) {
  if (set_parameters_request_id_ > 0) {
    pending_set_parameters_requests_.emplace_back(id, std::move(function));
    return;
  }

  int32 function_id = function->get_id();
  if (state_ != State::Run) {
    switch (function_id) {
      case td_api::getAuthorizationState::ID:
        // send response synchronously to prevent "Request aborted"
        return send_result(id, get_fake_authorization_state_object());
      case td_api::getCurrentState::ID:
        // send response synchronously to prevent "Request aborted"
        return send_result(id, td_api::make_object<td_api::updates>(get_fake_current_state()));
      case td_api::close::ID:
        // need to send response before actual closing
        send_closure(actor_id(this), &Td::send_result, id, td_api::make_object<td_api::ok>());
        send_closure(actor_id(this), &Td::close);
        return;
      default:
        break;
    }
  }
  switch (state_) {
    case State::WaitParameters: {
      switch (function_id) {
        case td_api::setTdlibParameters::ID: {
          auto r_parameters = get_parameters(move_tl_object_as<td_api::setTdlibParameters>(function));
          if (r_parameters.is_error()) {
            return send_closure(actor_id(this), &Td::send_error, id, r_parameters.move_as_error());
          }
          auto parameters = r_parameters.move_as_ok();

          VLOG(td_init) << "Begin to open database";
          set_parameters_request_id_ = id;
          can_ignore_background_updates_ = !parameters.second.use_chat_info_database_ &&
                                           !parameters.second.use_message_database_ &&
                                           !parameters.first.use_secret_chats_;

          auto promise = PromiseCreator::lambda(
              [actor_id = actor_id(this), parameters = std::move(parameters.first),
               parent = create_reference()](Result<TdDb::OpenedDatabase> r_opened_database) mutable {
                send_closure(actor_id, &Td::init, std::move(parameters), std::move(r_opened_database));
              });
          auto use_sqlite_pmc = parameters.second.use_message_database_ || parameters.second.use_chat_info_database_ ||
                                parameters.second.use_file_database_;
          return TdDb::open(use_sqlite_pmc ? G()->get_database_scheduler_id() : G()->get_slow_net_scheduler_id(),
                            std::move(parameters.second), std::move(promise));
        }
        default:
          if (is_preinitialization_request(function_id)) {
            return requests_->run_request(id, std::move(function));
          }
          if (is_preauthentication_request(function_id)) {
            pending_preauthentication_requests_.emplace_back(id, std::move(function));
            return;
          }
          return send_error_impl(
              id, make_error(400, "Initialization parameters are needed: call setTdlibParameters first"));
      }
      UNREACHABLE();
    }
    case State::Close:
      return send_error_impl(id, make_error(destroy_flag_ ? 401 : 500,
                                            destroy_flag_ ? CSlice("Unauthorized") : CSlice("Request aborted")));
    case State::Run:
      if (!auth_manager_->is_authorized() && !is_preauthentication_request(function_id) &&
          !is_preinitialization_request(function_id) && !is_authentication_request(function_id)) {
        return send_error_impl(id, make_error(401, "Unauthorized"));
      }
      return requests_->run_request(id, std::move(function));
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::Object> Td::static_request(td_api::object_ptr<td_api::Function> function) {
  return SynchronousRequests::run_request(std::move(function));
}

void Td::add_handler(uint64 id, std::shared_ptr<ResultHandler> handler) {
  result_handlers_[id] = std::move(handler);
}

std::shared_ptr<Td::ResultHandler> Td::extract_handler(uint64 id) {
  auto it = result_handlers_.find(id);
  if (it == result_handlers_.end()) {
    return nullptr;
  }
  auto result = std::move(it->second);
  result_handlers_.erase(it);
  return result;
}

void Td::on_update(telegram_api::object_ptr<telegram_api::Updates> updates, uint64 auth_key_id) {
  if (close_flag_ > 1) {
    return;
  }

  if (updates == nullptr) {
    if (auth_manager_->is_bot()) {
      G()->net_query_dispatcher().update_mtproto_header();
    } else {
      // this could be a min-channel update
      updates_manager_->schedule_get_difference("failed to fetch updates");
    }
  } else {
    updates_manager_->on_update_from_auth_key_id(auth_key_id);
    updates_manager_->on_get_updates(std::move(updates), Promise<Unit>());
    if (auth_manager_->is_bot() && auth_manager_->is_authorized()) {
      online_manager_->set_is_bot_online(true);
    }
  }
}

void Td::on_result(NetQueryPtr query) {
  query->debug("Td: received from DcManager");
  VLOG(net_query) << "Receive result of " << query;
  if (close_flag_ > 1) {
    return;
  }

  auto handler = extract_handler(query->id());
  if (handler != nullptr) {
    CHECK(query->is_ready());
    if (query->is_ok()) {
      handler->on_result(query->move_as_ok());
    } else {
      handler->on_error(query->move_as_error());
    }
  } else {
    if (!query->is_ok() || query->ok_tl_constructor() != telegram_api::upload_file::ID) {
      LOG(WARNING) << query << " is ignored: no handlers found";
    }
    query->clear();
  }
}

void Td::start_up() {
  uint64 check_endianness = 0x0706050403020100;
  auto check_endianness_raw = reinterpret_cast<const unsigned char *>(&check_endianness);
  for (unsigned char c = 0; c < 8; c++) {
    auto symbol = check_endianness_raw[static_cast<size_t>(c)];
    LOG_IF(FATAL, symbol != c) << "TDLib requires little-endian platform";
  }

  requests_ = make_unique<Requests>(this);

  VLOG(td_init) << "Create Global";
  old_context_ = set_context(std::make_shared<Global>());
  G()->set_net_query_stats(td_options_.net_query_stats);
  inc_request_actor_refcnt();  // guard
  inc_actor_refcnt();          // guard

  alarm_manager_ = create_actor<AlarmManager>("AlarmManager", create_reference());

  CHECK(state_ == State::WaitParameters);
  for (auto &update : get_fake_current_state()) {
    send_update(std::move(update));
  }
}

void Td::tear_down() {
  LOG_CHECK(close_flag_ == 5) << close_flag_;
}

void Td::hangup_shared() {
  auto token = get_link_token();
  auto type = Container<int>::type_from_id(token);

  if (type == RequestActorIdType) {
    request_actors_.erase(token);
    dec_request_actor_refcnt();
  } else if (type == ActorIdType) {
    dec_actor_refcnt();
  } else {
    LOG(FATAL) << "Unknown hangup_shared of type " << type;
  }
}

void Td::hangup() {
  LOG(INFO) << "Receive Td::hangup";
  close();
  dec_stop_cnt();
}

ActorShared<Td> Td::create_reference() {
  inc_actor_refcnt();
  return actor_shared(this, ActorIdType);
}

void Td::inc_actor_refcnt() {
  actor_refcnt_++;
}

void Td::dec_actor_refcnt() {
  actor_refcnt_--;
  if (actor_refcnt_ < 3) {
    LOG(DEBUG) << "Decrease reference count to " << actor_refcnt_;
  }
  if (actor_refcnt_ == 0) {
    if (close_flag_ == 2) {
      create_reference();
      close_flag_ = 3;
    } else if (close_flag_ == 3) {
      LOG(INFO) << "All actors were closed";
      Timer timer;
      auto reset_manager = [&timer](auto &manager, Slice name) {
        manager.reset();
        LOG(DEBUG) << name << " was cleared" << timer;
      };
      reset_manager(account_manager_, "AccountManager");
      reset_manager(animations_manager_, "AnimationsManager");
      reset_manager(attach_menu_manager_, "AttachMenuManager");
      reset_manager(audios_manager_, "AudiosManager");
      reset_manager(auth_manager_, "AuthManager");
      reset_manager(autosave_manager_, "AutosaveManager");
      reset_manager(background_manager_, "BackgroundManager");
      reset_manager(boost_manager_, "BoostManager");
      reset_manager(bot_info_manager_, "BotInfoManager");
      reset_manager(bot_recommendation_manager_, "BotRecommendationManager");
      reset_manager(business_connection_manager_, "BusinessConnectionManager");
      reset_manager(business_manager_, "BusinessManager");
      reset_manager(call_manager_, "CallManager");
      reset_manager(callback_queries_manager_, "CallbackQueriesManager");
      reset_manager(channel_recommendation_manager_, "ChannelRecommendationManager");
      reset_manager(chat_manager_, "ChatManager");
      reset_manager(common_dialog_manager_, "CommonDialogManager");
      reset_manager(connection_state_manager_, "ConnectionStateManager");
      reset_manager(country_info_manager_, "CountryInfoManager");
      reset_manager(dialog_action_manager_, "DialogActionManager");
      reset_manager(dialog_filter_manager_, "DialogFilterManager");
      reset_manager(dialog_invite_link_manager_, "DialogInviteLinkManager");
      reset_manager(dialog_manager_, "DialogManager");
      reset_manager(dialog_participant_manager_, "DialogParticipantManager");
      reset_manager(documents_manager_, "DocumentsManager");
      reset_manager(download_manager_, "DownloadManager");
      reset_manager(file_manager_, "FileManager");
      reset_manager(file_reference_manager_, "FileReferenceManager");
      reset_manager(forum_topic_manager_, "ForumTopicManager");
      reset_manager(game_manager_, "GameManager");
      reset_manager(group_call_manager_, "GroupCallManager");
      reset_manager(inline_message_manager_, "InlineMessageManager");
      reset_manager(inline_queries_manager_, "InlineQueriesManager");
      reset_manager(link_manager_, "LinkManager");
      reset_manager(message_import_manager_, "MessageImportManager");
      reset_manager(message_query_manager_, "MessageQueryManager");
      reset_manager(messages_manager_, "MessagesManager");
      reset_manager(notification_manager_, "NotificationManager");
      reset_manager(notification_settings_manager_, "NotificationSettingsManager");
      reset_manager(online_manager_, "OnlineManager");
      reset_manager(people_nearby_manager_, "PeopleNearbyManager");
      reset_manager(phone_number_manager_, "PhoneNumberManager");
      reset_manager(poll_manager_, "PollManager");
      reset_manager(privacy_manager_, "PrivacyManager");
      reset_manager(promo_data_manager_, "PromoDataManager");
      reset_manager(quick_reply_manager_, "QuickReplyManager");
      reset_manager(reaction_manager_, "ReactionManager");
      reset_manager(referral_program_manager_, "ReferralProgramManager");
      reset_manager(saved_messages_manager_, "SavedMessagesManager");
      reset_manager(sponsored_message_manager_, "SponsoredMessageManager");
      reset_manager(star_gift_manager_, "StarGiftManager");
      reset_manager(star_manager_, "StarManager");
      reset_manager(statistics_manager_, "StatisticsManager");
      reset_manager(stickers_manager_, "StickersManager");
      reset_manager(story_manager_, "StoryManager");
      reset_manager(suggested_action_manager_, "SuggestedActionManager");
      reset_manager(terms_of_service_manager_, "TermsOfServiceManager");
      reset_manager(theme_manager_, "ThemeManager");
      reset_manager(time_zone_manager_, "TimeZoneManager");
      reset_manager(top_dialog_manager_, "TopDialogManager");
      reset_manager(transcription_manager_, "TranscriptionManager");
      reset_manager(translation_manager_, "TranslationManager");
      reset_manager(updates_manager_, "UpdatesManager");
      reset_manager(user_manager_, "UserManager");
      reset_manager(video_notes_manager_, "VideoNotesManager");
      reset_manager(videos_manager_, "VideosManager");
      reset_manager(voice_notes_manager_, "VoiceNotesManager");
      reset_manager(web_app_manager_, "WebAppManager");
      reset_manager(web_pages_manager_, "WebPagesManager");

      G()->set_option_manager(nullptr);
      option_manager_.reset();
      LOG(DEBUG) << "OptionManager was cleared" << timer;

      G()->close_all(destroy_flag_,
                     PromiseCreator::lambda([actor_id = create_reference()](Unit) mutable { actor_id.reset(); }));

      // NetQueryDispatcher will be closed automatically
      close_flag_ = 4;
    } else if (close_flag_ == 4) {
      on_closed();
    } else {
      UNREACHABLE();
    }
  }
}

void Td::on_closed() {
  close_flag_ = 5;
  send_update(
      td_api::make_object<td_api::updateAuthorizationState>(td_api::make_object<td_api::authorizationStateClosed>()));
  dec_stop_cnt();
}

void Td::dec_stop_cnt() {
  stop_cnt_--;
  if (stop_cnt_ == 0) {
    LOG(INFO) << "Stop Td";
    set_context(std::move(old_context_));
    stop();
  }
}

void Td::inc_request_actor_refcnt() {
  request_actor_refcnt_++;
}

void Td::dec_request_actor_refcnt() {
  request_actor_refcnt_--;
  LOG(DEBUG) << "Decrease request actor count to " << request_actor_refcnt_;
  if (request_actor_refcnt_ == 0) {
    clear();
    dec_actor_refcnt();  // remove guard
  }
}

void Td::clear_requests() {
  while (!request_set_.empty()) {
    uint64 id = request_set_.begin()->first;
    if (destroy_flag_) {
      send_error_impl(id, make_error(401, "Unauthorized"));
    } else {
      send_error_impl(id, make_error(500, "Request aborted"));
    }
  }
}

void Td::clear() {
  if (close_flag_ >= 2) {
    return;
  }

  LOG(INFO) << "Clear Td";
  close_flag_ = 2;

  Timer timer;
  if (!auth_manager_->is_bot()) {
    if (destroy_flag_) {
      notification_manager_->destroy_all_notifications();
    } else {
      notification_manager_->flush_all_notifications();
    }
  }

  G()->net_query_creator().stop_check();
  result_handlers_.clear();
  LOG(DEBUG) << "Handlers were cleared" << timer;
  G()->net_query_dispatcher().stop();
  LOG(DEBUG) << "NetQueryDispatcher was stopped" << timer;
  state_manager_.reset();
  LOG(DEBUG) << "StateManager was cleared" << timer;
  clear_requests();

  auto reset_actor = [&timer](ActorOwn<Actor> actor) {
    if (!actor.empty()) {
      LOG(DEBUG) << "Start clearing " << actor.get().get_name() << timer;
    }
  };

  // close all pure actors
  reset_actor(ActorOwn<Actor>(std::move(alarm_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(cashtag_search_hints_)));
  reset_actor(ActorOwn<Actor>(std::move(config_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(device_token_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(hashtag_hints_)));
  reset_actor(ActorOwn<Actor>(std::move(hashtag_search_hints_)));
  reset_actor(ActorOwn<Actor>(std::move(language_pack_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(net_stats_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(password_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(secure_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(secret_chats_manager_)));
  reset_actor(ActorOwn<Actor>(std::move(storage_manager_)));

  G()->set_connection_creator(ActorOwn<ConnectionCreator>());
  LOG(DEBUG) << "ConnectionCreator was cleared" << timer;
  G()->set_temp_auth_key_watchdog(ActorOwn<TempAuthKeyWatchdog>());
  LOG(DEBUG) << "TempAuthKeyWatchdog was cleared" << timer;

  // clear actors which are unique pointers
  reset_actor(ActorOwn<Actor>(std::move(account_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(animations_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(attach_menu_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(auth_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(autosave_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(background_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(boost_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(bot_info_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(bot_recommendation_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(business_connection_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(business_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(call_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(channel_recommendation_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(chat_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(common_dialog_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(connection_state_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(country_info_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(dialog_action_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(dialog_filter_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(dialog_invite_link_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(dialog_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(dialog_participant_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(download_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(file_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(file_reference_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(forum_topic_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(game_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(group_call_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(inline_message_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(inline_queries_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(link_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(message_import_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(message_query_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(messages_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(notification_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(notification_settings_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(online_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(people_nearby_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(phone_number_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(poll_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(privacy_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(promo_data_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(quick_reply_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(reaction_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(referral_program_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(saved_messages_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(sponsored_message_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(star_gift_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(star_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(statistics_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(stickers_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(story_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(suggested_action_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(terms_of_service_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(theme_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(time_zone_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(top_dialog_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(transcription_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(translation_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(updates_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(user_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(video_notes_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(voice_notes_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(web_app_manager_actor_)));
  reset_actor(ActorOwn<Actor>(std::move(web_pages_manager_actor_)));
  LOG(DEBUG) << "All actors were cleared" << timer;
}

void Td::close() {
  close_impl(false);
}

void Td::destroy() {
  close_impl(true);
}

void Td::close_impl(bool destroy_flag) {
  destroy_flag_ |= destroy_flag;
  if (close_flag_) {
    return;
  }

  LOG(WARNING) << (destroy_flag ? "Destroy" : "Close") << " Td in state " << static_cast<int32>(state_);
  if (state_ == State::WaitParameters) {
    state_ = State::Close;
    close_flag_ = 4;
    G()->set_close_flag();
    clear_requests();
    alarm_manager_.reset();
    send_update(td_api::make_object<td_api::updateAuthorizationState>(
        td_api::make_object<td_api::authorizationStateClosing>()));

    request_actors_.clear();
    return send_closure_later(actor_id(this), &Td::dec_request_actor_refcnt);  // remove guard
  }

  state_ = State::Close;
  close_flag_ = 1;
  G()->set_close_flag();
  send_closure(auth_manager_actor_, &AuthManager::on_closing, destroy_flag);
  updates_manager_->timeout_expired();  // save PTS and QTS

  // wait till all request_actors will stop
  request_actors_.clear();
  G()->td_db()->flush_all();
  send_closure_later(actor_id(this), &Td::dec_request_actor_refcnt);  // remove guard
}

template <class T>
void Td::complete_pending_preauthentication_requests(const T &func) {
  for (auto &request : pending_preauthentication_requests_) {
    if (request.second != nullptr && func(request.second->get_id())) {
      requests_->run_request(request.first, std::move(request.second));
      request.second = nullptr;
    }
  }
}

void Td::finish_set_parameters() {
  CHECK(set_parameters_request_id_ != 0);
  set_parameters_request_id_ = 0;

  if (pending_set_parameters_requests_.empty()) {
    return;
  }

  VLOG(td_init) << "Continue to execute " << pending_set_parameters_requests_.size() << " pending requests";
  auto requests = std::move(pending_set_parameters_requests_);
  for (auto &request : requests) {
    run_request(request.first, std::move(request.second));
  }
  CHECK(pending_set_parameters_requests_.size() < requests.size());
}

void Td::init(Parameters parameters, Result<TdDb::OpenedDatabase> r_opened_database) {
  CHECK(set_parameters_request_id_ != 0);
  if (r_opened_database.is_error()) {
    LOG(WARNING) << "Failed to open database: " << r_opened_database.error();
    send_closure(actor_id(this), &Td::send_error, set_parameters_request_id_, r_opened_database.move_as_error());
    return finish_set_parameters();
  }
  auto events = r_opened_database.move_as_ok();

  VLOG(td_init) << "Successfully inited database";

  if (state_ == State::Close) {
    LOG(INFO) << "Close asynchronously opened database";
    auto database_ptr = events.database.get();
    auto promise = PromiseCreator::lambda([database = std::move(events.database)](Unit) {
      // destroy the database after closing
    });
    database_ptr->close(
        database_ptr->use_file_database() ? G()->get_database_scheduler_id() : G()->get_slow_net_scheduler_id(),
        destroy_flag_, std::move(promise));
    return finish_set_parameters();
  }

  G()->init(actor_id(this), std::move(events.database)).ensure();

  init_options_and_network();

  // we need to process td_api::getOption along with td_api::setOption for consistency
  // we need to process td_api::setOption before managers and MTProto header are created,
  // because their initialization may be affected by the options
  complete_pending_preauthentication_requests([](int32 id) {
    switch (id) {
      case td_api::getOption::ID:
      case td_api::setOption::ID:
        return true;
      default:
        return false;
    }
  });

  if (!option_manager_->get_option_boolean("disable_network_statistics")) {
    net_stats_manager_ = create_actor<NetStatsManager>("NetStatsManager", create_reference());

    // How else could I let two actor know about each other, without quite complex async logic?
    auto net_stats_manager_ptr = net_stats_manager_.get_actor_unsafe();
    net_stats_manager_ptr->init();
    G()->connection_creator().get_actor_unsafe()->set_net_stats_callback(
        net_stats_manager_ptr->get_common_stats_callback(), net_stats_manager_ptr->get_media_stats_callback());
    G()->set_net_stats_file_callbacks(net_stats_manager_ptr->get_file_stats_callbacks());
  }

  complete_pending_preauthentication_requests([](int32 id) {
    switch (id) {
      case td_api::getNetworkStatistics::ID:
      case td_api::addNetworkStatistics::ID:
      case td_api::resetNetworkStatistics::ID:
        return true;
      default:
        return false;
    }
  });

  if (events.since_last_open >= 3600) {
    auto old_since_last_open = option_manager_->get_option_integer("since_last_open");
    if (events.since_last_open > old_since_last_open) {
      option_manager_->set_option_integer("since_last_open", events.since_last_open);
    }
  }

  options_.language_pack = option_manager_->get_option_string("localization_target");
  options_.language_code = option_manager_->get_option_string("language_pack_id");
  options_.parameters = option_manager_->get_option_string("connection_parameters");
  options_.tz_offset = static_cast<int32>(option_manager_->get_option_integer("utc_time_offset"));
  options_.is_emulator = option_manager_->get_option_boolean("is_emulator");
  // options_.proxy = Proxy();
  G()->set_mtproto_header(make_unique<MtprotoHeader>(options_));
  G()->set_store_all_files_in_files_directory(
      option_manager_->get_option_boolean("store_all_files_in_files_directory"));

  VLOG(td_init) << "Create NetQueryDispatcher";
  auto net_query_dispatcher = make_unique<NetQueryDispatcher>([&] { return create_reference(); });
  G()->set_net_query_dispatcher(std::move(net_query_dispatcher));

  complete_pending_preauthentication_requests([](int32 id) {
    // pingProxy uses NetQueryDispatcher to get main_dc_id, so must be called after NetQueryDispatcher is created
    return id == td_api::pingProxy::ID;
  });

  VLOG(td_init) << "Create AuthManager";
  auth_manager_ = td::make_unique<AuthManager>(parameters.api_id_, parameters.api_hash_, create_reference());
  auth_manager_actor_ = register_actor("AuthManager", auth_manager_.get());
  G()->set_auth_manager(auth_manager_actor_.get());

  init_file_manager();

  init_non_actor_managers();

  init_managers();

  init_pure_actor_managers();

  secret_chats_manager_ =
      create_actor<SecretChatsManager>("SecretChatsManager", create_reference(), parameters.use_secret_chats_);
  G()->set_secret_chats_manager(secret_chats_manager_.get());

  storage_manager_ = create_actor<StorageManager>("StorageManager", create_reference(), G()->get_gc_scheduler_id());
  G()->set_storage_manager(storage_manager_.get());

  option_manager_->on_td_inited();

  process_binlog_events(std::move(events));

  VLOG(td_init) << "Ping datacenter";
  if (!auth_manager_->is_authorized()) {
    country_info_manager_->get_current_country_code(Promise<string>());
  } else {
    updates_manager_->get_difference("init");
  }

  complete_pending_preauthentication_requests([](int32 id) { return true; });

  VLOG(td_init) << "Finish initialization";

  state_ = State::Run;

  send_closure(actor_id(this), &Td::send_result, set_parameters_request_id_, td_api::make_object<td_api::ok>());
  return finish_set_parameters();
}

void Td::process_binlog_events(TdDb::OpenedDatabase &&events) {
  VLOG(td_init) << "Send binlog events";
  for (auto &event : events.user_events) {
    user_manager_->on_binlog_user_event(std::move(event));
  }

  for (auto &event : events.channel_events) {
    chat_manager_->on_binlog_channel_event(std::move(event));
  }

  // chats may contain links to channels, so should be inited after
  for (auto &event : events.chat_events) {
    chat_manager_->on_binlog_chat_event(std::move(event));
  }

  for (auto &event : events.secret_chat_events) {
    user_manager_->on_binlog_secret_chat_event(std::move(event));
  }

  for (auto &event : events.web_page_events) {
    web_pages_manager_->on_binlog_web_page_event(std::move(event));
  }

  for (auto &event : events.save_app_log_events) {
    on_save_app_log_binlog_event(this, std::move(event));
  }

  // Send binlog events to managers
  //
  // 1. Actors must receive all binlog events before other queries.
  //
  // -- All actors have one "entry point". So there is only one way to send query to them. So all queries are ordered
  // for each Actor.
  //
  // 2. An actor must not make some decisions before all binlog events are processed.
  // For example, SecretChatActor must not send RequestKey, before it receives log event with RequestKey and understands
  // that RequestKey was already sent.
  //
  // 3. During replay of binlog some queries may be sent to other actors. They shouldn't process such events before all
  // their binlog events are processed. So actor may receive some old queries. It must be in its actual state in
  // order to handle them properly.
  //
  // -- Use send_closure_later, so actors don't even start process binlog events, before all binlog events are sent

  for (auto &event : events.to_secret_chats_manager) {
    send_closure_later(secret_chats_manager_, &SecretChatsManager::replay_binlog_event, std::move(event));
  }

  send_closure_later(account_manager_actor_, &AccountManager::on_binlog_events, std::move(events.to_account_manager));

  send_closure_later(poll_manager_actor_, &PollManager::on_binlog_events, std::move(events.to_poll_manager));

  send_closure_later(dialog_manager_actor_, &DialogManager::on_binlog_events, std::move(events.to_dialog_manager));

  send_closure_later(message_query_manager_actor_, &MessageQueryManager::on_binlog_events,
                     std::move(events.to_message_query_manager));

  send_closure_later(messages_manager_actor_, &MessagesManager::on_binlog_events,
                     std::move(events.to_messages_manager));

  send_closure_later(story_manager_actor_, &StoryManager::on_binlog_events, std::move(events.to_story_manager));

  send_closure_later(notification_manager_actor_, &NotificationManager::on_binlog_events,
                     std::move(events.to_notification_manager));

  send_closure_later(notification_settings_manager_actor_, &NotificationSettingsManager::on_binlog_events,
                     std::move(events.to_notification_settings_manager));

  send_closure(secret_chats_manager_, &SecretChatsManager::binlog_replay_finish);
}

void Td::init_options_and_network() {
  VLOG(td_init) << "Create StateManager";
  state_manager_ = create_actor<StateManager>("State manager", create_reference());
  G()->set_state_manager(state_manager_.get());

  VLOG(td_init) << "Create OptionManager";
  option_manager_ = make_unique<OptionManager>(this);
  G()->set_option_manager(option_manager_.get());

  VLOG(td_init) << "Create ConnectionCreator";
  G()->set_connection_creator(create_actor<ConnectionCreator>("ConnectionCreator", create_reference()));

  complete_pending_preauthentication_requests([](int32 id) {
    switch (id) {
      case td_api::setNetworkType::ID:
      case td_api::addProxy::ID:
      case td_api::editProxy::ID:
      case td_api::enableProxy::ID:
      case td_api::disableProxy::ID:
      case td_api::removeProxy::ID:
      case td_api::getProxies::ID:
      case td_api::getProxyLink::ID:
        return true;
      default:
        return false;
    }
  });

  VLOG(td_init) << "Create TempAuthKeyWatchdog";
  G()->set_temp_auth_key_watchdog(create_actor<TempAuthKeyWatchdog>("TempAuthKeyWatchdog", create_reference()));

  VLOG(td_init) << "Create ConfigManager";
  config_manager_ = create_actor<ConfigManager>("ConfigManager", create_reference());
  G()->set_config_manager(config_manager_.get());

  VLOG(td_init) << "Create OnlineManager";
  online_manager_ = make_unique<OnlineManager>(this, create_reference());
  online_manager_actor_ = register_actor("OnlineManager", online_manager_.get());
  G()->set_online_manager(online_manager_actor_.get());
}

void Td::init_file_manager() {
  VLOG(td_init) << "Create FileManager";
  class FileManagerContext final : public FileManager::Context {
   public:
    explicit FileManagerContext(Td *td) : td_(td) {
    }

    bool need_notify_on_new_files() final {
      return !td_->auth_manager_->is_bot();
    }

    void on_new_file(int64 size, int64 real_size, int32 cnt) final {
      send_closure(G()->storage_manager(), &StorageManager::on_new_file, size, real_size, cnt);
    }

    void on_file_updated(FileId file_id) final {
      send_closure(G()->td(), &Td::send_update,
                   make_tl_object<td_api::updateFile>(td_->file_manager_->get_file_object(file_id)));
    }

    bool add_file_source(FileId file_id, FileSourceId file_source_id, const char *source) final {
      return td_->file_reference_manager_->add_file_source(file_id, file_source_id, source);
    }

    bool remove_file_source(FileId file_id, FileSourceId file_source_id, const char *source) final {
      return td_->file_reference_manager_->remove_file_source(file_id, file_source_id, source);
    }

    void on_merge_files(FileId to_file_id, FileId from_file_id) final {
      td_->file_reference_manager_->merge(to_file_id, from_file_id);
    }

    vector<FileSourceId> get_some_file_sources(FileId file_id) final {
      return td_->file_reference_manager_->get_some_file_sources(file_id);
    }

    void repair_file_reference(FileId file_id, Promise<Unit> promise) final {
      send_closure(G()->file_reference_manager(), &FileReferenceManager::repair_file_reference, file_id,
                   std::move(promise));
    }

    void reload_photo(PhotoSizeSource source, Promise<Unit> promise) final {
      FileReferenceManager::reload_photo(std::move(source), std::move(promise));
    }

    bool keep_exact_remote_location() final {
      return !td_->auth_manager_->is_bot();
    }

    ActorShared<> create_reference() final {
      return td_->create_reference();
    }

   private:
    Td *td_;
  };

  file_manager_ = make_unique<FileManager>(make_unique<FileManagerContext>(this));
  file_manager_actor_ = register_actor("FileManager", file_manager_.get());
  file_manager_->init_actor();
  G()->set_file_manager(file_manager_actor_.get());

  file_reference_manager_ = make_unique<FileReferenceManager>(create_reference());
  file_reference_manager_actor_ = register_actor("FileReferenceManager", file_reference_manager_.get());
  G()->set_file_reference_manager(file_reference_manager_actor_.get());
}

void Td::init_non_actor_managers() {
  VLOG(td_init) << "Create Managers";
  audios_manager_ = make_unique<AudiosManager>(this);
  callback_queries_manager_ = make_unique<CallbackQueriesManager>(this);
  documents_manager_ = make_unique<DocumentsManager>(this);
  videos_manager_ = make_unique<VideosManager>(this);
}

void Td::init_managers() {
  account_manager_ = make_unique<AccountManager>(this, create_reference());
  account_manager_actor_ = register_actor("AccountManager", account_manager_.get());
  G()->set_account_manager(account_manager_actor_.get());
  animations_manager_ = make_unique<AnimationsManager>(this, create_reference());
  animations_manager_actor_ = register_actor("AnimationsManager", animations_manager_.get());
  G()->set_animations_manager(animations_manager_actor_.get());
  attach_menu_manager_ = make_unique<AttachMenuManager>(this, create_reference());
  attach_menu_manager_actor_ = register_actor("AttachMenuManager", attach_menu_manager_.get());
  G()->set_attach_menu_manager(attach_menu_manager_actor_.get());
  autosave_manager_ = make_unique<AutosaveManager>(this, create_reference());
  autosave_manager_actor_ = register_actor("AutosaveManager", autosave_manager_.get());
  G()->set_autosave_manager(autosave_manager_actor_.get());
  background_manager_ = make_unique<BackgroundManager>(this, create_reference());
  background_manager_actor_ = register_actor("BackgroundManager", background_manager_.get());
  G()->set_background_manager(background_manager_actor_.get());
  boost_manager_ = make_unique<BoostManager>(this, create_reference());
  boost_manager_actor_ = register_actor("BoostManager", boost_manager_.get());
  G()->set_boost_manager(boost_manager_actor_.get());
  bot_info_manager_ = make_unique<BotInfoManager>(this, create_reference());
  bot_info_manager_actor_ = register_actor("BotInfoManager", bot_info_manager_.get());
  G()->set_bot_info_manager(bot_info_manager_actor_.get());
  bot_recommendation_manager_ = make_unique<BotRecommendationManager>(this, create_reference());
  bot_recommendation_manager_actor_ = register_actor("BotRecommendationManager", bot_recommendation_manager_.get());
  business_connection_manager_ = make_unique<BusinessConnectionManager>(this, create_reference());
  business_connection_manager_actor_ = register_actor("BusinessConnectionManager", business_connection_manager_.get());
  G()->set_business_connection_manager(business_connection_manager_actor_.get());
  business_manager_ = make_unique<BusinessManager>(this, create_reference());
  business_manager_actor_ = register_actor("BusinessManager", business_manager_.get());
  G()->set_business_manager(business_manager_actor_.get());
  call_manager_ = make_unique<CallManager>(this, create_reference());
  call_manager_actor_ = register_actor("CallManager", call_manager_.get());
  G()->set_call_manager(call_manager_actor_.get());
  channel_recommendation_manager_ = make_unique<ChannelRecommendationManager>(this, create_reference());
  channel_recommendation_manager_actor_ =
      register_actor("ChannelRecommendationManager", channel_recommendation_manager_.get());
  chat_manager_ = make_unique<ChatManager>(this, create_reference());
  chat_manager_actor_ = register_actor("ChatManager", chat_manager_.get());
  G()->set_chat_manager(chat_manager_actor_.get());
  common_dialog_manager_ = make_unique<CommonDialogManager>(this, create_reference());
  common_dialog_manager_actor_ = register_actor("CommonDialogManager", common_dialog_manager_.get());
  connection_state_manager_ = make_unique<ConnectionStateManager>(this, create_reference());
  connection_state_manager_actor_ = register_actor("ConnectionStateManager", connection_state_manager_.get());
  country_info_manager_ = make_unique<CountryInfoManager>(this, create_reference());
  country_info_manager_actor_ = register_actor("CountryInfoManager", country_info_manager_.get());
  dialog_action_manager_ = make_unique<DialogActionManager>(this, create_reference());
  dialog_action_manager_actor_ = register_actor("DialogActionManager", dialog_action_manager_.get());
  G()->set_dialog_action_manager(dialog_action_manager_actor_.get());
  dialog_filter_manager_ = make_unique<DialogFilterManager>(this, create_reference());
  dialog_filter_manager_actor_ = register_actor("DialogFilterManager", dialog_filter_manager_.get());
  G()->set_dialog_filter_manager(dialog_filter_manager_actor_.get());
  dialog_invite_link_manager_ = make_unique<DialogInviteLinkManager>(this, create_reference());
  dialog_invite_link_manager_actor_ = register_actor("DialogInviteLinkManager", dialog_invite_link_manager_.get());
  G()->set_dialog_invite_link_manager(dialog_invite_link_manager_actor_.get());
  dialog_manager_ = make_unique<DialogManager>(this, create_reference());
  dialog_manager_actor_ = register_actor("DialogManager", dialog_manager_.get());
  G()->set_dialog_manager(dialog_manager_actor_.get());
  dialog_participant_manager_ = make_unique<DialogParticipantManager>(this, create_reference());
  dialog_participant_manager_actor_ = register_actor("DialogParticipantManager", dialog_participant_manager_.get());
  G()->set_dialog_participant_manager(dialog_participant_manager_actor_.get());
  download_manager_ = DownloadManager::create(td::make_unique<DownloadManagerCallback>(this, create_reference()));
  download_manager_actor_ = register_actor("DownloadManager", download_manager_.get());
  G()->set_download_manager(download_manager_actor_.get());
  forum_topic_manager_ = make_unique<ForumTopicManager>(this, create_reference());
  forum_topic_manager_actor_ = register_actor("ForumTopicManager", forum_topic_manager_.get());
  G()->set_forum_topic_manager(forum_topic_manager_actor_.get());
  game_manager_ = make_unique<GameManager>(this, create_reference());
  game_manager_actor_ = register_actor("GameManager", game_manager_.get());
  G()->set_game_manager(game_manager_actor_.get());
  group_call_manager_ = make_unique<GroupCallManager>(this, create_reference());
  group_call_manager_actor_ = register_actor("GroupCallManager", group_call_manager_.get());
  G()->set_group_call_manager(group_call_manager_actor_.get());
  inline_message_manager_ = make_unique<InlineMessageManager>(this, create_reference());
  inline_message_manager_actor_ = register_actor("InlineMessageManager", inline_message_manager_.get());
  G()->set_inline_message_manager(inline_message_manager_actor_.get());
  inline_queries_manager_ = make_unique<InlineQueriesManager>(this, create_reference());
  inline_queries_manager_actor_ = register_actor("InlineQueriesManager", inline_queries_manager_.get());
  link_manager_ = make_unique<LinkManager>(this, create_reference());
  link_manager_actor_ = register_actor("LinkManager", link_manager_.get());
  G()->set_link_manager(link_manager_actor_.get());
  message_import_manager_ = make_unique<MessageImportManager>(this, create_reference());
  message_import_manager_actor_ = register_actor("MessageImportManager", message_import_manager_.get());
  G()->set_message_import_manager(message_import_manager_actor_.get());
  message_query_manager_ = make_unique<MessageQueryManager>(this, create_reference());
  message_query_manager_actor_ = register_actor("MessageQueryManager", message_query_manager_.get());
  G()->set_message_query_manager(message_query_manager_actor_.get());
  messages_manager_ = make_unique<MessagesManager>(this, create_reference());
  messages_manager_actor_ = register_actor("MessagesManager", messages_manager_.get());
  G()->set_messages_manager(messages_manager_actor_.get());
  notification_manager_ = make_unique<NotificationManager>(this, create_reference());
  notification_manager_actor_ = register_actor("NotificationManager", notification_manager_.get());
  G()->set_notification_manager(notification_manager_actor_.get());
  notification_settings_manager_ = make_unique<NotificationSettingsManager>(this, create_reference());
  notification_settings_manager_actor_ =
      register_actor("NotificationSettingsManager", notification_settings_manager_.get());
  G()->set_notification_settings_manager(notification_settings_manager_actor_.get());
  people_nearby_manager_ = make_unique<PeopleNearbyManager>(this, create_reference());
  people_nearby_manager_actor_ = register_actor("PeopleNearbyManager", people_nearby_manager_.get());
  G()->set_people_nearby_manager(people_nearby_manager_actor_.get());
  phone_number_manager_ = make_unique<PhoneNumberManager>(this, create_reference());
  phone_number_manager_actor_ = register_actor("PhoneNumberManager", phone_number_manager_.get());
  poll_manager_ = make_unique<PollManager>(this, create_reference());
  poll_manager_actor_ = register_actor("PollManager", poll_manager_.get());
  privacy_manager_ = make_unique<PrivacyManager>(this, create_reference());
  privacy_manager_actor_ = register_actor("PrivacyManager", privacy_manager_.get());
  promo_data_manager_ = make_unique<PromoDataManager>(this, create_reference());
  promo_data_manager_actor_ = register_actor("PromoDataManager", promo_data_manager_.get());
  G()->set_promo_data_manager(promo_data_manager_actor_.get());
  quick_reply_manager_ = make_unique<QuickReplyManager>(this, create_reference());
  quick_reply_manager_actor_ = register_actor("QuickReplyManager", quick_reply_manager_.get());
  G()->set_quick_reply_manager(quick_reply_manager_actor_.get());
  reaction_manager_ = make_unique<ReactionManager>(this, create_reference());
  reaction_manager_actor_ = register_actor("ReactionManager", reaction_manager_.get());
  G()->set_reaction_manager(reaction_manager_actor_.get());
  referral_program_manager_ = make_unique<ReferralProgramManager>(this, create_reference());
  referral_program_manager_actor_ = register_actor("ReferralProgramManager", referral_program_manager_.get());
  G()->set_referral_program_manager(referral_program_manager_actor_.get());
  saved_messages_manager_ = make_unique<SavedMessagesManager>(this, create_reference());
  saved_messages_manager_actor_ = register_actor("SavedMessagesManager", saved_messages_manager_.get());
  G()->set_saved_messages_manager(saved_messages_manager_actor_.get());
  sponsored_message_manager_ = make_unique<SponsoredMessageManager>(this, create_reference());
  sponsored_message_manager_actor_ = register_actor("SponsoredMessageManager", sponsored_message_manager_.get());
  G()->set_sponsored_message_manager(sponsored_message_manager_actor_.get());
  star_gift_manager_ = make_unique<StarGiftManager>(this, create_reference());
  star_gift_manager_actor_ = register_actor("StarGiftManager", star_gift_manager_.get());
  star_manager_ = make_unique<StarManager>(this, create_reference());
  star_manager_actor_ = register_actor("StarManager", star_manager_.get());
  G()->set_star_manager(star_manager_actor_.get());
  statistics_manager_ = make_unique<StatisticsManager>(this, create_reference());
  statistics_manager_actor_ = register_actor("StatisticsManager", statistics_manager_.get());
  stickers_manager_ = make_unique<StickersManager>(this, create_reference());
  stickers_manager_actor_ = register_actor("StickersManager", stickers_manager_.get());
  G()->set_stickers_manager(stickers_manager_actor_.get());
  story_manager_ = make_unique<StoryManager>(this, create_reference());
  story_manager_actor_ = register_actor("StoryManager", story_manager_.get());
  G()->set_story_manager(story_manager_actor_.get());
  suggested_action_manager_ = make_unique<SuggestedActionManager>(this, create_reference());
  suggested_action_manager_actor_ = register_actor("SuggestedActionManager", suggested_action_manager_.get());
  G()->set_suggested_action_manager(suggested_action_manager_actor_.get());
  terms_of_service_manager_ = make_unique<TermsOfServiceManager>(this, create_reference());
  terms_of_service_manager_actor_ = register_actor("TermsOfServiceManager", terms_of_service_manager_.get());
  theme_manager_ = make_unique<ThemeManager>(this, create_reference());
  theme_manager_actor_ = register_actor("ThemeManager", theme_manager_.get());
  G()->set_theme_manager(theme_manager_actor_.get());
  time_zone_manager_ = make_unique<TimeZoneManager>(this, create_reference());
  time_zone_manager_actor_ = register_actor("TimeZoneManager", time_zone_manager_.get());
  G()->set_time_zone_manager(time_zone_manager_actor_.get());
  top_dialog_manager_ = make_unique<TopDialogManager>(this, create_reference());
  top_dialog_manager_actor_ = register_actor("TopDialogManager", top_dialog_manager_.get());
  G()->set_top_dialog_manager(top_dialog_manager_actor_.get());
  transcription_manager_ = make_unique<TranscriptionManager>(this, create_reference());
  transcription_manager_actor_ = register_actor("TranscriptionManager", transcription_manager_.get());
  G()->set_transcription_manager(transcription_manager_actor_.get());
  translation_manager_ = make_unique<TranslationManager>(this, create_reference());
  translation_manager_actor_ = register_actor("TranslationManager", translation_manager_.get());
  updates_manager_ = make_unique<UpdatesManager>(this, create_reference());
  updates_manager_actor_ = register_actor("UpdatesManager", updates_manager_.get());
  G()->set_updates_manager(updates_manager_actor_.get());
  user_manager_ = make_unique<UserManager>(this, create_reference());
  user_manager_actor_ = register_actor("UserManager", user_manager_.get());
  G()->set_user_manager(user_manager_actor_.get());
  video_notes_manager_ = make_unique<VideoNotesManager>(this, create_reference());
  video_notes_manager_actor_ = register_actor("VideoNotesManager", video_notes_manager_.get());
  voice_notes_manager_ = make_unique<VoiceNotesManager>(this, create_reference());
  voice_notes_manager_actor_ = register_actor("VoiceNotesManager", voice_notes_manager_.get());
  web_app_manager_ = make_unique<WebAppManager>(this, create_reference());
  web_app_manager_actor_ = register_actor("WebAppManager", web_app_manager_.get());
  G()->set_web_app_manager(web_app_manager_actor_.get());
  web_pages_manager_ = make_unique<WebPagesManager>(this, create_reference());
  web_pages_manager_actor_ = register_actor("WebPagesManager", web_pages_manager_.get());
  G()->set_web_pages_manager(web_pages_manager_actor_.get());
}

void Td::init_pure_actor_managers() {
  cashtag_search_hints_ = create_actor<HashtagHints>("CashtagSearchHints", "cashtag_search", '$', create_reference());
  device_token_manager_ = create_actor<DeviceTokenManager>("DeviceTokenManager", create_reference());
  hashtag_hints_ = create_actor<HashtagHints>("HashtagHints", "text", '#', create_reference());
  hashtag_search_hints_ = create_actor<HashtagHints>("HashtagSearchHints", "search", '#', create_reference());
  language_pack_manager_ = create_actor<LanguagePackManager>("LanguagePackManager", create_reference());
  G()->set_language_pack_manager(language_pack_manager_.get());
  password_manager_ = create_actor<PasswordManager>("PasswordManager", create_reference());
  G()->set_password_manager(password_manager_.get());
  secure_manager_ = create_actor<SecureManager>("SecureManager", create_reference());
}

void Td::send_update(tl_object_ptr<td_api::Update> &&object) {
  CHECK(object != nullptr);
  auto object_id = object->get_id();
  if (close_flag_ >= 5 && object_id != td_api::updateAuthorizationState::ID) {
    // just in case
    return;
  }

  switch (object_id) {
    case td_api::updateAccentColors::ID:
    case td_api::updateChatThemes::ID:
    case td_api::updateFavoriteStickers::ID:
    case td_api::updateInstalledStickerSets::ID:
    case td_api::updateProfileAccentColors::ID:
    case td_api::updateRecentStickers::ID:
    case td_api::updateSavedAnimations::ID:
    case td_api::updateSavedNotificationSounds::ID:
    case td_api::updateUserStatus::ID:
      VLOG(td_requests) << "Sending update: " << oneline(to_string(object));
      break;
    case td_api::updateTrendingStickerSets::ID: {
      auto update = static_cast<const td_api::updateTrendingStickerSets *>(object.get());
      auto sticker_sets = update->sticker_sets_.get();
      VLOG(td_requests) << "Sending update: updateTrendingStickerSets { " << oneline(to_string(update->sticker_type_))
                        << ", total_count = " << sticker_sets->total_count_
                        << ", count = " << sticker_sets->sets_.size() << " }";
      break;
    }
    case td_api::updateOption::ID:
      if (auth_manager_ == nullptr || !auth_manager_->is_bot()) {
        VLOG(td_requests) << "Sending update: " << to_string(object);
      }
      break;
    case td_api::updateDefaultReactionType::ID / 2:
      LOG(ERROR) << "Sending update: " << oneline(to_string(object));
      break;
    default:
      VLOG(td_requests) << "Sending update: " << to_string(object);
  }

  callback_->on_result(0, std::move(object));
}

void Td::send_result(uint64 id, tl_object_ptr<td_api::Object> object) {
  if (id == 0) {
    LOG(ERROR) << "Sending " << to_string(object) << " through send_result";
    return;
  }

  auto it = request_set_.find(id);
  if (it != request_set_.end()) {
    if (object == nullptr) {
      object = make_tl_object<td_api::error>(404, "Not Found");
    }
    VLOG(td_requests) << "Sending result for request " << id << ": " << to_string(object);
    request_set_.erase(it);
    callback_->on_result(id, std::move(object));
  }
}

void Td::send_error_impl(uint64 id, tl_object_ptr<td_api::error> error) {
  CHECK(id != 0);
  CHECK(error != nullptr);
  auto it = request_set_.find(id);
  if (it != request_set_.end()) {
    if (error->code_ == 0 && error->message_ == "Lost promise") {
      LOG(FATAL) << "Lost promise for query " << id << " of type " << it->second << " in close state " << close_flag_;
    }
    VLOG(td_requests) << "Sending error for request " << id << ": " << oneline(to_string(error));
    request_set_.erase(it);
    callback_->on_error(id, std::move(error));
  }
}

void Td::send_error(uint64 id, Status error) {
  send_error_impl(id, make_tl_object<td_api::error>(error.code(), error.message().str()));
  error.ignore();
}

Result<std::pair<Td::Parameters, TdDb::Parameters>> Td::get_parameters(
    td_api::object_ptr<td_api::setTdlibParameters> parameters) {
  VLOG(td_init) << "Begin to set TDLib parameters";
  if (!clean_input_string(parameters->api_hash_) || !clean_input_string(parameters->system_language_code_) ||
      !clean_input_string(parameters->device_model_) || !clean_input_string(parameters->system_version_) ||
      !clean_input_string(parameters->application_version_)) {
    VLOG(td_init) << "Wrong string encoding";
    return Status::Error(400, "Strings must be encoded in UTF-8");
  }

  if (parameters->api_id_ <= 0) {
    return Status::Error(400, "Valid api_id must be provided. Can be obtained at https://my.telegram.org");
  }
  if (parameters->api_hash_.empty()) {
    return Status::Error(400, "Valid api_hash must be provided. Can be obtained at https://my.telegram.org");
  }

  std::pair<Parameters, TdDb::Parameters> result;
  result.first.api_id_ = parameters->api_id_;
  result.first.api_hash_ = std::move(parameters->api_hash_);
  result.first.use_secret_chats_ = parameters->use_secret_chats_;

  result.second.encryption_key_ = TdDb::as_db_key(std::move(parameters->database_encryption_key_));
  result.second.database_directory_ = std::move(parameters->database_directory_);
  result.second.files_directory_ = std::move(parameters->files_directory_);
  result.second.is_test_dc_ = parameters->use_test_dc_;
  result.second.use_file_database_ = parameters->use_file_database_;
  result.second.use_chat_info_database_ = parameters->use_chat_info_database_;
  result.second.use_message_database_ = parameters->use_message_database_;

  VLOG(td_init) << "Create MtprotoHeader::Options";
  options_.api_id = parameters->api_id_;
  options_.system_language_code = trim(parameters->system_language_code_);
  options_.device_model = trim(parameters->device_model_);
  options_.system_version = trim(parameters->system_version_);
  options_.application_version = trim(parameters->application_version_);
  if (options_.system_language_code.empty()) {
    return Status::Error(400, "System language code must be non-empty");
  }
  if (options_.device_model.empty()) {
    return Status::Error(400, "Device model must be non-empty");
  }
  if (options_.system_version.empty()) {
    options_.system_version = get_operating_system_version().str();
    VLOG(td_init) << "Set system version to " << options_.system_version;
  }
  if (options_.application_version.empty()) {
    return Status::Error(400, "Application version must be non-empty");
  }
  if (options_.api_id != 21724) {
    options_.application_version += ", TDLib ";
    auto version = OptionManager::get_option_synchronously("version");
    CHECK(version->get_id() == td_api::optionValueString::ID);
    options_.application_version += static_cast<const td_api::optionValueString *>(version.get())->value_;
  }
  options_.language_pack = string();
  options_.language_code = string();
  options_.parameters = string();
  options_.is_emulator = false;
  options_.proxy = Proxy();

  return std::move(result);
}

}  // namespace td
