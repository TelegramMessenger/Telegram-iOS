import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public final class QuickReplyMessageShortcut: Codable, Equatable {
    private final class CodableMessage: Codable {
        let message: Message
        
        init(message: Message) {
            self.message = message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            
            var media: [Media] = []
            if let mediaData = try container.decodeIfPresent(Data.self, forKey: "media") {
                if let value = PostboxDecoder(buffer: MemoryBuffer(data: mediaData)).decodeRootObject() as? Media {
                    media.append(value)
                }
            }
            
            var attributes: [MessageAttribute] = []
            if let attributesData = try container.decodeIfPresent([Data].self, forKey: "attributes") {
                for attribute in attributesData {
                    if let value = PostboxDecoder(buffer: MemoryBuffer(data: attribute)).decodeRootObject() as? MessageAttribute {
                        attributes.append(value)
                    }
                }
            }
            
            self.message = Message(
                stableId: 0,
                stableVersion: 0,
                id: MessageId(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(0)), namespace: 0, id: 0),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: 0,
                flags: [],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: nil,
                text: try container.decode(String.self, forKey: "text"),
                attributes: attributes,
                media: media,
                peers: SimpleDictionary(),
                associatedMessages: SimpleDictionary(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            
            if let media = self.message.media.first {
                let mediaEncoder = PostboxEncoder()
                mediaEncoder.encodeRootObject(media)
                try container.encode(mediaEncoder.makeData(), forKey: "media")
            }
            
            var attributesData: [Data] = []
            for attribute in self.message.attributes {
                let attributeEncoder = PostboxEncoder()
                attributeEncoder.encodeRootObject(attribute)
                attributesData.append(attributeEncoder.makeData())
            }
            try container.encode(attributesData, forKey: "attributes")
            
            try container.encode(self.message.text, forKey: "text")
        }
    }

    public let id: Int32
    public let shortcut: String
    public let messages: [EngineMessage]

    public init(id: Int32, shortcut: String, messages: [EngineMessage]) {
        self.id = id
        self.shortcut = shortcut
        self.messages = messages
    }
    
    public static func ==(lhs: QuickReplyMessageShortcut, rhs: QuickReplyMessageShortcut) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.shortcut != rhs.shortcut {
            return false
        }
        if lhs.messages != rhs.messages {
            return false
        }
        return true
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.id = try container.decode(Int32.self, forKey: "id")
        self.shortcut = try container.decode(String.self, forKey: "shortcut")
        self.messages = try container.decode([CodableMessage].self, forKey: "messages").map { EngineMessage($0.message) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.id, forKey: "id")
        try container.encode(self.shortcut, forKey: "shortcut")
        try container.encode(self.messages.map { CodableMessage(message: $0._asMessage()) }, forKey: "messages")
    }
}

public final class QuickReplyMessageShortcutsState: Codable, Equatable {
    public let shortcuts: [QuickReplyMessageShortcut]
    
    public init(shortcuts: [QuickReplyMessageShortcut]) {
        self.shortcuts = shortcuts
    }
    
    public static func ==(lhs: QuickReplyMessageShortcutsState, rhs: QuickReplyMessageShortcutsState) -> Bool {
        if lhs.shortcuts != rhs.shortcuts {
            return false
        }
        return true
    }
}

func _internal_shortcutMessages(account: Account) -> Signal<QuickReplyMessageShortcutsState, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.shortcutMessages()]))
    return account.postbox.combinedView(keys: [viewKey])
    |> map { views -> QuickReplyMessageShortcutsState in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return QuickReplyMessageShortcutsState(shortcuts: [])
        }
        guard let value = view.values[PreferencesKeys.shortcutMessages()]?.get(QuickReplyMessageShortcutsState.self) else {
            return QuickReplyMessageShortcutsState(shortcuts: [])
        }
        return value
    }
}

func _internal_updateShortcutMessages(account: Account, state: QuickReplyMessageShortcutsState) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.setPreferencesEntry(key: PreferencesKeys.shortcutMessages(), value: PreferencesEntry(state))
    }
    |> ignoreValues
}
