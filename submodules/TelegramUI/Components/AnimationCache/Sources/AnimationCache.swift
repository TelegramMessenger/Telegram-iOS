import Foundation
import UIKit
import SwiftSignalKit
import CryptoUtils
import ManagedFile
import Compression

private let algorithm: compression_algorithm = COMPRESSION_LZFSE

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
    
    public struct AdvanceResult {
        public let frame: AnimationCacheItemFrame
        public let didLoop: Bool
        
        public init(frame: AnimationCacheItemFrame, didLoop: Bool) {
            self.frame = frame
            self.didLoop = didLoop
        }
    }
    
    public let numFrames: Int
    private let advanceImpl: (Advance, AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult?
    private let resetImpl: () -> Void
    
    public init(numFrames: Int, advanceImpl: @escaping (Advance, AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult?, resetImpl: @escaping () -> Void) {
        self.numFrames = numFrames
        self.advanceImpl = advanceImpl
        self.resetImpl = resetImpl
    }
    
    public func advance(advance: Advance, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult? {
        return self.advanceImpl(advance, requestedFormat)
    }
    
    public func reset() {
        self.resetImpl()
    }
}

public struct AnimationCacheItemDrawingSurface {
    public let argb: UnsafeMutablePointer<UInt8>
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let length: Int
    
    public init(
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
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool)
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

public struct AnimationCacheFetchOptions {
    public let size: CGSize
    public let writer: AnimationCacheItemWriter
    public let firstFrameOnly: Bool
    
    public init(
        size: CGSize,
        writer: AnimationCacheItemWriter,
        firstFrameOnly: Bool
    ) {
        self.size = size
        self.writer = writer
        self.firstFrameOnly = firstFrameOnly
    }
}

public protocol AnimationCache: AnyObject {
    func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Signal<AnimationCacheItemResult, NoError>
    func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem?
    func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable
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

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    enum WriteError: Error {
        case generic
    }
    
    struct CompressedResult {
        var animationPath: String
    }
    
    private struct FrameMetadata {
        var duration: Double
    }
    
    var queue: Queue {
        return self.innerQueue
    }
    let innerQueue: Queue
    var isCancelled: Bool = false
    
    private let compressedPath: String
    private var file: ManagedFile?
    private var compressedWriter: CompressedFileWriter?
    private let completion: (CompressedResult?) -> Void
    
    
    private var currentSurface: ImageARGB?
    private var currentYUVASurface: ImageYUVA420?
    private var currentFrameFloat: FloatCoefficientsYUVA420?
    private var previousFrameCoefficients: DctCoefficientsYUVA420?
    private var deltaFrameFloat: FloatCoefficientsYUVA420?
    private var previousYUVASurface: ImageYUVA420?
    private var currentDctData: DctData?
    private var differenceCoefficients: DctCoefficientsYUVA420?
    private var currentDctCoefficients: DctCoefficientsYUVA420?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    
    private let dctQualityLuma: Int
    private let dctQualityChroma: Int
    private let dctQualityDelta: Int
    
    private let lock = Lock()
    
    init?(queue: Queue, allocateTempFile: @escaping () -> String, completion: @escaping (CompressedResult?) -> Void) {
        self.dctQualityLuma = 70
        self.dctQualityChroma = 88
        self.dctQualityDelta = 22
        
        self.innerQueue = queue
        self.compressedPath = allocateTempFile()
        
        guard let file = ManagedFile(queue: nil, path: self.compressedPath, mode: .readwrite) else {
            return nil
        }
        self.file = file
        self.compressedWriter = CompressedFileWriter(file: file)
        self.completion = completion
    }
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool) {
        do {
            try self.lock.throwingLocked {
                let width = roundUp(proposedWidth, multiple: 16)
                let height = roundUp(proposedHeight, multiple: 16)
                
                let surface: ImageARGB
                if let current = self.currentSurface {
                    if current.argbPlane.width == width && current.argbPlane.height == height {
                        surface = current
                        surface.argbPlane.data.withUnsafeMutableBytes { bytes -> Void in
                            memset(bytes.baseAddress!, 0, bytes.count)
                        }
                    } else {
                        self.isFailed = true
                        return
                    }
                } else {
                    surface = ImageARGB(width: width, height: height, rowAlignment: 32)
                    self.currentSurface = surface
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
                
                try addInternal(with: { yuvaSurface in
                    surface.toYUVA420(target: yuvaSurface)
                    
                    return duration
                }, width: width, height: height, insertKeyframe: insertKeyframe)
            }
        } catch {
        }
    }
    
    func addYUV(with drawingBlock: (ImageYUVA420) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool) throws {
        let width = roundUp(proposedWidth, multiple: 16)
        let height = roundUp(proposedHeight, multiple: 16)
        
        do {
            try self.lock.throwingLocked {
                try addInternal(with: { yuvaSurface in
                    return drawingBlock(yuvaSurface)
                }, width: width, height: height, insertKeyframe: insertKeyframe)
            }
        } catch {
        }
    }
    
    func addInternal(with drawingBlock: (ImageYUVA420) -> Double?, width: Int, height: Int, insertKeyframe: Bool) throws {
        if width == 0 || height == 0 {
            self.isFailed = true
            throw WriteError.generic
        }
        if self.isFailed || self.isFinished {
            throw WriteError.generic
        }
        
        guard !self.isFailed, !self.isFinished, let file = self.file, let compressedWriter = self.compressedWriter else {
            throw WriteError.generic
        }
        
        var isFirstFrame = false
        
        let yuvaSurface: ImageYUVA420
        if let current = self.currentYUVASurface {
            if current.yPlane.width == width && current.yPlane.height == height {
                yuvaSurface = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            isFirstFrame = true
            
            yuvaSurface = ImageYUVA420(width: width, height: height, rowAlignment: nil)
            self.currentYUVASurface = yuvaSurface
        }
        
        let currentFrameFloat: FloatCoefficientsYUVA420
        if let current = self.currentFrameFloat {
            if current.yPlane.width == width && current.yPlane.height == height {
                currentFrameFloat = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            currentFrameFloat = FloatCoefficientsYUVA420(width: width, height: height)
            self.currentFrameFloat = currentFrameFloat
        }
        
        let previousFrameCoefficients: DctCoefficientsYUVA420
        if let current = self.previousFrameCoefficients {
            if current.yPlane.width == width && current.yPlane.height == height {
                previousFrameCoefficients = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            previousFrameCoefficients = DctCoefficientsYUVA420(width: width, height: height)
            self.previousFrameCoefficients = previousFrameCoefficients
        }
        
        let deltaFrameFloat: FloatCoefficientsYUVA420
        if let current = self.deltaFrameFloat {
            if current.yPlane.width == width && current.yPlane.height == height {
                deltaFrameFloat = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            deltaFrameFloat = FloatCoefficientsYUVA420(width: width, height: height)
            self.deltaFrameFloat = deltaFrameFloat
        }
        
        let dctData: DctData
        if let current = self.currentDctData {
            dctData = current
        } else {
            dctData = DctData(generatingTablesAtQualityLuma: self.dctQualityLuma, chroma: self.dctQualityChroma, delta: self.dctQualityDelta)
            self.currentDctData = dctData
        }
        
        let duration = drawingBlock(yuvaSurface)
        
        guard let duration = duration else {
            return
        }
        
        let dctCoefficients: DctCoefficientsYUVA420
        if let current = self.currentDctCoefficients {
            if current.yPlane.width == width && current.yPlane.height == height {
                dctCoefficients = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            dctCoefficients = DctCoefficientsYUVA420(width: width, height: height)
            self.currentDctCoefficients = dctCoefficients
        }
        
        let differenceCoefficients: DctCoefficientsYUVA420
        if let current = self.differenceCoefficients {
            if current.yPlane.width == width && current.yPlane.height == height {
                differenceCoefficients = current
            } else {
                self.isFailed = true
                throw WriteError.generic
            }
        } else {
            differenceCoefficients = DctCoefficientsYUVA420(width: width, height: height)
            self.differenceCoefficients = differenceCoefficients
        }
        
        #if !arch(arm64)
        var insertKeyframe = insertKeyframe
        insertKeyframe = true
        #endif
        
        let previousYUVASurface: ImageYUVA420
        if let current = self.previousYUVASurface {
            previousYUVASurface = current
        } else {
            previousYUVASurface = ImageYUVA420(width: dctCoefficients.yPlane.width, height: dctCoefficients.yPlane.height, rowAlignment: nil)
            self.previousYUVASurface = previousYUVASurface
        }
        
        let isKeyframe: Bool
        if !isFirstFrame && !insertKeyframe {
            isKeyframe = false
            
            //previous + delta = current
            //delta = current - previous
            yuvaSurface.toCoefficients(target: differenceCoefficients)
            differenceCoefficients.subtract(other: previousFrameCoefficients)
            differenceCoefficients.dct4x4(dctData: dctData, target: dctCoefficients)
            
            //previous + delta = current
            dctCoefficients.idct4x4Add(dctData: dctData, target: previousFrameCoefficients)
            //previousFrameCoefficients.add(other: differenceCoefficients)
        } else {
            isKeyframe = true
            
            yuvaSurface.dct8x8(dctData: dctData, target: dctCoefficients)
            
            dctCoefficients.idct8x8(dctData: dctData, target: yuvaSurface)
            yuvaSurface.toCoefficients(target: previousFrameCoefficients)
        }
        
        if isFirstFrame {
            file.write(6 as UInt32)
            
            file.write(UInt32(dctCoefficients.yPlane.width))
            file.write(UInt32(dctCoefficients.yPlane.height))
            
            let lumaDctTable = dctData.lumaTable.serializedData()
            file.write(UInt32(lumaDctTable.count))
            let _ = file.write(lumaDctTable)
            
            let chromaDctTable = dctData.chromaTable.serializedData()
            file.write(UInt32(chromaDctTable.count))
            let _ = file.write(chromaDctTable)
            
            let deltaDctTable = dctData.deltaTable.serializedData()
            file.write(UInt32(deltaDctTable.count))
            let _ = file.write(deltaDctTable)
        
            self.contentLengthOffset = Int(file.position())
            file.write(0 as UInt32)
        }
        
        do {
            let frameLength = dctCoefficients.yPlane.data.count + dctCoefficients.uPlane.data.count + dctCoefficients.vPlane.data.count + dctCoefficients.aPlane.data.count
            try compressedWriter.writeUInt32(UInt32(frameLength))
            
            try compressedWriter.writeUInt32(isKeyframe ? 1 : 0)
            
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
            throw WriteError.generic
        }
    }
    
    func finish() {
        do {
            let result = try self.finishInternal()
            self.completion(result)
        } catch {
        }
    }
     
    func finishInternal() throws -> CompressedResult? {
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
                return CompressedResult(animationPath: self.compressedPath)
            } else {
                let _ = try? FileManager.default.removeItem(atPath: self.compressedPath)
                return nil
            }
        } else {
           return nil
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
        let yuva: ImageYUVA420
        
        init(index: Int, duration: Double, yuva: ImageYUVA420) {
            self.index = index
            self.duration = duration
            self.remainingDuration = duration
            self.yuva = yuva
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
    private var currentCoefficients: DctCoefficientsYUVA420?
    private let currentDctData: DctData
    private var sharedDctCoefficients: DctCoefficientsYUVA420?
    private var deltaCoefficients: DctCoefficientsYUVA420?
    
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
    
    private func loadNextFrame() -> Bool {
        var didLoop = false
        let index: Int
        if let currentFrame = self.currentFrame {
            if currentFrame.index + 1 >= self.durationMapping.count {
                index = 0
                self.compressedDataReader = nil
                didLoop = true
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
            return didLoop
        }
        
        do {
            let frameLength = Int(try compressedDataReader.readUInt32())
            
            let frameType = Int(try compressedDataReader.readUInt32())
            
            let dctCoefficients: DctCoefficientsYUVA420
            if let sharedDctCoefficients = self.sharedDctCoefficients, sharedDctCoefficients.yPlane.width == self.width, sharedDctCoefficients.yPlane.height == self.height, !"".isEmpty {
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
            
            let yuvaSurface: ImageYUVA420
            if let currentYUVASurface = self.currentYUVASurface {
                yuvaSurface = currentYUVASurface
            } else {
                yuvaSurface = ImageYUVA420(width: dctCoefficients.yPlane.width, height: dctCoefficients.yPlane.height, rowAlignment: nil)
            }
            
            let currentCoefficients: DctCoefficientsYUVA420
            if let current = self.currentCoefficients {
                currentCoefficients = current
            } else {
                currentCoefficients = DctCoefficientsYUVA420(width: yuvaSurface.yPlane.width, height: yuvaSurface.yPlane.height)
                self.currentCoefficients = currentCoefficients
            }
            
            /*let deltaCoefficients: DctCoefficientsYUVA420
            if let current = self.deltaCoefficients {
                deltaCoefficients = current
            } else {
                deltaCoefficients = DctCoefficientsYUVA420(width: yuvaSurface.yPlane.width, height: yuvaSurface.yPlane.height)
                self.deltaCoefficients = deltaCoefficients
            }*/
            
            switch frameType {
            case 1:
                dctCoefficients.idct8x8(dctData: self.currentDctData, target: yuvaSurface)
                yuvaSurface.toCoefficients(target: currentCoefficients)
            default:
                dctCoefficients.idct4x4Add(dctData: self.currentDctData, target: currentCoefficients)
                //currentCoefficients.add(other: deltaCoefficients)
                
                currentCoefficients.toYUVA420(target: yuvaSurface)
            }
            
            self.currentFrame = CurrentFrame(index: index, duration: self.durationMapping[index], yuva: yuvaSurface)
        } catch {
            self.currentFrame = nil
            self.compressedDataReader = nil
        }
        
        return didLoop
    }
    
    func reset() {
        self.currentFrame = nil
    }
    
    func advance(advance: AnimationCacheItem.Advance, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItem.AdvanceResult? {
        var didLoop = false
        switch advance {
        case let .frames(count):
            for _ in 0 ..< count {
                if self.loadNextFrame() {
                    didLoop = true
                }
            }
        case let .duration(duration):
            var durationOverflow = duration
            while true {
                if let currentFrame = self.currentFrame {
                    currentFrame.remainingDuration -= durationOverflow
                    if currentFrame.remainingDuration <= 0.0 {
                        durationOverflow = -currentFrame.remainingDuration
                        if self.loadNextFrame() {
                            didLoop = true
                        }
                    } else {
                        break
                    }
                } else {
                    if self.loadNextFrame() {
                        didLoop = true
                    }
                    break
                }
            }
        }
        
        guard let currentFrame = self.currentFrame else {
            return nil
        }
        
        switch requestedFormat {
        case .rgba:
            let currentSurface = ImageARGB(width: currentFrame.yuva.yPlane.width, height: currentFrame.yuva.yPlane.height, rowAlignment: 32)
            currentFrame.yuva.toARGB(target: currentSurface)
            
            return AnimationCacheItem.AdvanceResult(
                frame: AnimationCacheItemFrame(format: .rgba(data: currentSurface.argbPlane.data, width: currentSurface.argbPlane.width, height: currentSurface.argbPlane.height, bytesPerRow: currentSurface.argbPlane.bytesPerRow), duration: currentFrame.duration),
                didLoop: didLoop
            )
        case .yuva:
            return AnimationCacheItem.AdvanceResult(
                frame: AnimationCacheItemFrame(
                    format: .yuva(
                        y: AnimationCacheItemFrame.Plane(
                            data: currentFrame.yuva.yPlane.data,
                            width: currentFrame.yuva.yPlane.width,
                            height: currentFrame.yuva.yPlane.height,
                            bytesPerRow: currentFrame.yuva.yPlane.bytesPerRow
                        ),
                        u: AnimationCacheItemFrame.Plane(
                            data: currentFrame.yuva.uPlane.data,
                            width: currentFrame.yuva.uPlane.width,
                            height: currentFrame.yuva.uPlane.height,
                            bytesPerRow: currentFrame.yuva.uPlane.bytesPerRow
                        ),
                        v: AnimationCacheItemFrame.Plane(
                            data: currentFrame.yuva.vPlane.data,
                            width: currentFrame.yuva.vPlane.width,
                            height: currentFrame.yuva.vPlane.height,
                            bytesPerRow: currentFrame.yuva.vPlane.bytesPerRow
                        ),
                        a: AnimationCacheItemFrame.Plane(
                            data: currentFrame.yuva.aPlane.data,
                            width: currentFrame.yuva.aPlane.width,
                            height: currentFrame.yuva.aPlane.height,
                            bytesPerRow: currentFrame.yuva.aPlane.bytesPerRow
                        )
                    ),
                    duration: currentFrame.duration
                ),
                didLoop: didLoop
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
    
    private let tempOutputBufferSize: Int = 64 * 1024
    private let tempOutputBuffer: UnsafeMutablePointer<UInt8>
    private let tempInputBufferCapacity: Int = 64 * 1024
    private let tempInputBuffer: UnsafeMutablePointer<UInt8>
    private var tempInputBufferSize: Int = 0
    
    private var didFail: Bool = false
    
    init?(file: ManagedFile) {
        self.file = file
        
        self.stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        guard compression_stream_init(self.stream, COMPRESSION_STREAM_ENCODE, algorithm) != COMPRESSION_STATUS_ERROR else {
            self.stream.deallocate()
            return nil
        }
        
        self.tempOutputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.tempOutputBufferSize)
        self.tempInputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.tempInputBufferCapacity)
    }
    
    deinit {
        compression_stream_destroy(self.stream)
        self.stream.deallocate()
        self.tempOutputBuffer.deallocate()
        self.tempInputBuffer.deallocate()
    }
    
    private func flushBuffer() throws {
        if self.didFail {
            throw WriteError.generic
        }
        
        if self.tempInputBufferSize <= 0 {
            return
        }
        
        self.stream.pointee.src_ptr = UnsafePointer(self.tempInputBuffer)
        self.stream.pointee.src_size = self.tempInputBufferSize
        
        while true {
            self.stream.pointee.dst_ptr = self.tempOutputBuffer
            self.stream.pointee.dst_size = self.tempOutputBufferSize
            
            let status = compression_stream_process(self.stream, 0)
            if status == COMPRESSION_STATUS_ERROR {
                self.didFail = true
                throw WriteError.generic
            }
            
            let writtenBytes = self.tempOutputBufferSize - self.stream.pointee.dst_size
            if writtenBytes > 0 {
                let _ = self.file.write(self.tempOutputBuffer, count: writtenBytes)
            }
            
            if status == COMPRESSION_STATUS_END {
                break
            } else {
                if self.stream.pointee.src_size == 0 {
                    break
                }
            }
        }
        
        self.tempInputBufferSize = 0
    }
    
    func write(bytes: UnsafePointer<UInt8>, count: Int) throws {
        var writtenBytes = 0
        while writtenBytes < count {
            let availableBytes = self.tempInputBufferCapacity - self.tempInputBufferSize
            if availableBytes == 0 {
                try flushBuffer()
            } else {
                let writeCount = min(availableBytes, count - writtenBytes)
                
                memcpy(self.tempInputBuffer.advanced(by: self.tempInputBufferSize), bytes.advanced(by: writtenBytes), writeCount)
                self.tempInputBufferSize += writeCount
                writtenBytes += writeCount
            }
        }
    }
    
    func flush() throws {
        if self.didFail {
            throw WriteError.generic
        }
        
        try self.flushBuffer()
        
        while true {
            self.stream.pointee.dst_ptr = self.tempOutputBuffer
            self.stream.pointee.dst_size = self.tempOutputBufferSize
            
            let status = compression_stream_process(self.stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            if status == COMPRESSION_STATUS_ERROR {
                self.didFail = true
                throw WriteError.generic
            }
            
            let writtenBytes = self.tempOutputBufferSize - self.stream.pointee.dst_size
            if writtenBytes > 0 {
                let _ = self.file.write(self.tempOutputBuffer, count: writtenBytes)
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
        guard compression_stream_init(self.stream, COMPRESSION_STREAM_DECODE, algorithm) != COMPRESSION_STATUS_ERROR else {
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
    if formatVersion != 6 {
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
    let dctDeltaTableLength = readUInt32(data: compressedData, offset: offset)
    offset += 4
    
    if offset + Int(dctDeltaTableLength) > dataLength {
        throw LoadItemError.dataError
    }
    let dctDeltaData = readData(data: compressedData, offset: offset, count: Int(dctDeltaTableLength))
    offset += Int(dctDeltaTableLength)
    
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
    
    guard let dctData = DctData(lumaTable: dctLumaData, chromaTable: dctChromaData, deltaTable: dctDeltaData) else {
        throw LoadItemError.dataError
    }
    
    let itemAccessor = AnimationCacheItemAccessor(data: compressedData, range: compressedFrameDataRange, frameMapping: frameMapping, width: Int(width), height: Int(height), dctData: dctData)
    
    return AnimationCacheItem(numFrames: frameMapping.count, advanceImpl: { advance, requestedFormat in
        return itemAccessor.advance(advance: advance, requestedFormat: requestedFormat)
    }, resetImpl: {
        itemAccessor.reset()
    })
}

private func adaptItemFromHigherResolution(currentQueue: Queue, itemPath: String, width: Int, height: Int, itemDirectoryPath: String, higherResolutionPath: String, allocateTempFile: @escaping () -> String) -> AnimationCacheItem? {
    guard let higherResolutionItem = try? loadItem(path: higherResolutionPath) else {
        return nil
    }
    guard let writer = AnimationCacheItemWriterImpl(queue: currentQueue, allocateTempFile: allocateTempFile, completion: {
        _ in
    }) else {
        return nil
    }
    
    do {
        for _ in 0 ..< higherResolutionItem.numFrames {
            try writer.addYUV(with: { yuva in
                guard let frame = higherResolutionItem.advance(advance: .frames(1), requestedFormat: .yuva(rowAlignment: yuva.yPlane.rowAlignment)) else {
                    return nil
                }
                switch frame.frame.format {
                case .rgba:
                    return nil
                case let .yuva(y, u, v, a):
                    yuva.yPlane.copyScaled(fromPlane: y)
                    yuva.uPlane.copyScaled(fromPlane: u)
                    yuva.vPlane.copyScaled(fromPlane: v)
                    yuva.aPlane.copyScaled(fromPlane: a)
                }
                
                return frame.frame.duration
            }, proposedWidth: width, proposedHeight: height, insertKeyframe: true)
        }
        
        guard let result = try writer.finishInternal() else {
            return nil
        }
        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
            return nil
        }
        let _ = try? FileManager.default.removeItem(atPath: itemPath)
        guard let _ = try? FileManager.default.moveItem(atPath: result.animationPath, toPath: itemPath) else {
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

private func generateFirstFrameFromItem(currentQueue: Queue, itemPath: String, animationItemPath: String, allocateTempFile: @escaping () -> String) -> Bool {
    guard let animationItem = try? loadItem(path: animationItemPath) else {
        return false
    }
    guard let writer = AnimationCacheItemWriterImpl(queue: currentQueue, allocateTempFile: allocateTempFile, completion: { _ in
    }) else {
        return false
    }
    
    do {
        for _ in 0 ..< min(1, animationItem.numFrames) {
            guard let frame = animationItem.advance(advance: .frames(1), requestedFormat: .yuva(rowAlignment: 1)) else {
                return false
            }
            switch frame.frame.format {
            case .rgba:
                return false
            case let .yuva(y, u, v, a):
                try writer.addYUV(with: { yuva in
                    assert(yuva.yPlane.bytesPerRow == y.bytesPerRow)
                    assert(yuva.uPlane.bytesPerRow == u.bytesPerRow)
                    assert(yuva.vPlane.bytesPerRow == v.bytesPerRow)
                    assert(yuva.aPlane.bytesPerRow == a.bytesPerRow)
                    
                    yuva.yPlane.copyScaled(fromPlane: y)
                    yuva.uPlane.copyScaled(fromPlane: u)
                    yuva.vPlane.copyScaled(fromPlane: v)
                    yuva.aPlane.copyScaled(fromPlane: a)
                    
                    return frame.frame.duration
                }, proposedWidth: y.width, proposedHeight: y.height, insertKeyframe: true)
            }
        }
        
        guard let result = try writer.finishInternal() else {
            return false
        }
        
        let _ = try? FileManager.default.removeItem(atPath: itemPath)
        guard let _ = try? FileManager.default.moveItem(atPath: result.animationPath, toPath: itemPath) else {
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
        private struct ItemKey: Hashable {
            var id: String
            var width: Int
            var height: Int
        }
        
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
        
        private var itemContexts: [ItemKey: ItemContext] = [:]
        
        init(queue: Queue, basePath: String, allocateTempFile: @escaping () -> String) {
            self.queue = queue
            
            let fetchQueueCount: Int
            if ProcessInfo.processInfo.processorCount > 2 {
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
        
        func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable, updateResult: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
            let itemPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)"
            let itemFirstFramePath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)-f"
            
            if FileManager.default.fileExists(atPath: itemPath), let item = try? loadItem(path: itemPath) {
                updateResult(AnimationCacheItemResult(item: item, isFinal: true))
                
                return EmptyDisposable
            }
            let key = ItemKey(id: sourceId, width: Int(size.width), height: Int(size.height))
            
            let itemContext: ItemContext
            var beginFetch = false
            if let current = self.itemContexts[key] {
                itemContext = current
            } else {
                itemContext = ItemContext()
                self.itemContexts[key] = itemContext
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
                        guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[key] else {
                            return
                        }
                        
                        strongSelf.itemContexts.removeValue(forKey: key)
                        
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
                        
                        let _ = generateFirstFrameFromItem(currentQueue: queue, itemPath: itemFirstFramePath, animationItemPath: itemPath, allocateTempFile: allocateTempFile)
                        
                        for f in itemContext.subscribers.copyItems() {
                            guard let item = try? loadItem(path: itemPath) else {
                                continue
                            }
                            f(AnimationCacheItemResult(item: item, isFinal: true))
                        }
                    }
                }) else {
                    return EmptyDisposable
                }
                
                let fetchDisposable = MetaDisposable()
                fetchDisposable.set(fetch(AnimationCacheFetchOptions(size: size, writer: writer, firstFrameOnly: false)))
                
                itemContext.disposable.set(ActionDisposable { [weak writer] in
                    if let writer = writer {
                        writer.isCancelled = true
                    }
                    
                    fetchDisposable.dispose()
                })
            }
            
            return ActionDisposable { [weak self, weak itemContext] in
                queue.async {
                    guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[key] else {
                        return
                    }
                    itemContext.subscribers.remove(index)
                    if itemContext.subscribers.isEmpty {
                        itemContext.disposable.dispose()
                        strongSelf.itemContexts.removeValue(forKey: key)
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
                if let adaptedItem = adaptItemFromHigherResolution(currentQueue: .mainQueue(), itemPath: itemFirstFramePath, width: Int(size.width), height: Int(size.height), itemDirectoryPath: itemDirectoryPath, higherResolutionPath: adaptationItemPath, allocateTempFile: allocateTempFile) {
                    return adaptedItem
                }
            }
            
            return nil
        }
        
        static func getFirstFrame(queue: Queue, basePath: String, sourceId: String, size: CGSize, allocateTempFile: @escaping () -> String, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
            let hashString = md5Hash(sourceId)
            let sourceIdPath = itemSubpath(hashString: hashString, width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(basePath)/\(sourceIdPath.directory)"
            let itemFirstFramePath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)-f"
            
            if FileManager.default.fileExists(atPath: itemFirstFramePath), let item = try? loadItem(path: itemFirstFramePath) {
                completion(AnimationCacheItemResult(item: item, isFinal: true))
                return EmptyDisposable
            }
            
            if let adaptationItemPath = findHigherResolutionFileForAdaptation(itemDirectoryPath: itemDirectoryPath, baseName: "\(hashString)_", baseSuffix: "-f", width: Int(size.width), height: Int(size.height)) {
                if let adaptedItem = adaptItemFromHigherResolution(currentQueue: .mainQueue(), itemPath: itemFirstFramePath, width: Int(size.width), height: Int(size.height), itemDirectoryPath: itemDirectoryPath, higherResolutionPath: adaptationItemPath, allocateTempFile: allocateTempFile) {
                    completion(AnimationCacheItemResult(item: adaptedItem, isFinal: true))
                    return EmptyDisposable
                }
            }
            
            if let fetch = fetch {
                completion(AnimationCacheItemResult(item: nil, isFinal: false))
                
                guard let writer = AnimationCacheItemWriterImpl(queue: queue, allocateTempFile: allocateTempFile, completion: { result in
                    queue.async {
                        guard let result = result else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        let _ = try? FileManager.default.removeItem(atPath: itemFirstFramePath)
                        guard let _ = try? FileManager.default.moveItem(atPath: result.animationPath, toPath: itemFirstFramePath) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        guard let item = try? loadItem(path: itemFirstFramePath) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        
                        completion(AnimationCacheItemResult(item: item, isFinal: true))
                    }
                }) else {
                    completion(AnimationCacheItemResult(item: nil, isFinal: true))
                    return EmptyDisposable
                }
                
                let fetchDisposable = fetch(AnimationCacheFetchOptions(size: size, writer: writer, firstFrameOnly: true))
                return fetchDisposable
            } else {
                completion(AnimationCacheItemResult(item: nil, isFinal: true))
                return EmptyDisposable
            }
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
    
    public func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Signal<AnimationCacheItemResult, NoError> {
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
    
    public func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
        let disposable = MetaDisposable()
        
        let basePath = self.basePath
        let allocateTempFile = self.allocateTempFile
        queue.async {
            disposable.set(Impl.getFirstFrame(queue: queue, basePath: basePath, sourceId: sourceId, size: size, allocateTempFile: allocateTempFile, fetch: fetch, completion: completion))
        }
        
        return disposable
    }
}
