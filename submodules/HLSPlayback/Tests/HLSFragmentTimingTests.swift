import Foundation
import XCTest
@testable import HLSPlayback

// Parts built box by box in the shape Telegram's HLS segments come in (an init with one plain edit list on the video
// track, one fragment), and in the shapes left to FFmpeg. The values FFmpeg's probe gives real parts are pinned in
// UniversalMediaPlayer's HLSFragmentTimingParityTests.
final class HLSFragmentTimingTests: XCTestCase {
    private struct TrackSpec {
        var trackId: UInt32
        var handler: String
        var sampleEntry: String
        var timescale: UInt32
        var edits: [(segmentDuration: UInt32, mediaTime: Int32)]
        var defaultDuration: UInt32
        var baseDecodeTime: UInt64
        var durations: [UInt32]?
        var compositionOffsets: [UInt32]?
        var sampleCount: Int
        // The trun's sample count when it is not the number of samples written.
        var declaredSampleCount: UInt32? = nil
        // Whether the trun carries a size per sample; without one, nothing per sample is stored.
        var sampleSizes = true
        // A version 1 edit list of one entry with this media time, in place of `edits`.
        var largeEditMediaTime: Int64? = nil
    }

    private func u32(_ value: UInt32) -> Data {
        return Data([UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
    }

    private func u64(_ value: UInt64) -> Data {
        return self.u32(UInt32(value >> 32)) + self.u32(UInt32(value & 0xffffffff))
    }

    private func box(_ type: String, _ body: Data) -> Data {
        return self.u32(UInt32(8 + body.count)) + Data(type.utf8) + body
    }

    private func fullBox(_ type: String, version: UInt8 = 0, flags: UInt32 = 0, _ body: Data) -> Data {
        return self.box(type, Data([version, UInt8((flags >> 16) & 0xff), UInt8((flags >> 8) & 0xff), UInt8(flags & 0xff)]) + body)
    }

    private func trak(_ spec: TrackSpec) -> Data {
        let tkhd = self.fullBox("tkhd", self.u32(0) + self.u32(0) + self.u32(spec.trackId) + Data(count: 68))
        let mdhd = self.fullBox("mdhd", self.u32(0) + self.u32(0) + self.u32(spec.timescale) + self.u32(0) + Data(count: 4))
        let hdlr = self.fullBox("hdlr", self.u32(0) + Data(spec.handler.utf8) + Data(count: 13))
        let stsd = self.fullBox("stsd", self.u32(1) + self.box(spec.sampleEntry, Data(count: 8)))
        let minf = self.box("minf", self.box("stbl", stsd))
        var trak = tkhd
        if let mediaTime = spec.largeEditMediaTime {
            trak += self.box("edts", self.fullBox("elst", version: 1, self.u32(1) + self.u64(0) + self.u64(UInt64(bitPattern: mediaTime)) + self.u32(0x00010000)))
        } else if !spec.edits.isEmpty {
            var elst = self.u32(UInt32(spec.edits.count))
            for edit in spec.edits {
                elst += self.u32(edit.segmentDuration) + self.u32(UInt32(bitPattern: edit.mediaTime)) + self.u32(0x00010000)
            }
            trak += self.box("edts", self.fullBox("elst", elst))
        }
        trak += self.box("mdia", mdhd + hdlr + minf)
        return self.box("trak", trak)
    }

    private func traf(_ spec: TrackSpec) -> Data {
        let tfhd = self.fullBox("tfhd", flags: 0x20000, self.u32(spec.trackId))
        let tfdt = self.fullBox("tfdt", version: 1, self.u64(spec.baseDecodeTime))
        var flags: UInt32 = 0x1
        if spec.sampleSizes {
            flags |= 0x200
        }
        if spec.durations != nil {
            flags |= 0x100
        }
        if spec.compositionOffsets != nil {
            flags |= 0x800
        }
        var trun = self.u32(spec.declaredSampleCount ?? UInt32(spec.sampleCount)) + self.u32(0)
        for i in 0 ..< spec.sampleCount {
            if let durations = spec.durations {
                trun += self.u32(durations[i])
            }
            if spec.sampleSizes {
                trun += self.u32(100)
            }
            if let compositionOffsets = spec.compositionOffsets {
                trun += self.u32(compositionOffsets[i])
            }
        }
        return self.box("traf", tfhd + tfdt + self.fullBox("trun", flags: flags, trun))
    }

    private func part(_ tracks: [TrackSpec], moofs: Int = 1, splitFirstTrack: Bool = false) -> Data {
        var mvex = Data()
        for track in tracks {
            mvex += self.fullBox("trex", self.u32(track.trackId) + self.u32(1) + self.u32(track.defaultDuration) + self.u32(0) + self.u32(0))
        }
        let moov = self.box("moov", tracks.map { self.trak($0) }.reduce(Data(), +) + self.box("mvex", mvex))
        var trafs = tracks.map { self.traf($0) }.reduce(Data(), +)
        if splitFirstTrack, let first = tracks.first {
            trafs += self.traf(first)
        }
        var result = self.box("ftyp", Data("iso6".utf8) + self.u32(0)) + moov
        for _ in 0 ..< moofs {
            result += self.box("moof", self.fullBox("mfhd", self.u32(1)) + trafs)
        }
        return result + self.box("mdat", Data(count: 16))
    }

    // Video: 25 fps at 25000, B-frames, an edit list taking the decoder delay (2000) off; audio: AAC at 48000.
    private func video(edits: [(segmentDuration: UInt32, mediaTime: Int32)] = [(0, 2000)], sampleEntry: String = "avc1") -> TrackSpec {
        return TrackSpec(trackId: 1, handler: "vide", sampleEntry: sampleEntry, timescale: 25000, edits: edits, defaultDuration: 1000, baseDecodeTime: 39_543_000, durations: nil, compositionOffsets: [2000, 4000, 0, 2000], sampleCount: 4)
    }

    private func audio(edits: [(segmentDuration: UInt32, mediaTime: Int32)] = []) -> TrackSpec {
        return TrackSpec(trackId: 2, handler: "soun", sampleEntry: "mp4a", timescale: 48000, edits: edits, defaultDuration: 1024, baseDecodeTime: 75_922_432, durations: nil, compositionOffsets: nil, sampleCount: 3)
    }

    func testEachTrackStartsAtItsFirstSamplesPresentationTimeAndEndsAtItsLastDecodeTime() throws {
        let info = try XCTUnwrap(HLSFragmentTiming.parse(self.part([self.video(), self.audio()])))

        let video = try XCTUnwrap(info.video)
        XCTAssertEqual(video.start, 39_543_000.0 / 25000.0, accuracy: 1e-9)
        XCTAssertEqual(video.duration, 4000.0 / 25000.0, accuracy: 1e-9)
        let audio = try XCTUnwrap(info.audio)
        XCTAssertEqual(audio.start, 75_922_432.0 / 48000.0, accuracy: 1e-9)
        XCTAssertEqual(audio.duration, 3072.0 / 48000.0, accuracy: 1e-9)
        XCTAssertEqual(info.videoCodecName, "h264")
    }

    func testPerSampleDurationsWinOverTheDefaults() throws {
        var audio = self.audio()
        audio.durations = [1024, 1024, 512]
        let info = try XCTUnwrap(HLSFragmentTiming.parse(self.part([self.video(), audio])))
        XCTAssertEqual(info.audio?.duration ?? 0.0, 2560.0 / 48000.0, accuracy: 1e-9)
    }

    func testHEVCAndAV1AreNamedAsFFmpegNamesThem() {
        XCTAssertEqual(HLSFragmentTiming.parse(self.part([self.video(sampleEntry: "hvc1"), self.audio()]))?.videoCodecName, "hevc")
        XCTAssertEqual(HLSFragmentTiming.parse(self.part([self.video(sampleEntry: "av01"), self.audio()]))?.videoCodecName, "av1")
    }

    func testShapesOutsideHLSSegmentsAreLeftToFFmpeg() {
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.audio()], moofs: 2)))
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.audio()], splitFirstTrack: true)))
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(edits: [(500, -1), (0, 2000)]), self.audio()])))
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(edits: [(4000, 2000)]), self.audio()])))
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(sampleEntry: "mp4v"), self.audio()])))
        // An audio edit list marks priming samples, which FFmpeg skips.
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.audio(edits: [(0, 1024)])])))
    }

    func testATruncatedPartIsLeftToFFmpeg() {
        let whole = self.part([self.video(), self.audio()])
        let moofEnd = whole.count - 24
        for length in stride(from: 0, to: moofEnd, by: 7) {
            XCTAssertNil(HLSFragmentTiming.parse(whole.prefix(length)), "\(length) of \(whole.count) bytes")
        }
    }

    // FFmpeg's start is the first sample's presentation time (`index_entries[0]`), not the earliest: with open-GOP
    // leading pictures a later sample presents first.
    func testAPartStartsAtItsFirstSampleWhenALaterOnePresentsEarlier() throws {
        var video = self.video(edits: [])
        video.compositionOffsets = [4000, 0, 0, 3000]
        let info = try XCTUnwrap(HLSFragmentTiming.parse(self.part([video, self.audio()])))
        XCTAssertEqual(info.video?.start ?? 0.0, (39_543_000.0 + 4000.0) / 25000.0, accuracy: 1e-9)
    }

    // FFmpeg reads every composition offset as signed and shifts the decode times by the largest negative one.
    func testANegativeCompositionOffsetIsLeftToFFmpeg() {
        var video = self.video()
        video.compositionOffsets = [2000, UInt32(bitPattern: -1000), 0, 2000]
        XCTAssertNil(HLSFragmentTiming.parse(self.part([video, self.audio()])))
    }

    // Segment bytes come from the network: no size or time in them may trap.
    func testABoxSizePastTheEndIsLeftToFFmpeg() {
        let whole = self.part([self.video(), self.audio()])
        let large = self.box("ftyp", Data("iso6".utf8) + self.u32(0)) + self.u32(1) + Data("free".utf8) + self.u64(UInt64(Int.max) - 4) + whole
        XCTAssertNil(HLSFragmentTiming.parse(large))
    }

    func testADecodeTimeThatOverflowsIsLeftToFFmpeg() {
        var video = self.video()
        video.baseDecodeTime = UInt64(Int64.max) - 100
        XCTAssertNil(HLSFragmentTiming.parse(self.part([video, self.audio()])))
    }

    func testAnEditMediaTimeThatOverflowsIsLeftToFFmpeg() {
        var video = self.video()
        video.largeEditMediaTime = Int64.max
        video.baseDecodeTime = 0
        XCTAssertNil(HLSFragmentTiming.parse(self.part([video, self.audio()])))
    }

    // A sample count no bytes back is not walked: an honest segment has a few hundred samples.
    func testASampleCountWithNothingPerSampleIsBounded() {
        var audio = self.audio()
        audio.sampleSizes = false
        audio.declaredSampleCount = 1 << 20
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), audio])))
    }

    // Every byte of the boxes set to 0x00 and to 0xFF in turn: the parser returns, with timing or nil.
    func testCorruptedBoxesNeverTrap() {
        let whole = self.part([self.video(), self.audio()])
        for index in 0 ..< whole.count - 24 {
            for value: UInt8 in [0x00, 0xff] {
                var corrupted = whole
                corrupted[index] = value
                _ = HLSFragmentTiming.parse(corrupted)
            }
        }
    }
}
