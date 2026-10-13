import Foundation

public enum NewsChannelParticipation: Equatable {
    case member
    case left
    case kicked
}

public enum NewsChannelBarAction: Equatable {
    case addToNews
    case addedToNews
    /// Not a News state: the bar keeps its existing behaviour (Join, Mute/Unmute, …).
    case existing
}

/// The News states of a channel chat's bottom bar. A News-only channel may read as a member or as a channel
/// the user left (the backend may stop reporting it as joined), so `isInNews` is checked before participation.
/// The Added-to-News state does not depend on `featureEnabled`, so a News-only channel can always be moved
/// or removed.
public func newsChannelBarAction(isBroadcast: Bool, isInNews: Bool, participation: NewsChannelParticipation, featureEnabled: Bool, isAddingToNews: Bool) -> NewsChannelBarAction {
    guard isBroadcast, participation != .kicked else {
        return .existing
    }
    if isAddingToNews || isInNews {
        return .addedToNews
    }
    if participation == .left && featureEnabled {
        return .addToNews
    }
    return .existing
}
