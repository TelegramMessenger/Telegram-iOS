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
        public let id: Int32?
        public let shortcut: String
        public let topMessage: EngineMessage
        public let totalCount: Int
        
        public init(id: Int32?, shortcut: String, topMessage: EngineMessage, totalCount: Int) {
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
    let updateSignal = _internal_shortcutMessageList(account: account, onlyRemote: true)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        var acc: UInt64 = 0
        for item in list.items {
            guard let itemId = item.id else {
                continue
            }
            combineInt64Hash(&acc, with: UInt64(itemId))
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

func _internal_shortcutMessageList(account: Account, onlyRemote: Bool) -> Signal<ShortcutMessageList, NoError> {
    let pendingShortcuts: Signal<[String: EngineMessage], NoError>
    if onlyRemote {
        pendingShortcuts = .single([:])
    } else {
        pendingShortcuts = account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: account.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 100, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .just(Set([Namespaces.Message.QuickReplyLocal])), orderStatistics: [])
        |> map { view , _, _ -> [String: EngineMessage] in
            var topMessages: [String: EngineMessage] = [:]
            for entry in view.entries {
                var shortcut: String?
                inner: for attribute in entry.message.attributes {
                    if let attribute = attribute as? OutgoingQuickReplyMessageAttribute {
                        shortcut = attribute.shortcut
                        break inner
                    }
                }
                if let shortcut {
                    if let currentTopMessage = topMessages[shortcut] {
                        if entry.message.index < currentTopMessage.index {
                            topMessages[shortcut] = EngineMessage(entry.message)
                        }
                    } else {
                        topMessages[shortcut] = EngineMessage(entry.message)
                    }
                }
            }
            return topMessages
        }
        |> distinctUntilChanged
    }
        
    return combineLatest(queue: .mainQueue(),
        _internal_quickReplyMessageShortcutsState(account: account) |> distinctUntilChanged,
        pendingShortcuts
    )
    |> mapToSignal { state, pendingShortcuts -> Signal<ShortcutMessageList, NoError> in
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
            
            let summaryKey: PostboxViewKey = .historyTagSummaryView(tag: [], peerId: account.peerId, threadId: Int64(shortcut.id), namespace: Namespaces.Message.QuickReplyCloud, customTag: nil)
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
            
            for (shortcut, message) in pendingShortcuts.sorted(by: { $0.key < $1.key }) {
                if !items.contains(where: { $0.shortcut == shortcut }) {
                    items.append(ShortcutMessageList.Item(
                        id: nil,
                        shortcut: shortcut,
                        topMessage: message,
                        totalCount: 1
                    ))
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
        return account.network.request(Api.functions.messages.sendQuickReplyMessages(peer: inputPeer, shortcutId: id, id: [], randomId: []))
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
        state.shortcuts.append(QuickReplyMessageShortcut(id: quickReplyId, shortcut: shortcut))
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
    }
}

public final class TelegramBusinessRecipients: Codable, Equatable {
    public struct Categories: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let existingChats = Categories(rawValue: 1 << 0)
        public static let newChats = Categories(rawValue: 1 << 1)
        public static let contacts = Categories(rawValue: 1 << 2)
        public static let nonContacts = Categories(rawValue: 1 << 3)
    }
    
    private enum CodingKeys: String, CodingKey {
        case categories
        case additionalPeers
        case excludePeers
        case exclude
    }
    
    public let categories: Categories
    public let additionalPeers: Set<PeerId>
    public let excludePeers: Set<PeerId>
    public let exclude: Bool
    
    public init(categories: Categories, additionalPeers: Set<PeerId>, excludePeers: Set<PeerId>, exclude: Bool) {
        self.categories = categories
        self.additionalPeers = additionalPeers
        self.excludePeers = excludePeers
        self.exclude = exclude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.categories = Categories(rawValue: try container.decode(Int32.self, forKey: .categories))
        self.additionalPeers = Set(try container.decode([PeerId].self, forKey: .additionalPeers))
        if let excludePeers = try container.decodeIfPresent([PeerId].self, forKey: .excludePeers) {
            self.excludePeers = Set(excludePeers)
        } else {
            self.excludePeers = Set()
        }
        self.exclude = try container.decode(Bool.self, forKey: .exclude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.categories.rawValue, forKey: .categories)
        try container.encode(Array(self.additionalPeers).sorted(), forKey: .additionalPeers)
        try container.encode(Array(self.excludePeers).sorted(), forKey: .excludePeers)
        try container.encode(self.exclude, forKey: .exclude)
    }
    
    public static func ==(lhs: TelegramBusinessRecipients, rhs: TelegramBusinessRecipients) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.categories != rhs.categories {
            return false
        }
        if lhs.additionalPeers != rhs.additionalPeers {
            return false
        }
        if lhs.excludePeers != rhs.excludePeers {
            return false
        }
        if lhs.exclude != rhs.exclude {
            return false
        }
        
        return true
    }
}

public final class TelegramBusinessGreetingMessage: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case shortcutId
        case recipients
        case inactivityDays
    }
    
    public let shortcutId: Int32
    public let recipients: TelegramBusinessRecipients
    public let inactivityDays: Int
    
    public init(shortcutId: Int32, recipients: TelegramBusinessRecipients, inactivityDays: Int) {
        self.shortcutId = shortcutId
        self.recipients = recipients
        self.inactivityDays = inactivityDays
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.shortcutId = try container.decode(Int32.self, forKey: .shortcutId)
        self.recipients = try container.decode(TelegramBusinessRecipients.self, forKey: .recipients)
        self.inactivityDays = Int(try container.decode(Int32.self, forKey: .inactivityDays))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.shortcutId, forKey: .shortcutId)
        try container.encode(self.recipients, forKey: .recipients)
        try container.encode(Int32(clamping: self.inactivityDays), forKey: .inactivityDays)
    }
    
    public static func ==(lhs: TelegramBusinessGreetingMessage, rhs: TelegramBusinessGreetingMessage) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.shortcutId != rhs.shortcutId {
            return false
        }
        if lhs.recipients != rhs.recipients {
            return false
        }
        if lhs.inactivityDays != rhs.inactivityDays {
            return false
        }
        
        return true
    }
}

