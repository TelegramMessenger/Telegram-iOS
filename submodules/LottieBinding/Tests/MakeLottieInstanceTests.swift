import XCTest
import LottieBinding
import TLottieBinding

final class MakeLottieInstanceTests: XCTestCase {
    private func make(_ data: Data) -> LottieInstance? {
        return makeLottieInstance(
            data: data,
            fitzModifier: .none,
            colorReplacements: nil
        )
    }

    func testAcceptsAnOrdinaryAnimation() {
        XCTAssertNotNil(self.make(LottieBindingTestFixtures.solidRed()))
    }

    func testRejectsOversizedDimensions() {
        let data = LottieBindingTestFixtures.solidRed(width: 2000, height: 2000)
        XCTAssertNil(self.make(data), "accepted 2000x2000")
    }

    func testRejectsLongDuration() {
        // 60 fps * 600 frames == 10 seconds, past the 9-second limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 60, frameCount: 600)
        XCTAssertNil(self.make(data), "accepted a 10s animation")
    }

    func testRejectsExcessiveFrameRate() {
        let data = LottieBindingTestFixtures.solidRed(frameRate: 400, frameCount: 400)
        XCTAssertNil(self.make(data), "accepted 400 fps")
    }

    func testMetadataMatchesTheFixture() {
        guard let instance = self.make(LottieBindingTestFixtures.solidRed()) else {
            XCTFail("rejected the fixture")
            return
        }
        XCTAssertEqual(instance.frameCount, 60)
        XCTAssertEqual(instance.frameRate, 60)
        XCTAssertEqual(instance.dimensions, CGSize(width: 32, height: 32))
        XCTAssertTrue(instance is TLottieAnimation)
    }

    // MARK: - Negative controls
    //
    // The three rejection tests above assert nil, which would pass vacuously if
    // the fixture simply failed to parse at that size / rate / length. These
    // pin the other side of each boundary, so a nil above means "the limit
    // rejected it" rather than "nothing was ever constructed".

    func testAcceptsDimensionsJustUnderTheLimit() {
        let data = LottieBindingTestFixtures.solidRed(width: 1536, height: 1536)
        XCTAssertNotNil(self.make(data), "rejected 1536x1536, which is exactly the limit")
    }

    func testAcceptsDurationJustUnderTheLimit() {
        // 60 fps * 480 frames == 8 seconds, inside the 9-second limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 60, frameCount: 480)
        XCTAssertNotNil(self.make(data), "rejected an 8s animation")
    }

    func testAcceptsFrameRateAtTheLimit() {
        // The check is `frameRate > 360`, so 360 itself must be accepted. Kept
        // short enough to stay inside the duration limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 360, frameCount: 360)
        XCTAssertNotNil(self.make(data), "rejected 360 fps")
    }

    /// The live call sites pass `nil`, `[:]`, and a `[UInt32: UInt32]?`
    /// (ManagedAnimationItem.replaceColors). All three must reach the factory's
    /// NSDictionary? parameter; this pins which of them need an explicit bridge,
    /// so the wide migration does not discover it one file at a time.
    func testColorReplacementArgumentShapesFromLiveCallSites() {
        let data = LottieBindingTestFixtures.solidRed()

        XCTAssertNotNil(makeLottieInstance(
            data: data, fitzModifier: .none, colorReplacements: [:]))

        let replaceColors: [UInt32: UInt32]? = [0xFFFF0000: 0xFF00FF00]
        XCTAssertNotNil(makeLottieInstance(
            data: data, fitzModifier: .none, colorReplacements: replaceColors))
    }
}

