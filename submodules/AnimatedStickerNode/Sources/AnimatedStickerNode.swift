import Foundation
import SwiftSignalKit
import Compression
import Display
import AsyncDisplayKit
import RLottieBinding
import GZip
import YuvConversion
import MediaResources

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

private let sharedQueue = Queue()
private let sharedStoreQueue = Queue.concurrentDefaultQueue()

private class AnimatedStickerNodeDisplayEvents: ASDisplayNode {
    private var value: Bool = false
    var updated: ((Bool) -> Void)?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        if !self.value {
            self.value = true
            self.updated?(true)
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isInHierarchy {
                if strongSelf.value {
                    strongSelf.value = false
                    strongSelf.updated?(false)
                }
            }
        }
    }
}

public enum AnimatedStickerMode {
    case cached
    case direct(cachePathPrefix: String?)
}

public enum AnimatedStickerPlaybackPosition {
    case start
    case end
    case timestamp(Double)
    case frameIndex(Int)
}

public enum AnimatedStickerPlaybackMode {
    case once
    case count(Int)
    case loop
    case still(AnimatedStickerPlaybackPosition)
}

public final class AnimatedStickerFrame {
    public let data: Data
    public let type: AnimationRendererFrameType
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    let index: Int
    let isLastFrame: Bool
    let totalFrames: Int
    
    init(data: Data, type: AnimationRendererFrameType, width: Int, height: Int, bytesPerRow: Int, index: Int, isLastFrame: Bool, totalFrames: Int) {
        self.data = data
        self.type = type
        self.width = width
        self.height = height
        assert(bytesPerRow > 0)
        self.bytesPerRow = bytesPerRow
        self.index = index
        self.isLastFrame = isLastFrame
        self.totalFrames = totalFrames
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

private final class AnimatedStickerFrameSourceWrapper {
    let value: AnimatedStickerFrameSource
    
    init(_ value: AnimatedStickerFrameSource) {
        self.value = value
    }
}

@available(iOS 9.0, *)
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

private func wrappedWrite(_ fd: Int32, _ data: UnsafeRawPointer, _ count: Int) -> Int {
    return write(fd, data, count)
}

private func wrappedRead(_ fd: Int32, _ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
    return read(fd, data, count)
}

//TODO: separate ManagedFile into its own module
private final class ManagedFileImpl {
    enum Mode {
        case read
        case readwrite
        case append
    }
    
    private let queue: Queue?
    private let fd: Int32
    private let mode: Mode
    
    init?(queue: Queue?, path: String, mode: Mode) {
        if let queue = queue {
            assert(queue.isCurrent())
        }
        self.queue = queue
        self.mode = mode
        let fileMode: Int32
        let accessMode: UInt16
        switch mode {
            case .read:
                fileMode = O_RDONLY
                accessMode = S_IRUSR
            case .readwrite:
                fileMode = O_RDWR | O_CREAT
                accessMode = S_IRUSR | S_IWUSR
            case .append:
                fileMode = O_WRONLY | O_CREAT | O_APPEND
                accessMode = S_IRUSR | S_IWUSR
        }
        let fd = open(path, fileMode, accessMode)
        if fd >= 0 {
            self.fd = fd
        } else {
            return nil
        }
    }
    
    deinit {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        close(self.fd)
    }
    
    public func write(_ data: UnsafeRawPointer, count: Int) -> Int {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        return wrappedWrite(self.fd, data, count)
    }
    
    public func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        return wrappedRead(self.fd, data, count)
    }
    
    public func readData(count: Int) -> Data {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        var result = Data(count: count)
        result.withUnsafeMutableBytes { buffer -> Void in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            let readCount = self.read(bytes, count)
            assert(readCount == count)
        }
        return result
    }
    
    public func seek(position: Int64) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        lseek(self.fd, position, SEEK_SET)
    }
    
    public func truncate(count: Int64) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        ftruncate(self.fd, count)
    }
    
    public func getSize() -> Int? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        var value = stat()
        if fstat(self.fd, &value) == 0 {
            return Int(value.st_size)
        } else {
            return nil
        }
    }
    
    public func sync() {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        fsync(self.fd)
    }
}

