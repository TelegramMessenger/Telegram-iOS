import Foundation
import UIKit
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import TelegramStringFormatting
import MosaicLayout
import UnsupportedContentPill

// MARK: - Public layout data types

public struct InstantPageV2Layout {
    public let contentSize: CGSize
    public let items: [InstantPageV2LaidOutItem]
    /// Snapshot of the `index` values of every `.details` item present in `items`, captured at layout time.
    public let detailsIndices: [Int]
    /// Media dictionary inherited from the page's `LayoutContext.media`. Used by
    /// `InstantPageV2View.updateInlineImages()` to resolve each text view's
    /// `line.imageItems` MediaIds at update time. Nested layouts (details body,
    /// table cells, table title) carry the parent's same map.
    public let media: [EngineMedia.Id: EngineMedia]
    /// Webpage carried for the same reason — `updateInlineImages()` needs it to
    /// form the `WebpageReference` for `ImageMediaReference.webPage(...)`. May
    /// be nil for non-webpage-anchored layouts; in that case the lookup proceeds
    /// but no fetch signal can be bound (image view simply isn't created).
    public let webpage: TelegramMediaWebpage?

    /// Set by `layoutInstantPageV2` when the page contains at least one `.relative` `textDate`.
    /// The minimum refresh period (seconds, >=10) across all relative dates; the rich-data bubble
    /// schedules a timer on it to keep "N minutes ago" fresh. nil => no relative date => no timer.
    public var formattedDateUpdatePeriod: Int32? = nil

    public init(contentSize: CGSize, items: [InstantPageV2LaidOutItem], detailsIndices: [Int], media: [EngineMedia.Id: EngineMedia] = [:], webpage: TelegramMediaWebpage? = nil) {
        self.contentSize = contentSize
        self.items = items
        self.detailsIndices = detailsIndices
        self.media = media
        self.webpage = webpage
    }

    /// Returns every `InstantPageMedia` produced by this layout (or its nested sub-layouts)
    /// in laid-out order. Used by the gallery helper to enumerate sibling medias and find
    /// central index, mirroring V1's `mediasFromItems(_:)`.
    public func allMedias() -> [InstantPageMedia] {
        var result: [InstantPageMedia] = []
        InstantPageV2Layout.collectMedias(in: self.items, into: &result)
        return result
    }

    private static func collectMedias(in items: [InstantPageV2LaidOutItem], into result: inout [InstantPageMedia]) {
        for item in items {
            switch item {
            case let .mediaImage(m):       result.append(m.media)
            case let .mediaVideo(m):       result.append(m.media)
            case let .mediaMap(m):         result.append(m.media)
            case let .mediaCoverImage(m):  result.append(m.media)
            case let .mediaAudio(m):       result.append(m.media)
            case let .slideshow(s):        result.append(contentsOf: s.medias)
            case let .details(d):
                if let inner = d.innerLayout {
                    collectMedias(in: inner.items, into: &result)
                }
            case let .table(t):
                if let title = t.titleSubLayout {
                    collectMedias(in: title.items, into: &result)
                }
                for cell in t.cells {
                    if let sub = cell.subLayout {
                        collectMedias(in: sub.items, into: &result)
                    }
                }
            default:
                continue
            }
        }
    }
}

public enum InstantPageV2LaidOutItem {
    case text(InstantPageV2TextItem)
    case codeBlock(InstantPageV2CodeBlockItem)
    case divider(InstantPageV2DividerItem)
    case listMarker(InstantPageV2ListMarkerItem)
    case blockQuoteBar(InstantPageV2BarItem)
    case shape(InstantPageV2ShapeItem)
    case imageOrnament(InstantPageV2ImageOrnamentItem)
    case mediaPlaceholder(InstantPageV2MediaPlaceholderItem)
    case details(InstantPageV2DetailsItem)
    case table(InstantPageV2TableItem)
    case anchor(InstantPageV2AnchorItem)
    case mediaImage(InstantPageV2MediaImageItem)
    case mediaVideo(InstantPageV2MediaVideoItem)
    case mediaMap(InstantPageV2MediaMapItem)
    case mediaCoverImage(InstantPageV2MediaCoverImageItem)
    case mediaAudio(InstantPageV2MediaAudioItem)
    case formula(InstantPageV2FormulaItem)
    case inlineButton(InstantPageV2InlineButtonItem)
    case buttonRow(InstantPageV2ButtonRowItem)
    case document(InstantPageV2DocumentItem)
    case thinking(InstantPageV2ThinkingItem)
    case slideshow(InstantPageV2SlideshowItem)
    case quoteFrame(InstantPageV2QuoteFrameItem)
    case unsupportedContent(InstantPageV2UnsupportedItem)

    public var frame: CGRect {
        switch self {
        case let .text(item):              return item.frame
        case let .codeBlock(item):         return item.frame
        case let .divider(item):           return item.frame
        case let .listMarker(item):        return item.frame
        case let .blockQuoteBar(item):     return item.frame
        case let .shape(item):             return item.frame
        case let .imageOrnament(item):     return item.frame
        case let .mediaPlaceholder(item):  return item.frame
        case let .details(item):           return item.frame
        case let .table(item):             return item.frame
        case let .anchor(item):            return item.frame
        case let .mediaImage(item):        return item.frame
        case let .mediaVideo(item):        return item.frame
        case let .mediaMap(item):          return item.frame
        case let .mediaCoverImage(item):   return item.frame
        case let .mediaAudio(item):        return item.frame
        case let .formula(item):           return item.frame
        case let .inlineButton(item):      return item.frame
        case let .buttonRow(item):         return item.frame
        case let .document(item):          return item.frame
        case let .thinking(item):          return item.frame
        case let .slideshow(item):         return item.frame
        case let .quoteFrame(item):        return item.frame
        case let .unsupportedContent(item): return item.frame
        }
    }

    /// Returns a copy of `self` with its top-level frame translated by `delta`.
    /// Sub-layouts inside details/table cells are not re-translated — they're already
    /// expressed in their parent's local coordinates.
    public func offsetBy(_ delta: CGPoint) -> InstantPageV2LaidOutItem {
        switch self {
        case var .text(item):             item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .text(item)
        case var .codeBlock(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .codeBlock(item)
        case var .divider(item):          item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .divider(item)
        case var .listMarker(item):       item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .listMarker(item)
        case var .blockQuoteBar(item):    item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .blockQuoteBar(item)
        case var .shape(item):            item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .shape(item)
        case var .imageOrnament(item):    item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .imageOrnament(item)
        case var .mediaPlaceholder(item): item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaPlaceholder(item)
        case var .details(item):          item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .details(item)
        case var .table(item):            item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .table(item)
        case var .anchor(item):           item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .anchor(item)
        case var .mediaImage(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaImage(item)
        case var .mediaVideo(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaVideo(item)
        case var .mediaMap(item):          item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaMap(item)
        case var .mediaCoverImage(item):   item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaCoverImage(item)
        case var .mediaAudio(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .mediaAudio(item)
        case var .formula(item):          item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); item.centeringBounds = item.centeringBounds?.offsetBy(dx: delta.x, dy: delta.y); return .formula(item)
        case var .inlineButton(item):     item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .inlineButton(item)
        case var .buttonRow(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .buttonRow(item)
        case var .document(item):         item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .document(item)
        case var .thinking(item):         item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .thinking(item)
        case var .slideshow(item):        item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .slideshow(item)
        case var .quoteFrame(item):       item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .quoteFrame(item)
        case var .unsupportedContent(item): item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .unsupportedContent(item)
        }
    }
}

public struct InstantPageV2TextItem {
    public var frame: CGRect
    public let textItem: InstantPageTextItem   // V1 type reused as payload
    /// Height DRAWN below `frame` that the layout does not reserve — normally zero.
    ///
    /// A collapsed quote sets it so the lines past its three-line preview stay rendered while
    /// contributing nothing to the quote's height. Nothing outside the quote may see them, and
    /// nothing does: the only producer is `instantPageV2QuoteBudgetedItems`, which sets it solely for
    /// the item sitting at a collapsed quote's bottom edge — the item the fade mask covers. The mask
    /// is what clips the overflow, and because the mask ANIMATES, collapsing sweeps those lines away
    /// instead of blinking them out. See `InstantPageV2QuoteCollapse.swift`.
    public var overflowHeight: CGFloat = 0.0
}

public struct InstantPageV2CodeBlockItem {
    public var frame: CGRect
    /// Plain, flat band fill. Sourced from `InstantPageTheme.codeBlockBackgroundColor`, which the
    /// message hosts set to the same value they give `tableHeaderColor` — a code block reads as a
    /// highlighted table row, not as an accent-tinted quote.
    public let backgroundColor: UIColor
    public let language: String?
    /// The language line, laid out at LAYOUT time in block-local coordinates. It used to be built by
    /// the view from a bare point size, which made it the only font in the V2 renderer that could
    /// leak past the layout's content scale.
    public let languageItem: InstantPageTextItem?
    public let textItem: InstantPageTextItem
    public let inset: UIEdgeInsets
}

public struct InstantPageV2ThinkingItem {
    public var frame: CGRect
    /// The dimmed thinking text, laid out in block-local coordinates. Drawn fully (never
    /// char-reveal-masked); the shimmer + whole-block fade are the only animations.
    public let textItem: InstantPageTextItem
}

public struct InstantPageV2DividerItem {
    public var frame: CGRect
    public let color: UIColor
}

public struct InstantPageV2CheckboxColors {
    public let background: UIColor
    public let stroke: UIColor
    public let border: UIColor

    public init(background: UIColor, stroke: UIColor, border: UIColor) {
        self.background = background
        self.stroke = stroke
        self.border = border
    }
}

public enum InstantPageV2ListMarkerKind {
    case bullet
    /// The MEASURED attributed string, not a bare `String`, so the marker is drawn with exactly the
    /// attributes its column width was measured with — font size, weight, serif and colour all ride
    /// along. The renderer previously rebuilt it as a hardcoded `systemFont(ofSize: 17.0)`, which
    /// silently disagreed with the theme's paragraph font and broke the column alignment it feeds.
    ///
    /// `alignment` pins the number to the text-facing edge of the shared marker column: trailing in
    /// LTR (so the dots line up), leading in RTL, where the column is mirrored onto the right.
    case number(NSAttributedString, alignment: NSTextAlignment)
    case checklist(checked: Bool, colors: InstantPageV2CheckboxColors)
}

public struct InstantPageV2ListMarkerItem {
    public var frame: CGRect
    public let kind: InstantPageV2ListMarkerKind
    public let color: UIColor
    /// Structural path (root→list item) for a `.checklist` marker; nil for bullet/number markers.
    public let checkboxPath: [Int]?
}

public struct InstantPageV2BarItem {
    public var frame: CGRect
    public let color: UIColor
    public let cornerRadius: CGFloat
}

public struct InstantPageV2QuoteFrameItem {
    public var frame: CGRect
    public let accentColor: UIColor
    public let barWidth: CGFloat
    public let cornerRadius: CGFloat
    public let fillAlpha: CGFloat
    public let barOnTrailing: Bool   // RTL: bar on the trailing (right) edge → mirror the fill
    /// Whether this quote shows an expand control, and which way it points. `.notCollapsible` means the
    /// author did not mark it collapsed, or it is not longer than its own preview.
    let collapseState: InstantPageV2QuoteCollapseState
    /// The quote's structural block path — the identity its expanded/collapsed state is keyed by, and
    /// the same addressing `checkboxTapped` uses. Deliberately NOT an ordinal: blocks are appended
    /// during AI streaming, which would shift ordinals under the state.
    let path: [Int]
}

public enum InstantPageV2ShapeKind {
    case roundedRect(cornerRadius: CGFloat)
    case line(thickness: CGFloat)
}

public struct InstantPageV2ShapeItem {
    public var frame: CGRect
    public let kind: InstantPageV2ShapeKind
    public let color: UIColor
}

public struct InstantPageV2ImageOrnamentItem {
    public var frame: CGRect
    public let imageName: String   // e.g. "Chat/Message/ReplyQuoteIcon"
    public let color: UIColor      // tint
    public let rotated: Bool       // true → 180° (closing mark)
}

public struct InstantPageV2FormulaItem {
    public var frame: CGRect                          // outer frame in parent coords
    public let attachment: InstantPageMathAttachment  // rendered image + dimensions (theme-baked)
    public let isScrollable: Bool                     // true only for block formulas wider than bounds
    public let imageFrame: CGRect                     // image rect in this item's local coords; size must equal attachment.rendered.size for pixel-perfect rendering
    public let scrollContentSize: CGSize              // == frame.size unless isScrollable

    /// The horizontal band a *block* formula is centered within, in the same coordinate space as
    /// `frame` (so it is translated alongside it by `offsetBy`). Non-nil only for a narrow block
    /// formula: `nil` marks the two kinds that must keep the position the layout gave them —
    /// inline formula runs (pinned to their glyph position inside a text line) and wide/scrollable
    /// block formulas (full-bleed, panned inside their own scroll view).
    ///
    /// Centering is resolved by `layoutBlockSequence` *after* the sequence's `contentSize` is known,
    /// not here: under `fitToWidth` the achieved content width shrinks below `boundingWidth`, and
    /// centering against the pre-shrink width would push the formula off to the right.
    public var centeringBounds: CGRect? = nil
}

/// An inline `RichText.textButton`. Emitted as a top-level item next to the text item it visually
/// sits inside, exactly as inline formulas are.
public struct InstantPageV2InlineButtonItem {
    public var frame: CGRect                                  // parent coords
    public let attachment: InstantPageInlineButtonAttachment   // model + laid-out label + metrics
}

/// A block-level `pageBlockButtonRow`. One item per block (which may wrap onto several visual rows);
/// each entry's frame is local to the item.
public struct InstantPageV2ButtonRowItem {
    public var frame: CGRect
    public let buttons: [(attachment: InstantPageInlineButtonAttachment, frame: CGRect)]
}

/// A generic file row (`InstantPageBlock.document`). Same shape as `InstantPageV2MediaAudioItem`,
/// deliberately: it is the same kind of thing minus playback.
public struct InstantPageV2DocumentItem {
    public var frame: CGRect
    public let media: InstantPageMedia
    public let webPage: TelegramMediaWebpage

    public init(frame: CGRect, media: InstantPageMedia, webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.media = media
        self.webPage = webPage
    }
}

public enum InstantPageV2MediaPlaceholderKind {
    case image
    case video
    case audio
    case webEmbed
    case postEmbed
    case collage
    case slideshow
    case channelBanner
    case map
    case relatedArticles
}

public struct InstantPageV2MediaImageItem {
    public var frame: CGRect
    public let cornerRadius: CGFloat
    public let media: InstantPageMedia
    public let webPage: TelegramMediaWebpage
    public let attributes: [InstantPageImageAttribute]   // always empty for image; kept for symmetry
    public let spoiler: Bool
    /// Aspect-FIT + blurred backdrop (single media, whose frame is height-capped) vs the default
    /// aspect-FILL crop (collage cells). See `InstantPageImageNode.fit`. Default false = crop.
    public let fit: Bool

    public init(frame: CGRect, cornerRadius: CGFloat, media: InstantPageMedia, webPage: TelegramMediaWebpage, attributes: [InstantPageImageAttribute], spoiler: Bool = false, fit: Bool = false) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.media = media
        self.webPage = webPage
        self.attributes = attributes
        self.spoiler = spoiler
        self.fit = fit
    }
}

public struct InstantPageV2MediaAudioItem {
    public var frame: CGRect
    public let media: InstantPageMedia
    public let webPage: TelegramMediaWebpage

    public init(frame: CGRect, media: InstantPageMedia, webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.media = media
        self.webPage = webPage
    }
}

public struct InstantPageV2MediaVideoItem {
    public var frame: CGRect
    public let cornerRadius: CGFloat
    public let media: InstantPageMedia
    public let webPage: TelegramMediaWebpage
    public let attributes: [InstantPageImageAttribute]   // always empty
    public let spoiler: Bool
    /// Aspect-FIT + blurred backdrop (single media, whose frame is height-capped) vs the default
    /// aspect-FILL crop (collage cells). See `InstantPageImageNode.fit`. Default false = crop.
    public let fit: Bool

    public init(frame: CGRect, cornerRadius: CGFloat, media: InstantPageMedia, webPage: TelegramMediaWebpage, attributes: [InstantPageImageAttribute], spoiler: Bool = false, fit: Bool = false) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.media = media
        self.webPage = webPage
        self.attributes = attributes
        self.spoiler = spoiler
        self.fit = fit
    }
}

public struct InstantPageV2MediaMapItem {
    public var frame: CGRect
    public let cornerRadius: CGFloat
    public let media: InstantPageMedia
    public let webPage: TelegramMediaWebpage
    public let attributes: [InstantPageImageAttribute]   // [InstantPageMapAttribute] with zoom + dimensions

    public init(frame: CGRect, cornerRadius: CGFloat, media: InstantPageMedia, webPage: TelegramMediaWebpage, attributes: [InstantPageImageAttribute]) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.media = media
        self.webPage = webPage
        self.attributes = attributes
    }
}

public struct InstantPageV2MediaCoverImageItem {
    public var frame: CGRect
    public let cornerRadius: CGFloat
    public let media: InstantPageMedia                   // media.media == .webpage(synthesized fake webpage with cover image)
    public let webPage: TelegramMediaWebpage             // the parent IV's webpage (for WebpageReference)
    public let attributes: [InstantPageImageAttribute]   // always empty

    public init(frame: CGRect, cornerRadius: CGFloat, media: InstantPageMedia, webPage: TelegramMediaWebpage, attributes: [InstantPageImageAttribute]) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.media = media
        self.webPage = webPage
        self.attributes = attributes
    }
}

public struct InstantPageV2MediaPlaceholderItem {
    public var frame: CGRect
    public let kind: InstantPageV2MediaPlaceholderKind
    public let cornerRadius: CGFloat
}

public struct InstantPageV2SlideshowItem {
    public var frame: CGRect
    public let medias: [InstantPageMedia]
    public let webPage: TelegramMediaWebpage

    public init(frame: CGRect, medias: [InstantPageMedia], webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.medias = medias
        self.webPage = webPage
    }
}

public struct InstantPageV2DetailsItem {
    public var frame: CGRect
    public let index: Int
    public let sideInset: CGFloat
    public let titleTextItem: InstantPageTextItem
    public let titleFrame: CGRect            // local to this item's frame
    public let separatorColor: UIColor
    public let isExpanded: Bool
    public let innerLayout: InstantPageV2Layout?
    public let defaultExpanded: Bool         // from the InstantPageBlock model
    public let rtl: Bool                      // mirror chevron + title onto the trailing edge
}

public enum InstantPageV2TableVerticalAlignment {
    case top, middle, bottom
}

public struct InstantPageV2TableCell {
    public let frame: CGRect                 // local to the table's content area
    public let isHeader: Bool
    public let horizontalAlignment: NSTextAlignment
    public let verticalAlignment: InstantPageV2TableVerticalAlignment
    public let backgroundColor: UIColor?
    public let subLayout: InstantPageV2Layout?
}

public struct InstantPageV2TableItem {
    public var frame: CGRect
    public let titleSubLayout: InstantPageV2Layout?
    public let titleFrame: CGRect?
    public let contentSize: CGSize           // grid intrinsic size; may exceed frame.width → scroll
    public let contentInset: CGFloat         // page horizontalInset; the renderer shifts the grid right by it and pads the scroll content by it on BOTH sides
    public let cells: [InstantPageV2TableCell]
    public let horizontalLines: [CGRect]
    public let verticalLines: [CGRect]
    public let bordered: Bool
    public let striped: Bool
    public let borderColor: UIColor
}

public struct InstantPageV2AnchorItem {
    public var frame: CGRect                 // zero-height
    public let name: String
}

// MARK: - Public entry points

public func layoutInstantPageV2(
    webpage: TelegramMediaWebpage,
    instantPage: InstantPage,
    userLocation: MediaResourceUserLocation,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    theme: InstantPageTheme,
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat,
    cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight?,
    expandedDetails: [Int: Bool],
    /// Quotes the reader has expanded. Defaulted so the four non-chat V2 call sites are unchanged: a
    /// preview surface renders the author's collapsed state and offers no way to expand it.
    expandedQuotePaths: Set<[Int]> = [],
    fitToWidth: Bool,
    computeRevealCharacterRects: Bool = false,
    /// Points trimmed from the TOP-LEVEL sequence's leading and trailing spacing (clamped at 0).
    ///
    /// For a host that insets the whole page — the chat bubble insets it 1pt so media sits inside
    /// the rounded container rather than being clipped by it — this gives that inset back out of the
    /// page's own outer padding, so the blocks keep their absolute positions and the host keeps its
    /// size. Default 0: the other V2 surfaces place the page flush and must not lose padding.
    edgeSpacingReduction: CGFloat = 0.0,
    /// The host's typography scale over the theme's authored sizes — a chat bubble passes
    /// `baseDisplaySize / 17` so a rich message follows Settings ▸ Appearance ▸ Text Size like a plain
    /// one. Applied ONCE, to fonts and geometry alike, in `InstantPageV2ScaledLayoutInputs`; `theme`
    /// must therefore be the UNSCALED theme. Default 1.0: every other V2 surface is unchanged.
    contentScale: CGFloat = 1.0
) -> InstantPageV2Layout {
    guard case let .Loaded(loadedContent) = webpage.content else {
        return InstantPageV2Layout(contentSize: .zero, items: [], detailsIndices: [])
    }

    var media = instantPage.media.mapValues(EngineMedia.init)
    if let image = loadedContent.image, let id = image.id {
        media[id] = .image(image)
    }
    if let video = loadedContent.file, let id = video.id {
        media[id] = .file(video)
    }

    let dateAccumulator = DateUpdateAccumulator()
    let formatDate: (Int32, MessageTextEntityType.DateTimeFormat) -> String = { timestamp, format in
        if case .relative = format {
            let now = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let age = abs(now - timestamp)
            // Cap the fastest bucket at 10s (the message-entity reference uses 1s for <120s).
            let period: Int32 = age < 120 ? 10 : (age <= 60 * 60 ? 60 : 30 * 60)
            dateAccumulator.period = dateAccumulator.period.map { min($0, period) } ?? period
        }
        return stringForEntityFormattedDate(timestamp: timestamp, format: format, strings: strings, dateTimeFormat: dateTimeFormat)
    }

    // A scaled theme scaled again floors its categories twice while `fontSizeMultiplier` compounds
    // exactly, so body text and the heading ladder drift apart by a point. The Instant View reader's
    // themes arrive pre-scaled by the reader's slider and pass 1.0 here; a chat host passes the authored
    // theme and the scale. Anything else is a bug at the call site, not something to reconcile here.
    assert(theme.fontSizeMultiplier == 1.0 || contentScale == 1.0, "layoutInstantPageV2: pass an unscaled theme with contentScale, or a scaled theme with contentScale 1.0 — never both")
    let scaled = InstantPageV2ScaledLayoutInputs(baseTheme: theme, contentScale: contentScale)

    var context = LayoutContext(
        theme: scaled.theme,
        metrics: scaled.metrics,
        quoteTheme: scaled.quoteTheme,
        quoteMetrics: scaled.quoteMetrics,
        strings: strings,
        dateTimeFormat: dateTimeFormat,
        formatDate: formatDate,
        userLocation: userLocation,
        webpage: webpage,
        media: media,
        cachedMessageSyntaxHighlight: cachedMessageSyntaxHighlight,
        rtl: instantPage.rtl,
        fitToWidth: fitToWidth,
        computeRevealCharacterRects: computeRevealCharacterRects,
        pageHorizontalInset: horizontalInset,
        edgeSpacingReduction: edgeSpacingReduction,
        mediaIndexCounter: 0,
        detailsIndexCounter: 0,
        expandedDetails: expandedDetails,
        expandedQuotePaths: expandedQuotePaths
    )

    var result = layoutBlockSequence(
        instantPage.blocks,
        boundingWidth: boundingWidth,
        horizontalInset: horizontalInset,
        kind: .topLevel,
        context: &context
    )
    result.formattedDateUpdatePeriod = dateAccumulator.period
    return result
}

/// Used by `ChatMessageRichDataBubbleContentNode` to anchor the date/checks status node at the
/// bottom-right of the last text line in the bubble.
public func lastTextLineFrame(in layout: InstantPageV2Layout) -> CGRect? {
    // Walk items in reverse; descend into the LAST sub-layout when the last container has one.
    for item in layout.items.reversed() {
        switch item {
        case let .text(text):
            if let last = text.textItem.lines.last {
                return last.frame.offsetBy(dx: text.frame.minX, dy: text.frame.minY)
            }
        case let .codeBlock(block):
            if let last = block.textItem.lines.last {
                return last.frame
                    .offsetBy(dx: block.textItem.frame.minX, dy: block.textItem.frame.minY)
                    .offsetBy(dx: block.frame.minX, dy: block.frame.minY)
            }
        case let .details(details):
            if let inner = details.innerLayout, let innerFrame = lastTextLineFrame(in: inner) {
                return innerFrame.offsetBy(dx: details.frame.minX, dy: details.frame.minY + details.titleFrame.maxY)
            }
            // Title fallback
            if let last = details.titleTextItem.lines.last {
                return last.frame
                    .offsetBy(dx: details.titleTextItem.frame.minX, dy: details.titleTextItem.frame.minY)
                    .offsetBy(dx: details.frame.minX, dy: details.frame.minY)
            }
        case let .table(table):
            // Walk cells in reverse row-major order (last cell of last row first).
            // The renderer shifts cells down by gridOffsetY (title height) — match that here.
            let gridOffsetY = table.titleFrame?.height ?? 0.0
            for cell in table.cells.reversed() {
                if let subLayout = cell.subLayout, let frame = lastTextLineFrame(in: subLayout) {
                    return frame
                        .offsetBy(dx: cell.frame.minX, dy: cell.frame.minY + gridOffsetY)
                        .offsetBy(dx: table.frame.minX, dy: table.frame.minY)
                }
            }
        default:
            continue
        }
    }
    return nil
}

