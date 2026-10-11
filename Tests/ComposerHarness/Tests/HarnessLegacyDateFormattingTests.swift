import XCTest
import UIKit
import TelegramCore
import AccountContext
import TextFormat
import ChatPresentationInterfaceState

/// **What broke.** Applying or removing a date on the legacy composer stripped the text's other
/// formatting: `chatTextInputAddDateAttribute` / `chatTextInputRemoveDateAttribute`
/// (`ChatTextFormat.swift`) queued EVERY attribute key in the range for removal, not just the date.
/// It is the sibling of the link defect the seventh roam found (`HarnessLegacyLinkFormattingTests`),
/// left behind when that was fixed; spotted reading the fix, 2026-09-23.
///
/// **Tier 1**, and below the panel: the functions are pure state transforms, and the harness has no
/// date editor to drive (the chat presents one), so the transform is what can be pinned.
final class HarnessLegacyDateFormattingTests: XCTestCase {
    private func boldQuickState() -> ChatTextInputState {
        let text = NSMutableAttributedString(string: "The quick brown fox")
        text.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 4, length: 5))
        return ChatTextInputState(inputText: text, selectionRange: 4 ..< 9)
    }

    private func isBold(_ state: ChatTextInputState, _ range: NSRange) -> Bool {
        var bold = true
        state.inputText.enumerateAttribute(ChatTextInputAttributes.bold, in: range) { value, _, _ in
            if value == nil { bold = false }
        }
        return bold
    }

    func testAddingADateKeepsTheBold() {
        let result = chatTextInputAddDateAttribute(self.boldQuickState(), selectionRange: 4 ..< 9, date: 1_800_000_000)
        XCTAssertNotNil(result.inputText.attribute(ChatTextInputAttributes.date, at: 4, effectiveRange: nil), "precondition: no date applied")
        XCTAssertTrue(self.isBold(result, NSRange(location: 4, length: 5)), "adding a date stripped the bold")
    }

    func testRemovingADateKeepsTheBold() {
        let dated = chatTextInputAddDateAttribute(self.boldQuickState(), selectionRange: 4 ..< 9, date: 1_800_000_000)
        let result = chatTextInputRemoveDateAttribute(dated, selectionRange: 4 ..< 9)
        XCTAssertNil(result.inputText.attribute(ChatTextInputAttributes.date, at: 4, effectiveRange: nil), "precondition: the date was not removed")
        XCTAssertTrue(self.isBold(result, NSRange(location: 4, length: 5)), "removing a date stripped the bold")
    }
}
