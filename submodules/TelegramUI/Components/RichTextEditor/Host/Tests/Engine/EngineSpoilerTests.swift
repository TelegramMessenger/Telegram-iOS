import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-inline Task 6 — spoilers.
///
/// The one inline feature whose styling must NOT be written into the document. A spoiler hides its
/// text, and reveals it while the selection is inside — so the styling both must not be sent and must
/// change without an edit. Writing it into the document would send an explicit foreground colour AND
/// put an undo entry on every caret move.
///
/// It therefore rides the engine's display-decoration channel, and these tests assert on
/// `id_renderedTextForBlockAtIndex:` — what the canvas actually draws — and separately on
/// `attributedBlocks`, the model.
final class EngineSpoilerTests: XCTestCase {
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
        window.layoutIfNeeded()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func select(_ range: NSRange) {
        let start = editor.engine.position(from: editor.engine.beginningOfDocument,
                                           offset: range.location)!
        let end = editor.engine.position(from: start, offset: range.length)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: end)
    }

    private func renderedForeground(at index: Int) -> UIColor? {
        window.layoutIfNeeded()
        return editor.engine.id_renderedTextForBlock(at: 0)?
            .attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
    }

    private func modelRuns() -> [TextRun] {
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else { return [] }
        return paragraph.runs
    }

    func test_togglingSpoilerReachesTheDocument() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        XCTAssertTrue(modelRuns().contains { $0.attributes.spoiler },
                      "the spoiler marker did not survive into Document")
    }

    /// THE POINT OF THE WHOLE CHANNEL. The hide must not be in the model, or it is sent as an
    /// explicit foreground colour on the recipient's message.
    func test_theHideDoesNotReachTheModel() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 9, length: 0))   // caret away from the spoiler, so it is hidden
        window.layoutIfNeeded()

        for run in modelRuns() where run.attributes.spoiler {
            XCTAssertNil(run.attributes.foreground,
                         "the display-only hide was written into the model and would be sent")
        }
    }

    func test_aSpoilerRunRendersHiddenWhenTheSelectionIsElsewhere() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 9, length: 0))

        XCTAssertEqual(renderedForeground(at: 0), UIColor.clear,
                       "a spoiler away from the caret should be hidden")
    }

    /// THE CONTROL. Text outside the spoiler must be unaffected — otherwise the test above could pass
    /// on a decorator that hid everything.
    func test_control_textOutsideTheSpoilerIsNotHidden() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 9, length: 0))

        XCTAssertNotEqual(renderedForeground(at: 8), UIColor.clear,
                          "the decorator hid text that is not a spoiler")
    }

    /// Revealing while editing: you must be able to read what you are typing.
    func test_aSpoilerRevealsWhileTheSelectionIsInsideIt() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 2, length: 0))

        XCTAssertNotEqual(renderedForeground(at: 0), UIColor.clear,
                          "the spoiler stayed hidden with the caret inside it, so its text cannot be read")
    }

    private func dustViews() -> [SpoilerDustView] {
        window.layoutIfNeeded()
        return editor.engine.subviews.compactMap { $0 as? SpoilerDustView }
    }

    /// The dust is a real view over the run, not a decoration — it has to be, because the composer is
    /// TRANSPARENT over the chat wallpaper, so nothing can be hidden by painting over it.
    func test_aHiddenSpoilerGetsADustViewOverIt() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 9, length: 0))

        let dust = dustViews()
        XCTAssertEqual(dust.count, 1, "a hidden spoiler run should have exactly one dust cloud")
        XCTAssertGreaterThan(dust.first?.frame.width ?? 0, 0, "the dust has no area, so it draws nothing")
        XCTAssertGreaterThan(dust.first?.frame.height ?? 0, 0)
    }

    /// THE CONTROL. Without a spoiler there must be no dust — otherwise the test above could be
    /// counting something that is always present.
    func test_control_textWithNoSpoilerHasNoDust() {
        select(NSRange(location: 0, length: 5))
        XCTAssertTrue(dustViews().isEmpty, "dust appeared over text that is not a spoiler")
    }

    /// Dust and the text hide share one reveal rule, so they can never disagree — dust over readable
    /// text, or an invisible run with no dust.
    func test_revealingASpoilerRemovesItsDust() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 9, length: 0))
        XCTAssertEqual(dustViews().count, 1, "precondition: hidden and dusted")

        select(NSRange(location: 2, length: 0))
        window.layoutIfNeeded()

        // The dust dissolves asynchronously; what must be true immediately is that it is no longer
        // tracked as live, so a later layout cannot resurrect it.
        XCTAssertTrue(editor.spoilerDustViews.isEmpty,
                      "a revealed spoiler is still holding its dust")
    }

    /// Dust must cover an EMOJI inside a spoiler, not just the text around it.
    ///
    /// The particle emitter is confined to word rects so the cloud follows ink rather than filling a
    /// box — and `U+FFFC` is not a word, so a spoilered emoji was hidden with a bare gap where the
    /// dust should have been. Hiding something and then drawing nothing over it is as revealing as
    /// not hiding it.
    func test_dustCoversAnEmojiInsideTheSpoiler() {
        var emoji = CharacterAttributes()
        emoji.emoji = EmojiRef(id: "5202", instanceID: "i1")
        emoji.spoiler = true
        var spoiler = CharacterAttributes()
        spoiler.spoiler = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "ab ", attributes: spoiler),
            TextRun(text: "\u{FFFC}", attributes: emoji),
        ]))])
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        window.layoutIfNeeded()

        let emojiFrame = editor.engine.id_attachmentFrame(forCanonicalOffset: 3)
        XCTAssertFalse(emojiFrame.isNull, "precondition: the emoji has a frame")

        let inkRects = editor.spoilerWordRects(in: NSRange(location: 0, length: 4))
        XCTAssertTrue(inkRects.contains { $0.intersects(emojiFrame) },
                      "no particle area over the emoji — the dust leaves a bare gap there")
    }

    func test_togglingSpoilerOffClearsIt() {
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        select(NSRange(location: 0, length: 5))
        editor.toggleSpoiler()
        XCTAssertFalse(modelRuns().contains { $0.attributes.spoiler })
    }

    /// The dust rides the scroll too — same defect, same reason as the hosted emoji: its rects come
    /// from `id_rects`, which answers in the engine's CONTENT space, while the view was parented to
    /// the editor outside the scroll view.
    func test_theDustRidesTheScrollInsteadOfStayingPinnedToTheField() {
        var spoiler = CharacterAttributes()
        spoiler.spoiler = true
        // The spoiler sits part-way down on purpose: scrolled OFF the top its rects come from text
        // the engine has not laid out, and the test would be measuring that instead of the parenting.
        var blocks: [Block] = []
        for index in 0..<5 {
            blocks.append(.paragraph(ParagraphBlock(id: BlockID("above\(index)"),
                                                    runs: [TextRun(text: "line \(index)")])))
        }
        blocks.append(.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "secret", attributes: spoiler),
        ])))
        for index in 1...40 {
            blocks.append(.paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                                    runs: [TextRun(text: "line \(index)")])))
        }
        editor.document = Document(blocks: blocks)
        window.layoutIfNeeded()

        guard let dust = dustViews().first else { return XCTFail("no dust view") }
        let engine = editor.engine
        XCTAssertGreaterThan(engine.contentSize.height, engine.bounds.height + 40.0,
                             "precondition: the field must actually be scrollable")

        // Start from a known offset: setting the document parks the caret at its END, so the field
        // is already scrolled and "before" would otherwise depend on where that left it.
        engine.contentOffset = .zero
        window.layoutIfNeeded()
        let before = editor.convert(dust.bounds, from: dust)
        XCTAssertGreaterThan(before.minY, 40.0,
                             "precondition: the dust must stay on screen across the scroll")
        engine.contentOffset = CGPoint(x: 0.0, y: 40.0)
        window.layoutIfNeeded()
        let after = editor.convert(dust.bounds, from: dust)

        XCTAssertEqual(before.minY - after.minY, 40.0, accuracy: 0.5,
                       "the dust must move up with the text it hides")
    }
}
