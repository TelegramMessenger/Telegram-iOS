import Foundation
import UIKit
import HierarchyTrackingLayer
import ComponentFlow
import Display

final class StoryItemLoadingEffectView: UIView {
    private let duration: Double
    private let hasCustomBorder: Bool
    private let playOnce: Bool
    
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private let gradientWidth: CGFloat
    private let backgroundView: UIImageView
    
    private let borderGradientView: UIImageView
    private let borderContainerView: UIView
    let borderMaskLayer: SimpleShapeLayer
    
    private var didPlayOnce = false
    
    init(effectAlpha: CGFloat, borderAlpha: CGFloat, gradientWidth: CGFloat = 200.0, duration: Double, hasCustomBorder: Bool, playOnce: Bool) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.duration = duration
        self.hasCustomBorder = hasCustomBorder
        self.playOnce = playOnce
        
        self.gradientWidth = gradientWidth
        self.backgroundView = UIImageView()
        
        self.borderGradientView = UIImageView()
        self.borderContainerView = UIView()
        self.borderMaskLayer = SimpleShapeLayer()
        
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self, self.bounds.width != 0.0 else {
                return
            }
            self.updateAnimations(size: self.bounds.size)
        }
        
        let generateGradient: (CGFloat) -> UIImage? = { baseAlpha in
            return generateImage(CGSize(width: self.gradientWidth, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
                let backgroundColor = UIColor.clear
                
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                context.clip(to: CGRect(origin: CGPoint(), size: size))
                
                let foregroundColor = UIColor(white: 1.0, alpha: baseAlpha)
                
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
        }
        self.backgroundView.image = generateGradient(effectAlpha)
        self.addSubview(self.backgroundView)
        
        self.borderGradientView.image = generateGradient(borderAlpha)
        self.borderContainerView.addSubview(self.borderGradientView)
        self.addSubview(self.borderContainerView)
        self.borderContainerView.layer.mask = self.borderMaskLayer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations(size: CGSize) {
        if self.backgroundView.layer.animation(forKey: "shimmer") != nil || (self.playOnce && self.didPlayOnce) {
            return
        }

        let animation = self.backgroundView.layer.makeAnimation(from: 0.0 as NSNumber, to: (size.width + self.gradientWidth + size.width * 0.2) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: self.duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = self.playOnce ? 1 : Float.infinity
        self.backgroundView.layer.add(animation, forKey: "shimmer")
        self.borderGradientView.layer.add(animation, forKey: "shimmer")
        
        self.didPlayOnce = true
    }
    
    func update(size: CGSize, transition: Transition) {
        if self.backgroundView.bounds.size != size {
            self.backgroundView.layer.removeAllAnimations()
            
            if !self.hasCustomBorder {
                self.borderMaskLayer.fillColor = nil
                self.borderMaskLayer.strokeColor = UIColor.white.cgColor
                let lineWidth: CGFloat = 3.0
                self.borderMaskLayer.lineWidth = lineWidth
                self.borderMaskLayer.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), cornerRadius: 12.0).cgPath
            }
        }
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: size.height)))
        
        transition.setFrame(view: self.borderContainerView, frame: CGRect(origin: CGPoint(), size: size))
        transition.setFrame(view: self.borderGradientView, frame: CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: size.height)))
        
        self.updateAnimations(size: size)
    }
}
