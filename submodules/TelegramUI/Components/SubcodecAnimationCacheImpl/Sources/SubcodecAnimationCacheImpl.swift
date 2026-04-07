import Foundation
import UIKit
import SwiftSignalKit
import CryptoUtils
import ManagedFile
import AnimationCache
import SubcodecObjC

public struct MbsMetadata {
    public let frameCount: Int
    public let frameDurations: [Double]
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
    let directory = String(hashString[hashString.startIndex ..< hashString.index(hashString.startIndex, offsetBy: 2)])
    return (directory, "\(hashString)_\(width)x\(height)")
}

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 {
        return numToRound
    }
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound
    }
    return numToRound + multiple - remainder
}

private func convertARGBToYUVA420(
    argb: UnsafePointer<UInt8>,
    width: Int,
    height: Int,
    bytesPerRow: Int
) -> (y: Data, cb: Data, cr: Data, alpha: Data, yStride: Int, cbStride: Int, crStride: Int, alphaStride: Int) {
    let chromaWidth = width / 2
    let chromaHeight = height / 2

    var yData = Data(count: width * height)
    var cbData = Data(count: chromaWidth * chromaHeight)
    var crData = Data(count: chromaWidth * chromaHeight)
    var alphaData = Data(count: width * height)

    yData.withUnsafeMutableBytes { yBuf in
        cbData.withUnsafeMutableBytes { cbBuf in
            crData.withUnsafeMutableBytes { crBuf in
                alphaData.withUnsafeMutableBytes { aBuf in
                    let yPtr = yBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let cbPtr = cbBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let crPtr = crBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let aPtr = aBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    for row in 0 ..< height {
                        let srcRow = argb.advanced(by: row * bytesPerRow)
                        for col in 0 ..< width {
                            let px = srcRow.advanced(by: col * 4)
                            // BGRA layout (CoreGraphics premultiplied)
                            let b = Int(px[0])
                            let g = Int(px[1])
                            let r = Int(px[2])
                            let a = Int(px[3])

                            // Un-premultiply
                            let rr: Int
                            let gg: Int
                            let bb: Int
                            if a > 0 {
                                rr = min(255, r * 255 / a)
                                gg = min(255, g * 255 / a)
                                bb = min(255, b * 255 / a)
                            } else {
                                rr = 0
                                gg = 0
                                bb = 0
                            }

                            // BT.709
                            let y = 16 + (65 * rr + 129 * gg + 25 * bb + 128) / 256
                            yPtr[row * width + col] = UInt8(clamping: y)
                            aPtr[row * width + col] = UInt8(a)
                        }
                    }

                    // Chroma at half resolution (average 2x2 blocks)
                    for row in 0 ..< chromaHeight {
                        for col in 0 ..< chromaWidth {
                            var sumR = 0
                            var sumG = 0
                            var sumB = 0
                            for dy in 0 ..< 2 {
                                for dx in 0 ..< 2 {
                                    let srcRow = argb.advanced(by: (row * 2 + dy) * bytesPerRow)
                                    let px = srcRow.advanced(by: (col * 2 + dx) * 4)
                                    let b = Int(px[0])
                                    let g = Int(px[1])
                                    let r = Int(px[2])
                                    let a = Int(px[3])
                                    if a > 0 {
                                        sumR += min(255, r * 255 / a)
                                        sumG += min(255, g * 255 / a)
                                        sumB += min(255, b * 255 / a)
                                    }
                                }
                            }
                            let avgR = sumR / 4
                            let avgG = sumG / 4
                            let avgB = sumB / 4

                            let cb = 128 + (-38 * avgR - 74 * avgG + 112 * avgB + 128) / 256
                            let cr = 128 + (112 * avgR - 94 * avgG - 18 * avgB + 128) / 256
                            cbPtr[row * chromaWidth + col] = UInt8(clamping: cb)
                            crPtr[row * chromaWidth + col] = UInt8(clamping: cr)
                        }
                    }
                }
            }
        }
    }

    return (yData, cbData, crData, alphaData, width, chromaWidth, chromaWidth, width)
}

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    struct CompressedResult {
        var mbsPath: String
        var metaPath: String
    }

    var queue: Queue {
        return self.innerQueue
    }
    let innerQueue: Queue
    var isCancelled: Bool = false

    private let mbsOutputPath: String
    private let metaOutputPath: String
    private let completion: (CompressedResult?) -> Void

    private var spriteExtractor: SCSprite?
    private var frameDurations: [Double] = []
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    private var spriteWidth: Int = 0
    private var spriteHeight: Int = 0

    private let lock = Lock()

    init?(queue: Queue, allocateTempFile: @escaping () -> String, completion: @escaping (CompressedResult?) -> Void) {
        self.innerQueue = queue
        self.mbsOutputPath = allocateTempFile()
        self.metaOutputPath = allocateTempFile()
        self.completion = completion
    }

    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool) {
        self.lock.locked {
            if self.isFailed || self.isFinished {
                return
            }

            let width = roundUp(proposedWidth, multiple: 16)
            let height = roundUp(proposedHeight, multiple: 16)

            if width == 0 || height == 0 {
                self.isFailed = true
                return
            }

            // Create extractor on first frame
            if self.spriteExtractor == nil {
                self.spriteWidth = width
                self.spriteHeight = height
                let spriteSize = max(width, height)
                do {
                    self.spriteExtractor = try SCSprite.extractor(withSpriteSize: Int32(spriteSize), qp: 26, outputPath: self.mbsOutputPath)
                } catch {
                    self.isFailed = true
                    return
                }
            }

            guard self.spriteWidth == width && self.spriteHeight == height else {
                self.isFailed = true
                return
            }

            // Allocate ARGB surface
            let bytesPerRow = width * 4
            let bufferSize = height * bytesPerRow
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            memset(buffer, 0, bufferSize)

            guard let duration = drawingBlock(AnimationCacheItemDrawingSurface(
                argb: buffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                length: bufferSize
            )) else {
                return
            }

            // Convert ARGB → YUV planes
            let planes = convertARGBToYUVA420(
                argb: buffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )

            // Feed to extractor
            do {
                try self.spriteExtractor?.addFrameY(
                    planes.y, yStride: Int32(planes.yStride),
                    cb: planes.cb, cbStride: Int32(planes.cbStride),
                    cr: planes.cr, crStride: Int32(planes.crStride),
                    alpha: planes.alpha, alphaStride: Int32(planes.alphaStride)
                )
            } catch {
                self.isFailed = true
                return
            }

            self.frameDurations.append(duration)
        }
    }

    func finish() {
        var result: CompressedResult?

        self.lock.locked {
            if self.isFinished {
                return
            }
            self.isFinished = true

            if self.isFailed || self.spriteExtractor == nil {
                return
            }

            do {
                try self.spriteExtractor?.finalizeExtraction()
            } catch {
                self.isFailed = true
                return
            }

            // Write metadata file: frame count + durations
            var metaData = Data()
            var frameCount = UInt32(self.frameDurations.count)
            metaData.append(Data(bytes: &frameCount, count: 4))
            for duration in self.frameDurations {
                var d = Float32(duration)
                metaData.append(Data(bytes: &d, count: 4))
            }
            do {
                try metaData.write(to: URL(fileURLWithPath: self.metaOutputPath))
            } catch {
                self.isFailed = true
                return
            }

            result = CompressedResult(mbsPath: self.mbsOutputPath, metaPath: self.metaOutputPath)
        }

        if !self.isFailed {
            self.completion(result)
        } else {
            let _ = try? FileManager.default.removeItem(atPath: self.mbsOutputPath)
            let _ = try? FileManager.default.removeItem(atPath: self.metaOutputPath)
            self.completion(nil)
        }
    }
}

