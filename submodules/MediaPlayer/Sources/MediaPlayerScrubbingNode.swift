import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

public enum MediaPlayerScrubbingNodeCap {
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

private final class MediaPlayerScrubbingNodeButton: ASDisplayNode {
    var beginScrubbing: (() -> Void)?
    var endScrubbing: ((Bool) -> Void)?
    var updateScrubbing: ((CGFloat) -> Void)?
    
    private var scrubbingStartLocation: CGPoint?
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        var location = recognizer.location(in: self.view)
        location.x -= self.bounds.minX
        switch recognizer.state {
            case .began:
                self.scrubbingStartLocation = location
                self.beginScrubbing?()
            case .changed:
                if let scrubbingStartLocation = self.scrubbingStartLocation {
                    let delta = location.x - scrubbingStartLocation.x
                    self.updateScrubbing?(delta / self.bounds.size.width)
                }
            case .ended, .cancelled:
                if let scrubbingStartLocation = self.scrubbingStartLocation {
                    self.scrubbingStartLocation = nil
                    let delta = location.x - scrubbingStartLocation.x
                    self.updateScrubbing?(delta / self.bounds.size.width)
                    self.endScrubbing?(recognizer.state == .ended)
                }
            default:
                break
        }
    }
}

private final class MediaPlayerScrubbingForegroundNode: ASDisplayNode {
    var onEnterHierarchy: (() -> Void)?
    var onExitHierarchy: (() -> Void)?
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.onEnterHierarchy?()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.onExitHierarchy?()
    }
}

public enum MediaPlayerScrubbingNodeHandle {
    case none
    case line
    case circle
}

public enum MediaPlayerScrubbingNodeContent {
    case standard(lineHeight: CGFloat, lineCap: MediaPlayerScrubbingNodeCap, scrubberHandle: MediaPlayerScrubbingNodeHandle, backgroundColor: UIColor, foregroundColor: UIColor)
    case custom(backgroundNode: ASDisplayNode, foregroundContentNode: ASDisplayNode)
}

private final class StandardMediaPlayerScrubbingNodeContentNode {
    let lineHeight: CGFloat
    let lineCap: MediaPlayerScrubbingNodeCap
    let backgroundNode: ASImageNode
    let bufferingNode: MediaPlayerScrubbingBufferingNode
    let foregroundContentNode: ASImageNode
    let foregroundNode: MediaPlayerScrubbingForegroundNode
    let handle: MediaPlayerScrubbingNodeHandle
    let handleNode: ASDisplayNode?
    let handleNodeContainer: MediaPlayerScrubbingNodeButton?
    
    init(lineHeight: CGFloat, lineCap: MediaPlayerScrubbingNodeCap, backgroundNode: ASImageNode, bufferingNode: MediaPlayerScrubbingBufferingNode, foregroundContentNode: ASImageNode, foregroundNode: MediaPlayerScrubbingForegroundNode, handle: MediaPlayerScrubbingNodeHandle, handleNode: ASDisplayNode?, handleNodeContainer: MediaPlayerScrubbingNodeButton?) {
        self.lineHeight = lineHeight
        self.lineCap = lineCap
        self.backgroundNode = backgroundNode
        self.bufferingNode = bufferingNode
        self.foregroundContentNode = foregroundContentNode
        self.foregroundNode = foregroundNode
        self.handle = handle
        self.handleNode = handleNode
        self.handleNodeContainer = handleNodeContainer
    }
}

private final class CustomMediaPlayerScrubbingNodeContentNode {
    let backgroundNode: ASDisplayNode
    let foregroundContentNode: ASDisplayNode
    let foregroundNode: MediaPlayerScrubbingForegroundNode
    let handleNodeContainer: MediaPlayerScrubbingNodeButton?
    
    init(backgroundNode: ASDisplayNode, foregroundContentNode: ASDisplayNode, foregroundNode: MediaPlayerScrubbingForegroundNode, handleNodeContainer: MediaPlayerScrubbingNodeButton?) {
        self.backgroundNode = backgroundNode
        self.foregroundContentNode = foregroundContentNode
        self.foregroundNode = foregroundNode
        self.handleNodeContainer = handleNodeContainer
    }
}

