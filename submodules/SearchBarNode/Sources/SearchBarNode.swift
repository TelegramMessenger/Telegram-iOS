import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator
import AppBundle

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: color)
}

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

private func generateBackground(foregroundColor: UIColor, diameter: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setFillColor(foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: false)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private class SearchBarTextField: UITextField {
    public var didDeleteBackwardWhileEmpty: (() -> Void)?
    
    let placeholderLabel: ImmediateTextNode
    var placeholderString: NSAttributedString? {
        didSet {
            self.placeholderLabel.attributedText = self.placeholderString
            self.setNeedsLayout()
        }
    }
    
    private let measurePrefixLabel: ImmediateTextNode
    let prefixLabel: ImmediateTextNode
    var prefixString: NSAttributedString? {
        didSet {
            self.measurePrefixLabel.attributedText = self.prefixString
            self.prefixLabel.attributedText = self.prefixString
            self.setNeedsLayout()
        }
    }
    
    override init(frame: CGRect) {
        self.placeholderLabel = ImmediateTextNode()
        self.placeholderLabel.isUserInteractionEnabled = false
        self.placeholderLabel.displaysAsynchronously = false
        self.placeholderLabel.maximumNumberOfLines = 1
        self.placeholderLabel.truncationMode = .byTruncatingTail
        
        self.measurePrefixLabel = ImmediateTextNode()
        self.measurePrefixLabel.isUserInteractionEnabled = false
        self.measurePrefixLabel.displaysAsynchronously = false
        self.measurePrefixLabel.maximumNumberOfLines = 1
        self.measurePrefixLabel.truncationMode = .byTruncatingTail
        
        self.prefixLabel = ImmediateTextNode()
        self.prefixLabel.isUserInteractionEnabled = false
        self.prefixLabel.displaysAsynchronously = false
        self.prefixLabel.maximumNumberOfLines = 1
        self.prefixLabel.truncationMode = .byTruncatingTail
        
        super.init(frame: frame)
        
        self.addSubnode(self.placeholderLabel)
        self.addSubnode(self.prefixLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                self.becomeFirstResponder()
            }
        }
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        if bounds.size.width.isZero {
            return CGRect(origin: CGPoint(), size: CGSize())
        }
        var rect = bounds.insetBy(dx: 4.0, dy: 4.0)
        
        let prefixSize = self.measurePrefixLabel.updateLayout(CGSize(width: floor(bounds.size.width * 0.7), height: bounds.size.height))
        if !prefixSize.width.isZero {
            let prefixOffset = prefixSize.width + 3.0
            rect.origin.x += prefixOffset
            rect.size.width -= prefixOffset
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
        
        var textOffset: CGFloat = 1.0
        if bounds.height >= 36.0 {
            textOffset += 2.0
        }
        
        let textRect = self.textRect(forBounds: bounds)
        let labelSize = self.placeholderLabel.updateLayout(textRect.size)
        self.placeholderLabel.frame = CGRect(origin: CGPoint(x: textRect.minX, y: textRect.minY + textOffset), size: labelSize)
        
        let prefixSize = self.prefixLabel.updateLayout(CGSize(width: floor(bounds.size.width * 0.7), height: bounds.size.height))
        let prefixBounds = bounds.insetBy(dx: 4.0, dy: 4.0)
        self.prefixLabel.frame = CGRect(origin: CGPoint(x: prefixBounds.minX, y: prefixBounds.minY + textOffset), size: prefixSize)
    }
    
    override func deleteBackward() {
        if self.text == nil || self.text!.isEmpty {
            self.didDeleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
    }
}

public final class SearchBarNodeTheme: Equatable {
    public let background: UIColor
    public let separator: UIColor
    public let inputFill: UIColor
    public let placeholder: UIColor
    public let primaryText: UIColor
    public let inputIcon: UIColor
    public let inputClear: UIColor
    public let accent: UIColor
    public let keyboard: PresentationThemeKeyboardColor
    
    public init(background: UIColor, separator: UIColor, inputFill: UIColor, primaryText: UIColor, placeholder: UIColor, inputIcon: UIColor, inputClear: UIColor, accent: UIColor, keyboard: PresentationThemeKeyboardColor) {
        self.background = background
        self.separator = separator
        self.inputFill = inputFill
        self.primaryText = primaryText
        self.placeholder = placeholder
        self.inputIcon = inputIcon
        self.inputClear = inputClear
        self.accent = accent
        self.keyboard = keyboard
    }
    
    public init(theme: PresentationTheme, hasSeparator: Bool = true) {
        self.background = theme.rootController.navigationBar.backgroundColor
        self.separator = hasSeparator ? theme.rootController.navigationBar.separatorColor : theme.rootController.navigationBar.backgroundColor
        self.inputFill = theme.rootController.navigationSearchBar.inputFillColor
        self.placeholder = theme.rootController.navigationSearchBar.inputPlaceholderTextColor
        self.primaryText = theme.rootController.navigationSearchBar.inputTextColor
        self.inputIcon = theme.rootController.navigationSearchBar.inputIconColor
        self.inputClear = theme.rootController.navigationSearchBar.inputClearButtonColor
        self.accent = theme.rootController.navigationSearchBar.accentColor
        self.keyboard = theme.rootController.keyboardColor
    }
    
    public static func ==(lhs: SearchBarNodeTheme, rhs: SearchBarNodeTheme) -> Bool {
        if lhs.background != rhs.background {
            return false
        }
        if lhs.separator != rhs.separator {
            return false
        }
        if lhs.inputFill != rhs.inputFill {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.primaryText != rhs.primaryText {
            return false
        }
        if lhs.inputIcon != rhs.inputIcon {
            return false
        }
        if lhs.inputClear != rhs.inputClear {
            return false
        }
        if lhs.accent != rhs.accent {
            return false
        }
        if lhs.keyboard != rhs.keyboard {
            return false
        }
        return true
    }
}

public enum SearchBarStyle {
    case modern
    case legacy
    
    var font: UIFont {
        switch self {
            case .modern:
                return Font.regular(17.0)
            case .legacy:
                return Font.regular(14.0)
        }
    }
    
    var cornerDiameter: CGFloat {
        switch self {
            case .modern:
                return 21.0
            case .legacy:
                return 14.0
        }
    }
    
    var height: CGFloat {
        switch self {
            case .modern:
                return 36.0
            case .legacy:
                return 28.0
        }
    }
    
    var padding: CGFloat {
        switch self {
            case .modern:
                return 10.0
            case .legacy:
                return 8.0
        }
    }
}

public class SearchBarNode: ASDisplayNode, UITextFieldDelegate {
    public var cancel: (() -> Void)?
    public var textUpdated: ((String, String?) -> Void)?
    public var textReturned: ((String) -> Void)?
    public var clearPrefix: (() -> Void)?
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textBackgroundNode: ASDisplayNode
    private var activityIndicator: ActivityIndicator?
    private let iconNode: ASImageNode
    private let textField: SearchBarTextField
    private let clearButton: HighlightableButtonNode
    private let cancelButton: HighlightableButtonNode
    
    public var placeholderString: NSAttributedString? {
        get {
            return self.textField.placeholderString
        } set(value) {
            self.textField.placeholderString = value
        }
    }
    
    public var prefixString: NSAttributedString? {
        get {
            return self.textField.prefixString
        } set(value) {
            let previous = self.prefixString
            let updated: Bool
            if let previous = previous, let value = value {
                updated = !previous.isEqual(to: value)
            } else {
                updated = (previous != nil) != (value != nil)
            }
            if updated {
                self.textField.prefixString = value
                self.textField.setNeedsLayout()
                self.updateIsEmpty()
            }
        }
    }
    
    public var text: String {
        get {
            return self.textField.text ?? ""
        } set(value) {
            if self.textField.text ?? "" != value {
                self.textField.text = value
                self.textFieldDidChange(self.textField)
            }
        }
    }
    
    public var activity: Bool = false {
        didSet {
            if self.activity != oldValue {
                if self.activity {
                    if self.activityIndicator == nil, let theme = self.theme {
                        let activityIndicator = ActivityIndicator(type: .custom(theme.inputIcon, 13.0, 1.0, false))
                        self.activityIndicator = activityIndicator
                        self.addSubnode(activityIndicator)
                        if let (boundingSize, leftInset, rightInset) = self.validLayout {
                            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                        }
                    }
                } else if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    activityIndicator.removeFromSupernode()
                }
                self.iconNode.isHidden = self.activity
            }
        }
    }
    
    public var hasCancelButton: Bool = true {
        didSet {
            self.cancelButton.isHidden = !self.hasCancelButton
            if let (boundingSize, leftInset, rightInset) = self.validLayout {
                self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
            }
        }
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private let fieldStyle: SearchBarStyle
    private var theme: SearchBarNodeTheme?
    private var strings: PresentationStrings?
    private let cancelText: String?
    
    public init(theme: SearchBarNodeTheme, strings: PresentationStrings, fieldStyle: SearchBarStyle = .legacy, cancelText: String? = nil) {
        self.fieldStyle = fieldStyle
        self.cancelText = cancelText
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.textBackgroundNode = ASDisplayNode()
        self.textBackgroundNode.isLayerBacked = false
        self.textBackgroundNode.displaysAsynchronously = false
        self.textBackgroundNode.cornerRadius = self.fieldStyle.cornerDiameter / 2.0
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.textField = SearchBarTextField()
        self.textField.accessibilityTraits = .searchField
        self.textField.autocorrectionType = .no
        self.textField.returnKeyType = .search
        self.textField.font = self.fieldStyle.font
        
        self.clearButton = HighlightableButtonNode(pointerStyle: .lift)
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.isHidden = true
        
        self.cancelButton = HighlightableButtonNode(pointerStyle: .default)
        self.cancelButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.cancelButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.textBackgroundNode)
        self.view.addSubview(self.textField)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.clearButton)
        self.addSubnode(self.cancelButton)
        
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        self.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            self?.clearPressed()
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    public func updateThemeAndStrings(theme: SearchBarNodeTheme, strings: PresentationStrings) {
        if self.theme != theme || self.strings !== strings {
            self.cancelButton.setAttributedTitle(NSAttributedString(string: self.cancelText ?? strings.Common_Cancel, font: self.cancelText != nil ? Font.semibold(17.0) : Font.regular(17.0), textColor: theme.accent), for: [])
        }
        if self.theme != theme {
            self.backgroundNode.backgroundColor = theme.background
            if self.fieldStyle != .modern {
                self.separatorNode.backgroundColor = theme.separator
            }
            self.textBackgroundNode.backgroundColor = theme.inputFill
            self.textField.textColor = theme.primaryText
            self.clearButton.setImage(generateClearIcon(color: theme.inputClear), for: [])
            self.iconNode.image = generateLoupeIcon(color: theme.inputIcon)
            self.textField.keyboardAppearance = theme.keyboard.keyboardAppearance
            self.textField.tintColor = theme.accent
            
            if let activityIndicator = self.activityIndicator {
                activityIndicator.type = .custom(theme.inputIcon, 13.0, 1.0, false)
            }
        }
        
        self.theme = theme
        self.strings = strings
        if let (boundingSize, leftInset, rightInset) = self.validLayout {
            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    public func updateLayout(boundingSize: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (boundingSize, leftInset, rightInset)
        
        self.backgroundNode.frame = self.bounds
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.bounds.size.height), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel)))
        
        let verticalOffset: CGFloat = boundingSize.height - 82.0
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: boundingSize.width - leftInset - rightInset, height: boundingSize.height))
        
        let textBackgroundHeight = self.fieldStyle.height
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: 100.0, height: CGFloat.infinity))
        transition.updateFrame(node: self.cancelButton, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 10.0 - cancelButtonSize.width, y: verticalOffset + textBackgroundHeight + floorToScreenPixels((textBackgroundHeight - cancelButtonSize.height) / 2.0)), size: cancelButtonSize))
        
        let padding = self.fieldStyle.padding
        let textBackgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX + padding, y: verticalOffset + textBackgroundHeight), size: CGSize(width: contentFrame.width - padding * 2.0 - (self.hasCancelButton ? cancelButtonSize.width + 11.0 : 0.0), height: textBackgroundHeight))
        transition.updateFrame(node: self.textBackgroundNode, frame: textBackgroundFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 24.0, y: textBackgroundFrame.minY), size: CGSize(width: max(1.0, textBackgroundFrame.size.width - 24.0 - 20.0), height: textBackgroundFrame.size.height))
        
        if let iconImage = self.iconNode.image {
            let iconSize = iconImage.size
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 8.0, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - iconSize.height) / 2.0)), size: iconSize))
        }
        
        if let activityIndicator = self.activityIndicator {
            let indicatorSize = activityIndicator.measure(CGSize(width: 32.0, height: 32.0))
            transition.updateFrame(node: activityIndicator, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 7.0, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - indicatorSize.height) / 2.0)), size: indicatorSize))
        }
        
        let clearSize = self.clearButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.maxX - 8.0 - clearSize.width, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - clearSize.height) / 2.0)), size: clearSize))
        
        self.textField.frame = textFrame
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let cancel = self.cancel {
                cancel()
            }
        }
    }
    
    public func activate() {
        self.textField.becomeFirstResponder()
    }
    
    public func animateIn(from node: SearchBarPlaceholderNode, duration: Double, timingFunction: String) {
        let initialTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, initialTextBackgroundFrame.maxY + 8.0)))
        if let fromBackgroundColor = node.backgroundColor, let toBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: duration * 0.7)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
        self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let initialSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, initialTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.separatorNode.layer.animateFrame(from: initialSeparatorFrame, to: self.separatorNode.frame, duration: duration, timingFunction: timingFunction)
        
        if let fromTextBackgroundColor = node.backgroundNode.backgroundColor, let toTextBackgroundColor = self.textBackgroundNode.backgroundColor {
            self.textBackgroundNode.layer.animate(from: fromTextBackgroundColor.cgColor, to: toTextBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: timingFunction, duration: duration * 1.0)
        }
        self.textBackgroundNode.layer.animateFrame(from: initialTextBackgroundFrame, to: self.textBackgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let textFieldFrame = self.textField.frame
        let initialLabelNodeFrame = CGRect(origin: node.labelNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x - 4.0, dy: initialTextBackgroundFrame.origin.y - 7.0).origin, size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: initialLabelNodeFrame, to: self.textField.frame, duration: duration, timingFunction: timingFunction)
        
        let iconFrame = self.iconNode.frame
        let initialIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x, dy: initialTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.layer.animateFrame(from: initialIconFrame, to: self.iconNode.frame, duration: duration, timingFunction: timingFunction)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: initialTextBackgroundFrame.midY), to: self.cancelButton.layer.position, duration: duration, timingFunction: timingFunction)
        node.isHidden = true
    }
    
    public func deactivate(clear: Bool = true) {
        self.textField.resignFirstResponder()
        if clear {
            self.textField.text = nil
            self.textField.placeholderLabel.isHidden = false
        }
    }
    
    public func transitionOut(to node: SearchBarPlaceholderNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let targetTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let duration: Double = transition.isAnimated ? 0.5 : 0.0
        let timingFunction = kCAMediaTimingFunctionSpring
        
        node.isHidden = true
        self.clearButton.isHidden = true
        self.activityIndicator?.isHidden = true
        self.iconNode.isHidden = false
        self.textField.prefixString = nil
        self.textField.text = ""
        self.textField.layoutSubviews()
    
        var backgroundCompleted = false
        var separatorCompleted = false
        var textBackgroundCompleted = false
        let intermediateCompletion: () -> Void = { [weak node] in
            if backgroundCompleted && separatorCompleted && textBackgroundCompleted {
                completion()
                node?.isHidden = false
            }
        }
        
        let targetBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, targetTextBackgroundFrame.maxY + 8.0)))
        if let toBackgroundColor = node.backgroundColor, let fromBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: duration * 0.5, removeOnCompletion: false)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        }
        self.backgroundNode.layer.animateFrame(from: self.backgroundNode.frame, to: targetBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            backgroundCompleted = true
            intermediateCompletion()
        })
        
        let targetSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, targetTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        self.separatorNode.layer.animateFrame(from: self.separatorNode.frame, to: targetSeparatorFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            separatorCompleted = true
            intermediateCompletion()
        })
        
        self.textBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            textBackgroundCompleted = true
            intermediateCompletion()
        })
        
        let transitionBackgroundNode = ASDisplayNode()
        transitionBackgroundNode.isLayerBacked = true
        transitionBackgroundNode.displaysAsynchronously = false
        transitionBackgroundNode.backgroundColor = node.backgroundNode.backgroundColor
        transitionBackgroundNode.cornerRadius = node.backgroundNode.cornerRadius
        self.insertSubnode(transitionBackgroundNode, aboveSubnode: self.textBackgroundNode)
        transitionBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0, removeOnCompletion: false)
        transitionBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let textFieldFrame = self.textField.frame
        let targetLabelNodeFrame = CGRect(origin: CGPoint(x: node.labelNode.frame.minX + targetTextBackgroundFrame.origin.x - 4.0, y: targetTextBackgroundFrame.minY + floorToScreenPixels((targetTextBackgroundFrame.size.height - textFieldFrame.size.height) / 2.0)), size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: self.textField.frame, to: targetLabelNodeFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            if let snapshot = node.labelNode.layer.snapshotContentTree() {
                snapshot.frame = CGRect(origin: self.textField.placeholderLabel.frame.origin.offsetBy(dx: 0.0, dy: UIScreenPixel), size: node.labelNode.frame.size)
                self.textField.layer.addSublayer(snapshot)
                snapshot.animateAlpha(from: 0.0, to: 1.0, duration: duration * 2.0 / 3.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
                self.textField.placeholderLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false)
            }
        } else if let cachedLayout = node.labelNode.cachedLayout {
            let labelNode = TextNode()
            labelNode.isOpaque = false
            labelNode.isUserInteractionEnabled = false
            let labelLayout = TextNode.asyncLayout(labelNode)
            let (labelLayoutResult, labelApply) = labelLayout(TextNodeLayoutArguments(attributedString: self.placeholderString, backgroundColor: .clear, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: cachedLayout.size, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let _ = labelApply()
            
            self.textField.addSubnode(labelNode)
            labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 2.0 / 3.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
            labelNode.frame = CGRect(origin: self.textField.placeholderLabel.frame.origin.offsetBy(dx: 0.0, dy: UIScreenPixel), size: labelLayoutResult.size)
            self.textField.placeholderLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { _ in
                labelNode.removeFromSupernode()
            })
        }
        let iconFrame = self.iconNode.frame
        let targetIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: targetTextBackgroundFrame.origin.x, dy: targetTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.image = node.iconNode.image
        self.iconNode.layer.animateFrame(from: self.iconNode.frame, to: targetIconFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: self.cancelButton.layer.position, to: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: targetTextBackgroundFrame.midY), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.range(of: "\n") != nil {
            return false
        }
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textField.resignFirstResponder()
        if let textReturned = self.textReturned {
            textReturned(textField.text ?? "")
        }
        return false
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        self.updateIsEmpty()
        if let textUpdated = self.textUpdated {
            textUpdated(textField.text ?? "", textField.textInputMode?.primaryLanguage)
        }
    }
    
    public func selectAll() {
        self.textField.becomeFirstResponder()
        self.textField.selectAll(nil)
    }
    
    private func updateIsEmpty() {
        let isEmpty = !(self.textField.text?.isEmpty ?? true)
        if isEmpty != self.textField.placeholderLabel.isHidden {
            self.textField.placeholderLabel.isHidden = isEmpty
        }
        self.clearButton.isHidden = !isEmpty && self.prefixString == nil
    }
    
    @objc private func cancelPressed() {
        if let cancel = self.cancel {
            cancel()
        }
    }
    
    @objc private func clearPressed() {
        if (self.textField.text?.isEmpty ?? true) {
            if self.prefixString != nil {
                self.clearPrefix?()
            }
        } else {
            self.textField.text = ""
            self.textFieldDidChange(self.textField)
        }
    }
}
