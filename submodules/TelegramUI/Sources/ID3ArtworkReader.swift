import Foundation

private enum ID3Tag: CaseIterable {
    case v2
    case v3
    
    static var headerLength = 5
    var header: Data {
        switch self {
            case .v2:
                return Data([ 0x49, 0x44, 0x33, 0x02, 0x00 ])
            case .v3:
                return Data([ 0x49, 0x44, 0x33, 0x03, 0x00 ])
        }
    }
    
    var artworkHeader: Data {
        switch self {
            case .v2:
                return Data([ 0x50, 0x49, 0x43 ])
            case .v3:
                return Data([ 0x41, 0x50, 0x49, 0x43 ])
        }
    }
    
    var frameSizeOffset: Int {
        switch self {
            case .v2:
                return 2
            case .v3:
                return 4
        }
    }
    
    var frameOffset: Int {
        switch self {
            case .v2:
                return 6
            case .v3:
                return 10
        }
    }
    
    func frameSize(_ value: Int32) -> Int {
        switch self {
            case .v2:
                return Int(value & 0x00ffffff) + self.frameOffset
            case .v3:
                return Int(value) + self.frameOffset
        }
    }
}

private let sizeOffset = 6
private let tagOffset = 10
private let artOffset = 10

private let v2FrameOffset: UInt32 = 6
private let v3FrameOffset: UInt32 = 10

private let tagEnding = Data([ 0x00, 0x00, 0x00 ])

private enum ID3ArtworkFormat: CaseIterable {
    case jpg
    case png
    
    var magic: Data {
        switch self {
            case .jpg:
                return Data([ 0xff, 0xd8, 0xff ])
            case .png:
                return Data([ 0x89, 0x50, 0x4e, 0x47 ])
        }
    }
}

private class DataStream {
    private let data: Data
    private(set) var position = 0
    var reachedEnd: Bool {
        return self.position >= self.data.count
    }
    
    init(_ data: Data) {
        self.data = data
    }
    
    func next() -> UInt8? {
        guard !self.reachedEnd else {
            return nil
        }
        let byte = self.data[self.position]
        self.position += 1
        return byte
    }
    
    func nextValue<T: BinaryInteger>() -> T? {
        let count = MemoryLayout<T>.size
        guard self.position + count <= self.data.count else {
            return nil
        }
        let value = self.data.subdata(in: self.position ..< self.position + count).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> T in
            return pointer.baseAddress!.assumingMemoryBound(to: T.self).pointee
        }
        self.position += count
        return value
    }
    
    func next(_ count: Int, offset: Int = 0, peek: Bool = false) -> Data? {
        guard self.position + offset + count <= self.data.count else {
            return nil
        }
        let subdata = self.data.subdata(in: self.position + offset ..< self.position + offset + count)
        if !peek {
            self.position += count + offset
        }
        return subdata
    }
    
    func upTo(_ marker: UInt8) -> Data? {
        if let end = (self.position ..< self.data.count).firstIndex( where: { self.data[$0] == marker } ) {
            let upTo = self.next(end - self.position)
            self.skip()
            return upTo
        } else {
            return nil
        }
    }
    
    func skip(_ count: Int = 1) {
        self.position += count
    }
    
    func skipThrough(_ marker: UInt8) {
        if let end = (self.position ..< self.data.count).firstIndex( where: { self.data[$0] == marker } ) {
            self.position = end + 1
        } else {
            self.position = self.data.count
        }
    }
}

enum ID3ArtworkResult {
    case notFound
    case moreDataNeeded(Int)
    case artworkData(Data)
}

func readAlbumArtworkData(_ data: Data) -> ID3ArtworkResult {
    guard data.count >= 4 else {
        return .notFound
    }
    
    let stream = DataStream(data)
    let versionHeader = stream.next(ID3Tag.headerLength)
    
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
    
    stream.skip()
    guard let value: UInt32 = stream.nextValue() else {
        return .notFound
    }
    let size = CFSwapInt32HostToBig(value)
    let b1 = (size & 0x7f000000) >> 3
    let b2 = (size & 0x007f0000) >> 2
    let b3 = (size & 0x00007f00) >> 1
    let b4 = size & 0x0000007f
    let tagSize = Int(b1 + b2 + b3 + b4)
    
    while !stream.reachedEnd {
        guard let frameHeader = stream.next(4, peek: true) else {
            return .moreDataNeeded(tagSize)
        }
        
        stream.skip(id3Tag.frameSizeOffset)
        guard let value: UInt32 = stream.nextValue() else {
            return .moreDataNeeded(tagSize)
        }
        let val = CFSwapInt32HostToBig(value)
        if val > Int32.max {
            return .notFound
        }
        let frameSize = id3Tag.frameSize(Int32(val))
        let bytesLeft = frameSize - id3Tag.frameSizeOffset - 4
        
        if frameHeader == id3Tag.artworkHeader {
            var image: (ID3ArtworkFormat, Int)?
            outer: for i in 0 ..< frameSize - 4 {
                if let head = stream.next(4, offset: i, peek: true) {
                    for format in ID3ArtworkFormat.allCases {
                        if head.prefix(format.magic.count) == format.magic {
                            image = (format, i)
                            break outer
                        }
                    }
                }
            }
            
            if let (format, offset) = image {
                stream.skip(offset)
                
                switch format {
                    case .jpg:
                        var data = Data(capacity: frameSize + 1024)
                        var previousByte: UInt8 = 0xff
                    
                        let limit = Int(Double(frameSize - offset) * 0.8)
                        for _ in 0 ..< frameSize - offset {
                            if let byte: UInt8 = stream.nextValue() {
                                data.append(byte)
                                if byte == 0xd9 && previousByte == 0xff && data.count > limit {
                                    break
                                }
                                previousByte = byte
                            } else {
                                return .moreDataNeeded(tagSize)
                            }
                        }
                        return .artworkData(data)
                    case .png:
                        if let data = stream.next(frameSize - offset) {
                            return .artworkData(data)
                        } else {
                            return .moreDataNeeded(tagSize)
                        }
                }
            }
        } else if frameHeader.prefix(3) == tagEnding {
            return .notFound
        }
        stream.skip(bytesLeft)
    }
    return .notFound
}
