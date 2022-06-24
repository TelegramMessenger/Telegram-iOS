import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public enum TelegramEngineAuthorizationState {
    case unauthorized(UnauthorizedAccountState)
    case authorized
}

public extension TelegramEngineUnauthorized {
    final class Auth {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func exportAuthTransferToken(accountManager: AccountManager<TelegramAccountManagerTypes>, otherAccountUserIds: [PeerId.Id], syncContacts: Bool) -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> {
            return _internal_exportAuthTransferToken(accountManager: accountManager, account: self.account, otherAccountUserIds: otherAccountUserIds, syncContacts: syncContacts)
        }

        public func twoStepAuthData() -> Signal<TwoStepAuthData, MTRpcError> {
            return _internal_twoStepAuthData(self.account.network)
        }

        public func updateTwoStepVerificationPassword(currentPassword: String?, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<UpdateTwoStepVerificationPasswordResult, UpdateTwoStepVerificationPasswordError> {
            return _internal_updateTwoStepVerificationPassword(network: self.account.network, currentPassword: currentPassword, updatedPassword: updatedPassword)
        }

        public func requestTwoStepVerificationPasswordRecoveryCode() -> Signal<String, RequestTwoStepVerificationPasswordRecoveryCodeError> {
            return _internal_requestTwoStepVerificationPasswordRecoveryCode(network: self.account.network)
        }

        public func checkPasswordRecoveryCode(code: String) -> Signal<Never, PasswordRecoveryError> {
            return _internal_checkPasswordRecoveryCode(network: self.account.network, code: code)
        }

        public func performPasswordRecovery(code: String, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<RecoveredAccountData, PasswordRecoveryError> {
            return _internal_performPasswordRecovery(network: self.account.network, code: code, updatedPassword: updatedPassword)
        }

        public func resendTwoStepRecoveryEmail() -> Signal<Never, ResendTwoStepRecoveryEmailError> {
            return _internal_resendTwoStepRecoveryEmail(network: self.account.network)
        }

        public func uploadedPeerVideo(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerVideo(postbox: self.account.postbox, network: self.account.network, messageMediaPreuploadManager: nil, resource: resource)
        }
        
        public func state() -> Signal<TelegramEngineAuthorizationState?, NoError> {
            return self.account.postbox.stateView()
            |> map { view -> TelegramEngineAuthorizationState? in
                if let state = view.state as? UnauthorizedAccountState {
                    return .unauthorized(state)
                } else if let _ = view.state as? AuthorizedAccountState {
                    return .authorized
                } else {
                    return nil
                }
            }
        }
        
        public func setState(state: UnauthorizedAccountState) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.setState(state)
            }
            |> ignoreValues
        }
    }
}

public enum DeleteAccountError {
    case generic
}

public extension TelegramEngine {
    final class Auth {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func twoStepAuthData() -> Signal<TwoStepAuthData, MTRpcError> {
            return _internal_twoStepAuthData(self.account.network)
        }

