import Foundation
import UIKit
import Display
import XCTest
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData

// A media box on a fresh temporary directory, for `makePresentationTheme`.
func makeTestMediaBox() -> MediaBox {
    let path = NSTemporaryDirectory() + "TelegramPresentationDataTests-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return MediaBox(basePath: path, isMainProcess: false)
}

final class NeutralThemeTests: XCTestCase {
    private let mediaBox = makeTestMediaBox()

    func testNeutralHasGrayBubblesAndTheIncomingTextColors() {
        let theme = makeDefaultPresentationTheme(reference: .neutral, serviceBackgroundColor: nil)
        let message = theme.chat.message
        XCTAssertEqual(message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0xf4f4f4])
        XCTAssertEqual(message.outgoing.primaryTextColor, message.incoming.primaryTextColor)
        XCTAssertEqual(message.outgoing.linkTextColor, message.incoming.linkTextColor)
        XCTAssertEqual(message.outgoingCheckColor, message.incoming.accentControlColor)
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.neutral).index)
        XCTAssertEqual(theme.name, .builtin(.day))
        XCTAssertFalse(theme.overallDarkAppearance)
        XCTAssertEqual(theme.chat.defaultWallpaper, .color(0xffffff))
    }

    func testNeutralNightIsBlackWithGrayBubbles() {
        let theme = makeDefaultPresentationTheme(reference: .neutralNight, serviceBackgroundColor: nil)
        XCTAssertEqual(theme.chat.message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0x2f2f2f])
        XCTAssertEqual(theme.chat.defaultWallpaper, .color(0x000000))
        XCTAssertTrue(theme.overallDarkAppearance)
        XCTAssertEqual(theme.name, .builtin(.night))
    }

    func testNeutralKeepsItsGrayUnderAnAccent() {
        let theme = makePresentationTheme(mediaBox: mediaBox, themeReference: .builtin(.neutral), accentColor: UIColor(rgb: 0xff3b30))!
        XCTAssertEqual(theme.chat.message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0xf4f4f4])
    }

    func testAnUnknownBuiltinDecodesAsClassic() {
        let encoder = EnginePostboxEncoder()
        encoder.encodeInt32(0, forKey: "v")
        encoder.encodeInt32(9, forKey: "t")
        let decoded = PresentationThemeReference(decoder: EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded, .builtin(.dayClassic))
    }
}
