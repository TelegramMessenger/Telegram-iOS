import Foundation
import UIKit
import AsyncDisplayKit
import RLottieBinding
import SwiftSignalKit
import GZip
import Display

public final class DirectAnimatedStickerNode: ASDisplayNode, AnimatedStickerNode {
    private static let sharedQueue = Queue(name: "DirectAnimatedStickerNode", qos: .userInteractive)
    
    private final class LoadFrameTask {
        var isCancelled: Bool = false
    }
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var automaticallyLoadLastFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    private var didStart: Bool = false
    public var started: () -> Void = {}
    
    public var completed: (Bool) -> Void = { _ in }
    private var didComplete: Bool = false
    
    public var frameUpdated: (Int, Int) -> Void = { _, _ in }
    public var currentFrameIndex: Int {
        get {
            return self.frameIndex
        } set(value) {
        }
    }
    public var currentFrameCount: Int {
        get {
            if let lottieInstance = self.lottieInstance {
                return Int(lottieInstance.frameCount)
            } else if let videoSource = self.videoSource {
                return Int(videoSource.frameRate)
            } else {
                return 0
            }
        } set(value) {
        }
    }
    public var currentFrameImage: UIImage? {
        if let contents = self.layer.contents {
            return UIImage(cgImage: contents as! CGImage)
        } else {
            return nil
        }
    }
    
    public private(set) var isPlaying: Bool = false
    public var stopAtNearestLoop: Bool = false
    
    private let statusPromise = Promise<AnimatedStickerStatus>()
    public var status: Signal<AnimatedStickerStatus, NoError> {
        return self.statusPromise.get()
    }
    
    public var autoplay: Bool = true
    
    public var visibility: Bool = false {
        didSet {
            self.updatePlayback()
        }
    }
    
    public var overrideVisibility: Bool = false
    
    public var isPlayingChanged: (Bool) -> Void = { _ in }
    
    private var sourceDisposable: Disposable?
    private var playbackSize: CGSize?
    
    private var lottieInstance: LottieInstance?
    private var videoSource: AnimatedStickerFrameSource?
    private var frameIndex: Int = 0
    private var playbackMode: AnimatedStickerPlaybackMode = .loop
    
    private var frameImages: [Int: UIImage] = [:]
    private var loadFrameTasks: [Int: LoadFrameTask] = [:]
    private var nextFrameTimer: SwiftSignalKit.Timer?
    
    override public init() {
        super.init()
    }
    
    deinit {
        self.sourceDisposable?.dispose()
        self.nextFrameTimer?.invalidate()
    }
    
    public func cloneCurrentFrame(from otherNode: AnimatedStickerNode?) {
    }
    
