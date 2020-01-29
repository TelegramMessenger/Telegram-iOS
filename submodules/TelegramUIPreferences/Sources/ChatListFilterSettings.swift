import Foundation
import Postbox
import SwiftSignalKit
import SyncCore

public struct ChatListIncludeCategoryFilter: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let muted = ChatListIncludeCategoryFilter(rawValue: 1 << 1)
    public static let privateChats = ChatListIncludeCategoryFilter(rawValue: 1 << 2)
    public static let secretChats = ChatListIncludeCategoryFilter(rawValue: 1 << 3)
    public static let privateGroups = ChatListIncludeCategoryFilter(rawValue: 1 << 4)
    public static let bots = ChatListIncludeCategoryFilter(rawValue: 1 << 5)
    public static let publicGroups = ChatListIncludeCategoryFilter(rawValue: 1 << 6)
    public static let channels = ChatListIncludeCategoryFilter(rawValue: 1 << 7)
    public static let read = ChatListIncludeCategoryFilter(rawValue: 1 << 8)
    
    public static let all: ChatListIncludeCategoryFilter = [
        .muted,
        .privateChats,
        .secretChats,
        .privateGroups,
        .bots,
        .publicGroups,
        .channels,
        .read
    ]
}

public enum ChatListFilterPresetName: Equatable, Hashable, PostboxCoding {
    case unread
    case custom(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
        case 0:
            self = .unread
        case 1:
            self = .custom(decoder.decodeStringForKey("title", orElse: "Preset"))
        default:
            assertionFailure()
            self = .custom("Preset")
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .unread:
            encoder.encodeInt32(0, forKey: "_t")
        case let .custom(title):
            encoder.encodeInt32(1, forKey: "_t")
            encoder.encodeString(title, forKey: "title")
        }
    }
}

public struct ChatListFilterPreset: Equatable, PostboxCoding {
    public var id: Int64
    public var name: ChatListFilterPresetName
    public var includeCategories: ChatListIncludeCategoryFilter
    public var additionallyIncludePeers: [PeerId]
    
    public init(id: Int64, name: ChatListFilterPresetName, includeCategories: ChatListIncludeCategoryFilter, additionallyIncludePeers: [PeerId]) {
        self.id = id
        self.name = name
        self.includeCategories = includeCategories
        self.additionallyIncludePeers = additionallyIncludePeers
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.name = decoder.decodeObjectForKey("name", decoder: { ChatListFilterPresetName(decoder: $0) }) as? ChatListFilterPresetName ?? ChatListFilterPresetName.custom("Preset")
        self.includeCategories = ChatListIncludeCategoryFilter(rawValue: decoder.decodeInt32ForKey("includeCategories", orElse: 0))
        self.additionallyIncludePeers = decoder.decodeInt64ArrayForKey("additionallyIncludePeers").map(PeerId.init)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeObject(self.name, forKey: "name")
        encoder.encodeInt32(self.includeCategories.rawValue, forKey: "includeCategories")
        encoder.encodeInt64Array(self.additionallyIncludePeers.map { $0.toInt64() }, forKey: "additionallyIncludePeers")
    }
}

public struct ChatListFilterSettings: PreferencesEntry, Equatable {
    public var presets: [ChatListFilterPreset]
    
    public static var `default`: ChatListFilterSettings {
        return ChatListFilterSettings(presets: [
            ChatListFilterPreset(
                id: Int64(arc4random()),
                name: .unread,
                includeCategories: ChatListIncludeCategoryFilter.all.subtracting(.read),
                additionallyIncludePeers: []
            )
        ])
    }
    
    public init(presets: [ChatListFilterPreset]) {
        self.presets = presets
    }
    
    public init(decoder: PostboxDecoder) {
        self.presets = decoder.decodeObjectArrayWithDecoderForKey("presets")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.presets, forKey: "presets")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFilterSettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateChatListFilterSettingsInteractively(postbox: Postbox, _ f: @escaping (ChatListFilterSettings) -> ChatListFilterSettings) -> Signal<ChatListFilterSettings, NoError> {
    return postbox.transaction { transaction -> ChatListFilterSettings in
        var result: ChatListFilterSettings?
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatListFilterSettings, { entry in
            var settings = entry as? ChatListFilterSettings ?? ChatListFilterSettings.default
            let updated = f(settings)
            result = updated
            return updated
        })
        return result ?? .default
    }
}
