import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import LottieBinding
import LottieSettings
import AppBundle
import GZip
import SwiftSignalKit

public final class ManagedAnimationState {
    public let item: ManagedAnimationItem
    private let instance: LottieInstance

    private let displaySize: CGSize
    
    let frameCount: Int
    let fps: Double
    
    var relativeTime: Double = 0.0
    public var frameIndex: Int?
    public var position: CGFloat {
        if let frameIndex = frameIndex {
            return CGFloat(frameIndex) / CGFloat(frameCount)
        } else {
            return 0.0
        }
    }
    
    public var executedCallbacks = Set<Int>()
    
    public init?(displaySize: CGSize, item: ManagedAnimationItem, current: ManagedAnimationState?, lottieSettings: LottieRenderingSettings) {
        let resolvedInstance: LottieInstance
        
        if let current = current {
            resolvedInstance = current.instance
        } else {
            guard let path = item.source.path else {
                return nil
            }
            guard var data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return nil
            }
            if path.hasSuffix(".json") {
                
            } else if let unpackedData = TGGUnzipData(data, 5 * 1024 * 1024) {
                data = unpackedData
            }
            guard let instance = makeLottieInstance(data: data, fitzModifier: .none, colorReplacements: item.replaceColors, cacheKey: "", settings: lottieSettings) else {
                return nil
            }
            resolvedInstance = instance
        }

        self.displaySize = displaySize
        self.item = item
        self.instance = resolvedInstance
        
        self.frameCount = Int(self.instance.frameCount)
        self.fps = Double(self.instance.frameRate)
    }
    
    func draw() -> UIImage? {
        guard let renderContext = DrawingContext(size: self.displaySize, scale: UIScreenScale, clear: true) else {
            return nil
        }

        self.instance.renderFrame(with: Int32(self.frameIndex ?? 0), into: renderContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(renderContext.size.width * renderContext.scale), height: Int32(renderContext.size.height * renderContext.scale), bytesPerRow: Int32(renderContext.bytesPerRow))
        return renderContext.generateImage()
    }
}

public enum ManagedAnimationFramePosition {
    case start
    case end
}

public enum ManagedAnimationFrameRange: Equatable {
    case range(startFrame: Int, endFrame: Int)
    case still(ManagedAnimationFramePosition)
}

public enum ManagedAnimationSource: Equatable {
    case local(String)
    case resource(Account, EngineMediaResource)
    
    var cacheKey: String {
        switch self {
            case let .local(name):
                return name
            case let .resource(_, resource):
                return resource.id.stringRepresentation
        }
    }
    
    var path: String? {
        switch self {
            case let .local(name):
                if let tgsPath = getAppBundle().path(forResource: name, ofType: "tgs") {
                    return tgsPath
                }
                return getAppBundle().path(forResource: name, ofType: "json")
            case let .resource(account, resource):
                return account.postbox.mediaBox.completedResourcePath(resource._asResource())
        }
    }
    
