import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPermissions

public final class ApplicationSpecificBoolNotice: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

public final class ApplicationSpecificVariantNotice: Codable {
    public let value: Bool
    
    public init(value: Bool) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.value ? 1 : 0) as Int32, forKey: "v")
    }
}

public final class ApplicationSpecificCounterNotice: Codable {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value, forKey: "v")
    }
}

public final class ApplicationSpecificTimestampNotice: Codable {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value, forKey: "v")
    }
}

public final class ApplicationSpecificTimestampAndCounterNotice: Codable {
    public let counter: Int32
    public let timestamp: Int32
    
    public init(counter: Int32, timestamp: Int32) {
        self.counter = counter
        self.timestamp = timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.counter = try container.decode(Int32.self, forKey: "v")
        self.timestamp = try container.decode(Int32.self, forKey: "t")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.counter, forKey: "v")
        try container.encode(self.timestamp, forKey: "t")
    }
}

public final class ApplicationSpecificInt64ArrayNotice: Codable {
    public let values: [Int64]
    
    public init(values: [Int64]) {
        self.values = values
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.values = try container.decode([Int64].self, forKey: "v")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.values, forKey: "v")
    }
}

private func noticeNamespace(namespace: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: namespace)
    return key
}

private func noticeKey(peerId: PeerId, key: Int32) -> ValueBoxKey {
    let v = ValueBoxKey(length: 8 + 4)
    v.setInt64(0, value: peerId.toInt64())
    v.setInt32(8, value: key)
    return v
}

private enum ApplicationSpecificGlobalNotice: Int32 {
    case secretChatInlineBotUsage = 0
    case secretChatLinkPreviews = 1
    case proxyAdsAcknowledgment = 2
    case chatMediaMediaRecordingTips = 3
    case profileCallTips = 4
    case setPublicChannelLink = 5
    case passcodeLockTips = 6
    case contactsPermissionWarning = 7
    case notificationsPermissionWarning = 8
    case volumeButtonToUnmuteTip = 9
    case archiveChatTips = 10
    case archiveIntroDismissed = 11
    case cellularDataPermissionWarning = 13
    case chatMessageSearchResultsTip = 14
    case chatMessageOptionsTip = 15
    case chatTextSelectionTip = 16
    case themeChangeTip = 17
    case callsTabTip = 18
    case chatFolderTips = 19
    case locationProximityAlertTip = 20
    case nextChatSuggestionTip = 21
    case dismissedTrendingStickerPacks = 22
    case chatForwardOptionsTip = 24
    case messageViewsPrivacyTips = 25
    case chatSpecificThemeLightPreviewTip = 26
    case chatSpecificThemeDarkPreviewTip = 27
    case interactiveEmojiSyncTip = 28
    case sharedMediaScrollingTooltip = 29
    case sharedMediaFastScrollingTooltip = 30
    case forcedPasswordSetup = 31
    case emojiTooltip = 32
    case audioTranscriptionSuggestion = 33
    case clearStorageDismissedTipSize = 34
    case dismissedTrendingEmojiPacks = 35
    case audioRateOptionsTip = 36
    case translationSuggestion = 37
    case sendWhenOnlineTip = 38
    case chatWallpaperLightPreviewTip = 39
    case chatWallpaperDarkPreviewTip = 40
    case displayChatListContacts = 41
    case displayChatListStoriesTooltip = 42
    case storiesCameraTooltip = 43
    case storiesDualCameraTooltip = 44
    case displayChatListArchiveTooltip = 45
    case displayStoryReactionTooltip = 46
    case storyStealthModeReplyCount = 47
    case viewOnceTooltip = 48
    case displayStoryUnmuteTooltip = 49
    case chatReplyOptionsTip = 50
    case displayStoryInteractionGuide = 51
    case replyQuoteTextSelectionTip = 53
    case multipleReactionsSuggestion = 56
    case savedMessagesChatsSuggestion = 57
    case voiceMessagesPlayOnceSuggestion = 58
    case incomingVoiceMessagePlayOnceTip = 59
    case outgoingVoiceMessagePlayOnceTip = 60
    case videoMessagesPlayOnceSuggestion = 61
    case incomingVideoMessagePlayOnceTip = 62
    case outgoingVideoMessagePlayOnceTip = 63
    case savedMessageTagLabelSuggestion = 65
    case dismissedBusinessBadge = 68
    case monetizationIntroDismissed = 70
    case businessBotMessageTooltip = 71
    case dismissedBusinessIntroBadge = 72
    case dismissedBusinessLinksBadge = 73
    case dismissedBusinessChatbotsBadge = 74
    case captionAboveMediaTooltip = 75
    case channelSendGiftTooltip = 76
    case starGiftWearTips = 77
    case channelSuggestTooltip = 78
    case multipleStoriesTooltip = 79
    case voiceMessagesPauseSuggestion = 80
    case videoMessagesPauseSuggestion = 81
    case voiceMessagesResumeTrimWarning = 82
    
