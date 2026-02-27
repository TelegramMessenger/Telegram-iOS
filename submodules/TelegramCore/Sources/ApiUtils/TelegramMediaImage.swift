import Foundation
import Postbox
import TelegramApi


func telegramMediaImageRepresentationsFromApiSizes(datacenterId: Int32, photoId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(photoCachedSizeData):
                let (type, w, h) = (photoCachedSizeData.type, photoCachedSizeData.w, photoCachedSizeData.h)
                let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: nil, fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
            case let .photoSize(photoSizeData):
                let (type, w, h, size) = (photoSizeData.type, photoSizeData.w, photoSizeData.h, photoSizeData.size)
                let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: Int64(size), fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
            case let .photoSizeProgressive(photoSizeProgressiveData):
                let (type, w, h, sizes) = (photoSizeProgressiveData.type, photoSizeProgressiveData.w, photoSizeProgressiveData.h, photoSizeProgressiveData.sizes)
                if !sizes.isEmpty {
                    let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, size: Int64(sizes[sizes.count - 1]), fileReference: fileReference)
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: sizes, immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                }
            case let .photoStrippedSize(photoStrippedSizeData):
                let data = photoStrippedSizeData.bytes
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
        case let .photo(photoData):
            let (flags, id, accessHash, fileReference, sizes, videoSizes, dcId) = (photoData.flags, photoData.id, photoData.accessHash, photoData.fileReference, photoData.sizes, photoData.videoSizes, photoData.dcId)
            let (immediateThumbnailData, representations) = telegramMediaImageRepresentationsFromApiSizes(datacenterId: dcId, photoId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: sizes)
            var imageFlags: TelegramMediaImageFlags = []
            let hasStickers = (flags & (1 << 0)) != 0
            if hasStickers {
                imageFlags.insert(.hasStickers)
            }
            
            var videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []
            var emojiMarkup: TelegramMediaImage.EmojiMarkup?
            if let videoSizes = videoSizes {
                for size in videoSizes {
                    switch size {
                    case let .videoSize(videoSizeData):
                        let (_, type, w, h, size, videoStartTs) = (videoSizeData.flags, videoSizeData.type, videoSizeData.w, videoSizeData.h, videoSizeData.size, videoSizeData.videoStartTs)
                        let resource: TelegramMediaResource
                        resource = CloudPhotoSizeMediaResource(datacenterId: dcId, photoId: id, accessHash: accessHash, sizeSpec: type, size: Int64(size), fileReference: fileReference.makeData())

                        videoRepresentations.append(TelegramMediaImage.VideoRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, startTimestamp: videoStartTs))
                    case let .videoSizeEmojiMarkup(videoSizeEmojiMarkupData):
                        let (fileId, backgroundColors) = (videoSizeEmojiMarkupData.emojiId, videoSizeEmojiMarkupData.backgroundColors)
                        emojiMarkup = TelegramMediaImage.EmojiMarkup(content: .emoji(fileId: fileId), backgroundColors: backgroundColors)
                    case let .videoSizeStickerMarkup(videoSizeStickerMarkupData):
                        let (stickerSet, fileId, backgroundColors) = (videoSizeStickerMarkupData.stickerset, videoSizeStickerMarkupData.stickerId, videoSizeStickerMarkupData.backgroundColors)
                        if let packReference = StickerPackReference(apiInputSet: stickerSet) {
                            emojiMarkup = TelegramMediaImage.EmojiMarkup(content: .sticker(packReference: packReference, fileId: fileId), backgroundColors: backgroundColors)
                        }
                    }
                }
            }
            
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: representations, videoRepresentations: videoRepresentations, immediateThumbnailData: immediateThumbnailData, emojiMarkup: emojiMarkup, reference: .cloud(imageId: id, accessHash: accessHash, fileReference: fileReference.makeData()), partialReference: nil, flags: imageFlags)
        case .photoEmpty:
            return nil
    }
}
