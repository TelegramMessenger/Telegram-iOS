import Foundation
import UIKit
import TelegramCore
import MediaEditor

public struct ChatMediaSendItem {
    public enum Source {
        case libraryAsset(identifier: String, pixelSize: CGSize, isVideo: Bool, duration: Double)
        case image(UIImage)
        case imageFile(path: String, dimensions: PixelDimensions)
        case tempVideo(path: String, dimensions: PixelDimensions, duration: Double)
        case gifAsset(identifier: String, pixelSize: CGSize)
        case livePhoto(identifier: String, pixelSize: CGSize, mode: ChatMediaSendLivePhotoMode)
        case prebuilt(media: EngineRawMedia?)
    }

    public var uniqueId: String
    public var source: Source
    public var values: MediaEditorValues?
    public var renderedImage: UIImage?
    public var thumbnail: UIImage?
    public var coverImage: UIImage?
    public var stickers: [TelegramMediaFile]
    public var options: ChatMediaSendItemOptions
    public var fileName: String?
    var preparedImage: TelegramMediaImage?
    var convertedGif: ChatMediaSendConvertedGif?
    var preparedLivePhoto: ChatMediaSendPreparedLivePhoto?
    var preparedAnimatedPhoto: ChatMediaSendPreparedAnimatedPhoto?
    var rendersCameraRollStill = false

    public init(uniqueId: String, source: Source, values: MediaEditorValues? = nil, renderedImage: UIImage? = nil, thumbnail: UIImage? = nil, coverImage: UIImage? = nil, stickers: [TelegramMediaFile] = [], options: ChatMediaSendItemOptions, fileName: String? = nil) {
        self.uniqueId = uniqueId
        self.source = source
        self.values = values
        self.renderedImage = renderedImage
        self.thumbnail = thumbnail
        self.coverImage = coverImage
        self.stickers = stickers
        self.options = options
        self.fileName = fileName
    }
}
