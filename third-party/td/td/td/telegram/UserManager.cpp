//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/UserManager.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/Birthdate.hpp"
#include "td/telegram/BlockListId.h"
#include "td/telegram/BotMenuButton.h"
#include "td/telegram/BotVerification.h"
#include "td/telegram/BotVerification.hpp"
#include "td/telegram/BotVerifierSettings.hpp"
#include "td/telegram/BusinessAwayMessage.h"
#include "td/telegram/BusinessGreetingMessage.h"
#include "td/telegram/BusinessInfo.h"
#include "td/telegram/BusinessInfo.hpp"
#include "td/telegram/BusinessIntro.h"
#include "td/telegram/BusinessWorkHours.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/CommonDialogManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/EmojiStatus.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/MessageTtl.h"
#include "td/telegram/misc.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Outline.h"
#include "td/telegram/PeerColor.h"
#include "td/telegram/Photo.h"
#include "td/telegram/Photo.hpp"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/PremiumGiftOption.h"
#include "td/telegram/PremiumGiftOption.hpp"
#include "td/telegram/ReactionListType.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/ReferralProgramInfo.hpp"
#include "td/telegram/SecretChatLayer.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickerPhotoSize.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/VerificationStatus.h"
#include "td/telegram/Version.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"
#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <limits>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>

namespace td {

class GetContactsQuery final : public Td::ResultHandler {
 public:
  void send(int64 hash) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_getContacts(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getContacts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetContactsQuery: " << to_string(ptr);
    td_->user_manager_->on_get_contacts(std::move(ptr));
  }

  void on_error(Status status) final {
    td_->user_manager_->on_get_contacts_failed(std::move(status));
  }
};

class GetContactsBirthdaysQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::contacts_getBirthdays()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getBirthdays>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetContactsBirthdaysQuery: " << to_string(ptr);
    td_->user_manager_->on_get_contact_birthdates(std::move(ptr));
  }

  void on_error(Status status) final {
    td_->user_manager_->on_get_contact_birthdates(nullptr);
  }
};

class DismissContactBirthdaysSuggestionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DismissContactBirthdaysSuggestionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_dismissSuggestion(
        telegram_api::make_object<telegram_api::inputPeerEmpty>(), "BIRTHDAY_CONTACTS_TODAY")));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_dismissSuggestion>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetContactsStatusesQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::contacts_getStatuses()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getStatuses>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_get_contacts_statuses(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for GetContactsStatusesQuery: " << status;
    }
  }
};

class AddContactQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;

 public:
  explicit AddContactQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user, const Contact &contact,
            bool share_phone_number) {
    user_id_ = user_id;
    int32 flags = 0;
    if (share_phone_number) {
      flags |= telegram_api::contacts_addContact::ADD_PHONE_PRIVACY_EXCEPTION_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::contacts_addContact(flags, false /*ignored*/, std::move(input_user), contact.get_first_name(),
                                          contact.get_last_name(), contact.get_phone_number()),
        {{DialogId(user_id)}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_addContact>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AddContactQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->user_manager_->reload_contacts(true);
    td_->messages_manager_->reget_dialog_action_bar(DialogId(user_id_), "AddContactQuery");
  }
};

class EditCloseFriendsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  vector<UserId> user_ids_;

 public:
  explicit EditCloseFriendsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<UserId> user_ids) {
    user_ids_ = std::move(user_ids);
    send_query(G()->net_query_creator().create(
        telegram_api::contacts_editCloseFriends(UserId::get_input_user_ids(user_ids_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_editCloseFriends>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_set_close_friends(user_ids_, std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResolvePhoneQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  string phone_number_;

 public:
  explicit ResolvePhoneQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &phone_number) {
    phone_number_ = phone_number;
    send_query(G()->net_query_creator().create(telegram_api::contacts_resolvePhone(phone_number)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_resolvePhone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ResolvePhoneQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "ResolvePhoneQuery");
    // on_get_chats(std::move(ptr->chats_), "ResolvePhoneQuery");

    DialogId dialog_id(ptr->peer_);
    if (dialog_id.get_type() != DialogType::User) {
      LOG(ERROR) << "Receive " << dialog_id << " by " << phone_number_;
      return on_error(Status::Error(500, "Receive invalid response"));
    }

    td_->user_manager_->on_resolved_phone_number(phone_number_, dialog_id.get_user_id());

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == Slice("PHONE_NOT_OCCUPIED")) {
      td_->user_manager_->on_resolved_phone_number(phone_number_, UserId());
      return promise_.set_value(Unit());
    }
    promise_.set_error(std::move(status));
  }
};

class AcceptContactQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;

 public:
  explicit AcceptContactQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    user_id_ = user_id;
    send_query(G()->net_query_creator().create(telegram_api::contacts_acceptContact(std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_acceptContact>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AcceptContactQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->user_manager_->reload_contacts(true);
    td_->messages_manager_->reget_dialog_action_bar(DialogId(user_id_), "AcceptContactQuery");
  }
};

class ImportContactsQuery final : public Td::ResultHandler {
  int64 random_id_ = 0;
  size_t sent_size_ = 0;

 public:
  void send(vector<telegram_api::object_ptr<telegram_api::inputPhoneContact>> &&input_phone_contacts, int64 random_id) {
    random_id_ = random_id;
    sent_size_ = input_phone_contacts.size();
    send_query(G()->net_query_creator().create(telegram_api::contacts_importContacts(std::move(input_phone_contacts))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_importContacts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ImportContactsQuery: " << to_string(ptr);
    if (sent_size_ == ptr->retry_contacts_.size()) {
      return on_error(Status::Error(429, "Too Many Requests: retry after 3600"));
    }
    td_->user_manager_->on_imported_contacts(random_id_, std::move(ptr));
  }

  void on_error(Status status) final {
    td_->user_manager_->on_imported_contacts(random_id_, std::move(status));
  }
};

class DeleteContactsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteContactsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<telegram_api::object_ptr<telegram_api::InputUser>> &&input_users) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_deleteContacts(std::move(input_users))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_deleteContacts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteContactsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->user_manager_->reload_contacts(true);
  }
};

class DeleteContactsByPhoneNumberQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  vector<UserId> user_ids_;

 public:
  explicit DeleteContactsByPhoneNumberQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<string> &&user_phone_numbers, vector<UserId> &&user_ids) {
    if (user_phone_numbers.empty()) {
      return promise_.set_value(Unit());
    }
    user_ids_ = std::move(user_ids);
    send_query(G()->net_query_creator().create(telegram_api::contacts_deleteByPhones(std::move(user_phone_numbers))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_deleteByPhones>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(500, "Some contacts can't be deleted"));
    }

    td_->user_manager_->on_deleted_contacts(user_ids_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->user_manager_->reload_contacts(true);
  }
};

class ResetContactsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetContactsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::contacts_resetSaved()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_resetSaved>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      LOG(ERROR) << "Failed to delete imported contacts";
      td_->user_manager_->reload_contacts(true);
    } else {
      td_->user_manager_->on_update_contacts_reset();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->user_manager_->reload_contacts(true);
  }
};

class UploadProfilePhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;
  FileUploadId file_upload_id_;
  bool is_fallback_;
  bool only_suggest_;

 public:
  explicit UploadProfilePhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
            bool is_fallback, bool only_suggest, bool is_animation, double main_frame_timestamp) {
    CHECK(input_file != nullptr);
    CHECK(file_upload_id.is_valid());

    user_id_ = user_id;
    file_upload_id_ = file_upload_id;
    is_fallback_ = is_fallback;
    only_suggest_ = only_suggest;

    static_assert(static_cast<int32>(telegram_api::photos_uploadProfilePhoto::VIDEO_MASK) ==
                      static_cast<int32>(telegram_api::photos_uploadContactProfilePhoto::VIDEO_MASK),
                  "");
    static_assert(static_cast<int32>(telegram_api::photos_uploadProfilePhoto::VIDEO_START_TS_MASK) ==
                      static_cast<int32>(telegram_api::photos_uploadContactProfilePhoto::VIDEO_START_TS_MASK),
                  "");
    static_assert(static_cast<int32>(telegram_api::photos_uploadProfilePhoto::FILE_MASK) ==
                      static_cast<int32>(telegram_api::photos_uploadContactProfilePhoto::FILE_MASK),
                  "");

    int32 flags = 0;
    telegram_api::object_ptr<telegram_api::InputFile> photo_input_file;
    telegram_api::object_ptr<telegram_api::InputFile> video_input_file;
    if (is_animation) {
      flags |= telegram_api::photos_uploadProfilePhoto::VIDEO_MASK;
      video_input_file = std::move(input_file);

      if (main_frame_timestamp != 0.0) {
        flags |= telegram_api::photos_uploadProfilePhoto::VIDEO_START_TS_MASK;
      }
    } else {
      flags |= telegram_api::photos_uploadProfilePhoto::FILE_MASK;
      photo_input_file = std::move(input_file);
    }
    if (td_->user_manager_->is_user_bot(user_id)) {
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      if (r_input_user.is_error()) {
        return on_error(r_input_user.move_as_error());
      }
      flags |= telegram_api::photos_uploadProfilePhoto::BOT_MASK;
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadProfilePhoto(flags, false /*ignored*/, r_input_user.move_as_ok(),
                                                  std::move(photo_input_file), std::move(video_input_file),
                                                  main_frame_timestamp, nullptr),
          {{user_id}}));
    } else if (user_id == td_->user_manager_->get_my_id()) {
      if (is_fallback) {
        flags |= telegram_api::photos_uploadProfilePhoto::FALLBACK_MASK;
      }
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadProfilePhoto(flags, false /*ignored*/, nullptr, std::move(photo_input_file),
                                                  std::move(video_input_file), main_frame_timestamp, nullptr),
          {{"me"}}));
    } else {
      if (only_suggest) {
        flags |= telegram_api::photos_uploadContactProfilePhoto::SUGGEST_MASK;
      } else {
        flags |= telegram_api::photos_uploadContactProfilePhoto::SAVE_MASK;
      }
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      if (r_input_user.is_error()) {
        return on_error(r_input_user.move_as_error());
      }
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadContactProfilePhoto(flags, false /*ignored*/, false /*ignored*/,
                                                         r_input_user.move_as_ok(), std::move(photo_input_file),
                                                         std::move(video_input_file), main_frame_timestamp, nullptr),
          {{user_id}}));
    }
  }

  void send(UserId user_id, unique_ptr<StickerPhotoSize> sticker_photo_size, bool is_fallback, bool only_suggest) {
    CHECK(sticker_photo_size != nullptr);
    user_id_ = user_id;
    file_upload_id_ = FileUploadId();
    is_fallback_ = is_fallback;
    only_suggest_ = only_suggest;

    if (td_->user_manager_->is_user_bot(user_id)) {
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      if (r_input_user.is_error()) {
        return on_error(r_input_user.move_as_error());
      }
      int32 flags = telegram_api::photos_uploadProfilePhoto::VIDEO_EMOJI_MARKUP_MASK;
      flags |= telegram_api::photos_uploadProfilePhoto::BOT_MASK;
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadProfilePhoto(flags, false /*ignored*/, r_input_user.move_as_ok(), nullptr, nullptr,
                                                  0.0, sticker_photo_size->get_input_video_size_object(td_)),
          {{user_id}}));
    } else if (user_id == td_->user_manager_->get_my_id()) {
      int32 flags = telegram_api::photos_uploadProfilePhoto::VIDEO_EMOJI_MARKUP_MASK;
      if (is_fallback) {
        flags |= telegram_api::photos_uploadProfilePhoto::FALLBACK_MASK;
      }
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadProfilePhoto(flags, false /*ignored*/, nullptr, nullptr, nullptr, 0.0,
                                                  sticker_photo_size->get_input_video_size_object(td_)),
          {{"me"}}));
    } else {
      int32 flags = telegram_api::photos_uploadContactProfilePhoto::VIDEO_EMOJI_MARKUP_MASK;
      if (only_suggest) {
        flags |= telegram_api::photos_uploadContactProfilePhoto::SUGGEST_MASK;
      } else {
        flags |= telegram_api::photos_uploadContactProfilePhoto::SAVE_MASK;
      }
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      if (r_input_user.is_error()) {
        return on_error(r_input_user.move_as_error());
      }
      send_query(G()->net_query_creator().create(
          telegram_api::photos_uploadContactProfilePhoto(flags, false /*ignored*/, false /*ignored*/,
                                                         r_input_user.move_as_ok(), nullptr, nullptr, 0.0,
                                                         sticker_photo_size->get_input_video_size_object(td_)),
          {{user_id}}));
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::photos_uploadProfilePhoto::ReturnType,
                               telegram_api::photos_uploadContactProfilePhoto::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::photos_uploadProfilePhoto>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!only_suggest_) {
      td_->user_manager_->on_set_profile_photo(user_id_, result_ptr.move_as_ok(), is_fallback_, 0, std::move(promise_));
    } else {
      promise_.set_value(Unit());
    }

    if (file_upload_id_.is_valid()) {
      td_->file_manager_->delete_partial_remote_location(file_upload_id_);
    }
  }

  void on_error(Status status) final {
    if (file_upload_id_.is_valid()) {
      td_->file_manager_->delete_partial_remote_location(file_upload_id_);
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateProfilePhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;
  FileId file_id_;
  int64 old_photo_id_;
  bool is_fallback_;
  string file_reference_;

 public:
  explicit UpdateProfilePhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, FileId file_id, int64 old_photo_id, bool is_fallback,
            telegram_api::object_ptr<telegram_api::InputPhoto> &&input_photo) {
    CHECK(input_photo != nullptr);
    user_id_ = user_id;
    file_id_ = file_id;
    old_photo_id_ = old_photo_id;
    is_fallback_ = is_fallback;
    file_reference_ = FileManager::extract_file_reference(input_photo);
    int32 flags = 0;
    if (is_fallback) {
      flags |= telegram_api::photos_updateProfilePhoto::FALLBACK_MASK;
    }
    if (td_->user_manager_->is_user_bot(user_id)) {
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      if (r_input_user.is_error()) {
        return on_error(r_input_user.move_as_error());
      }
      flags |= telegram_api::photos_updateProfilePhoto::BOT_MASK;
      send_query(G()->net_query_creator().create(
          telegram_api::photos_updateProfilePhoto(flags, false /*ignored*/, r_input_user.move_as_ok(),
                                                  std::move(input_photo)),
          {{user_id}}));
    } else {
      send_query(G()->net_query_creator().create(
          telegram_api::photos_updateProfilePhoto(flags, false /*ignored*/, nullptr, std::move(input_photo)),
          {{"me"}}));
    }
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::photos_updateProfilePhoto>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_set_profile_photo(user_id_, result_ptr.move_as_ok(), is_fallback_, old_photo_id_,
                                             std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      if (file_id_.is_valid()) {
        VLOG(file_references) << "Receive " << status << " for " << file_id_;
        td_->file_manager_->delete_file_reference(file_id_, file_reference_);
        td_->file_reference_manager_->repair_file_reference(
            file_id_, PromiseCreator::lambda([user_id = user_id_, file_id = file_id_, is_fallback = is_fallback_,
                                              old_photo_id = old_photo_id_,
                                              promise = std::move(promise_)](Result<Unit> result) mutable {
              if (result.is_error()) {
                return promise.set_error(Status::Error(400, "Can't find the photo"));
              }

              send_closure(G()->user_manager(), &UserManager::send_update_profile_photo_query, user_id, file_id,
                           old_photo_id, is_fallback, std::move(promise));
            }));
        return;
      } else {
        LOG(ERROR) << "Receive file reference error, but file_id = " << file_id_;
      }
    }

    promise_.set_error(std::move(status));
  }
};

class DeleteContactProfilePhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;

 public:
  explicit DeleteContactProfilePhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    CHECK(input_user != nullptr);
    user_id_ = user_id;

    int32 flags = 0;
    flags |= telegram_api::photos_uploadContactProfilePhoto::SAVE_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::photos_uploadContactProfilePhoto(flags, false /*ignored*/, false /*ignored*/,
                                                       std::move(input_user), nullptr, nullptr, 0, nullptr),
        {{user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::photos_uploadContactProfilePhoto>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    ptr->photo_ = nullptr;
    td_->user_manager_->on_set_profile_photo(user_id_, std::move(ptr), false, 0, std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteProfilePhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  int64 profile_photo_id_;

 public:
  explicit DeleteProfilePhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 profile_photo_id) {
    profile_photo_id_ = profile_photo_id;
    vector<telegram_api::object_ptr<telegram_api::InputPhoto>> input_photo_ids;
    input_photo_ids.push_back(telegram_api::make_object<telegram_api::inputPhoto>(profile_photo_id, 0, BufferSlice()));
    send_query(G()->net_query_creator().create(telegram_api::photos_deletePhotos(std::move(input_photo_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::photos_deletePhotos>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteProfilePhotoQuery: " << result;
    if (result.size() != 1u) {
      LOG(WARNING) << "Photo can't be deleted";
      return on_error(Status::Error(400, "Photo can't be deleted"));
    }

    td_->user_manager_->on_delete_profile_photo(profile_photo_id_, std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateColorQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  bool for_profile_;
  AccentColorId accent_color_id_;
  CustomEmojiId background_custom_emoji_id_;

 public:
  explicit UpdateColorQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool for_profile, AccentColorId accent_color_id, CustomEmojiId background_custom_emoji_id) {
    for_profile_ = for_profile;
    accent_color_id_ = accent_color_id;
    background_custom_emoji_id_ = background_custom_emoji_id;
    int32 flags = 0;
    if (for_profile) {
      flags |= telegram_api::account_updateColor::FOR_PROFILE_MASK;
    }
    if (accent_color_id.is_valid()) {
      flags |= telegram_api::account_updateColor::COLOR_MASK;
    }
    if (background_custom_emoji_id.is_valid()) {
      flags |= telegram_api::account_updateColor::BACKGROUND_EMOJI_ID_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateColor(flags, false /*ignored*/, accent_color_id.get(),
                                          background_custom_emoji_id.get()),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateColor>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdateColorQuery: " << result_ptr.ok();
    td_->user_manager_->on_update_accent_color_success(for_profile_, accent_color_id_, background_custom_emoji_id_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateProfileQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  int32 flags_;
  string first_name_;
  string last_name_;
  string about_;

 public:
  explicit UpdateProfileQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 flags, const string &first_name, const string &last_name, const string &about) {
    flags_ = flags;
    first_name_ = first_name;
    last_name_ = last_name;
    about_ = about;
    send_query(G()->net_query_creator().create(telegram_api::account_updateProfile(flags, first_name, last_name, about),
                                               {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateProfile>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdateProfileQuery: " << to_string(result_ptr.ok());
    td_->user_manager_->on_get_user(result_ptr.move_as_ok(), "UpdateProfileQuery");
    td_->user_manager_->on_update_profile_success(flags_, first_name_, last_name_, about_);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleUserEmojiStatusPermissionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;
  bool can_manage_emoji_status_;

 public:
  explicit ToggleUserEmojiStatusPermissionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
            bool can_manage_emoji_status) {
    user_id_ = user_id;
    can_manage_emoji_status_ = can_manage_emoji_status;
    send_query(G()->net_query_creator().create(
        telegram_api::bots_toggleUserEmojiStatusPermission(std::move(input_user), can_manage_emoji_status),
        {{DialogId(user_id)}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_toggleUserEmojiStatusPermission>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (result_ptr.ok()) {
      td_->user_manager_->on_update_bot_can_manage_emoji_status(user_id_, can_manage_emoji_status_);
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateUserEmojiStatusQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateUserEmojiStatusQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
            const unique_ptr<EmojiStatus> &emoji_status) {
    send_query(
        G()->net_query_creator().create(telegram_api::bots_updateUserEmojiStatus(
                                            std::move(input_user), EmojiStatus::get_input_emoji_status(emoji_status)),
                                        {{DialogId(user_id)}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_updateUserEmojiStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "USER_PERMISSION_DENIED") {
      return promise_.set_error(Status::Error(403, "Not enough rights to change the user's emoji status"));
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateUsernameQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateUsernameQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &username) {
    send_query(G()->net_query_creator().create(telegram_api::account_updateUsername(username), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdateUsernameQuery: " << to_string(result_ptr.ok());
    td_->user_manager_->on_get_user(result_ptr.move_as_ok(), "UpdateUsernameQuery");
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED" && !td_->auth_manager_->is_bot()) {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleUsernameQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  string username_;
  bool is_active_;

 public:
  explicit ToggleUsernameQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(string &&username, bool is_active) {
    username_ = std::move(username);
    is_active_ = is_active;
    send_query(G()->net_query_creator().create(telegram_api::account_toggleUsername(username_, is_active_), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_toggleUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ToggleUsernameQuery: " << result;
    td_->user_manager_->on_update_username_is_active(td_->user_manager_->get_my_id(), std::move(username_), is_active_,
                                                     std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED") {
      td_->user_manager_->on_update_username_is_active(td_->user_manager_->get_my_id(), std::move(username_),
                                                       is_active_, std::move(promise_));
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ReorderUsernamesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  vector<string> usernames_;

 public:
  explicit ReorderUsernamesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<string> &&usernames) {
    usernames_ = usernames;
    send_query(G()->net_query_creator().create(telegram_api::account_reorderUsernames(std::move(usernames)), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_reorderUsernames>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ReorderUsernamesQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Usernames weren't updated"));
    }

    td_->user_manager_->on_update_active_usernames_order(td_->user_manager_->get_my_id(), std::move(usernames_),
                                                         std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED") {
      td_->user_manager_->on_update_active_usernames_order(td_->user_manager_->get_my_id(), std::move(usernames_),
                                                           std::move(promise_));
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleBotUsernameQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId bot_user_id_;
  string username_;
  bool is_active_;

 public:
  explicit ToggleBotUsernameQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, string &&username, bool is_active) {
    bot_user_id_ = bot_user_id;
    username_ = std::move(username);
    is_active_ = is_active;
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id_);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    send_query(G()->net_query_creator().create(
        telegram_api::bots_toggleUsername(r_input_user.move_as_ok(), username_, is_active_), {{bot_user_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_toggleUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ToggleBotUsernameQuery: " << result;
    td_->user_manager_->on_update_username_is_active(bot_user_id_, std::move(username_), is_active_,
                                                     std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED") {
      td_->user_manager_->on_update_username_is_active(bot_user_id_, std::move(username_), is_active_,
                                                       std::move(promise_));
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ReorderBotUsernamesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId bot_user_id_;
  vector<string> usernames_;

 public:
  explicit ReorderBotUsernamesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, vector<string> &&usernames) {
    bot_user_id_ = bot_user_id;
    usernames_ = usernames;
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id_);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    send_query(G()->net_query_creator().create(
        telegram_api::bots_reorderUsernames(r_input_user.move_as_ok(), std::move(usernames)), {{bot_user_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_reorderUsernames>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ReorderBotUsernamesQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Usernames weren't updated"));
    }

    td_->user_manager_->on_update_active_usernames_order(bot_user_id_, std::move(usernames_), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED") {
      td_->user_manager_->on_update_active_usernames_order(bot_user_id_, std::move(usernames_), std::move(promise_));
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateBirthdayQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateBirthdayQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const Birthdate &birthdate) {
    int32 flags = 0;
    if (!birthdate.is_empty()) {
      flags |= telegram_api::account_updateBirthday::BIRTHDAY_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateBirthday(flags, birthdate.get_input_birthday()), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBirthday>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdateBirthdayQuery: " << result_ptr.ok();
    if (result_ptr.ok()) {
      promise_.set_value(Unit());
    } else {
      promise_.set_error(Status::Error(400, "Failed to change birthdate"));
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdatePersonalChannelQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit UpdatePersonalChannelQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;
    telegram_api::object_ptr<telegram_api::InputChannel> input_channel;
    if (channel_id == ChannelId()) {
      input_channel = telegram_api::make_object<telegram_api::inputChannelEmpty>();
    } else {
      input_channel = td_->chat_manager_->get_input_channel(channel_id);
      CHECK(input_channel != nullptr);
    }
    send_query(G()->net_query_creator().create(telegram_api::account_updatePersonalChannel(std::move(input_channel)),
                                               {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updatePersonalChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdatePersonalChannelQuery: " << result_ptr.ok();
    if (result_ptr.ok()) {
      promise_.set_value(Unit());
    } else {
      promise_.set_error(Status::Error(400, "Failed to change personal chat"));
    }
  }

  void on_error(Status status) final {
    if (channel_id_.is_valid()) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "UpdatePersonalChannelQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateEmojiStatusQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateEmojiStatusQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const unique_ptr<EmojiStatus> &emoji_status) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateEmojiStatus(EmojiStatus::get_input_emoji_status(emoji_status)), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateEmojiStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for UpdateEmojiStatusQuery: " << result_ptr.ok();
    if (result_ptr.ok()) {
      promise_.set_value(Unit());
    } else {
      promise_.set_error(Status::Error(400, "Failed to change Premium badge"));
    }
  }

  void on_error(Status status) final {
    get_recent_emoji_statuses(td_, Auto());
    promise_.set_error(std::move(status));
  }
};

class ToggleSponsoredMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleSponsoredMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool sponsored_enabled) {
    send_query(
        G()->net_query_creator().create(telegram_api::account_toggleSponsoredMessages(sponsored_enabled), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_toggleSponsoredMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for ToggleSponsoredMessagesQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetUsersQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetUsersQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<telegram_api::object_ptr<telegram_api::InputUser>> &&input_users) {
    send_query(G()->net_query_creator().create(telegram_api::users_getUsers(std::move(input_users))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::users_getUsers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_get_users(result_ptr.move_as_ok(), "GetUsersQuery");

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetFullUserQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetFullUserQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    send_query(G()->net_query_creator().create(telegram_api::users_getFullUser(std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::users_getFullUser>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetFullUserQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetFullUserQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetFullUserQuery");
    td_->user_manager_->on_get_user_full(std::move(ptr->full_user_));
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetUserPhotosQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;
  int32 offset_;
  int32 limit_;

 public:
  explicit GetUserPhotosQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user, int32 offset, int32 limit,
            int64 photo_id) {
    user_id_ = user_id;
    offset_ = offset;
    limit_ = limit;
    send_query(G()->net_query_creator().create(
        telegram_api::photos_getUserPhotos(std::move(input_user), offset, photo_id, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::photos_getUserPhotos>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();

    LOG(INFO) << "Receive result for GetUserPhotosQuery: " << to_string(ptr);
    int32 constructor_id = ptr->get_id();
    if (constructor_id == telegram_api::photos_photos::ID) {
      auto photos = move_tl_object_as<telegram_api::photos_photos>(ptr);

      td_->user_manager_->on_get_users(std::move(photos->users_), "GetUserPhotosQuery");
      auto photos_size = narrow_cast<int32>(photos->photos_.size());
      td_->user_manager_->on_get_user_photos(user_id_, offset_, limit_, photos_size, std::move(photos->photos_));
    } else {
      CHECK(constructor_id == telegram_api::photos_photosSlice::ID);
      auto photos = move_tl_object_as<telegram_api::photos_photosSlice>(ptr);

      td_->user_manager_->on_get_users(std::move(photos->users_), "GetUserPhotosQuery slice");
      td_->user_manager_->on_get_user_photos(user_id_, offset_, limit_, photos->count_, std::move(photos->photos_));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetSupportUserQuery final : public Td::ResultHandler {
  Promise<UserId> promise_;

 public:
  explicit GetSupportUserQuery(Promise<UserId> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_getSupport()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getSupport>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetSupportUserQuery: " << to_string(ptr);

    auto user_id = UserManager::get_user_id(ptr->user_);
    td_->user_manager_->on_get_user(std::move(ptr->user_), "GetSupportUserQuery");

    promise_.set_value(std::move(user_id));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetIsPremiumRequiredToContactQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  vector<UserId> user_ids_;

 public:
  explicit GetIsPremiumRequiredToContactQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<UserId> &&user_ids, vector<telegram_api::object_ptr<telegram_api::InputUser>> &&input_users) {
    user_ids_ = std::move(user_ids);
    send_query(G()->net_query_creator().create(telegram_api::users_getRequirementsToContact(std::move(input_users))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::users_getRequirementsToContact>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetIsPremiumRequiredToContactQuery: " << to_string(ptr);
    td_->user_manager_->on_get_is_premium_required_to_contact_users(std::move(user_ids_), std::move(ptr),
                                                                    std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

template <class StorerT>
void UserManager::User::store(StorerT &storer) const {
  using td::store;
  bool has_last_name = !last_name.empty();
  bool legacy_has_username = false;
  bool has_photo = photo.small_file_id.is_valid();
  bool has_language_code = !language_code.empty();
  bool have_access_hash = access_hash != -1;
  bool has_cache_version = cache_version != 0;
  bool has_is_contact = true;
  bool has_restriction_reasons = !restriction_reasons.empty();
  bool has_emoji_status = emoji_status != nullptr;
  bool has_usernames = !usernames.is_empty();
  bool has_flags2 = true;
  bool has_max_active_story_id = max_active_story_id.is_valid();
  bool has_max_read_story_id = max_read_story_id.is_valid();
  bool has_max_active_story_id_next_reload_time = max_active_story_id_next_reload_time > Time::now();
  bool has_accent_color_id = accent_color_id.is_valid();
  bool has_background_custom_emoji_id = background_custom_emoji_id.is_valid();
  bool has_profile_accent_color_id = profile_accent_color_id.is_valid();
  bool has_profile_background_custom_emoji_id = profile_background_custom_emoji_id.is_valid();
  bool has_bot_active_users = bot_active_users != 0;
  bool has_bot_verification_icon = bot_verification_icon.is_valid();
  bool has_paid_message_star_count = paid_message_star_count != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_received);
  STORE_FLAG(is_verified);
  STORE_FLAG(is_deleted);
  STORE_FLAG(is_bot);
  STORE_FLAG(can_join_groups);
  STORE_FLAG(can_read_all_group_messages);
  STORE_FLAG(is_inline_bot);
  STORE_FLAG(need_location_bot);
  STORE_FLAG(has_last_name);
  STORE_FLAG(legacy_has_username);
  STORE_FLAG(has_photo);
  STORE_FLAG(false);  // legacy is_restricted
  STORE_FLAG(has_language_code);
  STORE_FLAG(have_access_hash);
  STORE_FLAG(is_support);
  STORE_FLAG(is_min_access_hash);
  STORE_FLAG(is_scam);
  STORE_FLAG(has_cache_version);
  STORE_FLAG(has_is_contact);
  STORE_FLAG(is_contact);
  STORE_FLAG(is_mutual_contact);
  STORE_FLAG(has_restriction_reasons);
  STORE_FLAG(need_apply_min_photo);
  STORE_FLAG(is_fake);
  STORE_FLAG(can_be_added_to_attach_menu);
  STORE_FLAG(is_premium);
  STORE_FLAG(attach_menu_enabled);
  STORE_FLAG(has_emoji_status);
  STORE_FLAG(has_usernames);
  STORE_FLAG(can_be_edited_bot);
  END_STORE_FLAGS();
  if (has_flags2) {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_close_friend);
    STORE_FLAG(stories_hidden);
    STORE_FLAG(false);
    STORE_FLAG(has_max_active_story_id);
    STORE_FLAG(has_max_read_story_id);
    STORE_FLAG(has_max_active_story_id_next_reload_time);
    STORE_FLAG(has_accent_color_id);
    STORE_FLAG(has_background_custom_emoji_id);
    STORE_FLAG(has_profile_accent_color_id);
    STORE_FLAG(has_profile_background_custom_emoji_id);
    STORE_FLAG(contact_require_premium);
    STORE_FLAG(is_business_bot);
    STORE_FLAG(has_bot_active_users);
    STORE_FLAG(has_main_app);
    STORE_FLAG(has_bot_verification_icon);
    STORE_FLAG(has_paid_message_star_count);
    END_STORE_FLAGS();
  }
  store(first_name, storer);
  if (has_last_name) {
    store(last_name, storer);
  }
  store(phone_number, storer);
  if (have_access_hash) {
    store(access_hash, storer);
  }
  if (has_photo) {
    store(photo, storer);
  }
  store(was_online, storer);
  if (has_restriction_reasons) {
    store(restriction_reasons, storer);
  }
  if (is_inline_bot) {
    store(inline_query_placeholder, storer);
  }
  if (is_bot) {
    store(bot_info_version, storer);
  }
  if (has_language_code) {
    store(language_code, storer);
  }
  if (has_cache_version) {
    store(cache_version, storer);
  }
  if (has_emoji_status) {
    store(emoji_status, storer);
  }
  if (has_usernames) {
    store(usernames, storer);
  }
  if (has_max_active_story_id) {
    store(max_active_story_id, storer);
  }
  if (has_max_read_story_id) {
    store(max_read_story_id, storer);
  }
  if (has_max_active_story_id_next_reload_time) {
    store_time(max_active_story_id_next_reload_time, storer);
  }
  if (has_accent_color_id) {
    store(accent_color_id, storer);
  }
  if (has_background_custom_emoji_id) {
    store(background_custom_emoji_id, storer);
  }
  if (has_profile_accent_color_id) {
    store(profile_accent_color_id, storer);
  }
  if (has_profile_background_custom_emoji_id) {
    store(profile_background_custom_emoji_id, storer);
  }
  if (has_bot_active_users) {
    store(bot_active_users, storer);
  }
  if (has_bot_verification_icon) {
    store(bot_verification_icon, storer);
  }
  if (has_paid_message_star_count) {
    store(paid_message_star_count, storer);
  }
}

template <class ParserT>
void UserManager::User::parse(ParserT &parser) {
  using td::parse;
  bool has_last_name;
  bool legacy_has_username;
  bool has_photo;
  bool legacy_is_restricted;
  bool has_language_code;
  bool have_access_hash;
  bool has_cache_version;
  bool has_is_contact;
  bool has_restriction_reasons;
  bool has_emoji_status;
  bool has_usernames;
  bool has_flags2 = parser.version() >= static_cast<int32>(Version::AddUserFlags2);
  bool legacy_has_stories = false;
  bool has_max_active_story_id = false;
  bool has_max_read_story_id = false;
  bool has_max_active_story_id_next_reload_time = false;
  bool has_accent_color_id = false;
  bool has_background_custom_emoji_id = false;
  bool has_profile_accent_color_id = false;
  bool has_profile_background_custom_emoji_id = false;
  bool has_bot_active_users = false;
  bool has_bot_verification_icon = false;
  bool has_paid_message_star_count = false;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_received);
  PARSE_FLAG(is_verified);
  PARSE_FLAG(is_deleted);
  PARSE_FLAG(is_bot);
  PARSE_FLAG(can_join_groups);
  PARSE_FLAG(can_read_all_group_messages);
  PARSE_FLAG(is_inline_bot);
  PARSE_FLAG(need_location_bot);
  PARSE_FLAG(has_last_name);
  PARSE_FLAG(legacy_has_username);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(legacy_is_restricted);
  PARSE_FLAG(has_language_code);
  PARSE_FLAG(have_access_hash);
  PARSE_FLAG(is_support);
  PARSE_FLAG(is_min_access_hash);
  PARSE_FLAG(is_scam);
  PARSE_FLAG(has_cache_version);
  PARSE_FLAG(has_is_contact);
  PARSE_FLAG(is_contact);
  PARSE_FLAG(is_mutual_contact);
  PARSE_FLAG(has_restriction_reasons);
  PARSE_FLAG(need_apply_min_photo);
  PARSE_FLAG(is_fake);
  PARSE_FLAG(can_be_added_to_attach_menu);
  PARSE_FLAG(is_premium);
  PARSE_FLAG(attach_menu_enabled);
  PARSE_FLAG(has_emoji_status);
  PARSE_FLAG(has_usernames);
  PARSE_FLAG(can_be_edited_bot);
  END_PARSE_FLAGS();
  if (has_flags2) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_close_friend);
    PARSE_FLAG(stories_hidden);
    PARSE_FLAG(legacy_has_stories);
    PARSE_FLAG(has_max_active_story_id);
    PARSE_FLAG(has_max_read_story_id);
    PARSE_FLAG(has_max_active_story_id_next_reload_time);
    PARSE_FLAG(has_accent_color_id);
    PARSE_FLAG(has_background_custom_emoji_id);
    PARSE_FLAG(has_profile_accent_color_id);
    PARSE_FLAG(has_profile_background_custom_emoji_id);
    PARSE_FLAG(contact_require_premium);
    PARSE_FLAG(is_business_bot);
    PARSE_FLAG(has_bot_active_users);
    PARSE_FLAG(has_main_app);
    PARSE_FLAG(has_bot_verification_icon);
    PARSE_FLAG(has_paid_message_star_count);
    END_PARSE_FLAGS();
  }
  parse(first_name, parser);
  if (has_last_name) {
    parse(last_name, parser);
  }
  if (legacy_has_username) {
    CHECK(!has_usernames);
    string username;
    parse(username, parser);
    usernames = Usernames(std::move(username), vector<telegram_api::object_ptr<telegram_api::username>>());
  }
  parse(phone_number, parser);
  if (parser.version() < static_cast<int32>(Version::FixMinUsers)) {
    have_access_hash = is_received;
  }
  if (have_access_hash) {
    parse(access_hash, parser);
  } else {
    is_min_access_hash = true;
  }
  if (has_photo) {
    parse(photo, parser);
  }
  if (!has_is_contact) {
    // enum class LinkState : uint8 { Unknown, None, KnowsPhoneNumber, Contact };

    uint32 link_state_inbound;
    uint32 link_state_outbound;
    parse(link_state_inbound, parser);
    parse(link_state_outbound, parser);

    is_contact = link_state_outbound == 3;
    is_mutual_contact = is_contact && link_state_inbound == 3;
    is_close_friend = false;
  }
  parse(was_online, parser);
  if (legacy_is_restricted) {
    string restriction_reason;
    parse(restriction_reason, parser);
    restriction_reasons = get_restriction_reasons(restriction_reason);
  } else if (has_restriction_reasons) {
    parse(restriction_reasons, parser);
  }
  if (is_inline_bot) {
    parse(inline_query_placeholder, parser);
  }
  if (is_bot) {
    parse(bot_info_version, parser);
  }
  if (has_language_code) {
    parse(language_code, parser);
  }
  if (has_cache_version) {
    parse(cache_version, parser);
  }
  if (has_emoji_status) {
    parse(emoji_status, parser);
  }
  if (has_usernames) {
    CHECK(!legacy_has_username);
    parse(usernames, parser);
  }
  if (has_max_active_story_id) {
    parse(max_active_story_id, parser);
  }
  if (has_max_read_story_id) {
    parse(max_read_story_id, parser);
  }
  if (has_max_active_story_id_next_reload_time) {
    parse_time(max_active_story_id_next_reload_time, parser);
  }
  if (has_accent_color_id) {
    parse(accent_color_id, parser);
  }
  if (has_background_custom_emoji_id) {
    parse(background_custom_emoji_id, parser);
  }
  if (has_profile_accent_color_id) {
    parse(profile_accent_color_id, parser);
  }
  if (has_profile_background_custom_emoji_id) {
    parse(profile_background_custom_emoji_id, parser);
  }
  if (has_bot_active_users) {
    parse(bot_active_users, parser);
  }
  if (has_bot_verification_icon) {
    parse(bot_verification_icon, parser);
  }
  if (has_paid_message_star_count) {
    parse(paid_message_star_count, parser);
  }

  if (!check_utf8(first_name)) {
    LOG(ERROR) << "Have invalid first name \"" << first_name << '"';
    first_name.clear();
    cache_version = 0;
  }
  if (!check_utf8(last_name)) {
    LOG(ERROR) << "Have invalid last name \"" << last_name << '"';
    last_name.clear();
    cache_version = 0;
  }

  clean_phone_number(phone_number);
  if (first_name.empty() && last_name.empty()) {
    first_name = phone_number;
  }
  if (!is_contact && is_mutual_contact) {
    LOG(ERROR) << "Have invalid flag is_mutual_contact";
    is_mutual_contact = false;
    cache_version = 0;
  }
  if (!is_contact && is_close_friend) {
    LOG(ERROR) << "Have invalid flag is_close_friend";
    is_close_friend = false;
    cache_version = 0;
  }
}

template <class StorerT>
void UserManager::UserFull::store(StorerT &storer) const {
  using td::store;
  bool has_about = !about.empty();
  bool has_photo = !photo.is_empty();
  bool has_description = bot_info != nullptr && !bot_info->description.empty();
  bool has_commands = bot_info != nullptr && !bot_info->commands.empty();
  bool has_private_forward_name = !private_forward_name.empty();
  bool has_group_administrator_rights =
      bot_info != nullptr && bot_info->group_administrator_rights != AdministratorRights();
  bool has_broadcast_administrator_rights =
      bot_info != nullptr && bot_info->broadcast_administrator_rights != AdministratorRights();
  bool has_menu_button = bot_info != nullptr && bot_info->menu_button != nullptr;
  bool has_description_photo = bot_info != nullptr && !bot_info->description_photo.is_empty();
  bool has_description_animation = bot_info != nullptr && bot_info->description_animation_file_id.is_valid();
  bool has_personal_photo = !personal_photo.is_empty();
  bool has_fallback_photo = !fallback_photo.is_empty();
  bool has_business_info = business_info != nullptr && !business_info->is_empty();
  bool has_birthdate = !birthdate.is_empty();
  bool has_personal_channel_id = personal_channel_id.is_valid();
  bool has_flags2 = true;
  bool has_privacy_policy_url = bot_info != nullptr && !bot_info->privacy_policy_url.empty();
  bool has_gift_count = gift_count != 0;
  bool has_placeholder_path = bot_info != nullptr && !bot_info->placeholder_path.empty();
  bool has_background_color = bot_info != nullptr && bot_info->background_color != -1;
  bool has_background_dark_color = bot_info != nullptr && bot_info->background_dark_color != -1;
  bool has_header_color = bot_info != nullptr && bot_info->header_color != -1;
  bool has_header_dark_color = bot_info != nullptr && bot_info->header_dark_color != -1;
  bool has_referral_program_info = bot_info != nullptr && bot_info->referral_program_info.is_valid();
  bool has_verifier_settings = bot_info != nullptr && bot_info->verifier_settings != nullptr;
  bool has_bot_verification = bot_verification != nullptr;
  bool has_charge_paid_message_stars = charge_paid_message_stars != 0;
  bool has_send_paid_message_stars = send_paid_message_stars != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_about);
  STORE_FLAG(is_blocked);
  STORE_FLAG(can_be_called);
  STORE_FLAG(has_private_calls);
  STORE_FLAG(can_pin_messages);
  STORE_FLAG(need_phone_number_privacy_exception);
  STORE_FLAG(has_photo);
  STORE_FLAG(supports_video_calls);
  STORE_FLAG(has_description);
  STORE_FLAG(has_commands);
  STORE_FLAG(has_private_forward_name);
  STORE_FLAG(has_group_administrator_rights);
  STORE_FLAG(has_broadcast_administrator_rights);
  STORE_FLAG(has_menu_button);
  STORE_FLAG(has_description_photo);
  STORE_FLAG(has_description_animation);
  STORE_FLAG(false);  // has_premium_gift_options
  STORE_FLAG(voice_messages_forbidden);
  STORE_FLAG(has_personal_photo);
  STORE_FLAG(has_fallback_photo);
  STORE_FLAG(has_pinned_stories);
  STORE_FLAG(is_blocked_for_stories);
  STORE_FLAG(wallpaper_overridden);
  STORE_FLAG(read_dates_private);
  STORE_FLAG(contact_require_premium);
  STORE_FLAG(has_business_info);
  STORE_FLAG(has_birthdate);
  STORE_FLAG(has_personal_channel_id);
  STORE_FLAG(sponsored_enabled);
  STORE_FLAG(has_flags2);
  END_STORE_FLAGS();
  if (has_flags2) {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_preview_medias);
    STORE_FLAG(has_privacy_policy_url);
    STORE_FLAG(has_gift_count);
    STORE_FLAG(can_view_revenue);
    STORE_FLAG(can_manage_emoji_status);
    STORE_FLAG(has_placeholder_path);
    STORE_FLAG(has_background_color);
    STORE_FLAG(has_background_dark_color);
    STORE_FLAG(has_header_color);
    STORE_FLAG(has_header_dark_color);
    STORE_FLAG(has_referral_program_info);
    STORE_FLAG(has_verifier_settings);
    STORE_FLAG(has_bot_verification);
    STORE_FLAG(has_charge_paid_message_stars);
    STORE_FLAG(has_send_paid_message_stars);
    END_STORE_FLAGS();
  }
  if (has_about) {
    store(about, storer);
  }
  store(common_chat_count, storer);
  store_time(expires_at, storer);
  if (has_photo) {
    store(photo, storer);
  }
  if (has_description) {
    store(bot_info->description, storer);
  }
  if (has_commands) {
    store(bot_info->commands, storer);
  }
  if (has_private_forward_name) {
    store(private_forward_name, storer);
  }
  if (has_group_administrator_rights) {
    store(bot_info->group_administrator_rights, storer);
  }
  if (has_broadcast_administrator_rights) {
    store(bot_info->broadcast_administrator_rights, storer);
  }
  if (has_menu_button) {
    store(bot_info->menu_button, storer);
  }
  if (has_description_photo) {
    store(bot_info->description_photo, storer);
  }
  if (has_description_animation) {
    storer.context()->td().get_actor_unsafe()->animations_manager_->store_animation(
        bot_info->description_animation_file_id, storer);
  }
  if (has_personal_photo) {
    store(personal_photo, storer);
  }
  if (has_fallback_photo) {
    store(fallback_photo, storer);
  }
  if (has_business_info) {
    store(business_info, storer);
  }
  if (has_birthdate) {
    store(birthdate, storer);
  }
  if (has_personal_channel_id) {
    store(personal_channel_id, storer);
  }
  if (has_privacy_policy_url) {
    store(bot_info->privacy_policy_url, storer);
  }
  if (has_gift_count) {
    store(gift_count, storer);
  }
  if (has_placeholder_path) {
    store(bot_info->placeholder_path, storer);
  }
  if (has_background_color) {
    store(bot_info->background_color, storer);
  }
  if (has_background_dark_color) {
    store(bot_info->background_dark_color, storer);
  }
  if (has_header_color) {
    store(bot_info->header_color, storer);
  }
  if (has_header_dark_color) {
    store(bot_info->header_dark_color, storer);
  }
  if (has_referral_program_info) {
    store(bot_info->referral_program_info, storer);
  }
  if (has_verifier_settings) {
    store(bot_info->verifier_settings, storer);
  }
  if (has_bot_verification) {
    store(bot_verification, storer);
  }
  if (has_charge_paid_message_stars) {
    store(charge_paid_message_stars, storer);
  }
  if (has_send_paid_message_stars) {
    store(send_paid_message_stars, storer);
  }
}

template <class ParserT>
void UserManager::UserFull::parse(ParserT &parser) {
  using td::parse;
  bool has_about;
  bool has_photo;
  bool has_description;
  bool has_commands;
  bool has_private_forward_name;
  bool has_group_administrator_rights;
  bool has_broadcast_administrator_rights;
  bool has_menu_button;
  bool has_description_photo;
  bool has_description_animation;
  bool legacy_has_premium_gift_options;
  bool has_personal_photo;
  bool has_fallback_photo;
  bool has_business_info;
  bool has_birthdate;
  bool has_personal_channel_id;
  bool has_flags2;
  bool has_privacy_policy_url = false;
  bool has_gift_count = false;
  bool has_placeholder_path = false;
  bool has_background_color = false;
  bool has_background_dark_color = false;
  bool has_header_color = false;
  bool has_header_dark_color = false;
  bool has_referral_program_info = false;
  bool has_verifier_settings = false;
  bool has_bot_verification = false;
  bool has_charge_paid_message_stars = false;
  bool has_send_paid_message_stars = false;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_about);
  PARSE_FLAG(is_blocked);
  PARSE_FLAG(can_be_called);
  PARSE_FLAG(has_private_calls);
  PARSE_FLAG(can_pin_messages);
  PARSE_FLAG(need_phone_number_privacy_exception);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(supports_video_calls);
  PARSE_FLAG(has_description);
  PARSE_FLAG(has_commands);
  PARSE_FLAG(has_private_forward_name);
  PARSE_FLAG(has_group_administrator_rights);
  PARSE_FLAG(has_broadcast_administrator_rights);
  PARSE_FLAG(has_menu_button);
  PARSE_FLAG(has_description_photo);
  PARSE_FLAG(has_description_animation);
  PARSE_FLAG(legacy_has_premium_gift_options);
  PARSE_FLAG(voice_messages_forbidden);
  PARSE_FLAG(has_personal_photo);
  PARSE_FLAG(has_fallback_photo);
  PARSE_FLAG(has_pinned_stories);
  PARSE_FLAG(is_blocked_for_stories);
  PARSE_FLAG(wallpaper_overridden);
  PARSE_FLAG(read_dates_private);
  PARSE_FLAG(contact_require_premium);
  PARSE_FLAG(has_business_info);
  PARSE_FLAG(has_birthdate);
  PARSE_FLAG(has_personal_channel_id);
  PARSE_FLAG(sponsored_enabled);
  PARSE_FLAG(has_flags2);
  END_PARSE_FLAGS();
  if (has_flags2) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_preview_medias);
    PARSE_FLAG(has_privacy_policy_url);
    PARSE_FLAG(has_gift_count);
    PARSE_FLAG(can_view_revenue);
    PARSE_FLAG(can_manage_emoji_status);
    PARSE_FLAG(has_placeholder_path);
    PARSE_FLAG(has_background_color);
    PARSE_FLAG(has_background_dark_color);
    PARSE_FLAG(has_header_color);
    PARSE_FLAG(has_header_dark_color);
    PARSE_FLAG(has_referral_program_info);
    PARSE_FLAG(has_verifier_settings);
    PARSE_FLAG(has_bot_verification);
    PARSE_FLAG(has_charge_paid_message_stars);
    PARSE_FLAG(has_send_paid_message_stars);
    END_PARSE_FLAGS();
  }
  if (has_about) {
    parse(about, parser);
  }
  parse(common_chat_count, parser);
  parse_time(expires_at, parser);
  if (has_photo) {
    parse(photo, parser);
  }
  if (has_description) {
    parse(add_bot_info()->description, parser);
  }
  if (has_commands) {
    parse(add_bot_info()->commands, parser);
  }
  if (has_private_forward_name) {
    parse(private_forward_name, parser);
  }
  if (has_group_administrator_rights) {
    parse(add_bot_info()->group_administrator_rights, parser);
  }
  if (has_broadcast_administrator_rights) {
    parse(add_bot_info()->broadcast_administrator_rights, parser);
  }
  if (has_menu_button) {
    parse(add_bot_info()->menu_button, parser);
  }
  if (has_description_photo) {
    parse(add_bot_info()->description_photo, parser);
  }
  if (has_description_animation) {
    add_bot_info()->description_animation_file_id =
        parser.context()->td().get_actor_unsafe()->animations_manager_->parse_animation(parser);
  }
  if (legacy_has_premium_gift_options) {
    vector<PremiumGiftOption> premium_gift_options;
    parse(premium_gift_options, parser);
  }
  if (has_personal_photo) {
    parse(personal_photo, parser);
  }
  if (has_fallback_photo) {
    parse(fallback_photo, parser);
  }
  if (has_business_info) {
    parse(business_info, parser);
  }
  if (has_birthdate) {
    parse(birthdate, parser);
  }
  if (has_personal_channel_id) {
    parse(personal_channel_id, parser);
  }
  if (has_privacy_policy_url) {
    parse(add_bot_info()->privacy_policy_url, parser);
  }
  if (has_gift_count) {
    parse(gift_count, parser);
  }
  if (has_placeholder_path) {
    parse(add_bot_info()->placeholder_path, parser);
  }
  if (has_background_color) {
    parse(add_bot_info()->background_color, parser);
  }
  if (has_background_dark_color) {
    parse(add_bot_info()->background_dark_color, parser);
  }
  if (has_header_color) {
    parse(add_bot_info()->header_color, parser);
  }
  if (has_header_dark_color) {
    parse(add_bot_info()->header_dark_color, parser);
  }
  if (has_referral_program_info) {
    parse(add_bot_info()->referral_program_info, parser);
  }
  if (has_verifier_settings) {
    parse(add_bot_info()->verifier_settings, parser);
  }
  if (has_bot_verification) {
    parse(bot_verification, parser);
  }
  if (has_charge_paid_message_stars) {
    parse(charge_paid_message_stars, parser);
  }
  if (has_send_paid_message_stars) {
    parse(send_paid_message_stars, parser);
  }
}

template <class StorerT>
void UserManager::SecretChat::store(StorerT &storer) const {
  using td::store;
  bool has_layer = layer > static_cast<int32>(SecretChatLayer::Default);
  bool has_initial_folder_id = initial_folder_id != FolderId();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_outbound);
  STORE_FLAG(has_layer);
  STORE_FLAG(has_initial_folder_id);
  END_STORE_FLAGS();

  store(access_hash, storer);
  store(user_id, storer);
  store(state, storer);
  store(ttl, storer);
  store(date, storer);
  store(key_hash, storer);
  if (has_layer) {
    store(layer, storer);
  }
  if (has_initial_folder_id) {
    store(initial_folder_id, storer);
  }
}

template <class ParserT>
void UserManager::SecretChat::parse(ParserT &parser) {
  using td::parse;
  bool has_layer;
  bool has_initial_folder_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_outbound);
  PARSE_FLAG(has_layer);
  PARSE_FLAG(has_initial_folder_id);
  END_PARSE_FLAGS();

  if (parser.version() >= static_cast<int32>(Version::AddAccessHashToSecretChat)) {
    parse(access_hash, parser);
  }
  parse(user_id, parser);
  parse(state, parser);
  parse(ttl, parser);
  parse(date, parser);
  if (parser.version() >= static_cast<int32>(Version::AddKeyHashToSecretChat)) {
    parse(key_hash, parser);
  }
  if (has_layer) {
    parse(layer, parser);
  } else {
    layer = static_cast<int32>(SecretChatLayer::Default);
  }
  if (has_initial_folder_id) {
    parse(initial_folder_id, parser);
  }
}

class UserManager::UserLogEvent {
 public:
  UserId user_id;
  const User *u_in = nullptr;
  unique_ptr<User> u_out;

  UserLogEvent() = default;

  UserLogEvent(UserId user_id, const User *u) : user_id(user_id), u_in(u) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(user_id, storer);
    td::store(*u_in, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(user_id, parser);
    td::parse(u_out, parser);
  }
};

class UserManager::SecretChatLogEvent {
 public:
  SecretChatId secret_chat_id;
  const SecretChat *c_in = nullptr;
  unique_ptr<SecretChat> c_out;

  SecretChatLogEvent() = default;

  SecretChatLogEvent(SecretChatId secret_chat_id, const SecretChat *c) : secret_chat_id(secret_chat_id), c_in(c) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(secret_chat_id, storer);
    td::store(*c_in, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(secret_chat_id, parser);
    td::parse(c_out, parser);
  }
};

class UserManager::UploadProfilePhotoCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->user_manager(), &UserManager::on_upload_profile_photo, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->user_manager(), &UserManager::on_upload_profile_photo_error, file_upload_id,
                       std::move(error));
  }
};

UserManager::UserManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_profile_photo_callback_ = std::make_shared<UploadProfilePhotoCallback>();

  my_id_ = load_my_id();

  if (G()->use_chat_info_database()) {
    auto next_contacts_sync_date_string = G()->td_db()->get_binlog_pmc()->get("next_contacts_sync_date");
    if (!next_contacts_sync_date_string.empty()) {
      next_contacts_sync_date_ = min(to_integer<int32>(next_contacts_sync_date_string), G()->unix_time() + 100000);
    }

    auto saved_contact_count_string = G()->td_db()->get_binlog_pmc()->get("saved_contact_count");
    if (!saved_contact_count_string.empty()) {
      saved_contact_count_ = to_integer<int32>(saved_contact_count_string);
    }
  } else if (!td_->auth_manager_->is_bot()) {
    G()->td_db()->get_binlog_pmc()->erase("next_contacts_sync_date");
    G()->td_db()->get_binlog_pmc()->erase("saved_contact_count");
  }
  if (G()->use_sqlite_pmc()) {
    G()->td_db()->get_sqlite_pmc()->erase_by_prefix("us_bot_info", Auto());
  }

  if (!td_->auth_manager_->is_bot()) {
    was_online_local_ = to_integer<int32>(G()->td_db()->get_binlog_pmc()->get("my_was_online_local"));
    was_online_remote_ = to_integer<int32>(G()->td_db()->get_binlog_pmc()->get("my_was_online_remote"));
    auto unix_time = G()->unix_time();
    if (was_online_local_ >= unix_time && !td_->online_manager_->is_online()) {
      was_online_local_ = unix_time - 1;
    }
  }

  user_online_timeout_.set_callback(on_user_online_timeout_callback);
  user_online_timeout_.set_callback_data(static_cast<void *>(this));

  user_emoji_status_timeout_.set_callback(on_user_emoji_status_timeout_callback);
  user_emoji_status_timeout_.set_callback_data(static_cast<void *>(this));

  get_user_queries_.set_merge_function([this](vector<int64> query_ids, Promise<Unit> &&promise) {
    TRY_STATUS_PROMISE(promise, G()->close_status());
    auto input_users = transform(query_ids, [this](int64 query_id) { return get_input_user_force(UserId(query_id)); });
    td_->create_handler<GetUsersQuery>(std::move(promise))->send(std::move(input_users));
  });
  get_is_premium_required_to_contact_queries_.set_merge_function(
      [this](vector<int64> query_ids, Promise<Unit> &&promise) {
        TRY_STATUS_PROMISE(promise, G()->close_status());
        auto user_ids = UserId::get_user_ids(query_ids);
        auto input_users = transform(user_ids, [this](UserId user_id) { return get_input_user_force(user_id); });
        td_->create_handler<GetIsPremiumRequiredToContactQuery>(std::move(promise))
            ->send(std::move(user_ids), std::move(input_users));
      });
}

UserManager::~UserManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), users_, users_full_, user_photos_,
                                              unknown_users_, pending_user_photos_, user_profile_photo_file_source_ids_,
                                              my_photo_file_id_, user_full_file_source_ids_, secret_chats_,
                                              unknown_secret_chats_, secret_chats_with_user_);
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), loaded_from_database_users_,
                                              unavailable_user_fulls_, loaded_from_database_secret_chats_,
                                              resolved_phone_numbers_, all_imported_contacts_, restricted_user_ids_);
}

void UserManager::tear_down() {
  parent_.reset();

  LOG(DEBUG) << "Have " << users_.calc_size() << " users and " << secret_chats_.calc_size() << " secret chats to free";
  LOG(DEBUG) << "Have " << users_full_.calc_size() << " full users to free";
}

void UserManager::on_user_online_timeout_callback(void *user_manager_ptr, int64 user_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto user_manager = static_cast<UserManager *>(user_manager_ptr);
  send_closure_later(user_manager->actor_id(user_manager), &UserManager::on_user_online_timeout, UserId(user_id_long));
}

void UserManager::on_user_online_timeout(UserId user_id) {
  if (G()->close_flag()) {
    return;
  }

  auto u = get_user(user_id);
  CHECK(u != nullptr);
  CHECK(u->is_update_user_sent);

  LOG(INFO) << "Update " << user_id << " online status to offline";
  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateUserStatus>(user_id.get(),
                                                             get_user_status_object(user_id, u, G()->unix_time())));

  td_->dialog_participant_manager_->update_user_online_member_count(user_id);
}

void UserManager::on_user_emoji_status_timeout_callback(void *user_manager_ptr, int64 user_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto user_manager = static_cast<UserManager *>(user_manager_ptr);
  send_closure_later(user_manager->actor_id(user_manager), &UserManager::on_user_emoji_status_timeout,
                     UserId(user_id_long));
}

void UserManager::on_user_emoji_status_timeout(UserId user_id) {
  if (G()->close_flag()) {
    return;
  }

  auto u = get_user(user_id);
  CHECK(u != nullptr);
  CHECK(u->is_update_user_sent);

  update_user(u, user_id);
}

UserId UserManager::get_user_id(const telegram_api::object_ptr<telegram_api::User> &user) {
  CHECK(user != nullptr);
  switch (user->get_id()) {
    case telegram_api::userEmpty::ID:
      return UserId(static_cast<const telegram_api::userEmpty *>(user.get())->id_);
    case telegram_api::user::ID:
      return UserId(static_cast<const telegram_api::user *>(user.get())->id_);
    default:
      UNREACHABLE();
      return UserId();
  }
}

vector<UserId> UserManager::get_user_ids(vector<telegram_api::object_ptr<telegram_api::User>> &&users,
                                         const char *source) {
  vector<UserId> user_ids;
  for (auto &user : users) {
    auto user_id = get_user_id(user);
    if (!user_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << user_id << " from " << source << " in " << to_string(user);
      continue;
    }
    on_get_user(std::move(user), source);
    if (have_user(user_id)) {
      user_ids.push_back(user_id);
    }
  }
  return user_ids;
}

UserId UserManager::load_my_id() {
  auto id_string = G()->td_db()->get_binlog_pmc()->get("my_id");
  if (!id_string.empty()) {
    UserId my_id(to_integer<int64>(id_string));
    if (my_id.is_valid()) {
      return my_id;
    }

    my_id = UserId(to_integer<int64>(Slice(id_string).substr(5)));
    if (my_id.is_valid()) {
      G()->td_db()->get_binlog_pmc()->set("my_id", to_string(my_id.get()));
      return my_id;
    }

    LOG(ERROR) << "Wrong my ID = \"" << id_string << "\" stored in database";
  }
  return UserId();
}

UserId UserManager::get_my_id() const {
  LOG_IF(ERROR, !my_id_.is_valid()) << "Wrong or unknown my ID returned";
  return my_id_;
}

void UserManager::set_my_id(UserId my_id) {
  UserId my_old_id = my_id_;
  if (my_old_id.is_valid() && my_old_id != my_id) {
    LOG(ERROR) << "Already know that me is " << my_old_id << " but received userSelf with " << my_id;
    return;
  }
  if (!my_id.is_valid()) {
    LOG(ERROR) << "Receive invalid my ID " << my_id;
    return;
  }
  if (my_old_id != my_id) {
    my_id_ = my_id;
    G()->td_db()->get_binlog_pmc()->set("my_id", to_string(my_id.get()));
    td_->option_manager_->set_option_integer("my_id", my_id_.get());
    if (!td_->auth_manager_->is_bot()) {
      G()->td_db()->get_binlog_pmc()->force_sync(Promise<Unit>(), "set_my_id");
    }
  }
}

UserId UserManager::get_service_notifications_user_id() {
  return UserId(static_cast<int64>(777000));
}

UserId UserManager::add_service_notifications_user() {
  auto user_id = get_service_notifications_user_id();
  if (!have_user_force(user_id, "add_service_notifications_user")) {
    LOG(FATAL) << "Failed to load service notification user";
  }
  return user_id;
}

UserId UserManager::get_replies_bot_user_id() {
  return UserId(static_cast<int64>(G()->is_test_dc() ? 708513 : 1271266957));
}

UserId UserManager::get_verification_codes_bot_user_id() {
  return UserId(static_cast<int64>(489000));
}

UserId UserManager::get_anonymous_bot_user_id() {
  return UserId(static_cast<int64>(G()->is_test_dc() ? 552888 : 1087968824));
}

UserId UserManager::get_channel_bot_user_id() {
  return UserId(static_cast<int64>(G()->is_test_dc() ? 936174 : 136817688));
}

UserId UserManager::get_anti_spam_bot_user_id() {
  return UserId(static_cast<int64>(G()->is_test_dc() ? 2200583762ll : 5434988373ll));
}

UserId UserManager::add_anonymous_bot_user() {
  auto user_id = get_anonymous_bot_user_id();
  if (!have_user_force(user_id, "add_anonymous_bot_user")) {
    LOG(FATAL) << "Failed to load anonymous bot user";
  }
  return user_id;
}

UserId UserManager::add_channel_bot_user() {
  auto user_id = get_channel_bot_user_id();
  if (!have_user_force(user_id, "add_channel_bot_user")) {
    LOG(FATAL) << "Failed to load channel bot user";
  }
  return user_id;
}

UserManager::MyOnlineStatusInfo UserManager::get_my_online_status() const {
  MyOnlineStatusInfo status_info;
  status_info.is_online_local = td_->online_manager_->is_online();
  status_info.is_online_remote = was_online_remote_ > G()->unix_time();
  status_info.was_online_local = was_online_local_;
  status_info.was_online_remote = was_online_remote_;

  return status_info;
}

void UserManager::set_my_online_status(bool is_online, bool send_update, bool is_local) {
  if (td_->auth_manager_->is_bot()) {
    return;  // just in case
  }

  auto my_id = get_my_id();
  User *u = get_user_force(my_id, "set_my_online_status");
  if (u != nullptr) {
    int32 new_online;
    int32 unix_time = G()->unix_time();
    if (is_online) {
      new_online = unix_time + 300;
    } else {
      new_online = unix_time - 1;
    }

    auto old_was_online = get_user_was_online(u, my_id, unix_time);
    if (is_local) {
      LOG(INFO) << "Update my local online from " << my_was_online_local_ << " to " << new_online;
      if (!is_online) {
        new_online = min(new_online, u->was_online);
      }
      if (new_online != my_was_online_local_) {
        my_was_online_local_ = new_online;
      }
    } else {
      if (my_was_online_local_ != 0 || new_online != u->was_online) {
        LOG(INFO) << "Update my online from " << u->was_online << " to " << new_online;
        my_was_online_local_ = 0;
        u->was_online = new_online;
        u->need_save_to_database = true;
      }
    }
    if (old_was_online != get_user_was_online(u, my_id, unix_time)) {
      u->is_status_changed = true;
      u->is_online_status_changed = true;
    }

    if (was_online_local_ != new_online) {
      was_online_local_ = new_online;
      VLOG(notifications) << "Set was_online_local to " << was_online_local_;
      G()->td_db()->get_binlog_pmc()->set("my_was_online_local", to_string(was_online_local_));
    }

    if (send_update) {
      update_user(u, my_id);
    }
  }
}

void UserManager::on_get_user(telegram_api::object_ptr<telegram_api::User> &&user_ptr, const char *source) {
  LOG(DEBUG) << "Receive from " << source << ' ' << to_string(user_ptr);
  int32 constructor_id = user_ptr->get_id();
  if (constructor_id == telegram_api::userEmpty::ID) {
    auto user = move_tl_object_as<telegram_api::userEmpty>(user_ptr);
    UserId user_id(user->id_);
    if (!user_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << user_id << " from " << source;
      return;
    }
    LOG(INFO) << "Receive empty " << user_id << " from " << source;

    User *u = get_user_force(user_id, source);
    if (u == nullptr && Slice(source) != Slice("GetUsersQuery")) {
      // userEmpty should be received only through getUsers for nonexistent users
      LOG(ERROR) << "Have no information about " << user_id << ", but received userEmpty from " << source;
    }
    return;
  }

  CHECK(constructor_id == telegram_api::user::ID);
  auto user = move_tl_object_as<telegram_api::user>(user_ptr);
  UserId user_id(user->id_);
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  LOG(INFO) << "Receive " << user_id << " from " << source;

  bool is_bot = user->bot_;
  if (user->self_) {
    set_my_id(user_id);
    if (!is_bot) {
      td_->option_manager_->set_option_string("my_phone_number", user->phone_);
    }
  }

  int32 flags = user->flags_;
  bool have_access_hash = (flags & telegram_api::user::ACCESS_HASH_MASK) != 0;
  bool is_received = !user->min_;
  bool is_contact = user->contact_;

  User *u = get_user(user_id);
  if (u == nullptr) {
    if (!is_received) {
      // we must preload received inaccessible users from database in order to not save
      // the min-user to the database and to not override access_hash and other data
      u = get_user_force(user_id, "on_get_user 2");
      if (u == nullptr) {
        LOG(INFO) << "Receive inaccessible " << user_id;
        u = add_user(user_id);
      }
    } else if (is_contact && !are_contacts_loaded_) {
      // preload contact users from database to know that is_contact didn't changed
      // and the list of contacts doesn't need to be saved to the database
      u = get_user_force(user_id, "on_get_user 3");
      if (u == nullptr) {
        LOG(INFO) << "Receive contact " << user_id << " for the first time";
        u = add_user(user_id);
      }
    } else {
      u = add_user(user_id);
    }
    CHECK(u != nullptr);
    if (unknown_users_.erase(user_id) != 0) {
      u->is_photo_inited = true;
    }
  }

  if (have_access_hash) {  // access_hash must be updated before photo
    auto access_hash = user->access_hash_;
    bool is_min_access_hash = !is_received && !((flags & telegram_api::user::PHONE_MASK) != 0 && user->phone_.empty());
    if (u->access_hash != access_hash && (!is_min_access_hash || u->is_min_access_hash || u->access_hash == -1)) {
      LOG(DEBUG) << "Access hash has changed for " << user_id << " from " << u->access_hash << "/"
                 << u->is_min_access_hash << " to " << access_hash << "/" << is_min_access_hash;
      u->access_hash = access_hash;
      u->is_min_access_hash = is_min_access_hash;
      u->need_save_to_database = true;
    }
  }

  bool is_verified = user->verified_;
  bool is_premium = user->premium_;
  bool is_support = user->support_;
  bool is_deleted = user->deleted_;
  bool can_join_groups = !user->bot_nochats_;
  bool can_read_all_group_messages = user->bot_chat_history_;
  bool can_be_added_to_attach_menu = user->bot_attach_menu_;
  bool has_main_app = user->bot_has_main_app_;
  bool attach_menu_enabled = user->attach_menu_enabled_;
  bool is_scam = user->scam_;
  bool can_be_edited_bot = user->bot_can_edit_;
  bool is_inline_bot = (flags & telegram_api::user::BOT_INLINE_PLACEHOLDER_MASK) != 0;
  bool is_business_bot = user->bot_business_;
  string inline_query_placeholder = std::move(user->bot_inline_placeholder_);
  int32 bot_active_users = user->bot_active_users_;
  bool need_location_bot = user->bot_inline_geo_;
  bool need_apply_min_photo = user->apply_min_photo_;
  bool is_fake = user->fake_;
  bool stories_available = user->stories_max_id_ > 0;
  bool stories_unavailable = user->stories_unavailable_;
  bool stories_hidden = user->stories_hidden_;
  bool contact_require_premium = user->contact_require_premium_;
  auto paid_message_star_count = StarManager::get_star_count(user->send_paid_messages_stars_);

  if (!is_bot && (!can_join_groups || can_read_all_group_messages || can_be_added_to_attach_menu || can_be_edited_bot ||
                  has_main_app || is_inline_bot || is_business_bot)) {
    LOG(ERROR) << "Receive not bot " << user_id << " with bot properties from " << source;
    can_join_groups = true;
    can_read_all_group_messages = false;
    can_be_added_to_attach_menu = false;
    can_be_edited_bot = false;
    has_main_app = false;
    is_inline_bot = false;
    is_business_bot = false;
  }
  if (need_location_bot && !is_inline_bot) {
    LOG(ERROR) << "Receive not inline bot " << user_id << " which needs user location from " << source;
    need_location_bot = false;
  }

  if (is_deleted) {
    // just in case
    is_verified = false;
    is_premium = false;
    is_support = false;
    is_bot = false;
    can_join_groups = false;
    can_read_all_group_messages = false;
    can_be_added_to_attach_menu = false;
    can_be_edited_bot = false;
    has_main_app = false;
    is_inline_bot = false;
    is_business_bot = false;
    inline_query_placeholder = string();
    bot_active_users = 0;
    need_location_bot = false;
    need_apply_min_photo = false;
    paid_message_star_count = 0;
  }

  int32 bot_info_version = is_bot ? user->bot_info_version_ : -1;
  if (is_verified != u->is_verified || is_support != u->is_support || is_bot != u->is_bot ||
      can_join_groups != u->can_join_groups || can_read_all_group_messages != u->can_read_all_group_messages ||
      is_scam != u->is_scam || is_fake != u->is_fake || is_inline_bot != u->is_inline_bot ||
      is_business_bot != u->is_business_bot || inline_query_placeholder != u->inline_query_placeholder ||
      need_location_bot != u->need_location_bot || can_be_added_to_attach_menu != u->can_be_added_to_attach_menu ||
      bot_active_users != u->bot_active_users || has_main_app != u->has_main_app) {
    if (is_bot != u->is_bot) {
      LOG_IF(ERROR, !is_deleted && !u->is_deleted && u->is_received)
          << "User.is_bot has changed for " << user_id << "/" << u->usernames << " from " << source << " from "
          << u->is_bot << " to " << is_bot;
      u->is_full_info_changed = true;
    }
    u->is_verified = is_verified;
    u->is_support = is_support;
    u->is_bot = is_bot;
    u->can_join_groups = can_join_groups;
    u->can_read_all_group_messages = can_read_all_group_messages;
    u->is_scam = is_scam;
    u->is_fake = is_fake;
    u->is_inline_bot = is_inline_bot;
    u->is_business_bot = is_business_bot;
    u->inline_query_placeholder = std::move(inline_query_placeholder);
    u->need_location_bot = need_location_bot;
    u->can_be_added_to_attach_menu = can_be_added_to_attach_menu;
    u->bot_active_users = bot_active_users;
    u->has_main_app = has_main_app;

    LOG(DEBUG) << "Info has changed for " << user_id;
    u->is_changed = true;
  }
  if (contact_require_premium != u->contact_require_premium || paid_message_star_count != u->paid_message_star_count) {
    u->contact_require_premium = contact_require_premium;
    u->paid_message_star_count = paid_message_star_count;
    u->is_changed = true;
    user_full_contact_price_.erase(user_id);
  }
  if (is_received && attach_menu_enabled != u->attach_menu_enabled) {
    u->attach_menu_enabled = attach_menu_enabled;
    u->is_changed = true;
  }
  if (is_premium != u->is_premium) {
    u->is_premium = is_premium;
    u->is_is_premium_changed = true;
    u->is_changed = true;
    u->is_full_info_changed = true;
  }
  if (is_received && can_be_edited_bot != u->can_be_edited_bot) {
    u->can_be_edited_bot = can_be_edited_bot;
    u->is_changed = true;
    u->is_full_info_changed = true;
  }

  if (u->bot_info_version != bot_info_version) {
    u->bot_info_version = bot_info_version;
    LOG(DEBUG) << "Bot info version has changed for " << user_id;
    u->need_save_to_database = true;
  }
  if (is_received && u->need_apply_min_photo != need_apply_min_photo) {
    LOG(DEBUG) << "Need apply min photo has changed for " << user_id;
    u->need_apply_min_photo = need_apply_min_photo;
    u->need_save_to_database = true;
  }

  if (is_received && !u->is_received) {
    u->is_received = true;

    LOG(DEBUG) << "Receive " << user_id;
    u->is_changed = true;
  }

  if (is_deleted != u->is_deleted) {
    u->is_deleted = is_deleted;

    LOG(DEBUG) << "User.is_deleted has changed for " << user_id << " to " << u->is_deleted;
    u->is_is_deleted_changed = true;
    u->is_changed = true;
  }

  if (u->language_code != user->lang_code_ && !user->lang_code_.empty()) {
    LOG_IF(ERROR, !td_->auth_manager_->is_bot()) << "Receive language code for " << user_id << " from " << source;

    u->language_code = user->lang_code_;
    u->is_changed = true;
  }

  bool is_me_regular_user = !td_->auth_manager_->is_bot();
  if (is_received || u->need_apply_min_photo || !u->is_received) {
    on_update_user_photo(u, user_id, std::move(user->photo_), source);
  }
  if (is_me_regular_user) {
    if (is_received || !u->is_received) {
      on_update_user_phone_number(u, user_id, std::move(user->phone_));
    }
    if (is_received || !u->is_received || u->was_online == 0) {
      on_update_user_online(u, user_id, std::move(user->status_));
    }
    if (is_received) {
      on_update_user_is_contact(u, user_id, is_contact, user->mutual_contact_, user->close_friend_);
    }
  }

  if (is_received || !u->is_received) {
    on_update_user_name(u, user_id, std::move(user->first_name_), std::move(user->last_name_));
    on_update_user_usernames(u, user_id, Usernames{std::move(user->username_), std::move(user->usernames_)});
  }
  on_update_user_emoji_status(u, user_id, EmojiStatus::get_emoji_status(std::move(user->emoji_status_)));
  PeerColor peer_color(user->color_);
  on_update_user_accent_color_id(u, user_id, peer_color.accent_color_id_);
  on_update_user_background_custom_emoji_id(u, user_id, peer_color.background_custom_emoji_id_);
  PeerColor profile_peer_color(user->profile_color_);
  on_update_user_profile_accent_color_id(u, user_id, profile_peer_color.accent_color_id_);
  on_update_user_profile_background_custom_emoji_id(u, user_id, profile_peer_color.background_custom_emoji_id_);
  if (is_me_regular_user) {
    if (is_received) {
      on_update_user_stories_hidden(u, user_id, stories_hidden);
    }
    if (stories_available || stories_unavailable) {
      // update at the end, because it calls need_poll_user_active_stories
      on_update_user_story_ids_impl(u, user_id, StoryId(user->stories_max_id_), StoryId());
    }
    auto restriction_reasons = get_restriction_reasons(std::move(user->restriction_reason_));
    if (restriction_reasons != u->restriction_reasons) {
      u->restriction_reasons = std::move(restriction_reasons);
      u->is_changed = true;
    }
    on_update_user_bot_verification_icon(u, user_id, CustomEmojiId(user->bot_verification_icon_));
  }

  if (u->cache_version != User::CACHE_VERSION && u->is_received) {
    u->cache_version = User::CACHE_VERSION;
    u->need_save_to_database = true;
  }
  u->is_received_from_server = true;
  update_user(u, user_id);
}

void UserManager::on_get_users(vector<telegram_api::object_ptr<telegram_api::User>> &&users, const char *source) {
  for (auto &user : users) {
    on_get_user(std::move(user), source);
  }
}

void UserManager::on_binlog_user_event(BinlogEvent &&event) {
  if (!G()->use_chat_info_database()) {
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  UserLogEvent log_event;
  if (log_event_parse(log_event, event.get_data()).is_error()) {
    LOG(ERROR) << "Failed to load a user from binlog";
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  auto user_id = log_event.user_id;
  if (have_min_user(user_id) || !user_id.is_valid()) {
    LOG(ERROR) << "Skip adding already added " << user_id;
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  LOG(INFO) << "Add " << user_id << " from binlog";
  users_.set(user_id, std::move(log_event.u_out));

  User *u = get_user(user_id);
  CHECK(u != nullptr);
  u->log_event_id = event.id_;

  update_user(u, user_id, true, false);
}

void UserManager::on_binlog_secret_chat_event(BinlogEvent &&event) {
  if (!G()->use_chat_info_database()) {
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  SecretChatLogEvent log_event;
  if (log_event_parse(log_event, event.get_data()).is_error()) {
    LOG(ERROR) << "Failed to load a secret chat from binlog";
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  auto secret_chat_id = log_event.secret_chat_id;
  if (have_secret_chat(secret_chat_id) || !secret_chat_id.is_valid()) {
    LOG(ERROR) << "Skip adding already added " << secret_chat_id;
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  LOG(INFO) << "Add " << secret_chat_id << " from binlog";
  secret_chats_.set(secret_chat_id, std::move(log_event.c_out));

  SecretChat *c = get_secret_chat(secret_chat_id);
  CHECK(c != nullptr);
  c->log_event_id = event.id_;

  update_secret_chat(c, secret_chat_id, true, false);
}

void UserManager::on_update_user_name(UserId user_id, string &&first_name, string &&last_name, Usernames &&usernames) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_name");
  if (u != nullptr) {
    on_update_user_name(u, user_id, std::move(first_name), std::move(last_name));
    on_update_user_usernames(u, user_id, std::move(usernames));
    update_user(u, user_id);
  } else {
    LOG(INFO) << "Ignore update user name about unknown " << user_id;
  }
}

void UserManager::on_update_user_name(User *u, UserId user_id, string &&first_name, string &&last_name) {
  if (first_name.empty() && last_name.empty()) {
    first_name = u->phone_number;
  }
  if (u->first_name != first_name || u->last_name != last_name) {
    u->first_name = std::move(first_name);
    u->last_name = std::move(last_name);
    u->is_name_changed = true;
    LOG(DEBUG) << "Name has changed for " << user_id;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_usernames(User *u, UserId user_id, Usernames &&usernames) {
  if (u->usernames != usernames) {
    td_->dialog_manager_->on_dialog_usernames_updated(DialogId(user_id), u->usernames, usernames);
    td_->messages_manager_->on_dialog_usernames_updated(DialogId(user_id), u->usernames, usernames);
    if (u->can_be_edited_bot && u->usernames.get_editable_username() != usernames.get_editable_username()) {
      u->is_full_info_changed = true;
    }
    u->usernames = std::move(usernames);
    u->is_username_changed = true;
    LOG(DEBUG) << "Usernames have changed for " << user_id;
    u->is_changed = true;
  } else if (u->is_bot || !td_->auth_manager_->is_bot()) {
    td_->dialog_manager_->on_dialog_usernames_received(DialogId(user_id), usernames, false);
  }
}

void UserManager::on_update_user_phone_number(UserId user_id, string &&phone_number) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_phone_number");
  if (u != nullptr) {
    on_update_user_phone_number(u, user_id, std::move(phone_number));
    update_user(u, user_id);
  } else {
    LOG(INFO) << "Ignore update user phone number about unknown " << user_id;
  }
}

void UserManager::on_update_user_phone_number(User *u, UserId user_id, string &&phone_number) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  clean_phone_number(phone_number);
  if (u->phone_number != phone_number) {
    if (!u->phone_number.empty()) {
      auto it = resolved_phone_numbers_.find(u->phone_number);
      if (it != resolved_phone_numbers_.end() && it->second == user_id) {
        resolved_phone_numbers_.erase(it);
      }
    }

    u->phone_number = std::move(phone_number);
    u->is_phone_number_changed = true;
    LOG(DEBUG) << "Phone number has changed for " << user_id;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_photo(User *u, UserId user_id,
                                       telegram_api::object_ptr<telegram_api::UserProfilePhoto> &&photo,
                                       const char *source) {
  if (td_->auth_manager_->is_bot() && !G()->use_chat_info_database()) {
    if (!u->is_photo_inited) {
      auto new_photo_id = get_profile_photo_id(photo);
      auto &old_photo = pending_user_photos_[user_id];
      if (new_photo_id == get_profile_photo_id(old_photo)) {
        return;
      }
      if (photo != nullptr && photo->get_id() == telegram_api::userProfilePhoto::ID) {
        auto *profile_photo = static_cast<telegram_api::userProfilePhoto *>(photo.get());
        profile_photo->stripped_thumb_.clear();
      }

      old_photo = std::move(photo);

      drop_user_photos(user_id, new_photo_id == 0, "on_update_user_photo");
      auto user_full = get_user_full(user_id);  // must not load UserFull
      if (user_full != nullptr && new_photo_id != get_user_full_profile_photo_id(user_full)) {
        // we didn't sent updateUser yet, so we must not sent updateUserFull with new_photo_id yet
        drop_user_full_photos(user_full, user_id, 0, "on_update_user_photo");
      }
      return;
    }
    if (u->is_received) {
      auto new_photo_id = get_profile_photo_id(photo);
      if (new_photo_id == u->photo.id) {
        return;
      }
    }
  }

  do_update_user_photo(u, user_id, std::move(photo), source);
}

void UserManager::do_update_user_photo(User *u, UserId user_id,
                                       telegram_api::object_ptr<telegram_api::UserProfilePhoto> &&photo,
                                       const char *source) {
  ProfilePhoto new_photo = get_profile_photo(td_->file_manager_.get(), user_id, u->access_hash, std::move(photo));
  if (td_->auth_manager_->is_bot()) {
    new_photo.minithumbnail.clear();
  }
  do_update_user_photo(u, user_id, std::move(new_photo), true, source);
}

void UserManager::do_update_user_photo(User *u, UserId user_id, ProfilePhoto &&new_photo, bool invalidate_photo_cache,
                                       const char *source) {
  u->is_photo_inited = true;
  if (need_update_profile_photo(u->photo, new_photo)) {
    LOG_IF(ERROR, u->access_hash == -1 && new_photo.small_file_id.is_valid())
        << "Update profile photo of " << user_id << " without access hash from " << source;
    LOG(DEBUG) << "Update photo of " << user_id << " from " << u->photo << " to " << new_photo
               << ", invalidate_photo_cache = " << invalidate_photo_cache << " from " << source;
    u->photo = std::move(new_photo);
    u->is_photo_changed = true;
    u->is_changed = true;

    if (invalidate_photo_cache) {
      drop_user_photos(user_id, u->photo.id == 0, source);
    }
    auto user_full = get_user_full(user_id);  // must not load UserFull
    if (user_full != nullptr && u->photo.id != get_user_full_profile_photo_id(user_full)) {
      // we didn't sent updateUser yet, so we must not sent updateUserFull with u->photo.id yet
      drop_user_full_photos(user_full, user_id, 0, "do_update_user_photo");
    }
  } else if (need_update_dialog_photo_minithumbnail(u->photo.minithumbnail, new_photo.minithumbnail)) {
    LOG(DEBUG) << "Photo minithumbnail has changed for " << user_id << " from " << source;
    u->photo.minithumbnail = std::move(new_photo.minithumbnail);
    u->is_photo_changed = true;
    u->is_changed = true;
  }
}

void UserManager::register_suggested_profile_photo(const Photo &photo) {
  auto photo_file_ids = photo_get_file_ids(photo);
  if (photo.is_empty() || photo_file_ids.empty()) {
    return;
  }
  auto first_file_id = photo_file_ids[0];
  auto file_type = td_->file_manager_->get_file_view(first_file_id).get_type();
  if (file_type == FileType::ProfilePhoto) {
    return;
  }
  CHECK(file_type == FileType::Photo);
  auto photo_id = photo.id.get();
  if (photo_id != 0) {
    my_photo_file_id_[photo_id] = first_file_id;
  }
}

void UserManager::register_user_photo(User *u, UserId user_id, const Photo &photo) {
  auto photo_file_ids = photo_get_file_ids(photo);
  if (photo.is_empty() || photo_file_ids.empty()) {
    return;
  }
  auto first_file_id = photo_file_ids[0];
  auto file_type = td_->file_manager_->get_file_view(first_file_id).get_type();
  if (file_type == FileType::ProfilePhoto) {
    return;
  }
  CHECK(file_type == FileType::Photo);
  CHECK(u != nullptr);
  auto photo_id = photo.id.get();
  if (photo_id != 0 && u->photo_ids.emplace(photo_id).second) {
    VLOG(file_references) << "Register photo " << photo_id << " of " << user_id;
    if (user_id == get_my_id()) {
      my_photo_file_id_[photo_id] = first_file_id;
    }
    auto file_source_id = user_profile_photo_file_source_ids_.get(std::make_pair(user_id, photo_id));
    if (file_source_id.is_valid()) {
      VLOG(file_references) << "Move " << file_source_id << " inside of " << user_id;
      user_profile_photo_file_source_ids_.erase(std::make_pair(user_id, photo_id));
    } else {
      VLOG(file_references) << "Need to create new file source for photo " << photo_id << " of " << user_id;
      file_source_id = td_->file_reference_manager_->create_user_photo_file_source(user_id, photo_id);
    }
    for (auto &file_id : photo_file_ids) {
      td_->file_manager_->add_file_source(file_id, file_source_id, "register_user_photo");
    }
  }
}

void UserManager::on_update_user_accent_color_id(User *u, UserId user_id, AccentColorId accent_color_id) {
  if (accent_color_id == AccentColorId(user_id) || !accent_color_id.is_valid()) {
    accent_color_id = AccentColorId();
  }
  if (u->accent_color_id != accent_color_id) {
    u->accent_color_id = accent_color_id;
    u->is_accent_color_changed = true;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_background_custom_emoji_id(User *u, UserId user_id,
                                                            CustomEmojiId background_custom_emoji_id) {
  if (u->background_custom_emoji_id != background_custom_emoji_id) {
    u->background_custom_emoji_id = background_custom_emoji_id;
    u->is_accent_color_changed = true;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_profile_accent_color_id(User *u, UserId user_id, AccentColorId accent_color_id) {
  if (!accent_color_id.is_valid()) {
    accent_color_id = AccentColorId();
  }
  if (u->profile_accent_color_id != accent_color_id) {
    u->profile_accent_color_id = accent_color_id;
    u->is_accent_color_changed = true;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_profile_background_custom_emoji_id(User *u, UserId user_id,
                                                                    CustomEmojiId background_custom_emoji_id) {
  if (u->profile_background_custom_emoji_id != background_custom_emoji_id) {
    u->profile_background_custom_emoji_id = background_custom_emoji_id;
    u->is_accent_color_changed = true;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_emoji_status(UserId user_id,
                                              telegram_api::object_ptr<telegram_api::EmojiStatus> &&emoji_status) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_emoji_status");
  if (u != nullptr) {
    on_update_user_emoji_status(u, user_id, EmojiStatus::get_emoji_status(std::move(emoji_status)));
    update_user(u, user_id);
  } else {
    LOG(INFO) << "Ignore update user emoji status about unknown " << user_id;
  }
}

void UserManager::on_update_user_emoji_status(User *u, UserId user_id, unique_ptr<EmojiStatus> emoji_status) {
  if (u->emoji_status != emoji_status) {
    LOG(DEBUG) << "Change emoji status of " << user_id << " from " << u->emoji_status << " to " << emoji_status;
    u->emoji_status = std::move(emoji_status);
    u->is_emoji_status_changed = true;
    // effective emoji status might not be changed; checked in update_user
    // u->is_changed = true;
  }
}

void UserManager::on_update_user_story_ids(UserId user_id, StoryId max_active_story_id, StoryId max_read_story_id) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_story_ids");
  if (u != nullptr) {
    on_update_user_story_ids_impl(u, user_id, max_active_story_id, max_read_story_id);
    update_user(u, user_id);
  } else {
    LOG(INFO) << "Ignore update user story identifiers about unknown " << user_id;
  }
}

void UserManager::on_update_user_story_ids_impl(User *u, UserId user_id, StoryId max_active_story_id,
                                                StoryId max_read_story_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  if (max_active_story_id != StoryId() && !max_active_story_id.is_server()) {
    LOG(ERROR) << "Receive max active " << max_active_story_id << " for " << user_id;
    return;
  }
  if (max_read_story_id != StoryId() && !max_read_story_id.is_server()) {
    LOG(ERROR) << "Receive max read " << max_read_story_id << " for " << user_id;
    return;
  }

  auto has_unread_stories = get_user_has_unread_stories(u);
  if (u->max_active_story_id != max_active_story_id) {
    LOG(DEBUG) << "Change last active story of " << user_id << " from " << u->max_active_story_id << " to "
               << max_active_story_id;
    u->max_active_story_id = max_active_story_id;
    u->need_save_to_database = true;
  }
  if (need_poll_user_active_stories(u, user_id)) {
    auto max_active_story_id_next_reload_time = Time::now() + MAX_ACTIVE_STORY_ID_RELOAD_TIME;
    if (max_active_story_id_next_reload_time >
        u->max_active_story_id_next_reload_time + MAX_ACTIVE_STORY_ID_RELOAD_TIME / 5) {
      LOG(DEBUG) << "Change max_active_story_id_next_reload_time of " << user_id;
      u->max_active_story_id_next_reload_time = max_active_story_id_next_reload_time;
      u->need_save_to_database = true;
    }
  }
  if (!max_active_story_id.is_valid()) {
    CHECK(max_read_story_id == StoryId());
    if (u->max_read_story_id != StoryId()) {
      LOG(DEBUG) << "Drop last read " << u->max_read_story_id << " of " << user_id;
      u->max_read_story_id = StoryId();
      u->need_save_to_database = true;
    }
  } else if (max_read_story_id.get() > u->max_read_story_id.get()) {
    LOG(DEBUG) << "Change last read story of " << user_id << " from " << u->max_read_story_id << " to "
               << max_read_story_id;
    u->max_read_story_id = max_read_story_id;
    u->need_save_to_database = true;
  }
  if (has_unread_stories != get_user_has_unread_stories(u)) {
    LOG(DEBUG) << "Change has_unread_stories of " << user_id << " to " << !has_unread_stories;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_max_read_story_id(UserId user_id, StoryId max_read_story_id) {
  CHECK(user_id.is_valid());

  User *u = get_user(user_id);
  if (u != nullptr) {
    on_update_user_max_read_story_id(u, user_id, max_read_story_id);
    update_user(u, user_id);
  }
}

void UserManager::on_update_user_max_read_story_id(User *u, UserId user_id, StoryId max_read_story_id) {
  if (td_->auth_manager_->is_bot() || !u->is_received) {
    return;
  }

  auto has_unread_stories = get_user_has_unread_stories(u);
  if (max_read_story_id.get() > u->max_read_story_id.get()) {
    LOG(DEBUG) << "Change last read story of " << user_id << " from " << u->max_read_story_id << " to "
               << max_read_story_id;
    u->max_read_story_id = max_read_story_id;
    u->need_save_to_database = true;
  }
  if (has_unread_stories != get_user_has_unread_stories(u)) {
    LOG(DEBUG) << "Change has_unread_stories of " << user_id << " to " << !has_unread_stories;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_stories_hidden(UserId user_id, bool stories_hidden) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_stories_hidden");
  if (u != nullptr) {
    on_update_user_stories_hidden(u, user_id, stories_hidden);
    update_user(u, user_id);
  } else {
    LOG(INFO) << "Ignore update user stories are archived about unknown " << user_id;
  }
}

void UserManager::on_update_user_stories_hidden(User *u, UserId user_id, bool stories_hidden) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (u->stories_hidden != stories_hidden) {
    LOG(DEBUG) << "Change stories are archived of " << user_id << " to " << stories_hidden;
    u->stories_hidden = stories_hidden;
    u->is_stories_hidden_changed = true;
    u->need_save_to_database = true;
  }
}

void UserManager::on_update_user_bot_verification_icon(User *u, UserId user_id, CustomEmojiId bot_verification_icon) {
  if (u->bot_verification_icon != bot_verification_icon) {
    u->bot_verification_icon = bot_verification_icon;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_is_contact(User *u, UserId user_id, bool is_contact, bool is_mutual_contact,
                                            bool is_close_friend) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  UserId my_id = get_my_id();
  if (user_id == my_id) {
    is_mutual_contact = is_contact;
    is_close_friend = false;
  }
  if (!is_contact && (is_mutual_contact || is_close_friend)) {
    LOG(ERROR) << "Receive is_mutual_contact = " << is_mutual_contact << ", and is_close_friend = " << is_close_friend
               << " for non-contact " << user_id;
    is_mutual_contact = false;
    is_close_friend = false;
  }

  if (u->is_contact != is_contact || u->is_mutual_contact != is_mutual_contact ||
      u->is_close_friend != is_close_friend) {
    LOG(DEBUG) << "Update " << user_id << " is_contact from (" << u->is_contact << ", " << u->is_mutual_contact << ", "
               << u->is_close_friend << ") to (" << is_contact << ", " << is_mutual_contact << ", " << is_close_friend
               << ")";
    if (u->is_contact != is_contact) {
      u->is_contact = is_contact;
      u->is_is_contact_changed = true;
    }
    if (u->is_mutual_contact != is_mutual_contact) {
      u->is_mutual_contact = is_mutual_contact;
      u->is_is_mutual_contact_changed = true;

      reload_contact_birthdates(true);
    }
    u->is_close_friend = is_close_friend;
    u->is_changed = true;
  }
}

void UserManager::on_update_user_online(UserId user_id, telegram_api::object_ptr<telegram_api::UserStatus> &&status) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_online");
  if (u != nullptr) {
    if (u->is_bot) {
      LOG(ERROR) << "Receive updateUserStatus about bot " << user_id;
      return;
    }
    on_update_user_online(u, user_id, std::move(status));
    update_user(u, user_id);

    if (user_id == get_my_id() &&
        was_online_remote_ != u->was_online) {  // only update was_online_remote_ from updateUserStatus
      was_online_remote_ = u->was_online;
      VLOG(notifications) << "Set was_online_remote to " << was_online_remote_;
      G()->td_db()->get_binlog_pmc()->set("my_was_online_remote", to_string(was_online_remote_));
    }
  } else {
    LOG(INFO) << "Ignore update user online about unknown " << user_id;
  }
}

void UserManager::on_update_user_online(User *u, UserId user_id,
                                        telegram_api::object_ptr<telegram_api::UserStatus> &&status) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  int32 id = status == nullptr ? telegram_api::userStatusEmpty::ID : status->get_id();
  int32 new_online;
  bool is_offline = false;
  if (id == telegram_api::userStatusOnline::ID) {
    int32 now = G()->unix_time();

    auto st = move_tl_object_as<telegram_api::userStatusOnline>(status);
    new_online = st->expires_;
    LOG_IF(ERROR, new_online < now - 86400)
        << "Receive userStatusOnline expired more than one day in past " << new_online;
  } else if (id == telegram_api::userStatusOffline::ID) {
    int32 now = G()->unix_time();

    auto st = move_tl_object_as<telegram_api::userStatusOffline>(status);
    new_online = st->was_online_;
    if (new_online >= now) {
      if (new_online > now + 10) {
        // this is possible when local time isn't adjusted yet after hibernation, but updates were received
        LOG(INFO) << "Receive userStatusOffline from the future time " << new_online << ", now is " << now;
      }
      new_online = now - 1;
    }
    is_offline = true;
  } else if (id == telegram_api::userStatusRecently::ID) {
    auto st = telegram_api::move_object_as<telegram_api::userStatusRecently>(status);
    new_online = st->by_me_ ? -4 : -1;
  } else if (id == telegram_api::userStatusLastWeek::ID) {
    auto st = telegram_api::move_object_as<telegram_api::userStatusLastWeek>(status);
    new_online = st->by_me_ ? -5 : -2;
  } else if (id == telegram_api::userStatusLastMonth::ID) {
    auto st = telegram_api::move_object_as<telegram_api::userStatusLastMonth>(status);
    new_online = st->by_me_ ? -6 : -3;
  } else {
    CHECK(id == telegram_api::userStatusEmpty::ID);
    new_online = 0;
  }

  if (new_online != u->was_online && !(new_online < 0 && user_id == get_my_id())) {
    LOG(DEBUG) << "Update " << user_id << " online from " << u->was_online << " to " << new_online;
    auto unix_time = G()->unix_time();
    bool old_is_online = u->was_online > unix_time;
    bool new_is_online = new_online > unix_time;
    u->was_online = new_online;
    u->is_status_changed = true;
    if (u->was_online > 0) {
      u->local_was_online = 0;
    }

    if (user_id == get_my_id()) {
      if (my_was_online_local_ != 0 || old_is_online != new_is_online) {
        my_was_online_local_ = 0;
        u->is_online_status_changed = true;
      }
      if (is_offline) {
        td_->online_manager_->on_online_updated(false, false);
      }
    } else if (old_is_online != new_is_online) {
      u->is_online_status_changed = true;
    }
  }
}

void UserManager::on_update_user_local_was_online(UserId user_id, int32 local_was_online) {
  CHECK(user_id.is_valid());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  User *u = get_user_force(user_id, "on_update_user_local_was_online");
  if (u == nullptr) {
    return;
  }

  on_update_user_local_was_online(u, user_id, local_was_online);
  update_user(u, user_id);
}

void UserManager::on_update_user_local_was_online(User *u, UserId user_id, int32 local_was_online) {
  CHECK(u != nullptr);
  if (u->is_deleted || u->is_bot || u->is_support || user_id == get_my_id()) {
    return;
  }
  int32 unix_time = G()->unix_time();
  if (u->was_online > unix_time) {
    // if user is currently online, ignore local online
    return;
  }

  // bring users online for 30 seconds
  local_was_online += 30;
  if (local_was_online < unix_time + 2 || local_was_online <= u->local_was_online ||
      local_was_online <= u->was_online) {
    return;
  }

  LOG(DEBUG) << "Update " << user_id << " local online from " << u->local_was_online << " to " << local_was_online;
  bool old_is_online = u->local_was_online > unix_time;
  u->local_was_online = local_was_online;
  u->is_status_changed = true;

  if (!old_is_online) {
    u->is_online_status_changed = true;
  }
}

void UserManager::on_update_user_is_blocked(UserId user_id, bool is_blocked, bool is_blocked_for_stories) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_is_blocked");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_is_blocked(user_full, user_id, is_blocked, is_blocked_for_stories);
  update_user_full(user_full, user_id, "on_update_user_is_blocked");
}

void UserManager::on_update_user_full_is_blocked(UserFull *user_full, UserId user_id, bool is_blocked,
                                                 bool is_blocked_for_stories) {
  CHECK(user_full != nullptr);
  if (user_full->is_blocked != is_blocked || user_full->is_blocked_for_stories != is_blocked_for_stories) {
    LOG(INFO) << "Receive update user full is blocked with " << user_id << " and is_blocked = " << is_blocked << '/'
              << is_blocked_for_stories;
    user_full->is_blocked = is_blocked;
    user_full->is_blocked_for_stories = is_blocked_for_stories;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_has_pinned_stories(UserId user_id, bool has_pinned_stories) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_has_pinned_stories");
  if (user_full == nullptr || user_full->has_pinned_stories == has_pinned_stories) {
    return;
  }
  user_full->has_pinned_stories = has_pinned_stories;
  user_full->is_changed = true;
  update_user_full(user_full, user_id, "on_update_user_has_pinned_stories");
}

void UserManager::on_update_user_common_chat_count(UserId user_id, int32 common_chat_count) {
  LOG(INFO) << "Receive " << common_chat_count << " common chat count with " << user_id;
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_common_chat_count");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_common_chat_count(user_full, user_id, common_chat_count);
  update_user_full(user_full, user_id, "on_update_user_common_chat_count");
}

void UserManager::on_update_user_full_common_chat_count(UserFull *user_full, UserId user_id, int32 common_chat_count) {
  CHECK(user_full != nullptr);
  if (common_chat_count < 0) {
    LOG(ERROR) << "Receive " << common_chat_count << " as common group count with " << user_id;
    common_chat_count = 0;
  }
  if (user_full->common_chat_count != common_chat_count) {
    user_full->common_chat_count = common_chat_count;
    user_full->is_common_chat_count_changed = true;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_gift_count(UserId user_id, int32 gift_count) {
  LOG(INFO) << "Receive " << gift_count << " gifts for " << user_id;
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_gift_count");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_gift_count(user_full, user_id, gift_count);
  update_user_full(user_full, user_id, "on_update_user_gift_count");
}

void UserManager::on_update_my_gift_count(int32 added_gift_count) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_my_gift_count");
  if (user_full == nullptr || user_full->gift_count + added_gift_count < 0) {
    return;
  }
  on_update_user_full_gift_count(user_full, user_id, user_full->gift_count + added_gift_count);
  update_user_full(user_full, user_id, "on_update_my_gift_count");
}

void UserManager::on_update_user_full_gift_count(UserFull *user_full, UserId user_id, int32 gift_count) {
  CHECK(user_full != nullptr);
  if (gift_count < 0) {
    LOG(ERROR) << "Receive " << gift_count << " as gift count with " << user_id;
    gift_count = 0;
  }
  if (user_full->gift_count != gift_count) {
    user_full->gift_count = gift_count;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_my_user_location(DialogLocation &&location) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_location");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_location(user_full, user_id, std::move(location));
  update_user_full(user_full, user_id, "on_update_user_location");
}

void UserManager::on_update_user_full_location(UserFull *user_full, UserId user_id, DialogLocation &&location) {
  CHECK(user_full != nullptr);
  if (BusinessInfo::set_location(user_full->business_info, std::move(location))) {
    user_full->is_changed = true;
  }
}

void UserManager::on_update_my_user_work_hours(BusinessWorkHours &&work_hours) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_work_hours");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_work_hours(user_full, user_id, std::move(work_hours));
  update_user_full(user_full, user_id, "on_update_user_work_hours");
}

void UserManager::on_update_user_full_work_hours(UserFull *user_full, UserId user_id, BusinessWorkHours &&work_hours) {
  CHECK(user_full != nullptr);
  if (BusinessInfo::set_work_hours(user_full->business_info, std::move(work_hours))) {
    user_full->is_changed = true;
  }
}

void UserManager::on_update_my_user_away_message(BusinessAwayMessage &&away_message) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_away_message");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_away_message(user_full, user_id, std::move(away_message));
  update_user_full(user_full, user_id, "on_update_user_away_message");
}

void UserManager::on_update_user_full_away_message(UserFull *user_full, UserId user_id,
                                                   BusinessAwayMessage &&away_message) const {
  CHECK(user_full != nullptr);
  if (away_message.is_valid() && user_id != get_my_id()) {
    LOG(ERROR) << "Receive " << away_message << " for " << user_id;
    return;
  }
  if (BusinessInfo::set_away_message(user_full->business_info, std::move(away_message))) {
    user_full->is_changed = true;
  }
}

void UserManager::on_update_my_user_greeting_message(BusinessGreetingMessage &&greeting_message) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_greeting_message");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_greeting_message(user_full, user_id, std::move(greeting_message));
  update_user_full(user_full, user_id, "on_update_user_greeting_message");
}

void UserManager::on_update_user_full_greeting_message(UserFull *user_full, UserId user_id,
                                                       BusinessGreetingMessage &&greeting_message) const {
  CHECK(user_full != nullptr);
  if (greeting_message.is_valid() && user_id != get_my_id()) {
    LOG(ERROR) << "Receive " << greeting_message << " for " << user_id;
    return;
  }
  if (BusinessInfo::set_greeting_message(user_full->business_info, std::move(greeting_message))) {
    user_full->is_changed = true;
  }
}

void UserManager::on_update_my_user_intro(BusinessIntro &&intro) {
  auto user_id = get_my_id();
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_intro");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_intro(user_full, user_id, std::move(intro));
  update_user_full(user_full, user_id, "on_update_user_intro");
}

void UserManager::on_update_user_full_intro(UserFull *user_full, UserId user_id, BusinessIntro &&intro) {
  CHECK(user_full != nullptr);
  if (BusinessInfo::set_intro(user_full->business_info, std::move(intro))) {
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_commands(UserId user_id,
                                          vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands) {
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_commands");
  if (user_full != nullptr) {
    on_update_user_full_commands(user_full, user_id, std::move(bot_commands));
    update_user_full(user_full, user_id, "on_update_user_commands");
  }
}

void UserManager::on_update_user_full_commands(
    UserFull *user_full, UserId user_id, vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands) {
  CHECK(user_full != nullptr);
  auto commands =
      transform(std::move(bot_commands), [](telegram_api::object_ptr<telegram_api::botCommand> &&bot_command) {
        return BotCommand(std::move(bot_command));
      });
  if (user_full->bot_info == nullptr && commands.empty()) {
    return;
  }
  auto bot_info = user_full->add_bot_info();
  if (bot_info->commands != commands) {
    bot_info->commands = std::move(commands);
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_referral_program_info(UserId user_id, ReferralProgramInfo &&referral_program_info) {
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_referral_program_info");
  if (user_full != nullptr) {
    on_update_user_full_referral_program_info(user_full, user_id, std::move(referral_program_info));
    update_user_full(user_full, user_id, "on_update_user_referral_program_info");
  }
}

void UserManager::on_update_user_full_referral_program_info(UserFull *user_full, UserId user_id,
                                                            ReferralProgramInfo &&referral_program_info) {
  CHECK(user_full != nullptr);
  if (user_full->bot_info == nullptr && !referral_program_info.is_valid()) {
    return;
  }
  auto bot_info = user_full->add_bot_info();
  if (bot_info->referral_program_info != referral_program_info) {
    bot_info->referral_program_info = std::move(referral_program_info);
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_verifier_settings(UserId user_id,
                                                   unique_ptr<BotVerifierSettings> &&verifier_settings) {
  UserFull *user_full = get_user_full_force(user_id, "on_update_user_verifier_settings");
  if (user_full != nullptr) {
    on_update_user_full_verifier_settings(user_full, user_id, std::move(verifier_settings));
    update_user_full(user_full, user_id, "on_update_user_verifier_settings");
  }
}

void UserManager::on_update_user_full_verifier_settings(UserFull *user_full, UserId user_id,
                                                        unique_ptr<BotVerifierSettings> &&verifier_settings) {
  CHECK(user_full != nullptr);
  if (user_full->bot_info == nullptr && verifier_settings == nullptr) {
    return;
  }
  auto bot_info = user_full->add_bot_info();
  if (bot_info->verifier_settings != verifier_settings) {
    bot_info->verifier_settings = std::move(verifier_settings);
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_need_phone_number_privacy_exception(UserId user_id,
                                                                     bool need_phone_number_privacy_exception) {
  LOG(INFO) << "Receive " << need_phone_number_privacy_exception << " need phone number privacy exception with "
            << user_id;
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_need_phone_number_privacy_exception");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_need_phone_number_privacy_exception(user_full, user_id, need_phone_number_privacy_exception);
  update_user_full(user_full, user_id, "on_update_user_need_phone_number_privacy_exception");
}

void UserManager::on_update_user_full_need_phone_number_privacy_exception(
    UserFull *user_full, UserId user_id, bool need_phone_number_privacy_exception) const {
  CHECK(user_full != nullptr);
  if (need_phone_number_privacy_exception) {
    const User *u = get_user(user_id);
    if (u == nullptr || u->is_contact || user_id == get_my_id()) {
      need_phone_number_privacy_exception = false;
    }
  }
  if (user_full->need_phone_number_privacy_exception != need_phone_number_privacy_exception) {
    user_full->need_phone_number_privacy_exception = need_phone_number_privacy_exception;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_charge_paid_message_stars(UserId user_id, int64 charge_paid_message_stars) {
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_charge_paid_message_stars");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_charge_paid_message_stars(user_full, user_id, charge_paid_message_stars);
  update_user_full(user_full, user_id, "on_update_user_charge_paid_message_stars");
}

void UserManager::on_update_user_full_charge_paid_message_stars(UserFull *user_full, UserId user_id,
                                                                int64 charge_paid_message_stars) const {
  CHECK(user_full != nullptr);
  if (user_full->charge_paid_message_stars != charge_paid_message_stars) {
    user_full->charge_paid_message_stars = charge_paid_message_stars;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_full_send_paid_message_stars(UserFull *user_full, UserId user_id,
                                                              int64 send_paid_message_stars) const {
  CHECK(user_full != nullptr);
  if (user_full->send_paid_message_stars != send_paid_message_stars) {
    user_full->send_paid_message_stars = send_paid_message_stars;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_user_wallpaper_overridden(UserId user_id, bool wallpaper_overridden) {
  LOG(INFO) << "Receive " << wallpaper_overridden << " set chat background for " << user_id;
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << user_id;
    return;
  }

  UserFull *user_full = get_user_full_force(user_id, "on_update_user_wallpaper_overridden");
  if (user_full == nullptr) {
    return;
  }
  on_update_user_full_wallpaper_overridden(user_full, user_id, wallpaper_overridden);
  update_user_full(user_full, user_id, "on_update_user_wallpaper_overridden");
}

void UserManager::on_update_user_full_wallpaper_overridden(UserFull *user_full, UserId user_id,
                                                           bool wallpaper_overridden) const {
  CHECK(user_full != nullptr);
  if (user_full->wallpaper_overridden != wallpaper_overridden) {
    user_full->wallpaper_overridden = wallpaper_overridden;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_bot_menu_button(UserId bot_user_id,
                                            telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button) {
  if (!bot_user_id.is_valid()) {
    LOG(ERROR) << "Receive updateBotMenuButton about invalid " << bot_user_id;
    return;
  }
  if (!have_user_force(bot_user_id, "on_update_bot_menu_button") || !is_user_bot(bot_user_id)) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto user_full = get_user_full_force(bot_user_id, "on_update_bot_menu_button");
  if (user_full != nullptr) {
    on_update_user_full_menu_button(user_full, bot_user_id, std::move(bot_menu_button));
    update_user_full(user_full, bot_user_id, "on_update_bot_menu_button");
  }
}

void UserManager::on_update_user_full_menu_button(
    UserFull *user_full, UserId user_id, telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button) {
  CHECK(user_full != nullptr);
  auto new_button = get_bot_menu_button(std::move(bot_menu_button));
  if (user_full->bot_info == nullptr && new_button == nullptr) {
    return;
  }
  auto bot_info = user_full->add_bot_info();
  bool is_changed;
  if (bot_info->menu_button == nullptr) {
    is_changed = (new_button != nullptr);
  } else {
    is_changed = (new_button == nullptr || *bot_info->menu_button != *new_button);
  }
  if (is_changed) {
    bot_info->menu_button = std::move(new_button);
    user_full->is_changed = true;
  }
}

void UserManager::on_update_bot_has_preview_medias(UserId bot_user_id, bool has_preview_medias) {
  if (!bot_user_id.is_valid()) {
    LOG(ERROR) << "Receive updateBotHasPreviewMedias about invalid " << bot_user_id;
    return;
  }
  if (!have_user_force(bot_user_id, "on_update_bot_has_preview_medias") || !is_user_bot(bot_user_id)) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto user_full = get_user_full_force(bot_user_id, "on_update_bot_has_preview_medias");
  if (user_full != nullptr) {
    on_update_user_full_has_preview_medias(user_full, bot_user_id, has_preview_medias);
    update_user_full(user_full, bot_user_id, "on_update_bot_has_preview_medias");
  }
}

void UserManager::on_update_user_full_has_preview_medias(UserFull *user_full, UserId user_id, bool has_preview_medias) {
  CHECK(user_full != nullptr);
  if (user_full->has_preview_medias != has_preview_medias) {
    user_full->has_preview_medias = has_preview_medias;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_bot_can_manage_emoji_status(UserId bot_user_id, bool can_manage_emoji_status) {
  CHECK(bot_user_id.is_valid());
  if (!have_user_force(bot_user_id, "on_update_bot_can_manage_emoji_status") || !is_user_bot(bot_user_id)) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto user_full = get_user_full_force(bot_user_id, "on_update_bot_can_manage_emoji_status");
  if (user_full != nullptr) {
    on_update_user_full_can_manage_emoji_status(user_full, bot_user_id, can_manage_emoji_status);
    update_user_full(user_full, bot_user_id, "on_update_bot_can_manage_emoji_status");
  }
}

void UserManager::on_update_user_full_can_manage_emoji_status(UserFull *user_full, UserId user_id,
                                                              bool can_manage_emoji_status) {
  CHECK(user_full != nullptr);
  if (user_full->can_manage_emoji_status != can_manage_emoji_status) {
    user_full->can_manage_emoji_status = can_manage_emoji_status;
    user_full->is_changed = true;
  }
}

void UserManager::on_update_secret_chat(SecretChatId secret_chat_id, int64 access_hash, UserId user_id,
                                        SecretChatState state, bool is_outbound, int32 ttl, int32 date, string key_hash,
                                        int32 layer, FolderId initial_folder_id) {
  LOG(INFO) << "Update " << secret_chat_id << " with " << user_id << " and access_hash " << access_hash;
  auto *secret_chat = add_secret_chat(secret_chat_id);
  if (access_hash != secret_chat->access_hash) {
    secret_chat->access_hash = access_hash;
    secret_chat->need_save_to_database = true;
  }
  if (user_id.is_valid() && user_id != secret_chat->user_id) {
    if (secret_chat->user_id.is_valid()) {
      LOG(ERROR) << "Secret chat user has changed from " << secret_chat->user_id << " to " << user_id;
      auto &old_secret_chat_ids = secret_chats_with_user_[secret_chat->user_id];
      td::remove(old_secret_chat_ids, secret_chat_id);
    }
    secret_chat->user_id = user_id;
    secret_chats_with_user_[secret_chat->user_id].push_back(secret_chat_id);
    secret_chat->is_changed = true;
  }
  if (state != SecretChatState::Unknown && state != secret_chat->state) {
    secret_chat->state = state;
    secret_chat->is_changed = true;
    secret_chat->is_state_changed = true;
  }
  if (is_outbound != secret_chat->is_outbound) {
    secret_chat->is_outbound = is_outbound;
    secret_chat->is_changed = true;
  }

  if (ttl != -1 && ttl != secret_chat->ttl) {
    secret_chat->ttl = ttl;
    secret_chat->need_save_to_database = true;
    secret_chat->is_ttl_changed = true;
  }
  if (date != 0 && date != secret_chat->date) {
    secret_chat->date = date;
    secret_chat->need_save_to_database = true;
  }
  if (!key_hash.empty() && key_hash != secret_chat->key_hash) {
    secret_chat->key_hash = std::move(key_hash);
    secret_chat->is_changed = true;
  }
  if (layer != 0 && layer != secret_chat->layer) {
    secret_chat->layer = layer;
    secret_chat->is_changed = true;
  }
  if (initial_folder_id != FolderId() && initial_folder_id != secret_chat->initial_folder_id) {
    secret_chat->initial_folder_id = initial_folder_id;
    secret_chat->is_changed = true;
  }

  update_secret_chat(secret_chat, secret_chat_id);
}

void UserManager::on_update_online_status_privacy() {
  td_->create_handler<GetContactsStatusesQuery>()->send();
}

void UserManager::on_update_phone_number_privacy() {
  CHECK(!td_->auth_manager_->is_bot());
  // all UserFull.need_phone_number_privacy_exception can be outdated now,
  // so mark all of them as expired
  users_full_.foreach([&](const UserId &user_id, unique_ptr<UserFull> &user_full) { user_full->expires_at = 0.0; });
}

void UserManager::on_ignored_restriction_reasons_changed() {
  restricted_user_ids_.foreach([&](const UserId &user_id) {
    send_closure(G()->td(), &Td::send_update, get_update_user_object(user_id, get_user(user_id)));
  });
}

void UserManager::invalidate_user_full(UserId user_id) {
  auto user_full = get_user_full_force(user_id, "invalidate_user_full");
  if (user_full != nullptr) {
    td_->dialog_manager_->on_dialog_info_full_invalidated(DialogId(user_id));

    if (!user_full->is_expired()) {
      user_full->expires_at = 0.0;
      user_full->need_save_to_database = true;

      update_user_full(user_full, user_id, "invalidate_user_full");
    }
  }
}

bool UserManager::have_user(UserId user_id) const {
  auto u = get_user(user_id);
  return u != nullptr && u->is_received;
}

bool UserManager::have_min_user(UserId user_id) const {
  return users_.count(user_id) > 0;
}

const UserManager::User *UserManager::get_user(UserId user_id) const {
  return users_.get_pointer(user_id);
}

UserManager::User *UserManager::get_user(UserId user_id) {
  return users_.get_pointer(user_id);
}

UserManager::User *UserManager::add_user(UserId user_id) {
  CHECK(user_id.is_valid());
  auto &user_ptr = users_[user_id];
  if (user_ptr == nullptr) {
    user_ptr = make_unique<User>();
  }
  return user_ptr.get();
}

void UserManager::save_user(User *u, UserId user_id, bool from_binlog) {
  if (!G()->use_chat_info_database()) {
    return;
  }
  CHECK(u != nullptr);
  if (!u->is_saved || !u->is_status_saved) {  // TODO more effective handling of !u->is_status_saved
    if (!from_binlog) {
      auto log_event = UserLogEvent(user_id, u);
      auto storer = get_log_event_storer(log_event);
      if (u->log_event_id == 0) {
        u->log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::Users, storer);
      } else {
        binlog_rewrite(G()->td_db()->get_binlog(), u->log_event_id, LogEvent::HandlerType::Users, storer);
      }
    }

    save_user_to_database(u, user_id);
  }
}

string UserManager::get_user_database_key(UserId user_id) {
  return PSTRING() << "us" << user_id.get();
}

string UserManager::get_user_database_value(const User *u) {
  return log_event_store(*u).as_slice().str();
}

void UserManager::save_user_to_database(User *u, UserId user_id) {
  CHECK(u != nullptr);
  if (u->is_being_saved) {
    return;
  }
  if (loaded_from_database_users_.count(user_id)) {
    save_user_to_database_impl(u, user_id, get_user_database_value(u));
    return;
  }
  if (load_user_from_database_queries_.count(user_id) != 0) {
    return;
  }

  load_user_from_database_impl(user_id, Auto());
}

void UserManager::save_user_to_database_impl(User *u, UserId user_id, string value) {
  CHECK(u != nullptr);
  CHECK(load_user_from_database_queries_.count(user_id) == 0);
  CHECK(!u->is_being_saved);
  u->is_being_saved = true;
  u->is_saved = true;
  u->is_status_saved = true;
  LOG(INFO) << "Trying to save to database " << user_id;
  G()->td_db()->get_sqlite_pmc()->set(
      get_user_database_key(user_id), std::move(value), PromiseCreator::lambda([user_id](Result<> result) {
        send_closure(G()->user_manager(), &UserManager::on_save_user_to_database, user_id, result.is_ok());
      }));
}

void UserManager::on_save_user_to_database(UserId user_id, bool success) {
  if (G()->close_flag()) {
    return;
  }

  User *u = get_user(user_id);
  CHECK(u != nullptr);
  LOG_CHECK(u->is_being_saved) << success << ' ' << user_id << ' ' << u->is_saved << ' ' << u->is_status_saved << ' '
                               << load_user_from_database_queries_.count(user_id) << ' ' << u->is_received << ' '
                               << u->is_deleted << ' ' << u->is_bot << ' ' << u->need_save_to_database << ' '
                               << u->is_changed << ' ' << u->is_status_changed << ' ' << u->is_name_changed << ' '
                               << u->is_username_changed << ' ' << u->is_photo_changed << ' '
                               << u->is_is_contact_changed << ' ' << u->is_is_deleted_changed << ' '
                               << u->is_stories_hidden_changed << ' ' << u->log_event_id;
  CHECK(load_user_from_database_queries_.count(user_id) == 0);
  u->is_being_saved = false;

  if (!success) {
    LOG(ERROR) << "Failed to save " << user_id << " to database";
    u->is_saved = false;
    u->is_status_saved = false;
  } else {
    LOG(INFO) << "Successfully saved " << user_id << " to database";
  }
  if (u->is_saved && u->is_status_saved) {
    if (u->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), u->log_event_id);
      u->log_event_id = 0;
    }
  } else {
    save_user(u, user_id, u->log_event_id != 0);
  }
}

void UserManager::load_user_from_database(User *u, UserId user_id, Promise<Unit> promise) {
  if (loaded_from_database_users_.count(user_id)) {
    promise.set_value(Unit());
    return;
  }

  CHECK(u == nullptr || !u->is_being_saved);
  load_user_from_database_impl(user_id, std::move(promise));
}

void UserManager::load_user_from_database_impl(UserId user_id, Promise<Unit> promise) {
  LOG(INFO) << "Load " << user_id << " from database";
  auto &load_user_queries = load_user_from_database_queries_[user_id];
  load_user_queries.push_back(std::move(promise));
  if (load_user_queries.size() == 1u) {
    G()->td_db()->get_sqlite_pmc()->get(get_user_database_key(user_id), PromiseCreator::lambda([user_id](string value) {
                                          send_closure(G()->user_manager(), &UserManager::on_load_user_from_database,
                                                       user_id, std::move(value), false);
                                        }));
  }
}

void UserManager::on_load_user_from_database(UserId user_id, string value, bool force) {
  if (G()->close_flag() && !force) {
    // the user is in Binlog and will be saved after restart
    return;
  }

  CHECK(user_id.is_valid());
  if (!loaded_from_database_users_.insert(user_id).second) {
    return;
  }

  auto it = load_user_from_database_queries_.find(user_id);
  vector<Promise<Unit>> promises;
  if (it != load_user_from_database_queries_.end()) {
    promises = std::move(it->second);
    CHECK(!promises.empty());
    load_user_from_database_queries_.erase(it);
  }

  LOG(INFO) << "Successfully loaded " << user_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_user_database_key(user_id), Auto());
  //  return;

  User *u = get_user(user_id);
  if (u == nullptr) {
    if (!value.empty()) {
      u = add_user(user_id);

      if (log_event_parse(*u, value).is_error()) {
        LOG(ERROR) << "Failed to load " << user_id << " from database";
        users_.erase(user_id);
      } else {
        u->is_saved = true;
        u->is_status_saved = true;
        update_user(u, user_id, true, true);
      }
    }
  } else {
    CHECK(!u->is_saved);  // user can't be saved before load completes
    CHECK(!u->is_being_saved);
    auto new_value = get_user_database_value(u);
    if (value != new_value) {
      save_user_to_database_impl(u, user_id, std::move(new_value));
    } else if (u->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), u->log_event_id);
      u->log_event_id = 0;
    }
  }

  set_promises(promises);
}

bool UserManager::have_user_force(UserId user_id, const char *source) {
  return get_user_force(user_id, source) != nullptr;
}

UserManager::User *UserManager::get_user_force(UserId user_id, const char *source) {
  auto u = get_user_force_impl(user_id, source);
  if ((u == nullptr || !u->is_received) &&
      (user_id == get_service_notifications_user_id() || user_id == get_replies_bot_user_id() ||
       user_id == get_verification_codes_bot_user_id() || user_id == get_anonymous_bot_user_id() ||
       user_id == get_channel_bot_user_id() || user_id == get_anti_spam_bot_user_id())) {
    int32 flags = telegram_api::user::ACCESS_HASH_MASK;
    bool need_apply_min_photo = true;
    bool is_bot = false;
    bool is_private_bot = false;
    bool is_verified = false;
    bool is_support = false;
    int64 profile_photo_id = 0;
    int32 profile_photo_dc_id = 1;
    string first_name;
    string last_name;
    string username;
    string phone_number;
    int32 bot_info_version = 0;

    if (user_id == get_service_notifications_user_id()) {
      is_verified = true;
      is_support = true;
      first_name = "Telegram";
      if (G()->is_test_dc()) {
        last_name = "Notifications";
      } else {
        profile_photo_id = 3337190045231036;
      }
      phone_number = "42777";
    } else if (user_id == get_replies_bot_user_id()) {
      is_bot = true;
      if (!G()->is_test_dc()) {
        is_private_bot = true;
      }
      first_name = "Replies";
      username = "replies";
      bot_info_version = G()->is_test_dc() ? 1 : 3;
    } else if (user_id == get_verification_codes_bot_user_id()) {
      is_bot = true;
      is_private_bot = true;
      is_verified = true;
      first_name = "Verification Codes";
      username = "VerificationCodes";
      bot_info_version = G()->is_test_dc() ? 4 : 2;
    } else if (user_id == get_anonymous_bot_user_id()) {
      is_bot = true;
      if (!G()->is_test_dc()) {
        is_private_bot = true;
      }
      first_name = "Group";
      username = G()->is_test_dc() ? "izgroupbot" : "GroupAnonymousBot";
      bot_info_version = G()->is_test_dc() ? 1 : 3;
      profile_photo_id = 5159307831025969322;
    } else if (user_id == get_channel_bot_user_id()) {
      is_bot = true;
      if (!G()->is_test_dc()) {
        is_private_bot = true;
      }
      first_name = G()->is_test_dc() ? "Channels" : "Channel";
      username = G()->is_test_dc() ? "channelsbot" : "Channel_Bot";
      bot_info_version = G()->is_test_dc() ? 1 : 4;
      profile_photo_id = 587627495930570665;
    } else if (user_id == get_anti_spam_bot_user_id()) {
      is_bot = true;
      if (G()->is_test_dc()) {
        first_name = "antispambot";
        username = "tantispambot";
      } else {
        is_verified = true;
        first_name = "Telegram Anti-Spam";
        username = "tgsantispambot";
        profile_photo_id = 5170408289966598902;
      }
    }
    if (!phone_number.empty()) {
      flags |= telegram_api::user::PHONE_MASK;
    }

    telegram_api::object_ptr<telegram_api::userProfilePhoto> profile_photo;
    if (!G()->is_test_dc() && profile_photo_id != 0) {
      profile_photo = telegram_api::make_object<telegram_api::userProfilePhoto>(0, false, false, profile_photo_id,
                                                                                BufferSlice(), profile_photo_dc_id);
    }

    auto user = telegram_api::make_object<telegram_api::user>(
        flags, false, false, false, false, is_bot, false, is_private_bot, is_verified, false, false, false, false,
        false, need_apply_min_photo, false, false, false, false, 0, false, false, false, false, false, false, false,
        user_id.get(), 1, first_name, string(), username, phone_number, std::move(profile_photo), nullptr,
        bot_info_version, Auto(), string(), string(), nullptr,
        vector<telegram_api::object_ptr<telegram_api::username>>(), 0, nullptr, nullptr, 0, 0, 0);
    on_get_user(std::move(user), "get_user_force");
    u = get_user(user_id);
    CHECK(u != nullptr && u->is_received);

    reload_user(user_id, Promise<Unit>(), "get_user_force");
  }
  return u;
}

UserManager::User *UserManager::get_user_force_impl(UserId user_id, const char *source) {
  if (!user_id.is_valid()) {
    return nullptr;
  }

  User *u = get_user(user_id);
  if (u != nullptr) {
    return u;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (loaded_from_database_users_.count(user_id)) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << user_id << " from database from " << source;
  on_load_user_from_database(user_id, G()->td_db()->get_sqlite_sync_pmc()->get(get_user_database_key(user_id)), true);
  return get_user(user_id);
}

void UserManager::send_get_me_query(Td *td, Promise<Unit> &&promise) {
  vector<telegram_api::object_ptr<telegram_api::InputUser>> users;
  users.push_back(telegram_api::make_object<telegram_api::inputUserSelf>());
  td->create_handler<GetUsersQuery>(std::move(promise))->send(std::move(users));
}

UserId UserManager::get_me(Promise<Unit> &&promise) {
  auto my_id = get_my_id();
  if (!have_user_force(my_id, "get_me")) {
    get_user_queries_.add_query(my_id.get(), std::move(promise), "get_me");
    return UserId();
  }

  promise.set_value(Unit());
  return my_id;
}

bool UserManager::get_user(UserId user_id, int left_tries, Promise<Unit> &&promise) {
  if (!user_id.is_valid()) {
    promise.set_error(Status::Error(400, "Invalid user identifier"));
    return false;
  }

  if (user_id == get_service_notifications_user_id() || user_id == get_replies_bot_user_id() ||
      user_id == get_verification_codes_bot_user_id() || user_id == get_anonymous_bot_user_id() ||
      user_id == get_channel_bot_user_id() || user_id == get_anti_spam_bot_user_id()) {
    get_user_force(user_id, "get_user");
  }

  if (td_->auth_manager_->is_bot() ? !have_user(user_id) : !have_min_user(user_id)) {
    if (left_tries > 2 && G()->use_chat_info_database()) {
      send_closure_later(actor_id(this), &UserManager::load_user_from_database, nullptr, user_id, std::move(promise));
      return false;
    }
    auto r_input_user = get_input_user(user_id);
    if (left_tries == 1 || r_input_user.is_error()) {
      if (r_input_user.is_error()) {
        promise.set_error(r_input_user.move_as_error());
      } else {
        promise.set_error(Status::Error(400, "User not found"));
      }
      return false;
    }

    get_user_queries_.add_query(user_id.get(), std::move(promise), "get_user");
    return false;
  }

  promise.set_value(Unit());
  return true;
}

void UserManager::reload_user(UserId user_id, Promise<Unit> &&promise, const char *source) {
  if (!user_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid user identifier"));
  }

  have_user_force(user_id, source);

  TRY_STATUS_PROMISE(promise, get_input_user(user_id));

  get_user_queries_.add_query(user_id.get(), std::move(promise), source);
}

Result<telegram_api::object_ptr<telegram_api::InputUser>> UserManager::get_input_user(UserId user_id) const {
  if (user_id == get_my_id()) {
    return telegram_api::make_object<telegram_api::inputUserSelf>();
  }

  const User *u = get_user(user_id);
  if (u == nullptr || u->access_hash == -1 || u->is_min_access_hash) {
    if (td_->auth_manager_->is_bot() && user_id.is_valid()) {
      return telegram_api::make_object<telegram_api::inputUser>(user_id.get(), 0);
    }
    auto it = user_messages_.find(user_id);
    if (it != user_messages_.end()) {
      CHECK(!it->second.empty());
      auto message_full_id = *it->second.begin();
      return telegram_api::make_object<telegram_api::inputUserFromMessage>(
          td_->chat_manager_->get_simple_input_peer(message_full_id.get_dialog_id()),
          message_full_id.get_message_id().get_server_message_id().get(), user_id.get());
    }
    if (u == nullptr) {
      return Status::Error(400, "User not found");
    } else {
      return Status::Error(400, "Have no access to the user");
    }
  }

  return telegram_api::make_object<telegram_api::inputUser>(user_id.get(), u->access_hash);
}

telegram_api::object_ptr<telegram_api::InputUser> UserManager::get_input_user_force(UserId user_id) const {
  auto r_input_user = get_input_user(user_id);
  if (r_input_user.is_error()) {
    CHECK(user_id.is_valid());
    return telegram_api::make_object<telegram_api::inputUser>(user_id.get(), 0);
  }
  return r_input_user.move_as_ok();
}

bool UserManager::have_input_peer_user(UserId user_id, AccessRights access_rights) const {
  if (user_id == get_my_id()) {
    return true;
  }
  return have_input_peer_user(get_user(user_id), user_id, access_rights);
}

bool UserManager::have_input_peer_user(const User *u, UserId user_id, AccessRights access_rights) const {
  if (u == nullptr || u->access_hash == -1 || u->is_min_access_hash) {
    if (u == nullptr) {
      LOG(DEBUG) << "Have no user";
    } else {
      LOG(DEBUG) << "Have user without access hash";
    }
    if (td_->auth_manager_->is_bot() && user_id.is_valid()) {
      return true;
    }
    if (user_messages_.count(user_id) != 0) {
      return true;
    }
    return false;
  }
  if (access_rights == AccessRights::Know) {
    return true;
  }
  if (access_rights == AccessRights::Read) {
    return true;
  }
  if (u->is_deleted) {
    LOG(DEBUG) << "Have a deleted user";
    return false;
  }
  return true;
}

telegram_api::object_ptr<telegram_api::InputPeer> UserManager::get_input_peer_user(UserId user_id,
                                                                                   AccessRights access_rights) const {
  if (user_id == get_my_id()) {
    return telegram_api::make_object<telegram_api::inputPeerSelf>();
  }
  const User *u = get_user(user_id);
  if (!have_input_peer_user(u, user_id, access_rights)) {
    return nullptr;
  }
  if (u == nullptr || u->access_hash == -1 || u->is_min_access_hash) {
    if (td_->auth_manager_->is_bot() && user_id.is_valid()) {
      return telegram_api::make_object<telegram_api::inputPeerUser>(user_id.get(), 0);
    }
    auto it = user_messages_.find(user_id);
    CHECK(it != user_messages_.end());
    CHECK(!it->second.empty());
    auto message_full_id = *it->second.begin();
    return telegram_api::make_object<telegram_api::inputPeerUserFromMessage>(
        td_->chat_manager_->get_simple_input_peer(message_full_id.get_dialog_id()),
        message_full_id.get_message_id().get_server_message_id().get(), user_id.get());
  }

  return telegram_api::make_object<telegram_api::inputPeerUser>(user_id.get(), u->access_hash);
}

bool UserManager::have_input_encrypted_peer(SecretChatId secret_chat_id, AccessRights access_rights) const {
  return have_input_encrypted_peer(get_secret_chat(secret_chat_id), access_rights);
}

bool UserManager::have_input_encrypted_peer(const SecretChat *secret_chat, AccessRights access_rights) {
  if (secret_chat == nullptr) {
    LOG(DEBUG) << "Have no secret chat";
    return false;
  }
  if (access_rights == AccessRights::Know) {
    return true;
  }
  if (access_rights == AccessRights::Read) {
    return true;
  }
  return secret_chat->state == SecretChatState::Active;
}

telegram_api::object_ptr<telegram_api::inputEncryptedChat> UserManager::get_input_encrypted_chat(
    SecretChatId secret_chat_id, AccessRights access_rights) const {
  auto sc = get_secret_chat(secret_chat_id);
  if (!have_input_encrypted_peer(sc, access_rights)) {
    return nullptr;
  }

  return telegram_api::make_object<telegram_api::inputEncryptedChat>(secret_chat_id.get(), sc->access_hash);
}

bool UserManager::is_user_contact(UserId user_id, bool is_mutual) const {
  return is_user_contact(get_user(user_id), user_id, is_mutual);
}

bool UserManager::is_user_contact(const User *u, UserId user_id, bool is_mutual) const {
  return u != nullptr && (is_mutual ? u->is_mutual_contact : u->is_contact) && user_id != get_my_id();
}

bool UserManager::is_user_premium(UserId user_id) const {
  return is_user_premium(get_user(user_id));
}

bool UserManager::is_user_premium(const User *u) {
  return u != nullptr && u->is_premium;
}

bool UserManager::is_user_deleted(UserId user_id) const {
  return is_user_deleted(get_user(user_id));
}

bool UserManager::is_user_deleted(const User *u) {
  return u == nullptr || u->is_deleted;
}

bool UserManager::is_user_support(UserId user_id) const {
  return is_user_support(get_user(user_id));
}

bool UserManager::is_user_support(const User *u) {
  return u != nullptr && !u->is_deleted && u->is_support;
}

bool UserManager::is_user_bot(UserId user_id) const {
  return is_user_bot(get_user(user_id));
}

bool UserManager::is_user_bot(const User *u) {
  return u != nullptr && !u->is_deleted && u->is_bot;
}

Result<UserManager::BotData> UserManager::get_bot_data(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return Status::Error(400, "Bot not found");
  }
  if (!u->is_bot) {
    return Status::Error(400, "User is not a bot");
  }
  if (u->is_deleted) {
    return Status::Error(400, "Bot is deleted");
  }
  if (!u->is_received) {
    return Status::Error(400, "Bot is inaccessible");
  }

  BotData bot_data;
  bot_data.username = u->usernames.get_first_username();
  bot_data.can_be_edited = u->can_be_edited_bot;
  bot_data.can_join_groups = u->can_join_groups;
  bot_data.can_read_all_group_messages = u->can_read_all_group_messages;
  bot_data.has_main_app = u->has_main_app;
  bot_data.is_inline = u->is_inline_bot;
  bot_data.is_business = u->is_business_bot;
  bot_data.need_location = u->need_location_bot;
  bot_data.can_be_added_to_attach_menu = u->can_be_added_to_attach_menu;
  return bot_data;
}

bool UserManager::is_user_online(UserId user_id, int32 tolerance, int32 unix_time) const {
  if (unix_time <= 0) {
    unix_time = G()->unix_time();
  }
  int32 was_online = get_user_was_online(get_user(user_id), user_id, unix_time);
  return was_online > unix_time - tolerance;
}

int32 UserManager::get_user_was_online(UserId user_id, int32 unix_time) const {
  if (unix_time <= 0) {
    unix_time = G()->unix_time();
  }
  return get_user_was_online(get_user(user_id), user_id, unix_time);
}

int32 UserManager::get_user_was_online(const User *u, UserId user_id, int32 unix_time) const {
  if (u == nullptr || u->is_deleted) {
    return 0;
  }

  int32 was_online = u->was_online;
  if (user_id == get_my_id()) {
    if (my_was_online_local_ != 0) {
      was_online = my_was_online_local_;
    }
  } else {
    if (u->local_was_online > 0 && u->local_was_online > was_online && u->local_was_online > unix_time) {
      was_online = u->local_was_online;
    }
  }
  return was_online;
}

bool UserManager::is_user_status_exact(UserId user_id) const {
  auto u = get_user(user_id);
  return u != nullptr && !u->is_deleted && !u->is_bot && u->was_online > 0;
}

bool UserManager::is_user_received_from_server(UserId user_id) const {
  const auto *u = get_user(user_id);
  return u != nullptr && u->is_received_from_server;
}

bool UserManager::can_report_user(UserId user_id) const {
  auto u = get_user(user_id);
  return u != nullptr && !u->is_deleted && !u->is_support && u->is_bot;
}

const DialogPhoto *UserManager::get_user_dialog_photo(UserId user_id) {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return nullptr;
  }

  apply_pending_user_photo(u, user_id, "get_user_dialog_photo");
  return &u->photo;
}

const DialogPhoto *UserManager::get_secret_chat_dialog_photo(SecretChatId secret_chat_id) {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return nullptr;
  }
  return get_user_dialog_photo(c->user_id);
}

int32 UserManager::get_user_accent_color_id_object(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr || !u->accent_color_id.is_valid()) {
    return td_->theme_manager_->get_accent_color_id_object(AccentColorId(user_id));
  }

  return td_->theme_manager_->get_accent_color_id_object(u->accent_color_id, AccentColorId(user_id));
}

int32 UserManager::get_secret_chat_accent_color_id_object(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return 5;
  }
  return get_user_accent_color_id_object(c->user_id);
}

CustomEmojiId UserManager::get_user_background_custom_emoji_id(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return CustomEmojiId();
  }

  return u->background_custom_emoji_id;
}

CustomEmojiId UserManager::get_secret_chat_background_custom_emoji_id(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return CustomEmojiId();
  }
  return get_user_background_custom_emoji_id(c->user_id);
}

int32 UserManager::get_user_profile_accent_color_id_object(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return -1;
  }

  return td_->theme_manager_->get_profile_accent_color_id_object(u->profile_accent_color_id);
}

int32 UserManager::get_secret_chat_profile_accent_color_id_object(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return -1;
  }
  return get_user_profile_accent_color_id_object(c->user_id);
}

CustomEmojiId UserManager::get_user_profile_background_custom_emoji_id(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return CustomEmojiId();
  }

  return u->profile_background_custom_emoji_id;
}

CustomEmojiId UserManager::get_secret_chat_profile_background_custom_emoji_id(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return CustomEmojiId();
  }
  return get_user_profile_background_custom_emoji_id(c->user_id);
}

string UserManager::get_user_title(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return string();
  }
  if (u->last_name.empty()) {
    return u->first_name;
  }
  if (u->first_name.empty()) {
    return u->last_name;
  }
  return PSTRING() << u->first_name << ' ' << u->last_name;
}

string UserManager::get_secret_chat_title(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return string();
  }
  return get_user_title(c->user_id);
}

RestrictedRights UserManager::get_user_default_permissions(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr || user_id == get_replies_bot_user_id() || user_id == get_verification_codes_bot_user_id()) {
    return RestrictedRights(false, false, false, false, false, false, false, false, false, false, false, false, false,
                            false, false, u != nullptr, false, ChannelType::Unknown);
  }
  return RestrictedRights(true, true, true, true, true, true, true, true, true, true, true, true, true, false, false,
                          true, false, ChannelType::Unknown);
}

RestrictedRights UserManager::get_secret_chat_default_permissions(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return RestrictedRights(false, false, false, false, false, false, false, false, false, false, false, false, false,
                            false, false, false, false, ChannelType::Unknown);
  }
  return RestrictedRights(true, true, true, true, true, true, true, true, true, true, true, true, true, false, false,
                          false, false, ChannelType::Unknown);
}

td_api::object_ptr<td_api::emojiStatus> UserManager::get_user_emoji_status_object(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr || u->last_sent_emoji_status == nullptr) {
    return nullptr;
  }
  return u->last_sent_emoji_status->get_emoji_status_object();
}

td_api::object_ptr<td_api::emojiStatus> UserManager::get_secret_chat_emoji_status_object(
    SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return nullptr;
  }
  return get_user_emoji_status_object(c->user_id);
}

bool UserManager::get_user_stories_hidden(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return false;
  }
  return u->stories_hidden;
}

bool UserManager::can_poll_user_active_stories(UserId user_id) const {
  const User *u = get_user(user_id);
  return need_poll_user_active_stories(u, user_id) && Time::now() >= u->max_active_story_id_next_reload_time;
}

bool UserManager::need_poll_user_active_stories(const User *u, UserId user_id) const {
  return u != nullptr && user_id != get_my_id() && !is_user_contact(u, user_id, false) && !is_user_bot(u) &&
         !is_user_support(u) && !is_user_deleted(u) && u->was_online != 0;
}

string UserManager::get_user_about(UserId user_id) {
  auto user_full = get_user_full_force(user_id, "get_user_about");
  if (user_full != nullptr) {
    return user_full->about;
  }
  return string();
}

string UserManager::get_secret_chat_about(SecretChatId secret_chat_id) {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return string();
  }
  return get_user_about(c->user_id);
}

string UserManager::get_user_private_forward_name(UserId user_id) {
  auto user_full = get_user_full_force(user_id, "get_user_private_forward_name");
  if (user_full != nullptr) {
    return user_full->private_forward_name;
  }
  return string();
}

bool UserManager::get_user_voice_messages_forbidden(UserId user_id) const {
  if (!is_user_premium(user_id)) {
    return false;
  }
  auto user_full = get_user_full(user_id);
  if (user_full != nullptr) {
    return user_full->voice_messages_forbidden;
  }
  return false;
}

bool UserManager::get_my_sponsored_enabled() const {
  auto user_id = get_my_id();
  if (!is_user_premium(user_id)) {
    return true;
  }
  auto user_full = get_user_full(user_id);
  if (user_full != nullptr) {
    return user_full->sponsored_enabled;
  }
  return true;
}

bool UserManager::get_user_read_dates_private(UserId user_id) {
  auto user_full = get_user_full_force(user_id, "get_user_read_dates_private");
  if (user_full != nullptr) {
    return user_full->read_dates_private;
  }
  return false;
}

string UserManager::get_user_search_text(UserId user_id) const {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return string();
  }
  return get_user_search_text(u);
}

string UserManager::get_user_search_text(const User *u) {
  CHECK(u != nullptr);
  return PSTRING() << u->first_name << ' ' << u->last_name << ' ' << implode(u->usernames.get_active_usernames());
}

void UserManager::for_each_secret_chat_with_user(UserId user_id, const std::function<void(SecretChatId)> &f) {
  auto it = secret_chats_with_user_.find(user_id);
  if (it != secret_chats_with_user_.end()) {
    for (auto secret_chat_id : it->second) {
      f(secret_chat_id);
    }
  }
}

string UserManager::get_user_first_username(UserId user_id) const {
  if (!user_id.is_valid()) {
    return string();
  }

  auto u = get_user(user_id);
  if (u == nullptr) {
    return string();
  }
  return u->usernames.get_first_username();
}

int32 UserManager::get_secret_chat_date(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return 0;
  }
  return c->date;
}

int32 UserManager::get_secret_chat_ttl(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return 0;
  }
  return c->ttl;
}

UserId UserManager::get_secret_chat_user_id(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return UserId();
  }
  return c->user_id;
}

bool UserManager::get_secret_chat_is_outbound(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return false;
  }
  return c->is_outbound;
}

SecretChatState UserManager::get_secret_chat_state(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return SecretChatState::Unknown;
  }
  return c->state;
}

int32 UserManager::get_secret_chat_layer(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return 0;
  }
  return c->layer;
}

FolderId UserManager::get_secret_chat_initial_folder_id(SecretChatId secret_chat_id) const {
  auto c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    return FolderId::main();
  }
  return c->initial_folder_id;
}

vector<BotCommands> UserManager::get_bot_commands(vector<telegram_api::object_ptr<telegram_api::botInfo>> &&bot_infos,
                                                  const vector<DialogParticipant> *participants) {
  vector<BotCommands> result;
  if (td_->auth_manager_->is_bot()) {
    return result;
  }
  for (auto &bot_info : bot_infos) {
    if (bot_info->commands_.empty()) {
      continue;
    }

    auto user_id = UserId(bot_info->user_id_);
    const User *u = get_user_force(user_id, "get_bot_commands");
    if (u == nullptr) {
      LOG(ERROR) << "Receive unknown " << user_id;
      continue;
    }
    if (!is_user_bot(u)) {
      if (!is_user_deleted(u)) {
        LOG(ERROR) << "Receive non-bot " << user_id;
      }
      continue;
    }
    if (participants != nullptr) {
      bool is_participant = false;
      for (auto &participant : *participants) {
        if (participant.dialog_id_ == DialogId(user_id)) {
          is_participant = true;
          break;
        }
      }
      if (!is_participant) {
        LOG(ERROR) << "Skip commands of non-member bot " << user_id;
        continue;
      }
    }
    result.emplace_back(user_id, std::move(bot_info->commands_));
  }
  return result;
}

void UserManager::set_name(const string &first_name, const string &last_name, Promise<Unit> &&promise) {
  auto new_first_name = clean_name(first_name, MAX_NAME_LENGTH);
  auto new_last_name = clean_name(last_name, MAX_NAME_LENGTH);
  if (new_first_name.empty()) {
    return promise.set_error(Status::Error(400, "First name must be non-empty"));
  }

  const User *u = get_user(get_my_id());
  int32 flags = 0;
  // TODO we can already send request for changing first_name and last_name and wanting to set initial values
  // TODO need to be rewritten using invoke after and cancelling previous request
  if (u == nullptr || u->first_name != new_first_name) {
    flags |= ACCOUNT_UPDATE_FIRST_NAME;
  }
  if (u == nullptr || u->last_name != new_last_name) {
    flags |= ACCOUNT_UPDATE_LAST_NAME;
  }
  if (flags == 0) {
    return promise.set_value(Unit());
  }

  td_->create_handler<UpdateProfileQuery>(std::move(promise))->send(flags, new_first_name, new_last_name, "");
}

void UserManager::set_bio(const string &bio, Promise<Unit> &&promise) {
  auto max_bio_length = static_cast<size_t>(td_->option_manager_->get_option_integer("bio_length_max"));
  auto new_bio = strip_empty_characters(bio, max_bio_length);
  for (auto &c : new_bio) {
    if (c == '\n') {
      c = ' ';
    }
  }

  const UserFull *user_full = get_user_full(get_my_id());
  int32 flags = 0;
  // TODO we can already send request for changing bio and wanting to set initial values
  // TODO need to be rewritten using invoke after and cancelling previous request
  if (user_full == nullptr || user_full->about != new_bio) {
    flags |= ACCOUNT_UPDATE_ABOUT;
  }
  if (flags == 0) {
    return promise.set_value(Unit());
  }

  td_->create_handler<UpdateProfileQuery>(std::move(promise))->send(flags, "", "", new_bio);
}

void UserManager::on_update_profile_success(int32 flags, const string &first_name, const string &last_name,
                                            const string &about) {
  CHECK(flags != 0);

  auto my_user_id = get_my_id();
  const User *u = get_user(my_user_id);
  if (u == nullptr) {
    LOG(ERROR) << "Doesn't receive info about me during update profile";
    return;
  }
  LOG_IF(ERROR, (flags & ACCOUNT_UPDATE_FIRST_NAME) != 0 && u->first_name != first_name)
      << "Wrong first name \"" << u->first_name << "\", expected \"" << first_name << '"';
  LOG_IF(ERROR, (flags & ACCOUNT_UPDATE_LAST_NAME) != 0 && u->last_name != last_name)
      << "Wrong last name \"" << u->last_name << "\", expected \"" << last_name << '"';

  if ((flags & ACCOUNT_UPDATE_ABOUT) != 0) {
    UserFull *user_full = get_user_full_force(my_user_id, "on_update_profile_success");
    if (user_full != nullptr) {
      user_full->about = about;
      user_full->is_changed = true;
      update_user_full(user_full, my_user_id, "on_update_profile_success");
      td_->group_call_manager_->on_update_dialog_about(DialogId(my_user_id), user_full->about, true);
    }
  }
}

FileId UserManager::get_profile_photo_file_id(int64 photo_id) const {
  auto it = my_photo_file_id_.find(photo_id);
  if (it == my_photo_file_id_.end()) {
    return FileId();
  }
  return it->second;
}

void UserManager::set_bot_profile_photo(UserId bot_user_id,
                                        const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                                        Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    if (bot_user_id != UserId() && bot_user_id != get_my_id()) {
      return promise.set_error(Status::Error(400, "Invalid bot user identifier specified"));
    }
    bot_user_id = get_my_id();
  } else {
    TRY_RESULT_PROMISE(promise, bot_data, get_bot_data(bot_user_id));
    if (!bot_data.can_be_edited) {
      return promise.set_error(Status::Error(400, "The bot can't be edited"));
    }
  }
  if (input_photo == nullptr) {
    td_->create_handler<UpdateProfilePhotoQuery>(std::move(promise))
        ->send(bot_user_id, FileId(), 0, false, telegram_api::make_object<telegram_api::inputPhotoEmpty>());
    return;
  }
  set_profile_photo_impl(bot_user_id, input_photo, false, false, std::move(promise));
}

void UserManager::set_profile_photo(const td_api::object_ptr<td_api::InputChatPhoto> &input_photo, bool is_fallback,
                                    Promise<Unit> &&promise) {
  dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::UserpicSetup}, Promise<Unit>());
  set_profile_photo_impl(get_my_id(), input_photo, is_fallback, false, std::move(promise));
}

void UserManager::set_profile_photo_impl(UserId user_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                                         bool is_fallback, bool only_suggest, Promise<Unit> &&promise) {
  if (input_photo == nullptr) {
    return promise.set_error(Status::Error(400, "New profile photo must be non-empty"));
  }

  const td_api::object_ptr<td_api::InputFile> *input_file = nullptr;
  double main_frame_timestamp = 0.0;
  bool is_animation = false;
  switch (input_photo->get_id()) {
    case td_api::inputChatPhotoPrevious::ID: {
      if (user_id != get_my_id() || td_->auth_manager_->is_bot()) {
        return promise.set_error(Status::Error(400, "Can't use inputChatPhotoPrevious"));
      }
      auto photo = static_cast<const td_api::inputChatPhotoPrevious *>(input_photo.get());
      auto photo_id = photo->chat_photo_id_;
      auto *u = get_user(user_id);
      if (u != nullptr && u->photo.id > 0 && photo_id == u->photo.id) {
        // it is possible that u->photo.is_fallback != is_fallback, so we need to set the photo anyway
        // return promise.set_value(Unit());
      }

      auto file_id = get_profile_photo_file_id(photo_id);
      if (!file_id.is_valid()) {
        return promise.set_error(Status::Error(400, "Unknown profile photo ID specified"));
      }
      return send_update_profile_photo_query(user_id, file_id, photo_id, is_fallback, std::move(promise));
    }
    case td_api::inputChatPhotoStatic::ID: {
      auto photo = static_cast<const td_api::inputChatPhotoStatic *>(input_photo.get());
      input_file = &photo->photo_;
      break;
    }
    case td_api::inputChatPhotoAnimation::ID: {
      auto photo = static_cast<const td_api::inputChatPhotoAnimation *>(input_photo.get());
      input_file = &photo->animation_;
      main_frame_timestamp = photo->main_frame_timestamp_;
      is_animation = true;
      break;
    }
    case td_api::inputChatPhotoSticker::ID: {
      auto photo = static_cast<const td_api::inputChatPhotoSticker *>(input_photo.get());
      TRY_RESULT_PROMISE(promise, sticker_photo_size, StickerPhotoSize::get_sticker_photo_size(td_, photo->sticker_));

      td_->create_handler<UploadProfilePhotoQuery>(std::move(promise))
          ->send(user_id, std::move(sticker_photo_size), is_fallback, only_suggest);
      return;
    }
    default:
      UNREACHABLE();
      break;
  }

  const double MAX_ANIMATION_DURATION = 10.0;
  if (main_frame_timestamp < 0.0 || main_frame_timestamp > MAX_ANIMATION_DURATION) {
    return promise.set_error(Status::Error(400, "Wrong main frame timestamp specified"));
  }

  auto file_type = is_animation ? FileType::Animation : FileType::Photo;
  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(file_type, *input_file, DialogId(user_id), false, false));

  upload_profile_photo(user_id, {file_id, FileManager::get_internal_upload_id()}, is_fallback, only_suggest,
                       is_animation, main_frame_timestamp, std::move(promise));
}

void UserManager::set_user_profile_photo(UserId user_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                                         bool only_suggest, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
  if (!only_suggest && !is_user_contact(user_id)) {
    return promise.set_error(Status::Error(400, "User isn't a contact"));
  }
  if (user_id == get_my_id()) {
    return promise.set_error(Status::Error(400, "Can't set personal or suggest photo to self"));
  }
  if (is_user_bot(user_id)) {
    return promise.set_error(Status::Error(400, "Can't set personal or suggest photo to bots"));
  }
  if (input_photo == nullptr) {
    td_->create_handler<DeleteContactProfilePhotoQuery>(std::move(promise))->send(user_id, std::move(input_user));
    return;
  }

  set_profile_photo_impl(user_id, input_photo, false, only_suggest, std::move(promise));
}

void UserManager::send_update_profile_photo_query(UserId user_id, FileId file_id, int64 old_photo_id, bool is_fallback,
                                                  Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  FileView file_view = td_->file_manager_->get_file_view(file_id);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location == nullptr) {
    return promise.set_error(Status::Error(500, "Failed to upload the file"));
  }
  td_->create_handler<UpdateProfilePhotoQuery>(std::move(promise))
      ->send(user_id, file_id, old_photo_id, is_fallback, main_remote_location->as_input_photo());
}

void UserManager::upload_profile_photo(UserId user_id, FileUploadId file_upload_id, bool is_fallback, bool only_suggest,
                                       bool is_animation, double main_frame_timestamp, Promise<Unit> &&promise,
                                       int reupload_count, vector<int> bad_parts) {
  CHECK(file_upload_id.is_valid());
  bool is_inserted =
      being_uploaded_profile_photos_
          .emplace(file_upload_id, UploadedProfilePhoto{user_id, is_fallback, only_suggest, main_frame_timestamp,
                                                        is_animation, reupload_count, std::move(promise)})
          .second;
  CHECK(is_inserted);
  LOG(INFO) << "Ask to upload " << (is_animation ? "animated" : "static") << " profile photo " << file_upload_id
            << " for user " << user_id << " with bad parts " << bad_parts;
  // TODO use force_reupload if reupload_count >= 1, replace reupload_count with is_reupload
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_profile_photo_callback_, 32, 0);
}

void UserManager::on_upload_profile_photo(FileUploadId file_upload_id,
                                          telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  auto it = being_uploaded_profile_photos_.find(file_upload_id);
  CHECK(it != being_uploaded_profile_photos_.end());
  UserId user_id = it->second.user_id;
  bool is_fallback = it->second.is_fallback;
  bool only_suggest = it->second.only_suggest;
  double main_frame_timestamp = it->second.main_frame_timestamp;
  bool is_animation = it->second.is_animation;
  int32 reupload_count = it->second.reupload_count;
  auto promise = std::move(it->second.promise);
  being_uploaded_profile_photos_.erase(it);

  LOG(INFO) << "Uploaded " << (is_animation ? "animated" : "static") << " profile photo " << file_upload_id << " for "
            << user_id << " with reupload_count = " << reupload_count;
  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && input_file == nullptr) {
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web photo as profile photo"));
    }
    if (reupload_count == 3) {  // upload, ForceReupload repair file reference, reupload
      return promise.set_error(Status::Error(400, "Failed to reupload the file"));
    }

    // delete file reference and forcely reupload the file
    if (is_animation) {
      CHECK(file_view.get_type() == FileType::Animation);
      LOG_CHECK(main_remote_location->is_common()) << *main_remote_location;
    } else {
      CHECK(file_view.get_type() == FileType::Photo);
      LOG_CHECK(main_remote_location->is_photo()) << *main_remote_location;
    }
    auto file_reference = is_animation ? FileManager::extract_file_reference(main_remote_location->as_input_document())
                                       : FileManager::extract_file_reference(main_remote_location->as_input_photo());
    td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), file_reference);
    upload_profile_photo(user_id, file_upload_id, is_fallback, only_suggest, is_animation, main_frame_timestamp,
                         std::move(promise), reupload_count + 1, {-1});
    return;
  }
  CHECK(input_file != nullptr);

  td_->create_handler<UploadProfilePhotoQuery>(std::move(promise))
      ->send(user_id, file_upload_id, std::move(input_file), is_fallback, only_suggest, is_animation,
             main_frame_timestamp);
}

void UserManager::on_upload_profile_photo_error(FileUploadId file_upload_id, Status status) {
  LOG(INFO) << "Profile photo " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_profile_photos_.find(file_upload_id);
  CHECK(it != being_uploaded_profile_photos_.end());
  auto promise = std::move(it->second.promise);
  being_uploaded_profile_photos_.erase(it);

  promise.set_error(std::move(status));  // TODO check that status has valid error code
}

void UserManager::on_set_profile_photo(UserId user_id, telegram_api::object_ptr<telegram_api::photos_photo> &&photo,
                                       bool is_fallback, int64 old_photo_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Changed profile photo to " << to_string(photo);

  bool is_bot = is_user_bot(user_id);
  bool is_my = (user_id == get_my_id());
  if (is_my && !is_fallback) {
    delete_my_profile_photo_from_cache(old_photo_id);
  }
  bool have_user = false;
  for (const auto &user : photo->users_) {
    if (get_user_id(user) == user_id) {
      have_user = true;
    }
  }
  on_get_users(std::move(photo->users_), "on_set_profile_photo");
  if (!is_bot) {
    add_set_profile_photo_to_cache(user_id, get_photo(td_, std::move(photo->photo_), DialogId(user_id)), is_fallback);
  }
  if (have_user) {
    promise.set_value(Unit());
  } else {
    reload_user(user_id, std::move(promise), "on_set_profile_photo");
  }
}

void UserManager::add_set_profile_photo_to_cache(UserId user_id, Photo &&photo, bool is_fallback) {
  // we have subsequence of user photos in user_photos_
  // ProfilePhoto in User and Photo in UserFull

  User *u = get_user_force(user_id, "add_set_profile_photo_to_cache");
  if (u == nullptr) {
    return;
  }

  LOG(INFO) << "Add profile photo " << photo.id.get() << " to cache";

  bool is_me = user_id == get_my_id();

  // update photo list
  auto user_photos = user_photos_.get_pointer(user_id);
  if (is_me && !is_fallback && user_photos != nullptr && user_photos->count != -1 && !photo.is_empty()) {
    if (user_photos->offset == 0) {
      if (user_photos->photos.empty() || user_photos->photos[0].id.get() != photo.id.get()) {
        user_photos->photos.insert(user_photos->photos.begin(), photo);
        user_photos->count++;
        register_user_photo(u, user_id, user_photos->photos[0]);
      }
    } else {
      user_photos->count++;
      user_photos->offset++;
    }
  }

  // update ProfilePhoto in User
  if ((!is_fallback || u->photo.id == 0) && !photo.is_empty()) {
    do_update_user_photo(u, user_id, as_profile_photo(td_->file_manager_.get(), user_id, u->access_hash, photo, !is_me),
                         false, "add_set_profile_photo_to_cache");
    update_user(u, user_id);
  }

  // update Photo in UserFull
  auto user_full = get_user_full_force(user_id, "add_set_profile_photo_to_cache");
  if (user_full != nullptr) {
    Photo *current_photo = nullptr;
    // don't update the changed photo if other photos aren't known to avoid having only some photos known
    bool need_apply = get_user_full_profile_photo_id(user_full) > 0;
    if (!is_me) {
      current_photo = &user_full->personal_photo;
      if (photo.is_empty()) {
        // always can apply empty personal photo
        need_apply = true;
      }
    } else if (!is_fallback) {
      current_photo = &user_full->photo;
      if (photo.is_empty()) {
        // never can apply empty photo
        need_apply = false;
      }
    } else {
      current_photo = &user_full->fallback_photo;
      if (photo.is_empty()) {
        // always can apply empty fallback photo
        need_apply = true;
      }
    }
    if (*current_photo != photo && need_apply) {
      LOG(INFO) << "Update full photo of " << user_id << " to " << photo;
      *current_photo = photo;
      user_full->is_changed = true;
      if (is_me && !photo.is_empty()) {
        if (!is_fallback) {
          register_user_photo(u, user_id, photo);
        } else {
          register_suggested_profile_photo(photo);
        }
      }
      drop_user_full_photos(user_full, user_id, u->photo.id, "add_set_profile_photo_to_cache");  // just in case
    }
    if (user_full->expires_at > 0.0) {
      user_full->expires_at = 0.0;
      user_full->need_save_to_database = true;
    }
    update_user_full(user_full, user_id, "add_set_profile_photo_to_cache");
    reload_user_full(user_id, Auto(), "add_set_profile_photo_to_cache");
  }
}

bool UserManager::delete_my_profile_photo_from_cache(int64 profile_photo_id) {
  if (profile_photo_id == 0 || profile_photo_id == -2) {
    return false;
  }

  // we have subsequence of user photos in user_photos_
  // ProfilePhoto in User and Photo in UserFull

  LOG(INFO) << "Delete profile photo " << profile_photo_id << " from cache";

  auto user_id = get_my_id();
  User *u = get_user_force(user_id, "delete_my_profile_photo_from_cache");
  bool is_main_photo_deleted = u != nullptr && u->photo.id == profile_photo_id;

  // update photo list
  auto user_photos = user_photos_.get_pointer(user_id);
  if (user_photos != nullptr && user_photos->count > 0) {
    auto old_size = user_photos->photos.size();
    if (td::remove_if(user_photos->photos,
                      [profile_photo_id](const auto &photo) { return photo.id.get() == profile_photo_id; })) {
      auto removed_photos = old_size - user_photos->photos.size();
      CHECK(removed_photos > 0);
      LOG_IF(ERROR, removed_photos != 1) << "Had " << removed_photos << " photos with ID " << profile_photo_id;
      user_photos->count -= narrow_cast<int32>(removed_photos);
      // offset was not changed
      CHECK(user_photos->count >= 0);
    } else {
      // failed to find photo to remove from cache
      // don't know how to adjust user_photos->offset, so drop photos cache
      LOG(INFO) << "Drop photos of " << user_id;
      user_photos->photos.clear();
      user_photos->count = -1;
      user_photos->offset = -1;
    }
  }
  bool have_new_photo =
      user_photos != nullptr && user_photos->count != -1 && user_photos->offset == 0 && !user_photos->photos.empty();

  auto user_full = get_user_full_force(user_id, "delete_my_profile_photo_from_cache");

  // update ProfilePhoto in User
  bool need_reget_user = false;
  if (is_main_photo_deleted) {
    if (have_new_photo) {
      do_update_user_photo(
          u, user_id,
          as_profile_photo(td_->file_manager_.get(), user_id, u->access_hash, user_photos->photos[0], false), false,
          "delete_my_profile_photo_from_cache");
    } else {
      do_update_user_photo(u, user_id, ProfilePhoto(), false, "delete_my_profile_photo_from_cache 2");
      need_reget_user = user_photos == nullptr || user_photos->count != 0;
    }
    update_user(u, user_id);

    // update Photo in UserFull
    if (user_full != nullptr) {
      if (user_full->fallback_photo.id.get() == profile_photo_id) {
        LOG(INFO) << "Drop full public photo of " << user_id;
        user_full->photo = Photo();
        user_full->is_changed = true;
      } else if (have_new_photo) {
        if (user_full->photo.id.get() == profile_photo_id && user_photos->photos[0] != user_full->photo) {
          LOG(INFO) << "Update full photo of " << user_id << " to " << user_photos->photos[0];
          user_full->photo = user_photos->photos[0];
          user_full->is_changed = true;
        }
      } else {
        // repair UserFull photo
        if (!user_full->photo.is_empty()) {
          user_full->photo = Photo();
          user_full->is_changed = true;
        }
        if (!user_full->fallback_photo.is_empty()) {
          user_full->fallback_photo = Photo();
          user_full->is_changed = true;
        }
      }
      if (user_full->expires_at > 0.0) {
        user_full->expires_at = 0.0;
        user_full->need_save_to_database = true;
      }
      reload_user_full(user_id, Auto(), "delete_my_profile_photo_from_cache");
      update_user_full(user_full, user_id, "delete_my_profile_photo_from_cache");
    }
  }

  return need_reget_user;
}

void UserManager::delete_profile_photo(int64 profile_photo_id, bool is_recursive, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  const UserFull *user_full = get_user_full_force(get_my_id(), "delete_profile_photo");
  if (user_full == nullptr) {
    // must load UserFull first, because fallback photo can't be deleted via DeleteProfilePhotoQuery
    if (is_recursive) {
      return promise.set_error(Status::Error(500, "Failed to load UserFullInfo"));
    }
    auto reload_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), profile_photo_id, promise = std::move(promise)](Result<Unit> result) mutable {
          if (result.is_error()) {
            return promise.set_error(result.move_as_error());
          }
          send_closure(actor_id, &UserManager::delete_profile_photo, profile_photo_id, true, std::move(promise));
        });
    reload_user_full(get_my_id(), std::move(reload_promise), "delete_profile_photo");
    return;
  }
  if (user_full->photo.id.get() == profile_photo_id || user_full->fallback_photo.id.get() == profile_photo_id) {
    td_->create_handler<UpdateProfilePhotoQuery>(std::move(promise))
        ->send(get_my_id(), FileId(), profile_photo_id, user_full->fallback_photo.id.get() == profile_photo_id,
               telegram_api::make_object<telegram_api::inputPhotoEmpty>());
    return;
  }

  td_->create_handler<DeleteProfilePhotoQuery>(std::move(promise))->send(profile_photo_id);
}

void UserManager::on_delete_profile_photo(int64 profile_photo_id, Promise<Unit> promise) {
  bool need_reget_user = delete_my_profile_photo_from_cache(profile_photo_id);
  if (need_reget_user && !G()->close_flag()) {
    return reload_user(get_my_id(), std::move(promise), "on_delete_profile_photo");
  }

  promise.set_value(Unit());
}

void UserManager::toggle_user_can_manage_emoji_status(UserId user_id, bool can_manage_emoji_status,
                                                      Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
  if (!is_user_bot(user_id)) {
    return promise.set_error(Status::Error(400, "The user must be a bot"));
  }
  td_->create_handler<ToggleUserEmojiStatusPermissionQuery>(std::move(promise))
      ->send(user_id, std::move(input_user), can_manage_emoji_status);
}

void UserManager::set_user_emoji_status(UserId user_id, const unique_ptr<EmojiStatus> &emoji_status,
                                        Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
  td_->create_handler<UpdateUserEmojiStatusQuery>(std::move(promise))
      ->send(user_id, std::move(input_user), emoji_status);
}

void UserManager::on_set_user_emoji_status(UserId user_id, unique_ptr<EmojiStatus> emoji_status,
                                           Promise<Unit> &&promise) {
  User *u = get_user(user_id);
  if (u != nullptr) {
    on_update_user_emoji_status(u, user_id, std::move(emoji_status));
    update_user(u, user_id);
  }
  promise.set_value(Unit());
}

void UserManager::set_username(const string &username, Promise<Unit> &&promise) {
  if (!username.empty() && !is_allowed_username(username)) {
    return promise.set_error(Status::Error(400, "Username is invalid"));
  }
  td_->create_handler<UpdateUsernameQuery>(std::move(promise))->send(username);
}

void UserManager::toggle_username_is_active(string &&username, bool is_active, Promise<Unit> &&promise) {
  get_me(PromiseCreator::lambda([actor_id = actor_id(this), username = std::move(username), is_active,
                                 promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &UserManager::toggle_username_is_active_impl, std::move(username), is_active,
                   std::move(promise));
    }
  }));
}

void UserManager::toggle_username_is_active_impl(string &&username, bool is_active, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  const User *u = get_user(get_my_id());
  CHECK(u != nullptr);
  if (!u->usernames.can_toggle(username)) {
    return promise.set_error(Status::Error(400, "Wrong username specified"));
  }
  td_->create_handler<ToggleUsernameQuery>(std::move(promise))->send(std::move(username), is_active);
}

void UserManager::reorder_usernames(vector<string> &&usernames, Promise<Unit> &&promise) {
  get_me(PromiseCreator::lambda([actor_id = actor_id(this), usernames = std::move(usernames),
                                 promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &UserManager::reorder_usernames_impl, std::move(usernames), std::move(promise));
    }
  }));
}

void UserManager::reorder_usernames_impl(vector<string> &&usernames, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  const User *u = get_user(get_my_id());
  CHECK(u != nullptr);
  if (!u->usernames.can_reorder_to(usernames)) {
    return promise.set_error(Status::Error(400, "Invalid username order specified"));
  }
  if (usernames.size() <= 1) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ReorderUsernamesQuery>(std::move(promise))->send(std::move(usernames));
}

void UserManager::on_update_username_is_active(UserId user_id, string &&username, bool is_active,
                                               Promise<Unit> &&promise) {
  User *u = get_user(user_id);
  CHECK(u != nullptr);
  if (!u->usernames.can_toggle(username)) {
    return reload_user(user_id, std::move(promise), "on_update_username_is_active");
  }
  on_update_user_usernames(u, user_id, u->usernames.toggle(username, is_active));
  update_user(u, user_id);
  promise.set_value(Unit());
}

void UserManager::on_update_active_usernames_order(UserId user_id, vector<string> &&usernames,
                                                   Promise<Unit> &&promise) {
  User *u = get_user(user_id);
  CHECK(u != nullptr);
  if (!u->usernames.can_reorder_to(usernames)) {
    return reload_user(user_id, std::move(promise), "on_update_active_usernames_order");
  }
  on_update_user_usernames(u, user_id, u->usernames.reorder_to(std::move(usernames)));
  update_user(u, user_id);
  promise.set_value(Unit());
}

void UserManager::toggle_bot_username_is_active(UserId bot_user_id, string &&username, bool is_active,
                                                Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, bot_data, get_bot_data(bot_user_id));
  if (!bot_data.can_be_edited) {
    return promise.set_error(Status::Error(400, "The bot can't be edited"));
  }
  const User *u = get_user(bot_user_id);
  CHECK(u != nullptr);
  if (!u->usernames.can_toggle(username)) {
    return promise.set_error(Status::Error(400, "Wrong username specified"));
  }
  td_->create_handler<ToggleBotUsernameQuery>(std::move(promise))->send(bot_user_id, std::move(username), is_active);
}

void UserManager::reorder_bot_usernames(UserId bot_user_id, vector<string> &&usernames, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, bot_data, get_bot_data(bot_user_id));
  if (!bot_data.can_be_edited) {
    return promise.set_error(Status::Error(400, "The bot can't be edited"));
  }
  const User *u = get_user(bot_user_id);
  CHECK(u != nullptr);
  if (!u->usernames.can_reorder_to(usernames)) {
    return promise.set_error(Status::Error(400, "Invalid username order specified"));
  }
  if (usernames.size() <= 1) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ReorderBotUsernamesQuery>(std::move(promise))->send(bot_user_id, std::move(usernames));
}

void UserManager::set_accent_color(AccentColorId accent_color_id, CustomEmojiId background_custom_emoji_id,
                                   Promise<Unit> &&promise) {
  if (!accent_color_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid accent color identifier specified"));
  }
  if (accent_color_id == AccentColorId(get_my_id())) {
    accent_color_id = AccentColorId();
  }

  td_->create_handler<UpdateColorQuery>(std::move(promise))->send(false, accent_color_id, background_custom_emoji_id);
}

void UserManager::set_profile_accent_color(AccentColorId accent_color_id, CustomEmojiId background_custom_emoji_id,
                                           Promise<Unit> &&promise) {
  td_->create_handler<UpdateColorQuery>(std::move(promise))->send(true, accent_color_id, background_custom_emoji_id);
}

void UserManager::on_update_accent_color_success(bool for_profile, AccentColorId accent_color_id,
                                                 CustomEmojiId background_custom_emoji_id) {
  auto user_id = get_my_id();
  User *u = get_user_force(user_id, "on_update_accent_color_success");
  if (u == nullptr) {
    return;
  }
  if (for_profile) {
    on_update_user_profile_accent_color_id(u, user_id, accent_color_id);
    on_update_user_profile_background_custom_emoji_id(u, user_id, background_custom_emoji_id);
  } else {
    on_update_user_accent_color_id(u, user_id, accent_color_id);
    on_update_user_background_custom_emoji_id(u, user_id, background_custom_emoji_id);
  }
  update_user(u, user_id);
}

void UserManager::set_birthdate(Birthdate &&birthdate, Promise<Unit> &&promise) {
  dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::BirthdaySetup}, Promise<Unit>());
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), birthdate, promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &UserManager::on_set_birthdate, birthdate, std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  td_->create_handler<UpdateBirthdayQuery>(std::move(query_promise))->send(birthdate);
}

void UserManager::on_set_birthdate(Birthdate birthdate, Promise<Unit> &&promise) {
  auto my_user_id = get_my_id();
  UserFull *user_full = get_user_full_force(my_user_id, "on_set_birthdate");
  if (user_full != nullptr && user_full->birthdate != birthdate) {
    user_full->birthdate = std::move(birthdate);
    user_full->is_changed = true;
    update_user_full(user_full, my_user_id, "on_set_birthdate");
  }
  promise.set_value(Unit());
}

void UserManager::set_personal_channel(DialogId dialog_id, Promise<Unit> &&promise) {
  ChannelId channel_id;
  if (dialog_id != DialogId()) {
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "set_personal_channel")) {
      return promise.set_error(Status::Error(400, "Chat not found"));
    }
    if (!td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
      return promise.set_error(Status::Error(400, "Chat can't be set as a personal chat"));
    }
    channel_id = dialog_id.get_channel_id();
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), channel_id, promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &UserManager::on_set_personal_channel, channel_id, std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  td_->create_handler<UpdatePersonalChannelQuery>(std::move(query_promise))->send(channel_id);
}

void UserManager::on_set_personal_channel(ChannelId channel_id, Promise<Unit> &&promise) {
  auto my_user_id = get_my_id();
  UserFull *user_full = get_user_full_force(my_user_id, "on_set_personal_channel");
  if (user_full != nullptr && user_full->personal_channel_id != channel_id) {
    user_full->personal_channel_id = channel_id;
    user_full->is_changed = true;
    update_user_full(user_full, my_user_id, "on_set_personal_channel");
  }
  promise.set_value(Unit());
}

void UserManager::set_emoji_status(const unique_ptr<EmojiStatus> &emoji_status, Promise<Unit> &&promise) {
  if (!td_->option_manager_->get_option_boolean("is_premium")) {
    return promise.set_error(Status::Error(400, "The method is available only to Telegram Premium users"));
  }
  if (emoji_status != nullptr) {
    add_recent_emoji_status(td_, *emoji_status);
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), emoji_status = EmojiStatus::clone_emoji_status(emoji_status),
                              promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &UserManager::on_set_emoji_status, std::move(emoji_status), std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  td_->create_handler<UpdateEmojiStatusQuery>(std::move(query_promise))->send(emoji_status);
}

void UserManager::on_set_emoji_status(unique_ptr<EmojiStatus> emoji_status, Promise<Unit> &&promise) {
  auto user_id = get_my_id();
  User *u = get_user(user_id);
  if (u != nullptr) {
    on_update_user_emoji_status(u, user_id, std::move(emoji_status));
    update_user(u, user_id);
  }
  promise.set_value(Unit());
}

void UserManager::toggle_sponsored_messages(bool sponsored_enabled, Promise<Unit> &&promise) {
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), sponsored_enabled, promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &UserManager::on_toggle_sponsored_messages, sponsored_enabled, std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  td_->create_handler<ToggleSponsoredMessagesQuery>(std::move(query_promise))->send(sponsored_enabled);
}

void UserManager::on_toggle_sponsored_messages(bool sponsored_enabled, Promise<Unit> &&promise) {
  auto my_user_id = get_my_id();
  UserFull *user_full = get_user_full_force(my_user_id, "on_toggle_sponsored_messages");
  if (user_full != nullptr && user_full->sponsored_enabled != sponsored_enabled) {
    user_full->sponsored_enabled = sponsored_enabled;
    user_full->is_changed = true;
    update_user_full(user_full, my_user_id, "on_toggle_sponsored_messages");
  }
  promise.set_value(Unit());
}

void UserManager::get_support_user(Promise<td_api::object_ptr<td_api::user>> &&promise) {
  if (support_user_id_.is_valid()) {
    return promise.set_value(get_user_object(support_user_id_));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), promise = std::move(promise)](Result<UserId> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &UserManager::on_get_support_user, result.move_as_ok(), std::move(promise));
        }
      });
  td_->create_handler<GetSupportUserQuery>(std::move(query_promise))->send();
}

void UserManager::on_get_support_user(UserId user_id, Promise<td_api::object_ptr<td_api::user>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const User *u = get_user(user_id);
  if (u == nullptr) {
    return promise.set_error(Status::Error(500, "Can't find support user"));
  }
  if (!u->is_support) {
    LOG(ERROR) << "Receive non-support " << user_id << ", but expected a support user";
  }

  support_user_id_ = user_id;
  promise.set_value(get_user_object(user_id, u));
}

void UserManager::get_user_profile_photos(UserId user_id, int32 offset, int32 limit,
                                          Promise<td_api::object_ptr<td_api::chatPhotos>> &&promise) {
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_GET_PROFILE_PHOTOS) {
    limit = MAX_GET_PROFILE_PHOTOS;
  }

  TRY_STATUS_PROMISE(promise, get_input_user(user_id));

  auto *u = get_user(user_id);
  if (u == nullptr) {
    return promise.set_error(Status::Error(400, "User not found"));
  }

  apply_pending_user_photo(u, user_id, "get_user_profile_photos");

  auto user_photos = add_user_photos(user_id);
  if (user_photos->count != -1) {  // know photo count
    CHECK(user_photos->offset != -1);
    LOG(INFO) << "Have " << user_photos->count << " cached user profile photos at offset " << user_photos->offset;
    vector<td_api::object_ptr<td_api::chatPhoto>> photo_objects;

    if (offset >= user_photos->count) {
      // offset if too big
      return promise.set_value(td_api::make_object<td_api::chatPhotos>(user_photos->count, std::move(photo_objects)));
    }

    if (limit > user_photos->count - offset) {
      limit = user_photos->count - offset;
    }

    int32 cache_begin = user_photos->offset;
    int32 cache_end = cache_begin + narrow_cast<int32>(user_photos->photos.size());
    if (cache_begin <= offset && offset + limit <= cache_end) {
      // answer query from cache
      for (int i = 0; i < limit; i++) {
        photo_objects.push_back(
            get_chat_photo_object(td_->file_manager_.get(), user_photos->photos[i + offset - cache_begin]));
      }
      return promise.set_value(td_api::make_object<td_api::chatPhotos>(user_photos->count, std::move(photo_objects)));
    }
  }

  PendingGetPhotoRequest pending_request;
  pending_request.offset = offset;
  pending_request.limit = limit;
  pending_request.promise = std::move(promise);
  user_photos->pending_requests.push_back(std::move(pending_request));
  if (user_photos->pending_requests.size() != 1u) {
    return;
  }

  send_get_user_photos_query(user_id, user_photos);
}

