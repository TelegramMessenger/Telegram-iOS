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

private enum SubscriberAction: Equatable {
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
    private let button: HighlightableButtonNode
    private let discussButton: HighlightableButtonNode
    private let discussButtonText: ImmediateTextNode
    private let badgeBackground: ASImageNode
    private let badgeText: ImmediateTextNode
    private let activityIndicator: UIActivityIndicatorView
    
    private let helpButton: HighlightableButtonNode
    private let giftButton: HighlightableButtonNode
    private let suggestedPostButton: HighlightableButtonNode
    
    private var action: SubscriberAction?
    
    private let actionDisposable = MetaDisposable()
    private let badgeDisposable = MetaDisposable()
    private var isJoining: Bool = false
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var layoutData: (CGFloat, CGFloat, CGFloat, CGFloat, UIEdgeInsets, CGFloat, Bool, LayoutMetrics)?
    
    public override init() {
        self.button = HighlightableButtonNode()
        self.discussButton = HighlightableButtonNode()
        self.activityIndicator = UIActivityIndicatorView(style: .medium)
        self.activityIndicator.isHidden = true
        
        self.discussButtonText = ImmediateTextNode()
        self.discussButtonText.displaysAsynchronously = false
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        self.badgeBackground.isHidden = true
        
        self.badgeText = ImmediateTextNode()
        self.badgeText.displaysAsynchronously = false
        self.badgeText.isHidden = true
        
        self.helpButton = HighlightableButtonNode()
        self.helpButton.isHidden = true
        self.giftButton = HighlightableButtonNode()
        self.giftButton.isHidden = true
        self.suggestedPostButton = HighlightableButtonNode()
        self.suggestedPostButton.isHidden = true
        
        self.discussButton.addSubnode(self.discussButtonText)
        self.discussButton.addSubnode(self.badgeBackground)
        self.discussButton.addSubnode(self.badgeText)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.button)
        self.addSubnode(self.discussButton)
        self.view.addSubview(self.activityIndicator)
        self.addSubnode(self.helpButton)
        self.addSubnode(self.giftButton)
        self.addSubnode(self.suggestedPostButton)
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.discussButton.addTarget(self, action: #selector(self.discussPressed), forControlEvents: .touchUpInside)
        self.helpButton.addTarget(self, action: #selector(self.helpPressed), forControlEvents: .touchUpInside)
        self.giftButton.addTarget(self, action: #selector(self.giftPressed), forControlEvents: .touchUpInside)
        self.suggestedPostButton.addTarget(self, action: #selector(self.suggestedPostPressed), forControlEvents: .touchUpInside)
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
            var delayActivity = false
            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                delayActivity = true
            }
            
            if delayActivity {
                Queue.mainQueue().after(1.5) {
                    if self.isJoining {
                        self.activityIndicator.isHidden = false
                        self.activityIndicator.startAnimating()
                    }
                }
            } else {
                self.activityIndicator.isHidden = false
                self.activityIndicator.startAnimating()
            }
            
            self.isJoining = true
            if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, isSecondary, metrics) = self.layoutData, let presentationInterfaceState = self.presentationInterfaceState {
                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset,  additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics, force: true)
            }
            self.actionDisposable.set((context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peer.id, hash: nil)
            |> afterDisposed { [weak self] in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.activityIndicator.isHidden = true
                        strongSelf.activityIndicator.stopAnimating()
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
    
    @objc private func discussPressed() {
        if let presentationInterfaceState = self.presentationInterfaceState, let peerDiscussionId = presentationInterfaceState.peerDiscussionId {
            self.interfaceInteraction?.navigateToChat(peerDiscussionId)
        }
    }
    
    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: transition, interfaceState: interfaceState, metrics: metrics, force: false)
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
            
            if giftCount < 2 && !self.giftButton.isHidden {
                let _ = ApplicationSpecificNotice.incrementChannelSendGiftTooltip(accountManager: context.sharedContext.accountManager).start()
                
                Queue.mainQueue().after(0.4, {
                    let absoluteFrame = self.giftButton.view.convert(self.giftButton.bounds, to: parentController.view)
                    let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY + 11.0), size: CGSize())
                    
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
            } else if suggestCount < 2 && !self.suggestedPostButton.isHidden {
                let _ = ApplicationSpecificNotice.incrementChannelSuggestTooltip(accountManager: context.sharedContext.accountManager).start()
                
                Queue.mainQueue().after(0.4, {
                    let absoluteFrame = self.suggestedPostButton.view.convert(self.suggestedPostButton.bounds, to: parentController.view)
                    let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY + 11.0), size: CGSize())
                    
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
    
    private func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, force: Bool) -> CGFloat {
        let isFirstTime = self.layoutData == nil
        self.layoutData = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, isSecondary, metrics)
        
        if self.presentationInterfaceState != interfaceState || force {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            if previousState?.theme !== interfaceState.theme {
                self.badgeBackground.image = PresentationResourcesChatList.badgeBackgroundActive(interfaceState.theme, diameter: 20.0)
                self.helpButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/Help"), color: interfaceState.theme.chat.inputPanel.panelControlAccentColor), for: .normal)
                self.suggestedPostButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/SuggestPost"), color: interfaceState.theme.chat.inputPanel.panelControlAccentColor), for: .normal)
                self.giftButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/Gift"), color: interfaceState.theme.chat.inputPanel.panelControlAccentColor), for: .normal)
            }
            
            if let context = self.context, let peer = interfaceState.renderedPeer?.peer, previousState?.renderedPeer?.peer == nil || !peer.isEqual(previousState!.renderedPeer!.peer!) || previousState?.theme !== interfaceState.theme || previousState?.strings !== interfaceState.strings || previousState?.peerIsMuted != interfaceState.peerIsMuted || previousState?.pinnedMessage != interfaceState.pinnedMessage || force {
                
                if let action = actionForPeer(context: context, peer: peer, interfaceState: interfaceState, isJoining: self.isJoining, isMuted: interfaceState.peerIsMuted) {
                    let previousAction = self.action
                    self.action = action
                    let (title, color) = titleAndColorForAction(action, theme: interfaceState.theme, strings: interfaceState.strings)
                    
                    var offset: CGFloat = 30.0
                    
                    if let previousAction = previousAction, [.join, .muteNotifications].contains(previousAction) && action == .unmuteNotifications || [.join, .unmuteNotifications].contains(previousAction) && action == .muteNotifications {
                        if [.join, .muteNotifications].contains(previousAction) {
                            offset *= -1.0
                        }
                        if let snapshotView = self.button.view.snapshotContentTree() {
                            snapshotView.frame = self.button.frame
                            self.button.supernode?.view.addSubview(snapshotView)
                            
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.2,  removeOnCompletion: false, additive: true)
                            self.button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            self.button.layer.animatePosition(from: CGPoint(x: 0.0, y: -offset), to: CGPoint(), duration: 0.2, additive: true)
                        }
                    }
                    
                    self.button.setTitle(title, with: Font.regular(17.0), with: color, for: [])
                    self.button.accessibilityLabel = title
                } else {
                    self.action = nil
                }
                
                self.discussButton.isHidden = true
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        if self.discussButton.isHidden {
            if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel {
                if case let .broadcast(broadcastInfo) = peer.info, interfaceState.starGiftsAvailable {
                    if self.giftButton.isHidden && !isFirstTime {
                        self.giftButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        self.giftButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    }
                    
                    self.giftButton.isHidden = false
                    self.helpButton.isHidden = true
                    self.suggestedPostButton.isHidden = !broadcastInfo.flags.contains(.hasMonoforum)
                    self.presentGiftOrSuggestTooltip()
                } else if case let .broadcast(broadcastInfo) = peer.info, broadcastInfo.flags.contains(.hasMonoforum) {
                    self.giftButton.isHidden = true
                    self.helpButton.isHidden = true
                    self.suggestedPostButton.isHidden = false
                    self.presentGiftOrSuggestTooltip()
                } else if peer.flags.contains(.isGigagroup), self.action == .muteNotifications || self.action == .unmuteNotifications {
                    self.giftButton.isHidden = true
                    self.helpButton.isHidden = false
                    self.suggestedPostButton.isHidden = true
                } else {
                    self.giftButton.isHidden = true
                    self.helpButton.isHidden = true
                    self.suggestedPostButton.isHidden = true
                }
            } else {
                self.giftButton.isHidden = true
                self.helpButton.isHidden = true
                self.suggestedPostButton.isHidden = true
            }
            if let action = self.action, action == .muteNotifications || action == .unmuteNotifications {
                let buttonWidth = self.button.calculateSizeThatFits(CGSize(width: width, height: panelHeight)).width + 24.0
                self.button.frame = CGRect(origin: CGPoint(x: floor((width - buttonWidth) / 2.0), y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
            } else {
                self.button.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: width - leftInset - rightInset, height: panelHeight))
            }
            self.giftButton.frame = CGRect(x: width - rightInset - panelHeight - 5.0, y: 0.0, width: panelHeight, height: panelHeight)
            self.helpButton.frame = CGRect(x: width - rightInset - panelHeight, y: 0.0, width: panelHeight, height: panelHeight)
            self.suggestedPostButton.frame = CGRect(x: leftInset + 5.0, y: 0.0, width: panelHeight, height: panelHeight)
        } else {
            self.giftButton.isHidden = true
            self.helpButton.isHidden = true
            self.suggestedPostButton.isHidden = true
                        
            let availableWidth = min(600.0, width - leftInset - rightInset)
            let leftOffset = floor((width - availableWidth) / 2.0)
            self.button.frame = CGRect(origin: CGPoint(x: leftOffset, y: 0.0), size: CGSize(width: floor(availableWidth / 2.0), height: panelHeight))
            self.discussButton.frame = CGRect(origin: CGPoint(x: leftOffset + floor(availableWidth / 2.0), y: 0.0), size: CGSize(width: floor(availableWidth / 2.0), height: panelHeight))
            
            let discussButtonSize = self.discussButton.bounds.size
            let discussTextSize = self.discussButtonText.updateLayout(discussButtonSize)
            self.discussButtonText.frame = CGRect(origin: CGPoint(x: floor((discussButtonSize.width - discussTextSize.width) / 2.0), y: floor((discussButtonSize.height - discussTextSize.height) / 2.0)), size: discussTextSize)
            
            let badgeOffset = self.discussButtonText.frame.maxX + 5.0 - self.badgeBackground.frame.minX
            self.badgeBackground.frame = self.badgeBackground.frame.offsetBy(dx: badgeOffset, dy: 0.0)
            self.badgeText.frame = self.badgeText.frame.offsetBy(dx: badgeOffset, dy: 0.0)
        }
        
        let indicatorSize = self.activityIndicator.bounds.size
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - rightInset - indicatorSize.width - 12.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
    
    override public func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
