import Foundation
import Compression
import Display
import SwiftSignalKit
import MediaResources
import RLottieBinding
import GZip
import ManagedFile
import AnimationCompression

private let sharedStoreQueue = Queue.concurrentDefaultQueue()

public extension EmojiFitzModifier {
    var lottieFitzModifier: LottieFitzModifier {
        switch self {
        case .type12:
            return .type12
        case .type3:
            return .type3
        case .type4:
            return .type4
        case .type5:
            return .type5
        case .type6:
            return .type6
        }
    }
}

public protocol AnimatedStickerFrameSource: AnyObject {
    var frameRate: Int { get }
    var frameCount: Int { get }
    var frameIndex: Int { get }
    
    func takeFrame(draw: Bool) -> AnimatedStickerFrame?
    func skipToEnd()
    func skipToFrameIndex(_ index: Int)
}

final class AnimatedStickerFrameSourceWrapper {
    let value: AnimatedStickerFrameSource
    
    init(_ value: AnimatedStickerFrameSource) {
        self.value = value
    }
}


public final class AnimatedStickerCachedFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private var data: Data
    private var dataComplete: Bool
    private let notifyUpdated: () -> Void
    
    private var scratchBuffer: Data
    let width: Int
    let bytesPerRow: Int
    let height: Int
    public let frameRate: Int
    public let frameCount: Int
    public var frameIndex: Int
    private let initialOffset: Int
    private var offset: Int
    var decodeBuffer: Data
    var frameBuffer: Data
    
    public init?(queue: Queue, data: Data, complete: Bool, notifyUpdated: @escaping () -> Void) {
        self.queue = queue
        self.data = data
        self.dataComplete = complete
        self.notifyUpdated = notifyUpdated
        self.scratchBuffer = Data(count: compression_decode_scratch_buffer_size(COMPRESSION_LZFSE))
        
        var offset = 0
        var width = 0
        var height = 0
        var bytesPerRow = 0
        var frameRate = 0
        var frameCount = 0
        
        if !self.data.withUnsafeBytes({ buffer -> Bool in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            var frameRateValue: Int32 = 0
            var frameCountValue: Int32 = 0
            var widthValue: Int32 = 0
            var heightValue: Int32 = 0
            var bytesPerRowValue: Int32 = 0
            memcpy(&frameRateValue, bytes.advanced(by: offset), 4)
            offset += 4
            memcpy(&frameCountValue, bytes.advanced(by: offset), 4)
            offset += 4
            memcpy(&widthValue, bytes.advanced(by: offset), 4)
            offset += 4
            memcpy(&heightValue, bytes.advanced(by: offset), 4)
            offset += 4
            memcpy(&bytesPerRowValue, bytes.advanced(by: offset), 4)
            offset += 4
            frameRate = Int(frameRateValue)
            frameCount = Int(frameCountValue)
            width = Int(widthValue)
            height = Int(heightValue)
            bytesPerRow = Int(bytesPerRowValue)
            
            return true
        }) {
            return nil
        }
        
        self.bytesPerRow = bytesPerRow
        
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.frameCount = frameCount
        
        self.frameIndex = 0
        self.initialOffset = offset
        self.offset = offset
        
        self.decodeBuffer = Data(count: self.bytesPerRow * height)
        self.frameBuffer = Data(count: self.bytesPerRow * height)
        let frameBufferLength = self.frameBuffer.count
        self.frameBuffer.withUnsafeMutableBytes { buffer -> Void in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            memset(bytes, 0, frameBufferLength)
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    public func takeFrame(draw: Bool) -> AnimatedStickerFrame? {
        var frameData: Data?
        var isLastFrame = false
        
        let dataLength = self.data.count
        let decodeBufferLength = self.decodeBuffer.count
        let frameBufferLength = self.frameBuffer.count
        
        let frameIndex = self.frameIndex
        
        self.data.withUnsafeBytes { buffer -> Void in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            if self.offset + 4 > dataLength {
                if self.dataComplete {
                    self.frameIndex = 0
                    self.offset = self.initialOffset
                    self.frameBuffer.withUnsafeMutableBytes { buffer -> Void in
                        guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return
                        }
                        memset(bytes, 0, frameBufferLength)
                    }
                }
                return
            }
            
            var frameLength: Int32 = 0
            memcpy(&frameLength, bytes.advanced(by: self.offset), 4)
            
            if self.offset + 4 + Int(frameLength) > dataLength {
                return
            }
            
            self.offset += 4
            
            if draw {
                self.scratchBuffer.withUnsafeMutableBytes { scratchBuffer -> Void in
                    guard let scratchBytes = scratchBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }

                    self.decodeBuffer.withUnsafeMutableBytes { decodeBuffer -> Void in
                        guard let decodeBytes = decodeBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return
                        }

                        self.frameBuffer.withUnsafeMutableBytes { frameBuffer -> Void in
                            guard let frameBytes = frameBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                                return
                            }

                            compression_decode_buffer(decodeBytes, decodeBufferLength, bytes.advanced(by: self.offset), Int(frameLength), UnsafeMutableRawPointer(scratchBytes), COMPRESSION_LZFSE)
                            
                            var lhs = UnsafeMutableRawPointer(frameBytes).assumingMemoryBound(to: UInt64.self)
                            var rhs = UnsafeRawPointer(decodeBytes).assumingMemoryBound(to: UInt64.self)
                            for _ in 0 ..< decodeBufferLength / 8 {
                                lhs.pointee = lhs.pointee ^ rhs.pointee
                                lhs = lhs.advanced(by: 1)
                                rhs = rhs.advanced(by: 1)
                            }
                            var lhsRest = UnsafeMutableRawPointer(frameBytes).assumingMemoryBound(to: UInt8.self).advanced(by: (decodeBufferLength / 8) * 8)
                            var rhsRest = UnsafeMutableRawPointer(decodeBytes).assumingMemoryBound(to: UInt8.self).advanced(by: (decodeBufferLength / 8) * 8)
                            for _ in (decodeBufferLength / 8) * 8 ..< decodeBufferLength {
                                lhsRest.pointee = rhsRest.pointee ^ lhsRest.pointee
                                lhsRest = lhsRest.advanced(by: 1)
                                rhsRest = rhsRest.advanced(by: 1)
                            }
                            
                            frameData = Data(bytes: frameBytes, count: decodeBufferLength)
                        }
                    }
                }
            }
            
            self.frameIndex += 1
            self.offset += Int(frameLength)
            if self.offset == dataLength && self.dataComplete {
                isLastFrame = true
                self.frameIndex = 0
                self.offset = self.initialOffset
                self.frameBuffer.withUnsafeMutableBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    memset(bytes, 0, frameBufferLength)
                }
            }
        }
        
        if let frameData = frameData, draw {
            return AnimatedStickerFrame(data: frameData, type: .yuva, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: isLastFrame, totalFrames: self.frameCount)
        } else {
            return nil
        }
    }
    
    func updateData(data: Data, complete: Bool) {
        self.data = data
        self.dataComplete = complete
    }
    
    public func skipToEnd() {
    }

    public func skipToFrameIndex(_ index: Int) {
    }
}

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

