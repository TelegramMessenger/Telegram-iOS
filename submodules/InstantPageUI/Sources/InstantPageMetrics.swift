import Foundation
import UIKit
import Display

/// Every geometry constant that is tuned against the body font, scaled once.
///
/// This type exists to make coverage **reviewable**. The risk in a content-scale change is an
/// incomplete sweep: one literal left raw renders 17pt-tuned geometry inside a 15pt quote, which no
/// diff review catches and no test covers. Collecting the constants here makes "what scales, what
/// doesn't, and why" a single screen instead of an emergent property of ~100 call sites.
///
/// Membership IS the policy. A constant that must not scale — chrome identity (bar widths, corner
/// radii, quote marks), hairlines (`UIScreenPixel`-derived widths), media frame geometry, and
/// minimum separations or 1–2pt optical nudges — is expressed by its ABSENCE from this struct, not
/// by a numeric threshold rule applied at a call site.
///
/// `layoutTextItem` is likewise absent by design: its literals are font-metric-relative
/// (`lineSpacingFactor`, the line-height factor, the baseline slack, `lineBoxTopInset`) and already
/// follow the scaled font. Scaling them here would double-apply.
///
/// **Invariant: `InstantPageMetrics(scale: 1.0)` is bit-identical to the literals it replaced.**
/// Everything outside a quote — most of every page — must lay out exactly as it did before this
/// type existed. `InstantPageMetricsTests` is that check.
struct InstantPageMetrics {
    // MARK: Block rhythm (InstantPageLayoutSpacings.swift)

    let baseBlockSpacing: CGFloat
    /// `blockVerticalPadding` and `dividerVerticalPadding` are both 4 today and stay separate
    /// fields: they are different quantities that happen to coincide, and collapsing them would
    /// make a future change to one silently move the other.
    let blockVerticalPadding: CGFloat
    let headingVerticalPadding: CGFloat
    let dividerVerticalPadding: CGFloat
    /// The gap added for a `.details` block followed by a NON-`.details` block. Two adjacent
    /// `.details` blocks take a different arm and never see this.
    let detailsAdjacentSpacing: CGFloat

    // MARK: Caption / credit

    let captionTopPad: CGFloat
    let creditTopPad: CGFloat
    let coverCaptionExtraPad: CGFloat

    // MARK: Quotes

    let quoteVerticalInset: CGFloat
    let pullQuoteVerticalInset: CGFloat
    let quoteLineInset: CGFloat
    let quoteLeadingInset: CGFloat
    let quoteTrailingInset: CGFloat
    let pullQuotePadding: CGFloat
    /// Body → attribution gap. Was a `3.0` duplicated at two sites; this unifies them.
    let quoteAttributionGap: CGFloat

    // MARK: Code blocks

    let codeBlockVerticalInset: CGFloat
    /// `layoutCodeBlock` sizes code from this rather than from the theme's `codeBlock` category (15
    /// in the chat table, 14 in the Instant View themes). It is a FONT size, so it takes the fonts'
    /// whole-point floor and not the pixel snap the geometry constants take: code, `table` and a
    /// quote's body are all "one step below body" and must stay equal at every content scale, which
    /// a 16.67pt code face against a 16pt table would break. `InstantPageContentScaleTests` pins it.
    let codeBlockFontSize: CGFloat
    /// Gap between the code block's bold language line and its first code line.
    let codeBlockLanguageSpacing: CGFloat

    // MARK: Lists
    //
    // `bulletDiameter` and `listItemTextwardOffset` are SCALED COPIES of the
    // `InstantPageShapeItem.swift` globals. Those globals stay as they are, because V1 reads them
    // and must not change.

    let listIndexSpacing: CGFloat
    let checklistMarkerSize: CGSize
    let bulletDiameter: CGFloat
    let listItemTextwardOffset: CGFloat
    let numberMarkerTextwardOffset: CGFloat

    // MARK: Tables

    let tableCellInsets: UIEdgeInsets
    /// Halved cell padding for `pageBlockTable`'s `compact` flag.
    let tableCompactCellInsets: UIEdgeInsets
    let tableMinCompressedColumnWidth: CGFloat

    // MARK: Details

    let detailsMinTitleHeight: CGFloat
    let detailsTitleVerticalPad: CGFloat
    let detailsChevronReserve: CGFloat
    let detailsTitleHorizontalInset: CGFloat

    // MARK: Button rows

    let blockButtonHeight: CGFloat
    let blockButtonSpacing: CGFloat

    /// `screenScale` is injectable so a test can pin the pixel grid (2x/3x) instead of inheriting
    /// whatever `UIScreen.main` reports in the test process; production always takes the default.
    init(scale: CGFloat, screenScale: CGFloat = UIScreenScale) {
        func s(_ value: CGFloat) -> CGFloat {
            return floor(value * scale * screenScale) / screenScale
        }

        self.baseBlockSpacing = s(instantPageBaseBlockSpacing)
        self.blockVerticalPadding = s(4.0)
        self.headingVerticalPadding = s(8.0)
        self.dividerVerticalPadding = s(4.0)
        self.detailsAdjacentSpacing = s(4.0)

        self.captionTopPad = s(9.0)
        self.creditTopPad = s(10.0)
        self.coverCaptionExtraPad = s(14.0)

        self.quoteVerticalInset = s(6.0)
        self.pullQuoteVerticalInset = s(12.0)
        self.quoteLineInset = s(9.0)
        self.quoteLeadingInset = s(9.0)
        self.quoteTrailingInset = s(16.0)
        self.pullQuotePadding = s(30.0)
        self.quoteAttributionGap = s(3.0)

        self.codeBlockVerticalInset = s(14.0)
        self.codeBlockFontSize = floor(15.0 * scale)
        self.codeBlockLanguageSpacing = s(3.0)

        self.listIndexSpacing = s(8.0)
        self.checklistMarkerSize = CGSize(width: s(18.0), height: s(18.0))
        self.bulletDiameter = s(instantPageBulletMarkerDiameter)
        self.listItemTextwardOffset = s(instantPageListItemTextwardOffset)
        self.numberMarkerTextwardOffset = s(instantPageV2NumberMarkerTextwardOffset)

        self.tableCellInsets = UIEdgeInsets(top: s(7.0), left: s(13.0), bottom: s(7.0), right: s(13.0))
        // Halved BEFORE `s(...)` so the result is screen-pixel-snapped like every other metric,
        // rather than a raw 3.5 that no `floorToScreenPixels` ever touched.
        self.tableCompactCellInsets = UIEdgeInsets(top: s(3.5), left: s(6.5), bottom: s(3.5), right: s(6.5))
        self.tableMinCompressedColumnWidth = s(60.0)

        self.detailsMinTitleHeight = s(36.0)
        self.detailsTitleVerticalPad = s(15.0)
        self.detailsChevronReserve = s(32.0)
        self.detailsTitleHorizontalInset = s(23.0)

        self.blockButtonHeight = s(instantPageBlockButtonHeight)
        self.blockButtonSpacing = s(instantPageBlockButtonSpacing)
    }

    /// The page-level metrics. MUST equal the literals this type replaced — see the invariant above.
    static let unscaled = InstantPageMetrics(scale: 1.0)

    /// Quoted content sits one typographic step below body: the theme's quote size over its
    /// paragraph size. Written as the ratio rather than 0.882 so it stays legible as what it means.
    static let quoteScale: CGFloat = 15.0 / 17.0
}
