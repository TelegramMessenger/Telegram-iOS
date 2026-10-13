import XCTest
@testable import CoreListDemo

final class SeededRNGTests: XCTestCase {
    func testSameSeed_producesSameSequence() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeed_producesDifferentSequence() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testIntInRange_staysInBounds() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<1000 {
            let v = rng.int(in: 0..<10)
            XCTAssertTrue(v >= 0 && v < 10)
        }
    }
}
