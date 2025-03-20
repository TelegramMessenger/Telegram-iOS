import Foundation
import UIKit

public struct PresentationResources {
}

public enum PresentationResourceKey: Int32 {
    case rootNavigationIndefiniteActivity
    
    case rootTabContactsIcon
    case rootTabContactsSelectedIcon
    case rootTabChatsIcon
    case rootTabChatsSelectedIcon
    case rootTabSettingsIcon
    case rootTabSettingsSelectedIcon
    
    case navigationComposeIcon
    case navigationCallIcon
    case navigationInfoIcon
    case navigationShareIcon
    case navigationSearchIcon
    case navigationCompactSearchIcon
    case navigationCompactSearchWhiteIcon
    case navigationCompactTagsSearchIcon
    case navigationCompactTagsSearchWhiteIcon
    case navigationCalendarIcon
    case navigationMoreIcon
    case navigationMoreCircledIcon
    case navigationAddIcon
    case navigationPlayerCloseButton
    case navigationQrCodeIcon
    
    case navigationLiveLocationIcon
    
    case navigationPlayerRateActiveIcon
    case navigationPlayerRateInactiveIcon
    case navigationPlayerMaximizedRateActiveIcon
    case navigationPlayerMaximizedRateInactiveIcon
    
    case itemListDownArrow
    case itemListDisclosureArrow
    case disclosureOptionArrowsImage
    case itemListDisclosureLocked
    case itemListCheckIcon
    case itemListSecondaryCheckIcon
    case itemListPlusIcon
    case itemListRoundPlusIcon
    case itemListAccentDeleteIcon
    case itemListDeleteIcon
    case itemListDeleteIndicatorIcon
    case itemListReorderIndicatorIcon
    case itemListLinkIcon
    case itemListAddPersonIcon
    case itemListCreateGroupIcon
    case itemListAddExceptionIcon
    case itemListAddPhoneIcon
    case itemListAddPhotoIcon
    case itemListClearInputIcon
    case itemListStickerItemUnreadDot
    case itemListVerifiedPeerIcon
    case itemListCloudFetchIcon
    case itemListCloseIconImage
    case itemListRemoveIconImage
    case itemListMakeVisibleIcon
    case itemListMakeInvisibleIcon
    case itemListEditThemeIcon
    case itemListCornersTop
    case itemListCornersBottom
    case itemListCornersBoth
    case itemListKnob
    case itemListBlockAccentIcon
    case itemListBlockDestructiveIcon
    case itemListAddDeviceIcon
    case itemListResetIcon
    case itemListImageIcon
    case itemListCloudIcon
    case itemListTopicArrowIcon
    case itemListAddBoostsIcon
    case itemListPremiumIcon
    case itemListRoundTopupIcon
    case itemListRoundWithdrawIcon
    case itemListStatsIcon
    
    case statsReactionsIcon
    case statsForwardsIcon
    
    case itemListVoiceCallIcon
    case itemListVideoCallIcon
    
    case chatListLockTopUnlockedImage
    case chatListLockBottomUnlockedImage
    case chatListPending
    case chatListClockFrame
    case chatListClockMin
    case chatListSingleCheck
    case chatListDoubleCheck
    case chatListBadgeBackgroundActive
    case chatListBadgeBackgroundInactive
    case chatListBadgeBackgroundMention
    case chatListBadgeBackgroundInactiveMention
    case chatListBadgeBackgroundPinned
    case chatListMutedIcon
    case chatListVerifiedIcon
    case chatListPremiumIcon
    case chatListScamRegularIcon
    case chatListScamOutgoingIcon
    case chatListScamServiceIcon
    case chatListFakeRegularIcon
    case chatListFakeOutgoingIcon
    case chatListFakeServiceIcon
    case chatListSecretIcon
    case chatListStatusLockIcon
    case chatListTopicArrowIcon
    case chatListRecentStatusOnlineIcon
    case chatListRecentStatusOnlineHighlightedIcon
    case chatListRecentStatusOnlinePinnedIcon
    case chatListRecentStatusOnlinePanelIcon
    case chatListRecentStatusVoiceChatIcon
    case chatListRecentStatusVoiceChatHighlightedIcon
    case chatListRecentStatusVoiceChatPinnedIcon
    case chatListRecentStatusVoiceChatPanelIcon
    
    case chatListForwardedIcon
    case chatListStoryReplyIcon
    case chatListGiftIcon
    case chatListLocationIcon
    
    case chatListGeneralTopicIcon
    case chatListGeneralTopicSmallIcon

    case chatTitleLockIcon
    case chatTitleMuteIcon
    case chatPanelLockIcon
    case chatPanelBoostIcon
    
    case chatBubbleVerticalLineIncomingImage
    case chatBubbleVerticalLineOutgoingImage
    
    case chatBubbleArrowFreeImage
    case chatBubbleArrowIncomingImage
    case chatBubbleArrowOutgoingImage
    
    case chatBubbleCheckBubbleFullImage
    case chatBubbleBubblePartialImage
    case checkBubbleMediaFullImage
    case checkBubbleMediaPartialImage
    
