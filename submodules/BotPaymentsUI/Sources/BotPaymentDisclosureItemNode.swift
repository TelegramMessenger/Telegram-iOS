import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(17.0)

class BotPaymentDisclosureItemNode: BotPaymentItemNode {
    private let title: String
    private let placeholder: String
    var text: String {
        didSet {
            if let theme = self.theme {
                self.textNode.attributedText = NSAttributedString(string: self.text, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            }
        }
    }
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var theme: PresentationTheme?
    
    var action: (() -> Void)?
    
    init(title: String, placeholder: String, text: String) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 1
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init(needsBackground: true)
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    if let supernode = strongSelf.supernode {
                        supernode.view.bringSubviewToFront(strongSelf.view)
                    }
                    
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(buttonPressed), forControlEvents: .touchUpInside)
    }
    
    override func measureInset(theme: PresentationTheme, width: CGFloat) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            if self.text.isEmpty {
                self.textNode.attributedText = NSAttributedString(string: self.placeholder, font: titleFont, textColor: theme.list.itemPlaceholderTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: self.text, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            }
        }
        
        let leftInset: CGFloat = 16.0
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        if titleSize.width.isZero {
            return 0.0
        } else {
            return leftInset + titleSize.width + 17.0
        }
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            if self.text.isEmpty {
                self.textNode.attributedText = NSAttributedString(string: self.placeholder, font: titleFont, textColor: theme.list.itemPlaceholderTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: self.text, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            }
        }
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: CGSize(width: width - sideInset * 2.0, height: 44.0))
        transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: 44.0 + UIScreenPixel)))
        
        let leftInset: CGFloat = 16.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0 - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: 11.0), size: titleSize))
        
        var textInset = leftInset
        if !titleSize.width.isZero {
            textInset += titleSize.width + 18.0
        }
        textInset = max(measuredInset, textInset)
        
        let textSize = self.textNode.measure(CGSize(width: width - measuredInset - 8.0 - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: textInset + sideInset, y: 11.0), size: textSize))
        
        return 44.0
    }
    
    @objc func buttonPressed() {
        self.action?()
    }
}
