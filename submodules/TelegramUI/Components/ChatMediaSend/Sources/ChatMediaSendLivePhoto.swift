import Foundation
import UIKit
import Photos
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import LocalMediaResources
import MediaEditor

public enum ChatMediaSendLivePhotoMode: Equatable {
    case off
    case live
    case loop
    case bounce

    public init(legacy: TGMediaLivePhotoMode) {
        switch legacy {
        case .live:
            self = .live
        case .loop:
            self = .loop
        case .bounce:
            self = .bounce
        default:
            self = .off
        }
    }

    public var legacyMode: TGMediaLivePhotoMode {
        switch self {
        case .off:
            return .off
        case .live:
            return .live
        case .loop:
            return .loop
        case .bounce:
            return .bounce
        }
    }

    public var isLoopOrBounce: Bool {
        return self == .loop || self == .bounce
    }
}

public func chatMediaSendResolvedLivePhotoMode(stored: ChatMediaSendLivePhotoMode?, isLiveAsset: Bool, forceLivePhotoEnabled: Bool) -> ChatMediaSendLivePhotoMode {
    if let stored {
        return stored
    }
    guard isLiveAsset else {
        return .off
    }
    return forceLivePhotoEnabled ? .live : .off
}

public func chatMediaSendEffectiveLivePhotoMode(resolved: ChatMediaSendLivePhotoMode, hasAnimatedPainting: Bool) -> ChatMediaSendLivePhotoMode {
    if resolved == .live && hasAnimatedPainting {
        return .loop
    }
    return resolved
}

public struct ChatMediaSendLivePhotoVideo: Equatable {
    public var path: String
    public var dimensions: PixelDimensions
    public var duration: Double

    public init(path: String, dimensions: PixelDimensions, duration: Double) {
        self.path = path
        self.dimensions = dimensions
        self.duration = duration
    }
}

public struct ChatMediaSendPreparedLivePhoto {
    public var video: ChatMediaSendLivePhotoVideo
    public var image: UIImage

    public init(video: ChatMediaSendLivePhotoVideo, image: UIImage) {
        self.video = video
        self.image = image
    }
}

public protocol ChatMediaSendLivePhotoPreparing {
    func prepareLivePhoto(item: ChatMediaSendItem, renderer: ChatMediaSendRendering) -> Signal<ChatMediaSendPreparedLivePhoto?, NoError>
}

public final class ChatMediaSendLivePhotoPreparer: ChatMediaSendLivePhotoPreparing {
    public static let shared = ChatMediaSendLivePhotoPreparer()

    public init() {
    }

    public func prepareLivePhoto(item: ChatMediaSendItem, renderer: ChatMediaSendRendering) -> Signal<ChatMediaSendPreparedLivePhoto?, NoError> {
        guard case let .livePhoto(identifier, _, _) = item.source else {
            return .single(nil)
        }
        let imageEvents: Signal<ChatMediaSendRenderEvent, NoError>
        if item.values != nil {
            imageEvents = renderer.renderPhoto(item: item, forceHd: item.rendersCameraRollStill)
        } else {
            imageEvents = chatMediaSendFullAssetImage(identifier: identifier)
        }
        return combineLatest(chatMediaSendLivePhotoPairedVideo(identifier: identifier), chatMediaSendFirstResultImage(imageEvents))
        |> take(1)
        |> map { video, image -> ChatMediaSendPreparedLivePhoto? in
            guard let video, let image else {
                return nil
            }
            return ChatMediaSendPreparedLivePhoto(video: video, image: image)
        }
    }
}

