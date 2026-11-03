import Foundation

/// What the For you list shows besides its posts and the interests block. Decided by posts alone: the
/// interests block is always there, so an empty feed shows it with the empty state under it.
public enum NewsForYouListStatus: Equatable {
    /// Nothing to show yet: shimmering placeholder rows.
    case placeholders
    /// The first batch failed: an error row with Retry.
    case error
    /// The server had nothing for this user: an empty-state row with Refresh.
    case empty
    /// A placeholder row under the posts while the next batch loads.
    case loadingMore
    /// The next batch failed: a Retry row under the posts.
    case loadMoreFailed
    case none
}

public func newsForYouListStatus(hasPosts: Bool, didLoadSnapshot: Bool, isLoadingMore: Bool, isExhausted: Bool, hasError: Bool) -> NewsForYouListStatus {
    guard didLoadSnapshot else {
        return .placeholders
    }
    if !hasPosts {
        if hasError {
            return .error
        }
        if isExhausted && !isLoadingMore {
            return .empty
        }
        return .placeholders
    }
    if isLoadingMore {
        return .loadingMore
    }
    if hasError {
        return .loadMoreFailed
    }
    return .none
}
