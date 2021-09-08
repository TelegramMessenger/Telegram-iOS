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
import ActivityIndicator

private class TextField: UITextField, UIScrollViewDelegate {
    let placeholderLabel: ImmediateTextNode
    var placeholderString: NSAttributedString? {
        didSet {
            self.placeholderLabel.attributedText = self.placeholderString
            self.setNeedsLayout()
        }
    }
    
    fileprivate func updatePrefixWidth(_ prefixWidth: CGFloat) {
        let previousPrefixWidth = self.prefixWidth
        guard previousPrefixWidth != prefixWidth else {
            return
        }
        self.prefixWidth = prefixWidth
        if let scrollView = self.scrollView {
            if scrollView.contentInset.left != prefixWidth {
                scrollView.contentInset = UIEdgeInsets(top: 0.0, left: prefixWidth, bottom: 0.0, right: 0.0)
            }
            if prefixWidth.isZero {
                scrollView.contentOffset = CGPoint()
            } else if prefixWidth != previousPrefixWidth {
                scrollView.contentOffset = CGPoint(x: -prefixWidth, y: 0.0)
            }
            self.updatePrefixPosition(transition: .immediate)
        }
    }
    
    private var prefixWidth: CGFloat = 0.0

    let prefixLabel: ImmediateTextNode
    var prefixString: NSAttributedString? {
        didSet {
            self.prefixLabel.attributedText = self.prefixString
            self.setNeedsLayout()
        }
    }
    
    init() {
        self.prefixLabel = ImmediateTextNode()
        self.prefixLabel.isUserInteractionEnabled = false
        self.prefixLabel.displaysAsynchronously = false
        self.prefixLabel.maximumNumberOfLines = 1
        self.prefixLabel.truncationMode = .byTruncatingTail
        
        self.placeholderLabel = ImmediateTextNode()
        self.placeholderLabel.isUserInteractionEnabled = false
        self.placeholderLabel.displaysAsynchronously = false
        self.placeholderLabel.maximumNumberOfLines = 1
        self.placeholderLabel.truncationMode = .byTruncatingTail
                
        super.init(frame: CGRect())
        
        self.addSubnode(self.prefixLabel)
        self.addSubnode(self.placeholderLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        
        if let scrollView = view as? UIScrollView {
            scrollView.delegate = self
        }
    }
    
    private weak var _scrollView: UIScrollView?
    var scrollView: UIScrollView? {
        if let scrollView = self._scrollView {
            return scrollView
        }
        for view in self.subviews {
            if let scrollView = view as? UIScrollView {
                _scrollView = scrollView
                return scrollView
            }
        }
        return nil
    }
    
    override func deleteBackward() {
        super.deleteBackward()
        
        if let scrollView = self.scrollView {
            if scrollView.contentSize.width <= scrollView.frame.width && scrollView.contentOffset.x > -scrollView.contentInset.left {
                scrollView.contentOffset = CGPoint(x: max(scrollView.contentOffset.x - 5.0, -scrollView.contentInset.left), y: 0.0)
                self.updatePrefixPosition()
            }
        }
    }
    
    func selectWhole() {
        guard let _ = self.scrollView else {
            return
        }
//        if scrollView.contentSize.width > scrollView.frame.width - scrollView.contentInset.left {
//            scrollView.contentOffset = CGPoint(x: -scrollView.contentInset.left + scrollView.contentSize.width - (scrollView.frame.width - scrollView.contentInset.left), y: 0.0)
//            self.updatePrefixPosition()
//        }
        self.selectAll(nil)
    }
    
    var fixAutoScroll: CGPoint?
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let fixAutoScroll = self.fixAutoScroll {
            self.scrollView?.setContentOffset(fixAutoScroll, animated: true)
            self.scrollView?.setContentOffset(fixAutoScroll, animated: false)
            self.fixAutoScroll = nil
        } else {
            self.updatePrefixPosition()
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        if let contentOffset = self.scrollView?.contentOffset {
            self.fixAutoScroll = contentOffset
            Queue.mainQueue().after(0.1) {
                self.fixAutoScroll = nil
            }
        }
        return super.becomeFirstResponder()
    }
    
    private func updatePrefixPosition(transition: ContainedViewLayoutTransition = .immediate) {
        if let scrollView = self.scrollView {
            transition.updateFrame(node: self.prefixLabel, frame: CGRect(origin: CGPoint(x: -scrollView.contentOffset.x - scrollView.contentInset.left, y: self.prefixLabel.frame.minY), size: self.prefixLabel.frame.size))
        }
    }
        
    override var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            let resigning = self.isFirstResponder
            if resigning {
                self.resignFirstResponder()
            }
            super.keyboardAppearance = newValue
            if resigning {
                let _ = self.becomeFirstResponder()
            }
        }
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        if bounds.size.width.isZero {
            return CGRect(origin: CGPoint(), size: CGSize())
        }
        var rect = bounds.insetBy(dx: 0.0, dy: 4.0)
        if #available(iOS 14.0, *) {
        } else {
            rect.origin.y += 1.0
        }
        if !self.prefixWidth.isZero && self.scrollView?.superview == nil {
            var offset = self.prefixWidth
            if let scrollView = self.scrollView {
                offset = scrollView.contentOffset.x * -1.0
            }
            rect.origin.x += offset
            rect.size.width -= offset
         }
        rect.size.width = max(rect.size.width, 10.0)
        return rect
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        if bounds.size.width.isZero {
            return
        }
                
        let textRect = self.textRect(forBounds: bounds)

        let labelSize = self.placeholderLabel.updateLayout(textRect.size)
        self.placeholderLabel.frame = CGRect(origin: CGPoint(x: textRect.minX + 3.0, y: floorToScreenPixels((bounds.height - labelSize.height) / 2.0)), size: labelSize)
        
        let prefixSize = self.prefixLabel.updateLayout(CGSize(width: floor(bounds.size.width * 0.7), height: bounds.size.height))
        let prefixBounds = bounds.insetBy(dx: 4.0, dy: 4.0)
        self.prefixLabel.frame = CGRect(origin: CGPoint(x: prefixBounds.minX, y: floorToScreenPixels((bounds.height - prefixSize.height) / 2.0)), size: prefixSize)
        self.updatePrefixWidth(prefixSize.width + 3.0)
    }
}

