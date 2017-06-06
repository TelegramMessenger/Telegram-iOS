import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit

func authorizationCurrentOptionText(_ type: SentAuthorizationCodeType) -> NSAttributedString {
    switch type {
        case .sms:
            return NSAttributedString(string: "We have sent you an SMS with a code to the number", font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
        case .otherSession:
            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: "We've sent the code to the ", font: Font.regular(16.0), textColor: UIColor.black))
            string.append(NSAttributedString(string: "Telegram", font: Font.medium(16.0), textColor: UIColor.black))
            string.append(NSAttributedString(string: " app on your other device.", font: Font.regular(16.0), textColor: UIColor.black))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            string.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0, string.length))
            return string
        case .call, .flashCall:
            return NSAttributedString(string: "Telegram dialed your number", font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
    }
}

func authorizationNextOptionText(_ type: AuthorizationCodeNextType?, timeout: Int32?) -> NSAttributedString {
    if let type = type, let timeout = timeout {
        let minutes = timeout / 60
        let seconds = timeout % 60
        switch type {
            case .sms:
                if timeout <= 0 {
                    return NSAttributedString(string: "Telegram sent you an SMS", font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
                } else {
                    return NSAttributedString(string: String(format: "Telegram will send you an SMS in %d:%.2d", minutes, seconds), font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
                }
            case .call, .flashCall:
                if timeout <= 0 {
                    return NSAttributedString(string: "Telegram dialed your number", font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
                } else {
                    return NSAttributedString(string: String(format: "Telegram will call you in %d:%.2d", minutes, seconds), font: Font.regular(16.0), textColor: UIColor.black, paragraphAlignment: .center)
                }
        }
    } else {
        return NSAttributedString(string: "Haven't received the code?", font: Font.regular(16.0), textColor: UIColor(rgb: 0x007ee5), paragraphAlignment: .center)
    }
}

final class AuthorizationSequenceCodeEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let navigationBackgroundNode: ASDisplayNode
    private let stripeNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let nextOptionNode: ASTextNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var codeType: SentAuthorizationCodeType?
    
    private let countdownDisposable = MetaDisposable()
    private var currentTimeoutTime: Int32?
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var phoneNumber: String = "" {
        didSet {
            self.titleNode.attributedText = NSAttributedString(string: self.phoneNumber, font: Font.light(30.0), textColor: UIColor.black)
        }
    }
    
    var currentCode: String {
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
        self.navigationBackgroundNode.backgroundColor = UIColor(rgb: 0xefefef)
        
        self.stripeNode = ASDisplayNode()
        self.stripeNode.isLayerBacked = true
        self.stripeNode.backgroundColor = UIColor(rgb: 0xbcbbc1)
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isLayerBacked = true
        self.currentOptionNode.displaysAsynchronously = false
        
        self.nextOptionNode = ASTextNode()
        self.nextOptionNode.isLayerBacked = true
        self.nextOptionNode.displaysAsynchronously = false
        self.nextOptionNode.attributedText = authorizationNextOptionText(AuthorizationCodeNextType.call, timeout: 60)
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = UIColor(rgb: 0xbcbbc1)
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(24.0)
        self.codeField.textField.textAlignment = .center
        self.codeField.textField.keyboardType = .numberPad
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
        
        self.codeField.textField.addTarget(self, action: #selector(self.codeFieldTextChanged(_:)), for: .editingChanged)
        
        self.codeField.textField.attributedPlaceholder = NSAttributedString(string: "Code", font: Font.regular(24.0), textColor: UIColor(rgb: 0xbcbcc3))
    }
    
    deinit {
        self.countdownDisposable.dispose()
    }
    
    func updateData(number: String, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?) {
        self.codeType = codeType
        self.phoneNumber = number
        
        self.currentOptionNode.attributedText = authorizationCurrentOptionText(codeType)
        if let timeout = timeout {
            self.currentTimeoutTime = timeout
            let disposable = ((Signal<Int, NoError>.single(1) |> delay(1.0, queue: Queue.mainQueue())) |> restart).start(next: { [weak self] _ in
                if let strongSelf = self {
                    if let currentTimeoutTime = strongSelf.currentTimeoutTime, currentTimeoutTime > 0 {
                        strongSelf.currentTimeoutTime = currentTimeoutTime - 1
                        strongSelf.nextOptionNode.attributedText = authorizationNextOptionText(nextType, timeout:strongSelf.currentTimeoutTime)
                        if let layoutArguments = strongSelf.layoutArguments {
                            strongSelf.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
                        }
                        if currentTimeoutTime == 1 {
                            strongSelf.requestNextOption?()
                        }
                    }
                }
            })
            self.countdownDisposable.set(disposable)
        } else {
            self.currentTimeoutTime = nil
            self.countdownDisposable.set(nil)
        }
        self.nextOptionNode.attributedText = authorizationNextOptionText(nextType, timeout: self.currentTimeoutTime)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.statusBar, .input])
        let availableHeight = max(1.0, layout.size.height - insets.top - insets.bottom)
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.phoneNumber, font: Font.light(30.0), textColor: UIColor.black)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.phoneNumber, font: Font.regular(20.0), textColor: UIColor.black)
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
        
        let codeFieldFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight + 3.0), size: CGSize(width: layout.size.width, height: 60.0))
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
    
    @objc func codeFieldTextChanged(_ textField: UITextField) {
        if let codeType = self.codeType {
            var codeLength: Int32?
            switch codeType {
                case let .call(length):
                    codeLength = length
                case let .otherSession(length):
                    codeLength = length
                case let .sms(length):
                    codeLength = length
                default:
                    break
            }
            if let codeLength = codeLength, let text = textField.text, text.characters.count == Int(codeLength) {
                self.loginWithCode?(text)
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return !self.inProgress
    }
}
