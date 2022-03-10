import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit


public enum StandaloneUploadMediaError {
    case generic
}

public struct StandaloneUploadSecretFile {
    let file: Api.InputEncryptedFile
    let size: Int32
    let key: SecretFileEncryptionKey
}

public enum StandaloneUploadMediaThumbnailResult {
    case pending
    case file(Api.InputFile)
    case none
    
    var file: Api.InputFile? {
        if case let .file(file) = self {
            return file
        } else {
            return nil
        }
    }
}

public enum StandaloneUploadMediaResult {
    case media(AnyMediaReference)
}

public enum StandaloneUploadMediaEvent {
    case progress(Float)
    case result(StandaloneUploadMediaResult)
}

private func uploadedThumbnail(network: Network, postbox: Postbox, data: Data) -> Signal<Api.InputFile?, StandaloneUploadMediaError> {
    return multipartUpload(network: network, postbox: postbox, source: .data(data), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
    |> mapToSignal { result -> Signal<Api.InputFile?, StandaloneUploadMediaError> in
        switch result {
            case .progress:
                return .complete()
            case let .inputFile(inputFile):
                return .single(inputFile)
            case .inputSecretFile:
                return .single(nil)
        }
    }
}

public func standaloneUploadedImage(account: Account, peerId: PeerId, text: String, data: Data, thumbnailData: Data? = nil, dimensions: PixelDimensions) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: peerId.namespace == Namespaces.Peer.SecretChat, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
    |> mapToSignal { next -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
        switch next {
            case let .inputFile(inputFile):
                return account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapError { _ -> StandaloneUploadMediaError in }
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
                        return Api.InputEncryptedChat.inputEncryptedChat(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: peer.accessHash)
                    }
                    return nil
                }
                |> castError(StandaloneUploadMediaError.self)
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
                                return .single(.result(.media(.standalone(media: TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: SecretFileMediaResource(fileId: id, accessHash: accessHash, containerSize: size, decryptedSize: Int32(data.count), datacenterId: Int(dcId), key: key), progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])))))
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

public func standaloneUploadedFile(account: Account, peerId: PeerId, text: String, source: MultipartUploadSource, thumbnailData: Data? = nil, mimeType: String, attributes: [TelegramMediaFileAttribute], hintFileIsLarge: Bool) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    let upload = multipartUpload(network: account.network, postbox: account.postbox, source: source, encrypt: peerId.namespace == Namespaces.Peer.SecretChat, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(attributes)), hintFileSize: nil, hintFileIsLarge: hintFileIsLarge, forceNoBigParts: false)
    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
    
    let uploadThumbnail: Signal<StandaloneUploadMediaThumbnailResult, StandaloneUploadMediaError>
    if let thumbnailData = thumbnailData {
        uploadThumbnail = .single(.pending)
        |> then(
            uploadedThumbnail(network: account.network, postbox: account.postbox, data: thumbnailData)
            |> mapError { _ -> StandaloneUploadMediaError in return .generic }
            |> map { result in
                if let result = result {
                    return .file(result)
                } else {
                    return .none
                }
            }
        )
    } else {
        uploadThumbnail = .single(.none)
    }
    
    return combineLatest(upload, uploadThumbnail)
    |> mapToSignal { result, thumbnail in
        switch result {
            case let .progress(progress):
                return .single(.progress(progress))
            default:
                switch thumbnail {
                    case .pending:
                        return .complete()
                    default:
                        switch result {
                            case let .inputFile(inputFile):
                                return account.postbox.transaction { transaction -> Api.InputPeer? in
                                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                                    }
                                |> mapError { _ -> StandaloneUploadMediaError in }
                                |> mapToSignal { inputPeer -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                    if let inputPeer = inputPeer {
                                        var flags: Int32 = 0
                                        let thumbnailFile = thumbnail.file
                                        if let _ = thumbnailFile {
                                            flags |= 1 << 2
                                        }
                                        return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedDocument(flags: flags, file: inputFile, thumb: thumbnailFile, mimeType: mimeType, attributes: inputDocumentAttributesFromFileAttributes(attributes), stickers: nil, ttlSeconds: nil)))
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
                            case let .inputSecretFile(file, _, key):
                                return account.postbox.transaction { transaction -> Api.InputEncryptedChat? in
                                    if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                                        return Api.InputEncryptedChat.inputEncryptedChat(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: peer.accessHash)
                                    }
                                    return nil
                                }
                                |> castError(StandaloneUploadMediaError.self)
                                |> mapToSignal { inputChat -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                    guard let inputChat = inputChat else {
                                        return .fail(.generic)
                                    }
                                    return account.network.request(Api.functions.messages.uploadEncryptedFile(peer: inputChat, file: file))
                                    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                                    |> mapToSignal { result -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                        switch result {
                                            case let .encryptedFile(id, accessHash, size, dcId, _):
                                                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: SecretFileMediaResource(fileId: id, accessHash: accessHash, containerSize: size, decryptedSize: size, datacenterId: Int(dcId), key: key), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: attributes)

                                                return .single(.result(.media(.standalone(media: media))))
                                            case .encryptedFileEmpty:
                                                return .fail(.generic)
                                        }
                                    }
                                }
                            case .progress:
                                return .never()
                        }
                }
        }
    }
}
