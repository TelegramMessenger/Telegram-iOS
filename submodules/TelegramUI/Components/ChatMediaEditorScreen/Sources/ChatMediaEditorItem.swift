import Foundation
import UIKit
import Photos
import ImageIO
import SwiftSignalKit
import TelegramCore
import MediaEditor
import ChatMediaSend

public enum ChatMediaEditorItemSource: Equatable {
    case asset(PHAsset)
    case image(UIImage)
    case imageFile(path: String, dimensions: PixelDimensions)
    case video(path: String, dimensions: PixelDimensions, duration: Double)

    public var subject: ChatMediaEditorSubject {
        switch self {
        case let .asset(asset):
            return .asset(asset)
        case let .image(image):
            return .image(image)
        case let .imageFile(path, dimensions):
            return .image(chatMediaEditorFileImage(path: path, dimensions: dimensions))
        case let .video(path, dimensions, duration):
            return .video(path: path, dimensions: dimensions, duration: duration)
        }
    }

    public var dimensions: PixelDimensions {
        switch self {
        case let .asset(asset):
            return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
        case let .image(image):
            return PixelDimensions(width: Int32(round(image.size.width * image.scale)), height: Int32(round(image.size.height * image.scale)))
        case let .imageFile(_, dimensions):
            return dimensions
        case let .video(_, dimensions, _):
            return dimensions
        }
    }

    public var isVideo: Bool {
        switch self {
        case let .asset(asset):
            return asset.mediaType == .video
        case .image, .imageFile:
            return false
        case .video:
            return true
        }
    }
}

public struct ChatMediaEditorItem {
    public let uniqueId: String
    public let source: ChatMediaEditorItemSource
    public let isAnimation: Bool
    public let isMirrored: Bool
    public let thumbnail: UIImage?

    public init(uniqueId: String, source: ChatMediaEditorItemSource, isAnimation: Bool = false, isMirrored: Bool = false, thumbnail: UIImage? = nil) {
        self.uniqueId = uniqueId
        self.source = source
        self.isAnimation = isAnimation
        self.isMirrored = isMirrored
        self.thumbnail = thumbnail
    }
}

func chatMediaEditorFileImage(path: String, dimensions: PixelDimensions) -> UIImage {
    if let image = UIImage(contentsOfFile: path) {
        return image
    }
    let pixelSize = dimensions.cgSize
    var size = CGSize(width: 1.0, height: 1.0)
    if pixelSize.width > 0.0 && pixelSize.height > 0.0 {
        let ratio = 64.0 / max(pixelSize.width, pixelSize.height)
        size = CGSize(width: max(1.0, floor(pixelSize.width * ratio)), height: max(1.0, floor(pixelSize.height * ratio)))
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

public func chatMediaEditorFileThumbnail(path: String, maxPixelSide: CGFloat) -> UIImage? {
    guard maxPixelSide >= 1.0, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSide.rounded(.up))
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

func chatMediaEditorFileThumbnailSignal(path: String, maxPixelSide: CGFloat) -> Signal<UIImage?, NoError> {
    return Signal { subscriber in
        subscriber.putNext(chatMediaEditorFileThumbnail(path: path, maxPixelSide: maxPixelSide))
        subscriber.putCompletion()
        return EmptyDisposable
    }
    |> runOn(Queue.concurrentDefaultQueue())
}

public struct ChatMediaEditorEditorSetup {
    public let subject: MediaEditor.Subject
    public let values: MediaEditorValues
    public let isVideo: Bool
}

public func chatMediaEditorItemSubject(_ item: ChatMediaEditorItem, convertedGif: (String) -> ChatMediaSendConvertedGif?) -> ChatMediaEditorSubject {
    if item.isAnimation, case let .asset(asset) = item.source, let converted = convertedGif(asset.localIdentifier) {
        return .video(path: converted.path, dimensions: converted.dimensions, duration: converted.duration)
    }
    return item.source.subject
}

public func chatMediaEditorItemAwaitsGifConversion(_ item: ChatMediaEditorItem, subject: ChatMediaEditorSubject) -> Bool {
    guard item.isAnimation, case .asset = item.source else {
        return false
    }
    return !subject.isVideo
}

public func chatMediaEditorSingleItem(subject: ChatMediaEditorSubject, isAnimation: Bool) -> ChatMediaEditorItem {
    return ChatMediaEditorItem(uniqueId: "single", source: subject.itemSource, isAnimation: isAnimation)
}

public func chatMediaEditorAssetItem(uniqueId: String, asset: PHAsset) -> ChatMediaEditorItem {
    return ChatMediaEditorItem(uniqueId: uniqueId, source: .asset(asset), isAnimation: asset.mediaType == .image && chatMediaSendAssetIsGif(asset))
}

public func chatMediaEditorEditorSetup(subject: ChatMediaEditorSubject, peerId: EnginePeer.Id, isAnimation: Bool = false, isMirrored: Bool = false) -> ChatMediaEditorEditorSetup {
    let dimensions = subject.dimensions
    let editorSubject: MediaEditor.Subject
    switch subject {
    case let .image(image):
        editorSubject = .image(image, dimensions)
    case let .video(path, dimensions, duration):
        editorSubject = .video(path, nil, false, nil, dimensions, duration)
    case let .asset(asset):
        editorSubject = .asset(asset)
    }
    let qualityPreset: MediaQualityPreset = subject.isVideo && isAnimation ? .animation : subject.isVideo ? chatMediaEditorInitialVideoQualityPreset(preferred: chatMediaEditorPreferredVideoQualityPreset(), dimensions: dimensions.cgSize) : .compressedVeryHigh
    let values = chatMediaEditorValues(peerId: peerId, originalDimensions: dimensions, qualityPreset: qualityPreset, videoIsMirrored: isMirrored && subject.isVideo)
    return ChatMediaEditorEditorSetup(subject: editorSubject, values: values, isVideo: subject.isVideo)
}

public let chatMediaEditorSourceProgressRevealDelay: Double = 0.3

public enum ChatMediaEditorSourceIndicatorState: Equatable {
    case hidden
    case progress(Float)
    case unavailable
}

public func chatMediaEditorSourceIndicatorState(_ state: MediaEditorSourceLoadState) -> ChatMediaEditorSourceIndicatorState {
    switch state {
    case let .loading(progress):
        if let progress {
            return .progress(progress)
        } else {
            return .hidden
        }
    case .ready:
        return .hidden
    case .unavailable:
        return .unavailable
    }
}
