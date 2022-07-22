import Foundation
import UIKit
import SwiftSignalKit
import CryptoUtils
import ManagedFile
import Compression

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

public final class AnimationCacheItemFrame {
    public enum RequestedFormat {
        case rgba
        case yuva(rowAlignment: Int)
    }
    
    public final class Plane {
        public let data: Data
        public let width: Int
        public let height: Int
        public let bytesPerRow: Int
        
        public init(data: Data, width: Int, height: Int, bytesPerRow: Int) {
            self.data = data
            self.width = width
            self.height = height
            self.bytesPerRow = bytesPerRow
        }
    }
    
    public enum Format {
        case rgba(data: Data, width: Int, height: Int, bytesPerRow: Int)
        case yuva(y: Plane, u: Plane, v: Plane, a: Plane)
    }
    
    public let format: Format
    public let duration: Double
    
    public init(format: Format, duration: Double) {
        self.format = format
        self.duration = duration
    }
}

public final class AnimationCacheItem {
    public enum Advance {
        case duration(Double)
        case frames(Int)
    }
    
    public let numFrames: Int
    private let advanceImpl: (Advance, AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame?
    
    public init(numFrames: Int, advanceImpl: @escaping (Advance, AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame?) {
        self.numFrames = numFrames
        self.advanceImpl = advanceImpl
    }
    
    public func advance(advance: Advance, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame? {
        return self.advanceImpl(advance, requestedFormat)
    }
}

public struct AnimationCacheItemDrawingSurface {
    public let argb: UnsafeMutablePointer<UInt8>
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let length: Int
    
    init(
        argb: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        length: Int
    ) {
        self.argb = argb
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.length = length
    }
}

public protocol AnimationCacheItemWriter: AnyObject {
    var queue: Queue { get }
    var isCancelled: Bool { get }
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int)
    func finish()
}

public final class AnimationCacheItemResult {
    public let item: AnimationCacheItem?
    public let isFinal: Bool
    
    public init(item: AnimationCacheItem?, isFinal: Bool) {
        self.item = item
        self.isFinal = isFinal
    }
}

public protocol AnimationCache: AnyObject {
    func get(sourceId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Signal<AnimationCacheItemResult, NoError>
    func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem?
    func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, completion: @escaping (AnimationCacheItem?) -> Void) -> Disposable
}

private func md5Hash(_ string: String) -> String {
    let hashData = string.data(using: .utf8)!.withUnsafeBytes { bytes -> Data in
        return CryptoMD5(bytes.baseAddress!, Int32(bytes.count))
    }
    return hashData.withUnsafeBytes { bytes -> String in
        let uintBytes = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
        return String(format: "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", uintBytes[0], uintBytes[1], uintBytes[2], uintBytes[3], uintBytes[4], uintBytes[5], uintBytes[6], uintBytes[7], uintBytes[8], uintBytes[9], uintBytes[10], uintBytes[11], uintBytes[12], uintBytes[13], uintBytes[14], uintBytes[15])
    }
}

private func itemSubpath(hashString: String, width: Int, height: Int) -> (directory: String, fileName: String) {
    assert(hashString.count == 32)
    var directory = ""
    
    for i in 0 ..< 1 {
        if !directory.isEmpty {
            directory.append("/")
        }
        directory.append(String(hashString[hashString.index(hashString.startIndex, offsetBy: i * 2) ..< hashString.index(hashString.startIndex, offsetBy: (i + 1) * 2)]))
    }
    
    return (directory, "\(hashString)_\(width)x\(height)")
}

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 {
        return numToRound
    }
    
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound;
    }
    
    return numToRound + multiple - remainder
}

private func compressData(data: Data, addSizeHeader: Bool = false) -> Data? {
    let algorithm: compression_algorithm = COMPRESSION_LZFSE
    
    let scratchData = malloc(compression_encode_scratch_buffer_size(algorithm))!
    defer {
        free(scratchData)
    }
    
    let headerSize = addSizeHeader ? 4 : 0
    var compressedData = Data(count: headerSize + data.count + 16 * 1024)
    let resultSize = compressedData.withUnsafeMutableBytes { buffer -> Int in
        guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return 0
        }
        
        if addSizeHeader {
            var decompressedSize: UInt32 = UInt32(data.count)
            memcpy(bytes, &decompressedSize, 4)
        }
        
        return data.withUnsafeBytes { sourceBuffer -> Int in
            return compression_encode_buffer(bytes.advanced(by: headerSize), buffer.count - headerSize, sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), sourceBuffer.count, scratchData, algorithm)
        }
    }
    
    if resultSize <= 0 {
        return nil
    }
    compressedData.count = headerSize + resultSize
    return compressedData
}

private func decompressData(data: Data, range: Range<Int>, decompressedSize: Int) -> Data? {
    let algorithm: compression_algorithm = COMPRESSION_LZFSE
    
    let scratchData = malloc(compression_decode_scratch_buffer_size(algorithm))!
    defer {
        free(scratchData)
    }
    
    var decompressedFrameData = Data(count: decompressedSize)
    let resultSize = decompressedFrameData.withUnsafeMutableBytes { buffer -> Int in
        guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return 0
        }
        return data.withUnsafeBytes { sourceBuffer -> Int in
            return compression_decode_buffer(bytes, buffer.count, sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: range.lowerBound), range.upperBound - range.lowerBound, scratchData, algorithm)
        }
    }
    
    if resultSize <= 0 {
        return nil
    }
    if decompressedFrameData.count != resultSize {
        decompressedFrameData.count = resultSize
    }
    return decompressedFrameData
}

private final class AnimationCacheItemWriterInternal {
    enum WriteError: Error {
        case generic
    }
    
    struct CompressedResult {
        var path: String
    }
    
    private struct FrameMetadata {
        var duration: Double
    }
    
    var isCancelled: Bool = false
    
