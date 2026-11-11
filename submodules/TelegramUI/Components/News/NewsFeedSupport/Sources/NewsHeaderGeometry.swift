import Foundation
import CoreGraphics

/// The News header's fixed measures (Feed2 FeedScreen.swift:136, 203-272).
public enum NewsHeaderMetrics {
    /// The top row sits where `ChatListNavigationBar` puts its header row: 10 pt under the status bar, 44 tall.
    public static let topRowOffset: CGFloat = 10.0
    public static let topRowHeight: CGFloat = 44.0
    public static let islandHeight: CGFloat = 40.0
    /// `FeedTabs.width`.
    public static let islandMinWidth: CGFloat = 228.0
    public static let islandToMoreButtonSpacing: CGFloat = 10.0
    /// From the top row to the search field: where `ChatListNavigationBar` puts its field (the node 2 pt up from
    /// the row's bottom, the field 8 pt into the node), so Chats, Contacts and News line up.
    public static let searchFieldGap: CGFloat = 6.0
    /// How far the folding search node lifts, as `ChatListNavigationBar` lifts its own: half the node's height
    /// beyond the field's ((60 − 44) / 2).
    public static let searchFoldLift: CGFloat = 8.0
    public static let headerBottomPadding: CGFloat = 6.0
    /// The header gradient runs 22 pt past the header's bottom.
    public static let edgeEffectExtension: CGFloat = 22.0
    /// The soft scroll edge fades in over this much scroll (measured on the mockup: ~90 % at 12 pt).
    public static let softEdgeRamp: CGFloat = 12.0
    /// Active search, as `ChatListNavigationBar`: the search node at status bar + 8, results under status bar + 3 + 60.
    public static let activeSearchNodeOffset: CGFloat = 8.0
    public static let activeSearchBarExtra: CGFloat = 3.0
}

/// Where the shared News header puts things.
public struct NewsHeaderGeometry: Equatable {
    /// The full-width row holding the tabs island and the "…" button; it never scrolls.
    public let topRow: CGRect
    public let island: CGRect
    /// The search node's frame when the list is at its top.
    public let searchNodeAtRest: CGRect
    /// From the top row's bottom edge to the search field's bottom edge: how far the block folds away.
    public let blockHeight: CGFloat
    /// The edge effect runs from the screen top down this far.
    public let edgeEffectHeight: CGFloat
    /// The lists' top content inset: the first row starts at the search field's bottom edge.
    public let listTopInset: CGFloat

    public init(topRow: CGRect, island: CGRect, searchNodeAtRest: CGRect, blockHeight: CGFloat, edgeEffectHeight: CGFloat, listTopInset: CGFloat) {
        self.topRow = topRow
        self.island = island
        self.searchNodeAtRest = searchNodeAtRest
        self.blockHeight = blockHeight
        self.edgeEffectHeight = edgeEffectHeight
        self.listTopInset = listTopInset
    }
}

/// - `islandFittingWidth`: the tabs' natural width. The island is at least 228 wide, centred, and never comes
///   within 10 pt of the "…" button (`moreButtonMinX`).
/// - `searchFieldFrameInNode`: where the search node lays out its field when whole (expansion 1), in the node's
///   coordinates. A folding node lays its field lower (`newsHeaderWholeSearchField`): never pass a folded node's frame.
public func newsHeaderGeometry(width: CGFloat, statusBarHeight: CGFloat, islandFittingWidth: CGFloat, moreButtonMinX: CGFloat, searchNodeHeight: CGFloat, searchFieldFrameInNode: CGRect) -> NewsHeaderGeometry {
    let metrics = NewsHeaderMetrics.self
    let topRow = CGRect(x: 0.0, y: statusBarHeight + metrics.topRowOffset, width: width, height: metrics.topRowHeight)

    let maxIslandWidth = max(0.0, 2.0 * (moreButtonMinX - metrics.islandToMoreButtonSpacing) - width)
    let islandWidth = min(max(metrics.islandMinWidth, islandFittingWidth), maxIslandWidth)
    let island = CGRect(x: floor((width - islandWidth) * 0.5), y: topRow.minY + floor((topRow.height - metrics.islandHeight) * 0.5), width: islandWidth, height: metrics.islandHeight)

    let fieldTop = topRow.maxY + metrics.searchFieldGap
    let searchNodeAtRest = CGRect(x: 0.0, y: fieldTop - searchFieldFrameInNode.minY, width: width, height: searchNodeHeight)
    let blockHeight = metrics.searchFieldGap + searchFieldFrameInNode.height

    return NewsHeaderGeometry(
        topRow: topRow,
        island: island,
        searchNodeAtRest: searchNodeAtRest,
        blockHeight: blockHeight,
        edgeEffectHeight: topRow.maxY + metrics.headerBottomPadding + metrics.edgeEffectExtension,
        listTopInset: topRow.maxY + blockHeight
    )
}