    public static func ==(lhs: ManagedAnimationSource, rhs: ManagedAnimationSource) -> Bool {
        switch lhs {
            case let .local(lhsPath):
                if case let .local(rhsPath) = rhs, lhsPath == rhsPath {
                    return true
                } else {
                    return false
                }
            case let .resource(lhsAccount, lhsResource):
                if case let .resource(rhsAccount, rhsResource) = rhs, lhsAccount === rhsAccount, lhsResource == rhsResource {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct ManagedAnimationItem {
    public let source: ManagedAnimationSource
    public let replaceColors: [UInt32: UInt32]?
    public var frames: ManagedAnimationFrameRange?
    public var duration: Double?
    public var loop: Bool
    var callbacks: [(Int, () -> Void)]
    
    public init(source: ManagedAnimationSource, replaceColors: [UInt32: UInt32]? = nil, frames: ManagedAnimationFrameRange? = nil, duration: Double? = nil, loop: Bool = false, callbacks: [(Int, () -> Void)] = []) {
        self.source = source
        self.replaceColors = replaceColors
        self.frames = frames
        self.duration = duration
        self.loop = loop
        self.callbacks = callbacks
    }
}

open class ManagedAnimationNode: ASDisplayNode {
    public let intrinsicSize: CGSize
    
    public let imageNode: ASImageNode
    private let displayLink: SharedDisplayLinkDriver.Link
    
    public var imageUpdated: ((UIImage) -> Void)?
    public var image: UIImage? {
        return self.imageNode.image
    }
    
    public var state: ManagedAnimationState?
    public var trackStack: [ManagedAnimationItem] = []
    public var didTryAdvancingState = false
    
    private var previousTimestamp: Double?
    private var delta: Double?
    
    public var customColor: UIColor? {
        didSet {
            if let customColor = self.customColor, oldValue?.rgb != customColor.rgb {
                self.imageNode.image = generateTintedImage(image: self.imageNode.image, color: customColor)
            }
        }
    }
    
    public var scale: CGFloat = 1.0 {
        didSet {
            self.imageNode.transform = CATransform3DMakeScale(self.scale, self.scale, 1.0)
        }
    }
    
    public let lottieSettings: LottieRenderingSettings

    public init(size: CGSize, lottieSettings: LottieRenderingSettings) {
        self.lottieSettings = lottieSettings
        self.intrinsicSize = size
        
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)
        
        var displayLinkUpdate: (() -> Void)?
        self.displayLink = SharedDisplayLinkDriver.shared.add { _ in
            displayLinkUpdate?()
        }
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        displayLinkUpdate = { [weak self] in
            if let strongSelf = self {
                let currentTimestamp = CACurrentMediaTime()
                let delta: Double
                if let previousTimestamp = strongSelf.previousTimestamp {
                    delta = currentTimestamp - previousTimestamp
                } else {
                    delta = 1.0 / 60.0
                }
                strongSelf.delta = delta
                strongSelf.updateAnimation()
                strongSelf.previousTimestamp = currentTimestamp
            }
        }
    }
    
    open func advanceState() {
        guard !self.trackStack.isEmpty else {
            self.displayLink.isPaused = true
            return
        }
        
        let item = self.trackStack.removeFirst()
        
        if let state = self.state, state.item.source == item.source {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state, lottieSettings: self.lottieSettings)
        } else {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil, lottieSettings: self.lottieSettings)
        }
        
        self.didTryAdvancingState = false
        self.previousTimestamp = CACurrentMediaTime()
        self.displayLink.isPaused = false
    }
    
    public func updateAnimation() {
        if self.state == nil {
            self.advanceState()
        }
        
        guard let state = self.state else {
            self.displayLink.isPaused = true
            return
        }
        
        let startFrame: Int
        let endFrame: Int
        let duration: Double
        if let frames = state.item.frames {
            switch frames {
                case let .range(start, end):
                    startFrame = start
                    endFrame = end
                case let .still(position):
                    switch position {
                        case .start:
                            startFrame = 0
                            endFrame = 0
                        case .end:
                            startFrame = state.frameCount
                            endFrame = state.frameCount
                    }
            }
        } else {
            startFrame = 0
            endFrame = state.frameCount
        }
        
        if let durationValue = state.item.duration {
            duration = durationValue
        } else {
            let fps: Double = state.fps > 0 ? state.fps : 60
            duration = Double(state.frameCount) / fps
        }
        
        var t = state.relativeTime / duration
        t = max(0.0, t)
        t = min(1.0, t)
        //print("\(t) \(state.item.name)")
        let frameOffset = Int(Double(startFrame) * (1.0 - t) + Double(endFrame) * t)
        let lowerBound: Int = 0
        let upperBound = state.frameCount - 1
        let frameIndex = max(lowerBound, min(upperBound, frameOffset))
        
        if state.frameIndex != frameIndex {
            state.frameIndex = frameIndex
            if let image = state.draw() {
                if let customColor = self.customColor {
                    self.imageNode.image = generateTintedImage(image: image, color: customColor)
                } else {
                    self.imageNode.image = image
                }
                self.imageUpdated?(image)
            }
            
            for (callbackFrame, callback) in state.item.callbacks {
                if !state.executedCallbacks.contains(callbackFrame) && frameIndex >= callbackFrame {
                    state.executedCallbacks.insert(callbackFrame)
                    callback()
                }
            }
        }
        
        var animationAdvancement: Double = self.delta ?? 1.0 / 60.0
        animationAdvancement *= Double(min(2, self.trackStack.count + 1))
        state.relativeTime += animationAdvancement
        
        if state.relativeTime >= duration && !self.didTryAdvancingState {
            if state.item.loop && self.trackStack.isEmpty {
                state.frameIndex = nil
                state.relativeTime = 0.0
            } else {
                self.didTryAdvancingState = true
                self.advanceState()
            }
        }
    }
    
    public func trackTo(item: ManagedAnimationItem, immediately: Bool = false) {
        if immediately {
            self.trackStack.removeAll()
            if let state = self.state, state.item.source == item.source {
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state, lottieSettings: self.lottieSettings)
            } else {
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil, lottieSettings: self.lottieSettings)
            }
            self.didTryAdvancingState = false
            self.previousTimestamp = CACurrentMediaTime()
            self.delta = 0.0
            self.displayLink.isPaused = false
            self.updateAnimation()
            return
        }
        self.trackStack.append(item)
        self.didTryAdvancingState = false
        self.updateAnimation()
    }
    
    open override func layout() {
        super.layout()
        
        self.imageNode.bounds = self.bounds
        self.imageNode.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
    }
}

