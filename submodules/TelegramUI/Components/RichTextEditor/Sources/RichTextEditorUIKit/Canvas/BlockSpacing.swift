#if canImport(UIKit)
import UIKit

/// What a canvas block will become when the document is rendered as an InstantPage — the vocabulary
/// the vertical-rhythm rules are written in.
///
/// The cases are exactly the `InstantPageBlock` cases the editor can produce, per
/// `InstantPageBuilder.buildInstantPage`. Adding a block type to the editor means adding its case
/// here; the pairwise-table test in `//submodules/InstantPageUI:InstantPageUITests` is what catches
/// the omission.
enum RichTextBlockSpacingKind: Equatable {
    case paragraph
    case heading
    /// A whole RUN of adjacent list items, which the renderer sees as one `.list` block.
    case list
    case preformatted
    case blockQuote
    case pullQuote
    case details
    case table
    case formula
    /// A `pageBlockButtonRow`.
    case buttonRow
    /// `isRawMedia` is true for image/video/slideshow/collage/map and false for audio/document —
    /// the distinction that decides whether the 1pt "media strip" rule applies.
    case media(hasCredit: Bool, isRawMedia: Bool)
}

/// Which kind of sequence the two blocks sit in. `.cell` is currently unread, mirroring the
/// renderer's own unread `.cell`; keep it rather than deleting it as dead, and do not read its
/// absence from the body as a bug.
enum RichTextBlockSequenceKind {
    case topLevel
    case cell
    case list
}

/// Symmetric padding a block contributes on BOTH sides, plus the one-sided flush flags. The flush
/// flags are consulted ONLY at a sequence edge — the both-blocks-present rules never read them,
/// which mirrors the renderer exactly.
private struct BlockPadding {
    var verticalPadding: CGFloat
    var flushAbove: Bool = false
    var flushBelow: Bool = false
}

private func padding(_ kind: RichTextBlockSpacingKind, _ m: RichTextRenderMetrics) -> BlockPadding {
    switch kind {
    case .heading:
        return BlockPadding(verticalPadding: m.headingVerticalPadding)
    case let .media(hasCredit, _):
        // A bare media block butts against both neighbours; a credited one needs room below for the
        // credit, so only its top is flush.
        return BlockPadding(verticalPadding: m.blockVerticalPadding, flushAbove: true, flushBelow: !hasCredit)
    case .preformatted:
        // Flush at the TOP of a sequence only, mirroring the renderer's `.preformatted` arm in
        // `InstantPageBlock.spacing(metrics:)`. A code block opening the document sits against the
        // top edge; below it the normal gap still applies, so `flushBelow` stays false.
        //
        // Both flush flags are read ONLY at a sequence edge, so this changes the leading edge and
        // nothing else — the pairwise rules never consult them.
        return BlockPadding(verticalPadding: m.blockVerticalPadding, flushAbove: true)
    default:
        return BlockPadding(verticalPadding: m.blockVerticalPadding)
    }
}

private func isRawMedia(_ kind: RichTextBlockSpacingKind) -> Bool {
    if case let .media(hasCredit, raw) = kind { return !hasCredit && raw }
    return false
}

/// The vertical gap between two adjacent blocks, or at a sequence edge when one side is nil.
///
/// A transcription of `InstantPageLayoutSpacings.spacingBetweenBlocks`. **The rule ORDER is
/// load-bearing** — several arms would otherwise both match — so this reads in the same order as the
/// renderer's function rather than being reorganised into something tidier.
func richTextSpacingBetweenBlocks(
    upper: RichTextBlockSpacingKind?,
    lower: RichTextBlockSpacingKind?,
    kind: RichTextBlockSequenceKind,
    metrics m: RichTextRenderMetrics
) -> CGFloat {
    /// Only the OUTER spacing is trimmed, and never below 0.
    func trimmedEdge(_ value: CGFloat) -> CGFloat {
        return max(0.0, value - m.edgeSpacingReduction)
    }

    if let upper, let lower {
        var upperPadding = padding(upper, m)
        let lowerPadding = padding(lower, m)

        // A credited media block's own padding grows by 2 for the credit line.
        if case let .media(hasCredit, _) = upper, hasCredit {
            upperPadding.verticalPadding += 2.0
        }
        let upperIsRaw = isRawMedia(upper)
        let lowerIsRaw = isRawMedia(lower)
        let sum = upperPadding.verticalPadding + lowerPadding.verticalPadding

        if upperIsRaw && lowerIsRaw { return 1.0 }

        // ORDER IS LOAD-BEARING: this sits BEFORE the `.list` checks, mirroring
        // `InstantPageLayoutSpacings.spacingBetweenBlocks`.
        if case .buttonRow = upper, case .buttonRow = lower { return sum }

        if case .list = kind { return sum }

        if case .list = upper, case .list = lower { return sum }

        if case .heading = upper {
            switch lower {
            case .heading: return upperPadding.verticalPadding
            case .paragraph, .list: return sum
            default: break
            }
        }

        if case .paragraph = upper {
            switch lower {
            case .heading:
                return upperPadding.verticalPadding + m.baseBlockSpacing + lowerPadding.verticalPadding
            case .list:
                return sum
            case .paragraph:
                // A minimum separation, not a font-derived size: two paragraphs are already held
                // apart by their own line boxes. Deliberately unscaled.
                return 1.0
            default:
                if lowerIsRaw { return max(1.0, sum + 1.0) }
            }
        }

        if case .list = upper, case .paragraph = lower { return sum }

        switch lower {
        case .paragraph, .list:
            if upperIsRaw { return max(1.0, sum + 1.0) }
        default:
            break
        }

        if case .details = upper {
            if case .details = lower { return sum }
            return upperPadding.verticalPadding + m.detailsAdjacentSpacing + lowerPadding.verticalPadding
        }

        return upperPadding.verticalPadding + m.baseBlockSpacing + lowerPadding.verticalPadding
    } else if let lower {
        let p = padding(lower, m)
        switch lower {
        // Mirrors the renderer's `.heading` arm in `spacingBetweenBlocks`: a heading opening the
        // document sits 1pt tighter to the top edge than its own padding. Transcribed here because
        // nothing links the two files at compile time — `RichTextV2MetricsParityTests` is the check.
        case .heading:   return trimmedEdge(max(0.0, p.verticalPadding - 1.0))
        case .paragraph: return trimmedEdge(p.verticalPadding + 2.0)
        case .table:     return trimmedEdge(p.verticalPadding + 7.0)
        default:         break
        }
        return trimmedEdge(p.flushAbove ? 0.0 : p.verticalPadding)
    } else if let upper {
        let p = padding(upper, m)
        switch upper {
        case .paragraph: return trimmedEdge(p.verticalPadding + 2.0)
        case .table:     return trimmedEdge(p.verticalPadding + 4.0)
        case let .media(hasCredit, _) where hasCredit:
            return trimmedEdge(p.verticalPadding + 2.0)
        default:
            break
        }
        return trimmedEdge(p.flushBelow ? 0.0 : p.verticalPadding)
    } else {
        return 0.0
    }
}
#endif