private let validIdentifierSet: CharacterSet = {
    var set = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
    set.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
    set.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
    set.insert("_")
    return set
}()

private final class ImportStickerPackTitleInputFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: TextField
    private let clearButton: HighlightableButtonNode
    
    var updateHeight: (() -> Void)?
    var complete: (() -> Void)?
    var textChanged: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 15.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    
    var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(14.0), textColor: self.theme.actionSheet.inputTextColor)
            self.textInputNode.placeholderLabel.isHidden = !newValue.isEmpty
            if self.textInputNode.isFirstResponder {
                self.clearButton.isHidden = newValue.isEmpty
            } else {
                self.clearButton.isHidden = true
            }
        }
    }
    
    var prefix: String = "" {
        didSet {
            self.textInputNode.prefixString = NSAttributedString(string: self.prefix, font: Font.regular(14.0), textColor: self.theme.actionSheet.inputTextColor)
        }
    }
    
    var disabled: Bool = false {
        didSet {
            self.clearButton.isHidden = true
        }
    }
    
    private let maxLength: Int
    
    init(theme: PresentationTheme, placeholder: String, maxLength: Int, keyboardType: UIKeyboardType = .default, returnKeyType: UIReturnKeyType = .done) {
        self.theme = theme
        self.maxLength = maxLength
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        
        self.textInputNode = TextField()
        self.textInputNode.font = Font.regular(14.0)
        self.textInputNode.typingAttributes = [NSAttributedString.Key.font: Font.regular(14.0), NSAttributedString.Key.foregroundColor: theme.actionSheet.inputTextColor]
        self.textInputNode.clipsToBounds = true
        self.textInputNode.placeholderString = NSAttributedString(string: placeholder, font: Font.regular(14.0), textColor: theme.actionSheet.secondaryTextColor)
        self.textInputNode.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.keyboardType = keyboardType
        self.textInputNode.autocapitalizationType = .sentences
        self.textInputNode.returnKeyType = returnKeyType
        self.textInputNode.autocorrectionType = .default
        self.textInputNode.tintColor = theme.actionSheet.controlAccentColor
                
        self.clearButton = HighlightableButtonNode()
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: theme.actionSheet.inputClearButtonColor), for: [])
        self.clearButton.isHidden = true
        
        super.init()
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.clearButton)
        
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textInputNode.delegate = self
        self.view.insertSubview(self.textInputNode, aboveSubview: self.backgroundNode.view)
    }
    
    func selectAll() {
        self.textInputNode.selectWhole()
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: self.theme.actionSheet.inputHollowBackgroundColor, strokeColor: self.theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        self.textInputNode.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
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
        
        transition.updateFrame(view: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right - 22.0, height: backgroundFrame.size.height)))
        
        if let image = self.clearButton.image(for: []) {
            transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX - 8.0 - image.size.width, y: backgroundFrame.minY + floor((backgroundFrame.size.height - image.size.height) / 2.0)), size: image.size))
        }
        
        return panelHeight
    }
    
    func activateInput() {
        let _ = self.textInputNode.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.clearButton.isHidden = (textField.text ?? "").isEmpty
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.clearButton.isHidden = true
    }
    
    func textFieldDidUpdateText(_ text: String) {
        self.updateTextNodeText(animated: true)
        self.textChanged?(text)
        self.clearButton.isHidden = text.isEmpty
        self.textInputNode.placeholderLabel.isHidden = !text.isEmpty
    }
        
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.disabled {
            return false
        }
        let updatedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if updatedText.count > maxLength {
            self.textInputNode.layer.addShakeAnimation()
            return false
        }
        if string == "\n" {
            self.complete?()
            return false
        }
        
        if self.textInputNode.keyboardType == .asciiCapable {
            var cleanString = string.folding(options: .diacriticInsensitive, locale: .current).replacingOccurrences(of: " ", with: "_")
            
            let filtered = cleanString.unicodeScalars.filter { validIdentifierSet.contains($0) }
            let filteredString = String(String.UnicodeScalarView(filtered))
            
            if cleanString != filteredString {
                cleanString = filteredString
                
                self.textInputNode.layer.addShakeAnimation()
                let hapticFeedback = HapticFeedback()
                hapticFeedback.error()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                    let _ = hapticFeedback
                })
            }
            
            if cleanString != string {
                var text = textField.text ?? ""
                text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: cleanString)
                textField.text = text
                if let startPosition = textField.position(from: textField.beginningOfDocument, offset: range.lowerBound + cleanString.count) {
                    let selectionRange = textField.textRange(from: startPosition, to: startPosition)
                    DispatchQueue.main.async {
                        textField.selectedTextRange = selectionRange
                    }
                }
                self.textFieldDidUpdateText(text)
                return false
            }
        }
        
        self.textFieldDidUpdateText(updatedText)
        return true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        return 33.0
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
        self.clearButton.isHidden = true
        
        self.textInputNode.attributedText = nil
        self.updateHeight?()
        self.textChanged?("")
    }
}

