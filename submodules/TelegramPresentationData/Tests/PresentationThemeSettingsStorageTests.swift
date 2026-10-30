import Foundation
import XCTest
import TelegramCore
import TelegramUIPreferences

// The bytes `updatePresentationThemeSettingsInteractively` stores for these settings.
func storedBytes(_ settings: PresentationThemeSettings) -> String {
    return EnginePreferencesEntry(settings)!.data.base64EncodedString()
}

// Every field away from its default. At most one entry per dictionary: a `[DictionaryKey: …]` dictionary encodes in
// iteration order, which is random per process.
let typicalSettings = PresentationThemeSettings(
    theme: .builtin(.night),
    themePreferredBaseTheme: [PresentationThemeReference.builtin(.night).index: .tinted],
    themeSpecificAccentColors: [PresentationThemeReference.builtin(.night).index: PresentationThemeAccentColor(baseColor: .purple)],
    themeSpecificChatWallpapers: [PresentationThemeReference.builtin(.dayClassic).index: .color(0x223344)],
    useSystemFont: false,
    fontSize: .large,
    listsFontSize: .medium,
    chatBubbleSettings: PresentationChatBubbleSettings(mainRadius: 10, auxiliaryRadius: 5, mergeBubbleCorners: false),
    automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(force: true, trigger: .timeBased(setting: .manual(fromSeconds: 79_200, toSeconds: 25_200)), theme: .builtin(.nightAccent)),
    largeEmoji: false,
    reduceMotion: true
)

// Captured from master's encoding at this branch's base (daf7a38360), before the bubble-free fields existed. With
// bubbles on, the settings must store exactly these bytes.
let masterDefaultBytes = "AV8FPw0k73MBAAABdAX4oF59DgAAAAF2AAAAAAABdAAAAAAAF3RoZW1lUHJlZmVycmVkQmFzZVRoZW1lBgAAAAAZdGhlbWVTcGVjaWZpY0FjY2VudENvbG9ycwYAAAAAG3RoZW1lU3BlY2lmaWNDaGF0V2FsbHBhcGVycwYAAAAADXVzZVN5c3RlbUZvbnQAAQAAAAFmAAIAAAACbGYAAgAAABJjaGF0QnViYmxlU2V0dGluZ3MFJ8Yjhj0AAAAKbWFpblJhZGl1cwAQAAAAD2F1eGlsaWFyeVJhZGl1cwAIAAAAEm1lcmdlQnViYmxlQ29ybmVycwABAAAAG2F1dG9tYXRpY1RoZW1lU3dpdGNoU2V0dGluZwWwG71pQQAAAAVmb3JjZQIAB3RyaWdnZXIFNIaHVQgAAAACX3QAAAAAAAh0aGVtZV92MgX4oF59DgAAAAF2AAAAAAABdAABAAAACmxhcmdlRW1vamkCAQxyZWR1Y2VNb3Rpb24CAA=="
let masterTypicalBytes = "AV8FPw0k7ykCAAABdAX4oF59DgAAAAF2AAAAAAABdAABAAAAF3RoZW1lUHJlZmVycmVkQmFzZVRoZW1lBwIAAAABAAAAAAAAAAMAAAAAAAAAGXRoZW1lU3BlY2lmaWNBY2NlbnRDb2xvcnMJAQAAALMCD2gLAAAAAWsBAQAAAAAAAAC8stdQKQAAAAFpAA8AAAABYgAFAAAAAWMLDGJ1YmJsZUNvbG9ycwYAAAAAAXcLAXQLG3RoZW1lU3BlY2lmaWNDaGF0V2FsbHBhcGVycwkBAAAAswIPaAsAAAABawEAAAAAAAAAALE49VUOAAAAAXYAAQAAAAFjAEQzIgANdXNlU3lzdGVtRm9udAAAAAAAAWYAAwAAAAJsZgAGAAAAEmNoYXRCdWJibGVTZXR0aW5ncwUnxiOGPQAAAAptYWluUmFkaXVzAAoAAAAPYXV4aWxpYXJ5UmFkaXVzAAUAAAASbWVyZ2VCdWJibGVDb3JuZXJzAAAAAAAbYXV0b21hdGljVGhlbWVTd2l0Y2hTZXR0aW5nBbAbvWl6AAAABWZvcmNlAgEHdHJpZ2dlcgU0hodVQQAAAAJfdAABAAAAB3NldHRpbmcFbxoFjCgAAAACX3QAAAAAAAtmcm9tU2Vjb25kcwBgNQEACXRvU2Vjb25kcwBwYgAACHRoZW1lX3YyBfigXn0OAAAAAXYAAAAAAAF0AAMAAAAKbGFyZ2VFbW9qaQIADHJlZHVjZU1vdGlvbgIB"

// The two theme keys an older build reads, exactly as it decodes them: it force-unwraps the builtin raw value inside
// each one, so a raw value it does not know crashes it at launch (and both extensions with it).
private struct LegacyKeys: Decodable {
    struct AutomaticThemeSwitchSetting: Decodable {
        enum CodingKeys: String, CodingKey {
            case theme = "theme_v2"
        }

        let theme: EngineAdaptedPostboxDecoder.RawObjectData
    }

    let t: EngineAdaptedPostboxDecoder.RawObjectData
    let automaticThemeSwitchSetting: AutomaticThemeSwitchSetting
}

