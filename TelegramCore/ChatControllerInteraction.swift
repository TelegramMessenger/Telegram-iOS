import Foundation
import Postbox
import AsyncDisplayKit

final class ChatControllerInteraction {
    let openMessage: (MessageId) -> Void
    let testNavigateToMessage: (MessageId, MessageId) -> Void
    var hiddenMedia: [MessageId: [Media]] = [:]
    
    init(openMessage: (MessageId) -> Void, testNavigateToMessage: (MessageId, MessageId) -> Void) {
        self.openMessage = openMessage
        self.testNavigateToMessage = testNavigateToMessage
    }
}
