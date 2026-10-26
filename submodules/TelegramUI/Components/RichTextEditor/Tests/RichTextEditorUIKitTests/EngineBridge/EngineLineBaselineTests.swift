#if canImport(UIKit)
import XCTest
@testable import RichTextEditorCore
@testable import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Where the ENGINE's rendered line puts its first baseline inside the box it lays out, and what that
/// costs the block's height.
///
/// The engine draws the bridge's attributed string directly — it has no counterpart to the legacy
/// canvas's `BlockLayoutEngine.baselineDelta`, which CORRECTS TextKit's placement back to V2's. So the
/// placement the paragraph style produces is the placement the glyphs get. See
/// the RichTextEditor `CLAUDE.md`, "A block's FRAME is a line box; the rhythm below it is the renderer's".
///
/// **SCOPE LIMIT — these measure in TextKit 1 and the engine is TextKit 2.** `NSLayoutManager` here
/// is the LEGACY canvas's engine (`BlockLayoutTK1`); the engine sizes blocks from
/// `NSTextLayoutManager.usageBoundsForTextContainer` (`IDBlockLayout.m:143,186`). These cases pin the
/// PARAGRAPH STYLE's consequences, which both systems read the same way, and are honest about the
/// first baseline because bottom-alignment in a pinned box is a property of the style. They are NOT
/// evidence about `usedSize` — `Host/Tests/Engine/EngineUsedHeightModelTests` is, and it is what
/// chose the arm. Do not cite `test_aBlocksStackingHeight…` as that measurement.
@available(iOS 18.4, *)
final class EngineLineBaselineTests: XCTestCase {
    private let bridge = EngineDocumentBridge(mapper: AttributedStringMapper())

