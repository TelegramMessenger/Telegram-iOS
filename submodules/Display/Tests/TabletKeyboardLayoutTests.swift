import Foundation
import XCTest
@testable import Display

final class TabletKeyboardLayoutTests: XCTestCase {
    private let screenBottom: CGFloat = 820.0
    private let visibleFrame = CGRect(x: 0.0, y: 495.0, width: 1180.0, height: 325.0)

    func testForeignKeyboardClearsStaleInset() {
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: false, hasFocusedInput: false, endFrame: self.visibleFrame, screenBottom: self.screenBottom, isHiding: false), .clear)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: false, hasFocusedInput: false, endFrame: nil, screenBottom: nil, isHiding: true), .clear)
    }

    func testForeignKeyboardLeavesFocusedInputAlone() {
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: false, hasFocusedInput: true, endFrame: self.visibleFrame, screenBottom: self.screenBottom, isHiding: false), .ignore)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: false, hasFocusedInput: true, endFrame: nil, screenBottom: nil, isHiding: true), .ignore)
    }

    func testLocalKeyboardUsesItsFrame() {
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: true, hasFocusedInput: true, endFrame: self.visibleFrame, screenBottom: self.screenBottom, isHiding: false), .measureFrame)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: nil, hasFocusedInput: false, endFrame: self.visibleFrame, screenBottom: nil, isHiding: false), .measureFrame)
    }

    func testHideClearsInsetWithoutAnEndFrame() {
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: true, hasFocusedInput: true, endFrame: nil, screenBottom: nil, isHiding: true), .clear)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: nil, hasFocusedInput: false, endFrame: nil, screenBottom: nil, isHiding: true), .clear)
    }

    func testZeroHeightFrameAtScreenBottomClearsInset() {
        let hiddenFrame = CGRect(x: 0.0, y: self.screenBottom, width: 1180.0, height: 0.0)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: true, hasFocusedInput: true, endFrame: hiddenFrame, screenBottom: self.screenBottom, isHiding: false), .clear)
    }

    func testFrameChangeWithoutUsableGeometryLeavesInsetAlone() {
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: true, hasFocusedInput: true, endFrame: .zero, screenBottom: self.screenBottom, isHiding: false), .ignore)
        XCTAssertEqual(resolveTabletKeyboardLayoutUpdate(isLocal: true, hasFocusedInput: true, endFrame: nil, screenBottom: self.screenBottom, isHiding: false), .ignore)
    }
}
