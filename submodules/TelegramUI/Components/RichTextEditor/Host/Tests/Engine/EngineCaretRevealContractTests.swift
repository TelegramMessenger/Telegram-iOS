import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The shared contract for who decides that the caret is revealed, asked of BOTH editors.
///
/// The rule it exists to hold: **an editor does not scroll itself to follow the caret.** It reports
/// that a reveal is owed and performs one only inside a host's layout pass, against the geometry
/// that pass applies. Every misfire this replaces was the editor deciding against a number the host
/// was about to change — the composer flickering into scroll mode as the panel grew the field, and
/// the article editor's caret landing under a keyboard whose inset had not arrived yet.
///
/// See the RichTextEditor `CLAUDE.md`, "The host decides when the caret is revealed".
@available(iOS 18.4, *)
final class EngineCaretRevealContractTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// Taller than the viewport in every keyboard state, so there is always somewhere to scroll.
    private func tallDocument() -> Document {
        Document(blocks: (0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"),
                                      runs: [TextRun(text: "Alpha beta gamma delta epsilon zeta eta theta \($0).")]))
        })
    }

    /// The article editor's real geometry, with the system keyboard up.
    private func layOut(_ editor: any RichTextEditor, caretReveal: RichTextEditorCaretReveal) {
        _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                          insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 400.0, right: 0.0),
                          contentMargins: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0),
                          scrollIndicatorInsets: nil,
                          caretReveal: caretReveal)
    }

    private func makeEditors() -> [any RichTextEditor] {
        [RichTextEngineEditorView(frame: .zero), RichTextEditorView(frame: .zero)]
    }

    // MARK: - `.none` is the honest default

    /// Both editors witness the five-argument requirement, and a pass that says nothing about the
    /// caret does not move it. That is what makes `.none` safe for the four-argument spelling every
    /// existing call site still uses.
    func test_aPassThatSaysNothingAboutTheCaretMovesNothing() {
        for editor in makeEditors() {
            editor.frame = CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0)
            editor.contentPageMargin = 16.0
            window.addSubview(editor)
            editor.document = tallDocument()
            layOut(editor, caretReveal: .none)
            let before = editor.composerContentOffset.y
            layOut(editor, caretReveal: .none)
            XCTAssertEqual(editor.composerContentOffset.y, before, accuracy: 0.5,
                           "\(type(of: editor)) moved on a pass that said nothing about the caret")
        }
    }

    // MARK: - The report that a reveal is owed

    /// **Synchronously**, which is the whole point of it being a separate callback. `onChange` is
    /// coalesced to one trailing async call per run-loop turn so a toolbar never observes a
    /// transient selection; a reveal riding that signal lands a turn late, and a rapid second arrow
    /// key then computes its destination against an in-flight offset. Measured here by the absence
    /// of any run-loop turn between the edit and the count.
    func test_anEditFiresTheRevealSignalSynchronously() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        var signals = 0
        editor.onCaretRevealNeeded = { signals += 1 }
        editor.engine.insertText("x")
        XCTAssertEqual(signals, 1, "the edit did not ask for a reveal in the same run-loop turn")
    }

    /// A caret that moves without the text changing asks too — the arrow-key case. It must move to
    /// somewhere it is NOT: a set to the caret's own position changes nothing and reports nothing,
    /// and mistaking that for "the property is not wired" is how an earlier reading of this went
    /// wrong. The document loads with the caret at its end, so this moves to the beginning.
    func test_aSelectionMoveFiresItToo() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        var signals = 0
        editor.onCaretRevealNeeded = { signals += 1 }
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
        XCTAssertEqual(signals, 1, "a caret move must ask for a reveal exactly once")
    }

    /// Legacy reports it too, from the same two causes.
    func test_theLegacyEditorReportsItAsWell() {
        let editor = RichTextEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.becomeFirstResponder())

        var signals = 0
        editor.onCaretRevealNeeded = { signals += 1 }
        editor.insertText("x")
        XCTAssertGreaterThanOrEqual(signals, 1, "legacy did not ask for a reveal")
    }

    // MARK: - A pass that asks

    /// A host pass that asks reveals against the geometry THAT PASS applies. Asserted with the
    /// editor's own self-scroll still in place, so it says only that the new path works — "and the
    /// old one is gone" is Task 7's assertion, not this one's.
    ///
    /// The caret is put at the document's end by TYPING, not by a selection set: the caret is already
    /// there when the document loads, so a set would move nothing and mark nothing.
    func test_aPassThatAsksRevealsAgainstTheGeometryItApplies() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("x")
        // Drag it away from the caret, so the pass below has somewhere to travel from.
        editor.engine.contentOffset = CGPoint(x: 0.0, y: -68.0)

        layOut(editor, caretReveal: .ifNeeded(.immediate))

        let insets = editor.engine.adjustedContentInset
        let maximum = max(-insets.top,
                          editor.engine.contentSize.height - editor.engine.bounds.height + insets.bottom)
        XCTAssertEqual(editor.engine.contentOffset.y, maximum, accuracy: 0.5,
                       "the caret is on the last line, so the reveal must reach the document's end")
    }

    /// And a pass that asks while the caret is comfortably visible moves nothing — `ifNeeded` means
    /// what it says, or every host layout would drag the document around.
    func test_aPassThatAsksWithTheCaretVisibleMovesNothing() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("x")
        layOut(editor, caretReveal: .ifNeeded(.immediate))
        let settled = editor.engine.contentOffset.y

        layOut(editor, caretReveal: .ifNeeded(.immediate))
        XCTAssertEqual(editor.engine.contentOffset.y, settled, accuracy: 0.5,
                       "a second ask moved a caret that was already visible")
    }

    /// Legacy answers the same contract through the same solver: a pass that asks produces a
    /// reveal. That it no longer reveals WITHOUT being asked is Task 7's assertion, not this one's.
    func test_theLegacyEditorRevealsWhenAsked() {
        let editor = RichTextEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.insertText("x")
        // Drag it away from the caret. Legacy leaves the caret near the START of a freshly loaded
        // document, so "away" is the BOTTOM — assuming the end, as the engine's cases can, would
        // leave the caret already visible and the assertion vacuous.
        let scroll = editor.subviews.compactMap { $0 as? UIScrollView }.first!
        let maximum = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.contentOffset = CGPoint(x: 0.0, y: maximum)
        XCTAssertGreaterThan(maximum, 0.0, "the fixture does not scroll, so this proves nothing")

        layOut(editor, caretReveal: .ifNeeded(.immediate))

        XCTAssertLessThan(editor.composerContentOffset.y, maximum - 1.0,
                          "legacy ignored a pass that asked for a reveal")
    }

    /// Legacy's half of the neuter: it does not follow the caret without being asked either.
    func test_theLegacyEditorDoesNotFollowTheCaretWithoutAHostPass() {
        let editor = RichTextEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.becomeFirstResponder())
        let scroll = editor.subviews.compactMap { $0 as? UIScrollView }.first!
        let maximum = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        XCTAssertGreaterThan(maximum, 0.0, "the fixture does not scroll, so this proves nothing")
        scroll.contentOffset = CGPoint(x: 0.0, y: maximum)

        editor.insertText("x")

        XCTAssertEqual(editor.composerContentOffset.y, maximum, accuracy: 0.5,
                       "legacy scrolled to the caret without being asked")
    }

    // MARK: - The two reported symptoms, and the hazard the fix could reintroduce

    /// **Symptom 1 — the composer flickering into scroll mode.** A keystroke that grows the content
    /// must produce NO offset of its own; the panel's next pass, at the field's new height, is the
    /// only thing that may move it.
    ///
    /// Asserted over the whole sequence rather than at the end. The flicker is one rendered frame
    /// with a scrolled offset between the edit and the pass, so a state check after both would see
    /// the settled value and pass over the defect. What this counts is how many DISTINCT offsets the
    /// sequence ever held.
    func test_growingTheContentNeverProducesAnIntermediateOffset() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 96.0))
        editor.contentPageMargin = 0.0
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "a")]))])
        _ = editor.update(size: CGSize(width: 320.0, height: 96.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        var offsets: [CGFloat] = [editor.engine.contentOffset.y]
        for _ in 0..<8 {
            editor.engine.insertText("wwwwwwwwww wwwwwwwwww wwwwwwwwww wwwwwwwwww wwwwwwwwww ")
            offsets.append(editor.engine.contentOffset.y)   // the composer grows; nothing may scroll
        }
        XCTAssertGreaterThan(editor.engine.contentSize.height, editor.engine.bounds.height * 3.0,
                             "the fixture barely overflows the field, so there is nothing to scroll and "
                             + "this case cannot see the defect it is for")
        XCTAssertEqual(Set(offsets.map { ($0 * 2.0).rounded() }).count, 1,
                       "the editor scrolled between the keystroke and the host's pass: \(offsets)")
    }

    /// **Symptom 2 — the caret under the keyboard, and then not animated.** The pass that adds the
    /// keyboard's inset must both reveal the caret and animate it.
    ///
    /// The animation is asserted by ENUMERATING the layer's animation keys rather than asking for one
    /// by name: guessing a key path produced a false negative on this project before.
    func test_theKeyboardsPassRevealsTheCaretAndAnimatesIt() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                          insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 92.0, right: 0.0),
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // A caret just inside the bottom of the roomy viewport — where the keyboard is about to land.
        let roomy = 810.0 - 68.0 - 92.0
        let position = editor.engine.closestPosition(to: CGPoint(x: 20.0, y: editor.engine.contentOffset.y + roomy - 8.0))!
        editor.engine.selectedTextRange = editor.engine.textRange(from: position, to: position)
        _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                          insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 92.0, right: 0.0),
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))
        let beforeTheKeyboard = editor.engine.contentOffset.y

        _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                          insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 400.0, right: 0.0),
                          contentMargins: .zero, scrollIndicatorInsets: nil,
                          caretReveal: .ifNeeded(.animated(duration: 0.25, curve: .easeInOut)))

        XCTAssertNotEqual(editor.engine.contentOffset.y, beforeTheKeyboard, accuracy: 0.5,
                          "the keyboard's pass left the caret where the keyboard now is")
        let keys = editor.engine.layer.animationKeys() ?? []
        XCTAssertFalse(keys.isEmpty, "the reveal was not animated; keys = \(keys)")
    }

    /// **The hazard this design could reintroduce.** Legacy scrolls synchronously inside the
    /// selection setter on purpose: its own comment records that an animated reveal mutates
    /// `contentOffset` mid-flight, so a rapid second arrow key computes its destination against
    /// in-flux state and arrow navigation goes non-deterministic.
    ///
    /// So a reveal owed to a caret that MOVED is immediate whatever the host passed — here the host
    /// passes a 0.4s spring and must not get one.
    ///
    /// Unlike the two cases above, this one does NOT reproduce a past defect: before the redesign
    /// nothing animated, so it passed then too. It is a guard against a future change introducing the
    /// animation here — verified by neutering the reveal, which the two above catch and this does
    /// not. Worth keeping, worth not mistaking for a reproduction.
    func test_twoCaretMovesInOneTurnBothSettleImmediately() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        let insets = UIEdgeInsets(top: 68.0, left: 0.0, bottom: 400.0, right: 0.0)
        _ = editor.update(size: CGSize(width: 402.0, height: 810.0), insets: insets,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.onCaretRevealNeeded = { [weak editor] in
            guard let editor else { return }
            _ = editor.update(size: CGSize(width: 402.0, height: 810.0), insets: insets,
                              contentMargins: .zero, scrollIndicatorInsets: nil,
                              caretReveal: .ifNeeded(.animated(duration: 0.4, curve: .spring)))
        }

        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)

        XCTAssertEqual(editor.engine.contentOffset.y, -68.0, accuracy: 0.5,
                       "the second move did not settle where it should")
        XCTAssertTrue((editor.engine.layer.animationKeys() ?? []).isEmpty,
                      "a caret move animated, so a rapid second one would race it")
    }

    /// **The new coupling, made audible.** Caret-follow now depends on a host pass arriving, so a
    /// host that installs the callback and then ignores it stops following the caret — and the
    /// symptom is "typing feels broken", not a missing call. The audit counts that; this checks the
    /// count is real rather than a log nobody reads.
    func test_aHostThatIgnoresTheReportIsCounted() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.onCaretRevealNeeded = { }        // installed, and answers nothing

        editor.engine.insertText("x")
        let counted = expectation(description: "the audit runs a turn later")
        DispatchQueue.main.async { counted.fulfill() }
        wait(for: [counted], timeout: 1.0)

        XCTAssertGreaterThanOrEqual(editor.caretRevealsNeverAskedAbout, 1,
                                    "a host that never asked was not noticed")
    }

    /// And the other side of it: a host that DOES answer is never counted, or the audit would cry
    /// wolf on both shipping hosts.
    func test_aHostThatAnswersIsNotCounted() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        layOut(editor, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.onCaretRevealNeeded = { [weak editor] in
            guard let editor else { return }
            _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                              insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 400.0, right: 0.0),
                              contentMargins: .zero, scrollIndicatorInsets: nil,
                              caretReveal: .ifNeeded(.immediate))
        }

        editor.engine.insertText("x")
        let settled = expectation(description: "a turn later")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1.0)

        XCTAssertEqual(editor.caretRevealsNeverAskedAbout, 0, "a host that answered was counted anyway")
    }

    /// **A pass that shrinks the FIELD shrinks the viewport too.** Reported from the device: tapping
    /// the last line of a chat draft focuses it, everything recalculates correctly, and the caret ends
    /// up below the edge.
    ///
    /// Traced in the running app — the composer's field went 281x169 to 317x146 on focus, because the
    /// accessory buttons go away, the text re-wraps wider and the field gets shorter — and the pass
    /// that applied it reported `shrank=0`. The check only compared INSETS, and the composer's are
    /// always zero: its viewport shrinks by the frame. A caret on the last line is then below the new
    /// bottom with nothing left to bring it back.
    func test_aPassThatShrinksTheFieldRevealsTheCaretItHides() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 0.0, width: 317.0, height: 169.0))
        editor.contentPageMargin = 0.0
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"),
            runs: [TextRun(text: String(repeating: "alpha beta gamma delta ", count: 8))]))])
        _ = editor.update(size: CGSize(width: 317.0, height: 169.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // Caret at the end — the last line, which the shrink is about to push out of sight.
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        _ = editor.update(size: CGSize(width: 317.0, height: 169.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))
        XCTAssertTrue(editor.engine.contentSize.height > 100.0, "the fixture has no content to hide")

        // The focus pass, as the PANEL actually performs it: it assigns the editor's frame directly
        // (`textFieldFrame`) and only then calls update. So by the time update runs, the view's own
        // bounds are already the new ones — which is why "did the viewport shrink?" cannot be answered
        // by reading them, and has to be answered from what the last pass APPLIED.
        editor.frame = CGRect(x: 0.0, y: 0.0, width: 317.0, height: 100.0)
        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))

        let caret = editor.engine.caretRect(for: editor.engine.selectedTextRange!.end)
        let visibleBottom = editor.engine.contentOffset.y + editor.engine.bounds.height
        XCTAssertLessThanOrEqual(caret.maxY, visibleBottom + 0.5,
                                 "the caret is below the field's edge after it shrank "
                                 + "(caret \(caret), visible bottom \(visibleBottom))")
    }

    /// **A pass that GROWS the field can still hide the caret, because it also re-wraps the text.**
    ///
    /// Reported from the device: pressing Return on a hardware keyboard dismisses the software
    /// keyboard, and the caret ends up under the field's bottom edge. Measured on K3, caret at the
    /// end of a scrolling draft:
    ///
    ///     keyboard up        field 274  offset 131  content 405  caret 377..399.67   visible 131..405
    ///     keyboard dismissed field 298  offset 107  content 428  caret 400..422.67   visible 107..405
    ///
    /// The field got TALLER by 24 — and the same pass made it NARROWER, because the accessory buttons
    /// come back when the keyboard goes, so the text re-wrapped and the content grew by 23. The caret
    /// moved down with the re-wrap and finished 18pt below the visible bottom.
    ///
    /// Neither half of the old `ifNeeded` condition held: nothing ASKED (the caret did not move in the
    /// document — the text moved under it), and the viewport did not SHRINK, it grew. So the rule is
    /// not "the viewport shrank" but "this pass changed the geometry the caret is measured against",
    /// which is what the shrink test was approximating from a single instance.
    func test_aPassThatGrowsTheFieldButRewrapsItRevealsTheCaret() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 0.0, width: 317.0, height: 100.0))
        editor.contentPageMargin = 0.0
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"),
            runs: [TextRun(text: String(repeating: "alpha beta gamma delta ", count: 8))]))])
        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))
        let contentBefore = editor.engine.contentSize.height
        let caretBefore = editor.engine.caretRect(for: editor.engine.selectedTextRange!.end)
        XCTAssertLessThanOrEqual(caretBefore.maxY,
                                 editor.engine.contentOffset.y + editor.engine.bounds.height + 0.5,
                                 "the caret is already hidden before the pass under test")

        // Narrower AND taller, the shape the device measured: the panel assigns the frame itself, so
        // the view already has the new bounds by the time `update` runs.
        editor.frame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 124.0)
        _ = editor.update(size: CGSize(width: 200.0, height: 124.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))

        // The fixture has to actually reproduce the shape, or this passes for the wrong reason.
        XCTAssertGreaterThan(editor.engine.contentSize.height, contentBefore + 24.0,
                             "the width change did not re-wrap enough to move the caret past the growth")

        let caret = editor.engine.caretRect(for: editor.engine.selectedTextRange!.end)
        let visibleBottom = editor.engine.contentOffset.y + editor.engine.bounds.height
        XCTAssertLessThanOrEqual(caret.maxY, visibleBottom + 0.5,
                                 "the caret is below the field's edge after a pass that grew it "
                                 + "(caret \(caret), visible bottom \(visibleBottom))")
    }

    /// **A pass that changes nothing leaves a scroll the user owns alone**, even with the caret out
    /// of sight. This is the other side of the rule above: widening "shrank" to "changed" widens what
    /// can yank the offset back, so what still protects a deliberate scroll is that a pass which
    /// applies the SAME geometry reveals nothing. Without it `ifNeeded` would be the bare
    /// out-of-band test the contract exists to avoid.
    func test_aPassThatChangesNothingLeavesAUserScrollAlone() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 0.0, width: 317.0, height: 100.0))
        editor.contentPageMargin = 0.0
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"),
            runs: [TextRun(text: String(repeating: "alpha beta gamma delta ", count: 8))]))])
        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .none)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))

        // The user drags to the top, away from the caret at the end.
        editor.engine.contentOffset = CGPoint(x: 0.0, y: 0.0)
        let caret = editor.engine.caretRect(for: editor.engine.selectedTextRange!.end)
        XCTAssertGreaterThan(caret.maxY, editor.engine.bounds.height,
                             "the fixture does not put the caret out of sight, so this proves nothing")

        _ = editor.update(size: CGSize(width: 317.0, height: 100.0), insets: .zero,
                          contentMargins: .zero, scrollIndicatorInsets: nil, caretReveal: .ifNeeded(.immediate))

        XCTAssertEqual(editor.engine.contentOffset.y, 0.0, accuracy: 0.5,
                       "an identical pass yanked the scroll back to the caret")
    }

    /// The four-argument spelling still exists and means `.none`.
    func test_theFourArgumentSpellingStillCompilesAndMeansNone() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0.0, y: 64.0, width: 402.0, height: 810.0))
        editor.contentPageMargin = 16.0
        window.addSubview(editor)
        editor.document = tallDocument()
        _ = editor.update(size: CGSize(width: 402.0, height: 810.0),
                          insets: UIEdgeInsets(top: 68.0, left: 0.0, bottom: 400.0, right: 0.0),
                          contentMargins: .zero, scrollIndicatorInsets: nil)
        XCTAssertEqual(editor.engine.contentOffset.y, -68.0, accuracy: 0.5)
    }
}
