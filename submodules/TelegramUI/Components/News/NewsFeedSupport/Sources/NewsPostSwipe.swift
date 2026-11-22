import Foundation
import CoreGraphics

/// A post row's swipe actions (Feed3 `feedSwipeActions`): Interesting sends `feed.likePost`, Not Interested
/// `feed.dislikePost`.
public enum NewsPostSwipeAction: Int32 {
    case interesting = 0
    case notInterested = 1
    /// The left side's one option: the row shows its post expanded (or compact again) while the feed keeps its mode.
    case expand = 2
    case collapse = 3
}

/// The swipe actions in the reveal control's order. The control draws the right side's last option at the row's
/// edge and performs it on a full swipe: Not Interested, the mockup's edge action.
public let newsPostSwipeActions: [NewsPostSwipeAction] = [.interesting, .notInterested]

/// The width of the strip along a post row's right edge where a swipe reveals its actions instead of paging: the chat
/// list's folder pager edge width (`ChatListControllerNode`, `.widthMultiplier(factor: 1/6, min: 22, max: 80)`).
public func newsPagerRevealZoneWidth(width: CGFloat) -> CGFloat {
    return max(22.0, min(80.0, width / 6.0))
}

/// Whether For You's pager leaves a touch to the row it starts on: a post row with swipe actions, inside the reveal
/// zone. Everywhere else a leftward swipe pages to Added (the chat list's rule with folders). Rows end at the list's
/// right safe inset (unlike the chat list's, which run under it), so the zone ends at that edge and is sized from the
/// width up to it; with no inset it is the list's edge, as in the chat list. `touchX` is in the list's coordinates.
public func newsPagerDefersToRowReveal(touchX: CGFloat, width: CGFloat, rightInset: CGFloat, isOnRevealableRow: Bool) -> Bool {
    let rowRightEdge = width - rightInset
    return isOnRevealableRow && touchX >= rowRightEdge - newsPagerRevealZoneWidth(width: rowRightEdge)
}

/// Added's mirror of `newsPagerDefersToRowReveal`: a rightward swipe from a post row's left edge reveals the row's
/// Expand, one from the middle pages back to For you. Rows start at the list's left safe inset, so the zone starts
/// there and is sized from the row's width between the insets. `touchX` is in the list's coordinates.
public func newsPagerDefersToRowLeftReveal(touchX: CGFloat, width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, isOnRevealableRow: Bool) -> Bool {
    let rowWidth = width - leftInset - rightInset
    return isOnRevealableRow && touchX <= leftInset + newsPagerRevealZoneWidth(width: rowWidth)
}

/// Whether a swipe that starts at `touchX` (in the row, `width` wide) is the row's own: the chat list's rule, on both
/// sides. From the right zone (`newsPagerRevealZoneWidth`) a swipe reveals the right side's actions, from the left
/// zone the left side's Expand; from the middle a swipe is the pager's, or nothing. An open row closes from anywhere.
public func newsRowRevealAllowed(touchX: CGFloat, width: CGFloat) -> Bool {
    let zone = newsPagerRevealZoneWidth(width: width)
    return touchX <= zone || touchX >= width - zone
}

/// The alpha each loaded post row gives its bottom separator. The separator between two rows is the upper row's,
/// and it fades with the lower row's swipe surface, as the chat list's do. `swipeAlphas` maps a loaded post row's
/// index to its own swipe separator alpha (1 closed, 0 open); a row without a post row directly below keeps 1.
public func newsSeparatorAlphasFromRowsBelow(_ swipeAlphas: [Int: CGFloat]) -> [Int: CGFloat] {
    var result: [Int: CGFloat] = [:]
    for index in swipeAlphas.keys {
        result[index] = swipeAlphas[index + 1] ?? 1.0
    }
    return result
}
