import Foundation
import Postbox
import TelegramApi


extension SecretChatFileReference {
    convenience init?(_ file: Api.EncryptedFile) {
        switch file {
            case let .encryptedFile(id, accessHash, size, dcId, keyFingerprint):
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, keyFingerprint: keyFingerprint)
            case .encryptedFileEmpty:
                return nil
        }
    }
}
