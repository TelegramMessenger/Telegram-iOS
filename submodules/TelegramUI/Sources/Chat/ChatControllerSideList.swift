import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatSideListPanel
import ChatListUI
import ChatControllerInteraction
import SwiftSignalKit
import ContextUI
import ForumCreateTopicScreen
import NavigationBarNode

extension ChatControllerImpl {
    func currentSideListKind(presentationInterfaceState: ChatPresentationInterfaceState) -> ChatSideListKind? {
        return chatSideListKindForChatPresentationInterfaceState(presentationInterfaceState, context: self.context)
    }

    /// The chat's whole layout, the side list's included.
    private var sideListLayout: ContainerViewLayout? {
        return self.sideListFullLayout ?? self.validLayout
    }

    /// The side list is a column beside the chat (`ChatSideListPanelNode.isDocked`).
    var isSideListDocked: Bool {
        guard let layout = self.sideListLayout else {
            return false
        }
        return ChatSideListPanelNode.isDocked(layout)
    }

    /// The docked column narrows the chat (`ChatSideListPanelNode.narrowsChat`); the chat stays in use beside it.
    var sideListNarrowsChat: Bool {
        guard let layout = self.sideListLayout else {
            return false
        }
        return ChatSideListPanelNode.narrowsChat(layout)
    }

    /// The chat's own layout: narrowed by as much of a docked side list as is out.
    func sideListDockedChatLayout(_ layout: ContainerViewLayout) -> ContainerViewLayout {
        guard self.sideListPanel != nil, self.sideListOpenFraction > 0.0, ChatSideListPanelNode.narrowsChat(layout) else {
            return layout
        }
        let width = ChatSideListPanelNode.dockedWidth(layout) * min(1.0, self.sideListOpenFraction)
        var safeInsets = layout.safeInsets
        safeInsets.right = max(0.0, safeInsets.right - width)
        var intrinsicInsets = layout.intrinsicInsets
        intrinsicInsets.right = max(0.0, intrinsicInsets.right - width)
        return ContainerViewLayout(
            size: CGSize(width: layout.size.width - width, height: layout.size.height),
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            reservedCorners: layout.reservedCorners,
            division: layout.division,
            additionalInsets: layout.additionalInsets,
            statusBarHeight: layout.statusBarHeight,
            inputHeight: layout.inputHeight,
            inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging,
            inVoiceOver: layout.inVoiceOver,
            presentedInFormSheet: layout.presentedInFormSheet
        )
    }

    /// Gives the list the open chat's row to highlight, as on iPad's master list. Saved Messages and direct-messages rows
    /// are keyed by the thread's peer; topics' and bot threads' rows match the open thread
    /// (`ChatListSideListHighlightKey.thread`).
    private func updateSideListHighlight(panel: ChatSideListPanelNode) {
        var highlightedLocation: ChatLocation?
        switch panel.kind {
        case .savedMessages, .monoforum:
            if let threadId = self.chatLocation.threadId {
                highlightedLocation = .peer(id: EnginePeer.Id(threadId))
            }
        case .botThreads, .forum:
            if case .replyThread = self.chatLocation {
                highlightedLocation = self.chatLocation
            }
        }
        if panel.highlightedLocation != highlightedLocation {
            panel.highlightedLocation = highlightedLocation
            panel.listController.updateNavigationCustomData(highlightedLocation, progress: 1.0, transition: .immediate)
        }
    }

    /// `initialVelocity` is the finger's speed over the distance left to go, so a released drag carries on.
    private static func sideListTransition(initialVelocity: CGFloat = 0.0) -> ContainedViewLayoutTransition {
        return .animated(duration: 0.42, curve: .customSpring(damping: 110.0, initialVelocity: initialVelocity))
    }

    func toggleSideList() {
        if self.sideListOpenFraction > 0.0 {
            self.closeSideList(animated: true)
        } else {
            self.openSideList()
        }
    }

