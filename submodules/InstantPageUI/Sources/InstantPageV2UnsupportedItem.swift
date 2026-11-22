import Foundation
import UIKit
import TelegramCore
import UnsupportedContentPill

/// A laid-out "this build cannot render this content" card, standing in for one or more
/// `InstantPageBlock.unsupported` blocks.
public struct InstantPageV2UnsupportedItem {
    public var frame: CGRect
    public let layout: UnsupportedContentPillLayout
    /// Carried on the item because the view is built later, from the item alone — the layout pass
    /// is the last place with access to the page's `PresentationStrings`.
    public let strings: UnsupportedContentPillStrings
    /// This pill stands for a block that is a direct child of the page, not one nested in a
    /// container.
    ///
    /// It has to be recorded here because it cannot be recovered from the finished layout. A
    /// blockquote (and a list) lays its children out with `layoutBlock` and appends the resulting
    /// items straight into its PARENT's item array, offset — so a nested pill is indistinguishable
    /// from a top-level one by position in `items` alone. Only the layout pass still knows the
    /// difference.
    public let isTopLevel: Bool
}

/// True for a block V2 renders as the "please update" pill rather than as itself.
///
/// Wider than `case .unsupported` by exactly one rule: a **collage** carrying a block this build
/// cannot decode is unsupported as a whole. `layoutCollage` reserves a mosaic slot for every inner
/// block and emits a cell only for the ones it can resolve, so an undecodable item leaves a hole and
/// pushes the tiles around it into the wrong geometry — a mosaic that is visibly wrong rather than
/// visibly missing. One pill says the true thing instead.
///
/// One level deep, deliberately: a collage's items are flat media blocks, and a collage inside a
/// collage is not a shape the schema produces.
///
/// NOT extended to `.slideshow`, which has the same shape but not the same failure: it drops an
/// undecodable item silently (one page fewer) and keeps rendering the ones it understands.
///
/// Every reader that asks "is this block unsupported" must ask THIS, not the case — the run
/// collapsing below and `InstantPageBlock.spacing(metrics:)` both do, so a collage-turned-pill
/// collapses into an adjacent run and takes the pill's own vertical rhythm.
func blockRendersAsUnsupported(_ block: InstantPageBlock) -> Bool {
    switch block {
    case .unsupported:
        return true
    case let .collage(items, _):
        return items.contains { if case .unsupported = $0 { return true } else { return false } }
    default:
        return false
    }
}

/// Indices of the unsupported blocks that directly follow another one, so a maximal run renders
/// as a single pill with a single set of block gaps.
///
/// Returns indices to SKIP rather than a filtered array on purpose: `layoutBlockSequence` feeds its
/// loop index into `pathPrefix + [i]`, which is the structural path checkbox toggling and anchors
/// address blocks by. Filtering the array would renumber every block after a collapsed run and
/// silently toggle the wrong checkbox.
///
/// Applied in every block sequence — including nested ones (details bodies, table cells, quotes) —
/// so the rule holds everywhere rather than only at the top level.
func redundantUnsupportedBlockIndices(_ blocks: [InstantPageBlock]) -> Set<Int> {
    var result: Set<Int> = []
    var previousWasUnsupported = false
    for (index, block) in blocks.enumerated() {
        if blockRendersAsUnsupported(block) {
            if previousWasUnsupported {
                result.insert(index)
            }
            previousWasUnsupported = true
        } else {
            previousWasUnsupported = false
        }
    }
    return result
}

/// Lays out one pill, inset horizontally like a paragraph and stretched to the content width.
func layoutUnsupportedBlock(
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    strings: UnsupportedContentPillStrings,
    colors: UnsupportedContentPillColors,
    isTopLevel: Bool
) -> [InstantPageV2LaidOutItem] {
    let contentWidth = max(1.0, boundingWidth - horizontalInset * 2.0)
    let pillLayout = UnsupportedContentPill.layout(strings: strings, colors: colors, constrainedWidth: contentWidth)
    let frame = CGRect(x: horizontalInset, y: 0.0, width: contentWidth, height: pillLayout.size.height)
    return [.unsupportedContent(InstantPageV2UnsupportedItem(frame: frame, layout: pillLayout, strings: strings, isTopLevel: isTopLevel))]
}

