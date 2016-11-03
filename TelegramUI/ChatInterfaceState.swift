import Foundation
import Postbox

struct ChatInterfaceSelectionState: Coding, Equatable {
    let selectedIds: Set<MessageId>
    
    static func ==(lhs: ChatInterfaceSelectionState, rhs: ChatInterfaceSelectionState) -> Bool {
        return lhs.selectedIds == rhs.selectedIds
    }
    
    init(selectedIds: Set<MessageId>) {
        self.selectedIds = selectedIds
    }
    
    init(decoder: Decoder) {
        if let data = decoder.decodeBytesForKeyNoCopy("i") {
            self.selectedIds = Set(MessageId.decodeArrayFromBuffer(data))
        } else {
            self.selectedIds = Set()
        }
    }
    
    func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        MessageId.encodeArrayToBuffer(Array(selectedIds), buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
    }
}

struct ChatTextInputState: Coding, Equatable {
    let inputText: String
    let selectionRange: Range<Int>
    
    static func ==(lhs: ChatTextInputState, rhs: ChatTextInputState) -> Bool {
        return lhs.inputText == rhs.inputText && lhs.selectionRange == rhs.selectionRange
    }
    
    init() {
        self.inputText = ""
        self.selectionRange = 0 ..< 0
    }
    
    init(inputText: String, selectionRange: Range<Int>) {
        self.inputText = inputText
        self.selectionRange = selectionRange
    }
    
    init(decoder: Decoder) {
        self.inputText = decoder.decodeStringForKey("t")
        self.selectionRange = Int(decoder.decodeInt32ForKey("s0")) ..< Int(decoder.decodeInt32ForKey("s1"))
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeString(self.inputText, forKey: "t")
        encoder.encodeInt32(Int32(self.selectionRange.lowerBound), forKey: "s0")
        encoder.encodeInt32(Int32(self.selectionRange.upperBound), forKey: "s1")
    }
}

final class ChatEmbeddedInterfaceState: PeerChatListEmbeddedInterfaceState {
    let timestamp: Int32
    let text: String
    
    init(timestamp: Int32, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
    
    init(decoder: Decoder) {
        self.timestamp = decoder.decodeInt32ForKey("d")
        self.text = decoder.decodeStringForKey("t")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.timestamp, forKey: "d")
        encoder.encodeString(self.text, forKey: "t")
    }
    
    public func isEqual(to: PeerChatListEmbeddedInterfaceState) -> Bool {
        if let to = to as? ChatEmbeddedInterfaceState {
            return self.timestamp == to.timestamp && self.text == to.text
        } else {
            return false
        }
    }
}

final class ChatInterfaceState: PeerChatInterfaceState, Equatable {
    let timestamp: Int32
    let inputState: ChatTextInputState
    let replyMessageId: MessageId?
    let forwardMessageIds: [MessageId]?
    let selectionState: ChatInterfaceSelectionState?
    
    var chatListEmbeddedState: PeerChatListEmbeddedInterfaceState? {
        if !self.inputState.inputText.isEmpty && self.timestamp != 0 {
            return ChatEmbeddedInterfaceState(timestamp: self.timestamp, text: self.inputState.inputText)
        } else {
            return nil
        }
    }
    
    init() {
        self.timestamp = 0
        self.inputState = ChatTextInputState()
        self.replyMessageId = nil
        self.forwardMessageIds = nil
        self.selectionState = nil
    }
    
    init(timestamp: Int32, inputState: ChatTextInputState, replyMessageId: MessageId?, forwardMessageIds: [MessageId]?, selectionState: ChatInterfaceSelectionState?) {
        self.timestamp = timestamp
        self.inputState = inputState
        self.replyMessageId = replyMessageId
        self.forwardMessageIds = forwardMessageIds
        self.selectionState = selectionState
    }
    
