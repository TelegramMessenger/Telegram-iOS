import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

public enum SaveSecureIdValueError {
    case generic
}

private func paddedData(_ data: Data) -> Data {
    var paddingCount = Int(47 + arc4random_uniform(255 - 47))
    paddingCount -= ((data.count + paddingCount) % 16)
    var result = Data(count: paddingCount + data.count)
    result.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        bytes.advanced(by: 0).pointee = UInt8(paddingCount)
        arc4random_buf(bytes.advanced(by: 1), paddingCount - 1)
        data.withUnsafeBytes { (source: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: paddingCount), source, data.count)
        }
    }
    return result
}

private func unpaddedData(_ data: Data) -> Data? {
    var paddingCount: UInt8 = 0
    data.copyBytes(to: &paddingCount, count: 1)
    
    if paddingCount < 0 || paddingCount > data.count {
        return nil
    }
    
    return data.subdata(in: Int(paddingCount) ..< data.count)
}

struct EncryptedSecureData {
    let data: Data
    let hash: Data
    let encryptedSecret: Data
    let secretHash: Data
}

func encryptedSecureData(context: SecureIdAccessContext, data: Data) -> EncryptedSecureData? {
    let fileData = paddedData(data)
    let fileHash = sha256Digest(fileData)
    
    guard let fileSecret = generateSecureSecretData() else {
        return nil
    }
    let fileSecretHash = sha512Digest(fileSecret + fileHash)
    let fileKey = fileSecretHash.subdata(in: 0 ..< 32)
    let fileIv = fileSecretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedFileData = encryptSecureData(key: fileKey, iv: fileIv, data: fileData, decrypt: false) else {
        return nil
    }
    
    let secretHash = sha512Digest(context.secret)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedFileSecret = encryptSecureData(key: secretKey, iv: secretIv, data: fileSecret, decrypt: false) else {
        return nil
    }
    
    return EncryptedSecureData(data: encryptedFileData, hash: fileHash, encryptedSecret: encryptedFileSecret, secretHash: secretHash)
}

func decryptedSecureData(context: SecureIdAccessContext, data: Data, dataHash: Data, encryptedSecret: Data) -> Data? {
    let secretHash = sha512Digest(context.secret)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let fileSecret = encryptSecureData(key: secretKey, iv: secretIv, data: encryptedSecret, decrypt: true) else {
        return nil
    }
    
    if !verifySecureSecret(fileSecret) {
        return nil
    }
    
    let fileSecretHash = sha512Digest(fileSecret + dataHash)
    let fileKey = fileSecretHash.subdata(in: 0 ..< 32)
    let fileIv = fileSecretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let decryptedFileData = encryptSecureData(key: fileKey, iv: fileIv, data: data, decrypt: true) else {
        return nil
    }
    
    let checkDataHash = sha256Digest(decryptedFileData)
    if checkDataHash != dataHash {
        return nil
    }
    
    return unpaddedData(decryptedFileData)
}

private func makeInputSecureValue(context: SecureIdAccessContext, value: SecureIdValue) -> Api.InputSecureValue? {
    switch value {
        case .identity:
            guard let (decryptedData, fileReferences) = value.serialize() else {
                return nil
            }
            guard let encryptedData = encryptedSecureData(context: context, data: decryptedData) else {
                return nil
            }
            
            if let checkData = decryptedSecureData(context: context, data: encryptedData.data, dataHash: encryptedData.hash, encryptedSecret: encryptedData.encryptedSecret) {
                if checkData != decryptedData {
                    return nil
                }
            } else {
                return nil
            }
            
            let files = fileReferences.map { file in
                return Api.InputSecureFile.inputSecureFile(id: file.id, accessHash: file.accessHash)
            }
            
            return Api.InputSecureValue.inputSecureValueIdentity(data: Api.SecureData.secureData(data: Buffer(data: encryptedData.data), dataHash: Buffer(data: encryptedData.hash)), files: files, secret: Buffer(data: encryptedData.encryptedSecret), hash: Buffer(data: encryptedData.secretHash))
        case let .phone(value):
            guard let phoneData = value.phone.data(using: .utf8) else {
                return nil
            }
            return Api.InputSecureValue.inputSecureValuePhone(phone: value.phone, hash: Buffer(data: sha256Digest(phoneData)))
        case let .email(value):
            guard let emailData = value.email.data(using: .utf8) else {
                return nil
            }
            return Api.InputSecureValue.inputSecureValueEmail(email: value.email, hash: Buffer(data: sha256Digest(emailData)))
    }
}

public func saveSecureIdValue(network: Network, context: SecureIdAccessContext, value: SecureIdValue) -> Signal<Void, SaveSecureIdValueError> {
    guard let inputValue = makeInputSecureValue(context: context, value: value) else {
        return .fail(.generic)
    }
    return network.request(Api.functions.account.saveSecureValue(value: inputValue, secureSecretHash: context.hash))
    |> mapError { _ -> SaveSecureIdValueError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, SaveSecureIdValueError> in
        return .complete()
    }
}
