import Foundation
import UIKit
import TelegramCore

enum BlockSequenceKind {
    case topLevel
    case detail
    case cell
    case list
}

/// Per-block-type contribution to the vertical rhythm of a block sequence.
///
/// `verticalPadding` is symmetric: it is added on BOTH sides of the block, on top of the base gap
/// (`instantPageBaseBlockSpacing`). The flush flags suppress a gap entirely on that side — the base
/// AND both neighbours' padding — for blocks that must butt against what precedes or follows them.
///
/// The flags are directional because every structural zero in this layout is one-sided: a cover is
/// flush against the page above it but takes a real gap below, before its title; related articles
/// are flush below but not above. `.anchor` is the one block that sets both, being an invisible
/// zero-height marker.
struct InstantPageBlockSpacing {
    var verticalPadding: CGFloat
    var flushAbove: Bool = false
    var flushBelow: Bool = false

    init(verticalPadding: CGFloat, flushAbove: Bool = false, flushBelow: Bool = false) {
        self.verticalPadding = verticalPadding
        self.flushAbove = flushAbove
        self.flushBelow = flushBelow
    }
}

/// The gap between any two adjacent blocks, before either block's padding is added.
let instantPageBaseBlockSpacing: CGFloat = 8.0

/// The rhythm of the "please update" pill. A fixed padding rather than a scaled one: the pill is a
/// fixed-size card that does not participate in the page's type scale.
private let instantPageUnsupportedBlockSpacing = InstantPageBlockSpacing(verticalPadding: 8.0)

extension InstantPageBlock {
    /// Resolved from the whole block value, not just its case, so a rule may depend on the payload
    /// (e.g. a checklist reading differently from a bullet list) without widening the model.
    ///
    /// Deliberately NOT exhaustive: every unnamed case takes the defaults, which are a genuine
    /// correct value rather than a silently-wrong one. Naming all thirty-odd cases to return the
    /// same literal would bury the four that carry meaning.
    /// `metrics` supplies the padding values, already scaled for the content this block sits in —
    /// page scale outside a quote, quote scale within one. The padding is therefore never a
    /// literal here: `InstantPageBlockSpacing.verticalPadding` deliberately lost its `= 4.0`
    /// default, because a defaulted padding is a literal that silently ignores the scale.
    func spacing(metrics: InstantPageMetrics) -> InstantPageBlockSpacing {
        // Ahead of the switch because spacing follows the RENDERING, not the case: a collage
        // carrying a block this build cannot decode is drawn as the pill, and the media arm below
        // would otherwise give it a media block's flush-both-sides rhythm — leaving the pill butted
        // against its neighbours like a full-bleed image.
        if blockRendersAsUnsupported(self) {
            return instantPageUnsupportedBlockSpacing
        }
        switch self {
        case .anchor:
            // A zero-height invisible marker: transparent to spacing on both sides. The padding is
            // pinned to 0 rather than left at the default — it is unreachable while both flush flags
            // are set, but a default 8.0 here reads as "an anchor has padding" and would come alive
            // the moment a flag is dropped or a new read forgets to check flush first.
            return InstantPageBlockSpacing(verticalPadding: 0.0, flushAbove: true, flushBelow: true)
        case .cover, .channelBanner:
            // Page-header elements: they butt against the top of the page, while their successor
            // (the title) takes a normal gap.
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true)
        case .relatedArticles:
            // A full-bleed footer section: flush against whatever follows it.
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushBelow: true)
        case .heading:
            return InstantPageBlockSpacing(verticalPadding: metrics.headingVerticalPadding)
        case .divider:
            return InstantPageBlockSpacing(verticalPadding: metrics.dividerVerticalPadding)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true, flushBelow: false)
            } else {
                return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true, flushBelow: true)
            }
        case .preformatted:
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true)
        case .unsupported:
            // Unreachable — the guard above answers for it — but kept so the rhythm is still
            // written where a reader looks for it.
            return instantPageUnsupportedBlockSpacing
        default:
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding)
        }
    }
}

