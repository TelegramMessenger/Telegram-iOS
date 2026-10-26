import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AlertUI
import PresentationDataUtils
import UndoUI
import ChatPresentationInterfaceState
import ChatInputPanelNode
import AccountContext
import OldChannelsController
import TooltipUI
import TelegramNotices
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import GlassControls
import BundleIconComponent
import MultilineTextComponent
import ContextUI
import NewsFeedSupport
import NewsChannelIsland

private enum SubscriberAction: Equatable, Hashable {
    case join
    case joinGroup
    case applyToJoin
    case kicked
    case muteNotifications
    case unmuteNotifications
    case unpinMessages(Int)
    case hidePinnedMessages
    case openChannel
    case openGroup
    case openChat
    case addToNews
    case addedToNews
    case addedToChats(muted: Bool)
}

private func titleAndColorForAction(_ action: SubscriberAction, theme: PresentationTheme, strings: PresentationStrings) -> (String, UIColor) {
    switch action {
        case .join:
            return (strings.Channel_JoinChannel, theme.chat.inputPanel.panelControlAccentColor)
        case .joinGroup:
            return (strings.Group_JoinGroup, theme.chat.inputPanel.panelControlAccentColor)
        case .applyToJoin:
            return (strings.Group_ApplyToJoin, theme.chat.inputPanel.panelControlAccentColor)
        case .kicked:
            return (strings.Channel_JoinChannel, theme.chat.inputPanel.panelControlDisabledColor)
        case .muteNotifications:
            return (strings.Conversation_Mute, theme.chat.inputPanel.panelControlAccentColor)
        case .unmuteNotifications:
            return (strings.Conversation_Unmute, theme.chat.inputPanel.panelControlAccentColor)
        case .unpinMessages:
            return (strings.Chat_PanelUnpinAllMessages, theme.chat.inputPanel.panelControlAccentColor)
        case .hidePinnedMessages:
            return (strings.Chat_PanelHidePinnedMessages, theme.chat.inputPanel.panelControlAccentColor)
        case .openChannel:
            return (strings.SavedMessages_OpenChannel, theme.chat.inputPanel.panelControlAccentColor)
        case .openGroup:
            return (strings.SavedMessages_OpenGroup, theme.chat.inputPanel.panelControlAccentColor)
        case .openChat:
            return (strings.SavedMessages_OpenChat, theme.chat.inputPanel.panelControlAccentColor)
        case .addToNews:
            return (strings.Channel_AddToNews, theme.chat.inputPanel.panelControlAccentColor)
        case .addedToNews:
            return (strings.Channel_AddedToNews, theme.chat.inputPanel.panelControlAccentColor)
        case .addedToChats:
            return (strings.Channel_AddedToChats, theme.chat.inputPanel.panelControlAccentColor)
    }
}

private func actionForPeer(context: AccountContext, peer: EnginePeer, interfaceState: ChatPresentationInterfaceState, isJoining: Bool, pending: NewsChannelBarPending, isMuted: Bool) -> SubscriberAction? {
    if case let .replyThread(message) = interfaceState.chatLocation, message.peerId == context.account.peerId {
        if let peer = interfaceState.savedMessagesTopicPeer {
            if case let .channel(channel) = peer {
                if case .broadcast = channel.info {
                    return .openChannel
                } else {
                    return .openGroup
                }
            } else if case .legacyGroup = peer {
                return .openGroup
            }
        }
        return .openChat
    } else if case .pinnedMessages = interfaceState.subject {
        var canManagePin = false
        if case let .channel(channel) = peer {
            canManagePin = channel.hasPermission(.pinMessages)
        } else if case let .legacyGroup(group) = peer {
            switch group.role {
                case .creator, .admin:
                    canManagePin = true
                default:
                    if let defaultBannedRights = group.defaultBannedRights {
                        canManagePin = !defaultBannedRights.flags.contains(.banPinMessages)
                    } else {
                        canManagePin = true
                    }
            }
        } else if case .user = peer, interfaceState.explicitelyCanPinMessages {
            canManagePin = true
        }
        if canManagePin {
            return .unpinMessages(max(1, interfaceState.pinnedMessage?.totalCount ?? 1))
        } else {
            return .hidePinnedMessages
        }
    } else {
        if case let .channel(channel) = peer {
            let participation: NewsChannelParticipation
            switch channel.participationStatus {
            case .member:
                participation = .member
            case .left:
                participation = .left
            case .kicked:
                participation = .kicked
            }
            var isBroadcast = false
            if case .broadcast = channel.info {
                isBroadcast = true
            }
            // Before the participation switch below: a light join (in_news, not joined) shows the News states.
            switch newsChannelBarAction(isBroadcast: isBroadcast, isInNews: channel.flags.contains(.isInNews), participation: participation, isMuted: isMuted, featureEnabled: isNewsFeedEnabled(appConfiguration: context.currentAppConfiguration.with { $0 }), pending: pending) {
            case .addToNews:
                return .addToNews
            case .addedToNews:
                return .addedToNews
            case let .addedToChats(muted):
                return .addedToChats(muted: muted)
            case .existing:
                break
            }
            if case .broadcast = channel.info, isJoining {
                if isMuted {
                    return .unmuteNotifications
                } else {
                    return .muteNotifications
                }
            }
            switch channel.participationStatus {
                case .kicked:
                    return .kicked
                case .left:
                    if case .group = channel.info {
                        if channel.flags.contains(.requestToJoin) {
                            return .applyToJoin
                        } else {
                            if channel.flags.contains(.isForum) {
                                return .join
                            } else {
                                return .joinGroup
                            }
                        }
                    } else {
                        return .join
                    }
                case .member:
                    if isMuted {
                        return .unmuteNotifications
                    } else {
                        return .muteNotifications
                    }
            }
        } else {
            if isMuted {
                return .unmuteNotifications
            } else {
                return .muteNotifications
            }
        }
    }
}

