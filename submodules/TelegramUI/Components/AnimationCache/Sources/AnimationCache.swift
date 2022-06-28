import Foundation
import UIKit
import SwiftSignalKit
import CryptoUtils
import ManagedFile

public final class AnimationCacheItemFrame {
    public enum Format {
        case rgba(width: Int, height: Int, bytesPerRow: Int)
    }
    
    public let data: Data
    public let range: Range<Int>
    public let format: Format
    public let duration: Double
    
    public init(data: Data, range: Range<Int>, format: Format, duration: Double) {
        self.data = data
        self.range = range
        self.format = format
        self.duration = duration
    }
}

public final class AnimationCacheItem {
    public let numFrames: Int
    private let getFrameImpl: (Int) -> AnimationCacheItemFrame?
    
    public init(numFrames: Int, getFrame: @escaping (Int) -> AnimationCacheItemFrame?) {
        self.numFrames = numFrames
        self.getFrameImpl = getFrame
    }
    
    public func getFrame(index: Int) -> AnimationCacheItemFrame? {
        return self.getFrameImpl(index)
    }
}

public protocol AnimationCacheItemWriter: AnyObject {
    func add(bytes: UnsafeRawPointer, length: Int, width: Int, height: Int, bytesPerRow: Int, duration: Double)
    func finish()
}

public protocol AnimationCache: AnyObject {
    func get(sourceId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable) -> Signal<AnimationCacheItem?, NoError>
    func getSynchronously(sourceId: String) -> AnimationCacheItem?
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

private func itemSubpath(hashString: String) -> (directory: String, fileName: String) {
    assert(hashString.count == 32)
    var directory = ""
    
    for i in 0 ..< 1 {
        if !directory.isEmpty {
            directory.append("/")
        }
        directory.append(String(hashString[hashString.index(hashString.startIndex, offsetBy: i * 2) ..< hashString.index(hashString.startIndex, offsetBy: (i + 1) * 2)]))
    }
    
    return (directory, hashString)
}

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    private struct ParameterSet: Equatable {
        var width: Int
        var height: Int
        var bytesPerRow: Int
    }
    
    private struct FrameMetadata {
        var offset: Int
        var length: Int
        var duration: Double
    }
    
    private let file: ManagedFile
    private let completion: (Bool) -> Void
    
    private var currentParameterSet: ParameterSet?
    private var contentLengthOffset: Int?
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    
    private var frames: [FrameMetadata] = []
    private var contentLength: Int = 0
    
    private let lock = Lock()
    
    init?(tempPath: String, completion: @escaping (Bool) -> Void) {
        guard let file = ManagedFile(queue: nil, path: tempPath, mode: .readwrite) else {
            return nil
        }
        self.file = file
        self.completion = completion
    }
    
    func add(bytes: UnsafeRawPointer, length: Int, width: Int, height: Int, bytesPerRow: Int, duration: Double) {
        self.lock.locked {
            if self.isFailed {
                return
            }
            
            let parameterSet = ParameterSet(width: width, height: height, bytesPerRow: bytesPerRow)
            if let currentParameterSet = self.currentParameterSet {
                if currentParameterSet != parameterSet {
                    self.isFailed = true
                    return
                }
            } else {
                self.currentParameterSet = parameterSet
                
                self.file.write(1 as UInt32)
                
                self.file.write(UInt32(parameterSet.width))
                self.file.write(UInt32(parameterSet.height))
                self.file.write(UInt32(parameterSet.bytesPerRow))
                
                self.contentLengthOffset = Int(self.file.position())
                self.file.write(0 as UInt32)
            }
            
            self.frames.append(FrameMetadata(offset: Int(self.file.position()), length: length, duration: duration))
            let _ = self.file.write(bytes, count: length)
            self.contentLength += length
        }
    }
    
