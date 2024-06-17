import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer
import RLottieBinding
import SwiftSignalKit
import AppBundle
import GZip
import GenerateStickerPlaceholderImage

public final class LottieComponent: Component {
    public typealias EnvironmentType = Empty
    
    public enum ContentData {
        case placeholder(data: Data)
        case animation(data: Data, cacheKey: String?)
    }
    
    open class Content: Equatable {
        open var frameRange: Range<Double> {
            preconditionFailure()
        }
        
        public init() {
        }
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            if lhs === rhs {
                return true
            }
            return lhs.isEqual(to: rhs)
        }

        open func isEqual(to other: Content) -> Bool {
            preconditionFailure()
        }
        
        open func load(_ f: @escaping (ContentData) -> Void) -> Disposable {
            preconditionFailure()
        }
    }
    
    public final class AppBundleContent: Content {
        public let name: String
        
        private let frameRangeValue: Range<Double>
        override public var frameRange: Range<Double> {
            return self.frameRangeValue
        }
        
        public init(name: String, frameRange: Range<Double> = 0.0 ..< 1.0) {
            self.name = name
            self.frameRangeValue = frameRange
        }
        
        override public func isEqual(to other: Content) -> Bool {
            guard let other = other as? AppBundleContent else {
                return false
            }
            if self.name != other.name {
                return false
            }
            if self.frameRangeValue != other.frameRangeValue {
                return false
            }
            return true
        }
        
        override public func load(_ f: @escaping (LottieComponent.ContentData) -> Void) -> Disposable {
            if let url = getAppBundle().url(forResource: self.name, withExtension: "json"), let data = try? Data(contentsOf: url) {
                f(.animation(data: data, cacheKey: url.path))
            } else if let url = getAppBundle().url(forResource: self.name, withExtension: "tgs"), let data = try? Data(contentsOf: URL(fileURLWithPath: url.path)), let unpackedData = TGGUnzipData(data, 5 * 1024 * 1024) {
                f(.animation(data: unpackedData, cacheKey: url.path))
            }
            
            return EmptyDisposable
        }
    }
    
    public enum StartingPosition: Equatable {
        case begin
        case end
        case fraction(Double)
    }

    public let content: Content
    public let color: UIColor?
    public let placeholderColor: UIColor?
    public let startingPosition: StartingPosition
    public let size: CGSize?
    public let renderingScale: CGFloat?
    public let loop: Bool
    public let playOnce: ActionSlot<Void>?
    
    public init(
        content: Content,
        color: UIColor? = nil,
        placeholderColor: UIColor? = nil,
        startingPosition: StartingPosition = .end,
        size: CGSize? = nil,
        renderingScale: CGFloat? = nil,
        loop: Bool = false,
        playOnce: ActionSlot<Void>? = nil
    ) {
        self.content = content
        self.color = color
        self.placeholderColor = placeholderColor
        self.startingPosition = startingPosition
        self.size = size
        self.renderingScale = renderingScale
        self.loop = loop
        self.playOnce = playOnce
    }
    
    public static func ==(lhs: LottieComponent, rhs: LottieComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.startingPosition != rhs.startingPosition {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.renderingScale != rhs.renderingScale {
            return false
        }
        if lhs.loop != rhs.loop {
            return false
        }
        return true
    }

    public final class View: UIImageView {
        private weak var state: EmptyComponentState?
        private var component: LottieComponent?
        
        private var scheduledPlayOnce: Bool = false
        private var isPlaying: Bool = false
        
        private var playOnceCompletion: (() -> Void)?
        private var animationInstance: LottieInstance?
        private var animationFrameRange: Range<Int>?
        private var currentDisplaySize: CGSize?
        private var currentContentDisposable: Disposable?
        
        private var currentFrame: Int = 0
        private var currentFrameStartTime: Double?
        
        private var hierarchyTrackingLayer: HierarchyTrackingLayer?
        private var isVisible: Bool = false
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        
        private var currentTemplateFrameImage: UIImage?
        
        public var externalShouldPlay: Bool? {
            didSet {
                if self.externalShouldPlay != oldValue {
                    self.visibilityUpdated()
                }
            }
        }
        
        var isEffectivelyVisible: Bool {
            if !self.isVisible {
                return false
            }
            if let externalShouldPlay = self.externalShouldPlay {
                if !externalShouldPlay {
                    return false
                }
            }
            return true
        }
        
        public weak var output: UIImageView? {
            didSet {
                if let output = self.output, let currentTemplateFrameImage = self.currentTemplateFrameImage {
                    output.image = currentTemplateFrameImage
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let hierarchyTrackingLayer = HierarchyTrackingLayer()
            self.hierarchyTrackingLayer = hierarchyTrackingLayer
            self.layer.addSublayer(hierarchyTrackingLayer)
            
            hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                if !self.isVisible {
                    self.isVisible = true
                    self.visibilityUpdated()
                }
            }
            hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                if self.isVisible {
                    self.isVisible = false
                    self.visibilityUpdated()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.currentContentDisposable?.dispose()
        }
        
        private func visibilityUpdated() {
            if self.isEffectivelyVisible {
                if self.scheduledPlayOnce {
                    self.playOnce()
                } else {
                    self.displayLink?.isPaused = false
                }
            } else {
                self.displayLink?.isPaused = true
            }
        }
        
        public func playOnce(delay: Double = 0.0, force: Bool = false,  completion: (() -> Void)? = nil) {
            self.playOnceCompletion = completion
            
            guard let _ = self.animationInstance, let animationFrameRange = self.animationFrameRange else {
                self.scheduledPlayOnce = true
                return
            }
            if !self.isEffectivelyVisible && !force {
                self.scheduledPlayOnce = true
                return
            }
            
            self.scheduledPlayOnce = false
            self.isPlaying = true
            
            if self.currentFrame != animationFrameRange.lowerBound {
                self.currentFrame = animationFrameRange.lowerBound
                self.updateImage()
            }
            
            if delay != 0.0 {
                self.isHidden = true
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isHidden = false
                    
                    self.currentFrameStartTime = CACurrentMediaTime()
                    if self.displayLink == nil {
                        self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.advanceIfNeeded()
                        }
                    }
                })
            } else {
                self.currentFrameStartTime = CACurrentMediaTime()
                if self.displayLink == nil {
                    self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.advanceIfNeeded()
                    }
                }
            }
        }
        
        private func loadPlaceholder(data: Data) {
            guard let component = self.component, let placeholderColor = component.placeholderColor else {
                return
            }
            guard let currentDisplaySize = self.currentDisplaySize else {
                return
            }
            
            if let image = generateStickerPlaceholderImage(
                data: data,
                size: currentDisplaySize,
                scale: min(2.0, UIScreenScale),
                imageSize: CGSize(width: 512.0, height: 512.0),
                backgroundColor: nil,
                foregroundColor: placeholderColor
            ) {
                self.image = image
            }
        }
        
        private func loadAnimation(data: Data, cacheKey: String?, startingPosition: StartingPosition, frameRange: Range<Double>) {
            self.animationInstance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: cacheKey ?? "")
            if let animationInstance = self.animationInstance {
                self.animationFrameRange = Int(floor(frameRange.lowerBound * Double(animationInstance.frameCount))) ..< Int(floor(frameRange.upperBound * Double(animationInstance.frameCount)))
            } else {
                self.animationFrameRange = nil
            }
            
            if let _ = self.animationInstance, let animationFrameRange = self.animationFrameRange {
                switch startingPosition {
                case .begin:
                    self.currentFrame = animationFrameRange.lowerBound
                case .end:
                    self.currentFrame = Int(max(animationFrameRange.lowerBound, animationFrameRange.upperBound - 1))
                case let .fraction(fraction):
                    self.currentFrame = animationFrameRange.lowerBound + Int(floor(Double(animationFrameRange.upperBound - animationFrameRange.lowerBound) * fraction))
                }
            }
            
            if self.scheduledPlayOnce && self.isEffectivelyVisible {
                self.scheduledPlayOnce = false
                self.playOnce()
            } else {
                self.updateImage()
            }
        }
        
        private func advanceIfNeeded() {
            guard let animationInstance = self.animationInstance, let animationFrameRange = self.animationFrameRange else {
                return
            }
            guard let currentFrameStartTime = self.currentFrameStartTime else {
                return
            }
            
            let secondsPerFrame: Double
            if animationInstance.frameRate == 0 {
                secondsPerFrame = 1.0 / 60.0
            } else {
                secondsPerFrame = 1.0 / Double(animationInstance.frameRate)
            }
            
            let timestamp = CACurrentMediaTime()
            if currentFrameStartTime + timestamp >= secondsPerFrame * 0.9 {
                var advanceFrameCount = 1
                if animationInstance.frameRate == 360 {
                    advanceFrameCount = 6
                } else if animationInstance.frameRate == 240 {
                    advanceFrameCount = 4
                }
                self.currentFrame += advanceFrameCount
                
                if self.currentFrame >= animationFrameRange.upperBound - 1 {
                    if let component = self.component, component.loop {
                        self.currentFrame = animationFrameRange.lowerBound
                    }
                }
                
                if self.currentFrame >= animationFrameRange.upperBound - 1 {
                    self.currentFrame = animationFrameRange.upperBound - 1
                    self.updateImage()
                    self.displayLink?.invalidate()
                    self.displayLink = nil
                    self.isPlaying = false
                    
                    if let playOnceCompletion = self.playOnceCompletion {
                        self.playOnceCompletion = nil
                        playOnceCompletion()
                    }
                } else {
                    self.currentFrameStartTime = timestamp
                    self.updateImage()
                }
            }
        }
        
        private func updateImage() {
            guard let animationInstance = self.animationInstance, let animationFrameRange = self.animationFrameRange, let currentDisplaySize = self.currentDisplaySize else {
                return
            }
            guard let context = DrawingContext(size: currentDisplaySize, scale: 1.0, opaque: false, clear: true) else {
                return
            }
            
            var effectiveFrameIndex = self.currentFrame
            effectiveFrameIndex = max(animationFrameRange.lowerBound, min(animationFrameRange.upperBound, effectiveFrameIndex))
            
            animationInstance.renderFrame(with: Int32(effectiveFrameIndex), into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(currentDisplaySize.width), height: Int32(currentDisplaySize.height), bytesPerRow: Int32(context.bytesPerRow))
            
            var image = context.generateImage()
            if let _ = self.component?.color {
                image = image?.withRenderingMode(.alwaysTemplate)
            }
            self.currentTemplateFrameImage = image
            self.image = self.currentTemplateFrameImage
            
            if let output = self.output, let currentTemplateFrameImage = self.currentTemplateFrameImage {
                output.image = currentTemplateFrameImage
            }
        }
        
        func update(component: LottieComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            component.playOnce?.connect { [weak self] in
                guard let self else {
                    return
                }
                self.playOnce()
            }
            
            let size = component.size ?? availableSize
            
            var redrawImage = false
            
            let renderingScale = component.renderingScale ?? UIScreenScale
            
            let displaySize = CGSize(width: size.width * renderingScale, height: size.height * renderingScale)
            if self.currentDisplaySize != displaySize {
                self.currentDisplaySize = displaySize
                redrawImage = true
            }
            
            if previousComponent?.content != component.content {
                self.currentContentDisposable?.dispose()
                let content = component.content
                let frameRange = content.frameRange
                self.currentContentDisposable = component.content.load { [weak self, weak content] result in
                    Queue.mainQueue().async {
                        guard let self, let component = self.component, component.content == content else {
                            return
                        }
                        switch result {
                        case let .placeholder(data):
                            self.loadPlaceholder(data: data)
                        case let .animation(data, cacheKey):
                            self.loadAnimation(data: data, cacheKey: cacheKey, startingPosition: component.startingPosition, frameRange: frameRange)
                        }
                    }
                }
            } else if redrawImage {
                self.updateImage()
            }
            
            if let color = component.color, self.tintColor != color {
                transition.setTintColor(view: self, color: color)
            }
            
            if component.loop && !self.isPlaying {
                self.playOnce()
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
