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
import Markdown
import GiftItemComponent
import StarsAvatarComponent
import PasswordSetupUI
import OwnershipTransferController
import PresentationDataUtils

private final class GiftWithdrawAlertContentNode: AlertContentNode {
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
    private let avatarView = ComponentView<Empty>()
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
        
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(
        context: AccountContext,
        theme: AlertControllerTheme,
        ptheme: PresentationTheme,
        strings: PresentationStrings,
        gift: StarGift.UniqueGift,
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
        let _ = self.avatarView.update(
            transition: .immediate,
            component: AnyComponent(
                StarsAvatarComponent(
                    context: self.context,
                    theme: self.presentationTheme,
                    peer: .fragment,
                    photo: nil,
                    media: [],
                    uniqueGift: nil,
                    backgroundColor: .clear,
                    size: avatarSize
                )
            ),
            environment: {},
            containerSize: avatarSize
        )
        if let view = self.avatarView.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            view.frame = avatarFrame
        }
        
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
        
        var effectiveActionLayout = TextAlertContentActionLayout.vertical
        if !"".isEmpty {
            // Silence the warning
            effectiveActionLayout = .horizontal
        }
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

public func giftWithdrawAlertController(context: AccountContext, gift: StarGift.UniqueGift, commit: @escaping () -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Gift_Withdraw_Title
    let text = strings.Gift_Withdraw_Text("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))").string
    let buttonText = strings.Gift_Withdraw_Proceed
    
    var dismissImpl: ((Bool) -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: buttonText, action: {
        dismissImpl?(true)
        commit()
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    let contentNode = GiftWithdrawAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: strings, gift: gift, title: title, text: text, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}

public func confirmGiftWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, reference: StarGiftReference, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.Gift_Withdraw_EnterPassword_Title, text: presentationData.strings.Gift_Withdraw_EnterPassword_Text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Withdraw_EnterPassword_Done, action: {
        proceedImpl?()
    })])
    
    contentNode.complete = {
        proceedImpl?()
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.theme = presentationData.theme
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
        disposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] in
        contentNode?.dismissInput()
        controller?.dismissAnimated()
    }
    proceedImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        contentNode.updateIsChecking(true)
        
        let signal = context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: contentNode.password)
        disposable.set((signal |> deliverOnMainQueue).start(next: { url in
            dismissImpl?()
            completion(url)
        }, error: { [weak contentNode] error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
                case .invalidPassword:
                    contentNode?.animateError()
                case .limitExceeded:
                    errorTextAndActions = (presentationData.strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                default:
                    errorTextAndActions = (presentationData.strings.Login_UnknownError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            }
            contentNode?.updateIsChecking(false)
            
            if let (text, actions) = errorTextAndActions {
                dismissImpl?()
                present(textAlertController(context: context, title: nil, text: text, actions: actions), nil)
            }
        }))
    }
    
    return controller
}

public func giftWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, reference: StarGiftReference, initialError: RequestStarGiftWithdrawalError, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationData: presentationData)
    
    var title: NSAttributedString? = NSAttributedString(string: presentationData.strings.Gift_Withdraw_SecurityCheck, font: Font.semibold(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center)
    
    var text = presentationData.strings.Gift_Withdraw_SecurityRequirements
    let textFontSize = presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0
    
    var actions: [TextAlertAction] = []
    switch initialError {
        case .requestPassword:
        return confirmGiftWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, reference: reference, present: present, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.Gift_Withdraw_ComeBackLater
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        case .twoStepAuthMissing:
            actions = [TextAlertAction(type: .genericAction, title: presentationData.strings.Gift_Withdraw_SetupTwoStepAuth, action: {
                let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})]
        default:
            title = nil
            text = presentationData.strings.Login_UnknownError
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
    }
    
    let body = MarkdownAttributeSet(font: Font.regular(textFontSize), textColor: theme.primaryColor)
    let bold = MarkdownAttributeSet(font: Font.semibold(textFontSize), textColor: theme.primaryColor)
    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
    
    return richTextAlertController(context: context, title: title, text: attributedText, actions: actions)
}
