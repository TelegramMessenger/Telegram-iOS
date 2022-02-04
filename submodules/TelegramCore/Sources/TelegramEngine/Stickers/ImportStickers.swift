import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


public enum UploadStickerStatus {
    case progress(Float)
    case complete(CloudDocumentMediaResource, String)
}

public enum UploadStickerError {
    case generic
}

private struct UploadedStickerData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedStickerDataContent
}

private enum UploadedStickerDataContent {
    case result(MultipartUploadResult)
    case error
}

private func uploadedSticker(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedStickerData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .file), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
    |> map { result -> UploadedStickerData in
        return UploadedStickerData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedStickerData, NoError> in
        return .single(UploadedStickerData(resource: resource, content: .error))
    }
}

func _internal_uploadSticker(account: Account, peer: Peer, resource: MediaResource, alt: String, dimensions: PixelDimensions, mimeType: String) -> Signal<UploadStickerStatus, UploadStickerError> {
    guard let inputPeer = apiInputPeer(peer) else {
        return .fail(.generic)
    }
    return uploadedSticker(postbox: account.postbox, network: account.network, resource: resource)
    |> mapError { _ -> UploadStickerError in }
    |> mapToSignal { result -> Signal<UploadStickerStatus, UploadStickerError> in
        switch result.content {
            case .error:
                return .fail(.generic)
            case let .result(resultData):
                switch resultData {
                    case let .progress(progress):
                        return .single(.progress(progress))
                    case let .inputFile(file):
                        let flags: Int32 = 0
                        var attributes: [Api.DocumentAttribute] = []
                        attributes.append(.documentAttributeSticker(flags: 0, alt: alt, stickerset: .inputStickerSetEmpty, maskCoords: nil))
                        attributes.append(.documentAttributeImageSize(w: dimensions.width, h: dimensions.height))
                        return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedDocument(flags: flags, file: file, thumb: nil, mimeType: mimeType, attributes: attributes, stickers: nil, ttlSeconds: nil)))
                        |> mapError { _ -> UploadStickerError in return .generic }
                        |> mapToSignal { media -> Signal<UploadStickerStatus, UploadStickerError> in
                            switch media {
                                case let .messageMediaDocument(_, document, _):
                                    if let document = document, let file = telegramMediaFileFromApiDocument(document), let resource = file.resource as? CloudDocumentMediaResource {
                                        return .single(.complete(resource, file.mimeType))
                                    }
                                default:
                                    break
                            }
                            return .fail(.generic)
                        }
                    default:
                        return .fail(.generic)
                }
        }
    }
}

public enum CreateStickerSetError {
    case generic
}

public struct ImportSticker {
    public let resource: MediaResource
    let emojis: [String]
    public let dimensions: PixelDimensions
    public let mimeType: String
    
    public init(resource: MediaResource, emojis: [String], dimensions: PixelDimensions, mimeType: String) {
        self.resource = resource
        self.emojis = emojis
        self.dimensions = dimensions
        self.mimeType = mimeType
    }
}

public enum CreateStickerSetStatus {
    case progress(Float, Int32, Int32)
    case complete(StickerPackCollectionInfo, [StickerPackItem])
}

public enum CreateStickerSetType {
    case image
    case animation
    case video
}