private enum MediaPlayerScrubbingNodeContentNodes {
    case standard(StandardMediaPlayerScrubbingNodeContentNode)
    case custom(CustomMediaPlayerScrubbingNodeContentNode)
}

private final class MediaPlayerScrubbingBufferingNode: ASDisplayNode {
    private let color: UIColor
    private let containerNode: ASDisplayNode
    private let foregroundNode: ASImageNode
    
    private var ranges: (IndexSet, Int)?
    
    init(color: UIColor, lineCap: MediaPlayerScrubbingNodeCap, lineHeight: CGFloat) {
        self.color = color
        
        self.containerNode = ASDisplayNode()
        self.containerNode.isLayerBacked = true
        self.containerNode.clipsToBounds = true
        
        self.foregroundNode = ASImageNode()
        self.foregroundNode.isLayerBacked = true
        self.foregroundNode.displayWithoutProcessing = true
        self.foregroundNode.displaysAsynchronously = false
        self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: color)
        
        super.init()
        
        self.containerNode.addSubnode(self.foregroundNode)
        self.addSubnode(self.containerNode)
    }
    
    func updateStatus(_ ranges: IndexSet, _ size: Int) {
        self.ranges = (ranges, size)
        if !self.bounds.width.isZero {
            self.updateLayout(size: self.bounds.size, transition: .animated(duration: 0.15, curve: .easeInOut))
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.rangeView {
                let rangeWidth = min(size.width, (CGFloat(range.count) / CGFloat(ranges.1)) * size.width)
                transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: rangeWidth, height: size.height)))
                break
            }
        } else {
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: 0.0, height: size.height)))
        }
    }
}

public final class MediaPlayerScrubbingNode: ASDisplayNode {
    private var contentNodes: MediaPlayerScrubbingNodeContentNodes
    
    private var displayLink: CADisplayLink?
    private var isInHierarchyValue: Bool = false
    
    private var playbackStatusValue: MediaPlayerPlaybackStatus?
    private var scrubbingBeginTimestamp: Double?
    private var scrubbingTimestampValue: Double?
    
    public var playbackStatusUpdated: ((MediaPlayerPlaybackStatus?) -> Void)?
    public var playerStatusUpdated: ((MediaPlayerStatus?) -> Void)?
    public var seek: ((Double) -> Void)?
    public var update: ((Double?, CGFloat) -> Void)?
    
    private let _scrubbingTimestamp = Promise<Double?>(nil)
    public var scrubbingTimestamp: Signal<Double?, NoError> {
        return self._scrubbingTimestamp.get()
    }
    
    public var ignoreSeekId: Int?
    
    public var enableScrubbing: Bool = true {
        didSet {
            switch self.contentNodes {
                case let .standard(node):
                    node.handleNodeContainer?.isUserInteractionEnabled = self.enableScrubbing
                case let .custom(node):
                    node.handleNodeContainer?.isUserInteractionEnabled = self.enableScrubbing
            }
        }
    }
    