/// Variant of `lastTextLineFrame(in:)` that returns the last text line frame only when the
/// bottom-most top-level item in the layout is itself a text item. When the layout ends in a
/// non-text item (table, image, divider, list marker, details, …) it returns nil, so callers
/// place the trailing status below all content rather than beside text buried above the final
/// item.
///
/// Also returns `trailingBottomPadding`: the renderer draws the baseline at the line frame's maxY,
/// so the visible text of a plain line sits ~5pt below it. A status that *trails on the line* should
/// anchor at `maxY + trailingBottomPadding` to align with where the text actually renders. The pad
/// is 0 when the line is taller than its font line height (a tall inline attachment, e.g. a formula,
/// already pushes maxY down to the right spot). Callers should NOT apply the pad when the status
/// wraps onto its own line below the text — there it should sit at the bare maxY.
public func lastTextLineFrameIfLastItemIsText(in layout: InstantPageV2Layout) -> (frame: CGRect, trailingBottomPadding: CGFloat)? {
    guard let bottomItem = layout.items.max(by: { $0.frame.maxY < $1.frame.maxY }),
          case let .text(text) = bottomItem,
          let last = text.textItem.lines.last
    else {
        return nil
    }
    // The stored line frame always has minX = 0 — alignment (center / right / natural-RTL) is
    // applied at render time by `v2FrameForLine`. Apply the same correction here so the returned
    // frame's `maxX` reflects the line's actual on-screen right edge, not just its width anchored
    // at the textItem's left. Without this, a right-aligned or RTL last line — whose visible right
    // edge sits at `textItem.width`, all the way at the right text inset — would feed the status
    // node a `contentWidth` equal to just `lineWidth`. The trail/wrap decision would then think
    // the date fits trailing the line, and place it directly on top of the line at the right text
    // inset where the line itself ends. The width is unchanged; only `origin.x` shifts.
    let displayedLineFrame = v2FrameForLine(last, boundingWidth: text.textItem.frame.width, alignment: text.textItem.alignment)
    let lineFrame = displayedLineFrame.offsetBy(dx: text.frame.minX, dy: text.frame.minY)
    var ascent: CGFloat = 0.0
    var descent: CGFloat = 0.0
    var leading: CGFloat = 0.0
    _ = CTLineGetTypographicBounds(last.line, &ascent, &descent, &leading)
    let isInflatedByAttachment = lineFrame.height > ascent + descent + 1.0
    return (lineFrame, isInflatedByAttachment ? 0.0 : 5.0)
}

/// Returns the frame of the bottom-most laid-out item when that item is full-width visual media
/// (image / video / cover image / map / slideshow / media placeholder), else nil. Used by the
/// rich-message bubble to overlay the date/status as an image-style pill on the media's bottom-right
/// corner instead of reserving a status strip below the content. The "full-width" gate excludes a
/// rare narrow/centered trailing media, which keeps the below-content bubble status.
/// Whether a laid-out item is visual media the overlaid date pill is designed to sit on.
private func isOverlayEligibleMedia(_ item: InstantPageV2LaidOutItem) -> Bool {
    switch item {
    case .mediaImage, .mediaVideo, .mediaCoverImage, .mediaMap, .slideshow:
        return true
    case let .mediaPlaceholder(placeholder):
        // Only a still-loading image/video placeholder should get the overlaid pill (so the style
        // doesn't flip when it resolves). Web/post-embed, channel-banner, and audio placeholders must
        // NOT — they aren't visual media the pill is designed for, and the prepare-phase structural
        // detector doesn't externalize their reactions, which would otherwise make reactions vanish.
        switch placeholder.kind {
        case .image, .video:
            return true
        default:
            return false
        }
    default:
        return false
    }
}

public func lastFullWidthMediaFrame(in layout: InstantPageV2Layout) -> CGRect? {
    guard let bottomEdge = layout.items.map({ $0.frame.maxY }).max() else {
        return nil
    }
    // Consider the whole bottom ROW, not just the single bottom-most item. A `.collage` lays out one
    // media item PER CELL, so a mosaic ends in several items side by side rather than one full-width
    // item; taking only the bottom-most would see a half-width cell, fail the full-width gate below,
    // and fall back to the inline text-time style even though the message plainly ends with media.
    // (`.slideshow` never needed this — it is a single full-width item.)
    //
    // The tolerance is deliberately tiny: cells in a mosaic row share a bottom edge to within
    // rounding, whereas a caption or text line below media sits a whole line-height lower and so
    // stays out of the band — which is what keeps a captioned collage on the text-time style.
    let bottomBandTolerance: CGFloat = 2.0
    let bottomItems = layout.items.filter { $0.frame.maxY >= bottomEdge - bottomBandTolerance }
    guard let firstBottomItem = bottomItems.first else {
        return nil
    }
    // EVERY item on the bottom row must be eligible media: one text item down there means the
    // message ends with text, wherever the media sits.
    guard bottomItems.allSatisfy(isOverlayEligibleMedia) else {
        return nil
    }
    let frame = bottomItems.dropFirst().reduce(firstBottomItem.frame) { $0.union($1.frame) }
    // Full-width gate: the media must span (approximately) the content width. The tolerance absorbs
    // the right-margin inset that `contentSize.width` reserves (see the `fitToWidth` maxX computation).
    if frame.width >= layout.contentSize.width - 12.0 {
        return frame
    }
    return nil
}

// MARK: - Layout context

private final class DateUpdateAccumulator {
    var period: Int32?
}

private struct LayoutContext {
    /// Mutable because quoted content lays out under a scaled theme — see `quoteTheme`.
    var theme: InstantPageTheme
    /// Geometry constants for the CURRENT content scale. Swapped alongside `theme`.
    var metrics: InstantPageMetrics
    /// How far a full-bleed child may extend past its content column to reach THIS container's
    /// interior edges. Set and restored by each container, exactly like `theme` and `metrics` above.
    /// `layoutCodeBlock` is the only consumer today.
    var childBleed: InstantPageV2ChildBleed = .none
    /// The theme and metrics quoted content uses, computed ONCE for the page.
    ///
    /// Precomputed rather than derived on entry so that nesting is idempotent by construction: a
    /// quote inside a quote assigns the same values instead of compounding to 11.7pt at depth
    /// three. Deriving these from `context.theme` at each entry would compound, and would read as
    /// correct in a diff.
    let quoteTheme: InstantPageTheme
    let quoteMetrics: InstantPageMetrics
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let formatDate: (Int32, MessageTextEntityType.DateTimeFormat) -> String
    let userLocation: MediaResourceUserLocation
    let webpage: TelegramMediaWebpage
    let media: [EngineMedia.Id: EngineMedia]
    let cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight?
    let rtl: Bool
    let fitToWidth: Bool
    let computeRevealCharacterRects: Bool
    let pageHorizontalInset: CGFloat
    let edgeSpacingReduction: CGFloat

    var mediaIndexCounter: Int = 0
    var detailsIndexCounter: Int = 0

    let expandedDetails: [Int: Bool]
    /// Quotes the reader has expanded, keyed by structural block path. Mirrors `expandedDetails`, which
    /// is the same idea keyed by the details block's ordinal index.
    let expandedQuotePaths: Set<[Int]>
}

// MARK: - Driver

private func layoutBlockSequence(
    _ blocks: [InstantPageBlock],
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    pathPrefix: [Int] = [],
    context: inout LayoutContext
) -> InstantPageV2Layout {
    var items: [InstantPageV2LaidOutItem] = []
    var detailsIndices: [Int] = []
    var contentHeight: CGFloat = 0.0
    var previousBlock: InstantPageBlock?

    // A top-level block's container is the page itself, so a full-bleed child may give back exactly
    // the page inset on each side. Every OTHER sequence — a table cell, a table title, a details
    // body — is a band inside a container that has not opted in, and must therefore RESET the bleed
    // rather than inherit it: an inherited page-level bleed would send a code band punching out
    // through the container's own edge. Restored on exit so this never leaks upward either.
    let savedChildBleed = context.childBleed
    defer { context.childBleed = savedChildBleed }
    context.childBleed = kind == .topLevel
        ? InstantPageV2ChildBleed(minXSide: horizontalInset, maxXSide: horizontalInset)
        : .none

    // One pill per run of undecodable blocks, everywhere a sequence is laid out. Indices are
    // skipped rather than filtered out of `blocks`, so `i` below still addresses the original
    // block positions that `pathPrefix + [i]` turns into structural paths.
    let skippedBlockIndices = redundantUnsupportedBlockIndices(blocks)

    for (i, block) in blocks.enumerated() {
        if skippedBlockIndices.contains(i) {
            continue
        }
        var spacing = spacingBetweenBlocks(upper: previousBlock, lower: block, kind: kind, metrics: context.metrics)
        // Leading page edge: give back the inset the host applied around the whole page. Clamped at
        // 0 — a flush first block (cover, anchor) has no padding here to give.
        if previousBlock == nil && kind == .topLevel {
            spacing = max(0.0, spacing - context.edgeSpacingReduction)
        }
        let localItems = layoutBlock(
            block,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            kind: kind,
            isCover: false,
            previousItems: items,
            isLast: i == blocks.count - 1,
            pathPrefix: pathPrefix + [i],
            context: &context
        )

        // Translate local items by (0, contentHeight + spacing) and append.
        let dy = contentHeight + spacing
        var blockMaxY: CGFloat = 0.0
        for var item in localItems {
            item = item.offsetBy(CGPoint(x: 0.0, y: dy))
            if case let .details(d) = item {
                detailsIndices.append(d.index)
            }
            let f = item.frame
            if f.maxY > blockMaxY {
                blockMaxY = f.maxY
            }
            items.append(item)
        }

        if blockMaxY > contentHeight {
            contentHeight = blockMaxY
            previousBlock = block
        }
    }

    var closingSpacing = spacingBetweenBlocks(upper: previousBlock, lower: nil, kind: kind, metrics: context.metrics)
    // Trailing page edge — the mirror of the leading trim above.
    if kind == .topLevel {
        closingSpacing = max(0.0, closingSpacing - context.edgeSpacingReduction)
    }
    contentHeight += closingSpacing

    var contentSize = CGSize(width: boundingWidth, height: contentHeight)
    if context.fitToWidth {
        // Match V1 InstantPageLayout.swift:1114 — include `+ horizontalInset` so the contentSize
        // reserves a right margin equal to the left inset. Without this, the longest text item's
        // right edge equals contentSize.width, and the bubble's containerNode (sized to
        // boundingSize.width - 2) clips the last 2pt of text.
        //
        // A code band contributes its INNER content rather than its own frame: the band is as wide as
        // its container by construction, so its frame would clamp every page containing one to the
        // full bounding width. Its text is nested inside the item rather than sitting in `items`, so
        // dropping the band outright would drop the code text from the shrink too — and a message
        // whose widest content is its code would get a bubble narrower than the width that text was
        // laid out against, clipping it. See `instantPageV2FitWidthMaxX`.
        var maxX: CGFloat = 0.0
        for item in items {
            maxX = max(maxX, ceil(instantPageV2FitWidthMaxX(item)) + horizontalInset)
        }
        contentSize.width = min(maxX, boundingWidth)
        // Then re-widen the bands to the width that SURVIVED the shrink — the same reason
        // `centerBlockFormulas` below runs after `contentSize` rather than before it.
        instantPageV2StretchCodeBands(in: &items, contentWidth: contentSize.width)
    }

    centerBlockFormulas(in: &items, contentWidth: contentSize.width, horizontalInset: horizontalInset)

    return InstantPageV2Layout(contentSize: contentSize, items: items, detailsIndices: detailsIndices, media: context.media, webpage: context.webpage)
}

/// Horizontally centers every narrow block formula in a finished sequence (see
/// `InstantPageV2FormulaItem.centeringBounds`; items without one — inline runs and wide scrollable
/// formulas — are left where they are).
///
/// This runs after `contentSize` because the band a formula should center in is the band that
/// survives the `fitToWidth` shrink, not the one it was laid out against: a bubble whose widest
/// item is a short paragraph ends up much narrower than `boundingWidth`, and centering against the
/// latter would leave the formula hanging past the bubble's right edge. Clamping to
/// `contentWidth - horizontalInset` (the content area's true trailing edge — `contentSize.width`
/// reserves a right margin equal to the leading inset) also keeps a formula that *is* the widest
/// item exactly where it was, so a formula-only bubble still hugs it.
private func centerBlockFormulas(in items: inout [InstantPageV2LaidOutItem], contentWidth: CGFloat, horizontalInset: CGFloat) {
    for i in items.indices {
        guard case var .formula(item) = items[i], let bounds = item.centeringBounds else {
            continue
        }
        let trailingEdge = min(bounds.maxX, contentWidth - horizontalInset)
        let x = bounds.minX + max(0.0, (trailingEdge - bounds.minX - item.frame.width) / 2.0)
        item.frame.origin.x = x
        items[i] = .formula(item)
    }
}

// MARK: - Markdown block context stamping helpers

private func stampMarkdownContext(_ items: [InstantPageV2LaidOutItem], kind: InstantPageMarkdownBlockContext.Kind) {
    for item in items {
        switch item {
        case let .text(textItem):
            if textItem.textItem.markdownContext == nil {
                textItem.textItem.markdownContext = InstantPageMarkdownBlockContext(kind: kind)
            }
        case let .codeBlock(block):
            if block.textItem.markdownContext == nil {
                block.textItem.markdownContext = InstantPageMarkdownBlockContext(kind: kind)
            }
        default:
            break
        }
    }
}

/// Marks every text item produced by a blockquote's children as quoted (depth + 1),
/// preserving each child's own kind (heading/list/paragraph/…).
private func bumpQuoteDepth(_ items: [InstantPageV2LaidOutItem]) {
    for item in items {
        let target: InstantPageTextItem?
        switch item {
        case let .text(textItem): target = textItem.textItem
        case let .codeBlock(block): target = block.textItem
        default: target = nil
        }
        guard let target else { continue }
        if var ctx = target.markdownContext {
            ctx.quoteDepth += 1
            target.markdownContext = ctx
        } else {
            target.markdownContext = InstantPageMarkdownBlockContext(kind: .paragraph, quoteDepth: 1)
        }
    }
}

private func layoutBlock(
    _ block: InstantPageBlock,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    isCover: Bool,
    previousItems: [InstantPageV2LaidOutItem],
    isLast: Bool,
    pathPrefix: [Int] = [],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let _ = isLast  // reserved for Tasks 7–9
    switch block {
    case let .cover(inner):
        return layoutBlock(inner, boundingWidth: boundingWidth, horizontalInset: horizontalInset, kind: kind,
                           isCover: true, previousItems: previousItems, isLast: isLast, pathPrefix: pathPrefix, context: &context)
    case let .title(text):
        let titleItems = layoutSimpleText(text, category: .header, boundingWidth: boundingWidth,
                                          horizontalInset: horizontalInset, context: &context)
        stampMarkdownContext(titleItems, kind: .title)
        return titleItems
    case let .subtitle(text):
        return layoutSimpleText(text, category: .subheader, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, context: &context)
    case let .kicker(text):
        return layoutSimpleText(text, category: .kicker, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, context: &context)
    case let .header(text):
        return layoutSimpleText(text, category: .header, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, context: &context)
    case let .subheader(text):
        return layoutSimpleText(text, category: .subheader, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, context: &context)
    case let .heading(text, level):
        return layoutHeading(text, level: level, boundingWidth: boundingWidth,
                             horizontalInset: horizontalInset, context: &context)
    case let .footer(text):
        return layoutSimpleText(text, category: .caption, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, context: &context)
    case let .paragraph(text):
        return layoutParagraph(text, boundingWidth: boundingWidth, horizontalInset: horizontalInset, kind: kind,
                               previousItems: previousItems, context: &context)
    case let .authorDate(author, date):
        return layoutAuthorDate(author: author, date: date, boundingWidth: boundingWidth,
                                horizontalInset: horizontalInset, previousItems: previousItems, context: &context)
    case .divider:
        return layoutDivider(boundingWidth: boundingWidth, context: context)
    case let .anchor(name):
        return [.anchor(InstantPageV2AnchorItem(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0), name: name))]

    case let .list(items, ordered):
        return layoutList(items, ordered: ordered, boundingWidth: boundingWidth,
                          horizontalInset: horizontalInset, kind: kind, pathPrefix: pathPrefix, context: &context)

    case let .preformatted(text, language):
        return layoutCodeBlock(text, language: language, boundingWidth: boundingWidth,
                               horizontalInset: horizontalInset, context: &context)

    case let .blockQuote(blocks, caption, collapsed):
        // `collapsed` is optional on the model: nil means the wire form carried no flag, which is
        // "not collapsed".
        return layoutBlockQuote(blocks: blocks, caption: caption, authorCollapsed: collapsed == true,
                                boundingWidth: boundingWidth, horizontalInset: horizontalInset, kind: kind,
                                isLast: isLast, pathPrefix: pathPrefix, context: &context)
    case let .pullQuote(text, caption):
        return layoutQuoteText(text: text, caption: caption, isPull: true,
                               boundingWidth: boundingWidth, horizontalInset: horizontalInset,
                               context: &context)

    case let .image(id, caption, url, webpageId, spoiler):
        if case let .image(image) = context.media[id], let largest = largestImageRepresentation(image.representations) {
            let naturalSize = CGSize(width: CGFloat(largest.dimensions.width), height: CGFloat(largest.dimensions.height))
            let mediaUrl: InstantPageUrlItem? = url.flatMap { InstantPageUrlItem(url: $0, webpageId: webpageId) }
            let mediaIndex = context.mediaIndexCounter
            context.mediaIndexCounter += 1
            let instantPageMedia = InstantPageMedia(
                index: mediaIndex,
                media: .image(image),
                url: mediaUrl,
                caption: caption.text,
                credit: caption.credit
            )
            let webpage = context.webpage
            return layoutTypedMediaWithCaption(
                produceItem: { frame, cornerRadius in
                    .mediaImage(InstantPageV2MediaImageItem(
                        frame: frame,
                        cornerRadius: cornerRadius,
                        media: instantPageMedia,
                        webPage: webpage,
                        attributes: [],
                        spoiler: spoiler,
                        fit: true
                    ))
                },
                naturalSize: naturalSize,
                caption: caption,
                isCover: isCover,
                cornerRadius: 8.0,
                flush: true,
                boundingWidth: boundingWidth,
                horizontalInset: horizontalInset,
                capHeight: true,
                context: &context
            )
        } else {
            // Fallback when the image is not present in the page's media dict — preserve V1
            // behavior, which returns an empty layout for unknown image IDs (V1
            // InstantPageLayout.swift:623). The existing layoutMediaWithCaption would emit a
            // grey rectangle; matching V1 instead.
            return []
        }

    case let .video(id, caption, _, _, spoiler):
        if case let .file(file) = context.media[id], let dimensions = file.dimensions {
            let naturalSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
            let mediaIndex = context.mediaIndexCounter
            context.mediaIndexCounter += 1
            let instantPageMedia = InstantPageMedia(
                index: mediaIndex,
                media: .file(file),
                url: nil,
                caption: caption.text,
                credit: caption.credit
            )
            let webpage = context.webpage
            return layoutTypedMediaWithCaption(
                produceItem: { frame, cornerRadius in
                    .mediaVideo(InstantPageV2MediaVideoItem(
                        frame: frame,
                        cornerRadius: cornerRadius,
                        media: instantPageMedia,
                        webPage: webpage,
                        attributes: [],
                        spoiler: spoiler,
                        fit: true
                    ))
                },
                naturalSize: naturalSize,
                caption: caption,
                isCover: isCover,
                cornerRadius: 8.0,
                flush: true,
                boundingWidth: boundingWidth,
                horizontalInset: horizontalInset,
                capHeight: true,
                context: &context
            )
        } else {
            return []
        }

    case let .audio(audioId, caption):
        guard case let .file(file) = context.media[audioId] else {
            return []
        }
        let mediaIndex = context.mediaIndexCounter
        context.mediaIndexCounter += 1
        let instantPageMedia = InstantPageMedia(
            index: mediaIndex,
            media: .file(file),
            url: nil,
            caption: nil,
            credit: nil
        )
        let audioFrame = CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: 44.0)
        var result: [InstantPageV2LaidOutItem] = [.mediaAudio(InstantPageV2MediaAudioItem(
            frame: audioFrame,
            media: instantPageMedia,
            webPage: context.webpage
        ))]
        let (captionItems, _) = layoutCaptionAndCredit(
            caption,
            offset: audioFrame.height,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            context: &context
        )
        result.append(contentsOf: captionItems)
        return result

    case let .webEmbed(url, _, dimensions, caption, _, _, coverId):
        // V1 (InstantPageLayout.swift:848): if the embed has a URL and a resolvable cover image,
        // V1 synthesizes a fake webpage holding the cover image and renders it as an image cell
        // with a play overlay. Otherwise V1 produces a WKWebView embed (out of scope for V2).
        if let url = url,
           let coverId = coverId,
           case let .image(coverImage) = context.media[coverId] {
            let embedHeight: CGFloat = CGFloat(dimensions?.height ?? 240)
            let naturalSize = CGSize(width: boundingWidth, height: embedHeight)
            let size = PixelDimensions(width: Int32(naturalSize.width), height: Int32(naturalSize.height))
            let loadedContent = TelegramMediaWebpageLoadedContent(
                url: url,
                displayUrl: url,
                hash: 0,
                type: "video",
                websiteName: nil,
                title: nil,
                text: nil,
                embedUrl: url,
                embedType: "video",
                embedSize: size,
                duration: nil,
                author: nil,
                isMediaLargeByDefault: nil,
                imageIsVideoCover: false,
                image: coverImage,
                file: nil,
                story: nil,
                attributes: [],
                instantPage: nil
            )
            let coverWebpage = TelegramMediaWebpage(
                webpageId: EngineMedia.Id(namespace: Namespaces.Media.LocalWebpage, id: -1),
                content: .Loaded(loadedContent)
            )
            let mediaIndex = context.mediaIndexCounter
            context.mediaIndexCounter += 1
            let instantPageMedia = InstantPageMedia(
                index: mediaIndex,
                media: .webpage(coverWebpage),
                url: nil,
                caption: caption.text,
                credit: caption.credit
            )
            let webpage = context.webpage
            return layoutTypedMediaWithCaption(
                produceItem: { frame, cornerRadius in
                    .mediaCoverImage(InstantPageV2MediaCoverImageItem(
                        frame: frame,
                        cornerRadius: cornerRadius,
                        media: instantPageMedia,
                        webPage: webpage,
                        attributes: []
                    ))
                },
                naturalSize: naturalSize,
                caption: caption,
                isCover: false,
                cornerRadius: 0.0,
                flush: true,
                boundingWidth: boundingWidth,
                horizontalInset: horizontalInset,
                context: &context
            )
        } else {
            // No cover image → keep the existing grey-placeholder path (plain web embed).
            let h: CGFloat = CGFloat(dimensions?.height ?? 240)
            return layoutMediaWithCaption(kind: .webEmbed,
                naturalSize: CGSize(width: boundingWidth, height: h), caption: caption,
                isCover: false, cornerRadius: 0.0, flush: true, boundingWidth: boundingWidth,
                horizontalInset: horizontalInset, context: &context)
        }

    case let .postEmbed(_, _, _, _, _, _, caption):
        return layoutMediaWithCaption(kind: .postEmbed,
            naturalSize: CGSize(width: boundingWidth, height: 140.0), caption: caption,
            isCover: false, cornerRadius: 8.0, flush: true, boundingWidth: boundingWidth,
            horizontalInset: horizontalInset, context: &context)

    case let .collage(items, caption):
        // A collage carrying a block this build cannot decode is unsupported as a whole: the mosaic
        // reserves a slot for it and draws nothing there, so the tiles that DO resolve are laid out
        // around a hole. One pill replaces the entire block, caption included — the caption
        // describes content that is not being shown.
        if blockRendersAsUnsupported(block) {
            return layoutUnsupportedBlock(
                boundingWidth: boundingWidth,
                horizontalInset: horizontalInset,
                strings: UnsupportedContentPillStrings(strings: context.strings),
                colors: context.theme.unsupportedPillColors,
                isTopLevel: pathPrefix.count == 1
            )
        }
        return layoutCollage(items: items, caption: caption, isCover: isCover,
                             boundingWidth: boundingWidth, horizontalInset: horizontalInset, context: &context)

    case let .slideshow(items, caption):
        return layoutSlideshow(items: items, caption: caption,
                               boundingWidth: boundingWidth, horizontalInset: horizontalInset, context: &context)

    case let .channelBanner(channel):
        if channel == nil { return [] }
        return layoutMediaWithCaption(kind: .channelBanner,
            naturalSize: CGSize(width: boundingWidth, height: 60.0),
            caption: InstantPageCaption(text: .empty, credit: .empty),
            isCover: false, cornerRadius: 0.0, flush: true, boundingWidth: boundingWidth,
            horizontalInset: horizontalInset, context: &context)

    case let .map(latitude, longitude, zoom, dimensions, caption):
        // AI/server-sent `.map` blocks can arrive with zero `dimensions` (the wire `w`/`h` are
        // required, but the sender may put 0). A zero `naturalSize.height` collapses the media
        // frame to height 0 (`instantPageV2MediaFrame`'s else branch) — the map takes no space,
        // the caption slides up into it, and the pin floats over the caption — and a zero-sized
        // `MapSnapshotMediaResource` makes `MKMapSnapshotter` render nothing. Substitute a sensible
        // default (a 2:1 map strip) for BOTH the layout size and the snapshot resource. Real web
        // articles (the V1 renderer) always carry real dimensions, so only the rich-message path
        // hits this; the fallback is scoped here rather than in V1 or the wire/parse layer.
        let effectiveDimensions: PixelDimensions
        if dimensions.width > 0 && dimensions.height > 0 {
            effectiveDimensions = dimensions
        } else {
            effectiveDimensions = PixelDimensions(width: 600, height: 300)
        }
        let naturalSize = CGSize(width: CGFloat(effectiveDimensions.width), height: CGFloat(effectiveDimensions.height))
        let map = TelegramMediaMap(
            latitude: latitude,
            longitude: longitude,
            heading: nil,
            accuracyRadius: nil,
            venue: nil,
            liveBroadcastingTimeout: nil,
            liveProximityNotificationRadius: nil
        )
        let mapAttributes: [InstantPageImageAttribute] = [InstantPageMapAttribute(zoom: zoom, dimensions: effectiveDimensions.cgSize)]
        let mediaIndex = context.mediaIndexCounter
        context.mediaIndexCounter += 1
        let instantPageMedia = InstantPageMedia(
            index: mediaIndex,
            media: .geo(map),
            url: nil,
            caption: caption.text,
            credit: caption.credit
        )
        let webpage = context.webpage
        return layoutTypedMediaWithCaption(
            produceItem: { frame, cornerRadius in
                .mediaMap(InstantPageV2MediaMapItem(
                    frame: frame,
                    cornerRadius: cornerRadius,
                    media: instantPageMedia,
                    webPage: webpage,
                    attributes: mapAttributes
                ))
            },
            naturalSize: naturalSize,
            caption: caption,
            isCover: false,
            cornerRadius: 8.0,
            flush: true,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            context: &context
        )

    case let .relatedArticles(_, articles):
        let h = min(CGFloat(articles.count) * 80.0, 320.0)
        return layoutMediaWithCaption(kind: .relatedArticles,
            naturalSize: CGSize(width: boundingWidth, height: max(h, 80.0)),
            caption: InstantPageCaption(text: .empty, credit: .empty),
            isCover: false, cornerRadius: 0.0, flush: true, boundingWidth: boundingWidth,
            horizontalInset: horizontalInset, context: &context)

    case let .formula(latex):
        return layoutFormulaBlock(latex: latex,
                                  boundingWidth: boundingWidth,
                                  horizontalInset: horizontalInset, kind: kind,
                                  context: &context)

    case let .details(title, blocks, expanded):
        return layoutDetails(title: title, blocks: blocks, defaultExpanded: expanded,
                             boundingWidth: boundingWidth, horizontalInset: horizontalInset,
                             pathPrefix: pathPrefix, context: &context)

    case let .table(title, rows, bordered, striped, compact):
        return layoutTable(title: title, rows: rows, bordered: bordered, striped: striped, compact: compact,
                           boundingWidth: boundingWidth, horizontalInset: horizontalInset,
                           context: &context)

    case let .thinking(text):
        return layoutThinking(text, boundingWidth: boundingWidth,
                              horizontalInset: horizontalInset, context: &context)
    case let .buttonRow(alignment, buttons):
        let labelledButtons = buttons.map { button -> (button: InstantPageButton, labelString: NSAttributedString) in
            // Measured with the paragraph style stack, exactly as layoutSimpleText builds one, so a
            // row pill's typography matches an inline pill's. Block buttons are a point larger than
            // inline ones; both semibold.
            let labelStyleStack = InstantPageTextStyleStack()
            setupStyleStack(labelStyleStack, theme: context.theme, category: .paragraph, link: false)
            labelStyleStack.push(.fontSize(instantPageBlockButtonFontSize))
            labelStyleStack.push(.semibold)
            return (button, attributedStringForRichText(button.text, styleStack: labelStyleStack, formatDate: context.formatDate))
        }
        let (entries, totalHeight) = instantPageV2LayoutButtonRow(
            labelledButtons: labelledButtons,
            alignment: alignment,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            rtl: context.rtl,
            metrics: context.metrics
        )
        if entries.isEmpty {
            return []
        }
        return [.buttonRow(InstantPageV2ButtonRowItem(
            frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: totalHeight),
            buttons: entries
        ))]
    case let .document(documentId, caption):
        guard case let .file(file) = context.media[documentId] else {
            return []
        }
        let mediaIndex = context.mediaIndexCounter
        context.mediaIndexCounter += 1
        let instantPageMedia = InstantPageMedia(
            index: mediaIndex,
            media: .file(file),
            url: nil,
            caption: nil,
            credit: nil
        )
        // Flush at full boundingWidth like .audio; 52pt rather than audio's 44 to fit the file row.
        let documentFrame = CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: 52.0)
        var result: [InstantPageV2LaidOutItem] = [.document(InstantPageV2DocumentItem(
            frame: documentFrame,
            media: instantPageMedia,
            webPage: context.webpage
        ))]
        let (captionItems, _) = layoutCaptionAndCredit(
            caption,
            offset: documentFrame.height,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            context: &context
        )
        result.append(contentsOf: captionItems)
        return result
    case .unsupported:
        return layoutUnsupportedBlock(
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            strings: UnsupportedContentPillStrings(strings: context.strings),
            colors: context.theme.unsupportedPillColors,
            // Depth, not `kind`: the top-level sequence starts from an empty prefix and every
            // nesting step appends, so a direct child of the page — and only that — has a
            // one-element path. `kind` cannot tell, because a blockquote lays its children out with
            // the ENCLOSING sequence's kind.
            isTopLevel: pathPrefix.count == 1
        )
    }
}

