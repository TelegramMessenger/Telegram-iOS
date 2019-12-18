import Foundation
import Postbox
import TelegramApi
import SyncCore
import SwiftSignalKit

public struct AuthTransferExportedToken {
    public let value: Data
    public let validUntil: Int32
}

public enum ExportAuthTransferTokenError {
    case generic
    case limitExceeded
}

public enum ExportAuthTransferTokenResult {
    case displayToken(AuthTransferExportedToken)
    case changeAccountAndRetry(UnauthorizedAccount)
    case loggedIn
    case passwordRequested
}

public func exportAuthTransferToken(accountManager: AccountManager, account: UnauthorizedAccount, otherAccountUserIds: [Int32], syncContacts: Bool) -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> {
    return account.network.request(Api.functions.auth.exportLoginToken(apiId: account.networkArguments.apiId, apiHash: account.networkArguments.apiHash, exceptIds: otherAccountUserIds))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
        if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
            return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
            |> mapError { error -> ExportAuthTransferTokenError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else {
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                switch result {
                case let .password(password):
                    return account.postbox.transaction { transaction -> Api.auth.LoginToken? in
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: password.hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                        return nil
                    }
                    |> castError(ExportAuthTransferTokenError.self)
                    
                    return .single(nil)
                }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapToSignal { result -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
        guard let result = result else {
            return .single(.passwordRequested)
        }
        switch result {
        case let .loginToken(expires, token):
            return .single(.displayToken(AuthTransferExportedToken(value: token.makeData(), validUntil: expires)))
        case let .loginTokenMigrateTo(dcId, token):
            let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: dcId)
            return updatedAccount
            |> castError(ExportAuthTransferTokenError.self)
            |> mapToSignal { updatedAccount -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                return updatedAccount.network.request(Api.functions.auth.importLoginToken(token: token))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                    if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
                        return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                        |> mapError { error -> ExportAuthTransferTokenError in
                            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                return .limitExceeded
                            } else {
                                return .generic
                            }
                        }
                        |> mapToSignal { result -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                            switch result {
                            case let .password(password):
                                return account.postbox.transaction { transaction -> Api.auth.LoginToken? in
                                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: password.hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                                    return nil
                                }
                                |> castError(ExportAuthTransferTokenError.self)
                                
                                return .single(nil)
                            }
                        }
                    } else {
                        return .fail(.generic)
                    }
                }
                |> mapToSignal { result -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                    switch result {
                    case let .loginTokenSuccess(authorization)?:
                        switch authorization {
                        case let .authorization(_, _, user):
                            return updatedAccount.postbox.transaction { transaction -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                                let user = TelegramUser(user: user)
                                let state = AuthorizedAccountState(isTestingEnvironment: updatedAccount.testingEnvironment, masterDatacenterId: updatedAccount.masterDatacenterId, peerId: user.id, state: nil)
                                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: updatedAccount.networkArguments.appVersion, syncContacts: syncContacts)
                                transaction.setState(state)
                                return accountManager.transaction { transaction -> ExportAuthTransferTokenResult in
                                    switchToAuthorizedAccount(transaction: transaction, account: updatedAccount)
                                    return .loggedIn
                                }
                                |> castError(ExportAuthTransferTokenError.self)
                            }
                            |> castError(ExportAuthTransferTokenError.self)
                            |> switchToLatest
                        default:
                            return .fail(.generic)
                        }
                    default:
                        return .single(.changeAccountAndRetry(updatedAccount))
                    }
                }
            }
        case let .loginTokenSuccess(authorization):
            switch authorization {
            case let .authorization(_, _, user):
                return account.postbox.transaction { transaction -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                    let user = TelegramUser(user: user)
                    let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                    initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                    transaction.setState(state)
                    return accountManager.transaction { transaction -> ExportAuthTransferTokenResult in
                        switchToAuthorizedAccount(transaction: transaction, account: account)
                        return .loggedIn
                    }
                    |> castError(ExportAuthTransferTokenError.self)
                }
                |> castError(ExportAuthTransferTokenError.self)
                |> switchToLatest
            case let .authorizationSignUpRequired:
                return .fail(.generic)
            }
        }
    }
}

public enum ApproveAuthTransferTokenError {
    case generic
    case invalid
    case expired
    case alreadyAccepted
}

public func approveAuthTransferToken(account: Account, token: Data, activeSessionsContext: ActiveSessionsContext) -> Signal<RecentAccountSession, ApproveAuthTransferTokenError> {
    return account.network.request(Api.functions.auth.acceptLoginToken(token: Buffer(data: token)))
    |> mapError { error -> ApproveAuthTransferTokenError in
        switch error.errorDescription {
        case "AUTH_TOKEN_INVALID":
            return .invalid
        case "AUTH_TOKEN_EXPIRED":
            return .expired
        case "AUTH_TOKEN_ALREADY_ACCEPTED":
            return .alreadyAccepted
        default:
            return .generic
        }
    }
    |> mapToSignal { authorization -> Signal<RecentAccountSession, ApproveAuthTransferTokenError> in
        let session = RecentAccountSession(apiAuthorization: authorization)
        activeSessionsContext.addSession(session)
        return .single(session)
    }
}
