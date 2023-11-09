import Foundation
import UIKit

public final class SharedDisplayLink {
    private final class DisplayLinkTarget: NSObject {
        let f: () -> Void
        
        init(_ f: @escaping () -> Void) {
            self.f = f
        }
        
        @objc func event() {
            self.f()
        }
    }
    
    public enum FramesPerSecond {
        case fps(Double)
        case max
    }
    
    public final class Subscription {
        fileprivate final class Target {
            let event: () -> Void
            let framesPerSecond: FramesPerSecond
            
            var lastDuration: Double = 0.0
            var totalTicks: Int = 0
            var acceptedTicks: Int = 0
            
            init(event: @escaping () -> Void, framesPerSecond: FramesPerSecond) {
                self.event = event
                self.framesPerSecond = framesPerSecond
            }
        }
        
        fileprivate let target: Target
        
        fileprivate init(event: @escaping () -> Void, framesPerSecond: FramesPerSecond) {
            self.target = Target(event: event, framesPerSecond: framesPerSecond)
        }
        
        deinit {
            SharedDisplayLink.shared.remove(target: self.target)
        }
    }
    
    public static let shared: SharedDisplayLink = {
        return SharedDisplayLink()
    }()
    
    private var displayLink: CADisplayLink?
    
    private var subscriptions: [Subscription.Target] = []
    
    private init() {
        self.displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            guard let self, let displayLink = self.displayLink else {
                return
            }
            self.displayLinkEvent(timestamp: displayLink.timestamp, duration: displayLink.duration)
        }, selector: #selector(DisplayLinkTarget.event))
        if #available(iOS 15.0, *) {
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: 120.0, preferred: 120.0)
        }
        self.displayLink?.add(to: .main, forMode: .common)
    }
    
    private func displayLinkEvent(timestamp: Double, duration: Double) {
        loop: for subscription in self.subscriptions {
            subscription.totalTicks += 1
            
            switch subscription.framesPerSecond {
            case let .fps(value):
                let secondsPerFrame = 1.0 / value
                
                subscription.lastDuration += duration
                if subscription.lastDuration >= secondsPerFrame * 0.99 {
                } else {
                    continue loop
                }
            case .max:
                break
            }
            subscription.lastDuration = 0.0
            subscription.acceptedTicks += 1
            subscription.event()
        }
    }
    
    public func add(framesPerSecond: FramesPerSecond = .max, _ event: @escaping () -> Void) -> Subscription {
        let subscription = Subscription(event: event, framesPerSecond: framesPerSecond)
        self.subscriptions.append(subscription.target)
        return subscription
    }
    
    private func remove(target: Subscription.Target) {
        if let index = self.subscriptions.firstIndex(where: { $0 === target }) {
            self.subscriptions.remove(at: index)
        }
    }
}