    public func setup(source: AnimatedStickerNodeSource, width: Int, height: Int, playbackMode: AnimatedStickerPlaybackMode, mode: AnimatedStickerMode) {
        self.didStart = false
        self.didComplete = false
        
        self.sourceDisposable?.dispose()
        
        self.playbackSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        self.playbackMode = playbackMode
        
        self.sourceDisposable = (source.directDataPath(attemptSynchronously: false)
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] path in
            guard let strongSelf = self, let path = path else {
                return
            }
            
            if source.isVideo {
                if let videoSource = makeVideoStickerDirectFrameSource(queue: DirectAnimatedStickerNode.sharedQueue, path: path, width: width, height: height, cachePathPrefix: nil, unpremultiplyAlpha: false) {
                    strongSelf.setupPlayback(videoSource: videoSource)
                }
            } else {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                    return
                }
                
                let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
                
                guard let lottieInstance = LottieInstance(data: decompressedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
                    print("Could not load sticker data")
                    return
                }
                
                strongSelf.setupPlayback(lottieInstance: lottieInstance)
            }
        })
    }
    
    private func updatePlayback() {
        let isPlaying = self.visibility && (self.lottieInstance != nil || self.videoSource != nil)
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
            if self.isPlaying {
                self.startNextFrameTimerIfNeeded()
                self.updateLoadFrameTasks()
            } else {
                self.nextFrameTimer?.invalidate()
                self.nextFrameTimer = nil
            }
            
            self.isPlayingChanged(self.isPlaying)
        }
    }
    
    private func startNextFrameTimerIfNeeded() {
        var frameRate: Double?
        if let lottieInstance = self.lottieInstance {
            frameRate = Double(lottieInstance.frameRate)
        } else if let videoSource = self.videoSource {
            frameRate = Double(videoSource.frameRate)
        }
        
        if self.nextFrameTimer == nil, let frameRate = frameRate, self.frameImages[self.frameIndex] != nil {
            let nextFrameTimer = SwiftSignalKit.Timer(timeout: 1.0 / frameRate, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.nextFrameTimer = nil
                strongSelf.advanceFrameIfPossible()
            }, queue: .mainQueue())
            self.nextFrameTimer = nextFrameTimer
            nextFrameTimer.start()
        }
    }
    
    private func advanceFrameIfPossible() {
        var frameCount: Int?
        if let lottieInstance = self.lottieInstance {
            frameCount = Int(lottieInstance.frameCount)
        } else if let videoSource = self.videoSource {
            frameCount = Int(videoSource.frameCount)
        }
        guard let frameCount = frameCount else {
            return
        }
        
        if self.frameIndex == frameCount - 1 {
            switch self.playbackMode {
            case .loop:
                self.completed(false)
            case let .count(count):
                if count <= 1 {
                    if !self.didComplete {
                        self.didComplete = true
                        self.completed(true)
                    }
                    return
                } else {
                    self.playbackMode = .count(count - 1)
                    self.completed(false)
                }
            case .once:
                if !self.didComplete {
                    self.didComplete = true
                    self.completed(true)
                }
                return
            case .still:
                break
            }
        }
        
        let nextFrameIndex = (self.frameIndex + 1) % frameCount
        self.frameIndex = nextFrameIndex
        
        self.updateFrameImageIfNeeded()
        self.updateLoadFrameTasks()
    }
    
    private func updateFrameImageIfNeeded() {
        var frameCount: Int?
        if let lottieInstance = self.lottieInstance {
            frameCount = Int(lottieInstance.frameCount)
        } else if let videoSource = self.videoSource {
            frameCount = Int(videoSource.frameCount)
        }
        guard let frameCount = frameCount else {
            return
        }
        
        var allowedIndices: [Int] = []
        for i in 0 ..< 2 {
            let mappedIndex = (self.frameIndex + i) % frameCount
            allowedIndices.append(mappedIndex)
        }
        
        var removeKeys: [Int] = []
        for index in self.frameImages.keys {
            if !allowedIndices.contains(index) {
                removeKeys.append(index)
            }
        }
        for index in removeKeys {
            self.frameImages.removeValue(forKey: index)
        }
        
        for (index, task) in self.loadFrameTasks {
            if !allowedIndices.contains(index) {
                task.isCancelled = true
            }
        }
        
        if let image = self.frameImages[self.frameIndex] {
            self.layer.contents = image.cgImage
            
            self.frameUpdated(self.frameIndex, frameCount)
            
            if !self.didComplete {
                self.startNextFrameTimerIfNeeded()
            }
            
            if !self.didStart {
                self.didStart = true
                self.started()
            }
        }
    }
    
    private func updateLoadFrameTasks() {
        var frameCount: Int?
        if let lottieInstance = self.lottieInstance {
            frameCount = Int(lottieInstance.frameCount)
        } else if let videoSource = self.videoSource {
            frameCount = Int(videoSource.frameCount)
        }
        guard let frameCount = frameCount else {
            return
        }
                
        let frameIndex = self.frameIndex % frameCount
        if self.frameImages[frameIndex] == nil {
            self.maybeStartLoadFrameTask(frameIndex: frameIndex)
        } else {
            self.maybeStartLoadFrameTask(frameIndex: (frameIndex + 1) % frameCount)
        }
    }
    
    private func maybeStartLoadFrameTask(frameIndex: Int) {
        guard self.lottieInstance != nil || self.videoSource != nil else {
            return
        }
        guard let playbackSize = self.playbackSize else {
            return
        }
        if self.loadFrameTasks[frameIndex] != nil {
            return
        }
        
        let task = LoadFrameTask()
        self.loadFrameTasks[frameIndex] = task
        
        let lottieInstance = self.lottieInstance
        let videoSource = self.videoSource
        
        DirectAnimatedStickerNode.sharedQueue.async { [weak self] in
            var image: UIImage?
            
            if !task.isCancelled {
                if let lottieInstance = lottieInstance {
                    let drawingContext = DrawingContext(size: playbackSize, scale: 1.0, opaque: false, clear: false)
                    lottieInstance.renderFrame(with: Int32(frameIndex), into: drawingContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(drawingContext.scaledSize.width), height: Int32(drawingContext.scaledSize.height), bytesPerRow: Int32(drawingContext.bytesPerRow))
                    
                    image = drawingContext.generateImage()
                } else if let videoSource = videoSource {
                    if let frame = videoSource.takeFrame(draw: true) {
                        let drawingContext = DrawingContext(size: CGSize(width: frame.width, height: frame.height), scale: 1.0, opaque: false, clear: false, bytesPerRow: frame.bytesPerRow)
                        
                        frame.data.copyBytes(to: drawingContext.bytes.assumingMemoryBound(to: UInt8.self), from: 0 ..< min(frame.data.count, drawingContext.length))
                        
                        image = drawingContext.generateImage()
                    }
                }
            }
            
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                
                if let currentTask = strongSelf.loadFrameTasks[frameIndex], currentTask === task {
                    strongSelf.loadFrameTasks.removeValue(forKey: frameIndex)
                }
                
                if !task.isCancelled, let image = image {
                    strongSelf.frameImages[frameIndex] = image
                    strongSelf.updateFrameImageIfNeeded()
                    strongSelf.updateLoadFrameTasks()
                }
            }
        }
    }
    
    private func setupPlayback(lottieInstance: LottieInstance) {
        self.lottieInstance = lottieInstance
        
        self.updatePlayback()
    }
    
    private func setupPlayback(videoSource: AnimatedStickerFrameSource) {
        self.videoSource = videoSource
        
        self.updatePlayback()
    }
    
    public func reset() {
    }
    
    public func playOnce() {
    }
    
    public func playLoop() {
    }
    
    public func play(firstFrame: Bool, fromIndex: Int?) {
        if let fromIndex = fromIndex {
            self.frameIndex = fromIndex
            self.updateLoadFrameTasks()
        }
    }
    
    public func pause() {
    }
    
    public func stop() {
    }
    
    public func seekTo(_ position: AnimatedStickerPlaybackPosition) {
    }
    
    public func playIfNeeded() -> Bool {
        return false
    }
    
    public func updateLayout(size: CGSize) {
    }
    
    public func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
    }
}
