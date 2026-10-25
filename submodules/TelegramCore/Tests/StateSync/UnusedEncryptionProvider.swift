import Foundation
import EncryptionProvider

/// `MTContext` requires an encryption provider. Nothing reaches it while the scripted server carries the
/// network: no MTProto session exists, so no auth key is made, and `replayFinalState` uses it only for
/// secret chats (`updateSecretChat`, `processSecretChatIncomingDecryptedOperations`). A test that
/// replays a secret-chat update traps here.
final class UnusedEncryptionProvider: NSObject, EncryptionProvider {
    func createBignumContext() -> MTBignumContext {
        preconditionFailure("UnusedEncryptionProvider: no auth key or secret chat is made in the harness")
    }

    func rsaEncrypt(withPublicKey publicKey: String, data: Data) -> Data? {
        preconditionFailure("UnusedEncryptionProvider: no auth key is made in the harness")
    }

    func rsaEncryptPKCS1OAEP(withPublicKey publicKey: String, data: Data) -> Data? {
        preconditionFailure("UnusedEncryptionProvider: no auth key is made in the harness")
    }

    func parseRSAPublicKey(_ publicKey: String) -> MTRsaPublicKey {
        preconditionFailure("UnusedEncryptionProvider: no auth key is made in the harness")
    }

    func macosRSAEncrypt(_ publicKey: String, data: Data) -> Data {
        preconditionFailure("UnusedEncryptionProvider: no auth key is made in the harness")
    }
}
