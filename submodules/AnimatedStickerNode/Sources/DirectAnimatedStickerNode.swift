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
            guard let lottieInstance = self.lottieInstance else {
                return 0
            }
            return Int(lottieInstance.frameCount)
        } set(value) {
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
    
    public var isPlayingChanged: (Bool) -> Void = { _ in }
    
    private var sourceDisposable: Disposable?
    private var playbackSize: CGSize?
    
    private var lottieInstance: LottieInstance?
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
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return
            }
            
            let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
            
            guard let lottieInstance = LottieInstance(data: decompressedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
                print("Could not load sticker data")
                return
            }
            
            strongSelf.setupPlayback(lottieInstance: lottieInstance)
        })
    }
    
    private func updatePlayback() {
        let isPlaying = self.visibility && self.lottieInstance != nil
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
        if self.nextFrameTimer == nil, let lottieInstance = self.lottieInstance, self.frameImages[self.frameIndex] != nil {
            let nextFrameTimer = SwiftSignalKit.Timer(timeout: 1.0 / Double(lottieInstance.frameRate), repeat: false, completion: { [weak self] in
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
        guard let lottieInstance = self.lottieInstance else {
            return
        }
        
        if self.frameIndex == Int(lottieInstance.frameCount) - 1 {
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
        
        let nextFrameIndex = (self.frameIndex + 1) % Int(lottieInstance.frameCount)
        self.frameIndex = nextFrameIndex
        
        self.updateFrameImageIfNeeded()
        self.updateLoadFrameTasks()
    }
    
    private func updateFrameImageIfNeeded() {
        guard let lottieInstance = self.lottieInstance else {
            return
        }
        
        var allowedIndices: [Int] = []
        for i in 0 ..< 2 {
            let mappedIndex = (self.frameIndex + i) % Int(lottieInstance.frameCount)
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
            
            self.frameUpdated(self.frameIndex, Int(lottieInstance.frameCount))
            
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
        guard let lottieInstance = self.lottieInstance else {
            return
        }
                
        let frameIndex = self.frameIndex % Int(lottieInstance.frameCount)
        if self.frameImages[frameIndex] == nil {
            self.maybeStartLoadFrameTask(frameIndex: frameIndex)
        } else {
            self.maybeStartLoadFrameTask(frameIndex: (frameIndex + 1) % Int(lottieInstance.frameCount))
        }
    }
    
    private func maybeStartLoadFrameTask(frameIndex: Int) {
        guard let lottieInstance = self.lottieInstance, let playbackSize = self.playbackSize else {
            return
        }
        if self.loadFrameTasks[frameIndex] != nil {
            return
        }
        
        let task = LoadFrameTask()
        self.loadFrameTasks[frameIndex] = task
        
        DirectAnimatedStickerNode.sharedQueue.async { [weak self] in
            var image: UIImage?
            
            if !task.isCancelled {
                let drawingContext = DrawingContext(size: playbackSize, scale: 1.0, opaque: false, clear: false)
                lottieInstance.renderFrame(with: Int32(frameIndex), into: drawingContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(drawingContext.scaledSize.width), height: Int32(drawingContext.scaledSize.height), bytesPerRow: Int32(drawingContext.bytesPerRow))
                
                image = drawingContext.generateImage()
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
    
    public func reset() {
    }
    
    public func playOnce() {
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
