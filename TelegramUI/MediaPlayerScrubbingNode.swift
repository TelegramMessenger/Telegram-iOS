import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

enum MediaPlayerScrubbingNodeCap {
    case square
    case round
}

private func generateHandleBackground(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 2.0, height: 4.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 1.5, height: 1.5)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - 1.5), size: CGSize(width: 1.5, height: 1.5)))
        context.fill(CGRect(origin: CGPoint(x: 0.0, y: 1.5 / 2.0), size: CGSize(width: 1.5, height: size.height - 1.5)))
    })?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 2)
}

private final class MediaPlayerScrubbingNodeButton: ASButtonNode {
    var beginScrubbing: (() -> Void)?
    var endScrubbing: ((Bool) -> Void)?
    var updateScrubbing: ((CGFloat) -> Void)?
    
    private var scrubbingStartLocation: CGPoint?
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    override func beginTracking(with touch: UITouch, with event: UIEvent?) -> Bool {
        if super.beginTracking(with: touch, with: event) {
            scrubbingStartLocation = touch.location(in: self.view)
            self.beginScrubbing?()
            return true
        } else {
            return false
        }
    }
    
    override func continueTracking(with touch: UITouch, with touchEvent: UIEvent?) -> Bool {
        if super.continueTracking(with: touch, with: touchEvent) {
            let location = touch.location(in: self.view)
            if let scrubbingStartLocation = self.scrubbingStartLocation {
                let delta = location.x - scrubbingStartLocation.x
                self.updateScrubbing?(delta / self.bounds.size.width)
            }
            return true
        } else {
            return false
        }
    }
    
    override func endTracking(with touch: UITouch?, with event: UIEvent?) {
        super.endTracking(with: touch, with: event)
        if let touch = touch {
            let location = touch.location(in: self.view)
            if let scrubbingStartLocation = self.scrubbingStartLocation {
                let delta = location.x - scrubbingStartLocation.x
                self.updateScrubbing?(delta / self.bounds.size.width)
            }
        }
        self.scrubbingStartLocation = nil
        self.endScrubbing?(true)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        self.scrubbingStartLocation = nil
        self.endScrubbing?(false)
    }
}

private final class MediaPlayerScrubbingForegroundNode: ASDisplayNode {
    var onEnterHierarchy: (() -> Void)?
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.onEnterHierarchy?()
    }
}

final class MediaPlayerScrubbingNode: ASDisplayNode {
    private let lineCap: MediaPlayerScrubbingNodeCap
    private let lineHeight: CGFloat
    
    private let backgroundNode: ASImageNode
    private let foregroundContentNode: ASImageNode
    private let foregroundNode: MediaPlayerScrubbingForegroundNode
    private let handleNode: ASDisplayNode?
    private let handleNodeContainer: MediaPlayerScrubbingNodeButton?
    
    private var playbackStatusValue: MediaPlayerPlaybackStatus?
    private var scrubbingBeginTimestamp: Double?
    private var scrubbingTimestamp: Double?
    
    var playbackStatusUpdated: ((MediaPlayerPlaybackStatus?) -> Void)?
    var playerStatusUpdated: ((MediaPlayerStatus?) -> Void)?
    var seek: ((Double) -> Void)?
    
