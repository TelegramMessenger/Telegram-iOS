//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/HashtagHints.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MediaArea.hpp"
#include "td/telegram/MessageEntity.hpp"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/ReactionType.hpp"
#include "td/telegram/StoryContent.h"
#include "td/telegram/StoryContentType.h"
#include "td/telegram/StoryForwardInfo.h"
#include "td/telegram/StoryForwardInfo.hpp"
#include "td/telegram/StoryInteractionInfo.hpp"
#include "td/telegram/StoryStealthMode.hpp"
#include "td/telegram/StoryViewer.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/WebPagesManager.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/actor/MultiPromise.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

#include <limits>

namespace td {

class GetAllStoriesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_AllStories>> promise_;

 public:
  explicit GetAllStoriesQuery(Promise<telegram_api::object_ptr<telegram_api::stories_AllStories>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(StoryListId story_list_id, bool is_next, const string &state) {
    int32 flags = 0;
    if (!state.empty()) {
      flags |= telegram_api::stories_getAllStories::STATE_MASK;
    }
    if (is_next) {
      flags |= telegram_api::stories_getAllStories::NEXT_MASK;
    }
    if (story_list_id == StoryListId::archive()) {
      flags |= telegram_api::stories_getAllStories::HIDDEN_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getAllStories(flags, false /*ignored*/, false /*ignored*/, state)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getAllStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetAllStoriesQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleStoriesHiddenQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool are_hidden_ = false;

 public:
  explicit ToggleStoriesHiddenQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool are_hidden) {
    dialog_id_ = dialog_id;
    are_hidden_ = are_hidden;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::stories_togglePeerStoriesHidden(std::move(input_peer), are_hidden), {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_togglePeerStoriesHidden>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ToggleStoriesHiddenQuery: " << result;
    if (result) {
      td_->story_manager_->on_update_dialog_stories_hidden(dialog_id_, are_hidden_);
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleStoriesHiddenQuery");
    promise_.set_error(std::move(status));
  }
};

class GetAllReadPeerStoriesQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::stories_getAllReadPeerStories()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getAllReadPeerStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetAllReadPeerStoriesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetAllReadPeerStoriesQuery: " << status;
  }
};

class ToggleAllStoriesHiddenQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleAllStoriesHiddenQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool all_stories_hidden) {
    send_query(
        G()->net_query_creator().create(telegram_api::stories_toggleAllStoriesHidden(all_stories_hidden), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_toggleAllStoriesHidden>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ToggleAllStoriesHiddenQuery: " << result;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class IncrementStoryViewsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit IncrementStoryViewsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const vector<StoryId> &story_ids) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_incrementStoryViews(std::move(input_peer), StoryId::get_input_story_ids(story_ids)),
        {{"view_story"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_incrementStoryViews>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "IncrementStoryViewsQuery");
    promise_.set_error(std::move(status));
  }
};

class ReadStoriesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ReadStoriesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId max_read_story_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_readStories(std::move(input_peer), max_read_story_id.get()), {{"view_story"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_readStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReadStoriesQuery");
    promise_.set_error(std::move(status));
  }
};

class SendStoryReactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SendStoryReactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(StoryFullId story_full_id, const ReactionType &reaction_type, bool add_to_recent) {
    dialog_id_ = story_full_id.get_dialog_id();

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    CHECK(!reaction_type.is_paid_reaction());

    int32 flags = 0;
    if (!reaction_type.is_empty() && add_to_recent) {
      flags |= telegram_api::stories_sendReaction::ADD_TO_RECENT_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::stories_sendReaction(flags, false /*ignored*/, std::move(input_peer),
                                           story_full_id.get_story_id().get(), reaction_type.get_input_reaction()),
        {{story_full_id}, {"view_story"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_sendReaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendStoryReactionQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "STORY_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendStoryReactionQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoryViewsListQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStoryViewsListQuery(Promise<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId story_id, const string &query, bool only_contacts, bool prefer_forwards,
            bool prefer_with_reaction, const string &offset, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (!query.empty()) {
      flags |= telegram_api::stories_getStoryViewsList::Q_MASK;
    }
    if (only_contacts) {
      flags |= telegram_api::stories_getStoryViewsList::JUST_CONTACTS_MASK;
    }
    if (prefer_forwards) {
      flags |= telegram_api::stories_getStoryViewsList::FORWARDS_FIRST_MASK;
    }
    if (prefer_with_reaction) {
      flags |= telegram_api::stories_getStoryViewsList::REACTIONS_FIRST_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getStoryViewsList(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                                std::move(input_peer), query, story_id.get(), offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getStoryViewsList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStoryViewsListQuery: " << to_string(result);
    td_->story_manager_->get_channel_differences_if_needed(std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoryViewsListQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoryReactionsListQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStoryReactionsListQuery(
      Promise<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(StoryFullId story_full_id, const ReactionType &reaction_type, bool prefer_forwards, const string &offset,
            int32 limit) {
    dialog_id_ = story_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    CHECK(!reaction_type.is_paid_reaction());

    int32 flags = 0;
    if (!reaction_type.is_empty()) {
      flags |= telegram_api::stories_getStoryReactionsList::REACTION_MASK;
    }
    if (!offset.empty()) {
      flags |= telegram_api::stories_getStoryReactionsList::OFFSET_MASK;
    }
    if (prefer_forwards) {
      flags |= telegram_api::stories_getStoryReactionsList::FORWARDS_FIRST_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::stories_getStoryReactionsList(
        flags, false /*ignored*/, std::move(input_peer), story_full_id.get_story_id().get(),
        reaction_type.get_input_reaction(), offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getStoryReactionsList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStoryReactionsListQuery: " << to_string(result);
    td_->story_manager_->get_channel_differences_if_needed(std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoryReactionsListQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoriesByIDQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  vector<StoryId> story_ids_;

 public:
  explicit GetStoriesByIDQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, vector<StoryId> story_ids) {
    dialog_id_ = dialog_id;
    story_ids_ = std::move(story_ids);
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getStoriesByID(std::move(input_peer), StoryId::get_input_story_ids(story_ids_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getStoriesByID>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStoriesByIDQuery: " << to_string(result);
    td_->story_manager_->on_get_stories(dialog_id_, std::move(story_ids_), std::move(result));
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoriesByIDQuery");
    promise_.set_error(std::move(status));
  }
};

class GetPinnedStoriesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_stories>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetPinnedStoriesQuery(Promise<telegram_api::object_ptr<telegram_api::stories_stories>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId offset_story_id, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getPinnedStories(std::move(input_peer), offset_story_id.get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getPinnedStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetPinnedStoriesQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPinnedStoriesQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoriesArchiveQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_stories>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStoriesArchiveQuery(Promise<telegram_api::object_ptr<telegram_api::stories_stories>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId offset_story_id, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getStoriesArchive(std::move(input_peer), offset_story_id.get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getStoriesArchive>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStoriesArchiveQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoriesArchiveQuery");
    promise_.set_error(std::move(status));
  }
};

class GetPeerStoriesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::stories_peerStories>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetPeerStoriesQuery(Promise<telegram_api::object_ptr<telegram_api::stories_peerStories>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(
        G()->net_query_creator().create(telegram_api::stories_getPeerStories(std::move(input_peer)), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getPeerStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetPeerStoriesQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPeerStoriesQuery");
    promise_.set_error(std::move(status));
  }
};

class EditStoryCoverQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  StoryId story_id_;
  double main_frame_timestamp_;
  FileId file_id_;
  string file_reference_;

 public:
  explicit EditStoryCoverQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId owner_dialog_id, StoryId story_id, double main_frame_timestamp, FileId file_id,
            telegram_api::object_ptr<telegram_api::InputMedia> input_media) {
    dialog_id_ = owner_dialog_id;
    story_id_ = story_id;
    main_frame_timestamp_ = main_frame_timestamp;
    file_id_ = file_id;
    file_reference_ = FileManager::extract_file_reference(input_media);
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(
        telegram_api::stories_editStory(telegram_api::stories_editStory::MEDIA_MASK, std::move(input_peer),
                                        story_id.get(), std::move(input_media),
                                        vector<telegram_api::object_ptr<telegram_api::MediaArea>>(), string(),
                                        vector<telegram_api::object_ptr<telegram_api::MessageEntity>>(), Auto()),
        {{StoryFullId{dialog_id_, story_id}}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_editStory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditStoryCoverQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for EditStoryCoverQuery: " << status;
    if (!td_->auth_manager_->is_bot() && status.message() == "STORY_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_, PromiseCreator::lambda([dialog_id = dialog_id_, story_id = story_id_,
                                            main_frame_timestamp = main_frame_timestamp_,
                                            promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              return promise.set_error(Status::Error(400, "Failed to edit cover"));
            }

            send_closure(G()->story_manager(), &StoryManager::edit_story_cover, dialog_id, story_id,
                         main_frame_timestamp, std::move(promise));
          }));
      return;
    }

    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditStoryCoverQuery");
    promise_.set_error(std::move(status));
  }
};

class EditStoryPrivacyQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit EditStoryPrivacyQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId story_id, UserPrivacySettingRules &&privacy_rules) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = telegram_api::stories_editStory::PRIVACY_RULES_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::stories_editStory(flags, std::move(input_peer), story_id.get(), nullptr,
                                        vector<telegram_api::object_ptr<telegram_api::MediaArea>>(), string(),
                                        vector<telegram_api::object_ptr<telegram_api::MessageEntity>>(),
                                        privacy_rules.get_input_privacy_rules(td_)),
        {{StoryFullId{dialog_id, story_id}}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_editStory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for EditStoryPrivacyQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && status.message() == "STORY_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditStoryPrivacyQuery");
    promise_.set_error(std::move(status));
  }
};

class ToggleStoryPinnedQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ToggleStoryPinnedQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, StoryId story_id, bool is_pinned) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_togglePinned(std::move(input_peer), {story_id.get()}, is_pinned),
        {{StoryFullId{dialog_id, story_id}}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_togglePinned>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ToggleStoryPinnedQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleStoryPinnedQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteStoriesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit DeleteStoriesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const vector<StoryId> &story_ids) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_deleteStories(std::move(input_peer), StoryId::get_input_story_ids(story_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_deleteStories>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for DeleteStoriesQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteStoriesQuery");
    promise_.set_error(std::move(status));
  }
};

class SearchStoriesQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundStories>> promise_;
  DialogId dialog_id_;

 public:
  explicit SearchStoriesQuery(Promise<td_api::object_ptr<td_api::foundStories>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, string hashtag, const string &offset, int32 limit) {
    dialog_id_ = dialog_id;
    int32 flags = telegram_api::stories_searchPosts::HASHTAG_MASK;
    telegram_api::object_ptr<telegram_api::InputPeer> input_peer;
    if (dialog_id != DialogId()) {
      flags |= telegram_api::stories_searchPosts::PEER_MASK;
      input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
      CHECK(input_peer != nullptr);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_searchPosts(flags, hashtag, nullptr, std::move(input_peer), offset, limit)));
  }

  void send(td_api::object_ptr<td_api::locationAddress> &&address, const string &offset, int32 limit) {
    int32 flags = telegram_api::stories_searchPosts::AREA_MASK;

    int32 address_flags = 0;
    if (!address->state_.empty()) {
      address_flags |= telegram_api::geoPointAddress::STATE_MASK;
    }
    if (!address->city_.empty()) {
      address_flags |= telegram_api::geoPointAddress::CITY_MASK;
    }
    if (!address->street_.empty()) {
      address_flags |= telegram_api::geoPointAddress::STREET_MASK;
    }

    auto area = telegram_api::make_object<telegram_api::mediaAreaGeoPoint>(
        telegram_api::mediaAreaGeoPoint::ADDRESS_MASK,
        telegram_api::make_object<telegram_api::mediaAreaCoordinates>(0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        telegram_api::make_object<telegram_api::geoPoint>(0, 0.0, 0.0, 0, 0),
        telegram_api::make_object<telegram_api::geoPointAddress>(address_flags, address->country_code_, address->state_,
                                                                 address->city_, address->street_));
    send_query(G()->net_query_creator().create(
        telegram_api::stories_searchPosts(flags, string(), std::move(area), nullptr, offset, limit)));
  }

  void send(const string &venue_provider, const string &venue_id, const string &offset, int32 limit) {
    int32 flags = telegram_api::stories_searchPosts::AREA_MASK;
    auto area = telegram_api::make_object<telegram_api::mediaAreaVenue>(
        telegram_api::make_object<telegram_api::mediaAreaCoordinates>(0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        telegram_api::make_object<telegram_api::geoPoint>(0, 0.0, 0.0, 0, 0), string(), string(), venue_provider,
        venue_id, string());
    send_query(G()->net_query_creator().create(
        telegram_api::stories_searchPosts(flags, string(), std::move(area), nullptr, offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_searchPosts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for SearchStoriesQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "SearchStoriesQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "SearchStoriesQuery");

    auto total_count = ptr->count_;
    if (total_count < static_cast<int32>(ptr->stories_.size())) {
      LOG(ERROR) << "Receive total count = " << total_count << " and " << ptr->stories_.size() << " stories";
      total_count = static_cast<int32>(ptr->stories_.size());
    }
    vector<td_api::object_ptr<td_api::story>> stories;
    for (auto &found_story : ptr->stories_) {
      DialogId owner_dialog_id(found_story->peer_);
      auto story_id = td_->story_manager_->on_get_story(owner_dialog_id, std::move(found_story->story_));
      if (story_id.is_valid()) {
        auto story_object = td_->story_manager_->get_story_object({owner_dialog_id, story_id});
        if (story_object == nullptr) {
          LOG(ERROR) << "Receive deleted " << story_id << " from " << owner_dialog_id;
        } else {
          stories.push_back(std::move(story_object));
        }
      }
    }

    promise_.set_value(td_api::make_object<td_api::foundStories>(total_count, std::move(stories), ptr->next_offset_));
  }

  void on_error(Status status) final {
    if (status.message() == "SEARCH_QUERY_EMPTY") {
      return promise_.set_value(td_api::make_object<td_api::foundStories>());
    }
    if (dialog_id_ != DialogId()) {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SearchStoriesQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class TogglePinnedStoriesToTopQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit TogglePinnedStoriesToTopQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, vector<StoryId> story_ids) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::stories_togglePinnedToTop(std::move(input_peer), StoryId::get_input_story_ids(story_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_togglePinnedToTop>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for TogglePinnedStoriesToTopQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoriesViewsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoriesViewsQuery final : public Td::ResultHandler {
  vector<StoryId> story_ids_;
  DialogId dialog_id_;

 public:
  void send(DialogId dialog_id, vector<StoryId> story_ids) {
    dialog_id_ = dialog_id;
    story_ids_ = std::move(story_ids);
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stories_getStoriesViews(std::move(input_peer), StoryId::get_input_story_ids(story_ids_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getStoriesViews>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStoriesViewsQuery: " << to_string(ptr);
    td_->story_manager_->on_get_story_views(dialog_id_, story_ids_, std::move(ptr));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetStoriesViewsQuery for " << story_ids_ << ": " << status;
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStoriesViewsQuery");
  }
};

class ReportStoryQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::ReportStoryResult>> promise_;
  DialogId dialog_id_;

 public:
  explicit ReportStoryQuery(Promise<td_api::object_ptr<td_api::ReportStoryResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(StoryFullId story_full_id, const string &option_id, const string &text) {
    dialog_id_ = story_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::stories_report(
        std::move(input_peer), {story_full_id.get_story_id().get()}, BufferSlice(option_id), text)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_report>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ReportStoryQuery: " << to_string(ptr);
    switch (ptr->get_id()) {
      case telegram_api::reportResultReported::ID:
        return promise_.set_value(td_api::make_object<td_api::reportStoryResultOk>());
      case telegram_api::reportResultChooseOption::ID: {
        auto options = telegram_api::move_object_as<telegram_api::reportResultChooseOption>(ptr);
        if (options->options_.empty()) {
          return promise_.set_value(td_api::make_object<td_api::reportStoryResultOk>());
        }
        vector<td_api::object_ptr<td_api::reportOption>> report_options;
        for (auto &option : options->options_) {
          report_options.push_back(
              td_api::make_object<td_api::reportOption>(option->option_.as_slice().str(), option->text_));
        }
        return promise_.set_value(
            td_api::make_object<td_api::reportStoryResultOptionRequired>(options->title_, std::move(report_options)));
      }
      case telegram_api::reportResultAddComment::ID: {
        auto option = telegram_api::move_object_as<telegram_api::reportResultAddComment>(ptr);
        return promise_.set_value(td_api::make_object<td_api::reportStoryResultTextRequired>(
            option->option_.as_slice().str(), option->optional_));
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportStoryQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStoriesMaxIdsQuery final : public Td::ResultHandler {
  vector<DialogId> dialog_ids_;

 public:
  void send(vector<DialogId> dialog_ids, vector<telegram_api::object_ptr<telegram_api::InputPeer>> &&input_peers) {
    dialog_ids_ = std::move(dialog_ids);
    send_query(G()->net_query_creator().create(telegram_api::stories_getPeerMaxIDs(std::move(input_peers))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getPeerMaxIDs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->story_manager_->on_get_dialog_max_active_story_ids(dialog_ids_, result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    td_->story_manager_->on_get_dialog_max_active_story_ids(dialog_ids_, Auto());
  }
};

class ActivateStealthModeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ActivateStealthModeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    int32 flags =
        telegram_api::stories_activateStealthMode::PAST_MASK | telegram_api::stories_activateStealthMode::FUTURE_MASK;

    send_query(G()->net_query_creator().create(
        telegram_api::stories_activateStealthMode(flags, false /*ignored*/, false /*ignored*/), {{"view_story"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_activateStealthMode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ActivateStealthModeQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetChatsToSendStoriesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetChatsToSendStoriesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::stories_getChatsToSend()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_getChatsToSend>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChatsToSendStoriesQuery: " << to_string(chats_ptr);
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->story_manager_->on_get_dialogs_to_send_stories(std::move(chats->chats_));
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        LOG(ERROR) << "Receive chatsSlice in result of GetCreatedPublicChannelsQuery";
        td_->story_manager_->on_get_dialogs_to_send_stories(std::move(chats->chats_));
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CanSendStoryQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::CanSendStoryResult>> promise_;
  DialogId dialog_id_;

 public:
  explicit CanSendStoryQuery(Promise<td_api::object_ptr<td_api::CanSendStoryResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(telegram_api::stories_canSendStory(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_canSendStory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(td_api::make_object<td_api::canSendStoryResultOk>());
  }

  void on_error(Status status) final {
    auto result = StoryManager::get_can_send_story_result_object(status);
    if (result != nullptr) {
      return promise_.set_value(std::move(result));
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "CanSendStoryQuery");
    promise_.set_error(std::move(status));
  }
};

class StoryManager::SendStoryQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  unique_ptr<PendingStory> pending_story_;

 public:
  void send(unique_ptr<PendingStory> pending_story, telegram_api::object_ptr<telegram_api::InputFile> input_file) {
    pending_story_ = std::move(pending_story);
    CHECK(pending_story_ != nullptr);
    dialog_id_ = pending_story_->dialog_id_;

    const auto *story = pending_story_->story_.get();
    const StoryContent *content = story->content_.get();
    CHECK(input_file != nullptr);
    auto input_media = get_story_content_input_media(td_, content, std::move(input_file));
    CHECK(input_media != nullptr);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    telegram_api::object_ptr<telegram_api::InputPeer> fwd_input_peer;
    int32 fwd_story_id = 0;
    if (story->forward_info_ != nullptr) {
      fwd_input_peer = td_->dialog_manager_->get_input_peer(pending_story_->forward_from_story_full_id_.get_dialog_id(),
                                                            AccessRights::Read);
      if (fwd_input_peer == nullptr) {
        return on_error(Status::Error(400, "Can't access the story to repost"));
      }
      fwd_story_id = pending_story_->forward_from_story_full_id_.get_story_id().get();
    }

    const FormattedText &caption = story->caption_;
    auto entities = get_input_message_entities(td_->user_manager_.get(), &caption, "SendStoryQuery");
    if (!td_->option_manager_->get_option_boolean("can_use_text_entities_in_story_caption")) {
      entities.clear();
    }
    auto privacy_rules = story->privacy_rules_.get_input_privacy_rules(td_);
    auto period = story->expire_date_ - story->date_;
    int32 flags = 0;
    if (!caption.text.empty()) {
      flags |= telegram_api::stories_sendStory::CAPTION_MASK;
    }
    if (!entities.empty()) {
      flags |= telegram_api::stories_sendStory::ENTITIES_MASK;
    }
    if (pending_story_->story_->is_pinned_) {
      flags |= telegram_api::stories_sendStory::PINNED_MASK;
    }
    if (period != 86400) {
      flags |= telegram_api::stories_sendStory::PERIOD_MASK;
    }
    if (story->forward_info_ != nullptr) {
      flags |= telegram_api::stories_sendStory::FWD_MODIFIED_MASK;
      flags |= telegram_api::stories_sendStory::FWD_FROM_ID_MASK;
      flags |= telegram_api::stories_sendStory::FWD_FROM_STORY_MASK;
    }
    if (story->noforwards_) {
      flags |= telegram_api::stories_sendStory::NOFORWARDS_MASK;
    }
    auto input_media_areas = MediaArea::get_input_media_areas(td_, story->areas_);
    if (!input_media_areas.empty()) {
      flags |= telegram_api::stories_sendStory::MEDIA_AREAS_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::stories_sendStory(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                        std::move(input_peer), std::move(input_media), std::move(input_media_areas),
                                        caption.text, std::move(entities), std::move(privacy_rules),
                                        pending_story_->random_id_, period, std::move(fwd_input_peer), fwd_story_id),
        {{pending_story_->dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_sendStory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendStoryQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([pending_story = std::move(pending_story_)](Result<Unit> &&result) mutable {
          send_closure(G()->story_manager(), &StoryManager::delete_pending_story, std::move(pending_story),
                       result.is_ok() ? Status::OK() : result.move_as_error());
        }));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for SendStoryQuery: " << status;
    if (G()->close_flag() && G()->use_message_database()) {
      // do not send error, story will be re-sent after restart
      return;
    }

    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      td_->story_manager_->on_send_story_file_parts_missing(std::move(pending_story_), std::move(bad_parts));
      return;
    }

    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendStoryQuery");
    td_->story_manager_->delete_pending_story(std::move(pending_story_), std::move(status));
  }
};

class StoryManager::EditStoryQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  unique_ptr<PendingStory> pending_story_;

 public:
  void send(const Story *story, unique_ptr<PendingStory> pending_story,
            telegram_api::object_ptr<telegram_api::InputFile> input_file, const BeingEditedStory *edited_story) {
    pending_story_ = std::move(pending_story);
    CHECK(pending_story_ != nullptr);
    dialog_id_ = pending_story_->dialog_id_;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;

    telegram_api::object_ptr<telegram_api::InputMedia> input_media;
    const StoryContent *content = edited_story->content_.get();
    if (content != nullptr) {
      CHECK(input_file != nullptr);
      input_media = get_story_content_input_media(td_, content, std::move(input_file));
      CHECK(input_media != nullptr);
      flags |= telegram_api::stories_editStory::MEDIA_MASK;
    }
    vector<telegram_api::object_ptr<telegram_api::MediaArea>> input_media_areas;
    if (edited_story->edit_media_areas_) {
      input_media_areas = MediaArea::get_input_media_areas(td_, edited_story->areas_);
      flags |= telegram_api::stories_editStory::MEDIA_AREAS_MASK;
    }
    vector<telegram_api::object_ptr<telegram_api::MessageEntity>> entities;
    if (edited_story->edit_caption_) {
      flags |= telegram_api::stories_editStory::CAPTION_MASK;
      if (td_->option_manager_->get_option_boolean("can_use_text_entities_in_story_caption")) {
        flags |= telegram_api::stories_editStory::ENTITIES_MASK;
        entities = get_input_message_entities(td_->user_manager_.get(), &edited_story->caption_, "EditStoryQuery");
      }
    }

    send_query(G()->net_query_creator().create(
        telegram_api::stories_editStory(flags, std::move(input_peer), pending_story_->story_id_.get(),
                                        std::move(input_media), std::move(input_media_areas),
                                        edited_story->caption_.text, std::move(entities), Auto()),
        {{StoryFullId{pending_story_->dialog_id_, pending_story_->story_id_}}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stories_editStory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditStoryQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([pending_story = std::move(pending_story_)](Result<Unit> &&result) mutable {
          send_closure(G()->story_manager(), &StoryManager::delete_pending_story, std::move(pending_story),
                       result.is_ok() ? Status::OK() : result.move_as_error());
        }));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for EditStoryQuery: " << status;
    if (G()->close_flag() && G()->use_message_database()) {
      // do not send error, story will be edited after restart
      return;
    }

    if (!td_->auth_manager_->is_bot() && status.message() == "STORY_NOT_MODIFIED") {
      return td_->story_manager_->delete_pending_story(std::move(pending_story_), Status::OK());
    }

    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      td_->story_manager_->on_send_story_file_parts_missing(std::move(pending_story_), std::move(bad_parts));
      return;
    }

    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditStoryQuery");
    td_->story_manager_->delete_pending_story(std::move(pending_story_), std::move(status));
  }
};

class StoryManager::UploadMediaCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->story_manager(), &StoryManager::on_upload_story, file_upload_id, std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->story_manager(), &StoryManager::on_upload_story_error, file_upload_id, std::move(error));
  }
};

StoryManager::PendingStory::PendingStory(DialogId dialog_id, StoryId story_id, StoryFullId forward_from_story_full_id,
                                         uint32 send_story_num, int64 random_id, unique_ptr<Story> &&story)
    : dialog_id_(dialog_id)
    , story_id_(story_id)
    , forward_from_story_full_id_(forward_from_story_full_id)
    , send_story_num_(send_story_num)
    , random_id_(random_id)
    , story_(std::move(story)) {
  if (story_ != nullptr && story_->content_ != nullptr) {
    file_upload_id_ = {get_story_content_any_file_id(story_->content_.get()), FileManager::get_internal_upload_id()};
  }
}

StoryManager::ReadyToSendStory::ReadyToSendStory(unique_ptr<PendingStory> &&pending_story,
                                                 telegram_api::object_ptr<telegram_api::InputFile> &&input_file)
    : pending_story_(std::move(pending_story)), input_file_(std::move(input_file)) {
}

template <class StorerT>
void StoryManager::Story::store(StorerT &storer) const {
  using td::store;
  bool has_receive_date = receive_date_ != 0;
  bool has_interaction_info = !interaction_info_.is_empty();
  bool has_privacy_rules = privacy_rules_ != UserPrivacySettingRules();
  bool has_content = content_ != nullptr;
  bool has_caption = !caption_.text.empty();
  bool has_areas = !areas_.empty();
  bool has_chosen_reaction_type = !chosen_reaction_type_.is_empty();
  bool has_forward_info = forward_info_ != nullptr;
  bool has_sender_dialog_id = sender_dialog_id_ != DialogId();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_edited_);
  STORE_FLAG(is_pinned_);
  STORE_FLAG(is_public_);
  STORE_FLAG(is_for_close_friends_);
  STORE_FLAG(noforwards_);
  STORE_FLAG(has_receive_date);
  STORE_FLAG(has_interaction_info);
  STORE_FLAG(has_privacy_rules);
  STORE_FLAG(has_content);
  STORE_FLAG(has_caption);
  STORE_FLAG(is_for_contacts_);
  STORE_FLAG(is_for_selected_contacts_);
  STORE_FLAG(has_areas);
  STORE_FLAG(has_chosen_reaction_type);
  STORE_FLAG(is_outgoing_);
  STORE_FLAG(has_forward_info);
  STORE_FLAG(has_sender_dialog_id);
  END_STORE_FLAGS();
  store(date_, storer);
  store(expire_date_, storer);
  if (has_receive_date) {
    store(receive_date_, storer);
  }
  if (has_interaction_info) {
    store(interaction_info_, storer);
  }
  if (has_privacy_rules) {
    store(privacy_rules_, storer);
  }
  if (has_content) {
    store_story_content(content_.get(), storer);
  }
  if (has_caption) {
    store(caption_, storer);
  }
  if (has_areas) {
    store(areas_, storer);
  }
  if (has_chosen_reaction_type) {
    store(chosen_reaction_type_, storer);
  }
  if (has_forward_info) {
    store(forward_info_, storer);
  }
  if (has_sender_dialog_id) {
    store(sender_dialog_id_, storer);
  }
}

template <class ParserT>
void StoryManager::Story::parse(ParserT &parser) {
  using td::parse;
  bool has_receive_date;
  bool has_interaction_info;
  bool has_privacy_rules;
  bool has_content;
  bool has_caption;
  bool has_areas;
  bool has_chosen_reaction_type;
  bool has_forward_info;
  bool has_sender_dialog_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_edited_);
  PARSE_FLAG(is_pinned_);
  PARSE_FLAG(is_public_);
  PARSE_FLAG(is_for_close_friends_);
  PARSE_FLAG(noforwards_);
  PARSE_FLAG(has_receive_date);
  PARSE_FLAG(has_interaction_info);
  PARSE_FLAG(has_privacy_rules);
  PARSE_FLAG(has_content);
  PARSE_FLAG(has_caption);
  PARSE_FLAG(is_for_contacts_);
  PARSE_FLAG(is_for_selected_contacts_);
  PARSE_FLAG(has_areas);
  PARSE_FLAG(has_chosen_reaction_type);
  PARSE_FLAG(is_outgoing_);
  PARSE_FLAG(has_forward_info);
  PARSE_FLAG(has_sender_dialog_id);
  END_PARSE_FLAGS();
  parse(date_, parser);
  parse(expire_date_, parser);
  if (has_receive_date) {
    parse(receive_date_, parser);
  }
  if (has_interaction_info) {
    parse(interaction_info_, parser);
  }
  if (has_privacy_rules) {
    parse(privacy_rules_, parser);
  }
  if (has_content) {
    parse_story_content(content_, parser);
  }
  if (has_caption) {
    parse(caption_, parser);
  }
  if (has_areas) {
    parse(areas_, parser);
  }
  if (has_chosen_reaction_type) {
    parse(chosen_reaction_type_, parser);
  }
  if (has_forward_info) {
    parse(forward_info_, parser);
  }
  if (has_sender_dialog_id) {
    parse(sender_dialog_id_, parser);
  }
}

template <class StorerT>
void StoryManager::StoryInfo::store(StorerT &storer) const {
  using td::store;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_for_close_friends_);
  END_STORE_FLAGS();
  store(story_id_, storer);
  store(date_, storer);
  store(expire_date_, storer);
}

template <class ParserT>
void StoryManager::StoryInfo::parse(ParserT &parser) {
  using td::parse;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_for_close_friends_);
  END_PARSE_FLAGS();
  parse(story_id_, parser);
  parse(date_, parser);
  parse(expire_date_, parser);
}

template <class StorerT>
void StoryManager::PendingStory::store(StorerT &storer) const {
  using td::store;
  bool is_edit = story_id_.is_server();
  bool has_forward_from_story_full_id = forward_from_story_full_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_edit);
  STORE_FLAG(has_forward_from_story_full_id);
  END_STORE_FLAGS();
  store(dialog_id_, storer);
  if (is_edit) {
    store(story_id_, storer);
  } else {
    store(random_id_, storer);
  }
  store(story_, storer);
  if (has_forward_from_story_full_id) {
    store(forward_from_story_full_id_, storer);
  }
}

template <class ParserT>
void StoryManager::PendingStory::parse(ParserT &parser) {
  using td::parse;
  bool is_edit;
  bool has_forward_from_story_full_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_edit);
  PARSE_FLAG(has_forward_from_story_full_id);
  END_PARSE_FLAGS();
  parse(dialog_id_, parser);
  if (is_edit) {
    parse(story_id_, parser);
  } else {
    parse(random_id_, parser);
  }
  parse(story_, parser);
  if (has_forward_from_story_full_id) {
    parse(forward_from_story_full_id_, parser);
  }
  if (story_ != nullptr && story_->content_ != nullptr) {
    file_upload_id_ = {get_story_content_any_file_id(story_->content_.get()), FileManager::get_internal_upload_id()};
  }
}

template <class StorerT>
void StoryManager::SavedActiveStories::store(StorerT &storer) const {
  using td::store;
  CHECK(!story_infos_.empty());
  bool has_max_read_story_id = max_read_story_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_max_read_story_id);
  END_STORE_FLAGS();
  store(story_infos_, storer);
  if (has_max_read_story_id) {
    store(max_read_story_id_, storer);
  }
}

template <class ParserT>
void StoryManager::SavedActiveStories::parse(ParserT &parser) {
  using td::parse;
  bool has_max_read_story_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_max_read_story_id);
  END_PARSE_FLAGS();
  parse(story_infos_, parser);
  if (has_max_read_story_id) {
    parse(max_read_story_id_, parser);
  }
}

template <class StorerT>
void StoryManager::SavedStoryList::store(StorerT &storer) const {
  using td::store;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_more_);
  END_STORE_FLAGS();
  store(state_, storer);
  store(total_count_, storer);
}

template <class ParserT>
void StoryManager::SavedStoryList::parse(ParserT &parser) {
  using td::parse;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_more_);
  END_PARSE_FLAGS();
  parse(state_, parser);
  parse(total_count_, parser);
}

StoryManager::StoryManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_media_callback_ = std::make_shared<UploadMediaCallback>();

  story_reload_timeout_.set_callback(on_story_reload_timeout_callback);
  story_reload_timeout_.set_callback_data(static_cast<void *>(this));

  story_expire_timeout_.set_callback(on_story_expire_timeout_callback);
  story_expire_timeout_.set_callback_data(static_cast<void *>(this));

  story_can_get_viewers_timeout_.set_callback(on_story_can_get_viewers_timeout_callback);
  story_can_get_viewers_timeout_.set_callback_data(static_cast<void *>(this));

  if (G()->use_message_database() && td_->auth_manager_->is_authorized() && !td_->auth_manager_->is_bot()) {
    for (auto story_list_id : {StoryListId::main(), StoryListId::archive()}) {
      auto r_value = G()->td_db()->get_story_db_sync()->get_active_story_list_state(story_list_id);
      if (r_value.is_ok() && !r_value.ok().empty()) {
        SavedStoryList saved_story_list;
        auto status = log_event_parse(saved_story_list, r_value.ok().as_slice());
        if (status.is_error()) {
          LOG(ERROR) << "Load invalid state for " << story_list_id << " from database";
        } else {
          LOG(INFO) << "Load state for " << story_list_id << " from database: " << saved_story_list.state_;
          auto &story_list = get_story_list(story_list_id);
          story_list.state_ = std::move(saved_story_list.state_);
          story_list.server_total_count_ = td::max(saved_story_list.total_count_, 0);
          story_list.server_has_more_ = saved_story_list.has_more_;
          story_list.database_has_more_ = true;
        }
      }
    }
  }
}

StoryManager::~StoryManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), story_full_id_to_file_source_id_, stories_,
                                              stories_by_global_id_, inaccessible_story_full_ids_,
                                              deleted_story_full_ids_, failed_to_load_story_full_ids_, story_messages_,
                                              story_quick_reply_messages_, active_stories_, updated_active_stories_,
                                              max_read_story_ids_, failed_to_load_active_stories_);
}

void StoryManager::start_up() {
  if (!td_->auth_manager_->is_authorized()) {
    return;
  }

  auto stealth_mode_str = G()->td_db()->get_binlog_pmc()->get(get_story_stealth_mode_key());
  if (!stealth_mode_str.empty()) {
    log_event_parse(stealth_mode_, stealth_mode_str).ensure();
    stealth_mode_.update();
    LOG(INFO) << stealth_mode_;
    if (stealth_mode_.is_empty()) {
      G()->td_db()->get_binlog_pmc()->erase(get_story_stealth_mode_key());
    } else {
      schedule_stealth_mode_update();
    }
  }
  send_update_story_stealth_mode();

  try_synchronize_archive_all_stories();
  load_expired_database_stories();

  for (auto story_list_id : {StoryListId::main(), StoryListId::archive()}) {
    update_story_list_sent_total_count(story_list_id, "start_up");
  }
}

void StoryManager::timeout_expired() {
  load_expired_database_stories();

  if (channels_to_send_stories_inited_ && get_dialogs_to_send_stories_queries_.empty() &&
      Time::now() > next_reload_channels_to_send_stories_time_ && !td_->auth_manager_->is_bot()) {
    reload_dialogs_to_send_stories(Auto());
  }
}

void StoryManager::hangup() {
  fail_promise_map(reload_story_queries_, Global::request_aborted_error());
  fail_promise_map(delete_yet_unsent_story_queries_, Global::request_aborted_error());

  stop();
}

void StoryManager::tear_down() {
  parent_.reset();
}

void StoryManager::on_story_reload_timeout_callback(void *story_manager_ptr, int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_manager = static_cast<StoryManager *>(story_manager_ptr);
  send_closure_later(story_manager->actor_id(story_manager), &StoryManager::on_story_reload_timeout, story_global_id);
}

void StoryManager::on_story_reload_timeout(int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_full_id = stories_by_global_id_.get(story_global_id);
  auto story = get_story(story_full_id);
  if (story == nullptr || opened_stories_.count(story_full_id) == 0) {
    LOG(INFO) << "There is no need to reload " << story_full_id;
    return;
  }

  reload_story(story_full_id, Promise<Unit>(), "on_story_reload_timeout");
  story_reload_timeout_.set_timeout_in(story_global_id, OPENED_STORY_POLL_PERIOD);
}

void StoryManager::on_story_expire_timeout_callback(void *story_manager_ptr, int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_manager = static_cast<StoryManager *>(story_manager_ptr);
  send_closure_later(story_manager->actor_id(story_manager), &StoryManager::on_story_expire_timeout, story_global_id);
}

void StoryManager::on_story_expire_timeout(int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_full_id = stories_by_global_id_.get(story_global_id);
  auto story = get_story(story_full_id);
  if (story == nullptr) {
    return;
  }
  if (is_active_story(story)) {
    // timeout used monotonic time instead of wall clock time
    LOG(INFO) << "Receive timeout for non-expired " << story_full_id << ": expire_date = " << story->expire_date_
              << ", current time = " << G()->unix_time();
    return set_story_expire_timeout(story);
  }

  LOG(INFO) << "Have expired " << story_full_id;
  auto owner_dialog_id = story_full_id.get_dialog_id();
  CHECK(owner_dialog_id.is_valid());
  if (story->content_ != nullptr && !can_access_expired_story(owner_dialog_id, story)) {
    on_delete_story(story_full_id);  // also updates active stories
  } else {
    auto active_stories = get_active_stories(owner_dialog_id);
    if (active_stories != nullptr && contains(active_stories->story_ids_, story_full_id.get_story_id())) {
      auto story_ids = active_stories->story_ids_;
      on_update_active_stories(owner_dialog_id, active_stories->max_read_story_id_, std::move(story_ids),
                               Promise<Unit>(), "on_story_expire_timeout");
    }
  }
}

void StoryManager::on_story_can_get_viewers_timeout_callback(void *story_manager_ptr, int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_manager = static_cast<StoryManager *>(story_manager_ptr);
  send_closure_later(story_manager->actor_id(story_manager), &StoryManager::on_story_can_get_viewers_timeout,
                     story_global_id);
}

void StoryManager::on_story_can_get_viewers_timeout(int64 story_global_id) {
  if (G()->close_flag()) {
    return;
  }

  auto story_full_id = stories_by_global_id_.get(story_global_id);
  auto story = get_story(story_full_id);
  if (story == nullptr) {
    return;
  }

  LOG(INFO) << "Have expired viewers in " << story_full_id;
  if (has_unexpired_viewers(story_full_id, story)) {
    // timeout used monotonic time instead of wall clock time
    // also a reaction could have been added on the story
    LOG(INFO) << "Receive timeout for " << story_full_id
              << " with available viewers: expire_date = " << story->expire_date_
              << ", current time = " << G()->unix_time();
    return set_story_can_get_viewers_timeout(story);
  }

  // can_get_viewers flag could have been changed; reload the story to repair it
  reload_story(story_full_id, Promise<Unit>(), "on_story_can_get_viewers_timeout");
}

void StoryManager::load_expired_database_stories() {
  if (!G()->use_message_database()) {
    if (!td_->auth_manager_->is_bot()) {
      set_timeout_in(Random::fast(300, 420));
    }
    return;
  }

  LOG(INFO) << "Load " << load_expired_database_stories_next_limit_ << " expired stories";
  G()->td_db()->get_story_db_async()->get_expiring_stories(
      G()->unix_time() - 1, load_expired_database_stories_next_limit_,
      PromiseCreator::lambda([actor_id = actor_id(this)](Result<vector<StoryDbStory>> r_stories) {
        if (G()->close_flag()) {
          return;
        }
        CHECK(r_stories.is_ok());
        send_closure(actor_id, &StoryManager::on_load_expired_database_stories, r_stories.move_as_ok());
      }));
}

void StoryManager::on_load_expired_database_stories(vector<StoryDbStory> stories) {
  if (G()->close_flag()) {
    return;
  }

  int32 next_request_delay;
  if (stories.size() == static_cast<size_t>(load_expired_database_stories_next_limit_)) {
    CHECK(load_expired_database_stories_next_limit_ < (1 << 30));
    load_expired_database_stories_next_limit_ *= 2;
    next_request_delay = 1;
  } else {
    load_expired_database_stories_next_limit_ = DEFAULT_LOADED_EXPIRED_STORIES;
    next_request_delay = Random::fast(300, 420);
  }
  set_timeout_in(next_request_delay);

  LOG(INFO) << "Receive " << stories.size() << " expired stories with next request in " << next_request_delay
            << " seconds";
  for (auto &database_story : stories) {
    auto story = parse_story(database_story.story_full_id_, std::move(database_story.data_));
    if (story != nullptr) {
      LOG(ERROR) << "Receive non-expired " << database_story.story_full_id_;
    }
  }
}

bool StoryManager::is_my_story(DialogId owner_dialog_id) const {
  return owner_dialog_id == td_->dialog_manager_->get_my_dialog_id();
}

bool StoryManager::can_access_expired_story(DialogId owner_dialog_id, const Story *story) const {
  CHECK(story != nullptr);
  CHECK(story->content_ != nullptr);
  // non-pinned non-editable stories can't be accessed after they expire
  return story->is_pinned_ || can_edit_stories(owner_dialog_id);
}

bool StoryManager::can_get_story_view_count(DialogId owner_dialog_id) {
  // result must be stable over time
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      return is_my_story(owner_dialog_id);
    case DialogType::Chat:
    case DialogType::Channel:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return true;
  }
}

bool StoryManager::can_post_stories(DialogId owner_dialog_id) const {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      return is_my_story(owner_dialog_id);
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_status(owner_dialog_id.get_channel_id()).can_post_stories();
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return false;
  }
}

bool StoryManager::can_edit_stories(DialogId owner_dialog_id) const {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      return is_my_story(owner_dialog_id);
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_status(owner_dialog_id.get_channel_id()).can_edit_stories();
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return false;
  }
}

bool StoryManager::can_delete_stories(DialogId owner_dialog_id) const {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      return is_my_story(owner_dialog_id);
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_status(owner_dialog_id.get_channel_id()).can_delete_stories();
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return false;
  }
}

bool StoryManager::can_edit_story(StoryFullId story_full_id, const Story *story) const {
  if (!story_full_id.get_story_id().is_server()) {
    return false;
  }
  auto owner_dialog_id = story_full_id.get_dialog_id();
  return can_edit_stories(owner_dialog_id) || (story->is_outgoing_ && can_post_stories(owner_dialog_id));
}

bool StoryManager::can_toggle_story_is_pinned(StoryFullId story_full_id, const Story *story) const {
  if (!story_full_id.get_story_id().is_server()) {
    return false;
  }
  return can_edit_stories(story_full_id.get_dialog_id());
}

bool StoryManager::can_delete_story(StoryFullId story_full_id, const Story *story) const {
  if (!story_full_id.get_story_id().is_server()) {
    return true;
  }
  auto owner_dialog_id = story_full_id.get_dialog_id();
  return can_delete_stories(owner_dialog_id) || (story->is_outgoing_ && can_post_stories(owner_dialog_id));
}

bool StoryManager::is_active_story(const Story *story) {
  return story != nullptr && G()->unix_time() < story->expire_date_;
}

int32 StoryManager::get_story_viewers_expire_date(const Story *story) const {
  return story->expire_date_ +
         narrow_cast<int32>(td_->option_manager_->get_option_integer("story_viewers_expiration_delay", 86400));
}

const StoryManager::Story *StoryManager::get_story(StoryFullId story_full_id) const {
  return stories_.get_pointer(story_full_id);
}

StoryManager::Story *StoryManager::get_story_editable(StoryFullId story_full_id) {
  return stories_.get_pointer(story_full_id);
}

StoryManager::Story *StoryManager::get_story_force(StoryFullId story_full_id, const char *source) {
  if (!story_full_id.is_valid()) {
    return nullptr;
  }

  auto story = get_story_editable(story_full_id);
  if (story != nullptr && story->content_ != nullptr) {
    return story;
  }

  if (!G()->use_message_database() || failed_to_load_story_full_ids_.count(story_full_id) > 0 ||
      is_inaccessible_story(story_full_id) || deleted_story_full_ids_.count(story_full_id) > 0 ||
      !story_full_id.get_story_id().is_server()) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << story_full_id << " from database from " << source;

  auto r_value = G()->td_db()->get_story_db_sync()->get_story(story_full_id);
  if (r_value.is_error()) {
    failed_to_load_story_full_ids_.insert(story_full_id);
    return nullptr;
  }
  return on_get_story_from_database(story_full_id, r_value.ok(), source);
}

unique_ptr<StoryManager::Story> StoryManager::parse_story(StoryFullId story_full_id, const BufferSlice &value) {
  auto story = make_unique<Story>();
  auto status = log_event_parse(*story, value.as_slice());
  if (status.is_error()) {
    LOG(ERROR) << "Receive invalid " << story_full_id << " from database: " << status << ' '
               << format::as_hex_dump<4>(value.as_slice());
    delete_story_from_database(story_full_id);
    reload_story(story_full_id, Auto(), "parse_story");
    return nullptr;
  }
  if (story->content_ == nullptr) {
    LOG(ERROR) << "Receive " << story_full_id << " without content from database";
    delete_story_from_database(story_full_id);
    return nullptr;
  }
  if (!story_full_id.get_story_id().is_server()) {
    LOG(ERROR) << "Receive " << story_full_id << " from database";
    delete_story_from_database(story_full_id);
    return nullptr;
  }

  auto owner_dialog_id = story_full_id.get_dialog_id();
  if (is_active_story(story.get())) {
    auto active_stories = get_active_stories(owner_dialog_id);
    if (active_stories != nullptr && !contains(active_stories->story_ids_, story_full_id.get_story_id())) {
      LOG(INFO) << "Ignore unavailable active " << story_full_id << " from database";
      delete_story_files(story.get());
      delete_story_from_database(story_full_id);
      return nullptr;
    }
  } else {
    if (!can_access_expired_story(owner_dialog_id, story.get())) {
      LOG(INFO) << "Delete expired " << story_full_id;
      delete_story_files(story.get());
      delete_story_from_database(story_full_id);
      return nullptr;
    }
  }
  if (is_my_story(owner_dialog_id)) {
    story->is_outgoing_ = true;
  }

  return story;
}

StoryManager::Story *StoryManager::on_get_story_from_database(StoryFullId story_full_id, const BufferSlice &value,
                                                              const char *source) {
  auto old_story = get_story_editable(story_full_id);
  if (old_story != nullptr && old_story->content_ != nullptr) {
    return old_story;
  }

  if (value.empty()) {
    failed_to_load_story_full_ids_.insert(story_full_id);
    return nullptr;
  }

  auto story = parse_story(story_full_id, value);
  if (story == nullptr) {
    failed_to_load_story_full_ids_.insert(story_full_id);
    return nullptr;
  }

  Dependencies dependencies;
  add_story_dependencies(dependencies, story.get());
  if (!dependencies.resolve_force(td_, "on_get_story_from_database")) {
    reload_story(story_full_id, Auto(), "on_get_story_from_database");
    failed_to_load_story_full_ids_.insert(story_full_id);
    return nullptr;
  }

  LOG(INFO) << "Load new " << story_full_id << " from " << source;

  auto result = story.get();
  stories_.set(story_full_id, std::move(story));
  register_story_global_id(story_full_id, result);

  CHECK(!is_inaccessible_story(story_full_id));
  CHECK(being_edited_stories_.count(story_full_id) == 0);

  on_story_changed(story_full_id, result, true, false, true);

  return result;
}

bool StoryManager::can_get_story_statistics(StoryFullId story_full_id) {
  return can_get_story_statistics(story_full_id, get_story_force(story_full_id, "can_get_story_statistics"));
}

bool StoryManager::can_get_story_statistics(StoryFullId story_full_id, const Story *story) const {
  if (td_->auth_manager_->is_bot()) {
    return false;
  }
  if (story == nullptr || !story_full_id.get_story_id().is_server()) {
    return false;
  }
  auto dialog_id = story_full_id.get_dialog_id();
  return dialog_id.get_type() == DialogType::Channel &&
         td_->chat_manager_->can_get_channel_story_statistics(dialog_id.get_channel_id());
}

const StoryManager::ActiveStories *StoryManager::get_active_stories(DialogId owner_dialog_id) const {
  return active_stories_.get_pointer(owner_dialog_id);
}

StoryManager::ActiveStories *StoryManager::get_active_stories_editable(DialogId owner_dialog_id) {
  return active_stories_.get_pointer(owner_dialog_id);
}

StoryManager::ActiveStories *StoryManager::get_active_stories_force(DialogId owner_dialog_id, const char *source) {
  auto active_stories = get_active_stories_editable(owner_dialog_id);
  if (active_stories != nullptr) {
    return active_stories;
  }

  if (!G()->use_message_database() || failed_to_load_active_stories_.count(owner_dialog_id) > 0 ||
      !owner_dialog_id.is_valid()) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load active stories of " << owner_dialog_id << " from database from " << source;
  auto r_value = G()->td_db()->get_story_db_sync()->get_active_stories(owner_dialog_id);
  if (r_value.is_error()) {
    failed_to_load_active_stories_.insert(owner_dialog_id);
    return nullptr;
  }
  return on_get_active_stories_from_database(StoryListId(), owner_dialog_id, r_value.ok(), source);
}

StoryManager::ActiveStories *StoryManager::on_get_active_stories_from_database(StoryListId story_list_id,
                                                                               DialogId owner_dialog_id,
                                                                               const BufferSlice &value,
                                                                               const char *source) {
  auto active_stories = get_active_stories_editable(owner_dialog_id);
  if (active_stories != nullptr) {
    return active_stories;
  }

  if (value.empty()) {
    failed_to_load_active_stories_.insert(owner_dialog_id);
    return nullptr;
  }

  SavedActiveStories saved_active_stories;
  auto status = log_event_parse(saved_active_stories, value.as_slice());
  if (status.is_error()) {
    LOG(ERROR) << "Receive invalid active stories in " << owner_dialog_id << " from database: " << status << ' '
               << format::as_hex_dump<4>(value.as_slice());
    save_active_stories(owner_dialog_id, nullptr, Promise<Unit>(), "on_get_active_stories_from_database");
    failed_to_load_active_stories_.insert(owner_dialog_id);
    return nullptr;
  }

  vector<StoryId> story_ids;
  for (auto &story_info : saved_active_stories.story_infos_) {
    story_ids.push_back(on_get_story_info(owner_dialog_id, std::move(story_info)));
  }

  on_update_active_stories(owner_dialog_id, saved_active_stories.max_read_story_id_, std::move(story_ids),
                           Promise<Unit>(), "on_get_active_stories_from_database", true);

  active_stories = get_active_stories_editable(owner_dialog_id);
  if (active_stories == nullptr) {
    if (!story_list_id.is_valid()) {
      story_list_id = get_dialog_story_list_id(owner_dialog_id);
    }
    if (story_list_id.is_valid()) {
      auto &story_list = get_story_list(story_list_id);
      if (!story_list.is_reloaded_server_total_count_ &&
          story_list.server_total_count_ > static_cast<int32>(story_list.ordered_stories_.size())) {
        story_list.server_total_count_--;
        update_story_list_sent_total_count(story_list_id, story_list, "on_get_active_stories_from_database");
        save_story_list(story_list_id, story_list.state_, story_list.server_total_count_, story_list.server_has_more_);
      }
    }
  }
  return active_stories;
}

void StoryManager::add_story_dependencies(Dependencies &dependencies, const Story *story) {
  if (story->forward_info_ != nullptr) {
    story->forward_info_->add_dependencies(dependencies);
  }
  story->interaction_info_.add_dependencies(dependencies);
  dependencies.add_message_sender_dependencies(story->sender_dialog_id_);
  story->privacy_rules_.add_dependencies(dependencies);
  if (story->content_ != nullptr) {
    add_story_content_dependencies(dependencies, story->content_.get());
  }
  add_formatted_text_dependencies(dependencies, &story->caption_);
  for (const auto &media_area : story->areas_) {
    media_area.add_dependencies(dependencies);
  }
}

void StoryManager::add_pending_story_dependencies(Dependencies &dependencies, const PendingStory *pending_story) {
  dependencies.add_dialog_and_dependencies(pending_story->dialog_id_);
  add_story_dependencies(dependencies, pending_story->story_.get());
}

void StoryManager::load_active_stories(StoryListId story_list_id, Promise<Unit> &&promise) {
  if (!story_list_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Story list must be non-empty"));
  }
  auto &story_list = get_story_list(story_list_id);
  if (story_list.list_last_story_date_ == MAX_DIALOG_DATE) {
    return promise.set_error(Status::Error(404, "Not found"));
  }

  if (story_list.database_has_more_) {
    CHECK(G()->use_message_database());
    story_list.load_list_from_database_queries_.push_back(std::move(promise));
    if (story_list.load_list_from_database_queries_.size() == 1u) {
      G()->td_db()->get_story_db_async()->get_active_story_list(
          story_list_id, story_list.last_loaded_database_dialog_date_.get_order(),
          story_list.last_loaded_database_dialog_date_.get_dialog_id(), 10,
          PromiseCreator::lambda(
              [actor_id = actor_id(this), story_list_id](Result<StoryDbGetActiveStoryListResult> &&result) {
                send_closure(actor_id, &StoryManager::on_load_active_stories_from_database, story_list_id,
                             std::move(result));
              }));
    }
    return;
  }

  if (!story_list.server_has_more_) {
    if (story_list.list_last_story_date_ != MAX_DIALOG_DATE) {
      auto min_story_date = story_list.list_last_story_date_;
      story_list.list_last_story_date_ = MAX_DIALOG_DATE;
      for (auto it = story_list.ordered_stories_.upper_bound(min_story_date); it != story_list.ordered_stories_.end();
           ++it) {
        on_dialog_active_stories_order_updated(it->get_dialog_id(), "load_active_stories");
      }
      update_story_list_sent_total_count(story_list_id, story_list, "load_active_stories");
    }
    return promise.set_error(Status::Error(404, "Not found"));
  }

  load_active_stories_from_server(story_list_id, story_list, !story_list.state_.empty(), std::move(promise));
}

void StoryManager::on_load_active_stories_from_database(StoryListId story_list_id,
                                                        Result<StoryDbGetActiveStoryListResult> result) {
  G()->ignore_result_if_closing(result);
  auto &story_list = get_story_list(story_list_id);
  auto promises = std::move(story_list.load_list_from_database_queries_);
  CHECK(!promises.empty());
  if (result.is_error()) {
    return fail_promises(promises, result.move_as_error());
  }

  auto active_story_list = result.move_as_ok();

  LOG(INFO) << "Load " << active_story_list.active_stories_.size() << " chats with active stories in " << story_list_id
            << " from database";

  bool is_bad = false;
  FlatHashSet<DialogId, DialogIdHash> owner_dialog_ids;
  Dependencies dependencies;
  for (auto &active_stories_it : active_story_list.active_stories_) {
    auto owner_dialog_id = active_stories_it.first;
    if (owner_dialog_id.is_valid()) {
      dependencies.add_dialog_and_dependencies(owner_dialog_id);
      owner_dialog_ids.insert(owner_dialog_id);
    } else {
      is_bad = true;
    }
  }
  if (is_bad || !dependencies.resolve_force(td_, "on_load_active_stories_from_database")) {
    active_story_list.active_stories_.clear();
    story_list.state_.clear();
    story_list.server_has_more_ = true;
  }

  if (active_story_list.active_stories_.empty()) {
    story_list.last_loaded_database_dialog_date_ = MAX_DIALOG_DATE;
    story_list.database_has_more_ = false;
  } else {
    for (auto &active_stories_it : active_story_list.active_stories_) {
      on_get_active_stories_from_database(story_list_id, active_stories_it.first, active_stories_it.second,
                                          "on_load_active_stories_from_database");
    }
    DialogDate max_story_date(active_story_list.next_order_, active_story_list.next_dialog_id_);
    if (story_list.last_loaded_database_dialog_date_ < max_story_date) {
      story_list.last_loaded_database_dialog_date_ = max_story_date;

      if (story_list.list_last_story_date_ < max_story_date) {
        auto min_story_date = story_list.list_last_story_date_;
        story_list.list_last_story_date_ = max_story_date;
        for (auto it = story_list.ordered_stories_.upper_bound(min_story_date);
             it != story_list.ordered_stories_.end() && *it <= max_story_date; ++it) {
          auto dialog_id = it->get_dialog_id();
          owner_dialog_ids.erase(dialog_id);
          on_dialog_active_stories_order_updated(dialog_id, "on_load_active_stories_from_database 1");
        }
        for (auto owner_dialog_id : owner_dialog_ids) {
          on_dialog_active_stories_order_updated(owner_dialog_id, "on_load_active_stories_from_database 2");
        }
      }
    } else {
      LOG(ERROR) << "Last database story date didn't increase";
    }
    update_story_list_sent_total_count(story_list_id, story_list, "on_load_active_stories_from_database");
  }

  set_promises(promises);
}

void StoryManager::load_active_stories_from_server(StoryListId story_list_id, StoryList &story_list, bool is_next,
                                                   Promise<Unit> &&promise) {
  story_list.load_list_from_server_queries_.push_back(std::move(promise));
  if (story_list.load_list_from_server_queries_.size() == 1u) {
    auto query_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), story_list_id, is_next, state = story_list.state_](
                                   Result<telegram_api::object_ptr<telegram_api::stories_AllStories>> r_all_stories) {
          send_closure(actor_id, &StoryManager::on_load_active_stories_from_server, story_list_id, is_next, state,
                       std::move(r_all_stories));
        });
    td_->create_handler<GetAllStoriesQuery>(std::move(query_promise))->send(story_list_id, is_next, story_list.state_);
  }
}

void StoryManager::reload_active_stories() {
  for (auto story_list_id : {StoryListId::main(), StoryListId::archive()}) {
    load_active_stories_from_server(story_list_id, get_story_list(story_list_id), false, Promise<Unit>());
  }
}

void StoryManager::on_load_active_stories_from_server(
    StoryListId story_list_id, bool is_next, string old_state,
    Result<telegram_api::object_ptr<telegram_api::stories_AllStories>> r_all_stories) {
  G()->ignore_result_if_closing(r_all_stories);
  auto &story_list = get_story_list(story_list_id);
  auto promises = std::move(story_list.load_list_from_server_queries_);
  CHECK(!promises.empty());
  if (r_all_stories.is_error()) {
    return fail_promises(promises, r_all_stories.move_as_error());
  }
  auto all_stories = r_all_stories.move_as_ok();
  switch (all_stories->get_id()) {
    case telegram_api::stories_allStoriesNotModified::ID: {
      auto stories = telegram_api::move_object_as<telegram_api::stories_allStoriesNotModified>(all_stories);
      if (stories->state_.empty()) {
        LOG(ERROR) << "Receive empty state in " << to_string(stories);
      } else {
        story_list.state_ = std::move(stories->state_);
        save_story_list(story_list_id, story_list.state_, story_list.server_total_count_, story_list.server_has_more_);
      }
      on_update_story_stealth_mode(std::move(stories->stealth_mode_));
      break;
    }
    case telegram_api::stories_allStories::ID: {
      auto stories = telegram_api::move_object_as<telegram_api::stories_allStories>(all_stories);
      td_->user_manager_->on_get_users(std::move(stories->users_), "on_load_active_stories_from_server");
      td_->chat_manager_->on_get_chats(std::move(stories->chats_), "on_load_active_stories_from_server");
      if (stories->state_.empty()) {
        LOG(ERROR) << "Receive empty state in " << to_string(stories);
      } else {
        story_list.state_ = std::move(stories->state_);
      }
      story_list.server_total_count_ = max(stories->count_, 0);
      story_list.is_reloaded_server_total_count_ = true;
      if (!stories->has_more_ || stories->peer_stories_.empty()) {
        story_list.server_has_more_ = false;
      }

      MultiPromiseActorSafe mpas{"SaveActiveStoryMultiPromiseActor"};
      mpas.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), story_list_id, state = story_list.state_,
                                               server_total_count = story_list.server_total_count_,
                                               has_more = story_list.server_has_more_](Result<Unit> &&result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &StoryManager::save_story_list, story_list_id, std::move(state), server_total_count,
                       has_more);
        }
      }));
      auto lock = mpas.get_promise();

      if (stories->peer_stories_.empty() && stories->has_more_) {
        LOG(ERROR) << "Receive no stories, but expected more";
        stories->has_more_ = false;
      }

      auto max_story_date = MIN_DIALOG_DATE;
      vector<DialogId> owner_dialog_ids;
      for (auto &peer_stories : stories->peer_stories_) {
        auto owner_dialog_id = on_get_dialog_stories(DialogId(), std::move(peer_stories), mpas.get_promise());
        auto active_stories = get_active_stories(owner_dialog_id);
        if (active_stories == nullptr) {
          LOG(ERROR) << "Receive invalid stories";
        } else {
          DialogDate story_date(active_stories->private_order_, owner_dialog_id);
          if (max_story_date < story_date) {
            max_story_date = story_date;
          } else {
            LOG(ERROR) << "Receive " << story_date << " after " << max_story_date << " for "
                       << (is_next ? "next" : "first") << " request with state \"" << old_state << "\" in "
                       << story_list_id << " of " << td_->user_manager_->get_my_id();
          }
          owner_dialog_ids.push_back(owner_dialog_id);
        }
      }
      if (!stories->has_more_) {
        max_story_date = MAX_DIALOG_DATE;
      }

      vector<DialogId> delete_dialog_ids;
      auto min_story_date = is_next ? story_list.list_last_story_date_ : MIN_DIALOG_DATE;
      for (auto it = story_list.ordered_stories_.upper_bound(min_story_date);
           it != story_list.ordered_stories_.end() && *it <= max_story_date; ++it) {
        auto dialog_id = it->get_dialog_id();
        if (!td::contains(owner_dialog_ids, dialog_id)) {
          delete_dialog_ids.push_back(dialog_id);
        }
      }
      if (story_list.list_last_story_date_ < max_story_date) {
        story_list.list_last_story_date_ = max_story_date;
        for (auto owner_dialog_id : owner_dialog_ids) {
          on_dialog_active_stories_order_updated(owner_dialog_id, "on_load_active_stories_from_server");
        }
      } else if (is_next) {
        LOG(ERROR) << "Last story date didn't increase";
      }
      if (!delete_dialog_ids.empty()) {
        LOG(INFO) << "Delete active stories in " << delete_dialog_ids;
      }
      for (auto dialog_id : delete_dialog_ids) {
        on_update_active_stories(dialog_id, StoryId(), vector<StoryId>(), mpas.get_promise(),
                                 "on_load_active_stories_from_server");
        load_dialog_expiring_stories(dialog_id, 0, "on_load_active_stories_from_server 1");
      }
      update_story_list_sent_total_count(story_list_id, story_list, "on_load_active_stories_from_server");

      lock.set_value(Unit());

      on_update_story_stealth_mode(std::move(stories->stealth_mode_));
      break;
    }
    default:
      UNREACHABLE();
  }

