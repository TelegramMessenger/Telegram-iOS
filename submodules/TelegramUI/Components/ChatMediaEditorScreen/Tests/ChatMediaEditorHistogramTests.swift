import XCTest
@testable import ChatMediaEditorScreen

final class ChatMediaEditorHistogramTests: XCTestCase {
    func testPhotoToolsShowCurvesHistogram() {
        XCTAssertTrue(chatMediaEditorHasCurvesHistogram(.item(isVideo: false)))
    }

    func testVideoToolsHaveNoCurvesHistogram() {
        XCTAssertFalse(chatMediaEditorHasCurvesHistogram(.item(isVideo: true)))
    }

    func testWallpaperToolsShowCurvesHistogram() {
        XCTAssertTrue(chatMediaEditorHasCurvesHistogram(.wallpaper))
    }
}
