//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageReactor.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

#include <algorithm>

namespace td {

MessageReactor::MessageReactor(Td *td, telegram_api::object_ptr<telegram_api::messageReactor> &&reactor)
    : dialog_id_(reactor->peer_id_ == nullptr ? DialogId() : DialogId(reactor->peer_id_))
    , count_(reactor->count_)
    , is_top_(reactor->top_)
    , is_me_(reactor->my_)
    , is_anonymous_(reactor->anonymous_) {
  if (dialog_id_.get_type() == DialogType::Channel && !td->dialog_manager_->have_dialog_info(dialog_id_)) {
    auto channel_id = dialog_id_.get_channel_id();
    auto min_channel = td->chat_manager_->get_min_channel(channel_id);
    if (min_channel == nullptr) {
      LOG(ERROR) << "Receive unknown reacted " << channel_id;
    } else {
      min_channel_ = make_unique<MinChannel>(*min_channel);
    }
  }
}

td_api::object_ptr<td_api::paidReactor> MessageReactor::get_paid_reactor_object(Td *td) const {
  return td_api::make_object<td_api::paidReactor>(
      dialog_id_ == DialogId() ? nullptr : get_message_sender_object(td, dialog_id_, "paidReactor"), count_, is_top_,
      is_me_, is_anonymous_);
}

void MessageReactor::add_min_channel(Td *td) const {
  if (min_channel_ != nullptr && dialog_id_.get_type() == DialogType::Channel) {
    td->chat_manager_->add_min_channel(dialog_id_.get_channel_id(), *min_channel_);
  }
}

void MessageReactor::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_message_sender_dependencies(dialog_id_);
}

PaidReactionType MessageReactor::get_paid_reaction_type(DialogId my_dialog_id) const {
  if (is_anonymous_ || !dialog_id_.is_valid()) {
    return PaidReactionType::legacy(true);
  }
  if (dialog_id_ == my_dialog_id) {
    return PaidReactionType::legacy(false);
  }
  return PaidReactionType::dialog(dialog_id_);
}

bool MessageReactor::fix_is_me(DialogId my_dialog_id) {
  if (dialog_id_ == my_dialog_id) {
    is_me_ = true;
    return true;
  }
  return false;
}

void MessageReactor::fix_message_reactors(vector<MessageReactor> &reactors, bool need_warning) {
  size_t TOP_REACTOR_COUNT = 3u;
  if (reactors.size() > TOP_REACTOR_COUNT + 1) {
    LOG(ERROR) << "Have too many " << reactors;
    reactors.resize(TOP_REACTOR_COUNT + 1);
  }
  if (reactors.size() > TOP_REACTOR_COUNT && !reactors[TOP_REACTOR_COUNT].is_me()) {
    LOG(ERROR) << "Receive unexpected " << reactors;
    reactors.resize(TOP_REACTOR_COUNT);
  }
  if (need_warning) {
    for (size_t i = 0; i < reactors.size(); i++) {
      if (reactors[i].is_top_ != (i < TOP_REACTOR_COUNT)) {
        LOG(ERROR) << "Receive incorrect top " << reactors;
        break;
      }
    }
    for (size_t i = 0; i + 1 < reactors.size(); i++) {
      if (reactors[i].count_ < reactors[i + 1].count_) {
        LOG(ERROR) << "Receive unordered " << reactors;
        break;
      }
    }
  }
  bool was_me = false;
  for (const auto &reactor : reactors) {
    CHECK(reactor.is_valid());
    if (reactor.is_me()) {
      CHECK(!was_me);
      was_me = true;
    }
  }
  std::sort(reactors.begin(), reactors.end());
  if (reactors.size() > TOP_REACTOR_COUNT && !reactors[TOP_REACTOR_COUNT].is_me()) {
    reactors.resize(TOP_REACTOR_COUNT);
  }
  for (size_t i = 0; i < reactors.size(); i++) {
    reactors[i].is_top_ = (i < TOP_REACTOR_COUNT);
  }
}

bool operator<(const MessageReactor &lhs, const MessageReactor &rhs) {
  if (lhs.count_ != rhs.count_) {
    return lhs.count_ > rhs.count_;
  }
  return lhs.dialog_id_.get() < rhs.dialog_id_.get();
}

bool operator==(const MessageReactor &lhs, const MessageReactor &rhs) {
  return lhs.dialog_id_ == rhs.dialog_id_ && lhs.count_ == rhs.count_ && lhs.is_top_ == rhs.is_top_ &&
         lhs.is_me_ == rhs.is_me_ && lhs.is_anonymous_ == rhs.is_anonymous_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReactor &reactor) {
  return string_builder << "PaidReactor[" << reactor.dialog_id_ << " - " << reactor.count_
                        << (reactor.is_me_ ? " by me" : "") << ']';
}

}  // namespace td