  set_promises(promises);
}

void StoryManager::save_story_list(StoryListId story_list_id, string state, int32 total_count, bool has_more) {
  if (G()->close_flag() || !G()->use_message_database()) {
    return;
  }

  SavedStoryList saved_story_list;
  saved_story_list.state_ = std::move(state);
  saved_story_list.total_count_ = total_count;
  saved_story_list.has_more_ = has_more;
  G()->td_db()->get_story_db_async()->add_active_story_list_state(story_list_id, log_event_store(saved_story_list),
                                                                  Promise<Unit>());
}

StoryManager::StoryList &StoryManager::get_story_list(StoryListId story_list_id) {
  CHECK(!td_->auth_manager_->is_bot());
  CHECK(story_list_id.is_valid());
  return story_lists_[story_list_id == StoryListId::archive()];
}

const StoryManager::StoryList &StoryManager::get_story_list(StoryListId story_list_id) const {
  CHECK(!td_->auth_manager_->is_bot());
  CHECK(story_list_id.is_valid());
  return story_lists_[story_list_id == StoryListId::archive()];
}

td_api::object_ptr<td_api::updateStoryListChatCount> StoryManager::get_update_story_list_chat_count_object(
    StoryListId story_list_id, const StoryList &story_list) const {
  CHECK(story_list_id.is_valid());
  return td_api::make_object<td_api::updateStoryListChatCount>(story_list_id.get_story_list_object(),
                                                               story_list.sent_total_count_);
}

void StoryManager::update_story_list_sent_total_count(StoryListId story_list_id, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  update_story_list_sent_total_count(story_list_id, get_story_list(story_list_id), source);
}

void StoryManager::update_story_list_sent_total_count(StoryListId story_list_id, StoryList &story_list,
                                                      const char *source) {
  if (story_list.server_total_count_ == -1 || td_->auth_manager_->is_bot()) {
    return;
  }
  LOG(INFO) << "Update story list sent total chat count in " << story_list_id << " from " << source;
  auto new_total_count = static_cast<int32>(story_list.ordered_stories_.size());
  auto yet_unsent_total_count = 0;
  for (const auto &it : yet_unsent_story_ids_) {
    if (active_stories_.count(it.first) == 0) {
      yet_unsent_total_count++;
    }
  }
  new_total_count += yet_unsent_total_count;
  if (story_list.list_last_story_date_ != MAX_DIALOG_DATE) {
    new_total_count = max(new_total_count, story_list.server_total_count_ + yet_unsent_total_count);
  } else if (story_list.server_total_count_ != new_total_count) {
    story_list.server_total_count_ = new_total_count;
    save_story_list(story_list_id, story_list.state_, story_list.server_total_count_, story_list.server_has_more_);
  }
  if (story_list.sent_total_count_ != new_total_count) {
    story_list.sent_total_count_ = new_total_count;
    send_closure(G()->td(), &Td::send_update, get_update_story_list_chat_count_object(story_list_id, story_list));
  }
}

void StoryManager::reload_all_read_stories() {
  td_->create_handler<GetAllReadPeerStoriesQuery>()->send();
}

void StoryManager::try_synchronize_archive_all_stories() {
  if (G()->close_flag()) {
    return;
  }
  if (has_active_synchronize_archive_all_stories_query_) {
    return;
  }
  if (!td_->option_manager_->get_option_boolean("need_synchronize_archive_all_stories")) {
    return;
  }

  has_active_synchronize_archive_all_stories_query_ = true;
  auto archive_all_stories = td_->option_manager_->get_option_boolean("archive_all_stories");

  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), archive_all_stories](Result<Unit> result) {
    send_closure(actor_id, &StoryManager::on_synchronized_archive_all_stories, archive_all_stories, std::move(result));
  });
  td_->create_handler<ToggleAllStoriesHiddenQuery>(std::move(promise))->send(archive_all_stories);
}

