//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PrivacyManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"

#include <algorithm>
#include <iterator>

namespace td {

class GetPrivacyQuery final : public Td::ResultHandler {
  Promise<UserPrivacySettingRules> promise_;

 public:
  explicit GetPrivacyQuery(Promise<UserPrivacySettingRules> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserPrivacySetting user_privacy_setting) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_getPrivacy(user_privacy_setting.get_input_privacy_key())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getPrivacy>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPrivacyQuery: " << to_string(ptr);
    promise_.set_value(UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(ptr)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetPrivacyQuery final : public Td::ResultHandler {
  Promise<UserPrivacySettingRules> promise_;

 public:
  explicit SetPrivacyQuery(Promise<UserPrivacySettingRules> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserPrivacySetting user_privacy_setting, UserPrivacySettingRules &&privacy_rules) {
    send_query(G()->net_query_creator().create(telegram_api::account_setPrivacy(
        user_privacy_setting.get_input_privacy_key(), privacy_rules.get_input_privacy_rules(td_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_setPrivacy>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetPrivacyQuery: " << to_string(ptr);
    promise_.set_value(UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(ptr)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AddNoPaidMessageExceptionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;

 public:
  explicit AddNoPaidMessageExceptionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user, bool refund_charged) {
    user_id_ = user_id;
    int32 flags = 0;
    if (refund_charged) {
      flags |= telegram_api::account_addNoPaidMessagesException::REFUND_CHARGED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_addNoPaidMessagesException(flags, false /*ignored*/, std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_addNoPaidMessagesException>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (result_ptr.ok()) {
      td_->user_manager_->on_update_user_charge_paid_message_stars(user_id_, 0);
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

PrivacyManager::PrivacyManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void PrivacyManager::tear_down() {
  parent_.reset();
}

void PrivacyManager::get_privacy(tl_object_ptr<td_api::UserPrivacySetting> key,
                                 Promise<tl_object_ptr<td_api::userPrivacySettingRules>> promise) {
  TRY_RESULT_PROMISE(promise, user_privacy_setting, UserPrivacySetting::get_user_privacy_setting(std::move(key)));
  auto &info = get_info(user_privacy_setting);
  if (info.is_synchronized_) {
    return promise.set_value(info.rules_.get_user_privacy_setting_rules_object(td_));
  }
  info.get_promises_.push_back(std::move(promise));
  if (info.get_promises_.size() > 1u) {
    // query has already been sent, just wait for the result
    return;
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), user_privacy_setting](Result<UserPrivacySettingRules> r_privacy_rules) {
        send_closure(actor_id, &PrivacyManager::on_get_user_privacy_settings, user_privacy_setting,
                     std::move(r_privacy_rules));
      });
  td_->create_handler<GetPrivacyQuery>(std::move(query_promise))->send(user_privacy_setting);
}

void PrivacyManager::set_privacy(tl_object_ptr<td_api::UserPrivacySetting> key,
                                 tl_object_ptr<td_api::userPrivacySettingRules> rules, Promise<Unit> promise) {
  TRY_RESULT_PROMISE(promise, user_privacy_setting, UserPrivacySetting::get_user_privacy_setting(std::move(key)));
  TRY_RESULT_PROMISE(promise, privacy_rules,
                     UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(rules)));

  auto &info = get_info(user_privacy_setting);
  if (info.has_set_query_) {
    info.pending_rules_ = std::move(privacy_rules);
    info.set_promises_.push_back(std::move(promise));
    return;
  }
  info.has_set_query_ = true;

  set_privacy_impl(user_privacy_setting, std::move(privacy_rules), std::move(promise));
}

void PrivacyManager::set_privacy_impl(UserPrivacySetting user_privacy_setting, UserPrivacySettingRules &&privacy_rules,
                                      Promise<Unit> &&promise) {
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), user_privacy_setting,
                              promise = std::move(promise)](Result<UserPrivacySettingRules> r_privacy_rules) mutable {
        send_closure(actor_id, &PrivacyManager::on_set_user_privacy_settings, user_privacy_setting,
                     std::move(r_privacy_rules), std::move(promise));
      });
  td_->create_handler<SetPrivacyQuery>(std::move(query_promise))->send(user_privacy_setting, std::move(privacy_rules));
}

void PrivacyManager::on_update_privacy(tl_object_ptr<telegram_api::updatePrivacy> update) {
  CHECK(update != nullptr);
  CHECK(update->key_ != nullptr);
  UserPrivacySetting user_privacy_setting(*update->key_);
  auto privacy_rules = UserPrivacySettingRules::get_user_privacy_setting_rules(td_, std::move(update->rules_));
  do_update_privacy(user_privacy_setting, std::move(privacy_rules), true);
}

void PrivacyManager::on_get_user_privacy_settings(UserPrivacySetting user_privacy_setting,
                                                  Result<UserPrivacySettingRules> r_privacy_rules) {
  G()->ignore_result_if_closing(r_privacy_rules);
  auto &info = get_info(user_privacy_setting);
  auto promises = std::move(info.get_promises_);
  reset_to_empty(info.get_promises_);
  for (auto &promise : promises) {
    if (r_privacy_rules.is_error()) {
      promise.set_error(r_privacy_rules.error().clone());
    } else {
      promise.set_value(r_privacy_rules.ok().get_user_privacy_setting_rules_object(td_));
    }
  }
  if (r_privacy_rules.is_ok()) {
    do_update_privacy(user_privacy_setting, r_privacy_rules.move_as_ok(), false);
  }
}

void PrivacyManager::on_set_user_privacy_settings(UserPrivacySetting user_privacy_setting,
                                                  Result<UserPrivacySettingRules> r_privacy_rules,
                                                  Promise<Unit> &&promise) {
  if (G()->close_flag()) {
    auto &info = get_info(user_privacy_setting);
    CHECK(info.has_set_query_);
    info.has_set_query_ = false;
    auto promises = std::move(info.set_promises_);
    fail_promises(promises, Global::request_aborted_error());
    promise.set_error(Global::request_aborted_error());
    return;
  }

  auto &info = get_info(user_privacy_setting);
  CHECK(info.has_set_query_);
  info.has_set_query_ = false;
  if (r_privacy_rules.is_error()) {
    promise.set_error(r_privacy_rules.move_as_error());
  } else {
    do_update_privacy(user_privacy_setting, r_privacy_rules.move_as_ok(), true);
    promise.set_value(Unit());
  }
  if (!info.set_promises_.empty()) {
    info.has_set_query_ = true;
    auto join_promise =
        PromiseCreator::lambda([promises = std::move(info.set_promises_)](Result<Unit> &&result) mutable {
          if (result.is_ok()) {
            set_promises(promises);
          } else {
            fail_promises(promises, result.move_as_error());
          }
        });
    reset_to_empty(info.set_promises_);
    set_privacy_impl(user_privacy_setting, std::move(info.pending_rules_), std::move(join_promise));
  }
}

void PrivacyManager::do_update_privacy(UserPrivacySetting user_privacy_setting, UserPrivacySettingRules &&privacy_rules,
                                       bool from_update) {
  auto &info = get_info(user_privacy_setting);
  bool was_synchronized = info.is_synchronized_;
  info.is_synchronized_ = true;

  if (!(info.rules_ == privacy_rules)) {
    if (!G()->close_flag() && (from_update || was_synchronized)) {
      switch (user_privacy_setting.type()) {
        case UserPrivacySetting::Type::UserStatus: {
          send_closure_later(G()->user_manager(), &UserManager::on_update_online_status_privacy);

          auto old_restricted = info.rules_.get_restricted_user_ids();
          auto new_restricted = privacy_rules.get_restricted_user_ids();
          if (old_restricted != new_restricted) {
            // if a user was unrestricted, it is not received from the server anymore
            // we need to reget their online status manually
            std::vector<UserId> unrestricted;
            std::set_difference(old_restricted.begin(), old_restricted.end(), new_restricted.begin(),
                                new_restricted.end(), std::back_inserter(unrestricted),
                                [](UserId lhs, UserId rhs) { return lhs.get() < rhs.get(); });
            for (auto &user_id : unrestricted) {
              send_closure_later(G()->user_manager(), &UserManager::reload_user, user_id, Promise<Unit>(),
                                 "do_update_privacy");
            }
          }
          break;
        }
        case UserPrivacySetting::Type::UserPhoneNumber:
          send_closure_later(G()->user_manager(), &UserManager::on_update_phone_number_privacy);
          break;
        default:
          break;
      }
    }

    info.rules_ = std::move(privacy_rules);
    send_closure(
        G()->td(), &Td::send_update,
        make_tl_object<td_api::updateUserPrivacySettingRules>(user_privacy_setting.get_user_privacy_setting_object(),
                                                              info.rules_.get_user_privacy_setting_rules_object(td_)));
  }
}

void PrivacyManager::allow_unpaid_messages(UserId user_id, bool refund_payments, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
  td_->create_handler<AddNoPaidMessageExceptionQuery>(std::move(promise))
      ->send(user_id, std::move(input_user), refund_payments);
}

}  // namespace td
