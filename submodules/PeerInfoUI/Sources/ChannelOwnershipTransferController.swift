import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import TextFormat
import AccountContext
import AlertUI
import PresentationDataUtils
import PasswordSetupUI
import Markdown

private final class ChannelOwnershipTransferPasswordFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: TextFieldNode
    private let placeholderNode: ASTextNode
    private var clearOnce: Bool = false
    private let inputActivityNode: ActivityIndicator
    
    private var isChecking = false
    
    var complete: (() -> Void)?
    var textChanged: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 8.0, left: 22.0, bottom: 15.0, right: 22.0)
    private let inputInsets = UIEdgeInsets(top: 5.0, left: 11.0, bottom: 5.0, right: 11.0)
    
    var password: String {
        get {
            return self.textInputNode.textField.text ?? ""
        }
        set {
            self.textInputNode.textField.text = newValue
            self.placeholderNode.isHidden = !newValue.isEmpty
        }
    }
    
    var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        }
    }
    
    init(theme: PresentationTheme, placeholder: String) {
        self.theme = theme
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: UIScreenPixel)
        
        self.textInputNode = TextFieldNode()

        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(14.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        
        self.inputActivityNode = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 18.0, 1.5, false))
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.inputActivityNode)
        
        self.inputActivityNode.isHidden = true
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textInputNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(14.0), NSAttributedString.Key.foregroundColor: self.theme.actionSheet.inputTextColor]
        self.textInputNode.textField.font = Font.regular(14.0)
        self.textInputNode.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.textInputNode.textField.isSecureTextEntry = true
        self.textInputNode.textField.returnKeyType = .done
        self.textInputNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.clipsToBounds = true
        self.textInputNode.textField.delegate = self
        self.textInputNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textField.tintColor = self.theme.list.itemAccentColor
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: UIScreenPixel)
        self.textInputNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.textField.textColor = theme.list.itemPrimaryTextColor
        self.textInputNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(14.0), NSAttributedString.Key.foregroundColor: theme.actionSheet.inputTextColor]
        self.textInputNode.textField.tintColor = theme.list.itemAccentColor
        self.placeholderNode.attributedText = NSAttributedString(string: self.placeholderNode.attributedText?.string ?? "", font: Font.regular(14.0), textColor: theme.actionSheet.inputPlaceholderColor)
    }
    
    func updateIsChecking(_ isChecking: Bool) {
        self.isChecking = isChecking
        self.inputActivityNode.isHidden = !isChecking
    }
    
    func updateIsInvalid() {
        self.clearOnce = true
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let textFieldHeight: CGFloat = 30.0
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right, height: backgroundFrame.size.height)))
        
        let activitySize = CGSize(width: 18.0, height: 18.0)
        transition.updateFrame(node: self.inputActivityNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX - activitySize.width - 6.0, y: backgroundFrame.minY + floor((backgroundFrame.height - activitySize.height) / 2.0)), size: activitySize))
        
        return panelHeight
    }
    
    func activateInput() {
        self.textInputNode.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        self.textChanged?(editableTextNode.textView.text)
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
    }
    
    @objc func textFieldTextChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        self.textChanged?(text)
        self.placeholderNode.isHidden = !text.isEmpty
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.isChecking {
            return false
        }
        
        if string == "\n" {
            self.complete?()
            return false
        }
        
        if self.clearOnce {
            self.clearOnce = false
            if range.length > string.count {
                textField.text = ""
                return false
            }
        }
        
        return true
    }
}

public final class ChannelOwnershipTransferAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    fileprivate let inputFieldNode: ChannelOwnershipTransferPasswordFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    private let hapticFeedback = HapticFeedback()
    
    public var complete: (() -> Void)? {
        didSet {
            self.inputFieldNode.complete = self.complete
        }
    }
    
    public var theme: PresentationTheme {
        didSet {
            self.inputFieldNode.updateTheme(self.theme)
        }
    }
    
    public override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    public init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction]) {
        self.strings = strings
        self.theme = ptheme
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 2
        
        self.inputFieldNode = ChannelOwnershipTransferPasswordFieldNode(theme: ptheme, placeholder: strings.Channel_OwnershipTransfer_PasswordPlaceholder)
        
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
        
        self.addSubnode(self.inputFieldNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        self.actionNodes.last?.actionEnabled = false
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.inputFieldNode.textChanged = { [weak self] text in
            if let strongSelf = self, let lastNode = strongSelf.actionNodes.last {
                lastNode.actionEnabled = !text.isEmpty
            }
        }
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func dismissInput() {
        self.inputFieldNode.deactivateInput()
    }
    
    public var password: String {
        return self.inputFieldNode.password
    }
    
    public func updateIsChecking(_ checking: Bool) {
        self.inputFieldNode.updateIsChecking(checking)
    }
    
    public override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Channel_OwnershipTransfer_EnterPassword, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.strings.Channel_OwnershipTransfer_EnterPasswordText, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
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
    
    public override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 6.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
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
        
        let inputFieldWidth = resultWidth
        let inputFieldHeight = self.inputFieldNode.updateLayout(width: inputFieldWidth, transition: transition)
        let inputHeight = inputFieldHeight
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(x: 0.0, y: origin.y, width: resultWidth, height: inputFieldHeight))
        transition.updateAlpha(node: self.inputFieldNode, alpha: inputHeight > 0.0 ? 1.0 : 0.0)
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + actionsHeight + inputHeight + insets.top + insets.bottom)
        
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
        
        if !hadValidLayout {
            self.inputFieldNode.activateInput()
        }
        
        return resultSize
    }
    
    public func animateError() {
        self.inputFieldNode.updateIsInvalid()
        self.inputFieldNode.layer.addShakeAnimation()
        self.hapticFeedback.error()
    }
}

