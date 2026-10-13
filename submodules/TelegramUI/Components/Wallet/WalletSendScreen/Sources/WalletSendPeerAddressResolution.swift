import Foundation
import TelegramCore

struct WalletSendPeerAddressResolution {
    enum State: Equatable {
        case notRequested
        case loading
        case resolved
        case failed
        case errorPresented
        case cancelled
    }

    var state: State = .notRequested
    private(set) var recipient: WalletUserAddress?
    private var generation = 0

    mutating func reset(resolvedAddress: WalletUserAddress?) {
        self.generation &+= 1
        self.recipient = resolvedAddress
        self.state = resolvedAddress == nil ? .notRequested : .resolved
    }

    mutating func begin() -> Int? {
        guard self.state == .notRequested else {
            return nil
        }
        self.generation &+= 1
        self.state = .loading
        return self.generation
    }

    mutating func complete(generation: Int, recipient: WalletUserAddress?) -> Bool {
        guard self.state == .loading, self.generation == generation else {
            return false
        }
        let address = recipient?.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if let recipient, let address, !address.isEmpty {
            self.recipient = WalletUserAddress(userId: recipient.userId, address: address, publicKey: recipient.publicKey)
            self.state = .resolved
        } else {
            self.recipient = nil
            self.state = .failed
        }
        return true
    }
}
