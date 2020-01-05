import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import HexColor

private var currentTextInputBackgroundImage: (UIColor, UIColor, CGFloat, UIImage)?
private func textInputBackgroundImage(fieldColor: UIColor, strokeColor: UIColor, diameter: CGFloat) -> UIImage? {
    if let current = currentTextInputBackgroundImage {
        if current.0.isEqual(fieldColor) && current.1.isEqual(strokeColor) && current.2.isEqual(to: diameter) {
            return current.3
        }
    }
    
    let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
        context.setFillColor(fieldColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
        context.setStrokeColor(strokeColor.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: diameter - strokeWidth, height: diameter - strokeWidth))
    })?.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
    if let image = image {
        currentTextInputBackgroundImage = (fieldColor, strokeColor, diameter, image)
        return image
    } else {
        return nil
    }
}

private func generateSwatchBorderImage(theme: PresentationTheme) -> UIImage? {
    return nil
    return generateImage(CGSize(width: 21.0, height: 21.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setLineWidth(1.0)
        context.setStrokeColor(theme.chat.inputPanel.inputControlColor.cgColor)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
    })
}

private class ColorInputFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    
    private let swatchNode: ASDisplayNode
    private let borderNode: ASImageNode
    private let removeButton: HighlightableButtonNode
    private let textBackgroundNode: ASImageNode
    private let selectionNode: ASDisplayNode
    let textFieldNode: TextFieldNode
    private let measureNode: ImmediateTextNode
    private let prefixNode: ASTextNode
    
    private var gestureRecognizer: UITapGestureRecognizer?
        
    var colorChanged: ((UIColor, Bool) -> Void)?
    var colorRemoved: (() -> Void)?
    var colorSelected: (() -> Void)?
    
    private var color: UIColor?
    
    private var isDefault = false {
        didSet {
            self.updateSelectionVisibility()
        }
    }
    
    var isRemovable: Bool = false {
        didSet {
            self.removeButton.isUserInteractionEnabled = self.isRemovable
        }
    }
    
    var isSelected: Bool = false {
        didSet {
            self.updateSelectionVisibility()
            self.gestureRecognizer?.isEnabled = !self.isSelected
            if !self.isSelected {
                self.textFieldNode.textField.resignFirstResponder()
            }
        }
    }
   
    private var previousIsDefault: Bool?
    private var previousColor: UIColor?
    private var validLayout: (CGSize, Bool)?
    
    private var skipEndEditing = false
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.textBackgroundNode = ASImageNode()
        self.textBackgroundNode.image = textInputBackgroundImage(fieldColor: theme.chat.inputPanel.inputBackgroundColor, strokeColor: theme.chat.inputPanel.inputStrokeColor, diameter: 33.0)
        self.textBackgroundNode.displayWithoutProcessing = true
        self.textBackgroundNode.displaysAsynchronously = false
        
        self.selectionNode = ASDisplayNode()
        self.selectionNode.backgroundColor = theme.chat.inputPanel.panelControlAccentColor.withAlphaComponent(0.2)
        self.selectionNode.cornerRadius = 3.0
        self.selectionNode.isUserInteractionEnabled = false
        
        self.textFieldNode = TextFieldNode()
        self.measureNode = ImmediateTextNode()
        
        self.prefixNode = ASTextNode()
        self.prefixNode.attributedText = NSAttributedString(string: "#", font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.inputTextColor)
        
        self.swatchNode = ASDisplayNode()
        self.swatchNode.cornerRadius = 10.5
        
        self.borderNode = ASImageNode()
        self.borderNode.displaysAsynchronously = false
        self.borderNode.displayWithoutProcessing = true
        self.borderNode.image = generateSwatchBorderImage(theme: theme)
        
        self.removeButton = HighlightableButtonNode()
        self.removeButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorRemoveIcon"), color: theme.chat.inputPanel.inputControlColor), for: .normal)
                
        super.init()
        
        self.addSubnode(self.textBackgroundNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.textFieldNode)
        self.addSubnode(self.prefixNode)
        self.addSubnode(self.swatchNode)
        self.addSubnode(self.borderNode)
        self.addSubnode(self.removeButton)
        
        self.removeButton.addTarget(self, action: #selector(self.removePressed), forControlEvents: .touchUpInside)
    }
        
    override func didLoad() {
        super.didLoad()
        
        self.textFieldNode.textField.font = Font.regular(17.0)
        self.textFieldNode.textField.textColor = self.theme.chat.inputPanel.inputTextColor
        self.textFieldNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.autocorrectionType = .no
        self.textFieldNode.textField.autocapitalizationType = .allCharacters
        self.textFieldNode.textField.keyboardType = .asciiCapable
        self.textFieldNode.textField.returnKeyType = .done
        self.textFieldNode.textField.delegate = self
        self.textFieldNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textFieldNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textFieldNode.textField.tintColor = self.theme.list.itemAccentColor
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.view.addGestureRecognizer(gestureRecognizer)
        self.gestureRecognizer = gestureRecognizer
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.textBackgroundNode.image = textInputBackgroundImage(fieldColor: self.theme.chat.inputPanel.inputBackgroundColor, strokeColor: self.theme.chat.inputPanel.inputStrokeColor, diameter: 33.0)
        
        self.textFieldNode.textField.textColor = self.isDefault ? self.theme.chat.inputPanel.inputPlaceholderColor : self.theme.chat.inputPanel.inputTextColor
        self.textFieldNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.tintColor = self.theme.list.itemAccentColor
        
        self.selectionNode.backgroundColor = theme.chat.inputPanel.panelControlAccentColor.withAlphaComponent(0.2)
        self.borderNode.image = generateSwatchBorderImage(theme: theme)
        self.updateBorderVisibility()
    }
    
    func setColor(_ color: UIColor, isDefault: Bool = false, update: Bool = true, ended: Bool = true) {
        self.color = color
        self.isDefault = isDefault
        let text = color.hexString.uppercased()
        self.textFieldNode.textField.text = text
        self.textFieldNode.textField.textColor = isDefault ? self.theme.chat.inputPanel.inputPlaceholderColor : self.theme.chat.inputPanel.inputTextColor
        if let (size, _) = self.validLayout {
            self.updateSelectionLayout(size: size, transition: .immediate)
        }
        if update {
            self.colorChanged?(color, ended)
        }
        self.swatchNode.backgroundColor = color
        self.updateBorderVisibility()
    }
    
    private func updateBorderVisibility() {
        guard let color = self.swatchNode.backgroundColor else {
            return
        }
        let inputBackgroundColor = self.theme.chat.inputPanel.inputBackgroundColor
        if color.distance(to: inputBackgroundColor) < 200 {
            self.borderNode.alpha = 1.0
        } else {
            self.borderNode.alpha = 0.0
        }
    }
    
    @objc private func removePressed() {
        if self.textFieldNode.textField.isFirstResponder {
            self.skipEndEditing = true
        }
        
        self.colorRemoved?()
        self.removeButton.layer.removeAnimation(forKey: "opacity")
        self.removeButton.alpha = 1.0
    }
    
    @objc private func tapped() {
        self.colorSelected?()
    }
        
    @objc internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var updated = textField.text ?? ""
        updated.replaceSubrange(updated.index(updated.startIndex, offsetBy: range.lowerBound) ..< updated.index(updated.startIndex, offsetBy: range.upperBound), with: string)
        if updated.count <= 6 && updated.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil {
            textField.text = updated.uppercased()
            textField.textColor = self.theme.chat.inputPanel.inputTextColor
            
            if updated.count == 6, let color = UIColor(hexString: updated) {
                self.setColor(color)
            }
            
            if let (size, _) = self.validLayout {
                self.updateSelectionLayout(size: size, transition: .immediate)
            }
        }
        return false
    }
    
    @objc func textFieldTextChanged(_ sender: UITextField) {
        if let color = self.colorFromCurrentText() {
            self.setColor(color)
        }
        
        if let (size, _) = self.validLayout {
            self.updateSelectionLayout(size: size, transition: .immediate)
        }
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.skipEndEditing = true
        if let color = self.colorFromCurrentText() {
            self.setColor(color)
        } else {
            self.setColor(self.previousColor ?? .black, isDefault: self.previousIsDefault ?? false)
        }
        self.textFieldNode.textField.resignFirstResponder()
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if self.isSelected {
            self.skipEndEditing = false
            self.previousColor = self.color
            self.previousIsDefault = self.isDefault
            
            textField.textColor = self.theme.chat.inputPanel.inputTextColor
            
            return true
        } else {
            self.colorSelected?()
            return false
        }
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        if !self.skipEndEditing {
            if let color = self.colorFromCurrentText() {
                self.setColor(color)
            } else {
                self.setColor(self.previousColor ?? .black, isDefault: self.previousIsDefault ?? false)
            }
        }
    }
    
    func setSkipEndEditingIfNeeded() {
        if self.textFieldNode.textField.isFirstResponder && self.colorFromCurrentText() != nil {
            self.skipEndEditing = true
        }
    }
    
    private func colorFromCurrentText() -> UIColor? {
        if let text = self.textFieldNode.textField.text, text.count == 6, let color = UIColor(hexString: text) {
            return color
        } else {
            return nil
        }
    }
    
    private func updateSelectionLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.measureNode.attributedText = NSAttributedString(string: self.textFieldNode.textField.text ?? "", font: self.textFieldNode.textField.font)
        let size = self.measureNode.updateLayout(size)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(x: self.textFieldNode.frame.minX, y: 6.0, width: max(0.0, size.width), height: 20.0))
    }
    
    private func updateSelectionVisibility() {
        self.selectionNode.isHidden = !self.isSelected || self.isDefault
    }
    
    func updateLayout(size: CGSize, condensed: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, condensed)
        
        let swatchFrame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 21.0, height: 21.0))
        transition.updateFrame(node: self.swatchNode, frame: swatchFrame)
        transition.updateFrame(node: self.borderNode, frame: swatchFrame)
        
        let textPadding: CGFloat = condensed ? 31.0 : 37.0
        
        transition.updateFrame(node: self.textBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.textFieldNode, frame: CGRect(x: textPadding + 10.0, y: 1.0, width: size.width - (21.0 + textPadding), height: size.height - 2.0))
        
        self.updateSelectionLayout(size: size, transition: transition)
        
        let prefixSize = self.prefixNode.measure(size)
        transition.updateFrame(node: self.prefixNode, frame: CGRect(origin: CGPoint(x: textPadding - UIScreenPixel, y: 6.0), size: prefixSize))
        
        let removeSize = CGSize(width: 33.0, height: 33.0)
        let removeOffset: CGFloat = condensed ? 3.0 : 0.0
        transition.updateFrame(node: self.removeButton, frame: CGRect(origin: CGPoint(x: size.width - removeSize.width + removeOffset, y: 0.0), size: removeSize))
        transition.updateAlpha(node: self.removeButton, alpha: self.isRemovable ? 1.0 : 0.0)
    }
}

