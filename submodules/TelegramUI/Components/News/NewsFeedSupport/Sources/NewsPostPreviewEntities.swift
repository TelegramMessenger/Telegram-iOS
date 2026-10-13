import Foundation
import TelegramCore

/// The entities a feed row's three-line preview keeps: everything but block formatting. A block quote or code
/// block lays the text out in separate blocks, and the line limit does not hold across them, so the row ran on
/// with overlapping lines. Their text stays, inline.
public func newsPostPreviewEntities(_ entities: [MessageTextEntity]) -> [MessageTextEntity] {
    return entities.filter { entity in
        switch entity.type {
        case .BlockQuote, .Pre:
            return false
        default:
            return true
        }
    }
}
