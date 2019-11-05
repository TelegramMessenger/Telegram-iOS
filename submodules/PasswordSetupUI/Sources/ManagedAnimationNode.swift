import Foundation
import UIKit
import Display
import AsyncDisplayKit
import RLottieBinding
import AppBundle
import GZip

private final class ManagedAnimationState {
    let item: ManagedAnimationItem
    
    private let instance: LottieInstance
    
    let frameCount: Int
    let fps: Double
    
    var startTime: Double?
    var frameIndex: Int?
    
    private let renderContext: DrawingContext
    
    init?(displaySize: CGSize, item: ManagedAnimationItem, current: ManagedAnimationState?) {
        let resolvedInstance: LottieInstance
        let renderContext: DrawingContext
        
        if let current = current {
            resolvedInstance = current.instance
            renderContext = current.renderContext
        } else {
            guard let path = getAppBundle().path(forResource: item.name, ofType: "tgs") else {
                return nil
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return nil
            }
            guard let unpackedData = TGGUnzipData(data, 5 * 1024 * 1024) else {
                return nil
            }
            guard let instance = LottieInstance(data: unpackedData, cacheKey: item.name) else {
                return nil
            }
            resolvedInstance = instance
            renderContext = DrawingContext(size: displaySize, scale: UIScreenScale, premultiplied: true, clear: true)
        }
        
        self.item = item
        self.instance = resolvedInstance
        self.renderContext = renderContext
        
        self.frameCount = Int(self.instance.frameCount)
        self.fps = Double(self.instance.frameRate)
    }
    
    func draw() -> UIImage? {
        self.instance.renderFrame(with: Int32(self.frameIndex ?? 0), into: self.renderContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(self.renderContext.size.width * self.renderContext.scale), height: Int32(self.renderContext.size.height * self.renderContext.scale), bytesPerRow: Int32(self.renderContext.bytesPerRow))
        return self.renderContext.generateImage()
    }
}

struct ManagedAnimationFrameRange: Equatable {
    var startFrame: Int
    var endFrame: Int
}

struct ManagedAnimationItem: Equatable {
    let name: String
    var frames: ManagedAnimationFrameRange
}

class ManagedAnimationNode: ASDisplayNode {
    let intrinsicSize: CGSize
    
    private let imageNode: ASImageNode
    private let displayLink: CADisplayLink
    
    private var state: ManagedAnimationState?
    
    init(size: CGSize) {
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
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        self.displayLink.add(to: RunLoop.main, forMode: .common)
        
        displayLinkUpdate = { [weak self] in
            self?.updateAnimation()
        }
    }
    
    private func updateAnimation() {
        guard let state = self.state else {
            return
        }
        let timestamp = CACurrentMediaTime()
        
        var startTime: Double
        if let current = state.startTime {
            startTime = current
        } else {
            startTime = timestamp
            state.startTime = startTime
        }
        
        let fps = state.fps
        let frameRange = state.item.frames
        
        let duration: Double = 0.3
        var t = (timestamp - startTime) / duration
        t = max(0.0, t)
        t = min(1.0, t)
        let frameOffset = Int(Double(frameRange.startFrame) * (1.0 - t) + Double(frameRange.startFrame) * t)
        let lowerBound = min(frameRange.startFrame, state.frameCount - 1)
        let upperBound = min(frameRange.endFrame, state.frameCount - 1)
        let frameIndex = max(lowerBound, min(upperBound, frameOffset))
        
        if state.frameIndex != frameIndex {
            state.frameIndex = frameIndex
            if let image = state.draw() {
                self.imageNode.image = image
            }
        }
    }
    
    func trackTo(item: ManagedAnimationItem, frameIndex: Int) {
        if let state = self.state, state.item.name == item.name {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
        } else {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil)
        }
        self.updateAnimation()
    }
}

enum ManagedMonkeyAnimationState: Equatable {
    case idle
    case eyesClosed
    case peeking
    case tracking(CGFloat)
}

/*private let animationIdle = ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle",
    intro: nil,
    loop: ManagedAnimationTrack(frameRange: 0 ..< 1),
    outro: nil
)
 
 private let animationIdle = ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle",
     intro: nil,
     loop: ManagedAnimationTrack(frameRange: 0 ..< 1),
     outro: nil
 )

 private let animationTracking = ManagedAnimationItem(name: "TwoFactorSetupMonkeyTracking",
     intro: nil,
     loop: ManagedAnimationTrack(frameRange: 0 ..< Int.max),
     outro: nil
 )

 private let animationHide = ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose",
     intro: ManagedAnimationTrack(frameRange: 0 ..< 41),
     loop: ManagedAnimationTrack(frameRange: 40 ..< 41),
     outro: ManagedAnimationTrack(frameRange: 60 ..< 99)
 )

 private let animationHideNoOutro = ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose",
     intro: ManagedAnimationTrack(frameRange: 0 ..< 41),
     loop: ManagedAnimationTrack(frameRange: 40 ..< 41),
     outro: nil
 )

 private let animationHideNoIntro = ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose",
     intro: nil,
     loop: ManagedAnimationTrack(frameRange: 40 ..< 41),
     outro: ManagedAnimationTrack(frameRange: 60 ..< 99)
 )

 private let animationHideOutro = ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose",
     intro: nil,
     loop: nil,
     outro: ManagedAnimationTrack(frameRange: 60 ..< 99)
 )

 private let animationPeek = ManagedAnimationItem(name: "TwoFactorSetupMonkeyPeek",
     intro: ManagedAnimationTrack(frameRange: 0 ..< 14),
     loop: ManagedAnimationTrack(frameRange: 13 ..< 14),
     outro: ManagedAnimationTrack(frameRange: 14 ..< 34)
 )

 private let animationMail = ManagedAnimationItem(name: "TwoFactorSetupMail",
     intro: ManagedAnimationTrack(frameRange: 0 ..< Int.max),
     loop: ManagedAnimationTrack(frameRange: Int.max - 1 ..< Int.max),
     outro: nil
 )

 private let animationHint = ManagedAnimationItem(name: "TwoFactorSetupHint",
     intro: ManagedAnimationTrack(frameRange: 0 ..< Int.max),
     loop: ManagedAnimationTrack(frameRange: Int.max - 1 ..< Int.max),
     outro: nil
 )*/

final class ManagedMonkeyAnimationNode: ManagedAnimationNode {
    private var state: ManagedMonkeyAnimationState = .idle
    
    init() {
        super.init(size: CGSize(width: 136.0, height: 136.0))
        
        self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 0)), frameIndex: 0)
    }
    
    func setState(_ state: ManagedMonkeyAnimationState) {
        let previousState = self.state
        self.state = state
        
        switch previousState {
        case .idle:
            switch state {
            case .idle:
                break
            case .eyesClosed:
                break
            case .peeking:
                break
            case let .tracking(value):
                break
            }
        case .eyesClosed:
            switch state {
            case .idle:
                break
            case .eyesClosed:
                break
            case .peeking:
                break
            case let .tracking(value):
                break
            }
        case .peeking:
            switch state {
            case .idle:
                break
            case .eyesClosed:
                break
            case .peeking:
                break
            case let .tracking(value):
                break
            }
        case let .tracking(previousValue):
            switch state {
            case .idle:
                break
            case .eyesClosed:
                break
            case .peeking:
                break
            case let .tracking(value):
                break
            }
        }
    }
}