// MARK: - Formula block layout

/// Lays out a top-level `InstantPageBlock.formula(latex:)`. The latex is rendered synchronously
/// through `instantPageMathAttachment(...)` (SwiftMath → `MTMathRenderer`) using the current
/// paragraph theme's color and font size; the resulting pre-rendered `UIImage` is wrapped in
/// an `InstantPageV2FormulaItem`. Wide formulas set `isScrollable = true`; on render failure
/// the raw latex source is laid out as a regular paragraph (matches V1 fallback).
private func layoutFormulaBlock(
    latex: String,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Style stack matches V1's per-block formula (paragraph category, not header).
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: .paragraph, link: false)
    let attributes = styleStack.textAttributes()
    let textColor = (attributes[.foregroundColor] as? UIColor)
                    ?? context.theme.textCategories.paragraph.color
    let fontSize = (attributes[.font] as? UIFont)?.pointSize
                    ?? context.theme.textCategories.paragraph.font.size

    guard let attachment = instantPageMathAttachment(latex: latex,
                                                     fontSize: fontSize,
                                                     textColor: textColor,
                                                     mode: .block) else {
        // Render failure: fall back to the raw latex source as a regular paragraph.
        return layoutParagraph(.plain(latex),
                               boundingWidth: boundingWidth,
                               horizontalInset: horizontalInset,
                               kind: kind,
                               previousItems: [],
                               context: &context)
    }

    let availableWidth = boundingWidth - horizontalInset * 2.0
    let renderedSize = attachment.rendered.size

    if renderedSize.width > availableWidth {
        // Wide formula: scroll view fills the bubble's available width so the image can pan inside.
        let frame = CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: renderedSize.height)
        let item = InstantPageV2FormulaItem(
            frame: frame,
            attachment: attachment,
            isScrollable: true,
            imageFrame: CGRect(x: horizontalInset, y: 0.0,
                               width: renderedSize.width, height: renderedSize.height),
            scrollContentSize: CGSize(width: renderedSize.width + horizontalInset * 2.0,
                                      height: renderedSize.height)
        )
        return [.formula(item)]
    } else {
        // Narrow formula: report the image's natural extent (left-inset + width) so the
        // bubble's `fitToWidth` contentSize shrinks instead of stretching to `boundingWidth`.
        // When the formula is the widest item, the bubble centers itself in the chat row.
        //
        // The frame stays at the leading inset here and is centered later, by the post-pass in
        // `layoutBlockSequence` — see `centeringBounds`. Widening the frame to the whole band
        // instead (image centered inside via `imageFrame`) would report `maxX == boundingWidth`
        // and defeat the hug above, stretching every formula-bearing bubble to full width.
        let frame = CGRect(x: horizontalInset, y: 0.0,
                           width: renderedSize.width, height: renderedSize.height)
        let item = InstantPageV2FormulaItem(
            frame: frame,
            attachment: attachment,
            isScrollable: false,
            imageFrame: CGRect(origin: .zero, size: renderedSize),
            scrollContentSize: renderedSize,
            centeringBounds: CGRect(x: horizontalInset, y: 0.0,
                                    width: availableWidth, height: renderedSize.height)
        )
        return [.formula(item)]
    }
}

// MARK: - Details layout

private func layoutDetails(
    title: RichText,
    blocks: [InstantPageBlock],
    defaultExpanded: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    pathPrefix: [Int] = [],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let index = context.detailsIndexCounter
    context.detailsIndexCounter += 1

    // Title text item at top.
    // V1 (InstantPageDetailsItem.swift:98–101): boundingWidth - detailsInset*2 - titleInset, titleHeight = max(44, titleSize.height + 26).
    let titleStyleStack = InstantPageTextStyleStack()
    setupStyleStack(titleStyleStack, theme: context.theme, category: .paragraph, link: false)
    // The header reads as a control, not body copy — semibold as a BASELINE weight, so an explicit
    // `.bold` inside the title still wins over it.
    titleStyleStack.push(.semibold)
    let titleString = attributedStringForRichText(title, styleStack: titleStyleStack, formatDate: context.formatDate)
    let (measuredTitleTextItem, _, _) = layoutTextItem(
        titleString,
        boundingWidth: boundingWidth - horizontalInset * 2.0 - context.metrics.detailsChevronReserve,   // reserve right edge for chevron
        offset: CGPoint(x: 0.0, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    // A toggle block may legitimately carry NO title: other clients send `pageBlockDetails` with
    // `textEmpty`, and `layoutTextItem` returns nil for a zero-length string. Bailing out here
    // dropped the WHOLE block — header, chevron and every child alike. Substitute an empty text
    // item instead: it has no lines, so it draws nothing, costs nothing in the reveal map and is
    // skipped by selection, while `titleHeight` falls back to `detailsMinTitleHeight`, which is
    // also the header's tap target and the chevron's vertical centre. V1 `layoutDetailsItem` has
    // always behaved this way — it discards the optional item and keeps its own minimum height.
    let titleTextItem = measuredTitleTextItem ?? InstantPageTextItem(
        frame: CGRect(),
        attributedString: titleString,
        alignment: .natural,
        opaqueBackground: false,
        lines: []
    )
    
    let titleHeight = max(context.metrics.detailsMinTitleHeight, titleTextItem.frame.height + context.metrics.detailsTitleVerticalPad)
    titleTextItem.frame.origin.x = context.rtl
        ? (boundingWidth - horizontalInset - context.metrics.detailsTitleHorizontalInset - titleTextItem.frame.width)
        : (horizontalInset + context.metrics.detailsTitleHorizontalInset)
    titleTextItem.frame.origin.y = floorToScreenPixels((titleHeight - titleTextItem.frame.height) * 0.5)

    let isExpanded = context.expandedDetails[index] ?? defaultExpanded

    // V1 uses max(44.0, titleSize.height + 26.0); matched here.
    let titleFrame = CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: titleHeight)

    var innerLayout: InstantPageV2Layout?
    var totalHeight = titleHeight
    if isExpanded {
        let layout = layoutBlockSequence(
            blocks,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            kind: .detail,
            pathPrefix: pathPrefix,
            context: &context
        )
        innerLayout = layout
        totalHeight += layout.contentSize.height
    }

    let item = InstantPageV2DetailsItem(
        frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: totalHeight),
        index: index,
        sideInset: horizontalInset,
        titleTextItem: titleTextItem,
        titleFrame: titleFrame,
        separatorColor: context.theme.separatorColor,
        isExpanded: isExpanded,
        innerLayout: innerLayout,
        defaultExpanded: defaultExpanded,
        rtl: context.rtl
    )
    return [.details(item)]
}

// MARK: - Table layout

private struct V2TableRow {
    var minColumnWidths: [Int: CGFloat]
    var maxColumnWidths: [Int: CGFloat]
}

let v2TableCellInsets: UIEdgeInsets = {
    return UIEdgeInsets(top: 7.0, left: 13.0, bottom: 7.0, right: 13.0)
}()
let v2TableBorderWidth: CGFloat = {
    return UIScreenPixel * 2.0
}()
let v2TableCornerRadius: CGFloat = 10.0
// Absolute floor for a column in the compress-to-fit second pass. 26pt of this is cell
// padding (v2TableCellInsets.left + .right), leaving ~34pt of text. Below this a column
// is too narrow to read, so the table scrolls horizontally instead.
let v2TableMinCompressedColumnWidth: CGFloat = 60.0

/// Second-pass column solver for a table whose columns' minimum (maximally-wrapped)
/// widths overflow `target`. Compresses columns proportionally to their natural
/// (`maxColumnWidths`) widths, clamping any column that would fall below `floor`
/// (a column narrower than the floor keeps its natural width) and redistributing the
/// remaining shrink among the still-scalable columns (water-filling).
///
/// Returns the per-column widths plus whether they fit within `target`:
/// - `fits == true`: the widths sum exactly to `target` (caller shows a non-scrolling table).
/// - `fits == false`: even at their floors the columns overflow, so the widths are the
///   fully-compressed (floored) shape; the caller still scrolls, but at this much narrower
///   width rather than the full natural widths.
/// Returns `nil` only for a degenerate table with no columns.
private func compressTableColumnsToFit(
    maxColumnWidths: [Int: CGFloat],
    columnCount: Int,
    target: CGFloat,
    floor: CGFloat
) -> (widths: [Int: CGFloat], fits: Bool)? {
    if columnCount <= 0 {
        return nil
    }

    // Effective floor per column: never pad a naturally-narrow column up to the floor.
    var effectiveFloor: [Int: CGFloat] = [:]
    var flooredTotal: CGFloat = 0.0
    for i in 0 ..< columnCount {
        let natural = maxColumnWidths[i] ?? 1.0
        let f = min(floor, natural)
        effectiveFloor[i] = f
        flooredTotal += f
    }

    // Infeasible: even at their floors the columns overflow. Keep the fully-compressed
    // (floored) shape — it still scrolls, but far less than the natural widths would.
    if flooredTotal > target {
        return (effectiveFloor, false)
    }

    // Water-filling: scale unpinned columns proportionally to natural width, pinning any
    // that would drop below their floor, until the pinned set is stable.
    var pinned = Set<Int>()
    while true {
        var fixedWidth: CGFloat = 0.0
        var scalableNatural: CGFloat = 0.0
        for i in 0 ..< columnCount {
            if pinned.contains(i) {
                fixedWidth += effectiveFloor[i] ?? floor
            } else {
                scalableNatural += maxColumnWidths[i] ?? 1.0
            }
        }
        if scalableNatural <= 0.0 {
            break
        }
        let scale = (target - fixedWidth) / scalableNatural
        var newlyPinned = Set<Int>()
        for i in 0 ..< columnCount where !pinned.contains(i) {
            let natural = maxColumnWidths[i] ?? 1.0
            if natural * scale < (effectiveFloor[i] ?? floor) {
                newlyPinned.insert(i)
            }
        }
        if newlyPinned.isEmpty {
            break
        }
        pinned.formUnion(newlyPinned)
    }

    // Final assignment using the stable pinned set.
    var fixedWidth: CGFloat = 0.0
    var scalableNatural: CGFloat = 0.0
    for i in 0 ..< columnCount {
        if pinned.contains(i) {
            fixedWidth += effectiveFloor[i] ?? floor
        } else {
            scalableNatural += maxColumnWidths[i] ?? 1.0
        }
    }
    let scale = scalableNatural > 0.0 ? (target - fixedWidth) / scalableNatural : 0.0

    var result: [Int: CGFloat] = [:]
    var assigned: CGFloat = 0.0
    var lastScalableIndex: Int? = nil
    for i in 0 ..< columnCount {
        let width: CGFloat
        if pinned.contains(i) {
            width = effectiveFloor[i] ?? floor
        } else {
            width = round((maxColumnWidths[i] ?? 1.0) * scale)
            lastScalableIndex = i
        }
        result[i] = width
        assigned += width
    }

    // Correct sub-pixel rounding drift so the widths sum to exactly `target`. Dump it on
    // the last scalable column (well above its floor) so no pinned column is pushed below
    // the floor; fall back to the last column if every column was pinned.
    let drift = target - assigned
    let driftIndex = lastScalableIndex ?? (columnCount - 1)
    if drift != 0.0, let current = result[driftIndex] {
        result[driftIndex] = current + drift
    }

    return (result, true)
}