    private let compressedPath: String
    private let file: ManagedFile
    private let compressedWriter: CompressedFileWriter
    
    private var currentYUVASurface: ImageYUVA420?
    private var currentDctData: DctData?
    private var currentDctCoefficients: DctCoefficientsYUVA420?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    
    private let dctQualityLuma: Int
    private let dctQualityChroma: Int
    
    init?(allocateTempFile: @escaping () -> String) {
        self.dctQualityLuma = 70
        self.dctQualityChroma = 88
        
        self.compressedPath = allocateTempFile()
        
        guard let file = ManagedFile(queue: nil, path: self.compressedPath, mode: .readwrite) else {
            return nil
        }
        guard let compressedWriter = CompressedFileWriter(file: file) else {
            return nil
        }
        self.file = file
        self.compressedWriter = compressedWriter
    }
    
    func add(with drawingBlock: (ImageYUVA420) -> Double?, proposedWidth: Int, proposedHeight: Int) throws {
        if self.isFailed || self.isFinished {
            return
        }
        
        guard !self.isFailed, !self.isFinished else {
            return
        }
        
        let width = roundUp(proposedWidth, multiple: 16)
        let height = roundUp(proposedWidth, multiple: 16)
        
        var isFirstFrame = false
        
        let yuvaSurface: ImageYUVA420
        if let current = self.currentYUVASurface {
            if current.yPlane.width == width && current.yPlane.height == height {
                yuvaSurface = current
            } else {
                self.isFailed = true
                return
            }
        } else {
            isFirstFrame = true
            yuvaSurface = ImageYUVA420(width: width, height: height, rowAlignment: nil)
            self.currentYUVASurface = yuvaSurface
        }
        
        let dctCoefficients: DctCoefficientsYUVA420
        if let current = self.currentDctCoefficients {
            if current.yPlane.width == width && current.yPlane.height == height {
                dctCoefficients = current
            } else {
                self.isFailed = true
                return
            }
        } else {
            dctCoefficients = DctCoefficientsYUVA420(width: width, height: height)
            self.currentDctCoefficients = dctCoefficients
        }
        
        let dctData: DctData
        if let current = self.currentDctData {
            dctData = current
        } else {
            dctData = DctData(generatingTablesAtQualityLuma: self.dctQualityLuma, chroma: self.dctQualityChroma)
            self.currentDctData = dctData
        }
        
        let duration = drawingBlock(yuvaSurface)
        
        guard let duration = duration else {
            return
        }
        
        yuvaSurface.dct(dctData: dctData, target: dctCoefficients)
        
        if isFirstFrame {
            self.file.write(4 as UInt32)
            
            self.file.write(UInt32(dctCoefficients.yPlane.width))
            self.file.write(UInt32(dctCoefficients.yPlane.height))
            
            let lumaDctTable = dctData.lumaTable.serializedData()
            self.file.write(UInt32(lumaDctTable.count))
            let _ = self.file.write(lumaDctTable)
            
            let chromaDctTable = dctData.chromaTable.serializedData()
            self.file.write(UInt32(chromaDctTable.count))
            let _ = self.file.write(chromaDctTable)
        
            self.contentLengthOffset = Int(self.file.position())
            self.file.write(0 as UInt32)
        }
        
        let frameLength = dctCoefficients.yPlane.data.count + dctCoefficients.uPlane.data.count + dctCoefficients.vPlane.data.count + dctCoefficients.aPlane.data.count
        try self.compressedWriter.writeUInt32(UInt32(frameLength))
        
        for i in 0 ..< 4 {
            let dctPlane: DctCoefficientPlane
            switch i {
            case 0:
                dctPlane = dctCoefficients.yPlane
            case 1:
                dctPlane = dctCoefficients.uPlane
            case 2:
                dctPlane = dctCoefficients.vPlane
            case 3:
                dctPlane = dctCoefficients.aPlane
            default:
                preconditionFailure()
            }
            
            try self.compressedWriter.writeUInt32(UInt32(dctPlane.data.count))
            try dctPlane.data.withUnsafeBytes { bytes in
                try self.compressedWriter.write(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bytes.count)
            }
        }
        
        self.frames.append(FrameMetadata(duration: duration))
    }
    