void StoryManager::on_synchronized_archive_all_stories(bool set_archive_all_stories, Result<Unit> result) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(has_active_synchronize_archive_all_stories_query_);
  has_active_synchronize_archive_all_stories_query_ = false;

  auto archive_all_stories = td_->option_manager_->get_option_boolean("archive_all_stories");
  if (archive_all_stories != set_archive_all_stories) {
    return try_synchronize_archive_all_stories();
  }
  td_->option_manager_->set_option_empty("need_synchronize_archive_all_stories");

  if (result.is_error()) {
    send_closure(G()->config_manager(), &ConfigManager::reget_app_config, Promise<Unit>());
  }
}

void StoryManager::toggle_dialog_stories_hidden(DialogId dialog_id, StoryListId story_list_id,
                                                Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "toggle_dialog_stories_hidden"));
  if (story_list_id == get_dialog_story_list_id(dialog_id)) {
    return promise.set_value(Unit());
  }
  if (!story_list_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Story list must be non-empty"));
  }

  td_->create_handler<ToggleStoriesHiddenQuery>(std::move(promise))
      ->send(dialog_id, story_list_id == StoryListId::archive());
}

void StoryManager::get_dialog_pinned_stories(DialogId owner_dialog_id, StoryId from_story_id, int32 limit,
                                             Promise<td_api::object_ptr<td_api::stories>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read,
                                                                        "get_dialog_pinned_stories"));

  if (from_story_id != StoryId() && !from_story_id.is_server()) {
    return promise.set_error(Status::Error(400, "Invalid value of parameter from_story_id specified"));
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), owner_dialog_id, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::stories_stories>> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &StoryManager::on_get_dialog_pinned_stories, owner_dialog_id, result.move_as_ok(),
                     std::move(promise));
      });
  td_->create_handler<GetPinnedStoriesQuery>(std::move(query_promise))->send(owner_dialog_id, from_story_id, limit);
}

void StoryManager::on_get_dialog_pinned_stories(DialogId owner_dialog_id,
                                                telegram_api::object_ptr<telegram_api::stories_stories> &&stories,
                                                Promise<td_api::object_ptr<td_api::stories>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  auto pinned_story_ids = StoryId::get_story_ids(stories->pinned_to_top_);
  auto result = on_get_stories(owner_dialog_id, {}, std::move(stories));
  on_update_dialog_has_pinned_stories(owner_dialog_id, result.first > 0);
  promise.set_value(get_stories_object(
      result.first,
      transform(result.second, [owner_dialog_id](StoryId story_id) { return StoryFullId(owner_dialog_id, story_id); }),
      pinned_story_ids));
}

void StoryManager::get_story_archive(DialogId owner_dialog_id, StoryId from_story_id, int32 limit,
                                     Promise<td_api::object_ptr<td_api::stories>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (from_story_id != StoryId() && !from_story_id.is_server()) {
    return promise.set_error(Status::Error(400, "Invalid value of parameter from_story_id specified"));
  }
  if (!td_->dialog_manager_->have_dialog_force(owner_dialog_id, "get_story_archive")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!can_edit_stories(owner_dialog_id)) {
    return promise.set_error(Status::Error(400, "Can't get story archive in the chat"));
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), owner_dialog_id, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::stories_stories>> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &StoryManager::on_get_story_archive, owner_dialog_id, result.move_as_ok(),
                     std::move(promise));
      });
  td_->create_handler<GetStoriesArchiveQuery>(std::move(query_promise))->send(owner_dialog_id, from_story_id, limit);
}

void StoryManager::on_get_story_archive(DialogId owner_dialog_id,
                                        telegram_api::object_ptr<telegram_api::stories_stories> &&stories,
                                        Promise<td_api::object_ptr<td_api::stories>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  LOG_IF(ERROR, !stories->pinned_to_top_.empty()) << "Receive pinned stories in archive";
  auto result = on_get_stories(owner_dialog_id, {}, std::move(stories));
  promise.set_value(get_stories_object(
      result.first,
      transform(result.second, [owner_dialog_id](StoryId story_id) { return StoryFullId(owner_dialog_id, story_id); }),
      {}));
}

void StoryManager::get_dialog_expiring_stories(DialogId owner_dialog_id,
                                               Promise<td_api::object_ptr<td_api::chatActiveStories>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read,
                                                                        "get_dialog_expiring_stories"));

  LOG(INFO) << "Get active stories in " << owner_dialog_id;
  auto active_stories = get_active_stories_force(owner_dialog_id, "get_dialog_expiring_stories");
  if (active_stories != nullptr) {
    if (!promise) {
      return promise.set_value(nullptr);
    }
    if (updated_active_stories_.insert(owner_dialog_id)) {
      send_update_chat_active_stories(owner_dialog_id, active_stories, "get_dialog_expiring_stories 2");
    }
    promise.set_value(get_chat_active_stories_object(owner_dialog_id, active_stories));
    promise = {};
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), owner_dialog_id, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::stories_peerStories>> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &StoryManager::on_get_dialog_expiring_stories, owner_dialog_id, result.move_as_ok(),
                     std::move(promise));
      });
  td_->create_handler<GetPeerStoriesQuery>(std::move(query_promise))->send(owner_dialog_id);
}

void StoryManager::reload_dialog_expiring_stories(DialogId dialog_id) {
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
    return;
  }
  td_->dialog_manager_->force_create_dialog(dialog_id, "reload_dialog_expiring_stories");
  load_dialog_expiring_stories(dialog_id, 0, "reload_dialog_expiring_stories");
}

class StoryManager::LoadDialogExpiringStoriesLogEvent {
 public:
  DialogId dialog_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
  }
};

uint64 StoryManager::save_load_dialog_expiring_stories_log_event(DialogId owner_dialog_id) {
  LoadDialogExpiringStoriesLogEvent log_event{owner_dialog_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::LoadDialogExpiringStories,
                    get_log_event_storer(log_event));
}

void StoryManager::load_dialog_expiring_stories(DialogId owner_dialog_id, uint64 log_event_id, const char *source) {
  if (load_expiring_stories_log_event_ids_.count(owner_dialog_id) > 0) {
    if (log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), log_event_id);
    }
    return;
  }
  LOG(INFO) << "Load active stories in " << owner_dialog_id << " from " << source;
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_load_dialog_expiring_stories_log_event(owner_dialog_id);
  }
  load_expiring_stories_log_event_ids_[owner_dialog_id] = log_event_id;

  // send later to ensure that active stories are inited before sending the request
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), owner_dialog_id](Result<td_api::object_ptr<td_api::chatActiveStories>> &&) {
        if (!G()->close_flag()) {
          send_closure(actor_id, &StoryManager::on_load_dialog_expiring_stories, owner_dialog_id);
        }
      });
  send_closure_later(actor_id(this), &StoryManager::get_dialog_expiring_stories, owner_dialog_id, std::move(promise));
}

void StoryManager::on_load_dialog_expiring_stories(DialogId owner_dialog_id) {
  if (G()->close_flag()) {
    return;
  }
  auto it = load_expiring_stories_log_event_ids_.find(owner_dialog_id);
  if (it == load_expiring_stories_log_event_ids_.end()) {
    return;
  }
  auto log_event_id = it->second;
  load_expiring_stories_log_event_ids_.erase(it);
  if (log_event_id != 0) {
    binlog_erase(G()->td_db()->get_binlog(), log_event_id);
  }
  LOG(INFO) << "Finished loading of active stories in " << owner_dialog_id;
}

void StoryManager::on_get_dialog_expiring_stories(DialogId owner_dialog_id,
                                                  telegram_api::object_ptr<telegram_api::stories_peerStories> &&stories,
                                                  Promise<td_api::object_ptr<td_api::chatActiveStories>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  td_->user_manager_->on_get_users(std::move(stories->users_), "on_get_dialog_expiring_stories");
  td_->chat_manager_->on_get_chats(std::move(stories->chats_), "on_get_dialog_expiring_stories");
  owner_dialog_id = on_get_dialog_stories(owner_dialog_id, std::move(stories->stories_), Promise<Unit>());
  if (promise) {
    CHECK(owner_dialog_id.is_valid());
    auto active_stories = get_active_stories(owner_dialog_id);
    if (updated_active_stories_.insert(owner_dialog_id)) {
      send_update_chat_active_stories(owner_dialog_id, active_stories, "on_get_dialog_expiring_stories");
    }
    promise.set_value(get_chat_active_stories_object(owner_dialog_id, active_stories));
  } else {
    promise.set_value(nullptr);
  }
}

