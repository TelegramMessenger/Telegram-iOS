import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import AuthorizationUI

final class AuthorizationSequenceCodeEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let titleNode: ImmediateTextNode
    private let titleIconNode: ASImageNode
    private let currentOptionNode: ASTextNode
    private let nextOptionNode: HighlightableButtonNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var codeType: SentAuthorizationCodeType?
    
    private let countdownDisposable = MetaDisposable()
    private var currentTimeoutTime: Int32?
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var phoneNumber: String = "" {
        didSet {
            if self.phoneNumber != oldValue {
                if let (layout, navigationHeight) = self.layoutArguments {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
            }
        }
    }
    
    var currentCode: String {
        return self.codeField.textField.text ?? ""
    }
    
    var loginWithCode: ((String) -> Void)?
    var requestNextOption: (() -> Void)?
    var requestAnotherOption: (() -> Void)?
    var updateNextEnabled: ((Bool) -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.codeField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.titleIconNode = ASImageNode()
        self.titleIconNode.isLayerBacked = true
        self.titleIconNode.displayWithoutProcessing = true
        self.titleIconNode.displaysAsynchronously = false
        self.titleIconNode.image = generateImage(CGSize(width: 81.0, height: 52.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(theme.list.itemPrimaryTextColor.cgColor)
            context.setStrokeColor(theme.list.itemPrimaryTextColor.cgColor)
            context.setLineWidth(2.97)
            let _ = try? drawSvgPath(context, path: "M9.87179487,9.04664384 C9.05602951,9.04664384 8.39525641,9.70682916 8.39525641,10.5205479 L8.39525641,44.0547945 C8.39525641,44.8685133 9.05602951,45.5286986 9.87179487,45.5286986 L65.1538462,45.5286986 C65.9696115,45.5286986 66.6303846,44.8685133 66.6303846,44.0547945 L66.6303846,10.5205479 C66.6303846,9.70682916 65.9696115,9.04664384 65.1538462,9.04664384 L9.87179487,9.04664384 S ")
            
            let _ = try? drawSvgPath(context, path: "M0,44.0547945 L75.025641,44.0547945 C75.025641,45.2017789 74.2153348,46.1893143 73.0896228,46.4142565 L66.1123641,47.8084669 C65.4749109,47.9358442 64.8264231,48 64.1763458,48 L10.8492952,48 C10.1992179,48 9.55073017,47.9358442 8.91327694,47.8084669 L1.93601826,46.4142565 C0.810306176,46.1893143 0,45.2017789 0,44.0547945 Z ")
            
            let _ = try? drawSvgPath(context, path: "M2.96153846,16.4383562 L14.1495726,16.4383562 C15.7851852,16.4383562 17.1111111,17.7631027 17.1111111,19.3972603 L17.1111111,45.0410959 C17.1111111,46.6752535 15.7851852,48 14.1495726,48 L2.96153846,48 C1.32592593,48 0,46.6752535 0,45.0410959 L0,19.3972603 C0,17.7631027 1.32592593,16.4383562 2.96153846,16.4383562 Z ")

            context.setStrokeColor(theme.list.plainBackgroundColor.cgColor)
            context.setLineWidth(1.65)
            let _ = try? drawSvgPath(context, path: "M2.96153846,15.6133562 L14.1495726,15.6133562 C16.2406558,15.6133562 17.9361111,17.3073033 17.9361111,19.3972603 L17.9361111,45.0410959 C17.9361111,47.1310529 16.2406558,48.825 14.1495726,48.825 L2.96153846,48.825 C0.870455286,48.825 -0.825,47.1310529 -0.825,45.0410959 L-0.825,19.3972603 C-0.825,17.3073033 0.870455286,15.6133562 2.96153846,15.6133562 S ")
            
            context.setFillColor(theme.list.plainBackgroundColor.cgColor)
            let _ = try? drawSvgPath(context, path: "M1.64529915,20.3835616 L15.465812,20.3835616 L15.465812,44.0547945 L1.64529915,44.0547945 Z ")
            
            context.setFillColor(theme.list.itemAccentColor.cgColor)
            let _ = try? drawSvgPath(context, path: "M66.4700855,0.0285884455 C60.7084674,0.0285884455 55.9687848,4.08259697 55.9687848,9.14830256 C55.9687848,12.0875991 57.5993165,14.6795278 60.0605723,16.3382966 C60.0568181,16.4358994 60.0611217,16.5884309 59.9318097,17.067302 C59.7721478,17.6586615 59.4575977,18.4958519 58.8015608,19.4258487 L58.3294314,20.083383 L59.1449275,20.0976772 C61.9723538,20.1099725 63.6110772,18.2528913 63.8662207,17.9535438 C64.7014993,18.1388449 65.5698144,18.2680167 66.4700855,18.2680167 C72.2312622,18.2680167 76.9713861,14.2140351 76.9713861,9.14830256 C76.9713861,4.08256999 72.2312622,0.0285884455 66.4700855,0.0285884455 Z ")
            
            let _ = try? drawSvgPath(context, path: "M64.1551769,18.856071 C63.8258967,19.1859287 63.4214479,19.5187 62.9094963,19.840779 C61.8188563,20.5269227 60.5584776,20.9288319 59.1304689,20.9225505 L56.7413094,20.8806727 L57.6592902,19.6022014 L58.127415,18.9502938 C58.6361919,18.2290526 58.9525079,17.5293964 59.1353377,16.8522267 C59.1487516,16.8025521 59.1603548,16.7584153 59.1703974,16.7187893 C56.653362,14.849536 55.1437848,12.1128655 55.1437848,9.14830256 C55.1437848,3.61947515 60.2526259,-0.796411554 66.4700855,-0.796411554 C72.6872626,-0.796411554 77.7963861,3.61958236 77.7963861,9.14830256 C77.7963861,14.6770228 72.6872626,19.0930167 66.4700855,19.0930167 C65.7185957,19.0930167 64.9627196,19.0118067 64.1551769,18.856071 S ")
        })
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        
        self.nextOptionNode = HighlightableButtonNode()
        self.nextOptionNode.displaysAsynchronously = false
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: .sms(length: 5), nextType: .call, timeout: 60, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        self.nextOptionNode.setAttributedTitle(nextOptionText, for: [])
        self.nextOptionNode.isUserInteractionEnabled = nextOptionActive
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(24.0)
        self.codeField.textField.textAlignment = .center
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.codeField.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.codeField.textField.keyboardType = .numberPad
        }
        #if swift(>=4.2)
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            self.codeField.textField.textContentType = .oneTimeCode
        }
        #endif
        self.codeField.textField.returnKeyType = .done
        self.codeField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.codeField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.codeField.textField.tintColor = self.theme.list.itemAccentColor
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.addSubnode(self.codeSeparatorNode)
        self.addSubnode(self.codeField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleIconNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.nextOptionNode)
        
        self.codeField.textField.delegate = self
        self.codeField.textField.addTarget(self, action: #selector(self.codeFieldTextChanged(_:)), for: .editingChanged)
        
        self.codeField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_Code, font: Font.regular(24.0), textColor: self.theme.list.itemPlaceholderTextColor
        )
        
        self.nextOptionNode.addTarget(self, action: #selector(self.nextOptionNodePressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.countdownDisposable.dispose()
    }
    
    func updateCode(_ code: String) {
        self.codeField.textField.text = code
        self.codeFieldTextChanged(self.codeField.textField)
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
            if let codeLength = codeLength, code.count == Int(codeLength) {
                self.loginWithCode?(code)
            }
        }
    }
    
    func updateData(number: String, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?) {
        self.codeType = codeType
        self.phoneNumber = number
        
        self.currentOptionNode.attributedText = authorizationCurrentOptionText(codeType, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        if let timeout = timeout {
            self.currentTimeoutTime = timeout
            let disposable = ((Signal<Int, NoError>.single(1) |> delay(1.0, queue: Queue.mainQueue())) |> restart).start(next: { [weak self] _ in
                if let strongSelf = self {
                    if let currentTimeoutTime = strongSelf.currentTimeoutTime, currentTimeoutTime > 0 {
                        strongSelf.currentTimeoutTime = currentTimeoutTime - 1
                        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, timeout:strongSelf.currentTimeoutTime, strings: strongSelf.strings, primaryColor: strongSelf.theme.list.itemPrimaryTextColor, accentColor: strongSelf.theme.list.itemAccentColor)
                        strongSelf.nextOptionNode.setAttributedTitle(nextOptionText, for: [])
                        strongSelf.nextOptionNode.isUserInteractionEnabled = nextOptionActive
                        
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
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, timeout: self.currentTimeoutTime, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        self.nextOptionNode.setAttributedTitle(nextOptionText, for: [])
        self.nextOptionNode.isUserInteractionEnabled = nextOptionActive
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [])
        insets.top = navigationBarHeight
        
        if let inputHeight = layout.inputHeight {
            insets.bottom += max(inputHeight, layout.standardInputHeight)
        }
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            if let codeType = self.codeType, case .otherSession = codeType {
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_CheckOtherSessionMessages, font: Font.medium(32.0), textColor: self.theme.list.itemPrimaryTextColor)
            } else {
                self.titleNode.attributedText = NSAttributedString(string: self.phoneNumber, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
            }
        } else {
            if let codeType = self.codeType, case .otherSession = codeType {
                let fontSize: CGFloat
                if layout.size.width > 330.0 {
                    fontSize = 22.0
                } else {
                    fontSize = 18.0
                }
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_CheckOtherSessionMessages, font: Font.semibold(fontSize), textColor: self.theme.list.itemPrimaryTextColor)
            } else {
                self.titleNode.attributedText = NSAttributedString(string: self.phoneNumber, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
            }
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let currentOptionSize = self.currentOptionNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let nextOptionSize = self.nextOptionNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        var items: [AuthorizationLayoutItem] = []
        if let codeType = self.codeType, case .otherSession = codeType {
            self.titleIconNode.isHidden = false
            items.append(AuthorizationLayoutItem(node: self.titleIconNode, size: self.titleIconNode.image!.size, spacingBefore: AuthorizationLayoutItemSpacing(weight: 41.0, maxValue: 41.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 40.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 88.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.nextOptionNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        } else {
            self.titleIconNode.isHidden = true
            items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 40.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 88.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.nextOptionNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        }
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    func activateInput() {
        self.codeField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeField.layer.addShakeAnimation()
    }
    
    @objc func codeFieldTextChanged(_ textField: UITextField) {
        self.updateNextEnabled?(!(textField.text ?? "").isEmpty)
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
            if let codeLength = codeLength, let text = textField.text, text.count == Int(codeLength) {
                self.loginWithCode?(text)
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.inProgress {
            return false
        }
        var result = ""
        for c in string {
            if c.unicodeScalars.count == 1 {
                let scalar = c.unicodeScalars.first!
                if scalar >= "0" && scalar <= "9" {
                    result.append(c)
                }
            }
        }
        if result != string {
            textField.text = result
            self.codeFieldTextChanged(textField)
            return false
        }
        return true
    }
    
    @objc func nextOptionNodePressed() {
        self.requestAnotherOption?()
    }
}
