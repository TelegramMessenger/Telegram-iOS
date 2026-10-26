import Foundation
import TelegramCore

/// For you always shows exactly one "What are you interested in?" block: where the server put it, or on
/// top when the server sent none. Without it an account with no interests selected gets an empty feed
/// and no way to pick any.
public func newsForYouItemsShowingInterests(_ items: [EngineForYouItem]) -> [EngineForYouItem] {
    var result: [EngineForYouItem] = []
    var hasInterests = false
    for item in items {
        if case .interests = item {
            if hasInterests {
                continue
            }
            hasInterests = true
        }
        result.append(item)
    }
    if !hasInterests {
        result.insert(.interests, at: 0)
    }
    return result
}
