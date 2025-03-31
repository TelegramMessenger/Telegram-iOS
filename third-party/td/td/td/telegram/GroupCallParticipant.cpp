//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/GroupCallParticipant.h"

#include "td/telegram/Global.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/logging.h"

#include <limits>

namespace td {

GroupCallParticipant::GroupCallParticipant(const tl_object_ptr<telegram_api::groupCallParticipant> &participant,
                                           int32 call_version) {
  CHECK(participant != nullptr);
  dialog_id = DialogId(participant->peer_);
  about = participant->about_;
  audio_source = participant->source_;
  server_is_muted_by_themselves = participant->can_self_unmute_;
  server_is_muted_by_admin = participant->muted_ && !participant->can_self_unmute_;
  server_is_muted_locally = participant->muted_by_you_;
  is_self = participant->self_;
  if ((participant->flags_ & telegram_api::groupCallParticipant::VOLUME_MASK) != 0) {
    volume_level = participant->volume_;
    if (volume_level < MIN_VOLUME_LEVEL || volume_level > MAX_VOLUME_LEVEL) {
      LOG(ERROR) << "Receive " << to_string(participant);
      volume_level = 10000;
    }
    is_volume_level_local = !participant->volume_by_admin_;
  }
  if (!participant->left_) {
    joined_date = participant->date_;
    if ((participant->flags_ & telegram_api::groupCallParticipant::ACTIVE_DATE_MASK) != 0) {
      active_date = participant->active_date_;
    }
    if (joined_date <= 0 || active_date < 0) {
      LOG(ERROR) << "Receive invalid active_date/joined_date in " << to_string(participant);
      joined_date = 1;
      active_date = 0;
    }
    if ((participant->flags_ & telegram_api::groupCallParticipant::RAISE_HAND_RATING_MASK) != 0) {
      raise_hand_rating = participant->raise_hand_rating_;
      if (raise_hand_rating < 0) {
        LOG(ERROR) << "Receive invalid raise_hand_rating in " << to_string(participant);
        raise_hand_rating = 0;
      }
    }
  }
  is_just_joined = participant->just_joined_;
  is_min = participant->min_;
  version = call_version;

  if (participant->video_ != nullptr) {
    video_payload = GroupCallVideoPayload(participant->video_.get());
  }
  if (participant->presentation_ != nullptr) {
    if (participant->presentation_->flags_ & telegram_api::groupCallParticipantVideo::AUDIO_SOURCE_MASK) {
      presentation_audio_source = participant->presentation_->audio_source_;
    }
    presentation_payload = GroupCallVideoPayload(participant->presentation_.get());
  }

  if (is_just_joined && get_has_video()) {
    video_diff++;
  }
}

bool GroupCallParticipant::is_versioned_update(const tl_object_ptr<telegram_api::groupCallParticipant> &participant) {
  // updates about new and left participants must be applied as versioned, even they don't increase version
  return participant->just_joined_ || participant->left_ || participant->versioned_;
}

GroupCallParticipantOrder GroupCallParticipant::get_real_order(bool can_self_unmute, bool joined_date_asc) const {
  auto sort_active_date = td::max(active_date, local_active_date);
  if (sort_active_date == 0 && !get_is_muted_by_admin()) {  // if the participant isn't muted by admin
    if (get_is_muted_by_themselves()) {
      sort_active_date = joined_date;
    } else {
      sort_active_date = G()->unix_time();
    }
  }
  if (sort_active_date < G()->unix_time() - 300) {
    sort_active_date = 0;
  }
  auto sort_raise_hand_rating = can_self_unmute ? raise_hand_rating : 0;
  auto sort_joined_date = joined_date_asc ? std::numeric_limits<int32>::max() - joined_date : joined_date;
  bool has_video = !video_payload.is_empty() || !presentation_payload.is_empty();
  return GroupCallParticipantOrder(has_video, sort_active_date, sort_raise_hand_rating, sort_joined_date);
}

GroupCallParticipantOrder GroupCallParticipant::get_server_order(bool can_self_unmute, bool joined_date_asc) const {
  auto sort_active_date = active_date;
  if (sort_active_date == 0 && !server_is_muted_by_admin) {  // if the participant isn't muted by admin
    if (server_is_muted_by_themselves) {
      sort_active_date = joined_date;
    } else {
      sort_active_date = G()->unix_time();
    }
  }
  auto sort_raise_hand_rating = can_self_unmute ? raise_hand_rating : 0;
  auto sort_joined_date = joined_date_asc ? std::numeric_limits<int32>::max() - joined_date : joined_date;
  bool has_video = !video_payload.is_empty() || !presentation_payload.is_empty();
  return GroupCallParticipantOrder(has_video, sort_active_date, sort_raise_hand_rating, sort_joined_date);
}

bool GroupCallParticipant::get_is_muted_by_themselves() const {
  return have_pending_is_muted ? pending_is_muted_by_themselves : server_is_muted_by_themselves;
}

bool GroupCallParticipant::get_is_muted_by_admin() const {
  return have_pending_is_muted ? pending_is_muted_by_admin : server_is_muted_by_admin;
}

bool GroupCallParticipant::get_is_muted_locally() const {
  return have_pending_is_muted ? pending_is_muted_locally : server_is_muted_locally;
}

bool GroupCallParticipant::get_is_muted_for_all_users() const {
  return get_is_muted_by_admin() || get_is_muted_by_themselves();
}

int32 GroupCallParticipant::get_volume_level() const {
  return pending_volume_level != 0 ? pending_volume_level : volume_level;
}

bool GroupCallParticipant::get_is_hand_raised() const {
  return have_pending_is_hand_raised ? pending_is_hand_raised : raise_hand_rating != 0;
}

int32 GroupCallParticipant::get_has_video() const {
  return video_payload.is_empty() && presentation_payload.is_empty() ? 0 : 1;
}

void GroupCallParticipant::update_from(const GroupCallParticipant &old_participant) {
  CHECK(!old_participant.is_min);
  if (joined_date < old_participant.joined_date) {
    LOG(ERROR) << "Join date of " << old_participant.dialog_id << " decreased from " << old_participant.joined_date
               << " to " << joined_date;
    joined_date = old_participant.joined_date;
  }
  if (active_date < old_participant.active_date) {
    active_date = old_participant.active_date;
  }
  local_active_date = old_participant.local_active_date;
  is_speaking = old_participant.is_speaking;
  if (is_min) {
    server_is_muted_locally = old_participant.server_is_muted_locally;

    if (old_participant.is_volume_level_local && !is_volume_level_local) {
      is_volume_level_local = true;
      volume_level = old_participant.volume_level;
    }

    if (audio_source == old_participant.audio_source) {
      is_self = old_participant.is_self;
    }
  }
  is_min = false;

  pending_volume_level = old_participant.pending_volume_level;
  pending_volume_level_generation = old_participant.pending_volume_level_generation;

  have_pending_is_muted = old_participant.have_pending_is_muted;
  pending_is_muted_by_themselves = old_participant.pending_is_muted_by_themselves;
  pending_is_muted_by_admin = old_participant.pending_is_muted_by_admin;
  pending_is_muted_locally = old_participant.pending_is_muted_locally;
  pending_is_muted_generation = old_participant.pending_is_muted_generation;

  have_pending_is_hand_raised = old_participant.have_pending_is_hand_raised;
  pending_is_hand_raised = old_participant.pending_is_hand_raised;
  pending_is_hand_raised_generation = old_participant.pending_is_hand_raised_generation;
}

bool GroupCallParticipant::update_can_be_muted(bool can_manage, bool is_admin) {
  bool is_muted_by_admin = get_is_muted_by_admin();
  bool is_muted_by_themselves = get_is_muted_by_themselves();
  bool is_muted_locally = get_is_muted_locally();

  CHECK(!is_muted_by_admin || !is_muted_by_themselves);

  bool new_can_be_muted_for_all_users = false;
  bool new_can_be_unmuted_for_all_users = false;
  bool new_can_be_muted_only_for_self = !can_manage && !is_muted_locally;
  bool new_can_be_unmuted_only_for_self = !can_manage && is_muted_locally;
  if (is_self) {
    // current user can be muted if !is_muted_by_themselves && !is_muted_by_admin; after that is_muted_by_themselves
    // current user can be unmuted if is_muted_by_themselves; after that !is_muted
    new_can_be_muted_for_all_users = !is_muted_by_themselves && !is_muted_by_admin;
    new_can_be_unmuted_for_all_users = is_muted_by_themselves;
    new_can_be_muted_only_for_self = false;
    new_can_be_unmuted_only_for_self = false;
  } else if (is_admin) {
    // admin user can be muted if can_manage && !is_muted_by_themselves; after that is_muted_by_themselves
    // admin user can't be unmuted
    new_can_be_muted_for_all_users = can_manage && !is_muted_by_themselves;
  } else {
    // other users can be muted if can_manage && !is_muted_by_admin; after that is_muted_by_admin
    // other users can be unmuted if can_manage && is_muted_by_admin; after that is_muted_by_themselves
    new_can_be_muted_for_all_users = can_manage && !is_muted_by_admin;
    new_can_be_unmuted_for_all_users = can_manage && is_muted_by_admin;
  }
  CHECK(static_cast<int>(new_can_be_muted_for_all_users) + static_cast<int>(new_can_be_unmuted_for_all_users) +
            static_cast<int>(new_can_be_muted_only_for_self) + static_cast<int>(new_can_be_unmuted_only_for_self) <=
        1);
  if (new_can_be_muted_for_all_users != can_be_muted_for_all_users ||
      new_can_be_unmuted_for_all_users != can_be_unmuted_for_all_users ||
      new_can_be_muted_only_for_self != can_be_muted_only_for_self ||
      new_can_be_unmuted_only_for_self != can_be_unmuted_only_for_self) {
    can_be_muted_for_all_users = new_can_be_muted_for_all_users;
    can_be_unmuted_for_all_users = new_can_be_unmuted_for_all_users;
    can_be_muted_only_for_self = new_can_be_muted_only_for_self;
    can_be_unmuted_only_for_self = new_can_be_unmuted_only_for_self;
    return true;
  }
  return false;
}

bool GroupCallParticipant::set_pending_is_muted(bool is_muted, bool can_manage, bool is_admin) {
  update_can_be_muted(can_manage, is_admin);
  if (is_muted) {
    if (!can_be_muted_for_all_users && !can_be_muted_only_for_self) {
      return false;
    }
    CHECK(!can_be_muted_for_all_users || !can_be_muted_only_for_self);
  } else {
    if (!can_be_unmuted_for_all_users && !can_be_unmuted_only_for_self) {
      return false;
    }
    CHECK(!can_be_unmuted_for_all_users || !can_be_unmuted_only_for_self);
  }

  if (is_self) {
    pending_is_muted_by_themselves = is_muted;
    pending_is_muted_by_admin = false;
    pending_is_muted_locally = false;
  } else {
    pending_is_muted_by_themselves = get_is_muted_by_themselves();
    pending_is_muted_by_admin = get_is_muted_by_admin();
    pending_is_muted_locally = get_is_muted_locally();
    if (is_muted) {
      if (can_be_muted_only_for_self) {
        // local mute
        pending_is_muted_locally = true;
      } else {
        // admin mute
        CHECK(can_be_muted_for_all_users);
        CHECK(can_manage);
        if (is_admin) {
          CHECK(!pending_is_muted_by_themselves);
          pending_is_muted_by_admin = false;
          pending_is_muted_by_themselves = true;
        } else {
          CHECK(!pending_is_muted_by_admin);
          pending_is_muted_by_admin = true;
          pending_is_muted_by_themselves = false;
        }
      }
    } else {
      if (can_be_unmuted_only_for_self) {
        // local unmute
        pending_is_muted_locally = false;
      } else {
        // admin unmute
        CHECK(can_be_unmuted_for_all_users);
        CHECK(can_manage);
        CHECK(!is_admin);
        pending_is_muted_by_admin = false;
        pending_is_muted_by_themselves = true;
      }
    }
  }

  have_pending_is_muted = true;
  update_can_be_muted(can_manage, is_admin);
  return true;
}

td_api::object_ptr<td_api::groupCallParticipant> GroupCallParticipant::get_group_call_participant_object(Td *td) const {
  if (!is_valid()) {
    return nullptr;
  }

  return td_api::make_object<td_api::groupCallParticipant>(
      get_message_sender_object(td, dialog_id, "get_group_call_participant_object"), audio_source,
      presentation_audio_source, video_payload.get_group_call_participant_video_info_object(),
      presentation_payload.get_group_call_participant_video_info_object(), about, is_self, is_speaking,
      get_is_hand_raised(), can_be_muted_for_all_users, can_be_unmuted_for_all_users, can_be_muted_only_for_self,
      can_be_unmuted_only_for_self, get_is_muted_for_all_users(), get_is_muted_locally(), get_is_muted_by_themselves(),
      get_volume_level(), order.get_group_call_participant_order_object());
}

bool operator==(const GroupCallParticipant &lhs, const GroupCallParticipant &rhs) {
  return lhs.dialog_id == rhs.dialog_id && lhs.audio_source == rhs.audio_source &&
         lhs.presentation_audio_source == rhs.presentation_audio_source && lhs.video_payload == rhs.video_payload &&
         lhs.presentation_payload == rhs.presentation_payload && lhs.about == rhs.about && lhs.is_self == rhs.is_self &&
         lhs.is_speaking == rhs.is_speaking && lhs.get_is_hand_raised() == rhs.get_is_hand_raised() &&
         lhs.can_be_muted_for_all_users == rhs.can_be_muted_for_all_users &&
         lhs.can_be_unmuted_for_all_users == rhs.can_be_unmuted_for_all_users &&
         lhs.can_be_muted_only_for_self == rhs.can_be_muted_only_for_self &&
         lhs.can_be_unmuted_only_for_self == rhs.can_be_unmuted_only_for_self &&
         lhs.get_is_muted_for_all_users() == rhs.get_is_muted_for_all_users() &&
         lhs.get_is_muted_locally() == rhs.get_is_muted_locally() &&
         lhs.get_is_muted_by_themselves() == rhs.get_is_muted_by_themselves() &&
         lhs.get_volume_level() == rhs.get_volume_level() && lhs.order == rhs.order;
}

bool operator!=(const GroupCallParticipant &lhs, const GroupCallParticipant &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const GroupCallParticipant &group_call_participant) {
  return string_builder << "GroupCallParticipant[" << group_call_participant.dialog_id << " with source "
                        << group_call_participant.audio_source << " and order " << group_call_participant.order << ']';
}

}  // namespace td
