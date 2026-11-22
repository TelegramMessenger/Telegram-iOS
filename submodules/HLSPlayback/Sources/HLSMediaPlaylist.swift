// Ported from hls.js v1.7.3 (src/loader/m3u8-parser.ts, src/loader/fragment.ts), Copyright (c) Dailymotion and hls.js contributors, Apache License 2.0.

import Foundation

public enum HLSPlaylistError: Error, Equatable {
    case notM3U8
    case missingInitSegment
    case duplicateTag(String)
    case mediaSequenceAfterSegment
    case malformedTag(String)
    case noSegments
    case multipleResources
}

// A VOD media playlist of fMP4 segments that are byte ranges of one resource, the only shape the server sends
// (an init named by EXT-X-MAP, then EXTINF + EXT-X-BYTERANGE + URI per segment, then EXT-X-ENDLIST). The playlist is a
// whole file stored with the message, so ENDLIST, TARGETDURATION and the init's byte range are not required, as the
// readers this replaced never required them.
public struct HLSMediaPlaylist: Equatable {
    public struct Segment: Equatable {
        public var index: Int
        public var start: Double
        public var duration: Double
        public var byteRange: Range<Int64>
        
        public var end: Double {
            return self.start + self.duration
        }
        
        public init(index: Int, start: Double, duration: Double, byteRange: Range<Int64>) {
            self.index = index
            self.start = start
            self.duration = duration
            self.byteRange = byteRange
        }
    }
    
    public var targetDuration: Int
    public var mediaSequence: Int
    public var initSegment: Range<Int64>
    public var resourceURI: String
    public var segments: [Segment]
    public var totalDuration: Double
    
    public var averageSegmentDuration: Double {
        if self.segments.isEmpty {
            return 0.0
        }
        return self.totalDuration / Double(self.segments.count)
    }
    
    public static func parse(_ text: String) throws -> HLSMediaPlaylist {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
            if line.hasSuffix("\r") {
                return line.dropLast()
            } else {
                return line
            }
        }
        
        // The first non-blank line must be exactly #EXTM3U. hls.js skips a UTF-8 BOM and blank lines before it.
        if let first = lines.first, first.hasPrefix("\u{FEFF}") {
            lines[0] = first.dropFirst()
        }
        guard let headerIndex = lines.firstIndex(where: { !$0.allSatisfy(\.isWhitespace) }), lines[headerIndex] == "#EXTM3U" else {
            throw HLSPlaylistError.notM3U8
        }
        
        var version: Int?
        var targetDuration: Int?
        var mediaSequence: Int?
        var playlistType: String?
        var hasEndList = false
        var initSegment: Range<Int64>?
        var resourceURI: String?
        
        var segments: [Segment] = []
        var totalDuration: Double = 0.0
        var pendingDuration: Double?
        var pendingByteRange: (length: Int64, offset: Int64?)?
        
        func noteResource(_ uri: String) throws {
            if let resourceURI {
                if resourceURI != uri {
                    throw HLSPlaylistError.multipleResources
                }
            } else {
                resourceURI = uri
            }
        }
        
        for line in lines[(headerIndex + 1)...] {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }
            if !line.hasPrefix("#") {
                // A URI line closes the pending segment.
                try noteResource(line)
                guard let byteRange = pendingByteRange else {
                    throw HLSPlaylistError.malformedTag("EXT-X-BYTERANGE")
                }
                let start = byteRange.offset ?? segments.last?.byteRange.upperBound ?? 0
                let duration = pendingDuration ?? 0.0
                segments.append(Segment(index: segments.count, start: totalDuration, duration: duration, byteRange: start ..< (start + byteRange.length)))
                totalDuration += duration
                pendingDuration = nil
                pendingByteRange = nil
                continue
            }
            
