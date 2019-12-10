import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import SyncCore

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

public func stickerPacksAttachedToMedia(postbox: Postbox, network: Network, media: AnyMediaReference) -> Signal<[StickerPackReference], NoError> {
    let inputMedia: Api.InputStickeredMedia
    if let imageReference = media.concrete(TelegramMediaImage.self), let reference = imageReference.media.reference, case let .cloud(imageId, accessHash, fileReference) = reference {
        inputMedia = .inputStickeredMediaPhoto(id: Api.InputPhoto.inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference ?? Data())))
    } else if let fileReference = media.concrete(TelegramMediaFile.self), let resource = fileReference.media.resource as? CloudDocumentMediaResource {
        inputMedia = .inputStickeredMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data())))
    } else {
        return .single([])
    }
    return network.request(Api.functions.messages.getAttachedStickers(media: inputMedia))
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
