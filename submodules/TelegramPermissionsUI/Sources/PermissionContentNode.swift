import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import TelegramPermissions
import PeersNearbyIconNode
import SolidRoundedButtonNode
import PresentationDataUtils
import Markdown
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import AccountContext

public enum PermissionContentIcon: Equatable {
    case image(UIImage?)
    case icon(PermissionControllerCustomIcon)
    case animation(String)
    
    public func imageForTheme(_ theme: PresentationTheme) -> UIImage? {
        switch self {
            case let .image(image):
                return image
            case let .icon(icon):
                return theme.overallDarkAppearance ? (icon.dark ?? icon.light) : icon.light
            case .animation:
                return nil
        }
    }
}

public final class PermissionContentNode: ASDisplayNode {
    private var theme: PresentationTheme
    public let kind: Int32

    private let iconNode: ASImageNode
    private let nearbyIconNode: PeersNearbyIconNode?
    private let animationNode: AnimatedStickerNode?
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let actionButton: SolidRoundedButtonNode
    private let footerNode: ImmediateTextNode
    private let privacyPolicyButton: HighlightableButtonNode
    
    private let icon: PermissionContentIcon
    private var title: String
    private var text: String
    
    public var buttonAction: (() -> Void)?
    public var openPrivacyPolicy: (() -> Void)?
    
