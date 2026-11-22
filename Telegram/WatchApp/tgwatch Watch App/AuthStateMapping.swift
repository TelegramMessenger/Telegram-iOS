import Foundation
import TDShim

func mapAuthState(_ s: AuthorizationState) -> AuthState {
    switch s {
    case .authorizationStateWaitTdlibParameters:
        return .waitTdlibParameters
    case .authorizationStateWaitPhoneNumber:
        return .waitPhoneNumber
    case .authorizationStateWaitCode(let payload):
        return .waitCode(info: codeInfo(from: payload.codeInfo))
    case .authorizationStateReady:
        return .ready
    case .authorizationStateLoggingOut:
        return .loggingOut
    case .authorizationStateClosing:
        return .loggingOut
    case .authorizationStateClosed:
        return .closed
    case .authorizationStateWaitPassword(let payload):
        return .waitPassword(info: PasswordInfo(
            hint: payload.passwordHint,
            hasRecoveryEmail: payload.hasRecoveryEmailAddress
        ))
    case .authorizationStateWaitEmailAddress, .authorizationStateWaitEmailCode:
        return .failed("Email-based login isn't supported in this build yet.")
    case .authorizationStateWaitOtherDeviceConfirmation(let payload):
        return .waitOtherDeviceConfirmation(link: payload.link)
    case .authorizationStateWaitRegistration:
        return .failed("Registration is not supported with QR login.")
    case .authorizationStateWaitPremiumPurchase:
        return .failed("Premium-purchase login isn't supported in this build yet.")
    case .unsupported:
        return .failed("Unsupported authorization state.")
    }
}

private func codeInfo(from info: AuthenticationCodeInfo) -> CodeInfo {
    CodeInfo(
        phoneNumber: info.phoneNumber,
        codeLength: codeLength(from: info.type),
        typeDescription: typeDescription(from: info.type)
    )
}

private func codeLength(from type: AuthenticationCodeType) -> Int? {
    switch type {
    case .authenticationCodeTypeSms(let p): return p.length
    case .authenticationCodeTypeTelegramMessage(let p): return p.length
    case .authenticationCodeTypeCall(let p): return p.length
    case .authenticationCodeTypeMissedCall(let p): return p.length
    default: return nil
    }
}

private func typeDescription(from type: AuthenticationCodeType) -> String {
    switch type {
    case .authenticationCodeTypeSms: return "SMS"
    case .authenticationCodeTypeTelegramMessage: return "Telegram message"
    case .authenticationCodeTypeCall: return "Phone call"
    case .authenticationCodeTypeMissedCall: return "Missed call"
    case .authenticationCodeTypeFlashCall: return "Flash call"
    case .authenticationCodeTypeFragment: return "Fragment"
    case .authenticationCodeTypeFirebaseAndroid, .authenticationCodeTypeFirebaseIos: return "App push"
    case .authenticationCodeTypeSmsWord, .authenticationCodeTypeSmsPhrase: return "SMS"
    case .unsupported: return "Code"
    }
}