extension TelegramBusinessGreetingMessage {
    convenience init(apiGreetingMessage: Api.BusinessGreetingMessage) {
        switch apiGreetingMessage {
        case let .businessGreetingMessage(shortcutId, recipients, noActivityDays):
            self.init(
                shortcutId: shortcutId,
                recipients: TelegramBusinessRecipients(apiValue: recipients),
                inactivityDays: Int(noActivityDays)
            )
        }
    }
}

public final class TelegramBusinessAwayMessage: Codable, Equatable {
    public enum Schedule: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case discriminator
            case customBeginTimestamp
            case customEndTimestamp
        }
        
        case always
        case outsideWorkingHours
        case custom(beginTimestamp: Int32, endTimestamp: Int32)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            switch try container.decode(Int32.self, forKey: .discriminator) {
            case 0:
                self = .always
            case 1:
                self = .outsideWorkingHours
            case 2:
                self = .custom(beginTimestamp: try container.decode(Int32.self, forKey: .customBeginTimestamp), endTimestamp: try container.decode(Int32.self, forKey: .customEndTimestamp))
            default:
                self = .always
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .always:
                try container.encode(0 as Int32, forKey: .discriminator)
            case .outsideWorkingHours:
                try container.encode(1 as Int32, forKey: .discriminator)
            case let .custom(beginTimestamp, endTimestamp):
                try container.encode(2 as Int32, forKey: .discriminator)
                try container.encode(beginTimestamp, forKey: .customBeginTimestamp)
                try container.encode(endTimestamp, forKey: .customEndTimestamp)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case shortcutId
        case recipients
        case schedule
        case sendWhenOffline
    }
    
    public let shortcutId: Int32
    public let recipients: TelegramBusinessRecipients
    public let schedule: Schedule
    public let sendWhenOffline: Bool
    
    public init(shortcutId: Int32, recipients: TelegramBusinessRecipients, schedule: Schedule, sendWhenOffline: Bool) {
        self.shortcutId = shortcutId
        self.recipients = recipients
        self.schedule = schedule
        self.sendWhenOffline = sendWhenOffline
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.shortcutId = try container.decode(Int32.self, forKey: .shortcutId)
        self.recipients = try container.decode(TelegramBusinessRecipients.self, forKey: .recipients)
        self.schedule = try container.decode(Schedule.self, forKey: .schedule)
        self.sendWhenOffline = try container.decodeIfPresent(Bool.self, forKey: .sendWhenOffline) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.shortcutId, forKey: .shortcutId)
        try container.encode(self.recipients, forKey: .recipients)
        try container.encode(self.schedule, forKey: .schedule)
        try container.encode(self.sendWhenOffline, forKey: .sendWhenOffline)
    }
    
    public static func ==(lhs: TelegramBusinessAwayMessage, rhs: TelegramBusinessAwayMessage) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.shortcutId != rhs.shortcutId {
            return false
        }
        if lhs.recipients != rhs.recipients {
            return false
        }
        if lhs.schedule != rhs.schedule {
            return false
        }
        if lhs.sendWhenOffline != rhs.sendWhenOffline {
            return false
        }
        
        return true
    }
}

