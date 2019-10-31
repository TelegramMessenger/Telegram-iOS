import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import UIKit
    import TelegramApi
#endif

import SyncCore

func telegramStickerPachThumbnailRepresentationFromApiSize(datacenterId: Int32, size: Api.PhotoSize) -> TelegramMediaImageRepresentation? {
    switch size {
        case let .photoCachedSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource)
            }
        case let .photoSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource)
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
