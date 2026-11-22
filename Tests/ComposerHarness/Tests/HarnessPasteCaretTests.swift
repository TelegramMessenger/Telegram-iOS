import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, after a paste, a PROGRAMMATIC content set (what the chat does
/// after Send, on a draft load, or when it clears the field) followed by another paste leaves the
/// caret where the PREVIOUS paste ended (clamped to the new text), not after the new pasted text:
///
///     empty → Paste "pasted" (caret 6, correct) → content set to "abc" (caret 3) → Paste "pasted"
///       engine: "abc pasted" (UIKit's smart-insert space is correct), caret 6 — "abc pa|sted";
///       typing Z gives "abc paZsted"
///       stock UITextView, same process: "abc pasted", caret 10
///     same after "abc" + Paste (caret 6 again); after "xyz12345" + Paste (end 15) the clamp to the
///     new length happens to land at the end (10), which is why a fresh or long previous paste hides it
///     control: the first paste of the session, into "abc", puts the caret at 10
///
/// Seen 3/3 for each ordering in one process; the node, the view and the chat's state all agree on the
/// wrong caret once settled, so it is not a stale read.
///
/// **How it was seen.** The fuzz's paste-lag reduction (`HarnessComposerFuzzTests`, 2026-09-23): typing
/// after a paste landed mid-word ("abc pZasted", "x pastZed").
///
/// **Suspected cause.** Not traced. The plain paste goes through the engine's own `paste:` (the
/// markdown transformer declines non-markdown text); something that places the caret after a paste
/// keeps the previous paste's end across `setInputContent`, which is programmatic and so resets
/// neither it nor, apparently, the undo baseline's edit selection.
///
/// **Tier 1**: `paste:` on the engine view is what the edit menu sends; `setInputContent` is the
/// panel's own entry point the chat uses; the pasteboard is this process's own, written before read.
final class HarnessPasteCaretTests: XCTestCase {
    private func paste(into texts: [String]) throws -> [(text: String, caret: Int)] {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        var results: [(text: String, caret: Int)] = []
        for text in texts {
            HarnessComposerFuzzTests.arrange(driver, HarnessContent.plainText(text))
            driver.settle(0.3)
            UIPasteboard.general.string = "pasted"
            HarnessComposerFuzzTests.execute(.paste, on: driver)
            driver.settle(0.3)
            results.append((driver.viewText(), driver.viewSelection().location))
        }
        return results
    }

    func testAPasteAfterAContentSetLeavesTheCaretAfterThePastedText() throws {
        let results = try self.paste(into: ["", "abc"])
        XCTAssertEqual(results[0].caret, 6, "precondition: the first paste's caret is not at its end")
        XCTAssertEqual(results[1].text, "abc pasted", "precondition: the second paste did not land as a stock text view lands it")
        XCTAssertEqual(results[1].caret, 10, "the caret after the second paste is where the FIRST paste ended")
    }

    /// Control: after a longer previous paste, the stale caret is clamped to the new end.
    func testControlAfterALongerPaste() throws {
        let results = try self.paste(into: ["xyz12345", "abc"])
        XCTAssertEqual(results[1].text, "abc pasted")
        XCTAssertEqual(results[1].caret, 10, "control: the caret is not at the end")
    }

    /// Oracle: a stock UITextView in the same process puts the caret after the pasted text.
    func testOracleStockTextView() throws {
        let root = try HarnessEngine.root()
        let oracle = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0))
        root.view.addSubview(oracle)
        defer { oracle.removeFromSuperview() }
        oracle.text = "abc"
        _ = oracle.becomeFirstResponder()
        oracle.selectedRange = NSRange(location: 3, length: 0)
        UIPasteboard.general.string = "pasted"
        oracle.paste(nil)
        HarnessEngine.settle(root)
        XCTAssertEqual(oracle.text, "abc pasted")
        XCTAssertEqual(oracle.selectedRange, NSRange(location: 10, length: 0))
        _ = oracle.resignFirstResponder()
    }
}
