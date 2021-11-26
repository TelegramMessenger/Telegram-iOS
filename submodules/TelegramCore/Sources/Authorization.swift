import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum AuthorizationCodeRequestError {
    case invalidPhoneNumber
    case limitExceeded
    case generic(info: (Int, String)?)
    case phoneLimitExceeded
    case phoneBanned
    case timeout
}

func switchToAuthorizedAccount(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, account: UnauthorizedAccount) {
    let nextSortOrder = (transaction.getRecords().map({ record -> Int32 in
        for attribute in record.attributes {
            if case let .sortOrder(sortOrder) = attribute {
                return sortOrder.order
            }
        }
        return 0
    }).max() ?? 0) + 1
    transaction.updateRecord(account.id, { _ in
        return AccountRecord(id: account.id, attributes: [
            .environment(AccountEnvironmentAttribute(environment: account.testingEnvironment ? .test : .production)),
            .sortOrder(AccountSortOrderAttribute(order: nextSortOrder))
        ], temporarySessionId: nil)
    })
    transaction.setCurrentId(account.id)
    transaction.removeAuth()
}

private struct Regex {
    let pattern: String
    let options: NSRegularExpression.Options!

    private var matcher: NSRegularExpression {
        return try! NSRegularExpression(pattern: self.pattern, options: self.options)
    }

    init(_ pattern: String) {
        self.pattern = pattern
        self.options = []
    }

    func match(_ string: String, options: NSRegularExpression.MatchingOptions = []) -> Bool {
        return self.matcher.numberOfMatches(in: string, options: options, range: NSMakeRange(0, string.utf16.count)) != 0
    }
}

private protocol RegularExpressionMatchable {
    func match(_ regex: Regex) -> Bool
}

private struct MatchString: RegularExpressionMatchable {
    private let string: String

    init(_ string: String) {
        self.string = string
    }

    func match(_ regex: Regex) -> Bool {
        return regex.match(self.string)
    }
}

private func ~=<T: RegularExpressionMatchable>(pattern: Regex, matchable: T) -> Bool {
    return matchable.match(pattern)
}

