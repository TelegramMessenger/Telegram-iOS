import Foundation
import AsyncDisplayKit
import Display

final class ListSectionHeaderNode: ASDisplayNode {
    private let label: TextNode
    private var actionButton: HighlightableButtonNode?
    private var theme: PresentationTheme
    
    var title: String? {
        didSet {
            self.calculatedLayoutDidChange()
            self.setNeedsLayout()
        }
    }
    
    var action: String? {
        didSet {
            if (self.action != nil) != (self.actionButton != nil) {
                if let _ = self.action {
                    let actionButton = HighlightableButtonNode()
                    self.addSubnode(actionButton)
                    self.actionButton = actionButton
                    actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
                } else if let actionButton = self.actionButton {
                    self.actionButton = nil
                    actionButton.removeFromSupernode()
                }
            }
            if let action = self.action {
                self.actionButton?.setAttributedTitle(NSAttributedString(string: action, font: Font.medium(12.0), textColor: self.theme.chatList.sectionHeaderTextColor), for: [])
            }
            self.calculatedLayoutDidChange()
            self.setNeedsLayout()
        }
    }
    
    var activateAction: (() -> Void)?
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.label = TextNode()
        self.label.isLayerBacked = true
        self.label.isOpaque = true
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.backgroundColor = theme.chatList.sectionHeaderFillColor
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.backgroundColor = theme.chatList.sectionHeaderFillColor
            if let action = self.action {
                self.actionButton?.setAttributedTitle(NSAttributedString(string: action, font: Font.medium(12.0), textColor: self.theme.chatList.sectionHeaderTextColor), for: [])
            }
            if !self.bounds.size.width.isZero && !self.bounds.size.height.isZero {
                self.layout()
            }
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        let makeLayout = TextNode.asyncLayout(self.label)
        let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title ?? "", font: Font.medium(12.0), textColor: self.theme.chatList.sectionHeaderTextColor), backgroundColor: self.backgroundColor, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, size.width - leftInset - rightInset - 18.0), height: size.height), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = labelApply()
        self.label.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 7.0), size: labelLayout.size)
        
        if let actionButton = self.actionButton {
            let buttonSize = actionButton.measure(CGSize(width: size.width, height: size.height))
            actionButton.frame = CGRect(origin: CGPoint(x: size.width - rightInset - 9.0 - buttonSize.width, y: 7.0), size: buttonSize)
        }
    }
    
    @objc func actionButtonPressed() {
        self.activateAction?()
    }
}
