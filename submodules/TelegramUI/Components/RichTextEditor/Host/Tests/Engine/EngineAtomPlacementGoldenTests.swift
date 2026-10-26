import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 4 — the placement branch `insertMediaBlock` uses, RECORDED before it is
/// extracted for button rows to share.
///
/// Every assertion here describes behaviour that already shipped. If one of them changes during the
/// extraction, the extraction is wrong — that is the entire purpose of this file.
@available(iOS 18.4, *)
final class EngineAtomPlacementGoldenTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    /// AUDIO, deliberately: `MediaKind.audio` is caption-less, which is the path a button row takes.
    private func insertAudio() {
        editor.insertMedia(mediaID: "a", naturalSize: CGSize(width: 0, height: 0), kind: .audio, caption: [])
    }
    private func insertPhoto() {
        editor.insertMedia(mediaID: "m", naturalSize: CGSize(width: 1000, height: 500), kind: .image, caption: [])
    }
    /// The document's shape as kinds, so a placement is readable at a glance.
    private func shape() -> [String] {
        editor.document.blocks.map { block in
            switch block {
            case .paragraph: return "p"
            case .media: return "media"
            case .blockQuote: return "quote"
            case .details: return "details"
            case .table: return "table"
            case .buttonRow: return "row"
            case .code: return "code"
            case .pullQuote: return "pull"
            }
        }
    }
    private func caretToStartOfRole(_ index: Int) {
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index), length: 0)
    }

    func test_anEmptyCaretParagraphIsReplaced() {
        editor.document = Document(blocks: [para("p", "")])
        caretToStartOfRole(0)
        insertAudio()
        XCTAssertEqual(shape(), ["media", "p"],
                       "the empty paragraph is consumed; the trailing one is minted for the caption-less atom")
    }

    func test_aCaretAtAParagraphStartInsertsBefore() {
        editor.document = Document(blocks: [para("p", "text")])
        caretToStartOfRole(0)
        insertAudio()
        XCTAssertEqual(shape(), ["media", "p"])
        XCTAssertEqual(editor.document.blocks[1].flatText, "text")
    }

    func test_aCaretAtAParagraphEndInsertsAfter() {
        editor.document = Document(blocks: [para("p", "text")])
        editor.engineSelectedRange = NSRange(location: editor.flatLength(ofRoleAt: 0), length: 0)
        insertAudio()
        XCTAssertEqual(shape(), ["p", "media", "p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "text")
    }

    func test_aCaretMidParagraphSplitsIt() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        insertAudio()
        XCTAssertEqual(shape(), ["p", "media", "p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "ab")
        XCTAssertEqual(editor.document.blocks[2].flatText, "cd")
    }

    func test_aCaretInsideAQuoteMakesTheAtomAChildOfThatQuote() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "in")], author: [])),
        ])
        caretToStartOfRole(0)
        insertPhoto()
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("\(shape())") }
        XCTAssertTrue(quote.children.contains { if case .media = $0 { return true }; return false },
                      "the unit takes the caret's own ancestry")
    }

    func test_aCaretInACellPlacesTheAtomAfterTheWholeTable() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 1, columns: 2)), para("after", "x")])
        let cell = editor.currentRoles.firstIndex { $0.owningTable != nil }!
        caretToStartOfRole(cell)
        insertAudio()
        XCTAssertEqual(shape(), ["table", "media", "p"],
                       "placement is against the CONTAINER, and a cell's container is the table")
    }

    func test_aCaptionlessAtomEndingAContainerMintsATrailingParagraphInsideIt() {
        editor.document = Document(blocks: [
            .details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                  children: [para("c", "body")], expanded: true)),
            para("after", "outside"),
        ])
        let body = editor.currentRoles.firstIndex { $0.containerID == BlockID("c") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: body)
                                             + editor.flatLength(ofRoleAt: body), length: 0)
        insertAudio()
        guard case let .details(details) = editor.document.blocks[0] else { return XCTFail("\(shape())") }
        XCTAssertEqual(details.children.count, 3,
                       "body, the audio atom, and a paragraph minted INSIDE the details to type into")
    }
}
