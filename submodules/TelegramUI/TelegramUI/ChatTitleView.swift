import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
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

enum ChatTitleContent {
    case peer(peerView: PeerView, onlineMemberCount: Int32?, isScheduledMessages: Bool)
    case group([Peer])
    case custom(String)
}

private final class ChatTitleNetworkStatusNode: ASDisplayNode {
    private var theme: PresentationTheme
    
    private let titleNode: ImmediateTextNode
    private let activityIndicator: ActivityIndicator
    
    var title: String = "" {
        didSet {
            if self.title != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isOpaque = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.rootController.navigationBar.primaryTextColor, 22.0, 1.5, false), speed: .slow)
        let activityIndicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(), size: activityIndicatorSize)
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activityIndicator)
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.medium(24.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        self.activityIndicator.type = .custom(self.theme.rootController.navigationBar.primaryTextColor, 22.0, 1.5, false)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let indicatorSize = self.activityIndicator.bounds.size
        let indicatorPadding = indicatorSize.width + 6.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - indicatorPadding), height: size.height))
        let combinedHeight = titleSize.height
        
        let titleFrame = CGRect(origin: CGPoint(x: indicatorPadding + floor((size.width - titleSize.width - indicatorPadding) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: titleFrame.minX - indicatorSize.width - 4.0, y: titleFrame.minY - 1.0), size: indicatorSize))
    }
}

private enum ChatTitleIcon {
    case none
    case lock
    case mute
}

final class ChatTitleView: UIView, NavigationBarTitleView {
    private let account: Account
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    private var nameDisplayOrder: PresentationPersonNameOrder
    
    private let contentContainer: ASDisplayNode
    let titleNode: ImmediateTextNode
    let titleLeftIconNode: ASImageNode
    let titleRightIconNode: ASImageNode
    let titleCredibilityIconNode: ASImageNode
    let activityNode: ChatTitleActivityNode
    
    private let button: HighlightTrackingButtonNode
    
    private var validLayout: (CGSize, CGRect)?
    
    private var titleLeftIcon: ChatTitleIcon = .none
    private var titleRightIcon: ChatTitleIcon = .none
    private var titleScamIcon = false
    
    //private var networkStatusNode: ChatTitleNetworkStatusNode?
    
    private var presenceManager: PeerPresenceStatusManager?
    
