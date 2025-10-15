import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
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
import TabSelectorComponent
import BundleIconComponent
import MultilineTextComponent
import TelegramStringFormatting
import TooltipUI

private final class GiftPurchaseAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private let strings: PresentationStrings
    private var presentationTheme: PresentationTheme
    private let gift: StarGift.UniqueGift
    private let peer: EnginePeer
    
    fileprivate var currency: CurrencyAmount.Currency
    
    fileprivate let header = ComponentView<Empty>()
    private let title = ComponentView<Empty>()
    private let text = ComponentView<Empty>()
    private let giftView = ComponentView<Empty>()
    private let arrow = ComponentView<Empty>()
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
    
    var updatedCurrency: (CurrencyAmount.Currency) -> Void = { _ in }
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(
        context: AccountContext,
        theme: AlertControllerTheme,
        presentationTheme: PresentationTheme,
        strings: PresentationStrings,
        gift: StarGift.UniqueGift,
        peer: EnginePeer,
        actions: [TextAlertAction]
    ) {
        self.context = context
        self.strings = strings
        self.presentationTheme = presentationTheme
        self.gift = gift
        self.peer = peer
                
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
        
        self.currency = self.gift.resellForTonOnly ? .ton : .stars
        
        super.init()
        
        self.addSubnode(self.avatarNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
        
        self.avatarNode.setPeer(context: context, theme: presentationTheme, peer: peer)
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
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
    
    func requestUpdate(transition: ContainedViewLayoutTransition) {
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: transition)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let containerSize = size
        var size = size
        size.width = min(size.width, 270.0)
        
        var origin = CGPoint(x: 0.0, y: 20.0)
        if self.gift.resellForTonOnly {
            let headerSize = self.header.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: self.strings.Gift_Buy_AcceptsTonOnly, font: Font.regular(13.0), textColor: self.presentationTheme.actionSheet.secondaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: size.height)
            )
            
            let headerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - headerSize.width) / 2.0), y: origin.y), size: headerSize)
            if let view = self.header.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                }
                view.frame = headerFrame
            }
            origin.y += headerSize.height + 17.0
        } else {
            origin.y -= 4.0

            let headerSize = self.header.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(TabSelectorComponent(
                    colors: TabSelectorComponent.Colors(
                        foreground: self.presentationTheme.list.itemSecondaryTextColor,
                        selection: self.presentationTheme.list.itemSecondaryTextColor.withMultipliedAlpha(0.15),
                        simple: true
                    ),
                    theme: self.presentationTheme,
                    customLayout: TabSelectorComponent.CustomLayout(
                        font: Font.medium(14.0),
                        spacing: 10.0
                    ),
                    items: [
                        TabSelectorComponent.Item(
                            id: AnyHashable(0),
                            content: .text(self.strings.Gift_Buy_PayInStars)
                        ),
                        TabSelectorComponent.Item(
                            id: AnyHashable(1),
                            content: .text(self.strings.Gift_Buy_PayInTon)
                        )
                    ],
                    selectedId: self.currency == .ton ? AnyHashable(1) : AnyHashable(0),
                    setSelectedId: { [weak self] id in
                        guard let self else {
                            return
                        }
                        let currency: CurrencyAmount.Currency
                        if id == AnyHashable(0) {
                            currency = .stars
                        } else {
                            currency = .ton
                        }
                        if self.currency != currency {
                            self.currency = currency
                            self.updatedCurrency(currency)
                            self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: containerSize.width - 16.0 * 2.0, height: 100.0)
            )
            
            size.width = min(containerSize.width, max(270.0, headerSize.width + 32.0))
            
            let headerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - headerSize.width) / 2.0), y: origin.y), size: headerSize)
            if let view = self.header.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                }
                view.frame = headerFrame
            }
            origin.y += headerSize.height + 17.0
        }
        
        self.validLayout = size
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                
        var resellPrice: CurrencyAmount?
        if let actionNode = self.actionNodes.first {
            switch self.currency {
            case .stars:
                if let resellAmount = self.gift.resellAmounts?.first(where: { $0.currency == .stars }) {
                    resellPrice = resellAmount
                    actionNode.action = TextAlertAction(type: .defaultAction, title: self.strings.Gift_Buy_Confirm_BuyFor(Int32(resellAmount.amount.value)), action: actionNode.action.action)
                }
            case .ton:
                if let resellAmount = self.gift.resellAmounts?.first(where: { $0.currency == .ton }) {
                    resellPrice = resellAmount
                    let valueString = formatTonAmountText(resellAmount.amount.value, dateTimeFormat: presentationData.dateTimeFormat)
                    actionNode.action = TextAlertAction(type: .defaultAction, title: self.strings.Gift_Buy_Confirm_BuyForTon(valueString).string, action: actionNode.action.action)
                }
            }
        }
        
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
        
        let arrowSize = self.arrow.update(
            transition: .immediate,
            component: AnyComponent(BundleIconComponent(name: "Peer Info/AlertArrow", tintColor: self.presentationTheme.actionSheet.secondaryTextColor)),
            environment: {},
            containerSize: size
        )
        let arrowFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - arrowSize.width) / 2.0), y: origin.y + floorToScreenPixels((avatarSize.height - arrowSize.height) / 2.0)), size: arrowSize)
        if let view = self.arrow.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            view.frame = arrowFrame
        }
        
        let avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0) + 44.0, y: origin.y), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        origin.y += avatarSize.height + 17.0
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(
                MultilineTextComponent(
                    text: .plain(NSAttributedString(string: self.strings.Gift_Buy_Confirm_Title, font: Font.semibold(17.0), textColor: self.presentationTheme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center
                )
            ),
            environment: {
            },
            containerSize: CGSize(width: size.width - 32.0, height: size.height)
        )
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize)
        if let view = self.title.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            view.frame = titleFrame
        }
        origin.y += titleSize.height + 5.0
        
        let giftTitle = "\(self.gift.title) #\(presentationStringsFormattedNumber(self.gift.number, presentationData.dateTimeFormat.groupingSeparator))"
        
        let priceString: String
        if let resellPrice {
            switch resellPrice.currency {
            case .stars:
                priceString = self.strings.Gift_Buy_Confirm_Text_Stars(Int32(clamping: resellPrice.amount.value))
            case .ton:
                priceString = "**\(formatTonAmountText(resellPrice.amount.value, dateTimeFormat: presentationData.dateTimeFormat)) TON**"
            }
        } else {
            priceString = ""
        }
        
        let text: String
        if self.peer.id == self.context.account.peerId {
            text = self.strings.Gift_Buy_Confirm_Text(giftTitle, priceString).string
        } else {
            text = self.strings.Gift_Buy_Confirm_GiftText(giftTitle, priceString, self.peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
        }
        
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(
                MultilineTextComponent(
                    text: .markdown(text: text, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: self.presentationTheme.actionSheet.primaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: self.presentationTheme.actionSheet.primaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: self.presentationTheme.actionSheet.primaryTextColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )
            ),
            environment: {
            },
            containerSize: CGSize(width: size.width - 32.0, height: size.height)
        )
        let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize)
        if let view = self.text.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            view.frame = textFrame
        }
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
        
        let resultSize = CGSize(width: contentWidth, height: origin.y + actionsHeight - 26.0 + insets.top + insets.bottom)
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
                actionNode.isUserInteractionEnabled = false
                actionNode.isHidden = false
                
                let indicatorSize = CGSize(width: 22.0, height: 22.0)
                transition.updateFrame(node: activityIndicator, frame: CGRect(origin: CGPoint(x: actionNode.frame.minX + floor((actionNode.frame.width - indicatorSize.width) / 2.0), y: actionNode.frame.minY + floor((actionNode.frame.height - indicatorSize.height) / 2.0)), size: indicatorSize))
            }
        }
        
        return resultSize
    }
}

