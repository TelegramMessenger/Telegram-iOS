import Foundation

final class ChatRecentActionsInteraction {
    let displayInfoAlert: () -> Void
    
    init(displayInfoAlert: @escaping () -> Void) {
        self.displayInfoAlert = displayInfoAlert
    }
}
