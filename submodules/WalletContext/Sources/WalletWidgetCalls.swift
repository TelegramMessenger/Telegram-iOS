import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

// A message widget's wallet calls (widget-sandbox v0.5.0, sdk-v1 §2.18, §5.13): TON Connect's formats without TON
// Connect's session. The bot that sent the message asks; the user confirms in the TON Connect window with the bot in its
// header. A transaction goes out the wallet's own way, a prepared transfer of all its messages sent by `submitTransfer`
// (`wallet.sendTransfer`), and its message hash is the server's. A signature is TON Connect's `signData` for the domain
// `bot<bot_id>`.

@available(macOS 10.15, *)
public extension WalletContext {
    /// Who asks: the bot of the widget's message (never what the widget says about itself).
    struct WidgetWalletRequester: Equatable, Sendable {
        public let botId: Int64
        public let name: String
        public let username: String?

        public init(botId: Int64, name: String, username: String?) {
            self.botId = botId
            self.name = name
            self.username = username
        }

        /// TON Connect's `signData` domain for a widget (sdk-v1 §2.18): the client signs for `bot<bot_id>`.
        public var signDomain: String {
            return "bot\(self.botId)"
        }

        /// The request's `domain`: `@username`, the part a bot cannot choose, or the name when it has none. The window
        /// names the bot from its peer instead (`WalletRequesterLineComponent`: the name, then the username, which never
        /// gives way to it).
        public var displayDomain: String {
            return self.username.map { "@\($0)" } ?? self.name
        }
    }

    /// What the widget's promise rejects with for a wallet call that did not reach its bot (sdk-v1 §2.18): the user
    /// declined (`REJECTED`), the wallet refused it (`BAD_REQUEST`), or anything else (`FAILED`). A balance short of the
    /// transaction and its fees is the wallet's refusal too, after the client offers the top-up (§5.13).
    enum WidgetWalletFailure: Error, Equatable, Sendable {
        case rejected
        case badRequest
        case insufficientBalance
        case failed
    }

    /// A transaction the wallet prepared, ready for the window (`request`) and, confirmed, for `submitWidgetTransaction`.
    struct WidgetPreparedTransaction: Equatable, Sendable {
        public let request: TonConnectOperationRequest
        let transfer: PreparedTransfer
    }

    /// A transaction the server accepted: its message hash as the server returned it, and the wallet for the bot's query.
    struct WidgetSentTransaction: Equatable {
        public let msgHash: String
        public let wallet: EngineUserWallet
    }

    /// A payload the wallet can sign, ready for the window (`request`) and, confirmed, for `signWidgetData`.
    struct WidgetPreparedSignData: Equatable, Sendable {
        public let request: TonConnectOperationRequest
        let payload: TonConnectSignDataPayload
        let payloadJson: String
        let requester: WidgetWalletRequester
        let identity: TonConnectWalletIdentity
    }

    /// TON Connect's `signData` result as JSON, and the wallet with what verifies it, for the bot's query.
    struct WidgetSignedData: Equatable {
        public let responseJson: String
        public let wallet: EngineUserWallet
    }

    /// Before the window: the user's cancelled passcode is a decline; the balance is the top-up's; the wallet's other
    /// refusals of the transaction or the payload (expiry, network or sender, destinations, amounts, cells, a preview it
    /// could not make) are BAD_REQUEST; anything else (no wallet, another operation, the network) FAILED.
    /// `previewIncomplete` no longer comes from a widget's transaction (the window shows an incomplete emulation's
    /// warning, as for a dApp) and keeps its mapping for any other path.
    static func widgetPrepareFailure(_ error: WalletError) -> WidgetWalletFailure {
        switch error {
        case .authorizationCancelled:
            return .rejected
        case .insufficientBalance:
            return .insufficientBalance
        case .preparedTransferExpired, .walletKeyMismatch, .invalidAddress, .invalidAmount, .previewFailed, .previewIncomplete, .engine:
            return .badRequest
        default:
            return .failed
        }
    }

    /// After the confirmation: the user's cancelled passcode is a decline; the balance is the top-up's; only an expiry
    /// passed meanwhile is still the wallet's refusal; anything else FAILED (whether the transfer went out is the bot's
    /// to tell).
    static func widgetSubmitFailure(_ error: WalletError) -> WidgetWalletFailure {
        switch error {
        case .authorizationCancelled:
            return .rejected
        case .insufficientBalance:
            return .insufficientBalance
        case .preparedTransferExpired:
            return .badRequest
        default:
            return .failed
        }
    }

