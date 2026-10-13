import Foundation
import MtProtoKit
import Postbox
import SwiftSignalKit
import TelegramApi

public struct WalletTonConnectIcon: Equatable, Codable, Sendable {
    public let url: String
    public let accessHash: Int64
    public let size: Int32
    public let mimeType: String

    public init(url: String, accessHash: Int64, size: Int32, mimeType: String) {
        self.url = url
        self.accessHash = accessHash
        self.size = size
        self.mimeType = mimeType
    }
}

public struct WalletTonConnectManifest: Equatable, Codable, Sendable {
    public let url: String
    public let name: String
    public let icon: WalletTonConnectIcon?

    public init(url: String, name: String, icon: WalletTonConnectIcon?) {
        self.url = url
        self.name = name
        self.icon = icon
    }
}

public struct WalletTonConnectSession: Equatable, Codable, Sendable {
    public let flags: Int32
    public let id: Int64
    public let dappClientId: String
    public let clientId: String?
    public let nonce: Data
    public let manifest: WalletTonConnectManifest?
    public let manifestError: Int32?
    public let date: Int32

    public var isPending: Bool {
        return self.flags & (1 << 0) != 0
    }

    public var isClosing: Bool {
        return self.flags & (1 << 1) != 0
    }

    public var isClosed: Bool {
        return self.flags & (1 << 2) != 0
    }

    public var isActive: Bool {
        return self.flags & 7 == 0
    }

    public init(flags: Int32, id: Int64, dappClientId: String, clientId: String?, nonce: Data, manifest: WalletTonConnectManifest?, manifestError: Int32?, date: Int32) {
        self.flags = flags
        self.id = id
        self.dappClientId = dappClientId
        self.clientId = clientId
        self.nonce = nonce
        self.manifest = manifest
        self.manifestError = manifestError
        self.date = date
    }
}

public struct WalletTonConnectRequest: Equatable, Codable, Sendable {
    public let flags: Int32
    public let sessionId: Int64
    public let msgId: Int32
    public let body: Data
    public let expires: Int32
    public let topic: String?
    public let traceId: String?

    public init(flags: Int32, sessionId: Int64, msgId: Int32, body: Data, expires: Int32, topic: String?, traceId: String?) {
        self.flags = flags
        self.sessionId = sessionId
        self.msgId = msgId
        self.body = body
        self.expires = expires
        self.topic = topic
        self.traceId = traceId
    }
}

public struct WalletTonConnectChallenge: Equatable, Sendable {
    public let challenge: Data
    public let eventId: Int64

    public init(challenge: Data, eventId: Int64) {
        self.challenge = challenge
        self.eventId = eventId
    }
}

public struct WalletTonConnectPending: Equatable, Sendable {
    public let session: WalletTonConnectSession
    public let requests: [WalletTonConnectRequest]

    public init(session: WalletTonConnectSession, requests: [WalletTonConnectRequest]) {
        self.session = session
        self.requests = requests
    }
}

/// The protocol requires exactly one lookup discriminator.
public enum WalletTonConnectLookup: Equatable, Sendable {
    case dappClientId(String)
    case sessionId(Int64)
}

public enum WalletTonConnectError: Error, Equatable, Sendable {
    case badRequestId
    case invalidPayload
    case rpc(code: Int32, description: String)

    public init(code: Int32, description: String) {
        if description == "TONCONNECT_BAD_REQUEST_ID" || description == "BAD_REQUEST_ID" {
            self = .badRequestId
        } else {
            self = .rpc(code: code, description: description)
        }
    }
}

public struct WalletTonConnectRequestMessage: Equatable {
    public let messageId: MessageId
    public let flags: Int32
    public let sessionId: Int64
    public let expires: Int32
    public let topic: String?
    public let traceId: String?
    public let dappName: String?

    public var msgId: Int32 {
        return self.messageId.id
    }

    public var isAccepted: Bool {
        return self.flags & (1 << 2) != 0
    }

    public var isDeclined: Bool {
        return self.flags & (1 << 3) != 0
    }

    public init(messageId: MessageId, flags: Int32, sessionId: Int64, expires: Int32, topic: String?, traceId: String?, dappName: String? = nil) {
        self.messageId = messageId
        self.flags = flags
        self.sessionId = sessionId
        self.expires = expires
        self.topic = topic
        self.traceId = traceId
        self.dappName = dappName
    }
}

