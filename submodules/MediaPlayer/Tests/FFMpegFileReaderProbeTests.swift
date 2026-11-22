import XCTest
import CoreMedia
@testable import UniversalMediaPlayer

// An HLS part's reader probes only its own stream. Fixtures/fragment720.mp4 is one fMP4 fragment from the ffmpeg CLI
// (testsrc2 1280x720 at 25 fps for 1 s, x264 High with B-frames, a 440 Hz AAC tone). Probing every stream, an audio
// reader decodes H.264 frames in software only to describe a stream it never reads. Made with
//   ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=25 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 1 \
//     -c:v libx264 -profile:v high -bf 3 -g 25 -crf 38 -pix_fmt yuv420p -c:a aac -b:a 32k \
//     -movflags +empty_moov+default_base_moof -frag_duration 100000000 fragment720.mp4
final class FFMpegFileReaderProbeTests: XCTestCase {
    // CPU time of the calling thread, which the probe runs on: FFmpeg probes with one decoder thread
    // (avformat_find_stream_info sets "threads" to 1), so a busy machine does not decide the comparison.
    private func threadCPUSeconds() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
    }

    private func open(mediaType: FFMpegFileReader.SelectedStream.MediaType, probeOnlySelectedMediaType: Bool) throws -> (seconds: Double, frames: Int) {
        let path = try XCTUnwrap(Bundle(for: FFMpegFileReaderProbeTests.self).path(forResource: "fragment720", ofType: "mp4"))
        let start = self.threadCPUSeconds()
        let reader = try XCTUnwrap(FFMpegFileReader(
            source: .file(path),
            useHardwareAcceleration: false,
            selectedStream: .mediaType(mediaType),
            seek: nil,
            maxReadablePts: nil,
            ignoreEditList: false,
            probeOnlySelectedMediaType: probeOnlySelectedMediaType
        ))
        let seconds = self.threadCPUSeconds() - start
        var frames = 0
        while case .frame = reader.readFrame() {
            frames += 1
        }
        return (seconds, frames)
    }

    // Best of five.
    private func openTime(mediaType: FFMpegFileReader.SelectedStream.MediaType, probeOnlySelectedMediaType: Bool) throws -> Double {
        var best = Double.infinity
        for _ in 0 ..< 5 {
            best = min(best, try self.open(mediaType: mediaType, probeOnlySelectedMediaType: probeOnlySelectedMediaType).seconds)
        }
        return best
    }

    func testAnAudioReaderThatProbesOnlyItsStreamOpensFasterAndReadsTheSameFrames() throws {
        let all = try self.open(mediaType: .audio, probeOnlySelectedMediaType: false)
        let only = try self.open(mediaType: .audio, probeOnlySelectedMediaType: true)
        XCTAssertGreaterThan(all.frames, 0)
        XCTAssertEqual(only.frames, all.frames)

        let allTime = try self.openTime(mediaType: .audio, probeOnlySelectedMediaType: false)
        let onlyTime = try self.openTime(mediaType: .audio, probeOnlySelectedMediaType: true)
        // Measured 0.39 (1.6 ms against 4.1 ms of CPU); about 1.0 when the reader probes every stream.
        XCTAssertLessThan(onlyTime, allTime * 0.75, "probing only audio: \(onlyTime) s, every stream: \(allTime) s")
    }

    func testAVideoReaderThatProbesOnlyItsStreamReadsTheSameFrames() throws {
        let all = try self.open(mediaType: .video, probeOnlySelectedMediaType: false)
        let only = try self.open(mediaType: .video, probeOnlySelectedMediaType: true)
        XCTAssertEqual(all.frames, 25)
        XCTAssertEqual(only.frames, all.frames)
    }
}
