import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit

public struct UploadedSecureIdFile: Equatable {
    let id: Int64
    let parts: Int32
    let md5Checksum: String
    public let fileHash: Data
    let encryptedSecret: Data
}

public enum UploadSecureIdFileResult {
    case progress(Float)
    case result(UploadedSecureIdFile, Data)
}

public enum UploadSecureIdFileError {
    case generic
}

private struct EncryptedSecureIdFile {
    let data: Data
    let hash: Data
    let encryptedSecret: Data
}

private func encryptedSecureIdFile(context: SecureIdAccessContext, data: Data) -> EncryptedSecureIdFile? {
    guard let fileSecret = generateSecureSecretData() else {
        return nil
    }
    
    let paddedFileData = paddedSecureIdData(data)
    let fileHash = sha256Digest(paddedFileData)
    let fileSecretHash = sha512Digest(fileSecret + fileHash)
    let fileKey = fileSecretHash.subdata(in: 0 ..< 32)
    let fileIv = fileSecretHash.subdata(in: 32 ..< (32 + 16))
    guard let encryptedFileData = encryptSecureData(key: fileKey, iv: fileIv, data: paddedFileData, decrypt: false) else {
        return nil
    }
    
    let secretHash = sha512Digest(context.secret + fileHash)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    guard let encryptedSecretData = encryptSecureData(key: secretKey, iv: secretIv, data: fileSecret, decrypt: false) else {
        return nil
    }
    
    return EncryptedSecureIdFile(data: encryptedFileData, hash: fileHash, encryptedSecret: encryptedSecretData)
}

func decryptedSecureIdFileSecret(context: SecureIdAccessContext, fileHash: Data, encryptedSecret: Data) -> Data? {
    let secretHash = sha512Digest(context.secret + fileHash)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    guard let fileSecret = encryptSecureData(key: secretKey, iv: secretIv, data: encryptedSecret, decrypt: true) else {
        return nil
    }
    guard verifySecureSecret(fileSecret) else {
        return nil
    }
    return fileSecret
}

func decryptedSecureIdFile(context: SecureIdAccessContext, encryptedData: Data, fileHash: Data, encryptedSecret: Data) -> Data? {
    guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: fileHash, encryptedSecret: encryptedSecret) else {
        return nil
    }
    
    let fileSecretHash = sha512Digest(fileSecret + fileHash)
    let fileKey = fileSecretHash.subdata(in: 0 ..< 32)
    let fileIv = fileSecretHash.subdata(in: 32 ..< (32 + 16))
    guard let paddedFileData = encryptSecureData(key: fileKey, iv: fileIv, data: encryptedData, decrypt: true) else {
        return nil
    }
    
    let checkFileHash = sha256Digest(paddedFileData)
    if fileHash != checkFileHash {
        return nil
    }
    
    guard let unpaddedFileData = unpaddedSecureIdData(paddedFileData) else {
        return nil
    }
    
    return unpaddedFileData
}

public func uploadSecureIdFile(context: SecureIdAccessContext, postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadSecureIdFileResult, UploadSecureIdFileError> {
    return postbox.mediaBox.resourceData(resource)
    |> mapError { _ -> UploadSecureIdFileError in
    }
    |> mapToSignal { next -> Signal<UploadSecureIdFileResult, UploadSecureIdFileError> in
        if !next.complete {
            return .complete()
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: next.path)) else {
            return .fail(.generic)
        }
        
        guard let encryptedData = encryptedSecureIdFile(context: context, data: data) else {
            return .fail(.generic)
        }
        
        return multipartUpload(network: network, postbox: postbox, source: .data(encryptedData.data), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
        |> mapError { _ -> UploadSecureIdFileError in
            return .generic
        }
        |> mapToSignal { result -> Signal<UploadSecureIdFileResult, UploadSecureIdFileError> in
            switch result {
                case let .progress(value):
                    return .single(.progress(value))
                case let .inputFile(file):
                    if case let .inputFile(id, parts, _, md5Checksum) = file {
                        return .single(.result(UploadedSecureIdFile(id: id, parts: parts, md5Checksum: md5Checksum, fileHash: encryptedData.hash, encryptedSecret: encryptedData.encryptedSecret), encryptedData.data))
                    } else {
                        return .fail(.generic)
                    }
                default:
                    return .fail(.generic)
            }
        }
    }
}