public final class TelegramBusinessIntro: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case title
        case text
        case stickerFile
    }
    
    public let title: String
    public let text: String
    public let stickerFile: TelegramMediaFile?
    
    public init(title: String, text: String, stickerFile: TelegramMediaFile?) {
        self.title = title
        self.text = text
        self.stickerFile = stickerFile
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try container.decode(String.self, forKey: .title)
        self.text = try container.decode(String.self, forKey: .text)
        
        if let stickerFileData = try container.decodeIfPresent(Data.self, forKey: .stickerFile) {
            self.stickerFile = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: stickerFileData)))
        } else {
            self.stickerFile = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.title, forKey: .title)
        try container.encode(self.text, forKey: .text)
        
        if let stickerFile = self.stickerFile {
            let innerEncoder = PostboxEncoder()
            stickerFile.encode(innerEncoder)
            try container.encode(innerEncoder.makeData(), forKey: .stickerFile)
        }
    }
    
    public static func ==(lhs: TelegramBusinessIntro, rhs: TelegramBusinessIntro) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.stickerFile != rhs.stickerFile {
            return false
        }
        return true
    }
}

extension TelegramBusinessAwayMessage {
    convenience init(apiAwayMessage: Api.BusinessAwayMessage) {
        switch apiAwayMessage {
        case let .businessAwayMessage(flags, shortcutId, schedule, recipients):
            let mappedSchedule: Schedule
            switch schedule {
            case .businessAwayMessageScheduleAlways:
                mappedSchedule = .always
            case .businessAwayMessageScheduleOutsideWorkHours:
                mappedSchedule = .outsideWorkingHours
            case let .businessAwayMessageScheduleCustom(startDate, endDate):
                mappedSchedule = .custom(beginTimestamp: startDate, endTimestamp: endDate)
            }
            
            let sendWhenOffline = (flags & (1 << 0)) != 0
            
            self.init(
                shortcutId: shortcutId,
                recipients: TelegramBusinessRecipients(apiValue: recipients),
                schedule: mappedSchedule,
                sendWhenOffline: sendWhenOffline
            )
        }
    }
}

extension TelegramBusinessIntro {
    convenience init(apiBusinessIntro: Api.BusinessIntro) {
        switch apiBusinessIntro {
        case let .businessIntro(_, title, description, sticker):
            self.init(title: title, text: description, stickerFile: sticker.flatMap { telegramMediaFileFromApiDocument($0, altDocuments: []) })
        }
    }
    
    func apiInputIntro() -> Api.InputBusinessIntro {
        var flags: Int32 = 0
        var sticker: Api.InputDocument?
        if let stickerFile = self.stickerFile {
            if let fileResource = stickerFile.resource as? CloudDocumentMediaResource, let resource = stickerFile.resource as? TelegramCloudMediaResourceWithFileReference, let reference = resource.fileReference {
                flags |= 1 << 0
                sticker = .inputDocument(id: fileResource.fileId, accessHash: fileResource.accessHash, fileReference: Buffer(data: reference))
            }
        }
        return .inputBusinessIntro(
            flags: flags,
            title: self.title,
            description: self.text,
            sticker: sticker
        )
    }
}