func chatMediaSendFirstResultImage(_ events: Signal<ChatMediaSendRenderEvent, NoError>) -> Signal<UIImage?, NoError> {
    return Signal { subscriber in
        let delivered = Atomic<Bool>(value: false)
        return events.start(next: { event in
            guard case let .result(image) = event else {
                return
            }
            if !delivered.swap(true) {
                subscriber.putNext(image)
                subscriber.putCompletion()
            }
        }, completed: {
            if !delivered.swap(true) {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        })
    }
}

public func chatMediaSendLivePhotoPairedVideoPath(identifier: String) -> String {
    let provider: LegacyComponentsGlobalsProvider? = LegacyComponentsGlobals.provider()
    let basePath = provider?.dataStoragePath() ?? NSTemporaryDirectory()
    let directory = (basePath as NSString).appendingPathComponent("convertedLivePhotos")
    let _ = try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    let name = TGStringUtils.md5(identifier) ?? "\(identifier.hashValue)"
    return (directory as NSString).appendingPathComponent("\(name).mp4")
}

private func chatMediaSendLivePhotoVideoFromFile(path: String) -> ChatMediaSendLivePhotoVideo? {
    guard let info = chatMediaSendConvertedGifFromFile(path: path) else {
        return nil
    }
    return ChatMediaSendLivePhotoVideo(path: info.path, dimensions: info.dimensions, duration: info.duration)
}

public func chatMediaSendLivePhotoPairedVideo(identifier: String) -> Signal<ChatMediaSendLivePhotoVideo?, NoError> {
    return Signal { subscriber in
        let path = chatMediaSendLivePhotoPairedVideoPath(identifier: identifier)
        if let existing = chatMediaSendLivePhotoVideoFromFile(path: path) {
            subscriber.putNext(existing)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .fullSizePairedVideo }) ?? resources.first(where: { $0.type == .pairedVideo }) else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let partialPath = path + ".\(Int64.random(in: 1 ... Int64.max)).part"
        let _ = try? FileManager.default.removeItem(atPath: partialPath)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: resource, toFile: URL(fileURLWithPath: partialPath), options: options, completionHandler: { error in
            var result: ChatMediaSendLivePhotoVideo?
            if error == nil {
                if let existing = chatMediaSendLivePhotoVideoFromFile(path: path) {
                    result = existing
                } else {
                    let _ = try? FileManager.default.removeItem(atPath: path)
                    if (try? FileManager.default.moveItem(atPath: partialPath, toPath: path)) != nil {
                        result = chatMediaSendLivePhotoVideoFromFile(path: path)
                    }
                }
            }
            let _ = try? FileManager.default.removeItem(atPath: partialPath)
            subscriber.putNext(result)
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}

private func chatMediaSendLivePhotoValues(base: MediaEditorValues, originalDimensions: PixelDimensions, cropOffset: CGPoint, cropRect: CGRect?, mode: ChatMediaSendLivePhotoMode) -> MediaEditorValues {
    return MediaEditorValues(
        peerId: base.peerId,
        originalDimensions: originalDimensions,
        cropOffset: cropOffset,
        cropRect: cropRect,
        cropScale: base.cropScale,
        cropRotation: base.cropRotation,
        cropMirroring: base.cropMirroring,
        cropOrientation: base.cropOrientation,
        cropPerspective: base.cropPerspective,
        gradientColors: base.gradientColors,
        videoTrimRange: nil,
        videoBounce: mode == .bounce,
        videoIsMuted: mode.isLoopOrBounce,
        videoIsFullHd: base.videoIsFullHd,
        videoIsMirrored: base.videoIsMirrored,
        videoVolume: base.videoVolume,
        additionalVideoPath: nil,
        additionalVideoIsDual: false,
        additionalVideoMirroringChanges: [],
        additionalVideoPosition: nil,
        additionalVideoScale: nil,
        additionalVideoRotation: nil,
        additionalVideoPositionChanges: [],
        additionalVideoTrimRange: nil,
        additionalVideoOffset: nil,
        additionalVideoVolume: nil,
        collage: [],
        nightTheme: base.nightTheme,
        drawing: base.drawing,
        maskDrawing: base.maskDrawing,
        entities: base.entities,
        toolValues: base.toolValues,
        audioTrack: nil,
        audioTrackTrimRange: nil,
        audioTrackOffset: nil,
        audioTrackVolume: nil,
        audioTrackSamples: nil,
        collageTrackSamples: nil,
        coverImageTimestamp: nil,
        coverDimensions: nil,
        qualityPreset: mode == .live ? .compressedMedium : .compressedHigh
    )
}

public func chatMediaSendLivePhotoVideoValues(photoValues: MediaEditorValues?, video: ChatMediaSendLivePhotoVideo, mode: ChatMediaSendLivePhotoMode) -> MediaEditorValues {
    guard let photoValues, photoValues.originalDimensions.width > 0, photoValues.originalDimensions.height > 0 else {
        let base = chatMediaEditorValues(peerId: chatMediaSendGifPlaceholderPeerId, originalDimensions: video.dimensions, qualityPreset: .compressedMedium)
        return chatMediaSendLivePhotoValues(base: base, originalDimensions: video.dimensions, cropOffset: .zero, cropRect: nil, mode: mode)
    }
    let scaleX = CGFloat(video.dimensions.width) / CGFloat(photoValues.originalDimensions.width)
    let scaleY = CGFloat(video.dimensions.height) / CGFloat(photoValues.originalDimensions.height)
    let cropRect = photoValues.cropRect.map { rect in
        return CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY, width: rect.width * scaleX, height: rect.height * scaleY)
    }
    let cropOffset = CGPoint(x: photoValues.cropOffset.x * scaleX, y: photoValues.cropOffset.y * scaleY)
    return chatMediaSendLivePhotoValues(base: photoValues, originalDimensions: video.dimensions, cropOffset: cropOffset, cropRect: cropRect, mode: mode)
}

func chatMediaSendLivePhotoVideoFile(resource: TelegramMediaResource, values: MediaEditorValues, duration: Double) -> TelegramMediaFile {
    let dimensions = chatMediaEditorVideoFileDimensions(values: values, duration: duration)
    let estimatedSize = TGMediaVideoConverter.estimatedSize(for: TGMediaVideoConversionPresetCompressedMedium, duration: duration, hasAudio: true)
    var fileAttributes: [TelegramMediaFileAttribute] = []
    fileAttributes.append(.Video(duration: duration, size: dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil))
    if estimatedSize > 10 * 1024 * 1024 {
        fileAttributes.append(.hintFileIsLarge)
    }
    return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], videoCover: nil, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: fileAttributes, alternativeRepresentations: [])
}

