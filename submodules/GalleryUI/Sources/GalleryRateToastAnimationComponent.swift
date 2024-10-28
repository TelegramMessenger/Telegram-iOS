import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

final class GalleryRateToastAnimationComponent: Component {
    init() {
    }
    
    static func ==(lhs: GalleryRateToastAnimationComponent, rhs: GalleryRateToastAnimationComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let itemViewContainer: UIView
        private var itemViews: [UIImageView] = []
        
        override init(frame: CGRect) {
            self.itemViewContainer = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.itemViewContainer)
            
            let image = UIImage(bundleImageName: "Media Gallery/VideoRateToast")?.withRenderingMode(.alwaysTemplate)
            for _ in 0 ..< 2 {
                let itemView = UIImageView(image: image)
                itemView.tintColor = .white
                self.itemViews.append(itemView)
                self.itemViewContainer.addSubview(itemView)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupAnimations() {
            let beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil)
            
            for i in 0 ..< self.itemViews.count {
                if self.itemViews[i].layer.animation(forKey: "idle-opacity") != nil {
                    continue
                }
                
                let delay = Double(i) * 0.1
                
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.beginTime = beginTime + delay
                animation.fromValue = 0.6 as NSNumber
                animation.toValue = 1.0 as NSNumber
                animation.repeatCount = Float.infinity
                animation.autoreverses = true
                animation.fillMode = .both
                animation.duration = 0.4
                self.itemViews[i].layer.add(animation, forKey: "idle-opacity")
                
                let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
                scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                scaleAnimation.beginTime = beginTime + delay
                scaleAnimation.fromValue = 0.9 as NSNumber
                scaleAnimation.toValue = 1.1 as NSNumber
                scaleAnimation.repeatCount = Float.infinity
                scaleAnimation.autoreverses = true
                scaleAnimation.fillMode = .both
                scaleAnimation.duration = 0.4
                self.itemViews[i].layer.add(scaleAnimation, forKey: "idle-scale")
            }
        }
        
        func update(component: GalleryRateToastAnimationComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let itemSize = self.itemViews[0].image?.size ?? CGSize(width: 10.0, height: 10.0)
            let itemSpacing: CGFloat = 1.0
            
            let size = CGSize(width: itemSize.width * 2.0 + itemSpacing, height: 12.0)
            
            for i in 0 ..< self.itemViews.count {
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(i) * (itemSize.width + itemSpacing), y: UIScreenPixel), size: itemSize)
                self.itemViews[i].frame = itemFrame
            }
            
            self.setupAnimations()
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
