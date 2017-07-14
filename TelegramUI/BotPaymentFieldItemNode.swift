import Foundation
import AsyncDisplayKit
import Display

private let titleFont = Font.regular(17.0)

final class BotPaymentFieldItemNode: BotPaymentItemNode {
    private let title: String
    var text: String {
        get {
            return self.textField.textField.text ?? ""
        } set(value) {
            self.textField.textField.text = value
        }
    }
    private let placeholder: String
    private let titleNode: ASTextNode
    
    private let textField: TextFieldNode
    
    private var theme: PresentationTheme?
    
    var textUpdated: (() -> Void)?
    
    init(title: String, placeholder: String) {
        self.title = title
        self.placeholder = placeholder
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.textField = TextFieldNode()
        self.textField.textField.font = titleFont
        self.textField.textField.returnKeyType = .next

        super.init(needsBackground: true)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textField)
        
        self.textField.textField.addTarget(self, action: #selector(self.editingChanged), for: [.editingChanged])
    }
    
    override func measureInset(theme: PresentationTheme, width: CGFloat) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            self.textField.textField.textColor = theme.list.itemPrimaryTextColor
            self.textField.textField.attributedPlaceholder = NSAttributedString(string: placeholder, font: titleFont, textColor: theme.list.itemPlaceholderTextColor)
            self.textField.textField.keyboardAppearance = theme.chatList.searchBarKeyboardColor.keyboardAppearance
        }
        
        let leftInset: CGFloat = 16.0
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        if titleSize.width.isZero {
            return 0.0
        } else {
            return leftInset + titleSize.width + 17.0
        }
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            self.textField.textField.keyboardAppearance = theme.chatList.searchBarKeyboardColor.keyboardAppearance
        }
        
        let leftInset: CGFloat = 16.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleSize))
        
        var textInset = leftInset
        if !titleSize.width.isZero {
            textInset += titleSize.width + 18.0
        }
        
        textInset = max(measuredInset, textInset)
        
        transition.updateFrame(node: self.textField, frame: CGRect(origin: CGPoint(x: textInset, y: 3.0), size: CGSize(width: max(1.0, width - textInset - 8.0), height: 40.0)))
        
        return 44.0
    }
    
    func activateInput() {
        self.textField.textField.becomeFirstResponder()
    }
    
    @objc func editingChanged() {
        self.textUpdated?()
    }
}
