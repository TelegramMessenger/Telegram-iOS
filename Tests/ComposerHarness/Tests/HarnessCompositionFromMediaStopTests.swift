import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, an IME composition over a selection that STARTS at a media
/// unit (on its atom, at its trailing stop, or at the end of the unit before it) and ends inside the
/// unit's CAPTION commits without the formatting of the caption text it replaces, while TYPING the same
/// text over the same selection keeps it — so the composition does not do what typing does:
///
///     [p "Listen"] [audio] [album cap=[b]"Remote"+" 0 tail"] [p "tail"]
///       "Listen\n⎕\n⎕\nRemote 0 tail\ntail": select 8..<17 (from the audio's end, over the album
///       atom, into "Remote"), compose ㅎ → … → 한글, commit
///       composed: cap="한글 0 tail"          typed: cap=[b]"한글"+" 0 tail"
///     a link there the same (typed keeps the link, composed is plain)
///     control: a selection inside the caption alone composes like typing
///     control (p15, `HarnessTypingIntoCaptionFormattingTests`): a selection from paragraph TEXT into
///       a caption composes like typing
///
/// **How it was seen.** p21 roam (2026-10-01), reducing the open edited-content fuzz failure at seed 82
/// step 49 (a Korean composition at a caption's start committed plain where typing gave a link), left
/// open by the p20 fix wave. Reduced by replaying the seed and then from a set document: no Format step,
/// no history is needed — a caption run carrying bold or a link from the starting content does it.
///
/// **Suspected cause.** The two halves pick "the start" differently. Typing goes through the surface
/// gate's `truncateAroundMediaUnits` (`RichTextEngineEditorView+SurfaceGate.swift`), whose head segment
/// is the clipped CAPTION text; it re-selects that segment before inserting, so the text inherits the
/// caption run's attributes. A composition first asks the gate for an EMPTY replacement
/// (`TGIDObservingBlockTextView tgid_resolveSelectionBeforeComposition`) and re-applies the typing
/// attributes taken from the selection BEFORE the deletion — the selection's own start, an atom or a
/// separator, which carries none. The p15 fix aligned the two for a selection that starts in text; a
/// selection that starts at a unit has no text at its start, so the two answers diverge again. Which
/// one is right is the fix's decision (p15's stated rule is "the start's formatting"); this test asks
/// only that composing and typing agree.
///
/// **Severity.** Drawn as sent (WYSIWYG), so not corruption; but the user loses bold / a link they did
/// not delete depending on which keyboard they type with.
///
/// **Tier 1**: `insertText` and `setMarkedText(_:selectedRange:)` / `unmarkText()` over a view
/// selection, the calls the keyboard makes.
@available(iOS 18.4, *)
final class HarnessCompositionFromMediaStopTests: XCTestCase {
    typealias E = HarnessEdited

    private static var bold: ChatInputInlineAttributes {
        var value = ChatInputInlineAttributes()
        value.bold = true
        return value
    }

