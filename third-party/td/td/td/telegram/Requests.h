//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/MovableValue.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class Requests {
 public:
  explicit Requests(Td *td);

  void run_request(uint64 id, td_api::object_ptr<td_api::Function> &&function);

 private:
  Td *td_ = nullptr;
  ActorId<Td> td_actor_;

  void send_error_raw(uint64 id, int32 code, CSlice error);

  void answer_ok_query(uint64 id, Status status);

  class RequestPromiseBase {
    enum class State : int32 { Empty, Ready, Complete };
    ActorId<Td> td_actor_;
    uint64 request_id_;
    MovableValue<State> state_{State::Empty};

   public:
    void set_value(td_api::object_ptr<td_api::Object> value) {
      CHECK(state_.get() == State::Ready);
      send_closure(td_actor_, &Td::send_result, request_id_, std::move(value));
      state_ = State::Complete;
    }

    void set_error(Status &&error) {
      if (state_.get() == State::Ready) {
        send_closure(td_actor_, &Td::send_error, request_id_, std::move(error));
        state_ = State::Complete;
      }
    }

    RequestPromiseBase(const RequestPromiseBase &) = delete;
    RequestPromiseBase &operator=(const RequestPromiseBase &) = delete;
    RequestPromiseBase(RequestPromiseBase &&) = default;
    RequestPromiseBase &operator=(RequestPromiseBase &&) = default;
    virtual ~RequestPromiseBase() {
      if (state_.get() == State::Ready) {
        send_closure(td_actor_, &Td::send_error, request_id_, Status::Error("Lost promise"));
      }
    }

    RequestPromiseBase(ActorId<Td> td_actor, uint64 request_id)
        : td_actor_(std::move(td_actor)), request_id_(request_id), state_(State::Ready) {
    }
  };

  template <class T>
  class RequestPromise final
      : public PromiseInterface<T>
      , private RequestPromiseBase {
   public:
    void set_value(T &&value) final {
      RequestPromiseBase::set_value(std::move(value));
    }

    void set_error(Status &&error) final {
      RequestPromiseBase::set_error(std::move(error));
    }

    RequestPromise(ActorId<Td> td_actor, uint64 request_id) : RequestPromiseBase(std::move(td_actor), request_id) {
    }
  };

  template <class T>
  Promise<T> create_request_promise(uint64 request_id) const {
    return Promise<T>(td::make_unique<RequestPromise<T>>(td_actor_, request_id));
  }

  Promise<Unit> create_ok_request_promise(uint64 id);

  Promise<string> create_text_request_promise(uint64 id);

  Promise<string> create_http_url_request_promise(uint64 id);

  template <class T>
  void on_request(uint64 id, const T &) = delete;

  void on_request(uint64 id, const td_api::setTdlibParameters &request);

  void on_request(uint64 id, const td_api::getAuthorizationState &request);

  void on_request(uint64 id, td_api::setAuthenticationPhoneNumber &request);

  void on_request(uint64 id, td_api::sendAuthenticationFirebaseSms &request);

  void on_request(uint64 id, td_api::reportAuthenticationCodeMissing &request);

  void on_request(uint64 id, td_api::setAuthenticationEmailAddress &request);

  void on_request(uint64 id, td_api::resendAuthenticationCode &request);

  void on_request(uint64 id, td_api::checkAuthenticationEmailCode &request);

  void on_request(uint64 id, td_api::checkAuthenticationCode &request);

  void on_request(uint64 id, td_api::registerUser &request);

  void on_request(uint64 id, const td_api::requestQrCodeAuthentication &request);

  void on_request(uint64 id, const td_api::resetAuthenticationEmailAddress &request);

  void on_request(uint64 id, td_api::checkAuthenticationPassword &request);

  void on_request(uint64 id, const td_api::requestAuthenticationPasswordRecovery &request);

  void on_request(uint64 id, td_api::checkAuthenticationPasswordRecoveryCode &request);

  void on_request(uint64 id, td_api::recoverAuthenticationPassword &request);

  void on_request(uint64 id, const td_api::logOut &request);

  void on_request(uint64 id, const td_api::close &request);

  void on_request(uint64 id, const td_api::destroy &request);

  void on_request(uint64 id, td_api::checkAuthenticationBotToken &request);

  void on_request(uint64 id, td_api::confirmQrCodeAuthentication &request);

  void on_request(uint64 id, td_api::setDatabaseEncryptionKey &request);

  void on_request(uint64 id, const td_api::getCurrentState &request);

  void on_request(uint64 id, const td_api::getPasswordState &request);

  void on_request(uint64 id, td_api::setPassword &request);

  void on_request(uint64 id, td_api::setLoginEmailAddress &request);

  void on_request(uint64 id, const td_api::resendLoginEmailAddressCode &request);

  void on_request(uint64 id, td_api::checkLoginEmailAddressCode &request);

  void on_request(uint64 id, td_api::getRecoveryEmailAddress &request);

  void on_request(uint64 id, td_api::setRecoveryEmailAddress &request);

  void on_request(uint64 id, td_api::checkRecoveryEmailAddressCode &request);

  void on_request(uint64 id, const td_api::resendRecoveryEmailAddressCode &request);

  void on_request(uint64 id, const td_api::cancelRecoveryEmailAddressVerification &request);

  void on_request(uint64 id, const td_api::requestPasswordRecovery &request);

  void on_request(uint64 id, td_api::checkPasswordRecoveryCode &request);

  void on_request(uint64 id, td_api::recoverPassword &request);

  void on_request(uint64 id, const td_api::resetPassword &request);

  void on_request(uint64 id, const td_api::cancelPasswordReset &request);

  void on_request(uint64 id, const td_api::getTemporaryPasswordState &request);

  void on_request(uint64 id, td_api::createTemporaryPassword &request);

  void on_request(uint64 id, td_api::processPushNotification &request);

  void on_request(uint64 id, td_api::registerDevice &request);

  void on_request(uint64 id, td_api::getUserPrivacySettingRules &request);

  void on_request(uint64 id, td_api::setUserPrivacySettingRules &request);

  void on_request(uint64 id, const td_api::getDefaultMessageAutoDeleteTime &request);

  void on_request(uint64 id, const td_api::setDefaultMessageAutoDeleteTime &request);

  void on_request(uint64 id, const td_api::getAccountTtl &request);

  void on_request(uint64 id, const td_api::setAccountTtl &request);

  void on_request(uint64 id, td_api::deleteAccount &request);

  void on_request(uint64 id, td_api::sendPhoneNumberCode &request);

  void on_request(uint64 id, td_api::sendPhoneNumberFirebaseSms &request);

  void on_request(uint64 id, td_api::reportPhoneNumberCodeMissing &request);

  void on_request(uint64 id, td_api::resendPhoneNumberCode &request);

  void on_request(uint64 id, td_api::checkPhoneNumberCode &request);

  void on_request(uint64 id, const td_api::getUserLink &request);

  void on_request(uint64 id, td_api::searchUserByToken &request);

  void on_request(uint64 id, const td_api::getActiveSessions &request);

  void on_request(uint64 id, const td_api::terminateSession &request);

  void on_request(uint64 id, const td_api::terminateAllOtherSessions &request);

  void on_request(uint64 id, const td_api::confirmSession &request);

  void on_request(uint64 id, const td_api::toggleSessionCanAcceptCalls &request);

  void on_request(uint64 id, const td_api::toggleSessionCanAcceptSecretChats &request);

  void on_request(uint64 id, const td_api::setInactiveSessionTtl &request);

  void on_request(uint64 id, const td_api::getConnectedWebsites &request);

  void on_request(uint64 id, const td_api::disconnectWebsite &request);

  void on_request(uint64 id, const td_api::disconnectAllWebsites &request);

  void on_request(uint64 id, const td_api::getMe &request);

  void on_request(uint64 id, const td_api::getUser &request);

  void on_request(uint64 id, const td_api::getUserFullInfo &request);

  void on_request(uint64 id, const td_api::getBasicGroup &request);

  void on_request(uint64 id, const td_api::getBasicGroupFullInfo &request);

  void on_request(uint64 id, const td_api::getSupergroup &request);

  void on_request(uint64 id, const td_api::getSupergroupFullInfo &request);

  void on_request(uint64 id, const td_api::getSecretChat &request);

  void on_request(uint64 id, const td_api::getChat &request);

  void on_request(uint64 id, const td_api::getMessage &request);

  void on_request(uint64 id, const td_api::getMessageLocally &request);

  void on_request(uint64 id, const td_api::getRepliedMessage &request);

  void on_request(uint64 id, const td_api::getChatPinnedMessage &request);

  void on_request(uint64 id, const td_api::getCallbackQueryMessage &request);

  void on_request(uint64 id, const td_api::getMessageThread &request);

  void on_request(uint64 id, const td_api::getMessageReadDate &request);

  void on_request(uint64 id, const td_api::getMessageViewers &request);

  void on_request(uint64 id, const td_api::getMessages &request);

  void on_request(uint64 id, const td_api::getMessageProperties &request);

  void on_request(uint64 id, const td_api::getChatSponsoredMessages &request);

  void on_request(uint64 id, const td_api::clickChatSponsoredMessage &request);

  void on_request(uint64 id, const td_api::reportChatSponsoredMessage &request);

  void on_request(uint64 id, const td_api::getMessageLink &request);

  void on_request(uint64 id, const td_api::getMessageEmbeddingCode &request);

  void on_request(uint64 id, td_api::getMessageLinkInfo &request);

  void on_request(uint64 id, td_api::translateText &request);

  void on_request(uint64 id, td_api::translateMessageText &request);

  void on_request(uint64 id, const td_api::recognizeSpeech &request);

  void on_request(uint64 id, const td_api::rateSpeechRecognition &request);

  void on_request(uint64 id, const td_api::getFile &request);

  void on_request(uint64 id, td_api::getRemoteFile &request);

  void on_request(uint64 id, const td_api::getStorageStatistics &request);

  void on_request(uint64 id, const td_api::getStorageStatisticsFast &request);

  void on_request(uint64 id, const td_api::getDatabaseStatistics &request);

  void on_request(uint64 id, td_api::optimizeStorage &request);

  void on_request(uint64 id, const td_api::getNetworkStatistics &request);

  void on_request(uint64 id, const td_api::resetNetworkStatistics &request);

  void on_request(uint64 id, td_api::addNetworkStatistics &request);

  void on_request(uint64 id, const td_api::setNetworkType &request);

  void on_request(uint64 id, const td_api::getAutoDownloadSettingsPresets &request);

  void on_request(uint64 id, const td_api::setAutoDownloadSettings &request);

  void on_request(uint64 id, const td_api::getAutosaveSettings &request);

  void on_request(uint64 id, td_api::setAutosaveSettings &request);

  void on_request(uint64 id, const td_api::clearAutosaveSettingsExceptions &request);

  void on_request(uint64 id, const td_api::getRecommendedChats &request);

  void on_request(uint64 id, const td_api::getChatSimilarChats &request);

  void on_request(uint64 id, const td_api::getChatSimilarChatCount &request);

  void on_request(uint64 id, const td_api::openChatSimilarChat &request);

  void on_request(uint64 id, const td_api::getBotSimilarBots &request);

  void on_request(uint64 id, const td_api::getBotSimilarBotCount &request);

  void on_request(uint64 id, const td_api::openBotSimilarBot &request);

  void on_request(uint64 id, const td_api::getTopChats &request);

  void on_request(uint64 id, const td_api::removeTopChat &request);

  void on_request(uint64 id, const td_api::loadChats &request);

  void on_request(uint64 id, const td_api::getChats &request);

  void on_request(uint64 id, const td_api::loadSavedMessagesTopics &request);

  void on_request(uint64 id, const td_api::getSavedMessagesTopicHistory &request);

  void on_request(uint64 id, const td_api::getSavedMessagesTopicMessageByDate &request);

  void on_request(uint64 id, const td_api::deleteSavedMessagesTopicHistory &request);

  void on_request(uint64 id, const td_api::deleteSavedMessagesTopicMessagesByDate &request);

  void on_request(uint64 id, const td_api::toggleSavedMessagesTopicIsPinned &request);

  void on_request(uint64 id, const td_api::setPinnedSavedMessagesTopics &request);

  void on_request(uint64 id, td_api::searchPublicChat &request);

  void on_request(uint64 id, td_api::searchPublicChats &request);

  void on_request(uint64 id, td_api::searchChats &request);

  void on_request(uint64 id, td_api::searchChatsOnServer &request);

  void on_request(uint64 id, td_api::searchRecentlyFoundChats &request);

  void on_request(uint64 id, const td_api::addRecentlyFoundChat &request);

  void on_request(uint64 id, const td_api::removeRecentlyFoundChat &request);

  void on_request(uint64 id, const td_api::clearRecentlyFoundChats &request);

  void on_request(uint64 id, const td_api::getRecentlyOpenedChats &request);

  void on_request(uint64 id, const td_api::getGroupsInCommon &request);

  void on_request(uint64 id, td_api::checkChatUsername &request);

  void on_request(uint64 id, const td_api::getCreatedPublicChats &request);

  void on_request(uint64 id, const td_api::checkCreatedPublicChatsLimit &request);

  void on_request(uint64 id, const td_api::getSuitableDiscussionChats &request);

  void on_request(uint64 id, const td_api::getInactiveSupergroupChats &request);

  void on_request(uint64 id, const td_api::getSuitablePersonalChats &request);

  void on_request(uint64 id, const td_api::openChat &request);

  void on_request(uint64 id, const td_api::closeChat &request);

  void on_request(uint64 id, const td_api::viewMessages &request);

  void on_request(uint64 id, const td_api::openMessageContent &request);

  void on_request(uint64 id, const td_api::clickAnimatedEmojiMessage &request);

  void on_request(uint64 id, const td_api::getInternalLink &request);

  void on_request(uint64 id, const td_api::getInternalLinkType &request);

  void on_request(uint64 id, td_api::getExternalLinkInfo &request);

  void on_request(uint64 id, td_api::getExternalLink &request);

  void on_request(uint64 id, const td_api::getChatHistory &request);

  void on_request(uint64 id, const td_api::deleteChatHistory &request);

  void on_request(uint64 id, const td_api::deleteChat &request);

  void on_request(uint64 id, const td_api::getMessageThreadHistory &request);

  void on_request(uint64 id, const td_api::getChatMessageCalendar &request);

  void on_request(uint64 id, td_api::searchChatMessages &request);

  void on_request(uint64 id, td_api::searchSecretMessages &request);

  void on_request(uint64 id, td_api::searchMessages &request);

  void on_request(uint64 id, td_api::searchSavedMessages &request);

  void on_request(uint64 id, const td_api::searchCallMessages &request);

  void on_request(uint64 id, td_api::searchOutgoingDocumentMessages &request);

  void on_request(uint64 id, td_api::searchPublicMessagesByTag &request);

  void on_request(uint64 id, td_api::searchPublicStoriesByTag &request);

  void on_request(uint64 id, td_api::searchPublicStoriesByLocation &request);

  void on_request(uint64 id, td_api::searchPublicStoriesByVenue &request);

  void on_request(uint64 id, td_api::getSearchedForTags &request);

  void on_request(uint64 id, td_api::removeSearchedForTag &request);

  void on_request(uint64 id, const td_api::clearSearchedForTags &request);

  void on_request(uint64 id, const td_api::deleteAllCallMessages &request);

  void on_request(uint64 id, const td_api::searchChatRecentLocationMessages &request);

  void on_request(uint64 id, const td_api::getChatMessageByDate &request);

  void on_request(uint64 id, const td_api::getChatSparseMessagePositions &request);

  void on_request(uint64 id, const td_api::getChatMessageCount &request);

  void on_request(uint64 id, const td_api::getChatMessagePosition &request);

  void on_request(uint64 id, const td_api::getChatScheduledMessages &request);

  void on_request(uint64 id, const td_api::getEmojiReaction &request);

  void on_request(uint64 id, const td_api::getCustomEmojiReactionAnimations &request);

  void on_request(uint64 id, const td_api::getMessageAvailableReactions &request);

  void on_request(uint64 id, const td_api::clearRecentReactions &request);

  void on_request(uint64 id, const td_api::addMessageReaction &request);

  void on_request(uint64 id, const td_api::getChatAvailablePaidMessageReactionSenders &request);

  void on_request(uint64 id, const td_api::addPendingPaidMessageReaction &request);

  void on_request(uint64 id, const td_api::commitPendingPaidMessageReactions &request);

  void on_request(uint64 id, const td_api::removePendingPaidMessageReactions &request);

  void on_request(uint64 id, const td_api::setPaidMessageReactionType &request);

  void on_request(uint64 id, const td_api::removeMessageReaction &request);

  void on_request(uint64 id, const td_api::setMessageReactions &request);

  void on_request(uint64 id, td_api::getMessageAddedReactions &request);

  void on_request(uint64 id, const td_api::setDefaultReactionType &request);

  void on_request(uint64 id, const td_api::getSavedMessagesTags &request);

  void on_request(uint64 id, td_api::setSavedMessagesTagLabel &request);

  void on_request(uint64 id, const td_api::getMessageEffect &request);

  void on_request(uint64 id, td_api::getMessagePublicForwards &request);

  void on_request(uint64 id, td_api::getStoryPublicForwards &request);

  void on_request(uint64 id, const td_api::removeNotification &request);

  void on_request(uint64 id, const td_api::removeNotificationGroup &request);

  void on_request(uint64 id, const td_api::deleteMessages &request);

  void on_request(uint64 id, const td_api::deleteChatMessagesBySender &request);

  void on_request(uint64 id, const td_api::deleteChatMessagesByDate &request);

  void on_request(uint64 id, const td_api::readAllChatMentions &request);

  void on_request(uint64 id, const td_api::readAllMessageThreadMentions &request);

  void on_request(uint64 id, const td_api::readAllChatReactions &request);

  void on_request(uint64 id, const td_api::readAllMessageThreadReactions &request);

  void on_request(uint64 id, const td_api::getChatAvailableMessageSenders &request);

  void on_request(uint64 id, const td_api::setChatMessageSender &request);

  void on_request(uint64 id, td_api::sendMessage &request);

  void on_request(uint64 id, td_api::sendMessageAlbum &request);

  void on_request(uint64 id, td_api::sendBotStartMessage &request);

  void on_request(uint64 id, td_api::sendInlineQueryResultMessage &request);

  void on_request(uint64 id, td_api::addLocalMessage &request);

  void on_request(uint64 id, td_api::editMessageText &request);

  void on_request(uint64 id, td_api::editMessageLiveLocation &request);

  void on_request(uint64 id, td_api::editMessageMedia &request);

  void on_request(uint64 id, td_api::editMessageCaption &request);

  void on_request(uint64 id, td_api::editMessageReplyMarkup &request);

  void on_request(uint64 id, td_api::editInlineMessageText &request);

  void on_request(uint64 id, td_api::editInlineMessageLiveLocation &request);

  void on_request(uint64 id, td_api::editInlineMessageMedia &request);

  void on_request(uint64 id, td_api::editInlineMessageCaption &request);

  void on_request(uint64 id, td_api::editInlineMessageReplyMarkup &request);

  void on_request(uint64 id, td_api::editMessageSchedulingState &request);

  void on_request(uint64 id, td_api::setMessageFactCheck &request);

  void on_request(uint64 id, td_api::sendBusinessMessage &request);

  void on_request(uint64 id, td_api::sendBusinessMessageAlbum &request);

  void on_request(uint64 id, td_api::editBusinessMessageText &request);

  void on_request(uint64 id, td_api::editBusinessMessageLiveLocation &request);

  void on_request(uint64 id, td_api::editBusinessMessageMedia &request);

  void on_request(uint64 id, td_api::editBusinessMessageCaption &request);

  void on_request(uint64 id, td_api::editBusinessMessageReplyMarkup &request);

  void on_request(uint64 id, td_api::stopBusinessPoll &request);

  void on_request(uint64 id, td_api::setBusinessMessageIsPinned &request);

  void on_request(uint64 id, const td_api::loadQuickReplyShortcuts &request);

  void on_request(uint64 id, const td_api::setQuickReplyShortcutName &request);

  void on_request(uint64 id, const td_api::deleteQuickReplyShortcut &request);

  void on_request(uint64 id, const td_api::reorderQuickReplyShortcuts &request);

  void on_request(uint64 id, const td_api::loadQuickReplyShortcutMessages &request);

  void on_request(uint64 id, const td_api::deleteQuickReplyShortcutMessages &request);

  void on_request(uint64 id, td_api::addQuickReplyShortcutMessage &request);

  void on_request(uint64 id, td_api::addQuickReplyShortcutInlineQueryResultMessage &request);

  void on_request(uint64 id, td_api::addQuickReplyShortcutMessageAlbum &request);

  void on_request(uint64 id, td_api::readdQuickReplyShortcutMessages &request);

  void on_request(uint64 id, td_api::editQuickReplyMessage &request);

  void on_request(uint64 id, const td_api::getCurrentWeather &request);

  void on_request(uint64 id, const td_api::getStory &request);

  void on_request(uint64 id, const td_api::getChatsToSendStories &request);

  void on_request(uint64 id, const td_api::canSendStory &request);

  void on_request(uint64 id, td_api::sendStory &request);

  void on_request(uint64 id, td_api::editStory &request);

  void on_request(uint64 id, const td_api::editStoryCover &request);

  void on_request(uint64 id, td_api::setStoryPrivacySettings &request);

  void on_request(uint64 id, const td_api::toggleStoryIsPostedToChatPage &request);

  void on_request(uint64 id, const td_api::deleteStory &request);

  void on_request(uint64 id, const td_api::loadActiveStories &request);

  void on_request(uint64 id, const td_api::setChatActiveStoriesList &request);

  void on_request(uint64 id, const td_api::getForumTopicDefaultIcons &request);

  void on_request(uint64 id, td_api::createForumTopic &request);

  void on_request(uint64 id, td_api::editForumTopic &request);

  void on_request(uint64 id, const td_api::getForumTopic &request);

  void on_request(uint64 id, const td_api::getForumTopicLink &request);

  void on_request(uint64 id, td_api::getForumTopics &request);

  void on_request(uint64 id, const td_api::toggleForumTopicIsClosed &request);

  void on_request(uint64 id, const td_api::toggleGeneralForumTopicIsHidden &request);

  void on_request(uint64 id, const td_api::toggleForumTopicIsPinned &request);

  void on_request(uint64 id, const td_api::setPinnedForumTopics &request);

  void on_request(uint64 id, const td_api::deleteForumTopic &request);

  void on_request(uint64 id, const td_api::setGameScore &request);

  void on_request(uint64 id, td_api::setInlineGameScore &request);

  void on_request(uint64 id, const td_api::getGameHighScores &request);

  void on_request(uint64 id, td_api::getInlineGameHighScores &request);

  void on_request(uint64 id, const td_api::deleteChatReplyMarkup &request);

  void on_request(uint64 id, td_api::sendChatAction &request);

  void on_request(uint64 id, td_api::forwardMessages &request);

  void on_request(uint64 id, const td_api::sendQuickReplyShortcutMessages &request);

  void on_request(uint64 id, td_api::resendMessages &request);

  void on_request(uint64 id, td_api::getLinkPreview &request);

  void on_request(uint64 id, td_api::getWebPageInstantView &request);

  void on_request(uint64 id, const td_api::createPrivateChat &request);

  void on_request(uint64 id, const td_api::createBasicGroupChat &request);

  void on_request(uint64 id, const td_api::createSupergroupChat &request);

  void on_request(uint64 id, const td_api::createSecretChat &request);

  void on_request(uint64 id, td_api::createNewBasicGroupChat &request);

  void on_request(uint64 id, td_api::createNewSupergroupChat &request);

  void on_request(uint64 id, const td_api::createNewSecretChat &request);

  void on_request(uint64 id, const td_api::createCall &request);

  void on_request(uint64 id, const td_api::acceptCall &request);

  void on_request(uint64 id, td_api::sendCallSignalingData &request);

  void on_request(uint64 id, const td_api::discardCall &request);

  void on_request(uint64 id, td_api::sendCallRating &request);

  void on_request(uint64 id, td_api::sendCallDebugInformation &request);

  void on_request(uint64 id, td_api::sendCallLog &request);

  void on_request(uint64 id, const td_api::getVideoChatAvailableParticipants &request);

  void on_request(uint64 id, const td_api::setVideoChatDefaultParticipant &request);

  void on_request(uint64 id, td_api::createVideoChat &request);

  void on_request(uint64 id, const td_api::createGroupCall &request);

  void on_request(uint64 id, const td_api::getVideoChatRtmpUrl &request);

  void on_request(uint64 id, const td_api::replaceVideoChatRtmpUrl &request);

  void on_request(uint64 id, const td_api::getGroupCall &request);

  void on_request(uint64 id, const td_api::startScheduledGroupCall &request);

  void on_request(uint64 id, const td_api::toggleGroupCallEnabledStartNotification &request);

  void on_request(uint64 id, td_api::joinGroupCall &request);

  void on_request(uint64 id, td_api::startGroupCallScreenSharing &request);

  void on_request(uint64 id, const td_api::endGroupCallScreenSharing &request);

  void on_request(uint64 id, td_api::setGroupCallTitle &request);

  void on_request(uint64 id, const td_api::toggleGroupCallMuteNewParticipants &request);

  void on_request(uint64 id, const td_api::revokeGroupCallInviteLink &request);

  void on_request(uint64 id, const td_api::inviteGroupCallParticipants &request);

  void on_request(uint64 id, const td_api::getGroupCallInviteLink &request);

  void on_request(uint64 id, td_api::startGroupCallRecording &request);

  void on_request(uint64 id, const td_api::toggleGroupCallScreenSharingIsPaused &request);

  void on_request(uint64 id, const td_api::endGroupCallRecording &request);

  void on_request(uint64 id, const td_api::toggleGroupCallIsMyVideoPaused &request);

  void on_request(uint64 id, const td_api::toggleGroupCallIsMyVideoEnabled &request);

  void on_request(uint64 id, const td_api::setGroupCallParticipantIsSpeaking &request);

  void on_request(uint64 id, const td_api::toggleGroupCallParticipantIsMuted &request);

  void on_request(uint64 id, const td_api::setGroupCallParticipantVolumeLevel &request);

  void on_request(uint64 id, const td_api::toggleGroupCallParticipantIsHandRaised &request);

  void on_request(uint64 id, const td_api::loadGroupCallParticipants &request);

  void on_request(uint64 id, const td_api::leaveGroupCall &request);

  void on_request(uint64 id, const td_api::endGroupCall &request);

  void on_request(uint64 id, const td_api::getGroupCallStreams &request);

  void on_request(uint64 id, td_api::getGroupCallStreamSegment &request);

  void on_request(uint64 id, const td_api::upgradeBasicGroupChatToSupergroupChat &request);

  void on_request(uint64 id, const td_api::getChatListsToAddChat &request);

  void on_request(uint64 id, const td_api::addChatToList &request);

  void on_request(uint64 id, const td_api::getChatFolder &request);

  void on_request(uint64 id, const td_api::getRecommendedChatFolders &request);

  void on_request(uint64 id, td_api::createChatFolder &request);

  void on_request(uint64 id, td_api::editChatFolder &request);

  void on_request(uint64 id, const td_api::deleteChatFolder &request);

  void on_request(uint64 id, const td_api::getChatFolderChatsToLeave &request);

  void on_request(uint64 id, td_api::getChatFolderChatCount &request);

  void on_request(uint64 id, const td_api::reorderChatFolders &request);

  void on_request(uint64 id, const td_api::toggleChatFolderTags &request);

  void on_request(uint64 id, const td_api::getChatsForChatFolderInviteLink &request);

  void on_request(uint64 id, td_api::createChatFolderInviteLink &request);

  void on_request(uint64 id, const td_api::getChatFolderInviteLinks &request);

  void on_request(uint64 id, td_api::editChatFolderInviteLink &request);

  void on_request(uint64 id, td_api::deleteChatFolderInviteLink &request);

  void on_request(uint64 id, td_api::checkChatFolderInviteLink &request);

  void on_request(uint64 id, td_api::addChatFolderByInviteLink &request);

  void on_request(uint64 id, const td_api::getChatFolderNewChats &request);

  void on_request(uint64 id, const td_api::processChatFolderNewChats &request);

  void on_request(uint64 id, const td_api::getArchiveChatListSettings &request);

  void on_request(uint64 id, td_api::setArchiveChatListSettings &request);

  void on_request(uint64 id, const td_api::getReadDatePrivacySettings &request);

  void on_request(uint64 id, td_api::setReadDatePrivacySettings &request);

  void on_request(uint64 id, const td_api::getNewChatPrivacySettings &request);

  void on_request(uint64 id, td_api::setNewChatPrivacySettings &request);

  void on_request(uint64 id, const td_api::getPaidMessageRevenue &request);

  void on_request(uint64 id, const td_api::allowUnpaidMessagesFromUser &request);

  void on_request(uint64 id, const td_api::setChatPaidMessageStarCount &request);

  void on_request(uint64 id, const td_api::canSendMessageToUser &request);

  void on_request(uint64 id, td_api::setChatTitle &request);

  void on_request(uint64 id, const td_api::setChatPhoto &request);

  void on_request(uint64 id, const td_api::setChatAccentColor &request);

  void on_request(uint64 id, const td_api::setChatProfileAccentColor &request);

  void on_request(uint64 id, const td_api::setChatMessageAutoDeleteTime &request);

  void on_request(uint64 id, const td_api::setChatEmojiStatus &request);

  void on_request(uint64 id, const td_api::setChatPermissions &request);

  void on_request(uint64 id, const td_api::setChatBackground &request);

  void on_request(uint64 id, const td_api::deleteChatBackground &request);

  void on_request(uint64 id, td_api::setChatTheme &request);

  void on_request(uint64 id, td_api::setChatDraftMessage &request);

  void on_request(uint64 id, const td_api::toggleChatHasProtectedContent &request);

  void on_request(uint64 id, const td_api::toggleChatIsPinned &request);

  void on_request(uint64 id, const td_api::toggleChatViewAsTopics &request);

  void on_request(uint64 id, const td_api::toggleChatIsTranslatable &request);

  void on_request(uint64 id, const td_api::toggleChatIsMarkedAsUnread &request);

  void on_request(uint64 id, const td_api::setMessageSenderBlockList &request);

  void on_request(uint64 id, const td_api::toggleChatDefaultDisableNotification &request);

  void on_request(uint64 id, const td_api::setPinnedChats &request);

  void on_request(uint64 id, const td_api::readChatList &request);

  void on_request(uint64 id, const td_api::getStoryNotificationSettingsExceptions &request);

  void on_request(uint64 id, const td_api::getChatActiveStories &request);

  void on_request(uint64 id, const td_api::getChatPostedToChatPageStories &request);

  void on_request(uint64 id, const td_api::getChatArchivedStories &request);

  void on_request(uint64 id, const td_api::setChatPinnedStories &request);

  void on_request(uint64 id, const td_api::openStory &request);

  void on_request(uint64 id, const td_api::closeStory &request);

  void on_request(uint64 id, const td_api::getStoryAvailableReactions &request);

  void on_request(uint64 id, const td_api::setStoryReaction &request);

  void on_request(uint64 id, td_api::getStoryInteractions &request);

  void on_request(uint64 id, td_api::getChatStoryInteractions &request);

  void on_request(uint64 id, td_api::reportStory &request);

  void on_request(uint64 id, const td_api::activateStoryStealthMode &request);

  void on_request(uint64 id, const td_api::getChatBoostLevelFeatures &request);

  void on_request(uint64 id, const td_api::getChatBoostFeatures &request);

  void on_request(uint64 id, const td_api::getAvailableChatBoostSlots &request);

  void on_request(uint64 id, const td_api::getChatBoostStatus &request);

  void on_request(uint64 id, td_api::boostChat &request);

  void on_request(uint64 id, const td_api::getChatBoostLink &request);

  void on_request(uint64 id, td_api::getChatBoostLinkInfo &request);

  void on_request(uint64 id, td_api::getChatBoosts &request);

  void on_request(uint64 id, const td_api::getUserChatBoosts &request);

  void on_request(uint64 id, const td_api::getAttachmentMenuBot &request);

  void on_request(uint64 id, const td_api::toggleBotIsAddedToAttachmentMenu &request);

  void on_request(uint64 id, td_api::setChatAvailableReactions &request);

  void on_request(uint64 id, td_api::setChatClientData &request);

  void on_request(uint64 id, td_api::setChatDescription &request);

  void on_request(uint64 id, const td_api::setChatDiscussionGroup &request);

  void on_request(uint64 id, td_api::setChatLocation &request);

  void on_request(uint64 id, const td_api::setChatSlowModeDelay &request);

  void on_request(uint64 id, const td_api::pinChatMessage &request);

  void on_request(uint64 id, const td_api::unpinChatMessage &request);

  void on_request(uint64 id, const td_api::unpinAllChatMessages &request);

  void on_request(uint64 id, const td_api::unpinAllMessageThreadMessages &request);

  void on_request(uint64 id, const td_api::joinChat &request);

  void on_request(uint64 id, const td_api::leaveChat &request);

  void on_request(uint64 id, const td_api::addChatMember &request);

  void on_request(uint64 id, const td_api::addChatMembers &request);

  void on_request(uint64 id, td_api::setChatMemberStatus &request);

  void on_request(uint64 id, const td_api::banChatMember &request);

  void on_request(uint64 id, const td_api::canTransferOwnership &request);

  void on_request(uint64 id, td_api::transferChatOwnership &request);

  void on_request(uint64 id, const td_api::getChatMember &request);

  void on_request(uint64 id, td_api::searchChatMembers &request);

  void on_request(uint64 id, const td_api::getChatAdministrators &request);

  void on_request(uint64 id, const td_api::replacePrimaryChatInviteLink &request);

  void on_request(uint64 id, td_api::createChatInviteLink &request);

  void on_request(uint64 id, td_api::createChatSubscriptionInviteLink &request);

  void on_request(uint64 id, td_api::editChatInviteLink &request);

  void on_request(uint64 id, td_api::editChatSubscriptionInviteLink &request);

  void on_request(uint64 id, td_api::getChatInviteLink &request);

  void on_request(uint64 id, const td_api::getChatInviteLinkCounts &request);

  void on_request(uint64 id, td_api::getChatInviteLinks &request);

  void on_request(uint64 id, td_api::getChatInviteLinkMembers &request);

  void on_request(uint64 id, td_api::getChatJoinRequests &request);

  void on_request(uint64 id, const td_api::processChatJoinRequest &request);

  void on_request(uint64 id, td_api::processChatJoinRequests &request);

  void on_request(uint64 id, td_api::revokeChatInviteLink &request);

  void on_request(uint64 id, td_api::deleteRevokedChatInviteLink &request);

  void on_request(uint64 id, const td_api::deleteAllRevokedChatInviteLinks &request);

  void on_request(uint64 id, td_api::checkChatInviteLink &request);

  void on_request(uint64 id, td_api::joinChatByInviteLink &request);

  void on_request(uint64 id, td_api::getChatEventLog &request);

  void on_request(uint64 id, const td_api::getTimeZones &request);

  void on_request(uint64 id, const td_api::clearAllDraftMessages &request);

  void on_request(uint64 id, const td_api::downloadFile &request);

  void on_request(uint64 id, const td_api::getFileDownloadedPrefixSize &request);

  void on_request(uint64 id, const td_api::cancelDownloadFile &request);

  void on_request(uint64 id, const td_api::getSuggestedFileName &request);

  void on_request(uint64 id, const td_api::preliminaryUploadFile &request);

  void on_request(uint64 id, const td_api::cancelPreliminaryUploadFile &request);

  void on_request(uint64 id, td_api::writeGeneratedFilePart &request);

  void on_request(uint64 id, const td_api::setFileGenerationProgress &request);

  void on_request(uint64 id, td_api::finishFileGeneration &request);

  void on_request(uint64 id, const td_api::readFilePart &request);

  void on_request(uint64 id, const td_api::deleteFile &request);

  void on_request(uint64 id, const td_api::addFileToDownloads &request);

  void on_request(uint64 id, const td_api::toggleDownloadIsPaused &request);

  void on_request(uint64 id, const td_api::toggleAllDownloadsArePaused &request);

  void on_request(uint64 id, const td_api::removeFileFromDownloads &request);

  void on_request(uint64 id, const td_api::removeAllFilesFromDownloads &request);

  void on_request(uint64 id, td_api::searchFileDownloads &request);

  void on_request(uint64 id, td_api::setApplicationVerificationToken &request);

  void on_request(uint64 id, td_api::getMessageFileType &request);

  void on_request(uint64 id, const td_api::getMessageImportConfirmationText &request);

  void on_request(uint64 id, const td_api::importMessages &request);

  void on_request(uint64 id, const td_api::blockMessageSenderFromReplies &request);

  void on_request(uint64 id, const td_api::getBlockedMessageSenders &request);

  void on_request(uint64 id, td_api::addContact &request);

  void on_request(uint64 id, td_api::importContacts &request);

  void on_request(uint64 id, const td_api::getContacts &request);

  void on_request(uint64 id, td_api::searchContacts &request);

  void on_request(uint64 id, const td_api::removeContacts &request);

  void on_request(uint64 id, const td_api::getImportedContactCount &request);

  void on_request(uint64 id, td_api::changeImportedContacts &request);

  void on_request(uint64 id, const td_api::clearImportedContacts &request);

  void on_request(uint64 id, const td_api::getCloseFriends &request);

  void on_request(uint64 id, const td_api::setCloseFriends &request);

  void on_request(uint64 id, const td_api::setUserPersonalProfilePhoto &request);

  void on_request(uint64 id, const td_api::suggestUserProfilePhoto &request);

  void on_request(uint64 id, const td_api::toggleBotCanManageEmojiStatus &request);

  void on_request(uint64 id, const td_api::setUserEmojiStatus &request);

  void on_request(uint64 id, td_api::searchUserByPhoneNumber &request);

  void on_request(uint64 id, const td_api::sharePhoneNumber &request);

  void on_request(uint64 id, const td_api::getRecentInlineBots &request);

  void on_request(uint64 id, const td_api::getOwnedBots &request);

  void on_request(uint64 id, td_api::setName &request);

  void on_request(uint64 id, td_api::setBio &request);

  void on_request(uint64 id, td_api::setUsername &request);

  void on_request(uint64 id, td_api::toggleUsernameIsActive &request);

  void on_request(uint64 id, td_api::reorderActiveUsernames &request);

  void on_request(uint64 id, td_api::setBirthdate &request);

  void on_request(uint64 id, const td_api::setPersonalChat &request);

  void on_request(uint64 id, const td_api::setEmojiStatus &request);

  void on_request(uint64 id, const td_api::toggleHasSponsoredMessagesEnabled &request);

  void on_request(uint64 id, const td_api::getThemedEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getThemedChatEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getDefaultEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getDefaultChatEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getRecentEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getUpgradedGiftEmojiStatuses &request);

  void on_request(uint64 id, const td_api::clearRecentEmojiStatuses &request);

  void on_request(uint64 id, td_api::setCommands &request);

  void on_request(uint64 id, td_api::deleteCommands &request);

  void on_request(uint64 id, td_api::getCommands &request);

  void on_request(uint64 id, td_api::setMenuButton &request);

  void on_request(uint64 id, const td_api::getMenuButton &request);

  void on_request(uint64 id, const td_api::setDefaultGroupAdministratorRights &request);

  void on_request(uint64 id, const td_api::setDefaultChannelAdministratorRights &request);

  void on_request(uint64 id, const td_api::canBotSendMessages &request);

  void on_request(uint64 id, const td_api::allowBotToSendMessages &request);

  void on_request(uint64 id, td_api::sendWebAppCustomRequest &request);

  void on_request(uint64 id, const td_api::getBotMediaPreviews &request);

  void on_request(uint64 id, const td_api::getBotMediaPreviewInfo &request);

  void on_request(uint64 id, td_api::addBotMediaPreview &request);

  void on_request(uint64 id, td_api::editBotMediaPreview &request);

  void on_request(uint64 id, const td_api::reorderBotMediaPreviews &request);

  void on_request(uint64 id, const td_api::deleteBotMediaPreviews &request);

  void on_request(uint64 id, td_api::setBotName &request);

  void on_request(uint64 id, const td_api::getBotName &request);

  void on_request(uint64 id, const td_api::setBotProfilePhoto &request);

  void on_request(uint64 id, td_api::toggleBotUsernameIsActive &request);

  void on_request(uint64 id, td_api::reorderBotActiveUsernames &request);

  void on_request(uint64 id, td_api::setBotInfoDescription &request);

  void on_request(uint64 id, const td_api::getBotInfoDescription &request);

  void on_request(uint64 id, td_api::setBotInfoShortDescription &request);

  void on_request(uint64 id, const td_api::getBotInfoShortDescription &request);

  void on_request(uint64 id, td_api::setMessageSenderBotVerification &request);

  void on_request(uint64 id, const td_api::removeMessageSenderBotVerification &request);

  void on_request(uint64 id, td_api::setBusinessLocation &request);

  void on_request(uint64 id, td_api::setBusinessOpeningHours &request);

  void on_request(uint64 id, td_api::setBusinessGreetingMessageSettings &request);

  void on_request(uint64 id, td_api::setBusinessAwayMessageSettings &request);

  void on_request(uint64 id, td_api::setBusinessStartPage &request);

  void on_request(uint64 id, const td_api::setProfilePhoto &request);

  void on_request(uint64 id, const td_api::deleteProfilePhoto &request);

  void on_request(uint64 id, const td_api::getUserProfilePhotos &request);

  void on_request(uint64 id, const td_api::setAccentColor &request);

  void on_request(uint64 id, const td_api::setProfileAccentColor &request);

  void on_request(uint64 id, const td_api::getBusinessConnectedBot &request);

  void on_request(uint64 id, td_api::setBusinessConnectedBot &request);

  void on_request(uint64 id, const td_api::deleteBusinessConnectedBot &request);

  void on_request(uint64 id, const td_api::toggleBusinessConnectedBotChatIsPaused &request);

  void on_request(uint64 id, const td_api::removeBusinessConnectedBotFromChat &request);

  void on_request(uint64 id, const td_api::getBusinessChatLinks &request);

  void on_request(uint64 id, td_api::createBusinessChatLink &request);

  void on_request(uint64 id, td_api::editBusinessChatLink &request);

  void on_request(uint64 id, td_api::deleteBusinessChatLink &request);

  void on_request(uint64 id, td_api::getBusinessChatLinkInfo &request);

  void on_request(uint64 id, td_api::setSupergroupUsername &request);

  void on_request(uint64 id, td_api::toggleSupergroupUsernameIsActive &request);

  void on_request(uint64 id, const td_api::disableAllSupergroupUsernames &request);

  void on_request(uint64 id, td_api::reorderSupergroupActiveUsernames &request);

  void on_request(uint64 id, const td_api::setSupergroupStickerSet &request);

  void on_request(uint64 id, const td_api::setSupergroupCustomEmojiStickerSet &request);

  void on_request(uint64 id, const td_api::setSupergroupUnrestrictBoostCount &request);

  void on_request(uint64 id, const td_api::toggleSupergroupSignMessages &request);

  void on_request(uint64 id, const td_api::toggleSupergroupJoinToSendMessages &request);

  void on_request(uint64 id, const td_api::toggleSupergroupJoinByRequest &request);

  void on_request(uint64 id, const td_api::toggleSupergroupIsAllHistoryAvailable &request);

  void on_request(uint64 id, const td_api::toggleSupergroupCanHaveSponsoredMessages &request);

  void on_request(uint64 id, const td_api::toggleSupergroupHasHiddenMembers &request);

  void on_request(uint64 id, const td_api::toggleSupergroupHasAggressiveAntiSpamEnabled &request);

  void on_request(uint64 id, const td_api::toggleSupergroupIsForum &request);

  void on_request(uint64 id, const td_api::toggleSupergroupIsBroadcastGroup &request);

  void on_request(uint64 id, const td_api::reportSupergroupSpam &request);

  void on_request(uint64 id, const td_api::reportSupergroupAntiSpamFalsePositive &request);

  void on_request(uint64 id, td_api::getSupergroupMembers &request);

  void on_request(uint64 id, const td_api::closeSecretChat &request);

  void on_request(uint64 id, const td_api::getStickerOutline &request);

  void on_request(uint64 id, td_api::getStickers &request);

  void on_request(uint64 id, td_api::getAllStickerEmojis &request);

  void on_request(uint64 id, td_api::searchStickers &request);

  void on_request(uint64 id, const td_api::getGreetingStickers &request);

  void on_request(uint64 id, const td_api::getPremiumStickers &request);

  void on_request(uint64 id, const td_api::getInstalledStickerSets &request);

  void on_request(uint64 id, const td_api::getArchivedStickerSets &request);

  void on_request(uint64 id, const td_api::getTrendingStickerSets &request);

  void on_request(uint64 id, const td_api::getAttachedStickerSets &request);

  void on_request(uint64 id, const td_api::getStickerSet &request);

  void on_request(uint64 id, const td_api::getStickerSetName &request);

  void on_request(uint64 id, td_api::searchStickerSet &request);

  void on_request(uint64 id, td_api::searchInstalledStickerSets &request);

  void on_request(uint64 id, td_api::searchStickerSets &request);

  void on_request(uint64 id, const td_api::changeStickerSet &request);

  void on_request(uint64 id, const td_api::viewTrendingStickerSets &request);

  void on_request(uint64 id, const td_api::reorderInstalledStickerSets &request);

  void on_request(uint64 id, td_api::uploadStickerFile &request);

  void on_request(uint64 id, td_api::getSuggestedStickerSetName &request);

  void on_request(uint64 id, td_api::checkStickerSetName &request);

  void on_request(uint64 id, td_api::createNewStickerSet &request);

  void on_request(uint64 id, td_api::addStickerToSet &request);

  void on_request(uint64 id, td_api::replaceStickerInSet &request);

  void on_request(uint64 id, td_api::setStickerSetThumbnail &request);

  void on_request(uint64 id, td_api::setCustomEmojiStickerSetThumbnail &request);

  void on_request(uint64 id, td_api::setStickerSetTitle &request);

  void on_request(uint64 id, td_api::deleteStickerSet &request);

  void on_request(uint64 id, const td_api::setStickerPositionInSet &request);

  void on_request(uint64 id, const td_api::removeStickerFromSet &request);

  void on_request(uint64 id, td_api::setStickerEmojis &request);

  void on_request(uint64 id, td_api::setStickerKeywords &request);

  void on_request(uint64 id, td_api::setStickerMaskPosition &request);

  void on_request(uint64 id, const td_api::getOwnedStickerSets &request);

  void on_request(uint64 id, const td_api::getRecentStickers &request);

  void on_request(uint64 id, td_api::addRecentSticker &request);

  void on_request(uint64 id, td_api::removeRecentSticker &request);

  void on_request(uint64 id, const td_api::clearRecentStickers &request);

  void on_request(uint64 id, const td_api::getSavedAnimations &request);

  void on_request(uint64 id, td_api::addSavedAnimation &request);

  void on_request(uint64 id, td_api::removeSavedAnimation &request);

  void on_request(uint64 id, td_api::getStickerEmojis &request);

  void on_request(uint64 id, td_api::searchEmojis &request);

  void on_request(uint64 id, td_api::getKeywordEmojis &request);

  void on_request(uint64 id, const td_api::getEmojiCategories &request);

  void on_request(uint64 id, td_api::getAnimatedEmoji &request);

  void on_request(uint64 id, td_api::getEmojiSuggestionsUrl &request);

  void on_request(uint64 id, const td_api::getCustomEmojiStickers &request);

  void on_request(uint64 id, const td_api::getDefaultChatPhotoCustomEmojiStickers &request);

  void on_request(uint64 id, const td_api::getDefaultProfilePhotoCustomEmojiStickers &request);

  void on_request(uint64 id, const td_api::getDefaultBackgroundCustomEmojiStickers &request);

  void on_request(uint64 id, const td_api::getDisallowedChatEmojiStatuses &request);

  void on_request(uint64 id, const td_api::getFavoriteStickers &request);

  void on_request(uint64 id, td_api::addFavoriteSticker &request);

  void on_request(uint64 id, td_api::removeFavoriteSticker &request);

  void on_request(uint64 id, const td_api::getSavedNotificationSound &request);

  void on_request(uint64 id, const td_api::getSavedNotificationSounds &request);

  void on_request(uint64 id, td_api::addSavedNotificationSound &request);

  void on_request(uint64 id, const td_api::removeSavedNotificationSound &request);

  void on_request(uint64 id, const td_api::getChatNotificationSettingsExceptions &request);

  void on_request(uint64 id, const td_api::getScopeNotificationSettings &request);

  void on_request(uint64 id, td_api::setChatNotificationSettings &request);

  void on_request(uint64 id, td_api::setForumTopicNotificationSettings &request);

  void on_request(uint64 id, td_api::setScopeNotificationSettings &request);

  void on_request(uint64 id, td_api::setReactionNotificationSettings &request);

  void on_request(uint64 id, const td_api::resetAllNotificationSettings &request);

  void on_request(uint64 id, const td_api::removeChatActionBar &request);

  void on_request(uint64 id, td_api::reportChat &request);

  void on_request(uint64 id, td_api::reportChatPhoto &request);

  void on_request(uint64 id, const td_api::reportMessageReactions &request);

  void on_request(uint64 id, const td_api::getChatStatistics &request);

  void on_request(uint64 id, const td_api::getChatRevenueStatistics &request);

  void on_request(uint64 id, const td_api::getChatRevenueWithdrawalUrl &request);

  void on_request(uint64 id, const td_api::getChatRevenueTransactions &request);

  void on_request(uint64 id, const td_api::getStarRevenueStatistics &request);

  void on_request(uint64 id, const td_api::getStarWithdrawalUrl &request);

  void on_request(uint64 id, const td_api::getStarAdAccountUrl &request);

  void on_request(uint64 id, const td_api::getMessageStatistics &request);

  void on_request(uint64 id, const td_api::getStoryStatistics &request);

  void on_request(uint64 id, td_api::getStatisticalGraph &request);

  void on_request(uint64 id, const td_api::getMapThumbnailFile &request);

  void on_request(uint64 id, const td_api::getLocalizationTargetInfo &request);

  void on_request(uint64 id, td_api::getLanguagePackInfo &request);

  void on_request(uint64 id, td_api::getLanguagePackStrings &request);

  void on_request(uint64 id, td_api::synchronizeLanguagePack &request);

  void on_request(uint64 id, td_api::addCustomServerLanguagePack &request);

  void on_request(uint64 id, td_api::setCustomLanguagePack &request);

  void on_request(uint64 id, td_api::editCustomLanguagePackInfo &request);

  void on_request(uint64 id, td_api::setCustomLanguagePackString &request);

  void on_request(uint64 id, td_api::deleteLanguagePack &request);

  void on_request(uint64 id, td_api::getOption &request);

  void on_request(uint64 id, td_api::setOption &request);

  void on_request(uint64 id, td_api::setPollAnswer &request);

  void on_request(uint64 id, const td_api::getPollVoters &request);

  void on_request(uint64 id, td_api::stopPoll &request);

  void on_request(uint64 id, const td_api::hideSuggestedAction &request);

  void on_request(uint64 id, const td_api::hideContactCloseBirthdays &request);

  void on_request(uint64 id, td_api::getBusinessConnection &request);

  void on_request(uint64 id, const td_api::getLoginUrlInfo &request);

  void on_request(uint64 id, const td_api::getLoginUrl &request);

  void on_request(uint64 id, const td_api::shareUsersWithBot &request);

  void on_request(uint64 id, const td_api::shareChatWithBot &request);

  void on_request(uint64 id, td_api::getInlineQueryResults &request);

  void on_request(uint64 id, td_api::answerInlineQuery &request);

  void on_request(uint64 id, td_api::savePreparedInlineMessage &request);

  void on_request(uint64 id, td_api::getPreparedInlineMessage &request);

  void on_request(uint64 id, td_api::getGrossingWebAppBots &request);

  void on_request(uint64 id, td_api::searchWebApp &request);

  void on_request(uint64 id, const td_api::getWebAppPlaceholder &request);

  void on_request(uint64 id, td_api::getWebAppLinkUrl &request);

  void on_request(uint64 id, td_api::getMainWebApp &request);

  void on_request(uint64 id, td_api::getWebAppUrl &request);

  void on_request(uint64 id, td_api::sendWebAppData &request);

  void on_request(uint64 id, td_api::openWebApp &request);

  void on_request(uint64 id, const td_api::closeWebApp &request);

  void on_request(uint64 id, td_api::answerWebAppQuery &request);

  void on_request(uint64 id, td_api::checkWebAppFileDownload &request);

  void on_request(uint64 id, td_api::getCallbackQueryAnswer &request);

  void on_request(uint64 id, td_api::answerCallbackQuery &request);

  void on_request(uint64 id, td_api::answerShippingQuery &request);

  void on_request(uint64 id, td_api::answerPreCheckoutQuery &request);

  void on_request(uint64 id, td_api::getBankCardInfo &request);

  void on_request(uint64 id, td_api::getPaymentForm &request);

  void on_request(uint64 id, td_api::validateOrderInfo &request);

  void on_request(uint64 id, td_api::sendPaymentForm &request);

  void on_request(uint64 id, const td_api::getPaymentReceipt &request);

  void on_request(uint64 id, const td_api::getSavedOrderInfo &request);

  void on_request(uint64 id, const td_api::deleteSavedOrderInfo &request);

  void on_request(uint64 id, const td_api::deleteSavedCredentials &request);

  void on_request(uint64 id, const td_api::getAvailableGifts &request);

  void on_request(uint64 id, td_api::sendGift &request);

  void on_request(uint64 id, const td_api::sellGift &request);

  void on_request(uint64 id, const td_api::toggleGiftIsSaved &request);

  void on_request(uint64 id, const td_api::setPinnedGifts &request);

  void on_request(uint64 id, const td_api::toggleChatGiftNotifications &request);

  void on_request(uint64 id, const td_api::getGiftUpgradePreview &request);

  void on_request(uint64 id, const td_api::upgradeGift &request);

  void on_request(uint64 id, const td_api::transferGift &request);

  void on_request(uint64 id, td_api::getReceivedGifts &request);

  void on_request(uint64 id, const td_api::getReceivedGift &request);

  void on_request(uint64 id, td_api::getUpgradedGift &request);

  void on_request(uint64 id, const td_api::getUpgradedGiftWithdrawalUrl &request);

  void on_request(uint64 id, td_api::createInvoiceLink &request);

  void on_request(uint64 id, td_api::refundStarPayment &request);

  void on_request(uint64 id, td_api::getPassportElement &request);

  void on_request(uint64 id, td_api::getAllPassportElements &request);

  void on_request(uint64 id, td_api::setPassportElement &request);

  void on_request(uint64 id, const td_api::deletePassportElement &request);

  void on_request(uint64 id, td_api::setPassportElementErrors &request);

  void on_request(uint64 id, td_api::getPreferredCountryLanguage &request);

  void on_request(uint64 id, td_api::sendEmailAddressVerificationCode &request);

  void on_request(uint64 id, const td_api::resendEmailAddressVerificationCode &request);

  void on_request(uint64 id, td_api::checkEmailAddressVerificationCode &request);

  void on_request(uint64 id, td_api::getPassportAuthorizationForm &request);

  void on_request(uint64 id, td_api::getPassportAuthorizationFormAvailableElements &request);

  void on_request(uint64 id, td_api::sendPassportAuthorizationForm &request);

  void on_request(uint64 id, const td_api::getSupportUser &request);

  void on_request(uint64 id, const td_api::getInstalledBackgrounds &request);

  void on_request(uint64 id, td_api::getBackgroundUrl &request);

  void on_request(uint64 id, td_api::searchBackground &request);

  void on_request(uint64 id, const td_api::setDefaultBackground &request);

  void on_request(uint64 id, const td_api::deleteDefaultBackground &request);

  void on_request(uint64 id, const td_api::removeInstalledBackground &request);

  void on_request(uint64 id, const td_api::resetInstalledBackgrounds &request);

  void on_request(uint64 id, td_api::getRecentlyVisitedTMeUrls &request);

  void on_request(uint64 id, td_api::setBotUpdatesStatus &request);

  void on_request(uint64 id, td_api::sendCustomRequest &request);

  void on_request(uint64 id, td_api::answerCustomQuery &request);

  void on_request(uint64 id, const td_api::setAlarm &request);

  void on_request(uint64 id, td_api::searchHashtags &request);

  void on_request(uint64 id, td_api::removeRecentHashtag &request);

  void on_request(uint64 id, const td_api::getPremiumLimit &request);

  void on_request(uint64 id, const td_api::getPremiumFeatures &request);

  void on_request(uint64 id, const td_api::getPremiumStickerExamples &request);

  void on_request(uint64 id, const td_api::getPremiumInfoSticker &request);

  void on_request(uint64 id, const td_api::viewPremiumFeature &request);

  void on_request(uint64 id, const td_api::clickPremiumSubscriptionButton &request);

  void on_request(uint64 id, const td_api::getPremiumState &request);

  void on_request(uint64 id, const td_api::getPremiumGiftPaymentOptions &request);

  void on_request(uint64 id, const td_api::getPremiumGiveawayPaymentOptions &request);

  void on_request(uint64 id, td_api::checkPremiumGiftCode &request);

  void on_request(uint64 id, td_api::applyPremiumGiftCode &request);

  void on_request(uint64 id, td_api::launchPrepaidGiveaway &request);

  void on_request(uint64 id, const td_api::getGiveawayInfo &request);

  void on_request(uint64 id, const td_api::getStarPaymentOptions &request);

  void on_request(uint64 id, const td_api::getStarGiftPaymentOptions &request);

  void on_request(uint64 id, const td_api::getStarGiveawayPaymentOptions &request);

  void on_request(uint64 id, td_api::getStarTransactions &request);

  void on_request(uint64 id, td_api::getStarSubscriptions &request);

  void on_request(uint64 id, td_api::editStarSubscription &request);

  void on_request(uint64 id, td_api::editUserStarSubscription &request);

  void on_request(uint64 id, td_api::reuseStarSubscription &request);

  void on_request(uint64 id, const td_api::setChatAffiliateProgram &request);

  void on_request(uint64 id, td_api::searchChatAffiliateProgram &request);

  void on_request(uint64 id, td_api::searchAffiliatePrograms &request);

  void on_request(uint64 id, const td_api::connectAffiliateProgram &request);

  void on_request(uint64 id, td_api::disconnectAffiliateProgram &request);

  void on_request(uint64 id, const td_api::getConnectedAffiliateProgram &request);

  void on_request(uint64 id, td_api::getConnectedAffiliatePrograms &request);

  void on_request(uint64 id, td_api::canPurchaseFromStore &request);

  void on_request(uint64 id, td_api::assignAppStoreTransaction &request);

  void on_request(uint64 id, td_api::assignGooglePlayTransaction &request);

  void on_request(uint64 id, const td_api::getBusinessFeatures &request);

  void on_request(uint64 id, td_api::acceptTermsOfService &request);

  void on_request(uint64 id, const td_api::getCountries &request);

  void on_request(uint64 id, const td_api::getCountryCode &request);

  void on_request(uint64 id, const td_api::getPhoneNumberInfo &request);

  void on_request(uint64 id, td_api::getCollectibleItemInfo &request);

  void on_request(uint64 id, const td_api::getApplicationDownloadLink &request);

  void on_request(uint64 id, td_api::getDeepLinkInfo &request);

  void on_request(uint64 id, const td_api::getApplicationConfig &request);

  void on_request(uint64 id, td_api::saveApplicationLogEvent &request);

  void on_request(uint64 id, td_api::addProxy &request);

  void on_request(uint64 id, td_api::editProxy &request);

  void on_request(uint64 id, const td_api::enableProxy &request);

  void on_request(uint64 id, const td_api::disableProxy &request);

  void on_request(uint64 id, const td_api::removeProxy &request);

  void on_request(uint64 id, const td_api::getProxies &request);

  void on_request(uint64 id, const td_api::getProxyLink &request);

  void on_request(uint64 id, const td_api::pingProxy &request);

  void on_request(uint64 id, const td_api::getUserSupportInfo &request);

  void on_request(uint64 id, td_api::setUserSupportInfo &request);

  void on_request(uint64 id, const td_api::getSupportName &request);

  void on_request(uint64 id, const td_api::searchQuote &request);

  void on_request(uint64 id, const td_api::getTextEntities &request);

  void on_request(uint64 id, const td_api::parseTextEntities &request);

  void on_request(uint64 id, const td_api::parseMarkdown &request);

  void on_request(uint64 id, const td_api::getMarkdownText &request);

  void on_request(uint64 id, const td_api::searchStringsByPrefix &request);

  void on_request(uint64 id, const td_api::checkQuickReplyShortcutName &request);

  void on_request(uint64 id, const td_api::getCountryFlagEmoji &request);

  void on_request(uint64 id, const td_api::getFileMimeType &request);

  void on_request(uint64 id, const td_api::getFileExtension &request);

  void on_request(uint64 id, const td_api::cleanFileName &request);

  void on_request(uint64 id, const td_api::getLanguagePackString &request);

  void on_request(uint64 id, const td_api::getPhoneNumberInfoSync &request);

  void on_request(uint64 id, const td_api::getPushReceiverId &request);

  void on_request(uint64 id, const td_api::getChatFolderDefaultIconName &request);

  void on_request(uint64 id, const td_api::getJsonValue &request);

  void on_request(uint64 id, const td_api::getJsonString &request);

  void on_request(uint64 id, const td_api::getThemeParametersJsonString &request);

  void on_request(uint64 id, const td_api::setLogStream &request);

  void on_request(uint64 id, const td_api::getLogStream &request);

  void on_request(uint64 id, const td_api::setLogVerbosityLevel &request);

  void on_request(uint64 id, const td_api::getLogVerbosityLevel &request);

  void on_request(uint64 id, const td_api::getLogTags &request);

  void on_request(uint64 id, const td_api::setLogTagVerbosityLevel &request);

  void on_request(uint64 id, const td_api::getLogTagVerbosityLevel &request);

  void on_request(uint64 id, const td_api::addLogMessage &request);

  void on_request(uint64 id, const td_api::testNetwork &request);

  void on_request(uint64 id, td_api::testProxy &request);

  void on_request(uint64 id, const td_api::testGetDifference &request);

  void on_request(uint64 id, const td_api::testUseUpdate &request);

  void on_request(uint64 id, const td_api::testReturnError &request);

  void on_request(uint64 id, const td_api::testCallEmpty &request);

  void on_request(uint64 id, const td_api::testSquareInt &request);

  void on_request(uint64 id, td_api::testCallString &request);

  void on_request(uint64 id, td_api::testCallBytes &request);

  void on_request(uint64 id, td_api::testCallVectorInt &request);

  void on_request(uint64 id, td_api::testCallVectorIntObject &request);

  void on_request(uint64 id, td_api::testCallVectorString &request);

  void on_request(uint64 id, td_api::testCallVectorStringObject &request);
};

}  // namespace td
