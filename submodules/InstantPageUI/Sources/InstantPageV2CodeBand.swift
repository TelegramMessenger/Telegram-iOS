import Foundation
import UIKit

/// How far a full-bleed child may extend past its own content column to reach the enclosing
/// container's interior edges.
///
/// GEOMETRIC, not logical: `minXSide` is always the smaller-x edge. A container that mirrors itself
/// for RTL — a block quote moves its accent bar to the trailing edge — resolves that when it SETS
/// these, so no consumer has to read `context.rtl`. Getting this wrong is invisible in LTR.
public struct InstantPageV2ChildBleed: Equatable {
    public var minXSide: CGFloat
    public var maxXSide: CGFloat

    public init(minXSide: CGFloat, maxXSide: CGFloat) {
        self.minXSide = minXSide
        self.maxXSide = maxXSide
    }

    /// The conservative default: a child stays in its content column, i.e. the pre-2026-08 geometry.
    /// Every container that has not opted in gets this.
    public static let none = InstantPageV2ChildBleed(minXSide: 0.0, maxXSide: 0.0)
}

/// A code block's band: its ordinary content column, grown outward by the bleed.
///
/// At top level (`horizontalInset` 9, bleed 9/9) this is `[0, boundingWidth]` — the full container.
/// Inside a block quote (`horizontalInset` 0, because children lay out flush against their band)
/// it is `[-minXSide, boundingWidth + maxXSide]`, which lands inside the quote's bar and out to its
/// fill's trailing edge once the band is translated into place.
func instantPageV2CodeBandFrame(boundingWidth: CGFloat, horizontalInset: CGFloat,
                                bleed: InstantPageV2ChildBleed, height: CGFloat) -> CGRect {
    let minX = horizontalInset - bleed.minXSide
    let maxX = boundingWidth - horizontalInset + bleed.maxXSide
    return CGRect(x: minX, y: 0.0, width: max(0.0, maxX - minX), height: height)
}

/// The x an item contributes to `layoutBlockSequence`'s `fitToWidth` shrink.
///
/// For a code band this is its INNER content, not its own frame. The band is as wide as its
/// container by construction, so its frame would clamp every page containing one to the full
/// bounding width — a full-width bubble for a one-line snippet. But the band's text and language
/// line are NOT items in the sequence: `layoutCodeBlock` returns a single `.codeBlock`, with both
/// nested inside it. Excluding the band alone therefore drops the code text from the shrink
/// entirely, and a message whose widest content IS its code ends up in a bubble narrower than the
/// width that text was laid out against — the text is then clipped at the bubble's edge.
///
/// So reach in: the nested frames are block-local, hence `block.frame.minX + inner.frame.maxX`.
func instantPageV2FitWidthMaxX(_ item: InstantPageV2LaidOutItem) -> CGFloat {
    guard case let .codeBlock(block) = item else {
        return item.frame.maxX
    }
    var maxX = block.frame.minX + block.textItem.frame.maxX
    if let languageItem = block.languageItem {
        maxX = max(maxX, block.frame.minX + languageItem.frame.maxX)
    }
    return maxX
}

/// Re-widens every code band to the width that SURVIVED the `fitToWidth` shrink.
///
/// Runs after `contentSize` is decided, for the same reason `centerBlockFormulas` does: the band a
/// full-bleed block should span is the one that survives the shrink, not the one it was laid out
/// against.
///
/// Moves the TRAILING edge only. The leading edge carries the bleed, and the code text's block-local
/// x is measured from it — moving it would drag the text off the paragraph inset it is supposed to
/// align with.
func instantPageV2StretchCodeBands(in items: inout [InstantPageV2LaidOutItem], contentWidth: CGFloat) {
    for i in items.indices {
        guard case var .codeBlock(block) = items[i] else {
            continue
        }
        block.frame.size.width = max(0.0, contentWidth - block.frame.minX)
        items[i] = .codeBlock(block)
    }
}

/// Width of a block quote's leading accent bar. Shared by the quote frames that DRAW it and by
/// `layoutBlockQuote`'s child-bleed computation, which has to stop a full-bleed child just inside it
/// — the two would otherwise be two literals free to drift, and the drift is a band painted over
/// the bar for its own height.
let instantPageV2QuoteBarWidth: CGFloat = 3.0