enum WallpaperColorPanelNodeSelectionState {
    case none
    case first
    case second
}

struct WallpaperColorPanelNodeState {
    var selection: WallpaperColorPanelNodeSelectionState
    var firstColor: UIColor?
    var defaultColor: UIColor?
    var secondColor: UIColor?
    var secondColorAvailable: Bool
    var rotateAvailable: Bool
    var rotation: Int32
    var preview: Bool
    var simpleGradientGeneration: Bool
}

final class WallpaperColorPanelNode: ASDisplayNode {
    private var theme: PresentationTheme
     
    private var state: WallpaperColorPanelNodeState
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let firstColorFieldNode: ColorInputFieldNode
    private let secondColorFieldNode: ColorInputFieldNode
    private let rotateButton: HighlightableButtonNode
    private let swapButton: HighlightableButtonNode
    private let addButton: HighlightableButtonNode
    private let doneButton: HighlightableButtonNode
    private let colorPickerNode: WallpaperColorPickerNode

    var colorsChanged: ((UIColor?, UIColor?, Bool) -> Void)?
    var colorSelected: (() -> Void)?
    var rotate: (() -> Void)?
    
    var colorAdded: (() -> Void)?
    var colorRemoved: (() -> Void)?
    
    private var validLayout: CGSize?

    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        self.bottomSeparatorNode =  ASDisplayNode()
        self.bottomSeparatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
            
