import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ActivityIndicator
import TelegramStringFormatting
import PeerPresenceStatusManager
import ChatTitleActivityNode
import LocalizedPeerData
import PhoneNumberFormat
import ChatTitleActivityNode
import AnimatedCountLabelNode
import AccountContext
import ComponentFlow
import EmojiStatusComponent
import AnimationCache
import MultiAnimationRenderer
import ComponentDisplayAdapters

private let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
private let subtitleFont = Font.regular(13.0)

public enum ChatTitleContent: Equatable {
    public struct PeerData: Equatable {
        public var peerId: PeerId
        public var peer: Peer?
        public var isContact: Bool
        public var isSavedMessages: Bool
        public var notificationSettings: TelegramPeerNotificationSettings?
        public var peerPresences: [PeerId: PeerPresence]
        public var cachedData: CachedPeerData?
        
        public init(peerId: PeerId, peer: Peer?, isContact: Bool, isSavedMessages: Bool, notificationSettings: TelegramPeerNotificationSettings?, peerPresences: [PeerId: PeerPresence], cachedData: CachedPeerData?) {
            self.peerId = peerId
            self.peer = peer
            self.isContact = isContact
            self.isSavedMessages = isSavedMessages
            self.notificationSettings = notificationSettings
            self.peerPresences = peerPresences
            self.cachedData = cachedData
        }
        
        public init(peerView: PeerView) {
            self.init(peerId: peerView.peerId, peer: peerViewMainPeer(peerView), isContact: peerView.peerIsContact, isSavedMessages: false, notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings, peerPresences: peerView.peerPresences, cachedData: peerView.cachedData)
        }
        