void StoryManager::search_hashtag_posts(DialogId dialog_id, string hashtag, string offset, int32 limit,
                                        Promise<td_api::object_ptr<td_api::foundStories>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_STORIES) {
    limit = MAX_SEARCH_STORIES;
  }
  if (dialog_id != DialogId()) {
    TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                          "search_hashtag_posts"));
  }

  bool is_cashtag = false;
  if (hashtag[0] == '#' || hashtag[0] == '$') {
    is_cashtag = (hashtag[0] == '$');
    hashtag = hashtag.substr(1);
  }
  if (hashtag.empty()) {
    return promise.set_value(td_api::make_object<td_api::foundStories>());
  }
  send_closure(is_cashtag ? td_->cashtag_search_hints_ : td_->hashtag_search_hints_, &HashtagHints::hashtag_used,
               hashtag);

  td_->create_handler<SearchStoriesQuery>(std::move(promise))
      ->send(dialog_id, PSTRING() << (is_cashtag ? '$' : '#') << hashtag, offset, limit);
}

void StoryManager::search_location_posts(td_api::object_ptr<td_api::locationAddress> &&address, string offset,
                                         int32 limit, Promise<td_api::object_ptr<td_api::foundStories>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_STORIES) {
    limit = MAX_SEARCH_STORIES;
  }

  td_->create_handler<SearchStoriesQuery>(std::move(promise))->send(std::move(address), offset, limit);
}

void StoryManager::search_venue_posts(string venue_provider, string venue_id, string offset, int32 limit,
                                      Promise<td_api::object_ptr<td_api::foundStories>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_STORIES) {
    limit = MAX_SEARCH_STORIES;
  }

  td_->create_handler<SearchStoriesQuery>(std::move(promise))->send(venue_provider, venue_id, offset, limit);
}

void StoryManager::set_pinned_stories(DialogId owner_dialog_id, vector<StoryId> story_ids, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Write,
                                                                        "set_pinned_stories"));
  if (!can_edit_stories(owner_dialog_id)) {
    return promise.set_error(Status::Error(400, "Can't change pinned stories in the chat"));
  }
  for (const auto &story_id : story_ids) {
    StoryFullId story_full_id{owner_dialog_id, story_id};
    const Story *story = get_story(story_full_id);
    if (story == nullptr) {
      return promise.set_error(Status::Error(400, "Story not found"));
    }
    if (!story->is_pinned_) {
      return promise.set_error(Status::Error(400, "The story must be posted to the chat page first"));
    }
    if (!story_id.is_server()) {
      return promise.set_error(Status::Error(400, "Story must be sent first"));
    }
  }
  td_->create_handler<TogglePinnedStoriesToTopQuery>(std::move(promise))->send(owner_dialog_id, std::move(story_ids));
}

void StoryManager::open_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read, "open_story"));
  if (!story_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid story identifier specified"));
  }

  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr) {
    return promise.set_value(Unit());
  }

  if (can_get_story_view_count(owner_dialog_id) && story_id.is_server()) {
    if (opened_stories_with_view_count_.empty()) {
      schedule_interaction_info_update();
    }
    auto &open_count = opened_stories_with_view_count_[story_full_id];
    if (++open_count == 1) {
      td_->create_handler<GetStoriesViewsQuery>()->send(owner_dialog_id, {story_id});
    }
  }

  if (story->content_ == nullptr) {
    return promise.set_value(Unit());
  }

  if (story_id.is_server()) {
    auto &open_count = opened_stories_[story_full_id];
    if (++open_count == 1) {
      CHECK(story->global_id_ > 0);
      story_reload_timeout_.set_timeout_in(story->global_id_,
                                           story->receive_date_ + OPENED_STORY_POLL_PERIOD - G()->unix_time());
    }
  }

  for (auto file_id : get_story_file_ids(story)) {
    td_->file_manager_->check_local_location_async(file_id, true);
  }

  bool is_active = is_active_story(story);
  bool need_increment_story_views = story_id.is_server() && !is_active && story->is_pinned_;
  bool need_read_story = story_id.is_server() && is_active;

  if (need_increment_story_views) {
    auto &story_views = pending_story_views_[owner_dialog_id];
    story_views.story_ids_.insert(story_id);
    if (!story_views.has_query_) {
      increment_story_views(owner_dialog_id, story_views);
    }
  }

  if (need_read_story && on_update_read_stories(owner_dialog_id, story_id)) {
    read_stories_on_server(owner_dialog_id, story_id, 0);
  }

  promise.set_value(Unit());
}

void StoryManager::close_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read, "close_story"));
  if (!story_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid story identifier specified"));
  }

  StoryFullId story_full_id{owner_dialog_id, story_id};
  if (can_get_story_view_count(owner_dialog_id) && story_id.is_server()) {
    auto &open_count = opened_stories_with_view_count_[story_full_id];
    if (open_count == 0) {
      return promise.set_error(Status::Error(400, "The story wasn't opened"));
    }
    if (--open_count == 0) {
      opened_stories_with_view_count_.erase(story_full_id);
      if (opened_stories_with_view_count_.empty()) {
        interaction_info_update_timeout_.cancel_timeout();
      }
    }
  }

  const Story *story = get_story(story_full_id);
  if (story == nullptr) {
    return promise.set_value(Unit());
  }

  if (story_id.is_server()) {
    auto &open_count = opened_stories_[story_full_id];
    if (open_count > 0 && --open_count == 0) {
      opened_stories_.erase(story_full_id);
      story_reload_timeout_.cancel_timeout(story->global_id_);
    }
  }

  promise.set_value(Unit());
}

void StoryManager::view_story_message(StoryFullId story_full_id) {
  if (!story_full_id.get_story_id().is_server()) {
    return;
  }

  const Story *story = get_story_force(story_full_id, "view_story_message");
  if (story == nullptr || story->receive_date_ < G()->unix_time() - VIEWED_STORY_POLL_PERIOD) {
    reload_story(story_full_id, Promise<Unit>(), "view_story_message");
  }
}

void StoryManager::on_story_replied(StoryFullId story_full_id, UserId replier_user_id) {
  if (!replier_user_id.is_valid() || replier_user_id == td_->user_manager_->get_my_id() ||
      !story_full_id.get_story_id().is_server()) {
    return;
  }
  const Story *story = get_story_force(story_full_id, "on_story_replied");
  if (story == nullptr || !is_my_story(story_full_id.get_dialog_id())) {
    return;
  }

  if (story->content_ != nullptr && G()->unix_time() < get_story_viewers_expire_date(story) &&
      story->interaction_info_.definitely_has_no_user(replier_user_id)) {
    td_->create_handler<GetStoriesViewsQuery>()->send(story_full_id.get_dialog_id(), {story_full_id.get_story_id()});
  }
}

bool StoryManager::has_suggested_reaction(const Story *story, const ReactionType &reaction_type) {
  if (reaction_type.is_empty() || reaction_type.is_paid_reaction()) {
    return false;
  }
  CHECK(story != nullptr);
  return any_of(story->areas_, [&reaction_type](const auto &area) { return area.has_reaction_type(reaction_type); });
}

bool StoryManager::can_use_story_reaction(const Story *story, const ReactionType &reaction_type) const {
  if (reaction_type.is_empty()) {
    return true;
  }
  if (reaction_type.is_custom_reaction()) {
    if (td_->option_manager_->get_option_boolean("is_premium")) {
      return true;
    }
    if (has_suggested_reaction(story, reaction_type)) {
      return true;
    }
    return false;
  }
  if (reaction_type.is_paid_reaction()) {
    return false;
  }
  return td_->reaction_manager_->is_active_reaction(reaction_type);
}

void StoryManager::on_story_chosen_reaction_changed(StoryFullId story_full_id, Story *story,
                                                    const ReactionType &reaction_type) {
  if (story == nullptr || story->chosen_reaction_type_ == reaction_type) {
    return;
  }

  if (story_full_id.get_dialog_id().get_type() != DialogType::User) {
    bool need_add = has_suggested_reaction(story, reaction_type);
    bool need_remove = has_suggested_reaction(story, story->chosen_reaction_type_);
    if (need_add || need_remove) {
      story->interaction_info_.set_chosen_reaction_type(need_add ? reaction_type : ReactionType(),
                                                        story->chosen_reaction_type_);
    }
  }
  story->chosen_reaction_type_ = reaction_type;
  on_story_changed(story_full_id, story, true, true);
}

void StoryManager::set_story_reaction(StoryFullId story_full_id, ReactionType reaction_type, bool add_to_recent,
                                      Promise<Unit> &&promise) {
  auto owner_dialog_id = story_full_id.get_dialog_id();
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read,
                                                                        "set_story_reaction"));
  if (!story_full_id.get_story_id().is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid story identifier specified"));
  }
  if (!story_full_id.get_story_id().is_server()) {
    return promise.set_error(Status::Error(400, "Can't react to the story"));
  }

  Story *story = get_story_force(story_full_id, "set_story_reaction");
  if (story == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }

  if (!can_use_story_reaction(story, reaction_type)) {
    return promise.set_error(Status::Error(400, "The reaction isn't available for the story"));
  }

  if (story->chosen_reaction_type_ == reaction_type) {
    return promise.set_value(Unit());
  }

  if (add_to_recent) {
    td_->reaction_manager_->add_recent_reaction(reaction_type);
  }

  on_story_chosen_reaction_changed(story_full_id, story, reaction_type);

  being_set_story_reactions_[story_full_id] += 2;

  // TODO cancel previous queries, log event
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), story_full_id,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    send_closure(actor_id, &StoryManager::on_set_story_reaction, story_full_id, std::move(result), std::move(promise));
  });

  td_->create_handler<SendStoryReactionQuery>(std::move(query_promise))
      ->send(story_full_id, reaction_type, add_to_recent);
}

void StoryManager::on_set_story_reaction(StoryFullId story_full_id, Result<Unit> &&result, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto need_reload_story = result.is_error();

  auto it = being_set_story_reactions_.find(story_full_id);
  CHECK(it != being_set_story_reactions_.end());
  it->second -= 2;
  if (it->second <= 1) {
    if (it->second == 1) {
      need_reload_story = true;
    }
    being_set_story_reactions_.erase(it);
  }

  if (!have_story_force(story_full_id)) {
    return promise.set_value(Unit());
  }

  if (need_reload_story) {
    reload_story(story_full_id, Promise<Unit>(), "on_set_story_reaction");
  }

  promise.set_result(std::move(result));
}

void StoryManager::schedule_interaction_info_update() {
  if (interaction_info_update_timeout_.has_timeout()) {
    return;
  }

  interaction_info_update_timeout_.set_callback(std::move(update_interaction_info_static));
  interaction_info_update_timeout_.set_callback_data(static_cast<void *>(this));
  interaction_info_update_timeout_.set_timeout_in(10.0);
}

void StoryManager::update_interaction_info_static(void *story_manager) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(story_manager != nullptr);
  static_cast<StoryManager *>(story_manager)->update_interaction_info();
}

void StoryManager::update_interaction_info() {
  if (opened_stories_with_view_count_.empty()) {
    return;
  }
  FlatHashMap<DialogId, vector<StoryId>, DialogIdHash> split_story_ids;
  for (auto &it : opened_stories_with_view_count_) {
    auto story_full_id = it.first;
    auto &story_ids = split_story_ids[story_full_id.get_dialog_id()];
    if (story_ids.size() < 100) {
      auto story_id = story_full_id.get_story_id();
      CHECK(story_id.is_server());
      story_ids.push_back(story_id);
    }
  }
  for (auto &story_ids : split_story_ids) {
    td_->create_handler<GetStoriesViewsQuery>()->send(story_ids.first, std::move(story_ids.second));
  }
}

void StoryManager::increment_story_views(DialogId owner_dialog_id, PendingStoryViews &story_views) {
  CHECK(!story_views.has_query_);
  vector<StoryId> viewed_story_ids;
  const size_t MAX_VIEWED_STORIES = 200;  // server-side limit
  while (!story_views.story_ids_.empty() && viewed_story_ids.size() < MAX_VIEWED_STORIES) {
    auto story_id_it = story_views.story_ids_.begin();
    auto story_id = *story_id_it;
    story_views.story_ids_.erase(story_id_it);
    CHECK(story_id.is_server());
    viewed_story_ids.push_back(story_id);
  }
  CHECK(!viewed_story_ids.empty());
  story_views.has_query_ = true;
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), owner_dialog_id](Result<Unit>) {
    send_closure(actor_id, &StoryManager::on_increment_story_views, owner_dialog_id);
  });
  td_->create_handler<IncrementStoryViewsQuery>(std::move(promise))->send(owner_dialog_id, std::move(viewed_story_ids));
}

void StoryManager::on_increment_story_views(DialogId owner_dialog_id) {
  if (G()->close_flag()) {
    return;
  }

  auto &story_views = pending_story_views_[owner_dialog_id];
  CHECK(story_views.has_query_);
  story_views.has_query_ = false;
  if (story_views.story_ids_.empty()) {
    pending_story_views_.erase(owner_dialog_id);
    return;
  }
  increment_story_views(owner_dialog_id, story_views);
}

class StoryManager::ReadStoriesOnServerLogEvent {
 public:
  DialogId dialog_id_;
  StoryId max_story_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
    td::store(max_story_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
    td::parse(max_story_id_, parser);
  }
};

uint64 StoryManager::save_read_stories_on_server_log_event(DialogId dialog_id, StoryId max_story_id) {
  ReadStoriesOnServerLogEvent log_event{dialog_id, max_story_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ReadStoriesOnServer,
                    get_log_event_storer(log_event));
}

void StoryManager::read_stories_on_server(DialogId owner_dialog_id, StoryId story_id, uint64 log_event_id) {
  CHECK(story_id.is_server());
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_read_stories_on_server_log_event(owner_dialog_id, story_id);
  }

  td_->create_handler<ReadStoriesQuery>(get_erase_log_event_promise(log_event_id))->send(owner_dialog_id, story_id);
}

Status StoryManager::can_get_story_viewers(StoryFullId story_full_id, const Story *story, int32 unix_time) const {
  CHECK(story != nullptr);
  if (!is_my_story(story_full_id.get_dialog_id())) {
    return Status::Error(400, "Story must be outgoing");
  }
  if (!story_full_id.get_story_id().is_server()) {
    return Status::Error(400, "Story is not sent yet");
  }
  if (story->interaction_info_.get_reaction_count() > 0) {
    return Status::OK();
  }
  if (story->interaction_info_.has_hidden_viewers() && unix_time >= get_story_viewers_expire_date(story)) {
    return Status::Error(400, "Story is too old");
  }
  return Status::OK();
}

bool StoryManager::has_unexpired_viewers(StoryFullId story_full_id, const Story *story) const {
  CHECK(story != nullptr);
  return is_my_story(story_full_id.get_dialog_id()) && story_full_id.get_story_id().is_server() &&
         G()->unix_time() < get_story_viewers_expire_date(story);
}

void StoryManager::get_channel_differences_if_needed(
    telegram_api::object_ptr<telegram_api::stories_storyViewsList> &&story_views,
    Promise<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> promise) {
  td_->user_manager_->on_get_users(std::move(story_views->users_), "stories_storyViewsList");
  td_->chat_manager_->on_get_chats(std::move(story_views->chats_), "stories_storyViewsList");

  vector<const telegram_api::object_ptr<telegram_api::Message> *> messages;
  for (const auto &view : story_views->views_) {
    CHECK(view != nullptr);
    if (view->get_id() != telegram_api::storyViewPublicForward::ID) {
      continue;
    }
    messages.push_back(&static_cast<const telegram_api::storyViewPublicForward *>(view.get())->message_);
  }
  td_->messages_manager_->get_channel_differences_if_needed(
      messages,
      PromiseCreator::lambda([actor_id = actor_id(this), story_views = std::move(story_views),
                              promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(std::move(story_views));
        }
      }),
      "stories_storyViewsList");
}

void StoryManager::get_story_interactions(StoryId story_id, const string &query, bool only_contacts,
                                          bool prefer_forwards, bool prefer_with_reaction, const string &offset,
                                          int32 limit,
                                          Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise) {
  auto owner_dialog_id = td_->dialog_manager_->get_my_dialog_id();
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (!story_id.is_server()) {
    return promise.set_value(td_api::make_object<td_api::storyInteractions>());
  }

  bool is_full = query.empty() && !only_contacts;
  bool is_first = is_full && offset.empty();
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), story_id, is_full, is_first, promise = std::move(promise)](
          Result<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> result) mutable {
        send_closure(actor_id, &StoryManager::on_get_story_interactions, story_id, is_full, is_first, std::move(result),
                     std::move(promise));
      });

  td_->create_handler<GetStoryViewsListQuery>(std::move(query_promise))
      ->send(owner_dialog_id, story_id, query, only_contacts, prefer_forwards, prefer_with_reaction, offset, limit);
}

void StoryManager::on_get_story_interactions(
    StoryId story_id, bool is_full, bool is_first,
    Result<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> r_view_list,
    Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise) {
  G()->ignore_result_if_closing(r_view_list);
  if (r_view_list.is_error()) {
    return promise.set_error(r_view_list.move_as_error());
  }
  auto view_list = r_view_list.move_as_ok();

  auto owner_dialog_id = td_->dialog_manager_->get_my_dialog_id();
  CHECK(story_id.is_server());
  StoryFullId story_full_id{owner_dialog_id, story_id};
  Story *story = get_story_editable(story_full_id);
  if (story == nullptr) {
    return promise.set_value(td_api::make_object<td_api::storyInteractions>());
  }

  auto total_count = view_list->count_;
  if (total_count < 0 || static_cast<size_t>(total_count) < view_list->views_.size()) {
    LOG(ERROR) << "Receive total_count = " << total_count << " and " << view_list->views_.size() << " story viewers";
    total_count = static_cast<int32>(view_list->views_.size());
  }
  auto total_reaction_count = view_list->reactions_count_;
  if (total_reaction_count < 0 || total_reaction_count > total_count) {
    LOG(ERROR) << "Receive total_reaction_count = " << total_reaction_count << " with " << total_count
               << " story viewers";
    total_reaction_count = total_count;
  }
  auto total_forward_count = max(view_list->forwards_count_, 0);

  StoryViewers story_viewers(td_, total_count, total_forward_count, total_reaction_count, std::move(view_list->views_),
                             std::move(view_list->next_offset_));
  if (story->content_ != nullptr) {
    bool is_changed = false;
    if (is_full && story->interaction_info_.set_counts(total_count, total_reaction_count)) {
      is_changed = true;
    }
    if (is_first && story->interaction_info_.set_recent_viewer_user_ids(story_viewers.get_viewer_user_ids())) {
      is_changed = true;
    }
    if (is_changed) {
      on_story_changed(story_full_id, story, true, true);
    }
  }

  on_view_dialog_active_stories(story_viewers.get_actor_dialog_ids());
  promise.set_value(story_viewers.get_story_interactions_object(td_));
}

void StoryManager::get_channel_differences_if_needed(
    telegram_api::object_ptr<telegram_api::stories_storyReactionsList> &&story_reactions,
    Promise<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> promise) {
  td_->user_manager_->on_get_users(std::move(story_reactions->users_), "stories_storyReactionsList");
  td_->chat_manager_->on_get_chats(std::move(story_reactions->chats_), "stories_storyReactionsList");

  vector<const telegram_api::object_ptr<telegram_api::Message> *> messages;
  for (const auto &reaction : story_reactions->reactions_) {
    CHECK(reaction != nullptr);
    if (reaction->get_id() != telegram_api::storyReactionPublicForward::ID) {
      continue;
    }
    messages.push_back(&static_cast<const telegram_api::storyReactionPublicForward *>(reaction.get())->message_);
  }
  td_->messages_manager_->get_channel_differences_if_needed(
      messages,
      PromiseCreator::lambda([actor_id = actor_id(this), story_reactions = std::move(story_reactions),
                              promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(std::move(story_reactions));
        }
      }),
      "stories_storyReactionsList");
}

void StoryManager::get_dialog_story_interactions(StoryFullId story_full_id, ReactionType reaction_type,
                                                 bool prefer_forwards, const string &offset, int32 limit,
                                                 Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise) {
  const Story *story = get_story(story_full_id);
  if (story == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (!story_full_id.get_story_id().is_server()) {
    return promise.set_value(td_api::make_object<td_api::storyInteractions>());
  }
  if (reaction_type.is_paid_reaction()) {
    return promise.set_error(Status::Error(400, "Stories can't have paid reactions"));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), story_full_id, promise = std::move(promise)](
          Result<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> result) mutable {
        send_closure(actor_id, &StoryManager::on_get_dialog_story_interactions, story_full_id, std::move(result),
                     std::move(promise));
      });

  td_->create_handler<GetStoryReactionsListQuery>(std::move(query_promise))
      ->send(story_full_id, reaction_type, prefer_forwards, offset, limit);
}

void StoryManager::on_get_dialog_story_interactions(
    StoryFullId story_full_id,
    Result<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> r_reaction_list,
    Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise) {
  G()->ignore_result_if_closing(r_reaction_list);
  if (r_reaction_list.is_error()) {
    return promise.set_error(r_reaction_list.move_as_error());
  }
  auto reaction_list = r_reaction_list.move_as_ok();

  Story *story = get_story_editable(story_full_id);
  if (story == nullptr) {
    return promise.set_value(td_api::make_object<td_api::storyInteractions>());
  }

  auto total_count = reaction_list->count_;
  if (total_count < 0 || static_cast<size_t>(total_count) < reaction_list->reactions_.size()) {
    LOG(ERROR) << "Receive total_count = " << total_count << " and " << reaction_list->reactions_.size()
               << " story reactioners";
    total_count = static_cast<int32>(reaction_list->reactions_.size());
  }

  StoryViewers story_viewers(td_, total_count, std::move(reaction_list->reactions_),
                             std::move(reaction_list->next_offset_));
  on_view_dialog_active_stories(story_viewers.get_actor_dialog_ids());
  promise.set_value(story_viewers.get_story_interactions_object(td_));
}

void StoryManager::report_story(StoryFullId story_full_id, const string &option_id, const string &text,
                                Promise<td_api::object_ptr<td_api::ReportStoryResult>> &&promise) {
  if (!have_story_force(story_full_id)) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!story_full_id.is_server()) {
    return promise.set_error(Status::Error(400, "Story can't be reported"));
  }

  td_->create_handler<ReportStoryQuery>(std::move(promise))->send(story_full_id, option_id, text);
}

void StoryManager::activate_stealth_mode(Promise<Unit> &&promise) {
  td_->create_handler<ActivateStealthModeQuery>(std::move(promise))->send();
}

bool StoryManager::have_story(StoryFullId story_full_id) const {
  return get_story(story_full_id) != nullptr;
}

bool StoryManager::have_story_force(StoryFullId story_full_id) {
  return get_story_force(story_full_id, "have_story_force") != nullptr;
}

int32 StoryManager::get_story_date(StoryFullId story_full_id) {
  const auto *story = get_story_force(story_full_id, "get_story_date");
  return story != nullptr ? story->date_ : 0;
}

bool StoryManager::is_inaccessible_story(StoryFullId story_full_id) const {
  return inaccessible_story_full_ids_.count(story_full_id) > 0;
}

int32 StoryManager::get_story_duration(StoryFullId story_full_id) const {
  const Story *story = get_story(story_full_id);
  if (story == nullptr || story->content_ == nullptr) {
    return -1;
  }
  auto *content = story->content_.get();
  auto it = being_edited_stories_.find(story_full_id);
  if (it != being_edited_stories_.end()) {
    if (it->second->content_ != nullptr) {
      content = it->second->content_.get();
    }
  }
  return get_story_content_duration(td_, content);
}

void StoryManager::register_story(StoryFullId story_full_id, MessageFullId message_full_id,
                                  QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  CHECK(story_full_id.is_server());

  LOG(INFO) << "Register " << story_full_id << " from " << message_full_id << '/' << quick_reply_message_full_id
            << " from " << source;
  if (quick_reply_message_full_id.is_valid()) {
    story_quick_reply_messages_[story_full_id].insert(quick_reply_message_full_id);
  } else {
    CHECK(message_full_id.get_dialog_id().is_valid());
    story_messages_[story_full_id].insert(message_full_id);
  }
}

