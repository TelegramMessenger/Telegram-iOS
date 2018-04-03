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

struct EncryptedSecureData {
    let data: Data
    let dataHash: Data
    let encryptedSecret: Data
}

func encryptedSecureValueData(context: SecureIdAccessContext, valueContext: SecureIdValueAccessContext, data: Data) -> EncryptedSecureData? {
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
    
    return EncryptedSecureData(data: encryptedValueData, dataHash: valueHash, encryptedSecret: encryptedValueSecret)
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

private func apiInputSecretFile(_ file: SecureIdVerificationDocumentReference) -> Api.InputSecureFile {
    switch file {
        case let .remote(file):
            return Api.InputSecureFile.inputSecureFile(id: file.id, accessHash: file.accessHash)
        case let .uploaded(file):
            return Api.InputSecureFile.inputSecureFileUploaded(id: file.id, parts: file.parts, md5Checksum: file.md5Checksum, fileHash: Buffer(data: file.fileHash), secret: Buffer(data: file.encryptedSecret))
    }
}

private struct InputSecureIdValueData {
    let type: Api.SecureValueType
    let dict: [String: Any]?
    let fileReferences: [SecureIdVerificationDocumentReference]
    let selfieReference: SecureIdVerificationDocumentReference?
    let publicData: Api.SecurePlainData?
}

private func inputSecureIdValueData(value: SecureIdValue) -> InputSecureIdValueData {
    switch value {
        case let .personalDetails(personalDetails):
            let (dict, fileReferences) = personalDetails.serialize()
            return InputSecureIdValueData(type: .secureValueTypePersonalDetails, dict: dict, fileReferences: fileReferences, selfieReference: nil, publicData: nil)
        case let .passport(passport):
            let (dict, fileReferences, selfieReference) = passport.serialize()
            return InputSecureIdValueData(type: .secureValueTypePassport, dict: dict, fileReferences: fileReferences, selfieReference: selfieReference, publicData: nil)
        case let .driversLicense(driversLicense):
            let (dict, fileReferences, selfieReference) = driversLicense.serialize()
            return InputSecureIdValueData(type: .secureValueTypeDriverLicense, dict: dict, fileReferences: fileReferences, selfieReference: selfieReference, publicData: nil)
        case let .idCard(idCard):
            let (dict, fileReferences, selfieReference) = idCard.serialize()
            return InputSecureIdValueData(type: .secureValueTypeIdentityCard, dict: dict, fileReferences: fileReferences, selfieReference: selfieReference, publicData: nil)
        case let .address(address):
            let (dict, fileReferences) = address.serialize()
            return InputSecureIdValueData(type: .secureValueTypeAddress, dict: dict, fileReferences: fileReferences, selfieReference: nil, publicData: nil)
        case let .utilityBill(utilityBill):
            let (dict, fileReferences) = utilityBill.serialize()
            return InputSecureIdValueData(type: .secureValueTypeUtilityBill, dict: dict, fileReferences: fileReferences, selfieReference: nil, publicData: nil)
        case let .bankStatement(bankStatement):
            let (dict, fileReferences) = bankStatement.serialize()
            return InputSecureIdValueData(type: .secureValueTypeBankStatement, dict: dict, fileReferences: fileReferences, selfieReference: nil, publicData: nil)
        case let .rentalAgreement(rentalAgreement):
            let (dict, fileReferences) = rentalAgreement.serialize()
            return InputSecureIdValueData(type: .secureValueTypeRentalAgreement, dict: dict, fileReferences: fileReferences, selfieReference: nil, publicData: nil)
        case let .phone(phone):
            return InputSecureIdValueData(type: .secureValueTypePhone, dict: nil, fileReferences: [], selfieReference: nil, publicData: .securePlainPhone(phone: phone.phone))
        case let .email(email):
            return InputSecureIdValueData(type: .secureValueTypeEmail, dict: nil, fileReferences: [], selfieReference: nil, publicData: .securePlainEmail(email: email.email))
    }
}

private func makeInputSecureValue(context: SecureIdAccessContext, value: SecureIdValue) -> Api.InputSecureValue? {
    let inputData = inputSecureIdValueData(value: value)
    
    var secureData: Api.SecureData?
    if let dict = inputData.dict {
        guard let decryptedData = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        guard let valueContext = generateSecureIdValueAccessContext() else {
            return nil
        }
        guard let encryptedData = encryptedSecureValueData(context: context, valueContext: valueContext, data: decryptedData) else {
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
        secureData = .secureData(data: Buffer(data: encryptedData.data), dataHash: Buffer(data: encryptedData.dataHash), secret: Buffer(data: encryptedData.encryptedSecret))
    }
    
    var flags: Int32 = 0
    
    let files = inputData.fileReferences.map(apiInputSecretFile)
    
    if secureData != nil {
        flags |= 1 << 0
    }
    if !files.isEmpty {
        flags |= 1 << 1
    }
    if inputData.publicData != nil {
        flags |= 1 << 2
    }
    if inputData.selfieReference != nil {
        flags |= 1 << 3
    }
    
    return Api.InputSecureValue.inputSecureValue(flags: flags, type: inputData.type, data: secureData, files: files, plainData: inputData.publicData, selfie: inputData.selfieReference.flatMap(apiInputSecretFile))
}

public func saveSecureIdValue(network: Network, context: SecureIdAccessContext, value: SecureIdValue) -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> {
    let delete = deleteSecureIdValues(network: network, keys: Set([value.key]))
    |> mapError { _ -> SaveSecureIdValueError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> in
        return .complete()
    }
    |> `catch` { _ -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> in
        return .complete()
    }
    
    guard let inputValue = makeInputSecureValue(context: context, value: value) else {
        return .fail(.generic)
    }
    let save = network.request(Api.functions.account.saveSecureValue(value: inputValue, secureSecretId: context.id))
    |> mapError { error -> SaveSecureIdValueError in
        if error.errorDescription == "PHONE_VERIFICATION_NEEDED" || error.errorDescription == "EMAIL_VERIFICATION_NEEDED" {
            return .verificationRequired
        }
        return .generic
    }
    |> mapToSignal { result -> Signal<SecureIdValueWithContext, SaveSecureIdValueError> in
        guard let parsedValue = parseSecureValue(context: context, value: result) else {
            return .fail(.generic)
        }
        
        return .single(parsedValue.valueWithContext)
    }
    
    return delete |> then(save)
}

public enum DeleteSecureIdValueError {
    case generic
}

public func deleteSecureIdValues(network: Network, keys: Set<SecureIdValueKey>) -> Signal<Void, DeleteSecureIdValueError> {
    return network.request(Api.functions.account.deleteSecureValue(types: keys.map(apiSecureValueType(key:))))
    |> mapError { _ -> DeleteSecureIdValueError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, DeleteSecureIdValueError> in
        return .complete()
    }
}