void UserManager::send_get_user_photos_query(UserId user_id, const UserPhotos *user_photos) {
  CHECK(!user_photos->pending_requests.empty());
  auto offset = user_photos->pending_requests[0].offset;
  auto limit = user_photos->pending_requests[0].limit;

  if (user_photos->count != -1 && offset >= user_photos->offset) {
    int32 cache_end = user_photos->offset + narrow_cast<int32>(user_photos->photos.size());
    if (offset < cache_end) {
      // adjust offset to the end of cache
      CHECK(offset + limit > cache_end);  // otherwise the request has already been answered
      limit = offset + limit - cache_end;
      offset = cache_end;
    }
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), user_id](Result<Unit> &&result) {
    send_closure(actor_id, &UserManager::on_get_user_profile_photos, user_id, std::move(result));
  });

  td_->create_handler<GetUserPhotosQuery>(std::move(query_promise))
      ->send(user_id, get_input_user_force(user_id), offset, max(limit, MAX_GET_PROFILE_PHOTOS / 5), 0);
}

void UserManager::on_get_user_profile_photos(UserId user_id, Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);
  auto user_photos = add_user_photos(user_id);
  auto pending_requests = std::move(user_photos->pending_requests);
  CHECK(!pending_requests.empty());
  if (result.is_error()) {
    for (auto &request : pending_requests) {
      request.promise.set_error(result.error().clone());
    }
    return;
  }
  if (user_photos->count == -1) {
    CHECK(have_user(user_id));
    // received result has just been dropped; resend request
    if (++pending_requests[0].retry_count >= 3) {
      pending_requests[0].promise.set_error(Status::Error(500, "Failed to return profile photos"));
      pending_requests.erase(pending_requests.begin());
      if (pending_requests.empty()) {
        return;
      }
    }
    user_photos->pending_requests = std::move(pending_requests);
    return send_get_user_photos_query(user_id, user_photos);
  }

  CHECK(user_photos->offset != -1);
  LOG(INFO) << "Have " << user_photos->count << " cached user profile photos at offset " << user_photos->offset;
  vector<PendingGetPhotoRequest> left_requests;
  for (size_t request_index = 0; request_index < pending_requests.size(); request_index++) {
    auto &request = pending_requests[request_index];
    vector<td_api::object_ptr<td_api::chatPhoto>> photo_objects;

    if (request.offset >= user_photos->count) {
      // offset if too big
      request.promise.set_value(td_api::make_object<td_api::chatPhotos>(user_photos->count, std::move(photo_objects)));
      continue;
    }

    if (request.limit > user_photos->count - request.offset) {
      request.limit = user_photos->count - request.offset;
    }

    int32 cache_begin = user_photos->offset;
    int32 cache_end = cache_begin + narrow_cast<int32>(user_photos->photos.size());
    if (cache_begin <= request.offset && request.offset + request.limit <= cache_end) {
      // answer query from cache
      for (int i = 0; i < request.limit; i++) {
        photo_objects.push_back(
            get_chat_photo_object(td_->file_manager_.get(), user_photos->photos[i + request.offset - cache_begin]));
      }
      request.promise.set_value(td_api::make_object<td_api::chatPhotos>(user_photos->count, std::move(photo_objects)));
      continue;
    }

    if (request_index == 0 && ++request.retry_count >= 3) {
      request.promise.set_error(Status::Error(500, "Failed to get profile photos"));
      continue;
    }

    left_requests.push_back(std::move(request));
  }

  if (!left_requests.empty()) {
    bool need_send = user_photos->pending_requests.empty();
    append(user_photos->pending_requests, std::move(left_requests));
    if (need_send) {
      send_get_user_photos_query(user_id, user_photos);
    }
  }
}

