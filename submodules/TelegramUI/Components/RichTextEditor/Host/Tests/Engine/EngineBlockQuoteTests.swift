import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7, final slice: `.blockQuote`.
///
/// Every other container is 1:1 with an engine block, so its kind is a tag in the identity table.
/// A block quote has `children: [Block]` — ONE model block becomes N engine blocks — and the view's
/// block cache is indexed by ENGINE BLOCK INDEX. So the quote's structure cannot live in a per-block
/// tag; consecutive engine blocks have to be grouped back into one quote on the way out.
@available(iOS 18.4, *)
final class EngineBlockQuoteTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func quote(_ texts: [String], id: String = "q0") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: texts.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("\(id)c\(index)"), runs: [TextRun(text: text)]))
        }))
    }

    func test_aBlockQuoteSurvivesBeingSetAndReadBack() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            quote(["quoted one", "quoted two"]),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])

        guard editor.document.blocks.count == 3 else {
            return XCTFail("expected three blocks, got \(editor.document.blocks)")
        }
        guard case let .blockQuote(quote) = editor.document.blocks[1] else {
            return XCTFail("the quote came back as \(editor.document.blocks[1])")
        }
        XCTAssertEqual(quote.children.count, 2, "its two children must stay ONE quote")
        XCTAssertEqual(quote.children.compactMap { $0.asParagraph?.runs.map(\.text).joined() },
                       ["quoted one", "quoted two"])
    }

    /// The grouping must key on the quote's identity, not on adjacency: two SEPARATE quotes that
    /// happen to sit next to each other must not merge into one.
    func test_twoAdjacentQuotesDoNotMerge() {
        editor.document = Document(blocks: [
            quote(["first"], id: "qA"),
            quote(["second"], id: "qB"),
        ])

        XCTAssertEqual(editor.document.blocks.count, 2,
                       "adjacent quotes merged: \(editor.document.blocks)")
    }

    /// The same identity-not-position invariant the other containers have, on the harder shape:
    /// splitting the paragraph ABOVE a quote must not shift the quote's membership.
    func test_splittingTheParagraphAboveAQuoteDoesNotMigrateIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "first")])),
            quote(["quoted"]),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        editor.engineSelectedRange = NSRange(location: 5, length: 0)
        editor.engine.insertText("\n")

        guard editor.document.blocks.count == 3 else {
            return XCTFail("expected three blocks after the split, got \(editor.document.blocks)")
        }
        guard case .paragraph = editor.document.blocks[1] else {
            return XCTFail("the quote migrated onto the new blank line: \(editor.document.blocks[1])")
        }
        guard case let .blockQuote(quote) = editor.document.blocks[2] else {
            return XCTFail("the quote did not survive: \(editor.document.blocks[2])")
        }
        XCTAssertEqual(quote.children.compactMap { $0.asParagraph?.runs.map(\.text).joined() },
                       ["quoted"])
    }

    func test_wrapInBlockQuoteWrapsTheTouchedParagraphs() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])
        // The flat axis joins paragraphs with "\n": "one\ntwo".
        editor.engineSelectedRange = NSRange(location: 0, length: 7)

        editor.wrapInBlockQuote()

        guard editor.document.blocks.count == 1 else {
            return XCTFail("expected one quote, got \(editor.document.blocks)")
        }
        guard case let .blockQuote(quote) = editor.document.blocks[0] else {
            return XCTFail("not a quote: \(editor.document.blocks[0])")
        }
        XCTAssertEqual(quote.children.compactMap { $0.asParagraph?.runs.map(\.text).joined() },
                       ["one", "two"], "both touched paragraphs become its children")
    }

    /// A quote must be VISIBLE. Each child draws its own bar segment — they abut, because the stack
    /// lays blocks with no gap — so a two-child quote has two decoration views, not none and not one
    /// stretched over a gap it does not own.
    func test_oneBandCoversTheWholeQuote() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "plain")])),
            quote(["one", "two"]),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()

        let decorations = editor.engine.subviews.compactMap { $0 as? ContainerDecorationView }
        XCTAssertEqual(decorations.count, 1,
                       "ONE band for the whole quote — children and author — and none for the "
                       + "paragraph")
        let quoteBand = decorations[0].frame
        for child in 1...2 {
            XCTAssertTrue(quoteBand.contains(editor.engine.id_frameForBlock(at: UInt(child))),
                          "the band covers child \(child)")
        }
    }

    private var decorations: [ContainerDecorationView] {
        editor.engine.subviews.compactMap { $0 as? ContainerDecorationView }
    }

    private func layOut() { editor.setNeedsLayout(); editor.layoutIfNeeded() }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }

    /// Reported from the device: the quote's background is not removable and persists after the quote
    /// is gone. Unwrapping must take its decoration with it.
    func test_unwrappingAQuoteRemovesItsDecoration() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 3)
        editor.wrapInBlockQuote()
        layOut()
        XCTAssertEqual(decorations.count, 1, "precondition: the quote should be decorated")

        editor.engineSelectedRange = NSRange(location: 0, length: 3)
        editor.wrapInBlockQuote()
        layOut()

        XCTAssertEqual(decorations.count, 0,
                       "the quote's background outlived the quote: \(editor.document.blocks)")
    }

    /// …and so must deleting the quoted text outright.
    /// Emptying a quote by KEYSTROKES keeps it, band and all; a further backspace is what removes
    /// it. (A select-all takes the quote with the text — `EngineCrossBlockReplaceTests`.)
    ///
    /// This used to assert the opposite — that deleting the text took the quote with it — on the
    /// reasoning that an emptied quote was otherwise undeletable. It is not: backspace in the empty
    /// one un-quotes it, which is also the legacy editor's rule. Reverting on emptiness meant one
    /// backspace too many silently changed what you were editing.
    func test_emptyingAQuoteKeepsItUntilABackspaceRemovesIt() {
        editor.document = Document(blocks: [quote(["one"])])
        layOut()
        XCTAssertEqual(decorations.count, 1, "precondition: the quote should be decorated")
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        editor.engineSelectedRange = NSRange(location: 3, length: 0)
        for _ in 0..<3 { editor.engine.deleteBackward() }
        layOut()
        XCTAssertEqual(decorations.count, 1,
                       "the emptied quote is still a quote: \(editor.document.blocks)")

        editor.engine.deleteBackward()
        layOut()
        XCTAssertEqual(decorations.count, 0,
                       "and the next backspace removes it: \(editor.document.blocks)")
    }

    /// Quoted content sits one step below body and inset from the bar — V2's `quoteScale` (15/17 of
    /// the 17pt body, so 15pt) and the stylesheet's `quoteIndent`. Both values come from the existing
    /// render contract rather than being chosen here.
    func test_aQuotesContentIsSmallerAndInsetFromTheBar() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "plain")])),
            quote(["quoted"]),
        ])
        layOut()

        guard let plainFont = editor.engine.id_renderedTextForBlock(at: 0)?
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
              let quotedFont = editor.engine.id_renderedTextForBlock(at: 1)?
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return XCTFail("no rendered fonts")
        }
        XCTAssertEqual(plainFont.pointSize, 17.0, accuracy: 0.5, "precondition: body is 17pt")
        XCTAssertEqual(quotedFont.pointSize, 15.0, accuracy: 0.5,
                       "quoted content should be one step below body")

        // Inset measured on the GLYPHS, against the plain paragraph — the same difference-based shape
        // the code block's inset test uses, so it survives the container padding moving.
        let plain = editor.engine.id_rects(forCanonicalRange: NSRange(location: 0, length: 5))
            .map(\.cgRectValue).first
        let quoted = editor.engine.id_rects(forCanonicalRange: NSRange(location: 6, length: 6))
            .map(\.cgRectValue).first
        guard let plain, let quoted else { return XCTFail("no glyph geometry") }
        let plainInset = plain.minX - editor.engine.id_frameForBlock(at: 0).minX
        let quotedInset = quoted.minX - editor.engine.id_frameForBlock(at: 1).minX
        XCTAssertGreaterThan(quotedInset - plainInset, 8.0,
                             "quoted text should be inset from the bar; plain=\(plainInset) "
                             + "quoted=\(quotedInset)")
    }

    /// …and NEITHER the smaller size nor the indent may reach the model. They are presentation: a
    /// quote's runs must round-trip without acquiring an explicit 15pt font, or sending the message
    /// would carry a size the user never chose.
    func test_theQuotesStylingDoesNotLeakIntoTheModel() {
        editor.document = Document(blocks: [quote(["quoted"])])
        layOut()

        guard case let .blockQuote(readBack) = editor.document.blocks[0],
              let child = readBack.children.first?.asParagraph else {
            return XCTFail("not a quote: \(editor.document.blocks)")
        }
        XCTAssertEqual(child.runs.map(\.text).joined(), "quoted")
        for run in child.runs {
            XCTAssertNil(run.attributes.fontSize,
                         "the quote's render size leaked into the model as \(String(describing: run.attributes.fontSize))")
        }
    }

    /// A quote's vertical geometry is the SUM of two shared quantities, and this pins which:
    ///
    ///  - the gap SEPARATING it from its neighbour, from `richTextSpacingBetweenBlocks` — the
    ///    renderer's own table, so the composer matches the sent bubble;
    ///  - its INTERIOR padding, fill edge to first text line, from the stylesheet, resolved exactly
    ///    as the legacy canvas resolves it.
    ///
    /// Neither is a constant chosen in the editor, which is the point: three implementations of this
    /// geometry would otherwise drift. Expressed as the composition rather than as the total, so a
    /// change to V2's table moves the expectation with the behaviour.
    func test_aQuotesVerticalGeometryComposesTheSharedSpacingAndItsInteriorPadding() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "above")])),
            quote(["one", "two"]),
        ])
        layOut()

        let metrics = RichTextRenderMetrics.default
        let exterior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .blockQuote,
                                                    kind: .topLevel, metrics: metrics)
        let betweenParagraphs = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                                             kind: .topLevel, metrics: metrics)
        let interior = 8.0  // StyleSheet.quoteTopInset's nil resolution, per the legacy canvas.
        XCTAssertGreaterThan(exterior, 0.0, "precondition: V2 separates a paragraph from a quote")

        let above = editor.engine.id_frameForBlock(at: 0)
        let firstChild = editor.engine.id_frameForBlock(at: 1)
        let secondChild = editor.engine.id_frameForBlock(at: 2)

        // A frame's BOTTOM is one trailing line-box overhang below its glyphs — the engine sizes each
        // canvas to its own pinned box — and every space below a block now gives that band back, so a
        // frame-to-frame gap reads one overhang short of the rhythm it expresses. Subtracted here
        // rather than widened into the tolerance: the quantity under test is the rhythm, and it is
        // exact (2026-09-15).
        XCTAssertEqual(firstChild.minY - above.maxY,
                       exterior + interior - editor.trailingLineBoxOverhang(atRole: 0), accuracy: 1.0,
                       "the space above a quote is the shared gap PLUS its interior padding")
        XCTAssertEqual(secondChild.minY - firstChild.maxY,
                       betweenParagraphs - editor.trailingLineBoxOverhang(atRole: 1), accuracy: 1.0,
                       "its own paragraphs keep the ordinary rhythm — the interior padding is at the "
                       + "RUN's edges, not around every child")
    }

    /// The band must COVER the padding, not hug the text inside it.
    ///
    /// The space is reserved AROUND the block — that is what leaves the block's own height alone —
    /// so a decoration positioned from the block's frame sits inside the padding and the quote reads
    /// as having no vertical inset at all. It has to grow into the space reserved for it.
    func test_theQuotesBandCoversItsVerticalPadding() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "above")])),
            quote(["one", "two"]),
        ])
        layOut()

        let firstChild = editor.engine.id_frameForBlock(at: 1)
        // The quote's author line closes the run and so sits at the BOTTOM of the band.
        let authorLine = editor.engine.id_frameForBlock(at: 3)
        let bands = decorations.map(\.frame)
        guard bands.count == 1 else { return XCTFail("expected ONE band, got \(bands)") }

        XCTAssertEqual(firstChild.minY - bands[0].minY, 8.0, accuracy: 1.0,
                       "the band extends up over the quote's top padding")
        // Measured from the author's GLYPHS, not from its frame: the band now stops one trailing
        // overhang higher, because the padding below a quote is measured from where its text ends and
        // the frame runs one empty band past that.
        XCTAssertEqual(bands[0].maxY - authorLine.maxY,
                       8.0 - editor.trailingLineBoxOverhang(atRole: 3), accuracy: 1.0,
                       "and down over its bottom padding, past the author line")
    }

    // MARK: The quote's author line

    /// A block quote carries an author too, below its children.
    ///
    /// Same second-leaf-region shape as the pull quote's and the code block's language, and the same
    /// reason: `BlockQuote.author` was carried through the identity table, so it round-tripped but
    /// could never be typed. Reported from the device — "no author field in block quotes" — after the
    /// other two landed.
    func test_aBlockQuotesAuthorIsItsOwnEngineBlockBelowTheChildren() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "first")])),
                .paragraph(ParagraphBlock(id: BlockID("c1"), runs: [TextRun(text: "second")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 3,
                       "two children and the author line")
        XCTAssertEqual(editor.engine.attributedBlocks.last?.string, "Ada",
                       "the author sits below the children")
    }

    func test_editingABlockQuotesAuthorSetsTheModelsAuthor() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "first")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()

        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let start = editor.engine.beginningOfDocument
        guard let from = editor.engine.position(from: start, offset: 6),
              let to = editor.engine.position(from: start, offset: 9),
              let line = editor.engine.textRange(from: from, to: to) else {
            return XCTFail("could not address the author line")
        }
        editor.engine.selectedTextRange = line
        editor.engine.insertText("Grace")

        guard case let .blockQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the document should still hold ONE block quote")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Grace")
        XCTAssertEqual(quote.children.count, 1, "and its children are untouched")
    }

    /// Empty when nothing is quoted yet, mirroring `BlockQuoteBox.shouldShowAuthor`.
    func test_anEmptyBlockQuoteHasNoAuthorLine() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"))),
            ])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 1,
                       "nothing quoted yet, so nothing to attribute")
    }

    /// An empty TABLE is not an empty quote. The only block that may be internally empty is a body
    /// paragraph; every other child is structure the user put there, and a quote holding one has
    /// something to attribute. The author-line rule used to ask whether any primary role held TEXT,
    /// so a quote whose only child was a fresh table read as empty and never showed its author line
    /// (K3, 2026-09-11) — a second, narrower spelling of a question `ContainerContents.isEmpty`
    /// already answers.
    func test_aQuoteWhoseOnlyChildIsAnEmptyTableHasAnAuthorLine() {
        var table = TableBlock.empty(rows: 2, columns: 2)
        table.id = BlockID("t0")
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [.table(table)])),
        ])
        layOut()
        XCTAssertTrue(editor.currentRoles.contains { $0.secondaryKind == .blockQuoteAuthor },
                      "the quote holds a table, so it has something to attribute")
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("no quote") }
        XCTAssertEqual(quote.children.count, 1, "and the table is still its only child")
    }

    /// The other three shapes that are never "nothing", for the same reason.
    func test_aQuoteWhoseOnlyChildIsAnEmptyContainerOrAtomHasAnAuthorLine() {
        let cases: [(String, Block)] = [
            ("code", .code(CodeBlock(id: BlockID("c0")))),
            ("media", .media(MediaBlock(id: BlockID("m0"), mediaID: "x", kind: .image,
                                        naturalSize: Size2D(width: 100, height: 80), caption: []))),
            ("nested quote", .blockQuote(BlockQuote(id: BlockID("q1"),
                                                    children: [.paragraph(ParagraphBlock(id: BlockID("n0")))]))),
        ]
        for (name, child) in cases {
            editor.document = Document(blocks: [
                .blockQuote(BlockQuote(id: BlockID("q0"), children: [child])),
            ])
            layOut()
            XCTAssertTrue(editor.currentRoles.contains {
                $0.secondaryKind == .blockQuoteAuthor && $0.containerID == BlockID("q0")
            }, "a quote holding an empty \(name) still has something to attribute")
        }
    }

    /// The forward pass decides the author line on a document SET (settle never runs for one) and
    /// settle decides it on the next keystroke, so the two have to agree about what "holds content"
    /// means — or a quote gains or loses its author line the moment the user types anywhere.
    func test_settleAgreesWithTheForwardPassAboutAQuoteHoldingOnlyAnEmptyTable() {
        var table = TableBlock.empty(rows: 2, columns: 2)
        table.id = BlockID("t0")
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [.table(table)])),
            .paragraph(ParagraphBlock(id: BlockID("p0"))),
        ])
        layOut()
        let onSet = editor.currentRoles.filter { $0.secondaryKind == .blockQuoteAuthor }.count
        XCTAssertEqual(onSet, 1, "the set gives the quote its author line")
        // A keystroke in the paragraph BELOW the quote: settle runs over the whole document and
        // re-decides every author line, so this is what would take it away again.
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: editor.currentRoles.count - 1), length: 0)
        editor.insertText("x")
        layOut()
        XCTAssertEqual(editor.currentRoles.filter { $0.secondaryKind == .blockQuoteAuthor }.count, onSet,
                       "and settle leaves it alone")
    }

    /// The contrast case, so the rule above is not just "always show the line": a quote holding one
    /// empty PARAGRAPH still has nothing to attribute, through both passes.
    func test_settleAgreesWithTheForwardPassAboutAQuoteHoldingOnlyAnEmptyParagraph() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"),
                                   children: [.paragraph(ParagraphBlock(id: BlockID("c0")))])),
            .paragraph(ParagraphBlock(id: BlockID("p0"))),
        ])
        layOut()
        XCTAssertFalse(editor.currentRoles.contains { $0.secondaryKind == .blockQuoteAuthor },
                       "an empty paragraph is not content")
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: editor.currentRoles.count - 1), length: 0)
        editor.insertText("x")
        layOut()
        XCTAssertFalse(editor.currentRoles.contains { $0.secondaryKind == .blockQuoteAuthor },
                       "and settle does not mint one either")
    }

    /// The COMMAND path, which is how a table actually gets into a quote on a device: wrap a
    /// paragraph in a quote, then ask the toolbar for a table. Neither is a document set, and the
    /// set-driven cases above would not have noticed if this one decided differently.
    func test_aTableInsertedIntoAQuoteThroughTheCommandsGetsItAnAuthorLine() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0")))])
        layOut()
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.wrapInBlockQuote()
        layOut()
        XCTAssertFalse(editor.currentRoles.contains { $0.secondaryKind == .blockQuoteAuthor },
                       "the fresh quote holds one empty paragraph and has nothing to attribute")
        editor.insertTable(rows: 2, cols: 2)
        layOut()
        XCTAssertTrue(editor.currentRoles.contains { $0.secondaryKind == .blockQuoteAuthor },
                      "and the table it now holds is content")
        XCTAssertTrue(editor.currentRoles.allSatisfy { $0.ancestry.count == 1 },
                      "the table went INTO the quote, not after it")
    }

    /// Return at the END of a quote's last child still makes another CHILD, not a loose paragraph.
    ///
    /// The author line sits after the last child, so a block minted there is no longer between two
    /// children — it is between a child and the author. the resolver's `.quoteChildSplit`
    /// keys on "a quote on both sides", which the author line has to satisfy or every Return at the
    /// end of a quote would break out of it.
    func test_returnAtTheEndOfTheLastChildStaysInsideTheQuote() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "first")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 5),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the end of the child")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")

        guard case let .blockQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote broke apart: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.children.count, 2, "Return adds a second child")
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada", "and the author is untouched")
        XCTAssertEqual(editor.document.blocks.count, 1, "nothing escaped the quote")
    }

    /// Emptying a quote that has an author leaves an empty quote, not a loose author line — and the
    /// author line must not keep the quote alive against a following backspace either.
    func test_emptyingAQuoteWithAnAuthorKeepsItThenRemovesItOnTheNextBackspace() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
            ])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 1),
              let all = editor.engine.textRange(from: start, to: end) else {
            return XCTFail("could not address the child")
        }
        editor.engine.selectedTextRange = all
        editor.engine.deleteBackward()

        XCTAssertTrue(editor.document.blocks.contains { if case .blockQuote = $0 { return true }; return false },
                      "the emptied quote is still a quote: \(editor.document.blocks)")

        editor.engine.deleteBackward()
        XCTAssertFalse(editor.document.blocks.contains { if case .blockQuote = $0 { return true }; return false },
                       "and the next backspace removes it: \(editor.document.blocks)")
        XCTAssertEqual(editor.document.blocks.count, 1,
                       "leaving ONE paragraph, not a stray author line: \(editor.document.blocks)")
    }

    // MARK: The author line is part of the quote, not a block beside it

    private func quoteWithAuthor() -> Document {
        Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "first")])),
            ], author: [TextRun(text: "Ada")])),
        ])
    }

    /// The author sits INSIDE the quote's band, one `authorSpacing` below the last child — not a
    /// block's gap away from it, which is what puts it outside the background.
    func test_theAuthorLineSitsInsideTheQuotesBand() {
        editor.document = quoteWithAuthor()
        window.layoutIfNeeded()

        let child = editor.engine.id_frameForBlock(at: 0)
        let author = editor.engine.id_frameForBlock(at: 1)
        XCTAssertEqual(author.minY - child.maxY, QuoteStyle.default.authorSpacing, accuracy: 1.0,
                       "the author is interior to the quote, so only authorSpacing separates them")

        let bands = editor.engine.subviews.compactMap { $0 as? ContainerDecorationView }
        XCTAssertTrue(bands.contains { $0.frame.contains(author) },
                      "and a band covers it: \(bands.map(\.frame)) vs \(author)")
    }

    /// Return in the author line EXITS the quote, leaving an empty body paragraph after it.
    ///
    /// An author is one line, so a break there cannot make another one — but it should not strand
    /// the caret either. It was landing in the quote's BODY, which is the one place it certainly
    /// does not belong.
    func test_returnInTheAuthorLineExitsTheQuote() {
        editor.document = quoteWithAuthor()
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 9),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the end of the author")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")

        // The repair is DEFERRED one runloop turn, like list continuation: it re-applies the
        // document, which cannot be done from inside the engine's own change notification. Enqueued
        // after it, so this resumes once it has run.
        let settled = expectation(description: "the split was put back")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(editor.document.blocks.count, 2,
                       "the quote, and an empty paragraph after it: \(editor.document.blocks)")
        guard case let .blockQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote broke apart")
        }
        XCTAssertEqual(quote.children.count, 1, "no child was added")
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada", "and the author is unchanged")
        guard case let .paragraph(escape)? = editor.document.blocks.last else {
            return XCTFail("expected a body paragraph after the quote")
        }
        XCTAssertTrue(escape.text.isEmpty, "which is empty, ready to type into")
        XCTAssertEqual(escape.style, .body)

        // And the caret is IN it — not back in the quote.
        let selection = editor.engineSelectedRange
        XCTAssertEqual(selection.length, 0)
        let quoteEnd = editor.engine.attributedBlocks.dropLast()
            .reduce(0) { $0 + $1.length + 1 }
        XCTAssertEqual(selection.location, quoteEnd,
                       "the caret should sit in the new paragraph, past the whole quote")
    }

    /// Backspace in an EMPTY author line must not delete the line — it is a permanent region of the
    /// quote, and deleting it takes the field away with no way to bring it back.
    func test_backspaceInAnEmptyAuthorLineKeepsTheLine() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "first")])),
            ])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(editor.engine.attributedBlocks.count, 2, "precondition: the line is there")

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 6),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the empty author line")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the author line survives a backspace inside it")
        guard case let .blockQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote was destroyed: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.children.map(\.flatUTF16Count), [5],
                       "and the child it would have merged into is intact")
    }

    /// The author's band must be indistinguishable from the children's: same x, same width, abutting
    /// edges. Reported from the device as "the quote author gets its own background".
    func test_theAuthorsBandIsContinuousWithTheChildrens() { assertContinuous(authored: true) }

    /// …and with an EMPTY author, which is what a fresh quote has: the line the placeholder sits in.
    func test_anEmptyAuthorsBandIsContinuousToo() { assertContinuous(authored: false) }

    private func assertContinuous(authored: Bool) {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "one")])),
                .paragraph(ParagraphBlock(id: BlockID("c1"), runs: [TextRun(text: "two")])),
            ], author: authored ? [TextRun(text: "Ada")] : [])),
        ])
        layOut()

        let bands = decorations.map(\.frame)
        guard bands.count == 1 else {
            return XCTFail("the author must share the quote's band, not get one of its own: \(bands)")
        }
        // Every engine block of the quote — both children and the author line — is inside it, so
        // there is no seam anywhere for a capped bar or a second fill to show through.
        for block in 0..<editor.engine.attributedBlocks.count {
            XCTAssertTrue(bands[0].contains(editor.engine.id_frameForBlock(at: UInt(block))),
                          "block \(block) is outside the quote's band")
        }
    }

    /// An EMPTY quoted line keeps the quote's indent — its caret included.
    ///
    /// An empty attributed string carries no attributes, so nothing about the intended line is
    /// reachable from it: the engine measured it at the document's default font and put its caret at
    /// the container's leading edge, outside the bar. The intended attributes now travel on the
    /// block's separator, which is the newline that follows it.
    func test_anEmptyQuotedLineKeepsTheQuotesIndent() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
                .paragraph(ParagraphBlock(id: BlockID("c1"))),
            ], author: [TextRun(text: "Ada")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // The caret at the start of the EMPTY child, against the filled one above it.
        let filled = editor.engine.id_rects(forCanonicalRange: NSRange(location: 0, length: 6))
            .map(\.cgRectValue.minX).min()
        let start = editor.engine.beginningOfDocument
        guard let filled,
              let position = editor.engine.position(from: start, offset: 7),
              let caret = editor.engine.caretRect(for: position) as CGRect? else {
            return XCTFail("no geometry")
        }
        XCTAssertGreaterThan(filled, 1.0, "precondition: quoted text IS indented")
        XCTAssertEqual(caret.minX, filled, accuracy: 1.5,
                       "an empty quoted line's caret sits at the same indent as its text")
    }

    /// An author line EMPTIED BY EDITING keeps its indent — which is how it actually gets emptied.
    ///
    /// The attributes are computed when the document is SET, and only for blocks that are empty at
    /// that moment. A block emptied by typing and deleting was never empty at any set, so it had no
    /// entry and fell back to the defaults: the fix worked only for documents that arrived empty,
    /// which is not how anyone reaches an empty author line.
    func test_anAuthorLineEmptiedByEditingKeepsItsIndent() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let authoredX = editor.engine.id_rects(forCanonicalRange: NSRange(location: 7, length: 3))
            .map(\.cgRectValue.minX).min()

        // Delete the author's text the way a user does, rather than setting an empty document.
        let start = editor.engine.beginningOfDocument
        guard let from = editor.engine.position(from: start, offset: 7),
              let to = editor.engine.position(from: start, offset: 10),
              let range = editor.engine.textRange(from: from, to: to) else {
            return XCTFail("could not address the author")
        }
        editor.engine.selectedTextRange = range
        editor.engine.deleteBackward()
        layOut()

        guard let authoredX,
              let caretAt = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                   offset: 7) else {
            return XCTFail("no geometry")
        }
        XCTAssertGreaterThan(authoredX, 1.0, "precondition: the author line IS indented")
        XCTAssertEqual(editor.engine.caretRect(for: caretAt).minX, authoredX, accuracy: 2.0,
                       "the emptied author line keeps the indent it had a moment ago")
    }

    /// Typing into an EMPTIED author line produces author text, not body text.
    ///
    /// Reported from the device: type an author, backspace it away, type again — and the new text
    /// comes out in the body font with no quote inset. The empty-line attributes fix what an empty
    /// line is MEASURED with; what is TYPED into it comes from the engine's typing attributes, which
    /// are the document's defaults. Both have to answer, or the line looks right until you use it.
    func test_typingIntoAnEmptiedAuthorLineProducesAuthorText() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "A")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let authored = editor.engine.id_renderedTextForBlock(at: 1),
              let authoredFont = authored.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
              let authoredStyle = authored.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else { return XCTFail("no authored geometry") }

        // Emptied the way a user does — the caret put at the end of the line and BACKSPACE pressed,
        // not a range selected and deleted. Then typed into again, more than one character.
        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 8),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the author")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()
        // The caret is re-placed rather than typed into directly, because that is what makes the
        // engine resolve its typing attributes — which is where this went wrong. Typing through
        // `insertText:` alone PASSED against the bug: a real keyboard inserts through the private
        // input controller's own replace, with a string built from those attributes, so the
        // post-insert typed-text policy never sees it.
        if let empty = editor.engine.position(from: start, offset: 7) {
            editor.engine.selectedTextRange = editor.engine.textRange(from: empty, to: empty)
        }
        editor.engine.insertText("B")
        editor.engine.insertText("C")
        layOut()

        guard let retyped = editor.engine.id_renderedTextForBlock(at: 1),
              retyped.string == "BC",
              let retypedFont = retyped.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
              let retypedStyle = retyped.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                  as? NSParagraphStyle else {
            return XCTFail("the author line holds "
                           + "\(editor.engine.id_renderedTextForBlock(at: 1)?.string ?? "nil"), "
                           + "document: \(editor.document.blocks)")
        }

        XCTAssertEqual(retypedFont.pointSize, authoredFont.pointSize, accuracy: 0.5,
                       "retyped author text keeps the author's size, not the body's")
        XCTAssertEqual(retypedFont.fontDescriptor.symbolicTraits.contains(.traitBold),
                       authoredFont.fontDescriptor.symbolicTraits.contains(.traitBold),
                       "and its weight")
        XCTAssertEqual(retypedStyle.headIndent, authoredStyle.headIndent, accuracy: 0.5,
                       "and the quote's inset")
    }

    // MARK: The quote's column — both edges

    /// A quote keeps its content back on BOTH sides, and legacy's `BlockQuoteBox` is the definition:
    /// `inner = max(width - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)`, with the fill
    /// left full width. This editor applied the leading half from the day quotes landed and the
    /// trailing half not at all, so a quoted line ran out to the column edge while the bar held it
    /// back on the left (user report, 2026-09-11).
    ///
    /// `tailIndent` is NEGATIVE by convention — a negative value measures from the container's
    /// trailing edge — so 0 is exactly the defect: text free to reach the column.
    func test_aQuotesContentStopsItsTrailingInsetShortOfTheColumn() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "someone")])),
        ])
        layOut()
        let sheet = editor.bridge.styleSheet
        XCTAssertGreaterThan(sheet.quoteTrailingInset, 0, "precondition: the style keeps content back")
        for (index, what) in [(UInt(0), "the child"), (UInt(1), "its author line")] {
            guard let rendered = editor.engine.id_renderedTextForBlock(at: index),
                  let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                      as? NSParagraphStyle else {
                return XCTFail("\(what) carries no paragraph style")
            }
            XCTAssertEqual(style.headIndent, sheet.quoteIndent, accuracy: 0.5,
                           "\(what) starts one leading inset in")
            XCTAssertEqual(style.tailIndent, -sheet.quoteTrailingInset, accuracy: 0.5,
                           "\(what) stops one trailing inset short of the column")
        }
    }

    /// …and it is a real narrowing, not an attribute nobody reads: the same text laid out inside the
    /// quote occupies a column narrower by BOTH insets.
    ///
    /// Measured on the engine's own used size, over a string of narrow glyphs so the wrap granule
    /// (one `i ` pair) is far smaller than the half under test. The used width runs from the block's
    /// own leading edge, so the head indent is INSIDE it and what shows here is the trailing half
    /// alone — which is exactly the half that was missing: an editor that applies the leading inset
    /// only answers ~0 to this, far outside the accuracy.
    func test_aQuotedParagraphIsLaidOutInTheNarrowedColumn() {
        let filler = String(repeating: "i ", count: 200)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: filler)])),
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: filler)])),
            ])),
        ])
        layOut()
        let sheet = editor.bridge.styleSheet
        let top = editor.engine.id_usedSizeForBlock(at: 0).width
        let quoted = editor.engine.id_usedSizeForBlock(at: 1).width
        XCTAssertEqual(top - quoted, sheet.quoteTrailingInset, accuracy: 6.0,
                       "the quoted line wraps a trailing inset short of where the top-level one does")
    }

    // MARK: The author line appears and goes with the quote's content

    /// Emptying a quote takes its author line with it — there is nothing left to attribute.
    ///
    /// `shouldShowAuthor` is evaluated when the document is SET, and a quote now survives being
    /// emptied, so the line outlived the content it belonged to: an empty quote sat there offering
    /// to attribute nothing.
    func test_emptyingAQuoteRemovesItsAuthorLine() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "x")])),
            ])),
        ])
        layOut()
        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "precondition: the child and its author line")
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 1),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the quote")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.deleteBackward()

        let settled = expectation(description: "presence reconciled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)
        layOut()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 1,
                       "an empty quote offers nothing to attribute")
        guard case .blockQuote? = editor.document.blocks.first else {
            return XCTFail("the quote itself must stay: \(editor.document.blocks)")
        }
    }

    /// An author that HAS text keeps its line, even with nothing quoted — it is content of its own.
    func test_anEmptyQuoteWithAnAuthorKeepsTheAuthorLine() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"))),
            ], author: [TextRun(text: "Ada")])),
        ])
        layOut()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the author is text, so it stays: \(editor.engine.attributedBlocks.map(\.string))")
    }

    /// …and typing into an empty quote brings the line back.
    func test_typingIntoAnEmptyQuoteRestoresItsAuthorLine() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"))),
            ])),
        ])
        layOut()
        XCTAssertEqual(editor.engine.attributedBlocks.count, 1, "precondition: no author line")
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
        editor.engine.insertText("q")

        let settled = expectation(description: "presence reconciled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)
        layOut()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "there is something to attribute now")
    }

    /// Return in the MIDDLE of an author takes the rest of it into the new paragraph.
    ///
    /// A break splits a line; it does not discard what follows the caret, and it does not put it
    /// back where it was. The author keeps what precedes the caret and the paragraph the Return
    /// escapes into carries the rest.
    func test_returnMidAuthorCarriesTheRestIntoTheNewParagraph() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        layOut()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // After the "A" of "Ada": past "quoted" and its separator, then one character.
        let start = editor.engine.beginningOfDocument
        guard let mid = editor.engine.position(from: start, offset: 8),
              let caret = editor.engine.textRange(from: mid, to: mid) else {
            return XCTFail("could not address the middle of the author")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")

        let settled = expectation(description: "repaired")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(editor.document.blocks.count, 2, "\(editor.document.blocks)")
        guard case let .blockQuote(quote)? = editor.document.blocks.first,
              case let .paragraph(escaped)? = editor.document.blocks.last else {
            return XCTFail("shape changed: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "A",
                       "the author keeps what precedes the caret")
        XCTAssertEqual(escaped.text, "da", "and the rest comes with the Return")
    }

    // MARK: - The Quote toggle and the author line

    /// A quote's author line reports its own quote as its innermost ancestor (nesting design §3.2),
    /// so a caret parked in it is INSIDE the quote as far as membership goes. It must not read as a
    /// selection worth toggling on its own — and when the toggle does unwrap, the line goes with the
    /// quote rather than surviving as a second line no quote owns.
    ///
    /// It survived once: `within(_:)` keeps the POSITION, so the lifted line stayed a
    /// `.blockQuoteAuthor` secondary with an empty ancestry, the regroup filed it under an owner
    /// nothing opened, and "Ada" was dropped from the document — permanently, since the command
    /// re-renders from what it built.
    private func quoteWithAuthor() -> Block {
        .blockQuote(BlockQuote(id: BlockID("q0"), children: [
            .paragraph(ParagraphBlock(id: BlockID("q0c0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("q0c1"), runs: [TextRun(text: "two")])),
        ], author: [TextRun(text: "Ada")]))
    }

    private func assertUnwrappedToTwoParagraphs(_ message: String) {
        XCTAssertEqual(editor.document.blocks.count, 2, "\(message): \(editor.document.blocks)")
        XCTAssertEqual(editor.document.blocks.map { $0.flatText }, ["one", "two"], message)
        XCTAssertTrue(editor.document.blocks.allSatisfy { if case .paragraph = $0 { return true }; return false },
                      "\(message): still a container — \(editor.document.blocks)")
        XCTAssertTrue(editor.currentRoles.allSatisfy { $0.secondaryKind != .blockQuoteAuthor },
                      "the author line outlived its quote: \(editor.currentRoles.map(\.secondaryKind))")
        XCTAssertTrue(editor.currentRoles.allSatisfy { $0.containerDepth == 0 }, message)
    }

    /// A caret in the author line ALONE toggles the quote OFF (controller ruling, R7-nesting task 5):
    /// the author line's own ancestry ends in its own quote (§3.2), so `commonAncestry` over the one
    /// touched role — the author line — resolves to that quote and the unwrap branch runs, exactly
    /// as the article host's "Quote" menu item does via `blockQuoteDepth > 0 → unwrapBlockQuoteLevel()`
    /// (spec §8.1). This REPLACES the earlier interim no-op ruling this test used to pin: the quote
    /// dissolves, its children rise one level, and the author's own text is dropped along with the
    /// line that carried it — there is nowhere left for it to live once the quote is gone.
    func test_theQuoteToggleWithTheCaretInTheAuthorLineAloneUnwrapsTheQuote() {
        editor.document = Document(blocks: [quoteWithAuthor()])
        guard let line = editor.currentRoles.firstIndex(where: { $0.secondaryKind == .blockQuoteAuthor }) else {
            return XCTFail("no author line: \(editor.currentRoles.map(\.secondaryKind))")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: line), length: 0)
        // Drain what the SETUP scheduled, or its delivery is counted against the command below
        // (`EngineChangeNotificationCountTests` documents this trap).
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        editor.wrapInBlockQuote()
        turn()
        editor.onChange = nil

        XCTAssertEqual(calls, 1, "the quote dissolving is a real edit — exactly one notification")
        assertUnwrappedToTwoParagraphs("the caret alone in the author line unwraps the quote")
    }

    /// The unwrap is the QUOTE's, not the selection's: one child is enough to take the whole thing,
    /// author line included. This is the case that separates the two implementations — before the
    /// fix the command lifted only the roles it touched, so the quote stayed open around its other
    /// child and the document came back as a quote plus a loose paragraph.
    func test_theQuoteToggleFromOneChildUnwrapsTheWholeQuoteIncludingTheAuthorLine() {
        editor.document = Document(blocks: [quoteWithAuthor()])
        // The SECOND child alone; the author line is outside the selection entirely.
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 1),
                                             length: editor.flatLength(ofRoleAt: 1))
        editor.wrapInBlockQuote()

        assertUnwrappedToTwoParagraphs("the quote survived around the child the selection missed")
    }

    /// The contract, stated over the whole body: unwrapping splices the children and keeps nothing
    /// else. (Both implementations agree here — it is the shape the fix must not change.)
    func test_theQuoteToggleOverBothChildrenUnwrapsAndDropsTheAuthorLineItNeverTouched() {
        editor.document = Document(blocks: [quoteWithAuthor()])
        let end = editor.flatOffset(ofRoleAt: 1) + editor.flatLength(ofRoleAt: 1)
        editor.engineSelectedRange = NSRange(location: 0, length: end)
        editor.wrapInBlockQuote()

        assertUnwrappedToTwoParagraphs("unwrapping splices the children and keeps nothing else (spec §2)")
    }
}