    var inputActivities: (PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            self.updateStatus()
        }
    }
    
    private func updateNetworkStatusNode(networkState: AccountNetworkState, layout: ContainerViewLayout?) {
        var isOnline = false
        if case .online = networkState {
            isOnline = true
        }
        
        /*if isOnline || layout?.metrics.widthClass == .regular {
            self.contentContainer.isHidden = false
            if let networkStatusNode = self.networkStatusNode {
                self.networkStatusNode = nil
                networkStatusNode.removeFromSupernode()
            }
        } else {
            self.contentContainer.isHidden = true
            let statusNode: ChatTitleNetworkStatusNode
            if let current = self.networkStatusNode {
                statusNode = current
            } else {
                statusNode = ChatTitleNetworkStatusNode(theme: self.theme)
                self.networkStatusNode = statusNode
                self.insertSubview(statusNode.view, aboveSubview: self.contentContainer.view)
            }
            switch self.networkState {
                case .waitingForNetwork:
                    statusNode.title = self.strings.State_WaitingForNetwork
                case let .connecting(proxy):
                    if let layout = layout, proxy != nil && layout.size.width > 320.0 {
                        statusNode.title = self.strings.State_ConnectingToProxy
                    } else {
                        statusNode.title = self.strings.State_Connecting
                    }
                case .updating:
                    statusNode.title = self.strings.State_Updating
                case .online:
                    break
            }
        }*/
        
        self.setNeedsLayout()
    }
    
    var networkState: AccountNetworkState = .online(proxy: nil) {
        didSet {
            if self.networkState != oldValue {
                updateNetworkStatusNode(networkState: self.networkState, layout: self.layout)
                self.updateStatus()
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
    
    var titleContent: ChatTitleContent? {
        didSet {
            if let titleContent = self.titleContent {
                var string: NSAttributedString?
                var titleLeftIcon: ChatTitleIcon = .none
                var titleRightIcon: ChatTitleIcon = .none
                var titleScamIcon = false
                var isEnabled = true
                switch titleContent {
                    case let .peer(peerView, _, isScheduledMessages):
                        if isScheduledMessages {
                            if peerView.peerId == self.account.peerId {
                                 string = NSAttributedString(string: self.strings.ScheduledMessages_RemindersTitle, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                            } else {
                                string = NSAttributedString(string: self.strings.ScheduledMessages_Title, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                            }
                            isEnabled = false
                        } else {
                            if let peer = peerViewMainPeer(peerView) {
                                if peerView.peerId == self.account.peerId {
                                    string = NSAttributedString(string: self.strings.Conversation_SavedMessages, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                                } else {
                                    if !peerView.peerIsContact, let user = peer as? TelegramUser, !user.flags.contains(.isSupport), user.botInfo == nil, let phone = user.phone, !phone.isEmpty {
                                        string = NSAttributedString(string: formatPhoneNumber(phone), font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                                    } else {
                                        string = NSAttributedString(string: peer.displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder), font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                                    }
                                }
                                titleScamIcon = peer.isScam
                            }
                            if peerView.peerId.namespace == Namespaces.Peer.SecretChat {
                                titleLeftIcon = .lock
                            }
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    titleRightIcon = .mute
                                }
                            }
                        }
                    case .group:
                        string = NSAttributedString(string: "Feed", font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                    case let .custom(text):
                        string = NSAttributedString(string: text, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                }
                
                if let string = string, self.titleNode.attributedText == nil || !self.titleNode.attributedText!.isEqual(to: string) {
                    self.titleNode.attributedText = string
                    self.setNeedsLayout()
                }
                
                if titleLeftIcon != self.titleLeftIcon {
                    self.titleLeftIcon = titleLeftIcon
                    switch titleLeftIcon {
                        case .lock:
                            self.titleLeftIconNode.image = PresentationResourcesChat.chatTitleLockIcon(self.theme)
                        default:
                            self.titleLeftIconNode.image = nil
                    }
                    self.setNeedsLayout()
                }
                
                if titleScamIcon != self.titleScamIcon {
                    self.titleScamIcon = titleScamIcon
                    self.titleCredibilityIconNode.image = titleScamIcon ? PresentationResourcesChatList.scamIcon(self.theme, type: .regular) : nil
                    self.setNeedsLayout()
                }
                
                if titleRightIcon != self.titleRightIcon {
                    self.titleRightIcon = titleRightIcon
                    switch titleRightIcon {
                        case .mute:
                            self.titleRightIconNode.image = PresentationResourcesChat.chatTitleMuteIcon(self.theme)
                        default:
                            self.titleRightIconNode.image = nil
                    }
                    self.setNeedsLayout()
                }
                self.isUserInteractionEnabled = isEnabled
                self.updateStatus()
            }
        }
    }
    
    private func updateStatus() {
        var inputActivitiesAllowed = true
        if let titleContent = self.titleContent {
            switch titleContent {
            case let .peer(peerView, _, isScheduledMessages):
                if let peer = peerViewMainPeer(peerView) {
                    if peer.id == self.account.peerId || isScheduledMessages {
                        inputActivitiesAllowed = false
                    }
                }
            default:
                inputActivitiesAllowed = false
            }
        }
        
        var state = ChatTitleActivityNodeState.none
        switch self.networkState {
        case .waitingForNetwork, .connecting, .updating:
            var infoText: String
            switch self.networkState {
            case .waitingForNetwork:
                infoText = self.strings.ChatState_WaitingForNetwork
            case let .connecting(proxy):
                infoText = self.strings.ChatState_Connecting
            case .updating:
                infoText = self.strings.ChatState_Updating
            case .online:
                infoText = ""
            }
            state = .info(NSAttributedString(string: infoText, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor), .generic)
        case .online:
            if let (peerId, inputActivities) = self.inputActivities, !inputActivities.isEmpty, inputActivitiesAllowed {
                var stringValue = ""
                var first = true
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
                    }
                } else {
                    for (peer, _) in inputActivities {
                        let title = peer.compactDisplayTitle
                        if !title.isEmpty {
                            if first {
                                first = false
                            } else {
                                stringValue += ", "
                            }
                            stringValue += title
                        }
                    }
                }
                let color = self.theme.rootController.navigationBar.accentTextColor
                let string = NSAttributedString(string: stringValue, font: Font.regular(13.0), textColor: color)
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
                }
            } else {
                if let titleContent = self.titleContent {
                    switch titleContent {
                        case let .peer(peerView, onlineMemberCount, isScheduledMessages):
                            if let peer = peerViewMainPeer(peerView) {
                                let servicePeer = isServicePeer(peer)
                                if peer.id == self.account.peerId || isScheduledMessages {
                                    let string = NSAttributedString(string: "", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                    state = .info(string, .generic)
                                } else if let user = peer as? TelegramUser {
                                    if servicePeer {
                                        let string = NSAttributedString(string: "", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if user.flags.contains(.isSupport) {
                                        let statusText = self.strings.Bot_GenericSupportStatus
                                        
                                        let string = NSAttributedString(string: statusText, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let _ = user.botInfo {
                                        let statusText = self.strings.Bot_GenericBotStatus
                                        
                                        let string = NSAttributedString(string: statusText, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    } else if let peer = peerViewMainPeer(peerView) {
                                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                                        let userPresence: TelegramUserPresence
                                        if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                                            userPresence = presence
                                            self.presenceManager?.reset(presence: presence)
                                        } else {
                                            userPresence = TelegramUserPresence(status: .none, lastActivity: 0)
                                        }
                                        let (string, activity) = stringAndActivityForUserPresence(strings: self.strings, dateTimeFormat: self.dateTimeFormat, presence: userPresence, relativeTo: Int32(timestamp))
                                        let attributedString = NSAttributedString(string: string, font: Font.regular(13.0), textColor: activity ? self.theme.rootController.navigationBar.accentTextColor : self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(attributedString, activity ? .online : .lastSeenTime)
                                    } else {
                                        let string = NSAttributedString(string: "", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    }
                                } else if let group = peer as? TelegramGroup {
                                    var onlineCount = 0
                                    if let cachedGroupData = peerView.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
                                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                                        for participant in participants.participants {
                                            if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                                                let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
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
                                        
                                        string.append(NSAttributedString(string: "\(strings.Conversation_StatusMembers(Int32(group.participantCount))), ", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                                        string.append(NSAttributedString(string: strings.Conversation_StatusOnline(Int32(onlineCount)), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                                        state = .info(string, .generic)
                                    } else {
                                        let string = NSAttributedString(string: strings.Conversation_StatusMembers(Int32(group.participantCount)), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                        state = .info(string, .generic)
                                    }
                                } else if let channel = peer as? TelegramChannel {
                                    if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                                        if memberCount == 0 {
                                            let string: NSAttributedString
                                            if case .group = channel.info {
                                                string = NSAttributedString(string: strings.Group_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                            } else {
                                                string = NSAttributedString(string: strings.Channel_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                            }
                                            state = .info(string, .generic)
                                        } else {
                                            if case .group = channel.info, let onlineMemberCount = onlineMemberCount, onlineMemberCount > 1 {
                                                let string = NSMutableAttributedString()
                                                
                                                string.append(NSAttributedString(string: "\(strings.Conversation_StatusMembers(Int32(memberCount))), ", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                                                string.append(NSAttributedString(string: strings.Conversation_StatusOnline(Int32(onlineMemberCount)), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                                                state = .info(string, .generic)
                                            } else {
                                                let membersString: String
                                                if case .group = channel.info {
                                                    membersString = strings.Conversation_StatusMembers(memberCount)
                                                } else {
                                                    membersString = strings.Conversation_StatusSubscribers(memberCount)
                                                }
                                                let string = NSAttributedString(string: membersString, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                            }
                                        }
                                    } else {
                                        switch channel.info {
                                            case .group:
                                                let string = NSAttributedString(string: strings.Group_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                            case .broadcast:
                                                let string = NSAttributedString(string: strings.Channel_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                                                state = .info(string, .generic)
                                        }
                                    }
                                }
                            }
                        default:
                            break
                    }
                    
                    self.accessibilityLabel = self.titleNode.attributedText?.string
                    self.accessibilityValue = state.string
                } else {
                    self.accessibilityLabel = nil
                }
            }
        }
        
        if self.activityNode.transitionToState(state, animation: .slide) {
            self.setNeedsLayout()
        }
    }
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        
        self.contentContainer = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isOpaque = false
        
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
            self?.updateStatus()
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
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        //self.networkStatusNode?.updateTheme(theme: theme)
        let titleContent = self.titleContent
        self.titleContent = titleContent
        self.updateStatus()
        
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, clearBounds)
        
        let transition: ContainedViewLayoutTransition = .immediate
        
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
        if size.height > 40.0 {
            var titleSize = self.titleNode.updateLayout(CGSize(width: clearBounds.width - leftIconWidth - credibilityIconWidth - rightIconWidth - titleSideInset * 2.0, height: size.height))
            titleSize.width += credibilityIconWidth
            let activitySize = self.activityNode.updateLayout(clearBounds.size, alignment: .center)
            let titleInfoSpacing: CGFloat = 0.0
            
            var titleFrame: CGRect
            
            if activitySize.height.isZero {
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                self.titleNode.frame = titleFrame
            } else {
                let combinedHeight = titleSize.height + activitySize.height + titleInfoSpacing
                
                titleFrame = CGRect(origin: CGPoint(x: floor((clearBounds.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
                if titleFrame.size.width < size.width {
                    titleFrame.origin.x = -clearBounds.minX + floor((size.width - titleFrame.width) / 2.0)
                }
                titleFrame.origin.x = max(titleFrame.origin.x, clearBounds.minX + leftIconWidth)
                self.titleNode.frame = titleFrame
                
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
                self.titleCredibilityIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.width - image.size.width - 1.0, y: 2.0), size: image.size)
            }
            if let image = self.titleRightIconNode.image {
                self.titleRightIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.width + 3.0, y: 6.0), size: image.size)
            }
        } else {
            let titleSize = self.titleNode.updateLayout(CGSize(width: floor(clearBounds.width / 2.0 - leftIconWidth - credibilityIconWidth - rightIconWidth - titleSideInset * 2.0), height: size.height))
            let activitySize = self.activityNode.updateLayout(CGSize(width: floor(clearBounds.width / 2.0), height: size.height), alignment: .center)
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + leftIconWidth + credibilityIconWidth + rightIconWidth + activitySize.width + titleInfoSpacing
            
            let titleFrame = CGRect(origin: CGPoint(x: leftIconWidth + floor((clearBounds.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.titleNode.frame = titleFrame
            self.activityNode.frame = CGRect(origin: CGPoint(x: floor((clearBounds.width - combinedWidth) / 2.0 + titleSize.width + leftIconWidth + credibilityIconWidth + rightIconWidth + titleInfoSpacing), y: floor((size.height - activitySize.height) / 2.0)), size: activitySize)
            
            if let image = self.titleLeftIconNode.image {
                self.titleLeftIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.minY + 4.0), size: image.size)
            }
            if let image = self.titleCredibilityIconNode.image {
                self.titleCredibilityIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX - image.size.width - 1.0, y: titleFrame.minY + 6.0), size: image.size)
            }
            if let image = self.titleRightIconNode.image {
                self.titleRightIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX - image.size.width - 1.0, y: titleFrame.minY + 6.0), size: image.size)
            }
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
    
    func animateLayoutTransition() {
        UIView.transition(with: self, duration: 0.25, options: [.transitionCrossDissolve], animations: {
        }, completion: nil)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.button.frame.contains(point) {
            return self.button.view
        }
        return super.hitTest(point, with: event)
    }
}
