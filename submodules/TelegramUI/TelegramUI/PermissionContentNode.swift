import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

final class PermissionContentNode: ASDisplayNode {
    private var theme: PresentationTheme
    let kind: PermissionKind
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let actionButton: SolidRoundedButtonNode
    private let privacyPolicyButton: HighlightableButtonNode
    
    private var title: String
    
    var buttonAction: (() -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, kind: PermissionKind, icon: UIImage?, title: String, text: String, buttonTitle: String, buttonAction: @escaping () -> Void, openPrivacyPolicy: (() -> Void)?) {
        self.theme = theme
        self.kind = kind
        
        self.buttonAction = buttonAction
        self.openPrivacyPolicy = openPrivacyPolicy
        
        self.title = title
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        self.textNode.displaysAsynchronously = false
        
        self.actionButton = SolidRoundedButtonNode(theme: theme, height: 48.0, cornerRadius: 9.0)
        
        self.privacyPolicyButton = HighlightableButtonNode()
        self.privacyPolicyButton.setTitle(strings.Permissions_PrivacyPolicy, with: Font.regular(16.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()
        
        self.iconNode.image = icon
        self.title = title
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.actionButton.title = buttonTitle
        self.privacyPolicyButton.isHidden = openPrivacyPolicy == nil
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionButton)
        self.addSubnode(self.privacyPolicyButton)
        
        self.actionButton.pressed = { [weak self] in
            self?.buttonAction?()
        }
        
        self.privacyPolicyButton.addTarget(self, action: #selector(self.privacyPolicyPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        let sidePadding: CGFloat
        let fontSize: CGFloat
        if min(size.width, size.height) > 330.0 {
            fontSize = 24.0
            sidePadding = 38.0
        } else {
            fontSize = 20.0
            sidePadding = 20.0
        }
        
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.semibold(fontSize), textColor: self.theme.list.itemPrimaryTextColor)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let buttonWidth = min(size.width, size.height)
        let buttonHeight = self.actionButton.updateLayout(width: buttonWidth, transition: transition)
        let privacyButtonSize = self.privacyPolicyButton.measure(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        
        let availableHeight = floor(size.height - insets.top - insets.bottom - titleSize.height - textSize.height - buttonHeight)
        
        let titleSubtitleSpacing: CGFloat = max(15.0, floor(availableHeight * 0.055))
        let buttonSpacing: CGFloat = max(19.0, floor(availableHeight * 0.075))
        var contentHeight = titleSize.height + titleSubtitleSpacing + textSize.height + buttonHeight + buttonSpacing
        
        var imageSize = CGSize()
        var imageSpacing: CGFloat = 0.0
        if let icon = self.iconNode.image, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = icon.size
            contentHeight += imageSize.height + imageSpacing
        }

        let privacySpacing: CGFloat = max(30.0 + privacyButtonSize.height, (availableHeight - titleSubtitleSpacing - buttonSpacing - imageSize.height - imageSpacing) / 2.0)
        
        let contentOrigin = insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0)
        let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: iconFrame.maxY + imageSpacing), size: titleSize)
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSubtitleSpacing), size: textSize)
        let buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonWidth) / 2.0), y: textFrame.maxY + buttonSpacing), size: CGSize(width: buttonWidth, height: buttonHeight))
        let privacyButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - privacyButtonSize.width) / 2.0), y: buttonFrame.maxY + floor((privacySpacing - privacyButtonSize.height) / 2.0)), size: privacyButtonSize)
        
        
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.actionButton, frame: buttonFrame)
        transition.updateFrame(node: self.privacyPolicyButton, frame: privacyButtonFrame)
    }
}
