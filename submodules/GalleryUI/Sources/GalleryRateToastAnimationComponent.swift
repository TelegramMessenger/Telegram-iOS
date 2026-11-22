import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

final class GalleryRateToastAnimationComponent: Component {
    let speedFraction: CGFloat
    
    init(speedFraction: CGFloat) {
        self.speedFraction = speedFraction
    }
    
    static func ==(lhs: GalleryRateToastAnimationComponent, rhs: GalleryRateToastAnimationComponent) -> Bool {
        if lhs.speedFraction != rhs.speedFraction {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let itemViewContainer: UIView
        private var itemViews: [UIImageView] = []
        
        private var link: SharedDisplayLinkDriver.Link?
        private var timeValue: CGFloat = 0.0
        private var speedFraction: CGFloat = 1.0
        
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
        
        deinit {
            self.link?.invalidate()
        }
        
        private func setupAnimations() {
            if self.link == nil {
                var previousTimestamp = CACurrentMediaTime()
                self.link = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                    guard let self else {
                        return
                    }
                    
                    let timestamp = CACurrentMediaTime()
                    let deltaMultiplier = 1.0 * (1.0 - self.speedFraction) + 3.0 * self.speedFraction
                    let deltaTime = (timestamp - previousTimestamp) * deltaMultiplier
                    previousTimestamp = timestamp
                    
                    self.timeValue += deltaTime
                    
                    let duration: CGFloat = 1.2
                    
                    for i in 0 ..< self.itemViews.count {
                        var itemFraction = (self.timeValue + CGFloat(i) * 0.1).truncatingRemainder(dividingBy: duration) / duration
                        
                        if itemFraction >= 0.5 {
                            itemFraction = (1.0 - itemFraction) / 0.5
                        } else {
                            itemFraction = itemFraction / 0.5
                        }
                        
                        let itemAlpha = 0.6 * (1.0 - itemFraction) + 1.0 * itemFraction
                        let itemScale = 0.9 * (1.0 - itemFraction) + 1.1 * itemFraction
                        
                        self.itemViews[i].alpha = itemAlpha
                        self.itemViews[i].transform = CGAffineTransformMakeScale(itemScale, itemScale)
                    }
                }
            }
        }
        
        func update(component: GalleryRateToastAnimationComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.speedFraction = component.speedFraction
            
            let itemSize = self.itemViews[0].image?.size ?? CGSize(width: 10.0, height: 10.0)
            let itemSpacing: CGFloat = 1.0
            
            let size = CGSize(width: itemSize.width * 2.0 + itemSpacing, height: 12.0)
            
            for i in 0 ..< self.itemViews.count {
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(i) * (itemSize.width + itemSpacing), y: UIScreenPixel), size: itemSize)
                self.itemViews[i].center = itemFrame.center
                self.itemViews[i].bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                
                self.itemViews[i].layer.speed = Float(1.0 * (1.0 - component.speedFraction) + 2.0 * component.speedFraction)
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
