import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The article editor's INSET CONTRACT: the editor fills the screen and the host hands it the bands
/// the content must scroll under — the navigation bar on top, and on the bottom whichever of the
/// system keyboard / emoji panel is up, plus the action bar and the home indicator.
///
/// Reported from the device: "the inset adjustment behaviour when opening keyboard/emoji keyboard in
/// the article editor is simply wrong." Measured on K3 with a document ~470pt tall in an 810pt
/// editor — a document that fits the visible area more than twice over — the engine let the whole
/// article be dragged off the top of the screen and snapped it back when the panel closed:
///
/// | state                | contentInset | contentSize | offset before → after a drag |
/// |----------------------|--------------|-------------|------------------------------|
/// | no keyboard          | 68 / 92      | 810         | −68 → **+92**                |
/// | emoji panel up       | 68 / 407     | 810         | +91 → **+407**               |
/// | panel closed again   | 68 / 92      | 810         | +407 → **−68** (a 475pt jump)|
///
/// The cause is in the last column but one: `contentSize.height` is floored at the editor's FULL
/// frame height, so the scrollable range is `contentInset.top + contentInset.bottom` for EVERY
/// document, no matter how short — and each keyboard/panel transition changes that phantom range and
/// re-clamps the offset inside it. The legacy canvas floors at the VISIBLE height instead
/// (`RichTextEditorView.performLayout`, "no phantom scroll/bounce over the inset bands"), which is
/// why the shipping editor never showed this.
///
/// These cases state the contract against BOTH editors wherever the answer is observable from
/// outside, because the legacy one is the shipped behaviour this must match.
@available(iOS 18.4, *)
final class EngineArticleInsetTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    /// The article editor's real geometry, read off K3 in-process (`TGIDObservingBlockTextView`).
    private let editorSize = CGSize(width: 402.0, height: 810.0)
    /// `environment.navigationHeight` — the Close / undo / redo bar the content scrolls under.
    private let topInset: CGFloat = 68.0
    /// Action bar + home indicator, nothing else up.
    private let restingBottom: CGFloat = 92.0
    /// The system keyboard, plus the same action bar.
    private let keyboardBottom: CGFloat = 400.0
    /// The emoji panel, plus the same action bar. (Only ONE of the two is ever up.)
    private let emojiBottom: CGFloat = 407.0
    private let margins = UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0)

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 64, width: editorSize.width, height: editorSize.height))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: - Fixtures

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    /// Two short paragraphs — a document that fits the visible area even with the emoji panel up
    /// (810 − 68 − 407 = 335pt of viewport).
    private func shortDocument() -> Document {
        Document(blocks: [para("p0", "Alpha beta gamma."), para("p1", "Delta epsilon zeta.")])
    }

    /// Taller than the editor's whole frame, so it genuinely scrolls in every state.
    private func tallDocument() -> Document {
        Document(blocks: (0..<40).map { para("p\($0)", "Alpha beta gamma delta epsilon zeta eta theta iota kappa \($0).") })
    }

    // MARK: - Reading the scroll geometry

    /// How far the content can travel, in points: `maxOffset − minOffset`, exactly as UIScrollView
    /// derives them. Zero means "the document fits; nothing to scroll".
    private func scrollableRange(_ scroll: UIScrollView) -> CGFloat {
        let insets = scroll.adjustedContentInset
        let minimum = -insets.top
        let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + insets.bottom)
        return maximum - minimum
    }

    private func apply(bottom: CGFloat, top: CGFloat? = nil, to editor: RichTextEngineEditorView,
                       caretReveal: RichTextEditorCaretReveal = .none) {
        _ = editor.update(size: editorSize,
                          insets: UIEdgeInsets(top: top ?? topInset, left: 0.0, bottom: bottom, right: 0.0),
                          contentMargins: margins,
                          scrollIndicatorInsets: nil,
                          caretReveal: caretReveal)
    }

    /// The host pass a real host would run from `onCaretRevealNeeded`: the same geometry, with the
    /// request attached. The editor no longer follows the caret without one.
    private func askForAReveal(bottom: CGFloat) {
        apply(bottom: bottom, to: editor, caretReveal: .ifNeeded(.immediate))
    }

    /// The legacy editor, framed and fed identically — the oracle for every question below that a
    /// host can ask from outside.
    private func makeLegacyEditor(_ document: Document, bottom: CGFloat) -> (RichTextEditorView, UIScrollView) {
        let legacy = RichTextEditorView(frame: CGRect(x: 0, y: 64, width: editorSize.width, height: editorSize.height))
        legacy.contentPageMargin = 16.0
        window.addSubview(legacy)
        legacy.document = document
        _ = legacy.update(size: editorSize,
                          insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottom, right: 0.0),
                          contentMargins: margins,
                          scrollIndicatorInsets: nil)
        let scroll = legacy.subviews.compactMap { $0 as? UIScrollView }.first!
        return (legacy, scroll)
    }

    // MARK: - A document that fits does not scroll

    /// **The reported defect.** A two-paragraph document in an 810pt editor cannot be scrolled — in
    /// any of the three states the article editor has.
    func test_aDocumentThatFitsTheVisibleAreaDoesNotScrollInAnyKeyboardState() {
        editor.document = shortDocument()
        for (name, bottom) in [("no keyboard", restingBottom), ("system keyboard", keyboardBottom), ("emoji panel", emojiBottom)] {
            apply(bottom: bottom, to: editor)
            XCTAssertEqual(scrollableRange(editor.engine), 0.0, accuracy: 0.5,
                           "\(name): a document that fits the viewport can be dragged \(scrollableRange(editor.engine))pt")
        }
    }

    /// The same question asked of the shipped editor, so the number above is a contract and not this
    /// suite's opinion.
    func test_theLegacyEditorDoesNotScrollThatDocumentEither() {
        let (_, scroll) = makeLegacyEditor(shortDocument(), bottom: emojiBottom)
        XCTAssertEqual(scrollableRange(scroll), 0.0, accuracy: 0.5,
                       "the oracle scrolls too, so the engine's answer cannot be judged against it")
    }

    /// Opening and closing the panels must not move a document that fits, and the reason it cannot is
    /// stronger than "it happens not to": such a document has exactly ONE legal offset, `−top`, in
    /// every state — so no drag can leave it anywhere a transition would have to snap it back from.
    /// The 475pt snap measured on the device is this failing.
    func test_aDocumentThatFitsRestsAtTheTopBandInEveryKeyboardState() {
        editor.document = shortDocument()
        for (name, bottom) in [("no keyboard", restingBottom), ("emoji panel", emojiBottom),
                               ("no keyboard again", restingBottom), ("system keyboard", keyboardBottom)] {
            apply(bottom: bottom, to: editor)
            XCTAssertEqual(editor.engine.contentOffset.y, -topInset, accuracy: 0.5,
                           "\(name): the article is not resting against the navigation bar")
        }
    }

    /// A document that genuinely overflows still scrolls, and by exactly its overflow — the fix must
    /// not trade the phantom range for no scrolling at all.
    func test_aTallDocumentScrollsByExactlyItsOverflow() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        let viewport = editorSize.height - topInset - keyboardBottom
        let overflow = editor.engine.contentSize.height - viewport
        XCTAssertGreaterThan(overflow, 100.0, "the fixture is not tall enough to prove anything")
        XCTAssertEqual(scrollableRange(editor.engine), overflow, accuracy: 0.5,
                       "the scrollable range is not the document's own overflow")
    }

    // MARK: - Where a document opens

    /// A tall document opens with its FIRST line under the navigation bar's lower edge, not under the
    /// bar itself. Legacy re-seats a scroll resting at the top when the top inset changes
    /// (`update(size:insets:)`), for exactly this reason — "the article editor opened scrolled under
    /// the navigation bar".
    func test_aTallDocumentOpensBelowTheNavigationBar() {
        editor.document = tallDocument()
        apply(bottom: restingBottom, to: editor)
        XCTAssertEqual(editor.engine.contentOffset.y, -topInset, accuracy: 0.5,
                       "the document opened scrolled under the navigation bar")
    }

    // MARK: - The caret survives the band that appears under it

    /// **Opening a panel must not leave the caret behind it.** The bands change, the content does
    /// not move on its own, and a caret that was just above the action bar is now under 250pt of
    /// emoji panel — measured on K3: caret at content y≈488 with the visible area cut to [0, 335],
    /// and nothing scrolled. The engine scrolls the caret back on an edit and on a selection change
    /// (`-id_scrollCaretToVisibleIfNeeded`) but never on an INSET change, which is the one kind of
    /// change that can hide a caret nobody moved.
    func test_openingAPanelScrollsACaretItWouldCoverBackIntoView() {
        editor.document = tallDocument()
        apply(bottom: restingBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder(), "not the responder, so there is no caret to lose")

        // A caret just inside the bottom of the roomy viewport — i.e. exactly where the panel lands.
        let roomy = editorSize.height - topInset - restingBottom
        let target = editor.engine.contentOffset.y + roomy - 8.0
        let position = editor.engine.closestPosition(to: CGPoint(x: 20.0, y: target))!
        editor.engine.selectedTextRange = editor.engine.textRange(from: position, to: position)
        editor.engine.setNeedsLayout(); editor.engine.layoutIfNeeded()
        XCTAssertTrue(visibleContentRect().contains(caretRect()), "the caret did not start visible")

        apply(bottom: emojiBottom, to: editor, caretReveal: .ifNeeded(.immediate))
        XCTAssertTrue(visibleContentRect().contains(caretRect()),
                      "the emoji panel covered the caret (\(caretRect()) is outside \(visibleContentRect()))")

        apply(bottom: keyboardBottom, to: editor, caretReveal: .ifNeeded(.immediate))
        XCTAssertTrue(visibleContentRect().contains(caretRect()),
                      "the keyboard covered the caret (\(caretRect()) is outside \(visibleContentRect()))")
    }

    /// **Typing at the end of a long article keeps the caret above the keyboard**, keystroke by
    /// keystroke and across the line the keystroke creates.
    ///
    /// This one is the ENGINE's (`-id_scrollCaretToVisibleIfNeeded`, off every document change) and
    /// was never the defect — but it clamps against `contentSize`, which the phantom floor inflated
    /// by `top + bottom`, so it is worth holding still now that the bound is the real one.
    func test_typingAtTheEndKeepsTheCaretAboveTheKeyboard() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        editor.engine.setNeedsLayout(); editor.engine.layoutIfNeeded()
        // The caret is ALREADY at the document's end when it is loaded, so the set above moves
        // nothing and scrolls nothing — measured, not assumed: a selection set in code that really
        // moves the caret does reach the engine's scroll-to-caret. What makes the first keystroke
        // travel is that the document opened at the top with its end hundreds of points below the
        // keyboard's edge, which the assertion below states directly rather than by inference.
        let beforeTheFirstKeystroke = editor.engine.contentOffset.y
        XCTAssertFalse(visibleContentRect().contains(caretRect()), "the caret is already visible, so nothing has to follow it")

        for keystroke in 0..<12 {
            editor.engine.insertText(keystroke == 6 ? "\n" : "x")
            askForAReveal(bottom: keyboardBottom)
            XCTAssertTrue(visibleContentRect().contains(caretRect()),
                          "keystroke \(keystroke) put the caret behind the keyboard "
                          + "(\(caretRect()) is outside \(visibleContentRect()))")
        }
        XCTAssertGreaterThan(editor.engine.contentOffset.y, beforeTheFirstKeystroke + 1.0,
                             "the run never scrolled, so it cannot have followed anything")
    }

    // MARK: - The two ends of the document are places you can land on

    /// **A caret on the FIRST line scrolls to the beginning of the document**, not to the smallest
    /// offset that reveals its line. The minimum leaves the document's own top margin above the
    /// viewport — the first line is flush against the navigation bar with nothing before it, which
    /// reads as "there is more up there" when there is not.
    func test_aCaretOnTheFirstLineScrollsToTheBeginningOfTheDocument() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.contentOffset = CGPoint(x: 0.0, y: maximumOffsetY())
        XCTAssertGreaterThan(editor.engine.contentOffset.y, 0.0, "the fixture did not scroll away from the top")

        typeOneCharacter(at: editor.engine.beginningOfDocument, revealingAt: keyboardBottom)

        XCTAssertEqual(editor.engine.contentOffset.y, -topInset, accuracy: 0.5,
                       "stopped short of the document's beginning by its top margin")
    }

    /// And the mirror: a caret on the LAST line scrolls to the end, so the document's bottom margin
    /// is below it rather than the caret sitting flush against the action bar.
    func test_aCaretOnTheLastLineScrollsToTheEndOfTheDocument() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.contentOffset = CGPoint(x: 0.0, y: -topInset)

        typeOneCharacter(at: editor.engine.endOfDocument, revealingAt: keyboardBottom)

        XCTAssertEqual(editor.engine.contentOffset.y, maximumOffsetY(), accuracy: 0.5,
                       "stopped short of the document's end by its bottom margin")
    }

    /// A caret in the MIDDLE still scrolls the minimum — the rule above is about the two ends, and a
    /// document that jumped to an edge from the middle would be worse than one that never moved.
    func test_aCaretInTheMiddleStillScrollsTheMinimum() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.contentOffset = CGPoint(x: 0.0, y: -topInset)
        let middle = editor.engine.closestPosition(to: CGPoint(x: 20.0, y: 700.0))!

        typeOneCharacter(at: middle, revealingAt: keyboardBottom)

        let offset = editor.engine.contentOffset.y
        XCTAssertGreaterThan(offset, -topInset + 1.0, "the caret was below the viewport; something had to scroll")
        XCTAssertLessThan(offset, maximumOffsetY() - 1.0, "a caret in the middle threw the document to its end")
        // The minimum scroll puts the caret's bottom exactly on the viewport's bottom edge.
        XCTAssertEqual(caretRect().maxY, visibleContentRect().maxY, accuracy: 1.0,
                       "the scroll was not the minimum one")
    }

    /// **A line's own margin is part of it.** The rule above only fires when the caret has actually
    /// left the viewport, so a first line resting FLUSH against the navigation bar — line fully
    /// visible, the document's top margin scrolled off above it — was left there: the condition asked
    /// about the caret, while the thing that has to be visible is the caret plus the end it reaches.
    func test_theFirstLinesOwnMarginIsPartOfWhatMustBeVisible() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        typeOneCharacter(at: editor.engine.beginningOfDocument, revealingAt: keyboardBottom)

        // Park it so the LINE is entirely in bounds and only the margin above it is not — otherwise
        // this case would be testing the out-of-bounds rule again.
        editor.engine.contentOffset = CGPoint(x: 0.0, y: -topInset + 8.0)
        XCTAssertTrue(visibleContentRect().contains(caretRect()),
                      "the caret's line must start fully visible, or this proves nothing new")

        editor.engine.insertText("y")
        askForAReveal(bottom: keyboardBottom)
        XCTAssertEqual(editor.engine.contentOffset.y, -topInset, accuracy: 0.5,
                       "the first line's own margin stayed above the viewport")
    }

    /// The mirror at the other end.
    func test_theLastLinesOwnMarginIsPartOfWhatMustBeVisible() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        typeOneCharacter(at: editor.engine.endOfDocument, revealingAt: keyboardBottom)

        editor.engine.contentOffset = CGPoint(x: 0.0, y: maximumOffsetY() - 8.0)
        XCTAssertTrue(visibleContentRect().contains(caretRect()),
                      "the caret's line must start fully visible, or this proves nothing new")

        editor.engine.insertText("y")
        askForAReveal(bottom: keyboardBottom)
        XCTAssertEqual(editor.engine.contentOffset.y, maximumOffsetY(), accuracy: 0.5,
                       "the last line's own margin stayed below the viewport")
    }

    /// And the neuter for the pair above: a caret the viewport comfortably contains, at neither end,
    /// must still move NOTHING. A condition that widened everywhere would pass both cases above and
    /// drag the document on every keystroke.
    func test_aVisibleCaretInTheMiddleMovesNothing() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let middle = editor.engine.closestPosition(to: CGPoint(x: 20.0, y: 600.0))!
        typeOneCharacter(at: middle, revealingAt: keyboardBottom)
        let settled = editor.engine.contentOffset.y
        XCTAssertTrue(visibleContentRect().contains(caretRect()), "the caret is not visible, so this proves nothing")

        editor.engine.insertText("y")
        askForAReveal(bottom: keyboardBottom)
        XCTAssertEqual(editor.engine.contentOffset.y, settled, accuracy: 0.5,
                       "a keystroke under a perfectly visible caret scrolled the document")
    }

    private func maximumOffsetY() -> CGFloat {
        let insets = editor.engine.adjustedContentInset
        return max(-insets.top, editor.engine.contentSize.height - editor.engine.bounds.height + insets.bottom)
    }

    /// Parks the caret at `position` and types one character. The keystroke is what these cases are
    /// about; the park is only how the caret gets there. (A selection set that genuinely MOVES the
    /// caret reaches the engine's scroll-to-caret too — setting it to where it already is does not,
    /// which is what an earlier comment here mistook for the property not being wired at all.)
    private func typeOneCharacter(at position: UITextPosition, revealingAt bottom: CGFloat) {
        editor.engine.selectedTextRange = editor.engine.textRange(from: position, to: position)
        editor.engine.insertText("x")
        editor.engine.setNeedsLayout(); editor.engine.layoutIfNeeded()
        askForAReveal(bottom: bottom)
    }

    // MARK: - And it does not do it unasked

    /// **The neuter for the whole redesign.** Type into a tall document with no host pass at all and
    /// the offset must not move. Before the self-scroll came out this fails: the engine followed the
    /// caret from its own document-change callback, which is the entire thing being removed.
    func test_theEditorDoesNotFollowTheCaretWithoutAHostPass() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        let before = editor.engine.contentOffset.y

        for _ in 0..<5 { editor.engine.insertText("x") }

        XCTAssertEqual(editor.engine.contentOffset.y, before, accuracy: 0.5,
                       "the editor scrolled without being asked")
    }

    /// The same for a band that grows: a pass that says nothing about the caret does not reveal it,
    /// even when it is the pass that hid it.
    func test_aPanelThatCoversTheCaretWithoutBeingAskedLeavesItCovered() {
        editor.document = tallDocument()
        apply(bottom: restingBottom, to: editor)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let roomy = editorSize.height - topInset - restingBottom
        let position = editor.engine.closestPosition(to: CGPoint(x: 20.0, y: editor.engine.contentOffset.y + roomy - 8.0))!
        editor.engine.selectedTextRange = editor.engine.textRange(from: position, to: position)
        askForAReveal(bottom: restingBottom)
        let before = editor.engine.contentOffset.y

        apply(bottom: emojiBottom, to: editor)   // `.none`: the host is not asking

        XCTAssertEqual(editor.engine.contentOffset.y, before, accuracy: 0.5,
                       "the editor revealed the caret on a pass that did not ask")
        XCTAssertFalse(visibleContentRect().contains(caretRect()),
                       "the fixture did not actually cover the caret, so this proves nothing")
    }

    /// The caret, in the engine's own content coordinates.
    private func caretRect() -> CGRect {
        editor.engine.caretRect(for: editor.engine.selectedTextRange!.end)
    }

    /// The unobscured viewport, in the same coordinates.
    private func visibleContentRect() -> CGRect {
        let insets = editor.engine.adjustedContentInset
        let offset = editor.engine.contentOffset
        return CGRect(x: offset.x + insets.left, y: offset.y + insets.top,
                      width: max(editor.engine.bounds.width - insets.left - insets.right, 0),
                      height: max(editor.engine.bounds.height - insets.top - insets.bottom, 0))
    }

    // MARK: - The scroll indicator rides the same bands

    /// `scrollIndicatorInsets: nil` means "track the content insets" — the indicator is inset by the
    /// same bands the content scrolls under (`RichTextEditorView.update`'s contract, which this
    /// editor witnesses). The article editor passes nil, so without this its scrollbar runs under the
    /// navigation bar and behind the keyboard.
    func test_theIndicatorTracksTheContentInsetsWhenTheHostPassesNil() {
        editor.document = tallDocument()
        apply(bottom: keyboardBottom, to: editor)
        XCTAssertEqual(editor.engine.verticalScrollIndicatorInsets.top, topInset, accuracy: 0.5,
                       "the scrollbar runs under the navigation bar")
        XCTAssertEqual(editor.engine.verticalScrollIndicatorInsets.bottom, keyboardBottom, accuracy: 0.5,
                       "the scrollbar runs behind the keyboard")
    }

    // MARK: - The placeholder is content, and sits where content starts

    /// The body placeholder stands in for the document's first line, so it rides the top inset band
    /// exactly as that line does. Measured on K3 it was at the editor's y=12 while the caret it
    /// stands in for was at y=84, so "Type something..." was drawn UNDER the Close button: the label
    /// was placed from the text-container inset alone and never saw the CONTENT inset.
    ///
    /// Stated as "the gap between the placeholder and the caret does not depend on the top inset",
    /// which is the property the fix restores, rather than "the two are flush" — they are not, by
    /// 4pt, in the composer too and with no inset in play. That gap is the paragraph's own leading,
    /// it predates this, and folding it into a tolerance here would make this case stop reporting
    /// the thing it is for.
    func test_thePlaceholderRidesTheTopInsetBandAsTheFirstLineDoes() {
        editor.placeholders = RichTextEditorPlaceholders(body: "Type something...", listEnd: "", listOutdent: "")
        editor.document = Document(blocks: [para("p0", "")])

        func gapToTheFirstLine() -> CGFloat {
            XCTAssertFalse(editor.bodyPlaceholderLabel.isHidden, "no placeholder on screen, so this proves nothing")
            let caret = editor.convert(editor.engine.caretRect(for: editor.engine.beginningOfDocument), from: editor.engine)
            return caret.minY - editor.bodyPlaceholderLabel.frame.minY
        }

        apply(bottom: restingBottom, top: 0.0, to: editor)
        let withoutABand = gapToTheFirstLine()

        apply(bottom: restingBottom, to: editor)
        XCTAssertEqual(gapToTheFirstLine(), withoutABand, accuracy: 0.5,
                       "the placeholder did not follow the navigation band the text moved under")
        XCTAssertGreaterThanOrEqual(editor.bodyPlaceholderLabel.frame.minY, topInset,
                                    "the placeholder is drawn under the navigation bar")
    }

    /// The inset contract is exact: the host's `insets` are the whole story, so nothing may be added
    /// to them. Legacy pins this with `contentInsetAdjustmentBehavior = .never` — "the editor frame
    /// can reach into the bottom safe area, so the default `.automatic` would ADD the home-indicator
    /// inset on top of the parent's `contentInset.bottom`".
    func test_nothingIsAddedToTheHostsInsets() {
        editor.document = shortDocument()
        apply(bottom: restingBottom, to: editor)
        XCTAssertEqual(editor.engine.contentInsetAdjustmentBehavior, .never,
                       "the engine may add a safe-area inset on top of the host's own")
        XCTAssertEqual(editor.engine.adjustedContentInset.bottom, restingBottom, accuracy: 0.5)
        XCTAssertEqual(editor.engine.adjustedContentInset.top, topInset, accuracy: 0.5)
    }
}