private func decodeSingleFrameFromMbs(mbsPath: String, metadata: MbsMetadata) -> AnimationCacheItemFrame? {
    guard let mbsData = try? Data(contentsOf: URL(fileURLWithPath: mbsPath), options: .mappedIfSafe) else {
        return nil
    }
    guard mbsData.count >= 14 else {
        return nil
    }
    guard mbsData[0] == 0x4D, mbsData[1] == 0x42, mbsData[2] == 0x53, mbsData[3] == 0x36 else {
        return nil
    }
    let _ = Int(mbsData[4]) | (Int(mbsData[5]) << 8)
    let heightMbs = Int(mbsData[6]) | (Int(mbsData[7]) << 8)
    let qp = Int(mbsData[10])

    let spriteContentSize = heightMbs * 16 - 32
    guard spriteContentSize > 0 else {
        return nil
    }

    var nalData: Data?
    let sinkBlock: (Data) -> Void = { data in
        if nalData == nil {
            nalData = data
        } else {
            nalData!.append(data)
        }
    }

    guard let surface = try? SCMuxSurface.create(
        withSpriteWidth: Int32(spriteContentSize),
        spriteHeight: Int32(spriteContentSize),
        maxSlots: 1,
        qp: Int32(qp),
        sink: sinkBlock
    ) else {
        return nil
    }

    guard let region = try? surface.addSprite(atPath: mbsPath) else {
        return nil
    }

    nalData = nil
    guard let _ = try? surface.advanceFrame(sink: sinkBlock) else {
        return nil
    }

    guard let streamData = nalData else {
        return nil
    }

    guard let decoder = try? SCVideoToolboxDecoder.createDecoder() else {
        return nil
    }
    guard let frames = try? decoder.decodeStream(streamData) else {
        return nil
    }
    guard let decodedFrame = frames.first else {
        return nil
    }

    return extractSpriteFrame(
        decodedFrame: decodedFrame,
        region: region,
        spriteContentWidth: spriteContentSize,
        spriteContentHeight: spriteContentSize
    )
}

