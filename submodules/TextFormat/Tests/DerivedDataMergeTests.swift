import XCTest
import TelegramCore
@testable import TextFormat

/// A message's derived data holds independent keys (`"code"` syntax highlighting, `"mps"` playback position,
/// `"widget"` widget sources): a writer of one key must keep the others.
final class DerivedDataMergeTests: XCTestCase {
    private struct Value: Codable, Equatable {
        let v: String
    }

    private func entry(_ v: String) -> EngineCodableEntry {
        return EngineCodableEntry(Value(v: v))!
    }

    func testSettingAKeyKeepsTheOthers() {
        let current = ["mps": self.entry("12.5"), "widget": self.entry("w")]
        let updated = derivedDataSetting(current, key: "code", to: self.entry("c"))
        XCTAssertEqual(Set(updated.keys), ["mps", "widget", "code"])
        XCTAssertEqual(updated["mps"]?.get(Value.self), Value(v: "12.5"))
        XCTAssertEqual(updated["widget"]?.get(Value.self), Value(v: "w"))
        XCTAssertEqual(updated["code"]?.get(Value.self), Value(v: "c"))
    }

    func testReplacingAKeyKeepsTheOthers() {
        let current = ["mps": self.entry("12.5"), "code": self.entry("old")]
        let updated = derivedDataSetting(current, key: "code", to: self.entry("new"))
        XCTAssertEqual(Set(updated.keys), ["mps", "code"])
        XCTAssertEqual(updated["code"]?.get(Value.self), Value(v: "new"))
    }

    func testRemovingAKeyKeepsTheOthers() {
        let current = ["mps": self.entry("12.5"), "code": self.entry("c")]
        let updated = derivedDataSetting(current, key: "code", to: nil)
        XCTAssertEqual(Set(updated.keys), ["mps"])
    }
}
