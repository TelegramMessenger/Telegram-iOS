import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import AccountContext
import AppBundle

final class AppIconsDemoComponent: Component {
    public typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    let appIcons: [PresentationAppIcon]
    
    public init(
        context: AccountContext,
        appIcons: [PresentationAppIcon]
    ) {
        self.context = context
        self.appIcons = appIcons
    }
    
    public static func ==(lhs: AppIconsDemoComponent, rhs: AppIconsDemoComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.appIcons != rhs.appIcons {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: AppIconsDemoComponent?
        
        private var containerView: UIView
        private var axisView = UIView()
        private var imageViews: [UIImageView] = []
        
        private var isVisible = false
                
        public override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.axisView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: AppIconsDemoComponent, availableSize: CGSize, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
            let isDisplaying = environment[DemoPageEnvironment.self].isDisplaying
            
            self.component = component
            
            self.containerView.frame = CGRect(origin: CGPoint(x: -availableSize.width / 2.0, y: 0.0), size: CGSize(width: availableSize.width * 2.0, height: availableSize.height))
            
            self.axisView.bounds = CGRect(origin: .zero, size: availableSize)
            self.axisView.center = CGPoint(x: availableSize.width, y: availableSize.height / 2.0)
            
            if self.imageViews.isEmpty {
                var i = 0
                for icon in component.appIcons {
                    let image: UIImage?
                    switch icon.imageName {
                        case "Premium":
                            image = UIImage(bundleImageName: "Premium/Icons/Premium")
                        case "PremiumBlack":
                            image = UIImage(bundleImageName: "Premium/Icons/Black")
                        case "PremiumTurbo":
                            image = UIImage(bundleImageName: "Premium/Icons/Turbo")
                        case "PremiumDuck":
                            image = UIImage(bundleImageName: "Premium/Icons/Duck")
                        case "PremiumCoffee":
                            image = UIImage(bundleImageName: "Premium/Icons/Coffee")
                        case "PremiumSteam":
                            image = UIImage(bundleImageName: "Premium/Icons/Steam")
                        default:
                            image = nil
                    }
                    if let image = image {
                        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 90.0, height: 90.0)))
                        imageView.clipsToBounds = true
                        imageView.layer.cornerRadius = 24.0
                        if #available(iOS 13.0, *) {
                            imageView.layer.cornerCurve = .continuous
                        }
                        imageView.image = image
                        if i == 0 {
                            self.containerView.addSubview(imageView)
                        } else {
                            self.axisView.addSubview(imageView)
                        }
                        
                        self.imageViews.append(imageView)
                        
                        i += 1
                    }
                }
            }
 
            let radius: CGFloat = availableSize.width * 0.33
            let angleIncrement: CGFloat = 2 * .pi / CGFloat(self.imageViews.count - 1)
                
            var i = 0
            for view in self.imageViews {
                let position: CGPoint
                if i == 0 {
                    position = CGPoint(x: availableSize.width, y: availableSize.height / 2.0)
                } else {
                    let angle = CGFloat(i - 1) * angleIncrement
                    let xPosition = radius * cos(angle) + availableSize.width / 2.0
                    let yPosition = radius * sin(angle) + availableSize.height / 2.0
                    
                    position = CGPoint(x: xPosition, y: yPosition)
                }
                
                view.center = position
                    
                i += 1
            }
            
            var mappedPosition = environment[DemoPageEnvironment.self].position
            mappedPosition *= abs(mappedPosition)
            
            if let _ = transition.userData(DemoAnimateInTransition.self), abs(mappedPosition) < .ulpOfOne {
                Queue.mainQueue().after(0.1) {
                    self.animateIn(availableSize: availableSize)
                }
            }
            
            if isDisplaying && !self.isVisible {
                self.animateIn(availableSize: availableSize)
            }
            self.isVisible = isDisplaying
            
            let rotationDuration: Double = 12.0
            if isDisplaying {
                if self.axisView.layer.animation(forKey: "rotationAnimation") == nil {
                    let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
                    rotationAnimation.fromValue = 0.0
                    rotationAnimation.toValue = 2.0 * CGFloat.pi
                    rotationAnimation.duration = rotationDuration
                    rotationAnimation.repeatCount = Float.infinity
                    self.axisView.layer.add(rotationAnimation, forKey: "rotationAnimation")
                    
                    var i = 0
                    for view in self.imageViews {
                        if i == 0 {
                            let animation = CABasicAnimation(keyPath: "transform.scale")
                            animation.duration = 2.0
                            animation.fromValue = 1.0
                            animation.toValue = 1.15
                            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            animation.autoreverses = true
                            animation.repeatCount = .infinity
                            view.layer.add(animation, forKey: "scale")
                        } else {
                            view.transform = CGAffineTransformMakeScale(0.8, 0.8)
                            
                            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
                            rotationAnimation.fromValue = 0.0
                            rotationAnimation.toValue = -2.0 * CGFloat.pi
                            rotationAnimation.duration = rotationDuration
                            rotationAnimation.repeatCount = Float.infinity
                            view.layer.add(rotationAnimation, forKey: "rotationAnimation")
                        }
                        
                        i += 1
                    }
                }
            } else {
                self.axisView.layer.removeAllAnimations()
                for view in self.imageViews {
                    view.layer.removeAllAnimations()
                }
            }
            
            return availableSize
        }
        
        private var animating = false
        func animateIn(availableSize: CGSize) {
            self.animating = true
            
            let radius: CGFloat = availableSize.width * 2.5
            let angleIncrement: CGFloat = 2 * .pi / CGFloat(self.imageViews.count - 1)
            
            var i = 0
            for view in self.imageViews {
                if i > 0 {
                    let delay: Double = 0.033 * Double(i - 1)
                    
                    let angle = CGFloat(i - 1) * angleIncrement
                    let xPosition = radius * cos(angle)
                    let yPosition = radius * sin(angle)
                                        
                    let from = CGPoint(x: xPosition, y: yPosition)
                    let initialPosition = view.layer.position
                    view.layer.position = initialPosition.offsetBy(dx: xPosition, dy: yPosition)
                    view.alpha = 0.0
                    
                    Queue.mainQueue().after(delay) {
                        view.alpha = 1.0
                        view.layer.position = initialPosition
                        view.layer.animateScale(from: 3.0, to: 0.8, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                        view.layer.animatePosition(from: from, to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        
                        if i == self.imageViews.count - 1 {
                            self.animating = false
                        }
                    }
                } else {
                    
                }
                i += 1
            }
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
