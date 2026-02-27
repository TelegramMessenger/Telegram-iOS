import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences
import Postbox
import TelegramCore
import PeerPresenceStatusManager
import ChatTitleActivityNode
import AnimatedTextComponent
import PhoneNumberFormat
import TelegramStringFormatting
import EmojiStatusComponent
import GlassBackgroundComponent

public final class ChatNavigationBarTitleView: UIView, NavigationBarTitleView {
    private final class ContentData {
        let context: AccountContext
        let theme: PresentationTheme
        let preferClearGlass: Bool
        let wallpaper: TelegramWallpaper
        let strings: PresentationStrings
        let dateTimeFormat: PresentationDateTimeFormat
        let nameDisplayOrder: PresentationPersonNameOrder
        let content: ChatTitleContent
        
        init(context: AccountContext, theme: PresentationTheme, preferClearGlass: Bool, wallpaper: TelegramWallpaper, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, content: ChatTitleContent) {
            self.context = context
            self.theme = theme
            self.preferClearGlass = preferClearGlass
            self.wallpaper = wallpaper
            self.strings = strings
            self.dateTimeFormat = dateTimeFormat
            self.nameDisplayOrder = nameDisplayOrder
            self.content = content
        }
    }
    
    private let parentTitleState = ComponentState()
    private let title = ComponentView<Empty>()
    
    private var contentData: ContentData?
    private var activities: ChatTitleComponent.Activities?
    private var networkState: AccountNetworkState?
    
    private var ignoreParentTransitionRequests: Bool = false
    public var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    
    public var tapAction: (() -> Void)?
    public var longTapAction: (() -> Void)?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func animateLayoutTransition() {
    }
    
    public func prepareSnapshotState() -> ChatTitleView.SnapshotState? {
        //return titleView.contentView?.snapshotView(afterScreenUpdates: false)
        return nil
    }
    
    public func animateFromSnapshot(_ snapshotState: ChatTitleView.SnapshotState, direction: ChatTitleView.AnimateFromSnapshotDirection) {
        guard let titleView = self.title.view as? ChatTitleComponent.View else {
            return
        }
        //titleView.contentView?.animateFromSnapshot(snapshotState, direction: direction)
        titleView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    public func update(
        context: AccountContext,
        theme: PresentationTheme,
        preferClearGlass: Bool,
        wallpaper: TelegramWallpaper,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        content: ChatTitleContent,
        transition: ComponentTransition,
        ignoreParentTransitionRequests: Bool = false
    ) {
        self.ignoreParentTransitionRequests = ignoreParentTransitionRequests
        self.contentData = ContentData(
            context: context,
            theme: theme,
            preferClearGlass: preferClearGlass,
            wallpaper: wallpaper,
            strings: strings,
            dateTimeFormat: dateTimeFormat,
            nameDisplayOrder: nameDisplayOrder,
            content: content
        )
        self.update(transition: transition)
        self.ignoreParentTransitionRequests = false
    }
    
    public func updateActivities(activities: ChatTitleComponent.Activities?, transition: ComponentTransition) {
        if self.activities != activities {
            self.activities = activities
            self.update(transition: transition)
        }
    }
    
    public func updateNetworkState(networkState: AccountNetworkState, transition: ComponentTransition) {
        if self.networkState != networkState {
            self.networkState = networkState
            self.update(transition: transition)
        }
    }
    
    private func update(transition: ComponentTransition) {
        if !self.ignoreParentTransitionRequests {
            self.requestUpdate?(transition.containedViewLayoutTransition)
        }
    }
    
    public func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let transition = ComponentTransition(transition)
        
        if let contentData = self.contentData {
            let displayBackground: Bool = true
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(ChatTitleComponent(
                    context: contentData.context,
                    theme: contentData.theme,
                    preferClearGlass: contentData.preferClearGlass,
                    strings: contentData.strings,
                    dateTimeFormat: contentData.dateTimeFormat,
                    nameDisplayOrder: contentData.nameDisplayOrder,
                    displayBackground: displayBackground,
                    content: contentData.content,
                    activities: self.activities,
                    networkState: self.networkState,
                    tapped: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.tapAction?()
                    },
                    longTapped: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.longTapAction?()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.title.parentState = self.parentTitleState
                    self.parentTitleState._updated = { [weak self] transition, _ in
                        guard let self else {
                            return
                        }
                        self.requestUpdate?(transition.containedViewLayoutTransition)
                    }
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(), size: titleSize))
            }
            return titleSize
        } else {
            return availableSize
        }
    }
}

public final class ChatTitleComponent: Component {
    public struct Activities: Equatable {
        public struct Item: Equatable {
            public let peer: EnginePeer
            public let activity: PeerInputActivity
            
