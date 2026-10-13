import Postbox
import TelegramCore
import Foundation

func walletTonConnectRequestRoute(message: Message, accountPeerId: PeerId) -> WalletTonConnectRequestMessage? {
    let servicePeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
    guard message.id.namespace == Namespaces.Message.Cloud,
          message.id.peerId == servicePeerId,
          message.author?.id == servicePeerId,
          message.effectivelyIncoming(accountPeerId) else {
        return nil
    }
    for media in message.media {
        if let action = media as? TelegramMediaAction,
           case let .walletTonConnectRequest(flags, sessionId, expires, topic, traceId, dappName) = action.action {
            return WalletTonConnectRequestMessage(messageId: message.id, flags: flags, sessionId: sessionId,
                expires: expires, topic: topic, traceId: traceId, dappName: dappName)
        }
    }
    return nil
}

/// A notification must not be replaced by a later tap while selecting its account.
struct WalletTonConnectNotificationQueue<AccountId: Equatable, MessageId: Equatable> {
    struct Route {
        let accountId: AccountId?
        let messageId: MessageId
        let alwaysKeepMessageId: Bool
    }
    private var routes: [Route] = []
    private var selectingAccount = false

    @discardableResult mutating func enqueue(accountId: AccountId?, messageId: MessageId, alwaysKeepMessageId: Bool) -> Bool {
        guard !self.routes.contains(where: { $0.accountId == accountId && $0.messageId == messageId }) else { return false }
        self.routes.append(Route(accountId: accountId, messageId: messageId, alwaysKeepMessageId: alwaysKeepMessageId))
        return true
    }

    mutating func next() -> Route? {
        guard !self.selectingAccount, let route = self.routes.first else { return nil }
        self.selectingAccount = true
        return route
    }

    mutating func complete() {
        guard self.selectingAccount else { return }
        self.routes.removeFirst()
        self.selectingAccount = false
    }
}