/// The search field's frame to build the header on: the one measured now while the field is whole (`expansion` 1),
/// else the last whole measurement (`whole`). The node lays its field's 44 pt frame lower as it folds (y 8 → 52; the
/// visible capsule shrinks from its top), so a frame read while folded would put the resting search up to 44 pt too
/// high, behind the top row, over an empty band above the first post. With no whole measurement yet, the current one.
public func newsHeaderWholeSearchField(measured: CGRect, expansion: CGFloat, whole: CGRect?) -> CGRect {
    if expansion > 0.9999 {
        return measured
    }
    return whole ?? measured
}

/// The search field's expansion as the list scrolls, as the chat list folds its field: whole at rest, gone once the
/// block is under the top row, in between in proportion; an overscroll keeps it whole.
public func newsHeaderSearchExpansion(listOffset: CGFloat, blockHeight: CGFloat) -> CGFloat {
    guard blockHeight > 0.0 else {
        return 1.0
    }
    return 1.0 - max(0.0, min(listOffset, blockHeight)) / blockHeight
}

/// How far the search node has moved up: 1:1 with the block's fold (the node keeps its field's bottom at its own
/// bottom while the field shrinks, so the field's bottom edge rises with the content it sat on), plus the chat
/// list's `searchFoldLift` by the time the field is folded; down with an overscroll, 1:1.
public func newsHeaderSearchLift(listOffset: CGFloat, blockHeight: CGFloat) -> CGFloat {
    if listOffset < 0.0 {
        return listOffset
    }
    let fold = 1.0 - newsHeaderSearchExpansion(listOffset: listOffset, blockHeight: blockHeight)
    return newsHeaderBlockOffset(listOffset: listOffset, blockHeight: blockHeight) + NewsHeaderMetrics.searchFoldLift * fold
}

/// How far the search block has folded: 1:1 with the list until it is under the top row, and down with an
/// overscroll. The snap and the pill go by it.
public func newsHeaderBlockOffset(listOffset: CGFloat, blockHeight: CGFloat) -> CGFloat {
    return min(listOffset, blockHeight)
}

/// Where the list scrolls when scrolling ends with the block partly hidden: fully shown below half its height,
/// fully hidden above it. nil when it is not partly hidden.
public func newsHeaderSnapTarget(blockOffset: CGFloat, blockHeight: CGFloat) -> CGFloat? {
    guard blockOffset > 0.0 && blockOffset < blockHeight else {
        return nil
    }
    return blockOffset < blockHeight * 0.5 ? 0.0 : blockHeight
}

/// Whether `y` is in the top row's band (the row and the header's bottom padding), which takes its own touches:
/// the search block that scrolled under it, and the rows beneath, must not get them.
public func newsHeaderTopBandContains(y: CGFloat, geometry: NewsHeaderGeometry) -> Bool {
    return y < geometry.topRow.maxY + NewsHeaderMetrics.headerBottomPadding
}

/// How visible the header's soft scroll edge (blur plus extra whitening) is. The mockup's system soft edge is absent
/// at rest, so its search row is untouched, and near full once content has scrolled ~12 pt under the header
/// (measured on K1). While search is active its results scroll under the field, so the edge stays on.
public func newsHeaderSoftEdgeAlpha(listOffset: CGFloat, isSearchActive: Bool) -> CGFloat {
    if isSearchActive {
        return 1.0
    }
    return max(0.0, min(1.0, listOffset / NewsHeaderMetrics.softEdgeRamp))
}
