import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class PermissionControllerNode: ASDisplayNode {
    private let theme: AuthorizationTheme
    private let strings: PresentationStrings
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    private let privacyPolicyNode: HighlightableButtonNode
    private let nextNode: HighlightableButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private var title: String?
    
    var allow: (() -> Void)?
    var next: (() -> Void)? {
        didSet {
            self.nextNode.isHidden = self.next == nil
        }
    }
    var openPrivacyPolicy: (() -> Void)?
    var dismiss: (() -> Void)?
    
    init(theme: AuthorizationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
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
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.primaryColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.accentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.buttonNode = SolidRoundedButtonNode(theme: self.theme, height: 48.0, cornerRadius: 9.0)
        
        self.privacyPolicyNode = HighlightableButtonNode()
        self.privacyPolicyNode.setTitle("Privacy Policy", with: Font.regular(16.0), with: self.theme.accentColor, for: .normal)
        
        self.nextNode = HighlightableButtonNode()
        self.nextNode.setTitle("Skip", with: Font.regular(17.0), with: self.theme.accentColor, for: .normal)
        self.nextNode.isHidden = true
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.backgroundColor
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.privacyPolicyNode)
        self.addSubnode(self.nextNode)
        
        self.buttonNode.pressed = { [weak self] in
            self?.allow?()
        }
    
        self.privacyPolicyNode.addTarget(self, action: #selector(self.privacyPolicyPressed), forControlEvents: .touchUpInside)
        self.nextNode.addTarget(self, action: #selector(self.nextPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(subject: DeviceAccessSubject, currentStatus: AccessType) {
        var icon: UIImage?
        var title = ""
        var text = ""
        var buttonTitle = ""
        var hasPrivacyPolicy = false
        
        switch subject {
            case .contacts:
                icon = UIImage(bundleImageName: "Settings/Permissions/Contacts")
                title = "Sync Your Contacts"
                text = "See who's on Telegram and switch seamlessly, without having to \"add\" to add your friends."
                if currentStatus == .denied {
                    buttonTitle = "Allow in Settings"
                } else {
                    buttonTitle = "Allow Access"
                }
                hasPrivacyPolicy = true
            case .notifications:
                icon = UIImage(bundleImageName: "Settings/Permissions/Notifications")
                title = "Turn ON Notifications"
                text = "Don't miss important messages from your friends and coworkers."
                if currentStatus == .denied || currentStatus == .restricted {
                    buttonTitle = "Turn ON in Settings"
                } else {
                    buttonTitle = "Turn Notifications ON"
                }
            case .cellularData:
                icon = UIImage(bundleImageName: "Settings/Permissions/CellularData")
                title = "Turn ON Mobile Data"
                text = "Don't worry, Telegram keeps network usage to a minimum. You can further control this in Settings > Data and Storage."
                buttonTitle = "Turn ON in Settings"
            case .siri:
                title = "Turn ON Siri"
                text = "Use Siri to send messages and make calls."
                if currentStatus == .denied {
                    buttonTitle = "Turn ON in Settings"
                } else {
                    buttonTitle = "Turn Siri ON"
                }
            default:
                break
        }
        
        self.iconNode.image = icon
        self.title = title

        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: self.theme.primaryColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: self.theme.accentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.buttonNode.title = buttonTitle
        
        self.privacyPolicyNode.isHidden = !hasPrivacyPolicy
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.statusBar])
        let fontSize: CGFloat
        let sideInset: CGFloat
        if layout.size.width > 330.0 {
            fontSize = 22.0
            sideInset = 38.0
        } else {
            fontSize = 18.0
            sideInset = 20.0
        }
        
        let nextSize = self.nextNode.measure(layout.size)
        transition.updateFrame(node: self.nextNode, frame: CGRect(x: layout.size.width - insets.right - nextSize.width - 16.0, y: insets.top + 10.0 + 60.0, width: nextSize.width, height: nextSize.height))
        
        self.titleNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.semibold(fontSize), textColor: self.theme.primaryColor)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let buttonHeight = self.buttonNode.updateLayout(width: layout.size.width, transition: transition)

        var items: [AuthorizationLayoutItem] = []
        if let icon = self.iconNode.image {
            items.append(AuthorizationLayoutItem(node: self.iconNode, size: icon.size, spacingBefore: AuthorizationLayoutItemSpacing(weight: 122.0, maxValue: 122.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 15.0, maxValue: 15.0)))
        }
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.textNode, size: textSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 5.0, maxValue: 5.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 35.0, maxValue: 35.0)))
        items.append(AuthorizationLayoutItem(node: self.buttonNode, size: CGSize(width: layout.size.width, height: buttonHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 35.0, maxValue: 35.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 50.0)))
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
        
        let privacyPolicySize = self.privacyPolicyNode.measure(layout.size)
        transition.updateFrame(node: self.privacyPolicyNode, frame: CGRect(x: (layout.size.width - privacyPolicySize.width) / 2.0, y: self.buttonNode.frame.maxY + (layout.size.height - self.buttonNode.frame.maxY - insets.bottom - privacyPolicySize.height) / 2.0, width: privacyPolicySize.width, height: privacyPolicySize.height))
    }
    
    @objc func allowPressed() {
        self.allow?()
    }
    
    @objc func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
    
    @objc func nextPressed() {
        self.next?()
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
            completion?()
        })
    }
}
