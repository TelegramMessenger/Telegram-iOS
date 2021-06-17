import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

public final class ShareInputFieldNodeTheme: Equatable {
    let backgroundColor: UIColor
    let textColor: UIColor
    let placeholderColor: UIColor
    let clearButtonColor: UIColor
    let accentColor: UIColor
    let keyboard: PresentationThemeKeyboardColor
    
    public init(backgroundColor: UIColor, textColor: UIColor, placeholderColor: UIColor, clearButtonColor: UIColor, accentColor: UIColor, keyboard: PresentationThemeKeyboardColor) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.clearButtonColor = clearButtonColor
        self.accentColor = accentColor
        self.keyboard = keyboard
    }
    
    public static func ==(lhs: ShareInputFieldNodeTheme, rhs: ShareInputFieldNodeTheme) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.clearButtonColor != rhs.clearButtonColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.keyboard != rhs.keyboard {
            return false
        }
        return true
    }
}

public extension ShareInputFieldNodeTheme {
    convenience init(presentationTheme theme: PresentationTheme) {
        self.init(backgroundColor: theme.actionSheet.inputBackgroundColor, textColor: theme.actionSheet.inputTextColor, placeholderColor: theme.actionSheet.inputPlaceholderColor, clearButtonColor: theme.actionSheet.inputClearButtonColor, accentColor: theme.actionSheet.controlAccentColor, keyboard: theme.rootController.keyboardColor)
    }
}

public final class ShareInputFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    private let theme: ShareInputFieldNodeTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: EditableTextNode
    private let placeholderNode: ASTextNode
    private let clearButton: HighlightableButtonNode
    
    public var updateHeight: (() -> Void)?
    public var updateText: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 1.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 10.0, left: 8.0, bottom: 10.0, right: 16.0)
    private let accessoryButtonsWidth: CGFloat = 10.0
    
    private var selectTextOnce: Bool = false
    
    public var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(17.0), textColor: self.theme.textColor)
            self.placeholderNode.isHidden = !newValue.isEmpty
            self.clearButton.isHidden = newValue.isEmpty
        }
    }
    
    public var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(17.0), textColor: self.theme.placeholderColor)
        }
    }
    
    public init(theme: ShareInputFieldNodeTheme, placeholder: String) {
        self.theme = theme
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.backgroundColor)
        
        self.textInputNode = EditableTextNode()
        let textColor: UIColor = theme.textColor
        self.textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: textColor]
        self.textInputNode.clipsToBounds = true
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textContainerInset = UIEdgeInsets(top: self.inputInsets.top, left: 0.0, bottom: self.inputInsets.bottom, right: 0.0)
        self.textInputNode.keyboardAppearance = theme.keyboard.keyboardAppearance
        self.textInputNode.tintColor = theme.accentColor
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.placeholderColor)
        
        self.clearButton = HighlightableButtonNode()
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.setImage(generateClearIcon(color: theme.clearButtonColor), for: [])
        self.clearButton.isHidden = true
        
        super.init()
        
        self.textInputNode.delegate = self
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.clearButton)
        
        self.textInputNode.textView.showsVerticalScrollIndicator = false
        
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
    }
    
    public func preselectText() {
        self.selectTextOnce = true
    }
    
    public func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: width)
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.size.width - placeholderSize.width) / 2.0), y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        if let image = self.clearButton.image(for: []) {
            transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX - 8.0 - image.size.width, y: backgroundFrame.minY + floor((backgroundFrame.size.height - image.size.height) / 2.0)), size: image.size))
        }
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right - accessoryButtonsWidth, height: backgroundFrame.size.height)))
        
        return panelHeight
    }
    
    public func activateInput() {
        self.textInputNode.becomeFirstResponder()
    }
    
    public func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    @objc public func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        self.updateTextNodeText(animated: true)
        self.updateText?(editableTextNode.attributedText?.string ?? "")
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
    }
    
    public func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.clearButton.isHidden = false
        
        if self.selectTextOnce {
            self.selectTextOnce = false
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {
                self.textInputNode.selectedRange = NSRange(self.text.startIndex ..< self.text.endIndex, in: self.text)
            })
        }
    }
    
    public func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
        self.clearButton.isHidden = true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        
        let unboundTextFieldHeight = max(33.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude)).height))
        
        return min(61.0, max(41.0, unboundTextFieldHeight))
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
        self.textInputNode.attributedText = nil
        self.deactivateInput()
        self.updateHeight?()
    }
}
