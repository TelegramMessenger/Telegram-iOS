import Foundation
import XCTest
@testable import HLSPlayback

// The lab's link: parts of 128 KB, at most 6 in flight per level and 12 in all, each arriving one round trip after it
// was sent or when the link is done with the parts before it, at the link's bandwidth.
final class HLSSimulatedLinkTests: XCTestCase {
    // 8 Mbit/s and 0.1 s: a 131 072-byte part takes 0.131072 s on the link.
    private let partTime = 0.131072

    private func environment(steps: [SimulatedLink.Step] = [SimulatedLink.Step(start: 0.0, bitsPerSecond: 8_000_000.0)]) -> SimulatedEnvironment {
        let environment = SimulatedEnvironment()
        environment.link = SimulatedLink(steps: steps, roundTrip: 0.1)
        return environment
    }

    private func startLoad(_ environment: SimulatedEnvironment, level: Int = 0, bytes: Int64, offset: Int64 = 0, progress: @escaping (Int64) -> Void = { _ in }) -> HLSCancellable {
        return environment.load(level: level, range: offset ..< (offset + bytes), priority: .playback, progress: progress, completion: { _ in })
    }

    func testOnePartArrivesAfterTheRoundTripAndItsTransfer() {
        let environment = self.environment()
        let _ = self.startLoad(environment, bytes: 131_072)
        environment.advance(by: 5.0)
        XCTAssertTrue(environment.loads[0].completed)
        XCTAssertEqual(environment.loads[0].completionTime, 0.1 + self.partTime, accuracy: 1e-9)
        XCTAssertEqual(environment.loads[0].networkBytes, 131_072)
    }

    func testPartsOfOneLoadFollowEachOther() {
        let environment = self.environment()
        var progress: [Int64] = []
        let _ = self.startLoad(environment, bytes: 524_288, progress: { progress.append($0) })
        environment.advance(by: 5.0)
        XCTAssertEqual(progress, [131_072, 262_144, 393_216])
        XCTAssertEqual(environment.loads[0].completionTime, 0.1 + 4.0 * self.partTime, accuracy: 1e-9)
    }

    func testAFileHasAtMostSixPartsInFlight() {
        let environment = self.environment()
        let _ = self.startLoad(environment, bytes: 1_048_576)
        environment.advance(by: 0.2)
        XCTAssertEqual(environment.link?.partsInFlight(level: 0), 6)
        environment.advance(by: 5.0)
        XCTAssertEqual(environment.loads[0].completionTime, 0.1 + 8.0 * self.partTime, accuracy: 1e-9)
    }

    func testTwoLevelsShareOneLink() {
        let environment = self.environment()
        let _ = self.startLoad(environment, level: 0, bytes: 131_072)
        let _ = self.startLoad(environment, level: 1, bytes: 131_072)
        environment.advance(by: 5.0)
        XCTAssertEqual(environment.loads[0].completionTime, 0.1 + self.partTime, accuracy: 1e-9)
        XCTAssertEqual(environment.loads[1].completionTime, 0.1 + 2.0 * self.partTime, accuracy: 1e-9)
    }

    func testTheBandwidthFollowsItsSteps() {
        let environment = self.environment(steps: [
            SimulatedLink.Step(start: 0.0, bitsPerSecond: 8_000_000.0),
            SimulatedLink.Step(start: 1.0, bitsPerSecond: 4_000_000.0)
        ])
        environment.advance(by: 2.0)
        let _ = self.startLoad(environment, bytes: 131_072)
        environment.advance(by: 5.0)
        XCTAssertEqual(environment.loads[0].completionTime, 2.0 + 0.1 + 2.0 * self.partTime, accuracy: 1e-9)
    }

    func testCancellingDropsQueuedParts() {
        let environment = self.environment()
        let first = self.startLoad(environment, bytes: 10 * 131_072)
        environment.advance(by: 0.15)
        first.cancel()
        XCTAssertTrue(environment.loads[0].cancelled)
        environment.advance(by: 0.05)
        let _ = self.startLoad(environment, level: 0, bytes: 131_072, offset: 20 * 131_072)
        environment.advance(by: 5.0)
        // Nothing of the cancelled load lands: its in-flight parts only hold the link.
        XCTAssertEqual(environment.loads[0].networkBytes, 0)
        XCTAssertFalse(environment.isOnDisk(level: 0, range: 0 ..< 131_072))
        XCTAssertEqual(environment.loads[1].completionTime, 0.1 + 7.0 * self.partTime, accuracy: 1e-9)
    }
}
