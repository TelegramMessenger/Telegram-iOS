import Foundation
import Postbox
import AsyncDisplayKit

public final class ChatControllerInteraction {
    let openMessage: (MessageId) -> Void
    let testNavigateToMessage: (MessageId, MessageId) -> Void
    var hiddenMedia: [MessageId: [Media]] = [:]
    
    public init(openMessage: (MessageId) -> Void, testNavigateToMessage: (MessageId, MessageId) -> Void) {
        self.openMessage = openMessage
        self.testNavigateToMessage = testNavigateToMessage
    }
}