void UserManager::reload_user_profile_photo(UserId user_id, int64 photo_id, Promise<Unit> &&promise) {
  get_user_force(user_id, "reload_user_profile_photo");
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));

  // this request will be needed only to download the photo,
  // so there is no reason to combine different requests for a photo into one request
  td_->create_handler<GetUserPhotosQuery>(std::move(promise))->send(user_id, std::move(input_user), -1, 1, photo_id);
}

FileSourceId UserManager::get_user_profile_photo_file_source_id(UserId user_id, int64 photo_id) {
  if (!user_id.is_valid()) {
    return FileSourceId();
  }

  auto u = get_user(user_id);
  if (u != nullptr && u->photo_ids.count(photo_id) != 0) {
    VLOG(file_references) << "Don't need to create file source for photo " << photo_id << " of " << user_id;
    // photo was already added, source ID was registered and shouldn't be needed
    return FileSourceId();
  }

  auto &source_id = user_profile_photo_file_source_ids_[std::make_pair(user_id, photo_id)];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_user_photo_file_source(user_id, photo_id);
  }
  VLOG(file_references) << "Return " << source_id << " for photo " << photo_id << " of " << user_id;
  return source_id;
}

UserManager::UserPhotos *UserManager::add_user_photos(UserId user_id) {
  CHECK(user_id.is_valid());
  auto &user_photos_ptr = user_photos_[user_id];
  if (user_photos_ptr == nullptr) {
    user_photos_ptr = make_unique<UserPhotos>();
  }
  return user_photos_ptr.get();
}

