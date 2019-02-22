import Foundation

private enum ID3Tag {
    case v2
    case v3
    
    static var headerLength = 5
    var header: Data {
        switch self {
            case .v2:
                return Data(bytes: [ 0x49, 0x44, 0x33, 0x02, 0x00 ])
            case .v3:
                return Data(bytes: [ 0x49, 0x44, 0x33, 0x03, 0x00 ])
        }
    }
    
    var artworkHeader: Data {
        switch self {
            case .v2:
                return Data(bytes: [ 0x50, 0x49, 0x43 ])
            case .v3:
                return Data(bytes: [ 0x41, 0x50, 0x49, 0x43 ])
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
    
    var frameOffset: Int32 {
        switch self {
            case .v2:
                return 6
            case .v3:
                return 10
        }
    }
    
    func frameSize(_ value: Int32) -> Int32 {
        switch self {
            case .v2:
                return (value & 0x00ffffff) + self.frameOffset
            case .v3:
                return value + self.frameOffset
        }
    }
}

private let sizeOffset = 6
private let tagOffset = 10
private let artOffset = 10

private let v2FrameOffset: UInt32 = 6
private let v3FrameOffset: UInt32 = 10

private let jpgMagic = Data(bytes: [ 0xff, 0xd8, 0xff ])
private let pngMagic = Data(bytes: [ 0x89, 0x50, 0x4e, 0x47 ])

private class DataStream {
    let data: Data
    var position = 0
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
        let value = self.data.subdata(in: self.position ..< self.position + count).withUnsafeBytes { (pointer: UnsafePointer<T>) -> T in
            return pointer.pointee
        }
        self.position += count
        return value
    }
    
    func next(_ count: Int) -> Data? {
        guard self.position + count <= self.data.count else {
            return nil
        }
        let subdata = self.data.subdata(in: self.position..<self.position + count)
        self.position += count
        return subdata
    }
    
    func upTo(_ marker: UInt8) -> Data? {
        if let end = (self.position ..< self.data.count).index( where: { self.data[$0] == marker } ) {
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
        if let end = (self.position ..< self.data.count).index( where: { self.data[$0] == marker } ) {
            self.position = end + 1
        } else {
            self.position = self.data.count
        }
    }
}

func readAlbumArtworkData(_ data: Data) -> Data? {
    guard data.count >= 4 else {
        return nil
    }
    
    let stream = DataStream(data)
    let versionHeader = stream.next(ID3Tag.headerLength)
    
    let id3Tag: ID3Tag
    if versionHeader == ID3Tag.v2.header {
        id3Tag = .v2
    } else if versionHeader == ID3Tag.v2.header {
        id3Tag = .v3
    } else {
        return nil
    }
    
    guard let value: UInt32 = stream.nextValue() else {
        return nil
    }
    let size = CFSwapInt32HostToBig(value)
    let b1 = (size & 0x7f000000) >> 3
    let b2 = (size & 0x007f0000) >> 2
    let b3 = (size & 0x00007f00) >> 1
    let b4 = size & 0x0000007f
    let tagSize = b1 + b2 + b3 + b4
    
    while !stream.reachedEnd {
        stream.skip(id3Tag.frameSizeOffset)
        guard let value: UInt32 = stream.nextValue() else {
            return nil
        }
        let frameSize = id3Tag.frameSize(Int32(CFSwapInt32HostToBig(value)))
        
        guard let frameHeader = stream.next(id3Tag.artworkHeader.count) else {
            return nil
        }
        if frameHeader == id3Tag.artworkHeader {
            
        } else {
            
        }
        
    }
    
    return Data()
}