        self.doneButton = HighlightableButtonNode()
        self.doneButton.setImage(PresentationResourcesChat.chatInputPanelApplyButtonImage(theme), for: .normal)
    
        self.colorPickerNode = WallpaperColorPickerNode(strings: strings)
        
        self.rotateButton = HighlightableButtonNode()
        self.rotateButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorRotateIcon"), color: theme.chat.inputPanel.panelControlColor), for: .normal)
        self.swapButton = HighlightableButtonNode()
        self.swapButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorSwapIcon"), color: theme.chat.inputPanel.panelControlColor), for: .normal)
        self.addButton = HighlightableButtonNode()
        self.addButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorAddIcon"), color: theme.chat.inputPanel.panelControlColor), for: .normal)
        
        self.firstColorFieldNode = ColorInputFieldNode(theme: theme)
        self.secondColorFieldNode = ColorInputFieldNode(theme: theme)
        
        self.state = WallpaperColorPanelNodeState(selection: .first, firstColor: nil, secondColor: nil, secondColorAvailable: false, rotateAvailable: false, rotation: 0, preview: false, simpleGradientGeneration: false)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.firstColorFieldNode)
        self.addSubnode(self.secondColorFieldNode)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.colorPickerNode)
        
        self.addSubnode(self.rotateButton)
        self.addSubnode(self.swapButton)
        self.addSubnode(self.addButton)
        
        self.rotateButton.addTarget(self, action: #selector(self.rotatePressed), forControlEvents: .touchUpInside)
        self.swapButton.addTarget(self, action: #selector(self.swapPressed), forControlEvents: .touchUpInside)
        self.addButton.addTarget(self, action: #selector(self.addPressed), forControlEvents: .touchUpInside)
        
        self.firstColorFieldNode.colorChanged = { [weak self] color, ended in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.firstColor = color
                    return updated
                })
            }
        }
        self.firstColorFieldNode.colorRemoved = { [weak self] in
            if let strongSelf = self {
                strongSelf.colorRemoved?()
                strongSelf.updateState({ current in
                    var updated = current
                    updated.selection = .first
                    if let defaultColor = current.defaultColor, updated.secondColor == nil {
                        updated.firstColor = nil
                    } else {
                        updated.firstColor = updated.secondColor ?? updated.firstColor
                    }
                    updated.secondColor = nil
                    return updated
                }, animated: strongSelf.state.secondColor != nil)
            }
        }
        self.firstColorFieldNode.colorSelected = { [weak self] in
            if let strongSelf = self {
                strongSelf.secondColorFieldNode.setSkipEndEditingIfNeeded()
                strongSelf.updateState({ current in
                    var updated = current
                    if updated.selection != .none {
                        updated.selection = .first
                    }
                    return updated
                })
                
                strongSelf.colorSelected?()
            }
        }
        
        self.secondColorFieldNode.colorChanged = { [weak self] color, ended in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.secondColor = color
                    return updated
                })
            }
        }
        self.secondColorFieldNode.colorRemoved = { [weak self] in
            if let strongSelf = self {
                strongSelf.colorRemoved?()
                strongSelf.updateState({ current in
                    var updated = current
                    if updated.selection != .none {
                        updated.selection = .first
                    }
                    updated.secondColor = nil
                    return updated
                })
            }
        }
        self.secondColorFieldNode.colorSelected = { [weak self] in
            if let strongSelf = self {
                strongSelf.firstColorFieldNode.setSkipEndEditingIfNeeded()
                strongSelf.updateState({ current in
                    var updated = current
                    updated.selection = .second
                    return updated
                })
                
                strongSelf.colorSelected?()
            }
        }
        
        self.colorPickerNode.colorChanged = { [weak self] color in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.preview = true
                    switch strongSelf.state.selection {
                        case .first:
                            updated.firstColor = color
                        case .second:
                            updated.secondColor = color
                        default:
                            break
                    }
                    return updated
                }, updateLayout: false)
            }
        }
        self.colorPickerNode.colorChangeEnded = { [weak self] color in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.preview = false
                    switch strongSelf.state.selection {
                        case .first:
                            updated.firstColor = color
                        case .second:
                            updated.secondColor = color
                        default:
                            break
                    }
                    return updated
                }, updateLayout: false)
            }
        }
    }
        
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundNode.backgroundColor = self.theme.chat.inputPanel.panelBackgroundColor
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
        self.bottomSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
        self.firstColorFieldNode.updateTheme(theme)
        self.secondColorFieldNode.updateTheme(theme)
    }
    
    func updateState(_ f: (WallpaperColorPanelNodeState) -> WallpaperColorPanelNodeState, updateLayout: Bool = true, animated: Bool = true) {
        var updateLayout = updateLayout
        let previousFirstColor = self.state.firstColor
        let previousSecondColor = self.state.secondColor
        let previousPreview = self.state.preview
        let previousRotation = self.state.rotation
        self.state = f(self.state)
        
        let firstColor: UIColor
        var firstColorIsDefault = false
        if let color = self.state.firstColor {
            firstColor = color
        } else if let defaultColor = self.state.defaultColor {
            firstColor = defaultColor
            firstColorIsDefault = true
        } else {
            firstColor = .white
        }
        let secondColor = self.state.secondColor
        
        if secondColor == nil && previousSecondColor != nil && firstColor == previousSecondColor && animated {
            self.animateLeftColorFieldOut()
        }
        
        self.firstColorFieldNode.setColor(firstColor, isDefault: self.state.firstColor == nil, update: false)
        if let secondColor = secondColor {
            self.secondColorFieldNode.setColor(secondColor, update: false)
        }
        
        var firstColorWasRemovable = self.firstColorFieldNode.isRemovable
        self.firstColorFieldNode.isRemovable = self.state.secondColor != nil || (self.state.defaultColor != nil && self.state.firstColor != nil)
        if firstColorWasRemovable != self.firstColorFieldNode.isRemovable {
            updateLayout = true
        }
    
        if updateLayout, let size = self.validLayout {
            switch self.state.selection {
                case .first:
                    self.colorPickerNode.color = firstColor
                case .second:
                    if let secondColor = secondColor {
                        self.colorPickerNode.color = secondColor
                    }
                default:
                    break
            }
            
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
        }
        
        if self.state.firstColor?.argb != previousFirstColor?.argb || self.state.secondColor?.argb != previousSecondColor?.argb || self.state.preview != previousPreview {
            self.colorsChanged?(firstColorIsDefault ? nil : firstColor, secondColor, !self.state.preview)
        }
    }
    
    private func animateLeftColorFieldOut() {
        guard let size = self.validLayout else {
            return
        }
        
        let condensedLayout = size.width < 375.0
        let leftInset: CGFloat
        let fieldSpacing: CGFloat
        if condensedLayout {
            leftInset = 6.0
            fieldSpacing = 40.0
        } else {
            leftInset = 15.0
            fieldSpacing = 45.0
        }
        let rightInsetWithButton: CGFloat = 42.0
        
        let offset: CGFloat = -(self.secondColorFieldNode.frame.minX - leftInset)
        
        if let fieldSnapshotView = self.firstColorFieldNode.view.snapshotView(afterScreenUpdates: false) {
            fieldSnapshotView.frame = self.firstColorFieldNode.frame
            self.view.addSubview(fieldSnapshotView)
            
            fieldSnapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: offset, y: 0.0), duration: 0.3, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, force: false) { _ in
                fieldSnapshotView.removeFromSuperview()
            }
        }
        
        let middleButton: ASDisplayNode
        if self.rotateButton.alpha > 1.0 {
            middleButton = self.rotateButton
        } else {
            middleButton = self.swapButton
        }
        if let buttonSnapshotView = middleButton.view.snapshotContentTree() {
            buttonSnapshotView.frame = middleButton.frame
            self.view.addSubview(buttonSnapshotView)
            
            buttonSnapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: offset, y: 0.0), duration: 0.3, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, force: false) { _ in
                buttonSnapshotView.removeFromSuperview()
            }
        }
        
        self.rotateButton.alpha = 0.0
        self.swapButton.alpha = 0.0
        
        let buttonOffset: CGFloat = (rightInsetWithButton - 13.0) / 2.0
        var buttonFrame = self.addButton.frame
        buttonFrame.origin.x = size.width
        self.addButton.frame = buttonFrame
        self.addButton.alpha = 1.0
        
        self.firstColorFieldNode.frame = self.secondColorFieldNode.frame
        
        var fieldFrame = self.secondColorFieldNode.frame
        fieldFrame.origin.x = fieldFrame.maxX + fieldSpacing
        self.secondColorFieldNode.frame = fieldFrame
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let condensedLayout = size.width < 375.0
        let separatorHeight = UIScreenPixel
        let topPanelHeight: CGFloat = 47.0
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: topPanelHeight))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: separatorHeight))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(x: 0.0, y: topPanelHeight, width: size.width, height: separatorHeight))
        
        let fieldHeight: CGFloat = 33.0
        let leftInset: CGFloat
        let rightInset: CGFloat
        let fieldSpacing: CGFloat
        if condensedLayout {
            leftInset = 6.0
            rightInset = 6.0
            fieldSpacing = 40.0
        } else {
            leftInset = 15.0
            rightInset = 15.0
            fieldSpacing = 45.0
        }
        let rightInsetWithButton: CGFloat = 42.0
        
        let buttonSize = CGSize(width: 26.0, height: 26.0)
        let buttonOffset: CGFloat = (rightInsetWithButton - 13.0) / 2.0
        let middleButtonFrame = CGRect(origin: CGPoint(x: self.state.secondColor != nil ? floor((size.width - 26.0) / 2.0) : (self.state.secondColorAvailable ? size.width - rightInsetWithButton + floor((rightInsetWithButton - buttonSize.width) / 2.0) : size.width + buttonOffset), y: floor((topPanelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        transition.updateFrame(node: self.rotateButton, frame: middleButtonFrame)
        transition.updateFrame(node: self.swapButton, frame: middleButtonFrame)
        transition.updateFrame(node: self.addButton, frame: middleButtonFrame)
        
        let rotateButtonAlpha: CGFloat
        let swapButtonAlpha: CGFloat
        let addButtonAlpha: CGFloat
        if let _ = self.state.secondColor {
            if self.state.rotateAvailable {
                rotateButtonAlpha = 1.0
                swapButtonAlpha = 0.0
            } else {
                rotateButtonAlpha = 0.0
                swapButtonAlpha = 1.0
            }
            addButtonAlpha = 0.0
        } else {
            swapButtonAlpha = 0.0
            rotateButtonAlpha = 0.0
            if self.state.secondColorAvailable {
                addButtonAlpha = 1.0
            } else {
                addButtonAlpha = 0.0
            }
        }
        transition.updateAlpha(node: self.rotateButton, alpha: rotateButtonAlpha)
        transition.updateAlpha(node: self.swapButton, alpha: swapButtonAlpha)
        transition.updateAlpha(node: self.addButton, alpha: addButtonAlpha)
        
        func degreesToRadians(_ degrees: CGFloat) -> CGFloat
        {
            var degrees = degrees
            if degrees >= 270.0 {
                degrees = degrees - 360.0
            }
            return degrees * CGFloat.pi / 180.0
        }

        transition.updateTransformRotation(node: self.rotateButton, angle: degreesToRadians(CGFloat(self.state.rotation)), beginWithCurrentState: true, completion: nil)
        
        self.firstColorFieldNode.isRemovable = self.state.secondColor != nil || (self.state.defaultColor != nil && self.state.firstColor != nil)
        self.secondColorFieldNode.isRemovable = true
        
        self.firstColorFieldNode.isSelected = self.state.selection == .first
        self.secondColorFieldNode.isSelected = self.state.selection == .second
        
        let firstFieldFrame = CGRect(x: leftInset, y: (topPanelHeight - fieldHeight) / 2.0, width: self.state.secondColor != nil ? floorToScreenPixels((size.width - fieldSpacing) / 2.0) - leftInset : size.width - leftInset - (self.state.secondColorAvailable ? rightInsetWithButton : rightInset), height: fieldHeight)
        transition.updateFrame(node: self.firstColorFieldNode, frame: firstFieldFrame)
        self.firstColorFieldNode.updateLayout(size: firstFieldFrame.size, condensed: condensedLayout, transition: transition)
        
        let secondFieldFrame = CGRect(x: firstFieldFrame.maxX + fieldSpacing, y: (topPanelHeight - fieldHeight) / 2.0, width: firstFieldFrame.width, height: fieldHeight)
        transition.updateFrame(node: self.secondColorFieldNode, frame: secondFieldFrame)
        self.secondColorFieldNode.updateLayout(size: secondFieldFrame.size, condensed: condensedLayout, transition: transition)
        
        let colorPickerSize = CGSize(width: size.width, height: size.height - topPanelHeight - separatorHeight)
        transition.updateFrame(node: self.colorPickerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + separatorHeight), size: colorPickerSize))
        self.colorPickerNode.updateLayout(size: colorPickerSize, transition: transition)
    }
    
    @objc private func rotatePressed() {
        self.rotate?()
        self.updateState({ current in
            var updated = current
            var newRotation = updated.rotation + 45
            if newRotation >= 360 {
                newRotation = 0
            }
            updated.rotation = newRotation
            return updated
        })
    }
    
    @objc private func swapPressed() {
        self.updateState({ current in
            var updated = current
            if let secondColor = current.secondColor {
                updated.firstColor = secondColor
                updated.secondColor = current.firstColor
            }
            return updated
        })
    }
    
    @objc private func addPressed() {
        self.colorSelected?()
        self.colorAdded?()
        
        self.firstColorFieldNode.setSkipEndEditingIfNeeded()
        
        self.updateState({ current in
            var updated = current
            updated.selection = .second
            
            let firstColor = current.firstColor ?? current.defaultColor
            if let color = firstColor {
                updated.firstColor = color
                
                let secondColor: UIColor
                if updated.simpleGradientGeneration {
                    var hsb = color.hsb
                    if hsb.1 > 0.5 {
                        hsb.1 -= 0.15
                    } else {
                        hsb.1 += 0.15
                    }
                    if hsb.0 > 0.5 {
                        hsb.0 -= 0.05
                    } else {
                        hsb.0 += 0.05
                    }
                    updated.secondColor = UIColor(hue: hsb.0, saturation: hsb.1, brightness: hsb.2, alpha: 1.0)
                } else {
                    updated.secondColor = generateGradientColors(color: color).1
                }
            }

            return updated
        })
    }
}