    var key: ValueBoxKey {
        let v = ValueBoxKey(length: 4)
        v.setInt32(0, value: self.rawValue)
        return v
    }
}

private extension PermissionKind {
    var noticeKey: NoticeEntryKey? {
        switch self {
        case .contacts:
            return ApplicationSpecificNoticeKeys.contactsPermissionWarning()
        case .notifications:
            return ApplicationSpecificNoticeKeys.notificationsPermissionWarning()
        case .cellularData:
            return ApplicationSpecificNoticeKeys.cellularDataPermissionWarning()
        default:
            return nil
        }
    }
}

private struct ApplicationSpecificNoticeKeys {
    private static let botPaymentLiabilityNamespace: Int32 = 1
    private static let globalNamespace: Int32 = 2
    private static let permissionsNamespace: Int32 = 3
    private static let peerReportNamespace: Int32 = 4
    private static let inlineBotLocationRequestNamespace: Int32 = 5
    private static let psaAcknowledgementNamespace: Int32 = 6
    private static let botGameNoticeNamespace: Int32 = 7
    private static let peerInviteRequestsNamespace: Int32 = 8
    private static let dismissedPremiumGiftNamespace: Int32 = 9
    private static let groupEmojiPackNamespace: Int32 = 9
    private static let dismissedBirthdayPremiumGiftTipNamespace: Int32 = 10
    private static let displayedPeerVerificationNamespace: Int32 = 11
    private static let dismissedPaidMessageWarningNamespace: Int32 = 11
    
