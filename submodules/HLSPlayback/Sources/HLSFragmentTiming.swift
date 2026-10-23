import Foundation

// A part's track timing read from its fMP4 boxes (the init's `moov`, the segment's `moof`) instead of probing it with
// FFmpeg: what `extractFFMpegMediaInfo` reports for such a part, per track, start = the first sample's presentation
// time (its decode time plus composition offset, less the edit list's media time) and duration = the end of its decode
// times (`tfdt` plus the sample durations) less that start. Nil for any shape outside the one HLS segments come in (more
// than one `moof`, a track split over several `traf`s, an edit list other than one plain entry, a negative composition
// offset, an unknown video codec) and for bytes no honest segment holds (a malformed box, a time that overflows, more
// samples than `maximumSampleCount`): the caller then asks FFmpeg.
public enum HLSFragmentTiming {
    public struct Track: Equatable {
        public var start: Double
        public var duration: Double

        public init(start: Double, duration: Double) {
            self.start = start
            self.duration = duration
        }
    }

    public struct Info: Equatable {
        public var audio: Track?
        public var video: Track?
        public var videoCodecName: String?

        public init(audio: Track?, video: Track?, videoCodecName: String?) {
            self.audio = audio
            self.video = video
            self.videoCodecName = videoCodecName
        }
    }

    private struct TrackHeader {
        var trackId: UInt32 = 0
        var timescale: UInt32 = 0
        var handler: String = ""
        var sampleEntry: String?
        var editMediaTime: Int64 = 0
    }

    private struct Fragment {
        var trackId: UInt32
        // The first sample's presentation time and the end of the last sample's decode time, in the track's timescale.
        var firstPresentationTime: Int64?
        var decodeEnd: Int64
        var sampleCount = 0
    }

    // A 5 s segment has a few hundred samples per track.
    static let maximumSampleCount = 1 << 16

