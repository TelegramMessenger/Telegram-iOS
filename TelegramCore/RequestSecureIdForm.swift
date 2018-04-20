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

public enum RequestSecureIdFormError {
    case generic
    case serverError(String)
}

private func parseSecureValueType(_ type: Api.SecureValueType, selfie: Bool) -> SecureIdRequestedFormField {
    switch type {
        case .secureValueTypePersonalDetails:
            return .personalDetails
        case .secureValueTypePassport:
            return .passport(selfie: selfie)
        case .secureValueTypeDriverLicense:
            return .driversLicense(selfie: selfie)
        case .secureValueTypeIdentityCard:
            return .idCard(selfie: selfie)
        case .secureValueTypeAddress:
            return .address
        case .secureValueTypeUtilityBill:
            return .utilityBill
        case .secureValueTypeBankStatement:
            return .bankStatement
        case .secureValueTypeRentalAgreement:
            return .rentalAgreement
        case .secureValueTypePhone:
            return .phone
        case .secureValueTypeEmail:
            return .email
    }
}

private func parseSecureData(_ value: Api.SecureData) -> (data: Data, hash: Data, secret: Data) {
    switch value {
        case let .secureData(data, dataHash, secret):
            return (data.makeData(), dataHash.makeData(), secret.makeData())
    }
}

struct ParsedSecureValue {
    let valueWithContext: SecureIdValueWithContext
}

func parseSecureValue(context: SecureIdAccessContext, value: Api.SecureValue) -> ParsedSecureValue? {
    switch value {
        case let .secureValue(_, type, data, files, plainData, selfie, hash):
            let parsedFileReferences = files.flatMap { $0.compactMap(SecureIdFileReference.init) } ?? []
            let parsedFiles = parsedFileReferences.map(SecureIdVerificationDocumentReference.remote)
            let parsedSelfie = selfie.flatMap(SecureIdFileReference.init).flatMap(SecureIdVerificationDocumentReference.remote)
            
            let decryptedData: Data?
            let encryptedMetadata: SecureIdEncryptedValueMetadata?
            var parsedFileMetadata: [SecureIdEncryptedValueFileMetadata] = []
            var parsedSelfieMetadata: SecureIdEncryptedValueFileMetadata?
            if let data = data {
                let (encryptedData, decryptedHash, encryptedSecret) = parseSecureData(data)
                guard let valueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedSecret, decryptedDataHash: decryptedHash) else {
                    return nil
                }
            
                decryptedData = decryptedSecureValueData(context: valueContext, encryptedData: encryptedData, decryptedDataHash: decryptedHash)
                if decryptedData == nil {
                    return nil
                }
                encryptedMetadata = SecureIdEncryptedValueMetadata(valueDataHash: decryptedHash, decryptedSecret: valueContext.secret)
            } else {
                decryptedData = nil
                encryptedMetadata = nil
            }
            for file in parsedFileReferences {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: file.fileHash, encryptedSecret: file.encryptedSecret) else {
                    return nil
                }
                parsedFileMetadata.append(SecureIdEncryptedValueFileMetadata(hash: file.fileHash, secret: fileSecret))
            }
            if let parsedSelfie = selfie.flatMap(SecureIdFileReference.init) {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: parsedSelfie.fileHash, encryptedSecret: parsedSelfie.encryptedSecret) else {
                    return nil
                }
                
                parsedSelfieMetadata = SecureIdEncryptedValueFileMetadata(hash: parsedSelfie.fileHash, secret: fileSecret)
            }
            
            let value: SecureIdValue
            
            switch type {
                case .secureValueTypePersonalDetails:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let personalDetails = SecureIdPersonalDetailsValue(dict: dict, fileReferences: parsedFiles) else {
                        return nil
                    }
                    value = .personalDetails(personalDetails)
                case .secureValueTypePassport:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let passport = SecureIdPassportValue(dict: dict, fileReferences: parsedFiles, selfieDocument: parsedSelfie) else {
                        return nil
                    }
                    value = .passport(passport)
                case .secureValueTypeDriverLicense:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let driversLicense = SecureIdDriversLicenseValue(dict: dict, fileReferences: parsedFiles, selfieDocument: parsedSelfie) else {
                        return nil
                    }
                    value = .driversLicense(driversLicense)
                case .secureValueTypeIdentityCard:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let idCard = SecureIdIDCardValue(dict: dict, fileReferences: parsedFiles, selfieDocument: parsedSelfie) else {
                        return nil
                    }
                    value = .idCard(idCard)
                case .secureValueTypeAddress:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let address = SecureIdAddressValue(dict: dict, fileReferences: parsedFiles) else {
                        return nil
                    }
                    value = .address(address)
                case .secureValueTypeUtilityBill:
                    guard let utilityBill = SecureIdUtilityBillValue(fileReferences: parsedFiles) else {
                        return nil
                    }
                    value = .utilityBill(utilityBill)
                case .secureValueTypeBankStatement:
                    guard let bankStatement = SecureIdBankStatementValue(fileReferences: parsedFiles) else {
                        return nil
                    }
                    value = .bankStatement(bankStatement)
                case .secureValueTypeRentalAgreement:
                    guard let rentalAgreement = SecureIdRentalAgreementValue(fileReferences: parsedFiles) else {
                        return nil
                    }
                    value = .rentalAgreement(rentalAgreement)
                case .secureValueTypePhone:
                    guard let publicData = plainData else {
                        return nil
                    }
                    switch publicData {
                        case let .securePlainPhone(phone):
                            value = .phone(SecureIdPhoneValue(phone: phone))
                        default:
                            return nil
                    }
                case .secureValueTypeEmail:
                    guard let publicData = plainData else {
                        return nil
                    }
                    switch publicData {
                        case let .securePlainEmail(email):
                            value = .email(SecureIdEmailValue(email: email))
                        default:
                            return nil
                    }
            }
        
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: value, files: parsedFileMetadata, selfie: parsedSelfieMetadata, encryptedMetadata: encryptedMetadata, opaqueHash: hash.makeData()))
    }
}