// The builtin raw value in a stored theme reference, or 0 for a local or cloud theme, which every build decodes.
private func builtinRawValue(_ data: EngineAdaptedPostboxDecoder.RawObjectData) -> Int32 {
    let decoder = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data.data))
    if decoder.decodeInt32ForKey("v", orElse: 0) != 0 {
        return 0
    }
    return decoder.decodeInt32ForKey("t", orElse: 0)
}

private func legacyKeys(_ settings: PresentationThemeSettings) -> (theme: Int32, automaticTheme: Int32) {
    let keys = EnginePreferencesEntry(settings)!.get(LegacyKeys.self)!
    return (builtinRawValue(keys.t), builtinRawValue(keys.automaticThemeSwitchSetting.theme))
}

final class PresentationThemeSettingsStorageTests: XCTestCase {
    func testBubblesOnBytesOfDefaultSettingsAreMasters() {
        XCTAssertEqual(storedBytes(PresentationThemeSettings.defaultSettings), masterDefaultBytes)
    }

    func testBubblesOnBytesOfTypicalSettingsAreMasters() {
        XCTAssertEqual(storedBytes(typicalSettings), masterTypicalBytes)
    }

    func testOlderBuildsNeverReadNeutralInTheirKeys() {
        let builtins: [PresentationBuiltinThemeReference] = [.dayClassic, .night, .day, .nightAccent, .neutral, .neutralNight]
        let slots: [PresentationThemeReference?] = [nil] + builtins.map { .builtin($0) }
        for bubbleMode in [true, false] {
            for theme in builtins { for automatic in builtins { for slot in slots { for automaticSlot in slots {
                var settings = PresentationThemeSettings.defaultSettings
                // Also what a writer that missed the accessors stores.
                settings.theme = .builtin(theme)
                settings.automaticThemeSwitchSetting.theme = .builtin(automatic)
                settings.chatBubbleSettings.bubbleMode = bubbleMode
                settings.chatBubbleSettings.bubblelessTheme = slot
                settings.chatBubbleSettings.bubblelessAutomaticTheme = automaticSlot
                settings.themeSpecificAccentColors[PresentationThemeReference.builtin(.neutral).index] = PresentationThemeAccentColor(baseColor: .red)
                let keys = legacyKeys(settings)
                XCTAssertTrue([0, 1, 2, 3].contains(keys.theme), "\(keys)")
                XCTAssertTrue([0, 1, 2, 3].contains(keys.automaticTheme), "\(keys)")
            } } } }
        }
    }

    func testBubbleModeOffAndTheChoicesSurviveARoundTrip() {
        var settings = typicalSettings
        settings.chatBubbleSettings.bubbleMode = false
        settings.chatBubbleSettings.bubblelessTheme = .builtin(.neutralNight)
        settings.chatBubbleSettings.bubblelessAutomaticTheme = .local(PresentationLocalTheme(title: "t", resource: LocalFileMediaResource(fileId: 42), resolvedWallpaper: nil))
        let decoded = EnginePreferencesEntry(settings)!.get(PresentationThemeSettings.self)!
        XCTAssertFalse(decoded.chatBubbleSettings.bubbleMode)
        XCTAssertEqual(decoded.chatBubbleSettings.bubblelessTheme, .builtin(.neutralNight))
        XCTAssertEqual(decoded.chatBubbleSettings.bubblelessAutomaticTheme, settings.chatBubbleSettings.bubblelessAutomaticTheme)
        XCTAssertTrue(decoded == settings)
    }

    // New York, picked in Text Size, is stored only when picked, so the bytes above stay master's without it.
    func testNewYorkSurvivesARoundTrip() {
        var settings = typicalSettings
        settings.chatBubbleSettings.serifMessageFont = true
        let decoded = EnginePreferencesEntry(settings)!.get(PresentationThemeSettings.self)!
        XCTAssertTrue(decoded.chatBubbleSettings.serifMessageFont)
        XCTAssertTrue(decoded == settings)
        XCTAssertNotEqual(storedBytes(settings), masterTypicalBytes)
    }

    func testMastersBytesDecodeWithoutNewYork() {
        let decoded = EnginePreferencesEntry(data: Data(base64Encoded: masterTypicalBytes)!).get(PresentationThemeSettings.self)!
        XCTAssertFalse(decoded.chatBubbleSettings.serifMessageFont)
    }

    func testMastersBytesDecodeWithBubbles() {
        let decoded = EnginePreferencesEntry(data: Data(base64Encoded: masterTypicalBytes)!).get(PresentationThemeSettings.self)!
        XCTAssertTrue(decoded.chatBubbleSettings.bubbleMode)
        XCTAssertNil(decoded.chatBubbleSettings.bubblelessTheme)
        XCTAssertNil(decoded.chatBubbleSettings.bubblelessAutomaticTheme)
        XCTAssertTrue(decoded == typicalSettings)
    }

    // A theme picked without bubbles keeps its file through cache cleanup, as the bubbles theme does. The auto-night
    // slot is left out, as master leaves out the auto-night theme.
    func testRelatedResourcesIncludeTheBubblelessTheme() {
        let resource = LocalFileMediaResource(fileId: 42)
        var settings = PresentationThemeSettings.defaultSettings
        settings.chatBubbleSettings.bubbleMode = false
        settings.chatBubbleSettings.bubblelessTheme = .local(PresentationLocalTheme(title: "t", resource: resource, resolvedWallpaper: nil))
        XCTAssertTrue(settings.relatedResources.contains(resource.id))
    }
}
