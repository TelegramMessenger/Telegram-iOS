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

private func generateCredentials(values: [SecureIdValueWithContext], opaquePayload: Data) -> Data? {
    var dict: [String: Any] = [:]
    for value in values {
        switch value.value {
            case .identity:
                guard let encryptedMetadata = value.encryptedMetadata else {
                    return nil
                }
                var identity: [String: Any] = [:]
                identity["data"] = ["data_hash": encryptedMetadata.valueDataHash.base64EncodedString()] as [String: Any]
                if !encryptedMetadata.fileHashes.isEmpty {
                    var files: [[String: Any]] = []
                    for fileHash in encryptedMetadata.fileHashes {
                        files.append(["file_hash": fileHash.base64EncodedString()])
                    }
                    identity["files"] = files
                }
                identity["secret"] = encryptedMetadata.valueSecret.base64EncodedString()
                dict["identity"] = identity
            case .address:
                guard let encryptedMetadata = value.encryptedMetadata else {
                    return nil
                }
                var identity: [String: Any] = [:]
                identity["data"] = ["data_hash": encryptedMetadata.valueDataHash.base64EncodedString()] as [String: Any]
                if !encryptedMetadata.fileHashes.isEmpty {
                    var files: [[String: Any]] = []
                    for fileHash in encryptedMetadata.fileHashes {
                        files.append(["file_hash": fileHash.base64EncodedString()])
                    }
                    identity["files"] = files
                }
                identity["secret"] = encryptedMetadata.valueSecret.base64EncodedString()
                dict["address"] = identity
            case .email, .phone:
                guard value.encryptedMetadata == nil else {
                    return nil
                }
        }
    }
    
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

private func valueHash(_ value: SecureIdValueWithContext) -> Api.SecureValueHash? {
    switch value.value {
        case let .identity(identity):
            guard let encryptedMetadata = value.encryptedMetadata else {
                return nil
            }
            guard let files = identity.serialize()?.1 else {
                return nil
            }
            
            var hashData = Data()
            hashData.append(encryptedMetadata.valueDataHash)
            hashData.append(encryptedMetadata.encryptedSecret)
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
            
            return .secureValueHash(type: .secureValueTypeIdentity, hash: Buffer(data: hash))
        case let .address(address):
            guard let encryptedMetadata = value.encryptedMetadata else {
                return nil
            }
            guard let files = address.serialize()?.1 else {
                return nil
            }
            
            var hashData = Data()
            hashData.append(encryptedMetadata.valueDataHash)
            hashData.append(encryptedMetadata.encryptedSecret)
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
            
            return .secureValueHash(type: .secureValueTypeAddress, hash: Buffer(data: hash))
        case let .phone(phone):
            guard let phoneData = phone.phone.data(using: .utf8) else {
                return nil
            }
            return .secureValueHash(type: .secureValueTypePhone, hash: Buffer(data: sha256Digest(phoneData)))
        case let .email(email):
            guard let emailData = email.email.data(using: .utf8) else {
                return nil
            }
            return .secureValueHash(type: .secureValueTypeEmail, hash: Buffer(data: sha256Digest(emailData)))
    }
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
        guard let hash = valueHash(value) else {
            return .fail(.generic)
        }
        valueHashes.append(hash)
    }
    
    return network.request(Api.functions.account.acceptAuthorization(botId: peerId.id, scope: scope, publicKey: publicKey, valueHashes: valueHashes, credentials: .secureCredentialsEncrypted(data: Buffer(data: encryptedCredentialsData), hash: Buffer(data: decryptedCredentialsHash), secret: Buffer(data: encryptedSecretData))))
    |> mapError { _ -> GrantSecureIdAccessError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, GrantSecureIdAccessError> in
        return .complete()
    }
}
