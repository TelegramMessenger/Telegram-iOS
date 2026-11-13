import Foundation
import Postbox
import SwiftSignalKit

private func supportResortHeldChatRows(transaction: Transaction, reason: String) {
    let startTime = CFAbsoluteTimeGetCurrent()
    let count = transaction.resortHeldChatListRows(groupIds: [.root, Namespaces.PeerGroup.archive])
    Logger.shared.log("SupportChatOrder", "\(reason): re-sorted \(count) rows in \(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)) ms")
}

func managedSupportChatOrder(postbox: Postbox, stateManager: AccountStateManager, supportContext: SupportContext) -> Signal<Never, NoError> {
    let launchResort: Signal<Void, NoError>
    if supportContext.takeChatOrderLaunchResort() {
        launchResort = postbox.transaction { transaction -> Void in
            supportResortHeldChatRows(transaction: transaction, reason: "launch")
        }
    } else {
        launchResort = .single(Void())
    }

    return launchResort
    |> mapToSignal { _ -> Signal<Bool, NoError> in
        return stateManager.isUpdating
        |> filter { isUpdating in
            return !isUpdating
        }
        |> take(1)
    }
    |> mapToSignal { _ -> Signal<Bool, NoError> in
        return supportSettingsSignal(postbox: postbox)
        |> map { settings in
            return settings.fixChatsOrder
        }
        |> distinctUntilChanged
    }
    |> mapToSignal { holdsOrder -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.setHoldsChatListOrder(holdsOrder)
            Logger.shared.log("SupportChatOrder", "holding order: \(holdsOrder)")
            if !holdsOrder {
                supportResortHeldChatRows(transaction: transaction, reason: "setting off")
            }
        }
    }
    |> ignoreValues
}
