//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MediaArea.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"

#include "td/utils/emoji.h"
#include "td/utils/logging.h"

#include <cmath>

namespace td {

MediaArea::MediaArea(Td *td, telegram_api::object_ptr<telegram_api::MediaArea> &&media_area_ptr) {
  CHECK(media_area_ptr != nullptr);
  switch (media_area_ptr->get_id()) {
    case telegram_api::mediaAreaGeoPoint::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaGeoPoint>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      location_ = Location(td, area->geo_);
      if (area->address_ != nullptr) {
        address_.country_iso2_ = area->address_->country_iso2_;
        address_.state_ = area->address_->state_;
        address_.city_ = area->address_->city_;
        address_.street_ = area->address_->street_;
      }
      if (coordinates_.is_valid() && !location_.empty()) {
        type_ = Type::Location;
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaVenue::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaVenue>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      venue_ = Venue(td, area->geo_, std::move(area->title_), std::move(area->address_), std::move(area->provider_),
                     std::move(area->venue_id_), std::move(area->venue_type_));
      if (coordinates_.is_valid() && !venue_.empty()) {
        type_ = Type::Venue;
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaSuggestedReaction::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaSuggestedReaction>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      reaction_type_ = ReactionType(area->reaction_);
      is_dark_ = area->dark_;
      is_flipped_ = area->flipped_;
      if (coordinates_.is_valid() && !reaction_type_.is_empty() && !reaction_type_.is_paid_reaction()) {
        type_ = Type::Reaction;
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaChannelPost::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaChannelPost>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      auto channel_id = ChannelId(area->channel_id_);
      auto server_message_id = ServerMessageId(area->msg_id_);
      if (coordinates_.is_valid() && channel_id.is_valid() && server_message_id.is_valid()) {
        type_ = Type::Message;
        message_full_id_ = MessageFullId(DialogId(channel_id), MessageId(server_message_id));
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaUrl::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaUrl>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      if (coordinates_.is_valid()) {
        type_ = Type::Url;
        url_ = std::move(area->url_);
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaWeather::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaWeather>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      if (coordinates_.is_valid() && is_emoji(area->emoji_) && std::isfinite(area->temperature_c_)) {
        type_ = Type::Weather;
        url_ = std::move(area->emoji_);
        temperature_ = area->temperature_c_;
        color_ = area->color_;
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::mediaAreaStarGift::ID: {
      auto area = telegram_api::move_object_as<telegram_api::mediaAreaStarGift>(media_area_ptr);
      coordinates_ = MediaAreaCoordinates(area->coordinates_);
      if (coordinates_.is_valid() && !area->slug_.empty()) {
        type_ = Type::StarGift;
        url_ = std::move(area->slug_);
      } else {
        LOG(ERROR) << "Receive " << to_string(area);
      }
      break;
    }
    case telegram_api::inputMediaAreaVenue::ID:
      LOG(ERROR) << "Receive " << to_string(media_area_ptr);
      break;
    case telegram_api::inputMediaAreaChannelPost::ID:
      LOG(ERROR) << "Receive " << to_string(media_area_ptr);
      break;
    default:
      UNREACHABLE();
  }
}

MediaArea::MediaArea(Td *td, td_api::object_ptr<td_api::inputStoryArea> &&input_story_area,
                     const vector<MediaArea> &old_media_areas) {
  if (input_story_area == nullptr || input_story_area->position_ == nullptr || input_story_area->type_ == nullptr) {
    return;
  }
  coordinates_ = MediaAreaCoordinates(input_story_area->position_);
  if (!coordinates_.is_valid()) {
    return;
  }
  switch (input_story_area->type_->get_id()) {
    case td_api::inputStoryAreaTypeLocation::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeLocation>(input_story_area->type_);
      location_ = Location(type->location_);
      if (type->address_ != nullptr) {
        address_.country_iso2_ = std::move(type->address_->country_code_);
        address_.state_ = std::move(type->address_->state_);
        address_.city_ = std::move(type->address_->city_);
        address_.street_ = std::move(type->address_->street_);
        if (!clean_input_string(address_.country_iso2_) || !clean_input_string(address_.state_) ||
            !clean_input_string(address_.city_) || !clean_input_string(address_.street_)) {
          break;
        }
      }
      if (!location_.empty()) {
        type_ = Type::Location;
      }
      break;
    }
    case td_api::inputStoryAreaTypeFoundVenue::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeFoundVenue>(input_story_area->type_);
      const InlineMessageContent *inline_message_content =
          td->inline_queries_manager_->get_inline_message_content(type->query_id_, type->result_id_);
      if (inline_message_content == nullptr || inline_message_content->message_content == nullptr) {
        break;
      }
      auto venue_ptr = get_message_content_venue(inline_message_content->message_content.get());
      if (venue_ptr == nullptr || venue_ptr->empty()) {
        break;
      }
      venue_ = *venue_ptr;
      input_query_id_ = type->query_id_;
      input_result_id_ = std::move(type->result_id_);
      type_ = Type::Venue;
      break;
    }
    case td_api::inputStoryAreaTypePreviousVenue::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypePreviousVenue>(input_story_area->type_);
      for (auto &old_media_area : old_media_areas) {
        if (old_media_area.type_ == Type::Venue && !old_media_area.venue_.empty() &&
            old_media_area.venue_.is_same(type->venue_provider_, type->venue_id_)) {
          venue_ = old_media_area.venue_;
          input_query_id_ = old_media_area.input_query_id_;
          input_result_id_ = old_media_area.input_result_id_;
          type_ = Type::Venue;
          break;
        }
      }
      break;
    }
    case td_api::inputStoryAreaTypeSuggestedReaction::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeSuggestedReaction>(input_story_area->type_);
      reaction_type_ = ReactionType(type->reaction_type_);
      is_dark_ = type->is_dark_;
      is_flipped_ = type->is_flipped_;
      if (!reaction_type_.is_empty() && !reaction_type_.is_paid_reaction()) {
        type_ = Type::Reaction;
      }
      break;
    }
    case td_api::inputStoryAreaTypeMessage::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeMessage>(input_story_area->type_);
      auto dialog_id = DialogId(type->chat_id_);
      auto message_id = MessageId(type->message_id_);
      auto message_full_id = MessageFullId(dialog_id, message_id);
      for (auto &old_media_area : old_media_areas) {
        if (old_media_area.type_ == Type::Message && old_media_area.message_full_id_ == message_full_id) {
          message_full_id_ = message_full_id;
          is_old_message_ = true;
          type_ = Type::Message;
          break;
        }
      }
      if (!is_old_message_) {
        if (!td->messages_manager_->can_share_message_in_story(message_full_id)) {
          break;
        }
        message_full_id_ = message_full_id;
        type_ = Type::Message;
      }
      break;
    }
    case td_api::inputStoryAreaTypeLink::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeLink>(input_story_area->type_);
      if (!clean_input_string(type->url_)) {
        break;
      }
      url_ = std::move(type->url_);
      type_ = Type::Url;
      break;
    }
    case td_api::inputStoryAreaTypeWeather::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeWeather>(input_story_area->type_);
      if (!clean_input_string(type->emoji_) || !is_emoji(type->emoji_) || !std::isfinite(type->temperature_)) {
        break;
      }
      url_ = std::move(type->emoji_);
      temperature_ = type->temperature_;
      color_ = type->background_color_;
      type_ = Type::Weather;
      break;
    }
    case td_api::inputStoryAreaTypeUpgradedGift::ID: {
      auto type = td_api::move_object_as<td_api::inputStoryAreaTypeUpgradedGift>(input_story_area->type_);
      if (!clean_input_string(type->gift_name_) || type->gift_name_.empty()) {
        break;
      }
      url_ = std::move(type->gift_name_);
      type_ = Type::StarGift;
      break;
    }
    default:
      UNREACHABLE();
  }
}

