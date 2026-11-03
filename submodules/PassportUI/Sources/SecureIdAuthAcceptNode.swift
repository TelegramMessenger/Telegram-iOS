import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AppBundle

private let textFont: UIFont = Font.regular(16.0)

final class SecureIdAuthAcceptNode: ASDisplayNode {
    private let separatorNode: ASDisplayNode
    private let buttonBackgroundNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    private let iconNode: ASImageNode
    private let labelNode: ImmediateTextNode
    
    var pressed: (() -> Void)?
    
    init(title: String, theme: PresentationTheme) {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.buttonBackgroundNode = ASImageNode()
        self.buttonBackgroundNode.isLayerBacked = true
        self.buttonBackgroundNode.displayWithoutProcessing = true
        self.buttonBackgroundNode.displaysAsynchronously = false
        self.buttonBackgroundNode.image = generateStretchableFilledCircleImage(radius: 24.0, color: theme.list.itemCheckColors.fillColor)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Secure ID/GrantIcon"), color: theme.list.itemCheckColors.foregroundColor)
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: theme.list.itemCheckColors.foregroundColor)
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.labelNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackgroundNode.alpha = 0.55
                } else {
                    strongSelf.buttonBackgroundNode.alpha = 1.0
                    strongSelf.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    /// `leftInset`/`rightInset` keep the button clear of a corner block beside the panel (iPhone Duo); the separator
    /// and the background span the whole width.
    func updateLayout(width: CGFloat, leftInset: CGFloat = 0.0, rightInset: CGFloat = 0.0, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        let baseHeight: CGFloat = 78.0
        let buttonSize = CGSize(width: width - leftInset - rightInset - 16.0 * 2.0, height: 48.0)
        let buttonFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: floor((baseHeight - buttonSize.height) / 2.0)), size: buttonSize)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        let labelSize = self.labelNode.updateLayout(buttonSize)
        var labelFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - labelSize.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - labelSize.height) / 2.0)), size: labelSize)
        
        if let image = self.iconNode.image {
            labelFrame.origin.x += 4.0
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: labelFrame.minX - image.size.width - 7.0, y: labelFrame.minY - 1.0), size: image.size))
        }
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        return baseHeight + bottomInset
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
}