extension TelegramBusinessRecipients {
    convenience init(apiValue: Api.BusinessRecipients) {
        switch apiValue {
        case let .businessRecipients(flags, users):
            var categories: Categories = []
            if (flags & (1 << 0)) != 0 {
                categories.insert(.existingChats)
            }
            if (flags & (1 << 1)) != 0 {
                categories.insert(.newChats)
            }
            if (flags & (1 << 2)) != 0 {
                categories.insert(.contacts)
            }
            if (flags & (1 << 3)) != 0 {
                categories.insert(.nonContacts)
            }
            
            self.init(
                categories: categories,
                additionalPeers: Set((users ?? []).map( { PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value($0)) })),
                excludePeers: Set(),
                exclude: (flags & (1 << 5)) != 0
            )
        }
    }
    
    convenience init(apiValue: Api.BusinessBotRecipients) {
        switch apiValue {
        case let .businessBotRecipients(flags, users, excludeUsers):
            var categories: Categories = []
            if (flags & (1 << 0)) != 0 {
                categories.insert(.existingChats)
            }
            if (flags & (1 << 1)) != 0 {
                categories.insert(.newChats)
            }
            if (flags & (1 << 2)) != 0 {
                categories.insert(.contacts)
            }
            if (flags & (1 << 3)) != 0 {
                categories.insert(.nonContacts)
            }
            
            self.init(
                categories: categories,
                additionalPeers: Set((users ?? []).map( { PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value($0)) })),
                excludePeers: Set((excludeUsers ?? []).map( { PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value($0)) })),
                exclude: (flags & (1 << 5)) != 0
            )
        }
    }
    
    func apiInputValue(additionalPeers: [Peer]) -> Api.InputBusinessRecipients {
        var users: [Api.InputUser]?
        if !additionalPeers.isEmpty {
            users = additionalPeers.compactMap(apiInputUser)
        }
        
        var flags: Int32 = 0
        
        if self.categories.contains(.existingChats) {
            flags |= 1 << 0
        }
        if self.categories.contains(.newChats) {
            flags |= 1 << 1
        }
        if self.categories.contains(.contacts) {
            flags |= 1 << 2
        }
        if self.categories.contains(.nonContacts) {
            flags |= 1 << 3
        }
        if self.exclude {
            flags |= 1 << 5
        }
        if users != nil {
            flags |= 1 << 4
        }
        
        return .inputBusinessRecipients(flags: flags, users: users)
    }
    
    func apiInputBotValue(additionalPeers: [Peer], excludePeers: [Peer]) -> Api.InputBusinessBotRecipients {
        var users: [Api.InputUser]?
        if !additionalPeers.isEmpty {
            users = additionalPeers.compactMap(apiInputUser)
        }
        var excludeUsers: [Api.InputUser]?
        if !excludePeers.isEmpty {
            excludeUsers = excludePeers.compactMap(apiInputUser)
        }
        
        var flags: Int32 = 0
        
        if self.categories.contains(.existingChats) {
            flags |= 1 << 0
        }
        if self.categories.contains(.newChats) {
            flags |= 1 << 1
        }
        if self.categories.contains(.contacts) {
            flags |= 1 << 2
        }
        if self.categories.contains(.nonContacts) {
            flags |= 1 << 3
        }
        if self.exclude {
            flags |= 1 << 5
        }
        if users != nil {
            flags |= 1 << 4
        }
        if excludeUsers != nil {
            flags |= 1 << 6
        }
        
        return .inputBusinessBotRecipients(flags: flags, users: users, excludeUsers: excludeUsers)
    }
}

func _internal_updateBusinessGreetingMessage(account: Account, greetingMessage: TelegramBusinessGreetingMessage?) -> Signal<Never, NoError> {
    let remoteApply = account.postbox.transaction { transaction -> [Peer] in
        guard let greetingMessage else {
            return []
        }
        return greetingMessage.recipients.additionalPeers.compactMap(transaction.getPeer)
    }
    |> mapToSignal { additionalPeers in
        var mappedMessage: Api.InputBusinessGreetingMessage?
        if let greetingMessage {
            mappedMessage = .inputBusinessGreetingMessage(
                shortcutId: greetingMessage.shortcutId,
                recipients: greetingMessage.recipients.apiInputValue(additionalPeers: additionalPeers),
                noActivityDays: Int32(clamping: greetingMessage.inactivityDays)
            )
        }
        
        var flags: Int32 = 0
        if mappedMessage != nil {
            flags |= 1 << 0
        }
        
        return account.network.request(Api.functions.account.updateBusinessGreetingMessage(flags: flags, message: mappedMessage))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
    
    return account.postbox.transaction { transaction in
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            var current = (current as? CachedUserData) ?? CachedUserData()
            current = current.withUpdatedGreetingMessage(greetingMessage)
            return current
        })
    }
    |> ignoreValues
    |> then(remoteApply)
}

func _internal_updateBusinessAwayMessage(account: Account, awayMessage: TelegramBusinessAwayMessage?) -> Signal<Never, NoError> {
    let remoteApply = account.postbox.transaction { transaction -> [Peer] in
        guard let awayMessage else {
            return []
        }
        return awayMessage.recipients.additionalPeers.compactMap(transaction.getPeer)
    }
    |> mapToSignal { additionalPeers in
        var mappedMessage: Api.InputBusinessAwayMessage?
        if let awayMessage {
            let mappedSchedule: Api.BusinessAwayMessageSchedule
            switch awayMessage.schedule {
            case .always:
                mappedSchedule = .businessAwayMessageScheduleAlways
            case .outsideWorkingHours:
                mappedSchedule = .businessAwayMessageScheduleOutsideWorkHours
            case let .custom(beginTimestamp, endTimestamp):
                mappedSchedule = .businessAwayMessageScheduleCustom(startDate: beginTimestamp, endDate: endTimestamp)
            }
            
            var flags: Int32 = 0
            if awayMessage.sendWhenOffline {
                flags |= 1 << 0
            }
            
            mappedMessage = .inputBusinessAwayMessage(
                flags: flags,
                shortcutId: awayMessage.shortcutId,
                schedule: mappedSchedule,
                recipients: awayMessage.recipients.apiInputValue(additionalPeers: additionalPeers)
            )
        }
        
        var flags: Int32 = 0
        if mappedMessage != nil {
            flags |= 1 << 0
        }
        
        return account.network.request(Api.functions.account.updateBusinessAwayMessage(flags: flags, message: mappedMessage))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
    
    return account.postbox.transaction { transaction in
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            var current = (current as? CachedUserData) ?? CachedUserData()
            current = current.withUpdatedAwayMessage(awayMessage)
            return current
        })
    }
    |> ignoreValues
    |> then(remoteApply)
}