            public init(peer: EnginePeer, activity: PeerInputActivity) {
                self.peer = peer
                self.activity = activity
            }
        }
        
        public let peerId: EnginePeer.Id
        public let items: [Item]
        
        public init(peerId: EnginePeer.Id, items: [Item]) {
            self.peerId = peerId
            self.items = items
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let preferClearGlass: Bool
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let displayBackground: Bool
    public let content: ChatTitleContent
    public let activities: Activities?
    public let networkState: AccountNetworkState?
    public let tapped: () -> Void
    public let longTapped: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        preferClearGlass: Bool,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        displayBackground: Bool,
        content: ChatTitleContent,
        activities: Activities?,
        networkState: AccountNetworkState?,
        tapped: @escaping () -> Void,
        longTapped: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.displayBackground = displayBackground
        self.content = content
        self.activities = activities
        self.networkState = networkState
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
        if lhs.preferClearGlass != rhs.preferClearGlass {
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
        if lhs.displayBackground != rhs.displayBackground {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.activities != rhs.activities {
            return false
        }
        if lhs.networkState != rhs.networkState {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var backgroundView: GlassBackgroundView?
        private let contentContainer: UIView
        private let title = ComponentView<Empty>()
        private var subtitleNode: ChatTitleActivityNode?
        private var activityMeasureSubtitleNode: ChatTitleActivityNode?
        private var leftIcon: ComponentView<Empty>?
        private var rightIcon: ComponentView<Empty>?
        private var credibilityIcon: ComponentView<Empty>?
        private var verifiedIcon: ComponentView<Empty>?
        private var statusIcon: ComponentView<Empty>?
        
        private var presenceManager: PeerPresenceStatusManager?
        
        private var component: ChatTitleComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.contentContainer = UIView()
            self.contentContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
                guard let self else {
                    return
                }
                self.state?.updated(transition: .spring(duration: 0.4))
            })
            
            let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
            recognizer.tapActionAtPoint = { _ in
                return .waitForSingleTap
            }
            self.contentContainer.addGestureRecognizer(recognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.component?.tapped()
                case .longTap:
                    self.component?.longTapped()
                default:
                    break
                }
            }
        }
        
