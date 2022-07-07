import Foundation
import Postbox
import TelegramCore
import AccountContext

public enum SessionSelectionMode: Codable, Equatable {
    case selected
    case excluded

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch (try? container.decode(Int32.self, forKey: "t")) ?? 0 {
        case 0:
            self = .selected
        case 1:
            self = .excluded
        default:
            assertionFailure()
            self = .selected
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        switch self {
        case .selected:
            try container.encode(0 as Int32, forKey: "t")
        case .excluded:
            try container.encode(1 as Int32, forKey: "t")
        }
    }
}

public struct FakePasscodeAccountActionsSettings: Codable, Equatable {
    public let peerId: PeerId
    public let recordId: AccountRecordId
    public let logOut: Bool
    public let sessionsToHide: [Int64]
    public let sessionsToHideMode: SessionSelectionMode

    public static func defaultSettings(peerId: PeerId, recordId: AccountRecordId) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: peerId, recordId: recordId, logOut: false, sessionsToHide: [], sessionsToHideMode: .selected)
    }

    public init(peerId: PeerId, recordId: AccountRecordId, logOut: Bool, sessionsToHide: [Int64], sessionsToHideMode: SessionSelectionMode) {
        self.peerId = peerId
        self.recordId = recordId
        self.logOut = logOut
        self.sessionsToHide = sessionsToHide
        self.sessionsToHideMode = sessionsToHideMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerId = try container.decode(PeerId.self, forKey: "pid")
        self.recordId = try container.decode(AccountRecordId.self, forKey: "rid")
        self.logOut = (try container.decodeIfPresent(Int32.self, forKey: "lo") ?? 0) != 0
        self.sessionsToHide = try container.decodeIfPresent([Int64].self, forKey: "sth") ?? []
        self.sessionsToHideMode = try container.decodeIfPresent(SessionSelectionMode.self, forKey: "sthsm") ?? SessionSelectionMode.selected
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerId, forKey: "pid")
        try container.encode(self.recordId, forKey: "rid")
        try container.encode((self.logOut ? 1 : 0) as Int32, forKey: "lo")
        try container.encode(self.sessionsToHide, forKey: "sth")
        try container.encode(self.sessionsToHideMode, forKey: "sthsm")
    }

    public func withUpdatedLogOut(_ logOut: Bool) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, logOut: logOut, sessionsToHide: self.sessionsToHide, sessionsToHideMode: self.sessionsToHideMode)
    }

    public func withUpdatedSessionsToHide(_ sessionsToHide: [Int64]) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, logOut: self.logOut, sessionsToHide: sessionsToHide, sessionsToHideMode: self.sessionsToHideMode)
    }

    public func withUpdatedSessionsToHideMode(_ sessionsToHideMode: SessionSelectionMode) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, logOut: self.logOut, sessionsToHide: self.sessionsToHide, sessionsToHideMode: sessionsToHideMode)
    }

    public func performActions(accountManager: AccountManager<TelegramAccountManagerTypes>, applicationBindings: TelegramApplicationBindings) {
        if logOut {
            applicationBindings.clearAllNotifications()
            let _ = logoutFromAccount(id: recordId, accountManager: accountManager, alreadyLoggedOutRemotely: false).start()
        }
    }
}
