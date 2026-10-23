import XCTest
import CoreMedia
import HLSPlayback
@testable import UniversalMediaPlayer

// HLSFragmentTiming reads an HLS part's timing from its boxes instead of FFmpeg's probe (`extractFFMpegMediaInfo`),
// and must give what the probe gives. The fixtures come from the ffmpeg CLI: fragment and fragment720 (no edit lists),
// fragment-videoedit (an edit list on the video track only, as Telegram's segments have), fragment-edit (edit lists on
// both tracks, the audio one marking 1024 samples of AAC-LC priming, which FFmpeg skips). fragment-edit was made with
//   ffmpeg -f lavfi -i testsrc2=size=64x64:rate=25 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 2 \
//     -c:v libx264 -bf 2 -g 25 -c:a aac -b:a 32k -movflags +empty_moov+delay_moov+default_base_moof \
//     -frag_duration 100000000 fragment-edit.mp4
// and fragment-videoedit is fragment-edit with the sound track's edts box removed (its trak and moov sizes reduced by
// that box's; the fragment's data offsets are relative to its moof).
final class HLSFragmentTimingParityTests: XCTestCase {
    private func path(_ name: String) throws -> String {
        return try XCTUnwrap(Bundle(for: HLSFragmentTimingParityTests.self).path(forResource: name, ofType: "mp4"), name)
    }

    private func probe(_ path: String) throws -> HLSFragmentTiming.Info {
        let info = try XCTUnwrap(extractFFMpegMediaInfo(path: path))
        return HLSFragmentTiming.Info(
            audio: info.audio.map { HLSFragmentTiming.Track(start: $0.startTime.seconds, duration: $0.duration.seconds) },
            video: info.video.map { HLSFragmentTiming.Track(start: $0.startTime.seconds, duration: $0.duration.seconds) },
            videoCodecName: info.video?.codecName
        )
    }

    private func assertEqual(_ track: HLSFragmentTiming.Track?, _ expected: HLSFragmentTiming.Track?, _ label: String) {
        XCTAssertEqual(track == nil, expected == nil, label)
        if let track, let expected {
            XCTAssertEqual(track.start, expected.start, accuracy: 1e-6, label)
            XCTAssertEqual(track.duration, expected.duration, accuracy: 1e-6, label)
        }
    }

    func testTheBoxesGiveTheProbesTiming() throws {
        for name in ["fragment", "fragment720", "fragment-videoedit", "fragment-edit"] {
            let path = try self.path(name)
            let parsed = try XCTUnwrap(HLSFragmentTiming.parse(try Data(contentsOf: URL(fileURLWithPath: path))), name)
            let expected = try self.probe(path)
            self.assertEqual(parsed.video, expected.video, "\(name) video")
            self.assertEqual(parsed.audio, expected.audio, "\(name) audio")
            XCTAssertEqual(parsed.videoCodecName, expected.videoCodecName, name)
        }
    }
}