private let badgeFont = Font.regular(14.0)

private final class ChannelNewsContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private weak var island: NewsChannelIslandView?
    private let initialSourceView: UIView

    init(controller: ViewController, island: NewsChannelIslandView) {
        self.controller = controller
        self.island = island
        self.initialSourceView = island.menuSourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        // The bar is at the bottom: open the menu above it. The island opts in to the liquid morph, so on iOS 26+ the
        // menu grows out of it, centred on it, as the mockup's system menu does.
        // The island's current glass: a width change while the menu is open moves the island into a new one, and the
        // menu closes into that.
        return ContextControllerReferenceViewInfo(referenceView: self.island?.menuSourceView ?? self.initialSourceView, contentAreaInScreenSpace: mainWindowScreenBounds, actionsPosition: .top, centersMorphedActions: true)
    }
}

public final class ChatChannelSubscriberInputPanelNode: ChatInputPanelNode {
    private let panelContainer = UIView()
    private let panel = ComponentView<Empty>()
    
    /*private let buttonBackgroundView: GlassBackgroundView
    private let button: HighlightableButton
    private let buttonTitle: ImmediateTextNode
    private let buttonTintTitle: ImmediateTextNode
    
    private let helpButtonBackgroundView: GlassBackgroundView
    private let helpButton: HighlightableButton
    private let helpButtonIconView: UIImageView
    
    private let giftButtonBackgroundView: GlassBackgroundView
    private let giftButton: HighlightableButton
    private let giftButtonIconView: UIImageView
    
    private let suggestedPostButtonBackgroundView: GlassBackgroundView
    private let suggestedPostButton: HighlightableButton
    private let suggestedPostButtonIconView: UIImageView*/
    
    private var action: SubscriberAction?
    
    private let actionDisposable = MetaDisposable()
    private let badgeDisposable = MetaDisposable()
    private var isJoining: Bool = false
    /// Add to News and Add to Chats stay pending until the stored channel shows their result, not just until their
    /// answer: see `NewsChannelBarRequest`.
    private var addToNewsRequest: NewsChannelBarRequest?
    private var addToChatsRequest: NewsChannelBarRequest?
    /// Remove from News and Notify / Do Not Notify only change Postbox: they too show at once and hold until the
    /// stored channel shows them, so a menu item is applied before its menu closes.
    private var removeFromNewsRequest: NewsChannelBarRequest?
    private var muteRequest: NewsChannelBarRequest?
    /// Set from a menu item's tap until its menu is dismissed: the island puts every change in place without its own
    /// transition, and the closing menu morphs into it.
    private var islandAppliesChangesImmediately = false
    /// A menu item is applying itself; a second tap on the menu is ignored until the menu is dismissed.
    private var isApplyingMenuItem = false
    private var islandView: NewsChannelIslandView?
    /// Remove from Chats waiting for its toast (spec §1.4).
    private var pendingRemoval: NewsDeferredAction?
    private weak var barToast: UndoOverlayController?
    private let haptic = HapticFeedback()

    private var pending: NewsChannelBarPending {
        var muted: Bool?
        if case let .setMuted(value)? = self.muteRequest?.kind {
            muted = value
        }
        return NewsChannelBarPending(isAddingToNews: self.addToNewsRequest != nil, isJoining: self.isJoining || self.addToChatsRequest != nil, isRemovingFromChats: self.pendingRemoval != nil, isRemovingFromNews: self.removeFromNewsRequest != nil, muted: muted)
    }

    /// A request's answer came back (marked by the caller): the bar keeps showing its outcome until the stored channel
    /// does (this layout settles it if the channel already does), or until the settle timeout.
    private func settleAnsweredRequest() {
        self.relayoutPanel()
        Queue.mainQueue().after(NewsChannelBarRequest.settleTimeout + 0.05) { [weak self] in
            self?.relayoutPanel()
        }
    }
    private let newsActionDisposable = MetaDisposable()
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var layoutData: (CGFloat, CGFloat, CGFloat, CGFloat, UIEdgeInsets, CGFloat, CGFloat, Bool, LayoutMetrics, DeviceMetrics)?
    
