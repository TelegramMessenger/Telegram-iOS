import XCTest
import MediaEditor
import ChatMediaEditorScreen

final class ChatMediaEditorVideoPresetTests: XCTestCase {
    func testAbsentPreferenceIsCompressedMedium() {
        XCTAssertEqual(chatMediaEditorVideoQualityPreset(storedLegacyPreset: nil), .compressedMedium)
    }

    func testStoredPreferenceIsMapped() {
        XCTAssertEqual(chatMediaEditorVideoQualityPreset(storedLegacyPreset: 4), .compressedHigh)
    }
}
