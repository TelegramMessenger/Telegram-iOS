import Foundation
import UIKit
import CoreText

// The pure core of collapsed quotes: given the items a quote's children laid out to, decide which
// survive a line budget and how tall the truncated one becomes.
//
// Kept out of `InstantPageV2Layout.swift` and free of `LayoutContext` deliberately — `layoutBlockQuote`
// is private and a `LayoutContext` needs a webpage, strings and a themed `InstantPageTheme`, so nothing
// in that file is reachable from a test. This is the part with arithmetic worth testing.

/// How many text lines a collapsed quote previews. Matches `InteractiveTextComponent`'s `lineCount > 3`,
/// so a rich bubble and a regular text message in the same chat collapse to the same size.
let instantPageV2CollapsedQuoteLineBudget = 3

/// Clearance an EXPANDED quote wants between its last row and the edge the chevron sits against.
/// Only the expanded state needs it — a collapsed quote's bottom fade already clears that corner.
let instantPageV2QuoteChevronClearance: CGFloat = 16.0

/// Height added to an expanded quote whose last row leaves less than `instantPageV2QuoteChevronClearance`.
/// `InteractiveTextComponent` widens the last line first and only grows the block if that does not
/// fit; a V2 quote's width is the band's and cannot stretch, so only the grow branch survives.
let instantPageV2QuoteChevronExtraHeight: CGFloat = 10.0

enum InstantPageV2QuoteCollapseState {
    /// No control, no hit target — either the author did not mark it, or it is not longer than its
    /// own preview.
    case notCollapsible
    case collapsed
    case expanded
}

/// **Collapsible is not the same as collapsed.** Collapsibility is author-set (mirroring
/// `TextNodeBlockQuoteData.isCollapsible`, which comes from the entity flag), AND the quote has to be
/// longer than the preview — collapsing something no longer than three lines is pure noise.
func instantPageV2QuoteCollapseState(totalTextLines: Int, authorCollapsed: Bool, isExpanded: Bool) -> InstantPageV2QuoteCollapseState {
    guard authorCollapsed, totalTextLines > instantPageV2CollapsedQuoteLineBudget else {
        return .notCollapsible
    }
    return isExpanded ? .expanded : .collapsed
}

/// Text lines an item contributes to the budget. Only `.text` items count: a medium, table or nested
/// quote has no lines, and charging it a notional cost would make the preview height depend on content
/// that is not text.
func instantPageV2TextLineCount(_ item: InstantPageV2LaidOutItem) -> Int {
    if case let .text(textItem) = item {
        return textItem.textItem.lines.count
    }
    return 0
}

/// A copy of `item` holding only its first `lineCount` lines, shortened by exactly the dropped lines.
///
/// The height comes from the LINE PITCH rather than a re-measure: pitch is uniform by construction (see
/// the `RichTextRenderMetrics` contract — `pitch = L + S`, always integral), so dropping `n` lines
/// removes `n × pitch`. A single-line item can never be truncated, so the pitch is always derivable.
private func instantPageV2TruncatedTextItem(_ item: InstantPageV2TextItem, toLineCount lineCount: Int, keepingOverflow: Bool) -> InstantPageV2TextItem {
    let lines = item.textItem.lines
    guard lineCount < lines.count, lines.count >= 2 else {
        return item
    }
    let pitch = lines[1].frame.minY - lines[0].frame.minY
    let droppedHeight = CGFloat(lines.count - lineCount) * pitch

    var survivingLines = Array(lines.prefix(lineCount))
    if let last = survivingLines.last,
       let token = instantPageV2TruncationToken(for: last, in: item.textItem.attributedString) {
        // Appended only when it fits beside the line. A line that already fills the band has no room,
        // and the reference's own token lands inside the faded corner there — so skipping it costs
        // nothing visible, and buys us not having to rewrite the line's `CTLine`. See
        // `InstantPageTextLine.additionalTrailingLine`.
        let tokenWidth = CTLineGetTypographicBounds(token, nil, nil, nil)
        if last.frame.maxX + tokenWidth <= item.textItem.frame.width {
            survivingLines[survivingLines.count - 1] = last.withAdditionalTrailingLine(token)
        }
    }

    // The LAYOUT box always shrinks by the dropped lines — that is what makes the quote three lines
    // tall. What `keepingOverflow` changes is whether those lines are still DRAWN below it: kept, the
    // quote's animated fade mask sweeps them away as it closes instead of blinking them out; dropped,
    // they are gone the instant the layout changes. Only the caller knows whether anything follows
    // this item inside the quote and would be overlapped by the spill, so only the caller can decide.
    let laidOutHeight = max(0.0, item.frame.height - droppedHeight)
    if keepingOverflow {
        // Same lines, same `InstantPageTextItem` — the drawn content is untouched. Only the outer
        // item's height moves, with the difference recorded as overflow.
        var overflowing = InstantPageV2TextItem(
            frame: CGRect(origin: item.frame.origin, size: CGSize(width: item.frame.width, height: laidOutHeight)),
            textItem: InstantPageTextItem(
                frame: item.textItem.frame,
                attributedString: item.textItem.attributedString,
                alignment: item.textItem.alignment,
                opaqueBackground: item.textItem.opaqueBackground,
                lines: survivingLines + lines.suffix(from: lineCount)
            )
        )
        overflowing.overflowHeight = droppedHeight
        return overflowing
    }

    let truncatedTextItem = InstantPageTextItem(
        frame: CGRect(origin: item.textItem.frame.origin,
                      size: CGSize(width: item.textItem.frame.width,
                                   height: max(0.0, item.textItem.frame.height - droppedHeight))),
        attributedString: item.textItem.attributedString,
        alignment: item.textItem.alignment,
        opaqueBackground: item.textItem.opaqueBackground,
        lines: survivingLines
    )
    return InstantPageV2TextItem(
        frame: CGRect(origin: item.frame.origin,
                      size: CGSize(width: item.frame.width, height: laidOutHeight)),
        textItem: truncatedTextItem
    )
}

