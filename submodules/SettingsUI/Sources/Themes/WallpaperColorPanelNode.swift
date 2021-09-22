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
   
    private var previousIsDefault: Bool?
    private var previousColor: UIColor?
    private var validLayout: (CGSize, Bool)?
    
    private var skipEndEditing = false

    private let displaySwatch: Bool
    
    init(theme: PresentationTheme, displaySwatch: Bool = true) {
        self.theme = theme

        self.displaySwatch = displaySwatch
        
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
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:)))
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
    }
    
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.colorSelected?()
        }
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
        self.skipEndEditing = false
        self.previousColor = self.color
        self.previousIsDefault = self.isDefault

        textField.textColor = self.theme.chat.inputPanel.inputTextColor

        return true
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
        self.selectionNode.isHidden = true
    }
    
    func updateLayout(size: CGSize, condensed: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, condensed)
        
        let swatchFrame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 21.0, height: 21.0))
        transition.updateFrame(node: self.swatchNode, frame: swatchFrame)
        transition.updateFrame(node: self.borderNode, frame: swatchFrame)

        self.swatchNode.isHidden = !self.displaySwatch
        
        let textPadding: CGFloat
        if self.displaySwatch {
            textPadding = condensed ? 31.0 : 37.0
        } else {
            textPadding = 12.0
        }
        
        transition.updateFrame(node: self.textBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.textFieldNode, frame: CGRect(x: textPadding + 10.0, y: 1.0, width: size.width - (21.0 + textPadding), height: size.height - 2.0))
        
        self.updateSelectionLayout(size: size, transition: transition)
        
        let prefixSize = self.prefixNode.measure(size)
        transition.updateFrame(node: self.prefixNode, frame: CGRect(origin: CGPoint(x: textPadding - UIScreenPixel, y: 6.0), size: prefixSize))
        
        let removeSize = CGSize(width: 33.0, height: 33.0)
        let removeOffset: CGFloat = condensed ? 3.0 : 0.0
        transition.updateFrame(node: self.removeButton, frame: CGRect(origin: CGPoint(x: size.width - removeSize.width + removeOffset, y: 0.0), size: removeSize))
        self.removeButton.alpha = self.isRemovable ? 1.0 : 0.0
    }
}

struct WallpaperColorPanelNodeState: Equatable {
    var selection: Int?
    var colors: [HSBColor]
    var maximumNumberOfColors: Int
    var rotateAvailable: Bool
    var rotation: Int32
    var preview: Bool
    var simpleGradientGeneration: Bool
    var suggestedNewColor: HSBColor?
}

private final class ColorSampleItemNode: ASImageNode {
    private struct State: Equatable {
        var color: UInt32
        var size: CGSize
        var isSelected: Bool
    }

    private var action: () -> Void
    private var validState: State?

    init(action: @escaping () -> Void) {
        self.action = action

        super.init()

        self.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action()
        }
    }

    func update(size: CGSize, color: UIColor, isSelected: Bool) {
        let state = State(color: color.rgb, size: size, isSelected: isSelected)
        if self.validState != state {
            self.validState = state

            self.image = generateImage(CGSize(width: size.width, height: size.height), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))

                context.setBlendMode(.softLight)
                context.setStrokeColor(UIColor(white: 0.0, alpha: 0.3).cgColor)
                context.setLineWidth(UIScreenPixel)
                context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: UIScreenPixel, dy: UIScreenPixel))

                if isSelected {
                    context.setBlendMode(.copy)
                    context.setStrokeColor(UIColor.clear.cgColor)
                    let lineWidth: CGFloat = 2.0
                    context.setLineWidth(lineWidth)
                    let inset: CGFloat = 2.0 + lineWidth / 2.0
                    context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset))
                }
            })
        }
    }
}

final class WallpaperColorPanelNode: ASDisplayNode {
    private var theme: PresentationTheme
     
    private var state: WallpaperColorPanelNodeState
    
    private let backgroundNode: NavigationBackgroundNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let rotateButton: HighlightableButtonNode
    private let swapButton: HighlightableButtonNode
    private let addButton: HighlightableButtonNode
    private let doneButton: HighlightableButtonNode
    private let colorPickerNode: WallpaperColorPickerNode

    private var sampleItemNodes: [ColorSampleItemNode] = []
    private let multiColorFieldNode: ColorInputFieldNode

    var colorsChanged: (([HSBColor], Int, Bool) -> Void)?
    var colorSelected: (() -> Void)?
    var rotate: (() -> Void)?
    
