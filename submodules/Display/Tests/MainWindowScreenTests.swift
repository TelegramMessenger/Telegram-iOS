import XCTest
import UIKit
@testable import Display

/// `mainWindowScreenBounds` answers for the screen the app's window is on, and falls back to `UIScreen.main` when
/// there is no window (extensions, tests, before launch). The registered-window path needs a real window, which an
/// `ios_unit_test` process traps on at exit; it is verified in the app (unfolded iPhone Duo: 669x951, not 466x678).
final class MainWindowScreenTests: XCTestCase {
    func test_noWindowRegistered_fallsBackToTheMainScreen() {
        XCTAssertEqual(mainWindowScreenBounds, UIScreen.main.bounds)
    }
}
