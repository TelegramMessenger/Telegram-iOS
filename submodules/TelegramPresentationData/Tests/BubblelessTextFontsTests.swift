import Foundation
import UIKit
import Display
import XCTest
import TelegramUIPreferences
import TelegramPresentationData

// Message text is set in New York when it is picked in Text Size, as in the patch: every message, with bubbles or
// without; nothing is built otherwise.
final class BubblelessTextFontsTests: XCTestCase {
    func testWithoutNewYorkNothingIsBuilt() {
        XCTAssertNil(ChatPresentationData.messageTextFonts(serif: false, baseFontSize: 17.0))
    }

    func testNewYorkAtTheSystemSizeAtEveryTextSize() {
        for size in PresentationFontSize.allCases {
            let baseFontSize = size.baseDisplaySize
            guard let fonts = ChatPresentationData.messageTextFonts(serif: true, baseFontSize: baseFontSize) else {
                XCTFail("no fonts with New York picked at \(size)")
                continue
            }
            for font in [fonts.regular, fonts.bold, fonts.italic, fonts.boldItalic] {
                XCTAssertEqual(font.pointSize, Font.regular(baseFontSize).pointSize, "\(size)")
                XCTAssertTrue(font.fontName.range(of: "NewYork", options: .caseInsensitive) != nil, "\(size): \(font.fontName)")
            }
        }
    }

    // The corners built from the settings carry the pick, in both modes.
    func testTheCornersCarryThePick() {
        for bubbleMode in [true, false] {
            var settings = PresentationThemeSettings.defaultSettings
            settings.chatBubbleSettings.bubbleMode = bubbleMode
            XCTAssertFalse(PresentationChatBubbleCorners(settings: settings.chatBubbleSettings).serifMessageText)
            settings.chatBubbleSettings.serifMessageFont = true
            XCTAssertTrue(PresentationChatBubbleCorners(settings: settings.chatBubbleSettings).serifMessageText)
        }
    }

    // What draws message text and what measures it (the News feed's cut) read one choice: New York with its quotes and
    // code-block titles in the system family when picked, else the system fonts and no block fonts.
    func testTheBodyFontsAreOneChoice() {
        let system = ChatMessageTextFonts(regular: Font.regular(17.0), bold: Font.bold(17.0), italic: Font.italic(17.0), boldItalic: Font.semiboldItalic(17.0))
        let newYork = ChatMessageTextFonts.newYork(baseFontSize: 17.0)
        let picked = ChatPresentationData.messageBodyFonts(messageTextFonts: newYork, systemTextFonts: system)
        XCTAssertEqual(picked.body.regular, newYork.regular)
        XCTAssertEqual(picked.body.boldItalic, newYork.boldItalic)
        XCTAssertEqual(picked.blockFonts?.regular, system.regular)
        let plain = ChatPresentationData.messageBodyFonts(messageTextFonts: nil, systemTextFonts: system)
        XCTAssertEqual(plain.body.regular, system.regular)
        XCTAssertEqual(plain.body.bold, system.bold)
        XCTAssertNil(plain.blockFonts)
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