public func sendAuthorizationCode(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, phoneNumber: String, apiId: Int32, apiHash: String, syncContacts: Bool) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> {
    return accountManager.transaction { transaction -> [Data] in
        return transaction.getStoredLoginTokens()
    }
    |> castError(AuthorizationCodeRequestError.self)
    |> mapToSignal { authTokens -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> in
        var flags: Int32 = 0
        flags |= 1 << 5 //allowMissedCall
        flags |= 1 << 6 //tokens
        let sendCode = Api.functions.auth.sendCode(phoneNumber: phoneNumber, apiId: apiId, apiHash: apiHash, settings: .codeSettings(flags: flags, logoutTokens: authTokens.map { Buffer(data: $0) }))
        
        enum SendCodeResult {
            case password(hint: String?)
            case sentCode(Api.auth.SentCode)
        }
        
        let codeAndAccount = account.network.request(sendCode, automaticFloodWait: false)
        |> map { result -> (SendCodeResult, UnauthorizedAccount) in
            return (.sentCode(result), account)
        }
        |> `catch` { error -> Signal<(SendCodeResult, UnauthorizedAccount), MTRpcError> in
            switch MatchString(error.errorDescription ?? "") {
                case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
                    let range = error.errorDescription.range(of: "MIGRATE_")!
                    let updatedMasterDatacenterId = Int32(error.errorDescription[range.upperBound ..< error.errorDescription.endIndex])!
                    let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: updatedMasterDatacenterId)
                    return updatedAccount
                    |> mapToSignalPromotingError { updatedAccount -> Signal<(SendCodeResult, UnauthorizedAccount), MTRpcError> in
                        return updatedAccount.network.request(sendCode, automaticFloodWait: false)
                        |> map { sentCode in
                            return (.sentCode(sentCode), updatedAccount)
                        }
                        |> `catch` { error -> Signal<(SendCodeResult, UnauthorizedAccount), MTRpcError> in
                            if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
                                return updatedAccount.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                                |> mapToSignal { result -> Signal<(SendCodeResult, UnauthorizedAccount), MTRpcError> in
                                    switch result {
                                    case let .password(_, _, _, _, hint, _, _, _, _, _):
                                        return .single((.password(hint: hint), updatedAccount))
                                    }
                                }
                            } else {
                                return .fail(error)
                            }
                        }
                    }
                case _:
                    return .fail(error)
            }
        }
        |> `catch` { error -> Signal<(SendCodeResult, UnauthorizedAccount), AuthorizationCodeRequestError> in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .fail(.limitExceeded)
            } else if error.errorDescription == "PHONE_NUMBER_INVALID" {
                return .fail(.invalidPhoneNumber)
            } else if error.errorDescription == "PHONE_NUMBER_FLOOD" {
                return .fail(.phoneLimitExceeded)
            } else if error.errorDescription == "PHONE_NUMBER_BANNED" {
                return .fail(.phoneBanned)
            } else if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
                return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                |> mapError { error -> AuthorizationCodeRequestError in
                    if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                        return .limitExceeded
                    } else {
                        return .generic(info: (Int(error.errorCode), error.errorDescription))
                    }
                }
                |> mapToSignal { result -> Signal<(SendCodeResult, UnauthorizedAccount), AuthorizationCodeRequestError> in
                    switch result {
                    case let .password(_, _, _, _, hint, _, _, _, _, _):
                        return .single((.password(hint: hint), account))
                    }
                }
            } else {
                return .fail(.generic(info: (Int(error.errorCode), error.errorDescription)))
            }
        }
        |> timeout(20.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.timeout))
        
        return codeAndAccount
        |> mapToSignal { result, account -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> in
            return account.postbox.transaction { transaction -> UnauthorizedAccount in
                switch result {
                case let .password(hint):
                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents:  .passwordEntry(hint: hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                case let .sentCode(sentCode):
                    switch sentCode {
                    case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                        var parsedNextType: AuthorizationCodeNextType?
                        if let nextType = nextType {
                            parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                        }
                        
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .confirmationCodeEntry(number: phoneNumber, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType, syncContacts: syncContacts)))
                    }
                }
                return account
            }
            |> mapError { _ -> AuthorizationCodeRequestError in
            }
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
                                    } |> mapError { _ -> AuthorizationCodeRequestError in }
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

