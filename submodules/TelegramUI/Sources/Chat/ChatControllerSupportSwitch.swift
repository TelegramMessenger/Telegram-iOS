import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatListUI
import ChatAvatarNavigationNode
import UndoUI
import NavigationBarNode
import GameController

func supportMessagesShareContact(_ messages: [EnqueueMessage]) -> Bool {
    return messages.contains(where: { message in
        if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message {
            return mediaReference?.media is TelegramMediaContact
        }
        return false
    })
}

extension ChatControllerImpl {
    func supportConfigureNavigationBar() {
        guard self.context.supportContext != nil else {
            return
        }
        (self.navigationBar as? NavigationBarNode)?.badgeChangesInPlace = true
    }

    // Subscribe before the enqueue: the send moves this chat to the top of the list, and transactions run in order.
    func supportSwitchTargetBeforeSend(isRequested: Bool, messages: [EnqueueMessage], postpone: Bool) -> Signal<EnginePeer?, NoError> {
        guard isRequested, !postpone, self.context.supportContext != nil, let peerId = self.supportOccupationPeerId else {
            return .single(nil)
        }
        if messages.contains(where: { supportSendIsDeferred(attributes: $0.attributes) }) {
            return .single(nil)
        }
        let accountPeerId = self.context.account.peerId
        return self.context.engine.messages.supportSwitchTarget(peerId: peerId, chatListFilterId: self.currentChatListFilter, searchResultPeerIds: self.context.supportContext?.searchResultPeerIds, getFilterPredicate: { data in
            return chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
        })
    }

    // A hardware keyboard keeps typing in the composer: there is no on-screen keyboard to make room for.
    var supportHidesKeyboard: Bool {
        return self.context.supportContext?.currentHideKeyboardOnSwitch == true && GCKeyboard.coalesced == nil
    }