/// The **V1 (Instant View reader)** vertical rhythm — the original, pre-V2 pairwise table, restored
/// verbatim as its own function.
///
/// V1 and V2 are two different typographic designs, not two callers of one design. The V2 rhythm
/// below is built out of per-block `verticalPadding` scaled by `InstantPageMetrics`, tuned against
/// the chat bubble's 15/17pt type; V1's is a flat table of absolute point gaps (20 / 25 / 27 / 31 /
/// 32 / 34) tuned against the reader's much larger page type. Feeding V1 the V2 table collapsed the
/// reader's spacing — which is why this is a SEPARATE function rather than a `kind`/`metrics`
/// parameter on one: the two tables share no rule, so any shared body would be a switch on which
/// renderer is asking.
///
/// **Do not "unify" these.** A change to the chat rhythm must not reach the reader, and vice versa.
/// The six V1 call sites are all in `InstantPageLayout.swift`; every other caller is V2.
func spacingBetweenBlocksV1(upper: InstantPageBlock?, lower: InstantPageBlock?) -> CGFloat {
    if let upper = upper, let lower = lower {
        switch (upper, lower) {
            // The original also listed `(.relatedArticles, nil)` here. That pattern was DEAD — `lower`
            // is non-optional inside this branch — and modern Swift rejects it outright. Dropping it
            // is behaviour-preserving; the live trailing-edge rule for `.relatedArticles` is in the
            // `else if let upper` arm at the bottom.
            case (_, .cover), (_, .channelBanner), (.details, .details), (_, .anchor):
                return 0.0
            case (.divider, _), (_, .divider):
                return 25.0
            case (_, .blockQuote), (.blockQuote, _), (_, .pullQuote), (.pullQuote, _):
                return 27.0
            case (.kicker, .title), (.cover, .title):
                return 16.0
            case (_, .title):
                return 20.0
            case (.title, .authorDate), (.subtitle, .authorDate):
                return 18.0
            case (_, .authorDate):
                return 20.0
            case (.title, .paragraph), (.authorDate, .paragraph):
                return 34.0
            case (.header, .paragraph), (.subheader, .paragraph):
                return 25.0
            case (.list, .paragraph):
                return 31.0
            case (.preformatted, .paragraph):
                return 19.0
            case (.paragraph, .paragraph):
                return 25.0
            case (_, .paragraph):
                return 20.0
            case (.title, .list), (.authorDate, .list):
                return 34.0
            case (.header, .list), (.subheader, .list):
                return 31.0
            case (.preformatted, .list):
                return 19.0
            case (_, .list):
                return 25.0
            case (.paragraph, .preformatted):
                return 19.0
            case (_, .preformatted):
                return 20.0
            case (_, .header), (_, .subheader):
                return 32.0
            default:
                return 20.0
        }
    } else if let lower = lower {
        switch lower {
            case .cover, .channelBanner, .details, .anchor:
                return 0.0
            default:
                return 25.0
        }
    } else {
        if let upper = upper, case .relatedArticles = upper {
            return 0.0
        } else {
            return 25.0
        }
    }
}

