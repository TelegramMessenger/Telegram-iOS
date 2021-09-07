import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi


public enum RequestSecureIdFormError {
    case generic
    case serverError(String)
    case versionOutdated
}

private func parseSecureValueType(_ type: Api.SecureValueType, selfie: Bool, translation: Bool, nativeNames: Bool) -> SecureIdRequestedFormFieldValue {
    switch type {
        case .secureValueTypePersonalDetails:
            return .personalDetails(nativeName: nativeNames)
        case .secureValueTypePassport:
            return .passport(selfie: selfie, translation: translation)
        case .secureValueTypeInternalPassport:
            return .internalPassport(selfie: selfie, translation: translation)
        case .secureValueTypeDriverLicense:
            return .driversLicense(selfie: selfie, translation: translation)
        case .secureValueTypeIdentityCard:
            return .idCard(selfie: selfie, translation: translation)
        case .secureValueTypeAddress:
            return .address
        case .secureValueTypeUtilityBill:
            return .utilityBill(translation: translation)
        case .secureValueTypeBankStatement:
            return .bankStatement(translation: translation)
        case .secureValueTypeRentalAgreement:
            return .rentalAgreement(translation: translation)
        case .secureValueTypePhone:
            return .phone
        case .secureValueTypeEmail:
            return .email
        case .secureValueTypePassportRegistration:
            return .passportRegistration(translation: translation)
        case .secureValueTypeTemporaryRegistration:
            return .temporaryRegistration(translation: translation)
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

func parseSecureValue(context: SecureIdAccessContext, value: Api.SecureValue, errors: [Api.SecureValueError]) -> ParsedSecureValue? {
    switch value {
        case let .secureValue(_, type, data, frontSide, reverseSide, selfie, translation, files, plainData, hash):
            let parsedFileReferences = files.flatMap { $0.compactMap(SecureIdFileReference.init) } ?? []
            let parsedFiles = parsedFileReferences.map(SecureIdVerificationDocumentReference.remote)
            let parsedTranslationReferences = translation.flatMap { $0.compactMap(SecureIdFileReference.init) } ?? []
            let parsedTranslations = parsedTranslationReferences.map(SecureIdVerificationDocumentReference.remote)
            let parsedFrontSide = frontSide.flatMap(SecureIdFileReference.init).flatMap(SecureIdVerificationDocumentReference.remote)
            let parsedBackSide = reverseSide.flatMap(SecureIdFileReference.init).flatMap(SecureIdVerificationDocumentReference.remote)
            let parsedSelfie = selfie.flatMap(SecureIdFileReference.init).flatMap(SecureIdVerificationDocumentReference.remote)
            
            let decryptedData: Data?
            let encryptedMetadata: SecureIdEncryptedValueMetadata?
            var parsedFileMetadata: [SecureIdEncryptedValueFileMetadata] = []
            var parsedTranslationMetadata: [SecureIdEncryptedValueFileMetadata] = []
            var parsedSelfieMetadata: SecureIdEncryptedValueFileMetadata?
            var parsedFrontSideMetadata: SecureIdEncryptedValueFileMetadata?
            var parsedBackSideMetadata: SecureIdEncryptedValueFileMetadata?
            var contentsId: Data?
            if let data = data {
                let (encryptedData, decryptedHash, encryptedSecret) = parseSecureData(data)
                guard let valueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedSecret, decryptedDataHash: decryptedHash) else {
                    return nil
                }
                
                contentsId = decryptedHash
            
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
            for file in parsedTranslationReferences {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: file.fileHash, encryptedSecret: file.encryptedSecret) else {
                    return nil
                }
                parsedTranslationMetadata.append(SecureIdEncryptedValueFileMetadata(hash: file.fileHash, secret: fileSecret))
            }
            if let parsedSelfie = selfie.flatMap(SecureIdFileReference.init) {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: parsedSelfie.fileHash, encryptedSecret: parsedSelfie.encryptedSecret) else {
                    return nil
                }
                
                parsedSelfieMetadata = SecureIdEncryptedValueFileMetadata(hash: parsedSelfie.fileHash, secret: fileSecret)
            }
            if let parsedFrontSide = frontSide.flatMap(SecureIdFileReference.init) {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: parsedFrontSide.fileHash, encryptedSecret: parsedFrontSide.encryptedSecret) else {
                    return nil
                }
                
                parsedFrontSideMetadata = SecureIdEncryptedValueFileMetadata(hash: parsedFrontSide.fileHash, secret: fileSecret)
            }
            if let parsedBackSide = reverseSide.flatMap(SecureIdFileReference.init) {
                guard let fileSecret = decryptedSecureIdFileSecret(context: context, fileHash: parsedBackSide.fileHash, encryptedSecret: parsedBackSide.encryptedSecret) else {
                    return nil
                }
                
                parsedBackSideMetadata = SecureIdEncryptedValueFileMetadata(hash: parsedBackSide.fileHash, secret: fileSecret)
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
                    guard let passport = SecureIdPassportValue(dict: dict, fileReferences: parsedFiles, translations: parsedTranslations, selfieDocument: parsedSelfie, frontSideDocument: parsedFrontSide) else {
                        return nil
                    }
                    value = .passport(passport)
                case .secureValueTypeInternalPassport:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let internalPassport = SecureIdInternalPassportValue(dict: dict, fileReferences: parsedFiles, translations: parsedTranslations, selfieDocument: parsedSelfie, frontSideDocument: parsedFrontSide) else {
                        return nil
                    }
                    value = .internalPassport(internalPassport)
                case .secureValueTypeDriverLicense:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let driversLicense = SecureIdDriversLicenseValue(dict: dict, fileReferences: parsedFiles, translations: parsedTranslations, selfieDocument: parsedSelfie, frontSideDocument: parsedFrontSide, backSideDocument: parsedBackSide) else {
                        return nil
                    }
                    value = .driversLicense(driversLicense)
                case .secureValueTypeIdentityCard:
                    guard let dict = (try? JSONSerialization.jsonObject(with: decryptedData ?? Data(), options: [])) as? [String: Any] else {
                        return nil
                    }
                    guard let idCard = SecureIdIDCardValue(dict: dict, fileReferences: parsedFiles, translations: parsedTranslations, selfieDocument: parsedSelfie, frontSideDocument: parsedFrontSide, backSideDocument: parsedBackSide) else {
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
                case .secureValueTypePassportRegistration:
                    guard let passportRegistration = SecureIdPassportRegistrationValue(fileReferences: parsedFiles, translations: parsedTranslations) else {
                        return nil
                    }
                    value = .passportRegistration(passportRegistration)
                case .secureValueTypeTemporaryRegistration:
                    guard let temporaryRegistration = SecureIdTemporaryRegistrationValue(fileReferences: parsedFiles, translations: parsedTranslations) else {
                        return nil
                    }
                    value = .temporaryRegistration(temporaryRegistration)
                case .secureValueTypeUtilityBill:
                    guard let utilityBill = SecureIdUtilityBillValue(fileReferences: parsedFiles, translations: parsedTranslations) else {
                        return nil
                    }
                    value = .utilityBill(utilityBill)
                case .secureValueTypeBankStatement:
                    guard let bankStatement = SecureIdBankStatementValue(fileReferences: parsedFiles, translations: parsedTranslations) else {
                        return nil
                    }
                    value = .bankStatement(bankStatement)
                case .secureValueTypeRentalAgreement:
                    guard let rentalAgreement = SecureIdRentalAgreementValue(fileReferences: parsedFiles, translations: parsedTranslations) else {
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
        
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: value, errors: parseSecureIdValueContentErrors(dataHash: contentsId, fileHashes: Set(parsedFileMetadata.map { $0.hash } + parsedTranslationMetadata.map { $0.hash}), selfieHash: parsedSelfieMetadata?.hash, frontSideHash: parsedFrontSideMetadata?.hash, backSideHash: parsedBackSideMetadata?.hash, errors: errors), files: parsedFileMetadata, translations: parsedTranslationMetadata, selfie: parsedSelfieMetadata, frontSide: parsedFrontSideMetadata, backSide: parsedBackSideMetadata, encryptedMetadata: encryptedMetadata, opaqueHash: hash.makeData()))
    }
}

