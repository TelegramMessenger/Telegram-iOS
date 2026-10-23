import XCTest
import CoreMedia
@testable import UniversalMediaPlayer

// A part's video reader opened for a seek target inside the part. Fixtures/fragment.mp4 is one fMP4 fragment like an
// HLS part, generated with the ffmpeg CLI (testsrc2 64x64 at 25 fps, x264 High with 3 B-frames, a keyframe every
// second at 0.08, 1.08 and 2.08 s, a 440 Hz AAC tone): 75 frames, 30 of them non-reference. Made with
//   ffmpeg -f lavfi -i testsrc2=size=64x64:rate=25 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 3 \
//     -c:v libx264 -profile:v high -bf 3 -g 25 -keyint_min 25 -sc_threshold 0 -pix_fmt yuv420p -c:a aac -b:a 32k \
//     -movflags +empty_moov+default_base_moof -frag_duration 100000000 fragment.mp4
final class FFMpegFileReaderStartTests: XCTestCase {
    private func videoFrameTimes(_ name: String = "fragment", startAt: Double?) throws -> [Double] {
        let path = try XCTUnwrap(Bundle(for: FFMpegFileReaderStartTests.self).path(forResource: name, ofType: "mp4"))
        let reader = try XCTUnwrap(FFMpegFileReader(
            source: .file(path),
            useHardwareAcceleration: false,
            selectedStream: .mediaType(.video),
            seek: startAt.map { .direct(position: $0) },
            maxReadablePts: nil,
            ignoreEditList: false,
            skipNonReferenceFramesBefore: startAt
        ))
        var times: [Double] = []
        while case let .frame(frame) = reader.readFrame() {
            times.append(CMSampleBufferGetPresentationTimeStamp(frame.sampleBuffer).seconds)
        }
        return times.sorted()
    }

    func testAReaderStartsAtTheKeyframeBeforeItsTarget() throws {
        let all = try self.videoFrameTimes(startAt: nil)
        XCTAssertEqual(all.count, 75)
        let times = try self.videoFrameTimes(startAt: 1.5)

        XCTAssertGreaterThanOrEqual(times.first ?? 0.0, 1.08 - 0.001)
        XCTAssertEqual(times.filter { $0 >= 1.5 - 0.001 }, all.filter { $0 >= 1.5 - 0.001 })
    }

    // Frames before the target are only decoded to be hidden, and a non-reference one feeds no later frame.
    func testNonReferenceFramesBeforeTheTargetAreNotDecoded() throws {
        let all = try self.videoFrameTimes(startAt: nil)
        let times = try self.videoFrameTimes(startAt: 1.5)
        let hiddenWithoutSkipping = all.filter { $0 >= 1.08 - 0.001 && $0 < 1.5 - 0.001 }
        let hidden = times.filter { $0 < 1.5 - 0.001 }

        XCTAssertLessThan(hidden.count, hiddenWithoutSkipping.count)
        XCTAssertEqual(times.filter { $0 >= 1.5 - 0.001 }, all.filter { $0 >= 1.5 - 0.001 })
    }

    // The seek searches decode times, so a target in the decoder delay before a keyframe (at or after its decode time,
    // before its presentation time) lands on that keyframe, after frames of the previous group that present at or
    // after the target. Fixtures/fragment-videoedit.mp4 (see HLSFragmentTimingParityTests) carries an edit list on its
    // video track, as Telegram's segments do.
    func testNoFrameAtOrAfterTheTargetIsLostWhereverTheTargetFalls() throws {
        for name in ["fragment", "fragment-videoedit"] {
            let all = try self.videoFrameTimes(name, startAt: nil)
            let last = try XCTUnwrap(all.last)
            for step in 1 ..< Int(last * 50.0) {
                let target = Double(step) / 50.0
                let times = try self.videoFrameTimes(name, startAt: target)
                XCTAssertEqual(times.filter { $0 >= target - 1e-6 }, all.filter { $0 >= target - 1e-6 }, "\(name) at \(target)")
            }
        }
    }
}