private final class AnimatedStickerDirectFrameSourceCache {
    private enum FrameRangeResult {
        case range(Range<Int>)
        case notFound
        case corruptedFile
    }
    
    private let queue: Queue
    private let storeQueue: Queue
    private let file: ManagedFile
    private let frameCount: Int
    private let width: Int
    private let height: Int
    
    private let useHardware: Bool
    
    private var isStoringFrames = Set<Int>()
    
    private var scratchBuffer: Data
    private var decodeBuffer: Data
    
    private var frameCompressor: AnimationCompressor?
    
    init?(queue: Queue, pathPrefix: String, width: Int, height: Int, frameCount: Int, fitzModifier: EmojiFitzModifier?, useHardware: Bool) {
        self.queue = queue
        self.storeQueue = sharedStoreQueue
        
        self.frameCount = frameCount
        self.width = width// alignUp(size: width, align: 8)
        self.height = height//alignUp(size: height, align: 8)
        self.useHardware = useHardware
        
        let suffix : String
        if let fitzModifier = fitzModifier {
            suffix = "_fitz\(fitzModifier.rawValue)"
        } else {
            suffix = ""
        }
        let path = "\(pathPrefix)_\(width):\(height)\(suffix).stickerframecachev3\(useHardware ? "-mtl" : "")"
        var file = ManagedFile(queue: queue, path: path, mode: .readwrite)
        if let file = file {
            self.file = file
        } else {
            let _ = try? FileManager.default.removeItem(atPath: path)
            file = ManagedFile(queue: queue, path: path, mode: .readwrite)
            if let file = file {
                self.file = file
            } else {
                return nil
            }
        }
        
        self.scratchBuffer = Data(count: compression_decode_scratch_buffer_size(COMPRESSION_LZFSE))
        
        let yuvaPixelsPerAlphaRow = (Int(width) + 1) & (~1)
        let yuvaLength = Int(width) * Int(height) * 2 + yuvaPixelsPerAlphaRow * Int(height) / 2
        self.decodeBuffer = Data(count: yuvaLength)
        
        self.initializeFrameTable()
    }
    
