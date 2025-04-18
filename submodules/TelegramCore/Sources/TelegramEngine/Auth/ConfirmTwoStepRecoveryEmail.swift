import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramApi


public enum ConfirmTwoStepRecoveryEmailError {
    case invalidEmail
    case invalidCode
    case flood
    case expired
    case generic
}

func _internal_confirmTwoStepRecoveryEmail(network: Network, code: String) -> Signal<Never, ConfirmTwoStepRecoveryEmailError> {
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

func _internal_resendTwoStepRecoveryEmail(network: Network) -> Signal<Never, ResendTwoStepRecoveryEmailError> {
    return network.request(Api.functions.account.resendPasswordEmail(), automaticFloodWait: false)
    |> mapError { error -> ResendTwoStepRecoveryEmailError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        }
        return .generic
    }
    |> ignoreValues
}

public enum CancelTwoStepRecoveryEmailError {
    case generic
}

func _internal_cancelTwoStepRecoveryEmail(network: Network) -> Signal<Never, CancelTwoStepRecoveryEmailError> {
    return network.request(Api.functions.account.cancelPasswordEmail(), automaticFloodWait: false)
    |> mapError { _ -> CancelTwoStepRecoveryEmailError in
        return .generic
    }
    |> ignoreValues
}
