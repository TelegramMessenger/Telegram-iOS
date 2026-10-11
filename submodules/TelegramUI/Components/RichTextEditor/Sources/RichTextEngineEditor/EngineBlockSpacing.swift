#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The vertical rhythm and container padding the engine's blocks are laid out with.
///
/// **Both halves are shared, neither is invented here.** The gaps BETWEEN blocks come from
/// `richTextSpacingBetweenBlocks` — a transcription of the renderer's own
/// `InstantPageLayoutSpacings.spacingBetweenBlocks`, already pinned against V2 by
/// `RichTextV2MetricsParityTests` — and a container's INTERIOR padding comes from the stylesheet
/// values the legacy canvas resolves (`quoteTopInset`/`quoteBottomInset`). So the composer, the
/// legacy editor and the sent bubble agree by construction rather than by three sets of constants
/// being kept in step by hand.
///
/// The legacy canvas cannot be reused wholesale for this: `BlockStack` operates on `CanvasBlock`,
/// which requires a `BlockLayoutEngine` — a legacy box IS a TextKit layout, and text layout is the
/// thing the engine replaces. The POLICY is separable; the layout is not.
@available(iOS 18.4, *)
internal enum EngineBlockSpacing {

    /// Space to reserve around each ENGINE block, parallel to `roles`, PLUS the space owed above a
    /// placed run that cannot be expressed as an inset at all (see `layOut`'s diversion).
    ///
    /// A quote RUN is one unit to the spacing rules — that is how the renderer sees it — so the gap
    /// above a quote is computed once for the run and reserved on its first child, not on each. A
    /// quote may hold quotes, so the walk RECURSES: each level lays its own units out and hands its
    /// children to the level below (nesting design §5.2).
    /// `lineAttributes` answers what the bridge renders each role's line with, and is how the
    /// trailing line-box overhang is taken out of the rhythm (`trailingLineBoxOverhang`). It has NO
    /// default: a caller that passes nothing would silently get the rhythm this editor had before
    /// the overhang was accounted for — two points looser per boundary than the bubble — and nothing
    /// would fail. Every caller says what it means, including the tests.
    internal static func blockLayout(for roles: [EngineBlockRole],
                                     styleSheet: StyleSheet,
                                     quoteStyle: QuoteStyle,
                                     pullQuoteStyle: PullQuoteStyle,
                                     grids: [BlockID: EngineTableGrid] = [:],
                                     standaloneFormulas: Set<Int> = [],
                                     lineAttributes: (Int) -> [NSAttributedString.Key: Any])
        -> (insets: [UIEdgeInsets], placedReservations: [Int: CGFloat]) {
        guard !roles.isEmpty else { return ([], [:]) }
        var insets = [UIEdgeInsets](repeating: .zero, count: roles.count)
        var reservations: [Int: CGFloat] = [:]
        let overhangs = trailingLineBoxOverhangs(for: roles, lineAttributes: lineAttributes)
        var charged: Set<Int> = []
        layOut(level: 0, range: 0...(roles.count - 1), roles: roles, styleSheet: styleSheet,
               quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle, grids: grids,
               standaloneFormulas: standaloneFormulas, overhangs: overhangs,
               insets: &insets, reservations: &reservations, charged: &charged)
        // **Every deposited quantity lands on the device pixel grid, BEFORE the baseline shift.**
        //
        // The rhythm is integral by construction — `pitch = L + S` with both terms floored, the
        // `.safe` box is `ceil(fontBox)` — but several deposits are font-derived and so arbitrary
        // fractions: a code block's interior padding subtracts `ascender - capHeight` at the top and
        // `-descender` at the bottom (`codeInteriorPadding`, which is V2's own rule and has to stay
        // that rule). A block's origin is the running sum of every preceding height and inset, and
        // its interior line boundaries are `origin + k * pitch`, so ONE fractional deposit puts every
        // line below it off the grid and the selection rects drawn from them straddle a pixel.
        //
        // Snapped HERE rather than at each deposit so a future contribution cannot reintroduce it,
        // and BEFORE `applyV2BaselineShift` so that shift stays EXACTLY net-zero: its drop is already
        // snapped, so subtracting it from a snapped top and adding it to a snapped bottom leaves both
        // on the grid and their sum unchanged. Snapping afterwards instead would round the pair
        // independently and let up to a pixel per block accumulate into the document's height.
        snapToWholePoints(&insets, reservations: &reservations)
        applyV2BaselineShift(&insets, roles: roles, lineAttributes: lineAttributes)
        return (insets, reservations)
    }

    private static func snapToWholePoints(_ insets: inout [UIEdgeInsets],
                                        reservations: inout [Int: CGFloat]) {
        for index in insets.indices {
            insets[index].top = snappedToWholePoints(insets[index].top)
            insets[index].bottom = snappedToWholePoints(insets[index].bottom)
        }
        // A placed run's leading reservation is the gap above a table, so it moves the grid's origin
        // exactly as an inset does.
        for key in reservations.keys {
            reservations[key] = snappedToWholePoints(reservations[key] ?? 0)
        }
    }

