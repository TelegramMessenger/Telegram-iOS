import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public enum AuthorizationCodeRequestError {
    case invalidPhoneNumber
    case limitExceeded
    case generic(info: (Int, String)?)
    case phoneLimitExceeded
    case phoneBanned
    case timeout
}

func switchToAuthorizedAccount(transaction: AccountManagerModifier, account: UnauthorizedAccount) {
    let nextSortOrder = (transaction.getRecords().map({ record -> Int32 in
        for attribute in record.attributes {
            if let attribute = attribute as? AccountSortOrderAttribute {
                return attribute.order
            }
        }
        return 0
    }).max() ?? 0) + 1
    transaction.updateRecord(account.id, { _ in
        return AccountRecord(id: account.id, attributes: [AccountEnvironmentAttribute(environment: account.testingEnvironment ? .test : .production), AccountSortOrderAttribute(order: nextSortOrder)], temporarySessionId: nil)
    })
    transaction.setCurrentId(account.id)
    transaction.removeAuth()
}

public func sendAuthorizationCode(accountManager: AccountManager, account: UnauthorizedAccount, phoneNumber: String, apiId: Int32, apiHash: String, syncContacts: Bool) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> {
    let sendCode = Api.functions.auth.sendCode(flags: 0, phoneNumber: phoneNumber, currentNumber: nil, apiId: apiId, apiHash: apiHash)
    
    let codeAndAccount = account.network.request(sendCode, automaticFloodWait: false)
    |> map { result in
        return (result, account)
    }
    |> `catch` { error -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
        switch (error.errorDescription ?? "") {
            case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
                let range = error.errorDescription.range(of: "MIGRATE_")!
                let updatedMasterDatacenterId = Int32(error.errorDescription[range.upperBound ..< error.errorDescription.endIndex])!
                let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: updatedMasterDatacenterId)
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
        } else if error.errorDescription == "PHONE_NUMBER_FLOOD" {
            return .phoneLimitExceeded
        } else if error.errorDescription == "PHONE_NUMBER_BANNED" {
            return .phoneBanned
        } else {
            return .generic(info: (Int(error.errorCode), error.errorDescription))
        }
    }
    |> timeout(20.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.timeout))
    
    return codeAndAccount
    |> mapToSignal { (sentCode, account) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> in
        return account.postbox.transaction { transaction -> UnauthorizedAccount in
            switch sentCode {
                case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                    var parsedNextType: AuthorizationCodeNextType?
                    if let nextType = nextType {
                        parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                    }
                
                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .confirmationCodeEntry(number: phoneNumber, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType, syncContacts: syncContacts)))
            }
            return account
        }
        |> mapError { _ -> AuthorizationCodeRequestError in
            return .generic(info: nil)
        }
    }
}

public func resendAuthorizationCode(account: UnauthorizedAccount) -> Signal<Void, AuthorizationCodeRequestError> {
    return account.postbox.transaction { transaction -> Signal<Void, AuthorizationCodeRequestError> in
        if let state = transaction.getState() as? UnauthorizedAccountState {
            switch state.contents {
                case let .confirmationCodeEntry(number, _, hash, _, nextType, syncContacts):
                    if nextType != nil {
                        return account.network.request(Api.functions.auth.resendCode(phoneNumber: number, phoneCodeHash: hash), automaticFloodWait: false)
                            |> mapError { error -> AuthorizationCodeRequestError in
                                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                    return .limitExceeded
                                } else if error.errorDescription == "PHONE_NUMBER_INVALID" {
                                    return .invalidPhoneNumber
                                } else if error.errorDescription == "PHONE_NUMBER_FLOOD" {
                                    return .phoneLimitExceeded
                                } else if error.errorDescription == "PHONE_NUMBER_BANNED" {
                                    return .phoneBanned
                                } else {
                                    return .generic(info: (Int(error.errorCode), error.errorDescription))
                                }
                            }
                            |> mapToSignal { sentCode -> Signal<Void, AuthorizationCodeRequestError> in
                                return account.postbox.transaction { transaction -> Void in
                                    switch sentCode {
                                        case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                                            
                                                var parsedNextType: AuthorizationCodeNextType?
                                                if let nextType = nextType {
                                                    parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                                                }
                                                
                                                transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .confirmationCodeEntry(number: number, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType, syncContacts: syncContacts)))
                                        
                                    }
                                    } |> mapError { _ -> AuthorizationCodeRequestError in return .generic(info: nil) }
                            }
                    } else {
                        return .fail(.generic(info: nil))
                    }
                default:
                    return .complete()
            }
        } else {
            return .fail(.generic(info: nil))
        }
    }
    |> mapError { _ -> AuthorizationCodeRequestError in
        return .generic(info: nil)
    }
    |> switchToLatest
}