void StoryManager::unregister_story(StoryFullId story_full_id, MessageFullId message_full_id,
                                    QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  CHECK(story_full_id.is_server());
  LOG(INFO) << "Unregister " << story_full_id << " from " << message_full_id << '/' << quick_reply_message_full_id
            << " from " << source;
  if (quick_reply_message_full_id.is_valid()) {
    auto &message_ids = story_quick_reply_messages_[story_full_id];
    auto is_deleted = message_ids.erase(quick_reply_message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << story_full_id << ' ' << quick_reply_message_full_id;
    if (message_ids.empty()) {
      story_quick_reply_messages_.erase(story_full_id);
    }
  } else {
    auto &message_ids = story_messages_[story_full_id];
    auto is_deleted = message_ids.erase(message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << story_full_id << ' ' << message_full_id;
    if (message_ids.empty()) {
      story_messages_.erase(story_full_id);
    }
  }
}

StoryManager::StoryInfo StoryManager::get_story_info(StoryFullId story_full_id) const {
  const auto *story = get_story(story_full_id);
  auto story_id = story_full_id.get_story_id();
  if (story == nullptr) {
    LOG(INFO) << "Tried to get info about deleted " << story_full_id;
    return {};
  }
  if (story_id.is_server() && !is_active_story(story)) {
    LOG(INFO) << "Tried to get info about expired " << story_full_id;
    return {};
  }
  StoryInfo story_info;
  story_info.story_id_ = story_id;
  story_info.date_ = story->date_;
  story_info.expire_date_ = story->expire_date_;
  story_info.is_for_close_friends_ = story->is_for_close_friends_;
  return story_info;
}

td_api::object_ptr<td_api::storyInfo> StoryManager::get_story_info_object(StoryFullId story_full_id) const {
  auto story_info = get_story_info(story_full_id);
  if (!story_info.story_id_.is_valid()) {
    return nullptr;
  }
  return td_api::make_object<td_api::storyInfo>(story_info.story_id_.get(), story_info.date_,
                                                story_info.is_for_close_friends_);
}

td_api::object_ptr<td_api::story> StoryManager::get_story_object(StoryFullId story_full_id) const {
  return get_story_object(story_full_id, get_story(story_full_id));
}

td_api::object_ptr<td_api::story> StoryManager::get_story_object(StoryFullId story_full_id, const Story *story) const {
  if (story == nullptr || story->content_ == nullptr) {
    return nullptr;
  }
  auto owner_dialog_id = story_full_id.get_dialog_id();
  if (!can_access_expired_story(owner_dialog_id, story) && !is_active_story(story)) {
    return nullptr;
  }

  td_api::object_ptr<td_api::StoryPrivacySettings> privacy_settings =
      story->privacy_rules_.get_story_privacy_settings_object(td_);
  if (privacy_settings == nullptr) {
    if (story->is_public_) {
      privacy_settings = td_api::make_object<td_api::storyPrivacySettingsEveryone>();
    } else if (story->is_for_contacts_) {
      privacy_settings = td_api::make_object<td_api::storyPrivacySettingsContacts>();
    } else if (story->is_for_close_friends_) {
      privacy_settings = td_api::make_object<td_api::storyPrivacySettingsCloseFriends>();
    } else {
      privacy_settings = td_api::make_object<td_api::storyPrivacySettingsSelectedUsers>();
    }
  }

  bool is_being_edited = false;
  bool is_edited = story->is_edited_;

  auto story_id = story_full_id.get_story_id();
  CHECK(story_id.is_valid());
  auto *content = story->content_.get();
  auto *areas = &story->areas_;
  auto *caption = &story->caption_;
  if (story_id.is_server()) {
    auto it = being_edited_stories_.find(story_full_id);
    if (it != being_edited_stories_.end()) {
      if (it->second->content_ != nullptr) {
        content = it->second->content_.get();
      }
      if (it->second->edit_media_areas_) {
        areas = &it->second->areas_;
      }
      if (it->second->edit_caption_) {
        caption = &it->second->caption_;
      }
      is_being_edited = true;
    }
  }

  auto is_being_sent = !story_id.is_server();
  auto changelog_dialog_id = get_changelog_story_dialog_id();
  auto is_visible_only_for_self = !story_id.is_server() || owner_dialog_id == changelog_dialog_id ||
                                  (!story->is_pinned_ && !is_active_story(story));
  auto can_be_deleted = can_delete_story(story_full_id, story);
  auto can_be_edited = can_edit_story(story_full_id, story);
  auto can_be_forwarded = !story->noforwards_ && story_id.is_server() &&
                          privacy_settings->get_id() == td_api::storyPrivacySettingsEveryone::ID;
  auto can_be_replied =
      story_id.is_server() && owner_dialog_id != changelog_dialog_id && owner_dialog_id.get_type() == DialogType::User;
  auto can_toggle_is_pinned = can_toggle_story_is_pinned(story_full_id, story);
  auto unix_time = G()->unix_time();
  auto can_get_statistics = can_get_story_statistics(story_full_id, story);
  auto can_get_interactions = can_get_story_viewers(story_full_id, story, unix_time).is_ok();
  auto repost_info =
      story->forward_info_ != nullptr ? story->forward_info_->get_story_repost_info_object(td_) : nullptr;
  auto interaction_info = story->interaction_info_.get_story_interaction_info_object(td_);
  auto has_expired_viewers = is_my_story(owner_dialog_id) && story_id.is_server() &&
                             unix_time >= get_story_viewers_expire_date(story) && interaction_info != nullptr &&
                             interaction_info->view_count_ > interaction_info->reaction_count_;
  const auto &reaction_counts = story->interaction_info_.get_reaction_counts();
  auto story_areas = transform(*areas, [td = td_, &reaction_counts](const MediaArea &media_area) {
    return media_area.get_story_area_object(td, reaction_counts);
  });

  story->is_update_sent_ = true;

  return td_api::make_object<td_api::story>(
      story_id.get(), td_->dialog_manager_->get_chat_id_object(owner_dialog_id, "get_story_object"),
      story->sender_dialog_id_ == DialogId()
          ? nullptr
          : get_message_sender_object(td_, story->sender_dialog_id_, "get_story_object 2"),
      story->date_, is_being_sent, is_being_edited, is_edited, story->is_pinned_, is_visible_only_for_self,
      can_be_deleted, can_be_edited, can_be_forwarded, can_be_replied, can_toggle_is_pinned, can_get_statistics,
      can_get_interactions, has_expired_viewers, std::move(repost_info), std::move(interaction_info),
      story->chosen_reaction_type_.get_reaction_type_object(), std::move(privacy_settings),
      get_story_content_object(td_, content), std::move(story_areas),
      get_formatted_text_object(td_->user_manager_.get(), *caption, true, get_story_content_duration(td_, content)));
}

td_api::object_ptr<td_api::stories> StoryManager::get_stories_object(int32 total_count,
                                                                     const vector<StoryFullId> &story_full_ids,
                                                                     const vector<StoryId> &pinned_story_ids) const {
  if (total_count == -1) {
    total_count = static_cast<int32>(story_full_ids.size());
  }
  return td_api::make_object<td_api::stories>(
      total_count,
      transform(story_full_ids, [this](StoryFullId story_full_id) { return get_story_object(story_full_id); }),
      StoryId::get_input_story_ids(pinned_story_ids));
}

td_api::object_ptr<td_api::chatActiveStories> StoryManager::get_chat_active_stories_object(
    DialogId owner_dialog_id, const ActiveStories *active_stories) const {
  StoryListId story_list_id;
  StoryId max_read_story_id;
  vector<td_api::object_ptr<td_api::storyInfo>> stories;
  int64 order = 0;
  if (active_stories != nullptr) {
    story_list_id = active_stories->story_list_id_;
    max_read_story_id = active_stories->max_read_story_id_;
    for (auto story_id : active_stories->story_ids_) {
      auto story_info = get_story_info_object({owner_dialog_id, story_id});
      if (story_info != nullptr) {
        stories.push_back(std::move(story_info));
      }
    }
    if (stories.size() != active_stories->story_ids_.size()) {
      send_closure_later(G()->story_manager(), &StoryManager::update_active_stories, owner_dialog_id);
    }
    if (story_list_id.is_valid()) {
      order = active_stories->public_order_;
    }
  } else {
    story_list_id = get_dialog_story_list_id(owner_dialog_id);
  }
  auto yet_unsent_story_ids_it = yet_unsent_story_ids_.find(owner_dialog_id);
  if (yet_unsent_story_ids_it != yet_unsent_story_ids_.end()) {
    for (auto story_id : yet_unsent_story_ids_it->second) {
      auto story_info = get_story_info_object({owner_dialog_id, story_id});
      if (story_info != nullptr) {
        stories.push_back(std::move(story_info));
      }
    }
  }
  return td_api::make_object<td_api::chatActiveStories>(
      td_->dialog_manager_->get_chat_id_object(owner_dialog_id, "updateChatActiveStories"),
      story_list_id.get_story_list_object(), order, max_read_story_id.get(), std::move(stories));
}

td_api::object_ptr<td_api::CanSendStoryResult> StoryManager::get_can_send_story_result_object(const Status &error,
                                                                                              bool force) {
  CHECK(error.is_error());
  if (error.message() == "PREMIUM_ACCOUNT_REQUIRED") {
    return td_api::make_object<td_api::canSendStoryResultPremiumNeeded>();
  }
  if (error.message() == "BOOSTS_REQUIRED") {
    return td_api::make_object<td_api::canSendStoryResultBoostNeeded>();
  }
  if (error.message() == "STORIES_TOO_MUCH") {
    return td_api::make_object<td_api::canSendStoryResultActiveStoryLimitExceeded>();
  }
  if (begins_with(error.message(), "STORY_SEND_FLOOD_WEEKLY_")) {
    auto r_next_date = to_integer_safe<int32>(error.message().substr(Slice("STORY_SEND_FLOOD_WEEKLY_").size()));
    if (r_next_date.is_ok() && r_next_date.ok() > 0) {
      auto retry_after = r_next_date.ok() - G()->unix_time();
      if (retry_after > 0 || force) {
        return td_api::make_object<td_api::canSendStoryResultWeeklyLimitExceeded>(max(retry_after, 0));
      } else {
        return td_api::make_object<td_api::canSendStoryResultOk>();
      }
    }
  }
  if (begins_with(error.message(), "STORY_SEND_FLOOD_MONTHLY_")) {
    auto r_next_date = to_integer_safe<int32>(error.message().substr(Slice("STORY_SEND_FLOOD_MONTHLY_").size()));
    if (r_next_date.is_ok() && r_next_date.ok() > 0) {
      auto retry_after = r_next_date.ok() - G()->unix_time();
      if (retry_after > 0 || force) {
        return td_api::make_object<td_api::canSendStoryResultMonthlyLimitExceeded>(max(retry_after, 0));
      } else {
        return td_api::make_object<td_api::canSendStoryResultOk>();
      }
    }
  }
  return nullptr;
}

vector<FileId> StoryManager::get_story_file_ids(const Story *story) const {
  if (story == nullptr || story->content_ == nullptr) {
    return {};
  }
  return get_story_content_file_ids(td_, story->content_.get());
}

void StoryManager::delete_story_files(const Story *story) const {
  for (auto file_id : get_story_file_ids(story)) {
    send_closure(G()->file_manager(), &FileManager::delete_file, file_id, Promise<Unit>(), "delete_story_files");
  }
}

void StoryManager::change_story_files(StoryFullId story_full_id, const Story *story,
                                      const vector<FileId> &old_file_ids) {
  auto new_file_ids = get_story_file_ids(story);
  if (new_file_ids == old_file_ids) {
    return;
  }

  for (auto file_id : old_file_ids) {
    if (!td::contains(new_file_ids, file_id)) {
      send_closure(G()->file_manager(), &FileManager::delete_file, file_id, Promise<Unit>(), "change_story_files");
    }
  }

  auto file_source_id = get_story_file_source_id(story_full_id);
  if (file_source_id.is_valid()) {
    td_->file_manager_->change_files_source(file_source_id, old_file_ids, new_file_ids, "change_story_files");
  }
}

StoryId StoryManager::on_get_story(DialogId owner_dialog_id,
                                   telegram_api::object_ptr<telegram_api::StoryItem> &&story_item_ptr) {
  if (!owner_dialog_id.is_valid()) {
    LOG(ERROR) << "Receive a story in " << owner_dialog_id;
    return {};
  }
  if (td_->auth_manager_->is_bot()) {
    return {};
  }
  CHECK(story_item_ptr != nullptr);
  switch (story_item_ptr->get_id()) {
    case telegram_api::storyItemDeleted::ID:
      return on_get_deleted_story(owner_dialog_id,
                                  telegram_api::move_object_as<telegram_api::storyItemDeleted>(story_item_ptr));
    case telegram_api::storyItemSkipped::ID:
      LOG(ERROR) << "Receive " << to_string(story_item_ptr);
      return {};
    case telegram_api::storyItem::ID: {
      return on_get_new_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItem>(story_item_ptr));
    }
    default:
      UNREACHABLE();
  }
}

StoryId StoryManager::on_get_new_story(DialogId owner_dialog_id,
                                       telegram_api::object_ptr<telegram_api::storyItem> &&story_item) {
  CHECK(story_item != nullptr);
  StoryId story_id(story_item->id_);
  if (!story_id.is_server()) {
    LOG(ERROR) << "Receive " << to_string(story_item);
    return StoryId();
  }
  CHECK(owner_dialog_id.is_valid());
  StoryFullId story_full_id{owner_dialog_id, story_id};
  if (deleted_story_full_ids_.count(story_full_id) > 0) {
    return StoryId();
  }

  td_->dialog_manager_->force_create_dialog(owner_dialog_id, "on_get_new_story");

  StoryId old_story_id;
  auto updates_story_ids_it = update_story_ids_.find(story_full_id);
  if (updates_story_ids_it != update_story_ids_.end()) {
    old_story_id = updates_story_ids_it->second;
    update_story_ids_.erase(updates_story_ids_it);

    LOG(INFO) << "Receive sent " << old_story_id << " as " << story_full_id;

    auto old_story_full_id = StoryFullId(owner_dialog_id, old_story_id);
    const Story *old_story = get_story_force(old_story_full_id, "on_get_new_story");
    if (old_story != nullptr) {
      delete_story_files(old_story);
      stories_.erase(old_story_full_id);
    } else {
      old_story_id = StoryId();
    }
  }

  bool is_bot = td_->auth_manager_->is_bot();
  auto caption =
      get_message_text(td_->user_manager_.get(), std::move(story_item->caption_), std::move(story_item->entities_),
                       true, is_bot, story_item->date_, false, "on_get_new_story");
  auto content = get_story_content(td_, std::move(story_item->media_), owner_dialog_id);
  if (content == nullptr) {
    return StoryId();
  }

  Story *story = get_story_force(story_full_id, "on_get_new_story");
  bool is_changed = false;
  bool need_save_to_database = false;
  if (story == nullptr) {
    auto s = make_unique<Story>();
    story = s.get();
    stories_.set(story_full_id, std::move(s));
    is_changed = true;
    story_item->min_ = false;
    register_story_global_id(story_full_id, story);

    inaccessible_story_full_ids_.erase(story_full_id);
    failed_to_load_story_full_ids_.erase(story_full_id);
    LOG(INFO) << "Add new " << story_full_id;
  }
  CHECK(story != nullptr);

  story->receive_date_ = G()->unix_time();

  const BeingEditedStory *edited_story = nullptr;
  auto it = being_edited_stories_.find(story_full_id);
  if (it != being_edited_stories_.end()) {
    edited_story = it->second.get();
  }

  auto content_type = content->get_type();
  auto old_file_ids = get_story_file_ids(story);
  if (edited_story != nullptr && edited_story->content_ != nullptr) {
    story->content_ = std::move(content);
    need_save_to_database = true;
  } else if (story->content_ == nullptr || story->content_->get_type() != content_type) {
    story->content_ = std::move(content);
    is_changed = true;
  } else {
    merge_story_contents(td_, story->content_.get(), content.get(), owner_dialog_id, need_save_to_database, is_changed);
    story->content_ = std::move(content);
  }

  if (is_changed || need_save_to_database) {
    change_story_files(story_full_id, story, old_file_ids);
  }

  if (story_item->date_ <= 0) {
    LOG(ERROR) << "Receive " << story_full_id << " sent at " << story_item->date_;
    story_item->date_ = 1;
  }
  if (story_item->expire_date_ <= story_item->date_) {
    LOG(ERROR) << "Receive " << story_full_id << " sent at " << story_item->date_ << ", but expired at "
               << story_item->expire_date_;
    story_item->expire_date_ = story_item->date_ + 1;
  }

  if (story->is_edited_ != story_item->edited_ || story->is_pinned_ != story_item->pinned_ ||
      story->is_public_ != story_item->public_ || story->is_for_close_friends_ != story_item->close_friends_ ||
      story->is_for_contacts_ != story_item->contacts_ ||
      story->is_for_selected_contacts_ != story_item->selected_contacts_ ||
      story->noforwards_ != story_item->noforwards_ || story->date_ != story_item->date_ ||
      story->expire_date_ != story_item->expire_date_) {
    story->is_edited_ = story_item->edited_;
    story->is_pinned_ = story_item->pinned_;
    story->is_public_ = story_item->public_;
    story->is_for_close_friends_ = story_item->close_friends_;
    story->is_for_contacts_ = story_item->contacts_;
    story->is_for_selected_contacts_ = story_item->selected_contacts_;
    story->noforwards_ = story_item->noforwards_;
    story->date_ = story_item->date_;
    story->expire_date_ = story_item->expire_date_;
    is_changed = true;
  }
  if (owner_dialog_id.get_type() == DialogType::User && !is_my_story(owner_dialog_id)) {
    story_item->min_ = false;
  }
  unique_ptr<StoryForwardInfo> forward_info =
      story_item->fwd_from_ != nullptr ? make_unique<StoryForwardInfo>(td_, std::move(story_item->fwd_from_)) : nullptr;
  if (story->forward_info_ != forward_info) {
    story->forward_info_ = std::move(forward_info);
    is_changed = true;
  }
  auto sender_dialog_id = story_item->from_id_ != nullptr ? DialogId(story_item->from_id_) : DialogId();
  if (sender_dialog_id != story->sender_dialog_id_) {
    story->sender_dialog_id_ = sender_dialog_id;
    is_changed = true;
  }
  if (!story_item->min_) {
    auto privacy_rules = UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(story_item->privacy_));
    auto interaction_info = StoryInteractionInfo(td_, std::move(story_item->views_));
    auto chosen_reaction_type = ReactionType(std::move(story_item->sent_reaction_));

    if (story->privacy_rules_ != privacy_rules) {
      story->privacy_rules_ = std::move(privacy_rules);
      is_changed = true;
    }
    if (story->interaction_info_ != interaction_info || story->chosen_reaction_type_ != chosen_reaction_type) {
      auto pending_reaction_it = being_set_story_reactions_.find(story_full_id);
      if (pending_reaction_it != being_set_story_reactions_.end()) {
        LOG(INFO) << "Postpone " << story_full_id << " interaction info update, because there is a pending reaction";
        pending_reaction_it->second |= 1;
      } else {
        story->interaction_info_ = std::move(interaction_info);
        story->chosen_reaction_type_ = std::move(chosen_reaction_type);
        is_changed = true;
      }
    }

    if (is_my_story(owner_dialog_id)) {
      story_item->out_ = true;
    }
    if (story->is_outgoing_ != story_item->out_) {
      story->is_outgoing_ = story_item->out_;
      need_save_to_database = true;
    }
  }
  if (story->caption_ != caption) {
    story->caption_ = std::move(caption);
    if (edited_story != nullptr && edited_story->edit_caption_) {
      need_save_to_database = true;
    } else {
      is_changed = true;
    }
  }
  vector<MediaArea> media_areas;
  for (auto &media_area_ptr : story_item->media_areas_) {
    MediaArea media_area(td_, std::move(media_area_ptr));
    if (media_area.is_valid()) {
      media_areas.push_back(std::move(media_area));
    }
  }
  if (story->areas_ != media_areas) {
    story->areas_ = std::move(media_areas);
    if (edited_story != nullptr && edited_story->edit_media_areas_) {
      need_save_to_database = true;
    } else {
      is_changed = true;
    }
  }

  Dependencies dependencies;
  add_story_dependencies(dependencies, story);
  for (auto dependent_dialog_id : dependencies.get_dialog_ids()) {
    td_->dialog_manager_->force_create_dialog(dependent_dialog_id, "on_get_new_story", true);
  }

  on_story_changed(story_full_id, story, is_changed, need_save_to_database);

  LOG(INFO) << "Receive " << story_full_id;

  if (is_active_story(story)) {
    auto active_stories = get_active_stories_force(owner_dialog_id, "on_get_new_story");
    if (active_stories == nullptr) {
      if (is_subscribed_to_dialog_stories(owner_dialog_id)) {
        load_dialog_expiring_stories(owner_dialog_id, 0, "on_get_new_story");

        if (updated_active_stories_.count(owner_dialog_id)) {
          on_update_active_stories(owner_dialog_id, StoryId(), vector<StoryId>{story_id}, Promise<Unit>(),
                                   "on_get_new_story 1");
        } else if (old_story_id.is_valid()) {
          send_update_chat_active_stories(owner_dialog_id, active_stories, "on_get_new_story 2");
        }
      } else if (old_story_id.is_valid()) {
        send_update_chat_active_stories(owner_dialog_id, active_stories, "on_get_new_story 3");
      }
    } else if (!contains(active_stories->story_ids_, story_id)) {
      auto story_ids = active_stories->story_ids_;
      story_ids.push_back(story_id);
      size_t i = story_ids.size() - 1;
      while (i > 0 && story_ids[i - 1].get() > story_id.get()) {
        story_ids[i] = story_ids[i - 1];
        i--;
      }
      story_ids[i] = story_id;
      on_update_active_stories(owner_dialog_id, active_stories->max_read_story_id_, std::move(story_ids),
                               Promise<Unit>(), "on_get_new_story");
    } else if (old_story_id.is_valid()) {
      send_update_chat_active_stories(owner_dialog_id, active_stories, "on_get_new_story 4");
    }
  }

  if (old_story_id.is_valid()) {
    send_closure(G()->td(), &Td::send_update,
                 td_api::make_object<td_api::updateStorySendSucceeded>(get_story_object(story_full_id, story),
                                                                       old_story_id.get()));
  }

  return story_id;
}

StoryId StoryManager::on_get_skipped_story(DialogId owner_dialog_id,
                                           telegram_api::object_ptr<telegram_api::storyItemSkipped> &&story_item) {
  CHECK(story_item != nullptr);
  StoryInfo story_info;
  story_info.story_id_ = StoryId(story_item->id_);
  story_info.date_ = story_item->date_;
  story_info.expire_date_ = story_item->expire_date_;
  story_info.is_for_close_friends_ = story_item->close_friends_;
  return on_get_story_info(owner_dialog_id, std::move(story_info));
}

StoryId StoryManager::on_get_story_info(DialogId owner_dialog_id, StoryInfo &&story_info) {
  StoryId story_id = story_info.story_id_;
  if (!story_id.is_server()) {
    LOG(ERROR) << "Receive " << story_id;
    return StoryId();
  }
  if (deleted_story_full_ids_.count({owner_dialog_id, story_id}) > 0) {
    return StoryId();
  }

  td_->dialog_manager_->force_create_dialog(owner_dialog_id, "on_get_story_info");

  StoryFullId story_full_id{owner_dialog_id, story_id};
  Story *story = get_story_editable(story_full_id);
  if (story == nullptr) {
    auto s = make_unique<Story>();
    story = s.get();
    stories_.set(story_full_id, std::move(s));
    register_story_global_id(story_full_id, story);
    story->is_outgoing_ = is_my_story(owner_dialog_id);

    inaccessible_story_full_ids_.erase(story_full_id);
  }
  CHECK(story != nullptr);

  if (story_info.date_ <= 0) {
    LOG(ERROR) << "Receive " << story_full_id << " sent at " << story_info.date_;
    story_info.date_ = 1;
  }
  if (story_info.expire_date_ <= story_info.date_) {
    LOG(ERROR) << "Receive " << story_full_id << " sent at " << story_info.date_ << ", but expired at "
               << story_info.expire_date_;
    story_info.expire_date_ = story_info.date_ + 1;
  }

  if (story->date_ != story_info.date_ || story->expire_date_ != story_info.expire_date_ ||
      story->is_for_close_friends_ != story_info.is_for_close_friends_) {
    story->date_ = story_info.date_;
    story->expire_date_ = story_info.expire_date_;
    story->is_for_close_friends_ = story_info.is_for_close_friends_;
    on_story_changed(story_full_id, story, true, true);
  }
  return story_id;
}

StoryId StoryManager::on_get_deleted_story(DialogId owner_dialog_id,
                                           telegram_api::object_ptr<telegram_api::storyItemDeleted> &&story_item) {
  StoryId story_id(story_item->id_);
  on_delete_story({owner_dialog_id, story_id});
  return story_id;
}

void StoryManager::on_delete_story(StoryFullId story_full_id) {
  auto story_id = story_full_id.get_story_id();
  if (!story_id.is_server()) {
    LOG(ERROR) << "Receive deleted " << story_full_id;
    return;
  }

  update_story_ids_.erase(story_full_id);

  inaccessible_story_full_ids_.set(story_full_id, Time::now());
  send_closure_later(G()->messages_manager(),
                     &MessagesManager::update_story_max_reply_media_timestamp_in_replied_messages, story_full_id);

  const Story *story = get_story_force(story_full_id, "on_delete_story");
  auto owner_dialog_id = story_full_id.get_dialog_id();
  if (story != nullptr) {
    LOG(INFO) << "Delete " << story_full_id;
    if (story->is_update_sent_) {
      send_closure(
          G()->td(), &Td::send_update,
          td_api::make_object<td_api::updateStoryDeleted>(
              td_->dialog_manager_->get_chat_id_object(owner_dialog_id, "updateStoryDeleted"), story_id.get()));
    }
    delete_story_files(story);
    unregister_story_global_id(story);
    stories_.erase(story_full_id);
    auto edited_stories_it = being_edited_stories_.find(story_full_id);
    if (edited_stories_it != being_edited_stories_.end()) {
      CHECK(edited_stories_it->second != nullptr);
      auto log_event_id = edited_stories_it->second->log_event_id_;
      if (log_event_id != 0) {
        binlog_erase(G()->td_db()->get_binlog(), log_event_id);
      }
      being_edited_stories_.erase(edited_stories_it);
    }
    edit_generations_.erase(story_full_id);
  } else {
    LOG(INFO) << "Delete not found " << story_full_id;
  }

  auto active_stories = get_active_stories_force(owner_dialog_id, "on_get_deleted_story");
  if (active_stories != nullptr && contains(active_stories->story_ids_, story_id)) {
    auto story_ids = active_stories->story_ids_;
    td::remove(story_ids, story_id);
    on_update_active_stories(owner_dialog_id, active_stories->max_read_story_id_, std::move(story_ids), Promise<Unit>(),
                             "on_delete_story");
  }

  delete_story_from_database(story_full_id);
}

