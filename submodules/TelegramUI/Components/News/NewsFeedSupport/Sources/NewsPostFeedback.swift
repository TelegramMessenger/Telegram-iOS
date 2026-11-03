import Foundation
import CoreGraphics
import TelegramCore

/// The answer picked in the "Post hidden" panel (spec §1). None reaches the server: there is no API yet.
public enum NewsPostFeedbackChoice: Equatable {
    /// For You: "Don't show posts from ‹channel›".
    case hideChannel
    /// For You: "Don't show posts like this". Hides only the post (the feed has no topic per post).
    case fewerLikeThis
    /// Added: "Remove ‹channel› from News".
    case removeChannelFromNews

    /// Whether it hides the post's channel, fading the channel's other posts out.
    public var hidesChannel: Bool {
        switch self {
        case .hideChannel, .removeChannelFromNews:
            return true
        case .fewerLikeThis:
            return false
        }
    }
}

public enum NewsPostFeedbackPhase: Equatable {
    case asking
    case done(NewsPostFeedbackChoice)
}

/// What a feed entry shows.
public enum NewsPostFeedbackRow: Equatable {
    case post(fading: Bool)
    case panel(NewsPostFeedbackPhase, fading: Bool)
    case hidden
}

/// One tab's "Post hidden" state: local, in memory, gone on relaunch (spec §1). Posts are keyed by
/// `newsPostIdentity`. Every mutation returns whether it applied, so a timer step that no longer applies does nothing.
public struct NewsPostFeedbackState: Equatable {
    public private(set) var panels: [AnyHashable: NewsPostFeedbackPhase] = [:]
    public private(set) var hiddenPosts = Set<AnyHashable>()
    public private(set) var hiddenChannels = Set<EnginePeer.Id>()
    /// Posts of a just-hidden channel, shown until their own fade.
    public private(set) var lingering = Set<AnyHashable>()
    /// Posts Undo brought back after another panel's choice had hidden their channel: they show anyway. A channel
    /// hidden after the Undo hides them like any other post of it.
    public private(set) var restoredPosts = Set<AnyHashable>()
    public private(set) var fadingPosts = Set<AnyHashable>()
    public private(set) var fadingPanels = Set<AnyHashable>()

    public init() {
    }

    /// A panel first; then a lingering post; then hidden posts and channels; otherwise the post.
    public func row(post: AnyHashable, channel: EnginePeer.Id) -> NewsPostFeedbackRow {
        if let phase = self.panels[post] {
            return .panel(phase, fading: self.fadingPanels.contains(post))
        }
        if !self.lingering.contains(post) && (self.hiddenPosts.contains(post) || (self.hiddenChannels.contains(channel) && !self.restoredPosts.contains(post))) {
            return .hidden
        }
        return .post(fading: self.fadingPosts.contains(post))
    }

    public func isShown(post: AnyHashable, channel: EnginePeer.Id) -> Bool {
        return self.row(post: post, channel: channel) != .hidden
    }

    public func hasPanel(_ post: AnyHashable) -> Bool {
        return self.panels[post] != nil
    }

    /// The post is on its way out (fading for its panel, or a hidden channel's post until its own fade): its row
    /// takes no swipe and no tap.
    public func isLeaving(_ post: AnyHashable) -> Bool {
        return self.lingering.contains(post) || self.fadingPosts.contains(post)
    }

    /// Not Interested: the post's content starts fading in place.
    public mutating func beginNotInterested(_ post: AnyHashable) -> Bool {
        guard self.panels[post] == nil, !self.fadingPosts.contains(post), !self.lingering.contains(post) else {
            return false
        }
        self.fadingPosts.insert(post)
        return true
    }

    /// The faded post gives its place to the panel.
    public mutating func showPanel(_ post: AnyHashable) -> Bool {
        guard self.panels[post] == nil, self.fadingPosts.contains(post) else {
            return false
        }
        self.fadingPosts.remove(post)
        self.panels[post] = .asking
        return true
    }

    public mutating func beginUndo(_ post: AnyHashable) -> Bool {
        guard self.panels[post] == .asking, !self.fadingPanels.contains(post) else {
            return false
        }
        self.fadingPanels.insert(post)
        return true
    }