    /// A UNIT at `level`: a maximal run within one CONTAINER at ancestry index `level`, or — for roles
    /// whose ancestry has exactly `level` entries — a leaf container's roles (a code block and its
    /// language line, a media atom and its caption, a table's cells). The ancestor a unit is, if it
    /// is one, of EITHER kind: keyed on `quote` alone, as it was, a details unit answered nil and
    /// `layOut` fell through to a `default: break` — so a details reserved none of its own interior
    /// AND its children were never laid out at all.
    private struct Unit {
        let range: ClosedRange<Int>
        let kind: RichTextBlockSpacingKind
        let container: EngineAncestor?
    }

    private static func units(at level: Int, in range: ClosedRange<Int>, roles: [EngineBlockRole],
                              standaloneFormulas: Set<Int>) -> [Unit] {
        var units: [Unit] = []
        var index = range.lowerBound
        while index <= range.upperBound {
            let role = roles[index]
            if role.ancestry.count > level {
                // A CONTAINER at this level is one unit, whichever kind it is. Matched on
                // `.blockQuote` alone, a details at this level fell through to the leaf branch below
                // and its children were grouped by `containerID` — so a details holding two
                // paragraphs read as two units and took a rhythm gap between them.
                let ancestor = role.ancestry[level]
                var end = index
                while end + 1 <= range.upperBound, roles[end + 1].ancestry.count > level,
                      roles[end + 1].ancestry[level].id == ancestor.id { end += 1 }
                units.append(Unit(range: index...end, kind: .blockQuote, container: ancestor))
                index = end + 1
            } else {
                // A container and its SECOND line are one unit: the rhythm sees a code block, not a
                // language line followed by a code block. Grouped on identity, like everything else
                // here — the line sits above its code today, but adjacency is not the invariant.
                var end = index
                while end + 1 <= range.upperBound, roles[end + 1].ancestry.count == level,
                      roles[end + 1].containerID == role.containerID { end += 1 }
                units.append(Unit(range: index...end,
                                  kind: spacingKind(of: role.container,
                                                    isStandaloneFormula: standaloneFormulas.contains(index)),
                                  container: nil))
                index = end + 1
            }
        }
        return units
    }

    /// The empty band a stacked block reserves BELOW its last line that the renderer does not.
    ///
    /// `StyleSheet` pins every line box to V2's pitch (`minimumLineHeight == maximumLineHeight`,
    /// because the reader's heading factor wants a pitch TIGHTER than the font's natural line height
    /// and a `lineSpacing` cannot go negative), so a block measures `lines * pitch`. V2's item
    /// measures `ceil(ascender + |descender|) + (lines - 1) * pitch`: it reserves only the DESCENDER
    /// below the last baseline, not a whole box. The difference is a constant per block — exactly
    /// what `BlockLayoutEngine` subtracts from the legacy canvas's boxes, which is why the legacy
    /// editor and the bubble agree and this one did not.
    ///
    /// It is EMPTY space — the glyphs are already drawn above it — so taking it out of the rhythm
    /// moves the next block up without clipping anything, exactly as it does in the legacy canvas.
    ///
    /// Zero when the block's height is not a pinned line box: an attachment atom (a media block, a
    /// button row) is one attachment character whose line TextKit inflates to the attachment, and a
    /// paragraph that ends in one is inflated the same way. Reading the attributes the bridge
    /// actually renders the line with — rather than re-deriving a style per role — is what keeps this
    /// honest for a code line, a caption and a quote's author alike, each of which is pinned to a
    /// different pitch.
    ///
    /// **AN INLINE ATTACHMENT THAT FITS THE PINNED LINE IS THE EXCEPTION, because it inflates
    /// nothing.** A custom emoji, a small inline formula and a short button pill all ride a text
    /// line that is still exactly its pinned height, so the empty band below the glyphs is still
    /// there and still has to come out of the rhythm. Refusing the overhang for EVERY attachment grew
    /// such a block by exactly that band: measured through the composer's own `height(forWidth:)`, a
    /// body paragraph went 49 → 51 and an H1 58 → 61 the moment an emoji was typed at its end, while
    /// the LINE BOX never moved (23 and 30 in both). That is the reported "inserting a custom emoji
    /// makes that line taller" — and it is the block, not the line. It also put the editor a
    /// line-band taller than the bubble, which reserves `ceil(A + |D|)` below its last baseline
    /// whatever characters are on it.
    ///
    /// **Fit is per-SIDE, not a height** (`RichTextInlineAttachmentFit.fitsPinnedLine`): the pin
    /// bottom-aligns the line, so an attachment can be shorter than the box and still inflate it by
    /// overhanging the baseline. Measured at body: a 22pt formula grows the line 0.2994 and a 19.9pt
    /// pill grows it 0.5176, both against a 23pt box. A height comparison would have called those
    /// two fits and handed back a band that is no longer there.
    /// **The face the pinned box was DERIVED from — which is not always the one the engine draws
    /// with**, and the difference is a defect if you read the wrong one.
    ///
    /// `StyleSheet` derives a style's pitch from `self.font(for: style, attributes: .plain)`, and the
    /// V2 renderer advances on the paragraph's font read once, never on a substituted run's metrics
    /// (`InstantPageV2Layout.swift:4280`). But **the engine rewrites `.font` in its own storage to
    /// the face CoreText substituted**: a body run comes back `.SFArabic-Regular` for Arabic,
    /// `.ThonburiUI-Regular` for Thai, `.AppleSDGothicNeoI-Regular` for Korean, where the mapper and
    /// the bridge both wrote `.SFUI-Regular`. Those faces have different boxes against the same 21pt
    /// pin — 21.117 for Arabic (drop 0, clamped) and ~17 for Korean (drop 4.0) against Latin's 20.287
    /// (drop 0.7129) — so a correction computed from `.font` follows whatever glyph was typed last.
    ///
    /// It was reported from the device as "when typing Arabic, the line moves up and down (likely
    /// depending on the symbols typed)", and that is exactly what it was: `spacingLineAttributes`
    /// samples the block's LAST character, so the answer flipped on the keystroke and the whole
    /// block's top inset moved with it.
    ///
    /// **`IDInlineTextBaseFontAttributeName` is the right source and already exists.** The bridge
    /// stamps it (`stampInlineTraitMarkers`) and the engine maintains it as the face traits are
    /// derived FROM, so it is the pre-substitution font. It also strips bold and italic, which
    /// matches `StyleSheet` deriving the pitch from `.plain`, and it PRESERVES a genuine style-level
    /// face change — inline code's monospaced font comes back as itself. Measured across latin,
    /// bold latin, arabic, bold arabic, thai and inline code: the marker answers the style's own
    /// face in every case where `.font` answers a substitution.
    ///
    /// Falls back to `.font` when the marker is absent, which is the honest answer for a string no
    /// bridge render has passed through.
    internal static func pinnedBoxFont(of attributes: [NSAttributedString.Key: Any]) -> UIFont? {
        (attributes[.IDInlineTextBaseFontAttributeName] as? UIFont) ?? (attributes[.font] as? UIFont)
    }

