import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import Markdown
import ChatMessagePaymentAlertController
import ActivityIndicator
import MultilineTextWithEntitiesComponent
import TelegramStringFormatting
import TextFormat

private final class GiftRemoveInfoAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private let strings: PresentationStrings
    private var presentationTheme: PresentationTheme
    private let title: String
    private let text: String
    private let gift: StarGift.UniqueGift
    private let peers: [EnginePeer.Id: EnginePeer]
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let infoBackgroundNode: ASDisplayNode
    private let infoView = ComponentView<Empty>()
        
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var activityIndicator: ActivityIndicator?
        
    private var validLayout: CGSize?
    
    var inProgress = false {
        didSet {
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(
        context: AccountContext,
        theme: AlertControllerTheme,
        ptheme: PresentationTheme,
        strings: PresentationStrings,
        gift: StarGift.UniqueGift,
        peers: [EnginePeer.Id: EnginePeer],
        title: String,
        text: String,
        actions: [TextAlertAction]
    ) {
        self.context = context
        self.strings = strings
        self.presentationTheme = ptheme
        self.title = title
        self.text = text
        self.gift = gift
        self.peers = peers
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.infoBackgroundNode = ASDisplayNode()
        self.infoBackgroundNode.backgroundColor = ptheme.overallDarkAppearance ? ptheme.list.itemModalBlocksBackgroundColor : ptheme.list.itemPrimaryTextColor.withAlphaComponent(0.04)
        self.infoBackgroundNode.cornerRadius = 10.0
        self.infoBackgroundNode.displaysAsynchronously = false
        
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
    
        self.addSubnode(self.infoBackgroundNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.semibold(17.0), textColor: theme.primaryColor)
        self.textNode.attributedText = parseMarkdownIntoAttributedString(self.text, attributes: MarkdownAttributes(
            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor),
            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            linkAttribute: { url in
                return ("URL", url)
            }
        ), textAlignment: .center)
    
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
        size.width = min(size.width, 310.0)
        
        let strings = self.strings
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
                        
        let titleSize = self.titleNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 5.0
        
        let textSize = self.textNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 10.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
        }
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        let contentWidth = max(size.width, minActionsWidth)
                
        let actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        
        var infoSize: CGSize = .zero
        for attribute in self.gift.attributes {
            if case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities) = attribute {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                
                let tableFont = Font.regular(13.0)
                let tableBoldFont = Font.semibold(13.0)
                let tableItalicFont = Font.italic(13.0)
                let tableBoldItalicFont = Font.semiboldItalic(13.0)
                let tableMonospaceFont = Font.monospace(13.0)
                
                let tableTextColor = self.presentationTheme.list.itemPrimaryTextColor
                let tableLinkColor = self.presentationTheme.list.itemAccentColor
                
                let senderName = senderPeerId.flatMap { self.peers[$0]?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) }
                let recipientName = self.peers[recipientPeerId]?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) ?? ""
                
                let dateString = stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false)
                let value: NSAttributedString
                if let text {
                    let attributedText = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: tableTextColor, linkColor: tableLinkColor, baseFont: tableFont, linkFont: tableFont, boldFont: tableBoldFont, italicFont: tableItalicFont, boldItalicFont: tableBoldItalicFont, fixedFont: tableMonospaceFont, blockQuoteFont: tableFont, message: nil)
                    
                    let format = senderName != nil ? presentationData.strings.Gift_Unique_OriginalInfoSenderWithText(senderName!, recipientName, dateString, "") : presentationData.strings.Gift_Unique_OriginalInfoWithText(recipientName, dateString, "")
                    let string = NSMutableAttributedString(string: format.string, font: tableFont, textColor: tableTextColor)
                    string.replaceCharacters(in: format.ranges[format.ranges.count - 1].range, with: attributedText)
                    if let _ = senderPeerId {
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[1].range)
                    } else {
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                    }
                    value = string
                } else {
                    let format = senderName != nil ? presentationData.strings.Gift_Unique_OriginalInfoSender(senderName!, recipientName, dateString) : presentationData.strings.Gift_Unique_OriginalInfo(recipientName, dateString)
                    let string = NSMutableAttributedString(string: format.string, font: tableFont, textColor: tableTextColor)
                    if let _ = senderPeerId {
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[1].range)
                    } else {
                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                    }
                    
                    value = string
                }
                
                infoSize = self.infoView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextWithEntitiesComponent(
                            context: self.context,
                            animationCache: self.context.animationCache,
                            animationRenderer: self.context.animationRenderer,
                            placeholderColor: self.presentationTheme.list.mediaPlaceholderColor,
                            text: .plain(value),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            handleSpoilers: true
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 64.0, height: size.height)
                )
                let infoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - infoSize.width) / 2.0), y: titleSize.height + textSize.height + 54.0), size: infoSize)
                if let view = self.infoView.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    view.frame = infoFrame
                }
                self.infoBackgroundNode.frame = infoFrame.insetBy(dx: -12.0, dy: -12.0)
                
                break
            }
        }
       
        let resultSize = CGSize(width: contentWidth, height: titleSize.height + textSize.height + infoSize.height + actionsHeight + 46.0 + insets.top + insets.bottom)
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                do {
                    transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            do {
                currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            do {
                actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        if self.inProgress {
            let activityIndicator: ActivityIndicator
            if let current = self.activityIndicator {
                activityIndicator = current
            } else {
                activityIndicator = ActivityIndicator(type: .custom(self.presentationTheme.list.freeInputField.controlColor, 18.0, 1.5, false))
                self.addSubnode(activityIndicator)
            }
            
            if let actionNode = self.actionNodes.first {
                actionNode.isHidden = true
                
                let indicatorSize = CGSize(width: 22.0, height: 22.0)
                transition.updateFrame(node: activityIndicator, frame: CGRect(origin: CGPoint(x: actionNode.frame.minX + floor((actionNode.frame.width - indicatorSize.width) / 2.0), y: actionNode.frame.minY + floor((actionNode.frame.height - indicatorSize.height) / 2.0)), size: indicatorSize))
            }
        }
        
        return resultSize
    }
}

public func giftRemoveInfoAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peers: [EnginePeer.Id: EnginePeer],
    removeInfoStars: Int64,
    navigationController: NavigationController?,
    commit: @escaping () -> Void
) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Gift_RemoveDetails_Title
    let text = strings.Gift_RemoveDetails_Text
    let buttonText = strings.Gift_RemoveDetails_Action(" $  \(presentationStringsFormattedNumber(Int32(clamping: removeInfoStars), presentationData.dateTimeFormat.groupingSeparator))").string
   
    var contentNode: GiftRemoveInfoAlertContentNode?
    var dismissImpl: ((Bool) -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: buttonText, action: {
        dismissImpl?(true)
        commit()
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    contentNode = GiftRemoveInfoAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: strings, gift: gift, peers: peers, title: title, text: text, actions: actions)
    
    let controller = ChatMessagePaymentAlertController(context: context, presentationData: presentationData, contentNode: contentNode!, navigationController: navigationController, chatPeerId: context.account.peerId, showBalance: removeInfoStars > 0)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
