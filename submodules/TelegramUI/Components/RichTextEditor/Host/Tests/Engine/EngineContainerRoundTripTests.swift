import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7, first slice: the engine editor must be able to HOLD a container at all.
///
/// `attributedBlocks(for:)` traps on any non-paragraph block today, so setting a document containing
/// a code block or a quote crashes by design. These pin the round trip that has to work before any
/// of the three Format commands can exist.
///
/// `CodeBlock` and `PullQuote` are LEAF containers — one `runs` list each — so they map one-to-one
/// onto an engine block, and only the block KIND has to survive host-side. `BlockQuote` has
/// `children` and needs grouping; it is a separate step.
final class EngineContainerRoundTripTests: XCTestCase {
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

    func test_aCodeBlockSurvivesBeingSetAndReadBack() {
        let document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift",
                            runs: [TextRun(text: "let x = 1")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])

        editor.document = document

        guard editor.document.blocks.count == 3 else {
            return XCTFail("expected three blocks, got \(editor.document.blocks.count)")
        }
        guard case let .code(code) = editor.document.blocks[1] else {
            return XCTFail("the code block came back as \(editor.document.blocks[1])")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x = 1")
        XCTAssertEqual(code.language, "swift", "the language is host-side structure and must survive")
    }

    func test_aPullQuoteSurvivesBeingSetAndReadBack() {
        let document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "quoted")])),
        ])

        editor.document = document

        guard case let .pullQuote(quote) = editor.document.blocks.first else {
            return XCTFail("the pull quote came back as \(String(describing: editor.document.blocks.first))")
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "quoted")
    }

    /// THE LOAD-BEARING INVARIANT, tested with an edit that can actually tell the two models apart.
    ///
    /// Container membership keys on the ENGINE's block identity, never on array position. The
    /// discriminating edit is one that INSERTS a block above the container: typing a character shifts
    /// no indices at all, so a positional model and an identity model agree and a test built on it
    /// proves nothing. Pressing Return does shift them.
    ///
    /// `-[IDBlockDocument replaceCanonicalRange:withAttributedString:]` keeps every block BEFORE the
    /// affected range on its own `NSUUID` and every block AFTER on its own, minting fresh ones only
    /// inside the affected span. So the split yields `["first"→u0, ""→new, "code"→u1]`, and a
    /// positional reuse hands index 1 — the blank new line — the code block's structure while the real
    /// code becomes a default paragraph. That is the container migrating up one row, and it is exactly
    /// what this asserts against.
    func test_splittingTheParagraphAboveAContainerDoesNotMigrateIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "first")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "code")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // Caret at the END of "first" — the boundary above the container — then Return.
        editor.engineSelectedRange = NSRange(location: 5, length: 0)
        editor.engine.insertText("\n")

        guard editor.document.blocks.count == 3 else {
            return XCTFail("expected three blocks after the split, got \(editor.document.blocks.count)")
        }
        guard case let .paragraph(blank) = editor.document.blocks[1] else {
            return XCTFail("the container MIGRATED onto the new blank line: blocks[1] is "
                           + "\(editor.document.blocks[1]) — this is the positional-reuse bug")
        }
        XCTAssertEqual(blank.runs.map(\.text).joined(), "",
                       "the freshly minted block is the empty new line")
        guard case let .code(code) = editor.document.blocks[2] else {
            return XCTFail("the code block did not survive the split above it: blocks[2] is "
                           + "\(editor.document.blocks[2])")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "code")
        XCTAssertEqual(code.language, "swift")
    }

    // MARK: Second leaf regions — a code block's language line

    /// A code block's language is AUTHORED, in an always-visible line above the code.
    ///
    /// `IDBlock` holds one attributed string, so a second editable region cannot live inside the
    /// block that owns it: it is its own ENGINE block, grouped back by the owner's identity — the
    /// same shape a block quote's children already use. Until now `language` survived only by being
    /// carried in the identity table, which round-trips it but leaves it invisible and uneditable.
    func test_aCodeBlocksLanguageIsItsOwnEngineBlockAboveTheCode() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "Swift",
                            runs: [TextRun(text: "let x = 1")])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "one engine block for the language line, one for the code")
        // Re-pinned 2026-09-24 (composer harness p13, `HarnessCodeLanguageRedoTests`): the line
        // renders the language AS STORED. It used to render lowercased, and since the line is what
        // the language is read back from, every re-render rewrote the user's value.
        XCTAssertEqual(editor.engine.attributedBlocks.first?.string, "Swift",
                       "the language line renders as stored, above the code")
        XCTAssertEqual(editor.engine.attributedBlocks.last?.string, "let x = 1")
    }

    /// …and editing that line is what sets the model's `language`.
    func test_editingTheLanguageLineSetsTheModelsLanguage() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift",
                            runs: [TextRun(text: "let x = 1")])),
        ])
        window.layoutIfNeeded()

        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 5),
              let line = editor.engine.textRange(from: start, to: end) else {
            return XCTFail("could not address the language line")
        }
        editor.engine.selectedTextRange = line
        editor.engine.insertText("rust")
        guard case let .code(code)? = editor.document.blocks.first else {
            return XCTFail("the document should still hold ONE code block, not two blocks")
        }
        XCTAssertEqual(code.language, "rust", "the line's text IS the language")
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x = 1",
                       "and the code itself is untouched")
    }

    /// A code block with NO language still shows the line, because it is where you type one.
    func test_aCodeBlockWithoutALanguageStillCarriesTheLine() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "let x = 1")])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the line is ALWAYS visible — it is the affordance for adding a language")
        XCTAssertEqual(editor.engine.attributedBlocks.first?.string, "")
    }

    // MARK: Second leaf regions — a pull quote's author line

    /// A pull quote's author is AUTHORED, in a line below the quote.
    ///
    /// Same shape as the code block's language line, and the same reason: `author` was carried
    /// through the identity table, so it round-tripped but could never be typed.
    func test_aPullQuotesAuthorIsItsOwnEngineBlockBelowTheQuote() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "one engine block for the quote, one for its author")
        XCTAssertEqual(editor.engine.attributedBlocks.first?.string, "the quote")
        XCTAssertEqual(editor.engine.attributedBlocks.last?.string, "Ada",
                       "the author line sits BELOW the quote, unlike a language line")
    }

    func test_editingTheAuthorLineSetsTheModelsAuthor() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()

        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // The author line follows the quote and its separator.
        let start = editor.engine.beginningOfDocument
        guard let from = editor.engine.position(from: start, offset: 10),
              let to = editor.engine.position(from: start, offset: 13),
              let line = editor.engine.textRange(from: from, to: to) else {
            return XCTFail("could not address the author line")
        }
        editor.engine.selectedTextRange = line
        editor.engine.insertText("Grace")

        guard case let .pullQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the document should still hold ONE pull quote")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Grace")
        XCTAssertEqual(quote.runs.map(\.text).joined(), "the quote", "the quote itself is untouched")
    }

    /// An EMPTY pull quote hides the line entirely, mirroring `PullQuoteBox.shouldShowAuthor`: a
    /// fresh quote has no author region at all, so there is no stray blank row under it.
    func test_anEmptyPullQuoteHasNoAuthorLine() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 1,
                       "nothing to attribute yet, so no author line")
    }

    /// A quote with text but NO author still reserves the line — it is where an author is typed.
    ///
    /// Reported from the device as "there is no author field, and no space for one". The engine block
    /// may be emitted and still take no room: an EMPTY attributed string carries no attributes at
    /// all, so there is nothing for a line height to be derived from.
    func test_anEmptyAuthorLineStillReservesItsRow() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")])),
        ])
        window.layoutIfNeeded()

        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the quote has content, so its author line exists")
        let author = editor.engine.id_frameForBlock(at: 1)
        XCTAssertFalse(author.isNull, "the author line has no frame at all")
        // Compared against a line that HAS text, because "greater than zero" cannot tell a real row
        // from a degenerate one — and a degenerate row is exactly what "no space for it" looks like.
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q1"), runs: [TextRun(text: "the quote")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()
        let filled = editor.engine.id_frameForBlock(at: 1)

        // EQUAL, not merely close. This used to be bounded at 3pt because an empty line took the
        // document's default font — the engine had no way to be told otherwise for the LAST block,
        // whose attributes travel on a separator it does not have. It does now
        // (`id_emptyLineAttributesByBlock`), so typing the first character of an author no longer
        // changes the row's height.
        XCTAssertEqual(author.height, filled.height, accuracy: 0.5,
                       "empty \(author.height) vs filled \(filled.height)")

    }

    /// An empty author line shows "Add author", or there is nothing on screen to aim at.
    ///
    /// Reported from the device as "I don't see any author field". The row IS reserved — measured —
    /// but an empty line inside the pill is indistinguishable from the pill's own padding, so the
    /// field exists and cannot be found. Legacy draws `quoteAuthorPlaceholderText` for exactly this.
    func test_anEmptyAuthorLineShowsItsPlaceholder() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")])),
        ])
        window.layoutIfNeeded()

        let labels = editor.engine.subviews.compactMap { $0 as? SecondaryPlaceholderLabel }
        XCTAssertEqual(labels.count, 1, "the empty author line needs a placeholder")
        XCTAssertEqual(labels.first?.text, quoteAuthorPlaceholderText)

        // The author line's own row, not somewhere else in the quote.
        let author = editor.engine.id_frameForBlock(at: 1)
        XCTAssertEqual(labels.first?.frame.midY ?? 0, author.midY, accuracy: 2.0)
    }

    /// …and it goes as soon as there is an author to show.
    func test_anAuthoredLineShowsNoPlaceholder() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "the quote")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()

        XCTAssertTrue(editor.engine.subviews.compactMap { $0 as? SecondaryPlaceholderLabel }.isEmpty,
                      "a filled line must not sit under a placeholder")
    }

    /// Return in the LANGUAGE line moves into the code, and must not wedge a paragraph between the
    /// two halves of the code block.
    ///
    /// The author line is a container's LAST engine block, so the block a Return splits off sits
    /// after the container and can simply become the paragraph the Return escapes into. A language
    /// line is the FIRST, so the same block lands BETWEEN the language and its code — which would
    /// split the container's engine blocks into a non-contiguous group and break every pass that
    /// assumes otherwise.
    func test_returnInTheLanguageLineMovesIntoTheCodeWithoutSplittingIt() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift",
                            runs: [TextRun(text: "let x = 1")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 5),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the end of the language line")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")

        let settled = expectation(description: "the split was repaired")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        XCTAssertEqual(editor.document.blocks.count, 1,
                       "still ONE code block: \(editor.document.blocks)")
        guard case let .code(code)? = editor.document.blocks.first else {
            return XCTFail("no longer a code block: \(editor.document.blocks)")
        }
        XCTAssertEqual(code.language, "swift", "the language survives")
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x = 1", "and so does the code")
        XCTAssertEqual(editor.engine.attributedBlocks.count, 2,
                       "the language line and the code, with nothing wedged between them")
    }

    /// A TRAILING empty author line takes its own indent, caret included.
    ///
    /// The reported case, and the one the separator could never reach: a block quote's author is the
    /// document's last engine block, so there is no following newline for its attributes to travel
    /// on. Leading-aligned, unlike a pull quote's centred one, so "where the text starts" is a
    /// meaningful thing to compare a caret against.
    func test_aTrailingEmptyAuthorLineTakesItsIndent() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ], author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()
        let authoredX = editor.engine.id_rects(forCanonicalRange: NSRange(location: 7, length: 3))
            .map(\.cgRectValue.minX).min()

        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q0"), children: [
                .paragraph(ParagraphBlock(id: BlockID("c0"), runs: [TextRun(text: "quoted")])),
            ])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        guard let authoredX,
              let position = editor.engine.position(from: editor.engine.beginningOfDocument,
                                                    offset: 7) else {
            return XCTFail("no author geometry")
        }
        XCTAssertGreaterThan(authoredX, 1.0, "precondition: the author line IS indented")
        XCTAssertEqual(editor.engine.caretRect(for: position).minX, authoredX, accuracy: 2.0,
                       "the caret of an empty trailing author line sits at the line's indent")
    }

    /// Return inside a pull quote leaves the quote, rather than wedging a paragraph inside it.
    ///
    /// A `PullQuote` holds ONE runs list, and the engine separates blocks by newlines, so it cannot
    /// hold a second paragraph. The block a Return splits off therefore landed BETWEEN the quote's
    /// text and its author line: the container's engine blocks stopped being contiguous, so the pill
    /// stretched over the intruder (its height grew while the first line stayed put) and the stray
    /// paragraph became a spacing unit of its own, taking a full inter-block gap.
    func test_returnInsideAPullQuoteIsANewlineInsideIt() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "quoted")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let start = editor.engine.beginningOfDocument
        guard let end = editor.engine.position(from: start, offset: 3),
              let caret = editor.engine.textRange(from: end, to: end) else {
            return XCTFail("could not address the quote")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")
        XCTAssertEqual(editor.document.blocks.count, 1, "still ONE quote: \(editor.document.blocks)")
        guard case let .pullQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("the quote came apart: \(editor.document.blocks)")
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "quo\nted", "the Return is a line inside the quote's text")
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada", "and the author is intact")
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["quo\u{2028}ted", "Ada"])
    }

    /// Undo after a structural repair restores a coherent document, not a spliced one.
    ///
    /// A repair re-applies the document out of band, so the engine's own undo entry — recorded
    /// against text RANGES from before it — no longer describes the text it would be applied to.
    /// Undoing it spliced the author into the body, carrying the author's font and colour with it,
    /// which is exactly what the report describes.
    func test_undoAfterAPullQuoteRepairDoesNotSpliceTheAuthorIntoTheBody() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "quoted")],
                                 author: [TextRun(text: "Ada")])),
        ])
        window.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // Return in the MIDDLE of the body, which is what splits a block off inside the container.
        let start = editor.engine.beginningOfDocument
        guard let mid = editor.engine.position(from: start, offset: 3),
              let caret = editor.engine.textRange(from: mid, to: mid) else {
            return XCTFail("could not address the middle of the quote")
        }
        editor.engine.selectedTextRange = caret
        editor.engine.insertText("\n")

        let repaired = expectation(description: "repaired")
        DispatchQueue.main.async { repaired.fulfill() }
        wait(for: [repaired], timeout: 2.0)

        XCTAssertNotNil(editor.engine.undoManager, "the engine exposes no undo manager at all")
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false,
                      "precondition: there IS something to undo, or this asserts nothing")
        editor.engine.undoManager?.undo()
        let settled = expectation(description: "undo settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        guard case let .pullQuote(quote)? = editor.document.blocks.first else {
            return XCTFail("no pull quote after undo: \(editor.document.blocks)")
        }
        XCTAssertFalse(quote.runs.map(\.text).joined().contains("Ada"),
                       "the author was spliced into the body: \(quote.runs.map(\.text))")
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ada",
                       "and the author itself must survive")
        XCTAssertEqual(quote.runs.map(\.text).joined(), "quoted",
                       "undo goes back to before the Return, in one step")
        XCTAssertEqual(editor.document.blocks.count, 1,
                       "with nothing left over: \(editor.document.blocks)")
    }
}