    func finish() {
        var shouldComplete = false
        self.lock.locked {
            if !self.isFinished {
                self.isFinished = true
                shouldComplete = true
                
                guard let contentLengthOffset = self.contentLengthOffset else {
                    self.isFailed = true
                    return
                }
                
                let metadataPosition = self.file.position()
                self.file.seek(position: Int64(contentLengthOffset))
                self.file.write(UInt32(self.contentLength))
                
                self.file.seek(position: metadataPosition)
                self.file.write(UInt32(self.frames.count))
                for frame in self.frames {
                    self.file.write(UInt32(frame.offset))
                    self.file.write(UInt32(frame.length))
                    self.file.write(Float32(frame.duration))
                }
            }
        }
        
        if shouldComplete {
            self.completion(!self.isFailed)
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
    private let format: AnimationCacheItemFrame.Format
    
    init(data: Data, frameMapping: [Int: FrameInfo], format: AnimationCacheItemFrame.Format) {
        self.data = data
        self.frameMapping = frameMapping
        self.format = format
    }
    
    func getFrame(index: Int) -> AnimationCacheItemFrame? {
        guard let frameInfo = self.frameMapping[index] else {
            return nil
        }
        
        return AnimationCacheItemFrame(data: data, range: frameInfo.range, format: self.format, duration: frameInfo.duration)
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

private func loadItem(path: String) -> AnimationCacheItem? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
        return nil
    }
    let dataLength = data.count
    
    var offset = 0
    
    guard dataLength >= offset + 4 else {
        return nil
    }
    let formatVersion = readUInt32(data: data, offset: offset)
    offset += 4
    if formatVersion != 1 {
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
    let bytesPerRow = readUInt32(data: data, offset: offset)
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
    
    var frameMapping: [Int: AnimationCacheItemAccessor.FrameInfo] = [:]
    for i in 0 ..< Int(numFrames) {
        guard dataLength >= offset + 4 + 4 + 4 else {
            return nil
        }
        
        let frameStart = readUInt32(data: data, offset: offset)
        offset += 4
        let frameLength = readUInt32(data: data, offset: offset)
        offset += 4
        let frameDuration = readUInt32(data: data, offset: offset)
        offset += 4
        
        frameMapping[i] = AnimationCacheItemAccessor.FrameInfo(range: Int(frameStart) ..< Int(frameStart + frameLength), duration: Double(frameDuration))
    }
    
    let itemAccessor = AnimationCacheItemAccessor(data: data, frameMapping: frameMapping, format: .rgba(width: Int(width), height: Int(height), bytesPerRow: Int(bytesPerRow)))
    
    return AnimationCacheItem(numFrames: Int(numFrames), getFrame: { index in
        return itemAccessor.getFrame(index: index)
    })
}

public final class AnimationCacheImpl: AnimationCache {
    private final class Impl {
        private final class ItemContext {
            let subscribers = Bag<(AnimationCacheItem?) -> Void>()
            let disposable = MetaDisposable()
            
            deinit {
                self.disposable.dispose()
            }
        }
        
        private let queue: Queue
        private let basePath: String
        private let allocateTempFile: () -> String
        
        private var itemContexts: [String: ItemContext] = [:]
        
        init(queue: Queue, basePath: String, allocateTempFile: @escaping () -> String) {
            self.queue = queue
            self.basePath = basePath
            self.allocateTempFile = allocateTempFile
        }
        
        deinit {
        }
        
        func get(sourceId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable, completion: @escaping (AnimationCacheItem?) -> Void) -> Disposable {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId))
            let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
            let itemPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)"
            
            if FileManager.default.fileExists(atPath: itemPath) {
                completion(loadItem(path: itemPath))
                
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
            let index = itemContext.subscribers.add(completion)
            
            if beginFetch {
                let tempPath = self.allocateTempFile()
                guard let writer = AnimationCacheItemWriterImpl(tempPath: tempPath, completion: { [weak self, weak itemContext] success in
                    queue.async {
                        guard let strongSelf = self, let itemContext = itemContext, itemContext === strongSelf.itemContexts[sourceId] else {
                            return
                        }
                        
                        strongSelf.itemContexts.removeValue(forKey: sourceId)
                        
                        guard success else {
                            return
                        }
                        guard let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: itemDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
                            return
                        }
                        guard let _ = try? FileManager.default.moveItem(atPath: tempPath, toPath: itemPath) else {
                            return
                        }
                        guard let item = loadItem(path: itemPath) else {
                            return
                        }
                        
                        for f in itemContext.subscribers.copyItems() {
                            f(item)
                        }
                    }
                }) else {
                    return EmptyDisposable
                }
                
                let fetchDisposable = fetch(writer)
                
                itemContext.disposable.set(ActionDisposable {
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
        
        func getSynchronously(sourceId: String) -> AnimationCacheItem? {
            let sourceIdPath = itemSubpath(hashString: md5Hash(sourceId))
            let itemDirectoryPath = "\(self.basePath)/\(sourceIdPath.directory)"
            let itemPath = "\(itemDirectoryPath)/\(sourceIdPath.fileName)"
            
            if FileManager.default.fileExists(atPath: itemPath) {
                return loadItem(path: itemPath)
            } else {
                return nil
            }
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(basePath: String, allocateTempFile: @escaping () -> String) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, basePath: basePath, allocateTempFile: allocateTempFile)
        })
    }
    
    public func get(sourceId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable) -> Signal<AnimationCacheItem?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.get(sourceId: sourceId, fetch: fetch, completion: { result in
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                }))
            }
            
            return disposable
        }
        |> runOn(self.queue)
    }
    
    public func getSynchronously(sourceId: String) -> AnimationCacheItem? {
        return self.impl.syncWith { impl -> AnimationCacheItem? in
            return impl.getSynchronously(sourceId: sourceId)
        }
    }
}
