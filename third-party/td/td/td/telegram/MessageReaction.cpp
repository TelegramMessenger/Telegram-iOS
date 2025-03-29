//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageReaction.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <algorithm>
#include <limits>
#include <utility>

namespace td {

static size_t get_max_reaction_count() {
  bool is_premium = G()->get_option_boolean("is_premium");
  auto option_key = is_premium ? Slice("reactions_user_max_premium") : Slice("reactions_user_max_default");
  return static_cast<size_t>(
      max(static_cast<int32>(1), static_cast<int32>(G()->get_option_integer(option_key, is_premium ? 3 : 1))));
}

class SendReactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SendReactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, vector<ReactionType> reaction_types, bool is_big, bool add_to_recent) {
    dialog_id_ = message_full_id.get_dialog_id();

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (!reaction_types.empty()) {
      flags |= telegram_api::messages_sendReaction::REACTION_MASK;

      if (is_big) {
        flags |= telegram_api::messages_sendReaction::BIG_MASK;
      }

      if (add_to_recent) {
        flags |= telegram_api::messages_sendReaction::ADD_TO_RECENT_MASK;
      }
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendReaction(flags, false /*ignored*/, false /*ignored*/, std::move(input_peer),
                                            message_full_id.get_message_id().get_server_message_id().get(),
                                            ReactionType::get_input_reactions(reaction_types)),
        {{dialog_id_}, {message_full_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendReaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendReactionQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "MESSAGE_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendReactionQuery");
    promise_.set_error(std::move(status));
  }
};

class SendPaidReactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  int64 star_count_;

 public:
  explicit SendPaidReactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, int32 star_count, bool use_default_paid_reaction_type,
            PaidReactionType paid_reaction_type, int64 random_id) {
    dialog_id_ = message_full_id.get_dialog_id();
    star_count_ = star_count;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    telegram_api::object_ptr<telegram_api::PaidReactionPrivacy> privacy;
    if (!use_default_paid_reaction_type) {
      flags |= telegram_api::messages_sendPaidReaction::PRIVATE_MASK;
      privacy = paid_reaction_type.get_input_paid_reaction_privacy(td_);
      CHECK(privacy != nullptr);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendPaidReaction(flags, std::move(input_peer),
                                                message_full_id.get_message_id().get_server_message_id().get(),
                                                star_count, random_id, std::move(privacy)),
        {{dialog_id_}, {message_full_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendPaidReaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendPaidReactionQuery: " << to_string(ptr);
    td_->star_manager_->add_pending_owned_star_count(star_count_, true);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "MESSAGE_NOT_MODIFIED") {
      td_->star_manager_->add_pending_owned_star_count(star_count_, true);
      return promise_.set_value(Unit());
    }
    td_->star_manager_->add_pending_owned_star_count(star_count_, false);
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendPaidReactionQuery");
    promise_.set_error(std::move(status));
  }
};

class TogglePaidReactionPrivacyQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit TogglePaidReactionPrivacyQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, PaidReactionType paid_reaction_type) {
    dialog_id_ = message_full_id.get_dialog_id();

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_togglePaidReactionPrivacy(std::move(input_peer),
                                                         message_full_id.get_message_id().get_server_message_id().get(),
                                                         paid_reaction_type.get_input_paid_reaction_privacy(td_)),
        {{dialog_id_}, {message_full_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_togglePaidReactionPrivacy>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "TogglePaidReactionPrivacyQuery");
    promise_.set_error(std::move(status));
  }
};

class GetPaidReactionPrivacyQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getPaidReactionPrivacy()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPaidReactionPrivacy>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPaidReactionPrivacyQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive " << status;
    }
  }
};

class GetMessageReactionsListQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::addedReactions>> promise_;
  DialogId dialog_id_;
  MessageId message_id_;
  ReactionType reaction_type_;
  string offset_;

 public:
  explicit GetMessageReactionsListQuery(Promise<td_api::object_ptr<td_api::addedReactions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, ReactionType reaction_type, string offset, int32 limit) {
    dialog_id_ = message_full_id.get_dialog_id();
    message_id_ = message_full_id.get_message_id();
    reaction_type_ = std::move(reaction_type);
    offset_ = std::move(offset);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (!reaction_type_.is_empty()) {
      flags |= telegram_api::messages_getMessageReactionsList::REACTION_MASK;
    }
    if (!offset_.empty()) {
      flags |= telegram_api::messages_getMessageReactionsList::OFFSET_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_getMessageReactionsList(flags, std::move(input_peer),
                                                       message_id_.get_server_message_id().get(),
                                                       reaction_type_.get_input_reaction(), offset_, limit),
        {{message_full_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getMessageReactionsList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetMessageReactionsListQuery: " << to_string(ptr);

    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetMessageReactionsListQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetMessageReactionsListQuery");

    int32 total_count = ptr->count_;
    auto received_reaction_count = static_cast<int32>(ptr->reactions_.size());
    if (total_count < received_reaction_count) {
      LOG(ERROR) << "Receive invalid total_count in " << to_string(ptr);
      total_count = received_reaction_count;
    }

    vector<td_api::object_ptr<td_api::addedReaction>> reactions;
    FlatHashMap<ReactionType, vector<DialogId>, ReactionTypeHash> recent_reaction_types;
    for (const auto &reaction : ptr->reactions_) {
      DialogId dialog_id(reaction->peer_id_);
      auto reaction_type = ReactionType(reaction->reaction_);
      if (!dialog_id.is_valid() ||
          (reaction_type_.is_empty() ? reaction_type.is_empty() : reaction_type_ != reaction_type)) {
        LOG(ERROR) << "Receive unexpected " << to_string(reaction);
        continue;
      }

      if (offset_.empty()) {
        recent_reaction_types[reaction_type].push_back(dialog_id);
      }

      auto message_sender = get_min_message_sender_object(td_, dialog_id, "GetMessageReactionsListQuery");
      if (message_sender != nullptr) {
        reactions.push_back(td_api::make_object<td_api::addedReaction>(
            reaction_type.get_reaction_type_object(), std::move(message_sender), reaction->my_, reaction->date_));
      }
    }

    if (offset_.empty()) {
      td_->messages_manager_->on_get_message_reaction_list({dialog_id_, message_id_}, reaction_type_,
                                                           std::move(recent_reaction_types), total_count);
    }

    promise_.set_value(
        td_api::make_object<td_api::addedReactions>(total_count, std::move(reactions), ptr->next_offset_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetMessageReactionsListQuery");
    promise_.set_error(std::move(status));
  }
};

class ReportReactionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ReportReactionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id, DialogId chooser_dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);

    auto chooser_input_peer = td_->dialog_manager_->get_input_peer(chooser_dialog_id, AccessRights::Know);
    if (chooser_input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Reaction sender is not accessible"));
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_reportReaction(
        std::move(input_peer), message_id.get_server_message_id().get(), std::move(chooser_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reportReaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportReactionQuery");
    promise_.set_error(std::move(status));
  }
};

MessageReaction::MessageReaction(ReactionType reaction_type, int32 choose_count, bool is_chosen,
                                 DialogId my_recent_chooser_dialog_id, vector<DialogId> &&recent_chooser_dialog_ids,
                                 vector<std::pair<ChannelId, MinChannel>> &&recent_chooser_min_channels)
    : reaction_type_(std::move(reaction_type))
    , choose_count_(choose_count)
    , is_chosen_(is_chosen)
    , my_recent_chooser_dialog_id_(my_recent_chooser_dialog_id)
    , recent_chooser_dialog_ids_(std::move(recent_chooser_dialog_ids))
    , recent_chooser_min_channels_(std::move(recent_chooser_min_channels)) {
  if (my_recent_chooser_dialog_id_.is_valid()) {
    CHECK(td::contains(recent_chooser_dialog_ids_, my_recent_chooser_dialog_id_));
  }
  fix_choose_count();
}

void MessageReaction::add_my_recent_chooser_dialog_id(DialogId dialog_id) {
  CHECK(!my_recent_chooser_dialog_id_.is_valid());
  my_recent_chooser_dialog_id_ = dialog_id;
  add_to_top(recent_chooser_dialog_ids_, MAX_RECENT_CHOOSERS + 1, dialog_id);
  fix_choose_count();
}

bool MessageReaction::remove_my_recent_chooser_dialog_id() {
  if (my_recent_chooser_dialog_id_.is_valid()) {
    bool is_removed = td::remove(recent_chooser_dialog_ids_, my_recent_chooser_dialog_id_);
    CHECK(is_removed);
    my_recent_chooser_dialog_id_ = DialogId();
    return true;
  }
  return false;
}

void MessageReaction::update_from(const MessageReaction &old_reaction) {
  CHECK(old_reaction.is_chosen());
  is_chosen_ = true;

  auto my_dialog_id = old_reaction.get_my_recent_chooser_dialog_id();
  if (my_dialog_id.is_valid() && td::contains(recent_chooser_dialog_ids_, my_dialog_id)) {
    my_recent_chooser_dialog_id_ = my_dialog_id;
  }
}

void MessageReaction::update_recent_chooser_dialog_ids(const MessageReaction &old_reaction) {
  if (recent_chooser_dialog_ids_.size() != MAX_RECENT_CHOOSERS) {
    return;
  }
  CHECK(is_chosen_ && old_reaction.is_chosen_);
  CHECK(reaction_type_ == old_reaction.reaction_type_);
  CHECK(old_reaction.recent_chooser_dialog_ids_.size() == MAX_RECENT_CHOOSERS + 1);
  for (size_t i = 0; i < MAX_RECENT_CHOOSERS; i++) {
    if (recent_chooser_dialog_ids_[i] != old_reaction.recent_chooser_dialog_ids_[i]) {
      return;
    }
  }
  my_recent_chooser_dialog_id_ = old_reaction.my_recent_chooser_dialog_id_;
  recent_chooser_dialog_ids_ = old_reaction.recent_chooser_dialog_ids_;
  recent_chooser_min_channels_ = old_reaction.recent_chooser_min_channels_;
  fix_choose_count();
}

void MessageReaction::set_as_chosen(DialogId my_dialog_id, bool have_recent_choosers) {
  CHECK(!is_chosen_);

  is_chosen_ = true;
  choose_count_++;
  if (have_recent_choosers) {
    remove_my_recent_chooser_dialog_id();
    add_my_recent_chooser_dialog_id(my_dialog_id);
  }
}

void MessageReaction::unset_as_chosen() {
  CHECK(is_chosen_);

  is_chosen_ = false;
  choose_count_--;
  remove_my_recent_chooser_dialog_id();
  fix_choose_count();
}

void MessageReaction::add_paid_reaction(int32 star_count) {
  is_chosen_ = true;
  CHECK(star_count <= std::numeric_limits<int32>::max() - choose_count_);
  choose_count_ += star_count;
}

void MessageReaction::fix_choose_count() {
  choose_count_ = max(choose_count_, narrow_cast<int32>(recent_chooser_dialog_ids_.size()));
}

void MessageReaction::set_my_recent_chooser_dialog_id(DialogId my_dialog_id) {
  if (!my_recent_chooser_dialog_id_.is_valid() || my_recent_chooser_dialog_id_ == my_dialog_id) {
    return;
  }
  td::remove(recent_chooser_dialog_ids_, my_dialog_id);
  for (auto &dialog_id : recent_chooser_dialog_ids_) {
    if (dialog_id == my_recent_chooser_dialog_id_) {
      dialog_id = my_dialog_id;
    }
  }
  CHECK(td::contains(recent_chooser_dialog_ids_, my_dialog_id));
  my_recent_chooser_dialog_id_ = my_dialog_id;
}

td_api::object_ptr<td_api::messageReaction> MessageReaction::get_message_reaction_object(Td *td, UserId my_user_id,
                                                                                         UserId peer_user_id) const {
  CHECK(!is_empty());

  td_api::object_ptr<td_api::MessageSender> used_sender;
  vector<td_api::object_ptr<td_api::MessageSender>> recent_choosers;
  if (my_user_id.is_valid()) {
    CHECK(peer_user_id.is_valid());
    if (is_chosen()) {
      auto recent_chooser = get_min_message_sender_object(td, DialogId(my_user_id), "get_message_reaction_object");
      if (recent_chooser != nullptr) {
        used_sender = get_min_message_sender_object(td, DialogId(my_user_id), "get_message_reaction_object");
        recent_choosers.push_back(std::move(recent_chooser));
      }
    }
    if (choose_count_ >= (is_chosen() ? 2 : 1)) {
      auto recent_chooser = get_min_message_sender_object(td, DialogId(peer_user_id), "get_message_reaction_object");
      if (recent_chooser != nullptr) {
        recent_choosers.push_back(std::move(recent_chooser));
      }
    }
  } else {
    for (auto dialog_id : recent_chooser_dialog_ids_) {
      auto recent_chooser = get_min_message_sender_object(td, dialog_id, "get_message_reaction_object");
      if (recent_chooser != nullptr) {
        if (is_chosen() && dialog_id == my_recent_chooser_dialog_id_) {
          used_sender = get_min_message_sender_object(td, dialog_id, "get_message_reaction_object");
        }
        recent_choosers.push_back(std::move(recent_chooser));
        if (recent_choosers.size() == MAX_RECENT_CHOOSERS) {
          break;
        }
      }
    }
  }
  return td_api::make_object<td_api::messageReaction>(reaction_type_.get_reaction_type_object(), choose_count_,
                                                      is_chosen_, std::move(used_sender), std::move(recent_choosers));
}

bool operator==(const MessageReaction &lhs, const MessageReaction &rhs) {
  return lhs.reaction_type_ == rhs.reaction_type_ && lhs.choose_count_ == rhs.choose_count_ &&
         lhs.is_chosen_ == rhs.is_chosen_ && lhs.my_recent_chooser_dialog_id_ == rhs.my_recent_chooser_dialog_id_ &&
         lhs.recent_chooser_dialog_ids_ == rhs.recent_chooser_dialog_ids_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReaction &reaction) {
  string_builder << '[' << reaction.reaction_type_ << (reaction.is_chosen_ ? " X " : " x ") << reaction.choose_count_;
  if (!reaction.recent_chooser_dialog_ids_.empty()) {
    string_builder << " by " << reaction.recent_chooser_dialog_ids_;
    if (reaction.my_recent_chooser_dialog_id_.is_valid()) {
      string_builder << " and my " << reaction.my_recent_chooser_dialog_id_;
    }
  }
  return string_builder << ']';
}

td_api::object_ptr<td_api::unreadReaction> UnreadMessageReaction::get_unread_reaction_object(Td *td) const {
  auto sender_id = get_min_message_sender_object(td, sender_dialog_id_, "get_unread_reaction_object");
  if (sender_id == nullptr) {
    return nullptr;
  }
  return td_api::make_object<td_api::unreadReaction>(reaction_type_.get_reaction_type_object(), std::move(sender_id),
                                                     is_big_);
}

bool operator==(const UnreadMessageReaction &lhs, const UnreadMessageReaction &rhs) {
  return lhs.reaction_type_ == rhs.reaction_type_ && lhs.sender_dialog_id_ == rhs.sender_dialog_id_ &&
         lhs.is_big_ == rhs.is_big_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const UnreadMessageReaction &unread_reaction) {
  return string_builder << '[' << unread_reaction.reaction_type_ << (unread_reaction.is_big_ ? " BY " : " by ")
                        << unread_reaction.sender_dialog_id_ << ']';
}

bool MessageReactions::are_empty() const {
  return reactions_.empty() && pending_paid_reactions_ == 0;
}

unique_ptr<MessageReactions> MessageReactions::get_message_reactions(
    Td *td, telegram_api::object_ptr<telegram_api::messageReactions> &&reactions, bool is_bot) {
  if (reactions == nullptr || is_bot) {
    return nullptr;
  }

  auto result = make_unique<MessageReactions>();
  result->can_get_added_reactions_ = reactions->can_see_list_;
  result->is_min_ = reactions->min_;
  result->are_tags_ = reactions->reactions_as_tags_;

  DialogId my_dialog_id;
  for (auto &peer_reaction : reactions->recent_reactions_) {
    if (peer_reaction->my_) {
      DialogId dialog_id(peer_reaction->peer_id_);
      if (!dialog_id.is_valid()) {
        continue;
      }
      if (my_dialog_id.is_valid() && dialog_id != my_dialog_id) {
        LOG(ERROR) << "Receive my reactions with " << dialog_id << " and " << my_dialog_id;
      }
      my_dialog_id = dialog_id;
    }
  }

  FlatHashSet<ReactionType, ReactionTypeHash> reaction_types;
  vector<std::pair<int32, ReactionType>> chosen_reaction_order;
  for (auto &reaction_count : reactions->results_) {
    auto reaction_type = ReactionType(reaction_count->reaction_);
    if (reaction_count->count_ <= 0 || reaction_count->count_ >= MessageReaction::MAX_CHOOSE_COUNT ||
        reaction_type.is_empty()) {
      LOG(ERROR) << "Receive " << reaction_type << " with invalid count " << reaction_count->count_;
      continue;
    }

    if (!reaction_types.insert(reaction_type).second) {
      LOG(ERROR) << "Receive duplicate " << reaction_type;
      continue;
    }

    FlatHashSet<DialogId, DialogIdHash> recent_choosers;
    DialogId my_recent_chooser_dialog_id;
    vector<DialogId> recent_chooser_dialog_ids;
    vector<std::pair<ChannelId, MinChannel>> recent_chooser_min_channels;
    for (auto &peer_reaction : reactions->recent_reactions_) {
      auto peer_reaction_type = ReactionType(peer_reaction->reaction_);
      if (peer_reaction_type == reaction_type) {
        DialogId dialog_id(peer_reaction->peer_id_);
        if (!dialog_id.is_valid()) {
          LOG(ERROR) << "Receive invalid " << dialog_id << " as a recent chooser for " << reaction_type;
          continue;
        }
        if (!recent_choosers.insert(dialog_id).second) {
          LOG(ERROR) << "Receive duplicate " << dialog_id << " as a recent chooser for " << reaction_type;
          continue;
        }
        if (!td->dialog_manager_->have_dialog_info(dialog_id)) {
          auto dialog_type = dialog_id.get_type();
          if (dialog_type == DialogType::User) {
            auto user_id = dialog_id.get_user_id();
            if (!td->user_manager_->have_min_user(user_id)) {
              LOG(ERROR) << "Receive unknown " << user_id;
              continue;
            }
          } else if (dialog_type == DialogType::Channel) {
            auto channel_id = dialog_id.get_channel_id();
            auto min_channel = td->chat_manager_->get_min_channel(channel_id);
            if (min_channel == nullptr) {
              LOG(ERROR) << "Receive unknown reacted " << channel_id;
              continue;
            }
            recent_chooser_min_channels.emplace_back(channel_id, *min_channel);
          } else {
            LOG(ERROR) << "Receive unknown reacted " << dialog_id;
            continue;
          }
        }

        recent_chooser_dialog_ids.push_back(dialog_id);
        if (dialog_id == my_dialog_id) {
          my_recent_chooser_dialog_id = dialog_id;
        }
        if (peer_reaction->unread_) {
          result->unread_reactions_.emplace_back(std::move(peer_reaction_type), dialog_id, peer_reaction->big_);
        }
        if (recent_chooser_dialog_ids.size() == MessageReaction::MAX_RECENT_CHOOSERS) {
          break;
        }
      }
    }

    bool is_chosen = (reaction_count->flags_ & telegram_api::reactionCount::CHOSEN_ORDER_MASK) != 0;
    if (is_chosen) {
      if (reaction_type == ReactionType::paid()) {
        LOG_IF(ERROR, reaction_count->chosen_order_ != -1)
            << "Receive paid reaction with order " << reaction_count->chosen_order_;
      } else {
        chosen_reaction_order.emplace_back(reaction_count->chosen_order_, reaction_type);
      }
    }
    result->reactions_.push_back({std::move(reaction_type), reaction_count->count_, is_chosen,
                                  my_recent_chooser_dialog_id, std::move(recent_chooser_dialog_ids),
                                  std::move(recent_chooser_min_channels)});
  }
  if (chosen_reaction_order.size() > 1) {
    std::sort(chosen_reaction_order.begin(), chosen_reaction_order.end());
    result->chosen_reaction_order_ =
        transform(chosen_reaction_order, [](const std::pair<int32, ReactionType> &order) { return order.second; });
  }
  bool was_me = false;
  for (auto &top_reactor : reactions->top_reactors_) {
    MessageReactor reactor(td, std::move(top_reactor));
    if (!reactor.is_valid() || (reactions->min_ && reactor.is_me())) {
      LOG(ERROR) << "Receive " << reactor;
      continue;
    }
    if (reactor.is_me()) {
      if (was_me) {
        LOG(ERROR) << "Receive duplicate " << reactor;
        continue;
      }
      was_me = true;
    }
    result->top_reactors_.push_back(std::move(reactor));
  }
  MessageReactor::fix_message_reactors(result->top_reactors_, true);
  return result;
}

MessageReaction *MessageReactions::get_reaction(const ReactionType &reaction_type) {
  for (auto &added_reaction : reactions_) {
    if (added_reaction.get_reaction_type() == reaction_type) {
      return &added_reaction;
    }
  }
  return nullptr;
}

const MessageReaction *MessageReactions::get_reaction(const ReactionType &reaction_type) const {
  for (const auto &added_reaction : reactions_) {
    if (added_reaction.get_reaction_type() == reaction_type) {
      return &added_reaction;
    }
  }
  return nullptr;
}

void MessageReactions::update_from(const MessageReactions &old_reactions, DialogId my_dialog_id) {
  if (is_min_ && !old_reactions.is_min_) {
    // chosen reactions were known, keep them
    is_min_ = false;
    chosen_reaction_order_ = old_reactions.chosen_reaction_order_;
    for (const auto &old_reaction : old_reactions.reactions_) {
      if (old_reaction.is_chosen()) {
        auto *reaction = get_reaction(old_reaction.get_reaction_type());
        if (reaction != nullptr) {
          reaction->update_from(old_reaction);
        }
      } else {
        td::remove(chosen_reaction_order_, old_reaction.get_reaction_type());
      }
    }
    unread_reactions_ = old_reactions.unread_reactions_;
    if (chosen_reaction_order_.size() == 1) {
      reset_to_empty(chosen_reaction_order_);
    }

    bool was_me = false;
    for (auto &reactor : top_reactors_) {
      if (reactor.fix_is_me(my_dialog_id)) {
        was_me = true;
        break;
      }
    }
    if (!was_me) {
      for (auto &reactor : old_reactions.top_reactors_) {
        if (reactor.is_me()) {
          // self paid reaction was known, keep it
          top_reactors_.push_back(reactor);
          MessageReactor::fix_message_reactors(top_reactors_, false);
        }
      }
    }
  }
  for (const auto &old_reaction : old_reactions.reactions_) {
    if (old_reaction.is_chosen() &&
        old_reaction.get_recent_chooser_dialog_ids().size() == MessageReaction::MAX_RECENT_CHOOSERS + 1) {
      auto *reaction = get_reaction(old_reaction.get_reaction_type());
      if (reaction != nullptr && reaction->is_chosen()) {
        reaction->update_recent_chooser_dialog_ids(old_reaction);
      }
    }
  }
  pending_paid_reactions_ = old_reactions.pending_paid_reactions_;
  pending_use_default_paid_reaction_type_ = old_reactions.pending_use_default_paid_reaction_type_;
  pending_paid_reaction_type_ = old_reactions.pending_paid_reaction_type_;
}

bool MessageReactions::add_my_reaction(const ReactionType &reaction_type, bool is_big, DialogId my_dialog_id,
                                       bool have_recent_choosers, bool is_tag) {
  vector<ReactionType> new_chosen_reaction_order = get_chosen_reaction_types();

  auto added_reaction = get_reaction(reaction_type);
  if (added_reaction == nullptr) {
    vector<DialogId> recent_chooser_dialog_ids;
    DialogId my_recent_chooser_dialog_id;
    if (have_recent_choosers) {
      recent_chooser_dialog_ids.push_back(my_dialog_id);
      my_recent_chooser_dialog_id = my_dialog_id;
    }
    reactions_.push_back(
        {reaction_type, 1, true, my_recent_chooser_dialog_id, std::move(recent_chooser_dialog_ids), Auto()});
    new_chosen_reaction_order.emplace_back(reaction_type);
  } else if (!added_reaction->is_chosen()) {
    added_reaction->set_as_chosen(my_dialog_id, have_recent_choosers);
    new_chosen_reaction_order.emplace_back(reaction_type);
  } else if (!is_big) {
    return false;
  }
  if (!is_tag) {
    CHECK(!are_tags_);
  } else {
    are_tags_ = true;
  }

  auto max_reaction_count = get_max_reaction_count();
  while (new_chosen_reaction_order.size() > max_reaction_count) {
    auto index = new_chosen_reaction_order[0] == reaction_type ? 1 : 0;
    CHECK(static_cast<size_t>(index) < new_chosen_reaction_order.size());
    bool is_removed = do_remove_my_reaction(new_chosen_reaction_order[index]);
    CHECK(is_removed);
    new_chosen_reaction_order.erase(new_chosen_reaction_order.begin() + index);
  }

  if (new_chosen_reaction_order.size() == 1) {
    new_chosen_reaction_order.clear();
  }
  chosen_reaction_order_ = std::move(new_chosen_reaction_order);

  for (auto &message_reaction : reactions_) {
    message_reaction.set_my_recent_chooser_dialog_id(my_dialog_id);
  }

  return true;
}

bool MessageReactions::remove_my_reaction(const ReactionType &reaction_type, DialogId my_dialog_id) {
  if (do_remove_my_reaction(reaction_type)) {
    if (!chosen_reaction_order_.empty()) {
      bool is_removed = td::remove(chosen_reaction_order_, reaction_type);
      CHECK(is_removed);

      // if the user isn't a Premium user, then max_reaction_count could be reduced from 3 to 1
      auto max_reaction_count = get_max_reaction_count();
      while (chosen_reaction_order_.size() > max_reaction_count) {
        is_removed = do_remove_my_reaction(chosen_reaction_order_[0]);
        CHECK(is_removed);
        chosen_reaction_order_.erase(chosen_reaction_order_.begin());
      }

      if (chosen_reaction_order_.size() <= 1) {
        reset_to_empty(chosen_reaction_order_);
      }
    }

    for (auto &message_reaction : reactions_) {
      message_reaction.set_my_recent_chooser_dialog_id(my_dialog_id);
    }

    return true;
  }
  return false;
}

bool MessageReactions::do_remove_my_reaction(const ReactionType &reaction_type) {
  for (auto it = reactions_.begin(); it != reactions_.end(); ++it) {
    auto &message_reaction = *it;
    if (message_reaction.get_reaction_type() == reaction_type) {
      if (message_reaction.is_chosen()) {
        message_reaction.unset_as_chosen();
        if (message_reaction.is_empty()) {
          it = reactions_.erase(it);
        }
        return true;
      }
      break;
    }
  }
  return false;
}

void MessageReactions::add_my_paid_reaction(Td *td, int32 star_count,
                                            const td_api::object_ptr<td_api::PaidReactionType> &type) {
  if (pending_paid_reactions_ > 1000000000 || star_count > 1000000000) {
    LOG(ERROR) << "Pending paid reactions overflown";
    return;
  }
  bool use_default_paid_reaction_type = type == nullptr;
  PaidReactionType paid_reaction_type(td, type);
  td->star_manager_->add_pending_owned_star_count(-star_count, false);
  if (use_default_paid_reaction_type) {
    if (pending_paid_reactions_ == 0) {
      pending_use_default_paid_reaction_type_ = true;
    }
    if (pending_use_default_paid_reaction_type_) {
      bool was_me = false;
      for (auto &reactor : top_reactors_) {
        if (reactor.is_me()) {
          was_me = true;
          pending_paid_reaction_type_ = reactor.get_paid_reaction_type(td->dialog_manager_->get_my_dialog_id());
        }
      }
      if (!was_me) {
        pending_paid_reaction_type_ = td->reaction_manager_->get_default_paid_reaction_type();
      }
    }
  } else {
    td->reaction_manager_->on_update_default_paid_reaction_type(paid_reaction_type);

    pending_use_default_paid_reaction_type_ = false;
    pending_paid_reaction_type_ = paid_reaction_type;
  }
  pending_paid_reactions_ += star_count;
}

bool MessageReactions::has_pending_paid_reactions() const {
  return pending_paid_reactions_ != 0;
}

void MessageReactions::drop_pending_paid_reactions(Td *td) {
  CHECK(has_pending_paid_reactions());
  td->star_manager_->add_pending_owned_star_count(pending_paid_reactions_, false);
  pending_paid_reactions_ = 0;
  pending_use_default_paid_reaction_type_ = false;
  pending_paid_reaction_type_ = {};
}

void MessageReactions::sort_reactions(const FlatHashMap<ReactionType, size_t, ReactionTypeHash> &active_reaction_pos) {
  std::sort(reactions_.begin(), reactions_.end(),
            [&active_reaction_pos](const MessageReaction &lhs, const MessageReaction &rhs) {
              if (lhs.get_reaction_type().is_paid_reaction() != rhs.get_reaction_type().is_paid_reaction()) {
                return lhs.get_reaction_type().is_paid_reaction();
              }
              if (lhs.get_choose_count() != rhs.get_choose_count()) {
                return lhs.get_choose_count() > rhs.get_choose_count();
              }
              auto lhs_it = active_reaction_pos.find(lhs.get_reaction_type());
              auto lhs_pos = lhs_it != active_reaction_pos.end() ? lhs_it->second : active_reaction_pos.size();
              auto rhs_it = active_reaction_pos.find(rhs.get_reaction_type());
              auto rhs_pos = rhs_it != active_reaction_pos.end() ? rhs_it->second : active_reaction_pos.size();
              if (lhs_pos != rhs_pos) {
                return lhs_pos < rhs_pos;
              }

              return lhs.get_reaction_type() < rhs.get_reaction_type();
            });
}

void MessageReactions::fix_chosen_reaction() {
  DialogId my_dialog_id;
  for (auto &reaction : reactions_) {
    if (!reaction.is_chosen() && reaction.get_my_recent_chooser_dialog_id().is_valid()) {
      my_dialog_id = reaction.get_my_recent_chooser_dialog_id();
      LOG(WARNING) << "Fix recent chosen reaction in " << *this;
      reaction.remove_my_recent_chooser_dialog_id();
    }
  }
  if (!my_dialog_id.is_valid()) {
    return;
  }
  for (auto &reaction : reactions_) {
    if (!reaction.get_reaction_type().is_paid_reaction() && reaction.is_chosen() &&
        !reaction.get_my_recent_chooser_dialog_id().is_valid()) {
      reaction.add_my_recent_chooser_dialog_id(my_dialog_id);
    }
  }
}

void MessageReactions::fix_my_recent_chooser_dialog_id(DialogId my_dialog_id) {
  for (auto &reaction : reactions_) {
    if (!reaction.get_reaction_type().is_paid_reaction() && reaction.is_chosen() &&
        !reaction.get_my_recent_chooser_dialog_id().is_valid() &&
        td::contains(reaction.get_recent_chooser_dialog_ids(), my_dialog_id)) {
      reaction.my_recent_chooser_dialog_id_ = my_dialog_id;
    }
  }
}

vector<ReactionType> MessageReactions::get_chosen_reaction_types() const {
  if (!chosen_reaction_order_.empty()) {
    return chosen_reaction_order_;
  }

  vector<ReactionType> reaction_order;
  for (const auto &reaction : reactions_) {
    if (!reaction.get_reaction_type().is_paid_reaction() && reaction.is_chosen()) {
      reaction_order.push_back(reaction.get_reaction_type());
    }
  }
  return reaction_order;
}

bool MessageReactions::are_consistent_with_list(
    const ReactionType &reaction_type, FlatHashMap<ReactionType, vector<DialogId>, ReactionTypeHash> reaction_types,
    int32 total_count) const {
  auto are_consistent = [](const vector<DialogId> &lhs, const vector<DialogId> &rhs) {
    size_t i = 0;
    size_t max_i = td::min(lhs.size(), rhs.size());
    while (i < max_i && lhs[i] == rhs[i]) {
      i++;
    }
    return i == max_i;
  };

  if (reaction_type.is_empty()) {
    // received list and total_count for all reactions
    int32 old_total_count = 0;
    for (const auto &message_reaction : reactions_) {
      CHECK(!message_reaction.get_reaction_type().is_empty());
      if (!are_consistent(reaction_types[message_reaction.get_reaction_type()],
                          message_reaction.get_recent_chooser_dialog_ids())) {
        return false;
      }
      old_total_count += message_reaction.get_choose_count();
      reaction_types.erase(message_reaction.get_reaction_type());
    }
    return old_total_count == total_count && reaction_types.empty();
  }

  // received list and total_count for a single reaction
  const auto *message_reaction = get_reaction(reaction_type);
  if (message_reaction == nullptr) {
    return reaction_types.count(reaction_type) == 0 && total_count == 0;
  } else {
    return are_consistent(reaction_types[reaction_type], message_reaction->get_recent_chooser_dialog_ids()) &&
           message_reaction->get_choose_count() == total_count;
  }
}

vector<MessageReactor> MessageReactions::apply_reactor_pending_paid_reactions(DialogId my_dialog_id) const {
  vector<MessageReactor> top_reactors;
  bool was_me = false;
  auto reactor_dialog_id = pending_paid_reaction_type_.get_dialog_id(my_dialog_id);
  for (auto &reactor : top_reactors_) {
    top_reactors.push_back(reactor);
    if (reactor.is_me()) {
      was_me = true;
      top_reactors.back().add_count(pending_paid_reactions_, reactor_dialog_id, my_dialog_id);
    }
  }
  if (!was_me) {
    if (reactor_dialog_id == DialogId()) {
      // anonymous reaction
      top_reactors.emplace_back(my_dialog_id, pending_paid_reactions_, true);
    } else {
      top_reactors.emplace_back(reactor_dialog_id, pending_paid_reactions_, false);
    }
  }
  MessageReactor::fix_message_reactors(top_reactors, false);
  return top_reactors;
}

td_api::object_ptr<td_api::messageReactions> MessageReactions::get_message_reactions_object(Td *td, UserId my_user_id,
                                                                                            UserId peer_user_id) const {
  auto reactions = transform(reactions_, [td, my_user_id, peer_user_id](const MessageReaction &reaction) {
    return reaction.get_message_reaction_object(td, my_user_id, peer_user_id);
  });
  auto reactors =
      transform(top_reactors_, [td](const MessageReactor &reactor) { return reactor.get_paid_reactor_object(td); });
  if (pending_paid_reactions_ > 0) {
    if (reactions_.empty() || !reactions_[0].reaction_type_.is_paid_reaction()) {
      reactions.insert(reactions.begin(),
                       MessageReaction(ReactionType::paid(), pending_paid_reactions_, true, DialogId(), Auto(), Auto())
                           .get_message_reaction_object(td, my_user_id, peer_user_id));
    } else {
      reactions[0]->total_count_ += pending_paid_reactions_;
      reactions[0]->is_chosen_ = true;
    }

    // my_user_id == UserId()
    auto top_reactors = apply_reactor_pending_paid_reactions(td->dialog_manager_->get_my_dialog_id());
    reactors =
        transform(top_reactors, [td](const MessageReactor &reactor) { return reactor.get_paid_reactor_object(td); });
  }
  return td_api::make_object<td_api::messageReactions>(std::move(reactions), are_tags_, std::move(reactors),
                                                       can_get_added_reactions_);
}

int32 MessageReactions::get_non_paid_reaction_count() const {
  int32 result = 0;
  for (const auto &reaction : reactions_) {
    if (!reaction.reaction_type_.is_paid_reaction()) {
      result++;
    }
  }
  return result;
}

void MessageReactions::add_min_channels(Td *td) const {
  for (const auto &reaction : reactions_) {
    for (const auto &recent_chooser_min_channel : reaction.get_recent_chooser_min_channels()) {
      LOG(INFO) << "Add min reacted " << recent_chooser_min_channel.first;
      td->chat_manager_->add_min_channel(recent_chooser_min_channel.first, recent_chooser_min_channel.second);
    }
  }
  for (const auto &reactor : top_reactors_) {
    reactor.add_min_channel(td);
  }
}

void MessageReactions::add_dependencies(Dependencies &dependencies) const {
  for (const auto &reaction : reactions_) {
    const auto &dialog_ids = reaction.get_recent_chooser_dialog_ids();
    for (auto dialog_id : dialog_ids) {
      dependencies.add_message_sender_dependencies(dialog_id);
    }
  }
  for (const auto &reactor : top_reactors_) {
    reactor.add_dependencies(dependencies);
  }
}

bool MessageReactions::need_update_message_reactions(const MessageReactions *old_reactions,
                                                     const MessageReactions *new_reactions) {
  if (old_reactions == nullptr) {
    // add reactions
    return new_reactions != nullptr;
  }
  if (new_reactions == nullptr) {
    // remove reactions when they are disabled
    return true;
  }

  // unread_reactions_ and chosen_reaction_order_ are updated independently; compare all other fields
  return old_reactions->reactions_ != new_reactions->reactions_ || old_reactions->is_min_ != new_reactions->is_min_ ||
         old_reactions->can_get_added_reactions_ != new_reactions->can_get_added_reactions_ ||
         old_reactions->need_polling_ != new_reactions->need_polling_ ||
         old_reactions->are_tags_ != new_reactions->are_tags_ ||
         old_reactions->top_reactors_ != new_reactions->top_reactors_;
}

bool MessageReactions::need_update_unread_reactions(const MessageReactions *old_reactions,
                                                    const MessageReactions *new_reactions) {
  if (old_reactions == nullptr || old_reactions->unread_reactions_.empty()) {
    return !(new_reactions == nullptr || new_reactions->unread_reactions_.empty());
  }
  return new_reactions == nullptr || old_reactions->unread_reactions_ != new_reactions->unread_reactions_;
}

void MessageReactions::send_paid_message_reaction(Td *td, MessageFullId message_full_id, int64 random_id,
                                                  Promise<Unit> &&promise) {
  CHECK(has_pending_paid_reactions());
  auto star_count = pending_paid_reactions_;
  auto use_default_paid_reaction_type = pending_use_default_paid_reaction_type_;
  auto paid_reaction_type = pending_paid_reaction_type_;
  top_reactors_ = apply_reactor_pending_paid_reactions(td->dialog_manager_->get_my_dialog_id());
  if (reactions_.empty() || !reactions_[0].reaction_type_.is_paid_reaction()) {
    reactions_.insert(reactions_.begin(),
                      MessageReaction(ReactionType::paid(), star_count, true, DialogId(), Auto(), Auto()));
  } else {
    reactions_[0].add_paid_reaction(star_count);
  }
  pending_paid_reactions_ = 0;
  pending_use_default_paid_reaction_type_ = false;
  pending_paid_reaction_type_ = {};

  td->create_handler<SendPaidReactionQuery>(std::move(promise))
      ->send(message_full_id, star_count, use_default_paid_reaction_type, paid_reaction_type, random_id);
}

bool MessageReactions::set_paid_message_reaction_type(Td *td, MessageFullId message_full_id,
                                                      const td_api::object_ptr<td_api::PaidReactionType> &type,
                                                      Promise<Unit> &&promise) {
  auto paid_reaction_type = PaidReactionType(td, type);
  if (pending_paid_reactions_ != 0) {
    pending_use_default_paid_reaction_type_ = false;
    pending_paid_reaction_type_ = paid_reaction_type;
  }
  for (auto &top_reactor : top_reactors_) {
    if (top_reactor.is_me()) {
      auto my_dialog_id = td->dialog_manager_->get_my_dialog_id();
      top_reactor.add_count(0, paid_reaction_type.get_dialog_id(my_dialog_id), my_dialog_id);
      td->reaction_manager_->on_update_default_paid_reaction_type(paid_reaction_type);
      td->create_handler<TogglePaidReactionPrivacyQuery>(std::move(promise))->send(message_full_id, paid_reaction_type);
      return true;
    }
  }
  if (pending_paid_reactions_ != 0) {
    td->reaction_manager_->on_update_default_paid_reaction_type(paid_reaction_type);
    promise.set_value(Unit());
    return true;
  }
  promise.set_error(Status::Error(400, "Message has no paid reaction"));
  return false;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReactions &reactions) {
  if (reactions.are_tags_) {
    return string_builder << "MessageTags{" << reactions.reactions_ << '}';
  }
  return string_builder << (reactions.is_min_ ? "Min" : "") << "MessageReactions{" << reactions.reactions_
                        << " with unread " << reactions.unread_reactions_ << ", reaction order "
                        << reactions.chosen_reaction_order_
                        << " and can_get_added_reactions = " << reactions.can_get_added_reactions_
                        << " with paid reactions by " << reactions.top_reactors_ << " and "
                        << reactions.pending_paid_reactions_ << " pending " << reactions.pending_paid_reaction_type_
                        << '}';
}

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<MessageReactions> &reactions) {
  if (reactions == nullptr) {
    return string_builder << "null";
  }
  return string_builder << *reactions;
}

void send_message_reaction(Td *td, MessageFullId message_full_id, vector<ReactionType> reaction_types, bool is_big,
                           bool add_to_recent, Promise<Unit> &&promise) {
  td->create_handler<SendReactionQuery>(std::move(promise))
      ->send(message_full_id, std::move(reaction_types), is_big, add_to_recent);
}

void set_message_reactions(Td *td, MessageFullId message_full_id, vector<ReactionType> reaction_types, bool is_big,
                           Promise<Unit> &&promise) {
  if (!td->messages_manager_->have_message_force(message_full_id, "set_message_reactions")) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }
  for (const auto &reaction_type : reaction_types) {
    if (reaction_type.is_empty() || reaction_type.is_paid_reaction()) {
      return promise.set_error(Status::Error(400, "Invalid reaction type specified"));
    }
  }
  send_message_reaction(td, message_full_id, std::move(reaction_types), is_big, false, std::move(promise));
}

void reload_paid_reaction_privacy(Td *td) {
  td->create_handler<GetPaidReactionPrivacyQuery>()->send();
}

void get_message_added_reactions(Td *td, MessageFullId message_full_id, ReactionType reaction_type, string offset,
                                 int32 limit, Promise<td_api::object_ptr<td_api::addedReactions>> &&promise) {
  if (!td->messages_manager_->have_message_force(message_full_id, "get_message_added_reactions")) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }
  if (reaction_type.is_paid_reaction()) {
    return promise.set_error(Status::Error(400, "Can't use the method for paid reaction"));
  }

  auto message_id = message_full_id.get_message_id();
  if (message_full_id.get_dialog_id().get_type() == DialogType::SecretChat || !message_id.is_valid() ||
      !message_id.is_server()) {
    return promise.set_value(td_api::make_object<td_api::addedReactions>(0, Auto(), string()));
  }

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  static constexpr int32 MAX_GET_ADDED_REACTIONS = 100;  // server side limit
  if (limit > MAX_GET_ADDED_REACTIONS) {
    limit = MAX_GET_ADDED_REACTIONS;
  }

  td->create_handler<GetMessageReactionsListQuery>(std::move(promise))
      ->send(message_full_id, std::move(reaction_type), std::move(offset), limit);
}

void report_message_reactions(Td *td, MessageFullId message_full_id, DialogId chooser_dialog_id,
                              Promise<Unit> &&promise) {
  auto dialog_id = message_full_id.get_dialog_id();
  TRY_STATUS_PROMISE(promise, td->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                       "report_message_reactions"));

  if (!td->messages_manager_->have_message_force(message_full_id, "report_message_reactions")) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }
  auto message_id = message_full_id.get_message_id();
  if (message_id.is_valid_scheduled()) {
    return promise.set_error(Status::Error(400, "Can't report reactions on scheduled messages"));
  }
  if (!message_id.is_server()) {
    return promise.set_error(Status::Error(400, "Message reactions can't be reported"));
  }

  if (!td->dialog_manager_->have_input_peer(chooser_dialog_id, false, AccessRights::Know)) {
    return promise.set_error(Status::Error(400, "Reaction sender not found"));
  }

  td->create_handler<ReportReactionQuery>(std::move(promise))->send(dialog_id, message_id, chooser_dialog_id);
}

vector<ReactionType> get_chosen_tags(const unique_ptr<MessageReactions> &message_reactions) {
  if (message_reactions == nullptr || !message_reactions->are_tags_) {
    return {};
  }
  return message_reactions->get_chosen_reaction_types();
}

}  // namespace td