    /// The panel for the chat's side list, made and laid out closed if there is none yet.
    @discardableResult
    func ensureSideListPanel() -> ChatSideListPanelNode? {
        guard let kind = self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState), self.validLayout != nil else {
            return nil
        }
        if let sideListPanel = self.sideListPanel, sideListPanel.kind != kind {
            self.removeSideListPanel()
        }
        let panel: ChatSideListPanelNode
        if let current = self.sideListPanel {
            panel = current
        } else {
            let listController = ChatListControllerImpl(context: self.context, location: kind.listLocation, controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: false, enableDebugActions: false, isSideList: true)
            self.addChild(listController)
            var showsNewTopicButton = kind.showsNewTopicButton
            if case .forum = kind {
                showsNewTopicButton = (self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel)?.hasPermission(.createTopics) ?? false
            }
            panel = ChatSideListPanelNode(kind: kind, listController: listController, presentationData: self.presentationData, showsNewTopicButton: showsNewTopicButton)
            panel.requestClose = { [weak self] in
                self?.closeSideList(animated: true)
            }
            panel.dragBegan = { [weak self] in
                self?.catchSideListInFlight()
            }
            panel.dragUpdated = { [weak self] fraction in
                self?.setSideListOpenFraction(fraction, transition: .immediate)
            }
            panel.dragEnded = { [weak self] remainsOpen, velocity in
                guard let self else {
                    return
                }
                if remainsOpen {
                    self.setSideListOpenFraction(1.0, transition: ChatControllerImpl.sideListTransition(initialVelocity: self.sideListInitialVelocity(velocity, targetFraction: 1.0)))
                } else {
                    self.closeSideList(animated: true, velocity: velocity)
                }
            }
            if case .savedMessages = kind {
            } else {
                listController.sideListMoreAction = { [weak self] sourceView, gesture in
                    self?.openSideListMoreMenu(sourceView: sourceView, gesture: gesture)
                }
            }
            listController.interceptPeerSelection = { [weak self] peerId, threadId, messageId in
                return self?.handleSideListSelection(peerId: peerId, threadId: threadId, messageId: messageId) ?? false
            }
            panel.newTopic = { [weak self] in
                guard let self else {
                    return
                }
                switch kind {
                case let .forum(peerId):
                    self.openSideListCreateTopic(peerId: peerId)
                default:
                    // A bot's new thread starts from its root chat, as the topics strip's "all" item does.
                    self.closeSideList(animated: true)
                    self.updateChatLocationThread(threadId: nil)
                }
            }
            self.sideListPanel = panel
            self.chatDisplayNode.insertSubnode(panel.backgroundNode, at: 0)
            self.chatDisplayNode.addSubnode(panel)
            listController.didMove(toParent: self)
            // Lay it out closed first, so the opening animates in from the right edge.
            self.setSideListOpenFraction(0.0, transition: .immediate)
        }
        return panel
    }

    /// Opens the list, from wherever it is (closed, or part of the way out under a finger). `velocity` is a released
    /// drag's, in points per second.
    func openSideList(velocity: CGFloat = 0.0) {
        guard let panel = self.ensureSideListPanel() else {
            return
        }
        // Beside the list, the chat stays in use.
        if !self.sideListNarrowsChat {
            self.chatDisplayNode.dismissInput()
        }
        self.updateSideListHighlight(panel: panel)
        let wasOpen = self.sideListAppeared
        if !wasOpen {
            self.sideListAppeared = true
            panel.listController.viewWillAppear(true)
            // A list opened again goes back to its top, its search shown rather than scrolled under the header. A new
            // one is laid out there already: scrolling it would slide its search in from under the header.
            if panel.hasBeenOpened {
                panel.listController.scrollToTop?()
            }
            panel.hasBeenOpened = true
        }
        self.setSideListOpenFraction(1.0, transition: ChatControllerImpl.sideListTransition(initialVelocity: self.sideListInitialVelocity(velocity, targetFraction: 1.0)), completion: { [weak panel] in
            if !wasOpen {
                panel?.listController.viewDidAppear(true)
            }
        })
    }

    func closeSideList(animated: Bool, velocity: CGFloat = 0.0) {
        guard let panel = self.sideListPanel, self.sideListOpenFraction > 0.0 else {
            return
        }
        // A pop may still be running, or its glass animating, above the list's header, and would stay behind as it leaves.
        self.effectiveNavigationController?.endNavigationBarTransitionNow()
        let wasOpen = self.sideListAppeared
        self.sideListAppeared = false
        if wasOpen {
            panel.listController.viewWillDisappear(animated)
        }
        self.setSideListOpenFraction(0.0, transition: animated ? ChatControllerImpl.sideListTransition(initialVelocity: self.sideListInitialVelocity(velocity, targetFraction: 0.0)) : .immediate, completion: { [weak panel] in
            if wasOpen {
                panel?.listController.viewDidDisappear(animated)
            }
        })
    }

    /// The distance the list moves between closed and open.
    private var sideListTravel: CGFloat {
        guard let layout = self.sideListLayout else {
            return 1.0
        }
        if ChatSideListPanelNode.isDocked(layout) {
            return ChatSideListPanelNode.dockedWidth(layout)
        }
        return max(1.0, layout.size.width - ChatSideListPanelNode.stripWidth)
    }

    private func sideListInitialVelocity(_ velocity: CGFloat, targetFraction: CGFloat) -> CGFloat {
        let distance = abs(targetFraction - self.sideListOpenFraction) * self.sideListTravel
        return distance > 1.0 ? min(abs(velocity) / distance, 30.0) : 0.0
    }

    /// A drag caught the list while it slides: it goes on from where the chat is on screen.
    func catchSideListInFlight() {
        self.effectiveNavigationController?.endNavigationBarTransitionNow()
        guard let presentationFrame = self.chatDisplayNode.wrappingNode.layer.presentation()?.frame else {
            return
        }
        let fraction = max(0.0, -presentationFrame.minX / self.sideListTravel)
        self.chatDisplayNode.removeSideListAnimations()
        self.sideListPanel?.removeLayoutAnimations()
        self.setSideListOpenFraction(fraction, transition: .immediate)
    }

    /// A drag from the chat's right edge brings the list out under the finger.
    private func attachSideListEdgePan() {
        guard self.sideListEdgePanHandler == nil, self.isNodeLoaded else {
            return
        }
        let handler = ChatSideListEdgePanHandler(controller: self)
        self.sideListEdgePanHandler = handler
        self.chatDisplayNode.view.addGestureRecognizer(handler.recognizer)
    }

    fileprivate func sideListEdgePanAllowed(at point: CGPoint) -> Bool {
        guard let layout = self.validLayout, self.sideListOpenFraction == 0.0, !self.isSideListDocked, self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState) != nil else {
            return false
        }
        // Not over the composer, whose controls reach the edge.
        if let inputPanelView = self.chatDisplayNode.textInputPanelNode?.view, inputPanelView.window != nil {
            let inputPanelFrame = inputPanelView.convert(inputPanelView.bounds, to: self.chatDisplayNode.view)
            if point.y >= inputPanelFrame.minY - 8.0 {
                return false
            }
        }
        return point.x >= layout.size.width - ChatSideListEdgePanHandler.edgeWidth
    }

    fileprivate func sideListEdgePanUpdated(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.chatDisplayNode.dismissInput()
            self.ensureSideListPanel()
        case .changed:
            guard self.sideListPanel != nil else {
                return
            }
            let translation = -recognizer.translation(in: self.chatDisplayNode.view).x
            self.setSideListOpenFraction(ChatSideListPanelNode.rubberBandedFraction(translation / self.sideListTravel), transition: .immediate)
        case .ended, .cancelled:
            guard self.sideListPanel != nil else {
                return
            }
            let velocity = recognizer.velocity(in: self.chatDisplayNode.view).x
            let isOpen = recognizer.state == .ended && ChatSideListPanelNode.remainsOpen(fraction: self.sideListOpenFraction, velocity: velocity)
            if isOpen {
                self.openSideList(velocity: velocity)
            } else {
                // The list never appeared: back to closed without the appearance calls.
                self.setSideListOpenFraction(0.0, transition: ChatControllerImpl.sideListTransition(initialVelocity: self.sideListInitialVelocity(velocity, targetFraction: 0.0)))
            }
        default:
            break
        }
    }

    enum SideListAppearance {
        case willAppear
        case didAppear
        case willDisappear
        case didDisappear
    }

    /// The chat's own appearance reaches the list only while the list is open; opening and closing send their own.
    func forwardSideListAppearance(_ appearance: SideListAppearance, animated: Bool) {
        guard let panel = self.sideListPanel, self.sideListAppeared else {
            return
        }
        switch appearance {
        case .willAppear:
            panel.listController.viewWillAppear(animated)
        case .didAppear:
            panel.listController.viewDidAppear(animated)
        case .willDisappear:
            panel.listController.viewWillDisappear(animated)
        case .didDisappear:
            panel.listController.viewDidDisappear(animated)
        }
    }

    /// The side list header's More menu, by the kind of chat it lists. Its avatar already opens the profile.
    private func openSideListMoreMenu(sourceView: UIView, gesture: ContextGesture?) {
        guard let panel = self.sideListPanel else {
            return
        }
        let kind = panel.kind
        let peerId = kind.parentPeerId
        let context = self.context
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak panel] peer, notificationSettings in
            guard let self, let panel, let peer else {
                return
            }
            let strings = self.presentationData.strings
            var isMuted = false
            if case .muted = notificationSettings.muteState {
                isMuted = true
            }

            var items: [ContextMenuItem] = []
            let muteItem: ContextMenuItem = .action(ContextMenuActionItem(text: isMuted ? strings.Conversation_Unmute : strings.Conversation_Mute, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: isMuted ? 0 : Int32.max).startStandalone()
            }))
            let selectItem: ContextMenuItem = .action(ContextMenuActionItem(text: strings.Common_Select, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
            }, action: { [weak panel] _, f in
                f(.default)
                panel?.listController.activateEdit()
            }))

            switch kind {
            case .savedMessages:
                return
            case .botThreads:
                items.append(muteItem)
                items.append(selectItem)
            case .monoforum:
                items.append(muteItem)
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.default)
                    let _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: false).startStandalone()
                })))
            case .forum:
                guard case let .channel(channel) = peer else {
                    return
                }
                items.append(.action(ContextMenuActionItem(text: strings.Chat_ContextViewAsTopics, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/List"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    self?.openSideListForumAsTopics(peerId: peerId)
                })))
                items.append(muteItem)
                if channel.hasPermission(.createTopics) {
                    items.append(.action(ContextMenuActionItem(text: strings.Chat_CreateTopic, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        self?.openSideListCreateTopic(peerId: peerId)
                    })))
                }
                if channel.hasPermission(.inviteMembers) {
                    items.append(.action(ContextMenuActionItem(text: strings.GroupInfo_AddParticipant, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        context.sharedContext.openAddPeerMembers(context: context, updatedPresentationData: self.updatedPresentationData, parentController: self, groupPeer: peer, selectAddMemberDisposable: MetaDisposable(), addMemberDisposable: MetaDisposable())
                    })))
                }
                items.append(selectItem)
            }

            let contextController = makeContextController(presentationData: self.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: self, sourceView: sourceView, insets: .zero)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            self.presentInGlobalOverlay(contextController)
        })
    }

    /// The forum leaves "view as messages": its topic list takes the chat's place.
    private func openSideListForumAsTopics(peerId: EnginePeer.Id) {
        let _ = self.context.engine.peers.updateForumViewAsMessages(peerId: peerId, value: false).startStandalone()
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        let listController = self.context.sharedContext.makeChatListController(context: self.context, location: .forum(peerId: peerId), controlsHistoryPreload: false, hideNetworkActivityStatus: false, previewing: false, enableDebugActions: false)
        navigationController.replaceController(self, with: listController, animated: false)
    }

    private func openSideListCreateTopic(peerId: EnginePeer.Id) {
        let controller = ForumCreateTopicScreen(context: self.context, peerId: peerId, mode: .create)
        controller.navigationPresentation = .modal
        controller.completion = { [weak self, weak controller] title, fileId, iconColor, _ in
            controller?.isInProgress = true
            controller?.view.endEditing(true)
            guard let self else {
                return
            }
            let _ = (self.context.engine.peers.createForumChannelTopic(id: peerId, title: title, iconColor: iconColor, iconFileId: fileId)
            |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] topicId in
                guard let self else {
                    return
                }
                self.closeSideList(animated: false)
                self.updateChatLocationThread(threadId: topicId)
                controller?.dismiss()
            }, error: { [weak controller] _ in
                controller?.isInProgress = false
            })
        }
        self.push(controller)
    }

    private func handleSideListSelection(peerId: EnginePeer.Id, threadId: Int64?, messageId: EngineMessage.Id?) -> Bool {
        guard let panel = self.sideListPanel else {
            return false
        }
        switch chatSideListSelection(kind: panel.kind, currentThreadId: self.chatLocation.threadId, selectedPeerId: peerId, selectedThreadId: threadId, messageId: messageId) {
        case .passThrough:
            return false
        case .closeOnly:
            // Beside the chat, the list stays, as a master list does.
            if !self.sideListNarrowsChat {
                self.closeSideList(animated: true)
            }
            return true
        case let .switchThread(threadId, messageId):
            if !self.sideListNarrowsChat {
                self.closeSideList(animated: true)
            }
            if threadId == self.chatLocation.threadId, let messageId {
                // `updateChatLocationThread` does nothing for the open thread.
                self.navigateToMessage(messageLocation: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), animated: true, forceInCurrentChat: true)
                return true
            }
            let subject: ChatControllerSubject? = messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false) }
            self.updateChatLocationThread(threadId: threadId, subject: subject)
            return true
        }
    }

    private func removeSideListPanel() {
        guard let panel = self.sideListPanel else {
            return
        }
        let wasOpen = self.sideListAppeared
        let narrowedChat = self.sideListNarrowsChat && self.sideListOpenFraction > 0.0
        self.sideListPanel = nil
        self.sideListOpenFraction = 0.0
        if narrowedChat {
            // The chat takes its whole width back; not from inside the layout pass this may be called from.
            DispatchQueue.main.async { [weak self] in
                guard let self, let layout = self.sideListFullLayout else {
                    return
                }
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
        self.sideListAppeared = false
        if wasOpen {
            panel.listController.viewWillDisappear(false)
            panel.listController.viewDidDisappear(false)
        }
        self.chatDisplayNode.updateSideListOffset(0.0, dimAlpha: 0.0, transition: .immediate)
        if let layout = self.sideListLayout {
            self.updateSideListHeaderButtonShift(layout: layout, transition: .immediate)
        }
        panel.listController.willMove(toParent: nil)
        panel.backgroundNode.removeFromSupernode()
        panel.removeFromSupernode()
        panel.listController.removeFromParent()
    }

    /// Over the strip the list leaves, the header's side list button moves into view (`headerButtonShift`).
    private func updateSideListHeaderButtonShift(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        guard let item = self.rightNavigationButton?.buttonItem, let capsule = (self.navigationBar as? NavigationBarNode)?.rightButtonCapsule(for: item) else {
            return
        }
        var shift: CGFloat = 0.0
        if self.sideListPanel != nil, !ChatSideListPanelNode.isDocked(layout) {
            shift = ChatSideListPanelNode.headerButtonShift(layout) * max(0.0, min(1.0, self.sideListOpenFraction))
        }
        transition.updateTransform(layer: capsule.container.layer, transform: CATransform3DMakeTranslation(shift, 0.0, 0.0))
    }

    func setSideListOpenFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.sideListOpenFraction = fraction
        if self.sideListNarrowsChat, let layout = self.sideListFullLayout {
            // The chat narrows or widens with the column: its whole layout follows (and lays the panel out).
            self.containerLayoutUpdated(layout, transition: transition)
            if case let .animated(duration, _) = transition {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: {
                    completion?()
                })
            } else {
                completion?()
            }
            return
        }
        self.updateSideListLayout(transition: transition, completion: completion)
    }

    func updateSideListLayout(transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.attachSideListEdgePan()
        guard let panel = self.sideListPanel, let layout = self.sideListLayout else {
            completion?()
            return
        }
        // The chat stopped being one with a side list (the killswitch, a width change): put it back.
        if self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState) != panel.kind {
            self.removeSideListPanel()
            completion?()
            return
        }
        if self.sideListAppeared {
            self.updateSideListHighlight(panel: panel)
        }
        self.updateSideListHeaderButtonShift(layout: layout, transition: transition)
        if ChatSideListPanelNode.isDocked(layout) {
            // Beside the chat, which its own layout narrows: nothing moves the chat aside or dims it.
            panel.backgroundNode.isHidden = true
            self.chatDisplayNode.updateSideListOffset(0.0, dimAlpha: 0.0, transition: transition, completion: {
                completion?()
            })
            transition.updateFrame(node: panel, frame: CGRect(origin: CGPoint(), size: layout.size))
            panel.updateLayout(layout: layout, openFraction: self.sideListOpenFraction, transition: transition)
            return
        }
        let offset = self.sideListOpenFraction * self.sideListTravel
        // The list's background shows only through the chat card's corners, from opening until fully closed.
        if self.sideListOpenFraction > 0.0 {
            panel.backgroundNode.isHidden = false
        }
        let isDark = self.presentationData.theme.overallDarkAppearance
        self.chatDisplayNode.updateSideListOffset(offset, dimAlpha: (isDark ? 0.45 : 0.22) * min(1.0, self.sideListOpenFraction), transition: transition, completion: { [weak self, weak panel] in
            if let self, let panel, self.sideListOpenFraction == 0.0 {
                panel.backgroundNode.isHidden = true
            }
            completion?()
        })
        transition.updateFrame(node: panel, frame: CGRect(origin: CGPoint(), size: layout.size))
        panel.updateLayout(layout: layout, openFraction: self.sideListOpenFraction, transition: transition)
    }
}

