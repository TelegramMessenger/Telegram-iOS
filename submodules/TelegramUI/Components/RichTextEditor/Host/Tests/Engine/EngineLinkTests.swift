import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// R9-inline Task 3 — links.
///
/// A link is an inline character attribute with a VALUE, not one of the engine's four inline traits
/// (`IDInlineTextTraits` is bold/italic/underline/strikethrough only). So it cannot go through
/// `toggleInlineTextTrait:`; it takes the attribute path, and its PRESENTATION goes through the
/// style-contributor seam added upstream in ab4cdce — because the resolver owns the foreground and
/// underline channels outright and would otherwise rewrite a link's styling out from under us on the
/// next trait toggle.
final class EngineLinkTests: XCTestCase {
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

    func test_settingALinkIsReadableBack() {
        selectAll()
        editor.setLink("https://telegram.org")
        XCTAssertEqual(editor.currentLink(), "https://telegram.org",
                       "a link set over the selection must read back from that selection")
    }

    func test_removingALinkClearsIt() {
        selectAll()
        editor.setLink("https://telegram.org")
        selectAll()
        editor.removeLink()
        XCTAssertNil(editor.currentLink(), "removeLink must clear the URL, not blank it")
    }

    /// The link has to reach Telegram's own model, not just the engine's attributed string —
    /// otherwise it is invisible to everything downstream (send, draft, markdown).
    func test_aLinkReachesTheDocument() {
        selectAll()
        editor.setLink("https://telegram.org")
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.link == "https://telegram.org" },
                      "the link did not survive the round-trip into Document")
    }

    /// The derive-don't-replace invariant, at the level a user would notice it. Bold and a link are
    /// carried by different mechanisms — a trait the engine owns, and a host attribute it does not —
    /// so a run wearing both is exactly where a wholesale attribute rebuild would drop one.
    func test_aLinkInsideBoldKeepsBoth() {
        selectAll()
        editor.toggleBold()
        selectAll()
        editor.setLink("https://telegram.org")

        XCTAssertEqual(editor.currentInlineTraits().bold, .on, "bolding was lost when the link landed")
        XCTAssertEqual(editor.currentLink(), "https://telegram.org", "the link was lost")
    }

    /// A link's colour and underline are DISPLAY, derived by the style contributor, and must not be
    /// written into the model — the legacy editor keeps the same property so the model stays
    /// markdown-clean. The contributor reproduces it by construction, since it decorates attributes
    /// on their way to being rendered and never reaches the document.
    func test_theModelCarriesTheURLAndNotItsDisplayStyling() {
        selectAll()
        editor.setLink("https://telegram.org")
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        let linked = paragraph.runs.filter { $0.attributes.link != nil }
        XCTAssertFalse(linked.isEmpty, "no linked run to check")
        for run in linked {
            XCTAssertFalse(run.attributes.underline,
                           "a link's underline is display-derived and must not enter the model")
        }
    }
}