bool MediaArea::has_reaction_type(const ReactionType &reaction_type) const {
  return reaction_type_ == reaction_type;
}

td_api::object_ptr<td_api::storyArea> MediaArea::get_story_area_object(
    Td *td, const vector<std::pair<ReactionType, int32>> &reaction_counts) const {
  CHECK(is_valid());
  td_api::object_ptr<td_api::StoryAreaType> type;
  switch (type_) {
    case Type::Location:
      type = td_api::make_object<td_api::storyAreaTypeLocation>(
          location_.get_location_object(),
          address_.is_empty() ? nullptr
                              : td_api::make_object<td_api::locationAddress>(address_.country_iso2_, address_.state_,
                                                                             address_.city_, address_.street_));
      break;
    case Type::Venue:
      type = td_api::make_object<td_api::storyAreaTypeVenue>(venue_.get_venue_object());
      break;
    case Type::Reaction: {
      int32 total_count = 0;
      for (const auto &reaction_count : reaction_counts) {
        if (reaction_count.first == reaction_type_) {
          total_count = reaction_count.second;
        }
      }
      type = td_api::make_object<td_api::storyAreaTypeSuggestedReaction>(reaction_type_.get_reaction_type_object(),
                                                                         total_count, is_dark_, is_flipped_);
      break;
    }
    case Type::Message:
      type = td_api::make_object<td_api::storyAreaTypeMessage>(
          td->dialog_manager_->get_chat_id_object(message_full_id_.get_dialog_id(), "storyAreaTypeMessage"),
          message_full_id_.get_message_id().get());
      break;
    case Type::Url:
      type = td_api::make_object<td_api::storyAreaTypeLink>(url_);
      break;
    case Type::Weather:
      type = td_api::make_object<td_api::storyAreaTypeWeather>(temperature_, url_, color_);
      break;
    case Type::StarGift:
      type = td_api::make_object<td_api::storyAreaTypeUpgradedGift>(url_);
      break;
    default:
      UNREACHABLE();
  }
  return td_api::make_object<td_api::storyArea>(coordinates_.get_story_area_position_object(), std::move(type));
}