private func parseSecureValues(context: SecureIdAccessContext, values: [Api.SecureValue], errors: [Api.SecureValueError], requestedFields: [SecureIdRequestedFormField]) -> [SecureIdValueWithContext] {
    return values.map({ apiValue in
        return parseSecureValue(context: context, value: apiValue, errors: errors)
    }).compactMap({ $0?.valueWithContext })
}

public struct EncryptedSecureIdForm {
    public let peerId: PeerId
    public let requestedFields: [SecureIdRequestedFormField]
    public let termsUrl: String?
    
    let encryptedValues: [Api.SecureValue]
    let errors: [Api.SecureValueError]
}

public func requestSecureIdForm(postbox: Postbox, network: Network, peerId: PeerId, scope: String, publicKey: String) -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return .fail(.serverError("BOT_INVALID"))
    }
    if scope.isEmpty {
        return .fail(.serverError("SCOPE_EMPTY"))
    }
    if publicKey.isEmpty {
        return .fail(.serverError("PUBLIC_KEY_REQUIRED"))
    }
    return network.request(Api.functions.account.getAuthorizationForm(botId: peerId.id._internalGetInt64Value(), scope: scope, publicKey: publicKey))
    |> mapError { error -> RequestSecureIdFormError in
        switch error.errorDescription {
            case "APP_VERSION_OUTDATED":
                return .versionOutdated
            default:
                return .serverError(error.errorDescription)
        }        
    }
    |> mapToSignal { result -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> in
        return postbox.transaction { transaction -> EncryptedSecureIdForm in
            switch result {
                case let .authorizationForm(_, requiredTypes, values, errors, users, termsUrl):
                    var peers: [Peer] = []
                    for user in users {
                        let parsed = TelegramUser(user: user)
                        peers.append(parsed)
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                        return updated
                    })
                    
                    return EncryptedSecureIdForm(peerId: peerId, requestedFields: requiredTypes.map { requiredType in
                        switch requiredType {
                            case let .secureRequiredType(flags, type):
                                return .just(parseSecureValueType(type, selfie: (flags & 1 << 1) != 0, translation: (flags & 1 << 2) != 0, nativeNames: (flags & 1 << 0) != 0))
                            case let .secureRequiredTypeOneOf(types):
                                let parsedInnerTypes = types.compactMap { innerType -> SecureIdRequestedFormFieldValue? in
                                    switch innerType {
                                        case let .secureRequiredType(flags, type):
                                            return parseSecureValueType(type, selfie: (flags & 1 << 1) != 0, translation: (flags & 1 << 2) != 0, nativeNames: (flags & 1 << 0) != 0)
                                        case .secureRequiredTypeOneOf:
                                            return nil
                                    }
                                }
                                return .oneOf(parsedInnerTypes)
                        }
                    }, termsUrl: termsUrl, encryptedValues: values, errors: errors)
            }
        } |> mapError { _ -> RequestSecureIdFormError in }
    }
}

public func decryptedSecureIdForm(context: SecureIdAccessContext, form: EncryptedSecureIdForm) -> SecureIdForm? {
    return SecureIdForm(peerId: form.peerId, requestedFields: form.requestedFields, values: parseSecureValues(context: context, values: form.encryptedValues, errors: form.errors, requestedFields: form.requestedFields))
}
