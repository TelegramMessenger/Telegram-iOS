import SwiftSignalKit
import Postbox

public final class TelegramEngine {
    public let account: Account

    public init(account: Account) {
        self.account = account
    }

    public lazy var secureId: SecureId = {
        return SecureId(account: self.account)
    }()

    public lazy var peersNearby: PeersNearby = {
        return PeersNearby(account: self.account)
    }()

    public lazy var payments: Payments = {
        return Payments(account: self.account)
    }()

    public lazy var peerNames: PeerNames = {
        return PeerNames(account: self.account)
    }()
}
