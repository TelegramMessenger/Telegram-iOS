import Foundation
import Postbox
import TelegramCore
import AccountContext

public struct FakePasscodeAccountActionsSettings: Codable, Equatable {
    public let peerId: PeerId
    public let recordId: AccountRecordId
    public let logOut: Bool
    public let sessionsToHide: FakePasscodeSessionsToHideSettings

    public static func defaultSettings(peerId: PeerId, recordId: AccountRecordId) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: peerId, recordId: recordId, logOut: false, sessionsToHide: FakePasscodeSessionsToHideSettings.defaultSettings())
    }

    public init(peerId: PeerId, recordId: AccountRecordId, logOut: Bool, sessionsToHide: FakePasscodeSessionsToHideSettings) {
        self.peerId = peerId
        self.recordId = recordId
        self.logOut = logOut
        self.sessionsToHide = sessionsToHide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerId = try container.decode(PeerId.self, forKey: "pid")
        self.recordId = try container.decode(AccountRecordId.self, forKey: "rid")
        self.logOut = (try container.decodeIfPresent(Int32.self, forKey: "lo") ?? 0) != 0
        self.sessionsToHide = try container.decodeIfPresent(FakePasscodeSessionsToHideSettings.self, forKey: "sth") ?? FakePasscodeSessionsToHideSettings.defaultSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerId, forKey: "pid")
        try container.encode(self.recordId, forKey: "rid")
        try container.encode((self.logOut ? 1 : 0) as Int32, forKey: "lo")
        try container.encode(self.sessionsToHide, forKey: "sth")
    }

    public func withUpdatedLogOut(_ logOut: Bool) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, logOut: logOut, sessionsToHide: self.sessionsToHide)
    }

    public func withUpdatedSessionsToHide(_ sessionsToHide: FakePasscodeSessionsToHideSettings) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, logOut: self.logOut, sessionsToHide: sessionsToHide)
    }

    public func performActions(accountManager: AccountManager<TelegramAccountManagerTypes>, applicationBindings: TelegramApplicationBindings) {
        if logOut {
            applicationBindings.clearAllNotifications()
            let _ = logoutFromAccount(id: recordId, accountManager: accountManager, alreadyLoggedOutRemotely: false).start()
        }
    }
}

public struct FakePasscodeSessionsToHideSettings: Codable, Equatable {
    public let sessions: [Int64]
    public let mode: SessionSelectionMode

    public static func defaultSettings() -> FakePasscodeSessionsToHideSettings {
        return FakePasscodeSessionsToHideSettings(sessions: [], mode: .selected)
    }

    public init(sessions: [Int64], mode: SessionSelectionMode) {
        self.sessions = sessions
        self.mode = mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.mode = try container.decode(SessionSelectionMode.self, forKey: "m")
        self.sessions = try container.decode([Int64].self, forKey: "s")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.sessions, forKey: "s")
        try container.encode(self.mode, forKey: "m")
    }

    public func withUpdatedSessions(_ sessions: [Int64]) -> FakePasscodeSessionsToHideSettings {
        return FakePasscodeSessionsToHideSettings(sessions: sessions, mode: self.mode)
    }

    public func withUpdatedMode(_ mode: SessionSelectionMode) -> FakePasscodeSessionsToHideSettings {
        return FakePasscodeSessionsToHideSettings(sessions: self.sessions, mode: mode)
    }
}

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
