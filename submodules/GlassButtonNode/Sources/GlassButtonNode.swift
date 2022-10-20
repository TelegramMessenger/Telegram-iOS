import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

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
            if knockout {
                context.setBlendMode(.copy)
                context.clip(to: imageRect, mask: icon.cgImage!)
                context.setFillColor(UIColor.clear.cgColor)
                context.fill(imageRect)
            } else {
                context.setBlendMode(.normal)
                context.draw(icon.cgImage!, in: imageRect)
            }
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

private let emptyHighlightedFill = UIColor(white: 1.0, alpha: 0.3)
private let invertedFill = UIColor(white: 1.0, alpha: 1.0)

private let largeLabelFont = Font.regular(14.5)
private let smallLabelFont = Font.regular(11.5)

public final class GlassButtonNode: HighlightTrackingButtonNode {
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    private var filledImage: UIImage?
    
    private let blurView: UIVisualEffectView
    private let iconNode: ASImageNode
    private var labelNode: ImmediateTextNode?
    
    public init(icon: UIImage, label: String?) {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        self.blurView = blurView
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = false
        self.iconNode.displaysAsynchronously = false
        
        self.regularImage = generateEmptyButtonImage(icon: icon, strokeColor: nil, fillColor: .clear, buttonSize: largeButtonSize)
        self.highlightedImage = generateEmptyButtonImage(icon: icon, strokeColor: nil, fillColor: emptyHighlightedFill, buttonSize: largeButtonSize)
        self.filledImage = generateEmptyButtonImage(icon: icon, strokeColor: nil, fillColor: invertedFill, knockout: true, buttonSize: largeButtonSize)
        
        if let label = label {
            let labelNode = ImmediateTextNode()
            let labelFont: UIFont
            if let image = regularImage, image.size.width < 70.0 {
                labelFont = smallLabelFont
            } else {
                labelFont = largeLabelFont
            }
            labelNode.attributedText = NSAttributedString(string: label, font: labelFont, textColor: .white)
            self.labelNode = labelNode
        } else {
            self.labelNode = nil
        }
        
        super.init()
        
        self.view.addSubview(blurView)
        self.addSubnode(self.iconNode)
        if let labelNode = self.labelNode {
            self.addSubnode(labelNode)
        }
        self.iconNode.image = regularImage
        self.currentImage = regularImage
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.internalHighlighted = highlighted
                strongSelf.updateState(highlighted: highlighted, selected: strongSelf.isSelected)
            }
        }
    }
    
    private var internalHighlighted = false
    
    override public var isSelected: Bool {
        didSet {
            self.updateState(highlighted: self.internalHighlighted, selected: self.isSelected)
        }
    }
    
    private var currentImage: UIImage?
    
    private func updateState(highlighted: Bool, selected: Bool) {
        let image: UIImage?
        if selected {
            image = self.filledImage
        } else if highlighted {
            image = self.highlightedImage
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
        
        self.blurView.layer.cornerRadius = size.width / 2.0
        blurView.frame = self.bounds
    
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
