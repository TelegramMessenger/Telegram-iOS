import Foundation
import UIKit
import SwiftSignalKit
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
import CheckNode
import Markdown
import TextFormat
import StarsBalanceOverlayComponent

private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

private func formattedText(_ text: String, fontSize: CGFloat, color: UIColor, linkColor: UIColor, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(fontSize), textColor: color), bold: MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: color), link: MarkdownAttributeSet(font: Font.regular(fontSize), textColor: linkColor), linkAttribute: { _ in return (TelegramTextAttributes.URL, "") }), textAlignment: textAlignment)
}

private final class ChatMessagePaymentAlertContentNode: AlertContentNode, ASGestureRecognizerDelegate {
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    private let optionText: String?
    private let alignment: TextAlertContentActionLayout
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
        
    private let checkNode: InteractiveCheckNode
    private let checkLabelNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
        
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    var dontAskAgain: Bool = false {
        didSet {
            self.checkNode.setSelected(self.dontAskAgain, animated: true)

        }
    }
    
    var openTerms: () -> Void = {}
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, title: String, text: String, optionText: String?, actions: [TextAlertAction], alignment: TextAlertContentActionLayout) {
        self.strings = strings
        self.title = title
        self.text = text
        self.optionText = optionText
        self.alignment = alignment
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.displaysAsynchronously = false
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.checkNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: theme.accentColor, strokeColor: theme.contrastColor, borderColor: theme.controlBorderColor, overlayBorder: false, hasInset: false, hasShadow: false))
        self.checkLabelNode = ImmediateTextNode()
        self.checkLabelNode.maximumNumberOfLines = 4
       
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

        if let _ = optionText {
            self.addSubnode(self.checkNode)
            self.addSubnode(self.checkLabelNode)
        }
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
                
        self.checkNode.valueChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.dontAskAgain = !strongSelf.dontAskAgain
            }
        }
        
        self.checkLabelNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.checkLabelNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTerms()
            }
        }
        
        self.updateTheme(theme)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.acceptTap(_:)))
        tapGesture.delegate = self.wrappedGestureRecognizerDelegate
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self.checkLabelNode.view)
        if self.checkLabelNode.bounds.contains(location) {
            return true
        }
        return false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if let (_, attributes) = self.checkLabelNode.attributesAtPoint(self.view.convert(point, to: self.checkLabelNode.view)) {
            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] == nil {
                return self.view
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    @objc private func acceptTap(_ gestureRecognizer: UITapGestureRecognizer) {
        self.dontAskAgain = !self.dontAskAgain
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.semibold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = formattedText(self.text, fontSize: 13.0, color: theme.primaryColor, linkColor: theme.accentColor, textAlignment: .center)

        self.checkLabelNode.attributedText = parseMarkdownIntoAttributedString(
            self.optionText ?? "",
            attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: theme.primaryColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: theme.primaryColor),
                link: MarkdownAttributeSet(font: textFont, textColor: theme.primaryColor),
                linkAttribute: { _ in
                    return nil
                }
            )
        )
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
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 17.0)
                
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        var entriesHeight: CGFloat = 0.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height
        
        if self.checkLabelNode.supernode != nil {
            origin.y += 21.0
            entriesHeight += 21.0
            
            let checkSize = CGSize(width: 22.0, height: 22.0)
            let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
            
            let spacing: CGFloat = 12.0
            let acceptTermsSize = self.checkLabelNode.updateLayout(condensedSize)
            let acceptTermsTotalWidth = checkSize.width + spacing + acceptTermsSize.width
            let acceptTermsOriginX = floorToScreenPixels((size.width - acceptTermsTotalWidth) / 2.0)
            
            transition.updateFrame(node: self.checkNode, frame: CGRect(origin: CGPoint(x: acceptTermsOriginX, y: origin.y - 3.0), size: checkSize))
            transition.updateFrame(node: self.checkLabelNode, frame: CGRect(origin: CGPoint(x: acceptTermsOriginX + checkSize.width + spacing, y: origin.y), size: acceptTermsSize))
            origin.y += acceptTermsSize.height
            entriesHeight += acceptTermsSize.height
            origin.y += 21.0
        }
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = self.alignment
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
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
        
        let contentWidth = max(size.width, minActionsWidth)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultSize = CGSize(width: contentWidth, height: titleSize.height + textSize.height + entriesHeight + actionsHeight + 3.0 + insets.top + insets.bottom)
        
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

public class ChatMessagePaymentAlertController: AlertController {
    private let context: AccountContext?
    private let presentationData: PresentationData
    private weak var parentNavigationController: NavigationController?
    private let showBalance: Bool
   
    private let balance = ComponentView<Empty>()
    
    private var didAppear = false
    
    public init(context: AccountContext?, presentationData: PresentationData, contentNode: AlertContentNode, navigationController: NavigationController?, showBalance: Bool = true) {
        self.context = context
        self.presentationData = presentationData
        self.parentNavigationController = navigationController
        self.showBalance = showBalance
        
        super.init(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
        
        self.willDismiss = { [weak self] in
            guard let self else {
                return
            }
            self.animateOut()
        }
    }
        
    required public init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }
    
    private func animateOut() {
        if let view = self.balance.view {
            view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false)
            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
    }
    