private final class ImportStickerPackTitleAlertContentNode: AlertContentNode {
    enum InfoText {
        case info
        case checking
        case available
        case taken
        case generating
    }
    private var theme: PresentationTheme
    private var alertTheme: AlertControllerTheme
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    
    var infoText: InfoText? {
        didSet {
            let text: String
            let color: UIColor
            var activity = false
            if let infoText = self.infoText {
                switch infoText {
                    case .info:
                        text = self.strings.ImportStickerPack_ChooseLinkDescription
                        color = self.alertTheme.primaryColor
                    case .checking:
                        text = self.strings.ImportStickerPack_CheckingLink
                        color = self.alertTheme.secondaryColor
                        activity = true
                    case .available:
                        text = self.strings.ImportStickerPack_LinkAvailable
                        color = self.theme.list.freeTextSuccessColor
                    case .taken:
                        text = self.strings.ImportStickerPack_LinkTaken
                        color = self.theme.list.freeTextErrorColor
                    case .generating:
                        text = self.strings.ImportStickerPack_GeneratingLink
                        color = self.alertTheme.secondaryColor
                        activity = true
                }
                self.activityIndicator.isHidden = !activity
            } else {
                text = self.text
                color = self.alertTheme.primaryColor
            }
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(13.0), textColor: color)
            if let size = self.validLayout {
                _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let activityIndicator: ActivityIndicator
    let inputFieldNode: ImportStickerPackTitleInputFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    fileprivate let actionNodes: [TextAlertContentActionNode]
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
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], title: String, text: String, placeholder: String, value: String?, maxLength: Int, asciiOnly: Bool = false) {
        self.strings = strings
        self.alertTheme = theme
        self.theme = ptheme
        self.title = title
        self.text = text
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 8
        
        self.activityIndicator = ActivityIndicator(type: .custom(ptheme.rootController.navigationBar.secondaryTextColor, 20.0, 1.5, false), speed: .slow)
        self.activityIndicator.isHidden = true
                
        self.inputFieldNode = ImportStickerPackTitleInputFieldNode(theme: ptheme, placeholder: placeholder, maxLength: maxLength, keyboardType: asciiOnly ? .asciiCapable : .default, returnKeyType: asciiOnly ? .done : .next)
        if asciiOnly {
            self.inputFieldNode.prefix = "t.me/addstickers/"
        }
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
        self.addSubnode(self.activityIndicator)
        
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
        self.alertTheme = theme
        
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
        
        let activitySize = CGSize(width: 20.0, height: 20.0)
        let textSize = self.textNode.measure(measureSize)
        let activityInset: CGFloat = self.activityIndicator.isHidden ? 0.0 : activitySize.width + 5.0
        let totalWidth = textSize.width + activityInset
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalWidth) / 2.0), y: origin.y - 1.0), size: activitySize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalWidth) / 2.0) + activityInset, y: origin.y), size: textSize))
        
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

