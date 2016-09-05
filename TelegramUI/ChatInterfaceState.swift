import Foundation
import Postbox

struct ChatInterfaceSelectionState: Equatable {
    let selectedIds: Set<MessageId>
    
    static func ==(lhs: ChatInterfaceSelectionState, rhs: ChatInterfaceSelectionState) -> Bool {
        return lhs.selectedIds == rhs.selectedIds
    }
}

final class ChatInterfaceState: Equatable {
    let inputText: String?
    let replyMessageId: MessageId?
    let selectionState: ChatInterfaceSelectionState?
    
    init() {
        self.inputText = nil
        self.replyMessageId = nil
        self.selectionState = nil
    }
    
    init(inputText: String?, replyMessageId: MessageId?, selectionState: ChatInterfaceSelectionState?) {
        self.inputText = inputText
        self.replyMessageId = replyMessageId
        self.selectionState = selectionState
    }
    
    static func ==(lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        return lhs.inputText == rhs.inputText && lhs.replyMessageId == rhs.replyMessageId && lhs.selectionState == rhs.selectionState
    }
    
    func withUpdatedReplyMessageId(_ replyMessageId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(inputText: self.inputText, replyMessageId: replyMessageId, selectionState: self.selectionState)
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> ChatInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return ChatInterfaceState(inputText: self.inputText, replyMessageId: self.replyMessageId, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
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
        return ChatInterfaceState(inputText: self.inputText, replyMessageId: self.replyMessageId, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds))
    }
    
    func withoutSelectionState() -> ChatInterfaceState {
        return ChatInterfaceState(inputText: self.inputText, replyMessageId: self.replyMessageId, selectionState: nil)
    }
}
