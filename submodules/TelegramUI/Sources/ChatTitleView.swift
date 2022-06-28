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

private let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
private let subtitleFont = Font.regular(13.0)

enum ChatTitleContent {
    enum ReplyThreadType {
        case comments
        case replies
    }
    
    case peer(peerView: PeerView, onlineMemberCount: Int32?, isScheduledMessages: Bool)
    case replyThread(type: ReplyThreadType, count: Int)
    case custom(String, String?, Bool)
}

private enum ChatTitleIcon {
    case none
    case lock
    case mute
}

private enum ChatTitleCredibilityIcon {
    case none
    case fake
    case scam
    case verified
    case premium
}

final class ChatTitleView: UIView, NavigationBarTitleView {
    private let context: AccountContext
    
    private var theme: PresentationTheme
    private var hasEmbeddedTitleContent: Bool = false
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    private var nameDisplayOrder: PresentationPersonNameOrder
    
    private let contentContainer: ASDisplayNode
    let titleNode: ImmediateAnimatedCountLabelNode
    let titleLeftIconNode: ASImageNode
    let titleRightIconNode: ASImageNode
    let titleCredibilityIconNode: ASImageNode
    let activityNode: ChatTitleActivityNode
    
    private let button: HighlightTrackingButtonNode
    
    private var validLayout: (CGSize, CGRect)?
    
    private var titleLeftIcon: ChatTitleIcon = .none
    private var titleRightIcon: ChatTitleIcon = .none
    private var titleCredibilityIcon: ChatTitleCredibilityIcon = .none
    
    //private var networkStatusNode: ChatTitleNetworkStatusNode?
    
    private var presenceManager: PeerPresenceStatusManager?
    
    private var pointerInteraction: PointerInteraction?
    
