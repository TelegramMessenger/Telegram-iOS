import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

private let titleFont = Font.regular(17.0)
private let textFont = Font.regular(15.0)

private func fieldTitleAndText(field: SecureIdField, strings: PresentationStrings) -> (String, String) {
    let title: String
    let placeholder: String
    
    switch field.type {
        case .identity:
            title = strings.SecureId_FormFieldIdentity
            placeholder = strings.SecureId_FormFieldIdentityPlaceholder
        case .address:
            title = strings.SecureId_FormFieldAddress
            placeholder = strings.SecureId_FormFieldAddressPlaceholder
        case .phone:
            title = strings.SecureId_FormFieldPhone
            placeholder = strings.SecureId_FormFieldPhonePlaceholder
        case .email:
            title = strings.SecureId_FormFieldEmail
            placeholder = strings.SecureId_FormFieldEmailPlaceholder
    }
    
    return (title, placeholder)
}

final class SecureIdAuthFormFieldNode: ASDisplayNode {
    private let selected: () -> Void
    
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private let buttonNode: HighlightableButtonNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, field: SecureIdField, selected: @escaping () -> Void) {
        self.selected = selected
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isLayerBacked = true
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = true
        self.textNode.maximumNumberOfLines = 1
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        let (title, text) = fieldTitleAndText(field: field, strings: strings)
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: theme.list.itemSecondaryTextColor)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.view.superview?.bringSubview(toFront: strongSelf.view)
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(width: CGFloat, hasPrevious: Bool, hasNext: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        let height: CGFloat = 64.0
        
        let rightTextInset = rightInset + 24.0
        
        let titleTextSpacing: CGFloat = 5.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        
        let textOrigin = floor((height - titleSize.height - titleTextSpacing - textSize.height) / 2.0)
        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: textOrigin), size: titleSize)
        self.titleNode.frame = titleFrame
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleTextSpacing), size: textSize)
        self.textNode.frame = textFrame
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateAlpha(node: self.topSeparatorNode, alpha: hasPrevious ? 0.0 : 1.0)
        let bottomSeparatorInset: CGFloat = hasNext ? leftInset : 0.0
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: bottomSeparatorInset, y: height - UIScreenPixel), size: CGSize(width: width - bottomSeparatorInset, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -(hasPrevious ? UIScreenPixel : 0.0)), size: CGSize(width: width, height: height + (hasPrevious ? UIScreenPixel : 0.0))))
        
        return height
    }
    
    @objc private func buttonPressed() {
        self.selected()
    }
}
