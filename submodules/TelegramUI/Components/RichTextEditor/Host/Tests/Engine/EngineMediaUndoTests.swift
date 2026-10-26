import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Undo and redo of the media rules: the text replays, and the ROLES come back from the snapshot —
/// a media unit returns as a unit, never as loose paragraphs (spec §6.5).
@available(iOS 18.4, *)
final class EngineMediaUndoTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func item(_ id: String) -> MediaItem { MediaItem(mediaID: id, kind: .image, naturalSize: Size2D(width: 1000, height: 500)) }
    private func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)")], caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }
    private func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{FFFC}", with: "▣") } }
    private func kinds() -> [String] {
        editor.currentRoles.map { role in
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    private func undo() { editor.engine.undoManager?.undo(); turn() }
    private func redo() { editor.engine.undoManager?.redo(); turn() }
    private func atomHasAttachment(_ index: Int) -> Bool {
        editor.engine.attributedBlocks[index].attribute(.attachment, at: 0, effectiveRange: nil) is MediaTextAttachment
    }

    func test_undoRestoresAUnitDeletedInTwoSteps() {
        load([para("p0", "before"), photo("a", "cap")])
        caret(8); editor.engine.deleteBackward(); turn()
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(kinds(), ["std", "std"])
        undo()
        XCTAssertEqual(strings(), ["before", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        XCTAssertTrue(atomHasAttachment(1), "the attachment came back with the character")
        guard case .media = editor.document.blocks[1] else { return XCTFail("\(editor.document.blocks)") }
        redo()
        XCTAssertEqual(strings(), ["before", ""])
        XCTAssertEqual(kinds(), ["std", "std"])
    }

    func test_undoRestoresAUnitDroppedBySelectAll() {
        load([photo("a", "cap"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 0, length: 11)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
        XCTAssertTrue(atomHasAttachment(0))
    }

    func test_undoOfTypingAtTheGapRemovesTheParagraphAbove() {
        load([photo("a", "cap")])
        caret(0); editor.engine.insertText("x"); turn()
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        undo()
        XCTAssertEqual(strings(), ["▣", "cap"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        redo()
        XCTAssertEqual(strings(), ["x", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
    }

    func test_undoOfACaptionReturnRejoinsTheCaption() {
        load([photo("a", "caption")])
        caret(5); editor.engine.insertText("\n"); turn()
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
        undo()
        XCTAssertEqual(strings(), ["▣", "caption"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    func test_undoOfATruncatingRangeRestoresTheCaption() {
        load([para("p0", "before"), photo("a", "caption")])
        editor.engineSelectedRange = NSRange(location: 3, length: 9)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(strings(), ["bef", "▣", "tion"])
        undo()
        XCTAssertEqual(strings(), ["before", "▣", "caption"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
    }

    // MARK: - The ••• verbs (spec §10: undo AND redo for each)

    private func album(_ id: String, _ count: Int) -> Block {
        .media(MediaBlock(id: BlockID(id), items: (1...count).map { MediaItem(mediaID: "\(id)-\($0)", kind: .image, naturalSize: Size2D(width: 1000, height: 500)) },
                          caption: [TextRun(text: "cap")]))
    }
    /// The model read back through `editor.document`, which is what a host sees.
    private func media(_ id: String) -> MediaBlock? {
        editor.document.blocks.first { $0.id == BlockID(id) }.flatMap { if case let .media(m) = $0 { return m }; return nil }
    }

    func test_deleteMediaBlockUndoesAndRedoesAsAUnit() {
        load([para("p0", "before"), photo("a", "cap")])
        turn()
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        editor.deleteMediaBlock(id: BlockID("a"))
        turn()
        XCTAssertEqual(strings(), ["before", ""])
        XCTAssertEqual(kinds(), ["std", "std"])
        XCTAssertNil(media("a"))
        undo()
        XCTAssertEqual(strings(), ["before", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"], "back as a unit, not as loose paragraphs")
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["m-a"])
        XCTAssertTrue(atomHasAttachment(1))
        redo()
        XCTAssertEqual(strings(), ["before", ""])
        XCTAssertEqual(kinds(), ["std", "std"])
    }

    func test_deleteMediaItemUndoesAndRedoes() {
        load([album("a", 2)])
        turn()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["a-1", "a-2"])
        editor.deleteMediaItem(blockID: BlockID("a"), itemIndex: 0)
        turn()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["a-2"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        undo()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["a-1", "a-2"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        redo()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["a-2"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    func test_addMediaItemUndoesAndRedoes() {
        load([photo("a", "cap")])
        turn()
        editor.addMediaItem(blockID: BlockID("a"), mediaID: "b", naturalSize: CGSize(width: 10, height: 10), kind: .video)
        turn()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["m-a", "b"])
        undo()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["m-a"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        redo()
        XCTAssertEqual(media("a")?.items.map(\.mediaID), ["m-a", "b"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    func test_toggleMediaDisplayModeUndoesAndRedoes() {
        load([album("a", 2)])
        turn()
        XCTAssertEqual(media("a")?.displayMode, .mosaic)
        editor.toggleMediaDisplayMode(blockID: BlockID("a"))
        turn()
        XCTAssertEqual(media("a")?.displayMode, .slideshow)
        undo()
        XCTAssertEqual(media("a")?.displayMode, .mosaic)
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        redo()
        XCTAssertEqual(media("a")?.displayMode, .slideshow)
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
    }

    func test_theFirstDeletionStepRegistersNoUndo() {
        load([para("p0", "before"), photo("a", "cap")])
        turn()
        let before = editor.engine.undoManager?.canUndo ?? false
        caret(8); editor.engine.deleteBackward(); turn()
        XCTAssertEqual(editor.engine.undoManager?.canUndo ?? false, before, "selecting the atom is a caret move")
    }
}