/// The drag from the chat's right edge that brings its side list out. Message swipes, the history's scrolling and the
/// back swipe wait while it may still begin; taps and long presses don't.
final class ChatSideListEdgePanHandler: NSObject, UIGestureRecognizerDelegate {
    static let edgeWidth: CGFloat = 24.0

    private weak var controller: ChatControllerImpl?
    let recognizer: ChatSideListEdgePanGestureRecognizer

    init(controller: ChatControllerImpl) {
        self.controller = controller
        self.recognizer = ChatSideListEdgePanGestureRecognizer()

        super.init()

        self.recognizer.addTarget(self, action: #selector(self.panGesture(_:)))
        self.recognizer.delegate = self
        self.recognizer.isInEdge = { [weak self] point in
            return self?.controller?.sideListEdgePanAllowed(at: point) ?? false
        }
    }

    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        self.controller?.sideListEdgePanUpdated(recognizer)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let velocity = self.recognizer.velocity(in: self.recognizer.view)
        return velocity.x < 0.0 && abs(velocity.x) > abs(velocity.y)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer
    }
}

/// A pan that can only start at the chat's right edge.
final class ChatSideListEdgePanGestureRecognizer: UIPanGestureRecognizer {
    var isInEdge: ((CGPoint) -> Bool)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let touch = touches.first, let view = self.view, !(self.isInEdge?(touch.location(in: view)) ?? false) {
            self.state = .failed
        }
    }
}