private func layoutTable(
    title: RichText,
    rows: [InstantPageTableRow],
    bordered: Bool,
    striped: Bool,
    compact: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Bound once, before the `finalizeCell` closure below: `context` is `inout` and cannot be
    // captured, and these are the only two table constants that scale with the content.
    let cellInsets = compact ? context.metrics.tableCompactCellInsets : context.metrics.tableCellInsets
    let minCompressedColumnWidth = context.metrics.tableMinCompressedColumnWidth

    if rows.isEmpty {
        return []
    }

    // Style stack shared across all cell text measurements.
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: .table, link: false)

    let borderWidth = bordered ? v2TableBorderWidth : 0.0
    // Size columns against the inset content width (mirrors V1's `boundingWidth - horizontalInset*2`),
    // so a fitting table aligns with body text on both sides. The item frame stays full-width (flush)
    // and the renderer bakes the inset back in as a left margin on the scroll content.
    let contentBoundingWidth = boundingWidth - horizontalInset * 2.0
    let totalCellPadding = cellInsets.left + cellInsets.right
    let cellWidthLimit = contentBoundingWidth - totalCellPadding

    var tableRows: [V2TableRow] = []
    var columnCount: Int = 0

    var columnSpans: [Range<Int>: (CGFloat, CGFloat)] = [:]
    var rowSpans: [Int: [(Int, Int)]] = [:]

    // Pass 1: measure min/max intrinsic width per cell.
    var r: Int = 0
    for row in rows {
        var minColumnWidths: [Int: CGFloat] = [:]
        var maxColumnWidths: [Int: CGFloat] = [:]
        var i: Int = 0

        for cell in row.cells {
            // Advance i past any rowspan-inherited columns (matches V1 lines 311–319).
            if let rowSpan = rowSpans[r] {
                for columnAndSpan in rowSpan {
                    if columnAndSpan.0 == i {
                        i += columnAndSpan.1
                    } else {
                        break
                    }
                }
            }

            var minCellWidth: CGFloat = 1.0
            var maxCellWidth: CGFloat = 1.0
            if let text = cell.text {
                // Mirror V1 (`InstantPageTableItem.layoutTableItem`): `attributedStringForRichText`'s
                // boundingWidth sizes inline attachments to `cellWidthLimit - totalCellPadding`, while
                // the line-break budget passed to `layoutTextItem` is the full `cellWidthLimit`. (V1
                // subtracts `totalCellPadding` only on the attribute-string arg, not the layout arg.)
                let attrStr = attributedStringForRichText(text, styleStack: styleStack, boundingWidth: cellWidthLimit - totalCellPadding, formatDate: context.formatDate)
                if let shortestItem = layoutTextItem(
                    attrStr,
                    boundingWidth: cellWidthLimit,
                    offset: CGPoint(),
                    minimizeWidth: true,
                    fitToWidth: context.fitToWidth,
                    computeRevealCharacterRects: context.computeRevealCharacterRects
                ).0 {
                    minCellWidth = shortestItem.effectiveWidth() + totalCellPadding
                }
                if let longestItem = layoutTextItem(
                    attrStr,
                    boundingWidth: cellWidthLimit,
                    offset: CGPoint(),
                    fitToWidth: context.fitToWidth,
                    computeRevealCharacterRects: context.computeRevealCharacterRects
                ).0 {
                    maxCellWidth = max(minCellWidth, longestItem.effectiveWidth() + totalCellPadding)
                }
            }

            if cell.colspan > 1 {
                minColumnWidths[i] = 1.0
                maxColumnWidths[i] = 1.0
                let spanRange = i ..< i + Int(cell.colspan)
                if let (minSW, maxSW) = columnSpans[spanRange] {
                    columnSpans[spanRange] = (max(minSW, minCellWidth), max(maxSW, maxCellWidth))
                } else {
                    columnSpans[spanRange] = (minCellWidth, maxCellWidth)
                }
            } else {
                minColumnWidths[i] = minCellWidth
                maxColumnWidths[i] = maxCellWidth
            }

            let colspan = cell.colspan > 1 ? Int(clamping: cell.colspan) : 1
            if cell.rowspan > 1 {
                for j in r ..< r + Int(cell.rowspan) {
                    if rowSpans[j] == nil {
                        rowSpans[j] = [(i, colspan)]
                    } else {
                        rowSpans[j]!.append((i, colspan))
                    }
                }
            }

            i += colspan
        }
        tableRows.append(V2TableRow(minColumnWidths: minColumnWidths, maxColumnWidths: maxColumnWidths))
        columnCount = max(columnCount, i)
        r += 1
    }

    // Aggregate column min/max across all rows.
    let maxContentWidth = contentBoundingWidth - borderWidth
    var availableWidth = maxContentWidth
    var minColumnWidths: [Int: CGFloat] = [:]
    var maxColumnWidths: [Int: CGFloat] = [:]
    var maxTotalWidth: CGFloat = 0.0
    for i in 0 ..< columnCount {
        var minWidth: CGFloat = 1.0
        var maxWidth: CGFloat = 1.0
        for row in tableRows {
            if let w = row.minColumnWidths[i] { minWidth = max(minWidth, w) }
            if let w = row.maxColumnWidths[i] { maxWidth = max(maxWidth, w) }
        }
        minColumnWidths[i] = minWidth
        maxColumnWidths[i] = maxWidth
        availableWidth -= minWidth
        maxTotalWidth += maxWidth
    }

    // Apply colspan constraints.
    for (range, span) in columnSpans {
        let (minSpanWidth, maxSpanWidth) = span
        var minWidth: CGFloat = 0.0
        var maxWidth: CGFloat = 0.0
        for i in range {
            if let w = minColumnWidths[i] { minWidth += w }
            if let w = maxColumnWidths[i] { maxWidth += w }
        }
        if minWidth < minSpanWidth {
            let delta = minSpanWidth - minWidth
            for i in range {
                if let w = minColumnWidths[i] {
                    let growth = floor(delta / CGFloat(range.count))
                    minColumnWidths[i] = w + growth
                    availableWidth -= growth
                }
            }
        }
        if maxWidth < maxSpanWidth {
            let delta = maxSpanWidth - maxWidth
            for i in range {
                if let w = maxColumnWidths[i] {
                    let growth = round(delta / CGFloat(range.count))
                    maxColumnWidths[i] = w + growth
                    maxTotalWidth += growth
                }
            }
        }
    }

    // Width allocation: choose per-column widths and the resulting grid width.
    var totalWidth: CGFloat
    var finalColumnWidths: [Int: CGFloat]
    if availableWidth > 0 {
        // Case A: the columns' minimum widths fit; grow them from min toward their
        // natural width (proportional to maxWidth) to fill the available width.
        finalColumnWidths = minColumnWidths
        var distributedWidth = availableWidth
        for i in 0 ..< finalColumnWidths.count {
            var width = finalColumnWidths[i]!
            let maxWidth = maxColumnWidths[i]!
            let growth = min(round(availableWidth * maxWidth / maxTotalWidth), distributedWidth)
            width += growth
            distributedWidth -= growth
            finalColumnWidths[i] = width
        }
        totalWidth = contentBoundingWidth
    } else if let compressed = compressTableColumnsToFit(
        maxColumnWidths: maxColumnWidths,
        columnCount: columnCount,
        target: maxContentWidth,
        floor: minCompressedColumnWidth
    ) {
        // Case B, second pass: the minimum (maximally-wrapped) widths overflow, so compress
        // columns proportionally down to the floor.
        finalColumnWidths = compressed.widths
        if compressed.fits {
            // Fits after compression → fill the content width, no horizontal scroll.
            totalWidth = contentBoundingWidth
        } else {
            // Even at the floor the columns overflow: still scroll, but at the compressed
            // (floored) width — far narrower than the natural widths.
            var compressedTotal: CGFloat = 0.0
            for i in 0 ..< columnCount {
                compressedTotal += compressed.widths[i] ?? 0.0
            }
            totalWidth = compressedTotal + borderWidth
        }
    } else {
        // Degenerate table with no columns: keep natural widths (unchanged behavior).
        finalColumnWidths = maxColumnWidths
        totalWidth = maxTotalWidth + borderWidth
    }

    // Pass 2 & 3: produce per-cell frames + sub-layouts.
    // Private struct to hold an in-progress cell before row height is known.
    struct PendingCell {
        let rowIndex: Int
        let column: Int
        let colspan: Int
        let rowspan: Int
        let cell: InstantPageTableCell
        var frame: CGRect          // height is tentative until row height resolved
        let isHeader: Bool
        let isFilled: Bool         // background fill (header or stripe)
        let subLayout: InstantPageV2Layout?
        let subLayoutContentHeight: CGFloat  // height of cell content (before padding)
    }

    var finalizedCells: [InstantPageV2TableCell] = []
    var origin = CGPoint(x: borderWidth / 2.0, y: borderWidth / 2.0)
    var totalHeight: CGFloat = 0.0
    var rowHeights: [Int: CGFloat] = [:]

    var awaitingSpanCells: [Int: [(Int, PendingCell)]] = [:]

    for i in 0 ..< rows.count {
        let row = rows[i]
        var maxRowHeight: CGFloat = 0.0
        var isEmptyRow = true
        origin.x = borderWidth / 2.0

        var k: Int = 0
        var rowCells: [PendingCell] = []

        for cell in row.cells {
            // Skip columns occupied by row spans.
            if let cells = awaitingSpanCells[i] {
                for colAndCell in cells {
                    if colAndCell.1.column == k {
                        for j in 0 ..< colAndCell.1.colspan {
                            if let width = finalColumnWidths[k + j] {
                                origin.x += width
                            }
                        }
                        k += colAndCell.1.colspan
                    } else {
                        break
                    }
                }
            }

            let colspan: Int = cell.colspan > 1 ? Int(clamping: cell.colspan) : 1
            let rowspan: Int = cell.rowspan > 1 ? Int(clamping: cell.rowspan) : 1

            var cellWidth: CGFloat = 0.0
            for j in 0 ..< colspan {
                if let width = finalColumnWidths[k + j] {
                    cellWidth += width
                }
            }

            // Build cell sub-layout via recursive layoutBlockSequence.
            var subLayout: InstantPageV2Layout?
            var subLayoutHeight: CGFloat = 0.0
            if let cellText = cell.text {
                let cellContentWidth = cellWidth - totalCellPadding
                if cellContentWidth > 0.0 {
                    let cellLayout = layoutBlockSequence(
                        [.paragraph(cellText)],
                        boundingWidth: cellContentWidth,
                        horizontalInset: 0.0,
                        kind: .cell,
                        context: &context
                    )
                    stampMarkdownContext(cellLayout.items, kind: .tableCell(row: i, column: k, isHeader: cell.header))
                    subLayout = cellLayout
                    subLayoutHeight = cellLayout.contentSize.height
                    isEmptyRow = false
                }
            }

            var cellHeight: CGFloat?
            if subLayout != nil {
                cellHeight = ceil(subLayoutHeight) + cellInsets.top + cellInsets.bottom
            }

            var isFilled = cell.header
            if !isFilled && striped {
                isFilled = i % 2 == 0
            }

            let pendingCell = PendingCell(
                rowIndex: i,
                column: k,
                colspan: colspan,
                rowspan: rowspan,
                cell: cell,
                frame: CGRect(x: origin.x, y: origin.y, width: cellWidth, height: cellHeight ?? 20.0),
                isHeader: cell.header,
                isFilled: isFilled,
                subLayout: subLayout,
                subLayoutContentHeight: subLayoutHeight
            )

            if rowspan == 1 {
                rowCells.append(pendingCell)
                if let ch = cellHeight {
                    maxRowHeight = max(maxRowHeight, ch)
                }
            } else {
                for j in i ..< i + rowspan {
                    if awaitingSpanCells[j] == nil {
                        awaitingSpanCells[j] = [(k, pendingCell)]
                    } else {
                        awaitingSpanCells[j]!.append((k, pendingCell))
                    }
                }
            }

            k += colspan
            origin.x += cellWidth
        }

        // Capture theme color value before the closure to avoid capturing `inout context`.
        let tableHeaderColor = context.theme.tableHeaderColor

        // Helper: finalize a pending cell with known row height → produce InstantPageV2TableCell.
        let finalizeCell: (PendingCell, CGFloat) -> InstantPageV2TableCell = { pending, height in
            let finalFrame = CGRect(x: pending.frame.minX, y: pending.frame.minY,
                                    width: pending.frame.width, height: height)

            // Compute sub-layout frame within the cell (horizontal inset + vertical alignment).
            var subLayout = pending.subLayout
            if var sl = subLayout {
                let textHeight = pending.subLayoutContentHeight
                let vertOffset: CGFloat
                switch pending.cell.verticalAlignment {
                case .top:
                    vertOffset = cellInsets.top
                case .middle:
                    vertOffset = max(cellInsets.top, (height - textHeight) / 2.0)
                case .bottom:
                    vertOffset = max(cellInsets.top, height - textHeight - cellInsets.bottom)
                }
                let horizOffset: CGFloat
                switch pending.cell.alignment {
                case .left:
                    horizOffset = cellInsets.left
                case .center:
                    horizOffset = (pending.frame.width - sl.contentSize.width) / 2.0
                case .right:
                    horizOffset = pending.frame.width - sl.contentSize.width - cellInsets.right
                }
                // Translate all items in the sub-layout by the inset.
                let delta = CGPoint(x: horizOffset, y: vertOffset)
                let translatedItems = sl.items.map { $0.offsetBy(delta) }
                sl = InstantPageV2Layout(contentSize: sl.contentSize, items: translatedItems, detailsIndices: sl.detailsIndices, media: sl.media, webpage: sl.webpage)
                subLayout = sl
            }

            let bgColor: UIColor? = pending.isFilled ? tableHeaderColor : nil
            let hAlign: NSTextAlignment
            switch pending.cell.alignment {
            case .left: hAlign = .left
            case .center: hAlign = .center
            case .right: hAlign = .right
            }
            let vAlign: InstantPageV2TableVerticalAlignment
            switch pending.cell.verticalAlignment {
            case .top: vAlign = .top
            case .middle: vAlign = .middle
            case .bottom: vAlign = .bottom
            }

            return InstantPageV2TableCell(
                frame: finalFrame,
                isHeader: pending.isHeader,
                horizontalAlignment: hAlign,
                verticalAlignment: vAlign,
                backgroundColor: bgColor,
                subLayout: subLayout
            )
        }

        if !isEmptyRow {
            rowHeights[i] = maxRowHeight
        } else {
            rowHeights[i] = 0.0
            maxRowHeight = 0.0
        }

        // Resolve any row-spanning cells whose bottom row is now known.
        var completedSpans = [Int: Set<Int>]()
        if let cells = awaitingSpanCells[i] {
            isEmptyRow = false
            for colAndCell in cells {
                let pending = colAndCell.1
                let utmostRow = pending.rowIndex + pending.rowspan - 1
                if rowHeights[utmostRow] == nil {
                    continue
                }

                var cellHeight: CGFloat = 0.0
                for k in pending.rowIndex ..< utmostRow + 1 {
                    if let h = rowHeights[k] { cellHeight += h }
                    if completedSpans[k] == nil {
                        completedSpans[k] = Set([colAndCell.0])
                    } else {
                        completedSpans[k]!.insert(colAndCell.0)
                    }
                }

                if pending.frame.height > cellHeight {
                    let delta = pending.frame.height - cellHeight
                    cellHeight = pending.frame.height
                    maxRowHeight += delta
                    rowHeights[i] = maxRowHeight
                }

                finalizedCells.append(finalizeCell(pending, cellHeight))
            }
        }

        for pending in rowCells {
            finalizedCells.append(finalizeCell(pending, maxRowHeight))
        }

        // Remove completed span cells from awaitingSpanCells.
        if !completedSpans.isEmpty {
            awaitingSpanCells = awaitingSpanCells.reduce([Int: [(Int, PendingCell)]]()) { current, rowAndValue in
                var result = current
                let cells = rowAndValue.value.filter { column, _ in
                    if let completedSet = completedSpans[rowAndValue.key] {
                        return !completedSet.contains(column)
                    }
                    return true
                }
                if !cells.isEmpty { result[rowAndValue.key] = cells }
                return result
            }
        }

        if !isEmptyRow {
            totalHeight += maxRowHeight
            origin.y += maxRowHeight
        }
    }
    totalHeight += borderWidth

    // RTL: flip all cell frames horizontally within totalWidth.
    if context.rtl {
        finalizedCells = finalizedCells.map { cell in
            let flippedX = totalWidth - cell.frame.minX - cell.frame.width
            let flippedFrame = CGRect(x: flippedX, y: cell.frame.minY,
                                      width: cell.frame.width, height: cell.frame.height)
            return InstantPageV2TableCell(
                frame: flippedFrame,
                isHeader: cell.isHeader,
                horizontalAlignment: cell.horizontalAlignment,
                verticalAlignment: cell.verticalAlignment,
                backgroundColor: cell.backgroundColor,
                subLayout: cell.subLayout
            )
        }
    }

    // Build border lines (table-local coords).
    var horizontalLines: [CGRect] = []
    var verticalLines: [CGRect] = []
    if bordered {
        // Interior lines: for each cell, emit a top line if not in the first row,
        // and a left line if not in the first column.
        for cell in finalizedCells {
            let isFirstRow = cell.frame.minY <= borderWidth / 2.0 + 0.5
            let isFirstCol = cell.frame.minX <= borderWidth / 2.0 + 0.5
            if !isFirstRow {
                horizontalLines.append(CGRect(x: cell.frame.minX, y: cell.frame.minY,
                                              width: cell.frame.width, height: borderWidth))
            }
            if !isFirstCol {
                verticalLines.append(CGRect(x: cell.frame.minX, y: cell.frame.minY,
                                            width: borderWidth, height: cell.frame.height))
            }
        }
    }

    // Title sub-layout (above the grid).
    var titleSubLayout: InstantPageV2Layout?
    var titleFrame: CGRect?
    if case .empty = title {
        // no title
    } else {
        let titleLayout = layoutBlockSequence(
            [.paragraph(title)],
            boundingWidth: totalWidth - cellInsets.left * 2.0,
            horizontalInset: 0.0,
            kind: .cell,
            context: &context
        )
        titleSubLayout = titleLayout
        let titleHeight = titleLayout.contentSize.height + cellInsets.top + cellInsets.bottom
        titleFrame = CGRect(x: 0.0, y: 0.0, width: totalWidth, height: titleHeight)
    }

    // The table item frame spans the full visible bubble interior (`boundingWidth`); the scroll
    // viewport equals what is actually visible. contentSize.width is the intrinsic grid width
    // (may exceed frame.width → horizontal scroll); the renderer adds the inset on both sides.
    let tableFrame = CGRect(x: 0.0, y: 0.0,
                            width: boundingWidth,
                            height: totalHeight + (titleFrame?.height ?? 0.0))
    let contentSize = CGSize(
        width: totalWidth,
        height: totalHeight + (titleFrame?.height ?? 0.0)
    )

    let tableItem = InstantPageV2TableItem(
        frame: tableFrame,
        titleSubLayout: titleSubLayout,
        titleFrame: titleFrame,
        contentSize: contentSize,
        contentInset: horizontalInset,
        cells: finalizedCells,
        horizontalLines: horizontalLines,
        verticalLines: verticalLines,
        bordered: bordered,
        striped: striped,
        borderColor: context.theme.tableBorderColor
    )
    return [.table(tableItem)]
}

// MARK: - Media placeholder layout

/// Caption+credit sub-helper. Items are positioned in block-global coordinates (y measured from the
/// top of the media block); `offset` is the y-position of the bottom of the placeholder, so
/// caption items start at `offset + topPadding`. The caller uses the returned total height to
/// compute block size. Returns (items, totalHeight).
///
/// **Every caller passes the media's bottom edge unmodified** — the 9pt pad below is the whole
/// media→caption gap, for single media, collages, slideshows and placeholders alike. Do not nudge
/// `offset` at a call site to tune the gap: `layoutTypedMediaWithCaption` once passed
/// `scaledSize.height - 5.0` to absorb the ascender headroom `lineBoxTopInset` adds inside a text
/// box, and because the other three call sites did not, a single image's caption sat 5pt tighter
/// than the identical caption under a slideshow or collage. Tune the pad here instead, where all
/// four kinds move together.
private func layoutCaptionAndCredit(
    _ caption: InstantPageCaption,
    offset: CGFloat,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> ([InstantPageV2LaidOutItem], CGFloat) {
    let metrics = context.metrics
    var items: [InstantPageV2LaidOutItem] = []
    var y = offset
    var totalHeight: CGFloat = 0.0
    var rtl = context.rtl
    var captionIsEmpty = true

    if case .empty = caption.text {
        // no caption text
    } else {
        captionIsEmpty = false
        totalHeight += metrics.captionTopPad
        y += metrics.captionTopPad
        let styleStack = InstantPageTextStyleStack()
        setupStyleStack(styleStack, theme: context.theme, category: .caption, link: false)
        let attributedString = attributedStringForRichText(caption.text, styleStack: styleStack, formatDate: context.formatDate)
        let (textItem, captionItems, captionSize) = layoutTextItem(
            attributedString,
            boundingWidth: boundingWidth - horizontalInset * 2.0,
            offset: CGPoint(x: horizontalInset, y: y),
            fitToWidth: context.fitToWidth,
            computeRevealCharacterRects: context.computeRevealCharacterRects
        )
        totalHeight += captionSize.height
        y += captionSize.height
        items.append(contentsOf: captionItems)
        rtl = textItem?.containsRTL ?? rtl
    }

    if case .empty = caption.credit {
        // no credit text
    } else {
        if captionIsEmpty {
            totalHeight += metrics.captionTopPad
            y += metrics.captionTopPad
        } else {
            totalHeight += metrics.creditTopPad
            y += metrics.creditTopPad
        }
        let styleStack = InstantPageTextStyleStack()
        setupStyleStack(styleStack, theme: context.theme, category: .credit, link: false)
        let attributedString = attributedStringForRichText(caption.credit, styleStack: styleStack, formatDate: context.formatDate)
        let (_, creditItems, creditSize) = layoutTextItem(
            attributedString,
            boundingWidth: boundingWidth - horizontalInset * 2.0,
            alignment: rtl ? .right : .natural,
            offset: CGPoint(x: horizontalInset, y: y),
            fitToWidth: context.fitToWidth,
            computeRevealCharacterRects: context.computeRevealCharacterRects
        )
        totalHeight += creditSize.height
        items.append(contentsOf: creditItems)
    }

    return (items, totalHeight)
}

// How many points a full-width flush media item bleeds past the bubble interior on the
// trailing edge so the rounded `containerNode` clip (see ChatMessageRichDataBubbleContentNode) rounds
// the trailing corners with no 1px background sliver. Harmless: the
// `contentSize.width = min(maxX, boundingWidth)` clamp keeps it from widening the bubble.
private let instantPageV2MediaEdgeBleed: CGFloat = 4.0

// Computes the laid-out frame for a block-media item.
//
// `flush == true` (every current caller): the media is edge-to-edge (x = 0, full
// `boundingWidth`) with corner radius forced to 0, relying on the bubble's rounded clipping
// container to round media that meets the bubble's top/bottom edge. A media item that fills the
// full width is widened by `instantPageV2MediaEdgeBleed` on the trailing edge (see the constant).
// A media item narrower than the full width (a small image — NOT upscaled, the `min(_, 1.0)`
// scale cap is kept) stays at its natural size, flush-left at x = 0, with no bleed.
// (The `cornerRadius` argument is ignored when `flush == true` — flush media is always
// un-rounded; callers may still pass their legacy radius, it has no effect.)
//
// `flush == false`: DEAD as of the V2 audio port — audio was its last caller and now has its
// own `layoutAudio` arm (in `layoutBlock`), so this branch is currently unreachable (follow-up:
// drop the `flush` parameter and this branch). Legacy behavior was: inset by `horizontalInset`
// on each side with the caller-supplied corner radius.
//
// Returns the frame, the un-bled scaled content size (the caption is offset by
// `scaledSize.height`), and the effective corner radius to stamp on the item.
private func instantPageV2MediaFrame(
    naturalSize: CGSize,
    flush: Bool,
    cornerRadius: CGFloat,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    capHeight: Bool = false
) -> (frame: CGRect, scaledSize: CGSize, cornerRadius: CGFloat) {
    let availableWidth = flush ? boundingWidth : (boundingWidth - horizontalInset * 2.0)
    var scaledSize: CGSize
    if naturalSize.width > 0.0 && naturalSize.height > 0.0 {
        let scale = min(availableWidth / naturalSize.width, 1.0)
        scaledSize = CGSize(width: floor(naturalSize.width * scale), height: floor(naturalSize.height * scale))
    } else {
        scaledSize = CGSize(width: availableWidth, height: naturalSize.height)
    }

    // Cap the displayed height at `min(1000, availableWidth)` — "media is never taller than its display
    // width, up to 1000pt" — matching the RichText editor (`MediaBlockBox.imageDisplaySize`). A capped
    // (portrait) box no longer matches the image aspect; the media view renders it aspect-fit + blurred
    // backdrop (the single `.image`/`.video` items pass `fit: true`). The returned `scaledSize.height`
    // is the capped value, so the caption offsets below the capped box. `capHeight` is opt-in so cover
    // images / embed placeholders keep their prior (uncapped) sizing.
    if capHeight {
        let heightCap = min(1000.0, availableWidth)
        if scaledSize.height > heightCap {
            scaledSize.height = heightCap
        }
    }

    if flush {
        // `floor(x) > x - 1` always, so a full-width item (scaledSize.width == floor(availableWidth))
        // always trips this; a genuinely smaller image does not. (availableWidth == boundingWidth
        // in the flush branch, so the bleed below extends past the full bounding width.)
        let fillsWidth = scaledSize.width >= availableWidth - 1.0
        let frameWidth = fillsWidth ? boundingWidth + instantPageV2MediaEdgeBleed : scaledSize.width
        let frame = CGRect(x: 0.0, y: 0.0, width: frameWidth, height: scaledSize.height)
        return (frame, scaledSize, 0.0)
    } else {
        let frame = CGRect(x: horizontalInset, y: 0.0, width: scaledSize.width, height: scaledSize.height)
        return (frame, scaledSize, cornerRadius)
    }
}

/// Variant of `layoutMediaWithCaption` that emits a caller-produced typed media item
/// instead of a `.mediaPlaceholder`. The frame-fitting logic + caption/credit text item
/// layout is otherwise identical.
private func layoutTypedMediaWithCaption(
    produceItem: (CGRect, CGFloat) -> InstantPageV2LaidOutItem,
    naturalSize: CGSize,
    caption: InstantPageCaption,
    isCover: Bool,
    cornerRadius: CGFloat,
    flush: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    capHeight: Bool = false,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let (mediaFrame, scaledSize, effectiveCornerRadius) = instantPageV2MediaFrame(
        naturalSize: naturalSize,
        flush: flush,
        cornerRadius: cornerRadius,
        boundingWidth: boundingWidth,
        horizontalInset: horizontalInset,
        capHeight: capHeight
    )
    var result: [InstantPageV2LaidOutItem] = [produceItem(mediaFrame, effectiveCornerRadius)]

    let (captionItems, captionHeight) = layoutCaptionAndCredit(
        caption,
        offset: scaledSize.height,
        boundingWidth: boundingWidth,
        horizontalInset: horizontalInset,
        context: &context
    )
    result.append(contentsOf: captionItems)

    // Same cover-padding logic as layoutMediaWithCaption: extend the last text item's frame by
    // 14pt when isCover && captionHeight > 0.0.
    if isCover && captionHeight > 0.0 {
        if let lastIndex = result.lastIndex(where: { if case .text = $0 { return true } else { return false } }) {
            if case var .text(lastText) = result[lastIndex] {
                lastText.frame = CGRect(
                    origin: lastText.frame.origin,
                    size: CGSize(width: lastText.frame.width, height: lastText.frame.height + context.metrics.coverCaptionExtraPad)
                )
                result[lastIndex] = .text(lastText)
            }
        }
    }

    return result
}

/// Lays out an `InstantPageBlock.collage(items:caption:)`. Mirrors V1
/// (InstantPageLayout.swift:692-727): compute a mosaic over the inner image/video sizes, then emit
/// one existing typed media item per cell at its mosaic frame, flush (cornerRadius 0) so the bubble's
/// rounded clip handles the outer corners and the 1pt mosaic spacing handles the interior gaps. A
/// single caption renders below the whole mosaic. Cells are top-level `.mediaImage`/`.mediaVideo`
/// items, so gallery / reveal / registry / hidden-media all work with no extra code.
private func layoutCollage(
    items innerBlocks: [InstantPageBlock],
    caption: InstantPageCaption,
    isCover: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // 1. One size per inner block (zero for unresolved — V1 still reserves a mosaic slot).
    var itemSizes: [CGSize] = []
    for block in innerBlocks {
        switch block {
        case let .image(id, _, _, _, _):
            if case let .image(image) = context.media[id], let largest = largestImageRepresentation(image.representations) {
                itemSizes.append(CGSize(width: CGFloat(largest.dimensions.width), height: CGFloat(largest.dimensions.height)))
            } else {
                itemSizes.append(CGSize())
            }
        case let .video(id, _, _, _, _):
            if case let .file(file) = context.media[id], let dimensions = file.dimensions {
                itemSizes.append(CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height)))
            } else {
                itemSizes.append(CGSize())
            }
        default:
            itemSizes.append(CGSize())
        }
    }

    // 2. Mosaic geometry — the same engine V1 uses.
    let (mosaic, mosaicSize) = chatMessageBubbleMosaicLayout(maxSize: CGSize(width: boundingWidth, height: boundingWidth), itemSizes: itemSizes)

    // 3. One typed media item per resolvable cell, at its mosaic frame.
    var result: [InstantPageV2LaidOutItem] = []
    let webpage = context.webpage
    for (i, block) in innerBlocks.enumerated() {
        guard i < mosaic.count else { break }
        let (cellFrame, position) = mosaic[i]
        // Right-edge cells bleed 4pt so the bubble's rounded clip leaves no trailing sliver.
        var frame = cellFrame
        if position.contains(.right) {
            frame.size.width += instantPageV2MediaEdgeBleed
        }
        switch block {
        case let .image(id, blockCaption, url, webpageId, spoiler):
            guard case let .image(image) = context.media[id] else { continue }
            let mediaIndex = context.mediaIndexCounter
            context.mediaIndexCounter += 1
            let mediaUrl: InstantPageUrlItem? = url.flatMap { InstantPageUrlItem(url: $0, webpageId: webpageId) }
            let media = InstantPageMedia(index: mediaIndex, media: .image(image), url: mediaUrl, caption: blockCaption.text, credit: blockCaption.credit)
            result.append(.mediaImage(InstantPageV2MediaImageItem(frame: frame, cornerRadius: 0.0, media: media, webPage: webpage, attributes: [], spoiler: spoiler)))
        case let .video(id, blockCaption, _, _, spoiler):
            guard case let .file(file) = context.media[id] else { continue }
            let mediaIndex = context.mediaIndexCounter
            context.mediaIndexCounter += 1
            let media = InstantPageMedia(index: mediaIndex, media: .file(file), url: nil, caption: blockCaption.text, credit: blockCaption.credit)
            result.append(.mediaVideo(InstantPageV2MediaVideoItem(frame: frame, cornerRadius: 0.0, media: media, webPage: webpage, attributes: [], spoiler: spoiler)))
        default:
            continue
        }
    }

    // 4. Caption below the mosaic.
    let (captionItems, captionHeight) = layoutCaptionAndCredit(caption, offset: mosaicSize.height, boundingWidth: boundingWidth, horizontalInset: horizontalInset, context: &context)
    result.append(contentsOf: captionItems)

    // Cover-caption padding parity with layoutTypedMediaWithCaption.
    if isCover && captionHeight > 0.0 {
        if let lastIndex = result.lastIndex(where: { if case .text = $0 { return true } else { return false } }) {
            if case var .text(lastText) = result[lastIndex] {
                lastText.frame = CGRect(origin: lastText.frame.origin, size: CGSize(width: lastText.frame.width, height: lastText.frame.height + context.metrics.coverCaptionExtraPad))
                result[lastIndex] = .text(lastText)
            }
        }
    }

    return result
}

/// Lays out an `InstantPageBlock.slideshow(items:caption:)`. Mirrors V1
/// (InstantPageLayout.swift:809-843): collect the inner image medias, size the block to the tallest
/// image fitted into the bounding width (capped), emit a single full-width slideshow carousel item,
/// caption below. `.image` AND `.video` inner blocks contribute (the editor's slideshow display mode
/// can hold videos; V1 was image-only, but the editor's mosaic↔slideshow toggle now produces videos).
private func layoutSlideshow(
    items innerBlocks: [InstantPageBlock],
    caption: InstantPageCaption,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    var medias: [InstantPageMedia] = []
    var height: CGFloat = 0.0
    // Cap the block height at `min(1000, boundingWidth)` — matching the RichText editor's
    // `MediaBlockBox.slideshowSize` (was 1200). Each page renders aspect-fit + blurred backdrop within
    // this box (the slideshow's `makeMediaWrapper` passes `fit: true`), so a shorter page shows whole.
    let heightCap = min(1000.0, boundingWidth)
    for block in innerBlocks {
        switch block {
        case let .image(id, blockCaption, url, webpageId, _):
            if case let .image(image) = context.media[id], let imageSize = largestImageRepresentation(image.representations)?.dimensions {
                let mediaIndex = context.mediaIndexCounter
                context.mediaIndexCounter += 1
                let filledSize = imageSize.cgSize.fitted(CGSize(width: boundingWidth, height: heightCap))
                height = max(height, filledSize.height)
                let mediaUrl: InstantPageUrlItem? = url.flatMap { InstantPageUrlItem(url: $0, webpageId: webpageId) }
                medias.append(InstantPageMedia(index: mediaIndex, media: .image(image), url: mediaUrl, caption: blockCaption.text, credit: blockCaption.credit))
            }
        case let .video(id, blockCaption, _, _, _):
            // Videos in a slideshow (the editor's mosaic↔slideshow toggle produces these) render as a
            // poster + play badge (tap opens the gallery), exactly like a collage video cell. Without this
            // arm the video was dropped entirely — no page, short paging-dot count. Sized like an image
            // from the file's dimensions (fitted to width, capped).
            if case let .file(file) = context.media[id], let dimensions = file.dimensions {
                let mediaIndex = context.mediaIndexCounter
                context.mediaIndexCounter += 1
                let filledSize = dimensions.cgSize.fitted(CGSize(width: boundingWidth, height: heightCap))
                height = max(height, filledSize.height)
                medias.append(InstantPageMedia(index: mediaIndex, media: .file(file), url: nil, caption: blockCaption.text, credit: blockCaption.credit))
            }
        default:
            break
        }
    }

    var result: [InstantPageV2LaidOutItem] = []
    result.append(.slideshow(InstantPageV2SlideshowItem(
        frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: height),
        medias: medias,
        webPage: context.webpage
    )))

    let (captionItems, _) = layoutCaptionAndCredit(caption, offset: height, boundingWidth: boundingWidth, horizontalInset: horizontalInset, context: &context)
    result.append(contentsOf: captionItems)
    return result
}

