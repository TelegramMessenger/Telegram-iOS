import Foundation
import UIKit
import Display
import XCTest
import TelegramUIPreferences
import TelegramPresentationData

// Other people's text without bubbles is set in New York (spec 5.11), built only in the bubble-free mode (6.6).
final class BubblelessTextFontsTests: XCTestCase {
    func testWithBubblesNothingIsBuilt() {
        XCTAssertNil(ChatPresentationData.bubblelessIncomingTextFonts(bubbleMode: true, baseFontSize: 17.0))
    }

    func testNewYorkAtTheSystemSizeAtEveryTextSize() {
        for size in PresentationFontSize.allCases {
            let baseFontSize = size.baseDisplaySize
            guard let fonts = ChatPresentationData.bubblelessIncomingTextFonts(bubbleMode: false, baseFontSize: baseFontSize) else {
                XCTFail("no fonts without bubbles at \(size)")
                continue
            }
            for font in [fonts.regular, fonts.bold, fonts.italic, fonts.boldItalic] {
                XCTAssertEqual(font.pointSize, Font.regular(baseFontSize).pointSize, "\(size)")
                XCTAssertTrue(font.fontName.range(of: "NewYork", options: .caseInsensitive) != nil, "\(size): \(font.fontName)")
            }
        }
    }

    // Bold is `.bold`, bold-italic is `.semibold` plus italic, as in the patch.
    func testWeightsAndTraitsAreThePatchs() {
        let baseFontSize: CGFloat = 17.0
        let fonts = ChatMessageTextFonts.newYork(baseFontSize: baseFontSize)
        XCTAssertEqual(fonts.regular, Font.with(size: baseFontSize, design: .serif))
        XCTAssertEqual(fonts.bold, Font.with(size: baseFontSize, design: .serif, weight: .bold))
        XCTAssertEqual(fonts.italic, Font.with(size: baseFontSize, design: .serif, traits: .italic))
        XCTAssertEqual(fonts.boldItalic, Font.with(size: baseFontSize, design: .serif, weight: .semibold, traits: .italic))
        XCTAssertTrue(fonts.italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertTrue(fonts.boldItalic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertFalse(fonts.regular.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertFalse(fonts.regular.fontDescriptor.symbolicTraits.contains(.traitBold))
    }
}
