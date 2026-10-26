import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-inline Task 5 — custom emoji, hosted the way the legacy canvas hosts them.
///
/// NOT through `NSTextAttachmentViewProvider`. This is a custom text view that does its own drawing:
/// the attachment reserves the box, and the HOST positions a provided view over the glyph rect,
/// pooling by `EmojiRef.instanceID`. That is what `DocumentCanvasView+Emoji.swift` does, and it is the
/// same machinery the spoiler dust already uses.
///
/// The design this replaces went through TextKit's view providers, on the strength of the engine
/// having an attachment-view lifecycle. That lifecycle forwards to a canvas host implementing nothing,
/// and the provider path could not be made to fire at all — including in a stock `UITextView`. Both
/// were dead ends reached by assuming the mechanism instead of looking at what legacy does.
final class EngineCustomEmojiTests: XCTestCase {

    /// Stands in for the chat's `EmojiTextAttachmentView`.
    final class StubEmojiView: UIView, RichTextEmojiView {
        var dynamicColor: UIColor?
        let emojiID: String
        init(emojiID: String) { self.emojiID = emojiID; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
    }

    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    private var vendedIDs: [String] = []

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.registerEmojiViewProvider { [weak self] id, _ in
            self?.vendedIDs.append(id)
            return StubEmojiView(emojiID: id)
        }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; vendedIDs = []; super.tearDown() }