private func layoutMediaWithCaption(
    kind: InstantPageV2MediaPlaceholderKind,
    naturalSize: CGSize,
    caption: InstantPageCaption,
    isCover: Bool,
    cornerRadius: CGFloat,
    flush: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let (placeholderFrame, scaledSize, effectiveCornerRadius) = instantPageV2MediaFrame(
        naturalSize: naturalSize,
        flush: flush,
        cornerRadius: cornerRadius,
        boundingWidth: boundingWidth,
        horizontalInset: horizontalInset
    )
    let placeholderItem = InstantPageV2MediaPlaceholderItem(
        frame: placeholderFrame,
        kind: kind,
        cornerRadius: effectiveCornerRadius
    )

    var result: [InstantPageV2LaidOutItem] = [.mediaPlaceholder(placeholderItem)]

    let (captionItems, captionHeight) = layoutCaptionAndCredit(
        caption,
        offset: scaledSize.height,
        boundingWidth: boundingWidth,
        horizontalInset: horizontalInset,
        context: &context
    )
    result.append(contentsOf: captionItems)

    // isCover adds extra 14pt bottom padding — but only when caption/credit text was actually
    // rendered (matches V1 lines 204-206: `contentSize.height > 0 && isCover`). For an
    // empty-caption cover image no padding is added.
    // Implemented by extending the last text item's frame rather than emitting an invisible shape
    // view that would silently consume tap area.
    if isCover && captionHeight > 0.0 {
        if let lastIndex = result.lastIndex(where: { if case .text = $0 { return true } else { return false } }) {
            if case var .text(lastText) = result[lastIndex] {
                lastText.frame = CGRect(
                    origin: lastText.frame.origin,
                    size: CGSize(width: lastText.frame.width, height: lastText.frame.height + context.metrics.coverCaptionExtraPad)
                )
                result[lastIndex] = .text(lastText)
            }
        }
    }

    return result
}

// MARK: - Simple-block layout functions

private func layoutSimpleText(
    _ text: RichText,
    category: InstantPageTextCategoryType,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: category, link: false)
    let attributedString = attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)
    let (_, items, _) = layoutTextItem(
        attributedString,
        boundingWidth: boundingWidth - horizontalInset * 2.0,
        alignment: context.rtl ? .right : .natural,
        offset: CGPoint(x: horizontalInset, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    return items
}

private func layoutHeading(
    _ text: RichText,
    level: Int32,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, attributes: context.theme.headingTextAttributes(level: level, link: false))
    let attributedString = attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)
    let (_, items, _) = layoutTextItem(
        attributedString,
        boundingWidth: boundingWidth - horizontalInset * 2.0,
        alignment: context.rtl ? .right : .natural,
        offset: CGPoint(x: horizontalInset, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    stampMarkdownContext(items, kind: .heading(level: max(1, min(6, Int(level)))))
    return items
}

private func layoutParagraph(
    _ text: RichText,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    previousItems: [InstantPageV2LaidOutItem],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let _ = previousItems

    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: kind == .cell ? .table : .paragraph, link: false)
    // `inlineButtonMaxWidth` caps a `textButton` pill, which cannot be re-broken onto the next line
    // once it is wider than the line itself. Must match the width handed to `layoutTextItem` below.
    //
    // Deliberately NOT passed as `boundingWidth`: that parameter also drives the inline-IMAGE clamp
    // (`fittedToWidthOrSmaller`), which has never been active on this path, and switching it on would
    // silently resize existing inline images.
    let attributedString = attributedStringForRichText(text, styleStack: styleStack, inlineButtonMaxWidth: boundingWidth - horizontalInset * 2.0, formatDate: context.formatDate)

    let (_, items, _) = layoutTextItem(
        attributedString,
        boundingWidth: boundingWidth - horizontalInset * 2.0,
        alignment: context.rtl ? .right : .natural,
        offset: CGPoint(x: horizontalInset, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    return items
}

private func layoutAuthorDate(
    author: RichText,
    date: Int32,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    previousItems: [InstantPageV2LaidOutItem],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Literal port of V1 InstantPageLayout.swift case .authorDate (lines 231–272).
    // Reads context.strings, formats date via DateFormatter with locale from localeWithStrings,
    // splices author and date into InstantPage_AuthorAndDateTitle format string.
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: .caption, link: false)

    // Capture strings by value to avoid capturing inout context in an escaping closure.
    let strings = context.strings
    let stringForDate: (Int32) -> String = { d in
        let formatter = DateFormatter()
        formatter.locale = localeWithStrings(strings)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date(timeIntervalSince1970: Double(d)))
    }

    var text: RichText?
    if case .empty = author {
        if date != 0 {
            text = .plain(stringForDate(date))
        }
    } else {
        if date != 0 {
            let dateText = RichText.plain(stringForDate(date))
            let formatString = context.strings.InstantPage_AuthorAndDateTitle("%1$@", "%2$@").string
            let authorRange = formatString.range(of: "%1$@")!
            let dateRange = formatString.range(of: "%2$@")!
            if authorRange.lowerBound < dateRange.lowerBound {
                let byPart = String(formatString[formatString.startIndex ..< authorRange.lowerBound])
                let middlePart = String(formatString[authorRange.upperBound ..< dateRange.lowerBound])
                let endPart = String(formatString[dateRange.upperBound...])
                text = .concat([.plain(byPart), author, .plain(middlePart), dateText, .plain(endPart)])
            } else {
                let beforePart = String(formatString[formatString.startIndex ..< dateRange.lowerBound])
                let middlePart = String(formatString[dateRange.upperBound ..< authorRange.lowerBound])
                let endPart = String(formatString[authorRange.upperBound...])
                text = .concat([.plain(beforePart), dateText, .plain(middlePart), author, .plain(endPart)])
            }
        } else {
            text = author
        }
    }

    guard let resolvedText = text else { return [] }

    var previousItemHasRTL = false
    if case let .text(prev) = previousItems.last, prev.textItem.containsRTL {
        previousItemHasRTL = true
    }
    let alignment: NSTextAlignment = (context.rtl || previousItemHasRTL) ? .right : .natural

    let (_, items, _) = layoutTextItem(
        attributedStringForRichText(resolvedText, styleStack: styleStack, formatDate: context.formatDate),
        boundingWidth: boundingWidth - horizontalInset * 2.0,
        alignment: alignment,
        offset: CGPoint(x: horizontalInset, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    return items
}

private func layoutDivider(
    boundingWidth: CGFloat,
    context: LayoutContext
) -> [InstantPageV2LaidOutItem] {
    let lineWidth = floor(boundingWidth / 2.0)
    let frame = CGRect(
        x: floor((boundingWidth - lineWidth) / 2.0),
        y: 0.0,
        width: lineWidth,
        height: UIScreenPixel
    )
    return [.divider(InstantPageV2DividerItem(frame: frame, color: context.theme.separatorColor))]
}

// MARK: - Code block layout (ported from V1 InstantPageLayout.swift lines 329–351)

/// Lowercased display form of a code block's language, or nil when there is nothing to show.
/// Lowercasing happens here rather than in the view so the model's casing ("Swift", "SWIFT") cannot
/// reach the screen.
func instantPageV2CodeLanguageDisplayText(_ language: String?) -> String? {
    guard let language = language, !language.isEmpty else {
        return nil
    }
    return language.lowercased()
}

private func layoutCodeBlock(
    _ text: RichText,
    language: String?,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // A plain band spanning the container's interior, with the code text at the paragraph inset of
    // this nesting level — so the band's interior side padding IS the paragraph inset, never a
    // code-block constant of its own. See
    // docs/superpowers/specs/2026-08-18-code-block-edge-to-edge-design.md.
    let verticalInset = context.metrics.codeBlockVerticalInset
    let bleed = context.childBleed

    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: .codeBlock, link: false)
    // Code is sized from the metrics, not from the theme's `codeBlock` category (15 in the chat table,
    // 14 in the Instant View themes): a whole-point floor of 15 × scale, equal to the table and quote-body
    // sizes at every content scale, and shrinking inside a quote with everything around it.
    styleStack.push(.fontSize(context.metrics.codeBlockFontSize))
    // `attributedStringForRichText` returns an immutable `NSAttributedString`, so take a mutable copy to
    // overlay onto — the same move V1's `attributedStringForPreformattedText` makes.
    let highlightedString = (attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)
        .mutableCopy() as! NSMutableAttributedString)
    // Overlay the cached syntax highlight. `cachedMessageSyntaxHighlight` has been stored on the layout
    // context — and read by nothing — since V2 was written, so V2 code blocks rendered plain while V1's
    // (`attributedStringForPreformattedText`) highlighted. A miss changes nothing.
    applyInstantPageSyntaxHighlight(to: highlightedString, language: language,
                                    cache: context.cachedMessageSyntaxHighlight)
    let attributedString: NSAttributedString = highlightedString

    // The text measure is the paragraph measure at this level — the same width a sibling paragraph
    // gets, which is what makes the two align on BOTH edges.
    let innerWidth = boundingWidth - horizontalInset * 2.0

    // The bold language line, when present. It mirrors the QUOTE AUTHOR's derivation — the caption
    // category's family and colour, pushed to bold at the paragraph size — rather than carrying a
    // font of its own, so the editor's copy of it cannot be set to something different.
    var languageItem: InstantPageTextItem?
    var languageHeight: CGFloat = 0.0
    var languageOverheadTop: CGFloat = 0.0
    var hasLanguageLine = false
    if let display = instantPageV2CodeLanguageDisplayText(language) {
        let languageStack = InstantPageTextStyleStack()
        setupStyleStack(languageStack, theme: context.theme, category: .caption, link: false)
        languageStack.push(.bold)
        languageStack.push(.fontSize(context.theme.textCategories.paragraph.font.size))
        let string = attributedStringForRichText(.plain(display), styleStack: languageStack, formatDate: context.formatDate)
        languageOverheadTop = instantPageV2TextBoxOverheads(string).top
        let (item, _, size) = layoutTextItem(
            string,
            boundingWidth: innerWidth,
            alignment: context.rtl ? .right : .natural,
            offset: CGPoint(x: 0.0, y: 0.0),
            fitToWidth: context.fitToWidth,
            computeRevealCharacterRects: context.computeRevealCharacterRects
        )
        languageItem = item
        languageHeight = size.height
        hasLanguageLine = item != nil
    }

    let (textItem, _, textSize) = layoutTextItem(
        attributedString,
        boundingWidth: innerWidth,
        offset: CGPoint(x: 0.0, y: 0.0),
        fitToWidth: context.fitToWidth,
        opaqueBackground: true,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    guard let textItem = textItem else { return [] }
    textItem.markdownContext = InstantPageMarkdownBlockContext(kind: .code(language: language))

    // The text items are true font line boxes (ascent headroom above the caps, descent below the
    // last baseline). Subtract that overhead so the VISIBLE gap from the band to the glyphs equals
    // `verticalInset` on both edges. The TOP overhead belongs to whichever line is first.
    let codeOverheads = instantPageV2TextBoxOverheads(attributedString)
    let topPad = max(0.0, verticalInset - (hasLanguageLine ? languageOverheadTop : codeOverheads.top))
    let bottomPad = max(0.0, verticalInset - codeOverheads.bottom)

    // The code text's x is the PARAGRAPH inset measured from the band's leading edge, which the
    // bleed moved outward. Both text items are in block-local coordinates.
    let bandFrame = instantPageV2CodeBandFrame(boundingWidth: boundingWidth, horizontalInset: horizontalInset,
                                               bleed: bleed, height: 0.0)
    let localTextX = horizontalInset - bandFrame.minX

    var y = topPad
    if let item = languageItem {
        item.frame = CGRect(x: localTextX, y: y, width: item.frame.width, height: item.frame.height)
        y += languageHeight + context.metrics.codeBlockLanguageSpacing
    }
    textItem.frame = CGRect(x: localTextX, y: y, width: textItem.frame.width, height: textItem.frame.height)
    y += textSize.height

    let blockHeight = y + bottomPad
    let blockFrame = CGRect(x: bandFrame.minX, y: 0.0, width: bandFrame.width, height: blockHeight)

    return [.codeBlock(InstantPageV2CodeBlockItem(
        frame: blockFrame,
        backgroundColor: context.theme.codeBlockBackgroundColor,
        language: language,
        languageItem: languageItem,
        textItem: textItem,
        inset: UIEdgeInsets(top: topPad, left: localTextX, bottom: bottomPad, right: localTextX)
    ))]
}

/// Vertical overhead of a V2 text item's true-font-line-box relative to the visible glyph box:
/// `.top` = ascent headroom above the cap line, `.bottom` = descent below the last baseline.
/// Subtracting these from an intended inset makes the VISIBLE fill→glyph gap equal that inset.
private func instantPageV2TextBoxOverheads(_ string: NSAttributedString) -> (top: CGFloat, bottom: CGFloat) {
    guard string.length > 0, let font = string.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
        return (0.0, 0.0)
    }
    return (max(0.0, font.ascender - font.capHeight), max(0.0, -font.descender))
}

/// The block-quote corner glyph (mirrors InteractiveTextComponent's `quoteIcon`): the `ReplyQuoteIcon`
/// (9×7 natural), accent-tinted, inset 4pt from the frame's top corner — top-right for LTR, top-left
/// for RTL (opposite the leading bar). The quote frame spans `[horizontalInset, boundingWidth − horizontalInset]`.
private func instantPageV2BlockQuoteIcon(boundingWidth: CGFloat, horizontalInset: CGFloat, color: UIColor, rtl: Bool) -> InstantPageV2LaidOutItem {
    let iconSize = CGSize(width: 9.0, height: 7.0)
    let iconX = rtl ? (horizontalInset + 4.0) : (boundingWidth - horizontalInset - 4.0 - iconSize.width)
    return .imageOrnament(InstantPageV2ImageOrnamentItem(
        frame: CGRect(x: iconX, y: 4.0, width: iconSize.width, height: iconSize.height),
        imageName: "Chat/Message/ReplyQuoteIcon", color: color, rotated: false))
}

private func layoutThinking(
    _ text: RichText,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Dimmed/secondary base color: the paragraph body color at reduced alpha. RichText keeps
    // its own bold/italic/link/inline-emoji formatting on top of this base (mirrors the old
    // hardcoded "Thinking…" header, which used the message theme's dimmed description color).
    let base = context.theme.textCategories.paragraph
    let dimmedAttributes = InstantPageTextAttributes(
        font: base.font,
        color: base.color.withAlphaComponent(0.55),
        underline: false
    )
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, attributes: dimmedAttributes)
    let attributedString = attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)

    // Mirror a normal `.text` item's sizing: lay the text out flush (offset .zero) and put the page
    // inset onto the BLOCK frame, so the `.thinking` item's frame == a `.text` item's frame
    // (`(horizontalInset, 0, textWidth, height)`) instead of a full-bleed `(0, 0, boundingWidth, …)`
    // box. The shimmer (sized to `item.frame.size`) then hugs the text rather than the whole page
    // width; the rendered text stays at the same place (`horizontalInset`) since the block carries
    // the inset.
    let (textItem, _, textSize) = layoutTextItem(
        attributedString,
        boundingWidth: boundingWidth - horizontalInset * 2.0,
        offset: CGPoint(x: 0.0, y: 0.0),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    guard let textItem = textItem else { return [] }

    let blockFrame = CGRect(x: horizontalInset, y: 0.0, width: textSize.width, height: textSize.height - 4.0)
    return [.thinking(InstantPageV2ThinkingItem(frame: blockFrame, textItem: textItem))]
}

// MARK: - Block quote / pull quote layout (ported from V1 InstantPageLayout.swift lines 517–586)

private func layoutBlockQuote(
    blocks: [InstantPageBlock],
    caption: RichText,
    authorCollapsed: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    isLast: Bool,
    pathPrefix: [Int] = [],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Quoted content lays out one typographic step below body. Assign, never multiply: a nested
    // quote takes the same precomputed values rather than compounding (see `LayoutContext`).
    let savedTheme = context.theme, savedMetrics = context.metrics, savedChildBleed = context.childBleed
    context.theme = context.quoteTheme
    context.metrics = context.quoteMetrics
    defer { context.theme = savedTheme; context.metrics = savedMetrics; context.childBleed = savedChildBleed }

    // These are the QUOTE's own insets, and they read the already-swapped metrics on purpose: a
    // 15pt quote carrying 17pt-tuned padding is the mismatch this scale exists to remove.
    let verticalInset = context.metrics.quoteVerticalInset
    let lineInset = context.metrics.quoteLineInset

    let innerBoundingWidth = boundingWidth - horizontalInset * 2.0 - lineInset
    let innerHorizontalInset = horizontalInset + lineInset
    // RTL: rigid-translate the child band so its gutter (lineInset) lands on the trailing edge,
    // faithfully mirroring the existing (intentionally preserved) LTR band. Width is preserved,
    // so a single x-delta moves the whole band correctly.
    let bandOffsetX: CGFloat = context.rtl ? (2.0 * horizontalInset + lineInset) : 0.0

    // Children are laid out flush against a band of their own (`horizontalInset: 0`) and then
    // TRANSLATED onto it, the way `layoutList` already places its sub-blocks — rather than being
    // laid out in the parent's coordinate space with the band's inset passed down.
    //
    // The distinction is invisible for text, which honours `horizontalInset` and lands in the same
    // place either way, and load-bearing for every FULL-BLEED block. A flush block ignores
    // `horizontalInset` on purpose — that is what flush means, fill the container edge to edge — so
    // passing the band inset down left media, tables, details bodies, collages and slideshows
    // sitting at x = 0, against the page's leading edge and outside the quote entirely. Laying them
    // out against the band and translating puts every one of them inside it, with no per-block
    // knowledge of quotes.
    //
    // `bandWidth` is exactly the width text already had here (`innerBoundingWidth` less the inset on
    // both sides), and `bandX` reproduces its old origin, so this moves no text by even a fraction.
    let bandWidth = innerBoundingWidth - innerHorizontalInset * 2.0
    let bandX = innerHorizontalInset + bandOffsetX

    // The quote's interior, expressed as how far a full-bleed child may reach past the child band.
    // GEOMETRIC sides: in RTL the bar moves to the max-x edge, so the two swap. The quote's own fill
    // spans [horizontalInset, boundingWidth - horizontalInset] and its bar is `quoteBarWidth` wide on
    // the leading side; a child bleeds to just INSIDE the bar so the bar stays continuous down the
    // whole quote rather than being interrupted for the child's height.
    let quoteFillMinX = horizontalInset
    let quoteFillMaxX = boundingWidth - horizontalInset
    let bandMaxX = bandX + bandWidth
    context.childBleed = context.rtl
        ? InstantPageV2ChildBleed(minXSide: bandX - quoteFillMinX,
                                  maxXSide: (quoteFillMaxX - instantPageV2QuoteBarWidth) - bandMaxX)
        : InstantPageV2ChildBleed(minXSide: bandX - (quoteFillMinX + instantPageV2QuoteBarWidth),
                                  maxXSide: quoteFillMaxX - bandMaxX)

    var result: [InstantPageV2LaidOutItem] = []
    // Two running heights, equal except inside a COLLAPSED quote: `contentHeight` is what the quote
    // reserves (and therefore how tall it is), `drawnHeight` is where the next child is positioned.
    // They diverge past the three-line cut, where children are still painted — for the mask to sweep
    // away — but no longer counted. See `instantPageV2QuoteBudgetedItems`.
    var contentHeight: CGFloat = verticalInset
    var drawnHeight: CGFloat = verticalInset

    // A quote's children are spaced by the page's own rhythm, like every other block sequence
    // (`layoutBlockSequence`, details bodies, table cells, list sub-blocks): a quote is a container,
    // not a separate spacing regime. This replaced a flat 10pt `childSpacing`, which meant a
    // heading, a list and a paragraph all sat the same distance apart inside a quote while the
    // identical run of blocks outside it did not — and, being a constant here, silently ignored
    // every rule the spacing model gained.
    //
    // `kind` is the enclosing sequence's, matching what the children themselves are laid out with.
    // If quotes ever want a denser rhythm of their own, that belongs in `spacingBetweenBlocks` as a
    // `BlockSequenceKind` case (the way `.list` already is), not as a constant at this call site.
    //
    // The sequence EDGES stay the quote's own `verticalInset`: `layoutBlockSequence`'s leading /
    // trailing edge contributions are deliberately NOT added, because the quote already pads itself
    // and stacking both would double the gap above the first child and below the last.
    //
    // `previousBlock` advances only when a child actually contributed height, mirroring
    // `layoutBlockSequence` — a zero-height child (an anchor, an unresolvable medium) has to stay
    // transparent to spacing rather than open a gap against nothing.
    // A collapsed quote previews the first `instantPageV2CollapsedQuoteLineBudget` text lines. The
    // budget is applied AS children are laid out, not as a post-pass: the siblings after a truncated
    // item do not exist yet, so nothing needs re-positioning and `contentHeight` is right by
    // construction.
    //
    // `totalTextLines` keeps counting past the budget because the collapsible decision needs the
    // UNtruncated total — a quote no longer than its own preview shows no control. `linesEmitted`
    // counts only what survived.
    let quoteIsExpanded = context.expandedQuotePaths.contains(pathPrefix)
    let applyBudget = authorCollapsed && !quoteIsExpanded
    // Whether the cut lines may stay DRAWN below the truncated item, for the animated mask to sweep
    // away as the quote closes. Safe only when nothing follows them inside the quote: once the budget
    // is exhausted every later child is dropped, so the one thing that can still sit underneath is
    // the caption, which is emitted below and is not budgeted.
    var keepQuoteOverflow = false
    if case .empty = caption {
        keepQuoteOverflow = true
    }
    var totalTextLines = 0
    var linesEmitted = 0
    var budgetExhausted = false

    var previousBlock: InstantPageBlock?
    for (i, child) in blocks.enumerated() {
        let spacing: CGFloat = previousBlock == nil
            ? 0.0
            : spacingBetweenBlocks(upper: previousBlock, lower: child, kind: kind, metrics: context.metrics)
        let childItems = layoutBlock(
            child,
            boundingWidth: bandWidth,
            horizontalInset: 0.0,
            kind: kind,
            isCover: false,
            previousItems: result,
            isLast: i == blocks.count - 1 && isLast,
            pathPrefix: pathPrefix + [i],
            context: &context
        )
        for item in childItems {
            totalTextLines += instantPageV2TextLineCount(item)
        }
        // `reservedCount` splits this child's items into the ones the quote takes height for and the
        // ones that are merely drawn. Everything is drawn at its natural position either way, so a
        // child's coordinates do not move when the reader toggles the quote — only the quote's own
        // height and its mask do. That is what stops a medium below the cut from being torn down and
        // rebuilt (a blink) rather than swept away by the closing fade.
        var effectiveChildItems = childItems
        var reservedCount = childItems.count
        if applyBudget {
            if budgetExhausted {
                effectiveChildItems = keepQuoteOverflow ? childItems : []
                reservedCount = 0
            } else {
                let budgeted = instantPageV2QuoteBudgetedItems(
                    childItems,
                    remainingLines: instantPageV2CollapsedQuoteLineBudget - linesEmitted,
                    keepingOverflow: keepQuoteOverflow
                )
                effectiveChildItems = budgeted.reserved + budgeted.overflow
                reservedCount = budgeted.reserved.count
                linesEmitted += budgeted.linesConsumed
                if linesEmitted >= instantPageV2CollapsedQuoteLineBudget || budgeted.reserved.count + budgeted.overflow.count < childItems.count {
                    budgetExhausted = true
                }
            }
        }

        // Positioned from `drawnHeight`, which advances over everything painted; the quote's own
        // height (`contentHeight`) advances only over what is reserved.
        let dy = drawnHeight + spacing
        let offsetItems = effectiveChildItems.map { $0.offsetBy(CGPoint(x: bandX, y: dy)) }
        var childDrawnMaxY: CGFloat = 0.0
        var childReservedMaxY: CGFloat = 0.0
        for (index, item) in offsetItems.enumerated() {
            childDrawnMaxY = max(childDrawnMaxY, instantPageV2DrawnMaxY(item))
            if index < reservedCount {
                childReservedMaxY = max(childReservedMaxY, item.frame.maxY)
            }
        }
        if childDrawnMaxY > drawnHeight {
            drawnHeight = childDrawnMaxY
            previousBlock = child
        }
        if childReservedMaxY > contentHeight {
            contentHeight = childReservedMaxY
        }
        result.append(contentsOf: offsetItems)
    }

    // Optional caption (mirrors layoutQuoteText's caption branch).
    if case .empty = caption {
        // no caption
    } else {
        // Small gap between the body and the attribution (author) line.
        contentHeight += context.metrics.quoteAttributionGap
        let captionStyleStack = InstantPageTextStyleStack()
        setupStyleStack(captionStyleStack, theme: context.theme, category: .caption, link: false)
        // The author is part of the quote's own chrome, so it takes the quote accent — the SAME
        // theme field the bar and fill read, not a copy, so the three cannot drift apart. (This is
        // why it is not a `.quoteAuthor` text category: a category would have to carry the colour
        // through all ten `InstantPageTextCategories` construction sites, each free to disagree with
        // `quoteAccentColor`. Make it a category only if the author ever needs its own font metrics,
        // which the `.caption` base supplies today.)
        //
        // `linkColor` moves with the text colour to preserve the caption-family rule that a link
        // matches its surrounding text and is therefore auto-underlined — see `setupStyleStack`.
        captionStyleStack.push(.textColor(context.theme.quoteAccentColor))
        captionStyleStack.push(.linkColor(context.theme.quoteAccentColor))
        captionStyleStack.push(.bold)
        // The author line matches the quote BODY's size, not the caption category's. The two were
        // both 15pt before quoted content took its own scale; the scale then took `.caption` down a
        // SECOND step (15 → 13pt), which reads as a footnote under the quote rather than as its
        // attribution. Sourcing the size from `.paragraph` — the category the body itself uses —
        // locks the two together at whatever scale is current, where an absolute 15pt would drift
        // from the body again at the reader's larger font sizes. Pushed after `setupStyleStack`
        // because the stack resolves last-push-wins (see `textAttributes()`).
        captionStyleStack.push(.fontSize(context.theme.textCategories.paragraph.font.size))
        let attributedCaption = attributedStringForRichText(caption, styleStack: captionStyleStack, formatDate: context.formatDate)
        let (_, captionItems, captionSize) = layoutTextItem(
            attributedCaption,
            boundingWidth: innerBoundingWidth,
            alignment: context.rtl ? .right : .natural,
            // The caption is single-inset (band [H+lineInset, B-H]), unlike the double-inset
            // child band, so it needs its own RTL mirror delta of -lineInset (→ [H, B-H-lineInset],
            // tucked under the trailing bar) — NOT the children's bandOffsetX.
            offset: CGPoint(x: innerHorizontalInset + (context.rtl ? -lineInset : 0.0), y: contentHeight),
            fitToWidth: context.fitToWidth,
            computeRevealCharacterRects: context.computeRevealCharacterRects
        )
        result.append(contentsOf: captionItems)
        contentHeight += captionSize.height
    }

    contentHeight += verticalInset

    let collapseState = instantPageV2QuoteCollapseState(totalTextLines: totalTextLines,
                                                        authorCollapsed: authorCollapsed,
                                                        isExpanded: quoteIsExpanded)

    // Room for the EXPANDED chevron. A COLLAPSED quote needs none — its bottom fade already clears
    // the corner the arrow sits in — but an expanded one would otherwise draw the arrow straight over
    // whatever its last row put there. `InteractiveTextComponent` widens the last line first and only
    // grows the block if that does not fit; a V2 quote's width is the band's and cannot stretch, so
    // only the grow branch survives the port.
    if collapseState == .expanded {
        let quoteFrame = CGRect(x: horizontalInset, y: 0.0, width: boundingWidth - horizontalInset * 2.0, height: contentHeight)
        let lastRowTop = contentHeight - verticalInset - instantPageV2QuoteChevronClearance
        var chevronCornerOccupied = false
        for item in result {
            guard item.frame.maxY > lastRowTop else {
                continue
            }
            if instantPageV2QuoteChevronSideInset(item, quoteFrame: quoteFrame, rtl: context.rtl) < instantPageV2QuoteChevronClearance {
                chevronCornerOccupied = true
                break
            }
        }
        if chevronCornerOccupied {
            contentHeight += instantPageV2QuoteChevronExtraHeight
        }
    }

    // Accent bar + accent-tinted rounded fill spanning the whole quote band (behind child content).
    let frameItem = InstantPageV2QuoteFrameItem(
        frame: CGRect(x: horizontalInset, y: 0.0, width: boundingWidth - horizontalInset * 2.0, height: contentHeight),
        accentColor: context.theme.quoteAccentColor, barWidth: instantPageV2QuoteBarWidth, cornerRadius: 6.0, fillAlpha: 0.10, barOnTrailing: context.rtl,
        collapseState: collapseState,
        path: pathPrefix)
    result.insert(.quoteFrame(frameItem), at: 0)
    result.append(instantPageV2BlockQuoteIcon(boundingWidth: boundingWidth, horizontalInset: horizontalInset, color: context.theme.quoteAccentColor, rtl: context.rtl))

    // Caption items (appended above) are also bumped to quoteDepth 1 and will render with a
    // `>` prefix. The whole-message markdown converter drops blockquote captions entirely, and
    // markdown-sent quotes carry empty captions, so this is benign.
    bumpQuoteDepth(result)
    return result
}