private func extractSpriteFrame(
    decodedFrame: SCDecodedFrame,
    region: SCSpriteRegion,
    spriteContentWidth: Int,
    spriteContentHeight: Int
) -> AnimationCacheItemFrame? {
    let colorRect = region.colorRect
    let alphaRect = region.alphaRect

    let frameWidth = Int(colorRect.width)
    let frameHeight = Int(colorRect.height)

    guard frameWidth > 0 && frameHeight > 0 else {
        return nil
    }

    let decodedWidth = Int(decodedFrame.width)

    let bytesPerRow = frameWidth * 4
    var argbData = Data(count: frameHeight * bytesPerRow)

    decodedFrame.y.withUnsafeBytes { yBuf in
        decodedFrame.cb.withUnsafeBytes { cbBuf in
            decodedFrame.cr.withUnsafeBytes { crBuf in
                argbData.withUnsafeMutableBytes { outBuf in
                    let yPtr = yBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let cbPtr = cbBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let crPtr = crBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let outPtr = outBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    let colorX = Int(colorRect.origin.x)
                    let colorY = Int(colorRect.origin.y)
                    let alphaX = Int(alphaRect.origin.x)
                    let alphaY = Int(alphaRect.origin.y)

                    let chromaWidth = decodedWidth / 2

                    for row in 0 ..< frameHeight {
                        for col in 0 ..< frameWidth {
                            let srcY = yPtr[(colorY + row) * decodedWidth + (colorX + col)]
                            let srcCb = cbPtr[((colorY + row) / 2) * chromaWidth + ((colorX + col) / 2)]
                            let srcCr = crPtr[((colorY + row) / 2) * chromaWidth + ((colorX + col) / 2)]
                            let srcA = yPtr[(alphaY + row) * decodedWidth + (alphaX + col)]

                            let yVal = Int(srcY) - 16
                            let cbVal = Int(srcCb) - 128
                            let crVal = Int(srcCr) - 128

                            var r = (298 * yVal + 459 * crVal + 128) >> 8
                            var g = (298 * yVal - 55 * cbVal - 136 * crVal + 128) >> 8
                            var b = (298 * yVal + 541 * cbVal + 128) >> 8

                            r = max(0, min(255, r))
                            g = max(0, min(255, g))
                            b = max(0, min(255, b))

                            let a = Int(srcA)

                            let pr = (r * a + 127) / 255
                            let pg = (g * a + 127) / 255
                            let pb = (b * a + 127) / 255

                            let outOffset = (row * frameWidth + col) * 4
                            outPtr[outOffset + 0] = UInt8(pb)
                            outPtr[outOffset + 1] = UInt8(pg)
                            outPtr[outOffset + 2] = UInt8(pr)
                            outPtr[outOffset + 3] = UInt8(a)
                        }
                    }
                }
            }
        }
    }

    return AnimationCacheItemFrame(
        format: .rgba(data: argbData, width: frameWidth, height: frameHeight, bytesPerRow: bytesPerRow),
        duration: 1.0 / 30.0
    )
}

private func loadMbsMetadata(metaPath: String) -> MbsMetadata? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: metaPath), options: .mappedIfSafe) else {
        return nil
    }
    guard data.count >= 4 else {
        return nil
    }
    var frameCount: UInt32 = 0
    withUnsafeMutableBytes(of: &frameCount) { buf in
        data.copyBytes(to: buf.baseAddress!.assumingMemoryBound(to: UInt8.self), from: 0 ..< 4)
    }
    let expectedSize = 4 + Int(frameCount) * 4
    guard data.count >= expectedSize else {
        return nil
    }
    var durations: [Double] = []
    for i in 0 ..< Int(frameCount) {
        var d: Float32 = 0
        let offset = 4 + i * 4
        withUnsafeMutableBytes(of: &d) { buf in
            data.copyBytes(to: buf.baseAddress!.assumingMemoryBound(to: UInt8.self), from: offset ..< offset + 4)
        }
        durations.append(Double(d))
    }
    return MbsMetadata(frameCount: Int(frameCount), frameDurations: durations)
}

