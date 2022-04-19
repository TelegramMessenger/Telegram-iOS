import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import RLottieBinding
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
    
    public init?(displaySize: CGSize, item: ManagedAnimationItem, current: ManagedAnimationState?) {
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
            guard let instance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: item.replaceColors, cacheKey: item.source.cacheKey) else {
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
        let renderContext = DrawingContext(size: self.displaySize, scale: UIScreenScale, clear: true)

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
    
    private let imageNode: ASImageNode
    private let displayLink: CADisplayLink
    
    public var imageUpdated: ((UIImage) -> Void)?
    public var image: UIImage? {
        return self.imageNode.image
    }
    
    public var state: ManagedAnimationState?
    public var trackStack: [ManagedAnimationItem] = []
    public var didTryAdvancingState = false
    
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
    
    public init(size: CGSize) {
        self.intrinsicSize = size
        
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)
        
        final class DisplayLinkTarget: NSObject {
            private let f: () -> Void
            
            init(_ f: @escaping () -> Void) {
                self.f = f
            }
            
            @objc func event() {
                self.f()
            }
        }
        var displayLinkUpdate: (() -> Void)?
        self.displayLink = CADisplayLink(target: DisplayLinkTarget {
            displayLinkUpdate?()
        }, selector: #selector(DisplayLinkTarget.event))
        if #available(iOS 10.0, *) {
            self.displayLink.preferredFramesPerSecond = 60
        }
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        self.displayLink.add(to: RunLoop.main, forMode: .common)
        
        displayLinkUpdate = { [weak self] in
            self?.updateAnimation()
        }
    }
    
    open func advanceState() {
        guard !self.trackStack.isEmpty else {
            return
        }
        
        let item = self.trackStack.removeFirst()
        
        if let state = self.state, state.item.source == item.source {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
        } else {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil)
        }
        
        self.didTryAdvancingState = false
    }
    
    public func updateAnimation() {
        if self.state == nil {
            self.advanceState()
        }
        
        guard let state = self.state else {
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
        
        var animationAdvancement: Double = 1.0 / 60.0
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
    
    public func trackTo(item: ManagedAnimationItem) {
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
    private let animationItem: ManagedAnimationItem
    
    public let size: CGSize
    private let playOnce: Bool
    public private(set) var didPlay = false
    
    public init(animationName: String, replaceColors: [UInt32: UInt32]? = nil, size: CGSize, playOnce: Bool = false) {
        self.size = size
        self.playOnce = playOnce
        self.stillItem = ManagedAnimationItem(source: .local(animationName), replaceColors: replaceColors, frames: .range(startFrame: 0, endFrame: 0), duration: 0.01)
        self.animationItem = ManagedAnimationItem(source: .local(animationName), replaceColors: replaceColors)

        super.init(size: size)
        
        self.trackTo(item: self.stillItem)
    }
    
    public func play() {
        if !self.playOnce || !self.didPlay {
            self.didPlay = true
            self.trackTo(item: self.animationItem)
        }
    }
    
    public func reset() {
        self.didPlay = false
        self.trackTo(item: self.stillItem)
    }
}