private func layoutQuoteText(
    text: RichText,
    caption: RichText,
    isPull: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // Quoted content lays out one typographic step below body — see `layoutBlockQuote`. Reached
    // only for `.pullQuote` today, but the swap stays unconditional: it is an assignment, so it
    // costs nothing if a caller re-enters with the quote scale already applied.
    let savedTheme = context.theme, savedMetrics = context.metrics
    context.theme = context.quoteTheme
    context.metrics = context.quoteMetrics
    defer { context.theme = savedTheme; context.metrics = savedMetrics }

    // Bubble-tuned insets: block-quote text sits 9pt from the frame's left border, 6pt top/bottom;
    // the trailing inset is larger (16pt) so the text clears the top-right quote icon (9pt wide +
    // 4pt corner inset). The pull-quote pill uses 12pt top/bottom and reserves `pullQuotePadding`
    // on each side so the centered body clears the top-left / bottom-right corner quote marks —
    // this is the same value as the pill's own content-hugging horizontal padding below.
    let pullQuotePadding = context.metrics.pullQuotePadding
    let verticalInset: CGFloat = isPull ? context.metrics.pullQuoteVerticalInset : context.metrics.quoteVerticalInset
    let leadingInset: CGFloat = isPull ? pullQuotePadding : context.metrics.quoteLeadingInset
    let trailingInset: CGFloat = isPull ? pullQuotePadding : context.metrics.quoteTrailingInset

    var result: [InstantPageV2LaidOutItem] = []

    // Body text style: the paragraph category, which under the quote-scaled theme swapped in above
    // IS 15pt in a chat bubble — and tracks the reader's font-size setting elsewhere, which the
    // absolute `.fontSize(15.0)` push this replaced could not. Pull quotes force italic + center.
    let styleStack = InstantPageTextStyleStack()
    setupStyleStack(styleStack, theme: context.theme, category: .paragraph, link: false)
    if isPull {
        styleStack.push(.italic)
    }

    let textBoundingWidth = boundingWidth - horizontalInset * 2.0 - leadingInset - trailingInset
    // Center the pull-quote text box within [horizontalInset+pad, boundingWidth-horizontalInset-pad]
    // so the (symmetric) inner padding is applied on both sides; regular quotes anchor to the leading
    // inset (mirrored for RTL).
    let textX: CGFloat = isPull
        ? horizontalInset + leadingInset
        : (context.rtl ? horizontalInset + trailingInset : horizontalInset + leadingInset)
    let textAlignment: NSTextAlignment = isPull ? .center : (context.rtl ? .right : .natural)

    let attributedBody = attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)
    // Subtract the font-box overhead so the VISIBLE top/bottom padding equals verticalInset (6pt),
    // matching the geometric horizontal inset (see instantPageV2TextBoxOverheads).
    let bodyOverheads = instantPageV2TextBoxOverheads(attributedBody)
    var contentHeight: CGFloat = max(0.0, verticalInset - bodyOverheads.top)
    var lastBottomOverhead = bodyOverheads.bottom
    let (bodyTextItem, bodyItems, bodySize) = layoutTextItem(
        attributedBody,
        boundingWidth: textBoundingWidth,
        alignment: textAlignment,
        offset: CGPoint(x: textX, y: contentHeight),
        fitToWidth: context.fitToWidth,
        computeRevealCharacterRects: context.computeRevealCharacterRects
    )
    result.append(contentsOf: bodyItems)
    contentHeight += bodySize.height

    // The quote-text region (marks bracket this; the pull-quote pill also spans any caption below).
    let quoteRegionBottom = contentHeight + max(0.0, verticalInset - bodyOverheads.bottom)

    // Optional caption (attribution / author line): bold, and bold+italic centered for pull quotes.
    if case .empty = caption {
        // no caption
    } else {
        // Small gap between the body and the attribution (author) line.
        contentHeight += context.metrics.quoteAttributionGap
        let captionStyleStack = InstantPageTextStyleStack()
        setupStyleStack(captionStyleStack, theme: context.theme, category: .caption, link: false)
        // The author is part of the quote's own chrome, so it takes the quote accent — the SAME
        // theme field the bar and fill read, not a copy, so the three cannot drift apart. (This is
        // why it is not a `.quoteAuthor` text category: a category would have to carry the colour
        // through all ten `InstantPageTextCategories` construction sites, each free to disagree with
        // `quoteAccentColor`. Make it a category only if the author ever needs its own font metrics,
        // which the `.caption` base supplies today.)
        //
        // `linkColor` moves with the text colour to preserve the caption-family rule that a link
        // matches its surrounding text and is therefore auto-underlined — see `setupStyleStack`.
        captionStyleStack.push(.textColor(context.theme.quoteAccentColor))
        captionStyleStack.push(.linkColor(context.theme.quoteAccentColor))
        captionStyleStack.push(.bold)
        // The author line matches the quote BODY's size, not the caption category's. The two were
        // both 15pt before quoted content took its own scale; the scale then took `.caption` down a
        // SECOND step (15 → 13pt), which reads as a footnote under the quote rather than as its
        // attribution. Sourcing the size from `.paragraph` — the category the body itself uses —
        // locks the two together at whatever scale is current, where an absolute 15pt would drift
        // from the body again at the reader's larger font sizes. Pushed after `setupStyleStack`
        // because the stack resolves last-push-wins (see `textAttributes()`).
        captionStyleStack.push(.fontSize(context.theme.textCategories.paragraph.font.size))
        if isPull {
            captionStyleStack.push(.italic)
        }
        let attributedCaption = attributedStringForRichText(caption, styleStack: captionStyleStack, formatDate: context.formatDate)
        lastBottomOverhead = instantPageV2TextBoxOverheads(attributedCaption).bottom
        let (_, captionItems, captionSize) = layoutTextItem(
            attributedCaption,
            boundingWidth: textBoundingWidth,
            alignment: textAlignment,
            offset: CGPoint(x: textX, y: contentHeight),
            fitToWidth: context.fitToWidth,
            computeRevealCharacterRects: context.computeRevealCharacterRects
        )
        result.append(contentsOf: captionItems)
        contentHeight += captionSize.height
    }

    contentHeight += max(0.0, verticalInset - lastBottomOverhead)

    let accent = context.theme.quoteAccentColor
    if isPull {
        // Content-hugging centered pill (behind text) + top-left / bottom-right corner marks.
        let markSize = CGSize(width: 12.0, height: 10.0)
        let markInset: CGFloat = 6.0
        // Content-hugging: track the widest wrapped line. `bodySize.width` is the full bounding
        // width for centered text (layoutTextItem only shrinks to content width for `.natural`),
        // so it must NOT drive the pill — else the pill spans the whole column instead of hugging.
        let contentWidth = bodyTextItem?.lines.map { $0.frame.width }.max() ?? bodySize.width
        // Cap at the inset content width (not the full column), so the widest pill spans
        // [horizontalInset, boundingWidth - horizontalInset] — the same side insets that the
        // regular block-quote frame respects (see the `else` branch below).
        let pillWidth = min(contentWidth + pullQuotePadding * 2.0, boundingWidth - horizontalInset * 2.0)
        let pillX = (boundingWidth - pillWidth) / 2.0
        let pill = InstantPageV2ShapeItem(
            frame: CGRect(x: pillX, y: 0.0, width: pillWidth, height: contentHeight),
            kind: .roundedRect(cornerRadius: 6.0),
            color: accent.withAlphaComponent(0.10))
        result.insert(.shape(pill), at: 0)
        result.append(.imageOrnament(InstantPageV2ImageOrnamentItem(
            frame: CGRect(x: pillX + markInset, y: markInset, width: markSize.width, height: markSize.height),
            imageName: "RichText/QuoteOpen", color: accent, rotated: false)))
        result.append(.imageOrnament(InstantPageV2ImageOrnamentItem(
            frame: CGRect(x: pillX + pillWidth - markInset - markSize.width, y: quoteRegionBottom - markInset - markSize.height,
                          width: markSize.width, height: markSize.height),
            imageName: "RichText/QuoteClose", color: accent, rotated: false)))
    } else {
        // Accent bar + accent-tinted rounded fill spanning the whole quote band (behind the text).
        // Never collapsible: this function serves `.pullQuote`, which carries no `collapsed` in the
        // model. Every `.blockQuote` — including a single-paragraph one — goes through
        // `layoutBlockQuote`, which is where the collapse budget lives.
        let frameItem = InstantPageV2QuoteFrameItem(
            frame: CGRect(x: horizontalInset, y: 0.0, width: boundingWidth - horizontalInset * 2.0, height: contentHeight),
            accentColor: accent, barWidth: instantPageV2QuoteBarWidth, cornerRadius: 6.0, fillAlpha: 0.10, barOnTrailing: context.rtl,
            collapseState: .notCollapsible, path: [])
        result.insert(.quoteFrame(frameItem), at: 0)
        result.append(instantPageV2BlockQuoteIcon(boundingWidth: boundingWidth, horizontalInset: horizontalInset, color: accent, rtl: context.rtl))
    }

    bumpQuoteDepth(result)

    return result
}

// MARK: - List layout (ported from V1 InstantPageLayout.swift lines 365–516)

/// Extra textward nudge for an ORDERED list's item content, on top of the shared
/// `instantPageListItemTextwardOffset` that every list gets.
///
/// V2-only, and deliberately not in the shared constants file: V1 places its numbers through a
/// different path with its own marker metrics, so shifting the item content there without the
/// matching marker nudge below would pull its numbered lists out of alignment.
let instantPageV2NumberedListItemTextwardOffset: CGFloat = 1.0

/// Textward nudge for a number marker within its column — the partner of the item offset above.
/// Applied to the marker's whole (full-column) frame, so it moves the right-aligned digits with it.
let instantPageV2NumberMarkerTextwardOffset: CGFloat = 5.0

private func layoutList(
    _ listItems: [InstantPageListItem],
    ordered: Bool,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    kind: BlockSequenceKind,
    pathPrefix: [Int] = [],
    context: inout LayoutContext
) -> [InstantPageV2LaidOutItem] {
    // A list item's sub-blocks lay out against a band of their own (`layoutBlock` with
    // `horizontalInset: 0`), reached WITHOUT going through `layoutBlockSequence` — so the reset
    // that function performs never runs for them and has to happen here. Conservative for this
    // cycle: a full-bleed child stays in its content column rather than bleeding under the marker
    // gutter. Restored on exit.
    let savedChildBleed = context.childBleed
    defer { context.childBleed = savedChildBleed }
    context.childBleed = .none

    // Determine marker characteristics.
    var maxIndexWidth: CGFloat = 0.0
    // hasNums: at least one ordered item carries an explicit `num` — in which case items
    // without one fall back to a blank " " (preserves the source's numbering gaps) rather
    // than auto-generated `(i + 1).`. Unordered lists never auto-generate numbers, so this
    // flag is only meaningful when `ordered` is true. (`hasTaskMarkers` is no longer derived
    // — the uniform 8pt gap below replaced the per-list `indexSpacing` ternary that consumed
    // it; column right-alignment handles mixed bullet/checkbox lists without flagging.)
    var hasNums = false
    if ordered {
        for item in listItems {
            if item.checked == nil, let num = item.num, !num.isEmpty {
                hasNums = true
                break
            }
        }
    }

    // Build per-item marker descriptors and measure their natural widths.
    let checklistMarkerSize = context.metrics.checklistMarkerSize

    let checkboxColors = InstantPageV2CheckboxColors(
        background: context.theme.panelAccentColor,
        stroke: context.theme.pageBackgroundColor,
        border: context.theme.tableBorderColor
    )
    // Track maxIndexWidth for ALL marker kinds (ordered + unordered, all three shapes), not
    // just ordered as V1/older V2 did. With every kind contributing to the marker column width
    // we can right-align every marker to a single shared column edge — so in a mixed unordered
    // list (bullets + checkboxes) both right-align flush to the same x, and the same uniform
    // gap separates them from the text. The column width simply equals the widest marker; for
    // a pure bullet list `maxIndexWidth == 6` and the bullet sits at `horizontalInset` (visually
    // identical to the pre-change formula), and for a pure checkbox list `maxIndexWidth == 18`
    // matches the previous left-aligned placement too.
    var markerKinds: [InstantPageV2ListMarkerKind] = []
    for (i, item) in listItems.enumerated() {
        if let checked = item.checked {
            maxIndexWidth = max(maxIndexWidth, checklistMarkerSize.width)
            markerKinds.append(.checklist(checked: checked, colors: checkboxColors))
        } else if ordered {
            let value: String
            if hasNums {
                if let num = item.num {
                    value = "\(num)."
                } else {
                    value = " "
                }
            } else {
                value = "\(i + 1)."
            }
            // Measure using a UILabel to get the expected label width.
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: context.theme, category: .paragraph, link: false)
            // A number leading a bold item is bold too, so the marker reads as part of its line.
            // This must happen BEFORE the measure below: bold digits are wider, and since the
            // marker carries the string it was measured with, weight and column width stay in step.
            if let leading = instantPageV2LeadingRichText(of: item),
               instantPageV2FirstCharacterIsBold(leading) == true {
                styleStack.push(.bold)
            }
            let attrStr = attributedStringForRichText(.plain(value), styleStack: styleStack, formatDate: context.formatDate)
            let (textItem, _, _) = layoutTextItem(
                attrStr,
                boundingWidth: boundingWidth - horizontalInset * 2.0,
                offset: .zero,
                fitToWidth: context.fitToWidth,
                computeRevealCharacterRects: context.computeRevealCharacterRects
            )
            let w: CGFloat
            if let textItem = textItem, let firstLine = textItem.lines.first {
                w = firstLine.frame.width
            } else {
                w = 0.0
            }
            maxIndexWidth = max(maxIndexWidth, w)
            // Hand the renderer the very string that was just measured, so drawn width and measured
            // column width cannot disagree.
            markerKinds.append(.number(attrStr, alignment: context.rtl ? .left : .right))
        } else {
            // Bullet: a round dot (matches V1's InstantPageShapeItem ellipse).
            maxIndexWidth = max(maxIndexWidth, context.metrics.bulletDiameter)
            markerKinds.append(.bullet)
        }
    }

    // Uniform 8pt marker→text gap across all four cases (ordered/unordered × bullet/number/
    // checkbox). With markers right-aligned to a shared column of width `maxIndexWidth`, text
    // starts at `horizontalInset + maxIndexWidth + indexSpacing` — so `indexSpacing` IS the
    // gap, regardless of marker shape. V1 used 12/16/20/24 (a mix of marker-area-width and
    // gap-after-marker, depending on alignment); the four gaps came out to 12/16/14/6 — far
    // from uniform, and a 14pt bullet gap looked especially loose. 8pt is a standard iOS list
    // gap; it tightens bullets (14→8), numbers (12→8) and ordered-checkbox (16→8), and only
    // loosens unordered-checkbox very slightly (6→8) so all four kinds match.
    let indexSpacing = context.metrics.listIndexSpacing

    // Gutter from the page inset to the item content: the marker column, the marker→text gap, and
    // the item's own textward nudge. Every content-column read below goes through this one value so
    // the origin and the width can't drift apart.
    // Ordered lists carry an extra nudge (see `instantPageV2NumberedListItemTextwardOffset`). Note
    // this keys on `ordered`, not on "the markers are digits", so an ordered CHECKLIST gets it too —
    // its items stay aligned with a sibling numbered list rather than with an unordered one.
    let contentGutter = indexSpacing + maxIndexWidth + context.metrics.listItemTextwardOffset
        + (ordered ? instantPageV2NumberedListItemTextwardOffset : 0.0)

    // Inter-item spacing comes from `spacingBetweenBlocks` — see the loop below. It replaced a
    // font-derived gap that reproduced body text's baseline rhythm; list spacing now follows the
    // one block-spacing model and is tuned there, not here.

    // Layout each item.
    var result: [InstantPageV2LaidOutItem] = []
    var contentHeight: CGFloat = 0.0

    for (i, item) in listItems.enumerated() {
        // Inter-item spacing: exactly the `spacingBetweenBlocks` that separates any other pair of
        // adjacent blocks, applied to the previous item's last block and this item's first.
        if i != 0 {
            contentHeight += spacingBetweenBlocks(
                upper: instantPageV2ListItemSpacingBlocks(listItems[i - 1]).last,
                lower: instantPageV2ListItemSpacingBlocks(item).first,
                kind: .list,
                metrics: context.metrics
            )
        }

        let markerKind = markerKinds[i]

        // Path to this list item (root→item), stamped onto checkbox markers only. Matches
        // InstantPage.togglingCheckbox path semantics: list items are addressed by item index
        // appended to the list block's own prefix.
        //
        // INVARIANT: `pathPrefix` is an absolute-from-root path only because every
        // `layoutBlockSequence` call that can reach a list is entered from the page root with a
        // correct prefix (top-level, details body, blockquote children, nested list-item blocks).
        // The only OTHER `layoutBlockSequence` call sites — table cells (`kind == .cell`, layout
        // hard-codes `[.paragraph]`) and the details title — contain no lists today, so no
        // checkbox marker is produced there. The `kind != .cell` guard is belt-and-suspenders: if
        // cells ever gain list content, their checkboxes stay non-interactive rather than
        // misrouting an edit to a colliding top-level path.
        let itemCheckboxPath: [Int]? = (item.checked != nil && kind != .cell) ? (pathPrefix + [i]) : nil

        // Effective item: an empty item — an empty `.blocks`, or a `.text` with no textual content
        // — is rendered as a single space so it still occupies a full text line. This matches the
        // height an empty whitespace line of regular paragraph text would take, instead of
        // collapsing to zero height (`layoutTextItem` returns a zero-height box for an empty string).
        var effectiveItem = item
        if case let .blocks(blocks, num, checked) = effectiveItem, blocks.isEmpty {
            effectiveItem = .text(.plain(" "), num, checked)
        } else if case let .text(text, num, checked) = effectiveItem, text.plainText.isEmpty {
            effectiveItem = .text(.plain(" "), num, checked)
        }

        // Derive the markdown marker string and checked state from the original item.
        let markdownMarker: String
        switch markerKind {
        case let .number(string, _): markdownMarker = string.string
        default: markdownMarker = "-"
        }
        let markdownChecked: Bool? = item.checked

        switch effectiveItem {
        case let .text(text, _, _):
            // Layout text content.
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: context.theme, category: .paragraph, link: false)
            let attrStr = attributedStringForRichText(text, styleStack: styleStack, formatDate: context.formatDate)
            let textX = instantPageV2ContentColumnX(horizontalInset: horizontalInset, gutter: contentGutter, rtl: context.rtl)
            let textWidth = boundingWidth - horizontalInset * 2.0 - contentGutter
            let (textItem, textLaidOutItems, textSize) = layoutTextItem(
                attrStr,
                boundingWidth: textWidth,
                alignment: context.rtl ? .right : .natural,
                offset: CGPoint(x: textX, y: contentHeight),
                fitToWidth: context.fitToWidth,
                computeRevealCharacterRects: context.computeRevealCharacterRects
            )

            // Compute marker vertical position: align to mid of first text line.
            var lineMidY: CGFloat = contentHeight
            if let textItem = textItem {
                if let firstLine = textItem.lines.first {
                    lineMidY = textItem.frame.minY + firstLine.frame.midY
                } else {
                    lineMidY = textItem.frame.midY
                }
            }

            // Compute marker frame.
            let markerFrame = markerFrameFor(
                kind: markerKind,
                maxIndexWidth: maxIndexWidth,
                horizontalInset: horizontalInset,
                checklistMarkerSize: checklistMarkerSize,
                bulletDiameter: context.metrics.bulletDiameter,
                numberMarkerTextwardOffset: context.metrics.numberMarkerTextwardOffset,
                lineMidY: lineMidY,
                rtl: context.rtl,
                boundingWidth: boundingWidth
            )

            result.append(.listMarker(InstantPageV2ListMarkerItem(
                frame: markerFrame,
                kind: markerKind,
                color: context.theme.textCategories.paragraph.color,
                checkboxPath: itemCheckboxPath
            )))
            stampMarkdownContext(textLaidOutItems, kind: .listItem(ordered: ordered, marker: markdownMarker, checked: markdownChecked))
            result.append(contentsOf: textLaidOutItems)
            contentHeight += textSize.height

        case let .blocks(blocks, _, _):
            // Nested block content (e.g. sub-list, paragraphs).
            var previousBlock: InstantPageBlock?
            let originY = contentHeight
            var firstBlockLineMidY: CGFloat?

            for (j, subBlock) in blocks.enumerated() {
                let subItems = layoutBlock(
                    subBlock,
                    boundingWidth: boundingWidth - horizontalInset * 2.0 - contentGutter,
                    horizontalInset: 0.0,
                    kind: kind,
                    isCover: false,
                    previousItems: result,
                    isLast: j == blocks.count - 1,
                    pathPrefix: pathPrefix + [i, j],
                    context: &context
                )
                let subLocalMaxY: CGFloat = subItems.map { $0.frame.maxY }.max() ?? 0.0
                let spacing: CGFloat = (previousBlock != nil && subLocalMaxY > 0.0) ? spacingBetweenBlocks(upper: previousBlock, lower: subBlock, kind: .list, metrics: context.metrics) : 0.0
                let offsetX = instantPageV2ContentColumnX(horizontalInset: horizontalInset, gutter: contentGutter, rtl: context.rtl)
                let offsetY = contentHeight + spacing
                let translatedItems = subItems.map { $0.offsetBy(CGPoint(x: offsetX, y: offsetY)) }

                if firstBlockLineMidY == nil {
                    // Find the mid-Y of the first text line in the first block.
                    for translated in translatedItems {
                        if case let .text(tv) = translated {
                            if let firstLine = tv.textItem.lines.first {
                                firstBlockLineMidY = tv.frame.minY + firstLine.frame.midY
                            } else {
                                firstBlockLineMidY = tv.frame.midY
                            }
                            break
                        }
                    }
                }

                // Compute block height contribution.
                // offsetY = contentHeight + spacing, so blockMaxY already accounts for spacing.
                var blockMaxY: CGFloat = offsetY
                for ti in translatedItems {
                    blockMaxY = max(blockMaxY, ti.frame.maxY)
                }

                // Nil-guard in stampMarkdownContext preserves any richer kind (e.g. .heading)
                // already stamped by a child block's own layout. So a heading nested inside a
                // .blocks list item keeps .heading, not .listItem — multi-block list items are
                // a documented best-effort case for markdown reconstruction.
                stampMarkdownContext(translatedItems, kind: .listItem(ordered: ordered, marker: markdownMarker, checked: markdownChecked))
                result.append(contentsOf: translatedItems)
                contentHeight = blockMaxY
                previousBlock = subBlock
            }

            // Mirror the .text case above (and what .checklist already does here): use the
            // first text line's midY for centering. `originY` is the sub-block's TOP, NOT a
            // line midpoint — `markerFrameFor` then subtracts `size.height / 2`, so feeding
            // `originY` placed the marker straddling the sub-block boundary, ½·marker-height
            // ABOVE the first text line. V1 hid the same arithmetic under a 6×12 shape with a
            // 3pt internal offset (matching ½·fontLineHeight for 17pt paragraph text), which
            // by coincidence equals `firstBlockLineMidY`. Using firstBlockLineMidY directly
            // makes the alignment explicit, unifies the three marker kinds, and matches the
            // .text case exactly. Fallback to `originY` when no text is in the first sub-block
            // (image-first lists are rare); mirrors the existing .checklist fallback.
            let markerLineMidY: CGFloat = firstBlockLineMidY ?? originY
            let markerFrame = markerFrameFor(
                kind: markerKind,
                maxIndexWidth: maxIndexWidth,
                horizontalInset: horizontalInset,
                checklistMarkerSize: checklistMarkerSize,
                bulletDiameter: context.metrics.bulletDiameter,
                numberMarkerTextwardOffset: context.metrics.numberMarkerTextwardOffset,
                lineMidY: markerLineMidY,
                rtl: context.rtl,
                boundingWidth: boundingWidth
            )

            result.append(.listMarker(InstantPageV2ListMarkerItem(
                frame: markerFrame,
                kind: markerKind,
                color: context.theme.textCategories.paragraph.color,
                checkboxPath: itemCheckboxPath
            )))

        default:
            break
        }
    }

    return result
}