    internal static func trailingLineBoxOverhang(of attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        guard let font = pinnedBoxFont(of: attributes),
              let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
              paragraph.maximumLineHeight > 0 else { return 0 }
        if let attachment = attributes[.attachment] as? NSTextAttachment {
            guard RichTextInlineAttachmentFit.fitsPinnedLine(
                attachment, font: font, pinnedLineHeight: paragraph.maximumLineHeight)
            else { return 0 }
        }
        return max(0, -RichTextRenderMetrics.trailingHeightCorrection(
            font, pinnedLineHeight: paragraph.maximumLineHeight))
    }

    /// **How far BELOW V2's first baseline the pinned box puts this role's line** — the correction
    /// the LEGACY canvas makes with `BlockLayoutEngine.baselineDelta` and the engine has no
    /// counterpart to, because it draws the bridge's attributed string as-is.
    ///
    /// `pinnedLineHeight - (ascender - descender)`. TextKit bottom-aligns a line inside a pinned box,
    /// so the baseline sits one descender above the bottom and any excess of the box over the font's
    /// own line becomes dead space ABOVE the glyphs. V2 instead puts the baseline at the ascender and
    /// leaves the excess BELOW the last descender.
    ///
    /// It is the same quantity at every arm, which is why it is expressed against the pinned box
    /// rather than against a mode: **2.7129** under `.off` (the whole originally-reported band),
    /// **0.7129** under `.safe` at 17pt body, **0** under `.exact`.
    ///
    /// **IT IS NOT A CONSTANT.** It is a rounding remainder of `ascender - descender`, so it moves
    /// with the face and the point size — measured over the styles one field can hold, six distinct
    /// values spanning 0.0996 (15pt) to 0.9062 (heading5). That is why the correction is read per
    /// ROLE here rather than nudged once in a host: a single constant is exact for its own style and
    /// leaves every other one further from V2 than it started. `EngineLineBaselineTests
    /// .test_theSafeArmsResidualIsFontDependentSoAHostNudgeCannotBePrecise` is that measurement.
    ///
    /// Zero under the same conditions as `trailingLineBoxOverhang`, and for the same reason: an
    /// attachment that INFLATES the line is placed by its own metrics, not bottom-aligned in the pin,
    /// so there is no band above it to take out. An inline attachment that FITS rides an unchanged
    /// line and keeps the band.
    /// Snap to the nearest WHOLE POINT.
    ///
    /// **Points, not device pixels, and that distinction is the whole fix.** The rhythm is integral
    /// by construction — `pitch = L + S` with both terms floored, the `.safe` box is
    /// `ceil(fontBox)` — but `v2BaselineDrop` is a `ceil(fontBox) - fontBox` remainder (0.7461 at
    /// heading1, 0.7129 at body) applied as a net-zero inset pair, so every block ORIGIN sat that
    /// fraction above a whole point and a block's interior line boundaries, `origin + k * pitch`,
    /// inherited it.
    ///
    /// Snapping those boundaries to the device pixel grid (1/3pt at 3x) is NOT enough, which cost a
    /// round: **the selection drawing integralises to whole points.** Measured with 1/3pt snapping,
    /// a wrapped paragraph's first two line rects came back
    /// `[12.0, 34.0]` and `[34.3333, 57.3333]` — the first ending on a whole point while the second
    /// began a third of a point later, leaving an unfilled row that reads on screen as a white seam
    /// between line one and line two, and elsewhere a matching 1/3pt OVERLAP. At whole points every
    /// consecutive pair abuts exactly.
    ///
    /// NEAREST rather than floor, so the baseline stays as close to V2's as the grid allows: the
    /// drop exists to put it where V2 puts it, and half a point is now the most it can be off
    /// (worst measured 0.46 at a code block, 0.287 at body).
    internal static func snappedToWholePoints(_ value: CGFloat) -> CGFloat {
        value.rounded()
    }

