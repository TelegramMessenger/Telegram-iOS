import Foundation
import Display
import AsyncDisplayKit

final class PermissionContentNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let actionButton: SolidRoundedButtonNode
    private let privacyPolicyButton: HighlightableButtonNode
    
    var kind: PermissionStateKind
    private var title: String
    
    var buttonAction: (() -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, kind: PermissionStateKind, icon: UIImage?, title: String, text: String, buttonTitle: String, buttonAction: @escaping () -> Void, openPrivacyPolicy: (() -> Void)?) {
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
        //self.privacyPolicyButton.setTitle(strings.Permissions_PrivacyPolicy, with: Font.regular(16.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()
        
        self.iconNode.image = icon
        self.title = title
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.actionButton.title = buttonTitle
        self.privacyPolicyButton.isHidden = openPrivacyPolicy != nil
        
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
        let sidePadding: CGFloat = 20.0
        //let sideButtonInset: CGFloat = 16.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let buttonHeight = self.actionButton.updateLayout(width: size.width, transition: transition)
    
        let titleSubtitleSpacing: CGFloat = 12.0

        let textHeight = titleSize.height + titleSubtitleSpacing + textSize.height
        

        let minContentHeight = textHeight
        let contentHeight = min(215.0, max(size.height - insets.top - insets.bottom - 40.0, minContentHeight))
        let contentOrigin = insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentOrigin), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSubtitleSpacing), size: textSize))
        transition.updateFrame(node: self.actionButton, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: buttonHeight))
    }
}
