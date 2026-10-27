import Foundation
import UIKit
import TelegramCore
import LegacyMediaPickerUI
import MediaEditor

public enum MediaPickerChatMediaSendFallback: Equatable {
    case emptySelection
    case missingItem
    case capturedVideo
    case legacyAdjustments
}

public enum MediaPickerChatMediaSendSource {
    case photo(identifier: String, pixelSize: CGSize, thumbnail: UIImage?)
    case video(identifier: String, pixelSize: CGSize, duration: Double, thumbnail: UIImage?)
    case gif(identifier: String, pixelSize: CGSize, thumbnail: UIImage?)
    case livePhoto(identifier: String, pixelSize: CGSize, mode: ChatMediaSendLivePhotoMode, thumbnail: UIImage?)
    case capturedVideo(path: String, dimensions: PixelDimensions, duration: Double)
    case capturedLibraryVideo(identifier: String, pixelSize: CGSize, duration: Double, isGif: Bool)
    case image(UIImage)
    case unsupported(MediaPickerChatMediaSendFallback)
}

public protocol MediaPickerChatMediaSendSelection {
    var selectedUniqueIds: [String] { get }
    var grouping: Bool { get }
}

public protocol MediaPickerChatMediaSendEditing {
    var forcedCaption: NSAttributedString? { get }
    var isHighQualityPhoto: Bool { get }
    func caption(for uniqueId: String) -> NSAttributedString?
    func timer(for uniqueId: String) -> Int32?
    func spoiler(for uniqueId: String) -> Bool
    func price(for uniqueId: String) -> Int64?
    func coverImage(for uniqueId: String) -> UIImage?
    func hasLegacyAdjustments(for uniqueId: String) -> Bool
}

public func mediaPickerChatMediaSendEditedValues(store: ChatMediaEditorItemStore, uniqueId: String) -> MediaEditorValues? {
    guard store.isEdited(uniqueId) else {
        return nil
    }
    return store.entry(for: uniqueId)?.values
}

private func mediaPickerChatMediaSendHasAnimatedEntities(_ values: MediaEditorValues?) -> Bool {
    return values?.entities.contains(where: { $0.entity.isAnimated }) ?? false
}

public struct ChatMediaSendLegacyMedia {
    public var media: EngineRawMedia
    public var stickers: [TelegramMediaFile]
    public var isAnimation: Bool

    public init(media: EngineRawMedia, stickers: [TelegramMediaFile], isAnimation: Bool) {
        self.media = media
        self.stickers = stickers
        self.isAnimation = isAnimation
    }
}

public func chatMediaSendLegacyMedia(messages: [LegacyAssetPickerEnqueueMessage]) -> ChatMediaSendLegacyMedia? {
    for message in messages {
        guard case let .message(_, attributes, _, mediaReference, _, _, _, _, _, _) = message.message, var media = mediaReference?.media else {
            continue
        }
        if let paidContent = media as? TelegramMediaPaidContent {
            var inner: EngineRawMedia?
            for extendedMedia in paidContent.extendedMedia {
                if case let .full(fullMedia) = extendedMedia {
                    inner = fullMedia
                    break
                }
            }
            guard let inner else {
                continue
            }
            media = inner
        }
        var stickers: [TelegramMediaFile] = []
        for attribute in attributes {
            if let attribute = attribute as? EmbeddedMediaStickersMessageAttribute {
                stickers.append(contentsOf: attribute.files)
            }
        }
        let isAnimation = (media as? TelegramMediaFile)?.isAnimated ?? false
        return ChatMediaSendLegacyMedia(media: media, stickers: stickers, isAnimation: isAnimation)
    }
    return nil
}

public func mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: String, source: MediaPickerChatMediaSendSource?, editing: MediaPickerChatMediaSendEditing, store: ChatMediaEditorItemStore) -> MediaPickerChatMediaSendFallback? {
    guard let source else {
        return .missingItem
    }
    switch source {
    case let .unsupported(reason):
        return reason
    case .capturedVideo, .capturedLibraryVideo:
        if !store.isEdited(uniqueId) {
            return .capturedVideo
        }
    default:
        break
    }
    if store.entry(for: uniqueId) == nil && editing.hasLegacyAdjustments(for: uniqueId) {
        return .legacyAdjustments
    }
    return nil
}

public func mediaPickerChatMediaSendLegacyOnlyIds(selection: MediaPickerChatMediaSendSelection, editing: MediaPickerChatMediaSendEditing, store: ChatMediaEditorItemStore, assetFor: (String) -> MediaPickerChatMediaSendSource?) -> [String] {
    return selection.selectedUniqueIds.filter { uniqueId in
        return mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: uniqueId, source: assetFor(uniqueId), editing: editing, store: store) != nil
    }
}

public func mediaPickerChatMediaSendFallback(selection: MediaPickerChatMediaSendSelection, editing: MediaPickerChatMediaSendEditing, store: ChatMediaEditorItemStore, assetFor: (String) -> MediaPickerChatMediaSendSource?) -> MediaPickerChatMediaSendFallback? {
    let uniqueIds = selection.selectedUniqueIds
    if uniqueIds.isEmpty {
        return .emptySelection
    }
    var firstReason: MediaPickerChatMediaSendFallback?
    for uniqueId in uniqueIds {
        guard let reason = mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: uniqueId, source: assetFor(uniqueId), editing: editing, store: store) else {
            return nil
        }
        if firstReason == nil {
            firstReason = reason
        }
    }
    return firstReason
}

public func mediaPickerChatMediaSendGlobalOptions(selection: MediaPickerChatMediaSendSelection, editing: MediaPickerChatMediaSendEditing, saveEditedPhotosToCameraRoll: Bool = false) -> ChatMediaSendGlobalOptions {
    return ChatMediaSendGlobalOptions(grouping: selection.grouping, forcedCaption: editing.forcedCaption, forceHd: editing.isHighQualityPhoto, saveEditedPhotosToCameraRoll: saveEditedPhotosToCameraRoll)
}

