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
    case navigationMoreIcon
    case navigationAddIcon
    case navigationPlayerCloseButton
    
    case navigationLiveLocationIcon
    
    case navigationPlayerPlayIcon
    case navigationPlayerPauseIcon
    case navigationPlayerRateActiveIcon
    case navigationPlayerRateInactiveIcon
    case navigationPlayerMaximizedRateActiveIcon
    case navigationPlayerMaximizedRateInactiveIcon
    
    case itemListDownArrow
    case itemListDisclosureArrow
    case itemListCheckIcon
    case itemListSecondaryCheckIcon
    case itemListPlusIcon
    case itemListDeleteIndicatorIcon
    case itemListReorderIndicatorIcon
    case itemListAddPersonIcon
    case itemListCreateGroupIcon
    case itemListAddExceptionIcon
    case itemListAddPhoneIcon
    case itemListClearInputIcon
    case itemListStickerItemUnreadDot
    case itemListVerifiedPeerIcon
    case itemListCloudFetchIcon
    case itemListCloseIconImage
    case itemListMakeVisibleIcon
    case itemListMakeInvisibleIcon
    case itemListCornersTop
    case itemListCornersBottom
    case itemListCornersBoth
    
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
    case chatListScamRegularIcon
    case chatListScamOutgoingIcon
    case chatListScamServiceIcon
    case chatListSecretIcon
    case chatListRecentStatusOnlineIcon
    case chatListRecentStatusOnlineHighlightedIcon
    case chatListRecentStatusOnlinePinnedIcon
    case chatListRecentStatusOnlinePanelIcon

    case chatTitleLockIcon
    case chatTitleMuteIcon
    
    case chatBubbleVerticalLineIncomingImage
    case chatBubbleVerticalLineOutgoingImage
    
    case chatBubbleCheckBubbleFullImage
    case chatBubbleBubblePartialImage
    case checkBubbleMediaFullImage
    case checkBubbleMediaPartialImage
    
    case chatBubbleConsumableContentIncomingIcon
    case chatBubbleConsumableContentOutgoingIcon
    case chatMediaConsumableContentIcon
    
    case chatBubbleMediaOverlayControlSecret
    
    case chatBubbleSecretMediaIcon
    case chatBubbleSecretMediaCompactIcon
    
    case chatInstantVideoWithWallpaperBackgroundImage
    case chatInstantVideoWithoutWallpaperBackgroundImage
    
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
    case chatInputPanelEncircledCloseIconImage
    case chatInputPanelVerticalSeparatorLineImage
    
    case chatMediaInputPanelHighlightedIconImage
    case chatInputMediaPanelSavedStickersIconImage
    case chatInputMediaPanelRecentStickersIconImage
    case chatInputMediaPanelRecentGifsIconImage
    case chatInputMediaPanelTrendingIconImage
    case chatInputMediaPanelSettingsIconImage
    case chatInputMediaPanelAddPackButtonImage
    case chatInputMediaPanelAddedPackButtonImage
    case chatInputMediaPanelGridSetupImage
    case chatInputMediaPanelGridDismissImage
    
    case chatInputButtonPanelButtonImage
    case chatInputButtonPanelButtonHighlightedImage
    
    case chatInputTextFieldBackgroundImage
    case chatInputTextFieldClearImage
    case chatInputPanelSendButtonImage
    case chatInputPanelApplyButtonImage
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
    
    case chatInputSearchPanelUpImage
    case chatInputSearchPanelUpDisabledImage
    case chatInputSearchPanelDownImage
    case chatInputSearchPanelDownDisabledImage
    case chatInputSearchPanelCalendarImage
    case chatInputSearchPanelMembersImage
    
    case chatTitlePanelInfoImage
    case chatTitlePanelSearchImage
    case chatTitlePanelUnarchiveImage
    case chatTitlePanelMuteImage
    case chatTitlePanelUnmuteImage
    case chatTitlePanelCallImage
    case chatTitlePanelReportImage
    case chatTitlePanelGroupingImage
    
    case chatHistoryNavigationButtonImage
    case chatHistoryMentionsButtonImage
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
    
    case chatCommandPanelArrowImage
    
    case sharedMediaFileDownloadStartIcon
    case sharedMediaFileDownloadPauseIcon
    case sharedMediaInstantViewIcon
    
    case chatInfoCallButtonImage
    
    case chatInstantMessageInfoBackgroundImage
    case chatInstantMessageMuteIconImage
    
    case chatBubbleIncomingCallButtonImage
    case chatBubbleOutgoingCallButtonImage
        
    case callListOutgoingIcon
    case callListInfoButton
    
    case genericSearchBarLoupeImage
    case genericSearchBar
    
    case inAppNotificationBackground
    case inAppNotificationSecretChatIcon
    
    case groupInfoAdminsIcon
    case groupInfoPermissionsIcon
    case groupInfoMembersIcon
    
    case emptyChatListCheckIcon
}

public enum PresentationResourceParameterKey: Hashable {
    case chatOutgoingFullCheck(CGFloat)
    case chatOutgoingPartialCheck(CGFloat)
    case chatMediaFullCheck(CGFloat)
    case chatMediaPartialCheck(CGFloat)
    case chatFreeFullCheck(CGFloat, Bool)
    case chatFreePartialCheck(CGFloat, Bool)
    
    case chatListBadgeBackgroundActive(CGFloat)
    case chatListBadgeBackgroundInactive(CGFloat)
    case chatListBadgeBackgroundMention(CGFloat)
    case chatListBadgeBackgroundInactiveMention(CGFloat)
    case chatListBadgeBackgroundPinned(CGFloat)
    
    case chatBubbleMediaCorner(incoming: Bool, mainRadius: CGFloat, inset: CGFloat)
    
    case chatPrincipalThemeEssentialGraphics(hasWallpaper: Bool, bubbleCorners: PresentationChatBubbleCorners)
    case chatPrincipalThemeAdditionalGraphics(isCustomWallpaper: Bool, bubbleCorners: PresentationChatBubbleCorners)
    
    case chatBubbleLamp(incoming: Bool)
    case chatPsaInfo(color: UInt32)
}
