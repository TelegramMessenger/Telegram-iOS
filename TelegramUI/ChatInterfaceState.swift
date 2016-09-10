import Foundation
import Postbox

struct ChatInterfaceSelectionState: Equatable {
    let selectedIds: Set<MessageId>
    
    static func ==(lhs: ChatInterfaceSelectionState, rhs: ChatInterfaceSelectionState) -> Bool {
        return lhs.selectedIds == rhs.selectedIds
    }
}

struct ChatTextInputState: Equatable {
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
}

final class ChatInterfaceState: Equatable {
    let inputState: ChatTextInputState
    let replyMessageId: MessageId?
    let selectionState: ChatInterfaceSelectionState?
    
    init() {
        self.inputState = ChatTextInputState()
        self.replyMessageId = nil
        self.selectionState = nil
    }
    
    init(inputState: ChatTextInputState, replyMessageId: MessageId?, selectionState: ChatInterfaceSelectionState?) {
        self.inputState = inputState
        self.replyMessageId = replyMessageId
        self.selectionState = selectionState
    }
    
    static func ==(lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        return lhs.inputState == rhs.inputState && lhs.replyMessageId == rhs.replyMessageId && lhs.selectionState == rhs.selectionState
    }
    
    func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        return ChatInterfaceState(inputState: inputState, replyMessageId: self.replyMessageId, selectionState: self.selectionState)
    }
    
    func withUpdatedReplyMessageId(_ replyMessageId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(inputState: self.inputState, replyMessageId: replyMessageId, selectionState: self.selectionState)
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> ChatInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return ChatInterfaceState(inputState: self.inputState, replyMessageId: self.replyMessageId, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
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
        return ChatInterfaceState(inputState: self.inputState, replyMessageId: self.replyMessageId, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
    }
    
    func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(inputState: self.inputState, replyMessageId: self.replyMessageId, selectionState: nil)
    }
}
