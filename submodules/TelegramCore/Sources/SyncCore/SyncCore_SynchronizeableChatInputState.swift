import Foundation
import Postbox

public struct SynchronizeableChatInputState: Codable, Equatable {
    public let replySubject: EngineMessageReplySubject?
    public let text: String
    public let entities: [MessageTextEntity]
    public let timestamp: Int32
    public let textSelection: Range<Int>?
    
    public init(replySubject: EngineMessageReplySubject?, text: String, entities: [MessageTextEntity], timestamp: Int32, textSelection: Range<Int>?) {
        self.replySubject = replySubject
        self.text = text
        self.entities = entities
        self.timestamp = timestamp
        self.textSelection = textSelection
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
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.text, forKey: "t")
        try container.encode(self.entities, forKey: "e")
        try container.encode(self.timestamp, forKey: "s")
        try container.encodeIfPresent(self.replySubject, forKey: "rep")
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
        return true
    }
}

class InternalChatInterfaceState: Codable {
    let synchronizeableInputState: SynchronizeableChatInputState?
    let historyScrollMessageIndex: MessageIndex?
    let opaqueData: Data?

    init(
        synchronizeableInputState: SynchronizeableChatInputState?,
        historyScrollMessageIndex: MessageIndex?,
        opaqueData: Data?
    ) {
        self.synchronizeableInputState = synchronizeableInputState
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.opaqueData = opaqueData
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

    if let updatedStateData = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
        synchronizeableInputState: inputState,
        historyScrollMessageIndex: previousState?.historyScrollMessageIndex,
        opaqueData: previousState?.opaqueData
    )) {
        let storedState = StoredPeerChatInterfaceState(
            overrideChatTimestamp: inputState?.timestamp,
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
