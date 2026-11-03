import Foundation

private enum ID3Tag: CaseIterable {
    case v2
    case v3
    
    static let headerLength = 10
    static let versionHeaderLength = 5
    
    var header: Data {
        switch self {
            case .v2:
                return Data([0x49, 0x44, 0x33, 0x02, 0x00])
            case .v3:
                return Data([0x49, 0x44, 0x33, 0x03, 0x00])
        }
    }
    
    var artworkHeader: Data {
        switch self {
            case .v2:
                return Data([0x50, 0x49, 0x43])
            case .v3:
                return Data([0x41, 0x50, 0x49, 0x43])
        }
    }
    
    var frameIdentifierLength: Int {
        switch self {
            case .v2:
                return 3
            case .v3:
                return 4
        }
    }
    
    var frameHeaderLength: Int {
        switch self {
            case .v2:
                return 6
            case .v3:
                return 10
        }
    }
    
    var unsupportedFlagsMask: UInt8 {
        switch self {
            case .v2, .v3:
                return 0xc0
        }
    }
    
    func frameDataSize(in data: Data, at frameOffset: Int) -> Int? {
        switch self {
            case .v2:
                guard let range = makeRange(start: frameOffset + self.frameIdentifierLength, length: 3, upperBound: data.count) else {
                    return nil
                }
                let bytes = data[range]
                return Int(UInt32(bytes[bytes.startIndex]) << 16 | UInt32(bytes[bytes.startIndex + 1]) << 8 | UInt32(bytes[bytes.startIndex + 2]))
            case .v3:
                guard let value = readBigEndianUInt32(in: data, at: frameOffset + self.frameIdentifierLength) else {
                    return nil
                }
                return Int(value)
        }
    }
}

private enum ID3ArtworkFormat: CaseIterable {
    case jpg
    case png
    
    var magic: Data {
        switch self {
            case .jpg:
                return Data([0xff, 0xd8, 0xff])
            case .png:
                return Data([0x89, 0x50, 0x4e, 0x47])
        }
    }
}

private enum ID3ArtworkReaderLimits {
    static let maximumTagSize = 16 * 1024 * 1024
    static let maximumFrameSize = 16 * 1024 * 1024
    static let maximumArtworkSize = 16 * 1024 * 1024
}

private let id3Prefix = Data([0x49, 0x44, 0x33])
private let tagEnding = Data([0x00, 0x00, 0x00])
private let jpegEndMarker = Data([0xff, 0xd9])
private let pngEndMarker = Data([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82])

private func makeRange(start: Int, length: Int, upperBound: Int) -> Range<Int>? {
    guard start >= 0, length >= 0 else {
        return nil
    }
    let (end, overflow) = start.addingReportingOverflow(length)
    guard !overflow, end <= upperBound else {
        return nil
    }
    return start ..< end
}

private func checkedAdd(_ lhs: Int, _ rhs: Int) -> Int? {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? nil : result
}

private func readBigEndianUInt32(in data: Data, at offset: Int) -> UInt32? {
    guard let range = makeRange(start: offset, length: 4, upperBound: data.count) else {
        return nil
    }
    let bytes = data[range]
    return UInt32(bytes[bytes.startIndex]) << 24
        | UInt32(bytes[bytes.startIndex + 1]) << 16
        | UInt32(bytes[bytes.startIndex + 2]) << 8
        | UInt32(bytes[bytes.startIndex + 3])
}

private func decodeSynchsafeUInt32(_ value: UInt32) -> Int? {
    guard value & 0x80808080 == 0 else {
        return nil
    }
    let b1 = Int((value >> 24) & 0x7f)
    let b2 = Int((value >> 16) & 0x7f)
    let b3 = Int((value >> 8) & 0x7f)
    let b4 = Int(value & 0x7f)
    return (b1 << 21) | (b2 << 14) | (b3 << 7) | b4
}

