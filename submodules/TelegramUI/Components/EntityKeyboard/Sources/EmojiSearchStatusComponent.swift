import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import AsyncDisplayKit
import ComponentDisplayAdapters
import LottieAnimationComponent
import EmojiStatusComponent
import LottieComponent
import AudioToolbox
import SwiftSignalKit
import GZip
import RLottieBinding
import AppBundle
import Lottie

private final class LottieDirectContent: LottieComponent.Content {
    let path: String
    
    init(path: String) {
        self.path = path
    }
    
    override var frameRange: Range<Double> {
        return 0.0 ..< 1.0
    }
    
    override func isEqual(to other: LottieComponent.Content) -> Bool {
        guard let other = other as? LottieDirectContent else {
            return false
        }
        if self.path != other.path {
            return false
        }
        
        return true
    }
    
    override func load(_ f: @escaping (Data, String?) -> Void) -> Disposable {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.path)) {
            let result = TGGUnzipData(data, 2 * 1024 * 1024) ?? data
            f(result, nil)
        }
        
        return EmptyDisposable
    }
}

private protocol EmojiSearchStatusAnimationState {
    var content: EmojiSearchStatusComponent.ContentState { get }
    var image: UIImage? { get }
    var isCompleted: Bool { get }
    
    func advanceIfNeeded()
    func updateImage()
}

final class EmojiSearchStatusComponent: Component {
    enum Content: Equatable {
        case search
        case progress
        case results
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let useOpaqueTheme: Bool
    let content: Content

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        useOpaqueTheme: Bool,
        content: Content
    ) {
        self.theme = theme
        self.strings = strings
        self.useOpaqueTheme = useOpaqueTheme
        self.content = content
    }
    