    public override func dismissAnimated() {
        super.dismissAnimated()
        
        self.animateOut()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didAppear {
            self.didAppear = true
            if !layout.metrics.isTablet && layout.size.width > layout.size.height {
                Queue.mainQueue().after(0.1) {
                    self.view.window?.endEditing(true)
                }
            }
        }
        
        if let context = self.context, let _ = self.parentNavigationController, self.showBalance {
            let insets = layout.insets(options: .statusBar)
            let balanceSize = self.balance.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: context,
                        theme: self.presentationData.theme,
                        action: { [weak self] in
                            guard let self, let starsContext = context.starsContext, let navigationController = self.parentNavigationController else {
                                return
                            }
                            self.dismissAnimated()
                            
                            let _ = (context.engine.payments.starsTopUpOptions()
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { options in
                                let controller = context.sharedContext.makeStarsPurchaseScreen(
                                    context: context,
                                    starsContext: starsContext,
                                    options: options,
                                    purpose: .generic,
                                    completion: { _ in }
                                )
                                navigationController.pushViewController(controller)
                            })
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            if let view = self.balance.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                    
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - balanceSize.width) / 2.0), y: insets.top + 5.0), size: balanceSize)
            }
        }
    }
}

public func chatMessagePaymentAlertController(
    context: AccountContext?,
    presentationData: PresentationData,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    peers: [EngineRenderedPeer],
    count: Int32,
    amount: StarsAmount,
    totalAmount: StarsAmount?,
    hasCheck: Bool = true,
    navigationController: NavigationController?,
    completion: @escaping (Bool) -> Void
) -> AlertController {
    let theme = defaultDarkColorPresentationTheme
    let presentationData = updatedPresentationData?.initial ?? presentationData
    let strings = presentationData.strings
    
    var completionImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    
    let title = presentationData.strings.Chat_PaidMessage_Confirm_Title
    let actionTitle = presentationData.strings.Chat_PaidMessage_Confirm_PayForMessage(count)
    let messagesString = presentationData.strings.Chat_PaidMessage_Confirm_Text_Messages(count)
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: actionTitle, action: {
        completionImpl?()
        dismissImpl?()
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    })]

    let text: String
    if peers.count == 1, let peer = peers.first {
        let amountString = presentationData.strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(amount.value))
        let totalString = presentationData.strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(amount.value * Int64(count)))
        if case let .channel(channel) = peer.chatOrMonoforumMainPeer, case .broadcast = channel.info {
            text = presentationData.strings.Chat_PaidMessage_Confirm_SingleComment_Text(EnginePeer(channel).compactDisplayTitle, amountString, totalString, messagesString).string
        } else {
            text = presentationData.strings.Chat_PaidMessage_Confirm_Single_Text(peer.chatOrMonoforumMainPeer?.compactDisplayTitle ?? " ", amountString, totalString, messagesString).string
        }
    } else {
        let amount = totalAmount ?? amount
        let usersString = presentationData.strings.Chat_PaidMessage_Confirm_Text_Users(Int32(peers.count))
        let totalString = presentationData.strings.Chat_PaidMessage_Confirm_Text_Stars(Int32(amount.value * Int64(count)))
        text = presentationData.strings.Chat_PaidMessage_Confirm_Multiple_Text(usersString, totalString, messagesString).string
    }
    
    let optionText = hasCheck ? presentationData.strings.Chat_PaidMessage_Confirm_DontAskAgain : nil
    
    let contentNode = ChatMessagePaymentAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, title: title, text: text, optionText: optionText, actions: actions, alignment: .vertical)
    
    completionImpl = { [weak contentNode] in
        guard let contentNode else {
            return
        }
        completion(contentNode.dontAskAgain)
    }
    
    let controller = ChatMessagePaymentAlertController(context: context, presentationData: presentationData, contentNode: contentNode, navigationController: navigationController)
    dismissImpl = { [weak controller]  in
        controller?.dismissAnimated()
    }
    return controller
}

public func chatMessageRemovePaymentAlertController(
    context: AccountContext? = nil,
    presentationData: PresentationData,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    peer: EnginePeer,
    amount: StarsAmount?,
    navigationController: NavigationController?,
    completion: @escaping (Bool) -> Void
) -> AlertController {
    let theme = defaultDarkColorPresentationTheme
    let presentationData = updatedPresentationData?.initial ?? presentationData
    let strings = presentationData.strings
    
    var completionImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [
        TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {
            dismissImpl?()
        }),
        TextAlertAction(type: .defaultAction, title: strings.Chat_PaidMessage_RemoveFee_Yes, action: {
            completionImpl?()
            dismissImpl?()
        })
    ]
    
    let title = strings.Chat_PaidMessage_RemoveFee_Title
    let text = strings.Chat_PaidMessage_RemoveFee_Text(peer.compactDisplayTitle).string
    let optionText = amount.flatMap { strings.Chat_PaidMessage_RemoveFee_Refund(strings.Chat_PaidMessage_RemoveFee_Refund_Stars(Int32($0.value))).string }
    
    let contentNode = ChatMessagePaymentAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, title: title, text: text, optionText: optionText, actions: actions, alignment: .horizontal)
    
    completionImpl = { [weak contentNode] in
        guard let contentNode else {
            return
        }
        completion(contentNode.dontAskAgain)
    }
    
    let controller = ChatMessagePaymentAlertController(context: context, presentationData: presentationData, contentNode: contentNode, navigationController: navigationController)
    dismissImpl = { [weak controller]  in
        controller?.dismissAnimated()
    }
    return controller
}
