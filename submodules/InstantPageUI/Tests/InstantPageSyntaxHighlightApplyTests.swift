import XCTest
import UIKit
import TelegramCore
import TextFormat
@testable import InstantPageUI

final class InstantPageSyntaxHighlightApplyTests: XCTestCase {
    private func cache(language: String, text: String, entities: [MessageSyntaxHighlight.Entity]) -> CachedMessageSyntaxHighlight {
        return CachedMessageSyntaxHighlight(values: [
            CachedMessageSyntaxHighlight.Spec(language: language, text: text): MessageSyntaxHighlight(entities: entities)
        ])
    }

    func testAppliesCachedColoursOverTheMatchingRanges() {
        let text = "let x = 1"
        let string = NSMutableAttributedString(string: text)
        let red = Int32(bitPattern: UIColor.red.rgb)
        applyInstantPageSyntaxHighlight(to: string, language: "Swift",
                                        cache: cache(language: "swift", text: text,
                                                     entities: [MessageSyntaxHighlight.Entity(color: red, range: 0 ..< 3)]))
        XCTAssertEqual(string.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor.red)
        XCTAssertNil(string.attribute(.foregroundColor, at: 4, effectiveRange: nil))
    }

    // The language is normalized on BOTH sides or a page storing "swift" never matches a block saying
    // "Swift" — the bug this shares a helper to prevent.
    func testMatchesRegardlessOfLanguageCasing() {
        let text = "let x = 1"
        let string = NSMutableAttributedString(string: text)
        let red = Int32(bitPattern: UIColor.red.rgb)
        applyInstantPageSyntaxHighlight(to: string, language: "  SWIFT  ",
                                        cache: cache(language: "swift", text: text,
                                                     entities: [MessageSyntaxHighlight.Entity(color: red, range: 0 ..< 3)]))
        XCTAssertNotNil(string.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    func testAMissLeavesTheStringUntouched() {
        let string = NSMutableAttributedString(string: "let x = 1")
        applyInstantPageSyntaxHighlight(to: string, language: "swift", cache: nil)
        XCTAssertNil(string.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        applyInstantPageSyntaxHighlight(to: string, language: "swift",
                                        cache: cache(language: "python", text: "let x = 1", entities: []))
        XCTAssertNil(string.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    // A persisted cache can outlive the text it described. Applying it partially would colour arbitrary
    // spans of unrelated code, so an out-of-bounds entity rejects the WHOLE highlight.
    func testAnOutOfBoundsEntityRejectsTheWholeHighlight() {
        let text = "abc"
        let string = NSMutableAttributedString(string: text)
        let red = Int32(bitPattern: UIColor.red.rgb)
        applyInstantPageSyntaxHighlight(to: string, language: "swift",
                                        cache: cache(language: "swift", text: text, entities: [
                                            MessageSyntaxHighlight.Entity(color: red, range: 0 ..< 1),
                                            MessageSyntaxHighlight.Entity(color: red, range: 2 ..< 99),
                                        ]))
        XCTAssertNil(string.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }
}
