import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import UrlEscaping

private final class VoiceChatTitleEditInputFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    private var theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: EditableTextNode
    private let placeholderNode: ASTextNode
    private let clearButton: HighlightableButtonNode
    
    var updateHeight: (() -> Void)?
    var complete: (() -> Void)?
    var textChanged: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 15.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 5.0, left: 12.0, bottom: 5.0, right: 12.0)
    
    var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputTextColor)
            self.placeholderNode.isHidden = !newValue.isEmpty
            if self.textInputNode.isFirstResponder() {
                self.clearButton.isHidden = newValue.isEmpty
            } else {
                self.clearButton.isHidden = true
            }
        }
    }
    
    var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        }
    }
    
    private let maxLength: Int
    
    init(theme: PresentationTheme, placeholder: String, maxLength: Int, returnKeyType: UIReturnKeyType = .done) {
        self.theme = theme
        self.maxLength = maxLength
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        
        self.textInputNode = EditableTextNode()
        self.textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: theme.actionSheet.inputTextColor]
        self.textInputNode.clipsToBounds = true
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textContainerInset = UIEdgeInsets(top: self.inputInsets.top, left: 0.0, bottom: self.inputInsets.bottom, right: 0.0)
        self.textInputNode.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.keyboardType = .default
        self.textInputNode.autocapitalizationType = .sentences
        self.textInputNode.returnKeyType = returnKeyType
        self.textInputNode.autocorrectionType = .default
        self.textInputNode.tintColor = theme.actionSheet.controlAccentColor
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        
        self.clearButton = HighlightableButtonNode()
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: theme.actionSheet.inputClearButtonColor), for: [])
        self.clearButton.isHidden = true
        
        super.init()
        
        self.textInputNode.delegate = self
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.clearButton)
        
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: self.theme.actionSheet.inputHollowBackgroundColor, strokeColor: self.theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        self.textInputNode.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.placeholderNode.attributedText = NSAttributedString(string: self.placeholderNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        self.textInputNode.tintColor = self.theme.actionSheet.controlAccentColor
        self.clearButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: theme.actionSheet.inputClearButtonColor), for: [])
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: width)
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right - 20.0, height: backgroundFrame.size.height)))
        
        if let image = self.clearButton.image(for: []) {
            transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX - 8.0 - image.size.width, y: backgroundFrame.minY + floor((backgroundFrame.size.height - image.size.height) / 2.0)), size: image.size))
        }
        
        return panelHeight
    }
    
    func activateInput() {
        self.textInputNode.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        self.updateTextNodeText(animated: true)
        self.textChanged?(editableTextNode.textView.text)
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
        self.clearButton.isHidden = !self.placeholderNode.isHidden
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.clearButton.isHidden = (editableTextNode.textView.text ?? "").isEmpty
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.clearButton.isHidden = true
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let updatedText = (editableTextNode.textView.text as NSString).replacingCharacters(in: range, with: text)
        if updatedText.count > maxLength {
            self.textInputNode.layer.addShakeAnimation()
            return false
        }
        if text == "\n" {
            self.complete?()
            return false
        }
        return true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let unboundTextFieldHeight = max(33.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right - 20.0, height: CGFloat.greatestFiniteMagnitude)).height))
        
        return min(61.0, max(33.0, unboundTextFieldHeight))
    }
    
    private func updateTextNodeText(animated: Bool) {
        let backgroundInsets = self.backgroundInsets
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: self.bounds.size.width)
        
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        if !self.bounds.size.height.isEqual(to: panelHeight) {
            self.updateHeight?()
        }
    }
    
    @objc func clearPressed() {
        self.placeholderNode.isHidden = false
        self.clearButton.isHidden = true
        
        self.textInputNode.attributedText = nil
        self.updateHeight?()
    }
}

private final class VoiceChatTitleEditAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    let inputFieldNode: VoiceChatTitleEditInputFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    private let hapticFeedback = HapticFeedback()
    
    var complete: (() -> Void)? {
        didSet {
            self.inputFieldNode.complete = self.complete
        }
    }
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], title: String, text: String, placeholder: String, value: String?, maxLength: Int) {
        self.strings = strings
        self.title = title
        self.text = text
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 8
        
        self.inputFieldNode = VoiceChatTitleEditInputFieldNode(theme: ptheme, placeholder: placeholder, maxLength: maxLength)
        self.inputFieldNode.text = value ?? ""
        
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
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.inputFieldNode.updateHeight = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.validLayout {
                    strongSelf.requestLayout?(.animated(duration: 0.15, curve: .spring))
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    var value: String {
        return self.inputFieldNode.text
    }

    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)

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
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        let spacing: CGFloat = 5.0
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 6.0 + spacing
        
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
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 9.0, right: 18.0)
        
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
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + spacing + inputHeight + actionsHeight  + insets.top + insets.bottom)
        
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
    
    func animateError() {
        self.inputFieldNode.layer.addShakeAnimation()
        self.hapticFeedback.error()
    }
}