    internal static func v2BaselineDrop(of attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        guard let font = pinnedBoxFont(of: attributes),
              let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
              paragraph.maximumLineHeight > 0 else { return 0 }
        if let attachment = attributes[.attachment] as? NSTextAttachment {
            guard RichTextInlineAttachmentFit.fitsPinnedLine(
                attachment, font: font, pinnedLineHeight: paragraph.maximumLineHeight)
            else { return 0 }
        }
        // Snapped HERE, in the one definition, so the layout walk, the decoration pass and the
        // geometry tests cannot disagree about the number — the same "one derivation, two consumers"
        // rule the rest of this file is built on.
        return snappedToWholePoints(max(0, paragraph.maximumLineHeight - (font.ascender - font.descender)))
    }

    /// The A/B for `v2BaselineDrop`'s application, so the shift has a negative control. Production
    /// never writes it; `EngineParagraphRhythmTests` does, to prove the transform is net-zero by
    /// comparing the two answers rather than by re-deriving one of them.
    internal static var v2BaselineShiftEnabled = true

    /// **Lift each block's text onto V2's baseline without moving anything else.**
    ///
    /// A block's canvas is placed `top` below where the rhythm left off, so taking `drop` OUT of its
    /// top inset moves its glyphs up by exactly the amount they sit low, and putting the same `drop`
    /// back into its bottom inset leaves the stacking cursor where it was. Net zero per block: the
    /// document's height, every later block's origin, and the baseline-to-baseline rhythm are all
    /// untouched, and only the text inside each box moves.
    ///
    /// **Per role, and that is the whole point** — a body paragraph needs 0.7129 where a 15pt quote
    /// child needs 0.0996, so the gap between two blocks of different styles legitimately changes by
    /// the DIFFERENCE of their drops. That is correct rather than a side effect: each baseline lands
    /// where V2 puts it, so the distance between them is V2's by construction.
    ///
    /// **PLACED roles are excluded**, as they are from `trailingLineBoxOverhangs` and for the same
    /// reason: the engine applies a placed block's insets INSIDE its host-computed frame, so a top
    /// inset would move a cell's text against a height the host owns. A cell renders at 15pt, where
    /// the drop is 0.0996 — below a device pixel at any scale — so the cost of leaving them is
    /// nothing anybody can see, and the alternative is reaching into table geometry for it.
    private static func applyV2BaselineShift(_ insets: inout [UIEdgeInsets],
                                             roles: [EngineBlockRole],
                                             lineAttributes: (Int) -> [NSAttributedString.Key: Any]) {
        guard v2BaselineShiftEnabled else { return }
        for index in roles.indices where roles[index].owningTable == nil {
            let drop = v2BaselineDrop(of: lineAttributes(index))
            guard drop > 0 else { continue }
            insets[index].top -= drop
            insets[index].bottom += drop
        }
    }

    /// Every role's trailing overhang, by index. Shared with the container decorations, which size
    /// their bands off the same too-tall block frames and would otherwise cover the line below.
    internal static func trailingLineBoxOverhangs(for roles: [EngineBlockRole],
                                                  lineAttributes: (Int) -> [NSAttributedString.Key: Any])
        -> [Int: CGFloat] {
        var overhangs: [Int: CGFloat] = [:]
        for index in roles.indices {
            // A PLACED role is sized by its frame, not by a stacked line box.
            guard roles[index].owningTable == nil else { continue }
            let overhang = trailingLineBoxOverhang(of: lineAttributes(index))
            if overhang > 0 { overhangs[index] = overhang }
        }
        return overhangs
    }

    /// Space deposited BELOW `role`, with that role's trailing overhang taken out of it ONCE.
    ///
    /// Several quantities can sit below the same line — a container's bottom interior, then the
    /// rhythm gap to whatever follows the container — and the overhang is one band of empty space,
    /// not one per quantity. Charging it per deposit would remove it two or three times over and
    /// pull the next block INTO the text above it.
    private static func spaceBelow(_ role: Int, amount: CGFloat, overhangs: [Int: CGFloat],
                                   charged: inout Set<Int>) -> CGFloat {
        guard !charged.contains(role) else { return amount }
        charged.insert(role)
        return amount - (overhangs[role] ?? 0)
    }

    /// Charges `bottom` at `index`, spread over every cell of the last row when that role is PLACED.
    /// A placed block's `bottom` extends the whole run, so one cell would extend one cell.
    private static func deposit(bottom: CGFloat, at index: Int, in range: ClosedRange<Int>,
                                roles: [EngineBlockRole], insets: inout [UIEdgeInsets]) {
        guard let row = roles[index].tableCellCoordinates?.row else {
            insets[index].bottom += bottom
            return
        }
        for cell in range where roles[cell].tableCellCoordinates?.row == row
            && roles[cell].containerID == roles[index].containerID {
            insets[cell].bottom += bottom
        }
    }

