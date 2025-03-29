//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StickersManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/EmojiGroup.hpp"
#include "td/telegram/EmojiStatus.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Outline.h"
#include "td/telegram/PhotoSizeSource.h"
#include "td/telegram/PhotoSizeType.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretChatLayer.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"

#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"

#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/emoji.h"
#include "td/utils/format.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <type_traits>

namespace td {

class GetAllStickersQuery final : public Td::ResultHandler {
  StickerType sticker_type_;

 public:
  void send(StickerType sticker_type, int64 hash) {
    sticker_type_ = sticker_type;
    switch (sticker_type) {
      case StickerType::Regular:
        return send_query(G()->net_query_creator().create(telegram_api::messages_getAllStickers(hash)));
      case StickerType::Mask:
        return send_query(G()->net_query_creator().create(telegram_api::messages_getMaskStickers(hash)));
      case StickerType::CustomEmoji:
        return send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiStickers(hash)));
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_getMaskStickers::ReturnType,
                               telegram_api::messages_getAllStickers::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::messages_getEmojiStickers::ReturnType,
                               telegram_api::messages_getAllStickers::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_getAllStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for get all " << sticker_type_ << " stickers: " << to_string(ptr);
    td_->stickers_manager_->on_get_installed_sticker_sets(sticker_type_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for get all stickers: " << status;
    }
    td_->stickers_manager_->on_get_installed_sticker_sets_failed(sticker_type_, std::move(status));
  }
};

class SearchStickersQuery final : public Td::ResultHandler {
  string parameters_;
  StickerType sticker_type_;
  bool is_first_;

 public:
  void send(string &&parameters, StickerType sticker_type, const string &emoji, const string &query,
            vector<string> input_language_codes, int32 offset, int32 limit, int64 hash) {
    parameters_ = std::move(parameters);
    sticker_type_ = sticker_type;
    is_first_ = offset == 0;
    int32 flags = 0;
    if (sticker_type == StickerType::CustomEmoji) {
      flags |= telegram_api::messages_searchStickers::EMOJIS_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_searchStickers(
        flags, false /*ignored*/, query, emoji, std::move(input_language_codes), offset, limit, hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_searchStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for search stickers: " << to_string(ptr);
    td_->stickers_manager_->on_find_stickers_by_query_success(sticker_type_, parameters_, is_first_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for search stickers: " << status;
    }
    td_->stickers_manager_->on_find_stickers_by_query_fail(sticker_type_, parameters_, std::move(status));
  }
};

class GetStickersQuery final : public Td::ResultHandler {
  string emoji_;

 public:
  void send(string &&emoji, int64 hash) {
    emoji_ = std::move(emoji);
    send_query(G()->net_query_creator().create(telegram_api::messages_getStickers(emoji_, hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for search stickers by emoji: " << to_string(ptr);
    td_->stickers_manager_->on_find_stickers_success(emoji_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for search stickers by emoji: " << status;
    }
    td_->stickers_manager_->on_find_stickers_fail(emoji_, std::move(status));
  }
};

class SearchCustomEmojiQuery final : public Td::ResultHandler {
  string emoji_;

 public:
  void send(string &&emoji, int64 hash) {
    emoji_ = std::move(emoji);
    send_query(G()->net_query_creator().create(telegram_api::messages_searchCustomEmoji(emoji_, hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_searchCustomEmoji>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for search custom emoji: " << to_string(ptr);
    td_->stickers_manager_->on_find_custom_emojis_success(emoji_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for search stickers: " << status;
    }
    td_->stickers_manager_->on_find_custom_emojis_fail(emoji_, std::move(status));
  }
};

class GetEmojiKeywordsLanguageQuery final : public Td::ResultHandler {
  Promise<vector<string>> promise_;

 public:
  explicit GetEmojiKeywordsLanguageQuery(Promise<vector<string>> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<string> &&language_codes) {
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getEmojiKeywordsLanguages(std::move(language_codes))));
  }
  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getEmojiKeywordsLanguages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result =
        transform(result_ptr.move_as_ok(), [](auto &&emoji_language) { return std::move(emoji_language->lang_code_); });
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetEmojiKeywordsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> promise_;

 public:
  explicit GetEmojiKeywordsQuery(Promise<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &language_code) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiKeywords(language_code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getEmojiKeywords>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetEmojiKeywordsDifferenceQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> promise_;

 public:
  explicit GetEmojiKeywordsDifferenceQuery(
      Promise<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &language_code, int32 version) {
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getEmojiKeywordsDifference(language_code, version)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getEmojiKeywordsDifference>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetEmojiUrlQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit GetEmojiUrlQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &language_code) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiURL(language_code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getEmojiURL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    promise_.set_value(std::move(ptr->url_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetArchivedStickerSetsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  StickerSetId offset_sticker_set_id_;
  StickerType sticker_type_;

 public:
  explicit GetArchivedStickerSetsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(StickerType sticker_type, StickerSetId offset_sticker_set_id, int32 limit) {
    offset_sticker_set_id_ = offset_sticker_set_id;
    sticker_type_ = sticker_type;

    int32 flags = 0;
    if (sticker_type_ == StickerType::Mask) {
      flags |= telegram_api::messages_getArchivedStickers::MASKS_MASK;
    }
    if (sticker_type_ == StickerType::CustomEmoji) {
      flags |= telegram_api::messages_getArchivedStickers::EMOJIS_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_getArchivedStickers(
        flags, false /*ignored*/, false /*ignored*/, offset_sticker_set_id.get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getArchivedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetArchivedStickerSetsQuery: " << to_string(ptr);
    td_->stickers_manager_->on_get_archived_sticker_sets(sticker_type_, offset_sticker_set_id_, std::move(ptr->sets_),
                                                         ptr->count_);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetFeaturedStickerSetsQuery final : public Td::ResultHandler {
  StickerType sticker_type_;

 public:
  void send(StickerType sticker_type, int64 hash) {
    sticker_type_ = sticker_type;
    switch (sticker_type) {
      case StickerType::Regular:
        send_query(G()->net_query_creator().create(telegram_api::messages_getFeaturedStickers(hash)));
        break;
      case StickerType::CustomEmoji:
        send_query(G()->net_query_creator().create(telegram_api::messages_getFeaturedEmojiStickers(hash)));
        break;
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_getFeaturedStickers::ReturnType,
                               telegram_api::messages_getFeaturedEmojiStickers::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_getFeaturedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetFeaturedStickerSetsQuery: " << to_string(ptr);
    td_->stickers_manager_->on_get_featured_sticker_sets(sticker_type_, -1, -1, 0, std::move(ptr));
  }

  void on_error(Status status) final {
    td_->stickers_manager_->on_get_featured_sticker_sets_failed(sticker_type_, -1, -1, 0, std::move(status));
  }
};

class GetOldFeaturedStickerSetsQuery final : public Td::ResultHandler {
  int32 offset_;
  int32 limit_;
  uint32 generation_;

 public:
  void send(StickerType sticker_type, int32 offset, int32 limit, uint32 generation) {
    CHECK(sticker_type == StickerType::Regular);
    offset_ = offset;
    limit_ = limit;
    generation_ = generation;
    send_query(G()->net_query_creator().create(telegram_api::messages_getOldFeaturedStickers(offset, limit, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getOldFeaturedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetOldFeaturedStickerSetsQuery: " << to_string(ptr);
    td_->stickers_manager_->on_get_featured_sticker_sets(StickerType::Regular, offset_, limit_, generation_,
                                                         std::move(ptr));
  }

  void on_error(Status status) final {
    td_->stickers_manager_->on_get_featured_sticker_sets_failed(StickerType::Regular, offset_, limit_, generation_,
                                                                std::move(status));
  }
};

class GetAttachedStickerSetsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  FileId file_id_;
  string file_reference_;

 public:
  explicit GetAttachedStickerSetsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(FileId file_id, string &&file_reference,
            tl_object_ptr<telegram_api::InputStickeredMedia> &&input_stickered_media) {
    file_id_ = file_id;
    file_reference_ = std::move(file_reference);
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getAttachedStickers(std::move(input_stickered_media))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAttachedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_get_attached_sticker_sets(file_id_, result_ptr.move_as_ok());

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      VLOG(file_references) << "Receive " << status << " for " << file_id_;
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_,
          PromiseCreator::lambda([file_id = file_id_, promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              return promise.set_error(Status::Error(400, "Failed to find the file"));
            }

            send_closure(G()->stickers_manager(), &StickersManager::send_get_attached_stickers_query, file_id,
                         std::move(promise));
          }));
      return;
    }

    promise_.set_error(std::move(status));
  }
};

class GetRecentStickersQuery final : public Td::ResultHandler {
  bool is_repair_ = false;
  bool is_attached_ = false;

 public:
  void send(bool is_repair, bool is_attached, int64 hash) {
    is_repair_ = is_repair;
    is_attached_ = is_attached;
    int32 flags = 0;
    if (is_attached) {
      flags |= telegram_api::messages_getRecentStickers::ATTACHED_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_getRecentStickers(flags, is_attached /*ignored*/, hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getRecentStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for get recent " << (is_attached_ ? "attached " : "")
               << "stickers: " << to_string(ptr);
    td_->stickers_manager_->on_get_recent_stickers(is_repair_, is_attached_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for get recent " << (is_attached_ ? "attached " : "") << "stickers: " << status;
    }
    td_->stickers_manager_->on_get_recent_stickers_failed(is_repair_, is_attached_, std::move(status));
  }
};

class SaveRecentStickerQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  FileId file_id_;
  string file_reference_;
  bool unsave_ = false;
  bool is_attached_;

 public:
  explicit SaveRecentStickerQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool is_attached, FileId file_id, tl_object_ptr<telegram_api::inputDocument> &&input_document,
            bool unsave) {
    CHECK(input_document != nullptr);
    CHECK(file_id.is_valid());
    file_id_ = file_id;
    file_reference_ = input_document->file_reference_.as_slice().str();
    unsave_ = unsave;
    is_attached_ = is_attached;

    int32 flags = 0;
    if (is_attached) {
      flags |= telegram_api::messages_saveRecentSticker::ATTACHED_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_saveRecentSticker(flags, is_attached /*ignored*/, std::move(input_document), unsave)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_saveRecentSticker>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for save recent " << (is_attached_ ? "attached " : "") << "sticker: " << result;
    if (!result) {
      td_->stickers_manager_->reload_recent_stickers(is_attached_, true);
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      VLOG(file_references) << "Receive " << status << " for " << file_id_;
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_, PromiseCreator::lambda([sticker_id = file_id_, is_attached = is_attached_, unsave = unsave_,
                                            promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              return promise.set_error(Status::Error(400, "Failed to find the sticker"));
            }

            send_closure(G()->stickers_manager(), &StickersManager::send_save_recent_sticker_query, is_attached,
                         sticker_id, unsave, std::move(promise));
          }));
      return;
    }

    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for save recent " << (is_attached_ ? "attached " : "") << "sticker: " << status;
    }
    td_->stickers_manager_->reload_recent_stickers(is_attached_, true);
    promise_.set_error(std::move(status));
  }
};

class ClearRecentStickersQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  bool is_attached_;

 public:
  explicit ClearRecentStickersQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool is_attached) {
    is_attached_ = is_attached;

    int32 flags = 0;
    if (is_attached) {
      flags |= telegram_api::messages_clearRecentStickers::ATTACHED_MASK;
    }

    send_query(
        G()->net_query_creator().create(telegram_api::messages_clearRecentStickers(flags, is_attached /*ignored*/)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_clearRecentStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for clear recent " << (is_attached_ ? "attached " : "") << "stickers: " << result;
    if (!result) {
      td_->stickers_manager_->reload_recent_stickers(is_attached_, true);
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for clear recent " << (is_attached_ ? "attached " : "") << "stickers: " << status;
    }
    td_->stickers_manager_->reload_recent_stickers(is_attached_, true);
    promise_.set_error(std::move(status));
  }
};

class GetFavedStickersQuery final : public Td::ResultHandler {
  bool is_repair_ = false;

 public:
  void send(bool is_repair, int64 hash) {
    is_repair_ = is_repair;
    send_query(G()->net_query_creator().create(telegram_api::messages_getFavedStickers(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getFavedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->stickers_manager_->on_get_favorite_stickers(is_repair_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for get favorite stickers: " << status;
    }
    td_->stickers_manager_->on_get_favorite_stickers_failed(is_repair_, std::move(status));
  }
};

class FaveStickerQuery final : public Td::ResultHandler {
  FileId file_id_;
  string file_reference_;
  bool unsave_ = false;

  Promise<Unit> promise_;

 public:
  explicit FaveStickerQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(FileId file_id, tl_object_ptr<telegram_api::inputDocument> &&input_document, bool unsave) {
    CHECK(input_document != nullptr);
    CHECK(file_id.is_valid());
    file_id_ = file_id;
    file_reference_ = input_document->file_reference_.as_slice().str();
    unsave_ = unsave;

    send_query(G()->net_query_creator().create(telegram_api::messages_faveSticker(std::move(input_document), unsave)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_faveSticker>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for fave sticker: " << result;
    if (!result) {
      td_->stickers_manager_->reload_favorite_stickers(true);
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      VLOG(file_references) << "Receive " << status << " for " << file_id_;
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_, PromiseCreator::lambda([sticker_id = file_id_, unsave = unsave_,
                                            promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              return promise.set_error(Status::Error(400, "Failed to find the sticker"));
            }

            send_closure(G()->stickers_manager(), &StickersManager::send_fave_sticker_query, sticker_id, unsave,
                         std::move(promise));
          }));
      return;
    }

    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for fave sticker: " << status;
    }
    td_->stickers_manager_->reload_favorite_stickers(true);
    promise_.set_error(std::move(status));
  }
};

class ReorderStickerSetsQuery final : public Td::ResultHandler {
  StickerType sticker_type_;

 public:
  void send(StickerType sticker_type, const vector<StickerSetId> &sticker_set_ids) {
    sticker_type_ = sticker_type;
    int32 flags = 0;
    if (sticker_type == StickerType::Mask) {
      flags |= telegram_api::messages_reorderStickerSets::MASKS_MASK;
    }
    if (sticker_type == StickerType::CustomEmoji) {
      flags |= telegram_api::messages_reorderStickerSets::EMOJIS_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_reorderStickerSets(
        flags, false /*ignored*/, false /*ignored*/, StickersManager::convert_sticker_set_ids(sticker_set_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reorderStickerSets>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      return on_error(Status::Error(400, "Result is false"));
    }
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for ReorderStickerSetsQuery: " << status;
    }
    td_->stickers_manager_->reload_installed_sticker_sets(sticker_type_, true);
  }
};

class GetStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  StickerSetId sticker_set_id_;
  string sticker_set_name_;

 public:
  explicit GetStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(StickerSetId sticker_set_id, tl_object_ptr<telegram_api::InputStickerSet> &&input_sticker_set, int32 hash) {
    sticker_set_id_ = sticker_set_id;
    if (input_sticker_set->get_id() == telegram_api::inputStickerSetShortName::ID) {
      sticker_set_name_ =
          static_cast<const telegram_api::inputStickerSetShortName *>(input_sticker_set.get())->short_name_;
    }
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getStickerSet(std::move(input_sticker_set), hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto set_ptr = result_ptr.move_as_ok();
    if (set_ptr->get_id() == telegram_api::messages_stickerSet::ID) {
      auto set = static_cast<telegram_api::messages_stickerSet *>(set_ptr.get());
      constexpr int64 GREAT_MINDS_COLOR_SET_ID = 151353307481243663;
      if (set->set_->id_ == GREAT_MINDS_COLOR_SET_ID) {
        string great_minds_name = "TelegramGreatMinds";
        if (sticker_set_id_.get() == StickersManager::GREAT_MINDS_SET_ID ||
            trim(to_lower(sticker_set_name_)) == to_lower(great_minds_name)) {
          set->set_->id_ = StickersManager::GREAT_MINDS_SET_ID;
          set->set_->short_name_ = std::move(great_minds_name);
        }
      }
    }

    td_->stickers_manager_->on_get_messages_sticker_set(sticker_set_id_, std::move(set_ptr), true,
                                                        "GetStickerSetQuery");

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetStickerSetQuery: " << status;
    td_->stickers_manager_->on_load_sticker_set_fail(sticker_set_id_, status);
    promise_.set_error(std::move(status));
  }
};

class GetStickerSetNameQuery final : public Td::ResultHandler {
  StickerSetId sticker_set_id_;

 public:
  void send(StickerSetId sticker_set_id, telegram_api::object_ptr<telegram_api::InputStickerSet> &&input_sticker_set) {
    sticker_set_id_ = sticker_set_id;
    send_query(G()->net_query_creator().create(telegram_api::messages_getStickerSet(std::move(input_sticker_set), 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_get_sticker_set_name(sticker_set_id_, result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    td_->stickers_manager_->on_get_sticker_set_name(sticker_set_id_, nullptr);
  }
};

class ReloadSpecialStickerSetQuery final : public Td::ResultHandler {
  StickerSetId sticker_set_id_;
  SpecialStickerSetType type_;

 public:
  void send(StickerSetId sticker_set_id, SpecialStickerSetType type, int32 hash) {
    sticker_set_id_ = sticker_set_id;
    type_ = std::move(type);
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getStickerSet(type_.get_input_sticker_set(), hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto set_ptr = result_ptr.move_as_ok();
    if (set_ptr->get_id() == telegram_api::messages_stickerSet::ID) {
      // sticker_set_id_ must be replaced always, because it could have been changed
      // we must not pass sticker_set_id_ in order to allow its change
      sticker_set_id_ = td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), std::move(set_ptr), true,
                                                                            "ReloadSpecialStickerSetQuery");
    } else {
      CHECK(set_ptr->get_id() == telegram_api::messages_stickerSetNotModified::ID);
      // we received telegram_api::messages_stickerSetNotModified, and must pass sticker_set_id_ to handle it
      // sticker_set_id_ can't be changed by this call
      td_->stickers_manager_->on_get_messages_sticker_set(sticker_set_id_, std::move(set_ptr), false,
                                                          "ReloadSpecialStickerSetQuery");
    }
    if (!sticker_set_id_.is_valid()) {
      return on_error(Status::Error(500, "Failed to add special sticker set"));
    }
    td_->stickers_manager_->on_get_special_sticker_set(type_, sticker_set_id_);
  }

  void on_error(Status status) final {
    LOG(WARNING) << "Receive error for ReloadSpecialStickerSetQuery: " << status;
    td_->stickers_manager_->on_load_special_sticker_set(type_, std::move(status));
  }
};

class SearchStickerSetsQuery final : public Td::ResultHandler {
  StickerType sticker_type_;
  string query_;

 public:
  void send(StickerType sticker_type, string query) {
    sticker_type_ = sticker_type;
    query_ = std::move(query);
    switch (sticker_type) {
      case StickerType::Regular:
        send_query(
            G()->net_query_creator().create(telegram_api::messages_searchStickerSets(0, false /*ignored*/, query_, 0)));
        break;
      case StickerType::CustomEmoji:
        send_query(G()->net_query_creator().create(
            telegram_api::messages_searchEmojiStickerSets(0, false /*ignored*/, query_, 0)));
        break;
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_searchStickerSets::ReturnType,
                               telegram_api::messages_searchEmojiStickerSets::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_searchStickerSets>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for search " << sticker_type_ << " sticker sets: " << to_string(ptr);
    td_->stickers_manager_->on_find_sticker_sets_success(sticker_type_, query_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for search " << sticker_type_ << " sticker sets: " << status;
    }
    td_->stickers_manager_->on_find_sticker_sets_fail(sticker_type_, query_, std::move(status));
  }
};

class InstallStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  StickerSetId set_id_;
  bool is_archived_;

 public:
  explicit InstallStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(StickerSetId set_id, tl_object_ptr<telegram_api::InputStickerSet> &&input_set, bool is_archived) {
    set_id_ = set_id;
    is_archived_ = is_archived;
    send_query(
        G()->net_query_creator().create(telegram_api::messages_installStickerSet(std::move(input_set), is_archived)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_installStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_install_sticker_set(set_id_, is_archived_, result_ptr.move_as_ok());

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UninstallStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  StickerSetId set_id_;

 public:
  explicit UninstallStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(StickerSetId set_id, tl_object_ptr<telegram_api::InputStickerSet> &&input_set) {
    set_id_ = set_id;
    send_query(G()->net_query_creator().create(telegram_api::messages_uninstallStickerSet(std::move(input_set))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_uninstallStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      LOG(WARNING) << "Receive false in result to uninstallStickerSet";
    } else {
      td_->stickers_manager_->on_uninstall_sticker_set(set_id_);
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ReadFeaturedStickerSetsQuery final : public Td::ResultHandler {
 public:
  void send(const vector<StickerSetId> &sticker_set_ids) {
    send_query(G()->net_query_creator().create(
        telegram_api::messages_readFeaturedStickers(StickersManager::convert_sticker_set_ids(sticker_set_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_readFeaturedStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    (void)result;
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for ReadFeaturedStickerSetsQuery: " << status;
    }
    td_->stickers_manager_->reload_featured_sticker_sets(StickerType::Regular, true);
    td_->stickers_manager_->reload_featured_sticker_sets(StickerType::CustomEmoji, true);
  }
};

class UploadStickerFileQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  FileUploadId file_upload_id_;
  bool is_url_ = false;
  bool was_uploaded_ = false;

 public:
  explicit UploadStickerFileQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputPeer> &&input_peer, FileUploadId file_upload_id, bool is_url,
            tl_object_ptr<telegram_api::InputMedia> &&input_media) {
    CHECK(input_peer != nullptr);
    CHECK(input_media != nullptr);
    file_upload_id_ = file_upload_id;
    is_url_ = is_url;
    was_uploaded_ = FileManager::extract_was_uploaded(input_media);
    send_query(G()->net_query_creator().create(
        telegram_api::messages_uploadMedia(0, string(), std::move(input_peer), std::move(input_media))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_uploadMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_uploaded_sticker_file(file_upload_id_, is_url_, result_ptr.move_as_ok(),
                                                     std::move(promise_));
  }

  void on_error(Status status) final {
    if (was_uploaded_) {
      CHECK(file_upload_id_.is_valid());
      auto bad_parts = FileManager::get_missing_file_parts(status);
      if (!bad_parts.empty()) {
        // TODO td_->stickers_manager_->on_upload_sticker_file_parts_missing(file_upload_id_, std::move(bad_parts));
        // return;
      } else {
        td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id_, status);
      }
    } else if (FileReferenceManager::is_file_reference_error(status)) {
      LOG(ERROR) << "Receive file reference error for UploadStickerFileQuery";
    }
    td_->file_manager_->cancel_upload(file_upload_id_);
    promise_.set_error(std::move(status));
  }
};

class SuggestStickerSetShortNameQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit SuggestStickerSetShortNameQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &title) {
    send_query(G()->net_query_creator().create(telegram_api::stickers_suggestShortName(title)));
  }
  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_suggestShortName>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    promise_.set_value(std::move(ptr->short_name_));
  }

  void on_error(Status status) final {
    if (status.message() == "TITLE_INVALID") {
      return promise_.set_value(string());
    }
    promise_.set_error(std::move(status));
  }
};

class CheckStickerSetShortNameQuery final : public Td::ResultHandler {
  Promise<bool> promise_;

 public:
  explicit CheckStickerSetShortNameQuery(Promise<bool> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name) {
    send_query(G()->net_query_creator().create(telegram_api::stickers_checkShortName(short_name)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_checkShortName>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CreateNewStickerSetQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::stickerSet>> promise_;

 public:
  explicit CreateNewStickerSetQuery(Promise<td_api::object_ptr<td_api::stickerSet>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputUser> &&input_user, const string &title, const string &short_name,
            StickerType sticker_type, bool has_text_color,
            vector<tl_object_ptr<telegram_api::inputStickerSetItem>> &&input_stickers, const string &software) {
    CHECK(input_user != nullptr);

    int32 flags = 0;
    if (sticker_type == StickerType::Mask) {
      flags |= telegram_api::stickers_createStickerSet::MASKS_MASK;
    }
    if (sticker_type == StickerType::CustomEmoji) {
      flags |= telegram_api::stickers_createStickerSet::EMOJIS_MASK;
    }
    if (has_text_color) {
      flags |= telegram_api::stickers_createStickerSet::TEXT_COLOR_MASK;
    }
    if (!software.empty()) {
      flags |= telegram_api::stickers_createStickerSet::SOFTWARE_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::stickers_createStickerSet(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                                std::move(input_user), title, short_name, nullptr,
                                                std::move(input_stickers), software),
        {{short_name}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_createStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto sticker_set_id = td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(),
                                                                              true, "CreateNewStickerSetQuery");
    if (!sticker_set_id.is_valid()) {
      return on_error(Status::Error(500, "Created sticker set not found"));
    }
    promise_.set_value(td_->stickers_manager_->get_sticker_set_object(sticker_set_id));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AddStickerToSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AddStickerToSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name, telegram_api::object_ptr<telegram_api::inputStickerSetItem> &&input_sticker,
            telegram_api::object_ptr<telegram_api::inputDocument> &&input_document) {
    if (input_document != nullptr) {
      send_query(G()->net_query_creator().create(
          telegram_api::stickers_replaceSticker(std::move(input_document), std::move(input_sticker)), {{short_name}}));
    } else {
      send_query(G()->net_query_creator().create(
          telegram_api::stickers_addStickerToSet(make_tl_object<telegram_api::inputStickerSetShortName>(short_name),
                                                 std::move(input_sticker)),
          {{short_name}}));
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::stickers_addStickerToSet::ReturnType,
                               telegram_api::stickers_replaceSticker::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::stickers_addStickerToSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto sticker_set_id = td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(),
                                                                              true, "AddStickerToSetQuery");
    if (!sticker_set_id.is_valid()) {
      return on_error(Status::Error(500, "Sticker set not found"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetStickerSetThumbnailQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetStickerSetThumbnailQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name, tl_object_ptr<telegram_api::InputDocument> &&input_document) {
    int32 flags = telegram_api::stickers_setStickerSetThumb::THUMB_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::stickers_setStickerSetThumb(
            flags, make_tl_object<telegram_api::inputStickerSetShortName>(short_name), std::move(input_document), 0),
        {{short_name}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_setStickerSetThumb>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto sticker_set_id = td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(),
                                                                              true, "SetStickerSetThumbnailQuery");
    if (!sticker_set_id.is_valid()) {
      return on_error(Status::Error(500, "Sticker set not found"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetCustomEmojiStickerSetThumbnailQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetCustomEmojiStickerSetThumbnailQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name, CustomEmojiId custom_emoji_id) {
    int32 flags = telegram_api::stickers_setStickerSetThumb::THUMB_DOCUMENT_ID_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::stickers_setStickerSetThumb(
            flags, make_tl_object<telegram_api::inputStickerSetShortName>(short_name), nullptr, custom_emoji_id.get()),
        {{short_name}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_setStickerSetThumb>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto sticker_set_id = td_->stickers_manager_->on_get_messages_sticker_set(
        StickerSetId(), result_ptr.move_as_ok(), true, "SetCustomEmojiStickerSetThumbnailQuery");
    if (!sticker_set_id.is_valid()) {
      return on_error(Status::Error(500, "Sticker set not found"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetStickerSetTitleQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetStickerSetTitleQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name, const string &title) {
    send_query(
        G()->net_query_creator().create(telegram_api::stickers_renameStickerSet(
                                            make_tl_object<telegram_api::inputStickerSetShortName>(short_name), title),
                                        {{short_name}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_renameStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto sticker_set_id = td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(),
                                                                              true, "SetStickerSetTitleQuery");
    if (!sticker_set_id.is_valid()) {
      return on_error(Status::Error(500, "Sticker set not found"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  string short_name_;

 public:
  explicit DeleteStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &short_name) {
    short_name_ = short_name;
    send_query(G()->net_query_creator().create(
        telegram_api::stickers_deleteStickerSet(make_tl_object<telegram_api::inputStickerSetShortName>(short_name)),
        {{short_name}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_deleteStickerSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      return on_error(Status::Error(500, "Failed to delete sticker set"));
    }
    td_->stickers_manager_->on_sticker_set_deleted(short_name_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetStickerPositionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetStickerPositionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &unique_name, tl_object_ptr<telegram_api::inputDocument> &&input_document, int32 position) {
    vector<ChainId> chain_ids;
    if (!unique_name.empty()) {
      chain_ids.emplace_back(unique_name);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::stickers_changeStickerPosition(std::move(input_document), position), std::move(chain_ids)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_changeStickerPosition>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(), true,
                                                        "SetStickerPositionQuery");

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteStickerFromSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteStickerFromSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &unique_name, tl_object_ptr<telegram_api::inputDocument> &&input_document) {
    vector<ChainId> chain_ids;
    if (!unique_name.empty()) {
      chain_ids.emplace_back(unique_name);
    }
    send_query(G()->net_query_creator().create(telegram_api::stickers_removeStickerFromSet(std::move(input_document)),
                                               std::move(chain_ids)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_removeStickerFromSet>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(), true,
                                                        "DeleteStickerFromSetQuery");

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ChangeStickerQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ChangeStickerQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &unique_name, tl_object_ptr<telegram_api::inputDocument> &&input_document, bool edit_emojis,
            const string &emojis, StickerMaskPosition mask_position, bool edit_keywords, const string &keywords) {
    vector<ChainId> chain_ids;
    if (!unique_name.empty()) {
      chain_ids.emplace_back(unique_name);
    }
    int32 flags = 0;
    if (edit_emojis) {
      flags |= telegram_api::stickers_changeSticker::EMOJI_MASK;
    }
    auto mask_coords = mask_position.get_input_mask_coords();
    if (mask_coords != nullptr) {
      flags |= telegram_api::stickers_changeSticker::MASK_COORDS_MASK;
    }
    if (edit_keywords) {
      flags |= telegram_api::stickers_changeSticker::KEYWORDS_MASK;
    }
    send_query(
        G()->net_query_creator().create(telegram_api::stickers_changeSticker(flags, std::move(input_document), emojis,
                                                                             std::move(mask_coords), keywords),
                                        std::move(chain_ids)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::stickers_changeSticker>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), result_ptr.move_as_ok(), true,
                                                        "ChangeStickerQuery");

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetMyStickersQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_myStickers>> promise_;

 public:
  explicit GetMyStickersQuery(Promise<telegram_api::object_ptr<telegram_api::messages_myStickers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(StickerSetId offset_sticker_set_id, int32 limit) {
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getMyStickers(offset_sticker_set_id.get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getMyStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetMyStickersQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetCustomEmojiDocumentsQuery final : public Td::ResultHandler {
  Promise<vector<telegram_api::object_ptr<telegram_api::Document>>> promise_;

 public:
  explicit GetCustomEmojiDocumentsQuery(Promise<vector<telegram_api::object_ptr<telegram_api::Document>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(vector<CustomEmojiId> &&custom_emoji_ids) {
    auto document_ids =
        transform(custom_emoji_ids, [](CustomEmojiId custom_emoji_id) { return custom_emoji_id.get(); });
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getCustomEmojiDocuments(std::move(document_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getCustomEmojiDocuments>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetEmojiGroupsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_EmojiGroups>> promise_;

 public:
  explicit GetEmojiGroupsQuery(Promise<telegram_api::object_ptr<telegram_api::messages_EmojiGroups>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(EmojiGroupType group_type, int32 hash) {
    switch (group_type) {
      case EmojiGroupType::Default:
        send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiGroups(hash)));
        break;
      case EmojiGroupType::EmojiStatus:
        send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiStatusGroups(hash)));
        break;
      case EmojiGroupType::ProfilePhoto:
        send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiProfilePhotoGroups(hash)));
        break;
      case EmojiGroupType::RegularStickers:
        send_query(G()->net_query_creator().create(telegram_api::messages_getEmojiStickerGroups(hash)));
        break;
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_getEmojiGroups::ReturnType,
                               telegram_api::messages_getEmojiStatusGroups::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::messages_getEmojiGroups::ReturnType,
                               telegram_api::messages_getEmojiProfilePhotoGroups::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::messages_getEmojiGroups::ReturnType,
                               telegram_api::messages_getEmojiStickerGroups::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_getEmojiGroups>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetDefaultDialogPhotoEmojisQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::EmojiList>> promise_;

 public:
  explicit GetDefaultDialogPhotoEmojisQuery(Promise<telegram_api::object_ptr<telegram_api::EmojiList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(StickerListType sticker_list_type, int64 hash) {
    switch (sticker_list_type) {
      case StickerListType::DialogPhoto:
        send_query(G()->net_query_creator().create(telegram_api::account_getDefaultGroupPhotoEmojis(hash)));
        break;
      case StickerListType::UserProfilePhoto:
        send_query(G()->net_query_creator().create(telegram_api::account_getDefaultProfilePhotoEmojis(hash)));
        break;
      case StickerListType::Background:
        send_query(G()->net_query_creator().create(telegram_api::account_getDefaultBackgroundEmojis(hash)));
        break;
      case StickerListType::DisallowedChannelEmojiStatus:
        send_query(G()->net_query_creator().create(telegram_api::account_getChannelRestrictedStatusEmojis(hash)));
        break;
      default:
        UNREACHABLE();
        break;
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::account_getDefaultProfilePhotoEmojis::ReturnType,
                               telegram_api::account_getDefaultGroupPhotoEmojis::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::account_getDefaultBackgroundEmojis::ReturnType,
                               telegram_api::account_getDefaultGroupPhotoEmojis::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::account_getChannelRestrictedStatusEmojis::ReturnType,
                               telegram_api::account_getDefaultGroupPhotoEmojis::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::account_getDefaultGroupPhotoEmojis>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SendAnimatedEmojiClicksQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  string emoji_;

 public:
  void send(DialogId dialog_id, tl_object_ptr<telegram_api::InputPeer> &&input_peer,
            tl_object_ptr<telegram_api::sendMessageEmojiInteraction> &&action) {
    dialog_id_ = dialog_id;
    CHECK(input_peer != nullptr);
    CHECK(action != nullptr);
    emoji_ = action->emoticon_;

    int32 flags = 0;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_setTyping(flags, std::move(input_peer), 0, std::move(action))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setTyping>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    // ignore result
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendAnimatedEmojiClicksQuery")) {
      LOG(INFO) << "Receive error for send animated emoji clicks: " << status;
    }

    td_->stickers_manager_->on_send_animated_emoji_clicks(dialog_id_, emoji_);
  }
};

template <class StorerT>
void StickersManager::FoundStickers::store(StorerT &storer) const {
  StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
  td::store(narrow_cast<int32>(sticker_ids_.size()), storer);
  for (auto sticker_id : sticker_ids_) {
    stickers_manager->store_sticker(sticker_id, false, storer, "FoundStickers");
  }
  td::store(cache_time_, storer);
  store_time(next_reload_time_, storer);
}

template <class ParserT>
void StickersManager::FoundStickers::parse(ParserT &parser) {
  StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
  int32 size = parser.fetch_int();
  sticker_ids_.resize(size);
  for (auto &sticker_id : sticker_ids_) {
    sticker_id = stickers_manager->parse_sticker(false, parser);
  }
  td::parse(cache_time_, parser);
  parse_time(next_reload_time_, parser);
}

class StickersManager::StickerListLogEvent {
 public:
  vector<FileId> sticker_ids;

  StickerListLogEvent() = default;

  explicit StickerListLogEvent(vector<FileId> sticker_ids) : sticker_ids(std::move(sticker_ids)) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
    td::store(narrow_cast<int32>(sticker_ids.size()), storer);
    for (auto sticker_id : sticker_ids) {
      stickers_manager->store_sticker(sticker_id, false, storer, "StickerListLogEvent");
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
    int32 size = parser.fetch_int();
    sticker_ids.resize(size);
    for (auto &sticker_id : sticker_ids) {
      sticker_id = stickers_manager->parse_sticker(false, parser);
    }
  }
};

class StickersManager::StickerSetListLogEvent {
 public:
  vector<StickerSetId> sticker_set_ids_;
  bool is_premium_ = false;

  StickerSetListLogEvent() = default;

  StickerSetListLogEvent(vector<StickerSetId> sticker_set_ids, bool is_premium)
      : sticker_set_ids_(std::move(sticker_set_ids)), is_premium_(is_premium) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_premium_);
    END_STORE_FLAGS();
    td::store(sticker_set_ids_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::AddStickerSetListFlags)) {
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(is_premium_);
      END_PARSE_FLAGS();
    }
    td::parse(sticker_set_ids_, parser);
  }
};

class StickersManager::UploadStickerFileCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->stickers_manager(), &StickersManager::on_upload_sticker_file, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->stickers_manager(), &StickersManager::on_upload_sticker_file_error, file_upload_id,
                       std::move(error));
  }
};

StickersManager::StickersManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_sticker_file_callback_ = std::make_shared<UploadStickerFileCallback>();

  if (!td_->auth_manager_->is_bot()) {
    on_update_animated_emoji_zoom();
    on_update_recent_stickers_limit();
    on_update_favorite_stickers_limit();
  }

  next_click_animated_emoji_message_time_ = Time::now();
  next_update_animated_emoji_clicked_time_ = Time::now();
}

StickersManager::~StickersManager() {
  Scheduler::instance()->destroy_on_scheduler(
      G()->get_gc_scheduler_id(), stickers_, sticker_sets_, short_name_to_sticker_set_id_, attached_sticker_sets_,
      found_stickers_[0], found_stickers_[1], found_stickers_[2], found_sticker_sets_[0], found_sticker_sets_[1],
      found_sticker_sets_[2], emoji_language_codes_, emoji_language_code_versions_,
      emoji_language_code_last_difference_times_, reloaded_emoji_keywords_, premium_gift_messages_, dice_messages_,
      dice_quick_reply_messages_, emoji_messages_, custom_emoji_messages_, custom_emoji_to_sticker_id_);
}

void StickersManager::start_up() {
  init();
}

void StickersManager::init() {
  if (G()->close_flag()) {
    return;
  }
  if (is_inited_ || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }
  LOG(INFO) << "Init StickersManager";
  is_inited_ = true;

  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji());
    if (G()->is_test_dc()) {
      init_special_sticker_set(sticker_set, 1258816259751954, 4879754868529595811, "emojies");
    } else {
      init_special_sticker_set(sticker_set, 1258816259751983, 5100237018658464041, "AnimatedEmojies");
    }
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  if (!G()->is_test_dc()) {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji_click());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::premium_gifts());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::generic_animations());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::default_statuses());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::default_channel_statuses());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }
  {
    auto &sticker_set = add_special_sticker_set(SpecialStickerSetType::default_topic_icons());
    load_special_sticker_set_info_from_binlog(sticker_set);
  }

  dice_emojis_str_ = td_->option_manager_->get_option_string("dice_emojis", "🎲\x01🎯\x01🏀\x01⚽\x01⚽️\x01🎰\x01🎳");
  dice_emojis_ = full_split(dice_emojis_str_, '\x01');
  for (auto &dice_emoji : dice_emojis_) {
    auto &animated_dice_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_dice(dice_emoji));
    load_special_sticker_set_info_from_binlog(animated_dice_sticker_set);
  }
  send_closure(G()->td(), &Td::send_update, get_update_dice_emojis_object());

  on_update_dice_success_values();
  on_update_dice_emojis();

  on_update_emoji_sounds();

  on_update_disable_animated_emojis();
  if (!disable_animated_emojis_) {
    load_special_sticker_set(add_special_sticker_set(SpecialStickerSetType::animated_emoji()));
  }
  load_special_sticker_set(add_special_sticker_set(SpecialStickerSetType::premium_gifts()));

  if (G()->use_sqlite_pmc()) {
    auto old_featured_sticker_set_count_str = G()->td_db()->get_binlog_pmc()->get("old_featured_sticker_set_count");
    if (!old_featured_sticker_set_count_str.empty()) {
      old_featured_sticker_set_count_[static_cast<int32>(StickerType::Regular)] =
          to_integer<int32>(old_featured_sticker_set_count_str);
    }
    if (!G()->td_db()->get_binlog_pmc()->get("invalidate_old_featured_sticker_sets").empty()) {
      invalidate_old_featured_sticker_sets(StickerType::Regular);
    }
  } else {
    G()->td_db()->get_binlog_pmc()->erase("old_featured_sticker_set_count");
    G()->td_db()->get_binlog_pmc()->erase("invalidate_old_featured_sticker_sets");
  }

  G()->td_db()->get_binlog_pmc()->erase("animated_dice_sticker_set");         // legacy
  td_->option_manager_->set_option_empty("animated_dice_sticker_set_name");   // legacy
  td_->option_manager_->set_option_empty("animated_emoji_sticker_set_name");  // legacy
}

StickersManager::SpecialStickerSet &StickersManager::add_special_sticker_set(const SpecialStickerSetType &type) {
  CHECK(!type.is_empty());
  auto &result_ptr = special_sticker_sets_[type];
  if (result_ptr == nullptr) {
    result_ptr = make_unique<SpecialStickerSet>();
  }
  auto &result = *result_ptr;
  if (result.type_.is_empty()) {
    result.type_ = type;
  } else {
    CHECK(result.type_ == type);
  }
  return result;
}

void StickersManager::init_special_sticker_set(SpecialStickerSet &sticker_set, int64 sticker_set_id, int64 access_hash,
                                               string name) {
  sticker_set.id_ = StickerSetId(sticker_set_id);
  sticker_set.access_hash_ = access_hash;
  sticker_set.short_name_ = std::move(name);
}

void StickersManager::load_special_sticker_set_info_from_binlog(SpecialStickerSet &sticker_set) {
  if (G()->use_sqlite_pmc()) {
    string sticker_set_string = G()->td_db()->get_binlog_pmc()->get(sticker_set.type_.type_);
    if (!sticker_set_string.empty()) {
      auto parts = full_split(sticker_set_string);
      if (parts.size() != 3) {
        LOG(ERROR) << "Can't parse " << sticker_set_string;
      } else {
        auto r_sticker_set_id = to_integer_safe<int64>(parts[0]);
        auto r_sticker_set_access_hash = to_integer_safe<int64>(parts[1]);
        auto sticker_set_name = parts[2];
        if (r_sticker_set_id.is_error() || r_sticker_set_access_hash.is_error() ||
            clean_username(sticker_set_name) != sticker_set_name || sticker_set_name.empty()) {
          LOG(ERROR) << "Can't parse " << sticker_set_string;
        } else {
          init_special_sticker_set(sticker_set, r_sticker_set_id.ok(), r_sticker_set_access_hash.ok(),
                                   std::move(sticker_set_name));
        }
      }
    }
  } else {
    G()->td_db()->get_binlog_pmc()->erase(sticker_set.type_.type_);
  }

  if (!sticker_set.id_.is_valid()) {
    return;
  }

  add_sticker_set(sticker_set.id_, sticker_set.access_hash_);
  auto cleaned_username = clean_username(sticker_set.short_name_);
  if (!cleaned_username.empty()) {
    short_name_to_sticker_set_id_.set(cleaned_username, sticker_set.id_);
  }
}

void StickersManager::load_special_sticker_set_by_type(SpecialStickerSetType type) {
  if (G()->close_flag()) {
    return;
  }

  auto &sticker_set = add_special_sticker_set(type);
  if (!sticker_set.is_being_loaded_) {
    return;
  }
  sticker_set.is_being_loaded_ = false;
  load_special_sticker_set(sticker_set);
}

void StickersManager::load_special_sticker_set(SpecialStickerSet &sticker_set) {
  CHECK(!td_->auth_manager_->is_bot() || sticker_set.type_ == SpecialStickerSetType::default_topic_icons());
  if (sticker_set.is_being_loaded_) {
    return;
  }
  sticker_set.is_being_loaded_ = true;
  LOG(INFO) << "Load " << sticker_set.type_.type_ << ' ' << sticker_set.id_;
  if (sticker_set.id_.is_valid()) {
    auto s = get_sticker_set(sticker_set.id_);
    CHECK(s != nullptr);
    if (s->was_loaded_) {
      reload_special_sticker_set(sticker_set, s->is_loaded_ ? s->hash_ : 0);
      return;
    }

    auto promise = PromiseCreator::lambda([actor_id = actor_id(this), type = sticker_set.type_](Result<Unit> &&result) {
      send_closure(actor_id, &StickersManager::on_load_special_sticker_set, type,
                   result.is_ok() ? Status::OK() : result.move_as_error());
    });
    load_sticker_sets({sticker_set.id_}, std::move(promise));
  } else {
    reload_special_sticker_set(sticker_set, 0);
  }
}

void StickersManager::reload_special_sticker_set_by_type(SpecialStickerSetType type, bool is_recursive) {
  if (G()->close_flag()) {
    return;
  }
  if (disable_animated_emojis_ &&
      (type == SpecialStickerSetType::animated_emoji() || type == SpecialStickerSetType::animated_emoji_click())) {
    return;
  }

  auto &sticker_set = add_special_sticker_set(type);
  if (sticker_set.is_being_reloaded_) {
    return;
  }

  if (!sticker_set.id_.is_valid()) {
    return reload_special_sticker_set(sticker_set, 0);
  }

  const auto *s = get_sticker_set(sticker_set.id_);
  if (s != nullptr && s->is_inited_ && s->was_loaded_) {
    return reload_special_sticker_set(sticker_set, s->is_loaded_ ? s->hash_ : 0);
  }
  if (!is_recursive) {
    auto promise = PromiseCreator::lambda([actor_id = actor_id(this), type = std::move(type)](Unit result) mutable {
      send_closure(actor_id, &StickersManager::reload_special_sticker_set_by_type, std::move(type), true);
    });
    return load_sticker_sets({sticker_set.id_}, std::move(promise));
  }

  reload_special_sticker_set(sticker_set, 0);
}

void StickersManager::reload_special_sticker_set(SpecialStickerSet &sticker_set, int32 hash) {
  if (sticker_set.is_being_reloaded_) {
    return;
  }
  sticker_set.is_being_reloaded_ = true;
  td_->create_handler<ReloadSpecialStickerSetQuery>()->send(sticker_set.id_, sticker_set.type_, hash);
}

void StickersManager::on_load_special_sticker_set(const SpecialStickerSetType &type, Status result) {
  if (G()->close_flag()) {
    return;
  }

  auto &special_sticker_set = add_special_sticker_set(type);
  special_sticker_set.is_being_reloaded_ = false;
  if (!special_sticker_set.is_being_loaded_) {
    return;
  }

  if (result.is_error()) {
    LOG(INFO) << "Failed to load special sticker set " << type.type_ << ": " << result.error();

    if (type == SpecialStickerSetType::premium_gifts()) {
      set_promises(pending_get_premium_gift_option_sticker_queries_);
    }

    // failed to load the special sticker set; repeat after some time
    create_actor<SleepActor>("RetryLoadSpecialStickerSetActor", Random::fast(300, 600),
                             PromiseCreator::lambda([actor_id = actor_id(this), type](Unit) mutable {
                               send_closure(actor_id, &StickersManager::load_special_sticker_set_by_type,
                                            std::move(type));
                             }))
        .release();
    return;
  }

  special_sticker_set.is_being_loaded_ = false;

  if (type == SpecialStickerSetType::animated_emoji()) {
    set_promises(pending_get_animated_emoji_queries_);
    try_update_animated_emoji_messages();
    return;
  }
  if (type == SpecialStickerSetType::premium_gifts()) {
    set_promises(pending_get_premium_gift_option_sticker_queries_);
    try_update_premium_gift_messages();
    return;
  }
  if (type == SpecialStickerSetType::generic_animations()) {
    set_promises(pending_get_generic_animations_queries_);
    return;
  }
  if (type == SpecialStickerSetType::default_statuses()) {
    set_promises(pending_get_default_statuses_queries_);
    return;
  }
  if (type == SpecialStickerSetType::default_channel_statuses()) {
    set_promises(pending_get_default_channel_statuses_queries_);
    return;
  }
  if (type == SpecialStickerSetType::default_topic_icons()) {
    set_promises(pending_get_default_topic_icons_queries_);
    return;
  }

  CHECK(special_sticker_set.id_.is_valid());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  CHECK(sticker_set != nullptr);
  CHECK(sticker_set->was_loaded_);

  if (type == SpecialStickerSetType::animated_emoji_click()) {
    auto pending_get_requests = std::move(pending_get_animated_emoji_click_stickers_);
    reset_to_empty(pending_get_animated_emoji_click_stickers_);
    for (auto &pending_request : pending_get_requests) {
      choose_animated_emoji_click_sticker(sticker_set, std::move(pending_request.message_text_),
                                          pending_request.message_full_id_, pending_request.start_time_,
                                          std::move(pending_request.promise_));
    }
    auto pending_click_requests = std::move(pending_on_animated_emoji_message_clicked_);
    reset_to_empty(pending_on_animated_emoji_message_clicked_);
    for (auto &pending_request : pending_click_requests) {
      schedule_update_animated_emoji_clicked(sticker_set, pending_request.emoji_, pending_request.message_full_id_,
                                             std::move(pending_request.clicks_));
    }
    return;
  }

  auto emoji = type.get_dice_emoji();
  CHECK(!emoji.empty());

  {
    auto it = dice_messages_.find(emoji);
    if (it != dice_messages_.end()) {
      vector<MessageFullId> message_full_ids;
      it->second.foreach([&](const MessageFullId &message_full_id) { message_full_ids.push_back(message_full_id); });
      CHECK(!message_full_ids.empty());
      for (const auto &message_full_id : message_full_ids) {
        td_->messages_manager_->on_external_update_message_content(message_full_id, "on_load_special_sticker_set");
      }
    }
  }
  {
    auto it = dice_quick_reply_messages_.find(emoji);
    if (it != dice_quick_reply_messages_.end()) {
      vector<QuickReplyMessageFullId> message_full_ids;
      it->second.foreach(
          [&](const QuickReplyMessageFullId &message_full_id) { message_full_ids.push_back(message_full_id); });
      CHECK(!message_full_ids.empty());
      for (const auto &message_full_id : message_full_ids) {
        td_->quick_reply_manager_->on_external_update_message_content(message_full_id, "on_load_special_sticker_set");
      }
    }
  }
}

void StickersManager::tear_down() {
  parent_.reset();
}

StickerType StickersManager::get_sticker_type(FileId file_id) const {
  const auto *sticker = get_sticker(file_id);
  CHECK(sticker != nullptr);
  return sticker->type_;
}

StickerFormat StickersManager::get_sticker_format(FileId file_id) const {
  const auto *sticker = get_sticker(file_id);
  CHECK(sticker != nullptr);
  return sticker->format_;
}

bool StickersManager::is_premium_custom_emoji(CustomEmojiId custom_emoji_id, bool default_result) const {
  auto sticker_id = custom_emoji_to_sticker_id_.get(custom_emoji_id);
  if (!sticker_id.is_valid()) {
    return default_result;
  }
  const Sticker *s = get_sticker(sticker_id);
  CHECK(s != nullptr);
  return s->is_premium_;
}

bool StickersManager::have_sticker(StickerSetId sticker_set_id, int64 sticker_id) {
  auto sticker_set = get_sticker_set(sticker_set_id);
  if (sticker_set == nullptr) {
    return false;
  }
  for (auto file_id : sticker_set->sticker_ids_) {
    if (get_sticker_id(file_id) == sticker_id) {
      return true;
    }
  }
  return false;
}

bool StickersManager::have_custom_emoji(CustomEmojiId custom_emoji_id) {
  return custom_emoji_to_sticker_id_.count(custom_emoji_id) != 0;
}

int64 StickersManager::get_sticker_id(FileId sticker_id) const {
  auto file_view = td_->file_manager_->get_file_view(sticker_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (file_view.is_encrypted() || full_remote_location == nullptr || !full_remote_location->is_document()) {
    return 0;
  }
  return full_remote_location->get_id();
}

CustomEmojiId StickersManager::get_custom_emoji_id(FileId sticker_id) const {
  return CustomEmojiId(get_sticker_id(sticker_id));
}

td_api::object_ptr<td_api::outline> StickersManager::get_sticker_outline_object(FileId file_id, bool for_animated_emoji,
                                                                                bool for_clicked_animated_emoji) const {
  const auto *sticker = get_sticker(file_id);
  if (sticker == nullptr || sticker->minithumbnail_.empty()) {
    return nullptr;
  }

  int64 document_id = 0;
  auto file_view = td_->file_manager_->get_file_view(sticker->file_id_);
  if (!file_view.is_encrypted()) {
    const auto *full_remote_location = file_view.get_full_remote_location();
    if (full_remote_location != nullptr && full_remote_location->is_document()) {
      document_id = full_remote_location->get_id();
    }
  }
  double zoom = 1.0;
  if ((is_sticker_format_vector(sticker->format_) || sticker->type_ == StickerType::CustomEmoji) &&
      (for_animated_emoji || for_clicked_animated_emoji)) {
    if (sticker->type_ == StickerType::CustomEmoji &&
        max(sticker->dimensions_.width, sticker->dimensions_.height) <= 100) {
      zoom *= 5.12;
    }
    if (for_clicked_animated_emoji) {
      zoom *= 3;
    }
  }
  return get_outline_object(sticker->minithumbnail_, zoom, PSLICE() << document_id << " in " << sticker->set_id_);
}

tl_object_ptr<td_api::sticker> StickersManager::get_sticker_object(FileId file_id, bool for_animated_emoji,
                                                                   bool for_clicked_animated_emoji) const {
  if (!file_id.is_valid()) {
    return nullptr;
  }

  const auto *sticker = get_sticker(file_id);
  LOG_CHECK(sticker != nullptr) << file_id << ' ' << stickers_.calc_size();
  const PhotoSize &thumbnail = sticker->m_thumbnail_.file_id.is_valid() ? sticker->m_thumbnail_ : sticker->s_thumbnail_;
  auto thumbnail_format = PhotoFormat::Webp;
  if (!sticker->set_id_.is_valid()) {
    auto file_view = td_->file_manager_->get_file_view(sticker->file_id_);
    if (file_view.is_encrypted()) {
      // uploaded to secret chats stickers have JPEG thumbnail instead of server-generated WEBP
      thumbnail_format = PhotoFormat::Jpeg;
    } else {
      if (thumbnail.file_id.is_valid()) {
        auto thumbnail_file_view = td_->file_manager_->get_file_view(thumbnail.file_id);
        if (ends_with(thumbnail_file_view.suggested_path(), ".jpg")) {
          thumbnail_format = PhotoFormat::Jpeg;
        }
      }
    }
  }
  auto thumbnail_object = get_thumbnail_object(td_->file_manager_.get(), thumbnail, thumbnail_format);
  int32 width = sticker->dimensions_.width;
  int32 height = sticker->dimensions_.height;
  double zoom = 1.0;
  if ((is_sticker_format_vector(sticker->format_) || sticker->type_ == StickerType::CustomEmoji) &&
      (for_animated_emoji || for_clicked_animated_emoji)) {
    if (sticker->type_ == StickerType::CustomEmoji && max(width, height) <= 100) {
      zoom *= 5.12;
    }
    width = static_cast<int32>(width * zoom + 0.5);
    height = static_cast<int32>(height * zoom + 0.5);
    if (for_clicked_animated_emoji) {
      zoom *= 3;
      width *= 3;
      height *= 3;
    }
  }
  auto full_type = [&]() -> td_api::object_ptr<td_api::StickerFullType> {
    switch (sticker->type_) {
      case StickerType::Regular: {
        auto premium_animation_object = sticker->premium_animation_file_id_.is_valid()
                                            ? td_->file_manager_->get_file_object(sticker->premium_animation_file_id_)
                                            : nullptr;
        return td_api::make_object<td_api::stickerFullTypeRegular>(std::move(premium_animation_object));
      }
      case StickerType::Mask:
        return td_api::make_object<td_api::stickerFullTypeMask>(sticker->mask_position_.get_mask_position_object());
      case StickerType::CustomEmoji:
        return td_api::make_object<td_api::stickerFullTypeCustomEmoji>(get_custom_emoji_id(sticker->file_id_).get(),
                                                                       sticker->has_text_color_);
      default:
        UNREACHABLE();
        return nullptr;
    }
  }();
  int64 sticker_id = 0;
  if (sticker->set_id_.is_valid()) {
    sticker_id = get_sticker_id(file_id);
  }
  return td_api::make_object<td_api::sticker>(
      sticker_id, sticker->set_id_.get(), width, height, sticker->alt_, get_sticker_format_object(sticker->format_),
      std::move(full_type), std::move(thumbnail_object), td_->file_manager_->get_file_object(file_id));
}

tl_object_ptr<td_api::stickers> StickersManager::get_stickers_object(const vector<FileId> &sticker_ids) const {
  return td_api::make_object<td_api::stickers>(
      transform(sticker_ids, [&](FileId sticker_id) { return get_sticker_object(sticker_id); }));
}

td_api::object_ptr<td_api::emojis> StickersManager::get_sticker_emojis_object(const vector<FileId> &sticker_ids,
                                                                              bool return_only_main_emoji) {
  auto emojis = td_api::make_object<td_api::emojis>();
  FlatHashSet<string> added_emojis;
  auto add_emoji = [&](const string &emoji) {
    if (!emoji.empty() && added_emojis.insert(emoji).second) {
      emojis->emojis_.push_back(emoji);
    }
  };
  for (auto sticker_id : sticker_ids) {
    auto sticker = get_sticker(sticker_id);
    CHECK(sticker != nullptr);
    add_emoji(sticker->alt_);
    if (!return_only_main_emoji && sticker->set_id_.is_valid()) {
      const StickerSet *sticker_set = get_sticker_set(sticker->set_id_);
      if (sticker_set != nullptr) {
        auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
        if (it != sticker_set->sticker_emojis_map_.end()) {
          for (auto emoji : it->second) {
            add_emoji(emoji);
          }
        }
      }
    }
  }
  return emojis;
}

tl_object_ptr<td_api::DiceStickers> StickersManager::get_dice_stickers_object(const string &emoji, int32 value) const {
  if (td_->auth_manager_->is_bot()) {
    return nullptr;
  }
  if (!td::contains(dice_emojis_, emoji)) {
    return nullptr;
  }

  auto it = special_sticker_sets_.find(SpecialStickerSetType::animated_dice(emoji));
  if (it == special_sticker_sets_.end()) {
    return nullptr;
  }

  auto sticker_set_id = it->second->id_;
  if (!sticker_set_id.is_valid()) {
    return nullptr;
  }

  auto sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  if (!sticker_set->was_loaded_) {
    return nullptr;
  }

  auto get_sticker = [&](int32 value) {
    return get_sticker_object(sticker_set->sticker_ids_[value], true);
  };

  if (emoji == "🎰") {
    if (sticker_set->sticker_ids_.size() < 21 || value < 0 || value > 64) {
      return nullptr;
    }

    int32 background_id = value == 1 || value == 22 || value == 43 || value == 64 ? 1 : 0;
    int32 lever_id = 2;
    int32 left_reel_id = value == 64 ? 3 : 8;
    int32 center_reel_id = value == 64 ? 9 : 14;
    int32 right_reel_id = value == 64 ? 15 : 20;
    if (value != 0 && value != 64) {
      left_reel_id = 4 + (value % 4);
      center_reel_id = 10 + ((value + 3) / 4 % 4);
      right_reel_id = 16 + ((value + 15) / 16 % 4);
    }
    return td_api::make_object<td_api::diceStickersSlotMachine>(get_sticker(background_id), get_sticker(lever_id),
                                                                get_sticker(left_reel_id), get_sticker(center_reel_id),
                                                                get_sticker(right_reel_id));
  }

  if (value >= 0 && value < static_cast<int32>(sticker_set->sticker_ids_.size())) {
    return td_api::make_object<td_api::diceStickersRegular>(get_sticker(value));
  }
  return nullptr;
}

int32 StickersManager::get_dice_success_animation_frame_number(const string &emoji, int32 value) const {
  if (td_->auth_manager_->is_bot()) {
    return std::numeric_limits<int32>::max();
  }
  if (value == 0 || !td::contains(dice_emojis_, emoji)) {
    return std::numeric_limits<int32>::max();
  }
  auto pos = static_cast<size_t>(std::find(dice_emojis_.begin(), dice_emojis_.end(), emoji) - dice_emojis_.begin());
  if (pos >= dice_success_values_.size()) {
    return std::numeric_limits<int32>::max();
  }

  auto &result = dice_success_values_[pos];
  return result.first == value ? result.second : std::numeric_limits<int32>::max();
}

PhotoFormat StickersManager::get_sticker_set_thumbnail_format(const StickerSet *sticker_set) const {
  if (sticker_set->thumbnail_document_id_ != 0 && sticker_set->sticker_type_ == StickerType::CustomEmoji) {
    for (auto sticker_id : sticker_set->sticker_ids_) {
      auto file_view = td_->file_manager_->get_file_view(sticker_id);
      const auto *full_remote_location = file_view.get_full_remote_location();
      if (full_remote_location != nullptr && !full_remote_location->is_web() &&
          full_remote_location->get_id() == sticker_set->thumbnail_document_id_) {
        const Sticker *s = get_sticker(sticker_id);
        CHECK(s != nullptr);
        return get_sticker_format_photo_format(s->format_);
      }
    }
  }
  auto type = sticker_set->thumbnail_.type;
  if (type == 's') {
    return PhotoFormat::Webp;
  }
  if (type == 'v') {
    return PhotoFormat::Webm;
  }
  if (type == 'a') {
    return PhotoFormat::Tgs;
  }
  return PhotoFormat::Tgs;
}

double StickersManager::get_sticker_set_minithumbnail_zoom(const StickerSet *sticker_set) const {
  if (get_sticker_set_thumbnail_format(sticker_set) == PhotoFormat::Tgs) {
    return 100.0 / 512.0;
  }
  return 1.0;
}

td_api::object_ptr<td_api::thumbnail> StickersManager::get_sticker_set_thumbnail_object(
    const StickerSet *sticker_set) const {
  CHECK(sticker_set != nullptr);
  if (sticker_set->thumbnail_document_id_ != 0 && sticker_set->sticker_type_ == StickerType::CustomEmoji) {
    for (auto sticker_id : sticker_set->sticker_ids_) {
      auto file_view = td_->file_manager_->get_file_view(sticker_id);
      const auto *full_remote_location = file_view.get_full_remote_location();
      if (full_remote_location != nullptr && !full_remote_location->is_web() &&
          full_remote_location->get_id() == sticker_set->thumbnail_document_id_) {
        const Sticker *s = get_sticker(sticker_id);
        auto thumbnail_format = get_sticker_format_photo_format(s->format_);
        PhotoSize thumbnail;
        thumbnail.type = PhotoSizeType('t');
        thumbnail.size = static_cast<int32>(file_view.size());
        thumbnail.dimensions = s->dimensions_;
        thumbnail.file_id = s->file_id_;
        return get_thumbnail_object(td_->file_manager_.get(), thumbnail, thumbnail_format);
      }
    }
  }
  auto thumbnail_format = get_sticker_set_thumbnail_format(sticker_set);
  return get_thumbnail_object(td_->file_manager_.get(), sticker_set->thumbnail_, thumbnail_format);
}

tl_object_ptr<td_api::stickerSet> StickersManager::get_sticker_set_object(StickerSetId sticker_set_id) const {
  const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  CHECK(sticker_set->was_loaded_);
  sticker_set->was_update_sent_ = true;

  std::vector<tl_object_ptr<td_api::sticker>> stickers;
  std::vector<tl_object_ptr<td_api::emojis>> emojis;
  for (auto sticker_id : sticker_set->sticker_ids_) {
    stickers.push_back(get_sticker_object(sticker_id));

    vector<string> sticker_emojis;
    auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
    if (it != sticker_set->sticker_emojis_map_.end()) {
      sticker_emojis = it->second;
    }
    emojis.push_back(make_tl_object<td_api::emojis>(std::move(sticker_emojis)));
  }
  return td_api::make_object<td_api::stickerSet>(
      sticker_set->id_.get(), sticker_set->title_, sticker_set->short_name_,
      get_sticker_set_thumbnail_object(sticker_set),
      get_outline_object(sticker_set->minithumbnail_, get_sticker_set_minithumbnail_zoom(sticker_set),
                         PSLICE() << sticker_set->id_),
      sticker_set->is_created_, sticker_set->is_installed_ && !sticker_set->is_archived_, sticker_set->is_archived_,
      sticker_set->is_official_, get_sticker_type_object(sticker_set->sticker_type_), sticker_set->has_text_color_,
      sticker_set->channel_emoji_status_, sticker_set->is_viewed_, std::move(stickers), std::move(emojis));
}

tl_object_ptr<td_api::stickerSets> StickersManager::get_sticker_sets_object(int32 total_count,
                                                                            const vector<StickerSetId> &sticker_set_ids,
                                                                            size_t covers_limit) const {
  vector<tl_object_ptr<td_api::stickerSetInfo>> result;
  result.reserve(sticker_set_ids.size());
  for (auto sticker_set_id : sticker_set_ids) {
    auto sticker_set_info = get_sticker_set_info_object(sticker_set_id, covers_limit, false);
    if (sticker_set_info->size_ != 0) {
      result.push_back(std::move(sticker_set_info));
    }
  }

  auto result_size = narrow_cast<int32>(result.size());
  if (total_count < result_size) {
    if (total_count != -1) {
      LOG(ERROR) << "Have total_count = " << total_count << ", but there are " << result_size << " results";
    }
    total_count = result_size;
  }
  return make_tl_object<td_api::stickerSets>(total_count, std::move(result));
}

tl_object_ptr<td_api::stickerSetInfo> StickersManager::get_sticker_set_info_object(StickerSetId sticker_set_id,
                                                                                   size_t covers_limit,
                                                                                   bool prefer_premium) const {
  const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  CHECK(sticker_set->is_inited_);
  sticker_set->was_update_sent_ = true;

  vector<td_api::object_ptr<td_api::sticker>> stickers;
  if (prefer_premium) {
    CHECK(!td_->auth_manager_->is_bot());
    vector<FileId> regular_sticker_ids;
    vector<FileId> premium_sticker_ids;
    std::tie(regular_sticker_ids, premium_sticker_ids) = split_stickers_by_premium(sticker_set);
    auto is_premium = td_->option_manager_->get_option_boolean("is_premium");
    size_t max_premium_stickers = is_premium ? covers_limit : 1;
    if (premium_sticker_ids.size() > max_premium_stickers) {
      premium_sticker_ids.resize(max_premium_stickers);
    }
    CHECK(premium_sticker_ids.size() <= covers_limit);
    if (regular_sticker_ids.size() > covers_limit - premium_sticker_ids.size()) {
      regular_sticker_ids.resize(covers_limit - premium_sticker_ids.size());
    }
    if (!is_premium) {
      std::swap(premium_sticker_ids, regular_sticker_ids);
    }

    append(premium_sticker_ids, regular_sticker_ids);
    for (auto sticker_id : premium_sticker_ids) {
      stickers.push_back(get_sticker_object(sticker_id));
      if (stickers.size() >= covers_limit) {
        break;
      }
    }
  } else {
    for (auto sticker_id : sticker_set->sticker_ids_) {
      stickers.push_back(get_sticker_object(sticker_id));
      if (stickers.size() >= covers_limit) {
        break;
      }
    }
  }

  auto actual_count = narrow_cast<int32>(sticker_set->sticker_ids_.size());
  return make_tl_object<td_api::stickerSetInfo>(
      sticker_set->id_.get(), sticker_set->title_, sticker_set->short_name_,
      get_sticker_set_thumbnail_object(sticker_set),
      get_outline_object(sticker_set->minithumbnail_, get_sticker_set_minithumbnail_zoom(sticker_set),
                         PSLICE() << sticker_set->id_),
      sticker_set->is_created_, sticker_set->is_installed_ && !sticker_set->is_archived_, sticker_set->is_archived_,
      sticker_set->is_official_, get_sticker_type_object(sticker_set->sticker_type_), sticker_set->has_text_color_,
      sticker_set->channel_emoji_status_, sticker_set->is_viewed_,
      sticker_set->was_loaded_ ? actual_count : max(actual_count, sticker_set->sticker_count_), std::move(stickers));
}

td_api::object_ptr<td_api::sticker> StickersManager::get_premium_gift_sticker_object(int32 month_count,
                                                                                     int64 star_count) {
  if (month_count == 0) {
    month_count = StarManager::get_months_by_star_count(star_count);
  }
  auto it = premium_gift_messages_.find(month_count);
  if (it == premium_gift_messages_.end()) {
    return get_sticker_object(get_premium_gift_option_sticker_id(month_count));
  } else {
    return get_sticker_object(it->second->sticker_id_);
  }
}

const StickersManager::StickerSet *StickersManager::get_premium_gift_sticker_set() {
  if (td_->auth_manager_->is_bot()) {
    return nullptr;
  }
  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::premium_gifts());
  if (!special_sticker_set.id_.is_valid()) {
    load_special_sticker_set(special_sticker_set);
    return nullptr;
  }

  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  CHECK(sticker_set != nullptr);
  if (!sticker_set->was_loaded_) {
    load_special_sticker_set(special_sticker_set);
    return nullptr;
  }

  return sticker_set;
}

FileId StickersManager::get_premium_gift_option_sticker_id(const StickerSet *sticker_set, int32 month_count) {
  if (sticker_set == nullptr || sticker_set->sticker_ids_.empty() || month_count <= 0) {
    return {};
  }

  int32 number = [month_count] {
    switch (month_count) {
      case 1:
        return 1;
      case 3:
        return 2;
      case 6:
        return 3;
      case 12:
        return 4;
      case 24:
        return 5;
      default:
        return -1;
    }
  }();

  for (auto sticker_id : sticker_set->sticker_ids_) {
    auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
    if (it != sticker_set->sticker_emojis_map_.end()) {
      for (auto &emoji : it->second) {
        if (get_emoji_number(emoji) == number) {
          return sticker_id;
        }
      }
    }
  }

  // there is no match; return the first sticker
  return sticker_set->sticker_ids_[0];
}

FileId StickersManager::get_premium_gift_option_sticker_id(int32 month_count) {
  return get_premium_gift_option_sticker_id(get_premium_gift_sticker_set(), month_count);
}

void StickersManager::load_premium_gift_sticker_set(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot() || get_premium_gift_sticker_set() != nullptr) {
    return promise.set_value(Unit());
  }
  pending_get_premium_gift_option_sticker_queries_.push_back(std::move(promise));
}

void StickersManager::load_premium_gift_sticker(int32 month_count, int64 star_count,
                                                Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  if (get_premium_gift_sticker_set() != nullptr) {
    return return_premium_gift_sticker(month_count, star_count, std::move(promise));
  }
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), month_count, star_count,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      return promise.set_error(result.move_as_error());
    }
    send_closure(actor_id, &StickersManager::return_premium_gift_sticker, month_count, star_count, std::move(promise));
  });
  pending_get_premium_gift_option_sticker_queries_.push_back(std::move(query_promise));
}

void StickersManager::return_premium_gift_sticker(int32 month_count, int64 star_count,
                                                  Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  promise.set_value(get_premium_gift_sticker_object(month_count, star_count));
}

const StickersManager::StickerSet *StickersManager::get_animated_emoji_sticker_set() {
  if (td_->auth_manager_->is_bot() || disable_animated_emojis_) {
    return nullptr;
  }
  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji());
  if (!special_sticker_set.id_.is_valid()) {
    load_special_sticker_set(special_sticker_set);
    return nullptr;
  }

  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  CHECK(sticker_set != nullptr);
  if (!sticker_set->was_loaded_) {
    load_special_sticker_set(special_sticker_set);
    return nullptr;
  }

  return sticker_set;
}

std::pair<FileId, int> StickersManager::get_animated_emoji_sticker(const StickerSet *sticker_set, const string &emoji) {
  if (sticker_set == nullptr) {
    return {};
  }

  auto emoji_without_modifiers = remove_emoji_modifiers(emoji);
  auto it = sticker_set->emoji_stickers_map_.find(emoji_without_modifiers);
  if (it == sticker_set->emoji_stickers_map_.end()) {
    return {};
  }

  auto emoji_without_selectors = remove_emoji_selectors(emoji);
  // trying to find full emoji match
  for (const auto &sticker_id : it->second) {
    auto emoji_it = sticker_set->sticker_emojis_map_.find(sticker_id);
    CHECK(emoji_it != sticker_set->sticker_emojis_map_.end());
    for (auto &sticker_emoji : emoji_it->second) {
      if (remove_emoji_selectors(sticker_emoji) == emoji_without_selectors) {
        return {sticker_id, 0};
      }
    }
  }

  // trying to find match without Fitzpatrick modifiers
  int modifier_id = get_fitzpatrick_modifier(emoji_without_selectors);
  if (modifier_id > 0) {
    for (const auto &sticker_id : it->second) {
      auto emoji_it = sticker_set->sticker_emojis_map_.find(sticker_id);
      CHECK(emoji_it != sticker_set->sticker_emojis_map_.end());
      for (auto &sticker_emoji : emoji_it->second) {
        if (remove_emoji_selectors(sticker_emoji) == Slice(emoji_without_selectors).remove_suffix(4)) {
          return {sticker_id, modifier_id};
        }
      }
    }
  }

  // there is no match
  return {};
}

std::pair<FileId, int> StickersManager::get_animated_emoji_sticker(const string &emoji) {
  return get_animated_emoji_sticker(get_animated_emoji_sticker_set(), emoji);
}

FileId StickersManager::get_animated_emoji_sound_file_id(const string &emoji) const {
  auto it = emoji_sounds_.find(remove_fitzpatrick_modifier(emoji).str());
  if (it == emoji_sounds_.end()) {
    return {};
  }
  return it->second;
}

FileId StickersManager::get_custom_animated_emoji_sticker_id(CustomEmojiId custom_emoji_id) const {
  if (disable_animated_emojis_) {
    return {};
  }

  return custom_emoji_to_sticker_id_.get(custom_emoji_id);
}

td_api::object_ptr<td_api::animatedEmoji> StickersManager::get_animated_emoji_object(const string &emoji,
                                                                                     CustomEmojiId custom_emoji_id) {
  if (td_->auth_manager_->is_bot() || disable_animated_emojis_) {
    return nullptr;
  }

  if (custom_emoji_id.is_valid()) {
    auto it = custom_emoji_messages_.find(custom_emoji_id);
    auto sticker_id = it == custom_emoji_messages_.end() ? get_custom_animated_emoji_sticker_id(custom_emoji_id)
                                                         : it->second->sticker_id_;
    auto sticker = get_sticker_object(sticker_id, true);
    auto default_custom_emoji_dimension = static_cast<int32>(512 * animated_emoji_zoom_ + 0.5);
    auto sticker_width = sticker == nullptr ? default_custom_emoji_dimension : sticker->width_;
    auto sticker_height = sticker == nullptr ? default_custom_emoji_dimension : sticker->height_;
    return td_api::make_object<td_api::animatedEmoji>(std::move(sticker), sticker_width, sticker_height, 0, nullptr);
  }

  auto it = emoji_messages_.find(emoji);
  if (it == emoji_messages_.end()) {
    return get_animated_emoji_object(get_animated_emoji_sticker(emoji), get_animated_emoji_sound_file_id(emoji));
  } else {
    return get_animated_emoji_object(it->second->animated_emoji_sticker_, it->second->sound_file_id_);
  }
}

td_api::object_ptr<td_api::animatedEmoji> StickersManager::get_animated_emoji_object(
    std::pair<FileId, int> animated_sticker, FileId sound_file_id) const {
  if (!animated_sticker.first.is_valid()) {
    return nullptr;
  }
  auto sticker = get_sticker_object(animated_sticker.first, true);
  CHECK(sticker != nullptr);
  auto sticker_width = sticker->width_;
  auto sticker_height = sticker->height_;
  return td_api::make_object<td_api::animatedEmoji>(
      std::move(sticker), sticker_width, sticker_height, animated_sticker.second,
      sound_file_id.is_valid() ? td_->file_manager_->get_file_object(sound_file_id) : nullptr);
}

tl_object_ptr<telegram_api::InputStickerSet> StickersManager::get_input_sticker_set(StickerSetId sticker_set_id) const {
  auto sticker_set = get_sticker_set(sticker_set_id);
  if (sticker_set == nullptr) {
    return nullptr;
  }

  return get_input_sticker_set(sticker_set);
}

class StickersManager::CustomEmojiLogEvent {
 public:
  FileId sticker_id;

  CustomEmojiLogEvent() = default;

  explicit CustomEmojiLogEvent(FileId sticker_id) : sticker_id(sticker_id) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    END_STORE_FLAGS();
    StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
    stickers_manager->store_sticker(sticker_id, false, storer, "CustomEmoji");
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    END_PARSE_FLAGS();
    StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
    sticker_id = stickers_manager->parse_sticker(false, parser);
  }
};

string StickersManager::get_custom_emoji_database_key(CustomEmojiId custom_emoji_id) {
  return PSTRING() << "emoji" << custom_emoji_id.get();
}

FileId StickersManager::on_get_sticker(unique_ptr<Sticker> new_sticker, bool replace) {
  auto file_id = new_sticker->file_id_;
  CHECK(file_id.is_valid());
  CustomEmojiId updated_custom_emoji_id;
  auto *s = get_sticker(file_id);
  if (s == nullptr) {
    s = new_sticker.get();
    stickers_.set(file_id, std::move(new_sticker));
  } else if (replace) {
    CHECK(s->file_id_ == file_id);

    if (s->type_ == StickerType::CustomEmoji) {
      auto custom_emoji_id = get_custom_emoji_id(file_id);
      if (custom_emoji_id.is_valid() && custom_emoji_to_sticker_id_.get(custom_emoji_id) == file_id) {
        custom_emoji_to_sticker_id_.erase(custom_emoji_id);
        updated_custom_emoji_id = custom_emoji_id;
      }
    }

    bool is_changed = false;
    if (s->dimensions_ != new_sticker->dimensions_ && new_sticker->dimensions_.width != 0) {
      LOG(DEBUG) << "Sticker " << file_id << " dimensions have changed";
      s->dimensions_ = new_sticker->dimensions_;
      is_changed = true;
    }
    if (s->set_id_ != new_sticker->set_id_ && new_sticker->set_id_.is_valid()) {
      LOG_IF(ERROR, s->set_id_.is_valid()) << "Sticker " << file_id << " set_id has changed";
      s->set_id_ = new_sticker->set_id_;
      is_changed = true;
    }
    if (s->alt_ != new_sticker->alt_ && !new_sticker->alt_.empty()) {
      LOG(DEBUG) << "Sticker " << file_id << " emoji has changed";
      s->alt_ = std::move(new_sticker->alt_);
      is_changed = true;
    }
    if (s->minithumbnail_ != new_sticker->minithumbnail_) {
      LOG(DEBUG) << "Sticker " << file_id << " minithumbnail has changed";
      s->minithumbnail_ = std::move(new_sticker->minithumbnail_);
      is_changed = true;
    }
    if (s->s_thumbnail_ != new_sticker->s_thumbnail_ && new_sticker->s_thumbnail_.file_id.is_valid()) {
      LOG_IF(INFO, s->s_thumbnail_.file_id.is_valid()) << "Sticker " << file_id << " s thumbnail has changed from "
                                                       << s->s_thumbnail_ << " to " << new_sticker->s_thumbnail_;
      s->s_thumbnail_ = std::move(new_sticker->s_thumbnail_);
      is_changed = true;
    }
    if (s->m_thumbnail_ != new_sticker->m_thumbnail_ && new_sticker->m_thumbnail_.file_id.is_valid()) {
      LOG_IF(INFO, s->m_thumbnail_.file_id.is_valid()) << "Sticker " << file_id << " m thumbnail has changed from "
                                                       << s->m_thumbnail_ << " to " << new_sticker->m_thumbnail_;
      s->m_thumbnail_ = std::move(new_sticker->m_thumbnail_);
      is_changed = true;
    }
    if (s->is_premium_ != new_sticker->is_premium_) {
      s->is_premium_ = new_sticker->is_premium_;
      is_changed = true;
    }
    if (s->has_text_color_ != new_sticker->has_text_color_) {
      s->has_text_color_ = new_sticker->has_text_color_;
      is_changed = true;
    }
    if (s->premium_animation_file_id_ != new_sticker->premium_animation_file_id_ &&
        new_sticker->premium_animation_file_id_.is_valid()) {
      s->premium_animation_file_id_ = new_sticker->premium_animation_file_id_;
      is_changed = true;
    }
    if (s->format_ != new_sticker->format_ && new_sticker->format_ != StickerFormat::Unknown) {
      s->format_ = new_sticker->format_;
      is_changed = true;
    }
    if (s->type_ != new_sticker->type_ && new_sticker->type_ != StickerType::Regular) {
      s->type_ = new_sticker->type_;
      is_changed = true;
    }
    if (s->mask_position_ != new_sticker->mask_position_) {
      s->mask_position_ = new_sticker->mask_position_;
      is_changed = true;
    }
    if (s->emoji_receive_date_ < new_sticker->emoji_receive_date_) {
      LOG(DEBUG) << "Update custom emoji file " << file_id << " receive date";
      s->emoji_receive_date_ = new_sticker->emoji_receive_date_;
      s->is_from_database_ = false;
    }

    if (is_changed) {
      s->is_from_database_ = false;
    }
  }

  if (s->type_ == StickerType::CustomEmoji) {
    s->is_being_reloaded_ = false;
    auto custom_emoji_id = get_custom_emoji_id(file_id);
    if (custom_emoji_id.is_valid()) {
      custom_emoji_to_sticker_id_.set(custom_emoji_id, file_id);
      CHECK(updated_custom_emoji_id == custom_emoji_id || !updated_custom_emoji_id.is_valid());
      updated_custom_emoji_id = custom_emoji_id;
      if (!s->is_from_database_ && G()->use_sqlite_pmc() && !G()->close_flag()) {
        LOG(INFO) << "Save " << custom_emoji_id << " to database";
        s->is_from_database_ = true;

        CustomEmojiLogEvent log_event(file_id);
        G()->td_db()->get_sqlite_pmc()->set(get_custom_emoji_database_key(custom_emoji_id),
                                            log_event_store(log_event).as_slice().str(), Auto());
      }
    }
  }
  if (updated_custom_emoji_id.is_valid()) {
    try_update_custom_emoji_messages(updated_custom_emoji_id);
  }
  return file_id;
}

bool StickersManager::has_webp_thumbnail(const vector<tl_object_ptr<telegram_api::PhotoSize>> &thumbnails) {
  // server tries to always replace user-provided thumbnail with server-side WEBP thumbnail
  // but there can be some old sticker documents or some big stickers
  for (auto &size : thumbnails) {
    switch (size->get_id()) {
      case telegram_api::photoStrippedSize::ID:
      case telegram_api::photoSizeProgressive::ID:
        // WEBP thumbnail can't have stripped size or be progressive
        return false;
      default:
        break;
    }
  }
  return true;
}

std::pair<int64, FileId> StickersManager::on_get_sticker_document(tl_object_ptr<telegram_api::Document> &&document_ptr,
                                                                  StickerFormat expected_format, const char *source) {
  if (document_ptr == nullptr) {
    return {};
  }
  int32 document_constructor_id = document_ptr->get_id();
  if (document_constructor_id == telegram_api::documentEmpty::ID) {
    LOG(ERROR) << "Empty sticker document received from " << source;
    return {};
  }
  CHECK(document_constructor_id == telegram_api::document::ID);
  auto document = move_tl_object_as<telegram_api::document>(document_ptr);

  if (!DcId::is_valid(document->dc_id_)) {
    LOG(ERROR) << "Wrong dc_id = " << document->dc_id_ << " from " << source << " in document " << to_string(document);
    return {};
  }
  auto dc_id = DcId::internal(document->dc_id_);

  Dimensions dimensions;
  tl_object_ptr<telegram_api::documentAttributeSticker> sticker;
  tl_object_ptr<telegram_api::documentAttributeCustomEmoji> custom_emoji;
  for (auto &attribute : document->attributes_) {
    switch (attribute->get_id()) {
      case telegram_api::documentAttributeVideo::ID: {
        auto video = move_tl_object_as<telegram_api::documentAttributeVideo>(attribute);
        dimensions = get_dimensions(video->w_, video->h_, "sticker documentAttributeVideo");
        break;
      }
      case telegram_api::documentAttributeImageSize::ID: {
        auto image_size = move_tl_object_as<telegram_api::documentAttributeImageSize>(attribute);
        dimensions = get_dimensions(image_size->w_, image_size->h_, "sticker documentAttributeImageSize");
        break;
      }
      case telegram_api::documentAttributeSticker::ID:
        sticker = move_tl_object_as<telegram_api::documentAttributeSticker>(attribute);
        break;
      case telegram_api::documentAttributeCustomEmoji::ID:
        custom_emoji = move_tl_object_as<telegram_api::documentAttributeCustomEmoji>(attribute);
        break;
      default:
        continue;
    }
  }
  if (sticker == nullptr && custom_emoji == nullptr) {
    if (document->mime_type_ != "application/x-bad-tgsticker") {
      LOG(ERROR) << "Have no attributeSticker from " << source << " in " << to_string(document);
    }
    return {};
  }

  auto format = get_sticker_format_by_mime_type(document->mime_type_);
  if (format == StickerFormat::Unknown || (expected_format != StickerFormat::Unknown && format != expected_format)) {
    LOG(ERROR) << "Expected sticker of the type " << expected_format << ", but received of the type " << format
               << " from " << source;
    return {};
  }
  int64 document_id = document->id_;
  FileId sticker_id =
      td_->file_manager_->register_remote(FullRemoteFileLocation(FileType::Sticker, document_id, document->access_hash_,
                                                                 dc_id, document->file_reference_.as_slice().str()),
                                          FileLocationSource::FromServer, DialogId(), document->size_, 0,
                                          PSTRING() << document_id << get_sticker_format_extension(format));

  PhotoSize thumbnail;
  string minithumbnail;
  auto thumbnail_format = has_webp_thumbnail(document->thumbs_) ? PhotoFormat::Webp : PhotoFormat::Jpeg;
  FileId premium_animation_file_id;
  for (auto &thumbnail_ptr : document->thumbs_) {
    auto photo_size = get_photo_size(td_->file_manager_.get(), PhotoSizeSource::thumbnail(FileType::Thumbnail, 0),
                                     document_id, document->access_hash_, document->file_reference_.as_slice().str(),
                                     dc_id, DialogId(), std::move(thumbnail_ptr), thumbnail_format);
    if (photo_size.get_offset() == 0) {
      if (!thumbnail.file_id.is_valid()) {
        thumbnail = std::move(photo_size.get<0>());
      }
      break;
    } else {
      if (thumbnail_format == PhotoFormat::Webp) {
        minithumbnail = std::move(photo_size.get<1>());
      }
    }
  }
  for (auto &thumbnail_ptr : document->video_thumbs_) {
    if (thumbnail_ptr->get_id() != telegram_api::videoSize::ID) {
      continue;
    }
    auto video_size = move_tl_object_as<telegram_api::videoSize>(thumbnail_ptr);
    if (video_size->type_ == "f") {
      if (!premium_animation_file_id.is_valid()) {
        premium_animation_file_id = register_photo_size(
            td_->file_manager_.get(), PhotoSizeSource::thumbnail(FileType::Thumbnail, 'f'), document_id,
            document->access_hash_, document->file_reference_.as_slice().str(), DialogId(), video_size->size_, dc_id,
            get_sticker_format_photo_format(format), "on_get_sticker_document");
      }
    }
  }

  create_sticker(sticker_id, premium_animation_file_id, std::move(minithumbnail), std::move(thumbnail), dimensions,
                 std::move(sticker), std::move(custom_emoji), format, nullptr);
  return {document_id, sticker_id};
}

StickersManager::Sticker *StickersManager::get_sticker(FileId file_id) {
  return stickers_.get_pointer(file_id);
}

const StickersManager::Sticker *StickersManager::get_sticker(FileId file_id) const {
  return stickers_.get_pointer(file_id);
}

StickersManager::StickerSet *StickersManager::get_sticker_set(StickerSetId sticker_set_id) {
  return sticker_sets_.get_pointer(sticker_set_id);
}

const StickersManager::StickerSet *StickersManager::get_sticker_set(StickerSetId sticker_set_id) const {
  return sticker_sets_.get_pointer(sticker_set_id);
}

StickerSetId StickersManager::get_sticker_set_id(const tl_object_ptr<telegram_api::InputStickerSet> &set_ptr) {
  CHECK(set_ptr != nullptr);
  switch (set_ptr->get_id()) {
    case telegram_api::inputStickerSetEmpty::ID:
      return StickerSetId();
    case telegram_api::inputStickerSetID::ID:
      return StickerSetId(static_cast<const telegram_api::inputStickerSetID *>(set_ptr.get())->id_);
    case telegram_api::inputStickerSetShortName::ID:
      LOG(ERROR) << "Receive sticker set by its short name";
      return search_sticker_set(static_cast<const telegram_api::inputStickerSetShortName *>(set_ptr.get())->short_name_,
                                false, Auto());
    case telegram_api::inputStickerSetAnimatedEmoji::ID:
    case telegram_api::inputStickerSetAnimatedEmojiAnimations::ID:
    case telegram_api::inputStickerSetPremiumGifts::ID:
    case telegram_api::inputStickerSetEmojiGenericAnimations::ID:
    case telegram_api::inputStickerSetEmojiDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiChannelDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiDefaultTopicIcons::ID:
      LOG(ERROR) << "Receive special sticker set " << to_string(set_ptr);
      return add_special_sticker_set(SpecialStickerSetType(set_ptr)).id_;
    case telegram_api::inputStickerSetDice::ID:
      LOG(ERROR) << "Receive special sticker set " << to_string(set_ptr);
      return StickerSetId();
    default:
      UNREACHABLE();
      return StickerSetId();
  }
}

StickerSetId StickersManager::add_sticker_set(tl_object_ptr<telegram_api::InputStickerSet> &&set_ptr) {
  CHECK(set_ptr != nullptr);
  switch (set_ptr->get_id()) {
    case telegram_api::inputStickerSetEmpty::ID:
      return StickerSetId();
    case telegram_api::inputStickerSetID::ID: {
      auto set = move_tl_object_as<telegram_api::inputStickerSetID>(set_ptr);
      StickerSetId set_id{set->id_};
      add_sticker_set(set_id, set->access_hash_);
      return set_id;
    }
    case telegram_api::inputStickerSetShortName::ID: {
      auto set = move_tl_object_as<telegram_api::inputStickerSetShortName>(set_ptr);
      LOG(ERROR) << "Receive sticker set by its short name";
      return search_sticker_set(set->short_name_, false, Auto());
    }
    case telegram_api::inputStickerSetAnimatedEmoji::ID:
    case telegram_api::inputStickerSetAnimatedEmojiAnimations::ID:
    case telegram_api::inputStickerSetPremiumGifts::ID:
    case telegram_api::inputStickerSetEmojiGenericAnimations::ID:
    case telegram_api::inputStickerSetEmojiDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiChannelDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiDefaultTopicIcons::ID:
      LOG(ERROR) << "Receive special sticker set " << to_string(set_ptr);
      return add_special_sticker_set(SpecialStickerSetType(set_ptr)).id_;
    case telegram_api::inputStickerSetDice::ID:
      LOG(ERROR) << "Receive special sticker set " << to_string(set_ptr);
      return StickerSetId();
    default:
      UNREACHABLE();
      return StickerSetId();
  }
}

StickersManager::StickerSet *StickersManager::add_sticker_set(StickerSetId sticker_set_id, int64 access_hash) {
  if (!sticker_set_id.is_valid()) {
    return nullptr;
  }
  auto *s = get_sticker_set(sticker_set_id);
  if (s == nullptr) {
    auto sticker_set = make_unique<StickerSet>();
    s = sticker_set.get();

    s->id_ = sticker_set_id;
    s->access_hash_ = access_hash;
    s->is_changed_ = false;
    s->need_save_to_database_ = false;

    sticker_sets_.set(sticker_set_id, std::move(sticker_set));
  } else {
    CHECK(s->id_ == sticker_set_id);
    if (s->access_hash_ != access_hash) {
      LOG(INFO) << "Access hash of " << sticker_set_id << " changed";
      s->access_hash_ = access_hash;
      s->need_save_to_database_ = true;
    }
  }
  return s;
}

FileId StickersManager::get_sticker_thumbnail_file_id(FileId file_id) const {
  auto *sticker = get_sticker(file_id);
  CHECK(sticker != nullptr);
  return sticker->s_thumbnail_.file_id;
}

void StickersManager::delete_sticker_thumbnail(FileId file_id) {
  auto *sticker = get_sticker(file_id);
  CHECK(sticker != nullptr);
  sticker->s_thumbnail_ = PhotoSize();
}

vector<FileId> StickersManager::get_sticker_file_ids(FileId file_id) const {
  vector<FileId> result;
  auto sticker = get_sticker(file_id);
  CHECK(sticker != nullptr);
  result.push_back(file_id);
  if (sticker->s_thumbnail_.file_id.is_valid()) {
    result.push_back(sticker->s_thumbnail_.file_id);
  }
  if (sticker->m_thumbnail_.file_id.is_valid()) {
    result.push_back(sticker->m_thumbnail_.file_id);
  }
  if (sticker->premium_animation_file_id_.is_valid()) {
    result.push_back(sticker->premium_animation_file_id_);
  }
  return result;
}

FileId StickersManager::dup_sticker(FileId new_id, FileId old_id) {
  const Sticker *old_sticker = get_sticker(old_id);
  CHECK(old_sticker != nullptr);
  if (get_sticker(new_id) != nullptr) {
    return new_id;
  }
  auto new_sticker = make_unique<Sticker>(*old_sticker);
  new_sticker->file_id_ = new_id;
  stickers_.set(new_id, std::move(new_sticker));
  return new_id;
}

void StickersManager::merge_stickers(FileId new_id, FileId old_id) {
  CHECK(old_id.is_valid() && new_id.is_valid());
  CHECK(new_id != old_id);

  LOG(INFO) << "Merge stickers " << new_id << " and " << old_id;
  const Sticker *old_ = get_sticker(old_id);
  CHECK(old_ != nullptr);

  const auto *new_ = get_sticker(new_id);
  if (new_ == nullptr) {
    dup_sticker(new_id, old_id);
  } else {
    if (old_->set_id_ == new_->set_id_ && old_->dimensions_ != new_->dimensions_ && old_->dimensions_.width != 0 &&
        old_->dimensions_.height != 0 && !is_sticker_format_vector(old_->format_) &&
        !is_sticker_format_vector(new_->format_)) {
      LOG(ERROR) << "Sticker has changed: alt = (" << old_->alt_ << ", " << new_->alt_ << "), set_id = ("
                 << old_->set_id_ << ", " << new_->set_id_ << "), dimensions = (" << old_->dimensions_ << ", "
                 << new_->dimensions_ << ")";
    }
  }
  LOG_STATUS(td_->file_manager_->merge(new_id, old_id));
}

tl_object_ptr<telegram_api::InputStickerSet> StickersManager::get_input_sticker_set(const StickerSet *set) {
  CHECK(set != nullptr);
  return make_tl_object<telegram_api::inputStickerSetID>(set->id_.get(), set->access_hash_);
}

void StickersManager::reload_installed_sticker_sets(StickerType sticker_type, bool force) {
  if (G()->close_flag()) {
    return;
  }

  auto type = static_cast<int32>(sticker_type);
  auto &next_load_time = next_installed_sticker_sets_load_time_[type];
  if (!td_->auth_manager_->is_bot() && next_load_time >= 0 && (next_load_time < Time::now() || force)) {
    LOG_IF(INFO, force) << "Reload sticker sets";
    next_load_time = -1;
    td_->create_handler<GetAllStickersQuery>()->send(sticker_type, installed_sticker_sets_hash_[type]);
  }
}

void StickersManager::reload_featured_sticker_sets(StickerType sticker_type, bool force) {
  if (G()->close_flag()) {
    return;
  }

  auto type = static_cast<int32>(sticker_type);
  auto &next_load_time = next_featured_sticker_sets_load_time_[type];
  if (!td_->auth_manager_->is_bot() && next_load_time >= 0 && (next_load_time < Time::now() || force)) {
    LOG_IF(INFO, force) << "Reload trending sticker sets";
    next_load_time = -1;
    td_->create_handler<GetFeaturedStickerSetsQuery>()->send(sticker_type, featured_sticker_sets_hash_[type]);
  }
}

void StickersManager::reload_old_featured_sticker_sets(StickerType sticker_type, uint32 generation) {
  if (sticker_type != StickerType::Regular) {
    return;
  }
  auto type = static_cast<int32>(sticker_type);
  if (generation != 0 && generation != old_featured_sticker_set_generation_[type]) {
    return;
  }
  td_->create_handler<GetOldFeaturedStickerSetsQuery>()->send(
      sticker_type, static_cast<int32>(old_featured_sticker_set_ids_[type].size()), OLD_FEATURED_STICKER_SET_SLICE_SIZE,
      old_featured_sticker_set_generation_[type]);
}

StickerSetId StickersManager::on_get_input_sticker_set(FileId sticker_file_id,
                                                       tl_object_ptr<telegram_api::InputStickerSet> &&set_ptr,
                                                       MultiPromiseActor *load_data_multipromise_ptr) {
  if (set_ptr == nullptr) {
    return StickerSetId();
  }
  switch (set_ptr->get_id()) {
    case telegram_api::inputStickerSetEmpty::ID:
      return StickerSetId();
    case telegram_api::inputStickerSetID::ID: {
      auto set = move_tl_object_as<telegram_api::inputStickerSetID>(set_ptr);
      StickerSetId set_id{set->id_};
      add_sticker_set(set_id, set->access_hash_);
      return set_id;
    }
    case telegram_api::inputStickerSetShortName::ID: {
      auto set = move_tl_object_as<telegram_api::inputStickerSetShortName>(set_ptr);
      if (load_data_multipromise_ptr == nullptr) {
        LOG(ERROR) << "Receive sticker set " << set->short_name_ << " by its short name";
        return search_sticker_set(set->short_name_, false, Auto());
      }
      auto set_id = search_sticker_set(set->short_name_, false, load_data_multipromise_ptr->get_promise());
      if (!set_id.is_valid()) {
        load_data_multipromise_ptr->add_promise(PromiseCreator::lambda(
            [actor_id = actor_id(this), sticker_file_id, short_name = set->short_name_](Result<Unit> result) {
              if (result.is_ok()) {
                // just in case
                send_closure(actor_id, &StickersManager::on_resolve_sticker_set_short_name, sticker_file_id,
                             short_name);
              }
            }));
      }
      // always return empty StickerSetId, because we can't trust the set_id provided by the peer in the secret chat
      // the real sticker set identifier will be set in on_get_sticker if and only if the sticker is really from the set
      return StickerSetId();
    }
    case telegram_api::inputStickerSetAnimatedEmoji::ID:
    case telegram_api::inputStickerSetAnimatedEmojiAnimations::ID:
    case telegram_api::inputStickerSetPremiumGifts::ID:
    case telegram_api::inputStickerSetEmojiGenericAnimations::ID:
    case telegram_api::inputStickerSetEmojiDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiChannelDefaultStatuses::ID:
    case telegram_api::inputStickerSetEmojiDefaultTopicIcons::ID:
      return add_special_sticker_set(SpecialStickerSetType(set_ptr)).id_;
    case telegram_api::inputStickerSetDice::ID:
      return StickerSetId();
    default:
      UNREACHABLE();
      return StickerSetId();
  }
}

void StickersManager::on_resolve_sticker_set_short_name(FileId sticker_file_id, const string &short_name) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Resolve sticker " << sticker_file_id << " set to " << short_name;
  StickerSetId set_id = search_sticker_set(short_name, false, Auto());
  if (set_id.is_valid()) {
    auto *s = get_sticker(sticker_file_id);
    CHECK(s != nullptr);
    if (s->set_id_ != set_id) {
      s->set_id_ = set_id;
    }
  }
}

void StickersManager::add_sticker_thumbnail(Sticker *s, PhotoSize thumbnail) {
  if (!thumbnail.file_id.is_valid()) {
    return;
  }
  if (thumbnail.type == 'm') {
    s->m_thumbnail_ = std::move(thumbnail);
    return;
  }
  if (thumbnail.type == 's' || thumbnail.type == 't') {
    s->s_thumbnail_ = std::move(thumbnail);
    return;
  }
  LOG(ERROR) << "Receive sticker thumbnail of unsupported type " << thumbnail.type;
}

void StickersManager::create_sticker(FileId file_id, FileId premium_animation_file_id, string minithumbnail,
                                     PhotoSize thumbnail, Dimensions dimensions,
                                     tl_object_ptr<telegram_api::documentAttributeSticker> sticker,
                                     tl_object_ptr<telegram_api::documentAttributeCustomEmoji> custom_emoji,
                                     StickerFormat format, MultiPromiseActor *load_data_multipromise_ptr) {
  if (format == StickerFormat::Unknown && sticker == nullptr) {
    auto old_sticker = get_sticker(file_id);
    if (old_sticker != nullptr) {
      format = old_sticker->format_;
    } else {
      // guess format by file extension
      auto file_view = td_->file_manager_->get_file_view(file_id);
      auto suggested_path = file_view.suggested_path();
      const PathView path_view(suggested_path);
      format = get_sticker_format_by_extension(path_view.extension());
      if (format == StickerFormat::Unknown) {
        format = StickerFormat::Webp;
      }
    }
  }
  if (is_sticker_format_vector(format) && dimensions.width == 0) {
    dimensions.width = custom_emoji != nullptr ? 100 : 512;
    dimensions.height = custom_emoji != nullptr ? 100 : 512;
  }

  auto s = make_unique<Sticker>();
  s->file_id_ = file_id;
  s->dimensions_ = dimensions;
  if (!td_->auth_manager_->is_bot()) {
    s->minithumbnail_ = std::move(minithumbnail);
  }
  add_sticker_thumbnail(s.get(), std::move(thumbnail));
  if (premium_animation_file_id.is_valid()) {
    s->is_premium_ = true;
  }
  s->premium_animation_file_id_ = premium_animation_file_id;
  if (sticker != nullptr) {
    s->set_id_ = on_get_input_sticker_set(file_id, std::move(sticker->stickerset_), load_data_multipromise_ptr);
    s->alt_ = std::move(sticker->alt_);

    if ((sticker->flags_ & telegram_api::documentAttributeSticker::MASK_MASK) != 0) {
      s->type_ = StickerType::Mask;
    }
    s->mask_position_ = StickerMaskPosition(sticker->mask_coords_);
  } else if (custom_emoji != nullptr) {
    s->set_id_ = on_get_input_sticker_set(file_id, std::move(custom_emoji->stickerset_), load_data_multipromise_ptr);
    s->alt_ = std::move(custom_emoji->alt_);
    s->type_ = StickerType::CustomEmoji;
    s->is_premium_ = !custom_emoji->free_;
    s->has_text_color_ = custom_emoji->text_color_;
    s->emoji_receive_date_ = G()->unix_time();
  }
  s->format_ = format;
  on_get_sticker(std::move(s),
                 (sticker != nullptr || custom_emoji != nullptr) && load_data_multipromise_ptr == nullptr);
}

bool StickersManager::has_secret_input_media(FileId sticker_file_id) const {
  auto file_view = td_->file_manager_->get_file_view(sticker_file_id);
  const Sticker *sticker = get_sticker(sticker_file_id);
  CHECK(sticker != nullptr);
  if (file_view.is_encrypted_secret()) {
    return true;
  }
  if (sticker->set_id_.is_valid()) {
    const auto *sticker_set = get_sticker_set(sticker->set_id_);
    if (sticker_set != nullptr && td::contains(sticker_set->sticker_ids_, sticker_file_id)) {
      // stickers within a set can be sent by id and access_hash
      return true;
    }
  }
  return false;
}

SecretInputMedia StickersManager::get_secret_input_media(
    FileId sticker_file_id, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
    BufferSlice thumbnail, int32 layer) const {
  const Sticker *sticker = get_sticker(sticker_file_id);
  CHECK(sticker != nullptr);
  auto file_view = td_->file_manager_->get_file_view(sticker_file_id);
  if (file_view.is_encrypted_secret()) {
    const auto *main_remote_location = file_view.get_main_remote_location();
    if (main_remote_location != nullptr) {
      input_file = main_remote_location->as_input_encrypted_file();
    }
    if (!input_file) {
      return {};
    }
    if (sticker->s_thumbnail_.file_id.is_valid() && thumbnail.empty()) {
      return {};
    }
  } else if (!file_view.is_encrypted()) {
    if (!sticker->set_id_.is_valid()) {
      // stickers without set can't be sent by id and access_hash
      return {};
    }
  } else {
    return {};
  }

  tl_object_ptr<secret_api::InputStickerSet> input_sticker_set = make_tl_object<secret_api::inputStickerSetEmpty>();
  if (sticker->set_id_.is_valid()) {
    const StickerSet *sticker_set = get_sticker_set(sticker->set_id_);
    CHECK(sticker_set != nullptr);
    if (sticker_set->is_inited_ && td::contains(sticker_set->sticker_ids_, sticker_file_id)) {
      input_sticker_set = make_tl_object<secret_api::inputStickerSetShortName>(sticker_set->short_name_);
    } else {
      // TODO load sticker set
    }
  }

  vector<tl_object_ptr<secret_api::DocumentAttribute>> attributes;
  attributes.push_back(
      secret_api::make_object<secret_api::documentAttributeSticker>(sticker->alt_, std::move(input_sticker_set)));
  if (sticker->dimensions_.width != 0 && sticker->dimensions_.height != 0) {
    attributes.push_back(secret_api::make_object<secret_api::documentAttributeImageSize>(sticker->dimensions_.width,
                                                                                         sticker->dimensions_.height));
  }

  if (file_view.is_encrypted_secret()) {
    return {std::move(input_file),
            std::move(thumbnail),
            sticker->s_thumbnail_.dimensions,
            get_sticker_format_mime_type(sticker->format_),
            file_view,
            std::move(attributes),
            string(),
            layer};
  } else {
    CHECK(!file_view.is_encrypted());
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);  // because it has set_id
    if (full_remote_location->is_web()) {
      // web stickers shouldn't have set_id
      LOG(ERROR) << "Have a web sticker in " << sticker->set_id_;
      return {};
    }
    if (file_view.size() > 1000000000) {
      LOG(ERROR) << "Have a sticker of size " << file_view.size() << " in " << sticker->set_id_;
      return {};
    }
    return SecretInputMedia{
        nullptr, make_tl_object<secret_api::decryptedMessageMediaExternalDocument>(
                     full_remote_location->get_id(), full_remote_location->get_access_hash(), 0 /*date*/,
                     get_sticker_format_mime_type(sticker->format_), narrow_cast<int32>(file_view.size()),
                     make_tl_object<secret_api::photoSizeEmpty>("t"), full_remote_location->get_dc_id().get_raw_id(),
                     std::move(attributes))};
  }
}

tl_object_ptr<telegram_api::InputMedia> StickersManager::get_input_media(
    FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, const string &emoji) const {
  auto file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return nullptr;
  }
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && !main_remote_location->is_web() && input_file == nullptr) {
    int32 flags = 0;
    if (!emoji.empty()) {
      flags |= telegram_api::inputMediaDocument::QUERY_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaDocument>(
        flags, false, main_remote_location->as_input_document(), nullptr, 0, 0, emoji);
  }
  const auto *url = file_view.get_url();
  if (url != nullptr) {
    return telegram_api::make_object<telegram_api::inputMediaDocumentExternal>(0, false, *url, 0, nullptr, 0);
  }

  if (input_file != nullptr) {
    const Sticker *s = get_sticker(file_id);
    CHECK(s != nullptr);

    vector<tl_object_ptr<telegram_api::DocumentAttribute>> attributes;
    if (s->dimensions_.width != 0 && s->dimensions_.height != 0) {
      attributes.push_back(
          make_tl_object<telegram_api::documentAttributeImageSize>(s->dimensions_.width, s->dimensions_.height));
    }
    attributes.push_back(make_tl_object<telegram_api::documentAttributeSticker>(
        0, false /*ignored*/, emoji.empty() ? s->alt_ : emoji, make_tl_object<telegram_api::inputStickerSetEmpty>(),
        nullptr));

    int32 flags = 0;
    if (input_thumbnail != nullptr) {
      flags |= telegram_api::inputMediaUploadedDocument::THUMB_MASK;
    }
    auto mime_type = get_sticker_format_mime_type(s->format_);
    return telegram_api::make_object<telegram_api::inputMediaUploadedDocument>(
        flags, false, false, false, std::move(input_file), std::move(input_thumbnail), mime_type, std::move(attributes),
        vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), nullptr, 0, 0);
  } else {
    CHECK(main_remote_location == nullptr);
  }

  return nullptr;
}

StickerSetId StickersManager::on_get_sticker_set(tl_object_ptr<telegram_api::stickerSet> &&set, bool is_changed,
                                                 const char *source) {
  CHECK(set != nullptr);
  StickerSetId set_id{set->id_};
  StickerSet *s = add_sticker_set(set_id, set->access_hash_);
  if (s == nullptr) {
    return {};
  }

  bool is_installed = (set->flags_ & telegram_api::stickerSet::INSTALLED_DATE_MASK) != 0;
  bool is_archived = set->archived_;
  bool is_official = set->official_;
  bool is_created = set->creator_;
  bool has_text_color = set->emojis_ && set->text_color_;
  bool channel_emoji_status = set->emojis_ && set->channel_emoji_status_;
  StickerType sticker_type =
      set->emojis_ ? StickerType::CustomEmoji : (set->masks_ ? StickerType::Mask : StickerType::Regular);

  PhotoSize thumbnail;
  string minithumbnail;
  for (auto &thumbnail_ptr : set->thumbs_) {
    auto photo_size =
        get_photo_size(td_->file_manager_.get(),
                       PhotoSizeSource::sticker_set_thumbnail(set_id.get(), s->access_hash_, set->thumb_version_), 0, 0,
                       "", DcId::create(set->thumb_dc_id_), DialogId(), std::move(thumbnail_ptr), PhotoFormat::Tgs);
    if (photo_size.get_offset() == 0) {
      if (!thumbnail.file_id.is_valid()) {
        thumbnail = std::move(photo_size.get<0>());
      }
    } else {
      minithumbnail = std::move(photo_size.get<1>());
    }
  }
  if (!s->is_inited_) {
    LOG(INFO) << "Init " << set_id;
    s->is_inited_ = true;
    s->title_ = std::move(set->title_);
    s->short_name_ = std::move(set->short_name_);
    if (!td_->auth_manager_->is_bot()) {
      s->minithumbnail_ = std::move(minithumbnail);
    }
    s->thumbnail_ = std::move(thumbnail);
    s->thumbnail_document_id_ = set->thumb_document_id_;
    s->is_thumbnail_reloaded_ = true;
    s->are_legacy_sticker_thumbnails_reloaded_ = true;
    s->sticker_count_ = set->count_;
    s->hash_ = set->hash_;
    s->is_official_ = is_official;
    s->sticker_type_ = sticker_type;
    s->has_text_color_ = has_text_color;
    s->channel_emoji_status_ = channel_emoji_status;
    s->is_created_ = is_created;
    s->is_changed_ = true;
  } else {
    CHECK(s->id_ == set_id);
    auto type = static_cast<int32>(s->sticker_type_);
    if (s->access_hash_ != set->access_hash_) {
      LOG(INFO) << "Access hash of " << set_id << " has changed";
      s->access_hash_ = set->access_hash_;
      s->need_save_to_database_ = true;
    }
    if (s->title_ != set->title_) {
      LOG(INFO) << "Title of " << set_id << " has changed";
      s->title_ = std::move(set->title_);
      s->is_changed_ = true;

      if (installed_sticker_sets_hints_[type].has_key(set_id.get())) {
        installed_sticker_sets_hints_[type].add(set_id.get(), PSLICE() << s->title_ << ' ' << s->short_name_);
      }
    }
    if (s->short_name_ != set->short_name_) {
      LOG(INFO) << "Short name of " << set_id << " has changed from \"" << s->short_name_ << "\" to \""
                << set->short_name_ << "\" from " << source;
      short_name_to_sticker_set_id_.erase(clean_username(s->short_name_));
      s->short_name_ = std::move(set->short_name_);
      s->is_changed_ = true;

      if (installed_sticker_sets_hints_[type].has_key(set_id.get())) {
        installed_sticker_sets_hints_[type].add(set_id.get(), PSLICE() << s->title_ << ' ' << s->short_name_);
      }
    }
    if (s->minithumbnail_ != minithumbnail) {
      LOG(INFO) << "Minithumbnail of " << set_id << " has changed";
      s->minithumbnail_ = std::move(minithumbnail);
      s->is_changed_ = true;
    }
    if (s->thumbnail_ != thumbnail) {
      LOG(INFO) << "Thumbnail of " << set_id << " has changed from " << s->thumbnail_ << " to " << thumbnail;
      s->thumbnail_ = std::move(thumbnail);
      s->is_changed_ = true;
    }
    if (s->thumbnail_document_id_ != set->thumb_document_id_) {
      LOG(INFO) << "Thumbnail of " << set_id << " has changed from " << s->thumbnail_document_id_ << " to "
                << set->thumb_document_id_;
      s->thumbnail_document_id_ = set->thumb_document_id_;
      s->is_changed_ = true;
    }
    if (!s->is_thumbnail_reloaded_ || !s->are_legacy_sticker_thumbnails_reloaded_) {
      LOG(INFO) << "Sticker thumbnails and thumbnail of " << set_id << " was reloaded";
      s->is_thumbnail_reloaded_ = true;
      s->are_legacy_sticker_thumbnails_reloaded_ = true;
      s->need_save_to_database_ = true;
    }

    if (s->sticker_count_ != set->count_ || s->hash_ != set->hash_) {
      LOG(INFO) << "Number of stickers in " << set_id << " changed from " << s->sticker_count_ << " to " << set->count_;
      s->is_loaded_ = false;

      s->sticker_count_ = set->count_;
      s->hash_ = set->hash_;
      if (s->was_loaded_) {
        s->need_save_to_database_ = true;
      } else {
        s->is_changed_ = true;
      }
    }

    if (s->is_official_ != is_official) {
      LOG(INFO) << "Official flag of " << set_id << " changed to " << is_official;
      s->is_official_ = is_official;
      s->is_changed_ = true;
    }
    if (s->is_created_ != is_created) {
      s->is_created_ = is_created;
      s->is_changed_ = true;
    }
    if (s->has_text_color_ != has_text_color) {
      LOG(INFO) << "Needs repainting flag of " << set_id << " changed to " << has_text_color;
      s->has_text_color_ = has_text_color;
      s->is_changed_ = true;
    }
    if (s->channel_emoji_status_ != channel_emoji_status) {
      LOG(INFO) << "Channel e,oji status flag of " << set_id << " changed to " << channel_emoji_status;
      s->channel_emoji_status_ = channel_emoji_status;
      s->is_changed_ = true;
    }
    LOG_IF(ERROR, s->sticker_type_ != sticker_type)
        << "Type of " << set_id << '/' << s->short_name_ << " has changed from " << s->sticker_type_ << " to "
        << sticker_type << " from " << source;
  }
  auto cleaned_username = clean_username(s->short_name_);
  if (!cleaned_username.empty()) {
    short_name_to_sticker_set_id_.set(cleaned_username, set_id);
  }

  on_update_sticker_set(s, is_installed, is_archived, is_changed);

  return set_id;
}

StickerSetId StickersManager::on_get_sticker_set_covered(tl_object_ptr<telegram_api::StickerSetCovered> &&set_ptr,
                                                         bool is_changed, const char *source) {
  StickerSetId set_id;
  switch (set_ptr->get_id()) {
    case telegram_api::stickerSetCovered::ID: {
      auto covered_set = move_tl_object_as<telegram_api::stickerSetCovered>(set_ptr);
      set_id = on_get_sticker_set(std::move(covered_set->set_), is_changed, source);
      if (!set_id.is_valid()) {
        break;
      }

      auto sticker_set = get_sticker_set(set_id);
      CHECK(sticker_set != nullptr);
      CHECK(sticker_set->is_inited_);
      if (sticker_set->was_loaded_) {
        break;
      }
      if (sticker_set->sticker_count_ == 0) {
        break;
      }

      auto &sticker_ids = sticker_set->sticker_ids_;

      auto sticker_id = on_get_sticker_document(std::move(covered_set->cover_), StickerFormat::Unknown, source).second;
      if (sticker_id.is_valid() && !td::contains(sticker_ids, sticker_id)) {
        sticker_ids.push_back(sticker_id);
        sticker_set->is_changed_ = true;
      }

      break;
    }
    case telegram_api::stickerSetMultiCovered::ID: {
      auto multicovered_set = move_tl_object_as<telegram_api::stickerSetMultiCovered>(set_ptr);
      set_id = on_get_sticker_set(std::move(multicovered_set->set_), is_changed, source);
      if (!set_id.is_valid()) {
        break;
      }

      auto sticker_set = get_sticker_set(set_id);
      CHECK(sticker_set != nullptr);
      CHECK(sticker_set->is_inited_);
      if (sticker_set->was_loaded_) {
        break;
      }
      auto &sticker_ids = sticker_set->sticker_ids_;

      for (auto &cover : multicovered_set->covers_) {
        auto sticker_id = on_get_sticker_document(std::move(cover), StickerFormat::Unknown, source).second;
        if (sticker_id.is_valid() && !td::contains(sticker_ids, sticker_id)) {
          sticker_ids.push_back(sticker_id);
          sticker_set->is_changed_ = true;
        }
      }

      break;
    }
    case telegram_api::stickerSetFullCovered::ID: {
      auto set = move_tl_object_as<telegram_api::stickerSetFullCovered>(set_ptr);
      auto sticker_set = telegram_api::make_object<telegram_api::messages_stickerSet>(
          std::move(set->set_), std::move(set->packs_), std::move(set->keywords_), std::move(set->documents_));
      return on_get_messages_sticker_set(StickerSetId(), std::move(sticker_set), is_changed, source);
    }
    case telegram_api::stickerSetNoCovered::ID: {
      auto covered_set = move_tl_object_as<telegram_api::stickerSetNoCovered>(set_ptr);
      set_id = on_get_sticker_set(std::move(covered_set->set_), is_changed, source);
      break;
    }
    default:
      UNREACHABLE();
  }
  return set_id;
}

StickerSetId StickersManager::on_get_messages_sticker_set(StickerSetId sticker_set_id,
                                                          tl_object_ptr<telegram_api::messages_StickerSet> &&set_ptr,
                                                          bool is_changed, const char *source) {
  LOG(INFO) << "Receive sticker set " << to_string(set_ptr);
  if (set_ptr->get_id() == telegram_api::messages_stickerSetNotModified::ID) {
    if (!sticker_set_id.is_valid()) {
      LOG(ERROR) << "Receive unexpected stickerSetNotModified from " << source;
    } else {
      auto s = get_sticker_set(sticker_set_id);
      CHECK(s != nullptr);
      CHECK(s->is_inited_);
      CHECK(s->was_loaded_);

      s->is_loaded_ = true;
      s->expires_at_ = G()->unix_time() +
                       (td_->auth_manager_->is_bot() ? Random::fast(10 * 60, 15 * 60) : Random::fast(30 * 60, 50 * 60));
    }
    return sticker_set_id;
  }
  auto set = move_tl_object_as<telegram_api::messages_stickerSet>(set_ptr);

  auto set_id = on_get_sticker_set(std::move(set->set_), is_changed, source);
  if (!set_id.is_valid()) {
    return StickerSetId();
  }
  if (sticker_set_id.is_valid() && sticker_set_id != set_id) {
    LOG(ERROR) << "Expected " << sticker_set_id << ", but receive " << set_id << " from " << source;
    on_load_sticker_set_fail(sticker_set_id, Status::Error(500, "Internal Server Error: wrong sticker set received"));
    return StickerSetId();
  }

  auto s = get_sticker_set(set_id);
  CHECK(s != nullptr);
  CHECK(s->is_inited_);

  s->expires_at_ = G()->unix_time() +
                   (td_->auth_manager_->is_bot() ? Random::fast(10 * 60, 15 * 60) : Random::fast(30 * 60, 50 * 60));

  if (s->is_loaded_) {
    update_sticker_set(s, "on_get_messages_sticker_set");
    send_update_installed_sticker_sets();
    return set_id;
  }
  s->was_loaded_ = true;
  s->is_loaded_ = true;
  s->is_changed_ = true;
  s->are_keywords_loaded_ = true;
  s->is_sticker_has_text_color_loaded_ = true;
  s->is_sticker_channel_emoji_status_loaded_ = true;
  s->is_created_loaded_ = true;

  FlatHashMap<int64, FileId> document_id_to_sticker_id;

  s->sticker_ids_.clear();
  s->premium_sticker_positions_.clear();
  bool is_bot = td_->auth_manager_->is_bot();
  for (auto &document_ptr : set->documents_) {
    auto sticker_id = on_get_sticker_document(std::move(document_ptr), StickerFormat::Unknown, source);
    if (!sticker_id.second.is_valid() || sticker_id.first == 0) {
      continue;
    }

    if (!is_bot && get_sticker(sticker_id.second)->is_premium_) {
      s->premium_sticker_positions_.push_back(static_cast<int32>(s->sticker_ids_.size()));
    }
    s->sticker_ids_.push_back(sticker_id.second);
    if (!is_bot) {
      document_id_to_sticker_id.emplace(sticker_id.first, sticker_id.second);
    }
  }
  auto get_full_source = [&] {
    return PSTRING() << set_id << '/' << s->short_name_ << " from " << source;
  };
  if (static_cast<int32>(s->sticker_ids_.size()) != s->sticker_count_) {
    LOG(ERROR) << "Wrong sticker set size " << s->sticker_count_ << " instead of " << s->sticker_ids_.size()
               << " specified in " << get_full_source();
    s->sticker_count_ = static_cast<int32>(s->sticker_ids_.size());
  }

  if (!is_bot) {
    s->emoji_stickers_map_.clear();
    s->sticker_emojis_map_.clear();
    s->keyword_stickers_map_.clear();
    s->sticker_keywords_map_.clear();
    for (auto &pack : set->packs_) {
      auto cleaned_emoji = remove_emoji_modifiers(pack->emoticon_);
      if (cleaned_emoji.empty()) {
        LOG(ERROR) << "Receive empty emoji in " << get_full_source();
        continue;
      }

      vector<FileId> stickers;
      stickers.reserve(pack->documents_.size());
      for (int64 document_id : pack->documents_) {
        auto it = document_id_to_sticker_id.find(document_id);
        if (it == document_id_to_sticker_id.end()) {
          LOG(ERROR) << "Can't find document with ID " << document_id << " in " << get_full_source();
          continue;
        }

        stickers.push_back(it->second);
        s->sticker_emojis_map_[it->second].push_back(pack->emoticon_);
      }

      auto &sticker_ids = s->emoji_stickers_map_[cleaned_emoji];
      for (auto sticker_id : stickers) {
        if (!td::contains(sticker_ids, sticker_id)) {
          sticker_ids.push_back(sticker_id);
        }
      }
    }
    for (auto &keywords : set->keywords_) {
      auto document_id = keywords->document_id_;
      auto it = document_id_to_sticker_id.find(document_id);
      if (it == document_id_to_sticker_id.end()) {
        LOG(ERROR) << "Can't find document with ID " << document_id << " in " << get_full_source();
        continue;
      }

      bool is_inserted = s->sticker_keywords_map_.emplace(it->second, std::move(keywords->keyword_)).second;
      if (!is_inserted) {
        LOG(ERROR) << "Receive twice document with ID " << document_id << " in " << get_full_source();
      }
    }
  }

  update_sticker_set(s, "on_get_messages_sticker_set 2");
  update_load_requests(s, true, Status::OK());
  send_update_installed_sticker_sets();

  if (set_id == add_special_sticker_set(SpecialStickerSetType::animated_emoji()).id_) {
    try_update_animated_emoji_messages();
  }
  if (set_id == add_special_sticker_set(SpecialStickerSetType::premium_gifts()).id_) {
    try_update_premium_gift_messages();
  }

  return set_id;
}

void StickersManager::on_load_sticker_set_fail(StickerSetId sticker_set_id, const Status &error) {
  if (!sticker_set_id.is_valid()) {
    return;
  }
  update_load_requests(get_sticker_set(sticker_set_id), true, error);
}

void StickersManager::on_sticker_set_deleted(const string &short_name) {
  // clear short_name_to_sticker_set_id_ to allow next searchStickerSet request to succeed
  LOG(INFO) << "Remove information about deleted sticker set " << short_name;
  short_name_to_sticker_set_id_.erase(clean_username(short_name));
}

void StickersManager::update_load_requests(StickerSet *sticker_set, bool with_stickers, const Status &status) {
  if (sticker_set == nullptr) {
    return;
  }
  if (with_stickers) {
    for (auto load_request_id : sticker_set->load_requests_) {
      update_load_request(load_request_id, status);
    }

    sticker_set->load_requests_.clear();
  }
  for (auto load_request_id : sticker_set->load_without_stickers_requests_) {
    update_load_request(load_request_id, status);
  }

  sticker_set->load_without_stickers_requests_.clear();

  if (status.message() == "STICKERSET_INVALID") {
    // the sticker set is likely to be deleted
    on_sticker_set_deleted(sticker_set->short_name_);
  }
}

void StickersManager::update_load_request(uint32 load_request_id, const Status &status) {
  auto it = sticker_set_load_requests_.find(load_request_id);
  CHECK(it != sticker_set_load_requests_.end());
  CHECK(it->second.left_queries_ > 0);
  if (status.is_error() && it->second.error_.is_ok()) {
    it->second.error_ = status.clone();
  }
  if (--it->second.left_queries_ == 0) {
    if (it->second.error_.is_ok()) {
      it->second.promise_.set_value(Unit());
    } else {
      it->second.promise_.set_error(std::move(it->second.error_));
    }
    sticker_set_load_requests_.erase(it);
  }
}

void StickersManager::on_get_sticker_set_name(StickerSetId sticker_set_id,
                                              telegram_api::object_ptr<telegram_api::messages_StickerSet> &&set_ptr) {
  auto it = sticker_set_name_load_queries_.find(sticker_set_id);
  CHECK(it != sticker_set_name_load_queries_.end());
  auto promises = std::move(it->second);
  sticker_set_name_load_queries_.erase(it);
  if (set_ptr == nullptr || set_ptr->get_id() != telegram_api::messages_stickerSet::ID) {
    return fail_promises(promises, Status::Error(500, "Failed to get sticker set name"));
  }
  auto set = telegram_api::move_object_as<telegram_api::messages_stickerSet>(set_ptr);
  if (sticker_set_id != StickerSetId(set->set_->id_)) {
    LOG(ERROR) << "Expected " << sticker_set_id << ", but receive " << StickerSetId(set->set_->id_);
    return fail_promises(promises, Status::Error(500, "Failed to get correct sticker set name"));
  }

  StickerSet *sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  if (!sticker_set->is_inited_) {
    sticker_set->short_name_ = std::move(set->set_->short_name_);
  }

  for (auto &promise : promises) {
    promise.set_value(string(sticker_set->short_name_));
  }
}

void StickersManager::on_get_special_sticker_set(const SpecialStickerSetType &type, StickerSetId sticker_set_id) {
  auto s = get_sticker_set(sticker_set_id);
  CHECK(s != nullptr);
  CHECK(s->is_inited_);
  CHECK(s->is_loaded_);

  LOG(INFO) << "Receive special sticker set " << type.type_ << ": " << sticker_set_id << ' ' << s->access_hash_ << ' '
            << s->short_name_;
  auto &sticker_set = add_special_sticker_set(type);
  auto new_short_name = clean_username(s->short_name_);
  if (sticker_set_id == sticker_set.id_ && s->access_hash_ == sticker_set.access_hash_ &&
      new_short_name == sticker_set.short_name_ && !new_short_name.empty()) {
    on_load_special_sticker_set(type, Status::OK());
    return;
  }

  sticker_set.id_ = sticker_set_id;
  sticker_set.access_hash_ = s->access_hash_;
  sticker_set.short_name_ = std::move(new_short_name);
  sticker_set.type_ = type;

  if (!td_->auth_manager_->is_bot()) {
    G()->td_db()->get_binlog_pmc()->set(type.type_, PSTRING()
                                                        << sticker_set.id_.get() << ' ' << sticker_set.access_hash_
                                                        << ' ' << sticker_set.short_name_);
  }

  sticker_set.is_being_loaded_ = true;
  on_load_special_sticker_set(type, Status::OK());
}

void StickersManager::on_get_installed_sticker_sets(StickerType sticker_type,
                                                    tl_object_ptr<telegram_api::messages_AllStickers> &&stickers_ptr) {
  auto type = static_cast<int32>(sticker_type);
  next_installed_sticker_sets_load_time_[type] = Time::now_cached() + Random::fast(30 * 60, 50 * 60);

  CHECK(stickers_ptr != nullptr);
  int32 constructor_id = stickers_ptr->get_id();
  if (constructor_id == telegram_api::messages_allStickersNotModified::ID) {
    LOG(INFO) << sticker_type << " stickers are not modified";
    return;
  }
  CHECK(constructor_id == telegram_api::messages_allStickers::ID);
  auto stickers = move_tl_object_as<telegram_api::messages_allStickers>(stickers_ptr);

  FlatHashSet<StickerSetId, StickerSetIdHash> uninstalled_sticker_sets;
  for (auto &sticker_set_id : installed_sticker_set_ids_[type]) {
    uninstalled_sticker_sets.insert(sticker_set_id);
  }

  vector<StickerSetId> sets_to_load;
  vector<StickerSetId> installed_sticker_set_ids;
  vector<int32> debug_hashes;
  vector<int64> debug_sticker_set_ids;
  std::reverse(stickers->sets_.begin(), stickers->sets_.end());  // apply installed sticker sets in reverse order
  for (auto &set : stickers->sets_) {
    debug_hashes.push_back(set->hash_);
    debug_sticker_set_ids.push_back(set->id_);
    StickerSetId set_id = on_get_sticker_set(std::move(set), false, "on_get_installed_sticker_sets");
    if (!set_id.is_valid()) {
      continue;
    }

    auto sticker_set = get_sticker_set(set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_inited_);

    if (sticker_set->is_installed_ && !sticker_set->is_archived_ && sticker_set->sticker_type_ == sticker_type) {
      installed_sticker_set_ids.push_back(set_id);
      uninstalled_sticker_sets.erase(set_id);
    } else {
      LOG_IF(ERROR, !sticker_set->is_installed_) << "Receive non-installed sticker set in getAllStickers";
      LOG_IF(ERROR, sticker_set->is_archived_) << "Receive archived sticker set in getAllStickers";
      LOG_IF(ERROR, sticker_set->sticker_type_ != sticker_type)
          << "Receive sticker set of a wrong type in getAllStickers";
    }
    update_sticker_set(sticker_set, "on_get_installed_sticker_sets");

    if (!sticker_set->is_archived_ && !sticker_set->is_loaded_) {
      sets_to_load.push_back(set_id);
    }
  }
  std::reverse(debug_hashes.begin(), debug_hashes.end());
  std::reverse(installed_sticker_set_ids.begin(), installed_sticker_set_ids.end());
  std::reverse(debug_sticker_set_ids.begin(), debug_sticker_set_ids.end());

  if (!sets_to_load.empty()) {
    load_sticker_sets(std::move(sets_to_load), Auto());
  }

  for (auto set_id : uninstalled_sticker_sets) {
    auto sticker_set = get_sticker_set(set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_installed_ && !sticker_set->is_archived_);
    on_update_sticker_set(sticker_set, false, false, true);
    update_sticker_set(sticker_set, "on_get_installed_sticker_sets 2");
  }

  on_load_installed_sticker_sets_finished(sticker_type, std::move(installed_sticker_set_ids));

  if (installed_sticker_sets_hash_[type] != stickers->hash_) {
    LOG(ERROR) << "Sticker sets hash mismatch: server hash list = " << debug_hashes << ", client hash list = "
               << transform(installed_sticker_set_ids_[type],
                            [this](StickerSetId sticker_set_id) { return get_sticker_set(sticker_set_id)->hash_; })
               << ", server sticker set list = " << debug_sticker_set_ids
               << ", client sticker set list = " << installed_sticker_set_ids_[type]
               << ", server hash = " << stickers->hash_ << ", client hash = " << installed_sticker_sets_hash_[type];
  }
}

void StickersManager::on_get_installed_sticker_sets_failed(StickerType sticker_type, Status error) {
  CHECK(error.is_error());
  auto type = static_cast<int32>(sticker_type);
  next_installed_sticker_sets_load_time_[type] = Time::now_cached() + Random::fast(5, 10);
  fail_promises(load_installed_sticker_sets_queries_[type], std::move(error));
}

const std::map<string, vector<FileId>> &StickersManager::get_sticker_set_keywords(const StickerSet *sticker_set) {
  if (sticker_set->keyword_stickers_map_.empty()) {
    for (auto &sticker_id_keywords : sticker_set->sticker_keywords_map_) {
      for (auto &keyword : Hints::fix_words(transform(sticker_id_keywords.second, utf8_prepare_search_string))) {
        CHECK(!keyword.empty());
        sticker_set->keyword_stickers_map_[keyword].push_back(sticker_id_keywords.first);
      }
    }
  }
  return sticker_set->keyword_stickers_map_;
}

void StickersManager::find_sticker_set_stickers(const StickerSet *sticker_set, const vector<string> &emojis,
                                                const string &query, vector<std::pair<bool, FileId>> &result) const {
  CHECK(sticker_set != nullptr);
  FlatHashSet<FileId, FileIdHash> found_sticker_ids;
  for (auto &emoji : emojis) {
    auto it = sticker_set->emoji_stickers_map_.find(emoji);
    if (it != sticker_set->emoji_stickers_map_.end()) {
      found_sticker_ids.insert(it->second.begin(), it->second.end());
    }
  }
  if (!query.empty()) {
    const auto &keywords_map = get_sticker_set_keywords(sticker_set);
    for (auto it = keywords_map.lower_bound(query); it != keywords_map.end() && begins_with(it->first, query); ++it) {
      found_sticker_ids.insert(it->second.begin(), it->second.end());
    }
  }

  if (!found_sticker_ids.empty()) {
    for (auto sticker_id : sticker_set->sticker_ids_) {
      if (found_sticker_ids.count(sticker_id) != 0) {
        const Sticker *s = get_sticker(sticker_id);
        LOG(INFO) << "Add " << sticker_id << " sticker from " << sticker_set->id_;
        result.emplace_back(is_sticker_format_animated(s->format_), sticker_id);
      }
    }
  }
}

bool StickersManager::can_find_sticker_by_query(FileId sticker_id, const vector<string> &emojis,
                                                const string &query) const {
  const Sticker *s = get_sticker(sticker_id);
  CHECK(s != nullptr);
  if (td::contains(emojis, remove_emoji_modifiers(s->alt_))) {
    // fast path
    return true;
  }
  const StickerSet *sticker_set = get_sticker_set(s->set_id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    return false;
  }
  for (auto &emoji : emojis) {
    auto it = sticker_set->emoji_stickers_map_.find(emoji);
    if (it != sticker_set->emoji_stickers_map_.end()) {
      if (td::contains(it->second, sticker_id)) {
        return true;
      }
    }
  }

  if (!query.empty()) {
    const auto &keywords_map = get_sticker_set_keywords(sticker_set);
    for (auto it = keywords_map.lower_bound(query); it != keywords_map.end() && begins_with(it->first, query); ++it) {
      if (td::contains(it->second, sticker_id)) {
        return true;
      }
    }
  }

  return false;
}

std::pair<vector<FileId>, vector<FileId>> StickersManager::split_stickers_by_premium(
    const vector<FileId> &sticker_ids) const {
  CHECK(!td_->auth_manager_->is_bot());
  vector<FileId> regular_sticker_ids;
  vector<FileId> premium_sticker_ids;
  for (const auto &sticker_id : sticker_ids) {
    if (sticker_id.is_valid()) {
      const Sticker *s = get_sticker(sticker_id);
      CHECK(s != nullptr);
      if (s->is_premium_) {
        premium_sticker_ids.push_back(sticker_id);
      } else {
        regular_sticker_ids.push_back(sticker_id);
      }
    }
  }
  return {std::move(regular_sticker_ids), std::move(premium_sticker_ids)};
}

std::pair<vector<FileId>, vector<FileId>> StickersManager::split_stickers_by_premium(
    const StickerSet *sticker_set) const {
  CHECK(!td_->auth_manager_->is_bot());
  if (!sticker_set->was_loaded_) {
    return split_stickers_by_premium(sticker_set->sticker_ids_);
  }
  if (sticker_set->premium_sticker_positions_.empty()) {
    return {sticker_set->sticker_ids_, {}};
  }
  vector<FileId> regular_sticker_ids;
  vector<FileId> premium_sticker_ids;
  size_t premium_pos = 0;
  for (size_t i = 0; i < sticker_set->sticker_ids_.size(); i++) {
    if (premium_pos < sticker_set->premium_sticker_positions_.size() &&
        static_cast<size_t>(sticker_set->premium_sticker_positions_[premium_pos]) == i) {
      premium_sticker_ids.push_back(sticker_set->sticker_ids_[i]);
      premium_pos++;
    } else {
      regular_sticker_ids.push_back(sticker_set->sticker_ids_[i]);
    }
  }
  CHECK(premium_pos == sticker_set->premium_sticker_positions_.size());
  return {std::move(regular_sticker_ids), std::move(premium_sticker_ids)};
}

vector<FileId> StickersManager::get_stickers(StickerType sticker_type, string query, int32 limit, DialogId dialog_id,
                                             bool force, Promise<Unit> &&promise) {
  if (G()->close_flag()) {
    promise.set_error(Global::request_aborted_error());
    return {};
  }

  if (limit <= 0) {
    promise.set_error(Status::Error(400, "Parameter limit must be positive"));
    return {};
  }

  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type]) {
    CHECK(!force);
    load_installed_sticker_sets(
        sticker_type,
        PromiseCreator::lambda([actor_id = actor_id(this), sticker_type, query = std::move(query), limit, dialog_id,
                                force, promise = std::move(promise)](Result<Unit> result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_stickers, sticker_type, std::move(query), limit, dialog_id,
                         force, std::move(promise));
          }
        }));
    return {};
  }

  bool return_all_installed = query.empty();

  remove_emoji_modifiers_in_place(query);
  auto emojis = full_split(query, ' ');
  for (auto &emoji : emojis) {
    if (!is_emoji(emoji)) {
      emojis.clear();
      break;
    }
  }
  if (!return_all_installed) {
    if (sticker_type == StickerType::Regular) {
      if (!are_recent_stickers_loaded_[0 /*is_attached*/]) {
        load_recent_stickers(false, std::move(promise));
        return {};
      }
      if (!are_favorite_stickers_loaded_) {
        load_favorite_stickers(std::move(promise));
        return {};
      }
    } else if (sticker_type == StickerType::CustomEmoji) {
      if (!are_featured_sticker_sets_loaded_[type]) {
        load_featured_sticker_sets(sticker_type, std::move(promise));
        return {};
      }
    }
  }

  vector<StickerSetId> examined_sticker_set_ids = installed_sticker_set_ids_[type];
  if (!return_all_installed && sticker_type == StickerType::CustomEmoji) {
    append(examined_sticker_set_ids, featured_sticker_set_ids_[type]);
  }

  vector<StickerSetId> sets_to_load;
  bool need_load = false;
  for (const auto &sticker_set_id : examined_sticker_set_ids) {
    const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_inited_);
    if (!sticker_set->is_loaded_) {
      sets_to_load.push_back(sticker_set_id);
      if (!sticker_set->was_loaded_) {
        need_load = true;
      }
    }
  }

  vector<FileId> prepend_sticker_ids;
  if (!return_all_installed && sticker_type == StickerType::Regular) {
    prepend_sticker_ids.reserve(favorite_sticker_ids_.size() + recent_sticker_ids_[0].size());
    append(prepend_sticker_ids, recent_sticker_ids_[0]);
    for (auto sticker_id : favorite_sticker_ids_) {
      if (!td::contains(prepend_sticker_ids, sticker_id)) {
        prepend_sticker_ids.push_back(sticker_id);
      }
    }

    auto prefer_animated = [this](FileId lhs, FileId rhs) {
      const Sticker *lhs_s = get_sticker(lhs);
      const Sticker *rhs_s = get_sticker(rhs);
      CHECK(lhs_s != nullptr && rhs_s != nullptr);
      return is_sticker_format_animated(lhs_s->format_) && !is_sticker_format_animated(rhs_s->format_);
    };
    // std::stable_sort(prepend_sticker_ids.begin(), prepend_sticker_ids.begin() + recent_sticker_ids_[0].size(),
    //                  prefer_animated);
    std::stable_sort(prepend_sticker_ids.begin() + recent_sticker_ids_[0].size(), prepend_sticker_ids.end(),
                     prefer_animated);

    LOG(INFO) << "Have " << recent_sticker_ids_[0] << " recent and " << favorite_sticker_ids_ << " favorite stickers";
    for (const auto &sticker_id : prepend_sticker_ids) {
      const Sticker *s = get_sticker(sticker_id);
      CHECK(s != nullptr);
      LOG(INFO) << "Have prepend sticker " << sticker_id << " from " << s->set_id_;
      if (s->set_id_.is_valid() && !td::contains(sets_to_load, s->set_id_)) {
        const StickerSet *sticker_set = get_sticker_set(s->set_id_);
        if (sticker_set == nullptr || !sticker_set->is_loaded_) {
          sets_to_load.push_back(s->set_id_);
          if (sticker_set == nullptr || !sticker_set->was_loaded_) {
            need_load = true;
          }
        }
      }
    }
  }

  if (!sets_to_load.empty()) {
    if (need_load && !force) {
      load_sticker_sets(std::move(sets_to_load),
                        PromiseCreator::lambda([promise = std::move(promise)](Result<Unit> result) mutable {
                          if (result.is_error() && result.error().message() != "STICKERSET_INVALID") {
                            LOG(ERROR) << "Failed to load sticker sets: " << result.error();
                          }
                          promise.set_value(Unit());
                        }));
      return {};
    } else {
      load_sticker_sets(std::move(sets_to_load), Auto());
    }
  }

  bool allow_premium = false;
  if (sticker_type == StickerType::CustomEmoji) {
    switch (dialog_id.get_type()) {
      case DialogType::User:
        if (dialog_id.get_user_id() == td_->user_manager_->get_my_id()) {
          allow_premium = true;
        }
        break;
      case DialogType::SecretChat:
        if (td_->user_manager_->get_secret_chat_layer(dialog_id.get_secret_chat_id()) <
            static_cast<int32>(SecretChatLayer::SpoilerAndCustomEmojiEntities)) {
          promise.set_value(Unit());
          return {};
        }
        break;
      default:
        break;
    }
  }

  vector<FileId> result;
  auto limit_size_t = static_cast<size_t>(limit);
  if (return_all_installed) {
    for (const auto &sticker_set_id : examined_sticker_set_ids) {
      const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
      if (sticker_set == nullptr || !sticker_set->was_loaded_) {
        continue;
      }

      append(result, sticker_set->sticker_ids_);
      if (result.size() > limit_size_t) {
        result.resize(limit_size_t);
        break;
      }
    }
  } else {
    auto prepared_query = utf8_prepare_search_string(query);
    LOG(INFO) << "Search stickers by " << emojis << " and keyword " << prepared_query;
    vector<const StickerSet *> examined_sticker_sets;
    for (const auto &sticker_set_id : examined_sticker_set_ids) {
      const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
      if (sticker_set == nullptr || !sticker_set->was_loaded_) {
        continue;
      }

      if (!td::contains(examined_sticker_sets, sticker_set)) {
        examined_sticker_sets.push_back(sticker_set);
      }
    }
    vector<std::pair<bool, FileId>> partial_results[2][2];
    for (auto sticker_set : examined_sticker_sets) {
      find_sticker_set_stickers(sticker_set, emojis, prepared_query,
                                partial_results[sticker_set->is_installed_][sticker_set->is_archived_]);
    }
    for (int is_installed = 1; is_installed >= 0; is_installed--) {
      for (int is_archived = 1; is_archived >= 0; is_archived--) {
        auto &partial_result = partial_results[is_installed][is_archived];
        std::stable_sort(partial_result.begin(), partial_result.end(),
                         [](const auto &lhs, const auto &rhs) { return lhs.first && !rhs.first; });
        for (auto &is_animated_sticker_id_pair : partial_result) {
          result.push_back(is_animated_sticker_id_pair.second);
        }
      }
    }

    vector<FileId> sorted;
    sorted.reserve(min(limit_size_t, result.size()));
    auto recent_stickers_size = recent_sticker_ids_[0].size();
    const size_t MAX_RECENT_STICKERS = 5;
    for (size_t i = 0; i < prepend_sticker_ids.size(); i++) {
      if (sorted.size() == MAX_RECENT_STICKERS && i < recent_stickers_size) {
        LOG(INFO) << "Skip recent sticker " << prepend_sticker_ids[i];
        continue;
      }

      auto sticker_id = prepend_sticker_ids[i];
      bool is_good = false;
      auto it = std::find(result.begin(), result.end(), sticker_id);
      if (it != result.end()) {
        LOG(INFO) << "Found prepend sticker " << sticker_id << " in installed packs at position "
                  << (it - result.begin());
        *it = FileId();
        is_good = true;
      } else if (can_find_sticker_by_query(sticker_id, emojis, prepared_query)) {
        LOG(INFO) << "Found prepend sticker " << sticker_id;
        is_good = true;
      }

      if (is_good) {
        sorted.push_back(sticker_id);
        if (sorted.size() == limit_size_t) {
          break;
        }
      }
    }
    if (sorted.size() != limit_size_t) {
      vector<FileId> regular_sticker_ids;
      vector<FileId> premium_sticker_ids;
      std::tie(regular_sticker_ids, premium_sticker_ids) = split_stickers_by_premium(result);
      if (td_->option_manager_->get_option_boolean("is_premium") || allow_premium) {
        auto normal_count = td_->option_manager_->get_option_integer("stickers_normal_by_emoji_per_premium_num", 2);
        if (normal_count < 0) {
          normal_count = 2;
        }
        if (normal_count > 10) {
          normal_count = 10;
        }
        // premium users have normal_count normal stickers per each premium
        size_t normal_pos = 0;
        size_t premium_pos = 0;
        normal_count++;
        for (size_t pos = 1; normal_pos < regular_sticker_ids.size() || premium_pos < premium_sticker_ids.size();
             pos++) {
          if (pos % normal_count == 0 && premium_pos < premium_sticker_ids.size()) {
            auto sticker_id = premium_sticker_ids[premium_pos++];
            LOG(INFO) << "Add premium sticker " << sticker_id << " from installed sticker set";
            sorted.push_back(sticker_id);
          } else if (normal_pos < regular_sticker_ids.size()) {
            auto sticker_id = regular_sticker_ids[normal_pos++];
            LOG(INFO) << "Add normal sticker " << sticker_id << " from installed sticker set";
            sorted.push_back(sticker_id);
          }
          if (sorted.size() == limit_size_t) {
            break;
          }
        }
      } else {
        for (const auto &sticker_id : regular_sticker_ids) {
          LOG(INFO) << "Add normal sticker " << sticker_id << " from installed sticker set";
          sorted.push_back(sticker_id);
          if (sorted.size() == limit_size_t) {
            break;
          }
        }
        if (sorted.size() < limit_size_t) {
          auto premium_count = td_->option_manager_->get_option_integer("stickers_premium_by_emoji_num", 0);
          if (premium_count > 0) {
            for (const auto &sticker_id : premium_sticker_ids) {
              LOG(INFO) << "Add premium sticker " << sticker_id << " from installed sticker set";
              sorted.push_back(sticker_id);
              if (sorted.size() == limit_size_t || --premium_count == 0) {
                break;
              }
            }
          }
        }
      }
    }

    result = std::move(sorted);
  }

  promise.set_value(Unit());
  return result;
}

string StickersManager::get_found_stickers_database_key(StickerType sticker_type, const string &emoji) {
  return PSTRING() << (sticker_type == StickerType::Regular ? "found_stickers" : "found_custom_emoji") << emoji;
}

void StickersManager::search_stickers(StickerType sticker_type, string emoji, const string &query,
                                      const vector<string> &input_language_codes, int32 offset, int32 limit,
                                      Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
  }
  if (limit == 0) {
    return promise.set_value(get_stickers_object({}));
  }
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_FOUND_STICKERS) {
    limit = MAX_FOUND_STICKERS;
  }

  remove_emoji_modifiers_in_place(emoji, false);
  if (!query.empty() || offset > 0) {
    emoji = PSTRING() << emoji << '\xFF' << query << '\xFF' << implode(input_language_codes, ' ') << '\xFF' << offset
                      << '\xFF' << limit;
  }
  if (emoji.empty() || sticker_type == StickerType::Mask) {
    return promise.set_value(get_stickers_object({}));
  }

  auto type = static_cast<int32>(sticker_type);
  auto it = found_stickers_[type].find(emoji);
  if (it != found_stickers_[type].end()) {
    const auto &sticker_ids = it->second.sticker_ids_;
    auto result_size = min(static_cast<size_t>(limit), sticker_ids.size());
    promise.set_value(get_stickers_object({sticker_ids.begin(), sticker_ids.begin() + result_size}));
    if (Time::now() < it->second.next_reload_time_) {
      return;
    }

    promise = Promise<td_api::object_ptr<td_api::stickers>>();
    limit = 0;
  }

  auto &promises = search_stickers_queries_[type][emoji];
  promises.emplace_back(limit, std::move(promise));
  if (promises.size() == 1u) {
    if (it != found_stickers_[type].end()) {
      return reload_found_stickers(sticker_type, std::move(emoji),
                                   get_recent_stickers_hash(it->second.sticker_ids_, "search_stickers"));
    }

    if (G()->use_sqlite_pmc() && offset == 0) {
      LOG(INFO) << "Trying to load stickers for " << emoji << " from database";
      G()->td_db()->get_sqlite_pmc()->get(get_found_stickers_database_key(sticker_type, emoji),
                                          PromiseCreator::lambda([sticker_type, emoji](string value) mutable {
                                            send_closure(G()->stickers_manager(),
                                                         &StickersManager::on_load_found_stickers_from_database,
                                                         sticker_type, std::move(emoji), std::move(value));
                                          }));
    } else {
      return reload_found_stickers(sticker_type, std::move(emoji), 0);
    }
  }
}

void StickersManager::reload_found_stickers(StickerType sticker_type, string &&emoji, int64 hash) {
  if (emoji.find('\xFF') != string::npos) {
    auto parameters = full_split(emoji, '\xFF');
    CHECK(parameters.size() == 5);
    td_->create_handler<SearchStickersQuery>()->send(std::move(emoji), sticker_type, parameters[0], parameters[1],
                                                     full_split(parameters[2]), to_integer<int32>(parameters[3]),
                                                     to_integer<int32>(parameters[4]), hash);
    return;
  }
  switch (sticker_type) {
    case StickerType::Regular:
      td_->create_handler<GetStickersQuery>()->send(std::move(emoji), hash);
      break;
    case StickerType::CustomEmoji:
      td_->create_handler<SearchCustomEmojiQuery>()->send(std::move(emoji), hash);
      break;
    default:
      UNREACHABLE();
  }
}

void StickersManager::on_load_found_stickers_from_database(StickerType sticker_type, string emoji, string value) {
  if (G()->close_flag()) {
    on_search_stickers_failed(sticker_type, emoji, Global::request_aborted_error());
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Stickers for " << emoji << " aren't found in database";
    return reload_found_stickers(sticker_type, std::move(emoji), 0);
  }

  LOG(INFO) << "Successfully loaded stickers for " << emoji << " from database";

  auto type = static_cast<int32>(sticker_type);
  auto &found_stickers = found_stickers_[type][emoji];
  CHECK(found_stickers.next_reload_time_ == 0);
  auto status = log_event_parse(found_stickers, value);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load stickers for emoji: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    found_stickers_[type].erase(emoji);
    return reload_found_stickers(sticker_type, std::move(emoji), 0);
  }

  on_search_stickers_finished(sticker_type, emoji, found_stickers);
}

void StickersManager::on_search_stickers_finished(StickerType sticker_type, const string &emoji,
                                                  const FoundStickers &found_stickers) {
  auto type = static_cast<int32>(sticker_type);
  auto it = search_stickers_queries_[type].find(emoji);
  CHECK(it != search_stickers_queries_[type].end());
  CHECK(!it->second.empty());
  auto queries = std::move(it->second);
  search_stickers_queries_[type].erase(it);

  const auto &sticker_ids = found_stickers.sticker_ids_;
  for (auto &query : queries) {
    auto result_size = min(static_cast<size_t>(query.first), sticker_ids.size());
    query.second.set_value(get_stickers_object({sticker_ids.begin(), sticker_ids.begin() + result_size}));
  }
}

void StickersManager::on_search_stickers_succeeded(StickerType sticker_type, const string &emoji,
                                                   bool need_save_to_database, vector<FileId> &&sticker_ids) {
  auto type = static_cast<int32>(sticker_type);
  auto &found_stickers = found_stickers_[type][emoji];
  found_stickers.cache_time_ = 300;
  found_stickers.next_reload_time_ = Time::now() + found_stickers.cache_time_;
  found_stickers.sticker_ids_ = std::move(sticker_ids);

  if (G()->use_sqlite_pmc() && !G()->close_flag() && need_save_to_database) {
    LOG(INFO) << "Save " << sticker_type << " stickers for " << emoji << " to database";
    G()->td_db()->get_sqlite_pmc()->set(get_found_stickers_database_key(sticker_type, emoji),
                                        log_event_store(found_stickers).as_slice().str(), Auto());
  }

  return on_search_stickers_finished(sticker_type, emoji, found_stickers);
}

void StickersManager::on_search_stickers_failed(StickerType sticker_type, const string &emoji, Status &&error) {
  auto type = static_cast<int32>(sticker_type);
  auto it = search_stickers_queries_[type].find(emoji);
  CHECK(it != search_stickers_queries_[type].end());
  CHECK(!it->second.empty());
  auto queries = std::move(it->second);
  search_stickers_queries_[type].erase(it);

  for (auto &query : queries) {
    query.second.set_error(error.clone());
  }
}

void StickersManager::on_find_stickers_by_query_success(
    StickerType sticker_type, const string &emoji, bool is_first,
    telegram_api::object_ptr<telegram_api::messages_FoundStickers> &&stickers) {
  CHECK(stickers != nullptr);
  auto type = static_cast<int32>(sticker_type);
  switch (stickers->get_id()) {
    case telegram_api::messages_foundStickersNotModified::ID: {
      auto it = found_stickers_[type].find(emoji);
      if (it == found_stickers_[type].end()) {
        return on_find_stickers_fail(emoji, Status::Error(500, "Receive messages.foundStickerNotModified"));
      }
      auto &found_stickers = it->second;
      found_stickers.next_reload_time_ = Time::now() + found_stickers.cache_time_;
      return on_search_stickers_finished(sticker_type, emoji, found_stickers);
    }
    case telegram_api::messages_foundStickers::ID: {
      auto received_stickers = move_tl_object_as<telegram_api::messages_foundStickers>(stickers);

      vector<FileId> sticker_ids;
      for (auto &sticker : received_stickers->stickers_) {
        FileId sticker_id =
            on_get_sticker_document(std::move(sticker), StickerFormat::Unknown, "on_find_stickers_by_query_success")
                .second;
        if (sticker_id.is_valid()) {
          sticker_ids.push_back(sticker_id);
        }
      }

      return on_search_stickers_succeeded(sticker_type, emoji, is_first, std::move(sticker_ids));
    }
    default:
      UNREACHABLE();
  }
}

void StickersManager::on_find_stickers_by_query_fail(StickerType sticker_type, const string &emoji, Status &&error) {
  auto type = static_cast<int32>(sticker_type);
  if (found_stickers_[type].count(emoji) != 0) {
    found_stickers_[type][emoji].cache_time_ = Random::fast(40, 80);
    return on_find_stickers_success(emoji, telegram_api::make_object<telegram_api::messages_stickersNotModified>());
  }

  on_search_stickers_failed(sticker_type, emoji, std::move(error));
}

void StickersManager::on_find_stickers_success(const string &emoji,
                                               tl_object_ptr<telegram_api::messages_Stickers> &&stickers) {
  CHECK(stickers != nullptr);
  auto sticker_type = StickerType::Regular;
  auto type = static_cast<int32>(sticker_type);
  switch (stickers->get_id()) {
    case telegram_api::messages_stickersNotModified::ID: {
      auto it = found_stickers_[type].find(emoji);
      if (it == found_stickers_[type].end()) {
        return on_find_stickers_fail(emoji, Status::Error(500, "Receive messages.stickerNotModified"));
      }
      auto &found_stickers = it->second;
      found_stickers.next_reload_time_ = Time::now() + found_stickers.cache_time_;
      return on_search_stickers_finished(sticker_type, emoji, found_stickers);
    }
    case telegram_api::messages_stickers::ID: {
      auto received_stickers = move_tl_object_as<telegram_api::messages_stickers>(stickers);

      vector<FileId> sticker_ids;
      for (auto &sticker : received_stickers->stickers_) {
        FileId sticker_id =
            on_get_sticker_document(std::move(sticker), StickerFormat::Unknown, "on_find_stickers_success").second;
        if (sticker_id.is_valid()) {
          sticker_ids.push_back(sticker_id);
        }
      }

      return on_search_stickers_succeeded(sticker_type, emoji, true, std::move(sticker_ids));
    }
    default:
      UNREACHABLE();
  }
}

void StickersManager::on_find_stickers_fail(const string &emoji, Status &&error) {
  auto sticker_type = StickerType::Regular;
  auto type = static_cast<int32>(sticker_type);
  if (found_stickers_[type].count(emoji) != 0) {
    found_stickers_[type][emoji].cache_time_ = Random::fast(40, 80);
    return on_find_stickers_success(emoji, make_tl_object<telegram_api::messages_stickersNotModified>());
  }

  on_search_stickers_failed(sticker_type, emoji, std::move(error));
}

void StickersManager::on_find_custom_emojis_success(const string &emoji,
                                                    tl_object_ptr<telegram_api::EmojiList> &&stickers) {
  CHECK(stickers != nullptr);
  auto sticker_type = StickerType::CustomEmoji;
  auto type = static_cast<int32>(sticker_type);
  switch (stickers->get_id()) {
    case telegram_api::emojiListNotModified::ID: {
      auto it = found_stickers_[type].find(emoji);
      if (it == found_stickers_[type].end()) {
        return on_find_custom_emojis_fail(emoji, Status::Error(500, "Receive emojiListNotModified"));
      }
      auto &found_stickers = it->second;
      found_stickers.next_reload_time_ = Time::now() + found_stickers.cache_time_;
      return on_search_stickers_finished(sticker_type, emoji, found_stickers);
    }
    case telegram_api::emojiList::ID: {
      auto emoji_list = move_tl_object_as<telegram_api::emojiList>(stickers);

      auto custom_emoji_ids = CustomEmojiId::get_custom_emoji_ids(emoji_list->document_id_);
      get_custom_emoji_stickers_unlimited(
          custom_emoji_ids,
          PromiseCreator::lambda([actor_id = actor_id(this), emoji, hash = emoji_list->hash_,
                                  custom_emoji_ids](Result<td_api::object_ptr<td_api::stickers>> &&result) {
            send_closure(actor_id, &StickersManager::on_load_custom_emojis, std::move(emoji), hash, custom_emoji_ids,
                         std::move(result));
          }));
      break;
    }
    default:
      UNREACHABLE();
  }
}

void StickersManager::on_load_custom_emojis(string emoji, int64 hash, vector<CustomEmojiId> custom_emoji_ids,
                                            Result<td_api::object_ptr<td_api::stickers>> &&result) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    return on_find_custom_emojis_fail(emoji, result.move_as_error());
  }

  vector<FileId> sticker_ids;
  for (auto custom_emoji_id : custom_emoji_ids) {
    auto sticker_id = custom_emoji_to_sticker_id_.get(custom_emoji_id);
    if (sticker_id.is_valid()) {
      sticker_ids.push_back(sticker_id);
    }
  }

  on_search_stickers_succeeded(StickerType::CustomEmoji, emoji, true, std::move(sticker_ids));
}

void StickersManager::on_find_custom_emojis_fail(const string &emoji, Status &&error) {
  auto sticker_type = StickerType::CustomEmoji;
  auto type = static_cast<int32>(StickerType::CustomEmoji);
  if (found_stickers_[type].count(emoji) != 0) {
    found_stickers_[type][emoji].cache_time_ = Random::fast(40, 80);
    return on_find_custom_emojis_success(emoji, make_tl_object<telegram_api::emojiListNotModified>());
  }

  on_search_stickers_failed(sticker_type, emoji, std::move(error));
}

void StickersManager::get_premium_stickers(int32 limit, Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (limit == 0) {
    return promise.set_value(get_stickers_object({}));
  }
  if (limit > MAX_FOUND_STICKERS) {
    limit = MAX_FOUND_STICKERS;
  }

  MultiPromiseActorSafe mpas{"GetPremiumStickersMultiPromiseActor"};
  mpas.add_promise(PromiseCreator::lambda(
      [actor_id = actor_id(this), limit, promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &StickersManager::do_get_premium_stickers, limit, std::move(promise));
        }
      }));

  auto lock = mpas.get_promise();
  search_stickers(StickerType::Regular, "📂⭐️", string(), vector<string>(), 0, limit,
                  PromiseCreator::lambda(
                      [promise = mpas.get_promise()](Result<td_api::object_ptr<td_api::stickers>> result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          promise.set_value(Unit());
                        }
                      }));
  get_stickers(StickerType::Regular, string(), 1, DialogId(), false, mpas.get_promise());
  lock.set_value(Unit());
}

void StickersManager::do_get_premium_stickers(int32 limit, Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  auto type = static_cast<int32>(StickerType::Regular);
  CHECK(are_installed_sticker_sets_loaded_[type]);

  vector<FileId> sticker_ids;
  auto limit_size_t = static_cast<size_t>(limit);
  for (const auto &sticker_set_id : installed_sticker_set_ids_[type]) {
    const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    if (sticker_set == nullptr || !sticker_set->was_loaded_) {
      continue;
    }

    for (auto premium_sticker_position : sticker_set->premium_sticker_positions_) {
      sticker_ids.push_back(sticker_set->sticker_ids_[premium_sticker_position]);
      if (sticker_ids.size() == limit_size_t) {
        return promise.set_value(get_stickers_object(sticker_ids));
      }
    }
  }

  auto it = found_stickers_[type].find(remove_emoji_modifiers("📂⭐️", false));
  CHECK(it != found_stickers_[type].end());
  for (auto sticker_id : it->second.sticker_ids_) {
    if (td::contains(sticker_ids, sticker_id)) {
      continue;
    }
    sticker_ids.push_back(sticker_id);
    if (sticker_ids.size() == limit_size_t) {
      break;
    }
  }
  promise.set_value(get_stickers_object(sticker_ids));
}

vector<StickerSetId> StickersManager::get_installed_sticker_sets(StickerType sticker_type, Promise<Unit> &&promise) {
  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type]) {
    load_installed_sticker_sets(sticker_type, std::move(promise));
    return {};
  }
  reload_installed_sticker_sets(sticker_type, false);

  promise.set_value(Unit());
  return installed_sticker_set_ids_[type];
}

bool StickersManager::update_sticker_set_cache(const StickerSet *sticker_set, Promise<Unit> &promise) {
  CHECK(sticker_set != nullptr);
  auto set_id = sticker_set->id_;
  if (!sticker_set->is_loaded_) {
    if (!sticker_set->was_loaded_ || td_->auth_manager_->is_bot()) {
      load_sticker_sets({set_id}, std::move(promise));
      return true;
    } else {
      load_sticker_sets({set_id}, Auto());
    }
  } else if (sticker_set->is_installed_) {
    reload_installed_sticker_sets(sticker_set->sticker_type_, false);
  } else {
    if (G()->unix_time() >= sticker_set->expires_at_) {
      if (td_->auth_manager_->is_bot()) {
        do_reload_sticker_set(set_id, get_input_sticker_set(sticker_set), sticker_set->hash_, std::move(promise),
                              "update_sticker_set_cache");
        return true;
      } else {
        do_reload_sticker_set(set_id, get_input_sticker_set(sticker_set), sticker_set->hash_, Auto(),
                              "update_sticker_set_cache");
      }
    }
  }

  return false;
}

StickerSetId StickersManager::get_sticker_set(StickerSetId set_id, Promise<Unit> &&promise) {
  const StickerSet *sticker_set = get_sticker_set(set_id);
  if (sticker_set == nullptr) {
    if (set_id.get() == GREAT_MINDS_SET_ID) {
      do_reload_sticker_set(set_id, make_tl_object<telegram_api::inputStickerSetID>(set_id.get(), 0), 0,
                            std::move(promise), "get_sticker_set");
      return StickerSetId();
    }

    promise.set_error(Status::Error(400, "Sticker set not found"));
    return StickerSetId();
  }

  if (update_sticker_set_cache(sticker_set, promise)) {
    return StickerSetId();
  }

  promise.set_value(Unit());
  return set_id;
}

void StickersManager::get_sticker_set_name(StickerSetId set_id, Promise<string> &&promise) {
  constexpr int64 GREAT_MINDS_COLOR_SET_ID = 151353307481243663;
  if (set_id.get() == GREAT_MINDS_SET_ID || set_id.get() == GREAT_MINDS_COLOR_SET_ID) {
    return promise.set_value("TelegramGreatMinds");
  }

  const StickerSet *sticker_set = get_sticker_set(set_id);
  if (sticker_set == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker set not found"));
  }
  if (!sticker_set->short_name_.empty()) {
    return promise.set_value(string(sticker_set->short_name_));
  }
  auto &queries = sticker_set_name_load_queries_[set_id];
  queries.push_back(std::move(promise));
  if (queries.size() == 1u) {
    td_->create_handler<GetStickerSetNameQuery>()->send(set_id, get_input_sticker_set(sticker_set));
  }
}

StickerSetId StickersManager::search_sticker_set(const string &short_name_to_search, bool ignore_cache,
                                                 Promise<Unit> &&promise) {
  string short_name = clean_username(short_name_to_search);
  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));

  if (sticker_set == nullptr || ignore_cache) {
    auto set_to_load = make_tl_object<telegram_api::inputStickerSetShortName>(short_name);
    do_reload_sticker_set(StickerSetId(), std::move(set_to_load), 0, std::move(promise), "search_sticker_set");
    return StickerSetId();
  }

  if (update_sticker_set_cache(sticker_set, promise)) {
    return StickerSetId();
  }

  promise.set_value(Unit());
  return sticker_set->id_;
}

std::pair<int32, vector<StickerSetId>> StickersManager::search_installed_sticker_sets(StickerType sticker_type,
                                                                                      const string &query, int32 limit,
                                                                                      Promise<Unit> &&promise) {
  LOG(INFO) << "Search installed " << sticker_type << " sticker sets with query = \"" << query
            << "\" and limit = " << limit;

  if (limit < 0) {
    promise.set_error(Status::Error(400, "Limit must be non-negative"));
    return {};
  }

  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type]) {
    load_installed_sticker_sets(sticker_type, std::move(promise));
    return {};
  }
  reload_installed_sticker_sets(sticker_type, false);

  std::pair<size_t, vector<int64>> result = installed_sticker_sets_hints_[type].search(query, limit);
  promise.set_value(Unit());
  return {narrow_cast<int32>(result.first), convert_sticker_set_ids(result.second)};
}

vector<StickerSetId> StickersManager::search_sticker_sets(StickerType sticker_type, const string &query,
                                                          Promise<Unit> &&promise) {
  if (sticker_type == StickerType::Mask) {
    promise.set_value(Unit());
    return {};
  }
  auto type = static_cast<int32>(sticker_type);

  auto q = clean_name(query, 1000);
  auto it = found_sticker_sets_[type].find(q);
  if (it != found_sticker_sets_[type].end()) {
    promise.set_value(Unit());
    auto result = it->second;
    td::remove_if(result, [&](StickerSetId sticker_set_id) {
      const auto *sticker_set = get_sticker_set(sticker_set_id);
      CHECK(sticker_set != nullptr);
      return sticker_set->is_inited_ && sticker_set->is_installed_;
    });
    return result;
  }

  auto &promises = search_sticker_sets_queries_[type][q];
  promises.push_back(std::move(promise));
  if (promises.size() == 1u) {
    td_->create_handler<SearchStickerSetsQuery>()->send(sticker_type, std::move(q));
  }

  return {};
}

void StickersManager::on_find_sticker_sets_success(
    StickerType sticker_type, const string &query,
    tl_object_ptr<telegram_api::messages_FoundStickerSets> &&sticker_sets) {
  auto type = static_cast<int32>(sticker_type);
  CHECK(sticker_sets != nullptr);
  switch (sticker_sets->get_id()) {
    case telegram_api::messages_foundStickerSetsNotModified::ID:
      return on_find_sticker_sets_fail(sticker_type, query,
                                       Status::Error(500, "Receive messages.foundStickerSetsNotModified"));
    case telegram_api::messages_foundStickerSets::ID: {
      auto found_stickers_sets = move_tl_object_as<telegram_api::messages_foundStickerSets>(sticker_sets);
      vector<StickerSetId> &sticker_set_ids = found_sticker_sets_[type][query];
      CHECK(sticker_set_ids.empty());

      for (auto &sticker_set : found_stickers_sets->sets_) {
        StickerSetId set_id = on_get_sticker_set_covered(std::move(sticker_set), true, "on_find_sticker_sets_success");
        if (!set_id.is_valid()) {
          continue;
        }
        auto *s = get_sticker_set(set_id);
        CHECK(s != nullptr);
        if (s->sticker_type_ != sticker_type) {
          LOG(ERROR) << "Receive " << set_id << " of type " << s->sticker_type_ << " while searching for "
                     << sticker_type << " sticker sets with query " << query;
          continue;
        }

        update_sticker_set(s, "on_find_sticker_sets_success");
        sticker_set_ids.push_back(set_id);
      }

      send_update_installed_sticker_sets();
      break;
    }
    default:
      UNREACHABLE();
  }

  auto it = search_sticker_sets_queries_[type].find(query);
  CHECK(it != search_sticker_sets_queries_[type].end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  search_sticker_sets_queries_[type].erase(it);

  set_promises(promises);
}

void StickersManager::on_find_sticker_sets_fail(StickerType sticker_type, const string &query, Status &&error) {
  auto type = static_cast<int32>(sticker_type);
  CHECK(found_sticker_sets_[type].count(query) == 0);

  auto it = search_sticker_sets_queries_[type].find(query);
  CHECK(it != search_sticker_sets_queries_[type].end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  search_sticker_sets_queries_[type].erase(it);

  fail_promises(promises, std::move(error));
}

void StickersManager::change_sticker_set(StickerSetId set_id, bool is_installed, bool is_archived,
                                         Promise<Unit> &&promise) {
  if (is_installed && is_archived) {
    return promise.set_error(Status::Error(400, "Sticker set can't be installed and archived simultaneously"));
  }
  const StickerSet *sticker_set = get_sticker_set(set_id);
  if (sticker_set == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker set not found"));
  }
  if (!sticker_set->is_inited_) {
    load_sticker_sets({set_id}, std::move(promise));
    return;
  }
  auto type = static_cast<int32>(sticker_set->sticker_type_);
  if (!are_installed_sticker_sets_loaded_[type]) {
    load_installed_sticker_sets(sticker_set->sticker_type_, std::move(promise));
    return;
  }

  if (is_archived) {
    is_installed = true;
  }
  if (is_installed) {
    if (sticker_set->is_installed_ && is_archived == sticker_set->is_archived_) {
      return promise.set_value(Unit());
    }

    td_->create_handler<InstallStickerSetQuery>(std::move(promise))
        ->send(set_id, get_input_sticker_set(sticker_set), is_archived);
    return;
  }

  if (!sticker_set->is_installed_) {
    return promise.set_value(Unit());
  }

  td_->create_handler<UninstallStickerSetQuery>(std::move(promise))->send(set_id, get_input_sticker_set(sticker_set));
}

void StickersManager::on_update_sticker_set(StickerSet *sticker_set, bool is_installed, bool is_archived,
                                            bool is_changed, bool from_database) {
  LOG(INFO) << "Update " << sticker_set->id_ << ": installed = " << is_installed << ", archived = " << is_archived
            << ", changed = " << is_changed << ", from_database = " << from_database;
  CHECK(sticker_set->is_inited_);
  if (is_archived) {
    is_installed = true;
  }
  if (sticker_set->is_installed_ == is_installed && sticker_set->is_archived_ == is_archived) {
    return;
  }

  bool was_added = sticker_set->is_installed_ && !sticker_set->is_archived_;
  bool was_archived = sticker_set->is_archived_;
  sticker_set->is_installed_ = is_installed;
  sticker_set->is_archived_ = is_archived;
  if (!from_database) {
    sticker_set->is_changed_ = true;
  }

  bool is_added = sticker_set->is_installed_ && !sticker_set->is_archived_;
  auto type = static_cast<int32>(sticker_set->sticker_type_);
  if (was_added != is_added) {
    vector<StickerSetId> &sticker_set_ids = installed_sticker_set_ids_[type];
    need_update_installed_sticker_sets_[type] = true;

    if (is_added) {
      installed_sticker_sets_hints_[type].add(sticker_set->id_.get(),
                                              PSLICE() << sticker_set->title_ << ' ' << sticker_set->short_name_);
      sticker_set_ids.insert(sticker_set_ids.begin(), sticker_set->id_);
    } else {
      installed_sticker_sets_hints_[type].remove(sticker_set->id_.get());
      td::remove(sticker_set_ids, sticker_set->id_);
    }
  }
  if (was_archived != is_archived && is_changed) {
    int32 &total_count = total_archived_sticker_set_count_[type];
    vector<StickerSetId> &sticker_set_ids = archived_sticker_set_ids_[type];
    if (total_count < 0) {
      return;
    }

    if (is_archived) {
      if (!td::contains(sticker_set_ids, sticker_set->id_)) {
        total_count++;
        sticker_set_ids.insert(sticker_set_ids.begin(), sticker_set->id_);
      }
    } else {
      total_count--;
      if (total_count < 0) {
        LOG(ERROR) << "Total count of archived sticker sets became negative";
        total_count = 0;
      }
      td::remove(sticker_set_ids, sticker_set->id_);
    }
  }
}

void StickersManager::load_installed_sticker_sets(StickerType sticker_type, Promise<Unit> &&promise) {
  auto type = static_cast<int32>(sticker_type);
  if (td_->auth_manager_->is_bot()) {
    are_installed_sticker_sets_loaded_[type] = true;
  }
  if (are_installed_sticker_sets_loaded_[type]) {
    promise.set_value(Unit());
    return;
  }
  load_installed_sticker_sets_queries_[type].push_back(std::move(promise));
  if (load_installed_sticker_sets_queries_[type].size() == 1u) {
    if (G()->use_sqlite_pmc()) {
      LOG(INFO) << "Trying to load installed " << sticker_type << " sticker sets from database";
      G()->td_db()->get_sqlite_pmc()->get(
          PSTRING() << "sss" << type, PromiseCreator::lambda([sticker_type](string value) {
            send_closure(G()->stickers_manager(), &StickersManager::on_load_installed_sticker_sets_from_database,
                         sticker_type, std::move(value));
          }));
    } else {
      LOG(INFO) << "Trying to load installed " << sticker_type << " sticker sets from server";
      reload_installed_sticker_sets(sticker_type, true);
    }
  }
}

void StickersManager::on_load_installed_sticker_sets_from_database(StickerType sticker_type, string value) {
  if (G()->close_flag()) {
    on_get_installed_sticker_sets_failed(sticker_type, Global::request_aborted_error());
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Installed " << sticker_type << " sticker sets aren't found in database";
    reload_installed_sticker_sets(sticker_type, true);
    return;
  }

  LOG(INFO) << "Successfully loaded installed " << sticker_type << " sticker set list of size " << value.size()
            << " from database";

  StickerSetListLogEvent log_event;
  auto status = log_event_parse(log_event, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Can't load installed sticker set list: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    return reload_installed_sticker_sets(sticker_type, true);
  }
  CHECK(!log_event.is_premium_);

  vector<StickerSetId> sets_to_load;
  for (auto sticker_set_id : log_event.sticker_set_ids_) {
    StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    if (!sticker_set->is_inited_) {
      sets_to_load.push_back(sticker_set_id);
    }
  }
  std::reverse(sets_to_load.begin(), sets_to_load.end());  // load installed sticker sets in reverse order

  load_sticker_sets_without_stickers(
      std::move(sets_to_load),
      PromiseCreator::lambda([sticker_type,
                              sticker_set_ids = std::move(log_event.sticker_set_ids_)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(G()->stickers_manager(), &StickersManager::on_load_installed_sticker_sets_finished, sticker_type,
                       std::move(sticker_set_ids), true);
        } else {
          send_closure(G()->stickers_manager(), &StickersManager::reload_installed_sticker_sets, sticker_type, true);
        }
      }));
}

void StickersManager::on_load_installed_sticker_sets_finished(StickerType sticker_type,
                                                              vector<StickerSetId> &&installed_sticker_set_ids,
                                                              bool from_database) {
  bool need_reload = false;
  vector<StickerSetId> old_installed_sticker_set_ids;
  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type] && !installed_sticker_set_ids_[type].empty()) {
    old_installed_sticker_set_ids = std::move(installed_sticker_set_ids_[type]);
  }
  installed_sticker_set_ids_[type].clear();
  for (auto set_id : installed_sticker_set_ids) {
    CHECK(set_id.is_valid());

    auto sticker_set = get_sticker_set(set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_inited_);
    if (sticker_set->is_installed_ && !sticker_set->is_archived_ && sticker_set->sticker_type_ == sticker_type) {
      installed_sticker_set_ids_[type].push_back(set_id);
    } else {
      need_reload = true;
    }
  }
  if (need_reload) {
    LOG(ERROR) << "Reload installed " << sticker_type << " sticker sets, because only "
               << installed_sticker_set_ids_[type].size() << " of " << installed_sticker_set_ids.size()
               << " are really installed after loading from " << (from_database ? "database" : "server");
    reload_installed_sticker_sets(sticker_type, true);
  } else if (!old_installed_sticker_set_ids.empty() &&
             old_installed_sticker_set_ids != installed_sticker_set_ids_[type]) {
    LOG(ERROR) << "Reload installed " << sticker_type << " sticker sets, because they has changed from "
               << old_installed_sticker_set_ids << " to " << installed_sticker_set_ids_[type] << " after loading from "
               << (from_database ? "database" : "server");
    reload_installed_sticker_sets(sticker_type, true);
  }

  are_installed_sticker_sets_loaded_[type] = true;
  need_update_installed_sticker_sets_[type] = true;
  send_update_installed_sticker_sets(from_database);
  set_promises(load_installed_sticker_sets_queries_[type]);
}

string StickersManager::get_sticker_set_database_key(StickerSetId set_id) {
  return PSTRING() << "ss" << set_id.get();
}

string StickersManager::get_full_sticker_set_database_key(StickerSetId set_id) {
  return PSTRING() << "ssf" << set_id.get();
}

string StickersManager::get_sticker_set_database_value(const StickerSet *s, bool with_stickers, const char *source) {
  LogEventStorerCalcLength storer_calc_length;
  store_sticker_set(s, with_stickers, storer_calc_length, source);

  BufferSlice value_buffer{storer_calc_length.get_length()};
  auto value = value_buffer.as_mutable_slice();

  LOG(DEBUG) << "Serialized size of " << s->id_ << " is " << value.size();

  LogEventStorerUnsafe storer_unsafe(value.ubegin());
  store_sticker_set(s, with_stickers, storer_unsafe, source);

  return value.str();
}

void StickersManager::update_sticker_set(StickerSet *sticker_set, const char *source) {
  CHECK(sticker_set != nullptr);
  if (sticker_set->is_changed_ || sticker_set->need_save_to_database_) {
    if (G()->use_sqlite_pmc() && !G()->close_flag()) {
      LOG(INFO) << "Save " << sticker_set->id_ << " to database from " << source;
      if (sticker_set->is_inited_) {
        G()->td_db()->get_sqlite_pmc()->set(get_sticker_set_database_key(sticker_set->id_),
                                            get_sticker_set_database_value(sticker_set, false, source), Auto());
      }
      if (sticker_set->was_loaded_) {
        G()->td_db()->get_sqlite_pmc()->set(get_full_sticker_set_database_key(sticker_set->id_),
                                            get_sticker_set_database_value(sticker_set, true, source), Auto());
      }
    }
    if (sticker_set->is_changed_ && sticker_set->was_loaded_ && sticker_set->was_update_sent_) {
      send_closure(G()->td(), &Td::send_update,
                   td_api::make_object<td_api::updateStickerSet>(get_sticker_set_object(sticker_set->id_)));
    }
    sticker_set->is_changed_ = false;
    sticker_set->need_save_to_database_ = false;
    if (sticker_set->is_inited_) {
      update_load_requests(sticker_set, false, Status::OK());
    }
  }
}

void StickersManager::load_sticker_sets(vector<StickerSetId> &&sticker_set_ids, Promise<Unit> &&promise) {
  if (sticker_set_ids.empty()) {
    return promise.set_value(Unit());
  }

  CHECK(current_sticker_set_load_request_ < std::numeric_limits<uint32>::max());
  auto load_request_id = ++current_sticker_set_load_request_;
  StickerSetLoadRequest &load_request = sticker_set_load_requests_[load_request_id];
  load_request.promise_ = std::move(promise);
  load_request.left_queries_ = sticker_set_ids.size();

  for (auto sticker_set_id : sticker_set_ids) {
    StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    CHECK(!sticker_set->is_loaded_);

    sticker_set->load_requests_.push_back(load_request_id);
    if (sticker_set->load_requests_.size() == 1u) {
      if (G()->use_sqlite_pmc() && !sticker_set->was_loaded_) {
        LOG(INFO) << "Trying to load " << sticker_set_id << " with stickers from database";
        G()->td_db()->get_sqlite_pmc()->get(
            get_full_sticker_set_database_key(sticker_set_id), PromiseCreator::lambda([sticker_set_id](string value) {
              send_closure(G()->stickers_manager(), &StickersManager::on_load_sticker_set_from_database, sticker_set_id,
                           true, std::move(value));
            }));
      } else {
        LOG(INFO) << "Trying to load " << sticker_set_id << " with stickers from server";
        do_reload_sticker_set(sticker_set_id, get_input_sticker_set(sticker_set), 0, Auto(), "load_sticker_sets");
      }
    }
  }
}

void StickersManager::load_sticker_sets_without_stickers(vector<StickerSetId> &&sticker_set_ids,
                                                         Promise<Unit> &&promise) {
  if (sticker_set_ids.empty()) {
    promise.set_value(Unit());
    return;
  }

  CHECK(current_sticker_set_load_request_ < std::numeric_limits<uint32>::max());
  auto load_request_id = ++current_sticker_set_load_request_;
  StickerSetLoadRequest &load_request = sticker_set_load_requests_[load_request_id];
  load_request.promise_ = std::move(promise);
  load_request.left_queries_ = sticker_set_ids.size();

  for (auto sticker_set_id : sticker_set_ids) {
    StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    CHECK(!sticker_set->is_inited_);

    if (!sticker_set->load_requests_.empty()) {
      sticker_set->load_requests_.push_back(load_request_id);
    } else {
      sticker_set->load_without_stickers_requests_.push_back(load_request_id);
      if (sticker_set->load_without_stickers_requests_.size() == 1u) {
        if (G()->use_sqlite_pmc()) {
          LOG(INFO) << "Trying to load " << sticker_set_id << " from database";
          G()->td_db()->get_sqlite_pmc()->get(
              get_sticker_set_database_key(sticker_set_id), PromiseCreator::lambda([sticker_set_id](string value) {
                send_closure(G()->stickers_manager(), &StickersManager::on_load_sticker_set_from_database,
                             sticker_set_id, false, std::move(value));
              }));
        } else {
          LOG(INFO) << "Trying to load " << sticker_set_id << " from server";
          do_reload_sticker_set(sticker_set_id, get_input_sticker_set(sticker_set), 0, Auto(),
                                "load_sticker_sets_without_stickers");
        }
      }
    }
  }
}

void StickersManager::on_load_sticker_set_from_database(StickerSetId sticker_set_id, bool with_stickers, string value) {
  if (G()->close_flag()) {
    return;
  }
  StickerSet *sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  if (sticker_set->was_loaded_) {
    LOG(INFO) << "Receive from database previously loaded " << sticker_set_id;
    return;
  }
  if (!with_stickers && sticker_set->is_inited_) {
    LOG(INFO) << "Receive from database previously inited " << sticker_set_id;
    return;
  }

  // it is possible that a server reload_sticker_set request has failed and cleared requests list with an error
  if (with_stickers) {
    // CHECK(!sticker_set->load_requests_.empty());
  } else {
    // CHECK(!sticker_set->load_without_stickers_requests_.empty());
  }

  if (value.empty()) {
    LOG(INFO) << "Failed to find in the database " << sticker_set_id;
    return do_reload_sticker_set(sticker_set_id, get_input_sticker_set(sticker_set), 0, Auto(),
                                 "on_load_sticker_set_from_database");
  }

  LOG(INFO) << "Successfully loaded " << sticker_set_id << " with" << (with_stickers ? "" : "out")
            << " stickers of size " << value.size() << " from database";

  auto was_inited = sticker_set->is_inited_;
  auto old_sticker_count = sticker_set->sticker_ids_.size();

  {
    LOG_IF(ERROR, sticker_set->is_changed_) << sticker_set_id << " with" << (with_stickers ? "" : "out")
                                            << " stickers was changed before it is loaded from database";
    LogEventParser parser(value);
    parse_sticker_set(sticker_set, parser);
    parser.fetch_end();
    if (sticker_set->is_changed_) {
      LOG(INFO) << sticker_set_id << " with" << (with_stickers ? "" : "out") << " stickers is changed";
    }
    auto status = parser.get_status();
    if (status.is_error()) {
      G()->td_db()->get_sqlite_sync_pmc()->erase(with_stickers ? get_full_sticker_set_database_key(sticker_set_id)
                                                               : get_sticker_set_database_key(sticker_set_id));
      // need to crash, because the current StickerSet state is spoiled by parse_sticker_set
      LOG(FATAL) << "Failed to parse " << sticker_set_id << ": " << status << ' '
                 << format::as_hex_dump<4>(Slice(value));
    }
  }
  if (!sticker_set->is_created_loaded_ || !sticker_set->is_sticker_channel_emoji_status_loaded_ ||
      !sticker_set->is_sticker_has_text_color_loaded_ || !sticker_set->are_keywords_loaded_ ||
      !sticker_set->is_thumbnail_reloaded_ || !sticker_set->are_legacy_sticker_thumbnails_reloaded_) {
    do_reload_sticker_set(sticker_set_id, get_input_sticker_set(sticker_set), 0, Auto(),
                          "on_load_sticker_set_from_database 2");
  }

  if (with_stickers && was_inited && old_sticker_count < get_max_featured_sticker_count(sticker_set->sticker_type_) &&
      old_sticker_count < sticker_set->sticker_ids_.size()) {
    sticker_set->need_save_to_database_ = true;
  }

  update_sticker_set(sticker_set, "on_load_sticker_set_from_database");

  update_load_requests(sticker_set, with_stickers, Status::OK());
}

void StickersManager::reload_sticker_set(StickerSetId sticker_set_id, int64 access_hash, Promise<Unit> &&promise) {
  do_reload_sticker_set(sticker_set_id,
                        make_tl_object<telegram_api::inputStickerSetID>(sticker_set_id.get(), access_hash), 0,
                        std::move(promise), "reload_sticker_set");
}

void StickersManager::do_reload_sticker_set(StickerSetId sticker_set_id,
                                            tl_object_ptr<telegram_api::InputStickerSet> &&input_sticker_set,
                                            int32 hash, Promise<Unit> &&promise, const char *source) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(input_sticker_set != nullptr);
  LOG(INFO) << "Reload " << sticker_set_id << " from " << source;
  if (sticker_set_id.is_valid() && input_sticker_set->get_id() == telegram_api::inputStickerSetID::ID) {
    auto &queries = sticker_set_reload_queries_[sticker_set_id];
    if (queries == nullptr) {
      queries = make_unique<StickerSetReloadQueries>();
    }
    if (!queries->sent_promises_.empty()) {
      // query has already been sent, just wait for the result
      if (queries->sent_hash_ == 0 || hash == queries->sent_hash_) {
        LOG(INFO) << "Wait for result of the sent reload query";
        queries->sent_promises_.push_back(std::move(promise));
      } else {
        LOG(INFO) << "Postpone reload of " << sticker_set_id << ", because another query was sent";
        if (queries->pending_promises_.empty()) {
          queries->pending_hash_ = hash;
        } else if (queries->pending_hash_ != hash) {
          queries->pending_hash_ = 0;
        }
        queries->pending_promises_.push_back(std::move(promise));
      }
      return;
    }

    CHECK(queries->pending_promises_.empty());
    queries->sent_promises_.push_back(std::move(promise));
    queries->sent_hash_ = hash;
    promise = PromiseCreator::lambda([actor_id = actor_id(this), sticker_set_id](Result<Unit> result) mutable {
      send_closure(actor_id, &StickersManager::on_reload_sticker_set, sticker_set_id, std::move(result));
    });
  }
  td_->create_handler<GetStickerSetQuery>(std::move(promise))->send(sticker_set_id, std::move(input_sticker_set), hash);
}

void StickersManager::on_reload_sticker_set(StickerSetId sticker_set_id, Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);
  LOG(INFO) << "Reloaded " << sticker_set_id;
  auto it = sticker_set_reload_queries_.find(sticker_set_id);
  CHECK(it != sticker_set_reload_queries_.end());
  auto queries = std::move(it->second);
  sticker_set_reload_queries_.erase(it);
  CHECK(queries != nullptr);
  CHECK(!queries->sent_promises_.empty());
  if (result.is_error()) {
    fail_promises(queries->sent_promises_, result.error().clone());
    fail_promises(queries->pending_promises_, result.move_as_error());
    return;
  }
  set_promises(queries->sent_promises_);
  if (!queries->pending_promises_.empty()) {
    auto sticker_set = get_sticker_set(sticker_set_id);
    auto access_hash = sticker_set == nullptr ? 0 : sticker_set->access_hash_;
    auto promises = std::move(queries->pending_promises_);
    for (auto &promise : promises) {
      do_reload_sticker_set(sticker_set_id,
                            make_tl_object<telegram_api::inputStickerSetID>(sticker_set_id.get(), access_hash),
                            queries->pending_hash_, std::move(promise), "on_reload_sticker_set");
    }
  }
}

void StickersManager::on_install_sticker_set(StickerSetId set_id, bool is_archived,
                                             tl_object_ptr<telegram_api::messages_StickerSetInstallResult> &&result) {
  StickerSet *sticker_set = get_sticker_set(set_id);
  CHECK(sticker_set != nullptr);
  on_update_sticker_set(sticker_set, true, is_archived, true);
  update_sticker_set(sticker_set, "on_install_sticker_set");

  switch (result->get_id()) {
    case telegram_api::messages_stickerSetInstallResultSuccess::ID:
      break;
    case telegram_api::messages_stickerSetInstallResultArchive::ID: {
      auto archived_sets = move_tl_object_as<telegram_api::messages_stickerSetInstallResultArchive>(result);
      for (auto &archived_set_ptr : archived_sets->sets_) {
        StickerSetId archived_sticker_set_id =
            on_get_sticker_set_covered(std::move(archived_set_ptr), true, "on_install_sticker_set");
        if (archived_sticker_set_id.is_valid()) {
          auto archived_sticker_set = get_sticker_set(archived_sticker_set_id);
          CHECK(archived_sticker_set != nullptr);
          update_sticker_set(archived_sticker_set, "on_install_sticker_set 2");
        }
      }
      break;
    }
    default:
      UNREACHABLE();
  }

  send_update_installed_sticker_sets();
}

void StickersManager::on_uninstall_sticker_set(StickerSetId set_id) {
  StickerSet *sticker_set = get_sticker_set(set_id);
  CHECK(sticker_set != nullptr);
  on_update_sticker_set(sticker_set, false, false, true);
  update_sticker_set(sticker_set, "on_uninstall_sticker_set");
  send_update_installed_sticker_sets();
}

td_api::object_ptr<td_api::updateDiceEmojis> StickersManager::get_update_dice_emojis_object() const {
  return td_api::make_object<td_api::updateDiceEmojis>(vector<string>(dice_emojis_));
}

void StickersManager::on_update_dice_emojis() {
  if (G()->close_flag()) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    td_->option_manager_->set_option_empty("dice_emojis");
    return;
  }
  if (!is_inited_) {
    return;
  }

  auto dice_emojis_str =
      td_->option_manager_->get_option_string("dice_emojis", "🎲\x01🎯\x01🏀\x01⚽\x01⚽️\x01🎰\x01🎳");
  if (dice_emojis_str == dice_emojis_str_) {
    return;
  }
  dice_emojis_str_ = std::move(dice_emojis_str);
  auto new_dice_emojis = full_split(dice_emojis_str_, '\x01');
  for (auto &emoji : new_dice_emojis) {
    if (!td::contains(dice_emojis_, emoji)) {
      auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_dice(emoji));
      if (special_sticker_set.id_.is_valid()) {
        // drop information about the sticker set to reload it
        special_sticker_set.id_ = StickerSetId();
        special_sticker_set.access_hash_ = 0;
        special_sticker_set.short_name_.clear();
      }

      if (G()->use_sqlite_pmc()) {
        LOG(INFO) << "Load new dice sticker set for emoji " << emoji;
        load_special_sticker_set(special_sticker_set);
      }
    }
  }
  dice_emojis_ = std::move(new_dice_emojis);

  send_closure(G()->td(), &Td::send_update, get_update_dice_emojis_object());
}

void StickersManager::on_update_dice_success_values() {
  if (G()->close_flag()) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    td_->option_manager_->set_option_empty("dice_success_values");
    return;
  }
  if (!is_inited_) {
    return;
  }

  auto dice_success_values_str =
      td_->option_manager_->get_option_string("dice_success_values", "0,6:62,5:110,5:110,5:110,64:110,6:110");
  if (dice_success_values_str == dice_success_values_str_) {
    return;
  }

  LOG(INFO) << "Change dice success values to " << dice_success_values_str;
  dice_success_values_str_ = std::move(dice_success_values_str);
  dice_success_values_ = transform(full_split(dice_success_values_str_, ','), [](Slice value) {
    auto result = split(value, ':');
    return std::make_pair(to_integer<int32>(result.first), to_integer<int32>(result.second));
  });
}

void StickersManager::on_update_emoji_sounds() {
  if (G()->close_flag() || !is_inited_ || td_->auth_manager_->is_bot()) {
    return;
  }

  auto emoji_sounds_str = td_->option_manager_->get_option_string("emoji_sounds");
  if (emoji_sounds_str == emoji_sounds_str_) {
    return;
  }

  LOG(INFO) << "Change emoji sounds to " << emoji_sounds_str;
  emoji_sounds_str_ = std::move(emoji_sounds_str);

  vector<FileId> old_file_ids;
  for (auto &emoji_sound : emoji_sounds_) {
    old_file_ids.push_back(emoji_sound.second);
  }
  emoji_sounds_.clear();

  vector<FileId> new_file_ids;
  auto sounds = full_split(Slice(emoji_sounds_str_), ',');
  CHECK(sounds.size() % 2 == 0);
  for (size_t i = 0; i < sounds.size(); i += 2) {
    vector<Slice> parts = full_split(sounds[i + 1], ':');
    CHECK(parts.size() == 3);
    auto id = to_integer<int64>(parts[0]);
    auto access_hash = to_integer<int64>(parts[1]);
    auto dc_id = G()->net_query_dispatcher().get_main_dc_id();
    auto file_reference = base64url_decode(parts[2]).move_as_ok();
    int32 expected_size = 7000;
    auto suggested_file_name = PSTRING() << static_cast<uint64>(id) << '.'
                                         << MimeType::to_extension("audio/ogg", "oga");
    auto file_id = td_->file_manager_->register_remote(
        FullRemoteFileLocation(FileType::VoiceNote, id, access_hash, dc_id, std::move(file_reference)),
        FileLocationSource::FromServer, DialogId(), 0, expected_size, std::move(suggested_file_name));
    CHECK(file_id.is_valid());
    auto cleaned_emoji = remove_fitzpatrick_modifier(sounds[i]).str();
    if (!cleaned_emoji.empty()) {
      emoji_sounds_.emplace(cleaned_emoji, file_id);
      new_file_ids.push_back(file_id);
    }
  }
  td_->file_manager_->change_files_source(get_app_config_file_source_id(), old_file_ids, new_file_ids,
                                          "on_update_emoji_sounds");

  try_update_animated_emoji_messages();
}

void StickersManager::on_update_disable_animated_emojis() {
  if (G()->close_flag() || !is_inited_ || td_->auth_manager_->is_bot()) {
    return;
  }

  auto disable_animated_emojis = td_->option_manager_->get_option_boolean("disable_animated_emoji");
  if (disable_animated_emojis == disable_animated_emojis_) {
    return;
  }
  disable_animated_emojis_ = disable_animated_emojis;
  if (!disable_animated_emojis_) {
    reload_special_sticker_set_by_type(SpecialStickerSetType::animated_emoji());
    reload_special_sticker_set_by_type(SpecialStickerSetType::animated_emoji_click());
  }
  try_update_animated_emoji_messages();

  vector<CustomEmojiId> custom_emoji_ids;
  for (auto &it : custom_emoji_messages_) {
    custom_emoji_ids.push_back(it.first);
  }
  for (auto custom_emoji_id : custom_emoji_ids) {
    try_update_custom_emoji_messages(custom_emoji_id);
  }

  if (!disable_animated_emojis_) {
    for (auto &slice_custom_emoji_ids : vector_split(std::move(custom_emoji_ids), MAX_GET_CUSTOM_EMOJI_STICKERS)) {
      get_custom_emoji_stickers(std::move(slice_custom_emoji_ids), true, Auto());
    }
  }
}

void StickersManager::on_update_sticker_sets(StickerType sticker_type) {
  auto type = static_cast<int32>(sticker_type);
  archived_sticker_set_ids_[type].clear();
  total_archived_sticker_set_count_[type] = -1;
  reload_installed_sticker_sets(sticker_type, true);
}

void StickersManager::try_update_animated_emoji_messages() {
  auto sticker_set = get_animated_emoji_sticker_set();
  vector<MessageFullId> message_full_ids;
  vector<QuickReplyMessageFullId> quick_reply_message_full_ids;
  for (auto &it : emoji_messages_) {
    auto new_animated_sticker = get_animated_emoji_sticker(sticker_set, it.first);
    auto new_sound_file_id = get_animated_emoji_sound_file_id(it.first);
    if (new_animated_sticker != it.second->animated_emoji_sticker_ ||
        (new_animated_sticker.first.is_valid() && new_sound_file_id != it.second->sound_file_id_)) {
      it.second->animated_emoji_sticker_ = new_animated_sticker;
      it.second->sound_file_id_ = new_sound_file_id;
      it.second->message_full_ids_.foreach(
          [&](const MessageFullId &message_full_id) { message_full_ids.push_back(message_full_id); });
      it.second->quick_reply_message_full_ids_.foreach([&](const QuickReplyMessageFullId &message_full_id) {
        quick_reply_message_full_ids.push_back(message_full_id);
      });
    }
  }
  for (const auto &message_full_id : message_full_ids) {
    td_->messages_manager_->on_external_update_message_content(message_full_id, "try_update_animated_emoji_messages");
  }
  for (const auto &message_full_id : quick_reply_message_full_ids) {
    td_->quick_reply_manager_->on_external_update_message_content(message_full_id,
                                                                  "try_update_animated_emoji_messages");
  }
}

void StickersManager::try_update_custom_emoji_messages(CustomEmojiId custom_emoji_id) {
  auto it = custom_emoji_messages_.find(custom_emoji_id);
  if (it == custom_emoji_messages_.end()) {
    return;
  }

  vector<MessageFullId> message_full_ids;
  vector<QuickReplyMessageFullId> quick_reply_message_full_ids;
  auto new_sticker_id = get_custom_animated_emoji_sticker_id(custom_emoji_id);
  if (new_sticker_id != it->second->sticker_id_) {
    it->second->sticker_id_ = new_sticker_id;
    it->second->message_full_ids_.foreach(
        [&](const MessageFullId &message_full_id) { message_full_ids.push_back(message_full_id); });
    it->second->quick_reply_message_full_ids_.foreach([&](const QuickReplyMessageFullId &message_full_id) {
      quick_reply_message_full_ids.push_back(message_full_id);
    });
  }
  for (const auto &message_full_id : message_full_ids) {
    td_->messages_manager_->on_external_update_message_content(message_full_id, "try_update_custom_emoji_messages");
  }
  for (const auto &message_full_id : quick_reply_message_full_ids) {
    td_->quick_reply_manager_->on_external_update_message_content(message_full_id, "try_update_custom_emoji_messages");
  }
}

void StickersManager::try_update_premium_gift_messages() {
  auto sticker_set = get_premium_gift_sticker_set();
  vector<MessageFullId> message_full_ids;
  for (auto &it : premium_gift_messages_) {
    auto new_sticker_id = get_premium_gift_option_sticker_id(sticker_set, it.first);
    if (new_sticker_id != it.second->sticker_id_) {
      it.second->sticker_id_ = new_sticker_id;
      for (const auto &message_full_id : it.second->message_full_ids_) {
        message_full_ids.push_back(message_full_id);
      }
    }
  }
  for (const auto &message_full_id : message_full_ids) {
    td_->messages_manager_->on_external_update_message_content(message_full_id, "try_update_premium_gift_messages");
  }
}

void StickersManager::register_premium_gift(int32 months, int64 star_count, MessageFullId message_full_id,
                                            const char *source) {
  if (months == 0) {
    months = StarManager::get_months_by_star_count(star_count);
  }
  if (td_->auth_manager_->is_bot() || months == 0) {
    return;
  }

  LOG(INFO) << "Register premium gift for " << months << " months from " << message_full_id << " from " << source;
  auto &premium_gift_messages_ptr = premium_gift_messages_[months];
  if (premium_gift_messages_ptr == nullptr) {
    premium_gift_messages_ptr = make_unique<GiftPremiumMessages>();
  }
  auto &premium_gift_messages = *premium_gift_messages_ptr;

  if (premium_gift_messages.message_full_ids_.empty()) {
    premium_gift_messages.sticker_id_ = get_premium_gift_option_sticker_id(months);
  }

  bool is_inserted = premium_gift_messages.message_full_ids_.insert(message_full_id).second;
  LOG_CHECK(is_inserted) << source << ' ' << months << ' ' << message_full_id;
}

void StickersManager::unregister_premium_gift(int32 months, int64 star_count, MessageFullId message_full_id,
                                              const char *source) {
  if (months == 0) {
    months = StarManager::get_months_by_star_count(star_count);
  }
  if (td_->auth_manager_->is_bot() || months == 0) {
    return;
  }

  LOG(INFO) << "Unregister premium gift for " << months << " months from " << message_full_id << " from " << source;
  auto it = premium_gift_messages_.find(months);
  CHECK(it != premium_gift_messages_.end());
  auto &message_ids = it->second->message_full_ids_;
  auto is_deleted = message_ids.erase(message_full_id) > 0;
  LOG_CHECK(is_deleted) << source << ' ' << months << ' ' << message_full_id;

  if (message_ids.empty()) {
    premium_gift_messages_.erase(it);
  }
}

void StickersManager::register_dice(const string &emoji, int32 value, MessageFullId message_full_id,
                                    QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  CHECK(!emoji.empty());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(INFO) << "Register dice " << emoji << " with value " << value << " from " << message_full_id << '/'
            << quick_reply_message_full_id << " from " << source;
  if (quick_reply_message_full_id.is_valid()) {
    dice_quick_reply_messages_[emoji].insert(quick_reply_message_full_id);
  } else {
    CHECK(message_full_id.get_dialog_id().is_valid());
    dice_messages_[emoji].insert(message_full_id);
  }

  if (!td::contains(dice_emojis_, emoji)) {
    if (quick_reply_message_full_id.is_valid() ||
        (message_full_id.get_message_id().is_any_server() &&
         message_full_id.get_dialog_id().get_type() != DialogType::SecretChat)) {
      send_closure(G()->config_manager(), &ConfigManager::reget_app_config, Promise<Unit>());
    }
    return;
  }

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_dice(emoji));
  bool need_load = false;
  StickerSet *sticker_set = nullptr;
  if (!special_sticker_set.id_.is_valid()) {
    need_load = true;
  } else {
    sticker_set = get_sticker_set(special_sticker_set.id_);
    CHECK(sticker_set != nullptr);
    need_load = !sticker_set->was_loaded_;
  }

  if (need_load) {
    LOG(INFO) << "Waiting for a dice sticker set needed in " << message_full_id << '/' << quick_reply_message_full_id;
    load_special_sticker_set(special_sticker_set);
  } else {
    // TODO reload once in a while
    // reload_special_sticker_set(special_sticker_set, sticker_set->is_loaded_ ? sticker_set->hash_ : 0);
  }
}

void StickersManager::unregister_dice(const string &emoji, int32 value, MessageFullId message_full_id,
                                      QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  CHECK(!emoji.empty());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(INFO) << "Unregister dice " << emoji << " with value " << value << " from " << message_full_id << '/'
            << quick_reply_message_full_id << " from " << source;
  if (quick_reply_message_full_id.is_valid()) {
    auto &message_ids = dice_quick_reply_messages_[emoji];
    auto is_deleted = message_ids.erase(quick_reply_message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << emoji << ' ' << value << ' ' << quick_reply_message_full_id;

    if (message_ids.empty()) {
      dice_quick_reply_messages_.erase(emoji);
    }
  } else {
    auto &message_ids = dice_messages_[emoji];
    auto is_deleted = message_ids.erase(message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << emoji << ' ' << value << ' ' << message_full_id;

    if (message_ids.empty()) {
      dice_messages_.erase(emoji);
    }
  }
}

void StickersManager::register_emoji(const string &emoji, CustomEmojiId custom_emoji_id, MessageFullId message_full_id,
                                     QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  CHECK(!emoji.empty());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(INFO) << "Register emoji " << emoji << " with " << custom_emoji_id << " from " << message_full_id << '/'
            << quick_reply_message_full_id << " from " << source;
  if (custom_emoji_id.is_valid()) {
    auto &emoji_messages_ptr = custom_emoji_messages_[custom_emoji_id];
    if (emoji_messages_ptr == nullptr) {
      emoji_messages_ptr = make_unique<CustomEmojiMessages>();
    }
    auto &emoji_messages = *emoji_messages_ptr;
    if (emoji_messages.message_full_ids_.empty() && emoji_messages.quick_reply_message_full_ids_.empty()) {
      if (!disable_animated_emojis_ && custom_emoji_to_sticker_id_.count(custom_emoji_id) == 0) {
        load_custom_emoji_sticker_from_database_force(custom_emoji_id);
        if (custom_emoji_to_sticker_id_.count(custom_emoji_id) == 0) {
          get_custom_emoji_stickers({custom_emoji_id}, false, Promise<td_api::object_ptr<td_api::stickers>>());
        }
      }
      emoji_messages.sticker_id_ = get_custom_animated_emoji_sticker_id(custom_emoji_id);
    }
    if (quick_reply_message_full_id.is_valid()) {
      emoji_messages.quick_reply_message_full_ids_.insert(quick_reply_message_full_id);
    } else {
      CHECK(message_full_id.get_dialog_id().is_valid());
      emoji_messages.message_full_ids_.insert(message_full_id);
    }
    return;
  }

  auto &emoji_messages_ptr = emoji_messages_[emoji];
  if (emoji_messages_ptr == nullptr) {
    emoji_messages_ptr = make_unique<EmojiMessages>();
  }
  auto &emoji_messages = *emoji_messages_ptr;
  if (emoji_messages.message_full_ids_.empty() && emoji_messages.quick_reply_message_full_ids_.empty()) {
    emoji_messages.animated_emoji_sticker_ = get_animated_emoji_sticker(emoji);
    emoji_messages.sound_file_id_ = get_animated_emoji_sound_file_id(emoji);
  }
  if (quick_reply_message_full_id.is_valid()) {
    emoji_messages.quick_reply_message_full_ids_.insert(quick_reply_message_full_id);
  } else {
    CHECK(message_full_id.get_dialog_id().is_valid());
    emoji_messages.message_full_ids_.insert(message_full_id);
  }
}

void StickersManager::unregister_emoji(const string &emoji, CustomEmojiId custom_emoji_id,
                                       MessageFullId message_full_id,
                                       QuickReplyMessageFullId quick_reply_message_full_id, const char *source) {
  CHECK(!emoji.empty());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(INFO) << "Unregister emoji " << emoji << " with " << custom_emoji_id << " from " << message_full_id << '/'
            << quick_reply_message_full_id << " from " << source;
  if (custom_emoji_id.is_valid()) {
    auto it = custom_emoji_messages_.find(custom_emoji_id);
    CHECK(it != custom_emoji_messages_.end());
    if (quick_reply_message_full_id.is_valid()) {
      auto is_deleted = it->second->quick_reply_message_full_ids_.erase(quick_reply_message_full_id) > 0;
      LOG_CHECK(is_deleted) << source << ' ' << custom_emoji_id << ' ' << quick_reply_message_full_id;
    } else {
      auto is_deleted = it->second->message_full_ids_.erase(message_full_id) > 0;
      LOG_CHECK(is_deleted) << source << ' ' << custom_emoji_id << ' ' << message_full_id;
    }
    if (it->second->message_full_ids_.empty() && it->second->quick_reply_message_full_ids_.empty()) {
      custom_emoji_messages_.erase(it);
    }
    return;
  }

  auto it = emoji_messages_.find(emoji);
  CHECK(it != emoji_messages_.end());
  if (quick_reply_message_full_id.is_valid()) {
    auto is_deleted = it->second->quick_reply_message_full_ids_.erase(quick_reply_message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << custom_emoji_id << ' ' << quick_reply_message_full_id;
  } else {
    auto is_deleted = it->second->message_full_ids_.erase(message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << custom_emoji_id << ' ' << message_full_id;
  }
  if (it->second->message_full_ids_.empty() && it->second->quick_reply_message_full_ids_.empty()) {
    emoji_messages_.erase(it);
  }
}

void StickersManager::get_animated_emoji(string emoji, bool is_recursive,
                                         Promise<td_api::object_ptr<td_api::animatedEmoji>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(nullptr);
    }

    pending_get_animated_emoji_queries_.push_back(
        PromiseCreator::lambda([actor_id = actor_id(this), emoji = std::move(emoji),
                                promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_animated_emoji, std::move(emoji), true, std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  promise.set_value(get_animated_emoji_object(get_animated_emoji_sticker(sticker_set, emoji),
                                              get_animated_emoji_sound_file_id(emoji)));
}

void StickersManager::get_all_animated_emojis(bool is_recursive,
                                              Promise<td_api::object_ptr<td_api::emojis>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(td_api::make_object<td_api::emojis>());
    }

    pending_get_animated_emoji_queries_.push_back(PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_all_animated_emojis, true, std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  auto emojis = transform(sticker_set->sticker_ids_, [&](FileId sticker_id) {
    auto s = get_sticker(sticker_id);
    CHECK(s != nullptr);
    return s->alt_;
  });
  promise.set_value(td_api::make_object<td_api::emojis>(std::move(emojis)));
}

void StickersManager::get_custom_emoji_reaction_generic_animations(
    bool is_recursive, Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::generic_animations());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(td_api::make_object<td_api::stickers>());
    }

    pending_get_generic_animations_queries_.push_back(PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_custom_emoji_reaction_generic_animations, true,
                         std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  promise.set_value(get_stickers_object(sticker_set->sticker_ids_));
}

void StickersManager::get_default_emoji_statuses(
    bool is_recursive, Promise<td_api::object_ptr<td_api::emojiStatusCustomEmojis>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::default_statuses());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(td_api::make_object<td_api::emojiStatusCustomEmojis>());
    }

    pending_get_default_statuses_queries_.push_back(PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_default_emoji_statuses, true, std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  vector<int64> custom_emoji_ids;
  for (auto sticker_id : sticker_set->sticker_ids_) {
    auto custom_emoji_id = get_custom_emoji_id(sticker_id);
    if (!custom_emoji_id.is_valid()) {
      LOG(ERROR) << "Ignore wrong sticker " << sticker_id;
      continue;
    }
    custom_emoji_ids.push_back(custom_emoji_id.get());
    if (custom_emoji_ids.size() >= 8) {
      break;
    }
  }
  promise.set_value(td_api::make_object<td_api::emojiStatusCustomEmojis>(std::move(custom_emoji_ids)));
}

int StickersManager::is_custom_emoji_from_sticker_set(CustomEmojiId custom_emoji_id,
                                                      StickerSetId sticker_set_id) const {
  const auto *sticker_set = get_sticker_set(sticker_set_id);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    return -1;
  }
  for (auto sticker_id : sticker_set->sticker_ids_) {
    if (get_custom_emoji_id(sticker_id) == custom_emoji_id) {
      return 1;
    }
  }
  return 0;
}

bool StickersManager::is_default_emoji_status(CustomEmojiId custom_emoji_id) {
  return is_custom_emoji_from_sticker_set(
             custom_emoji_id, add_special_sticker_set(SpecialStickerSetType::default_statuses()).id_) == 1 ||
         is_custom_emoji_from_sticker_set(
             custom_emoji_id, add_special_sticker_set(SpecialStickerSetType::default_channel_statuses()).id_) == 1;
}

void StickersManager::get_default_channel_emoji_statuses(
    bool is_recursive, Promise<td_api::object_ptr<td_api::emojiStatusCustomEmojis>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::default_channel_statuses());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(td_api::make_object<td_api::emojiStatusCustomEmojis>());
    }

    pending_get_default_channel_statuses_queries_.push_back(PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_default_channel_emoji_statuses, true, std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  vector<int64> custom_emoji_ids;
  for (auto sticker_id : sticker_set->sticker_ids_) {
    auto custom_emoji_id = get_custom_emoji_id(sticker_id);
    if (!custom_emoji_id.is_valid()) {
      LOG(ERROR) << "Ignore wrong sticker " << sticker_id;
      continue;
    }
    custom_emoji_ids.push_back(custom_emoji_id.get());
    if (custom_emoji_ids.size() >= 8) {
      break;
    }
  }
  promise.set_value(td_api::make_object<td_api::emojiStatusCustomEmojis>(std::move(custom_emoji_ids)));
}

void StickersManager::get_default_topic_icons(bool is_recursive,
                                              Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::default_topic_icons());
  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    if (is_recursive) {
      return promise.set_value(td_api::make_object<td_api::stickers>());
    }

    pending_get_default_topic_icons_queries_.push_back(PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_default_topic_icons, true, std::move(promise));
          }
        }));
    load_special_sticker_set(special_sticker_set);
    return;
  }

  if (!is_recursive && td_->auth_manager_->is_bot() && G()->unix_time() >= sticker_set->expires_at_) {
    auto reload_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &StickersManager::get_default_topic_icons, true, std::move(promise));
          }
        });
    do_reload_sticker_set(sticker_set->id_, get_input_sticker_set(sticker_set), sticker_set->hash_,
                          std::move(reload_promise), "get_default_topic_icons");
    return;
  }

  promise.set_value(get_stickers_object(sticker_set->sticker_ids_));
}

void StickersManager::load_custom_emoji_sticker_from_database_force(CustomEmojiId custom_emoji_id) {
  if (!G()->use_sqlite_pmc()) {
    return;
  }

  auto value = G()->td_db()->get_sqlite_sync_pmc()->get(get_custom_emoji_database_key(custom_emoji_id));
  if (value.empty()) {
    LOG(INFO) << "Failed to load " << custom_emoji_id << " from database";
    return;
  }

  LOG(INFO) << "Synchronously loaded " << custom_emoji_id << " of size " << value.size() << " from database";
  CustomEmojiLogEvent log_event;
  if (log_event_parse(log_event, value).is_error()) {
    LOG(ERROR) << "Delete invalid " << custom_emoji_id << " value from database";
    G()->td_db()->get_sqlite_sync_pmc()->erase(get_custom_emoji_database_key(custom_emoji_id));
  }
}

void StickersManager::load_custom_emoji_sticker_from_database(CustomEmojiId custom_emoji_id, Promise<Unit> &&promise) {
  CHECK(custom_emoji_id.is_valid());
  if (!G()->use_sqlite_pmc()) {
    return promise.set_value(Unit());
  }

  auto &queries = custom_emoji_load_queries_[custom_emoji_id];
  queries.push_back(std::move(promise));
  if (queries.size() == 1) {
    LOG(INFO) << "Trying to load " << custom_emoji_id << " from database";
    G()->td_db()->get_sqlite_pmc()->get(
        get_custom_emoji_database_key(custom_emoji_id), PromiseCreator::lambda([custom_emoji_id](string value) {
          send_closure(G()->stickers_manager(), &StickersManager::on_load_custom_emoji_from_database, custom_emoji_id,
                       std::move(value));
        }));
  }
}

void StickersManager::on_load_custom_emoji_from_database(CustomEmojiId custom_emoji_id, string value) {
  auto it = custom_emoji_load_queries_.find(custom_emoji_id);
  CHECK(it != custom_emoji_load_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  custom_emoji_load_queries_.erase(it);

  if (!value.empty()) {
    LOG(INFO) << "Successfully loaded " << custom_emoji_id << " of size " << value.size() << " from database";
    CustomEmojiLogEvent log_event;
    if (log_event_parse(log_event, value).is_error()) {
      LOG(ERROR) << "Delete invalid " << custom_emoji_id << " value from database";
      G()->td_db()->get_sqlite_pmc()->erase(get_custom_emoji_database_key(custom_emoji_id), Auto());
    }
  } else {
    LOG(INFO) << "Failed to load " << custom_emoji_id << " from database";
  }

  set_promises(promises);
}

td_api::object_ptr<td_api::sticker> StickersManager::get_custom_emoji_sticker_object(CustomEmojiId custom_emoji_id) {
  auto file_id = custom_emoji_to_sticker_id_.get(custom_emoji_id);
  if (!file_id.is_valid()) {
    return nullptr;
  }
  auto s = get_sticker(file_id);
  LOG_CHECK(s != nullptr) << file_id << ' ' << stickers_.calc_size();
  CHECK(s->type_ == StickerType::CustomEmoji);
  if (s->emoji_receive_date_ < G()->unix_time() - 86400 && !s->is_being_reloaded_) {
    s->is_being_reloaded_ = true;
    LOG(INFO) << "Reload " << custom_emoji_id;
    auto promise = PromiseCreator::lambda(
        [actor_id =
             actor_id(this)](Result<vector<telegram_api::object_ptr<telegram_api::Document>>> r_documents) mutable {
          send_closure(actor_id, &StickersManager::on_get_custom_emoji_documents, std::move(r_documents),
                       vector<CustomEmojiId>(), Promise<td_api::object_ptr<td_api::stickers>>());
        });
    td_->create_handler<GetCustomEmojiDocumentsQuery>(std::move(promise))->send({custom_emoji_id});
  }
  return get_sticker_object(file_id);
}

td_api::object_ptr<td_api::stickers> StickersManager::get_custom_emoji_stickers_object(
    const vector<CustomEmojiId> &custom_emoji_ids) {
  vector<td_api::object_ptr<td_api::sticker>> stickers;
  auto update_before_date = G()->unix_time() - 86400;
  vector<CustomEmojiId> reload_custom_emoji_ids;
  for (auto custom_emoji_id : custom_emoji_ids) {
    auto file_id = custom_emoji_to_sticker_id_.get(custom_emoji_id);
    if (file_id.is_valid()) {
      auto s = get_sticker(file_id);
      LOG_CHECK(s != nullptr) << file_id << ' ' << stickers_.calc_size();
      CHECK(s->type_ == StickerType::CustomEmoji);
      if (s->emoji_receive_date_ < update_before_date && !s->is_being_reloaded_) {
        s->is_being_reloaded_ = true;
        reload_custom_emoji_ids.push_back(custom_emoji_id);
      }

      auto sticker = get_sticker_object(file_id);
      CHECK(sticker != nullptr);
      stickers.push_back(std::move(sticker));
    }
  }
  if (!reload_custom_emoji_ids.empty()) {
    LOG(INFO) << "Reload " << reload_custom_emoji_ids;
    auto promise = PromiseCreator::lambda(
        [actor_id =
             actor_id(this)](Result<vector<telegram_api::object_ptr<telegram_api::Document>>> r_documents) mutable {
          send_closure(actor_id, &StickersManager::on_get_custom_emoji_documents, std::move(r_documents),
                       vector<CustomEmojiId>(), Promise<td_api::object_ptr<td_api::stickers>>());
        });
    td_->create_handler<GetCustomEmojiDocumentsQuery>(std::move(promise))->send(std::move(reload_custom_emoji_ids));
  }
  return td_api::make_object<td_api::stickers>(std::move(stickers));
}

void StickersManager::get_custom_emoji_stickers_unlimited(vector<CustomEmojiId> custom_emoji_ids,
                                                          Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  if (custom_emoji_ids.size() <= MAX_GET_CUSTOM_EMOJI_STICKERS) {
    return get_custom_emoji_stickers(std::move(custom_emoji_ids), true, std::move(promise));
  }

  MultiPromiseActorSafe mpas{"GetCustomEmojiStickersMultiPromiseActor"};
  mpas.add_promise(
      PromiseCreator::lambda([actor_id = actor_id(this), custom_emoji_ids, promise = std::move(promise)](Unit) mutable {
        send_closure(actor_id, &StickersManager::on_get_custom_emoji_stickers_unlimited, std::move(custom_emoji_ids),
                     std::move(promise));
      }));
  auto lock = mpas.get_promise();
  for (auto &slice_custom_emoji_ids : vector_split(std::move(custom_emoji_ids), MAX_GET_CUSTOM_EMOJI_STICKERS)) {
    get_custom_emoji_stickers(std::move(slice_custom_emoji_ids), true,
                              PromiseCreator::lambda([promise = mpas.get_promise()](
                                                         Result<td_api::object_ptr<td_api::stickers>> result) mutable {
                                if (result.is_ok()) {
                                  promise.set_value(Unit());
                                } else {
                                  promise.set_error(result.move_as_error());
                                }
                              }));
  }
  lock.set_value(Unit());
}

void StickersManager::on_get_custom_emoji_stickers_unlimited(vector<CustomEmojiId> custom_emoji_ids,
                                                             Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  promise.set_value(get_custom_emoji_stickers_object(custom_emoji_ids));
}

void StickersManager::get_custom_emoji_stickers(vector<CustomEmojiId> custom_emoji_ids, bool use_database,
                                                Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (custom_emoji_ids.size() > MAX_GET_CUSTOM_EMOJI_STICKERS) {
    return promise.set_error(Status::Error(400, "Too many custom emoji identifiers specified"));
  }

  FlatHashSet<CustomEmojiId, CustomEmojiIdHash> unique_custom_emoji_ids;
  size_t j = 0;
  for (size_t i = 0; i < custom_emoji_ids.size(); i++) {
    auto custom_emoji_id = custom_emoji_ids[i];
    if (custom_emoji_id.is_valid() && unique_custom_emoji_ids.insert(custom_emoji_id).second) {
      custom_emoji_ids[j++] = custom_emoji_id;
    }
  }
  custom_emoji_ids.resize(j);

  vector<CustomEmojiId> unknown_custom_emoji_ids;
  for (auto custom_emoji_id : custom_emoji_ids) {
    if (custom_emoji_to_sticker_id_.count(custom_emoji_id) == 0) {
      unknown_custom_emoji_ids.push_back(custom_emoji_id);
    }
  }

  if (unknown_custom_emoji_ids.empty()) {
    return promise.set_value(get_custom_emoji_stickers_object(custom_emoji_ids));
  }

  if (use_database && G()->use_sqlite_pmc()) {
    MultiPromiseActorSafe mpas{"LoadCustomEmojiMultiPromiseActor"};
    mpas.add_promise(PromiseCreator::lambda(
        [actor_id = actor_id(this), custom_emoji_ids, promise = std::move(promise)](Unit) mutable {
          send_closure(actor_id, &StickersManager::get_custom_emoji_stickers, std::move(custom_emoji_ids), false,
                       std::move(promise));
        }));

    auto lock = mpas.get_promise();
    for (auto custom_emoji_id : unknown_custom_emoji_ids) {
      load_custom_emoji_sticker_from_database(custom_emoji_id, mpas.get_promise());
    }

    return lock.set_value(Unit());
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), custom_emoji_ids = std::move(custom_emoji_ids), promise = std::move(promise)](
          Result<vector<telegram_api::object_ptr<telegram_api::Document>>> r_documents) mutable {
        send_closure(actor_id, &StickersManager::on_get_custom_emoji_documents, std::move(r_documents),
                     std::move(custom_emoji_ids), std::move(promise));
      });
  td_->create_handler<GetCustomEmojiDocumentsQuery>(std::move(query_promise))
      ->send(std::move(unknown_custom_emoji_ids));
}

void StickersManager::on_get_custom_emoji_documents(
    Result<vector<telegram_api::object_ptr<telegram_api::Document>>> &&r_documents,
    vector<CustomEmojiId> &&custom_emoji_ids, Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (r_documents.is_error()) {
    return promise.set_error(r_documents.move_as_error());
  }
  auto documents = r_documents.move_as_ok();

  for (auto &document : documents) {
    LOG(INFO) << "Receive " << to_string(document);
    if (document->get_id() == telegram_api::documentEmpty::ID) {
      continue;
    }

    on_get_sticker_document(std::move(document), StickerFormat::Unknown, "on_get_custom_emoji_documents");
  }

  promise.set_value(get_custom_emoji_stickers_object(custom_emoji_ids));
}

void StickersManager::get_default_custom_emoji_stickers(StickerListType sticker_list_type, bool force_reload,
                                                        Promise<td_api::object_ptr<td_api::stickers>> &&promise) {
  auto index = static_cast<int32>(sticker_list_type);
  if (are_default_custom_emoji_ids_loaded_[index] && !force_reload) {
    return get_custom_emoji_stickers_unlimited(default_custom_emoji_ids_[index], std::move(promise));
  }

  auto &queries = default_custom_emoji_ids_load_queries_[index];
  queries.push_back(std::move(promise));
  load_default_custom_emoji_ids(sticker_list_type, force_reload);
}

void StickersManager::get_sticker_list_emoji_statuses(
    StickerListType sticker_list_type, bool force_reload,
    Promise<td_api::object_ptr<td_api::emojiStatusCustomEmojis>> &&promise) {
  auto index = static_cast<int32>(sticker_list_type);
  if (are_default_custom_emoji_ids_loaded_[index] && !force_reload) {
    return promise.set_value(get_emoji_status_custom_emojis_object(default_custom_emoji_ids_[index]));
  }

  auto &queries = default_emoji_statuses_load_queries_[index];
  queries.push_back(std::move(promise));
  load_default_custom_emoji_ids(sticker_list_type, force_reload);
}

void StickersManager::load_default_custom_emoji_ids(StickerListType sticker_list_type, bool force_reload) {
  auto index = static_cast<int32>(sticker_list_type);
  if (default_custom_emoji_ids_load_queries_[index].size() + default_emoji_statuses_load_queries_[index].size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  if (G()->use_sqlite_pmc() && !are_default_custom_emoji_ids_loaded_[index]) {
    LOG(INFO) << "Trying to load " << sticker_list_type << " from database";
    return G()->td_db()->get_sqlite_pmc()->get(
        get_sticker_list_type_database_key(sticker_list_type),
        PromiseCreator::lambda([sticker_list_type, force_reload](string value) {
          send_closure(G()->stickers_manager(), &StickersManager::on_load_default_custom_emoji_ids_from_database,
                       sticker_list_type, force_reload, std::move(value));
        }));
  }

  reload_default_custom_emoji_ids(sticker_list_type);
}

class StickersManager::CustomEmojiIdsLogEvent {
 public:
  vector<CustomEmojiId> custom_emoji_ids_;
  int64 hash_ = 0;

  CustomEmojiIdsLogEvent() = default;

  CustomEmojiIdsLogEvent(vector<CustomEmojiId> custom_emoji_ids, int64 hash)
      : custom_emoji_ids_(std::move(custom_emoji_ids)), hash_(hash) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(custom_emoji_ids_, storer);
    td::store(hash_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(custom_emoji_ids_, parser);
    td::parse(hash_, parser);
  }
};

void StickersManager::on_load_default_custom_emoji_ids_from_database(StickerListType sticker_list_type,
                                                                     bool force_reload, string value) {
  if (G()->close_flag()) {
    auto index = static_cast<int32>(sticker_list_type);
    fail_promises(default_custom_emoji_ids_load_queries_[index], Global::request_aborted_error());
    fail_promises(default_emoji_statuses_load_queries_[index], Global::request_aborted_error());
    return;
  }

  if (value.empty()) {
    return reload_default_custom_emoji_ids(sticker_list_type);
  }

  LOG(INFO) << "Successfully loaded " << sticker_list_type << " of size " << value.size() << " from database";
  CustomEmojiIdsLogEvent log_event;
  if (log_event_parse(log_event, value).is_error()) {
    LOG(ERROR) << "Delete invalid " << sticker_list_type << " from database";
    G()->td_db()->get_sqlite_pmc()->erase(get_sticker_list_type_database_key(sticker_list_type), Auto());
    return reload_default_custom_emoji_ids(sticker_list_type);
  }

  on_get_default_custom_emoji_ids_success(sticker_list_type, std::move(log_event.custom_emoji_ids_), log_event.hash_);
  if (force_reload) {
    reload_default_custom_emoji_ids(sticker_list_type);
  }
}

void StickersManager::reload_default_custom_emoji_ids(StickerListType sticker_list_type) {
  if (G()->close_flag()) {
    auto index = static_cast<int32>(sticker_list_type);
    fail_promises(default_custom_emoji_ids_load_queries_[index], Global::request_aborted_error());
    fail_promises(default_emoji_statuses_load_queries_[index], Global::request_aborted_error());
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  auto index = static_cast<int32>(sticker_list_type);
  if (are_default_custom_emoji_ids_being_loaded_[index]) {
    return;
  }
  are_default_custom_emoji_ids_being_loaded_[index] = true;

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), sticker_list_type](
                                 Result<telegram_api::object_ptr<telegram_api::EmojiList>> r_emoji_list) mutable {
        send_closure(actor_id, &StickersManager::on_get_default_custom_emoji_ids, sticker_list_type,
                     std::move(r_emoji_list));
      });
  td_->create_handler<GetDefaultDialogPhotoEmojisQuery>(std::move(query_promise))
      ->send(sticker_list_type, default_custom_emoji_ids_hash_[index]);
}

void StickersManager::on_get_default_custom_emoji_ids(
    StickerListType sticker_list_type, Result<telegram_api::object_ptr<telegram_api::EmojiList>> r_emoji_list) {
  G()->ignore_result_if_closing(r_emoji_list);

  auto index = static_cast<int32>(sticker_list_type);
  CHECK(are_default_custom_emoji_ids_being_loaded_[index]);
  are_default_custom_emoji_ids_being_loaded_[index] = false;

  if (r_emoji_list.is_error()) {
    fail_promises(default_custom_emoji_ids_load_queries_[index], r_emoji_list.move_as_error());
    fail_promises(default_emoji_statuses_load_queries_[index], r_emoji_list.move_as_error());
    return;
  }

  auto emoji_list_ptr = r_emoji_list.move_as_ok();
  int32 constructor_id = emoji_list_ptr->get_id();
  if (constructor_id == telegram_api::emojiListNotModified::ID) {
    LOG(INFO) << "The " << sticker_list_type << " isn't modified";
    if (!are_default_custom_emoji_ids_loaded_[index]) {
      on_get_default_custom_emoji_ids_success(sticker_list_type, {}, 0);
    }
    auto sticker_promises = std::move(default_custom_emoji_ids_load_queries_[index]);
    auto status_promises = std::move(default_emoji_statuses_load_queries_[index]);
    reset_to_empty(default_custom_emoji_ids_load_queries_[index]);
    reset_to_empty(default_emoji_statuses_load_queries_[index]);
    for (auto &promise : sticker_promises) {
      CHECK(!promise);
    }
    for (auto &promise : status_promises) {
      CHECK(!promise);
    }
    return;
  }
  CHECK(constructor_id == telegram_api::emojiList::ID);
  auto emoji_list = move_tl_object_as<telegram_api::emojiList>(emoji_list_ptr);
  auto custom_emoji_ids = CustomEmojiId::get_custom_emoji_ids(emoji_list->document_id_);
  auto hash = emoji_list->hash_;

  if (G()->use_sqlite_pmc()) {
    CustomEmojiIdsLogEvent log_event(custom_emoji_ids, hash);
    G()->td_db()->get_sqlite_pmc()->set(get_sticker_list_type_database_key(sticker_list_type),
                                        log_event_store(log_event).as_slice().str(), Auto());
  }

  on_get_default_custom_emoji_ids_success(sticker_list_type, std::move(custom_emoji_ids), hash);
}

void StickersManager::on_get_default_custom_emoji_ids_success(StickerListType sticker_list_type,
                                                              vector<CustomEmojiId> custom_emoji_ids, int64 hash) {
  auto index = static_cast<int32>(sticker_list_type);
  LOG(INFO) << "Load " << custom_emoji_ids.size() << ' ' << sticker_list_type;
  default_custom_emoji_ids_[index] = std::move(custom_emoji_ids);
  default_custom_emoji_ids_hash_[index] = hash;
  are_default_custom_emoji_ids_loaded_[index] = true;

  auto sticker_promises = std::move(default_custom_emoji_ids_load_queries_[index]);
  auto status_promises = std::move(default_emoji_statuses_load_queries_[index]);
  reset_to_empty(default_custom_emoji_ids_load_queries_[index]);
  reset_to_empty(default_emoji_statuses_load_queries_[index]);
  for (auto &promise : sticker_promises) {
    get_custom_emoji_stickers_unlimited(default_custom_emoji_ids_[index], std::move(promise));
  }
  for (auto &promise : status_promises) {
    promise.set_value(get_emoji_status_custom_emojis_object(default_custom_emoji_ids_[index]));
  }
}

void StickersManager::get_animated_emoji_click_sticker(const string &message_text, MessageFullId message_full_id,
                                                       Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  if (disable_animated_emojis_ || td_->auth_manager_->is_bot()) {
    return promise.set_value(nullptr);
  }

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji_click());
  if (!special_sticker_set.id_.is_valid()) {
    // don't wait for the first load of the sticker set from the server
    load_special_sticker_set(special_sticker_set);
    return promise.set_value(nullptr);
  }

  auto sticker_set = get_sticker_set(special_sticker_set.id_);
  CHECK(sticker_set != nullptr);
  if (sticker_set->was_loaded_) {
    return choose_animated_emoji_click_sticker(sticker_set, message_text, message_full_id, Time::now(),
                                               std::move(promise));
  }

  LOG(INFO) << "Waiting for an emoji click sticker set needed in " << message_full_id;
  load_special_sticker_set(special_sticker_set);

  PendingGetAnimatedEmojiClickSticker pending_request;
  pending_request.message_text_ = message_text;
  pending_request.message_full_id_ = message_full_id;
  pending_request.start_time_ = Time::now();
  pending_request.promise_ = std::move(promise);
  pending_get_animated_emoji_click_stickers_.push_back(std::move(pending_request));
}

int StickersManager::get_emoji_number(Slice emoji) {
  // '0'-'9' + U+20E3
  auto data = emoji.ubegin();
  if (emoji.size() != 4 || emoji[0] < '0' || emoji[0] > '9' || data[1] != 0xE2 || data[2] != 0x83 || data[3] != 0xA3) {
    return -1;
  }
  return emoji[0] - '0';
}

vector<FileId> StickersManager::get_animated_emoji_click_stickers(const StickerSet *sticker_set, Slice emoji) const {
  vector<FileId> result;
  for (auto sticker_id : sticker_set->sticker_ids_) {
    auto s = get_sticker(sticker_id);
    CHECK(s != nullptr);
    if (remove_emoji_modifiers(s->alt_) == emoji) {
      result.push_back(sticker_id);
    }
  }
  if (result.empty()) {
    const static vector<string> heart_emojis{"💛", "💙", "💚", "💜", "🧡", "🖤", "🤎", "🤍"};
    if (td::contains(heart_emojis, emoji)) {
      return get_animated_emoji_click_stickers(sticker_set, Slice("❤"));
    }
  }
  return result;
}

void StickersManager::choose_animated_emoji_click_sticker(const StickerSet *sticker_set, string message_text,
                                                          MessageFullId message_full_id, double start_time,
                                                          Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  CHECK(sticker_set->was_loaded_);
  remove_emoji_modifiers_in_place(message_text);
  if (message_text.empty()) {
    return promise.set_error(Status::Error(400, "Message is not an animated emoji message"));
  }

  if (disable_animated_emojis_ || td_->auth_manager_->is_bot()) {
    return promise.set_value(nullptr);
  }

  auto now = Time::now();
  if (last_clicked_animated_emoji_ == message_text && last_clicked_animated_emoji_message_full_id_ == message_full_id &&
      next_click_animated_emoji_message_time_ >= now + 2 * MIN_ANIMATED_EMOJI_CLICK_DELAY) {
    return promise.set_value(nullptr);
  }

  auto all_sticker_ids = get_animated_emoji_click_stickers(sticker_set, message_text);
  vector<std::pair<int, FileId>> found_stickers;
  for (auto sticker_id : all_sticker_ids) {
    auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
    if (it != sticker_set->sticker_emojis_map_.end()) {
      for (auto &emoji : it->second) {
        auto number = get_emoji_number(emoji);
        if (number > 0) {
          found_stickers.emplace_back(number, sticker_id);
        }
      }
    }
  }
  if (found_stickers.empty()) {
    LOG(INFO) << "There is no click effect for " << message_text << " from " << message_full_id;
    return promise.set_value(nullptr);
  }

  if (last_clicked_animated_emoji_message_full_id_ != message_full_id) {
    flush_pending_animated_emoji_clicks();
    last_clicked_animated_emoji_message_full_id_ = message_full_id;
  }
  if (last_clicked_animated_emoji_ != message_text) {
    pending_animated_emoji_clicks_.clear();
    last_clicked_animated_emoji_ = std::move(message_text);
  }

  if (!pending_animated_emoji_clicks_.empty() && found_stickers.size() >= 2) {
    for (auto it = found_stickers.begin(); it != found_stickers.end(); ++it) {
      if (it->first == pending_animated_emoji_clicks_.back().first) {
        found_stickers.erase(it);
        break;
      }
    }
  }

  CHECK(!found_stickers.empty());
  auto result = found_stickers[Random::fast(0, narrow_cast<int>(found_stickers.size()) - 1)];

  pending_animated_emoji_clicks_.emplace_back(result.first, start_time);
  if (pending_animated_emoji_clicks_.size() == 5) {
    flush_pending_animated_emoji_clicks();
  } else {
    set_timeout_in(0.5);
  }
  if (now >= next_click_animated_emoji_message_time_) {
    next_click_animated_emoji_message_time_ = now + MIN_ANIMATED_EMOJI_CLICK_DELAY;
    promise.set_value(get_sticker_object(result.second, false, true));
  } else {
    create_actor<SleepActor>("SendClickAnimatedEmojiMessageResponse", next_click_animated_emoji_message_time_ - now,
                             PromiseCreator::lambda([actor_id = actor_id(this), sticker_id = result.second,
                                                     promise = std::move(promise)](Unit) mutable {
                               send_closure(actor_id, &StickersManager::send_click_animated_emoji_message_response,
                                            sticker_id, std::move(promise));
                             }))
        .release();
    next_click_animated_emoji_message_time_ += MIN_ANIMATED_EMOJI_CLICK_DELAY;
  }
}

void StickersManager::send_click_animated_emoji_message_response(
    FileId sticker_id, Promise<td_api::object_ptr<td_api::sticker>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  promise.set_value(get_sticker_object(sticker_id, false, true));
}

void StickersManager::timeout_expired() {
  flush_pending_animated_emoji_clicks();
}

void StickersManager::flush_pending_animated_emoji_clicks() {
  if (G()->close_flag()) {
    return;
  }
  if (pending_animated_emoji_clicks_.empty()) {
    return;
  }
  auto clicks = std::move(pending_animated_emoji_clicks_);
  pending_animated_emoji_clicks_.clear();
  auto message_full_id = last_clicked_animated_emoji_message_full_id_;
  last_clicked_animated_emoji_message_full_id_ = MessageFullId();
  auto emoji = std::move(last_clicked_animated_emoji_);
  last_clicked_animated_emoji_.clear();

  if (td_->messages_manager_->is_message_edited_recently(message_full_id, 1)) {
    // includes deleted message_full_id
    return;
  }
  auto dialog_id = message_full_id.get_dialog_id();
  auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
  if (input_peer == nullptr) {
    return;
  }

  double start_time = clicks[0].second;
  auto data = json_encode<string>(json_object([&clicks, start_time](auto &o) {
    o("v", 1);
    o("a", json_array(clicks, [start_time](auto &click) {
        return json_object([&click, start_time](auto &o) {
          o("i", click.first);
          auto t = static_cast<int32>((click.second - start_time) * 100);
          o("t", JsonRaw(PSLICE() << (t / 100) << '.' << (t < 10 ? "0" : "") << (t % 100)));
        });
      }));
  }));

  td_->create_handler<SendAnimatedEmojiClicksQuery>()->send(
      dialog_id, std::move(input_peer),
      make_tl_object<telegram_api::sendMessageEmojiInteraction>(
          emoji, message_full_id.get_message_id().get_server_message_id().get(),
          make_tl_object<telegram_api::dataJSON>(data)));

  on_send_animated_emoji_clicks(dialog_id, emoji);
}

void StickersManager::on_send_animated_emoji_clicks(DialogId dialog_id, const string &emoji) {
  flush_sent_animated_emoji_clicks();

  if (!sent_animated_emoji_clicks_.empty() && sent_animated_emoji_clicks_.back().dialog_id_ == dialog_id &&
      sent_animated_emoji_clicks_.back().emoji_ == emoji) {
    sent_animated_emoji_clicks_.back().send_time_ = Time::now();
    return;
  }

  SentAnimatedEmojiClicks clicks;
  clicks.send_time_ = Time::now();
  clicks.dialog_id_ = dialog_id;
  clicks.emoji_ = emoji;
  sent_animated_emoji_clicks_.push_back(std::move(clicks));
}

void StickersManager::flush_sent_animated_emoji_clicks() {
  if (sent_animated_emoji_clicks_.empty()) {
    return;
  }
  auto min_send_time = Time::now() - 30.0;
  auto it = sent_animated_emoji_clicks_.begin();
  while (it != sent_animated_emoji_clicks_.end() && it->send_time_ <= min_send_time) {
    ++it;
  }
  sent_animated_emoji_clicks_.erase(sent_animated_emoji_clicks_.begin(), it);
}

bool StickersManager::is_sent_animated_emoji_click(DialogId dialog_id, const string &emoji) {
  flush_sent_animated_emoji_clicks();
  for (const auto &click : sent_animated_emoji_clicks_) {
    if (click.dialog_id_ == dialog_id && click.emoji_ == emoji) {
      return true;
    }
  }
  return false;
}

Status StickersManager::on_animated_emoji_message_clicked(string &&emoji, MessageFullId message_full_id, string data) {
  if (td_->auth_manager_->is_bot() || disable_animated_emojis_) {
    return Status::OK();
  }

  TRY_RESULT(value, json_decode(data));
  if (value.type() != JsonValue::Type::Object) {
    return Status::Error("Expected an object");
  }
  auto &object = value.get_object();
  TRY_RESULT(version, object.get_required_int_field("v"));
  if (version != 1) {
    return Status::OK();
  }
  TRY_RESULT(array_value, object.extract_required_field("a", JsonValue::Type::Array));
  auto &array = array_value.get_array();
  if (array.size() > 20) {
    return Status::Error("Click array is too big");
  }
  vector<std::pair<int, double>> clicks;
  double previous_start_time = 0.0;
  double adjustment = 0.0;
  for (auto &click : array) {
    if (click.type() != JsonValue::Type::Object) {
      return Status::Error("Expected clicks as JSON objects");
    }
    auto &click_object = click.get_object();
    TRY_RESULT(index, click_object.get_required_int_field("i"));
    if (index <= 0 || index > 9) {
      return Status::Error("Wrong index");
    }
    TRY_RESULT(start_time, click_object.get_required_double_field("t"));
    if (!std::isfinite(start_time)) {
      return Status::Error("Receive invalid start time");
    }
    if (start_time < previous_start_time) {
      return Status::Error("Non-monotonic start time");
    }
    if (start_time > previous_start_time + 3) {
      return Status::Error("Too big delay between clicks");
    }
    previous_start_time = start_time;

    auto adjusted_start_time =
        clicks.empty() ? 0.0 : max(start_time + adjustment, clicks.back().second + MIN_ANIMATED_EMOJI_CLICK_DELAY);
    adjustment = adjusted_start_time - start_time;
    clicks.emplace_back(static_cast<int>(index), adjusted_start_time);
  }

  auto &special_sticker_set = add_special_sticker_set(SpecialStickerSetType::animated_emoji_click());
  if (special_sticker_set.id_.is_valid()) {
    auto sticker_set = get_sticker_set(special_sticker_set.id_);
    CHECK(sticker_set != nullptr);
    if (sticker_set->was_loaded_) {
      schedule_update_animated_emoji_clicked(sticker_set, emoji, message_full_id, std::move(clicks));
      return Status::OK();
    }
  }

  LOG(INFO) << "Waiting for an emoji click sticker set needed in " << message_full_id;
  load_special_sticker_set(special_sticker_set);

  PendingOnAnimatedEmojiClicked pending_request;
  pending_request.emoji_ = std::move(emoji);
  pending_request.message_full_id_ = message_full_id;
  pending_request.clicks_ = std::move(clicks);
  pending_on_animated_emoji_message_clicked_.push_back(std::move(pending_request));
  return Status::OK();
}

void StickersManager::schedule_update_animated_emoji_clicked(const StickerSet *sticker_set, Slice emoji,
                                                             MessageFullId message_full_id,
                                                             vector<std::pair<int, double>> clicks) {
  if (clicks.empty()) {
    return;
  }
  if (td_->messages_manager_->is_message_edited_recently(message_full_id, 2)) {
    // includes deleted message_full_id
    return;
  }
  auto dialog_id = message_full_id.get_dialog_id();
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Write)) {
    return;
  }

  auto all_sticker_ids = get_animated_emoji_click_stickers(sticker_set, emoji);
  FlatHashMap<int32, FileId> sticker_ids;
  for (auto sticker_id : all_sticker_ids) {
    auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
    if (it != sticker_set->sticker_emojis_map_.end()) {
      for (auto &sticker_emoji : it->second) {
        auto number = get_emoji_number(sticker_emoji);
        if (number > 0) {
          sticker_ids[number] = sticker_id;
        }
      }
    }
  }

  auto now = Time::now();
  auto start_time = max(now, next_update_animated_emoji_clicked_time_);
  for (const auto &click : clicks) {
    auto index = click.first;
    if (index <= 0) {
      return;
    }
    auto sticker_id = sticker_ids[index];
    if (!sticker_id.is_valid()) {
      LOG(INFO) << "Failed to find sticker for " << emoji << " with index " << index;
      return;
    }
    create_actor<SleepActor>("SendUpdateAnimatedEmojiClicked", start_time + click.second - now,
                             PromiseCreator::lambda([actor_id = actor_id(this), message_full_id, sticker_id](Unit) {
                               send_closure(actor_id, &StickersManager::send_update_animated_emoji_clicked,
                                            message_full_id, sticker_id);
                             }))
        .release();
  }
  next_update_animated_emoji_clicked_time_ = start_time + clicks.back().second + MIN_ANIMATED_EMOJI_CLICK_DELAY;
}

void StickersManager::send_update_animated_emoji_clicked(MessageFullId message_full_id, FileId sticker_id) {
  if (G()->close_flag() || disable_animated_emojis_ || td_->auth_manager_->is_bot()) {
    return;
  }
  if (td_->messages_manager_->is_message_edited_recently(message_full_id, 2)) {
    // includes deleted message_full_id
    return;
  }
  auto dialog_id = message_full_id.get_dialog_id();
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Write)) {
    return;
  }

  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateAnimatedEmojiMessageClicked>(
                   td_->dialog_manager_->get_chat_id_object(dialog_id, "updateAnimatedEmojiMessageClicked"),
                   message_full_id.get_message_id().get(), get_sticker_object(sticker_id, false, true)));
}

void StickersManager::view_featured_sticker_sets(const vector<StickerSetId> &sticker_set_ids) {
  for (auto sticker_set_id : sticker_set_ids) {
    auto set = get_sticker_set(sticker_set_id);
    if (set != nullptr && !set->is_viewed_) {
      auto type = static_cast<int32>(set->sticker_type_);
      if (td::contains(featured_sticker_set_ids_[type], sticker_set_id)) {
        need_update_featured_sticker_sets_[type] = true;
      }
      set->is_viewed_ = true;
      pending_viewed_featured_sticker_set_ids_.insert(sticker_set_id);
      update_sticker_set(set, "view_featured_sticker_sets");
    }
  }

  for (int32 type = 0; type < MAX_STICKER_TYPE; type++) {
    send_update_featured_sticker_sets(static_cast<StickerType>(type));
  }

  if (!pending_viewed_featured_sticker_set_ids_.empty() && !pending_featured_sticker_set_views_timeout_.has_timeout()) {
    LOG(INFO) << "Have pending viewed trending sticker sets";
    pending_featured_sticker_set_views_timeout_.set_callback(read_featured_sticker_sets);
    pending_featured_sticker_set_views_timeout_.set_callback_data(static_cast<void *>(td_));
    pending_featured_sticker_set_views_timeout_.set_timeout_in(MAX_FEATURED_STICKER_SET_VIEW_DELAY);
  }
}

void StickersManager::read_featured_sticker_sets(void *td_void) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td_void != nullptr);
  auto td = static_cast<Td *>(td_void);

  auto &set_ids = td->stickers_manager_->pending_viewed_featured_sticker_set_ids_;
  vector<StickerSetId> sticker_set_ids;
  for (auto sticker_set_id : set_ids) {
    sticker_set_ids.push_back(sticker_set_id);
  }
  set_ids.clear();
  td->create_handler<ReadFeaturedStickerSetsQuery>()->send(std::move(sticker_set_ids));
}

std::pair<int32, vector<StickerSetId>> StickersManager::get_archived_sticker_sets(StickerType sticker_type,
                                                                                  StickerSetId offset_sticker_set_id,
                                                                                  int32 limit, bool force,
                                                                                  Promise<Unit> &&promise) {
  if (limit <= 0) {
    promise.set_error(Status::Error(400, "Parameter limit must be positive"));
    return {};
  }

  auto type = static_cast<int32>(sticker_type);
  vector<StickerSetId> &sticker_set_ids = archived_sticker_set_ids_[type];
  int32 total_count = total_archived_sticker_set_count_[type];
  if (total_count >= 0) {
    auto offset_it = sticker_set_ids.begin();
    if (offset_sticker_set_id.is_valid()) {
      offset_it = std::find(sticker_set_ids.begin(), sticker_set_ids.end(), offset_sticker_set_id);
      if (offset_it == sticker_set_ids.end()) {
        offset_it = sticker_set_ids.begin();
      } else {
        ++offset_it;
      }
    }
    vector<StickerSetId> result;
    while (result.size() < static_cast<size_t>(limit)) {
      if (offset_it == sticker_set_ids.end()) {
        break;
      }
      auto sticker_set_id = *offset_it++;
      if (!sticker_set_id.is_valid()) {  // end of the list
        promise.set_value(Unit());
        return {total_count, std::move(result)};
      }
      result.push_back(sticker_set_id);
    }
    if (result.size() == static_cast<size_t>(limit) || force) {
      promise.set_value(Unit());
      return {total_count, std::move(result)};
    }
  }

  td_->create_handler<GetArchivedStickerSetsQuery>(std::move(promise))
      ->send(sticker_type, offset_sticker_set_id, limit);
  return {};
}

void StickersManager::on_get_archived_sticker_sets(
    StickerType sticker_type, StickerSetId offset_sticker_set_id,
    vector<tl_object_ptr<telegram_api::StickerSetCovered>> &&sticker_sets, int32 total_count) {
  auto type = static_cast<int32>(sticker_type);
  vector<StickerSetId> &sticker_set_ids = archived_sticker_set_ids_[type];
  if (!sticker_set_ids.empty() && sticker_set_ids.back() == StickerSetId()) {
    return;
  }
  if (total_count < 0) {
    LOG(ERROR) << "Receive " << total_count << " as total count of archived sticker sets";
  }

  // if 0 sticker sets are received, then set offset_sticker_set_id was found and there are no stickers after it
  // or it wasn't found and there are no archived sets at all
  bool is_last =
      sticker_sets.empty() && (!offset_sticker_set_id.is_valid() ||
                               (!sticker_set_ids.empty() && offset_sticker_set_id == sticker_set_ids.back()));

  total_archived_sticker_set_count_[type] = total_count;
  for (auto &sticker_set_covered : sticker_sets) {
    auto sticker_set_id =
        on_get_sticker_set_covered(std::move(sticker_set_covered), false, "on_get_archived_sticker_sets");
    if (sticker_set_id.is_valid()) {
      auto sticker_set = get_sticker_set(sticker_set_id);
      CHECK(sticker_set != nullptr);
      update_sticker_set(sticker_set, "on_get_archived_sticker_sets");

      if (!td::contains(sticker_set_ids, sticker_set_id)) {
        sticker_set_ids.push_back(sticker_set_id);
      }
    }
  }
  if (sticker_set_ids.size() >= static_cast<size_t>(total_count) || is_last) {
    if (sticker_set_ids.size() != static_cast<size_t>(total_count)) {
      LOG(ERROR) << "Expected total of " << total_count << " archived sticker sets, but " << sticker_set_ids.size()
                 << " found";
      total_archived_sticker_set_count_[type] = static_cast<int32>(sticker_set_ids.size());
    }
    sticker_set_ids.push_back(StickerSetId());
  }
  send_update_installed_sticker_sets();
}

td_api::object_ptr<td_api::trendingStickerSets> StickersManager::get_featured_sticker_sets(StickerType sticker_type,
                                                                                           int32 offset, int32 limit,
                                                                                           Promise<Unit> &&promise) {
  if (offset < 0) {
    promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
    return {};
  }

  if (limit < 0) {
    promise.set_error(Status::Error(400, "Parameter limit must be non-negative"));
    return {};
  }
  if (limit == 0) {
    offset = 0;
  }

  if (sticker_type == StickerType::Mask) {
    promise.set_value(Unit());
    return get_trending_sticker_sets_object(sticker_type, {});
  }
  auto type = static_cast<int32>(sticker_type);

  if (!are_featured_sticker_sets_loaded_[type]) {
    load_featured_sticker_sets(sticker_type, std::move(promise));
    return {};
  }
  reload_featured_sticker_sets(sticker_type, false);

  auto set_count = static_cast<int32>(featured_sticker_set_ids_[type].size());
  if (offset < set_count) {
    if (limit > set_count - offset) {
      limit = set_count - offset;
    }
    promise.set_value(Unit());
    auto begin = featured_sticker_set_ids_[type].begin() + offset;
    return get_trending_sticker_sets_object(sticker_type, {begin, begin + limit});
  }

  if (offset == set_count && are_old_featured_sticker_sets_invalidated_[type]) {
    invalidate_old_featured_sticker_sets(sticker_type);
  }

  auto total_count =
      set_count + (old_featured_sticker_set_count_[type] == -1 ? 1 : old_featured_sticker_set_count_[type]);
  if (offset < total_count || old_featured_sticker_set_count_[type] == -1) {
    offset -= set_count;
    set_count = static_cast<int32>(old_featured_sticker_set_ids_[type].size());
    if (offset < set_count) {
      if (limit > set_count - offset) {
        limit = set_count - offset;
      }
      promise.set_value(Unit());
      auto begin = old_featured_sticker_set_ids_[type].begin() + offset;
      return get_trending_sticker_sets_object(sticker_type, {begin, begin + limit});
    }
    if (offset > set_count) {
      promise.set_error(
          Status::Error(400, "Too big offset specified; trending sticker sets can be received only consequently"));
      return {};
    }

    load_old_featured_sticker_sets(sticker_type, std::move(promise));
    return {};
  }

  promise.set_value(Unit());
  return get_trending_sticker_sets_object(sticker_type, {});
}

void StickersManager::on_old_featured_sticker_sets_invalidated(StickerType sticker_type) {
  if (sticker_type != StickerType::Regular) {
    return;
  }

  auto type = static_cast<int32>(sticker_type);
  LOG(INFO) << "Invalidate old trending sticker sets";
  are_old_featured_sticker_sets_invalidated_[type] = true;

  if (!G()->use_sqlite_pmc()) {
    return;
  }

  G()->td_db()->get_binlog_pmc()->set("invalidate_old_featured_sticker_sets", "1");
}

void StickersManager::invalidate_old_featured_sticker_sets(StickerType sticker_type) {
  if (G()->close_flag()) {
    return;
  }
  if (sticker_type != StickerType::Regular) {
    return;
  }

  auto type = static_cast<int32>(sticker_type);
  LOG(INFO) << "Invalidate old featured sticker sets";
  if (G()->use_sqlite_pmc()) {
    G()->td_db()->get_binlog_pmc()->erase("invalidate_old_featured_sticker_sets");
    G()->td_db()->get_sqlite_pmc()->erase_by_prefix("sssoldfeatured", Auto());
  }
  are_old_featured_sticker_sets_invalidated_[type] = false;
  old_featured_sticker_set_ids_[type].clear();

  old_featured_sticker_set_generation_[type]++;
  fail_promises(load_old_featured_sticker_sets_queries_, Status::Error(400, "Trending sticker sets were updated"));
}

void StickersManager::set_old_featured_sticker_set_count(StickerType sticker_type, int32 count) {
  auto type = static_cast<int32>(sticker_type);
  if (old_featured_sticker_set_count_[type] == count) {
    return;
  }
  if (sticker_type != StickerType::Regular) {
    return;
  }

  on_old_featured_sticker_sets_invalidated(sticker_type);

  old_featured_sticker_set_count_[type] = count;
  need_update_featured_sticker_sets_[type] = true;

  if (!G()->use_sqlite_pmc()) {
    return;
  }

  LOG(INFO) << "Save old trending sticker set count " << count << " to binlog";
  G()->td_db()->get_binlog_pmc()->set("old_featured_sticker_set_count", to_string(count));
}

void StickersManager::fix_old_featured_sticker_set_count(StickerType sticker_type) {
  auto type = static_cast<int32>(sticker_type);
  auto known_count = static_cast<int32>(old_featured_sticker_set_ids_[type].size());
  if (old_featured_sticker_set_count_[type] < known_count) {
    if (old_featured_sticker_set_count_[type] >= 0) {
      LOG(ERROR) << "Have old trending sticker set count " << old_featured_sticker_set_count_[type] << ", but have "
                 << known_count << " old trending sticker sets";
    }
    set_old_featured_sticker_set_count(sticker_type, known_count);
  }
  if (old_featured_sticker_set_count_[type] > known_count && known_count % OLD_FEATURED_STICKER_SET_SLICE_SIZE != 0) {
    LOG(ERROR) << "Have " << known_count << " old sticker sets out of " << old_featured_sticker_set_count_[type];
    set_old_featured_sticker_set_count(sticker_type, known_count);
  }
}

void StickersManager::on_get_featured_sticker_sets(
    StickerType sticker_type, int32 offset, int32 limit, uint32 generation,
    tl_object_ptr<telegram_api::messages_FeaturedStickers> &&sticker_sets_ptr) {
  auto type = static_cast<int32>(sticker_type);
  if (offset < 0) {
    next_featured_sticker_sets_load_time_[type] = Time::now_cached() + Random::fast(30 * 60, 50 * 60);
  }

  int32 constructor_id = sticker_sets_ptr->get_id();
  if (constructor_id == telegram_api::messages_featuredStickersNotModified::ID) {
    LOG(INFO) << "Trending sticker sets are not modified";
    auto *stickers = static_cast<const telegram_api::messages_featuredStickersNotModified *>(sticker_sets_ptr.get());
    if (offset >= 0 && generation == old_featured_sticker_set_generation_[type]) {
      set_old_featured_sticker_set_count(sticker_type, stickers->count_);
      fix_old_featured_sticker_set_count(sticker_type);
    }
    send_update_featured_sticker_sets(sticker_type);
    return;
  }
  CHECK(constructor_id == telegram_api::messages_featuredStickers::ID);
  auto featured_stickers = move_tl_object_as<telegram_api::messages_featuredStickers>(sticker_sets_ptr);

  if (featured_stickers->premium_ != are_featured_sticker_sets_premium_[type]) {
    on_old_featured_sticker_sets_invalidated(sticker_type);
    if (offset >= 0) {
      featured_stickers->premium_ = are_featured_sticker_sets_premium_[type];
      reload_featured_sticker_sets(sticker_type, true);
    }
  }

  if (offset >= 0 && generation == old_featured_sticker_set_generation_[type]) {
    set_old_featured_sticker_set_count(sticker_type, featured_stickers->count_);
    // the count will be fixed in on_load_old_featured_sticker_sets_finished
  }

  FlatHashSet<StickerSetId, StickerSetIdHash> unread_sticker_set_ids;
  for (auto &unread_sticker_set_id : featured_stickers->unread_) {
    StickerSetId sticker_set_id(unread_sticker_set_id);
    if (sticker_set_id.is_valid()) {
      unread_sticker_set_ids.insert(sticker_set_id);
    }
  }

  vector<StickerSetId> featured_sticker_set_ids;
  for (auto &sticker_set : featured_stickers->sets_) {
    StickerSetId set_id = on_get_sticker_set_covered(std::move(sticker_set), true, "on_get_featured_sticker_sets");
    if (!set_id.is_valid()) {
      continue;
    }

    auto set = get_sticker_set(set_id);
    CHECK(set != nullptr);
    bool is_viewed = unread_sticker_set_ids.count(set_id) == 0;
    if (is_viewed != set->is_viewed_) {
      set->is_viewed_ = is_viewed;
      set->is_changed_ = true;
    }

    update_sticker_set(set, "on_get_featured_sticker_sets 2");

    featured_sticker_set_ids.push_back(set_id);
  }

  send_update_installed_sticker_sets();

  if (offset >= 0) {
    if (generation == old_featured_sticker_set_generation_[type] && sticker_type == StickerType::Regular) {
      if (G()->use_sqlite_pmc() && !G()->close_flag()) {
        LOG(INFO) << "Save old trending sticker sets to database with offset "
                  << old_featured_sticker_set_ids_[type].size();
        CHECK(old_featured_sticker_set_ids_[type].size() % OLD_FEATURED_STICKER_SET_SLICE_SIZE == 0);
        StickerSetListLogEvent log_event(featured_sticker_set_ids, false);
        G()->td_db()->get_sqlite_pmc()->set(PSTRING() << "sssoldfeatured" << old_featured_sticker_set_ids_[type].size(),
                                            log_event_store(log_event).as_slice().str(), Auto());
      }
      on_load_old_featured_sticker_sets_finished(sticker_type, generation, std::move(featured_sticker_set_ids));
    }

    send_update_featured_sticker_sets(sticker_type);  // because of changed count
    return;
  }

  on_load_featured_sticker_sets_finished(sticker_type, std::move(featured_sticker_set_ids),
                                         featured_stickers->premium_);

  LOG_IF(ERROR, featured_sticker_sets_hash_[type] != featured_stickers->hash_) << "Trending sticker sets hash mismatch";

  if (G()->use_sqlite_pmc() && !G()->close_flag()) {
    LOG(INFO) << "Save trending sticker sets to database";
    StickerSetListLogEvent log_event(featured_sticker_set_ids_[type], are_featured_sticker_sets_premium_[type]);
    G()->td_db()->get_sqlite_pmc()->set(PSTRING() << "sssfeatured" << get_featured_sticker_suffix(sticker_type),
                                        log_event_store(log_event).as_slice().str(), Auto());
  }
}

void StickersManager::on_get_featured_sticker_sets_failed(StickerType sticker_type, int32 offset, int32 limit,
                                                          uint32 generation, Status error) {
  auto type = static_cast<int32>(sticker_type);
  CHECK(error.is_error());
  if (offset >= 0) {
    if (generation != old_featured_sticker_set_generation_[type] || sticker_type != StickerType::Regular) {
      return;
    }
    fail_promises(load_old_featured_sticker_sets_queries_, std::move(error));
  } else {
    next_featured_sticker_sets_load_time_[type] = Time::now_cached() + Random::fast(5, 10);
    fail_promises(load_featured_sticker_sets_queries_[type], std::move(error));
  }
}

void StickersManager::load_featured_sticker_sets(StickerType sticker_type, Promise<Unit> &&promise) {
  CHECK(sticker_type != StickerType::Mask);
  auto type = static_cast<int32>(sticker_type);
  if (td_->auth_manager_->is_bot()) {
    are_featured_sticker_sets_loaded_[type] = true;
    old_featured_sticker_set_count_[type] = 0;
  }
  if (are_featured_sticker_sets_loaded_[type]) {
    promise.set_value(Unit());
    return;
  }
  load_featured_sticker_sets_queries_[type].push_back(std::move(promise));
  if (load_featured_sticker_sets_queries_[type].size() == 1u) {
    if (G()->use_sqlite_pmc()) {
      LOG(INFO) << "Trying to load trending sticker sets from database";
      G()->td_db()->get_sqlite_pmc()->get(PSTRING() << "sssfeatured" << get_featured_sticker_suffix(sticker_type),
                                          PromiseCreator::lambda([sticker_type](string value) {
                                            send_closure(G()->stickers_manager(),
                                                         &StickersManager::on_load_featured_sticker_sets_from_database,
                                                         sticker_type, std::move(value));
                                          }));
    } else {
      LOG(INFO) << "Trying to load trending sticker sets from server";
      reload_featured_sticker_sets(sticker_type, true);
    }
  }
}

void StickersManager::on_load_featured_sticker_sets_from_database(StickerType sticker_type, string value) {
  if (G()->close_flag()) {
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Trending " << sticker_type << " sticker sets aren't found in database";
    reload_featured_sticker_sets(sticker_type, true);
    return;
  }

  LOG(INFO) << "Successfully loaded trending " << sticker_type << " sticker set list of size " << value.size()
            << " from database";

  StickerSetListLogEvent log_event;
  auto status = log_event_parse(log_event, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Can't load trending sticker set list: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    return reload_featured_sticker_sets(sticker_type, true);
  }

  vector<StickerSetId> sets_to_load;
  for (auto sticker_set_id : log_event.sticker_set_ids_) {
    StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    if (!sticker_set->is_inited_) {
      sets_to_load.push_back(sticker_set_id);
    }
  }

  load_sticker_sets_without_stickers(
      std::move(sets_to_load),
      PromiseCreator::lambda([sticker_type, sticker_set_ids = std::move(log_event.sticker_set_ids_),
                              is_premium = log_event.is_premium_](Result<> result) mutable {
        if (result.is_ok()) {
          send_closure(G()->stickers_manager(), &StickersManager::on_load_featured_sticker_sets_finished, sticker_type,
                       std::move(sticker_set_ids), is_premium);
        } else {
          send_closure(G()->stickers_manager(), &StickersManager::reload_featured_sticker_sets, sticker_type, true);
        }
      }));
}

void StickersManager::on_load_featured_sticker_sets_finished(StickerType sticker_type,
                                                             vector<StickerSetId> &&featured_sticker_set_ids,
                                                             bool is_premium) {
  auto type = static_cast<int32>(sticker_type);
  if (!featured_sticker_set_ids_[type].empty() && featured_sticker_set_ids != featured_sticker_set_ids_[type]) {
    // always invalidate old featured sticker sets when current featured sticker sets change
    on_old_featured_sticker_sets_invalidated(sticker_type);
  }
  featured_sticker_set_ids_[type] = std::move(featured_sticker_set_ids);
  are_featured_sticker_sets_premium_[type] = is_premium;
  are_featured_sticker_sets_loaded_[type] = true;
  need_update_featured_sticker_sets_[type] = true;
  send_update_featured_sticker_sets(sticker_type);
  set_promises(load_featured_sticker_sets_queries_[type]);
}

void StickersManager::load_old_featured_sticker_sets(StickerType sticker_type, Promise<Unit> &&promise) {
  CHECK(sticker_type == StickerType::Regular);
  CHECK(!td_->auth_manager_->is_bot());
  auto type = static_cast<int32>(sticker_type);
  CHECK(old_featured_sticker_set_ids_[type].size() % OLD_FEATURED_STICKER_SET_SLICE_SIZE == 0);
  load_old_featured_sticker_sets_queries_.push_back(std::move(promise));
  if (load_old_featured_sticker_sets_queries_.size() == 1u) {
    if (G()->use_sqlite_pmc()) {
      LOG(INFO) << "Trying to load old trending sticker sets from database with offset "
                << old_featured_sticker_set_ids_[type].size();
      G()->td_db()->get_sqlite_pmc()->get(
          PSTRING() << "sssoldfeatured" << old_featured_sticker_set_ids_[type].size(),
          PromiseCreator::lambda([sticker_type, generation = old_featured_sticker_set_generation_[type]](string value) {
            send_closure(G()->stickers_manager(), &StickersManager::on_load_old_featured_sticker_sets_from_database,
                         sticker_type, generation, std::move(value));
          }));
    } else {
      LOG(INFO) << "Trying to load old trending sticker sets from server with offset "
                << old_featured_sticker_set_ids_[type].size();
      reload_old_featured_sticker_sets(sticker_type);
    }
  }
}

void StickersManager::on_load_old_featured_sticker_sets_from_database(StickerType sticker_type, uint32 generation,
                                                                      string value) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(sticker_type == StickerType::Regular);
  auto type = static_cast<int32>(sticker_type);
  if (generation != old_featured_sticker_set_generation_[type]) {
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Old trending sticker sets aren't found in database";
    return reload_old_featured_sticker_sets(sticker_type);
  }

  LOG(INFO) << "Successfully loaded old trending sticker set list of size " << value.size()
            << " from database with offset " << old_featured_sticker_set_ids_[type].size();

  StickerSetListLogEvent log_event;
  auto status = log_event_parse(log_event, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Can't load old trending sticker set list: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    return reload_old_featured_sticker_sets(sticker_type);
  }
  CHECK(!log_event.is_premium_);

  vector<StickerSetId> sets_to_load;
  for (auto sticker_set_id : log_event.sticker_set_ids_) {
    StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    if (!sticker_set->is_inited_) {
      sets_to_load.push_back(sticker_set_id);
    }
  }

  load_sticker_sets_without_stickers(
      std::move(sets_to_load),
      PromiseCreator::lambda(
          [sticker_type, generation, sticker_set_ids = std::move(log_event.sticker_set_ids_)](Result<> result) mutable {
            if (result.is_ok()) {
              send_closure(G()->stickers_manager(), &StickersManager::on_load_old_featured_sticker_sets_finished,
                           sticker_type, generation, std::move(sticker_set_ids));
            } else {
              send_closure(G()->stickers_manager(), &StickersManager::reload_old_featured_sticker_sets, sticker_type,
                           generation);
            }
          }));
}

void StickersManager::on_load_old_featured_sticker_sets_finished(StickerType sticker_type, uint32 generation,
                                                                 vector<StickerSetId> &&featured_sticker_set_ids) {
  auto type = static_cast<int32>(sticker_type);
  if (generation != old_featured_sticker_set_generation_[type]) {
    fix_old_featured_sticker_set_count(sticker_type);  // must never be needed
    return;
  }
  CHECK(sticker_type == StickerType::Regular);
  append(old_featured_sticker_set_ids_[type], std::move(featured_sticker_set_ids));
  fix_old_featured_sticker_set_count(sticker_type);
  set_promises(load_old_featured_sticker_sets_queries_);
}

vector<StickerSetId> StickersManager::get_attached_sticker_sets(FileId file_id, Promise<Unit> &&promise) {
  if (!file_id.is_valid()) {
    promise.set_error(Status::Error(400, "Wrong file_id specified"));
    return {};
  }

  auto it = attached_sticker_sets_.find(file_id);
  if (it != attached_sticker_sets_.end()) {
    promise.set_value(Unit());
    return it->second;
  }

  send_get_attached_stickers_query(file_id, std::move(promise));
  return {};
}

void StickersManager::send_get_attached_stickers_query(FileId file_id, Promise<Unit> &&promise) {
  auto file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.empty()) {
    return promise.set_error(Status::Error(400, "File not found"));
  }
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr || (!full_remote_location->is_document() && !full_remote_location->is_photo()) ||
      full_remote_location->is_web()) {
    return promise.set_value(Unit());
  }

  tl_object_ptr<telegram_api::InputStickeredMedia> input_stickered_media;
  string file_reference;
  if (full_remote_location->is_photo()) {
    auto input_photo = full_remote_location->as_input_photo();
    file_reference = input_photo->file_reference_.as_slice().str();
    input_stickered_media = make_tl_object<telegram_api::inputStickeredMediaPhoto>(std::move(input_photo));
  } else {
    auto input_document = full_remote_location->as_input_document();
    file_reference = input_document->file_reference_.as_slice().str();
    input_stickered_media = make_tl_object<telegram_api::inputStickeredMediaDocument>(std::move(input_document));
  }

  td_->create_handler<GetAttachedStickerSetsQuery>(std::move(promise))
      ->send(file_id, std::move(file_reference), std::move(input_stickered_media));
}

void StickersManager::on_get_attached_sticker_sets(
    FileId file_id, vector<tl_object_ptr<telegram_api::StickerSetCovered>> &&sticker_sets) {
  CHECK(file_id.is_valid());
  vector<StickerSetId> &sticker_set_ids = attached_sticker_sets_[file_id];
  sticker_set_ids.clear();
  for (auto &sticker_set_covered : sticker_sets) {
    auto sticker_set_id =
        on_get_sticker_set_covered(std::move(sticker_set_covered), true, "on_get_attached_sticker_sets");
    if (sticker_set_id.is_valid()) {
      auto sticker_set = get_sticker_set(sticker_set_id);
      CHECK(sticker_set != nullptr);
      update_sticker_set(sticker_set, "on_get_attached_sticker_sets");

      sticker_set_ids.push_back(sticker_set_id);
    }
  }
  send_update_installed_sticker_sets();
}

// -1 - order can't be applied, because some sticker sets aren't loaded or aren't installed,
// 0 - order wasn't changed, 1 - order was partly replaced by the new order, 2 - order was replaced by the new order
int StickersManager::apply_installed_sticker_sets_order(StickerType sticker_type,
                                                        const vector<StickerSetId> &sticker_set_ids) {
  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type]) {
    return -1;
  }

  vector<StickerSetId> &current_sticker_set_ids = installed_sticker_set_ids_[type];
  if (sticker_set_ids == current_sticker_set_ids) {
    return 0;
  }

  FlatHashSet<StickerSetId, StickerSetIdHash> valid_set_ids;
  for (auto sticker_set_id : current_sticker_set_ids) {
    valid_set_ids.insert(sticker_set_id);
  }

  vector<StickerSetId> new_sticker_set_ids;
  for (auto sticker_set_id : sticker_set_ids) {
    auto it = valid_set_ids.find(sticker_set_id);
    if (it != valid_set_ids.end()) {
      new_sticker_set_ids.push_back(sticker_set_id);
      valid_set_ids.erase(it);
    } else {
      return -1;
    }
  }
  if (new_sticker_set_ids.empty()) {
    return 0;
  }
  if (!valid_set_ids.empty()) {
    vector<StickerSetId> missed_sticker_set_ids;
    for (auto sticker_set_id : current_sticker_set_ids) {
      auto it = valid_set_ids.find(sticker_set_id);
      if (it != valid_set_ids.end()) {
        missed_sticker_set_ids.push_back(sticker_set_id);
        valid_set_ids.erase(it);
      }
    }
    append(missed_sticker_set_ids, new_sticker_set_ids);
    new_sticker_set_ids = std::move(missed_sticker_set_ids);
  }
  CHECK(valid_set_ids.empty());

  if (new_sticker_set_ids == current_sticker_set_ids) {
    return 0;
  }
  current_sticker_set_ids = std::move(new_sticker_set_ids);

  need_update_installed_sticker_sets_[type] = true;
  if (sticker_set_ids != current_sticker_set_ids) {
    return 1;
  }
  return 2;
}

void StickersManager::on_update_sticker_sets_order(StickerType sticker_type,
                                                   const vector<StickerSetId> &sticker_set_ids) {
  int result = apply_installed_sticker_sets_order(sticker_type, sticker_set_ids);
  if (result < 0) {
    return reload_installed_sticker_sets(sticker_type, true);
  }
  if (result > 0) {
    send_update_installed_sticker_sets();
  }
}

// -1 - sticker set can't be moved to top, 0 - order wasn't changed, 1 - sticker set was moved to top
int StickersManager::move_installed_sticker_set_to_top(StickerType sticker_type, StickerSetId sticker_set_id) {
  LOG(INFO) << "Move " << sticker_set_id << " to top of " << sticker_type;
  auto type = static_cast<int32>(sticker_type);
  if (!are_installed_sticker_sets_loaded_[type]) {
    return -1;
  }

  vector<StickerSetId> &current_sticker_set_ids = installed_sticker_set_ids_[type];
  if (!current_sticker_set_ids.empty() && sticker_set_id == current_sticker_set_ids[0]) {
    return 0;
  }
  if (!td::contains(current_sticker_set_ids, sticker_set_id)) {
    return -1;
  }
  add_to_top(current_sticker_set_ids, current_sticker_set_ids.size(), sticker_set_id);

  need_update_installed_sticker_sets_[type] = true;
  return 1;
}

void StickersManager::on_update_move_sticker_set_to_top(StickerType sticker_type, StickerSetId sticker_set_id) {
  int result = move_installed_sticker_set_to_top(sticker_type, sticker_set_id);
  if (result < 0) {
    return reload_installed_sticker_sets(sticker_type, true);
  }
  if (result > 0) {
    send_update_installed_sticker_sets();
  }
}

void StickersManager::reorder_installed_sticker_sets(StickerType sticker_type,
                                                     const vector<StickerSetId> &sticker_set_ids,
                                                     Promise<Unit> &&promise) {
  auto result = apply_installed_sticker_sets_order(sticker_type, sticker_set_ids);
  if (result < 0) {
    return promise.set_error(Status::Error(400, "Wrong sticker set list"));
  }
  if (result > 0) {
    auto type = static_cast<int32>(sticker_type);
    td_->create_handler<ReorderStickerSetsQuery>()->send(sticker_type, installed_sticker_set_ids_[type]);
    send_update_installed_sticker_sets();
  }
  promise.set_value(Unit());
}

void StickersManager::move_sticker_set_to_top_by_sticker_id(FileId sticker_id) {
  LOG(INFO) << "Move to top sticker set of " << sticker_id;
  const auto *s = get_sticker(sticker_id);
  if (s == nullptr || !s->set_id_.is_valid()) {
    return;
  }
  if (s->type_ == StickerType::CustomEmoji) {
    // just in case
    return;
  }
  if (move_installed_sticker_set_to_top(s->type_, s->set_id_) > 0) {
    send_update_installed_sticker_sets();
  }
}

void StickersManager::move_sticker_set_to_top_by_custom_emoji_ids(const vector<CustomEmojiId> &custom_emoji_ids) {
  LOG(INFO) << "Move to top sticker set of " << custom_emoji_ids;
  StickerSetId sticker_set_id;
  for (auto custom_emoji_id : custom_emoji_ids) {
    auto sticker_id = custom_emoji_to_sticker_id_.get(custom_emoji_id);
    if (!sticker_id.is_valid()) {
      return;
    }
    const auto *s = get_sticker(sticker_id);
    CHECK(s != nullptr);
    CHECK(s->type_ == StickerType::CustomEmoji);
    if (!s->set_id_.is_valid()) {
      return;
    }
    if (s->set_id_ != sticker_set_id) {
      if (sticker_set_id.is_valid()) {
        return;
      }
      sticker_set_id = s->set_id_;
    }
  }
  CHECK(sticker_set_id.is_valid());
  if (move_installed_sticker_set_to_top(StickerType::CustomEmoji, sticker_set_id) > 0) {
    send_update_installed_sticker_sets();
  }
}

Result<std::tuple<FileId, bool, bool>> StickersManager::prepare_input_sticker(td_api::inputSticker *sticker,
                                                                              StickerType sticker_type) {
  if (sticker == nullptr) {
    return Status::Error(400, "Input sticker must be non-empty");
  }

  if (!clean_input_string(sticker->emojis_)) {
    return Status::Error(400, "Emojis must be encoded in UTF-8");
  }

  for (auto &keyword : sticker->keywords_) {
    if (!clean_input_string(keyword)) {
      return Status::Error(400, "Keywords must be encoded in UTF-8");
    }
    for (auto &c : keyword) {
      if (c == ',' || c == '\n') {
        c = ' ';
      }
    }
  }

  return prepare_input_file(sticker->sticker_, ::td::get_sticker_format(sticker->format_), sticker_type, false);
}

Result<std::tuple<FileId, bool, bool>> StickersManager::prepare_input_file(
    const tl_object_ptr<td_api::InputFile> &input_file, StickerFormat sticker_format, StickerType sticker_type,
    bool for_thumbnail) {
  if (sticker_format == StickerFormat::Unknown) {
    return Status::Error(400, "Sticker format must be non-empty");
  }

  auto file_type = sticker_format == StickerFormat::Tgs ? FileType::Sticker : FileType::Document;
  TRY_RESULT(file_id, td_->file_manager_->get_input_file_id(file_type, input_file, DialogId(), for_thumbnail, false));
  if (file_id.empty()) {
    return std::make_tuple(FileId(), false, false);
  }

  if (sticker_format == StickerFormat::Tgs) {
    int32 width = for_thumbnail ? 100 : 512;
    create_sticker(file_id, FileId(), string(), PhotoSize(), get_dimensions(width, width, "prepare_input_file"),
                   nullptr, nullptr, sticker_format, nullptr);
  } else if (sticker_format == StickerFormat::Webm) {
    td_->documents_manager_->create_document(file_id, string(), PhotoSize(), "sticker.webm", "video/webm", false);
  } else {
    td_->documents_manager_->create_document(file_id, string(), PhotoSize(), "sticker.png", "image/png", false);
  }

  FileView file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return Status::Error(400, "Can't use encrypted file");
  }

  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && main_remote_location->is_web()) {
    return Status::Error(400, "Can't use web file to create a sticker");
  }
  bool is_url = false;
  bool is_local = false;
  if (main_remote_location != nullptr) {
    CHECK(main_remote_location->is_document());
  } else {
    if (file_view.has_url()) {
      is_url = true;
    } else {
      if (file_view.has_full_local_location() &&
          file_view.expected_size() > get_max_sticker_file_size(sticker_format, sticker_type, for_thumbnail)) {
        return Status::Error(400, "File is too big");
      }
      is_local = true;
    }
  }
  if (is_url) {
    if (sticker_format == StickerFormat::Tgs) {
      return Status::Error(400, "Animated stickers can't be uploaded by URL");
    }
    if (sticker_format == StickerFormat::Webm) {
      return Status::Error(400, "Video stickers can't be uploaded by URL");
    }
  }
  return std::make_tuple(file_id, is_url, is_local);
}

void StickersManager::upload_sticker_file(UserId user_id, StickerFormat sticker_format,
                                          const td_api::object_ptr<td_api::InputFile> &input_file,
                                          Promise<td_api::object_ptr<td_api::file>> &&promise) {
  bool is_bot = td_->auth_manager_->is_bot();
  if (!is_bot) {
    user_id = td_->user_manager_->get_my_id();
  }

  TRY_STATUS_PROMISE(promise, td_->user_manager_->get_input_user(user_id));

  // StickerType::Regular has less restrictions
  TRY_RESULT_PROMISE(promise, file_info, prepare_input_file(input_file, sticker_format, StickerType::Regular, false));
  auto file_id = std::get<0>(file_info);
  auto is_url = std::get<1>(file_info);
  auto is_local = std::get<2>(file_info);

  auto upload_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), file_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &StickersManager::finish_upload_sticker_file, file_id, std::move(promise));
      });

  if (is_url) {
    do_upload_sticker_file(user_id, {file_id, FileManager::get_internal_upload_id()}, nullptr,
                           std::move(upload_promise));
  } else if (is_local) {
    upload_sticker_file(user_id, file_id, std::move(upload_promise));
  } else {
    upload_promise.set_value(Unit());
  }
}

void StickersManager::finish_upload_sticker_file(FileId file_id, Promise<td_api::object_ptr<td_api::file>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  FileView file_view = td_->file_manager_->get_file_view(file_id);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location == nullptr) {
    return promise.set_error(Status::Error(500, "Failed to upload the file"));
  }

  promise.set_value(td_->file_manager_->get_file_object(file_id));
}

Result<telegram_api::object_ptr<telegram_api::inputStickerSetItem>> StickersManager::get_input_sticker(
    const td_api::inputSticker *sticker, FileId file_id) const {
  CHECK(sticker != nullptr);
  FileView file_view = td_->file_manager_->get_file_view(file_id);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location == nullptr) {
    // merge has failed
    return Status::Error(500, "Failed to upload the file");
  }
  auto input_document = main_remote_location->as_input_document();

  int32 flags = 0;

  auto mask_coords = StickerMaskPosition(sticker->mask_position_).get_input_mask_coords();
  if (mask_coords != nullptr) {
    flags |= telegram_api::inputStickerSetItem::MASK_COORDS_MASK;
  }

  string keywords = implode(sticker->keywords_, ',');
  if (!keywords.empty()) {
    flags |= telegram_api::inputStickerSetItem::KEYWORDS_MASK;
  }

  return make_tl_object<telegram_api::inputStickerSetItem>(flags, std::move(input_document), sticker->emojis_,
                                                           std::move(mask_coords), keywords);
}

void StickersManager::get_suggested_sticker_set_name(string title, Promise<string> &&promise) {
  title = strip_empty_characters(title, MAX_STICKER_SET_TITLE_LENGTH);
  if (title.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set title must be non-empty"));
  }

  td_->create_handler<SuggestStickerSetShortNameQuery>(std::move(promise))->send(title);
}

void StickersManager::check_sticker_set_name(const string &name, Promise<CheckStickerSetNameResult> &&promise) {
  if (name.empty()) {
    return promise.set_value(CheckStickerSetNameResult::Invalid);
  }

  auto request_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<bool> result) mutable {
    if (result.is_error()) {
      auto error = result.move_as_error();
      if (error.message() == "SHORT_NAME_INVALID") {
        return promise.set_value(CheckStickerSetNameResult::Invalid);
      }
      if (error.message() == "SHORT_NAME_OCCUPIED") {
        return promise.set_value(CheckStickerSetNameResult::Occupied);
      }
      return promise.set_error(std::move(error));
    }

    promise.set_value(CheckStickerSetNameResult::Ok);
  });

  return td_->create_handler<CheckStickerSetShortNameQuery>(std::move(request_promise))->send(name);
}

td_api::object_ptr<td_api::CheckStickerSetNameResult> StickersManager::get_check_sticker_set_name_result_object(
    CheckStickerSetNameResult result) {
  switch (result) {
    case CheckStickerSetNameResult::Ok:
      return td_api::make_object<td_api::checkStickerSetNameResultOk>();
    case CheckStickerSetNameResult::Invalid:
      return td_api::make_object<td_api::checkStickerSetNameResultNameInvalid>();
    case CheckStickerSetNameResult::Occupied:
      return td_api::make_object<td_api::checkStickerSetNameResultNameOccupied>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void StickersManager::create_new_sticker_set(UserId user_id, string title, string short_name, StickerType sticker_type,
                                             bool has_text_color,
                                             vector<td_api::object_ptr<td_api::inputSticker>> &&stickers,
                                             string software,
                                             Promise<td_api::object_ptr<td_api::stickerSet>> &&promise) {
  bool is_bot = td_->auth_manager_->is_bot();
  if (!is_bot) {
    user_id = td_->user_manager_->get_my_id();
  }

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  title = strip_empty_characters(title, MAX_STICKER_SET_TITLE_LENGTH);
  if (title.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set title must be non-empty"));
  }

  short_name = strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH);
  if (short_name.empty() && is_bot) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  if (stickers.empty()) {
    return promise.set_error(Status::Error(400, "At least 1 sticker must be specified"));
  }

  if (has_text_color && sticker_type != StickerType::CustomEmoji) {
    return promise.set_error(Status::Error(400, "Only custom emoji stickers support repainting"));
  }

  vector<FileId> file_ids;
  file_ids.reserve(stickers.size());
  vector<FileId> local_file_ids;
  vector<FileId> url_file_ids;
  for (auto &sticker : stickers) {
    TRY_RESULT_PROMISE(promise, file_info, prepare_input_sticker(sticker.get(), sticker_type));
    auto file_id = std::get<0>(file_info);
    auto is_url = std::get<1>(file_info);
    auto is_local = std::get<2>(file_info);

    file_ids.push_back(file_id);
    if (is_url) {
      url_file_ids.push_back(file_id);
    } else if (is_local) {
      local_file_ids.push_back(file_id);
    }
  }

  auto pending_new_sticker_set = make_unique<PendingNewStickerSet>();
  pending_new_sticker_set->user_id_ = user_id;
  pending_new_sticker_set->title_ = std::move(title);
  pending_new_sticker_set->short_name_ = short_name;
  pending_new_sticker_set->sticker_type_ = sticker_type;
  pending_new_sticker_set->has_text_color_ = has_text_color;
  pending_new_sticker_set->file_ids_ = std::move(file_ids);
  pending_new_sticker_set->stickers_ = std::move(stickers);
  pending_new_sticker_set->software_ = std::move(software);
  pending_new_sticker_set->promise_ = std::move(promise);

  auto &multipromise = pending_new_sticker_set->upload_files_multipromise_;

  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || pending_new_sticker_sets_.count(random_id) > 0);
  pending_new_sticker_sets_[random_id] = std::move(pending_new_sticker_set);

  multipromise.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), random_id](Result<Unit> result) {
    send_closure_later(actor_id, &StickersManager::on_new_stickers_uploaded, random_id, std::move(result));
  }));
  auto lock_promise = multipromise.get_promise();

  for (auto file_id : url_file_ids) {
    do_upload_sticker_file(user_id, {file_id, FileManager::get_internal_upload_id()}, nullptr,
                           multipromise.get_promise());
  }

  for (auto file_id : local_file_ids) {
    upload_sticker_file(user_id, file_id, multipromise.get_promise());
  }

  lock_promise.set_value(Unit());
}

void StickersManager::upload_sticker_file(UserId user_id, FileId file_id, Promise<Unit> &&promise) {
  if (td_->file_manager_->get_file_view(file_id).get_type() == FileType::Sticker) {
    CHECK(get_input_media(file_id, nullptr, nullptr, string()) == nullptr);
  } else {
    CHECK(td_->documents_manager_->get_input_media(file_id, nullptr, nullptr) == nullptr);
  }

  FileUploadId file_upload_id{file_id, FileManager::get_internal_upload_id()};
  CHECK(file_upload_id.is_valid());
  being_uploaded_files_[file_upload_id] = {user_id, std::move(promise)};
  LOG(INFO) << "Ask to upload sticker " << file_upload_id;
  td_->file_manager_->upload(file_upload_id, upload_sticker_file_callback_, 2, 0);
}

void StickersManager::on_upload_sticker_file(FileUploadId file_upload_id,
                                             telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Sticker " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto user_id = it->second.first;
  auto promise = std::move(it->second.second);
  being_uploaded_files_.erase(it);

  do_upload_sticker_file(user_id, file_upload_id, std::move(input_file), std::move(promise));
}

void StickersManager::on_upload_sticker_file_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(WARNING) << "Sticker " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto promise = std::move(it->second.second);
  being_uploaded_files_.erase(it);

  promise.set_error(Status::Error(status.code() > 0 ? status.code() : 500,
                                  status.message()));  // TODO CHECK that status has always a code
}

void StickersManager::do_upload_sticker_file(UserId user_id, FileUploadId file_upload_id,
                                             telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
                                             Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  DialogId dialog_id(user_id);
  auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
  if (input_peer == nullptr) {
    if (input_file != nullptr) {
      td_->file_manager_->cancel_upload(file_upload_id);
    }
    return promise.set_error(Status::Error(400, "Have no access to the user"));
  }

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  FileType file_type = file_view.get_type();

  bool had_input_file = input_file != nullptr;
  auto input_media =
      file_type == FileType::Sticker
          ? get_input_media(file_upload_id.get_file_id(), std::move(input_file), nullptr, string())
          : td_->documents_manager_->get_input_media(file_upload_id.get_file_id(), std::move(input_file), nullptr);
  CHECK(input_media != nullptr);
  if (had_input_file && !FileManager::extract_was_uploaded(input_media)) {
    // if we had InputFile, but has failed to use it for input_media, then we need to immediately cancel file upload
    // so the next upload with the same file can succeed
    td_->file_manager_->cancel_upload(file_upload_id);
  }

  td_->create_handler<UploadStickerFileQuery>(std::move(promise))
      ->send(std::move(input_peer), file_upload_id, !had_input_file, std::move(input_media));
}

void StickersManager::on_uploaded_sticker_file(FileUploadId file_upload_id, bool is_url,
                                               tl_object_ptr<telegram_api::MessageMedia> media,
                                               Promise<Unit> &&promise) {
  CHECK(media != nullptr);
  LOG(INFO) << "Receive uploaded sticker file " << to_string(media);
  if (media->get_id() != telegram_api::messageMediaDocument::ID) {
    td_->file_manager_->delete_partial_remote_location(file_upload_id);
    return promise.set_error(Status::Error(400, "Can't upload sticker file: wrong file type"));
  }

  auto message_document = move_tl_object_as<telegram_api::messageMediaDocument>(media);
  auto document_ptr = std::move(message_document->document_);
  int32 document_id = document_ptr->get_id();
  if (document_id == telegram_api::documentEmpty::ID) {
    td_->file_manager_->delete_partial_remote_location(file_upload_id);
    return promise.set_error(Status::Error(400, "Can't upload sticker file: empty file"));
  }
  CHECK(document_id == telegram_api::document::ID);

  auto file_id = file_upload_id.get_file_id();
  FileView file_view = td_->file_manager_->get_file_view(file_id);
  FileType file_type = file_view.get_type();
  auto expected_document_type = file_type == FileType::Sticker ? Document::Type::Sticker : Document::Type::General;

  auto parsed_document = td_->documents_manager_->on_get_document(
      move_tl_object_as<telegram_api::document>(document_ptr), DialogId(), false);
  if (parsed_document.type != expected_document_type) {
    if (is_url && expected_document_type == Document::Type::General &&
        parsed_document.type == Document::Type::Sticker) {
      // uploaded by a URL WEBP sticker
      // re-register as document
      FileView sticker_file_view = td_->file_manager_->get_file_view(parsed_document.file_id);
      const auto *full_remote_location = sticker_file_view.get_full_remote_location();
      CHECK(full_remote_location != nullptr);
      auto remote_location = *full_remote_location;
      CHECK(remote_location.is_common());
      remote_location.file_type_ = FileType::Document;
      auto document_file_id =
          td_->file_manager_->register_remote(std::move(remote_location), FileLocationSource::FromServer, DialogId(),
                                              sticker_file_view.size(), 0, sticker_file_view.remote_name());
      CHECK(document_file_id.is_valid());
      td_->documents_manager_->create_document(document_file_id, string(), PhotoSize(), "sticker.webp", "image/webp",
                                               false);
      td_->documents_manager_->merge_documents(document_file_id, file_id);
      td_->file_manager_->cancel_upload(file_upload_id);
      return promise.set_value(Unit());
    }
    td_->file_manager_->delete_partial_remote_location(file_upload_id);
    return promise.set_error(Status::Error(400, "Wrong file type"));
  }

  if (parsed_document.file_id != file_id) {
    if (file_type == FileType::Sticker) {
      merge_stickers(parsed_document.file_id, file_id);
    } else {
      // must not delete the old document, because the file_id could be used for simultaneous URL uploads
      td_->documents_manager_->merge_documents(parsed_document.file_id, file_id);
    }
  }
  td_->file_manager_->cancel_upload(file_upload_id);
  promise.set_value(Unit());
}

void StickersManager::on_new_stickers_uploaded(int64 random_id, Result<Unit> result) {
  G()->ignore_result_if_closing(result);

  auto it = pending_new_sticker_sets_.find(random_id);
  CHECK(it != pending_new_sticker_sets_.end());

  auto pending_new_sticker_set = std::move(it->second);
  CHECK(pending_new_sticker_set != nullptr);

  pending_new_sticker_sets_.erase(it);

  if (result.is_error()) {
    pending_new_sticker_set->promise_.set_error(result.move_as_error());
    return;
  }

  CHECK(pending_new_sticker_set->upload_files_multipromise_.promise_count() == 0);

  auto &promise = pending_new_sticker_set->promise_;
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(pending_new_sticker_set->user_id_));

  StickerType sticker_type = pending_new_sticker_set->sticker_type_;

  auto sticker_count = pending_new_sticker_set->stickers_.size();
  vector<tl_object_ptr<telegram_api::inputStickerSetItem>> input_stickers;
  input_stickers.reserve(sticker_count);
  for (size_t i = 0; i < sticker_count; i++) {
    TRY_RESULT_PROMISE(
        promise, input_sticker,
        get_input_sticker(pending_new_sticker_set->stickers_[i].get(), pending_new_sticker_set->file_ids_[i]));
    input_stickers.push_back(std::move(input_sticker));
  }

  td_->create_handler<CreateNewStickerSetQuery>(std::move(promise))
      ->send(std::move(input_user), pending_new_sticker_set->title_, pending_new_sticker_set->short_name_, sticker_type,
             pending_new_sticker_set->has_text_color_, std::move(input_stickers), pending_new_sticker_set->software_);
}

StickerFormat StickersManager::guess_sticker_set_format(const StickerSet *sticker_set) const {
  auto format = StickerFormat::Unknown;
  for (auto sticker_id : sticker_set->sticker_ids_) {
    const auto *s = get_sticker(sticker_id);
    if (format == StickerFormat::Unknown) {
      format = s->format_;
    } else if (format != s->format_) {
      return StickerFormat::Unknown;
    }
  }
  return format;
}

void StickersManager::add_sticker_to_set(UserId user_id, string short_name,
                                         td_api::object_ptr<td_api::inputSticker> &&sticker,
                                         td_api::object_ptr<td_api::InputFile> &&old_sticker, Promise<Unit> &&promise) {
  bool is_bot = td_->auth_manager_->is_bot();
  if (!is_bot) {
    user_id = td_->user_manager_->get_my_id();
  }

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  short_name = clean_username(strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH));
  if (short_name.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set != nullptr && sticker_set->was_loaded_) {
    return do_add_sticker_to_set(user_id, short_name, std::move(sticker), std::move(old_sticker), std::move(promise));
  }

  do_reload_sticker_set(StickerSetId(), make_tl_object<telegram_api::inputStickerSetShortName>(short_name), 0,
                        PromiseCreator::lambda([actor_id = actor_id(this), user_id, short_name,
                                                sticker = std::move(sticker), old_sticker = std::move(old_sticker),
                                                promise = std::move(promise)](Result<Unit> result) mutable {
                          if (result.is_error()) {
                            promise.set_error(result.move_as_error());
                          } else {
                            send_closure(actor_id, &StickersManager::do_add_sticker_to_set, user_id,
                                         std::move(short_name), std::move(sticker), std::move(old_sticker),
                                         std::move(promise));
                          }
                        }),
                        "add_sticker_to_set");
}

void StickersManager::do_add_sticker_to_set(UserId user_id, string short_name,
                                            td_api::object_ptr<td_api::inputSticker> &&sticker,
                                            td_api::object_ptr<td_api::InputFile> &&old_sticker,
                                            Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    return promise.set_error(Status::Error(400, "Sticker set not found"));
  }
  telegram_api::object_ptr<telegram_api::inputDocument> input_document;
  if (old_sticker != nullptr) {
    TRY_RESULT_PROMISE(promise, sticker_input_document, get_sticker_input_document(old_sticker));
    input_document = std::move(sticker_input_document.input_document_);
  }

  if (sticker != nullptr && sticker->format_ == nullptr) {
    auto format = guess_sticker_set_format(sticker_set);
    if (format != StickerFormat::Unknown) {
      sticker->format_ = get_sticker_format_object(format);
    }
  }
  TRY_RESULT_PROMISE(promise, file_info, prepare_input_sticker(sticker.get(), sticker_set->sticker_type_));
  auto file_id = std::get<0>(file_info);
  auto is_url = std::get<1>(file_info);
  auto is_local = std::get<2>(file_info);

  auto pending_add_sticker_to_set = make_unique<PendingAddStickerToSet>();
  pending_add_sticker_to_set->short_name_ = short_name;
  pending_add_sticker_to_set->file_id_ = file_id;
  pending_add_sticker_to_set->sticker_ = std::move(sticker);
  pending_add_sticker_to_set->input_document_ = std::move(input_document);
  pending_add_sticker_to_set->promise_ = std::move(promise);

  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || pending_add_sticker_to_sets_.count(random_id) > 0);
  pending_add_sticker_to_sets_[random_id] = std::move(pending_add_sticker_to_set);

  auto on_upload_promise = PromiseCreator::lambda([random_id](Result<Unit> result) {
    send_closure(G()->stickers_manager(), &StickersManager::on_added_sticker_uploaded, random_id, std::move(result));
  });

  if (is_url) {
    do_upload_sticker_file(user_id, {file_id, FileManager::get_internal_upload_id()}, nullptr,
                           std::move(on_upload_promise));
  } else if (is_local) {
    upload_sticker_file(user_id, file_id, std::move(on_upload_promise));
  } else {
    on_upload_promise.set_value(Unit());
  }
}

void StickersManager::on_added_sticker_uploaded(int64 random_id, Result<Unit> result) {
  G()->ignore_result_if_closing(result);

  auto it = pending_add_sticker_to_sets_.find(random_id);
  CHECK(it != pending_add_sticker_to_sets_.end());

  auto pending_add_sticker_to_set = std::move(it->second);
  CHECK(pending_add_sticker_to_set != nullptr);

  pending_add_sticker_to_sets_.erase(it);

  if (result.is_error()) {
    pending_add_sticker_to_set->promise_.set_error(result.move_as_error());
    return;
  }
  TRY_RESULT_PROMISE(
      pending_add_sticker_to_set->promise_, input_sticker,
      get_input_sticker(pending_add_sticker_to_set->sticker_.get(), pending_add_sticker_to_set->file_id_));

  td_->create_handler<AddStickerToSetQuery>(std::move(pending_add_sticker_to_set->promise_))
      ->send(pending_add_sticker_to_set->short_name_, std::move(input_sticker),
             std::move(pending_add_sticker_to_set->input_document_));
}

void StickersManager::set_sticker_set_thumbnail(UserId user_id, string short_name,
                                                td_api::object_ptr<td_api::InputFile> &&thumbnail, StickerFormat format,
                                                Promise<Unit> &&promise) {
  bool is_bot = td_->auth_manager_->is_bot();
  if (!is_bot) {
    user_id = td_->user_manager_->get_my_id();
  }

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  short_name = clean_username(strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH));
  if (short_name.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set != nullptr && sticker_set->was_loaded_) {
    return do_set_sticker_set_thumbnail(user_id, short_name, std::move(thumbnail), format, std::move(promise));
  }

  do_reload_sticker_set(
      StickerSetId(), make_tl_object<telegram_api::inputStickerSetShortName>(short_name), 0,
      PromiseCreator::lambda([actor_id = actor_id(this), user_id, short_name, thumbnail = std::move(thumbnail), format,
                              promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &StickersManager::do_set_sticker_set_thumbnail, user_id, std::move(short_name),
                       std::move(thumbnail), format, std::move(promise));
        }
      }),
      "set_sticker_set_thumbnail");
}

void StickersManager::do_set_sticker_set_thumbnail(UserId user_id, string short_name,
                                                   td_api::object_ptr<td_api::InputFile> &&thumbnail,
                                                   StickerFormat format, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    return promise.set_error(Status::Error(400, "Sticker set not found"));
  }
  if (sticker_set->sticker_type_ == StickerType::CustomEmoji) {
    return promise.set_error(
        Status::Error(400, "The method can't be used to set thumbnail of custom emoji sticker sets"));
  }
  if (format == StickerFormat::Unknown) {
    format = guess_sticker_set_format(sticker_set);
  }

  TRY_RESULT_PROMISE(promise, file_info, prepare_input_file(thumbnail, format, sticker_set->sticker_type_, true));
  auto file_id = std::get<0>(file_info);
  auto is_url = std::get<1>(file_info);
  auto is_local = std::get<2>(file_info);

  if (!file_id.is_valid()) {
    td_->create_handler<SetStickerSetThumbnailQuery>(std::move(promise))
        ->send(short_name, telegram_api::make_object<telegram_api::inputDocumentEmpty>());
    return;
  }

  auto pending_set_sticker_set_thumbnail = make_unique<PendingSetStickerSetThumbnail>();
  pending_set_sticker_set_thumbnail->short_name_ = short_name;
  pending_set_sticker_set_thumbnail->file_id_ = file_id;
  pending_set_sticker_set_thumbnail->promise_ = std::move(promise);

  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || pending_set_sticker_set_thumbnails_.count(random_id) > 0);
  pending_set_sticker_set_thumbnails_[random_id] = std::move(pending_set_sticker_set_thumbnail);

  auto on_upload_promise = PromiseCreator::lambda([random_id](Result<Unit> result) {
    send_closure(G()->stickers_manager(), &StickersManager::on_sticker_set_thumbnail_uploaded, random_id,
                 std::move(result));
  });

  if (is_url) {
    do_upload_sticker_file(user_id, {file_id, FileManager::get_internal_upload_id()}, nullptr,
                           std::move(on_upload_promise));
  } else if (is_local) {
    upload_sticker_file(user_id, file_id, std::move(on_upload_promise));
  } else {
    on_upload_promise.set_value(Unit());
  }
}

void StickersManager::on_sticker_set_thumbnail_uploaded(int64 random_id, Result<Unit> result) {
  G()->ignore_result_if_closing(result);

  auto it = pending_set_sticker_set_thumbnails_.find(random_id);
  CHECK(it != pending_set_sticker_set_thumbnails_.end());

  auto pending_set_sticker_set_thumbnail = std::move(it->second);
  CHECK(pending_set_sticker_set_thumbnail != nullptr);

  pending_set_sticker_set_thumbnails_.erase(it);

  if (result.is_error()) {
    pending_set_sticker_set_thumbnail->promise_.set_error(result.move_as_error());
    return;
  }

  FileView file_view = td_->file_manager_->get_file_view(pending_set_sticker_set_thumbnail->file_id_);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location == nullptr) {
    return pending_set_sticker_set_thumbnail->promise_.set_error(Status::Error(500, "Failed to upload the file"));
  }

  td_->create_handler<SetStickerSetThumbnailQuery>(std::move(pending_set_sticker_set_thumbnail->promise_))
      ->send(pending_set_sticker_set_thumbnail->short_name_, main_remote_location->as_input_document());
}

void StickersManager::set_custom_emoji_sticker_set_thumbnail(string short_name, CustomEmojiId custom_emoji_id,
                                                             Promise<Unit> &&promise) {
  short_name = clean_username(strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH));
  if (short_name.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set != nullptr && sticker_set->was_loaded_) {
    return do_set_custom_emoji_sticker_set_thumbnail(short_name, custom_emoji_id, std::move(promise));
  }

  do_reload_sticker_set(StickerSetId(), make_tl_object<telegram_api::inputStickerSetShortName>(short_name), 0,
                        PromiseCreator::lambda([actor_id = actor_id(this), short_name, custom_emoji_id,
                                                promise = std::move(promise)](Result<Unit> result) mutable {
                          if (result.is_error()) {
                            promise.set_error(result.move_as_error());
                          } else {
                            send_closure(actor_id, &StickersManager::do_set_custom_emoji_sticker_set_thumbnail,
                                         std::move(short_name), custom_emoji_id, std::move(promise));
                          }
                        }),
                        "set_custom_emoji_sticker_set_thumbnail");
}

void StickersManager::do_set_custom_emoji_sticker_set_thumbnail(string short_name, CustomEmojiId custom_emoji_id,
                                                                Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const StickerSet *sticker_set = get_sticker_set(short_name_to_sticker_set_id_.get(short_name));
  if (sticker_set == nullptr || !sticker_set->was_loaded_) {
    return promise.set_error(Status::Error(400, "Sticker set not found"));
  }
  if (sticker_set->sticker_type_ != StickerType::CustomEmoji) {
    return promise.set_error(
        Status::Error(400, "The method can be used to set thumbnail only for custom emoji sticker sets"));
  }

  td_->create_handler<SetCustomEmojiStickerSetThumbnailQuery>(std::move(promise))->send(short_name, custom_emoji_id);
}

void StickersManager::set_sticker_set_title(string short_name, string title, Promise<Unit> &&promise) {
  short_name = clean_username(strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH));
  if (short_name.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  title = strip_empty_characters(title, MAX_STICKER_SET_TITLE_LENGTH);
  if (title.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set title must be non-empty"));
  }

  td_->create_handler<SetStickerSetTitleQuery>(std::move(promise))->send(short_name, title);
}

void StickersManager::delete_sticker_set(string short_name, Promise<Unit> &&promise) {
  short_name = clean_username(strip_empty_characters(short_name, MAX_STICKER_SET_SHORT_NAME_LENGTH));
  if (short_name.empty()) {
    return promise.set_error(Status::Error(400, "Sticker set name must be non-empty"));
  }

  td_->create_handler<DeleteStickerSetQuery>(std::move(promise))->send(short_name);
}

Result<StickersManager::StickerInputDocument> StickersManager::get_sticker_input_document(
    const tl_object_ptr<td_api::InputFile> &sticker) const {
  TRY_RESULT(file_id, td_->file_manager_->get_input_file_id(FileType::Sticker, sticker, DialogId(), false, false));

  auto file_view = td_->file_manager_->get_file_view(file_id);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location == nullptr || !main_remote_location->is_document() || main_remote_location->is_web()) {
    return Status::Error(400, "Wrong sticker file specified");
  }

  StickerInputDocument result;
  const Sticker *s = get_sticker(file_id);
  if (s != nullptr && s->set_id_.is_valid()) {
    const StickerSet *sticker_set = get_sticker_set(s->set_id_);
    if (sticker_set != nullptr) {
      result.sticker_set_unique_name_ = sticker_set->short_name_;
    } else {
      result.sticker_set_unique_name_ = to_string(s->set_id_.get());
    }
  }
  result.input_document_ = main_remote_location->as_input_document();
  return std::move(result);
}

void StickersManager::set_sticker_position_in_set(const td_api::object_ptr<td_api::InputFile> &sticker, int32 position,
                                                  Promise<Unit> &&promise) {
  if (position < 0) {
    return promise.set_error(Status::Error(400, "Wrong sticker position specified"));
  }

  TRY_RESULT_PROMISE(promise, input_document, get_sticker_input_document(sticker));

  td_->create_handler<SetStickerPositionQuery>(std::move(promise))
      ->send(input_document.sticker_set_unique_name_, std::move(input_document.input_document_), position);
}

void StickersManager::remove_sticker_from_set(const td_api::object_ptr<td_api::InputFile> &sticker,
                                              Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_document, get_sticker_input_document(sticker));

  td_->create_handler<DeleteStickerFromSetQuery>(std::move(promise))
      ->send(input_document.sticker_set_unique_name_, std::move(input_document.input_document_));
}

void StickersManager::set_sticker_emojis(const td_api::object_ptr<td_api::InputFile> &sticker, const string &emojis,
                                         Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_document, get_sticker_input_document(sticker));

  td_->create_handler<ChangeStickerQuery>(std::move(promise))
      ->send(input_document.sticker_set_unique_name_, std::move(input_document.input_document_), true, emojis,
             StickerMaskPosition(), false, string());
}

void StickersManager::set_sticker_keywords(const td_api::object_ptr<td_api::InputFile> &sticker,
                                           vector<string> &&keywords, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_document, get_sticker_input_document(sticker));

  for (auto &keyword : keywords) {
    for (auto &c : keyword) {
      if (c == ',' || c == '\n') {
        c = ' ';
      }
    }
  }
  td_->create_handler<ChangeStickerQuery>(std::move(promise))
      ->send(input_document.sticker_set_unique_name_, std::move(input_document.input_document_), false, string(),
             StickerMaskPosition(), true, implode(keywords, ','));
}

void StickersManager::set_sticker_mask_position(const td_api::object_ptr<td_api::InputFile> &sticker,
                                                td_api::object_ptr<td_api::maskPosition> &&mask_position,
                                                Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_document, get_sticker_input_document(sticker));
  td_->create_handler<ChangeStickerQuery>(std::move(promise))
      ->send(input_document.sticker_set_unique_name_, std::move(input_document.input_document_), false, string(),
             StickerMaskPosition(mask_position), false, string());
}

void StickersManager::get_created_sticker_sets(StickerSetId offset_sticker_set_id, int32 limit,
                                               Promise<td_api::object_ptr<td_api::stickerSets>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), promise = std::move(promise)](
          Result<telegram_api::object_ptr<telegram_api::messages_myStickers>> r_my_stickers) mutable {
        send_closure(actor_id, &StickersManager::on_get_created_sticker_sets, std::move(r_my_stickers),
                     std::move(promise));
      });
  td_->create_handler<GetMyStickersQuery>(std::move(query_promise))->send(offset_sticker_set_id, limit);
}

void StickersManager::on_get_created_sticker_sets(
    Result<telegram_api::object_ptr<telegram_api::messages_myStickers>> r_my_stickers,
    Promise<td_api::object_ptr<td_api::stickerSets>> &&promise) {
  G()->ignore_result_if_closing(r_my_stickers);
  if (r_my_stickers.is_error()) {
    return promise.set_error(r_my_stickers.move_as_error());
  }
  auto my_stickers = r_my_stickers.move_as_ok();
  auto total_count = my_stickers->count_;
  vector<StickerSetId> sticker_set_ids;
  for (auto &sticker_set_covered : my_stickers->sets_) {
    auto sticker_set_id =
        on_get_sticker_set_covered(std::move(sticker_set_covered), false, "on_get_created_sticker_sets");
    if (sticker_set_id.is_valid()) {
      auto sticker_set = get_sticker_set(sticker_set_id);
      CHECK(sticker_set != nullptr);
      update_sticker_set(sticker_set, "on_get_created_sticker_sets");

      if (!td::contains(sticker_set_ids, sticker_set_id) && sticker_set->is_created_) {
        sticker_set_ids.push_back(sticker_set_id);
      }
    }
  }
  if (static_cast<int32>(sticker_set_ids.size()) > total_count) {
    LOG(ERROR) << "Expected total of " << total_count << " owned sticker sets, but " << sticker_set_ids.size()
               << " received";
    total_count = static_cast<int32>(sticker_set_ids.size());
  }
  send_update_installed_sticker_sets();
  promise.set_value(get_sticker_sets_object(total_count, sticker_set_ids, 1));
}

vector<FileId> StickersManager::get_attached_sticker_file_ids(const vector<int32> &int_file_ids) {
  vector<FileId> result;

  result.reserve(int_file_ids.size());
  for (auto int_file_id : int_file_ids) {
    FileId file_id(int_file_id, 0);
    const Sticker *s = get_sticker(file_id);
    if (s == nullptr) {
      LOG(WARNING) << "Can't find sticker " << file_id;
      continue;
    }
    if (!s->set_id_.is_valid()) {
      // only stickers from sticker sets can be attached to files
      continue;
    }

    auto file_view = td_->file_manager_->get_file_view(file_id);
    CHECK(!file_view.empty());
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    if (full_remote_location->is_web()) {
      LOG(ERROR) << "Sticker " << file_id << " is web";
      continue;
    }
    if (!full_remote_location->is_document()) {
      LOG(ERROR) << "Sticker " << file_id << " is encrypted";
      continue;
    }
    result.push_back(file_id);

    if (!td_->auth_manager_->is_bot() && s->type_ != StickerType::CustomEmoji) {
      add_recent_sticker_by_id(true, file_id);
    }
  }

  return result;
}

int64 StickersManager::get_sticker_sets_hash(const vector<StickerSetId> &sticker_set_ids) const {
  vector<uint64> numbers;
  numbers.reserve(sticker_set_ids.size());
  for (auto sticker_set_id : sticker_set_ids) {
    const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_inited_);
    numbers.push_back(sticker_set->hash_);
  }
  return get_vector_hash(numbers);
}

int64 StickersManager::get_featured_sticker_sets_hash(StickerType sticker_type) const {
  auto type = static_cast<int32>(sticker_type);
  vector<uint64> numbers;
  numbers.reserve(featured_sticker_set_ids_[type].size() * 2);
  for (auto sticker_set_id : featured_sticker_set_ids_[type]) {
    const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
    CHECK(sticker_set != nullptr);
    CHECK(sticker_set->is_inited_);

    numbers.push_back(sticker_set_id.get());

    if (!sticker_set->is_viewed_) {
      numbers.push_back(1);
    }
  }
  return get_vector_hash(numbers);
}

vector<int64> StickersManager::convert_sticker_set_ids(const vector<StickerSetId> &sticker_set_ids) {
  return transform(sticker_set_ids, [](StickerSetId sticker_set_id) { return sticker_set_id.get(); });
}

vector<StickerSetId> StickersManager::convert_sticker_set_ids(const vector<int64> &sticker_set_ids) {
  return transform(sticker_set_ids, [](int64 sticker_set_id) { return StickerSetId(sticker_set_id); });
}

td_api::object_ptr<td_api::updateInstalledStickerSets> StickersManager::get_update_installed_sticker_sets_object(
    StickerType sticker_type) const {
  auto type = static_cast<int32>(sticker_type);
  return td_api::make_object<td_api::updateInstalledStickerSets>(
      get_sticker_type_object(sticker_type), convert_sticker_set_ids(installed_sticker_set_ids_[type]));
}

void StickersManager::send_update_installed_sticker_sets(bool from_database) {
  for (int32 type = 0; type < MAX_STICKER_TYPE; type++) {
    auto sticker_type = static_cast<StickerType>(type);
    if (need_update_installed_sticker_sets_[type]) {
      need_update_installed_sticker_sets_[type] = false;
      if (are_installed_sticker_sets_loaded_[type]) {
        installed_sticker_sets_hash_[type] = get_sticker_sets_hash(installed_sticker_set_ids_[type]);
        send_closure(G()->td(), &Td::send_update, get_update_installed_sticker_sets_object(sticker_type));

        if (G()->use_sqlite_pmc() && !from_database && !G()->close_flag()) {
          LOG(INFO) << "Save installed " << sticker_type << " sticker sets to database";
          StickerSetListLogEvent log_event(installed_sticker_set_ids_[type], false);
          G()->td_db()->get_sqlite_pmc()->set(PSTRING() << "sss" << type, log_event_store(log_event).as_slice().str(),
                                              Auto());
        }
      }
    }
  }
}

size_t StickersManager::get_max_featured_sticker_count(StickerType sticker_type) {
  switch (sticker_type) {
    case StickerType::Regular:
      return 5;
    case StickerType::Mask:
      return 5;
    case StickerType::CustomEmoji:
      return 16;
    default:
      UNREACHABLE();
      return 0;
  }
}

Slice StickersManager::get_featured_sticker_suffix(StickerType sticker_type) {
  switch (sticker_type) {
    case StickerType::Regular:
      return Slice();
    case StickerType::Mask:
      return Slice("1");
    case StickerType::CustomEmoji:
      return Slice("2");
    default:
      UNREACHABLE();
      return Slice();
  }
}

td_api::object_ptr<td_api::trendingStickerSets> StickersManager::get_trending_sticker_sets_object(
    StickerType sticker_type, const vector<StickerSetId> &sticker_set_ids) const {
  auto type = static_cast<int32>(sticker_type);
  auto total_count = static_cast<int32>(featured_sticker_set_ids_[type].size()) +
                     (old_featured_sticker_set_count_[type] == -1 ? 1 : old_featured_sticker_set_count_[type]);

  vector<tl_object_ptr<td_api::stickerSetInfo>> result;
  result.reserve(sticker_set_ids.size());
  for (auto sticker_set_id : sticker_set_ids) {
    auto sticker_set_info = get_sticker_set_info_object(sticker_set_id, get_max_featured_sticker_count(sticker_type),
                                                        are_featured_sticker_sets_premium_[type]);
    if (sticker_set_info->size_ != 0) {
      result.push_back(std::move(sticker_set_info));
    }
  }

  auto result_size = narrow_cast<int32>(result.size());
  CHECK(total_count >= result_size);
  return td_api::make_object<td_api::trendingStickerSets>(total_count, std::move(result),
                                                          are_featured_sticker_sets_premium_[type]);
}

td_api::object_ptr<td_api::updateTrendingStickerSets> StickersManager::get_update_trending_sticker_sets_object(
    StickerType sticker_type) const {
  auto type = static_cast<int32>(sticker_type);
  return td_api::make_object<td_api::updateTrendingStickerSets>(
      get_sticker_type_object(sticker_type),
      get_trending_sticker_sets_object(sticker_type, featured_sticker_set_ids_[type]));
}

void StickersManager::send_update_featured_sticker_sets(StickerType sticker_type) {
  auto type = static_cast<int32>(sticker_type);
  if (need_update_featured_sticker_sets_[type]) {
    need_update_featured_sticker_sets_[type] = false;
    featured_sticker_sets_hash_[type] = get_featured_sticker_sets_hash(sticker_type);

    send_closure(G()->td(), &Td::send_update, get_update_trending_sticker_sets_object(sticker_type));
  }
}

void StickersManager::reload_recent_stickers(bool is_attached, bool force) {
  if (G()->close_flag()) {
    return;
  }

  auto &next_load_time = next_recent_stickers_load_time_[is_attached];
  if (!td_->auth_manager_->is_bot() && next_load_time >= 0 && (next_load_time < Time::now() || force)) {
    LOG_IF(INFO, force) << "Reload recent " << (is_attached ? "attached " : "") << "stickers";
    next_load_time = -1;
    td_->create_handler<GetRecentStickersQuery>()->send(false, is_attached, recent_stickers_hash_[is_attached]);
  }
}

void StickersManager::repair_recent_stickers(bool is_attached, Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Bots have no recent stickers"));
  }

  repair_recent_stickers_queries_[is_attached].push_back(std::move(promise));
  if (repair_recent_stickers_queries_[is_attached].size() == 1u) {
    td_->create_handler<GetRecentStickersQuery>()->send(true, is_attached, 0);
  }
}

vector<FileId> StickersManager::get_recent_stickers(bool is_attached, Promise<Unit> &&promise) {
  if (!are_recent_stickers_loaded_[is_attached]) {
    load_recent_stickers(is_attached, std::move(promise));
    return {};
  }
  reload_recent_stickers(is_attached, false);

  promise.set_value(Unit());
  return recent_sticker_ids_[is_attached];
}

void StickersManager::load_recent_stickers(bool is_attached, Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    are_recent_stickers_loaded_[is_attached] = true;
  }
  if (are_recent_stickers_loaded_[is_attached]) {
    promise.set_value(Unit());
    return;
  }
  load_recent_stickers_queries_[is_attached].push_back(std::move(promise));
  if (load_recent_stickers_queries_[is_attached].size() == 1u) {
    if (G()->use_sqlite_pmc()) {
      LOG(INFO) << "Trying to load recent " << (is_attached ? "attached " : "") << "stickers from database";
      G()->td_db()->get_sqlite_pmc()->get(
          is_attached ? "ssr1" : "ssr0", PromiseCreator::lambda([is_attached](string value) {
            send_closure(G()->stickers_manager(), &StickersManager::on_load_recent_stickers_from_database, is_attached,
                         std::move(value));
          }));
    } else {
      LOG(INFO) << "Trying to load recent " << (is_attached ? "attached " : "") << "stickers from server";
      reload_recent_stickers(is_attached, true);
    }
  }
}

void StickersManager::on_load_recent_stickers_from_database(bool is_attached, string value) {
  if (G()->close_flag()) {
    fail_promises(load_recent_stickers_queries_[is_attached], Global::request_aborted_error());
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Recent " << (is_attached ? "attached " : "") << "stickers aren't found in database";
    reload_recent_stickers(is_attached, true);
    return;
  }

  LOG(INFO) << "Successfully loaded recent " << (is_attached ? "attached " : "") << "stickers list of size "
            << value.size() << " from database";

  StickerListLogEvent log_event;
  auto status = log_event_parse(log_event, value);
  if (status.is_error()) {
    // can't happen unless database is broken, but has been seen in the wild
    LOG(ERROR) << "Can't load recent stickers: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    return reload_recent_stickers(is_attached, true);
  }

  on_load_recent_stickers_finished(is_attached, std::move(log_event.sticker_ids), true);
}

void StickersManager::on_load_recent_stickers_finished(bool is_attached, vector<FileId> &&recent_sticker_ids,
                                                       bool from_database) {
  if (static_cast<int32>(recent_sticker_ids.size()) > recent_stickers_limit_) {
    recent_sticker_ids.resize(recent_stickers_limit_);
  }
  recent_sticker_ids_[is_attached] = std::move(recent_sticker_ids);
  are_recent_stickers_loaded_[is_attached] = true;
  send_update_recent_stickers(is_attached, from_database);
  set_promises(load_recent_stickers_queries_[is_attached]);
}

void StickersManager::on_get_recent_stickers(bool is_repair, bool is_attached,
                                             tl_object_ptr<telegram_api::messages_RecentStickers> &&stickers_ptr) {
  CHECK(!td_->auth_manager_->is_bot());
  if (!is_repair) {
    next_recent_stickers_load_time_[is_attached] = Time::now_cached() + Random::fast(30 * 60, 50 * 60);
  }

  CHECK(stickers_ptr != nullptr);
  int32 constructor_id = stickers_ptr->get_id();
  if (constructor_id == telegram_api::messages_recentStickersNotModified::ID) {
    if (is_repair) {
      return on_get_recent_stickers_failed(true, is_attached, Status::Error(500, "Failed to reload recent stickers"));
    }
    LOG(INFO) << (is_attached ? "Attached r" : "R") << "ecent stickers are not modified";
    return;
  }
  CHECK(constructor_id == telegram_api::messages_recentStickers::ID);
  auto stickers = move_tl_object_as<telegram_api::messages_recentStickers>(stickers_ptr);

  vector<FileId> recent_sticker_ids;
  recent_sticker_ids.reserve(stickers->stickers_.size());
  for (auto &document_ptr : stickers->stickers_) {
    auto sticker_id =
        on_get_sticker_document(std::move(document_ptr), StickerFormat::Unknown, "on_get_recent_stickers").second;
    if (!sticker_id.is_valid()) {
      continue;
    }
    recent_sticker_ids.push_back(sticker_id);
  }

  if (is_repair) {
    set_promises(repair_recent_stickers_queries_[is_attached]);
  } else {
    on_load_recent_stickers_finished(is_attached, std::move(recent_sticker_ids));

    LOG_IF(ERROR, recent_stickers_hash_[is_attached] != stickers->hash_) << "Stickers hash mismatch";
  }
}

void StickersManager::on_get_recent_stickers_failed(bool is_repair, bool is_attached, Status error) {
  CHECK(error.is_error());
  if (!is_repair) {
    next_recent_stickers_load_time_[is_attached] = Time::now_cached() + Random::fast(5, 10);
  }
  fail_promises(is_repair ? repair_recent_stickers_queries_[is_attached] : load_recent_stickers_queries_[is_attached],
                std::move(error));
}

int64 StickersManager::get_recent_stickers_hash(const vector<FileId> &sticker_ids, const char *source) const {
  vector<uint64> numbers;
  numbers.reserve(sticker_ids.size());
  for (auto sticker_id : sticker_ids) {
    auto sticker = get_sticker(sticker_id);
    LOG_CHECK(sticker != nullptr) << sticker_id << ' ' << stickers_.calc_size() << ' ' << source;
    auto file_view = td_->file_manager_->get_file_view(sticker_id);
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    if (!full_remote_location->is_document()) {
      LOG(ERROR) << "Recent sticker remote location is not document: " << *full_remote_location << " from " << source;
      continue;
    }
    numbers.push_back(full_remote_location->get_id());
  }
  return get_vector_hash(numbers);
}

FileSourceId StickersManager::get_recent_stickers_file_source_id(int is_attached) {
  if (!recent_stickers_file_source_id_[is_attached].is_valid()) {
    recent_stickers_file_source_id_[is_attached] =
        td_->file_reference_manager_->create_recent_stickers_file_source(is_attached != 0);
  }
  return recent_stickers_file_source_id_[is_attached];
}

void StickersManager::add_recent_sticker(bool is_attached, const tl_object_ptr<td_api::InputFile> &input_file,
                                         Promise<Unit> &&promise) {
  if (!are_recent_stickers_loaded_[is_attached]) {
    load_recent_stickers(is_attached, std::move(promise));
    return;
  }

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Sticker, input_file, DialogId(), false, false));

  add_recent_sticker_impl(is_attached, file_id, true, std::move(promise));
}

void StickersManager::send_save_recent_sticker_query(bool is_attached, FileId sticker_id, bool unsave,
                                                     Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  // TODO invokeAfter and log event
  auto file_view = td_->file_manager_->get_file_view(sticker_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  CHECK(full_remote_location != nullptr);
  CHECK(full_remote_location->is_document());
  CHECK(!full_remote_location->is_web());
  td_->create_handler<SaveRecentStickerQuery>(std::move(promise))
      ->send(is_attached, sticker_id, full_remote_location->as_input_document(), unsave);
}

void StickersManager::add_recent_sticker_by_id(bool is_attached, FileId sticker_id) {
  // TODO log event
  add_recent_sticker_impl(is_attached, sticker_id, false, Auto());
}

void StickersManager::add_recent_sticker_impl(bool is_attached, FileId sticker_id, bool add_on_server,
                                              Promise<Unit> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());

  LOG(INFO) << "Add recent " << (is_attached ? "attached " : "") << "sticker " << sticker_id;
  if (!are_recent_stickers_loaded_[is_attached]) {
    load_recent_stickers(is_attached, PromiseCreator::lambda([is_attached, sticker_id, add_on_server,
                                                              promise = std::move(promise)](Result<> result) mutable {
                           if (result.is_ok()) {
                             send_closure(G()->stickers_manager(), &StickersManager::add_recent_sticker_impl,
                                          is_attached, sticker_id, add_on_server, std::move(promise));
                           } else {
                             promise.set_error(result.move_as_error());
                           }
                         }));
    return;
  }

  auto is_equal = [sticker_id](FileId file_id) {
    return file_id == sticker_id || (file_id.get_remote() == sticker_id.get_remote() && sticker_id.get_remote() != 0);
  };

  vector<FileId> &sticker_ids = recent_sticker_ids_[is_attached];
  if (!sticker_ids.empty() && is_equal(sticker_ids[0])) {
    if (sticker_ids[0].get_remote() == 0 && sticker_id.get_remote() != 0) {
      sticker_ids[0] = sticker_id;
      save_recent_stickers_to_database(is_attached);
    }

    return promise.set_value(Unit());
  }

  auto sticker = get_sticker(sticker_id);
  if (sticker == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker not found"));
  }
  if (!sticker->set_id_.is_valid() &&
      (!add_on_server || (sticker->format_ != StickerFormat::Webp && sticker->format_ != StickerFormat::Webm))) {
    return promise.set_error(Status::Error(400, "The sticker must be from a sticker set"));
  }
  if (sticker->type_ == StickerType::CustomEmoji) {
    return promise.set_error(Status::Error(400, "Custom emoji stickers can't be added to recent"));
  }

  auto file_view = td_->file_manager_->get_file_view(sticker_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr) {
    return promise.set_error(Status::Error(400, "Can save only sent stickers"));
  }
  if (full_remote_location->is_web()) {
    return promise.set_error(Status::Error(400, "Can't save web stickers"));
  }
  if (!full_remote_location->is_document()) {
    return promise.set_error(Status::Error(400, "Can't save encrypted stickers"));
  }

  add_to_top_if(sticker_ids, static_cast<size_t>(recent_stickers_limit_), sticker_id, is_equal);

  if (sticker_ids[0].get_remote() == 0 && sticker_id.get_remote() != 0) {
    sticker_ids[0] = sticker_id;
  }

  send_update_recent_stickers(is_attached);
  if (add_on_server) {
    send_save_recent_sticker_query(is_attached, sticker_id, false, std::move(promise));
  }
}

void StickersManager::remove_recent_sticker(bool is_attached, const tl_object_ptr<td_api::InputFile> &input_file,
                                            Promise<Unit> &&promise) {
  if (!are_recent_stickers_loaded_[is_attached]) {
    load_recent_stickers(is_attached, std::move(promise));
    return;
  }

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Sticker, input_file, DialogId(), false, false));

  vector<FileId> &sticker_ids = recent_sticker_ids_[is_attached];
  auto is_equal = [sticker_id = file_id](FileId file_id) {
    return file_id == sticker_id || (file_id.get_remote() == sticker_id.get_remote() && sticker_id.get_remote() != 0);
  };
  if (!td::remove_if(sticker_ids, is_equal)) {
    return promise.set_value(Unit());
  }

  auto sticker = get_sticker(file_id);
  if (sticker == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker not found"));
  }

  send_save_recent_sticker_query(is_attached, file_id, true, std::move(promise));

  send_update_recent_stickers(is_attached);
}

void StickersManager::clear_recent_stickers(bool is_attached, Promise<Unit> &&promise) {
  if (!are_recent_stickers_loaded_[is_attached]) {
    load_recent_stickers(is_attached, std::move(promise));
    return;
  }

  vector<FileId> &sticker_ids = recent_sticker_ids_[is_attached];
  if (sticker_ids.empty()) {
    return promise.set_value(Unit());
  }

  // TODO invokeAfter
  td_->create_handler<ClearRecentStickersQuery>(std::move(promise))->send(is_attached);

  sticker_ids.clear();

  send_update_recent_stickers(is_attached);
}

td_api::object_ptr<td_api::updateRecentStickers> StickersManager::get_update_recent_stickers_object(
    int is_attached) const {
  return td_api::make_object<td_api::updateRecentStickers>(
      is_attached != 0, td_->file_manager_->get_file_ids_object(recent_sticker_ids_[is_attached]));
}

void StickersManager::send_update_recent_stickers(bool is_attached, bool from_database) {
  if (!are_recent_stickers_loaded_[is_attached]) {
    return;
  }

  vector<FileId> new_recent_sticker_file_ids;
  for (auto &sticker_id : recent_sticker_ids_[is_attached]) {
    append(new_recent_sticker_file_ids, get_sticker_file_ids(sticker_id));
  }
  std::sort(new_recent_sticker_file_ids.begin(), new_recent_sticker_file_ids.end());
  if (new_recent_sticker_file_ids != recent_sticker_file_ids_[is_attached]) {
    td_->file_manager_->change_files_source(get_recent_stickers_file_source_id(is_attached),
                                            recent_sticker_file_ids_[is_attached], new_recent_sticker_file_ids,
                                            "send_update_recent_stickers");
    recent_sticker_file_ids_[is_attached] = std::move(new_recent_sticker_file_ids);
  }

  recent_stickers_hash_[is_attached] =
      get_recent_stickers_hash(recent_sticker_ids_[is_attached], "send_update_recent_stickers");
  send_closure(G()->td(), &Td::send_update, get_update_recent_stickers_object(is_attached));

  if (!from_database) {
    save_recent_stickers_to_database(is_attached != 0);
  }
}

void StickersManager::save_recent_stickers_to_database(bool is_attached) {
  if (G()->use_sqlite_pmc() && !G()->close_flag()) {
    LOG(INFO) << "Save recent " << (is_attached ? "attached " : "") << "stickers to database";
    StickerListLogEvent log_event(recent_sticker_ids_[is_attached]);
    G()->td_db()->get_sqlite_pmc()->set(is_attached ? "ssr1" : "ssr0", log_event_store(log_event).as_slice().str(),
                                        Auto());
  }
}

void StickersManager::on_update_animated_emoji_zoom() {
  animated_emoji_zoom_ =
      static_cast<double>(td_->option_manager_->get_option_integer("animated_emoji_zoom", 625000000)) * 1e-9;
}

void StickersManager::on_update_recent_stickers_limit() {
  auto recent_stickers_limit =
      narrow_cast<int32>(td_->option_manager_->get_option_integer("recent_stickers_limit", 200));
  if (recent_stickers_limit != recent_stickers_limit_) {
    if (recent_stickers_limit > 0) {
      LOG(INFO) << "Update recent stickers limit to " << recent_stickers_limit;
      recent_stickers_limit_ = recent_stickers_limit;
      for (int is_attached = 0; is_attached < 2; is_attached++) {
        if (static_cast<int32>(recent_sticker_ids_[is_attached].size()) > recent_stickers_limit) {
          recent_sticker_ids_[is_attached].resize(recent_stickers_limit);
          send_update_recent_stickers(is_attached != 0);
        }
      }
    } else {
      LOG(ERROR) << "Receive wrong recent stickers limit = " << recent_stickers_limit;
    }
  }
}

void StickersManager::on_update_favorite_stickers_limit() {
  auto favorite_stickers_limit =
      narrow_cast<int32>(td_->option_manager_->get_option_integer("favorite_stickers_limit", 5));
  if (favorite_stickers_limit != favorite_stickers_limit_) {
    if (favorite_stickers_limit > 0) {
      LOG(INFO) << "Update favorite stickers limit to " << favorite_stickers_limit;
      favorite_stickers_limit_ = favorite_stickers_limit;
      if (static_cast<int32>(favorite_sticker_ids_.size()) > favorite_stickers_limit) {
        favorite_sticker_ids_.resize(favorite_stickers_limit);
        send_update_favorite_stickers();
      }
    } else {
      LOG(ERROR) << "Receive wrong favorite stickers limit = " << favorite_stickers_limit;
    }
  }
}

void StickersManager::reload_favorite_stickers(bool force) {
  if (G()->close_flag()) {
    return;
  }

  auto &next_load_time = next_favorite_stickers_load_time_;
  if (!td_->auth_manager_->is_bot() && next_load_time >= 0 && (next_load_time < Time::now() || force)) {
    LOG_IF(INFO, force) << "Reload favorite stickers";
    next_load_time = -1;
    td_->create_handler<GetFavedStickersQuery>()->send(false, get_favorite_stickers_hash());
  }
}

void StickersManager::repair_favorite_stickers(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Bots have no favorite stickers"));
  }

  repair_favorite_stickers_queries_.push_back(std::move(promise));
  if (repair_favorite_stickers_queries_.size() == 1u) {
    td_->create_handler<GetFavedStickersQuery>()->send(true, 0);
  }
}

vector<FileId> StickersManager::get_favorite_stickers(Promise<Unit> &&promise) {
  if (!are_favorite_stickers_loaded_) {
    load_favorite_stickers(std::move(promise));
    return {};
  }
  reload_favorite_stickers(false);

  promise.set_value(Unit());
  return favorite_sticker_ids_;
}

void StickersManager::load_favorite_stickers(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    are_favorite_stickers_loaded_ = true;
  }
  if (are_favorite_stickers_loaded_) {
    promise.set_value(Unit());
    return;
  }
  load_favorite_stickers_queries_.push_back(std::move(promise));
  if (load_favorite_stickers_queries_.size() == 1u) {
    if (G()->use_sqlite_pmc()) {
      LOG(INFO) << "Trying to load favorite stickers from database";
      G()->td_db()->get_sqlite_pmc()->get("ssfav", PromiseCreator::lambda([](string value) {
                                            send_closure(G()->stickers_manager(),
                                                         &StickersManager::on_load_favorite_stickers_from_database,
                                                         std::move(value));
                                          }));
    } else {
      LOG(INFO) << "Trying to load favorite stickers from server";
      reload_favorite_stickers(true);
    }
  }
}

void StickersManager::on_load_favorite_stickers_from_database(const string &value) {
  if (G()->close_flag()) {
    fail_promises(load_favorite_stickers_queries_, Global::request_aborted_error());
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Favorite stickers aren't found in database";
    reload_favorite_stickers(true);
    return;
  }

  LOG(INFO) << "Successfully loaded favorite stickers list of size " << value.size() << " from database";

  StickerListLogEvent log_event;
  auto status = log_event_parse(log_event, value);
  if (status.is_error()) {
    // can't happen unless database is broken, but has been seen in the wild
    LOG(ERROR) << "Can't load favorite stickers: " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    return reload_favorite_stickers(true);
  }

  on_load_favorite_stickers_finished(std::move(log_event.sticker_ids), true);
}

void StickersManager::on_load_favorite_stickers_finished(vector<FileId> &&favorite_sticker_ids, bool from_database) {
  if (static_cast<int32>(favorite_sticker_ids.size()) > favorite_stickers_limit_) {
    favorite_sticker_ids.resize(favorite_stickers_limit_);
  }
  favorite_sticker_ids_ = std::move(favorite_sticker_ids);
  are_favorite_stickers_loaded_ = true;
  send_update_favorite_stickers(from_database);
  set_promises(load_favorite_stickers_queries_);
}

void StickersManager::on_get_favorite_stickers(
    bool is_repair, tl_object_ptr<telegram_api::messages_FavedStickers> &&favorite_stickers_ptr) {
  CHECK(!td_->auth_manager_->is_bot());
  if (!is_repair) {
    next_favorite_stickers_load_time_ = Time::now_cached() + Random::fast(30 * 60, 50 * 60);
  }

  CHECK(favorite_stickers_ptr != nullptr);
  int32 constructor_id = favorite_stickers_ptr->get_id();
  if (constructor_id == telegram_api::messages_favedStickersNotModified::ID) {
    if (is_repair) {
      return on_get_favorite_stickers_failed(true, Status::Error(500, "Failed to reload favorite stickers"));
    }
    LOG(INFO) << "Favorite stickers are not modified";
    return;
  }
  CHECK(constructor_id == telegram_api::messages_favedStickers::ID);
  auto favorite_stickers = move_tl_object_as<telegram_api::messages_favedStickers>(favorite_stickers_ptr);

  // TODO use favorite_stickers->packs_

  vector<FileId> favorite_sticker_ids;
  favorite_sticker_ids.reserve(favorite_stickers->stickers_.size());
  for (auto &document_ptr : favorite_stickers->stickers_) {
    auto sticker_id =
        on_get_sticker_document(std::move(document_ptr), StickerFormat::Unknown, "on_get_favorite_stickers").second;
    if (!sticker_id.is_valid()) {
      continue;
    }

    favorite_sticker_ids.push_back(sticker_id);
  }

  if (is_repair) {
    set_promises(repair_favorite_stickers_queries_);
  } else {
    on_load_favorite_stickers_finished(std::move(favorite_sticker_ids));

    LOG_IF(ERROR, get_favorite_stickers_hash() != favorite_stickers->hash_) << "Favorite stickers hash mismatch";
  }
}

void StickersManager::on_get_favorite_stickers_failed(bool is_repair, Status error) {
  CHECK(error.is_error());
  if (!is_repair) {
    next_favorite_stickers_load_time_ = Time::now_cached() + Random::fast(5, 10);
  }
  fail_promises(is_repair ? repair_favorite_stickers_queries_ : load_favorite_stickers_queries_, std::move(error));
}

int64 StickersManager::get_favorite_stickers_hash() const {
  return get_recent_stickers_hash(favorite_sticker_ids_, "get_favorite_stickers_hash");
}

FileSourceId StickersManager::get_app_config_file_source_id() {
  if (!app_config_file_source_id_.is_valid()) {
    app_config_file_source_id_ = td_->file_reference_manager_->create_app_config_file_source();
  }
  return app_config_file_source_id_;
}

FileSourceId StickersManager::get_favorite_stickers_file_source_id() {
  if (!favorite_stickers_file_source_id_.is_valid()) {
    favorite_stickers_file_source_id_ = td_->file_reference_manager_->create_favorite_stickers_file_source();
  }
  return favorite_stickers_file_source_id_;
}

void StickersManager::add_favorite_sticker(const tl_object_ptr<td_api::InputFile> &input_file,
                                           Promise<Unit> &&promise) {
  if (!are_favorite_stickers_loaded_) {
    load_favorite_stickers(std::move(promise));
    return;
  }

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Sticker, input_file, DialogId(), false, false));

  add_favorite_sticker_impl(file_id, true, std::move(promise));
}

void StickersManager::send_fave_sticker_query(FileId sticker_id, bool unsave, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  // TODO invokeAfter and log event
  auto file_view = td_->file_manager_->get_file_view(sticker_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  CHECK(full_remote_location != nullptr);
  CHECK(full_remote_location->is_document());
  CHECK(!full_remote_location->is_web());
  td_->create_handler<FaveStickerQuery>(std::move(promise))
      ->send(sticker_id, full_remote_location->as_input_document(), unsave);
}

void StickersManager::add_favorite_sticker_by_id(FileId sticker_id) {
  // TODO log event
  add_favorite_sticker_impl(sticker_id, false, Auto());
}

void StickersManager::add_favorite_sticker_impl(FileId sticker_id, bool add_on_server, Promise<Unit> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());

  if (!are_favorite_stickers_loaded_) {
    load_favorite_stickers(
        PromiseCreator::lambda([sticker_id, add_on_server, promise = std::move(promise)](Result<> result) mutable {
          if (result.is_ok()) {
            send_closure(G()->stickers_manager(), &StickersManager::add_favorite_sticker_impl, sticker_id,
                         add_on_server, std::move(promise));
          } else {
            promise.set_error(result.move_as_error());
          }
        }));
    return;
  }

  auto is_equal = [sticker_id](FileId file_id) {
    return file_id == sticker_id || (file_id.get_remote() == sticker_id.get_remote() && sticker_id.get_remote() != 0);
  };

  if (!favorite_sticker_ids_.empty() && is_equal(favorite_sticker_ids_[0])) {
    if (favorite_sticker_ids_[0].get_remote() == 0 && sticker_id.get_remote() != 0) {
      favorite_sticker_ids_[0] = sticker_id;
      save_favorite_stickers_to_database();
    }

    return promise.set_value(Unit());
  }

  auto sticker = get_sticker(sticker_id);
  if (sticker == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker not found"));
  }
  if (!sticker->set_id_.is_valid() &&
      (!add_on_server || (sticker->format_ != StickerFormat::Webp && sticker->format_ != StickerFormat::Webm))) {
    return promise.set_error(Status::Error(400, "The sticker must be from a sticker set"));
  }
  if (sticker->type_ == StickerType::CustomEmoji) {
    return promise.set_error(Status::Error(400, "Custom emoji stickers can't be added to favorite"));
  }

  auto file_view = td_->file_manager_->get_file_view(sticker_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr) {
    return promise.set_error(Status::Error(400, "Can add to favorites only sent stickers"));
  }
  if (full_remote_location->is_web()) {
    return promise.set_error(Status::Error(400, "Can't add to favorites web stickers"));
  }
  if (!full_remote_location->is_document()) {
    return promise.set_error(Status::Error(400, "Can't add to favorites encrypted stickers"));
  }

  add_to_top_if(favorite_sticker_ids_, static_cast<size_t>(favorite_stickers_limit_), sticker_id, is_equal);

  if (favorite_sticker_ids_[0].get_remote() == 0 && sticker_id.get_remote() != 0) {
    favorite_sticker_ids_[0] = sticker_id;
  }

  send_update_favorite_stickers();
  if (add_on_server) {
    send_fave_sticker_query(sticker_id, false, std::move(promise));
  }
}

void StickersManager::remove_favorite_sticker(const tl_object_ptr<td_api::InputFile> &input_file,
                                              Promise<Unit> &&promise) {
  if (!are_favorite_stickers_loaded_) {
    load_favorite_stickers(std::move(promise));
    return;
  }

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Sticker, input_file, DialogId(), false, false));

  auto is_equal = [sticker_id = file_id](FileId file_id) {
    return file_id == sticker_id || (file_id.get_remote() == sticker_id.get_remote() && sticker_id.get_remote() != 0);
  };
  if (!td::remove_if(favorite_sticker_ids_, is_equal)) {
    return promise.set_value(Unit());
  }

  auto sticker = get_sticker(file_id);
  if (sticker == nullptr) {
    return promise.set_error(Status::Error(400, "Sticker not found"));
  }

  send_fave_sticker_query(file_id, true, std::move(promise));

  send_update_favorite_stickers();
}

td_api::object_ptr<td_api::updateFavoriteStickers> StickersManager::get_update_favorite_stickers_object() const {
  return td_api::make_object<td_api::updateFavoriteStickers>(
      td_->file_manager_->get_file_ids_object(favorite_sticker_ids_));
}

void StickersManager::send_update_favorite_stickers(bool from_database) {
  if (are_favorite_stickers_loaded_) {
    vector<FileId> new_favorite_sticker_file_ids;
    for (auto &sticker_id : favorite_sticker_ids_) {
      append(new_favorite_sticker_file_ids, get_sticker_file_ids(sticker_id));
    }
    std::sort(new_favorite_sticker_file_ids.begin(), new_favorite_sticker_file_ids.end());
    if (new_favorite_sticker_file_ids != favorite_sticker_file_ids_) {
      td_->file_manager_->change_files_source(get_favorite_stickers_file_source_id(), favorite_sticker_file_ids_,
                                              new_favorite_sticker_file_ids, "send_update_favorite_stickers");
      favorite_sticker_file_ids_ = std::move(new_favorite_sticker_file_ids);
    }

    send_closure(G()->td(), &Td::send_update, get_update_favorite_stickers_object());

    if (!from_database) {
      save_favorite_stickers_to_database();
    }
  }
}

void StickersManager::save_favorite_stickers_to_database() {
  if (G()->use_sqlite_pmc() && !G()->close_flag()) {
    LOG(INFO) << "Save favorite stickers to database";
    StickerListLogEvent log_event(favorite_sticker_ids_);
    G()->td_db()->get_sqlite_pmc()->set("ssfav", log_event_store(log_event).as_slice().str(), Auto());
  }
}

vector<string> StickersManager::get_sticker_emojis(const tl_object_ptr<td_api::InputFile> &input_file,
                                                   Promise<Unit> &&promise) {
  auto r_file_id = td_->file_manager_->get_input_file_id(FileType::Sticker, input_file, DialogId(), false, false);
  if (r_file_id.is_error()) {
    promise.set_error(r_file_id.move_as_error());
    return {};
  }

  FileId file_id = r_file_id.ok();

  auto sticker = get_sticker(file_id);
  if (sticker == nullptr) {
    promise.set_value(Unit());
    return {};
  }
  if (!sticker->set_id_.is_valid()) {
    promise.set_value(Unit());
    return {};
  }

  auto file_view = td_->file_manager_->get_file_view(file_id);
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr) {
    promise.set_value(Unit());
    return {};
  }
  if (!full_remote_location->is_document()) {
    promise.set_value(Unit());
    return {};
  }
  if (full_remote_location->is_web()) {
    promise.set_value(Unit());
    return {};
  }

  const StickerSet *sticker_set = get_sticker_set(sticker->set_id_);
  if (update_sticker_set_cache(sticker_set, promise)) {
    return {};
  }

  promise.set_value(Unit());
  auto it = sticker_set->sticker_emojis_map_.find(file_id);
  if (it == sticker_set->sticker_emojis_map_.end()) {
    return {};
  }

  return it->second;
}

string StickersManager::get_emoji_language_code_version_database_key(const string &language_code) {
  return PSTRING() << "emojiv$" << language_code;
}

int32 StickersManager::get_emoji_language_code_version(const string &language_code) {
  auto it = emoji_language_code_versions_.find(language_code);
  if (it != emoji_language_code_versions_.end()) {
    return it->second;
  }
  if (language_code.empty()) {
    return 0;
  }
  auto &result = emoji_language_code_versions_[language_code];
  result = to_integer<int32>(
      G()->td_db()->get_sqlite_sync_pmc()->get(get_emoji_language_code_version_database_key(language_code)));
  return result;
}

string StickersManager::get_emoji_language_code_last_difference_time_database_key(const string &language_code) {
  return PSTRING() << "emojid$" << language_code;
}

double StickersManager::get_emoji_language_code_last_difference_time(const string &language_code) {
  auto it = emoji_language_code_last_difference_times_.find(language_code);
  if (it != emoji_language_code_last_difference_times_.end()) {
    return it->second;
  }
  if (language_code.empty()) {
    return Time::now_cached() - G()->unix_time();
  }
  auto &result = emoji_language_code_last_difference_times_[language_code];
  auto old_unix_time = to_integer<int32>(G()->td_db()->get_sqlite_sync_pmc()->get(
      get_emoji_language_code_last_difference_time_database_key(language_code)));
  int32 passed_time = max(static_cast<int32>(0), G()->unix_time() - old_unix_time);
  result = Time::now_cached() - passed_time;
  return result;
}

string StickersManager::get_language_emojis_database_key(const string &language_code, const string &text) {
  return PSTRING() << "emoji$" << language_code << '$' << text;
}

vector<std::pair<string, string>> StickersManager::search_language_emojis(const string &language_code,
                                                                          const string &text) {
  LOG(INFO) << "Search emoji for \"" << text << "\" in language " << language_code;
  auto key = get_language_emojis_database_key(language_code, text);
  vector<std::pair<string, string>> result;
  G()->td_db()->get_sqlite_sync_pmc()->get_by_prefix(key, [&text, &result](Slice key, Slice value) {
    for (const auto &emoji : full_split(value, '$')) {
      result.emplace_back(emoji.str(), PSTRING() << text << key);
    }
    return true;
  });
  return result;
}

vector<string> StickersManager::get_keyword_language_emojis(const string &language_code, const string &text) {
  LOG(INFO) << "Get emoji for \"" << text << "\" in language " << language_code;
  auto key = get_language_emojis_database_key(language_code, text);
  string emojis = G()->td_db()->get_sqlite_sync_pmc()->get(key);
  return full_split(emojis, '$');
}

string StickersManager::get_emoji_language_codes_database_key(const vector<string> &language_codes) {
  return PSTRING() << "emojilc$" << implode(language_codes, '$');
}

void StickersManager::load_language_codes(vector<string> language_codes, string key, Promise<Unit> &&promise) {
  auto &promises = load_language_codes_queries_[key];
  promises.push_back(std::move(promise));
  if (promises.size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), key = std::move(key)](Result<vector<string>> &&result) {
        send_closure(actor_id, &StickersManager::on_get_language_codes, key, std::move(result));
      });
  td_->create_handler<GetEmojiKeywordsLanguageQuery>(std::move(query_promise))->send(std::move(language_codes));
}

void StickersManager::on_get_language_codes(const string &key, Result<vector<string>> &&result) {
  auto queries_it = load_language_codes_queries_.find(key);
  CHECK(queries_it != load_language_codes_queries_.end());
  CHECK(!queries_it->second.empty());
  auto promises = std::move(queries_it->second);
  load_language_codes_queries_.erase(queries_it);

  if (result.is_error()) {
    if (!G()->is_expected_error(result.error())) {
      LOG(ERROR) << "Receive " << result.error() << " from GetEmojiKeywordsLanguageQuery";
    }
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto language_codes = result.move_as_ok();
  LOG(INFO) << "Receive language codes " << language_codes << " for emojis search with key " << key;
  td::remove_if(language_codes, [](const string &language_code) {
    if (language_code.empty() || language_code.find('$') != string::npos) {
      LOG(ERROR) << "Receive language_code \"" << language_code << '"';
      return true;
    }
    return false;
  });
  if (language_codes.empty()) {
    LOG(ERROR) << "Language codes list is empty";
    language_codes.emplace_back("en");
  }
  td::unique(language_codes);

  auto it = emoji_language_codes_.find(key);
  CHECK(it != emoji_language_codes_.end());
  if (it->second != language_codes) {
    LOG(INFO) << "Update emoji language codes for " << key << " to " << language_codes;
    if (!G()->close_flag()) {
      CHECK(G()->use_sqlite_pmc());
      G()->td_db()->get_sqlite_pmc()->set(key, implode(language_codes, '$'), Auto());
    }
    it->second = std::move(language_codes);
  }

  set_promises(promises);
}

vector<string> StickersManager::get_used_language_codes(const vector<string> &input_language_codes, Slice text) const {
  vector<string> language_codes = td_->language_pack_manager_.get_actor_unsafe()->get_used_language_codes();
  auto system_language_code = G()->mtproto_header().get_system_language_code();
  if (system_language_code.size() >= 2 && system_language_code.find('$') == string::npos &&
      (system_language_code.size() == 2 || system_language_code[2] == '-')) {
    language_codes.push_back(system_language_code.substr(0, 2));
  }
  for (auto &input_language_code : input_language_codes) {
    if (input_language_code.size() >= 2 && input_language_code.find('$') == string::npos &&
        (input_language_code.size() == 2 || input_language_code[2] == '-')) {
      language_codes.push_back(input_language_code.substr(0, 2));
    }
  }
  if (!text.empty()) {
    uint32 code = 0;
    next_utf8_unsafe(text.ubegin(), &code);
    if ((0x410 <= code && code <= 0x44F) || code == 0x401 || code == 0x451) {
      // the first letter is cyrillic
      if (!td::contains(language_codes, "ru") && !td::contains(language_codes, "uk") &&
          !td::contains(language_codes, "bg") && !td::contains(language_codes, "be") &&
          !td::contains(language_codes, "mk") && !td::contains(language_codes, "sr") &&
          !td::contains(language_codes, "mn") && !td::contains(language_codes, "ky") &&
          !td::contains(language_codes, "kk") && !td::contains(language_codes, "uz") &&
          !td::contains(language_codes, "tk")) {
        language_codes.push_back("ru");
      }
    }
  }
  td::unique(language_codes);

  if (language_codes.empty()) {
    LOG(INFO) << "List of language codes is empty";
    language_codes.push_back("en");
  }
  return language_codes;
}

string StickersManager::get_used_language_codes_string() const {
  return implode(get_used_language_codes({}, Slice()), '$');
}

vector<string> StickersManager::get_emoji_language_codes(const vector<string> &input_language_codes, Slice text,
                                                         Promise<Unit> &promise) {
  auto language_codes = get_used_language_codes(input_language_codes, text);

  LOG(DEBUG) << "Have language codes " << language_codes;
  auto key = get_emoji_language_codes_database_key(language_codes);
  auto it = emoji_language_codes_.find(key);
  if (it == emoji_language_codes_.end()) {
    it = emoji_language_codes_.emplace(key, full_split(G()->td_db()->get_sqlite_sync_pmc()->get(key), '$')).first;
    td::remove_if(it->second, [](const string &language_code) {
      if (language_code.empty() || language_code.find('$') != string::npos) {
        LOG(ERROR) << "Loaded language_code \"" << language_code << '"';
        return true;
      }
      return false;
    });
  }
  if (it->second.empty()) {
    load_language_codes(std::move(language_codes), std::move(key), std::move(promise));
  } else {
    LOG(DEBUG) << "Have emoji language codes " << it->second;
    double now = Time::now_cached();
    for (auto &language_code : it->second) {
      double last_difference_time = get_emoji_language_code_last_difference_time(language_code);
      if (last_difference_time < now - EMOJI_KEYWORDS_UPDATE_DELAY &&
          get_emoji_language_code_version(language_code) != 0) {
        load_emoji_keywords_difference(language_code);
      }
    }
    if (reloaded_emoji_keywords_.insert(key).second) {
      load_language_codes(std::move(language_codes), std::move(key), Auto());
    }
  }
  return it->second;
}

void StickersManager::load_emoji_keywords(const string &language_code, Promise<Unit> &&promise) {
  auto &promises = load_emoji_keywords_queries_[language_code];
  promises.push_back(std::move(promise));
  if (promises.size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this),
       language_code](Result<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&result) mutable {
        send_closure(actor_id, &StickersManager::on_get_emoji_keywords, language_code, std::move(result));
      });
  td_->create_handler<GetEmojiKeywordsQuery>(std::move(query_promise))->send(language_code);
}

void StickersManager::on_get_emoji_keywords(
    const string &language_code, Result<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&result) {
  auto it = load_emoji_keywords_queries_.find(language_code);
  CHECK(it != load_emoji_keywords_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  load_emoji_keywords_queries_.erase(it);

  if (result.is_error()) {
    if (!G()->is_expected_error(result.error())) {
      LOG(ERROR) << "Receive " << result.error() << " from GetEmojiKeywordsQuery";
    }
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto version = get_emoji_language_code_version(language_code);
  CHECK(version == 0);

  MultiPromiseActorSafe mpas{"SaveEmojiKeywordsMultiPromiseActor"};
  for (auto &promise : promises) {
    mpas.add_promise(std::move(promise));
  }

  auto lock = mpas.get_promise();

  auto keywords = result.move_as_ok();
  LOG(INFO) << "Receive " << keywords->keywords_.size() << " emoji keywords for language " << language_code;
  LOG_IF(ERROR, language_code != keywords->lang_code_)
      << "Receive keywords for " << keywords->lang_code_ << " instead of " << language_code;
  LOG_IF(ERROR, keywords->from_version_ != 0) << "Receive keywords from version " << keywords->from_version_;
  version = keywords->version_;
  if (version <= 0) {
    LOG(ERROR) << "Receive keywords of version " << version;
    version = 1;
  }
  for (auto &keyword_ptr : keywords->keywords_) {
    switch (keyword_ptr->get_id()) {
      case telegram_api::emojiKeyword::ID: {
        auto keyword = telegram_api::move_object_as<telegram_api::emojiKeyword>(keyword_ptr);
        auto text = utf8_to_lower(keyword->keyword_);
        bool is_good = true;
        for (auto &emoji : keyword->emoticons_) {
          if (emoji.find('$') != string::npos) {
            LOG(ERROR) << "Receive emoji \"" << emoji << "\" from server for " << text;
            is_good = false;
          }
        }
        if (is_good && !G()->close_flag()) {
          CHECK(G()->use_sqlite_pmc());
          G()->td_db()->get_sqlite_pmc()->set(get_language_emojis_database_key(language_code, text),
                                              implode(keyword->emoticons_, '$'), mpas.get_promise());
        }
        break;
      }
      case telegram_api::emojiKeywordDeleted::ID:
        LOG(ERROR) << "Receive emojiKeywordDeleted in keywords for " << language_code;
        break;
      default:
        UNREACHABLE();
    }
  }
  if (!G()->close_flag()) {
    CHECK(G()->use_sqlite_pmc());
    G()->td_db()->get_sqlite_pmc()->set(get_emoji_language_code_version_database_key(language_code), to_string(version),
                                        mpas.get_promise());
    G()->td_db()->get_sqlite_pmc()->set(get_emoji_language_code_last_difference_time_database_key(language_code),
                                        to_string(G()->unix_time()), mpas.get_promise());
  }
  emoji_language_code_versions_[language_code] = version;
  emoji_language_code_last_difference_times_[language_code] = static_cast<int32>(Time::now_cached());

  lock.set_value(Unit());
}

void StickersManager::load_emoji_keywords_difference(const string &language_code) {
  LOG(INFO) << "Load emoji keywords difference for language " << language_code;
  CHECK(!language_code.empty());
  emoji_language_code_last_difference_times_[language_code] =
      Time::now_cached() + 1e9;  // prevent simultaneous requests
  int32 from_version = get_emoji_language_code_version(language_code);
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), language_code,
       from_version](Result<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&result) mutable {
        send_closure(actor_id, &StickersManager::on_get_emoji_keywords_difference, language_code, from_version,
                     std::move(result));
      });
  td_->create_handler<GetEmojiKeywordsDifferenceQuery>(std::move(query_promise))->send(language_code, from_version);
}

void StickersManager::on_get_emoji_keywords_difference(
    const string &language_code, int32 from_version,
    Result<telegram_api::object_ptr<telegram_api::emojiKeywordsDifference>> &&result) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    if (!G()->is_expected_error(result.error())) {
      LOG(ERROR) << "Receive " << result.error() << " from GetEmojiKeywordsDifferenceQuery";
    }
    emoji_language_code_last_difference_times_[language_code] = Time::now_cached() - EMOJI_KEYWORDS_UPDATE_DELAY - 2;
    return;
  }

  auto version = get_emoji_language_code_version(language_code);
  CHECK(version == from_version);

  auto keywords = result.move_as_ok();
  LOG(INFO) << "Receive " << keywords->keywords_.size() << " emoji keywords difference for language " << language_code;
  LOG_IF(ERROR, language_code != keywords->lang_code_)
      << "Receive keywords for " << keywords->lang_code_ << " instead of " << language_code;
  LOG_IF(ERROR, keywords->from_version_ != from_version)
      << "Receive keywords from version " << keywords->from_version_ << " instead of " << from_version;
  if (keywords->version_ < version) {
    LOG(ERROR) << "Receive keywords of version " << keywords->version_ << ", but have of version " << version;
    keywords->version_ = version;
  }
  version = keywords->version_;
  FlatHashMap<string, string> key_values;
  key_values.emplace(get_emoji_language_code_version_database_key(language_code), to_string(version));
  key_values.emplace(get_emoji_language_code_last_difference_time_database_key(language_code),
                     to_string(G()->unix_time()));
  for (auto &keyword_ptr : keywords->keywords_) {
    switch (keyword_ptr->get_id()) {
      case telegram_api::emojiKeyword::ID: {
        auto keyword = telegram_api::move_object_as<telegram_api::emojiKeyword>(keyword_ptr);
        auto text = utf8_to_lower(keyword->keyword_);
        bool is_good = true;
        for (auto &emoji : keyword->emoticons_) {
          if (emoji.find('$') != string::npos) {
            LOG(ERROR) << "Receive emoji \"" << emoji << "\" from server for " << text;
            is_good = false;
          }
        }
        if (is_good) {
          vector<string> emojis = get_keyword_language_emojis(language_code, text);
          bool is_changed = false;
          for (auto &emoji : keyword->emoticons_) {
            if (!td::contains(emojis, emoji)) {
              emojis.push_back(emoji);
              is_changed = true;
            }
          }
          if (is_changed) {
            key_values.emplace(get_language_emojis_database_key(language_code, text), implode(emojis, '$'));
          } else {
            LOG(INFO) << "Emoji keywords not changed for \"" << text << "\" from version " << from_version
                      << " to version " << version;
          }
        }
        break;
      }
      case telegram_api::emojiKeywordDeleted::ID: {
        auto keyword = telegram_api::move_object_as<telegram_api::emojiKeywordDeleted>(keyword_ptr);
        auto text = utf8_to_lower(keyword->keyword_);
        vector<string> emojis = get_keyword_language_emojis(language_code, text);
        bool is_changed = false;
        for (auto &emoji : keyword->emoticons_) {
          if (td::remove(emojis, emoji)) {
            is_changed = true;
          }
        }
        if (is_changed) {
          key_values.emplace(get_language_emojis_database_key(language_code, text), implode(emojis, '$'));
        } else {
          LOG(INFO) << "Emoji keywords not changed for \"" << text << "\" from version " << from_version
                    << " to version " << version;
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }
  CHECK(G()->use_sqlite_pmc());
  G()->td_db()->get_sqlite_pmc()->set_all(
      std::move(key_values), PromiseCreator::lambda([actor_id = actor_id(this), language_code, version](Unit) mutable {
        send_closure(actor_id, &StickersManager::finish_get_emoji_keywords_difference, std::move(language_code),
                     version);
      }));
}

void StickersManager::finish_get_emoji_keywords_difference(string language_code, int32 version) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Finished to get emoji keywords difference for language " << language_code;
  emoji_language_code_versions_[language_code] = version;
  emoji_language_code_last_difference_times_[language_code] = static_cast<int32>(Time::now_cached());
}

bool StickersManager::prepare_search_emoji_query(const string &text, const vector<string> &input_language_codes,
                                                 bool force, Promise<Unit> &promise, SearchEmojiQuery &query) {
  if (text.empty() || !G()->use_sqlite_pmc()) {
    promise.set_value(Unit());
    return false;
  }

  auto language_codes = get_emoji_language_codes(input_language_codes, text, promise);
  if (language_codes.empty()) {
    // promise was consumed
    return false;
  }

  vector<string> languages_to_load;
  for (auto &language_code : language_codes) {
    CHECK(!language_code.empty());
    auto version = get_emoji_language_code_version(language_code);
    if (version == 0) {
      languages_to_load.push_back(language_code);
    } else {
      LOG(DEBUG) << "Found language " << language_code << " with version " << version;
    }
  }

  if (!languages_to_load.empty()) {
    if (!force) {
      MultiPromiseActorSafe mpas{"LoadEmojiLanguagesMultiPromiseActor"};
      mpas.add_promise(std::move(promise));

      auto lock = mpas.get_promise();
      for (auto &language_code : languages_to_load) {
        load_emoji_keywords(language_code, mpas.get_promise());
      }
      lock.set_value(Unit());
      return false;
    } else {
      LOG(ERROR) << "Have no " << languages_to_load << " emoji keywords";
    }
  }

  query.text_ = utf8_to_lower(text);
  query.language_codes_ = std::move(language_codes);
  return true;
}

vector<std::pair<string, string>> StickersManager::search_emojis(const string &text,
                                                                 const vector<string> &input_language_codes, bool force,
                                                                 Promise<Unit> &&promise) {
  SearchEmojiQuery query;
  if (!prepare_search_emoji_query(text, input_language_codes, force, promise, query)) {
    return {};
  }

  vector<std::pair<string, string>> result;
  for (auto &language_code : query.language_codes_) {
    combine(result, search_language_emojis(language_code, query.text_));
  }
  td::unique(result);

  promise.set_value(Unit());
  return result;
}

vector<string> StickersManager::get_keyword_emojis(const string &text, const vector<string> &input_language_codes,
                                                   bool force, Promise<Unit> &&promise) {
  SearchEmojiQuery query;
  if (!prepare_search_emoji_query(text, input_language_codes, force, promise, query)) {
    return {};
  }

  vector<string> result;
  for (auto &language_code : query.language_codes_) {
    combine(result, get_keyword_language_emojis(language_code, query.text_));
  }
  td::unique(result);

  promise.set_value(Unit());
  return result;
}

void StickersManager::get_emoji_suggestions_url(const string &language_code, Promise<string> &&promise) {
  td_->create_handler<GetEmojiUrlQuery>(std::move(promise))->send(language_code);
}

string StickersManager::get_emoji_groups_database_key(EmojiGroupType group_type) {
  return PSTRING() << "emojigroup" << static_cast<int32>(group_type);
}

void StickersManager::get_emoji_groups(EmojiGroupType group_type,
                                       Promise<td_api::object_ptr<td_api::emojiCategories>> &&promise) {
  auto type = static_cast<int32>(group_type);
  auto used_language_codes = get_used_language_codes_string();
  LOG(INFO) << "Have language codes " << used_language_codes;
  if (emoji_group_list_[type].get_used_language_codes() == used_language_codes) {
    promise.set_value(emoji_group_list_[type].get_emoji_categories_object(this));
    if (!emoji_group_list_[type].is_expired()) {
      return;
    }
    promise = Promise<td_api::object_ptr<td_api::emojiCategories>>();
  }

  emoji_group_load_queries_[type].push_back(std::move(promise));
  if (emoji_group_load_queries_[type].size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  if (G()->use_sqlite_pmc()) {
    G()->td_db()->get_sqlite_pmc()->get(
        get_emoji_groups_database_key(group_type),
        PromiseCreator::lambda(
            [group_type, used_language_codes = std::move(used_language_codes)](string value) mutable {
              send_closure(G()->stickers_manager(), &StickersManager::on_load_emoji_groups_from_database, group_type,
                           std::move(used_language_codes), std::move(value));
            }));
  } else {
    reload_emoji_groups(group_type, std::move(used_language_codes));
  }
}

void StickersManager::on_load_emoji_groups_from_database(EmojiGroupType group_type, string used_language_codes,
                                                         string value) {
  if (G()->close_flag()) {
    return on_get_emoji_groups(group_type, std::move(used_language_codes), Global::request_aborted_error());
  }
  if (value.empty()) {
    LOG(INFO) << "Emoji groups of type " << group_type << " aren't found in database";
    return reload_emoji_groups(group_type, std::move(used_language_codes));
  }

  LOG(INFO) << "Successfully loaded emoji groups of type " << group_type << " from database";

  EmojiGroupList group_list;
  auto status = log_event_parse(group_list, value);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load emoji groups: " << status;
    return reload_emoji_groups(group_type, std::move(used_language_codes));
  }

  if (group_list.get_used_language_codes() != used_language_codes) {
    return reload_emoji_groups(group_type, std::move(used_language_codes));
  }

  auto custom_emoji_ids = group_list.get_icon_custom_emoji_ids();
  get_custom_emoji_stickers_unlimited(
      std::move(custom_emoji_ids),
      PromiseCreator::lambda([actor_id = actor_id(this), group_type, group_list = std::move(group_list)](
                                 Result<td_api::object_ptr<td_api::stickers>> &&result) {
        send_closure(actor_id, &StickersManager::on_load_emoji_group_icons, group_type, std::move(group_list));
      }));
}

void StickersManager::on_load_emoji_group_icons(EmojiGroupType group_type, EmojiGroupList group_list) {
  if (G()->close_flag()) {
    return on_get_emoji_groups(group_type, group_list.get_used_language_codes(), Global::request_aborted_error());
  }

  auto type = static_cast<int32>(group_type);
  emoji_group_list_[type] = std::move(group_list);

  auto promises = std::move(emoji_group_load_queries_[type]);
  reset_to_empty(emoji_group_load_queries_[type]);
  for (auto &promise : promises) {
    promise.set_value(emoji_group_list_[type].get_emoji_categories_object(this));
  }
}

void StickersManager::reload_emoji_groups(EmojiGroupType group_type, string used_language_codes) {
  auto type = static_cast<int32>(group_type);
  if (used_language_codes.empty()) {
    used_language_codes = get_used_language_codes_string();
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), group_type, used_language_codes = std::move(used_language_codes)](
          Result<telegram_api::object_ptr<telegram_api::messages_EmojiGroups>> r_emoji_groups) {
        send_closure(actor_id, &StickersManager::on_get_emoji_groups, group_type, std::move(used_language_codes),
                     std::move(r_emoji_groups));
      });
  td_->create_handler<GetEmojiGroupsQuery>(std::move(query_promise))
      ->send(group_type, emoji_group_list_[type].get_hash());
}

void StickersManager::on_get_emoji_groups(
    EmojiGroupType group_type, string used_language_codes,
    Result<telegram_api::object_ptr<telegram_api::messages_EmojiGroups>> r_emoji_groups) {
  G()->ignore_result_if_closing(r_emoji_groups);

  auto type = static_cast<int32>(group_type);
  if (r_emoji_groups.is_error()) {
    if (!G()->is_expected_error(r_emoji_groups.error())) {
      LOG(ERROR) << "Receive " << r_emoji_groups.error() << " from GetEmojiGroupsQuery";
    }
    return fail_promises(emoji_group_load_queries_[type], r_emoji_groups.move_as_error());
  }

  auto new_used_language_codes = get_used_language_codes_string();
  if (new_used_language_codes != used_language_codes) {
    used_language_codes.clear();
  }

  auto emoji_groups = r_emoji_groups.move_as_ok();
  switch (emoji_groups->get_id()) {
    case telegram_api::messages_emojiGroupsNotModified::ID:
      if (!used_language_codes.empty()) {
        emoji_group_list_[type].update_next_reload_time();
      }
      break;
    case telegram_api::messages_emojiGroups::ID: {
      auto groups = telegram_api::move_object_as<telegram_api::messages_emojiGroups>(emoji_groups);
      EmojiGroupList group_list = EmojiGroupList(used_language_codes, groups->hash_, std::move(groups->groups_));

      if (!used_language_codes.empty() && G()->use_sqlite_pmc()) {
        G()->td_db()->get_sqlite_pmc()->set(get_emoji_groups_database_key(group_type),
                                            log_event_store(group_list).as_slice().str(), Auto());
      }

      auto custom_emoji_ids = group_list.get_icon_custom_emoji_ids();
      get_custom_emoji_stickers_unlimited(
          std::move(custom_emoji_ids),
          PromiseCreator::lambda([actor_id = actor_id(this), group_type, group_list = std::move(group_list)](
                                     Result<td_api::object_ptr<td_api::stickers>> &&result) {
            send_closure(actor_id, &StickersManager::on_load_emoji_group_icons, group_type, std::move(group_list));
          }));
      return;
    }
    default:
      UNREACHABLE();
  }

  auto promises = std::move(emoji_group_load_queries_[type]);
  reset_to_empty(emoji_group_load_queries_[type]);
  for (auto &promise : promises) {
    promise.set_value(emoji_group_list_[type].get_emoji_categories_object(this));
  }
}

void StickersManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  for (int32 type = 0; type < MAX_STICKER_TYPE; type++) {
    if (are_installed_sticker_sets_loaded_[type]) {
      updates.push_back(get_update_installed_sticker_sets_object(static_cast<StickerType>(type)));
    }
    if (are_featured_sticker_sets_loaded_[type]) {
      updates.push_back(get_update_trending_sticker_sets_object(static_cast<StickerType>(type)));
    }
  }

  for (int is_attached = 0; is_attached < 2; is_attached++) {
    if (are_recent_stickers_loaded_[is_attached]) {
      updates.push_back(get_update_recent_stickers_object(is_attached));
    }
  }
  if (are_favorite_stickers_loaded_) {
    updates.push_back(get_update_favorite_stickers_object());
  }
  if (!dice_emojis_.empty()) {
    updates.push_back(get_update_dice_emojis_object());
  }
}

}  // namespace td
