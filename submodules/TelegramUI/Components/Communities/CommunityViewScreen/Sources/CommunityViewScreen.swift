import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import EdgeEffect
import ResizableSheetComponent
import ListActionItemComponent
import ListSectionComponent
import ListItemComponentAdaptor
import PeerListItemComponent
import AlertComponent
import AlertUI
import UndoUI
import ChatListUI
import ChatListHeaderComponent
import ChatListTitleView
import ContextUI
import SearchUI
import ItemListUI
import PeerSelectionScreen
import CommunityPrivateChatScreen
import AvatarComponent

private extension CommunityViewScreenMode {
    var usesGroupedStyle: Bool {
        return self == .sheet
    }

    var usesPlainStyle: Bool {
        return self != .sheet
    }

    var usesSheetPresentation: Bool {
        return self == .sheet
    }

    var usesFullscreenPresentation: Bool {
        return self != .sheet
    }

    var isPreview: Bool {
        return self == .preview
    }
}

private final class CommunityChatPreviewContextContentSource: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?

    let navigationController: NavigationController?

    let passthroughTouches: Bool = true

    init(controller: ViewController, sourceNode: ASDisplayNode?, navigationController: NavigationController?) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.navigationController = navigationController
    }

    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }

    func animatedIn() {
    }
}

private struct CommunityChatPreviewData: Equatable {
    var messages: [EngineMessage]
    var readCounters: EnginePeerReadCounters

    var timestamp: Int32 {
        return self.messages.map(\.timestamp).max() ?? 0
    }

    var searchText: String {
        return self.messages.map(\.text).joined(separator: " ")
    }
}

private enum CommunityViewSection: Int {
    case joined
    case visible
    case requestable
    case hidden
}

private struct CommunityViewRow: Equatable {
    let peer: EnginePeer
    let linkedPeer: CachedCommunityData.CommunityLinkedPeer
}

private func communitySelectionPeerMatchesRequestTypes(peer: EnginePeer, requestPeerType: [ReplyMarkupButtonRequestPeerType]?) -> Bool {
    guard let requestPeerType else {
        return true
    }
    guard !peer.isDeleted else {
        return false
    }

    for peerType in requestPeerType {
        var match = false
        switch peerType {
        case let .user(userType):
            if case let .user(user) = peer {
                match = true
                if user.id.isVerificationCodes {
                    match = false
                }
                if let isBot = userType.isBot, isBot != (user.botInfo != nil) {
                    match = false
                }
                if let isPremium = userType.isPremium, isPremium != user.isPremium {
                    match = false
                }
            }
        case let .group(groupType):
            if case let .legacyGroup(group) = peer {
                match = true
                if groupType.isCreator {
                    if case .creator = group.role {
                    } else {
                        match = false
                    }
                }
                if let isForum = groupType.isForum, isForum {
                    match = false
                }
                if let hasUsername = groupType.hasUsername, hasUsername {
                    match = false
                }
                if let userAdminRights = groupType.userAdminRights {
                    if case .creator = group.role, userAdminRights.rights.contains(.canBeAnonymous) {
                        match = false
                    } else if case let .admin(rights, _) = group.role {
                        if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                            match = false
                        }
                    } else if case .member = group.role {
                        match = false
                    }
                }
            } else if case let .channel(channel) = peer, case .group = channel.info {
                match = true
                if groupType.isCreator, !channel.flags.contains(.isCreator) {
                    match = false
                }
                if let isForum = groupType.isForum, isForum != channel.isForum {
                    match = false
                }
                if let hasUsername = groupType.hasUsername, hasUsername != (!(channel.addressName ?? "").isEmpty) {
                    match = false
                }
                if let userAdminRights = groupType.userAdminRights {
                    if channel.flags.contains(.isCreator) {
                        if let rights = channel.adminRights, rights.rights.contains(.canBeAnonymous) != userAdminRights.rights.contains(.canBeAnonymous) {
                            match = false
                        }
                    } else if let rights = channel.adminRights {
                        if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                            match = false
                        }
                    } else {
                        match = false
                    }
                }
            }
        case let .channel(channelType):
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                match = true
                if channelType.isCreator, !channel.flags.contains(.isCreator) {
                    match = false
                }
                if let hasUsername = channelType.hasUsername, hasUsername != (!(channel.addressName ?? "").isEmpty) {
                    match = false
                }
                if let userAdminRights = channelType.userAdminRights {
                    if channel.flags.contains(.isCreator) {
                        if let rights = channel.adminRights, rights.rights.contains(.canBeAnonymous) != userAdminRights.rights.contains(.canBeAnonymous) {
                            match = false
                        }
                    } else if let rights = channel.adminRights {
                        if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                            match = false
                        }
                    } else {
                        match = false
                    }
                }
            }
        case .createBot:
            break
        }
        if match {
            return true
        }
    }

    return false
}

private func communitySelectionPeerState(peer: EnginePeer, isJoined: Bool, options: CommunityPeerSelectionOptions) -> (isVisible: Bool, isEnabled: Bool, disabledReason: ChatListDisabledPeerReason) {
    let filter = options.filter

    if options.excludedPeerIds.contains(peer.id) {
        return (false, false, .generic)
    }
    if !communitySelectionPeerMatchesRequestTypes(peer: peer, requestPeerType: options.requestPeerType) {
        return (false, false, .generic)
    }
    if filter.contains(.excludeSecretChats), peer.id.namespace == Namespaces.Peer.SecretChat {
        return (false, false, .generic)
    }

    switch peer {
    case let .user(user):
        if user.id.isRepliesOrVerificationCodes {
            return (false, false, .generic)
        }
        if user.botInfo != nil {
            if filter.contains(.excludeBots) {
                return (false, false, .generic)
            }
        } else if filter.contains(.excludeUsers) {
            return (false, false, .generic)
        }
    case .legacyGroup:
        if filter.contains(.excludeGroups) {
            return (false, false, .generic)
        }
    case let .channel(channel):
        switch channel.info {
        case .broadcast:
            if filter.contains(.excludeChannels) {
                return (false, false, .generic)
            }
        case .group:
            if filter.contains(.excludeGroups) {
                return (false, false, .generic)
            }
        }
    case .secretChat:
        break
    case .community:
        return (false, false, .generic)
    }

    if filter.contains(.onlyPrivateChats) {
        switch peer {
        case .user, .secretChat:
            break
        default:
            return (false, false, .generic)
        }
    }

    if filter.contains(.onlyGroupsAndChannels) {
        if case .legacyGroup = peer {
        } else if case .channel = peer {
        } else {
            return (false, false, .generic)
        }
    } else {
        if filter.contains(.onlyGroups) {
            if case .legacyGroup = peer {
            } else if case let .channel(channel) = peer, case .group = channel.info {
            } else {
                return (false, false, .generic)
            }
        }
        if filter.contains(.onlyChannels) {
            if case let .channel(channel) = peer, case .broadcast = channel.info {
            } else {
                return (false, false, .generic)
            }
        }
    }

    var enabled = true
    if filter.contains(.onlyWriteable), !canSendMessagesToPeer(peer) {
        enabled = false
    }

    if filter.contains(.onlyManageable) {
        var canManage = false
        if case let .legacyGroup(group) = peer {
            switch group.role {
            case .creator, .admin:
                canManage = true
            default:
                break
            }
        } else if case let .channel(channel) = peer, case .group = channel.info, channel.hasPermission(.inviteMembers) {
            canManage = true
        } else if case let .channel(channel) = peer, case .broadcast = channel.info, channel.hasPermission(.addAdmins) {
            canManage = true
        }
        if !canManage {
            enabled = false
        }
    }

    if !enabled {
        if filter.contains(.excludeDisabled) || !isJoined {
            return (false, false, .generic)
        } else {
            return (true, false, .generic)
        }
    }

    return (true, true, .generic)
}

private struct CommunityViewRequestRow: Equatable {
    let request: CommunityPeerRequest
    let peer: EnginePeer
    let requestedBy: EnginePeer?
    let memberCount: Int32?
    let isPrivate: Bool
    let isVisible: Bool
}

private struct PendingCommunityViewRequestAction {
    let request: CommunityPeerRequest
    let approve: Bool
    var isCommitted: Bool
}

private final class CommunityViewPendingAccessoryComponent: Component {
    let count: Int32?
    let theme: PresentationTheme

    init(count: Int32?, theme: PresentationTheme) {
        self.count = count
        self.theme = theme
    }

    static func ==(lhs: CommunityViewPendingAccessoryComponent, rhs: CommunityViewPendingAccessoryComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private let badgeBackgroundView = UIView()
        private let chevronView = UIImageView()
        private var component: CommunityViewPendingAccessoryComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.badgeBackgroundView)
            self.addSubview(self.chevronView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: CommunityViewPendingAccessoryComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            if themeUpdated || self.chevronView.image == nil {
                self.chevronView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
            }

            let countValue = component.count.flatMap { $0 > 0 ? Int($0) : nil }
            var textSize = CGSize()
            if let countValue {
                textSize = self.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "\(countValue)",
                            font: Font.medium(12.0),
                            textColor: component.theme.list.itemCheckColors.foregroundColor
                        )),
                        horizontalAlignment: .center,
                        verticalAlignment: .middle
                    )),
                    environment: {},
                    containerSize: CGSize(width: 80.0, height: 20.0)
                )
                if let textView = self.text.view {
                    if textView.superview == nil {
                        self.insertSubview(textView, aboveSubview: self.badgeBackgroundView)
                    }
                    textView.isHidden = false
                    textView.backgroundColor = nil
                }
                self.badgeBackgroundView.isHidden = false
                self.badgeBackgroundView.backgroundColor = component.theme.list.itemCheckColors.fillColor
                self.badgeBackgroundView.layer.cornerRadius = 10.0
                self.badgeBackgroundView.clipsToBounds = true
            } else {
                self.text.view?.isHidden = true
                self.badgeBackgroundView.isHidden = true
            }

            let chevronSize = self.chevronView.image?.size ?? CGSize(width: 8.0, height: 13.0)
            let spacing: CGFloat = countValue == nil ? 0.0 : 4.0
            let size = CGSize(width: textSize.width + spacing + chevronSize.width - 9.0, height: max(20.0, chevronSize.height))

            var currentX: CGFloat = 0.0
            if countValue != nil {
                let badgeBackgroundSize = CGSize(width: max(20.0, textSize.width), height: 20.0)
                transition.setFrame(view: self.badgeBackgroundView, frame: CGRect(
                    origin: CGPoint(x: currentX + textSize.width * 0.5 - badgeBackgroundSize.width * 0.5, y: floor((size.height - badgeBackgroundSize.height) * 0.5)),
                    size: badgeBackgroundSize
                ))
                if let textView = self.text.view {
                    transition.setFrame(view: textView, frame: CGRect(
                        origin: CGPoint(x: currentX, y: floor((size.height - textSize.height) * 0.5)),
                        size: textSize
                    ))
                }
                currentX += textSize.width + spacing
            }
            transition.setFrame(view: self.chevronView, frame: CGRect(
                origin: CGPoint(x: currentX, y: floor((size.height - chevronSize.height) * 0.5)),
                size: chevronSize
            ))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private func communityChatPreviewSignal(context: AccountContext, peerId: EnginePeer.Id) -> Signal<(EnginePeer.Id, CommunityChatPreviewData), NoError> {
    var ignoredNamespaces = Set<Int32>()
    ignoredNamespaces = ignoredNamespaces.union(Namespaces.Message.allNonRegular)
    ignoredNamespaces = ignoredNamespaces.union(Namespaces.Message.allEphemeral)

    return combineLatest(
        context.account.postbox.aroundMessageHistoryViewForLocation(
            .peer(peerId: peerId, threadId: nil),
            anchor: .upperBound,
            ignoreMessagesInTimestampRange: nil,
            ignoreMessageIds: Set(),
            count: 10,
            clipHoles: false,
            fixedCombinedReadStates: nil,
            topTaggedMessageIdNamespaces: Set(),
            tag: nil,
            appendMessagesFromTheSameGroup: false,
            namespaces: .not(ignoredNamespaces),
            orderStatistics: []
        ),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId)),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global())
    )
    |> map { viewData, readCounters, peer, notificationSettings, globalNotificationSettings -> (EnginePeer.Id, CommunityChatPreviewData) in
        let (view, _, _) = viewData
        var messages: [EngineMessage] = []
        for i in (0 ..< view.entries.count).reversed() {
            if messages.isEmpty {
                messages.append(EngineMessage(view.entries[i].message))
            } else if messages[0].groupingKey != nil && messages[0].groupingKey == view.entries[i].message.groupingKey {
                messages.append(EngineMessage(view.entries[i].message))
            }
        }
        messages = messages.reversed()

        var isMuted = false
        if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
            isMuted = true
        } else if case .default = notificationSettings.muteState, let peer {
            if case .user = peer {
                isMuted = !globalNotificationSettings.privateChats.enabled
            } else if case .legacyGroup = peer {
                isMuted = !globalNotificationSettings.groupChats.enabled
            } else if case let .channel(channel) = peer {
                switch channel.info {
                case .group:
                    isMuted = !globalNotificationSettings.groupChats.enabled
                case .broadcast:
                    isMuted = !globalNotificationSettings.channels.enabled
                }
            }
        }
        let effectiveReadCounters = EnginePeerReadCounters(state: readCounters._asReadCounters(), isMuted: isMuted)

        return (peerId, CommunityChatPreviewData(messages: messages, readCounters: effectiveReadCounters))
    }
}