    private func documentWithEmoji(id: String, instanceID: String) -> Document {
        var emojiAttributes = CharacterAttributes()
        emojiAttributes.emoji = EmojiRef(id: id, instanceID: instanceID)
        return Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "hi "),
            TextRun(text: "\u{FFFC}", attributes: emojiAttributes),
            TextRun(text: " there"),
        ]))])
    }

    private func hostedEmojiViews() -> [StubEmojiView] {
        window.layoutIfNeeded()
        return editor.engine.subviews.compactMap { $0 as? StubEmojiView }
    }

    func test_anEmojiInTheDocumentIsHostedAsAView() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")

        let views = hostedEmojiViews()
        XCTAssertEqual(views.count, 1, "the emoji was not hosted — it renders as a blank gap")
        XCTAssertEqual(views.first?.emojiID, "5202", "the wrong emoji id reached the provider")
    }

    /// It must sit ON the glyph, not at the origin — the whole point of asking the engine for geometry.
    func test_theHostedViewIsPositionedOverItsGlyph() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        guard let view = hostedEmojiViews().first else { return XCTFail("not hosted") }

        XCTAssertGreaterThan(view.frame.width, 0, "zero-width emoji view")
        XCTAssertGreaterThan(view.frame.height, 0)
        XCTAssertGreaterThan(view.frame.minX, 0,
                             "the emoji sits at x=0, so it was never placed over its glyph")
    }

    /// Reported as "displayed non-rectangular": the view was placed from a SELECTION rect, which is
    /// the line's height, while the emoji's own box is a square on the baseline.
    func test_theHostedViewIsSquare() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        guard let view = hostedEmojiViews().first else { return XCTFail("not hosted") }

        XCTAssertEqual(view.frame.width, view.frame.height, accuracy: 0.5,
                       "the emoji view is \(view.frame.size) — not square, so the glyph is stretched")
    }

    /// THE CONTROL. Plain text hosts nothing, so the tests above cannot be passing on a view that is
    /// always created.
    func test_control_plainTextHostsNoEmojiViews() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "no emoji here")]))])
        XCTAssertTrue(hostedEmojiViews().isEmpty)
    }

    /// Pooling: the same emoji across a re-set must not vend a second view, or every keystroke would
    /// rebuild every emoji in the composer.
    func test_theSameEmojiIsReusedRatherThanRecreated() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        _ = hostedEmojiViews()
        let first = vendedIDs.count

        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        _ = hostedEmojiViews()

        XCTAssertEqual(vendedIDs.count, first, "the emoji view was recreated instead of reused")
    }

    func test_removingTheEmojiTearsDownItsView() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        XCTAssertEqual(hostedEmojiViews().count, 1, "precondition")

        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "gone")]))])

        XCTAssertTrue(hostedEmojiViews().isEmpty, "the emoji view outlived its emoji")
    }

    /// THE GAP THE SPOILER WORK LEFT OPEN, closeable only now that emoji views exist.
    ///
    /// A spoiler hides text with a foreground colour, which does nothing to a hosted VIEW — the emoji
    /// would sit fully visible behind the dust, which is the one thing a spoiler must never do. Legacy
    /// has this bug today: `DocumentCanvasView+Emoji.swift` contains no spoiler handling at all.
    func test_anEmojiInsideAHiddenSpoilerIsHidden() {
        var attributes = CharacterAttributes()
        attributes.emoji = EmojiRef(id: "5202", instanceID: "i1")
        attributes.spoiler = true
        var plainSpoiler = CharacterAttributes()
        plainSpoiler.spoiler = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "hi ", attributes: plainSpoiler),
            TextRun(text: "\u{FFFC}", attributes: attributes),
            TextRun(text: " there"),
        ]))])
        // Caret well away from the spoiler, so it is hidden.
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)

        guard let view = hostedEmojiViews().first else { return XCTFail("emoji not hosted at all") }
        XCTAssertTrue(view.isHidden,
                      "the emoji is visible inside a hidden spoiler — it leaks the hidden content")
    }

    /// And it must come back with the spoiler, or revealing shows a gap where the emoji was.
    func test_anEmojiInARevealedSpoilerIsVisible() {
        var attributes = CharacterAttributes()
        attributes.emoji = EmojiRef(id: "5202", instanceID: "i1")
        attributes.spoiler = true
        var plainSpoiler = CharacterAttributes()
        plainSpoiler.spoiler = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "hi ", attributes: plainSpoiler),
            TextRun(text: "\u{FFFC}", attributes: attributes),
            TextRun(text: " there"),
        ]))])
        // Caret INSIDE the spoiler run reveals it.
        let inside = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 2)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: inside, to: inside)

        guard let view = hostedEmojiViews().first else { return XCTFail("emoji not hosted at all") }
        XCTAssertFalse(view.isHidden, "the emoji stayed hidden in a revealed spoiler")
    }

    /// Template emoji are tinted to the text colour; the editor pushes it every pass.
    func test_theHostedViewIsTintedWithTheTextColour() {
        editor.document = documentWithEmoji(id: "5202", instanceID: "i1")
        XCTAssertEqual(hostedEmojiViews().first?.dynamicColor, editor.theme.primaryText)
    }

    /// A hosted view must ride the field's scroll.
    ///
    /// The geometry the host places these from — `id_attachmentFrame`, `id_rects` — is in the
    /// engine's CONTENT space, but the view was parented to the EDITOR, outside the scroll view. At
    /// rest the two spaces coincide, so this was invisible until the field had enough text to scroll,
    /// at which point every emoji stayed pinned to the screen while its text moved out from under it.
    /// The container decorations had exactly this bug and were fixed by parenting into the engine;
    /// these are the remaining two.
    func test_aHostedEmojiRidesTheScrollInsteadOfStayingPinnedToTheField() {
        var emojiAttributes = CharacterAttributes()
        emojiAttributes.emoji = EmojiRef(id: "e1", instanceID: "i1")
        // Part-way down, so the scroll does not push it off the top and measure unlaid-out geometry.
        var blocks: [Block] = (0..<5).map {
            .paragraph(ParagraphBlock(id: BlockID("above\($0)"), runs: [TextRun(text: "line \($0)")]))
        }
        blocks.append(.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "hi "),
            TextRun(text: "\u{FFFC}", attributes: emojiAttributes),
        ])))
        // Enough text below it that the field genuinely scrolls.
        for index in 1...40 {
            blocks.append(.paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                                    runs: [TextRun(text: "line \(index)")])))
        }
        editor.document = Document(blocks: blocks)
        window.layoutIfNeeded()

        guard let view = hostedEmojiViews().first else { return XCTFail("no hosted emoji") }
        let engine = editor.engine
        XCTAssertGreaterThan(engine.contentSize.height, engine.bounds.height + 40.0,
                             "precondition: the field must actually be scrollable")

        // Start from a known offset: setting the document parks the caret at its END, so the field
        // is already scrolled and "before" would otherwise depend on where that left it.
        engine.contentOffset = .zero
        window.layoutIfNeeded()
        let before = editor.convert(view.bounds, from: view)
        XCTAssertGreaterThan(before.minY, 40.0,
                             "precondition: the emoji must stay on screen across the scroll")
        engine.contentOffset = CGPoint(x: 0.0, y: 40.0)
        window.layoutIfNeeded()
        let after = editor.convert(view.bounds, from: view)

        XCTAssertEqual(before.minY - after.minY, 40.0, accuracy: 0.5,
                       "the emoji must move up with its text, not stay put on screen")
    }

    // MARK: - Authoring (R9-emoji-insertion)

    /// `insertEmoji` is the emoji panel's verb for a CUSTOM emoji (a standard one arrives through
    /// `insertText`). Until this rung it TRAPPED — `richTextEngineUnimplemented` — so tapping a
    /// custom emoji in the panel killed the app: the engine could render one it was handed but not
    /// write one, which are different capabilities.

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func emojiRefs() -> [EmojiRef] {
        editor.document.blocks.flatMap { $0.asParagraph?.runs ?? [] }.compactMap(\.attributes.emoji)
    }

    func test_insertingAnEmojiWritesOneAtomAndLandsTheCaretAfterIt() {
        editor.document = Document(blocks: [para("p", "ab")])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)
        editor.insertEmoji(id: "e1", altText: ":star:")
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "a\u{FFFC}b",
                       "one attachment character, where the caret was")
        XCTAssertEqual(emojiRefs().map(\.id), ["e1"])
        XCTAssertEqual(emojiRefs().first?.altText, ":star:")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    /// `instanceID` is the view-pooling key, so the same sticker inserted twice must be two views —
    /// reusing an id would make one of them vanish and the other animate for both.
    func test_twoInsertsOfTheSameEmojiGetDistinctInstanceIDs() {
        editor.document = Document(blocks: [para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        editor.insertEmoji(id: "e1", altText: nil)
        let instanceIDs = emojiRefs().map(\.instanceID)
        XCTAssertEqual(instanceIDs.count, 2)
        XCTAssertNotEqual(instanceIDs[0], instanceIDs[1])
    }

    func test_aSelectionIsReplacedByTheEmoji() {
        editor.document = Document(blocks: [para("p", "abcd")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 1, length: 2)
        editor.insertEmoji(id: "e1", altText: nil)
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "a\u{FFFC}d")
        XCTAssertEqual(emojiRefs().count, 1)
    }

    /// A button row is an ATOM — one attachment character and no text region of its own — so there
    /// is nowhere inline to put an emoji. The same refusal `insertInlineFormula` makes.
    func test_anAtomBlockRefusesTheEmoji() {
        editor.document = Document(blocks: [
            .buttonRow(ButtonRowBlock(id: BlockID("r"), buttons: [ButtonRef(label: [], action: .url(""))])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        XCTAssertTrue(emojiRefs().isEmpty)
    }

    /// The mapper bakes `emojiScale` AND `emojiRenderBoost(for:)` into the attachment. Legacy's
    /// canvas has to stamp the boost by hand and records why: without it "a freshly-inserted body
    /// emoji would render at its bare glyph box until the next full document reload". Building the
    /// run through the mapper is what makes that impossible here, so this compares an inserted
    /// emoji against a loaded one rather than asserting a number.
    func test_anInsertedEmojiIsHostedAtTheSameSizeAsALoadedOne() {
        editor.document = documentWithEmoji(id: "e1", instanceID: "i1")
        let loaded = hostedEmojiViews().first?.bounds.size
        XCTAssertNotNil(loaded, "precondition: a loaded emoji is hosted")

        editor.document = Document(blocks: [para("p", "hi ")])
        editor.engineSelectedRange = NSRange(location: 3, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        let inserted = hostedEmojiViews().first?.bounds.size
        XCTAssertNotNil(inserted, "an inserted emoji is hosted with no document reload in between")
        XCTAssertEqual(inserted, loaded)
    }

    func test_anInsertedEmojiDoesNotDrift() {
        editor.document = Document(blocks: [para("p", "hi")])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        XCTAssertEqual(editor.presentationDrift(atBlock: 0), [],
                       "presentation must stay a function of role + model")
    }

    func test_oneInsertDeliversExactlyOneChangeNotification() {
        editor.document = Document(blocks: [para("p", "hi")])
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        XCTAssertEqual(changes, 1)
    }

    /// A CODE block takes the `altText` as PLAIN TEXT rather than the atom — `insertInlineFormula`'s
    /// rule for the same block, because code leaves as preformatted text where a custom emoji has no
    /// representation. DIVERGES from the legacy canvas, which writes the real atom into code.
    func test_aCodeBlockTakesThePlainAltTextInstead() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        // Engine blocks are ["swift", "x"]: the language line first, then the body. 7 is the body's end.
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.insertEmoji(id: "e1", altText: "*")
        XCTAssertTrue(emojiRefs().isEmpty, "no atom in a code block")
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("not a code block") }
        XCTAssertEqual(code.runs.map(\.text).joined(), "x*")
        XCTAssertEqual(code.language, "swift")
    }

    func test_aCodeBlockWithNoAltTextRefusesEntirely() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.insertEmoji(id: "e1", altText: nil)
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("not a code block") }
        XCTAssertEqual(code.runs.map(\.text).joined(), "x", "nothing plain to write")
    }

    /// **A boosted body emoji on the FIRST line must not be clipped.**
    ///
    /// `emojiRenderBoost` draws a body emoji 4pt larger than the box the layout reserves, centred on
    /// it, "bleeding into the line's leading" — and the R8 work removed the dead band above line 1
    /// that the bleed had been landing in. The emoji view is parented into the engine, which is a
    /// `UIScrollView` and therefore clips, so the top of the boost has to stay inside the content.
    ///
    /// Driven under the COMPOSER's own metrics, which is the tight case: `contentPageMargin = 0`
    /// (`RichTextEditorChatInputNode.applyComposerLayoutMetrics`) removes the page inset that gives
    /// an article editor room to spare. Measured with that margin: the boost reaches 1.2871pt above
    /// the block's frame, and the block's own top inset is what has to cover it.
    func test_aBoostedEmojiOnTheFirstLineIsNotClippedAtTheContentTop() {
        editor.contentPageMargin = 0.0
        editor.minimumContentHeight = 0.0
        editor.document = documentWithEmoji(id: "e", instanceID: "i")
        window.layoutIfNeeded()

        let views = hostedEmojiViews()
        XCTAssertEqual(views.count, 1, "fixture vended no emoji view, so this asserts nothing")
        guard let view = views.first else { return }
        let block = editor.engine.id_frameForBlock(at: UInt(0))
        XCTAssertGreaterThan(view.frame.height, block.height,
                             "the fixture is not a BOOSTED emoji — its view is no taller than the "
                             + "line box, so the clipping question does not arise")
        XCTAssertGreaterThanOrEqual(view.frame.minY, 0,
                                    "the emoji's visible box starts \(view.frame.minY) — above the "
                                    + "engine's content top, where the scroll view clips it")
    }
}
