import Foundation
import Postbox
import TelegramApi


func telegramMediaImageRepresentationsFromApiSizes(datacenterId: Int32, photoId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(type, w, h, _):
                let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: nil, fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
            case let .photoSize(type, w, h, size):
                let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: Int64(size), fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
            case let .photoSizeProgressive(type, w, h, sizes):
                if !sizes.isEmpty {
                    let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: Int64(sizes[sizes.count - 1]), fileReference: fileReference)
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: sizes, immediateThumbnailData: nil, hasVideo: false))
                }
            case let .photoStrippedSize(_, data):
                immediateThumbnailData = data.makeData()
            case .photoPathSize:
                break
            case .photoSizeEmpty:
                break
        }
    }
    return (immediateThumbnailData, representations)
}

func telegramMediaImageFromApiPhoto(_ photo: Api.Photo) -> TelegramMediaImage? {
    switch photo {
        case let .photo(flags, id, accessHash, fileReference, _, sizes, videoSizes, dcId):
            let (immediateThumbnailData, representations) = telegramMediaImageRepresentationsFromApiSizes(datacenterId: dcId, photoId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: sizes)
            var imageFlags: TelegramMediaImageFlags = []
            let hasStickers = (flags & (1 << 0)) != 0
            if hasStickers {
                imageFlags.insert(.hasStickers)
            }
            
            var videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []
            if let videoSizes = videoSizes {
                for size in videoSizes {
                    switch size {
                        case let .videoSize(_, type, w, h, size, videoStartTs):
                            let resource: TelegramMediaResource
                            resource = CloudPhotoSizeMediaResource(datacenterId: dcId, photoId: id, accessHash: accessHash, sizeSpec: type, size: Int64(size), fileReference: fileReference.makeData())
                            
                            videoRepresentations.append(TelegramMediaImage.VideoRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, startTimestamp: videoStartTs))
                    }
                }
            }
            
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: representations, videoRepresentations: videoRepresentations, immediateThumbnailData: immediateThumbnailData, reference: .cloud(imageId: id, accessHash: accessHash, fileReference: fileReference.makeData()), partialReference: nil, flags: imageFlags)
        case .photoEmpty:
            return nil
    }
}
