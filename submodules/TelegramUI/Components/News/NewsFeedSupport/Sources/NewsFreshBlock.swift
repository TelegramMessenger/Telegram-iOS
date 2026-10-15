import Foundation
import CoreGraphics
import TelegramCore

/// A revealed post's place in the new-posts block (spec §4.1).
public struct NewsFreshSegment: Equatable {
    /// Top to bottom among the revealed posts: the lens-in's stagger.
    public var index: Int
    public var isFirst: Bool
    public var isLast: Bool
    public var revealTime: Double

    public init(index: Int, isFirst: Bool, isLast: Bool, revealTime: Double) {
        self.index = index
        self.isFirst = isFirst
        self.isLast = isLast
        self.revealTime = revealTime
    }
}

/// The new-posts block and the lens-in (FeedRow.swift:42-376; spec §4).
public enum NewsFreshBlock {
    public static let contentDelay: Double = 0.14
    /// The block's fade-in after `contentDelay`.
    public static let inDuration: Double = 0.35
    public static let duration: Double = 5.6
    /// When the binding drops the marks (FeedStore.swift:577).
    public static let lifetime: Double = 5.9
    /// Only rows that exist this soon after the reveal lens in.
    public static let lensWindow: Double = 0.3
    public static let lensStagger: Double = 0.06
    /// `Motion.appear`'s response.
    public static let lensResponse: Double = 0.45
    /// When the lens has settled (the critically damped spring is within 0.1 %).
    public static let lensSettle: Double = 0.7
    public static let fillAlpha: CGFloat = 0.05
    public static let sliceOverhang: CGFloat = 40.0

    /// `FreshBlock.envelope`: hidden for 0.14 s, in over 0.35 s, held, out by 5.6 s. The hidden start also covers the
    /// old rows sliding away from under the new ones, which the list draws above them.
    public static func alpha(at t: Double) -> CGFloat {
        let C = NewsRefreshCurves.self
        let u = t - contentDelay
        if u < 0.0 {
            return 0.0
        }
        if u < inDuration {
            return C.smooth(CGFloat(u / inDuration))
        }
        if u < 3.4 {
            return 1.0
        }
        return 1.0 - C.smooth(CGFloat((u - 3.4) / (duration - contentDelay - 3.4)))
    }

    /// The card's slice in a row of `bounds` (`FreshShape`): interior slices run past the row and are clipped by it.
    public static func sliceRect(bounds: CGRect, isFirst: Bool, isLast: Bool) -> CGRect {
        let M = NewsRefreshMetrics.self
        let top = isFirst ? bounds.minY + M.cardVerticalInset : bounds.minY - sliceOverhang
        let bottom = isLast ? bounds.maxY - M.cardVerticalInset : bounds.maxY + sliceOverhang
        return CGRect(x: bounds.minX + M.cardSideInset, y: top, width: bounds.width - 2.0 * M.cardSideInset, height: bottom - top)
    }

    /// The row's content clip while fresh (`FreshClip`): the card inside the row's bounds.
    public static func clipRect(bounds: CGRect, isFirst: Bool, isLast: Bool) -> CGRect {
        let M = NewsRefreshMetrics.self
        let top = isFirst ? M.cardVerticalInset : 0.0
        let bottom = isLast ? M.cardVerticalInset : 0.0
        return CGRect(x: bounds.minX + M.cardSideInset, y: bounds.minY + top, width: bounds.width - 2.0 * M.cardSideInset, height: bounds.height - top - bottom)
    }

    public static func lensProgress(_ t: Double) -> CGFloat {
        return NewsRefreshCurves.follow(t, duration: lensResponse)
    }

    public static func lensScale(_ p: CGFloat) -> CGFloat {
        return 1.0 + 0.3 * (1.0 - p)
    }

    public static func lensBlur(_ p: CGFloat) -> CGFloat {
        return 6.0 * (1.0 - p)
    }

    public static func lensAlpha(_ p: CGFloat) -> CGFloat {
        return min(1.0, p / 0.7)
    }

    public static func lensDelay(now: Double, segment: NewsFreshSegment) -> Double {
        return max(0.0, segment.revealTime + contentDelay - now) + lensStagger * Double(segment.index)
    }