private func parseSecureValues(context: SecureIdAccessContext, values: [Api.SecureValue]) -> [SecureIdValueWithContext] {
    return values.map({ parseSecureValue(context: context, value: $0) }).compactMap({ $0?.valueWithContext })
}

public struct EncryptedSecureIdForm {
    public let peerId: PeerId
    public let requestedFields: [SecureIdRequestedFormField]
    public let termsUrl: String?
    
    let encryptedValues: [Api.SecureValue]
}

public func requestSecureIdForm(postbox: Postbox, network: Network, peerId: PeerId, scope: String, publicKey: String) -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return .fail(.serverError("PEER IS NOT A BOT"))
    }
    return network.request(Api.functions.account.getAuthorizationForm(botId: peerId.id, scope: scope, publicKey: publicKey))
    |> mapError { error -> RequestSecureIdFormError in
        return .serverError(error.errorDescription)
    }
    |> mapToSignal { result -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> in
        return postbox.modify { modifier -> EncryptedSecureIdForm in
            switch result {
                case let .authorizationForm(flags, requiredTypes, values, errors, users, termsUrl):
                    var peers: [Peer] = []
                    for user in users {
                        let parsed = TelegramUser(user: user)
                        peers.append(parsed)
                    }
                    updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                        return updated
                    })
                    
                    return EncryptedSecureIdForm(peerId: peerId, requestedFields: requiredTypes.map {
                        return parseSecureValueType($0, selfie: (flags & 1 << 1) != 0)
                    }, termsUrl: termsUrl, encryptedValues: values)
            }
        } |> mapError { _ in return RequestSecureIdFormError.generic }
    }
}

public func decryptedSecureIdForm(context: SecureIdAccessContext, form: EncryptedSecureIdForm) -> SecureIdForm? {
    return SecureIdForm(peerId: form.peerId, requestedFields: form.requestedFields, values: parseSecureValues(context: context, values: form.encryptedValues))
}
