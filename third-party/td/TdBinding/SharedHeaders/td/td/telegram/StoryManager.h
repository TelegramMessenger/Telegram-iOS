//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogDate.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/MediaArea.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/QuickReplyMessageFullId.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/StoryDb.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/StoryInteractionInfo.h"
#include "td/telegram/StoryListId.h"
#include "td/telegram/StoryStealthMode.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserPrivacySettingRule.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"
#include "td/actor/Timeout.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/WaitFreeHashMap.h"
#include "td/utils/WaitFreeHashSet.h"

#include <memory>
#include <set>
#include <utility>

namespace td {

struct BinlogEvent;
class Dependencies;
class StoryContent;
class StoryForwardInfo;
struct StoryDbStory;
class Td;

class StoryManager final : public Actor {
  struct Story {
    DialogId sender_dialog_id_;
    int32 date_ = 0;
    int32 expire_date_ = 0;
    int32 receive_date_ = 0;
    bool is_edited_ = false;
    bool is_pinned_ = false;
    bool is_public_ = false;
    bool is_for_close_friends_ = false;
    bool is_for_contacts_ = false;
    bool is_for_selected_contacts_ = false;
    bool is_outgoing_ = false;
    bool noforwards_ = false;
    mutable bool is_update_sent_ = false;  // whether the story is known to the app
    unique_ptr<StoryForwardInfo> forward_info_;
    StoryInteractionInfo interaction_info_;
    ReactionType chosen_reaction_type_;
    UserPrivacySettingRules privacy_rules_;
    unique_ptr<StoryContent> content_;
    vector<MediaArea> areas_;
    FormattedText caption_;
    int64 global_id_ = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct StoryInfo {
    StoryId story_id_;
    int32 date_ = 0;
    int32 expire_date_ = 0;
    bool is_for_close_friends_ = false;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct BeingEditedStory {
    unique_ptr<StoryContent> content_;
    vector<MediaArea> areas_;
    FormattedText caption_;
    bool edit_media_areas_ = false;
    bool edit_caption_ = false;
    vector<Promise<Unit>> promises_;
    int64 log_event_id_ = 0;
  };

  struct PendingStory {
    DialogId dialog_id_;
    StoryId story_id_;
    StoryFullId forward_from_story_full_id_;
    FileUploadId file_upload_id_;
    uint64 log_event_id_ = 0;
    uint32 send_story_num_ = 0;
    int64 random_id_ = 0;
    bool was_reuploaded_ = false;
    unique_ptr<Story> story_;

    PendingStory() = default;

    PendingStory(DialogId dialog_id, StoryId story_id, StoryFullId forward_from_story_full_id, uint32 send_story_num,
                 int64 random_id, unique_ptr<Story> &&story);

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct ReadyToSendStory {
    unique_ptr<PendingStory> pending_story_;
    telegram_api::object_ptr<telegram_api::InputFile> input_file_;

    ReadyToSendStory(unique_ptr<PendingStory> &&pending_story,
                     telegram_api::object_ptr<telegram_api::InputFile> &&input_file);
  };

  struct PendingStoryViews {
    FlatHashSet<StoryId, StoryIdHash> story_ids_;
    bool has_query_ = false;
  };

  struct ActiveStories {
    StoryId max_read_story_id_;
    vector<StoryId> story_ids_;
    StoryListId story_list_id_;
    int64 private_order_ = 0;
    int64 public_order_ = 0;
  };

  struct SavedActiveStories {
    StoryId max_read_story_id_;
    vector<StoryInfo> story_infos_;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct StoryList {
    int32 server_total_count_ = -1;
    int32 sent_total_count_ = -1;
    string state_;

    bool is_reloaded_server_total_count_ = false;
    bool server_has_more_ = true;
    bool database_has_more_ = false;

    vector<Promise<Unit>> load_list_from_server_queries_;
    vector<Promise<Unit>> load_list_from_database_queries_;

    std::set<DialogDate> ordered_stories_;  // all known active stories from the story list

    DialogDate last_loaded_database_dialog_date_ = MIN_DIALOG_DATE;  // in memory
    DialogDate list_last_story_date_ = MIN_DIALOG_DATE;              // in memory
  };

  struct SavedStoryList {
    string state_;
    int32 total_count_ = -1;
    bool has_more_ = true;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

 public:
  StoryManager(Td *td, ActorShared<> parent);
  StoryManager(const StoryManager &) = delete;
  StoryManager &operator=(const StoryManager &) = delete;
  StoryManager(StoryManager &&) = delete;
  StoryManager &operator=(StoryManager &&) = delete;
  ~StoryManager() final;

  void get_story(DialogId owner_dialog_id, StoryId story_id, bool only_local,
                 Promise<td_api::object_ptr<td_api::story>> &&promise);

  void get_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void reload_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void on_get_dialogs_to_send_stories(vector<tl_object_ptr<telegram_api::Chat>> &&chats);

  void update_dialogs_to_send_stories(ChannelId channel_id, bool can_send_stories);

  void can_send_story(DialogId dialog_id, Promise<td_api::object_ptr<td_api::CanSendStoryResult>> &&promise);

  void send_story(DialogId dialog_id, td_api::object_ptr<td_api::InputStoryContent> &&input_story_content,
                  td_api::object_ptr<td_api::inputStoryAreas> &&input_areas,
                  td_api::object_ptr<td_api::formattedText> &&input_caption,
                  td_api::object_ptr<td_api::StoryPrivacySettings> &&settings, int32 active_period,
                  td_api::object_ptr<td_api::storyFullId> &&from_story_full_id, bool is_pinned, bool protect_content,
                  Promise<td_api::object_ptr<td_api::story>> &&promise);

  void on_send_story_file_parts_missing(unique_ptr<PendingStory> &&pending_story, vector<int> &&bad_parts);

  void edit_story(DialogId owner_dialog_id, StoryId story_id,
                  td_api::object_ptr<td_api::InputStoryContent> &&input_story_content,
                  td_api::object_ptr<td_api::inputStoryAreas> &&input_areas,
                  td_api::object_ptr<td_api::formattedText> &&input_caption, Promise<Unit> &&promise);

  void edit_story_cover(DialogId owner_dialog_id, StoryId story_id, double main_frame_timestamp,
                        Promise<Unit> &&promise);

  void set_story_privacy_settings(StoryId story_id, td_api::object_ptr<td_api::StoryPrivacySettings> &&settings,
                                  Promise<Unit> &&promise);

  void toggle_story_is_pinned(DialogId owner_dialog_id, StoryId story_id, bool is_pinned, Promise<Unit> &&promise);

  void delete_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise);

  void load_active_stories(StoryListId story_list_id, Promise<Unit> &&promise);

  void reload_active_stories();

  void reload_all_read_stories();

  void toggle_dialog_stories_hidden(DialogId dialog_id, StoryListId story_list_id, Promise<Unit> &&promise);

  void get_dialog_pinned_stories(DialogId owner_dialog_id, StoryId from_story_id, int32 limit,
                                 Promise<td_api::object_ptr<td_api::stories>> &&promise);

  void get_story_archive(DialogId owner_dialog_id, StoryId from_story_id, int32 limit,
                         Promise<td_api::object_ptr<td_api::stories>> &&promise);

  void get_dialog_expiring_stories(DialogId owner_dialog_id,
                                   Promise<td_api::object_ptr<td_api::chatActiveStories>> &&promise);

  void reload_dialog_expiring_stories(DialogId dialog_id);

  void search_hashtag_posts(DialogId dialog_id, string hashtag, string offset, int32 limit,
                            Promise<td_api::object_ptr<td_api::foundStories>> &&promise);

  void search_location_posts(td_api::object_ptr<td_api::locationAddress> &&address, string offset, int32 limit,
                             Promise<td_api::object_ptr<td_api::foundStories>> &&promise);

  void search_venue_posts(string venue_provider, string venue_id, string offset, int32 limit,
                          Promise<td_api::object_ptr<td_api::foundStories>> &&promise);

  void set_pinned_stories(DialogId owner_dialog_id, vector<StoryId> story_ids, Promise<Unit> &&promise);

  void open_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise);

  void close_story(DialogId owner_dialog_id, StoryId story_id, Promise<Unit> &&promise);

  void view_story_message(StoryFullId story_full_id);

  void on_story_replied(StoryFullId story_full_id, UserId replier_user_id);

  void set_story_reaction(StoryFullId story_full_id, ReactionType reaction_type, bool add_to_recent,
                          Promise<Unit> &&promise);

  void get_story_interactions(StoryId story_id, const string &query, bool only_contacts, bool prefer_forwards,
                              bool prefer_with_reaction, const string &offset, int32 limit,
                              Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise);

  void get_dialog_story_interactions(StoryFullId story_full_id, ReactionType reaction_type, bool prefer_forwards,
                                     const string &offset, int32 limit,
                                     Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise);

  void get_channel_differences_if_needed(
      telegram_api::object_ptr<telegram_api::stories_storyViewsList> &&story_views,
      Promise<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> promise);

  void get_channel_differences_if_needed(
      telegram_api::object_ptr<telegram_api::stories_storyReactionsList> &&story_reactions,
      Promise<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> promise);

  void report_story(StoryFullId story_full_id, const string &option_id, const string &text,
                    Promise<td_api::object_ptr<td_api::ReportStoryResult>> &&promise);

  void activate_stealth_mode(Promise<Unit> &&promise);

  void remove_story_notifications_by_story_ids(DialogId dialog_id, const vector<StoryId> &story_ids);

  StoryId on_get_story(DialogId owner_dialog_id, telegram_api::object_ptr<telegram_api::StoryItem> &&story_item_ptr);

  std::pair<int32, vector<StoryId>> on_get_stories(DialogId owner_dialog_id, vector<StoryId> &&expected_story_ids,
                                                   telegram_api::object_ptr<telegram_api::stories_stories> &&stories);

  DialogId on_get_dialog_stories(DialogId owner_dialog_id,
                                 telegram_api::object_ptr<telegram_api::peerStories> &&peer_stories,
                                 Promise<Unit> &&promise);

  void on_update_story_id(int64 random_id, StoryId new_story_id, const char *source);

  bool on_update_read_stories(DialogId owner_dialog_id, StoryId max_read_story_id);

  void on_update_story_stealth_mode(telegram_api::object_ptr<telegram_api::storiesStealthMode> &&stealth_mode);

  void on_update_story_chosen_reaction_type(DialogId owner_dialog_id, StoryId story_id,
                                            ReactionType chosen_reaction_type);

  void on_update_dialog_stories_hidden(DialogId owner_dialog_id, bool stories_hidden);

  void on_dialog_active_stories_order_updated(DialogId owner_dialog_id, const char *source);

  Status can_get_story_viewers(StoryFullId story_full_id, const Story *story, int32 unix_time) const;

  bool has_unexpired_viewers(StoryFullId story_full_id, const Story *story) const;

  void on_get_story_views(DialogId owner_dialog_id, const vector<StoryId> &story_ids,
                          telegram_api::object_ptr<telegram_api::stories_storyViews> &&story_views);

  void on_view_dialog_active_stories(vector<DialogId> dialog_ids);

  void on_get_dialog_max_active_story_ids(const vector<DialogId> &dialog_ids, const vector<int32> &max_story_ids);

  bool have_story(StoryFullId story_full_id) const;

  bool have_story_force(StoryFullId story_full_id);

  int32 get_story_date(StoryFullId story_full_id);

  bool can_get_story_statistics(StoryFullId story_full_id);

  bool is_inaccessible_story(StoryFullId story_full_id) const;

  int32 get_story_duration(StoryFullId story_full_id) const;

  void register_story(StoryFullId story_full_id, MessageFullId message_full_id,
                      QuickReplyMessageFullId quick_reply_message_full_id, const char *source);

  void unregister_story(StoryFullId story_full_id, MessageFullId message_full_id,
                        QuickReplyMessageFullId quick_reply_message_full_id, const char *source);

  td_api::object_ptr<td_api::story> get_story_object(StoryFullId story_full_id) const;

  td_api::object_ptr<td_api::stories> get_stories_object(int32 total_count, const vector<StoryFullId> &story_full_ids,
                                                         const vector<StoryId> &pinned_story_ids) const;

  static td_api::object_ptr<td_api::CanSendStoryResult> get_can_send_story_result_object(const Status &error,
                                                                                         bool force = false);

  FileSourceId get_story_file_source_id(StoryFullId story_full_id);

  telegram_api::object_ptr<telegram_api::InputMedia> get_input_media(StoryFullId story_full_id) const;

  void reload_story(StoryFullId story_full_id, Promise<Unit> &&promise, const char *source);

  void try_synchronize_archive_all_stories();

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

  void on_binlog_events(vector<BinlogEvent> &&events);

 private:
  class UploadMediaCallback;

  class SendStoryQuery;
  class EditStoryQuery;

  class DeleteStoryOnServerLogEvent;
  class ReadStoriesOnServerLogEvent;
  class LoadDialogExpiringStoriesLogEvent;
  class SendStoryLogEvent;
  class EditStoryLogEvent;

  static constexpr int32 MAX_SEARCH_STORIES = 100;  // server-side limit

  static constexpr int32 OPENED_STORY_POLL_PERIOD = 60;
  static constexpr int32 VIEWED_STORY_POLL_PERIOD = 300;

  static constexpr int32 DEFAULT_LOADED_EXPIRED_STORIES = 50;

  void start_up() final;

  void timeout_expired() final;

  void hangup() final;

  void tear_down() final;

  static void on_story_reload_timeout_callback(void *story_manager_ptr, int64 story_global_id);

  void on_story_reload_timeout(int64 story_global_id);

  static void on_story_expire_timeout_callback(void *story_manager_ptr, int64 story_global_id);

  void on_story_expire_timeout(int64 story_global_id);

  static void on_story_can_get_viewers_timeout_callback(void *story_manager_ptr, int64 story_global_id);

  void on_story_can_get_viewers_timeout(int64 story_global_id);

  bool is_my_story(DialogId owner_dialog_id) const;

  bool can_access_expired_story(DialogId owner_dialog_id, const Story *story) const;

  bool can_get_story_statistics(StoryFullId story_full_id, const Story *story) const;

  bool can_get_story_view_count(DialogId owner_dialog_id);

  bool can_post_stories(DialogId owner_dialog_id) const;

  bool can_edit_stories(DialogId owner_dialog_id) const;

  bool can_delete_stories(DialogId owner_dialog_id) const;

  bool can_edit_story(StoryFullId story_full_id, const Story *story) const;

  bool can_toggle_story_is_pinned(StoryFullId story_full_id, const Story *story) const;

  bool can_delete_story(StoryFullId story_full_id, const Story *story) const;

  int32 get_story_viewers_expire_date(const Story *story) const;

  static bool is_active_story(const Story *story);

  DialogId get_changelog_story_dialog_id() const;

  bool is_subscribed_to_dialog_stories(DialogId owner_dialog_id) const;

  StoryListId get_dialog_story_list_id(DialogId owner_dialog_id) const;

  void add_story_dependencies(Dependencies &dependencies, const Story *story);

  void add_pending_story_dependencies(Dependencies &dependencies, const PendingStory *pending_story);

  const Story *get_story(StoryFullId story_full_id) const;

  Story *get_story_editable(StoryFullId story_full_id);

  Story *get_story_force(StoryFullId story_full_id, const char *source);

  unique_ptr<Story> parse_story(StoryFullId story_full_id, const BufferSlice &value);

  Story *on_get_story_from_database(StoryFullId story_full_id, const BufferSlice &value, const char *source);

  const ActiveStories *get_active_stories(DialogId owner_dialog_id) const;

  ActiveStories *get_active_stories_editable(DialogId owner_dialog_id);

  ActiveStories *get_active_stories_force(DialogId owner_dialog_id, const char *source);

  ActiveStories *on_get_active_stories_from_database(StoryListId story_list_id, DialogId owner_dialog_id,
                                                     const BufferSlice &value, const char *source);

  void set_story_expire_timeout(const Story *story);

  void set_story_can_get_viewers_timeout(const Story *story);

  void on_story_changed(StoryFullId story_full_id, const Story *story, bool is_changed, bool need_save_to_database,
                        bool from_database = false);

  void register_story_global_id(StoryFullId story_full_id, Story *story);

  void unregister_story_global_id(const Story *story);

  StoryId on_get_story_info(DialogId owner_dialog_id, StoryInfo &&story_info);

  StoryInfo get_story_info(StoryFullId story_full_id) const;

  td_api::object_ptr<td_api::storyInfo> get_story_info_object(StoryFullId story_full_id) const;

  td_api::object_ptr<td_api::story> get_story_object(StoryFullId story_full_id, const Story *story) const;

  td_api::object_ptr<td_api::chatActiveStories> get_chat_active_stories_object(
      DialogId owner_dialog_id, const ActiveStories *active_stories) const;

  StoryId on_get_new_story(DialogId owner_dialog_id, telegram_api::object_ptr<telegram_api::storyItem> &&story_item);

  StoryId on_get_skipped_story(DialogId owner_dialog_id,
                               telegram_api::object_ptr<telegram_api::storyItemSkipped> &&story_item);

  StoryId on_get_deleted_story(DialogId owner_dialog_id,
                               telegram_api::object_ptr<telegram_api::storyItemDeleted> &&story_item);

  void on_delete_story(StoryFullId story_full_id);

  void return_dialogs_to_send_stories(Promise<td_api::object_ptr<td_api::chats>> &&promise,
                                      const vector<ChannelId> &channel_ids);

  void finish_get_dialogs_to_send_stories(Result<Unit> &&result);

  void save_channels_to_send_stories();

  void on_get_dialog_pinned_stories(DialogId owner_dialog_id,
                                    telegram_api::object_ptr<telegram_api::stories_stories> &&stories,
                                    Promise<td_api::object_ptr<td_api::stories>> &&promise);

  void on_get_story_archive(DialogId owner_dialog_id, telegram_api::object_ptr<telegram_api::stories_stories> &&stories,
                            Promise<td_api::object_ptr<td_api::stories>> &&promise);

  void on_get_dialog_expiring_stories(DialogId owner_dialog_id,
                                      telegram_api::object_ptr<telegram_api::stories_peerStories> &&stories,
                                      Promise<td_api::object_ptr<td_api::chatActiveStories>> &&promise);

  static uint64 save_load_dialog_expiring_stories_log_event(DialogId owner_dialog_id);

  void load_dialog_expiring_stories(DialogId owner_dialog_id, uint64 log_event_id, const char *source);

  void on_load_dialog_expiring_stories(DialogId owner_dialog_id);

  void on_load_active_stories_from_database(StoryListId story_list_id, Result<StoryDbGetActiveStoryListResult> result);

  void load_active_stories_from_server(StoryListId story_list_id, StoryList &story_list, bool is_next,
                                       Promise<Unit> &&promise);

  void on_load_active_stories_from_server(
      StoryListId story_list_id, bool is_next, string old_state,
      Result<telegram_api::object_ptr<telegram_api::stories_AllStories>> r_all_stories);

  void save_story_list(StoryListId story_list_id, string state, int32 total_count, bool has_more);

  StoryList &get_story_list(StoryListId story_list_id);

  const StoryList &get_story_list(StoryListId story_list_id) const;

  td_api::object_ptr<td_api::updateStoryListChatCount> get_update_story_list_chat_count_object(
      StoryListId story_list_id, const StoryList &story_list) const;

  void update_story_list_sent_total_count(StoryListId story_list_id, const char *source);

  void update_story_list_sent_total_count(StoryListId story_list_id, StoryList &story_list, const char *source);

  vector<FileId> get_story_file_ids(const Story *story) const;

  static uint64 save_delete_story_on_server_log_event(StoryFullId story_full_id);

  void delete_story_on_server(StoryFullId story_full_id, uint64 log_event_id, Promise<Unit> &&promise);

  void delete_story_from_database(StoryFullId story_full_id);

  void delete_story_files(const Story *story) const;

  void change_story_files(StoryFullId story_full_id, const Story *story, const vector<FileId> &old_file_ids);

  void do_get_story(StoryFullId story_full_id, Result<Unit> &&result,
                    Promise<td_api::object_ptr<td_api::story>> &&promise);

  void on_reload_story(StoryFullId story_full_id, Result<Unit> &&result);

  int64 save_send_story_log_event(const PendingStory *pending_story);

  void delete_pending_story(unique_ptr<PendingStory> &&pending_story, Status status);

  Result<StoryId> get_next_yet_unsent_story_id(DialogId dialog_id);

  void do_send_story(unique_ptr<PendingStory> &&pending_story, vector<int> bad_parts);

  void on_upload_story(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_story_error(FileUploadId file_upload_id, Status status);

  void try_send_story(DialogId dialog_id);

  void do_edit_story(unique_ptr<PendingStory> &&pending_story,
                     telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_toggle_story_is_pinned(StoryFullId story_full_id, bool is_pinned, Promise<Unit> &&promise);

  void on_update_dialog_max_story_ids(DialogId owner_dialog_id, StoryId max_story_id, StoryId max_read_story_id);

  void on_update_dialog_max_read_story_id(DialogId owner_dialog_id, StoryId max_read_story_id);

  void on_update_dialog_has_pinned_stories(DialogId owner_dialog_id, bool has_pinned_stories);

  void update_active_stories(DialogId owner_dialog_id);

  void on_update_active_stories(DialogId owner_dialog_id, StoryId max_read_story_id, vector<StoryId> &&story_ids,
                                Promise<Unit> &&promise, const char *source, bool from_database = false);

  bool update_active_stories_order(DialogId owner_dialog_id, ActiveStories *active_stories,
                                   bool *need_save_to_database);

  void delete_active_stories_from_story_list(DialogId owner_dialog_id, const ActiveStories *active_stories);

  void send_update_story(StoryFullId story_full_id, const Story *story);

  td_api::object_ptr<td_api::updateChatActiveStories> get_update_chat_active_stories_object(
      DialogId owner_dialog_id, const ActiveStories *active_stories) const;

  void send_update_chat_active_stories(DialogId owner_dialog_id, const ActiveStories *active_stories,
                                       const char *source);

  void save_active_stories(DialogId owner_dialog_id, const ActiveStories *active_stories, Promise<Unit> &&promise,
                           const char *source) const;

  void increment_story_views(DialogId owner_dialog_id, PendingStoryViews &story_views);

  void on_increment_story_views(DialogId owner_dialog_id);

  static uint64 save_read_stories_on_server_log_event(DialogId dialog_id, StoryId max_story_id);

  void read_stories_on_server(DialogId owner_dialog_id, StoryId story_id, uint64 log_event_id);

  static bool has_suggested_reaction(const Story *story, const ReactionType &reaction_type);

  bool can_use_story_reaction(const Story *story, const ReactionType &reaction_type) const;

  void on_story_chosen_reaction_changed(StoryFullId story_full_id, Story *story, const ReactionType &reaction_type);

  void schedule_interaction_info_update();

  static void update_interaction_info_static(void *story_manager);

  void update_interaction_info();

  void on_synchronized_archive_all_stories(bool set_archive_all_stories, Result<Unit> result);

  td_api::object_ptr<td_api::updateStoryStealthMode> get_update_story_stealth_mode() const;

  void send_update_story_stealth_mode() const;

  void schedule_stealth_mode_update();

  static void update_stealth_mode_static(void *story_manager);

  void update_stealth_mode();

  static string get_story_stealth_mode_key();

  void set_story_stealth_mode(StoryStealthMode stealth_mode);

  void on_get_story_interactions(StoryId story_id, bool is_full, bool is_first,
                                 Result<telegram_api::object_ptr<telegram_api::stories_storyViewsList>> r_view_list,
                                 Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise);

  void on_get_dialog_story_interactions(
      StoryFullId story_full_id,
      Result<telegram_api::object_ptr<telegram_api::stories_storyReactionsList>> r_reaction_list,
      Promise<td_api::object_ptr<td_api::storyInteractions>> &&promise);

  void on_set_story_reaction(StoryFullId story_full_id, Result<Unit> &&result, Promise<Unit> &&promise);

  void load_expired_database_stories();

  void on_load_expired_database_stories(vector<StoryDbStory> stories);

  std::shared_ptr<UploadMediaCallback> upload_media_callback_;

  WaitFreeHashMap<StoryFullId, FileSourceId, StoryFullIdHash> story_full_id_to_file_source_id_;

  WaitFreeHashMap<StoryFullId, unique_ptr<Story>, StoryFullIdHash> stories_;

  WaitFreeHashMap<int64, StoryFullId> stories_by_global_id_;

  WaitFreeHashMap<StoryFullId, double, StoryFullIdHash> inaccessible_story_full_ids_;

  WaitFreeHashSet<StoryFullId, StoryFullIdHash> deleted_story_full_ids_;

  WaitFreeHashSet<StoryFullId, StoryFullIdHash> failed_to_load_story_full_ids_;

  WaitFreeHashMap<StoryFullId, WaitFreeHashSet<MessageFullId, MessageFullIdHash>, StoryFullIdHash> story_messages_;

  WaitFreeHashMap<StoryFullId, WaitFreeHashSet<QuickReplyMessageFullId, QuickReplyMessageFullIdHash>, StoryFullIdHash>
      story_quick_reply_messages_;

  WaitFreeHashMap<DialogId, unique_ptr<ActiveStories>, DialogIdHash> active_stories_;

  WaitFreeHashSet<DialogId, DialogIdHash> updated_active_stories_;

  WaitFreeHashMap<DialogId, StoryId, DialogIdHash> max_read_story_ids_;

  WaitFreeHashSet<DialogId, DialogIdHash> failed_to_load_active_stories_;

  FlatHashMap<DialogId, uint64, DialogIdHash> load_expiring_stories_log_event_ids_;

  FlatHashMap<StoryFullId, unique_ptr<BeingEditedStory>, StoryFullIdHash> being_edited_stories_;

  FlatHashMap<StoryFullId, int64, StoryFullIdHash> edit_generations_;

  FlatHashMap<DialogId, PendingStoryViews, DialogIdHash> pending_story_views_;

  FlatHashMap<StoryFullId, uint32, StoryFullIdHash> opened_stories_with_view_count_;

  FlatHashMap<StoryFullId, uint32, StoryFullIdHash> opened_stories_;

  FlatHashMap<StoryFullId, vector<Promise<Unit>>, StoryFullIdHash> reload_story_queries_;

  FlatHashMap<FileUploadId, unique_ptr<PendingStory>, FileUploadIdHash> being_uploaded_files_;

  FlatHashMap<DialogId, std::set<uint32>, DialogIdHash> yet_unsent_stories_;

  FlatHashMap<DialogId, vector<StoryId>, DialogIdHash> yet_unsent_story_ids_;

  FlatHashMap<int64, StoryFullId> being_sent_stories_;

  FlatHashMap<StoryFullId, int64, StoryFullIdHash> being_sent_story_random_ids_;

  FlatHashMap<StoryFullId, FileUploadId, StoryFullIdHash> being_uploaded_file_upload_ids_;

  FlatHashMap<StoryFullId, StoryId, StoryFullIdHash> update_story_ids_;

  FlatHashMap<int64, vector<Promise<Unit>>> delete_yet_unsent_story_queries_;

  FlatHashMap<uint32, unique_ptr<ReadyToSendStory>> ready_to_send_stories_;

  FlatHashSet<DialogId, DialogIdHash> being_reloaded_active_stories_dialog_ids_;

  bool channels_to_send_stories_inited_ = false;
  vector<ChannelId> channels_to_send_stories_;
  vector<Promise<td_api::object_ptr<td_api::chats>>> get_dialogs_to_send_stories_queries_;
  double next_reload_channels_to_send_stories_time_ = 0.0;

  FlatHashMap<StoryFullId, int32, StoryFullIdHash> being_set_story_reactions_;

  StoryList story_lists_[2];

  StoryStealthMode stealth_mode_;

  uint32 send_story_count_ = 0;

  int64 max_story_global_id_ = 0;

  FlatHashMap<DialogId, int32, DialogIdHash> current_yet_unsent_story_ids_;

  bool has_active_synchronize_archive_all_stories_query_ = false;

  Timeout stealth_mode_update_timeout_;

  Timeout interaction_info_update_timeout_;

  int32 load_expired_database_stories_next_limit_ = DEFAULT_LOADED_EXPIRED_STORIES;

  MultiTimeout story_reload_timeout_{"StoryReloadTimeout"};
  MultiTimeout story_expire_timeout_{"StoryExpireTimeout"};
  MultiTimeout story_can_get_viewers_timeout_{"StoryCanGetViewersTimeout"};

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
