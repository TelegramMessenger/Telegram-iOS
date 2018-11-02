import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramCoreMac
    import SwiftSignalKitMac
#else
    import Postbox
    import TelegramCore
    import SwiftSignalKit
#endif

public enum StandaloneUploadMediaError {
    case generic
}

public struct StandaloneUploadSecretFile {
    let file: Api.InputEncryptedFile
    let size: Int32
    let key: SecretFileEncryptionKey
}

public enum StandaloneUploadMediaResult {
    case media(AnyMediaReference)
}

public enum StandaloneUploadMediaEvent {
    case progress(Float)
    case result(StandaloneUploadMediaResult)
}

public func standaloneUploadedImage(account: Account, peerId: PeerId, text: String, data: Data, dimensions: CGSize) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: peerId.namespace == Namespaces.Peer.SecretChat, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
    |> mapToSignal { next -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
        switch next {
            case let .inputFile(inputFile):
                return account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                |> mapToSignal { inputPeer -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                    if let inputPeer = inputPeer {
                        return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil)))
                        |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                        |> mapToSignal { media -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                            switch media {
                                case let .messageMediaPhoto(_, photo, _):
                                    if let photo = photo {
                                        if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                                            return .single(.result(.media(.standalone(media: mediaImage))))
                                        }
                                    }
                                default:
                                    break
                            }
                            return .fail(.generic)
                        }
                    } else {
                        return .fail(.generic)
                    }
                }
            case let .inputSecretFile(file, _, key):
                return account.postbox.transaction { transaction -> Api.InputEncryptedChat? in
                    if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                        return Api.InputEncryptedChat.inputEncryptedChat(chatId: peer.id.id, accessHash: peer.accessHash)
                    }
                    return nil
                }
                |> introduceError(StandaloneUploadMediaError.self)
                |> mapToSignal { inputChat -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                    guard let inputChat = inputChat else {
                        return .fail(.generic)
                    }
                    return account.network.request(Api.functions.messages.uploadEncryptedFile(peer: inputChat, file: file))
                    |> mapError { _ -> StandaloneUploadMediaError in return .generic
                    }
                    |> mapToSignal { result -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                        switch result {
                            case let .encryptedFile(id, accessHash, size, dcId, _):
                                return .single(.result(.media(.standalone(media: TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64()), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: SecretFileMediaResource(fileId: id, accessHash: accessHash, containerSize: size, decryptedSize: Int32(data.count), datacenterId: Int(dcId), key: key))], reference: nil, partialReference: nil)))))
                            case .encryptedFileEmpty:
                                return .fail(.generic)
                        }
                    }
                }
            case let .progress(progress):
                return .single(.progress(progress))
        }
    }
}

public func standaloneUploadedFile(account: Account, peerId: PeerId, text: String, source: MultipartUploadSource, mimeType: String, attributes: [TelegramMediaFileAttribute]) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: source, encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(attributes)), hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> StandaloneUploadMediaError in return .generic }
        |> mapToSignal { next -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
            switch next {
            case let .inputFile(inputFile):
                return account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                    }
                    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                    |> mapToSignal { inputPeer -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                        if let inputPeer = inputPeer {
                            return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, thumb: nil, mimeType: mimeType, attributes: inputDocumentAttributesFromFileAttributes(attributes), stickers: nil, ttlSeconds: nil)))
                                |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                                |> mapToSignal { media -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                    switch media {
                                        case let .messageMediaDocument(_, document, _):
                                            if let document = document {
                                                if let mediaFile = telegramMediaFileFromApiDocument(document) {
                                                    return .single(.result(.media(.standalone(media: mediaFile))))
                                                }
                                            }
                                        default:
                                            break
                                    }
                                    return .fail(.generic)
                            }
                        } else {
                            return .fail(.generic)
                        }
                }
            case let .inputSecretFile(file, size, key):
                return account.postbox.transaction { transaction -> Api.InputEncryptedChat? in
                    if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                        return Api.InputEncryptedChat.inputEncryptedChat(chatId: peer.id.id, accessHash: peer.accessHash)
                    }
                    return nil
                    }
                    |> introduceError(StandaloneUploadMediaError.self)
                    |> mapToSignal { inputChat -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                        guard let inputChat = inputChat else {
                            return .fail(.generic)
                        }
                        return account.network.request(Api.functions.messages.uploadEncryptedFile(peer: inputChat, file: file))
                            |> mapError { _ -> StandaloneUploadMediaError in return .generic
                            }
                            |> mapToSignal { result -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                switch result {
                                case let .encryptedFile(id, accessHash, size, dcId, _):
                                    let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: SecretFileMediaResource(fileId: id, accessHash: accessHash, containerSize: size, decryptedSize: size, datacenterId: Int(dcId), key: key), previewRepresentations: [], mimeType: mimeType, size: Int(size), attributes: attributes)
                                    
                                    return .single(.result(.media(.standalone(media: media))))
                                case .encryptedFileEmpty:
                                    return .fail(.generic)
                                }
                        }
                }
            case let .progress(progress):
                return .single(.progress(progress))
            }
    }
}