    /// Whether this device can sign for the user's wallet now (the client passes `context.wallet` only then).
    var widgetWalletReady: Signal<Bool, NoError> {
        return self.state
        |> map { state -> Bool in
            if case let .wallet(info) = state.phase {
                return info.canSign
            }
            return false
        }
        |> distinctUntilChanged
    }

    /// Checks the widget's transaction (TON Connect's `sendTransaction` request, as the runtime checked it) against this
    /// wallet, emulates it and prepares it as a transfer of the wallet's own; the window's request names the requester.
    func prepareWidgetTransaction(json: String, requester: WidgetWalletRequester) -> Signal<WidgetPreparedTransaction, WidgetWalletFailure> {
        return self.signal(
            name: "preparing_widget_transaction",
            discardResult: { [impl = self.impl] prepared in
                Task { await impl.discardPreparedTransfer(prepared.transfer) }
            }
        ) { impl, operationId in
            try await impl.prepareWidgetTransaction(json: json, requester: requester, operationId: operationId)
        }
        |> mapError { WalletContext.widgetPrepareFailure($0) }
    }

    /// The user declined: the prepared transfer is dropped.
    func discardWidgetTransaction(_ prepared: WidgetPreparedTransaction) {
        let _ = self.discardPreparedTransfer(prepared.transfer).start()
    }

    /// Sends a confirmed transaction through the wallet's transfer path (`wallet.sendTransfer`; the wallet's passcode if
    /// protection is on) and yields the server's message hash with the wallet's card.
    func submitWidgetTransaction(_ prepared: WidgetPreparedTransaction) -> Signal<WidgetSentTransaction, WidgetWalletFailure> {
        return self.submitTransfer(prepared.transfer)
        |> mapError { WalletContext.widgetSubmitFailure($0) }
        |> mapToSignal { [weak self] pending -> Signal<WidgetSentTransaction, WidgetWalletFailure> in
            guard let self, let msgHash = pending.sentTransfer?.msgHash, !msgHash.isEmpty else {
                return .fail(.failed)
            }
            return self.state
            |> take(1)
            |> castError(WidgetWalletFailure.self)
            |> mapToSignal { state -> Signal<WidgetSentTransaction, WidgetWalletFailure> in
                guard case let .wallet(info) = state.phase else {
                    return .fail(.failed)
                }
                return .single(WidgetSentTransaction(msgHash: msgHash, wallet: EngineUserWallet(address: info.address, balance: state.balance.currentValue ?? 0, signing: nil)))
            }
        }
    }

    /// Checks the widget's payload (TON Connect's `signData`, as the runtime checked it) against this wallet; the window's
    /// request names the requester.
    func prepareWidgetSignData(json: String, requester: WidgetWalletRequester) -> Signal<WidgetPreparedSignData, WidgetWalletFailure> {
        return self.signal(name: "preparing_widget_sign_data") { impl, _ in
            try await impl.prepareWidgetSignData(json: json, requester: requester)
        }
        |> mapError { WalletContext.widgetPrepareFailure($0) }
    }

    /// Signs a confirmed payload for `bot<bot_id>` (the wallet's passcode if protection is on) and yields TON Connect's
    /// result with the wallet's card, its public key and StateInit included.
    func signWidgetData(_ prepared: WidgetPreparedSignData) -> Signal<WidgetSignedData, WidgetWalletFailure> {
        return self.signal(name: "signing_widget_data") { impl, operationId in
            try await impl.signWidgetData(prepared, operationId: operationId)
        }
        |> mapError { WalletContext.widgetSubmitFailure($0) }
        |> map { signed -> WidgetSignedData in
            return WidgetSignedData(responseJson: signed.responseJson, wallet: EngineUserWallet(address: signed.address, balance: signed.balance,
                signing: EngineUserWallet.Signing(publicKey: signed.publicKey, stateInit: signed.stateInit)))
        }
    }
}