public func authorizeWithCode(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, code: String, termsOfService: UnauthorizedAccountTermsOfService?, forcedPasswordSetupNotice: @escaping (Int32) -> (NoticeEntryKey, CodableEntry)?) -> Signal<AuthorizeWithCodeResult, AuthorizationCodeVerificationError> {
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
                                        case let .password(_, _, _, _, hint, _, _, _, _, _):
                                            return .single(.password(hint: hint ?? ""))
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
                                    case let .authorization(_, otherwiseReloginDays, _, user):
                                        let user = TelegramUser(user: user)
                                        let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                                        initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                                        transaction.setState(state)
                                        if let otherwiseReloginDays = otherwiseReloginDays, let value = forcedPasswordSetupNotice(otherwiseReloginDays) {
                                            transaction.setNoticeEntry(key: value.0, value: value.1)
                                        }
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

public func authorizeWithPassword(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, password: String, syncContacts: Bool) -> Signal<Void, AuthorizationPasswordVerificationError> {
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
            case let .authorization(_, _, _, user):
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

public enum PasswordRecoveryError {
    case invalidCode
    case limitExceeded
    case expired
    case generic
}

func _internal_checkPasswordRecoveryCode(network: Network, code: String) -> Signal<Never, PasswordRecoveryError> {
    return network.request(Api.functions.auth.checkRecoveryPassword(code: code), automaticFloodWait: false)
    |> mapError { error -> PasswordRecoveryError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription.hasPrefix("PASSWORD_RECOVERY_EXPIRED") {
            return .expired
        } else {
            return .invalidCode
        }
    }
    |> mapToSignal { result -> Signal<Never, PasswordRecoveryError> in
        return .complete()
    }
}

public final class RecoveredAccountData {
    let authorization: Api.auth.Authorization

    init(authorization: Api.auth.Authorization) {
        self.authorization = authorization
    }
}

public func loginWithRecoveredAccountData(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, recoveredAccountData: RecoveredAccountData, syncContacts: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        switch recoveredAccountData.authorization {
        case let .authorization(_, _, _, user):
            let user = TelegramUser(user: user)
            let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)

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
    |> ignoreValues
}

func _internal_performPasswordRecovery(network: Network, code: String, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<RecoveredAccountData, PasswordRecoveryError> {
    return _internal_twoStepAuthData(network)
    |> mapError { _ -> PasswordRecoveryError in
        return .generic
    }
    |> mapToSignal { authData -> Signal<RecoveredAccountData, PasswordRecoveryError> in
        let newSettings: Api.account.PasswordInputSettings?
        switch updatedPassword {
        case .none:
            newSettings = nil
        case let .password(password, hint, email):
            var flags: Int32 = 1 << 0
            if email != nil {
                flags |= (1 << 1)
            }

            guard let (updatedPasswordHash, updatedPasswordDerivation) = passwordUpdateKDF(encryptionProvider: network.encryptionProvider, password: password, derivation: authData.nextPasswordDerivation) else {
                return .fail(.invalidCode)
            }

            newSettings = Api.account.PasswordInputSettings.passwordInputSettings(flags: flags, newAlgo: updatedPasswordDerivation.apiAlgo, newPasswordHash: Buffer(data: updatedPasswordHash), hint: hint, email: email, newSecureSettings: nil)
        }

        var flags: Int32 = 0
        if newSettings != nil {
            flags |= 1 << 0
        }
        return network.request(Api.functions.auth.recoverPassword(flags: flags, code: code, newSettings: newSettings), automaticFloodWait: false)
        |> mapError { error -> PasswordRecoveryError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else if error.errorDescription.hasPrefix("PASSWORD_RECOVERY_EXPIRED") {
                return .expired
            } else {
                return .invalidCode
            }
        }
        |> mapToSignal { result -> Signal<RecoveredAccountData, PasswordRecoveryError> in
            return .single(RecoveredAccountData(authorization: result))
        }
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
        |> mapError { _ -> AccountResetError in }
    }
}

public enum SignUpError {
    case generic
    case limitExceeded
    case codeExpired
    case invalidFirstName
    case invalidLastName
}

public func signUpWithName(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, firstName: String, lastName: String, avatarData: Data?, avatarVideo: Signal<UploadedPeerPhotoData?, NoError>?, videoStartTimestamp: Double?, forcedPasswordSetupNotice: @escaping (Int32) -> (NoticeEntryKey, CodableEntry)?) -> Signal<Void, SignUpError> {
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
                case let .authorization(_, otherwiseReloginDays, _, user):
                    let user = TelegramUser(user: user)
                    let appliedState = account.postbox.transaction { transaction -> Void in
                        let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                        if let hole = account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
                            transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
                        }
                        initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                        transaction.setState(state)
                        if let otherwiseReloginDays = otherwiseReloginDays, let value = forcedPasswordSetupNotice(otherwiseReloginDays) {
                            transaction.setNoticeEntry(key: value.0, value: value.1)
                        }
                    }
                    |> castError(SignUpError.self)
                    
                    let switchedAccounts = accountManager.transaction { transaction -> Void in
                        switchToAuthorizedAccount(transaction: transaction, account: account)
                    }
                    |> castError(SignUpError.self)
                    
                    if let avatarData = avatarData {
                        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                        account.postbox.mediaBox.storeResourceData(resource.id, data: avatarData)
                        
                        return _internal_updatePeerPhotoInternal(postbox: account.postbox, network: account.network, stateManager: nil, accountPeerId: user.id, peer: .single(user), photo: _internal_uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: resource), video: avatarVideo, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { _, _ in .single([:]) })
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
