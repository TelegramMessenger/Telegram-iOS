//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SuggestedAction.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/Global.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Td.h"

#include "td/actor/actor.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"

#include <algorithm>

namespace td {

void SuggestedAction::init(Type type) {
  type_ = type;
}

SuggestedAction::SuggestedAction(Slice action_str) {
  if (action_str == Slice("AUTOARCHIVE_POPULAR")) {
    init(Type::EnableArchiveAndMuteNewChats);
  } else if (action_str == Slice("VALIDATE_PASSWORD")) {
    init(Type::CheckPassword);
  } else if (action_str == Slice("VALIDATE_PHONE_NUMBER")) {
    init(Type::CheckPhoneNumber);
  } else if (action_str == Slice("NEWCOMER_TICKS")) {
    init(Type::ViewChecksHint);
  } else if (action_str == Slice("SETUP_PASSWORD")) {
    init(Type::SetPassword);
  } else if (action_str == Slice("PREMIUM_UPGRADE")) {
    init(Type::UpgradePremium);
  } else if (action_str == Slice("PREMIUM_ANNUAL")) {
    init(Type::SubscribeToAnnualPremium);
  } else if (action_str == Slice("PREMIUM_RESTORE")) {
    init(Type::RestorePremium);
  } else if (action_str == Slice("PREMIUM_CHRISTMAS")) {
    init(Type::GiftPremiumForChristmas);
  } else if (action_str == Slice("BIRTHDAY_SETUP")) {
    init(Type::BirthdaySetup);
  } else if (action_str == Slice("PREMIUM_GRACE")) {
    init(Type::PremiumGrace);
  } else if (action_str == Slice("STARS_SUBSCRIPTION_LOW_BALANCE")) {
    init(Type::StarsSubscriptionLowBalance);
  } else if (action_str == Slice("USERPIC_SETUP")) {
    init(Type::UserpicSetup);
  }
}

SuggestedAction::SuggestedAction(Slice action_str, DialogId dialog_id) {
  CHECK(dialog_id.is_valid());
  if (action_str == Slice("CONVERT_GIGAGROUP")) {
    type_ = Type::ConvertToGigagroup;
    dialog_id_ = dialog_id;
  }
}

SuggestedAction::SuggestedAction(const td_api::object_ptr<td_api::SuggestedAction> &suggested_action) {
  if (suggested_action == nullptr) {
    return;
  }
  switch (suggested_action->get_id()) {
    case td_api::suggestedActionEnableArchiveAndMuteNewChats::ID:
      init(Type::EnableArchiveAndMuteNewChats);
      break;
    case td_api::suggestedActionCheckPassword::ID:
      init(Type::CheckPassword);
      break;
    case td_api::suggestedActionCheckPhoneNumber::ID:
      init(Type::CheckPhoneNumber);
      break;
    case td_api::suggestedActionViewChecksHint::ID:
      init(Type::ViewChecksHint);
      break;
    case td_api::suggestedActionConvertToBroadcastGroup::ID: {
      auto action = static_cast<const td_api::suggestedActionConvertToBroadcastGroup *>(suggested_action.get());
      ChannelId channel_id(action->supergroup_id_);
      if (channel_id.is_valid()) {
        type_ = Type::ConvertToGigagroup;
        dialog_id_ = DialogId(channel_id);
      }
      break;
    }
    case td_api::suggestedActionSetPassword::ID: {
      auto action = static_cast<const td_api::suggestedActionSetPassword *>(suggested_action.get());
      type_ = Type::SetPassword;
      otherwise_relogin_days_ = action->authorization_delay_;
      break;
    }
    case td_api::suggestedActionUpgradePremium::ID:
      init(Type::UpgradePremium);
      break;
    case td_api::suggestedActionSubscribeToAnnualPremium::ID:
      init(Type::SubscribeToAnnualPremium);
      break;
    case td_api::suggestedActionRestorePremium::ID:
      init(Type::RestorePremium);
      break;
    case td_api::suggestedActionGiftPremiumForChristmas::ID:
      init(Type::GiftPremiumForChristmas);
      break;
    case td_api::suggestedActionSetBirthdate::ID:
      init(Type::BirthdaySetup);
      break;
    case td_api::suggestedActionExtendPremium::ID:
      init(Type::PremiumGrace);
      break;
    case td_api::suggestedActionExtendStarSubscriptions::ID:
      init(Type::StarsSubscriptionLowBalance);
      break;
    case td_api::suggestedActionSetProfilePhoto::ID:
      init(Type::UserpicSetup);
      break;
    default:
      UNREACHABLE();
  }
}

string SuggestedAction::get_suggested_action_str() const {
  switch (type_) {
    case Type::EnableArchiveAndMuteNewChats:
      return "AUTOARCHIVE_POPULAR";
    case Type::CheckPassword:
      return "VALIDATE_PASSWORD";
    case Type::CheckPhoneNumber:
      return "VALIDATE_PHONE_NUMBER";
    case Type::ViewChecksHint:
      return "NEWCOMER_TICKS";
    case Type::ConvertToGigagroup:
      return "CONVERT_GIGAGROUP";
    case Type::SetPassword:
      return "SETUP_PASSWORD";
    case Type::UpgradePremium:
      return "PREMIUM_UPGRADE";
    case Type::SubscribeToAnnualPremium:
      return "PREMIUM_ANNUAL";
    case Type::RestorePremium:
      return "PREMIUM_RESTORE";
    case Type::GiftPremiumForChristmas:
      return "PREMIUM_CHRISTMAS";
    case Type::BirthdaySetup:
      return "BIRTHDAY_SETUP";
    case Type::PremiumGrace:
      return "PREMIUM_GRACE";
    case Type::StarsSubscriptionLowBalance:
      return "STARS_SUBSCRIPTION_LOW_BALANCE";
    case Type::UserpicSetup:
      return "USERPIC_SETUP";
    default:
      return string();
  }
}

td_api::object_ptr<td_api::SuggestedAction> SuggestedAction::get_suggested_action_object() const {
  switch (type_) {
    case Type::Empty:
      return nullptr;
    case Type::EnableArchiveAndMuteNewChats:
      return td_api::make_object<td_api::suggestedActionEnableArchiveAndMuteNewChats>();
    case Type::CheckPassword:
      return td_api::make_object<td_api::suggestedActionCheckPassword>();
    case Type::CheckPhoneNumber:
      return td_api::make_object<td_api::suggestedActionCheckPhoneNumber>();
    case Type::ViewChecksHint:
      return td_api::make_object<td_api::suggestedActionViewChecksHint>();
    case Type::ConvertToGigagroup:
      return td_api::make_object<td_api::suggestedActionConvertToBroadcastGroup>(dialog_id_.get_channel_id().get());
    case Type::SetPassword:
      return td_api::make_object<td_api::suggestedActionSetPassword>(otherwise_relogin_days_);
    case Type::UpgradePremium:
      return td_api::make_object<td_api::suggestedActionUpgradePremium>();
    case Type::SubscribeToAnnualPremium:
      return td_api::make_object<td_api::suggestedActionSubscribeToAnnualPremium>();
    case Type::RestorePremium:
      return td_api::make_object<td_api::suggestedActionRestorePremium>();
    case Type::GiftPremiumForChristmas:
      return td_api::make_object<td_api::suggestedActionGiftPremiumForChristmas>();
    case Type::BirthdaySetup:
      return td_api::make_object<td_api::suggestedActionSetBirthdate>();
    case Type::PremiumGrace:
      return td_api::make_object<td_api::suggestedActionExtendPremium>(
          G()->get_option_string("premium_manage_subscription_url", "https://t.me/premiumbot?start=status"));
    case Type::StarsSubscriptionLowBalance:
      return td_api::make_object<td_api::suggestedActionExtendStarSubscriptions>();
    case Type::UserpicSetup:
      return td_api::make_object<td_api::suggestedActionSetProfilePhoto>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::updateSuggestedActions> get_update_suggested_actions_object(
    const vector<SuggestedAction> &added_actions, const vector<SuggestedAction> &removed_actions, const char *source) {
  LOG(INFO) << "Get updateSuggestedActions from " << source;
  auto get_object = [](const SuggestedAction &action) {
    return action.get_suggested_action_object();
  };
  return td_api::make_object<td_api::updateSuggestedActions>(transform(added_actions, get_object),
                                                             transform(removed_actions, get_object));
}

bool update_suggested_actions(vector<SuggestedAction> &suggested_actions,
                              vector<SuggestedAction> &&new_suggested_actions) {
  td::unique(new_suggested_actions);
  if (new_suggested_actions == suggested_actions) {
    return false;
  }

  vector<SuggestedAction> added_actions;
  vector<SuggestedAction> removed_actions;
  auto old_it = suggested_actions.begin();
  auto new_it = new_suggested_actions.begin();
  while (old_it != suggested_actions.end() || new_it != new_suggested_actions.end()) {
    if (old_it != suggested_actions.end() && (new_it == new_suggested_actions.end() || *old_it < *new_it)) {
      removed_actions.push_back(*old_it++);
    } else if (old_it == suggested_actions.end() || *new_it < *old_it) {
      added_actions.push_back(*new_it++);
    } else {
      ++old_it;
      ++new_it;
    }
  }
  CHECK(!added_actions.empty() || !removed_actions.empty());
  suggested_actions = std::move(new_suggested_actions);
  send_closure(G()->td(), &Td::send_update,
               get_update_suggested_actions_object(added_actions, removed_actions, "update_suggested_actions"));
  return true;
}

bool remove_suggested_action(vector<SuggestedAction> &suggested_actions, SuggestedAction suggested_action) {
  if (td::remove(suggested_actions, suggested_action)) {
    send_closure(G()->td(), &Td::send_update,
                 get_update_suggested_actions_object({}, {suggested_action}, "remove_suggested_action"));
    return true;
  }
  return false;
}

void dismiss_suggested_action(SuggestedAction action, Promise<Unit> &&promise) {
  switch (action.type_) {
    case SuggestedAction::Type::Empty:
      return promise.set_error(Status::Error(400, "Action must be non-empty"));
    case SuggestedAction::Type::EnableArchiveAndMuteNewChats:
    case SuggestedAction::Type::CheckPassword:
    case SuggestedAction::Type::CheckPhoneNumber:
    case SuggestedAction::Type::ViewChecksHint:
    case SuggestedAction::Type::UpgradePremium:
    case SuggestedAction::Type::SubscribeToAnnualPremium:
    case SuggestedAction::Type::RestorePremium:
    case SuggestedAction::Type::GiftPremiumForChristmas:
    case SuggestedAction::Type::BirthdaySetup:
    case SuggestedAction::Type::PremiumGrace:
    case SuggestedAction::Type::StarsSubscriptionLowBalance:
    case SuggestedAction::Type::ConvertToGigagroup:
    case SuggestedAction::Type::UserpicSetup:
      return send_closure_later(G()->suggested_action_manager(), &SuggestedActionManager::dismiss_suggested_action,
                                std::move(action), std::move(promise));
    case SuggestedAction::Type::SetPassword: {
      if (action.otherwise_relogin_days_ < 0) {
        return promise.set_error(Status::Error(400, "Invalid authorization_delay specified"));
      }
      if (action.otherwise_relogin_days_ == 0) {
        return send_closure_later(G()->suggested_action_manager(), &SuggestedActionManager::dismiss_suggested_action,
                                  std::move(action), std::move(promise));
      }
      auto days = narrow_cast<int32>(G()->get_option_integer("otherwise_relogin_days"));
      if (days == action.otherwise_relogin_days_) {
        vector<SuggestedAction> removed_actions{SuggestedAction{SuggestedAction::Type::SetPassword, DialogId(), days}};
        send_closure(G()->td(), &Td::send_update,
                     get_update_suggested_actions_object({}, removed_actions, "dismiss_suggested_action"));
        G()->set_option_empty("otherwise_relogin_days");
      }
      return promise.set_value(Unit());
    }
    default:
      UNREACHABLE();
      return;
  }
}

}  // namespace td