            let (tag, value) = splitTag(line)
            switch tag {
            case "#EXTINF":
                let durationString = value.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                guard let duration = Double(durationString), duration.isFinite, duration >= 0.0 else {
                    throw HLSPlaylistError.malformedTag("EXTINF")
                }
                pendingDuration = duration
            case "#EXT-X-BYTERANGE":
                guard let byteRange = parseByteRange(value) else {
                    throw HLSPlaylistError.malformedTag("EXT-X-BYTERANGE")
                }
                pendingByteRange = byteRange
            case "#EXT-X-MAP":
                let attributes = parseAttributes(value)
                guard let uri = attributes["URI"], !uri.isEmpty else {
                    throw HLSPlaylistError.malformedTag("EXT-X-MAP")
                }
                try noteResource(uri)
                if let byteRangeString = attributes["BYTERANGE"] {
                    // The init's offset defaults to 0: no previous segment applies to it.
                    guard let byteRange = parseByteRange(byteRangeString) else {
                        throw HLSPlaylistError.malformedTag("EXT-X-MAP")
                    }
                    let start = byteRange.offset ?? 0
                    initSegment = start ..< (start + byteRange.length)
                }
            case "#EXT-X-VERSION":
                if version != nil {
                    throw HLSPlaylistError.duplicateTag("EXT-X-VERSION")
                }
                guard let parsed = parseDecimalInteger(value) else {
                    throw HLSPlaylistError.malformedTag("EXT-X-VERSION")
                }
                version = parsed
            case "#EXT-X-TARGETDURATION":
                if targetDuration != nil {
                    throw HLSPlaylistError.duplicateTag("EXT-X-TARGETDURATION")
                }
                guard let parsed = parseDecimalInteger(value) else {
                    throw HLSPlaylistError.malformedTag("EXT-X-TARGETDURATION")
                }
                targetDuration = max(parsed, 1)
            case "#EXT-X-MEDIA-SEQUENCE":
                if mediaSequence != nil {
                    throw HLSPlaylistError.duplicateTag("EXT-X-MEDIA-SEQUENCE")
                }
                if !segments.isEmpty {
                    throw HLSPlaylistError.mediaSequenceAfterSegment
                }
                guard let parsed = parseDecimalInteger(value) else {
                    throw HLSPlaylistError.malformedTag("EXT-X-MEDIA-SEQUENCE")
                }
                mediaSequence = parsed
            case "#EXT-X-PLAYLIST-TYPE":
                if playlistType != nil {
                    throw HLSPlaylistError.duplicateTag("EXT-X-PLAYLIST-TYPE")
                }
                playlistType = value.uppercased()
            case "#EXT-X-ENDLIST":
                if hasEndList {
                    throw HLSPlaylistError.duplicateTag("EXT-X-ENDLIST")
                }
                hasEndList = true
            default:
                // Unknown tags and comments are ignored, as hls.js keeps them only in a fragment's tag list.
                break
            }
        }
        // A trailing segment without a URI is dropped.
        
        if segments.isEmpty {
            throw HLSPlaylistError.noSegments
        }
        // Without one, the longest segment rounded up.
        let resolvedTargetDuration = targetDuration ?? max(1, Int((segments.map(\.duration).max() ?? 1.0).rounded(.up)))
        // Without a byte range for it, the init is everything before the first segment.
        guard let initSegment = initSegment ?? (segments[0].byteRange.lowerBound > 0 ? 0 ..< segments[0].byteRange.lowerBound : nil) else {
            throw HLSPlaylistError.missingInitSegment
        }
        guard let resourceURI else {
            throw HLSPlaylistError.noSegments
        }
        
        return HLSMediaPlaylist(
            targetDuration: resolvedTargetDuration,
            mediaSequence: mediaSequence ?? 0,
            initSegment: initSegment,
            resourceURI: resourceURI,
            segments: segments,
            totalDuration: totalDuration
        )
    }
    
    // The segment whose [start, end) contains `time`: 0 before the start, nil at or after the end.
    public func segmentIndex(containing time: Double) -> Int? {
        if time >= self.totalDuration {
            return nil
        }
        if time < 0.0 {
            return self.segments.isEmpty ? nil : 0
        }
        // Ends are non-decreasing, so binary-search the first segment ending after `time`.
        var low = 0
        var high = self.segments.count
        while low < high {
            let mid = (low + high) / 2
            if self.segments[mid].end > time {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low < self.segments.count ? low : nil
    }
    
    // Bytes from the start of the resource (init included) to the end of the first segments whose durations add up to
    // at least `seconds`, or of every segment when the playlist is shorter.
    public func prefixRange(seconds: Double) -> Range<Int64>? {
        var upperBound: Int64 = 0
        var accumulated: Double = 0.0
        for segment in self.segments {
            upperBound = max(upperBound, segment.byteRange.upperBound)
            accumulated += segment.duration
            if accumulated >= seconds {
                break
            }
        }
        if upperBound == 0 {
            return nil
        }
        return 0 ..< upperBound
    }
    
    // Bytes from the start of the resource to the end of the first segment that holds any media.
    public func firstFrameRange() -> Range<Int64>? {
        guard let segment = self.segments.first(where: { $0.duration > 0.0 }) else {
            return nil
        }
        return 0 ..< max(segment.byteRange.upperBound, self.initSegment.upperBound)
    }
}

private func splitTag(_ line: String) -> (tag: String, value: String) {
    if let colon = line.firstIndex(of: ":") {
        return (String(line[line.startIndex ..< colon]), String(line[line.index(after: colon)...]))
    } else {
        return (line, "")
    }
}

// `n` or ` n`, as hls.js's `: *(\d+)`.
private func parseDecimalInteger(_ value: String) -> Int? {
    let trimmed = value.drop(while: { $0 == " " })
    if trimmed.isEmpty || !trimmed.allSatisfy(\.isASCII) || !trimmed.allSatisfy(\.isNumber) {
        return nil
    }
    return Int(trimmed)
}

// `<length>[@<offset>]`.
private func parseByteRange(_ value: String) -> (length: Int64, offset: Int64?)? {
    let parts = value.trimmingCharacters(in: .whitespaces).split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    guard let lengthPart = parts.first, let length = Int64(lengthPart), length >= 0 else {
        return nil
    }
    if parts.count == 2 {
        guard let offset = Int64(parts[1]), offset >= 0 else {
            return nil
        }
        return (length, offset)
    }
    return (length, nil)
}

// `KEY=value,KEY="quoted, value"`.
private func parseAttributes(_ value: String) -> [String: String] {
    var result: [String: String] = [:]
    var index = value.startIndex
    while index < value.endIndex {
        guard let equals = value[index...].firstIndex(of: "=") else {
            break
        }
        let key = value[index ..< equals].trimmingCharacters(in: .whitespaces)
        var cursor = value.index(after: equals)
        var attributeValue: String
        if cursor < value.endIndex, value[cursor] == "\"" {
            let valueStart = value.index(after: cursor)
            let closing = value[valueStart...].firstIndex(of: "\"") ?? value.endIndex
            attributeValue = String(value[valueStart ..< closing])
            cursor = closing < value.endIndex ? value.index(after: closing) : closing
        } else {
            let end = value[cursor...].firstIndex(of: ",") ?? value.endIndex
            attributeValue = value[cursor ..< end].trimmingCharacters(in: .whitespaces)
            cursor = end
        }
        result[key] = attributeValue
        if let comma = value[cursor...].firstIndex(of: ",") {
            index = value.index(after: comma)
        } else {
            break
        }
    }
    return result
}
