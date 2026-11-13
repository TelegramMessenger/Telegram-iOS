import Foundation
import Postbox

enum SupportAccountResetChat: Equatable {
    case skip
    case clear
    case reset
}

private let supportAccountResetOutgoingScanLimit = 20

/// A support account keeps a chat-list record for every customer it ever had, so the reset after differenceTooLong
/// leaves one-to-one chats outside the list alone, unless a folder names one: the reset that hid one put a hole over
/// it, and a chat that was deleted or cleaned up has no history, but the cleanup keeps a chat a folder names. Of those
/// it does look at it skips the empty ones and clears those without a received message, instead of a hole each. A chat
/// on screen is not cleared under its reader: it gets the hole.
func supportAccountResetChat(transaction: Transaction, peerId: PeerId) -> SupportAccountResetChat {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return .reset
    }
    if transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Local) != nil {
        return .reset
    }
    if transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) == nil {
        if !transaction.isMessageHistoryInitialized(peerId: peerId) {
            return .skip
        }
        if transaction.getHoles(peerId: peerId, namespace: Namespaces.Message.Cloud).contains(integersIn: 1 ... Int(Int32.max - 1)) {
            return .skip
        }
        return .reset
    }
    var count = 0
    var hasReceivedMessage = false
    transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: supportAccountResetOutgoingScanLimit, { message in
        count += 1
        if message.flags.contains(.Incoming) {
            hasReceivedMessage = true
            return false
        }
        return true
    })
    if !hasReceivedMessage && count < supportAccountResetOutgoingScanLimit && !transaction.hasOpenMessageHistoryView(peerId: peerId) {
        return .clear
    }
    return .reset
}