    /// Nesting design §5.2. The rhythm gap above each unit from the two units' ACTUAL kinds; at level 0
    /// the first unit and the trailing gap as before; inside a quote the first unit gets no rhythm gap
    /// (the interior padding stands in for it). A quote unit adds its interior at its two ends and
    /// `authorSpacing` before its author line, then recurses into its children one level down.
    private static func layOut(level: Int, range: ClosedRange<Int>, roles: [EngineBlockRole],
                               styleSheet: StyleSheet, quoteStyle: QuoteStyle, pullQuoteStyle: PullQuoteStyle,
                               grids: [BlockID: EngineTableGrid], standaloneFormulas: Set<Int>,
                               overhangs: [Int: CGFloat],
                               insets: inout [UIEdgeInsets],
                               reservations: inout [Int: CGFloat], charged: inout Set<Int>) {
        let metrics = styleSheet.metrics
        let units = units(at: level, in: range, roles: roles, standaloneFormulas: standaloneFormulas)
        for (position, unit) in units.enumerated() {
            let upper: RichTextBlockSpacingKind? = position == 0 ? nil : units[position - 1].kind
            // A PLACED first role takes NO top inset from this walk. A table's cells are placed, and
            // the engine applies a placed block's `top` inset INSIDE its own frame — so anything
            // deposited here moves the cell's text down within the cell instead of moving the table
            // down. The space is still owed, so it is DIVERTED into `reservations`, which the host
            // folds into every cell frame of the run.
            //
            // This covers the table's own unit AND any quote unit the table OPENS: a quote whose
            // first child is a table has its first role placed too, and its rhythm gap and top
            // interior were silently eaten the same way (measured: the two first-row cells of a
            // quoted table drifted 24pt apart, because only the first cell carried the quote's gap).
            let firstIsPlaced = roles[unit.range.lowerBound].owningTable != nil
            // The gap ABOVE this unit, owned by it. One quantity between two blocks, assigned to the
            // lower one so it is reserved exactly once.
            if position > 0 || level == 0 {
                var gap = richTextSpacingBetweenBlocks(upper: upper, lower: unit.kind, kind: .topLevel, metrics: metrics)
                // The block above ends in a line box taller than the renderer's item by its trailing
                // overhang, so the rhythm owes that much less. At `position == 0` there is nothing
                // above: this is the document's leading edge, which sits above a line box and not
                // below one.
                if position > 0 {
                    gap = spaceBelow(units[position - 1].range.upperBound, amount: gap,
                                     overhangs: overhangs, charged: &charged)
                }
                if firstIsPlaced {
                    reservations[unit.range.lowerBound, default: 0] += gap
                } else {
                    insets[unit.range.lowerBound].top += gap
                }
            }
            if level == 0, position == units.count - 1 {
                let trailing = spaceBelow(unit.range.upperBound,
                                          amount: richTextSpacingBetweenBlocks(upper: unit.kind, lower: nil,
                                                                               kind: .topLevel, metrics: metrics),
                                          overhangs: overhangs, charged: &charged)
                // `bottom` on a placed block extends its run's extent, so it has to reach the whole
                // LAST ROW. A table unit is the obvious case; a DETAILS unit reaches it too — its
                // `upperBound` is its last body block, which can be a table's final cell, and then
                // one cell carried the document's trailing gap while the rest of its row got none.
                deposit(bottom: trailing, at: unit.range.upperBound, in: unit.range, roles: roles, insets: &insets)
            }

            // A container's INTERIOR padding — fill edge to first/last text line — which is a
            // different quantity from the gaps above and is not expressible in the text at all
            // (TextKit ignores spacing-before on a container's first paragraph, and trailing spacing
            // does not extend the used height; both measured). Resolved exactly as the legacy canvas
            // resolves each one.
            if let container = unit.container {
                // DIVERTED on a placed first role for the reason above. The BOTTOM needs no such
                // guard: a placed block's `bottom` DOES
                // extend its run, which is why the last row carries the bottom border — but it has to
                // reach every cell of that row, which `deposit(bottom:)` does. A quote always ends in
                // its author line and never reaches that case; a details ends in its last body block,
                // which can be a table.
                //
                // Per KIND, like `interiorContributions`: a details' insets are its own, and its
                // expanded and folded bottoms differ.
                let topInterior: CGFloat
                let bottomInterior: CGFloat
                switch container {
                case .blockQuote:
                    topInterior = styleSheet.quoteTopInset ?? defaultQuoteInterior
                    bottomInterior = styleSheet.quoteBottomInset ?? defaultQuoteInterior
                case let .details(details):
                    topInterior = DetailsShape.topInset
                    bottomInterior = details.expanded ? DetailsShape.expandedBottomInset : DetailsShape.foldedBottomInset
                }
                if firstIsPlaced {
                    reservations[unit.range.lowerBound, default: 0] += topInterior
                } else {
                    insets[unit.range.lowerBound].top += topInterior
                }
                // `bottom` on a placed block extends its RUN, so a table at the container's end takes
                // it on every cell of the last row — one cell would extend that cell alone. A quote
                // always ends in its author line, so only a details can reach this.
                deposit(bottom: spaceBelow(unit.range.upperBound, amount: bottomInterior,
                                           overhangs: overhangs, charged: &charged),
                        at: unit.range.upperBound, in: unit.range, roles: roles, insets: &insets)

                // …and its own contents keep the ordinary rhythm between them, one level down,
                // except the container's OWN line, which is not a child: a quote's author sits one
                // `authorSpacing` below the last child, and a details' TITLE sits above the first
                // one with `titleBodyGap` between. A folded details has nothing but that title, so
                // there is nothing to recurse into.
                var children = unit.range
                let first = unit.range.lowerBound
                let last = unit.range.upperBound
                if case let .blockQuote(quote) = container,
                   roles[last].isOwnedLine(.blockQuoteAuthor, of: quote.id) {
                    insets[last].top += last > first
                        ? spaceBelow(last - 1, amount: quoteStyle.authorSpacing,
                                     overhangs: overhangs, charged: &charged)
                        : quoteStyle.authorSpacing
                    if last > first { children = first...(last - 1) } else { continue }
                } else if case let .details(details) = container,
                          roles[first].isOwnedLine(.detailsTitle, of: details.id) {
                    guard last > first else { continue }
                    children = (first + 1)...last
                    // The THIRD divert. A details' first body block hangs `titleBodyGap` below the
                    // title, and it used to get that only when the block was not a table — a placed
                    // block's `top` inset moves the cell's TEXT rather than the table, so it was
                    // dropped rather than delivered. Diverted like the other two, a table now hangs
                    // the same 14 below the title that a paragraph does.
                    //
                    // **This is the one place the placement refactor could not be behaviour-neutral,
                    // and the golden is what proved it.** `tableGapAbove` gave a table here a
                    // TOP-LEVEL RHYTHM gap of 16 — the gap a bare table gets after a paragraph —
                    // which is not the quantity that sits between a container's own line and its
                    // first child. Reproducing that 16 would have meant re-inventing the bug inside
                    // the new code, so the measured-correct 14 landed instead. Five of the six
                    // golden fixtures are byte-identical; this one moved on purpose.
                    let titleGap = spaceBelow(first, amount: DetailsShape.titleBodyGap,
                                              overhangs: overhangs, charged: &charged)
                    if roles[first + 1].owningTable == nil {
                        insets[first + 1].top += titleGap
                    } else {
                        reservations[first + 1, default: 0] += titleGap
                    }
                }
                layOut(level: level + 1, range: children, roles: roles, styleSheet: styleSheet,
                       quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle, grids: grids,
                       standaloneFormulas: standaloneFormulas, overhangs: overhangs,
                       insets: &insets, reservations: &reservations, charged: &charged)
                continue
            }
            switch unit.kind {
            case .preformatted:
                // Both edges land on the same index for a code block with no language line, and on
                // the two ends of the pair when it has one.
                let padding = codeInteriorPadding(styleSheet: styleSheet)
                insets[unit.range.lowerBound].top += padding.top
                insets[unit.range.upperBound].bottom += spaceBelow(unit.range.upperBound, amount: padding.bottom,
                                                                   overhangs: overhangs, charged: &charged)
                // The language line's own gap to the code below it.
                for line in unit.range.dropFirst() {
                    insets[line].top += spaceBelow(line - 1, amount: styleSheet.codeLanguageSpacing,
                                                   overhangs: overhangs, charged: &charged)
                }
            case .pullQuote:
                // Applied RAW, unlike a code block's: `PullQuoteStyle` defines these as the pill's
                // own interior padding — the legacy box adds them to its frame the same way — where
                // `codeVerticalInset` is defined as the resulting VISIBLE gap and so has the font-box
                // overhead taken out of it first. Two different definitions, not an inconsistency.
                insets[unit.range.lowerBound].top += pullQuoteStyle.topInset
                insets[unit.range.upperBound].bottom += spaceBelow(unit.range.upperBound,
                                                                   amount: pullQuoteStyle.bottomInset,
                                                                   overhangs: overhangs, charged: &charged)
                // The author line's own gap below the quote text.
                for line in unit.range.dropFirst() {
                    insets[line].top += spaceBelow(line - 1, amount: pullQuoteStyle.authorSpacing,
                                                   overhangs: overhangs, charged: &charged)
                }
            case .table:
                // Cell padding, applied INSIDE each placed frame; the grid already knows the
                // per-cell value, including the free space a middle/bottom alignment adds.
                let lastRow = unit.range.compactMap { roles[$0].tableCellCoordinates?.row }.max() ?? 0
                for cell in unit.range {
                    guard let grid = grids[roles[cell].containerID], let geometry = grid.cell(withID: roles[cell].blockID) else { continue }
                    insets[cell].top += geometry.textInsets.top
                    insets[cell].left += geometry.textInsets.left
                    insets[cell].right += geometry.textInsets.right
                    // The last column's frame is one border wider so the run holds the right
                    // border (`syncTableFrames`); the same border on the right inset keeps the
                    // text column where the grid put it.
                    insets[cell].right += grid.trailingBorderExtension(for: geometry)
                    // The chrome is one border taller than the last row's cells; `bottom` on a
                    // placed block extends the run, so the run holds the whole bottom border.
                    if roles[cell].tableCellCoordinates?.row == lastRow {
                        insets[cell].bottom += grid.borderWidth
                        // And the column grip's band, INSIDE a container. At the top level the grip
                        // hangs into the document's own rhythm, as legacy's does; inside a quote the
                        // next line is the container's — the author line sits right under the table —
                        // and the grip was drawn over it (K3, 2026-09-11).
                        if !roles[cell].ancestry.isEmpty {
                            insets[cell].bottom += EngineTableStructuralChrome.gripHeight
                        }
                    }
                }
            case .blockQuote:
                // A FOLDED quote (R7-collapse §4.2). It is the only `.blockQuote` unit that reaches
                // this switch — an OPEN quote is a CONTAINER unit and `continue`s above, in the
                // branch that charges its interior per ancestor — but the guard says so explicitly
                // rather than resting on that, so a future leaf of this kind cannot pick up a
                // quote's padding by accident.
                //
                // A leaf container's interior is declared TWICE: here, where it is reserved in the
                // LAYOUT, and in `leafInteriorPadding`, the decoration pass's mirror of the same
                // numbers. Declared only there — as it was when this rung shipped — the band is drawn
                // 8pt above the atom while the rhythm reserves nothing for it, so a folded quote sat
                // 8pt closer to the block above than an open one and its background read as a
                // different shape (device, 2026-09-15). The text origin looked right throughout,
                // because the text is 8pt inside the band either way.
                guard roles[unit.range.lowerBound].shape.collapsedQuote != nil else { break }
                insets[unit.range.lowerBound].top += styleSheet.quoteTopInset ?? defaultQuoteInterior
                insets[unit.range.upperBound].bottom += spaceBelow(
                    unit.range.upperBound, amount: styleSheet.quoteBottomInset ?? defaultQuoteInterior,
                    overhangs: overhangs, charged: &charged)
            case .media:
                // `MediaBlockBox`'s interior: 8 above the medium and below the unit's last line, 4
                // between the medium and its caption.
                insets[unit.range.lowerBound].top += MediaSlotGeometry.verticalInset
                insets[unit.range.upperBound].bottom += MediaSlotGeometry.verticalInset
                for line in unit.range.dropFirst() { insets[line].top += MediaSlotGeometry.captionGap }
            default:
                break
            }
        }
    }

