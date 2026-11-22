import XCTest
@testable import RichTextEditorCore

final class ScaffoldTests: XCTestCase {
    func test_moduleVersionIsPresent() {
        XCTAssertEqual(RichTextEditorCore.version, "0.0.1")
    }
}