public enum WalletTonConnectEvent: Equatable {
    case session(WalletTonConnectSession)
    case request(WalletTonConnectRequestMessage)
    case pendingDisconnect(sessionIds: [Int64])
}

extension WalletTonConnectManifest {
    init(apiManifest: Api.TonConnectManifest) {
        switch apiManifest {
        case let .tonConnectManifest(data):
            let icon: WalletTonConnectIcon?
            if case let .webDocument(document)? = data.icon, document.size > 0, document.size <= 2 * 1024 * 1024,
               document.mimeType.lowercased().hasPrefix("image/") {
                icon = WalletTonConnectIcon(url: document.url, accessHash: document.accessHash, size: document.size, mimeType: document.mimeType)
            } else {
                icon = nil
            }
            self.init(url: data.url, name: data.name, icon: icon)
        }
    }
}

extension WalletTonConnectSession {
    init(apiSession: Api.TonConnectSession) {
        switch apiSession {
        case let .tonConnectSession(data):
            self.init(flags: data.flags, id: data.id, dappClientId: data.dappClientId, clientId: data.clientId, nonce: data.nonce.makeData(), manifest: data.manifest.map(WalletTonConnectManifest.init(apiManifest:)), manifestError: data.manifestError, date: data.date)
        }
    }
}

extension WalletTonConnectRequest {
    init(apiRequest: Api.TonConnectRequest) {
        switch apiRequest {
        case let .tonConnectRequest(data):
            self.init(flags: data.flags, sessionId: data.sessionId, msgId: data.msgId, body: data.body.makeData(), expires: data.expires, topic: data.topic, traceId: data.traceId)
        }
    }
}

extension WalletTonConnectChallenge {
    init(apiChallenge: Api.wallet.TonConnectChallenge) {
        switch apiChallenge {
        case let .tonConnectChallenge(data):
            self.init(challenge: data.challenge.makeData(), eventId: data.eventId)
        }
    }
}

extension WalletTonConnectPending {
    init(apiPending: Api.wallet.TonConnectPending) {
        switch apiPending {
        case let .tonConnectPending(data):
            self.init(session: WalletTonConnectSession(apiSession: data.session), requests: data.requests.map(WalletTonConnectRequest.init(apiRequest:)))
        }
    }
}

func _internal_walletTonConnectCreateSession(account: Account, dappClientId: String, manifestUrl: String) -> Signal<WalletTonConnectSession, WalletTonConnectError> {
    return account.network.request(Api.functions.wallet.tonConnectCreateSession(dappClientId: dappClientId, manifestUrl: manifestUrl), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map(WalletTonConnectSession.init(apiSession:))
}

func _internal_walletTonConnectRegisterKey(account: Account, sessionId: Int64, clientId: String) -> Signal<WalletTonConnectChallenge, WalletTonConnectError> {
    return account.network.request(Api.functions.wallet.tonConnectRegisterKey(sessionId: sessionId, clientId: clientId), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map(WalletTonConnectChallenge.init(apiChallenge:))
}

func _internal_walletTonConnectSubmitConnectResult(account: Account, sessionId: Int64, challengeAnswer: Data, body: Data, isError: Bool, traceId: String?) -> Signal<Bool, WalletTonConnectError> {
    guard body.count <= 1_048_576, (traceId?.count ?? 0) <= 100 else {
        return .fail(.invalidPayload)
    }

    var flags: Int32 = 0
    if isError {
        flags |= 1 << 0
    }
    if traceId != nil {
        flags |= 1 << 1
    }

    return account.network.request(Api.functions.wallet.tonConnectSubmitConnectResult(flags: flags, sessionId: sessionId, challengeAnswer: Buffer(data: challengeAnswer), body: Buffer(data: body), traceId: traceId), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case .boolTrue:
            return true
        case .boolFalse:
            return false
        }
    }
}

func _internal_walletTonConnectGetPending(account: Account, lookup: WalletTonConnectLookup) -> Signal<WalletTonConnectPending, WalletTonConnectError> {
    var flags: Int32 = 0
    let dappClientId: String?
    let sessionId: Int64?
    switch lookup {
    case let .dappClientId(value):
        flags |= 1 << 0
        dappClientId = value
        sessionId = nil
    case let .sessionId(value):
        flags |= 1 << 1
        dappClientId = nil
        sessionId = value
    }

    return account.network.request(Api.functions.wallet.tonConnectGetPending(flags: flags, dappClientId: dappClientId, sessionId: sessionId), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map(WalletTonConnectPending.init(apiPending:))
}

func _internal_walletTonConnectClaimRequest(account: Account, sessionId: Int64, msgId: Int32, appRequestId: String, challengeAnswer: Data?, declined: Bool) -> Signal<Bool, WalletTonConnectError> {
    guard (1 ... 100).contains(appRequestId.utf8.count), appRequestId.utf8.allSatisfy({ (0x20 ... 0x7e).contains($0) }) else {
        return .fail(.badRequestId)
    }

    var flags: Int32 = 0
    if challengeAnswer != nil {
        flags |= 1 << 0
    }
    if declined {
        flags |= 1 << 1
    }

    return account.network.request(Api.functions.wallet.tonConnectClaimRequest(flags: flags, sessionId: sessionId, msgId: msgId, appRequestId: appRequestId, challengeAnswer: challengeAnswer.map { Buffer(data: $0) }), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case .boolTrue:
            return true
        case .boolFalse:
            return false
        }
    }
}

func _internal_walletTonConnectSubmitResponse(account: Account, sessionId: Int64, msgId: Int32, body: Data, traceId: String?) -> Signal<Bool, WalletTonConnectError> {
    guard body.count <= 1_048_576, (traceId?.count ?? 0) <= 100 else {
        return .fail(.invalidPayload)
    }

    var flags: Int32 = 0
    if traceId != nil {
        flags |= 1 << 0
    }

    return account.network.request(Api.functions.wallet.tonConnectSubmitResponse(flags: flags, sessionId: sessionId, msgId: msgId, body: Buffer(data: body), traceId: traceId), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case .boolTrue:
            return true
        case .boolFalse:
            return false
        }
    }
}