public final class SubcodecAnimationCacheImpl: AnimationCache {
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
        private let updateStorageStats: (String, Int64) -> Void

        private let fetchQueues: [Queue]
        private var nextFetchQueueIndex: Int = 0

        private var itemContexts: [ItemKey: ItemContext] = [:]

        init(queue: Queue, basePath: String, allocateTempFile: @escaping () -> String, updateStorageStats: @escaping (String, Int64) -> Void) {
            self.queue = queue

            let fetchQueueCount: Int
            if ProcessInfo.processInfo.processorCount > 2 {
                fetchQueueCount = 3
            } else {
                fetchQueueCount = 2
            }
            self.fetchQueues = (0 ..< fetchQueueCount).map { i in Queue(name: "SubcodecAnimationCacheImpl-Fetch\(i)", qos: .default) }
            self.basePath = basePath
            self.allocateTempFile = allocateTempFile
            self.updateStorageStats = updateStorageStats
        }

        func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable, updateResult: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
            let mbsPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs"
            let metaPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs.meta"

            if FileManager.default.fileExists(atPath: mbsPath), let metadata = loadMbsMetadata(metaPath: metaPath) {
                if let frame = decodeSingleFrameFromMbs(mbsPath: mbsPath, metadata: metadata) {
                    let item = AnimationCacheItem(numFrames: metadata.frameCount, advanceImpl: { _, _ in
                        return AnimationCacheItem.AdvanceResult(frame: frame, didLoop: false)
                    }, resetImpl: {})
                    updateResult(AnimationCacheItemResult(item: item, isFinal: true))
                    return EmptyDisposable
                }
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
                let updateStorageStats = self.updateStorageStats

                guard let writer = AnimationCacheItemWriterImpl(queue: self.fetchQueues[fetchQueueIndex % self.fetchQueues.count], allocateTempFile: allocateTempFile, completion: { [weak self, weak itemContext] result in
                    queue.async {
                        guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[key] else {
                            return
                        }

                        strongSelf.itemContexts.removeValue(forKey: key)

                        guard let result = result else {
                            for f in itemContext.subscribers.copyItems() {
                                f(AnimationCacheItemResult(item: nil, isFinal: true))
                            }
                            return
                        }

                        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
                            return
                        }
                        let _ = try? FileManager.default.removeItem(atPath: mbsPath)
                        let _ = try? FileManager.default.removeItem(atPath: metaPath)
                        guard let _ = try? FileManager.default.moveItem(atPath: result.mbsPath, toPath: mbsPath) else {
                            return
                        }
                        guard let _ = try? FileManager.default.moveItem(atPath: result.metaPath, toPath: metaPath) else {
                            return
                        }

                        if let size = SubcodecAnimationCacheImpl.fileSize(mbsPath) {
                            updateStorageStats(mbsPath, size)
                        }

                        guard let metadata = loadMbsMetadata(metaPath: metaPath) else {
                            return
                        }

                        for f in itemContext.subscribers.copyItems() {
                            if let frame = decodeSingleFrameFromMbs(mbsPath: mbsPath, metadata: metadata) {
                                let item = AnimationCacheItem(numFrames: metadata.frameCount, advanceImpl: { _, _ in
                                    return AnimationCacheItem.AdvanceResult(frame: frame, didLoop: false)
                                }, resetImpl: {})
                                f(AnimationCacheItemResult(item: item, isFinal: true))
                            } else {
                                f(AnimationCacheItemResult(item: nil, isFinal: true))
                            }
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
    }

    private static func fileSize(_ path: String) -> Int64? {
        var value = stat()
        if stat(path, &value) == 0 {
            return value.st_size
        }
        return nil
    }

    private let queue: Queue
    private let basePath: String
    private let impl: QueueLocalObject<Impl>
    private let allocateTempFile: () -> String
    private let updateStorageStats: (String, Int64) -> Void

    public init(basePath: String, allocateTempFile: @escaping () -> String, updateStorageStats: @escaping (String, Int64) -> Void) {
        let queue = Queue()
        self.queue = queue
        self.basePath = basePath
        self.allocateTempFile = allocateTempFile
        self.updateStorageStats = updateStorageStats
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, basePath: basePath, allocateTempFile: allocateTempFile, updateStorageStats: updateStorageStats)
        })
    }