func importStickerPackTitleController(context: AccountContext, title: String, text: String, placeholder: String, value: String?, maxLength: Int, apply: @escaping (String?) -> Void, cancel: @escaping () -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
        cancel()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Next, action: {
        applyImpl?()
    })]
    
    let contentNode = ImportStickerPackTitleAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, title: title, text: text, placeholder: placeholder, value: value, maxLength: maxLength)
    contentNode.complete = {
        applyImpl?()
    }
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        let newValue = contentNode.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newValue.isEmpty else {
            return
        }
        
        contentNode.infoText = .generating
        contentNode.inputFieldNode.disabled = true
        contentNode.actionNodes.last?.actionEnabled = false
        
        apply(newValue)
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.inputFieldNode.updateTheme(presentationData.theme)
    })
    contentNode.actionNodes.last?.actionEnabled = false
    contentNode.inputFieldNode.textChanged = { [weak contentNode] title in
        contentNode?.actionNodes.last?.actionEnabled = !title.trimmingTrailingSpaces().isEmpty
    }
    controller.willDismiss = { [weak contentNode] in
        contentNode?.inputFieldNode.deactivateInput()
    }
    controller.dismissed = {
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


func importStickerPackShortNameController(context: AccountContext, title: String, text: String, placeholder: String, value: String?, maxLength: Int, existingAlertController: AlertController?, apply: @escaping (String?) -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ImportStickerPack_Create, action: {
        applyImpl?()
    })]
    
    let contentNode = ImportStickerPackTitleAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, title: title, text: text, placeholder: placeholder, value: value, maxLength: maxLength, asciiOnly: true)
    contentNode.complete = {
        applyImpl?()
    }
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        let newValue = contentNode.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newValue.isEmpty else {
            return
        }
        
        dismissImpl?(true)
        apply(newValue)
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode, existingAlertController: existingAlertController)
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.inputFieldNode.updateTheme(presentationData.theme)
    })
    let checkDisposable = MetaDisposable()
    let value = value ?? ""
    contentNode.actionNodes.last?.actionEnabled = !value.isEmpty
    if !value.isEmpty {
        Queue.mainQueue().after(0.25) {
            contentNode.inputFieldNode.selectAll()
        }
    }
    contentNode.inputFieldNode.textChanged = { [weak contentNode] value in
        if value.isEmpty {
            checkDisposable.set(nil)
            contentNode?.infoText = .info
            contentNode?.actionNodes.last?.actionEnabled = false
        } else {
            checkDisposable.set((context.engine.stickers.validateStickerSetShortNameInteractive(shortName: value)
            |> deliverOnMainQueue).start(next: { [weak contentNode] result in
                switch result {
                    case .checking:
                        contentNode?.infoText = .checking
                        contentNode?.actionNodes.last?.actionEnabled = false
                    case let .availability(availability):
                        switch availability {
                            case .available:
                                contentNode?.infoText = .available
                                contentNode?.actionNodes.last?.actionEnabled = true
                            case .taken:
                                contentNode?.infoText = .taken
                                contentNode?.actionNodes.last?.actionEnabled = false
                            case .invalid:
                                contentNode?.infoText = .info
                                contentNode?.actionNodes.last?.actionEnabled = false
                        }
                    case .invalidFormat:
                        contentNode?.infoText = .info
                        contentNode?.actionNodes.last?.actionEnabled = false
                }
            }))
        }
    }
    controller.willDismiss = { [weak contentNode] in
        contentNode?.inputFieldNode.deactivateInput()
    }
    controller.dismissed = {
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
