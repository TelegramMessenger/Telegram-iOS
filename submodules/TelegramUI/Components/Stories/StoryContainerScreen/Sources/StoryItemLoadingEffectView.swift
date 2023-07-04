import Foundation
import UIKit
import HierarchyTrackingLayer
import ComponentFlow
import Display

final class StoryItemLoadingEffectView: UIView {
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private let gradientWidth: CGFloat
    private let backgroundView: UIImageView
    
    private let borderGradientView: UIImageView
    private let borderContaineView: UIView
    private let borderMaskLayer: SimpleShapeLayer
    
    override init(frame: CGRect) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.gradientWidth = 500.0
        self.backgroundView = UIImageView()
        
        self.borderGradientView = UIImageView()
        self.borderContaineView = UIView()
        self.borderMaskLayer = SimpleShapeLayer()
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self, self.bounds.width != 0.0 else {
                return
            }
            self.updateAnimations(size: self.bounds.size)
        }
        
        self.backgroundView.image = generateImage(CGSize(width: self.gradientWidth, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
            let backgroundColor = UIColor.clear
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let foregroundColor = UIColor(white: 1.0, alpha: 0.2)
            
            let numColors = 7
            var locations: [CGFloat] = []
            var colors: [CGColor] = []
            for i in 0 ..< numColors {
                let position: CGFloat = CGFloat(i) / CGFloat(numColors - 1)
                locations.append(position)
                
                let distanceFromCenterFraction: CGFloat = max(0.0, min(1.0, abs(position - 0.5) / 0.5))
                let colorAlpha = sin((1.0 - distanceFromCenterFraction) * CGFloat.pi * 0.5)
                
                colors.append(foregroundColor.withMultipliedAlpha(colorAlpha).cgColor)
            }
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
        self.addSubview(self.backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations(size: CGSize) {
        if self.backgroundView.layer.animation(forKey: "shimmer") != nil {
            return
        }

        let animation = self.backgroundView.layer.makeAnimation(from: 0.0 as NSNumber, to: (size.width + self.gradientWidth) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.8, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        self.backgroundView.layer.add(animation, forKey: "shimmer")
    }
    
    func update(size: CGSize, transition: Transition) {
        if self.backgroundView.bounds.size != size {
            self.backgroundView.layer.removeAllAnimations()
        }
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: size))
        self.updateAnimations(size: size)
    }
}