telegram_api::object_ptr<telegram_api::MediaArea> MediaArea::get_input_media_area(const Td *td) const {
  CHECK(is_valid());
  switch (type_) {
    case Type::Location: {
      int32 flags = 0;
      telegram_api::object_ptr<telegram_api::geoPointAddress> address;
      if (!address_.is_empty()) {
        int32 address_flags = 0;
        if (!address_.state_.empty()) {
          address_flags |= telegram_api::geoPointAddress::STATE_MASK;
        }
        if (!address_.city_.empty()) {
          address_flags |= telegram_api::geoPointAddress::CITY_MASK;
        }
        if (!address_.street_.empty()) {
          address_flags |= telegram_api::geoPointAddress::STREET_MASK;
        }
        address = telegram_api::make_object<telegram_api::geoPointAddress>(
            address_flags, address_.country_iso2_, address_.state_, address_.city_, address_.street_);
        flags |= telegram_api::mediaAreaGeoPoint::ADDRESS_MASK;
      }

      return telegram_api::make_object<telegram_api::mediaAreaGeoPoint>(
          flags, coordinates_.get_input_media_area_coordinates(), location_.get_fake_geo_point(), std::move(address));
    }
    case Type::Venue:
      if (input_query_id_ != 0) {
        return telegram_api::make_object<telegram_api::inputMediaAreaVenue>(
            coordinates_.get_input_media_area_coordinates(), input_query_id_, input_result_id_);
      }
      return venue_.get_input_media_area_venue(coordinates_.get_input_media_area_coordinates());
    case Type::Reaction: {
      int32 flags = 0;
      if (is_dark_) {
        flags |= telegram_api::mediaAreaSuggestedReaction::DARK_MASK;
      }
      if (is_flipped_) {
        flags |= telegram_api::mediaAreaSuggestedReaction::FLIPPED_MASK;
      }
      return telegram_api::make_object<telegram_api::mediaAreaSuggestedReaction>(
          flags, false /*ignored*/, false /*ignored*/, coordinates_.get_input_media_area_coordinates(),
          reaction_type_.get_input_reaction());
    }
    case Type::Message: {
      auto channel_id = message_full_id_.get_dialog_id().get_channel_id();
      auto server_message_id = message_full_id_.get_message_id().get_server_message_id();
      if (!is_old_message_) {
        auto input_channel = td->chat_manager_->get_input_channel(channel_id);
        if (input_channel == nullptr) {
          return nullptr;
        }
        return telegram_api::make_object<telegram_api::inputMediaAreaChannelPost>(
            coordinates_.get_input_media_area_coordinates(), std::move(input_channel), server_message_id.get());
      }
      return telegram_api::make_object<telegram_api::mediaAreaChannelPost>(
          coordinates_.get_input_media_area_coordinates(), channel_id.get(), server_message_id.get());
    }
    case Type::Url:
      return telegram_api::make_object<telegram_api::mediaAreaUrl>(coordinates_.get_input_media_area_coordinates(),
                                                                   url_);
    case Type::Weather:
      return telegram_api::make_object<telegram_api::mediaAreaWeather>(coordinates_.get_input_media_area_coordinates(),
                                                                       url_, temperature_, color_);
    case Type::StarGift:
      return telegram_api::make_object<telegram_api::mediaAreaStarGift>(coordinates_.get_input_media_area_coordinates(),
                                                                        url_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

vector<telegram_api::object_ptr<telegram_api::MediaArea>> MediaArea::get_input_media_areas(
    const Td *td, const vector<MediaArea> &media_areas) {
  vector<telegram_api::object_ptr<telegram_api::MediaArea>> input_media_areas;
  for (const auto &media_area : media_areas) {
    auto input_media_area = media_area.get_input_media_area(td);
    if (input_media_area != nullptr) {
      input_media_areas.push_back(std::move(input_media_area));
    }
  }
  return input_media_areas;
}

void MediaArea::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_dialog_and_dependencies(message_full_id_.get_dialog_id());
}

bool operator==(const MediaArea &lhs, const MediaArea &rhs) {
  return lhs.type_ == rhs.type_ && lhs.coordinates_ == rhs.coordinates_ && lhs.location_ == rhs.location_ &&
         lhs.venue_ == rhs.venue_ && lhs.message_full_id_ == rhs.message_full_id_ &&
         lhs.input_query_id_ == rhs.input_query_id_ && lhs.input_result_id_ == rhs.input_result_id_ &&
         lhs.reaction_type_ == rhs.reaction_type_ && std::fabs(lhs.temperature_ - rhs.temperature_) < 1e-6 &&
         lhs.color_ == rhs.color_ && lhs.is_dark_ == rhs.is_dark_ && lhs.is_flipped_ == rhs.is_flipped_ &&
         lhs.is_old_message_ == rhs.is_old_message_;
}

bool operator!=(const MediaArea &lhs, const MediaArea &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MediaArea &media_area) {
  return string_builder << "StoryArea[" << media_area.coordinates_ << ": " << media_area.location_ << '/'
                        << media_area.venue_ << '/' << media_area.reaction_type_ << '/' << media_area.message_full_id_
                        << '/' << media_area.temperature_ << ']';
}

}  // namespace td