/// What `signWidgetData` gets from the wallet (Sendable, unlike TelegramCore's card).
@available(macOS 10.15, *)
struct WidgetSignedResult: Equatable, Sendable {
    let responseJson: String
    let address: String
    let balance: Int64
    let publicKey: Data
    let stateInit: Data
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func prepareWidgetTransaction(json: String, requester: WalletContext.WidgetWalletRequester, operationId: UUID) async throws -> WalletContext.WidgetPreparedTransaction {
        return try await self.performOperation(.preparingTransfer, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            let parsed = try widgetTransactionIntent(json: json, now: Int64(currentWalletTimestamp()), walletAddress: info.address)
            // The engine refuses a balance short of the total and its fees here (`insufficientBalance`, the top-up's).
            let preview = try await self.runtime.previewSend(intent: parsed.intent)
            try Task.checkCancellation()
            // As for a dApp (sdk-v1 §5.13, "the client's existing TON Connect window"): an emulation whose trace failed
            // or did not finish is shown with the window's warning (`tonConnectOperation`), the wallet's own fee kept.
            guard let fee = Int64(preview.emulation.walletFeesNanograms) else {
                throw WalletError.previewFailed
            }
            if let balance = self.currentState.balance.currentValue, parsed.total > balance || fee > balance - parsed.total {
                let (required, overflow) = parsed.total.addingReportingOverflow(fee)
                throw WalletError.insufficientBalance(required: overflow ? Int64.max : required)
            }
            let transfer = PreparedTransfer(
                id: UUID().uuidString.lowercased(),
                recipient: parsed.firstDestination,
                amount: parsed.total,
                comment: nil,
                fee: fee,
                expiresAt: Int32(clamping: preview.validUntil)
            )
            self.preparedTransfers[transfer.id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .send(parsed.intent),
                allowsGasless: false
            )
            self.removeExpiredPreparedTransfers()
            let request = Self.tonConnectOperation(id: transfer.id, applicationName: requester.name, domain: requester.displayDomain, icon: nil, preview: preview)
            return WalletContext.WidgetPreparedTransaction(request: request, transfer: transfer)
        }
    }

    func prepareWidgetSignData(json: String, requester: WalletContext.WidgetWalletRequester) async throws -> WalletContext.WidgetPreparedSignData {
        guard case let .wallet(info) = self.currentState.phase, info.canSign else {
            throw WalletError.unavailable
        }
        let engineRequest = try widgetSignDataRequest(json: json, walletAddress: info.address)
        let payload: TonConnectSignDataPayload
        do {
            payload = try TonConnectSignDataPayload(engineRequest)
        } catch {
            throw WalletError.previewFailed
        }
        let identity = try await self.runtime.tonConnectIdentity()
        let signData = WalletContext.TonConnectSignDataRequest(id: UUID().uuidString.lowercased(), applicationName: requester.name,
            domain: requester.displayDomain, icon: nil, payload: payload.content, address: identity.address, network: identity.network)
        let request = WalletContext.TonConnectOperationRequest(id: signData.id, applicationName: requester.name, domain: requester.displayDomain,
            icon: nil, method: .signData, messages: [], feeNanograms: nil, validUntil: nil, relayerWillSubmit: false, needsWalletStateInit: false,
            warnings: [], actions: [], signData: signData)
        return WalletContext.WidgetPreparedSignData(request: request, payload: payload, payloadJson: json, requester: requester, identity: identity)
    }

    func signWidgetData(_ prepared: WalletContext.WidgetPreparedSignData, operationId: UUID) async throws -> WidgetSignedResult {
        return try await self.performOperation(.tonConnect, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            let signed = try await self.runtime.signTonConnectData(prepared.payload, domain: prepared.requester.signDomain,
                timestamp: UInt64(max(0, self.tonConnectNow)), wallet: prepared.identity)
            let account = try await self.runtime.tonConnectAccount(wallet: prepared.identity)
            guard let stateInit = Data(base64Encoded: account.walletStateInit) else {
                throw WalletError.engine("wallet-engine returned a StateInit that is not base64")
            }
            let response = widgetSignDataResponse(signature: Data(signed.signature), rawAddress: account.address, timestamp: signed.timestamp,
                domain: signed.domain, payloadJson: prepared.payloadJson)
            return WidgetSignedResult(responseJson: response, address: info.address, balance: self.currentState.balance.currentValue ?? 0,
                publicKey: Data(signed.publicKey), stateInit: stateInit)
        }
    }
}

/// A widget's transaction as the engine's send intent, its total and its first destination (the pending transfer's).
@available(macOS 10.15, *)
struct WidgetTransactionIntent: Equatable {
    let intent: SendIntent
    let total: Int64
    let firstDestination: String
}

