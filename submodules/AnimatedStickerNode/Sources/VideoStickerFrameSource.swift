import Foundation
import Compression
import Display
import SwiftSignalKit
import UniversalMediaPlayer
import CoreMedia
import ManagedFile
import Accelerate
import TelegramCore

private let sharedStoreQueue = Queue.concurrentDefaultQueue()

private let maximumFrameCount = 30 * 10

private final class VideoStickerFrameSourceCache {
    private enum FrameRangeResult {
        case range(Range<Int>)
        case notFound
        case corruptedFile
    }
    
    private let queue: Queue
    private let storeQueue: Queue
    private let path: String
    private let file: ManagedFile
    private let width: Int
    private let height: Int
    
    public private(set) var frameRate: Int32 = 0
    public private(set) var frameCount: Int32 = 0
    
    private var isStoringFrames = Set<Int>()
    var storedFrames: Int {
        return self.isStoringFrames.count
    }
    
    private var scratchBuffer: Data
    private var decodeBuffer: Data
    
    init?(queue: Queue, pathPrefix: String, width: Int, height: Int) {
        self.queue = queue
        self.storeQueue = sharedStoreQueue
        
        self.width = width
        self.height = height
        
        let version: Int = 3
        self.path = "\(pathPrefix)_\(width)x\(height)-v\(version).vstickerframecache"
        var file = ManagedFile(queue: queue, path: self.path, mode: .readwrite)
        if let file = file {
            self.file = file
        } else {
            let _ = try? FileManager.default.removeItem(atPath: self.path)
            file = ManagedFile(queue: queue, path: self.path, mode: .readwrite)
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
    
    deinit {
        if self.frameCount == 0 {
            let _ = try? FileManager.default.removeItem(atPath: self.path)
        }
    }
    
    private func initializeFrameTable() {
        var reset = true
        if let size = self.file.getSize(), size >= maximumFrameCount {
            if self.readFrameRate() {
                reset = false
            }
        }
        if reset {
            self.file.truncate(count: 0)
            var zero: Int32 = 0
            let _ = self.file.write(&zero, count: 4)
            let _ = self.file.write(&zero, count: 4)
            
            for _ in 0 ..< maximumFrameCount {
                let _ = self.file.write(&zero, count: 4)
                let _ = self.file.write(&zero, count: 4)
            }
        }
    }
    
    private func readFrameRate() -> Bool {
        guard self.frameCount == 0 else {
            return true
        }
       
        self.file.seek(position: 0)
        var frameRate: Int32 = 0
        if self.file.read(&frameRate, 4) != 4 {
            return false
        }
        if frameRate < 0 {
            return false
        }
        if frameRate == 0 {
            return false
        }
        self.frameRate = frameRate
        
        self.file.seek(position: 4)
        
        var frameCount: Int32 = 0
        if self.file.read(&frameCount, 4) != 4 {
            return false
        }
        
        if frameCount < 0 {
            return false
        }
        if frameCount == 0 {
            return false
        }
        self.frameCount = frameCount
        
        return true
    }
    
    private func readFrameRange(index: Int) -> FrameRangeResult {
        if index < 0 || index >= maximumFrameCount {
            return .notFound
        }
        
        guard self.readFrameRate() else {
            return .notFound
        }
                
        if index >= self.frameCount {
            return .notFound
        }
        
        self.file.seek(position: Int64(8 + index * 4 * 2))
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
    
    func storeFrameRateAndCount(frameRate: Int, frameCount: Int) {
        self.file.seek(position: 0)
        var frameRate = Int32(frameRate)
        let _ = self.file.write(&frameRate, count: 4)
       
        self.file.seek(position: 4)
        var frameCount = Int32(frameCount)
        let _ = self.file.write(&frameCount, count: 4)
    }
    
    func storeUncompressedRgbFrame(index: Int, rgbData: Data) {
        if index < 0 || index >= maximumFrameCount {
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
            let compressedData = compressFrame(width: width, height: height, rgbData: rgbData, unpremultiply: false)
            
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
                
                strongSelf.file.seek(position: Int64(8 + index * 4 * 2))
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
    
    func readUncompressedYuvaFrame(index: Int) -> Data? {
        if index < 0 || index >= maximumFrameCount {
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

private let useCache = true

final class VideoStickerDirectFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private let path: String
    private let width: Int
    private let height: Int
    private let cache: VideoStickerFrameSourceCache?
    private let bytesPerRow: Int
    var frameCount: Int
    let frameRate: Int
    fileprivate var currentFrame: Int
    
    private let source: SoftwareVideoSource?
    
    var frameIndex: Int {
        return self.currentFrame % self.frameCount
    }
    
    init?(queue: Queue, path: String, width: Int, height: Int, cachePathPrefix: String?) {
        self.queue = queue
        self.path = path
        self.width = width
        self.height = height
        self.bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(self.width))
        self.currentFrame = 0
  
        self.cache = cachePathPrefix.flatMap { cachePathPrefix in
            VideoStickerFrameSourceCache(queue: queue, pathPrefix: cachePathPrefix, width: width, height: height)
        }
        
        if useCache, let cache = self.cache, cache.frameCount > 0 {
            self.source = nil
            self.frameRate = Int(cache.frameRate)
            self.frameCount = Int(cache.frameCount)
        } else {
            let source = SoftwareVideoSource(path: path, hintVP9: true)
            self.source = source
            self.frameRate = min(30, source.getFramerate())
            self.frameCount = 0
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func takeFrame(draw: Bool) -> AnimatedStickerFrame? {
        let frameIndex: Int
        if self.frameCount > 0 {
            frameIndex = self.currentFrame % self.frameCount
        } else {
            frameIndex = self.currentFrame
        }

        self.currentFrame += 1
        if draw {
            if useCache, let cache = self.cache, let yuvData = cache.readUncompressedYuvaFrame(index: frameIndex) {
                return AnimatedStickerFrame(data: yuvData, type: .yuva, width: self.width, height: self.height, bytesPerRow: self.width * 2, index: frameIndex, isLastFrame: frameIndex == self.frameCount - 1, totalFrames: self.frameCount)
            } else if let source = self.source {
                let frameAndLoop = source.readFrame(maxPts: nil)
                if frameAndLoop.0 == nil {
                    if frameAndLoop.3 {
                        if self.frameCount == 0 {
                            if let cache = self.cache {
                                if cache.storedFrames == frameIndex {
                                    self.frameCount = frameIndex
                                    cache.storeFrameRateAndCount(frameRate: self.frameRate, frameCount: self.frameCount)
                                } else {
                                    Logger.shared.log("VideoSticker", "Missed a frame? \(frameIndex) \(cache.storedFrames)")
                                }
                            } else {
                                self.frameCount = frameIndex
                            }
                        }
                        self.currentFrame = 0
                    } else {
                        Logger.shared.log("VideoSticker", "Skipped a frame?")
                    }
                    return nil
                }
                
                guard let frame = frameAndLoop.0 else {
                    return nil
                }
                
                var frameData = Data(count: self.bytesPerRow * self.height)
                frameData.withUnsafeMutableBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    
                    let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer)
                    CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
                    let width = CVPixelBufferGetWidth(imageBuffer!)
                    let height = CVPixelBufferGetHeight(imageBuffer!)
                    let srcData = CVPixelBufferGetBaseAddress(imageBuffer!)
                    
                    var sourceBuffer = vImage_Buffer(data: srcData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
                    var destBuffer = vImage_Buffer(data: bytes, height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: self.bytesPerRow)
                               
                    let _ = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageDoNotTile))
                    
                    CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                }

                self.cache?.storeUncompressedRgbFrame(index: frameIndex, rgbData: frameData)
                                
                return AnimatedStickerFrame(data: frameData, type: .argb, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: frameIndex == self.frameCount - 1, totalFrames: self.frameCount, multiplyAlpha: true)
            } else {
                return nil
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
