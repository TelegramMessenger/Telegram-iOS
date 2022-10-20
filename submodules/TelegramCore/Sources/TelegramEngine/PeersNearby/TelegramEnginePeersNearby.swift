import SwiftSignalKit

public extension TelegramEngine {
    final class PeersNearby {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func updatePeersNearbyVisibility(update: PeerNearbyVisibilityUpdate, background: Bool) -> Signal<Void, NoError> {
            return _internal_updatePeersNearbyVisibility(account: self.account, update: update, background: background)
        }
    }
}
