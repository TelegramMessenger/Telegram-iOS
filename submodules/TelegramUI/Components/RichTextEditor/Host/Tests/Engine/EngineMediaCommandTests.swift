import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The host commands (spec §7): `insertMedia`'s four placements and caret rule, `insertDocument`,
/// and — Task 11 — the ••• menu's request and verbs.
@available(iOS 18.4, *)
final class EngineMediaCommandTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func item(_ id: String, kind: MediaKind = .image) -> MediaItem { MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: 1000, height: 500)) }
    func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)")], caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }
    func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{FFFC}", with: "▣") } }
    func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            if role.innermostAncestor != nil { return "child" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    /// A CAPTION-LESS atom needs somewhere to type after it — that is what the trailing-paragraph
    /// branch exists for. Asked as "is there a next role that is a paragraph", an atom that is a
    /// container's LAST child saw the block FOLLOWING the container, minted nothing, and left the
    /// caret outside the block with nowhere to type. The reported table bug's shape exactly.
    func test_aCaptionlessAtomAtADetailsEndGetsItsTrailingParagraphInsideTheDetails() {
        load([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                    children: [para("a", "one")], expanded: true)),
              para("after", "z")])
        caret(editor.flatOffset(ofRoleAt: 1) + editor.flatLength(ofRoleAt: 1))
        editor.insertMedia(mediaID: "aud", naturalSize: CGSize(width: 1, height: 1), kind: .audio, caption: [])
        XCTAssertEqual(editor.currentRoles.map(\.containerDepth), [1, 1, 1, 1, 0],
                       "a trailing paragraph INSIDE the details, got \(kinds()) strings \(strings())")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: editor.flatOffset(ofRoleAt: 3), length: 0),
                       "and the caret is in it, not in the block after the details")
    }

    func insertPhoto(caption: String = "") {
        editor.insertMedia(mediaID: "new", naturalSize: CGSize(width: 800, height: 600), kind: .image,
                           caption: caption.isEmpty ? [] : [TextRun(text: caption)])
    }
    func atomHasAttachment(_ index: Int) -> Bool {
        editor.engine.attributedBlocks[index].attribute(.attachment, at: 0, effectiveRange: nil) is MediaTextAttachment
    }

    // MARK: - §7.1 insertMedia

    func test_anEmptyCaretParagraphIsReplaced() {
        load([para("p0", "")])
        caret(0)
        insertPhoto(caption: "cap")
        XCTAssertEqual(strings(), ["▣", "cap"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        XCTAssertTrue(atomHasAttachment(0))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "the caption's start")
        guard case let .media(media) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(media.items.first?.mediaID, "new")
        XCTAssertEqual(media.naturalSize, Size2D(width: 800, height: 600))
    }

    func test_aCaretMidParagraphSplitsIt() {
        load([para("p0", "hello world")])
        caret(5)
        insertPhoto()
        XCTAssertEqual(strings(), ["hello", "▣", "", " world"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0))
    }

    func test_aCaretAtOffsetZeroInsertsBefore() {
        load([para("p0", "text")])
        caret(0)
        insertPhoto()
        XCTAssertEqual(strings(), ["▣", "", "text"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
    }

    func test_aCaretAtTheEndInsertsAfter() {
        load([para("p0", "text")])
        caret(4)
        insertPhoto()
        XCTAssertEqual(strings(), ["text", "▣", ""])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0))
    }

    func test_aCaptionlessKindLandsTheCaretInTheFollowingParagraphAppendingOne() {
        load([para("p0", "text")])
        caret(4)
        editor.insertMedia(mediaID: "song", naturalSize: .zero, kind: .audio, caption: [])
        XCTAssertEqual(strings(), ["text", "▣", ""])
        XCTAssertEqual(kinds(), ["std", "media", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0))
        load([para("p0", "text"), para("p1", "after")])
        caret(4)
        editor.insertMedia(mediaID: "doc", naturalSize: .zero, kind: .document, caption: [])
        XCTAssertEqual(strings(), ["text", "▣", "after"], "an existing paragraph is reused")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0))
    }

    /// A caret in a SECOND line places the unit outside the whole container, exactly as a caret in
    /// the container's body does — the language line sits ABOVE the code, so `index + 1` would put
    /// the unit between the line and its own body.
    func test_aCaretInACodeBlocksLanguageLinePlacesTheUnitAfterTheWholeCodeBlock() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")]))])
        caret(2)                                                   // inside "swift", the language line
        insertPhoto()
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code", "media", "secondary.mediaCaption"])
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(code.language, "swift", "the line the caret was in is untouched")
    }

    /// The caption arrives as RUNS and must be rendered as a document set renders it: a flattened
    /// `map(\.text).joined()` would drop bold, links and custom emoji from a passed caption.
    func test_aPassedCaptionKeepsItsRunAttributes() {
        load([para("p0", "")])
        caret(0)
        var bold = CharacterAttributes(); bold.bold = true
        editor.insertMedia(mediaID: "new", naturalSize: CGSize(width: 800, height: 600), kind: .image,
                           caption: [TextRun(text: "b", attributes: bold)])
        XCTAssertEqual(strings(), ["▣", "b"])
        guard case let .media(media) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(media.caption.first?.attributes.bold, true, "the caption's bold survived the insert")
    }

    func test_aSelectionIsReplacedFirst() {
        load([para("p0", "hello world")])
        editor.engineSelectedRange = NSRange(location: 5, length: 6)
        insertPhoto()
        XCTAssertEqual(strings(), ["hello", "▣", ""])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
    }

    /// Was a no-op: legacy's v1 rule refused media inside a quote and the nesting rung kept the
    /// guard, but the RENDER half landed with that rung, so the only thing still refusing was the
    /// guard itself — to a user holding a quote the + button did nothing (device, K3 2026-09-08).
    /// The unit now takes the caret's own ancestry and lands as a child of the quote.
    func test_insideAQuoteLandsInTheQuote() {
        load([.blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "quoted")]))])
        caret(3)
        insertPhoto()
        // The caret is mid-paragraph, so the quoted paragraph splits around the unit, exactly as it
        // does at the top level.
        XCTAssertEqual(strings(), ["quo", "▣", "", "ted", ""])
        XCTAssertEqual(editor.currentRoles.map(\.containerDepth), [1, 1, 1, 1, 1],
                       "every role — the split halves, the atom, its caption — is IN the quote")
        guard case .media = editor.currentRoles[1].shape else {
            return XCTFail("role 1 is the atom, not \(editor.currentRoles[1].shape)")
        }
    }

    func test_insideACellInsertsAfterTheTable() {
        load([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"), blocks: [para("cp", "aa")])])])), para("p1", "after")])
        caret(1)
        insertPhoto()
        XCTAssertEqual(kinds(), ["cell", "media", "secondary.mediaCaption", "std"])
    }

    /// Both ends of the same rule, because a code block's second line is ABOVE its body: a caret at
    /// the body's offset 0 puts the unit above the WHOLE block (not between the language line and
    /// the code, which is what minted a second language line and dropped the language), and a caret
    /// at the body's end puts it below the whole block.
    func test_aCaretInACodeBodyPlacesTheUnitOutsideTheWholeCodeBlock() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")]))])
        XCTAssertEqual(strings(), ["swift", "let x"], "the language line is the block above the body")
        caret(6)                                                   // "swift" + "\n" + "let x": offset 0 of the code body
        insertPhoto()
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "secondary.codeLanguage", "code"])
        guard case let .code(above) = editor.document.blocks[1] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(above.language, "swift", "the language survives — no second empty line was minted")

        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")]))])
        caret(11)                                                  // the end of the code body
        insertPhoto()
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code", "media", "secondary.mediaCaption"])
        guard case let .code(below) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(below.language, "swift")
    }

    func test_aCaretInAPullQuoteBodyInsertsAfterItsAuthorLine() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        caret(3)                                                   // inside "quoted"
        insertPhoto()
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor", "media", "secondary.mediaCaption"])
    }

    func test_insertMediaDoesNotTakeFocusAndDoesNotClearHistory() {
        editor.document = Document(blocks: [para("p0", "text")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        caret(4); editor.engine.insertText("!"); turn()
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false)
        XCTAssertTrue(editor.engine.resignFirstResponder())
        insertPhoto()
        XCTAssertFalse(editor.engine.isFirstResponder)
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false, "history survives")
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(kinds(), ["std"], "the insert is undone as ONE step")
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(strings(), ["text"], "and the typing before it is still there to undo")
    }

    // MARK: - §7.2 insertDocument

    func test_insertDocumentSplicesAnAlbumAfterTheCaretsBlock() {
        load([para("p0", "text"), para("p1", "after")])
        caret(2)
        let album = MediaBlock(id: BlockID("al"), items: [item("1"), item("2")], caption: [TextRun(text: "two")])
        editor.insertDocument(Document(blocks: [.media(album)]))
        XCTAssertEqual(strings(), ["text", "▣", "two", "after"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption", "std"])
        XCTAssertTrue(atomHasAttachment(1))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 10, length: 0), "the end of the inserted content")
        XCTAssertEqual(editor.document.blocks[1], .media(album))
    }

    func test_insertDocumentReplacesAnEmptyCaretParagraphAndKeepsStyles() {
        load([para("p0", "")])
        caret(0)
        editor.insertDocument(Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")]))]))
        XCTAssertEqual(strings(), ["Title"])
        guard case let .paragraph(heading) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(heading.style, .heading1)
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, editor.bridge.styleSheet.font(for: .heading1, attributes: .plain).pointSize)
    }

    // MARK: - §7.3 the control menu

    private func album(_ id: String, _ count: Int) -> Block {
        .media(MediaBlock(id: BlockID(id), items: (1...count).map { item("\(id)-\($0)") }, caption: [TextRun(text: "cap")]))
    }
    private func media(_ id: String) -> MediaBlock? {
        editor.document.blocks.first { $0.id == BlockID(id) }.flatMap { if case let .media(m) = $0 { return m }; return nil }
    }

    func test_aControlTapBuildsARequestBoundToTheBlock() {
        var received: MediaControlRequest?
        editor.onRequestMediaControl = { received = $0 }
        load([para("p0", "before"), album("a", 2)])
        let anchor = UIView()
        editor.handleMediaControlTapped(blockID: BlockID("a"), kind: .more, itemIndex: nil, anchorView: anchor, sourceRect: CGRect(x: 1, y: 2, width: 3, height: 4))
        guard let request = received else { return XCTFail("no request") }
        XCTAssertEqual(request.control, .more)
        XCTAssertEqual(request.mediaID, "a-1")
        XCTAssertNil(request.itemIndex)
        XCTAssertFalse(request.isSpoiler)
        XCTAssertTrue(request.view === anchor)
        XCTAssertNotNil(request.toggleLayout, "two photos: togglable")
        XCTAssertNotNil(request.addMore)
        XCTAssertNil(request.replace)
        request.delete()
        XCTAssertEqual(kinds(), ["std", "std"], "delete removes the whole block, an empty paragraph in its place")
    }

    func test_deletingOneItemOfAnAlbumKeepsTheRest_andTheLastOneDeletesTheBlock() {
        load([album("a", 2)])
        editor.deleteMediaItem(blockID: BlockID("a"), itemIndex: 0)
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["a-2"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        editor.deleteMediaItem(blockID: BlockID("a"), itemIndex: 0)
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_spoilerTogglesOneCellOrTheWholeBlock() {
        load([album("a", 2)])
        editor.toggleMediaSpoiler(blockID: BlockID("a"), itemIndex: 1)
        XCTAssertEqual(media("a")?.items.map(\.isSpoiler), [false, true])
        editor.toggleMediaSpoiler(blockID: BlockID("a"), itemIndex: nil)
        XCTAssertEqual(media("a")?.items.map(\.isSpoiler), [true, true], "the whole block takes the negation of the FIRST item's flag")
        editor.toggleMediaSpoiler(blockID: BlockID("a"), itemIndex: 7)
        XCTAssertEqual(media("a")?.items.map(\.isSpoiler), [false, false], "out of range flips the whole block too")
    }

    func test_addMoreAppendsAndTheLayoutToggleFlips() {
        load([photo("a", "cap")])
        editor.addMediaItem(blockID: BlockID("a"), mediaID: "b", naturalSize: CGSize(width: 10, height: 10), kind: .video)
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["m-a", "b"])
        editor.toggleMediaDisplayMode(blockID: BlockID("a"))
        XCTAssertEqual(media("a")?.displayMode, .slideshow)
        editor.toggleMediaDisplayMode(blockID: BlockID("a"))
        XCTAssertEqual(media("a")?.displayMode, .mosaic)
        editor.addMediaItem(blockID: BlockID("a"), mediaID: "s", naturalSize: .zero, kind: .audio)
        XCTAssertEqual(media("a")?.items.count, 2, "audio is never added to an album")
    }

    func test_aRoleChangeUndoesByIdentityAndReRendersTheAtom() {
        load([para("p0", "before"), album("a", 2)])
        turn()
        editor.toggleMediaSpoiler(blockID: BlockID("a"), itemIndex: 0)
        let attachment = editor.engine.attributedBlocks[1].attribute(.attachment, at: 0, effectiveRange: nil) as? MediaTextAttachment
        XCTAssertEqual(attachment?.shape.items.first?.isSpoiler, true, "the attachment carries the new shape")
        turn()
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(media("a")?.items.map(\.isSpoiler), [false, false])
        editor.engine.undoManager?.redo(); turn()
        XCTAssertEqual(media("a")?.items.map(\.isSpoiler), [true, false])
    }
}
