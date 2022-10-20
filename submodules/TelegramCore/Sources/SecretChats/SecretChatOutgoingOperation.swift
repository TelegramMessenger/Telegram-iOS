import Foundation
import Postbox
import TelegramApi


extension SecretChatOutgoingFileReference {
    init?(_ apiFile: Api.InputEncryptedFile) {
        switch apiFile {
            case let .inputEncryptedFile(id, accessHash):
                self = .remote(id: id, accessHash: accessHash)
            case let .inputEncryptedFileBigUploaded(id, parts, keyFingerprint):
                self = .uploadedLarge(id: id, partCount: parts, keyFingerprint: keyFingerprint)
            case let .inputEncryptedFileUploaded(id, parts, md5Checksum, keyFingerprint):
                self = .uploadedRegular(id: id, partCount: parts, md5Digest: md5Checksum, keyFingerprint: keyFingerprint)
            case .inputEncryptedFileEmpty:
                return nil
        }
    }
    
    var apiInputFile: Api.InputEncryptedFile {
        switch self {
            case let .remote(id, accessHash):
                return .inputEncryptedFile(id: id, accessHash: accessHash)
            case let .uploadedRegular(id, partCount, md5Digest, keyFingerprint):
                return .inputEncryptedFileUploaded(id: id, parts: partCount, md5Checksum: md5Digest, keyFingerprint: keyFingerprint)
            case let .uploadedLarge(id, partCount, keyFingerprint):
                return .inputEncryptedFileBigUploaded(id: id, parts: partCount, keyFingerprint: keyFingerprint)
        }
    }
}