    // `data`: the init segment followed by one media segment.
    public static func parse(_ data: Data) -> Info? {
        return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Info? in
            var reader = BoxReader(bytes: buffer)
            return reader.parsePart()
        }
    }

    private struct BoxReader {
        let bytes: UnsafeRawBufferPointer

        init(bytes: UnsafeRawBufferPointer) {
            self.bytes = bytes
        }

        func u8(_ offset: Int) -> UInt8? {
            guard offset >= 0, offset < self.bytes.count else {
                return nil
            }
            return self.bytes[offset]
        }

        func u32(_ offset: Int) -> UInt32? {
            guard offset >= 0, offset + 4 <= self.bytes.count else {
                return nil
            }
            var value: UInt32 = 0
            for i in 0 ..< 4 {
                value = (value << 8) | UInt32(self.bytes[offset + i])
            }
            return value
        }

        func u64(_ offset: Int) -> UInt64? {
            guard let high = self.u32(offset), let low = self.u32(offset + 4) else {
                return nil
            }
            return (UInt64(high) << 32) | UInt64(low)
        }

        func fourCC(_ offset: Int) -> String? {
            guard offset >= 0, offset + 4 <= self.bytes.count else {
                return nil
            }
            return String(bytes: self.bytes[offset ..< offset + 4], encoding: .isoLatin1)
        }

        // The boxes directly inside `range`, as (type, body range); nil when one runs past it.
        func children(_ range: Range<Int>) -> [(String, Range<Int>)]? {
            var result: [(String, Range<Int>)] = []
            var position = range.lowerBound
            while position + 8 <= range.upperBound {
                guard var size = self.u32(position).map(Int.init), let type = self.fourCC(position + 4) else {
                    return nil
                }
                var header = 8
                if size == 1 {
                    guard let large = self.u64(position + 8), large <= UInt64(Int.max) else {
                        return nil
                    }
                    size = Int(large)
                    header = 16
                } else if size == 0 {
                    size = range.upperBound - position
                }
                guard size >= header, size <= range.upperBound - position else {
                    return nil
                }
                result.append((type, (position + header) ..< (position + size)))
                position += size
            }
            return result
        }

        func child(_ type: String, in range: Range<Int>) -> Range<Int>? {
            return self.children(range)?.first(where: { $0.0 == type })?.1
        }

        mutating func parsePart() -> Info? {
            guard let top = self.children(0 ..< self.bytes.count) else {
                return nil
            }
            let moofs = top.filter { $0.0 == "moof" }
            guard let moov = top.first(where: { $0.0 == "moov" })?.1, moofs.count == 1, let moovChildren = self.children(moov) else {
                return nil
            }

            var tracks: [TrackHeader] = []
            var defaultDurations: [UInt32: UInt32] = [:]
            for (type, body) in moovChildren {
                if type == "trak" {
                    guard let track = self.parseTrack(body) else {
                        return nil
                    }
                    tracks.append(track)
                } else if type == "mvex", let mvexChildren = self.children(body) {
                    for (childType, trex) in mvexChildren where childType == "trex" {
                        guard let trackId = self.u32(trex.lowerBound + 4), let duration = self.u32(trex.lowerBound + 12) else {
                            return nil
                        }
                        defaultDurations[trackId] = duration
                    }
                }
            }

            guard let moofChildren = self.children(moofs[0].1) else {
                return nil
            }
            var fragments: [UInt32: Fragment] = [:]
            for (type, traf) in moofChildren where type == "traf" {
                guard let fragment = self.parseTrackFragment(traf, defaultDurations: defaultDurations), fragments[fragment.trackId] == nil else {
                    return nil
                }
                fragments[fragment.trackId] = fragment
            }

            var info = Info(audio: nil, video: nil, videoCodecName: nil)
            var sawVideo = false
            var sawAudio = false
            for track in tracks {
                if track.handler == "vide" && !sawVideo {
                    sawVideo = true
                    guard let codecName = track.sampleEntry.flatMap(HLSFragmentTiming.codecName) else {
                        return nil
                    }
                    info.videoCodecName = codecName
                    if let fragment = fragments[track.trackId], fragment.firstPresentationTime != nil {
                        guard let timing = HLSFragmentTiming.timing(track: track, fragment: fragment) else {
                            return nil
                        }
                        info.video = timing
                    }
                } else if track.handler == "soun" && !sawAudio {
                    sawAudio = true
                    // An audio edit list marks priming samples, which FFmpeg skips rather than starting before.
                    if track.editMediaTime != 0 {
                        return nil
                    }
                    if let fragment = fragments[track.trackId], fragment.firstPresentationTime != nil {
                        guard let timing = HLSFragmentTiming.timing(track: track, fragment: fragment) else {
                            return nil
                        }
                        info.audio = timing
                    }
                }
            }
            if info.audio == nil && info.video == nil {
                return nil
            }
            // FFmpeg does not report a start before 0 as it is.
            if (info.audio?.start ?? 0.0) < 0.0 || (info.video?.start ?? 0.0) < 0.0 {
                return nil
            }
            return info
        }

        func parseTrack(_ trak: Range<Int>) -> TrackHeader? {
            var track = TrackHeader()
            guard let tkhd = self.child("tkhd", in: trak), let version = self.u8(tkhd.lowerBound), let trackId = self.u32(tkhd.lowerBound + (version == 1 ? 20 : 12)) else {
                return nil
            }
            track.trackId = trackId
            guard let mdia = self.child("mdia", in: trak), let mdhd = self.child("mdhd", in: mdia), let mdhdVersion = self.u8(mdhd.lowerBound), let timescale = self.u32(mdhd.lowerBound + (mdhdVersion == 1 ? 20 : 12)), timescale > 0, let hdlr = self.child("hdlr", in: mdia), let handler = self.fourCC(hdlr.lowerBound + 8) else {
                return nil
            }
            track.timescale = timescale
            track.handler = handler
            if let minf = self.child("minf", in: mdia), let stbl = self.child("stbl", in: minf), let stsd = self.child("stsd", in: stbl), let entryCount = self.u32(stsd.lowerBound + 4), entryCount > 0 {
                track.sampleEntry = self.fourCC(stsd.lowerBound + 12)
            }
            if let edts = self.child("edts", in: trak), let elst = self.child("elst", in: edts) {
                guard let version = self.u8(elst.lowerBound), let count = self.u32(elst.lowerBound + 4), count == 1 else {
                    return nil
                }
                let entry = elst.lowerBound + 8
                let segmentDuration: UInt64?
                let mediaTime: Int64?
                let rateOffset: Int
                if version == 1 {
                    segmentDuration = self.u64(entry)
                    mediaTime = self.u64(entry + 8).map { Int64(bitPattern: $0) }
                    rateOffset = entry + 16
                } else {
                    segmentDuration = self.u32(entry).map(UInt64.init)
                    mediaTime = self.u32(entry + 4).map { Int64(Int32(bitPattern: $0)) }
                    rateOffset = entry + 8
                }
                guard segmentDuration == 0, let mediaTime, mediaTime >= 0, self.u32(rateOffset) == 0x00010000 else {
                    return nil
                }
                track.editMediaTime = mediaTime
            }
            return track
        }

        func parseTrackFragment(_ traf: Range<Int>, defaultDurations: [UInt32: UInt32]) -> Fragment? {
            guard let trafChildren = self.children(traf), let tfhd = trafChildren.first(where: { $0.0 == "tfhd" })?.1, let tfhdFlags = self.u32(tfhd.lowerBound).map({ $0 & 0x00ffffff }), let trackId = self.u32(tfhd.lowerBound + 4) else {
                return nil
            }
            var offset = tfhd.lowerBound + 8
            if tfhdFlags & 0x1 != 0 {
                offset += 8
            }
            if tfhdFlags & 0x2 != 0 {
                offset += 4
            }
            var defaultDuration = defaultDurations[trackId]
            if tfhdFlags & 0x8 != 0 {
                guard let duration = self.u32(offset) else {
                    return nil
                }
                defaultDuration = duration
            }
            guard let tfdt = trafChildren.first(where: { $0.0 == "tfdt" })?.1, let tfdtVersion = self.u8(tfdt.lowerBound) else {
                return nil
            }
            let baseDecodeTime: Int64
            if tfdtVersion == 1 {
                guard let value = self.u64(tfdt.lowerBound + 4), value <= UInt64(Int64.max) else {
                    return nil
                }
                baseDecodeTime = Int64(value)
            } else {
                guard let value = self.u32(tfdt.lowerBound + 4) else {
                    return nil
                }
                baseDecodeTime = Int64(value)
            }
            var fragment = Fragment(trackId: trackId, decodeEnd: baseDecodeTime)
            for (type, trun) in trafChildren where type == "trun" {
                guard let header = self.u32(trun.lowerBound), let sampleCount = self.u32(trun.lowerBound + 4).map(Int.init) else {
                    return nil
                }
                let flags = header & 0x00ffffff
                var position = trun.lowerBound + 8
                if flags & 0x1 != 0 {
                    position += 4
                }
                if flags & 0x4 != 0 {
                    position += 4
                }
                let bytesPerSample = [0x100, 0x200, 0x400, 0x800].filter { flags & $0 != 0 }.count * 4
                fragment.sampleCount += sampleCount
                guard fragment.sampleCount <= HLSFragmentTiming.maximumSampleCount, position <= trun.upperBound, sampleCount * bytesPerSample <= trun.upperBound - position else {
                    return nil
                }
                for _ in 0 ..< sampleCount {
                    var duration = defaultDuration
                    if flags & 0x100 != 0 {
                        duration = self.u32(position)
                        position += 4
                    }
                    if flags & 0x200 != 0 {
                        position += 4
                    }
                    if flags & 0x400 != 0 {
                        position += 4
                    }
                    var compositionOffset: Int64 = 0
                    if flags & 0x800 != 0 {
                        // FFmpeg reads an offset as signed whatever the box version, and shifts every decode time by
                        // the largest negative one.
                        guard let value = self.u32(position), Int32(bitPattern: value) >= 0 else {
                            return nil
                        }
                        compositionOffset = Int64(value)
                        position += 4
                    }
                    guard let duration else {
                        return nil
                    }
                    if fragment.firstPresentationTime == nil {
                        let (presentationTime, overflow) = fragment.decodeEnd.addingReportingOverflow(compositionOffset)
                        guard !overflow else {
                            return nil
                        }
                        fragment.firstPresentationTime = presentationTime
                    }
                    let (decodeEnd, overflow) = fragment.decodeEnd.addingReportingOverflow(Int64(duration))
                    guard !overflow else {
                        return nil
                    }
                    fragment.decodeEnd = decodeEnd
                }
            }
            return fragment
        }
    }

    // Nil when a time overflows.
    private static func timing(track: TrackHeader, fragment: Fragment) -> Track? {
        guard let firstPresentationTime = fragment.firstPresentationTime else {
            return nil
        }
        let (start, startOverflow) = firstPresentationTime.subtractingReportingOverflow(track.editMediaTime)
        let (duration, durationOverflow) = fragment.decodeEnd.subtractingReportingOverflow(start)
        guard !startOverflow, !durationOverflow else {
            return nil
        }
        let timescale = Double(track.timescale)
        return Track(start: Double(start) / timescale, duration: Double(max(0, duration)) / timescale)
    }

    // The name `resolveFFMpegCodecName` gives the codec FFmpeg identifies from this sample entry.
    private static func codecName(sampleEntry: String) -> String? {
        switch sampleEntry {
        case "avc1", "avc3":
            return "h264"
        case "hvc1", "hev1":
            return "hevc"
        case "av01":
            return "av1"
        case "vp09":
            return "vp9"
        case "vp08":
            return "vp8"
        default:
            return nil
        }
    }
}
