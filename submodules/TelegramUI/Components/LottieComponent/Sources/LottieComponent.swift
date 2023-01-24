import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer
import RLottieBinding
import SwiftSignalKit
import Accelerate

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
        
        open func load(_ f: @escaping (Data) -> Void) -> Disposable {
            preconditionFailure()
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
            //self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            //self.layer.addSublayer(self.hierarchyTrackingLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.currentContentDisposable?.dispose()
        }
        
        public func playOnce(delay: Double = 0.0) {
            guard let _ = self.animationInstance else {
                self.scheduledPlayOnce = true
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
        
        private func loadAnimation(data: Data) {
            self.animationInstance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: "")
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
            
            var destinationBuffer = vImage_Buffer()
            destinationBuffer.width = UInt(context.scaledSize.width)
            destinationBuffer.height = UInt(context.scaledSize.height)
            destinationBuffer.data = context.bytes
            destinationBuffer.rowBytes = context.bytesPerRow
            
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
                self.currentContentDisposable = component.content.load { [weak self, weak content] data in
                    Queue.mainQueue().async {
                        guard let self, self.component?.content == content else {
                            return
                        }
                        self.loadAnimation(data: data)
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
