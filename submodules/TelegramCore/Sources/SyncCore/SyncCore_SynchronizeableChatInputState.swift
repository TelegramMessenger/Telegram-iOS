import Foundation
import Postbox

public struct SynchronizeableChatInputState: Codable, Equatable {
    public struct SuggestedPost: Codable, Equatable {
        public var price: CurrencyAmount?
        public var timestamp: Int32?
        
        public init(price: CurrencyAmount?, timestamp: Int32?) {
            self.price = price
            self.timestamp = timestamp
        }
    }
    
    /// The draft body. Either a flat text + entity list (the legacy / cloud
    /// currency every existing client understands), or a structured
    /// `InstantPage` for drafts that carry structure the entity set can't
    /// represent. Old clients degrade an `.instantPage` draft to its
    /// `plainText` projection with no entities (see the derived accessors).
    public enum Content: Equatable {
        case textEntities(text: String, entities: [MessageTextEntity])
        case instantPage(InstantPage)
    }

    public let replySubject: EngineMessageReplySubject?
    public let content: Content
    public let timestamp: Int32
    public let textSelection: Range<Int>?
    public let messageEffectId: Int64?
    public let suggestedPost: SuggestedPost?

    /// Derived flat-text view of `content` (old-client / cloud fallback).
    public var text: String {
        switch self.content {
        case let .textEntities(text, _):
            return text
        case let .instantPage(page):
            return page.plainText
        }
    }

    /// Derived entity view of `content`. An `.instantPage` draft carries no
    /// flat entities — old clients see only its `plainText`.
    public var entities: [MessageTextEntity] {
        switch self.content {
        case let .textEntities(_, entities):
            return entities
        case .instantPage:
            return []
        }
    }

    public init(replySubject: EngineMessageReplySubject?, content: Content, timestamp: Int32, textSelection: Range<Int>?, messageEffectId: Int64?, suggestedPost: SuggestedPost?) {
        self.replySubject = replySubject
        self.content = content
        self.timestamp = timestamp
        self.textSelection = textSelection
        self.messageEffectId = messageEffectId
        self.suggestedPost = suggestedPost
    }

    public init(replySubject: EngineMessageReplySubject?, text: String, entities: [MessageTextEntity], timestamp: Int32, textSelection: Range<Int>?, messageEffectId: Int64?, suggestedPost: SuggestedPost?) {
        self.init(replySubject: replySubject, content: .textEntities(text: text, entities: entities), timestamp: timestamp, textSelection: textSelection, messageEffectId: messageEffectId, suggestedPost: suggestedPost)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        if let instantPageData = try? container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "ip") {
            self.content = .instantPage(InstantPage(decoder: PostboxDecoder(buffer: MemoryBuffer(data: instantPageData.data))))
        } else {
            let text = (try? container.decode(String.self, forKey: "t")) ?? ""
            let entities = (try? container.decode([MessageTextEntity].self, forKey: "e")) ?? []
            self.content = .textEntities(text: text, entities: entities)
        }
        self.timestamp = (try? container.decode(Int32.self, forKey: "s")) ?? 0

