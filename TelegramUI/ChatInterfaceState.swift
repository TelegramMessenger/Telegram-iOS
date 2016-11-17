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
    
    init(inputText: String) {
        self.inputText = inputText
        let length = (inputText as NSString).length
        self.selectionRange = length ..< length
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

struct ChatEditMessageState: Coding, Equatable {
    let messageId: MessageId
    let inputState: ChatTextInputState
    
    init(messageId: MessageId, inputState: ChatTextInputState) {
        self.messageId = messageId
        self.inputState = inputState
    }
    
    init(decoder: Decoder) {
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("mp")), namespace: decoder.decodeInt32ForKey("mn"), id: decoder.decodeInt32ForKey("mi"))
        if let inputState = decoder.decodeObjectForKey("is", decoder: { return ChatTextInputState(decoder: $0) }) as? ChatTextInputState {
            self.inputState = inputState
        } else {
            self.inputState = ChatTextInputState()
        }
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "mp")
        encoder.encodeInt32(self.messageId.namespace, forKey: "mn")
        encoder.encodeInt32(self.messageId.id, forKey: "mi")
        encoder.encodeObject(self.inputState, forKey: "is")
    }
    
    static func ==(lhs: ChatEditMessageState, rhs: ChatEditMessageState) -> Bool {
        return lhs.messageId == rhs.messageId && lhs.inputState == rhs.inputState
    }
    
    func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatEditMessageState {
        return ChatEditMessageState(messageId: self.messageId, inputState: inputState)
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
    let composeInputState: ChatTextInputState
    let replyMessageId: MessageId?
    let forwardMessageIds: [MessageId]?
    let editMessage: ChatEditMessageState?
    let selectionState: ChatInterfaceSelectionState?
    
    var chatListEmbeddedState: PeerChatListEmbeddedInterfaceState? {
        if !self.composeInputState.inputText.isEmpty && self.timestamp != 0 {
            return ChatEmbeddedInterfaceState(timestamp: self.timestamp, text: self.composeInputState.inputText)
        } else {
            return nil
        }
    }
    
    var effectiveInputState: ChatTextInputState {
        if let editMessage = self.editMessage {
            return editMessage.inputState
        } else {
            return self.composeInputState
        }
    }
    
    init() {
        self.timestamp = 0
        self.composeInputState = ChatTextInputState()
        self.replyMessageId = nil
        self.forwardMessageIds = nil
        self.editMessage = nil
        self.selectionState = nil
    }
    
    init(timestamp: Int32, composeInputState: ChatTextInputState, replyMessageId: MessageId?, forwardMessageIds: [MessageId]?, editMessage: ChatEditMessageState?, selectionState: ChatInterfaceSelectionState?) {
        self.timestamp = timestamp
        self.composeInputState = composeInputState
        self.replyMessageId = replyMessageId
        self.forwardMessageIds = forwardMessageIds
        self.editMessage = editMessage
        self.selectionState = selectionState
    }
    
    init(decoder: Decoder) {
        self.timestamp = decoder.decodeInt32ForKey("ts")
        if let inputState = decoder.decodeObjectForKey("is", decoder: { return ChatTextInputState(decoder: $0) }) as? ChatTextInputState {
            self.composeInputState = inputState
        } else {
            self.composeInputState = ChatTextInputState()
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
        if let editMessage = decoder.decodeObjectForKey("em", decoder: { ChatEditMessageState(decoder: $0) }) as? ChatEditMessageState {
            self.editMessage = editMessage
        } else {
            self.editMessage = nil
        }
        if let selectionState = decoder.decodeObjectForKey("ss", decoder: { return ChatInterfaceSelectionState(decoder: $0) }) as? ChatInterfaceSelectionState {
            self.selectionState = selectionState
        } else {
            self.selectionState = nil
        }
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.timestamp, forKey: "ts")
        encoder.encodeObject(self.composeInputState, forKey: "is")
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
        if let editMessage = self.editMessage {
            encoder.encodeObject(editMessage, forKey: "em")
        } else {
            encoder.encodeNil(forKey: "em")
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
        return lhs.composeInputState == rhs.composeInputState && lhs.replyMessageId == rhs.replyMessageId && lhs.selectionState == rhs.selectionState && lhs.editMessage == rhs.editMessage
    }
    
    func withUpdatedEffectiveInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        var updatedEditMessage = self.editMessage
        var updatedComposeInputState = self.composeInputState
        if let editMessage = self.editMessage {
            updatedEditMessage = editMessage.withUpdatedInputState(inputState)
        } else {
            updatedComposeInputState = inputState
        }
        
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: updatedComposeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: updatedEditMessage, selectionState: self.selectionState)
    }
    
    func withUpdatedReplyMessageId(_ replyMessageId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: self.editMessage, selectionState: self.selectionState)
    }
    
    func withUpdatedForwardMessageIds(_ forwardMessageIds: [MessageId]?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: forwardMessageIds, editMessage: self.editMessage, selectionState: self.selectionState)
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> ChatInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
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
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: self.editMessage, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
    }
    
    func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: self.editMessage, selectionState: nil)
    }
    
    func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: self.editMessage, selectionState: self.selectionState)
    }
    
    func withUpdatedEditMessage(_ editMessage: ChatEditMessageState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, composeInputState: self.composeInputState, replyMessageId: self.replyMessageId, forwardMessageIds: self.forwardMessageIds, editMessage: editMessage, selectionState: self.selectionState)
    }
}
