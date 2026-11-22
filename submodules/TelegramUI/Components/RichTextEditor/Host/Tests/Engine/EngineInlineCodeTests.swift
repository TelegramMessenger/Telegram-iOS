import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// R9-inline Task 4 — inline code.
///
/// Same two halves as links: storage through the engine's host-attribute path, presentation through
/// a style contributor. The key is `.rtInlineCode`, which the SHARED `AttributedStringMapper`
/// already round-trips to `CharacterAttributes.inlineCode` — chosen deliberately after the link work
/// showed what a private key costs (the two backends stop agreeing on the same document).
final class EngineInlineCodeTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha beta")]))])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func selectAll() {
        let whole = editor.engine.textRange(from: editor.engine.beginningOfDocument,
                                            to: editor.engine.endOfDocument)!
        editor.engine.selectedTextRange = whole
    }

    private func runs() -> [TextRun] {
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else { return [] }
        return paragraph.runs
    }

    func test_togglingInlineCodeReachesTheDocument() {
        selectAll()
        editor.toggleInlineCode()
        XCTAssertTrue(runs().contains { $0.attributes.inlineCode },
                      "inline code did not survive the round-trip into Document")
    }

    func test_togglingInlineCodeOffClearsIt() {
        selectAll()
        editor.toggleInlineCode()
        selectAll()
        editor.toggleInlineCode()
        XCTAssertFalse(runs().contains { $0.attributes.inlineCode },
                       "toggling twice must leave no inline code behind")
    }

    /// Bold survives into the MODEL when a run becomes inline code.
    ///
    /// NOT a test of the font derivation, though it was written as one. Mutation proved it vacuous:
    /// dropping the incoming traits entirely leaves this green, because the contributor's font never
    /// reaches the document at all — the model reads the RESOLVER's font, and the contributor only
    /// decorates on the way to being rendered. What actually guards the derivation is
    /// `EngineInlineCodeStyleTests.test_boldSurvivesTheMonospaceDerivation`.
    ///
    /// It is kept because the property it does test is real and worth pinning: on the engine path
    /// the mapper reads bold off the rendered font's symbolic traits (the engine writes
    /// `IDInlineTextBold`, the mapper reads `RTBold` — different strings), so anything that flattened
    /// that font would take the user's bold out of the sent message.
    func test_boldInsideInlineCodeKeepsBoldInTheModel() {
        selectAll()
        editor.toggleBold()
        selectAll()
        editor.toggleInlineCode()

        let coded = runs().filter { $0.attributes.inlineCode }
        XCTAssertFalse(coded.isEmpty, "no inline-code run to check")
        XCTAssertTrue(coded.allSatisfy { $0.attributes.bold },
                      "bold was lost when the run became inline code")
    }
}
