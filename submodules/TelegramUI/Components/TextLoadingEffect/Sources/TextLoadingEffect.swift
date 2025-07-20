import Foundation
import UIKit
import Display
import AppBundle
import HierarchyTrackingLayer

private let shadowImage: UIImage? = {
    UIImage(named: "Stories/PanelGradient")
}()

public final class TextLoadingEffectView: UIView {
    let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private let maskContentsView: UIView
    private let maskHighlightNode: LinkHighlightingNode
    private var maskShapeLayer: SimpleShapeLayer?
    
    private let maskBorderContentsView: UIView
    private let maskBorderHighlightNode: LinkHighlightingNode
    private var maskBorderShapeLayer: SimpleShapeLayer?
    
    private let backgroundView: UIImageView
    private let borderBackgroundView: UIImageView
    
    private var duration: Double
    private var gradientWidth: CGFloat
    
    private var size: CGSize?
    
    override public init(frame: CGRect) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.maskContentsView = UIView()
        self.maskHighlightNode = LinkHighlightingNode(color: .black)
        //self.maskHighlightNode.useModernPathCalculation = true
        
        self.maskBorderContentsView = UIView()
        self.maskBorderHighlightNode = LinkHighlightingNode(color: .black)
        self.maskBorderHighlightNode.borderOnly = true
        //self.maskBorderHighlightNode.useModernPathCalculation = true
        self.maskBorderContentsView.addSubview(self.maskBorderHighlightNode.view)
        
        self.backgroundView = UIImageView()
        self.borderBackgroundView = UIImageView()
        
        self.gradientWidth = 120.0
        self.duration = 1.0
        
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        self.maskContentsView.mask = self.maskHighlightNode.view
        self.maskContentsView.addSubview(self.backgroundView)
        self.addSubview(self.maskContentsView)
        
        self.maskBorderContentsView.mask = self.maskBorderHighlightNode.view
        self.maskBorderContentsView.addSubview(self.borderBackgroundView)
        self.addSubview(self.maskBorderContentsView)
        
        let generateGradient: (CGFloat) -> UIImage? = { baseAlpha in
            return generateImage(CGSize(width: self.gradientWidth, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
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
            })?.withRenderingMode(.alwaysTemplate)
        }
        
        self.backgroundView.image = generateGradient(0.5)
        self.borderBackgroundView.image = generateGradient(1.0)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self, let size = self.size else {
                return
            }
            self.updateAnimations(size: size)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations(size: CGSize) {
        if self.backgroundView.layer.animation(forKey: "shimmer") != nil {
            return
        }

        let animation = self.backgroundView.layer.makeAnimation(from: 0.0 as NSNumber, to: (size.width + self.gradientWidth + size.width * 0.0) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: self.duration, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        self.backgroundView.layer.add(animation, forKey: "shimmer")
        self.borderBackgroundView.layer.add(animation, forKey: "shimmer")
    }
    
    public func update(color: UIColor, rect: CGRect) {
        let maskFrame = CGRect(origin: CGPoint(), size: rect.size).insetBy(dx: -4.0, dy: -4.0)
        
        self.gradientWidth = 260.0
        self.duration = 1.2
        
        self.maskContentsView.backgroundColor = .clear
        
        self.backgroundView.alpha = 0.25
        self.backgroundView.tintColor = color
    
        self.maskContentsView.frame = maskFrame
    
        let rectsSet: [CGRect] = [rect]
                
        self.maskHighlightNode.updateRects(rectsSet)
        self.maskHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
                
        if self.size != maskFrame.size {
            self.size = maskFrame.size
            
            self.backgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            
            self.updateAnimations(size: maskFrame.size)
        }
    }
    
    public func update(color: UIColor, textNode: TextNodeProtocol, range: NSRange) {
        var rectsSet: [CGRect] = []
        if let rects = textNode.textRangeRects(in: range)?.rects, !rects.isEmpty {
            rectsSet = rects
        }
        
        let maskFrame = CGRect(origin: CGPoint(), size: textNode.bounds.size).insetBy(dx: -4.0, dy: -4.0)
        
        self.maskContentsView.backgroundColor = color.withAlphaComponent(0.1)
        self.maskBorderContentsView.backgroundColor = color.withAlphaComponent(0.12)
        
        self.backgroundView.tintColor = color
        self.borderBackgroundView.tintColor = color
        
        self.maskContentsView.frame = maskFrame
        self.maskBorderContentsView.frame = maskFrame
        
        self.maskHighlightNode.updateRects(rectsSet)
        self.maskHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        self.maskBorderHighlightNode.updateRects(rectsSet)
        self.maskBorderHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        if self.size != maskFrame.size {
            self.size = maskFrame.size
            
            self.backgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            self.borderBackgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            
            self.updateAnimations(size: maskFrame.size)
        }
    }
    
    public func update(color: UIColor, size: CGSize, rects: [CGRect]) {
        let rectsSet: [CGRect] = rects
        
        let maskFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -4.0, dy: -4.0)
        
        self.maskContentsView.backgroundColor = color.withAlphaComponent(0.1)
        self.maskBorderContentsView.backgroundColor = color.withAlphaComponent(0.12)
        
        self.backgroundView.tintColor = color
        self.borderBackgroundView.tintColor = color
        
        self.maskContentsView.frame = maskFrame
        self.maskBorderContentsView.frame = maskFrame
        
        self.maskHighlightNode.updateRects(rectsSet)
        self.maskHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        self.maskBorderHighlightNode.updateRects(rectsSet)
        self.maskBorderHighlightNode.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
        
        if self.size != maskFrame.size {
            self.size = maskFrame.size
            
            self.backgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            self.borderBackgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            
            self.updateAnimations(size: maskFrame.size)
        }
    }
    