    func finish() throws -> CompressedResult {
        var shouldComplete = false
        
        do {
            if !self.isFinished {
                self.isFinished = true
                shouldComplete = true
                
                try self.compressedWriter.flush()
                
                guard let contentLengthOffset = self.contentLengthOffset else {
                    self.isFailed = true
                    throw WriteError.generic
                }
                assert(contentLengthOffset >= 0)
                
                let metadataPosition = file.position()
                let contentLength = Int(metadataPosition) - contentLengthOffset - 4
                file.seek(position: Int64(contentLengthOffset))
                file.write(UInt32(contentLength))
                
                file.seek(position: metadataPosition)
                file.write(UInt32(self.frames.count))
                for frame in self.frames {
                    file.write(Float32(frame.duration))
                }
                
                if !self.frames.isEmpty {
                } else {
                    self.isFailed = true
                    throw WriteError.generic
                }
                
                self.file._unsafeClose()
            }
        } catch let e {
            throw e
        }
        
        if shouldComplete {
            if !self.isFailed {
                return CompressedResult(path: self.compressedPath)
            } else {
                let _ = try? FileManager.default.removeItem(atPath: self.compressedPath)
                throw WriteError.generic
            }
        } else {
            throw WriteError.generic
        }
    }
}

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    struct CompressedResult {
        var animationPath: String
    }
    
    private struct FrameMetadata {
        var duration: Double
    }
    
    let queue: Queue
    var isCancelled: Bool = false
    
    private let compressedPath: String
    private var file: ManagedFile?
    private var compressedWriter: CompressedFileWriter?
    private let completion: (CompressedResult?) -> Void
    
    private var currentSurface: ImageARGB?
    private var currentYUVASurface: ImageYUVA420?
    private var currentDctData: DctData?
    private var currentDctCoefficients: DctCoefficientsYUVA420?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    
    private let dctQualityLuma: Int
    private let dctQualityChroma: Int
    
    private let lock = Lock()
    
    init?(queue: Queue, allocateTempFile: @escaping () -> String, completion: @escaping (CompressedResult?) -> Void) {
        self.dctQualityLuma = 70
        self.dctQualityChroma = 88
        
        self.queue = queue
        self.compressedPath = allocateTempFile()
        
        guard let file = ManagedFile(queue: nil, path: self.compressedPath, mode: .readwrite) else {
            return nil
        }
        self.file = file
        self.compressedWriter = CompressedFileWriter(file: file)
        self.completion = completion
    }
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int) {
        if self.isFailed || self.isFinished {
            return
        }
        
        self.lock.locked {
            guard !self.isFailed, !self.isFinished, let file = self.file, let compressedWriter = self.compressedWriter else {
                return
            }
            
            let width = roundUp(proposedWidth, multiple: 16)
            let height = roundUp(proposedWidth, multiple: 16)
            
            var isFirstFrame = false
            
            let surface: ImageARGB
            if let current = self.currentSurface {
                if current.argbPlane.width == width && current.argbPlane.height == height {
                    surface = current
                } else {
                    self.isFailed = true
                    return
                }
            } else {
                isFirstFrame = true
                
                surface = ImageARGB(width: width, height: height, rowAlignment: 32)
                self.currentSurface = surface
            }
            
            let yuvaSurface: ImageYUVA420
            if let current = self.currentYUVASurface {
                if current.yPlane.width == width && current.yPlane.height == height {
                    yuvaSurface = current
                } else {
                    self.isFailed = true
                    return
                }
            } else {
                yuvaSurface = ImageYUVA420(width: width, height: height, rowAlignment: nil)
                self.currentYUVASurface = yuvaSurface
            }
            
            let dctCoefficients: DctCoefficientsYUVA420
            if let current = self.currentDctCoefficients {
                if current.yPlane.width == width && current.yPlane.height == height {
                    dctCoefficients = current
                } else {
                    self.isFailed = true
                    return
                }
            } else {
                dctCoefficients = DctCoefficientsYUVA420(width: width, height: height)
                self.currentDctCoefficients = dctCoefficients
            }
            
            let dctData: DctData
            if let current = self.currentDctData {
                dctData = current
            } else {
                dctData = DctData(generatingTablesAtQualityLuma: self.dctQualityLuma, chroma: self.dctQualityChroma)
                self.currentDctData = dctData
            }
            
            let duration = surface.argbPlane.data.withUnsafeMutableBytes { bytes -> Double? in
                return drawingBlock(AnimationCacheItemDrawingSurface(
                    argb: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    width: width,
                    height: height,
                    bytesPerRow: surface.argbPlane.bytesPerRow,
                    length: bytes.count
                ))
            }
            
            guard let duration = duration else {
                return
            }
            
            surface.toYUVA420(target: yuvaSurface)
            yuvaSurface.dct(dctData: dctData, target: dctCoefficients)
            
            if isFirstFrame {
                file.write(4 as UInt32)
                
                file.write(UInt32(dctCoefficients.yPlane.width))
                file.write(UInt32(dctCoefficients.yPlane.height))
                
                let lumaDctTable = dctData.lumaTable.serializedData()
                file.write(UInt32(lumaDctTable.count))
                let _ = file.write(lumaDctTable)
                
                let chromaDctTable = dctData.chromaTable.serializedData()
                file.write(UInt32(chromaDctTable.count))
                let _ = file.write(chromaDctTable)
            
                self.contentLengthOffset = Int(file.position())
                file.write(0 as UInt32)
            }
            
            do {
                let frameLength = dctCoefficients.yPlane.data.count + dctCoefficients.uPlane.data.count + dctCoefficients.vPlane.data.count + dctCoefficients.aPlane.data.count
                try compressedWriter.writeUInt32(UInt32(frameLength))
                
                for i in 0 ..< 4 {
                    let dctPlane: DctCoefficientPlane
                    switch i {
                    case 0:
                        dctPlane = dctCoefficients.yPlane
                    case 1:
                        dctPlane = dctCoefficients.uPlane
                    case 2:
                        dctPlane = dctCoefficients.vPlane
                    case 3:
                        dctPlane = dctCoefficients.aPlane
                    default:
                        preconditionFailure()
                    }
                    
                    try compressedWriter.writeUInt32(UInt32(dctPlane.data.count))
                    try dctPlane.data.withUnsafeBytes { bytes in
                        try compressedWriter.write(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bytes.count)
                    }
                }
                
                self.frames.append(FrameMetadata(duration: duration))
            } catch {
                self.isFailed = true
            }
        }
    }
    
    func finish() {
        var shouldComplete = false
        self.lock.locked {
            if !self.isFinished {
                self.isFinished = true
                shouldComplete = true
                
                guard let contentLengthOffset = self.contentLengthOffset, let file = self.file, let compressedWriter = self.compressedWriter else {
                    self.isFailed = true
                    return
                }
                assert(contentLengthOffset >= 0)
                
                do {
                    try compressedWriter.flush()
                
                    let metadataPosition = file.position()
                    let contentLength = Int(metadataPosition) - contentLengthOffset - 4
                    file.seek(position: Int64(contentLengthOffset))
                    file.write(UInt32(contentLength))
                    
                    file.seek(position: metadataPosition)
                    file.write(UInt32(self.frames.count))
                    for frame in self.frames {
                        file.write(Float32(frame.duration))
                    }
                    
                    if !self.isFailed {
                        self.compressedWriter = nil
                        self.file = nil
                        
                        file._unsafeClose()
                    }
                } catch {
                    self.isFailed = true
                }
            }
        }
        
        if shouldComplete {
            if !self.isFailed {
                self.completion(CompressedResult(animationPath: self.compressedPath))
            } else {
                let _ = try? FileManager.default.removeItem(atPath: self.compressedPath)
                self.completion(nil)
            }
        }
    }
}

