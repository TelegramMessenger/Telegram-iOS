import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import SyncCore
import MtProtoKit

func telegramStickerPachThumbnailRepresentationFromApiSize(datacenterId: Int32, size: Api.PhotoSize) -> TelegramMediaImageRepresentation? {
    switch size {
        case let .photoCachedSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource)
            }
        case let .photoSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource)
            }
        case .photoStrippedSize:
            return nil
        case .photoSizeEmpty:
            return nil
    }
}

extension StickerPackCollectionInfo {
    convenience init(apiSet: Api.StickerSet, namespace: ItemCollectionId.Namespace) {
        switch apiSet {
            case let .stickerSet(flags, _, id, accessHash, title, shortName, thumb, thumbDcId, count, nHash):
                var setFlags: StickerPackCollectionInfoFlags = StickerPackCollectionInfoFlags()
                if (flags & (1 << 2)) != 0 {
                    setFlags.insert(.isOfficial)
                }
                if (flags & (1 << 3)) != 0 {
                    setFlags.insert(.isMasks)
                }
                if (flags & (1 << 5)) != 0 {
                    setFlags.insert(.isAnimated)
                }
                
                var thumbnailRepresentation: TelegramMediaImageRepresentation?
                if let thumb = thumb, let thumbDcId = thumbDcId {
                    thumbnailRepresentation = telegramStickerPachThumbnailRepresentationFromApiSize(datacenterId: thumbDcId, size: thumb)
                }
                
                self.init(id: ItemCollectionId(namespace: namespace, id: id), flags: setFlags, accessHash: accessHash, title: title, shortName: shortName, thumbnail: thumbnailRepresentation, hash: nHash, count: count)
        }
    }
}

public func stickerPacksAttachedToMedia(account: Account, media: AnyMediaReference) -> Signal<[StickerPackReference], NoError> {
    let inputMedia: Api.InputStickeredMedia
    let resourceReference: MediaResourceReference
    if let imageReference = media.concrete(TelegramMediaImage.self), let reference = imageReference.media.reference, case let .cloud(imageId, accessHash, fileReference) = reference, let representation = largestImageRepresentation(imageReference.media.representations) {
        inputMedia = .inputStickeredMediaPhoto(id: Api.InputPhoto.inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference ?? Data())))
        resourceReference = imageReference.resourceReference(representation.resource)
    } else if let fileReference = media.concrete(TelegramMediaFile.self), let resource = fileReference.media.resource as? CloudDocumentMediaResource {
        inputMedia = .inputStickeredMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data())))
        resourceReference = fileReference.resourceReference(fileReference.media.resource)
    } else {
        return .single([])
    }
    return account.network.request(Api.functions.messages.getAttachedStickers(media: inputMedia))
    |> `catch` { _ -> Signal<[Api.StickerSetCovered], MTRpcError> in
        return revalidateMediaResourceReference(postbox: account.postbox, network: account.network, revalidationContext: account.mediaReferenceRevalidationContext, info: TelegramCloudMediaResourceFetchInfo(reference: resourceReference, preferBackgroundReferenceRevalidation: false, continueInBackground: false), resource: resourceReference.resource)
        |> mapError { _ -> MTRpcError in
            return MTRpcError(errorCode: 500, errorDescription: "Internal")
        }
        |> mapToSignal { reference -> Signal<[Api.StickerSetCovered], MTRpcError> in
            let inputMedia: Api.InputStickeredMedia
            if let resource = reference.updatedResource as? TelegramCloudMediaResourceWithFileReference, let updatedReference = resource.fileReference {
                if let imageReference = media.concrete(TelegramMediaImage.self), let reference = imageReference.media.reference, case let .cloud(imageId, accessHash, fileReference) = reference, let representation = largestImageRepresentation(imageReference.media.representations) {
                    inputMedia = .inputStickeredMediaPhoto(id: Api.InputPhoto.inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: updatedReference ?? Data())))
                } else if let fileReference = media.concrete(TelegramMediaFile.self), let resource = fileReference.media.resource as? CloudDocumentMediaResource {
                    inputMedia = .inputStickeredMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: updatedReference ?? Data())))
                } else {
                    return .single([])
                }
                return account.network.request(Api.functions.messages.getAttachedStickers(media: inputMedia))
            } else {
                return .single([])
            }
        }
        |> `catch` { _ -> Signal<[Api.StickerSetCovered], MTRpcError> in
            return .single([])
        }
    }
    |> map { result -> [StickerPackReference] in
        return result.map { pack in
            switch pack {
            case let .stickerSetCovered(set, _), let .stickerSetMultiCovered(set, _):
                let info = StickerPackCollectionInfo(apiSet: set, namespace: Namespaces.ItemCollection.CloudStickerPacks)
                return .id(id: info.id.id, accessHash: info.accessHash)
            }
        }
    }
    |> `catch` { _ -> Signal<[StickerPackReference], NoError> in
        return .single([])
    }
}
