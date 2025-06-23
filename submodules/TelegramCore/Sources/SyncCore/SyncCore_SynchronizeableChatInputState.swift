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
    
    public let replySubject: EngineMessageReplySubject?
    public let text: String
    public let entities: [MessageTextEntity]
    public let timestamp: Int32
    public let textSelection: Range<Int>?
    public let messageEffectId: Int64?
    public let suggestedPost: SuggestedPost?
    
    public init(replySubject: EngineMessageReplySubject?, text: String, entities: [MessageTextEntity], timestamp: Int32, textSelection: Range<Int>?, messageEffectId: Int64?, suggestedPost: SuggestedPost?) {
        self.replySubject = replySubject
        self.text = text
        self.entities = entities
        self.timestamp = timestamp
        self.textSelection = textSelection
        self.messageEffectId = messageEffectId
        self.suggestedPost = suggestedPost
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.text = (try? container.decode(String.self, forKey: "t")) ?? ""
        self.entities = (try? container.decode([MessageTextEntity].self, forKey: "e")) ?? []
        self.timestamp = (try? container.decode(Int32.self, forKey: "s")) ?? 0

        if let replySubject = try? container.decodeIfPresent(EngineMessageReplySubject.self, forKey: "rep") {
            self.replySubject = replySubject
        } else {
            if let messageIdPeerId = try? container.decodeIfPresent(Int64.self, forKey: "m.p"), let messageIdNamespace = try? container.decodeIfPresent(Int32.self, forKey: "m.n"), let messageIdId = try? container.decodeIfPresent(Int32.self, forKey: "m.i") {
                self.replySubject = EngineMessageReplySubject(messageId: MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId), quote: nil)
            } else {
                self.replySubject = nil
            }
        }
        self.textSelection = nil
        self.messageEffectId = try container.decodeIfPresent(Int64.self, forKey: "messageEffectId")
        self.suggestedPost = try container.decodeIfPresent(SuggestedPost.self, forKey: "suggestedPost")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.text, forKey: "t")
        try container.encode(self.entities, forKey: "e")
        try container.encode(self.timestamp, forKey: "s")
        try container.encodeIfPresent(self.replySubject, forKey: "rep")
        try container.encodeIfPresent(self.messageEffectId, forKey: "messageEffectId")
        try container.encodeIfPresent(self.suggestedPost, forKey: "suggestedPost")
    }
    
    public static func ==(lhs: SynchronizeableChatInputState, rhs: SynchronizeableChatInputState) -> Bool {
        if lhs.replySubject != rhs.replySubject {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
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