    private func initializeFrameTable() {
        if let size = self.file.getSize(), size >= self.frameCount * 4 * 2 {
        } else {
            self.file.truncate(count: 0)
            for _ in 0 ..< self.frameCount {
                var zero: Int32 = 0
                let _ = self.file.write(&zero, count: 4)
                let _ = self.file.write(&zero, count: 4)
            }
        }
    }
    
    private func readFrameRange(index: Int) -> FrameRangeResult {
        if index < 0 || index >= self.frameCount {
            return .notFound
        }
        
        self.file.seek(position: Int64(index * 4 * 2))
        var offset: Int32 = 0
        var length: Int32 = 0
        if self.file.read(&offset, 4) != 4 {
            return .corruptedFile
        }
        if self.file.read(&length, 4) != 4 {
            return .corruptedFile
        }
        if length == 0 {
            return .notFound
        }
        if length < 0 || offset < 0 {
            return .corruptedFile
        }
        if Int64(offset) + Int64(length) > 200 * 1024 * 1024 {
            return .corruptedFile
        }
        
        return .range(Int(offset) ..< Int(offset + length))
    }
    
    func storeUncompressedRgbFrame(index: Int, rgbData: Data) {
        if self.useHardware {
            self.storeUncompressedRgbFrameMetal(index: index, rgbData: rgbData)
        } else {
            self.storeUncompressedRgbFrameSoft(index: index, rgbData: rgbData)
        }
    }
    
