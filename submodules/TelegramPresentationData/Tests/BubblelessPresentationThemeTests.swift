import Foundation
import UIKit
import Display
import XCTest
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData

final class BubblelessPresentationThemeTests: XCTestCase {
    private let mediaBox = makeTestMediaBox()

    private var off: PresentationThemeSettings {
        var settings = PresentationThemeSettings.defaultSettings
        settings.chatBubbleSettings.bubbleMode = false
        return settings
    }

    private func build(_ settings: PresentationThemeSettings, autoNight: Bool = false) -> PresentationTheme {
        return makeBubblelessPresentationTheme(mediaBox: self.mediaBox, themeSettings: settings, autoNightModeTriggered: autoNight)
    }

    func testBubblelessNeutralKeepsGrayAndTheThemeAccent() {
        let theme = self.build(self.off)
        let message = theme.chat.message
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.neutral).index)
        // Gray stays gray.
        XCTAssertEqual(message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0xf4f4f4])
        XCTAssertEqual(message.outgoing.bubble.withWallpaper.fill.map(\.rgb), [0xf4f4f4])
        // Links keep the theme accent.
        XCTAssertEqual(message.outgoing.linkTextColor, message.incoming.linkTextColor)
        // Incoming messages are the page, outlined.
        XCTAssertEqual(message.incoming.bubble.withoutWallpaper.fill.map(\.rgb), [0xffffff])
        XCTAssertEqual(message.incoming.bubble.withoutWallpaper.stroke.rgb, 0xdcdce1)
        XCTAssertEqual(theme.chat.serviceMessage.components.withDefaultWallpaper.primaryText.rgb, 0x8e8e93)
        XCTAssertEqual(bubblelessChatWallpaper(theme: theme), .color(0xffffff))
    }

    func testBubblelessClassicGetsTheSoftenedDefaultGreen() {
        var settings = self.off
        settings.currentModeTheme = .builtin(.dayClassic)
        let theme = self.build(settings)
        let bubble = theme.chat.message.outgoing.bubble.withoutWallpaper
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.dayClassic).index)
        XCTAssertEqual(bubble.fill.map(\.rgb), bubblelessOutgoingBubbleColors([UIColor(rgb: 0xe1ffc7)], dark: false).map(\.rgb))
        XCTAssertEqual(bubble.stroke, .clear)
    }

    func testBubblelessNightGetsTelegramBlue() {
        var settings = self.off
        settings.chatBubbleSettings.bubblelessAutomaticTheme = .builtin(.night)
        let theme = self.build(settings, autoNight: true)
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.night).index)
        XCTAssertEqual(theme.chat.message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), bubblelessOutgoingBubbleColors([UIColor(rgb: 0x2b5435)], dark: true).map(\.rgb))
        let blueNight = makePresentationTheme(mediaBox: self.mediaBox, themeReference: .builtin(.night), accentColor: PresentationThemeAccentColor(baseColor: .blue).colorFor(baseTheme: .night))!
        XCTAssertEqual(theme.list.itemAccentColor.rgb, blueNight.list.itemAccentColor.rgb)
    }

    func testBubblelessAutoNightUsesNeutralNightWhenUnset() {
        let theme = self.build(self.off, autoNight: true)
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.neutralNight).index)
        XCTAssertEqual(theme.chat.message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0x2f2f2f])
        XCTAssertEqual(bubblelessChatWallpaper(theme: theme), .color(0x000000))
    }

    func testBubblelessDarkBubblesThemeStartsOnNeutralNight() {
        var settings = self.off
        settings.theme = .builtin(.night)
        let theme = self.build(settings)
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.neutralNight).index)
    }

    func testBubblelessCustomBubbleColorsAreSoftened() {
        var settings = self.off
        settings.currentModeTheme = .builtin(.dayClassic)
        settings.themeSpecificAccentColors[PresentationThemeReference.builtin(.dayClassic).index] = PresentationThemeAccentColor(index: 10, baseColor: .blue, accentColor: nil, bubbleColors: [0x0088ff])
        let theme = self.build(settings)
        let message = theme.chat.message
        XCTAssertEqual(message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), bubblelessOutgoingBubbleColors([UIColor(rgb: 0x0088ff)], dark: false).map(\.rgb))
        // The soft bubble's links take a deep shade of its own colour, not the incoming side's accent.
        XCTAssertEqual(message.outgoing.linkTextColor.hsb.h, UIColor(rgb: 0x0088ff).hsb.h, accuracy: 0.01)
        XCTAssertNotEqual(message.outgoing.linkTextColor.rgb, message.incoming.linkTextColor.rgb)
    }
}