        public static func ==(lhs: PeerData, rhs: PeerData) -> Bool {
            if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
            } else if (lhs.peer == nil) != (rhs.peer == nil) {
                return false
            }
            if lhs.isContact != rhs.isContact {
                return false
            }
            if lhs.isSavedMessages != rhs.isSavedMessages {
                return false
            }
            if lhs.notificationSettings != rhs.notificationSettings {
                return false
            }
            if lhs.peerPresences.count != rhs.peerPresences.count {
                return false
            } else {
                for (key, value) in lhs.peerPresences {
                    if let rhsValue = rhs.peerPresences[key] {
                        if !value.isEqual(to: rhsValue) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            if lhs.cachedData !== rhs.cachedData {
                return false
            }
            return true
        }
    }
    
    public enum ReplyThreadType {
        case comments
        case replies
    }
    
    case peer(peerView: PeerData, customTitle: String?, onlineMemberCount: (total: Int32?, recent: Int32?), isScheduledMessages: Bool, isMuted: Bool?, customMessageCount: Int?, isEnabled: Bool)
    case replyThread(type: ReplyThreadType, count: Int)
    case custom(String, String?, Bool)
    
    public static func ==(lhs: ChatTitleContent, rhs: ChatTitleContent) -> Bool {
        switch lhs {
        case let .peer(peerView, customTitle, onlineMemberCount, isScheduledMessages, isMuted, customMessageCount, isEnabled):
            if case let .peer(rhsPeerView, rhsCustomTitle, rhsOnlineMemberCount, rhsIsScheduledMessages, rhsIsMuted, rhsCustomMessageCount, rhsIsEnabled) = rhs {
                if peerView != rhsPeerView {
                    return false
                }
                if customTitle != rhsCustomTitle {
                    return false
                }
                if onlineMemberCount.0 != rhsOnlineMemberCount.0 || onlineMemberCount.1 != rhsOnlineMemberCount.1 {
                    return false
                }
                if isScheduledMessages != rhsIsScheduledMessages {
                    return false
                }
                if isMuted != rhsIsMuted {
                    return false
                }
                if customMessageCount != rhsCustomMessageCount {
                    return false
                }
                if isEnabled != rhsIsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .replyThread(type, count):
            if case .replyThread(type, count) = rhs {
                return true
            } else {
                return false
            }
        case let .custom(title, status, active):
            if case .custom(title, status, active) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum ChatTitleIcon {
    case none
    case lock
    case mute
}

private enum ChatTitleCredibilityIcon: Equatable {
    case none
    case fake
    case scam
    case verified
    case premium
    case emojiStatus(PeerEmojiStatus)
}

public final class ChatTitleView: UIView, NavigationBarTitleView {
    public enum AnimateFromSnapshotDirection {
        case up
        case down
        case left
        case right
    }
    
    private let context: AccountContext
    
    private var theme: PresentationTheme
    private var hasEmbeddedTitleContent: Bool = false
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    private var nameDisplayOrder: PresentationPersonNameOrder
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private let contentContainer: ASDisplayNode
    public let titleContainerView: PortalSourceView
    public let titleTextNode: ImmediateAnimatedCountLabelNode
    public let titleLeftIconNode: ASImageNode
    public let titleRightIconNode: ASImageNode
    public let titleCredibilityIconView: ComponentHostView<Empty>
    public let titleVerifiedIconView: ComponentHostView<Empty>
    public let titleStatusIconView: ComponentHostView<Empty>
    public let activityNode: ChatTitleActivityNode
    
    private let button: HighlightTrackingButtonNode
    
    public var disableAnimations: Bool = false
    
    var manualLayout: Bool = false
    private var validLayout: (CGSize, CGRect)?
    
    private var titleLeftIcon: ChatTitleIcon = .none
    private var titleRightIcon: ChatTitleIcon = .none
    private var titleCredibilityIcon: ChatTitleCredibilityIcon = .none
    private var titleVerifiedIcon: ChatTitleCredibilityIcon = .none
    private var titleStatusIcon: ChatTitleCredibilityIcon = .none
    
    private var presenceManager: PeerPresenceStatusManager?
    
    private var pointerInteraction: PointerInteraction?
    
    public var inputActivities: (PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            let _ = self.updateStatus()
        }
    }
    
    private func updateNetworkStatusNode(networkState: AccountNetworkState, layout: ContainerViewLayout?) {
        if self.manualLayout {
            self.setNeedsLayout()
        }
    }
    
    public var networkState: AccountNetworkState = .online(proxy: nil) {
        didSet {
            if self.networkState != oldValue {
                updateNetworkStatusNode(networkState: self.networkState, layout: self.layout)
                let _ = self.updateStatus()
            }
        }
    }
    
    public var layout: ContainerViewLayout? {
        didSet {
            if self.layout != oldValue {
                updateNetworkStatusNode(networkState: self.networkState, layout: self.layout)
            }
        }
    }
    
    public var pressed: (() -> Void)?
    public var longPressed: (() -> Void)?
    
    public var titleContent: ChatTitleContent? {
        didSet {
            if let titleContent = self.titleContent {
                let titleTheme = self.hasEmbeddedTitleContent ? defaultDarkPresentationTheme : self.theme
                
                var segments: [AnimatedCountLabelNode.Segment] = []
                var titleLeftIcon: ChatTitleIcon = .none
                var titleRightIcon: ChatTitleIcon = .none
                var titleCredibilityIcon: ChatTitleCredibilityIcon = .none
                var titleVerifiedIcon: ChatTitleCredibilityIcon = .none
                var titleStatusIcon: ChatTitleCredibilityIcon = .none
                var isEnabled = true
                switch titleContent {
                    case let .peer(peerView, customTitle, _, isScheduledMessages, isMuted, _, isEnabledValue):
                        if peerView.peerId.isReplies {
                            let typeText: String = self.strings.DialogList_Replies
                            segments = [.text(0, NSAttributedString(string: typeText, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                            isEnabled = false
                        } else if isScheduledMessages {
                            if peerView.peerId == self.context.account.peerId {
                                segments = [.text(0, NSAttributedString(string: self.strings.ScheduledMessages_RemindersTitle, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                            } else {
                                segments = [.text(0, NSAttributedString(string: self.strings.ScheduledMessages_Title, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                            }
                            isEnabled = false
                        } else {
                            if let peer = peerView.peer {
                                if let customTitle = customTitle {
                                    segments = [.text(0, NSAttributedString(string: customTitle, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                } else if peerView.peerId == self.context.account.peerId {
                                    if peerView.isSavedMessages {
                                        segments = [.text(0, NSAttributedString(string: self.strings.Conversation_MyNotes, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                    } else {
                                        segments = [.text(0, NSAttributedString(string: self.strings.Conversation_SavedMessages, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                    }
                                } else if peerView.peerId.isAnonymousSavedMessages {
                                    segments = [.text(0, NSAttributedString(string: self.strings.ChatList_AuthorHidden, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                } else {
                                    if !peerView.isContact, let user = peer as? TelegramUser, !user.flags.contains(.isSupport), user.botInfo == nil, let phone = user.phone, !phone.isEmpty {
                                        segments = [.text(0, NSAttributedString(string: formatPhoneNumber(context: self.context, number: phone), font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                    } else {
                                        segments = [.text(0, NSAttributedString(string: EnginePeer(peer).displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder), font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                    }
                                }
                                if peer.id != self.context.account.peerId {
                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                                    if peer.isFake {
                                        titleCredibilityIcon = .fake
                                    } else if peer.isScam {
                                        titleCredibilityIcon = .scam
                                    } else if let emojiStatus = peer.emojiStatus, !premiumConfiguration.isPremiumDisabled {
                                        titleStatusIcon = .emojiStatus(emojiStatus)
                                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                                        titleCredibilityIcon = .premium
                                    }
                                    
                                    if peer.isVerified {
                                        titleCredibilityIcon = .verified
                                    }
                                    if let verificationIconFileId = peer.verificationIconFileId {
                                        titleVerifiedIcon = .emojiStatus(PeerEmojiStatus(content: .emoji(fileId: verificationIconFileId), expirationDate: nil))
                                    }
                                }
                            }
                            if peerView.peerId.namespace == Namespaces.Peer.SecretChat {
                                titleLeftIcon = .lock
                            }
                            if let isMuted {
                                if isMuted {
                                    titleRightIcon = .mute
                                }
                            } else {
                                if let notificationSettings = peerView.notificationSettings {
                                    if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                        if titleCredibilityIcon != .verified {
                                            titleRightIcon = .mute
                                        }
                                    }
                                }
                            }
                            if peerView.peerId.isVerificationCodes {
                                isEnabled = false
                            } else {
                                isEnabled = isEnabledValue
                            }
                        }
                    case let .replyThread(type, count):
                        let textFont = titleFont
                        let textColor = titleTheme.rootController.navigationBar.primaryTextColor
                        
                        if count > 0 {
                            var commentsPart: String
                            switch type {
                            case .comments:
                                commentsPart = self.strings.Conversation_TitleComments(Int32(count))
                            case .replies:
                                commentsPart = self.strings.Conversation_TitleReplies(Int32(count))
                            }
                            
                            if commentsPart.contains("[") && commentsPart.contains("]") {
                                if let startIndex = commentsPart.firstIndex(of: "["), let endIndex = commentsPart.firstIndex(of: "]") {
                                    commentsPart.removeSubrange(startIndex ... endIndex)
                                }
                            } else {
                                commentsPart = commentsPart.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,."))
                            }
                            
                            let rawTextAndRanges: PresentationStrings.FormattedString
                            switch type {
                            case .comments:
                                rawTextAndRanges = self.strings.Conversation_TitleCommentsFormat("\(count)", commentsPart)
                            case .replies:
                                rawTextAndRanges = self.strings.Conversation_TitleRepliesFormat("\(count)", commentsPart)
                            }

                            let rawText = rawTextAndRanges.string

                            var textIndex = 0
                            var latestIndex = 0
                            for indexAndRange in rawTextAndRanges.ranges {
                                let index = indexAndRange.index
                                let range = indexAndRange.range

                                var lowerSegmentIndex = range.lowerBound
                                if index != 0 {
                                    lowerSegmentIndex = min(lowerSegmentIndex, latestIndex)
                                } else {
                                    if latestIndex < range.lowerBound {
                                        let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: latestIndex) ..< rawText.index(rawText.startIndex, offsetBy: range.lowerBound)])
                                        segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                                        textIndex += 1
                                    }
                                }
                                latestIndex = range.upperBound
                                
                                let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: lowerSegmentIndex) ..< rawText.index(rawText.startIndex, offsetBy: min(rawText.count, range.upperBound))])
                                if index == 0 {
                                    segments.append(.number(count, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                                } else {
                                    segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                                    textIndex += 1
                                }
                            }
                            if latestIndex < rawText.count {
                                let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: latestIndex)...])
                                segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                                textIndex += 1
                            }
                        } else {
                            switch type {
                            case .comments:
                                segments = [.text(0, NSAttributedString(string: strings.Conversation_TitleCommentsEmpty, font: textFont, textColor: textColor))]
                            case .replies:
                                segments = [.text(0, NSAttributedString(string: strings.Conversation_TitleRepliesEmpty, font: textFont, textColor: textColor))]
                            }
                        }
                        
                        isEnabled = false
                    case let .custom(text, _, enabled):
                        segments = [.text(0, NSAttributedString(string: text, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                        isEnabled = enabled
                }
                
                var updated = false
                
                if self.titleTextNode.segments != segments {
                    self.titleTextNode.segments = segments
                    updated = true
                }
                
                if titleLeftIcon != self.titleLeftIcon {
                    self.titleLeftIcon = titleLeftIcon
                    switch titleLeftIcon {
                        case .lock:
                            self.titleLeftIconNode.image = PresentationResourcesChat.chatTitleLockIcon(titleTheme)
                        default:
                            self.titleLeftIconNode.image = nil
                    }
                    updated = true
                }
                                
                if titleCredibilityIcon != self.titleCredibilityIcon {
                    self.titleCredibilityIcon = titleCredibilityIcon
                    updated = true
                }
                
                if titleVerifiedIcon != self.titleVerifiedIcon {
                    self.titleVerifiedIcon = titleVerifiedIcon
                    updated = true
                }
                
                if titleStatusIcon != self.titleStatusIcon {
                    self.titleStatusIcon = titleStatusIcon
                    updated = true
                }
                
                if titleRightIcon != self.titleRightIcon {
                    self.titleRightIcon = titleRightIcon
                    switch titleRightIcon {
                        case .mute:
                            self.titleRightIconNode.image = PresentationResourcesChat.chatTitleMuteIcon(titleTheme)
                        default:
                            self.titleRightIconNode.image = nil
                    }
                    updated = true
                }
                self.isUserInteractionEnabled = isEnabled
                self.button.isUserInteractionEnabled = isEnabled
                
                var enableAnimation = false
                switch titleContent {
                case let .peer(_, customTitle, _, _, _, _, _):
                    if case let .peer(_, previousCustomTitle, _, _, _, _, _) = oldValue {
                        if customTitle != previousCustomTitle {
                            enableAnimation = false
                        }
                    } else {
                        enableAnimation = false
                    }
                default:
                    break
                }
                
                if !self.updateStatus(enableAnimation: enableAnimation) {
                    if updated {
                        if !self.manualLayout, let (size, clearBounds) = self.validLayout {
                            let _ = self.updateLayout(size: size, clearBounds: clearBounds, transition: (self.disableAnimations || !enableAnimation) ? .immediate : .animated(duration: 0.2, curve: .easeInOut))
                        }
                    }
                }
            }
        }
    }
    
    private func updateStatus(enableAnimation: Bool = true) -> Bool {
        var inputActivitiesAllowed = true
        if let titleContent = self.titleContent {
            switch titleContent {
            case let .peer(peerView, _, _, isScheduledMessages, _, _, _):
                if let peer = peerView.peer {
                    if peer.id == self.context.account.peerId || isScheduledMessages || peer.id.isRepliesOrVerificationCodes {
                        inputActivitiesAllowed = false
                    }
                }
            case .replyThread:
                inputActivitiesAllowed = true
            default:
                inputActivitiesAllowed = false
            }
        }
        
        let titleTheme = self.hasEmbeddedTitleContent ? defaultDarkPresentationTheme : self.theme
        
        var state = ChatTitleActivityNodeState.none
        switch self.networkState {
        case .waitingForNetwork, .connecting, .updating:
            var infoText: String
            switch self.networkState {
            case .waitingForNetwork:
                infoText = self.strings.ChatState_WaitingForNetwork
            case .connecting:
                infoText = self.strings.ChatState_Connecting
            case .updating:
                infoText = self.strings.ChatState_Updating
            case .online:
                infoText = ""
            }
            state = .info(NSAttributedString(string: infoText, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor), .generic)
        case .online:
            if let (peerId, inputActivities) = self.inputActivities, !inputActivities.isEmpty, inputActivitiesAllowed {
                var stringValue = ""
                var mergedActivity = inputActivities[0].1
                for (_, activity) in inputActivities {
                    if activity != mergedActivity {
                        mergedActivity = .typingText
                        break
                    }
                }
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                    switch mergedActivity {
                        case .typingText:
                            stringValue = strings.Conversation_typing
                        case .uploadingFile:
                            stringValue = strings.Activity_UploadingDocument
                        case .recordingVoice:
                            stringValue = strings.Activity_RecordingAudio
                        case .uploadingPhoto:
                            stringValue = strings.Activity_UploadingPhoto
                        case .uploadingVideo:
                            stringValue = strings.Activity_UploadingVideo
                        case .playingGame:
                            stringValue = strings.Activity_PlayingGame
                        case .recordingInstantVideo:
                            stringValue = strings.Activity_RecordingVideoMessage
                        case .uploadingInstantVideo:
                            stringValue = strings.Activity_UploadingVideoMessage
                        case .choosingSticker:
                            stringValue = strings.Activity_ChoosingSticker
                        case let .seeingEmojiInteraction(emoticon):
                            stringValue = strings.Activity_EnjoyingAnimations(emoticon).string
                        case .speakingInGroupCall, .interactingWithEmoji:
                            stringValue = ""
                    }
                } else {
                    if inputActivities.count > 1 {
                        let peerTitle = EnginePeer(inputActivities[0].0).compactDisplayTitle
                        if inputActivities.count == 2 {
                            let secondPeerTitle = EnginePeer(inputActivities[1].0).compactDisplayTitle
                            stringValue = strings.Chat_MultipleTypingPair(peerTitle, secondPeerTitle).string
                        } else {
                            stringValue = strings.Chat_MultipleTypingMore(peerTitle, String(inputActivities.count - 1)).string
                        }
                    } else if let (peer, _) = inputActivities.first {
                        stringValue = EnginePeer(peer).compactDisplayTitle
                    }
                }
                let color = titleTheme.rootController.navigationBar.accentTextColor
                let string = NSAttributedString(string: stringValue, font: subtitleFont, textColor: color)
                switch mergedActivity {
                    case .typingText:
                        state = .typingText(string, color)
                    case .recordingVoice:
                        state = .recordingVoice(string, color)
                    case .recordingInstantVideo:
                        state = .recordingVideo(string, color)
                    case .uploadingFile, .uploadingInstantVideo, .uploadingPhoto, .uploadingVideo:
                        state = .uploading(string, color)
                    case .playingGame:
                        state = .playingGame(string, color)
                    case .speakingInGroupCall, .interactingWithEmoji:
                        state = .typingText(string, color)
                    case .choosingSticker:
                        state = .choosingSticker(string, color)
                    case .seeingEmojiInteraction:
                        state = .choosingSticker(string, color)
                }
            } else {
                if let titleContent = self.titleContent {
                    switch titleContent {
                        case let .peer(peerView, customTitle, onlineMemberCount, isScheduledMessages, _, customMessageCount, _):
                            if let customMessageCount = customMessageCount, customMessageCount != 0 {
                                let string = NSAttributedString(string: self.strings.Conversation_Messages(Int32(customMessageCount)), font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                state = .info(string, .generic)
                            } else if let peer = peerView.peer {
                                let servicePeer = isServicePeer(peer)
                                if peer.id == self.context.account.peerId || isScheduledMessages || peer.id.isRepliesOrVerificationCodes {
                                    let string = NSAttributedString(string: "", font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                    state = .info(string, .generic)
                                } else if let user = peer as? TelegramUser {
                                    if user.isDeleted {
                                        state = .none
                                    } else if servicePeer {
                                        let string = NSAttributedString(string: "", font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if user.flags.contains(.isSupport) {
                                        let statusText = self.strings.Bot_GenericSupportStatus
                                        
                                        let string = NSAttributedString(string: statusText, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let _ = user.botInfo {
                                        let statusText: String
                                        if let subscriberCount = user.subscriberCount {
                                            statusText = self.strings.Conversation_StatusBotSubscribers(subscriberCount)
                                        } else {
                                            statusText = self.strings.Bot_GenericBotStatus
                                        }
                                        
                                        let string = NSAttributedString(string: statusText, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let peer = peerView.peer {
                                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                                        let userPresence: TelegramUserPresence
                                        if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                                            userPresence = presence
                                            self.presenceManager?.reset(presence: EnginePeer.Presence(presence))
                                        } else {
                                            userPresence = TelegramUserPresence(status: .none, lastActivity: 0)
                                        }
                                        let (string, activity) = stringAndActivityForUserPresence(strings: self.strings, dateTimeFormat: self.dateTimeFormat, presence: EnginePeer.Presence(userPresence), relativeTo: Int32(timestamp))
                                        let attributedString = NSAttributedString(string: string, font: subtitleFont, textColor: activity ? titleTheme.rootController.navigationBar.accentTextColor : titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(attributedString, activity ? .online : .lastSeenTime)
                                    } else {
                                        let string = NSAttributedString(string: "", font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    }
                                } else if let group = peer as? TelegramGroup {
                                    var onlineCount = 0
                                    if let cachedGroupData = peerView.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
                                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                                        for participant in participants.participants {
                                            if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                                                let relativeStatus = relativeUserPresenceStatus(EnginePeer.Presence(presence), relativeTo: Int32(timestamp))
                                                switch relativeStatus {
                                                case .online:
                                                    onlineCount += 1
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    if onlineCount > 1 {
                                        let string = NSMutableAttributedString()
                                        
                                        string.append(NSAttributedString(string: "\(strings.Conversation_StatusMembers(Int32(group.participantCount))), ", font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor))
                                        string.append(NSAttributedString(string: strings.Conversation_StatusOnline(Int32(onlineCount)), font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor))
                                        state = .info(string, .generic)
                                    } else {
                                        let string = NSAttributedString(string: strings.Conversation_StatusMembers(Int32(group.participantCount)), font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    }
                                } else if let channel = peer as? TelegramChannel {
                                    if channel.isForumOrMonoForum, customTitle != nil {
                                        let string = NSAttributedString(string: EnginePeer(peer).displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder), font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = onlineMemberCount.total ?? cachedChannelData.participantsSummary.memberCount {
                                        if memberCount == 0 {
                                            let string: NSAttributedString
                                            if case .group = channel.info {
                                                string = NSAttributedString(string: strings.Group_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                            } else {
                                                string = NSAttributedString(string: strings.Channel_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                            }
                                            state = .info(string, .generic)
                                        } else {
                                            if case .group = channel.info, let onlineMemberCount = onlineMemberCount.recent, onlineMemberCount > 1 {
                                                let string = NSMutableAttributedString()
                                                
                                                string.append(NSAttributedString(string: "\(strings.Conversation_StatusMembers(Int32(memberCount))), ", font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor))
                                                string.append(NSAttributedString(string: strings.Conversation_StatusOnline(Int32(onlineMemberCount)), font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor))
                                                state = .info(string, .generic)
                                            } else {
                                                let membersString: String
                                                if case .group = channel.info {
                                                    membersString = strings.Conversation_StatusMembers(memberCount)
                                                } else {
                                                    membersString = strings.Conversation_StatusSubscribers(memberCount)
                                                }
                                                let string = NSAttributedString(string: membersString, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                            }
                                        }
                                    } else {
                                        switch channel.info {
                                            case .group:
                                                let string = NSAttributedString(string: strings.Group_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                            case .broadcast:
                                                let string = NSAttributedString(string: strings.Channel_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                        }
                                    }
                                }
                            }
                        case let .custom(_, subtitle?, _):
                            let string = NSAttributedString(string: subtitle, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                            state = .info(string, .generic)
                        default:
                            break
                    }
                    
                    var accessibilityText = ""
                    for segment in self.titleTextNode.segments {
                        switch segment {
                        case let .number(_, string):
                            accessibilityText.append(string.string)
                        case let .text(_, string):
                            accessibilityText.append(string.string)
                        }
                    }
                    
                    self.accessibilityLabel = accessibilityText
                    self.accessibilityValue = state.string
                } else {
                    self.accessibilityLabel = nil
                }
            }
        }
        
        if self.activityNode.transitionToState(state, animation: enableAnimation ? .slide : .none) {
            if !self.manualLayout, let (size, clearBounds) = self.validLayout {
                let _ = self.updateLayout(size: size, clearBounds: clearBounds, transition: enableAnimation ? .animated(duration: 0.3, curve: .spring) : .immediate)
            }
            return true
        } else {
            return false
        }
    }
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
                
        self.contentContainer = ASDisplayNode()
        
        self.titleContainerView = PortalSourceView()
        self.titleTextNode = ImmediateAnimatedCountLabelNode()
        
        self.titleLeftIconNode = ASImageNode()
        self.titleLeftIconNode.isLayerBacked = true
        self.titleLeftIconNode.displayWithoutProcessing = true
        self.titleLeftIconNode.displaysAsynchronously = false
        
        self.titleRightIconNode = ASImageNode()
        self.titleRightIconNode.isLayerBacked = true
        self.titleRightIconNode.displayWithoutProcessing = true
        self.titleRightIconNode.displaysAsynchronously = false
        
        self.titleCredibilityIconView = ComponentHostView()
        self.titleCredibilityIconView.isUserInteractionEnabled = false
        
        self.titleVerifiedIconView = ComponentHostView()
        self.titleVerifiedIconView.isUserInteractionEnabled = false
        
        self.titleStatusIconView = ComponentHostView()
        self.titleStatusIconView.isUserInteractionEnabled = false
        
        self.activityNode = ChatTitleActivityNode()
        self.button = HighlightTrackingButtonNode()
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .header
        
        self.addSubnode(self.contentContainer)
        self.titleContainerView.addSubnode(self.titleTextNode)
        self.contentContainer.view.addSubview(self.titleContainerView)
        self.contentContainer.addSubnode(self.activityNode)
        self.addSubnode(self.button)
        
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            let _ = self?.updateStatus()
        })
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.activityNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleCredibilityIconView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleVerifiedIconView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleStatusIconView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleTextNode.alpha = 0.4
                    strongSelf.activityNode.alpha = 0.4
                    strongSelf.titleCredibilityIconView.alpha = 0.4
                    strongSelf.titleVerifiedIconView.alpha = 0.4
                } else {
                    strongSelf.titleTextNode.alpha = 1.0
                    strongSelf.activityNode.alpha = 1.0
                    strongSelf.titleCredibilityIconView.alpha = 1.0
                    strongSelf.titleVerifiedIconView.alpha = 1.0
                    strongSelf.titleStatusIconView.alpha = 1.0
                    strongSelf.titleTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.activityNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.button.view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if !self.manualLayout, let (size, clearBounds) = self.validLayout {
            let _ = self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, hasEmbeddedTitleContent: Bool) {
        if self.theme !== theme || self.strings !== strings || self.hasEmbeddedTitleContent != hasEmbeddedTitleContent {
            self.theme = theme
            self.hasEmbeddedTitleContent = hasEmbeddedTitleContent
            self.strings = strings
            
            let titleContent = self.titleContent
            self.titleCredibilityIcon = .none
            self.titleVerifiedIcon = .none
            self.titleContent = titleContent
            let _ = self.updateStatus()
            
            if !self.manualLayout, let (size, clearBounds) = self.validLayout {
                let _ = self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
            }
        }
    }
    
    public func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) -> CGRect {
        self.validLayout = (size, clearBounds)
        
        self.button.frame = clearBounds
        self.contentContainer.frame = clearBounds
        
        var leftIconWidth: CGFloat = 0.0
        var rightIconWidth: CGFloat = 0.0
        var credibilityIconWidth: CGFloat = 0.0
        var verifiedIconWidth: CGFloat = 0.0
        var statusIconWidth: CGFloat = 0.0
        
        if let image = self.titleLeftIconNode.image {
            if self.titleLeftIconNode.supernode == nil {
                self.titleTextNode.addSubnode(self.titleLeftIconNode)
            }
            leftIconWidth = image.size.width + 6.0
        } else if self.titleLeftIconNode.supernode != nil {
            self.titleLeftIconNode.removeFromSupernode()
        }
        
        let titleCredibilityContent: EmojiStatusComponent.Content
        switch self.titleCredibilityIcon {
        case .none:
            titleCredibilityContent = .none
        case .premium:
            titleCredibilityContent = .premium(color: self.theme.list.itemAccentColor)
        case .verified:
            titleCredibilityContent = .verified(fillColor: self.theme.list.itemCheckColors.fillColor, foregroundColor: self.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
        case .fake:
            titleCredibilityContent = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_FakeAccount.uppercased())
        case .scam:
            titleCredibilityContent = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_ScamAccount.uppercased())
        case let .emojiStatus(emojiStatus):
            titleCredibilityContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: self.theme.list.mediaPlaceholderColor, themeColor: self.theme.list.itemAccentColor, loopMode: .count(2))
        }
        
        let titleVerifiedContent: EmojiStatusComponent.Content
        switch self.titleVerifiedIcon {
        case .none:
            titleVerifiedContent = .none
        case .premium:
            titleVerifiedContent = .premium(color: self.theme.list.itemAccentColor)
        case .verified:
            titleVerifiedContent = .verified(fillColor: self.theme.list.itemCheckColors.fillColor, foregroundColor: self.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
        case .fake:
            titleVerifiedContent = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_FakeAccount.uppercased())
        case .scam:
            titleVerifiedContent = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_ScamAccount.uppercased())
        case let .emojiStatus(emojiStatus):
            titleVerifiedContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: self.theme.list.mediaPlaceholderColor, themeColor: self.theme.list.itemAccentColor, loopMode: .count(2))
        }
        
        let titleStatusContent: EmojiStatusComponent.Content
        var titleStatusParticleColor: UIColor?
        switch self.titleStatusIcon {
        case let .emojiStatus(emojiStatus):
            titleStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: self.theme.list.mediaPlaceholderColor, themeColor: self.theme.list.itemAccentColor, loopMode: .count(2))
            if let color = emojiStatus.color {
                titleStatusParticleColor = UIColor(rgb: UInt32(bitPattern: color))
            }
        default:
            titleStatusContent = .none
        }
        
        let titleCredibilitySize = self.titleCredibilityIconView.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusComponent(
                context: self.context,
                animationCache: self.animationCache,
                animationRenderer: self.animationRenderer,
                content: titleCredibilityContent,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 20.0, height: 20.0)
        )
        
        let titleVerifiedSize = self.titleVerifiedIconView.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusComponent(
                context: self.context,
                animationCache: self.animationCache,
                animationRenderer: self.animationRenderer,
                content: titleVerifiedContent,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 20.0, height: 20.0)
        )
        
        let titleStatusSize = self.titleStatusIconView.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusComponent(
                context: self.context,
                animationCache: self.animationCache,
                animationRenderer: self.animationRenderer,
                content: titleStatusContent,
                particleColor: titleStatusParticleColor,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 20.0, height: 20.0)
        )
        
        if self.titleCredibilityIcon != .none {
            self.titleTextNode.view.addSubview(self.titleCredibilityIconView)
            credibilityIconWidth = titleCredibilitySize.width + 3.0
        } else {
            if self.titleCredibilityIconView.superview != nil {
                self.titleCredibilityIconView.removeFromSuperview()
            }
        }
        
        if self.titleVerifiedIcon != .none {
            self.titleTextNode.view.addSubview(self.titleVerifiedIconView)
            verifiedIconWidth = titleVerifiedSize.width + 3.0
        } else {
            if self.titleVerifiedIconView.superview != nil {
                self.titleVerifiedIconView.removeFromSuperview()
            }
        }
        
        if self.titleStatusIcon != .none {
            self.titleTextNode.view.addSubview(self.titleStatusIconView)
            statusIconWidth = titleStatusSize.width + 3.0
        } else {
            if self.titleStatusIconView.superview != nil {
                self.titleStatusIconView.removeFromSuperview()
            }
        }
        
        if let image = self.titleRightIconNode.image {
            if self.titleRightIconNode.supernode == nil {
                self.titleTextNode.addSubnode(self.titleRightIconNode)
            }
            rightIconWidth = max(24.0, image.size.width) + 3.0
        } else if self.titleRightIconNode.supernode != nil {
            self.titleRightIconNode.removeFromSupernode()
        }
        
        var titleTransition = transition
        if self.titleContainerView.bounds.width.isZero {
            titleTransition = .immediate
        }
        
        let statusSpacing: CGFloat = 3.0
        let titleSideInset: CGFloat = 6.0
        var titleFrame: CGRect
        if size.height > 40.0 {
            var titleInsets: UIEdgeInsets = .zero
            if case .emojiStatus = self.titleVerifiedIcon, verifiedIconWidth > 0.0 {
                titleInsets.left = verifiedIconWidth
            }
            
            var titleSize = self.titleTextNode.updateLayout(size: CGSize(width: clearBounds.width - leftIconWidth - credibilityIconWidth - verifiedIconWidth - statusIconWidth - rightIconWidth - titleSideInset * 2.0, height: size.height), insets: titleInsets, animated: titleTransition.isAnimated)
            titleSize.width += credibilityIconWidth
            titleSize.width += verifiedIconWidth
            if statusIconWidth > 0.0 {
                titleSize.width += statusIconWidth
                if credibilityIconWidth > 0.0 {
                    titleSize.width += statusSpacing
                }
            }
            
            let activitySize = self.activityNode.updateLayout(CGSize(width: clearBounds.size.width - titleSideInset * 2.0, height: clearBounds.size.height), alignment: .center)
            let titleInfoSpacing: CGFloat = 0.0
            
            if activitySize.height.isZero {
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                titleTransition.updateFrameAdditive(view: self.titleContainerView, frame: titleFrame)
                titleTransition.updateFrameAdditive(node: self.titleTextNode, frame: CGRect(origin: CGPoint(), size: titleFrame.size))
            } else {
                let combinedHeight = titleSize.height + activitySize.height + titleInfoSpacing
                
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                titleFrame.origin.x = max(titleFrame.origin.x, clearBounds.minX + leftIconWidth)
                titleTransition.updateFrameAdditive(view: self.titleContainerView, frame: titleFrame)
                titleTransition.updateFrameAdditive(node: self.titleTextNode, frame: CGRect(origin: CGPoint(), size: titleFrame.size))
                
                var activityFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - activitySize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: activitySize)
                if activitySize.width < size.width {
                    activityFrame.origin.x = -clearBounds.minX + floor((size.width - activityFrame.width) / 2.0)
                }
                titleTransition.updateFrameAdditiveToCenter(node: self.activityNode, frame: activityFrame)
            }
            
            if let image = self.titleLeftIconNode.image {
                titleTransition.updateFrame(node: self.titleLeftIconNode, frame: CGRect(origin: CGPoint(x: -image.size.width - 3.0 - UIScreenPixel, y: 4.0), size: image.size))
            }
            
            var nextIconX: CGFloat = titleFrame.width
            
            titleTransition.updateFrame(view: self.titleVerifiedIconView, frame: CGRect(origin: CGPoint(x: 0.0, y: floor((titleFrame.height - titleVerifiedSize.height) / 2.0)), size: titleVerifiedSize))
            
            self.titleCredibilityIconView.frame = CGRect(origin: CGPoint(x: nextIconX - titleCredibilitySize.width, y: floor((titleFrame.height - titleCredibilitySize.height) / 2.0)), size: titleCredibilitySize)
            nextIconX -= titleCredibilitySize.width
            if credibilityIconWidth > 0.0 {
                nextIconX -= statusSpacing
            }
            
            self.titleStatusIconView.frame = CGRect(origin: CGPoint(x: nextIconX - titleStatusSize.width, y: floor((titleFrame.height - titleStatusSize.height) / 2.0)), size: titleStatusSize)
            nextIconX -= titleStatusSize.width
        
            if let image = self.titleRightIconNode.image {
                self.titleRightIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.width + 3.0 + UIScreenPixel, y: 6.0), size: image.size)
            }
        } else {
            let titleSize = self.titleTextNode.updateLayout(size: CGSize(width: floor(clearBounds.width / 2.0 - leftIconWidth - credibilityIconWidth - verifiedIconWidth - statusIconWidth - rightIconWidth - titleSideInset * 2.0), height: size.height), animated: titleTransition.isAnimated)
            let activitySize = self.activityNode.updateLayout(CGSize(width: floor(clearBounds.width / 2.0), height: size.height), alignment: .center)
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + leftIconWidth + credibilityIconWidth + verifiedIconWidth + statusIconWidth + rightIconWidth + activitySize.width + titleInfoSpacing
            
            titleFrame = CGRect(origin: CGPoint(x: leftIconWidth + floor((clearBounds.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            
            titleTransition.updateFrameAdditiveToCenter(view: self.titleContainerView, frame: titleFrame)
            titleTransition.updateFrameAdditiveToCenter(node: self.titleTextNode, frame: CGRect(origin: CGPoint(), size: titleFrame.size))
            
            titleTransition.updateFrameAdditiveToCenter(node: self.activityNode, frame: CGRect(origin: CGPoint(x: floor((clearBounds.width - combinedWidth) / 2.0 + titleSize.width + leftIconWidth + credibilityIconWidth + verifiedIconWidth + statusIconWidth + rightIconWidth + titleInfoSpacing), y: floor((size.height - activitySize.height) / 2.0)), size: activitySize))
            
            if let image = self.titleLeftIconNode.image {
                self.titleLeftIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.minY + 4.0), size: image.size)
            }
            
            var nextIconX: CGFloat = titleFrame.maxX
            
            self.titleVerifiedIconView.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((titleFrame.height - titleVerifiedSize.height) / 2.0)), size: titleVerifiedSize)
            
            self.titleCredibilityIconView.frame = CGRect(origin: CGPoint(x: nextIconX - titleCredibilitySize.width, y: floor((titleFrame.height - titleCredibilitySize.height) / 2.0)), size: titleCredibilitySize)
            nextIconX -= titleCredibilitySize.width
            
            titleTransition.updateFrame(view: self.titleStatusIconView, frame: CGRect(origin: CGPoint(x: nextIconX - titleStatusSize.width, y: floor((titleFrame.height - titleStatusSize.height) / 2.0)), size: titleStatusSize))
            nextIconX -= titleStatusSize.width
            
            if let image = self.titleRightIconNode.image {
                titleTransition.updateFrame(node: self.titleRightIconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX - image.size.width, y: titleFrame.minY + 6.0), size: image.size))
            }
        }
        
        self.pointerInteraction = PointerInteraction(view: self, style: .rectangle(CGSize(width: titleFrame.width + 16.0, height: 40.0)))
        
        return titleFrame
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    @objc private func longPressGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            self.longPressed?()
        default:
            break
        }
    }
    
    public func animateLayoutTransition() {
        UIView.transition(with: self, duration: 0.25, options: [.transitionCrossDissolve], animations: {
        }, completion: nil)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isUserInteractionEnabled {
            return nil
        }
        if self.button.frame.contains(point) {
            return self.button.view
        }
        return super.hitTest(point, with: event)
    }

    public final class SnapshotState {
        fileprivate let snapshotView: UIView

        fileprivate init(snapshotView: UIView) {
            self.snapshotView = snapshotView
        }
    }

    public func prepareSnapshotState() -> SnapshotState? {
        guard let snapshotView = self.snapshotView(afterScreenUpdates: false) else {
            return nil
        }
        return SnapshotState(
            snapshotView: snapshotView
        )
    }

    public func animateFromSnapshot(_ snapshotState: SnapshotState, direction: AnimateFromSnapshotDirection = .up) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        var offset = CGPoint()
        switch direction {
        case .up:
            offset.y = -20.0
        case .down:
            offset.y = 20.0
        case .left:
            offset.x = -20.0
        case .right:
            offset.x = 20.0
        }
        
        self.layer.animatePosition(from: offset, to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)

        snapshotState.snapshotView.frame = self.frame
        self.superview?.insertSubview(snapshotState.snapshotView, belowSubview: self)

        let snapshotView = snapshotState.snapshotView
        snapshotState.snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.14, removeOnCompletion: false, completion: { [weak snapshotView] _ in
            snapshotView?.removeFromSuperview()
        })
        snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -offset.x, y: -offset.y), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    }
}

public final class ChatTitleComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let content: ChatTitleContent
    public let tapped: () -> Void
    public let longTapped: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        content: ChatTitleContent,
        tapped: @escaping () -> Void,
        longTapped: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.content = content
        self.tapped = tapped
        self.longTapped = longTapped
    }
    
    public static func ==(lhs: ChatTitleComponent, rhs: ChatTitleComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        public private(set) var contentView: ChatTitleView?
        
        private var component: ChatTitleComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let contentView: ChatTitleView
            if let current = self.contentView {
                contentView = current
            } else {
                contentView = ChatTitleView(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    dateTimeFormat: component.dateTimeFormat,
                    nameDisplayOrder: component.nameDisplayOrder,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer
                )
                contentView.pressed = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.component?.tapped()
                }
                contentView.longPressed = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.component?.longTapped()
                }
                contentView.manualLayout = true
                self.contentView = contentView
                self.addSubview(contentView)
            }
            
            if contentView.titleContent != component.content {
                contentView.titleContent = component.content
            }
            contentView.updateThemeAndStrings(theme: component.theme, strings: component.strings, hasEmbeddedTitleContent: false)
            
            let _ = contentView.updateLayout(size: availableSize, clearBounds: CGRect(origin: CGPoint(), size: availableSize), transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