    private var statusValue: MediaPlayerStatus? {
        didSet {
            if self.statusValue != oldValue {
                self.updateProgress()
                
                let playbackStatus = self.statusValue?.status
                if self.playbackStatusValue != playbackStatus {
                    self.playbackStatusValue = playbackStatus
                    if let playbackStatusUpdated = self.playbackStatusUpdated {
                        playbackStatusUpdated(playbackStatus)
                    }
                }
                
                self.playerStatusUpdated?(self.statusValue)
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus?>()
    
    var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status |> map { $0 })
            } else {
                self.statusValuePromise.set(.single(nil))
            }
        }
    }
    
    init(lineHeight: CGFloat, lineCap: MediaPlayerScrubbingNodeCap, scrubberHandle: Bool, backgroundColor: UIColor, foregroundColor: UIColor) {
        self.lineHeight = lineHeight
        self.lineCap = lineCap
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.foregroundContentNode = ASImageNode()
        self.foregroundContentNode.isLayerBacked = true
        self.foregroundContentNode.displaysAsynchronously = false
        self.foregroundContentNode.displayWithoutProcessing = true
        
        switch lineCap {
            case .round:
                self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: backgroundColor)
                self.foregroundContentNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: foregroundColor)
            case .square:
                self.backgroundNode.backgroundColor = backgroundColor
                self.foregroundContentNode.backgroundColor = foregroundColor
        }
        
        self.foregroundNode = MediaPlayerScrubbingForegroundNode()
        self.foregroundNode.isLayerBacked = true
        self.foregroundNode.clipsToBounds = true
        
        if scrubberHandle {
            let handleNode = ASImageNode()
            handleNode.image = generateHandleBackground(color: foregroundColor)
            handleNode.isLayerBacked = true
            self.handleNode = handleNode
            
            let handleNodeContainer = MediaPlayerScrubbingNodeButton()
            handleNodeContainer.addSubnode(handleNode)
            self.handleNodeContainer = handleNodeContainer
        } else {
            self.handleNode = nil
            self.handleNodeContainer = nil
        }
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.foregroundNode.addSubnode(self.foregroundContentNode)
        self.addSubnode(self.foregroundNode)
        
        if let handleNodeContainer = self.handleNodeContainer {
            self.addSubnode(handleNodeContainer)
            handleNodeContainer.beginScrubbing = { [weak self] in
                if let strongSelf = self {
                    if let statusValue = strongSelf.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                        strongSelf.scrubbingBeginTimestamp = statusValue.timestamp
                        strongSelf.scrubbingTimestamp = statusValue.timestamp
                        strongSelf.updateProgress()
                    }
                }
            }
            handleNodeContainer.updateScrubbing = { [weak self] addedFraction in
                if let strongSelf = self {
                    if let statusValue = strongSelf.statusValue, let scrubbingBeginTimestamp = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                        strongSelf.scrubbingTimestamp = scrubbingBeginTimestamp + statusValue.duration * Double(addedFraction)
                        strongSelf.updateProgress()
                    }
                }
            }
            handleNodeContainer.endScrubbing = { [weak self] apply in
                if let strongSelf = self {
                    strongSelf.scrubbingBeginTimestamp = nil
                    let scrubbingTimestamp = strongSelf.scrubbingTimestamp
                    strongSelf.scrubbingTimestamp = nil
                    if let scrubbingTimestamp = scrubbingTimestamp, apply {
                        strongSelf.seek?(scrubbingTimestamp)
                    }
                    strongSelf.updateProgress()
                }
            }
        }
        
        self.foregroundNode.onEnterHierarchy = { [weak self] in
            self?.updateProgress()
        }
        
        self.statusDisposable = (self.statusValuePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.statusValue = status
                }
            })
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    override var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.updateProgress()
            }
        }
    }
    
    func updateColors(backgroundColor: UIColor, foregroundColor: UIColor) {
        switch lineCap {
            case .round:
                self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: backgroundColor)
                self.foregroundContentNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: foregroundColor)
            case .square:
                self.backgroundNode.backgroundColor = backgroundColor
                self.foregroundContentNode.backgroundColor = foregroundColor
        }
        if let handleNode = self.handleNode as? ASImageNode {
            handleNode.image = generateHandleBackground(color: foregroundColor)
        }
    }
    
    private func preparedAnimation(keyPath: String, from: NSValue, to: NSValue, duration: Double, beginTime: Double?, offset: Double, speed: Float, repeatForever: Bool = false) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        //animation.isRemovedOnCompletion = true
        animation.fillMode = kCAFillModeBoth
        animation.speed = speed
        animation.timeOffset = offset
        animation.isAdditive = false
        //animation.repeatCount = Float.infinity
        if let beginTime = beginTime {
            animation.beginTime = beginTime
        }
        return animation
    }
    
    private func updateProgress() {
        self.foregroundNode.layer.removeAnimation(forKey: "playback-bounds")
        self.foregroundNode.layer.removeAnimation(forKey: "playback-position")
        if let handleNodeContainer = self.handleNodeContainer {
            handleNodeContainer.layer.removeAnimation(forKey: "playback-bounds")
        }
        
        let bounds = self.bounds
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((bounds.size.height - self.lineHeight) / 2.0)), size: CGSize(width: bounds.size.width, height: self.lineHeight))
        self.backgroundNode.frame = backgroundFrame
        self.foregroundContentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
        
        if let handleNode = self.handleNode {
            handleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 2.0, height: bounds.size.height))
            handleNode.layer.removeAnimation(forKey: "playback-position")
        }
        
        if let handleNodeContainer = self.handleNodeContainer {
            handleNodeContainer.frame = bounds
        }
        
        let timestampAndDuration: (timestamp: Double, duration: Double)?
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            if let scrubbingTimestamp = self.scrubbingTimestamp {
                timestampAndDuration = (max(0.0, min(scrubbingTimestamp, statusValue.duration)), statusValue.duration)
            } else {
                timestampAndDuration = (statusValue.timestamp, statusValue.duration)
            }
        } else {
            timestampAndDuration = nil
        }
        
        if let (timestamp, duration) = timestampAndDuration {
            let progress = CGFloat(timestamp / duration)
            if let _ = scrubbingTimestamp {
                let fromRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                let toRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                
                let fromBounds = CGRect(origin: CGPoint(), size: fromRect.size)
                let toBounds = CGRect(origin: CGPoint(), size: toRect.size)
                
                self.foregroundNode.frame = toRect
                self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-bounds")
                self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: CGPoint(x: fromRect.midX, y: fromRect.midY)), to: NSValue(cgPoint: CGPoint(x: toRect.midX, y: toRect.midY)), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-position")
                
                if let handleNodeContainer = self.handleNodeContainer {
                    let fromBounds = bounds
                    let toBounds = bounds.offsetBy(dx: -bounds.size.width, dy: 0.0)
                    
                    handleNodeContainer.isHidden = false
                    handleNodeContainer.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-bounds")
                }
                
                if let handleNode = self.handleNode {
                    let fromPosition = handleNode.position
                    let toPosition = CGPoint(x: fromPosition.x - 1.0, y: fromPosition.y)
                    handleNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: fromPosition), to: NSValue(cgPoint: toPosition), duration: duration / Double(bounds.size.width), beginTime: nil, offset: timestamp, speed: 0.0, repeatForever: true), forKey: "playback-position")
                }
            } else if let statusValue = self.statusValue, !progress.isNaN && progress.isFinite {
                if statusValue.generationTimestamp.isZero {
                    let fromRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                    let toRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                    
                    let fromBounds = CGRect(origin: CGPoint(), size: fromRect.size)
                    let toBounds = CGRect(origin: CGPoint(), size: toRect.size)
                    
                    self.foregroundNode.frame = toRect
                    self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-bounds")
                    self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: CGPoint(x: fromRect.midX, y: fromRect.midY)), to: NSValue(cgPoint: CGPoint(x: toRect.midX, y: toRect.midY)), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-position")
                    
                    if let handleNodeContainer = self.handleNodeContainer {
                        let fromBounds = bounds
                        let toBounds = bounds.offsetBy(dx: -bounds.size.width, dy: 0.0)
                        
                        handleNodeContainer.isHidden = false
                        handleNodeContainer.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: nil, offset: timestamp, speed: 0.0), forKey: "playback-bounds")
                    }
                    
                    if let handleNode = self.handleNode {
                        let fromPosition = handleNode.position
                        let toPosition = CGPoint(x: fromPosition.x - 1.0, y: fromPosition.y)
                        handleNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: fromPosition), to: NSValue(cgPoint: toPosition), duration: duration / Double(bounds.size.width), beginTime: nil, offset: timestamp, speed: 0.0, repeatForever: true), forKey: "playback-position")
                    }
                } else {
                    let fromRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                    let toRect = CGRect(origin: backgroundFrame.origin, size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                    
                    let fromBounds = CGRect(origin: CGPoint(), size: fromRect.size)
                    let toBounds = CGRect(origin: CGPoint(), size: toRect.size)
                    
                    self.foregroundNode.frame = toRect
                    self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: statusValue.generationTimestamp, offset: timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0), forKey: "playback-bounds")
                    self.foregroundNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: CGPoint(x: fromRect.midX, y: fromRect.midY)), to: NSValue(cgPoint: CGPoint(x: toRect.midX, y: toRect.midY)), duration: duration, beginTime: statusValue.generationTimestamp, offset: timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0), forKey: "playback-position")
                    
                    if let handleNodeContainer = self.handleNodeContainer {
                        let fromBounds = bounds
                        let toBounds = bounds.offsetBy(dx: -bounds.size.width, dy: 0.0)
                        
                        handleNodeContainer.isHidden = false
                        handleNodeContainer.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: statusValue.duration, beginTime: statusValue.generationTimestamp, offset: statusValue.timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0), forKey: "playback-bounds")
                    }
                    
                    if let handleNode = self.handleNode {
                        let fromPosition = handleNode.position
                        let toPosition = CGPoint(x: fromPosition.x - 1.0, y: fromPosition.y)
                        handleNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: fromPosition), to: NSValue(cgPoint: toPosition), duration: duration / Double(bounds.size.width), beginTime: statusValue.generationTimestamp, offset: timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0, repeatForever: true), forKey: "playback-position")
                    }
                }
            } else {
                self.handleNodeContainer?.isHidden = true
                self.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
            }
        } else {
            self.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
            self.handleNodeContainer?.isHidden = true
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.handleNodeContainer?.view
        } else {
            return nil
        }
    }
}