    var colorAdded: (() -> Void)?
    var colorRemoved: (() -> Void)?
    
    private var validLayout: CGSize?

    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.chat.inputPanel.panelBackgroundColor)
        
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

        self.multiColorFieldNode = ColorInputFieldNode(theme: theme, displaySwatch: false)
        
        self.state = WallpaperColorPanelNodeState(
            selection: 0,
            colors: [],
            maximumNumberOfColors: 1,
            rotateAvailable: false,
            rotation: 0,
            preview: false,
            simpleGradientGeneration: false
        )
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.multiColorFieldNode)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.colorPickerNode)
        
        self.addSubnode(self.rotateButton)
        self.addSubnode(self.swapButton)
        self.addSubnode(self.addButton)
        
        self.rotateButton.addTarget(self, action: #selector(self.rotatePressed), forControlEvents: .touchUpInside)
        self.swapButton.addTarget(self, action: #selector(self.swapPressed), forControlEvents: .touchUpInside)
        self.addButton.addTarget(self, action: #selector(self.addPressed), forControlEvents: .touchUpInside)

        self.multiColorFieldNode.colorChanged = { [weak self] color, ended in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.preview = !ended
                    if let index = strongSelf.state.selection {
                        updated.colors[index] = HSBColor(color: color)
                    }
                    return updated
                })
            }
        }
        self.multiColorFieldNode.colorRemoved = { [weak self] in
            if let strongSelf = self {
                strongSelf.colorRemoved?()
                strongSelf.updateState({ current in
                    var updated = current
                    if let index = strongSelf.state.selection {
                        updated.colors.remove(at: index)
                        if updated.colors.isEmpty {
                            updated.selection = nil
                        } else {
                            updated.selection = max(0, min(index - 1, updated.colors.count - 1))
                        }
                    }
                    return updated
                }, animated: strongSelf.state.colors.count >= 2)
            }
        }
        
        self.colorPickerNode.colorChanged = { [weak self] color in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.preview = true
                    if let index = strongSelf.state.selection {
                        updated.colors[index] = color
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
                    if let index = strongSelf.state.selection {
                        updated.colors[index] = color
                    }
                    return updated
                }, updateLayout: false)
            }
        }
    }
        
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundNode.updateColor(color: self.theme.chat.inputPanel.panelBackgroundColor, transition: .immediate)
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
        self.bottomSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
        self.multiColorFieldNode.updateTheme(theme)
    }
    
    func updateState(_ f: (WallpaperColorPanelNodeState) -> WallpaperColorPanelNodeState, updateLayout: Bool = true, animated: Bool = true) {
        var updateLayout = updateLayout
        let previousColors = self.state.colors
        let previousPreview = self.state.preview
        let previousSelection = self.state.selection
        self.state = f(self.state)
        
        let colorWasRemovable = self.multiColorFieldNode.isRemovable
        self.multiColorFieldNode.isRemovable = self.state.colors.count > 1
        if colorWasRemovable != self.multiColorFieldNode.isRemovable {
            updateLayout = true
        }

        if let index = self.state.selection {
            if self.state.colors.count > index {
                self.colorPickerNode.color = self.state.colors[index]
            }
        }
    
        if updateLayout, let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
        }

        if let index = self.state.selection {
            if self.state.colors.count > index {
                self.multiColorFieldNode.setColor(self.state.colors[index].color, update: false)
            }
        }

        for i in 0 ..< self.state.colors.count {
            if i < self.sampleItemNodes.count {
                self.sampleItemNodes[i].update(size: self.sampleItemNodes[i].bounds.size, color: self.state.colors[i].color, isSelected: state.selection == i)
            }
        }

        if self.state.colors != previousColors || self.state.preview != previousPreview || self.state.selection != previousSelection {
            self.colorsChanged?(self.state.colors, self.state.selection ?? 0, !self.state.preview)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let condensedLayout = size.width < 375.0
        let separatorHeight = UIScreenPixel
        let topPanelHeight: CGFloat = 47.0
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: topPanelHeight))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: separatorHeight))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(x: 0.0, y: topPanelHeight, width: size.width, height: separatorHeight))
        
        let fieldHeight: CGFloat = 33.0
        let leftInset: CGFloat
        let rightInset: CGFloat
        if condensedLayout {
            leftInset = 6.0
            rightInset = 6.0
        } else {
            leftInset = 15.0
            rightInset = 15.0
        }
        
        let buttonSize = CGSize(width: 26.0, height: 26.0)
        let canAddColors = self.state.colors.count < self.state.maximumNumberOfColors

        transition.updateFrame(node: self.addButton, frame: CGRect(origin: CGPoint(x: size.width - rightInset - buttonSize.width, y: floor((topPanelHeight - buttonSize.height) / 2.0)), size: buttonSize))
        transition.updateAlpha(node: self.addButton, alpha: canAddColors ? 1.0 : 0.0)
        transition.updateSublayerTransformScale(node: self.addButton, scale: canAddColors ? 1.0 : 0.1)
        
        func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
            var degrees = degrees
            if degrees >= 270.0 {
                degrees = degrees - 360.0
            }
            return degrees * CGFloat.pi / 180.0
        }

        transition.updateTransformRotation(node: self.rotateButton, angle: degreesToRadians(CGFloat(self.state.rotation)), beginWithCurrentState: true, completion: nil)

        self.rotateButton.isHidden = true
        self.swapButton.isHidden = true
        self.multiColorFieldNode.isHidden = false

        let sampleItemSize: CGFloat = 32.0
        let sampleItemSpacing: CGFloat = 15.0

        var nextSampleX = leftInset

        for i in 0 ..< self.state.colors.count {
            var animateIn = false
            let itemNode: ColorSampleItemNode
            if self.sampleItemNodes.count > i {
                itemNode = self.sampleItemNodes[i]
            } else {
                itemNode = ColorSampleItemNode(action: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let index = i
                    strongSelf.updateState({ state in
                        var state = state
                        state.selection = index
                        return state
                    })
                })
                self.sampleItemNodes.append(itemNode)
                self.insertSubnode(itemNode, aboveSubnode: self.multiColorFieldNode)
                animateIn = true
            }

            if i != 0 {
                nextSampleX += sampleItemSpacing
            }
            itemNode.frame = CGRect(origin: CGPoint(x: nextSampleX, y: (topPanelHeight - sampleItemSize) / 2.0), size: CGSize(width: sampleItemSize, height: sampleItemSize))
            nextSampleX += sampleItemSize
            itemNode.update(size: itemNode.bounds.size, color: self.state.colors[i].color, isSelected: self.state.selection == i)

            if animateIn {
                transition.animateTransformScale(node: itemNode, from: 0.1)
                itemNode.alpha = 0.0
                transition.updateAlpha(node: itemNode, alpha: 1.0)
            }
        }
        if self.sampleItemNodes.count > self.state.colors.count {
            for i in self.state.colors.count ..< self.sampleItemNodes.count {
                let itemNode = self.sampleItemNodes[i]
                transition.updateTransformScale(node: itemNode, scale: 0.1)
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
            self.sampleItemNodes.removeSubrange(self.state.colors.count ..< self.sampleItemNodes.count)
        }

        let fieldX = nextSampleX + sampleItemSpacing

        let fieldFrame = CGRect(x: fieldX, y: (topPanelHeight - fieldHeight) / 2.0, width: size.width - fieldX - leftInset - (canAddColors ? (buttonSize.width + sampleItemSpacing) : 0.0), height: fieldHeight)
        transition.updateFrame(node: self.multiColorFieldNode, frame: fieldFrame)
        self.multiColorFieldNode.updateLayout(size: fieldFrame.size, condensed: false, transition: transition)
        
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
        /*self.updateState({ current in
            var updated = current
            if let secondColor = current.secondColor {
                updated.firstColor = secondColor
                updated.secondColor = current.firstColor
            }
            return updated
        })*/
    }
    
    @objc private func addPressed() {
        self.colorSelected?()
        self.colorAdded?()

        self.multiColorFieldNode.setSkipEndEditingIfNeeded()

        self.updateState({ current in
            var current = current
            if current.colors.count < current.maximumNumberOfColors {
                if current.colors.isEmpty {
                    current.colors.append(HSBColor(rgb: 0xffffff))
                } else if current.simpleGradientGeneration {
                    var hsb = current.colors[0].values
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
                    current.colors.append(HSBColor(values: hsb))
                } else if let suggestedNewColor = current.suggestedNewColor {
                    current.colors.append(suggestedNewColor)
                } else {
                    current.colors.append(current.colors[current.colors.count - 1])
                }
                current.selection = current.colors.count - 1
            }
            return current
        })
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = super.hitTest(point, with: event) {
            return result
        }
        return nil
    }
}