    public override init() {
        super.init()
        
        self.view.addSubview(self.panelContainer)
    }
    
    deinit {
        // The chat closed or the bar was replaced during the Undo window: the leave goes now, and its toast with it.
        self.pendingRemoval?.commit()
        self.barToast?.dismiss()
        self.actionDisposable.dispose()
        self.newsActionDisposable.dispose()
        self.badgeDisposable.dispose()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
    
    @objc private func giftPressed() {
        self.interfaceInteraction?.openPremiumGift()
    }
    
    @objc private func helpPressed() {
        self.interfaceInteraction?.presentGigagroupHelp()
    }

    @objc private func suggestedPostPressed() {
        self.interfaceInteraction?.openMonoforum()
    }
    
    private func relayoutPanel() {
        if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, maxOverlayHeight, isSecondary, metrics, deviceMetrics) = self.layoutData, let presentationInterfaceState = self.presentationInterfaceState {
            let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics, deviceMetrics: deviceMetrics, force: true)
        }
    }

    private func openJoinWebView(_ webView: JoinChatWebView, context: AccountContext, peer: EnginePeer) {
        if let controller = self.interfaceInteraction?.getNavigationController()?.viewControllers.last as? ViewController {
            context.sharedContext.openJoinChatWebView(context: context, parentController: controller, updatedPresentationData: nil, webView: webView, chatTitle: peer.compactDisplayTitle)
        }
    }

    /// `retry` runs after the old-channels screen frees a slot: the request that failed, not whatever the bar shows now.
    private func presentJoinError(_ error: JoinChannelError, context: AccountContext, retry: @escaping () -> Void) {
        guard let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let text: String
        switch error {
        case .inviteRequestSent:
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.interfaceInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationInterfaceState.strings.Group_RequestToJoinSent, text: presentationInterfaceState.strings.Group_RequestToJoinSentDescriptionGroup ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), nil)
            return
        case .tooMuchJoined:
            self.interfaceInteraction?.getNavigationController()?.pushViewController(oldChannelsController(context: context, intent: .join, completed: { value in
                if value {
                    retry()
                }
            }))
            return
        case .tooMuchUsers:
            text = presentationInterfaceState.strings.Conversation_UsersTooMuchError
        case .generic:
            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                text = presentationInterfaceState.strings.Channel_ErrorAccessDenied
            } else {
                text = presentationInterfaceState.strings.Group_ErrorAccessDenied
            }
        }
        self.interfaceInteraction?.presentController(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationInterfaceState.strings.Common_OK, action: {})]), nil)
    }

    @objc private func buttonPressed() {
        guard let context = self.context, let action = self.action, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        switch action {
        case .join, .joinGroup, .applyToJoin:
            self.startJoin(context: context, peer: EnginePeer(peer))
        case .addToNews:
            guard self.pending.acceptsTap else {
                return
            }
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            if let pendingRemoval = self.pendingRemoval {
                // Add to News on a channel still joined would change nothing, and a join sent before the server has
                // the leave can be undone by it: the deferred leave goes first, and Add to News waits until the
                // channel shows it. `removePeerChat` completes on its local transaction; the leave request follows.
                self.pendingRemoval = nil
                self.barToast?.dismiss()
                self.addToNewsRequest = NewsChannelBarRequest(kind: .addToNews)
                self.relayoutPanel()
                let enginePeer = EnginePeer(peer)
                pendingRemoval.commit(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.newsActionDisposable.set((context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: enginePeer.id))
                    |> filter { peer -> Bool in
                        if case let .channel(channel) = peer, case .member = channel.participationStatus {
                            return false
                        }
                        return true
                    }
                    |> take(1)
                    |> timeout(10.0, queue: .mainQueue(), alternate: .single(nil))
                    |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                        self?.startAddToNews(context: context, peer: enginePeer)
                    }))
                })
            } else {
                self.startAddToNews(context: context, peer: EnginePeer(peer))
            }
        case .addedToNews, .addedToChats:
            guard self.pending.acceptsTap else {
                return
            }
            self.openIslandMenu()
        case .kicked:
            break
        case .muteNotifications, .unmuteNotifications:
            if let context = self.context, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer {
                self.actionDisposable.set(context.engine.peers.togglePeerMuted(peerId: peer.id, threadId: nil).startStrict())
            }
        case .hidePinnedMessages, .unpinMessages:
            self.interfaceInteraction?.unpinAllMessages()
        case .openChannel, .openGroup, .openChat:
            if let presentationInterfaceState = self.presentationInterfaceState, let savedMessagesTopicPeer = presentationInterfaceState.savedMessagesTopicPeer {
                self.interfaceInteraction?.navigateToChat(savedMessagesTopicPeer.id)
            }
        }
    }
    
    private func startAddToNews(context: AccountContext, peer: EnginePeer) {
        self.addToNewsRequest = NewsChannelBarRequest(kind: .addToNews)
        self.relayoutPanel()
        let title = peer.compactDisplayTitle
        self.newsActionDisposable.set((context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peer.id, hash: nil, forNews: true)
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .joined:
                // The answer arrives before the channel with `in_news` is stored.
                self.addToNewsRequest?.answer(at: CACurrentMediaTime())
                self.settleAnsweredRequest()
                self.presentBarToast(.addedToNews, title: title)
            case let .webView(webView):
                // Not added yet: the bot's web view decides. Show the bar as it really is.
                self.addToNewsRequest = nil
                self.relayoutPanel()
                self.openJoinWebView(webView, context: context, peer: peer)
            }
        }, error: { [weak self] error in
            guard let self else {
                return
            }
            self.addToNewsRequest = nil
            self.relayoutPanel()
            // The same outcomes as Join: a request-sent toast, the old-channels screen, or an alert.
            self.presentJoinError(error, context: context, retry: { [weak self] in
                self?.startAddToNews(context: context, peer: peer)
            })
        }))
    }

    /// Join, Join Group, Apply to Join, and Add to Chats in the News menu: one path, so the menu gets the same
    /// joining state, error alerts and join web view as the button.
    /// `isAddToChats`: the News menu's Add to Chats, which the bar shows at once and holds until the channel is stored
    /// joined, and which closing the chat does not cancel. `muteAfterJoin` mutes the channel once joined.
    private func startJoin(context: AccountContext, peer: EnginePeer, isAddToChats: Bool = false, muteAfterJoin: Bool = false, onJoined: (() -> Void)? = nil) {
        self.isJoining = true
        if isAddToChats {
            self.addToChatsRequest = NewsChannelBarRequest(kind: .addToChats)
        }
        if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, maxOverlayHeight, isSecondary, metrics, deviceMetrics) = self.layoutData, let presentationInterfaceState = self.presentationInterfaceState {
            let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics, deviceMetrics: deviceMetrics, force: true)
        }
        var didJoin = false
        var joinSignal = context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peer.id, hash: nil)
        if muteAfterJoin {
            let peerId = peer.id
            joinSignal = joinSignal
            |> mapToSignal { result -> Signal<JoinChannelResult, JoinChannelError> in
                guard case .joined = result else {
                    return .single(result)
                }
                // ChannelAdd_4: a channel added to Chats starts without notifications. It is muted before the
                // join's request ends, so the island never shows the bell in between.
                // The mute is one Postbox transaction: it emits once, when the setting is stored.
                return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: Int32.max)
                |> castError(JoinChannelError.self)
                |> map { _ -> JoinChannelResult in
                    return result
                }
            }
        }
        let observedJoin = joinSignal
        |> afterDisposed { [weak self] in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.isJoining = false
                }
            }
        }
        let onNext: (JoinChannelResult) -> Void = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .joined:
                didJoin = true
                if isAddToChats {
                    // The answer arrives before the joined channel is stored.
                    strongSelf.addToChatsRequest?.answer(at: CACurrentMediaTime())
                    strongSelf.settleAnsweredRequest()
                }
            case let .webView(webView):
                // Not joined yet: the bot's web view decides. Show the bar as it really is.
                strongSelf.isJoining = false
                strongSelf.addToChatsRequest = nil
                strongSelf.relayoutPanel()
                strongSelf.openJoinWebView(webView, context: context, peer: peer)
            }
        }
        let onError: (JoinChannelError) -> Void = { [weak self] error in
            guard let self else {
                return
            }
            // Back to the state the bar really has (Add to Chats shows "Added to Chats" while it runs).
            self.isJoining = false
            self.addToChatsRequest = nil
            self.relayoutPanel()
            self.presentJoinError(error, context: context, retry: { [weak self] in
                self?.startJoin(context: context, peer: peer, isAddToChats: isAddToChats, muteAfterJoin: muteAfterJoin, onJoined: onJoined)
            })
        }
        let onCompleted: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            if !didJoin {
                return
            }
            onJoined?()
            Queue.mainQueue().after(0.5) {
                if let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer {
                    var canEditRank = false
                    if let channel = peer as? TelegramChannel, case .group = channel.info, channel.hasPermission(.editRank) {
                        canEditRank = true
                    } else if let group = peer as? TelegramGroup, !group.hasBannedPermission(.banEditRank) {
                        canEditRank = true
                    }
                    if canEditRank {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let controller = UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Chat_JoinedGroup_Text, cancel: presentationData.strings.Chat_JoinedGroup_AddTag, destructive: false), elevatedLayout: true, action: { action in
                            if case .undo = action {
                                let tagController = context.sharedContext.makeChatCustomRankSetupScreen(context: context, peerId: peer.id, participantId: context.account.peerId, rank: nil, role: .member)
                                self.interfaceInteraction?.getNavigationController()?.pushViewController(tagController)
                            }
                            return true
                        })
                        self.interfaceInteraction?.presentController(controller, nil)
                    }
                }
            }
        }
        if isAddToChats {
            // Add to Chats is not owned by the bar: closing the chat must not cancel a join the server may already
            // have done, or the mute that follows it.
            let _ = observedJoin.startStandalone(next: onNext, error: onError, completed: onCompleted)
        } else {
            self.actionDisposable.set(observedJoin.startStrict(next: onNext, error: onError, completed: onCompleted))
        }
    }

    private func openIslandMenu() {
        guard let context = self.context, let interfaceInteraction = self.interfaceInteraction, let chatController = interfaceInteraction.chatController(), let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer, let islandView = self.islandView else {
            return
        }
        let barAction: NewsChannelBarAction
        switch self.action {
        case .addedToNews:
            barAction = .addedToNews
        case let .addedToChats(muted):
            barAction = .addedToChats(muted: muted)
        default:
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let enginePeer = EnginePeer(peer)
        var items: [ContextMenuItem] = []
        for item in newsChannelMenuItems(for: barAction, isArchived: presentationInterfaceState.isArchived) {
            items.append(.action(ContextMenuActionItem(text: self.menuTitle(item, strings: presentationData.strings), textColor: item.isDestructive ? .destructive : .primary, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: item.iconName), color: item.isDestructive ? theme.contextMenu.destructiveColor : theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }
                if self.isApplyingMenuItem {
                    return
                }
                // Applied first, and the menu dismissed once the change has landed, so the menu morphs back into the
                // island already showing it. Until then the island puts every change in place without its own
                // transition.
                self.isApplyingMenuItem = true
                self.islandAppliesChangesImmediately = true
                self.performMenuItem(item, context: context, peer: enginePeer, landed: { [weak self] in
                    // One more main-queue turn for the chat to integrate what landed in Postbox.
                    DispatchQueue.main.async {
                        c?.dismiss(completion: nil)
                        self?.islandAppliesChangesImmediately = false
                        self?.isApplyingMenuItem = false
                    }
                })
            })))
        }
        islandView.settleForMenu()
        // No outline of our own: the menu resolves the glass's shape (its corner radius) when it opens and again when
        // it closes, so an item that changes the island's width (Remove from Chats, Add to Chats) closes the menu into
        // the island's new size.
        let contextController = makeContextController(presentationData: presentationData, source: .reference(ChannelNewsContextReferenceContentSource(controller: chatController, island: islandView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        interfaceInteraction.presentController(contextController, nil)
    }

    private func menuTitle(_ item: NewsChannelMenuItem, strings: PresentationStrings) -> String {
        switch item {
        case .addToChats:
            return strings.Channel_AddToChats
        case .removeFromNews:
            return strings.Channel_RemoveFromNews
        case .notify:
            return strings.Channel_Notify
        case .doNotNotify:
            return strings.Channel_DoNotNotify
        case .archive:
            return strings.ChatList_Context_Archive
        case .unarchive:
            return strings.ChatList_Context_Unarchive
        case .removeFromChats:
            return strings.Channel_RemoveFromChats
        }
    }

    /// `landed` runs once the item's change is in place: a Postbox write when it completes (on the main queue), the
    /// bar's own state (Add to Chats, whose join goes to the server; Remove from Chats, deferred behind its toast)
    /// right away. Called exactly once on every path.
    private func performMenuItem(_ item: NewsChannelMenuItem, context: AccountContext, peer: EnginePeer, landed: @escaping () -> Void) {
        let peerId = peer.id
        let title = peer.compactDisplayTitle
        switch item {
        case .addToChats:
            // A plain join on a light-joined channel adds it to Chats.
            if !self.pending.acceptsTap {
                landed()
                return
            }
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            self.startJoin(context: context, peer: peer, isAddToChats: true, muteAfterJoin: !(self.presentationInterfaceState?.peerIsMuted ?? false), onJoined: { [weak self] in
                self?.presentBarToast(.addedToChats, title: title)
            })
            landed()
        case .removeFromNews:
            // Leaving is right only for a light join. A channel joined since the menu opened (Add to Chats on
            // another device, say) keeps its membership.
            if let channel = self.presentationInterfaceState?.renderedPeer?.peer as? TelegramChannel, case .member = channel.participationStatus {
                landed()
                return
            }
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            self.removeFromNewsRequest = NewsChannelBarRequest(kind: .removeFromNews)
            self.removeFromNewsRequest?.answer(at: CACurrentMediaTime())
            self.settleAnsweredRequest()
            // A light-joined channel has no chat-list entry to lose, so there is no confirmation.
            let _ = (context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: false)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                self?.presentBarToast(.removedFromNews, title: title)
                landed()
            })
        case .notify, .doNotNotify:
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            let mute = item == .doNotNotify
            self.muteRequest = NewsChannelBarRequest(kind: .setMuted(mute))
            self.muteRequest?.answer(at: CACurrentMediaTime())
            self.settleAnsweredRequest()
            // Explicit, not a toggle, so a repeated tap cannot flip it back. 0 is "unmuted", nil would be "default".
            let _ = (context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: mute ? Int32.max : 0)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                self?.presentBarToast(mute ? .notificationsOff : .notificationsOn, title: title)
                landed()
            })
        case .archive, .unarchive:
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            let archive = item == .archive
            let _ = (context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: archive ? .archive : .root)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                self?.presentBarToast(archive ? .archived : .unarchived, title: title)
                landed()
            })
        case .removeFromChats:
            self.haptic.impact(.light, intensity: NewsIslandMetrics.changeHapticIntensity)
            self.beginRemovalFromChats(context: context, peerId: peerId, title: title)
            landed()
        }
    }

    /// The island changes at once; the leave is sent when the toast commits, and Undo cancels it (spec §1.4).
    private func beginRemovalFromChats(context: AccountContext, peerId: EnginePeer.Id, title: String) {
        let removal = NewsDeferredAction(perform: { completion in
            let _ = (context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: false)
            |> deliverOnMainQueue).startStandalone(completed: {
                completion()
            })
        })
        self.pendingRemoval = removal
        self.relayoutPanel()
        self.presentBarToast(.removedFromChats, title: title, undo: { [weak self] in
            guard removal.cancel(), let self, self.pendingRemoval === removal else {
                return
            }
            self.pendingRemoval = nil
            self.relayoutPanel()
        }, commit: {
            removal.commit()
        })
    }

    /// One toast at a time: a newer one commits the previous (its deferred leave goes now).
    private func presentBarToast(_ toast: NewsChannelToast, title: String, undo: (() -> Void)? = nil, commit: (() -> Void)? = nil) {
        guard let context = self.context else {
            return
        }
        self.barToast?.dismissWithCommitAction()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        let text: String
        switch toast {
        case .addedToNews:
            text = strings.Channel_Toast_AddedToNews(title).string
        case .addedToChats:
            text = strings.Channel_Toast_AddedToChats(title).string
        case .removedFromNews:
            text = strings.Channel_Toast_RemovedFromNews(title).string
        case .removedFromChats:
            text = strings.Channel_Toast_RemovedFromChats(title).string
        case .notificationsOn:
            text = strings.Channel_Toast_NotificationsOn
        case .notificationsOff:
            text = strings.Channel_Toast_NotificationsOff
        case .archived:
            text = strings.Channel_Toast_Archived(title).string
        case .unarchived:
            text = strings.Channel_Toast_Unarchived(title).string
        }
        let icon = generateTintedImage(image: UIImage(bundleImageName: toast.iconName), color: .white) ?? UIImage()
        let controller = UndoOverlayController(presentationData: presentationData, content: .universalImage(image: icon, size: CGSize(width: 30.0, height: 30.0), title: nil, text: text, customUndoText: toast.hasUndo ? strings.Undo_Undo : nil, timeout: toast.timeout), elevatedLayout: true, action: { action in
            switch action {
            case .undo:
                undo?()
            case .commit:
                commit?()
            default:
                break
            }
            return true
        })
        self.barToast = controller
        self.interfaceInteraction?.presentController(controller, nil)
    }

    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, transition: transition, interfaceState: interfaceState, metrics: metrics, deviceMetrics: deviceMetrics, force: false)
    }
    
    private var displayedGiftOrSuggestTooltip = false
    private func presentGiftOrSuggestTooltip() {
        guard let context = self.context, !self.displayedGiftOrSuggestTooltip, let parentController = self.interfaceInteraction?.chatController() else {
            return
        }
        self.displayedGiftOrSuggestTooltip = true

        let _ = (combineLatest(queue: .mainQueue(),
            ApplicationSpecificNotice.getChannelSendGiftTooltip(accountManager: context.sharedContext.accountManager),
            ApplicationSpecificNotice.getChannelSuggestTooltip(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue)).start(next: { [weak self] giftCount, suggestCount in
            guard let self else {
                return
            }
            
            /*#if DEBUG
            var giftCount = giftCount
            var suggestCount = suggestCount
            if "".isEmpty {
                giftCount = 2
                suggestCount = 0
            }
            #endif*/
            
            let giftItemView = (self.panel.view as? GlassControlPanelComponent.View)?.leftItemView?.itemView(id: AnyHashable("gift"))
            let suggestPostItemView = (self.panel.view as? GlassControlPanelComponent.View)?.leftItemView?.itemView(id: AnyHashable("suggestPost"))
            
            if giftCount < 2, let giftItemView {
                let _ = ApplicationSpecificNotice.incrementChannelSendGiftTooltip(accountManager: context.sharedContext.accountManager).start()
                
                Queue.mainQueue().after(0.4, { [weak giftItemView] in
                    guard let giftItemView else {
                        return
                    }
                    let absoluteFrame = giftItemView.convert(giftItemView.bounds, to: parentController.view)
                    let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY), size: CGSize())
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let text: String = presentationData.strings.Chat_SendGiftTooltip
                    
                    let tooltipController = TooltipScreen(
                        account: context.account,
                        sharedContext: context.sharedContext,
                        text: .plain(text: text),
                        balancedTextLayout: false,
                        style: .wide,
                        arrowStyle: .small,
                        icon: nil,
                        location: .point(location, .bottom),
                        displayDuration: .default,
                        inset: 8.0,
                        shouldDismissOnTouch: { _, _ in
                            return .ignore
                        }
                    )
                    self.interfaceInteraction?.presentControllerInCurrent(tooltipController, nil)
                })
            } else if suggestCount < 2, let suggestPostItemView {
                let _ = ApplicationSpecificNotice.incrementChannelSuggestTooltip(accountManager: context.sharedContext.accountManager).start()
                
                Queue.mainQueue().after(0.4, { [weak suggestPostItemView] in
                    guard let suggestPostItemView else {
                        return
                    }
                    let absoluteFrame = suggestPostItemView.convert(suggestPostItemView.bounds, to: parentController.view)
                    let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY), size: CGSize())
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let _ = presentationData
                    let text: String = presentationData.strings.Chat_ChannelMessagesHint
                    
                    let tooltipController = TooltipScreen(
                        account: context.account,
                        sharedContext: context.sharedContext,
                        text: .plain(text: text),
                        textBadge: presentationData.strings.Chat_ChannelMessagesHintBadge.isEmpty ? nil : presentationData.strings.Chat_ChannelMessagesHintBadge,
                        balancedTextLayout: false,
                        style: .wide,
                        arrowStyle: .small,
                        icon: nil,
                        location: .point(location, .bottom),
                        displayDuration: .default,
                        inset: 8.0,
                        shouldDismissOnTouch: { _, _ in
                            return .ignore
                        }
                    )
                    self.interfaceInteraction?.presentControllerInCurrent(tooltipController, nil)
                })
            }
        })
    }
    
    private func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, force: Bool) -> CGFloat {
        let isFirstTime = self.layoutData == nil
        self.layoutData = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, maxOverlayHeight, isSecondary, metrics, deviceMetrics)
        
        var transition = transition
        if !isFirstTime && !transition.isAnimated {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        
        self.presentationInterfaceState = interfaceState
        
        // A committed removal stops being pending once the channel shows it.
        if let pendingRemoval = self.pendingRemoval, pendingRemoval.state == .done, let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.participationStatus != .member {
            self.pendingRemoval = nil
        }
        // So do an answered Add to News and Add to Chats.
        if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel {
            let participation: NewsChannelParticipation
            switch channel.participationStatus {
            case .member:
                participation = .member
            case .left:
                participation = .left
            case .kicked:
                participation = .kicked
            }
            let isInNews = channel.flags.contains(.isInNews)
            let now = CACurrentMediaTime()
            let isMuted = interfaceState.peerIsMuted
            if let request = self.addToNewsRequest, !request.isPending(isInNews: isInNews, participation: participation, isMuted: isMuted, now: now) {
                self.addToNewsRequest = nil
            }
            if let request = self.addToChatsRequest, !request.isPending(isInNews: isInNews, participation: participation, isMuted: isMuted, now: now) {
                self.addToChatsRequest = nil
            }
            if let request = self.removeFromNewsRequest, !request.isPending(isInNews: isInNews, participation: participation, isMuted: isMuted, now: now) {
                self.removeFromNewsRequest = nil
            }
            if let request = self.muteRequest, !request.isPending(isInNews: isInNews, participation: participation, isMuted: isMuted, now: now) {
                self.muteRequest = nil
            }
        }
        
        var centerAction: (title: String, isAccent: Bool)?
        if let context = self.context, let peer = interfaceState.renderedPeer?.peer, let action = actionForPeer(context: context, peer: EnginePeer(peer), interfaceState: interfaceState, isJoining: self.isJoining, pending: self.pending, isMuted: interfaceState.peerIsMuted) {
            self.action = action
            let (title, _) = titleAndColorForAction(action, theme: interfaceState.theme, strings: interfaceState.strings)
            
            var isAccent = false
            switch self.action {
            case .join, .joinGroup, .applyToJoin, .addToNews:
                isAccent = true
            default:
                break
            }
            centerAction = (title, isAccent)
        }
        
        let islandContent: NewsChannelIslandView.Content?
        switch self.action {
        case .addToNews:
            islandContent = .addToNews
        case .addedToNews:
            islandContent = .addedToNews
        case let .addedToChats(muted):
            islandContent = .addedToChats(muted: muted)
        default:
            islandContent = nil
        }
        
        var displayGift = false
        var displaySuggestPost = false
        var displayHelp = false
        
        if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel {
            if case .broadcast = peer.info, interfaceState.starGiftsAvailable {
                displayGift = true
            }
            if case let .broadcast(broadcastInfo) = peer.info, broadcastInfo.flags.contains(.hasMonoforum) {
                displaySuggestPost = true
            }
            if peer.flags.contains(.isGigagroup), self.action == .muteNotifications || self.action == .unmuteNotifications {
                displayHelp = true
            }
        }
        
        var leftInset = leftInset + 8.0
        var rightInset = rightInset + 8.0
        let compactBottomSideInset = self.compactBottomSideInset(bottomInset: bottomInset, deviceMetrics: deviceMetrics)
        leftInset += compactBottomSideInset
        rightInset += compactBottomSideInset
        
        var leftPanelItems: [GlassControlGroupComponent.Item] = []
        if displaySuggestPost {
            leftPanelItems.append(GlassControlGroupComponent.Item(
                id: "suggestPost",
                content: .icon("Chat/Input/Accessory Panels/SuggestPost"),
                action: { [weak self] in
                    self?.suggestedPostPressed()
                }
            ))
        }
        if displayGift {
            leftPanelItems.append(GlassControlGroupComponent.Item(
                id: "gift",
                content: .icon("Chat/Input/Accessory Panels/Gift"),
                action: { [weak self] in
                    self?.giftPressed()
                }
            ))
        }
        if displayHelp {
            leftPanelItems.append(GlassControlGroupComponent.Item(
                id: "help",
                content: .icon("Chat/Input/Accessory Panels/Help"),
                action: { [weak self] in
                    self?.helpPressed()
                }
            ))
        }
        
        var centerPanelItem: GlassControlPanelComponent.Item?
        if let centerAction, islandContent == nil {
            let centerItems: [GlassControlGroupComponent.Item] = [
                GlassControlGroupComponent.Item(id: 0, content: .text(centerAction.title), action: { [weak self] in
                    self?.buttonPressed()
                })
            ]
            centerPanelItem = GlassControlPanelComponent.Item(
                items: centerItems,
                background: centerAction.isAccent ? .activeTint(inset: true) : .panel,
                keepWide: true,
                minWidth: centerAction.isAccent ? 166.0 : nil,
                textHorizontalInset: centerAction.isAccent ? 19.0 : 10.0
            )
        }
        
        var rightPanelItems: [GlassControlGroupComponent.Item] = []
        if !canJoinInaccessibleCommunityChat(interfaceState) {
            rightPanelItems.append(GlassControlGroupComponent.Item(
                id: "search",
                content: .icon("Chat List/SearchIcon"),
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.beginMessageSearch(.everything, "")
                }
            ))
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        let _ = isFirstTime
        let panelFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: width - leftInset - rightInset, height: panelHeight))
        
        let _ = self.panel.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(GlassControlPanelComponent(
                theme: interfaceState.theme,
                preferClearGlass: interfaceState.preferredGlassType == .clear,
                leftItem: leftPanelItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                    items: leftPanelItems,
                    background: .panel
                ),
                centralItem: centerPanelItem,
                rightItem: rightPanelItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                    items: rightPanelItems,
                    background: .panel
                )
            )),
            environment: {},
            containerSize: panelFrame.size
        )
        if let panelView = self.panel.view {
            if panelView.superview == nil {
                self.panelContainer.addSubview(panelView)
            }
            transition.updateFrame(view: self.panelContainer, frame: panelFrame)
            transition.updateFrame(view: panelView, frame: CGRect(origin: CGPoint(), size: panelFrame.size))
        }
        
        if let islandContent {
            let islandView: NewsChannelIslandView
            if let current = self.islandView {
                islandView = current
            } else {
                islandView = NewsChannelIslandView(frame: CGRect())
                islandView.action = { [weak self] in
                    self?.buttonPressed()
                }
                self.islandView = islandView
                self.view.addSubview(islandView)
            }
            transition.updateFrame(view: islandView, frame: panelFrame)
            // The room between the side buttons, in the panel's coordinates (the island's frame is the panel's).
            var leftLimit: CGFloat = 0.0
            var rightLimit: CGFloat = panelFrame.width
            if let panelComponentView = self.panel.view as? GlassControlPanelComponent.View {
                if let leftView = panelComponentView.leftItemView {
                    leftLimit = leftView.convert(leftView.bounds, to: panelComponentView).maxX + NewsIslandMetrics.sideSpacing
                }
                if let rightView = panelComponentView.rightItemView {
                    rightLimit = rightView.convert(rightView.bounds, to: panelComponentView).minX - NewsIslandMetrics.sideSpacing
                }
            }
            islandView.update(
                content: islandContent,
                labels: NewsChannelIslandView.Labels(addToNews: interfaceState.strings.Channel_AddToNews, addedToNews: interfaceState.strings.Channel_AddedToNews, addedToChats: interfaceState.strings.Channel_AddedToChats, menuHint: interfaceState.strings.Channel_IslandMenuHint),
                theme: interfaceState.theme,
                preferClearGlass: interfaceState.preferredGlassType == .clear,
                leftLimit: leftLimit,
                rightLimit: rightLimit,
                animated: !self.islandAppliesChangesImmediately
            )
        } else if let islandView = self.islandView {
            self.islandView = nil
            islandView.removeFromSuperview()
        }
        
        return panelHeight
    }
    
    override public func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
