import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData

private var currentTextInputBackgroundImage: (UIColor, UIColor, UIColor, CGFloat, UIImage)?
private func textInputBackgroundImage(backgroundColor: UIColor, fieldColor: UIColor, strokeColor: UIColor, diameter: CGFloat) -> UIImage? {
    if let current = currentTextInputBackgroundImage {
        if current.0.isEqual(backgroundColor) && current.1.isEqual(fieldColor) && current.2.isEqual(strokeColor) && current.3.isEqual(to: diameter) {
            return current.4
        }
    }
    
    let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
        context.setFillColor(fieldColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
        context.setStrokeColor(strokeColor.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: diameter - strokeWidth, height: diameter - strokeWidth))
    })?.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
    if let image = image {
        currentTextInputBackgroundImage = (backgroundColor, fieldColor, strokeColor, diameter, image)
        return image
    } else {
        return nil
    }
}

final class WallpaperColorPanelNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let textBackgroundNode: ASImageNode
    private let textFieldNode: TextFieldNode
    private let prefixNode: ASTextNode
    private let palleteButton: HighlightableButtonNode
    private let doneButton: HighlightableButtonNode
    private let colorPickerNode: WallpaperColorPickerNode
    
    var previousColor: UIColor?
    var color: UIColor {
        get {
            return self.colorPickerNode.color
        }
        set {
            self.setColor(newValue)
        }
    }

    var colorChanged: ((UIColor, Bool) -> Void)?

    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        self.bottomSeparatorNode =  ASDisplayNode()
        self.bottomSeparatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        
        self.textBackgroundNode = ASImageNode()
        self.textBackgroundNode.image = textInputBackgroundImage(backgroundColor: theme.chat.inputPanel.panelBackgroundColor, fieldColor: theme.chat.inputPanel.inputBackgroundColor,  strokeColor: theme.chat.inputPanel.inputStrokeColor, diameter: 33.0)
        
        self.textFieldNode = TextFieldNode()
        self.prefixNode = ASTextNode()
        self.prefixNode.attributedText = NSAttributedString(string: "#", font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.inputTextColor)
        
        self.palleteButton = HighlightableButtonNode()
        self.palleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/WallpaperColorIcon"), color: theme.chat.inputPanel.panelControlColor), for: .normal)
       
        self.doneButton = HighlightableButtonNode()
        self.doneButton.setImage(PresentationResourcesChat.chatInputPanelApplyButtonImage(theme), for: .normal)
        
        self.colorPickerNode = WallpaperColorPickerNode(strings: strings)
    
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.textBackgroundNode)
        self.addSubnode(self.textFieldNode)
        self.addSubnode(self.prefixNode)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.colorPickerNode)
        
        self.colorPickerNode.colorChanged = { [weak self] color in
            self?.setColor(color, updatePicker: false, ended: false)
        }
        self.colorPickerNode.colorChangeEnded = { [weak self] color in
            self?.setColor(color, updatePicker: false, ended: true)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textFieldNode.textField.font = Font.regular(17.0)
        self.textFieldNode.textField.textColor = self.theme.chat.inputPanel.inputTextColor
        self.textFieldNode.textField.keyboardAppearance = self.theme.chat.inputPanel.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.autocorrectionType = .no
        self.textFieldNode.textField.autocapitalizationType = .allCharacters
        self.textFieldNode.textField.keyboardType = .asciiCapable
        self.textFieldNode.textField.returnKeyType = .done
        self.textFieldNode.textField.delegate = self
        self.textFieldNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textFieldNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    private func setColor(_ color: UIColor, updatePicker: Bool = true, ended: Bool = true) {
        self.textFieldNode.textField.text = color.hexString.uppercased()
        if updatePicker {
            self.colorPickerNode.color = color
        }
        self.colorChanged?(color, ended)
    }
    
    func updateLayout(size: CGSize, keyboardHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let separatorHeight = UIScreenPixel
        let topPanelHeight: CGFloat = 47.0
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: topPanelHeight))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: separatorHeight))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(x: 0.0, y: topPanelHeight, width: size.width, height: separatorHeight))
        
        let fieldHeight: CGFloat = 33.0
        let buttonSpacing: CGFloat = keyboardHeight > 0.0 ? 3.0 : 6.0
        let leftInset: CGFloat = 5.0
        let rightInset: CGFloat = 5.0
        
        transition.updateFrame(node: self.palleteButton, frame: CGRect(x: 0.0, y: 0.0, width: topPanelHeight, height: topPanelHeight))
        transition.updateFrame(node: self.textBackgroundNode, frame: CGRect(x: leftInset, y: (topPanelHeight - fieldHeight) / 2.0, width: size.width - leftInset - rightInset, height: fieldHeight))
        transition.updateFrame(node: self.textFieldNode, frame: CGRect(x: leftInset + 24.0, y: (topPanelHeight - fieldHeight) / 2.0 + 1.0, width: size.width - leftInset - rightInset - 36.0, height: fieldHeight - 2.0))
        
        let prefixSize = self.prefixNode.measure(CGSize(width: size.width, height: fieldHeight))
        transition.updateFrame(node: self.prefixNode, frame: CGRect(origin: CGPoint(x: leftInset + 13.0, y: 12.0 + UIScreenPixel), size: prefixSize))
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: 0.0, y: size.width - rightInset + buttonSpacing, width: topPanelHeight, height: topPanelHeight))
        
        let colorPickerSize = CGSize(width: size.width, height: size.height - topPanelHeight - separatorHeight)
        transition.updateFrame(node: self.colorPickerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + separatorHeight), size: colorPickerSize))
        self.colorPickerNode.updateLayout(size: colorPickerSize, transition: transition)
    }
    
    @objc internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.count > 1 {
            if string.count <= 6 {
                var updated = textField.text ?? ""
                updated.replaceSubrange(updated.index(updated.startIndex, offsetBy: range.lowerBound) ..< updated.index(updated.startIndex, offsetBy: range.upperBound), with: string)
                if updated.count <= 6 && updated.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil {
                    textField.text = updated.uppercased()
                }
            }
            return false
        } else if string.count == 1 {
            return (textField.text ?? "").count < 6 && string.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil
        }
        return true
    }
    
    @objc func textFieldTextChanged(_ sender: UITextField) {
        if let text = sender.text, text.count == 6, let color = UIColor(hexString: text) {
            self.setColor(color)
        }
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textFieldNode.resignFirstResponder()
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.previousColor = self.color
        return true
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = self.textFieldNode.textField.text, text.count == 6, let color = UIColor(hexString: text) {
            self.setColor(color)
        } else {
            self.setColor(self.previousColor ?? .black)
        }
    }
}