private func compressFrame(width: Int, height: Int, rgbData: Data) -> Data? {
    let bytesPerRow = rgbData.count / height
    
    let yuvaPixelsPerAlphaRow = (Int(width) + 1) & (~1)
    assert(yuvaPixelsPerAlphaRow % 2 == 0)
    
    let yuvaLength = Int(width) * Int(height) * 2 + yuvaPixelsPerAlphaRow * Int(height) / 2
    let yuvaFrameData = malloc(yuvaLength)!
    defer {
        free(yuvaFrameData)
    }
    memset(yuvaFrameData, 0, yuvaLength)
    
    var compressedFrameData = Data(count: yuvaLength)
    let compressedFrameDataLength = compressedFrameData.count
    
    let scratchData = malloc(compression_encode_scratch_buffer_size(COMPRESSION_LZFSE))!
    defer {
        free(scratchData)
    }
    
    var rgbData = rgbData
    rgbData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Void in
        if let baseAddress = buffer.baseAddress {
            encodeRGBAToYUVA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), baseAddress.assumingMemoryBound(to: UInt8.self), Int32(width), Int32(height), Int32(bytesPerRow))
        }
    }
    
    var maybeResultSize: Int?
    
    compressedFrameData.withUnsafeMutableBytes { buffer -> Void in
        guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return
        }
        let length = compression_encode_buffer(bytes, compressedFrameDataLength, yuvaFrameData.assumingMemoryBound(to: UInt8.self), yuvaLength, scratchData, COMPRESSION_LZFSE)
        maybeResultSize = length
    }
    
    guard let resultSize = maybeResultSize else {
        return nil
    }
    compressedFrameData.count = resultSize
    return compressedFrameData
}

private final class AnimatedStickerDirectFrameSourceCache {
    private enum FrameRangeResult {
        case range(Range<Int>)
        case notFound
        case corruptedFile
    }
    
    private let queue: Queue
    private let storeQueue: Queue
    private let file: ManagedFileImpl
    private let frameCount: Int
    private let width: Int
    private let height: Int
    
    private var isStoringFrames = Set<Int>()
    
    private var scratchBuffer: Data
    private var decodeBuffer: Data
    
