import Foundation
import TelegramCore
import TelegramIntents
import AccountContext
import Postbox
import SwiftSignalKit

public enum PeerRemovalType: Int32, Codable {
    case delete
    case hide
}

public struct PeerWithRemoveOptions: Codable, Equatable {
    public let peerId: PeerId
    public let removalType: PeerRemovalType
    public let deleteFromCompanion: Bool

    public init(peerId: PeerId, removalType: PeerRemovalType, deleteFromCompanion: Bool) {
        self.peerId = peerId
        self.removalType = removalType
        self.deleteFromCompanion = deleteFromCompanion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.peerId = try container.decode(PeerId.self, forKey: "pid")
        self.removalType = PeerRemovalType(rawValue: try container.decode(Int32.self, forKey: "rt")) ?? .delete
        self.deleteFromCompanion = (try container.decodeIfPresent(Int32.self, forKey: "dfc") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.peerId, forKey: "pid")
        try container.encode(self.removalType.rawValue, forKey: "rt")
        try container.encode((self.deleteFromCompanion ? 1 : 0) as Int32, forKey: "dfc")
    }
}

public struct FakePasscodeAccountActionsSettings: Codable, Equatable {
    public let peerId: PeerId
    public let recordId: AccountRecordId
    public let chatsToRemove: [PeerWithRemoveOptions]
    public let logOut: Bool
    public let sessionsToHide: FakePasscodeSessionsToHideSettings

    public static func defaultSettings(peerId: PeerId, recordId: AccountRecordId) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: peerId, recordId: recordId, chatsToRemove: [], logOut: false, sessionsToHide: FakePasscodeSessionsToHideSettings.defaultSettings())
    }

    public init(peerId: PeerId, recordId: AccountRecordId, chatsToRemove: [PeerWithRemoveOptions], logOut: Bool, sessionsToHide: FakePasscodeSessionsToHideSettings) {
        self.peerId = peerId
        self.recordId = recordId
        self.chatsToRemove = chatsToRemove
        self.logOut = logOut
        self.sessionsToHide = sessionsToHide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerId = try container.decode(PeerId.self, forKey: "pid")
        self.recordId = try container.decode(AccountRecordId.self, forKey: "rid")
        self.chatsToRemove = try container.decodeIfPresent([PeerWithRemoveOptions].self, forKey: "ctr") ?? []
        self.logOut = (try container.decodeIfPresent(Int32.self, forKey: "lo") ?? 0) != 0
        self.sessionsToHide = try container.decodeIfPresent(FakePasscodeSessionsToHideSettings.self, forKey: "sth") ?? FakePasscodeSessionsToHideSettings.defaultSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerId, forKey: "pid")
        try container.encode(self.recordId, forKey: "rid")
        try container.encode(self.chatsToRemove, forKey: "ctr")
        try container.encode((self.logOut ? 1 : 0) as Int32, forKey: "lo")
        try container.encode(self.sessionsToHide, forKey: "sth")
    }

    public func withUpdatedLogOut(_ logOut: Bool) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: logOut, sessionsToHide: self.sessionsToHide)
    }

    public func withUpdatedChatsToRemove(_ chatsToRemove: [PeerWithRemoveOptions]) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: chatsToRemove, logOut: self.logOut, sessionsToHide: self.sessionsToHide)
    }

    public func withUpdatedSessionsToHide(_ sessionsToHide: FakePasscodeSessionsToHideSettings) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: self.logOut, sessionsToHide: sessionsToHide)
    }

    public func performActions(context: AccountContext, updateSettings: @escaping (FakePasscodeAccountActionsSettings) -> Void) {
        let waitingQueueSizeValue = Atomic<Int>(value: 0)
        let waitingQueueSizePromise = ValuePromise<Int>(0)

        let updateWaitingQueueSize: ((Int) -> Int) -> Void = { f in
            waitingQueueSizePromise.set(waitingQueueSizeValue.modify { f($0) })
        }

        for chatToRemove in chatsToRemove {
            switch chatToRemove.removalType {
            case .delete:
                if chatToRemove.peerId.namespace == Namespaces.Peer.CloudChannel {
                    context.peerChannelMemberCategoriesContextsManager.externallyRemoved(peerId: chatToRemove.peerId, memberId: context.account.peerId)
                }

                let deleteGloballyIfPossible: Bool
                switch chatToRemove.peerId.namespace {
                case Namespaces.Peer.CloudUser:
                    deleteGloballyIfPossible = chatToRemove.deleteFromCompanion
                    break
                case Namespaces.Peer.SecretChat:
                    deleteGloballyIfPossible = true
                    break
                default:
                    deleteGloballyIfPossible = false
                    break
                }

                updateWaitingQueueSize({ $0 + 1 })
                let _ = context.engine.peers.removePeerChat(peerId: chatToRemove.peerId, reportChatSpam: false, deleteGloballyIfPossible: deleteGloballyIfPossible).start(completed: {
                    deleteSendMessageIntents(peerId: chatToRemove.peerId)
                    updateWaitingQueueSize({ $0 - 1 })
                })
                break

            case .hide:
                break
            }
        }

        let updatedChatsToRemove = chatsToRemove.filter({ !($0.peerId.namespace == Namespaces.Peer.SecretChat && $0.removalType == .delete) })
        if updatedChatsToRemove != chatsToRemove {
            updateSettings(self.withUpdatedChatsToRemove(updatedChatsToRemove))
        }

        if logOut {
            let _ = (waitingQueueSizePromise.get()
            |> filter { $0 == 0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { _ in
                context.sharedContext.applicationBindings.clearAllNotifications()
                let _ = logoutFromAccount(id: recordId, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
            })
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

        self.mode = SessionSelectionMode(rawValue: try container.decode(Int32.self, forKey: "m")) ?? .selected
        self.sessions = try container.decode([Int64].self, forKey: "s")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.mode.rawValue, forKey: "m")
        try container.encode(self.sessions, forKey: "s")
    }

    public func withUpdatedSessions(_ sessions: [Int64]) -> FakePasscodeSessionsToHideSettings {
        return FakePasscodeSessionsToHideSettings(sessions: sessions, mode: self.mode)
    }

    public func withUpdatedMode(_ mode: SessionSelectionMode) -> FakePasscodeSessionsToHideSettings {
        return FakePasscodeSessionsToHideSettings(sessions: self.sessions, mode: mode)
    }
}

public enum SessionSelectionMode: Int32, Codable {
    case selected
    case excluded
}
