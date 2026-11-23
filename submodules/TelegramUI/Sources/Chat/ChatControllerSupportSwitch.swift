import Foundation
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
        return self.context.engine.messages.supportSwitchTarget(peerId: peerId, chatListFilterId: self.currentChatListFilter, getFilterPredicate: { data in
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
        let _ = (self.context.engine.messages.supportMarkDone(peerId: peerId, chatListFilterId: self.currentChatListFilter, getFilterPredicate: { data in
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

    func supportSwitchPreload(peerId: EnginePeer.Id) -> Disposable {
        let context = self.context
        let accountPeerId = context.account.peerId
        return (context.engine.messages.supportSwitchTargetUpdates(peerId: peerId, chatListFilterId: self.currentChatListFilter, getFilterPredicate: { data in
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
