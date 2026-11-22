import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import LocalMediaResources
import MediaEditor

public struct ChatMediaSendPreparedAnimatedPhoto {
    public var path: String
    public var duration: Double
    public var preview: UIImage

    public init(path: String, duration: Double, preview: UIImage) {
        self.path = path
        self.duration = duration
        self.preview = preview
    }
}

public func chatMediaSendAnimatedPhotoDuration(stickerDurations: [Double]) -> Double {
    func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        let remainder = a % b
        if remainder != 0 {
            return gcd(b, remainder)
        } else {
            return b
        }
    }

    func lcm(_ x: Int64, _ y: Int64) -> Int64 {
        let x = max(x, 1)
        let y = max(y, 1)
        return x / gcd(x, y) * y
    }

    let minDuration: Double = 3.0
    let maxMultipleDuration: Double = 6.0
    var result: Double
    if stickerDurations.count > 1 {
        var reduced: Double = 1.0
        for duration in stickerDurations {
            if reduced / 10.0 >= maxMultipleDuration {
                break
            }
            reduced = Double(lcm(Int64(reduced * 100.0), Int64(min(max(0.0, duration), 1000000.0) * 100.0)))
        }
        result = min(maxMultipleDuration, reduced / 10.0)
    } else if let duration = stickerDurations.first {
        result = duration
    } else {
        result = minDuration
    }
    if result < minDuration {
        if result > 0.0 {
            result = result * ceil(minDuration / result)
        } else {
            result = minDuration
        }
    }
    return result
}

public func chatMediaSendItemIsAnimatedPhoto(_ item: ChatMediaSendItem) -> Bool {
    guard let values = item.values, values.entities.contains(where: { $0.entity.isAnimated }) else {
        return false
    }
    switch item.source {
    case let .libraryAsset(_, _, isVideo, _):
        return !isVideo
    case .image, .imageFile:
        return true
    case .tempVideo, .gifAsset, .livePhoto, .prebuilt:
        return false
    }
}

func chatMediaSendAnimatedPhotoValues(_ values: MediaEditorValues, duration: Double) -> MediaEditorValues {
    return values.withUpdatedQualityPreset(.animation).withUpdatedImageDuration(duration)
}

func chatMediaSendAnimatedPhotoBaseImagePath(image: UIImage) -> String? {
    let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    guard pixelSize.width >= 1.0, pixelSize.height >= 1.0 else {
        return nil
    }
    let fittedSize = pixelSize.aspectFittedOrSmaller(CGSize(width: 1920.0, height: 1920.0))
    let size = CGSize(width: max(1.0, floor(fittedSize.width)), height: max(1.0, floor(fittedSize.height)))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
    guard let data = upright.jpegData(compressionQuality: 0.8) else {
        return nil
    }
    let path = NSTemporaryDirectory() + "gifvideo_\(String(UInt64.random(in: 0 ... UInt64.max), radix: 16)).jpg"
    guard (try? data.write(to: URL(fileURLWithPath: path))) != nil else {
        return nil
    }
    return path
}

func chatMediaSendAnimatedPhotoFile(item: ChatMediaSendItem, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaFile? {
    guard let values = item.values, let prepared = item.preparedAnimatedPhoto else {
        return nil
    }
    let sendValues = chatMediaSendAnimatedPhotoValues(values, duration: prepared.duration)
    guard let adjustments = chatMediaEditorVideoAdjustments(values: sendValues) else {
        return nil
    }
    let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: prepared.path, adjustments: adjustments)
    let dimensions = chatMediaEditorVideoFileDimensions(values: sendValues, duration: prepared.duration)

    var previewRepresentations: [TelegramMediaImageRepresentation] = []
    if let representation = chatMediaSendThumbnailRepresentation(thumbnail: prepared.preview, fittedTo: dimensions.cgSize, storeResourceData: storeResourceData) {
        previewRepresentations.append(representation)
    }

    let estimatedSize = TGMediaVideoConverter.estimatedSize(for: TGMediaVideoConversionPresetAnimation, duration: prepared.duration, hasAudio: false)
    var fileAttributes: [TelegramMediaFileAttribute] = []
    fileAttributes.append(.FileName(fileName: "video.mp4"))
    fileAttributes.append(.Animated)
    fileAttributes.append(.Video(duration: prepared.duration, size: dimensions, flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil))
    if estimatedSize > 10 * 1024 * 1024 {
        fileAttributes.append(.hintFileIsLarge)
    }
    if !item.stickers.isEmpty {
        fileAttributes.append(.HasLinkedStickers)
    }
    return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], videoCover: nil, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: fileAttributes, alternativeRepresentations: [])
}