public final class SimpleAnimationNode: ManagedAnimationNode {
    private let stillItem: ManagedAnimationItem
    private let stillEndItem: ManagedAnimationItem
    private var animationItem: ManagedAnimationItem
    
    public let size: CGSize
    private let playOnce: Bool
    public private(set) var didPlay = false
    
    public init(animationName: String, replaceColors: [UInt32: UInt32]? = nil, size: CGSize, playOnce: Bool = false, startFrame: Int = 0, lottieSettings: LottieRenderingSettings) {
        let startFrame = max(0, startFrame)
        let source = ManagedAnimationSource.local(animationName)
        self.size = size
        self.playOnce = playOnce
        self.stillItem = ManagedAnimationItem(source: source, replaceColors: replaceColors, frames: .range(startFrame: startFrame, endFrame: startFrame), duration: 0.01)
        self.stillEndItem = ManagedAnimationItem(source: source, replaceColors: replaceColors, frames: .still(.end), duration: 0.01)
        self.animationItem = ManagedAnimationItem(source: source, replaceColors: replaceColors)

        super.init(size: size, lottieSettings: lottieSettings)
        
        self.trackTo(item: self.stillItem)
        if startFrame > 0, let state = self.state {
            let clampedStartFrame = min(startFrame, max(0, state.frameCount - 1))
            let fps = state.fps > 0.0 ? state.fps : 60.0
            self.animationItem = ManagedAnimationItem(
                source: source,
                replaceColors: replaceColors,
                frames: .range(startFrame: clampedStartFrame, endFrame: state.frameCount),
                duration: Double(max(1, state.frameCount - clampedStartFrame)) / fps
            )
        }
    }
    
    public func play(immediately: Bool = false) {
        if !self.playOnce || !self.didPlay {
            self.didPlay = true
            self.trackTo(item: self.animationItem, immediately: immediately)
        }
    }
    
    public func reset(immediately: Bool = false) {
        self.didPlay = false
        self.trackTo(item: self.stillItem, immediately: immediately)
    }
    
    public func seekToEnd(immediately: Bool = false) {
        self.didPlay = false
        self.trackTo(item: self.stillEndItem, immediately: immediately)
    }
}
