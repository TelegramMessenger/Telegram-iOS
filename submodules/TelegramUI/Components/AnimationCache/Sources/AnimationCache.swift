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
    public let numFrames: Int
    private let getFrameImpl: (Int, AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame?
    private let getFrameIndexImpl: (Double) -> Int
    private let getFrameDurationImpl: (Int) -> Double?
    
    public init(numFrames: Int, getFrame: @escaping (Int, AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame?, getFrameIndexImpl: @escaping (Double) -> Int, getFrameDurationImpl: @escaping (Int) -> Double?) {
        self.numFrames = numFrames
        self.getFrameImpl = getFrame
        self.getFrameIndexImpl = getFrameIndexImpl
        self.getFrameDurationImpl = getFrameDurationImpl
    }
    
    public func getFrameDuration(index: Int) -> Double? {
        return self.getFrameDurationImpl(index)
    }
    
    public func getFrame(index: Int, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame? {
        return self.getFrameImpl(index, requestedFormat)
    }
    
    public func getFrame(at duration: Double, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame? {
        let index = self.getFrameIndexImpl(duration)
        return self.getFrameImpl(index, requestedFormat)
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
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Void, proposedWidth: Int, proposedHeight: Int, duration: Double)
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
    struct CompressedResult {
        var path: String
    }
    
    private struct FrameMetadata {
        var offset: Int
        var length: Int
        var duration: Double
    }
    
    var isCancelled: Bool = false
    
    private let decompressedPath: String
    private let compressedPath: String
    private var file: ManagedFile?
    
    private var currentYUVASurface: ImageYUVA420?
    private var currentDctData: DctData?
    private var currentDctCoefficients: DctCoefficientsYUVA420?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    private var contentLength: Int = 0
    
    private let dctQuality: Int
    
    init?(allocateTempFile: @escaping () -> String) {
        self.dctQuality = 70
        
        self.decompressedPath = allocateTempFile()
        self.compressedPath = allocateTempFile()
        
        guard let file = ManagedFile(queue: nil, path: self.decompressedPath, mode: .readwrite) else {
            return nil
        }
        self.file = file
    }
    
    func add(with drawingBlock: (ImageYUVA420) -> Void, proposedWidth: Int, proposedHeight: Int, duration: Double) {
        if self.isFailed || self.isFinished {
            return
        }
        
        guard !self.isFailed, !self.isFinished, let file = self.file else {
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
        if let current = self.currentDctData, current.quality == self.dctQuality {
            dctData = current
        } else {
            dctData = DctData(quality: self.dctQuality)
            self.currentDctData = dctData
        }
        
        drawingBlock(yuvaSurface)
        
        yuvaSurface.dct(dctData: dctData, target: dctCoefficients)
        
        if isFirstFrame {
            file.write(2 as UInt32)
            
            file.write(UInt32(dctCoefficients.yPlane.width))
            file.write(UInt32(dctCoefficients.yPlane.height))
            file.write(UInt32(dctData.quality))
        
            self.contentLengthOffset = Int(file.position())
            file.write(0 as UInt32)
        }
        
        let framePosition = Int(file.position())
        assert(framePosition >= 0)
        var frameLength = 0
        
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
            
            dctPlane.data.withUnsafeBytes { bytes in
                let _ = file.write(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bytes.count)
            }
            frameLength += dctPlane.data.count
        }
        
        self.frames.append(FrameMetadata(offset: framePosition, length: frameLength, duration: duration))
        
        self.contentLength += frameLength
    }
    
    func finish() -> CompressedResult? {
        var shouldComplete = false
        
        outer: for _ in 0 ..< 1 {
            if !self.isFinished {
                self.isFinished = true
                shouldComplete = true
                
                guard let contentLengthOffset = self.contentLengthOffset, let file = self.file else {
                    self.isFailed = true
                    break outer
                }
                assert(contentLengthOffset >= 0)
                
                let metadataPosition = file.position()
                file.seek(position: Int64(contentLengthOffset))
                file.write(UInt32(self.contentLength))
                
                file.seek(position: metadataPosition)
                file.write(UInt32(self.frames.count))
                for frame in self.frames {
                    file.write(UInt32(frame.offset))
                    file.write(UInt32(frame.length))
                    file.write(Float32(frame.duration))
                }
                
                if !self.frames.isEmpty {
                } else {
                    self.isFailed = true
                    break outer
                }
                
                if !self.isFailed {
                    self.file = nil
                    
                    file._unsafeClose()
                    
                    guard let uncompressedData = try? Data(contentsOf: URL(fileURLWithPath: self.decompressedPath), options: .alwaysMapped) else {
                        self.isFailed = true
                        break outer
                    }
                    guard let compressedData = compressData(data: uncompressedData) else {
                        self.isFailed = true
                        break outer
                    }
                    guard let compressedFile = ManagedFile(queue: nil, path: self.compressedPath, mode: .readwrite) else {
                        self.isFailed = true
                        break outer
                    }
                    compressedFile.write(Int32(uncompressedData.count))
                    let _ = compressedFile.write(compressedData)
                    compressedFile._unsafeClose()
                }
            }
        }
        
        if shouldComplete {
            let _ = try? FileManager.default.removeItem(atPath: self.decompressedPath)
            
            if !self.isFailed {
                return CompressedResult(path: self.compressedPath)
            } else {
                let _ = try? FileManager.default.removeItem(atPath: self.compressedPath)
                
                return nil
            }
        } else {
            return nil
        }
    }
}

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    struct CompressedResult {
        var animationPath: String
        var firstFramePath: String
    }
    
    private struct FrameMetadata {
        var offset: Int
        var length: Int
        var duration: Double
    }
    
    let queue: Queue
    var isCancelled: Bool = false
    
    private let decompressedPath: String
    private let compressedPath: String
    private let firstFramePath: String
    private var file: ManagedFile?
    private let completion: (CompressedResult?) -> Void
    
    private var currentSurface: ImageARGB?
    private var currentYUVASurface: ImageYUVA420?
    private var currentDctData: DctData?
    private var currentDctCoefficients: DctCoefficientsYUVA420?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    private var contentLength: Int = 0
    
    private let dctQuality: Int
    
    private let lock = Lock()
    
    init?(queue: Queue, allocateTempFile: @escaping () -> String, completion: @escaping (CompressedResult?) -> Void) {
        self.dctQuality = 70
        
        self.queue = queue
        self.decompressedPath = allocateTempFile()
        self.compressedPath = allocateTempFile()
        self.firstFramePath = allocateTempFile()
        
        guard let file = ManagedFile(queue: nil, path: self.decompressedPath, mode: .readwrite) else {
            return nil
        }
        self.file = file
        self.completion = completion
    }
    
    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Void, proposedWidth: Int, proposedHeight: Int, duration: Double) {
        if self.isFailed || self.isFinished {
            return
        }
        
        self.lock.locked {
            guard !self.isFailed, !self.isFinished, let file = self.file else {
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
            if let current = self.currentDctData, current.quality == self.dctQuality {
                dctData = current
            } else {
                dctData = DctData(quality: self.dctQuality)
                self.currentDctData = dctData
            }
            
            surface.argbPlane.data.withUnsafeMutableBytes { bytes -> Void in
                drawingBlock(AnimationCacheItemDrawingSurface(
                    argb: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    width: width,
                    height: height,
                    bytesPerRow: surface.argbPlane.bytesPerRow,
                    length: bytes.count
                ))
            }
            
            surface.toYUVA420(target: yuvaSurface)
            yuvaSurface.dct(dctData: dctData, target: dctCoefficients)
            
            if isFirstFrame {
                file.write(2 as UInt32)
                
                file.write(UInt32(dctCoefficients.yPlane.width))
                file.write(UInt32(dctCoefficients.yPlane.height))
                file.write(UInt32(dctData.quality))
            
                self.contentLengthOffset = Int(file.position())
                file.write(0 as UInt32)
            }
            
            let framePosition = Int(file.position())
            assert(framePosition >= 0)
            var frameLength = 0
            
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
                
                dctPlane.data.withUnsafeBytes { bytes in
                    let _ = file.write(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bytes.count)
                }
                frameLength += dctPlane.data.count
            }
            
            self.frames.append(FrameMetadata(offset: framePosition, length: frameLength, duration: duration))
            
            self.contentLength += frameLength
        }
    }
    
    func finish() {
        var shouldComplete = false
        self.lock.locked {
            if !self.isFinished {
                self.isFinished = true
                shouldComplete = true
                
                guard let contentLengthOffset = self.contentLengthOffset, let file = self.file else {
                    self.isFailed = true
                    return
                }
                assert(contentLengthOffset >= 0)
                
                let metadataPosition = file.position()
                file.seek(position: Int64(contentLengthOffset))
                file.write(UInt32(self.contentLength))
                
                file.seek(position: metadataPosition)
                file.write(UInt32(self.frames.count))
                for frame in self.frames {
                    file.write(UInt32(frame.offset))
                    file.write(UInt32(frame.length))
                    file.write(Float32(frame.duration))
                }
                
                if !self.frames.isEmpty, let dctCoefficients = self.currentDctCoefficients, let dctData = self.currentDctData {
                    var firstFrameData = Data(capacity: 4 * 5 + self.frames[0].length)
                    
                    writeUInt32(data: &firstFrameData, value: 2 as UInt32)
                    writeUInt32(data: &firstFrameData, value: UInt32(dctCoefficients.yPlane.width))
                    writeUInt32(data: &firstFrameData, value: UInt32(dctCoefficients.yPlane.height))
                    writeUInt32(data: &firstFrameData, value: UInt32(dctData.quality))
                    
                    writeUInt32(data: &firstFrameData, value: UInt32(self.frames[0].length))
                    let firstFrameStart = 4 * 5
                    
                    file.seek(position: Int64(self.frames[0].offset))
                    firstFrameData.count += self.frames[0].length
                    firstFrameData.withUnsafeMutableBytes { bytes in
                        let _ = file.read(bytes.baseAddress!.advanced(by: 4 * 5), self.frames[0].length)
                    }
                    
                    writeUInt32(data: &firstFrameData, value: UInt32(1))
                    writeUInt32(data: &firstFrameData, value: UInt32(firstFrameStart))
                    writeUInt32(data: &firstFrameData, value: UInt32(self.frames[0].length))
                    writeFloat32(data: &firstFrameData, value: Float32(1.0))
                    
                    guard let compressedFirstFrameData = compressData(data: firstFrameData, addSizeHeader: true) else {
                        self.isFailed = true
                        return
                    }
                    guard let _ = try? compressedFirstFrameData.write(to: URL(fileURLWithPath: self.firstFramePath)) else {
                        self.isFailed = true
                        return
                    }
                } else {
                    self.isFailed = true
                    return
                }
                
                if !self.isFailed {
                    self.file = nil
                    
                    file._unsafeClose()
                    
                    guard let uncompressedData = try? Data(contentsOf: URL(fileURLWithPath: self.decompressedPath), options: .alwaysMapped) else {
                        self.isFailed = true
                        return
                    }
                    guard let compressedData = compressData(data: uncompressedData) else {
                        self.isFailed = true
                        return
                    }
                    guard let compressedFile = ManagedFile(queue: nil, path: self.compressedPath, mode: .readwrite) else {
                        self.isFailed = true
                        return
                    }
                    compressedFile.write(Int32(uncompressedData.count))
                    let _ = compressedFile.write(compressedData)
                    compressedFile._unsafeClose()
                }
            }
        }
        
        if shouldComplete {
            let _ = try? FileManager.default.removeItem(atPath: self.decompressedPath)
            
            if !self.isFailed {
                self.completion(CompressedResult(
                    animationPath: self.compressedPath,
                    firstFramePath: self.firstFramePath
                ))
            } else {
                let _ = try? FileManager.default.removeItem(atPath: self.compressedPath)
                let _ = try? FileManager.default.removeItem(atPath: self.firstFramePath)
                self.completion(nil)
            }
        }
    }
}

private final class AnimationCacheItemAccessor {
    struct FrameInfo {
        let range: Range<Int>
        let duration: Double
    }
    
    private let data: Data
    private let frameMapping: [Int: FrameInfo]
    private let durationMapping: [Double]
    private let totalDuration: Double
    
    private var currentYUVASurface: ImageYUVA420?
    private var currentDctData: DctData
    private var currentDctCoefficients: DctCoefficientsYUVA420
    
    init(data: Data, frameMapping: [FrameInfo], width: Int, height: Int, dctQuality: Int) {
        self.data = data
        
        var resultFrameMapping: [Int: FrameInfo] = [:]
        var durationMapping: [Double] = []
        var totalDuration: Double = 0.0
        
        for i in 0 ..< frameMapping.count {
            let frame = frameMapping[i]
            resultFrameMapping[i] = frame
            totalDuration += frame.duration
            durationMapping.append(totalDuration)
        }
        
        self.frameMapping = resultFrameMapping
        self.durationMapping = durationMapping
        self.totalDuration = totalDuration
        
        self.currentDctData = DctData(quality: dctQuality)
        self.currentDctCoefficients = DctCoefficientsYUVA420(width: width, height: height)
    }
    
    func getFrame(index: Int, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AnimationCacheItemFrame? {
        guard let frameInfo = self.frameMapping[index] else {
            return nil
        }
        
        var frameDataOffset = 0
        let frameLength = frameInfo.range.upperBound - frameInfo.range.lowerBound
        for i in 0 ..< 4 {
            let dctPlane: DctCoefficientPlane
            switch i {
            case 0:
                dctPlane = self.currentDctCoefficients.yPlane
            case 1:
                dctPlane = self.currentDctCoefficients.uPlane
            case 2:
                dctPlane = self.currentDctCoefficients.vPlane
            case 3:
                dctPlane = self.currentDctCoefficients.aPlane
            default:
                preconditionFailure()
            }
            
            if frameDataOffset + dctPlane.data.count > frameLength {
                break
            }
            
            dctPlane.data.withUnsafeMutableBytes { targetBuffer -> Void in
                self.data.copyBytes(to: targetBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), from: (frameInfo.range.lowerBound + frameDataOffset) ..< (frameInfo.range.lowerBound + frameDataOffset + targetBuffer.count))
            }
            
            frameDataOffset += dctPlane.data.count
        }
        
        let yuvaSurface: ImageYUVA420
        switch requestedFormat {
        case .rgba:
            if let currentYUVASurface = self.currentYUVASurface {
                yuvaSurface = currentYUVASurface
            } else {
                yuvaSurface = ImageYUVA420(width: self.currentDctCoefficients.yPlane.width, height: self.currentDctCoefficients.yPlane.height, rowAlignment: nil)
            }
        case let .yuva(preferredRowAlignment):
            yuvaSurface = ImageYUVA420(width: self.currentDctCoefficients.yPlane.width, height: self.currentDctCoefficients.yPlane.height, rowAlignment: preferredRowAlignment)
        }
        
        self.currentDctCoefficients.idct(dctData: self.currentDctData, target: yuvaSurface)
        
        switch requestedFormat {
        case .rgba:
            let currentSurface = ImageARGB(width: yuvaSurface.yPlane.width, height: yuvaSurface.yPlane.height, rowAlignment: 32)
            yuvaSurface.toARGB(target: currentSurface)
            self.currentYUVASurface = yuvaSurface
            
            return AnimationCacheItemFrame(format: .rgba(data: currentSurface.argbPlane.data, width: currentSurface.argbPlane.width, height: currentSurface.argbPlane.height, bytesPerRow: currentSurface.argbPlane.bytesPerRow), duration: frameInfo.duration)
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
                duration: frameInfo.duration
            )
        }
    }
    
    func getFrameIndex(duration: Double) -> Int {
        if self.totalDuration == 0.0 {
            return 0
        }
        if self.durationMapping.count <= 1 {
            return 0
        }
        let normalizedDuration = duration.truncatingRemainder(dividingBy: self.totalDuration)
        for i in 1 ..< self.durationMapping.count {
            if normalizedDuration < self.durationMapping[i] {
                return i - 1
            }
        }
        return self.durationMapping.count - 1
    }
    
    func getFrameDuration(index: Int) -> Double? {
        if index < self.durationMapping.count {
            return self.durationMapping[index]
        } else {
            return nil
        }
    }
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

private func loadItem(path: String) -> AnimationCacheItem? {
    guard let compressedData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
        return nil
    }
    
    if compressedData.count < 4 {
        return nil
    }
    let decompressedSize = readUInt32(data: compressedData, offset: 0)
    
    if decompressedSize <= 0 || decompressedSize > 40 * 1024 * 1024 {
        return nil
    }
    guard let data = decompressData(data: compressedData, range: 4 ..< compressedData.count, decompressedSize: Int(decompressedSize)) else {
        return nil
    }
    
    let dataLength = data.count
    
    var offset = 0
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let formatVersion = readUInt32(data: data, offset: offset)
    offset += 4
    if formatVersion != 2 {
        return nil
    }
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let width = readUInt32(data: data, offset: offset)
    offset += 4
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let height = readUInt32(data: data, offset: offset)
    offset += 4
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let dctQuality = readUInt32(data: data, offset: offset)
    offset += 4
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let frameDataLength = readUInt32(data: data, offset: offset)
    offset += 4
    
    offset += Int(frameDataLength)
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let numFrames = readUInt32(data: data, offset: offset)
    offset += 4
    
    var frameMapping: [AnimationCacheItemAccessor.FrameInfo] = []
    for _ in 0 ..< Int(numFrames) {
        guard dataLength >= offset + 4 + 4 + 4 else {
            return nil
        }
        
        let frameStart = readUInt32(data: data, offset: offset)
        offset += 4
        let frameLength = readUInt32(data: data, offset: offset)
        offset += 4
        let frameDuration = readFloat32(data: data, offset: offset)
        offset += 4
        
        frameMapping.append(AnimationCacheItemAccessor.FrameInfo(range: Int(frameStart) ..< Int(frameStart + frameLength), duration: Double(frameDuration)))
    }
    
    let itemAccessor = AnimationCacheItemAccessor(data: data, frameMapping: frameMapping, width: Int(width), height: Int(height), dctQuality: Int(dctQuality))
    
    return AnimationCacheItem(numFrames: Int(numFrames), getFrame: { index, requestedFormat in
        return itemAccessor.getFrame(index: index, requestedFormat: requestedFormat)
    }, getFrameIndexImpl: { duration in
        return itemAccessor.getFrameIndex(duration: duration)
    }, getFrameDurationImpl: { index in
        return itemAccessor.getFrameDuration(index: index)
    })
}

