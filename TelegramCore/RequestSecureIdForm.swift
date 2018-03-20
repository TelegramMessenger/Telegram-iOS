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

private func parseFieldType(_ type: Api.AuthFieldType) -> SecureIdFieldType {
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

private func parseValue(_ value: Api.SecureValue) -> SecureIdFieldValue {
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
}

private func parseField(_ field: Api.AuthField) -> SecureIdField {
    switch field {
        case let .authField(_, type, data, document):
            return SecureIdField(type: parseFieldType(type), value: parseValue(data))
    }
}

public func requestSecureIdForm(postbox: Postbox, network: Network, peerId: PeerId, scope: [String], origin: String?, packageName: String?, bundleId: String?, publicKey: String?) -> Signal<SecureIdForm, RequestSecureIdFormError> {
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
    |> mapToSignal { result -> Signal<SecureIdForm, RequestSecureIdFormError> in
        return postbox.modify { modifier -> SecureIdForm in
            switch result {
                case let .authorizationForm(_, botId, fields, acceptedFields, users):
                    var peers: [Peer] = []
                    for user in users {
                        let parsed = TelegramUser(user: user)
                        peers.append(parsed)
                    }
                    updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                        return updated
                    })
                    
                    let parsedFields = fields.map(parseField)
                
                    return SecureIdForm(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: botId), fields: parsedFields)
            }
        } |> mapError { _ in return RequestSecureIdFormError.generic }
    }
}