void UserManager::on_get_user_photos(UserId user_id, int32 offset, int32 limit, int32 total_count,
                                     vector<telegram_api::object_ptr<telegram_api::Photo>> photos) {
  auto photo_count = narrow_cast<int32>(photos.size());
  int32 min_total_count = (offset >= 0 && photo_count > 0 ? offset : 0) + photo_count;
  if (total_count < min_total_count) {
    LOG(ERROR) << "Receive wrong photos total_count " << total_count << " for user " << user_id << ": receive "
               << photo_count << " photos with offset " << offset;
    total_count = min_total_count;
  }
  LOG_IF(ERROR, limit < photo_count) << "Requested not more than " << limit << " photos, but " << photo_count
                                     << " received";

  User *u = get_user(user_id);
  if (u == nullptr) {
    LOG(ERROR) << "Can't find " << user_id;
    return;
  }

  if (offset == -1) {
    // from reload_user_profile_photo
    CHECK(limit == 1);
    for (auto &photo_ptr : photos) {
      if (photo_ptr->get_id() == telegram_api::photo::ID) {
        auto server_photo = telegram_api::move_object_as<telegram_api::photo>(photo_ptr);
        if (server_photo->id_ == u->photo.id) {
          auto profile_photo = convert_photo_to_profile_photo(server_photo, u->photo.is_personal);
          if (profile_photo) {
            LOG_IF(ERROR, u->access_hash == -1) << "Receive profile photo of " << user_id << " without access hash";
            get_profile_photo(td_->file_manager_.get(), user_id, u->access_hash, std::move(profile_photo));
          } else {
            LOG(ERROR) << "Failed to get profile photo from " << to_string(server_photo);
          }
        }

        auto photo = get_photo(td_, std::move(server_photo), DialogId(user_id));
        register_user_photo(u, user_id, photo);
      }
    }
    return;
  }

  LOG(INFO) << "Receive " << photo_count << " photos of " << user_id << " out of " << total_count << " with offset "
            << offset << " and limit " << limit;
  UserPhotos *user_photos = add_user_photos(user_id);
  user_photos->count = total_count;
  CHECK(!user_photos->pending_requests.empty());

  if (user_photos->offset == -1) {
    user_photos->offset = 0;
    CHECK(user_photos->photos.empty());
  }

  if (offset != narrow_cast<int32>(user_photos->photos.size()) + user_photos->offset) {
    LOG(INFO) << "Inappropriate offset to append " << user_id << " profile photos to cache: offset = " << offset
              << ", current_offset = " << user_photos->offset << ", photo_count = " << user_photos->photos.size();
    user_photos->photos.clear();
    user_photos->offset = offset;
  }

  for (auto &photo : photos) {
    auto user_photo = get_photo(td_, std::move(photo), DialogId(user_id));
    if (user_photo.is_empty()) {
      LOG(ERROR) << "Receive empty profile photo in getUserPhotos request for " << user_id << " with offset " << offset
                 << " and limit " << limit << ". Receive " << photo_count << " photos out of " << total_count
                 << " photos";
      user_photos->count--;
      CHECK(user_photos->count >= 0);
      continue;
    }

    user_photos->photos.push_back(std::move(user_photo));
    register_user_photo(u, user_id, user_photos->photos.back());
  }
  if (user_photos->offset > user_photos->count) {
    user_photos->offset = user_photos->count;
    user_photos->photos.clear();
  }

  auto known_photo_count = narrow_cast<int32>(user_photos->photos.size());
  if (user_photos->offset + known_photo_count > user_photos->count) {
    user_photos->photos.resize(user_photos->count - user_photos->offset);
  }
}