func chatMediaSendLivePhotoMedia(item: ChatMediaSendItem, pixelSize: CGSize, mode: ChatMediaSendLivePhotoMode, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> EngineRawMedia? {
    guard let prepared = item.preparedLivePhoto, mode != .off else {
        return nil
    }
    let values = chatMediaSendLivePhotoVideoValues(photoValues: item.values, video: prepared.video, mode: mode)
    guard let adjustments = chatMediaEditorVideoAdjustments(values: values) else {
        return nil
    }
    let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: prepared.video.path, adjustments: adjustments)
    if mode == .live {
        let nominalDimensions = item.values.map(chatMediaEditorCroppedNominalDimensions(values:)) ?? PixelDimensions(pixelSize)
        let videoFile = chatMediaSendLivePhotoVideoFile(resource: resource, values: values, duration: prepared.video.duration)
        return chatMediaSendRenderedImageMedia(image: prepared.image, nominalDimensions: nominalDimensions, thumbnail: prepared.image, stickerFiles: item.stickers, forceHd: false, livePhotoVideo: videoFile, storeResourceData: storeResourceData)
    } else {
        return chatMediaSendEditedVideoFile(resource: resource, values: values, duration: prepared.video.duration, fileName: "video.mp4", thumbnail: prepared.image, cover: prepared.image, stickerFiles: item.stickers, storeResourceData: storeResourceData)
    }
}
