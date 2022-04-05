import Foundation
import SwiftSignalKit
import Compression
import Display
import AsyncDisplayKit
import YuvConversion
import MediaResources
import AnimationCompression

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
    let multiplyAlpha: Bool
    
    init(data: Data, type: AnimationRendererFrameType, width: Int, height: Int, bytesPerRow: Int, index: Int, isLastFrame: Bool, totalFrames: Int, multiplyAlpha: Bool = false) {
        self.data = data
        self.type = type
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.index = index
        self.isLastFrame = isLastFrame
        self.totalFrames = totalFrames
        self.multiplyAlpha = multiplyAlpha
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
    var isVideo: Bool { get }
    
    func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError>
    func directDataPath() -> Signal<String, NoError>
}

public final class AnimatedStickerNode: ASDisplayNode {
    private let queue: Queue
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let eventsNode: AnimatedStickerNodeDisplayEvents
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var automaticallyLoadLastFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    public var started: () -> Void = {}
    private var reportedStarted = false
    
    public var completed: (Bool) -> Void = { _ in }
    public var frameUpdated: (Int, Int) -> Void = { _, _ in }
    public private(set) var currentFrameIndex: Int = 0
    private var playFromIndex: Int?
    
    private let timer = Atomic<SwiftSignalKit.Timer?>(value: nil)
    private let frameSource = Atomic<QueueLocalObject<AnimatedStickerFrameSourceWrapper>?>(value: nil)
    
    private var directData: (Data, String, Int, Int, String?, EmojiFitzModifier?, Bool)?
    private var cachedData: (Data, Bool, EmojiFitzModifier?)?
    
    private let useMetalCache: Bool
    private var renderer: AnimationRendererPool.Holder?
    
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
    
    private var overlayColor: (UIColor?, Bool)? = nil
    private var size: CGSize?
    
    public init(useMetalCache: Bool = false) {
        self.queue = sharedQueue
        self.eventsNode = AnimatedStickerNodeDisplayEvents()
        
        self.useMetalCache = useMetalCache
        
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
    
    private static let hardwareRendererPool = AnimationRendererPool(generate: {
        if #available(iOS 10.0, *) {
            return CompressedAnimationRenderer()
        } else {
            return SoftwareAnimationRenderer()
        }
    })
    
    private static let softwareRendererPool = AnimationRendererPool(generate: {
        return SoftwareAnimationRenderer()
    })
    
    private weak var nodeToCopyFrameFrom: AnimatedStickerNode?
    override public func didLoad() {
        super.didLoad()
        
        if #available(iOS 10.0, *), (self.useMetalCache/* || "".isEmpty*/) {
            self.renderer = AnimatedStickerNode.hardwareRendererPool.take()
        } else {
            self.renderer = AnimatedStickerNode.softwareRendererPool.take()
            if let contents = self.nodeToCopyFrameFrom?.renderer?.renderer.contents {
                self.renderer?.renderer.contents = contents
            }
        }
        
        self.renderer?.renderer.frame = CGRect(origin: CGPoint(), size: self.size ?? self.bounds.size)
        if let (overlayColor, replace) = self.overlayColor {
            self.renderer?.renderer.setOverlayColor(overlayColor, replace: replace, animated: false)
        }
        self.nodeToCopyFrameFrom = nil
        self.addSubnode(self.renderer!.renderer)
    }
    
    public func cloneCurrentFrame(from otherNode: AnimatedStickerNode?) {
        if let renderer = self.renderer?.renderer as? SoftwareAnimationRenderer, let otherRenderer = otherNode?.renderer?.renderer as? SoftwareAnimationRenderer {
            if let contents = otherRenderer.contents {
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
                    strongSelf.directData = (directData, path, width, height, cachePathPrefix, source.fitzModifier, source.isVideo)
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
        if !self.autoplay {
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
        }
        if self.automaticallyLoadLastFrame {
            if self.isDisplaying {
                self.seekTo(.end)
            }
        } else {
            let canDisplayFirstFrame = self.automaticallyLoadFirstFrame && self.isDisplaying
            if self.canDisplayFirstFrame != canDisplayFirstFrame {
                self.canDisplayFirstFrame = canDisplayFirstFrame
                if canDisplayFirstFrame {
                    self.play(firstFrame: true)
                }
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
            let useMetalCache = self.useMetalCache
            self.queue.async { [weak self] in
                var maybeFrameSource: AnimatedStickerFrameSource? = frameSourceHolder.with { $0 }?.syncWith { $0 }.value
                if maybeFrameSource == nil {
                    let notifyUpdated: (() -> Void)? = nil
                    if let directData = directData {
                        if directData.6 {
                            maybeFrameSource = VideoStickerDirectFrameSource(queue: queue, path: directData.1, width: directData.2, height: directData.3, cachePathPrefix: directData.4)
                        } else {
                            maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, useMetalCache: useMetalCache, fitzModifier: directData.5)
                        }
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
                            
                            strongSelf.renderer?.renderer.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, mulAlpha: frame.multiplyAlpha, completion: {
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
            let useMetalCache = self.useMetalCache
            self.queue.async { [weak self] in
                var maybeFrameSource: AnimatedStickerFrameSource?
                let notifyUpdated: (() -> Void)? = nil
                if let directData = directData {
                    if directData.6 {
                        maybeFrameSource = VideoStickerDirectFrameSource(queue: queue, path: directData.1, width: directData.2, height: directData.3, cachePathPrefix: directData.4)
                    } else {
                        maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, useMetalCache: useMetalCache, fitzModifier: directData.5)
                    }
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
                            
                            strongSelf.renderer?.renderer.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, mulAlpha: frame.multiplyAlpha, completion: {
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
        let useMetalCache = self.useMetalCache
        self.queue.async { [weak self] in
            var maybeFrameSource: AnimatedStickerFrameSource? = frameSourceHolder.with { $0 }?.syncWith { $0 }.value
            if case .timestamp = position {
            } else {
                if let directData = directData {
                    if directData.6 {
                        maybeFrameSource = VideoStickerDirectFrameSource(queue: queue, path: directData.1, width: directData.2, height: directData.3, cachePathPrefix: directData.4)
                    } else {
                        maybeFrameSource = AnimatedStickerDirectFrameSource(queue: queue, data: directData.0, width: directData.2, height: directData.3, cachePathPrefix: directData.4, useMetalCache: useMetalCache, fitzModifier: directData.5)
                    }
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
            if frameSource.frameCount == 0 {
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
                    
                    strongSelf.renderer?.renderer.render(queue: strongSelf.queue, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, mulAlpha: frame.multiplyAlpha, completion: {
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
        self.size = size
        self.renderer?.renderer.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    public func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
        self.overlayColor = (color, replace)
        self.renderer?.renderer.setOverlayColor(color, replace: replace, animated: animated)
    }
}
