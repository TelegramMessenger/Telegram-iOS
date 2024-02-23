import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public final class QuickReplyMessageShortcut: Codable, Equatable {
    public let id: Int32
    public let shortcut: String

    public init(id: Int32, shortcut: String) {
        self.id = id
        self.shortcut = shortcut
    }
    
    public static func ==(lhs: QuickReplyMessageShortcut, rhs: QuickReplyMessageShortcut) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.shortcut != rhs.shortcut {
            return false
        }
        return true
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.id = try container.decode(Int32.self, forKey: "id")
        self.shortcut = try container.decode(String.self, forKey: "shortcut")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.id, forKey: "id")
        try container.encode(self.shortcut, forKey: "shortcut")
    }
}

struct QuickReplyMessageShortcutsState: Codable, Equatable {
    var shortcuts: [QuickReplyMessageShortcut]
    
    init(shortcuts: [QuickReplyMessageShortcut]) {
        self.shortcuts = shortcuts
    }
}

public final class ShortcutMessageList: Equatable {
    public final class Item: Equatable {
        public let id: Int32
        public let shortcut: String
        public let topMessage: EngineMessage
        public let totalCount: Int
        
        public init(id: Int32, shortcut: String, topMessage: EngineMessage, totalCount: Int) {
            self.id = id
            self.shortcut = shortcut
            self.topMessage = topMessage
            self.totalCount = totalCount
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.shortcut != rhs.shortcut {
                return false
            }
            if lhs.topMessage != rhs.topMessage {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            return true
        }
    }
    
    public let items: [Item]
    public let isLoading: Bool
    
    public init(items: [Item], isLoading: Bool) {
        self.items = items
        self.isLoading = isLoading
    }
    
    public static func ==(lhs: ShortcutMessageList, rhs: ShortcutMessageList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        return true
    }
}

func _internal_quickReplyMessageShortcutsState(account: Account) -> Signal<QuickReplyMessageShortcutsState?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.shortcutMessages()]))
    return account.postbox.combinedView(keys: [viewKey])
    |> map { views -> QuickReplyMessageShortcutsState? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.shortcutMessages()]?.get(QuickReplyMessageShortcutsState.self) else {
            return nil
        }
        return value
    }
}

func _internal_keepShortcutMessagesUpdated(account: Account) -> Signal<Never, NoError> {
    let updateSignal = _internal_shortcutMessageList(account: account)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        var acc: UInt64 = 0
        for item in list.items {
            combineInt64Hash(&acc, with: UInt64(item.id))
            combineInt64Hash(&acc, with: md5StringHash(item.shortcut))
            combineInt64Hash(&acc, with: UInt64(item.topMessage.id.id))

            var editTimestamp: Int32 = 0
            inner: for attribute in item.topMessage.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    editTimestamp = attribute.date
                    break inner
                }
            }
            combineInt64Hash(&acc, with: UInt64(editTimestamp))
        }
        
        return account.network.request(Api.functions.messages.getQuickReplies(hash: finalizeInt64Hash(acc)))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.QuickReplies?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            
            return account.postbox.transaction { transaction in
                var state = transaction.getPreferencesEntry(key: PreferencesKeys.shortcutMessages())?.get(QuickReplyMessageShortcutsState.self) ?? QuickReplyMessageShortcutsState(shortcuts: [])
                switch result {
                case let .quickReplies(quickReplies, messages, chats, users):
                    let previousShortcuts = state.shortcuts
                    state.shortcuts.removeAll()
                    
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                    
                    var storeMessages: [StoreMessage] = []
                    
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: false) {
                            storeMessages.append(message)
                        }
                    }
                    let _ = transaction.addMessages(storeMessages, location: .Random)
                    var topMessageIds: [Int32: Int32] = [:]
                    
                    for quickReply in quickReplies {
                        switch quickReply {
                        case let .quickReply(shortcutId, shortcut, topMessage, _):
                            state.shortcuts.append(QuickReplyMessageShortcut(
                                id: shortcutId,
                                shortcut: shortcut
                            ))
                            topMessageIds[shortcutId] = topMessage
                        }
                    }
                    
                    if previousShortcuts != state.shortcuts {
                        for shortcut in previousShortcuts {
                            if let topMessageId = topMessageIds[shortcut.id] {
                                //TODO:remove earlier
                                let _ = topMessageId
                            } else {
                                let existingCloudMessages = transaction.getMessagesWithThreadId(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyCloud, threadId: Int64(shortcut.id), from: MessageIndex.lowerBound(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyCloud), includeFrom: false, to: MessageIndex.upperBound(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyCloud), limit: 1000)
                                let existingLocalMessages = transaction.getMessagesWithThreadId(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyLocal, threadId: Int64(shortcut.id), from: MessageIndex.lowerBound(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyLocal), includeFrom: false, to: MessageIndex.upperBound(peerId: account.peerId, namespace: Namespaces.Message.QuickReplyLocal), limit: 1000)
                                
                                transaction.deleteMessages(existingCloudMessages.map(\.id), forEachMedia: nil)
                                transaction.deleteMessages(existingLocalMessages.map(\.id), forEachMedia: nil)
                            }
                        }
                    }
                case .quickRepliesNotModified:
                    break
                }
                
                transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}