private func communityChatPreviewsSignal(context: AccountContext, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: CommunityChatPreviewData], NoError> {
    if peerIds.isEmpty {
        return .single([:])
    }

    return combineLatest(peerIds.map { peerId in
        return communityChatPreviewSignal(context: context, peerId: peerId)
    })
    |> map { values -> [EnginePeer.Id: CommunityChatPreviewData] in
        var result: [EnginePeer.Id: CommunityChatPreviewData] = [:]
        for (peerId, preview) in values {
            result[peerId] = preview
        }
        return result
    }
}

private func communityChatContextMenuItems(context: AccountContext, peer: EnginePeer, canMute: Bool, canRemove: Bool, removePeer: @escaping () -> Void) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    let peerId = peer.id
    let removeItem: () -> ContextMenuItem = {
        return .action(ContextMenuActionItem(text: strings.GroupInfo_ActionRemove, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
        }, action: { c, f in
            if let c {
                c.dismiss(completion: {
                    removePeer()
                })
            } else {
                f(.dismissWithoutContent)
                removePeer()
            }
        }))
    }

    if !canMute {
        var items: [ContextMenuItem] = []
        if canRemove {
            items.append(removeItem())
        }
        return .single(items)
    }

    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId),
        TelegramEngine.EngineData.Item.NotificationSettings.Global()
    )
    |> map { notificationSettings, globalNotificationSettings -> [ContextMenuItem] in
        var isMuted = false
        if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
            isMuted = true
        } else if case .default = notificationSettings.muteState {
            if case .user = peer {
                isMuted = !globalNotificationSettings.privateChats.enabled
            } else if case .legacyGroup = peer {
                isMuted = !globalNotificationSettings.groupChats.enabled
            } else if case let .channel(channel) = peer {
                switch channel.info {
                case .group:
                    isMuted = !globalNotificationSettings.groupChats.enabled
                case .broadcast:
                    isMuted = !globalNotificationSettings.channels.enabled
                }
            }
        }

        var items: [ContextMenuItem] = []
        if canMute {
            items.append(.action(ContextMenuActionItem(text: isMuted ? strings.ChatList_Context_Unmute : strings.ChatList_Context_Mute, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                let _ = (context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil)
                |> deliverOnMainQueue).startStandalone(completed: {
                    f(.default)
                })
            })))
        }

        if canRemove {
            items.append(removeItem())
        }

        return items
    }
}

private func communityChatPeerIsCreatedByAccount(_ peer: EnginePeer) -> Bool {
    switch peer {
    case let .legacyGroup(group):
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    case let .channel(channel):
        return channel.flags.contains(.isCreator)
    default:
        return false
    }
}

private func communityChatCanRemovePeer(community: TelegramCommunity?, peer: EnginePeer) -> Bool {
    if community?.hasPermission(.manageLinkedPeers) == true {
        return true
    }
    return communityChatPeerIsCreatedByAccount(peer)
}

private func communityCachedMemberCounts(_ data: [EnginePeer.Id: CachedPeerData]) -> [EnginePeer.Id: Int32] {
    var result: [EnginePeer.Id: Int32] = [:]
    for (peerId, cachedData) in data {
        if let cachedData = cachedData as? CachedChannelData, let count = cachedData.participantsSummary.memberCount {
            result[peerId] = count
        } else if let cachedData = cachedData as? CachedGroupData {
            result[peerId] = Int32(cachedData.participants?.participants.count ?? 0)
        }
    }
    return result
}

private func communityChatListContextActionsEqual(_ lhs: ChatListItem.EnabledContextActions?, _ rhs: ChatListItem.EnabledContextActions?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (.auto?, .auto?):
        return true
    case let (.custom(lhsActions)?, .custom(rhsActions)?):
        return lhsActions.rawValue == rhsActions.rawValue
    default:
        return false
    }
}

private final class CommunityChatListItemGenerator: ListItemComponentAdaptor.ItemGenerator {
    let context: AccountContext
    let presentationData: ChatListPresentationData
    let peer: EnginePeer
    let preview: CommunityChatPreviewData
    let interaction: ChatListNodeInteraction
    let enabledContextActions: ChatListItem.EnabledContextActions?
    let hasActiveRevealControls: Bool
    let isHidden: Bool
    let hasNext: Bool

    init(
        context: AccountContext,
        presentationData: ChatListPresentationData,
        peer: EnginePeer,
        preview: CommunityChatPreviewData,
        interaction: ChatListNodeInteraction,
        enabledContextActions: ChatListItem.EnabledContextActions?,
        hasActiveRevealControls: Bool,
        isHidden: Bool,
        hasNext: Bool
    ) {
        self.context = context
        self.presentationData = presentationData
        self.peer = peer
        self.preview = preview
        self.interaction = interaction
        self.enabledContextActions = enabledContextActions
        self.hasActiveRevealControls = hasActiveRevealControls
        self.isHidden = isHidden
        self.hasNext = hasNext
    }

    static func ==(lhs: CommunityChatListItemGenerator, rhs: CommunityChatListItemGenerator) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.preview != rhs.preview {
            return false
        }
        if !communityChatListContextActionsEqual(lhs.enabledContextActions, rhs.enabledContextActions) {
            return false
        }
        if lhs.hasActiveRevealControls != rhs.hasActiveRevealControls {
            return false
        }
        if lhs.isHidden != rhs.isHidden {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        if lhs.presentationData.theme !== rhs.presentationData.theme {
            return false
        }
        if lhs.presentationData.fontSize != rhs.presentationData.fontSize {
            return false
        }
        if lhs.presentationData.strings !== rhs.presentationData.strings {
            return false
        }
        if lhs.presentationData.dateTimeFormat != rhs.presentationData.dateTimeFormat {
            return false
        }
        if lhs.presentationData.nameSortOrder != rhs.presentationData.nameSortOrder {
            return false
        }
        if lhs.presentationData.nameDisplayOrder != rhs.presentationData.nameDisplayOrder {
            return false
        }
        if lhs.presentationData.disableAnimations != rhs.presentationData.disableAnimations {
            return false
        }
        return true
    }

    func item() -> ListViewItem {
        let messageIndex: EngineMessage.Index
        if let message = self.preview.messages.first {
            messageIndex = message.index
        } else {
            messageIndex = EngineMessage.Index(
                id: EngineMessage.Id(peerId: self.peer.id, namespace: Namespaces.Message.Cloud, id: 0),
                timestamp: 0
            )
        }

        return ChatListItem(
            presentationData: self.presentationData,
            context: self.context,
            chatListLocation: .chatList(groupId: .root),
            filterData: nil,
            index: .chatList(EngineChatListIndex(pinningIndex: nil, messageIndex: messageIndex)),
            content: .peer(ChatListItemContent.PeerData(
                messages: self.preview.messages,
                peer: EngineRenderedPeer(peer: self.peer),
                threadInfo: nil,
                combinedReadState: self.preview.readCounters,
                isRemovedFromTotalUnreadCount: self.preview.readCounters.isMuted,
                presence: nil,
                hasUnseenMentions: false,
                hasUnseenReactions: false,
                hasUnseenPollVotes: false,
                draftState: nil,
                mediaDraftContentType: nil,
                inputActivities: [],
                promoInfo: nil,
                ignoreUnreadBadge: false,
                displayAsMessage: false,
                hasFailedMessages: false,
                forumTopicData: nil,
                topForumTopicItems: [],
                autoremoveTimeout: nil,
                storyState: nil,
                requiresPremiumForMessaging: false,
                displayAsTopicList: false,
                tags: []
            )),
            editing: false,
            hasActiveRevealControls: self.hasActiveRevealControls,
            selected: false,
            header: nil,
            enabledContextActions: self.enabledContextActions,
            hiddenOffset: false,
            interaction: self.interaction,
            useCommunityViewLayout: true,
            displayHiddenPeerIcon: self.isHidden
        )
    }
}

private final class CommunityViewBottomButtonComponent: Component {
    let theme: PresentationTheme
    let title: String
    let iconName: String?
    let safeInsets: UIEdgeInsets
    let isEnabled: Bool
    let displaysProgress: Bool
    let action: () -> Void

    init(
        theme: PresentationTheme,
        title: String,
        iconName: String?,
        safeInsets: UIEdgeInsets,
        isEnabled: Bool,
        displaysProgress: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.iconName = iconName
        self.safeInsets = safeInsets
        self.isEnabled = isEnabled
        self.displaysProgress = displaysProgress
        self.action = action
    }

    static func ==(lhs: CommunityViewBottomButtonComponent, rhs: CommunityViewBottomButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.displaysProgress != rhs.displaysProgress {
            return false
        }
        return true
    }

    final class View: UIView {
        private let button = ComponentView<Empty>()