/// The prefix of `items` that fits `remainingLines` text lines, with the crossing text item truncated
/// to its surviving lines. Returns the surviving items and how much budget they consumed.
///
/// A non-text item costs nothing and is kept WHOLE as long as budget remains; once the budget is gone
/// nothing further survives, so a medium is never partially shown.
///
/// `keepingOverflow` asks for everything past the cut to stay DRAWN rather than be discarded, so the
/// quote's animated fade can sweep it away instead of blinking it out. `reserved` is what the quote
/// takes height for; `overflow` is drawn at its natural position and reserved for by nobody — which
/// is what keeps a medium or a nested quote below the cut from being torn down and rebuilt on every
/// toggle, and keeps every child's position IDENTICAL in both states.
///
/// Off by default, and it must stay off whenever anything follows the cut inside the quote: the spill
/// is only invisible because the mask clips it, and the mask is only transparent BELOW the quote's
/// bottom edge.
func instantPageV2QuoteBudgetedItems(_ items: [InstantPageV2LaidOutItem], remainingLines: Int, keepingOverflow: Bool = false) -> (reserved: [InstantPageV2LaidOutItem], overflow: [InstantPageV2LaidOutItem], linesConsumed: Int) {
    guard remainingLines > 0 else {
        return ([], keepingOverflow ? items : [], 0)
    }
    var reserved: [InstantPageV2LaidOutItem] = []
    var consumed = 0
    var cutIndex: Int?
    for (index, item) in items.enumerated() {
        let lines = instantPageV2TextLineCount(item)
        if lines == 0 {
            reserved.append(item)
            continue
        }
        let available = remainingLines - consumed
        if available <= 0 {
            cutIndex = index
            break
        }
        if lines <= available {
            reserved.append(item)
            consumed += lines
            continue
        }
        guard case let .text(textItem) = item else {
            cutIndex = index
            break
        }
        reserved.append(.text(instantPageV2TruncatedTextItem(textItem, toLineCount: available, keepingOverflow: keepingOverflow)))
        consumed += available
        cutIndex = index + 1
        break
    }
    guard keepingOverflow, let cutIndex, cutIndex < items.count else {
        return (reserved, [], consumed)
    }
    return (reserved, Array(items[cutIndex...]), consumed)
}

/// How far down an item actually PAINTS, which is its frame except for a text item carrying overflow.
/// Sibling positioning has to use this rather than `frame.maxY`, so that a quote's children land in
/// the same place collapsed and expanded.
func instantPageV2DrawnMaxY(_ item: InstantPageV2LaidOutItem) -> CGFloat {
    if case let .text(textItem) = item {
        return textItem.frame.maxY + textItem.overflowHeight
    }
    return item.frame.maxY
}

/// The "…" a collapsed quote puts after its last visible line, in that line's own font and colour.
///
/// The font is taken from the first run of the line that is REAL TEXT: an inline attachment
/// (emoji, image, formula, button) carries a `CTRunDelegate` that reports the attachment's box as
/// the run's metrics, so a line that happens to start with one would size the ellipsis to the
/// attachment rather than to the text beside it.
private func instantPageV2TruncationToken(for line: InstantPageTextLine, in attributedString: NSAttributedString) -> CTLine? {
    let range = line.range
    guard range.location >= 0, range.length > 0, range.location + range.length <= attributedString.length else {
        return nil
    }

    var font: UIFont?
    var color: UIColor?
    attributedString.enumerateAttributes(in: range, options: []) { attributes, _, stop in
        if attributes[NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String)] != nil {
            return
        }
        guard let runFont = attributes[.font] as? UIFont else {
            return
        }
        font = runFont
        color = attributes[.foregroundColor] as? UIColor
        stop.pointee = true
    }
    guard let font else {
        return nil
    }

    var tokenAttributes: [NSAttributedString.Key: Any] = [.font: font]
    if let color {
        tokenAttributes[.foregroundColor] = color
    }
    return CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2026}", attributes: tokenAttributes))
}

/// How far this item stops short of the quote edge the expand chevron sits against — the clearance
/// an EXPANDED quote checks before it lets the arrow sit beside its last row.
///
/// For text this measures the LAST LINE's drawn edge, not the item's frame: a paragraph's frame
/// always spans the whole band, so measuring the frame would report every quote as occupied and add
/// the extra height unconditionally. Everything else (media, tables, buttons) is measured by its
/// frame, which is what it paints. `item` and `quoteFrame` must be in the same coordinate space.
func instantPageV2QuoteChevronSideInset(_ item: InstantPageV2LaidOutItem, quoteFrame: CGRect, rtl: Bool) -> CGFloat {
    if case let .text(textItem) = item, let lastLine = textItem.textItem.lines.last {
        // Alignment is applied at DRAW time (`v2FrameForLine`), so a right-aligned or RTL line's
        // stored x is not where it lands — reconstruct the drawn edge from the line's width.
        let lineWidth = lastLine.frame.width
        if rtl {
            return (textItem.frame.minX + (textItem.frame.width - lineWidth)) - quoteFrame.minX
        }
        return quoteFrame.maxX - (textItem.frame.minX + lineWidth)
    }
    return rtl ? (item.frame.minX - quoteFrame.minX) : (quoteFrame.maxX - item.frame.maxX)
}
