import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream
@testable import RichTextEngineEditor

/// The engine's trait state is its OWN four marker attributes — `traitsInAttributes:` reads
/// `IDInlineTextBold` / `Italic` / `Underline` / `Strikethrough` and nothing else. It does not derive
/// state from the rendered font; `baseFontForAttributes:` picks the base FACE, which is a different
/// question and is what the bridge's older comment was describing.
///
/// The shared mapper emits the DERIVED form — a bold face, `.rtBold`, `.underlineStyle`,
/// `.strikethroughStyle` — and none of those markers. So before this, every trait reported `off` for
/// text that arrived through a document set: a reopened draft, a paste, the composer seeding content.
/// Measured consequences, in order of severity: the model and the render diverged (un-bolding left
/// `bold: true` in the document while the screen showed regular, so the message would SEND bold);
/// un-bolding took two presses; and the toolbar showed Bold unlit over visibly bold text.
@available(iOS 18.4, *)
final class EngineInlineTraitMarkerTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func load(_ attributes: CharacterAttributes, plainTail: Bool = false) {
        var runs = [TextRun(text: "aa", attributes: attributes)]
        if plainTail { runs.append(TextRun(text: "bb")) }
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: runs))])
        window.layoutIfNeeded()
    }

    private func styled(_ set: (inout CharacterAttributes) -> Void) -> CharacterAttributes {
        var attributes = CharacterAttributes()
        set(&attributes)
        return attributes
    }

    private func selectStyledRun() { editor.engineSelectedRange = NSRange(location: 0, length: 2) }

    // MARK: The four traits, over LOADED text

    func test_loadedBoldReportsOn() {
        load(styled { $0.bold = true })
        selectStyledRun()
        XCTAssertEqual(editor.currentInlineTraits().bold, .on)
    }

    func test_loadedItalicReportsOn() {
        load(styled { $0.italic = true })
        selectStyledRun()
        XCTAssertEqual(editor.currentInlineTraits().italic, .on)
    }

    func test_loadedUnderlineReportsOn() {
        load(styled { $0.underline = true })
        selectStyledRun()
        XCTAssertEqual(editor.currentInlineTraits().underline, .on)
    }

    func test_loadedStrikethroughReportsOn() {
        load(styled { $0.strikethrough = true })
        selectStyledRun()
        XCTAssertEqual(editor.currentInlineTraits().strikethrough, .on)
    }

    func test_plainTextReportsOff() {
        load(CharacterAttributes())
        selectStyledRun()
        let traits = editor.currentInlineTraits()
        XCTAssertEqual(traits.bold, .off)
        XCTAssertEqual(traits.italic, .off)
        XCTAssertEqual(traits.underline, .off)
        XCTAssertEqual(traits.strikethrough, .off)
    }

    /// A selection genuinely spanning both is `mixed` — the engine's third state, which is the whole
    /// reason `InlineTraitState` is not a `Bool`.
    func test_aSelectionSpanningBoldAndPlainIsMixed() {
        load(styled { $0.bold = true }, plainTail: true)
        editor.engineSelectedRange = NSRange(location: 0, length: 4)
        XCTAssertEqual(editor.currentInlineTraits().bold, .mixed)
    }

    // MARK: The consequences

    /// ONE press un-bolds loaded bold text. It used to take two: the first wrote the marker and
    /// recomputed the identical face, so nothing moved on screen.
    func test_onePressUnboldsLoadedBoldText() {
        load(styled { $0.bold = true })
        selectStyledRun()
        editor.toggleBold()
        XCTAssertEqual(editor.currentInlineTraits().bold, .off)
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), false,
                       "the rendered face is no longer bold")
    }

    /// THE SEVERE ONE. The model and the render must agree after that press. They did not: the face
    /// went regular while the document still said `bold: true`, so the message would send bold while
    /// the editor showed it plain.
    func test_theModelAgreesWithTheRenderAfterUnbolding() {
        load(styled { $0.bold = true })
        selectStyledRun()
        editor.toggleBold()
        let runs = editor.document.blocks[0].asParagraph?.runs ?? []
        XCTAssertEqual(runs.map(\.attributes.bold), [false],
                       "the document must not still claim bold after the text was un-bolded")
    }

    // MARK: What must NOT change

    /// Markers are ADDED; nothing rendered moves. `.font`, `.underlineStyle` and `.strikethroughStyle`
    /// already equal what the engine derives from the markers, so they are left exactly as the mapper
    /// wrote them.
    func test_theRenderedFaceIsUnchanged() {
        load(styled { $0.bold = true })
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_theEngineMarkersAreStamped() {
        load(styled { $0.bold = true; $0.italic = true; $0.underline = true; $0.strikethrough = true })
        let block = editor.engine.attributedBlocks[0]
        let keys = block.attributes(at: 0, effectiveRange: nil).keys
        XCTAssertTrue(keys.contains(.IDInlineTextBoldAttributeName))
        XCTAssertTrue(keys.contains(.IDInlineTextItalicAttributeName))
        XCTAssertTrue(keys.contains(.IDInlineTextUnderlineAttributeName))
        XCTAssertTrue(keys.contains(.IDInlineTextStrikethroughAttributeName))
        XCTAssertTrue(keys.contains(.IDInlineTextBaseFontAttributeName))
    }

    /// The base face the engine derives from must have the traits STRIPPED, or a bold run derives its
    /// base from the bold face and can never toggle back — the same rule the code-block stamp states.
    func test_theStampedBaseFaceHasTheTraitsStripped() {
        load(styled { $0.bold = true; $0.italic = true })
        let base = editor.engine.attributedBlocks[0]
            .attribute(.IDInlineTextBaseFontAttributeName, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(base?.fontDescriptor.symbolicTraits.contains(.traitBold), false)
        XCTAssertEqual(base?.fontDescriptor.symbolicTraits.contains(.traitItalic), false)
    }

    func test_loadedTraitsLeaveNoPresentationDrift() {
        load(styled { $0.bold = true; $0.underline = true })
        XCTAssertEqual(editor.presentationDrift(atBlock: 0), [])
    }

    /// STYLE-bold is not USER-bold. A pull quote's author line and a code block's language line are
    /// rendered bold by the style, and the system "Bold Text" setting forces the trait onto
    /// substituted scripts — which is the whole reason `.rtBold` exists. Deriving the engine's marker
    /// from the rendered face stamped one the re-render could not reproduce, and
    /// `verifyPresentationIsDerived` trapped on every pull quote with `RTBold` as the drifting key.
    func test_aStyleBoldAuthorLineIsNotUserBoldAndDoesNotDrift() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quoted")],
                                 author: [TextRun(text: "someone")])),
        ])
        window.layoutIfNeeded()
        for index in editor.currentRoles.indices {
            XCTAssertEqual(editor.presentationDrift(atBlock: index), [], "role \(index) drifted")
        }
        // The author line is the LAST role of the pull quote's span.
        let author = editor.currentRoles.count - 1
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: author), length: 1)
        XCTAssertEqual(editor.currentInlineTraits().bold, .off,
                       "the author line is bold by STYLE, so the user's bold is off there")
    }
}
