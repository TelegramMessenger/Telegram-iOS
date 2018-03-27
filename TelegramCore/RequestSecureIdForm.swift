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

//secureData data:bytes data_hash:bytes = SecureData;

private func parseSecureData(_ value: Api.SecureData) -> (data: Data, hash: Data) {
    switch value {
        case let .secureData(data, dataHash):
            return (data.makeData(), dataHash.makeData())
    }
}

private func parseSecureValue(context: SecureIdAccessContext, value: Api.SecureValue) -> SecureIdValue? {
    switch value {
        case let .secureValueIdentity(_, data, files, secret, hash, verified):
            let (encryptedData, encryptedHash) = parseSecureData(data)
            guard let decryptedData = decryptedSecureData(context: context, data: encryptedData, dataHash: encryptedHash, encryptedSecret: secret.makeData()) else {
                return nil
            }
            var fileReferences: [Int64: SecureIdFileReference] = [:]
            for file in files.map(SecureIdFileReference.init).flatMap({ $0 }) {
                fileReferences[file.id] = file
            }
            guard let value = SecureIdIdentityValue(data: decryptedData, fileReferences: fileReferences) else {
                return nil
            }
            return .identity(value)
        case let .secureValueAddress(_, data, files, secret, hash, verified):
            return nil
        case let .secureValuePhone(_, phone, hash, verified):
            guard let phoneData = phone.data(using: .utf8) else {
                return nil
            }
            if sha256Digest(phoneData) != hash.makeData() {
                return nil
            }
            return .phone(SecureIdPhoneValue(phone: phone))
        case let .secureValueEmail(_, email, hash, verified):
            guard let emailData = email.data(using: .utf8) else {
                return nil
            }
            if sha256Digest(emailData) != hash.makeData() {
                return nil
            }
            return .email(SecureIdEmailValue(email: email))
    }
}

private func parseSecureValues(context: SecureIdAccessContext, values: [Api.SecureValue]) -> [SecureIdValue] {
    return values.map({ parseSecureValue(context: context, value: $0) }).flatMap({ $0 })
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
                case let .authorizationForm(_, requiredTypes, values, users):
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
