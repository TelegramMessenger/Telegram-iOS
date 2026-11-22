import Foundation
import UIKit
import Display
import ComponentFlow

final class ContentOverlayButton: HighlightTrackingButton, OverlayMaskContainerViewProtocol {
    private struct ContentParams: Equatable {
        var size: CGSize
        var image: UIImage?
        var isSelected: Bool
        var isDestructive: Bool
        var isEnabled: Bool
        
        init(size: CGSize, image: UIImage?, isSelected: Bool, isDestructive: Bool, isEnabled: Bool) {
            self.size = size
            self.image = image
            self.isSelected = isSelected
            self.isDestructive = isDestructive
            self.isEnabled = isEnabled
        }
    }
    
    let maskContents: UIView
    
    override static var layerClass: AnyClass {
        return MirroringLayer.self
    }
    
    var action: (() -> Void)?
    
    private let contentView: UIImageView
    private var currentContentViewIsSelected: Bool?
    
    private let textView: TextView
    
    private var contentParams: ContentParams?
    
    override init(frame: CGRect) {
        self.maskContents = UIView()
        
        self.contentView = UIImageView()
        self.textView = TextView()
        
        super.init(frame: frame)
        
        self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        let size: CGFloat = 56.0
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: CGSize(width: size, height: size)))
        self.maskContents.layer.contents = renderer.image { context in
            UIGraphicsPushContext(context.cgContext)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size, height: size)))
            UIGraphicsPopContext()
        }.cgImage
        
        (self.layer as? MirroringLayer)?.targetLayer = self.maskContents.layer
        
        self.addSubview(self.contentView)
        self.addSubview(self.textView)
        
        self.internalHighligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "sublayerTransform")
                    let transition = ComponentTransition(animation: .curve(duration: 0.15, curve: .easeInOut))
                    transition.setScale(layer: self.layer, scale: topScale)
                } else {
                    let t = self.layer.presentation()?.transform ?? layer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    let transition = ComponentTransition(animation: .none)
                    transition.setScale(layer: self.layer, scale: 1.0)
                    
                    self.layer.animateScale(from: currentScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let self, completed else {
                            return
                        }
                        
                        self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        self.action?()
    }
    
    func update(size: CGSize, image: UIImage?, isSelected: Bool, isDestructive: Bool, isEnabled: Bool, title: String, transition: ComponentTransition) {
        let contentParams = ContentParams(size: size, image: image, isSelected: isSelected, isDestructive: isDestructive, isEnabled: isEnabled)
        if self.contentParams != contentParams {
            self.contentParams = contentParams
            self.updateContent(contentParams: contentParams, transition: transition)
        }
        
        self.isUserInteractionEnabled = isEnabled
        
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
        
        let textSize = self.textView.update(string: title, fontSize: 13.0, fontWeight: 0.0, color: .white, constrainedWidth: 100.0, transition: .immediate)
        self.textView.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) * 0.5), y: size.height + 4.0), size: textSize)
    }
    
    private func updateContent(contentParams: ContentParams, transition: ComponentTransition) {
        let image = generateImage(contentParams.size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            if contentParams.isDestructive {
                context.setFillColor(UIColor(rgb: 0xFF3B30).cgColor)
            } else {
                context.setFillColor(UIColor(white: 1.0, alpha: contentParams.isSelected ? 1.0 : 0.0).cgColor)
            }
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            if let image = contentParams.image, let cgImage = image.cgImage {
                let imageSize = CGSize(width: image.size.width * 0.8, height: image.size.height * 0.8)
                let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) * 0.5), y: floor((size.height - imageSize.height) * 0.5)), size: imageSize)
                
                context.saveGState()
                context.translateBy(x: imageFrame.midX, y: imageFrame.midY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -imageFrame.midX, y: -imageFrame.midY)
                
                context.clip(to: imageFrame, mask: cgImage)
                context.setBlendMode(contentParams.isSelected ? .copy : .normal)
                context.setFillColor(contentParams.isSelected ? UIColor(white: 1.0, alpha: contentParams.isEnabled ? 0.0 : 0.5).cgColor : UIColor(white: 1.0, alpha: contentParams.isEnabled ? 1.0 : 0.5).cgColor)
                context.fill(imageFrame)
                
                context.resetClip()
                context.restoreGState()
            }
        })
        
        if !transition.animation.isImmediate, let currentContentViewIsSelected = self.currentContentViewIsSelected, currentContentViewIsSelected != contentParams.isSelected, let previousImage = self.contentView.image {
            self.contentView.layer.mask = nil
            let previousContentView = UIImageView(image: previousImage)
            previousContentView.frame = self.contentView.frame
            self.addSubview(previousContentView)
            
            let animationDuration = 0.16
            let animationTimingFunction: String = CAMediaTimingFunctionName.linear.rawValue
            
            if contentParams.isSelected {
                let maskLayer = CAShapeLayer()
                maskLayer.frame = self.contentView.bounds
                maskLayer.path = UIBezierPath(ovalIn: self.contentView.bounds).cgPath
                maskLayer.strokeColor = UIColor.black.cgColor
                maskLayer.fillColor = nil
                maskLayer.lineWidth = 1.0
                self.contentView.layer.mask = maskLayer
                maskLayer.animate(from: 0.0 as NSNumber, to: contentParams.size.width as NSNumber, keyPath: "lineWidth", timingFunction: animationTimingFunction, duration: animationDuration, removeOnCompletion: false, completion: { [weak self, weak maskLayer] _ in
                    guard let self, let maskLayer, self.contentView.layer.mask === maskLayer else {
                        return
                    }
                    self.contentView.layer.mask = nil
                })
                
                let previousMaskLayer = CAShapeLayer()
                previousMaskLayer.frame = previousContentView.bounds
                previousMaskLayer.path = UIBezierPath(ovalIn: previousContentView.bounds).cgPath
                previousMaskLayer.strokeColor = nil
                previousMaskLayer.fillColor = UIColor.black.cgColor
                previousContentView.layer.mask = previousMaskLayer
                previousMaskLayer.animate(from: 1.0 as NSNumber, to: 0.0001 as NSNumber, keyPath: "transform.scale", timingFunction: animationTimingFunction, duration: animationDuration, removeOnCompletion: false, completion: { [weak previousContentView] _ in
                    previousContentView?.removeFromSuperview()
                })
            } else {
                let maskLayer = CAShapeLayer()
                maskLayer.frame = self.contentView.bounds
                maskLayer.path = UIBezierPath(ovalIn: self.contentView.bounds).cgPath
                maskLayer.strokeColor = nil
                maskLayer.fillColor = UIColor.black.cgColor
                self.contentView.layer.mask = maskLayer
                maskLayer.animate(from: 0.0001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", timingFunction: animationTimingFunction, duration: animationDuration, removeOnCompletion: false, completion: { [weak self, weak maskLayer] _ in
                    guard let self, let maskLayer, self.contentView.layer.mask === maskLayer else {
                        return
                    }
                    self.contentView.layer.mask = nil
                })
                
                let previousMaskLayer = CAShapeLayer()
                previousMaskLayer.frame = previousContentView.bounds
                previousMaskLayer.path = UIBezierPath(ovalIn: previousContentView.bounds).cgPath
                previousMaskLayer.strokeColor = UIColor.black.cgColor
                previousMaskLayer.fillColor = nil
                previousMaskLayer.lineWidth = 1.0
                previousContentView.layer.mask = previousMaskLayer
                previousMaskLayer.animate(from: contentParams.size.width as NSNumber, to: 0.0 as NSNumber, keyPath: "lineWidth", timingFunction: animationTimingFunction, duration: animationDuration, removeOnCompletion: false, completion: { [weak previousContentView] _ in
                    previousContentView?.removeFromSuperview()
                })
            }
        }
        
        self.contentView.image = image
        self.currentContentViewIsSelected = contentParams.isSelected
    }
}