    public static func runsLens(createdAt: Double, segment: NewsFreshSegment) -> Bool {
        return createdAt - segment.revealTime <= lensWindow + 1e-9
    }

    /// The glow's mask centre drifts between these (FeedRow.swift:270-271).
    public static func glowCenters(size: CGSize) -> (start: CGPoint, end: CGPoint) {
        return (CGPoint(x: 8.0, y: min(size.height * 0.62, 120.0)), CGPoint(x: min(size.width * 0.46, 190.0), y: 2.0))
    }
}

/// Each revealed row's segment: consecutive revealed rows make one block.
public func newsFreshSegments(isFresh: [Bool], revealTime: Double) -> [NewsFreshSegment?] {
    var result: [NewsFreshSegment?] = []
    var index = 0
    for i in 0 ..< isFresh.count {
        guard isFresh[i] else {
            result.append(nil)
            continue
        }
        let isFirst = i == 0 || !isFresh[i - 1]
        let isLast = i == isFresh.count - 1 || !isFresh[i + 1]
        result.append(NewsFreshSegment(index: index, isFirst: isFirst, isLast: isLast, revealTime: revealTime))
        index += 1
    }
    return result
}

public func newsForYouPostKeys(_ items: [EngineForYouItem]) -> Set<AnyHashable> {
    var keys = Set<AnyHashable>()
    for item in items {
        if case let .post(entry) = item {
            keys.insert(newsPostIdentity(entry))
        }
    }
    return keys
}

/// The posts a For you refresh brought: the ones its batch prepended, before the first post the feed already had.
/// Unknown posts further down came from a load-more that landed meanwhile; they are not fresh.
public func newsForYouFreshPostKeys(knownKeys: Set<AnyHashable>, items: [EngineForYouItem]) -> [AnyHashable] {
    var result: [AnyHashable] = []
    for item in items {
        if case let .post(entry) = item {
            let key = newsPostIdentity(entry)
            if knownKeys.contains(key) {
                break
            }
            result.append(key)
        }
    }
    return result
}

/// For you's items while a pull is held back: the feed as it was when the pull began, so nothing the refresh changes
/// (its posts, or the interests marker its batch carries, which the merge moves to the top) shows before the drop
/// lands. Posts a load-more appended meanwhile (after the snapshot's last post) still show.
public func newsForYouHeldItems(snapshot: [EngineForYouItem], current: [EngineForYouItem]) -> [EngineForYouItem] {
    var snapshotKeys = Set<AnyHashable>()
    var lastSnapshotKey: AnyHashable?
    for item in snapshot {
        if case let .post(entry) = item {
            let key = newsPostIdentity(entry)
            snapshotKeys.insert(key)
            lastSnapshotKey = key
        }
    }
    guard let lastSnapshotKey, let lastIndex = current.firstIndex(where: { item in
        if case let .post(entry) = item {
            return newsPostIdentity(entry) == lastSnapshotKey
        }
        return false
    }) else {
        return snapshot
    }
    var result = snapshot
    for item in current[(lastIndex + 1)...] {
        if case let .post(entry) = item, !snapshotKeys.contains(newsPostIdentity(entry)) {
            result.append(item)
        }
    }
    return result
}

/// An Added pull's request, followed through the feed's loading flags. `loadNewer(force:)` does not start while the
/// first page is loading, so that load counts as the pull's own: the pull ends when a load seen running has stopped.
public struct NewsAddedPullRequest: Equatable {
    public private(set) var sawLoading: Bool

    public init(isLoadingNewer: Bool, isLoadingInitial: Bool) {
        self.sawLoading = isLoadingNewer || isLoadingInitial
    }

    /// True once the request has ended.
    public mutating func observe(isLoadingNewer: Bool, isLoadingInitial: Bool) -> Bool {
        if isLoadingNewer || isLoadingInitial {
            self.sawLoading = true
            return false
        }
        return self.sawLoading
    }
}

/// The posts an Added refresh brought: the entries above the window's previous top.
public func newsAddedFreshPostKeys(entries: [EngineFeedEntry], above top: EngineFeedPosition) -> [AnyHashable] {
    return entries.filter { $0.position > top }.map(newsPostIdentity)
}
