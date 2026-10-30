import Foundation

/// Whether this client has Gram Wallet for an account's user (widget-sandbox v0.5.0, sdk-v1 §5.13: the context's
/// `wallet`, so a widget gets `TelegramWidget.wallet`). It is all three at once: the app configuration's
/// `wallet_available`, a wallet context (the main app only), and a wallet this device can sign for. The last is the
/// user's decision of 2026-10-30, a divergence from §5.13: no wallet, or one whose key is not on this device, is no
/// wallet for widgets, so a widget never makes the server create one.
///
/// The host app sets it per account from the wallet's state, and every layout pass reads it. A change posts
/// `MessageWidgetAvailability`'s, so the bubbles on screen lay out again; the context is part of a widget's key, so a
/// widget whose wallet changed boots again with it. Off until told otherwise.
///
/// The answer belongs to the host object that gave it last (`owner`, an account's context): two contexts of one account
/// can overlap for a moment, and the older one's release must not take the wallet away from the newer one's widgets.
public enum MessageWidgetWalletAvailability {
    private static let lock = NSLock()
    /// The accounts whose users have the wallet, each with the owner of that answer (nil: set with no owner).
    private static var ready: [Int64: ObjectIdentifier?] = [:]

    /// `accountId`: the id of the account's own user (`EnginePeer.Id.id._internalGetInt64Value()`).
    public static func isReady(accountId: Int64) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.ready[accountId] != nil
    }

    /// The account's answer now, given by `owner`, which then owns it.
    public static func set(_ isReady: Bool, accountId: Int64, owner: ObjectIdentifier? = nil) {
        self.lock.lock()
        let changed = (self.ready[accountId] != nil) != isReady
        if isReady {
            self.ready[accountId] = .some(owner)
        } else {
            self.ready.removeValue(forKey: accountId)
        }
        self.lock.unlock()
        if changed {
            MessageWidgetAvailability.noteChange()
        }
    }

    /// `owner` goes away: the account has no wallet for widgets, unless another owner has answered since.
    public static func release(accountId: Int64, owner: ObjectIdentifier) {
        self.lock.lock()
        let owned = self.ready[accountId].map { $0 == owner } ?? false
        if owned {
            self.ready.removeValue(forKey: accountId)
        }
        self.lock.unlock()
        if owned {
            MessageWidgetAvailability.noteChange()
        }
    }
}
