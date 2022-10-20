import Foundation
import ComponentFlow
import Lottie
import AppBundle
import HierarchyTrackingLayer
import Display

public final class LottieAnimationComponent: Component {
    public struct AnimationItem: Equatable {
        public enum StillPosition {
            case begin
            case end
        }
        
        public enum Mode: Equatable {
            case still(position: StillPosition)
            case animating(loop: Bool)
            case animateTransitionFromPrevious
        }
        
        public var name: String
        public var mode: Mode
        
        public init(name: String, mode: Mode) {
            self.name = name
            self.mode = mode
        }
    }
    
    public let animation: AnimationItem
    public let colors: [String: UIColor]
    public let tag: AnyObject?
    public let size: CGSize?
    
    public init(animation: AnimationItem, colors: [String: UIColor], tag: AnyObject? = nil, size: CGSize?) {
        self.animation = animation
        self.colors = colors
        self.tag = tag
        self.size = size
    }
    
    public func tagged(_ tag: AnyObject?) -> LottieAnimationComponent {
        return LottieAnimationComponent(
            animation: self.animation,
            colors: self.colors,
            tag: tag,
            size: self.size
        )
    }

    public static func ==(lhs: LottieAnimationComponent, rhs: LottieAnimationComponent) -> Bool {
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
    
    public final class View: UIView, ComponentTaggedView {
        private var component: LottieAnimationComponent?
        
        //private var colorCallbacks: [LOTColorValueCallback] = []
        private var animationView: AnimationView?
        private var didPlayToCompletion: Bool = false
        
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        private var currentCompletion: (() -> Void)?
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self, let animationView = strongSelf.animationView else {
                    return
                }
                if case .loop = animationView.loopMode {
                    animationView.play { _ in
                        self?.currentCompletion?()
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        public func playOnce() {
            guard let animationView = self.animationView else {
                return
            }

            animationView.stop()
            animationView.loopMode = .playOnce
            animationView.play { [weak self] _ in
                self?.currentCompletion?()
            }
        }
        
        func update(component: LottieAnimationComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            var updatePlayback = false
            var updateColors = false
            
            if let currentComponent = self.component, currentComponent.colors != component.colors {
                updateColors = true
            }
            
            var animateSize = true
            var updateComponent = true
            
            if self.component?.animation != component.animation {
                if let animationView = self.animationView {
                    if case .animateTransitionFromPrevious = component.animation.mode, !animationView.isAnimationPlaying, !self.didPlayToCompletion {
                        updateComponent = false
                        animationView.play { [weak self] _ in
                            self?.currentCompletion?()
                        }
                    }
                }
                
                if let animationView = self.animationView, animationView.isAnimationPlaying {
                    updateComponent = false
                    self.currentCompletion = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.didPlayToCompletion = true
                        let _ = strongSelf.update(component: component, availableSize: availableSize, transition: transition)
                    }
                    animationView.loopMode = .playOnce
                } else {
                    self.component = component
                    
                    self.animationView?.removeFromSuperview()
                    self.didPlayToCompletion = false
                    self.currentCompletion = nil
                    
                    if let url = getAppBundle().url(forResource: component.animation.name, withExtension: "json"), let animation = Animation.filepath(url.path) {
                        let view = AnimationView(animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                        switch component.animation.mode {
                        case .still, .animateTransitionFromPrevious:
                            view.loopMode = .playOnce
                        case let .animating(loop):
                            if loop {
                                view.loopMode = .loop
                            } else {
                                view.loopMode = .playOnce
                            }
                        }
                        view.animationSpeed = 1.0
                        view.backgroundColor = .clear
                        view.isOpaque = false
                        
                        updateColors = true
                        
                        self.animationView = view
                        self.addSubview(view)
                        
                        animateSize = false
                        updatePlayback = true
                    }
                }
            }
            
            if updateComponent {
                self.component = component
            }
            
            if updateColors, let animationView = self.animationView {
                if let value = component.colors["__allcolors__"] {
                    for keypath in animationView.allKeypaths(predicate: { $0.keys.last == "Color" }) {
                        animationView.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: keypath))
                    }
                }
                
                for (key, value) in component.colors {
                    if key == "__allcolors__" {
                        continue
                    }
                    animationView.setValueProvider(ColorValueProvider(value.lottieColorValue), keypath: AnimationKeypath(keypath: "\(key).Color"))
                }
            }
            
            var animationSize = CGSize()
            if let animationView = self.animationView, let animation = animationView.animation {
                animationSize = animation.size
            }
            if let customSize = component.size {
                animationSize = customSize
            }
            
            let size = CGSize(width: min(animationSize.width, availableSize.width), height: min(animationSize.height, availableSize.height))
            
            if let animationView = self.animationView {
                let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.height - animationSize.height) / 2.0)), size: animationSize)
                
                if animationView.frame != animationFrame {
                    if !transition.animation.isImmediate && animateSize && !animationView.frame.isEmpty && animationView.frame.size != animationFrame.size {
                        let previouosAnimationFrame = animationView.frame
                        
                        if let snapshotView = animationView.snapshotView(afterScreenUpdates: false) {
                            snapshotView.frame = previouosAnimationFrame
                            
                            animationView.superview?.insertSubview(snapshotView, belowSubview: animationView)
                            
                            transition.setPosition(view: snapshotView, position: CGPoint(x: animationFrame.midX, y: animationFrame.midY))
                            snapshotView.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                            let scaleFactor = previouosAnimationFrame.width / animationFrame.width
                            transition.animateScale(view: snapshotView, from: scaleFactor, to: 1.0)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                        
                        transition.setPosition(view: animationView, position: CGPoint(x: animationFrame.midX, y: animationFrame.midY))
                        transition.setBounds(view: animationView, bounds: CGRect(origin: CGPoint(), size: animationFrame.size))
                        transition.animateSublayerScale(view: animationView, from: previouosAnimationFrame.width / animationFrame.width, to: 1.0)
                        animationView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                    } else if animationView.frame.size == animationFrame.size {
                        transition.setFrame(view: animationView, frame: animationFrame)
                    } else {
                        animationView.frame = animationFrame
                    }
                }
                
                if updatePlayback {
                    if case .animating = component.animation.mode {
                        if !animationView.isAnimationPlaying {
                            animationView.play { [weak self] _ in
                                self?.currentCompletion?()
                            }
                        }
                    } else {
                        if case let .still(position) = component.animation.mode {
                            switch position {
                            case .begin:
                                animationView.currentFrame = 0.0
                            case .end:
                                animationView.currentFrame = animationView.animation?.endFrame ?? 0.0
                            }
                        }
                        if animationView.isAnimationPlaying {
                            animationView.stop()
                        }
                    }
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
