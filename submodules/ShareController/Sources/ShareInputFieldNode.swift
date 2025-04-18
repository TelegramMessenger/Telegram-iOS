import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle
import ComponentFlow
import MultilineTextComponent
import AnimatedTextComponent

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

private final class ShareInputCopyComponent: Component {
    let theme: ShareInputFieldNodeTheme
    let strings: PresentationStrings
    let text: String
    let action: () -> Void
    
    init(
        theme: ShareInputFieldNodeTheme,
        strings: PresentationStrings,
        text: String,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.text = text
        self.action = action
    }
    
    static func ==(lhs: ShareInputCopyComponent, rhs: ShareInputCopyComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let text = ComponentView<Empty>()
        let button = ComponentView<Empty>()
        let textMask = UIImageView()
        
        var component: ShareInputCopyComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ShareInputCopyComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let textChanged = self.component != nil && self.component?.text != component.text
            self.component = component
            
            var textItems: [AnimatedTextComponent.Item] = []
            if let range = component.text.range(of: "?", options: .backwards) {
                textItems.append(AnimatedTextComponent.Item(id: 0, isUnbreakable: true, content: .text(String(component.text[component.text.startIndex ..< range.lowerBound]))))
                textItems.append(AnimatedTextComponent.Item(id: 1, isUnbreakable: true, content: .text(String(component.text[range.lowerBound...]))))
            } else {
                textItems.append(AnimatedTextComponent.Item(id: 0, isUnbreakable: true, content: .text(component.text)))
            }
            
            let sideInset: CGFloat = 12.0
            let textSize = self.text.update(
                transition: textChanged ? .spring(duration: 0.4) : .immediate,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(17.0),
                    color: component.theme.textColor,
                    items: textItems,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((availableSize.height - textSize.height) * 0.5)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                    textView.mask = self.textMask
                }
                textView.frame = textFrame
            }
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(Button(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Conversation_LinkDialogCopy, font: Font.regular(17.0), textColor: component.theme.accentColor))
                    )),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.component?.action()
                    }
                ).minSize(CGSize(width: 0.0, height: availableSize.height))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 40.0, height: 1000.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - buttonSize.width, y: floor((availableSize.height - buttonSize.height) * 0.5)), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                buttonView.frame = buttonFrame
            }
            
            if self.textMask.image == nil {
                let gradientWidth: CGFloat = 26.0
                self.textMask.image = generateGradientImage(size: CGSize(width: gradientWidth, height: 8.0), colors: [
                    UIColor(white: 1.0, alpha: 1.0),
                    UIColor(white: 1.0, alpha: 1.0),
                    UIColor(white: 1.0, alpha: 0.0)
                ], locations: [
                    0.0,
                    1.0 / gradientWidth,
                    1.0
                ], direction: .horizontal)?.resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: gradientWidth - 1.0), resizingMode: .stretch)
                self.textMask.frame = CGRect(origin: CGPoint(), size: CGSize(width: max(0.0, buttonFrame.minX - 4.0 - textFrame.minX), height: textFrame.height))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ShareInputFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    private let theme: ShareInputFieldNodeTheme
    private let strings: PresentationStrings
    private let backgroundNode: ASImageNode
    private let textInputNode: EditableTextNode
    private let placeholderNode: ASTextNode
    private let clearButton: HighlightableButtonNode
    
    private var copyView: ComponentView<Empty>?
    
    public var updateHeight: (() -> Void)?
    public var updateText: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 1.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 10.0, left: 8.0, bottom: 10.0, right: 22.0)
    private let accessoryButtonsWidth: CGFloat = 10.0
    private var inputCopyText: String?
    public var onInputCopyText: (() -> Void)?
    
    private var selectTextOnce: Bool = false
    
    public var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(17.0), textColor: self.theme.textColor)
            self.placeholderNode.isHidden = !newValue.isEmpty || self.inputCopyText != nil
            self.clearButton.isHidden = newValue.isEmpty
        }
    }
    
    public var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(17.0), textColor: self.theme.placeholderColor)
        }
    }
    
    public init(theme: ShareInputFieldNodeTheme, strings: PresentationStrings, placeholder: String) {
        self.theme = theme
        self.strings = strings
        
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
    
    public func updateLayout(width: CGFloat, inputCopyText: String?, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        self.inputCopyText = inputCopyText
        
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
        
        self.textInputNode.isUserInteractionEnabled = inputCopyText == nil
        self.textInputNode.isHidden = inputCopyText != nil
        self.placeholderNode.isHidden = !(self.textInputNode.textView.text ?? "").isEmpty || self.inputCopyText != nil
        
        if let inputCopyText {
            let copyView: ComponentView<Empty>
            if let current = self.copyView {
                copyView = current
            } else {
                copyView = ComponentView()
                self.copyView = copyView
            }
            let copyViewSize = copyView.update(
                transition: .immediate,
                component: AnyComponent(ShareInputCopyComponent(
                    theme: self.theme,
                    strings: self.strings,
                    text: inputCopyText,
                    action: {
                        self.onInputCopyText?()
                    }
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            let copyViewFrame = CGRect(origin: backgroundFrame.origin, size: copyViewSize)
            if let copyComponentView = copyView.view {
                if copyComponentView.superview == nil {
                    self.view.addSubview(copyComponentView)
                }
                copyComponentView.frame = copyViewFrame
            }
        } else if let copyView = self.copyView {
            self.copyView = nil
            copyView.view?.removeFromSuperview()
        }
        
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
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty || self.inputCopyText != nil
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
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty || self.inputCopyText != nil
        self.clearButton.isHidden = true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        
        if self.inputCopyText != nil {
            return 41.0
        } else {
            let unboundTextFieldHeight = max(33.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude)).height))
            
            return min(61.0, max(41.0, unboundTextFieldHeight))
        }
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
