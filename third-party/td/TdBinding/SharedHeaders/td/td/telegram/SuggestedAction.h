//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"

namespace td {

struct SuggestedAction {
  enum class Type : int32 {
    Empty,
    EnableArchiveAndMuteNewChats,
    CheckPhoneNumber,
    ViewChecksHint,
    ConvertToGigagroup,
    CheckPassword,
    SetPassword,
    UpgradePremium,
    SubscribeToAnnualPremium,
    RestorePremium,
    GiftPremiumForChristmas,
    BirthdaySetup,
    PremiumGrace,
    StarsSubscriptionLowBalance,
    UserpicSetup
  };
  Type type_ = Type::Empty;
  DialogId dialog_id_;
  int32 otherwise_relogin_days_ = 0;

  void init(Type type);

  SuggestedAction() = default;

  explicit SuggestedAction(Type type, DialogId dialog_id = DialogId(), int32 otherwise_relogin_days = 0)
      : type_(type), dialog_id_(dialog_id), otherwise_relogin_days_(otherwise_relogin_days) {
  }

  explicit SuggestedAction(Slice action_str);

  SuggestedAction(Slice action_str, DialogId dialog_id);

  explicit SuggestedAction(const td_api::object_ptr<td_api::SuggestedAction> &suggested_action);

  bool is_empty() const {
    return type_ == Type::Empty;
  }

  string get_suggested_action_str() const;

  td_api::object_ptr<td_api::SuggestedAction> get_suggested_action_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

struct SuggestedActionHash {
  uint32 operator()(SuggestedAction suggested_action) const {
    return combine_hashes(DialogIdHash()(suggested_action.dialog_id_), static_cast<int32>(suggested_action.type_));
  }
};

inline bool operator==(const SuggestedAction &lhs, const SuggestedAction &rhs) {
  return lhs.type_ == rhs.type_ && lhs.dialog_id_ == rhs.dialog_id_;
}

inline bool operator!=(const SuggestedAction &lhs, const SuggestedAction &rhs) {
  return !(lhs == rhs);
}

inline bool operator<(const SuggestedAction &lhs, const SuggestedAction &rhs) {
  if (lhs.dialog_id_ != rhs.dialog_id_) {
    return lhs.dialog_id_.get() < rhs.dialog_id_.get();
  }
  return static_cast<int32>(lhs.type_) < static_cast<int32>(rhs.type_);
}

td_api::object_ptr<td_api::updateSuggestedActions> get_update_suggested_actions_object(
    const vector<SuggestedAction> &added_actions, const vector<SuggestedAction> &removed_actions, const char *source);

bool update_suggested_actions(vector<SuggestedAction> &suggested_actions,
                              vector<SuggestedAction> &&new_suggested_actions);

bool remove_suggested_action(vector<SuggestedAction> &suggested_actions, SuggestedAction suggested_action);

void dismiss_suggested_action(SuggestedAction action, Promise<Unit> &&promise);

}  // namespace td