/// Computes the frame for a list marker, handling RTL and all three marker kinds.
///
/// Bullets and checkboxes are drawn at their own size, right-aligned within the shared
/// `[horizontalInset, horizontalInset + maxIndexWidth]` column (LTR) or left-aligned within the
/// mirrored column on the right (RTL), so mixed unordered lists align flush at the column's inner edge.
///
/// A NUMBER instead takes the WHOLE column as its frame and is aligned by the text system inside it
/// (`InstantPageV2ListMarkerKind.number` carries the alignment). Sizing each number's box to its own
/// glyph width and relying on frame arithmetic to line the boxes up only works while the measured
/// width matches the drawn one — which is exactly the coupling that broke when the renderer drew the
/// digits in a hardcoded font. A shared box makes "the dots line up" a property of one alignment
/// setting rather than of two measurements agreeing.
private func markerFrameFor(
    kind: InstantPageV2ListMarkerKind,
    maxIndexWidth: CGFloat,
    horizontalInset: CGFloat,
    checklistMarkerSize: CGSize,
    // Scaled copies of the InstantPageShapeItem globals / the V2 number nudge. Passed in rather
    // than read from the globals here, the way the sizes above already are, because this helper
    // has no LayoutContext and a global read cannot know it is inside a quote.
    bulletDiameter: CGFloat,
    numberMarkerTextwardOffset: CGFloat,
    lineMidY: CGFloat,
    rtl: Bool,
    boundingWidth: CGFloat
) -> CGRect {
    let size: CGSize
    // Only the bullet takes the optical nudges — below the line midpoint, and toward its item's
    // text. Numbers and checkboxes stay put, so both offsets are selected here rather than applied
    // to the shared return. `textwardOffset` is signed by direction, not by axis: the marker column
    // is mirrored onto the trailing edge in RTL, so moving toward the text means moving LEFT there.
    let verticalOffset: CGFloat
    let textwardOffset: CGFloat
    switch kind {
    case .bullet:
        size = CGSize(width: bulletDiameter, height: bulletDiameter)
        verticalOffset = instantPageBulletMarkerVerticalOffset
        textwardOffset = instantPageBulletMarkerTextwardOffset
    case .number:
        // The full marker column — alignment inside it is the renderer's job. The height is a
        // container for already-scaled digits that the renderer centres, not a body-font-tuned
        // size, so it is deliberately NOT a metric: scaling it would move nothing visible.
        size = CGSize(width: maxIndexWidth, height: 20.0)
        verticalOffset = 0.0
        textwardOffset = numberMarkerTextwardOffset
    case .checklist:
        size = checklistMarkerSize
        verticalOffset = 0.0
        textwardOffset = 0.0
    }
    let x: CGFloat
    if rtl {
        x = boundingWidth - horizontalInset - maxIndexWidth - textwardOffset
    } else {
        x = horizontalInset + maxIndexWidth - size.width + textwardOffset
    }
    return CGRect(x: x, y: floorToScreenPixels(lineMidY - size.height / 2.0 + verticalOffset), width: size.width, height: size.height)
}

/// Leading/trailing geometry helpers — the single source of truth for "which side is the
/// block gutter on", gated on the page's explicit `rtl` flag. The `rtl == false` branch returns
/// the pre-existing literal so non-RTL pages are byte-identical.

/// X origin of a block's content column, given a leading gutter of width `gutter`
/// (the marker column, or the quote bar+inset band). Column width is unchanged either way.
///   LTR: content sits after the gutter        → horizontalInset + gutter
///   RTL: content sits at the inset; the gutter is mirrored onto the trailing edge → horizontalInset
func instantPageV2ContentColumnX(horizontalInset: CGFloat, gutter: CGFloat, rtl: Bool) -> CGFloat {
    return rtl ? horizontalInset : horizontalInset + gutter
}

/// X origin of a leading-edge element of width `elementWidth` (e.g. the quote bar), hugging the
/// trailing edge of the gutter band in RTL.
///   LTR: horizontalInset
///   RTL: boundingWidth - horizontalInset - elementWidth
func instantPageV2LeadingEdgeX(boundingWidth: CGFloat, horizontalInset: CGFloat, elementWidth: CGFloat, rtl: Bool) -> CGFloat {
    return rtl ? (boundingWidth - horizontalInset - elementWidth) : horizontalInset
}

// MARK: - Style helpers (ported from V1 InstantPageLayout.swift lines 32–88)

private func setupStyleStack(_ stack: InstantPageTextStyleStack, theme: InstantPageTheme, attributes: InstantPageTextAttributes) {
    stack.push(.textColor(attributes.color))
    stack.push(.markerColor(theme.markerColor))
    stack.push(.linkColor(theme.linkColor))
    stack.push(.linkMarkerColor(theme.linkHighlightColor))
    switch attributes.font.style {
    case .sans:
        stack.push(.fontSerif(false))
    case .serif:
        stack.push(.fontSerif(true))
    case .monospace:
        stack.push(.fontFixed(true))
    }
    switch attributes.font.weight {
    case .regular:
        break
    case .medium:
        stack.push(.medium)
    case .semibold:
        stack.push(.semibold)
    }
    stack.push(.fontSize(attributes.font.size))
    stack.push(.lineSpacingFactor(attributes.font.lineSpacingFactor))
    if attributes.underline {
        stack.push(.underline)
    }
}

private func setupStyleStack(_ stack: InstantPageTextStyleStack, theme: InstantPageTheme, category: InstantPageTextCategoryType, link: Bool) {
    let attributes = theme.textCategories.attributes(type: category, link: link)
    setupStyleStack(stack, theme: theme, attributes: attributes)
    switch category {
    case .caption, .credit:
        // Caption-family links read as their own text rather than as accent. The underline is NOT
        // applied here: `InstantPageTextStyleStack.textAttributes()` underlines a link whose colour
        // equals the surrounding text colour, so setting the colour is what produces both.
        //
        // LOAD-BEARING: the text colour and the link colour must come from this ONE `attributes`
        // value. Source them from two separate reads and a later tweak to either one desynchronises
        // them — at which point the underline silently disappears with no other symptom.
        //
        // The push must come AFTER `setupStyleStack`, which pushes `theme.linkColor` itself: the
        // stack resolves by scanning pushes in reverse and taking the first hit, so the last push wins.
        stack.push(.linkColor(attributes.color))
    case .kicker, .header, .subheader, .paragraph, .table, .article, .codeBlock:
        break
    }
}

private func instantPageFont(style: InstantPageTextAttributes, bold: Bool = false, italic: Bool = false, fixed: Bool = false) -> UIFont {
    let size = style.font.size
    if fixed {
        if bold && italic {
            return UIFont(name: "Menlo-BoldItalic", size: size) ?? Font.semiboldItalic(size)
        } else if bold {
            return UIFont(name: "Menlo-Bold", size: size) ?? Font.bold(size)
        } else if italic {
            return UIFont(name: "Menlo-Italic", size: size) ?? Font.italic(size)
        } else {
            return UIFont(name: "Menlo", size: size) ?? Font.regular(size)
        }
    }
    switch style.font.style {
    case .serif:
        if bold && italic {
            return UIFont(name: "Georgia-BoldItalic", size: size) ?? Font.semiboldItalic(size)
        } else if bold {
            return UIFont(name: "Georgia-Bold", size: size) ?? Font.bold(size)
        } else if italic {
            return UIFont(name: "Georgia-Italic", size: size) ?? Font.italic(size)
        } else {
            return UIFont(name: "Georgia", size: size) ?? Font.regular(size)
        }
    case .sans:
        if bold && italic {
            return Font.semiboldItalic(size)
        } else if bold {
            return Font.bold(size)
        } else if italic {
            return Font.italic(size)
        } else {
            return Font.regular(size)
        }
    case .monospace:
        if bold && italic {
            return Font.semiboldItalicMonospace(size)
        } else if bold {
            return Font.semiboldMonospace(size)
        } else if italic {
            return Font.italicMonospace(size)
        } else {
            return Font.monospace(size)
        }
    }
}

// MARK: - V2 text-item layout (ported from V1 InstantPageTextItem.swift layoutTextItemWithString)
//
// V0 difference from V1:
//   * Inline image runs are NOT emitted as items here. They are discovered at view-update time
//     by `InstantPageV2View.updateInlineImages()`, which walks each text view's `line.imageItems`
//     and creates `InstantPageV2InlineImageView`s attached to the text view's `imageContainerView`
//     (the pop-in animation mirrors the inline custom-emoji ownership model).
//   * Inline formula runs produce `.formula(InstantPageV2FormulaItem(...))` items carrying the
//     rendered math image (see `InstantPageV2FormulaView`); the line's `formulaItems` field
//     already provides the attachment + frame.
//   * No `InstantPageScrollableTextItem` wrapping: even if `requiresScroll` would be true in V1,
//     V2 takes the non-scroll path (text item kept flat; long preformatted lines simply clip
//     outside the bubble width). Deferred to a future iteration.

// Internal helpers ported from V1 InstantPageTextItem.swift (declared private there; copied here).
// `internal` (not private) so that InstantPageRenderer.swift can call them from the same module.
func v2FrameForLine(_ line: InstantPageTextLine, boundingWidth: CGFloat, alignment: NSTextAlignment) -> CGRect {
    var lineFrame = line.frame
    if alignment == .center {
        lineFrame.origin.x = floor((boundingWidth - lineFrame.size.width) / 2.0)
    } else if alignment == .right || (alignment == .natural && line.isRTL) {
        lineFrame.origin.x = boundingWidth - lineFrame.size.width
    }
    return lineFrame
}

// Returns the leading-edge x offset (line-origin-relative) for an inline-attachment's string
// `range`, correct for both LTR and RTL runs. `CTLineGetOffsetForStringIndex` at the start index
// gives the glyph's LEFT edge in LTR text, but its RIGHT edge in RTL text (increasing string index
// moves leftward) — so using the start-index offset alone as the left edge shoves an RTL attachment
// ~one advance too far right. Taking the min of the start- and end-index offsets yields the true
// leading (left) edge in both directions. Mirrors `Display.TextNode`'s `addEmbeddedItem`, including
// the directional-boundary secondary-offset handling. For a pure-LTR line this returns exactly the
// start-index offset (primary == secondary, and start-offset < end-offset), so LTR layout is
// byte-identical to the previous single-offset behavior.
/// Module-internal (not `private`) so the button-label geometry in `InstantPageInlineButton.swift`
/// can reuse it. A bare `CTLineGetOffsetForStringIndex` returns the glyph's RIGHT edge on an RTL
/// line, which shifts an attachment by roughly one advance.
func v2LeadingOffsetForRange(_ line: CTLine, range: NSRange) -> CGFloat {
    var secondaryStartOffset: CGFloat = 0.0
    let rawStartOffset = CTLineGetOffsetForStringIndex(line, range.location, &secondaryStartOffset)
    var startOffset = rawStartOffset
    if !rawStartOffset.isEqual(to: secondaryStartOffset) {
        startOffset = secondaryStartOffset
    }

    var secondaryEndOffset: CGFloat = 0.0
    let rawEndOffset = CTLineGetOffsetForStringIndex(line, range.location + range.length, &secondaryEndOffset)
    var endOffset = rawEndOffset
    if !rawEndOffset.isEqual(to: secondaryEndOffset) {
        endOffset = secondaryEndOffset
    }

    return min(startOffset, endOffset)
}

private func v2LocalAttachmentBoundsForRange(_ range: NSRange, imageItems: [InstantPageTextImageItem], formulaItems: [InstantPageTextFormulaRun], buttonItems: [InstantPageTextButtonRun] = []) -> CGRect? {
    var result: CGRect?

    for imageItem in imageItems {
        if NSIntersectionRange(range, imageItem.range).length != 0 {
            if let current = result {
                result = current.union(imageItem.frame)
            } else {
                result = imageItem.frame
            }
        }
    }

    for formulaItem in formulaItems {
        if NSIntersectionRange(range, formulaItem.range).length != 0 {
            if let current = result {
                result = current.union(formulaItem.frame)
            } else {
                result = formulaItem.frame
            }
        }
    }

    for buttonItem in buttonItems {
        if NSIntersectionRange(range, buttonItem.range).length != 0 {
            if let current = result {
                result = current.union(buttonItem.frame)
            } else {
                result = buttonItem.frame
            }
        }
    }

    return result
}

private struct PendingV2ImageAttachment {
    let xOffset: CGFloat
    let range: NSRange
    let id: Int64
    let size: CGSize
}

private struct PendingV2FormulaAttachment {
    let xOffset: CGFloat
    let range: NSRange
    let attachment: InstantPageMathAttachment
    let baselineOffset: CGFloat
}

private struct PendingV2ButtonAttachment {
    let xOffset: CGFloat
    let range: NSRange
    let attachment: InstantPageInlineButtonAttachment
    let baselineOffset: CGFloat
}

private struct PendingV2EmojiAttachment {
    let xOffset: CGFloat
    let range: NSRange
    let emoji: ChatTextInputTextCustomEmojiAttribute
    let size: CGFloat
}

/// A list item's content expressed as blocks, so the gap between two items can be decided by the
/// same `spacingBetweenBlocks` as any other adjacent pair: a `.text` item is the paragraph it
/// renders as, a `.blocks` item contributes its own outermost blocks (its last faces the next
/// item, its first faces the previous one).
///
/// This replaced `instantPageV2ListItemGap`, which derived the gap from the paragraph font so that
/// successive items followed body text's baseline rhythm. That is no longer wanted — list spacing
/// is now one more consumer of the block-spacing model and is tuned there.
///
/// An empty `.blocks` and `.unknown` map to an empty paragraph, matching how `layoutList`
/// normalises an empty item into a single-space `.text` for rendering.
/// Whether the FIRST rendered character of `text` is bold.
///
/// Returns `nil` when the subtree renders no character at all, which is what lets `.concat` skip
/// empty leading runs and ask the next one instead of answering `false` for `["", **bold**]`.
///
/// `bold` is threaded down rather than read off a leaf, because emphasis in `RichText` is a WRAPPER
/// node: a leaf's weight is a property of what encloses it, not of the leaf.
private func instantPageV2FirstCharacterIsBold(_ text: RichText, inheritingBold bold: Bool = false) -> Bool? {
    switch text {
    case .empty:
        return nil
    case let .plain(string):
        return string.isEmpty ? nil : bold
    case let .bold(inner):
        return instantPageV2FirstCharacterIsBold(inner, inheritingBold: true)
    // Wrappers that carry emphasis or entity meaning but not weight — recurse keeping what we inherited.
    case let .italic(inner), let .underline(inner), let .strikethrough(inner), let .fixed(inner),
         let .superscript(inner), let .marked(inner), let .textAutoEmail(inner),
         let .textAutoPhone(inner), let .textAutoUrl(inner), let .textBankCard(inner), let .textTonAddress(inner),
         let .textBotCommand(inner), let .textCashtag(inner), let .textHashtag(inner),
         let .textMention(inner), let .textSpoiler(inner):
        return instantPageV2FirstCharacterIsBold(inner, inheritingBold: bold)
    case let .`subscript`(inner):
        return instantPageV2FirstCharacterIsBold(inner, inheritingBold: bold)
    case let .url(inner, _, _), let .textDate(inner, _, _):
        return instantPageV2FirstCharacterIsBold(inner, inheritingBold: bold)
    case let .email(inner, _), let .phone(inner, _), let .anchor(inner, _), let .textMentionName(inner, _):
        return instantPageV2FirstCharacterIsBold(inner, inheritingBold: bold)
    case let .concat(texts):
        for inner in texts {
            if let result = instantPageV2FirstCharacterIsBold(inner, inheritingBold: bold) {
                return result
            }
        }
        return nil
    // Atoms occupy a character position but have no weight of their own, so they answer with the
    // emphasis they are wrapped in.
    case .image, .formula, .textCustomEmoji, .textButton:
        return bold
    }
}

/// The rich text a list item leads with — the run whose weight the number marker should match.
/// `nil` when the item leads with something that is not text (so the marker keeps its normal weight).
private func instantPageV2LeadingRichText(of item: InstantPageListItem) -> RichText? {
    switch item {
    case let .text(text, _, _):
        return text
    case let .blocks(blocks, _, _):
        switch blocks.first {
        case let .paragraph(text):
            return text
        case let .heading(text, _):
            return text
        default:
            return nil
        }
    case .unknown:
        return nil
    }
}

private func instantPageV2ListItemSpacingBlocks(_ item: InstantPageListItem) -> (first: InstantPageBlock, last: InstantPageBlock) {
    switch item {
    case let .text(text, _, _):
        return (.paragraph(text), .paragraph(text))
    case let .blocks(blocks, _, _):
        guard let first = blocks.first, let last = blocks.last else {
            return (.paragraph(.empty), .paragraph(.empty))
        }
        return (first, last)
    case .unknown:
        return (.paragraph(.empty), .paragraph(.empty))
    }
}