/// TON Connect's `sendTransaction` request, as the widget's runtime checked it (sdk-v1 §2.18), checked against the wallet
/// as a TON Connect wallet checks it, as the engine's intent: an expired `valid_until` (`preparedTransferExpired`),
/// another network than the mainnet or another sender than `walletAddress` (`walletKeyMismatch`), a destination that is
/// not a mainnet address (`invalidAddress`), amounts past what the wallet can hold (`invalidAmount`), cells that are not
/// base64 (`previewFailed`). Each destination keeps its bounce flag; payloads and StateInits become standard base64.
@available(macOS 10.15, *)
func widgetTransactionIntent(json: String, now: Int64, walletAddress: String) throws -> WidgetTransactionIntent {
    guard let object = widgetJSONObject(json) else {
        throw WalletContext.WalletError.previewFailed
    }
    var expiration: SendExpiration = .engineDefault
    if let validUntil = (object["valid_until"] as? NSNumber)?.int64Value {
        guard validUntil > now else {
            throw WalletContext.WalletError.preparedTransferExpired
        }
        expiration = .exact(unixTimestamp: UInt64(validUntil))
    }
    try widgetCheckTarget(object, walletAddress: walletAddress)
    guard let list = object["messages"] as? [[String: Any]], !list.isEmpty else {
        throw WalletContext.WalletError.previewFailed
    }
    var total: Int64 = 0
    var messages: [SendMessage] = []
    for message in list {
        guard let address = message["address"] as? String, let amount = message["amount"] as? String else {
            throw WalletContext.WalletError.previewFailed
        }
        let destination = try WalletTransferDestination(address)
        guard let value = Int64(amount), value >= 0 else {
            throw WalletContext.WalletError.invalidAmount
        }
        let (sum, overflow) = total.addingReportingOverflow(value)
        guard !overflow else {
            throw WalletContext.WalletError.invalidAmount
        }
        total = sum
        let body: SendMessageBody = try (message["payload"] as? String).map { .rawPayload(boc: try widgetBase64($0)) } ?? .empty
        let stateInit = try (message["stateInit"] as? String).map(widgetBase64)
        messages.append(SendMessage(destination: destination.address, amount: .exact(nanograms: amount), body: body, bounce: destination.bounce, stateInit: stateInit))
    }
    return WidgetTransactionIntent(intent: SendIntent(expiration: expiration, messages: messages), total: total, firstDestination: messages[0].destination)
}

/// TON Connect's `signData` payload, as the widget's runtime checked it, checked against the wallet (network, sender) as
/// the engine's request.
@available(macOS 10.15, *)
func widgetSignDataRequest(json: String, walletAddress: String) throws -> WalletEngineFFI.TonConnectSignDataRequest {
    guard let object = widgetJSONObject(json) else {
        throw WalletContext.WalletError.previewFailed
    }
    try widgetCheckTarget(object, walletAddress: walletAddress)
    let payload: WalletEngineFFI.TonConnectSignDataPayload
    switch object["type"] as? String {
    case "text":
        guard let text = object["text"] as? String else {
            throw WalletContext.WalletError.previewFailed
        }
        payload = .text(text: text)
    case "binary":
        guard let bytes = object["bytes"] as? String else {
            throw WalletContext.WalletError.previewFailed
        }
        payload = .binary(bytes: bytes)
    case "cell":
        guard let schema = object["schema"] as? String, let cell = object["cell"] as? String else {
            throw WalletContext.WalletError.previewFailed
        }
        payload = .cell(schema: schema, cell: cell)
    default:
        throw WalletContext.WalletError.previewFailed
    }
    return WalletEngineFFI.TonConnectSignDataRequest(payload: payload, network: object["network"] as? String, from: object["from"] as? String)
}

/// TON Connect's `signData` result (`SignDataResponse`): the signature in standard base64, the wallet's raw address, the
/// timestamp, the domain and the payload as the widget sent it.
func widgetSignDataResponse(signature: Data, rawAddress: String, timestamp: UInt64, domain: String, payloadJson: String) -> String {
    let payload: Any = (try? JSONSerialization.jsonObject(with: Data(payloadJson.utf8))) ?? payloadJson
    let object: [String: Any] = [
        "signature": signature.base64EncodedString(),
        "address": rawAddress,
        "timestamp": NSNumber(value: timestamp),
        "domain": domain,
        "payload": payload,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
        return "{}"
    }
    return String(decoding: data, as: UTF8.self)
}

/// The mainnet only (the engine's), and this wallet as the sender, raw or user-friendly.
@available(macOS 10.15, *)
private func widgetCheckTarget(_ object: [String: Any], walletAddress: String) throws {
    if let network = object["network"] as? String, network != "-239" {
        throw WalletContext.WalletError.walletKeyMismatch
    }
    if let from = object["from"] as? String, !walletEngineAddressesEqual(from, walletAddress) {
        throw WalletContext.WalletError.walletKeyMismatch
    }
}

private func widgetJSONObject(_ json: String) -> [String: Any]? {
    return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
}

/// Base64 or base64url, padded or not, as standard padded base64; `previewFailed` otherwise.
private func widgetBase64(_ value: String) throws -> String {
    var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while normalized.hasSuffix("=") {
        normalized.removeLast()
    }
    normalized += String(repeating: "=", count: (4 - normalized.utf8.count % 4) % 4)
    guard let data = Data(base64Encoded: normalized) else {
        throw WalletContext.WalletError.previewFailed
    }
    return data.base64EncodedString()
}
