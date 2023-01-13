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

public class PendingTaskCounter {
    private let counterValue = Atomic<Int>(value: 0)
    private let counterPromise = ValuePromise<Int>(0)
    
    public init() {}
    
    public func increment() {
        counterPromise.set(counterValue.modify { $0 + 1 })
    }
    
    public func decrement() {
        counterPromise.set(counterValue.modify { $0 - 1 })
    }
    
    public func completed() -> Signal<Void, NoError> {
        return counterPromise.get()
        |> filter { $0 == 0 }
        |> take(1)
        |> map { _ in }
    }
}

public struct FakePasscodeAccountActionsSettings: Codable, Equatable {
    public let peerId: PeerId
    public let recordId: AccountRecordId
    public let chatsToRemove: [PeerWithRemoveOptions]
    public let logOut: Bool
    public let sessionsToHide: SessionSelector
    public let sessionsToTerminate: SessionSelector
    public let sessionsToTerminateSkipWarning: Bool

    public static func defaultSettings(peerId: PeerId, recordId: AccountRecordId) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: peerId, recordId: recordId, chatsToRemove: [], logOut: false, sessionsToHide: SessionSelector.defaultSettings(), sessionsToTerminate: SessionSelector.defaultSettings(), sessionsToTerminateSkipWarning: false)
    }

    public init(peerId: PeerId, recordId: AccountRecordId, chatsToRemove: [PeerWithRemoveOptions], logOut: Bool, sessionsToHide: SessionSelector, sessionsToTerminate: SessionSelector, sessionsToTerminateSkipWarning: Bool) {
        self.peerId = peerId
        self.recordId = recordId
        self.chatsToRemove = chatsToRemove
        self.logOut = logOut
        self.sessionsToHide = sessionsToHide
        self.sessionsToTerminate = sessionsToTerminate
        self.sessionsToTerminateSkipWarning = sessionsToTerminateSkipWarning
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerId = try container.decode(PeerId.self, forKey: "pid")
        self.recordId = try container.decode(AccountRecordId.self, forKey: "rid")
        self.chatsToRemove = try container.decodeIfPresent([PeerWithRemoveOptions].self, forKey: "ctr") ?? []
        self.logOut = (try container.decodeIfPresent(Int32.self, forKey: "lo") ?? 0) != 0
        self.sessionsToHide = try container.decodeIfPresent(SessionSelector.self, forKey: "sth") ?? SessionSelector.defaultSettings()
        self.sessionsToTerminate = try container.decodeIfPresent(SessionSelector.self, forKey: "stt") ?? SessionSelector.defaultSettings()
        self.sessionsToTerminateSkipWarning = (try container.decodeIfPresent(Int32.self, forKey: "sttw") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerId, forKey: "pid")
        try container.encode(self.recordId, forKey: "rid")
        try container.encode(self.chatsToRemove, forKey: "ctr")
        try container.encode((self.logOut ? 1 : 0) as Int32, forKey: "lo")
        try container.encode(self.sessionsToHide, forKey: "sth")
        try container.encode(self.sessionsToTerminate, forKey: "stt")
        try container.encode((self.sessionsToTerminateSkipWarning ? 1 : 0) as Int32, forKey: "sttw")
    }

    public func withUpdatedLogOut(_ logOut: Bool) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: logOut, sessionsToHide: self.sessionsToHide, sessionsToTerminate: self.sessionsToTerminate, sessionsToTerminateSkipWarning: self.sessionsToTerminateSkipWarning)
    }

    public func withUpdatedChatsToRemove(_ chatsToRemove: [PeerWithRemoveOptions]) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: chatsToRemove, logOut: self.logOut, sessionsToHide: self.sessionsToHide, sessionsToTerminate: self.sessionsToTerminate, sessionsToTerminateSkipWarning: self.sessionsToTerminateSkipWarning)
    }

    public func withUpdatedSessionsToHide(_ sessionsToHide: SessionSelector) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: self.logOut, sessionsToHide: sessionsToHide, sessionsToTerminate: self.sessionsToTerminate, sessionsToTerminateSkipWarning: self.sessionsToTerminateSkipWarning)
    }

    public func withUpdatedSessionsToTerminate(_ sessionsToTerminate: SessionSelector) -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: self.logOut, sessionsToHide: self.sessionsToHide, sessionsToTerminate: sessionsToTerminate, sessionsToTerminateSkipWarning: self.sessionsToTerminateSkipWarning)
    }

    public func withDisabledSessionsToTerminateWarning() -> FakePasscodeAccountActionsSettings {
        return FakePasscodeAccountActionsSettings(peerId: self.peerId, recordId: self.recordId, chatsToRemove: self.chatsToRemove, logOut: self.logOut, sessionsToHide: self.sessionsToHide, sessionsToTerminate: sessionsToTerminate, sessionsToTerminateSkipWarning: true)
    }

    public func performActions(context: AccountContext, isCurrentAccount: Bool, beforeUnlockTaskCounter: PendingTaskCounter, updateSettings: @escaping (FakePasscodeAccountActionsSettings) -> Void) {
        let beforeLogoutTaskCounter = PendingTaskCounter()

        let chatsToDelete = chatsToRemove.filter { $0.removalType == .delete }
        if !chatsToDelete.isEmpty {
            beforeLogoutTaskCounter.increment()
            if isCurrentAccount {
                beforeUnlockTaskCounter.increment()
            }

            let _ = context.engine.peers.currentChatListFilters().start(next: { filters in
                // remove folder if removed chats are the only chats in it
                var filterIdsToRemove: [Int32] = []
                for fltr in filters {
                    if case let .filter(id, _, _, data) = fltr {
                        if data.categories.isEmpty && !data.includePeers.peers.isEmpty && Set(data.includePeers.peers).isSubset(of: chatsToDelete.map({ $0.peerId })) {
                            filterIdsToRemove.append(id)
                        }
                    }
                }

                var deleteItems: [(peerId: PeerId, deleteGloballyIfPossible: Bool)] = []

                for chatToRemove in chatsToDelete {
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

                    deleteItems.append((peerId: chatToRemove.peerId, deleteGloballyIfPossible: deleteGloballyIfPossible))
                }

                beforeLogoutTaskCounter.increment()
                if isCurrentAccount {
                    beforeUnlockTaskCounter.increment()
                }

                let _ = context.engine.peers.removePeerChats(items: deleteItems).start(completed: {
                    if !filterIdsToRemove.isEmpty {
                        beforeLogoutTaskCounter.increment()
                        if isCurrentAccount {
                            beforeUnlockTaskCounter.increment()
                        }

                        let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                            assert(filters.filter({ filterIdsToRemove.contains($0.id) }).allSatisfy { fltr in
                                if case let .filter(_, _, _, data) = fltr {
                                    return data.includePeers.peers.isEmpty
                                }
                                return false
                            })
                            return filters.filter({ !filterIdsToRemove.contains($0.id) })
                        }).start(completed: {
                            if isCurrentAccount {
                                beforeUnlockTaskCounter.decrement()
                            }

                            if logOut {
                                // need to wait for synchronization before logout
                                let _ = (context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
                                |> filter { view in
                                    let entry = view.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
                                    return entry.filters == entry.remoteFilters
                                }
                                |> map { _ in }
                                |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(Void()))
                                |> take(1)).start(completed: {
                                    beforeLogoutTaskCounter.decrement()
                                })
                            } else {
                                beforeLogoutTaskCounter.decrement()
                            }
                        })
                    }

                    if isCurrentAccount {
                        beforeUnlockTaskCounter.decrement()
                    }

                    let updatedChatsToRemove = chatsToRemove.filter { !($0.peerId.namespace == Namespaces.Peer.SecretChat && $0.removalType == .delete) }
                    if updatedChatsToRemove != chatsToRemove {
                        updateSettings(self.withUpdatedChatsToRemove(updatedChatsToRemove))
                    }

                    beforeLogoutTaskCounter.decrement()

                    for (peerId, _) in deleteItems {
                        deleteSendMessageIntents(peerId: peerId)
                    }
                })

                beforeLogoutTaskCounter.decrement()
                if isCurrentAccount {
                    beforeUnlockTaskCounter.decrement()
                }
            })
        }

        let activeSessionsContext = context.engine.privacy.activeSessions()
        activeSessionsContext.loadMore();
        if sessionsToTerminate.mode == .selected {
            for sessionId in sessionsToTerminate.sessions {
                let _ = activeSessionsContext.remove(hash: sessionId).start()
            }
        } else if sessionsToTerminate.mode == .excluded {
            let _ = (activeSessionsContext.state |> take(1)).start(next: { context in
                for s in context.sessions {
                    if !(s.hash == 0 || sessionsToTerminate.sessions.contains(s.hash)) {
                        let _ = activeSessionsContext.remove(hash: s.hash).start()
                    }
                }
            })
        } else {
            assertionFailure("Unsupported SessionSelectionMode \(sessionsToTerminate.mode)")
        }

        if logOut {
            beforeUnlockTaskCounter.increment()
            let _ = (beforeLogoutTaskCounter.completed()
            |> deliverOnMainQueue).start(next: {
                context.sharedContext.applicationBindings.clearAllNotifications()
                let _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start(completed: {
                    beforeUnlockTaskCounter.decrement()
                })
            })
        }
    }
}

public struct SessionSelector: Codable, Equatable {
    public let sessions: [Int64]
    public let mode: SessionSelectionMode

    public static func defaultSettings() -> SessionSelector {
        return SessionSelector(sessions: [], mode: .selected)
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

    public func withUpdatedSessions(_ sessions: [Int64]) -> SessionSelector {
        return SessionSelector(sessions: sessions, mode: self.mode)
    }

    public func withUpdatedMode(_ mode: SessionSelectionMode) -> SessionSelector {
        return SessionSelector(sessions: self.sessions, mode: mode)
    }
}

public enum SessionSelectionMode: Int32, Codable {
    case selected
    case excluded
}