private final class AnimationCacheItemAccessor {
    private enum ReadError: Error {
        case generic
    }
    
    final class CurrentFrame {
        let index: Int
        var remainingDuration: Double
        let duration: Double
        let dctCoefficients: DctCoefficientsYUVA420
        
        init(index: Int, duration: Double, dctCoefficients: DctCoefficientsYUVA420) {
            self.index = index
            self.duration = duration
            self.remainingDuration = duration
            self.dctCoefficients = dctCoefficients
        }
    }
    
    struct FrameInfo {
        let duration: Double
    }
    
    private let data: Data
    private var compressedDataReader: DecompressedData?
    private let range: Range<Int>
    private let frameMapping: [Int: FrameInfo]
    private let width: Int
    private let height: Int
    private let durationMapping: [Double]
    
    private var currentFrame: CurrentFrame?
    
    private var currentYUVASurface: ImageYUVA420?
    private let currentDctData: DctData
    private var sharedDctCoefficients: DctCoefficientsYUVA420?
    
    init(data: Data, range: Range<Int>, frameMapping: [FrameInfo], width: Int, height: Int, dctData: DctData) {
        self.data = data
        self.range = range
        self.width = width
        self.height = height
        
        var resultFrameMapping: [Int: FrameInfo] = [:]
        var durationMapping: [Double] = []
        
        for i in 0 ..< frameMapping.count {
            let frame = frameMapping[i]
            resultFrameMapping[i] = frame
            durationMapping.append(frame.duration)
        }
        
        self.frameMapping = resultFrameMapping
        self.durationMapping = durationMapping
        
        self.currentDctData = dctData
    }
    
    private func loadNextFrame() {
        let index: Int
        if let currentFrame = self.currentFrame {
            if currentFrame.index + 1 >= self.durationMapping.count {
                index = 0
                self.compressedDataReader = nil
            } else {
                index = currentFrame.index + 1
            }
        } else {
            index = 0
            self.compressedDataReader = nil
        }
        
        if self.compressedDataReader == nil {
            self.compressedDataReader = DecompressedData(compressedData: self.data, dataRange: self.range)
        }
        
        guard let compressedDataReader = self.compressedDataReader else {
            self.currentFrame = nil
            return
        }
        
        do {
            let frameLength = Int(try compressedDataReader.readUInt32())
            
            let dctCoefficients: DctCoefficientsYUVA420
            if let sharedDctCoefficients = self.sharedDctCoefficients, sharedDctCoefficients.yPlane.width == self.width, sharedDctCoefficients.yPlane.height == self.height {
                dctCoefficients = sharedDctCoefficients
            } else {
                dctCoefficients = DctCoefficientsYUVA420(width: self.width, height: self.height)
                self.sharedDctCoefficients = dctCoefficients
            }
            
            var frameOffset = 0
            for i in 0 ..< 4 {
                let planeLength = Int(try compressedDataReader.readUInt32())
                if planeLength < 0 || planeLength > 20 * 1024 * 1024 {
                    throw ReadError.generic
                }
                
                let plane: DctCoefficientPlane
                switch i {
                case 0:
                    plane = dctCoefficients.yPlane
                case 1:
                    plane = dctCoefficients.uPlane
                case 2:
                    plane = dctCoefficients.vPlane
                case 3:
                    plane = dctCoefficients.aPlane
                default:
                    throw ReadError.generic
                }
                
                if planeLength != plane.data.count {
                    throw ReadError.generic
                }
                
                if frameOffset + plane.data.count > frameLength {
                    throw ReadError.generic
                }
                
                try plane.data.withUnsafeMutableBytes { bytes in
                    try compressedDataReader.read(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bytes.count)
                }
                frameOffset += plane.data.count
            }
            
            self.currentFrame = CurrentFrame(index: index, duration: self.durationMapping[index], dctCoefficients: dctCoefficients)
        } catch {
            self.currentFrame = nil
            self.compressedDataReader = nil
        }
    }
    
