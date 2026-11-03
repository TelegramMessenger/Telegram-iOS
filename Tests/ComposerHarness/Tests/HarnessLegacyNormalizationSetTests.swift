import XCTest
import UIKit
import TelegramCore
@testable import ComposerHarnessLib

/// **What broke.** The legacy text view's `attributedText` setter writes in place when the new value
/// has the "same characters" as the storage, and decided that with Swift `String ==`, which compares
/// CANONICAL EQUIVALENCE: precomposed "é" (one UTF-16 unit) equals "e" + U+0301 (two). The in-place
/// write then walks the new value's UTF-16 ranges against storage of a different length — longer
/// value: `NSRangeException`, a crash; shorter value: the view keeps its old code units while the
/// chat's state holds the new ones, so every later selection and entity offset is off by the
/// difference.
///
/// **How it was seen.** Code review of the InputDec squash (2026-10-12). A programmatic set in the
/// other normalization form reaches the setter from a draft sync, an edit load, or Translate.
///
/// **Tier 1**: the setter is the text view's own; nothing above it is involved.
final class HarnessLegacyNormalizationSetTests: XCTestCase {
    private let precomposed = "caf\u{00E9}"      // café, NFC: 4 UTF-16 units
    private let decomposed = "cafe\u{0301}"      // café, NFD: 5 UTF-16 units

    /// The shorter value replacing the longer one must replace the CODE UNITS, not just keep the old
    /// ones because Swift calls them equal.
    func testASetInTheShorterNormalizationReplacesTheCodeUnits() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText(self.decomposed))
        arranged = value
        XCTAssertEqual((value.textView.text as NSString).length, 5, "precondition: the view holds the decomposed form")

        value.textView.attributedText = NSAttributedString(string: self.precomposed)
        XCTAssertEqual((value.textView.text as NSString).length, 4, "the view kept the old code units")
        XCTAssertTrue((value.textView.text as NSString).isEqual(to: self.precomposed))
    }

    /// The longer value replacing the shorter one raised `NSRangeException` before the fix (the test
    /// process trapped here).
    func testASetInTheLongerNormalizationDoesNotRaise() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText(self.precomposed))
        arranged = value
        XCTAssertEqual((value.textView.text as NSString).length, 4, "precondition: the view holds the precomposed form")

        value.textView.attributedText = NSAttributedString(string: self.decomposed)
        XCTAssertTrue((value.textView.text as NSString).isEqual(to: self.decomposed))
    }

    /// Control: a set that really does keep the characters still writes attributes only.
    func testASetWithTheSameCodeUnitsKeepsTheText() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText(self.precomposed))
        arranged = value
        value.textView.attributedText = NSAttributedString(string: self.precomposed)
        XCTAssertTrue((value.textView.text as NSString).isEqual(to: self.precomposed))
    }
}