void UserManager::apply_pending_user_photo(User *u, UserId user_id, const char *source) {
  if (u == nullptr || u->is_photo_inited) {
    return;
  }

  if (pending_user_photos_.count(user_id) > 0) {
    do_update_user_photo(u, user_id, std::move(pending_user_photos_[user_id]), source);
    pending_user_photos_.erase(user_id);
    update_user(u, user_id);
  }
}

void UserManager::register_message_users(MessageFullId message_full_id, vector<UserId> user_ids) {
  auto dialog_id = message_full_id.get_dialog_id();
  CHECK(dialog_id.get_type() == DialogType::Channel);
  if (!td_->chat_manager_->have_channel(dialog_id.get_channel_id())) {
    return;
  }
  for (auto user_id : user_ids) {
    CHECK(user_id.is_valid());
    const User *u = get_user(user_id);
    if (u == nullptr || u->access_hash == -1 || u->is_min_access_hash) {
      auto &user_messages = user_messages_[user_id];
      auto need_update = user_messages.empty();
      user_messages.insert(message_full_id);
      if (need_update) {
        send_closure(G()->td(), &Td::send_update, get_update_user_object(user_id, u));
      }
    }
  }
}

void UserManager::unregister_message_users(MessageFullId message_full_id, vector<UserId> user_ids) {
  if (user_messages_.empty()) {
    // fast path
    return;
  }
  for (auto user_id : user_ids) {
    auto it = user_messages_.find(user_id);
    if (it != user_messages_.end()) {
      it->second.erase(message_full_id);
      if (it->second.empty()) {
        user_messages_.erase(it);

        const User *u = get_user(user_id);
        if (u == nullptr || u->access_hash == -1 || u->is_min_access_hash) {
          send_closure(G()->td(), &Td::send_update, get_update_user_object(user_id, u));
        }
      }
    }
  }
}

void UserManager::can_send_message_to_user(UserId user_id, bool force,
                                           Promise<td_api::object_ptr<td_api::CanSendMessageToUserResult>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (user_id == get_my_id()) {
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultOk>());
  }
  const auto *u = get_user(user_id);
  if (!have_input_peer_user(u, user_id, AccessRights::Write)) {
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultUserIsDeleted>());
  }
  CHECK(user_id.is_valid());
  if ((u != nullptr && ((!u->contact_require_premium && u->paid_message_star_count == 0) || u->is_mutual_contact)) ||
      (td_->option_manager_->get_option_boolean("is_premium") && u->paid_message_star_count == 0)) {
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultOk>());
  }

  auto user_full = get_user_full_force(user_id, "can_send_message_to_user");
  if (user_full != nullptr) {
    if (user_full->send_paid_message_stars > 0) {
      return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultUserHasPaidMessages>(
          user_full->send_paid_message_stars));
    }
    if (user_full->contact_require_premium) {
      return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultUserRestrictsNewChats>());
    }
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultOk>());
  }

  auto it = user_full_contact_price_.find(user_id);
  if (it != user_full_contact_price_.end()) {
    if (it->second > 0) {
      return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultUserHasPaidMessages>(it->second));
    }
    if (it->second == -1) {
      return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultUserRestrictsNewChats>());
    }
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultOk>());
  }

  if (force) {
    return promise.set_value(td_api::make_object<td_api::canSendMessageToUserResultOk>());
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), user_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &UserManager::can_send_message_to_user, user_id, true, std::move(promise));
      });
  get_is_premium_required_to_contact_queries_.add_query(user_id.get(), std::move(query_promise),
                                                        "can_send_message_to_user");
}

void UserManager::on_get_is_premium_required_to_contact_users(
    vector<UserId> &&user_ids, vector<telegram_api::object_ptr<telegram_api::RequirementToContact>> &&requirements,
    Promise<Unit> &&promise) {
  if (user_ids.size() != requirements.size()) {
    LOG(ERROR) << "Receive " << requirements.size() << " flags instead of " << user_ids.size();
    return promise.set_error(Status::Error(500, "Receive invalid response"));
  }
  for (size_t i = 0; i < user_ids.size(); i++) {
    auto user_id = user_ids[i];
    CHECK(user_id.is_valid());
    if (get_user_full(user_id) == nullptr) {
      const auto &requirement = requirements[i].get();
      switch (requirement->get_id()) {
        case telegram_api::requirementToContactEmpty::ID:
          user_full_contact_price_[user_id] = 0;
          break;
        case telegram_api::requirementToContactPremium::ID:
          user_full_contact_price_[user_id] = -1;
          break;
        case telegram_api::requirementToContactPaidMessages::ID:
          user_full_contact_price_[user_id] = StarManager::get_star_count(
              static_cast<const telegram_api::requirementToContactPaidMessages *>(requirement)->stars_amount_);
          break;
        default:
          UNREACHABLE();
      }
    }
  }
  promise.set_value(Unit());
}

void UserManager::allow_send_message_to_user(UserId user_id) {
  CHECK(!td_->auth_manager_->is_bot());
  if (get_user_full(user_id) == nullptr) {
    CHECK(user_id.is_valid());
    auto it = user_full_contact_price_.find(user_id);
    if (it != user_full_contact_price_.end() && it->second == -1) {
      it->second = 0;
    }
  }
}

void UserManager::share_phone_number(UserId user_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!are_contacts_loaded_) {
    load_contacts(PromiseCreator::lambda(
        [actor_id = actor_id(this), user_id, promise = std::move(promise)](Result<Unit> &&) mutable {
          send_closure(actor_id, &UserManager::share_phone_number, user_id, std::move(promise));
        }));
    return;
  }

  LOG(INFO) << "Share phone number with " << user_id;
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));

  td_->messages_manager_->hide_dialog_action_bar(DialogId(user_id));

  td_->create_handler<AcceptContactQuery>(std::move(promise))->send(user_id, std::move(input_user));
}

void UserManager::load_contacts(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    are_contacts_loaded_ = true;
    saved_contact_count_ = 0;
  }
  if (are_contacts_loaded_ && saved_contact_count_ != -1) {
    LOG(INFO) << "Contacts are already loaded";
    return promise.set_value(Unit());
  }
  load_contacts_queries_.push_back(std::move(promise));
  if (load_contacts_queries_.size() == 1u) {
    if (G()->use_chat_info_database() && next_contacts_sync_date_ > 0 && saved_contact_count_ != -1) {
      LOG(INFO) << "Load contacts from database";
      G()->td_db()->get_sqlite_pmc()->get(
          "user_contacts", PromiseCreator::lambda([](string value) {
            send_closure(G()->user_manager(), &UserManager::on_load_contacts_from_database, std::move(value));
          }));
    } else {
      LOG(INFO) << "Load contacts from server";
      reload_contacts(true);
    }
  } else {
    LOG(INFO) << "Load contacts request has already been sent";
  }
}

int64 UserManager::get_contacts_hash() {
  if (!are_contacts_loaded_) {
    return 0;
  }

  vector<int64> user_ids = contacts_hints_.search_empty(100000).second;
  CHECK(std::is_sorted(user_ids.begin(), user_ids.end()));
  auto my_id = get_my_id();
  const User *u = get_user_force(my_id, "get_contacts_hash");
  if (u != nullptr && u->is_contact) {
    user_ids.insert(std::upper_bound(user_ids.begin(), user_ids.end(), my_id.get()), my_id.get());
  }

  vector<uint64> numbers;
  numbers.reserve(user_ids.size() + 1);
  numbers.push_back(saved_contact_count_);
  for (auto user_id : user_ids) {
    numbers.push_back(user_id);
  }
  return get_vector_hash(numbers);
}

void UserManager::reload_contacts(bool force) {
  if (!G()->close_flag() && !td_->auth_manager_->is_bot() &&
      next_contacts_sync_date_ != std::numeric_limits<int32>::max() &&
      (next_contacts_sync_date_ < G()->unix_time() || force)) {
    next_contacts_sync_date_ = std::numeric_limits<int32>::max();
    td_->create_handler<GetContactsQuery>()->send(get_contacts_hash());
  }
}

void UserManager::save_next_contacts_sync_date() {
  if (G()->close_flag()) {
    return;
  }
  if (!G()->use_chat_info_database()) {
    return;
  }
  G()->td_db()->get_binlog_pmc()->set("next_contacts_sync_date", to_string(next_contacts_sync_date_));
}

void UserManager::save_contacts_to_database() {
  if (!G()->use_chat_info_database() || !are_contacts_loaded_) {
    return;
  }

  LOG(INFO) << "Schedule save contacts to database";
  vector<UserId> user_ids =
      transform(contacts_hints_.search_empty(100000).second, [](int64 key) { return UserId(key); });

  G()->td_db()->get_binlog_pmc()->set("saved_contact_count", to_string(saved_contact_count_));
  G()->td_db()->get_binlog()->force_sync(
      PromiseCreator::lambda([user_ids = std::move(user_ids)](Result<> result) {
        if (result.is_ok()) {
          LOG(INFO) << "Saved contacts to database";
          G()->td_db()->get_sqlite_pmc()->set(
              "user_contacts", log_event_store(user_ids).as_slice().str(), PromiseCreator::lambda([](Result<> result) {
                if (result.is_ok()) {
                  send_closure(G()->user_manager(), &UserManager::save_next_contacts_sync_date);
                }
              }));
        }
      }),
      "save_contacts_to_database");
}

void UserManager::on_get_contacts(telegram_api::object_ptr<telegram_api::contacts_Contacts> &&new_contacts) {
  next_contacts_sync_date_ = G()->unix_time() + Random::fast(70000, 100000);

  CHECK(new_contacts != nullptr);
  if (new_contacts->get_id() == telegram_api::contacts_contactsNotModified::ID) {
    if (saved_contact_count_ == -1) {
      saved_contact_count_ = 0;
    }
    on_get_contacts_finished(contacts_hints_.size());
    td_->create_handler<GetContactsStatusesQuery>()->send();
    return;
  }

  auto contacts = move_tl_object_as<telegram_api::contacts_contacts>(new_contacts);
  FlatHashSet<UserId, UserIdHash> contact_user_ids;
  for (auto &user : contacts->users_) {
    auto user_id = get_user_id(user);
    if (!user_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << user_id;
      continue;
    }
    contact_user_ids.insert(user_id);
  }
  on_get_users(std::move(contacts->users_), "on_get_contacts");

  UserId my_id = get_my_id();
  users_.foreach([&](const UserId &user_id, unique_ptr<User> &user) {
    User *u = user.get();
    bool should_be_contact = contact_user_ids.count(user_id) == 1;
    if (u->is_contact != should_be_contact) {
      if (u->is_contact) {
        LOG(INFO) << "Drop contact with " << user_id;
        if (user_id != my_id) {
          LOG_CHECK(contacts_hints_.has_key(user_id.get()))
              << my_id << " " << user_id << " " << to_string(get_user_object(user_id, u));
        }
        on_update_user_is_contact(u, user_id, false, false, false);
        CHECK(u->is_is_contact_changed);
        u->cache_version = 0;
        u->is_repaired = false;
        update_user(u, user_id);
        CHECK(!u->is_contact);
        if (user_id != my_id) {
          CHECK(!contacts_hints_.has_key(user_id.get()));
        }
      } else {
        LOG(ERROR) << "Receive non-contact " << user_id << " in the list of contacts";
      }
    }
  });

  saved_contact_count_ = contacts->saved_count_;
  on_get_contacts_finished(std::numeric_limits<size_t>::max());
}

void UserManager::on_get_contacts_failed(Status error) {
  CHECK(error.is_error());
  next_contacts_sync_date_ = G()->unix_time() + Random::fast(5, 10);
  fail_promises(load_contacts_queries_, std::move(error));
}

void UserManager::on_load_contacts_from_database(string value) {
  if (G()->close_flag()) {
    return;
  }
  if (value.empty()) {
    reload_contacts(true);
    return;
  }

  vector<UserId> user_ids;
  if (log_event_parse(user_ids, value).is_error()) {
    LOG(ERROR) << "Failed to load contacts from database";
    reload_contacts(true);
    return;
  }

  if (log_event_get_version(value) < static_cast<int32>(Version::AddUserFlags2)) {
    next_contacts_sync_date_ = 0;
    save_next_contacts_sync_date();
    reload_contacts(true);
  }

  LOG(INFO) << "Successfully loaded " << user_ids.size() << " contacts from database";

  load_contact_users_multipromise_.add_promise(PromiseCreator::lambda(
      [actor_id = actor_id(this), expected_contact_count = user_ids.size()](Result<Unit> result) {
        if (result.is_ok()) {
          send_closure(actor_id, &UserManager::on_get_contacts_finished, expected_contact_count);
        } else {
          LOG(INFO) << "Failed to load contact users from database: " << result.error();
          send_closure(actor_id, &UserManager::reload_contacts, true);
        }
      }));

  auto lock_promise = load_contact_users_multipromise_.get_promise();

  for (auto user_id : user_ids) {
    get_user(user_id, 3, load_contact_users_multipromise_.get_promise());
  }

  lock_promise.set_value(Unit());
}

void UserManager::on_get_contacts_finished(size_t expected_contact_count) {
  LOG(INFO) << "Finished to get " << contacts_hints_.size() << " contacts out of expected " << expected_contact_count;
  are_contacts_loaded_ = true;
  set_promises(load_contacts_queries_);
  if (expected_contact_count != contacts_hints_.size()) {
    save_contacts_to_database();
  }
}

void UserManager::on_get_contacts_statuses(vector<telegram_api::object_ptr<telegram_api::contactStatus>> &&statuses) {
  auto my_user_id = get_my_id();
  for (auto &status : statuses) {
    UserId user_id(status->user_id_);
    if (user_id != my_user_id) {
      on_update_user_online(user_id, std::move(status->status_));
    }
  }
  save_next_contacts_sync_date();
}

void UserManager::add_contact(Contact contact, bool share_phone_number, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!are_contacts_loaded_) {
    load_contacts(PromiseCreator::lambda([actor_id = actor_id(this), contact = std::move(contact), share_phone_number,
                                          promise = std::move(promise)](Result<Unit> &&) mutable {
      send_closure(actor_id, &UserManager::add_contact, std::move(contact), share_phone_number, std::move(promise));
    }));
    return;
  }

  LOG(INFO) << "Add " << contact << " with share_phone_number = " << share_phone_number;

  auto user_id = contact.get_user_id();
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));

  td_->create_handler<AddContactQuery>(std::move(promise))
      ->send(user_id, std::move(input_user), contact, share_phone_number);
}

std::pair<vector<UserId>, vector<int32>> UserManager::import_contacts(const vector<Contact> &contacts, int64 &random_id,
                                                                      Promise<Unit> &&promise) {
  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return {};
  }

  LOG(INFO) << "Asked to import " << contacts.size() << " contacts with random_id = " << random_id;
  if (random_id != 0) {
    // request has already been sent before
    auto it = imported_contacts_.find(random_id);
    CHECK(it != imported_contacts_.end());
    auto result = std::move(it->second);
    imported_contacts_.erase(it);

    promise.set_value(Unit());
    return result;
  }

  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || random_id == 1 || imported_contacts_.count(random_id) > 0);
  imported_contacts_[random_id];  // reserve place for result

  do_import_contacts(contacts, random_id, std::move(promise));
  return {};
}

void UserManager::do_import_contacts(vector<Contact> contacts, int64 random_id, Promise<Unit> &&promise) {
  size_t size = contacts.size();
  if (size == 0) {
    on_import_contacts_finished(random_id, {}, {});
    return promise.set_value(Unit());
  }

  vector<telegram_api::object_ptr<telegram_api::inputPhoneContact>> input_phone_contacts;
  input_phone_contacts.reserve(size);
  for (size_t i = 0; i < size; i++) {
    input_phone_contacts.push_back(contacts[i].get_input_phone_contact(static_cast<int64>(i)));
  }

  auto task = make_unique<ImportContactsTask>();
  task->promise_ = std::move(promise);
  task->input_contacts_ = std::move(contacts);
  task->imported_user_ids_.resize(size);
  task->unimported_contact_invites_.resize(size);

  bool is_added = import_contact_tasks_.emplace(random_id, std::move(task)).second;
  CHECK(is_added);

  td_->create_handler<ImportContactsQuery>()->send(std::move(input_phone_contacts), random_id);
}

void UserManager::on_imported_contacts(
    int64 random_id, Result<telegram_api::object_ptr<telegram_api::contacts_importedContacts>> result) {
  auto it = import_contact_tasks_.find(random_id);
  CHECK(it != import_contact_tasks_.end());
  CHECK(it->second != nullptr);

  auto task = it->second.get();
  if (result.is_error()) {
    auto promise = std::move(task->promise_);
    import_contact_tasks_.erase(it);
    return promise.set_error(result.move_as_error());
  }

  auto imported_contacts = result.move_as_ok();
  on_get_users(std::move(imported_contacts->users_), "on_imported_contacts");

  for (auto &imported_contact : imported_contacts->imported_) {
    int64 client_id = imported_contact->client_id_;
    if (client_id < 0 || client_id >= static_cast<int64>(task->imported_user_ids_.size())) {
      LOG(ERROR) << "Wrong client_id " << client_id << " returned";
      continue;
    }

    task->imported_user_ids_[static_cast<size_t>(client_id)] = UserId(imported_contact->user_id_);
  }
  for (auto &popular_contact : imported_contacts->popular_invites_) {
    int64 client_id = popular_contact->client_id_;
    if (client_id < 0 || client_id >= static_cast<int64>(task->unimported_contact_invites_.size())) {
      LOG(ERROR) << "Wrong client_id " << client_id << " returned";
      continue;
    }
    if (popular_contact->importers_ < 0) {
      LOG(ERROR) << "Wrong number of importers " << popular_contact->importers_ << " returned";
      continue;
    }

    task->unimported_contact_invites_[static_cast<size_t>(client_id)] = popular_contact->importers_;
  }

  if (!imported_contacts->retry_contacts_.empty()) {
    auto total_size = static_cast<int64>(task->input_contacts_.size());
    vector<telegram_api::object_ptr<telegram_api::inputPhoneContact>> input_phone_contacts;
    input_phone_contacts.reserve(imported_contacts->retry_contacts_.size());
    for (auto &client_id : imported_contacts->retry_contacts_) {
      if (client_id < 0 || client_id >= total_size) {
        LOG(ERROR) << "Wrong client_id " << client_id << " returned";
        continue;
      }
      auto i = static_cast<size_t>(client_id);
      input_phone_contacts.push_back(task->input_contacts_[i].get_input_phone_contact(client_id));
    }
    td_->create_handler<ImportContactsQuery>()->send(std::move(input_phone_contacts), random_id);
    return;
  }

  auto promise = std::move(task->promise_);
  on_import_contacts_finished(random_id, std::move(task->imported_user_ids_),
                              std::move(task->unimported_contact_invites_));
  import_contact_tasks_.erase(it);
  promise.set_value(Unit());
}

void UserManager::on_import_contacts_finished(int64 random_id, vector<UserId> imported_contact_user_ids,
                                              vector<int32> unimported_contact_invites) {
  LOG(INFO) << "Contacts import with random_id " << random_id << " has finished: " << imported_contact_user_ids;
  if (random_id == 1) {
    // import from change_imported_contacts
    all_imported_contacts_ = std::move(next_all_imported_contacts_);
    next_all_imported_contacts_.clear();

    auto result_size = imported_contacts_unique_id_.size();
    auto unique_size = all_imported_contacts_.size();
    auto add_size = imported_contacts_pos_.size();

    imported_contact_user_ids_.resize(result_size);
    unimported_contact_invites_.resize(result_size);

    CHECK(imported_contact_user_ids.size() == add_size);
    CHECK(unimported_contact_invites.size() == add_size);
    CHECK(imported_contacts_unique_id_.size() == result_size);

    std::unordered_map<int64, int32, Hash<int64>> unique_id_to_unimported_contact_invites;
    for (size_t i = 0; i < add_size; i++) {
      auto unique_id = imported_contacts_pos_[i];
      get_user_id_object(imported_contact_user_ids[i], "on_import_contacts_finished");  // to ensure updateUser
      all_imported_contacts_[unique_id].set_user_id(imported_contact_user_ids[i]);
      unique_id_to_unimported_contact_invites[narrow_cast<int64>(unique_id)] = unimported_contact_invites[i];
    }

    if (G()->use_chat_info_database()) {
      G()->td_db()->get_binlog()->force_sync(
          PromiseCreator::lambda(
              [log_event = log_event_store(all_imported_contacts_).as_slice().str()](Result<> result) mutable {
                if (result.is_ok()) {
                  LOG(INFO) << "Save imported contacts to database";
                  G()->td_db()->get_sqlite_pmc()->set("user_imported_contacts", std::move(log_event), Auto());
                }
              }),
          "on_import_contacts_finished");
    }

    for (size_t i = 0; i < result_size; i++) {
      auto unique_id = imported_contacts_unique_id_[i];
      CHECK(unique_id < unique_size);
      imported_contact_user_ids_[i] = all_imported_contacts_[unique_id].get_user_id();
      auto it = unique_id_to_unimported_contact_invites.find(narrow_cast<int64>(unique_id));
      if (it == unique_id_to_unimported_contact_invites.end()) {
        unimported_contact_invites_[i] = 0;
      } else {
        unimported_contact_invites_[i] = it->second;
      }
    }
    return;
  }

  auto it = imported_contacts_.find(random_id);
  CHECK(it != imported_contacts_.end());
  CHECK(it->second.first.empty());
  CHECK(it->second.second.empty());
  imported_contacts_[random_id] = {std::move(imported_contact_user_ids), std::move(unimported_contact_invites)};
}

void UserManager::remove_contacts(const vector<UserId> &user_ids, Promise<Unit> &&promise) {
  LOG(INFO) << "Delete contacts: " << user_ids;
  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return;
  }

  vector<UserId> to_delete_user_ids;
  vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
  for (auto &user_id : user_ids) {
    const User *u = get_user(user_id);
    if (u != nullptr && u->is_contact) {
      auto r_input_user = get_input_user(user_id);
      if (r_input_user.is_ok()) {
        to_delete_user_ids.push_back(user_id);
        input_users.push_back(r_input_user.move_as_ok());
      }
    }
  }

  if (input_users.empty()) {
    return promise.set_value(Unit());
  }

  td_->create_handler<DeleteContactsQuery>(std::move(promise))->send(std::move(input_users));
}

void UserManager::remove_contacts_by_phone_number(vector<string> user_phone_numbers, vector<UserId> user_ids,
                                                  Promise<Unit> &&promise) {
  LOG(INFO) << "Delete contacts by phone number: " << user_phone_numbers;
  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return;
  }

  td_->create_handler<DeleteContactsByPhoneNumberQuery>(std::move(promise))
      ->send(std::move(user_phone_numbers), std::move(user_ids));
}

void UserManager::on_deleted_contacts(const vector<UserId> &deleted_contact_user_ids) {
  LOG(INFO) << "Contacts deletion has finished for " << deleted_contact_user_ids;

  for (auto user_id : deleted_contact_user_ids) {
    auto u = get_user(user_id);
    CHECK(u != nullptr);
    if (!u->is_contact) {
      continue;
    }

    LOG(INFO) << "Drop contact with " << user_id;
    on_update_user_is_contact(u, user_id, false, false, false);
    CHECK(u->is_is_contact_changed);
    u->cache_version = 0;
    u->is_repaired = false;
    update_user(u, user_id);
    CHECK(!u->is_contact);
    CHECK(!contacts_hints_.has_key(user_id.get()));
  }
}

int32 UserManager::get_imported_contact_count(Promise<Unit> &&promise) {
  LOG(INFO) << "Get imported contact count";

  if (!are_contacts_loaded_ || saved_contact_count_ == -1) {
    load_contacts(std::move(promise));
    return 0;
  }
  reload_contacts(false);

  promise.set_value(Unit());
  return saved_contact_count_;
}

void UserManager::load_imported_contacts(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    are_imported_contacts_loaded_ = true;
  }
  if (are_imported_contacts_loaded_) {
    LOG(INFO) << "Imported contacts are already loaded";
    promise.set_value(Unit());
    return;
  }
  load_imported_contacts_queries_.push_back(std::move(promise));
  if (load_imported_contacts_queries_.size() == 1u) {
    if (G()->use_chat_info_database()) {
      LOG(INFO) << "Load imported contacts from database";
      G()->td_db()->get_sqlite_pmc()->get("user_imported_contacts", PromiseCreator::lambda([](string value) {
                                            send_closure_later(G()->user_manager(),
                                                               &UserManager::on_load_imported_contacts_from_database,
                                                               std::move(value));
                                          }));
    } else {
      LOG(INFO) << "Have no previously imported contacts";
      send_closure_later(G()->user_manager(), &UserManager::on_load_imported_contacts_from_database, string());
    }
  } else {
    LOG(INFO) << "Load imported contacts request has already been sent";
  }
}

void UserManager::on_load_imported_contacts_from_database(string value) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(!are_imported_contacts_loaded_);
  if (need_clear_imported_contacts_) {
    need_clear_imported_contacts_ = false;
    value.clear();
  }
  if (value.empty()) {
    CHECK(all_imported_contacts_.empty());
  } else {
    if (log_event_parse(all_imported_contacts_, value).is_error()) {
      LOG(ERROR) << "Failed to load all imported contacts from database";
      all_imported_contacts_.clear();
    } else {
      LOG(INFO) << "Successfully loaded " << all_imported_contacts_.size() << " imported contacts from database";
    }
  }

  load_imported_contact_users_multipromise_.add_promise(
      PromiseCreator::lambda([actor_id = actor_id(this)](Result<Unit> result) {
        if (result.is_ok()) {
          send_closure_later(actor_id, &UserManager::on_load_imported_contacts_finished);
        }
      }));

  auto lock_promise = load_imported_contact_users_multipromise_.get_promise();

  for (const auto &contact : all_imported_contacts_) {
    auto user_id = contact.get_user_id();
    if (user_id.is_valid()) {
      get_user(user_id, 3, load_imported_contact_users_multipromise_.get_promise());
    }
  }

  lock_promise.set_value(Unit());
}

void UserManager::on_load_imported_contacts_finished() {
  LOG(INFO) << "Finished to load " << all_imported_contacts_.size() << " imported contacts";

  for (const auto &contact : all_imported_contacts_) {
    get_user_id_object(contact.get_user_id(), "on_load_imported_contacts_finished");  // to ensure updateUser
  }

  if (need_clear_imported_contacts_) {
    need_clear_imported_contacts_ = false;
    all_imported_contacts_.clear();
  }
  are_imported_contacts_loaded_ = true;
  set_promises(load_imported_contacts_queries_);
}