public enum AuthorizationCodeVerificationError {
    case invalidCode
    case limitExceeded
    case generic
    case codeExpired
}

private enum AuthorizationCodeResult {
    case authorization(Api.auth.Authorization)
    case password(hint: String)
    case signUp
}

public struct AuthorizationSignUpData {
    let number: String
    let codeHash: String
    let code: String
    let termsOfService: UnauthorizedAccountTermsOfService?
    let syncContacts: Bool
}

public enum AuthorizeWithCodeResult {
    case signUp(AuthorizationSignUpData)
    case loggedIn
}

public func authorizeWithCode(accountManager: AccountManager, account: UnauthorizedAccount, code: String, termsOfService: UnauthorizedAccountTermsOfService?) -> Signal<AuthorizeWithCodeResult, AuthorizationCodeVerificationError> {
    return account.postbox.transaction { transaction -> Signal<AuthorizeWithCodeResult, AuthorizationCodeVerificationError> in
        if let state = transaction.getState() as? UnauthorizedAccountState {
            switch state.contents {
                case let .confirmationCodeEntry(number, _, hash, _, _, syncContacts):
                    return account.network.request(Api.functions.auth.signIn(phoneNumber: number, phoneCodeHash: hash, phoneCode: code), automaticFloodWait: false)
                    |> map { authorization in
                        return .authorization(authorization)
                    }
                    |> `catch` { error -> Signal<AuthorizationCodeResult, AuthorizationCodeVerificationError> in
                        switch (error.errorCode, error.errorDescription ?? "") {
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
                                        case let .password(password):
                                            return .single(.password(hint: password.hint ?? ""))
                                    }
                                }
                            case let (_, errorDescription):
                                if errorDescription.hasPrefix("FLOOD_WAIT") {
                                    return .fail(.limitExceeded)
                                } else if errorDescription == "PHONE_CODE_INVALID" {
                                    return .fail(.invalidCode)
                                } else if errorDescription == "CODE_HASH_EXPIRED" || errorDescription == "PHONE_CODE_EXPIRED" {
                                    return .fail(.codeExpired)
                                } else if errorDescription == "PHONE_NUMBER_UNOCCUPIED" {
                                    return .single(.signUp)
                                } else {
                                    return .fail(.generic)
                                }
                        }
                    }
                    |> mapToSignal { result -> Signal<AuthorizeWithCodeResult, AuthorizationCodeVerificationError> in
                        return account.postbox.transaction { transaction -> Signal<AuthorizeWithCodeResult, NoError> in
                            switch result {
                                case .signUp:
                                    return .single(.signUp(AuthorizationSignUpData(number: number, codeHash: hash, code: code, termsOfService: termsOfService, syncContacts: syncContacts)))
                                case let .password(hint):
                                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint, number: number, code: code, suggestReset: false, syncContacts: syncContacts)))
                                    return .single(.loggedIn)
                                case let .authorization(authorization):
                                    switch authorization {
                                    case let .authorization(_, _, user):
                                        let user = TelegramUser(user: user)
                                        let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                                        initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                                        transaction.setState(state)
                                        return accountManager.transaction { transaction -> AuthorizeWithCodeResult in
                                            switchToAuthorizedAccount(transaction: transaction, account: account)
                                            return .loggedIn
                                        }
                                    case let .authorizationSignUpRequired(_, termsOfService):
                                        return .single(.signUp(AuthorizationSignUpData(number: number, codeHash: hash, code: code, termsOfService: termsOfService.flatMap(UnauthorizedAccountTermsOfService.init(apiTermsOfService:)), syncContacts: syncContacts)))
                                    }
                            }
                        }
                        |> switchToLatest
                        |> mapError { _ -> AuthorizationCodeVerificationError in
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

public func beginSignUp(account: UnauthorizedAccount, data: AuthorizationSignUpData) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .signUp(number: data.number, codeHash: data.codeHash, firstName: "", lastName: "", termsOfService: data.termsOfService, syncContacts: data.syncContacts)))
    }
    |> ignoreValues
}

