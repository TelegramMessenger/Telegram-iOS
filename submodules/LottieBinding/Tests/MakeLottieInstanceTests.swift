import XCTest
import LottieSettings
import LottieBinding
import RLottieBinding
import TLottieBinding

final class MakeLottieInstanceTests: XCTestCase {
    private let backends: [LottieBackend] = [.rlottie, .tlottie]

    private func make(_ data: Data, _ backend: LottieBackend) -> LottieInstance? {
        return makeLottieInstance(
            data: data,
            fitzModifier: .none,
            colorReplacements: nil,
            cacheKey: "",
            settings: LottieRenderingSettings(backend: backend)
        )
    }

    func testAcceptsAnOrdinaryAnimationOnBothBackends() {
        for backend in self.backends {
            XCTAssertNotNil(self.make(LottieBindingTestFixtures.solidRed(), backend),
                            "\(backend) rejected an ordinary animation")
        }
    }

    func testRejectsOversizedDimensionsOnBothBackends() {
        let data = LottieBindingTestFixtures.solidRed(width: 2000, height: 2000)
        for backend in self.backends {
            XCTAssertNil(self.make(data, backend), "\(backend) accepted 2000x2000")
        }
    }

    func testRejectsLongDurationOnBothBackends() {
        // 60 fps * 600 frames == 10 seconds, past the 9-second limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 60, frameCount: 600)
        for backend in self.backends {
            XCTAssertNil(self.make(data, backend), "\(backend) accepted a 10s animation")
        }
    }

    func testRejectsExcessiveFrameRateOnBothBackends() {
        let data = LottieBindingTestFixtures.solidRed(frameRate: 400, frameCount: 400)
        for backend in self.backends {
            XCTAssertNil(self.make(data, backend), "\(backend) accepted 400 fps")
        }
    }

    func testBackendsAgreeOnMetadata() {
        let data = LottieBindingTestFixtures.solidRed()
        guard let r = self.make(data, .rlottie), let t = self.make(data, .tlottie) else {
            XCTFail("one backend rejected the fixture")
            return
        }
        XCTAssertEqual(r.frameCount, t.frameCount)
        XCTAssertEqual(r.frameRate, t.frameRate)
        XCTAssertEqual(r.dimensions, t.dimensions)
    }

    func testSettingsSelectTheBackend() {
        let data = LottieBindingTestFixtures.solidRed()
        XCTAssertTrue(self.make(data, .rlottie) is RLottieInstance)
        XCTAssertTrue(self.make(data, .tlottie) is TLottieAnimation)
    }

    // MARK: - Negative controls
    //
    // The three rejection tests above assert nil, which would pass vacuously if
    // the fixture simply failed to parse at that size / rate / length. These
    // pin the other side of each boundary, so a nil above means "the limit
    // rejected it" rather than "nothing was ever constructed".

    func testAcceptsDimensionsJustUnderTheLimit() {
        let data = LottieBindingTestFixtures.solidRed(width: 1536, height: 1536)
        for backend in self.backends {
            XCTAssertNotNil(self.make(data, backend),
                            "\(backend) rejected 1536x1536, which is exactly the limit")
        }
    }

    func testAcceptsDurationJustUnderTheLimit() {
        // 60 fps * 480 frames == 8 seconds, inside the 9-second limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 60, frameCount: 480)
        for backend in self.backends {
            XCTAssertNotNil(self.make(data, backend), "\(backend) rejected an 8s animation")
        }
    }

    func testAcceptsFrameRateAtTheLimit() {
        // The check is `frameRate > 360`, so 360 itself must be accepted. Kept
        // short enough to stay inside the duration limit.
        let data = LottieBindingTestFixtures.solidRed(frameRate: 360, frameCount: 360)
        for backend in self.backends {
            XCTAssertNotNil(self.make(data, backend), "\(backend) rejected 360 fps")
        }
    }

    /// The live call sites pass `nil`, `[:]`, and a `[UInt32: UInt32]?`
    /// (ManagedAnimationItem.replaceColors). All three must reach the factory's
    /// NSDictionary? parameter; this pins which of them need an explicit bridge,
    /// so the wide migration does not discover it one file at a time.
    func testColorReplacementArgumentShapesFromLiveCallSites() {
        let data = LottieBindingTestFixtures.solidRed()

        XCTAssertNotNil(makeLottieInstance(
            data: data, fitzModifier: .none, colorReplacements: [:],
            cacheKey: "", settings: .noAccountFallback))

        let replaceColors: [UInt32: UInt32]? = [0xFFFF0000: 0xFF00FF00]
        XCTAssertNotNil(makeLottieInstance(
            data: data, fitzModifier: .none, colorReplacements: replaceColors,
            cacheKey: "", settings: .noAccountFallback))
    }
}