    func storeUncompressedRgbFrameMetal(index: Int, rgbData: Data) {
        if self.isStoringFrames.contains(index) {
            return
        }
        self.isStoringFrames.insert(index)
        
        if self.frameCompressor == nil {
            self.frameCompressor = AnimationCompressor(sharedContext: AnimationCompressor.SharedContext.shared)
        }
        
        let queue = self.queue
        let frameCompressor = self.frameCompressor
        let width = self.width
        let height = self.height
        DispatchQueue.main.async { [weak self] in
            frameCompressor?.compress(image: AnimationCompressor.ImageData(width: width, height: height, bytesPerRow: width * 4, data: rgbData), completion: { compressedData in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    guard let currentSize = strongSelf.file.getSize() else {
                        return
                    }
                    
                    strongSelf.file.seek(position: Int64(index * 4 * 2))
                    var offset = Int32(currentSize)
                    var length = Int32(compressedData.data.count)
                    let _ = strongSelf.file.write(&offset, count: 4)
                    let _ = strongSelf.file.write(&length, count: 4)
                    strongSelf.file.seek(position: Int64(currentSize))
                    compressedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
                        if let baseAddress = buffer.baseAddress {
                            let _ = strongSelf.file.write(baseAddress, count: Int(length))
                        }
                    }
                }
            })
        }
    }
    
    func storeUncompressedRgbFrameSoft(index: Int, rgbData: Data) {
        if index < 0 || index >= self.frameCount {
            return
        }
        if self.isStoringFrames.contains(index) {
            return
        }
        self.isStoringFrames.insert(index)
        
        let width = self.width
        let height = self.height
        
        let queue = self.queue
        self.storeQueue.async { [weak self] in
            let compressedData = compressFrame(width: width, height: height, rgbData: rgbData, unpremultiply: true)
            
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                guard let currentSize = strongSelf.file.getSize() else {
                    return
                }
                guard let compressedData = compressedData else {
                    return
                }
                
                strongSelf.file.seek(position: Int64(index * 4 * 2))
                var offset = Int32(currentSize)
                var length = Int32(compressedData.count)
                let _ = strongSelf.file.write(&offset, count: 4)
                let _ = strongSelf.file.write(&length, count: 4)
                strongSelf.file.seek(position: Int64(currentSize))
                compressedData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
                    if let baseAddress = buffer.baseAddress {
                        let _ = strongSelf.file.write(baseAddress, count: Int(length))
                    }
                }
            }
        }
    }
    
    /*func readUncompressedYuvaFrameOld(index: Int) -> Data? {
        if index < 0 || index >= self.frameCount {
            return nil
        }
        let rangeResult = self.readFrameRange(index: index)
        
        switch rangeResult {
        case let .range(range):
            self.file.seek(position: Int64(range.lowerBound))
            let length = range.upperBound - range.lowerBound
            let compressedData = self.file.readData(count: length)
            if compressedData.count != length {
                return nil
            }
            
            var frameData: Data?
            
            let decodeBufferLength = self.decodeBuffer.count
            
            compressedData.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                
                self.scratchBuffer.withUnsafeMutableBytes { scratchBuffer -> Void in
                    guard let scratchBytes = scratchBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }

                    self.decodeBuffer.withUnsafeMutableBytes { decodeBuffer -> Void in
                        guard let decodeBytes = decodeBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return
                        }

                        let resultLength = compression_decode_buffer(decodeBytes, decodeBufferLength, bytes, length, UnsafeMutableRawPointer(scratchBytes), COMPRESSION_LZFSE)
                        
                        frameData = Data(bytes: decodeBytes, count: resultLength)
                    }
                }
            }
            
            return frameData
        case .notFound:
            return nil
        case .corruptedFile:
            self.file.truncate(count: 0)
            self.initializeFrameTable()
            
            return nil
        }
    }*/
    
    func readCompressedFrame(index: Int, totalFrames: Int) -> AnimatedStickerFrame? {
        if index < 0 || index >= self.frameCount {
            return nil
        }
        let rangeResult = self.readFrameRange(index: index)
        
        switch rangeResult {
        case let .range(range):
            self.file.seek(position: Int64(range.lowerBound))
            let length = range.upperBound - range.lowerBound
            let compressedData = self.file.readData(count: length)
            if compressedData.count != length {
                return nil
            }
            
            if compressedData.count > 4 {
                var magic: Int32 = 0
                compressedData.withUnsafeBytes { bytes in
                    let _ = memcpy(&magic, bytes.baseAddress!, 4)
                }
                if magic == 0x543ee445 {
                    return AnimatedStickerFrame(data: compressedData, type: .dct, width: 0, height: 0, bytesPerRow: 0, index: index, isLastFrame: index == frameCount - 1, totalFrames: frameCount)
                }
            }
            
            var frameData: Data?
            
            let decodeBufferLength = self.decodeBuffer.count
            
            compressedData.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                
                self.scratchBuffer.withUnsafeMutableBytes { scratchBuffer -> Void in
                    guard let scratchBytes = scratchBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }

                    self.decodeBuffer.withUnsafeMutableBytes { decodeBuffer -> Void in
                        guard let decodeBytes = decodeBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return
                        }

                        let resultLength = compression_decode_buffer(decodeBytes, decodeBufferLength, bytes, length, UnsafeMutableRawPointer(scratchBytes), COMPRESSION_LZFSE)
                        
                        frameData = Data(bytes: decodeBytes, count: resultLength)
                    }
                }
            }
            
            if let frameData = frameData {
                return AnimatedStickerFrame(data: frameData, type: .yuva, width: self.width, height: self.height, bytesPerRow: self.width * 2, index: index, isLastFrame: index == frameCount - 1, totalFrames: frameCount)
            } else {
                return nil
            }
        case .notFound:
            return nil
        case .corruptedFile:
            self.file.truncate(count: 0)
            self.initializeFrameTable()
            
            return nil
        }
    }
}