void StoryManager::delete_story_from_database(StoryFullId story_full_id) {
  if (G()->use_message_database()) {
    LOG(INFO) << "Delete " << story_full_id << " from database";
    G()->td_db()->get_story_db_async()->delete_story(story_full_id, Promise<Unit>());
  }
}

void StoryManager::set_story_expire_timeout(const Story *story) {
  CHECK(story->global_id_ > 0);
  story_expire_timeout_.set_timeout_in(story->global_id_, story->expire_date_ - G()->unix_time());
}

void StoryManager::set_story_can_get_viewers_timeout(const Story *story) {
  CHECK(story->global_id_ > 0);
  story_can_get_viewers_timeout_.set_timeout_in(story->global_id_,
                                                get_story_viewers_expire_date(story) - G()->unix_time() + 2);
}

void StoryManager::on_story_changed(StoryFullId story_full_id, const Story *story, bool is_changed,
                                    bool need_save_to_database, bool from_database) {
  if (!story_full_id.get_story_id().is_server()) {
    return;
  }
  if (is_active_story(story)) {
    set_story_expire_timeout(story);
  }
  if (has_unexpired_viewers(story_full_id, story)) {
    set_story_can_get_viewers_timeout(story);
  }
  if (story->content_ == nullptr) {
    return;
  }
  if (is_changed || need_save_to_database) {
    if (G()->use_message_database() && !from_database) {
      LOG(INFO) << "Add " << story_full_id << " to database";

      int32 expires_at = 0;
      if (is_active_story(story) && !can_access_expired_story(story_full_id.get_dialog_id(), story)) {
        expires_at = story->expire_date_;
      }

      G()->td_db()->get_story_db_async()->add_story(story_full_id, expires_at, NotificationId(),
                                                    log_event_store(*story), Promise<Unit>());
    }

    if (is_changed && story->is_update_sent_) {
      send_update_story(story_full_id, story);
    }

    send_closure_later(G()->messages_manager(),
                       &MessagesManager::update_story_max_reply_media_timestamp_in_replied_messages, story_full_id);
    send_closure_later(G()->web_pages_manager(), &WebPagesManager::on_story_changed, story_full_id);

    if (story_messages_.count(story_full_id) != 0) {
      vector<MessageFullId> message_full_ids;
      story_messages_[story_full_id].foreach(
          [&message_full_ids](const MessageFullId &message_full_id) { message_full_ids.push_back(message_full_id); });
      CHECK(!message_full_ids.empty());
      for (const auto &message_full_id : message_full_ids) {
        send_closure_later(G()->messages_manager(), &MessagesManager::on_external_update_message_content,
                           message_full_id, "on_story_changed", true);
      }
    }

    if (story_quick_reply_messages_.count(story_full_id) != 0) {
      vector<QuickReplyMessageFullId> message_full_ids;
      story_quick_reply_messages_[story_full_id].foreach(
          [&message_full_ids](const QuickReplyMessageFullId &message_full_id) {
            message_full_ids.push_back(message_full_id);
          });
      CHECK(!message_full_ids.empty());
      for (const auto &message_full_id : message_full_ids) {
        send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::on_external_update_message_content,
                           message_full_id, "on_story_changed", true);
      }
    }
  }
}

void StoryManager::register_story_global_id(StoryFullId story_full_id, Story *story) {
  CHECK(story_full_id.is_server());
  CHECK(story->global_id_ == 0);
  story->global_id_ = ++max_story_global_id_;
  stories_by_global_id_[story->global_id_] = story_full_id;
}

void StoryManager::unregister_story_global_id(const Story *story) {
  CHECK(story->global_id_ > 0);
  stories_by_global_id_.erase(story->global_id_);
}

std::pair<int32, vector<StoryId>> StoryManager::on_get_stories(
    DialogId owner_dialog_id, vector<StoryId> &&expected_story_ids,
    telegram_api::object_ptr<telegram_api::stories_stories> &&stories) {
  td_->user_manager_->on_get_users(std::move(stories->users_), "on_get_stories");
  td_->chat_manager_->on_get_chats(std::move(stories->chats_), "on_get_stories");

  vector<StoryId> story_ids;
  for (auto &story : stories->stories_) {
    switch (story->get_id()) {
      case telegram_api::storyItemDeleted::ID:
        on_get_deleted_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItemDeleted>(story));
        break;
      case telegram_api::storyItemSkipped::ID:
        LOG(ERROR) << "Receive " << to_string(story);
        break;
      case telegram_api::storyItem::ID: {
        auto story_id = on_get_new_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItem>(story));
        if (story_id.is_valid()) {
          story_ids.push_back(story_id);
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  auto total_count = stories->count_;
  if (total_count < static_cast<int32>(story_ids.size())) {
    LOG(ERROR) << "Expected at most " << total_count << " stories, but receive " << story_ids.size();
    total_count = static_cast<int32>(story_ids.size());
  }
  if (!expected_story_ids.empty()) {
    FlatHashSet<StoryId, StoryIdHash> all_story_ids;
    for (auto expected_story_id : expected_story_ids) {
      CHECK(expected_story_id != StoryId());
      all_story_ids.insert(expected_story_id);
    }
    for (auto story_id : story_ids) {
      if (all_story_ids.erase(story_id) == 0) {
        LOG(ERROR) << "Receive " << story_id << " in " << owner_dialog_id << ", but didn't request it";
      }
    }
    for (auto story_id : all_story_ids) {
      on_delete_story({owner_dialog_id, story_id});
    }
  }
  return {total_count, std::move(story_ids)};
}

DialogId StoryManager::on_get_dialog_stories(DialogId owner_dialog_id,
                                             telegram_api::object_ptr<telegram_api::peerStories> &&peer_stories,
                                             Promise<Unit> &&promise) {
  if (peer_stories == nullptr) {
    if (owner_dialog_id.is_valid()) {
      LOG(INFO) << "Receive no stories in " << owner_dialog_id;
      on_update_active_stories(owner_dialog_id, StoryId(), {}, std::move(promise), "on_get_dialog_stories");
    } else {
      promise.set_value(Unit());
    }
    return owner_dialog_id;
  }

  DialogId story_dialog_id(peer_stories->peer_);
  if (owner_dialog_id.is_valid() && owner_dialog_id != story_dialog_id) {
    LOG(ERROR) << "Receive stories from " << story_dialog_id << " instead of " << owner_dialog_id;
    on_update_active_stories(owner_dialog_id, StoryId(), {}, std::move(promise), "on_get_dialog_stories 2");
    return owner_dialog_id;
  }
  if (!story_dialog_id.is_valid()) {
    LOG(ERROR) << "Receive stories in " << story_dialog_id;
    promise.set_value(Unit());
    return owner_dialog_id;
  }
  owner_dialog_id = story_dialog_id;

  StoryId max_read_story_id(peer_stories->max_read_id_);
  if (!max_read_story_id.is_server() && max_read_story_id != StoryId()) {
    LOG(ERROR) << "Receive max read " << max_read_story_id;
    max_read_story_id = StoryId();
  }

  vector<StoryId> story_ids;
  for (auto &story : peer_stories->stories_) {
    switch (story->get_id()) {
      case telegram_api::storyItemDeleted::ID:
        on_get_deleted_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItemDeleted>(story));
        break;
      case telegram_api::storyItemSkipped::ID:
        story_ids.push_back(
            on_get_skipped_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItemSkipped>(story)));
        break;
      case telegram_api::storyItem::ID:
        story_ids.push_back(
            on_get_new_story(owner_dialog_id, telegram_api::move_object_as<telegram_api::storyItem>(story)));
        break;
      default:
        UNREACHABLE();
    }
  }

  on_update_active_stories(story_dialog_id, max_read_story_id, std::move(story_ids), std::move(promise),
                           "on_get_dialog_stories 3");
  return story_dialog_id;
}

void StoryManager::on_update_dialog_max_story_ids(DialogId owner_dialog_id, StoryId max_story_id,
                                                  StoryId max_read_story_id) {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      // use send_closure_later because story order can be updated from update_user
      send_closure_later(td_->user_manager_actor_, &UserManager::on_update_user_story_ids,
                         owner_dialog_id.get_user_id(), max_story_id, max_read_story_id);
      break;
    case DialogType::Channel:
      // use send_closure_later because story order can be updated from update_channel
      send_closure_later(td_->chat_manager_actor_, &ChatManager::on_update_channel_story_ids,
                         owner_dialog_id.get_channel_id(), max_story_id, max_read_story_id);
      break;
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      break;
  }
}

void StoryManager::on_update_dialog_max_read_story_id(DialogId owner_dialog_id, StoryId max_read_story_id) {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      td_->user_manager_->on_update_user_max_read_story_id(owner_dialog_id.get_user_id(), max_read_story_id);
      break;
    case DialogType::Channel:
      td_->chat_manager_->on_update_channel_max_read_story_id(owner_dialog_id.get_channel_id(), max_read_story_id);
      break;
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      break;
  }
}

void StoryManager::on_update_dialog_has_pinned_stories(DialogId owner_dialog_id, bool has_pinned_stories) {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      td_->user_manager_->on_update_user_has_pinned_stories(owner_dialog_id.get_user_id(), has_pinned_stories);
      break;
    case DialogType::Channel:
      td_->chat_manager_->on_update_channel_has_pinned_stories(owner_dialog_id.get_channel_id(), has_pinned_stories);
      break;
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      break;
  }
}

void StoryManager::on_update_dialog_stories_hidden(DialogId owner_dialog_id, bool stories_hidden) {
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      td_->user_manager_->on_update_user_stories_hidden(owner_dialog_id.get_user_id(), stories_hidden);
      break;
    case DialogType::Channel:
      td_->chat_manager_->on_update_channel_stories_hidden(owner_dialog_id.get_channel_id(), stories_hidden);
      break;
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      break;
  }
}

void StoryManager::update_active_stories(DialogId owner_dialog_id) {
  auto active_stories = get_active_stories(owner_dialog_id);
  if (active_stories != nullptr) {
    auto story_ids = active_stories->story_ids_;
    on_update_active_stories(owner_dialog_id, active_stories->max_read_story_id_, std::move(story_ids), Promise<Unit>(),
                             "update_active_stories");
  }
}

void StoryManager::on_update_active_stories(DialogId owner_dialog_id, StoryId max_read_story_id,
                                            vector<StoryId> &&story_ids, Promise<Unit> &&promise, const char *source,
                                            bool from_database) {
  CHECK(owner_dialog_id.is_valid());
  if (td::remove_if(story_ids, [&](StoryId story_id) {
        if (!story_id.is_server()) {
          CHECK(!from_database);
          return true;
        }
        if (!is_active_story(get_story({owner_dialog_id, story_id}))) {
          LOG(INFO) << "Receive expired " << story_id << " in " << owner_dialog_id << " from " << source;
          return true;
        }
        return false;
      })) {
    from_database = false;
  }
  if (story_ids.empty() || max_read_story_id.get() < story_ids[0].get()) {
    max_read_story_id = StoryId();
  } else if (max_read_story_id != StoryId()) {
    CHECK(max_read_story_id.is_server());
  }

  LOG(INFO) << "Update active stories in " << owner_dialog_id << " to " << story_ids << " with max read "
            << max_read_story_id << " from " << source;

  if (story_ids.empty()) {
    on_update_dialog_max_story_ids(owner_dialog_id, StoryId(), StoryId());
    auto *active_stories = get_active_stories(owner_dialog_id);
    if (active_stories != nullptr) {
      LOG(INFO) << "Delete active stories for " << owner_dialog_id;
      if (active_stories->story_list_id_.is_valid()) {
        delete_active_stories_from_story_list(owner_dialog_id, active_stories);
        auto &story_list = get_story_list(active_stories->story_list_id_);
        if (!from_database && story_list.is_reloaded_server_total_count_ &&
            story_list.server_total_count_ > static_cast<int32>(story_list.ordered_stories_.size())) {
          story_list.server_total_count_--;
          save_story_list(active_stories->story_list_id_, story_list.state_, story_list.server_total_count_,
                          story_list.server_has_more_);
        }
        update_story_list_sent_total_count(active_stories->story_list_id_, story_list, "on_update_active_stories");
      }
      active_stories_.erase(owner_dialog_id);
      send_update_chat_active_stories(owner_dialog_id, nullptr, "on_update_active_stories 1");
    } else {
      max_read_story_ids_.erase(owner_dialog_id);
    }
    if (!from_database) {
      save_active_stories(owner_dialog_id, nullptr, std::move(promise), source);
    }
    failed_to_load_active_stories_.insert(owner_dialog_id);
    return;
  }
  failed_to_load_active_stories_.erase(owner_dialog_id);

  auto &active_stories = active_stories_[owner_dialog_id];
  if (active_stories == nullptr) {
    LOG(INFO) << "Create active stories for " << owner_dialog_id << " from " << source;
    active_stories = make_unique<ActiveStories>();
    auto old_max_read_story_id = max_read_story_ids_.get(owner_dialog_id);
    if (old_max_read_story_id != StoryId()) {
      max_read_story_ids_.erase(owner_dialog_id);
      if (old_max_read_story_id.get() > max_read_story_id.get() && old_max_read_story_id.get() >= story_ids[0].get()) {
        max_read_story_id = old_max_read_story_id;
      }
    }
  }
  on_update_dialog_max_story_ids(owner_dialog_id, story_ids.back(), max_read_story_id);
  bool need_save_to_database = false;
  if (active_stories->max_read_story_id_ != max_read_story_id || active_stories->story_ids_ != story_ids) {
    need_save_to_database = true;
    active_stories->max_read_story_id_ = max_read_story_id;
    active_stories->story_ids_ = std::move(story_ids);
    update_active_stories_order(owner_dialog_id, active_stories.get(), &need_save_to_database);
    send_update_chat_active_stories(owner_dialog_id, active_stories.get(), "on_update_active_stories 2");
  } else if (update_active_stories_order(owner_dialog_id, active_stories.get(), &need_save_to_database)) {
    send_update_chat_active_stories(owner_dialog_id, active_stories.get(), "on_update_active_stories 3");
  }
  if (need_save_to_database && !from_database) {
    save_active_stories(owner_dialog_id, active_stories.get(), std::move(promise), source);
  } else {
    promise.set_value(Unit());
  }
}

bool StoryManager::update_active_stories_order(DialogId owner_dialog_id, ActiveStories *active_stories,
                                               bool *need_save_to_database) {
  if (td_->auth_manager_->is_bot()) {
    return false;
  }

  CHECK(active_stories != nullptr);
  CHECK(!active_stories->story_ids_.empty());
  CHECK(owner_dialog_id.is_valid());

  auto last_story_id = active_stories->story_ids_.back();
  const Story *last_story = get_story({owner_dialog_id, last_story_id});
  CHECK(last_story != nullptr);

  int64 new_private_order = 0;
  new_private_order += last_story->date_;
  if (owner_dialog_id.get_type() == DialogType::User &&
      td_->user_manager_->is_user_premium(owner_dialog_id.get_user_id())) {
    new_private_order += static_cast<int64>(1) << 33;
  }
  if (owner_dialog_id == get_changelog_story_dialog_id()) {
    new_private_order += static_cast<int64>(1) << 34;
  }
  if (active_stories->max_read_story_id_.get() < last_story_id.get()) {
    new_private_order += static_cast<int64>(1) << 35;
  }
  if (owner_dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
    new_private_order += static_cast<int64>(1) << 36;
  }
  CHECK(new_private_order != 0);

  StoryListId story_list_id = get_dialog_story_list_id(owner_dialog_id);
  LOG(INFO) << "Update order of active stories of " << owner_dialog_id << " in " << story_list_id << " from "
            << active_stories->private_order_ << '/' << active_stories->public_order_ << " to " << new_private_order;

  int64 new_public_order = 0;
  if (story_list_id.is_valid()) {
    auto &story_list = get_story_list(story_list_id);
    if (DialogDate(new_private_order, owner_dialog_id) <= story_list.list_last_story_date_) {
      new_public_order = new_private_order;
    }

    if (active_stories->private_order_ != new_private_order || active_stories->story_list_id_ != story_list_id) {
      delete_active_stories_from_story_list(owner_dialog_id, active_stories);
      bool is_inserted = story_list.ordered_stories_.insert({new_private_order, owner_dialog_id}).second;
      CHECK(is_inserted);

      if (active_stories->story_list_id_ != story_list_id && active_stories->story_list_id_.is_valid()) {
        update_story_list_sent_total_count(active_stories->story_list_id_, "update_active_stories_order 1");
      }
      update_story_list_sent_total_count(story_list_id, story_list, "update_active_stories_order 2");
    }
  } else if (active_stories->story_list_id_.is_valid()) {
    delete_active_stories_from_story_list(owner_dialog_id, active_stories);
    update_story_list_sent_total_count(active_stories->story_list_id_, "update_active_stories_order 3");
  }

  if (active_stories->private_order_ != new_private_order || active_stories->public_order_ != new_public_order ||
      active_stories->story_list_id_ != story_list_id) {
    LOG(INFO) << "Update order of active stories of " << owner_dialog_id << " to " << new_private_order << '/'
              << new_public_order << " in list " << story_list_id;
    if (active_stories->private_order_ != new_private_order || active_stories->story_list_id_ != story_list_id) {
      *need_save_to_database = true;
    }
    active_stories->private_order_ = new_private_order;
    if (active_stories->public_order_ != new_public_order || active_stories->story_list_id_ != story_list_id) {
      if (active_stories->story_list_id_ != story_list_id) {
        if (active_stories->story_list_id_.is_valid() && active_stories->public_order_ != 0) {
          active_stories->public_order_ = 0;
          send_update_chat_active_stories(owner_dialog_id, active_stories, "update_active_stories_order");
        }
        active_stories->story_list_id_ = story_list_id;
      }
      active_stories->public_order_ = new_public_order;
      return true;
    }
  }

  return false;
}

void StoryManager::delete_active_stories_from_story_list(DialogId owner_dialog_id,
                                                         const ActiveStories *active_stories) {
  if (!active_stories->story_list_id_.is_valid()) {
    return;
  }
  auto &story_list = get_story_list(active_stories->story_list_id_);
  bool is_deleted = story_list.ordered_stories_.erase({active_stories->private_order_, owner_dialog_id}) > 0;
  CHECK(is_deleted);
}

void StoryManager::send_update_story(StoryFullId story_full_id, const Story *story) {
  auto story_object = get_story_object(story_full_id, story);
  if (story_object == nullptr) {
    CHECK(story != nullptr);
    CHECK(story->content_ != nullptr);
    // the story can be just expired
    return;
  }
  send_closure(G()->td(), &Td::send_update, td_api::make_object<td_api::updateStory>(std::move(story_object)));
}

td_api::object_ptr<td_api::updateChatActiveStories> StoryManager::get_update_chat_active_stories_object(
    DialogId owner_dialog_id, const ActiveStories *active_stories) const {
  return td_api::make_object<td_api::updateChatActiveStories>(
      get_chat_active_stories_object(owner_dialog_id, active_stories));
}

void StoryManager::send_update_chat_active_stories(DialogId owner_dialog_id, const ActiveStories *active_stories,
                                                   const char *source) {
  if (updated_active_stories_.count(owner_dialog_id) == 0) {
    if (active_stories == nullptr || active_stories->public_order_ == 0) {
      LOG(INFO) << "Skip update about active stories in " << owner_dialog_id << " from " << source;
      return;
    }
    CHECK(owner_dialog_id.is_valid());
    updated_active_stories_.insert(owner_dialog_id);
  }
  LOG(INFO) << "Send update about active stories in " << owner_dialog_id << " from " << source;
  send_closure(G()->td(), &Td::send_update, get_update_chat_active_stories_object(owner_dialog_id, active_stories));
}

void StoryManager::save_active_stories(DialogId owner_dialog_id, const ActiveStories *active_stories,
                                       Promise<Unit> &&promise, const char *source) const {
  if (!G()->use_message_database()) {
    return promise.set_value(Unit());
  }
  if (active_stories == nullptr) {
    LOG(INFO) << "Delete active stories of " << owner_dialog_id << " from database from " << source;
    G()->td_db()->get_story_db_async()->delete_active_stories(owner_dialog_id, std::move(promise));
  } else {
    LOG(INFO) << "Add " << active_stories->story_ids_.size() << " active stories of " << owner_dialog_id
              << " to database from " << source;
    auto order = active_stories->story_list_id_.is_valid() ? active_stories->private_order_ : 0;
    SavedActiveStories saved_active_stories;
    saved_active_stories.max_read_story_id_ = active_stories->max_read_story_id_;
    for (auto story_id : active_stories->story_ids_) {
      auto story_info = get_story_info({owner_dialog_id, story_id});
      if (story_info.story_id_.is_valid()) {
        saved_active_stories.story_infos_.push_back(std::move(story_info));
      }
    }
    if (saved_active_stories.story_infos_.size() != active_stories->story_ids_.size()) {
      send_closure_later(G()->story_manager(), &StoryManager::update_active_stories, owner_dialog_id);
    }
    if (saved_active_stories.story_infos_.empty()) {
      LOG(INFO) << "Have no active stories to save";
      G()->td_db()->get_story_db_async()->delete_active_stories(owner_dialog_id, std::move(promise));
    } else {
      G()->td_db()->get_story_db_async()->add_active_stories(owner_dialog_id, active_stories->story_list_id_, order,
                                                             log_event_store(saved_active_stories), std::move(promise));
    }
  }
}

void StoryManager::on_update_story_id(int64 random_id, StoryId new_story_id, const char *source) {
  if (!new_story_id.is_server()) {
    LOG(ERROR) << "Receive " << new_story_id << " with random_id " << random_id << " from " << source;
    return;
  }

  auto it = being_sent_stories_.find(random_id);
  if (it == being_sent_stories_.end()) {
    // update about a new story sent from another device
    LOG(INFO) << "Receive not sent outgoing " << new_story_id << " with random_id = " << random_id;
    return;
  }
  auto old_story_full_id = it->second;
  being_sent_stories_.erase(it);
  auto is_deleted = being_sent_story_random_ids_.erase(old_story_full_id) > 0;
  CHECK(is_deleted);

  if (!have_story_force(old_story_full_id)) {
    LOG(INFO) << "Can't find sent story " << old_story_full_id;
    // delete_sent_story_on_server(old_story_full_id, new_story_id);
    return;
  }

  auto old_story_id = old_story_full_id.get_story_id();
  auto new_story_full_id = StoryFullId(old_story_full_id.get_dialog_id(), new_story_id);

  LOG(INFO) << "Save correspondence from " << new_story_full_id << " to " << old_story_id;
  CHECK(!old_story_id.is_server());
  update_story_ids_[new_story_full_id] = old_story_id;
}

bool StoryManager::on_update_read_stories(DialogId owner_dialog_id, StoryId max_read_story_id) {
  if (!td_->dialog_manager_->have_dialog_info_force(owner_dialog_id, "on_update_read_stories")) {
    LOG(INFO) << "Can't read stories in unknown " << owner_dialog_id;
    return false;
  }
  if (max_read_story_id != StoryId() && !max_read_story_id.is_server()) {
    LOG(ERROR) << "Receive max read " << max_read_story_id;
    return false;
  }
  auto active_stories = get_active_stories_force(owner_dialog_id, "on_update_read_stories");
  if (active_stories == nullptr) {
    LOG(INFO) << "Can't find active stories in " << owner_dialog_id;
    auto old_max_read_story_id = max_read_story_ids_.get(owner_dialog_id);
    if (max_read_story_id.get() > old_max_read_story_id.get()) {
      LOG(INFO) << "Set max read story identifier in " << owner_dialog_id << " to " << max_read_story_id;
      max_read_story_ids_.set(owner_dialog_id, max_read_story_id);
      on_update_dialog_max_read_story_id(owner_dialog_id, max_read_story_id);
      return true;
    }
  } else if (max_read_story_id.get() > active_stories->max_read_story_id_.get()) {
    LOG(INFO) << "Update max read story identifier in " << owner_dialog_id << " with stories "
              << active_stories->story_ids_ << " from " << active_stories->max_read_story_id_ << " to "
              << max_read_story_id;
    auto story_ids = active_stories->story_ids_;
    on_update_active_stories(owner_dialog_id, max_read_story_id, std::move(story_ids), Promise<Unit>(),
                             "on_update_read_stories");
    return true;
  } else {
    LOG(DEBUG) << "Don't need update max read story from " << active_stories->max_read_story_id_ << " to "
               << max_read_story_id;
  }
  return false;
}

td_api::object_ptr<td_api::updateStoryStealthMode> StoryManager::get_update_story_stealth_mode() const {
  return stealth_mode_.get_update_story_stealth_mode_object();
}

void StoryManager::send_update_story_stealth_mode() const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  send_closure(G()->td(), &Td::send_update, get_update_story_stealth_mode());
}

void StoryManager::on_update_story_stealth_mode(
    telegram_api::object_ptr<telegram_api::storiesStealthMode> &&stealth_mode) {
  set_story_stealth_mode(StoryStealthMode(std::move(stealth_mode)));
}

void StoryManager::on_update_story_chosen_reaction_type(DialogId owner_dialog_id, StoryId story_id,
                                                        ReactionType chosen_reaction_type) {
  if (!owner_dialog_id.is_valid() || !story_id.is_server()) {
    LOG(ERROR) << "Receive chosen reaction in " << story_id << " in " << owner_dialog_id;
    return;
  }
  if (!td_->dialog_manager_->have_dialog_info_force(owner_dialog_id, "on_update_story_chosen_reaction_type")) {
    return;
  }
  if (chosen_reaction_type.is_paid_reaction()) {
    LOG(ERROR) << "Receive paid reaction for " << story_id << " in " << owner_dialog_id;
    return;
  }
  StoryFullId story_full_id{owner_dialog_id, story_id};
  auto pending_reaction_it = being_set_story_reactions_.find(story_full_id);
  if (pending_reaction_it != being_set_story_reactions_.end()) {
    LOG(INFO) << "Postpone " << story_full_id << " chosen reaction update, because there is a pending reaction";
    pending_reaction_it->second |= 1;
    return;
  }
  Story *story = get_story_force(story_full_id, "on_update_story_chosen_reaction_type");
  on_story_chosen_reaction_changed(story_full_id, story, chosen_reaction_type);
}

