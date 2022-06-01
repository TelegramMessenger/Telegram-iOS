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
        
        private var imageViews: [UIImageView] = []
                
        public func update(component: AppIconsDemoComponent, availableSize: CGSize, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
//            let isDisplaying = environment[DemoPageEnvironment.self].isDisplaying
            
//            if self.node == nil {
//                let node = StickersCarouselNode(
//                    context: component.context,
//                    stickers: component.stickers
//                )
//                self.node = node
//                self.addSubnode(node)
//            }
            
//            let isFirstTime = self.component == nil
            self.component = component
            
            if self.imageViews.isEmpty {
                for icon in component.appIcons {
                    if let image = UIImage(named: icon.imageName, in: getAppBundle(), compatibleWith: nil) {
                        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 90.0, height: 90.0)))
                        imageView.clipsToBounds = true
                        imageView.layer.cornerRadius = 24.0
                        imageView.image = image
                        self.addSubview(imageView)
                        
                        self.imageViews.append(imageView)
                    }
                }
            }
 
            var i = 0
            for view in self.imageViews {
                let position: CGPoint
                switch i {
                    case 0:
                        position = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.333)
                    case 1:
                        position = CGPoint(x: availableSize.width * 0.333, y: availableSize.height * 0.667)
                    case 2:
                        position = CGPoint(x: availableSize.width * 0.667, y: availableSize.height * 0.667)
                    default:
                        position = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5)
                }
                
                view.center = position
                
                i += 1
            }
            
            var mappedPosition = environment[DemoPageEnvironment.self].position
            mappedPosition *= abs(mappedPosition)
            
            if let _ = transition.userData(DemoAnimateInTransition.self), abs(mappedPosition) < .ulpOfOne {
                Queue.mainQueue().after(0.1) {
                    var i = 0
                    for view in self.imageViews {
                        let from: CGPoint
                        let delay: Double
                        switch i {
                            case 0:
                                from = CGPoint(x: -availableSize.width * 0.333, y: -availableSize.height * 0.8)
                                delay = 0.1
                            case 1:
                                from = CGPoint(x: -availableSize.width * 0.75, y: availableSize.height * 0.75)
                                delay = 0.15
                            case 2:
                                from = CGPoint(x: availableSize.width * 0.9, y: availableSize.height * 0.0)
                                delay = 0.0
                            default:
                                from = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5)
                                delay = 0.0
                        }
                        view.layer.animateScale(from: 3.0, to: 1.0, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                        view.layer.animatePosition(from: from, to: CGPoint(), duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        
                        i += 1
                    }
                }
            }
            
            return availableSize
        }
        
        func animateIn() {
            
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
