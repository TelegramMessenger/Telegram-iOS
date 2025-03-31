//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageReplyInfo.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

MessageReplyInfo::MessageReplyInfo(Td *td, tl_object_ptr<telegram_api::messageReplies> &&reply_info, bool is_bot) {
  if (reply_info == nullptr) {
    return;
  }
  if (reply_info->replies_ < 0) {
    LOG(ERROR) << "Receive wrong " << to_string(reply_info);
    return;
  }
  if (is_bot || reply_info->channel_id_ == 777) {
    is_dropped_ = true;
    return;
  }
  reply_count_ = reply_info->replies_;
  pts_ = reply_info->replies_pts_;

  is_comment_ = reply_info->comments_;

  if (is_comment_) {
    channel_id_ = ChannelId(reply_info->channel_id_);
    if (!channel_id_.is_valid()) {
      LOG(ERROR) << "Receive invalid " << channel_id_;
      channel_id_ = ChannelId();
      is_comment_ = false;
    }
  }

  if (is_comment_) {
    for (const auto &peer : reply_info->recent_repliers_) {
      DialogId dialog_id(peer);
      if (!dialog_id.is_valid()) {
        LOG(ERROR) << "Receive " << dialog_id << " as a recent replier";
        continue;
      }
      if (td::contains(recent_replier_dialog_ids_, dialog_id)) {
        LOG(ERROR) << "Receive duplicate " << dialog_id << " as a recent replier";
        continue;
      }
      if (!td->dialog_manager_->have_dialog_info(dialog_id)) {
        auto dialog_type = dialog_id.get_type();
        if (dialog_type == DialogType::User) {
          auto replier_user_id = dialog_id.get_user_id();
          if (!td->user_manager_->have_min_user(replier_user_id)) {
            LOG(ERROR) << "Receive unknown replied " << replier_user_id;
            continue;
          }
        } else if (dialog_type == DialogType::Channel) {
          auto replier_channel_id = dialog_id.get_channel_id();
          auto min_channel = td->chat_manager_->get_min_channel(replier_channel_id);
          if (min_channel == nullptr) {
            LOG(ERROR) << "Receive unknown replied " << replier_channel_id;
            continue;
          }
          replier_min_channels_.emplace_back(replier_channel_id, *min_channel);
        } else {
          LOG(ERROR) << "Receive unknown replied " << dialog_id;
          continue;
        }
      }
      recent_replier_dialog_ids_.push_back(dialog_id);
      if (recent_replier_dialog_ids_.size() == MAX_RECENT_REPLIERS) {
        break;
      }
    }
  }
  if ((reply_info->flags_ & telegram_api::messageReplies::MAX_ID_MASK) != 0 &&
      ServerMessageId(reply_info->max_id_).is_valid()) {
    max_message_id_ = MessageId(ServerMessageId(reply_info->max_id_));
  }
  if ((reply_info->flags_ & telegram_api::messageReplies::READ_MAX_ID_MASK) != 0 &&
      ServerMessageId(reply_info->read_max_id_).is_valid()) {
    last_read_inbox_message_id_ = MessageId(ServerMessageId(reply_info->read_max_id_));
  }
  if (last_read_inbox_message_id_ > max_message_id_) {  // possible if last thread message was deleted after it was read
    max_message_id_ = last_read_inbox_message_id_;
  }
  LOG(DEBUG) << "Parsed " << oneline(to_string(reply_info)) << " to " << *this;
}

bool MessageReplyInfo::need_update_to(const MessageReplyInfo &other) const {
  if (other.is_empty() && !is_empty()) {
    // ignore updates to empty reply info, because we will hide the info ourselves
    // return true;
  }
  if (other.is_comment_ != is_comment_ && !other.was_dropped()) {
    LOG(ERROR) << "Reply info has changed from " << *this << " to " << other;
    return true;
  }
  if (other.pts_ < pts_ && !other.was_dropped()) {
    return false;
  }
  return reply_count_ != other.reply_count_ || recent_replier_dialog_ids_ != other.recent_replier_dialog_ids_ ||
         replier_min_channels_.size() != other.replier_min_channels_.size() || is_comment_ != other.is_comment_ ||
         channel_id_ != other.channel_id_;
}

bool MessageReplyInfo::update_max_message_ids(const MessageReplyInfo &other) {
  return update_max_message_ids(other.max_message_id_, other.last_read_inbox_message_id_,
                                other.last_read_outbox_message_id_);
}

