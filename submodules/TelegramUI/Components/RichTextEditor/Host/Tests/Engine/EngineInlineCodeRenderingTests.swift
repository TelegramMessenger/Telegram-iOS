import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// What a user actually sees, asserted on the text the CANVAS renders from (`attributedBlocks`) —
/// not on a helper's return value.
///
/// The predecessors of this file tested two style-contributor objects directly. All of them passed
/// while inline code rendered as plain text in the app, because they exercised the contract at the
/// one place it worked and never the path it was invoked from. These drive the real toggle.
final class EngineInlineCodeRenderingTests: XCTestCase {
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

    /// The font the canvas will actually draw with, read from the engine's own block text.
    private func renderedFont() -> UIFont? {
        editor.engine.attributedBlocks.first?
            .attributes(at: 0, effectiveRange: nil)[.font] as? UIFont
    }

    /// Measured, not asked: `traitMonoSpace` is not a reliable witness on this platform.
    private func isMonospaced(_ font: UIFont) -> Bool {
        let i = ("i" as NSString).size(withAttributes: [.font: font]).width
        let w = ("W" as NSString).size(withAttributes: [.font: font]).width
        return abs(i - w) < 0.01
    }

    func test_control_bodyTextIsNotMonospacedToBeginWith() {
        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertFalse(isMonospaced(font), "the witness reports true for the body font")
    }

    /// Your #3: toggling inline code must change what is DRAWN, not just what is stored.
    func test_togglingInlineCodeRendersMonospaced() {
        selectAll()
        editor.toggleInlineCode()
        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertTrue(isMonospaced(font), "inline code did not become monospaced")
    }

    /// Your #2: applying code to bold text must keep BOTH.
    func test_inlineCodeOverBoldTextIsBoldAndMonospaced() {
        selectAll(); editor.toggleBold()
        selectAll(); editor.toggleInlineCode()

        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "bold was lost")
        XCTAssertTrue(isMonospaced(font), "monospacing was lost")
    }

    /// And the order that used to break it: bolding an existing code run recomputes the font from the
    /// base face, so the monospacing survives only because the base font is monospaced.
    func test_boldingAnExistingCodeRunKeepsItMonospaced() {
        selectAll(); editor.toggleInlineCode()
        selectAll(); editor.toggleBold()

        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "bold was not applied")
        XCTAssertTrue(isMonospaced(font),
                      "bolding a code run recomputed the font from the BODY face — the host's base "
                      + "font is not being honoured")
    }

    /// DRAFT RESTORE. A document arriving from the model — a saved draft, a re-opened chat — must
    /// render the same as one built by toggling.
    ///
    /// It did not. The SHARED mapper writes `monospacedSystemFont(weight: .regular)` for a code run,
    /// because on the legacy path the user's bold travels separately in `.rtBold`. The engine has no
    /// such marker (it reads `IDInlineTextBold`) and recovers bold from the rendered font, so a bold
    /// code run came back plain — and the next read-back would then derive `bold: false` and lose it
    /// from the MODEL as well. That is data loss, not just a rendering fault.
    func test_aBoldInlineCodeRunFromTheModelRendersBoldAndMonospaced() {
        var attributes = CharacterAttributes()
        attributes.bold = true
        attributes.inlineCode = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha", attributes: attributes)]))])

        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold),
                      "bold was lost bringing a code run in from the model")
        XCTAssertTrue(isMonospaced(font), "monospacing was lost bringing a code run in from the model")
    }

    /// And it must still behave: bolding is derived from the base face, which a model round-trip
    /// must therefore also carry.
    func test_aCodeRunFromTheModelStaysMonospacedWhenBolded() {
        var attributes = CharacterAttributes()
        attributes.inlineCode = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha", attributes: attributes)]))])

        selectAll(); editor.toggleBold()

        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertTrue(isMonospaced(font),
                      "a restored code run lost its base face, so bolding it fell back to the body font")
    }

    func test_togglingInlineCodeOffRestoresAProportionalFont() {
        selectAll(); editor.toggleInlineCode()
        selectAll(); editor.toggleInlineCode()
        guard let font = renderedFont() else { return XCTFail("no font") }
        XCTAssertFalse(isMonospaced(font), "the monospace face survived turning code off")
    }
}
