import Foundation
import UIKit
import AVFoundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import LegacyComponents
import LegacyMediaPickerUI
import TextFormat
import ImageCompression
import LocalMediaResources
import MediaEditor

public struct ChatMediaEditorResult {
    public enum Media {
        case image(image: UIImage, nominalDimensions: PixelDimensions)
        case video(path: String, values: MediaEditorValues, duration: Double)
    }

    public let media: Media
    public let thumbnail: UIImage?
    public let caption: NSAttributedString
    public let stickers: [TelegramMediaFile]
    public let isAnimation: Bool

    public init(media: Media, thumbnail: UIImage?, caption: NSAttributedString, stickers: [TelegramMediaFile], isAnimation: Bool = false) {
        self.media = media
        self.thumbnail = thumbnail
        self.caption = caption
        self.stickers = stickers
        self.isAnimation = isAnimation
    }
}

public let chatMediaEditorSendsForceHd = false

public func chatMediaEditorImageMaxSide(forceHd: Bool) -> CGFloat {
    return forceHd ? 2560.0 : 1280.0
}

public func chatMediaEditorCroppedNominalDimensions(values: MediaEditorValues) -> PixelDimensions {
    var size = CGSize(width: CGFloat(values.originalDimensions.width), height: CGFloat(values.originalDimensions.height))
    if let cropRect = values.cropRect, cropRect.width > 0.0, cropRect.height > 0.0 {
        size = cropRect.size
    }
    if values.cropOrientation?.isSideward == true {
        size = CGSize(width: size.height, height: size.width)
    }
    return PixelDimensions(width: Int32(size.width.rounded()), height: Int32(size.height.rounded()))
}

public func chatMediaEditorImageSendSize(nominalDimensions: PixelDimensions, forceHd: Bool) -> CGSize {
    let maxSide = chatMediaEditorImageMaxSide(forceHd: forceHd)
    let maxSize = CGSize(width: maxSide, height: maxSide)
    return nominalDimensions.cgSize.aspectFittedOrSmaller(maxSize)
}

public func chatMediaEditorVideoAdjustments(values: MediaEditorValues) -> VideoMediaResourceAdjustments? {
    guard let valuesData = try? JSONEncoder().encode(values) else {
        return nil
    }
    let data = EngineMemoryBuffer(data: valuesData)
    let digest = EngineMemoryBuffer(data: data.md5Digest())
    return VideoMediaResourceAdjustments(data: data, digest: digest, isStory: false)
}

public func chatMediaEditorVideoDuration(values: MediaEditorValues, duration: Double) -> Double {
    let sourceDuration: Double
    if let trimRange = values.videoTrimRange {
        sourceDuration = trimRange.upperBound - trimRange.lowerBound
    } else {
        sourceDuration = duration
    }
    return values.videoBounce ? sourceDuration * 2.0 : sourceDuration
}

public func chatMediaEditorVideoFileDimensions(values: MediaEditorValues, duration: Double) -> PixelDimensions {
    let configuration = recommendedVideoExportConfiguration(values: values, duration: duration, frameRate: 30.0)
    let width = (configuration.videoSettings[AVVideoWidthKey] as? Int) ?? 1920
    let height = (configuration.videoSettings[AVVideoHeightKey] as? Int) ?? 1080
    return PixelDimensions(width: Int32(width), height: Int32(height))
}

public func chatMediaEditorGifSendsOriginal(values: MediaEditorValues?, hasStickers: Bool) -> Bool {
    if hasStickers {
        return false
    }
    guard let values else {
        return true
    }
    if chatMediaEditorValuesHaveVisualEdits(values) {
        return false
    }
    if let qualityPreset = values.qualityPreset, qualityPreset != .animation {
        return false
    }
    return true
}

public func chatMediaEditorEnqueueMessage(
    result: ChatMediaEditorResult,
    forceHd: Bool,
    originalMediaReference: AnyMediaReference? = nil,
    storeResourceData: (EngineMediaResource.Id, Data) -> Void
) -> LegacyAssetPickerEnqueueMessage? {
    let stickerFiles = result.stickers
    let media: EngineRawMedia
    switch result.media {
    case let .image(image, nominalDimensions):
        guard let imageMedia = chatMediaSendRenderedImageMedia(image: image, nominalDimensions: nominalDimensions, thumbnail: result.thumbnail, stickerFiles: stickerFiles, forceHd: forceHd, storeResourceData: storeResourceData) else {
            return nil
        }
        media = imageMedia
    case let .video(path, values, duration):
        if result.isAnimation, let originalMediaReference, originalMediaReference.media is TelegramMediaFile, chatMediaEditorGifSendsOriginal(values: values, hasStickers: !stickerFiles.isEmpty) {
            return chatMediaSendMessage(media: originalMediaReference.media, mediaReference: originalMediaReference, caption: chatMediaSendCaption(result.caption), stickerFiles: [], timer: nil, spoiler: false, groupingKey: nil, uniqueId: nil)
        }
        let sendValues = result.isAnimation ? values.withUpdatedQualityPreset(.animation).withUpdatedVideoIsMuted(true) : values
        let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: path, adjustments: chatMediaEditorVideoAdjustments(values: sendValues))
        media = chatMediaSendEditedVideoFile(resource: resource, values: sendValues, duration: duration, fileName: "video.mp4", thumbnail: result.thumbnail, cover: nil, stickerFiles: stickerFiles, storeResourceData: storeResourceData)
    }
    return chatMediaSendMessage(media: media, caption: chatMediaSendCaption(result.caption), stickerFiles: stickerFiles, timer: nil, spoiler: false, groupingKey: nil, uniqueId: nil)
}

public func chatMediaEditorEnqueueMessages(context: AccountContext, result: ChatMediaEditorResult, forceHd: Bool, originalMediaReference: AnyMediaReference? = nil) -> Signal<[LegacyAssetPickerEnqueueMessage], Void> {
    return Signal { subscriber in
        let message = chatMediaEditorEnqueueMessage(result: result, forceHd: forceHd, originalMediaReference: originalMediaReference, storeResourceData: { id, data in
            context.engine.resources.storeResourceData(id: id, data: data)
        })
        if let message {
            subscriber.putNext([message])
            subscriber.putCompletion()
        } else {
            subscriber.putError(Void())
        }
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}
