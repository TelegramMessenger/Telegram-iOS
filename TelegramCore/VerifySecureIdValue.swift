import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

public enum SecureIdPreparePhoneVerificationError {
    case generic
    case flood
    case occupied
}

public struct SecureIdPreparePhoneVerificationPayload {
    public let type: SentAuthorizationCodeType
    public let nextType: AuthorizationCodeNextType?
    public let timeout: Int32?
    let phone: String
    let phoneCodeHash: String
}

public func secureIdPreparePhoneVerification(network: Network, value: SecureIdPhoneValue) -> Signal<SecureIdPreparePhoneVerificationPayload, SecureIdPreparePhoneVerificationError> {
    return network.request(Api.functions.account.sendVerifyPhoneCode(flags: 0, phoneNumber: value.phone, currentNumber: nil), automaticFloodWait: false)
    |> mapError { error -> SecureIdPreparePhoneVerificationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        } else if error.errorDescription == "PHONE_NUMBER_OCCUPIED" {
            return .occupied
        }
        return .generic
    }
    |> map { sentCode -> SecureIdPreparePhoneVerificationPayload in
        switch sentCode {
            case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                return SecureIdPreparePhoneVerificationPayload(type: SentAuthorizationCodeType(apiType: type), nextType: nextType.flatMap(AuthorizationCodeNextType.init), timeout: timeout, phone: value.phone, phoneCodeHash: phoneCodeHash)
        }
    }
}

public enum SecureIdCommitPhoneVerificationError {
    case generic
    case flood
    case invalid
}

public func secureIdCommitPhoneVerification(network: Network, context: SecureIdAccessContext, payload: SecureIdPreparePhoneVerificationPayload, code: String) -> Signal<SecureIdValueWithContext, SecureIdCommitPhoneVerificationError> {
    return network.request(Api.functions.account.verifyPhone(phoneNumber: payload.phone, phoneCodeHash: payload.phoneCodeHash, phoneCode: code))
    |> mapError { error -> SecureIdCommitPhoneVerificationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        } else if error.errorDescription == "PHONE_CODE_INVALID" {
            return .invalid
        }
        
        return .generic
    }
    |> mapToSignal { _ -> Signal<SecureIdValueWithContext, SecureIdCommitPhoneVerificationError> in
        return saveSecureIdValue(network: network, context: context, valueContext: generateSecureIdValueEmptyAccessContext()!, value: .phone(SecureIdPhoneValue(phone: payload.phone)))
        |> mapError { _ -> SecureIdCommitPhoneVerificationError in
            return .generic
        }
    }
}

public enum SecureIdPrepareEmailVerificationError {
    case generic
    case flood
}

public struct SecureIdPrepareEmailVerificationPayload {
    let email: String
}

public func secureIdPrepareEmailVerification(network: Network, value: SecureIdEmailValue) -> Signal<SecureIdPrepareEmailVerificationPayload, SecureIdPrepareEmailVerificationError> {
    return network.request(Api.functions.account.sendVerifyEmailCode(email: value.email), automaticFloodWait: false)
        |> mapError { error -> SecureIdPrepareEmailVerificationError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .flood
            }
            return .generic
        }
        |> map { sentCode -> SecureIdPrepareEmailVerificationPayload in
            switch sentCode {
                case .sentEmailCode:
                    return SecureIdPrepareEmailVerificationPayload(email: value.email)
            }
    }
}

public enum SecureIdCommitEmailVerificationError {
    case generic
    case flood
    case invalid
}

public func secureIdCommitEmailVerification(network: Network, context: SecureIdAccessContext, payload: SecureIdPrepareEmailVerificationPayload, code: String) -> Signal<SecureIdValueWithContext, SecureIdCommitEmailVerificationError> {
    return network.request(Api.functions.account.verifyEmail(email: payload.email, code: code), automaticFloodWait: false)
    |> mapError { error -> SecureIdCommitEmailVerificationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> mapToSignal { _ -> Signal<SecureIdValueWithContext, SecureIdCommitEmailVerificationError> in
        return saveSecureIdValue(network: network, context: context, valueContext: generateSecureIdValueEmptyAccessContext()!, value: .email(SecureIdEmailValue(email: payload.email)))
        |> mapError { _ -> SecureIdCommitEmailVerificationError in
            return .generic
        }
    }
}
