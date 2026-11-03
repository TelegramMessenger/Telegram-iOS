import Foundation
import Display
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import ComponentFlow
import GlassBackgroundComponent

private let largeButtonSize = CGSize(width: 72.0, height: 72.0)
private let smallButtonSize = CGSize(width: 60.0, height: 60.0)

private func generateEmptyButtonImage(icon: UIImage?, strokeColor: UIColor?, fillColor: UIColor, knockout: Bool = false, angle: CGFloat = 0.0, buttonSize: CGSize = smallButtonSize) -> UIImage? {
    return generateImage(buttonSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        if let strokeColor = strokeColor {
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.5, y: 1.5), size: CGSize(width: size.width - 3.0, height: size.height - 3.0)))
        } else {
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        }
        
        if let icon = icon {
            if !angle.isZero {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: angle)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            let imageSize = icon.size
            let imageRect = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.width - imageSize.height) / 2.0)), size: imageSize)
            
            context.setBlendMode(.copy)
            context.clip(to: imageRect, mask: icon.cgImage!)
            if knockout {
                context.setFillColor(UIColor.clear.cgColor)
            } else {
                context.setFillColor(UIColor.white.cgColor)
            }
            context.fill(imageRect)
        }
    })
}

private func generateFilledButtonImage(color: UIColor, icon: UIImage?, angle: CGFloat = 0.0, buttonSize: CGSize = smallButtonSize) -> UIImage? {
    return generateImage(buttonSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        if let icon = icon {
            if !angle.isZero {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: angle)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            context.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) / 2.0), y: floor((size.height - icon.size.height) / 2.0)), size: icon.size))
        }
    })
}

private let largeLabelFont = Font.regular(14.5)
private let smallLabelFont = Font.regular(11.5)

final class GlassButtonNode: ASDisplayNode {
    private var regularImage: UIImage?
    private var filledImage: UIImage?
    
    private let backgroundView: GlassBackgroundView
    private let iconNode: ASImageNode
    private var labelNode: ImmediateTextNode?
    
    private let button: HighlightTrackingButton
    
    var pressed: () -> Void = {}
    
    init(icon: UIImage, label: String?) {
        self.backgroundView = GlassBackgroundView()
        
        self.button = HighlightTrackingButton()
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isUserInteractionEnabled = false
        
        self.regularImage = generateEmptyButtonImage(icon: icon, strokeColor: nil, fillColor: .clear, buttonSize: largeButtonSize)
        self.filledImage = generateEmptyButtonImage(icon: icon, strokeColor: nil, fillColor: .white, knockout: true, buttonSize: largeButtonSize)
        
        if let label = label {
            let labelNode = ImmediateTextNode()
            let labelFont: UIFont
            if let image = self.regularImage, image.size.width < 70.0 {
                labelFont = smallLabelFont
            } else {
                labelFont = largeLabelFont
            }
            labelNode.attributedText = NSAttributedString(string: label, font: labelFont, textColor: .white)
            labelNode.isUserInteractionEnabled = false
            self.labelNode = labelNode
        } else {
            self.labelNode = nil
        }
        
        super.init()
        
        self.view.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.button)
        self.backgroundView.contentView.addSubview(self.iconNode.view)
        if let labelNode = self.labelNode {
            self.backgroundView.contentView.addSubview(labelNode.view)
        }
        self.iconNode.image = self.regularImage
        self.currentImage = self.regularImage
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    var isSelected: Bool = false {
        didSet {
            self.updateState(selected: self.isSelected)
        }
    }
    
    private var currentImage: UIImage?
    
    private func updateState(selected: Bool) {
        let image: UIImage?
        if selected {
            image = self.filledImage
        } else {
            image = self.regularImage
        }
        
        if self.currentImage !== image {
            let currentContents = self.iconNode.layer.contents
            self.iconNode.layer.removeAnimation(forKey: "contents")
            if let currentContents = currentContents, let image = image {
                self.iconNode.image = image
                self.iconNode.layer.animate(from: currentContents as AnyObject, to:  image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: image === self.currentImage || image === self.filledImage ? 0.25 : 0.15)
            } else {
                self.iconNode.image = image
            }
            self.currentImage = image
        }
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.button.frame = self.bounds

        self.backgroundView.frame = self.bounds
        self.backgroundView.update(size: size, cornerRadius: size.width / 2.0, isDark: true, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
    
        self.iconNode.frame = self.bounds
        
        if let labelNode = self.labelNode {
            let labelSize = labelNode.updateLayout(CGSize(width: 200.0, height: 100.0))
            let offset: CGFloat
            if size.width < 70.0 {
                offset = 65.0
            } else {
                offset = 81.0
            }
            labelNode.frame = CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: offset), size: labelSize)
        }
    }
}
