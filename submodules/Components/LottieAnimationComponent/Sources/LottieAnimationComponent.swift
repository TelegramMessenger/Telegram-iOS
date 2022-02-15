import Foundation
import ComponentFlow
import Lottie
import AppBundle

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
    public let size: CGSize
    
    public init(animation: Animation, size: CGSize) {
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
        
        func update(component: LottieAnimationComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let size = CGSize(width: min(component.size.width, availableSize.width), height: min(component.size.height, availableSize.height))
            
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
                        
                        view.logHierarchyKeypaths()
                        
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
            
            if let animationView = self.animationView {
                animationView.frame = CGRect(origin: CGPoint(x: floor((size.width - component.size.width) / 2.0), y: floor((size.height - component.size.height) / 2.0)), size: component.size)
                
                if !animationView.isAnimationPlaying {
                    animationView.play { _ in
                    }
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