    init?(queue: Queue, pathPrefix: String, width: Int, height: Int, frameCount: Int, fitzModifier: EmojiFitzModifier?) {
        self.queue = queue
        self.storeQueue = sharedStoreQueue
        
        self.frameCount = frameCount
        self.width = width
        self.height = height
        
        let suffix : String
        if let fitzModifier = fitzModifier {
            suffix = "_fitz\(fitzModifier.rawValue)"
        } else {
            suffix = ""
        }
        let path = "\(pathPrefix)_\(width):\(height)\(suffix).stickerframecache"
        var file = ManagedFileImpl(queue: queue, path: path, mode: .readwrite)
        if let file = file {
            self.file = file
        } else {
            let _ = try? FileManager.default.removeItem(atPath: path)
            file = ManagedFileImpl(queue: queue, path: path, mode: .readwrite)
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
        if Int64(offset) + Int64(length) > 100 * 1024 * 1024 {
            return .corruptedFile
        }
        
        return .range(Int(offset) ..< Int(offset + length))
    }
    
    func storeUncompressedRgbFrame(index: Int, rgbData: Data) {
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
            let compressedData = compressFrame(width: width, height: height, rgbData: rgbData)
            
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
    
    func readUncompressedYuvFrame(index: Int) -> Data? {
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
    }
}

private final class AnimatedStickerDirectFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private let data: Data
    private let width: Int
    private let height: Int
    private let cache: AnimatedStickerDirectFrameSourceCache?
    private let bytesPerRow: Int
    let frameCount: Int
    let frameRate: Int
    fileprivate var currentFrame: Int
    private let animation: LottieInstance
    
    var frameIndex: Int {
        return self.currentFrame % self.frameCount
    }
    
    init?(queue: Queue, data: Data, width: Int, height: Int, cachePathPrefix: String?, fitzModifier: EmojiFitzModifier?) {
        self.queue = queue
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(width))
        self.currentFrame = 0
        let rawData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
        let decompressedData = transformedWithFitzModifier(data: rawData, fitzModifier: fitzModifier)
        
        guard let animation = LottieInstance(data: decompressedData, fitzModifier: fitzModifier?.lottieFitzModifier ?? .none, cacheKey: "") else {
            return nil
        }
        self.animation = animation
        let frameCount = Int(animation.frameCount)
        self.frameCount = frameCount
        self.frameRate = Int(animation.frameRate)
        
        self.cache = cachePathPrefix.flatMap { cachePathPrefix in
            AnimatedStickerDirectFrameSourceCache(queue: queue, pathPrefix: cachePathPrefix, width: width, height: height, frameCount: frameCount, fitzModifier: fitzModifier)
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func takeFrame(draw: Bool) -> AnimatedStickerFrame? {
        let frameIndex = self.currentFrame % self.frameCount
        self.currentFrame += 1
        if draw {
            if let cache = self.cache, let yuvData = cache.readUncompressedYuvFrame(index: frameIndex) {
                return AnimatedStickerFrame(data: yuvData, type: .yuva, width: self.width, height: self.height, bytesPerRow: self.width * 2, index: frameIndex, isLastFrame: frameIndex == self.frameCount - 1, totalFrames: self.frameCount)
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
    
    func skipToEnd() {
        self.currentFrame = self.frameCount - 1
    }

    func skipToFrameIndex(_ index: Int) {
        self.currentFrame = index
    }
}

public final class AnimatedStickerFrameQueue {
    private let queue: Queue
    private let length: Int
    private let source: AnimatedStickerFrameSource
    private var frames: [AnimatedStickerFrame] = []
    
    public init(queue: Queue, length: Int, source: AnimatedStickerFrameSource) {
        self.queue = queue
        self.length = length
        self.source = source
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    public func take(draw: Bool) -> AnimatedStickerFrame? {
        if self.frames.isEmpty {
            if let frame = self.source.takeFrame(draw: draw) {
                self.frames.append(frame)
            }
        }
        if !self.frames.isEmpty {
            let frame = self.frames.removeFirst()
            return frame
        } else {
            return nil
        }
    }
    
    public func generateFramesIfNeeded() {
        if self.frames.isEmpty {
            if let frame = self.source.takeFrame(draw: true) {
                self.frames.append(frame)
            }
        }
    }
}

public struct AnimatedStickerStatus: Equatable {
    public let playing: Bool
    public let duration: Double
    public let timestamp: Double
    
    public init(playing: Bool, duration: Double, timestamp: Double) {
        self.playing = playing
        self.duration = duration
        self.timestamp = timestamp
    }
}

public protocol AnimatedStickerNodeSource {
    var fitzModifier: EmojiFitzModifier? { get }
    
    func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError>
    func directDataPath() -> Signal<String, NoError>
}

public final class AnimatedStickerNode: ASDisplayNode {
    private let queue: Queue
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let eventsNode: AnimatedStickerNodeDisplayEvents
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    public var started: () -> Void = {}
    private var reportedStarted = false
    
    public var completed: (Bool) -> Void = { _ in }
    public var frameUpdated: (Int, Int) -> Void = { _, _ in }
    public private(set) var currentFrameIndex: Int = 0
    private var playFromIndex: Int?
    
    private let timer = Atomic<SwiftSignalKit.Timer?>(value: nil)
    private let frameSource = Atomic<QueueLocalObject<AnimatedStickerFrameSourceWrapper>?>(value: nil)
    
    private var directData: (Data, String, Int, Int, String?, EmojiFitzModifier?)?
    private var cachedData: (Data, Bool, EmojiFitzModifier?)?
    
    private var renderer: (AnimationRenderer & ASDisplayNode)?
    
    public var isPlaying: Bool = false
    private var currentLoopCount: Int = 0
    private var canDisplayFirstFrame: Bool = false
    private var playbackMode: AnimatedStickerPlaybackMode = .loop
    
    public var stopAtNearestLoop: Bool = false
    
    private let playbackStatus = Promise<AnimatedStickerStatus>()
    public var status: Signal<AnimatedStickerStatus, NoError> {
        return self.playbackStatus.get()
    }
    
    public var autoplay = false
    
    public var visibility = false {
        didSet {
            if self.visibility != oldValue {
                self.updateIsPlaying()
            }
        }
    }
    
    private var isDisplaying = false {
        didSet {
            if self.isDisplaying != oldValue {
                self.updateIsPlaying()
            }
        }
    }
    
    public var isPlayingChanged: (Bool) -> Void = { _ in }
    
    override public init() {
        self.queue = sharedQueue
        self.eventsNode = AnimatedStickerNodeDisplayEvents()
        
        super.init()
        
        self.eventsNode.updated = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isDisplaying = value
        }
        self.addSubnode(self.eventsNode)
    }
    
    deinit {
        self.disposable.dispose()
        self.fetchDisposable.dispose()
        self.timer.swap(nil)?.invalidate()
    }
    
    private weak var nodeToCopyFrameFrom: AnimatedStickerNode?
    override public func didLoad() {
        super.didLoad()
        
        #if targetEnvironment(simulator)
        self.renderer = SoftwareAnimationRenderer()
        #else
        self.renderer = SoftwareAnimationRenderer()
        //self.renderer = MetalAnimationRenderer()
        #endif
        self.renderer?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        if let contents = self.nodeToCopyFrameFrom?.renderer?.contents {
            self.renderer?.contents = contents
        }
        self.nodeToCopyFrameFrom = nil
        self.addSubnode(self.renderer!)
    }
    
    public func cloneCurrentFrame(from otherNode: AnimatedStickerNode?) {
        if let renderer = self.renderer {
            if let contents = otherNode?.renderer?.contents {
                renderer.contents = contents
            }
        } else {
            self.nodeToCopyFrameFrom = otherNode
        }
    }

    public func setup(source: AnimatedStickerNodeSource, width: Int, height: Int, playbackMode: AnimatedStickerPlaybackMode = .loop, mode: AnimatedStickerMode) {
        if width < 2 || height < 2 {
            return
        }
        self.playbackMode = playbackMode
        switch mode {
        case let .direct(cachePathPrefix):
            let f: (String) -> Void = { [weak self] path in
                guard let strongSelf = self else {
                    return
                }
                if let directData = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                    strongSelf.directData = (directData, path, width, height, cachePathPrefix, source.fitzModifier)
                }
                if case let .still(position) = playbackMode {
                    strongSelf.seekTo(position)
                } else if strongSelf.isPlaying || strongSelf.autoplay {
                    if strongSelf.autoplay {
                        strongSelf.isSetUpForPlayback = false
                        strongSelf.isPlaying = true
                    }
                    let fromIndex = strongSelf.playFromIndex
                    strongSelf.playFromIndex = nil
                    strongSelf.play(fromIndex: fromIndex)
                } else if strongSelf.canDisplayFirstFrame {
                    strongSelf.play(firstFrame: true)
                }
            }
            self.disposable.set((source.directDataPath()
            |> deliverOnMainQueue).start(next: { path in
                f(path)
            }))
        case .cached:
            self.disposable.set((source.cachedDataPath(width: width, height: height)
            |> deliverOnMainQueue).start(next: { [weak self] path, complete in
                guard let strongSelf = self else {
                    return
                }
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                    if let (_, currentComplete, _) = strongSelf.cachedData {
                        if !currentComplete {
                            strongSelf.cachedData = (data, complete, source.fitzModifier)
                            strongSelf.frameSource.with { frameSource in
                                frameSource?.with { frameSource in
                                    if let frameSource = frameSource.value as? AnimatedStickerCachedFrameSource {
                                        frameSource.updateData(data: data, complete: complete)
                                    }
                                }
                            }
                        }
                    } else {
                        strongSelf.cachedData = (data, complete, source.fitzModifier)
                        if strongSelf.isPlaying {
                            strongSelf.play()
                        } else if strongSelf.canDisplayFirstFrame {
                            strongSelf.play(firstFrame: true)
                        }
                    }
                }
            }))
        }
    }
    
    public func reset() {
        self.disposable.set(nil)
        self.fetchDisposable.set(nil)
    }
    
    private func updateIsPlaying() {
        guard !self.autoplay else {
            return
        }
        let isPlaying = self.visibility && self.isDisplaying
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            if isPlaying {
                self.play()
            } else{
                self.pause()
            }
            
            self.isPlayingChanged(isPlaying)
        }
        let canDisplayFirstFrame = self.automaticallyLoadFirstFrame && self.isDisplaying
        if self.canDisplayFirstFrame != canDisplayFirstFrame {
            self.canDisplayFirstFrame = canDisplayFirstFrame
            if canDisplayFirstFrame {
                self.play(firstFrame: true)
            }
        }
    }
    
    private var isSetUpForPlayback = false
        
    public func play(firstFrame: Bool = false, fromIndex: Int? = nil) {
        if !firstFrame {
            switch self.playbackMode {
            case .once:
                self.isPlaying = true
            case .count:
                self.currentLoopCount = 0
                self.isPlaying = true
            default:
                break
            }
        }
        if self.isSetUpForPlayback {
            let directData = self.directData
            let cachedData = self.cachedData
            let queue = self.queue
            let timerHolder = self.timer
            let frameSourceHolder = self.frameSource
            self.queue.async { [weak self] in
                var maybeFrameSource: AnimatedStickerFrameSource? = frameSourceHolder.with { $0 }?.syncWith { $0 }.value
                if maybeFrameSource == nil {
                    let notifyUpdated: (() -> Void)? = nil
                    if let directData = directData {
                        maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, fitzModifier: directData.5)
                    } else if let (cachedData, cachedDataComplete, _) = cachedData {
                        if #available(iOS 9.0, *) {
                            maybeFrameSource = AnimatedStickerCachedFrameSource(queue: queue, data: cachedData, complete: cachedDataComplete, notifyUpdated: {
                                notifyUpdated?()
                            })
                        }
                    }
                    let _ = frameSourceHolder.swap(maybeFrameSource.flatMap { maybeFrameSource in
                        return QueueLocalObject(queue: queue, generate: {
                            return AnimatedStickerFrameSourceWrapper(maybeFrameSource)
                        })
                    })
                }
                guard let frameSource = maybeFrameSource else {
                    return
                }
                if let fromIndex = fromIndex {
                    frameSource.skipToFrameIndex(fromIndex)
                }
                let frameQueue = QueueLocalObject<AnimatedStickerFrameQueue>(queue: queue, generate: {
                    return AnimatedStickerFrameQueue(queue: queue, length: 1, source: frameSource)
                })
                timerHolder.swap(nil)?.invalidate()
                
                let duration: Double = frameSource.frameRate > 0 ? Double(frameSource.frameCount) / Double(frameSource.frameRate) : 0
                let frameRate = frameSource.frameRate
                
                let timer = SwiftSignalKit.Timer(timeout: 1.0 / Double(frameRate), repeat: !firstFrame, completion: {
                    let frame = frameQueue.syncWith { frameQueue in
                        return frameQueue.take(draw: true)
                    }
                    if let frame = frame {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.renderer?.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, completion: {
                                guard let strongSelf = self else {
                                    return
                                }
                                if !strongSelf.reportedStarted {
                                    strongSelf.reportedStarted = true
                                    strongSelf.started()
                                }
                            })
                            
                            strongSelf.frameUpdated(frame.index, frame.totalFrames)
                            strongSelf.currentFrameIndex = frame.index
                            
                            if frame.isLastFrame {
                                var stopped = false
                                var stopNow = false
                                if case .still = strongSelf.playbackMode {
                                    stopNow = true
                                } else if case .once = strongSelf.playbackMode {
                                    stopNow = true
                                } else if case let .count(count) = strongSelf.playbackMode {
                                    strongSelf.currentLoopCount += 1
                                    if count <= strongSelf.currentLoopCount {
                                        stopNow = true
                                    }
                                } else if strongSelf.stopAtNearestLoop {
                                    stopNow = true
                                }
                                if stopNow {
                                    strongSelf.stop()
                                    strongSelf.isPlaying = false
                                    stopped = true
                                }
                                
                                strongSelf.completed(stopped)
                            }

                            let timestamp: Double = frameRate > 0 ? Double(frame.index) / Double(frameRate) : 0
                            strongSelf.playbackStatus.set(.single(AnimatedStickerStatus(playing: strongSelf.isPlaying, duration: duration, timestamp: timestamp)))
                        }
                    }
                    frameQueue.with { frameQueue in
                        frameQueue.generateFramesIfNeeded()
                    }
                }, queue: queue)
                let _ = timerHolder.swap(timer)
                timer.start()
            }
        } else {
            self.isSetUpForPlayback = true
            let directData = self.directData
            let cachedData = self.cachedData
            if directData == nil && cachedData == nil {
                self.playFromIndex = fromIndex
            }
            let queue = self.queue
            let timerHolder = self.timer
            let frameSourceHolder = self.frameSource
            self.queue.async { [weak self] in
                var maybeFrameSource: AnimatedStickerFrameSource?
                let notifyUpdated: (() -> Void)? = nil
                if let directData = directData {
                    maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, fitzModifier: directData.5)
                } else if let (cachedData, cachedDataComplete, _) = cachedData {
                    if #available(iOS 9.0, *) {
                        maybeFrameSource = AnimatedStickerCachedFrameSource(queue: queue, data: cachedData, complete: cachedDataComplete, notifyUpdated: {
                            notifyUpdated?()
                        })
                    }
                }
                let _ = frameSourceHolder.swap(maybeFrameSource.flatMap { maybeFrameSource in
                    return QueueLocalObject(queue: queue, generate: {
                        return AnimatedStickerFrameSourceWrapper(maybeFrameSource)
                    })
                })
                guard let frameSource = maybeFrameSource else {
                    return
                }
                if let fromIndex = fromIndex {
                    frameSource.skipToFrameIndex(fromIndex)
                }
                let frameQueue = QueueLocalObject<AnimatedStickerFrameQueue>(queue: queue, generate: {
                    return AnimatedStickerFrameQueue(queue: queue, length: 1, source: frameSource)
                })
                timerHolder.swap(nil)?.invalidate()
                
                let duration: Double = frameSource.frameRate > 0 ? Double(frameSource.frameCount) / Double(frameSource.frameRate) : 0
                let frameRate = frameSource.frameRate
                
                let timer = SwiftSignalKit.Timer(timeout: 1.0 / Double(frameRate), repeat: !firstFrame, completion: {
                    let frame = frameQueue.syncWith { frameQueue in
                        return frameQueue.take(draw: true)
                    }
                    if let frame = frame {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }

                            assert(frame.bytesPerRow != 0)
                            
                            strongSelf.renderer?.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, completion: {
                                guard let strongSelf = self else {
                                    return
                                }
                                if !strongSelf.reportedStarted {
                                    strongSelf.reportedStarted = true
                                    strongSelf.started()
                                }
                            })
                            
                            strongSelf.frameUpdated(frame.index, frame.totalFrames)
                            strongSelf.currentFrameIndex = frame.index
                            
                            if frame.isLastFrame {
                                var stopped = false
                                var stopNow = false
                                if case .still = strongSelf.playbackMode {
                                    stopNow = true
                                } else if case .once = strongSelf.playbackMode {
                                    stopNow = true
                                } else if case let .count(count) = strongSelf.playbackMode {
                                    strongSelf.currentLoopCount += 1
                                    if count <= strongSelf.currentLoopCount {
                                        stopNow = true
                                    }
                                } else if strongSelf.stopAtNearestLoop {
                                    stopNow = true
                                }
                                if stopNow {
                                    strongSelf.stop()
                                    strongSelf.isPlaying = false
                                    stopped = true
                                }
                                
                                strongSelf.completed(stopped)
                            }
                                                        
                            let timestamp: Double = frameRate > 0 ? Double(frame.index) / Double(frameRate) : 0
                            strongSelf.playbackStatus.set(.single(AnimatedStickerStatus(playing: strongSelf.isPlaying, duration: duration, timestamp: timestamp)))
                        }
                    }
                    frameQueue.with { frameQueue in
                        frameQueue.generateFramesIfNeeded()
                    }
                }, queue: queue)
                let _ = timerHolder.swap(timer)
                timer.start()
            }
        }
    }
    
    public func pause() {
        self.timer.swap(nil)?.invalidate()
    }
    
    public func stop() {
        self.isSetUpForPlayback = false
        self.reportedStarted = false
        self.timer.swap(nil)?.invalidate()
        if self.playToCompletionOnStop {
            self.seekTo(.start)
        }
    }
    
    public func seekTo(_ position: AnimatedStickerPlaybackPosition) {
        self.isPlaying = false
        
        let directData = self.directData
        let cachedData = self.cachedData
        let queue = self.queue
        let frameSourceHolder = self.frameSource
        let timerHolder = self.timer
        self.queue.async { [weak self] in
            var maybeFrameSource: AnimatedStickerFrameSource? = frameSourceHolder.with { $0 }?.syncWith { $0 }.value
            if case .timestamp = position {
            } else {
                if let directData = directData {
                    maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, fitzModifier: directData.5)
                    if case .end = position {
                        maybeFrameSource?.skipToEnd()
                    }
                } else if let (cachedData, cachedDataComplete, _) = cachedData {
                    if #available(iOS 9.0, *) {
                        maybeFrameSource = AnimatedStickerCachedFrameSource(queue: queue, data: cachedData, complete: cachedDataComplete, notifyUpdated: {})
                    }
                }
            }

            guard let frameSource = maybeFrameSource else {
                return
            }
            let frameQueue = QueueLocalObject<AnimatedStickerFrameQueue>(queue: queue, generate: {
                return AnimatedStickerFrameQueue(queue: queue, length: 1, source: frameSource)
            })
            timerHolder.swap(nil)?.invalidate()
            
            let duration: Double = frameSource.frameRate > 0 ? Double(frameSource.frameCount) / Double(frameSource.frameRate) : 0
        
            var maybeFrame: AnimatedStickerFrame??
            if case let .timestamp(timestamp) = position {
                var stickerTimestamp = timestamp
                while stickerTimestamp > duration {
                    stickerTimestamp -= duration
                }
                let targetFrame = Int(stickerTimestamp / duration * Double(frameSource.frameCount))
                if targetFrame == frameSource.frameIndex {
                    return
                }
                
                var delta = targetFrame - frameSource.frameIndex
                if delta < 0 {
                    delta = frameSource.frameCount + delta
                }
                for i in 0 ..< delta {
                    maybeFrame = frameQueue.syncWith { frameQueue in
                        return frameQueue.take(draw: i == delta - 1)
                    }
                }
            } else if case let .frameIndex(frameIndex) = position {
                let targetFrame = frameIndex
                if targetFrame == frameSource.frameIndex {
                    return
                }

                var delta = targetFrame - frameSource.frameIndex
                if delta < 0 {
                    delta = frameSource.frameCount + delta
                }
                for i in 0 ..< delta {
                    maybeFrame = frameQueue.syncWith { frameQueue in
                        return frameQueue.take(draw: i == delta - 1)
                    }
                }
            } else {
                maybeFrame = frameQueue.syncWith { frameQueue in
                    return frameQueue.take(draw: true)
                }
            }
            if let maybeFrame = maybeFrame, let frame = maybeFrame {
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.renderer?.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, completion: {
                        guard let strongSelf = self else {
                            return
                        }
                        if !strongSelf.reportedStarted {
                            strongSelf.reportedStarted = true
                            strongSelf.started()
                        }
                    })

                    strongSelf.playbackStatus.set(.single(AnimatedStickerStatus(playing: false, duration: duration, timestamp: 0.0)))
                }
            }
            frameQueue.with { frameQueue in
                frameQueue.generateFramesIfNeeded()
            }
        }
    }
    
    public func playIfNeeded() -> Bool {
        if !self.isPlaying {
            self.isPlaying = true
            self.play()
            return true
        }
        return false
    }
    
    public func updateLayout(size: CGSize) {
        self.renderer?.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    public func setOverlayColor(_ color: UIColor?, animated: Bool) {
        self.renderer?.setOverlayColor(color, animated: animated)
    }
}
