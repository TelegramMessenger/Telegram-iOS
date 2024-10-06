import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer

private let shadowImage: UIImage? = {
    UIImage(named: "Stories/PanelGradient")
}()

private func generateGradient(baseAlpha: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: 200.0, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let foregroundColor = UIColor(white: 1.0, alpha: min(1.0, baseAlpha * 4.0))
        
        if let shadowImage {
            UIGraphicsPushContext(context)
            
            for i in 0 ..< 2 {
                let shadowFrame = CGRect(origin: CGPoint(x: CGFloat(i) * (size.width * 0.5), y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height))
                
                context.saveGState()
                context.translateBy(x: shadowFrame.midX, y: shadowFrame.midY)
                context.rotate(by: CGFloat(i == 0 ? 1.0 : -1.0) * CGFloat.pi * 0.5)
                let adjustedRect = CGRect(origin: CGPoint(x: -shadowFrame.height * 0.5, y: -shadowFrame.width * 0.5), size: CGSize(width: shadowFrame.height, height: shadowFrame.width))
                
                context.clip(to: adjustedRect, mask: shadowImage.cgImage!)
                context.setFillColor(foregroundColor.cgColor)
                context.fill(adjustedRect)
                
                context.restoreGState()
            }
            
            UIGraphicsPopContext()
        }
    })
}

private final class AnimatedGradientView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var containerWidth: CGFloat
        var offsetX: CGFloat
        var gradientWidth: CGFloat
        
        init(size: CGSize, containerWidth: CGFloat, offsetX: CGFloat, gradientWidth: CGFloat) {
            self.size = size
            self.containerWidth = containerWidth
            self.offsetX = offsetX
            self.gradientWidth = gradientWidth
        }
    }
    
    private let duration: Double
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private let backgroundContainerView: UIView
    private let backgroundScaleView: UIView
    private let backgroundOffsetView: UIView
    private let backgroundView: UIImageView
    
    private var params: Params?
    
    init(effectAlpha: CGFloat, duration: Double) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.duration = duration
        
        self.backgroundContainerView = UIView()
        self.backgroundContainerView.layer.anchorPoint = CGPoint()
        
        self.backgroundScaleView = UIView()
        self.backgroundOffsetView = UIView()
        
        self.backgroundView = UIImageView()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateAnimations()
        }
        
        self.backgroundView.image = generateGradient(baseAlpha: effectAlpha)
        
        self.backgroundOffsetView.addSubview(self.backgroundView)
        self.backgroundScaleView.addSubview(self.backgroundOffsetView)
        self.backgroundContainerView.addSubview(self.backgroundScaleView)
        self.addSubview(self.backgroundContainerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations() {
        if self.backgroundView.layer.animation(forKey: "shimmer") == nil {
            let animation = self.backgroundView.layer.makeAnimation(from: -1.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: self.duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            animation.repeatCount = Float.infinity
            animation.beginTime = 1.0
            self.backgroundView.layer.add(animation, forKey: "shimmer")
        }
        if self.backgroundScaleView.layer.animation(forKey: "shimmer") == nil {
            let animation = self.backgroundScaleView.layer.makeAnimation(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: self.duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            animation.repeatCount = Float.infinity
            animation.beginTime = 1.0
            self.backgroundScaleView.layer.add(animation, forKey: "shimmer")
        }
    }
    
    func update(size: CGSize, containerWidth: CGFloat, offsetX: CGFloat, gradientWidth: CGFloat, transition: ComponentTransition) {
        let params = Params(size: size, containerWidth: containerWidth, offsetX: offsetX, gradientWidth: gradientWidth)
        if self.params == params {
            return
        }
        self.params = params
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0))
        transition.setPosition(view: self.backgroundView, position: backgroundFrame.center)
        transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        
        transition.setPosition(view: self.backgroundOffsetView, position: backgroundFrame.center)
        transition.setBounds(view: self.backgroundOffsetView, bounds: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        
        transition.setTransform(view: self.backgroundOffsetView, transform: CATransform3DMakeScale(gradientWidth, 1.0, 1.0))
        
        let backgroundContainerViewSubFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
        transition.setPosition(view: self.backgroundContainerView, position: CGPoint())
        transition.setBounds(view: self.backgroundContainerView, bounds: backgroundContainerViewSubFrame)
        var containerTransform = CATransform3DIdentity
        containerTransform = CATransform3DTranslate(containerTransform, -offsetX, 0.0, 0.0)
        containerTransform = CATransform3DScale(containerTransform, containerWidth, size.height, 1.0)
        transition.setSublayerTransform(view: self.backgroundContainerView, transform: containerTransform)
        
        transition.setSublayerTransform(view: self.backgroundScaleView, transform: CATransform3DMakeScale(1.0 / containerWidth, 1.0, 1.0))
        
        self.updateAnimations()
    }
}

final class VideoChatVideoLoadingEffectView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var containerWidth: CGFloat
        var offsetX: CGFloat
        var gradientWidth: CGFloat
        
        init(size: CGSize, containerWidth: CGFloat, offsetX: CGFloat, gradientWidth: CGFloat) {
            self.size = size
            self.containerWidth = containerWidth
            self.offsetX = offsetX
            self.gradientWidth = gradientWidth
        }
    }
    
    private let duration: Double
    private let cornerRadius: CGFloat
    
    private let backgroundView: AnimatedGradientView
    
    private let borderMaskView: UIImageView
    private let borderBackgroundView: AnimatedGradientView
    
    private var params: Params?
    
    init(effectAlpha: CGFloat, borderAlpha: CGFloat, cornerRadius: CGFloat = 12.0, duration: Double) {
        self.duration = duration
        self.cornerRadius = cornerRadius
        
        self.backgroundView = AnimatedGradientView(effectAlpha: effectAlpha, duration: duration)
        
        self.borderMaskView = UIImageView()
        self.borderMaskView.image = generateStretchableFilledCircleImage(diameter: cornerRadius * 2.0, color: nil, strokeColor: .white, strokeWidth: 2.0)
        self.borderBackgroundView = AnimatedGradientView(effectAlpha: borderAlpha, duration: duration)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundView)
        
        self.borderBackgroundView.mask = self.borderMaskView
        self.addSubview(self.borderBackgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, containerWidth: CGFloat, offsetX: CGFloat, gradientWidth: CGFloat, transition: ComponentTransition) {
        let params = Params(size: size, containerWidth: containerWidth, offsetX: offsetX, gradientWidth: gradientWidth)
        if self.params == params {
            return
        }
        self.params = params
        
        self.backgroundView.update(size: size, containerWidth: containerWidth, offsetX: offsetX, gradientWidth: gradientWidth, transition: transition)
        self.borderBackgroundView.update(size: size, containerWidth: containerWidth, offsetX: offsetX, gradientWidth: gradientWidth, transition: transition)
        transition.setFrame(view: self.borderMaskView, frame: CGRect(origin: CGPoint(), size: size))
    }
}
