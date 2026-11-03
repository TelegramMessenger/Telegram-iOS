import XCTest
import Foundation
@testable import ChatRichTextEditorComposer

/// **The host's selection is a lagging mirror; while the editor has focus the editor owns the caret.**
///
/// Reported from the device: "I opened a chat, tapped the input field somewhere (with hardware
/// keyboard on), the cursor blinked there briefly, and moved." Measured on K3 against the shipped
/// build by breakpointing `-[IDBlockTextView setSelectedTextRange:]` at its entry and printing the
/// caller — every tap placed the caret and every one was overwritten about 100ms later:
///
///     tap  -> 39   (no composer frames)
///     echo -> 15   via RichTextEditorChatInputNode.setInputContent
///
/// 15 was the caret from the PREVIOUS tap. The editor reports a selection change asynchronously and
/// the chat interface state takes further turns to settle, so a layout pass inside that window
/// re-applies a selection older than the one the editor holds. It is intermittent because it needs a
/// chat state update to land in the window, which is why it reads as "sometimes".
///
/// Reproduced from a CLEAN LAUNCH with no debugger-driven selection changes beforehand, which is what
/// rules out the probe itself having staled the host's copy.
///
/// `setInputContent` already refused one shape of this — a content-equal set collapsing a live RANGE
/// to a caret, the double-tap "flash then deselect" — and that guard was written against the shape
/// that had been seen rather than against the race. A caret moving to a different caret is the same
/// echo and was unguarded.
final class ComposerEchoedSelectionTests: XCTestCase {
    private func caret(_ location: Int) -> NSRange { NSRange(location: location, length: 0) }
    private func range(_ location: Int, _ length: Int) -> NSRange {
        NSRange(location: location, length: length)
    }

    /// The reported defect, in the numbers the device produced.
    func test_aFocusedCaretIsNotMovedByAnEchoCarryingTheOlderOne() {
        XCTAssertFalse(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(15), live: caret(39), editorHasFocus: true),
            "the echo moved the caret the user had just placed at 39 back to 15")
    }

    /// **The half that keeps this from being "never move the caret".** An unfocused set is the host
    /// legitimately placing a caret the editor has no opinion about — a draft restore, a programmatic
    /// move — and it must still apply. Without this the rule would silently break opening a chat with
    /// a saved selection.
    func test_anUnfocusedCaretIsStillPlacedByTheHost() {
        XCTAssertTrue(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(15), live: caret(39), editorHasFocus: false),
            "the host can no longer place a caret in an unfocused field")
    }

    /// The guard that predates this one, kept: it covers the editor holding a RANGE while unfocused,
    /// which the focus test above would let through.
    func test_anEchoNeverCollapsesALiveRange() {
        XCTAssertFalse(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(3), live: range(2, 7), editorHasFocus: false),
            "a lagging caret collapsed the range a gesture had just made")
        XCTAssertFalse(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(3), live: range(2, 7), editorHasFocus: true))
    }

    /// An echo that agrees with the editor is the common case and must be a no-op rather than a write
    /// — writing it would churn the flat/structural mapping on every chat state update.
    func test_anEchoThatAgreesChangesNothing() {
        XCTAssertFalse(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(12), live: caret(12), editorHasFocus: true))
        XCTAssertFalse(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: caret(12), live: caret(12), editorHasFocus: false))
    }

    /// A host RANGE selection into an unfocused field still applies — "Select All" performed from
    /// outside the editor is this, and the collapse guard must not be read as "ranges are ignored".
    func test_anUnfocusedRangeFromTheHostStillApplies() {
        XCTAssertTrue(RichTextEditorChatInputNode.echoedSelectionShouldApply(
            target: range(0, 20), live: caret(4), editorHasFocus: false))
    }
}