std::pair<vector<UserId>, vector<int32>> UserManager::change_imported_contacts(vector<Contact> &contacts,
                                                                               int64 &random_id,
                                                                               Promise<Unit> &&promise) {
  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return {};
  }
  if (!are_imported_contacts_loaded_) {
    load_imported_contacts(std::move(promise));
    return {};
  }

  LOG(INFO) << "Asked to change imported contacts to a list of " << contacts.size()
            << " contacts with random_id = " << random_id;
  if (random_id != 0) {
    // request has already been sent before
    if (need_clear_imported_contacts_) {
      need_clear_imported_contacts_ = false;
      all_imported_contacts_.clear();
      if (G()->use_chat_info_database()) {
        G()->td_db()->get_sqlite_pmc()->erase("user_imported_contacts", Auto());
      }
      reload_contacts(true);
    }

    CHECK(are_imported_contacts_changing_);
    are_imported_contacts_changing_ = false;

    auto unimported_contact_invites = std::move(unimported_contact_invites_);
    unimported_contact_invites_.clear();

    auto imported_contact_user_ids = std::move(imported_contact_user_ids_);
    imported_contact_user_ids_.clear();

    promise.set_value(Unit());
    return {std::move(imported_contact_user_ids), std::move(unimported_contact_invites)};
  }

  if (are_imported_contacts_changing_) {
    promise.set_error(Status::Error(400, "ChangeImportedContacts can be called only once at the same time"));
    return {};
  }

  vector<size_t> new_contacts_unique_id(contacts.size());
  vector<Contact> unique_new_contacts;
  unique_new_contacts.reserve(contacts.size());
  std::unordered_map<Contact, size_t, ContactHash, ContactEqual> different_new_contacts;
  std::unordered_set<string, Hash<string>> different_new_phone_numbers;
  size_t unique_size = 0;
  for (size_t i = 0; i < contacts.size(); i++) {
    auto it_success = different_new_contacts.emplace(std::move(contacts[i]), unique_size);
    new_contacts_unique_id[i] = it_success.first->second;
    if (it_success.second) {
      unique_new_contacts.push_back(it_success.first->first);
      different_new_phone_numbers.insert(unique_new_contacts.back().get_phone_number());
      unique_size++;
    }
  }

  vector<string> to_delete;
  vector<UserId> to_delete_user_ids;
  for (auto &old_contact : all_imported_contacts_) {
    auto user_id = old_contact.get_user_id();
    auto it = different_new_contacts.find(old_contact);
    if (it == different_new_contacts.end()) {
      auto phone_number = old_contact.get_phone_number();
      if (different_new_phone_numbers.count(phone_number) == 0) {
        to_delete.push_back(std::move(phone_number));
        if (user_id.is_valid()) {
          to_delete_user_ids.push_back(user_id);
        }
      }
    } else {
      unique_new_contacts[it->second].set_user_id(user_id);
      different_new_contacts.erase(it);
    }
  }
  std::pair<vector<size_t>, vector<Contact>> to_add;
  for (auto &new_contact : different_new_contacts) {
    to_add.first.push_back(new_contact.second);
    to_add.second.push_back(new_contact.first);
  }

  if (to_add.first.empty() && to_delete.empty()) {
    for (size_t i = 0; i < contacts.size(); i++) {
      auto unique_id = new_contacts_unique_id[i];
      contacts[i].set_user_id(unique_new_contacts[unique_id].get_user_id());
    }

    promise.set_value(Unit());
    return {transform(contacts, [&](const Contact &contact) { return contact.get_user_id(); }),
            vector<int32>(contacts.size())};
  }

  are_imported_contacts_changing_ = true;
  random_id = 1;

  remove_contacts_by_phone_number(
      std::move(to_delete), std::move(to_delete_user_ids),
      PromiseCreator::lambda([new_contacts = std::move(unique_new_contacts),
                              new_contacts_unique_id = std::move(new_contacts_unique_id), to_add = std::move(to_add),
                              promise = std::move(promise)](Result<> result) mutable {
        if (result.is_ok()) {
          send_closure_later(G()->user_manager(), &UserManager::on_clear_imported_contacts, std::move(new_contacts),
                             std::move(new_contacts_unique_id), std::move(to_add), std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      }));
  return {};
}

void UserManager::clear_imported_contacts(Promise<Unit> &&promise) {
  LOG(INFO) << "Delete imported contacts";

  if (saved_contact_count_ == 0) {
    promise.set_value(Unit());
    return;
  }

  td_->create_handler<ResetContactsQuery>(std::move(promise))->send();
}

void UserManager::on_clear_imported_contacts(vector<Contact> &&contacts, vector<size_t> contacts_unique_id,
                                             std::pair<vector<size_t>, vector<Contact>> &&to_add,
                                             Promise<Unit> &&promise) {
  LOG(INFO) << "Add " << to_add.first.size() << " contacts";
  next_all_imported_contacts_ = std::move(contacts);
  imported_contacts_unique_id_ = std::move(contacts_unique_id);
  imported_contacts_pos_ = std::move(to_add.first);

  do_import_contacts(std::move(to_add.second), 1, std::move(promise));
}

void UserManager::on_update_contacts_reset() {
  /*
  UserId my_id = get_my_id();
  users_.foreach([&](const UserId &user_id, unique_ptr<User> &user) {
    User *u = user.get();
    if (u->is_contact) {
      LOG(INFO) << "Drop contact with " << user_id;
      if (user_id != my_id) {
        CHECK(contacts_hints_.has_key(user_id.get()));
      }
      on_update_user_is_contact(u, user_id, false, false, false);
      CHECK(u->is_is_contact_changed);
      u->cache_version = 0;
      u->is_repaired = false;
      update_user(u, user_id);
      CHECK(!u->is_contact);
      if (user_id != my_id) {
        CHECK(!contacts_hints_.has_key(user_id.get()));
      }
    }
  });
  */

  saved_contact_count_ = 0;
  if (G()->use_chat_info_database()) {
    G()->td_db()->get_binlog_pmc()->set("saved_contact_count", "0");
    G()->td_db()->get_sqlite_pmc()->erase("user_imported_contacts", Auto());
  }
  if (!are_imported_contacts_loaded_) {
    if (load_imported_contacts_queries_.empty()) {
      CHECK(all_imported_contacts_.empty());
      LOG(INFO) << "Imported contacts were never loaded, just clear them";
    } else {
      LOG(INFO) << "Imported contacts are being loaded, clear them after they will be loaded";
      need_clear_imported_contacts_ = true;
    }
  } else {
    if (!are_imported_contacts_changing_) {
      LOG(INFO) << "Imported contacts were loaded, but aren't changing now, just clear them";
      all_imported_contacts_.clear();
    } else {
      LOG(INFO) << "Imported contacts are changing now, clear them after they will be changed";
      need_clear_imported_contacts_ = true;
    }
  }
  reload_contacts(true);
}

void UserManager::update_contacts_hints(const User *u, UserId user_id, bool from_database) {
  bool is_contact = is_user_contact(u, user_id, false);
  if (td_->auth_manager_->is_bot()) {
    LOG_IF(ERROR, is_contact) << "Bot has " << user_id << " in the contacts list";
    return;
  }

  int64 key = user_id.get();
  string old_value = contacts_hints_.key_to_string(key);
  string new_value = is_contact ? get_user_search_text(u) : string();

  if (new_value != old_value) {
    if (is_contact) {
      contacts_hints_.add(key, new_value);
    } else {
      contacts_hints_.remove(key);
    }
  }

  if (G()->use_chat_info_database()) {
    // update contacts database
    if (!are_contacts_loaded_) {
      if (!from_database && load_contacts_queries_.empty() && is_contact && u->is_is_contact_changed) {
        search_contacts("", std::numeric_limits<int32>::max(), Auto());
      }
    } else {
      if (old_value.empty() == is_contact) {
        save_contacts_to_database();
      }
    }
  }
}

std::pair<int32, vector<UserId>> UserManager::search_contacts(const string &query, int32 limit,
                                                              Promise<Unit> &&promise) {
  LOG(INFO) << "Search contacts with query = \"" << query << "\" and limit = " << limit;

  if (limit < 0) {
    promise.set_error(Status::Error(400, "Limit must be non-negative"));
    return {};
  }

  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return {};
  }
  reload_contacts(false);

  std::pair<size_t, vector<int64>> result;
  if (query.empty()) {
    result = contacts_hints_.search_empty(limit);
  } else {
    result = contacts_hints_.search(query, limit);
  }

  vector<UserId> user_ids;
  user_ids.reserve(result.second.size());
  for (auto key : result.second) {
    user_ids.emplace_back(key);
  }

  promise.set_value(Unit());
  return {narrow_cast<int32>(result.first), std::move(user_ids)};
}

void UserManager::reload_contact_birthdates(bool force) {
  if (td_->option_manager_->get_option_boolean("dismiss_birthday_contact_today")) {
    contact_birthdates_.need_drop_ = true;
    if (!contact_birthdates_.is_being_synced_) {
      contact_birthdates_.is_being_synced_ = true;
      on_get_contact_birthdates(nullptr);
    }
    return;
  }
  if (!G()->close_flag() && !td_->auth_manager_->is_bot() && !contact_birthdates_.is_being_synced_ &&
      (contact_birthdates_.next_sync_time_ < Time::now() || force)) {
    contact_birthdates_.is_being_synced_ = true;
    td_->create_handler<GetContactsBirthdaysQuery>()->send();
  }
}

void UserManager::on_get_contact_birthdates(
    telegram_api::object_ptr<telegram_api::contacts_contactBirthdays> &&birthdays) {
  CHECK(contact_birthdates_.is_being_synced_);
  contact_birthdates_.is_being_synced_ = false;
  if (contact_birthdates_.need_drop_) {
    birthdays = telegram_api::make_object<telegram_api::contacts_contactBirthdays>(Auto(), Auto());
    contact_birthdates_.need_drop_ = false;
  }
  if (birthdays == nullptr) {
    contact_birthdates_.next_sync_time_ = Time::now() + Random::fast(120, 180);
    return;
  }
  contact_birthdates_.next_sync_time_ = Time::now() + Random::fast(86400 / 4, 86400 / 3);

  on_get_users(std::move(birthdays->users_), "on_get_contact_birthdates");
  vector<std::pair<UserId, Birthdate>> users;
  for (auto &contact : birthdays->contacts_) {
    UserId user_id(contact->contact_id_);
    if (is_user_contact(user_id)) {
      Birthdate birthdate(std::move(contact->birthday_));
      UserFull *user_full = get_user_full_force(user_id, "on_get_contact_birthdates");
      if (user_full != nullptr && user_full->birthdate != birthdate) {
        user_full->birthdate = birthdate;
        user_full->is_changed = true;
        update_user_full(user_full, user_id, "on_get_contact_birthdates");
      }
      if (!birthdate.is_empty()) {
        users.emplace_back(user_id, birthdate);
      }
    }
  }
  if (contact_birthdates_.users_ != users) {
    contact_birthdates_.users_ = std::move(users);
    send_closure(G()->td(), &Td::send_update, get_update_contact_close_birthdays());
  }
  // there is no need to save them between restarts
}

void UserManager::hide_contact_birthdays(Promise<Unit> &&promise) {
  td_->create_handler<DismissContactBirthdaysSuggestionQuery>(std::move(promise))->send();
}

vector<UserId> UserManager::get_close_friends(Promise<Unit> &&promise) {
  if (!are_contacts_loaded_) {
    load_contacts(std::move(promise));
    return {};
  }
  reload_contacts(false);

  auto result = contacts_hints_.search_empty(10000);

  vector<UserId> user_ids;
  for (auto key : result.second) {
    UserId user_id(key);
    const User *u = get_user(user_id);
    if (u != nullptr && u->is_close_friend) {
      user_ids.push_back(user_id);
    }
  }

  promise.set_value(Unit());
  return user_ids;
}

void UserManager::set_close_friends(vector<UserId> user_ids, Promise<Unit> &&promise) {
  for (auto &user_id : user_ids) {
    if (!have_user(user_id)) {
      return promise.set_error(Status::Error(400, "User not found"));
    }
  }

  td_->create_handler<EditCloseFriendsQuery>(std::move(promise))->send(std::move(user_ids));
}

void UserManager::on_set_close_friends(const vector<UserId> &user_ids, Promise<Unit> &&promise) {
  FlatHashSet<UserId, UserIdHash> close_friend_user_ids;
  for (auto &user_id : user_ids) {
    CHECK(user_id.is_valid());
    close_friend_user_ids.insert(user_id);
  }
  users_.foreach([&](const UserId &user_id, unique_ptr<User> &user) {
    User *u = user.get();
    if (u->is_contact && u->is_close_friend != (close_friend_user_ids.count(user_id) > 0)) {
      on_update_user_is_contact(u, user_id, u->is_contact, u->is_mutual_contact, !u->is_close_friend);
      update_user(u, user_id);
    }
  });
  promise.set_value(Unit());
}

UserId UserManager::search_user_by_phone_number(string phone_number, bool only_local, Promise<Unit> &&promise) {
  clean_phone_number(phone_number);
  if (phone_number.empty()) {
    promise.set_error(Status::Error(200, "Phone number is invalid"));
    return UserId();
  }

  auto it = resolved_phone_numbers_.find(phone_number);
  if (it != resolved_phone_numbers_.end()) {
    promise.set_value(Unit());
    return it->second;
  }

  if (only_local) {
    promise.set_value(Unit());
  } else {
    td_->create_handler<ResolvePhoneQuery>(std::move(promise))->send(phone_number);
  }
  return UserId();
}

void UserManager::on_resolved_phone_number(const string &phone_number, UserId user_id) {
  if (!user_id.is_valid()) {
    resolved_phone_numbers_.emplace(phone_number, UserId());  // negative cache
    return;
  }

  auto it = resolved_phone_numbers_.find(phone_number);
  if (it != resolved_phone_numbers_.end()) {
    if (it->second != user_id) {
      LOG(WARNING) << "Resolve phone number \"" << phone_number << "\" to " << user_id << ", but have it in "
                   << it->second;
      it->second = user_id;
    }
    return;
  }

  auto *u = get_user(user_id);
  if (u == nullptr) {
    LOG(ERROR) << "Resolve phone number \"" << phone_number << "\" to unknown " << user_id;
  } else if (!u->phone_number.empty()) {
    LOG(ERROR) << "Resolve phone number \"" << phone_number << "\" to " << user_id << " with phone number "
               << u->phone_number;
  } else {
    // the user's phone number can be hidden by privacy settings, despite the user can be found by the phone number
  }
  resolved_phone_numbers_[phone_number] = user_id;  // always update cached value
}

const UserManager::UserFull *UserManager::get_user_full(UserId user_id) const {
  return users_full_.get_pointer(user_id);
}

UserManager::UserFull *UserManager::get_user_full(UserId user_id) {
  return users_full_.get_pointer(user_id);
}

UserManager::UserFull *UserManager::add_user_full(UserId user_id) {
  CHECK(user_id.is_valid());
  auto &user_full_ptr = users_full_[user_id];
  if (user_full_ptr == nullptr) {
    user_full_ptr = make_unique<UserFull>();
    user_full_contact_price_.erase(user_id);
  }
  return user_full_ptr.get();
}

UserManager::UserFull *UserManager::get_user_full_force(UserId user_id, const char *source) {
  if (!have_user_force(user_id, source)) {
    return nullptr;
  }

  UserFull *user_full = get_user_full(user_id);
  if (user_full != nullptr) {
    return user_full;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (!unavailable_user_fulls_.insert(user_id).second) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load full " << user_id << " from database from " << source;
  on_load_user_full_from_database(user_id,
                                  G()->td_db()->get_sqlite_sync_pmc()->get(get_user_full_database_key(user_id)));
  return get_user_full(user_id);
}

void UserManager::load_user_full(UserId user_id, bool force, Promise<Unit> &&promise, const char *source) {
  auto u = get_user(user_id);
  if (u == nullptr) {
    return promise.set_error(Status::Error(400, "User not found"));
  }

  auto user_full = get_user_full_force(user_id, source);
  if (user_full == nullptr) {
    TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
    return send_get_user_full_query(user_id, std::move(input_user), std::move(promise), source);
  }
  if (user_full->is_expired()) {
    auto input_user = get_input_user_force(user_id);
    if (td_->auth_manager_->is_bot() && !force) {
      return send_get_user_full_query(user_id, std::move(input_user), std::move(promise), "load expired user_full");
    }

    send_get_user_full_query(user_id, std::move(input_user), Auto(), "load expired user_full");
  }

  td_->story_manager_->on_view_dialog_active_stories({DialogId(user_id)});
  promise.set_value(Unit());
}

void UserManager::reload_user_full(UserId user_id, Promise<Unit> &&promise, const char *source) {
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
  send_get_user_full_query(user_id, std::move(input_user), std::move(promise), source);
}

void UserManager::send_get_user_full_query(UserId user_id,
                                           telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
                                           Promise<Unit> &&promise, const char *source) {
  LOG(INFO) << "Get full " << user_id << " from " << source;
  if (!user_id.is_valid()) {
    return promise.set_error(Status::Error(500, "Invalid user_id"));
  }
  auto send_query =
      PromiseCreator::lambda([td = td_, input_user = std::move(input_user)](Result<Promise<Unit>> &&promise) mutable {
        if (promise.is_ok() && !G()->close_flag()) {
          td->create_handler<GetFullUserQuery>(promise.move_as_ok())->send(std::move(input_user));
        }
      });
  get_user_full_queries_.add_query(user_id.get(), std::move(send_query), std::move(promise));
}

void UserManager::on_get_user_full(telegram_api::object_ptr<telegram_api::userFull> &&user) {
  LOG(INFO) << "Receive " << to_string(user);

  UserId user_id(user->id_);
  User *u = get_user(user_id);
  if (u == nullptr) {
    LOG(ERROR) << "Failed to find " << user_id;
    return;
  }

  auto is_bot = is_user_bot(u);

  apply_pending_user_photo(u, user_id, "on_get_user_full");

  td_->messages_manager_->on_update_dialog_notify_settings(DialogId(user_id), std::move(user->notify_settings_),
                                                           "on_get_user_full");

  td_->messages_manager_->on_update_dialog_background(DialogId(user_id), std::move(user->wallpaper_));

  td_->messages_manager_->on_update_dialog_theme_name(DialogId(user_id), std::move(user->theme_emoticon_));

  td_->messages_manager_->on_update_dialog_last_pinned_message_id(DialogId(user_id),
                                                                  MessageId(ServerMessageId(user->pinned_msg_id_)));

  td_->messages_manager_->on_update_dialog_folder_id(DialogId(user_id), FolderId(user->folder_id_));

  td_->messages_manager_->on_update_dialog_has_scheduled_server_messages(DialogId(user_id), user->has_scheduled_);

  td_->messages_manager_->on_update_dialog_message_ttl(DialogId(user_id), MessageTtl(user->ttl_period_));

  td_->messages_manager_->on_update_dialog_is_blocked(DialogId(user_id), user->blocked_,
                                                      user->blocked_my_stories_from_);

  td_->messages_manager_->on_update_dialog_is_translatable(DialogId(user_id), !user->translations_disabled_);

  send_closure_later(td_->story_manager_actor_, &StoryManager::on_get_dialog_stories, DialogId(user_id),
                     std::move(user->stories_), Promise<Unit>());

  UserFull *user_full = add_user_full(user_id);
  user_full->expires_at = Time::now() + USER_FULL_EXPIRE_TIME;

  on_update_user_full_is_blocked(user_full, user_id, user->blocked_, user->blocked_my_stories_from_);
  on_update_user_full_gift_count(user_full, user_id, user->stargifts_count_);
  on_update_user_full_common_chat_count(user_full, user_id, user->common_chats_count_);
  on_update_user_full_location(user_full, user_id, DialogLocation(td_, std::move(user->business_location_)));
  on_update_user_full_work_hours(user_full, user_id, BusinessWorkHours(std::move(user->business_work_hours_)));
  on_update_user_full_away_message(user_full, user_id, BusinessAwayMessage(std::move(user->business_away_message_)));
  on_update_user_full_greeting_message(user_full, user_id,
                                       BusinessGreetingMessage(std::move(user->business_greeting_message_)));
  on_update_user_full_intro(user_full, user_id, BusinessIntro(td_, std::move(user->business_intro_)));
  on_update_user_full_need_phone_number_privacy_exception(user_full, user_id,
                                                          user->settings_->need_contacts_exception_);
  on_update_user_full_charge_paid_message_stars(
      user_full, user_id, StarManager::get_star_count(user->settings_->charge_paid_message_stars_));
  on_update_user_full_send_paid_message_stars(user_full, user_id,
                                              StarManager::get_star_count(user->send_paid_messages_stars_));
  on_update_user_full_wallpaper_overridden(user_full, user_id, user->wallpaper_overridden_);

  bool can_pin_messages = user->can_pin_message_;
  bool can_be_called = user->phone_calls_available_ && !user->phone_calls_private_;
  bool supports_video_calls = user->video_calls_available_ && !user->phone_calls_private_;
  bool has_private_calls = user->phone_calls_private_;
  bool voice_messages_forbidden = u->is_premium ? user->voice_messages_forbidden_ : false;
  bool has_pinned_stories = user->stories_pinned_available_;
  auto birthdate = Birthdate(std::move(user->birthday_));
  auto personal_channel_id = ChannelId(user->personal_channel_id_);
  auto sponsored_enabled = user->sponsored_enabled_;
  auto can_view_revenue = user->can_view_revenue_;
  auto bot_verification = BotVerification::get_bot_verification(std::move(user->bot_verification_));
  if (user_full->can_be_called != can_be_called || user_full->supports_video_calls != supports_video_calls ||
      user_full->has_private_calls != has_private_calls ||
      user_full->voice_messages_forbidden != voice_messages_forbidden ||
      user_full->can_pin_messages != can_pin_messages || user_full->has_pinned_stories != has_pinned_stories ||
      user_full->sponsored_enabled != sponsored_enabled || user_full->can_view_revenue != can_view_revenue ||
      user_full->bot_verification != bot_verification) {
    user_full->can_be_called = can_be_called;
    user_full->supports_video_calls = supports_video_calls;
    user_full->has_private_calls = has_private_calls;
    user_full->voice_messages_forbidden = voice_messages_forbidden;
    user_full->can_pin_messages = can_pin_messages;
    user_full->has_pinned_stories = has_pinned_stories;
    user_full->sponsored_enabled = sponsored_enabled;
    user_full->can_view_revenue = can_view_revenue;
    user_full->bot_verification = std::move(bot_verification);

    user_full->is_changed = true;
  }
  if (user_full->birthdate != birthdate) {
    user_full->birthdate = birthdate;
    user_full->is_changed = true;

    if (u->is_mutual_contact) {
      reload_contact_birthdates(true);
    }
  }

  if (user_full->private_forward_name != user->private_forward_name_) {
    if (user_full->private_forward_name.empty() != user->private_forward_name_.empty()) {
      user_full->is_changed = true;
    }
    user_full->private_forward_name = std::move(user->private_forward_name_);
    user_full->need_save_to_database = true;
  }
  if (user_full->read_dates_private != user->read_dates_private_ ||
      user_full->contact_require_premium != user->contact_require_premium_) {
    user_full->read_dates_private = user->read_dates_private_;
    user_full->contact_require_premium = user->contact_require_premium_;
    user_full->need_save_to_database = true;
  }
  if (user_full->about != user->about_) {
    user_full->about = std::move(user->about_);
    user_full->is_changed = true;
    td_->group_call_manager_->on_update_dialog_about(DialogId(user_id), user_full->about, true);
  }
  if (is_bot && !td_->auth_manager_->is_bot()) {
    auto *bot_info = user_full->add_bot_info();
    AdministratorRights group_administrator_rights(user->bot_group_admin_rights_, ChannelType::Megagroup);
    AdministratorRights broadcast_administrator_rights(user->bot_broadcast_admin_rights_, ChannelType::Broadcast);
    ReferralProgramInfo referral_program_info;
    if (user->starref_program_ != nullptr) {
      auto bot_user_id = UserId(user->starref_program_->bot_id_);
      if (user_id == bot_user_id) {
        referral_program_info = ReferralProgramInfo(std::move(user->starref_program_));
      } else {
        LOG(ERROR) << "Receive affiliate program for " << bot_user_id << " instead of " << user_id;
      }
    }
    if (bot_info->group_administrator_rights != group_administrator_rights ||
        bot_info->broadcast_administrator_rights != broadcast_administrator_rights ||
        bot_info->referral_program_info != referral_program_info) {
      bot_info->group_administrator_rights = std::move(group_administrator_rights);
      bot_info->broadcast_administrator_rights = std::move(broadcast_administrator_rights);
      bot_info->referral_program_info = std::move(referral_program_info);

      user_full->is_changed = true;
    }

    string description;
    Photo description_photo;
    FileId description_animation_file_id;
    string placeholder_path;
    int32 background_color = -1;
    int32 background_dark_color = -1;
    int32 header_color = -1;
    int32 header_dark_color = -1;
    BotVerifierSettings verifier_settings;
    if (user->bot_info_ != nullptr) {
      description = std::move(user->bot_info_->description_);
      description_photo = get_photo(td_, std::move(user->bot_info_->description_photo_), DialogId(user_id));
      auto document = std::move(user->bot_info_->description_document_);
      if (document != nullptr) {
        int32 document_id = document->get_id();
        if (document_id == telegram_api::document::ID) {
          auto parsed_document = td_->documents_manager_->on_get_document(
              move_tl_object_as<telegram_api::document>(document), DialogId(user_id), false);
          if (parsed_document.type == Document::Type::Animation) {
            description_animation_file_id = parsed_document.file_id;
          } else {
            LOG(ERROR) << "Receive non-animation document in bot description";
          }
        }
      }

      on_update_user_full_commands(user_full, user_id, std::move(user->bot_info_->commands_));
      on_update_user_full_menu_button(user_full, user_id, std::move(user->bot_info_->menu_button_));
      on_update_user_full_has_preview_medias(user_full, user_id, user->bot_info_->has_preview_medias_);
      on_update_user_full_verifier_settings(
          user_full, user_id,
          BotVerifierSettings::get_bot_verifier_settings(std::move(user->bot_info_->verifier_settings_)));

      if (bot_info->privacy_policy_url != user->bot_info_->privacy_policy_url_) {
        bot_info->privacy_policy_url = std::move(user->bot_info_->privacy_policy_url_);
        user_full->is_changed = true;
      }
      if (user->bot_info_->app_settings_ != nullptr) {
        auto *app_settings = user->bot_info_->app_settings_.get();
        placeholder_path = app_settings->placeholder_path_.as_slice().str();
        if ((app_settings->flags_ & telegram_api::botAppSettings::BACKGROUND_COLOR_MASK) != 0) {
          background_color = app_settings->background_color_;
        }
        if ((app_settings->flags_ & telegram_api::botAppSettings::BACKGROUND_DARK_COLOR_MASK) != 0) {
          background_dark_color = app_settings->background_dark_color_;
        }
        if ((app_settings->flags_ & telegram_api::botAppSettings::HEADER_COLOR_MASK) != 0) {
          header_color = app_settings->header_color_;
        }
        if ((app_settings->flags_ & telegram_api::botAppSettings::HEADER_DARK_COLOR_MASK) != 0) {
          header_dark_color = app_settings->header_dark_color_;
        }
      }
    }
    if (bot_info->description != description) {
      bot_info->description = std::move(description);
      user_full->is_changed = true;
    }
    if (bot_info->description_photo != description_photo ||
        bot_info->description_animation_file_id != description_animation_file_id) {
      bot_info->description_photo = std::move(description_photo);
      bot_info->description_animation_file_id = description_animation_file_id;
      user_full->is_changed = true;
    }
    if (bot_info->background_color != background_color || bot_info->background_dark_color != background_dark_color ||
        bot_info->header_color != header_color || bot_info->header_dark_color != header_dark_color) {
      bot_info->background_color = background_color;
      bot_info->background_dark_color = background_dark_color;
      bot_info->header_color = header_color;
      bot_info->header_dark_color = header_dark_color;
      user_full->is_changed = true;
    }
    if (bot_info->placeholder_path != placeholder_path) {
      bot_info->placeholder_path = std::move(placeholder_path);
      user_full->need_save_to_database = true;
    }
  }

  on_update_user_full_can_manage_emoji_status(user_full, user_id, user->bot_can_manage_emoji_status_);
  if (personal_channel_id != ChannelId() &&
      td_->chat_manager_->get_channel_type(personal_channel_id) != ChannelType::Broadcast) {
    LOG(ERROR) << "Receive personal " << personal_channel_id << " of the type "
               << static_cast<uint8>(td_->chat_manager_->get_channel_type(personal_channel_id));
    personal_channel_id = ChannelId();
  }
  if (user_full->personal_channel_id != personal_channel_id) {
    user_full->personal_channel_id = personal_channel_id;
    user_full->is_changed = true;
  }
  if (user_full->personal_channel_id != ChannelId()) {
    auto personal_message_id = MessageId(ServerMessageId(user->personal_channel_message_));
    td_->messages_manager_->get_channel_difference_if_needed(DialogId(user_full->personal_channel_id),
                                                             personal_message_id, "on_get_user_full personal chat");
  }

  auto photo = get_photo(td_, std::move(user->profile_photo_), DialogId(user_id));
  auto personal_photo = get_photo(td_, std::move(user->personal_photo_), DialogId(user_id));
  auto fallback_photo = get_photo(td_, std::move(user->fallback_photo_), DialogId(user_id));
  // do_update_user_photo should be a no-op if server sent consistent data
  const Photo *photo_ptr = nullptr;
  bool is_personal = false;
  if (!personal_photo.is_empty()) {
    photo_ptr = &personal_photo;
    is_personal = true;
  } else if (!photo.is_empty()) {
    photo_ptr = &photo;
  } else {
    photo_ptr = &fallback_photo;
  }
  bool is_photo_empty = photo_ptr->is_empty();
  do_update_user_photo(u, user_id,
                       as_profile_photo(td_->file_manager_.get(), user_id, u->access_hash, *photo_ptr, is_personal),
                       false, "on_get_user_full");
  if (photo != user_full->photo) {
    user_full->photo = std::move(photo);
    user_full->is_changed = true;
  }
  if (personal_photo != user_full->personal_photo) {
    user_full->personal_photo = std::move(personal_photo);
    user_full->is_changed = true;
  }
  if (fallback_photo != user_full->fallback_photo) {
    user_full->fallback_photo = std::move(fallback_photo);
    user_full->is_changed = true;
  }
  if (!user_full->photo.is_empty()) {
    register_user_photo(u, user_id, user_full->photo);
  }
  if (user_id == get_my_id() && !user_full->fallback_photo.is_empty()) {
    register_suggested_profile_photo(user_full->fallback_photo);
  }
  if (is_photo_empty) {
    drop_user_photos(user_id, true, "on_get_user_full");
  }

  // User must be updated before UserFull
  if (u->is_changed) {
    LOG(ERROR) << "Receive inconsistent chatPhoto and chatPhotoInfo for " << user_id;
    update_user(u, user_id);
  }

  user_full->is_update_user_full_sent = true;
  update_user_full(user_full, user_id, "on_get_user_full");

  // update peer settings after UserFull is created and updated to not update twice
  // need_phone_number_privacy_exception and charge_paid_message_stars
  td_->messages_manager_->on_get_peer_settings(DialogId(user_id), std::move(user->settings_));
}

FileSourceId UserManager::get_user_full_file_source_id(UserId user_id) {
  if (!user_id.is_valid()) {
    return FileSourceId();
  }

  auto user_full = get_user_full(user_id);
  if (user_full != nullptr) {
    VLOG(file_references) << "Don't need to create file source for full " << user_id;
    // user full was already added, source ID was registered and shouldn't be needed
    return user_full->is_update_user_full_sent ? FileSourceId() : user_full->file_source_id;
  }

  auto &source_id = user_full_file_source_ids_[user_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_user_full_file_source(user_id);
  }
  VLOG(file_references) << "Return " << source_id << " for full " << user_id;
  return source_id;
}

void UserManager::save_user_full(const UserFull *user_full, UserId user_id) {
  if (!G()->use_chat_info_database()) {
    return;
  }

  LOG(INFO) << "Trying to save to database full " << user_id;
  CHECK(user_full != nullptr);
  G()->td_db()->get_sqlite_pmc()->set(get_user_full_database_key(user_id), get_user_full_database_value(user_full),
                                      Auto());
}

string UserManager::get_user_full_database_key(UserId user_id) {
  return PSTRING() << "usf" << user_id.get();
}

string UserManager::get_user_full_database_value(const UserFull *user_full) {
  return log_event_store(*user_full).as_slice().str();
}

void UserManager::on_load_user_full_from_database(UserId user_id, string value) {
  LOG(INFO) << "Successfully loaded full " << user_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_user_full_database_key(user_id), Auto());
  //  return;

  if (get_user_full(user_id) != nullptr || value.empty()) {
    return;
  }

  UserFull *user_full = add_user_full(user_id);
  auto status = log_event_parse(*user_full, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Repair broken full " << user_id << ' ' << format::as_hex_dump<4>(Slice(value));

    // just clean all known data about the user and pretend that there was nothing in the database
    users_full_.erase(user_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_user_full_database_key(user_id), Auto());
    return;
  }

  Dependencies dependencies;
  dependencies.add(user_id);
  if (user_full->business_info != nullptr) {
    user_full->business_info->add_dependencies(dependencies);
  }
  if (user_full->bot_verification != nullptr) {
    user_full->bot_verification->add_dependencies(dependencies);
  }
  dependencies.add(user_full->personal_channel_id);
  if (!dependencies.resolve_force(td_, "on_load_user_full_from_database")) {
    users_full_.erase(user_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_user_full_database_key(user_id), Auto());
    return;
  }

  if (user_full->need_phone_number_privacy_exception && is_user_contact(user_id)) {
    user_full->need_phone_number_privacy_exception = false;
  }

  User *u = get_user(user_id);
  CHECK(u != nullptr);
  drop_user_full_photos(user_full, user_id, u->photo.id, "on_load_user_full_from_database");
  if (!user_full->photo.is_empty()) {
    register_user_photo(u, user_id, user_full->photo);
  }
  if (user_id == get_my_id() && !user_full->fallback_photo.is_empty()) {
    register_suggested_profile_photo(user_full->fallback_photo);
  }

  td_->group_call_manager_->on_update_dialog_about(DialogId(user_id), user_full->about, false);

  user_full->is_update_user_full_sent = true;
  update_user_full(user_full, user_id, "on_load_user_full_from_database", true);

  if (is_user_deleted(u)) {
    drop_user_full(user_id);
  } else if (user_full->expires_at == 0.0) {
    reload_user_full(user_id, Auto(), "on_load_user_full_from_database");
  }
}

void UserManager::get_web_app_placeholder(UserId user_id, Promise<td_api::object_ptr<td_api::outline>> &&promise) {
  auto user_full = get_user_full_force(user_id, "get_web_app_placeholder");
  if (user_full == nullptr || user_full->bot_info == nullptr) {
    return promise.set_value(nullptr);
  }
  promise.set_value(get_outline_object(user_full->bot_info->placeholder_path, 1.0, PSLICE() << "Web App " << user_id));
}

int64 UserManager::get_user_full_profile_photo_id(const UserFull *user_full) {
  if (!user_full->personal_photo.is_empty()) {
    return user_full->personal_photo.id.get();
  }
  if (!user_full->photo.is_empty()) {
    return user_full->photo.id.get();
  }
  return user_full->fallback_photo.id.get();
}

void UserManager::drop_user_full_photos(UserFull *user_full, UserId user_id, int64 expected_photo_id,
                                        const char *source) {
  if (user_full == nullptr) {
    return;
  }
  LOG(INFO) << "Expect full photo " << expected_photo_id << " from " << source;
  for (auto photo_ptr : {&user_full->personal_photo, &user_full->photo, &user_full->fallback_photo}) {
    if (photo_ptr->is_empty()) {
      continue;
    }
    if (expected_photo_id == 0) {
      // if profile photo is empty, we must drop the full photo
      *photo_ptr = Photo();
      user_full->is_changed = true;
    } else if (expected_photo_id != photo_ptr->id.get()) {
      LOG(INFO) << "Drop full photo " << photo_ptr->id.get();
      // if full profile photo is unknown, we must drop the full photo
      *photo_ptr = Photo();
      user_full->is_changed = true;
    } else {
      // nothing to drop
      break;
    }
  }
  if (expected_photo_id != get_user_full_profile_photo_id(user_full)) {
    user_full->expires_at = 0.0;
  }
  if (user_full->is_update_user_full_sent) {
    update_user_full(user_full, user_id, "drop_user_full_photos");
  }
}

void UserManager::drop_user_photos(UserId user_id, bool is_empty, const char *source) {
  LOG(INFO) << "Drop user photos to " << (is_empty ? "empty" : "unknown") << " from " << source;
  auto user_photos = user_photos_.get_pointer(user_id);
  if (user_photos != nullptr) {
    int32 new_count = is_empty ? 0 : -1;
    if (user_photos->count == new_count) {
      CHECK(user_photos->photos.empty());
      CHECK(user_photos->offset == user_photos->count);
    } else {
      LOG(INFO) << "Drop photos of " << user_id << " to " << (is_empty ? "empty" : "unknown") << " from " << source;
      user_photos->photos.clear();
      user_photos->count = new_count;
      user_photos->offset = user_photos->count;
    }
  }
}

void UserManager::drop_user_full(UserId user_id) {
  auto user_full = get_user_full_force(user_id, "drop_user_full");

  drop_user_photos(user_id, false, "drop_user_full");

  if (user_full == nullptr) {
    return;
  }

  user_full->expires_at = 0.0;

  user_full->photo = Photo();
  user_full->personal_photo = Photo();
  user_full->fallback_photo = Photo();
  // user_full->is_blocked = false;
  // user_full->is_blocked_for_stories = false;
  user_full->can_be_called = false;
  user_full->supports_video_calls = false;
  user_full->has_private_calls = false;
  user_full->need_phone_number_privacy_exception = false;
  user_full->wallpaper_overridden = false;
  user_full->about = string();
  user_full->bot_info = nullptr;
  user_full->gift_count = 0;
  user_full->common_chat_count = 0;
  user_full->personal_channel_id = ChannelId();
  user_full->business_info = nullptr;
  user_full->bot_verification = nullptr;
  user_full->private_forward_name.clear();
  user_full->voice_messages_forbidden = false;
  user_full->has_pinned_stories = false;
  user_full->read_dates_private = false;
  user_full->contact_require_premium = false;
  user_full->birthdate = {};
  user_full->sponsored_enabled = false;
  user_full->has_preview_medias = false;
  user_full->can_view_revenue = false;
  user_full->can_manage_emoji_status = false;
  user_full->charge_paid_message_stars = false;
  user_full->send_paid_message_stars = false;
  user_full->is_changed = true;

  update_user_full(user_full, user_id, "drop_user_full");
  td_->group_call_manager_->on_update_dialog_about(DialogId(user_id), user_full->about, true);
}

bool UserManager::have_secret_chat(SecretChatId secret_chat_id) const {
  return secret_chats_.count(secret_chat_id) > 0;
}

const UserManager::SecretChat *UserManager::get_secret_chat(SecretChatId secret_chat_id) const {
  return secret_chats_.get_pointer(secret_chat_id);
}

UserManager::SecretChat *UserManager::get_secret_chat(SecretChatId secret_chat_id) {
  return secret_chats_.get_pointer(secret_chat_id);
}

UserManager::SecretChat *UserManager::add_secret_chat(SecretChatId secret_chat_id) {
  CHECK(secret_chat_id.is_valid());
  auto &secret_chat_ptr = secret_chats_[secret_chat_id];
  if (secret_chat_ptr == nullptr) {
    secret_chat_ptr = make_unique<SecretChat>();
  }
  return secret_chat_ptr.get();
}

bool UserManager::have_secret_chat_force(SecretChatId secret_chat_id, const char *source) {
  return get_secret_chat_force(secret_chat_id, source) != nullptr;
}

UserManager::SecretChat *UserManager::get_secret_chat_force(SecretChatId secret_chat_id, const char *source) {
  if (!secret_chat_id.is_valid()) {
    return nullptr;
  }

  SecretChat *c = get_secret_chat(secret_chat_id);
  if (c != nullptr) {
    if (!have_user_force(c->user_id, source)) {
      LOG(ERROR) << "Can't find " << c->user_id << " from " << secret_chat_id << " from " << source;
    }
    return c;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (loaded_from_database_secret_chats_.count(secret_chat_id)) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << secret_chat_id << " from database from " << source;
  on_load_secret_chat_from_database(
      secret_chat_id, G()->td_db()->get_sqlite_sync_pmc()->get(get_secret_chat_database_key(secret_chat_id)), true);
  return get_secret_chat(secret_chat_id);
}

bool UserManager::get_secret_chat(SecretChatId secret_chat_id, bool force, Promise<Unit> &&promise) {
  if (!secret_chat_id.is_valid()) {
    promise.set_error(Status::Error(400, "Invalid secret chat identifier"));
    return false;
  }

  if (!have_secret_chat(secret_chat_id)) {
    if (!force && G()->use_chat_info_database()) {
      send_closure_later(actor_id(this), &UserManager::load_secret_chat_from_database, nullptr, secret_chat_id,
                         std::move(promise));
      return false;
    }

    promise.set_error(Status::Error(400, "Secret chat not found"));
    return false;
  }

  promise.set_value(Unit());
  return true;
}

void UserManager::save_secret_chat(SecretChat *c, SecretChatId secret_chat_id, bool from_binlog) {
  if (!G()->use_chat_info_database()) {
    return;
  }
  CHECK(c != nullptr);
  if (!c->is_saved) {
    if (!from_binlog) {
      auto log_event = SecretChatLogEvent(secret_chat_id, c);
      auto storer = get_log_event_storer(log_event);
      if (c->log_event_id == 0) {
        c->log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SecretChatInfos, storer);
      } else {
        binlog_rewrite(G()->td_db()->get_binlog(), c->log_event_id, LogEvent::HandlerType::SecretChatInfos, storer);
      }
    }

    save_secret_chat_to_database(c, secret_chat_id);
    return;
  }
}

