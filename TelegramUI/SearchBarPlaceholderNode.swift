import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private let templateLoupeIcon = UIImage(bundleImageName: "Components/Search Bar/Loupe")

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: templateLoupeIcon, color: color)
}

private func generateBackground(backgroundColor: UIColor, foregroundColor: UIColor, diameter: CGFloat) -> UIImage? {
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

class SearchBarPlaceholderNode: ASDisplayNode {
    var activate: (() -> Void)?
    
    private let fieldStyle: SearchBarStyle
    let backgroundNode: ASDisplayNode
    private var fillBackgroundColor: UIColor
    private var foregroundColor: UIColor
    private var iconColor: UIColor
    let iconNode: ASImageNode
    let labelNode: TextNode
    
    private(set) var placeholderString: NSAttributedString?
    
    convenience override init() {
        self.init(fieldStyle: .legacy)
    }
    
    init(fieldStyle: SearchBarStyle = .legacy) {
        self.fieldStyle = fieldStyle
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = false
        self.backgroundNode.displaysAsynchronously = false
        
        self.fillBackgroundColor = UIColor.white
        self.foregroundColor = UIColor(rgb: 0xededed)
        self.iconColor = UIColor(rgb: 0x000000, alpha: 0.0)
        
        self.backgroundNode.backgroundColor = self.foregroundColor
        self.backgroundNode.cornerRadius = self.fieldStyle.cornerDiameter / 2.0
        
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
    
    func asyncLayout() -> (_ placeholderString: NSAttributedString?, _ constrainedSize: CGSize, _ expansionProgress: CGFloat, _ iconColor: UIColor, _ foregroundColor: UIColor, _ backgroundColor: UIColor, _ transition: ContainedViewLayoutTransition) -> (() -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let currentForegroundColor = self.foregroundColor
        let currentIconColor = self.iconColor
        
        return { placeholderString, constrainedSize, expansionProgress, iconColor, foregroundColor, backgroundColor, transition in
            let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: placeholderString, backgroundColor: foregroundColor, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var updatedColor: UIColor?
            var updatedIconImage: UIImage?
            if !currentForegroundColor.isEqual(foregroundColor) {
                updatedColor = foregroundColor
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
                    strongSelf.backgroundNode.isUserInteractionEnabled = expansionProgress > 1.0 - CGFloat.ulpOfOne
                    
                    if let updatedColor = updatedColor {
                        strongSelf.backgroundNode.backgroundColor = updatedColor
                    }
                    if let updatedIconImage = updatedIconImage {
                        strongSelf.iconNode.image = updatedIconImage
                    }
                    
                    strongSelf.placeholderString = placeholderString
                    
                    var iconSize = CGSize()
                    var totalWidth = labelLayoutResult.size.width
                    let spacing: CGFloat = 7.0
                    let height = constrainedSize.height * expansionProgress
                    
                    if let iconImage = strongSelf.iconNode.image {
                        iconSize = iconImage.size
                        totalWidth += iconSize.width + spacing
                         transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: floor((constrainedSize.width - totalWidth) / 2.0), y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
                    }
                    var textOffset: CGFloat = 0.0
                    if constrainedSize.height >= 36.0 {
                        textOffset += UIScreenPixel
                    }
                    let labelFrame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - totalWidth) / 2.0) + iconSize.width + spacing, y: floorToScreenPixels((height - labelLayoutResult.size.height) / 2.0) + textOffset), size: labelLayoutResult.size)
                    transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
               
                    let innerAlpha = max(0.0, expansionProgress - 0.77) / 0.23
                    transition.updateAlpha(node: strongSelf.labelNode, alpha: innerAlpha)
                    transition.updateAlpha(node: strongSelf.iconNode, alpha: innerAlpha)
                    let outerAlpha = min(0.3, expansionProgress) / 0.3
                    
                    let cornerRadius = min(strongSelf.fieldStyle.cornerDiameter / 2.0, height / 2.0)
                    strongSelf.backgroundNode.cornerRadius = cornerRadius
                    transition.updateAlpha(node: strongSelf.backgroundNode, alpha: outerAlpha)
                    transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: height)))
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