    private static func album(_ caption: [ChatInputRun]) -> ChatInputBlock {
        return .media(ChatInputMedia(items: [
            ChatInputMediaItem(media: E.image(11), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0)),
            ChatInputMediaItem(media: E.image(12), kind: .image, naturalSize: ChatInputSize(width: 300.0, height: 400.0)),
        ], caption: caption))
    }

    private static func photo(_ caption: [ChatInputRun]) -> ChatInputBlock {
        return .media(ChatInputMedia(items: [ChatInputMediaItem(media: E.image(1), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0))], caption: caption))
    }

    /// "Listen\n⎕\n⎕\nRemote 0 tail\ntail": the audio atom is 7, the album atom 9, the caption 11..<24.
    private static func audioThenAlbum(_ first: ChatInputRun) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("Listen")]), E.audio(3), Self.album([first, E.run(" 0 tail")]), E.paragraph([E.run("tail")])])
    }

    /// "x\n⎕\nRemote 0 tail\nend": the atom is 2, the caption 4..<17.
    private static func photoAfterText(_ first: ChatInputRun) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.photo([first, E.run(" 0 tail")]), E.paragraph([E.run("end")])])
    }

    /// The model after composing 한글 (ㅎ → … → 한글, committed) over `range`, and after typing 한글 over
    /// the same range, each from a fresh `content`.
    private func composedAndTyped(_ content: ChatInputContent, _ range: (Int, Int), commit: FuzzCommit = .unmark) throws -> (composed: ChatInputContent, typed: ChatInputContent, text: String) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        HarnessComposerFuzzTests.arrange(driver, content)
        let text = driver.viewText()
        driver.setViewSelection(NSRange(location: range.0, length: range.1 - range.0))
        driver.settle(0.1)
        for step in FuzzIME.korean.steps {
            input.setMarkedText(step.text, selectedRange: step.selected)
            driver.settle(0.03)
        }
        if commit == .insertFinal {
            input.insertText("한글")
        } else {
            input.unmarkText()
        }
        driver.settle(0.2)
        XCTAssertNil(input.markedTextRange, "precondition: the composition is still open")
        let composed = FuzzModel.normalized(driver.model())
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(NSRange(location: range.0, length: range.1 - range.0))
        driver.settle(0.1)
        driver.insert("한글")
        driver.settle(0.2)
        return (composed, FuzzModel.normalized(driver.model()), text)
    }

    private func assertComposingMatchesTyping(_ content: ChatInputContent, _ range: (Int, Int), commit: FuzzCommit = .unmark, _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.composedAndTyped(content, range, commit: commit)
        // `plainText` leaves captions out, so the description is searched.
        XCTAssertTrue(FuzzModel.describe(result.composed).contains("\\u{D55C}\\u{AE00}"), "precondition: nothing was committed: \(FuzzModel.describe(result.composed))", file: file, line: line)
        XCTAssertEqual(FuzzModel.describe(result.composed), FuzzModel.describe(result.typed),
                       "\(what): composing 한글 over \(range) of \(fuzzEscaped(result.text)) does not do what typing does\n  composed \(FuzzModel.describe(result.composed))\n  typed    \(FuzzModel.describe(result.typed))",
                       file: file, line: line)
    }

    // MARK: - Red

    /// The seed-82 shape: from the end of the unit before (an audio atom), over the album, into a bold run.
    func testCompositionFromTheUnitBeforeIntoABoldCaptionRunMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.audioThenAlbum(ChatInputRun(text: "Remote", attributes: Self.bold)), (8, 17), "from the audio's end into a bold caption run")
    }

    /// The same with a link, as the fuzz met it.
    func testCompositionFromTheUnitBeforeIntoALinkedCaptionRunMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.audioThenAlbum(E.url("Remote", "https://t.example/a")), (8, 17), "from the audio's end into a linked caption run")
    }

    /// The same, committed by `insertText` of the final candidate.
    func testCompositionCommittedByInsertTextFromTheUnitBeforeMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.audioThenAlbum(ChatInputRun(text: "Remote", attributes: Self.bold)), (8, 17), commit: .insertFinal, "insertText commit from the audio's end into a bold caption run")
    }

    /// From the album's own trailing stop into the caption.
    func testCompositionFromTheAtomsTrailingStopIntoABoldCaptionRunMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.audioThenAlbum(ChatInputRun(text: "Remote", attributes: Self.bold)), (10, 16), "from the album's trailing stop into a bold caption run")
    }

    /// From the photo's atom itself into the caption (a single medium after a paragraph).
    func testCompositionFromThePhotoAtomIntoABoldCaptionRunMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.photoAfterText(ChatInputRun(text: "Remote", attributes: Self.bold)), (2, 9), "from the photo's atom into a bold caption run")
    }

    // MARK: - Controls

    /// A selection wholly inside the caption.
    func testControlCompositionInsideTheCaptionMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.audioThenAlbum(ChatInputRun(text: "Remote", attributes: Self.bold)), (11, 17), "inside the caption")
    }

    /// p15's shape: from paragraph text into the caption.
    func testControlCompositionFromParagraphTextIntoTheCaptionMatchesTyping() throws {
        try self.assertComposingMatchesTyping(Self.photoAfterText(ChatInputRun(text: "Remote", attributes: Self.bold)), (0, 9), "from paragraph text into the caption")
    }
}