    public var validLayout: (CGSize, UIEdgeInsets)?
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, kind: Int32, icon: PermissionContentIcon, title: String, subtitle: String? = nil, text: String, buttonTitle: String, secondaryButtonTitle: String? = nil, footerText: String? = nil, buttonAction: @escaping () -> Void, openPrivacyPolicy: (() -> Void)?) {
        self.theme = theme
        self.kind = kind
        
        self.buttonAction = buttonAction
        self.openPrivacyPolicy = openPrivacyPolicy
        
        self.icon = icon
        self.title = title
        self.text = text
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        if case let .animation(animation) = icon {
            self.animationNode = AnimatedStickerNode()
            
            self.animationNode?.setup(source: AnimatedStickerNodeLocalFileSource(name: animation), width: 320, height: 320, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animationNode?.visibility = true
            
            self.nearbyIconNode = nil
        } else if kind == PermissionKind.nearbyLocation.rawValue {
            self.nearbyIconNode = PeersNearbyIconNode(theme: theme)
            self.animationNode = nil
        } else {
            self.nearbyIconNode = nil
            self.animationNode = nil
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.textAlignment = .center
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.displaysAsynchronously = false
        
        self.actionButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 52.0, cornerRadius: 9.0, gloss: true)
        
        self.footerNode = ImmediateTextNode()
        self.footerNode.textAlignment = .center
        self.footerNode.maximumNumberOfLines = 0
        self.footerNode.displaysAsynchronously = false
        
        self.privacyPolicyButton = HighlightableButtonNode()
        self.privacyPolicyButton.setTitle(secondaryButtonTitle ?? strings.Permissions_PrivacyPolicy, with: Font.regular(17.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()
        
        self.iconNode.image = icon.imageForTheme(theme)
        self.title = title
        
        var secondaryText = false
        if case .animation = icon {
            secondaryText = true
        }
        
        self.textNode.textAlignment = secondaryButtonTitle != nil ? .natural : .center
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: secondaryButtonTitle != nil ? theme.list.itemSecondaryTextColor : theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: secondaryText ? .natural : .center)
        
        self.actionButton.title = buttonTitle
        self.privacyPolicyButton.isHidden = openPrivacyPolicy == nil
        
        if let subtitle = subtitle {
            self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        if let footerText = footerText {
            self.footerNode.attributedText = NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        self.addSubnode(self.iconNode)
        self.nearbyIconNode.flatMap { self.addSubnode($0) }
        self.animationNode.flatMap { self.addSubnode($0) }
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionButton)
        self.addSubnode(self.footerNode)
        self.addSubnode(self.privacyPolicyButton)
        
        self.actionButton.pressed = { [weak self] in
            self?.buttonAction?()
        }
        
        self.privacyPolicyButton.addTarget(self, action: #selector(self.privacyPolicyPressed), forControlEvents: .touchUpInside)
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        let theme = presentationData.theme
        self.theme = theme
        
        self.iconNode.image = self.icon.imageForTheme(theme)
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(self.text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        if let subtitle = self.subtitleNode.attributedText?.string {
            self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        if let footerText = self.footerNode.attributedText?.string {
            self.footerNode.attributedText = NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        if let privacyPolicyTitle = self.privacyPolicyButton.attributedTitle(for: .normal)?.string {
            self.privacyPolicyButton.setTitle(privacyPolicyTitle, with: Font.regular(16.0), with: theme.list.itemAccentColor, for: .normal)
        }
        
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout.0, insets: validLayout.1, transition: .immediate)
        }
    }
    
    @objc private func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets)
        
        var sidePadding: CGFloat
        let fontSize: CGFloat
        if min(size.width, size.height) > 330.0 {
            fontSize = 24.0
            sidePadding = 36.0
        } else {
            fontSize = 20.0
            sidePadding = 20.0
        }
        sidePadding += insets.left
        
        let smallerSidePadding: CGFloat = 20.0 + insets.left
        
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(fontSize), textColor: self.theme.list.itemPrimaryTextColor)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: size.width - smallerSidePadding * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let buttonInset: CGFloat = 16.0
        let buttonWidth = min(size.width, size.height) - buttonInset * 2.0 - insets.left - insets.right
        let buttonHeight = self.actionButton.updateLayout(width: buttonWidth, transition: transition)
        let footerSize = self.footerNode.updateLayout(CGSize(width: size.width - smallerSidePadding * 2.0, height: .greatestFiniteMagnitude))
        let privacyButtonSize = self.privacyPolicyButton.measure(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        
        let availableHeight = floor(size.height - insets.top - insets.bottom - titleSize.height - subtitleSize.height - textSize.height - buttonHeight)
        
        let titleTextSpacing: CGFloat = max(15.0, floor(availableHeight * 0.045))
        let titleSubtitleSpacing: CGFloat = 6.0
        let buttonSpacing: CGFloat = max(19.0, floor(availableHeight * 0.075))
        var contentHeight = titleSize.height + titleTextSpacing + textSize.height + buttonHeight + buttonSpacing
        if subtitleSize.height > 0.0 {
            contentHeight += titleSubtitleSpacing + subtitleSize.height
        }
        
        var imageSize = CGSize()
        var imageSpacing: CGFloat = 0.0
        if let icon = self.iconNode.image, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = icon.size
            contentHeight += imageSize.height + imageSpacing
        }
        if let _ = self.nearbyIconNode, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = CGSize(width: 120.0, height: 120.0)
            contentHeight += imageSize.height + imageSpacing
        }
        if let _ = self.animationNode, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = CGSize(width: 240.0, height: 240.0)
            contentHeight += imageSize.height + imageSpacing
        }
        
        let privacySpacing: CGFloat = max(30.0 + privacyButtonSize.height, (availableHeight - titleTextSpacing - buttonSpacing - imageSize.height - imageSpacing) / 2.0)
        
        var verticalOffset: CGFloat = 0.0
        if size.height >= 568.0 {
            verticalOffset = availableHeight * 0.05
        }
        
        let contentOrigin = insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0) - verticalOffset
        let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let nearbyIconFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: iconFrame.maxY + imageSpacing), size: titleSize)
        
        let subtitleFrame: CGRect
        if subtitleSize.height > 0.0 {
            subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
        } else {
            subtitleFrame = titleFrame
        }
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: subtitleFrame.maxY + titleTextSpacing), size: textSize)
        let footerFrame = CGRect(origin: CGPoint(x: floor((size.width - footerSize.width) / 2.0), y: size.height - footerSize.height - insets.bottom - 8.0), size: footerSize)
        
        let buttonFrame: CGRect
        let privacyButtonFrame: CGRect
        if self.textNode.textAlignment == .natural {
            buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonWidth) / 2.0), y: max(textFrame.maxY + buttonSpacing ,size.height - buttonHeight - insets.bottom - 70.0)), size: CGSize(width: buttonWidth, height: buttonHeight))
            privacyButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - privacyButtonSize.width) / 2.0), y: buttonFrame.maxY + 29.0), size: privacyButtonSize)
        } else {
            buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonWidth) / 2.0), y: textFrame.maxY + buttonSpacing), size: CGSize(width: buttonWidth, height: buttonHeight))
            privacyButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - privacyButtonSize.width) / 2.0), y: buttonFrame.maxY + floor((privacySpacing - privacyButtonSize.height) / 2.0)), size: privacyButtonSize)
        }
        
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        if let nearbyIconNode = self.nearbyIconNode {
            transition.updateFrame(node: nearbyIconNode, frame: nearbyIconFrame)
        }
        if let animationNode = self.animationNode {
            transition.updateFrame(node: animationNode, frame: animationFrame)
            animationNode.updateLayout(size: animationFrame.size)
        }
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.actionButton, frame: buttonFrame)
        transition.updateFrame(node: self.footerNode, frame: footerFrame)
        transition.updateFrame(node: self.privacyPolicyButton, frame: privacyButtonFrame)
        
        self.footerNode.isHidden = size.height < 568.0
    }
}
