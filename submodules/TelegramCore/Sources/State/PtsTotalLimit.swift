import Foundation
import Postbox

/// The `pts_total_limit` sent with `updates.getDifference` when the app configuration has no `pts_total_limit`
/// (audit Q14).
let defaultPtsTotalLimit: Int32 = 10000

/// The most a support account sends. A support account touches thousands of chats a day, so after a long absence a
/// replay of the missed updates keeps it "Updating" for a long time; past this many it resets instead, loading the
/// chat list from the newest chats down.
let supportPtsTotalLimit: Int32 = 1000

/// The `pts_total_limit` to send with `updates.getDifference`, nil for none (flags.0 clear).
///
/// It comes from the app-configuration key `pts_total_limit`, which arrives as a number (Double):
/// - absent, or not a number: `defaultPtsTotalLimit`;
/// - below 1: nil. A request without the limit is the server's off switch;
/// - otherwise the value, rounded toward zero and capped at `Int32.max`.
///
/// A gap larger than the limit answers `updates.differenceTooLong`. The main app reads this in the transaction
/// that starts each poll, so every request of a chain carries it, slices included; the notification extension
/// reads it before each request and leaves the reset to the app (Q3).
///
/// In DEBUG builds the Debug Settings override (`StateSyncDebugSettings.ptsTotalLimitOverride`) wins when it is set:
/// below 1 it sends no limit, otherwise its value. Release builds never read it.
///
/// A support account sends at most `supportPtsTotalLimit`; the server's off switch still sends none.
func currentPtsTotalLimit(transaction: Transaction, accountPeerId: PeerId) -> Int32? {
    #if DEBUG
    if let override = transaction.getPreferencesEntry(key: PreferencesKeys.stateSyncDebugSettings)?.get(StateSyncDebugSettings.self)?.ptsTotalLimitOverride {
        return override >= 1 ? override : nil
    }
    #endif
    guard let limit = configuredPtsTotalLimit(transaction: transaction) else {
        return nil
    }
    if isSupportAccount(transaction: transaction, accountPeerId: accountPeerId) {
        return min(limit, supportPtsTotalLimit)
    }
    return limit
}

private func configuredPtsTotalLimit(transaction: Transaction) -> Int32? {
    let appConfiguration = currentAppConfiguration(transaction: transaction)
    guard let data = appConfiguration.data, let value = data["pts_total_limit"] as? Double, value.isFinite else {
        return defaultPtsTotalLimit
    }
    if value < 1.0 {
        return nil
    }
    if value >= Double(Int32.max) {
        return Int32.max
    }
    return Int32(value)
}
