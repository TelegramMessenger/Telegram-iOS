import Foundation

extension SecretChatFileReference {
    func resource(key: SecretFileEncryptionKey, decryptedSize: Int64) -> SecretFileMediaResource {
        return SecretFileMediaResource(fileId: self.id, accessHash: self.accessHash, containerSize: self.size, decryptedSize: decryptedSize, datacenterId: Int(self.datacenterId), key: key)
    }
}