public enum AuthorizationPasswordVerificationError {
    case limitExceeded
    case invalidPassword
    case generic
}

public func authorizeWithPassword(accountManager: AccountManager, account: UnauthorizedAccount, password: String, syncContacts: Bool) -> Signal<Void, AuthorizationPasswordVerificationError> {
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
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
            switch result {
            case let .authorization(_, _, user):
                let user = TelegramUser(user: user)
                let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                /*transaction.updatePeersInternal([user], update: { current, peer -> Peer? in
                 return peer
                 })*/
                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                transaction.setState(state)
                
                return accountManager.transaction { transaction -> Void in
                    switchToAuthorizedAccount(transaction: transaction, account: account)
                }
            case .authorizationSignUpRequired:
                return .complete()
            }
        }
        |> switchToLatest
        |> mapError { _ -> AuthorizationPasswordVerificationError in
            return .generic
        }
    }
}

public enum PasswordRecoveryRequestError {
    case limitExceeded
    case generic
}

public enum PasswordRecoveryOption {
    case none
    case email(pattern: String)
}

public func requestPasswordRecovery(account: UnauthorizedAccount) -> Signal<PasswordRecoveryOption, PasswordRecoveryRequestError> {
    return account.network.request(Api.functions.auth.requestPasswordRecovery())
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.auth.PasswordRecovery?, PasswordRecoveryRequestError> in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .fail(.limitExceeded)
            } else if error.errorDescription.hasPrefix("PASSWORD_RECOVERY_NA") {
                return .single(nil)
            } else {
                return .fail(.generic)
            }
        }
        |> map { result -> PasswordRecoveryOption in
            if let result = result {
                switch result {
                    case let .passwordRecovery(emailPattern):
                        return .email(pattern: emailPattern)
                }
            } else {
                return .none
            }
        }
}

public enum PasswordRecoveryError {
    case invalidCode
    case limitExceeded
    case expired
}

public func performPasswordRecovery(accountManager: AccountManager, account: UnauthorizedAccount, code: String, syncContacts: Bool) -> Signal<Void, PasswordRecoveryError> {
    return account.network.request(Api.functions.auth.recoverPassword(code: code))
    |> mapError { error -> PasswordRecoveryError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription.hasPrefix("PASSWORD_RECOVERY_EXPIRED") {
            return .expired
        } else {
            return .invalidCode
        }
    }
    |> mapToSignal { result -> Signal<Void, PasswordRecoveryError> in
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
            switch result {
            case let .authorization(_, _, user):
                let user = TelegramUser(user: user)
                let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                /*transaction.updatePeersInternal([user], update: { current, peer -> Peer? in
                 return peer
                 })*/
                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                transaction.setState(state)
                return accountManager.transaction { transaction -> Void in
                    switchToAuthorizedAccount(transaction: transaction, account: account)
                }
            case .authorizationSignUpRequired:
                return .complete()
            }
        }
        |> switchToLatest
        |> mapError { _ in return PasswordRecoveryError.expired }
    }
}

public enum AccountResetError {
    case generic
    case limitExceeded
}

