import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class EmojiSearchCategories: Equatable, Codable {
    public enum Kind: Int64 {
        case emoji = 0
        case status = 1
        case avatar = 2
    }

    public struct Group: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case identifiers
        }
        
        public var id: Int64
        public var title: String
        public var identifiers: [String]

        public init(id: Int64, title: String, identifiers: [String]) {
            self.id = id
            self.title = title
            self.identifiers = identifiers
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int64.self, forKey: .id)
            self.title = try container.decode(String.self, forKey: .title)
            self.identifiers = try container.decode([String].self, forKey: .identifiers)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case newHash
        case groups
    }
    
    public let hash: Int32
    public let groups: [Group]
    
    public init(
        hash: Int32,
        groups: [Group]
    ) {
        self.hash = hash
        self.groups = groups
    }
    
    public static func ==(lhs: EmojiSearchCategories, rhs: EmojiSearchCategories) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.groups != rhs.groups {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decodeIfPresent(Int32.self, forKey: .newHash) ?? 0
        self.groups = try container.decode([Group].self, forKey: .groups)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .newHash)
        try container.encode(self.groups, forKey: .groups)
    }
}

func _internal_cachedEmojiSearchCategories(postbox: Postbox, kind: EmojiSearchCategories.Kind) -> Signal<EmojiSearchCategories?, NoError> {
    return postbox.transaction { transaction -> EmojiSearchCategories? in
        return _internal_cachedEmojiSearchCategories(transaction: transaction, kind: kind)
    }
}

func _internal_cachedEmojiSearchCategories(transaction: Transaction, kind: EmojiSearchCategories.Kind) -> EmojiSearchCategories? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: kind.rawValue)
    
    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.emojiSearchCategories, key: key))?.get(EmojiSearchCategories.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

func _internal_setCachedEmojiSearchCategories(transaction: Transaction, categories: EmojiSearchCategories, kind: EmojiSearchCategories.Kind) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: kind.rawValue)
    
    if let entry = CodableEntry(categories) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.emojiSearchCategories, key: key), entry: entry)
    }
}

func managedSynchronizeEmojiSearchCategories(postbox: Postbox, network: Network, kind: EmojiSearchCategories.Kind) -> Signal<Never, NoError> {
    let poll = Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = _internal_cachedEmojiSearchCategories(postbox: postbox, kind: kind)
        |> mapToSignal { current in
            let signal: Signal<Api.messages.EmojiGroups, NoError>
            switch kind {
            case .emoji:
                signal = network.request(Api.functions.messages.getEmojiGroups(hash: current?.hash ?? 0))
                |> `catch` { _ -> Signal<Api.messages.EmojiGroups, NoError> in
                    return .single(.emojiGroupsNotModified)
                }
            case .status:
                signal = network.request(Api.functions.messages.getEmojiStatusGroups(hash: current?.hash ?? 0))
                |> `catch` { _ -> Signal<Api.messages.EmojiGroups, NoError> in
                    return .single(.emojiGroupsNotModified)
                }
            case .avatar:
                signal = network.request(Api.functions.messages.getEmojiProfilePhotoGroups(hash: current?.hash ?? 0))
                |> `catch` { _ -> Signal<Api.messages.EmojiGroups, NoError> in
                    return .single(.emojiGroupsNotModified)
                }
            }
        
            return signal
            |> mapToSignal { result -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> Signal<Never, NoError> in
                    switch result {
                    case let .emojiGroups(hash, groups):
                        let categories = EmojiSearchCategories(
                            hash: hash,
                            groups: groups.map { item -> EmojiSearchCategories.Group in
                                switch item {
                                case let .emojiGroup(title, iconEmojiId, emoticons):
                                    return EmojiSearchCategories.Group(
                                        id: iconEmojiId,
                                        title: title, identifiers: emoticons
                                    )
                                }
                            }
                        )
                        _internal_setCachedEmojiSearchCategories(transaction: transaction, categories: categories, kind: kind)
                    case .emojiGroupsNotModified:
                        break
                    }
                    
                    var fileIds: [Int64] = []
                    if let cached = _internal_cachedEmojiSearchCategories(transaction: transaction, kind: kind) {
                        for group in cached.groups {
                            fileIds.append(group.id)
                        }
                    }
                    return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: fileIds)
                    |> mapToSignal { files -> Signal<Never, NoError> in
                        var fetchSignals: Signal<Never, NoError> = .complete()
                        for (_, file) in files {
                            let signal = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: file.resource))
                            |> ignoreValues
                            |> `catch` { _ -> Signal<Never, NoError> in
                                return .complete()
                            }
                            fetchSignals = fetchSignals |> then(signal)
                        }
                        return fetchSignals
                    }
                }
                |> switchToLatest
            }
        }
                
        return signal.start(completed: {
            subscriber.putCompletion()
        })
    }
    
    return (
    	poll
    	|> then(
    		.complete()
    		|> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
    	)
    )
    |> restart
}