bool MessageReplyInfo::update_max_message_ids(MessageId other_max_message_id,
                                              MessageId other_last_read_inbox_message_id,
                                              MessageId other_last_read_outbox_message_id) {
  bool result = false;
  if (other_last_read_inbox_message_id > last_read_inbox_message_id_) {
    last_read_inbox_message_id_ = other_last_read_inbox_message_id;
    result = true;
  }
  if (other_last_read_outbox_message_id > last_read_outbox_message_id_) {
    last_read_outbox_message_id_ = other_last_read_outbox_message_id;
    result = true;
  }
  if (other_max_message_id.is_valid() ||
      (!other_last_read_inbox_message_id.is_valid() && !other_last_read_outbox_message_id.is_valid())) {
    if (other_max_message_id < last_read_inbox_message_id_) {
      other_max_message_id = last_read_inbox_message_id_;
    }
    if (other_max_message_id < last_read_outbox_message_id_) {
      other_max_message_id = last_read_outbox_message_id_;
    }
    if (other_max_message_id != max_message_id_) {
      max_message_id_ = other_max_message_id;
      result = true;
    }
  }
  return result;
}

bool MessageReplyInfo::add_reply(DialogId replier_dialog_id, MessageId reply_message_id, int diff) {
  CHECK(!is_empty());
  CHECK(diff == +1 || diff == -1);

  if (diff == -1 && reply_count_ == 0) {
    return false;
  }

  reply_count_ += diff;
  if (is_comment_ && replier_dialog_id.is_valid()) {
    if (replier_dialog_id.get_type() == DialogType::Channel) {
      // the replier_dialog_id is never min, because it is the sender of a message
      for (auto it = replier_min_channels_.begin(); it != replier_min_channels_.end(); ++it) {
        if (it->first == replier_dialog_id.get_channel_id()) {
          replier_min_channels_.erase(it);
          break;
        }
      }
    }

    if (diff > 0) {
      add_to_top(recent_replier_dialog_ids_, MAX_RECENT_REPLIERS, replier_dialog_id);
    } else {
      td::remove(recent_replier_dialog_ids_, replier_dialog_id);
      auto max_repliers = static_cast<size_t>(reply_count_);
      if (recent_replier_dialog_ids_.size() > max_repliers) {
        recent_replier_dialog_ids_.resize(max_repliers);
      }
    }
  }

  if (diff > 0 && reply_message_id > max_message_id_) {
    max_message_id_ = reply_message_id;
  }
  return true;
}

bool MessageReplyInfo::need_reget(const Td *td) const {
  for (auto &dialog_id : recent_replier_dialog_ids_) {
    if (dialog_id.get_type() != DialogType::User && !td->dialog_manager_->have_dialog_info(dialog_id)) {
      if (dialog_id.get_type() == DialogType::Channel &&
          td->chat_manager_->have_min_channel(dialog_id.get_channel_id())) {
        return false;
      }
      LOG(INFO) << "Reget a message because of replied " << dialog_id;
      return true;
    }
  }
  return false;
}

td_api::object_ptr<td_api::messageReplyInfo> MessageReplyInfo::get_message_reply_info_object(
    Td *td, MessageId dialog_last_read_inbox_message_id) const {
  if (is_empty()) {
    return nullptr;
  }

  vector<td_api::object_ptr<td_api::MessageSender>> recent_repliers;
  for (auto dialog_id : recent_replier_dialog_ids_) {
    auto recent_replier = get_min_message_sender_object(td, dialog_id, "get_message_reply_info_object");
    if (recent_replier != nullptr) {
      recent_repliers.push_back(std::move(recent_replier));
    }
  }
  auto last_read_inbox_message_id = last_read_inbox_message_id_;
  if (last_read_inbox_message_id.is_valid() && last_read_inbox_message_id < dialog_last_read_inbox_message_id) {
    last_read_inbox_message_id = min(dialog_last_read_inbox_message_id, max_message_id_);
  }
  return td_api::make_object<td_api::messageReplyInfo>(reply_count_, std::move(recent_repliers),
                                                       last_read_inbox_message_id.get(),
                                                       last_read_outbox_message_id_.get(), max_message_id_.get());
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReplyInfo &reply_info) {
  if (reply_info.is_comment_) {
    return string_builder << reply_info.reply_count_ << " comments in " << reply_info.channel_id_ << " by "
                          << reply_info.recent_replier_dialog_ids_ << " read up to "
                          << reply_info.last_read_inbox_message_id_ << '/' << reply_info.last_read_outbox_message_id_
                          << " with PTS " << reply_info.pts_;
  } else {
    return string_builder << reply_info.reply_count_ << " replies read up to " << reply_info.last_read_inbox_message_id_
                          << "/" << reply_info.last_read_outbox_message_id_ << " with PTS " << reply_info.pts_;
  }
}

}  // namespace td