func _internal_updateBusinessIntro(account: Account, intro: TelegramBusinessIntro?) -> Signal<Never, NoError> {
    let remoteApply = account.postbox.transaction { transaction -> Void in
        return
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        var flags: Int32 = 0
        var inputIntro: Api.InputBusinessIntro?
        
        if let intro {
            flags |= 1 << 0
            inputIntro = intro.apiInputIntro()
        }
        
        return account.network.request(Api.functions.account.updateBusinessIntro(flags: flags, intro: inputIntro))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
    
    return account.postbox.transaction { transaction in
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            var current = (current as? CachedUserData) ?? CachedUserData()
            current = current.withUpdatedBusinessIntro(intro)
            return current
        })
    }
    |> ignoreValues
    |> then(remoteApply)
}

public final class TelegramAccountConnectedBot: Codable, Equatable {
    public let id: PeerId
    public let recipients: TelegramBusinessRecipients
    public let canReply: Bool
    
    public init(id: PeerId, recipients: TelegramBusinessRecipients, canReply: Bool) {
        self.id = id
        self.recipients = recipients
        self.canReply = canReply
    }
    
    public static func ==(lhs: TelegramAccountConnectedBot, rhs: TelegramAccountConnectedBot) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.recipients != rhs.recipients {
            return false
        }
        if lhs.canReply != rhs.canReply {
            return false
        }
        return true
    }
}

public func _internal_setAccountConnectedBot(account: Account, bot: TelegramAccountConnectedBot?) -> Signal<Never, NoError> {
    let remoteApply = account.postbox.transaction { transaction -> (Peer?, [Peer], [Peer]) in
        guard let bot else {
            return (nil, [], [])
        }
        return (
            transaction.getPeer(bot.id),
            bot.recipients.additionalPeers.compactMap(transaction.getPeer),
            bot.recipients.excludePeers.compactMap(transaction.getPeer)
        )
    }
    |> mapToSignal { botUser, additionalPeers, excludePeers in
        var flags: Int32 = 0
        var mappedBot: Api.InputUser = .inputUserEmpty
        var mappedRecipients: Api.InputBusinessBotRecipients = .inputBusinessBotRecipients(flags: 0, users: nil, excludeUsers: nil)
        
        if let bot, let inputBotUser = botUser.flatMap(apiInputUser) {
            mappedBot = inputBotUser
            if bot.canReply {
                flags |= 1 << 0
            }
            mappedRecipients = bot.recipients.apiInputBotValue(additionalPeers: additionalPeers, excludePeers: excludePeers)
        } else {
            flags |= 1 << 1
        }
        
        return account.network.request(Api.functions.account.updateConnectedBot(flags: flags, bot: mappedBot, recipients: mappedRecipients))
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
    
    return account.postbox.transaction { transaction in
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            var current = (current as? CachedUserData) ?? CachedUserData()
            current = current.withUpdatedConnectedBot(bot)
            return current
        })
    }
    |> ignoreValues
    |> then(remoteApply)
}

func _internal_updatePersonalChannel(account: Account, personalChannel: TelegramPersonalChannel?) -> Signal<Never, NoError> {
    let remoteApply = account.postbox.transaction { transaction -> Peer? in
        guard let personalChannel else {
            return nil
        }
        return (
            transaction.getPeer(personalChannel.peerId)
        )
    }
    |> mapToSignal { peer in
        let inputPeer = peer.flatMap(apiInputChannel)
        
        return account.network.request(Api.functions.account.updatePersonalChannel(channel: inputPeer ?? .inputChannelEmpty))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
    
    return account.postbox.transaction { transaction in
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            var current = (current as? CachedUserData) ?? CachedUserData()
            current = current.withUpdatedPersonalChannel(personalChannel)
            return current
        })
    }
    |> ignoreValues
    |> then(remoteApply)
}
