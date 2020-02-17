import Foundation
import UIKit
import Display
import AsyncDisplayKit
import RLottieBinding
import AppBundle
import GZip
import SwiftSignalKit

private final class ManagedAnimationState {
    let item: ManagedAnimationItem
    
    private let instance: LottieInstance
    
    let frameCount: Int
    let fps: Double
    
    var relativeTime: Double = 0.0
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
    var duration: Double
}

class ManagedAnimationNode: ASDisplayNode {
    let intrinsicSize: CGSize
    
    private let imageNode: ASImageNode
    private let displayLink: CADisplayLink
    
    fileprivate var state: ManagedAnimationState?
    fileprivate var trackStack: [ManagedAnimationItem] = []
    fileprivate var didTryAdvancingState = false
    
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
    
    func advanceState() {
        guard !self.trackStack.isEmpty else {
            return
        }
        
        let item = self.trackStack.removeFirst()
        
        if let state = self.state, state.item.name == item.name {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
        } else {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil)
        }
        
        self.didTryAdvancingState = false
    }
    
    fileprivate func updateAnimation() {
        if self.state == nil {
            self.advanceState()
        }
        
        guard let state = self.state else {
            return
        }
        let timestamp = CACurrentMediaTime()
        
        let fps = state.fps
        let frameRange = state.item.frames
        
        let duration: Double = state.item.duration
        var t = state.relativeTime / duration
        t = max(0.0, t)
        t = min(1.0, t)
        //print("\(t) \(state.item.name)")
        let frameOffset = Int(Double(frameRange.startFrame) * (1.0 - t) + Double(frameRange.endFrame) * t)
        let lowerBound: Int = 0
        let upperBound = state.frameCount - 1
        let frameIndex = max(lowerBound, min(upperBound, frameOffset))
        
        if state.frameIndex != frameIndex {
            state.frameIndex = frameIndex
            if let image = state.draw() {
                self.imageNode.image = image
            }
        }
        
        var animationAdvancement: Double = 1.0 / 60.0
        animationAdvancement *= Double(min(2, self.trackStack.count + 1))
        
        state.relativeTime += animationAdvancement
        
        if state.relativeTime >= duration && !self.didTryAdvancingState {
            self.didTryAdvancingState = true
            self.advanceState()
        }
    }
    
    func trackTo(item: ManagedAnimationItem) {
        self.trackStack.append(item)
        self.didTryAdvancingState = false
        self.updateAnimation()
    }
}

enum ManagedMonkeyAnimationIdle: CaseIterable {
    case blink
    case ear
    case still
}

enum ManagedMonkeyAnimationState: Equatable {
    case idle(ManagedMonkeyAnimationIdle)
    case eyesClosed
    case peeking
    case tracking(CGFloat)
}

final class ManagedMonkeyAnimationNode: ManagedAnimationNode {
    private var monkeyState: ManagedMonkeyAnimationState = .idle(.blink)
    private var timer: SwiftSignalKit.Timer?
    
    init() {
        super.init(size: CGSize(width: 136.0, height: 136.0))
        
        self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 0), duration: 0.3))
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    private func startIdleTimer() {
        self.timer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: Double.random(in: 1.0 ..< 1.5), repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.monkeyState {
            case .idle:
                if let idle = ManagedMonkeyAnimationIdle.allCases.randomElement() {
                    strongSelf.setState(.idle(idle))
                }
            default:
                break
            }
        }, queue: .mainQueue())
        self.timer = timer
        timer.start()
    }
    
    override func advanceState() {
        super.advanceState()
        
        self.timer?.invalidate()
        self.timer = nil
        
        if self.trackStack.isEmpty, case .idle = self.monkeyState {
            self.startIdleTimer()
        }
    }
    
    private func enqueueIdle(_ idle: ManagedMonkeyAnimationIdle) {
        switch idle {
        case .still:
            self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 0), duration: 0.3))
        case .blink:
            self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle1", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 30), duration: 0.3))
        case .ear:
            self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle2", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 30), duration: 0.3))
            //self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 179), duration: 3.0))
        }
    }
    
    func setState(_ monkeyState: ManagedMonkeyAnimationState) {
        let previousState = self.monkeyState
        self.monkeyState = monkeyState
        
        self.timer?.invalidate()
        self.timer = nil
        
        func enqueueTracking(_ value: CGFloat) {
            let lowerBound = 18
            let upperBound = 160
            let frameIndex = lowerBound + Int(value * CGFloat(upperBound - lowerBound))
            if let state = self.state, state.item.name == "TwoFactorSetupMonkeyTracking" {
                let item = ManagedAnimationItem(name: "TwoFactorSetupMonkeyTracking", frames: ManagedAnimationFrameRange(startFrame: state.frameIndex ?? 0, endFrame: frameIndex), duration: 0.3)
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
                self.didTryAdvancingState = false
                self.updateAnimation()
            } else {
                self.trackStack = self.trackStack.filter {
                    $0.name != "TwoFactorSetupMonkeyTracking"
                }
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyTracking", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: frameIndex), duration: 0.3))
            }
        }
        
        func enqueueClearTracking() {
            if let state = self.state, state.item.name == "TwoFactorSetupMonkeyTracking" {
                let item = ManagedAnimationItem(name: "TwoFactorSetupMonkeyTracking", frames: ManagedAnimationFrameRange(startFrame: state.frameIndex ?? 0, endFrame: 0), duration: 0.3)
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
                self.didTryAdvancingState = false
                self.updateAnimation()
            }
        }
        
        switch previousState {
        case let .idle(previousIdle):
            switch monkeyState {
            case let .idle(idle):
                self.enqueueIdle(idle)
            case .eyesClosed:
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 41), duration: 0.3))
            case .peeking:
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyCloseAndPeek", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 41), duration: 0.3))
            case let .tracking(value):
                enqueueTracking(value)
            }
        case .eyesClosed:
            switch monkeyState {
            case let .idle(idle):
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose", frames: ManagedAnimationFrameRange(startFrame: 41, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                break
            case .peeking:
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyPeek", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 14), duration: 0.3))
            case let .tracking(value):
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose", frames: ManagedAnimationFrameRange(startFrame: 41, endFrame: 0), duration: 0.3))
                enqueueTracking(value)
            }
        case .peeking:
            switch monkeyState {
            case let .idle(idle):
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyCloseAndPeek", frames: ManagedAnimationFrameRange(startFrame: 41, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyPeek", frames: ManagedAnimationFrameRange(startFrame: 14, endFrame: 0), duration: 0.3))
            case .peeking:
                break
            case let .tracking(value):
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyCloseAndPeek", frames: ManagedAnimationFrameRange(startFrame: 41, endFrame: 0), duration: 0.3))
                enqueueTracking(value)
            }
        case let .tracking(currentValue):
            switch monkeyState {
            case let .idle(idle):
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyIdle", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyClose", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 41), duration: 0.3))
            case .peeking:
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(name: "TwoFactorSetupMonkeyCloseAndPeek", frames: ManagedAnimationFrameRange(startFrame: 0, endFrame: 41), duration: 0.3))
            case let .tracking(value):
                if abs(currentValue - value) > CGFloat.ulpOfOne {
                    enqueueTracking(value)
                }
            }
        }
    }
}
