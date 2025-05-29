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
import AvatarNode
import Markdown
import GiftItemComponent
import ChatMessagePaymentAlertController
import ActivityIndicator

private final class GiftTransferAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private let strings: PresentationStrings
    private var presentationTheme: PresentationTheme
    private let title: String
    private let text: String
    private let gift: StarGift.UniqueGift
    
    private let titleNode: ASTextNode
    private let giftView = ComponentView<Empty>()
    private let textNode: ASTextNode
    private let arrowNode: ASImageNode
    private let avatarNode: AvatarNode
    
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
        peer: EnginePeer,
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
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
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
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.avatarNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
        
        self.avatarNode.setPeer(context: context, theme: ptheme, peer: peer)
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
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/AlertArrow"), color: theme.secondaryColor)
        
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
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let avatarSize = CGSize(width: 60.0, height: 60.0)
        self.avatarNode.updateSize(size: avatarSize)
        
        let giftFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0) - 44.0, y: origin.y), size: avatarSize)
        
        let _ = self.giftView.update(
            transition: .immediate,
            component: AnyComponent(
                GiftItemComponent(
                    context: self.context,
                    theme: self.presentationTheme,
                    strings: self.strings,
                    peer: nil,
                    subject: .uniqueGift(gift: self.gift, price: nil),
                    mode: .thumbnail
                )
            ),
            environment: {},
            containerSize: avatarSize
        )
        if let view = self.giftView.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            view.frame = giftFrame
        }
        
        if let arrowImage = self.arrowNode.image {
            let arrowFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - arrowImage.size.width) / 2.0), y: origin.y + floorToScreenPixels((avatarSize.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }
        
        let avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0) + 44.0, y: origin.y), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
                
        origin.y += avatarSize.height + 17.0
        
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
        
        let resultSize = CGSize(width: contentWidth, height: avatarSize.height + titleSize.height + textSize.height + actionsHeight + 24.0 + insets.top + insets.bottom)
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        //let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                /*switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:*/
                do {
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            /*switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:*/
            do {
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            /*switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:*/
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

public func giftTransferAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peer: EnginePeer,
    transferStars: Int64,
    navigationController: NavigationController?,
    commit: @escaping () -> Void
) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Gift_Transfer_Confirmation_Title
    let text: String
    let buttonText: String
    if transferStars > 0 {
        text = strings.Gift_Transfer_Confirmation_Text("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))", peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), strings.Gift_Transfer_Confirmation_Text_Stars(Int32(transferStars))).string
        buttonText = "\(strings.Gift_Transfer_Confirmation_Transfer)  $  \(transferStars)"
    } else {
        text = strings.Gift_Transfer_Confirmation_TextFree("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))", peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
        buttonText = strings.Gift_Transfer_Confirmation_TransferFree
    }
    
    var contentNode: GiftTransferAlertContentNode?
    var dismissImpl: ((Bool) -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: buttonText, action: { [weak contentNode] in
        contentNode?.inProgress = true
        commit()
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    contentNode = GiftTransferAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: strings, gift: gift, peer: peer, title: title, text: text, actions: actions)
    
    let controller = ChatMessagePaymentAlertController(context: context, presentationData: presentationData, contentNode: contentNode!, navigationController: navigationController, showBalance: transferStars > 0)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