public func giftPurchaseAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peer: EnginePeer,
    animateBalanceOverlay: Bool = false,
    navigationController: NavigationController?,
    commit: @escaping (CurrencyAmount.Currency) -> Void,
    dismissed: @escaping () -> Void
) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
                
    var contentNode: GiftPurchaseAlertContentNode?
    var dismissImpl: ((Bool) -> Void)?
    var commitImpl: (() -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: "", action: {
        commitImpl?()
        dismissImpl?(true)
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    contentNode = GiftPurchaseAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), presentationTheme: presentationData.theme, strings: strings, gift: gift, peer: peer, actions: actions)
    
    let controller = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        contentNode: contentNode!,
        navigationController: navigationController,
        chatPeerId: context.account.peerId,
        showBalance: true,
        currency: gift.resellForTonOnly ? .ton : .stars,
        animateBalanceOverlay: animateBalanceOverlay
    )
    controller.dismissed = { _ in
        dismissed()
    }
        
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    commitImpl = { [weak contentNode] in
        contentNode?.inProgress = true
        commit(contentNode?.currency ?? .stars)
    }
    
    contentNode?.updatedCurrency = { [weak controller] currency in
        controller?.currency = currency
    }
    
    if !gift.resellForTonOnly {
        Queue.mainQueue().after(0.3) {
            if let headerView = contentNode?.header.view as? TabSelectorComponent.View {
                let absoluteFrame = headerView.convert(headerView.bounds, to: nil)
                var originX = absoluteFrame.width * 0.75
                if let itemFrame = headerView.frameForItem(AnyHashable(1)) {
                    originX = itemFrame.midX
                }
                let location = CGRect(origin: CGPoint(x: absoluteFrame.minX + floor(originX), y: absoluteFrame.minY - 8.0), size: CGSize())
                let tooltipController = TooltipScreen(account: context.account, sharedContext: context.sharedContext, text: .plain(text: presentationData.strings.Gift_Buy_PayInTon_Tooltip), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: false)
                })
                controller.present(tooltipController, in: .window(.root))
            }
        }
    }
    
    return controller
}