string UserManager::get_secret_chat_database_key(SecretChatId secret_chat_id) {
  return PSTRING() << "sc" << secret_chat_id.get();
}

string UserManager::get_secret_chat_database_value(const SecretChat *c) {
  return log_event_store(*c).as_slice().str();
}

void UserManager::save_secret_chat_to_database(SecretChat *c, SecretChatId secret_chat_id) {
  CHECK(c != nullptr);
  if (c->is_being_saved) {
    return;
  }
  if (loaded_from_database_secret_chats_.count(secret_chat_id)) {
    save_secret_chat_to_database_impl(c, secret_chat_id, get_secret_chat_database_value(c));
    return;
  }
  if (load_secret_chat_from_database_queries_.count(secret_chat_id) != 0) {
    return;
  }

  load_secret_chat_from_database_impl(secret_chat_id, Auto());
}

void UserManager::save_secret_chat_to_database_impl(SecretChat *c, SecretChatId secret_chat_id, string value) {
  CHECK(c != nullptr);
  CHECK(load_secret_chat_from_database_queries_.count(secret_chat_id) == 0);
  CHECK(!c->is_being_saved);
  c->is_being_saved = true;
  c->is_saved = true;
  LOG(INFO) << "Trying to save to database " << secret_chat_id;
  G()->td_db()->get_sqlite_pmc()->set(get_secret_chat_database_key(secret_chat_id), std::move(value),
                                      PromiseCreator::lambda([secret_chat_id](Result<> result) {
                                        send_closure(G()->user_manager(), &UserManager::on_save_secret_chat_to_database,
                                                     secret_chat_id, result.is_ok());
                                      }));
}

void UserManager::on_save_secret_chat_to_database(SecretChatId secret_chat_id, bool success) {
  if (G()->close_flag()) {
    return;
  }

  SecretChat *c = get_secret_chat(secret_chat_id);
  CHECK(c != nullptr);
  CHECK(c->is_being_saved);
  CHECK(load_secret_chat_from_database_queries_.count(secret_chat_id) == 0);
  c->is_being_saved = false;

  if (!success) {
    LOG(ERROR) << "Failed to save " << secret_chat_id << " to database";
    c->is_saved = false;
  } else {
    LOG(INFO) << "Successfully saved " << secret_chat_id << " to database";
  }
  if (c->is_saved) {
    if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
  } else {
    save_secret_chat(c, secret_chat_id, c->log_event_id != 0);
  }
}

void UserManager::load_secret_chat_from_database(SecretChat *c, SecretChatId secret_chat_id, Promise<Unit> promise) {
  if (loaded_from_database_secret_chats_.count(secret_chat_id)) {
    promise.set_value(Unit());
    return;
  }

  CHECK(c == nullptr || !c->is_being_saved);
  load_secret_chat_from_database_impl(secret_chat_id, std::move(promise));
}

void UserManager::load_secret_chat_from_database_impl(SecretChatId secret_chat_id, Promise<Unit> promise) {
  LOG(INFO) << "Load " << secret_chat_id << " from database";
  auto &load_secret_chat_queries = load_secret_chat_from_database_queries_[secret_chat_id];
  load_secret_chat_queries.push_back(std::move(promise));
  if (load_secret_chat_queries.size() == 1u) {
    G()->td_db()->get_sqlite_pmc()->get(
        get_secret_chat_database_key(secret_chat_id), PromiseCreator::lambda([secret_chat_id](string value) {
          send_closure(G()->user_manager(), &UserManager::on_load_secret_chat_from_database, secret_chat_id,
                       std::move(value), false);
        }));
  }
}

void UserManager::on_load_secret_chat_from_database(SecretChatId secret_chat_id, string value, bool force) {
  if (G()->close_flag() && !force) {
    // the secret chat is in Binlog and will be saved after restart
    return;
  }

  CHECK(secret_chat_id.is_valid());
  if (!loaded_from_database_secret_chats_.insert(secret_chat_id).second) {
    return;
  }

  auto it = load_secret_chat_from_database_queries_.find(secret_chat_id);
  vector<Promise<Unit>> promises;
  if (it != load_secret_chat_from_database_queries_.end()) {
    promises = std::move(it->second);
    CHECK(!promises.empty());
    load_secret_chat_from_database_queries_.erase(it);
  }

  LOG(INFO) << "Successfully loaded " << secret_chat_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_secret_chat_database_key(secret_chat_id), Auto());
  //  return;

  SecretChat *c = get_secret_chat(secret_chat_id);
  if (c == nullptr) {
    if (!value.empty()) {
      c = add_secret_chat(secret_chat_id);

      if (log_event_parse(*c, value).is_error()) {
        LOG(ERROR) << "Failed to load " << secret_chat_id << " from database";
        secret_chats_.erase(secret_chat_id);
      } else {
        c->is_saved = true;
        update_secret_chat(c, secret_chat_id, true, true);
      }
    }
  } else {
    CHECK(!c->is_saved);  // secret chat can't be saved before load completes
    CHECK(!c->is_being_saved);
    auto new_value = get_secret_chat_database_value(c);
    if (value != new_value) {
      save_secret_chat_to_database_impl(c, secret_chat_id, std::move(new_value));
    } else if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
  }

  // TODO load users asynchronously
  if (c != nullptr && !have_user_force(c->user_id, "on_load_secret_chat_from_database")) {
    LOG(ERROR) << "Can't find " << c->user_id << " from " << secret_chat_id;
  }

  set_promises(promises);
}

void UserManager::create_new_secret_chat(UserId user_id, Promise<td_api::object_ptr<td_api::chat>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_input_user(user_id));
  if (input_user->get_id() != telegram_api::inputUser::ID) {
    return promise.set_error(Status::Error(400, "Can't create secret chat with the user"));
  }
  auto user = static_cast<const telegram_api::inputUser *>(input_user.get());

  send_closure(
      G()->secret_chats_manager(), &SecretChatsManager::create_chat, UserId(user->user_id_), user->access_hash_,
      PromiseCreator::lambda(
          [actor_id = actor_id(this), promise = std::move(promise)](Result<SecretChatId> r_secret_chat_id) mutable {
            if (r_secret_chat_id.is_error()) {
              return promise.set_error(r_secret_chat_id.move_as_error());
            }
            send_closure(actor_id, &UserManager::on_create_new_secret_chat, r_secret_chat_id.ok(), std::move(promise));
          }));
}

void UserManager::on_create_new_secret_chat(SecretChatId secret_chat_id,
                                            Promise<td_api::object_ptr<td_api::chat>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(secret_chat_id.is_valid());
  DialogId dialog_id(secret_chat_id);
  td_->dialog_manager_->force_create_dialog(dialog_id, "on_create_new_secret_chat");
  promise.set_value(td_->messages_manager_->get_chat_object(dialog_id, "on_create_new_secret_chat"));
}

void UserManager::update_user(User *u, UserId user_id, bool from_binlog, bool from_database) {
  CHECK(u != nullptr);

  if (u->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of " << user_id;
  }
  u->is_being_updated = true;
  SCOPE_EXIT {
    u->is_being_updated = false;
  };

  if (user_id == get_my_id()) {
    if (td_->option_manager_->get_option_boolean("is_premium") != u->is_premium) {
      td_->option_manager_->set_option_boolean("is_premium", u->is_premium);
      send_closure(td_->config_manager_, &ConfigManager::request_config, true);
      if (!td_->auth_manager_->is_bot()) {
        td_->reaction_manager_->reload_reaction_list(ReactionListType::Top, "update_user is_premium");
        td_->messages_manager_->update_is_translatable(u->is_premium);
      }
    }
  }
  if (u->is_name_changed || u->is_username_changed || u->is_is_contact_changed) {
    update_contacts_hints(u, user_id, from_database);
    u->is_username_changed = false;
  }
  if (u->is_is_contact_changed) {
    td_->messages_manager_->on_dialog_user_is_contact_updated(DialogId(user_id), u->is_contact);
    send_closure_later(td_->story_manager_actor_, &StoryManager::on_dialog_active_stories_order_updated,
                       DialogId(user_id), "update_user is_contact");
    if (is_user_contact(u, user_id, false)) {
      auto user_full = get_user_full(user_id);
      if (user_full != nullptr && user_full->need_phone_number_privacy_exception) {
        on_update_user_full_need_phone_number_privacy_exception(user_full, user_id, false);
        update_user_full(user_full, user_id, "update_user");
      }
    }
    u->is_is_contact_changed = false;
  }
  if (u->is_is_mutual_contact_changed) {
    if (!from_database && u->is_update_user_sent) {
      send_closure_later(td_->story_manager_actor_, &StoryManager::reload_dialog_expiring_stories, DialogId(user_id));
    }
    u->is_is_mutual_contact_changed = false;
  }
  if (u->is_is_deleted_changed) {
    td_->messages_manager_->on_dialog_user_is_deleted_updated(DialogId(user_id), u->is_deleted);
    if (u->is_deleted) {
      auto user_full = get_user_full(user_id);  // must not load user_full from database before sending updateUser
      if (user_full != nullptr) {
        u->is_full_info_changed = false;
        drop_user_full(user_id);
      }
    }
    u->is_is_deleted_changed = false;
  }
  if (u->is_is_premium_changed) {
    send_closure_later(td_->story_manager_actor_, &StoryManager::on_dialog_active_stories_order_updated,
                       DialogId(user_id), "update_user is_premium");
    u->is_is_premium_changed = false;
  }
  if (u->is_name_changed) {
    auto messages_manager = td_->messages_manager_.get();
    messages_manager->on_dialog_title_updated(DialogId(user_id));
    for_each_secret_chat_with_user(user_id, [messages_manager](SecretChatId secret_chat_id) {
      messages_manager->on_dialog_title_updated(DialogId(secret_chat_id));
    });
    u->is_name_changed = false;
  }
  if (u->is_photo_changed) {
    auto messages_manager = td_->messages_manager_.get();
    messages_manager->on_dialog_photo_updated(DialogId(user_id));
    for_each_secret_chat_with_user(user_id, [messages_manager](SecretChatId secret_chat_id) {
      messages_manager->on_dialog_photo_updated(DialogId(secret_chat_id));
    });
    u->is_photo_changed = false;
  }
  if (u->is_accent_color_changed) {
    auto messages_manager = td_->messages_manager_.get();
    messages_manager->on_dialog_accent_colors_updated(DialogId(user_id));
    for_each_secret_chat_with_user(user_id, [messages_manager](SecretChatId secret_chat_id) {
      messages_manager->on_dialog_accent_colors_updated(DialogId(secret_chat_id));
    });
    u->is_accent_color_changed = false;
  }
  if (u->is_phone_number_changed) {
    if (!u->phone_number.empty() && !td_->auth_manager_->is_bot()) {
      resolved_phone_numbers_[u->phone_number] = user_id;
    }
    u->is_phone_number_changed = false;
  }
  auto unix_time = G()->unix_time();
  if (u->is_status_changed && user_id != get_my_id()) {
    auto left_time = get_user_was_online(u, user_id, unix_time) - G()->server_time();
    if (left_time >= 0 && left_time < 30 * 86400) {
      left_time += 2.0;  // to guarantee expiration
      LOG(DEBUG) << "Set online timeout for " << user_id << " in " << left_time << " seconds";
      user_online_timeout_.set_timeout_in(user_id.get(), left_time);
    } else {
      LOG(DEBUG) << "Cancel online timeout for " << user_id;
      user_online_timeout_.cancel_timeout(user_id.get());
    }
  }
  if (u->is_stories_hidden_changed) {
    send_closure_later(td_->story_manager_actor_, &StoryManager::on_dialog_active_stories_order_updated,
                       DialogId(user_id), "update_user stories_hidden");
    u->is_stories_hidden_changed = false;
  }
  if (!td_->auth_manager_->is_bot()) {
    if (u->restriction_reasons.empty()) {
      restricted_user_ids_.erase(user_id);
    } else {
      restricted_user_ids_.insert(user_id);
    }
  }

  auto effective_emoji_status = EmojiStatus::get_effective_emoji_status(u->emoji_status, u->is_premium, unix_time);
  if (effective_emoji_status != u->last_sent_emoji_status) {
    if (u->last_sent_emoji_status != nullptr) {
      user_emoji_status_timeout_.cancel_timeout(user_id.get());
    }
    u->last_sent_emoji_status = std::move(effective_emoji_status);
    if (u->last_sent_emoji_status != nullptr) {
      auto until_date = u->last_sent_emoji_status->get_until_date();
      auto left_time = until_date - unix_time;
      if (left_time >= 0 && left_time < 30 * 86400) {
        user_emoji_status_timeout_.set_timeout_in(user_id.get(), left_time);
      }
    }
    u->is_changed = true;

    auto messages_manager = td_->messages_manager_.get();
    messages_manager->on_dialog_emoji_status_updated(DialogId(user_id));
    for_each_secret_chat_with_user(user_id, [messages_manager](SecretChatId secret_chat_id) {
      messages_manager->on_dialog_emoji_status_updated(DialogId(secret_chat_id));
    });
    u->is_emoji_status_changed = false;
  } else if (u->is_emoji_status_changed) {
    LOG(DEBUG) << "Emoji status for " << user_id << " has changed";
    u->need_save_to_database = true;
    u->is_emoji_status_changed = false;
  }

  if (u->is_deleted) {
    td_->inline_queries_manager_->remove_recent_inline_bot(user_id, Promise<>());
  }
  if (from_binlog || from_database) {
    td_->dialog_manager_->on_dialog_usernames_received(DialogId(user_id), u->usernames, true);
  }

  LOG(DEBUG) << "Update " << user_id << ": need_save_to_database = " << u->need_save_to_database
             << ", is_changed = " << u->is_changed << ", is_status_changed = " << u->is_status_changed
             << ", from_binlog = " << from_binlog << ", from_database = " << from_database;
  u->need_save_to_database |= u->is_changed;
  if (u->need_save_to_database) {
    if (!from_database) {
      u->is_saved = false;
    }
    u->need_save_to_database = false;
  }
  if (u->is_changed) {
    send_closure(G()->td(), &Td::send_update, get_update_user_object(user_id, u));
    u->is_changed = false;
    u->is_status_changed = false;
    u->is_update_user_sent = true;
  }
  if (u->is_status_changed) {
    if (!from_database) {
      u->is_status_saved = false;
    }
    CHECK(u->is_update_user_sent);
    send_closure(
        G()->td(), &Td::send_update,
        td_api::make_object<td_api::updateUserStatus>(user_id.get(), get_user_status_object(user_id, u, unix_time)));
    u->is_status_changed = false;
  }
  if (u->is_online_status_changed) {
    td_->dialog_participant_manager_->update_user_online_member_count(user_id);
    u->is_online_status_changed = false;
  }

  if (!from_database) {
    save_user(u, user_id, from_binlog);
  }

  if (u->cache_version != User::CACHE_VERSION && !u->is_repaired &&
      have_input_peer_user(u, user_id, AccessRights::Read) && !G()->close_flag()) {
    u->is_repaired = true;

    LOG(INFO) << "Repairing cache of " << user_id;
    reload_user(user_id, Promise<Unit>(), "update_user");
  }

  if (u->is_full_info_changed) {
    u->is_full_info_changed = false;
    auto user_full = get_user_full(user_id);
    if (user_full != nullptr) {
      user_full->need_send_update = true;
      update_user_full(user_full, user_id, "update_user is_full_info_changed");
      reload_user_full(user_id, Promise<Unit>(), "update_user");
    }
  }
}

void UserManager::update_secret_chat(SecretChat *c, SecretChatId secret_chat_id, bool from_binlog, bool from_database) {
  CHECK(c != nullptr);

  if (c->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of " << secret_chat_id;
  }
  c->is_being_updated = true;
  SCOPE_EXIT {
    c->is_being_updated = false;
  };

  LOG(DEBUG) << "Update " << secret_chat_id << ": need_save_to_database = " << c->need_save_to_database
             << ", is_changed = " << c->is_changed;
  c->need_save_to_database |= c->is_changed;
  if (c->need_save_to_database) {
    if (!from_database) {
      c->is_saved = false;
    }
    c->need_save_to_database = false;

    DialogId dialog_id(secret_chat_id);
    send_closure_later(G()->messages_manager(), &MessagesManager::force_create_dialog, dialog_id, "update secret chat",
                       true, true);
    if (c->is_state_changed) {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_update_secret_chat_state, secret_chat_id,
                         c->state);
      c->is_state_changed = false;
    }
    if (c->is_ttl_changed) {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_message_ttl,
                         DialogId(secret_chat_id), MessageTtl(c->ttl));
      c->is_ttl_changed = false;
    }
  }
  if (c->is_changed) {
    send_closure(G()->td(), &Td::send_update, get_update_secret_chat_object(secret_chat_id, c));
    c->is_changed = false;
  }

  if (!from_database) {
    save_secret_chat(c, secret_chat_id, from_binlog);
  }
}

void UserManager::update_user_full(UserFull *user_full, UserId user_id, const char *source, bool from_database) {
  CHECK(user_full != nullptr);

  if (user_full->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of full " << user_id << " from " << source;
  }
  user_full->is_being_updated = true;
  SCOPE_EXIT {
    user_full->is_being_updated = false;
  };

  unavailable_user_fulls_.erase(user_id);  // don't needed anymore
  if (user_full->is_common_chat_count_changed) {
    td_->common_dialog_manager_->drop_common_dialogs_cache(user_id);
    user_full->is_common_chat_count_changed = false;
  }
  if (true) {
    vector<FileId> file_ids;
    if (!user_full->personal_photo.is_empty()) {
      append(file_ids, photo_get_file_ids(user_full->personal_photo));
    }
    if (!user_full->fallback_photo.is_empty()) {
      append(file_ids, photo_get_file_ids(user_full->fallback_photo));
    }
    if (user_full->bot_info != nullptr) {
      if (!user_full->bot_info->description_photo.is_empty()) {
        append(file_ids, photo_get_file_ids(user_full->bot_info->description_photo));
      }
      if (user_full->bot_info->description_animation_file_id.is_valid()) {
        file_ids.push_back(user_full->bot_info->description_animation_file_id);
      }
    }
    if (user_full->business_info != nullptr) {
      append(file_ids, user_full->business_info->get_file_ids(td_));
    }
    if (user_full->registered_file_ids != file_ids) {
      auto &file_source_id = user_full->file_source_id;
      if (!file_source_id.is_valid()) {
        file_source_id = user_full_file_source_ids_.get(user_id);
        if (file_source_id.is_valid()) {
          VLOG(file_references) << "Move " << file_source_id << " inside of " << user_id;
          user_full_file_source_ids_.erase(user_id);
        } else {
          VLOG(file_references) << "Need to create new file source for full " << user_id;
          file_source_id = td_->file_reference_manager_->create_user_full_file_source(user_id);
        }
      }

      td_->file_manager_->change_files_source(file_source_id, user_full->registered_file_ids, file_ids,
                                              "update_user_full");
      user_full->registered_file_ids = std::move(file_ids);
    }
  }

  user_full->need_send_update |= user_full->is_changed;
  user_full->need_save_to_database |= user_full->is_changed;
  user_full->is_changed = false;
  if (user_full->need_send_update || user_full->need_save_to_database) {
    LOG(INFO) << "Update full " << user_id << " from " << source;
  }
  if (user_full->need_send_update) {
    {
      auto u = get_user(user_id);
      CHECK(u == nullptr || u->is_update_user_sent);
    }
    if (!user_full->is_update_user_full_sent) {
      LOG(ERROR) << "Send partial updateUserFullInfo for " << user_id << " from " << source;
      user_full->is_update_user_full_sent = true;
    }
    send_closure(G()->td(), &Td::send_update,
                 td_api::make_object<td_api::updateUserFullInfo>(get_user_id_object(user_id, "updateUserFullInfo"),
                                                                 get_user_full_info_object(user_id, user_full)));
    user_full->need_send_update = false;

    if (user_id == get_my_id() && !user_full->birthdate.is_empty() && !td_->auth_manager_->is_bot()) {
      dismiss_suggested_action(SuggestedAction{SuggestedAction::Type::BirthdaySetup}, Promise<Unit>());
    }
  }
  if (user_full->need_save_to_database) {
    if (!from_database) {
      save_user_full(user_full, user_id);
    }
    user_full->need_save_to_database = false;
  }
}

td_api::object_ptr<td_api::UserStatus> UserManager::get_user_status_object(UserId user_id, const User *u,
                                                                           int32 unix_time) const {
  if (u->is_bot) {
    return td_api::make_object<td_api::userStatusOnline>(std::numeric_limits<int32>::max());
  }

  int32 was_online = get_user_was_online(u, user_id, unix_time);
  switch (was_online) {
    case -6:
    case -3:
      return td_api::make_object<td_api::userStatusLastMonth>(was_online == -6);
    case -5:
    case -2:
      return td_api::make_object<td_api::userStatusLastWeek>(was_online == -5);
    case -4:
    case -1:
      return td_api::make_object<td_api::userStatusRecently>(was_online == -4);
    case 0:
      return td_api::make_object<td_api::userStatusEmpty>();
    default: {
      int32 time = G()->unix_time();
      if (was_online > time) {
        return td_api::make_object<td_api::userStatusOnline>(was_online);
      } else {
        return td_api::make_object<td_api::userStatusOffline>(was_online);
      }
    }
  }
}

bool UserManager::get_user_has_unread_stories(const User *u) {
  CHECK(u != nullptr);
  return u->max_active_story_id.get() > u->max_read_story_id.get();
}

td_api::object_ptr<td_api::updateUser> UserManager::get_update_user_object(UserId user_id, const User *u) const {
  if (u == nullptr) {
    return get_update_unknown_user_object(user_id);
  }
  return td_api::make_object<td_api::updateUser>(get_user_object(user_id, u));
}

td_api::object_ptr<td_api::updateUser> UserManager::get_update_unknown_user_object(UserId user_id) const {
  auto have_access = user_id == get_my_id() || user_messages_.count(user_id) != 0;
  return td_api::make_object<td_api::updateUser>(td_api::make_object<td_api::user>(
      user_id.get(), "", "", nullptr, "", td_api::make_object<td_api::userStatusEmpty>(), nullptr,
      td_->theme_manager_->get_accent_color_id_object(AccentColorId(user_id)), 0, -1, 0, nullptr, false, false, false,
      nullptr, false, false, "", false, false, false, 0, have_access, td_api::make_object<td_api::userTypeUnknown>(),
      "", false));
}

int64 UserManager::get_user_id_object(UserId user_id, const char *source) const {
  if (user_id.is_valid() && get_user(user_id) == nullptr && unknown_users_.count(user_id) == 0) {
    if (source != nullptr) {
      LOG(ERROR) << "Have no information about " << user_id << " from " << source;
    }
    unknown_users_.insert(user_id);
    send_closure(G()->td(), &Td::send_update, get_update_unknown_user_object(user_id));

    if (user_id == my_id_) {
      send_get_me_query(td_, Promise<Unit>());
    }
  }
  return user_id.get();
}

void UserManager::get_user_id_object_async(UserId user_id, Promise<int64> &&promise) {
  promise.set_value(get_user_id_object(user_id, "get_user_id_object_async"));
}

td_api::object_ptr<td_api::user> UserManager::get_user_object(UserId user_id) const {
  return get_user_object(user_id, get_user(user_id));
}

td_api::object_ptr<td_api::user> UserManager::get_user_object(UserId user_id, const User *u) const {
  if (u == nullptr) {
    return nullptr;
  }
  td_api::object_ptr<td_api::UserType> type;
  if (u->is_deleted) {
    type = td_api::make_object<td_api::userTypeDeleted>();
  } else if (u->is_bot) {
    type = td_api::make_object<td_api::userTypeBot>(
        u->can_be_edited_bot, u->can_join_groups, u->can_read_all_group_messages, u->has_main_app, u->is_inline_bot,
        u->inline_query_placeholder, u->need_location_bot, u->is_business_bot, u->can_be_added_to_attach_menu,
        u->bot_active_users);
  } else {
    type = td_api::make_object<td_api::userTypeRegular>();
  }

  auto emoji_status = EmojiStatus::get_emoji_status_object(u->last_sent_emoji_status);
  auto verification_status =
      get_verification_status_object(td_, u->is_verified, u->is_scam, u->is_fake, u->bot_verification_icon);
  auto have_access = user_id == get_my_id() || have_input_peer_user(u, user_id, AccessRights::Know);
  auto restricts_new_chats = u->contact_require_premium && !u->is_mutual_contact;
  return td_api::make_object<td_api::user>(
      user_id.get(), u->first_name, u->last_name, u->usernames.get_usernames_object(), u->phone_number,
      get_user_status_object(user_id, u, G()->unix_time()),
      get_profile_photo_object(td_->file_manager_.get(), u->photo),
      td_->theme_manager_->get_accent_color_id_object(u->accent_color_id, AccentColorId(user_id)),
      u->background_custom_emoji_id.get(),
      td_->theme_manager_->get_profile_accent_color_id_object(u->profile_accent_color_id),
      u->profile_background_custom_emoji_id.get(), std::move(emoji_status), u->is_contact, u->is_mutual_contact,
      u->is_close_friend, std::move(verification_status), u->is_premium, u->is_support,
      get_restriction_reason_description(u->restriction_reasons), u->max_active_story_id.is_valid(),
      get_user_has_unread_stories(u), restricts_new_chats, u->paid_message_star_count, have_access, std::move(type),
      u->language_code, u->attach_menu_enabled);
}

vector<int64> UserManager::get_user_ids_object(const vector<UserId> &user_ids, const char *source) const {
  return transform(user_ids, [this, source](UserId user_id) { return get_user_id_object(user_id, source); });
}

td_api::object_ptr<td_api::users> UserManager::get_users_object(int32 total_count,
                                                                const vector<UserId> &user_ids) const {
  if (total_count == -1) {
    total_count = narrow_cast<int32>(user_ids.size());
  }
  return td_api::make_object<td_api::users>(total_count, get_user_ids_object(user_ids, "get_users_object"));
}

td_api::object_ptr<td_api::userFullInfo> UserManager::get_user_full_info_object(UserId user_id) const {
  return get_user_full_info_object(user_id, get_user_full(user_id));
}

td_api::object_ptr<td_api::userFullInfo> UserManager::get_user_full_info_object(UserId user_id,
                                                                                const UserFull *user_full) const {
  CHECK(user_full != nullptr);
  td_api::object_ptr<td_api::botInfo> bot_info;
  const User *u = get_user(user_id);
  bool is_bot = is_user_bot(u);
  bool is_premium = is_user_premium(u);
  td_api::object_ptr<td_api::formattedText> bio_object;
  if (is_bot) {
    if (user_full->bot_info == nullptr) {
      bot_info = td_api::make_object<td_api::botInfo>(
          user_full->about, string(), nullptr, nullptr, nullptr, Auto(), string(), nullptr, nullptr, nullptr, -1, -1,
          -1, -1, nullptr, user_full->can_view_revenue, user_full->can_manage_emoji_status,
          user_full->has_preview_medias, nullptr, nullptr, nullptr, nullptr);
    } else {
      const auto *user_bot_info = user_full->bot_info.get();
      auto menu_button = get_bot_menu_button_object(td_, user_bot_info->menu_button.get());
      auto commands =
          transform(user_bot_info->commands, [](const auto &command) { return command.get_bot_command_object(); });
      bot_info = td_api::make_object<td_api::botInfo>(
          user_full->about, user_bot_info->description,
          get_photo_object(td_->file_manager_.get(), user_bot_info->description_photo),
          td_->animations_manager_->get_animation_object(user_bot_info->description_animation_file_id),
          std::move(menu_button), std::move(commands), user_bot_info->privacy_policy_url,
          user_bot_info->group_administrator_rights == AdministratorRights()
              ? nullptr
              : user_bot_info->group_administrator_rights.get_chat_administrator_rights_object(),
          user_bot_info->broadcast_administrator_rights == AdministratorRights()
              ? nullptr
              : user_bot_info->broadcast_administrator_rights.get_chat_administrator_rights_object(),
          user_bot_info->referral_program_info.get_affiliate_program_info_object(), user_bot_info->background_color,
          user_bot_info->background_dark_color, user_bot_info->header_color, user_bot_info->header_dark_color,
          user_bot_info->verifier_settings == nullptr
              ? nullptr
              : user_bot_info->verifier_settings->get_bot_verification_parameters_object(td_),
          user_full->can_view_revenue, user_full->can_manage_emoji_status, user_full->has_preview_medias, nullptr,
          nullptr, nullptr, nullptr);
    }
    if (u != nullptr && u->can_be_edited_bot && u->usernames.has_editable_username()) {
      auto bot_username = u->usernames.get_editable_username();
      bot_info->edit_commands_link_ = td_api::make_object<td_api::internalLinkTypeBotStart>(
          "botfather", PSTRING() << bot_username << "-commands", true);
      bot_info->edit_description_link_ = td_api::make_object<td_api::internalLinkTypeBotStart>(
          "botfather", PSTRING() << bot_username << "-intro", true);
      bot_info->edit_description_media_link_ = td_api::make_object<td_api::internalLinkTypeBotStart>(
          "botfather", PSTRING() << bot_username << "-intropic", true);
      bot_info->edit_settings_link_ =
          td_api::make_object<td_api::internalLinkTypeBotStart>("botfather", bot_username, true);
    }
  } else {
    FormattedText bio;
    bio.text = user_full->about;
    bio.entities = find_entities(bio.text, true, true);
    if (!is_premium) {
      td::remove_if(bio.entities, [&](const MessageEntity &entity) {
        if (entity.type == MessageEntity::Type::EmailAddress) {
          return true;
        }
        if (entity.type == MessageEntity::Type::Url &&
            !LinkManager::is_internal_link(utf8_utf16_substr(bio.text, entity.offset, entity.length))) {
          return true;
        }
        return false;
      });
    }
    bio_object = get_formatted_text_object(this, bio, true, 0);
  }
  auto voice_messages_forbidden = is_premium ? user_full->voice_messages_forbidden : false;
  auto block_list_id = BlockListId(user_full->is_blocked, user_full->is_blocked_for_stories);
  auto business_info = is_premium && user_full->business_info != nullptr
                           ? user_full->business_info->get_business_info_object(td_)
                           : nullptr;
  int64 personal_chat_id = 0;
  if (user_full->personal_channel_id.is_valid()) {
    DialogId dialog_id(user_full->personal_channel_id);
    td_->dialog_manager_->force_create_dialog(dialog_id, "get_user_full_info_object", true);
    personal_chat_id = td_->dialog_manager_->get_chat_id_object(dialog_id, "get_user_full_info_object");
  }
  auto bot_verification =
      user_full->bot_verification == nullptr ? nullptr : user_full->bot_verification->get_bot_verification_object(td_);
  return td_api::make_object<td_api::userFullInfo>(
      get_chat_photo_object(td_->file_manager_.get(), user_full->personal_photo),
      get_chat_photo_object(td_->file_manager_.get(), user_full->photo),
      get_chat_photo_object(td_->file_manager_.get(), user_full->fallback_photo), block_list_id.get_block_list_object(),
      user_full->can_be_called, user_full->supports_video_calls, user_full->has_private_calls,
      !user_full->private_forward_name.empty(), voice_messages_forbidden, user_full->has_pinned_stories,
      user_full->sponsored_enabled, user_full->need_phone_number_privacy_exception, user_full->wallpaper_overridden,
      std::move(bio_object), user_full->birthdate.get_birthdate_object(), personal_chat_id, user_full->gift_count,
      user_full->common_chat_count, user_full->charge_paid_message_stars, user_full->send_paid_message_stars,
      std::move(bot_verification), std::move(business_info), std::move(bot_info));
}

td_api::object_ptr<td_api::updateContactCloseBirthdays> UserManager::get_update_contact_close_birthdays() const {
  return td_api::make_object<td_api::updateContactCloseBirthdays>(
      transform(contact_birthdates_.users_, [this](const std::pair<UserId, Birthdate> &user) {
        return td_api::make_object<td_api::closeBirthdayUser>(get_user_id_object(user.first, "closeBirthdayUser"),
                                                              user.second.get_birthdate_object());
      }));
}

td_api::object_ptr<td_api::SecretChatState> UserManager::get_secret_chat_state_object(SecretChatState state) {
  switch (state) {
    case SecretChatState::Waiting:
      return td_api::make_object<td_api::secretChatStatePending>();
    case SecretChatState::Active:
      return td_api::make_object<td_api::secretChatStateReady>();
    case SecretChatState::Closed:
    case SecretChatState::Unknown:
      return td_api::make_object<td_api::secretChatStateClosed>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::updateSecretChat> UserManager::get_update_secret_chat_object(SecretChatId secret_chat_id,
                                                                                        const SecretChat *secret_chat) {
  if (secret_chat == nullptr) {
    return get_update_unknown_secret_chat_object(secret_chat_id);
  }
  return td_api::make_object<td_api::updateSecretChat>(get_secret_chat_object(secret_chat_id, secret_chat));
}

td_api::object_ptr<td_api::updateSecretChat> UserManager::get_update_unknown_secret_chat_object(
    SecretChatId secret_chat_id) {
  return td_api::make_object<td_api::updateSecretChat>(td_api::make_object<td_api::secretChat>(
      secret_chat_id.get(), 0, get_secret_chat_state_object(SecretChatState::Unknown), false, string(), 0));
}

int32 UserManager::get_secret_chat_id_object(SecretChatId secret_chat_id, const char *source) const {
  if (secret_chat_id.is_valid() && get_secret_chat(secret_chat_id) == nullptr &&
      unknown_secret_chats_.count(secret_chat_id) == 0) {
    LOG(ERROR) << "Have no information about " << secret_chat_id << " from " << source;
    unknown_secret_chats_.insert(secret_chat_id);
    send_closure(G()->td(), &Td::send_update, get_update_unknown_secret_chat_object(secret_chat_id));
  }
  return secret_chat_id.get();
}

td_api::object_ptr<td_api::secretChat> UserManager::get_secret_chat_object(SecretChatId secret_chat_id) {
  return get_secret_chat_object(secret_chat_id, get_secret_chat(secret_chat_id));
}

td_api::object_ptr<td_api::secretChat> UserManager::get_secret_chat_object(SecretChatId secret_chat_id,
                                                                           const SecretChat *secret_chat) {
  if (secret_chat == nullptr) {
    return nullptr;
  }
  get_user_force(secret_chat->user_id, "get_secret_chat_object");
  return get_secret_chat_object_const(secret_chat_id, secret_chat);
}

td_api::object_ptr<td_api::secretChat> UserManager::get_secret_chat_object_const(SecretChatId secret_chat_id,
                                                                                 const SecretChat *secret_chat) const {
  return td_api::make_object<td_api::secretChat>(secret_chat_id.get(),
                                                 get_user_id_object(secret_chat->user_id, "secretChat"),
                                                 get_secret_chat_state_object(secret_chat->state),
                                                 secret_chat->is_outbound, secret_chat->key_hash, secret_chat->layer);
}

void UserManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  for (auto user_id : unknown_users_) {
    if (!have_min_user(user_id)) {
      updates.push_back(get_update_unknown_user_object(user_id));
    }
  }
  for (auto secret_chat_id : unknown_secret_chats_) {
    if (!have_secret_chat(secret_chat_id)) {
      updates.push_back(get_update_unknown_secret_chat_object(secret_chat_id));
    }
  }

  users_.foreach([&](const UserId &user_id, const unique_ptr<User> &user) {
    updates.push_back(get_update_user_object(user_id, user.get()));
  });
  // secret chat objects contain user_id, so they must be sent after users
  secret_chats_.foreach([&](const SecretChatId &secret_chat_id, const unique_ptr<SecretChat> &secret_chat) {
    updates.push_back(
        td_api::make_object<td_api::updateSecretChat>(get_secret_chat_object_const(secret_chat_id, secret_chat.get())));
  });

  users_full_.foreach([&](const UserId &user_id, const unique_ptr<UserFull> &user_full) {
    updates.push_back(td_api::make_object<td_api::updateUserFullInfo>(
        user_id.get(), get_user_full_info_object(user_id, user_full.get())));
  });

  if (!contact_birthdates_.users_.empty()) {
    updates.push_back(get_update_contact_close_birthdays());
  }
}

}  // namespace td
