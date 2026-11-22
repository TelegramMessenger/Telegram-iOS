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
        // An mp4a sample entry with this AudioSpecificConfig in its esds, at this sample rate; nil: an empty entry.
        var audioSpecificConfig: [UInt8]? = nil
        var sampleRate: UInt32 = 48000
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
        let stsd = self.fullBox("stsd", self.u32(1) + self.sampleEntry(spec))
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

    // A descriptor of the esds (ISO 14496-1), its size in one byte.
    private func descriptor(_ tag: UInt8, _ body: Data) -> Data {
        return Data([tag, UInt8(body.count)]) + body
    }

    private func sampleEntry(_ spec: TrackSpec) -> Data {
        guard let config = spec.audioSpecificConfig else {
            return self.box(spec.sampleEntry, Data(count: 8))
        }
        // SampleEntry (6 reserved, data reference index), AudioSampleEntry version 0 (8 reserved, channel count, sample
        // size, 4 reserved, sample rate 16.16), then the esds: ES (id, flags), DecoderConfig (MPEG-4 audio, audio
        // stream, buffer size, bit rates), DecoderSpecificInfo (the config), SLConfig.
        var entry = Data(count: 6) + Data([0, 1]) + Data(count: 8) + Data([0, 2, 0, 16]) + Data(count: 4) + self.u32(spec.sampleRate << 16)
        let decoderConfig = self.descriptor(0x04, Data([0x40, 0x15, 0, 0, 0]) + self.u32(128_000) + self.u32(128_000) + self.descriptor(0x05, Data(config)))
        entry += self.fullBox("esds", self.descriptor(0x03, Data([0, 2, 0]) + decoderConfig + self.descriptor(0x06, Data([0x02]))))
        return self.box(spec.sampleEntry, entry)
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
        // An audio edit list marks priming samples, which FFmpeg skips at the codec's sample rate: without a config to
        // read it from, the part is FFmpeg's.
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
        for whole in [self.part([self.video(), self.audio()]), self.part([self.video(), self.primedAudio(config: [0x11, 0x88, 0x56, 0xe5, 0x00])])] {
            for index in 0 ..< whole.count - 24 {
                for value: UInt8 in [0x00, 0xff] {
                    var corrupted = whole
                    corrupted[index] = value
                    _ = HLSFragmentTiming.parse(corrupted)
                }
            }
        }
    }

    // AAC at 48 kHz with 2112 priming samples marked by its edit list, in this AudioSpecificConfig.
    private func primedAudio(config: [UInt8], sampleRate: UInt32 = 48000) -> TrackSpec {
        var audio = self.audio(edits: [(0, 2112)])
        audio.audioSpecificConfig = config
        audio.sampleRate = sampleRate
        return audio
    }

    // FFmpeg skips priming as samples and adds them back to the start at the codec's sample rate: for plain AAC at the
    // track's timescale, the start is the first sample's decode time (measured on 34 real parts and a fixture).
    func testPlainAACPrimingStartsAtTheFirstSamplesDecodeTime() throws {
        // AAC-LC, 48 kHz, stereo.
        let info = try XCTUnwrap(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x11, 0x90])])))
        let audio = try XCTUnwrap(info.audio)
        XCTAssertEqual(audio.start, 75_922_432.0 / 48000.0, accuracy: 1e-9)
        XCTAssertEqual(audio.duration, 3072.0 / 48000.0, accuracy: 1e-9)
    }

    // A config that signals SBR explicitly as absent (sync extension 0x2b7, SBR, not present) is plain AAC.
    func testAnExplicitNoSBRExtensionIsPlainAAC() throws {
        let info = try XCTUnwrap(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x11, 0x88, 0x56, 0xe5, 0x00])])))
        XCTAssertEqual(info.audio?.start ?? 0.0, 75_922_432.0 / 48000.0, accuracy: 1e-9)
    }

    // FFmpeg's sample rate for HE-AAC can be twice the core rate, and anything else needs FFmpeg's config parser.
    func testPrimingOtherThanPlainAACIsLeftToFFmpeg() {
        // HE-AAC (object type 5).
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x2b, 0x10, 0x88, 0x00])])))
        // AAC-LC with SBR signalled present (sync extension, SBR, present, 48 kHz extension).
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x13, 0x10, 0x56, 0xe5, 0x98])])))
        // AAC-LC at 44.1 kHz in a 48 kHz track.
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x12, 0x10])])))
        // A channel configuration of 0 (a program config element follows).
        XCTAssertNil(HLSFragmentTiming.parse(self.part([self.video(), self.primedAudio(config: [0x11, 0x80])])))
    }
}