    func advance(advance: AnimationCacheItem.Advance, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame? {
        switch advance {
        case let .frames(count):
            for _ in 0 ..< count {
                self.loadNextFrame()
            }
        case let .duration(duration):
            var durationOverflow = duration
            while true {
                if let currentFrame = self.currentFrame {
                    currentFrame.remainingDuration -= durationOverflow
                    if currentFrame.remainingDuration <= 0.0 {
                        durationOverflow = -currentFrame.remainingDuration
                        self.loadNextFrame()
                    } else {
                        break
                    }
                } else {
                    self.loadNextFrame()
                    break
                }
            }
        }
        
        guard let currentFrame = self.currentFrame else {
            return nil
        }
        
        let yuvaSurface: ImageYUVA420
        switch requestedFormat {
        case .rgba:
            if let currentYUVASurface = self.currentYUVASurface {
                yuvaSurface = currentYUVASurface
            } else {
                yuvaSurface = ImageYUVA420(width: currentFrame.dctCoefficients.yPlane.width, height: currentFrame.dctCoefficients.yPlane.height, rowAlignment: nil)
            }
        case let .yuva(preferredRowAlignment):
            yuvaSurface = ImageYUVA420(width: currentFrame.dctCoefficients.yPlane.width, height: currentFrame.dctCoefficients.yPlane.height, rowAlignment: preferredRowAlignment)
        }
        
        currentFrame.dctCoefficients.idct(dctData: self.currentDctData, target: yuvaSurface)
        
        switch requestedFormat {
        case .rgba:
            let currentSurface = ImageARGB(width: yuvaSurface.yPlane.width, height: yuvaSurface.yPlane.height, rowAlignment: 32)
            yuvaSurface.toARGB(target: currentSurface)
            self.currentYUVASurface = yuvaSurface
            
            return AnimationCacheItemFrame(format: .rgba(data: currentSurface.argbPlane.data, width: currentSurface.argbPlane.width, height: currentSurface.argbPlane.height, bytesPerRow: currentSurface.argbPlane.bytesPerRow), duration: currentFrame.duration)
        case .yuva:
            return AnimationCacheItemFrame(
                format: .yuva(
                    y: AnimationCacheItemFrame.Plane(
                        data: yuvaSurface.yPlane.data,
                        width: yuvaSurface.yPlane.width,
                        height: yuvaSurface.yPlane.height,
                        bytesPerRow: yuvaSurface.yPlane.bytesPerRow
                    ),
                    u: AnimationCacheItemFrame.Plane(
                        data: yuvaSurface.uPlane.data,
                        width: yuvaSurface.uPlane.width,
                        height: yuvaSurface.uPlane.height,
                        bytesPerRow: yuvaSurface.uPlane.bytesPerRow
                    ),
                    v: AnimationCacheItemFrame.Plane(
                        data: yuvaSurface.vPlane.data,
                        width: yuvaSurface.vPlane.width,
                        height: yuvaSurface.vPlane.height,
                        bytesPerRow: yuvaSurface.vPlane.bytesPerRow
                    ),
                    a: AnimationCacheItemFrame.Plane(
                        data: yuvaSurface.aPlane.data,
                        width: yuvaSurface.aPlane.width,
                        height: yuvaSurface.aPlane.height,
                        bytesPerRow: yuvaSurface.aPlane.bytesPerRow
                    )
                ),
                duration: currentFrame.duration
            )
        }
    }
}

private func readData(data: Data, offset: Int, count: Int) -> Data {
    var result = Data(count: count)
    result.withUnsafeMutableBytes { bytes -> Void in
        data.withUnsafeBytes { dataBytes -> Void in
            memcpy(bytes.baseAddress!, dataBytes.baseAddress!.advanced(by: offset), count)
        }
    }
    return result
}

private func readUInt32(data: Data, offset: Int) -> UInt32 {
    var value: UInt32 = 0
    withUnsafeMutableBytes(of: &value, { bytes -> Void in
        data.withUnsafeBytes { dataBytes -> Void in
            memcpy(bytes.baseAddress!, dataBytes.baseAddress!.advanced(by: offset), 4)
        }
    })
    
    return value
}

private func readFloat32(data: Data, offset: Int) -> Float32 {
    var value: Float32 = 0
    withUnsafeMutableBytes(of: &value, { bytes -> Void in
        data.withUnsafeBytes { dataBytes -> Void in
            memcpy(bytes.baseAddress!, dataBytes.baseAddress!.advanced(by: offset), 4)
        }
    })
    
    return value
}

private func writeUInt32(data: inout Data, value: UInt32) {
    var value: UInt32 = value
    withUnsafeBytes(of: &value, { bytes -> Void in
        data.count += 4
        data.withUnsafeMutableBytes { dataBytes -> Void in
            memcpy(dataBytes.baseAddress!.advanced(by: dataBytes.count - 4), bytes.baseAddress!, 4)
        }
    })
}

private func writeFloat32(data: inout Data, value: Float32) {
    var value: Float32 = value
    withUnsafeBytes(of: &value, { bytes -> Void in
        data.count += 4
        data.withUnsafeMutableBytes { dataBytes -> Void in
            memcpy(dataBytes.baseAddress!.advanced(by: dataBytes.count - 4), bytes.baseAddress!, 4)
        }
    })
}

private final class CompressedFileWriter {
    enum WriteError: Error {
        case generic
    }
    
    private let file: ManagedFile
    private let stream: UnsafeMutablePointer<compression_stream>
    
    private let tempBufferSize: Int = 32 * 1024
    private let tempBuffer: UnsafeMutablePointer<UInt8>
    
    private var didFail: Bool = false
    
    init?(file: ManagedFile) {
        self.file = file
        
        self.stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        guard compression_stream_init(self.stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZFSE) != COMPRESSION_STATUS_ERROR else {
            self.stream.deallocate()
            return nil
        }
        
        self.tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.tempBufferSize)
    }
    
    deinit {
        compression_stream_destroy(self.stream)
        self.stream.deallocate()
        self.tempBuffer.deallocate()
    }
    
    func write(bytes: UnsafePointer<UInt8>, count: Int) throws {
        if self.didFail {
            throw WriteError.generic
        }
        
        self.stream.pointee.src_ptr = bytes
        self.stream.pointee.src_size = count
        
        while true {
            self.stream.pointee.dst_ptr = self.tempBuffer
            self.stream.pointee.dst_size = self.tempBufferSize
            
            let status = compression_stream_process(self.stream, 0)
            if status == COMPRESSION_STATUS_ERROR {
                self.didFail = true
                throw WriteError.generic
            }
            
            let writtenBytes = self.tempBufferSize - self.stream.pointee.dst_size
            if writtenBytes > 0 {
                let _ = self.file.write(self.tempBuffer, count: writtenBytes)
            }
            
            if status == COMPRESSION_STATUS_END {
                break
            } else {
                if self.stream.pointee.src_size == 0 {
                    break
                }
            }
        }
    }
    
