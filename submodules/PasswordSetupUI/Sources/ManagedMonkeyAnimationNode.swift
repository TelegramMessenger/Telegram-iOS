import Foundation
import UIKit
import Display
import AsyncDisplayKit
import RLottieBinding
import AppBundle
import GZip
import SwiftSignalKit
import ManagedAnimationNode

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
        
        self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.3))
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
            self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.3))
        case .blink:
            self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle1"), frames: .range(startFrame: 0, endFrame: 30), duration: 0.3))
        case .ear:
            self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle2"), frames: .range(startFrame: 0, endFrame: 30), duration: 0.3))
            //self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle"), frames: .range(startFrame: 0, endFrame: 179), duration: 3.0))
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
            if let state = self.state, state.item.source == .local("TwoFactorSetupMonkeyTracking") {
                let item = ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyTracking"), frames: .range(startFrame: state.frameIndex ?? 0, endFrame: frameIndex), duration: 0.3)
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
                self.didTryAdvancingState = false
                self.updateAnimation()
            } else {
                self.trackStack = self.trackStack.filter {
                    $0.source != .local("TwoFactorSetupMonkeyTracking")
                }
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyTracking"), frames: .range(startFrame: 0, endFrame: frameIndex), duration: 0.3))
            }
        }
        
        func enqueueClearTracking() {
            if let state = self.state, state.item.source == .local("TwoFactorSetupMonkeyTracking") {
                let item = ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyTracking"), frames: .range(startFrame: state.frameIndex ?? 0, endFrame: 0), duration: 0.3)
                self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
                self.didTryAdvancingState = false
                self.updateAnimation()
            }
        }
        
        switch previousState {
        case .idle:
            switch monkeyState {
            case let .idle(idle):
                self.enqueueIdle(idle)
            case .eyesClosed:
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyClose"), frames: .range(startFrame: 0, endFrame: 41), duration: 0.3))
            case .peeking:
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyCloseAndPeek"), frames: .range(startFrame: 0, endFrame: 41), duration: 0.3))
            case let .tracking(value):
                enqueueTracking(value)
            }
        case .eyesClosed:
            switch monkeyState {
            case let .idle(idle):
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyClose"), frames: .range(startFrame: 41, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                break
            case .peeking:
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyPeek"), frames: .range(startFrame: 0, endFrame: 14), duration: 0.3))
            case let .tracking(value):
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyClose"), frames: .range(startFrame: 41, endFrame: 0), duration: 0.3))
                enqueueTracking(value)
            }
        case .peeking:
            switch monkeyState {
            case let .idle(idle):
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyCloseAndPeek"), frames: .range(startFrame: 41, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyPeek"), frames: .range(startFrame: 14, endFrame: 0), duration: 0.3))
            case .peeking:
                break
            case let .tracking(value):
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyCloseAndPeek"), frames: .range(startFrame: 41, endFrame: 0), duration: 0.3))
                enqueueTracking(value)
            }
        case let .tracking(currentValue):
            switch monkeyState {
            case let .idle(idle):
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyIdle"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.3))
                self.enqueueIdle(idle)
            case .eyesClosed:
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyClose"), frames: .range(startFrame: 0, endFrame: 41), duration: 0.3))
            case .peeking:
                enqueueClearTracking()
                self.trackTo(item: ManagedAnimationItem(source: .local("TwoFactorSetupMonkeyCloseAndPeek"), frames: .range(startFrame: 0, endFrame: 41), duration: 0.3))
            case let .tracking(value):
                if abs(currentValue - value) > CGFloat.ulpOfOne {
                    enqueueTracking(value)
                }
            }
        }
    }
}