    /// Each container's own interior contribution at `index`: one entry per ancestor, outermost first,
    /// then one for the leaf container. A band sums the entries from its own level downward (§5.1);
    /// `interiorPadding` sums them all.
    ///
    /// A quote's edges are its MEMBERSHIP's, which is what its children, its nested containers and its
    /// author line share. Keyed on `containerID` instead, a child's own identity would make every child
    /// its own group and the band would cover neither the gap above the author nor the bottom padding.
    internal static func interiorContributions(for roles: [EngineBlockRole], at index: Int, styleSheet: StyleSheet,
                                               quoteStyle: QuoteStyle, pullQuoteStyle: PullQuoteStyle) -> [UIEdgeInsets] {
        guard index < roles.count else { return [] }
        let role = roles[index]
        var result: [UIEdgeInsets] = []
        for ancestor in role.ancestry {
            let isFirst = index == 0 || !roles[index - 1].isWithin(ancestor.id)
            let isLast = index == roles.count - 1 || !roles[index + 1].isWithin(ancestor.id)
            // The author's band also covers the gap separating it from the last child, so the
            // segments abut instead of leaving a seam in the fill.
            let isAuthor = role.isOwnedLine(.blockQuoteAuthor, of: ancestor.id)
            // Per KIND. Charged unconditionally, a details was billed a quote's interior — an inset
            // it does not have — on top of its own (R7-details spec §3.3).
            let topInterior: CGFloat
            let bottomInterior: CGFloat
            switch ancestor {
            case .blockQuote:
                topInterior = styleSheet.quoteTopInset ?? defaultQuoteInterior
                bottomInterior = styleSheet.quoteBottomInset ?? defaultQuoteInterior
            case let .details(details):
                topInterior = DetailsShape.topInset
                bottomInterior = details.expanded ? DetailsShape.expandedBottomInset : DetailsShape.foldedBottomInset
            }
            result.append(UIEdgeInsets(top: isFirst ? topInterior : (isAuthor ? quoteStyle.authorSpacing : 0.0),
                                       left: 0.0, bottom: isLast ? bottomInterior : 0.0, right: 0.0))
        }
        result.append(leafInteriorPadding(for: roles, at: index, styleSheet: styleSheet, pullQuoteStyle: pullQuoteStyle))
        return result
    }

