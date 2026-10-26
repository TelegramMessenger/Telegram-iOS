import PasscodeCore
import Foundation
import CryptoKit
import TelegramCore
import WalletEngineFFI

@available(macOS 10.15, *)
final class WalletLogger: @unchecked Sendable {
    private let sink: (String) -> Void

    init(_ sink: @escaping (String) -> Void) {
        self.sink = sink
    }

    func log(_ message: String) {
        self.sink(message)
    }

    func error(_ event: String, _ error: Error, context: String? = nil) {
        var message = "event=\(event) \(walletContextErrorFields(error))"
        if let context, !context.isEmpty {
            message += " \(context)"
        }
        self.sink(message)
    }
}

@available(macOS 10.15, *)
private func walletContextErrorFields(_ error: Error) -> String {
    let nsError = error as NSError
    var result = "error_type=\(String(reflecting: type(of: error))) error_domain=\(nsError.domain) error_code=\(nsError.code)"
    if let kind = walletContextErrorKind(error) {
        result += " error_kind=\(kind)"
    }
    return result
}

@available(macOS 10.15, *)
private func walletContextErrorKind(_ error: Error) -> String? {
    if let kind = tonConnectErrorKind(error) {
        return kind
    }
    if error is CancellationError {
        return "cancelled"
    }
    if let error = error as? TelegramCore.WalletOperationError {
        switch error {
        case .generic: return "telegram_generic"
        case .network: return "telegram_network"
        case .preflightNetwork: return "telegram_preflight_network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .proofInvalid: return "proof_invalid"
        case .proofExpired: return "proof_expired"
        case .rotationNotFound: return "rotation_not_found"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        }
    }
    if let error = error as? WalletEngineStorageError {
        switch error {
        case .keychainStatus: return "keychain_status"
        case .corrupted: return "storage_corrupted"
        }
    }
    if let error = error as? WalletClientError {
        return "wallet_engine_\(walletEngineErrorCaseName(error))"
    }
    if (error as? WalletSendTransferError) == .keyMismatch { return "wallet_key_mismatch" }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return "unavailable"
        case .noWallet: return "no_wallet"
        case .invalidMnemonic: return "invalid_mnemonic"
        case .invalidAddress: return "invalid_address"
        case .invalidAmount: return "invalid_amount"
        case .operationInProgress: return "operation_in_progress"
        case .previewFailed: return "preview_failed"
        case .previewIncomplete: return "preview_incomplete"
        case .preparedTransferExpired: return "prepared_transfer_expired"
        case .preparedTransferNotFound: return "prepared_transfer_not_found"
        case .walletKeyMismatch: return "wallet_key_mismatch"
        case .recoveryPhraseOutdated: return "recovery_phrase_outdated"
        case .network: return "network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .authorizationCancelled: return "authorization_cancelled"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .proofInvalid: return "proof_invalid"
        case .proofExpired: return "proof_expired"
        case .rotationNotFound: return "rotation_not_found"
        case .keyRotationFailed: return "key_rotation_failed"
        case .backupDisableNeedsConfirmation: return "backup_disable_needs_confirmation"
        case .preparedBackupDisableExpired: return "prepared_backup_disable_expired"
        case .commentTooLong: return "comment_too_long"
        case .commentEncryptionRecipientUnavailable: return "comment_encryption_recipient_unavailable"
        case .commentEncryptionFailed: return "comment_encryption_failed"
        case .commentDecryptionFailed: return "comment_decryption_failed"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        case .insufficientBalance: return "insufficient_balance"
        case .storage: return "storage"
        case .engine: return "engine"
        }
    }
    if let error = error as? TonApiRequestError {
        return "telegram_relay_\(error.code)"
    }
    if let error = error as? URLError {
        return "url_\(error.code.rawValue)"
    }
    return nil
}

@available(macOS 10.15, *)
private func walletEngineErrorCaseName(_ error: WalletClientError) -> String {
    if case .SendAlreadyInProgress = error {
        return "send_already_in_progress"
    }
    if case .SendPreviewAlreadyInProgress = error {
        return "send_preview_already_in_progress"
    }
    let reflected = String(reflecting: error)
    let withoutPayload = reflected.split(separator: "(", maxSplits: 1).first.map(String.init) ?? reflected
    let name = withoutPayload.split(separator: ".").last.map(String.init) ?? withoutPayload
    var result = ""
    for scalar in name.unicodeScalars {
        if CharacterSet.uppercaseLetters.contains(scalar) {
            if !result.isEmpty {
                result.append("_")
            }
            result.append(String(scalar).lowercased())
        } else if CharacterSet.alphanumerics.contains(scalar) {
            result.append(String(scalar).lowercased())
        } else if result.last != "_" {
            result.append("_")
        }
    }
    return result.isEmpty ? "unknown" : result
}

