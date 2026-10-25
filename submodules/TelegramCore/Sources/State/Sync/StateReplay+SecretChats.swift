import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Secret chats: the chat itself, its incoming encrypted messages (queued here, decrypted by `finalize`) and its read
/// outbox.
extension ReplayContext {
    func applyUpdateSecretChat(_ chat: Api.EncryptedChat) {
        updateSecretChat(encryptionProvider: encryptionProvider, accountPeerId: accountPeerId, transaction: transaction, mediaBox: mediaBox, chat: chat, requestData: nil)
    }
    
    func applyAddSecretMessages(_ messages: [Api.EncryptedMessage]) {
        for message in messages {
            let peerId = message.peerId
            transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, tagLocalIndex: .automatic, tagMergedIndex: .none, contents: SecretChatIncomingEncryptedOperation(message: message))
            peerIdsWithAddedSecretMessages.insert(peerId)
        }
    }
    
    func applyReadSecretOutbox(_ peerId: PeerId, _ maxTimestamp: Int32, _ actionTimestamp: Int32) {
        applyOutgoingReadMaxIndex(transaction: transaction, index: MessageIndex.upperBound(peerId: peerId, timestamp: maxTimestamp, namespace: Namespaces.Message.Local), beginCountdownAt: actionTimestamp)
    }
}
