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
}

public func secureIdCommitPhoneVerification(network: Network, payload: SecureIdPreparePhoneVerificationPayload, code: String) -> Signal<Void, SecureIdCommitPhoneVerificationError> {
    return network.request(Api.functions.account.verifyPhone(phoneNumber: payload.phone, phoneCodeHash: payload.phoneCodeHash, phoneCode: code))
    |> mapError { error -> SecureIdCommitPhoneVerificationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, SecureIdCommitPhoneVerificationError> in
        return .complete()
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
}

public func secureIdCommitEmailVerification(network: Network, payload: SecureIdPrepareEmailVerificationPayload, code: String) -> Signal<Void, SecureIdCommitEmailVerificationError> {
    return network.request(Api.functions.account.verifyEmail(email: payload.email, code: code), automaticFloodWait: false)
    |> mapError { error -> SecureIdCommitEmailVerificationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, SecureIdCommitEmailVerificationError> in
        return .complete()
    }
}
