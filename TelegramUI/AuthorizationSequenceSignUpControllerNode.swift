import Foundation
import AsyncDisplayKit
import Display

final class AuthorizationSequenceSignUpControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let navigationBackgroundNode: ASDisplayNode
    private let stripeNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    
    private let firstNameField: TextFieldNode
    private let lastNameField: TextFieldNode
    private let firstSeparatorNode: ASDisplayNode
    private let lastSeparatorNode: ASDisplayNode
    private let addPhotoButton: HighlightableButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentName: (String, String) {
        return (self.firstNameField.textField.text ?? "", self.lastNameField.textField.text ?? "")
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var requestNextOption: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.firstNameField.alpha = self.inProgress ? 0.6 : 1.0
            self.lastNameField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    override init() {
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.isLayerBacked = true
        self.navigationBackgroundNode.backgroundColor = UIColor(rgb: 0xefefef)
        
        self.stripeNode = ASDisplayNode()
        self.stripeNode.isLayerBacked = true
        self.stripeNode.backgroundColor = UIColor(rgb: 0xbcbbc1)
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: "Your Info", font: Font.light(30.0), textColor: UIColor.black)
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isLayerBacked = true
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(string: "Enter your name and add a profile picture", font: Font.regular(16.0), textColor: UIColor(rgb: 0x878787), paragraphAlignment: .center)
        
        self.firstSeparatorNode = ASDisplayNode()
        self.firstSeparatorNode.isLayerBacked = true
        self.firstSeparatorNode.backgroundColor = UIColor(rgb: 0xbcbbc1)
        
        self.lastSeparatorNode = ASDisplayNode()
        self.lastSeparatorNode.isLayerBacked = true
        self.lastSeparatorNode.backgroundColor = UIColor(rgb: 0xbcbbc1)
        
        self.firstNameField = TextFieldNode()
        self.firstNameField.textField.font = Font.regular(20.0)
        self.firstNameField.textField.textAlignment = .natural
        self.firstNameField.textField.returnKeyType = .next
        self.firstNameField.textField.attributedPlaceholder = NSAttributedString(string: "First name", font: self.firstNameField.textField.font, textColor: UIColor(rgb: 0xbcbcc3))
        
        self.lastNameField = TextFieldNode()
        self.lastNameField.textField.font = Font.regular(20.0)
        self.lastNameField.textField.textAlignment = .natural
        self.lastNameField.textField.returnKeyType = .done
        self.lastNameField.textField.attributedPlaceholder = NSAttributedString(string: "Last name", font: self.lastNameField.textField.font, textColor: UIColor(rgb: 0xbcbcc3))
        
        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setAttributedTitle(NSAttributedString(string: "add\nphoto", font: Font.regular(16.0), textColor: UIColor(rgb: 0xbcbcc3), paragraphAlignment: .center), for: .normal)
        self.addPhotoButton.setBackgroundImage(generateCircleImage(diameter: 110.0, lineWidth: 1.0, color: UIColor(rgb: 0xbcbcc3)), for: .normal)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor.white
        
        self.firstNameField.textField.delegate = self
        self.lastNameField.textField.delegate = self
        
        self.addSubnode(self.navigationBackgroundNode)
        self.addSubnode(self.stripeNode)
        self.addSubnode(self.firstSeparatorNode)
        self.addSubnode(self.lastSeparatorNode)
        self.addSubnode(self.firstNameField)
        self.addSubnode(self.lastNameField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.addPhotoButton)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(firstName: String, lastName: String) {
        self.firstNameField.textField.attributedPlaceholder = NSAttributedString(string: firstName, font: Font.regular(20.0), textColor: UIColor(rgb: 0xbcbcc3))
        self.lastNameField.textField.attributedPlaceholder = NSAttributedString(string: lastName, font: Font.regular(20.0), textColor: UIColor(rgb: 0xbcbcc3))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.statusBar, .input])
        let availableHeight = max(1.0, layout.size.height - insets.top - insets.bottom)
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: "Your Info", font: Font.light(40.0), textColor: UIColor.black)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: "Your Info", font: Font.light(30.0), textColor: UIColor.black)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let additionalTitleSpacing: CGFloat
        if titleSize.width > layout.size.width - 160.0 {
            additionalTitleSpacing = 44.0
        } else {
            additionalTitleSpacing = 0.0
        }
        
        let minimalTitleSpacing: CGFloat = 10.0
        let maxTitleSpacing: CGFloat = 22.0
        let fieldHeight: CGFloat = 57.0
        let inputFieldsHeight: CGFloat = fieldHeight * 2.0
        let leftInset: CGFloat = 130.0
        
        let minimalNoticeSpacing: CGFloat = 11.0
        let maxNoticeSpacing: CGFloat = 35.0
        let noticeSize = self.currentOptionNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let minimalTermsOfServiceSpacing: CGFloat = 6.0
        let maxTermsOfServiceSpacing: CGFloat = 20.0
        let minTrailingSpacing: CGFloat = 10.0
        
        let inputHeight = inputFieldsHeight
        let essentialHeight = additionalTitleSpacing + titleSize.height + minimalTitleSpacing + inputHeight + minimalNoticeSpacing + noticeSize.height
        let additionalHeight = minimalTermsOfServiceSpacing + minTrailingSpacing
        
        let navigationHeight: CGFloat
        if essentialHeight + additionalHeight > availableHeight || availableHeight * 0.66 - inputHeight < additionalHeight {
            navigationHeight = min(floor(availableHeight * 0.3), availableHeight - inputFieldsHeight)
        } else {
            navigationHeight = floor(availableHeight * 0.3)
        }
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.stripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let titleOffset: CGFloat
        if navigationHeight * 0.5 < titleSize.height + minimalTitleSpacing {
            titleOffset = floor((navigationHeight - titleSize.height) / 2.0)
        } else {
            titleOffset = max(navigationHeight * 0.5, navigationHeight - maxTitleSpacing - titleSize.height)
        }
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: titleOffset), size: titleSize))
        
        let addPhotoButtonFrame = CGRect(origin: CGPoint(x: 10.0, y: navigationHeight + 10.0), size: CGSize(width: 110.0, height: 110.0))
        transition.updateFrame(node: self.addPhotoButton, frame: addPhotoButtonFrame)
        
        let firstFieldFrame = CGRect(origin: CGPoint(x: leftInset, y: navigationHeight + 3.0), size: CGSize(width: layout.size.width - leftInset, height: fieldHeight))
        transition.updateFrame(node: self.firstNameField, frame: firstFieldFrame)
        
        let lastFieldFrame = CGRect(origin: CGPoint(x: firstFieldFrame.minX, y: firstFieldFrame.maxY), size: CGSize(width: firstFieldFrame.size.width, height: fieldHeight))
        transition.updateFrame(node: self.lastNameField, frame: lastFieldFrame)
        
        transition.updateFrame(node: self.firstSeparatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: firstFieldFrame.maxY), size: CGSize(width: layout.size.width - leftInset, height: UIScreenPixel)))
        transition.updateFrame(node: self.lastSeparatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: lastFieldFrame.maxY), size: CGSize(width: layout.size.width - leftInset, height: UIScreenPixel)))
        
        let additionalAvailableHeight = max(1.0, availableHeight - lastFieldFrame.maxY)
        let additionalAvailableSpacing = max(1.0, additionalAvailableHeight - noticeSize.height)
        let noticeSpacingFactor = maxNoticeSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        let termsOfServiceSpacingFactor = maxTermsOfServiceSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        
        let noticeSpacing: CGFloat
        let termsOfServiceSpacing: CGFloat
        if additionalAvailableHeight <= maxNoticeSpacing + noticeSize.height + maxTermsOfServiceSpacing + minTrailingSpacing {
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
            noticeSpacing = floor((additionalAvailableHeight - termsOfServiceSpacing - noticeSize.height) / 2.0)
        } else {
            noticeSpacing = min(floor(noticeSpacingFactor * additionalAvailableSpacing), maxNoticeSpacing)
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
        }
        
        let currentOptionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - noticeSize.width) / 2.0), y: lastFieldFrame.maxY + noticeSpacing), size: noticeSize)
        
        transition.updateFrame(node: self.currentOptionNode, frame: currentOptionFrame)
    }
    
    func activateInput() {
        self.firstNameField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        if self.firstNameField.textField.text == nil || self.firstNameField.textField.text!.isEmpty {
            self.firstNameField.layer.addShakeAnimation()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.firstNameField.textField {
            self.lastNameField.textField.becomeFirstResponder()
        } else {
            let name = self.currentName
            self.signUpWithName?(name.0, name.1)
        }
        return false
    }
    
    @objc func addPhotoPressed() {
        
    }
}