    public func update(color: UIColor, rect: CGRect, path: CGPath) {
        let maskShapeLayer: SimpleShapeLayer
        if let current = self.maskShapeLayer {
            maskShapeLayer = current
        } else {
            maskShapeLayer = SimpleShapeLayer()
            maskShapeLayer.fillColor = UIColor.white.cgColor
            self.maskShapeLayer = maskShapeLayer
        }
        
        let maskBorderShapeLayer: SimpleShapeLayer
        if let current = self.maskBorderShapeLayer {
            maskBorderShapeLayer = current
        } else {
            maskBorderShapeLayer = SimpleShapeLayer()
            maskBorderShapeLayer.fillColor = nil
            maskBorderShapeLayer.strokeColor = UIColor.white.cgColor
            maskBorderShapeLayer.lineWidth = 4.0
            self.maskBorderShapeLayer = maskBorderShapeLayer
        }
        
        maskShapeLayer.path = path
        maskBorderShapeLayer.path = path
        
        if self.maskContentsView.layer.mask !== maskShapeLayer {
            self.maskContentsView.layer.mask = maskShapeLayer
        }
        if self.maskBorderContentsView.layer.mask !== maskBorderShapeLayer {
            self.maskBorderContentsView.layer.mask = maskBorderShapeLayer
        }
        
        let maskFrame = CGRect(origin: CGPoint(), size: rect.size)
        
        self.gradientWidth = 260.0
        self.duration = 0.7
        
        self.maskContentsView.backgroundColor = .clear
        
        self.backgroundView.alpha = 0.25
        self.backgroundView.tintColor = color
        
        self.borderBackgroundView.alpha = 0.5
        self.borderBackgroundView.tintColor = color
    
        self.maskContentsView.frame = maskFrame
        self.maskBorderContentsView.frame = maskFrame
        
        maskShapeLayer.frame = CGRect(origin: CGPoint(x: -maskFrame.minX, y: -maskFrame.minY), size: CGSize())
                
        if self.size != maskFrame.size {
            self.size = maskFrame.size
            
            self.backgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            self.borderBackgroundView.frame = CGRect(origin: CGPoint(x: -self.gradientWidth, y: 0.0), size: CGSize(width: self.gradientWidth, height: maskFrame.height))
            
            self.updateAnimations(size: maskFrame.size)
        }
    }
}