public func performAccountReset(account: UnauthorizedAccount) -> Signal<Void, AccountResetError> {
    return account.network.request(Api.functions.account.deleteAccount(reason: ""))
    |> map { _ -> Int32? in return nil }
    |> `catch` { error -> Signal<Int32?, AccountResetError> in
        if error.errorDescription.hasPrefix("2FA_CONFIRM_WAIT_") {
            let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "2FA_CONFIRM_WAIT_".count)...])
            if let value = Int32(timeout) {
                return .single(value)
            } else {
                return .fail(.generic)
            }
        } else if error.errorDescription == "2FA_RECENT_CONFIRM" {
            return .fail(.limitExceeded)
        } else {
            return .fail(.generic)
        }
    }
    |> mapToSignal { timeout -> Signal<Void, AccountResetError> in
        return account.postbox.transaction { transaction -> Void in
            guard let state = transaction.getState() as? UnauthorizedAccountState else {
                return
            }
            var number: String?
            var syncContacts: Bool?
            if case let .passwordEntry(_, numberValue, _, _, syncContactsValue) = state.contents {
                number = numberValue
                syncContacts = syncContactsValue
            } else if case let .awaitingAccountReset(_, numberValue, syncContactsValue) = state.contents {
                number = numberValue
                syncContacts = syncContactsValue
            }
            if let number = number, let syncContacts = syncContacts {
                if let timeout = timeout {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: state.isTestingEnvironment, masterDatacenterId: state.masterDatacenterId, contents: .awaitingAccountReset(protectedUntil: timestamp + timeout, number: number, syncContacts: syncContacts)))
                } else {
                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: state.isTestingEnvironment, masterDatacenterId: state.masterDatacenterId, contents: .empty))
                }
            }
        }
        |> mapError { _ in return AccountResetError.generic }
    }
}

public enum SignUpError {
    case generic
    case limitExceeded
    case codeExpired
    case invalidFirstName
    case invalidLastName
}

public func signUpWithName(accountManager: AccountManager, account: UnauthorizedAccount, firstName: String, lastName: String, avatarData: Data?) -> Signal<Void, SignUpError> {
    return account.postbox.transaction { transaction -> Signal<Void, SignUpError> in
        if let state = transaction.getState() as? UnauthorizedAccountState, case let .signUp(number, codeHash, _, _, _, syncContacts) = state.contents {
            return account.network.request(Api.functions.auth.signUp(phoneNumber: number, phoneCodeHash: codeHash, firstName: firstName, lastName: lastName))
            |> mapError { error -> SignUpError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else if error.errorDescription == "PHONE_CODE_EXPIRED" {
                    return .codeExpired
                } else if error.errorDescription == "FIRSTNAME_INVALID" {
                    return .invalidFirstName
                } else if error.errorDescription == "LASTNAME_INVALID" {
                    return .invalidLastName
                } else {
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Void, SignUpError> in
                switch result {
                case let .authorization(_, _, user):
                    let user = TelegramUser(user: user)
                    let appliedState = account.postbox.transaction { transaction -> Void in
                        let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                        if let hole = account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
                            transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
                        }
                        initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                        transaction.setState(state)
                        }
                        |> castError(SignUpError.self)
                    
                    let switchedAccounts = accountManager.transaction { transaction -> Void in
                        switchToAuthorizedAccount(transaction: transaction, account: account)
                        }
                        |> castError(SignUpError.self)
                    
                    if let avatarData = avatarData {
                        let resource = LocalFileMediaResource(fileId: arc4random64())
                        account.postbox.mediaBox.storeResourceData(resource.id, data: avatarData)
                        
                        return updatePeerPhotoInternal(postbox: account.postbox, network: account.network, stateManager: nil, accountPeerId: user.id, peer: .single(user), photo: uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: resource), mapResourceToAvatarSizes: { _, _ in .single([:]) })
                            |> `catch` { _ -> Signal<UpdatePeerPhotoStatus, SignUpError> in
                                return .complete()
                            }
                            |> mapToSignal { result -> Signal<Void, SignUpError> in
                                switch result {
                                case .complete:
                                    return .complete()
                                case .progress:
                                    return .never()
                                }
                            }
                            |> then(appliedState)
                            |> then(switchedAccounts)
                    } else {
                        return appliedState
                            |> then(switchedAccounts)
                    }
                case .authorizationSignUpRequired:
                    return .fail(.generic)
                }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> SignUpError in
        return .generic
    }
    |> switchToLatest
}

public enum AuthorizationStateReset {
    case empty
}

public func resetAuthorizationState(account: UnauthorizedAccount, to value: AuthorizationStateReset) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if let state = transaction.getState() as? UnauthorizedAccountState {
            transaction.setState(UnauthorizedAccountState(isTestingEnvironment: state.isTestingEnvironment, masterDatacenterId: state.masterDatacenterId, contents: .empty))
        }
    }
}
