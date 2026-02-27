import Foundation
import Postbox
import TelegramApi


extension SecretChatOutgoingFileReference {
    init?(_ apiFile: Api.InputEncryptedFile) {
        switch apiFile {
            case let .inputEncryptedFile(inputEncryptedFileData):
                let (id, accessHash) = (inputEncryptedFileData.id, inputEncryptedFileData.accessHash)
                self = .remote(id: id, accessHash: accessHash)
            case let .inputEncryptedFileBigUploaded(inputEncryptedFileBigUploadedData):
                let (id, parts, keyFingerprint) = (inputEncryptedFileBigUploadedData.id, inputEncryptedFileBigUploadedData.parts, inputEncryptedFileBigUploadedData.keyFingerprint)
                self = .uploadedLarge(id: id, partCount: parts, keyFingerprint: keyFingerprint)
            case let .inputEncryptedFileUploaded(inputEncryptedFileUploadedData):
                let (id, parts, md5Checksum, keyFingerprint) = (inputEncryptedFileUploadedData.id, inputEncryptedFileUploadedData.parts, inputEncryptedFileUploadedData.md5Checksum, inputEncryptedFileUploadedData.keyFingerprint)
                self = .uploadedRegular(id: id, partCount: parts, md5Digest: md5Checksum, keyFingerprint: keyFingerprint)
            case .inputEncryptedFileEmpty:
                return nil
        }
    }
    
    var apiInputFile: Api.InputEncryptedFile {
        switch self {
            case let .remote(id, accessHash):
                return .inputEncryptedFile(.init(id: id, accessHash: accessHash))
            case let .uploadedRegular(id, partCount, md5Digest, keyFingerprint):
                return .inputEncryptedFileUploaded(.init(id: id, parts: partCount, md5Checksum: md5Digest, keyFingerprint: keyFingerprint))
            case let .uploadedLarge(id, partCount, keyFingerprint):
                return .inputEncryptedFileBigUploaded(.init(id: id, parts: partCount, keyFingerprint: keyFingerprint))
        }
    }
}
