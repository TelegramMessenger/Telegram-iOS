import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Privacy {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func requestUpdatePeerIsBlocked(peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
            return _internal_requestUpdatePeerIsBlocked(account: self.account, peerId: peerId, isBlocked: isBlocked)
        }
    }
}
