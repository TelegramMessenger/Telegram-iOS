//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class MessageContentType : int32 {
  None = -1,
  Text,
  Animation,
  Audio,
  Document,
  Photo,
  Sticker,
  Video,
  VoiceNote,
  Contact,
  Location,
  Venue,
  ChatCreate,
  ChatChangeTitle,
  ChatChangePhoto,
  ChatDeletePhoto,
  ChatDeleteHistory,
  ChatAddUsers,
  ChatJoinedByLink,
  ChatDeleteUser,
  ChatMigrateTo,
  ChannelCreate,
  ChannelMigrateFrom,
  PinMessage,
  Game,
  GameScore,
  ScreenshotTaken,
  ChatSetTtl,
  Unsupported,
  Call,
  Invoice,
  PaymentSuccessful,
  VideoNote,
  ContactRegistered,
  ExpiredPhoto,
  ExpiredVideo,
  LiveLocation,
  CustomServiceAction,
  WebsiteConnected,
  PassportDataSent,
  PassportDataReceived,
  Poll,
  Dice,
  ProximityAlertTriggered,
  GroupCall,
  InviteToGroupCall,
  ChatSetTheme,
  WebViewDataSent,
  WebViewDataReceived,
  GiftPremium,
  TopicCreate,
  TopicEdit,
  SuggestProfilePhoto,
  WriteAccessAllowed,
  RequestedDialog,
  WebViewWriteAccessAllowed,
  SetBackground,
  Story,
  WriteAccessAllowedByRequest,
  GiftCode,
  Giveaway,
  GiveawayLaunch,
  GiveawayResults,
  GiveawayWinners,
  ExpiredVideoNote,
  ExpiredVoiceNote,
  BoostApply,
  DialogShared,
  PaidMedia,
  PaymentRefunded,
  GiftStars,
  PrizeStars,
  StarGift,
  StarGiftUnique
};
// increase MessageUnsupported::CURRENT_VERSION each time a new message content type is added

StringBuilder &operator<<(StringBuilder &string_builder, MessageContentType content_type);

bool is_allowed_invert_caption_message_content(MessageContentType content_type);

bool is_allowed_media_group_content(MessageContentType content_type);

bool is_homogenous_media_group_content(MessageContentType content_type);

bool can_be_secret_message_content(MessageContentType content_type);

bool can_be_local_message_content(MessageContentType content_type);

bool is_service_message_content(MessageContentType content_type);

bool is_editable_message_content(MessageContentType content_type);

bool is_supported_reply_message_content(MessageContentType content_type);

bool is_expired_message_content(MessageContentType content_type);

MessageContentType get_expired_message_content_type(MessageContentType content_type);

bool can_have_message_content_caption(MessageContentType content_type);

bool can_send_message_content_to_secret_chat(MessageContentType content_type);

uint64 get_message_content_chain_id(MessageContentType content_type);

bool get_default_service_message_content_reactions_are_possible(MessageContentType content_type);

struct MessageContentTypeHash {
  uint32 operator()(MessageContentType content_type) const {
    return Hash<int32>()(static_cast<int32>(content_type));
  }
};

}  // namespace td
