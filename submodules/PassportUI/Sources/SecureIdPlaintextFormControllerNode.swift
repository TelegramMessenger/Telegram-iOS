import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import CoreTelephony
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import CountrySelectionUI
import PhoneNumberFormat

private func cleanPhoneNumber(_ text: String?) -> String {
    var cleanNumber = ""
    if let text = text {
        for c in text {
            if c >= "0" && c <= "9" {
                cleanNumber += String(c)
            }
        }
    }
    return cleanNumber
}

public final class SecureIdPlaintextFormParams {
    fileprivate let openCountrySelection: () -> Void
    fileprivate let updateTextField: (SecureIdPlaintextFormTextField, String) -> Void
    fileprivate let usePhone: (String) -> Void
    fileprivate let useEmailAddress: (String) -> Void
    fileprivate let save: () -> Void
    
    fileprivate init(openCountrySelection: @escaping () -> Void, updateTextField: @escaping (SecureIdPlaintextFormTextField, String) -> Void, usePhone: @escaping (String) -> Void, useEmailAddress: @escaping (String) -> Void, save: @escaping () -> Void) {
        self.openCountrySelection = openCountrySelection
        self.updateTextField = updateTextField
        self.usePhone = usePhone
        self.useEmailAddress = useEmailAddress
        self.save = save
    }
}

private struct PhoneInputState {
    var countryCode: String
    var number: String
    var countryId: String
    
    func isEqual(to: PhoneInputState) -> Bool {
        if self.countryCode != to.countryCode {
            return false
        }
        if self.number != to.number {
            return false
        }
        if self.countryId != to.countryId {
            return false
        }
        return true
    }
}

private struct PhoneVerifyState {
    let phone: String
    let payload: SecureIdPreparePhoneVerificationPayload
    var code: String
    
    func isEqual(to: PhoneVerifyState) -> Bool {
        if self.code != to.code {
            return false
        }
        return true
    }
}

private enum SecureIdPlaintextFormPhoneState {
    case input(PhoneInputState)
    case verify(PhoneVerifyState)
    
