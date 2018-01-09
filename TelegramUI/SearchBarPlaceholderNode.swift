import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private let templateLoupeIcon = UIImage(bundleImageName: "Components/Search Bar/Loupe")

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: templateLoupeIcon, color: color)
}

private func generateBackground(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    let diameter: CGFloat = 10.0
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: true)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private class SearchBarPlaceholderNodeLayer: CALayer {
}

private class SearchBarPlaceholderNodeView: UIView {
    override static var layerClass: AnyClass {
        return SearchBarPlaceholderNodeLayer.self
    }
}

class SearchBarPlaceholderNode: ASDisplayNode, ASEditableTextNodeDelegate {
    var activate: (() -> Void)?
    
    let backgroundNode: ASImageNode
    private var fillBackgroundColor: UIColor
    private var foregroundColor: UIColor
    private var iconColor: UIColor
    let iconNode: ASImageNode
    let labelNode: TextNode
    
    private(set) var placeholderString: NSAttributedString?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = false
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.fillBackgroundColor = UIColor.white
        self.foregroundColor = UIColor(rgb: 0xededed)
        self.iconColor = UIColor(rgb: 0x000000, alpha: 0.0)
        
        self.backgroundNode.image = generateBackground(backgroundColor: self.fillBackgroundColor, foregroundColor: self.foregroundColor)
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isOpaque = true
        self.labelNode.isLayerBacked = true
        self.labelNode.backgroundColor = self.foregroundColor
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.labelNode)
        
        self.backgroundNode.isUserInteractionEnabled = true
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.backgroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTap(_:))))
    }
    
    func asyncLayout() -> (_ placeholderString: NSAttributedString?, _ constrainedSize: CGSize, _ iconColor: UIColor, _ foregroundColor: UIColor, _ backgroundColor: UIColor) -> (() -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let currentFillBackgroundColor = self.fillBackgroundColor
        let currentForegroundColor = self.foregroundColor
        let currentIconColor = self.iconColor
        
        return { placeholderString, constrainedSize, iconColor, foregroundColor, backgroundColor in
            let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: placeholderString, backgroundColor: foregroundColor, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var updatedBackgroundImage: UIImage?
            var updatedIconImage: UIImage?
            if !currentFillBackgroundColor.isEqual(backgroundColor) || !currentForegroundColor.isEqual(foregroundColor) {
                updatedBackgroundImage = generateBackground(backgroundColor: backgroundColor, foregroundColor: foregroundColor)
            }
            if !currentIconColor.isEqual(iconColor) {
                updatedIconImage = generateLoupeIcon(color: iconColor)
            }
            
            return { [weak self] in
                if let strongSelf = self {
                    let _ = labelApply()
                    
                    strongSelf.fillBackgroundColor = backgroundColor
                    strongSelf.foregroundColor = foregroundColor
                    strongSelf.iconColor = iconColor
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                        strongSelf.labelNode.backgroundColor = foregroundColor
                    }
                    if let updatedIconImage = updatedIconImage {
                        strongSelf.iconNode.image = updatedIconImage
                    }
                    
                    strongSelf.placeholderString = placeholderString
                    
                    let labelFrame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - labelLayoutResult.size.width) / 2.0), y: floorToScreenPixels((28.0 - labelLayoutResult.size.height) / 2.0)), size: labelLayoutResult.size)
                    strongSelf.labelNode.frame = labelFrame
                    if let iconImage = strongSelf.iconNode.image {
                        let iconSize = iconImage.size
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: labelFrame.minX - 4.0 - iconSize.width, y: floorToScreenPixels((28.0 - iconSize.height) / 2.0)), size: iconSize)
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: 28.0))
                    strongSelf.backgroundColor = backgroundColor
                }
            }
        }
    }
    
    @objc private func backgroundTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let activate = self.activate {
                activate()
            }
        }
    }
}