        if let replySubject = try? container.decodeIfPresent(EngineMessageReplySubject.self, forKey: "rep") {
            self.replySubject = replySubject
        } else {
            if let messageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "m.p"), let messageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "m.n"), let messageIdId = try? container.decodeIfPresent(Int32.self, forKey: "m.i") {
                self.replySubject = EngineMessageReplySubject(messageId: MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId), quote: nil, innerSubject: nil)
            } else {
                self.replySubject = nil
            }
        }
        if let textSelectionFrom = try? container.decodeIfPresent(Int32.self, forKey: "ts0"), let textSelectionTo = try? container.decode(Int32.self, forKey: "ts1"), textSelectionFrom <= textSelectionTo {
            self.textSelection = Int(textSelectionFrom) ..< Int(textSelectionTo)
        } else {
            self.textSelection = nil
        }
        self.messageEffectId = try container.decodeIfPresent(Int64.self, forKey: "messageEffectId")
        self.suggestedPost = try container.decodeIfPresent(SuggestedPost.self, forKey: "suggestedPost")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self.content {
        case let .textEntities(text, entities):
            try container.encode(text, forKey: "t")
            try container.encode(entities, forKey: "e")
        case let .instantPage(page):
            try container.encode(PostboxEncoder().encodeObjectToRawData(page), forKey: "ip")
        }
        try container.encode(self.timestamp, forKey: "s")
        if let textSelection = self.textSelection {
            try container.encode(Int32(clamping: textSelection.lowerBound), forKey: "ts0")
            try container.encode(Int32(clamping: textSelection.upperBound), forKey: "ts1")
        }
        try container.encodeIfPresent(self.replySubject, forKey: "rep")
        try container.encodeIfPresent(self.messageEffectId, forKey: "messageEffectId")
        try container.encodeIfPresent(self.suggestedPost, forKey: "suggestedPost")
    }
    
    public static func ==(lhs: SynchronizeableChatInputState, rhs: SynchronizeableChatInputState) -> Bool {
        if lhs.replySubject != rhs.replySubject {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.textSelection != rhs.textSelection {
            return false
        }
        if lhs.messageEffectId != rhs.messageEffectId {
            return false
        }
        if lhs.suggestedPost != rhs.suggestedPost {
            return false
        }
        return true
    }
}

class InternalChatInterfaceState: Codable {
    let synchronizeableInputState: SynchronizeableChatInputState?
    let historyScrollMessageIndex: MessageIndex?
    let mediaDraftState: MediaDraftState?
    let opaqueData: Data?

    init(
        synchronizeableInputState: SynchronizeableChatInputState?,
        historyScrollMessageIndex: MessageIndex?,
        mediaDraftState: MediaDraftState?,
        opaqueData: Data?
    ) {
        self.synchronizeableInputState = synchronizeableInputState
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.mediaDraftState = mediaDraftState
        self.opaqueData = opaqueData
    }
}

public struct MediaDraftState: Codable, Equatable {
    public let contentType: EngineChatList.MediaDraftContentType
    public let timestamp: Int32
    
    public init(contentType: EngineChatList.MediaDraftContentType, timestamp: Int32) {
        self.contentType = contentType
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.contentType = EngineChatList.MediaDraftContentType(rawValue: try container.decode(Int32.self, forKey: "t")) ?? .audio
        self.timestamp = (try? container.decode(Int32.self, forKey: "s")) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.contentType.rawValue, forKey: "t")
        try container.encode(self.timestamp, forKey: "s")
    }
    
    public static func ==(lhs: MediaDraftState, rhs: MediaDraftState) -> Bool {
        if lhs.contentType != rhs.contentType {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}

func _internal_updateChatInputState(transaction: Transaction, peerId: PeerId, threadId: Int64?, inputState: SynchronizeableChatInputState?) {
    var previousState: InternalChatInterfaceState?
    if let threadId = threadId {
        if let peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId), let data = peerChatInterfaceState.data {
            previousState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))
        }
    } else {
        if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
            previousState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))
        }
    }
    
    var overrideChatTimestamp: Int32?
    if let inputState = inputState {
        overrideChatTimestamp = inputState.timestamp
    }
    
    if let mediaDraftState = previousState?.mediaDraftState {
        if let current = overrideChatTimestamp, mediaDraftState.timestamp < current {
        } else {
            overrideChatTimestamp = mediaDraftState.timestamp
        }
    }

    if let updatedStateData = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
        synchronizeableInputState: inputState,
        historyScrollMessageIndex: previousState?.historyScrollMessageIndex,
        mediaDraftState: previousState?.mediaDraftState,
        opaqueData: previousState?.opaqueData
    )) {
        let storedState = StoredPeerChatInterfaceState(
            overrideChatTimestamp: overrideChatTimestamp,
            historyScrollMessageIndex: previousState?.historyScrollMessageIndex,
            associatedMessageIds: (inputState?.replySubject?.messageId).flatMap({ [$0] }) ?? [],
            data: updatedStateData
        )
        if let threadId = threadId {
            transaction.setPeerChatThreadInterfaceState(peerId, threadId: threadId, state: storedState)
        } else {
            transaction.setPeerChatInterfaceState(peerId, state: storedState)
        }
    }
}
