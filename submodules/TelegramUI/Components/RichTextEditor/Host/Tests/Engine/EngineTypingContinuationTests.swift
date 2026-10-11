import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// What formatting continues onto text typed NEXT, and what must not.
final class EngineTypingContinuationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha")]))])
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

    private func placeCaretAtEnd() {
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
    }

    private func runs() -> [TextRun] {
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else { return [] }
        return paragraph.runs
    }

    /// A link must NOT swallow what is typed after it. Reported against the running app, where it
    /// extended even across a space — so a whole following sentence became part of the URL's run.
    func test_typingAfterALinkDoesNotExtendIt() {
        selectAll()
        editor.setLink("https://telegram.org")
        placeCaretAtEnd()
        editor.engine.insertText(" and more")

        let linked = runs().filter { $0.attributes.link != nil }.map(\.text).joined()
        XCTAssertEqual(linked, "alpha",
                       "text typed after a link was absorbed into it — the link now reads as \\(linked)")
    }

    /// THE CONTROL. Ordinary character formatting SHOULD continue, so the test above is pinning a
    /// property specific to links rather than a blanket "nothing continues".
    func test_control_typingAfterBoldTextStaysBold() {
        selectAll()
        editor.toggleBold()
        placeCaretAtEnd()
        editor.engine.insertText("X")

        XCTAssertTrue(runs().last?.attributes.bold == true,
                      "bold stopped continuing onto typed text, which is a regression, not the fix")
    }

    /// THE OTHER HALF OF THE RULE, and the reason the fix keys on the FOLLOWING character rather
    /// than simply never extending: typing in the middle of a link must stay part of it, or editing
    /// a URL would silently tear it in three.
    func test_typingInsideALinkDoesExtendIt() {
        selectAll()
        editor.setLink("https://telegram.org")
        let middle = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 2)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: middle, to: middle)
        editor.engine.insertText("ZZ")

        let linked = runs().filter { $0.attributes.link != nil }.map(\.text).joined()
        XCTAssertEqual(linked, "alZZpha",
                       "typing inside a link dropped out of it, splitting the URL's run")
    }

    /// A link JOINS a word typed against it — the reported rule. Only punctuation and whitespace end
    /// it, so "alpha" + "s" is one link and "alpha" + ", x" is not.
    func test_typingAWordCharacterAfterALinkJoinsIt() {
        selectAll()
        editor.setLink("https://telegram.org")
        placeCaretAtEnd()
        editor.engine.insertText("s")

        let linked = runs().filter { $0.attributes.link != nil }.map(\.text).joined()
        XCTAssertEqual(linked, "alphas", "a word character typed against a link should join it")
    }

    func test_typingPunctuationAfterALinkDoesNotJoinIt() {
        selectAll()
        editor.setLink("https://telegram.org")
        placeCaretAtEnd()
        editor.engine.insertText(".")

        let linked = runs().filter { $0.attributes.link != nil }.map(\.text).joined()
        XCTAssertEqual(linked, "alpha", "punctuation should end a link, not extend it")
    }

    /// Real typing arrives ONE CHARACTER AT A TIME. The existing test inserts " and more" in a single
    /// call, which is not what a keyboard does — and the reported bug survives that test, so this
    /// reproduces the actual sequence.
    func test_typingASpaceThenAWordAfterALinkJoinsNeither() {
        selectAll()
        editor.setLink("https://telegram.org")
        placeCaretAtEnd()
        for character in " and" { editor.engine.insertText(String(character)) }

        let linked = runs().filter { $0.attributes.link != nil }.map(\.text).joined()
        XCTAssertEqual(linked, "alpha",
                       "typing a space then a word after a link pulled them in — linked text is \(linked)")
    }

    /// Typing inside a spoiler must stay inside it. It was splitting the run in three, because the
    /// engine's typing attributes carry only the font, foreground and its own four traits — every
    /// host marker is outside that set.
    func test_typingInsideASpoilerStaysSpoilered() {
        selectAll()
        editor.toggleSpoiler()
        let middle = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 2)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: middle, to: middle)
        editor.engine.insertText("XY")

        XCTAssertTrue(runs().allSatisfy { $0.attributes.spoiler },
                      "typing inside a spoiler broke it into spoilered and unspoilered runs")
    }

    /// The same gap silently affected inline code: its FONT continued (fonts are in the engine's
    /// allowed typing attributes) so it still looked like code, while the model quietly lost it.
    func test_typingInsideInlineCodeStaysCode() {
        selectAll()
        editor.toggleInlineCode()
        let middle = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 2)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: middle, to: middle)
        editor.engine.insertText("XY")

        XCTAssertTrue(runs().allSatisfy { $0.attributes.inlineCode },
                      "typed text looked like code but was not code in the model")
    }

    /// Deleting everything must clear the pending formatting. Otherwise the composer looks empty but
    /// is still armed, and the next thing typed silently comes out bold — or monospaced.
    func test_deletingAllContentResetsTypingFormatting() {
        selectAll()
        editor.toggleBold()
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.text, "", "the document was not emptied")

        editor.engine.insertText("plain")

        XCTAssertFalse(runs().contains { $0.attributes.bold },
                       "typing after clearing the composer was still bold")
    }
}
