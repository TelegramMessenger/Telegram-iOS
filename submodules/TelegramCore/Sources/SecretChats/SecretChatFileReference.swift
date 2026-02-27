import Foundation
import Postbox
import TelegramApi


extension SecretChatFileReference {
    convenience init?(_ file: Api.EncryptedFile) {
        switch file {
            case let .encryptedFile(encryptedFileData):
                let (id, accessHash, size, dcId, keyFingerprint) = (encryptedFileData.id, encryptedFileData.accessHash, encryptedFileData.size, encryptedFileData.dcId, encryptedFileData.keyFingerprint)
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, keyFingerprint: keyFingerprint)
            case .encryptedFileEmpty:
                return nil
        }
    }
}
