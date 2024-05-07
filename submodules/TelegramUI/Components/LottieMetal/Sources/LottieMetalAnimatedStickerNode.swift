import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AnimatedStickerNode
import MetalEngine
import LottieCpp
import GZip

public final class LottieMetalAnimatedStickerNode: ASDisplayNode, AnimatedStickerNode {
    private final class LoadFrameTask {
        var isCancelled: Bool = false
    }
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var automaticallyLoadLastFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    private var lottieInstance: LottieAnimationContainer?
    
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
                return Int(lottieInstance.animation.frameCount)
            } else {
                return 0
            }
        } set(value) {
        }
    }
    public var currentFrameImage: UIImage? {
        return nil
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
    
    private var frameIndex: Int = 0
    private var playbackMode: AnimatedStickerPlaybackMode = .loop
    
    override public init() {
        super.init()
        
        self.backgroundColor = .blue
    }
    
    deinit {
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
        |> deliverOnMainQueue).startStrict(next: { [weak self] path in
            guard let self, let path = path else {
                return
            }
            
            if source.isVideo {
            } else {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                    return
                }
                
                let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
                guard let lottieAnimation = LottieAnimation(data: decompressedData) else {
                    print("Could not load sticker data")
                    return
                }
                let lottieInstance = LottieAnimationContainer(animation: lottieAnimation)
                self.setupPlayback(lottieInstance: lottieInstance)
            }
        }).strict()
    }
    
    private func updatePlayback() {
        let isPlaying = self.visibility && self.lottieInstance != nil
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.isPlayingChanged(self.isPlaying)
        }
    }
    
    private func advanceFrameIfPossible() {
        /*var frameCount: Int?
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
        self.updateLoadFrameTasks()*/
    }
    
    private func setupPlayback(lottieInstance: LottieAnimationContainer) {
        self.lottieInstance = lottieInstance
        
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