func _internal_shortcutMessageList(account: Account) -> Signal<ShortcutMessageList, NoError> {
    return _internal_quickReplyMessageShortcutsState(account: account)
    |> distinctUntilChanged
    |> mapToSignal { state -> Signal<ShortcutMessageList, NoError> in
        guard let state else {
            return .single(ShortcutMessageList(items: [], isLoading: true))
        }
        
        var keys: [PostboxViewKey] = []
        var historyViewKeys: [Int32: PostboxViewKey] = [:]
        var summaryKeys: [Int32: PostboxViewKey] = [:]
        for shortcut in state.shortcuts {
            let historyViewKey: PostboxViewKey = .historyView(PostboxViewKey.HistoryView(
                peerId: account.peerId,
                threadId: Int64(shortcut.id),
                clipHoles: false,
                trackHoles: false,
                anchor: .lowerBound,
                appendMessagesFromTheSameGroup: false,
                namespaces: .just(Set([Namespaces.Message.QuickReplyCloud])),
                count: 10
            ))
            historyViewKeys[shortcut.id] = historyViewKey
            keys.append(historyViewKey)
            
            let summaryKey: PostboxViewKey = .historyTagSummaryView(tag: [], peerId: account.peerId, threadId: Int64(shortcut.id), namespace: Namespaces.Message.ScheduledCloud, customTag: nil)
            summaryKeys[shortcut.id] = summaryKey
            keys.append(summaryKey)
        }
        return account.postbox.combinedView(
            keys: keys
        )
        |> map { views -> ShortcutMessageList in
            var items: [ShortcutMessageList.Item] = []
            for shortcut in state.shortcuts {
                guard let historyViewKey = historyViewKeys[shortcut.id], let historyView = views.views[historyViewKey] as? MessageHistoryView else {
                    continue
                }
                
                var totalCount = 1
                if let summaryKey = summaryKeys[shortcut.id], let summaryView = views.views[summaryKey] as? MessageHistoryTagSummaryView {
                    if let count = summaryView.count {
                        totalCount = max(1, Int(count))
                    }
                }
                
                if let entry = historyView.entries.first {
                    items.append(ShortcutMessageList.Item(id: shortcut.id, shortcut: shortcut.shortcut, topMessage: EngineMessage(entry.message), totalCount: totalCount))
                }
            }
            return ShortcutMessageList(items: items, isLoading: false)
        }
        |> distinctUntilChanged
    }
}

func _internal_editMessageShortcut(account: Account, id: Int32, shortcut: String) -> Signal<Never, NoError> {
    let remoteApply = account.network.request(Api.functions.messages.editQuickReplyShortcut(shortcutId: id, shortcut: shortcut))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return .complete()
    }
    
    return account.postbox.transaction { transaction in
        var state = transaction.getPreferencesEntry(key: PreferencesKeys.shortcutMessages())?.get(QuickReplyMessageShortcutsState.self) ?? QuickReplyMessageShortcutsState(shortcuts: [])
        if let index = state.shortcuts.firstIndex(where: { $0.id == id }) {
            state.shortcuts[index] = QuickReplyMessageShortcut(id: id, shortcut: shortcut)
        }
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
    }
    |> ignoreValues
    |> then(remoteApply)
}

func _internal_deleteMessageShortcuts(account: Account, ids: [Int32]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction in
        var state = transaction.getPreferencesEntry(key: PreferencesKeys.shortcutMessages())?.get(QuickReplyMessageShortcutsState.self) ?? QuickReplyMessageShortcutsState(shortcuts: [])
        
        for id in ids {
            if let index = state.shortcuts.firstIndex(where: { $0.id == id }) {
                state.shortcuts.remove(at: index)
            }
        }
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
        
        for id in ids {
            cloudChatAddClearHistoryOperation(transaction: transaction, peerId: account.peerId, threadId: Int64(id), explicitTopMessageId: nil, minTimestamp: nil, maxTimestamp: nil, type: .quickReplyMessages)
        }
    }
    |> ignoreValues
}

func _internal_reorderMessageShortcuts(account: Account, ids: [Int32], localCompletion: @escaping () -> Void) -> Signal<Never, NoError> {
    let remoteApply = account.network.request(Api.functions.messages.reorderQuickReplies(order: ids))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return .complete()
    }
    
    return account.postbox.transaction { transaction in
        var state = transaction.getPreferencesEntry(key: PreferencesKeys.shortcutMessages())?.get(QuickReplyMessageShortcutsState.self) ?? QuickReplyMessageShortcutsState(shortcuts: [])
        
        let previousShortcuts = state.shortcuts
        state.shortcuts.removeAll()
        for id in ids {
            if let index = previousShortcuts.firstIndex(where: { $0.id == id }) {
                state.shortcuts.append(previousShortcuts[index])
            }
        }
        for shortcut in previousShortcuts {
            if !state.shortcuts.contains(where: { $0.id == shortcut.id }) {
                state.shortcuts.append(shortcut)
            }
        }
        
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
    }
    |> ignoreValues
    |> afterCompleted {
        localCompletion()
    }
    |> then(remoteApply)
}

func _internal_sendMessageShortcut(account: Account, peerId: PeerId, id: Int32) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> mapToSignal { peer -> Signal<Never, NoError> in
        guard let peer, let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.sendQuickReplyMessages(peer: inputPeer, shortcutId: id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            if let result {
                account.stateManager.addUpdates(result)
            }
            return .complete()
        }
    }
}

func _internal_applySentQuickReplyMessage(transaction: Transaction, shortcut: String, quickReplyId: Int32) {
    var state = transaction.getPreferencesEntry(key: PreferencesKeys.shortcutMessages())?.get(QuickReplyMessageShortcutsState.self) ?? QuickReplyMessageShortcutsState(shortcuts: [])
    
    if !state.shortcuts.contains(where: { $0.id == quickReplyId }) {
        state.shortcuts.insert(QuickReplyMessageShortcut(id: quickReplyId, shortcut: shortcut), at: 0)
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
    }
}