private func adaptItemFromHigherResolution(itemPath: String, width: Int, height: Int, itemDirectoryPath: String, higherResolutionPath: String, allocateTempFile: @escaping () -> String) -> AnimationCacheItem? {
    guard let higherResolutionItem = loadItem(path: higherResolutionPath) else {
        return nil
    }
    guard let writer = AnimationCacheItemWriterInternal(allocateTempFile: allocateTempFile) else {
        return nil
    }
    
    for i in 0 ..< higherResolutionItem.numFrames {
        guard let duration = higherResolutionItem.getFrameDuration(index: i) else {
            break
        }
        writer.add(with: { yuva in
            guard let frame = higherResolutionItem.getFrame(index: i, requestedFormat: .yuva(rowAlignment: yuva.yPlane.rowAlignment)) else {
                return
            }
            switch frame.format {
            case .rgba:
                return
            case let .yuva(y, u, v, a):
                yuva.yPlane.copyScaled(fromPlane: y)
                yuva.uPlane.copyScaled(fromPlane: u)
                yuva.vPlane.copyScaled(fromPlane: v)
                yuva.aPlane.copyScaled(fromPlane: a)
            }
        }, proposedWidth: width, proposedHeight: height, duration: duration)
    }
    
    guard let result = writer.finish() else {
        return nil
    }
    guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
        return nil
    }
    let _ = try? FileManager.default.removeItem(atPath: itemPath)
    guard let _ = try? FileManager.default.moveItem(atPath: result.path, toPath: itemPath) else {
        return nil
    }
    guard let item = loadItem(path: itemPath) else {
        return nil
    }
    return item
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
            
            if FileManager.default.fileExists(atPath: itemPath), let item = loadItem(path: itemPath) {
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
                        let _ = try? FileManager.default.removeItem(atPath: itemFirstFramePath)
                        guard let _ = try? FileManager.default.moveItem(atPath: result.firstFramePath, toPath: itemFirstFramePath) else {
                            return
                        }
                        guard let item = loadItem(path: itemPath) else {
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
                return loadItem(path: itemFirstFramePath)
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
            
            if FileManager.default.fileExists(atPath: itemFirstFramePath), let item = loadItem(path: itemFirstFramePath) {
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
