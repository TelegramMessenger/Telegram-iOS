import Foundation
import ComponentFlow
import Lottie
import AppBundle

private final class NullActionClass: NSObject, CAAction {
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private let nullAction = NullActionClass()

private final class HierarchyTrackingLayer: CALayer {
    var didEnterHierarchy: (() -> Void)?
    var didExitHierarchy: (() -> Void)?
    
    override func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.didExitHierarchy?()
        }
        return nullAction
    }
}

public final class LottieAnimationComponent: Component {
    public struct Animation: Equatable {
        public var name: String
        public var loop: Bool
        public var colors: [String: UIColor]
        
        public init(name: String, colors: [String: UIColor], loop: Bool) {
            self.name = name
            self.colors = colors
            self.loop = loop
        }
    }
    
    public let animation: Animation
    public let size: CGSize?
    
    public init(animation: Animation, size: CGSize?) {
        self.animation = animation
        self.size = size
    }

    public static func ==(lhs: LottieAnimationComponent, rhs: LottieAnimationComponent) -> Bool {
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var currentAnimation: Animation?
        
        private var colorCallbacks: [LOTColorValueCallback] = []
        private var animationView: LOTAnimationView?
        
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self, let animationView = strongSelf.animationView else {
                    return
                }
                if animationView.loopAnimation {
                    animationView.play()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: LottieAnimationComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.currentAnimation != component.animation {
                if let animationView = self.animationView, animationView.isAnimationPlaying {
                    animationView.completionBlock = { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.update(component: component, availableSize: availableSize, transition: transition)
                    }
                    animationView.loopAnimation = false
                } else {
                    self.currentAnimation = component.animation
                    
                    self.animationView?.removeFromSuperview()
                    
                    if let url = getAppBundle().url(forResource: component.animation.name, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                        let view = LOTAnimationView(model: composition, in: getAppBundle())
                        view.loopAnimation = component.animation.loop
                        view.animationSpeed = 1.0
                        view.backgroundColor = .clear
                        view.isOpaque = false
                        
                        for (key, value) in component.animation.colors {
                            let colorCallback = LOTColorValueCallback(color: value.cgColor)
                            self.colorCallbacks.append(colorCallback)
                            view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                        }
                        
                        self.animationView = view
                        self.addSubview(view)
                    }
                }
            }
            
            var animationSize = CGSize()
            if let animationView = self.animationView, let sceneModel = animationView.sceneModel {
                animationSize = sceneModel.compBounds.size
            }
            if let customSize = component.size {
                animationSize = customSize
            }
            
            let size = CGSize(width: min(animationSize.width, availableSize.width), height: min(animationSize.height, availableSize.height))
            
            if let animationView = self.animationView {
                animationView.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.height - animationSize.height) / 2.0)), size: animationSize)
                
                if !animationView.isAnimationPlaying {
                    animationView.play { _ in
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
