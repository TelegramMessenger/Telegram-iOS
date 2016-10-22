import Foundation
import Postbox

final class ChatPanelInterfaceInteraction {
    let setupReplyMessage: (MessageId) -> Void
    let beginMessageSelection: (MessageId) -> Void
    let deleteSelectedMessages: () -> Void
    let forwardSelectedMessages: () -> Void
    let updateTextInputState: (ChatTextInputState) -> Void
    let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    
    init(setupReplyMessage: @escaping (MessageId) -> Void, beginMessageSelection: @escaping (MessageId) -> Void, deleteSelectedMessages: @escaping () -> Void, forwardSelectedMessages: @escaping () -> Void, updateTextInputState: @escaping (ChatTextInputState) -> Void, updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void) {
        self.setupReplyMessage = setupReplyMessage
        self.beginMessageSelection = beginMessageSelection
        self.deleteSelectedMessages = deleteSelectedMessages
        self.forwardSelectedMessages = forwardSelectedMessages
        self.updateTextInputState = updateTextInputState
        self.updateInputMode = updateInputMode
    }
}