func voiceChatTitleEditController(sharedContext: SharedAccountContext, account: Account, forceTheme: PresentationTheme?, title: String, text: String, placeholder: String, doneButtonTitle: String? = nil, value: String?, maxLength: Int, apply: @escaping (String?) -> Void) -> AlertController {
    var presentationData = sharedContext.currentPresentationData.with { $0 }
    if let forceTheme = forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: doneButtonTitle ?? presentationData.strings.Common_Done, action: {
        applyImpl?()
    })]
    
    let contentNode = VoiceChatTitleEditAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, title: title, text: text, placeholder: placeholder, value: value, maxLength: maxLength)
    contentNode.complete = {
        applyImpl?()
    }
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        dismissImpl?(true)
        
        let previousValue = value ?? ""
        let newValue = contentNode.value.trimmingCharacters(in: .whitespacesAndNewlines)
        apply(previousValue != newValue || value == nil ? newValue : nil)
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = sharedContext.presentationData.start(next: { [weak controller, weak contentNode] presentationData in
        var presentationData = presentationData
        if let forceTheme = forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.inputFieldNode.updateTheme(presentationData.theme)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] animated in
        contentNode?.inputFieldNode.deactivateInput()
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}

private final class VoiceChatUserNameEditAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let title: String
    
    private let titleNode: ASTextNode
    let firstNameInputFieldNode: VoiceChatTitleEditInputFieldNode
    let lastNameInputFieldNode: VoiceChatTitleEditInputFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    private let hapticFeedback = HapticFeedback()
    
    var complete: (() -> Void)? {
        didSet {
            self.lastNameInputFieldNode.complete = self.complete
        }
    }
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], title: String, firstNamePlaceholder: String, lastNamePlaceholder: String, firstNameValue: String?, lastNameValue: String?, maxLength: Int) {
        self.strings = strings
        self.title = title
    
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        
        self.firstNameInputFieldNode = VoiceChatTitleEditInputFieldNode(theme: ptheme, placeholder: firstNamePlaceholder, maxLength: maxLength, returnKeyType: .next)
        self.firstNameInputFieldNode.text = firstNameValue ?? ""
        
        self.lastNameInputFieldNode = VoiceChatTitleEditInputFieldNode(theme: ptheme, placeholder: lastNamePlaceholder, maxLength: maxLength)
        self.lastNameInputFieldNode.text = lastNameValue ?? ""
        
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
        
        self.addSubnode(self.firstNameInputFieldNode)
        self.addSubnode(self.lastNameInputFieldNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
        
        self.firstNameInputFieldNode.complete = { [weak self] in
            self?.lastNameInputFieldNode.activateInput()
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    var firstName: String {
        return self.firstNameInputFieldNode.text
    }
    
    var lastName: String {
        return self.lastNameInputFieldNode.text
    }

    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)

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
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        let spacing: CGFloat = 0.0
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
                
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
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 9.0, right: 18.0)
        
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
        let firstInputFieldHeight = self.firstNameInputFieldNode.updateLayout(width: inputFieldWidth, transition: transition)
        transition.updateFrame(node: self.firstNameInputFieldNode, frame: CGRect(x: 0.0, y: origin.y, width: resultWidth, height: firstInputFieldHeight))
        
        origin.y += firstInputFieldHeight + spacing
        
        let lastInputFieldHeight = self.lastNameInputFieldNode.updateLayout(width: inputFieldWidth, transition: transition)
        transition.updateFrame(node: self.lastNameInputFieldNode, frame: CGRect(x: 0.0, y: origin.y, width: resultWidth, height: lastInputFieldHeight))
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + firstInputFieldHeight + spacing + lastInputFieldHeight + actionsHeight + insets.top + insets.bottom)
        
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
            self.firstNameInputFieldNode.activateInput()
        }
        
        return resultSize
    }
    
    func animateError() {
        if self.firstNameInputFieldNode.text.isEmpty {
            self.firstNameInputFieldNode.layer.addShakeAnimation()
        }
        self.hapticFeedback.error()
    }
}

func voiceChatUserNameController(sharedContext: SharedAccountContext, account: Account, forceTheme: PresentationTheme?, title: String, firstNamePlaceholder: String, lastNamePlaceholder: String, doneButtonTitle: String? = nil, firstName: String?, lastName: String?, maxLength: Int, apply: @escaping ((String, String)?) -> Void) -> AlertController {
    var presentationData = sharedContext.currentPresentationData.with { $0 }
    if let forceTheme = forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: doneButtonTitle ?? presentationData.strings.Common_Done, action: {
        applyImpl?()
    })]
    
    let contentNode = VoiceChatUserNameEditAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, title: title, firstNamePlaceholder: firstNamePlaceholder, lastNamePlaceholder: lastNamePlaceholder, firstNameValue: firstName, lastNameValue: lastName, maxLength: maxLength)
    contentNode.complete = {
        applyImpl?()
    }
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        
        let previousFirstName = firstName ?? ""
        let previousLastName = lastName ?? ""
        let newFirstName = contentNode.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLastName = contentNode.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if newFirstName.isEmpty {
            contentNode.animateError()
            return
        }
        
        dismissImpl?(true)
        
        if previousFirstName != newFirstName || previousLastName != newLastName {
            apply((newFirstName, newLastName))
        } else {
            apply(nil)
        }
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = sharedContext.presentationData.start(next: { [weak controller, weak contentNode] presentationData in
        var presentationData = presentationData
        if let forceTheme = forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.firstNameInputFieldNode.updateTheme(presentationData.theme)
        contentNode?.lastNameInputFieldNode.updateTheme(presentationData.theme)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] animated in
        contentNode?.firstNameInputFieldNode.deactivateInput()
        contentNode?.lastNameInputFieldNode.deactivateInput()
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
