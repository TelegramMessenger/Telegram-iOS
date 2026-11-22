import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-details §4: a details emits its title first, then its children ONLY when expanded. Folded, the
/// body is not in the engine at all — it rides in the role's shape (§7.1).
@available(iOS 18.4, *)
final class EngineDetailsRoundTripTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func details(_ id: String, title: String, _ children: [Block], expanded: Bool = true) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: expanded))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else {
                switch role.shape {
                case .media: kind = "media"
                case .buttonRow: kind = "buttonRow"
                case .code: kind = "code"
                case .pullQuote: kind = "pullQuote"
                case .collapsedQuote: kind = "collapsedQuote"
                case .paragraph: kind = "p"
                }
            }
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks) }

    func test_anExpandedDetailsEmitsItsTitleThenItsChildren() {
        load([details("d", title: "Summary", [para("a", "one"), para("b", "two")])])
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@1"])
        XCTAssertEqual(strings(), ["Summary", "one", "two"])
    }

    func test_aFoldedDetailsEmitsOnlyItsTitle() {
        load([details("d", title: "Summary", [para("a", "one")], expanded: false)])
        XCTAssertEqual(roles(), ["detailsTitle@1"], "the body is NOT in the engine")
        XCTAssertEqual(strings(), ["Summary"])
    }

    /// The fold's whole mechanism: the hidden body has exactly one home, and a set-and-read must not
    /// lose it (§7.1).
    func test_aFoldedDetailsRoundTripsItsHiddenBody() {
        load([details("d", title: "Summary", [para("a", "one"), para("b", "two")], expanded: false)])
        guard case let .details(read) = editor.document.blocks[0] else { return XCTFail("not a details") }
        XCTAssertEqual(read.expanded, false)
        XCTAssertEqual(read.children.count, 2, "the hidden body survives a set-and-read")
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
        XCTAssertEqual(read.title.first?.text, "Summary")
    }

    func test_anExpandedDetailsRoundTripsItsTitleAndChildren() {
        load([details("d", title: "Summary", [para("a", "one")])])
        guard case let .details(read) = editor.document.blocks[0] else { return XCTFail("not a details") }
        XCTAssertEqual(read.expanded, true)
        XCTAssertEqual(read.title.first?.text, "Summary")
        XCTAssertEqual(read.children.count, 1)
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
    }

    func test_aDetailsInsideAQuote() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        XCTAssertEqual(roles(), ["detailsTitle@2", "p@2", "blockQuoteAuthor@1"])
    }

    func test_aQuoteInsideADetails() {
        load([details("d", title: "T", [.blockQuote(BlockQuote(id: BlockID("q"),
                                                               children: [para("a", "one")]))])])
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@2", "blockQuoteAuthor@2"])
    }

    func test_aDetailsInsideADetails() {
        load([details("outer", title: "O", [details("inner", title: "I", [para("a", "one")])])])
        XCTAssertEqual(roles(), ["detailsTitle@1", "detailsTitle@2", "p@2"])
        XCTAssertEqual(strings(), ["O", "I", "one"])
    }

    /// §3.4: a details indents nothing, so a paragraph inside `quote > details` sits at ONE indent.
    /// `quoteIndent × ancestry.count` would give two.
    func test_aParagraphInAQuotedDetailsSitsAtOneIndent() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        // Roles: detailsTitle@2, a@2, q author@1 — the body is role 1.
        let style = editor.engine.attributedBlocks[1].attribute(.paragraphStyle, at: 0, effectiveRange: nil)
        XCTAssertEqual((style as? NSParagraphStyle)?.headIndent ?? -1,
                       editor.bridge.styleSheet.quoteIndent, accuracy: 0.5,
                       "ONE quoteIndent: the quote's. The details contributes nothing.")
    }

    // MARK: the review wave

    /// The quote mapper is chosen on `depth > 0`, and depth counts CONTAINERS — so a paragraph
    /// inside a TOP-LEVEL details rendered at the quote's 15pt although no quote enclosed it, while
    /// the title (always built with the plain mapper) stayed 17pt. Legacy's `DetailsBox` builds its
    /// children with the mapper it was handed, so both editors must agree: outside a quote a details
    /// is body-sized throughout, inside one it is quote-sized throughout.
    func test_aTopLevelDetailsRendersAtBodySizeThroughout() {
        load([details("d", title: "T", [para("a", "one")])])
        XCTAssertEqual(fontSize(0), 17.0, accuracy: 0.5, "the title")
        XCTAssertEqual(fontSize(1), 17.0, accuracy: 0.5, "and its body")
    }

    func test_aQuotedDetailsRendersAtQuoteSizeThroughout() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        XCTAssertEqual(fontSize(0), 15.0, accuracy: 0.5, "the title takes the quote's size too")
        XCTAssertEqual(fontSize(1), 15.0, accuracy: 0.5)
    }

    private func fontSize(_ index: Int) -> CGFloat {
        (editor.engine.attributedBlocks[index].attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize ?? -1
    }
}