    func flush() throws {
        if self.didFail {
            throw WriteError.generic
        }
        
        while true {
            self.stream.pointee.dst_ptr = self.tempBuffer
            self.stream.pointee.dst_size = self.tempBufferSize
            
            let status = compression_stream_process(self.stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            if status == COMPRESSION_STATUS_ERROR {
                self.didFail = true
                throw WriteError.generic
            }
            
            let writtenBytes = self.tempBufferSize - self.stream.pointee.dst_size
            if writtenBytes > 0 {
                let _ = self.file.write(self.tempBuffer, count: writtenBytes)
            }
            
            if status == COMPRESSION_STATUS_END {
                break
            }
        }
    }
    
    func writeUInt32(_ value: UInt32) throws {
        var value: UInt32 = value
        try withUnsafeBytes(of: &value, { bytes -> Void in
            try self.write(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
        })
    }
    
    func writeFloat32(_ value: Float32) throws {
        var value: Float32 = value
        try withUnsafeBytes(of: &value, { bytes -> Void in
            try self.write(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
        })
    }
}

private final class DecompressedData {
    enum ReadError: Error {
        case didReadToEnd
    }
    
    private let compressedData: Data
    private let dataRange: Range<Int>
    private let stream: UnsafeMutablePointer<compression_stream>
    private var isComplete = false
    
    init?(compressedData: Data, dataRange: Range<Int>) {
        self.compressedData = compressedData
        self.dataRange = dataRange
        
        self.stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        guard compression_stream_init(self.stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZFSE) != COMPRESSION_STATUS_ERROR else {
            self.stream.deallocate()
            return nil
        }
        
        self.compressedData.withUnsafeBytes { bytes in
            self.stream.pointee.src_ptr = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: dataRange.lowerBound)
            self.stream.pointee.src_size = dataRange.upperBound - dataRange.lowerBound
        }
    }
    
    deinit {
        compression_stream_destroy(self.stream)
        self.stream.deallocate()
    }
    
    func read(bytes: UnsafeMutablePointer<UInt8>, count: Int) throws {
        if self.isComplete {
            throw ReadError.didReadToEnd
        }
        
        self.stream.pointee.dst_ptr = bytes
        self.stream.pointee.dst_size = count
        
        let status = compression_stream_process(self.stream, 0)
        
        if status == COMPRESSION_STATUS_ERROR {
            self.isComplete = true
            throw ReadError.didReadToEnd
        } else if status == COMPRESSION_STATUS_END {
            if self.stream.pointee.src_size == 0 {
                self.isComplete = true
            }
        }
         
        if self.stream.pointee.dst_size != 0 {
            throw ReadError.didReadToEnd
        }
    }
    
    func readUInt32() throws -> UInt32 {
        var value: UInt32 = 0
        try withUnsafeMutableBytes(of: &value, { bytes -> Void in
            try self.read(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
        })
        return value
    }

    func readFloat32() throws -> Float32 {
        var value: Float32 = 0
        try withUnsafeMutableBytes(of: &value, { bytes -> Void in
            try self.read(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
        })
        return value
    }
}

private enum LoadItemError: Error {
    case dataError
}

private func loadItem(path: String) throws -> AnimationCacheItem {
    guard let compressedData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
        throw LoadItemError.dataError
    }
    
    var offset: Int = 0
    let dataLength = compressedData.count
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let formatVersion = readUInt32(data: compressedData, offset: offset)
    offset += 4
    if formatVersion != 4 {
        throw LoadItemError.dataError
    }
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let width = readUInt32(data: compressedData, offset: offset)
    offset += 4
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let height = readUInt32(data: compressedData, offset: offset)
    offset += 4
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let dctLumaTableLength = readUInt32(data: compressedData, offset: offset)
    offset += 4
    
    if offset + Int(dctLumaTableLength) > dataLength {
        throw LoadItemError.dataError
    }
    let dctLumaData = readData(data: compressedData, offset: offset, count: Int(dctLumaTableLength))
    offset += Int(dctLumaTableLength)
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let dctChromaTableLength = readUInt32(data: compressedData, offset: offset)
    offset += 4
    
    if offset + Int(dctChromaTableLength) > dataLength {
        throw LoadItemError.dataError
    }
    let dctChromaData = readData(data: compressedData, offset: offset, count: Int(dctChromaTableLength))
    offset += Int(dctChromaTableLength)
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let contentLength = Int(readUInt32(data: compressedData, offset: offset))
    offset += 4
    
    let compressedFrameDataRange = offset ..< (offset + contentLength)
    offset += contentLength
    
    if offset + 4 > dataLength {
        throw LoadItemError.dataError
    }
    let frameCount = Int(readUInt32(data: compressedData, offset: offset))
    offset += 4
    
    var frameMapping: [AnimationCacheItemAccessor.FrameInfo] = []
    for _ in 0 ..< frameCount {
        if offset + 4 > dataLength {
            throw LoadItemError.dataError
        }
        let frameDuration = readFloat32(data: compressedData, offset: offset)
        offset += 4
        
        frameMapping.append(AnimationCacheItemAccessor.FrameInfo(duration: Double(frameDuration)))
    }
    
    guard let dctData = DctData(lumaTable: dctLumaData, chromaTable: dctChromaData) else {
        throw LoadItemError.dataError
    }
    
    let itemAccessor = AnimationCacheItemAccessor(data: compressedData, range: compressedFrameDataRange, frameMapping: frameMapping, width: Int(width), height: Int(height), dctData: dctData)
    
    return AnimationCacheItem(numFrames: frameMapping.count, advanceImpl: { advance, requestedFormat in
        return itemAccessor.advance(advance: advance, requestedFormat: requestedFormat)
    })
}

private func adaptItemFromHigherResolution(itemPath: String, width: Int, height: Int, itemDirectoryPath: String, higherResolutionPath: String, allocateTempFile: @escaping () -> String) -> AnimationCacheItem? {
    guard let higherResolutionItem = try? loadItem(path: higherResolutionPath) else {
        return nil
    }
    guard let writer = AnimationCacheItemWriterInternal(allocateTempFile: allocateTempFile) else {
        return nil
    }
    
    do {
        for _ in 0 ..< higherResolutionItem.numFrames {
            try writer.add(with: { yuva in
                guard let frame = higherResolutionItem.advance(advance: .frames(1), requestedFormat: .yuva(rowAlignment: yuva.yPlane.rowAlignment)) else {
                    return nil
                }
                switch frame.format {
                case .rgba:
                    return nil
                case let .yuva(y, u, v, a):
                    yuva.yPlane.copyScaled(fromPlane: y)
                    yuva.uPlane.copyScaled(fromPlane: u)
                    yuva.vPlane.copyScaled(fromPlane: v)
                    yuva.aPlane.copyScaled(fromPlane: a)
                }
                
                return frame.duration
            }, proposedWidth: width, proposedHeight: height)
        }
        
        let result = try writer.finish()
        
        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
            return nil
        }
        let _ = try? FileManager.default.removeItem(atPath: itemPath)
        guard let _ = try? FileManager.default.moveItem(atPath: result.path, toPath: itemPath) else {
            return nil
        }
        guard let item = try? loadItem(path: itemPath) else {
            return nil
        }
        return item
    } catch {
        return nil
    }
}

private func generateFirstFrameFromItem(itemPath: String, animationItemPath: String, allocateTempFile: @escaping () -> String) -> Bool {
    guard let animationItem = try? loadItem(path: animationItemPath) else {
        return false
    }
    guard let writer = AnimationCacheItemWriterInternal(allocateTempFile: allocateTempFile) else {
        return false
    }
    
    do {
        for _ in 0 ..< min(1, animationItem.numFrames) {
            guard let frame = animationItem.advance(advance: .frames(1), requestedFormat: .yuva(rowAlignment: 1)) else {
                return false
            }
            switch frame.format {
            case .rgba:
                return false
            case let .yuva(y, u, v, a):
                try writer.add(with: { yuva in
                    assert(yuva.yPlane.bytesPerRow == y.bytesPerRow)
                    assert(yuva.uPlane.bytesPerRow == u.bytesPerRow)
                    assert(yuva.vPlane.bytesPerRow == v.bytesPerRow)
                    assert(yuva.aPlane.bytesPerRow == a.bytesPerRow)
                    
                    yuva.yPlane.copyScaled(fromPlane: y)
                    yuva.uPlane.copyScaled(fromPlane: u)
                    yuva.vPlane.copyScaled(fromPlane: v)
                    yuva.aPlane.copyScaled(fromPlane: a)
                    
                    return frame.duration
                }, proposedWidth: y.width, proposedHeight: y.height)
            }
        }
        
        let result = try writer.finish()
        
        let _ = try? FileManager.default.removeItem(atPath: itemPath)
        guard let _ = try? FileManager.default.moveItem(atPath: result.path, toPath: itemPath) else {
            return false
        }
        return true
    } catch {
        return false
    }
}

private func findHigherResolutionFileForAdaptation(itemDirectoryPath: String, baseName: String, baseSuffix: String, width: Int, height: Int) -> String? {
    var candidates: [(path: String, width: Int, height: Int)] = []
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: itemDirectoryPath), includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants, errorHandler: nil) {
        for url in enumerator {
            guard let url = url as? URL else {
                continue
            }
            let fileName = url.lastPathComponent
            if fileName.hasPrefix(baseName) {
                let scanner = Scanner(string: fileName)
                guard scanner.scanString(baseName, into: nil) else {
                    continue
                }
                var itemWidth: Int = 0
                guard scanner.scanInt(&itemWidth) else {
                    continue
                }
                guard scanner.scanString("x", into: nil) else {
                    continue
                }
                var itemHeight: Int = 0
                guard scanner.scanInt(&itemHeight) else {
                    continue
                }
                if !baseSuffix.isEmpty {
                    guard scanner.scanString(baseSuffix, into: nil) else {
                        continue
                    }
                }
                guard scanner.isAtEnd else {
                    continue
                }
                if itemWidth > width && itemHeight > height {
                    candidates.append((url.path, itemWidth, itemHeight))
                }
            }
        }
    }
    if !candidates.isEmpty {
        candidates.sort(by: { $0.width < $1.width })
        return candidates[0].path
    }
    return nil
}