@available(macOS 10.15, *)
func synchronizationError(_ error: DomainError?) -> WalletContext.SynchronizationError {
    guard let error else { return .engine }
    switch error.code {
    case .invalidProviderResponse, .responseTooLarge, .hostPolicyViolation:
        return .invalidData
    case .hostCancelled:
        return .unavailable
    case .rateLimited:
        return .http(statusCode: error.providerStatus.map { Int($0) } ?? 429)
    case .httpRejected:
        return error.providerStatus.map { .http(statusCode: Int($0)) } ?? .network
    case .transportFailed:
        return error.hostKind == .timeout ? .timeout : .network
    }
}

@available(macOS 10.15, *)
func synchronizationError(_ error: Error?) -> WalletContext.SynchronizationError {
    guard let error else { return .engine }
    if error is WalletGetNftsError { return .network }
    if let error = error as? WalletContext.SynchronizationError { return error }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return .unavailable
        case .network: return .network
        case .invalidAddress, .invalidAmount, .invalidMnemonic, .previewIncomplete, .previewFailed: return .invalidData
        default: return .engine
        }
    }
    if let error = error as? URLError {
        return error.code == .timedOut ? .timeout : .network
    }
    return .engine
}

@available(macOS 10.15, *)
func walletError(_ error: Error) -> WalletContext.WalletError {
    if error is WalletGetNftsError { return .network }
    if let value = error as? PasscodeError {
        switch value {
        case .cancelled, .staleAuthorization: return .authorizationCancelled
        default: return .unavailable
        }
    }
    if let value = error as? WalletContext.WalletError { return value }
    if let value = error as? WalletClientError {
        switch value {
        case let .InsufficientBalance(_, requestedNanograms):
            return .insufficientBalance(required: Int64(requestedNanograms) ?? Int64.max)
        case let .InsufficientBalanceForFees(_, requestedNanograms, estimatedFeeNanograms):
            let amount = Int64(requestedNanograms) ?? Int64.max
            let fee = Int64(estimatedFeeNanograms) ?? Int64.max
            let (required, overflow) = amount.addingReportingOverflow(fee)
            return .insufficientBalance(required: overflow ? Int64.max : required)
        default:
            break
        }
    }
    if (error as? WalletSendTransferError) == .keyMismatch { return .walletKeyMismatch }
    if let value = error as? TonConnectFailure { return .engine(value.message) }
    if let value = error as? WalletContext.SynchronizationError {
        switch value {
        case .network, .timeout, .http: return .network
        case .unavailable: return .unavailable
        case .invalidData: return .engine("wallet-engine returned invalid resource data")
        case .engine: return .engine("wallet-engine resource update failed")
        }
    }
    if let value = error as? TelegramCore.WalletOperationError {
        switch value {
        case .generic: return .unavailable
        case .network: return .network
        case .preflightNetwork: return .network
        case .requestPassword: return .requestPassword
        case .invalidPassword: return .invalidPassword
        case .twoStepAuthMissing: return .twoStepAuthMissing
        case let .passwordTooFresh(timeout): return .passwordTooFresh(timeout)
        case let .sessionTooFresh(timeout): return .sessionTooFresh(timeout)
        case .backupDisabled: return .backupDisabled
        case .backupNotAvailable: return .backupNotAvailable
        case .replacementInvalid: return .replacementInvalid
        case .publicKeyInvalid: return .publicKeyInvalid
        case .proofInvalid: return .proofInvalid
        case .proofExpired: return .proofExpired
        case .rotationNotFound: return .rotationNotFound
        case .tokenInvalid: return .tokenInvalid
        case .tokenExpired: return .tokenExpired
        case .clientKeyInvalid: return .clientKeyInvalid
        case .partUnavailable: return .partUnavailable
        case .invalidBackupData: return .invalidBackupData
        }
    }
    if error is URLError || error is TonApiRequestError { return .network }
    return .engine(sanitizedWalletEngineDiagnostic(String(describing: error)))
}