public final class AnimatedStickerDirectFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private let data: Data
    private let width: Int
    private let height: Int
    private let cache: AnimatedStickerDirectFrameSourceCache?
    private let bytesPerRow: Int
    public let frameCount: Int
    public let frameRate: Int
    fileprivate var currentFrame: Int
    private let animation: LottieInstance
    
    public var frameIndex: Int {
        return self.currentFrame % self.frameCount
    }
    
    public init?(queue: Queue, data: Data, width: Int, height: Int, cachePathPrefix: String?, useMetalCache: Bool = false, fitzModifier: EmojiFitzModifier?) {
        self.queue = queue
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(width))
        self.currentFrame = 0
        let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
        
        guard let animation = LottieInstance(data: decompressedData, fitzModifier: fitzModifier?.lottieFitzModifier ?? .none, colorReplacements: nil, cacheKey: "") else {
            print("Could not load sticker data")
            return nil
        }
        self.animation = animation
        let frameCount = Int(animation.frameCount)
        self.frameCount = frameCount
        self.frameRate = Int(animation.frameRate)
        
        self.cache = cachePathPrefix.flatMap { cachePathPrefix in
            AnimatedStickerDirectFrameSourceCache(queue: queue, pathPrefix: cachePathPrefix, width: width, height: height, frameCount: frameCount, fitzModifier: fitzModifier, useHardware: useMetalCache)
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    public func takeFrame(draw: Bool) -> AnimatedStickerFrame? {
        let frameIndex = self.currentFrame % self.frameCount
        self.currentFrame += 1
        if draw {
            if let cache = self.cache, let compressedFrame = cache.readCompressedFrame(index: frameIndex, totalFrames: self.frameCount) {
                return compressedFrame
            } else {
                var frameData = Data(count: self.bytesPerRow * self.height)
                frameData.withUnsafeMutableBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }

                    memset(bytes, 0, self.bytesPerRow * self.height)
                    self.animation.renderFrame(with: Int32(frameIndex), into: bytes, width: Int32(self.width), height: Int32(self.height), bytesPerRow: Int32(self.bytesPerRow))
                }
                if let cache = self.cache {
                    cache.storeUncompressedRgbFrame(index: frameIndex, rgbData: frameData)
                }
                return AnimatedStickerFrame(data: frameData, type: .argb, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: frameIndex == self.frameCount - 1, totalFrames: self.frameCount)
            }
        } else {
            return nil
        }
    }
    
    public func skipToEnd() {
        self.currentFrame = self.frameCount - 1
    }

    public func skipToFrameIndex(_ index: Int) {
        self.currentFrame = index
    }
}
