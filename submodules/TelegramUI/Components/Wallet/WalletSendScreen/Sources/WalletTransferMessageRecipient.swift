import Foundation
import TelegramCore

public enum WalletTransferMessageRecipient: Equatable {
    case peer(EnginePeer)
    case address(String)
}

/// Who "Send Money" on a GRAM transfer message sends to. A transfer in a private chat is with that user. Elsewhere,
/// as in Telegram Notifications (which reports transfers from wallets that are not Telegram users), the counterparty
/// is the transfer's address; a service account, a bot or the account itself never is one. Nil means no recipient,
/// and the action is not offered.
public func walletTransferMessageRecipient(chatPeer: EnginePeer?, accountPeerId: EnginePeer.Id, peerAddress: String) -> WalletTransferMessageRecipient? {
    if let chatPeer, case let .user(user) = chatPeer,
       user.id.namespace == Namespaces.Peer.CloudUser,
       user.id != accountPeerId,
       !chatPeer.isService,
       user.botInfo == nil,
       !user.flags.contains(.isSupport) {
        return .peer(chatPeer)
    }
    let address = peerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    if !address.isEmpty {
        return .address(address)
    }
    return nil
}
