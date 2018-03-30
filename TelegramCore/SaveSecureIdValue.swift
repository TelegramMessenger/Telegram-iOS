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
    case verificationRequired
}

func paddedSecureIdData(_ data: Data) -> Data {
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

func unpaddedSecureIdData(_ data: Data) -> Data? {
    var paddingCount: UInt8 = 0
    data.copyBytes(to: &paddingCount, count: 1)
    
    if paddingCount < 0 || paddingCount > data.count {
        return nil
    }
    
    return data.subdata(in: Int(paddingCount) ..< data.count)
}

struct EncryptedSecureData {
    let data: Data
    let dataHash: Data
    let hash: Data
    let encryptedSecret: Data
}

func encryptedSecureValueData(context: SecureIdAccessContext, valueContext: SecureIdValueAccessContext, data: Data, files: [SecureIdVerificationDocumentReference]) -> EncryptedSecureData? {
    let valueData = paddedSecureIdData(data)
    let valueHash = sha256Digest(valueData)
    
    let valueSecretHash = sha512Digest(valueContext.secret + valueHash)
    let valueKey = valueSecretHash.subdata(in: 0 ..< 32)
    let valueIv = valueSecretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedValueData = encryptSecureData(key: valueKey, iv: valueIv, data: valueData, decrypt: false) else {
        return nil
    }
    
    let secretHash = sha512Digest(context.secret + valueHash)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedValueSecret = encryptSecureData(key: secretKey, iv: secretIv, data: valueContext.secret, decrypt: false) else {
        return nil
    }
    
    var hashData = valueHash + encryptedValueSecret
    for file in files {
        switch file {
            case let .remote(file):
                hashData.append(file.fileHash)
                hashData.append(file.encryptedSecret)
            case let .uploaded(file):
                hashData.append(file.fileHash)
                hashData.append(file.encryptedSecret)
        }
    }
    let hash = sha256Digest(hashData)
    
    return EncryptedSecureData(data: encryptedValueData, dataHash: valueHash, hash: hash, encryptedSecret: encryptedValueSecret)
}

func decryptedSecureValueAccessContext(context: SecureIdAccessContext, encryptedSecret: Data, decryptedDataHash: Data) -> SecureIdValueAccessContext? {
    let secretHash = sha512Digest(context.secret + decryptedDataHash)
    let secretKey = secretHash.subdata(in: 0 ..< 32)
    let secretIv = secretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let valueSecret = encryptSecureData(key: secretKey, iv: secretIv, data: encryptedSecret, decrypt: true) else {
        return nil
    }
    
    if !verifySecureSecret(valueSecret) {
        return nil
    }
    
    let valueSecretHash = sha512Digest(valueSecret)
    var valueSecretIdValue: Int64 = 0
    valueSecretHash.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        memcpy(&valueSecretIdValue, bytes.advanced(by: valueSecretHash.count - 8), 8)
    }
    
    return SecureIdValueAccessContext(secret: valueSecret, id: valueSecretIdValue)
}

func decryptedSecureValueData(context: SecureIdValueAccessContext, encryptedData: Data, decryptedDataHash: Data) -> Data? {
    let valueSecretHash = sha512Digest(context.secret + decryptedDataHash)
    
    let valueKey = valueSecretHash.subdata(in: 0 ..< 32)
    let valueIv = valueSecretHash.subdata(in: 32 ..< (32 + 16))
    
    guard let decryptedValueData = encryptSecureData(key: valueKey, iv: valueIv, data: encryptedData, decrypt: true) else {
        return nil
    }
    
    let checkDataHash = sha256Digest(decryptedValueData)
    if checkDataHash != decryptedDataHash {
        return nil
    }
    
    guard let unpaddedValueData = unpaddedSecureIdData(decryptedValueData) else {
        return nil
    }
    
    return unpaddedValueData
}

