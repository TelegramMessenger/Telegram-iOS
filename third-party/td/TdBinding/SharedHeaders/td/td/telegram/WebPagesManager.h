//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/QuickReplyMessageFullId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/WebPageId.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/WaitFreeHashMap.h"

#include <utility>

namespace td {

struct BinlogEvent;

class Td;

class WebPagesManager final : public Actor {
 public:
  WebPagesManager(Td *td, ActorShared<> parent);

  WebPagesManager(const WebPagesManager &) = delete;
  WebPagesManager &operator=(const WebPagesManager &) = delete;
  WebPagesManager(WebPagesManager &&) = delete;
  WebPagesManager &operator=(WebPagesManager &&) = delete;
  ~WebPagesManager() final;

  struct GetWebPagePreviewOptions {
    string first_url_;
    bool skip_confirmation_ = false;
    td_api::object_ptr<td_api::linkPreviewOptions> link_preview_options_;
  };

  static string get_web_page_url(const tl_object_ptr<telegram_api::WebPage> &web_page_ptr);

  WebPageId on_get_web_page(tl_object_ptr<telegram_api::WebPage> &&web_page_ptr, DialogId owner_dialog_id);

  void on_get_web_page_by_url(const string &url, WebPageId web_page_id, bool from_database);

  void on_get_web_page_instant_view_view_count(WebPageId web_page_id, int32 view_count);

  void register_web_page(WebPageId web_page_id, MessageFullId message_full_id, const char *source);

  void unregister_web_page(WebPageId web_page_id, MessageFullId message_full_id, const char *source);

  void register_quick_reply_web_page(WebPageId web_page_id, QuickReplyMessageFullId message_full_id,
                                     const char *source);

  void unregister_quick_reply_web_page(WebPageId web_page_id, QuickReplyMessageFullId message_full_id,
                                       const char *source);

  bool have_web_page(WebPageId web_page_id) const;

  bool have_web_page_force(WebPageId web_page_id);

  td_api::object_ptr<td_api::linkPreview> get_link_preview_object(WebPageId web_page_id, bool force_small_media,
                                                                  bool force_large_media, bool skip_confirmation,
                                                                  bool invert_media) const;

  td_api::object_ptr<td_api::webPageInstantView> get_web_page_instant_view_object(WebPageId web_page_id) const;

  void get_web_page_preview(td_api::object_ptr<td_api::formattedText> &&text,
                            td_api::object_ptr<td_api::linkPreviewOptions> &&link_preview_options,
                            Promise<td_api::object_ptr<td_api::linkPreview>> &&promise);

  void get_web_page_instant_view(const string &url, bool only_local, Promise<WebPageId> &&promise);

  string get_web_page_url(WebPageId web_page_id) const;

  WebPageId get_web_page_by_url(const string &url) const;

  void fetch_web_page_by_url(const string &url, Promise<WebPageId> &&promise);

  void reload_web_page_by_url(const string &url, bool only_local, Promise<WebPageId> &&promise);

  void on_get_web_page_preview(unique_ptr<GetWebPagePreviewOptions> &&options,
                               tl_object_ptr<telegram_api::MessageMedia> &&message_media_ptr,
                               Promise<td_api::object_ptr<td_api::linkPreview>> &&promise);

  void on_binlog_web_page_event(BinlogEvent &&event);

  FileSourceId get_url_file_source_id(const string &url);

  string get_web_page_search_text(WebPageId web_page_id) const;

  int32 get_web_page_media_duration(WebPageId web_page_id) const;

  StoryFullId get_web_page_story_full_id(WebPageId web_page_id) const;

  vector<UserId> get_web_page_user_ids(WebPageId web_page_id) const;

  vector<ChannelId> get_web_page_channel_ids(WebPageId web_page_id) const;

  void on_story_changed(StoryFullId story_full_id);

 private:
  class WebPage;

  class WebPageInstantView;

  class WebPageLogEvent;

  void update_web_page(unique_ptr<WebPage> web_page, WebPageId web_page_id, bool from_binlog, bool from_database);

  void update_web_page_instant_view(WebPageId web_page_id, WebPageInstantView &new_instant_view,
                                    WebPageInstantView &&old_instant_view);

  static bool need_use_old_instant_view(const WebPageInstantView &new_instant_view,
                                        const WebPageInstantView &old_instant_view);

  void on_web_page_changed(WebPageId web_page_id, bool have_web_page);

  const WebPage *get_web_page(WebPageId web_page_id) const;

  const WebPageInstantView *get_web_page_instant_view(WebPageId web_page_id) const;

  void get_web_page_instant_view_impl(WebPageId web_page_id, bool only_local, Promise<WebPageId> &&promise);

  td_api::object_ptr<td_api::LinkPreviewType> get_link_preview_type_album_object(
      const WebPageInstantView &instant_view) const;