    func isEqual(to: SecureIdPlaintextFormPhoneState) -> Bool {
        switch self {
            case let .input(lhsInput):
                if case let .input(rhsInput) = to, lhsInput.isEqual(to: rhsInput) {
                    return true
                } else {
                    return false
                }
            case let .verify(lhsInput):
                if case let .verify(rhsInput) = to, lhsInput.isEqual(to: rhsInput) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func isComplete() -> Bool {
        switch self {
            case let .input(input):
                if input.countryCode.isEmpty {
                    return false
                }
                if input.number.isEmpty {
                    return false
                }
                return true
            case let .verify(verify):
                if verify.code.isEmpty {
                    return false
                }
                return true
        }
    }
}

private struct EmailInputState {
    var email: String
    
    func isEqual(to: EmailInputState) -> Bool {
        if self.email != to.email {
            return false
        }
        return true
    }
}

private struct EmailVerifyState {
    let email: String
    let payload: SecureIdPrepareEmailVerificationPayload
    var code: String
    
    func isEqual(to: EmailVerifyState) -> Bool {
        if self.code != to.code {
            return false
        }
        return true
    }
}

private enum SecureIdPlaintextFormEmailState {
    case input(EmailInputState)
    case verify(EmailVerifyState)
    
    func isEqual(to: SecureIdPlaintextFormEmailState) -> Bool {
        switch self {
            case let .input(lhsInput):
                if case let .input(rhsInput) = to, lhsInput.isEqual(to: rhsInput) {
                    return true
                } else {
                    return false
                }
            case let .verify(lhsInput):
                if case let .verify(rhsInput) = to, lhsInput.isEqual(to: rhsInput) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func isComplete() -> Bool {
        switch self {
            case let .input(input):
                if input.email.isEmpty {
                    return false
                }
                return true
            case let .verify(verify):
                if verify.code.isEmpty {
                    return false
                }
                return true
        }
    }
}

private enum SecureIdPlaintextFormTextField {
    case countryCode
    case number
    case code
    case email
}

private enum SecureIdPlaintextFormDataState {
    case phone(SecureIdPlaintextFormPhoneState)
    case email(SecureIdPlaintextFormEmailState)
    
    mutating func updateTextField(type: SecureIdPlaintextFormTextField, value: String) {
        switch self {
            case let .phone(phone):
                switch phone {
                    case var .input(input):
                        switch type {
                            case .countryCode:
                                input.countryCode = value
                            case .number:
                                input.number = value
                            default:
                                break
                        }
                        self = .phone(.input(input))
                    case var .verify(verify):
                        switch type {
                            case .code:
                                verify.code = value
                            default:
                                break
                        }
                        self = .phone(.verify(verify))
                }
            case let .email(email):
                switch email {
                    case var .input(input):
                        switch type {
                            case .email:
                                input.email = value
                            default:
                                break
                        }
                        self = .email(.input(input))
                    case var .verify(verify):
                        switch type {
                            case .code:
                                verify.code = value
                            default:
                                break
                        }
                        self = .email(.verify(verify))
                }
        }
    }
    
    func isEqual(to: SecureIdPlaintextFormDataState) -> Bool {
        switch self {
            case let .phone(lhsValue):
                if case let .phone(rhsValue) = to, lhsValue.isEqual(to: rhsValue) {
                    return true
                } else {
                    return false
                }
            case let .email(lhsValue):
                if case let .email(rhsValue) = to, lhsValue.isEqual(to: rhsValue) {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum SecureIdPlaintextFormActionState {
    case none
    case saving
    case deleting
}

enum SecureIdPlaintextFormInputState {
    case nextAvailable
    case nextNotAvailable
    case saveAvailable
    case saveNotAvailable
    case inProgress
}

public struct SecureIdPlaintextFormInnerState: FormControllerInnerState {
    fileprivate let previousValue: SecureIdValue?
    fileprivate var data: SecureIdPlaintextFormDataState
    fileprivate var actionState: SecureIdPlaintextFormActionState
    
    public func isEqual(to: SecureIdPlaintextFormInnerState) -> Bool {
        if !self.data.isEqual(to: to.data) {
            return false
        }
        if self.actionState != to.actionState {
            return false
        }
        return true
    }
    
    public func entries() -> [FormControllerItemEntry<SecureIdPlaintextFormEntry>] {
        switch self.data {
        case let .phone(phone):
            var result: [FormControllerItemEntry<SecureIdPlaintextFormEntry>] = []
            switch phone {
                case let .input(input):
                    result.append(.spacer)
                    
                    if let value = self.previousValue, case let .phone(phone) = value {
                        result.append(.entry(SecureIdPlaintextFormEntry.immediatelyAvailablePhone(phone.phone)))
                        result.append(.entry(SecureIdPlaintextFormEntry.immediatelyAvailablePhoneInfo))
                        result.append(.spacer)
                        result.append(.entry(SecureIdPlaintextFormEntry.numberInputHeader))
                    }
                
                    result.append(.entry(SecureIdPlaintextFormEntry.numberInput(countryCode: input.countryCode, number: input.number)))
                    result.append(.entry(SecureIdPlaintextFormEntry.numberInputInfo))
                case let .verify(verify):
                    result.append(.spacer)
                    var codeLength: Int32 = 5
                    switch verify.payload.type {
                        case let .sms(length):
                            codeLength = length
                        case let .call(length):
                            codeLength = length
                        case let .otherSession(length):
                            codeLength = length
                        default:
                            break
                    }
                    result.append(.entry(SecureIdPlaintextFormEntry.numberCode(verify.code, codeLength)))
                    result.append(.entry(SecureIdPlaintextFormEntry.numberVerifyInfo))
            }
            return result
        case let .email(email):
            var result: [FormControllerItemEntry<SecureIdPlaintextFormEntry>] = []
            switch email {
                case let .input(input):
                    result.append(.spacer)
                    
                    if let value = self.previousValue, case let .email(email) = value {
                        result.append(.entry(SecureIdPlaintextFormEntry.immediatelyAvailableEmail(email.email)))
                        result.append(.entry(SecureIdPlaintextFormEntry.immediatelyAvailableEmailInfo))
                        result.append(.spacer)
                    result.append(.entry(SecureIdPlaintextFormEntry.emailInputHeader))
                    }
                    
                    result.append(.entry(SecureIdPlaintextFormEntry.emailAddress(input.email)))
                    result.append(.entry(SecureIdPlaintextFormEntry.emailInputInfo))
                case let .verify(verify):
                    result.append(.spacer)
                    result.append(.entry(SecureIdPlaintextFormEntry.numberCode(verify.code, verify.payload.length)))
                    result.append(.entry(SecureIdPlaintextFormEntry.emailVerifyInfo(verify.email)))
            }
            return result
        }
    }
    
    func actionInputState() -> SecureIdPlaintextFormInputState {
        switch self.actionState {
            case .deleting, .saving:
                return .inProgress
            default:
                break
        }
        
        switch self.data {
            case let .phone(phone):
                switch phone {
                    case .input:
                        if !phone.isComplete() {
                            return .nextNotAvailable
                        } else {
                            return .nextAvailable
                        }
                    case .verify:
                        if !phone.isComplete() {
                            return .saveNotAvailable
                        } else {
                            return .saveAvailable
                        }
                }
            case let .email(email):
                switch email {
                    case .input:
                        if !email.isComplete() {
                            return .nextNotAvailable
                        } else {
                            return .nextAvailable
                        }
                    case .verify:
                        if !email.isComplete() {
                            return .saveNotAvailable
                        } else {
                            return .saveAvailable
                        }
            }
        }
    }
}

extension SecureIdPlaintextFormInnerState {
    init(type: SecureIdPlaintextFormType, immediatelyAvailableValue: SecureIdValue?) {
        switch type {
            case .phone:
                var countryId: String? = nil
                let networkInfo = CTTelephonyNetworkInfo()
                if let carrier = networkInfo.subscriberCellularProvider {
                    countryId = carrier.isoCountryCode
                }
                
                if countryId == nil {
                    countryId = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
                }
                
                var countryCodeAndId: (Int32, String) = (1, "US")
                
                if let countryId = countryId {
                    let normalizedId = countryId.uppercased()
                    for (code, idAndName) in countryCodeToIdAndName {
                        if idAndName.0 == normalizedId {
                            countryCodeAndId = (Int32(code), idAndName.0.uppercased())
                            break
                        }
                    }
                }
                
                self.init(previousValue: immediatelyAvailableValue, data: .phone(.input(PhoneInputState(countryCode: "+\(countryCodeAndId.0)", number: "", countryId: countryCodeAndId.1))), actionState: .none)
            case .email:
                self.init(previousValue: immediatelyAvailableValue, data: .email(.input(EmailInputState(email: ""))), actionState: .none)
        }
    }
}

public enum SecureIdPlaintextFormEntryId: Hashable {
    case immediatelyAvailablePhone
    case immediatelyAvailablePhoneInfo
    case numberInputHeader
    case numberInput
    case numberInputInfo
    case numberCode
    case numberVerifyInfo
    case immediatelyAvailableEmail
    case immediatelyAvailableEmailInfo
    case emailInputHeader
    case emailAddress
    case emailInputInfo
    case emailCode
    case emailVerifyInfo
}

public enum SecureIdPlaintextFormEntry: FormControllerEntry {
    case immediatelyAvailablePhone(String)
    case immediatelyAvailablePhoneInfo
    case numberInputHeader
    case numberInput(countryCode: String, number: String)
    case numberInputInfo
    case numberCode(String, Int32)
    case numberVerifyInfo
    case immediatelyAvailableEmail(String)
    case immediatelyAvailableEmailInfo
    case emailInputHeader
    case emailAddress(String)
    case emailInputInfo
    case emailCode(String)
    case emailVerifyInfo(String)
    
    public var stableId: SecureIdPlaintextFormEntryId {
        switch self {
            case .immediatelyAvailablePhone:
                return .immediatelyAvailablePhone
            case .immediatelyAvailablePhoneInfo:
                return .immediatelyAvailablePhoneInfo
            case .numberInputHeader:
                return .numberInputHeader
            case .numberInput:
                return .numberInput
            case .numberInputInfo:
                return .numberInputInfo
            case .numberCode:
                return .numberCode
            case .numberVerifyInfo:
                return .numberVerifyInfo
            case .immediatelyAvailableEmail:
                return .immediatelyAvailableEmail
            case .immediatelyAvailableEmailInfo:
                return .immediatelyAvailableEmailInfo
            case .emailInputHeader:
                return .emailInputHeader
            case .emailAddress:
                return .emailAddress
            case .emailInputInfo:
                return .emailInputInfo
            case .emailCode:
                return .emailCode
            case .emailVerifyInfo:
                return .emailVerifyInfo
        }
    }
    
    public func isEqual(to: SecureIdPlaintextFormEntry) -> Bool {
        switch self {
            case let .immediatelyAvailablePhone(value):
                if case .immediatelyAvailablePhone(value) = to {
                    return true
                } else {
                    return false
                }
            case .immediatelyAvailablePhoneInfo:
                if case .immediatelyAvailablePhoneInfo = to {
                    return true
                } else {
                    return false
                }
            case .numberInputHeader:
                if case .numberInputHeader = to {
                    return true
                } else {
                    return false
                }
            case let .numberInput(countryCode, number):
                if case .numberInput(countryCode, number) = to {
                    return true
                } else {
                    return false
                }
            case .numberInputInfo:
                if case .numberInputInfo = to {
                    return true
                } else {
                    return false
                }
            case let .numberCode(code, length):
                if case .numberCode(code, length) = to {
                    return true
                } else {
                    return false
                }
            case .numberVerifyInfo:
                if case .numberVerifyInfo = to {
                    return true
                } else {
                    return false
                }
            case let .immediatelyAvailableEmail(value):
                if case .immediatelyAvailableEmail(value) = to {
                    return true
                } else {
                    return false
                }
            case .immediatelyAvailableEmailInfo:
                if case .immediatelyAvailableEmailInfo = to {
                    return true
                } else {
                    return false
                }
            case .emailInputHeader:
                if case .emailInputHeader = to {
                    return true
                } else {
                    return false
                }
            case let .emailAddress(code):
                if case .emailAddress(code) = to {
                    return true
                } else {
                    return false
                }
            case .emailInputInfo:
                if case .emailInputInfo = to {
                    return true
                } else {
                    return false
                }
            case let .emailCode(code):
                if case .emailCode(code) = to {
                    return true
                } else {
                    return false
                }
            case let .emailVerifyInfo(address):
                if case .emailVerifyInfo(address) = to {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public func item(params: SecureIdPlaintextFormParams, strings: PresentationStrings) -> FormControllerItem {
        switch self {
            case let .immediatelyAvailablePhone(value):
                return FormControllerActionItem(type: .accent, title: strings.Passport_Phone_UseTelegramNumber(formatPhoneNumber(value)).string, activated: {
                    params.usePhone(value)
                })
            case .immediatelyAvailablePhoneInfo:
                return FormControllerTextItem(text: strings.Passport_Phone_UseTelegramNumberHelp)
            case .numberInputHeader:
                return FormControllerHeaderItem(text: strings.Passport_Phone_EnterOtherNumber)
            case let .numberInput(countryCode, number):
                var countryName = ""
                if let codeNumber = Int(countryCode), let codeId = AuthorizationSequenceCountrySelectionController.lookupCountryIdByCode(codeNumber) {
                    countryName = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(codeId, strings: strings) ?? ""
                }
                return SecureIdValueFormPhoneItem(countryCode: countryCode, number: number, countryName: countryName, openCountrySelection: {
                    params.openCountrySelection()
                }, updateCountryCode: { value in
                    params.updateTextField(.countryCode, value)
                }, updateNumber: { value in
                    params.updateTextField(.number, value)
                })
            case .numberInputInfo:
                return FormControllerTextItem(text: strings.Passport_Phone_Help)
            case let .numberCode(code, length):
                return FormControllerTextInputItem(title: strings.ChangePhoneNumberCode_CodePlaceholder, text: code, placeholder: strings.ChangePhoneNumberCode_CodePlaceholder, type: .number, textUpdated: { value in
                    params.updateTextField(.code, value)
                    if value.count == length {
                        params.save()
                    }
                }, returnPressed: {
                    
                })
            case .numberVerifyInfo:
                return FormControllerTextItem(text: strings.ChangePhoneNumberCode_Help)
            case let .immediatelyAvailableEmail(value):
                return FormControllerActionItem(type: .accent, title: strings.Passport_Email_UseTelegramEmail(value).string, activated: {
                    params.useEmailAddress(value)
                })
            case .immediatelyAvailableEmailInfo:
                return FormControllerTextItem(text: strings.Passport_Email_UseTelegramEmailHelp)
            case .emailInputHeader:
                return FormControllerHeaderItem(text: strings.Passport_Email_EnterOtherEmail)
            case let .emailAddress(address):
                return FormControllerTextInputItem(title: strings.TwoStepAuth_Email, text: address, placeholder: strings.Passport_Email_EmailPlaceholder, type: .email, textUpdated: { value in
                    params.updateTextField(.email, value)
                }, returnPressed: {
                    params.save()
                })
            case .emailInputInfo:
                return FormControllerTextItem(text: strings.Passport_Email_Help)
            case let .emailCode(code):
                return FormControllerTextInputItem(title: strings.TwoStepAuth_RecoveryCode, text: code, placeholder: strings.TwoStepAuth_RecoveryCode, type: .number, textUpdated: { value in
                    params.updateTextField(.code, value)
                }, returnPressed: {
                    
                })
            case let .emailVerifyInfo(address):
                return FormControllerTextItem(text: strings.Passport_Email_CodeHelp(address).string)
        }
    }
}

public struct SecureIdPlaintextFormControllerNodeInitParams {
    let context: AccountContext
    let secureIdContext: SecureIdAccessContext
}

private enum SecureIdPlaintextFormNavigatonTransition {
    case none
    case push
}

public final class SecureIdPlaintextFormControllerNode: FormControllerNode<SecureIdPlaintextFormControllerNodeInitParams, SecureIdPlaintextFormInnerState> {
    private var _itemParams: SecureIdPlaintextFormParams?
    override public var itemParams: SecureIdPlaintextFormParams {
        return self._itemParams!
    }
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let context: AccountContext
    private let secureIdContext: SecureIdAccessContext
    
    var actionInputStateUpdated: ((SecureIdPlaintextFormInputState) -> Void)?
    var completedWithValue: ((SecureIdValueWithContext?) -> Void)?
    var dismiss: (() -> Void)?
    
    private let actionDisposable = MetaDisposable()
    
    required public init(initParams: SecureIdPlaintextFormControllerNodeInitParams, presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.context = initParams.context
        self.secureIdContext = initParams.secureIdContext
        
        super.init(initParams: initParams, presentationData: presentationData)
        
        self._itemParams = SecureIdPlaintextFormParams(openCountrySelection: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.strings, theme: strongSelf.theme, displayCodes: true)
            controller.completeWithCountryCode = { code, _ in
                if let strongSelf = self, var innerState = strongSelf.innerState {
                    innerState.data.updateTextField(type: .countryCode, value: "+\(code)")
                    strongSelf.updateInnerState(transition: .immediate, with: innerState)
                }
            }
            strongSelf.view.endEditing(true)
            strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, updateTextField: { [weak self] type, value in
            guard let strongSelf = self else {
                return
            }
            guard var innerState = strongSelf.innerState else {
                return
            }
            innerState.data.updateTextField(type: type, value: value)
            strongSelf.updateInnerState(transition: .immediate, with: innerState)
        }, usePhone: { [weak self] value in
            self?.savePhone(value)
        }, useEmailAddress: { [weak self] value in
            self?.saveEmailAddress(value)
        }, save: { [weak self] in
            self?.save()
        })
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    override func updateInnerState(transition: ContainedViewLayoutTransition, with innerState: SecureIdPlaintextFormInnerState) {
        let previousActionInputState = self.innerState?.actionInputState()
        super.updateInnerState(transition: transition, with: innerState)
        
        let actionInputState = innerState.actionInputState()
        if previousActionInputState != actionInputState {
            self.actionInputStateUpdated?(actionInputState)
        }
    }
    
    private func updateInnerState(transition: ContainedViewLayoutTransition, navigationTransition: SecureIdPlaintextFormNavigatonTransition, with innerState: SecureIdPlaintextFormInnerState) {
        if case .push = navigationTransition {
            if let snapshotView = self.scrollNode.view.snapshotContentTree() {
                snapshotView.frame = self.scrollNode.view.frame.offsetBy(dx: 0.0, dy: self.scrollNode.view.contentInset.top)
                self.scrollNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.scrollNode.view)
                snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -self.scrollNode.view.bounds.width, y: 0.0), duration: 0.25, removeOnCompletion: false, additive: true, completion : { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.scrollNode.view.layer.animatePosition(from: CGPoint(x: self.scrollNode.view.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, additive: true)
            }
        }
        self.updateInnerState(transition: transition, with: innerState)
    }
    
    func activateMainInput() {
        self.enumerateItemsAndEntries({ itemEntry, itemNode in
            switch itemEntry {
            case .emailAddress, .numberCode, .emailCode:
                if let inputNode = itemNode as? FormControllerTextInputItemNode {
                    inputNode.activate()
                }
                return false
            case .numberInput:
                if let inputNode = itemNode as? SecureIdValueFormPhoneItemNode {
                    inputNode.activate()
                }
                return false
            default:
                return true
            }
        })
    }
    
    override func didAppear() {
        self.activateMainInput()
    }
    
    func save() {
        guard var innerState = self.innerState else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        
        switch innerState.data {
            case let .phone(phone):
                switch phone {
                    case let .input(input):
                        self.savePhone(input.countryCode + input.number)
                        return
                    case .verify:
                        self.verifyPhoneCode()
                        return
                }
            case let .email(email):
                switch email {
                    case let .input(input):
                        self.saveEmailAddress(input.email)
                        return
                    case let .verify(verify):
                        guard case .saveAvailable = innerState.actionInputState() else {
                            return
                        }
                        innerState.actionState = .saving
                        self.updateInnerState(transition: .immediate, with: innerState)
                        
                        self.actionDisposable.set((secureIdCommitEmailVerification(postbox: self.context.account.postbox, network: self.context.account.network, context: self.secureIdContext, payload: verify.payload, code: verify.code)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            if let strongSelf = self {
                                guard let innerState = strongSelf.innerState else {
                                    return
                                }
                                guard case .saving = innerState.actionState else {
                                    return
                                }
                                strongSelf.completedWithValue?(result)
                            }
                        }, error: { [weak self] error in
                            if let strongSelf = self {
                                guard var innerState = strongSelf.innerState else {
                                    return
                                }
                                guard case .saving = innerState.actionState else {
                                    return
                                }
                                innerState.actionState = .none
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                                let errorText: String
                                switch error {
                                    case .generic:
                                        errorText = strongSelf.strings.Login_UnknownError
                                    case .flood:
                                        errorText = strongSelf.strings.Login_CodeFloodError
                                    case .invalid:
                                        errorText = strongSelf.strings.Login_InvalidCodeError
                                }
                                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), nil)
                            }
                        }))
                        
                        return
                }
        }
    }
    
    private func savePhone(_ value: String) {
        guard var innerState = self.innerState else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        innerState.actionState = .saving
        let inputPhone = cleanPhoneNumber(value)
        self.updateInnerState(transition: .immediate, with: innerState)
        
        self.actionDisposable.set((secureIdPreparePhoneVerification(network: self.context.account.network, value: SecureIdPhoneValue(phone: inputPhone))
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                innerState.data = .phone(.verify(PhoneVerifyState(phone: inputPhone, payload: result, code: "")))
                strongSelf.updateInnerState(transition: .immediate, navigationTransition: .push, with: innerState)
                strongSelf.activateMainInput()
            }
        }, error: { [weak self] error in
            if let strongSelf = self {
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                let errorText: String
                switch error {
                    case .generic:
                        errorText = strongSelf.strings.Login_UnknownError
                    case .flood:
                        errorText = strongSelf.strings.Login_CodeFloodError
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), nil)
            }
        }))
    }
    
    private func saveEmailAddress(_ value: String) {
        guard var innerState = self.innerState else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        innerState.actionState = .saving
        self.updateInnerState(transition: .immediate, with: innerState)
        
        self.actionDisposable.set((saveSecureIdValue(postbox: self.context.account.postbox, network: self.context.account.network, context: self.secureIdContext, value: .email(SecureIdEmailValue(email: value)), uploadedFiles: [:])
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completedWithValue?(result)
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
        strongSelf.actionDisposable.set((secureIdPrepareEmailVerification(network: strongSelf.context.account.network, value: SecureIdEmailValue(email: value))
            |> deliverOnMainQueue).start(next: { result in
                guard let strongSelf = self else {
                    return
                }
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                innerState.data = .email(.verify(EmailVerifyState(email: value, payload: result, code: "")))
                strongSelf.updateInnerState(transition: .immediate, navigationTransition: .push, with: innerState)
                strongSelf.activateMainInput()
            }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                let errorText: String
                switch error {
                    case .generic:
                        errorText = strongSelf.strings.Login_UnknownError
                    case .invalidEmail:
                        errorText = strongSelf.strings.TwoStepAuth_EmailInvalid
                    case .flood:
                        errorText = strongSelf.strings.Login_CodeFloodError
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), nil)
            }))
        }))
    }
    
    private func verifyPhoneCode() {
        guard var innerState = self.innerState else {
            return
        }
        guard case let .phone(phone) = innerState.data, case let .verify(verify) = phone else {
            return
        }
        guard case .saveAvailable = innerState.actionInputState() else {
            return
        }
        innerState.actionState = .saving
        self.updateInnerState(transition: .immediate, with: innerState)
        
        self.actionDisposable.set((secureIdCommitPhoneVerification(postbox: self.context.account.postbox, network: self.context.account.network, context: self.secureIdContext, payload: verify.payload, code: verify.code)
    |> deliverOnMainQueue).start(next: { [weak self] result in
        if let strongSelf = self {
            guard let innerState = strongSelf.innerState else {
                return
            }
            guard case .saving = innerState.actionState else {
                return
            }
            
            strongSelf.completedWithValue?(result)
        }
        }, error: { [weak self] error in
            if let strongSelf = self {
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                let errorText: String
                switch error {
                case .generic:
                    errorText = strongSelf.strings.Login_UnknownError
                case .flood:
                    errorText = strongSelf.strings.Login_CodeFloodError
                case .invalid:
                    errorText = strongSelf.strings.Login_InvalidCodeError
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), nil)
            }
        }))
    }
    
    func applyPhoneCode(_ code: Int) {
        guard var innerState = self.innerState else {
            return
        }
        switch innerState.data {
            case let .phone(phone):
                switch phone {
                    case var .verify(verify):
                        let value = "\(code)"
                        verify.code = value
                        innerState.data = .phone(.verify(verify))
                        self.updateInnerState(transition: .immediate, with: innerState)
                        self.verifyPhoneCode()
                    default:
                        break
                }
            default:
                break
        }
    }
}