func _internal_createStickerSet(account: Account, title: String, shortName: String, stickers: [ImportSticker], thumbnail: ImportSticker?, type: CreateStickerSetType, software: String?) -> Signal<CreateStickerSetStatus, CreateStickerSetError> {
    return account.postbox.loadedPeerWithId(account.peerId)
    |> castError(CreateStickerSetError.self)
    |> mapToSignal { peer -> Signal<CreateStickerSetStatus, CreateStickerSetError> in
        guard let inputUser = apiInputUser(peer) else {
            return .fail(.generic)
        }
        var uploadStickers: [Signal<UploadStickerStatus, CreateStickerSetError>] = []
        var stickers = stickers
        if let thumbnail = thumbnail {
            stickers.append(thumbnail)
        }
        for sticker in stickers {
            if let resource = sticker.resource as? CloudDocumentMediaResource {
                uploadStickers.append(.single(.complete(resource, sticker.mimeType)))
            } else {
                uploadStickers.append(_internal_uploadSticker(account: account, peer: peer, resource: sticker.resource, alt: sticker.emojis.first ?? "", dimensions: sticker.dimensions, mimeType: sticker.mimeType)
                |> mapError { _ -> CreateStickerSetError in
                    return .generic
                })
            }
        }
        return combineLatest(uploadStickers)
        |> mapToSignal { uploadedStickers -> Signal<CreateStickerSetStatus, CreateStickerSetError> in
            var resources: [CloudDocumentMediaResource] = []
            for sticker in uploadedStickers {
                if case let .complete(resource, _) = sticker {
                    resources.append(resource)
                }
            }
            if resources.count == stickers.count {
                var flags: Int32 = 0
                switch type {
                    case .animation:
                        flags |= (1 << 1)
                    case .video:
                        flags |= (1 << 4)
                    default:
                        break
                }
                var inputStickers: [Api.InputStickerSetItem] = []
                let stickerDocuments = thumbnail != nil ? resources.dropLast() : resources
                for i in 0 ..< stickerDocuments.count {
                    let sticker = stickers[i]
                    let resource = resources[i]
                    inputStickers.append(.inputStickerSetItem(flags: 0, document: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data())), emoji: sticker.emojis.first ?? "", maskCoords: nil))
                }
                var thumbnailDocument: Api.InputDocument?
                if thumbnail != nil, let resource = resources.last {
                    flags |= (1 << 2)
                    thumbnailDocument = .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data()))
                }
                if let software = software, !software.isEmpty {
                    flags |= (1 << 3)
                }
                return account.network.request(Api.functions.stickers.createStickerSet(flags: flags, userId: inputUser, title: title, shortName: shortName, thumb: thumbnailDocument, stickers: inputStickers, software: software))
                |> mapError { error -> CreateStickerSetError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<CreateStickerSetStatus, CreateStickerSetError> in
                    let info: StickerPackCollectionInfo
                    var items: [StickerPackItem] = []
                    
                    switch result {
                    case .stickerSetNotModified:
                        return .complete()
                    case let .stickerSet(set, packs, documents):
                        let namespace: ItemCollectionId.Namespace
                        switch set {
                            case let .stickerSet(flags, _, _, _, _, _, _, _, _, _, _):
                                if (flags & (1 << 3)) != 0 {
                                    namespace = Namespaces.ItemCollection.CloudMaskPacks
                                } else {
                                    namespace = Namespaces.ItemCollection.CloudStickerPacks
                                }
                        }
                        info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
                        var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
                        for pack in packs {
                            switch pack {
                                case let .stickerPack(text, fileIds):
                                    let key = ValueBoxKey(text).toMemoryBuffer()
                                    for fileId in fileIds {
                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                        if indexKeysByFile[mediaId] == nil {
                                            indexKeysByFile[mediaId] = [key]
                                        } else {
                                            indexKeysByFile[mediaId]!.append(key)
                                        }
                                    }
                            }
                        }
                        
                        for apiDocument in documents {
                            if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                                let fileIndexKeys: [MemoryBuffer]
                                if let indexKeys = indexKeysByFile[id] {
                                    fileIndexKeys = indexKeys
                                } else {
                                    fileIndexKeys = []
                                }
                                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: fileIndexKeys))
                            }
                        }
                    }
                    return .single(.complete(info, items))
                }
            } else {
                var totalProgress: Float = 0.0
                var completeCount: Int32 = 0
                for sticker in uploadedStickers {
                    switch sticker {
                        case .complete:
                            totalProgress += 1.0
                            completeCount += 1
                        case let .progress(progress):
                            totalProgress += progress
                            if progress == 1.0 {
                                completeCount += 1
                            }
                    }
                }
                let normalizedProgress = min(1.0, max(0.0, totalProgress / Float(stickers.count)))
                return .single(.progress(normalizedProgress, completeCount, Int32(uploadedStickers.count)))
            }
        }
    }
}

func _internal_getStickerSetShortNameSuggestion(account: Account, title: String) -> Signal<String?, NoError> {
    return account.network.request(Api.functions.stickers.suggestShortName(title: title))
    |> map (Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
    |> map { result in
        guard let result = result else {
            return nil
        }
        switch result {
            case let .suggestedShortName(shortName):
                return shortName
        }
    }
}

func _internal_stickerSetShortNameAvailability(account: Account, shortName: String) -> Signal<AddressNameAvailability, NoError> {
    return account.network.request(Api.functions.stickers.checkShortName(shortName: shortName))
    |> map { result -> AddressNameAvailability in
        switch result {
            case .boolTrue:
                return .available
            case .boolFalse:
                return .taken
        }
    }
    |> `catch` { error -> Signal<AddressNameAvailability, NoError> in
        if error.errorDescription == "SHORT_NAME_OCCUPIED" {
            return .single(.taken)
        }
        return .single(.invalid)
    }
}
