#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

final class UIKitScaffoldTests: XCTestCase {
    func test_versionPresent() {
        XCTAssertEqual(RichTextEditorUIKit.version, "0.0.1")
    }
}
#endif
