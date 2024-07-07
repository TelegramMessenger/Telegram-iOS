import Foundation
import UIKit
import Display
import ComponentFlow

final class FlipButtonContentComponent: Component {
    let tag: AnyObject?
    
    init(
        tag: AnyObject?
    ) {
        self.tag = tag
    }
    
    static func ==(lhs: FlipButtonContentComponent, rhs: FlipButtonContentComponent) -> Bool {
        return lhs === rhs
    }
    
    final class View: UIView, ComponentTaggedView {
        private var component: FlipButtonContentComponent?
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let backgroundView: BlurredBackgroundView
        private let icon = SimpleLayer()
        
        init() {
            self.backgroundView = BlurredBackgroundView(color: UIColor(white: 0.0, alpha: 0.5), enableBlur: true)
            
            super.init(frame: CGRect())
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.icon)
            
            self.icon.contents = UIImage(bundleImageName: "Camera/FlipIcon")?.withRenderingMode(.alwaysTemplate).cgImage
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func playAnimation() {
            let animation = CASpringAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0.0 as NSNumber
            animation.toValue = CGFloat.pi as NSNumber
            animation.mass = 5.0
            animation.stiffness = 900.0
            animation.damping = 90.0
            animation.duration = animation.settlingDuration
            if #available(iOS 15.0, *) {
                let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: maxFps, preferred: maxFps)
            }
            self.icon.add(animation, forKey: "transform.rotation.z")
        }
        
        func update(component: FlipButtonContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let size = CGSize(width: 48.0, height: 48.0)
            let backgroundFrame = CGRect(x: 4.0, y: 4.0, width: 40.0, height: 40.0)
            
            self.icon.layerTintColor = UIColor.white.cgColor
            self.icon.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.icon.bounds = CGRect(origin: .zero, size: size)
            
            self.backgroundView.frame = backgroundFrame
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.width / 2.0, transition: .immediate)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