    static func ==(lhs: EmojiSearchStatusComponent, rhs: EmojiSearchStatusComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.useOpaqueTheme != rhs.useOpaqueTheme {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    fileprivate enum ContentState {
        case search
        case searchToProgress
        case progress
        case results
        
        init(content: Content) {
            switch content {
            case .search:
                self = .search
            case .progress:
                self = .progress
            case .results:
                self = .results
            }
        }
        
        var content: Content {
            switch self {
            case .search:
                return .search
            case .searchToProgress, .progress:
                return .progress
            case .results:
                return .results
            }
        }
        
        var automaticNextState: ContentState? {
            switch self {
            case .searchToProgress:
                return .progress
            default:
                return nil
            }
        }
    }
    
    private final class LottieAnimationState: EmojiSearchStatusAnimationState {
        let content: ContentState
        
        private let animationInstance: LottieInstance
        
        private var currentFrameStartTime: Double?
        private var currentFrame: Int = 0
        private let frameRange: ClosedRange<Int>?
        private(set) var image: UIImage?
        
        private(set) var previousAnimationState: EmojiSearchStatusAnimationState?
        
        private(set) var isCompleted: Bool = false
        
        var displaySize: CGSize {
            didSet {
                if self.displaySize != oldValue {
                    self.image = nil
                }
            }
        }
        
        init?(content: ContentState, data: Data, displaySize: CGSize, frameRange: ClosedRange<Int>?, previousAnimationState: EmojiSearchStatusAnimationState?) {
            guard let animationInstance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
                return nil
            }
            self.content = content
            self.animationInstance = animationInstance
            self.displaySize = displaySize
            self.frameRange = frameRange
            self.previousAnimationState = previousAnimationState
            
            if let frameRange {
                self.currentFrame = frameRange.lowerBound
            }
        }
        
        func advanceIfNeeded() {
            if let previousAnimationState = self.previousAnimationState {
                previousAnimationState.advanceIfNeeded()
                if previousAnimationState.isCompleted {
                    self.previousAnimationState = nil
                }
                if previousAnimationState.image == nil {
                    self.image = nil
                }
            }
            
            if self.isCompleted {
                return
            }
            
            if let frameRange = self.frameRange {
                if frameRange.lowerBound == frameRange.upperBound {
                    self.isCompleted = true
                    return
                }
            }
            
            let timestamp = CACurrentMediaTime()
            
            guard let currentFrameStartTime = self.currentFrameStartTime else {
                currentFrameStartTime = timestamp
                return
            }
            
            let secondsPerFrame: Double
            if animationInstance.frameRate == 0 {
                secondsPerFrame = 1.0 / 60.0
            } else {
                secondsPerFrame = 1.0 / Double(animationInstance.frameRate)
            }
            
            if currentFrameStartTime + secondsPerFrame * 0.9 <= timestamp {
                self.currentFrame += 1
                let maxFrame: Int
                if let frameRange = self.frameRange {
                    maxFrame = frameRange.upperBound
                } else {
                    maxFrame = Int(animationInstance.frameCount) - 1
                }
                if self.currentFrame >= maxFrame {
                    self.currentFrame = maxFrame
                    self.isCompleted = true
                } else {
                    self.currentFrameStartTime = timestamp
                    self.image = nil
                }
            }
        }
        
        func updateImage() {
            guard let frameContext = DrawingContext(size: self.displaySize, scale: 1.0, opaque: false, clear: true) else {
                return
            }
            
            self.animationInstance.renderFrame(with: Int32(self.currentFrame % Int(self.animationInstance.frameCount)), into: frameContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(self.displaySize.width), height: Int32(self.displaySize.height), bytesPerRow: Int32(frameContext.bytesPerRow))
            
            if let previousAnimationState = self.previousAnimationState as? ProgressAnimationState {
                guard let context = DrawingContext(size: self.displaySize, scale: 1.0, opaque: false, clear: true) else {
                    return
                }
                
                if previousAnimationState.image == nil {
                    previousAnimationState.updateImage()
                }
                if let frameImage = frameContext.generateImage()?.cgImage, let cgImage = previousAnimationState.image?.cgImage {
                    context.withFlippedContext { c in
                        c.draw(cgImage, in: CGRect(origin: CGPoint(), size: context.size))
                        
                        c.translateBy(x: self.displaySize.width * 0.5, y: self.displaySize.height * 0.5)
                        c.rotate(by: previousAnimationState.currentRotationAngle.truncatingRemainder(dividingBy: CGFloat.pi * 2.0))
                        c.translateBy(x: -self.displaySize.width * 0.5, y: -self.displaySize.height * 0.5)
                        
                        c.draw(frameImage, in: CGRect(origin: CGPoint(), size: context.size))
                    }
                }
                
                self.image = context.generateImage()?.withRenderingMode(.alwaysTemplate)
            } else {
                self.image = frameContext.generateImage()?.withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    private final class ProgressAnimationState: EmojiSearchStatusAnimationState {
        let content: ContentState
        
        private var currentFrameStartTime: Double?
        private var currentOffset: CGFloat
        private(set) var currentRotationAngle: CGFloat
        
        private var lastStageStartOffset: CGFloat?
        private var lastStageRotationAngle: CGFloat?
        
        private(set) var image: UIImage?
        
        var shouldComplete: Bool = false {
            didSet {
                if self.shouldComplete != oldValue && self.shouldComplete {
                    self.lastStageStartOffset = self.currentOffset
                    self.currentRotationAngle = self.currentRotationAngle.truncatingRemainder(dividingBy: CGFloat.pi * 2.0)
                    self.lastStageRotationAngle = self.currentRotationAngle
                }
            }
        }
        private(set) var isCompleted: Bool = false
        
        var displaySize: CGSize {
            didSet {
                if self.displaySize != oldValue {
                    self.image = nil
                }
            }
        }
        
        init(content: ContentState, displaySize: CGSize) {
            self.content = content
            self.displaySize = displaySize
            self.currentOffset = 0.0
            self.currentRotationAngle = 0.0
        }
        
        func advanceIfNeeded() {
            if self.isCompleted {
                return
            }
            
            let timestamp = CACurrentMediaTime()
            
            guard let currentFrameStartTime = self.currentFrameStartTime else {
                currentFrameStartTime = timestamp
                return
            }
            
            let secondsPerFrame: Double = 1.0 / 60.0
            let offsetVelocity: CGFloat = CGFloat.pi * 3.0
            let maxOffset: CGFloat = CGFloat.pi * 2.0 - CGFloat.pi * 1.0 / 1.4
            
            let rotationVelocity: CGFloat = CGFloat.pi * 3.0 * 1.0
            
            if currentFrameStartTime + secondsPerFrame * 0.9 <= timestamp {
                if let lastStageStartOffset = self.lastStageStartOffset {
                    let lastStageRemainingOffset: CGFloat = CGFloat.pi * 2.0 - lastStageStartOffset
                    let lastStageRemainingVelocity: CGFloat = lastStageRemainingOffset / 9.0 * 60.0
                    self.currentOffset = min(CGFloat.pi * 2.0, self.currentOffset + lastStageRemainingVelocity * secondsPerFrame)
                } else if self.shouldComplete {
                    self.currentOffset = min(CGFloat.pi * 2.0, self.currentOffset + offsetVelocity * secondsPerFrame)
                    if self.currentOffset == CGFloat.pi * 2.0 {
                        self.isCompleted = true
                    }
                } else {
                    self.currentOffset = min(maxOffset, self.currentOffset + offsetVelocity * secondsPerFrame)
                }
                if let lastStageRotationAngle = self.lastStageRotationAngle {
                    let _ = lastStageRotationAngle
                    /*let lastStageRemainingAngle: CGFloat = CGFloat.pi * 2.0 + lastStageRotationAngle
                    let lastStageRemainingAngleVelocity: CGFloat = lastStageRemainingAngle / 12.0 * 60.0
                    self.currentRotationAngle = max(-CGFloat.pi * 2.0, self.currentRotationAngle - lastStageRemainingAngleVelocity * secondsPerFrame)*/
                    self.currentRotationAngle = max(-CGFloat.pi * 2.0, self.currentRotationAngle - rotationVelocity * secondsPerFrame)
                } else {
                    self.currentRotationAngle -= rotationVelocity * secondsPerFrame
                }
                
                if self.lastStageStartOffset != nil && self.lastStageRotationAngle != nil {
                    if self.currentOffset == CGFloat.pi * 2.0 && self.currentRotationAngle == -CGFloat.pi * 2.0 {
                        self.isCompleted = true
                    }
                }
                
                self.currentFrameStartTime = timestamp
                self.image = nil
            }
        }
        
        func updateImage() {
            guard let context = DrawingContext(size: self.displaySize, scale: 1.0, opaque: false, clear: true) else {
                return
            }
            
            context.withFlippedContext { c in
                c.setStrokeColor(UIColor.white.cgColor)
                c.setLineCap(.round)
                
                let lineWidth: CGFloat = 1.33 * UIScreenScale
                let fullDiameter = 20.0 * UIScreenScale
                
                c.setLineWidth(lineWidth)
                
                let startAngle: CGFloat = 0.0
                let endAngle: CGFloat = startAngle + (CGFloat.pi * 2.0 - self.currentOffset.truncatingRemainder(dividingBy: CGFloat.pi * 2.0))
                
                c.translateBy(x: self.displaySize.width * 0.5, y: self.displaySize.height * 0.5)
                c.rotate(by: self.currentRotationAngle.truncatingRemainder(dividingBy: CGFloat.pi * 2.0))
                c.translateBy(x: -self.displaySize.width * 0.5, y: -self.displaySize.height * 0.5)
                
                if self.currentOffset != CGFloat.pi * 2.0 {
                    c.addArc(center: CGPoint(x: self.displaySize.width * 0.5, y: self.displaySize.height * 0.5), radius: fullDiameter * 0.5 - lineWidth, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    c.strokePath()
                }
            }
            self.image = context.generateImage()?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    final class View: UIView {
        private var component: EmojiSearchStatusComponent?
        
        private var disappearingAnimationStates: [(UIImageView, UIImageView, EmojiSearchStatusAnimationState)] = []
        
        private var currentAnimationState: EmojiSearchStatusAnimationState?
        private var pendingContent: Content?
        
        private var displaySize: CGSize?
        private var displayLink: SharedDisplayLinkDriver.Link?
        
        public let contentView: UIImageView
        public let tintContainerView: UIView
        public let tintContentView: UIImageView

        override init(frame: CGRect) {
            self.contentView = UIImageView()
            self.tintContainerView = UIView()
            self.tintContentView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            
            self.tintContainerView.isUserInteractionEnabled = false
            self.tintContainerView.addSubview(self.tintContentView)
            
            //self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
            }
        }
        
        func update(component: EmojiSearchStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let displaySize = CGSize(width: availableSize.width * UIScreenScale, height: availableSize.height * UIScreenScale)
            self.displaySize = displaySize
            
            let overlayColor = component.useOpaqueTheme ? component.theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor : component.theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
            let baseColor: UIColor = .white
            
            if self.contentView.tintColor != overlayColor {
                self.contentView.tintColor = overlayColor
            }
            if self.tintContentView.tintColor != baseColor {
                self.tintContentView.tintColor = baseColor
            }
            
            let currentTargetContent = self.pendingContent ?? self.currentAnimationState?.content.content
            if component.content != currentTargetContent {
                var canSwitchNow = false
                if let currentAnimationState = self.currentAnimationState {
                    if currentAnimationState.isCompleted {
                        canSwitchNow = true
                    } else if let _ = currentAnimationState as? ProgressAnimationState {
                        canSwitchNow = true
                    }
                } else {
                    canSwitchNow = true
                }
                
                if canSwitchNow {
                    /*if let currentAnimationState = self.currentAnimationState, case .search = currentAnimationState.content, case .progress = component.content {
                        self.switchToContent(content: .searchToProgress)
                    } else {*/
                        self.switchToContent(content: ContentState(content: component.content))
                    //}
                } else {
                    self.pendingContent = component.content
                }
            }
            
            self.updateAnimation()
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.tintContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            return availableSize
        }
        
        private func switchToContent(content: ContentState) {
            guard let displaySize = self.displaySize else {
                return
            }
            
            enum FrameRangeValue {
                case index(Int)
                case marker(String)
                case end
            }
            
            var name: String?
            var isJson = false
            var frameRange: (FrameRangeValue, FrameRangeValue)?
            var manualTransition = false
            var previousAnimationState: EmojiSearchStatusAnimationState?
            previousAnimationState = nil
            
            let manualPreviousState = self.currentAnimationState
            
            if let currentAnimationState = self.currentAnimationState {
                switch currentAnimationState.content {
                case .search:
                    switch content {
                    case .search:
                        name = "emoji_search_to_arrow"
                        frameRange = (.index(0), .index(0))
                    case .searchToProgress:
                        name = "emoji_search_to_progress"
                        isJson = true
                        //frameRange = (.index(0), .marker("{\r\"name\":\"Search to Progress\"\r}"))
                        frameRange = (.index(0), .index(7))
                    case .progress:
                        manualTransition = true
                        break
                    case .results:
                        name = "emoji_search_to_arrow"
                    }
                case .searchToProgress:
                    switch content {
                    case .search:
                        manualTransition = true
                        name = "emoji_search_to_arrow"
                        frameRange = (.index(0), .index(0))
                    case .searchToProgress:
                        break
                    case .progress:
                        break
                    case .results:
                        manualTransition = true
                        name = "emoji_arrow_to_search"
                        frameRange = (.index(0), .index(0))
                    }
                case .progress:
                    switch content {
                    case .search:
                        manualTransition = true
                        name = "emoji_search_to_arrow"
                        frameRange = (.index(0), .index(0))
                    case .searchToProgress:
                        break
                    case .progress:
                        break
                    case .results:
                        manualTransition = true
                        name = "emoji_arrow_to_search"
                        frameRange = (.index(0), .index(0))
                    }
                    /*switch content {
                    case .search:
                        manualTransition = true
                        name = "emoji_search_to_arrow"
                        frameRange = (.index(0), .index(0))
                    case .searchToProgress:
                        name = "emoji_search_to_progress"
                        isJson = true
                    case .progress:
                        break
                    case .results:
                        name = "emoji_search_to_progress"
                        isJson = true
                        //frameRange = (.marker("{\n\"name\":\"Progress to Arrow\"\n}"), .end)
                        frameRange = (.index(87), .end)
                        
                        previousAnimationState = currentAnimationState
                        (currentAnimationState as? ProgressAnimationState)?.shouldComplete = true
                        
                        /*name = "emoji_arrow_to_search"
                        frameRange = (.index(0), .index(0))*/
                    }*/
                case .results:
                    switch content {
                    case .search:
                        name = "emoji_arrow_to_search"
                    case .searchToProgress:
                        name = "emoji_search_to_progress"
                        isJson = true
                    case .progress:
                        manualTransition = true
                    case .results:
                        name = "emoji_arrow_to_search"
                        frameRange = (.index(0), .index(0))
                    }
                }
            } else {
                switch content {
                case .search:
                    name = "emoji_search_to_arrow"
                    frameRange = (.index(0), .index(0))
                case .searchToProgress:
                    name = "emoji_search_to_progress"
                    isJson = true
                case .progress:
                    break
                case .results:
                    name = "emoji_arrow_to_search"
                    frameRange = (.index(0), .index(0))
                }
            }
            
            if manualTransition, let manualPreviousState {
                let tempImageView = UIImageView()
                tempImageView.image = self.contentView.image
                tempImageView.frame = self.contentView.frame
                tempImageView.tintColor = self.contentView.tintColor
                self.contentView.superview?.insertSubview(tempImageView, aboveSubview: self.contentView)
                
                let tempTintImageView = UIImageView()
                tempTintImageView.image = self.tintContentView.image
                tempTintImageView.frame = self.tintContentView.frame
                tempTintImageView.tintColor = self.tintContentView.tintColor
                self.tintContentView.superview?.insertSubview(tempTintImageView, aboveSubview: self.tintContentView)
                
                self.disappearingAnimationStates.append((tempImageView, tempTintImageView, manualPreviousState))
                
                let minScale: CGFloat = 0.6
                
                tempImageView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak self, weak tempImageView] _ in
                    if let self, let tempImageView {
                        tempImageView.removeFromSuperview()
                        self.disappearingAnimationStates.removeAll(where: { $0.0 === tempImageView })
                    }
                })
                tempImageView.layer.animateScale(from: 1.0, to: minScale, duration: 0.18, removeOnCompletion: false)
                tempTintImageView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak self, weak tempTintImageView] _ in
                    if let self, let tempTintImageView {
                        tempImageView.removeFromSuperview()
                        self.disappearingAnimationStates.removeAll(where: { $0.1 === tempTintImageView })
                    }
                })
                tempTintImageView.layer.animateScale(from: 1.0, to: minScale, duration: 0.18, removeOnCompletion: false)
                
                self.contentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                self.contentView.layer.animateScale(from: minScale, to: 1.0, duration: 0.18)
                self.tintContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                self.tintContentView.layer.animateScale(from: minScale, to: 1.0, duration: 0.18)
            }
            
            if case .progress = content {
                self.currentAnimationState = ProgressAnimationState(content: content, displaySize: displaySize)
            } else if let name, let data = getAppBundle().path(forResource: name, ofType: isJson ? "json" : "tgs").flatMap({
                return try? Data(contentsOf: URL(fileURLWithPath: $0))
            }).flatMap({ data -> Data in
                if isJson {
                    return data
                }
                return TGGUnzipData(data, 2 * 1024 * 1024) ?? data
            }) {
                var resolvedFrameRange: ClosedRange<Int>?
                if let frameRange {
                    var hasMarkers = false
                    
                    if case .marker = frameRange.0 {
                        hasMarkers = true
                    }
                    if case .marker = frameRange.1 {
                        hasMarkers = true
                    }
                    if case .end = frameRange.0 {
                        hasMarkers = true
                    }
                    if case .end = frameRange.1 {
                        hasMarkers = true
                    }
                    
                    var resolvedLowerBound: Int = 0
                    var resolvedUpperBound: Int = 0
                    
                    if case let .index(index) = frameRange.0 {
                        resolvedLowerBound = index
                    }
                    if case let .index(index) = frameRange.1 {
                        resolvedUpperBound = index
                    }
                    
                    if hasMarkers, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let animation = try? Animation(dictionary: json) {
                        let numFrames = animation.endFrame - animation.startFrame
                        
                        if case let .marker(markerName) = frameRange.0 {
                            if let value = animation.progressTime(forMarker: markerName) {
                                resolvedLowerBound = Int(value * numFrames)
                            }
                        }
                        if case .end = frameRange.0 {
                            resolvedLowerBound = Int(numFrames) - 1
                        }
                        if case let .marker(markerName) = frameRange.1 {
                            if let value = animation.progressTime(forMarker: markerName) {
                                resolvedUpperBound = Int(round(value * numFrames))
                            }
                        }
                        if case .end = frameRange.1 {
                            resolvedUpperBound = Int(numFrames) - 1
                        }
                    }
                    
                    resolvedFrameRange = resolvedLowerBound ... max(resolvedLowerBound, resolvedUpperBound)
                }
                
                self.currentAnimationState = LottieAnimationState(content: content, data: data, displaySize: displaySize, frameRange: resolvedFrameRange, previousAnimationState: previousAnimationState)
            } else {
                self.currentAnimationState = nil
            }
        }
        