        func update(component: CommunityViewBottomButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            var buttonItems: [AnyComponentWithIdentity<Empty>] = []
            if let iconName = component.iconName {
                buttonItems.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(
                    name: iconName,
                    tintColor: component.theme.list.itemCheckColors.foregroundColor
                ))))
            }
            buttonItems.append(AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(
                text: component.title,
                font: Font.semibold(17.0),
                color: component.theme.list.itemCheckColors.foregroundColor
            ))))

            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: component.title, component: AnyComponent(HStack(buttonItems, spacing: 8.0))),
                    isEnabled: component.isEnabled,
                    displaysProgress: component.displaysProgress,
                    action: component.action
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 52.0)
            )

            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(
                    origin: CGPoint(x: 0.0, y: 0.0),
                    size: CGSize(width: availableSize.width, height: buttonSize.height)
                ))
            }

            return CGSize(width: availableSize.width, height: buttonSize.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class CommunityViewContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id
    let mode: CommunityViewScreenMode
    let topInset: CGFloat
    let community: TelegramCommunity?
    let cachedData: CachedCommunityData?
    let peers: [EnginePeer.Id: EnginePeer]
    let cachedPeerData: [EnginePeer.Id: CachedPeerData]
    let previews: [EnginePeer.Id: CommunityChatPreviewData]
    let pendingRequests: CommunityPeerLinkRequests?
    let pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData]
    let pendingRequestInFlightPeerId: EnginePeer.Id?
    let pendingRequestInFlightApprove: Bool?
    let joinedPeerIds: Set<EnginePeer.Id>
    let selectionOptions: CommunityPeerSelectionOptions?
    let toggleCollapsed: (Bool) -> Void
    let setRequestApproval: (CommunityPeerRequest, EnginePeer, Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openPendingRequests: () -> Void
    let removePeer: (EnginePeer.Id) -> Void

    init(
        context: AccountContext,
        communityId: EnginePeer.Id,
        mode: CommunityViewScreenMode,
        topInset: CGFloat,
        community: TelegramCommunity?,
        cachedData: CachedCommunityData?,
        peers: [EnginePeer.Id: EnginePeer],
        cachedPeerData: [EnginePeer.Id: CachedPeerData],
        previews: [EnginePeer.Id: CommunityChatPreviewData],
        pendingRequests: CommunityPeerLinkRequests?,
        pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData],
        pendingRequestInFlightPeerId: EnginePeer.Id?,
        pendingRequestInFlightApprove: Bool?,
        joinedPeerIds: Set<EnginePeer.Id>,
        selectionOptions: CommunityPeerSelectionOptions?,
        toggleCollapsed: @escaping (Bool) -> Void,
        setRequestApproval: @escaping (CommunityPeerRequest, EnginePeer, Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openPendingRequests: @escaping () -> Void,
        removePeer: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.communityId = communityId
        self.mode = mode
        self.topInset = topInset
        self.community = community
        self.cachedData = cachedData
        self.peers = peers
        self.cachedPeerData = cachedPeerData
        self.previews = previews
        self.pendingRequests = pendingRequests
        self.pendingRequestCachedPeerData = pendingRequestCachedPeerData
        self.pendingRequestInFlightPeerId = pendingRequestInFlightPeerId
        self.pendingRequestInFlightApprove = pendingRequestInFlightApprove
        self.joinedPeerIds = joinedPeerIds
        self.selectionOptions = selectionOptions
        self.toggleCollapsed = toggleCollapsed
        self.setRequestApproval = setRequestApproval
        self.openPeer = openPeer
        self.openPendingRequests = openPendingRequests
        self.removePeer = removePeer
    }

    static func ==(lhs: CommunityViewContentComponent, rhs: CommunityViewContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.community != rhs.community {
            return false
        }
        if lhs.cachedData !== rhs.cachedData {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if communityCachedMemberCounts(lhs.cachedPeerData) != communityCachedMemberCounts(rhs.cachedPeerData) {
            return false
        }
        if lhs.previews != rhs.previews {
            return false
        }
        if lhs.pendingRequests != rhs.pendingRequests {
            return false
        }
        if communityCachedMemberCounts(lhs.pendingRequestCachedPeerData) != communityCachedMemberCounts(rhs.pendingRequestCachedPeerData) {
            return false
        }
        if lhs.pendingRequestInFlightPeerId != rhs.pendingRequestInFlightPeerId {
            return false
        }
        if lhs.pendingRequestInFlightApprove != rhs.pendingRequestInFlightApprove {
            return false
        }
        if lhs.joinedPeerIds != rhs.joinedPeerIds {
            return false
        }
        if lhs.selectionOptions !== rhs.selectionOptions {
            return false
        }
        return true
    }

    final class View: UIView {
        private let collapseSection = ComponentView<Empty>()
        private let collapseFooter = ComponentView<Empty>()
        private let pendingRequestsSection = ComponentView<Empty>()
        private var sectionViews: [CommunityViewSection: ComponentView<Empty>] = [:]

        private var component: CommunityViewContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var interaction: ChatListNodeInteraction?
        private var revealedPeerId: EnginePeer.Id?
        private let pendingRequestsIcon = renderSettingsIcon(name: "Item List/Icons/Requests", backgroundColors: [UIColor(rgb: 0x0079ff)])

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func presentRemovePeerConfirmation(peerId: EnginePeer.Id) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: environment.strings.Community_RemoveChat_Title,
                text: environment.strings.Community_RemoveChat_Text,
                actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultDestructiveAction, title: environment.strings.Community_RemoveChat_Remove, action: {
                        component.removePeer(peerId)
                    })
                ]
            ), in: .window(.root))
        }

        private func presentHiddenChatToast() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .banned(text: presentationData.strings.Community_View_HiddenChatToast),
                position: .bottom,
                animateInAsReplacement: false,
                action: { _ in return true }
            ), in: .current)
        }

        private func activateChatPreview(item: ChatListItem, sourceNode: ASDisplayNode, gesture: ContextGesture?) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                gesture?.cancel()
                return
            }
            guard case let .peer(peerData) = item.content, let peer = peerData.peer.peer else {
                gesture?.cancel()
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            var dismissPreviewingImpl: ((Bool) -> (() -> Void))?
            let previewController: ViewController
            if case let .channel(channel) = peer, channel.isForum {
                let chatListController = ChatListControllerImpl(context: component.context, location: .forum(peerId: channel.id), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                chatListController.navigationPresentation = .master
                previewController = chatListController
            } else {
                let chatController = component.context.sharedContext.makeChatController(context: component.context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.previewing), params: nil)
                chatController.customNavigationController = controller.navigationController as? NavigationController
                chatController.canReadHistory.set(false)
                chatController.dismissPreviewing = { animateIn in
                    return dismissPreviewingImpl?(animateIn) ?? {}
                }
                previewController = chatController
            }

            let source: ContextContentSource = .controller(CommunityChatPreviewContextContentSource(
                controller: previewController,
                sourceNode: sourceNode,
                navigationController: controller.navigationController as? NavigationController
            ))
            let contextController = makeContextController(context: component.context, presentationData: presentationData, source: source, items: communityChatContextMenuItems(
                context: component.context,
                peer: peer,
                canMute: component.joinedPeerIds.contains(peer.id),
                canRemove: communityChatCanRemovePeer(community: component.community, peer: peer),
                removePeer: { [weak self] in
                    self?.presentRemovePeerConfirmation(peerId: peer.id)
                }
            ) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
            controller.presentInGlobalOverlay(contextController)

            dismissPreviewingImpl = { [weak controller, weak contextController] animateIn in
                if let controller, let contextController {
                    if animateIn {
                        contextController.statusBar.statusBarStyle = .Ignore
                        contextController.animateDismissalIfNeeded()
                        controller.present(contextController, in: .window(.root))
                        return {
                            contextController.dismissNow()
                        }
                    } else {
                        contextController.dismiss()
                    }
                }
                return {}
            }
        }

        private func makeInteraction(component: CommunityViewContentComponent) -> ChatListNodeInteraction {
            if let current = self.interaction {
                return current
            }

            let interaction = ChatListNodeInteraction(
                context: component.context,
                animationCache: component.context.animationCache,
                animationRenderer: component.context.animationRenderer,
                activateSearch: {},
                peerSelected: { [weak self] peer, _, _, _, _ in
                    self?.component?.openPeer(peer)
                },
                disabledPeerSelected: { _, _, _ in },
                togglePeerSelected: { _, _ in },
                togglePeersSelection: { _, _ in },
                additionalCategorySelected: { _ in },
                messageSelected: { _, _, _, _ in },
                groupSelected: { _ in },
                addContact: { _ in },
                setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
                    guard let self else {
                        return
                    }
                    if (peerId == nil && fromPeerId == self.revealedPeerId) || (peerId != nil && fromPeerId == nil) || (peerId == nil && fromPeerId == nil) {
                        self.revealedPeerId = peerId
                        self.state?.updated(transition: .immediate)
                    }
                },
                setItemPinned: { _, _ in },
                setPeerMuted: { [weak self] peerId, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    let _ = (component.context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil)
                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.revealedPeerId = nil
                        self.state?.updated(transition: .immediate)
                    })
                },
                setPeerThreadMuted: { _, _, _ in },
                deletePeer: { [weak self] peerId, _ in
                    self?.presentRemovePeerConfirmation(peerId: peerId)
                },
                deletePeerThread: { _, _ in },
                setPeerThreadStopped: { _, _, _ in },
                setPeerThreadPinned: { _, _, _ in },
                setPeerThreadHidden: { _, _, _ in },
                updatePeerGrouping: { _, _ in },
                togglePeerMarkedUnread: { _, _ in },
                toggleArchivedFolderHiddenByDefault: {},
                toggleThreadsSelection: { _, _ in },
                hidePsa: { _ in },
                activateChatPreview: { [weak self] item, _, node, gesture, _ in
                    self?.activateChatPreview(item: item, sourceNode: node, gesture: gesture)
                },
                present: { _ in },
                openForumThread: { _, _ in },
                openStorageManagement: {},
                openPasswordSetup: {},
                openPremiumIntro: {},
                openPremiumGift: { _, _ in },
                openPremiumManagement: {},
                openActiveSessions: {},
                openBirthdaySetup: {},
                performActiveSessionAction: { _, _ in },
                performBotConnectionReviewAction: { _, _ in },
                openChatFolderUpdates: {},
                hideChatFolderUpdates: {},
                openStories: { _, _ in },
                openStarsTopup: { _ in },
                editPeer: { _ in },
                openWebApp: { _ in },
                openPhotoSetup: {},
                openAdInfo: { _, _ in },
                openAccountFreezeInfo: {},
                openUrl: { _ in }
            )
            self.interaction = interaction
            return interaction
        }

        private func isBot(peer: EnginePeer) -> Bool {
            if case let .user(user) = peer, user.botInfo != nil {
                return true
            }
            return false
        }

        private func botHasPreview(peerId: EnginePeer.Id, component: CommunityViewContentComponent) -> Bool {
            return component.previews[peerId]?.messages.isEmpty == false
        }

        private func rows(component: CommunityViewContentComponent, section: CommunityViewSection) -> [CommunityViewRow] {
            guard let cachedData = component.cachedData else {
                return []
            }

            var result: [CommunityViewRow] = []
            for linkedPeer in cachedData.linkedPeers {
                guard let peer = component.peers[linkedPeer.peerId] else {
                    continue
                }
                var isJoined = false
                if case let .channel(channel) = peer, case .member = channel.participationStatus {
                    isJoined = true
                }
                let isPrivate = peer.addressName == nil
                let isHidden = linkedPeer.visible == false
                let canView = linkedPeer.canViewHistory
                let isBot = self.isBot(peer: peer)
                let botHasPreview = isBot && self.botHasPreview(peerId: peer.id, component: component)
                
                if let selectionOptions = component.selectionOptions {
                    let selectionState = communitySelectionPeerState(peer: peer, isJoined: isJoined, options: selectionOptions)
                    if !selectionState.isVisible {
                        continue
                    }
                }
                switch section {
                case .joined:
                    if isJoined || botHasPreview {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                case .visible:
                    if !isJoined && !isBot && canView {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                case .requestable:
                    if !isJoined && !isBot && !canView && !isHidden {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                    if isBot && !botHasPreview {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                case .hidden:
                    if !isJoined && !isBot && isPrivate && isHidden {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                }
            }

            return result.enumerated().sorted { lhs, rhs in
                let lhsTimestamp = component.previews[lhs.element.peer.id]?.timestamp ?? 0
                let rhsTimestamp = component.previews[rhs.element.peer.id]?.timestamp ?? 0
                if lhsTimestamp != rhsTimestamp {
                    return lhsTimestamp > rhsTimestamp
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }

        private func memberCountString(component: CommunityViewContentComponent, peerId: EnginePeer.Id, presentationData: PresentationData) -> String? {
            guard let count = communityCachedMemberCounts(component.cachedPeerData)[peerId] else {
                return nil
            }
            if count > 0 {
                return presentationData.strings.Conversation_StatusMembers(count)
            }
            return nil
        }

        private func memberCount(peerId: EnginePeer.Id, cachedPeerData: [EnginePeer.Id: CachedPeerData]) -> Int32? {
            guard let cachedData = cachedPeerData[peerId] else {
                return nil
            }
            if let cachedData = cachedData as? CachedChannelData {
                return cachedData.participantsSummary.memberCount
            } else if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
                return Int32(participants.participants.count)
            } else {
                return nil
            }
        }

        private func pendingRequestRows(component: CommunityViewContentComponent) -> [CommunityViewRequestRow] {
            guard let pendingRequests = component.pendingRequests else {
                return []
            }
            var result: [CommunityViewRequestRow] = []
            for request in pendingRequests.requests {
                if let peer = pendingRequests.peers[request.peerId] {
                    var isPrivate = true
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        isPrivate = false
                    }
                    result.append(CommunityViewRequestRow(
                        request: request,
                        peer: peer,
                        requestedBy: pendingRequests.peers[request.requestedBy],
                        memberCount: self.memberCount(peerId: request.peerId, cachedPeerData: component.pendingRequestCachedPeerData),
                        isPrivate: isPrivate,
                        isVisible: request.isVisible
                    ))
                }
            }
            return result
        }

        private func openRequest(row: CommunityViewRequestRow) {
            if !row.isPrivate {
                self.component?.openPeer(row.peer)
                return
            }

            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = CommunityPrivateChatScreen(
                context: component.context,
                chatPeer: row.peer,
                requestedByPeer: row.requestedBy,
                memberCount: row.memberCount,
                messageOwner: { [weak self, requestedBy = row.requestedBy] in
                    if let requestedBy {
                        self?.component?.openPeer(requestedBy)
                    }
                }
            )
            environment.controller()?.present(controller, in: .window(.root))
        }

        private func sectionTitle(_ section: CommunityViewSection, presentationData: PresentationData) -> String {
            switch section {
            case .joined:
                return presentationData.strings.Community_View_SectionJoined
            case .visible:
                return presentationData.strings.Community_View_SectionVisible
            case .requestable:
                return presentationData.strings.Community_View_SectionRequestable
            case .hidden:
                return presentationData.strings.Community_View_SectionHidden
            }
        }

        private func updateSection(
            component: CommunityViewContentComponent,
            section: CommunityViewSection,
            rows: [CommunityViewRow],
            theme: PresentationTheme,
            presentationData: PresentationData,
            availableWidth: CGFloat,
            transition: ComponentTransition
        ) -> CGSize {
            let sectionView: ComponentView<Empty>
            if let current = self.sectionViews[section] {
                sectionView = current
            } else {
                sectionView = ComponentView<Empty>()
                self.sectionViews[section] = sectionView
            }

            var items: [AnyComponentWithIdentity<Empty>] = []
            let chatListPresentationData = ChatListPresentationData(
                theme: theme,
                fontSize: presentationData.listsFontSize,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameSortOrder: presentationData.nameSortOrder,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                disableAnimations: true
            )
            let interaction = self.makeInteraction(component: component)

            for index in rows.indices {
                let row = rows[index]
                if let selectionOptions = component.selectionOptions {
                    let isJoined = component.joinedPeerIds.contains(row.peer.id)
                    let selectionState = communitySelectionPeerState(peer: row.peer, isJoined: isJoined, options: selectionOptions)
                    guard selectionState.isVisible else {
                        continue
                    }
                    let subtitle = self.memberCountString(component: component, peerId: row.peer.id, presentationData: presentationData).flatMap {
                        PeerListItemComponent.Subtitle(text: $0, color: .neutral)
                    }
                    items.append(AnyComponentWithIdentity(id: row.peer.id, component: AnyComponent(PeerListItemComponent(
                        context: component.context,
                        theme: theme,
                        strings: presentationData.strings,
                        style: .list,
                        sideInset: 0.0,
                        title: row.peer.compactDisplayTitle,
                        peer: row.peer,
                        subtitle: subtitle,
                        subtitleAccessory: .none,
                        presence: nil,
                        rightAccessory: .none,
                        selectionState: .none,
                        isEnabled: selectionState.isEnabled,
                        hasNext: false,
                        extractedTheme: PeerListItemComponent.ExtractedTheme(
                            inset: 2.0,
                            background: component.mode.usesPlainStyle ? theme.chatList.itemBackgroundColor : theme.list.itemBlocksBackgroundColor
                        ),
                        insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0),
                        action: { peer, _, _ in
                            if selectionState.isEnabled {
                                component.openPeer(peer)
                            } else {
                                selectionOptions.selectDisabledPeer(peer, selectionState.disabledReason)
                            }
                        }
                    ))))
                    continue
                }
                switch section {
                case .joined, .visible:
                    let preview = component.previews[row.peer.id] ?? CommunityChatPreviewData(messages: [], readCounters: EnginePeerReadCounters())
                    var enabledContextActions: ChatListItem.EnabledContextActions.Actions = []
                    if component.joinedPeerIds.contains(row.peer.id) {
                        enabledContextActions.formUnion(.toggleMuted)
                    }
                    if communityChatCanRemovePeer(community: component.community, peer: row.peer) {
                        enabledContextActions.formUnion(.remove)
                    }
                    let communityChatAvatarDiameter = min(60.0, floor(presentationData.listsFontSize.baseDisplaySize * 60.0 / 17.0))
                    let communityChatSeparatorInset = 10.0 + 8.0 + communityChatAvatarDiameter + 2.0
                    let hasActiveRevealControls = self.revealedPeerId == row.peer.id
                    let nextHasActiveRevealControls = index + 1 < rows.count && self.revealedPeerId == rows[index + 1].peer.id
                    let communityChatSeparatorAlpha: CGFloat = (hasActiveRevealControls || nextHasActiveRevealControls) ? 0.0 : 1.0
                    items.append(AnyComponentWithIdentity(id: row.peer.id, component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: CommunityChatListItemGenerator(
                            context: component.context,
                            presentationData: chatListPresentationData,
                            peer: row.peer,
                            preview: preview,
                            interaction: interaction,
                            enabledContextActions: enabledContextActions.isEmpty ? nil : .custom(enabledContextActions),
                            hasActiveRevealControls: hasActiveRevealControls,
                            isHidden: row.linkedPeer.visible == false,
                            hasNext: false //index != rows.count - 1
                        ),
                        params: ListViewItemLayoutParams(
                            width: availableWidth,
                            leftInset: 0.0,
                            rightInset: 0.0,
                            availableHeight: 10000.0,
                            isStandalone: true
                        ),
                        separatorInset: communityChatSeparatorInset,
                        separatorAlpha: communityChatSeparatorAlpha,
                        action: { [weak self] in
                            guard let self, self.revealedPeerId == nil else {
                                return
                            }
                            self.component?.openPeer(row.peer)
                        },
                        actionMode: .gesture
                    ))))
                case .requestable, .hidden:
                    let subtitle = self.memberCountString(component: component, peerId: row.peer.id, presentationData: presentationData).flatMap {
                        PeerListItemComponent.Subtitle(text: $0, color: .neutral)
                    }
                    items.append(AnyComponentWithIdentity(id: row.peer.id, component: AnyComponent(PeerListItemComponent(
                        context: component.context,
                        theme: theme,
                        strings: presentationData.strings,
                        style: .list,
                        sideInset: 0.0,
                        title: row.peer.compactDisplayTitle,
                        titleAccessory: row.linkedPeer.visible == false ? .hidden : .none,
                        peer: row.peer,
                        subtitle: subtitle,
                        subtitleAccessory: .none,
                        presence: nil,
                        rightAccessory: .disclosure,
                        selectionState: .none,
                        isEnabled: true,
                        hasNext: false,
                        extractedTheme: PeerListItemComponent.ExtractedTheme(
                            inset: 2.0,
                            background: component.mode.usesPlainStyle ? theme.chatList.itemBackgroundColor : theme.list.itemBlocksBackgroundColor
                        ),
                        insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0),
                        action: { [weak self] peer, _, _ in
                            switch section {
                            case .requestable:
                                component.openPeer(peer)
                            case .hidden:
                                self?.presentHiddenChatToast()
                            default:
                                break
                            }
                        }
                    ))))
                }
            }

            return sectionView.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: component.mode.usesPlainStyle ? .plain : .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.sectionTitle(section, presentationData: presentationData),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 10000.0)
            )
        }

        private func updatePendingRequestsSection(
            component: CommunityViewContentComponent,
            theme: PresentationTheme,
            presentationData: PresentationData,
            availableWidth: CGFloat,
            transition: ComponentTransition
        ) -> CGSize? {
            let totalCount: Int32
            if let pendingRequests = component.pendingRequests {
                totalCount = pendingRequests.totalCount
            } else {
                totalCount = component.cachedData?.pendingRequests ?? 0
            }
            guard totalCount > 0 else {
                return nil
            }
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            let rows = self.pendingRequestRows(component: component)
            if totalCount == 1 {
                guard let row = rows.first else {
                    return nil
                }
                let isInFlight = component.pendingRequestInFlightPeerId == row.request.peerId
                items.append(AnyComponentWithIdentity(id: row.request.peerId, component: AnyComponent(CommunityRequestItemComponent(
                    context: component.context,
                    theme: theme,
                    strings: presentationData.strings,
                    chatPeer: row.peer,
                    requestedByPeer: row.requestedBy,
                    memberCount: row.memberCount,
                    isPrivate: row.isPrivate,
                    isVisible: row.isVisible,
                    isEnabled: component.pendingRequestInFlightPeerId == nil,
                    declineDisplaysProgress: isInFlight && component.pendingRequestInFlightApprove == false,
                    addDisplaysProgress: isInFlight && component.pendingRequestInFlightApprove == true,
                    hasNext: false,
                    open: { [weak self] _ in
                        self?.openRequest(row: row)
                    },
                    add: { _ in
                        component.setRequestApproval(row.request, row.peer, true)
                    },
                    decline: { _ in
                        component.setRequestApproval(row.request, row.peer, false)
                    }
                ))))
            } else {
                items.append(AnyComponentWithIdentity(id: "pendingRequests", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: presentationData.strings.Community_View_PendingRequests,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .custom(AnyComponentWithIdentity(
                        id: "pendingRequestsIcon",
                        component: AnyComponent(Image(image: self.pendingRequestsIcon, size: CGSize(width: 30.0, height: 30.0)))
                    ), false),
                    accessory: .custom(ListActionItemComponent.CustomAccessory(
                        component: AnyComponentWithIdentity(id: "pendingRequests-accessory-\(totalCount)", component: AnyComponent(CommunityViewPendingAccessoryComponent(
                            count: totalCount,
                            theme: theme
                        ))),
                        insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0),
                        isInteractive: false
                    )),
                    action: { _ in
                        component.openPendingRequests()
                    }
                ))))
            }

            let header: AnyComponent<Empty>?
            if totalCount == 1 {
                header = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationData.strings.Community_View_PendingRequestHeader,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 1
                ))
            } else {
                header = nil
            }

            return self.pendingRequestsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: component.mode.usesPlainStyle ? .plain : .glass,
                    header: header,
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 10000.0)
            )
        }

        func update(component: CommunityViewContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            let theme: PresentationTheme
            let sideInset: CGFloat
            switch component.mode {
            case .sheet:
                theme = environment.theme.withModalBlocksBackground()
                sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            case .fullscreen, .preview:
                theme = environment.theme
                sideInset = max(environment.safeInsets.left, environment.safeInsets.right)
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sectionSpacing: CGFloat = component.mode.usesGroupedStyle ? 28.0 : 12.0
            let contentWidth = availableSize.width - sideInset * 2.0

            self.backgroundColor = .clear

            let isAdmin = component.community?.hasPermission(.manageLinkedPeers) == true
            var contentHeight: CGFloat = component.topInset + 16.0

            if component.mode.usesGroupedStyle {
                var transition = transition
                if self.collapseSection.view == nil {
                    transition = .immediate
                }
                let collapseSectionSize = self.collapseSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "collapse", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: presentationData.strings.Community_View_ShowAsOneChat,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )),
                                accessory: .toggle(ListActionItemComponent.Toggle(
                                    style: .regular,
                                    isOn: component.community?.collapsedInDialogs == true,
                                    isInteractive: true,
                                    isEnabled: true,
                                    action: { [weak self] value in
                                        self?.component?.toggleCollapsed(value)
                                    }
                                )),
                                action: nil
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 10000.0)
                )
                if let collapseSectionView = self.collapseSection.view {
                    if collapseSectionView.superview == nil {
                        self.addSubview(collapseSectionView)
                    }
                    transition.setFrame(view: collapseSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: collapseSectionSize))
                }
                contentHeight += collapseSectionSize.height + 10.0

                let footerSize = self.collapseFooter.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: presentationData.strings.Community_View_ShowAsOneChatInfo,
                            font: Font.regular(13.0),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 32.0, height: 10000.0)
                )
                if let footerView = self.collapseFooter.view {
                    if footerView.superview == nil {
                        self.addSubview(footerView)
                    }
                    transition.setFrame(view: footerView, frame: CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: footerSize))
                }
                contentHeight += footerSize.height + sectionSpacing
            } else {
                self.collapseSection.view?.removeFromSuperview()
                self.collapseFooter.view?.removeFromSuperview()
            }

            if isAdmin && component.selectionOptions == nil, let pendingRequestsSectionSize = self.updatePendingRequestsSection(
                component: component,
                theme: theme,
                presentationData: presentationData,
                availableWidth: contentWidth,
                transition: transition
            ) {
                if let pendingRequestsSectionView = self.pendingRequestsSection.view {
                    if pendingRequestsSectionView.superview == nil {
                        self.addSubview(pendingRequestsSectionView)
                    }
                    transition.setAlpha(view: pendingRequestsSectionView, alpha: 1.0)
                    transition.setFrame(view: pendingRequestsSectionView, frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: pendingRequestsSectionSize
                    ))
                }
                contentHeight += pendingRequestsSectionSize.height + sectionSpacing
            } else if let pendingRequestsSectionView = self.pendingRequestsSection.view {
                transition.setAlpha(view: pendingRequestsSectionView, alpha: 0.0, completion: { [weak pendingRequestsSectionView] _ in
                    pendingRequestsSectionView?.removeFromSuperview()
                })
            }


            let sections: [CommunityViewSection] = component.selectionOptions != nil ? [.joined] : [.joined, .visible, .requestable, .hidden]
            for section in sections {
                let rows = self.rows(component: component, section: section)
                guard !rows.isEmpty else {
                    if let sectionView = self.sectionViews[section]?.view {
                        transition.setAlpha(view: sectionView, alpha: 0.0, completion: { [weak sectionView] _ in
                            sectionView?.removeFromSuperview()
                        })
                    }
                    continue
                }
                
                var transition = transition
                if self.sectionViews[section] == nil {
                    transition = .immediate
                }

                let size = self.updateSection(
                    component: component,
                    section: section,
                    rows: rows,
                    theme: theme,
                    presentationData: presentationData,
                    availableWidth: contentWidth,
                    transition: transition
                )
                if let sectionView = self.sectionViews[section]?.view {
                    if sectionView.superview == nil {
                        self.addSubview(sectionView)
                    }
                    transition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: size))
                }
                contentHeight += size.height + sectionSpacing
            }

            contentHeight += 16.0
            contentHeight += 60.0

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CommunityViewScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id
    let mode: CommunityViewScreenMode
    let selectionOptions: CommunityPeerSelectionOptions?

    init(context: AccountContext, communityId: EnginePeer.Id, mode: CommunityViewScreenMode, selectionOptions: CommunityPeerSelectionOptions?) {
        self.context = context
        self.communityId = communityId
        self.mode = mode
        self.selectionOptions = selectionOptions
    }

    static func ==(lhs: CommunityViewScreenComponent, rhs: CommunityViewScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.selectionOptions !== rhs.selectionOptions {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        private let animateOut = ActionSlot<Action<()>>()
        private let scrollView = ScrollView()
        private let fullscreenContent = ComponentView<EnvironmentType>()
        private let fullscreenBottomItem = ComponentView<Empty>()
        private let bottomEdgeEffectView = EdgeEffectView()
        private let navigationBarView = ComponentView<Empty>()
        private let searchOverlayNode = ASDisplayNode()
        private let sheetBoundsUpdated = ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>()
        private let sheetNavigationTopInset: CGFloat = 16.0
        private let sheetSearchOverlayTopOffset: CGFloat = 20.0

        private var component: CommunityViewScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var isSearchDisplayControllerActive: ChatListNavigationBar.ActiveSearch?
        private var searchDisplayController: SearchDisplayController?
        private var disappearingSearchDisplayController: SearchDisplayController?
        private var currentSheetBounds: CGRect?
        private var currentAvailableSize: CGSize = .zero
        private var lastInactiveNavigationHeight: CGFloat?
        private var sheetNavigationFrame: CGRect = .zero
        private var sheetTopInset: CGFloat = 0.0
        private var sheetContainerInset: CGFloat = 0.0
        private var didApplyInitialOffset = false

        private var community: TelegramCommunity?
        private var cachedData: CachedCommunityData?
        private var peers: [EnginePeer.Id: EnginePeer] = [:]
        private var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var previews: [EnginePeer.Id: CommunityChatPreviewData] = [:]
        private var pendingRequests: CommunityPeerLinkRequests?
        private var pendingRequestsContext: CommunityPeerLinkRequestsContext?
        private var pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var pendingRequestActions: [EnginePeer.Id: PendingCommunityViewRequestAction] = [:]
        private weak var currentRequestUndoOverlayController: UndoOverlayController?
        private var joinedPeerIds = Set<EnginePeer.Id>()

        private var isAddActionInProgress = false
        private var removingPeerId: EnginePeer.Id?
        private var didRequestInitialData = false
        private var didRequestJoinedChats = false

        private var dataDisposable: Disposable?
        private let linkedPeersDisposable = MetaDisposable()
        private let linkedPeerDataDisposable = MetaDisposable()
        private let previewsDisposable = MetaDisposable()
        private let joinedChatsDisposable = MetaDisposable()
        private let actionDisposable = MetaDisposable()
        private let addChatDisposable = MetaDisposable()
        private let removePeerDisposable = MetaDisposable()
        private let openSearchResultDisposable = MetaDisposable()
        private let pendingRequestsDisposable = MetaDisposable()
        private let pendingRequestCachedDataDisposable = MetaDisposable()
        private var currentLinkedPeerIds: [EnginePeer.Id] = []
        private var currentPendingRequestsCount: Int32?
        private var currentPendingRequestCachedPeerIds: [EnginePeer.Id] = []
        private var requestedPendingRequestCachedPeerIds = Set<EnginePeer.Id>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.scrollView.delegate = self

            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true

            self.sheetBoundsUpdated.connect { [weak self] update in
                guard let self else {
                    return
                }
                self.currentSheetBounds = update.bounds
                self.updateSheetNavigationBarFrame(bounds: update.bounds, transition: .immediate)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.commitPendingRequestActions()
            self.currentRequestUndoOverlayController?.dismiss()
            self.dataDisposable?.dispose()
            self.linkedPeersDisposable.dispose()
            self.linkedPeerDataDisposable.dispose()
            self.previewsDisposable.dispose()
            self.joinedChatsDisposable.dispose()
            self.actionDisposable.dispose()
            self.addChatDisposable.dispose()
            self.removePeerDisposable.dispose()
            self.openSearchResultDisposable.dispose()
            self.pendingRequestsDisposable.dispose()
            self.pendingRequestCachedDataDisposable.dispose()
        }

        private var isAdmin: Bool {
            if let community = self.community {
                if community.flags.contains(.isCreator) {
                    return true
                }
                if let adminRights = self.community?.adminRights, !adminRights.rights.isEmpty {
                    return true
                }
                return false
            } else {
                return false
            }
        }

        private var canAddChatsToCommunity: Bool {
            guard let community = self.community else {
                return false
            }
            if community.hasPermission(.manageLinkedPeers) {
                return true
            }
            return community.defaultBannedRights?.flags.contains(.banManageLinkedPeers) != true
        }

        private var isSheetSearchFullscreen: Bool {
            guard self.component?.mode.usesSheetPresentation == true else {
                return false
            }
            return self.searchDisplayController != nil
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if scrollView === self.scrollView {
                self.updateNavigationScrolling(transition: .immediate)
            }
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard scrollView === self.scrollView, let targetOffset = self.snappedNavigationSearchOffset(targetContentOffset.pointee.y) else {
                return
            }
            targetContentOffset.pointee.y = targetOffset
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard scrollView === self.scrollView, !decelerate else {
                return
            }
            self.snapNavigationSearchOffsetIfNeeded()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            self.snapNavigationSearchOffsetIfNeeded()
        }

        private func snappedNavigationSearchOffset(_ offset: CGFloat) -> CGFloat? {
            guard let component = self.component, component.mode.usesPlainStyle, component.mode.usesFullscreenPresentation, !component.mode.isPreview, component.selectionOptions == nil, self.isSearchDisplayControllerActive == nil else {
                return nil
            }

            let searchScrollHeight = ChatListNavigationBar.searchScrollHeight
            guard offset > 0.0 && offset < searchScrollHeight else {
                return nil
            }

            if offset < searchScrollHeight * 0.5 {
                return 0.0
            } else {
                return searchScrollHeight
            }
        }

        private func snapNavigationSearchOffsetIfNeeded() {
            guard let targetOffset = self.snappedNavigationSearchOffset(self.scrollView.contentOffset.y) else {
                return
            }
            self.scrollView.setContentOffset(CGPoint(x: self.scrollView.contentOffset.x, y: targetOffset), animated: true)
        }

        private func updateNavigationScrolling(transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            if component.mode.isPreview {
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    navigationBarComponentView.applyScroll(offset: 0.0, allowAvatarsExpansion: false, forceUpdate: false, transition: transition)
                }
                return
            }

            let rawOffset: CGFloat
            switch component.mode {
            case .sheet:
                rawOffset = self.currentSheetBounds?.minY ?? 0.0
            case .fullscreen, .preview:
                rawOffset = self.scrollView.contentOffset.y
            }

            var offset = min(max(0.0, rawOffset), ChatListNavigationBar.searchScrollHeight)
            if abs(offset) < 0.1 {
                offset = 0.0
            }
            if component.selectionOptions != nil || self.isSearchDisplayControllerActive != nil {
                offset = 0.0
            }

            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: false, forceUpdate: false, transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                )))
            }
        }

        private func updateLinkedPeerSignals(component: CommunityViewScreenComponent, ids: [EnginePeer.Id]) {
            if self.currentLinkedPeerIds == ids {
                return
            }
            self.currentLinkedPeerIds = ids

            if ids.isEmpty {
                self.peers = [:]
                self.cachedPeerData = [:]
                self.previews = [:]
                self.linkedPeersDisposable.set(nil)
                self.linkedPeerDataDisposable.set(nil)
                self.previewsDisposable.set(nil)
                self.state?.updated(transition: .immediate)
                return
            }

            self.linkedPeersDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peersById in
                guard let self else {
                    return
                }
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for id in ids {
                    if let maybePeer = peersById[id], let peer = maybePeer {
                        peers[id] = peer
                    }
                }
                var transition: ComponentTransition = .spring(duration: 0.35)
                if self.peers.isEmpty {
                    transition = .immediate
                }
                self.peers = peers
                self.state?.updated(transition: transition)
            }))

            self.linkedPeerDataDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
                for id in ids {
                    if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                        cachedPeerData[id] = cachedData
                    }
                }
                self.cachedPeerData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            }))

            self.previewsDisposable.set((communityChatPreviewsSignal(context: component.context, peerIds: ids)
            |> deliverOnMainQueue).startStrict(next: { [weak self] previews in
                guard let self else {
                    return
                }
                var transition: ComponentTransition = .spring(duration: 0.35)
                if self.previews.isEmpty {
                    transition = .immediate
                }
                self.previews = previews
                self.state?.updated(transition: transition)
            }))
        }

        private func updatePendingRequestCachedData(component: CommunityViewScreenComponent, transition: ComponentTransition) {
            let ids = self.pendingRequests?.requests.map(\.peerId) ?? []
            if self.currentPendingRequestCachedPeerIds == ids {
                return
            }
            self.currentPendingRequestCachedPeerIds = ids

            if ids.isEmpty {
                self.pendingRequestCachedPeerData = [:]
                self.pendingRequestCachedDataDisposable.set(nil)
                self.state?.updated(transition: transition)
                return
            }

            for peerId in ids {
                if !self.requestedPendingRequestCachedPeerIds.contains(peerId) {
                    self.requestedPendingRequestCachedPeerIds.insert(peerId)
                    component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
                }
            }

            self.pendingRequestCachedDataDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
                for id in ids {
                    if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                        cachedPeerData[id] = cachedData
                    }
                }
                self.pendingRequestCachedPeerData = cachedPeerData
                self.state?.updated(transition: transition)
            }))
        }

        private func updatePendingRequestsSignal(component: CommunityViewScreenComponent, force: Bool = false) {
            let pendingCount: Int32
            if self.isAdmin {
                pendingCount = self.cachedData?.pendingRequests ?? 0
            } else {
                pendingCount = 0
            }

            if !force && self.pendingRequestsContext != nil {
                self.currentPendingRequestsCount = pendingCount
                return
            }
            self.currentPendingRequestsCount = pendingCount

            let pendingRequestsLimit: Int32 = 100
            let requestsContext: CommunityPeerLinkRequestsContext
            if let current = self.pendingRequestsContext {
                requestsContext = current
                if force {
                    requestsContext.reload(limit: pendingRequestsLimit)
                }
            } else {
                requestsContext = component.context.engine.peers.communityPeerLinkRequestsContext(communityId: component.communityId, initialLimit: pendingRequestsLimit)
                self.pendingRequestsContext = requestsContext
            }

            self.pendingRequestsDisposable.set((requestsContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                var transition: ComponentTransition = .spring(duration: 0.35)
                if self.pendingRequests == nil {
                    transition = .immediate
                }
                if result.hasLoadedOnce {
                    self.pendingRequests = CommunityPeerLinkRequests(
                        totalCount: result.count,
                        requests: result.requests,
                        nextOffset: nil,
                        peers: result.peers
                    )
                }
                self.prunePendingRequestActions()
                self.updatePendingRequestCachedData(component: component, transition: transition)
                self.state?.updated(transition: transition)
            }))
        }

        private func updateJoinedChatsSignal(component: CommunityViewScreenComponent, force: Bool = false) {
            if !force && self.didRequestJoinedChats {
                return
            }
            self.didRequestJoinedChats = true

            self.joinedChatsDisposable.set((component.context.engine.peers.communityParticipantJoinedChats(
                communityId: component.communityId,
                participantId: component.context.account.peerId
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.joinedPeerIds = Set(result.creatorChatIds + result.joinedChatIds)
                self.state?.updated(transition: .immediate)
            }))
        }

        private func ensureDataSignal(component: CommunityViewScreenComponent) {
            if self.dataDisposable == nil {
                self.dataDisposable = (component.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.communityId),
                    TelegramEngine.EngineData.Item.Peer.CachedData(id: component.communityId)
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                    guard let self else {
                        return
                    }

                    var transition: ComponentTransition = .spring(duration: 0.35)
                    if self.community == nil {
                        transition = .immediate
                    }
                    if let peer, case let .community(community) = peer {
                        self.community = community
                    } else {
                        self.community = nil
                    }
                    self.cachedData = cachedData as? CachedCommunityData

                    let ids = self.cachedData?.linkedPeers.map(\.peerId) ?? []
                    self.updateLinkedPeerSignals(component: component, ids: ids)
                    if component.selectionOptions == nil {
                        self.updatePendingRequestsSignal(component: component)
                    }
                    self.state?.updated(transition: transition)
                })
            }

            if !self.didRequestInitialData {
                self.didRequestInitialData = true
                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
            }
            self.updateJoinedChatsSignal(component: component)
        }

        private func dismiss(animated: Bool) {
            guard let controller = self.environment?.controller else {
                return
            }
            if self.component?.mode.usesFullscreenPresentation == true {
                if let navigationController = controller()?.navigationController as? NavigationController {
                    let _ = navigationController.popViewController(animated: animated)
                } else {
                    controller()?.dismiss(completion: nil)
                }
                return
            }
            if animated {
                self.animateOut.invoke(Action { _ in
                    controller()?.dismiss(completion: nil)
                })
            } else {
                controller()?.dismiss(completion: nil)
            }
        }

        private func openEdit() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
            controller.navigationPresentation = .modal
            environment.controller()?.push(controller)
        }

        private func openPendingRequests() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityRequestsScreen(context: component.context, communityId: component.communityId, existingContext: self.pendingRequestsContext)
            controller.navigationPresentation = .modal
            environment.controller()?.push(controller)
        }

        private func openPeer(_ peer: EnginePeer) {
            guard let component = self.component else {
                return
            }
            if let selectionOptions = component.selectionOptions {
                self.dismiss(animated: false)
                selectionOptions.selectPeer(peer)
                return
            }
            guard let environment = self.environment, let navigationController = environment.controller()?.navigationController as? NavigationController else {
                return
            }
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: component.context,
                chatLocation: .peer(peer),
                keepStack: .always,
                forceOpenChat: true
            ))
        }

        private func openPeerFromSearch(peer: EnginePeer, threadId: Int64?, dismissSearch: Bool) {
            guard let component = self.component else {
                return
            }
            let navigationController = self.environment?.controller()?.navigationController as? NavigationController
            self.openSearchResultDisposable.set((component.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actualPeer in
                guard let self, let component = self.component else {
                    return
                }
                if dismissSearch {
                    self.deactivateSearch(animated: true)
                }

                if let selectionOptions = component.selectionOptions {
                    let selectionState = communitySelectionPeerState(peer: actualPeer, isJoined: self.joinedPeerIds.contains(actualPeer.id), options: selectionOptions)
                    if selectionState.isVisible {
                        if selectionState.isEnabled {
                            self.dismiss(animated: false)
                            selectionOptions.selectPeer(actualPeer)
                        } else {
                            selectionOptions.selectDisabledPeer(actualPeer, selectionState.disabledReason)
                        }
                    }
                    return
                }

                guard let navigationController else {
                    return
                }
                if case let .channel(channel) = actualPeer, channel.isForumOrMonoForum, let threadId {
                    self.deactivateSearch(animated: false)
                    let _ = component.context.sharedContext.navigateToForumThread(context: component.context, peerId: actualPeer.id, threadId: threadId, messageId: nil, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .never, animated: true).startStandalone()
                } else {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: component.context,
                        chatLocation: .peer(actualPeer),
                        keepStack: .always,
                        purposefulAction: { [weak self] in
                            self?.deactivateSearch(animated: false)
                        },
                        forceOpenChat: true
                    ))
                }
            }))
        }

        private func openMessageFromSearch(peer: EnginePeer, threadId: Int64?, messageId: EngineMessage.Id, deactivateOnAction: Bool) {
            if self.component?.selectionOptions != nil {
                self.openPeerFromSearch(peer: peer, threadId: threadId, dismissSearch: deactivateOnAction)
                return
            }
            guard let component = self.component, let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                return
            }
            self.openSearchResultDisposable.set((component.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actualPeer in
                guard let self, let component = self.component else {
                    return
                }

                if case let .channel(channel) = actualPeer, channel.isForumOrMonoForum, let threadId {
                    self.deactivateSearch(animated: false)
                    let _ = component.context.sharedContext.navigateToForumThread(context: component.context, peerId: actualPeer.id, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .never, animated: true).startStandalone()
                } else {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: component.context,
                        chatLocation: .peer(actualPeer),
                        subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
                        keepStack: .always,
                        purposefulAction: { [weak self] in
                            if deactivateOnAction {
                                self?.deactivateSearch(animated: false)
                            }
                        },
                        forceOpenChat: true
                    ))
                }
            }))
        }

        private func activateSearch(searchContentNode: NavigationBarSearchContentNode?) {
            guard let component = self.component, !component.mode.isPreview, let environment = self.environment, let (layout, navigationHeight) = self.validLayout, self.searchDisplayController == nil else {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let selectionOptions = component.selectionOptions
            let contentNode = ChatListSearchContainerNode(
                context: component.context,
                animationCache: component.context.animationCache,
                animationRenderer: component.context.animationRenderer,
                filter: selectionOptions?.filter ?? [],
                requestPeerType: selectionOptions?.requestPeerType,
                excludedPeerIds: selectionOptions?.excludedPeerIds ?? Set(),
                location: .chatList(groupId: .root),
                communityId: component.communityId,
                folder: nil,
                displaySearchFilters: false,
                hasDownloads: false,
                initialFilter: .chats,
                openPeer: { [weak self] peer, _, threadId, dismissSearch in
                    self?.openPeerFromSearch(peer: peer, threadId: threadId, dismissSearch: dismissSearch)
                },
                openDisabledPeer: { peer, _, reason in
                    selectionOptions?.selectDisabledPeer(peer, reason)
                },
                openRecentPeerOptions: { _ in
                },
                openMessage: { [weak self] peer, threadId, messageId, deactivateOnAction in
                    self?.openMessageFromSearch(peer: peer, threadId: threadId, messageId: messageId, deactivateOnAction: deactivateOnAction)
                },
                addContact: nil,
                peerContextAction: nil,
                present: { [weak self] controller, arguments in
                    self?.environment?.controller()?.present(controller, in: .window(.root), with: arguments)
                },
                presentInGlobalOverlay: { [weak self] controller, arguments in
                    self?.environment?.controller()?.presentInGlobalOverlay(controller, with: arguments)
                },
                navigationController: environment.controller()?.navigationController as? NavigationController,
                parentController: { [weak self] in
                    return self?.environment?.controller()
                }
            )
            contentNode.dismissSearch = { [weak self] in
                self?.deactivateSearch(animated: true)
            }
            contentNode.dismissSearchImmediately = { [weak self] in
                self?.deactivateSearch(animated: false)
            }

            let searchDisplayController = SearchDisplayController(
                presentationData: presentationData,
                mode: .list,
                contentNode: contentNode,
                cancel: { [weak self] in
                    self?.deactivateSearch(animated: true)
                },
                fieldStyle: .glass,
                searchBarIsExternal: false
            )
            self.searchDisplayController = searchDisplayController
            self.isSearchDisplayControllerActive = ChatListNavigationBar.ActiveSearch(isExternal: false)
            self.searchOverlayNode.view.isUserInteractionEnabled = true
            self.state?.updated(transition: .spring(duration: 0.4))

            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
            searchDisplayController.activate(insertSubnode: { [weak self] subnode, isSearchBar in
                guard let self else {
                    return
                }
                if isSearchBar {
                    if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                        if let searchContentNode = navigationBarComponentView.searchContentNode {
                            searchContentNode.addSubnode(subnode)
                        } else {
                            self.searchOverlayNode.addSubnode(subnode)
                        }
                    } else {
                        self.searchOverlayNode.addSubnode(subnode)
                    }
                } else {
                    self.searchOverlayNode.addSubnode(subnode)
                }
            }, placeholder: searchContentNode?.placeholderNode)
        }

        private func deactivateSearch(animated: Bool) {
            self.isSearchDisplayControllerActive = nil
            if let searchDisplayController = self.searchDisplayController {
                self.searchDisplayController = nil
                self.disappearingSearchDisplayController = searchDisplayController
                let placeholderNode = (self.navigationBarView.view as? ChatListNavigationBar.View)?.searchContentNode?.placeholderNode
                searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated, completion: { [weak self, weak searchDisplayController] in
                    guard let self, let searchDisplayController else {
                        return
                    }
                    if self.disappearingSearchDisplayController === searchDisplayController {
                        self.disappearingSearchDisplayController = nil
                        self.searchOverlayNode.view.isUserInteractionEnabled = false
                        if self.component?.mode.usesSheetPresentation == true {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
            }
            self.state?.updated(transition: .spring(duration: 0.4))
        }

        private func removePeer(_ peerId: EnginePeer.Id) {
            guard let component = self.component, self.isAdmin, self.removingPeerId == nil else {
                return
            }
            self.removingPeerId = peerId
            self.state?.updated(transition: .immediate)

            self.removePeerDisposable.set((component.context.engine.peers.toggleCommunityPeerLink(
                communityId: component.communityId,
                peerId: peerId,
                action: .unlink
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.removingPeerId = nil
                self.state?.updated(transition: .spring(duration: 0.35))
            }, completed: { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                self.removingPeerId = nil
                if let cachedData = self.cachedData {
                    self.cachedData = cachedData.withUpdatedLinkedPeers(cachedData.linkedPeers.filter { $0.peerId != peerId })
                }
                self.peers.removeValue(forKey: peerId)
                self.cachedPeerData.removeValue(forKey: peerId)
                self.previews.removeValue(forKey: peerId)
                self.joinedPeerIds.remove(peerId)
                self.currentLinkedPeerIds.removeAll(where: { $0 == peerId })

                let _ = component.context.account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([component.communityId]), update: { _, current in
                        guard let current = current as? CachedCommunityData else {
                            return current
                        }
                        return current.withUpdatedLinkedPeers(current.linkedPeers.filter { $0.peerId != peerId })
                    })
                }.startStandalone()

                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func prunePendingRequestActions() {
            guard let pendingRequests = self.pendingRequests else {
                if (self.cachedData?.pendingRequests ?? 0) <= 0 {
                    self.pendingRequestActions.removeAll()
                }
                return
            }
            let requestIds = Set(pendingRequests.requests.map(\.peerId))
            for peerId in Array(self.pendingRequestActions.keys) {
                if !requestIds.contains(peerId) {
                    self.pendingRequestActions.removeValue(forKey: peerId)
                }
            }
        }

        private func commitPendingRequestAction(peerId: EnginePeer.Id) {
            guard var pendingAction = self.pendingRequestActions[peerId], !pendingAction.isCommitted else {
                return
            }
            guard let pendingRequestsContext = self.pendingRequestsContext else {
                return
            }
            pendingAction.isCommitted = true
            self.pendingRequestActions[peerId] = pendingAction
            pendingRequestsContext.update(pendingAction.request, action: pendingAction.approve ? .approve : .deny)
            self.state?.updated(transition: .spring(duration: 0.35))
        }

        private func commitPendingRequestActions() {
            let peerIds = Array(self.pendingRequestActions.keys)
            for peerId in peerIds {
                self.commitPendingRequestAction(peerId: peerId)
            }
        }

        @discardableResult
        private func commitCurrentRequestUndoOverlay(animateAsReplacement: Bool) -> Bool {
            guard let currentRequestUndoOverlayController = self.currentRequestUndoOverlayController else {
                return false
            }
            if animateAsReplacement {
                currentRequestUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
            } else {
                currentRequestUndoOverlayController.dismissWithCommitAction()
            }
            self.currentRequestUndoOverlayController = nil
            return true
        }

        private func setPendingRequestApproval(request: CommunityPeerRequest, peer: EnginePeer, approve: Bool) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller(), self.pendingRequestsContext != nil else {
                return
            }

            let peerId = request.peerId
            if self.pendingRequestActions[peerId] != nil {
                return
            }

            let animateInAsReplacement = self.commitCurrentRequestUndoOverlay(animateAsReplacement: true)

            self.pendingRequestActions[peerId] = PendingCommunityViewRequestAction(
                request: request,
                approve: approve,
                isCommitted: false
            )
            self.state?.updated(transition: .spring(duration: 0.35))

            let title: String = peer.compactDisplayTitle
            let text: String
            if approve {
                text = environment.strings.Community_View_PendingRequestApprovedToast
            } else {
                text = environment.strings.Community_View_PendingRequestDeclinedToast
            }

            let undoController = UndoOverlayController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                content: .invitedToVoiceChat(
                    context: component.context,
                    peer: peer,
                    title: title,
                    text: text,
                    action: environment.strings.Undo_Undo,
                    duration: 3.0
                ),
                animateInAsReplacement: animateInAsReplacement,
                action: { [weak self] action in
                    guard let self else {
                        return false
                    }
                    switch action {
                    case .commit:
                        self.commitPendingRequestAction(peerId: peerId)
                        return true
                    case .undo:
                        if let pendingAction = self.pendingRequestActions[peerId], !pendingAction.isCommitted {
                            self.pendingRequestActions.removeValue(forKey: peerId)
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                        return true
                    case .info:
                        return false
                    }
                }
            )
            self.currentRequestUndoOverlayController = undoController
            controller.present(undoController, in: .current)
        }

        private func toggleCollapsed(_ collapsed: Bool) {
            guard let component = self.component else {
                return
            }
            self.state?.updated(transition: .spring(duration: 0.35))

            self.actionDisposable.set((component.context.engine.peers.toggleCommunityCollapsedInDialogs(
                communityId: component.communityId,
                collapsed: collapsed
            )
            |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                guard let self else {
                    return
                }
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func openAddChat() {
            guard let component = self.component, let environment = self.environment, !self.isAddActionInProgress else {
                return
            }

            let communitiesConfiguration = CommunitiesConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let linkedPeersCount = Int32(self.cachedData?.linkedPeers.count ?? 0)
            if linkedPeersCount >= communitiesConfiguration.peersLimit {
                let alertText = environment.strings.Community_View_ChatsLimitReached
                let alertScreen = textAlertController(context: component.context, title: nil, text: alertText, actions: [
                    TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {})
                ])
                environment.controller()?.present(alertScreen, in: .window(.root))
                return
            }

            self.isAddActionInProgress = true
            self.state?.updated(transition: .spring(duration: 0.35))

            let excludedPeerIds = Set((self.cachedData?.linkedPeers ?? []).map(\.peerId))
            self.addChatDisposable.set((component.context.engine.peers.adminedPublicChannels(scope: .forCommunity)
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] channels in
                guard let self else {
                    return
                }
                self.isAddActionInProgress = false
                self.addChatDisposable.set(nil)
                self.state?.updated(transition: .spring(duration: 0.35))

                guard let component = self.component, let environment = self.environment else {
                    return
                }

                let channels = channels.filter { channel in
                    !excludedPeerIds.contains(channel.peer.id)
                }
                let selectionController = PeerSelectionScreen(
                    context: component.context,
                    initialData: PeerSelectionScreen.communityInitialData(channels: channels),
                    updatedPresentationData: nil,
                    completion: { [weak self] channel in
                        guard let self, let component = self.component, let channel else {
                            return
                        }
                        let controller = component.context.sharedContext.makeCommunityAddScreen(
                            context: component.context,
                            communityId: component.communityId,
                            peerId: channel.peer.id,
                            requiresConfirmation: !self.isAdmin,
                            completed: { [weak self] immediate in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
                                self.updateJoinedChatsSignal(component: component, force: true)
                                self.state?.updated(transition: .spring(duration: 0.35))
                            }
                        )
                        self.environment?.controller()?.present(controller, in: .window(.root))
                    }
                )
                selectionController.navigationPresentation = .modal
                environment.controller()?.push(selectionController)
            }))
        }

        private func containerLayout(availableSize: CGSize, environment: EnvironmentType, mode: CommunityViewScreenMode, safeInsets: UIEdgeInsets? = nil) -> ContainerViewLayout {
            let effectiveSafeInsets = safeInsets ?? environment.safeInsets
            return ContainerViewLayout(
                size: availableSize,
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: effectiveSafeInsets.bottom, right: 0.0),
                safeInsets: effectiveSafeInsets,
                additionalInsets: environment.additionalInsets,
                statusBarHeight: mode.usesFullscreenPresentation ? environment.statusBarHeight : 0.0,
                inputHeight: environment.inputHeight > 0.0 ? environment.inputHeight : nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false,
                presentedInFormSheet: false
            )
        }

        private func sheetMetrics(availableSize: CGSize, environment: EnvironmentType) -> (fillingSize: CGFloat, rawSideInset: CGFloat) {
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, availableSize.height) - environment.safeInsets.left * 2.0
            }

            return (fillingSize, floor((availableSize.width - fillingSize) * 0.5))
        }

        private func updateNavigationBar(component: CommunityViewScreenComponent, availableSize: CGSize, statusBarHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, environment: EnvironmentType, transition: ComponentTransition) -> CGSize {
            let theme: PresentationTheme
            switch component.mode {
            case .sheet:
                theme = environment.theme.withModalBlocksBackground()
            case .fullscreen, .preview:
                theme = environment.theme
            }

            let title = self.community?.title ?? environment.strings.Community_View_Title
                        
            let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
            let backPressed: (() -> Void)?
            let navigationBackTitle: String?
            if component.mode.isPreview {
                leftButton = nil
                backPressed = nil
                navigationBackTitle = nil
            } else {
                switch component.mode {
                case .sheet:
                    leftButton = AnyComponentWithIdentity(id: "close", component: AnyComponent(NavigationButtonComponent(
                        content: .icon(imageName: "Navigation/Close"),
                        pressed: { [weak self] _ in
                            self?.dismiss(animated: true)
                        }
                    )))
                    backPressed = nil
                    navigationBackTitle = nil
                case .fullscreen:
                    leftButton = nil
                    backPressed = { [weak self] in
                        self?.dismiss(animated: true)
                    }
                    navigationBackTitle = environment.strings.Common_Back
                case .preview:
                    leftButton = nil
                    backPressed = nil
                    navigationBackTitle = nil
                }
            }

            var titleItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor)))
                ))
            ]
            if component.mode.usesFullscreenPresentation, let community = self.community {
                titleItems.insert(AnyComponentWithIdentity(id: "avatar", component: AnyComponent(
                    AvatarComponent(context: component.context, theme: theme, peer: EnginePeer(community), clipStyle: .roundedRect, size: CGSize(width: 20.0, height: 20.0))
                )), at: 0)
            }
            
            var rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            if component.mode.usesSheetPresentation && !component.mode.isPreview && component.selectionOptions == nil {
                rightButtons.append(AnyComponentWithIdentity(id: "search", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Navigation/Search"),
                    pressed: { [weak self] _ in
                        self?.activateSearch(searchContentNode: nil)
                    }
                ))))
            }
            if self.isAdmin && !component.mode.isPreview && component.selectionOptions == nil {
                rightButtons.append(AnyComponentWithIdentity(id: "settings", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Media Editor/Adjustments"),
                    pressed: { [weak self] _ in
                        self?.openEdit()
                    }
                ))))
            }

            let primaryContent = ChatListHeaderComponent.Content(
                title: title,
                navigationBackTitle: navigationBackTitle,
                titleComponent: AnyComponent(
                    HStack(titleItems, spacing: 7.0)
                ),
                chatListTitle: nil,
                leftButton: leftButton,
                rightButtons: rightButtons,
                backPressed: backPressed
            )

            var statusBarHeight = statusBarHeight
            if component.selectionOptions != nil {
                statusBarHeight += 6.0
            } else if component.mode.isPreview {
                statusBarHeight += 2.0
            }
            
            let navigationBarSize = self.navigationBarView.update(
                transition: transition,
                component: AnyComponent(ChatListNavigationBar(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    statusBarHeight: statusBarHeight,
                    leftInset: leftInset,
                    rightInset: rightInset,
                    search: component.mode.usesFullscreenPresentation && !component.mode.isPreview && component.selectionOptions == nil ? ChatListNavigationBar.Search(isEnabled: true) : nil,
                    activeSearch: self.isSearchDisplayControllerActive,
                    primaryContent: primaryContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    storySubscriptions: nil,
                    storiesIncludeHidden: true,
                    uploadProgress: [:],
                    headerPanels: nil,
                    tabsNode: nil,
                    tabsNodeIsSearch: false,
                    accessoryPanelContainer: nil,
                    accessoryPanelContainerHeight: 0.0,
                    hasEdgeEffect: component.mode.usesPlainStyle,
                    activateSearch: { [weak self] searchContentNode in
                        if !component.mode.isPreview && component.selectionOptions == nil {
                            self?.activateSearch(searchContentNode: searchContentNode)
                        }
                    },
                    openStatusSetup: { _ in
                    },
                    allowAutomaticOrder: {
                    }
                )),
                environment: {},
                containerSize: availableSize
            )

            return navigationBarSize
        }

        private func currentSheetNavigationBarFrame(bounds: CGRect?) -> CGRect? {
            if self.sheetNavigationFrame.size.width <= 0.0 || self.sheetNavigationFrame.size.height <= 0.0 {
                return nil
            }

            var frame = self.sheetNavigationFrame
            if let bounds {
                let topOffset = max(0.0, -bounds.minY + self.sheetTopInset)
                frame.origin.y = topOffset + self.sheetContainerInset + self.sheetNavigationTopInset
            }

            return frame
        }

        private func sheetSearchOverlayFrame(navigationBarFrame: CGRect, availableSize: CGSize, statusBarHeight: CGFloat) -> CGRect {
            let originY = max(navigationBarFrame.minY + self.sheetSearchOverlayTopOffset, statusBarHeight + self.sheetSearchOverlayTopOffset)
            return CGRect(
                origin: CGPoint(x: navigationBarFrame.minX, y: originY),
                size: CGSize(width: navigationBarFrame.width, height: max(1.0, availableSize.height - originY))
            )
        }

        private func updateSearchDisplayControllers(containerLayout: ContainerViewLayout, navigationHeight: CGFloat, transition: ComponentTransition) {
            self.validLayout = (containerLayout, navigationHeight)
            if let searchDisplayController = self.searchDisplayController {
                searchDisplayController.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationHeight, transition: transition.containedViewLayoutTransition)
            }
            if let disappearingSearchDisplayController = self.disappearingSearchDisplayController {
                disappearingSearchDisplayController.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationHeight, transition: transition.containedViewLayoutTransition)
            }
        }

        private func updateSheetNavigationBarFrame(bounds: CGRect?, transition: ComponentTransition) {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View, let frame = self.currentSheetNavigationBarFrame(bounds: bounds) else {
                return
            }

            transition.setFrame(view: navigationBarComponentView, frame: frame)
            self.updateNavigationScrolling(transition: transition)

            if self.searchOverlayNode.view.superview === navigationBarComponentView.superview, let component = self.component, let environment = self.environment, component.mode.usesSheetPresentation {
                let overlayFrame = self.sheetSearchOverlayFrame(navigationBarFrame: frame, availableSize: self.currentAvailableSize, statusBarHeight: environment.statusBarHeight)
                self.searchOverlayNode.frame = overlayFrame
                transition.setFrame(view: self.searchOverlayNode.view, frame: overlayFrame)

                let containerLayout = self.containerLayout(
                    availableSize: overlayFrame.size,
                    environment: environment,
                    mode: .sheet,
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
                )
                self.updateSearchDisplayControllers(containerLayout: containerLayout, navigationHeight: frame.height, transition: transition)
            }
        }

        private func placeSearchOverlay(in superview: UIView, frame: CGRect, transition: ComponentTransition) {
            self.searchOverlayNode.frame = frame
            if self.searchOverlayNode.view.superview !== superview {
                self.searchOverlayNode.view.removeFromSuperview()
                superview.addSubview(self.searchOverlayNode.view)
            }
            transition.setFrame(view: self.searchOverlayNode.view, frame: frame)
            self.searchOverlayNode.view.isUserInteractionEnabled = self.searchDisplayController != nil || self.disappearingSearchDisplayController != nil
        }

        private func placeFullscreenNavigationBar(navigationBarSize: CGSize, transition: ComponentTransition) {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                return
            }
            if navigationBarComponentView.superview !== self {
                navigationBarComponentView.removeFromSuperview()
                self.addSubview(navigationBarComponentView)
            }

            self.sheetNavigationFrame = .zero
            transition.setFrame(view: navigationBarComponentView, frame: CGRect(origin: .zero, size: navigationBarSize))
            self.updateNavigationScrolling(transition: transition)
        }

        private func placeSheetNavigationBar(sheetView: ResizableSheetComponent<EnvironmentType>.View, availableSize: CGSize, navigationBarSize: CGSize, sheetMetrics: (fillingSize: CGFloat, rawSideInset: CGFloat), environment: EnvironmentType, transition: ComponentTransition) -> CGRect? {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                return nil
            }
            if navigationBarComponentView.superview !== sheetView.containerView {
                navigationBarComponentView.removeFromSuperview()
                sheetView.containerView.addSubview(navigationBarComponentView)
            }

            let isSheetSearchFullscreen = self.isSheetSearchFullscreen
            let containerInset: CGFloat = isSheetSearchFullscreen ? 0.0 : environment.statusBarHeight + 10.0
            let defaultHeight: CGFloat = self.isAdmin ? 620.0 : 700.0
            let contentHeight = self.sheetExternalState.contentHeight
            let initialContentHeight = isSheetSearchFullscreen ? contentHeight : min(contentHeight, max(0.0, defaultHeight))
            let topInset = isSheetSearchFullscreen ? 0.0 : max(0.0, availableSize.height - containerInset - initialContentHeight)

            self.sheetTopInset = topInset
            self.sheetContainerInset = containerInset
            self.sheetNavigationFrame = CGRect(
                origin: CGPoint(x: sheetMetrics.rawSideInset, y: topInset + containerInset + self.sheetNavigationTopInset),
                size: navigationBarSize
            )

            self.updateSheetNavigationBarFrame(bounds: self.currentSheetBounds, transition: transition)
            sheetView.containerView.bringSubviewToFront(navigationBarComponentView)
            return self.currentSheetNavigationBarFrame(bounds: self.currentSheetBounds)
        }

        private var visiblePendingRequests: CommunityPeerLinkRequests? {
            guard let pendingRequests = self.pendingRequests else {
                return nil
            }
            guard !self.pendingRequestActions.isEmpty else {
                return pendingRequests
            }

            let pendingPeerIds = Set(self.pendingRequestActions.keys)
            let requests = pendingRequests.requests.filter { request in
                !pendingPeerIds.contains(request.peerId)
            }
            let hiddenCount = pendingRequests.requests.count - requests.count
            let totalCount = max(0, pendingRequests.totalCount - Int32(hiddenCount))
            return CommunityPeerLinkRequests(
                totalCount: totalCount,
                requests: requests,
                nextOffset: pendingRequests.nextOffset,
                peers: pendingRequests.peers
            )
        }

        private func makeContentComponent(component: CommunityViewScreenComponent, topInset: CGFloat) -> CommunityViewContentComponent {
            return CommunityViewContentComponent(
                context: component.context,
                communityId: component.communityId,
                mode: component.mode,
                topInset: topInset,
                community: self.community,
                cachedData: self.cachedData,
                peers: self.peers,
                cachedPeerData: self.cachedPeerData,
                previews: self.previews,
                pendingRequests: component.selectionOptions == nil ? self.visiblePendingRequests : nil,
                pendingRequestCachedPeerData: self.pendingRequestCachedPeerData,
                pendingRequestInFlightPeerId: nil,
                pendingRequestInFlightApprove: nil,
                joinedPeerIds: self.joinedPeerIds,
                selectionOptions: component.selectionOptions,
                toggleCollapsed: { [weak self] value in
                    self?.toggleCollapsed(value)
                },
                setRequestApproval: { [weak self] request, peer, approve in
                    self?.setPendingRequestApproval(request: request, peer: peer, approve: approve)
                },
                openPeer: { [weak self] peer in
                    self?.openPeer(peer)
                },
                openPendingRequests: { [weak self] in
                    self?.openPendingRequests()
                },
                removePeer: { [weak self] peerId in
                    self?.removePeer(peerId)
                }
            )
        }

        private func makeBottomButtonComponent(theme: PresentationTheme, strings: PresentationStrings, safeInsets: UIEdgeInsets) -> CommunityViewBottomButtonComponent {
            return CommunityViewBottomButtonComponent(
                theme: theme,
                title: strings.Community_View_AddChatButton,
                iconName: "Item List/Icons/Add",
                safeInsets: safeInsets,
                isEnabled: !self.isAddActionInProgress,
                displaysProgress: self.isAddActionInProgress,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.openAddChat()
                }
            )
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let component = self.component else {
                return nil
            }
            if component.mode.isPreview {
                if self.bounds.contains(point) {
                    return self.scrollView
                } else {
                    return nil
                }
            } else {
                return super.hitTest(point, with: event)
            }
        }

        func update(component: CommunityViewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.currentAvailableSize = availableSize

            self.ensureDataSignal(component: component)

            let currentSheetMetrics = self.sheetMetrics(availableSize: availableSize, environment: environment)
            let navigationAvailableSize: CGSize
            let navigationStatusBarHeight: CGFloat
            let navigationSideInsets: (left: CGFloat, right: CGFloat)
            switch component.mode {
            case .sheet:
                navigationAvailableSize = CGSize(width: currentSheetMetrics.fillingSize, height: availableSize.height)
                navigationStatusBarHeight = 0.0
                navigationSideInsets = (0.0, 0.0)
            case .fullscreen, .preview:
                navigationAvailableSize = availableSize
                navigationStatusBarHeight = environment.statusBarHeight
                navigationSideInsets = (environment.safeInsets.left, environment.safeInsets.right)
            }

            let navigationBarSize = self.updateNavigationBar(
                component: component,
                availableSize: navigationAvailableSize,
                statusBarHeight: navigationStatusBarHeight,
                leftInset: navigationSideInsets.left,
                rightInset: navigationSideInsets.right,
                environment: environment,
                transition: transition
            )
            let navigationHeight = navigationBarSize.height
            if self.isSearchDisplayControllerActive == nil {
                self.lastInactiveNavigationHeight = navigationHeight
            }
            let contentNavigationHeight = self.lastInactiveNavigationHeight ?? navigationHeight
            let displaysBottomItem = !self.isSheetSearchFullscreen && !component.mode.isPreview && component.selectionOptions == nil && self.canAddChatsToCommunity
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let bottomPanelHeight = 52.0 + buttonInsets.bottom

            switch component.mode {
            case .sheet:
                self.scrollView.removeFromSuperview()
                self.fullscreenContent.view?.removeFromSuperview()
                self.fullscreenBottomItem.view?.removeFromSuperview()
                self.bottomEdgeEffectView.removeFromSuperview()

                let theme = environment.theme.withModalBlocksBackground()
                let isSheetSearchFullscreen = self.isSheetSearchFullscreen
                let bottomItem: AnyComponent<Empty>? = displaysBottomItem ? AnyComponent(self.makeBottomButtonComponent(theme: theme, strings: environment.strings, safeInsets: environment.safeInsets)) : nil
                let sheetBackgroundColor = isSheetSearchFullscreen ? theme.list.modalPlainBackgroundColor : theme.list.modalBlocksBackgroundColor
                let contentTopInset = contentNavigationHeight + self.sheetNavigationTopInset
                let sheetSize = self.sheet.update(
                    transition: transition,
                    component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                        content: AnyComponent<EnvironmentType>(self.makeContentComponent(component: component, topInset: contentTopInset)),
                        hasTopEdgeEffect: true,
                        bottomItem: bottomItem,
                        backgroundColor: .color(sheetBackgroundColor),
                        isFullscreen: isSheetSearchFullscreen,
                        defaultHeight: self.isAdmin ? 620.0 : 700.0,
                        externalState: self.sheetExternalState,
                        animateOut: self.animateOut
                    )),
                    environment: {
                        environment
                        ResizableSheetComponentEnvironment(
                            theme: theme,
                            statusBarHeight: environment.statusBarHeight,
                            safeInsets: environment.safeInsets,
                            inputHeight: 0.0,
                            metrics: environment.metrics,
                            deviceMetrics: environment.deviceMetrics,
                            isDisplaying: environment.isVisible,
                            isCentered: environment.metrics.widthClass == .regular,
                            screenSize: availableSize,
                            regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                            dismiss: { [weak self] animated in
                                self?.dismiss(animated: animated)
                            },
                            boundsUpdated: self.sheetBoundsUpdated
                        )
                    },
                    containerSize: availableSize
                )
                if let sheetView = self.sheet.view {
                    if sheetView.superview == nil {
                        self.addSubview(sheetView)
                    }
                    transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
                }
                if let sheetView = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                    let navigationBarFrame = self.placeSheetNavigationBar(
                        sheetView: sheetView,
                        availableSize: availableSize,
                        navigationBarSize: navigationBarSize,
                        sheetMetrics: currentSheetMetrics,
                        environment: environment,
                        transition: transition
                    )
                    if let navigationBarFrame {
                        let searchOverlayFrame = self.sheetSearchOverlayFrame(navigationBarFrame: navigationBarFrame, availableSize: availableSize, statusBarHeight: environment.statusBarHeight)
                        self.placeSearchOverlay(in: sheetView.containerView, frame: searchOverlayFrame, transition: transition)

                        let searchContainerLayout = self.containerLayout(
                            availableSize: searchOverlayFrame.size,
                            environment: environment,
                            mode: component.mode,
                            safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
                        )
                        self.updateSearchDisplayControllers(containerLayout: searchContainerLayout, navigationHeight: navigationHeight, transition: transition)

                        sheetView.containerView.bringSubviewToFront(self.searchOverlayNode.view)
                        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                            sheetView.containerView.bringSubviewToFront(navigationBarComponentView)
                        }
                    }
                }
            case .fullscreen, .preview:
                self.sheet.view?.removeFromSuperview()
                self.currentSheetBounds = nil
                self.placeSearchOverlay(in: self, frame: CGRect(origin: .zero, size: availableSize), transition: transition)
               
                self.placeFullscreenNavigationBar(navigationBarSize: navigationBarSize, transition: transition)

                let searchContainerLayout = self.containerLayout(availableSize: availableSize, environment: environment, mode: component.mode)
                self.updateSearchDisplayControllers(containerLayout: searchContainerLayout, navigationHeight: navigationHeight, transition: transition)

                let theme = environment.theme
                self.backgroundColor = theme.chatList.backgroundColor

                let bottomFrame: CGRect
                let bottomSize: CGSize
                if displaysBottomItem {
                    let bottomPanelWidth = max(1.0, availableSize.width - environment.safeInsets.left * 2.0 - buttonInsets.left - buttonInsets.right)
                    bottomSize = self.fullscreenBottomItem.update(
                        transition: transition,
                        component: AnyComponent(self.makeBottomButtonComponent(theme: theme, strings: environment.strings, safeInsets: UIEdgeInsets())),
                        environment: {},
                        containerSize: CGSize(width: bottomPanelWidth, height: 52.0)
                    )
                    bottomFrame = CGRect(
                        origin: CGPoint(
                            x: environment.safeInsets.left + buttonInsets.left,
                            y: availableSize.height - bottomPanelHeight
                        ),
                        size: bottomSize
                    )
                    if let bottomView = self.fullscreenBottomItem.view {
                        if bottomView.superview == nil {
                            self.addSubview(bottomView)
                        }
                        transition.setFrame(view: bottomView, frame: bottomFrame)
                    }
                } else {
                    self.fullscreenBottomItem.view?.removeFromSuperview()
                    bottomSize = .zero
                    bottomFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: bottomSize)
                }

                if self.scrollView.superview == nil {
                    if displaysBottomItem, let bottomView = self.fullscreenBottomItem.view {
                        self.insertSubview(self.scrollView, belowSubview: bottomView)
                    } else {
                        self.addSubview(self.scrollView)
                    }
                }
                let displaysBottomEdgeEffect = component.mode.usesPlainStyle && !component.mode.isPreview && (component.selectionOptions != nil || displaysBottomItem)
                if displaysBottomEdgeEffect {
                    let bottomEdgeEffectHeight = bottomSize.height + environment.safeInsets.bottom + 36.0
                    let bottomEdgeEffectFrame = CGRect(
                        origin: CGPoint(x: 0.0, y: availableSize.height - bottomEdgeEffectHeight),
                        size: CGSize(width: availableSize.width, height: bottomEdgeEffectHeight)
                    )
                    if self.bottomEdgeEffectView.superview == nil {
                        self.addSubview(self.bottomEdgeEffectView)
                    }
                    if self.scrollView.superview === self {
                        self.insertSubview(self.bottomEdgeEffectView, aboveSubview: self.scrollView)
                    }
                    if let bottomView = self.fullscreenBottomItem.view, bottomView.superview === self {
                        self.insertSubview(self.bottomEdgeEffectView, belowSubview: bottomView)
                    }
                    transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
                    self.bottomEdgeEffectView.update(content: theme.chatList.backgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
                } else {
                    self.bottomEdgeEffectView.removeFromSuperview()
                }
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: availableSize))

                let fullscreenContentTopInset = contentNavigationHeight
                let contentSize = self.fullscreenContent.update(
                    transition: transition,
                    component: AnyComponent(self.makeContentComponent(component: component, topInset: fullscreenContentTopInset)),
                    environment: {
                        environment
                    },
                    containerSize: CGSize(width: availableSize.width, height: 10000.0)
                )
                if let contentView = self.fullscreenContent.view {
                    if contentView.superview == nil {
                        self.scrollView.addSubview(contentView)
                    }
                    transition.setFrame(view: contentView, frame: CGRect(origin: .zero, size: contentSize))
                }

                let scrollBottomInset: CGFloat
                if displaysBottomItem {
                    scrollBottomInset = availableSize.height - bottomFrame.minY + 8.0
                } else {
                    scrollBottomInset = environment.safeInsets.bottom
                }
                let scrollInsets = UIEdgeInsets(top: fullscreenContentTopInset, left: 0.0, bottom: scrollBottomInset, right: 0.0)
                if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                    self.scrollView.verticalScrollIndicatorInsets = scrollInsets
                }
                let scrollContentHeight: CGFloat
                if component.mode.usesPlainStyle && !component.mode.isPreview && component.selectionOptions == nil {
                    scrollContentHeight = max(contentSize.height, availableSize.height + ChatListNavigationBar.searchScrollHeight)
                } else {
                    scrollContentHeight = contentSize.height
                }
                let scrollContentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
                if self.scrollView.contentSize != scrollContentSize {
                    self.scrollView.contentSize = scrollContentSize
                }
                if component.mode.usesPlainStyle && !component.mode.isPreview && component.selectionOptions == nil && self.isSearchDisplayControllerActive == nil && !self.didApplyInitialOffset {
                    self.didApplyInitialOffset = true
                    self.scrollView.setContentOffset(CGPoint(x: 0.0, y: ChatListNavigationBar.searchScrollHeight), animated: false)
                    self.updateNavigationScrolling(transition: .immediate)
                }
                self.bringSubviewToFront(self.searchOverlayNode.view)
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    self.bringSubviewToFront(navigationBarComponentView)
                }
            }

            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout, var presentationContextLayout = controller.currentlyAppliedLayout {
                if displaysBottomItem {
                    let baseBottomInset = presentationContextLayout.intrinsicInsets.bottom + presentationContextLayout.safeInsets.bottom
                    presentationContextLayout.intrinsicInsets.bottom = max(baseBottomInset, bottomPanelHeight)
                    presentationContextLayout.safeInsets.bottom = 0.0
                }
                controller.presentationContext.containerLayoutUpdated(presentationContextLayout, transition: transition.containedViewLayoutTransition)
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityViewScreenImpl: ViewControllerComponentContainer, CommunityViewScreen {
    public init(context: AccountContext, communityId: EnginePeer.Id, mode: CommunityViewScreenMode, selectionOptions: CommunityPeerSelectionOptions? = nil) {
        super.init(
            context: context,
            component: CommunityViewScreenComponent(context: context, communityId: communityId, mode: mode, selectionOptions: selectionOptions),
            navigationBarAppearance: .none,
            theme: .default,
            updatedPresentationData: nil
        )

        self.automaticallyControlPresentationContextLayout = false

        switch mode {
        case .sheet:
            self.statusBar.statusBarStyle = .Ignore
            self.navigationPresentation = .flatModal
            self.blocksBackgroundWhenInOverlay = true
        case .fullscreen, .preview:
            self.statusBar.statusBarStyle = .Ignore
            self.navigationPresentation = .default
            self.blocksBackgroundWhenInOverlay = false
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if self.navigationPresentation == .flatModal {
            self.view.disablesInteractiveModalDismiss = true
        }
    }

    public func dismissAnimated() {
        guard self.navigationPresentation == .flatModal else {
            self.dismiss(completion: nil)
            return
        }
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
