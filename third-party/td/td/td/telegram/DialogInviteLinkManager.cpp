//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogInviteLinkManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogInviteLink.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/VerificationStatus.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"

namespace td {

class CheckChatInviteQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  string invite_link_;

 public:
  explicit CheckChatInviteQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &invite_link) {
    invite_link_ = invite_link;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_checkChatInvite(LinkManager::get_dialog_invite_link_hash(invite_link_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_checkChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CheckChatInviteQuery: " << to_string(ptr);

    td_->dialog_invite_link_manager_->on_get_dialog_invite_link_info(invite_link_, std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ImportChatInviteQuery final : public Td::ResultHandler {
  Promise<DialogId> promise_;

  string invite_link_;

 public:
  explicit ImportChatInviteQuery(Promise<DialogId> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &invite_link) {
    invite_link_ = invite_link;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_importChatInvite(LinkManager::get_dialog_invite_link_hash(invite_link_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_importChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ImportChatInviteQuery: " << to_string(ptr);

    auto dialog_ids = UpdatesManager::get_chat_dialog_ids(ptr.get());
    if (dialog_ids.size() != 1u) {
      LOG(ERROR) << "Receive wrong result for ImportChatInviteQuery: " << to_string(ptr);
      return on_error(Status::Error(500, "Internal Server Error: failed to join chat via invite link"));
    }
    auto dialog_id = dialog_ids[0];

    td_->dialog_invite_link_manager_->invalidate_invite_link_info(invite_link_);
    td_->updates_manager_->on_get_updates(
        std::move(ptr), PromiseCreator::lambda([promise = std::move(promise_), dialog_id](Unit) mutable {
          promise.set_value(std::move(dialog_id));
        }));
  }

  void on_error(Status status) final {
    td_->dialog_invite_link_manager_->invalidate_invite_link_info(invite_link_);
    promise_.set_error(std::move(status));
  }
};

class ExportChatInviteQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLink>> promise_;
  DialogId dialog_id_;

 public:
  explicit ExportChatInviteQuery(Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &title, int32 expire_date, int32 usage_limit, bool creates_join_request,
            StarSubscriptionPricing subscription_pricing, bool is_permanent) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (expire_date > 0) {
      flags |= telegram_api::messages_exportChatInvite::EXPIRE_DATE_MASK;
    }
    if (usage_limit > 0) {
      flags |= telegram_api::messages_exportChatInvite::USAGE_LIMIT_MASK;
    }
    if (creates_join_request) {
      flags |= telegram_api::messages_exportChatInvite::REQUEST_NEEDED_MASK;
    }
    if (is_permanent) {
      flags |= telegram_api::messages_exportChatInvite::LEGACY_REVOKE_PERMANENT_MASK;
    }
    if (!title.empty()) {
      flags |= telegram_api::messages_exportChatInvite::TITLE_MASK;
    }
    if (!subscription_pricing.is_empty()) {
      flags |= telegram_api::messages_exportChatInvite::SUBSCRIPTION_PRICING_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_exportChatInvite(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), expire_date, usage_limit, title,
        subscription_pricing.get_input_stars_subscription_pricing())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_exportChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ExportChatInviteQuery: " << to_string(ptr);

    DialogInviteLink invite_link(std::move(ptr), false, false, "ExportChatInviteQuery");
    if (!invite_link.is_valid()) {
      return on_error(Status::Error(500, "Receive invalid invite link"));
    }
    if (invite_link.get_creator_user_id() != td_->user_manager_->get_my_id()) {
      return on_error(Status::Error(500, "Receive invalid invite link creator"));
    }
    if (invite_link.is_permanent()) {
      td_->dialog_invite_link_manager_->on_get_permanent_dialog_invite_link(dialog_id_, invite_link);
    }
    promise_.set_value(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ExportChatInviteQuery");
    promise_.set_error(std::move(status));
  }
};

class EditChatInviteLinkQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLink>> promise_;
  DialogId dialog_id_;

 public:
  explicit EditChatInviteLinkQuery(Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link, const string &title, int32 expire_date, int32 usage_limit,
            bool creates_join_request, bool is_subscription) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    int32 flags = telegram_api::messages_editExportedChatInvite::TITLE_MASK;
    if (!is_subscription) {
      flags |= telegram_api::messages_editExportedChatInvite::EXPIRE_DATE_MASK |
               telegram_api::messages_editExportedChatInvite::USAGE_LIMIT_MASK |
               telegram_api::messages_editExportedChatInvite::REQUEST_NEEDED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_editExportedChatInvite(flags, false /*ignored*/, std::move(input_peer), invite_link,
                                                      expire_date, usage_limit, creates_join_request, title)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editExportedChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditChatInviteLinkQuery: " << to_string(result);

    if (result->get_id() != telegram_api::messages_exportedChatInvite::ID) {
      return on_error(Status::Error(500, "Receive unexpected response from server"));
    }

    auto invite = move_tl_object_as<telegram_api::messages_exportedChatInvite>(result);

    td_->user_manager_->on_get_users(std::move(invite->users_), "EditChatInviteLinkQuery");

    DialogInviteLink invite_link(std::move(invite->invite_), false, false, "EditChatInviteLinkQuery");
    if (!invite_link.is_valid()) {
      return on_error(Status::Error(500, "Receive invalid invite link"));
    }
    promise_.set_value(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditChatInviteLinkQuery");
    promise_.set_error(std::move(status));
  }
};

class GetExportedChatInviteQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLink>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetExportedChatInviteQuery(Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_getExportedChatInvite(std::move(input_peer), invite_link)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getExportedChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (result_ptr.ok()->get_id() != telegram_api::messages_exportedChatInvite::ID) {
      LOG(ERROR) << "Receive wrong result for GetExportedChatInviteQuery: " << to_string(result_ptr.ok());
      return on_error(Status::Error(500, "Receive unexpected response"));
    }

    auto result = move_tl_object_as<telegram_api::messages_exportedChatInvite>(result_ptr.ok_ref());
    LOG(INFO) << "Receive result for GetExportedChatInviteQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetExportedChatInviteQuery");

    DialogInviteLink invite_link(std::move(result->invite_), false, false, "GetExportedChatInviteQuery");
    if (!invite_link.is_valid()) {
      LOG(ERROR) << "Receive invalid invite link in " << dialog_id_;
      return on_error(Status::Error(500, "Receive invalid invite link"));
    }
    promise_.set_value(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetExportedChatInviteQuery");
    promise_.set_error(std::move(status));
  }
};

class GetExportedChatInvitesQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLinks>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetExportedChatInvitesQuery(Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, tl_object_ptr<telegram_api::InputUser> &&input_user, bool is_revoked, int32 offset_date,
            const string &offset_invite_link, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (!offset_invite_link.empty() || offset_date != 0) {
      flags |= telegram_api::messages_getExportedChatInvites::OFFSET_DATE_MASK;
      flags |= telegram_api::messages_getExportedChatInvites::OFFSET_LINK_MASK;
    }
    if (is_revoked) {
      flags |= telegram_api::messages_getExportedChatInvites::REVOKED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getExportedChatInvites(flags, false /*ignored*/, std::move(input_peer),
                                                      std::move(input_user), offset_date, offset_invite_link, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getExportedChatInvites>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetExportedChatInvitesQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetExportedChatInvitesQuery");

    int32 total_count = result->count_;
    if (total_count < static_cast<int32>(result->invites_.size())) {
      LOG(ERROR) << "Receive wrong total count of invite links " << total_count << " in " << dialog_id_;
      total_count = static_cast<int32>(result->invites_.size());
    }
    vector<td_api::object_ptr<td_api::chatInviteLink>> invite_links;
    for (auto &invite : result->invites_) {
      DialogInviteLink invite_link(std::move(invite), false, false, "GetExportedChatInvitesQuery");
      if (!invite_link.is_valid()) {
        LOG(ERROR) << "Receive invalid invite link in " << dialog_id_;
        total_count--;
        continue;
      }
      invite_links.push_back(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
    }
    promise_.set_value(td_api::make_object<td_api::chatInviteLinks>(total_count, std::move(invite_links)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetExportedChatInvitesQuery");
    promise_.set_error(std::move(status));
  }
};

class GetChatAdminWithInvitesQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLinkCounts>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetChatAdminWithInvitesQuery(Promise<td_api::object_ptr<td_api::chatInviteLinkCounts>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::messages_getAdminsWithInvites(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAdminsWithInvites>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChatAdminWithInvitesQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetChatAdminWithInvitesQuery");

    vector<td_api::object_ptr<td_api::chatInviteLinkCount>> invite_link_counts;
    for (auto &admin : result->admins_) {
      UserId user_id(admin->admin_id_);
      if (!user_id.is_valid()) {
        LOG(ERROR) << "Receive invalid invite link creator " << user_id << " in " << dialog_id_;
        continue;
      }
      invite_link_counts.push_back(td_api::make_object<td_api::chatInviteLinkCount>(
          td_->user_manager_->get_user_id_object(user_id, "chatInviteLinkCount"), admin->invites_count_,
          admin->revoked_invites_count_));
    }
    promise_.set_value(td_api::make_object<td_api::chatInviteLinkCounts>(std::move(invite_link_counts)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetChatAdminWithInvitesQuery");
    promise_.set_error(std::move(status));
  }
};

class GetChatInviteImportersQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLinkMembers>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetChatInviteImportersQuery(Promise<td_api::object_ptr<td_api::chatInviteLinkMembers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link, bool subscription_expired, int32 offset_date,
            UserId offset_user_id, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    auto r_input_user = td_->user_manager_->get_input_user(offset_user_id);
    if (r_input_user.is_error()) {
      r_input_user = make_tl_object<telegram_api::inputUserEmpty>();
    }

    int32 flags = telegram_api::messages_getChatInviteImporters::LINK_MASK;
    if (subscription_expired) {
      flags |= telegram_api::messages_getChatInviteImporters::SUBSCRIPTION_EXPIRED_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_getChatInviteImporters(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), invite_link, string(), offset_date,
        r_input_user.move_as_ok(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getChatInviteImporters>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChatInviteImportersQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetChatInviteImportersQuery");

    int32 total_count = result->count_;
    if (total_count < static_cast<int32>(result->importers_.size())) {
      LOG(ERROR) << "Receive wrong total count of invite link users " << total_count << " in " << dialog_id_;
      total_count = static_cast<int32>(result->importers_.size());
    }
    vector<td_api::object_ptr<td_api::chatInviteLinkMember>> invite_link_members;
    for (auto &importer : result->importers_) {
      UserId user_id(importer->user_id_);
      UserId approver_user_id(importer->approved_by_);
      if (!user_id.is_valid() || (!approver_user_id.is_valid() && approver_user_id != UserId()) ||
          importer->requested_) {
        LOG(ERROR) << "Receive invalid invite link importer: " << to_string(importer);
        total_count--;
        continue;
      }
      invite_link_members.push_back(td_api::make_object<td_api::chatInviteLinkMember>(
          td_->user_manager_->get_user_id_object(user_id, "chatInviteLinkMember"), importer->date_,
          importer->via_chatlist_, td_->user_manager_->get_user_id_object(approver_user_id, "chatInviteLinkMember")));
    }
    promise_.set_value(td_api::make_object<td_api::chatInviteLinkMembers>(total_count, std::move(invite_link_members)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetChatInviteImportersQuery");
    promise_.set_error(std::move(status));
  }
};

class RevokeChatInviteLinkQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatInviteLinks>> promise_;
  DialogId dialog_id_;

 public:
  explicit RevokeChatInviteLinkQuery(Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    int32 flags = telegram_api::messages_editExportedChatInvite::REVOKED_MASK;
    send_query(G()->net_query_creator().create(telegram_api::messages_editExportedChatInvite(
        flags, false /*ignored*/, std::move(input_peer), invite_link, 0, 0, false, string())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editExportedChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for RevokeChatInviteLinkQuery: " << to_string(result);

    vector<td_api::object_ptr<td_api::chatInviteLink>> links;
    switch (result->get_id()) {
      case telegram_api::messages_exportedChatInvite::ID: {
        auto invite = move_tl_object_as<telegram_api::messages_exportedChatInvite>(result);

        td_->user_manager_->on_get_users(std::move(invite->users_), "RevokeChatInviteLinkQuery");

        DialogInviteLink invite_link(std::move(invite->invite_), false, false, "RevokeChatInviteLinkQuery");
        if (!invite_link.is_valid()) {
          return on_error(Status::Error(500, "Receive invalid invite link"));
        }
        links.push_back(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
        break;
      }
      case telegram_api::messages_exportedChatInviteReplaced::ID: {
        auto invite = move_tl_object_as<telegram_api::messages_exportedChatInviteReplaced>(result);

        td_->user_manager_->on_get_users(std::move(invite->users_), "RevokeChatInviteLinkQuery replaced");

        DialogInviteLink invite_link(std::move(invite->invite_), false, false, "RevokeChatInviteLinkQuery replaced");
        DialogInviteLink new_invite_link(std::move(invite->new_invite_), false, false,
                                         "RevokeChatInviteLinkQuery new replaced");
        if (!invite_link.is_valid() || !new_invite_link.is_valid()) {
          return on_error(Status::Error(500, "Receive invalid invite link"));
        }
        if (new_invite_link.get_creator_user_id() == td_->user_manager_->get_my_id() &&
            new_invite_link.is_permanent()) {
          td_->dialog_invite_link_manager_->on_get_permanent_dialog_invite_link(dialog_id_, new_invite_link);
        }
        links.push_back(invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
        links.push_back(new_invite_link.get_chat_invite_link_object(td_->user_manager_.get()));
        break;
      }
      default:
        UNREACHABLE();
    }
    auto total_count = static_cast<int32>(links.size());
    promise_.set_value(td_api::make_object<td_api::chatInviteLinks>(total_count, std::move(links)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "RevokeChatInviteLinkQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteExportedChatInviteQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit DeleteExportedChatInviteQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteExportedChatInvite(std::move(input_peer), invite_link)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteExportedChatInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteExportedChatInviteQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteRevokedExportedChatInvitesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit DeleteRevokedExportedChatInvitesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, tl_object_ptr<telegram_api::InputUser> &&input_user) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteRevokedExportedChatInvites(std::move(input_peer), std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteRevokedExportedChatInvites>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteRevokedExportedChatInvitesQuery");
    promise_.set_error(std::move(status));
  }
};

DialogInviteLinkManager::DialogInviteLinkManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  invite_link_info_expire_timeout_.set_callback(on_invite_link_info_expire_timeout_callback);
  invite_link_info_expire_timeout_.set_callback_data(static_cast<void *>(this));
}

void DialogInviteLinkManager::tear_down() {
  parent_.reset();
}

DialogInviteLinkManager::~DialogInviteLinkManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), invite_link_infos_,
                                              dialog_access_by_invite_link_);
}

void DialogInviteLinkManager::on_invite_link_info_expire_timeout_callback(void *dialog_invite_link_manager_ptr,
                                                                          int64 dialog_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto dialog_invite_link_manager = static_cast<DialogInviteLinkManager *>(dialog_invite_link_manager_ptr);
  send_closure_later(dialog_invite_link_manager->actor_id(dialog_invite_link_manager),
                     &DialogInviteLinkManager::on_invite_link_info_expire_timeout, DialogId(dialog_id_long));
}

void DialogInviteLinkManager::on_invite_link_info_expire_timeout(DialogId dialog_id) {
  if (G()->close_flag()) {
    return;
  }

  auto access_it = dialog_access_by_invite_link_.find(dialog_id);
  if (access_it == dialog_access_by_invite_link_.end()) {
    return;
  }
  auto expires_in = access_it->second.accessible_before_date - G()->unix_time() - 1;
  if (expires_in >= 3) {
    invite_link_info_expire_timeout_.set_timeout_in(dialog_id.get(), expires_in);
    return;
  }

  remove_dialog_access_by_invite_link(dialog_id);
}

void DialogInviteLinkManager::check_dialog_invite_link(const string &invite_link, bool force, Promise<Unit> &&promise) {
  auto it = invite_link_infos_.find(invite_link);
  if (it != invite_link_infos_.end()) {
    auto dialog_id = it->second->dialog_id;
    if (!force && dialog_id.get_type() == DialogType::Chat &&
        !td_->chat_manager_->get_chat_is_active(dialog_id.get_chat_id())) {
      invite_link_infos_.erase(it);
    } else {
      return promise.set_value(Unit());
    }
  }

  if (!DialogInviteLink::is_valid_invite_link(invite_link)) {
    return promise.set_error(Status::Error(400, "Wrong invite link"));
  }

  CHECK(!invite_link.empty());
  td_->create_handler<CheckChatInviteQuery>(std::move(promise))->send(invite_link);
}

void DialogInviteLinkManager::import_dialog_invite_link(const string &invite_link, Promise<DialogId> &&promise) {
  if (!DialogInviteLink::is_valid_invite_link(invite_link)) {
    return promise.set_error(Status::Error(400, "Wrong invite link"));
  }

  td_->create_handler<ImportChatInviteQuery>(std::move(promise))->send(invite_link);
}

void DialogInviteLinkManager::on_get_dialog_invite_link_info(
    const string &invite_link, telegram_api::object_ptr<telegram_api::ChatInvite> &&chat_invite_ptr,
    Promise<Unit> &&promise) {
  CHECK(chat_invite_ptr != nullptr);
  CHECK(!invite_link.empty());
  switch (chat_invite_ptr->get_id()) {
    case telegram_api::chatInviteAlready::ID:
    case telegram_api::chatInvitePeek::ID: {
      telegram_api::object_ptr<telegram_api::Chat> chat = nullptr;
      int32 accessible_before_date = 0;
      if (chat_invite_ptr->get_id() == telegram_api::chatInviteAlready::ID) {
        auto chat_invite_already = telegram_api::move_object_as<telegram_api::chatInviteAlready>(chat_invite_ptr);
        chat = std::move(chat_invite_already->chat_);
      } else {
        auto chat_invite_peek = telegram_api::move_object_as<telegram_api::chatInvitePeek>(chat_invite_ptr);
        chat = std::move(chat_invite_peek->chat_);
        accessible_before_date = chat_invite_peek->expires_;
      }
      auto chat_id = ChatManager::get_chat_id(chat);
      if (chat_id != ChatId() && !chat_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << chat_id;
        chat_id = ChatId();
      }
      auto channel_id = ChatManager::get_channel_id(chat);
      if (channel_id != ChannelId() && !channel_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << channel_id;
        channel_id = ChannelId();
      }
      if (accessible_before_date != 0 && (!channel_id.is_valid() || accessible_before_date < 0)) {
        LOG(ERROR) << "Receive expires = " << accessible_before_date << " for invite link " << invite_link << " to "
                   << to_string(chat);
        accessible_before_date = 0;
      }
      td_->chat_manager_->on_get_chat(std::move(chat), "chatInviteAlready");

      CHECK(chat_id == ChatId() || channel_id == ChannelId());

      // the access is already expired, reget the info
      if (accessible_before_date != 0 && accessible_before_date <= G()->unix_time() + 1) {
        td_->create_handler<CheckChatInviteQuery>(std::move(promise))->send(invite_link);
        return;
      }

      DialogId dialog_id = chat_id.is_valid() ? DialogId(chat_id) : DialogId(channel_id);
      auto &invite_link_info = invite_link_infos_[invite_link];
      if (invite_link_info == nullptr) {
        invite_link_info = make_unique<InviteLinkInfo>();
      }
      invite_link_info->dialog_id = dialog_id;
      if (accessible_before_date != 0 && dialog_id.is_valid()) {
        add_dialog_access_by_invite_link(dialog_id, invite_link, accessible_before_date);
      }
      break;
    }
    case telegram_api::chatInvite::ID: {
      auto chat_invite = telegram_api::move_object_as<telegram_api::chatInvite>(chat_invite_ptr);
      auto &invite_link_info = invite_link_infos_[invite_link];
      if (invite_link_info == nullptr) {
        invite_link_info = make_unique<InviteLinkInfo>();
      }
      invite_link_info->dialog_id = DialogId();
      invite_link_info->title = chat_invite->title_;
      invite_link_info->photo = get_photo(td_, std::move(chat_invite->photo_), DialogId());
      invite_link_info->accent_color_id = AccentColorId(chat_invite->color_);
      invite_link_info->description = std::move(chat_invite->about_);
      invite_link_info->participant_count = chat_invite->participants_count_;
      invite_link_info->participant_user_ids =
          td_->user_manager_->get_user_ids(std::move(chat_invite->participants_), "chatInvite");
      invite_link_info->subscription_pricing = StarSubscriptionPricing(std::move(chat_invite->subscription_pricing_));
      invite_link_info->subscription_form_id = chat_invite->subscription_form_id_;
      invite_link_info->can_refulfill_subscription = chat_invite->can_refulfill_subscription_;
      invite_link_info->creates_join_request = std::move(chat_invite->request_needed_);
      invite_link_info->is_chat = !chat_invite->channel_;
      invite_link_info->is_channel = chat_invite->channel_;

      bool is_broadcast = chat_invite->broadcast_;
      bool is_public = chat_invite->public_;
      bool is_megagroup = chat_invite->megagroup_;

      if (!invite_link_info->is_channel) {
        if (is_broadcast || is_public || is_megagroup) {
          LOG(ERROR) << "Receive wrong chat invite: " << to_string(chat_invite);
          is_public = is_megagroup = false;
        }
      } else {
        LOG_IF(ERROR, is_broadcast == is_megagroup) << "Receive wrong chat invite: " << to_string(chat_invite);
      }

      invite_link_info->is_public = is_public;
      invite_link_info->is_megagroup = is_megagroup;
      invite_link_info->is_verified = chat_invite->verified_;
      invite_link_info->is_scam = chat_invite->scam_;
      invite_link_info->is_fake = chat_invite->fake_;
      invite_link_info->bot_verification_icon = chat_invite->bot_verification_ == nullptr
                                                    ? CustomEmojiId()
                                                    : CustomEmojiId(chat_invite->bot_verification_->icon_);
      break;
    }
    default:
      UNREACHABLE();
  }
  promise.set_value(Unit());
}

void DialogInviteLinkManager::invalidate_invite_link_info(const string &invite_link) {
  LOG(INFO) << "Invalidate info about invite link " << invite_link;
  invite_link_infos_.erase(invite_link);
}

td_api::object_ptr<td_api::chatInviteLinkInfo> DialogInviteLinkManager::get_chat_invite_link_info_object(
    const string &invite_link) {
  auto it = invite_link_infos_.find(invite_link);
  if (it == invite_link_infos_.end()) {
    return nullptr;
  }

  const auto *invite_link_info = it->second.get();
  CHECK(invite_link_info != nullptr);

  DialogId dialog_id = invite_link_info->dialog_id;
  bool is_chat = false;
  bool is_megagroup = false;
  string title;
  const DialogPhoto *photo = nullptr;
  DialogPhoto invite_link_photo;
  int32 accent_color_id_object;
  string description;
  int32 participant_count = 0;
  vector<int64> member_user_ids;
  td_api::object_ptr<td_api::chatInviteLinkSubscriptionInfo> subscription_info;
  bool creates_join_request = false;
  bool is_public = false;
  bool is_member = false;
  td_api::object_ptr<td_api::verificationStatus> verification_status;

  if (dialog_id.is_valid()) {
    switch (dialog_id.get_type()) {
      case DialogType::Chat: {
        auto chat_id = dialog_id.get_chat_id();
        is_chat = true;

        title = td_->chat_manager_->get_chat_title(chat_id);
        photo = td_->chat_manager_->get_chat_dialog_photo(chat_id);
        participant_count = td_->chat_manager_->get_chat_participant_count(chat_id);
        is_member = td_->chat_manager_->get_chat_status(chat_id).is_member();
        accent_color_id_object = td_->chat_manager_->get_chat_accent_color_id_object(chat_id);
        break;
      }
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        title = td_->chat_manager_->get_channel_title(channel_id);
        photo = td_->chat_manager_->get_channel_dialog_photo(channel_id);
        is_public = td_->chat_manager_->is_channel_public(channel_id);
        is_megagroup = td_->chat_manager_->is_megagroup_channel(channel_id);
        participant_count = td_->chat_manager_->get_channel_participant_count(channel_id);
        is_member = td_->chat_manager_->get_channel_status(channel_id).is_member();
        verification_status = td_->chat_manager_->get_channel_verification_status_object(channel_id);
        accent_color_id_object = td_->chat_manager_->get_channel_accent_color_id_object(channel_id);
        break;
      }
      default:
        UNREACHABLE();
    }
    description = td_->dialog_manager_->get_dialog_about(dialog_id);
  } else {
    is_chat = invite_link_info->is_chat;
    is_megagroup = invite_link_info->is_megagroup;
    title = invite_link_info->title;
    invite_link_photo = as_fake_dialog_photo(invite_link_info->photo, dialog_id, false);
    photo = &invite_link_photo;
    accent_color_id_object = td_->theme_manager_->get_accent_color_id_object(invite_link_info->accent_color_id);
    description = invite_link_info->description;
    participant_count = invite_link_info->participant_count;
    member_user_ids = td_->user_manager_->get_user_ids_object(invite_link_info->participant_user_ids,
                                                              "get_chat_invite_link_info_object");
    auto subscription_pricing = invite_link_info->subscription_pricing.get_star_subscription_pricing_object();
    if (subscription_pricing != nullptr) {
      subscription_info = td_api::make_object<td_api::chatInviteLinkSubscriptionInfo>(
          std::move(subscription_pricing), invite_link_info->can_refulfill_subscription,
          invite_link_info->subscription_form_id);
    }
    creates_join_request = invite_link_info->creates_join_request;
    is_public = invite_link_info->is_public;
    verification_status =
        get_verification_status_object(td_, invite_link_info->is_verified, invite_link_info->is_scam,
                                       invite_link_info->is_fake, invite_link_info->bot_verification_icon);
  }

  td_api::object_ptr<td_api::InviteLinkChatType> chat_type;
  if (is_chat) {
    chat_type = td_api::make_object<td_api::inviteLinkChatTypeBasicGroup>();
  } else if (is_megagroup) {
    chat_type = td_api::make_object<td_api::inviteLinkChatTypeSupergroup>();
  } else {
    chat_type = td_api::make_object<td_api::inviteLinkChatTypeChannel>();
  }

  if (dialog_id.is_valid()) {
    td_->dialog_manager_->force_create_dialog(dialog_id, "get_chat_invite_link_info_object");
  }
  int32 accessible_for = 0;
  if (dialog_id.is_valid() && !is_member) {
    accessible_for = get_dialog_accessible_by_invite_link_before_date(dialog_id);
  }

  return td_api::make_object<td_api::chatInviteLinkInfo>(
      td_->dialog_manager_->get_chat_id_object(dialog_id, "chatInviteLinkInfo"), accessible_for, std::move(chat_type),
      title, get_chat_photo_info_object(td_->file_manager_.get(), photo), accent_color_id_object, description,
      participant_count, std::move(member_user_ids), std::move(subscription_info), creates_join_request, is_public,
      std::move(verification_status));
}

void DialogInviteLinkManager::add_dialog_access_by_invite_link(DialogId dialog_id, const string &invite_link,
                                                               int32 accessible_before_date) {
  CHECK(dialog_id.is_valid());
  CHECK(!invite_link.empty());
  auto &access = dialog_access_by_invite_link_[dialog_id];
  access.invite_links.insert(invite_link);
  if (access.accessible_before_date < accessible_before_date) {
    access.accessible_before_date = accessible_before_date;

    auto expires_in = accessible_before_date - G()->unix_time() - 1;
    invite_link_info_expire_timeout_.set_timeout_in(dialog_id.get(), expires_in);
  }
}

bool DialogInviteLinkManager::have_dialog_access_by_invite_link(DialogId dialog_id) const {
  return dialog_access_by_invite_link_.count(dialog_id) != 0;
}

int32 DialogInviteLinkManager::get_dialog_accessible_by_invite_link_before_date(DialogId dialog_id) const {
  auto it = dialog_access_by_invite_link_.find(dialog_id);
  if (it != dialog_access_by_invite_link_.end()) {
    return td::max(1, it->second.accessible_before_date - G()->unix_time() - 1);
  }
  return 0;
}

void DialogInviteLinkManager::remove_dialog_access_by_invite_link(DialogId dialog_id) {
  auto access_it = dialog_access_by_invite_link_.find(dialog_id);
  if (access_it == dialog_access_by_invite_link_.end()) {
    return;
  }

  for (auto &invite_link : access_it->second.invite_links) {
    invalidate_invite_link_info(invite_link);
  }
  dialog_access_by_invite_link_.erase(access_it);

  invite_link_info_expire_timeout_.cancel_timeout(dialog_id.get());
}

Status DialogInviteLinkManager::can_manage_dialog_invite_links(DialogId dialog_id, bool creator_only) {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write,
                                                       "can_manage_dialog_invite_links"));

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return Status::Error(400, "Can't invite members to a private chat");
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      if (!td_->chat_manager_->get_chat_is_active(chat_id)) {
        return Status::Error(400, "Chat is deactivated");
      }
      auto status = td_->chat_manager_->get_chat_status(chat_id);
      bool have_rights = creator_only ? status.is_creator() : status.can_manage_invite_links();
      if (!have_rights) {
        return Status::Error(400, "Not enough rights to manage chat invite link");
      }
      break;
    }
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      auto status = td_->chat_manager_->get_channel_status(channel_id);
      bool have_rights = creator_only ? status.is_creator() : status.can_manage_invite_links();
      if (!have_rights) {
        return Status::Error(400, "Not enough rights to manage chat invite link");
      }
      break;
    }
    case DialogType::SecretChat:
      return Status::Error(400, "Can't invite members to a secret chat");
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  return Status::OK();
}

void DialogInviteLinkManager::on_get_permanent_dialog_invite_link(DialogId dialog_id,
                                                                  const DialogInviteLink &invite_link) {
  switch (dialog_id.get_type()) {
    case DialogType::Chat:
      return td_->chat_manager_->on_update_chat_permanent_invite_link(dialog_id.get_chat_id(), invite_link);
    case DialogType::Channel:
      return td_->chat_manager_->on_update_channel_permanent_invite_link(dialog_id.get_channel_id(), invite_link);
    case DialogType::User:
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogInviteLinkManager::export_dialog_invite_link(DialogId dialog_id, string title, int32 expire_date,
                                                        int32 usage_limit, bool creates_join_request,
                                                        StarSubscriptionPricing subscription_pricing,
                                                        bool is_subscription, bool is_permanent,
                                                        Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise) {
  if (is_subscription) {
    if (subscription_pricing.is_empty()) {
      return promise.set_error(Status::Error(400, "Invalid subscription pricing specified"));
    }
    CHECK(expire_date == 0 && usage_limit == 0 && !creates_join_request);
  } else {
    CHECK(subscription_pricing.is_empty());
  }
  if (creates_join_request && usage_limit > 0) {
    return promise.set_error(
        Status::Error(400, "Member limit can't be specified for links requiring administrator approval"));
  }

  td_->user_manager_->get_me(PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_id, title = clean_name(std::move(title), MAX_INVITE_LINK_TITLE_LENGTH),
       expire_date, usage_limit, creates_join_request, subscription_pricing, is_permanent,
       promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &DialogInviteLinkManager::export_dialog_invite_link_impl, dialog_id, std::move(title),
                       expire_date, usage_limit, creates_join_request, subscription_pricing, is_permanent,
                       std::move(promise));
        }
      }));
}

void DialogInviteLinkManager::export_dialog_invite_link_impl(
    DialogId dialog_id, string title, int32 expire_date, int32 usage_limit, bool creates_join_request,
    StarSubscriptionPricing subscription_pricing, bool is_permanent,
    Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));

  td_->create_handler<ExportChatInviteQuery>(std::move(promise))
      ->send(dialog_id, title, expire_date, usage_limit, creates_join_request, subscription_pricing, is_permanent);
}

void DialogInviteLinkManager::edit_dialog_invite_link(DialogId dialog_id, const string &invite_link, string title,
                                                      int32 expire_date, int32 usage_limit, bool creates_join_request,
                                                      bool is_subscription,
                                                      Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));
  if (creates_join_request && usage_limit > 0) {
    return promise.set_error(
        Status::Error(400, "Member limit can't be specified for links requiring administrator approval"));
  }

  if (invite_link.empty()) {
    return promise.set_error(Status::Error(400, "Invite link must be non-empty"));
  }

  auto new_title = clean_name(std::move(title), MAX_INVITE_LINK_TITLE_LENGTH);
  td_->create_handler<EditChatInviteLinkQuery>(std::move(promise))
      ->send(dialog_id, invite_link, new_title, expire_date, usage_limit, creates_join_request, is_subscription);
}

void DialogInviteLinkManager::get_dialog_invite_link(DialogId dialog_id, const string &invite_link,
                                                     Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));

  if (invite_link.empty()) {
    return promise.set_error(Status::Error(400, "Invite link must be non-empty"));
  }

  td_->create_handler<GetExportedChatInviteQuery>(std::move(promise))->send(dialog_id, invite_link);
}

