import Foundation
import TelegramCore

struct ChatSearchState: Equatable {
    let query: String
    let location: SearchMessagesLocation
    let loadMoreState: SearchMessagesState?
}
