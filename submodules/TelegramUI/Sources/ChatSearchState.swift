import Foundation
import Postbox
import TelegramCore
import SyncCore

struct ChatSearchState: Equatable {
    let query: String
    let location: SearchMessagesLocation
    let loadMoreState: SearchMessagesState?
}