private func commitChannelOwnershipTransferController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: Peer, member: TelegramUser, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (PeerId?) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.OwnershipTransfer_Transfer, action: {
        proceedImpl?()
    })])
    
    contentNode.complete = {
        proceedImpl?()
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.inputFieldNode.updateTheme(presentationData.theme)
    })
    controller.dismissed = {
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
        
        let signal: Signal<PeerId?, ChannelOwnershipTransferError>
        if let peer = peer as? TelegramChannel {
            signal = context.peerChannelMemberCategoriesContextsManager.transferOwnership(engine: context.engine, peerId: peer.id, memberId: member.id, password: contentNode.password) |> mapToSignal { _ in
                return .complete()
            }
            |> then(.single(nil))
        } else if let peer = peer as? TelegramGroup {
            signal = context.engine.peers.convertGroupToSupergroup(peerId: peer.id)
            |> map(Optional.init)
            |> mapError { error -> ChannelOwnershipTransferError in
                switch error {
                case .tooManyChannels:
                    return .tooMuchJoined
                default:
                    return .generic
                }
            }
            |> deliverOnMainQueue
            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ChannelOwnershipTransferError> in
                guard let upgradedPeerId = upgradedPeerId else {
                    return .fail(.generic)
                }
                return context.peerChannelMemberCategoriesContextsManager.transferOwnership(engine: context.engine, peerId: upgradedPeerId, memberId: member.id, password: contentNode.password) |> mapToSignal { _ in
                    return .complete()
                }
                |> then(.single(upgradedPeerId))
            }
        } else {
            signal = .never()
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { upgradedPeerId in
            dismissImpl?()
            completion(upgradedPeerId)
        }, error: { [weak contentNode] error in
            var isGroup = true
            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                isGroup = false
            }
            
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
                case .tooMuchJoined:
                    pushControllerImpl?(oldChannelsController(context: context, intent: .upgrade))
                    return
                case .invalidPassword:
                    contentNode?.animateError()
                case .limitExceeded:
                    errorTextAndActions = (presentationData.strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                case .adminsTooMuch:
                    errorTextAndActions = (isGroup ? presentationData.strings.Group_OwnershipTransfer_ErrorAdminsTooMuch :  presentationData.strings.Channel_OwnershipTransfer_ErrorAdminsTooMuch, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                case .userPublicChannelsTooMuch:
                    errorTextAndActions = (presentationData.strings.Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                case .userLocatedGroupsTooMuch:
                    errorTextAndActions = (presentationData.strings.Group_OwnershipTransfer_ErrorLocatedGroupsTooMuch, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                case .userBlocked, .restricted:
                    errorTextAndActions = (isGroup ? presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted :  presentationData.strings.Channel_OwnershipTransfer_ErrorPrivacyRestricted, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
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
    
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    
    return controller
}

private func confirmChannelOwnershipTransferController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: Peer, member: TelegramUser, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (PeerId?) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationData: presentationData)
    
    var isGroup = true
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        isGroup = false
    }
    
    var title: String
    var text: String
    if isGroup {
        title = presentationData.strings.Group_OwnershipTransfer_Title
        text = presentationData.strings.Group_OwnershipTransfer_DescriptionInfo(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), EnginePeer(member).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
    } else {
        title = presentationData.strings.Channel_OwnershipTransfer_Title
        text = presentationData.strings.Channel_OwnershipTransfer_DescriptionInfo(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), EnginePeer(member).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
    }
    
    let attributedTitle = NSAttributedString(string: title, font: Font.medium(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
    let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor)
    let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor)
    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
    
    let controller = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Channel_OwnershipTransfer_ChangeOwner, action: {
        present(commitChannelOwnershipTransferController(context: context, peer: peer, member: member, present: present, completion: completion), nil)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {
    })], actionLayout: .vertical)
    return controller
}

func channelOwnershipTransferController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: Peer, member: TelegramUser, initialError: ChannelOwnershipTransferError, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (PeerId?) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationData: presentationData)
    
    var title: NSAttributedString? = NSAttributedString(string: presentationData.strings.OwnershipTransfer_SecurityCheck, font: Font.medium(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center)
    
    var text = presentationData.strings.OwnershipTransfer_SecurityRequirements
    var isGroup = true
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        isGroup = false
    }
    
    var actions: [TextAlertAction] = []
    
    switch initialError {
        case .requestPassword:
            return confirmChannelOwnershipTransferController(context: context, updatedPresentationData: updatedPresentationData, peer: peer, member: member, present: present, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.OwnershipTransfer_ComeBackLater
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        case .twoStepAuthMissing:
            actions = [TextAlertAction(type: .genericAction, title: presentationData.strings.OwnershipTransfer_SetupTwoStepAuth, action: {
                let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})]
        case .adminsTooMuch:
            title = nil
            text = isGroup ? presentationData.strings.Group_OwnershipTransfer_ErrorAdminsTooMuch :  presentationData.strings.Channel_OwnershipTransfer_ErrorAdminsTooMuch
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        case .userPublicChannelsTooMuch:
            title = nil
            text = presentationData.strings.Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        case .userBlocked, .restricted:
            title = nil
            text = isGroup ? presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted :  presentationData.strings.Channel_OwnershipTransfer_ErrorPrivacyRestricted
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        default:
            title = nil
            text = presentationData.strings.Login_UnknownError
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
    }
    
    let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor)
    let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor)
    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
    
    return richTextAlertController(context: context, title: title, text: attributedText, actions: actions)
}
