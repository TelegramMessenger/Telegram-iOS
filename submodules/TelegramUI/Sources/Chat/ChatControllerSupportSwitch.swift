import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatListUI
import ChatAvatarNavigationNode

func supportMessagesShareContact(_ messages: [EnqueueMessage]) -> Bool {
    return messages.contains(where: { message in
        if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message {
            return mediaReference?.media is TelegramMediaContact
        }
        return false
    })
}

extension ChatControllerImpl {
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

    func supportSwitch(to peer: EnginePeer) -> Bool {
        guard let navigationController = self.effectiveNavigationController, navigationController.viewControllers.last === self else {
            return false
        }
        let keepsKeyboard = self.presentationInterfaceState.inputMode == .text
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
            (nextController as! ChatControllerImpl).animateFromPreviousController(snapshotState: snapshotState)
        }))
        return true
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