public final class AnimationCacheImpl: AnimationCache {
    private final class Impl {
        private final class ItemContext {
            let subscribers = Bag<(AnimationCacheItemResult) -> Void>()
            let disposable = MetaDisposable()
            
            deinit {
                self.disposable.dispose()
            }
        }
        
        private let queue: Queue
        private let basePath: String
        private let allocateTempFile: () -> String
        
        private let fetchQueues: [Queue]
        private var nextFetchQueueIndex: Int = 0
        
        private var itemContexts: [String: ItemContext] = [:]
        
        init(queue: Queue, basePath: String, allocateTempFile: @escaping () -> String) {
            self.queue = queue
            
            let fetchQueueCount: Int
            if ProcessInfo.processInfo.activeProcessorCount > 2 {
                fetchQueueCount = 3
            } else {
                fetchQueueCount = 2
            }
            
            self.fetchQueues = (0 ..< fetchQueueCount).map { i in Queue(name: "AnimationCacheImpl-Fetch\(i)", qos: .default) }
            self.basePath = basePath
            self.allocateTempFile = allocateTempFile
        }
        
        deinit {
        }
        
        func get(sourceId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable, updateResult: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
            let itemPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)"
            let itemFirstFramePath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)-f"
            
            if FileManager.default.fileExists(atPath: itemPath), let item = try? loadItem(path: itemPath) {
                updateResult(AnimationCacheItemResult(item: item, isFinal: true))
                
                return EmptyDisposable
            }
            
            let itemContext: ItemContext
            var beginFetch = false
            if let current = self.itemContexts[sourceId] {
                itemContext = current
            } else {
                itemContext = ItemContext()
                self.itemContexts[sourceId] = itemContext
                beginFetch = true
            }
            
            let queue = self.queue
            let index = itemContext.subscribers.add(updateResult)
            
            updateResult(AnimationCacheItemResult(item: nil, isFinal: false))
            
