import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum AuthorizationCodeRequestError {
    case invalidPhoneNumber
    case limitExceeded
    case generic
}

public func sendAuthorizationCode(account: UnauthorizedAccount, phoneNumber: String, apiId: Int32, apiHash: String) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> {
    let sendCode = Api.functions.auth.sendCode(flags: 0, phoneNumber: phoneNumber, currentNumber: nil, apiId: apiId, apiHash: apiHash)
    
    let codeAndAccount = account.network.request(sendCode, automaticFloodWait: false)
        |> map { result in
            return (result, account)
        } |> `catch` { error -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
            switch error.errorDescription {
                case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
                    let range = error.errorDescription.range(of: "MIGRATE_")!
                    let updatedMasterDatacenterId = Int32(error.errorDescription.substring(from: range.upperBound))!
                    let updatedAccount = account.changedMasterDatacenterId(updatedMasterDatacenterId)
                    return updatedAccount
                        |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                            return updatedAccount.network.request(sendCode, automaticFloodWait: false)
                                |> map { sentCode in
                                    return (sentCode, updatedAccount)
                            }
                    }
            case _:
                return .fail(error)
            }
        }
        |> mapError { error -> AuthorizationCodeRequestError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else if error.errorDescription == "PHONE_NUMBER_INVALID" {
                return .invalidPhoneNumber
            } else {
                return .generic
            }
        }
    
    return codeAndAccount
        |> mapToSignal { (sentCode, account) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> in
            return account.postbox.modify { modifier -> UnauthorizedAccount in
                switch sentCode {
                    case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                        var parsedNextType: AuthorizationCodeNextType?
                        if let nextType = nextType {
                            parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                        }
                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .confirmationCodeEntry(number: phoneNumber, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType)))
                }
                return account
            } |> mapError { _ -> AuthorizationCodeRequestError in return .generic }
        }
}

public func resendAuthorizationCode(account: UnauthorizedAccount) -> Signal<Void, AuthorizationCodeRequestError> {
    return account.postbox.modify { modifier -> Signal<Void, AuthorizationCodeRequestError> in
        if let state = modifier.getState() as? UnauthorizedAccountState {
            switch state.contents {
                case let .confirmationCodeEntry(number, _, hash, _, nextType):
                    if nextType != nil {
                        return account.network.request(Api.functions.auth.resendCode(phoneNumber: number, phoneCodeHash: hash), automaticFloodWait: false)
                            |> mapError { error -> AuthorizationCodeRequestError in
                                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                    return .limitExceeded
                                } else if error.errorDescription == "PHONE_NUMBER_INVALID" {
                                    return .invalidPhoneNumber
                                } else {
                                    return .generic
                                }
                            }
                            |> mapToSignal { sentCode -> Signal<Void, AuthorizationCodeRequestError> in
                                return account.postbox.modify { modifier -> Void in
                                    switch sentCode {
                                        case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                                            var parsedNextType: AuthorizationCodeNextType?
                                            if let nextType = nextType {
                                                parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                                            }
                                            modifier.setState(UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .confirmationCodeEntry(number: number, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType)))
                                    }
                                } |> mapError { _ -> AuthorizationCodeRequestError in return .generic }
                            }
                    } else {
                        return .fail(.generic)
                    }
                default:
                    return .complete()
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> AuthorizationCodeRequestError in
        return .generic
    }
    |> switchToLatest
}

public enum AuthorizationCodeVerificationError {
    case invalidCode
    case limitExceeded
    case generic
}

private enum AuthorizationCodeResult {
    case Authorization(Api.auth.Authorization)
    case Password(String)
}

public func authorizeWithCode(account: UnauthorizedAccount, code: String) -> Signal<Void, AuthorizationCodeVerificationError> {
    return account.postbox.modify { modifier -> Signal<Void, AuthorizationCodeVerificationError> in
        if let state = modifier.getState() as? UnauthorizedAccountState {
            switch state.contents {
                case let .confirmationCodeEntry(number, _, hash, _, _):
                    return account.network.request(Api.functions.auth.signIn(phoneNumber: number, phoneCodeHash: hash, phoneCode: code), automaticFloodWait: false) |> map { authorization in
                            return AuthorizationCodeResult.Authorization(authorization)
                        } |> `catch` { error -> Signal<AuthorizationCodeResult, AuthorizationCodeVerificationError> in
                            switch (error.errorCode, error.errorDescription) {
                                case (401, "SESSION_PASSWORD_NEEDED"):
                                    return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                                        |> mapError { error -> AuthorizationCodeVerificationError in
                                            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                                return .limitExceeded
                                            } else {
                                                return .generic
                                            }
                                        }
                                        |> mapToSignal { result -> Signal<AuthorizationCodeResult, AuthorizationCodeVerificationError> in
                                            switch result {
                                                case .noPassword:
                                                    return .fail(.generic)
                                                case let .password(_, _, hint, _, _):
                                                    return .single(.Password(hint))
                                            }
                                        }
                                case let (_, errorDescription):
                                    if errorDescription.hasPrefix("FLOOD_WAIT") {
                                        return .fail(.limitExceeded)
                                    } else if errorDescription == "PHONE_CODE_INVALID" {
                                        return .fail(.invalidCode)
                                    } else {
                                        return .fail(.generic)
                                    }
                            }
                        }
                        |> mapToSignal { result -> Signal<Void, AuthorizationCodeVerificationError> in
                            return account.postbox.modify { modifier -> Void in
                                switch result {
                                    case let .Password(hint):
                                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint)))
                                    case let .Authorization(authorization):
                                        switch authorization {
                                            case let .authorization(_, _, user):
                                                let user = TelegramUser(user: user)
                                                let state = AuthorizedAccountState(masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                                                modifier.setState(state)
                                        }
                                }
                            } |> mapError { _ -> AuthorizationCodeVerificationError in
                                    return .generic
                            }
                        }
                default:
                    return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> AuthorizationCodeVerificationError in
        return .generic
    }
    |> switchToLatest
}

public enum AuthorizationPasswordVerificationError {
    case limitExceeded
    case invalidPassword
    case generic
}

public func authorizeWithPassword(account: UnauthorizedAccount, password: String) -> Signal<Void, AuthorizationPasswordVerificationError> {
    return verifyPassword(account, password: password)
        |> `catch` { error -> Signal<Api.auth.Authorization, AuthorizationPasswordVerificationError> in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .fail(.limitExceeded)
            } else if error.errorDescription == "PASSWORD_HASH_INVALID" {
                return .fail(.invalidPassword)
            } else {
                return .fail(.generic)
            }
        }
        |> mapToSignal { result -> Signal<Void, AuthorizationPasswordVerificationError> in
            return account.postbox.modify { modifier -> Void in
                switch result {
                    case let .authorization(_, _, user):
                        let user = TelegramUser(user: user)
                        let state = AuthorizedAccountState(masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                        modifier.setState(state)
                    }
            }
            |> mapError { _ -> AuthorizationPasswordVerificationError in
                return .generic
            }
        }
}

public enum AuthorizationStateReset {
    case empty
}

public func resetAuthorizationState(account: UnauthorizedAccount, to value: AuthorizationStateReset) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let state = modifier.getState() as? UnauthorizedAccountState {
            modifier.setState(UnauthorizedAccountState(masterDatacenterId: state.masterDatacenterId, contents: .empty))
        }
    }
}