    private var _statusValue: MediaPlayerStatus?
    private var statusValue: MediaPlayerStatus? {
        get {
            return self._statusValue
        } set(value) {
            if value != self._statusValue {
                if let value = value, value.seekId == self.ignoreSeekId {
                } else {
                    self._statusValue = value
                    self.updateProgressAnimations()
                    
                    let playbackStatus = value?.status
                    if self.playbackStatusValue != playbackStatus {
                        self.playbackStatusValue = playbackStatus
                        if let playbackStatusUpdated = self.playbackStatusUpdated {
                            playbackStatusUpdated(playbackStatus)
                        }
                    }
                    
                    self.playerStatusUpdated?(value)
                }
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus?>()
    
    public var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status |> map { $0 })
            } else {
                self.statusValuePromise.set(.single(nil))
            }
        }
    }
    
    private var bufferingStatusDisposable: Disposable?
    private var bufferingStatusValuePromise = Promise<(IndexSet, Int)?>()
    
    public var bufferingStatus: Signal<(IndexSet, Int)?, NoError>? {
        didSet {
            if let bufferingStatus = self.bufferingStatus {
                self.bufferingStatusValuePromise.set(bufferingStatus)
            } else {
                self.bufferingStatusValuePromise.set(.single(nil))
            }
        }
    }
    
    private static func contentNodesFromContent(_ content: MediaPlayerScrubbingNodeContent, enableScrubbing: Bool) -> MediaPlayerScrubbingNodeContentNodes {
        switch content {
            case let .standard(lineHeight, lineCap, scrubberHandle, backgroundColor, foregroundColor):
                let backgroundNode = ASImageNode()
                backgroundNode.isLayerBacked = true
                backgroundNode.displaysAsynchronously = false
                backgroundNode.displayWithoutProcessing = true
                
                let bufferingNode = MediaPlayerScrubbingBufferingNode(color: foregroundColor.withAlphaComponent(0.5), lineCap: lineCap, lineHeight: lineHeight)
                
                let foregroundContentNode = ASImageNode()
                foregroundContentNode.isLayerBacked = true
                foregroundContentNode.displaysAsynchronously = false
                foregroundContentNode.displayWithoutProcessing = true
                
                switch lineCap {
                    case .round:
                        backgroundNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: backgroundColor)
                        foregroundContentNode.image = generateStretchableFilledCircleImage(diameter: lineHeight, color: foregroundColor)
                    case .square:
                        backgroundNode.backgroundColor = backgroundColor
                        foregroundContentNode.backgroundColor = foregroundColor
                }
                
                let foregroundNode = MediaPlayerScrubbingForegroundNode()
                foregroundNode.isLayerBacked = true
                foregroundNode.clipsToBounds = true
                
                var handleNodeImpl: ASImageNode?
                var handleNodeContainerImpl: MediaPlayerScrubbingNodeButton?
                
                switch scrubberHandle {
                    case .none:
                        break
                    case .line:
                        let handleNode = ASImageNode()
                        handleNode.image = generateHandleBackground(color: foregroundColor)
                        handleNode.isLayerBacked = true
                        handleNodeImpl = handleNode
                        
                        let handleNodeContainer = MediaPlayerScrubbingNodeButton()
                        handleNodeContainer.addSubnode(handleNode)
                        handleNodeContainerImpl = handleNodeContainer
                    case .circle:
                        let handleNode = ASImageNode()
                        handleNode.image = generateFilledCircleImage(diameter: lineHeight + 4.0, color: foregroundColor)
                        handleNode.isLayerBacked = true
                        handleNodeImpl = handleNode
                        
                        let handleNodeContainer = MediaPlayerScrubbingNodeButton()
                        handleNodeContainer.addSubnode(handleNode)
                        handleNodeContainerImpl = handleNodeContainer
                }
                
                handleNodeContainerImpl?.isUserInteractionEnabled = enableScrubbing
                
                return .standard(StandardMediaPlayerScrubbingNodeContentNode(lineHeight: lineHeight, lineCap: lineCap, backgroundNode: backgroundNode, bufferingNode: bufferingNode, foregroundContentNode: foregroundContentNode, foregroundNode: foregroundNode, handle: scrubberHandle, handleNode: handleNodeImpl, handleNodeContainer: handleNodeContainerImpl))
            case let .custom(backgroundNode, foregroundContentNode):
                let foregroundNode = MediaPlayerScrubbingForegroundNode()
                foregroundNode.isLayerBacked = true
                foregroundNode.clipsToBounds = true
                
                let handleNodeContainer = MediaPlayerScrubbingNodeButton()
                handleNodeContainer.isUserInteractionEnabled = enableScrubbing
                
                return .custom(CustomMediaPlayerScrubbingNodeContentNode(backgroundNode: backgroundNode, foregroundContentNode: foregroundContentNode, foregroundNode: foregroundNode, handleNodeContainer: handleNodeContainer))
        }
    }
    
    public init(content: MediaPlayerScrubbingNodeContent) {
        self.contentNodes = MediaPlayerScrubbingNode.contentNodesFromContent(content, enableScrubbing: self.enableScrubbing)
        
        super.init()
        
        self.setupContentNodes()
        
        self.statusDisposable = (self.statusValuePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.statusValue = status
            }
        })
        
        self.bufferingStatusDisposable = (self.bufferingStatusValuePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                switch strongSelf.contentNodes {
                    case let .standard(node):
                        if let status = status {
                            node.bufferingNode.updateStatus(status.0, status.1)
                        }
                    case .custom:
                        break
                }
            }
        })
    }
    
    private func setupContentNodes() {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                subnode.removeFromSupernode()
            }
        }
        
        switch self.contentNodes {
            case let .standard(node):
                self.addSubnode(node.backgroundNode)
                self.addSubnode(node.bufferingNode)
                node.foregroundNode.addSubnode(node.foregroundContentNode)
                self.addSubnode(node.foregroundNode)
                
                if let handleNodeContainer = node.handleNodeContainer {
                    self.addSubnode(handleNodeContainer)
                    handleNodeContainer.beginScrubbing = { [weak self] in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingBeginTimestamp = statusValue.timestamp
                                strongSelf.scrubbingTimestampValue = statusValue.timestamp
                                strongSelf._scrubbingTimestamp.set(.single(strongSelf.scrubbingTimestampValue))
                                strongSelf.update?(strongSelf.scrubbingTimestampValue, CGFloat(statusValue.timestamp / statusValue.duration))
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.updateScrubbing = { [weak self] addedFraction in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, let scrubbingBeginTimestamp = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                let timestampValue = max(0.0, min(statusValue.duration, scrubbingBeginTimestamp + statusValue.duration * Double(addedFraction)))
                                strongSelf.scrubbingTimestampValue = timestampValue
                                strongSelf._scrubbingTimestamp.set(.single(strongSelf.scrubbingTimestampValue))
                                strongSelf.update?(timestampValue, CGFloat(timestampValue / statusValue.duration))
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.endScrubbing = { [weak self] apply in
                        if let strongSelf = self {
                            strongSelf.scrubbingBeginTimestamp = nil
                            let scrubbingTimestampValue = strongSelf.scrubbingTimestampValue
                            strongSelf.scrubbingTimestampValue = nil
                            strongSelf._scrubbingTimestamp.set(.single(nil))
                            if let scrubbingTimestampValue = scrubbingTimestampValue, apply {
                                if let statusValue = strongSelf.statusValue {
                                    switch statusValue.status {
                                        case .buffering:
                                            break
                                        default:
                                            strongSelf.ignoreSeekId = statusValue.seekId
                                    }
                                }
                                strongSelf.seek?(scrubbingTimestampValue)
                            }
                            strongSelf.update?(nil, 0.0)
                            strongSelf.updateProgressAnimations()
                        }
                    }
                }
                
                node.foregroundNode.onEnterHierarchy = { [weak self] in
                    self?.isInHierarchyValue = true
                    self?.updateProgressAnimations()
                }
                node.foregroundNode.onExitHierarchy = { [weak self] in
                    self?.isInHierarchyValue = false
                    self?.updateProgressAnimations()
                }
            case let .custom(node):
                self.addSubnode(node.backgroundNode)
                node.foregroundNode.addSubnode(node.foregroundContentNode)
                self.addSubnode(node.foregroundNode)
                
                if let handleNodeContainer = node.handleNodeContainer {
                    self.addSubnode(handleNodeContainer)
                    handleNodeContainer.beginScrubbing = { [weak self] in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingBeginTimestamp = statusValue.timestamp
                                strongSelf.scrubbingTimestampValue = statusValue.timestamp
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.updateScrubbing = { [weak self] addedFraction in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, let scrubbingBeginTimestamp = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingTimestampValue = scrubbingBeginTimestamp + statusValue.duration * Double(addedFraction)
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.endScrubbing = { [weak self] apply in
                        if let strongSelf = self {
                            strongSelf.scrubbingBeginTimestamp = nil
                            let scrubbingTimestampValue = strongSelf.scrubbingTimestampValue
                            strongSelf.scrubbingTimestampValue = nil
                            if let scrubbingTimestampValue = scrubbingTimestampValue, apply {
                                strongSelf.seek?(scrubbingTimestampValue)
                            }
                            strongSelf.updateProgressAnimations()
                        }
                    }
                }
                
                node.foregroundNode.onEnterHierarchy = { [weak self] in
                    self?.isInHierarchyValue = true
                    self?.updateProgressAnimations()
                }
                node.foregroundNode.onExitHierarchy = { [weak self] in
                    self?.isInHierarchyValue = false
                    self?.updateProgressAnimations()
                }
        }
    }
    
    public func updateContent(_ content: MediaPlayerScrubbingNodeContent) {
        self.contentNodes = MediaPlayerScrubbingNode.contentNodesFromContent(content, enableScrubbing: self.enableScrubbing)
        
        self.setupContentNodes()
        
        self.updateProgressAnimations()
    }
    
    deinit {
        self.displayLink?.invalidate()
        self.statusDisposable?.dispose()
        self.bufferingStatusDisposable?.dispose()
    }
    
    override public var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.updateProgressAnimations()
            }
        }
    }
    
    public func updateColors(backgroundColor: UIColor, foregroundColor: UIColor) {
        switch self.contentNodes {
            case let .standard(node):
                switch node.lineCap {
                    case .round:
                        node.backgroundNode.image = generateStretchableFilledCircleImage(diameter: node.lineHeight, color: backgroundColor)
                        node.foregroundContentNode.image = generateStretchableFilledCircleImage(diameter: node.lineHeight, color: foregroundColor)
                    case .square:
                        node.backgroundNode.backgroundColor = backgroundColor
                        node.foregroundContentNode.backgroundColor = foregroundColor
                }
                if let handleNode = node.handleNode as? ASImageNode {
                    handleNode.image = generateHandleBackground(color: foregroundColor)
                }
            case .custom:
                break
        }
    }
    
    private func updateProgressAnimations() {
        self.updateProgress()
        
        let needsAnimation: Bool
        
        if !self.isInHierarchyValue {
            needsAnimation = false
        } else if let _ = scrubbingTimestampValue {
            needsAnimation = false
        } else if let statusValue = self.statusValue {
            if case .buffering(true, _) = statusValue.status {
                needsAnimation = false
            } else if Double(0.0).isLess(than: statusValue.duration) {
                needsAnimation = true
            } else {
                needsAnimation = false
            }
        } else {
            needsAnimation = false
        }
        
        if needsAnimation {
            if self.displayLink == nil {
                class DisplayLinkProxy: NSObject {
                    var f: () -> Void
                    init(_ f: @escaping () -> Void) {
                        self.f = f
                    }
                    
                    @objc func displayLinkEvent() {
                        self.f()
                    }
                }
                let displayLink = CADisplayLink(target: DisplayLinkProxy({ [weak self] in
                    self?.updateProgress()
                }), selector: #selector(DisplayLinkProxy.displayLinkEvent))
                displayLink.add(to: .main, forMode: RunLoop.Mode.common)
                self.displayLink = displayLink
            }
            self.displayLink?.isPaused = false
        } else {
            self.displayLink?.isPaused = true
        }
    }
    
    private func updateProgress() {
        let bounds = self.bounds
        
        var isPlaying = false
        var timestampAndDuration: (timestamp: Double, duration: Double)?
        if let statusValue = self.statusValue {
            switch statusValue.status {
                case .playing:
                    isPlaying = true
                default:
                    break
            }
            if case .buffering(true, _) = statusValue.status {
                //initialBuffering = true
            } else if Double(0.0).isLess(than: statusValue.duration) {
                if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                    timestampAndDuration = (max(0.0, min(scrubbingTimestampValue, statusValue.duration)), statusValue.duration)
                } else {
                    timestampAndDuration = (statusValue.timestamp, statusValue.duration)
                }
            }
        }
        
        switch self.contentNodes {
            case let .standard(node):
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((bounds.size.height - node.lineHeight) / 2.0)), size: CGSize(width: bounds.size.width, height: node.lineHeight))
                node.backgroundNode.frame = backgroundFrame
                node.foregroundContentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                
                node.bufferingNode.frame = backgroundFrame
                node.bufferingNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
                
                if let handleNode = node.handleNode {
                    var handleSize: CGSize = CGSize(width: 2.0, height: bounds.size.height)
                    if case .circle = node.handle, let handleNode = handleNode as? ASImageNode, let image = handleNode.image {
                        handleSize = image.size
                    }
                    handleNode.frame = CGRect(origin: CGPoint(x: -handleSize.width / 2.0, y: floor((bounds.size.height - handleSize.height) / 2.0)), size: handleSize)
                }
                
                if let handleNodeContainer = node.handleNodeContainer {
                    handleNodeContainer.frame = bounds
                }
                
                if let (timestamp, duration) = timestampAndDuration {
                    if let scrubbingTimestampValue = scrubbingTimestampValue {
                        var progress = CGFloat(scrubbingTimestampValue / duration)
                        if progress.isNaN || !progress.isFinite {
                            progress = 0.0
                        }
                        progress = min(1.0, progress)
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progress * backgroundFrame.size.width), height: backgroundFrame.size.height))
                        
                        if let handleNodeContainer = node.handleNodeContainer {
                            handleNodeContainer.bounds = bounds.offsetBy(dx: -floorToScreenPixels(bounds.size.width * progress), dy: 0.0)
                            handleNodeContainer.isHidden = false
                        }
                    } else if let statusValue = self.statusValue {
                        let actualTimestamp: Double
                        if statusValue.generationTimestamp.isZero || !isPlaying {
                            actualTimestamp = timestamp
                        } else {
                            let currentTimestamp = CACurrentMediaTime()
                            actualTimestamp = timestamp + (currentTimestamp - statusValue.generationTimestamp) * statusValue.baseRate
                        }
                        var progress = CGFloat(actualTimestamp / duration)
                        if progress.isNaN || !progress.isFinite {
                            progress = 0.0
                        }
                        progress = min(1.0, progress)
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progress * backgroundFrame.size.width), height: backgroundFrame.size.height))
                        
                        if let handleNodeContainer = node.handleNodeContainer {
                            handleNodeContainer.bounds = bounds.offsetBy(dx: -floorToScreenPixels(bounds.size.width * progress), dy: 0.0)
                            handleNodeContainer.isHidden = false
                        }
                    } else {
                        node.handleNodeContainer?.isHidden = true
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                    }
                } else {
                    node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                    node.handleNodeContainer?.isHidden = true
                }
            case let .custom(node):
                if let handleNodeContainer = node.handleNodeContainer {
                    handleNodeContainer.frame = bounds
                }
                
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: bounds.size.width, height: bounds.size.height))
                node.backgroundNode.frame = backgroundFrame
                node.foregroundContentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                
                let timestampAndDuration: (timestamp: Double, duration: Double)?
                if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                    if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                        timestampAndDuration = (max(0.0, min(scrubbingTimestampValue, statusValue.duration)), statusValue.duration)
                    } else {
                        timestampAndDuration = (statusValue.timestamp, statusValue.duration)
                    }
                } else {
                    timestampAndDuration = nil
                }
                
                if let (timestamp, duration) = timestampAndDuration {
                    if let scrubbingTimestampValue = scrubbingTimestampValue {
                        var progress = CGFloat(scrubbingTimestampValue / duration)
                        if progress.isNaN || !progress.isFinite {
                            progress = 0.0
                        }
                        progress = max(0.0, min(1.0, progress))
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progress * backgroundFrame.size.width), height: backgroundFrame.size.height))
                    } else if let statusValue = self.statusValue {
                        let actualTimestamp: Double
                        if statusValue.generationTimestamp.isZero || !isPlaying {
                            actualTimestamp = timestamp
                        } else {
                            let currentTimestamp = CACurrentMediaTime()
                            actualTimestamp = timestamp + (currentTimestamp - statusValue.generationTimestamp) * statusValue.baseRate
                        }
                        var progress = CGFloat(actualTimestamp / duration)
                        if progress.isNaN || !progress.isFinite {
                            progress = 0.0
                        }
                        progress = max(0.0, min(1.0, progress))
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progress * backgroundFrame.size.width), height: backgroundFrame.size.height))
                    } else {
                        node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                    }
                } else {
                    node.foregroundNode.frame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: 0.0, height: backgroundFrame.size.height))
                }
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch self.contentNodes {
        case let .standard(node):
            if let handleNodeContainer = node.handleNodeContainer, handleNodeContainer.isUserInteractionEnabled, handleNodeContainer.frame.insetBy(dx: 0.0, dy: -5.0).contains(point) {
                return handleNodeContainer.view
            } else {
                return nil
            }
        case let .custom(node):
            if let handleNodeContainer = node.handleNodeContainer, handleNodeContainer.isUserInteractionEnabled, handleNodeContainer.frame.insetBy(dx: 0.0, dy: -5.0).contains(point) {
                return handleNodeContainer.view
            } else {
                return nil
            }
        }
    }
}
