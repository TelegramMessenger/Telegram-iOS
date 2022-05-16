import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import RangeSet

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

public struct MediaPlayerScrubbingChapter: Equatable {
    public let title: String
    public let start: Double
    
    public init(title: String, start: Double) {
        self.title = title
        self.start = start
    }
}

private final class MediaPlayerScrubbingNodeButton: ASDisplayNode, UIGestureRecognizerDelegate {
    var beginScrubbing: (() -> Void)?
    var endScrubbing: ((Bool) -> Void)?
    var updateScrubbing: ((CGFloat, Double) -> Void)?
    var updateMultiplier: ((Double) -> Void)?
    
    var highlighted: ((Bool) -> Void)?
    
    var verticalPanEnabled = false
    private let hapticFeedback = HapticFeedback()
    
    private var scrubbingMultiplier: Double = 1.0
    private var scrubbingStartLocation: CGPoint?
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        gestureRecognizer.delegate = self
        self.view.addGestureRecognizer(gestureRecognizer)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let _ = gestureRecognizer as? UIPanGestureRecognizer else {
            return !self.verticalPanEnabled
        }
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        self.highlighted?(true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if self.scrubbingStartLocation == nil {
            self.highlighted?(false)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        if self.scrubbingStartLocation == nil {
            self.highlighted?(false)
        }
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
                    var multiplier: Double = 1.0
                    var skipUpdate = false
                    if self.verticalPanEnabled, location.y > scrubbingStartLocation.y {
                        let verticalDelta = abs(location.y - scrubbingStartLocation.y)
                        if verticalDelta > 150.0 {
                            multiplier = 0.01
                        } else if verticalDelta > 100.0 {
                            multiplier = 0.25
                        } else if verticalDelta > 50.0 {
                            multiplier = 0.5
                        }
                        if multiplier != self.scrubbingMultiplier {
                            skipUpdate = true
                            self.scrubbingMultiplier = multiplier
                            self.scrubbingStartLocation = CGPoint(x: location.x, y: scrubbingStartLocation.y)
                            self.updateMultiplier?(multiplier)
                            
                            self.hapticFeedback.impact()
                        }
                    }
                    if !skipUpdate {
                        self.updateScrubbing?(delta / self.bounds.size.width, multiplier)
                    }
                }
            case .ended, .cancelled:
                if let scrubbingStartLocation = self.scrubbingStartLocation {
                    self.scrubbingStartLocation = nil
                    let delta = location.x - scrubbingStartLocation.x
                    self.updateScrubbing?(delta / self.bounds.size.width, self.scrubbingMultiplier)
                    self.endScrubbing?(recognizer.state == .ended)
                    self.highlighted?(false)
                    self.scrubbingMultiplier = 1.0
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
    case standard(lineHeight: CGFloat, lineCap: MediaPlayerScrubbingNodeCap, scrubberHandle: MediaPlayerScrubbingNodeHandle, backgroundColor: UIColor, foregroundColor: UIColor, bufferingColor: UIColor, chapters: [MediaPlayerScrubbingChapter])
    case custom(backgroundNode: CustomMediaPlayerScrubbingForegroundNode, foregroundContentNode: CustomMediaPlayerScrubbingForegroundNode)
}

private final class StandardMediaPlayerScrubbingNodeContentNode {
    let lineHeight: CGFloat
    let lineCap: MediaPlayerScrubbingNodeCap
    let containerNode: ASDisplayNode
    let backgroundNode: ASImageNode
    let bufferingNode: MediaPlayerScrubbingBufferingNode
    let foregroundContentNode: ASImageNode
    let foregroundNode: MediaPlayerScrubbingForegroundNode
    let chapterNodesContainer: ASDisplayNode?
    let chapterNodes: [(MediaPlayerScrubbingChapter, ASDisplayNode)]
    let handle: MediaPlayerScrubbingNodeHandle
    let handleNode: ASDisplayNode?
    let highlightedHandleNode: ASDisplayNode?
    let handleNodeContainer: MediaPlayerScrubbingNodeButton?
    
    init(lineHeight: CGFloat, lineCap: MediaPlayerScrubbingNodeCap, containerNode: ASDisplayNode, backgroundNode: ASImageNode, bufferingNode: MediaPlayerScrubbingBufferingNode, foregroundContentNode: ASImageNode, foregroundNode: MediaPlayerScrubbingForegroundNode, chapterNodesContainer: ASDisplayNode?, chapterNodes: [(MediaPlayerScrubbingChapter, ASDisplayNode)], handle: MediaPlayerScrubbingNodeHandle, handleNode: ASDisplayNode?, highlightedHandleNode: ASDisplayNode?, handleNodeContainer: MediaPlayerScrubbingNodeButton?) {
        self.lineHeight = lineHeight
        self.lineCap = lineCap
        self.containerNode = containerNode
        self.backgroundNode = backgroundNode
        self.bufferingNode = bufferingNode
        self.foregroundContentNode = foregroundContentNode
        self.foregroundNode = foregroundNode
        self.chapterNodesContainer = chapterNodesContainer
        self.chapterNodes = chapterNodes
        self.handle = handle
        self.handleNode = handleNode
        self.highlightedHandleNode = highlightedHandleNode
        self.handleNodeContainer = handleNodeContainer
    }
}

public protocol CustomMediaPlayerScrubbingForegroundNode: ASDisplayNode {
    var progress: CGFloat? { get set }
}

private final class CustomMediaPlayerScrubbingNodeContentNode {
    let backgroundNode: CustomMediaPlayerScrubbingForegroundNode
    let foregroundContentNode: CustomMediaPlayerScrubbingForegroundNode
    let foregroundNode: MediaPlayerScrubbingForegroundNode
    let handleNodeContainer: MediaPlayerScrubbingNodeButton?
    
    init(backgroundNode: CustomMediaPlayerScrubbingForegroundNode, foregroundContentNode: CustomMediaPlayerScrubbingForegroundNode, foregroundNode: MediaPlayerScrubbingForegroundNode, handleNodeContainer: MediaPlayerScrubbingNodeButton?) {
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
    
    private var ranges: (RangeSet<Int64>, Int64)?
    
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
    
    func updateStatus(_ ranges: RangeSet<Int64>, _ size: Int64) {
        self.ranges = (ranges, size)
        if !self.bounds.width.isZero {
            self.updateLayout(size: self.bounds.size, transition: .animated(duration: 0.15, curve: .easeInOut))
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.ranges {
                let rangeWidth = min(size.width, (CGFloat(range.count) / CGFloat(ranges.1)) * size.width)
                transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: rangeWidth, height: size.height)))
                transition.updateAlpha(node: self.foregroundNode, alpha: abs(size.width - rangeWidth) < 1.0 ? 0.0 : 1.0)
                break
            }
        } else {
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: 0.0, height: size.height)))
            transition.updateAlpha(node: self.foregroundNode, alpha: 0.0)
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
    
    private let _scrubbingPosition = Promise<Double?>(nil)
    public var scrubbingPosition: Signal<Double?, NoError> {
        return self._scrubbingPosition.get()
    }
    
    public var isScrubbing: Bool {
        return self.scrubbingTimestampValue != nil
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
    
    public var enableFineScrubbing: Bool = false {
        didSet {
            switch self.contentNodes {
                case let .standard(node):
                    node.handleNodeContainer?.verticalPanEnabled = self.enableFineScrubbing
                case let .custom(node):
                    node.handleNodeContainer?.verticalPanEnabled = self.enableFineScrubbing
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
                    let previousStatusValue = self._statusValue
                    self._statusValue = value
                    self.updateProgressAnimations()
                    
                    var playbackStatus = value?.status
                    if self.playbackStatusValue != playbackStatus {
                        self.playbackStatusValue = playbackStatus
                        if let playbackStatusUpdated = self.playbackStatusUpdated {
                            if playbackStatus == .paused, previousStatusValue?.status == .playing, let value = value, value.timestamp > value.duration - 0.1 {
                                playbackStatus = .playing
                            }
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
    private var bufferingStatusValuePromise = Promise<(RangeSet<Int64>, Int64)?>()
    
    public var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError>? {
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
            case let .standard(lineHeight, lineCap, scrubberHandle, backgroundColor, foregroundColor, bufferingColor, chapters):
                let backgroundNode = ASImageNode()
                backgroundNode.isLayerBacked = true
                backgroundNode.displaysAsynchronously = false
                backgroundNode.displayWithoutProcessing = true
                
                let bufferingNode = MediaPlayerScrubbingBufferingNode(color: bufferingColor, lineCap: lineCap, lineHeight: lineHeight)
                
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
                var highlightedHandleNodeImpl: ASImageNode?
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
                        handleNode.image = generateFilledCircleImage(diameter: lineHeight + 3.0, color: foregroundColor)
                        handleNode.isLayerBacked = true
                        handleNodeImpl = handleNode
                        
                        let highlightedHandleNode = ASImageNode()
                        let highlightedHandleImage = generateFilledCircleImage(diameter: lineHeight + 3.0 + 20.0, color: foregroundColor)!
                        highlightedHandleNode.image = highlightedHandleImage
                        highlightedHandleNode.bounds = CGRect(origin: CGPoint(), size: highlightedHandleImage.size)
                        highlightedHandleNode.isLayerBacked = true
                        highlightedHandleNode.transform = CATransform3DMakeScale(0.1875, 0.1875, 1.0)
                        highlightedHandleNodeImpl = highlightedHandleNode
                        
                        let handleNodeContainer = MediaPlayerScrubbingNodeButton()
                        handleNodeContainer.addSubnode(handleNode)
                        handleNodeContainer.addSubnode(highlightedHandleNode)
                        handleNodeContainerImpl = handleNodeContainer
                }
                
                handleNodeContainerImpl?.isUserInteractionEnabled = enableScrubbing
                
                var chapterNodesContainerImpl: ASDisplayNode?
                var chapterNodes: [(MediaPlayerScrubbingChapter, ASDisplayNode)] = []
                
                if !chapters.isEmpty {
                    let chapterNodesContainer = ASDisplayNode()
                    chapterNodesContainer.isUserInteractionEnabled = false
                    chapterNodesContainerImpl = chapterNodesContainer
                    
                    var chapters = chapters
                    if let firstChapter = chapters.first, firstChapter.start > 0.0 {
                        chapters.insert(MediaPlayerScrubbingChapter(title: "", start: 0.0), at: 0)
                    }
                    
                    for i in 0 ..< chapters.count {
                        let chapterNode = ASDisplayNode()
                        chapterNode.backgroundColor = .white
                        chapterNodesContainer.addSubnode(chapterNode)
                        
                        chapterNodes.append((chapters[i], chapterNode))
                    }
                }
                
                return .standard(StandardMediaPlayerScrubbingNodeContentNode(lineHeight: lineHeight, lineCap: lineCap, containerNode: ASDisplayNode(), backgroundNode: backgroundNode, bufferingNode: bufferingNode, foregroundContentNode: foregroundContentNode, foregroundNode: foregroundNode, chapterNodesContainer: chapterNodesContainerImpl, chapterNodes: chapterNodes, handle: scrubberHandle, handleNode: handleNodeImpl, highlightedHandleNode: highlightedHandleNodeImpl, handleNodeContainer: handleNodeContainerImpl))
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
    
    deinit {
        self.displayLink?.invalidate()
        self.statusDisposable?.dispose()
        self.bufferingStatusDisposable?.dispose()
    }
    
    private func setupContentNodes() {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                subnode.removeFromSupernode()
            }
        }
        
        switch self.contentNodes {
            case let .standard(node):
                self.addSubnode(node.containerNode)
                
                node.containerNode.addSubnode(node.backgroundNode)
                node.containerNode.addSubnode(node.bufferingNode)
                node.foregroundNode.addSubnode(node.foregroundContentNode)
                node.containerNode.addSubnode(node.foregroundNode)
                
                if let handleNodeContainer = node.handleNodeContainer {
                    self.addSubnode(handleNodeContainer)
                    handleNodeContainer.highlighted = { [weak self] highlighted in
                        if let strongSelf = self, let highlightedHandleNode = node.highlightedHandleNode, let statusValue = strongSelf.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                            if highlighted {
                                strongSelf.displayLink?.isPaused = true
                                
                                var timestamp = statusValue.timestamp
                                if statusValue.generationTimestamp > 0 && statusValue.status == .playing {
                                    let currentTimestamp = CACurrentMediaTime()
                                    timestamp = timestamp + (currentTimestamp - statusValue.generationTimestamp) * statusValue.baseRate
                                }
                                strongSelf.scrubbingTimestampValue = timestamp
                                strongSelf._scrubbingTimestamp.set(.single(strongSelf.scrubbingTimestampValue))
                                strongSelf._scrubbingPosition.set(.single(strongSelf.scrubbingTimestampValue.flatMap { $0 / statusValue.duration }))
                                
                                highlightedHandleNode.layer.animateSpring(from: 0.1875 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.65, initialVelocity: 0.0, damping: 80.0, removeOnCompletion: false)
                            } else {
                                strongSelf.scrubbingTimestampValue = nil
                                strongSelf._scrubbingTimestamp.set(.single(nil))
                                strongSelf._scrubbingPosition.set(.single(nil))
                                strongSelf.updateProgressAnimations()
                                
                                highlightedHandleNode.layer.animateSpring(from: 1.0 as NSNumber, to: 0.1875 as NSNumber, keyPath: "transform.scale", duration: 0.65, initialVelocity: 0.0, damping: 120.0, removeOnCompletion: false)
                            }
                        }
                    }
                    handleNodeContainer.beginScrubbing = { [weak self] in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingBeginTimestamp = statusValue.timestamp
                                strongSelf.scrubbingTimestampValue = statusValue.timestamp
                                strongSelf._scrubbingTimestamp.set(.single(strongSelf.scrubbingTimestampValue))
                                strongSelf._scrubbingPosition.set(.single(strongSelf.scrubbingTimestampValue.flatMap { $0 / statusValue.duration }))
                                strongSelf.update?(strongSelf.scrubbingTimestampValue, CGFloat(statusValue.timestamp / statusValue.duration))
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.updateScrubbing = { [weak self] addedFraction, multiplier in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, let scrubbingBeginTimestamp = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                let delta: Double = (statusValue.duration * Double(addedFraction)) * multiplier
                                let timestampValue = max(0.0, min(statusValue.duration, scrubbingBeginTimestamp + delta))
                                strongSelf.scrubbingTimestampValue = timestampValue
                                strongSelf._scrubbingTimestamp.set(.single(strongSelf.scrubbingTimestampValue))
                                strongSelf._scrubbingPosition.set(.single(strongSelf.scrubbingTimestampValue.flatMap { $0 / statusValue.duration }))
                                strongSelf.update?(timestampValue, CGFloat(timestampValue / statusValue.duration))
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.updateMultiplier = { [weak self] multiplier in
                           if let strongSelf = self {
                               if let statusValue = strongSelf.statusValue, let _ = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                   strongSelf.scrubbingBeginTimestamp = strongSelf.scrubbingTimestampValue
                               }
                           }
                       }
                    handleNodeContainer.endScrubbing = { [weak self] apply in
                        if let strongSelf = self {
                            strongSelf.scrubbingBeginTimestamp = nil
                            let scrubbingTimestampValue = strongSelf.scrubbingTimestampValue
                            Queue.mainQueue().after(0.05, {
                                strongSelf._scrubbingTimestamp.set(.single(nil))
                                strongSelf._scrubbingPosition.set(.single(nil))
                                strongSelf.scrubbingTimestampValue = nil
                            })
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
                    handleNodeContainer.updateScrubbing = { [weak self] addedFraction, multiplier in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, let scrubbingBeginTimestamp = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingTimestampValue = scrubbingBeginTimestamp + (statusValue.duration * Double(addedFraction)) * multiplier
                                strongSelf.updateProgressAnimations()
                            }
                        }
                    }
                    handleNodeContainer.updateMultiplier = { [weak self] multiplier in
                        if let strongSelf = self {
                            if let statusValue = strongSelf.statusValue, let _ = strongSelf.scrubbingBeginTimestamp, Double(0.0).isLess(than: statusValue.duration) {
                                strongSelf.scrubbingBeginTimestamp = strongSelf.scrubbingTimestampValue
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
    
    public func setCollapsed(_ collapsed: Bool, animated: Bool) {
        let alpha: CGFloat = collapsed ? 0.0 : 1.0
        let backgroundScale: CGFloat = collapsed ? 0.4 : 1.0
        let handleScale: CGFloat = collapsed ? 0.2 : 1.0
        switch self.contentNodes {
            case let .standard(node):
                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
                node.foregroundContentNode.backgroundColor = collapsed ? .white : nil
                
                if let handleNode = node.handleNodeContainer {
                    transition.updateAlpha(node: node.foregroundContentNode, alpha: collapsed ? 0.45 : 1.0)
                    transition.updateAlpha(node: handleNode, alpha: collapsed ? 0.0 : 1.0)
                    transition.updateTransformScale(node: handleNode, scale: CGPoint(x: 1.0, y: handleScale))
                }
                transition.updateAlpha(node: node.bufferingNode, alpha: alpha)
                transition.updateAlpha(node: node.backgroundNode, alpha: alpha)
                transition.updateTransformScale(node: node.foregroundContentNode, scale: CGPoint(x: 1.0, y: backgroundScale))
                transition.updateTransformScale(node: node.backgroundNode, scale: CGPoint(x: 1.0, y: backgroundScale))
            case .custom:
                break
        }
    }
    
    override public var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.updateProgressAnimations()
            }
        }
    }
    
    public func update(size: CGSize, animator: ControlledTransitionAnimator) {
        self.updateProgressAnimations(animator: animator)
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
                    switch node.handle {
                        case .line:
                            handleNode.image = generateHandleBackground(color: foregroundColor)
                        case .circle:
                            handleNode.image = generateFilledCircleImage(diameter: node.lineHeight + 3.0, color: foregroundColor)
                        case .none:
                            break
                    }
                }
            case .custom:
                break
        }
    }
    
    private func updateProgressAnimations(animator: ControlledTransitionAnimator? = nil) {
        self.updateProgress(animator: animator)
        
        let needsAnimation: Bool
        
        if !self.isInHierarchyValue {
            needsAnimation = false
        } else if let _ = self.scrubbingTimestampValue {
            needsAnimation = false
        } else if let statusValue = self.statusValue {
            switch statusValue.status {
            case .buffering:
                needsAnimation = false
            case .paused:
                needsAnimation = false
            case .playing:
                needsAnimation = true
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
    
    private var animateToValue: Double?
    private var animating = false
    public func animateTo(_ timestamp: Double) {
        self.animateToValue = timestamp
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut, .allowAnimatedContent, .layoutSubviews], animations: {
            self.updateProgress()
        }, completion: { _ in
            self.animateToValue = nil
            self.animating = false
        })
    }
    
    private func updateProgress(animator: ControlledTransitionAnimator? = nil) {
        let bounds = self.bounds
        
        var isPlaying = false
        var timestampAndDuration: (timestamp: Double?, duration: Double)?
        if let statusValue = self.statusValue {
            switch statusValue.status {
                case .playing:
                    isPlaying = true
                default:
                    break
            }
            if case .buffering(true, _, _, _) = statusValue.status {
                timestampAndDuration = (nil, statusValue.duration)
                //initialBuffering = true
            } else if Double(0.0).isLess(than: statusValue.duration) {
                if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                    timestampAndDuration = (max(0.0, min(scrubbingTimestampValue, statusValue.duration)), statusValue.duration)
                } else {
                    timestampAndDuration = (statusValue.timestamp, statusValue.duration)
                }
            }
        }
        
        if let animateToValue = self.animateToValue {
            if self.animating {
                return
            } else if let (_, duration) = timestampAndDuration {
                self.animating = true
                timestampAndDuration = (animateToValue, duration)
            }
        }
        
        switch self.contentNodes {
            case let .standard(node):
                node.containerNode.frame = CGRect(origin: CGPoint(), size: bounds.size)
            
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((bounds.size.height - node.lineHeight) / 2.0)), size: CGSize(width: bounds.size.width, height: node.lineHeight))
                let foregroundContentFrame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
            
                node.backgroundNode.position = backgroundFrame.center
                node.backgroundNode.bounds = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                
                node.foregroundContentNode.position = foregroundContentFrame.center
                node.foregroundContentNode.bounds = CGRect(origin: CGPoint(), size: foregroundContentFrame.size)
                
                node.bufferingNode.frame = backgroundFrame
                node.bufferingNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
                
                if let chapterNodesContainer = node.chapterNodesContainer {
                    if let duration = timestampAndDuration?.duration, duration > 1.0, backgroundFrame.width > 0.0, node.chapterNodes.count > 1 {
                        if node.containerNode.view.mask == nil {
                            node.containerNode.view.mask = chapterNodesContainer.view
                            
                            let transitionView = UIView()
                            transitionView.backgroundColor = .white
                            transitionView.frame = node.containerNode.bounds
                            chapterNodesContainer.view.addSubview(transitionView)
                            transitionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionView] _ in
                                transitionView?.removeFromSuperview()
                            })
                        }
                        
                        chapterNodesContainer.frame = backgroundFrame
                        
                        var addedBeginning = false
                        for i in 1 ..< node.chapterNodes.count {
                            let (previousChapter, previousChapterNode) = node.chapterNodes[i - 1]
                            let (chapter, chapterNode) = node.chapterNodes[i]
                            
                            let lineWidth: CGFloat = 1.0 + UIScreenPixel * 2.0
                            let startPosition: CGFloat
                            if !addedBeginning {
                                startPosition = 0.0
                            } else {
                                startPosition = floor(backgroundFrame.width * CGFloat(previousChapter.start / duration)) + lineWidth / 2.0
                            }
                            let endPosition: CGFloat = max(startPosition, floor(backgroundFrame.width * CGFloat(chapter.start / duration)) - lineWidth / 2.0)
                            let width = endPosition - startPosition
                            if width < lineWidth * 2.0 {
                                previousChapterNode.frame = CGRect()
                                continue
                            }
                            previousChapterNode.frame = CGRect(x: startPosition, y: 0.0, width: endPosition - startPosition, height: backgroundFrame.size.height)
                            
                            addedBeginning = true
                            
                            if i == node.chapterNodes.count - 1 {
                                let startPosition = endPosition + lineWidth
                                chapterNode.frame = CGRect(x: startPosition, y: 0.0, width: backgroundFrame.size.width - startPosition, height: backgroundFrame.size.height)
                            }
                        }
                    } else {
                        node.containerNode.view.mask = nil
                    }
                }
                
                if let handleNode = node.handleNode {
                    var handleSize: CGSize = CGSize(width: 2.0, height: bounds.size.height)
                    var handleOffset: CGFloat = 0.0
                    if case .circle = node.handle, let handleNode = handleNode as? ASImageNode, let image = handleNode.image {
                        handleSize = image.size
                        handleOffset = -1.0 + UIScreenPixel
                    }
                    handleNode.frame = CGRect(origin: CGPoint(x: -handleSize.width / 2.0, y: floor((bounds.size.height - handleSize.height) / 2.0) + handleOffset), size: handleSize)
                    
                    if let highlightedHandleNode = node.highlightedHandleNode {
                        highlightedHandleNode.position = handleNode.position
                    }
                }
                
                if let handleNodeContainer = node.handleNodeContainer {
                    handleNodeContainer.frame = bounds
                }
                
                if let (maybeTimestamp, duration) = timestampAndDuration, let timestamp = maybeTimestamp, duration > 0.01 {
                    if let scrubbingTimestampValue = self.scrubbingTimestampValue {
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
                        var actualTimestamp: Double
                        if statusValue.generationTimestamp.isZero || !isPlaying || self.animateToValue != nil {
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
                        
                        let foregroundFrame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progress * backgroundFrame.size.width), height: backgroundFrame.size.height))
                        if let _ = self.animateToValue {
                            let previousFrame = node.foregroundNode.frame
                            node.foregroundNode.frame = foregroundFrame
                            node.foregroundNode.layer.animateFrame(from: previousFrame, to: foregroundFrame, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                        } else {
                            node.foregroundNode.frame = foregroundFrame
                        }
                        
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
            
                if let animator = animator {
                    animator.updateFrame(layer: node.backgroundNode.layer, frame: backgroundFrame, completion: nil)
                    animator.updateFrame(layer: node.foregroundContentNode.layer, frame: CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height)), completion: nil)
                } else {
                    node.backgroundNode.frame = backgroundFrame
                    node.foregroundContentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundFrame.size.width, height: backgroundFrame.size.height))
                }
                
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
                    if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                        var progress = CGFloat(scrubbingTimestampValue / duration)
                        if progress.isNaN || !progress.isFinite {
                            progress = 0.0
                        }
                        progress = max(0.0, min(1.0, progress))
                        node.backgroundNode.progress = nil
                        node.foregroundContentNode.progress = nil
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
                        node.backgroundNode.progress = progress
                        node.foregroundContentNode.progress = progress
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
            if let handleNodeContainer = node.handleNodeContainer, handleNodeContainer.isUserInteractionEnabled, handleNodeContainer.frame.insetBy(dx: 0.0, dy: -16.0).contains(point) {
                if let handleNode = node.handleNode, handleNode.convert(handleNode.bounds, to: self).insetBy(dx: -32.0, dy: -16.0).contains(point) {
                    return handleNodeContainer.view
                } else {
                    return nil
                }
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