            if beginFetch {
                let fetchQueueIndex = self.nextFetchQueueIndex
                self.nextFetchQueueIndex += 1
                let allocateTempFile = self.allocateTempFile
                guard let writer = AnimationCacheItemWriterImpl(queue: self.fetchQueues[fetchQueueIndex % self.fetchQueues.count], allocateTempFile: self.allocateTempFile, completion: { [weak self, weak itemContext] result in
                    queue.async {
                        guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[sourceId] else {
                            return
                        }
                        
                        strongSelf.itemContexts.removeValue(forKey: sourceId)
                        
                        guard let result = result else {
                            return
                        }
                        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
                            return
                        }
                        let _ = try? FileManager.default.removeItem(atPath: itemPath)
                        guard let _ = try? FileManager.default.moveItem(atPath: result.animationPath, toPath: itemPath) else {
                            return
                        }
                        
                        let _ = generateFirstFrameFromItem(itemPath: itemFirstFramePath, animationItemPath: itemPath, allocateTempFile: allocateTempFile)
                        
                        guard let item = try? loadItem(path: itemPath) else {
                            return
                        }
                        
                        for f in itemContext.subscribers.copyItems() {
                            f(AnimationCacheItemResult(item: item, isFinal: true))
                        }
                    }
                }) else {
                    return EmptyDisposable
                }
                
                let fetchDisposable = MetaDisposable()
                fetchDisposable.set(fetch(size, writer))
                
                itemContext.disposable.set(ActionDisposable { [weak writer] in
                    if let writer = writer {
                        writer.isCancelled = true
                    }
                    
                    fetchDisposable.dispose()
                })
            }
            
            return ActionDisposable { [weak self, weak itemContext] in
                queue.async {
                    guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[sourceId] else {
                        return
                    }
                    itemContext.subscribers.remove(index)
                    if itemContext.subscribers.isEmpty {
                        itemContext.disposable.dispose()
                        strongSelf.itemContexts.removeValue(forKey: sourceId)
                    }
                }
            }
        }
        
        static func getFirstFrameSynchronously(basePath: String, sourceId: String, size: CGSize, allocateTempFile: @escaping () -> String) -> AnimationCacheItem? {
            let hashString = md5Hash(sourceId)
            let sourceIdPath = itemSubpath(hashString: hashString, width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(basePath)/\(sourceIdPath.directory)"
            let itemFirstFramePath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)-f"
            
            if FileManager.default.fileExists(atPath: itemFirstFramePath) {
                if let item = try? loadItem(path: itemFirstFramePath) {
                    return item
                }
            }
            
            if let adaptationItemPath = findHigherResolutionFileForAdaptation(itemDirectoryPath: itemDirectoryPath, baseName: "\(hashString)_", baseSuffix: "-f", width: Int(size.width), height: Int(size.height)) {
                if let adaptedItem = adaptItemFromHigherResolution(itemPath: itemFirstFramePath, width: Int(size.width), height: Int(size.height), itemDirectoryPath: itemDirectoryPath, higherResolutionPath: adaptationItemPath, allocateTempFile: allocateTempFile) {
                    return adaptedItem
                }
            }
            
            return nil
        }
        
        static func getFirstFrame(basePath: String, sourceId: String, size: CGSize, allocateTempFile: @escaping () -> String, completion: @escaping (AnimationCacheItem?) -> Void) -> Disposable {
            let hashString = md5Hash(sourceId)
            let sourceIdPath = itemSubpath(hashString: hashString, width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(basePath)/\(sourceIdPath.directory)"
            let itemFirstFramePath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)-f"
            
            if FileManager.default.fileExists(atPath: itemFirstFramePath), let item = try? loadItem(path: itemFirstFramePath) {
                completion(item)
                return EmptyDisposable
            }
            
            if let adaptationItemPath = findHigherResolutionFileForAdaptation(itemDirectoryPath: itemDirectoryPath, baseName: "\(hashString)_", baseSuffix: "-f", width: Int(size.width), height: Int(size.height)) {
                if let adaptedItem = adaptItemFromHigherResolution(itemPath: itemFirstFramePath, width: Int(size.width), height: Int(size.height), itemDirectoryPath: itemDirectoryPath, higherResolutionPath: adaptationItemPath, allocateTempFile: allocateTempFile) {
                    completion(adaptedItem)
                    return EmptyDisposable
                }
            }
            
            completion(nil)
            return EmptyDisposable
        }
    }
    
    private let queue: Queue
    private let basePath: String
    private let impl: QueueLocalObject<Impl>
    private let allocateTempFile: () -> String
    
    public init(basePath: String, allocateTempFile: @escaping () -> String) {
        let queue = Queue()
        self.queue = queue
        self.basePath = basePath
        self.allocateTempFile = allocateTempFile
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, basePath: basePath, allocateTempFile: allocateTempFile)
        })
    }
    
    public func get(sourceId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Signal<AnimationCacheItemResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.get(sourceId: sourceId, size: size, fetch: fetch, updateResult: { result in
                    subscriber.putNext(result)
                    if result.isFinal {
                        subscriber.putCompletion()
                    }
                }))
            }
            
            return disposable
        }
        |> runOn(self.queue)
    }
    
    public func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem? {
        return Impl.getFirstFrameSynchronously(basePath: self.basePath, sourceId: sourceId, size: size, allocateTempFile: self.allocateTempFile)
    }
    
    public func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, completion: @escaping (AnimationCacheItem?) -> Void) -> Disposable {
        let disposable = MetaDisposable()
        
        let basePath = self.basePath
        let allocateTempFile = self.allocateTempFile
        queue.async {
            disposable.set(Impl.getFirstFrame(basePath: basePath, sourceId: sourceId, size: size, allocateTempFile: allocateTempFile, completion: completion))
        }
        
        return disposable
    }
}
