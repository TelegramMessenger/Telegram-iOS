import Foundation
import Postbox
import TelegramApi


private func keyFingerprintFromBytes(_ bytes: Buffer) -> Int64 {
    if let memory = bytes.data, bytes.size >= 4 {
        var fingerprint: Int64 = 0
        memcpy(&fingerprint, memory, 8)
        return fingerprint
    }
    return 0
}

extension SecretChatIncomingEncryptedOperation {
    convenience init(message: Api.EncryptedMessage) {
        switch message {
            case let .encryptedMessage(randomId, chatId, date, bytes, file):
                self.init(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId))), globallyUniqueId: randomId, timestamp: date, type: .message, keyFingerprint: keyFingerprintFromBytes(bytes), contents: MemoryBuffer(bytes), mediaFileReference: SecretChatFileReference(file))
            case let .encryptedMessageService(randomId, chatId, date, bytes):
                self.init(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId))), globallyUniqueId: randomId, timestamp: date, type: .service, keyFingerprint: keyFingerprintFromBytes(bytes), contents: MemoryBuffer(bytes), mediaFileReference: nil)
        }
    }
}