@available(macOS 10.15, *)
extension WalletLogger {
    func tonConnect(_ stage: String, requestId: String, session: WalletTonConnectSession?, traceId: String?, eventId: Int64?, walletClientId: String? = nil, body: Data? = nil, outcome: String? = nil, error: Error? = nil) {
        func quoted(_ value: String) -> String {
            String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
        }
        var fields = ["stage=\(stage)", "request_id=\(quoted(requestId))"]
        if let session {
            fields.append("session_id=\(session.id)")
            fields.append("dapp_client_id=\(quoted(session.dappClientId))")
            if let code = session.manifestError { fields.append("manifest_error=\(code)") }
        }
        if let key = walletClientId ?? session?.clientId { fields.append("wallet_client_id=\(quoted(key))") }
        if let traceId { fields.append("trace_id=\(quoted(traceId))") }
        if let eventId { fields.append("event_id=\(eventId)") }
        if let body {
            fields.append("body_bytes=\(body.count)")
            fields.append("body_sha256=\(SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())")
        }
        if let outcome { fields.append("outcome=\(quoted(outcome))") }
        if let error = error as? WalletTonConnectError, case let .rpc(code, _) = error {
            fields.append("rpc_code=\(code)")
        }
        let context = fields.joined(separator: " ")
        if let error {
            self.error("ton_connect", error, context: context)
        } else {
            self.log("event=ton_connect \(context)")
        }
    }
}

@available(macOS 10.15, *)
func tonConnectErrorKind(_ error: Error) -> String? {
    if let error = error as? TonConnectFailure {
        switch error {
        case .unavailable: return "ton_connect_unavailable"
        case .invalidLink: return "ton_connect_invalid_link"
        case .conflictingLink: return "ton_connect_conflicting_link"
        case .invalidManifest: return "ton_connect_invalid_manifest"
        case .wrongNetwork: return "ton_connect_wrong_network"
        case .bridgeUnavailable: return "ton_connect_bridge_unavailable"
        case .outcomeUnknown: return "ton_connect_outcome_unknown"
        case .keyMismatch: return "ton_connect_key_mismatch"
        case .expired: return "ton_connect_expired"
        case .handledElsewhere: return "ton_connect_handled_elsewhere"
        }
    }
    if error is TonConnectSessionError { return "ton_connect_session_failed" }
    if let error = error as? WalletLifecycleError {
        switch error {
        case .InvalidTonConnectSessionInput: return "ton_connect_invalid_session_input"
        case .SecretWalletMismatch: return "ton_connect_key_mismatch"
        case .TonConnectSigningFailed: return "ton_connect_signing_failed"
        default: break
        }
    }
    if let error = error as? WalletTonConnectError {
        switch error {
        case .badRequestId: return "ton_connect_bad_request_id"
        case .invalidPayload: return "ton_connect_invalid_payload"
        case let .rpc(_, description):
            // Arbitrary RPC descriptions may contain request data.
            switch description {
            case "TONCONNECT_DAPP_CLIENT_ID_INVALID", "TONCONNECT_MANIFEST_URL_INVALID",
                 "TONCONNECT_SESSION_NOT_FOUND", "TONCONNECT_SESSION_CLOSED", "TONCONNECT_SESSION_NOT_ACTIVE",
                 "TONCONNECT_CLIENT_ID_INVALID", "TONCONNECT_CLIENT_ID_OCCUPIED", "TONCONNECT_CHALLENGE_INVALID",
                 "TONCONNECT_BODY_INVALID", "TONCONNECT_LOOKUP_INVALID", "TONCONNECT_REQUEST_NOT_FOUND",
                 "TONCONNECT_REQUEST_EXPIRED", "TONCONNECT_REQUEST_ALREADY_CLAIMED", "TONCONNECT_BAD_REQUEST_ID":
                return "ton_connect_rpc_" + description.dropFirst("TONCONNECT_".count).lowercased()
            default: return "ton_connect_rpc"
            }
        }
    }
    if let error = error as? TonConnectWireFailure {
        switch error.code {
        case .unknown: return "ton_connect_wire_unknown"
        case .badRequest: return "ton_connect_wire_bad_request"
        case .manifestNotFound: return "ton_connect_wire_manifest_not_found"
        case .invalidManifest: return "ton_connect_wire_invalid_manifest"
        case .unknownApp: return "ton_connect_wire_unknown_app"
        case .userDeclined: return "ton_connect_wire_user_declined"
        case .methodNotSupported: return "ton_connect_wire_method_not_supported"
        }
    }
    return nil
}
