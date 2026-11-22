import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, after a paste, Send (the chat's programmatic clear) and then
/// some TYPING, the next paste puts the caret where the paste BEFORE the Send ended. The keystroke after
/// it lands mid-word:
///
///     empty → Paste "pasted" (caret 6) → Send → type "abc" (caret 3) → Paste "pasted"
///       engine: "abc pasted", caret 6 → type "Z" → "abc paZsted"
///       stock UITextView (oracle, `HarnessPasteCaretTests`): caret 10
///     control: the same without the typing (a set to "abc" and then a paste) is right. That is the
///     tenth wave's fix, `HarnessPasteCaretTests`.
///
/// **How it was seen.** The eleventh wave's K1 on-screen sweep of the tenth-wave fixes, 2026-09-23. It
/// was driven through the panel's real `sendButtonPressed`, then `insertText:` and `paste:` on the
/// engine view, and the readout said `"abc paZsted"`. It reproduced in-process at the first attempt.
///
/// **Suspected cause.** The tenth wave's `reseatSelectionAfterHostSet` (`RichTextEngineEditorView.swift`)
/// re-seats UIKit's input-controller range when a host set leaves the caret reading as "already
/// there". After Send the set leaves an empty document with the caret at 0, and typing then moves the
/// ENGINE's caret. UIKit's snapshot range is the one the next paste measures from
/// (`-[UITextInputController _pasteAttributedString:toRange:completion:]`), and it is still the
/// pre-Send paste's clamped anchor: an untracked `IDRichTextAnchor` whose offset re-grows to 6 as the
/// text grows. Typing does not refresh it.
///
/// **Tier 1**: `simulateSend` is the harness's Send (the panel's clear); typing and paste are
/// `insertText:` / `paste:` on the engine view; the pasteboard is this process's own.
@available(iOS 18.4, *)
final class HarnessPasteCaretAfterSendTests: XCTestCase {
    private func run(typing: Bool) throws -> (text: String, caret: Int) {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, HarnessContent.plainText(""))
        UIPasteboard.general.string = "pasted"
        HarnessComposerFuzzTests.execute(.paste, on: driver)
        driver.settle(0.3)
        XCTAssertEqual(driver.viewSelection().location, 6, "precondition: the first paste's caret is not at its end")
        driver.root.simulateSend()
        driver.settle(0.3)
        XCTAssertEqual(driver.viewText(), "", "precondition: Send did not clear the composer")
        if typing {
            driver.insert("abc")
        } else {
            driver.host.setInputContent(HarnessContent.plainText("abc"))
        }
        driver.settle(0.3)
        driver.setViewSelection(NSRange(location: 3, length: 0))
        driver.settle(0.2)
        UIPasteboard.general.string = "pasted"
        HarnessComposerFuzzTests.execute(.paste, on: driver)
        driver.settle(0.3)
        return (driver.viewText(), driver.viewSelection().location)
    }

    func testAPasteAfterSendAndTypingLeavesTheCaretAfterThePastedText() throws {
        let result = try self.run(typing: true)
        XCTAssertEqual(result.text, "abc pasted", "precondition: the paste did not land as a stock text view lands it")
        XCTAssertEqual(result.caret, 10, "the caret after the paste is where the paste before Send ended")
    }

    /// Control: a content set instead of typing (the tenth wave's fix).
    func testControlAContentSetInsteadOfTyping() throws {
        let result = try self.run(typing: false)
        XCTAssertEqual(result.text, "abc pasted")
        XCTAssertEqual(result.caret, 10)
    }
}