        func update(component: ChatTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let statusIconsSpacing: CGFloat = 4.0
            let leftTitleIconSpacing: CGFloat = 3.0
            let rightTitleIconSpacing: CGFloat = 3.0
            let containerSideInset: CGFloat = 14.0
            
            self.component = component
            self.state = state
            
            var titleSegments: [AnimatedTextComponent.Item] = []
            var titleLeftIcon: TitleIconComponent.Kind?
            var titleRightIcon: TitleIconComponent.Kind?
            var titleCredibilityIcon: ChatTitleCredibilityIcon = .none
            var titleVerifiedIcon: ChatTitleCredibilityIcon = .none
            var titleStatusIcon: ChatTitleCredibilityIcon = .none
            var isEnabled = true
            switch component.content {
            case let .peer(peerView, customTitle, _, _, isScheduledMessages, isMuted, _, isEnabledValue):
                if peerView.peerId.isReplies {
                    titleSegments = [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        isUnbreakable: true,
                        content: .text(component.strings.DialogList_Replies)
                    )]
                    isEnabled = false
                } else if isScheduledMessages {
                    if peerView.peerId == component.context.account.peerId {
                        titleSegments = [AnimatedTextComponent.Item(
                            id: AnyHashable(0),
                            isUnbreakable: true,
                            content: .text(component.strings.ScheduledMessages_RemindersTitle)
                        )]
                    } else {
                        titleSegments = [AnimatedTextComponent.Item(
                            id: AnyHashable(0),
                            isUnbreakable: true,
                            content: .text(component.strings.ScheduledMessages_Title)
                        )]
                    }
                    isEnabled = false
                } else {
                    if let peer = peerView.peer {
                        if let customTitle {
                            titleSegments = [AnimatedTextComponent.Item(
                                id: AnyHashable(0),
                                isUnbreakable: true,
                                content: .text(customTitle)
                            )]
                        } else if peerView.peerId == component.context.account.peerId {
                            if peerView.isSavedMessages {
                                titleSegments = [AnimatedTextComponent.Item(
                                    id: AnyHashable(0),
                                    isUnbreakable: true,
                                    content: .text(component.strings.Conversation_MyNotes)
                                )]
                            } else {
                                titleSegments = [AnimatedTextComponent.Item(
                                    id: AnyHashable(0),
                                    isUnbreakable: true,
                                    content: .text(component.strings.Conversation_SavedMessages)
                                )]
                            }
                        } else if peerView.peerId.isAnonymousSavedMessages {
                            titleSegments = [AnimatedTextComponent.Item(
                                id: AnyHashable(0),
                                isUnbreakable: true,
                                content: .text(component.strings.ChatList_AuthorHidden)
                            )]
                        } else {
                            if !peerView.isContact, let user = peer as? TelegramUser, !user.flags.contains(.isSupport), user.botInfo == nil, let phone = user.phone, !phone.isEmpty {
                                titleSegments = [AnimatedTextComponent.Item(
                                    id: AnyHashable(0),
                                    isUnbreakable: true,
                                    content: .text(formatPhoneNumber(context: component.context, number: phone))
                                )]
                            } else {
                                titleSegments = [AnimatedTextComponent.Item(
                                    id: AnyHashable(0),
                                    isUnbreakable: true,
                                    content: .text(EnginePeer(peer).displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder))
                                )]
                            }
                        }
                        if peer.id != component.context.account.peerId {
                            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with({ $0 }))
                            if peer.isFake {
                                titleCredibilityIcon = .fake
                            } else if peer.isScam {
                                titleCredibilityIcon = .scam
                            } else if let emojiStatus = peer.emojiStatus {
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
                if count > 0 {
                    var commentsPart: String
                    switch type {
                    case .comments:
                        commentsPart = component.strings.Conversation_TitleComments(Int32(count))
                    case .replies:
                        commentsPart = component.strings.Conversation_TitleReplies(Int32(count))
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
                        rawTextAndRanges = component.strings.Conversation_TitleCommentsFormat("\(count)", commentsPart)
                    case .replies:
                        rawTextAndRanges = component.strings.Conversation_TitleRepliesFormat("\(count)", commentsPart)
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
                                
                                titleSegments.append(AnimatedTextComponent.Item(
                                    id: AnyHashable(textIndex),
                                    isUnbreakable: true,
                                    content: .text(part)
                                ))
                                textIndex += 1
                            }
                        }
                        latestIndex = range.upperBound
                        
                        let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: lowerSegmentIndex) ..< rawText.index(rawText.startIndex, offsetBy: min(rawText.count, range.upperBound))])
                        if index == 0 {
                            titleSegments.append(AnimatedTextComponent.Item(
                                id: AnyHashable(textIndex),
                                isUnbreakable: false,
                                content: .text(part)
                            ))
                            textIndex += 1
                        } else {
                            titleSegments.append(AnimatedTextComponent.Item(
                                id: AnyHashable(textIndex),
                                isUnbreakable: true,
                                content: .text(part)
                            ))
                            textIndex += 1
                        }
                    }
                    if latestIndex < rawText.count {
                        let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: latestIndex)...])
                        titleSegments.append(AnimatedTextComponent.Item(
                            id: AnyHashable(textIndex),
                            isUnbreakable: true,
                            content: .text(part)
                        ))
                        textIndex += 1
                    }
                } else {
                    switch type {
                    case .comments:
                        titleSegments = [AnimatedTextComponent.Item(
                            id: AnyHashable(0),
                            isUnbreakable: true,
                            content: .text(component.strings.Conversation_TitleCommentsEmpty)
                        )]
                    case .replies:
                        titleSegments = [AnimatedTextComponent.Item(
                            id: AnyHashable(0),
                            isUnbreakable: true,
                            content: .text(component.strings.Conversation_TitleRepliesEmpty)
                        )]
                    }
                }
                
                isEnabled = false
            case let .custom(textItems, _, enabled):
                titleSegments = textItems.map { item -> AnimatedTextComponent.Item in
                    let mappedContent: AnimatedTextComponent.Item.Content
                    switch item.content {
                    case let .number(value, minDigits):
                        mappedContent = .number(value, minDigits: minDigits)
                    case let .text(text):
                        mappedContent = .text(text)
                    }
                    return AnimatedTextComponent.Item(
                        id: item.id,
                        isUnbreakable: item.isUnbreakable,
                        content: mappedContent
                    )
                }
                isEnabled = enabled
            }
            
            var accessibilityText = ""
            for segment in titleSegments {
                switch segment.content {
                case let .number(value, _):
                    accessibilityText.append("\(value)")
                case let .text(string):
                    accessibilityText.append(string)
                case .icon:
                    break
                }
            }
            self.accessibilityLabel = accessibilityText
            
            var inputActivitiesAllowed = true
            switch component.content {
            case let .peer(peerView, _, _, _, isScheduledMessages, _, _, _):
                if let peer = peerView.peer {
                    if peer.id == component.context.account.peerId || isScheduledMessages || peer.id.isRepliesOrVerificationCodes {
                        inputActivitiesAllowed = false
                    }
                }
            case .replyThread:
                inputActivitiesAllowed = true
            default:
                inputActivitiesAllowed = false
            }
            
            let subtitleFont = Font.regular(12.0)
            var state: ChatTitleActivityNodeState = .none
            switch component.networkState {
            case .waitingForNetwork, .connecting, .updating:
                var infoText: String
                switch component.networkState {
                case .waitingForNetwork:
                    infoText = component.strings.ChatState_WaitingForNetwork
                case .connecting:
                    infoText = component.strings.ChatState_Connecting
                case .updating:
                    infoText = component.strings.ChatState_Updating
                case .online, .none:
                    infoText = ""
                }
                state = .info(NSAttributedString(string: infoText, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor), .generic)
            case .online, .none:
                if let inputActivities = component.activities, !inputActivities.items.isEmpty, inputActivitiesAllowed {
                    var stringValue = ""
                    var mergedActivity = inputActivities.items[0].activity
                    for item in inputActivities.items {
                        if item.activity != mergedActivity {
                            mergedActivity = .typingText
                            break
                        }
                    }
                    if inputActivities.peerId.namespace == Namespaces.Peer.CloudUser || inputActivities.peerId.namespace == Namespaces.Peer.SecretChat {
                        switch mergedActivity {
                        case .typingText:
                            stringValue = component.strings.Conversation_typing
                        case .uploadingFile:
                            stringValue = component.strings.Activity_UploadingDocument
                        case .recordingVoice:
                            stringValue = component.strings.Activity_RecordingAudio
                        case .uploadingPhoto:
                            stringValue = component.strings.Activity_UploadingPhoto
                        case .uploadingVideo:
                            stringValue = component.strings.Activity_UploadingVideo
                        case .playingGame:
                            stringValue = component.strings.Activity_PlayingGame
                        case .recordingInstantVideo:
                            stringValue = component.strings.Activity_RecordingVideoMessage
                        case .uploadingInstantVideo:
                            stringValue = component.strings.Activity_UploadingVideoMessage
                        case .choosingSticker:
                            stringValue = component.strings.Activity_ChoosingSticker
                        case let .seeingEmojiInteraction(emoticon):
                            stringValue = component.strings.Activity_EnjoyingAnimations(emoticon).string
                        case .speakingInGroupCall, .interactingWithEmoji:
                            stringValue = ""
                        }
                    } else {
                        if inputActivities.items.count > 1 {
                            let peerTitle = inputActivities.items[0].peer.compactDisplayTitle
                            if inputActivities.items.count == 2 {
                                let secondPeerTitle = inputActivities.items[1].peer.compactDisplayTitle
                                stringValue = component.strings.Chat_MultipleTypingPair(peerTitle, secondPeerTitle).string
                            } else {
                                stringValue = component.strings.Chat_MultipleTypingMore(peerTitle, String(inputActivities.items.count - 1)).string
                            }
                        } else if let item = inputActivities.items.first {
                            stringValue = item.peer.compactDisplayTitle
                        }
                    }
                    let color = component.theme.rootController.navigationBar.accentTextColor
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
                    switch component.content {
                    case let .peer(peerView, customTitle, customSubtitle, onlineMemberCount, isScheduledMessages, _, customMessageCount, _):
                        if let customSubtitle {
                            let string = NSAttributedString(string: customSubtitle, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                            state = .info(string, .generic)
                        } else if let customMessageCount = customMessageCount, customMessageCount != 0 {
                            let string = NSAttributedString(string: component.strings.Conversation_Messages(Int32(customMessageCount)), font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                            state = .info(string, .generic)
                        } else if let peer = peerView.peer {
                            let servicePeer = isServicePeer(peer)
                            if peer.id == component.context.account.peerId || isScheduledMessages || peer.id.isRepliesOrVerificationCodes {
                                let string = NSAttributedString(string: "", font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                state = .info(string, .generic)
                            } else if let user = peer as? TelegramUser {
                                if user.isDeleted {
                                    state = .none
                                } else if servicePeer {
                                    let string = NSAttributedString(string: "", font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                    state = .info(string, .generic)
                                } else if user.flags.contains(.isSupport) {
                                    let statusText = component.strings.Bot_GenericSupportStatus
                                    let string = NSAttributedString(string: statusText, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                    state = .info(string, .generic)
                                } else if let _ = user.botInfo {
                                    let statusText: String
                                    if let subscriberCount = user.subscriberCount {
                                        statusText = component.strings.Conversation_StatusBotSubscribers(subscriberCount)
                                    } else {
                                        statusText = component.strings.Bot_GenericBotStatus
                                    }
                                    
                                    let string = NSAttributedString(string: statusText, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
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
                                    let (string, activity) = stringAndActivityForUserPresence(strings: component.strings, dateTimeFormat: component.dateTimeFormat, presence: EnginePeer.Presence(userPresence), relativeTo: Int32(timestamp))
                                    let attributedString = NSAttributedString(string: string, font: subtitleFont, textColor: activity ? component.theme.rootController.navigationBar.accentTextColor : component.theme.chat.inputPanel.inputControlColor)
                                    state = .info(attributedString, activity ? .online : .lastSeenTime)
                                } else {
                                    let string = NSAttributedString(string: "", font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
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
                                    
                                    string.append(NSAttributedString(string: "\(component.strings.Conversation_StatusMembers(Int32(group.participantCount))), ", font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor))
                                    string.append(NSAttributedString(string: component.strings.Conversation_StatusOnline(Int32(onlineCount)), font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor))
                                    state = .info(string, .generic)
                                } else {
                                    let string = NSAttributedString(string: component.strings.Conversation_StatusMembers(Int32(group.participantCount)), font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                    state = .info(string, .generic)
                                }
                            } else if let channel = peer as? TelegramChannel {
                                if channel.isForumOrMonoForum, customTitle != nil {
                                    let string = NSAttributedString(string: EnginePeer(peer).displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder), font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                    state = .info(string, .generic)
                                } else if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = onlineMemberCount.total ?? cachedChannelData.participantsSummary.memberCount {
                                    if memberCount == 0 {
                                        let string: NSAttributedString
                                        if case .group = channel.info {
                                            string = NSAttributedString(string: component.strings.Group_Status, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                        } else {
                                            string = NSAttributedString(string: component.strings.Channel_Status, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                        }
                                        state = .info(string, .generic)
                                    } else {
                                        if case .group = channel.info, let onlineMemberCount = onlineMemberCount.recent, onlineMemberCount > 1 {
                                            let string = NSMutableAttributedString()
                                            
                                            string.append(NSAttributedString(string: "\(component.strings.Conversation_StatusMembers(Int32(memberCount))), ", font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor))
                                            string.append(NSAttributedString(string: component.strings.Conversation_StatusOnline(Int32(onlineMemberCount)), font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor))
                                            state = .info(string, .generic)
                                        } else {
                                            let membersString: String
                                            if case .group = channel.info {
                                                membersString = component.strings.Conversation_StatusMembers(memberCount)
                                            } else {
                                                membersString = component.strings.Conversation_StatusSubscribers(memberCount)
                                            }
                                            let string = NSAttributedString(string: membersString, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                            state = .info(string, .generic)
                                        }
                                    }
                                } else {
                                    switch channel.info {
                                    case .group:
                                        let string = NSAttributedString(string: component.strings.Group_Status, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                        state = .info(string, .generic)
                                    case .broadcast:
                                        let string = NSAttributedString(string: component.strings.Channel_Status, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                                        state = .info(string, .generic)
                                    }
                                }
                            }
                        }
                    case let .custom(_, subtitle?, _):
                        let string = NSAttributedString(string: subtitle, font: subtitleFont, textColor: component.theme.chat.inputPanel.inputControlColor)
                        state = .info(string, .generic)
                    default:
                        break
                    }
                    
                    self.accessibilityValue = state.string
                }
            }
            
            var rightIconSize: CGSize?
            if let titleRightIcon {
                let rightIcon: ComponentView<Empty>
                var rightIconTransition = transition
                if let current = self.rightIcon {
                    rightIcon = current
                } else {
                    rightIconTransition = rightIconTransition.withAnimation(.none)
                    rightIcon = ComponentView()
                    self.rightIcon = rightIcon
                }
                rightIconSize = rightIcon.update(
                    transition: rightIconTransition,
                    component: AnyComponent(TitleIconComponent(
                        kind: titleRightIcon,
                        color: component.theme.chat.inputPanel.inputControlColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else if let rightIcon = self.rightIcon {
                self.rightIcon = nil
                if let rightIconView = rightIcon.view {
                    transition.setScale(view: rightIconView, scale: 0.001)
                    transition.setAlpha(view: rightIconView, alpha: 0.0, completion: { [weak rightIconView] _ in
                        rightIconView?.removeFromSuperview()
                    })
                }
            }
            
            var leftIconSize: CGSize?
            if let titleLeftIcon {
                let leftIcon: ComponentView<Empty>
                var leftIconTransition = transition
                if let current = self.leftIcon {
                    leftIcon = current
                } else {
                    leftIconTransition = leftIconTransition.withAnimation(.none)
                    leftIcon = ComponentView()
                    self.leftIcon = leftIcon
                }
                leftIconSize = leftIcon.update(
                    transition: leftIconTransition,
                    component: AnyComponent(TitleIconComponent(
                        kind: titleLeftIcon,
                        color: component.theme.chat.inputPanel.panelControlColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else if let leftIcon = self.leftIcon {
                self.leftIcon = nil
                if let leftIconView = leftIcon.view {
                    transition.setScale(view: leftIconView, scale: 0.001)
                    transition.setAlpha(view: leftIconView, alpha: 0.0, completion: { [weak leftIconView] _ in
                        leftIconView?.removeFromSuperview()
                    })
                }
            }
            
            let mapTitleIcon: (ChatTitleCredibilityIcon) -> EmojiStatusComponent.Content? = { value in
                switch value {
                case .none:
                    return nil
                case .premium:
                    return .premium(color: component.theme.list.itemAccentColor)
                case .verified:
                    return .verified(fillColor: component.theme.list.itemCheckColors.fillColor, foregroundColor: component.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
                case .fake:
                    return .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_FakeAccount.uppercased())
                case .scam:
                    return .text(color: component.theme.chat.message.incoming.scamColor, string: component.strings.Message_ScamAccount.uppercased())
                case let .emojiStatus(emojiStatus):
                    return .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.theme.list.itemAccentColor, loopMode: .count(2))
                }
            }
            
            var credibilityIconSize: CGSize?
            if let titleCredibilityIcon = mapTitleIcon(titleCredibilityIcon) {
                let credibilityIcon: ComponentView<Empty>
                if let current = self.credibilityIcon {
                    credibilityIcon = current
                } else {
                    credibilityIcon = ComponentView()
                    self.credibilityIcon = credibilityIcon
                }
                credibilityIconSize = credibilityIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: titleCredibilityIcon,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
            } else if let credibilityIcon = self.credibilityIcon {
                self.credibilityIcon = nil
                if let credibilityIconView = credibilityIcon.view {
                    transition.setScale(view: credibilityIconView, scale: 0.001)
                    transition.setAlpha(view: credibilityIconView, alpha: 0.0, completion: { [weak credibilityIconView] _ in
                        credibilityIconView?.removeFromSuperview()
                    })
                }
            }
            
            var statusIconSize: CGSize?
            if let titleStatusIcon = mapTitleIcon(titleStatusIcon) {
                let statusIcon: ComponentView<Empty>
                if let current = self.statusIcon {
                    statusIcon = current
                } else {
                    statusIcon = ComponentView()
                    self.statusIcon = statusIcon
                }
                statusIconSize = statusIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: titleStatusIcon,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
            } else if let statusIcon = self.statusIcon {
                self.statusIcon = nil
                if let statusIconView = statusIcon.view {
                    transition.setScale(view: statusIconView, scale: 0.001)
                    transition.setAlpha(view: statusIconView, alpha: 0.0, completion: { [weak statusIconView] _ in
                        statusIconView?.removeFromSuperview()
                    })
                }
            }
            
            var verifiedIconSize: CGSize?
            if let titleVerifiedIcon = mapTitleIcon(titleVerifiedIcon) {
                let verifiedIcon: ComponentView<Empty>
                if let current = self.verifiedIcon {
                    verifiedIcon = current
                } else {
                    verifiedIcon = ComponentView()
                    self.verifiedIcon = verifiedIcon
                }
                verifiedIconSize = verifiedIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: titleVerifiedIcon,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
            } else if let verifiedIcon = self.verifiedIcon {
                self.verifiedIcon = nil
                if let verifiedIconView = verifiedIcon.view {
                    transition.setScale(view: verifiedIconView, scale: 0.001)
                    transition.setAlpha(view: verifiedIconView, alpha: 0.0, completion: { [weak verifiedIconView] _ in
                        verifiedIconView?.removeFromSuperview()
                    })
                }
            }
            
            let subtitleNode: ChatTitleActivityNode
            if let current = self.subtitleNode {
                subtitleNode = current
            } else {
                subtitleNode = ChatTitleActivityNode()
                self.subtitleNode = subtitleNode
                subtitleNode.isUserInteractionEnabled = false
                self.contentContainer.addSubview(subtitleNode.view)
            }
            
            var titleLeftIconsWidth: CGFloat = 0.0
            if let leftIconSize {
                titleLeftIconsWidth += leftIconSize.width + leftTitleIconSpacing
            }
            if let verifiedIconSize {
                titleLeftIconsWidth += verifiedIconSize.width + statusIconsSpacing
            }
            
            var titleRightIconsWidth: CGFloat = 0.0
            if let rightIconSize {
                titleRightIconsWidth += rightIconSize.width + rightTitleIconSpacing
            }
            if let credibilityIconSize {
                titleRightIconsWidth += credibilityIconSize.width + statusIconsSpacing
            }
            if let statusIconSize {
                titleRightIconsWidth += statusIconSize.width + statusIconsSpacing
            }
            
            let maxTitleWidth = availableSize.width - titleLeftIconsWidth - titleRightIconsWidth - containerSideInset * 2.0
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(17.0),
                    color: component.theme.chat.inputPanel.panelControlColor,
                    items: titleSegments,
                    noDelay: false,
                    animateScale: true,
                    animateSlide: true,
                    blur: true
                )),
                environment: {},
                containerSize: CGSize(width: maxTitleWidth, height: 100.0)
            )
            
            let _ = subtitleNode.transitionToState(state, animation: transition.animation.isImmediate ? .none : .slide)
            let subtitleSize = subtitleNode.updateLayout(CGSize(width: availableSize.width - containerSideInset * 2.0, height: 100.0), alignment: .center)
            
            var minSubtitleWidth: CGFloat?
            let activityMeasureSubtitleNode: ChatTitleActivityNode
            if let current = self.activityMeasureSubtitleNode {
                activityMeasureSubtitleNode = current
            } else {
                activityMeasureSubtitleNode = ChatTitleActivityNode()
                self.activityMeasureSubtitleNode = activityMeasureSubtitleNode
            }
            let measureTypingTextString = NSAttributedString(string: component.strings.Conversation_typing, font: subtitleFont, textColor: .black)
            let _ = activityMeasureSubtitleNode.transitionToState(.typingText(measureTypingTextString, .black), animation: .none)
            let activityMeasureSubtitleSize = activityMeasureSubtitleNode.updateLayout(CGSize(width: availableSize.width - containerSideInset * 2.0, height: 100.0), alignment: .center)
            minSubtitleWidth = activityMeasureSubtitleSize.width
            
            var contentSize = titleSize
            contentSize.width += titleLeftIconsWidth + titleRightIconsWidth
            contentSize.width = max(contentSize.width, subtitleSize.width)
            if let minSubtitleWidth {
                contentSize.width = max(contentSize.width, minSubtitleWidth)
            }
            contentSize.width = max(min(150.0, availableSize.width - containerSideInset * 2.0), contentSize.width)
            contentSize.height += subtitleSize.height
            
            let containerSize = CGSize(width: contentSize.width + containerSideInset * 2.0, height: 44.0)
            let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((availableSize.height - containerSize.height) * 0.5)), size: containerSize)
            
            let titleFrame = CGRect(origin: CGPoint(x: titleLeftIconsWidth + floor((containerFrame.width - titleSize.width - titleLeftIconsWidth - titleRightIconsWidth) * 0.5), y: floor((containerFrame.height - contentSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((containerFrame.width - subtitleSize.width) * 0.5), y: titleFrame.maxY), size: subtitleSize)
            // Internally, the status view has zero width
            transition.setFrame(view: subtitleNode.view, frame: CGRect(origin: CGPoint(x: subtitleFrame.midX, y: subtitleFrame.minY), size: CGSize(width: 0.0, height: subtitleFrame.height)))
            
            var nextLeftIconX: CGFloat = titleFrame.minX
            
            if let leftIconSize, let leftIconView = self.leftIcon?.view {
                let leftIconFrame = CGRect(origin: CGPoint(x: nextLeftIconX - leftTitleIconSpacing - leftIconSize.width, y: titleFrame.minY + leftTitleIconSpacing), size: leftIconSize)
                if leftIconView.superview == nil {
                    leftIconView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(leftIconView)
                    leftIconView.frame = leftIconFrame
                    ComponentTransition.immediate.setScale(view: leftIconView, scale: 0.001)
                    leftIconView.alpha = 0.0
                }
                transition.setPosition(view: leftIconView, position: leftIconFrame.center)
                transition.setBounds(view: leftIconView, bounds: CGRect(origin: CGPoint(), size: leftIconFrame.size))
                transition.setAlpha(view: leftIconView, alpha: 1.0)
                transition.setScale(view: leftIconView, scale: 1.0)
            }
            
            if let verifiedIconSize, let verifiedIconView = self.verifiedIcon?.view {
                let verifiedIconFrame = CGRect(origin: CGPoint(x: nextLeftIconX - statusIconsSpacing - verifiedIconSize.width, y: titleFrame.minY), size: verifiedIconSize)
                if verifiedIconView.superview == nil {
                    verifiedIconView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(verifiedIconView)
                    verifiedIconView.frame = verifiedIconFrame
                    ComponentTransition.immediate.setScale(view: verifiedIconView, scale: 0.001)
                    verifiedIconView.alpha = 0.0
                }
                transition.setPosition(view: verifiedIconView, position: verifiedIconFrame.center)
                transition.setBounds(view: verifiedIconView, bounds: CGRect(origin: CGPoint(), size: verifiedIconFrame.size))
                transition.setAlpha(view: verifiedIconView, alpha: 1.0)
                transition.setScale(view: verifiedIconView, scale: 1.0)
                nextLeftIconX -= statusIconsSpacing + verifiedIconSize.width
            }
            
            var nextRightIconX: CGFloat = titleFrame.maxX
            
            if let credibilityIconSize, let credibilityIconView = self.credibilityIcon?.view {
                let credibilityIconFrame = CGRect(origin: CGPoint(x: nextRightIconX + statusIconsSpacing, y: titleFrame.minY), size: credibilityIconSize)
                if credibilityIconView.superview == nil {
                    credibilityIconView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(credibilityIconView)
                    credibilityIconView.frame = credibilityIconFrame
                    ComponentTransition.immediate.setScale(view: credibilityIconView, scale: 0.001)
                    credibilityIconView.alpha = 0.0
                }
                transition.setPosition(view: credibilityIconView, position: credibilityIconFrame.center)
                transition.setBounds(view: credibilityIconView, bounds: CGRect(origin: CGPoint(), size: credibilityIconFrame.size))
                transition.setAlpha(view: credibilityIconView, alpha: 1.0)
                transition.setScale(view: credibilityIconView, scale: 1.0)
                nextRightIconX += statusIconsSpacing + credibilityIconSize.width
            }
            
            if let statusIconSize, let statusIconView = self.statusIcon?.view {
                let statusIconFrame = CGRect(origin: CGPoint(x: nextRightIconX + statusIconsSpacing, y: titleFrame.minY), size: statusIconSize)
                if statusIconView.superview == nil {
                    statusIconView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(statusIconView)
                    statusIconView.frame = statusIconFrame
                    ComponentTransition.immediate.setScale(view: statusIconView, scale: 0.001)
                    statusIconView.alpha = 0.0
                }
                transition.setPosition(view: statusIconView, position: statusIconFrame.center)
                transition.setBounds(view: statusIconView, bounds: CGRect(origin: CGPoint(), size: statusIconFrame.size))
                transition.setAlpha(view: statusIconView, alpha: 1.0)
                transition.setScale(view: statusIconView, scale: 1.0)
                nextRightIconX += statusIconsSpacing + statusIconSize.width
            }
            
            if let rightIconSize, let rightIconView = self.rightIcon?.view {
                let rightIconFrame = CGRect(origin: CGPoint(x: nextRightIconX + rightTitleIconSpacing, y: titleFrame.minY + 5.0), size: rightIconSize)
                if rightIconView.superview == nil {
                    rightIconView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(rightIconView)
                    rightIconView.frame = rightIconFrame
                    ComponentTransition.immediate.setScale(view: rightIconView, scale: 0.001)
                    rightIconView.alpha = 0.0
                }
                transition.setPosition(view: rightIconView, position: rightIconFrame.center)
                transition.setBounds(view: rightIconView, bounds: CGRect(origin: CGPoint(), size: rightIconFrame.size))
                transition.setAlpha(view: rightIconView, alpha: 1.0)
                transition.setScale(view: rightIconView, scale: 1.0)
                nextRightIconX += rightTitleIconSpacing + rightIconSize.width
            }
            
            if component.displayBackground {
                let backgroundView: GlassBackgroundView
                if let current = self.backgroundView {
                    backgroundView = current
                } else {
                    backgroundView = GlassBackgroundView()
                    self.backgroundView = backgroundView
                    self.addSubview(backgroundView)
                    backgroundView.contentView.addSubview(self.contentContainer)
                }
                transition.setFrame(view: backgroundView, frame: containerFrame)
                backgroundView.update(size: containerFrame.size, cornerRadius: containerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: component.preferClearGlass ? .clear : .panel), isInteractive: isEnabled, transition: transition)
                transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: containerFrame.size))
                self.contentContainer.layer.cornerRadius = containerFrame.height * 0.5
            } else {
                if let backgroundView = self.backgroundView {
                    self.backgroundView = nil
                    backgroundView.removeFromSuperview()
                }
                if self.contentContainer.superview !== self {
                    self.addSubview(self.contentContainer)
                }
                transition.setFrame(view: self.contentContainer, frame: containerFrame)
                self.contentContainer.layer.cornerRadius = 0.0
            }
            
            return CGSize(width: containerSize.width, height: availableSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
