import Foundation
import UIKit

public final class DisplayLinkTarget: NSObject {
    private let f: () -> Void
    
    public init(_ f: @escaping () -> Void) {
        self.f = f
    }
    
    @objc public func event() {
        self.f()
    }
}

public final class DisplayLinkAnimator {
    private var displayLink: CADisplayLink!
    private let duration: Double
    private let fromValue: CGFloat
    private let toValue: CGFloat
    private let startTime: Double
    private let update: (CGFloat) -> Void
    private let completion: () -> Void
    private var completed = false
    
    public init(duration: Double, from fromValue: CGFloat, to toValue: CGFloat, update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
        self.duration = duration
        self.fromValue = fromValue
        self.toValue = toValue
        self.update = update
        self.completion = completion
        
        self.startTime = CACurrentMediaTime()
        
        self.displayLink = CADisplayLink(target: DisplayLinkTarget({ [weak self] in
            self?.tick()
        }), selector: #selector(DisplayLinkTarget.event))
        self.displayLink.isPaused = false
        self.displayLink.add(to: RunLoop.main, forMode: .common)
    }
    
    deinit {
        self.displayLink.isPaused = true
        self.displayLink.invalidate()
    }
    
    public func invalidate() {
        self.displayLink.isPaused = true
        self.displayLink.invalidate()
    }
    
    @objc private func tick() {
        if self.completed {
            return
        }
        let timestamp = CACurrentMediaTime()
        var t = (timestamp - self.startTime) / self.duration
        t = max(0.0, t)
        t = min(1.0, t)
        self.update(self.fromValue * CGFloat(1 - t) + self.toValue * CGFloat(t))
        if abs(t - 1.0) < Double.ulpOfOne {
            self.completed = true
            self.displayLink.isPaused = true
            self.completion()
        }
    }
}

public final class ConstantDisplayLinkAnimator {
    private var displayLink: CADisplayLink?
    private let update: () -> Void
    private var completed = false
    
    public var frameInterval: Int = 1 {
        didSet {
            self.updateDisplayLink()
        }
    }
    
    private func updateDisplayLink() {
        guard let displayLink = self.displayLink else {
            return
        }
        if #available(iOS 10.0, *) {
            let preferredFramesPerSecond: Int
            if self.frameInterval == 1 {
                preferredFramesPerSecond = 60
            } else {
                preferredFramesPerSecond = 30
            }
            displayLink.preferredFramesPerSecond = preferredFramesPerSecond
        } else {
            displayLink.frameInterval = self.frameInterval
        }
    }
    
    public var isPaused: Bool = true {
        didSet {
            if self.isPaused != oldValue {
                if !self.isPaused && self.displayLink == nil {
                    let displayLink = CADisplayLink(target: DisplayLinkTarget({ [weak self] in
                        self?.tick()
                    }), selector: #selector(DisplayLinkTarget.event))
                    /*if #available(iOS 15.0, *) {
                        self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
                    }*/
                    displayLink.add(to: RunLoop.main, forMode: .common)
                    self.displayLink = displayLink
                    self.updateDisplayLink()
                }
                
                self.displayLink?.isPaused = self.isPaused
            }
        }
    }
    
    public init(update: @escaping () -> Void) {
        self.update = update
    }
    
    deinit {
        if let displayLink = self.displayLink {
            displayLink.isPaused = true
            displayLink.invalidate()
        }
    }
    
    public func invalidate() {
        if let displayLink = self.displayLink {
            displayLink.isPaused = true
            displayLink.invalidate()
        }
    }
    
    @objc private func tick() {
        if self.completed {
            return
        }
        self.update()
    }
}