    case chatBubbleConsumableContentIncomingIcon
    case chatBubbleConsumableContentOutgoingIcon
    case chatMediaConsumableContentIcon
    
    case chatBubbleMediaOverlayControlSecret
        
    case chatInstantVideoWithWallpaperBackgroundImage
    case chatInstantVideoWithoutWallpaperBackgroundImage
    
    case chatActionPhotoWithWallpaperBackgroundImage
    case chatActionPhotoWithoutWallpaperBackgroundImage
    
    case chatUnreadBarBackgroundImage
    
    case chatBubbleFileCloudFetchMediaIcon
    case chatBubbleFileCloudFetchIncomingIcon
    case chatBubbleFileCloudFetchOutgoingIcon
    case chatBubbleFileCloudFetchedIncomingIcon
    case chatBubbleFileCloudFetchedOutgoingIcon
    
    case chatBubbleReplyThumbnailPlayImage
    
    case chatBubbleDeliveryFailedIcon
    
    case chatInfoItemBackgroundImageWithWallpaper
    case chatInfoItemBackgroundImageWithoutWallpaper
    
    case chatInputPanelCloseIconImage
    case chatInputPanelPinnedListIconImage
    case chatInputPanelEncircledCloseIconImage
    case chatInputPanelVerticalSeparatorLineImage
    
    case chatInputPanelForwardIconImage
    case chatInputPanelReplyIconImage
    case chatInputPanelEditIconImage
    case chatInputPanelWebpageIconImage
    
    case chatInputMediaPanelAddPackButtonImage
    case chatInputMediaPanelAddedPackButtonImage
    case chatInputMediaPanelGridSetupImage
    case chatInputMediaPanelGridDismissImage

    case chatInputButtonPanelButtonHighlightImage
    case chatInputButtonPanelButtonShadowImage
    
    case chatInputTextFieldBackgroundImage
    case chatInputTextFieldClearImage
    case chatInputPanelSendIconImage
    case chatInputPanelSendButtonImage
    case chatInputPanelApplyIconImage
    case chatInputPanelApplyButtonImage
    case chatInputPanelScheduleIconImage
    case chatInputPanelScheduleButtonImage
    case chatInputPanelVoiceButtonImage
    case chatInputPanelVideoButtonImage
    case chatInputPanelExpandButtonImage
    case chatInputPanelVoiceActiveButtonImage
    case chatInputPanelVideoActiveButtonImage
    case chatInputPanelAttachmentButtonImage
    case chatInputPanelEditAttachmentButtonImage
    case chatInputPanelMediaRecordingDotImage
    case chatInputPanelMediaRecordingCancelArrowImage
    case chatInputTextFieldStickersImage
    case chatInputTextFieldInputButtonsImage
    case chatInputTextFieldKeyboardImage
    case chatInputTextFieldCommandsImage
    case chatInputTextFieldSilentPostOnImage
    case chatInputTextFieldSilentPostOffImage
    case chatInputTextFieldTimerImage
    case chatInputTextFieldScheduleImage
    case chatInputTextFieldGiftImage
    
    case chatInputSearchPanelUpImage
    case chatInputSearchPanelUpDisabledImage
    case chatInputSearchPanelDownImage
    case chatInputSearchPanelDownDisabledImage
    case chatInputSearchPanelCalendarImage
    case chatInputSearchPanelMembersImage
        
    case chatHistoryNavigationButtonBackground
    case chatHistoryNavigationButtonImage
    case chatHistoryNavigationUpButtonImage
    case chatHistoryMentionsButtonImage
    case chatHistoryReactionsButtonImage
    case chatHistoryNavigationButtonBadgeImage
    
    case chatMessageAttachedContentButtonIncoming
    case chatMessageAttachedContentHighlightedButtonIncoming
    case chatMessageAttachedContentButtonOutgoing
    case chatMessageAttachedContentHighlightedButtonOutgoing
    
    case chatMessageAttachedContentButtonIconInstantIncoming
    case chatMessageAttachedContentHighlightedButtonIconInstantIncomingWithWallpaper
    case chatMessageAttachedContentHighlightedButtonIconInstantIncomingWithoutWallpaper
    case chatMessageAttachedContentButtonIconInstantOutgoing
    case chatMessageAttachedContentHighlightedButtonIconInstantOutgoingWithWallpaper
    case chatMessageAttachedContentHighlightedButtonIconInstantOutgoingWithoutWallpaper
    
    case chatMessageAttachedContentButtonIconLinkIncoming
    case chatMessageAttachedContentHighlightedButtonIconLinkIncomingWithWallpaper
    case chatMessageAttachedContentHighlightedButtonIconLinkIncomingWithoutWallpaper
    case chatMessageAttachedContentButtonIconLinkOutgoing
    case chatMessageAttachedContentHighlightedButtonIconLinkOutgoingWithWallpaper
    case chatMessageAttachedContentHighlightedButtonIconLinkOutgoingWithoutWallpaper
    
    case chatCommandPanelArrowImage
    
