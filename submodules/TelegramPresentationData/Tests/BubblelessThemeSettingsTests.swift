import Foundation
import XCTest
import TelegramCore
import TelegramUIPreferences

final class BubblelessThemeSettingsTests: XCTestCase {
    func testWithBubblesTheAccessorsAreTheStoredFields() {
        var settings = typicalSettings
        XCTAssertEqual(settings.currentModeTheme, settings.theme)
        XCTAssertEqual(settings.currentModeAutomaticThemeSwitchSetting, settings.automaticThemeSwitchSetting)

        settings.currentModeTheme = .builtin(.day)
        let automatic = AutomaticThemeSwitchSetting(force: false, trigger: .system, theme: .builtin(.night))
        settings.currentModeAutomaticThemeSwitchSetting = automatic
        XCTAssertEqual(settings.theme, .builtin(.day))
        XCTAssertEqual(settings.automaticThemeSwitchSetting, automatic)
        XCTAssertNil(settings.chatBubbleSettings.bubblelessTheme)
        XCTAssertNil(settings.chatBubbleSettings.bubblelessAutomaticTheme)
    }

    func testWithoutBubblesAnUnsetChoiceIsNeutral() {
        var settings = PresentationThemeSettings.defaultSettings
        settings.chatBubbleSettings.bubbleMode = false
        XCTAssertEqual(settings.currentModeTheme, .builtin(.neutral))
        settings.theme = .builtin(.day)
        XCTAssertEqual(settings.currentModeTheme, .builtin(.neutral))
        settings.theme = .builtin(.night)
        XCTAssertEqual(settings.currentModeTheme, .builtin(.neutralNight))
        settings.theme = .builtin(.nightAccent)
        XCTAssertEqual(settings.currentModeTheme, .builtin(.neutralNight))

        let automatic = settings.currentModeAutomaticThemeSwitchSetting
        XCTAssertEqual(automatic.theme, .builtin(.neutralNight))
        XCTAssertEqual(automatic.force, settings.automaticThemeSwitchSetting.force)
        XCTAssertEqual(automatic.trigger, settings.automaticThemeSwitchSetting.trigger)
    }

    func testWithoutBubblesWritesLeaveTheBubblesFieldsAlone() {
        // Night with a purple accent, Tinted Night at night.
        var settings = typicalSettings
        settings.chatBubbleSettings.bubbleMode = false
        settings.currentModeTheme = .builtin(.dayClassic)
        var automatic = settings.currentModeAutomaticThemeSwitchSetting
        automatic.trigger = .system
        automatic.force = false
        automatic.theme = .builtin(.night)
        settings.currentModeAutomaticThemeSwitchSetting = automatic
        XCTAssertEqual(settings.theme, .builtin(.night))
        XCTAssertEqual(settings.automaticThemeSwitchSetting.theme, .builtin(.nightAccent))
        // The trigger is shared.
        XCTAssertEqual(settings.automaticThemeSwitchSetting.trigger, .system)
        XCTAssertEqual(settings.themeSpecificAccentColors, typicalSettings.themeSpecificAccentColors)

        settings.chatBubbleSettings.bubbleMode = true
        XCTAssertEqual(settings.currentModeTheme, .builtin(.night))
        XCTAssertEqual(settings.currentModeAutomaticThemeSwitchSetting.theme, .builtin(.nightAccent))
        settings.chatBubbleSettings.bubbleMode = false
        XCTAssertEqual(settings.currentModeTheme, .builtin(.dayClassic))
        XCTAssertEqual(settings.currentModeAutomaticThemeSwitchSetting.theme, .builtin(.night))
    }

    // A theme link applied without bubbles goes to the bubble-free choice only. Marking Night's accent slot with it
    // would change how bubbles look afterwards: Night would lose its blue at night, and a purple Night would lose its
    // purple.
    func testApplyingACloudThemeWithoutBubblesLeavesTheBuiltinAccentsAlone() {
        var settings = typicalSettings
        settings.chatBubbleSettings.bubbleMode = false
        let accentColors = settings.accentColors(afterApplyingCloudTheme: 777, basedOn: .builtin(.night))
        XCTAssertEqual(accentColors, settings.themeSpecificAccentColors)
        XCTAssertEqual(accentColors[PresentationThemeReference.builtin(.night).index]?.baseColor, .purple)
    }

    func testApplyingACloudThemeWithBubblesMarksItsBuiltin() {
        let accentColors = typicalSettings.accentColors(afterApplyingCloudTheme: 777, basedOn: .builtin(.night))
        let marker = accentColors[PresentationThemeReference.builtin(.night).index]
        XCTAssertEqual(marker?.baseColor, .theme)
        XCTAssertEqual(marker?.themeIndex, 777)
    }
}
