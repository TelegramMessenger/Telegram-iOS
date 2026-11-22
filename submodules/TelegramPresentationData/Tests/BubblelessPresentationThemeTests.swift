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

    func testBubblelessNeutralKeepsGray() {
        let theme = self.build(self.off)
        let message = theme.chat.message
        XCTAssertEqual(theme.index, PresentationThemeReference.builtin(.neutral).index)
        // Gray stays gray, but a gray as pale as the page is taken down to a cool EBEBF0 that stands apart from it.
        XCTAssertEqual(message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb), [0xebebf0])
        XCTAssertEqual(message.outgoing.bubble.withWallpaper.fill.map(\.rgb), [0xebebf0])
        // Both sides' links read alike.
        XCTAssertEqual(message.outgoing.linkTextColor, message.incoming.linkTextColor)
        // Incoming messages are the page, outlined.
        XCTAssertEqual(message.incoming.bubble.withoutWallpaper.fill.map(\.rgb), [0xf9f9fb])
        XCTAssertEqual(message.incoming.bubble.withoutWallpaper.stroke.rgb, 0xdcdce1)
        XCTAssertEqual(theme.chat.serviceMessage.components.withDefaultWallpaper.primaryText.rgb, 0x8e8e93)
        XCTAssertEqual(bubblelessChatWallpaper(theme: theme), .color(0xf9f9fb))
    }
    
    // The page is the plain list background softened a little: F9F9FB rather than white, 141415 rather than black; a
    // theme with a page of another colour keeps it.
    func testBubblelessPageIsSoftened() {
        let light = self.build(self.off)
        XCTAssertEqual(bubblelessPageColor(light).rgb, 0xf9f9fb)
        let dark = self.build(self.off, autoNight: true)
        XCTAssertEqual(bubblelessPageColor(dark).rgb, 0x141415)
        XCTAssertEqual(bubblelessChatWallpaper(theme: dark), .color(0x141415))
        XCTAssertEqual(dark.chat.message.incoming.bubble.withoutWallpaper.fill.map(\.rgb), [0x141415])
        var tinted = self.off
        tinted.chatBubbleSettings.bubblelessAutomaticTheme = .builtin(.nightAccent)
        let tintedTheme = self.build(tinted, autoNight: true)
        XCTAssertNotEqual(tintedTheme.list.plainBackgroundColor.rgb, 0x000000)
        XCTAssertEqual(bubblelessPageColor(tintedTheme).rgb, tintedTheme.list.plainBackgroundColor.rgb)
    }
    
    // Soft tints: a light gray as pale as the page goes to EBEBF0; light colours keep their hue at saturation 0.14–0.28
    // and brightness 0.98; dark ones are unchanged.
    func testBubblelessSoftTints() {
        XCTAssertEqual(bubblelessOutgoingBubbleColors([UIColor(rgb: 0xf4f4f4)], dark: false).map(\.rgb), [0xebebf0])
        XCTAssertEqual(bubblelessOutgoingBubbleColors([UIColor(rgb: 0xd0d0d0)], dark: false).map(\.rgb), [0xd0d0d0])
        XCTAssertEqual(bubblelessOutgoingBubbleColors([UIColor(rgb: 0x2f2f2f)], dark: true).map(\.rgb), [0x2f2f2f])
        let strong = bubblelessOutgoingBubbleColors([UIColor(rgb: 0x4fae4e)], dark: false)[0].hsb
        XCTAssertEqual(strong.s, 0.28, accuracy: 0.01)
        XCTAssertEqual(strong.b, 0.98, accuracy: 0.01)
        let pale = bubblelessOutgoingBubbleColors([UIColor(rgb: 0xeffde8)], dark: false)[0].hsb
        XCTAssertEqual(pale.s, 0.14, accuracy: 0.01)
        let night = bubblelessOutgoingBubbleColors([UIColor(rgb: 0x2b5435)], dark: true)[0].hsb
        XCTAssertEqual(night.b, 0.3, accuracy: 0.01)
    }
    
    // A dark theme's idle waveform is a neutral gray that reads on the black page, and lighter on a gray bubble.
    func testBubblelessDarkWaveformsReadOnThePage() {
        let night = self.build(self.off, autoNight: true)
        XCTAssertEqual(night.chat.message.incoming.mediaInactiveControlColor.rgb, 0x48484a)
        XCTAssertEqual(night.chat.message.outgoing.mediaInactiveControlColor.rgb, 0x636366)
        let light = self.build(self.off)
        XCTAssertNotEqual(light.chat.message.incoming.mediaInactiveControlColor.rgb, 0x48484a)
    }
    
    // Gray bubbles with the system blue (the standard look): messages have no colour of their own; the blue gives way to
    // the text colour, and reactions are ink.
    func testBubblelessGrayWithSystemBlueIsMonochrome() {
        for theme in [self.build(self.off), self.build(self.off, autoNight: true)] {
            let message = theme.chat.message
            let inactiveAlpha: CGFloat = theme.overallDarkAppearance ? 0.12 : 0.06
            for colors in [message.incoming, message.outgoing] {
                let ink = colors.primaryTextColor
                XCTAssertEqual(colors.linkTextColor.argb, ink.argb)
                XCTAssertEqual(colors.accentTextColor.argb, ink.argb)
                XCTAssertEqual(colors.accentControlColor.argb, ink.argb)
                XCTAssertEqual(colors.mediaActiveControlColor.argb, ink.argb)
                XCTAssertEqual(colors.fileTitleColor.argb, ink.argb)
                XCTAssertEqual(colors.polls.bar.argb, ink.argb)
                XCTAssertEqual(colors.textSelectionColor.argb, ink.withAlphaComponent(0.15).argb)
                let bubble = colors.bubble.withoutWallpaper
                XCTAssertEqual(bubble.reactionActiveBackground.argb, ink.argb)
                XCTAssertEqual(bubble.reactionActiveForeground.argb, UIColor.clear.argb)
                XCTAssertEqual(bubble.reactionInactiveBackground.argb, ink.withAlphaComponent(inactiveAlpha).argb)
                XCTAssertEqual(bubble.reactionInactiveForeground.argb, ink.argb)
            }
            XCTAssertEqual(message.outgoingCheckColor.argb, message.outgoing.primaryTextColor.argb)
            XCTAssertEqual(message.infoLinkTextColor.argb, message.incoming.primaryTextColor.argb)
        }
    }
    
    // Coloured bubbles, or an accent of another colour, keep their colours.
    func testBubblelessColorKeepsItsColors() {
        var classic = self.off
        classic.currentModeTheme = .builtin(.dayClassic)
        let classicTheme = self.build(classic)
        XCTAssertNotEqual(classicTheme.chat.message.incoming.linkTextColor.argb, classicTheme.chat.message.incoming.primaryTextColor.argb)
        var orange = self.off
        orange.themeSpecificAccentColors[PresentationThemeReference.builtin(.neutral).index] = PresentationThemeAccentColor(index: 12, baseColor: .orange)
        let orangeTheme = self.build(orange)
        XCTAssertNotEqual(orangeTheme.chat.message.incoming.linkTextColor.argb, orangeTheme.chat.message.incoming.primaryTextColor.argb)
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
        XCTAssertEqual(bubblelessChatWallpaper(theme: theme), .color(0x141415))
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