    private func bodyParagraph(_ text: String) -> NSAttributedString {
        let document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)]))
        ])
        return bridge.attributedBlocks(for: document)[0]
    }

    /// The baseline TextKit produces for the first line, from that line's box top — the same two calls
    /// `BlockLayoutTK1.rawFirstBaselineFromTop` makes, so this reads the real placement rather than
    /// re-deriving it from the paragraph style.
    private func firstBaselineFromLineTop(of attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        measuring(attributed, width: width) { manager, _ in
            manager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY
                + manager.location(forGlyphAt: 0).y
        }
    }

    private func usedHeight(of attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        measuring(attributed, width: width) { manager, container in
            manager.usedRect(for: container).height
        }
    }

    /// How many line fragments the string actually broke into — asserted independently rather than
    /// derived from the height, or a regression that measures a 2-line block as one line's height
    /// passes silently (`ceil(21/23) == 1`, and `textHeight(…, lineCount: 1) == 21`).
    private func lineFragmentCount(of attributed: NSAttributedString, width: CGFloat) -> Int {
        measuring(attributed, width: width) { manager, container in
            var count = 0
            let glyphs = manager.glyphRange(for: container)
            var index = glyphs.location
            while index < NSMaxRange(glyphs) {
                var effective = NSRange(location: 0, length: 0)
                _ = manager.lineFragmentRect(forGlyphAt: index, effectiveRange: &effective)
                count += 1
                index = NSMaxRange(effective)
            }
            return count
        }
    }

    /// **The storage must outlive the measurement**, which is why this takes a closure rather than
    /// returning the manager: an `NSTextStorage` OWNS its layout manager, so a manager that escapes a
    /// helper loses its text the moment the local storage deallocates — and `usedRect` then reports a
    /// perfectly plausible `0.0` rather than failing.
    private func measuring<T>(_ attributed: NSAttributedString, width: CGFloat,
                              _ body: (NSLayoutManager, NSTextContainer) -> T) -> T {
        let storage = NSTextStorage(attributedString: attributed)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        return withExtendedLifetime(storage) { body(manager, container) }
    }

    // MARK: - The fixed defect

    /// **The defect this whole change exists for, now fixed.**
    ///
    /// The engine's first baseline sits at `pitch - |descender|` (TextKit bottom-aligns a line inside a
    /// box pinned by `minimumLineHeight == maximumLineHeight`), where V2 puts it at the font's
    /// ascender. Measured 2026-09-16: **18.899 against V2's 16.187**, a dead band of **2.7129pt** above
    /// line 1 only — invisible between lines, where it reads as line spacing, and visible once per
    /// block at the top. That is the chat composer's "the first line is offset to the bottom".
    ///
    /// It grew on 2026-09-15 with `8cd8e45814` (body `lineSpacingFactor` 0.9 → 0.95, pitch 22 → 23),
    /// which moved the renderer too — so the extra point is correct and lands BETWEEN lines in the
    /// bubble and ABOVE line 1 here. **Do not fix it by reverting the factor.**
    ///
    /// The `.safe` arm (spec §5.1) asserts 16.899 rather than 16.187: it deliberately leaves 0.713pt
    /// to keep the block's height exactly V2's. The second assertion is the one that would catch a
    /// regression back toward 18.899 even if someone re-tuned the first.
    func test_engineBodyLine_putsItsFirstBaselineWhereV2Does() throws {
        let attributed = bodyParagraph("Handy")
        let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        // The `.safe` arm pins the box to `ceil(fontBox)`, so the baseline lands
        // `ceil(fontBox) - fontBox` = 0.713pt below V2's — deliberately, to keep the block's height
        // exactly V2's (spec §5.1). 2.0 of the 2.713pt dead band is gone; this asserts where it
        // actually lands rather than where the ideal arm would put it.
        XCTAssertEqual(firstBaselineFromLineTop(of: attributed, width: 280.0),
                       ceil(font.ascender - font.descender) + font.descender, accuracy: 0.01)
        XCTAssertLessThan(
            abs(firstBaselineFromLineTop(of: attributed, width: 280.0)
                - RichTextRenderMetrics.firstBaselineFromTop(font)),
            1.0, "the residual against V2 must stay under a point")
    }

    // MARK: - The mode switch

    /// The mode switch is off by default, so Task 1 changes nothing on its own — and each arm moves
    /// the first baseline to its own predicted place. `.off` must reproduce today's defect exactly,
    /// or the switch is not a faithful rollback.
    ///
    /// Every expectation is `box + font.descender` (descender negative) — TextKit bottom-aligns the
    /// line in the pinned box, so the baseline sits one descender above its bottom whatever the box
    /// is. That is the ONE rule this whole change rests on, stated once per arm.
    func test_eachPlacementModeMovesTheFirstBaselineToItsPredictedPlace() throws {
        let font = try XCTUnwrap(bodyParagraph("Handy")
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let fontBox = font.ascender - font.descender
        let expected: [EngineDocumentBridge.V2BaselinePlacement: CGFloat] = [
            .off: RichTextRenderMetrics.linePitch(
                font, factor: RichTextRenderMetrics.default.body.lineSpacingFactor) + font.descender,
            .safe: ceil(fontBox) + font.descender,
            .exact: fontBox + font.descender,
            .exactWithTrailingSpacing: fontBox + font.descender,
        ]
        let original = EngineDocumentBridge.v2BaselinePlacement
        defer { EngineDocumentBridge.v2BaselinePlacement = original }

        for (mode, want) in expected {
            EngineDocumentBridge.v2BaselinePlacement = mode
            let measured = firstBaselineFromLineTop(of: bodyParagraph("Handy"), width: 280.0)
            XCTAssertEqual(measured, want, accuracy: 0.01, "mode \(mode)")
        }
    }

    // MARK: - Is the residual a constant?

    /// **The `.safe` arm's residual is NOT font-independent, so a single host-side nudge cannot be
    /// precise.** Asked directly (2026-09-16): "Is it font-independent? We can do a nudge in the host,
    /// but we need to know it's precise."
    ///
    /// The residual is `ceil(fontBox) - fontBox` — a ROUNDING REMAINDER, and a rounding remainder of a
    /// quantity that changes with the face and the point size. It is not a property of the placement,
    /// it is a property of each font. A host nudge is ONE number applied to the whole canvas, so it can
    /// only ever be exact for whichever style happens to match it, and it is wrong for every other
    /// style in the same field — over-correcting some blocks and under-correcting others.
    ///
    /// This prints the table and asserts the spread, so the claim is a measurement rather than an
    /// argument. `XCTAssertGreaterThan(distinct, 1)` is the whole point: if these were all equal, the
    /// host nudge WOULD be precise and this case should fail and be deleted.
    func test_theSafeArmsResidualIsFontDependentSoAHostNudgeCannotBePrecise() throws {
        var rows: [(name: String, size: CGFloat, box: CGFloat, residual: CGFloat)] = []

        func record(_ label: String, _ sheet: StyleSheet, _ style: ParagraphStyleName) {
            let font = sheet.font(for: style, attributes: CharacterAttributes())
            let box = font.ascender - font.descender
            rows.append((label, font.pointSize, box, ceil(box) - box))
        }

        let sheet = StyleSheet()
        for style in ParagraphStyleName.allCases { record("\(style)", sheet, style) }
        // The 15pt cell sheet — a quote child renders at this scale too, so it is the size that most
        // often shares a field with body text.
        for style in [ParagraphStyleName.body, .heading1] {
            record("cell/\(style)", StyleSheet.tableCells, style)
        }

        print("=== .safe residual = ceil(fontBox) - fontBox ===")
        for row in rows {
            print(String(format: "%-16@ %5.1fpt  box %8.4f  residual %6.4f",
                         row.name as NSString, row.size, row.box, row.residual))
        }

        let distinct = Set(rows.map { Int(($0.residual * 10_000).rounded()) })
        XCTAssertGreaterThan(distinct.count, 1,
                             "every style shares one residual — a host nudge WOULD be precise; "
                             + "delete this case and say so")

        let spread = (rows.map(\.residual).max() ?? 0) - (rows.map(\.residual).min() ?? 0)
        print(String(format: "distinct residuals: %d   spread: %.4fpt", distinct.count, spread))
        XCTAssertGreaterThan(spread, 0.1, "the spread is what a single host constant would mis-apply")
    }

    // MARK: - Regression guard

    /// **The invariant that governs the rhythm on screen.** A block's canvas is its used height, and
    /// `EngineBlockSpacing` gives `trailingLineBoxOverhang` back out of every deposit below it — so
    /// `used - overhang` is the height the block occupies in the stack, and it must equal V2's item
    /// height for the same text.
    ///
    /// This is the case a baseline fix breaks silently: re-pinning the line box changes the used
    /// height, and a fix verified only on the first line ships a per-block drift that accumulates.
    /// It holds today and must hold after — under EITHER arm, which is the point: the safe arm keeps
    /// it by construction, and the exact arm only keeps it if the 0.713 shortfall is restored (spec
    /// §5.2).
    ///
    /// Subject to this class's TK1 scope limit — it is a proxy, not the engine's own answer.
    func test_aBlocksStackingHeightMatchesV2sItemHeight() throws {
        let factor = RichTextRenderMetrics.default.body.lineSpacingFactor
        for wordCount in 1...3 {
            let attributed = bodyParagraph(Array(repeating: "Handy", count: wordCount).joined(separator: " "))
            let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
            // Wide enough for one "Handy" (~45pt at 17pt), too narrow for two. The assertion below
            // is what pins that: at 44pt the word itself broke in half and the earlier version of
            // this case passed anyway, because it derived the line count from the height it measured.
            let width = 60.0
            let lines = lineFragmentCount(of: attributed, width: width)
            XCTAssertEqual(lines, wordCount, "fixture must wrap to one line per word")

            let used = usedHeight(of: attributed, width: width)
            let overhang = EngineBlockSpacing.trailingLineBoxOverhang(
                of: attributed.attributes(at: 0, effectiveRange: nil))

            XCTAssertEqual(used - overhang,
                           RichTextRenderMetrics.textHeight(font, factor: factor, lineCount: lines),
                           accuracy: 0.01,
                           "lines=\(lines) used=\(used) overhang=\(overhang)")
        }
    }
}
#endif