    // MARK: - AnimationCache protocol

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
        let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
        let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
        let mbsPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs"
        let metaPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs.meta"

        guard FileManager.default.fileExists(atPath: mbsPath), let metadata = loadMbsMetadata(metaPath: metaPath) else {
            return nil
        }
        guard let frame = decodeSingleFrameFromMbs(mbsPath: mbsPath, metadata: metadata) else {
            return nil
        }
        return AnimationCacheItem(numFrames: 1, advanceImpl: { _, _ in
            return AnimationCacheItem.AdvanceResult(frame: frame, didLoop: false)
        }, resetImpl: {})
    }

    public func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable {
        let disposable = MetaDisposable()
        let basePath = self.basePath
        let allocateTempFile = self.allocateTempFile
        let updateStorageStats = self.updateStorageStats

        queue.async {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
            let itemDirectoryPath = "\(basePath)/\(sourceIdPath.directory)"
            let mbsPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs"
            let metaPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs.meta"

            if FileManager.default.fileExists(atPath: mbsPath), let metadata = loadMbsMetadata(metaPath: metaPath) {
                if let frame = decodeSingleFrameFromMbs(mbsPath: mbsPath, metadata: metadata) {
                    let item = AnimationCacheItem(numFrames: 1, advanceImpl: { _, _ in
                        return AnimationCacheItem.AdvanceResult(frame: frame, didLoop: false)
                    }, resetImpl: {})
                    completion(AnimationCacheItemResult(item: item, isFinal: true))
                    return
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
                        let _ = try? FileManager.default.removeItem(atPath: mbsPath)
                        let _ = try? FileManager.default.removeItem(atPath: metaPath)
                        guard let _ = try? FileManager.default.moveItem(atPath: result.mbsPath, toPath: mbsPath) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        guard let _ = try? FileManager.default.moveItem(atPath: result.metaPath, toPath: metaPath) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        if let size = SubcodecAnimationCacheImpl.fileSize(mbsPath) {
                            updateStorageStats(mbsPath, size)
                        }
                        guard let metadata = loadMbsMetadata(metaPath: metaPath) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        guard let frame = decodeSingleFrameFromMbs(mbsPath: mbsPath, metadata: metadata) else {
                            completion(AnimationCacheItemResult(item: nil, isFinal: true))
                            return
                        }
                        let item = AnimationCacheItem(numFrames: 1, advanceImpl: { _, _ in
                            return AnimationCacheItem.AdvanceResult(frame: frame, didLoop: false)
                        }, resetImpl: {})
                        completion(AnimationCacheItemResult(item: item, isFinal: true))
                    }
                }) else {
                    completion(AnimationCacheItemResult(item: nil, isFinal: true))
                    return
                }
                let fetchDisposable = fetch(AnimationCacheFetchOptions(size: size, writer: writer, firstFrameOnly: true))
                disposable.set(fetchDisposable)
            } else {
                completion(AnimationCacheItemResult(item: nil, isFinal: true))
            }
        }

        return disposable
    }

    // MARK: - Subcodec-specific API (used by renderer)

    public func getMbsPath(sourceId: String, size: CGSize) -> String {
        let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
        let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
        return "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs"
    }

    public func getMetaPath(sourceId: String, size: CGSize) -> String {
        let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId), width: Int(size.width), height: Int(size.height))
        let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
        return "\(itemDirectoryPath)/\(sourceIdPath.fileName).mbs.meta"
    }

    public func loadMetadata(sourceId: String, size: CGSize) -> MbsMetadata? {
        let metaPath = getMetaPath(sourceId: sourceId, size: size)
        return loadMbsMetadata(metaPath: metaPath)
    }

    public func fetchIfNeeded(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable, completion: @escaping (String?) -> Void) -> Disposable {
        let mbsPath = getMbsPath(sourceId: sourceId, size: size)
        if FileManager.default.fileExists(atPath: mbsPath) {
            completion(mbsPath)
            return EmptyDisposable
        }

        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.get(sourceId: sourceId, size: size, fetch: fetch, updateResult: { [weak self] result in
                guard let strongSelf = self else {
                    completion(nil)
                    return
                }
                if result.isFinal {
                    let path = strongSelf.getMbsPath(sourceId: sourceId, size: size)
                    if FileManager.default.fileExists(atPath: path) {
                        completion(path)
                    } else {
                        completion(nil)
                    }
                }
            }))
        }
        return disposable
    }
}
