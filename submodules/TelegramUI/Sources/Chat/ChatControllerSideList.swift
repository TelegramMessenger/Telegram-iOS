import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatSideListPanel
import ChatListUI
import ChatControllerInteraction

extension ChatControllerImpl {
    func currentSideListKind(presentationInterfaceState: ChatPresentationInterfaceState) -> ChatSideListKind? {
        let isRegularWidth = self.validLayout?.metrics.widthClass == .regular
        return chatSideListKindForChatPresentationInterfaceState(presentationInterfaceState, context: self.context, isRegularWidth: isRegularWidth)
    }

    private static var sideListTransition: ContainedViewLayoutTransition {
        return .animated(duration: 0.4, curve: .spring)
    }

    func toggleSideList() {
        if self.sideListOpenFraction > 0.0 {
            self.closeSideList(animated: true)
        } else {
            self.openSideList()
        }
    }

    func openSideList() {
        guard let kind = self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState), self.validLayout != nil else {
            return
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
            panel = ChatSideListPanelNode(kind: kind, listController: listController, presentationData: self.presentationData)
            panel.requestClose = { [weak self] in
                self?.closeSideList(animated: true)
            }
            panel.dragUpdated = { [weak self] fraction in
                self?.setSideListOpenFraction(fraction, transition: .immediate)
            }
            panel.dragEnded = { [weak self] remainsOpen in
                guard let self else {
                    return
                }
                if remainsOpen {
                    self.setSideListOpenFraction(1.0, transition: ChatControllerImpl.sideListTransition)
                } else {
                    self.closeSideList(animated: true)
                }
            }
            listController.interceptPeerSelection = { [weak self] peerId, threadId, messageId in
                return self?.handleSideListSelection(peerId: peerId, threadId: threadId, messageId: messageId) ?? false
            }
            panel.newTopic = { [weak self] in
                guard let self else {
                    return
                }
                // A bot's new thread starts from its root chat, as the topics strip's "all" item does.
                self.closeSideList(animated: true)
                self.updateChatLocationThread(threadId: nil)
            }
            self.sideListPanel = panel
            self.chatDisplayNode.insertSubnode(panel.backgroundNode, at: 0)
            self.chatDisplayNode.addSubnode(panel)
            listController.didMove(toParent: self)
            // Lay it out closed first, so the opening animates in from the right edge.
            self.setSideListOpenFraction(0.0, transition: .immediate)
        }

        self.chatDisplayNode.dismissInput()
        // The open chat's row is highlighted, as on iPad's master list. Saved Messages and direct-messages rows are
        // keyed by the thread's peer; a bot's threads share the bot's peer, so they have no row to match.
        var highlightedLocation: ChatLocation?
        switch kind {
        case .savedMessages, .monoforum:
            if let threadId = self.chatLocation.threadId {
                highlightedLocation = .peer(id: EnginePeer.Id(threadId))
            }
        case .botThreads, .forum:
            break
        }
        panel.listController.updateNavigationCustomData(highlightedLocation, progress: 1.0, transition: .immediate)
        let wasOpen = self.sideListOpenFraction > 0.0
        if !wasOpen {
            panel.listController.viewWillAppear(true)
        }
        self.setSideListOpenFraction(1.0, transition: ChatControllerImpl.sideListTransition, completion: { [weak panel] in
            if !wasOpen {
                panel?.listController.viewDidAppear(true)
            }
        })
    }

    func closeSideList(animated: Bool) {
        guard let panel = self.sideListPanel, self.sideListOpenFraction > 0.0 else {
            return
        }
        panel.listController.viewWillDisappear(animated)
        self.setSideListOpenFraction(0.0, transition: animated ? ChatControllerImpl.sideListTransition : .immediate, completion: { [weak panel] in
            panel?.listController.viewDidDisappear(animated)
        })
    }

    enum SideListAppearance {
        case willAppear
        case didAppear
        case willDisappear
        case didDisappear
    }

    /// The chat's own appearance reaches the list only while the list is open; opening and closing send their own.
    func forwardSideListAppearance(_ appearance: SideListAppearance, animated: Bool) {
        guard let panel = self.sideListPanel, self.sideListOpenFraction > 0.0 else {
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

    private func handleSideListSelection(peerId: EnginePeer.Id, threadId: Int64?, messageId: EngineMessage.Id?) -> Bool {
        guard let panel = self.sideListPanel else {
            return false
        }
        switch chatSideListSelection(kind: panel.kind, currentThreadId: self.chatLocation.threadId, selectedPeerId: peerId, selectedThreadId: threadId, messageId: messageId) {
        case .passThrough:
            return false
        case .closeOnly:
            self.closeSideList(animated: true)
            return true
        case let .switchThread(threadId, messageId):
            self.closeSideList(animated: true)
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
        let wasOpen = self.sideListOpenFraction > 0.0
        self.sideListPanel = nil
        self.sideListOpenFraction = 0.0
        if wasOpen {
            panel.listController.viewWillDisappear(false)
            panel.listController.viewDidDisappear(false)
        }
        self.chatDisplayNode.updateSideListOffset(0.0, transition: .immediate)
        panel.listController.willMove(toParent: nil)
        panel.backgroundNode.removeFromSupernode()
        panel.removeFromSupernode()
        panel.listController.removeFromParent()
    }

    func setSideListOpenFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.sideListOpenFraction = fraction
        self.updateSideListLayout(transition: transition, completion: completion)
    }

    func updateSideListLayout(transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        guard let panel = self.sideListPanel, let layout = self.validLayout else {
            completion?()
            return
        }
        // The chat stopped being one with a side list (the killswitch, a width change): put it back.
        if self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState) != panel.kind {
            self.removeSideListPanel()
            completion?()
            return
        }
        let offset = self.sideListOpenFraction * (layout.size.width - ChatSideListPanelNode.stripWidth)
        // The list's background shows only through the chat card's corners, from opening until fully closed.
        if self.sideListOpenFraction > 0.0 {
            panel.backgroundNode.isHidden = false
        }
        self.chatDisplayNode.updateSideListOffset(offset, transition: transition, completion: { [weak self, weak panel] in
            if let self, let panel, self.sideListOpenFraction == 0.0 {
                panel.backgroundNode.isHidden = true
            }
            completion?()
        })
        transition.updateFrame(node: panel, frame: CGRect(origin: CGPoint(), size: layout.size))
        panel.updateLayout(layout: layout, openFraction: self.sideListOpenFraction, transition: transition)
    }
}
