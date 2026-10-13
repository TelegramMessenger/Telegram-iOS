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

/// The News states of a channel chat's bottom bar. Membership comes first: a joined channel appears everywhere
/// and keeps its existing bar even when it is in News, so Remove from News, which leaves the channel, is only
/// offered to a light join (`in_news` without membership). The Added-to-News state does not depend on
/// `featureEnabled`, so a light-joined channel can always be moved or removed.
public func newsChannelBarAction(isBroadcast: Bool, isInNews: Bool, participation: NewsChannelParticipation, featureEnabled: Bool, isAddingToNews: Bool) -> NewsChannelBarAction {
    guard isBroadcast, participation == .left else {
        return .existing
    }
    if isAddingToNews || isInNews {
        return .addedToNews
    }
    if featureEnabled {
        return .addToNews
    }
    return .existing
}