private func makeInputSecureValue(context: SecureIdAccessContext, valueContext: SecureIdValueAccessContext, value: SecureIdValue) -> Api.InputSecureValue? {
    switch value {
        case .identity:
            guard let (decryptedData, fileReferences) = value.serialize() else {
                return nil
            }
            guard let encryptedData = encryptedSecureValueData(context: context, valueContext: valueContext, data: decryptedData, files: fileReferences) else {
                return nil
            }
            guard let checkValueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedData.encryptedSecret, decryptedDataHash: encryptedData.dataHash) else {
                return nil
            }
            if checkValueContext != valueContext {
                return nil
            }
            
            if let checkData = decryptedSecureValueData(context: checkValueContext, encryptedData: encryptedData.data, decryptedDataHash: encryptedData.dataHash) {
                if checkData != decryptedData {
                    return nil
                }
            } else {
                return nil
            }
            
            let files = fileReferences.map { file -> Api.InputSecureFile in
                switch file {
                    case let .remote(file):
                        return Api.InputSecureFile.inputSecureFile(id: file.id, accessHash: file.accessHash)
                    case let .uploaded(file):
                        return Api.InputSecureFile.inputSecureFileUploaded(id: file.id, parts: file.parts, md5Checksum: file.md5Checksum, fileHash: Buffer(data: file.fileHash), secret: Buffer(data: file.encryptedSecret))
                }
            }
            
            return Api.InputSecureValue.inputSecureValueIdentity(data: Api.SecureData.secureData(data: Buffer(data: encryptedData.data), dataHash: Buffer(data: encryptedData.dataHash), secret: Buffer(data: encryptedData.encryptedSecret)), files: files)
        case .address:
            guard let (decryptedData, fileReferences) = value.serialize() else {
                return nil
            }
            guard let encryptedData = encryptedSecureValueData(context: context, valueContext: valueContext, data: decryptedData, files: fileReferences) else {
                return nil
            }
            guard let checkValueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedData.encryptedSecret, decryptedDataHash: encryptedData.dataHash) else {
                return nil
            }
            if checkValueContext != valueContext {
                return nil
            }
            
            if let checkData = decryptedSecureValueData(context: checkValueContext, encryptedData: encryptedData.data, decryptedDataHash: encryptedData.dataHash) {
                if checkData != decryptedData {
                    return nil
                }
            } else {
                return nil
            }
            
            let files = fileReferences.map { file -> Api.InputSecureFile in
                switch file {
                    case let .remote(file):
                        return Api.InputSecureFile.inputSecureFile(id: file.id, accessHash: file.accessHash)
                    case let .uploaded(file):
                        return Api.InputSecureFile.inputSecureFileUploaded(id: file.id, parts: file.parts, md5Checksum: file.md5Checksum, fileHash: Buffer(data: file.fileHash), secret: Buffer(data: file.encryptedSecret))
                }
            }
            
            return Api.InputSecureValue.inputSecureValueAddress(data: Api.SecureData.secureData(data: Buffer(data: encryptedData.data), dataHash: Buffer(data: encryptedData.dataHash), secret: Buffer(data: encryptedData.encryptedSecret)), files: files)
        case let .phone(value):
            return Api.InputSecureValue.inputSecureValuePhone(phone: value.phone)
        case let .email(value):
            return Api.InputSecureValue.inputSecureValueEmail(email: value.email)
    }
}

private func inputSecureValueType(_ value: SecureIdValue) -> Api.SecureValueType {
    switch value {
        case .identity:
            return .secureValueTypeIdentity
        case .address:
            return .secureValueTypeAddress
        case .phone:
            return .secureValueTypePhone
        case .email:
            return .secureValueTypeEmail
    }
}

public func saveSecureIdValue(network: Network, context: SecureIdAccessContext, valueContext: SecureIdValueAccessContext, value: SecureIdValue) -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> {
    guard let inputValue = makeInputSecureValue(context: context, valueContext: valueContext, value: value) else {
        return .fail(.generic)
    }
    return network.request(Api.functions.account.saveSecureValue(value: inputValue, secureSecretId: context.id))
    |> mapError { error -> SaveSecureIdValueError in
        if error.errorDescription == "PHONE_VERIFICATION_NEEDED" || error.errorDescription == "EMAIL_VERIFICATION_NEEDED" {
            return .verificationRequired
        }
        return .generic
    }
    |> mapToSignal { _ -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> in
        return network.request(Api.functions.account.getSecureValue(userId: .inputUserSelf, types: [inputSecureValueType(value)]))
        |> mapError { _ -> SaveSecureIdValueError in
            return .generic
        }
        |> mapToSignal { result -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> in
            guard let firstValue = result.first else {
                return .fail(.generic)
            }
            guard let parsedValue = parseSecureValue(context: context, value: firstValue) else {
                return .fail(.generic)
            }
            guard parsedValue.valueWithContext.context == valueContext else {
                return .fail(.generic)
            }
            
            return .single(parsedValue.valueWithContext)
        }
    }
}

public enum DeleteSecureIdValueError {
    case generic
}

public func deleteSecureIdValue(network: Network, value: SecureIdValue) -> Signal<Void, DeleteSecureIdValueError> {
    let type: Api.SecureValueType
    switch value {
        case .identity:
            type = .secureValueTypeIdentity
        case .address:
            type = .secureValueTypeAddress
        case .phone:
            type = .secureValueTypePhone
        case .email:
            type = .secureValueTypeEmail
    }
    return network.request(Api.functions.account.deleteSecureValue(types: [type]))
    |> mapError { _ -> DeleteSecureIdValueError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, DeleteSecureIdValueError> in
        return .complete()
    }
}
