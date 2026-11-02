import Foundation
import TelegramCore
import WalletContext

// Mirrors WalletSendRequest.Recipient so the choice can be tested without AccountContext.
public enum WalletTransferMessageRecipient: Equatable {
    case peer(EnginePeer)
    case address(String)
}

/// Who "Send Money" on a GRAM transfer message sends to. A transfer in a private chat with an ordinary user is with
/// that user. Telegram Notifications reports transfers with wallets that are not Telegram users, so there the
/// counterparty is the transfer's address, offered only when it parses as one (normalized as the transaction screen's
/// Send does). Nowhere else (a group, a channel, a secret chat, a bot, a service or deleted account, the account
/// itself) is the counterparty known: nil, and the action is not offered.
public func walletTransferMessageRecipient(chatPeer: EnginePeer?, accountPeerId: EnginePeer.Id, peerAddress: String) -> WalletTransferMessageRecipient? {
    guard let chatPeer, case let .user(user) = chatPeer, user.id.namespace == Namespaces.Peer.CloudUser else {
        return nil
    }
    if user.id.isTelegramNotifications {
        return WalletContext.transferAddress(from: peerAddress, preserveBounce: true).flatMap { .address($0) }
    }
    if user.id != accountPeerId,
       !chatPeer.isService,
       !chatPeer.isDeleted,
       user.botInfo == nil,
       !user.flags.contains(.isSupport) {
        return .peer(chatPeer)
    }
    return nil
}
