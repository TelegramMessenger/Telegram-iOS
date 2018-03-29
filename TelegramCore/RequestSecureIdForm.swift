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
}

private func parseSecureValueType(_ type: Api.SecureValueType) -> SecureIdRequestedFormField {
    switch type {
        case .secureValueTypeIdentity:
            return .identity
        case .secureValueTypeAddress:
            return .address
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
    let hash: Data
}

func parseSecureValue(context: SecureIdAccessContext, value: Api.SecureValue) -> ParsedSecureValue? {
    switch value {
        case let .secureValueIdentity(_, data, files, hash, verified):
            let (encryptedData, decryptedHash, encryptedSecret) = parseSecureData(data)
            guard let valueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedSecret, decryptedDataHash: decryptedHash) else {
                return nil
            }
            
            let parsedFileReferences = files.map(SecureIdFileReference.init).flatMap({ $0 })
            let parsedFileHashes = parsedFileReferences.map { $0.fileHash }
            let parsedFiles = parsedFileReferences.map(SecureIdVerificationDocumentReference.remote)
            
            guard let decryptedData = decryptedSecureValueData(context: valueContext, encryptedData: encryptedData, decryptedDataHash: decryptedHash) else {
                return nil
            }
            guard let value = SecureIdIdentityValue(data: decryptedData, fileReferences: parsedFiles) else {
                return nil
            }
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: .identity(value), context: valueContext, encryptedMetadata: SecureIdEncryptedValueMetadata(valueDataHash: decryptedHash, fileHashes: parsedFileHashes, valueSecret: valueContext.secret, hash: hash.makeData())), hash: hash.makeData())
        case let .secureValueAddress(_, data, files, hash, verified):
            let (encryptedData, decryptedHash, encryptedSecret) = parseSecureData(data)
            guard let valueContext = decryptedSecureValueAccessContext(context: context, encryptedSecret: encryptedSecret, decryptedDataHash: decryptedHash) else {
                return nil
            }
            
            let parsedFileReferences = files.map(SecureIdFileReference.init).flatMap({ $0 })
            let parsedFileHashes = parsedFileReferences.map { $0.fileHash }
            let parsedFiles = parsedFileReferences.map(SecureIdVerificationDocumentReference.remote)
            
            guard let decryptedData = decryptedSecureValueData(context: valueContext, encryptedData: encryptedData, decryptedDataHash: decryptedHash) else {
                return nil
            }
            guard let value = SecureIdAddressValue(data: decryptedData, fileReferences: parsedFiles) else {
                return nil
            }
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: .address(value), context: valueContext, encryptedMetadata: SecureIdEncryptedValueMetadata(valueDataHash: decryptedHash, fileHashes: parsedFileHashes, valueSecret: valueContext.secret, hash: hash.makeData())), hash: hash.makeData())
        case let .secureValuePhone(_, phone, hash, verified):
            guard let phoneData = phone.data(using: .utf8) else {
                return nil
            }
            if sha256Digest(phoneData) != hash.makeData() {
                return nil
            }
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: .phone(SecureIdPhoneValue(phone: phone)), context: SecureIdValueAccessContext(secret: Data(), id: 0), encryptedMetadata: nil), hash: hash.makeData())
        case let .secureValueEmail(_, email, hash, verified):
            guard let emailData = email.data(using: .utf8) else {
                return nil
            }
            if sha256Digest(emailData) != hash.makeData() {
                return nil
            }
            return ParsedSecureValue(valueWithContext: SecureIdValueWithContext(value: .email(SecureIdEmailValue(email: email)), context: SecureIdValueAccessContext(secret: Data(), id: 0), encryptedMetadata: nil), hash: hash.makeData())
    }
}

private func parseSecureValues(context: SecureIdAccessContext, values: [Api.SecureValue]) -> [SecureIdValueWithContext] {
    return values.map({ parseSecureValue(context: context, value: $0) }).flatMap({ $0?.valueWithContext })
}

public struct EncryptedSecureIdForm {
    public let peerId: PeerId
    public let requestedFields: [SecureIdRequestedFormField]
    
    let encryptedValues: [Api.SecureValue]
}

public func requestSecureIdForm(postbox: Postbox, network: Network, peerId: PeerId, scope: String, publicKey: String) -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return .fail(.generic)
    }
    return network.request(Api.functions.account.getAuthorizationForm(botId: peerId.id, scope: scope, publicKey: publicKey))
    |> mapError { _ -> RequestSecureIdFormError in
        return .generic
    }
    |> mapToSignal { result -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> in
        return postbox.modify { modifier -> EncryptedSecureIdForm in
            switch result {
                case let .authorizationForm(requiredTypes, values, users):
                    var peers: [Peer] = []
                    for user in users {
                        let parsed = TelegramUser(user: user)
                        peers.append(parsed)
                    }
                    updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                        return updated
                    })
                    
                    return EncryptedSecureIdForm(peerId: peerId, requestedFields: requiredTypes.map(parseSecureValueType), encryptedValues: values)
            }
        } |> mapError { _ in return RequestSecureIdFormError.generic }
    }
}

public func decryptedSecureIdForm(context: SecureIdAccessContext, form: EncryptedSecureIdForm) -> SecureIdForm? {
    return SecureIdForm(peerId: form.peerId, requestedFields: form.requestedFields, values: parseSecureValues(context: context, values: form.encryptedValues))
}
