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

    enum Display: Equatable {
        case loading
        case address
        case unavailable
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

    /// What the recipient row shows for a peer: the lookup animation only while the lookup is due or running, so a
    /// failed one, or a peer without an address, ends in a static state rather than animating forever. A lookup
    /// cancelled by closing the sheet is not an error: the row keeps its placeholder while the sheet goes away.
    func display(recipientAddress: String) -> Display {
        if !recipientAddress.isEmpty {
            return .address
        }
        switch self.state {
        case .notRequested, .loading, .cancelled:
            return .loading
        case .resolved, .failed, .errorPresented:
            return .unavailable
        }
    }
}