string StoryManager::get_story_stealth_mode_key() {
  return "stealth_mode";
}

void StoryManager::schedule_stealth_mode_update() {
  if (stealth_mode_.is_empty()) {
    stealth_mode_update_timeout_.cancel_timeout();
    return;
  }

  auto timeout = max(static_cast<double>(stealth_mode_.get_update_date() - G()->unix_time()), 0.1);
  LOG(INFO) << "Schedule stealth mode update in " << timeout;
  stealth_mode_update_timeout_.set_callback(std::move(update_stealth_mode_static));
  stealth_mode_update_timeout_.set_callback_data(static_cast<void *>(this));
  stealth_mode_update_timeout_.set_timeout_in(timeout);
}

void StoryManager::set_story_stealth_mode(StoryStealthMode stealth_mode) {
  stealth_mode.update();
  if (stealth_mode == stealth_mode_) {
    return;
  }

  stealth_mode_ = stealth_mode;
  LOG(INFO) << stealth_mode_;
  schedule_stealth_mode_update();
  send_update_story_stealth_mode();

  if (stealth_mode_.is_empty()) {
    G()->td_db()->get_binlog_pmc()->erase(get_story_stealth_mode_key());
  } else {
    G()->td_db()->get_binlog_pmc()->set(get_story_stealth_mode_key(), log_event_store(stealth_mode_).as_slice().str());
  }
}

void StoryManager::update_stealth_mode_static(void *story_manager) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(story_manager != nullptr);
  static_cast<StoryManager *>(story_manager)->update_stealth_mode();
}

void StoryManager::update_stealth_mode() {
  if (stealth_mode_.update()) {
    LOG(INFO) << stealth_mode_;
    send_update_story_stealth_mode();
  }
  schedule_stealth_mode_update();
}

DialogId StoryManager::get_changelog_story_dialog_id() const {
  return DialogId(UserId(td_->option_manager_->get_option_integer(
      "stories_changelog_user_id", UserManager::get_service_notifications_user_id().get())));
}

bool StoryManager::is_subscribed_to_dialog_stories(DialogId owner_dialog_id) const {
  if (owner_dialog_id == get_changelog_story_dialog_id()) {
    return true;
  }
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      if (is_my_story(owner_dialog_id)) {
        return true;
      }
      return td_->user_manager_->is_user_contact(owner_dialog_id.get_user_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_status(owner_dialog_id.get_channel_id()).is_member();
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return false;
  }
}

StoryListId StoryManager::get_dialog_story_list_id(DialogId owner_dialog_id) const {
  if (!is_subscribed_to_dialog_stories(owner_dialog_id)) {
    return StoryListId();
  }
  switch (owner_dialog_id.get_type()) {
    case DialogType::User:
      if (!is_my_story(owner_dialog_id) && td_->user_manager_->get_user_stories_hidden(owner_dialog_id.get_user_id())) {
        return StoryListId::archive();
      }
      return StoryListId::main();
    case DialogType::Channel:
      if (td_->chat_manager_->get_channel_stories_hidden(owner_dialog_id.get_channel_id())) {
        return StoryListId::archive();
      }
      return StoryListId::main();
    case DialogType::Chat:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      return StoryListId::archive();
  }
}

void StoryManager::on_dialog_active_stories_order_updated(DialogId owner_dialog_id, const char *source) {
  // called from update_user/on_channel_status_changed, must not create the dialog and hence must not load active stories
  auto active_stories = get_active_stories_editable(owner_dialog_id);
  bool need_save_to_database = false;
  if (active_stories != nullptr &&
      update_active_stories_order(owner_dialog_id, active_stories, &need_save_to_database)) {
    send_update_chat_active_stories(owner_dialog_id, active_stories, source);
  }
  if (need_save_to_database) {
    save_active_stories(owner_dialog_id, active_stories, Promise<Unit>(), source);
  }
}

void StoryManager::on_get_story_views(DialogId owner_dialog_id, const vector<StoryId> &story_ids,
                                      telegram_api::object_ptr<telegram_api::stories_storyViews> &&story_views) {
  schedule_interaction_info_update();
  td_->user_manager_->on_get_users(std::move(story_views->users_), "on_get_story_views");
  if (story_ids.size() != story_views->views_.size()) {
    LOG(ERROR) << "Receive invalid views for " << story_ids << ": " << to_string(story_views);
    return;
  }
  for (size_t i = 0; i < story_ids.size(); i++) {
    auto story_id = story_ids[i];
    CHECK(story_id.is_server());

    StoryFullId story_full_id{owner_dialog_id, story_id};
    Story *story = get_story_editable(story_full_id);
    if (story == nullptr || story->content_ == nullptr) {
      continue;
    }

    StoryInteractionInfo interaction_info(td_, std::move(story_views->views_[i]));
    CHECK(!interaction_info.is_empty());
    if (story->interaction_info_ != interaction_info) {
      auto pending_reaction_it = being_set_story_reactions_.find(story_full_id);
      if (pending_reaction_it != being_set_story_reactions_.end()) {
        LOG(INFO) << "Postpone " << story_full_id << " interaction info update, because there is a pending reaction";
        pending_reaction_it->second |= 1;
      } else {
        story->interaction_info_ = std::move(interaction_info);
        on_story_changed(story_full_id, story, true, true);
      }
    }
  }
}

void StoryManager::on_view_dialog_active_stories(vector<DialogId> dialog_ids) {
  if (dialog_ids.empty() || td_->auth_manager_->is_bot()) {
    return;
  }
  LOG(DEBUG) << "View active stories of " << dialog_ids;

  const size_t MAX_SLICE_SIZE = 100;  // server side limit
  vector<DialogId> input_dialog_ids;
  vector<telegram_api::object_ptr<telegram_api::InputPeer>> input_peers;
  for (auto &dialog_id : dialog_ids) {
    if (td::contains(input_dialog_ids, dialog_id)) {
      continue;
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      continue;
    }

    bool need_poll = [&] {
      switch (dialog_id.get_type()) {
        case DialogType::User:
          return td_->user_manager_->can_poll_user_active_stories(dialog_id.get_user_id());
        case DialogType::Channel:
          return td_->chat_manager_->can_poll_channel_active_stories(dialog_id.get_channel_id());
        case DialogType::Chat:
        case DialogType::SecretChat:
        case DialogType::None:
        default:
          return false;
      }
    }();
    if (!need_poll) {
      continue;
    }
    if (!being_reloaded_active_stories_dialog_ids_.insert(dialog_id).second) {
      continue;
    }

    input_dialog_ids.push_back(dialog_id);
    input_peers.push_back(std::move(input_peer));
    if (input_peers.size() == MAX_SLICE_SIZE) {
      td_->create_handler<GetStoriesMaxIdsQuery>()->send(std::move(input_dialog_ids), std::move(input_peers));
      input_dialog_ids.clear();
      input_peers.clear();
    }
  }
  if (!input_peers.empty()) {
    td_->create_handler<GetStoriesMaxIdsQuery>()->send(std::move(input_dialog_ids), std::move(input_peers));
  }
}

void StoryManager::on_get_dialog_max_active_story_ids(const vector<DialogId> &dialog_ids,
                                                      const vector<int32> &max_story_ids) {
  for (auto &dialog_id : dialog_ids) {
    auto is_deleted = being_reloaded_active_stories_dialog_ids_.erase(dialog_id) > 0;
    CHECK(is_deleted);
  }
  if (dialog_ids.size() != max_story_ids.size()) {
    if (!max_story_ids.empty()) {
      LOG(ERROR) << "Receive " << max_story_ids.size() << " max active story identifiers for " << dialog_ids;
    }
    return;
  }
  for (size_t i = 0; i < dialog_ids.size(); i++) {
    auto max_story_id = StoryId(max_story_ids[i]);
    auto dialog_id = dialog_ids[i];
    if (max_story_id == StoryId() || max_story_id.is_server()) {
      if (dialog_id.get_type() == DialogType::User) {
        td_->user_manager_->on_update_user_story_ids(dialog_id.get_user_id(), max_story_id, StoryId());
      } else {
        td_->chat_manager_->on_update_channel_story_ids(dialog_id.get_channel_id(), max_story_id, StoryId());
      }
    } else {
      LOG(ERROR) << "Receive " << max_story_id << " as maximum active story for " << dialog_id;
    }
  }
}

FileSourceId StoryManager::get_story_file_source_id(StoryFullId story_full_id) {
  if (td_->auth_manager_->is_bot()) {
    return FileSourceId();
  }

  if (!story_full_id.is_server()) {
    return FileSourceId();
  }

  auto &file_source_id = story_full_id_to_file_source_id_[story_full_id];
  if (!file_source_id.is_valid()) {
    file_source_id = td_->file_reference_manager_->create_story_file_source(story_full_id);
  }
  return file_source_id;
}

void StoryManager::reload_story(StoryFullId story_full_id, Promise<Unit> &&promise, const char *source) {
  if (deleted_story_full_ids_.count(story_full_id) > 0) {
    return promise.set_value(Unit());
  }
  double last_reloaded_at = inaccessible_story_full_ids_.get(story_full_id);
  if (last_reloaded_at >= Time::now() - OPENED_STORY_POLL_PERIOD / 2 && last_reloaded_at > 0.0) {
    return promise.set_value(Unit());
  }

  LOG(INFO) << "Reload " << story_full_id << " from " << source;
  auto dialog_id = story_full_id.get_dialog_id();
  auto story_id = story_full_id.get_story_id();
  if (!story_id.is_server()) {
    return promise.set_error(Status::Error(400, "Invalid story identifier"));
  }

  auto &queries = reload_story_queries_[story_full_id];
  if (!queries.empty() && !promise) {
    return;
  }
  queries.push_back(std::move(promise));
  if (queries.size() != 1) {
    return;
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), story_full_id](Result<Unit> &&result) mutable {
        send_closure(actor_id, &StoryManager::on_reload_story, story_full_id, std::move(result));
      });
  td_->create_handler<GetStoriesByIDQuery>(std::move(query_promise))->send(dialog_id, {story_id});
}

void StoryManager::on_reload_story(StoryFullId story_full_id, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }
  auto it = reload_story_queries_.find(story_full_id);
  CHECK(it != reload_story_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  reload_story_queries_.erase(it);

  if (result.is_ok()) {
    set_promises(promises);
  } else {
    fail_promises(promises, result.move_as_error());
  }
}

void StoryManager::get_story(DialogId owner_dialog_id, StoryId story_id, bool only_local,
                             Promise<td_api::object_ptr<td_api::story>> &&promise) {
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(owner_dialog_id, false, AccessRights::Read, "get_story"));
  if (!story_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid story identifier specified"));
  }

  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story_force(story_full_id, "get_story");
  if (story != nullptr && story->content_ != nullptr) {
    if (!story->is_update_sent_) {
      send_update_story(story_full_id, story);
    }
    return promise.set_value(get_story_object(story_full_id, story));
  }
  if (only_local || !story_id.is_server()) {
    return promise.set_value(nullptr);
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), story_full_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        send_closure(actor_id, &StoryManager::do_get_story, story_full_id, std::move(result), std::move(promise));
      });
  reload_story(story_full_id, std::move(query_promise), "get_story");
}

void StoryManager::do_get_story(StoryFullId story_full_id, Result<Unit> &&result,
                                Promise<td_api::object_ptr<td_api::story>> &&promise) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  const Story *story = get_story(story_full_id);
  if (story != nullptr && story->content_ != nullptr && !story->is_update_sent_) {
    send_update_story(story_full_id, story);
  }
  promise.set_value(get_story_object(story_full_id, story));
}

Result<StoryId> StoryManager::get_next_yet_unsent_story_id(DialogId dialog_id) {
  auto &story_id = current_yet_unsent_story_ids_[dialog_id];
  if (story_id == 0) {
    story_id = StoryId::MAX_SERVER_STORY_ID;
  } else if (story_id == std::numeric_limits<int32>::max()) {
    return Status::Error(400, "Tried to send too many stories above daily limit");
  }
  return StoryId(++story_id);
}

void StoryManager::return_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise,
                                                  const vector<ChannelId> &channel_ids) {
  if (!promise) {
    return;
  }

  auto total_count = narrow_cast<int32>(channel_ids.size());
  promise.set_value(td_api::make_object<td_api::chats>(
      total_count, transform(channel_ids, [](ChannelId channel_id) { return DialogId(channel_id).get(); })));
}

void StoryManager::get_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  if (channels_to_send_stories_inited_) {
    return return_dialogs_to_send_stories(std::move(promise), channels_to_send_stories_);
  }

  if (get_dialogs_to_send_stories_queries_.empty() && G()->use_message_database()) {
    auto pmc_key = "channels_to_send_stories";
    auto str = G()->td_db()->get_binlog_pmc()->get(pmc_key);
    if (!str.empty()) {
      auto r_channel_ids = transform(full_split(Slice(str), ','), [](Slice str) -> Result<ChannelId> {
        TRY_RESULT(channel_id_int, to_integer_safe<int64>(str));
        ChannelId channel_id(channel_id_int);
        if (!channel_id.is_valid()) {
          return Status::Error("Have invalid channel ID");
        }
        return channel_id;
      });
      if (any_of(r_channel_ids, [](const auto &r_channel_id) { return r_channel_id.is_error(); })) {
        LOG(ERROR) << "Can't parse " << str;
        G()->td_db()->get_binlog_pmc()->erase(pmc_key);
      } else {
        Dependencies dependencies;
        vector<ChannelId> channel_ids;
        for (auto &r_channel_id : r_channel_ids) {
          auto channel_id = r_channel_id.move_as_ok();
          dependencies.add_dialog_and_dependencies(DialogId(channel_id));
          channel_ids.push_back(channel_id);
        }
        if (!dependencies.resolve_force(td_, "get_dialogs_to_send_stories")) {
          G()->td_db()->get_binlog_pmc()->erase(pmc_key);
        } else {
          for (auto channel_id : channel_ids) {
            if (td_->chat_manager_->get_channel_status(channel_id).can_post_stories()) {
              channels_to_send_stories_.push_back(channel_id);
            }
          }
          channels_to_send_stories_inited_ = true;

          return_dialogs_to_send_stories(std::move(promise), channels_to_send_stories_);
          promise = {};
        }
      }
    }
  }

  reload_dialogs_to_send_stories(std::move(promise));
}

void StoryManager::reload_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  get_dialogs_to_send_stories_queries_.push_back(std::move(promise));
  if (get_dialogs_to_send_stories_queries_.size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this)](Result<Unit> &&result) {
      send_closure(actor_id, &StoryManager::finish_get_dialogs_to_send_stories, std::move(result));
    });
    td_->create_handler<GetChatsToSendStoriesQuery>(std::move(query_promise))->send();
  }
}

void StoryManager::finish_get_dialogs_to_send_stories(Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);

  auto promises = std::move(get_dialogs_to_send_stories_queries_);
  reset_to_empty(get_dialogs_to_send_stories_queries_);
  if (result.is_error()) {
    return fail_promises(promises, result.move_as_error());
  }

  next_reload_channels_to_send_stories_time_ = Time::now() + 86400;

  CHECK(channels_to_send_stories_inited_);
  for (auto &promise : promises) {
    return_dialogs_to_send_stories(std::move(promise), channels_to_send_stories_);
  }
}

void StoryManager::update_dialogs_to_send_stories(ChannelId channel_id, bool can_send_stories) {
  if (channels_to_send_stories_inited_) {
    CHECK(!td_->auth_manager_->is_bot());
    bool was_changed = false;
    if (!can_send_stories) {
      was_changed = td::remove(channels_to_send_stories_, channel_id);
    } else {
      if (!td::contains(channels_to_send_stories_, channel_id)) {
        channels_to_send_stories_.push_back(channel_id);
        was_changed = true;

        next_reload_channels_to_send_stories_time_ = Time::now();
        set_timeout_in(1.0);
      }
    }
    if (was_changed) {
      save_channels_to_send_stories();
    }
  }
}

void StoryManager::on_get_dialogs_to_send_stories(vector<tl_object_ptr<telegram_api::Chat>> &&chats) {
  auto channel_ids = td_->chat_manager_->get_channel_ids(std::move(chats), "on_get_dialogs_to_send_stories");
  if (channels_to_send_stories_inited_ && channels_to_send_stories_ == channel_ids) {
    return;
  }
  channels_to_send_stories_.clear();
  for (auto channel_id : channel_ids) {
    td_->dialog_manager_->force_create_dialog(DialogId(channel_id), "on_get_dialogs_to_send_stories");
    if (td_->chat_manager_->get_channel_status(channel_id).can_post_stories()) {
      channels_to_send_stories_.push_back(channel_id);
    }
  }
  channels_to_send_stories_inited_ = true;

  save_channels_to_send_stories();
}

void StoryManager::save_channels_to_send_stories() {
  CHECK(channels_to_send_stories_inited_);
  if (G()->use_message_database()) {
    G()->td_db()->get_binlog_pmc()->set(
        "channels_to_send_stories",
        implode(transform(channels_to_send_stories_, [](auto channel_id) { return PSTRING() << channel_id.get(); }),
                ','));
  }
}

void StoryManager::can_send_story(DialogId dialog_id,
                                  Promise<td_api::object_ptr<td_api::CanSendStoryResult>> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "can_send_story")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!can_post_stories(dialog_id)) {
    return promise.set_error(Status::Error(400, "Not enough rights to post stories in the chat"));
  }
  td_->create_handler<CanSendStoryQuery>(std::move(promise))->send(dialog_id);
}

void StoryManager::send_story(DialogId dialog_id, td_api::object_ptr<td_api::InputStoryContent> &&input_story_content,
                              td_api::object_ptr<td_api::inputStoryAreas> &&input_areas,
                              td_api::object_ptr<td_api::formattedText> &&input_caption,
                              td_api::object_ptr<td_api::StoryPrivacySettings> &&settings, int32 active_period,
                              td_api::object_ptr<td_api::storyFullId> &&from_story_full_id, bool is_pinned,
                              bool protect_content, Promise<td_api::object_ptr<td_api::story>> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "send_story")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!can_post_stories(dialog_id)) {
    return promise.set_error(Status::Error(400, "Not enough rights to post stories in the chat"));
  }

  bool is_bot = td_->auth_manager_->is_bot();
  TRY_RESULT_PROMISE(promise, content, get_input_story_content(td_, std::move(input_story_content), dialog_id));
  TRY_RESULT_PROMISE(promise, caption,
                     get_formatted_text(td_, DialogId(), std::move(input_caption), is_bot, true, false, false));
  if (dialog_id != td_->dialog_manager_->get_my_dialog_id()) {
    settings = td_api::make_object<td_api::storyPrivacySettingsEveryone>();
  }
  TRY_RESULT_PROMISE(promise, privacy_rules,
                     UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(settings)));
  unique_ptr<StoryForwardInfo> forward_info;
  StoryFullId forward_from_story_full_id;
  if (from_story_full_id != nullptr) {
    forward_from_story_full_id =
        StoryFullId(DialogId(from_story_full_id->sender_chat_id_), StoryId(from_story_full_id->story_id_));
    const Story *story = get_story(forward_from_story_full_id);
    if (story == nullptr || story->content_ == nullptr) {
      return promise.set_error(Status::Error(400, "Story to repost not found"));
    }
    if (story->noforwards_) {
      return promise.set_error(Status::Error(400, "Story can't be reposted"));
    }
    if (story->forward_info_ != nullptr) {
      forward_info = make_unique<StoryForwardInfo>(*story->forward_info_);
    } else {
      forward_info = make_unique<StoryForwardInfo>(forward_from_story_full_id, true);
    }
    forward_info->hide_sender_if_needed(td_);
  }
  if (active_period != 86400 && !(G()->is_test_dc() && (active_period == 60 || active_period == 300))) {
    bool is_premium = td_->option_manager_->get_option_boolean("is_premium");
    if (!is_premium || !td::contains(vector<int32>{6 * 3600, 12 * 3600, 2 * 86400}, active_period)) {
      return promise.set_error(Status::Error(400, "Invalid story active period specified"));
    }
  }
  TRY_RESULT_PROMISE(promise, story_id, get_next_yet_unsent_story_id(dialog_id));
  vector<MediaArea> areas;
  if (input_areas != nullptr) {
    for (auto &input_area : input_areas->areas_) {
      MediaArea media_area(td_, std::move(input_area), Auto());
      if (media_area.is_valid()) {
        areas.push_back(std::move(media_area));
      }
    }
  }
  if (!td_->option_manager_->get_option_boolean("can_use_text_entities_in_story_caption")) {
    caption.entities.clear();
  }

  td_->dialog_manager_->force_create_dialog(dialog_id, "send_story");

  auto story = make_unique<Story>();
  if (dialog_id.get_type() == DialogType::Channel &&
      td_->chat_manager_->is_megagroup_channel(dialog_id.get_channel_id())) {
    story->sender_dialog_id_ = td_->messages_manager_->get_dialog_default_send_message_as_dialog_id(dialog_id);
    if (story->sender_dialog_id_ == DialogId() &&
        !td_->dialog_manager_->is_anonymous_administrator(dialog_id, nullptr)) {
      story->sender_dialog_id_ = td_->dialog_manager_->get_my_dialog_id();
    }
  }
  story->date_ = G()->unix_time();
  story->expire_date_ = story->date_ + active_period;
  story->is_pinned_ = is_pinned;
  story->is_outgoing_ = true;
  story->noforwards_ = protect_content;
  story->privacy_rules_ = std::move(privacy_rules);
  story->content_ = std::move(content);
  story->forward_info_ = std::move(forward_info);
  story->areas_ = std::move(areas);
  story->caption_ = std::move(caption);

  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || being_sent_stories_.count(random_id) > 0);

  auto story_ptr = story.get();

  auto pending_story = td::make_unique<PendingStory>(dialog_id, story_id, forward_from_story_full_id,
                                                     ++send_story_count_, random_id, std::move(story));
  pending_story->log_event_id_ = save_send_story_log_event(pending_story.get());

  do_send_story(std::move(pending_story), {});

  promise.set_value(get_story_object({dialog_id, story_id}, story_ptr));
}

class StoryManager::SendStoryLogEvent {
 public:
  const PendingStory *pending_story_in_;
  unique_ptr<PendingStory> pending_story_out_;

  SendStoryLogEvent() : pending_story_in_(nullptr) {
  }

  explicit SendStoryLogEvent(const PendingStory *pending_story) : pending_story_in_(pending_story) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(*pending_story_in_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(pending_story_out_, parser);
  }
};

int64 StoryManager::save_send_story_log_event(const PendingStory *pending_story) {
  if (!G()->use_message_database()) {
    return 0;
  }

  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SendStory,
                    get_log_event_storer(SendStoryLogEvent(pending_story)));
}

void StoryManager::do_send_story(unique_ptr<PendingStory> &&pending_story, vector<int> bad_parts) {
  CHECK(pending_story != nullptr);
  CHECK(pending_story->story_id_.is_valid());
  CHECK(pending_story->story_ != nullptr);
  CHECK(pending_story->story_->content_ != nullptr);
  CHECK(pending_story->story_id_.is_valid());
  CHECK(pending_story->file_upload_id_.is_valid());

  auto story_full_id = StoryFullId(pending_story->dialog_id_, pending_story->story_id_);
  if (bad_parts.empty() && !pending_story->story_id_.is_server()) {
    auto story = make_unique<Story>();
    story->sender_dialog_id_ = pending_story->story_->sender_dialog_id_;
    story->date_ = pending_story->story_->date_;
    story->expire_date_ = pending_story->story_->expire_date_;
    story->is_pinned_ = pending_story->story_->is_pinned_;
    story->is_outgoing_ = true;
    story->noforwards_ = pending_story->story_->noforwards_;
    story->privacy_rules_ = pending_story->story_->privacy_rules_;
    story->content_ = copy_story_content(pending_story->story_->content_.get());
    story->areas_ = pending_story->story_->areas_;
    story->caption_ = pending_story->story_->caption_;
    send_update_story(story_full_id, story.get());
    stories_.set(story_full_id, std::move(story));

    auto active_stories = get_active_stories_force(pending_story->dialog_id_, "do_send_story");

    CHECK(pending_story->dialog_id_.is_valid());
    CHECK(pending_story->random_id_ != 0);
    yet_unsent_stories_[pending_story->dialog_id_].insert(pending_story->send_story_num_);
    yet_unsent_story_ids_[pending_story->dialog_id_].push_back(pending_story->story_id_);
    being_sent_stories_[pending_story->random_id_] = story_full_id;
    being_sent_story_random_ids_[story_full_id] = pending_story->random_id_;

    updated_active_stories_.insert(pending_story->dialog_id_);
    send_update_chat_active_stories(pending_story->dialog_id_, active_stories, "do_send_story");
    update_story_list_sent_total_count(StoryListId::main(), "do_send_story");
  }

  auto file_upload_id = pending_story->file_upload_id_;
  auto upload_order = pending_story->send_story_num_;

  LOG(INFO) << "Ask to upload story " << file_upload_id << " with bad parts " << bad_parts;
  if (!pending_story->story_id_.is_server()) {
    being_uploaded_file_upload_ids_[story_full_id] = file_upload_id;
  }
  CHECK(file_upload_id.is_valid());
  bool is_inserted = being_uploaded_files_.emplace(file_upload_id, std::move(pending_story)).second;
  CHECK(is_inserted);
  // need to call resume_upload synchronously to make upload process consistent with being_uploaded_files_
  // and to send is_uploading_active == true in response
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_media_callback_, 1, upload_order);
}