    /// How much of a block's inset belongs to the containers DRAWN around it, as opposed to the gap
    /// separating it from its neighbours. A band covers the former and not the latter.
    internal static func interiorPadding(for roles: [EngineBlockRole], at index: Int, styleSheet: StyleSheet,
                                         quoteStyle: QuoteStyle, pullQuoteStyle: PullQuoteStyle) -> UIEdgeInsets {
        interiorContributions(for: roles, at: index, styleSheet: styleSheet, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle)
            .reduce(UIEdgeInsets.zero) { UIEdgeInsets(top: $0.top + $1.top, left: 0.0, bottom: $0.bottom + $1.bottom, right: 0.0) }
    }

    /// The LEAF container's interior at `index` — the code, pull quote and media arms the old
    /// `interiorPadding` had, gated on the container group's edges.
    private static func leafInteriorPadding(for roles: [EngineBlockRole], at index: Int, styleSheet: StyleSheet,
                                            pullQuoteStyle: PullQuoteStyle) -> UIEdgeInsets {
        let isFirst = index == 0 || roles[index - 1].containerID != roles[index].containerID
        let isLast = index == roles.count - 1 || roles[index + 1].containerID != roles[index].containerID
        switch roles[index].container {
        case .details:
            // A details' own top/bottom insets are charged per ANCESTOR by `interiorContributions`,
            // like a quote's — not here. The title line adds nothing of its own.
            return .zero
        case .block(.code):
            let padding = codeInteriorPadding(styleSheet: styleSheet)
            return UIEdgeInsets(top: isFirst ? padding.top : 0.0, left: 0.0, bottom: isLast ? padding.bottom : 0.0, right: 0.0)
        case .block(.pullQuote):
            // Gated on the GROUP's edges, exactly as the code case is: a pull quote with an author
            // line owns two engine blocks, and padding reported for both would be counted twice by
            // the band that spans them.
            return UIEdgeInsets(top: isFirst ? pullQuoteStyle.topInset : 0.0, left: 0.0, bottom: isLast ? pullQuoteStyle.bottomInset : 0.0, right: 0.0)
        case .block(.media):
            return UIEdgeInsets(top: isFirst ? MediaSlotGeometry.verticalInset : MediaSlotGeometry.captionGap, left: 0.0,
                                bottom: isLast ? MediaSlotGeometry.verticalInset : 0.0, right: 0.0)
        case .block(.collapsedQuote):
            // The folded quote's OWN interior, which `interiorContributions` no longer charges
            // because the quote is not an ancestor any more (R7-collapse §4.2). No `isFirst`/
            // `isLast` gating, unlike code and pull quote: a folded quote owns exactly ONE engine
            // block, so there is no group for the band to double-count across.
            return UIEdgeInsets(top: styleSheet.quoteTopInset ?? defaultQuoteInterior, left: 0.0,
                                bottom: styleSheet.quoteBottomInset ?? defaultQuoteInterior, right: 0.0)
        case .block(.paragraph), .block(.buttonRow), .blockQuote, .table:
            // A button row has no interior of its own: the packed row IS the atom's height, so
            // padding here would be reserved twice.
            return .zero
        }
    }