    init(decoder: Decoder) {
        self.timestamp = decoder.decodeInt32ForKey("ts")
        if let inputState = decoder.decodeObjectForKey("is", decoder: { return ChatTextInputState(decoder: $0) }) as? ChatTextInputState {
            self.inputState = inputState
        } else {
            self.inputState = ChatTextInputState()
        }
        let replyMessageIdPeerId: Int64? = decoder.decodeInt64ForKey("r.p")
        let replyMessageIdNamespace: Int32? = decoder.decodeInt32ForKey("r.n")
        let replyMessageIdId: Int32? = decoder.decodeInt32ForKey("r.i")
        if let replyMessageIdPeerId = replyMessageIdPeerId, let replyMessageIdNamespace = replyMessageIdNamespace, let replyMessageIdId = replyMessageIdId {
            self.replyMessageId = MessageId(peerId: PeerId(replyMessageIdPeerId), namespace: replyMessageIdNamespace, id: replyMessageIdId)
        } else {
            self.replyMessageId = nil
        }
        if let forwardMessageIdsData = decoder.decodeBytesForKeyNoCopy("fm") {
            self.forwardMessageIds = MessageId.decodeArrayFromBuffer(forwardMessageIdsData)
        } else {
            self.forwardMessageIds = nil
        }
        if let selectionState = decoder.decodeObjectForKey("ss", decoder: { return ChatInterfaceSelectionState(decoder: $0) }) as? ChatInterfaceSelectionState {
            self.selectionState = selectionState
        } else {
            self.selectionState = nil
        }
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.timestamp, forKey: "ts")
        encoder.encodeObject(self.inputState, forKey: "is")
        if let replyMessageId = self.replyMessageId {
            encoder.encodeInt64(replyMessageId.peerId.toInt64(), forKey: "r.p")
            encoder.encodeInt32(replyMessageId.namespace, forKey: "r.n")
            encoder.encodeInt32(replyMessageId.id, forKey: "r.i")
        } else {
            encoder.encodeNil(forKey: "r.p")
            encoder.encodeNil(forKey: "r.n")
            encoder.encodeNil(forKey: "r.i")
        }
        if let forwardMessageIds = self.forwardMessageIds {
            let buffer = WriteBuffer()
            MessageId.encodeArrayToBuffer(forwardMessageIds, buffer: buffer)
            encoder.encodeBytes(buffer, forKey: "fm")
        } else {
            encoder.encodeNil(forKey: "fm")
        }
        if let selectionState = self.selectionState {
            encoder.encodeObject(selectionState, forKey: "ss")
        } else {
            encoder.encodeNil(forKey: "ss")
        }
    }
    
    func isEqual(to: PeerChatInterfaceState) -> Bool {
        if let to = to as? ChatInterfaceState, self == to {
            return true
        } else {
            return false
        }
    }
    
    static func ==(lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        if let lhsForwardMessageIds = lhs.forwardMessageIds, let rhsForwardMessageIds = rhs.forwardMessageIds {
            if lhsForwardMessageIds != rhsForwardMessageIds {
                return false
            }
        } else if (lhs.forwardMessageIds != nil) != (rhs.forwardMessageIds != nil) {
            return false
        }
        return lhs.inputState == rhs.inputState && lhs.replyMessageId == rhs.replyMessageId && lhs.selectionState == rhs.selectionState
    }
    
    func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: inputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: self.selectionState)
    }
    
    func withUpdatedReplyMessageId(_ replyMessageId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: self.selectionState)
    }
    
    func withUpdatedForwardMessageIds(_ forwardMessageIds: [MessageId]?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, forwardMessageIds: forwardMessageIds, selectionState: self.selectionState)
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> ChatInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> ChatInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.contains(messageId) {
            let _ = selectedIds.remove(messageId)
        } else {
            selectedIds.insert(messageId)
        }
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
    }
    
    func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: nil)
    }
    
    func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, selectionState: self.selectionState)
    }
}
