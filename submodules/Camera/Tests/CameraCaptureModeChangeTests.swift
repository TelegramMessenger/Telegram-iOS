import XCTest

final class CameraCaptureModeChangeTests: XCTestCase {
    func testOneShotClaimsOnce() {
        let oneShot = CameraOneShot()
        XCTAssertTrue(oneShot.claim())
        XCTAssertFalse(oneShot.claim())
        XCTAssertFalse(oneShot.claim())
    }

    func testOneShotClaimedOnceAcrossThreads() {
        let oneShot = CameraOneShot()
        let lock = NSLock()
        var claims = 0
        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            if oneShot.claim() {
                lock.lock()
                claims += 1
                lock.unlock()
            }
        }
        XCTAssertEqual(claims, 1)
    }

    func testCaptureModeChangeGeneration() {
        var generation = CameraCaptureModeChangeGeneration()
        let first = generation.next()
        XCTAssertTrue(generation.isCurrent(first))
        let second = generation.next()
        XCTAssertFalse(generation.isCurrent(first))
        XCTAssertTrue(generation.isCurrent(second))
    }

    func testCaptureModeChangeFallbackTimeout() {
        XCTAssertEqual(cameraCaptureModeChangeTimeout, 1.0)
    }
}