    static func inlineBotLocationRequestNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: inlineBotLocationRequestNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func botPaymentLiabilityNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botPaymentLiabilityNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func botGameNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botGameNoticeNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func irrelevantPeerGeoNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: peerReportNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func dismissedPremiumGiftNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: dismissedPremiumGiftNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func groupEmojiPackNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: groupEmojiPackNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func forcedPasswordSetup() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatInlineBotUsage.key)
    }
    
    static func secretChatInlineBotUsage() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatInlineBotUsage.key)
    }
    
    static func secretChatLinkPreviews() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatLinkPreviews.key)
    }
    
    static func archiveIntroDismissed() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.archiveIntroDismissed.key)
    }
    
    static func chatMediaMediaRecordingTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatMediaMediaRecordingTips.key)
    }
    
    static func archiveChatTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.archiveChatTips.key)
    }
    
    static func chatFolderTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatFolderTips.key)
    }
    
    static func profileCallTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.profileCallTips.key)
    }
    
    static func proxyAdsAcknowledgment() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.proxyAdsAcknowledgment.key)
    }
    
    static func psaAdsAcknowledgment(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: psaAcknowledgementNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func setPublicChannelLink() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.setPublicChannelLink.key)
    }
    
    static func passcodeLockTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.passcodeLockTips.key)
    }
    
    static func contactsPermissionWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: permissionsNamespace), key: ApplicationSpecificGlobalNotice.contactsPermissionWarning.key)
    }
    
    static func notificationsPermissionWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: permissionsNamespace), key: ApplicationSpecificGlobalNotice.notificationsPermissionWarning.key)
    }
    
    static func cellularDataPermissionWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: permissionsNamespace), key: ApplicationSpecificGlobalNotice.cellularDataPermissionWarning.key)
    }
    
    static func volumeButtonToUnmuteTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.volumeButtonToUnmuteTip.key)
    }
    
    static func callsTabTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.callsTabTip.key)
    }
    
    static func chatMessageSearchResultsTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatMessageSearchResultsTip.key)
    }
    
    static func chatMessageOptionsTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatMessageOptionsTip.key)
    }
    
    static func chatTextSelectionTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatTextSelectionTip.key)
    }

    static func messageViewsPrivacyTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.messageViewsPrivacyTips.key)
    }
    
    static func themeChangeTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.themeChangeTip.key)
    }
    
    static func locationProximityAlertTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.locationProximityAlertTip.key)
    }

    static func nextChatSuggestionTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.nextChatSuggestionTip.key)
    }
    
    static func dismissedTrendingStickerPacks() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedTrendingStickerPacks.key)
    }
    
    static func chatSpecificThemeLightPreviewTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatSpecificThemeLightPreviewTip.key)
    }
    
    static func chatSpecificThemeDarkPreviewTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatSpecificThemeDarkPreviewTip.key)
    }
    
    static func chatWallpaperLightPreviewTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatWallpaperLightPreviewTip.key)
    }
    
    static func chatWallpaperDarkPreviewTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatWallpaperDarkPreviewTip.key)
    }
    
    static func chatForwardOptionsTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatForwardOptionsTip.key)
    }
    
    static func chatReplyOptionsTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatReplyOptionsTip.key)
    }
    
    static func interactiveEmojiSyncTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.interactiveEmojiSyncTip.key)
    }
    
    static func dismissedInvitationRequestsNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: peerInviteRequestsNamespace), key: noticeKey(peerId: peerId, key: 0))
    }

    static func sharedMediaScrollingTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.sharedMediaScrollingTooltip.key)
    }

    static func sharedMediaFastScrollingTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.sharedMediaFastScrollingTooltip.key)
    }
    
    static func emojiTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.emojiTooltip.key)
    }
    
    static func audioTranscriptionSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.audioTranscriptionSuggestion.key)
    }
    
    static func clearStorageDismissedTipSize() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.clearStorageDismissedTipSize.key)
    }
    
    static func dismissedTrendingEmojiPacks() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedTrendingEmojiPacks.key)
    }
    
    static func translationSuggestionNotice() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.translationSuggestion.key)
    }
    
    static func audioRateOptionsTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.audioRateOptionsTip.key)
    }
    
    static func sendWhenOnlineTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.sendWhenOnlineTip.key)
    }
    
    static func displayChatListContacts() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayChatListContacts.key)
    }
    
    static func displayChatListStoriesTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayChatListStoriesTooltip.key)
    }
    
    static func storiesCameraTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.storiesCameraTooltip.key)
    }
    
    static func storiesDualCameraTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.storiesDualCameraTooltip.key)
    }
    
    static func displayChatListArchiveTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayChatListArchiveTooltip.key)
    }
    
    static func displayStoryReactionTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayStoryReactionTooltip.key)
    }
    
    static func storyStealthModeReplyCount() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.storyStealthModeReplyCount.key)
    }
    
    static func viewOnceTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.viewOnceTooltip.key)
    }
    
    static func displayStoryUnmuteTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayStoryUnmuteTooltip.key)
    }
    
    static func displayStoryInteractionGuide() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.displayStoryInteractionGuide.key)
    }
    
    static func replyQuoteTextSelectionTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.replyQuoteTextSelectionTip.key)
    }
    
    static func multipleReactionsSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.multipleReactionsSuggestion.key)
    }
    
    static func savedMessagesChatsSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.savedMessagesChatsSuggestion.key)
    }
    
    static func voiceMessagesPlayOnceSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.voiceMessagesPlayOnceSuggestion.key)
    }
    
    static func incomingVoiceMessagePlayOnceTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.incomingVoiceMessagePlayOnceTip.key)
    }
    
    static func outgoingVoiceMessagePlayOnceTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.outgoingVoiceMessagePlayOnceTip.key)
    }
    
    static func videoMessagesPlayOnceSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.videoMessagesPlayOnceSuggestion.key)
    }
    
    static func incomingVideoMessagePlayOnceTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.incomingVideoMessagePlayOnceTip.key)
    }
    
    static func outgoingVideoMessagePlayOnceTip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.outgoingVideoMessagePlayOnceTip.key)
    }
    
    static func savedMessageTagLabelSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.savedMessageTagLabelSuggestion.key)
    }
    
    static func dismissedBusinessBadge() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedBusinessBadge.key)
    }
        
    static func dismissedBirthdayPremiumGiftTip(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: dismissedBirthdayPremiumGiftTipNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func displayedPeerVerification(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: displayedPeerVerificationNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func dismissedPaidMessageWarning(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: dismissedPaidMessageWarningNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func monetizationIntroDismissed() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.monetizationIntroDismissed.key)
    }
    
    static func businessBotMessageTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.businessBotMessageTooltip.key)
    }
    
    static func dismissedBusinessIntroBadge() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedBusinessIntroBadge.key)
    }
    
    static func dismissedBusinessLinksBadge() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedBusinessLinksBadge.key)
    }
    
    static func dismissedBusinessChatbotsBadge() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.dismissedBusinessChatbotsBadge.key)
    }
    
    static func captionAboveMediaTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.captionAboveMediaTooltip.key)
    }
    
    static func channelSendGiftTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.channelSendGiftTooltip.key)
    }
    
    static func starGiftWearTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.starGiftWearTips.key)
    }
    
    static func channelSuggestTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.channelSuggestTooltip.key)
    }
    
    static func multipleStoriesTooltip() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.multipleStoriesTooltip.key)
    }
    
    static func voiceMessagesPauseSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.voiceMessagesPauseSuggestion.key)
    }
    
    static func videoMessagesPauseSuggestion() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.videoMessagesPauseSuggestion.key)
    }
    
    static func voiceMessagesResumeTrimWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.voiceMessagesResumeTrimWarning.key)
    }
}

