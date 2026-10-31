import XCTest
@testable import MessageWidget

/// The vendored corpus (third-party/widget-sandbox/corpus at v0.5.0) is in the test bundle by folder.
final class WidgetCorpusTests: XCTestCase {
    func testTheCorpusIsInTheBundleByFolder() {
        let counts = Dictionary(uniqueKeysWithValues: WidgetCorpus.folders.map { ($0, WidgetCorpus.files(in: $0).count) })
        XCTAssertEqual(counts, ["attacks": 113, "bot-demos": 6, "common": 32, "compat": 19, "defaults": 6, "generated": 40, "gestures": 8, "htmlbubbles-ported": 116, "interactive": 5, "out-of-profile": 9, "resize": 3, "safe-area": 7, "showcase": 27])
        // generated/with-profile and without-profile share 21 file names: the folders must survive bundling.
        let generated = WidgetCorpus.files(in: "generated").map(\.path)
        XCTAssertEqual(generated.filter { $0.hasPrefix("generated/with-profile/") }.count, 20)
        XCTAssertEqual(generated.filter { $0.hasPrefix("generated/without-profile/") }.count, 20)
        XCTAssertTrue(WidgetCorpus.files(in: "htmlbubbles-ported").allSatisfy { !$0.source.isEmpty })
    }
}
