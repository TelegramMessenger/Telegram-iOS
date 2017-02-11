import Foundation
import AsyncDisplayKit
import Display

final class AuthorizationSequencePasswordEntryControllerNode: ASDisplayNode {
    private let navigationBackgroundNode: ASDisplayNode
    private let stripeNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let nextOptionNode: ASTextNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentPassword: String {
        return self.codeField.textField.text ?? ""
    }
    
    var loginWithCode: ((String) -> Void)?
    var requestNextOption: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.codeField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    override init() {
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.isLayerBacked = true
        self.navigationBackgroundNode.backgroundColor = UIColor(0xefefef)
        
        self.stripeNode = ASDisplayNode()
        self.stripeNode.isLayerBacked = true
        self.stripeNode.backgroundColor = UIColor(0xbcbbc1)
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: "Your Password", font: Font.light(30.0), textColor: UIColor.black)
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isLayerBacked = true
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(string: "Two-step verification enabled.\nYour account is protected with an\nadditional password.", font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
        
        self.nextOptionNode = ASTextNode()
        self.nextOptionNode.isLayerBacked = true
        self.nextOptionNode.displaysAsynchronously = false
        self.nextOptionNode.attributedText = NSAttributedString(string: "Forgot password?", font: Font.regular(16.0), textColor: UIColor(0x007ee5), paragraphAlignment: .center)
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = UIColor(0xbcbbc1)
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(20.0)
        self.codeField.textField.textAlignment = .natural
        self.codeField.textField.isSecureTextEntry = true
        self.codeField.textField.returnKeyType = .done
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.navigationBackgroundNode)
        self.addSubnode(self.stripeNode)
        self.addSubnode(self.codeSeparatorNode)
        self.addSubnode(self.codeField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.nextOptionNode)
    }
    
    func updateData(hint: String) {
        self.codeField.textField.attributedPlaceholder = NSAttributedString(string: hint, font: Font.regular(20.0), textColor: UIColor(0xbcbcc3))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.statusBar, .input])
        let availableHeight = max(1.0, layout.size.height - insets.top - insets.bottom)
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: "Your Password", font: Font.light(30.0), textColor: UIColor.black)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: "Your Password", font: Font.regular(20.0), textColor: UIColor.black)
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
        let inputFieldsHeight: CGFloat = 60.0
        
        let minimalNoticeSpacing: CGFloat = 11.0
        let maxNoticeSpacing: CGFloat = 35.0
        let noticeSize = self.currentOptionNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let minimalTermsOfServiceSpacing: CGFloat = 6.0
        let maxTermsOfServiceSpacing: CGFloat = 20.0
        let termsOfServiceSize = self.nextOptionNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let minTrailingSpacing: CGFloat = 10.0
        
        let inputHeight = inputFieldsHeight
        let essentialHeight = additionalTitleSpacing + titleSize.height + minimalTitleSpacing + inputHeight + minimalNoticeSpacing + noticeSize.height
        let additionalHeight = minimalTermsOfServiceSpacing + termsOfServiceSize.height + minTrailingSpacing
        
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
        
        let codeFieldFrame = CGRect(origin: CGPoint(x: 22.0, y: navigationHeight + 3.0), size: CGSize(width: layout.size.width - 44.0, height: 60.0))
        transition.updateFrame(node: self.codeField, frame: codeFieldFrame)
        transition.updateFrame(node: self.codeSeparatorNode, frame: CGRect(origin: CGPoint(x: 22.0, y: navigationHeight + 60.0), size: CGSize(width: layout.size.width - 44.0, height: UIScreenPixel)))
        
        let additionalAvailableHeight = max(1.0, availableHeight - codeFieldFrame.maxY)
        let additionalAvailableSpacing = max(1.0, additionalAvailableHeight - noticeSize.height - termsOfServiceSize.height)
        let noticeSpacingFactor = maxNoticeSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        let termsOfServiceSpacingFactor = maxTermsOfServiceSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        
        let noticeSpacing: CGFloat
        let termsOfServiceSpacing: CGFloat
        if additionalAvailableHeight <= maxNoticeSpacing + noticeSize.height + maxTermsOfServiceSpacing + termsOfServiceSize.height + minTrailingSpacing {
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
            noticeSpacing = floor((additionalAvailableHeight - termsOfServiceSpacing - noticeSize.height - termsOfServiceSize.height) / 2.0)
        } else {
            noticeSpacing = min(floor(noticeSpacingFactor * additionalAvailableSpacing), maxNoticeSpacing)
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
        }
        
        let currentOptionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - noticeSize.width) / 2.0), y: codeFieldFrame.maxY + noticeSpacing), size: noticeSize)
        let nextOptionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - termsOfServiceSize.width) / 2.0), y: currentOptionFrame.maxY + termsOfServiceSpacing), size: termsOfServiceSize)
        
        transition.updateFrame(node: self.currentOptionNode, frame: currentOptionFrame)
        transition.updateFrame(node: self.nextOptionNode, frame: nextOptionFrame)
    }
    
    func activateInput() {
        self.codeField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeField.layer.addShakeAnimation()
    }
    
    @objc func passwordFieldTextChanged(_ textField: UITextField) {
        
    }
}
