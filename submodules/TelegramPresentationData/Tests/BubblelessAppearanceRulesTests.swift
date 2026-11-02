import Foundation
import XCTest
import TelegramCore
import TelegramUIPreferences

// Appearance's rules without bubbles: which theme goes with a pick at night, what the carousel lists and selects.
final class BubblelessAppearanceRulesTests: XCTestCase {
    func testPickingNeutralPairsNeutralNight() {
        XCTAssertEqual(bubblelessAutomaticTheme(afterSelecting: .builtin(.neutral), current: .builtin(.night)), .builtin(.neutralNight))
    }

    func testPickingClassicResetsANeutralNight() {
        XCTAssertEqual(bubblelessAutomaticTheme(afterSelecting: .builtin(.dayClassic), current: .builtin(.neutralNight)), .builtin(.night))
        XCTAssertEqual(bubblelessAutomaticTheme(afterSelecting: .builtin(.day), current: .builtin(.neutral)), .builtin(.night))
    }

    func testPickingClassicKeepsTintedNight() {
        XCTAssertEqual(bubblelessAutomaticTheme(afterSelecting: .builtin(.dayClassic), current: .builtin(.nightAccent)), .builtin(.nightAccent))
    }

    func testPickingANightThemeUsesItAtNight() {
        XCTAssertEqual(bubblelessAutomaticTheme(afterSelecting: .builtin(.night), current: .builtin(.neutralNight)), .builtin(.night))
    }

    func testTheCarouselStartsWithNeutralAndClassic() {
        XCTAssertEqual(bubblelessCarouselThemes(chatThemes: []), [.builtin(.neutral), .builtin(.dayClassic)])
    }

    func testNeutralKeepsItsCardDuringAutoNight() {
        var settings = PresentationThemeSettings.defaultSettings
        settings.chatBubbleSettings.bubbleMode = false
        settings.currentModeTheme = .builtin(.neutral)
        settings.currentModeAutomaticThemeSwitchSetting.theme = .builtin(.neutralNight)
        XCTAssertEqual(bubblelessCarouselSelection(settings: settings, autoNightModeTriggered: true), .builtin(.neutral))
        settings.currentModeAutomaticThemeSwitchSetting.theme = .builtin(.night)
        XCTAssertEqual(bubblelessCarouselSelection(settings: settings, autoNightModeTriggered: true), .builtin(.night))
        XCTAssertEqual(bubblelessCarouselSelection(settings: settings, autoNightModeTriggered: false), .builtin(.neutral))
    }
}