    /// What the legacy canvas resolves a nil quote inset to (`BlockBox.defaultVerticalInset`).
    private static let defaultQuoteInterior: CGFloat = 8.0

    /// A code block's interior padding, LESS the font-box overhead the block frame already carries.
    ///
    /// `codeVerticalInset` is the VISIBLE gap: band edge to the cap line above, to the baseline
    /// below. V2 reaches that by subtracting `instantPageV2TextBoxOverheads` — `ascender - capHeight`
    /// at the top, `-descender` at the bottom — from the inset before applying it, because the text
    /// item it pads is a font line box carrying ascent headroom above the caps and descent below the
    /// last baseline. The engine's block frame is a line box for the same reason, so reserving the
    /// RAW inset around it counts that overhead twice and the block reads far too tall — which is
    /// what shipped, and what a device look caught immediately.
    ///
    /// The residual against the renderer is the pinned line box being slightly taller than the font
    /// box (TextKit's placement inside a pinned box is measured, not derived — see
    /// `BlockLayoutEngine.baselineDelta`); closing THAT is R8's frame-parity contract. This is the
    /// renderer's own rule applied to the geometry this rung has.
    private static func codeInteriorPadding(styleSheet: StyleSheet) -> UIEdgeInsets {
        let inset = styleSheet.codeVerticalInset
        let code = FontResolver.font(spec: styleSheet.metrics.codeBlock,
                                     bold: false, italic: false, family: nil)
        // The TOP overhead belongs to whichever line is first, which is the language line — always
        // present, because it is where a language is typed. `layoutCodeBlock` makes the same
        // distinction (`hasLanguageLine ? languageOverheadTop : codeOverheads.top`); the two fonts
        // differ, so taking the code's overhead at the top would misplace the band by their gap.
        let language = UIFont.systemFont(ofSize: styleSheet.metrics.body.size, weight: .semibold)
        return UIEdgeInsets(top: max(0.0, inset - max(0.0, language.ascender - language.capHeight)),
                            left: 0.0,
                            bottom: max(0.0, inset - max(0.0, -code.descender)),
                            right: 0.0)
    }

    private static func spacingKind(of container: EngineContainerShape,
                                    isStandaloneFormula: Bool) -> RichTextBlockSpacingKind {
        switch container {
        case let .block(.paragraph(paragraph)):
            // FIRST, mirroring `InstantPageBuilder`'s dispatch order — a standalone formula wins
            // over the list check, which wins over the style switch. `BlockBox.spacingKind` says
            // the layout side must match that order, and this is the engine's layout side.
            if isStandaloneFormula { return .formula }
            if paragraph.list != nil { return .list }
            switch paragraph.style {
            case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return .heading
            default: return .paragraph
            }
        case .block(.code): return .preformatted
        case .block(.pullQuote): return .pullQuote
        case let .block(.media(media)): return .media(hasCredit: false, isRawMedia: media.isRawMedia)
        case .block(.buttonRow): return .buttonRow
        // A folded quote keeps the QUOTE's rhythm against its neighbours, so folding moves the
        // blocks around it by the quote's own height change and by nothing else.
        case .block(.collapsedQuote): return .blockQuote
        case .blockQuote: return .blockQuote
        // A details takes the block quote's rhythm: both are containers whose neighbours should be
        // separated from them as a unit, and the renderer has no kind of its own for a folding block.
        case .details: return .blockQuote
        case .table: return .table
        }
    }
}
#endif