    func supportSwitch(to peer: EnginePeer) -> Bool {
        guard let navigationController = self.effectiveNavigationController, navigationController.viewControllers.last === self else {
            return false
        }
        let hidesKeyboard = self.supportHidesKeyboard
        let keepsKeyboard = self.presentationInterfaceState.inputMode == .text && !hidesKeyboard
        if hidesKeyboard {
            self.context.supportContext?.skipComposerFocus(peerId: peer.id)
        }
        // The composer clears on the history view's update, which may not have come yet.
        if let layoutActionOnViewTransitionAction = self.layoutActionOnViewTransitionAction {
            self.layoutActionOnViewTransitionAction = nil
            layoutActionOnViewTransitionAction()
        }
        let snapshotState = self.chatDisplayNode.prepareSnapshotState(
            titleViewSnapshotState: self.chatTitleView?.prepareSnapshotState(),
            avatarSnapshotState: (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.prepareSnapshotState()
        )
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), activateInput: keepsKeyboard ? .text : nil, animated: false, chatListFilter: self.currentChatListFilter, completion: { nextController in
            let nextController = nextController as! ChatControllerImpl
            // A second tap of a double tap would read this chat before it is seen.
            nextController.supportDoneIgnoredUntil = CFAbsoluteTimeGetCurrent() + 0.5
            nextController.animateFromPreviousController(snapshotState: snapshotState)
        }))
        return true
    }

    func supportDone() {
        guard self.context.supportContext != nil, let peerId = self.supportOccupationPeerId, CFAbsoluteTimeGetCurrent() >= self.supportDoneIgnoredUntil else {
            return
        }
        let accountPeerId = self.context.account.peerId
        let _ = (self.context.engine.messages.supportMarkDone(peerId: peerId, chatListFilterId: self.currentChatListFilter, searchResultPeerIds: self.context.supportContext?.searchResultPeerIds, getFilterPredicate: { data in
            return chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
        })
        |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .switchTo(peer):
                if self.supportSwitch(to: peer) {
                    return
                }
            case .noUnreadChatLeft:
                self.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: self.presentationData.strings.Support_Switching_NoUnreadChats, timeout: nil, customUndoText: nil), action: { _ in return false }), in: .window(.root))
            case .stay:
                break
            }
            self.chatDisplayNode.historyNode.scrollToEndOfHistory()
        })
    }

    func supportMoveThroughChatList(downward: Bool) {
        guard let supportContext = self.context.supportContext, let peerId = self.supportOccupationPeerId, supportContext.allowsHardwarePress(of: .chatHistory) else {
            return
        }
        let accountPeerId = self.context.account.peerId
        let _ = (self.context.engine.messages.supportChatListNeighbour(peerId: peerId, chatListFilterId: self.currentChatListFilter, downward: downward, getFilterPredicate: { data in
            return chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
        })
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            let _ = self.supportSwitch(to: peer)
        })
    }

    func supportSendAndStay() {
        guard let supportContext = self.context.supportContext, supportContext.allowsHardwarePress(of: .composerReturn) else {
            return
        }
        self.chatDisplayNode.supportSendStaysInChat = true
        self.chatDisplayNode.textInputPanelNode?.supportSendIfPossible()
        self.chatDisplayNode.supportSendStaysInChat = false
    }

    func supportEscape() {
        guard let supportContext = self.context.supportContext, supportContext.allowsHardwarePress(of: .escape) else {
            return
        }
        if self.presentationInterfaceState.interfaceState.editMessage != nil {
            self.interfaceInteraction?.setupEditMessage(nil, { _ in })
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    private var supportComposerHasSelection: Bool {
        if let selection = self.chatDisplayNode.textInputPanelNode?.supportComposerTextAndSelection?.selection {
            return selection.length > 0
        }
        return false
    }

    var supportShortcutActions: [SupportShortcutAction] {
        var actions: [SupportShortcutAction] = [.muteChat, .sendAndStay, .closeChat, .reloadTemplates]
        if self.supportOccupationPeerId != nil {
            actions.append(contentsOf: [.previousChat, .nextChat, .previousOpenedChat, .nextOpenedChat])
        }
        return actions
    }

    func supportPerformShortcut(_ action: SupportShortcutAction) {
        switch action {
        case .muteChat:
            self.supportToggleMuted()
        case .sendAndStay:
            self.supportSendAndStay()
        case .closeChat:
            self.supportEscape()
        case .reloadTemplates:
            supportReloadTemplatesAction(context: self.context, present: { [weak self] controller in
                self?.present(controller, in: .window(.root))
            })()
        case .previousChat:
            self.supportMoveThroughChatList(downward: false)
        case .nextChat:
            self.supportMoveThroughChatList(downward: true)
        case .previousOpenedChat:
            self.supportMoveThroughChatHistory(steps: -1)
        case .nextOpenedChat:
            self.supportMoveThroughChatHistory(steps: 1)
        case .showCurrentChat, .openAbuseBot:
            break
        }
    }

    func supportPerformsShortcut(insteadOfFormatKey key: String) -> Bool {
        guard let supportContext = self.context.supportContext, !self.supportComposerHasSelection else {
            return false
        }
        let combo = SupportKeyCombo(key: key, modifiers: [.command, .shift])
        guard let action = self.supportShortcutActions.first(where: { supportContext.shortcutCombos($0).contains(combo) }) else {
            return false
        }
        self.supportPerformShortcut(action)
        return true
    }

    func supportMoveThroughChatHistory(steps: Int) {
        guard let supportContext = self.context.supportContext, self.supportOccupationPeerId != nil, self.canReadHistoryValue, supportContext.allowsHardwarePress(of: .chatHistory), let peerId = supportContext.chatHistoryTarget(steps: steps) else {
            return
        }
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer, supportContext.chatHistoryTarget(steps: steps) == peerId else {
                return
            }
            // Before the switch: the next chat pushes itself when it appears, and must find itself current.
            supportContext.moveChatHistory(steps: steps)
            if !self.supportSwitch(to: peer) {
                supportContext.moveChatHistory(steps: -steps)
            }
        })
    }

    func supportToggleMuted() {
        guard let supportContext = self.context.supportContext, case .standard(.default) = self.mode, self.canReadHistoryValue, supportContext.allowsHardwarePress(of: .toggleMuted) else {
            return
        }
        self.interfaceInteraction?.togglePeerNotifications()
    }

    func supportSwitchPreload(peerId: EnginePeer.Id) -> Disposable {
        let context = self.context
        let accountPeerId = context.account.peerId
        return (context.engine.messages.supportSwitchTargetUpdates(peerId: peerId, chatListFilterId: self.currentChatListFilter, searchResultPeerIds: {
            return context.supportContext?.searchResultPeerIds
        }, getFilterPredicate: { data in
            return chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
        })
        |> mapToSignal { target -> Signal<Never, NoError> in
            guard let target else {
                return .complete()
            }
            return preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .Initial(count: 50), id: 0), context: context, chatLocation: .peer(id: target), subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), fixedCombinedReadStates: nil, tag: nil, additionalData: [])
            |> ignoreValues
        }).startStrict()
    }
}