    /// The faded panel gives its place back to the post, which shows even if its channel was hidden meanwhile.
    public mutating func finishUndo(_ post: AnyHashable, channel: EnginePeer.Id) -> Bool {
        guard self.panels[post] == .asking, self.fadingPanels.contains(post) else {
            return false
        }
        self.panels[post] = nil
        self.fadingPanels.remove(post)
        if self.hiddenChannels.contains(channel) {
            self.restoredPosts.insert(post)
        }
        return true
    }

    /// The panel confirms; the post stays hidden once it leaves. A channel choice hides the channel and keeps
    /// `others` (its other shown posts) until their own fade.
    public mutating func choose(_ post: AnyHashable, channel: EnginePeer.Id, choice: NewsPostFeedbackChoice, others: [AnyHashable]) -> Bool {
        guard self.panels[post] == .asking, !self.fadingPanels.contains(post) else {
            return false
        }
        self.panels[post] = .done(choice)
        self.hiddenPosts.insert(post)
        self.restoredPosts.remove(post)
        if choice.hidesChannel {
            self.hiddenChannels.insert(channel)
            self.lingering.formUnion(others)
        }
        return true
    }

    public mutating func beginLingeringFade(_ post: AnyHashable) -> Bool {
        guard self.lingering.contains(post), !self.fadingPosts.contains(post) else {
            return false
        }
        self.fadingPosts.insert(post)
        return true
    }

    public mutating func finishLingeringFade(_ post: AnyHashable) -> Bool {
        guard self.lingering.contains(post), self.fadingPosts.contains(post) else {
            return false
        }
        self.lingering.remove(post)
        self.fadingPosts.remove(post)
        return true
    }

    public mutating func beginPanelLeave(_ post: AnyHashable) -> Bool {
        guard case .done? = self.panels[post], !self.fadingPanels.contains(post) else {
            return false
        }
        self.fadingPanels.insert(post)
        return true
    }

    public mutating func finishPanelLeave(_ post: AnyHashable) -> Bool {
        guard case .done? = self.panels[post], self.fadingPanels.contains(post) else {
            return false
        }
        self.panels[post] = nil
        self.fadingPanels.remove(post)
        return true
    }

    /// The channel's other posts that `posts` (the tab's, in list order) shows as posts and that are on screen
    /// (`visible`): they fade out one by one. The channel's other posts are hidden at once with it, so the confirmation
    /// does not wait while posts nobody sees fade.
    public func others(of post: AnyHashable, channel: EnginePeer.Id, in posts: [(post: AnyHashable, channel: EnginePeer.Id)], visible: Set<AnyHashable>) -> [AnyHashable] {
        return posts.compactMap { item in
            // Not a post fading for its own panel: that one gets its panel, not a lingering fade.
            guard item.post != post, item.channel == channel, visible.contains(item.post), case .post(fading: false) = self.row(post: item.post, channel: item.channel) else {
                return nil
            }
            return item.post
        }
    }
}

/// The panel flow's timings (Feed3 `FeedStore.fade` / `confirm`, `FeedbackPanel`).
public enum NewsFeedbackTiming {
    /// A row's content fading out before the rows change (`FeedStore.fadeOut`).
    public static let fadeOut: Double = 0.16
    /// A panel, or a post Undo brought back, appears this long after the rows change.
    public static let appearDelay: Double = 0.08
    /// A row created this soon after its appear time plays the appear; later (scrolled into view) it is just there.
    public static let appearWindow: Double = 0.3

    /// When the `index`-th other post of a hidden channel starts fading, from the choice.
    public static func othersFadeDelay(index: Int) -> Double {
        return 0.45 + Double(index) * 0.12
    }

    /// When the confirmed panel starts leaving, from the choice.
    public static func panelLeaveDelay(othersCount: Int) -> Double {
        return max(1.7, 0.45 + Double(othersCount) * 0.12 + 0.6)
    }

    /// `times` without the entries whose appear window has passed.
    public static func pruned(_ times: [AnyHashable: Double], now: Double) -> [AnyHashable: Double] {
        return times.filter { now - $0.value < self.appearWindow }
    }

    public static func playsAppear(appearTime: Double?, now: Double) -> Bool {
        guard let appearTime else {
            return false
        }
        return now - appearTime < self.appearWindow
    }
}

public extension NewsSpring {
    /// `Motion.rows` (`.smooth(duration: 0.4)`): rows going in and out.
    static let rows = NewsSpring(duration: 0.4, bounce: 0.0)

    /// `Motion.lens` (`.spring(duration: 0.5, bounce: 0.3)`): the panel appearing.
    static let lens = NewsSpring(duration: 0.5, bounce: 0.3)
}
