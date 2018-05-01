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

func apiSecureValueType(value: SecureIdValue) -> Api.SecureValueType {
    let type: Api.SecureValueType
    switch value {
        case .personalDetails:
            type = .secureValueTypePersonalDetails
        case .passport:
            type = .secureValueTypePassport
        case .internalPassport:
            type = .secureValueTypeInternalPassport
        case .driversLicense:
            type = .secureValueTypeDriverLicense
        case .idCard:
            type = .secureValueTypeIdentityCard
        case .address:
            type = .secureValueTypeAddress
        case .passportRegistration:
            type = .secureValueTypePassportRegistration
        case .temporaryRegistration:
            type = .secureValueTypeTemporaryRegistration
        case .bankStatement:
            type = .secureValueTypeBankStatement
        case .utilityBill:
            type = .secureValueTypeUtilityBill
        case .rentalAgreement:
            type = .secureValueTypeRentalAgreement
        case .phone:
            type = .secureValueTypePhone
        case .email:
            type = .secureValueTypeEmail
    }
    return type
}

func apiSecureValueType(key: SecureIdValueKey) -> Api.SecureValueType {
    let type: Api.SecureValueType
    switch key {
        case .personalDetails:
            type = .secureValueTypePersonalDetails
        case .passport:
            type = .secureValueTypePassport
        case .internalPassport:
            type = .secureValueTypeInternalPassport
        case .driversLicense:
            type = .secureValueTypeDriverLicense
        case .idCard:
            type = .secureValueTypeIdentityCard
        case .address:
            type = .secureValueTypeAddress
        case .passportRegistration:
            type = .secureValueTypePassportRegistration
        case .temporaryRegistration:
            type = .secureValueTypeTemporaryRegistration
        case .bankStatement:
            type = .secureValueTypeBankStatement
        case .utilityBill:
            type = .secureValueTypeUtilityBill
        case .rentalAgreement:
            type = .secureValueTypeRentalAgreement
        case .phone:
            type = .secureValueTypePhone
        case .email:
            type = .secureValueTypeEmail
    }
    return type
}

private func credentialsValueTypeName(value: SecureIdValue) -> String {
    switch value {
        case .personalDetails:
            return "personal_details"
        case .passport:
            return "passport"
        case .internalPassport:
            return "internal_passport"
        case .driversLicense:
            return "driver_license"
        case .idCard:
            return "identity_card"
        case .address:
            return "address"
        case .passportRegistration:
            return "passport_registration"
        case .temporaryRegistration:
            return "temporary_registration"
        case .bankStatement:
            return "bank_statement"
        case .utilityBill:
            return "utility_bill"
        case .rentalAgreement:
            return "rental_agreement"
        case .phone:
            return "phone"
        case .email:
            return "email"
    }
}

private func generateCredentials(values: [SecureIdValueWithContext], opaquePayload: Data) -> Data? {
    var secureData: [String: Any] = [:]
    for value in values {
        var valueDict: [String: Any] = [:]
        if let encryptedMetadata = value.encryptedMetadata {
            valueDict["data"] = [
                "data_hash": encryptedMetadata.valueDataHash.base64EncodedString(),
                "secret": encryptedMetadata.decryptedSecret.base64EncodedString()
            ] as [String: Any]
        }
            
        if !value.files.isEmpty {
            valueDict["files"] = value.files.map { file -> [String: Any] in
                return [
                    "file_hash": file.hash.base64EncodedString(),
                    "secret": file.secret.base64EncodedString()
                ]
            }
        }
            
        if let selfie = value.selfie {
            valueDict["selfie"] = [
                "file_hash": selfie.hash.base64EncodedString(),
                "secret": selfie.secret.base64EncodedString()
            ] as [String: Any]
        }
        
        if !valueDict.isEmpty {
            secureData[credentialsValueTypeName(value: value.value)] = valueDict
        }
    }
    
    var dict: [String: Any] = [:]
    dict["secure_data"] = secureData
    
    if !opaquePayload.isEmpty, let opaquePayload = String(data: opaquePayload, encoding: .utf8) {
        dict["payload"] = opaquePayload
    }
    
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
        return nil
    }
    
    return data
}

private func encryptedCredentialsData(data: Data, secretData: Data) -> (data: Data, hash: Data)? {
    let paddedData = paddedSecureIdData(data)
    let hash = sha256Digest(paddedData)
    let secretHash = sha512Digest(secretData + hash)
    let key = secretHash.subdata(in: 0 ..< 32)
    let iv = secretHash.subdata(in: 32 ..< (32 + 16))
    guard let encryptedData = encryptSecureData(key: key, iv: iv, data: paddedData, decrypt: false) else {
        return nil
    }
    return (encryptedData, hash)
}

public enum GrantSecureIdAccessError {
    case generic
}

public func grantSecureIdAccess(network: Network, peerId: PeerId, publicKey: String, scope: String, opaquePayload: Data, values: [SecureIdValueWithContext]) -> Signal<Void, GrantSecureIdAccessError> {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return .fail(.generic)
    }
    guard let credentialsSecretData = generateSecureSecretData() else {
        return .fail(.generic)
    }
    guard let credentialsData = generateCredentials(values: values, opaquePayload: opaquePayload) else {
        return .fail(.generic)
    }
    guard let (encryptedCredentialsData, decryptedCredentialsHash) = encryptedCredentialsData(data: credentialsData, secretData: credentialsSecretData) else {
        return .fail(.generic)
    }
    guard let encryptedSecretData = MTRsaEncryptPKCS1OAEP(publicKey, credentialsSecretData) else {
        return .fail(.generic)
    }
    
    var valueHashes: [Api.SecureValueHash] = []
    for value in values {
        valueHashes.append(.secureValueHash(type: apiSecureValueType(value: value.value), hash: Buffer(data: value.opaqueHash)))
    }
    
    return network.request(Api.functions.account.acceptAuthorization(botId: peerId.id, scope: scope, publicKey: publicKey, valueHashes: valueHashes, credentials: .secureCredentialsEncrypted(data: Buffer(data: encryptedCredentialsData), hash: Buffer(data: decryptedCredentialsHash), secret: Buffer(data: encryptedSecretData))))
    |> mapError { _ -> GrantSecureIdAccessError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, GrantSecureIdAccessError> in
        return .complete()
    }
}
