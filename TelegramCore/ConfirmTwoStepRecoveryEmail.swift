import Foundation
#if os(macOS)
import SwiftSignalKitMac
import MtProtoKitMac
#else
import SwiftSignalKit
import MtProtoKitDynamic
#endif

public enum ConfirmTwoStepRecoveryEmailError {
    case invalidEmail
    case invalidCode
    case flood
    case expired
    case generic
}

public func confirmTwoStepRecoveryEmail(network: Network, code: String) -> Signal<Never, ConfirmTwoStepRecoveryEmailError> {
    return network.request(Api.functions.account.confirmPasswordEmail(code: code), automaticFloodWait: false)
    |> mapError { error -> ConfirmTwoStepRecoveryEmailError in
        if error.errorDescription == "EMAIL_INVALID" {
            return .invalidEmail
        } else if error.errorDescription == "CODE_INVALID" {
            return .invalidCode
        } else if error.errorDescription == "EMAIL_HASH_EXPIRED" {
            return .expired
        } else if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> ignoreValues
}

public enum ResendTwoStepRecoveryEmailError {
    case flood
    case generic
}

public func resendTwoStepRecoveryEmail(network: Network) -> Signal<Never, ResendTwoStepRecoveryEmailError> {
    return network.request(Api.functions.account.resendPasswordEmail(), automaticFloodWait: false)
    |> mapError { error -> ResendTwoStepRecoveryEmailError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> ignoreValues
}
