import XCTest
@testable import HLSPlayback

final class HLSPartTimingTests: XCTestCase {
    // Measured on a real stream: the audio stops 0.33 s into segment 14 while the video runs on to 75.0. The part must
    // reach 75.0, or the rest of the segment reads as a hole the player waits at forever.
    func testAPartRunsToTheLaterTrackEndWhenTheAudioStopsEarly() {
        let range = HLSPartTiming.range(audio: (start: 70.031383, duration: 0.334853), video: (start: 70.0, duration: 5.0))
        XCTAssertEqual(range?.start ?? 0.0, 70.031383, accuracy: 1e-9)
        XCTAssertEqual(range?.end ?? 0.0, 75.0, accuracy: 1e-9)
    }
    
    // The audio start is kept: audio frames run on from part to part, so consecutive parts meet without overlapping.
    func testThePartStartsWithItsAudio() {
        let range = HLSPartTiming.range(audio: (start: 65.039093, duration: 4.99229), video: (start: 65.0, duration: 5.0))
        XCTAssertEqual(range?.start ?? 0.0, 65.039093, accuracy: 1e-9)
        XCTAssertEqual(range?.end ?? 0.0, 70.031383, accuracy: 1e-6)
    }
    
    func testAVideoOnlyPartUsesTheVideo() {
        let range = HLSPartTiming.range(audio: nil, video: (start: 75.0, duration: 0.95))
        XCTAssertEqual(range?.start ?? 0.0, 75.0, accuracy: 1e-9)
        XCTAssertEqual(range?.end ?? 0.0, 75.95, accuracy: 1e-9)
    }
    
    // A track with nothing in it does not decide the part.
    func testAnEmptyAudioTrackIsIgnored() {
        let range = HLSPartTiming.range(audio: (start: 80.0, duration: 0.0), video: (start: 75.0, duration: 0.95))
        XCTAssertEqual(range?.start ?? 0.0, 75.0, accuracy: 1e-9)
        XCTAssertEqual(range?.end ?? 0.0, 75.95, accuracy: 1e-9)
    }
    
    func testAnAudioOnlyPartUsesTheAudio() {
        let range = HLSPartTiming.range(audio: (start: 10.0, duration: 5.0), video: nil)
        XCTAssertEqual(range?.start ?? 0.0, 10.0, accuracy: 1e-9)
        XCTAssertEqual(range?.end ?? 0.0, 15.0, accuracy: 1e-9)
    }
    
    func testNoTrackWithMediaMeansNoPart() {
        XCTAssertNil(HLSPartTiming.range(audio: (start: 0.0, duration: 0.0), video: nil))
        XCTAssertNil(HLSPartTiming.range(audio: nil, video: nil))
    }
}
