import XCTest
import ScenariosLegacy
import ScenariosV2

final class ReleaseOrderTests: XCTestCase {
    func testReleaseOrderMatchesLegacy() {
        let legacy = ScenariosLegacy.releaseOrderProbe()
        let v2 = ScenariosV2.releaseOrderProbe()
        XCTAssertEqual(Set(legacy.keys), Set(v2.keys))
        for key in legacy.keys.sorted() {
            let l = legacy[key]!
            let r = v2[key] ?? []
            if ProcessInfo.processInfo.environment["SSK_PRINT_PROBE"] != nil {
                print("== \(key)\n   legacy: \(l.joined(separator: " | "))\n   v2:     \(r.joined(separator: " | "))")
            }
            XCTAssertEqual(l, r, "release order differs for \(key)\nlegacy: \(l)\nv2:     \(r)")
        }
    }
}
