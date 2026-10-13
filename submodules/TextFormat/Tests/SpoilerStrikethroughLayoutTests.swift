import XCTest
import UIKit
import Display
@testable import TextFormat

/// A run can carry a strikethrough attribute and a spoiler attribute at the same time. The text
/// engine draws the strikethrough itself (CoreText does not), so the layout has to record it
/// independently of the spoiler: it is withheld at draw time while the dust is up, not dropped
/// during layout.
final class SpoilerStrikethroughLayoutTests: XCTestCase {
    private static let spoilerAttribute = NSAttributedString.Key(rawValue: "Attribute__Spoiler")

    private func makeString(spoiler: Bool, strikethrough: Bool) -> NSAttributedString {
        let string = NSMutableAttributedString(string: "hidden words")
        let range = NSRange(location: 0, length: string.length)
        string.addAttribute(.font, value: UIFont.systemFont(ofSize: 17.0), range: range)
        string.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        if strikethrough {
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
        }
        if spoiler {
            string.addAttribute(SpoilerStrikethroughLayoutTests.spoilerAttribute, value: true as NSNumber, range: range)
        }
        return string
    }

    private func layout(spoiler: Bool, strikethrough: Bool) -> TextNodeLayout {
        return TextNode.calculateLayout(
            attributedString: self.makeString(spoiler: spoiler, strikethrough: strikethrough),
            minimumNumberOfLines: 0,
            maximumNumberOfLines: 0,
            truncationType: .end,
            backgroundColor: nil,
            constrainedSize: CGSize(width: 300.0, height: 1000.0),
            alignment: .natural,
            verticalAlignment: .top,
            lineSpacingFactor: 0.12,
            cutout: nil,
            insets: UIEdgeInsets(),
            lineColor: nil,
            textShadowColor: nil,
            textShadowBlur: nil,
            textStroke: nil,
            displaySpoilers: false,
            displayEmbeddedItemsUnderSpoilers: false,
            customTruncationToken: nil
        )
    }

    /// Control: without a spoiler the strikethrough is recorded.
    func test_strikethroughWithoutSpoiler_isRecorded() {
        let result = self.layout(spoiler: false, strikethrough: true).strikethroughs
        XCTAssertEqual(result.count, 1)
        XCTAssertGreaterThan(result.first?.1.width ?? 0.0, 0.0)
    }

    /// The same run, now also a spoiler, must still carry its strikethrough.
    func test_strikethroughInsideSpoiler_isRecorded() {
        let layout = self.layout(spoiler: true, strikethrough: true)

        XCTAssertFalse(layout.spoilers.isEmpty, "fixture should produce a spoiler")

        let result = layout.strikethroughs
        XCTAssertEqual(result.count, 1, "a spoilered run must still record its strikethrough")
        XCTAssertGreaterThan(result.first?.1.width ?? 0.0, 0.0)
    }

    /// A spoiler on its own must not invent a strikethrough.
    func test_spoilerWithoutStrikethrough_recordsNone() {
        XCTAssertTrue(self.layout(spoiler: true, strikethrough: false).strikethroughs.isEmpty)
    }

    /// The geometry must not depend on the spoiler attribute either.
    func test_strikethroughGeometry_matchesTheUnspoileredRun() {
        let plain = self.layout(spoiler: false, strikethrough: true).strikethroughs
        let spoilered = self.layout(spoiler: true, strikethrough: true).strikethroughs

        XCTAssertEqual(plain.count, spoilered.count)
        for (lhs, rhs) in zip(plain, spoilered) {
            XCTAssertEqual(lhs.0, rhs.0)
            XCTAssertEqual(lhs.1, rhs.1)
        }
    }
}
