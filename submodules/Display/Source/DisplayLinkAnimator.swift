import Foundation
import UIKit

public protocol SharedDisplayLinkDriverLink: AnyObject {
    var isPaused: Bool { get set }
    
    func invalidate()
}

public final class SharedDisplayLinkDriver {
    public typealias Link = SharedDisplayLinkDriverLink
    
    public static let shared = SharedDisplayLinkDriver()
    
    private let useNative: Bool
    
    public final class LinkImpl: Link {
        private let driver: SharedDisplayLinkDriver
        public let needsHighestFramerate: Bool
        let update: () -> Void
        var isValid: Bool = true
        public var isPaused: Bool = false {
            didSet {
                if self.isPaused != oldValue {
                    driver.requestUpdate()
                }
            }
        }
        
        init(driver: SharedDisplayLinkDriver, needsHighestFramerate: Bool, update: @escaping () -> Void) {
            self.driver = driver
            self.needsHighestFramerate = needsHighestFramerate
            self.update = update
        }
        
        public func invalidate() {
            self.isValid = false
        }
    }
    
    public final class NativeLinkImpl: Link {
        private var displayLink: CADisplayLink?
        
        public var isPaused: Bool = false {
            didSet {
                self.displayLink?.isPaused = self.isPaused
            }
        }
        
        init(needsHighestFramerate: Bool, update: @escaping () -> Void) {
            let displayLink = CADisplayLink(target: DisplayLinkTarget {
                update()
            }, selector: #selector(DisplayLinkTarget.event))
            
            if #available(iOS 15.0, *) {
                let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
                if maxFps > 61.0 {
                    let frameRateRange: CAFrameRateRange
                    if needsHighestFramerate {
                        frameRateRange = CAFrameRateRange(minimum: 30.0, maximum: 120.0, preferred: 120.0)
                    } else {
                        frameRateRange = .default
                    }
                    if displayLink.preferredFrameRateRange != frameRateRange {
                        displayLink.preferredFrameRateRange = frameRateRange
                    }
                }
            }
            
            self.displayLink = displayLink
            displayLink.add(to: .main, forMode: .common)
        }
        
        deinit {
            self.displayLink?.invalidate()
        }
        
        public func invalidate() {
            self.displayLink?.invalidate()
        }
    }
    
    private final class RequestContext {
        weak var link: LinkImpl?
        
        init(link: LinkImpl) {
            self.link = link
        }
    }
    
    private var displayLink: CADisplayLink?
    private var hasRequestedHighestFramerate: Bool = false
    private var requests: [RequestContext] = []
    
    private var isInForeground: Bool = false
    
    private init() {
        self.useNative = false
        
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.isInForeground = true
            self.update()
        })
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.isInForeground = false
            self.update()
        })
        
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            self.isInForeground = true
        } else {
            switch UIApplication.shared.applicationState {
            case .active:
                self.isInForeground = true
            default:
                self.isInForeground = false
            }
        }
        
        self.update()
    }
    
    public func updateForegroundState(_ isActive: Bool) {
        if self.isInForeground != isActive {
            self.isInForeground = isActive
            self.update()
        }
    }
    
    private func requestUpdate() {
        self.update()
    }
    
    private func update() {
        var hasActiveItems = false
        var needHighestFramerate = false
        for request in self.requests {
            if let link = request.link {
                needHighestFramerate = link.needsHighestFramerate
                if link.isValid && !link.isPaused {
                    hasActiveItems = true
                    break
                }
            }
        }
        
        if self.isInForeground && hasActiveItems {
            let displayLink: CADisplayLink
            if let current = self.displayLink {
                displayLink = current
            } else {
                displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkEvent))
                self.displayLink = displayLink
                displayLink.add(to: .main, forMode: .common)
            }
            if #available(iOS 15.0, *) {
                let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
                if maxFps > 61.0 {
                    let frameRateRange: CAFrameRateRange
                    if needHighestFramerate {
                        frameRateRange = CAFrameRateRange(minimum: 30.0, maximum: 120.0, preferred: 120.0)
                    } else {
                        frameRateRange = .default
                    }
                    if displayLink.preferredFrameRateRange != frameRateRange {
                        displayLink.preferredFrameRateRange = frameRateRange
                    }
                }
            }
            displayLink.isPaused = false
        } else {
            if let displayLink = self.displayLink {
                self.displayLink = nil
                displayLink.invalidate()
            }
        }
    }
    
    @objc private func displayLinkEvent() {
        var removeIndices: [Int]?
        for i in 0 ..< self.requests.count {
            if let link = self.requests[i].link, link.isValid {
                if !link.isPaused {
                    link.update()
                }
            } else {
                if removeIndices == nil {
                    removeIndices = [i]
                } else {
                    removeIndices?.append(i)
                }
            }
        }
        if let removeIndices = removeIndices {
            for index in removeIndices.reversed() {
                self.requests.remove(at: index)
            }
            
            if self.requests.isEmpty {
                self.update()
            }
        }
    }
    
    public func add(needsHighestFramerate: Bool = true, _ update: @escaping () -> Void) -> Link {
        if self.useNative {
            return NativeLinkImpl(needsHighestFramerate: needsHighestFramerate, update: update)
        } else {
            let link = LinkImpl(driver: self, needsHighestFramerate: needsHighestFramerate, update: update)
            self.requests.append(RequestContext(link: link))
            
            self.update()
            
            return link
        }
    }
}

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
    private var displayLink: SharedDisplayLinkDriver.Link?
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
        
        self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
            self?.tick()
        }
        self.displayLink?.isPaused = false
    }
    
    deinit {
        self.displayLink?.isPaused = true
        self.displayLink?.invalidate()
    }
    
    public func invalidate() {
        self.displayLink?.isPaused = true
        self.displayLink?.invalidate()
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
            self.displayLink?.isPaused = true
            self.completion()
        }
    }
}

public final class ConstantDisplayLinkAnimator {
    private var displayLink: SharedDisplayLinkDriver.Link?
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
        let _ = displayLink
    }
    
    public var isPaused: Bool = true {
        didSet {
            if self.isPaused != oldValue {
                if !self.isPaused && self.displayLink == nil {
                    let displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
                        self?.tick()
                    }
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

