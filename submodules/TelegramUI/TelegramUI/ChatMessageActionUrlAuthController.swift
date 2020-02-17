import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import CheckNode
import TextFormat
import AccountContext
import Markdown

private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

private func formattedText(_ text: String, color: UIColor, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: color), bold: MarkdownAttributeSet(font: boldTextFont, textColor: color), link: MarkdownAttributeSet(font: textFont, textColor: color), linkAttribute: { _ in return nil}), textAlignment: textAlignment)
}

private final class ChatMessageActionUrlAuthAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let defaultUrl: String
    private let domain: String
    private let bot: Peer
    private let displayName: String
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let authorizeCheckNode: CheckNode
    private let authorizeLabelNode: ASTextNode
    private let allowWriteCheckNode: CheckNode
    private let allowWriteLabelNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    var authorize: Bool = true {
        didSet {
            self.authorizeCheckNode.setIsChecked(self.authorize, animated: true)
            self.allowWriteCheckNode.isUserInteractionEnabled = self.authorize
            self.allowWriteCheckNode.alpha = self.authorize ? 1.0 : 0.4
            self.allowWriteLabelNode.alpha = self.authorize ? 1.0 : 0.4
            if !self.authorize && self.allowWriteAccess {
                self.allowWriteAccess = false
            }
        }
    }
    
    var allowWriteAccess: Bool = true {
        didSet {
            self.allowWriteCheckNode.setIsChecked(self.allowWriteAccess, animated: true)
        }
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, defaultUrl: String, domain: String, bot: Peer, requestWriteAccess: Bool, displayName: String, actions: [TextAlertAction]) {
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.defaultUrl = defaultUrl
        self.domain = domain
        self.bot = bot
        self.displayName = displayName
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.authorizeCheckNode = CheckNode(strokeColor: theme.separatorColor, fillColor: theme.accentColor, foregroundColor: .white, style: .plain)
        self.authorizeCheckNode.setIsChecked(true, animated: false)
        self.authorizeLabelNode = ASTextNode()
        self.authorizeLabelNode.maximumNumberOfLines = 4
        self.authorizeLabelNode.isUserInteractionEnabled = true
        
        self.allowWriteCheckNode = CheckNode(strokeColor: theme.separatorColor, fillColor: theme.accentColor, foregroundColor: .white, style: .plain)
        self.allowWriteCheckNode.setIsChecked(true, animated: false)
        self.allowWriteLabelNode = ASTextNode()
        self.allowWriteLabelNode.maximumNumberOfLines = 4
        self.allowWriteLabelNode.isUserInteractionEnabled = true
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.authorizeCheckNode)
        self.addSubnode(self.authorizeLabelNode)
        
        if requestWriteAccess {
            self.addSubnode(self.allowWriteCheckNode)
            self.addSubnode(self.allowWriteLabelNode)
        }
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.authorizeCheckNode.addTarget(target: self, action: #selector(self.authorizePressed))
        self.allowWriteCheckNode.addTarget(target: self, action: #selector(self.allowWritePressed))
        
        self.updateTheme(theme)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.authorizeLabelNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.authorizeTap(_:))))
        self.allowWriteLabelNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.allowWriteTap(_:))))
    }
    
    @objc private func authorizePressed() {
        self.authorize = !self.authorize
    }
    
    @objc private func authorizeTap(_ gestureRecognizer: UITapGestureRecognizer) {
         self.authorize = !self.authorize
    }
    
    @objc private func allowWriteTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if self.allowWriteCheckNode.isUserInteractionEnabled {
            self.allowWriteAccess = !self.allowWriteAccess
        }
    }
    
    @objc private func allowWritePressed() {
        self.allowWriteAccess = !self.allowWriteAccess
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: strings.Conversation_OpenBotLinkTitle, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.textNode.attributedText = formattedText(strings.Conversation_OpenBotLinkText(self.defaultUrl).0, color: theme.primaryColor, textAlignment: .center)
        self.authorizeLabelNode.attributedText = formattedText(strings.Conversation_OpenBotLinkLogin(self.domain, self.displayName).0, color: theme.primaryColor)
        self.allowWriteLabelNode.attributedText = formattedText(strings.Conversation_OpenBotLinkAllowMessages(self.bot.displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder)).0, color: theme.primaryColor)
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 9.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 16.0
        
        let checkSize = CGSize(width: 32.0, height: 32.0)
        let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
        
        var entriesHeight: CGFloat = 0.0
        
        let authorizeSize = self.authorizeLabelNode.measure(condensedSize)
        transition.updateFrame(node: self.authorizeLabelNode, frame: CGRect(origin: CGPoint(x: 46.0, y: origin.y), size: authorizeSize))
        transition.updateFrame(node: self.authorizeCheckNode, frame: CGRect(origin: CGPoint(x: 7.0, y: origin.y - 7.0), size: checkSize))
        origin.y += authorizeSize.height
        entriesHeight += authorizeSize.height
        
        if self.allowWriteLabelNode.supernode != nil {
            origin.y += 16.0
            entriesHeight += 16.0
            
            let allowWriteSize = self.allowWriteLabelNode.measure(condensedSize)
            transition.updateFrame(node: self.allowWriteLabelNode, frame: CGRect(origin: CGPoint(x: 46.0, y: origin.y), size: allowWriteSize))
            transition.updateFrame(node: self.allowWriteCheckNode, frame: CGRect(origin: CGPoint(x: 7.0, y: origin.y - 7.0), size: checkSize))
            origin.y += allowWriteSize.height
            entriesHeight += allowWriteSize.height
        }
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
        case .horizontal:
            actionsHeight = actionButtonHeight
        case .vertical:
            actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + entriesHeight + actionsHeight + 30.0 + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

func chatMessageActionUrlAuthController(context: AccountContext, defaultUrl: String, domain: String, bot: Peer, requestWriteAccess: Bool, displayName: String, open: @escaping (Bool, Bool) -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var contentNode: ChatMessageActionUrlAuthAlertContentNode?
    
    var dismissImpl: ((Bool) -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Conversation_OpenBotLinkOpen, action: {
        dismissImpl?(true)
        if let contentNode = contentNode {
            open(contentNode.authorize, contentNode.allowWriteAccess)
        }
    })]
    contentNode = ChatMessageActionUrlAuthAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, nameDisplayOrder: presentationData.nameDisplayOrder, defaultUrl: defaultUrl, domain: domain, bot: bot, requestWriteAccess: requestWriteAccess, displayName: displayName, actions: actions)
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
