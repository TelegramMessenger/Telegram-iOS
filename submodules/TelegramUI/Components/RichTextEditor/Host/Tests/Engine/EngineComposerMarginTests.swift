import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The composer's `contentMargins` must survive a layout pass.
///
/// Reported from the device: text overflows the composer's right inset while the field's HEIGHT is
/// right, and the caret briefly jumps to where the text should have been when deleting. That pairing
/// is the signature of TWO widths — a measure pass that honours the margins and a render pass that
/// does not — and the flip-flop between them is what the caret is chasing.
@available(iOS 18.4, *)
final class EngineComposerMarginTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    private let size = CGSize(width: 320.0, height: 240.0)
    /// A right inset in the shape the composer uses: it reserves the accessory + send-button strip.
    private let margins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 60.0)

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(origin: .zero, size: size))
        // These cases model the COMPOSER, which owns all horizontal inset itself and therefore sets
        // `contentPageMargin` to 0. It is set explicitly rather than left to the default, which is
        // the DOCUMENT's 16 — relying on that default is what these assertions used to do, silently,
        // back when the engine's default was the composer's value.
        editor.contentPageMargin = 0.0
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func applyUpdateThenLayOut() {
        _ = editor.update(size: size, insets: .zero, contentMargins: margins,
                          scrollIndicatorInsets: nil)
        // The pass that was overwriting the margins. UIKit runs it on its own schedule, so a host
        // never sees it coming.
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
    }

    /// The margins are applied to the engine's TEXT CONTAINER — the mechanism the legacy input node
    /// uses for the identical property — so the engine fills the editor and the padding is interior.
    /// Applying them to the engine's FRAME instead stacked them on the engine's own
    /// `textContainerInset`, which read as the field having extra margins.
    func test_theMarginsSurviveALayoutPass() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "hello")])),
        ])

        applyUpdateThenLayOut()

        XCTAssertEqual(editor.engine.textContainerInset.right, margins.right, accuracy: 0.5,
                       "the applied margins did not survive layoutSubviews")
        XCTAssertEqual(editor.engine.frame.width, size.width, accuracy: 0.5,
                       "the engine should FILL the editor; the margin is interior padding")
    }

    /// The consequence, measured on glyphs rather than on the frame — this is what the user sees.
    func test_textDoesNotRenderPastTheRightContentMargin() {
        let long = String(repeating: "overflowing composer text ", count: 4)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: long)])),
        ])

        applyUpdateThenLayOut()

        let rects = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 0, length: (long as NSString).length))
            .map(\.cgRectValue)
        guard !rects.isEmpty else { return XCTFail("no text geometry") }
        // Engine coordinates -> editor coordinates.
        let rightmost = (rects.map(\.maxX).max() ?? 0.0) + editor.engine.frame.minX

        XCTAssertLessThanOrEqual(rightmost, size.width - margins.right + 0.5,
                                 "text is drawn past the right content margin, into the strip the "
                                 + "composer reserves for its buttons")
    }

    /// CONTROL: with no margins the engine fills its bounds, so the rule above is "respect the
    /// margins", not "always be narrower".
    func test_withoutMarginsTheEngineStillFillsTheEditor() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "hello")])),
        ])

        _ = editor.update(size: size, insets: .zero, contentMargins: .zero, scrollIndicatorInsets: nil)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()

        XCTAssertEqual(editor.engine.frame.width, size.width, accuracy: 0.5)
        XCTAssertEqual(editor.engine.frame.minX, 0.0, accuracy: 0.5)
        XCTAssertEqual(editor.engine.textContainerInset.left, 0.0, accuracy: 0.5)
    }

    /// The height the composer sizes its field from must describe the SAME layout the engine
    /// actually performs. Reported from the device as "the field expands way too early, before the
    /// text reaches the edge" — the signature of a measure that thinks the column is narrower than it
    /// is.
    ///
    /// The margins now live in the engine's `textContainerInset`, so a probe that ALSO subtracts them
    /// from the width counts them twice. Measured directly: the applied layout is 260pt wide
    /// (320 − 60) and the probe re-laid it at 200 (260 − 60).
    func test_theMeasuredHeightMatchesWhatIsActuallyLaidOut() {
        // Long enough that the doubly-narrowed column really does need more lines — otherwise the
        // comparison passes for the wrong reason, which the first version of this test did.
        let long = String(repeating: "wrapping composer text ", count: 8)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: long)])),
        ])

        _ = editor.update(size: size, insets: .zero, contentMargins: margins,
                          scrollIndicatorInsets: nil)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()

        // The REAL laid-out extent. NOT `engine.contentSize.height`, which is floored at the view's
        // own height and so reports the frame height for any short document — a measurement that
        // cannot fail.
        //
        // Includes the space RESERVED around the block: blocks now carry the V2 rhythm as per-block
        // insets, so a block's own frame is no longer the whole of what it occupies. Reading the
        // reserved amount back from the engine keeps this measuring the layout rather than restating
        // the spacing table.
        var reserved = UIEdgeInsets.zero
        if let identifier = editor.engine.tgid_blockIdentifiers.first,
           let value = editor.engine.blockInsets?[identifier] {
            reserved = value.uiEdgeInsetsValue
        }
        let laidOut = editor.engine.id_frameForBlock(at: 0).height
            + reserved.top + reserved.bottom
            + margins.top + margins.bottom
        let probed = editor.height(forWidth: size.width, contentMargins: margins)

        XCTAssertEqual(probed, laidOut, accuracy: 1.0,
                       "the probe disagrees with the layout the engine actually performed — the "
                       + "margins are counted twice, so the field grows before the text reaches "
                       + "the edge")
    }

    /// `height(forWidth:contentMargins:)` is a QUERY and must leave no geometry behind.
    ///
    /// It restores the engine's frame, but restoring a frame does not re-run the block layout, so the
    /// engine was left laid out at the probed width — 200pt against an applied 260pt. The text then
    /// visibly wraps early until something else triggers a pass.
    func test_theProbeLeavesTheAppliedLayoutIntact() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      runs: [TextRun(text: String(repeating: "text ", count: 12))])),
        ])
        _ = editor.update(size: size, insets: .zero, contentMargins: margins,
                          scrollIndicatorInsets: nil)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        let appliedWidth = editor.engine.id_frameForBlock(at: 0).width
        XCTAssertEqual(appliedWidth, size.width - margins.right, accuracy: 1.0,
                       "precondition: the applied layout should span the field minus its margins")

        _ = editor.height(forWidth: size.width, contentMargins: margins)

        XCTAssertEqual(editor.engine.id_frameForBlock(at: 0).width, appliedWidth, accuracy: 1.0,
                       "the probe re-laid the document at its own width and left it there")
    }

    /// The measured height must not CHANGE when a layout pass happens.
    ///
    /// Reported from the device: the field grows after focusing it. The block rhythm is reserved as
    /// per-block insets, and if those are applied as a side effect of laying out, the host's first
    /// measure omits them and a later pass adds them — the field is sized twice, and the second time
    /// is bigger. A measure is a query about the document, not about whether a layout has run yet.
    func test_theMeasuredHeightDoesNotChangeAcrossALayoutPass() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])

        // Measured BEFORE anything lays out, which is what the host does when it sizes the field.
        let beforeLayout = editor.height(forWidth: size.width, contentMargins: margins)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        let afterLayout = editor.height(forWidth: size.width, contentMargins: margins)

        XCTAssertEqual(beforeLayout, afterLayout, accuracy: 0.5,
                       "the field would jump from \(beforeLayout) to \(afterLayout) on the first "
                       + "layout — the rhythm is being reserved too late to be measured")
    }

    /// `renderMetrics` must actually reach the layout.
    ///
    /// The composer sets `edgeSpacingReduction` because V2 gives a top-level paragraph 6pt at each
    /// SEQUENCE EDGE, which in a page is the page's margin but in a composer is padding the input
    /// panel already owns. Stored-but-unread, that 12pt reappeared as unexplained height — the field
    /// measured taller than its text for no reason a user could see.
    ///
    /// Trimming touches the EDGES only, so the interior rhythm stays V2-exact; that is the property
    /// asserted here, not a particular height.
    func test_theEdgeSpacingReductionReachesTheLayout() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])
        let untrimmed = editor.height(forWidth: size.width, contentMargins: margins)

        var metrics = RichTextRenderMetrics.default
        metrics.edgeSpacingReduction = 6.0
        editor.renderMetrics = metrics
        let trimmed = editor.height(forWidth: size.width, contentMargins: margins)

        XCTAssertEqual(untrimmed - trimmed, 12.0, accuracy: 1.0,
                       "trimming 6 at each of the two sequence edges should remove 12pt; "
                       + "untrimmed=\(untrimmed) trimmed=\(trimmed)")

        // …and ONLY the edges: the two paragraphs keep V2's gap between them.
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        let first = editor.engine.id_frameForBlock(at: 0)
        let second = editor.engine.id_frameForBlock(at: 1)
        let interior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                                    kind: .topLevel, metrics: metrics)
        // Less the first paragraph's trailing overhang: a frame's bottom is one empty line-box band
        // below its glyphs and the rhythm gives that band back, so this frame-to-frame gap is
        // NEGATIVE where the rhythm is 1pt — the boxes overlap by the empty part (2026-09-15).
        XCTAssertEqual(second.minY - first.maxY,
                       interior - editor.trailingLineBoxOverhang(atRole: 0), accuracy: 0.5,
                       "the interior rhythm must survive the edge trim")
    }

    /// With the composer's own metrics, a one-line field is exactly its text — no phantom padding.
    /// This is the number the input panel is designed around; the panel supplies the padding itself.
    func test_aOneLineFieldUnderComposerMetricsHasNoEdgePadding() {
        var metrics = RichTextRenderMetrics.default
        metrics.edgeSpacingReduction = 6.0
        editor.renderMetrics = metrics
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()

        let measured = editor.height(forWidth: size.width, contentMargins: .zero)
        // The block's FRAME is its pinned line box, which is taller than the text by the trailing
        // overhang — the phantom padding this test exists to refuse. The field measures the
        // renderer's item, which is what the input panel is designed around (2026-09-15).
        let text = editor.engine.id_frameForBlock(at: 0).height - editor.trailingLineBoxOverhang(atRole: 0)
        XCTAssertEqual(measured, text, accuracy: 1.0,
                       "a one-line field should measure its text and nothing more; "
                       + "measured=\(measured) text=\(text)")
        XCTAssertEqual(text, RichTextRenderMetrics.textHeight(
            editor.bridge.styleSheet.font(for: .body, attributes: .plain),
            factor: metrics.body.lineSpacingFactor, lineCount: 1), accuracy: 0.01,
                       "and that is exactly V2's one-line item")
    }

    // MARK: contentPageMargin — the editor's OWN horizontal page margin

    /// Additive to the host's `contentMargins`, exactly as the legacy canvas derives its content
    /// width (`bounds.width - (pageMargin + margins.left) - (pageMargin + margins.right)`).
    ///
    /// It was stored and never read. The composer zeroes it, so nothing showed there; the full-page
    /// article editor keeps the 16pt default AND passes `contentMargins` with left/right 0, so its
    /// side insets came entirely from this property — and it had essentially none.
    private func textLeftEdge() -> CGFloat? {
        editor.engine.id_rects(forCanonicalRange: NSRange(location: 0, length: 3))
            .map(\.cgRectValue.minX).min()
    }

    private func applyPageMargin(_ pageMargin: CGFloat) {
        editor.contentPageMargin = pageMargin
        _ = editor.update(size: size, insets: .zero, contentMargins: .zero,
                          scrollIndicatorInsets: nil)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
    }

    func test_thePageMarginInsetsTheText() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "abc")])),
        ])

        applyPageMargin(0.0)
        guard let bare = textLeftEdge() else { return XCTFail("no geometry") }
        applyPageMargin(16.0)
        guard let margined = textLeftEdge() else { return XCTFail("no geometry") }

        XCTAssertEqual(margined - bare, 16.0, accuracy: 0.5,
                       "the page margin moves the text in from the editor's leading edge")
    }

    /// And it narrows the COLUMN, not just the origin — the half a caller measuring its own height
    /// depends on. `contentMargins` is applied for the duration of a probe, so the page margin has
    /// to be folded in at the same place or a probe measures a wider column than the text will get.
    func test_thePageMarginNarrowsTheMeasuredColumn() {
        let long = String(repeating: "word ", count: 40)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: long)])),
        ])

        editor.contentPageMargin = 0.0
        let bare = editor.height(forWidth: size.width, contentMargins: .zero)
        editor.contentPageMargin = 40.0
        let margined = editor.height(forWidth: size.width, contentMargins: .zero)

        XCTAssertGreaterThan(margined, bare,
                             "a narrower column wraps more lines, so the measured height grows")
    }

}
