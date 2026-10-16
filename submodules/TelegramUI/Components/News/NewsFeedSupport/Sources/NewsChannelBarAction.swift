import Foundation

public enum NewsChannelParticipation: Equatable {
    case member
    case left
    case kicked
}

/// The bar's own requests still in flight. Each shows its outcome until the stored channel catches up, so the island
/// never steps back to the state it is leaving (spec §1.1).
public struct NewsChannelBarPending: Equatable {
    public var isAddingToNews: Bool
    /// Add to Chats: the join and the mute that follows it.
    public var isJoining: Bool
    /// A Remove from Chats waiting for its toast (spec §1.4).
    public var isRemovingFromChats: Bool
    /// A Remove from News the stored channel does not show yet.
    public var isRemovingFromNews: Bool
    /// A Notify / Do Not Notify the stored setting does not show yet.
    public var muted: Bool?

    public init(isAddingToNews: Bool = false, isJoining: Bool = false, isRemovingFromChats: Bool = false, isRemovingFromNews: Bool = false, muted: Bool? = nil) {
        self.isAddingToNews = isAddingToNews
        self.isJoining = isJoining
        self.isRemovingFromChats = isRemovingFromChats
        self.isRemovingFromNews = isRemovingFromNews
        self.muted = muted
    }

    /// A tap that would start a second request while one runs is ignored. A deferred removal is not a request until it
    /// commits: a tap on "+ Add to News" commits it and then adds.
    public var acceptsTap: Bool {
        return !self.isAddingToNews && !self.isJoining
    }
}

/// One of the bar's own requests, from its tap until the stored channel shows its result. A join's answer arrives
/// before the channel it changed is stored (`joinChannel` hands its updates to the state manager, which applies them
/// later), so ending the request on its answer let a layout in between show the state it was leaving, and the island
/// restarted its transition from there (measured on K1: Add to News's answer came 100 ms before `in_news`).
public struct NewsChannelBarRequest: Equatable {
    public enum Kind: Equatable {
        case addToNews
        case addToChats
        case removeFromNews
        case setMuted(Bool)
    }

    /// How long an answered request waits for the stored channel before the bar shows the stored state anyway.
    public static let settleTimeout: Double = 5.0

    public let kind: Kind
    public private(set) var answeredAt: Double?

    public init(kind: Kind) {
        self.kind = kind
    }

    /// The request's answer came back (a join, not an error or a join web view: those end the request at once).
    public mutating func answer(at time: Double) {
        self.answeredAt = time
    }

    /// Whether the bar still shows the request's outcome rather than the stored channel.
    public func isPending(isInNews: Bool, participation: NewsChannelParticipation, isMuted: Bool, now: Double) -> Bool {
        guard let answeredAt = self.answeredAt else {
            return true
        }
        if now - answeredAt >= NewsChannelBarRequest.settleTimeout {
            return false
        }
        switch self.kind {
        case .addToNews:
            return !isInNews && participation != .member
        case .addToChats:
            return participation != .member
        case .removeFromNews:
            return isInNews
        case let .setMuted(muted):
            return isMuted != muted
        }
    }
}

public enum NewsChannelBarAction: Equatable {
    case addToNews
    case addedToNews
    case addedToChats(muted: Bool)
    /// Not a News state: the bar keeps its existing behaviour (Join, Mute/Unmute, …).
    case existing
}

/// The News states of a channel chat's bottom bar (spec §1.1), only while the feature is on: with it off the bar is
/// Join or Mute/Unmute as before News, also for a channel added to News while it was on (user decision, 2026-10-16).
/// Every joined broadcast channel is "Added to Chats" (user decision, 2026-10-15: the mockup has no Mute/Unmute), and a
/// light join (`in_news` without membership) is "Added to News". The bar's own requests win over the stored state: a
/// pending removal (from Chats or News), then a join, then an Add to News; a pending Notify / Do Not Notify wins over
/// the stored mute setting.
public func newsChannelBarAction(isBroadcast: Bool, isInNews: Bool, participation: NewsChannelParticipation, isMuted: Bool, featureEnabled: Bool, pending: NewsChannelBarPending) -> NewsChannelBarAction {
    guard isBroadcast, participation != .kicked else {
        return .existing
    }
    if pending.isRemovingFromChats || pending.isRemovingFromNews {
        return featureEnabled ? .addToNews : .existing
    }
    if pending.isJoining {
        return featureEnabled ? .addedToChats(muted: pending.muted ?? true) : .existing
    }
    if pending.isAddingToNews {
        return featureEnabled ? .addedToNews : .existing
    }
    switch participation {
    case .member:
        return featureEnabled ? .addedToChats(muted: pending.muted ?? isMuted) : .existing
    case .left:
        if isInNews {
            return featureEnabled ? .addedToNews : .existing
        }
        return featureEnabled ? .addToNews : .existing
    case .kicked:
        return .existing
    }
}

/// The island's menu items (spec §1.3), with the mockup's icons (`Images.xcassets/News/Channel`).
public enum NewsChannelMenuItem: Equatable {
    case addToChats
    case removeFromNews
    case notify
    case doNotNotify
    case archive
    case unarchive
    case removeFromChats

    public var isDestructive: Bool {
        switch self {
        case .removeFromNews, .removeFromChats:
            return true
        case .addToChats, .notify, .doNotNotify, .archive, .unarchive:
            return false
        }
    }

    public var iconName: String {
        switch self {
        case .addToChats:
            return "News/Channel/MenuAddChats"
        case .removeFromNews:
            return "News/Channel/MenuFeedCrossed"
        case .notify:
            return "News/Channel/MenuNotify"
        case .doNotNotify:
            return "News/Channel/MenuDoNotNotify"
        case .archive:
            return "News/Channel/MenuArchive"
        case .unarchive:
            return "News/Channel/MenuUnarchive"
        case .removeFromChats:
            return "News/Channel/MenuRemoveChats"
        }
    }
}

/// The menu the island opens, top to bottom (spec §1.3); empty where it opens none.
public func newsChannelMenuItems(for action: NewsChannelBarAction, isArchived: Bool) -> [NewsChannelMenuItem] {
    switch action {
    case .addedToNews:
        return [.addToChats, .removeFromNews]
    case let .addedToChats(muted):
        return [muted ? .notify : .doNotNotify, isArchived ? .unarchive : .archive, .removeFromChats]
    case .addToNews, .existing:
        return []
    }
}

/// Whether the chat title shows its mute icon (spec §3). A broadcast channel with the feature on shows it exactly when it
/// is in Chats and muted, also when verified (the mockup draws it after the check). Every other chat keeps the old rule:
/// muted and not verified.
public func newsChatTitleShowsMuteIcon(isBroadcast: Bool, participation: NewsChannelParticipation, isMuted: Bool, isVerified: Bool, featureEnabled: Bool) -> Bool {
    if isBroadcast && featureEnabled {
        return participation == .member && isMuted
    }
    return isMuted && !isVerified
}
