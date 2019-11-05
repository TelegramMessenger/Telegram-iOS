import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Compression
import Display
import AsyncDisplayKit
import RLottieBinding
import GZip
import Tuples
import MediaResources
import StickerResources

private let sharedQueue = Queue()

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
        
        if self.value {
            self.value = false
            self.updated?(false)
        }
    }
}

public enum AnimatedStickerMode {
    case cached
    case direct
}

public enum AnimatedStickerPlaybackMode {
    case once
    case loop
}

private final class AnimatedStickerFrame {
    let data: Data
    let type: AnimationRendererFrameType
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let index: Int
    let isLastFrame: Bool
    
    init(data: Data, type: AnimationRendererFrameType, width: Int, height: Int, bytesPerRow: Int, index: Int, isLastFrame: Bool) {
        self.data = data
        self.type = type
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.index = index
        self.isLastFrame = isLastFrame
    }
}

private protocol AnimatedStickerFrameSource: class {
    var frameRate: Int { get }
    var frameCount: Int { get }
    
    func takeFrame() -> AnimatedStickerFrame
}

@available(iOS 9.0, *)
private final class AnimatedStickerCachedFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private let data: Data
    private var scratchBuffer: Data
    let width: Int
    let bytesPerRow: Int
    let height: Int
    let frameRate: Int
    let frameCount: Int
    private var frameIndex: Int
    private let initialOffset: Int
    private var offset: Int
    var decodeBuffer: Data
    var frameBuffer: Data
    
    init?(queue: Queue, data: Data) {
        self.queue = queue
        self.data = data
        self.scratchBuffer = Data(count: compression_decode_scratch_buffer_size(COMPRESSION_LZFSE))
        
        var offset = 0
        var width = 0
        var height = 0
        var bytesPerRow = 0
        var frameRate = 0
        var frameCount = 0
        
        if !self.data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Bool in
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
        self.frameBuffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            memset(bytes, 0, frameBufferLength)
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func takeFrame() -> AnimatedStickerFrame {
        var frameData: Data?
        var isLastFrame = false
        
        let dataLength = self.data.count
        let decodeBufferLength = self.decodeBuffer.count
        let frameBufferLength = self.frameBuffer.count
        
        let frameIndex = self.frameIndex
        
        self.data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            var frameLength: Int32 = 0
            memcpy(&frameLength, bytes.advanced(by: self.offset), 4)
            self.offset += 4
            
            self.scratchBuffer.withUnsafeMutableBytes { (scratchBytes: UnsafeMutablePointer<UInt8>) -> Void in
                self.decodeBuffer.withUnsafeMutableBytes { (decodeBytes: UnsafeMutablePointer<UInt8>) -> Void in
                    self.frameBuffer.withUnsafeMutableBytes { (frameBytes: UnsafeMutablePointer<UInt8>) -> Void in
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
            
            self.frameIndex += 1
            self.offset += Int(frameLength)
            if self.offset == dataLength {
                isLastFrame = true
                self.frameIndex = 0
                self.offset = self.initialOffset
                self.frameBuffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                    memset(bytes, 0, frameBufferLength)
                }
            }
        }
        
        return AnimatedStickerFrame(data: frameData!, type: .yuva, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: isLastFrame)
    }
}

private final class AnimatedStickerDirectFrameSource: AnimatedStickerFrameSource {
    private let queue: Queue
    private let data: Data
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    let frameCount: Int
    let frameRate: Int
    private var currentFrame: Int
    private let animation: LottieInstance
    
    init?(queue: Queue, data: Data, width: Int, height: Int) {
        self.queue = queue
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = (4 * Int(width) + 15) & (~15)
        self.currentFrame = 0
        guard let rawData = TGGUnzipData(data, 8 * 1024 * 1024) else {
            return nil
        }
        guard let animation = LottieInstance(data: rawData, cacheKey: "") else {
            return nil
        }
        self.animation = animation
        self.frameCount = Int(animation.frameCount)
        self.frameRate = Int(animation.frameRate)
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func takeFrame() -> AnimatedStickerFrame {
        let frameIndex = self.currentFrame % self.frameCount
        self.currentFrame += 1
        var frameData = Data(count: self.bytesPerRow * self.height)
        frameData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            memset(bytes, 0, self.bytesPerRow * self.height)
            self.animation.renderFrame(with: Int32(frameIndex), into: bytes, width: Int32(self.width), height: Int32(self.height), bytesPerRow: Int32(self.bytesPerRow))
        }
        return AnimatedStickerFrame(data: frameData, type: .argb, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: frameIndex == self.frameCount)
    }
}

private final class AnimatedStickerFrameQueue {
    private let queue: Queue
    private let length: Int
    private let source: AnimatedStickerFrameSource
    private var frames: [AnimatedStickerFrame] = []
    
    init(queue: Queue, length: Int, source: AnimatedStickerFrameSource) {
        self.queue = queue
        self.length = length
        self.source = source
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func take() -> AnimatedStickerFrame? {
        if self.frames.isEmpty {
            self.frames.append(self.source.takeFrame())
        }
        let frame = self.frames.removeFirst()
        return frame
    }
    
    func generateFramesIfNeeded() {
        if self.frames.isEmpty {
            self.frames.append(self.source.takeFrame())
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

public enum AnimatedStickerNodeResource {
    case resource(MediaResource)
    case localFile(String)
}

public final class AnimatedStickerNode: ASDisplayNode {
    private let queue: Queue
    private var account: Account?
    private var fileReference: FileMediaReference?
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let eventsNode: AnimatedStickerNodeDisplayEvents
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    public var started: () -> Void = {}
    private var reportedStarted = false
    
    private let timer = Atomic<SwiftSignalKit.Timer?>(value: nil)
    
    private var directData: Tuple4<Data, String, Int, Int>?
    private var cachedData: Data?
    
    private var renderer: (AnimationRenderer & ASDisplayNode)?
    
    private var isPlaying: Bool = false
    private var canDisplayFirstFrame: Bool = false
    private var playbackMode: AnimatedStickerPlaybackMode = .loop
    
    private let playbackStatus = Promise<AnimatedStickerStatus>()
    public var status: Signal<AnimatedStickerStatus, NoError> {
        return self.playbackStatus.get()
    }
    
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
    
    override public func didLoad() {
        super.didLoad()
        
        #if targetEnvironment(simulator)
        self.renderer = SoftwareAnimationRenderer()
        #else
        self.renderer = SoftwareAnimationRenderer()
        //self.renderer = MetalAnimationRenderer()
        #endif
        self.renderer?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.addSubnode(self.renderer!)
    }

    public func setup(account: Account, resource: AnimatedStickerNodeResource, fitzModifier: EmojiFitzModifier? = nil, width: Int, height: Int, playbackMode: AnimatedStickerPlaybackMode = .loop, mode: AnimatedStickerMode) {
        if width < 2 || height < 2 {
            return
        }
        self.playbackMode = playbackMode
        switch mode {
        case .direct:
            let f: (MediaResourceData) -> Void = { [weak self] data in
                guard let strongSelf = self, data.complete else {
                    return
                }
                if let directData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.mappedRead]) {
                    strongSelf.directData = Tuple(directData, data.path, width, height)
                }
                if strongSelf.isPlaying {
                    strongSelf.play()
                } else if strongSelf.canDisplayFirstFrame {
                    strongSelf.play(firstFrame: true)
                }
            }
            switch resource {
            case let .resource(resource):
                self.disposable.set((account.postbox.mediaBox.resourceData(resource)
                |> deliverOnMainQueue).start(next: { data in
                    f(data)
                }))
            case let .localFile(path):
                f(MediaResourceData(path: path, offset: 0, size: Int(Int32.max - 1), complete: true))
            }
        case .cached:
            switch resource {
            case let .resource(resource):
                self.disposable.set((chatMessageAnimationData(postbox: account.postbox, resource: resource, fitzModifier: fitzModifier, width: width, height: height, synchronousLoad: false)
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    if let strongSelf = self, data.complete {
                        strongSelf.cachedData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.mappedRead])
                        if strongSelf.isPlaying {
                            strongSelf.play()
                        } else if strongSelf.canDisplayFirstFrame {
                            strongSelf.play(firstFrame: true)
                        }
                    }
                }))
            case .localFile:
                break
            }
        }
    }
    
    public func reset() {
        self.disposable.set(nil)
        self.fetchDisposable.set(nil)
    }
    
    private func updateIsPlaying() {
        let isPlaying = self.visibility && self.isDisplaying
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            if isPlaying {
                self.play()
            } else{
                self.stop()
            }
        }
        let canDisplayFirstFrame = self.automaticallyLoadFirstFrame && self.isDisplaying
        if self.canDisplayFirstFrame != canDisplayFirstFrame {
            self.canDisplayFirstFrame = canDisplayFirstFrame
            if canDisplayFirstFrame {
                self.play(firstFrame: true)
            }
        }
    }
    
    public func play(firstFrame: Bool = false) {
        let directData = self.directData
        let cachedData = self.cachedData
        let queue = self.queue
        let timerHolder = self.timer
        self.queue.async { [weak self] in
            var maybeFrameSource: AnimatedStickerFrameSource?
            if let directData = directData {
                maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData._0, width: directData._2, height: directData._3)
            } else if let cachedData = cachedData {
                if #available(iOS 9.0, *) {
                    maybeFrameSource = AnimatedStickerCachedFrameSource(queue: queue, data: cachedData)
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
            let frameRate = frameSource.frameRate
            
            let timer = SwiftSignalKit.Timer(timeout: 1.0 / Double(frameRate), repeat: !firstFrame, completion: {
                let maybeFrame = frameQueue.syncWith { frameQueue in
                    return frameQueue.take()
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
                        
                        if case .once = strongSelf.playbackMode, frame.isLastFrame {
                            strongSelf.stop()
                            strongSelf.isPlaying = false
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
    
    public func stop() {
        self.reportedStarted = false
        self.timer.swap(nil)?.invalidate()
        if self.playToCompletionOnStop {
            self.seekToStart()
        }
    }
    
    public func seekToStart() {
        self.isPlaying = false
        
        let directData = self.directData
        let cachedData = self.cachedData
        let queue = self.queue
        let timerHolder = self.timer
        self.queue.async { [weak self] in
            var maybeFrameSource: AnimatedStickerFrameSource?
            if let directData = directData {
                maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData._0, width: directData._2, height: directData._3)
            } else if let cachedData = cachedData {
                if #available(iOS 9.0, *) {
                    maybeFrameSource = AnimatedStickerCachedFrameSource(queue: queue, data: cachedData)
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
            
            let maybeFrame = frameQueue.syncWith { frameQueue in
                return frameQueue.take()
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
}