public struct ApplicationSpecificNotice {
    public static func irrelevantPeerGeoReportKey(peerId: PeerId) -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.irrelevantPeerGeoNotice(peerId: peerId)
    }
    
    public static func setIrrelevantPeerGeoReport(engine: TelegramEngine, peerId: PeerId) -> Signal<Never, NoError> {
        return engine.notices.set(id: ApplicationSpecificNoticeKeys.irrelevantPeerGeoNotice(peerId: peerId), item: ApplicationSpecificBoolNotice())
    }
    
    public static func getBotPaymentLiability(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId))?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setBotPaymentLiability(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId), entry)
            }
        }
    }
    
    public static func getBotGameNotice(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.botGameNotice(peerId: peerId))?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setBotGameNotice(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.botGameNotice(peerId: peerId), entry)
            }
        }
    }
    
    public static func getInlineBotLocationRequest(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Int32?, NoError> {
        return accountManager.transaction { transaction -> Int32? in
            if let notice = transaction.getNotice(ApplicationSpecificNoticeKeys.inlineBotLocationRequestNotice(peerId: peerId))?.get(ApplicationSpecificTimestampNotice.self) {
                return notice.value
            } else {
                return nil
            }
        }
    }
    
    public static func inlineBotLocationRequestStatus(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.inlineBotLocationRequestNotice(peerId: peerId))
        |> map { view -> Bool in
            guard let value = view.value?.get(ApplicationSpecificTimestampNotice.self) else {
                return false
            }
            if value.value == 0 {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func updateInlineBotLocationRequestState(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, timestamp: Int32) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let notice = transaction.getNotice(ApplicationSpecificNoticeKeys.inlineBotLocationRequestNotice(peerId: peerId))?.get(ApplicationSpecificTimestampNotice.self), (notice.value == 0 || timestamp <= notice.value + 10 * 60) {
                return false
            }

            if let entry = CodableEntry(ApplicationSpecificTimestampNotice(value: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.inlineBotLocationRequestNotice(peerId: peerId), entry)
            }
            
            return true
        }
    }
    
    public static func setInlineBotLocationRequest(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, value: Int32) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificTimestampNotice(value: value)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.inlineBotLocationRequestNotice(peerId: peerId), entry)
            }
        }
    }
    
    public static func getSecretChatInlineBotUsage(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.secretChatInlineBotUsage())?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setSecretChatInlineBotUsage(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.secretChatInlineBotUsage(), entry)
            }
        }
    }
    
    public static func setSecretChatInlineBotUsage(transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
            transaction.setNotice(ApplicationSpecificNoticeKeys.secretChatInlineBotUsage(), entry)
        }
    }
    
    public static func getSecretChatLinkPreviews(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool?, NoError> {
        return accountManager.transaction { transaction -> Bool? in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.secretChatLinkPreviews())?.get(ApplicationSpecificVariantNotice.self) {
                return value.value
            } else {
                return nil
            }
        }
    }
    
    public static func getSecretChatLinkPreviews(_ entry: CodableEntry) -> Bool? {
        if let value = entry.get(ApplicationSpecificVariantNotice.self) {
            return value.value
        } else {
            return nil
        }
    }
    
    public static func setSecretChatLinkPreviews(accountManager: AccountManager<TelegramAccountManagerTypes>, value: Bool) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificVariantNotice(value: value)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.secretChatLinkPreviews(), entry)
            }
        }
    }
    
    public static func setSecretChatLinkPreviews(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, value: Bool) {
        if let entry = CodableEntry(ApplicationSpecificVariantNotice(value: value)) {
            transaction.setNotice(ApplicationSpecificNoticeKeys.secretChatLinkPreviews(), entry)
        }
    }
    
    public static func secretChatLinkPreviewsKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.secretChatLinkPreviews()
    }
    
    public static func getChatMediaMediaRecordingTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatMediaMediaRecordingTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips(), entry)
            }
        }
    }
    
    public static func getArchiveChatTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.archiveChatTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementArchiveChatTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.archiveChatTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.archiveChatTips(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func incrementChatFolderTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatFolderTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatFolderTips(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func setArchiveIntroDismissed(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, value: Bool) {
        if let entry = CodableEntry(ApplicationSpecificVariantNotice(value: value)) {
            transaction.setNotice(ApplicationSpecificNoticeKeys.archiveIntroDismissed(), entry)
        }
    }
    
    public static func archiveIntroDismissedKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.archiveIntroDismissed()
    }
    
    public static func getProfileCallTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.profileCallTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementProfileCallTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.profileCallTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.profileCallTips(), entry)
            }
        }
    }
    
    public static func getSetPublicChannelLink(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.profileCallTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value < 1
            } else {
                return true
            }
        }
    }
    
    public static func markAsSeenSetPublicChannelLink(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: 1)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.profileCallTips(), entry)
            }
        }
    }
    
    public static func getProxyAdsAcknowledgment(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.proxyAdsAcknowledgment())?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setProxyAdsAcknowledgment(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.proxyAdsAcknowledgment(), entry)
            }
        }
    }
    
    public static func getPsaAcknowledgment(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.psaAdsAcknowledgment(peerId: peerId))?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setPsaAcknowledgment(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.psaAdsAcknowledgment(peerId: peerId), entry)
            }
        }
    }
    
    public static func getPasscodeLockTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.passcodeLockTips())?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setPasscodeLockTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.passcodeLockTips(), entry)
            }
        }
    }
    
    public static func permissionWarningKey(permission: PermissionKind) -> NoticeEntryKey? {
        return permission.noticeKey
    }
    
    public static func setPermissionWarning(accountManager: AccountManager<TelegramAccountManagerTypes>, permission: PermissionKind, value: Int32) {
        guard let noticeKey = permission.noticeKey else {
            return
        }
        let _ = (accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificTimestampNotice(value: value)) {
                transaction.setNotice(noticeKey, entry)
            }
        }).start()
    }
    
    public static func getTimestampValue(_ entry: CodableEntry) -> Int32? {
        if let value = entry.get(ApplicationSpecificTimestampNotice.self) {
            return value.value
        } else {
            return nil
        }
    }
    
    public static func getVolumeButtonToUnmute(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.volumeButtonToUnmuteTip())?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setVolumeButtonToUnmute(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let _ = accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.volumeButtonToUnmuteTip(), entry)
            }
        }.start()
    }
    
    public static func getCallsTabTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.callsTabTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementCallsTabTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.callsTabTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += min(3, Int32(count))

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.callsTabTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func setCallsTabTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.callsTabTip(), entry)
            }
        }
    }
    
    
    public static func getChatMessageSearchResultsTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageSearchResultsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatMessageSearchResultsTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageSearchResultsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatMessageSearchResultsTip(), entry)
            }
        }
    }
    
    public static func getChatMessageOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatMessageOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip(), entry)
            }
        }
    }
    
    public static func getChatTextSelectionTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatTextSelectionTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatTextSelectionTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatTextSelectionTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatTextSelectionTip(), entry)
            }
        }
    }
    
    public static func getReplyQuoteTextSelectionTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.replyQuoteTextSelectionTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementReplyQuoteTextSelectionTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.replyQuoteTextSelectionTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.replyQuoteTextSelectionTip(), entry)
            }
        }
    }

    public static func getMessageViewsPrivacyTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.messageViewsPrivacyTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }

    public static func incrementMessageViewsPrivacyTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.messageViewsPrivacyTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.messageViewsPrivacyTips(), entry)
            }
        }
    }
    
    public static func getThemeChangeTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.themeChangeTip())?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func markThemeChangeTipAsSeen(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let _ = accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.themeChangeTip(), entry)
            }
        }.start()
    }
    
    public static func getLocationProximityAlertTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementLocationProximityAlertTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatMessageOptionsTip(), entry)
            }
        }
    }

    public static func getNextChatSuggestionTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.nextChatSuggestionTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }

    public static func incrementNextChatSuggestionTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.nextChatSuggestionTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.nextChatSuggestionTip(), entry)
            }
        }
    }

    public static func getSharedMediaScrollingTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sharedMediaScrollingTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }

    public static func incrementSharedMediaScrollingTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sharedMediaScrollingTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.sharedMediaScrollingTooltip(), entry)
            }
        }
    }

    public static func getSharedMediaFastScrollingTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sharedMediaFastScrollingTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }

    public static func incrementSharedMediaFastScrollingTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sharedMediaFastScrollingTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.sharedMediaFastScrollingTooltip(), entry)
            }
        }
    }
    
    public static func getEmojiTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.emojiTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }

    public static func incrementEmojiTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.emojiTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.emojiTooltip(), entry)
            }
        }
    }
    
    public static func dismissedTrendingStickerPacks(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<[Int64]?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedTrendingStickerPacks())
        |> map { view -> [Int64]? in
            if let value = view.value?.get(ApplicationSpecificInt64ArrayNotice.self) {
                return value.values
            } else {
                return nil
            }
        }
    }
    
    public static func setDismissedTrendingStickerPacks(accountManager: AccountManager<TelegramAccountManagerTypes>, values: [Int64]) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificInt64ArrayNotice(values: values)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedTrendingStickerPacks(), entry)
            }
        }
    }
    
    public static func dismissedTrendingEmojiPacks(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<[Int64]?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedTrendingEmojiPacks())
        |> map { view -> [Int64]? in
            if let value = view.value?.get(ApplicationSpecificInt64ArrayNotice.self) {
                return value.values
            } else {
                return nil
            }
        }
    }
    
    public static func setDismissedTrendingEmojiPacks(accountManager: AccountManager<TelegramAccountManagerTypes>, values: [Int64]) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificInt64ArrayNotice(values: values)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedTrendingEmojiPacks(), entry)
            }
        }
    }
    
    public static func getChatSpecificThemeLightPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.transaction { transaction -> (Int32, Int32) in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeLightPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementChatSpecificThemeLightPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1, timestamp: Int32) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeLightPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeLightPreviewTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChatSpecificThemeDarkPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.transaction { transaction -> (Int32, Int32) in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeDarkPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementChatSpecificThemeDarkPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1, timestamp: Int32) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeDarkPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatSpecificThemeDarkPreviewTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChatWallpaperLightPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.transaction { transaction -> (Int32, Int32) in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatWallpaperLightPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementChatWallpaperLightPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1, timestamp: Int32) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatWallpaperLightPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatWallpaperLightPreviewTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChatWallpaperDarkPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.transaction { transaction -> (Int32, Int32) in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatWallpaperDarkPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementChatWallpaperDarkPreviewTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1, timestamp: Int32) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatWallpaperDarkPreviewTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatWallpaperDarkPreviewTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChatForwardOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatForwardOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatForwardOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatForwardOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatForwardOptionsTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChatReplyOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatReplyOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChatReplyOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.chatReplyOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.chatReplyOptionsTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getClearStorageDismissedTipSize(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.clearStorageDismissedTipSize())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func setClearStorageDismissedTipSize(accountManager: AccountManager<TelegramAccountManagerTypes>, value: Int32) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.clearStorageDismissedTipSize(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func getInteractiveEmojiSyncTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.transaction { transaction -> (Int32, Int32) in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.interactiveEmojiSyncTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementInteractiveEmojiSyncTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1, timestamp: Int32) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.interactiveEmojiSyncTip())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.interactiveEmojiSyncTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func dismissedInvitationRequests(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<[Int64]?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedInvitationRequestsNotice(peerId: peerId))
        |> map { view -> [Int64]? in
            if let value = view.value?.get(ApplicationSpecificInt64ArrayNotice.self) {
                return value.values
            } else {
                return nil
            }
        }
    }
    
    public static func setDismissedInvitationRequests(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, values: [Int64]) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificInt64ArrayNotice(values: values)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedInvitationRequestsNotice(peerId: peerId), entry)
            }
        }
    }
    
    public static func forcedPasswordSetupKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.forcedPasswordSetup()
    }
    
    public static func setForcedPasswordSetup(engine: TelegramEngine, reloginDaysTimeout: Int32?) -> Signal<Never, NoError> {
        var item: ApplicationSpecificCounterNotice?
        if let reloginDaysTimeout = reloginDaysTimeout {
            item = ApplicationSpecificCounterNotice(value: reloginDaysTimeout)
        }
        return engine.notices.set(id: ApplicationSpecificNoticeKeys.forcedPasswordSetup(), item: item)
    }
    
    public static func audioTranscriptionSuggestionKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.audioTranscriptionSuggestion()
    }
    
    public static func getAudioTranscriptionSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.audioTranscriptionSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementAudioTranscriptionSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.audioTranscriptionSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.audioTranscriptionSuggestion(), entry)
            }
            
            return previousValue
        }
    }
        
    public static func translationSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<(Int32, Int32), NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.translationSuggestionNotice())
        |> map { view -> (Int32, Int32) in
            if let value = view.value?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                return (value.counter, value.timestamp)
            } else {
                return (0, 0)
            }
        }
    }
    
    public static func incrementTranslationSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1, timestamp: Int32) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            var currentValue: Int32 = 0
            var currentTimestamp: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.translationSuggestionNotice())?.get(ApplicationSpecificTimestampAndCounterNotice.self) {
                currentValue = value.counter
                currentTimestamp = value.timestamp
            }
            
            if currentTimestamp > timestamp {
                return Int32(currentValue)
            } else {
                let previousValue = currentValue
                currentValue = max(0, Int32(currentValue + count))
                
                if let entry = CodableEntry(ApplicationSpecificTimestampAndCounterNotice(counter: currentValue, timestamp: timestamp)) {
                    transaction.setNotice(ApplicationSpecificNoticeKeys.translationSuggestionNotice(), entry)
                }
                
                return Int32(previousValue)
            }
        }
    }
    
    public static func getAudioRateOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.audioRateOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementAudioRateOptionsTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.audioRateOptionsTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.audioRateOptionsTip(), entry)
            }
            return previousValue
        }
    }
    
    public static func dismissedPremiumGiftSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Int32?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedPremiumGiftNotice(peerId: peerId))
        |> map { view -> Int32? in
            if let value = view.value?.get(ApplicationSpecificTimestampNotice.self) {
                return value.value
            } else {
                return nil
            }
        }
    }
    
    public static func incrementDismissedPremiumGiftSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, timestamp: Int32) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificTimestampNotice(value: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedPremiumGiftNotice(peerId: peerId), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func groupEmojiPackSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Int32, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.groupEmojiPackNotice(peerId: peerId))
        |> map { view -> Int32 in
            if let value = view.value?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementGroupEmojiPackSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, count: Int32 = 1) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.groupEmojiPackNotice(peerId: peerId))?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += count
            
            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.groupEmojiPackNotice(peerId: peerId), entry)
            }
            return previousValue
        }
    }
    
    public static func getSendWhenOnlineTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sendWhenOnlineTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementSendWhenOnlineTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int32 = 1) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.sendWhenOnlineTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            currentValue += count

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.sendWhenOnlineTip(), entry)
            }
        }
    }
    
    public static func displayChatListContacts(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayChatListContacts())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setDisplayChatListContacts(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayChatListContacts(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func displayChatListStoriesTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayChatListStoriesTooltip())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setDisplayChatListStoriesTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayChatListStoriesTooltip(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func incrementStoriesCameraTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.storiesCameraTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.storiesCameraTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getStoriesDualCameraTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.storiesDualCameraTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementStoriesDualCameraTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.storiesDualCameraTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.storiesDualCameraTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func reset(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
        }
    }
    
    public static func displayChatListArchiveTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayChatListArchiveTooltip())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func setDisplayStoryReactionTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayStoryReactionTooltip(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func displayStoryReactionTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayStoryReactionTooltip())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func setDisplayChatListArchiveTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayChatListArchiveTooltip(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func storyStealthModeReplyCount(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.storyStealthModeReplyCount())
        |> map { view -> Int in
            if let value = view.value?.get(ApplicationSpecificCounterNotice.self) {
                return Int(value.value)
            } else {
                return 0
            }
        }
        |> take(1)
    }
    
    public static func incrementStoryStealthModeReplyCount(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            var value: Int32 = 0
            if let item = transaction.getNotice(ApplicationSpecificNoticeKeys.storyStealthModeReplyCount())?.get(ApplicationSpecificCounterNotice.self) {
                value = item.value
            }
            
            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value + 1)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.storyStealthModeReplyCount(), entry)
            }
        }
        |> ignoreValues
    }

    public static func incrementViewOnceTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.viewOnceTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.viewOnceTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func setDisplayStoryUnmuteTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayStoryUnmuteTooltip(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func displayStoryUnmuteTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayStoryUnmuteTooltip())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func setDisplayStoryInteractionGuide(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayStoryInteractionGuide(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func displayStoryInteractionGuide(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayStoryInteractionGuide())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
            
    public static func getMultipleReactionsSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.multipleReactionsSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementMultipleReactionsSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.multipleReactionsSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.multipleReactionsSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getSavedMessagesChatsSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.savedMessagesChatsSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementSavedMessagesChatsSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.savedMessagesChatsSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.savedMessagesChatsSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getVoiceMessagesPlayOnceSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesPlayOnceSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementVoiceMessagesPlayOnceSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesPlayOnceSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.voiceMessagesPlayOnceSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getIncomingVoiceMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.incomingVoiceMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementIncomingVoiceMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.incomingVoiceMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.incomingVoiceMessagePlayOnceTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getOutgoingVoiceMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.outgoingVoiceMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementOutgoingVoiceMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.outgoingVoiceMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.outgoingVoiceMessagePlayOnceTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getVideoMessagesPlayOnceSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.videoMessagesPlayOnceSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementVideoMessagesPlayOnceSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.videoMessagesPlayOnceSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.videoMessagesPlayOnceSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getIncomingVideoMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.incomingVideoMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementIncomingVideoMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.incomingVideoMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.incomingVideoMessagePlayOnceTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getOutgoingVideoMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.outgoingVideoMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementOutgoingVideoMessagePlayOnceTip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.outgoingVideoMessagePlayOnceTip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.outgoingVideoMessagePlayOnceTip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getSavedMessageTagLabelSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.savedMessageTagLabelSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementSavedMessageTagLabelSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.savedMessageTagLabelSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)
            
            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.savedMessageTagLabelSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }

    public static func setDismissedBusinessBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedBusinessBadge(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func dismissedBusinessBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedBusinessBadge())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func dismissedBirthdayPremiumGiftTip(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Int32?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedBirthdayPremiumGiftTip(peerId: peerId))
        |> map { view -> Int32? in
            if let value = view.value?.get(ApplicationSpecificTimestampNotice.self) {
                return value.value
            } else {
                return nil
            }
        }
    }
    
    public static func incrementDismissedBirthdayPremiumGiftTip(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, timestamp: Int32) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificTimestampNotice(value: timestamp)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedBirthdayPremiumGiftTip(peerId: peerId), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func displayedPeerVerification(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.displayedPeerVerification(peerId: peerId))
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setDisplayedPeerVerification(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.displayedPeerVerification(peerId: peerId), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func dismissedPaidMessageWarningNamespace(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Int64?, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedPaidMessageWarning(peerId: peerId))
        |> map { view -> Int64? in
            if let counter = view.value?.get(ApplicationSpecificCounterNotice.self) {
                return Int64(counter.value)
            } else {
                return nil
            }
        }
    }
    
    public static func setDismissedPaidMessageWarningNamespace(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId, amount: Int64?) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let amount, let entry = CodableEntry(ApplicationSpecificCounterNotice(value: Int32(amount))) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedPaidMessageWarning(peerId: peerId), entry)
            } else {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedPaidMessageWarning(peerId: peerId), nil)
            }
        }
        |> ignoreValues
    }
    
    public static func setMonetizationIntroDismissed(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.monetizationIntroDismissed(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func monetizationIntroDismissed(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.monetizationIntroDismissed())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func getBusinessBotMessageTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.businessBotMessageTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementBusinessBotMessageTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.businessBotMessageTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.businessBotMessageTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func setDismissedBusinessLinksBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedBusinessLinksBadge(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func dismissedBusinessLinksBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedBusinessLinksBadge())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func setDismissedBusinessIntroBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedBusinessIntroBadge(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func dismissedBusinessIntroBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedBusinessIntroBadge())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func setDismissedBusinessChatbotsBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.dismissedBusinessChatbotsBadge(), entry)
            }
        }
        |> ignoreValues
    }
    
    public static func dismissedBusinessChatbotsBadge(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.noticeEntry(key: ApplicationSpecificNoticeKeys.dismissedBusinessChatbotsBadge())
        |> map { view -> Bool in
            if let _ = view.value?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
        |> take(1)
    }
    
    public static func getCaptionAboveMediaTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.captionAboveMediaTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementCaptionAboveMediaTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.captionAboveMediaTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.captionAboveMediaTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChannelSendGiftTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.channelSendGiftTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChannelSendGiftTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.channelSendGiftTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.channelSendGiftTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getChannelSuggestTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.channelSuggestTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementChannelSuggestTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.channelSuggestTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.channelSuggestTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getStarGiftWearTips(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.starGiftWearTips())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementStarGiftWearTips(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.starGiftWearTips())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.starGiftWearTips(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getMultipleStoriesTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.multipleStoriesTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementMultipleStoriesTooltip(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.multipleStoriesTooltip())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.multipleStoriesTooltip(), entry)
            }
            
            return Int(previousValue)
        }
    }
        
    public static func getVoiceMessagesPauseSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesPauseSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementVoiceMessagesPauseSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesPauseSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.voiceMessagesPauseSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getVideoMessagesPauseSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.videoMessagesPauseSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementVideoMessagesPauseSuggestion(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.videoMessagesPauseSuggestion())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.videoMessagesPauseSuggestion(), entry)
            }
            
            return Int(previousValue)
        }
    }
    
    public static func getVoiceMessagesResumeTrimWarning(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Int32, NoError> {
        return accountManager.transaction { transaction -> Int32 in
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesResumeTrimWarning())?.get(ApplicationSpecificCounterNotice.self) {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    public static func incrementVoiceMessagesResumeTrimWarning(accountManager: AccountManager<TelegramAccountManagerTypes>, count: Int = 1) -> Signal<Int, NoError> {
        return accountManager.transaction { transaction -> Int in
            var currentValue: Int32 = 0
            if let value = transaction.getNotice(ApplicationSpecificNoticeKeys.voiceMessagesResumeTrimWarning())?.get(ApplicationSpecificCounterNotice.self) {
                currentValue = value.value
            }
            let previousValue = currentValue
            currentValue += Int32(count)

            if let entry = CodableEntry(ApplicationSpecificCounterNotice(value: currentValue)) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.voiceMessagesResumeTrimWarning(), entry)
            }
            
            return Int(previousValue)
        }
    }
}
