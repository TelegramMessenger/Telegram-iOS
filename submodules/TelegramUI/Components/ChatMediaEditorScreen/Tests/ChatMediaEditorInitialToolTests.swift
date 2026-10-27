import XCTest
import LegacyMediaPickerUI
@testable import ChatMediaEditorScreen

final class ChatMediaEditorInitialToolTests: XCTestCase {
    func testLegacyModeMapping() {
        XCTAssertEqual(chatMediaEditorInitialTool(.plain), ChatMediaEditorInitialTool.none)
        XCTAssertEqual(chatMediaEditorInitialTool(.draw), .paint)
        XCTAssertEqual(chatMediaEditorInitialTool(.adjustments), .tools)
    }

    func testCaptionModeOpensCaption() {
        XCTAssertEqual(chatMediaEditorInitialTool(.caption), .caption)
    }

    func testDefaultModeOpensNone() {
        XCTAssertEqual(chatMediaEditorInitialTool(.default), ChatMediaEditorInitialTool.none)
    }
}
