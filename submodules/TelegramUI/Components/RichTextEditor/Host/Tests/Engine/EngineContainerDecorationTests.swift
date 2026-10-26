import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7, slice 2: containers are decorated by REAL VIEWS, one per container block.
///
/// The requirement is explicit — decoration must not be composited into a shared canvas — so these
/// assert on the view hierarchy, not on a colour in the text bitmap.
///
/// They also pin the parenting, which is the part that is easy to get wrong invisibly: `IDBlockTextView`
/// is a `UIScrollView` and `id_frameForBlockAtIndex:` answers in its CONTENT space, so a decoration view
/// parented to the editor (outside the scroll view) is correct only while `contentOffset` is zero and
/// slides out from under its text as soon as the field scrolls.
@available(iOS 18.4, *)
final class EngineContainerDecorationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func decorations() -> [ContainerDecorationView] {
        editor.engine.subviews.compactMap { $0 as? ContainerDecorationView }
    }

    /// What `RichTextEditorChatInputNode` sets on the real editor. A compact host cannot let the band
    /// bleed outward past the field, so it indents the code inward instead — see `CodeStyle`.
    private let composerCodeStyle = CodeStyle(horizontalBleed: 0.0, horizontalInset: 8.0,
                                              cornerRadius: 4.0)

    /// The engine block holding a code block's CODE.
    ///
    /// A code block occupies TWO engine blocks — its language line, then the code — so the code is
    /// not at the container's own document index. Resolved from the roles rather than hardcoded, so
    /// these cases keep saying "the code" whatever else the container grows.
    /// The container's FIRST engine block — its language line. The band's top edge is measured from
    /// here, not from the code, because the line is inside the container.
    private var codeUnitTopIndex: UInt {
        let id = editor.currentRoles.first {
            if case .block(.code) = $0.container { return true }
            return false
        }?.containerID
        let index = editor.currentRoles.firstIndex { $0.containerID == id }
        return UInt(index ?? 0)
    }

    private var codeIndex: UInt {
        let index = editor.currentRoles.firstIndex { role in
            guard role.secondaryKind == nil, case .block(.code) = role.container else { return false }
            return true
        }
        return UInt(index ?? 0)
    }

    private func layOut() {
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
    }

    func test_aCodeBlockGetsItsOwnDecorationView() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        XCTAssertEqual(decorations().count, 1,
                       "exactly one decoration view, for the one container block")
    }

    /// THE CONTROL. Without it, a sync that decorated EVERY block would pass the test above.
    func test_aDocumentOfPlainParagraphsGetsNoDecorationAtAll() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])
        layOut()

        XCTAssertEqual(decorations().count, 0,
                       "a paragraph is not a container and must not be decorated")
    }

    /// The decoration must cover the block it decorates. A view that exists but sits at the origin
    /// with a zero size is the failure this catches — and it is exactly what a `CGRectZero` answer
    /// from the engine would have produced, which is why that accessor returns `CGRectNull`.
    func test_theDecorationCoversItsOwnBlock() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let decoration = decorations().first else { return XCTFail("no decoration view") }
        let blockFrame = editor.engine.id_frameForBlock(at: 1)
        XCTAssertFalse(blockFrame.isNull)
        XCTAssertGreaterThan(decoration.frame.height, 0.0)
        XCTAssertGreaterThan(decoration.frame.width, 0.0)
        // The band covers its block's box PLUS the interior padding reserved around it — the padding
        // is inside the container, so a band that hugged the glyphs would leave it unpainted.
        // Containment, not equality: a code band BLEEDS horizontally past its text by
        // design — `test_aDocumentHostsCodeBandBleedsToTheCanvasEdgeAndIsSquare` owns that
        // shape — so the two frames are equal on no axis.
        XCTAssertTrue(decoration.frame.contains(blockFrame),
                      "the decoration must cover its block's box: \(decoration.frame) vs \(blockFrame)")
        XCTAssertGreaterThan(decoration.frame.minY, 0.0,
                             "the second block cannot start at the top of the document; a zero "
                             + "origin means the frame was never really resolved")
    }

    /// Decoration is parented INTO the scroll content, so it scrolls with the text it decorates.
    func test_decorationIsParentedIntoTheScrollContentNotTheEditor() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "code")])),
        ])
        layOut()

        guard let decoration = decorations().first else { return XCTFail("no decoration view") }
        XCTAssertTrue(decoration.superview === editor.engine,
                      "parented to the editor instead of the scroll content: the band would stay "
                      + "put while its block scrolls away")
        XCTAssertFalse(editor.subviews.contains { $0 is ContainerDecorationView },
                       "no decoration should be a direct child of the editor view")
    }

    /// Decoration draws BEHIND the text, or it paints over the code it is meant to sit under.
    func test_decorationSitsBehindTheText() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "code")])),
        ])
        layOut()

        guard let decoration = decorations().first,
              let decorationIndex = editor.engine.subviews.firstIndex(of: decoration) else {
            return XCTFail("no decoration view")
        }
        let others = editor.engine.subviews.enumerated()
            .filter { !($0.element is ContainerDecorationView) }
            .map(\.offset)
        XCTAssertFalse(others.isEmpty, "the engine has no other subviews to be behind")
        for index in others {
            XCTAssertLessThan(decorationIndex, index,
                              "decoration must be below every other engine subview, or it covers "
                              + "the glyphs it is decorating")
        }
    }

    /// Removing the container removes its view — the cull half of the pool.
    func test_theDecorationGoesAwayWithItsBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "code")])),
        ])
        layOut()
        XCTAssertEqual(decorations().count, 1)

        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "plain")])),
        ])
        layOut()

        XCTAssertEqual(decorations().count, 0,
                       "the band outlived its block and is now decorating a paragraph")
    }

    /// The band needs PADDING, or the code sits flush against its own background and reads as broken.
    /// The legacy composer insets code text 8pt inside the band (`CodeStyle.horizontalInset`), and the
    /// decoration view cannot produce that — it is a background BEHIND the text, so the padding has to
    /// come from the text's own layout.
    ///
    /// **Measured as a DIFFERENCE against a plain paragraph, deliberately.** An absolute threshold
    /// here was calibrated against the text container's 5pt `lineFragmentPadding`, and became wrong
    /// the moment the composer host zeroed that: the assertion was pinning a baseline it did not own.
    /// The difference is what this feature actually controls.
    ///
    /// **The measurement is the subtle part.** A selection rect for a FULLY covered line is the line
    /// FRAGMENT, which runs to the container's edges, so the union of a wrapped selection's rects
    /// reports the container inset and never reveals a head indent. Both probes are therefore short,
    /// single-line, glyph-hugging text.
    ///
    /// Vertical padding is deliberately not asserted: it is 0 and cannot be fixed from here — see
    /// `EngineDocumentBridge.horizontalInset`.
    func test_aCodeBlockIndentsItsTextFurtherThanAParagraph() {
        editor.codeStyle = composerCodeStyle
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "abc")])),
        ])
        layOut()
        guard let paragraphText = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 0, length: 3))
            .map(\.cgRectValue).first else { return XCTFail("no paragraph geometry") }
        let paragraphInset = paragraphText.minX - editor.engine.id_frameForBlock(at: 0).minX

        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "abc")])),
        ])
        layOut()
        guard let codeText = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 0, length: 3))
            .map(\.cgRectValue).first else { return XCTFail("no code geometry") }
        let codeInset = codeText.minX - editor.engine.id_frameForBlock(at: codeIndex).minX

        XCTAssertEqual(codeInset - paragraphInset, 8.0, accuracy: 1.0,
                       "a code block must indent its text by the host's CodeStyle.horizontalInset "
                       + "beyond a plain paragraph, so the code does not sit flush against its band")
    }


    /// The trailing inset, asserted on the RENDER PATH rather than on geometry.
    ///
    /// It cannot be measured the way the leading inset is. A selection rect for a fully covered line
    /// is the line FRAGMENT, and the fragment runs to the container's edge whether or not
    /// `tailIndent` moved the wrap point — measured directly: the text wraps into the narrower column
    /// while `band.maxX - widestRect.maxX` still reports the bare 5pt container padding. Comparing
    /// line counts against a paragraph does not work either, since a code block is monospaced and
    /// would wrap differently on the font alone.
    ///
    /// So this reads what the canvas actually draws. `id_renderedTextForBlockAtIndex:` exists for
    /// precisely this — verifying decoration end to end — and it is a stronger check than testing the
    /// bridge's output in isolation, which is how three presentation designs on this project shipped
    /// green and broken.
    func test_theRenderedCodeBlockCarriesBothHorizontalIndents() {
        editor.codeStyle = composerCodeStyle
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "abc")])),
        ])
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else {
            return XCTFail("the rendered code block carries no paragraph style at all")
        }
        XCTAssertEqual(style.headIndent, 8.0, "wrapped lines would start at the band's edge")
        XCTAssertEqual(style.tailIndent, -8.0,
                       "negative measures from the trailing edge; 0 would let text run to the band")
    }

    /// A code block's vertical geometry composes the same two shared quantities a quote's does: the
    /// gap SEPARATING it from its neighbour, from the renderer's spacing table, plus its INTERIOR
    /// padding from the stylesheet (`codeVerticalInset`, which resolves to the shared code metrics).
    ///
    /// This was recorded as unreachable when code blocks were added — TextKit ignores
    /// `paragraphSpacingBefore` on a container's first paragraph and trailing spacing does not extend
    /// the used height, both measured — and became reachable once the engine could reserve space
    /// around a block.
    func test_aCodeBlocksVerticalGeometryComposesTheSharedSpacingAndItsInteriorPadding() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "above")])),
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        let metrics = RichTextRenderMetrics.default
        let exterior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .preformatted,
                                                    kind: .topLevel, metrics: metrics)
        let above = editor.engine.id_frameForBlock(at: 0)
        // The unit's TOP block — its language line — because that is where the container starts.
        let code = editor.engine.id_frameForBlock(at: codeUnitTopIndex)
        // The interior padding is read off the BAND, which is drawn around exactly the space
        // reserved for it — so this asserts the two quantities COMPOSE, without restating how the
        // interior one is computed (`test_theCodeBandsPaddingSubtractsTheFontBoxOverhead` owns that).
        guard let band = decorations().first?.frame else { return XCTFail("no band") }
        let interior = code.minY - band.minY
        XCTAssertGreaterThan(interior, 0.0, "precondition: there is interior padding to compose with")
        XCTAssertGreaterThan(exterior, 0.0, "precondition: and a shared gap to compose it with")

        // Less the paragraph's trailing overhang — a frame's bottom is one empty line-box band below
        // its glyphs, and every space below a block gives that band back (2026-09-15).
        XCTAssertEqual(code.minY - above.maxY,
                       exterior + interior - editor.trailingLineBoxOverhang(atRole: 0), accuracy: 1.0,
                       "the space above a code block is the shared gap PLUS its interior padding")
    }

    /// …and its band covers that padding, rather than hugging the code inside it.
    func test_theCodeBandCoversItsVerticalPadding() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let band = decorations().first?.frame else { return XCTFail("no band") }
        let code = editor.engine.id_frameForBlock(at: codeUnitTopIndex)
        XCTAssertGreaterThan(code.minY - band.minY, 0.0,
                             "the band should extend above the code by its interior padding")
        XCTAssertGreaterThan(band.maxY - code.maxY, 0.0, "and below it")
        XCTAssertLessThan(code.minY - band.minY, RichTextRenderMetrics.default.code.verticalInset,
                          "but by LESS than the raw inset: the block frame already carries the "
                          + "font-box overhead, which the padding subtracts")
    }

    /// `codeStyle` is the host's knob over that padding, exactly as it is for the legacy canvas. It
    /// was stored-but-never-read, so the composer's own `CodeStyle` was inert and the bridge carried
    /// a private copy of its horizontal inset as a constant — two spellings of one value.
    func test_theHostsCodeStyleDrivesTheCodeBlocksPadding() {
        let document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        let baselineInset = RichTextRenderMetrics.default.code.verticalInset
        editor.codeStyle = CodeStyle(verticalInset: baselineInset, horizontalInset: 20.0)
        editor.document = document
        layOut()
        guard let bandBefore = decorations().first?.frame else { return XCTFail("no band") }
        let paddingBefore = editor.engine.id_frameForBlock(at: codeIndex).minY - bandBefore.minY

        editor.codeStyle = CodeStyle(verticalInset: baselineInset + 16.0, horizontalInset: 20.0)
        layOut()
        guard let band = decorations().first?.frame else { return XCTFail("no band") }
        let code = editor.engine.id_frameForBlock(at: codeIndex)
        // Asserted as the DIFFERENCE the host's value makes, which cannot be satisfied by a constant
        // and does not restate the font-box correction the padding also applies.
        XCTAssertEqual((code.minY - band.minY) - paddingBefore, 16.0, accuracy: 0.5,
                       "the host's verticalInset should drive the padding, not the metrics default")

        guard let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex) else {
            return XCTFail("no rendered text")
        }
        let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent ?? 0.0, 20.0, accuracy: 0.5,
                       "and its horizontalInset should drive the code's own indent")
    }

    /// A code block's TEXT is 15pt Menlo, not body-sized sans with a monospace face swapped over it.
    ///
    /// `RichTextRenderMetrics.codeBlock` carries `(monospace, 15, lineSpacingFactor 1.0)` because
    /// V2's `layoutCodeBlock` overrides the theme's nominal 14pt with an absolute 15 — the same step
    /// down from body that a quote takes. Rendering the block through the BODY spec and then
    /// substituting the face kept body's 17pt and body's line pitch, so the code read a size too
    /// large and spaced for a font it was no longer set in.
    func test_aCodeBlockRendersInTheCodeMetricsFontNotTheBodyFont() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return XCTFail("the rendered code block carries no font")
        }
        let spec = RichTextRenderMetrics.default.codeBlock
        XCTAssertEqual(font.pointSize, spec.size, accuracy: 0.01,
                       "code is \(spec.size)pt, one step below body — like a quote")
        XCTAssertEqual(font.familyName, "Menlo",
                       "the renderer resolves .monospace to Menlo; a system monospace face is a "
                       + "different typeface at the same size")
    }

    /// …and the line pitch follows that font, which is the half a face swap cannot reach: the pinned
    /// line height lives in the paragraph style, derived from whichever font the mapper laid out.
    func test_aCodeBlocksLinePitchFollowsTheCodeFont() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph style") }
        // Derived from the font the block is actually SET in, so the assertion is "the pitch matches
        // this text's own font" rather than a transcription of the expected number.
        guard let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return XCTFail("no font")
        }
        let metrics = RichTextRenderMetrics.default
        let expected = RichTextRenderMetrics.linePitch(font, factor: metrics.codeBlock.lineSpacingFactor)
        // The PITCH is the pinned box plus the remainder: `v2BaselinePlacedStyle` splits V2's pitch
        // into a smaller box and a `lineSpacing` carrying the difference, so `maximumLineHeight`
        // alone is the box. The claim under test is unchanged — this text's advance comes from the
        // CODE spec and not from body's.
        XCTAssertEqual(style.maximumLineHeight + style.lineSpacing, expected, accuracy: 0.01,
                       "the pitch must come from the code spec, not from body's")
        XCTAssertEqual(style.minimumLineHeight, style.maximumLineHeight, accuracy: 0.01,
                       "the box stays pinned — only where the remainder lives changed")

        let bodyPitch = RichTextRenderMetrics.linePitch(
            UIFont.systemFont(ofSize: metrics.body.size), factor: metrics.body.lineSpacingFactor)
        XCTAssertNotEqual(expected, bodyPitch, accuracy: 0.01,
                          "precondition: if the two pitches agreed this test could not fail")
    }

    /// The padding subtracts the font-box overhead, exactly as `layoutCodeBlock` does.
    ///
    /// `verticalInset` is the VISIBLE gap — band edge to the cap line at the top, to the baseline at
    /// the bottom — and V2 reaches it by subtracting `instantPageV2TextBoxOverheads` from the inset
    /// before applying it, because a text item's frame is a font line box with ascent headroom above
    /// the caps and descent below the last baseline. Reserving the raw inset around a box that
    /// ALREADY carries that headroom adds the overhead twice and the block reads far too tall.
    func test_theCodeBandsPaddingSubtractsTheFontBoxOverhead() {
        editor.codeStyle = composerCodeStyle
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let band = decorations().first?.frame,
              let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return XCTFail("no band or no rendered font")
        }
        let code = editor.engine.id_frameForBlock(at: codeIndex)
        let inset = RichTextRenderMetrics.default.code.verticalInset
        // From the LANGUAGE line's font, not the code's: that line is first, so its ascent headroom
        // is the one the band's top edge sits above. `layoutCodeBlock` picks the same font for the
        // same reason.
        let languageFont = UIFont.systemFont(ofSize: RichTextRenderMetrics.default.body.size,
                                             weight: .semibold)
        let overheadTop = max(0.0, languageFont.ascender - languageFont.capHeight)
        let overheadBottom = max(0.0, -font.descender)
        XCTAssertGreaterThan(overheadTop, 0.0, "precondition: the face has ascent headroom to subtract")

        XCTAssertEqual(editor.engine.id_frameForBlock(at: codeUnitTopIndex).minY - band.minY,
                       inset - overheadTop, accuracy: 0.5,
                       "the reserved top padding is the inset LESS the ascent headroom the box "
                       + "already contains")
        XCTAssertEqual(band.maxY - code.maxY,
                       inset - overheadBottom - editor.trailingLineBoxOverhang(atRole: editor.currentRoles.count - 1),
                       accuracy: 0.5,
                       "and the bottom padding is the inset less the descent")
    }

    /// A later theme push must not discard the host's other configuration.
    ///
    /// The theme is a MAPPER input, and the mapper also carries the stylesheet — the code geometry,
    /// the quote geometry and the render metrics. Rebuilding it from the theme ALONE silently reset
    /// every one of them, and the composer pushes a theme on each presentation update, long after it
    /// configures the editor. The horizontal inset vanishing in the composer is how this surfaced.
    func test_aThemePushKeepsTheHostsCodeStyleAndMetrics() {
        editor.codeStyle = composerCodeStyle
        var metrics = RichTextRenderMetrics.default
        metrics.edgeSpacingReduction = 6.0
        editor.renderMetrics = metrics
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()
        let heightBefore = editor.engine.id_frameForBlock(at: codeIndex)

        var themed = RichTextEditorTheme.default
        themed.primaryText = .red
        editor.theme = themed
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph style after theming") }
        XCTAssertEqual(style.headIndent, composerCodeStyle.horizontalInset, accuracy: 0.5,
                       "the code's horizontal inset must survive a theme push")
        XCTAssertEqual(editor.engine.id_frameForBlock(at: codeIndex), heightBefore,
                       "and so must the render metrics, which place the block")

        let colored = rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(colored, .red, "precondition: the theme really was applied")
    }

    /// A pull quote is a content-hugging centred pill with a corner mark at each end — not a
    /// full-width tinted band.
    ///
    /// V2 lays it out that way (`layoutQuote`'s `isPull` arm: a rounded pill whose width is the
    /// widest laid-out line plus `pullQuotePadding` on each side, capped at the available width,
    /// with `RichText/QuoteOpen` at the top-left and `RichText/QuoteClose` at the bottom-right), and
    /// so does the legacy editor, whose `PullQuoteStyle` carries the same numbers. The engine drew
    /// the tinted field and nothing else.
    func test_aPullQuoteHugsItsContentAndCarriesCornerMarks() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "short")])),
        ])
        layOut()

        guard let decoration = decorations().first else { return XCTFail("no decoration") }
        let block = editor.engine.id_frameForBlock(at: 0)
        XCTAssertLessThan(decoration.frame.width, block.width - 1.0,
                          "the pill must hug its content, not span the whole column")
        XCTAssertEqual(decoration.frame.midX, block.midX, accuracy: 1.0,
                       "and it is centred, like the text inside it")
        XCTAssertEqual(decoration.subviews.compactMap { $0 as? PullQuoteMarksView }.count, 1,
                       "a pull quote carries its two corner quote marks")
    }

    /// Its text is inset from the pill's edges, and the pill reserves vertical room around it.
    func test_aPullQuoteInsetsItsTextHorizontallyAndReservesVerticalRoom() {
        let style = PullQuoteStyle.default
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "short")])),
        ])
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: 0),
              let paragraph = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph style") }
        XCTAssertEqual(paragraph.headIndent, style.horizontalPadding, accuracy: 0.5,
                       "the text is measured inside the pill's horizontal padding")
        XCTAssertEqual(paragraph.tailIndent, -style.horizontalPadding, accuracy: 0.5)

        guard let decoration = decorations().first else { return XCTFail("no decoration") }
        // A pull quote with any content owns TWO engine blocks — the quote and its author line — and
        // the pill spans both, so each edge is measured against the block on that side.
        let block = editor.engine.id_frameForBlock(at: 0)
        let last = editor.engine.id_frameForBlock(
            at: UInt(editor.engine.attributedBlocks.count - 1))
        XCTAssertEqual(block.minY - decoration.frame.minY, style.topInset, accuracy: 1.0,
                       "the pill extends above the text by its top inset")
        XCTAssertEqual(decoration.frame.maxY - last.maxY,
                       style.bottomInset - editor.trailingLineBoxOverhang(atRole: editor.currentRoles.count - 1),
                       accuracy: 1.0,
                       "and below its last line by its bottom inset")
    }

    // MARK: The two hosts' code bands are deliberately different shapes

    /// A DOCUMENT host's code band bleeds to the canvas edge and is square.
    ///
    /// That is what `CodeStyle`'s defaults mean — `horizontalBleed: nil` is documented as "reaches
    /// the CANVAS edge, the document-editor look, and what the InstantPage V2 renderer does in a
    /// bubble", with `cornerRadius: 0` square to match. The article editor sets no `codeStyle` at
    /// all, so it is asking for exactly this; the engine hardcoded the COMPOSER's 4pt radius and
    /// never read the bleed, so it drew a rounded band inset to the text column instead.
    func test_aDocumentHostsCodeBandBleedsToTheCanvasEdgeAndIsSquare() {
        editor.contentPageMargin = 16.0
        _ = editor.update(size: CGSize(width: 320.0, height: 240.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil)
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let decoration = decorations().first else { return XCTFail("no decoration") }
        let block = editor.engine.id_frameForBlock(at: codeIndex)
        XCTAssertGreaterThan(block.minX, 8.0,
                            "precondition: the TEXT is inset by the page margin, so a band that "
                            + "merely matched the block would not be flush")
        XCTAssertEqual(decoration.frame.minX, 0.0, accuracy: 0.5,
                       "the band reaches the container's leading edge")
        XCTAssertEqual(decoration.frame.width, editor.engine.bounds.width, accuracy: 0.5,
                       "and spans it edge to edge")
        XCTAssertEqual(decoration.layer.cornerRadius, 0.0, accuracy: 0.01,
                       "square, per CodeStyle's default")
    }

    /// A COMPACT host's spans exactly the text column and is rounded — it cannot bleed, because its
    /// canvas sits inside the input field's own rounded background.
    func test_aCompactHostsCodeBandSpansTheTextColumnAndIsRounded() {
        editor.codeStyle = composerCodeStyle
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let decoration = decorations().first else { return XCTFail("no decoration") }
        let block = editor.engine.id_frameForBlock(at: codeIndex)
        XCTAssertEqual(decoration.frame.minX, block.minX, accuracy: 0.5)
        XCTAssertEqual(decoration.frame.width, block.width, accuracy: 0.5,
                       "no bleed: the band is the text column")
        XCTAssertEqual(decoration.layer.cornerRadius, composerCodeStyle.cornerRadius, accuracy: 0.01,
                       "and carries the host's radius")
    }

    /// A code block's language line sits at the same x as the code it names.
    ///
    /// The band's side padding is applied to the CODE's paragraphs; the language line was rendered
    /// without it, so the label hung to the left of everything it labels. `layoutCodeBlock` places
    /// both at one `localTextX`.
    func test_theLanguageLineSitsAtTheSameXAsTheCode() {
        editor.codeStyle = composerCodeStyle
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift",
                            runs: [TextRun(text: "let x = 1")])),
        ])
        layOut()

        guard let language = editor.engine.id_renderedTextForBlock(at: 0),
              let code = editor.engine.id_renderedTextForBlock(at: codeIndex),
              let languageStyle = language.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle,
              let codeStyle = code.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph styles") }

        XCTAssertGreaterThan(codeStyle.headIndent, 0.0, "precondition: the code IS inset")
        XCTAssertEqual(languageStyle.headIndent, codeStyle.headIndent, accuracy: 0.5,
                       "the language line takes the code's inset")
        XCTAssertEqual(languageStyle.firstLineHeadIndent, codeStyle.firstLineHeadIndent,
                       accuracy: 0.5)
    }

    /// And a placeholder sits where its line's TEXT will, not at the block's leading edge.
    func test_theAuthorPlaceholderSitsWhereTheAuthorTextWill() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        layOut()
        let authored = editor.engine.id_rects(forCanonicalRange: NSRange(location: 7, length: 3))
            .map(\.cgRectValue.minX).min()

        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ])),
        ])
        layOut()
        let label = editor.engine.subviews.compactMap { $0 as? SecondaryPlaceholderLabel }.first

        guard let authored, let label else { return XCTFail("no author geometry") }
        XCTAssertGreaterThan(authored, 1.0, "precondition: the author text IS inset")
        XCTAssertEqual(label.frame.minX, authored, accuracy: 1.0,
                       "the prompt stands exactly where the text it stands in for would")
    }

    /// A pull quote's caret sits on its glyphs, not at the left margin.
    ///
    /// Reported from the device: the cursor lands correctly on the LAST character of a centred pull
    /// quote and at the left everywhere else — which is where it would be if the line were
    /// left-aligned.
    func test_thePullQuotesCaretSitsOnItsCentredGlyphs() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "abcdef")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let firstThree = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 0, length: 3))
            .map(\.cgRectValue).first,
              let position = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                    offset: 3) else {
            return XCTFail("no geometry")
        }
        let glyphEnd = firstThree.maxX
        XCTAssertGreaterThan(firstThree.minX, 40.0,
                             "precondition: the pull quote IS centred, not at the margin")
        XCTAssertEqual(editor.engine.caretRect(for: position).minX, glyphEnd, accuracy: 2.0,
                       "the caret belongs where those characters end")
    }

    /// Tapping a centred pull quote lands on the character tapped.
    ///
    /// The caret RECT is right; what a tap resolves to is the other half. If a point is mapped as
    /// though the line began at the left margin, every tap on a centred line resolves to an offset
    /// near its start and the caret is then drawn — correctly — at that wrong place.
    func test_tappingACentredPullQuoteLandsOnTheCharacterTapped() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "abcdef")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // The third character's own box, in the engine's coordinates.
        guard let third = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 2, length: 1))
            .map(\.cgRectValue).first else { return XCTFail("no glyph geometry") }
        XCTAssertGreaterThan(third.minX, 40.0, "precondition: the line IS centred")

        let point = CGPoint(x: third.midX, y: third.midY)
        guard let position = editor.engine.closestPosition(to: point) else {
            return XCTFail("no position for \(point)")
        }
        let offset = editor.engine.offset(from: editor.engine.beginningOfDocument, to: position)
        XCTAssertTrue(offset == 2 || offset == 3,
                      "a tap on the third character should land on it, got offset \(offset)")
    }

    /// Every offset of a WRAPPED centred pull quote gets a caret on its own glyphs.
    ///
    /// A single short line was not enough to reproduce what the device shows. Each wrapped line is
    /// centred by a different amount, so a caret placed from a line-independent measurement is wrong
    /// by a different amount on each one — and right only where the two happen to coincide.
    func test_everyOffsetOfAWrappedPullQuoteHasACaretOnItsGlyphs() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [
                TextRun(text: "the quick brown fox jumps over the lazy dog and keeps running"),
            ])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let length = editor.engine.attributedBlocks.first?.length ?? 0
        XCTAssertGreaterThan(length, 20, "precondition: there is text")
        var wrongAt: [Int] = []
        var detail = ""
        for offset in 1..<length {
            guard let glyph = editor.engine
                .id_rects(forCanonicalRange: NSRange(location: offset - 1, length: 1))
                .map(\.cgRectValue).first,
                  let position = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                        offset: offset) else { continue }
            let caret = editor.engine.caretRect(for: position)
            // A caret belongs at the trailing edge of the character BEFORE it, or — at a wrap, where
            // it legitimately moves down a line — at the leading edge of the character AFTER it.
            // Anything else is off its glyphs.
            let next = editor.engine
                .id_rects(forCanonicalRange: NSRange(location: offset, length: 1))
                .map(\.cgRectValue).first
            let onGlyph = abs(caret.minX - glyph.maxX) < 2.0
                || next.map { abs(caret.minX - $0.minX) < 2.0 } ?? false
            if !onGlyph {
                wrongAt.append(offset)
                if wrongAt.count == 1 {
                    detail = "offset \(offset): caret.minX=\(caret.minX) "
                        + "glyph=[\(glyph.minX), \(glyph.maxX)] glyphY=\(glyph.minY) "
                        + "caretY=\(caret.minY)"
                }
            }
        }
        XCTAssertTrue(wrongAt.isEmpty, "carets off their glyphs at \(wrongAt.count) offsets; "
                      + "first \(detail)")
    }

    /// An empty pull-quote author's caret sits at the START of "Add author", not in its middle.
    ///
    /// The prompt is centred on the line, so the insertion point the line's own alignment produces
    /// is its MIDDLE. Legacy makes the same distinction with `emptyLineLeadingIndent`.
    func test_theEmptyAuthorsCaretSitsAtTheStartOfItsPrompt() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let label = editor.engine.subviews
            .compactMap({ $0 as? SecondaryPlaceholderLabel }).first,
              let position = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                    offset: 10) else {
            return XCTFail("no prompt")
        }
        // Where the centred prompt's text actually begins inside its (centred) label.
        let promptWidth = (label.text ?? "").size(withAttributes: [.font: label.font as Any]).width
        let promptStart = label.frame.midX - promptWidth / 2.0

        XCTAssertGreaterThan(promptWidth, 10.0, "precondition: there IS a prompt")
        XCTAssertEqual(editor.engine.caretRect(for: position).minX, promptStart, accuracy: 2.0,
                       "the caret belongs where the prompt starts")
    }

    /// A pull quote's author line is measured inside the same padding as its body.
    ///
    /// The body's text is measured inside `PullQuoteStyle.horizontalPadding` so the pill can hug it;
    /// the author line was rendered without that, so it was measured against the full column and a
    /// long attribution ran past the padding the quote above it respects.
    func test_thePullQuotesAuthorTakesTheSameInsetsAsItsBody() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")],
                                 author: [TextRun(text: "Ada")])),
        ])
        layOut()

        guard let body = editor.engine.id_renderedTextForBlock(at: 0),
              let author = editor.engine.id_renderedTextForBlock(at: 1),
              let bodyStyle = body.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle,
              let authorStyle = author.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph styles") }

        XCTAssertGreaterThan(bodyStyle.headIndent, 0.0, "precondition: the body IS inset")
        XCTAssertEqual(authorStyle.headIndent, bodyStyle.headIndent, accuracy: 0.5,
                       "the author takes the quote's leading inset")
        XCTAssertEqual(authorStyle.tailIndent, bodyStyle.tailIndent, accuracy: 0.5,
                       "and its trailing one")
        XCTAssertEqual(authorStyle.firstLineHeadIndent, bodyStyle.firstLineHeadIndent, accuracy: 0.5)
    }

    /// Typing into an EMPTY pull quote produces centred, padded quote text.
    ///
    /// An empty pull quote is what the article editor's Format command makes. Reported from the
    /// device: the text typed into one comes out at the container's left edge rather than centred
    /// inside the pill.
    func test_typingIntoAnEmptyPullQuoteProducesCentredQuoteText() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
        editor.engine.insertText("Q")
        layOut()

        guard let rendered = editor.engine.id_renderedTextForBlock(at: 0),
              let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no paragraph style") }
        XCTAssertEqual(style.alignment, .center, "quote text is centred")
        XCTAssertEqual(style.headIndent, PullQuoteStyle.default.horizontalPadding, accuracy: 0.5,
                       "and sits inside the pill's padding")
    }

    /// …and it gains an author line, because there is something to attribute now.
    func test_typingIntoAnEmptyPullQuoteRestoresItsAuthorLine() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [])),
        ])
        layOut()
        XCTAssertEqual(editor.engine.attributedBlocks.count, 1, "precondition: no author line yet")
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
        editor.engine.insertText("Q")

        let settled = expectation(description: "presence reconciled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)
        layOut()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the quote has content, so it has an author line")
    }

    /// An empty author line's PROMPT sets the pill's minimum width while the field is visible.
    ///
    /// The pill hugs the wider of its lines, and an empty line measures zero — so a short quote drew
    /// a pill narrower than the "Add author" it was displaying, and clipped it. Legacy counts the
    /// placeholder as that line's content for exactly this (`pillContentWidth`).
    func test_theAuthorPromptSetsThePullQuotesMinimumWidth() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "hi")])),
        ])
        layOut()

        guard let band = decorations().first?.frame,
              let label = editor.engine.subviews
                  .compactMap({ $0 as? SecondaryPlaceholderLabel }).first else {
            return XCTFail("no pill or no prompt")
        }
        let promptWidth = (label.text ?? "").size(withAttributes: [.font: label.font as Any]).width
        let padding = PullQuoteStyle.default.horizontalPadding

        XCTAssertGreaterThan(promptWidth, 10.0, "precondition: there IS a prompt")
        XCTAssertGreaterThanOrEqual(band.width, promptWidth + padding * 2.0 - 1.0,
                                    "the pill must be wide enough for the prompt it shows: "
                                    + "band=\(band.width) prompt=\(promptWidth)")
    }
}
