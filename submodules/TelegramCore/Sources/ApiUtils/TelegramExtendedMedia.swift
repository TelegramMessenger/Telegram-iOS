import Foundation
import Postbox
import TelegramApi

extension TelegramExtendedMedia {
    init?(apiExtendedMedia: Api.MessageExtendedMedia, peerId: PeerId) {
        switch apiExtendedMedia {
        case let .messageExtendedMediaPreview(_, width, height, thumb, videoDuration):
            var dimensions: PixelDimensions?
            if let width = width, let height = height {
                dimensions = PixelDimensions(width: width, height: height)
            }
            var immediateThumbnailData: Data?
            if let thumb = thumb, case let .photoStrippedSize(_, bytes) = thumb {
                immediateThumbnailData = bytes.makeData()
            }
            self = .preview(dimensions: dimensions, immediateThumbnailData: immediateThumbnailData, videoDuration: videoDuration)
        case let .messageExtendedMedia(apiMedia):
            let (media, _, _, _, _) = textMediaAndExpirationTimerFromApiMedia(apiMedia, peerId)
            if let media = media {
                self = .full(media: media)
            } else {
                return nil
            }
        }
    }
}
