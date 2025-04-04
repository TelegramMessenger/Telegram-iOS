//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

constexpr int32 MTPROTO_LAYER = 200;

enum class Version : int32 {
  Initial,  // 0
  StoreFileId,
  AddKeyHashToSecretChat,
  AddDurationToAnimation,
  FixStoreGameWithoutAnimation,
  AddAccessHashToSecretChat,  // 5
  StoreFileOwnerId,
  StoreFileEncryptionKey,
  NetStatsCountDuration,
  FixWebPageInstantViewDatabase,
  FixMinUsers,  // 10
  FixPageBlockAudioEmptyFile,
  AddMessageInvoiceProviderData,
  AddCaptionEntities,
  AddVenueType,
  AddTermsOfService,  // 15
  AddContactVcard,
  AddMessageUnsupportedVersion,
  SupportInstantView2_0,
  AddNotificationGroupInfoMaxRemovedMessageId,
  SupportMinithumbnails,  // 20
  AddVideoCallsSupport,
  AddPhotoSizeSource,
  AddFolders,
  SupportPolls2_0,
  AddDiceEmoji,  // 25
  AddAnimationStickers,
  AddDialogPhotoHasAnimation,
  AddPhotoProgressiveSizes,
  AddLiveLocationHeading,
  AddLiveLocationProximityAlertDistance,  // 30
  SupportBannedChannels,
  RemovePhotoVolumeAndLocalId,
  Support64BitIds,
  AddInviteLinksRequiringApproval,
  AddKeyboardButtonFlags,  // 35
  AddAudioFlags,
  UseServerForwardAsCopy,
  AddMainDialogListPosition,
  AddVoiceNoteFlags,
  AddMessageStickerFlags,  // 40
  AddStickerSetListFlags,
  AddInputInvoiceFlags,
  AddVideoNoteFlags,
  AddMessageChatSetTtlFlags,
  AddMessageMediaSpoiler,  // 45
  MakeParticipantFlags64Bit,
  AddDocumentFlags,
  AddUserFlags2,
  AddMessageTextFlags,
  AddPageBlockChatLinkFlags,  // 50
  SupportRepliesInOtherChats,
  SupportMultipleSharedUsers,
  SupportMoreEmojiGroups,
  SupportStarGiveaways,
  Next
};

enum class DbVersion : int32 {
  CreateDialogDb = 3,
  AddMessageDbMediaIndex,
  AddMessageDb30MediaIndex,
  AddMessageDbFts,
  AddMessagesCallIndex,
  FixFileRemoteLocationKeyBug,
  AddNotificationsSupport,
  AddFolders,
  AddScheduledMessages,
  StorePinnedDialogsInBinlog,
  AddMessageThreadSupport,
  AddMessageThreadDatabase,
  Next
};

inline constexpr int32 current_db_version() {
  return static_cast<int32>(DbVersion::Next) - 1;
}

}  // namespace td
