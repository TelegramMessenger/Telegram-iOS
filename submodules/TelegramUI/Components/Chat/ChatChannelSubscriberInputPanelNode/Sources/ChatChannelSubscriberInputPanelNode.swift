import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
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
    }
}

private func actionForPeer(context: AccountContext, peer: Peer, interfaceState: ChatPresentationInterfaceState, isJoining: Bool, isMuted: Bool) -> SubscriberAction? {
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
        if let channel = peer as? TelegramChannel {
            canManagePin = channel.hasPermission(.pinMessages)
        } else if let group = peer as? TelegramGroup {
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
        } else if let _ = peer as? TelegramUser, interfaceState.explicitelyCanPinMessages {
            canManagePin = true
        }
        if canManagePin {
            return .unpinMessages(max(1, interfaceState.pinnedMessage?.totalCount ?? 1))
        } else {
            return .hidePinnedMessages
        }
    } else {
        if let channel = peer as? TelegramChannel {
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
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var layoutData: (CGFloat, CGFloat, CGFloat, CGFloat, UIEdgeInsets, CGFloat, CGFloat, Bool, LayoutMetrics)?
    
    public override init() {
        super.init()
        
        self.view.addSubview(self.panelContainer)
    }
    
    deinit {
        self.actionDisposable.dispose()
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
    
    @objc private func buttonPressed() {
        guard let context = self.context, let action = self.action, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        switch action {
        case .join, .joinGroup, .applyToJoin:
            self.isJoining = true
            if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, maxOverlayHeight, isSecondary, metrics) = self.layoutData, let presentationInterfaceState = self.presentationInterfaceState {
                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics, force: true)
            }
            self.actionDisposable.set((context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peer.id, hash: nil)
            |> afterDisposed { [weak self] in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.isJoining = false
                    }
                }
            }).startStrict(error: { [weak self] error in
                guard let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer else {
                    return
                }
                let text: String
                switch error {
                case .inviteRequestSent:
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.interfaceInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationInterfaceState.strings.Group_RequestToJoinSent, text: presentationInterfaceState.strings.Group_RequestToJoinSentDescriptionGroup ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), nil)
                    return
                case .tooMuchJoined:
                    strongSelf.interfaceInteraction?.getNavigationController()?.pushViewController(oldChannelsController(context: context, intent: .join, completed: { value in
                        if value {
                            self?.buttonPressed()
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
                strongSelf.interfaceInteraction?.presentController(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationInterfaceState.strings.Common_OK, action: {})]), nil)
            }))
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
    
    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, transition: transition, interfaceState: interfaceState, metrics: metrics, force: false)
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
    
    private func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, force: Bool) -> CGFloat {
        let isFirstTime = self.layoutData == nil
        self.layoutData = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, maxOverlayHeight, isSecondary, metrics)
        
        var transition = transition
        if !isFirstTime && !transition.isAnimated {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        
        self.presentationInterfaceState = interfaceState
        
        var centerAction: (title: String, isAccent: Bool)?
        if let context = self.context, let peer = interfaceState.renderedPeer?.peer, let action = actionForPeer(context: context, peer: peer, interfaceState: interfaceState, isJoining: self.isJoining, isMuted: interfaceState.peerIsMuted) {
            self.action = action
            let (title, _) = titleAndColorForAction(action, theme: interfaceState.theme, strings: interfaceState.strings)
            
            var isAccent = false
            switch self.action {
            case .join, .joinGroup, .applyToJoin:
                isAccent = true
            default:
                break
            }
            centerAction = (title, isAccent)
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
        if bottomInset <= 32.0 {
            leftInset += 18.0
            rightInset += 18.0
        }
        
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
        if let centerAction {
            centerPanelItem = GlassControlPanelComponent.Item(
                items: [GlassControlGroupComponent.Item(
                    id: 0,
                    content: .text(centerAction.title),
                    action: { [weak self] in
                        self?.buttonPressed()
                    }
                )],
                background: centerAction.isAccent ? .activeTint : .panel,
                keepWide: true
            )
        }
        
        var rightPanelItems: [GlassControlGroupComponent.Item] = []
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
        
        return panelHeight
    }
    
    override public func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
