import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public struct CancelAccountResetData: Equatable {
    public let type: SentAuthorizationCodeType
    public let hash: String
    public let timeout: Int32?
    public let nextType: AuthorizationCodeNextType?
}

public enum RequestCancelAccountResetDataError {
    case limitExceeded
    case generic
}

func _internal_requestCancelAccountResetData(network: Network, hash: String) -> Signal<CancelAccountResetData, RequestCancelAccountResetDataError> {
    return network.request(Api.functions.account.sendConfirmPhoneCode(hash: hash, settings: .codeSettings(flags: 0)), automaticFloodWait: false)
    |> mapError { error -> RequestCancelAccountResetDataError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else {
            return .generic
        }
    }
    |> map { sentCode -> CancelAccountResetData in
        switch sentCode {
            case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                var parsedNextType: AuthorizationCodeNextType?
                if let nextType = nextType {
                    parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                }
                return CancelAccountResetData(type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType)
        }
    }
}

func _internal_requestNextCancelAccountResetOption(network: Network, phoneNumber: String, phoneCodeHash: String) -> Signal<CancelAccountResetData, RequestCancelAccountResetDataError> {
    return network.request(Api.functions.auth.resendCode(phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash), automaticFloodWait: false)
    |> mapError { error -> RequestCancelAccountResetDataError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else {
            return .generic
        }
    }
    |> map { sentCode -> CancelAccountResetData in
        switch sentCode {
            case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                var parsedNextType: AuthorizationCodeNextType?
                if let nextType = nextType {
                    parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                }
                return CancelAccountResetData(type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType)
        }
    }
}

public enum CancelAccountResetError {
    case generic
    case invalidCode
    case codeExpired
    case limitExceeded
}

func _internal_requestCancelAccountReset(network: Network, phoneCodeHash: String, phoneCode: String) -> Signal<Never, CancelAccountResetError> {
    return network.request(Api.functions.account.confirmPhone(phoneCodeHash: phoneCodeHash, phoneCode: phoneCode))
    |> mapError { error -> CancelAccountResetError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription == "PHONE_CODE_INVALID" {
            return .invalidCode
        } else if error.errorDescription == "PHONE_CODE_EXPIRED" {
            return .codeExpired
        } else {
            return .generic
        }
    }
    |> ignoreValues
}
