import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.bold(13.0)
private let actionFont = Font.medium(13.0)

public final class ListSectionHeaderNode: ASDisplayNode {
    private let label: ImmediateTextNode
    private var actionButton: HighlightableButtonNode?
    private var theme: PresentationTheme
    
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    
    public var title: String? {
        didSet {
            self.label.attributedText = NSAttributedString(string: self.title ?? "", font: titleFont, textColor: self.theme.chatList.sectionHeaderTextColor)
            
            if let (size, leftInset, rightInset) = self.validLayout {
                self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
            }
        }
    }
    
    public var action: String? {
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
                self.actionButton?.setAttributedTitle(NSAttributedString(string: action, font: actionFont, textColor: self.theme.chatList.sectionHeaderTextColor), for: [])
            }
            
            if let (size, leftInset, rightInset) = self.validLayout {
                self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
            }
        }
    }
    
    public var activateAction: (() -> Void)?
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.backgroundColor = theme.chatList.sectionHeaderFillColor
    }
    
    public func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.label.attributedText = NSAttributedString(string: self.title ?? "", font: titleFont, textColor: self.theme.chatList.sectionHeaderTextColor)
            
            self.backgroundColor = theme.chatList.sectionHeaderFillColor
            if let action = self.action {
                self.actionButton?.setAttributedTitle(NSAttributedString(string: action, font: actionFont, textColor: self.theme.chatList.sectionHeaderTextColor), for: [])
            }
            
            if let (size, leftInset, rightInset) = self.validLayout {
                self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
            }
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        let labelSize = self.label.updateLayout(CGSize(width: max(0.0, size.width - leftInset - rightInset - 18.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: 6.0 + UIScreenPixel), size: labelSize)
        
        if let actionButton = self.actionButton {
            let buttonSize = actionButton.measure(CGSize(width: size.width, height: size.height))
            actionButton.frame = CGRect(origin: CGPoint(x: size.width - rightInset - 16.0 - buttonSize.width, y: 6.0 + UIScreenPixel), size: buttonSize)
        }
    }
    
    @objc private func actionButtonPressed() {
        self.activateAction?()
    }
}