void DialogInviteLinkManager::get_dialog_invite_link_counts(
    DialogId dialog_id, Promise<td_api::object_ptr<td_api::chatInviteLinkCounts>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id, true));

  td_->create_handler<GetChatAdminWithInvitesQuery>(std::move(promise))->send(dialog_id);
}

void DialogInviteLinkManager::get_dialog_invite_links(DialogId dialog_id, UserId creator_user_id, bool is_revoked,
                                                      int32 offset_date, const string &offset_invite_link, int32 limit,
                                                      Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise) {
  TRY_STATUS_PROMISE(promise,
                     can_manage_dialog_invite_links(dialog_id, creator_user_id != td_->user_manager_->get_my_id()));
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(creator_user_id));

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  td_->create_handler<GetExportedChatInvitesQuery>(std::move(promise))
      ->send(dialog_id, std::move(input_user), is_revoked, offset_date, offset_invite_link, limit);
}

void DialogInviteLinkManager::get_dialog_invite_link_users(
    DialogId dialog_id, const string &invite_link, bool subscription_expired,
    td_api::object_ptr<td_api::chatInviteLinkMember> offset_member, int32 limit,
    Promise<td_api::object_ptr<td_api::chatInviteLinkMembers>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  if (invite_link.empty()) {
    return promise.set_error(Status::Error(400, "Invite link must be non-empty"));
  }

  UserId offset_user_id;
  int32 offset_date = 0;
  if (offset_member != nullptr) {
    offset_user_id = UserId(offset_member->user_id_);
    offset_date = offset_member->joined_chat_date_;
  }

  td_->create_handler<GetChatInviteImportersQuery>(std::move(promise))
      ->send(dialog_id, invite_link, subscription_expired, offset_date, offset_user_id, limit);
}

void DialogInviteLinkManager::revoke_dialog_invite_link(
    DialogId dialog_id, const string &invite_link, Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));

  if (invite_link.empty()) {
    return promise.set_error(Status::Error(400, "Invite link must be non-empty"));
  }

  td_->create_handler<RevokeChatInviteLinkQuery>(std::move(promise))->send(dialog_id, invite_link);
}

void DialogInviteLinkManager::delete_revoked_dialog_invite_link(DialogId dialog_id, const string &invite_link,
                                                                Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_invite_links(dialog_id));

  if (invite_link.empty()) {
    return promise.set_error(Status::Error(400, "Invite link must be non-empty"));
  }

  td_->create_handler<DeleteExportedChatInviteQuery>(std::move(promise))->send(dialog_id, invite_link);
}

void DialogInviteLinkManager::delete_all_revoked_dialog_invite_links(DialogId dialog_id, UserId creator_user_id,
                                                                     Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise,
                     can_manage_dialog_invite_links(dialog_id, creator_user_id != td_->user_manager_->get_my_id()));
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(creator_user_id));

  td_->create_handler<DeleteRevokedExportedChatInvitesQuery>(std::move(promise))
      ->send(dialog_id, std::move(input_user));
}

}  // namespace td