private func extractArtworkData(from data: Data, frameDataRange: Range<Int>) -> Data? {
    let frameData = data.subdata(in: frameDataRange)
    
    var bestMatch: (format: ID3ArtworkFormat, range: Range<Data.Index>)?
    for format in ID3ArtworkFormat.allCases {
        guard let range = frameData.range(of: format.magic) else {
            continue
        }
        if let current = bestMatch {
            if range.lowerBound < current.range.lowerBound {
                bestMatch = (format, range)
            }
        } else {
            bestMatch = (format, range)
        }
    }
    
    guard let match = bestMatch else {
        return nil
    }
    
    let payload: Data
    switch match.format {
        case .jpg:
            if let endMarkerRange = frameData[match.range.lowerBound ..< frameData.endIndex].range(of: jpegEndMarker) {
                payload = frameData.subdata(in: match.range.lowerBound ..< endMarkerRange.upperBound)
            } else {
                payload = frameData.subdata(in: match.range.lowerBound ..< frameData.endIndex)
            }
        case .png:
            if let endMarkerRange = frameData[match.range.lowerBound ..< frameData.endIndex].range(of: pngEndMarker) {
                payload = frameData.subdata(in: match.range.lowerBound ..< endMarkerRange.upperBound)
            } else {
                payload = frameData.subdata(in: match.range.lowerBound ..< frameData.endIndex)
            }
    }
    
    guard payload.count <= ID3ArtworkReaderLimits.maximumArtworkSize else {
        return nil
    }
    return payload
}

enum ID3ArtworkResult {
    case notFound
    case moreDataNeeded(Int)
    case artworkData(Data)
}

func readAlbumArtworkData(_ data: Data) -> ID3ArtworkResult {
    if data.count < id3Prefix.count {
        return id3Prefix.starts(with: data) ? .moreDataNeeded(ID3Tag.headerLength) : .notFound
    }
    if data.count < ID3Tag.headerLength {
        return data.starts(with: id3Prefix) ? .moreDataNeeded(ID3Tag.headerLength) : .notFound
    }
    
    guard let versionHeaderRange = makeRange(start: 0, length: ID3Tag.versionHeaderLength, upperBound: data.count) else {
        return .notFound
    }
    let versionHeader = data.subdata(in: versionHeaderRange)
    
    var version: ID3Tag?
    for tag in ID3Tag.allCases {
        if versionHeader == tag.header {
            version = tag
            break
        }
    }
    guard let id3Tag = version else {
        return .notFound
    }
    
    let flags = data[5]
    guard flags & id3Tag.unsupportedFlagsMask == 0 else {
        return .notFound
    }
    
    guard let rawTagSize = readBigEndianUInt32(in: data, at: 6), let tagPayloadSize = decodeSynchsafeUInt32(rawTagSize) else {
        return .notFound
    }
    guard let totalTagSize = checkedAdd(ID3Tag.headerLength, tagPayloadSize), totalTagSize <= ID3ArtworkReaderLimits.maximumTagSize else {
        return .notFound
    }
    
    let availableTagEnd = min(totalTagSize, data.count)
    var frameOffset = ID3Tag.headerLength
    
    while frameOffset < availableTagEnd {
        let remainingTagBytes = availableTagEnd - frameOffset
        if remainingTagBytes < id3Tag.frameHeaderLength {
            return totalTagSize > data.count ? .moreDataNeeded(totalTagSize) : .notFound
        }
        
        guard let frameIdentifierRange = makeRange(start: frameOffset, length: id3Tag.frameIdentifierLength, upperBound: data.count) else {
            return totalTagSize > data.count ? .moreDataNeeded(totalTagSize) : .notFound
        }
        let frameIdentifier = data.subdata(in: frameIdentifierRange)
        if frameIdentifier.prefix(3) == tagEnding {
            return .notFound
        }
        
        guard let framePayloadSize = id3Tag.frameDataSize(in: data, at: frameOffset), framePayloadSize <= ID3ArtworkReaderLimits.maximumFrameSize else {
            return .notFound
        }
        guard let frameSize = checkedAdd(id3Tag.frameHeaderLength, framePayloadSize), let frameEnd = checkedAdd(frameOffset, frameSize) else {
            return .notFound
        }
        guard frameEnd <= totalTagSize else {
            return .notFound
        }
        if frameEnd > data.count {
            return .moreDataNeeded(totalTagSize)
        }
        
        if frameIdentifier == id3Tag.artworkHeader {
            let frameDataStart = frameOffset + id3Tag.frameHeaderLength
            if let artworkData = extractArtworkData(from: data, frameDataRange: frameDataStart ..< frameEnd) {
                return .artworkData(artworkData)
            }
        }
        
        frameOffset = frameEnd
    }
    
    return .notFound
}
