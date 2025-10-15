import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import Stripe

struct BotPaymentCardInputData {
    let number: String
    let code: String
    let year: UInt
    let month: UInt
}

final class BotPaymentCardInputItemNode: BotPaymentItemNode, STPPaymentCardTextFieldDelegate {
    private let cardField: STPPaymentCardTextField
    
    private var theme: PresentationTheme?
    
    var updated: ((BotPaymentCardInputData?) -> Void)?
    var completed: (() -> Void)?
    
    init() {
        self.cardField = STPPaymentCardTextField()
        self.cardField.borderColor = .clear
        self.cardField.borderWidth = 0.0
        
        super.init(needsBackground: true)
        
        self.cardField.delegate = self
        self.view.addSubview(self.cardField)
    }
    
    override func measureInset(theme: PresentationTheme, width: CGFloat) -> CGFloat {
        return 0.0
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            
            self.cardField.textColor = theme.list.itemPrimaryTextColor
            self.cardField.textErrorColor = theme.list.itemDestructiveColor
            self.cardField.placeholderColor = theme.list.itemPlaceholderTextColor
            self.cardField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        }
        
        self.cardField.frame = CGRect(origin: CGPoint(x: 5.0 + sideInset, y: 0.0), size: CGSize(width: width - 10.0 - sideInset * 2.0, height: 44.0))
        
        return 44.0
    }
    
    func paymentCardTextFieldDidChange(_ textField: STPPaymentCardTextField) {
        if textField.isValid, let number = textField.cardParams.number, let code = textField.cardParams.cvc {
            self.updated?(BotPaymentCardInputData(number: number, code: code, year: textField.cardParams.expYear, month: textField.cardParams.expMonth))
            
            if code.count == 3 {
                self.completed?()
            }
        } else {
            self.updated?(nil)
        }
    }
    
    func activateInput() {
        self.cardField.becomeFirstResponder()
    }
}
