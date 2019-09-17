import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

final class ShareSearchBarNode: ASDisplayNode, UITextFieldDelegate {
    private let backgroundNode: ASImageNode
    private let searchIconNode: ASImageNode
    private let textInputNode: TextFieldNode
    private let clearButton: HighlightableButtonNode
    
    private let inputInsets = UIEdgeInsets(top: 10.0, left: 26.0, bottom: 10.0, right: 10.0 + 16.0)
    
    var textUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, placeholder: String) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.actionSheet.inputBackgroundColor)
        
        self.searchIconNode = ASImageNode()
        self.searchIconNode.isLayerBacked = true
        self.searchIconNode.displaysAsynchronously = false
        self.searchIconNode.displayWithoutProcessing = true
        self.searchIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Share/SearchBarSearchIcon"), color: theme.actionSheet.inputPlaceholderColor)
        
        self.clearButton = HighlightableButtonNode()
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.setImage(generateClearIcon(color: theme.actionSheet.inputClearButtonColor), for: [])
        self.clearButton.isHidden = true
        
        self.textInputNode = TextFieldNode()
        self.textInputNode.fixOffset = false
        let textColor: UIColor = theme.actionSheet.inputTextColor
        let keyboardAppearance: UIKeyboardAppearance = UIKeyboardAppearance.default
        self.textInputNode.textField.font = Font.regular(16.0)
        self.textInputNode.textField.textColor = textColor
        self.textInputNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(16.0), NSAttributedString.Key.foregroundColor: textColor]
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textField.keyboardAppearance = keyboardAppearance
        self.textInputNode.textField.attributedPlaceholder = NSAttributedString(string: placeholder, font: Font.regular(16.0), textColor: theme.actionSheet.inputPlaceholderColor)
        self.textInputNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.textField.tintColor = theme.actionSheet.controlAccentColor
        self.textInputNode.textField.returnKeyType = .search
        self.textInputNode.textField.accessibilityTraits = .searchField
        
        super.init()
        
        self.textInputNode.textField.delegate = self
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.searchIconNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.clearButton)
        
        self.textInputNode.textField.addTarget(self, action: #selector(self.textFieldDidChangeText), for: [.editingChanged])
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) {
        let inputInsets = self.inputInsets
        
        let textFieldHeight: CGFloat = 40.0
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: textFieldHeight))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        if let image = self.searchIconNode.image {
            transition.updateFrame(node: self.searchIconNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + 8.0, y: backgroundFrame.minY + 13.0), size: image.size))
        }
        
        if let image = self.clearButton.image(for: []) {
            transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX - 8.0 - image.size.width, y: backgroundFrame.minY + floor((backgroundFrame.size.height - image.size.height) / 2.0)), size: image.size))
        }
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY + UIScreenPixel), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right, height: backgroundFrame.size.height)))
    }
    
    func activateInput() {
        self.textInputNode.textField.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.textField.resignFirstResponder()
    }
    
    @objc func textFieldDidChangeText() {
        self.clearButton.isHidden = self.textInputNode.textField.text?.isEmpty ?? true
        self.textUpdated?(self.textInputNode.textField.text ?? "")
    }
    
    @objc func clearPressed() {
        self.textInputNode.textField.text = ""
        self.textFieldDidChangeText()
    }
}
