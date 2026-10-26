import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **Copy and paste carry a `Document`, not a string.**
///
/// The engine can only write plain text — measured, before any of this existed: copying a document
/// of `paragraph / table / paragraph` put exactly ONE representation on the pasteboard,
/// `public.utf8-plain-text`, holding `"before\n\n\n\n\nafter"`. The table's structure was not
/// degraded, it was absent; the five newlines are its four empty cells. Reported as "tables are not
/// preserved when copying/pasting", and it is every block structure, not only tables.
///
/// Legacy has carried the answer since Phase 5d: `RichTextEditorClipboard` writes THREE
/// representations — the private fragment UTI (JSON `Document`, lossless within the app),
/// `public.rtf` for other apps, and plain text — and paste reads them richest-first. The engine
/// editor simply never reached it, because `copy:`/`paste:` land on the ENGINE (the first responder)
/// rather than on this wrapper.
///
/// What makes this small is the global position axis: copy is `selectedGlobalRange()` +
/// `Document.extractFragment`, and paste is `Document.replacingRange` — the same two functions the
/// AI-compose flow uses, which is why no clipboard-specific range logic exists here.
@available(iOS 18.4, *)
final class EngineClipboardTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.engine.becomeFirstResponder()
        UIPasteboard.general.items = []
    }
    override func tearDown() {
        UIPasteboard.general.items = []
        window.isHidden = true; window = nil; editor = nil; super.tearDown()
    }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func kinds(_ document: Document) -> [String] {
        document.blocks.map { $0.caseNameForDiagnostics }
    }
    /// Selects every engine block, the whole document.
    private func selectAll() {
        let total = editor.currentRoles.indices.reduce(0) { $0 + editor.flatLength(ofRoleAt: $1) + 1 } - 1
        editor.engineSelectedRange = NSRange(location: 0, length: max(0, total))
    }
    private func caret(atEndOfRoleWithBlockID id: String) {
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID(id) }) else {
            return XCTFail("no role for \(id)")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index)
                                             + editor.flatLength(ofRoleAt: index), length: 0)
    }
    /// **The ENGINE's own paste is asynchronous** — measured: straight after `paste(nil)` the
    /// document still reads empty, and the text arrives a run-loop turn later. The rich path is
    /// synchronous (it goes through the document setter), so spinning covers both and keeps the
    /// plain-text control honest rather than passing for the wrong reason.
    private func paste() {
        editor.engine.paste(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    }
    private func pasteboardFragment() -> Document? {
        guard let data = UIPasteboard.general.data(forPasteboardType: RichTextEditorClipboard.fragmentUTI)
        else { return nil }
        return try? DocumentCodec.decode(data)
    }
    private func tableDocument() -> Document {
        Document(blocks: [para("p0", "before"), .table(TableBlock.empty(rows: 2, columns: 2)), para("p1", "after")])
    }

    // MARK: - Copy

    func test_copyingATableWritesTheFragmentRepresentation() {
        editor.document = tableDocument()
        selectAll()

        editor.engine.copy(nil)

        guard let fragment = pasteboardFragment() else {
            return XCTFail("no fragment on the pasteboard — the table cannot survive a plain-text copy")
        }
        XCTAssertEqual(kinds(fragment), ["paragraph", "table", "paragraph"])
    }

    /// The other two representations are what makes a copy useful OUTSIDE the app, and plain text is
    /// also what `canPerformAction(paste:)` keys on, so losing it would disable Paste.
    func test_copyAlsoWritesRTFAndPlainText() {
        editor.document = tableDocument()
        selectAll()

        editor.engine.copy(nil)

        XCTAssertNotNil(UIPasteboard.general.data(forPasteboardType: "public.rtf"), "cross-app copy")
        XCTAssertNotNil(UIPasteboard.general.string, "plain text")
    }

    // MARK: - Paste

    func test_pastingRestoresTheTable() {
        editor.document = tableDocument()
        selectAll()
        editor.engine.copy(nil)

        editor.document = Document(blocks: [para("q0", "target")])
        caret(atEndOfRoleWithBlockID: "q0")
        paste()

        XCTAssertTrue(kinds(editor.document).contains("table"),
                      "the pasted table must arrive as a table, not as its cells' newlines")
    }

    /// A fragment sits on the pasteboard and can be pasted repeatedly. A block id keys the
    /// hosted-view pool, so two blocks sharing one id share one hosted view.
    func test_pastingTwiceGivesDistinctBlockIDs() {
        editor.document = tableDocument()
        selectAll()
        editor.engine.copy(nil)

        editor.document = Document(blocks: [para("q0", "target")])
        caret(atEndOfRoleWithBlockID: "q0")
        paste()
        paste()

        let ids = editor.document.blocks.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "every pasted block needs an id of its own")
    }

    /// Pasting over a selection replaces it, rather than appending beside it.
    func test_pastingOverASelectionReplacesIt() {
        editor.document = Document(blocks: [para("p0", "keep this drop")])
        editor.engineSelectedRange = NSRange(location: 5, length: 4)   // "this"
        editor.engine.copy(nil)

        editor.document = Document(blocks: [para("q0", "AAA BBB")])
        editor.engineSelectedRange = NSRange(location: 4, length: 3)   // "BBB"
        paste()

        let text = editor.document.blocks.compactMap { block -> String? in
            guard case let .paragraph(p) = block else { return nil }
            return p.runs.map(\.text).joined()
        }.joined()
        XCTAssertEqual(text, "AAA this")
    }

    // MARK: - Cut

    func test_cutWritesTheFragmentAndRemovesTheSelection() {
        editor.document = tableDocument()
        selectAll()

        editor.engine.cut(nil)

        XCTAssertNotNil(pasteboardFragment(), "cut writes what copy writes")
        XCTAssertFalse(kinds(editor.document).contains("table"), "the cut content is gone from the document")
    }

    // MARK: - Per-occurrence identity

    /// **A pasted custom emoji needs an `instanceID` of its own.** `EmojiRef.instanceID` is "unique
    /// per occurrence" and IS the view-pooling key (`syncCustomEmojiViews` keys `customEmojiViews`
    /// on it, deliberately, so the same sticker twice is two views). A fragment carries the
    /// original's verbatim, so after a paste two occurrences claimed ONE view and only one of them
    /// rendered — reported as "after I pasted a paragraph with a custom emoji, the custom emoji is
    /// only displayed in the pasted one".
    ///
    /// Block ids were already regenerated; this is the RUN-level identity beside them, and it is the
    /// only one — a formula and an inline button have no identity of their own.
    func test_aPastedCustomEmojiGetsItsOwnInstanceID() {
        var attributes = CharacterAttributes()
        attributes.emoji = EmojiRef(id: "sticker-1", instanceID: "original-instance")
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "a"), TextRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        selectAll()
        editor.engine.copy(nil)

        caret(atEndOfRoleWithBlockID: "p0")
        paste()

        let instanceIDs = editor.document.blocks.flatMap { block -> [String] in
            guard case let .paragraph(p) = block else { return [] }
            return p.runs.compactMap { $0.attributes.emoji?.instanceID }
        }
        XCTAssertEqual(instanceIDs.count, 2, "both occurrences must survive the paste")
        XCTAssertEqual(Set(instanceIDs).count, 2,
                       "two occurrences sharing one instanceID share one hosted view, so only one draws")
    }

    /// The same fact at the level the user sees it: TWO hosted views, not one.
    func test_bothCopiesOfAPastedEmojiAreHosted() {
        final class StubEmojiView: UIView, RichTextEmojiView { var dynamicColor: UIColor? }
        editor.registerEmojiViewProvider { _, _ in StubEmojiView() }

        var attributes = CharacterAttributes()
        attributes.emoji = EmojiRef(id: "sticker-1", instanceID: "original-instance")
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "a"), TextRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        selectAll()
        editor.engine.copy(nil)

        caret(atEndOfRoleWithBlockID: "p0")
        paste()
        window.layoutIfNeeded()

        let hosted = editor.engine.subviews.compactMap { $0 as? StubEmojiView }
        XCTAssertEqual(hosted.count, 2, "each occurrence draws its own emoji")
    }

    // MARK: - Controls

    /// A pasteboard holding ONLY plain text still pastes, through the engine, unchanged.
    func test_plainTextPasteStillGoesToTheEngine() {
        editor.document = Document(blocks: [para("p0", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        UIPasteboard.general.items = [["public.utf8-plain-text": "plain"]]

        paste()

        XCTAssertEqual(editor.document.blocks.count, 1)
        guard case let .paragraph(p) = editor.document.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertEqual(p.runs.map(\.text).joined(), "plain")
    }

    /// A collapsed caret with nothing selected writes nothing and leaves the pasteboard alone.
    func test_copyingWithNoSelectionWritesNothing() {
        editor.document = tableDocument()
        editor.engineSelectedRange = NSRange(location: 0, length: 0)

        editor.engine.copy(nil)

        XCTAssertNil(pasteboardFragment())
    }
}
