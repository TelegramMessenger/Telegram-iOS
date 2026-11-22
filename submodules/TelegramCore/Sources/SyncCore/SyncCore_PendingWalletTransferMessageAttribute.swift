import Foundation
import Postbox

/// A local wallet receipt. It is deliberately not an outgoing message queued for sending.
public final class PendingWalletTransferMessageAttribute: MessageAttribute, PendingMessageActionData {
    public let operationId: String
    public let expiresAt: Int32
    public let previousMessageId: Int32
    public let msgHash: String?
    public let transactionId: String?
    public let chainTraceId: String?
    public let serverMessageId: Int32?

    var resolvedMessageId: String? { self.transactionId ?? self.chainTraceId }

    public init(operationId: String, expiresAt: Int32, previousMessageId: Int32, msgHash: String? = nil, transactionId: String? = nil, chainTraceId: String? = nil, serverMessageId: Int32? = nil) {
        self.operationId = operationId
        self.expiresAt = expiresAt
        self.previousMessageId = previousMessageId
        self.msgHash = msgHash
        self.transactionId = transactionId
        self.chainTraceId = chainTraceId
        self.serverMessageId = serverMessageId
    }

    public init(decoder: PostboxDecoder) {
        self.operationId = decoder.decodeStringForKey("o", orElse: "")
        self.expiresAt = decoder.decodeInt32ForKey("e", orElse: 0)
        self.previousMessageId = decoder.decodeInt32ForKey("p", orElse: 0)
        self.msgHash = decoder.decodeOptionalStringForKey("h")
        self.transactionId = decoder.decodeOptionalStringForKey("t")
        self.chainTraceId = decoder.decodeOptionalStringForKey("ct")
        self.serverMessageId = decoder.decodeOptionalInt32ForKey("sid")
    }

    public func encode(_ encoder: PostboxEncoder) {
        if let serverMessageId = self.serverMessageId {
            encoder.encodeInt32(serverMessageId, forKey: "sid")
        } else {
            encoder.encodeNil(forKey: "sid")
        }
        if let chainTraceId = self.chainTraceId {
            encoder.encodeString(chainTraceId, forKey: "ct")
        } else {
            encoder.encodeNil(forKey: "ct")
        }
        encoder.encodeString(self.operationId, forKey: "o")
        encoder.encodeInt32(self.expiresAt, forKey: "e")
        encoder.encodeInt32(self.previousMessageId, forKey: "p")
        if let msgHash = self.msgHash {
            encoder.encodeString(msgHash, forKey: "h")
        } else {
            encoder.encodeNil(forKey: "h")
        }
        if let transactionId = self.transactionId {
            encoder.encodeString(transactionId, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }

    public func isEqual(to other: PendingMessageActionData) -> Bool {
        guard let other = other as? PendingWalletTransferMessageAttribute else {
            return false
        }
        return self.operationId == other.operationId
            && self.expiresAt == other.expiresAt
            && self.previousMessageId == other.previousMessageId
            && self.msgHash == other.msgHash
            && self.transactionId == other.transactionId
            && self.chainTraceId == other.chainTraceId
            && self.serverMessageId == other.serverMessageId
    }

    func accepting(msgHash: String, receivedAt: Int32) -> PendingWalletTransferMessageAttribute {
        // Replayed receipts must not extend the deadline or change an established identity.
        guard self.msgHash == nil else {
            return self
        }
        return PendingWalletTransferMessageAttribute(
            operationId: self.operationId,
            expiresAt: Int32(clamping: Int64(receivedAt) + 90),
            previousMessageId: self.previousMessageId,
            msgHash: msgHash,
            transactionId: self.transactionId,
            chainTraceId: self.chainTraceId,
            serverMessageId: self.serverMessageId
        )
    }

    func renewingPreparation(expiresAt: Int32) -> PendingWalletTransferMessageAttribute {
        guard self.msgHash == nil, self.resolvedMessageId == nil, self.serverMessageId == nil else { return self }
        return PendingWalletTransferMessageAttribute(
            operationId: self.operationId, expiresAt: max(self.expiresAt, expiresAt),
            previousMessageId: self.previousMessageId
        )
    }

    func resolving(transactionId: String) -> PendingWalletTransferMessageAttribute {
        return PendingWalletTransferMessageAttribute(
            operationId: self.operationId,
            expiresAt: self.expiresAt,
            previousMessageId: self.previousMessageId,
            msgHash: self.msgHash,
            transactionId: transactionId,
            chainTraceId: self.chainTraceId,
            serverMessageId: self.serverMessageId
        )
    }

    func resolving(chainTraceId: String) -> PendingWalletTransferMessageAttribute {
        guard self.chainTraceId == nil else { return self }
        return PendingWalletTransferMessageAttribute(
            operationId: self.operationId, expiresAt: self.expiresAt,
            previousMessageId: self.previousMessageId, msgHash: self.msgHash,
            transactionId: self.transactionId, chainTraceId: chainTraceId,
            serverMessageId: self.serverMessageId
        )
    }

    func resolving(serverMessageId: Int32) -> PendingWalletTransferMessageAttribute {
        guard self.serverMessageId == nil, serverMessageId > 0 else { return self }
        return PendingWalletTransferMessageAttribute(
            operationId: self.operationId, expiresAt: self.expiresAt,
            previousMessageId: self.previousMessageId, msgHash: self.msgHash,
            transactionId: self.transactionId, chainTraceId: self.chainTraceId,
            serverMessageId: serverMessageId
        )
    }
}