  td_api::object_ptr<td_api::LinkPreviewType> get_link_preview_type_object(const WebPage *web_page) const;

  td_api::object_ptr<td_api::webPageInstantView> get_web_page_instant_view_object(
      WebPageId web_page_id, const WebPageInstantView *web_page_instant_view, Slice web_page_url) const;

  static void on_pending_web_page_timeout_callback(void *web_pages_manager_ptr, int64 web_page_id_int);

  void on_pending_web_page_timeout(WebPageId web_page_id);

  void on_get_web_page_preview_success(unique_ptr<GetWebPagePreviewOptions> &&options, WebPageId web_page_id,
                                       Promise<td_api::object_ptr<td_api::linkPreview>> &&promise);

  void on_get_web_page_instant_view(WebPage *web_page, tl_object_ptr<telegram_api::page> &&page, int32 hash,
                                    DialogId owner_dialog_id);

  void save_web_page(const WebPage *web_page, WebPageId web_page_id, bool from_binlog);

  static string get_web_page_database_key(WebPageId web_page_id);

  void on_save_web_page_to_database(WebPageId web_page_id, bool success);

  void load_web_page_from_database(WebPageId web_page_id, Promise<Unit> promise);

  void on_load_web_page_from_database(WebPageId web_page_id, string value);

  const WebPage *get_web_page_force(WebPageId web_page_id);

  static string get_web_page_instant_view_database_key(WebPageId web_page_id);

  void load_web_page_instant_view(WebPageId web_page_id, bool only_local, Promise<WebPageId> &&promise);

  void update_web_page_instant_view_load_requests(WebPageId web_page_id, WebPageId new_web_page_id,
                                                  vector<Promise<WebPageId>> &&promises) const;

  void on_load_web_page_instant_view_from_database(WebPageId web_page_id, string value);

  void on_load_web_page_instant_view(WebPageId web_page_id, WebPageId new_web_page_id);

  void reload_web_page_instant_view(WebPageId web_page_id);

  void on_reload_web_page_instant_view(WebPageId web_page_id, Result<WebPageId> r_web_page_id);

  static string get_web_page_url_database_key(const string &url);

  void load_web_page_by_url(string url, bool only_local, Promise<WebPageId> &&promise);

  void on_load_web_page_id_by_url_from_database(string url, bool only_local, string value,
                                                Promise<WebPageId> &&promise);

  void on_load_web_page_by_url_from_database(WebPageId web_page_id, string url, bool only_local,
                                             Promise<WebPageId> &&promise, Result<Unit> &&result);

  void tear_down() final;

  int32 get_web_page_media_duration(const WebPage *web_page) const;

  FileSourceId get_web_page_file_source_id(WebPage *web_page);

  vector<FileId> get_web_page_file_ids(const WebPage *web_page) const;

  static int32 get_video_start_timestamp(const string &url);

  static bool can_web_page_be_album(const WebPage *web_page);

  static bool is_web_page_album(const WebPage *web_page);

  Td *td_;
  ActorShared<> parent_;
  WaitFreeHashMap<WebPageId, unique_ptr<WebPage>, WebPageIdHash> web_pages_;

  FlatHashMap<WebPageId, vector<Promise<Unit>>, WebPageIdHash> load_web_page_from_database_queries_;
  FlatHashSet<WebPageId, WebPageIdHash> loaded_from_database_web_pages_;

  FlatHashMap<WebPageId, vector<Promise<WebPageId>>, WebPageIdHash> load_local_web_page_instant_view_queries_;
  FlatHashMap<WebPageId, vector<Promise<WebPageId>>, WebPageIdHash> load_server_web_page_instant_view_queries_;

  FlatHashMap<WebPageId, FlatHashSet<MessageFullId, MessageFullIdHash>, WebPageIdHash> web_page_messages_;
  FlatHashMap<WebPageId, FlatHashSet<QuickReplyMessageFullId, QuickReplyMessageFullIdHash>, WebPageIdHash>
      web_page_quick_reply_messages_;

  FlatHashMap<WebPageId,
              vector<std::pair<unique_ptr<GetWebPagePreviewOptions>, Promise<td_api::object_ptr<td_api::linkPreview>>>>,
              WebPageIdHash>
      pending_get_web_pages_;

  FlatHashMap<StoryFullId, FlatHashSet<WebPageId, WebPageIdHash>, StoryFullIdHash> story_web_pages_;

  FlatHashMap<string, std::pair<WebPageId, bool>> url_to_web_page_id_;  // URL -> [WebPageId, from_database]

  FlatHashMap<string, FileSourceId> url_to_file_source_id_;

  MultiTimeout pending_web_pages_timeout_{"PendingWebPagesTimeout"};
};

}  // namespace td