/// The **V2** vertical gap between two adjacent blocks, or at a sequence edge when one side is nil.
///
/// Three rules, in order: a flush side wins and yields 0; two `.paragraph` (body) blocks have no gap
/// at all, neither the base nor either block's padding; otherwise the gap is
/// `upper.verticalPadding + instantPageBaseBlockSpacing + lower.verticalPadding`. At an edge only the
/// one present block contributes — the base is strictly a *between two blocks* quantity.
///
/// V1 does NOT call this — see `spacingBetweenBlocksV1` above for why the reader keeps its own table.
///
/// `kind` is currently unread. It is kept because container-specific spacing (denser table cells,
/// tighter list sub-blocks) is expected to return; do not delete it as dead, and do not read its
/// absence from the body as a bug.
///
/// `metrics` is REQUIRED rather than defaulted to `.unscaled`. A default would let a new V2 call
/// site silently get page-scale spacing inside a quote — the failure mode this whole scale design
/// is built to prevent.
func spacingBetweenBlocks(upper: InstantPageBlock?, lower: InstantPageBlock?, kind: BlockSequenceKind, metrics: InstantPageMetrics) -> CGFloat {
    if let upper, let lower {
        var upperSpacing = upper.spacing(metrics: metrics)
        let lowerSpacing = lower.spacing(metrics: metrics)
        
        var upperIsRawMedia = false
        switch upper {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                upperSpacing.verticalPadding += 2.0
            } else {
                switch upper {
                case .image, .video, .slideshow, .collage, .map:
                    upperIsRawMedia = true
                default:
                    break
                }
            }
            break
        default:
            break
        }
        
        var lowerIsRawMedia = false
        switch lower {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
            } else {
                switch lower {
                case .image, .video, .slideshow, .collage, .map:
                    lowerIsRawMedia = true
                default:
                    break
                }
            }
            break
        default:
            break
        }
        
        if upperIsRawMedia && lowerIsRawMedia {
            return 1.0
        }
        
        if case .buttonRow = upper, case .buttonRow = lower {
            return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
        }
        
        if case .list = kind {
            return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
        } else {
            if case .list = upper, case .list = lower {
                return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
            }
            switch upper {
            case .heading:
                switch lower {
                case .heading:
                    return upperSpacing.verticalPadding
                case .paragraph, .thinking, .list:
                    return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
                default:
                    break
                }
            default:
                break
            }
            switch upper {
            case .paragraph:
                switch lower {
                case .heading:
                    return upperSpacing.verticalPadding + metrics.baseBlockSpacing + lowerSpacing.verticalPadding
                case .list:
                    return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
                case .paragraph:
                    // A minimum separation, not a body-font-derived size: two paragraphs are held
                    // apart by their own line boxes. Left unscaled deliberately —
                    // floorToScreenPixels(1.0 * 15/17) is 0.67pt.
                    return 1.0
                default:
                    if lowerIsRawMedia {
                        return max(1.0, upperSpacing.verticalPadding + lowerSpacing.verticalPadding + 1.0)
                    }
                }
            default:
                break
            }
            if case .list = upper {
                switch lower {
                case .paragraph:
                    return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
                default:
                    break
                }
            }
            switch lower {
            case .paragraph, .thinking, .list:
                if upperIsRawMedia {
                    return max(1.0, upperSpacing.verticalPadding + lowerSpacing.verticalPadding + 1.0)
                }
            default:
                break
            }
        }
        if case .details = upper {
            if case .details = lower {
                return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
            }
            return upperSpacing.verticalPadding + metrics.detailsAdjacentSpacing + lowerSpacing.verticalPadding
        }
        return upperSpacing.verticalPadding + metrics.baseBlockSpacing + lowerSpacing.verticalPadding
    } else if let lower {
        let lowerSpacing = lower.spacing(metrics: metrics)
        switch lower {
        case .heading:
            return max(0.0, lowerSpacing.verticalPadding - 1.0)
        case .paragraph, .thinking:
            return lowerSpacing.verticalPadding + 2.0
        case .table:
            return lowerSpacing.verticalPadding + 7.0
        default:
            break
        }
        return lowerSpacing.flushAbove ? 0.0 : lowerSpacing.verticalPadding
    } else if let upper {
        let upperSpacing = upper.spacing(metrics: metrics)
        switch upper {
        case .paragraph, .thinking:
            return upperSpacing.verticalPadding + 2.0
        case .table:
            return upperSpacing.verticalPadding + 4.0
        default:
            break
        }
        switch upper {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .slideshow(_, caption), let .collage(_, caption), let .document(_, caption), let .audio(_, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                return upperSpacing.verticalPadding + 2.0
            }
            break
        default:
            break
        }
        return upperSpacing.flushBelow ? 0.0 : upperSpacing.verticalPadding
    } else {
        return 0.0
    }
}

/// Whether a V2 page's content meets the page's top edge with no leading gap: its first block is
/// flush above (a photo, collage, code band or file row) rather than padded like text.
///
/// For a host that draws something ABOVE the page. A flush block is designed to butt against the
/// top of its container, so a header placed directly above the page runs into it, and the host has
/// to supply the gap the page does not. This is the leading edge `layoutBlockSequence` lays out: an
/// anchor contributes no height, so the block after it is the one that meets the edge.
///
/// Judged from the model, because a host needs it before it has a width to lay out at. A block
/// whose media is missing from the page lays out empty and hands the edge to its successor, which
/// this cannot see. `.unscaled` is safe here where it is not in the layout: a flush edge is 0 at
/// every content scale, and a padded one is never 0.
public func instantPageV2ContentStartsFlushAtTop(_ blocks: [InstantPageBlock]) -> Bool {
    guard let first = blocks.first(where: { block in
        if case .anchor = block {
            return false
        }
        return true
    }) else {
        return false
    }
    return spacingBetweenBlocks(upper: nil, lower: first, kind: .topLevel, metrics: .unscaled) == 0.0
}
