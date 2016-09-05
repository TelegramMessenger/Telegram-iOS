import Foundation

final class ChatPanelInterfaceInteraction {
    let deleteSelectedMessages: () -> Void
    let forwardSelectedMessages: () -> Void
    
    init(deleteSelectedMessages: @escaping () -> Void, forwardSelectedMessages: @escaping () -> Void) {
        self.deleteSelectedMessages = deleteSelectedMessages
        self.forwardSelectedMessages = forwardSelectedMessages
    }
}