/// Page-space rects a host may cut out of whatever it draws behind the page, one per pill.
///
/// Top level only, deliberately: a pill nested inside a `<details>` body, a blockquote or a table
/// cell is not full-width relative to the host's background, so tearing across it would cut a band
/// through unrelated content.
///
/// The `isTopLevel` filter is what enforces that, NOT the non-recursive walk. A blockquote appends
/// its children's items into its parent's array, so a quoted pill sits in `layout.items` looking
/// exactly like a top-level one. Not recursing merely keeps the walk cheap — it excludes only the
/// containers that build a sub-layout of their own (`details`, table cells).
///
/// Only the vertical extent is meaningful to the caller — the horizontal extent of a tear is the
/// host's business, since only the host knows how wide its background is — but the pill's own
/// horizontal box is returned unchanged rather than zeroed, so the value stays a rect that means
/// something on its own.
public func unsupportedContentTearZones(in layout: InstantPageV2Layout) -> [CGRect] {
    /// Vertical breathing room added above and below a pill when a host tears its background across it.
    /// Without it the bubble's cut edges land exactly on the pill's box and the two touch.
    let instantPageUnsupportedTearPadding: CGFloat = 6.0
    
    var result: [CGRect] = []
    for item in layout.items {
        if case let .unsupportedContent(unsupported) = item, unsupported.isTopLevel {
            result.append(unsupported.frame.insetBy(dx: 0.0, dy: -instantPageUnsupportedTearPadding))
        }
    }
    return result
}

/// The page-space frame of the Update button of the pill containing `point`, or nil.
///
/// A host that renders the page inside a surface which arbitrates its own touches must be able to
/// answer "is this point the pill's button?" from the layout alone: a chat bubble resolves a touch
/// in `tapActionAtPoint`, where it has the laid-out page but no pill view to ask. Without that
/// answer the bubble's tap recognizer claims the touch and cancels the button's tracking, so
/// `touchUpInside` never fires and the button reads as dead (`ChatMessageUnsupportedBubbleContentNode`
/// answers the same question for the standalone unsupported bubble, via the pill view).
///
/// The button only, not the whole card: the rest of the pill is ordinary content, and claiming it
/// would swallow the surrounding surface's own tap and long-press.
///
/// Unlike `unsupportedContentTearZones` this DOES recurse into container sub-layouts — a pill in a
/// `<details>` body or a table cell has the same dead button — mirroring `findTextItem`, including
/// its limitation that a horizontally scrolled table's cells are addressed at their unscrolled
/// positions.
func unsupportedActionFrame(in layout: InstantPageV2Layout, containing point: CGPoint) -> CGRect? {
    return findUnsupportedActionFrame(in: layout, point: point, accumulatedOffset: .zero)
}

private func findUnsupportedActionFrame(
    in layout: InstantPageV2Layout,
    point: CGPoint,
    accumulatedOffset: CGPoint
) -> CGRect? {
    for item in layout.items {
        let f = item.frame.offsetBy(dx: accumulatedOffset.x, dy: accumulatedOffset.y)
        if !f.contains(point) { continue }
        switch item {
        case let .unsupportedContent(unsupported):
            // `f.size`, not the pill's intrinsic `layout.size`: the item is stretched to the
            // content width and the button is pinned to its trailing edge.
            let actionFrame = unsupported.layout.actionFrame(in: f.size).offsetBy(dx: f.minX, dy: f.minY)
            if actionFrame.contains(point) {
                return actionFrame
            }
        case let .details(details):
            if let inner = details.innerLayout {
                let innerOffset = CGPoint(x: f.minX, y: f.minY + details.titleFrame.maxY)
                if let hit = findUnsupportedActionFrame(in: inner, point: point, accumulatedOffset: innerOffset) {
                    return hit
                }
            }
        case let .table(table):
            for cell in table.cells {
                let cellAbs = cell.frame.offsetBy(dx: f.minX + table.contentInset, dy: f.minY)
                if !cellAbs.contains(point) { continue }
                if let sub = cell.subLayout {
                    if let hit = findUnsupportedActionFrame(in: sub, point: point,
                                                           accumulatedOffset: CGPoint(x: cellAbs.minX, y: cellAbs.minY)) {
                        return hit
                    }
                }
            }
            if let titleLayout = table.titleSubLayout, let titleFrame = table.titleFrame {
                let titleAbs = titleFrame.offsetBy(dx: f.minX + table.contentInset, dy: f.minY)
                if titleAbs.contains(point) {
                    if let hit = findUnsupportedActionFrame(in: titleLayout, point: point,
                                                           accumulatedOffset: CGPoint(x: titleAbs.minX, y: titleAbs.minY)) {
                        return hit
                    }
                }
            }
        default:
            continue
        }
    }
    return nil
}
