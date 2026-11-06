import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

/// The proposal is available only in the isolated offline account.
/// Cloud groups require a server capability before exposing this permission.
public enum AllMentionDemoConfiguration {
    public static var isEnabled: Bool {
        return allMentionDemoNetworkIsDisabled
    }

    public static let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(9_100_000))
    public static let groupPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(8_100_001))

    public static let forumPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(8_100_002))
    public static let groupPeerIds = [groupPeerId, forumPeerId]

    public static func isAvailable(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> Bool {
        return self.isEnabled && accountPeerId == self.accountPeerId && self.groupPeerIds.contains(peerId)
    }
}

/// A group-wide gate: administrators follow the same switch as members.
public struct AllMentionGroupPermission: Codable, Equatable {
    public static let callInterval: TimeInterval = 5 * 60
    public static let burstLimit = 3
    public let isEnabled: Bool
    public let callsInBurst: Int
    /// Five minutes after the latest call: refreshes a partial series or ends an exhausted series' break.
    public let burstResetsAt: TimeInterval

    public init(isEnabled: Bool = false, callsInBurst: Int = 0, burstResetsAt: TimeInterval = 0) {
        self.isEnabled = isEnabled
        self.callsInBurst = callsInBurst
        self.burstResetsAt = burstResetsAt
    }

    public func remainingSeconds(at timestamp: TimeInterval) -> Int {
        guard self.callsInBurst >= Self.burstLimit else { return 0 }
        return Int(ceil(max(0, self.burstResetsAt - timestamp)))
    }

    public func withUpdatedIsEnabled(_ isEnabled: Bool) -> Self {
        // Turning the permission off and back on must not reset the group limit.
        return Self(isEnabled: isEnabled, callsInBurst: self.callsInBurst, burstResetsAt: self.burstResetsAt)
    }

    public func availableCalls(at timestamp: TimeInterval) -> Int {
        guard self.isEnabled, self.remainingSeconds(at: timestamp) == 0 else { return 0 }
        return timestamp >= self.burstResetsAt ? Self.burstLimit : max(0, Self.burstLimit - self.callsInBurst)
    }

    public func reservingCall(at timestamp: TimeInterval) -> Self? {
        let available = self.availableCalls(at: timestamp)
        guard available > 0 else { return nil }
        let count = Self.burstLimit - available + 1
        return Self(isEnabled: true, callsInBurst: count, burstResetsAt: timestamp + Self.callInterval)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case callsInBurst
        case burstResetsAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.callsInBurst = Int(try container.decodeIfPresent(Int32.self, forKey: .callsInBurst) ?? 0)
        self.burstResetsAt = try container.decodeIfPresent(TimeInterval.self, forKey: .burstResetsAt) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.isEnabled, forKey: .isEnabled)
        // Postbox deliberately rejects platform-sized Int in Codable records.
        try container.encode(Int32(self.callsInBurst), forKey: .callsInBurst)
        try container.encode(self.burstResetsAt, forKey: .burstResetsAt)
    }
}

public func allMentionGroupState(postbox: Postbox, peerId: EnginePeer.Id) -> Signal<AllMentionGroupPermission, NoError> {
    let key = ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: peerId)
    return postbox.preferencesView(keys: [key])
    |> map { view in
        return view.values[key]?.get(AllMentionGroupPermission.self) ?? AllMentionGroupPermission()
    }
    |> distinctUntilChanged
}

public func allMentionGroupPermission(postbox: Postbox, peerId: EnginePeer.Id) -> Signal<Bool, NoError> {
    return allMentionGroupState(postbox: postbox, peerId: peerId)
    |> map { $0.isEnabled }
    |> distinctUntilChanged
}

public func allMentionGroupState(transaction: Transaction, peerId: EnginePeer.Id) -> AllMentionGroupPermission {
    return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: peerId))?.get(AllMentionGroupPermission.self) ?? AllMentionGroupPermission()
}

public func allMentionGroupPermission(transaction: Transaction, peerId: EnginePeer.Id) -> Bool {
    return allMentionGroupState(transaction: transaction, peerId: peerId).isEnabled
}

public func updateAllMentionGroupPermission(account: Account, peerId: EnginePeer.Id, isEnabled: Bool) -> Signal<Void, NoError> {
    guard AllMentionDemoConfiguration.isAvailable(accountPeerId: account.peerId, peerId: peerId) else {
        return .single(())
    }
    return account.postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: peerId), { entry in
            let state = entry?.get(AllMentionGroupPermission.self) ?? AllMentionGroupPermission()
            return PreferencesEntry(state.withUpdatedIsEnabled(isEnabled))
        })
    }
}
