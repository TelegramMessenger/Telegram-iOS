import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer
import RLottieBinding
import SwiftSignalKit
import AppBundle

public final class LottieComponent: Component {
    public typealias EnvironmentType = Empty
    
    open class Content: Equatable {
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
        
        open func load(_ f: @escaping (Data, String?) -> Void) -> Disposable {
            preconditionFailure()
        }
    }
    
    public final class AppBundleContent: Content {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
        
        override public func isEqual(to other: Content) -> Bool {
            guard let other = other as? AppBundleContent else {
                return false
            }
            if self.name != other.name {
                return false
            }
            return true
        }
        
        override public func load(_ f: @escaping (Data, String?) -> Void) -> Disposable {
            if let url = getAppBundle().url(forResource: self.name, withExtension: "json"), let data = try? Data(contentsOf: url) {
                f(data, url.path)
            }
            
            return EmptyDisposable
        }
    }

    public let content: Content
    public let color: UIColor
    
    public init(
        content: Content,
        color: UIColor
    ) {
        self.content = content
        self.color = color
    }
    
    public static func ==(lhs: LottieComponent, rhs: LottieComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    public final class View: UIImageView {
        private weak var state: EmptyComponentState?
        private var component: LottieComponent?
        
        private var scheduledPlayOnce: Bool = false
        private var animationInstance: LottieInstance?
        private var currentDisplaySize: CGSize?
        private var currentContentDisposable: Disposable?
        
        private var currentFrame: Int = 0
        private var currentFrameStartTime: Double?
        
        private var hierarchyTrackingLayer: HierarchyTrackingLayer?
        private var isVisible: Bool = false
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        
        private var currentTemplateFrameImage: UIImage?
        
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
            if self.isVisible {
                if self.scheduledPlayOnce {
                    self.playOnce()
                }
            }
        }
        
        public func playOnce(delay: Double = 0.0) {
            guard let _ = self.animationInstance else {
                self.scheduledPlayOnce = true
                return
            }
            if !self.isVisible {
                return
            }
            
            self.scheduledPlayOnce = false
            
            if self.currentFrame != 0 {
                self.currentFrame = 0
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
                        self.displayLink = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: false, { [weak self] in
                            guard let self else {
                                return
                            }
                            self.advanceIfNeeded()
                        })
                    }
                })
            } else {
                self.currentFrameStartTime = CACurrentMediaTime()
                if self.displayLink == nil {
                    self.displayLink = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: false, { [weak self] in
                        guard let self else {
                            return
                        }
                        self.advanceIfNeeded()
                    })
                }
            }
        }
        
        private func loadAnimation(data: Data, cacheKey: String?) {
            self.animationInstance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: cacheKey ?? "")
            if self.scheduledPlayOnce {
                self.scheduledPlayOnce = false
                self.playOnce()
            } else if let animationInstance = self.animationInstance {
                self.currentFrame = Int(animationInstance.frameCount - 1)
                self.updateImage()
            }
        }
        
        private func advanceIfNeeded() {
            guard let animationInstance = self.animationInstance else {
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
                self.currentFrame += 1
                if self.currentFrame >= Int(animationInstance.frameCount) - 1 {
                    self.currentFrame = Int(animationInstance.frameCount) - 1
                    self.updateImage()
                    self.displayLink?.invalidate()
                    self.displayLink = nil
                } else {
                    self.currentFrameStartTime = timestamp
                    self.updateImage()
                }
            }
        }
        
        private func updateImage() {
            guard let animationInstance = self.animationInstance, let currentDisplaySize = self.currentDisplaySize else {
                return
            }
            guard let context = DrawingContext(size: currentDisplaySize, scale: 1.0, opaque: false, clear: true) else {
                return
            }
            
            animationInstance.renderFrame(with: Int32(self.currentFrame % Int(animationInstance.frameCount)), into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(currentDisplaySize.width), height: Int32(currentDisplaySize.height), bytesPerRow: Int32(context.bytesPerRow))
            self.currentTemplateFrameImage = context.generateImage()?.withRenderingMode(.alwaysTemplate)
            self.image = self.currentTemplateFrameImage
            
            if let output = self.output, let currentTemplateFrameImage = self.currentTemplateFrameImage {
                output.image = currentTemplateFrameImage
            }
        }
        
        func update(component: LottieComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            var redrawImage = false
            
            let displaySize = CGSize(width: availableSize.width * UIScreenScale, height: availableSize.height * UIScreenScale)
            if self.currentDisplaySize != displaySize {
                self.currentDisplaySize = displaySize
                redrawImage = true
            }
            
            if previousComponent?.content != component.content {
                self.currentContentDisposable?.dispose()
                let content = component.content
                self.currentContentDisposable = component.content.load { [weak self, weak content] data, cacheKey in
                    Queue.mainQueue().async {
                        guard let self, self.component?.content == content else {
                            return
                        }
                        self.loadAnimation(data: data, cacheKey: cacheKey)
                    }
                }
            } else if redrawImage {
                self.updateImage()
            }
            
            if self.tintColor != component.color {
                transition.setTintColor(view: self, color: component.color)
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
