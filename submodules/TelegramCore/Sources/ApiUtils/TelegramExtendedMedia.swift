import Foundation
import Postbox
import TelegramApi

extension TelegramExtendedMedia {
    init?(apiExtendedMedia: Api.MessageExtendedMedia, peerId: PeerId) {
        switch apiExtendedMedia {
        case let .messageExtendedMediaPreview(messageExtendedMediaPreviewData):
            let (width, height, thumb, videoDuration) = (messageExtendedMediaPreviewData.w, messageExtendedMediaPreviewData.h, messageExtendedMediaPreviewData.thumb, messageExtendedMediaPreviewData.videoDuration)
            var dimensions: PixelDimensions?
            if let width = width, let height = height {
                dimensions = PixelDimensions(width: width, height: height)
            }
            var immediateThumbnailData: Data?
            if let thumb = thumb, case let .photoStrippedSize(photoStrippedSizeData) = thumb {
                let bytes = photoStrippedSizeData.bytes
                immediateThumbnailData = bytes.makeData()
            }
            self = .preview(dimensions: dimensions, immediateThumbnailData: immediateThumbnailData, videoDuration: videoDuration)
        case let .messageExtendedMedia(messageExtendedMediaData):
            let apiMedia = messageExtendedMediaData.media
            if let media = textMediaAndExpirationTimerFromApiMedia(apiMedia, peerId).media {
                self = .full(media: media)
            } else {
                return nil
            }
        }
    }
}