    var inputActivities: (PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            let _ = self.updateStatus()
        }
    }
    
    private func updateNetworkStatusNode(networkState: AccountNetworkState, layout: ContainerViewLayout?) {
        self.setNeedsLayout()
    }
    
    var networkState: AccountNetworkState = .online(proxy: nil) {
        didSet {
            if self.networkState != oldValue {
                updateNetworkStatusNode(networkState: self.networkState, layout: self.layout)
                let _ = self.updateStatus()
            }
        }
    }
    
    var layout: ContainerViewLayout? {
        didSet {
            if self.layout != oldValue {
                updateNetworkStatusNode(networkState: self.networkState, layout: self.layout)
            }
        }
    }
    
    var pressed: (() -> Void)?
    var longPressed: (() -> Void)?
    
    var titleContent: ChatTitleContent? {
        didSet {
            if let titleContent = self.titleContent {
                let titleTheme = self.hasEmbeddedTitleContent ? defaultDarkPresentationTheme : self.theme
                
                var segments: [AnimatedCountLabelNode.Segment] = []
                var titleLeftIcon: ChatTitleIcon = .none
                var titleRightIcon: ChatTitleIcon = .none
                var titleCredibilityIcon: ChatTitleCredibilityIcon = .none
                var isEnabled = true
                switch titleContent {
                    case let .peer(peerView, _, isScheduledMessages):
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
                            if let peer = peerViewMainPeer(peerView) {
                                if peerView.peerId == self.context.account.peerId {
                                    segments = [.text(0, NSAttributedString(string: self.strings.Conversation_SavedMessages, font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
                                } else {
                                    if !peerView.peerIsContact, let user = peer as? TelegramUser, !user.flags.contains(.isSupport), user.botInfo == nil, let phone = user.phone, !phone.isEmpty {
                                        segments = [.text(0, NSAttributedString(string: formatPhoneNumber(phone), font: titleFont, textColor: titleTheme.rootController.navigationBar.primaryTextColor))]
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
                                    } else if peer.isVerified {
                                        titleCredibilityIcon = .verified
                                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                                        titleCredibilityIcon = .premium
                                    }
                                }
                            }
                            if peerView.peerId.namespace == Namespaces.Peer.SecretChat {
                                titleLeftIcon = .lock
                            }
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    if titleCredibilityIcon != .verified {
                                        titleRightIcon = .mute
                                    }
                                }
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
                
                if self.titleNode.segments != segments {
                    self.titleNode.segments = segments
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
                    switch titleCredibilityIcon {
                        case .none:
                            self.titleCredibilityIconNode.image = nil
                        case .fake:
                            self.titleCredibilityIconNode.image = PresentationResourcesChatList.fakeIcon(titleTheme, strings: self.strings, type: .regular)
                        case .scam:
                            self.titleCredibilityIconNode.image = PresentationResourcesChatList.scamIcon(titleTheme, strings: self.strings, type: .regular)
                        case .verified:
                            self.titleCredibilityIconNode.image = PresentationResourcesChatList.verifiedIcon(titleTheme)
                        case .premium:
                            self.titleCredibilityIconNode.image = PresentationResourcesChatList.premiumIcon(titleTheme)
                    }
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
                if !self.updateStatus() {
                    if updated {
                        if let (size, clearBounds) = self.validLayout {
                            self.updateLayout(size: size, clearBounds: clearBounds, transition: .animated(duration: 0.2, curve: .easeInOut))
                        }
                    }
                }
            }
        }
    }
    
    private func updateStatus() -> Bool {
        var inputActivitiesAllowed = true
        if let titleContent = self.titleContent {
            switch titleContent {
            case let .peer(peerView, _, isScheduledMessages):
                if let peer = peerViewMainPeer(peerView) {
                    if peer.id == self.context.account.peerId || isScheduledMessages || peer.id.isReplies {
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
                        case let .peer(peerView, onlineMemberCount, isScheduledMessages):
                            if let peer = peerViewMainPeer(peerView) {
                                let servicePeer = isServicePeer(peer)
                                if peer.id == self.context.account.peerId || isScheduledMessages || peer.id.isReplies {
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
                                        let statusText = self.strings.Bot_GenericBotStatus
                                        
                                        let string = NSAttributedString(string: statusText, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let peer = peerViewMainPeer(peerView) {
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
                                    if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                                        if memberCount == 0 {
                                            let string: NSAttributedString
                                            if case .group = channel.info {
                                                string = NSAttributedString(string: strings.Group_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                            } else {
                                                string = NSAttributedString(string: strings.Channel_Status, font: subtitleFont, textColor: titleTheme.rootController.navigationBar.secondaryTextColor)
                                            }
                                            state = .info(string, .generic)
                                        } else {
                                            if case .group = channel.info, let onlineMemberCount = onlineMemberCount, onlineMemberCount > 1 {
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
                    for segment in self.titleNode.segments {
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
        
        if self.activityNode.transitionToState(state, animation: .slide) {
            if let (size, clearBounds) = self.validLayout {
                self.updateLayout(size: size, clearBounds: clearBounds, transition: .animated(duration: 0.3, curve: .spring))
            }
            return true
        } else {
            return false
        }
    }
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
                
        self.contentContainer = ASDisplayNode()
        
        self.titleNode = ImmediateAnimatedCountLabelNode()
        
        self.titleLeftIconNode = ASImageNode()
        self.titleLeftIconNode.isLayerBacked = true
        self.titleLeftIconNode.displayWithoutProcessing = true
        self.titleLeftIconNode.displaysAsynchronously = false
        
        self.titleRightIconNode = ASImageNode()
        self.titleRightIconNode.isLayerBacked = true
        self.titleRightIconNode.displayWithoutProcessing = true
        self.titleRightIconNode.displaysAsynchronously = false
        
        self.titleCredibilityIconNode = ASImageNode()
        self.titleCredibilityIconNode.isLayerBacked = true
        self.titleCredibilityIconNode.displayWithoutProcessing = true
        self.titleCredibilityIconNode.displaysAsynchronously = false
        
        self.activityNode = ChatTitleActivityNode()
        self.button = HighlightTrackingButtonNode()
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .header
        
        self.addSubnode(self.contentContainer)
        self.contentContainer.addSubnode(self.titleNode)
        self.contentContainer.addSubnode(self.activityNode)
        self.addSubnode(self.button)
        
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            let _ = self?.updateStatus()
        })
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.activityNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleCredibilityIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.activityNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.activityNode.alpha = 1.0
                    strongSelf.titleCredibilityIconNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.activityNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.button.view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:))))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, hasEmbeddedTitleContent: Bool) {
        self.theme = theme
        self.hasEmbeddedTitleContent = hasEmbeddedTitleContent
        self.strings = strings
        
        let titleContent = self.titleContent
        self.titleCredibilityIcon = .none
        self.titleContent = titleContent
        let _ = self.updateStatus()
        
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, clearBounds)
        
        self.button.frame = clearBounds
        self.contentContainer.frame = clearBounds
        
        var leftIconWidth: CGFloat = 0.0
        var rightIconWidth: CGFloat = 0.0
        var credibilityIconWidth: CGFloat = 0.0
        
        if let image = self.titleLeftIconNode.image {
            if self.titleLeftIconNode.supernode == nil {
                self.titleNode.addSubnode(self.titleLeftIconNode)
            }
            leftIconWidth = image.size.width + 6.0
        } else if self.titleLeftIconNode.supernode != nil {
            self.titleLeftIconNode.removeFromSupernode()
        }
        
        if let image = self.titleCredibilityIconNode.image {
            if self.titleCredibilityIconNode.supernode == nil {
                self.titleNode.addSubnode(self.titleCredibilityIconNode)
            }
            credibilityIconWidth = image.size.width + 3.0
        } else if self.titleCredibilityIconNode.supernode != nil {
            self.titleCredibilityIconNode.removeFromSupernode()
        }
        
        if let image = self.titleRightIconNode.image {
            if self.titleRightIconNode.supernode == nil {
                self.titleNode.addSubnode(self.titleRightIconNode)
            }
            rightIconWidth = image.size.width + 3.0
        } else if self.titleRightIconNode.supernode != nil {
            self.titleRightIconNode.removeFromSupernode()
        }
        
        let titleSideInset: CGFloat = 3.0
        var titleFrame: CGRect
        if size.height > 40.0 {
            var titleSize = self.titleNode.updateLayout(size: CGSize(width: clearBounds.width - leftIconWidth - credibilityIconWidth - rightIconWidth - titleSideInset * 2.0, height: size.height), animated: transition.isAnimated)
            titleSize.width += credibilityIconWidth
            let activitySize = self.activityNode.updateLayout(clearBounds.size, alignment: .center)
            let titleInfoSpacing: CGFloat = 0.0
                        
            if activitySize.height.isZero {
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
            } else {
                let combinedHeight = titleSize.height + activitySize.height + titleInfoSpacing
                
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                titleFrame.origin.x = max(titleFrame.origin.x, clearBounds.minX + leftIconWidth)
                transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
                
                var activityFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - activitySize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: activitySize)
                if activitySize.width < size.width {
                    activityFrame.origin.x = -clearBounds.minX + floor((size.width - activityFrame.width) / 2.0)
                }
                self.activityNode.frame = activityFrame
            }
            
            if let image = self.titleLeftIconNode.image {
                self.titleLeftIconNode.frame = CGRect(origin: CGPoint(x: -image.size.width - 3.0 - UIScreenPixel, y: 4.0), size: image.size)
            }
            if let image = self.titleCredibilityIconNode.image {
                var originY: CGFloat = 3.0
                if [.fake, .scam].contains(self.titleCredibilityIcon) {
                    originY = 2.0
                }
                self.titleCredibilityIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.width - image.size.width, y: originY), size: image.size)
            }
            if let image = self.titleRightIconNode.image {
                self.titleRightIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.width + 3.0 + UIScreenPixel, y: 6.0), size: image.size)
            }
        } else {
            let titleSize = self.titleNode.updateLayout(size: CGSize(width: floor(clearBounds.width / 2.0 - leftIconWidth - credibilityIconWidth - rightIconWidth - titleSideInset * 2.0), height: size.height), animated: transition.isAnimated)
            let activitySize = self.activityNode.updateLayout(CGSize(width: floor(clearBounds.width / 2.0), height: size.height), alignment: .center)
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + leftIconWidth + credibilityIconWidth + rightIconWidth + activitySize.width + titleInfoSpacing
            
            titleFrame = CGRect(origin: CGPoint(x: leftIconWidth + floor((clearBounds.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            transition.updateFrameAdditiveToCenter(node: self.titleNode, frame: titleFrame)
            self.activityNode.frame = CGRect(origin: CGPoint(x: floor((clearBounds.width - combinedWidth) / 2.0 + titleSize.width + leftIconWidth + credibilityIconWidth + rightIconWidth + titleInfoSpacing), y: floor((size.height - activitySize.height) / 2.0)), size: activitySize)
            
            if let image = self.titleLeftIconNode.image {
                self.titleLeftIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.minY + 4.0), size: image.size)
            }
            if let image = self.titleCredibilityIconNode.image {
                var originY: CGFloat = titleFrame.minY + 7.0
                if [.fake, .scam].contains(self.titleCredibilityIcon) {
                    originY = titleFrame.minY + 6.0
                }
                self.titleCredibilityIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX - image.size.width, y: originY), size: image.size)
            }
            if let image = self.titleRightIconNode.image {
                self.titleRightIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX - image.size.width, y: titleFrame.minY + 6.0), size: image.size)
            }
        }
        
        self.pointerInteraction = PointerInteraction(view: self, style: .rectangle(CGSize(width: titleFrame.width + 16.0, height: 40.0)))
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
    
    func animateLayoutTransition() {
        UIView.transition(with: self, duration: 0.25, options: [.transitionCrossDissolve], animations: {
        }, completion: nil)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isUserInteractionEnabled {
            return nil
        }
        if self.button.frame.contains(point) {
            return self.button.view
        }
        return super.hitTest(point, with: event)
    }

    final class SnapshotState {
        fileprivate let snapshotView: UIView

        fileprivate init(snapshotView: UIView) {
            self.snapshotView = snapshotView
        }
    }

    func prepareSnapshotState() -> SnapshotState {
        let snapshotView = self.snapshotView(afterScreenUpdates: false)!
        return SnapshotState(
            snapshotView: snapshotView
        )
    }

    func animateFromSnapshot(_ snapshotState: SnapshotState) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.layer.animatePosition(from: CGPoint(x: 0.0, y: 20.0), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)

        snapshotState.snapshotView.frame = self.frame
        self.superview?.insertSubview(snapshotState.snapshotView, belowSubview: self)

        let snapshotView = snapshotState.snapshotView
        snapshotState.snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
            snapshotView?.removeFromSuperview()
        })
        snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -20.0), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    }
}