        private func updateAnimation() {
            var needsAnimation = false
            
            for (tempView, tempTintView, animationState) in self.disappearingAnimationStates {
                animationState.advanceIfNeeded()
                if animationState.image == nil {
                    animationState.updateImage()
                }
                tempView.image = animationState.image
                tempTintView.image = animationState.image
                
                needsAnimation = true
            }
            
            while true {
                if let currentAnimationState = self.currentAnimationState {
                    if self.pendingContent != nil, let currentAnimationState = currentAnimationState as? ProgressAnimationState {
                        currentAnimationState.shouldComplete = true
                    }
                    
                    currentAnimationState.advanceIfNeeded()
                    
                    if currentAnimationState.image == nil {
                        currentAnimationState.updateImage()
                    }
                    
                    if let previousAnimationState = (currentAnimationState as? LottieAnimationState)?.previousAnimationState, !previousAnimationState.isCompleted {
                        needsAnimation = true
                    }
                    
                    if currentAnimationState.isCompleted {
                        if self.pendingContent == nil, let automaticNextState = currentAnimationState.content.automaticNextState {
                            self.switchToContent(content: automaticNextState)
                        } else if let pendingContent = self.pendingContent {
                            self.pendingContent = nil
                            self.switchToContent(content: ContentState(content: pendingContent))
                        } else {
                            break
                        }
                    } else {
                        needsAnimation = true
                        break
                    }
                } else {
                    break
                }
            }
            
            if let currentAnimationState = self.currentAnimationState {
                if currentAnimationState.image == nil {
                    currentAnimationState.updateImage()
                }
                
                if let image = currentAnimationState.image {
                    self.contentView.image = image
                    self.tintContentView.image = image
                }
            }
            
            if needsAnimation {
                if self.displayLink == nil {
                    var counter = 0
                    self.displayLink = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: false, { [weak self] in
                        counter += 1
                        if counter % 1 == 0 {
                            self?.updateAnimation()
                        }
                    })
                }
            } else {
                if let displayLink = self.displayLink {
                    self.displayLink = nil
                    displayLink.invalidate()
                }
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