void StoryManager::on_upload_story(FileUploadId file_upload_id,
                                   telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Story " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto pending_story = std::move(it->second);
  being_uploaded_files_.erase(it);
  CHECK(file_upload_id == pending_story->file_upload_id_);

  if (!pending_story->story_id_.is_server()) {
    being_uploaded_file_upload_ids_.erase({pending_story->dialog_id_, pending_story->story_id_});

    auto deleted_story_it = delete_yet_unsent_story_queries_.find(pending_story->random_id_);
    if (deleted_story_it != delete_yet_unsent_story_queries_.end()) {
      auto promises = std::move(deleted_story_it->second);
      delete_yet_unsent_story_queries_.erase(deleted_story_it);
      fail_promises(promises, Status::Error(400, "Story upload has been already completed"));
    }
  }

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      delete_pending_story(std::move(pending_story), Status::Error(400, "Can't use web photo as a story"));
      return;
    }
    if (pending_story->was_reuploaded_) {
      delete_pending_story(std::move(pending_story), Status::Error(500, "Failed to reupload story"));
      return;
    }
    pending_story->was_reuploaded_ = true;

    // delete file reference and forcely reupload the file
    td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), main_remote_location->get_file_reference());
    do_send_story(std::move(pending_story), {-1});
    return;
  }
  CHECK(input_file != nullptr);

  bool is_edit = pending_story->story_id_.is_server();
  if (is_edit) {
    do_edit_story(std::move(pending_story), std::move(input_file));
  } else {
    auto dialog_id = pending_story->dialog_id_;
    auto send_story_num = pending_story->send_story_num_;
    LOG(INFO) << "Story " << send_story_num << " is ready to be sent";
    ready_to_send_stories_.emplace(send_story_num,
                                   td::make_unique<ReadyToSendStory>(std::move(pending_story), std::move(input_file)));
    try_send_story(dialog_id);
  }
}

void StoryManager::on_upload_story_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(INFO) << "Story " << file_upload_id << " has upload error " << status;

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto pending_story = std::move(it->second);
  being_uploaded_files_.erase(it);

  vector<Promise<Unit>> promises;
  if (!pending_story->story_id_.is_server()) {
    being_uploaded_file_upload_ids_.erase({pending_story->dialog_id_, pending_story->story_id_});

    auto deleted_story_it = delete_yet_unsent_story_queries_.find(pending_story->random_id_);
    if (deleted_story_it != delete_yet_unsent_story_queries_.end()) {
      promises = std::move(deleted_story_it->second);
      delete_yet_unsent_story_queries_.erase(deleted_story_it);
      status = Status::Error(406, "Canceled");
    }
  }

  delete_pending_story(std::move(pending_story), std::move(status));
  set_promises(promises);
}

void StoryManager::try_send_story(DialogId dialog_id) {
  const auto yet_unsent_story_it = yet_unsent_stories_.find(dialog_id);
  if (yet_unsent_story_it == yet_unsent_stories_.end()) {
    LOG(INFO) << "There is no more stories to send in " << dialog_id;
    return;
  }
  CHECK(!yet_unsent_story_it->second.empty());
  auto send_story_num = *yet_unsent_story_it->second.begin();
  auto it = ready_to_send_stories_.find(send_story_num);
  if (it == ready_to_send_stories_.end()) {
    LOG(INFO) << "Story " << send_story_num << " isn't ready to be sent or is being sent";
    return;
  }
  auto ready_to_send_story = std::move(it->second);
  ready_to_send_stories_.erase(it);

  td_->create_handler<SendStoryQuery>()->send(std::move(ready_to_send_story->pending_story_),
                                              std::move(ready_to_send_story->input_file_));
}

void StoryManager::on_send_story_file_parts_missing(unique_ptr<PendingStory> &&pending_story, vector<int> &&bad_parts) {
  do_send_story(std::move(pending_story), std::move(bad_parts));
}

class StoryManager::EditStoryLogEvent {
 public:
  const PendingStory *pending_story_in_;
  unique_ptr<PendingStory> pending_story_out_;
  bool edit_media_areas_;
  vector<MediaArea> areas_;
  bool edit_caption_;
  FormattedText caption_;

  EditStoryLogEvent() : pending_story_in_(nullptr), edit_caption_(false) {
  }

  EditStoryLogEvent(const PendingStory *pending_story, bool edit_media_areas, vector<MediaArea> areas,
                    bool edit_caption, const FormattedText &caption)
      : pending_story_in_(pending_story)
      , edit_media_areas_(edit_media_areas)
      , areas_(std::move(areas))
      , edit_caption_(edit_caption)
      , caption_(caption) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_caption = edit_caption_ && !caption_.text.empty();
    bool has_media_areas = edit_media_areas_ && !areas_.empty();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(edit_caption_);
    STORE_FLAG(has_caption);
    STORE_FLAG(edit_media_areas_);
    STORE_FLAG(has_media_areas);
    END_STORE_FLAGS();
    td::store(*pending_story_in_, storer);
    if (has_caption) {
      td::store(caption_, storer);
    }
    if (has_media_areas) {
      td::store(areas_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_caption;
    bool has_media_areas;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(edit_caption_);
    PARSE_FLAG(has_caption);
    PARSE_FLAG(edit_media_areas_);
    PARSE_FLAG(has_media_areas);
    END_PARSE_FLAGS();
    td::parse(pending_story_out_, parser);
    if (has_caption) {
      td::parse(caption_, parser);
    }
    if (has_media_areas) {
      td::parse(areas_, parser);
    }
  }
};

void StoryManager::edit_story(DialogId owner_dialog_id, StoryId story_id,
                              td_api::object_ptr<td_api::InputStoryContent> &&input_story_content,
                              td_api::object_ptr<td_api::inputStoryAreas> &&input_areas,
                              td_api::object_ptr<td_api::formattedText> &&input_caption, Promise<Unit> &&promise) {
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr || story->content_ == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!can_edit_story(story_full_id, story)) {
    return promise.set_error(Status::Error(400, "Story can't be edited"));
  }

  bool is_bot = td_->auth_manager_->is_bot();
  unique_ptr<StoryContent> content;
  bool are_media_areas_edited = input_areas != nullptr;
  vector<MediaArea> areas;
  bool is_caption_edited = input_caption != nullptr;
  FormattedText caption;
  if (input_story_content != nullptr) {
    TRY_RESULT_PROMISE_ASSIGN(promise, content,
                              get_input_story_content(td_, std::move(input_story_content), owner_dialog_id));
  }
  if (are_media_areas_edited) {
    for (auto &input_area : input_areas->areas_) {
      MediaArea media_area(td_, std::move(input_area), story->areas_);
      if (media_area.is_valid()) {
        areas.push_back(std::move(media_area));
      }
    }
    auto *current_areas = &story->areas_;
    auto it = being_edited_stories_.find(story_full_id);
    if (it != being_edited_stories_.end() && it->second->edit_media_areas_) {
      current_areas = &it->second->areas_;
    }
    if (*current_areas == areas) {
      are_media_areas_edited = false;
    } else if (content == nullptr) {
      return promise.set_error(Status::Error(400, "Can't edit story areas without content"));
    }
  }
  if (is_caption_edited) {
    TRY_RESULT_PROMISE_ASSIGN(
        promise, caption, get_formatted_text(td_, DialogId(), std::move(input_caption), is_bot, true, false, false));
    if (!td_->option_manager_->get_option_boolean("can_use_text_entities_in_story_caption")) {
      caption.entities.clear();
    }
    auto *current_caption = &story->caption_;
    auto it = being_edited_stories_.find(story_full_id);
    if (it != being_edited_stories_.end() && it->second->edit_caption_) {
      current_caption = &it->second->caption_;
    }
    if (*current_caption == caption) {
      is_caption_edited = false;
    }
  }
  if (content == nullptr && !are_media_areas_edited && !is_caption_edited) {
    return promise.set_value(Unit());
  }

  auto &edited_story = being_edited_stories_[story_full_id];
  if (edited_story == nullptr) {
    edited_story = make_unique<BeingEditedStory>();
  }
  auto &edit_generation = edit_generations_[story_full_id];
  if (content != nullptr) {
    edited_story->content_ = std::move(content);
    edit_generation++;
  }
  if (are_media_areas_edited) {
    edited_story->areas_ = std::move(areas);
    edited_story->edit_media_areas_ = true;
    edit_generation++;
  }
  if (is_caption_edited) {
    edited_story->caption_ = std::move(caption);
    edited_story->edit_caption_ = true;
    edit_generation++;
  }
  edited_story->promises_.push_back(std::move(promise));

  auto new_story = make_unique<Story>();
  new_story->content_ = copy_story_content(edited_story->content_.get());

  auto pending_story = td::make_unique<PendingStory>(owner_dialog_id, story_id, StoryFullId(),
                                                     std::numeric_limits<uint32>::max() - (++send_story_count_),
                                                     edit_generation, std::move(new_story));
  if (G()->use_message_database()) {
    EditStoryLogEvent log_event(pending_story.get(), edited_story->edit_media_areas_, edited_story->areas_,
                                edited_story->edit_caption_, edited_story->caption_);
    auto storer = get_log_event_storer(log_event);
    auto &cur_log_event_id = edited_story->log_event_id_;
    if (cur_log_event_id == 0) {
      cur_log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::EditStory, storer);
      LOG(INFO) << "Add edit story log event " << cur_log_event_id;
    } else {
      auto new_log_event_id =
          binlog_rewrite(G()->td_db()->get_binlog(), cur_log_event_id, LogEvent::HandlerType::EditStory, storer);
      LOG(INFO) << "Rewrite edit story log event " << cur_log_event_id << " with " << new_log_event_id;
    }
  }

  on_story_changed(story_full_id, story, true, true);

  if (edited_story->content_ == nullptr) {
    return do_edit_story(std::move(pending_story), nullptr);
  }

  do_send_story(std::move(pending_story), {});
}

void StoryManager::do_edit_story(unique_ptr<PendingStory> &&pending_story,
                                 telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  StoryFullId story_full_id{pending_story->dialog_id_, pending_story->story_id_};
  const Story *story = get_story(story_full_id);
  auto it = being_edited_stories_.find(story_full_id);
  if (story == nullptr || it == being_edited_stories_.end() ||
      edit_generations_[story_full_id] != pending_story->random_id_) {
    LOG(INFO) << "Skip outdated edit of " << story_full_id;
    td_->file_manager_->cancel_upload(pending_story->file_upload_id_);
    return;
  }
  CHECK(story->content_ != nullptr);
  td_->create_handler<EditStoryQuery>()->send(story, std::move(pending_story), std::move(input_file), it->second.get());
}

void StoryManager::edit_story_cover(DialogId owner_dialog_id, StoryId story_id, double main_frame_timestamp,
                                    Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr || story->content_ == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!can_edit_story(story_full_id, story)) {
    return promise.set_error(Status::Error(400, "Story can't be edited"));
  }
  if (being_edited_stories_.count(story_full_id) > 0) {
    return promise.set_error(Status::Error(400, "Story is being edited"));
  }
  if (main_frame_timestamp < 0.0) {
    return promise.set_error(Status::Error(400, "Wrong cover timestamp specified"));
  }
  if (story->content_->get_type() != StoryContentType::Video) {
    return promise.set_error(Status::Error(400, "Cover timestamp can't be edited for the story"));
  }
  auto input_media = get_story_content_document_input_media(td_, story->content_.get(), main_frame_timestamp);
  if (input_media == nullptr) {
    return promise.set_error(Status::Error(400, "Can't edit story cover"));
  }

  td_->create_handler<EditStoryCoverQuery>(std::move(promise))
      ->send(owner_dialog_id, story_id, main_frame_timestamp, get_story_content_any_file_id(story->content_.get()),
             std::move(input_media));
}

void StoryManager::delete_pending_story(unique_ptr<PendingStory> &&pending_story, Status status) {
  if (G()->close_flag() && G()->use_message_database()) {
    return;
  }
  if (pending_story->file_upload_id_.is_valid()) {
    td_->file_manager_->delete_partial_remote_location(pending_story->file_upload_id_);
  }

  CHECK(pending_story != nullptr);
  StoryFullId story_full_id{pending_story->dialog_id_, pending_story->story_id_};
  const Story *story = get_story(story_full_id);
  bool is_edit = pending_story->story_id_.is_server();
  if (is_edit) {
    auto it = being_edited_stories_.find(story_full_id);
    if (story == nullptr || it == being_edited_stories_.end() ||
        edit_generations_[story_full_id] != pending_story->random_id_) {
      LOG(INFO) << "Ignore outdated edit of " << story_full_id;
      return;
    }
    CHECK(story->content_ != nullptr);
    auto promises = std::move(it->second->promises_);
    auto log_event_id = it->second->log_event_id_;
    if (log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), log_event_id);
    }
    being_edited_stories_.erase(it);

    on_story_changed(story_full_id, story, true, true);

    if (status.is_ok()) {
      set_promises(promises);
    } else {
      fail_promises(promises, std::move(status));
    }
    CHECK(pending_story->log_event_id_ == 0);
  } else {
    LOG(INFO) << "Finish sending of story " << pending_story->send_story_num_;
    if (story != nullptr) {
      if (status.is_ok()) {
        LOG(ERROR) << "Failed to receive sent " << story_full_id;
        status = Status::Error(500, "Failed to receive a sent story");
      }
      auto story_object = get_story_object(story_full_id, story);
      delete_story_files(story);
      stories_.erase(story_full_id);
      send_update_chat_active_stories(pending_story->dialog_id_, get_active_stories(pending_story->dialog_id_),
                                      "delete_pending_story");
      send_closure(
          G()->td(), &Td::send_update,
          td_api::make_object<td_api::updateStorySendFailed>(
              std::move(story_object), td_api::make_object<td_api::error>(status.code(), status.message().str()),
              get_can_send_story_result_object(status, true)));
    }
    auto it = yet_unsent_stories_.find(pending_story->dialog_id_);
    CHECK(it != yet_unsent_stories_.end());
    bool is_deleted = it->second.erase(pending_story->send_story_num_) > 0;
    CHECK(is_deleted);
    if (it->second.empty()) {
      yet_unsent_stories_.erase(it);
      yet_unsent_story_ids_.erase(pending_story->dialog_id_);
      update_story_list_sent_total_count(StoryListId::main(), "delete_pending_story");
    } else {
      auto story_id_it = yet_unsent_story_ids_.find(pending_story->dialog_id_);
      CHECK(story_id_it != yet_unsent_story_ids_.end());
      bool is_story_id_deleted = remove(story_id_it->second, pending_story->story_id_);
      CHECK(is_story_id_deleted);
      CHECK(!yet_unsent_story_ids_.empty());
    }
    being_sent_stories_.erase(pending_story->random_id_);
    being_sent_story_random_ids_.erase(story_full_id);
    try_send_story(pending_story->dialog_id_);

    if (pending_story->log_event_id_ != 0) {
      binlog_erase(G()->td_db()->get_binlog(), pending_story->log_event_id_);
    }
  }
}

void StoryManager::set_story_privacy_settings(StoryId story_id,
                                              td_api::object_ptr<td_api::StoryPrivacySettings> &&settings,
                                              Promise<Unit> &&promise) {
  DialogId owner_dialog_id(td_->dialog_manager_->get_my_dialog_id());
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr || story->content_ == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!can_edit_story(story_full_id, story)) {
    return promise.set_error(Status::Error(400, "Story privacy settings can't be edited"));
  }
  TRY_RESULT_PROMISE(promise, privacy_rules,
                     UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(settings)));
  td_->create_handler<EditStoryPrivacyQuery>(std::move(promise))
      ->send(owner_dialog_id, story_id, std::move(privacy_rules));
}

void StoryManager::toggle_story_is_pinned(DialogId owner_dialog_id, StoryId story_id, bool is_pinned,
                                          Promise<Unit> &&promise) {
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr || story->content_ == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!can_toggle_story_is_pinned(story_full_id, story)) {
    return promise.set_error(Status::Error(400, "Story can't be pinned/unpinned"));
  }
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), story_full_id, is_pinned,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      return promise.set_error(result.move_as_error());
    }
    send_closure(actor_id, &StoryManager::on_toggle_story_is_pinned, story_full_id, is_pinned, std::move(promise));
  });
  td_->create_handler<ToggleStoryPinnedQuery>(std::move(query_promise))->send(owner_dialog_id, story_id, is_pinned);
}

void StoryManager::on_toggle_story_is_pinned(StoryFullId story_full_id, bool is_pinned, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  Story *story = get_story_editable(story_full_id);
  if (story != nullptr) {
    CHECK(story->content_ != nullptr);
    story->is_pinned_ = is_pinned;
    on_story_changed(story_full_id, story, true, true);
  }
  promise.set_value(Unit());
}

void StoryManager::delete_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise) {
  StoryFullId story_full_id{owner_dialog_id, story_id};
  const Story *story = get_story(story_full_id);
  if (story == nullptr) {
    return promise.set_error(Status::Error(400, "Story not found"));
  }
  if (!can_delete_story(story_full_id, story)) {
    return promise.set_error(Status::Error(400, "Story can't be deleted"));
  }
  if (!story_id.is_server()) {
    auto file_upload_id_it = being_uploaded_file_upload_ids_.find(story_full_id);
    if (file_upload_id_it == being_uploaded_file_upload_ids_.end()) {
      return promise.set_error(Status::Error(400, "Story upload has been already completed"));
    }
    auto file_upload_id = file_upload_id_it->second;
    auto random_id_it = being_sent_story_random_ids_.find(story_full_id);
    if (random_id_it == being_sent_story_random_ids_.end()) {
      return promise.set_error(Status::Error(400, "Story not found"));
    }
    int64 random_id = random_id_it->second;
    CHECK(random_id != 0);

    LOG(INFO) << "Cancel uploading of " << story_full_id;

    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);

    delete_yet_unsent_story_queries_[random_id].push_back(std::move(promise));
    return;
  }

  delete_story_on_server(story_full_id, 0, std::move(promise));
}

class StoryManager::DeleteStoryOnServerLogEvent {
 public:
  StoryFullId story_full_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(story_full_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(story_full_id_, parser);
  }
};

uint64 StoryManager::save_delete_story_on_server_log_event(StoryFullId story_full_id) {
  DeleteStoryOnServerLogEvent log_event{story_full_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteStoryOnServer,
                    get_log_event_storer(log_event));
}

void StoryManager::delete_story_on_server(StoryFullId story_full_id, uint64 log_event_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Delete " << story_full_id << " from server";
  CHECK(story_full_id.is_server());

  if (log_event_id == 0) {
    log_event_id = save_delete_story_on_server_log_event(story_full_id);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  deleted_story_full_ids_.insert(story_full_id);

  td_->create_handler<DeleteStoriesQuery>(std::move(promise))
      ->send(story_full_id.get_dialog_id(), {story_full_id.get_story_id()});

  on_delete_story(story_full_id);
}

telegram_api::object_ptr<telegram_api::InputMedia> StoryManager::get_input_media(StoryFullId story_full_id) const {
  auto dialog_id = story_full_id.get_dialog_id();
  auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
  if (input_peer == nullptr) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::inputMediaStory>(std::move(input_peer),
                                                                  story_full_id.get_story_id().get());
}

void StoryManager::remove_story_notifications_by_story_ids(DialogId dialog_id, const vector<StoryId> &story_ids) {
  VLOG(notifications) << "Trying to remove notification about " << story_ids << " in " << dialog_id;
  for (auto story_id : story_ids) {
    if (!story_id.is_server()) {
      LOG(ERROR) << "Tried to delete " << story_id << " in " << dialog_id;
      continue;
    }
    StoryFullId story_full_id{dialog_id, story_id};
    if (!have_story_force(story_full_id)) {
      LOG(INFO) << "Can't delete " << story_full_id << " because it is not found";
      // call synchronously to remove them before ProcessPush returns
      // td_->notification_manager_->remove_temporary_notification_by_story_id(
      //    story_notification_group_id, story_full_id, true, "remove_story_notifications_by_story_ids");
      continue;
    }
    on_delete_story(story_full_id);
  }
}

void StoryManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  active_stories_.foreach([&](const DialogId &dialog_id, const unique_ptr<ActiveStories> &active_stories) {
    if (updated_active_stories_.count(dialog_id) > 0) {
      updates.push_back(get_update_chat_active_stories_object(dialog_id, active_stories.get()));
    }
  });
  if (!td_->auth_manager_->is_bot()) {
    for (auto story_list_id : {StoryListId::main(), StoryListId::archive()}) {
      const auto &story_list = get_story_list(story_list_id);
      if (story_list.sent_total_count_ != -1) {
        updates.push_back(get_update_story_list_chat_count_object(story_list_id, story_list));
      }
    }

    updates.push_back(get_update_story_stealth_mode());
  }
}

void StoryManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  bool have_old_message_database = G()->use_message_database() && !G()->td_db()->was_dialog_db_created();
  for (auto &event : events) {
    CHECK(event.id_ != 0);
    switch (event.type_) {
      case LogEvent::HandlerType::DeleteStoryOnServer: {
        DeleteStoryOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto owner_dialog_id = log_event.story_full_id_.get_dialog_id();
        td_->dialog_manager_->have_dialog_force(owner_dialog_id, "DeleteStoryOnServerLogEvent");
        delete_story_on_server(log_event.story_full_id_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::ReadStoriesOnServer: {
        ReadStoriesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto owner_dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(owner_dialog_id, "ReadStoriesOnServerLogEvent")) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }
        auto max_read_story_id = log_event.max_story_id_;
        auto active_stories = get_active_stories_force(owner_dialog_id, "ReadStoriesOnServerLogEvent");
        if (active_stories == nullptr) {
          max_read_story_ids_[owner_dialog_id] = max_read_story_id;
          on_update_dialog_max_read_story_id(owner_dialog_id, max_read_story_id);
        } else {
          auto story_ids = active_stories->story_ids_;
          on_update_active_stories(owner_dialog_id, max_read_story_id, std::move(story_ids), Promise<Unit>(),
                                   "ReadStoriesOnServerLogEvent");
        }
        read_stories_on_server(owner_dialog_id, max_read_story_id, event.id_);
        break;
      }
      case LogEvent::HandlerType::LoadDialogExpiringStories: {
        LoadDialogExpiringStoriesLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto owner_dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(owner_dialog_id, "LoadDialogExpiringStoriesLogEvent")) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }
        load_dialog_expiring_stories(owner_dialog_id, event.id_, "LoadDialogExpiringStoriesLogEvent");
        break;
      }
      case LogEvent::HandlerType::SendStory: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        SendStoryLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto pending_story = std::move(log_event.pending_story_out_);
        pending_story->log_event_id_ = event.id_;

        CHECK(pending_story->story_->content_ != nullptr);
        if (pending_story->story_->content_->get_type() == StoryContentType::Unsupported) {
          LOG(ERROR) << "Sent story content is invalid: " << format::as_hex_dump<4>(event.get_data());
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        Dependencies dependencies;
        add_pending_story_dependencies(dependencies, pending_story.get());
        if (!dependencies.resolve_force(td_, "SendStoryLogEvent")) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ++send_story_count_;
        CHECK(!pending_story->story_id_.is_server());
        pending_story->story_id_ = get_next_yet_unsent_story_id(pending_story->dialog_id_).move_as_ok();
        pending_story->send_story_num_ = send_story_count_;
        do_send_story(std::move(pending_story), {});
        break;
      }
      case LogEvent::HandlerType::EditStory: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        EditStoryLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto pending_story = std::move(log_event.pending_story_out_);
        CHECK(pending_story->story_id_.is_server());
        StoryFullId story_full_id{pending_story->dialog_id_, pending_story->story_id_};
        const Story *story = get_story_force(story_full_id, "EditStoryLogEvent");
        if (story == nullptr || story->content_ == nullptr) {
          LOG(INFO) << "Failed to find " << story_full_id;
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        if (pending_story->story_->content_ != nullptr &&
            pending_story->story_->content_->get_type() == StoryContentType::Unsupported) {
          LOG(ERROR) << "Sent story content is invalid: " << format::as_hex_dump<4>(event.get_data());
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        Dependencies dependencies;
        add_pending_story_dependencies(dependencies, pending_story.get());
        if (!dependencies.resolve_force(td_, "EditStoryLogEvent")) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        auto &edited_story = being_edited_stories_[story_full_id];
        if (edited_story != nullptr) {
          LOG(INFO) << "Ignore outdated edit of " << story_full_id;
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }
        edited_story = make_unique<BeingEditedStory>();
        edited_story->content_ = copy_story_content(pending_story->story_->content_.get());
        if (log_event.edit_media_areas_) {
          edited_story->areas_ = std::move(log_event.areas_);
          edited_story->edit_media_areas_ = true;
        }
        if (log_event.edit_caption_) {
          edited_story->caption_ = std::move(log_event.caption_);
          edited_story->edit_caption_ = true;
        }
        edited_story->log_event_id_ = event.id_;

        ++send_story_count_;
        pending_story->send_story_num_ = std::numeric_limits<uint32>::max() - send_story_count_;
        pending_story->random_id_ = ++edit_generations_[story_full_id];

        if (edited_story->content_ == nullptr) {
          do_edit_story(std::move(pending_story), nullptr);
        } else {
          do_send_story(std::move(pending_story), {});
        }
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

}  // namespace td