        public func updateTwoStepVerificationPassword(currentPassword: String?, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<UpdateTwoStepVerificationPasswordResult, UpdateTwoStepVerificationPasswordError> {
            return _internal_updateTwoStepVerificationPassword(network: self.account.network, currentPassword: currentPassword, updatedPassword: updatedPassword)
        }

        public func deleteAccount(reason: String) -> Signal<Never, DeleteAccountError> {
            return self.account.network.request(Api.functions.account.deleteAccount(reason: reason))
            |> mapError { _ -> DeleteAccountError in
                return .generic
            }
            |> ignoreValues
        }

        public func updateTwoStepVerificationEmail(currentPassword: String, updatedEmail: String) -> Signal<UpdateTwoStepVerificationPasswordResult, UpdateTwoStepVerificationPasswordError> {
            return _internal_updateTwoStepVerificationEmail(network: self.account.network, currentPassword: currentPassword, updatedEmail: updatedEmail)
        }

        public func confirmTwoStepRecoveryEmail(code: String) -> Signal<Never, ConfirmTwoStepRecoveryEmailError> {
            return _internal_confirmTwoStepRecoveryEmail(network: self.account.network, code: code)
        }

        public func resendTwoStepRecoveryEmail() -> Signal<Never, ResendTwoStepRecoveryEmailError> {
        	return _internal_resendTwoStepRecoveryEmail(network: self.account.network)
        }

        public func cancelTwoStepRecoveryEmail() -> Signal<Never, CancelTwoStepRecoveryEmailError> {
        	return _internal_cancelTwoStepRecoveryEmail(network: self.account.network)
        }

        public func twoStepVerificationConfiguration() -> Signal<TwoStepVerificationConfiguration, NoError> {
            return _internal_twoStepVerificationConfiguration(account: self.account)
        }

        public func requestTwoStepVerifiationSettings(password: String) -> Signal<TwoStepVerificationSettings, AuthorizationPasswordVerificationError> {
            return _internal_requestTwoStepVerifiationSettings(network: self.account.network, password: password)
        }

        public func requestTwoStepVerificationPasswordRecoveryCode() -> Signal<String, RequestTwoStepVerificationPasswordRecoveryCodeError> {
            return _internal_requestTwoStepVerificationPasswordRecoveryCode(network: self.account.network)
        }

        public func performPasswordRecovery(code: String, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<RecoveredAccountData, PasswordRecoveryError> {
            return _internal_performPasswordRecovery(network: self.account.network, code: code, updatedPassword: updatedPassword)
        }

        public func cachedTwoStepPasswordToken() -> Signal<TemporaryTwoStepPasswordToken?, NoError> {
            return _internal_cachedTwoStepPasswordToken(postbox: self.account.postbox)
        }

        public func cacheTwoStepPasswordToken(token: TemporaryTwoStepPasswordToken?) -> Signal<Void, NoError> {
            return _internal_cacheTwoStepPasswordToken(postbox: self.account.postbox, token: token)
        }

        public func requestTemporaryTwoStepPasswordToken(password: String, period: Int32, requiresBiometrics: Bool) -> Signal<TemporaryTwoStepPasswordToken, AuthorizationPasswordVerificationError> {
            return _internal_requestTemporaryTwoStepPasswordToken(account: self.account, password: password, period: period, requiresBiometrics: requiresBiometrics)
        }

        public func checkPasswordRecoveryCode(code: String) -> Signal<Never, PasswordRecoveryError> {
            return _internal_checkPasswordRecoveryCode(network: self.account.network, code: code)
        }

        public func requestTwoStepPasswordReset() -> Signal<RequestTwoStepPasswordResetResult, NoError> {
            return _internal_requestTwoStepPasswordReset(network: self.account.network)
        }

        public func declineTwoStepPasswordReset() -> Signal<Never, NoError> {
            return _internal_declineTwoStepPasswordReset(network: self.account.network)
        }

        public func requestCancelAccountResetData(hash: String) -> Signal<CancelAccountResetData, RequestCancelAccountResetDataError> {
            return _internal_requestCancelAccountResetData(network: self.account.network, hash: hash)
        }

        public func requestNextCancelAccountResetOption(phoneNumber: String, phoneCodeHash: String) -> Signal<CancelAccountResetData, RequestCancelAccountResetDataError> {
            return _internal_requestNextCancelAccountResetOption(network: self.account.network, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash)
        }

        public func requestCancelAccountReset(phoneCodeHash: String, phoneCode: String) -> Signal<Never, CancelAccountResetError> {
            return _internal_requestCancelAccountReset(network: self.account.network, phoneCodeHash: phoneCodeHash, phoneCode: phoneCode)
        }
    }
}

public extension SomeTelegramEngine {
    final class Auth {
        private let engine: SomeTelegramEngine

        init(engine: SomeTelegramEngine) {
            self.engine = engine
        }

        public func twoStepAuthData() -> Signal<TwoStepAuthData, MTRpcError> {
            switch self.engine {
            case let .authorized(engine):
                return engine.auth.twoStepAuthData()
            case let .unauthorized(engine):
                return engine.auth.twoStepAuthData()
            }
        }

        public func updateTwoStepVerificationPassword(currentPassword: String?, updatedPassword: UpdatedTwoStepVerificationPassword) -> Signal<UpdateTwoStepVerificationPasswordResult, UpdateTwoStepVerificationPasswordError> {
            switch self.engine {
            case let .authorized(engine):
                return engine.auth.updateTwoStepVerificationPassword(currentPassword: currentPassword, updatedPassword: updatedPassword)
            case let .unauthorized(engine):
                return engine.auth.updateTwoStepVerificationPassword(currentPassword: currentPassword, updatedPassword: updatedPassword)
            }
        }

        public func requestTwoStepVerificationPasswordRecoveryCode() -> Signal<String, RequestTwoStepVerificationPasswordRecoveryCodeError> {
            switch self.engine {
            case let .authorized(engine):
                return engine.auth.requestTwoStepVerificationPasswordRecoveryCode()
            case let .unauthorized(engine):
                return engine.auth.requestTwoStepVerificationPasswordRecoveryCode()
            }
        }

        public func checkPasswordRecoveryCode(code: String) -> Signal<Never, PasswordRecoveryError> {
            switch self.engine {
            case let .authorized(engine):
                return engine.auth.checkPasswordRecoveryCode(code: code)
            case let .unauthorized(engine):
                return engine.auth.checkPasswordRecoveryCode(code: code)
            }
        }
    }

    var auth: Auth {
        return Auth(engine: self)
    }
}
