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

func telegramMediaImageRepresentationsFromApiSizes(datacenterId: Int32, photoId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoStrippedSize(_, data):
                immediateThumbnailData = data.makeData()
            case .photoSizeEmpty:
                break
        }
    }
    return (immediateThumbnailData, representations)
}

func telegramMediaImageFromApiPhoto(_ photo: Api.Photo) -> TelegramMediaImage? {
    switch photo {
        case let .photo(_, id, accessHash, fileReference, _, sizes, dcId):
            let (immediateThumbnailData, representations) = telegramMediaImageRepresentationsFromApiSizes(datacenterId: dcId, photoId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: sizes)
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: representations, immediateThumbnailData: immediateThumbnailData, reference: .cloud(imageId: id, accessHash: accessHash, fileReference: fileReference.makeData()), partialReference: nil)
        case .photoEmpty:
            return nil
    }
}