    case sharedMediaFileDownloadStartIcon
    case sharedMediaFileDownloadPauseIcon
    case sharedMediaInstantViewIcon
    
    case chatInfoCallButtonImage
    
    case chatInstantMessageInfoBackgroundImage
    case chatInstantMessageMuteIconImage
    
    case chatBubbleIncomingCallButtonImage
    case chatBubbleOutgoingCallButtonImage
    
    case chatBubbleIncomingVideoCallButtonImage
    case chatBubbleOutgoingVideoCallButtonImage
        
    case callListOutgoingIcon
    case callListOutgoingVideoIcon
    case callListInfoButton
    
    case genericSearchBarLoupeImage
    case genericSearchBar
    
    case inAppNotificationBackground
    
    case groupInfoAdminsIcon
    case groupInfoPermissionsIcon
    case groupInfoMembersIcon
    
    case emptyChatListCheckIcon

    case chatFreeCommentButtonIcon
    case chatFreeNavigateButtonIcon
    case chatFreeShareButtonIcon
    case chatFreeCloseButtonIcon
    case chatFreeMoreButtonIcon
    
    case chatKeyboardActionButtonMessageIcon
    case chatKeyboardActionButtonLinkIcon
    case chatKeyboardActionButtonShareIcon
    case chatKeyboardActionButtonPhoneIcon
    case chatKeyboardActionButtonLocationIcon
    case chatKeyboardActionButtonPaymentIcon
    case chatKeyboardActionButtonProfileIcon
    case chatKeyboardActionButtonAddToChatIcon
    case chatKeyboardActionButtonWebAppIcon
    
    case chatGeneralThreadIcon
    case chatGeneralThreadIncomingIcon
    case chatGeneralThreadOutgoingIcon
    case chatGeneralThreadFreeIcon
    
    case uploadToneIcon
    
    case storyViewListLikeIcon
    case navigationPostStoryIcon
    case navigationSortIcon
    
    case chatReplyBackgroundTemplateIncomingImage
    case chatReplyBackgroundTemplateOutgoingDashedImage
    case chatReplyServiceBackgroundTemplateImage
    
    case chatBubbleCloseIcon
    
    case chatEmptyStateStarIcon
    case chatPlaceholderStarIcon
    case chatUserInfoWarningIcon
    
    case avatarPremiumLockBadgeBackground
    case avatarPremiumLockBadge
    case shareAvatarPremiumLockBadgeBackground
    case shareAvatarPremiumLockBadge
    
    case shareAvatarStarsLockBadgeBackground
    case shareAvatarStarsLockBadgeInnerBackground
    
    case sharedLinkIcon
    
    case hideIconImage
    case peerStatusLockedImage
    case expandDownArrowImage
    case expandSmallDownArrowImage
}

public enum ChatExpiredStoryIndicatorType: Hashable {
    case incoming
    case outgoing
    case free
}

public enum PresentationResourceParameterKey: Hashable {
    case chatOutgoingFullCheck(CGFloat)
    case chatOutgoingPartialCheck(CGFloat)
    case chatMediaFullCheck(CGFloat)
    case chatMediaPartialCheck(CGFloat)
    case chatFreeFullCheck(CGFloat, Bool)
    case chatFreePartialCheck(CGFloat, Bool)
    
    case chatListBadgeBackgroundActive(CGFloat)
    case chatListBadgeBackgroundActiveProvisional(CGFloat)
    case chatListBadgeBackgroundInactive(CGFloat)
    case chatListBadgeBackgroundInactiveProvisional(CGFloat)
    case chatListBadgeBackgroundMention(CGFloat)
    case badgeBackgroundReactions(CGFloat)
    case badgeBackgroundInactiveReactions(CGFloat)
    case chatListBadgeBackgroundInactiveMention(CGFloat)
    case chatListBadgeBackgroundPinned(CGFloat)
    case badgeBackgroundBorder(CGFloat)
    
    case chatBubbleMediaCorner(incoming: Bool, mainRadius: CGFloat, inset: CGFloat)
    
    case chatPrincipalThemeEssentialGraphics(hasWallpaper: Bool, bubbleCorners: PresentationChatBubbleCorners)
    case chatPrincipalThemeAdditionalGraphics(isCustomWallpaper: Bool, bubbleCorners: PresentationChatBubbleCorners)
    
    case chatBubbleLamp(incoming: Bool)
    case chatPsaInfo(color: UInt32)
    
    case chatMessageCommentsIcon(incoming: Bool)
    case chatMessageCommentsArrowIcon(incoming: Bool)
    case chatMessageCommentsUnreadDotIcon(incoming: Bool)
    case chatMessageRepliesIcon(incoming: Bool)
    
    case chatEntityKeyboardLock(color: UInt32)
    case chatInputMediaPanelGridDismissImage(color: UInt32)
    
    case statusAutoremoveIcon(isActive: Bool)
    
    case chatExpiredStoryIndicatorIcon(type: ChatExpiredStoryIndicatorType)
    case chatReplyStoryIndicatorIcon(type: ChatExpiredStoryIndicatorType)
}
