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

public enum RequestedSecureIdField {
    case identity
    case address
    case phone
    case email
}

private func parseRequestedFieldType(_ type: Api.AuthFieldType) -> RequestedSecureIdField {
    switch type {
        case .authFieldTypeIdentity:
            return .identity
        case .authFieldTypeAddress:
            return .address
        case .authFieldTypePhone:
            return .phone
        case .authFieldTypeEmail:
            return .email
    }
}

private func parseFileReference(_ file: Api.SecureFile) -> SecureIdFileReference {
    switch file {
        case .secureFileEmpty:
            return .none
        case let .secureFile(id, accessHash, size, dcId, fileHash):
            return .file(id: id, accessHash: accessHash, size: size, datacenterId: dcId, fileHash: fileHash)
    }
}

/*private func parseValue(_ value: Api.SecureValue) -> SecureIdFieldValue {
    switch value {
        case let .secureValueEmpty(name):
            return SecureIdFieldValue(name: name, data: .none)
        case let .secureValueData(name, data, hash, secret):
            return SecureIdFieldValue(name: name, data: .data(data: data.makeData(), hash: hash, secret: secret.makeData()))
        case let .secureValueFile(name, file, hash, secret):
            return SecureIdFieldValue(name: name, data: .files(files: file.map(parseFileReference), hash: hash, secret: secret.makeData()))
        case let .secureValueText(name, text, hash):
            return SecureIdFieldValue(name: name, data: .text(text: text, hash: hash))
    }
}*/

private func parseIdentityField(context: SecureIdAccessContext, value: Api.SecureValue, document: Api.SecureValue?) -> SecureIdIdentityField? {
    switch value {
        case let .secureValueData(name, data, hash, secret):
            return nil
        default:
            return nil
    }
}

private func parsePhoneField(context: SecureIdAccessContext, value: Api.SecureValue) -> SecureIdPhoneField? {
    switch value {
        case let .secureValueText(name, text, _):
            return SecureIdPhoneField(rawValue: text)
        default:
            return nil
    }
}

private func parseEmailField(context: SecureIdAccessContext, value: Api.SecureValue) -> SecureIdEmailField? {
    switch value {
        case let .secureValueText(name, text, _):
            return SecureIdEmailField(rawValue: text)
        default:
            return nil
    }
}

private func parseFields(context: SecureIdAccessContext, fields: [Api.AuthField]) -> SecureIdFields {
    var result = SecureIdFields(identity: nil, phone: nil, email: nil)
    for field in fields {
        switch field {
            case let .authField(_, type, data, document):
                switch type {
                    case .authFieldTypeIdentity:
                        if let identity = parseIdentityField(context: context, value: data, document: document) {
                            result.identity = .value(identity)
                        } else {
                            result.identity = .empty
                        }
                    case .authFieldTypeAddress:
                        break
                    case .authFieldTypePhone:
                        if let phone = parsePhoneField(context: context, value: data) {
                            result.phone = .value(phone)
                        } else {
                            result.phone = .empty
                        }
                    case .authFieldTypeEmail:
                        if let email = parseEmailField(context: context, value: data) {
                            result.email = .value(email)
                        } else {
                            result.email = .empty
                        }
                }
        }
    }
    return result
}

public struct EncryptedSecureIdForm {
    public let peerId: PeerId
    public let requestedFields: [RequestedSecureIdField]
    
    let encryptedFields: [Api.AuthField]
}

public func requestSecureIdForm(postbox: Postbox, network: Network, peerId: PeerId, scope: [String], origin: String?, packageName: String?, bundleId: String?, publicKey: String?) -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return .fail(.generic)
    }
    var flags: Int32 = 0
    if let _ = origin {
        flags |= 1 << 0
    }
    if let _ = packageName {
        flags |= 1 << 1
    }
    if let _ = bundleId {
        flags |= 1 << 2
    }
    if let _ = publicKey {
        flags |= 1 << 3
    }
    return network.request(Api.functions.account.getAuthorizationForm(flags: flags, botId: peerId.id, scope: scope, origin: origin, packageName: packageName, bundleId: bundleId, publicKey: publicKey))
    |> mapError { _ -> RequestSecureIdFormError in
        return .generic
    }
    |> mapToSignal { result -> Signal<EncryptedSecureIdForm, RequestSecureIdFormError> in
        return postbox.modify { modifier -> EncryptedSecureIdForm in
            switch result {
                case let .authorizationForm(_, botId, fields, _, users):
                    var peers: [Peer] = []
                    for user in users {
                        let parsed = TelegramUser(user: user)
                        peers.append(parsed)
                    }
                    updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                        return updated
                    })
                    
                    return EncryptedSecureIdForm(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: botId), requestedFields: fields.map { field -> RequestedSecureIdField in
                        switch field {
                            case let .authField(_, type, data, document):
                                return parseRequestedFieldType(type)
                        }
                    }, encryptedFields: fields)
            }
        } |> mapError { _ in return RequestSecureIdFormError.generic }
    }
}

public func decryptedSecureIdForm(context: SecureIdAccessContext, form: EncryptedSecureIdForm) -> SecureIdForm? {
    return SecureIdForm(peerId: form.peerId, fields: parseFields(context: context, fields: form.encryptedFields))
}