func _internal_walletTonConnectNextEventId(account: Account, sessionId: Int64) -> Signal<Int64, WalletTonConnectError> {
    return account.network.request(Api.functions.wallet.tonConnectNextEventId(sessionId: sessionId), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case let .tonConnectNextEventId(data):
            return data.eventId
        }
    }
}

func _internal_walletTonConnectCloseSession(account: Account, sessionId: Int64, body: Data? = nil) -> Signal<Bool, WalletTonConnectError> {
    guard (body?.count ?? 0) <= 1_048_576 else {
        return .fail(.invalidPayload)
    }

    let flags: Int32 = body == nil ? 0 : 1 << 0
    return account.network.request(Api.functions.wallet.tonConnectCloseSession(flags: flags, sessionId: sessionId, body: body.map { Buffer(data: $0) }), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case .boolTrue:
            return true
        case .boolFalse:
            return false
        }
    }
}

func _internal_walletTonConnectGetSessions(account: Account) -> Signal<[WalletTonConnectSession], WalletTonConnectError> {
    return account.network.request(Api.functions.wallet.tonConnectGetSessions(), automaticFloodWait: false)
    |> mapError { error in
        return WalletTonConnectError(code: error.errorCode, description: error.errorDescription ?? "")
    }
    |> map { result in
        switch result {
        case let .tonConnectSessions(data):
            return data.sessions.map(WalletTonConnectSession.init(apiSession:))
        }
    }
}

/// Collected during replay, before notification filtering, for both additions and edits.
func walletTonConnectEvents(operation: AccountStateMutationOperation) -> [WalletTonConnectEvent] {
    let messages: [StoreMessage]
    switch operation {
    case let .UpdateWalletTonConnectEvent(event):
        return [event]
    case let .AddMessages(updatedMessages, _):
        messages = updatedMessages
    case let .EditMessage(_, message):
        messages = [message]
    default:
        return []
    }

    let servicePeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
    var events: [WalletTonConnectEvent] = []
    for message in messages {
        guard case let .Id(id) = message.id,
              id.namespace == Namespaces.Message.Cloud,
              id.peerId == servicePeerId,
              message.authorId == servicePeerId,
              message.flags.contains(.Incoming) else {
            continue
        }
        for media in message.media {
            if let action = media as? TelegramMediaAction,
               case let .walletTonConnectRequest(flags, sessionId, expires, topic, traceId, dappName) = action.action {
                events.append(.request(WalletTonConnectRequestMessage(messageId: id, flags: flags, sessionId: sessionId, expires: expires, topic: topic, traceId: traceId, dappName: dappName)))
                break
            }
        }
    }
    return events
}
