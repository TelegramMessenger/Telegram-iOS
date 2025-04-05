//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/StarSubscriptionPricing.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class DialogInviteLink;
class Td;

class DialogInviteLinkManager final : public Actor {
 public:
  DialogInviteLinkManager(Td *td, ActorShared<> parent);
  DialogInviteLinkManager(const DialogInviteLinkManager &) = delete;
  DialogInviteLinkManager &operator=(const DialogInviteLinkManager &) = delete;
  DialogInviteLinkManager(DialogInviteLinkManager &&) = delete;
  DialogInviteLinkManager &operator=(DialogInviteLinkManager &&) = delete;
  ~DialogInviteLinkManager() final;

  void check_dialog_invite_link(const string &invite_link, bool force, Promise<Unit> &&promise);

  void import_dialog_invite_link(const string &invite_link, Promise<DialogId> &&promise);

  void on_get_dialog_invite_link_info(const string &invite_link,
                                      telegram_api::object_ptr<telegram_api::ChatInvite> &&chat_invite_ptr,
                                      Promise<Unit> &&promise);

  void invalidate_invite_link_info(const string &invite_link);

  td_api::object_ptr<td_api::chatInviteLinkInfo> get_chat_invite_link_info_object(const string &invite_link);

  void on_get_permanent_dialog_invite_link(DialogId dialog_id, const DialogInviteLink &invite_link);

  bool have_dialog_access_by_invite_link(DialogId dialog_id) const;

  void remove_dialog_access_by_invite_link(DialogId dialog_id);

  void export_dialog_invite_link(DialogId dialog_id, string title, int32 expire_date, int32 usage_limit,
                                 bool creates_join_request, StarSubscriptionPricing subscription_pricing,
                                 bool is_subscription, bool is_permanent,
                                 Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise);

  void edit_dialog_invite_link(DialogId dialog_id, const string &link, string title, int32 expire_date,
                               int32 usage_limit, bool creates_join_request, bool is_subscription,
                               Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise);

  void get_dialog_invite_link(DialogId dialog_id, const string &invite_link,
                              Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise);

  void get_dialog_invite_link_counts(DialogId dialog_id,
                                     Promise<td_api::object_ptr<td_api::chatInviteLinkCounts>> &&promise);

  void get_dialog_invite_links(DialogId dialog_id, UserId creator_user_id, bool is_revoked, int32 offset_date,
                               const string &offset_invite_link, int32 limit,
                               Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise);

  void get_dialog_invite_link_users(DialogId dialog_id, const string &invite_link, bool subscription_expired,
                                    td_api::object_ptr<td_api::chatInviteLinkMember> offset_member, int32 limit,
                                    Promise<td_api::object_ptr<td_api::chatInviteLinkMembers>> &&promise);

  void revoke_dialog_invite_link(DialogId dialog_id, const string &link,
                                 Promise<td_api::object_ptr<td_api::chatInviteLinks>> &&promise);

  void delete_revoked_dialog_invite_link(DialogId dialog_id, const string &invite_link, Promise<Unit> &&promise);

  void delete_all_revoked_dialog_invite_links(DialogId dialog_id, UserId creator_user_id, Promise<Unit> &&promise);

 private:
  static constexpr size_t MAX_INVITE_LINK_TITLE_LENGTH = 32;  // server side limit

  void tear_down() final;

  static void on_invite_link_info_expire_timeout_callback(void *dialog_invite_link_manager_ptr, int64 dialog_id_long);

  void on_invite_link_info_expire_timeout(DialogId dialog_id);

  void add_dialog_access_by_invite_link(DialogId dialog_id, const string &invite_link, int32 accessible_before_date);

  int32 get_dialog_accessible_by_invite_link_before_date(DialogId dialog_id) const;

  void export_dialog_invite_link_impl(DialogId dialog_id, string title, int32 expire_date, int32 usage_limit,
                                      bool creates_join_request, StarSubscriptionPricing subscription_pricing,
                                      bool is_permanent, Promise<td_api::object_ptr<td_api::chatInviteLink>> &&promise);

  Status can_manage_dialog_invite_links(DialogId dialog_id, bool creator_only = false);

  struct InviteLinkInfo {
    // known dialog
    DialogId dialog_id;

    // unknown dialog
    string title;
    Photo photo;
    AccentColorId accent_color_id;
    int32 participant_count = 0;
    vector<UserId> participant_user_ids;
    string description;
    StarSubscriptionPricing subscription_pricing;
    int64 subscription_form_id;
    CustomEmojiId bot_verification_icon;
    bool creates_join_request = false;
    bool can_refulfill_subscription = false;
    bool is_chat = false;
    bool is_channel = false;
    bool is_public = false;
    bool is_megagroup = false;
    bool is_verified = false;
    bool is_scam = false;
    bool is_fake = false;
  };
  FlatHashMap<string, unique_ptr<InviteLinkInfo>> invite_link_infos_;

  struct DialogAccessByInviteLink {
    FlatHashSet<string> invite_links;
    int32 accessible_before_date = 0;
  };
  FlatHashMap<DialogId, DialogAccessByInviteLink, DialogIdHash> dialog_access_by_invite_link_;

  MultiTimeout invite_link_info_expire_timeout_{"InviteLinkInfoExpireTimeout"};

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