public func mediaPickerChatMediaSendItems(selection: MediaPickerChatMediaSendSelection, editing: MediaPickerChatMediaSendEditing, store: ChatMediaEditorItemStore, assetFor: (String) -> MediaPickerChatMediaSendSource?, fileNameFor: (String) -> String?, legacyMedia: [String: ChatMediaSendLegacyMedia] = [:]) -> [ChatMediaSendItem] {
    var items: [ChatMediaSendItem] = []
    for uniqueId in selection.selectedUniqueIds {
        let resolvedSource = assetFor(uniqueId)
        if mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: uniqueId, source: resolvedSource, editing: editing, store: store) != nil {
            var timer = editing.timer(for: uniqueId)
            if timer == 0 {
                timer = nil
            }
            let legacy = legacyMedia[uniqueId]
            let options = ChatMediaSendItemOptions(
                caption: editing.caption(for: uniqueId),
                timer: timer,
                spoiler: editing.spoiler(for: uniqueId),
                price: editing.price(for: uniqueId),
                isAnimation: legacy?.isAnimation ?? false
            )
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .prebuilt(media: legacy?.media), stickers: legacy?.stickers ?? [], options: options))
            continue
        }
        guard let source = resolvedSource else {
            continue
        }
        let values = mediaPickerChatMediaSendEditedValues(store: store, uniqueId: uniqueId)
        let editedThumbnail = values != nil ? store.entry(for: uniqueId)?.thumbnail : nil
        let stickers = values.flatMap { chatMediaSendCollectStickers(entities: $0.entities) } ?? []

        var timer = editing.timer(for: uniqueId)
        if timer == 0 {
            timer = nil
        }
        let hasAnimatedPainting = mediaPickerChatMediaSendHasAnimatedEntities(values)
        var isVideoSource = false
        var isGifSource = false
        var livePhotoMode: ChatMediaSendLivePhotoMode = .off
        switch source {
        case .video, .capturedVideo:
            isVideoSource = true
        case let .capturedLibraryVideo(_, _, _, isGif):
            if isGif {
                isGifSource = true
            } else {
                isVideoSource = true
            }
        case .gif:
            isGifSource = true
        case let .livePhoto(_, _, mode, _):
            livePhotoMode = chatMediaSendEffectiveLivePhotoMode(resolved: mode, hasAnimatedPainting: hasAnimatedPainting)
        default:
            break
        }
        let options = ChatMediaSendItemOptions(
            caption: editing.caption(for: uniqueId),
            timer: timer,
            spoiler: editing.spoiler(for: uniqueId),
            price: editing.price(for: uniqueId),
            isAnimation: false,
            hasAnimatedPainting: hasAnimatedPainting,
            livePhotoLoopOrBounce: livePhotoMode.isLoopOrBounce,
            isLivePhoto: livePhotoMode == .live,
            isMuted: isVideoSource && (values?.videoIsMuted ?? false),
            excludedFromGrouping: isGifSource
        )

        switch source {
        case let .photo(identifier, pixelSize, thumbnail):
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .libraryAsset(identifier: identifier, pixelSize: pixelSize, isVideo: false, duration: 0.0), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? thumbnail, coverImage: nil, stickers: stickers, options: options, fileName: nil))
        case let .video(identifier, pixelSize, duration, thumbnail):
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .libraryAsset(identifier: identifier, pixelSize: pixelSize, isVideo: true, duration: duration), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? thumbnail, coverImage: editing.coverImage(for: uniqueId), stickers: stickers, options: options, fileName: fileNameFor(uniqueId)))
        case let .gif(identifier, pixelSize, thumbnail):
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .gifAsset(identifier: identifier, pixelSize: pixelSize), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? thumbnail, coverImage: nil, stickers: stickers, options: options, fileName: nil))
        case let .livePhoto(identifier, pixelSize, _, thumbnail):
            if livePhotoMode == .off {
                items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .libraryAsset(identifier: identifier, pixelSize: pixelSize, isVideo: false, duration: 0.0), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? thumbnail, coverImage: nil, stickers: stickers, options: options, fileName: nil))
            } else {
                items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .livePhoto(identifier: identifier, pixelSize: pixelSize, mode: livePhotoMode), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? thumbnail, coverImage: nil, stickers: stickers, options: options, fileName: nil))
            }
        case let .capturedVideo(path, dimensions, duration):
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .tempVideo(path: path, dimensions: dimensions, duration: duration), values: values, renderedImage: nil, thumbnail: editedThumbnail, coverImage: editing.coverImage(for: uniqueId), stickers: stickers, options: options, fileName: nil))
        case let .capturedLibraryVideo(identifier, pixelSize, duration, isGif):
            if isGif {
                items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .gifAsset(identifier: identifier, pixelSize: pixelSize), values: values, renderedImage: nil, thumbnail: editedThumbnail, coverImage: nil, stickers: stickers, options: options, fileName: nil))
            } else {
                items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .libraryAsset(identifier: identifier, pixelSize: pixelSize, isVideo: true, duration: duration), values: values, renderedImage: nil, thumbnail: editedThumbnail, coverImage: editing.coverImage(for: uniqueId), stickers: stickers, options: options, fileName: fileNameFor(uniqueId)))
            }
        case let .image(image):
            items.append(ChatMediaSendItem(uniqueId: uniqueId, source: .image(image), values: values, renderedImage: nil, thumbnail: editedThumbnail ?? image, coverImage: nil, stickers: stickers, options: options, fileName: nil))
        case .unsupported:
            break
        }
    }
    return items
}