func layoutTextItem(
    _ string: NSAttributedString,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat = 0.0,
    alignment: NSTextAlignment = .natural,
    offset: CGPoint,
    minimizeWidth: Bool = false,
    fitToWidth: Bool = false,
    maxNumberOfLines: Int = 0,
    opaqueBackground: Bool = false,
    computeRevealCharacterRects: Bool = false
) -> (InstantPageTextItem?, [InstantPageV2LaidOutItem], CGSize) {
    if string.length == 0 {
        return (nil, [], CGSize())
    }

    var lines: [InstantPageTextLine] = []
    var imageItems: [InstantPageTextImageItem] = []
    var hasFormulaItems: Bool = false
    var font = string.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) as? UIFont
    if font == nil {
        let range = NSMakeRange(0, string.length)
        string.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            if font == nil, let furtherFont = attributes[NSAttributedString.Key.font] as? UIFont {
                font = furtherFont
            }
        }
    }
    let image = string.attribute(NSAttributedString.Key.init(rawValue: InstantPageMediaIdAttribute), at: 0, effectiveRange: nil)
    let formula = string.attribute(NSAttributedString.Key(rawValue: InstantPageFormulaAttribute), at: 0, effectiveRange: nil)
    guard font != nil || image != nil || formula != nil else {
        return (nil, [], CGSize())
    }

    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(NSAttributedString.Key(rawValue: InstantPageLineSpacingFactorAttribute), at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }

    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font?.ascender ?? 0.0
    let fontDescent = font?.descender ?? 0.0

    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    let fontDescentBelowBaseline = max(0.0, -fontDescent)
    // True font-height line box: shift the whole line stack down by the ascender headroom above
    // the cap line (A − L) and pad the final height by the descender (D) below the last baseline,
    // so a single-line item measures exactly A + D. Exact (not pixel-snapped): this is an
    // intra-item line offset; crispness rides on the item's own pixel-snapped frame origin, and
    // intra-item line positions may already be fractional (e.g. after a non-integral extraDescent).
    // Inter-line advance is unchanged. (Named `lineBoxTopInset` to avoid colliding with the
    // formula-bleed `topInset` local near the end of this function.)
    let lineBoxTopInset = max(0.0, fontAscent - fontLineHeight)
    let baselineToNextTopSlack = max(0.0, fontLineSpacing - 4.0)

    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint(x: 0.0, y: lineBoxTopInset)

    var hasAnchors = false
    var maxLineWidth: CGFloat = 0.0
    var extraDescent: CGFloat = 0.0
    let text = string.string
    var indexOffset: CFIndex?
    while true {
        var workingLineOrigin = currentLineOrigin

        // An inline pill that BEGINS this line hangs into the page's horizontal inset by its own
        // horizontal padding, so its LABEL — not its background — lines up with the text edge of the
        // surrounding paragraph, like hanging punctuation.
        //
        // Decided HERE, before the break, and it is knowable here: `lastIndex` is already the first
        // character of the line we are about to break, settled by the previous iteration. So this is
        // forward-only — no re-break, no iteration, and it works for a WRAPPED line's leading pill
        // just as well as for a paragraph's first.
        //
        // The hang is added to the break budget so the line reclaims exactly the space it hangs into
        // and its right edge stays flush; it is then subtracted from the line's FRAME (and only from
        // the frame — see the invariant at that site) to place it. Budget and frame MUST agree on the
        // condition: widening the budget for a line that is not then hung would overflow it right by
        // the padding.
        //
        // Gated on `alignment` alone rather than the per-line `isRTL`, which does not exist yet at
        // this point. A centred / right-aligned paragraph has no shared left text edge to align to,
        // and an RTL page arrives here as `.right`, so both are excluded.
        var lineLeadingHang: CGFloat = 0.0
        if alignment != .center, alignment != .right,
           lastIndex < string.length,
           let leadingButton = string.attribute(NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute), at: lastIndex, effectiveRange: nil) as? InstantPageInlineButtonAttachment {
            lineLeadingHang = leadingButton.horizontalPadding
        }

        let currentMaxWidth = boundingWidth - workingLineOrigin.x + lineLeadingHang
        var lineCharacterCount: CFIndex
        var hadIndexOffset = false
        if minimizeWidth {
            var count = 0
            for ch in text.suffix(text.count - lastIndex) {
                count += 1
                if ch == " " || ch == "\n" || ch == "\t" {
                    break
                }
            }
            lineCharacterCount = count
        } else {
            let suggestedLineBreak = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
            if let offset = indexOffset {
                lineCharacterCount = suggestedLineBreak + offset
                if lineCharacterCount <= 0 {
                    lineCharacterCount = suggestedLineBreak
                }
                indexOffset = nil
                hadIndexOffset = true
            } else {
                lineCharacterCount = suggestedLineBreak
            }
        }
        if lineCharacterCount > 0 {
            var line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            var lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let lineRange = NSMakeRange(lastIndex, lineCharacterCount)

            var stop = false
            if maxNumberOfLines > 0 && lines.count == maxNumberOfLines - 1 && lastIndex + lineCharacterCount < string.length {
                let attributes = string.attributes(at: lastIndex + lineCharacterCount - 1, effectiveRange: nil)
                if let truncateString = CFAttributedStringCreate(nil, "\u{2026}" as CFString, attributes as CFDictionary) {
                    let truncateToken = CTLineCreateWithAttributedString(truncateString)
                    let tokenWidth = CGFloat(CTLineGetTypographicBounds(truncateToken, nil, nil, nil) + 3.0)
                    if let truncatedLine = CTLineCreateTruncatedLine(line, Double(lineWidth - tokenWidth), .end, truncateToken) {
                        lineWidth += tokenWidth
                        line = truncatedLine
                    }
                }
                stop = true
            }

            let hadExtraDescent = extraDescent > 0.0
            extraDescent = 0.0
            var lineImageItems: [InstantPageTextImageItem] = []
            var lineFormulaItems: [InstantPageTextFormulaRun] = []
            var pendingImages: [PendingV2ImageAttachment] = []
            var pendingFormulas: [PendingV2FormulaAttachment] = []
            var lineButtonItems: [InstantPageTextButtonRun] = []
            var pendingButtons: [PendingV2ButtonAttachment] = []
            var lineEmojiItems: [InstantPageTextEmojiItem] = []
            var pendingEmoji: [PendingV2EmojiAttachment] = []
            var isRTL = false
            if let glyphRuns = CTLineGetGlyphRuns(line) as? [CTRun], !glyphRuns.isEmpty {
                if let run = glyphRuns.first, CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                    isRTL = true
                }

                for run in glyphRuns {
                    let cfRunRange = CTRunGetStringRange(run)
                    let runRange = NSMakeRange(cfRunRange.location == kCFNotFound ? NSNotFound : cfRunRange.location, cfRunRange.length)
                    string.enumerateAttributes(in: runRange, options: []) { attributes, range, _ in
                        if let id = attributes[NSAttributedString.Key.init(rawValue: InstantPageMediaIdAttribute)] as? Int64, let dimensions = attributes[NSAttributedString.Key.init(rawValue: InstantPageMediaDimensionsAttribute)] as? PixelDimensions {
                            let imageSize = dimensions.cgSize.fitted(CGSize(width: boundingWidth, height: boundingWidth))
                            let xOffset = v2LeadingOffsetForRange(line, range: range)
                            pendingImages.append(PendingV2ImageAttachment(xOffset: xOffset, range: range, id: id, size: imageSize))
                        } else if let attachment = attributes[NSAttributedString.Key(rawValue: InstantPageFormulaAttribute)] as? InstantPageMathAttachment {
                            let xOffset = v2LeadingOffsetForRange(line, range: range)
                            let baselineOffset = (attributes[NSAttributedString.Key.baselineOffset] as? CGFloat) ?? 0.0
                            pendingFormulas.append(PendingV2FormulaAttachment(xOffset: xOffset, range: range, attachment: attachment, baselineOffset: baselineOffset))
                        } else if let attachment = attributes[NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute)] as? InstantPageInlineButtonAttachment {
                            // x MUST come from v2LeadingOffsetForRange: a bare start-index offset
                            // returns the glyph's RIGHT edge on RTL lines, shifting the pill by ~one
                            // advance.
                            let xOffset = v2LeadingOffsetForRange(line, range: range)
                            let baselineOffset = (attributes[NSAttributedString.Key.baselineOffset] as? CGFloat) ?? 0.0
                            pendingButtons.append(PendingV2ButtonAttachment(xOffset: xOffset, range: range, attachment: attachment, baselineOffset: baselineOffset))
                        } else if let emoji = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                            let xOffset = v2LeadingOffsetForRange(line, range: range)
                            let font = (attributes[NSAttributedString.Key.font] as? UIFont) ?? UIFont.systemFont(ofSize: 17.0)
                            // Size the inline emoji to the font's line height (A + D = the true
                            // line-box height) plus a 4pt bump at the 17pt body font (scaled
                            // proportionally) so it reads a touch larger than the bare line box.
                            // The line is NOT inflated (lineAscent stays fontLineHeight). Must match
                            // the run-delegate width in attributedStringForRichText (InstantPageTextItem.swift).
                            //
                            // The drawn square is derived from the FONT here, never from the run
                            // delegate — the delegate only supplies the advance — so a caller wanting
                            // a different size must set BOTH, and the size travels on
                            // `InstantPageEmojiSizeAttribute`. Button labels use it: a body-sized
                            // emoji (24.29pt at 17pt) is taller than the chat bubble's whole 22pt row
                            // and would overlap the lines above and below.
                            let itemSize: CGFloat
                            if let explicitSize = attributes[NSAttributedString.Key(rawValue: InstantPageEmojiSizeAttribute)] as? NSNumber {
                                itemSize = CGFloat(explicitSize.doubleValue)
                            } else {
                                itemSize = font.ascender - font.descender + 4.0 * font.pointSize / 17.0
                            }
                            pendingEmoji.append(PendingV2EmojiAttachment(xOffset: xOffset, range: range, emoji: emoji, size: itemSize))
                        }
                    }
                }
            }

            // Inline emoji and images do NOT inflate the line: they are centered on the font
            // line box and allowed to bleed above/below (mirroring V1 `layoutTextItemWithString`
            // and the chat `InteractiveTextComponent`). Their run delegates already report the
            // font's own ascent/descent, so CoreText lays the line out at the normal height — the
            // old `lineAscent = emoji.size` inflation both doubled the line height and (because the
            // baseline sits at the bottom of the box) shoved the text baseline down. Only formulas,
            // which carry their own typographic metrics, are allowed to grow the line.
            var lineAscent: CGFloat = fontLineHeight
            var lineDescent: CGFloat = fontDescentBelowBaseline
            for formula in pendingFormulas {
                let formulaAscent = formula.attachment.rendered.size.height - formula.attachment.rendered.descent
                if formulaAscent > lineAscent {
                    lineAscent = formulaAscent
                }
                if formula.attachment.rendered.descent > lineDescent {
                    lineDescent = formula.attachment.rendered.descent
                }
            }
            // Buttons may grow the line, but only after consuming the leeway the line already
            // reserves — the same headroom inline formulas bleed into.
            //
            // UNIT MISMATCH TO BEWARE: `lineAscent` starts at `fontLineHeight`, which is the REDUCED
            // box `floor(ascender + descender)` (≈12.4pt at 17pt, since descender is negative), while
            // `attachment.ascent` comes from `CTLineGetTypographicBounds` and is the FULL font ascent
            // (≈16.3pt for a 15pt label + padding). Comparing them directly inflated every
            // button-bearing line by ~4pt even though the pill fits inside the existing headroom.
            //
            // So discount the headroom first: `lineBoxTopInset` above the cap line (the line stack is
            // already shifted down by it) and `baselineToNextTopSlack` below the baseline (the
            // inter-line spacing the following line does not need). Anything beyond that genuinely
            // overflows and does grow the line.
            for button in pendingButtons {
                let effectiveAscent = button.attachment.ascent - lineBoxTopInset
                if effectiveAscent > lineAscent {
                    lineAscent = effectiveAscent
                }
                let effectiveDescent = button.attachment.descent - baselineToNextTopSlack
                if effectiveDescent > lineDescent {
                    lineDescent = effectiveDescent
                }
            }
            let baselineY = workingLineOrigin.y + lineAscent

            for image in pendingImages {
                // Center on the font line box (baseline − fontLineHeight/2), matching V1's
                // `(fontLineHeight - imageHeight) / 2` offset, instead of bottom-aligning on the
                // baseline. Keeps the text baseline put and lets the image bleed symmetrically.
                let imageFrame = CGRect(
                    x: workingLineOrigin.x + image.xOffset,
                    y: floorToScreenPixels(baselineY - fontLineHeight / 2.0 - image.size.height / 2.0),
                    width: image.size.width,
                    height: image.size.height
                )
                lineImageItems.append(InstantPageTextImageItem(frame: imageFrame, range: image.range, id: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: image.id)))
            }
            for formula in pendingFormulas {
                let attachment = formula.attachment
                let formulaAscent = attachment.rendered.size.height - attachment.rendered.descent
                let formulaFrame = CGRect(
                    x: workingLineOrigin.x + formula.xOffset,
                    y: baselineY - formulaAscent + formula.baselineOffset,
                    width: attachment.rendered.size.width,
                    height: attachment.rendered.size.height
                )
                lineFormulaItems.append(InstantPageTextFormulaRun(frame: formulaFrame, range: formula.range, attachment: attachment))
            }
            for button in pendingButtons {
                let buttonFrame = CGRect(
                    x: workingLineOrigin.x + button.xOffset,
                    y: baselineY - button.attachment.ascent + button.baselineOffset,
                    width: button.attachment.size.width,
                    height: button.attachment.size.height
                )
                lineButtonItems.append(InstantPageTextButtonRun(frame: buttonFrame, range: button.range, attachment: button.attachment))
            }
            for emoji in pendingEmoji {
                // Center on the font line box (baseline − fontLineHeight/2) so a 24pt emoji on a
                // ~17pt line bleeds symmetrically rather than forcing the line taller and pushing
                // the text baseline down. Matches the chat `InteractiveTextComponent` placement.
                let emojiFrame = CGRect(
                    x: workingLineOrigin.x + emoji.xOffset,
                    y: floorToScreenPixels(baselineY - fontLineHeight / 2.0 - emoji.size / 2.0),
                    width: emoji.size,
                    height: emoji.size
                )
                lineEmojiItems.append(InstantPageTextEmojiItem(frame: emojiFrame, range: emoji.range, emoji: emoji.emoji))
            }

            extraDescent = max(0.0, lineDescent - baselineToNextTopSlack)
            // A centered attachment taller than the line bleeds below the baseline; grow the
            // descent so the following line isn't overlapped (mirrors V1's extraDescent handling).
            // Emoji sized to the font line height (A + D) fit the line box, so they contribute nothing.
            for imageItem in lineImageItems {
                extraDescent = max(extraDescent, imageItem.frame.maxY - (baselineY + baselineToNextTopSlack))
            }
            for emojiItem in lineEmojiItems {
                extraDescent = max(extraDescent, emojiItem.frame.maxY - (baselineY + baselineToNextTopSlack))
            }

            if !minimizeWidth && !hadIndexOffset && lineCharacterCount > 1 && lineWidth > currentMaxWidth + 5.0 {
                if let imageItem = lineImageItems.last {
                    indexOffset = -(lastIndex + lineCharacterCount - imageItem.range.lowerBound)
                    continue
                }
                if let formulaItem = lineFormulaItems.last {
                    indexOffset = -(lastIndex + lineCharacterCount - formulaItem.range.lowerBound)
                    continue
                }
                // Without this arm an overflowing inline button stayed on the line and spilled past the
                // bounding width instead of moving to the next line: the pill's width lives entirely in
                // a CTRunDelegate on a single placeholder character, so the typesetter's suggested break
                // can land after it. Re-break before the pill, exactly as images and formulas do.
                if let buttonItem = lineButtonItems.last {
                    indexOffset = -(lastIndex + lineCharacterCount - buttonItem.range.lowerBound)
                    continue
                }
            }

            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            var underlineItems: [InstantPageTextUnderlineItem] = []
            var markedItems: [InstantPageTextMarkedItem] = []
            var spoilerItems: [InstantPageTextSpoilerItem] = []
            var anchorItems: [InstantPageTextAnchorItem] = []

            string.enumerateAttributes(in: lineRange, options: []) { attributes, range, _ in
                if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + (lineAscent - fontLineHeight), width: abs(upperX - lowerX), height: fontLineHeight)))
                }
                if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    underlineItems.append(InstantPageTextUnderlineItem(
                        frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + (lineAscent - fontLineHeight), width: abs(upperX - lowerX), height: fontLineHeight),
                        range: range,
                        color: attributes[NSAttributedString.Key.underlineColor] as? UIColor
                    ))
                }
                if let color = attributes[NSAttributedString.Key.init(rawValue: InstantPageMarkerColorAttribute)] as? UIColor {
                    var lineHeight = fontLineHeight
                    var delta: CGFloat = 0.0

                    if let offset = attributes[NSAttributedString.Key.baselineOffset] as? CGFloat {
                        lineHeight = floorToScreenPixels(lineHeight * 0.85)
                        delta = offset * 0.6
                    }
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    markedItems.append(InstantPageTextMarkedItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + (lineAscent - fontLineHeight) + delta, width: abs(upperX - lowerX), height: lineHeight), color: color, range: range))
                }
                if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] != nil {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    spoilerItems.append(InstantPageTextSpoilerItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + (lineAscent - fontLineHeight), width: abs(upperX - lowerX), height: fontLineHeight), range: range))
                }
                if let item = attributes[NSAttributedString.Key.init(rawValue: InstantPageAnchorAttribute)] as? Dictionary<String, Any>, let name = item["name"] as? String, let empty = item["empty"] as? Bool {
                    anchorItems.append(InstantPageTextAnchorItem(name: name, anchorText: item["text"] as? NSAttributedString, empty: empty))
                }
            }

            if !anchorItems.isEmpty {
                hasAnchors = true
            }

            if hadExtraDescent && extraDescent > 0 {
                workingLineOrigin.y += fontLineSpacing
            }

            let height = lineAscent
            if !markedItems.isEmpty {
                markedItems = markedItems.map { item in
                    if let attachmentBounds = v2LocalAttachmentBoundsForRange(item.range, imageItems: lineImageItems, formulaItems: lineFormulaItems, buttonItems: lineButtonItems) {
                        return InstantPageTextMarkedItem(frame: attachmentBounds, color: item.color, range: item.range)
                    } else {
                        return item
                    }
                }
            }
            // Per-character rects use each glyph's actual ink bounds via
            // CTFontGetBoundingRectsForGlyphs — caret-position advance-width
            // math (CTLineGetOffsetForStringIndex) is too tight for italics,
            // accented marks, and any glyph with side bearings, which causes
            // the reveal mask to visibly clip the glyph edges. Mirrors
            // InteractiveTextComponent.computeCharacterRectsForLine.
            //
            // For ligatures (one glyph for multiple chars), only the first
            // char's slot is populated; the rest stay CGRect.zero and the
            // consumer's `rect.isEmpty` guard skips them.
            let lineCharacterRects: [CGRect]?
            if computeRevealCharacterRects {
                var rects = [CGRect](repeating: CGRect.zero, count: lineRange.length)
                let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                for run in glyphRuns {
                    let run = run as! CTRun
                    let glyphCount = CTRunGetGlyphCount(run)
                    if glyphCount == 0 {
                        continue
                    }

                    var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                    CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)

                    var positions = [CGPoint](repeating: CGPoint.zero, count: glyphCount)
                    CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)

                    var stringIndices = [CFIndex](repeating: 0, count: glyphCount)
                    CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), &stringIndices)

                    let attributes = CTRunGetAttributes(run) as NSDictionary
                    guard let font = attributes[kCTFontAttributeName] as! CTFont? else {
                        continue
                    }

                    var boundingRects = [CGRect](repeating: CGRect.zero, count: glyphCount)
                    CTFontGetBoundingRectsForGlyphs(font, .default, &glyphs, &boundingRects, glyphCount)

                    for i in 0 ..< glyphCount {
                        let charIndex = stringIndices[i] - lineRange.location
                        if charIndex >= 0 && charIndex < lineRange.length {
                            let pos = positions[i]
                            let bbox = boundingRects[i]
                            rects[charIndex] = CGRect(
                                x: pos.x + bbox.origin.x,
                                y: pos.y + bbox.origin.y,
                                width: bbox.width,
                                height: bbox.height
                            )
                        }
                    }
                }
                for emoji in pendingEmoji {
                    let localIndex = emoji.range.location - lineRange.location
                    if localIndex >= 0 && localIndex < rects.count {
                        let x = v2LeadingOffsetForRange(line, range: emoji.range)
                        // characterRects are baseline-relative (positive-up). The emoji cell is now
                        // centered on the font line box (see frame loop), so in baseline-relative
                        // coords it spans [fontLineHeight/2 − size/2, fontLineHeight/2 + size/2].
                        // Width feeds the reveal cost map; maxY feeds the reveal-mask y conversion in
                        // the renderer (lineAscent − maxY), keeping the mask tracking the centered cell.
                        rects[localIndex] = CGRect(x: x, y: fontLineHeight / 2.0 - emoji.size / 2.0, width: emoji.size, height: emoji.size)
                    }
                }
                for image in pendingImages {
                    let localIndex = image.range.location - lineRange.location
                    if localIndex >= 0 && localIndex < rects.count {
                        let x = v2LeadingOffsetForRange(line, range: image.range)
                        // Image cell is centered on the font line box (see frame loop). Baseline-relative
                        // cell spans [fontLineHeight/2 − height/2, fontLineHeight/2 + height/2]; the full
                        // width feeds the reveal cost map so the streaming cursor is charged the image's
                        // width when crossing it — same as an emoji cell.
                        rects[localIndex] = CGRect(x: x, y: fontLineHeight / 2.0 - image.size.height / 2.0, width: image.size.width, height: image.size.height)
                    }
                }
                lineCharacterRects = rects
            } else {
                lineCharacterRects = nil
            }
            // `lineLeadingHang` (computed before the break, at the top of this iteration) is applied
            // HERE and ONLY here. The line frame positions both the drawn text and — via
            // `offsetBy(dx: lineFrame.minX …)` at emission — every per-line item, so one subtraction
            // moves the whole line coherently.
            //
            // INVARIANT — per-line item frames are LINE-LOCAL. `workingLineOrigin.x` is always 0.0
            // (it starts at 0 and is reset to 0 at the end of every iteration), so the
            // `workingLineOrigin.x + xOffset` in the item loops above is really just `xOffset`, and
            // each item picks up the line's position later, at emission. Subtracting the hang from
            // `workingLineOrigin.x` instead would therefore apply it TWICE to every pill, formula and
            // emoji — once in the item frame, once via `lineFrame.minX` — while the text, drawn from
            // the line frame alone, moved once. Keep the hang out of `workingLineOrigin`.
            let textLine = InstantPageTextLine(line: line, range: lineRange, frame: CGRect(x: workingLineOrigin.x - lineLeadingHang, y: workingLineOrigin.y, width: lineWidth, height: height), strikethroughItems: strikethroughItems, underlineItems: underlineItems, markedItems: markedItems, spoilerItems: spoilerItems, imageItems: lineImageItems, formulaItems: lineFormulaItems, buttonItems: lineButtonItems, emojiItems: lineEmojiItems, anchorItems: anchorItems, isRTL: isRTL, characterRects: lineCharacterRects)

            lines.append(textLine)
            imageItems.append(contentsOf: lineImageItems)
            if !lineFormulaItems.isEmpty {
                hasFormulaItems = true
            }

            if lineWidth > maxLineWidth {
                maxLineWidth = lineWidth
            }

            workingLineOrigin.x = 0.0
            workingLineOrigin.y += lineAscent + fontLineSpacing + extraDescent
            currentLineOrigin = workingLineOrigin

            lastIndex += lineCharacterCount

            if stop {
                break
            }
        } else {
            break
        }
    }

    var height: CGFloat = 0.0
    if !lines.isEmpty && !(string.string == "\u{200b}" && hasAnchors) {
        // + fontDescentBelowBaseline: contain the last line's descender below its baseline, so
        // (with the topInset shift) a single-line item measures exactly A + D = true font height.
        height = lines.last!.frame.maxY + extraDescent + fontDescentBelowBaseline
    }

    var textWidth = boundingWidth
    // Shrinking the box to content width anchors it at the leading `offset.x`, which makes any
    // non-leading display-time alignment a no-op (the block stays pinned to the leading edge and
    // only redistributes internally). Only `.natural` is leading-anchored; `.right` (RTL text)
    // and `.center` (pull quotes) must keep the full bounding width so `v2FrameForLine` lands
    // each line at the true trailing / centered position. `.right`/`.center` reach here only via
    // RTL text and pull quotes respectively, so plain LTR `.natural` body text is unaffected.
    if fitToWidth && alignment == .natural {
        textWidth = maxLineWidth
    }
    if (!imageItems.isEmpty || hasFormulaItems) && maxLineWidth > boundingWidth + 10.0 {
        textWidth = maxLineWidth
    }

    // Round the measured box UP to whole points. `height` comes from font metrics and `textWidth`
    // from CTLine measurement, so both are fractional — and because callers stack blocks by adding
    // this size to a running origin, one fractional box makes every later block origin fractional
    // too. Ceiling (not rounding, not flooring) is the only direction that cannot clip the text.
    //
    // Scope: the item's own box only. `lines` keep their fractional frames, and the inline button /
    // formula / image / emoji frames built below stay fractional on purpose — they are registered
    // against glyph positions the line-breaker cannot re-measure, so snapping them would drift the
    // attachment off its text.
    let itemSize = CGSize(width: ceil(textWidth), height: ceil(height))
    let textItem = InstantPageTextItem(frame: CGRect(origin: CGPoint(), size: itemSize), attributedString: string, alignment: alignment, opaqueBackground: opaqueBackground, lines: lines)
    textItem.frame = textItem.frame.offsetBy(dx: offset.x, dy: offset.y)
    var items: [InstantPageV2LaidOutItem] = []
    if imageItems.isEmpty || string.length > 1 {
        items.append(.text(InstantPageV2TextItem(frame: textItem.frame, textItem: textItem)))
    }

    var topInset: CGFloat = 0.0
    var bottomInset: CGFloat = 0.0
    var additionalItems: [InstantPageV2LaidOutItem] = []
    let effectiveOffset = offset
    for line in textItem.lines {
        let lineFrame = v2FrameForLine(line, boundingWidth: boundingWidth, alignment: alignment)
        // Inline images (RichText.image) are NOT emitted as top-level items here. They are
        // discovered at view-update time by InstantPageV2View.updateInlineImages(), which
        // walks each text view's `line.imageItems` and creates an InstantPageV2InlineImageView
        // attached to the text view's imageContainerView. The pop-in animation reuses the
        // emoji-style ownership model. See the inline-image design doc:
        // docs/superpowers/specs/2026-05-28-instantpage-v2-inline-image-design.md.
        for buttonItem in line.buttonItems {
            let buttonFrame = buttonItem.frame.offsetBy(dx: lineFrame.minX + effectiveOffset.x, dy: effectiveOffset.y)
            additionalItems.append(.inlineButton(InstantPageV2InlineButtonItem(frame: buttonFrame, attachment: buttonItem.attachment)))
            if buttonFrame.minY < topInset { topInset = buttonFrame.minY }
            if buttonFrame.maxY > height { bottomInset = max(bottomInset, buttonFrame.maxY - height) }
        }
        for formulaItem in line.formulaItems {
            let formulaFrame = formulaItem.frame.offsetBy(dx: lineFrame.minX + effectiveOffset.x, dy: effectiveOffset.y)
            let item = InstantPageV2FormulaItem(
                frame: formulaFrame,
                attachment: formulaItem.attachment,
                isScrollable: false,
                imageFrame: CGRect(origin: .zero, size: formulaFrame.size),
                scrollContentSize: formulaFrame.size
            )
            additionalItems.append(.formula(item))
            if formulaFrame.minY < topInset { topInset = formulaFrame.minY }
            if formulaFrame.maxY > height { bottomInset = max(bottomInset, formulaFrame.maxY - height) }
        }
    }

    let _ = topInset
    let _ = bottomInset
    items.append(contentsOf: additionalItems)

    return (textItem, items, textItem.frame.size)
}

/// Line-level metrics for hosts that apply text-style layout heuristics to a rendered page
/// (first-line collapse, trailing-line/copy-button overlap). Text items contribute their
/// laid-out lines (offset into page coordinates); substantive block items (code blocks,
/// tables, media, …) contribute their whole frame as one "line" and mark the trailing
/// position as a block; pure decorations (list markers, quote bars, shapes, dividers, image
/// ornaments) and anchors contribute nothing.
public struct InstantPageV2TextLineMetrics {
    public let numberOfLines: Int
    public let lineRects: [CGRect]
    public let trailingLineWidth: CGFloat
    public let trailingLineIsRTL: Bool
    public let trailingIsBlock: Bool
}

public extension InstantPageV2Layout {
    func textLineMetrics() -> InstantPageV2TextLineMetrics {
        var lineRects: [CGRect] = []
        var trailingLineWidth: CGFloat = 0.0
        var trailingLineIsRTL = false
        var trailingIsBlock = false

        for item in self.items {
            switch item {
            case .anchor, .listMarker, .blockQuoteBar, .shape, .divider, .imageOrnament, .quoteFrame:
                continue
            case let .text(textItem):
                if textItem.textItem.lines.isEmpty {
                    continue
                }
                for line in textItem.textItem.lines {
                    lineRects.append(line.frame.offsetBy(dx: textItem.frame.minX, dy: textItem.frame.minY))
                    trailingLineWidth = line.frame.maxX + textItem.frame.minX
                    trailingLineIsRTL = line.isRTL
                }
                trailingIsBlock = false
            default:
                lineRects.append(item.frame)
                trailingLineWidth = item.frame.maxX
                trailingLineIsRTL = false
                trailingIsBlock = true
            }
        }

        return InstantPageV2TextLineMetrics(
            numberOfLines: lineRects.count,
            lineRects: lineRects,
            trailingLineWidth: trailingLineWidth,
            trailingLineIsRTL: trailingLineIsRTL,
            trailingIsBlock: trailingIsBlock
        )
    }
}
