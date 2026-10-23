import XCTest
import RangeSet
@testable import TelegramCore

// How FetchV2 picks the next part of a file among the ranges its readers ask for at different priorities
// (`MediaBoxFetchPriority`: 0 default, 1 elevated, 2 maximum).
final class FetchV2PrioritySelectionTests: XCTestCase {
    private let kb: Int64 = 1024

    private func takeAll(_ ranges: [RangeSet<Int64>]) -> [Range<Int64>] {
        var ranges = ranges
        var taken: [Range<Int64>] = []
        while let part = fetchV2TakeNextPart(ranges: &ranges, partSize: 128 * kb, minPartSize: 4 * kb, maxPartSize: 1024 * kb, alignment: 4 * kb, boundaryLimit: 1024 * kb) {
            taken.append(part.fetchRange)
            if taken.count > 100 {
                break
            }
        }
        return taken
    }

    func testARangeAskedForAtTwoPrioritiesIsOnlyInTheHigher() {
        let ranges = fetchV2PriorityRanges(required: [(0 ..< 1024 * kb, 0), (512 * kb ..< 1024 * kb, 1)], knownSize: nil, excluded: RangeSet<Int64>())

        XCTAssertEqual(ranges[1], RangeSet<Int64>(512 * kb ..< 1024 * kb))
        XCTAssertEqual(ranges[0], RangeSet<Int64>(0 ..< 512 * kb))
        XCTAssertTrue(ranges[2].isEmpty)
    }

    func testCompletedAndPendingBytesAndBytesPastTheEndAreNotNeeded() {
        var excluded = RangeSet<Int64>(0 ..< 128 * kb)
        excluded.formUnion(RangeSet<Int64>(256 * kb ..< 384 * kb))
        let ranges = fetchV2PriorityRanges(required: [(0 ..< 1024 * kb, 1)], knownSize: 512 * kb, excluded: excluded)

        var expected = RangeSet<Int64>(128 * kb ..< 256 * kb)
        expected.formUnion(RangeSet<Int64>(384 * kb ..< 512 * kb))
        XCTAssertEqual(ranges[1], expected)
    }

    // The playing video's range (elevated) is fetched before a preload of the same file (default), whatever came first.
    func testTheNextPartComesFromTheHighestPriority() {
        let ranges = fetchV2PriorityRanges(required: [(0 ..< 1024 * kb, 0), (2048 * kb ..< 2304 * kb, 1)], knownSize: nil, excluded: RangeSet<Int64>())
        let taken = self.takeAll(ranges)

        XCTAssertEqual(taken.prefix(2), [2048 * kb ..< 2176 * kb, 2176 * kb ..< 2304 * kb])
        XCTAssertEqual(taken.count, 10)
    }

    func testTakingEveryPartFetchesNoByteTwice() {
        let ranges = fetchV2PriorityRanges(required: [(0 ..< 1024 * kb, 0), (256 * kb ..< 768 * kb, 1), (512 * kb ..< 640 * kb, 2)], knownSize: nil, excluded: RangeSet<Int64>())
        let taken = self.takeAll(ranges)

        XCTAssertEqual(taken, [
            512 * kb ..< 640 * kb,
            256 * kb ..< 384 * kb, 384 * kb ..< 512 * kb, 640 * kb ..< 768 * kb,
            0 ..< 128 * kb, 128 * kb ..< 256 * kb, 768 * kb ..< 896 * kb, 896 * kb ..< 1024 * kb
        ])
    }
}
