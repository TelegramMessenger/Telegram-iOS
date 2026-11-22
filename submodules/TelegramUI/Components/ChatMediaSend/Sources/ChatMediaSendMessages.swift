import Foundation
import UIKit
import TelegramCore
import Display
import LegacyComponents
import LegacyMediaPickerUI
import TextFormat
import ImageCompression
import LocalMediaResources
import MediaEditor

struct ChatMediaSendCaption {
    let text: String
    let entities: [MessageTextEntity]
    let bubbleUpEmojiOrStickersets: [EngineItemCollectionId]
}

func chatMediaSendCaption(_ caption: NSAttributedString?) -> ChatMediaSendCaption {
    let text = trimChatInputText(convertMarkdownToAttributes(caption ?? NSAttributedString()))
    let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))

    var bubbleUpEmojiOrStickersetsById: [Int64: EngineItemCollectionId] = [:]
    text.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: text.length), using: { value, _, _ in
        if let value = value as? ChatTextInputTextCustomEmojiAttribute {
            if let file = value.file {
                if let packId = value.interactivelySelectedFromPackId {
                    bubbleUpEmojiOrStickersetsById[file.fileId.id] = packId
                }
            }
        }
    })
    var bubbleUpEmojiOrStickersets: [EngineItemCollectionId] = []
    for entity in entities {
        if case let .CustomEmoji(_, fileId) = entity.type {
            if let packId = bubbleUpEmojiOrStickersetsById[fileId] {
                if !bubbleUpEmojiOrStickersets.contains(packId) {
                    bubbleUpEmojiOrStickersets.append(packId)
                }
            }
        }
    }
    return ChatMediaSendCaption(text: text.string, entities: entities, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
}

func chatMediaSendMessage(media: EngineRawMedia, mediaReference: AnyMediaReference? = nil, caption: ChatMediaSendCaption, stickerFiles: [TelegramMediaFile], timer: Int32?, spoiler: Bool, groupingKey: Int64?, uniqueId: String?) -> LegacyAssetPickerEnqueueMessage {
    var attributes: [EngineMessage.Attribute] = []
    if !stickerFiles.isEmpty {
        attributes.append(EmbeddedMediaStickersMessageAttribute(files: stickerFiles))
    }
    if let timer, timer > 0 && (timer <= 60 || timer == viewOnceTimeout) {
        attributes.append(AutoremoveTimeoutMessageAttribute(timeout: timer, countdownBeginTime: nil))
    }
    if spoiler {
        attributes.append(MediaSpoilerMessageAttribute())
    }
    if !caption.entities.isEmpty {
        attributes.append(TextEntitiesMessageAttribute(entities: caption.entities))
    }
    return LegacyAssetPickerEnqueueMessage(
        message: .message(text: caption.text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference ?? .standalone(media: media), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: caption.bubbleUpEmojiOrStickersets),
        uniqueId: uniqueId,
        isFile: false
    )
}

func chatMediaSendThumbnailRepresentation(thumbnail: UIImage, fittedTo size: CGSize, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaImageRepresentation? {
    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
    let thumbnailSize = size.aspectFitted(CGSize(width: 320.0, height: 320.0))
    guard let thumbnailImage = TGScaleImageToPixelSize(thumbnail, thumbnailSize), let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) else {
        return nil
    }
    storeResourceData(EngineMediaResource.Id(resource.id), thumbnailData)
    return TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
}

func chatMediaSendVideoCover(_ cover: UIImage, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaImage? {
    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
    let maxSide: CGFloat = 1280.0
    let coverSize = cover.size.aspectFitted(CGSize(width: maxSide, height: maxSide))
    guard let coverImage = TGScaleImageToPixelSize(cover, coverSize), let coverData = coverImage.jpegData(compressionQuality: 0.87) else {
        return nil
    }
    storeResourceData(EngineMediaResource.Id(resource.id), coverData)
    return TelegramMediaImage(
        imageId: EngineMedia.Id(namespace: 0, id: 0),
        representations: [
            TelegramMediaImageRepresentation(dimensions: PixelDimensions(coverSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
        ],
        immediateThumbnailData: nil,
        reference: nil,
        partialReference: nil,
        flags: []
    )
}

func chatMediaSendRenderedImageMedia(image: UIImage, nominalDimensions: PixelDimensions, thumbnail: UIImage?, stickerFiles: [TelegramMediaFile], forceHd: Bool, livePhotoVideo: TelegramMediaFile? = nil, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaImage? {
    var representations: [TelegramMediaImageRepresentation] = []
    if let thumbnail {
        if let representation = chatMediaSendThumbnailRepresentation(thumbnail: thumbnail, fittedTo: thumbnail.size, storeResourceData: storeResourceData) {
            representations.append(representation)
        }
    }

    var randomId: Int64 = 0
    arc4random_buf(&randomId, 8)
    let tempFilePath = NSTemporaryDirectory() + "\(randomId).jpeg"
    let scaledSize = chatMediaEditorImageSendSize(nominalDimensions: nominalDimensions, forceHd: forceHd)
    guard let scaledImage = TGScaleImageToPixelSize(image, scaledSize) else {
        return nil
    }
    let tempFile = EngineTempBox.shared.tempFile(fileName: "file")
    defer {
        EngineTempBox.shared.dispose(tempFile)
    }
    guard let scaledImageData = compressImageToJPEG(scaledImage, quality: 0.6, tempFilePath: tempFile.path) else {
        return nil
    }
    let _ = try? scaledImageData.write(to: URL(fileURLWithPath: tempFilePath))

    let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath, randomId: randomId)
    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))

    var imageFlags: TelegramMediaImageFlags = []
    if !stickerFiles.isEmpty {
        imageFlags.insert(.hasStickers)
    }
    if livePhotoVideo != nil {
        imageFlags.insert(.isLivePhoto)
    }
    return TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: randomId), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: imageFlags, video: livePhotoVideo)
}

func chatMediaSendLibraryPhotoMedia(identifier: String, pixelSize: CGSize, thumbnail: UIImage?, forceHd: Bool, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaImage {
    var representations: [TelegramMediaImageRepresentation] = []
    if let thumbnail {
        if let representation = chatMediaSendThumbnailRepresentation(thumbnail: thumbnail, fittedTo: thumbnail.size, storeResourceData: storeResourceData) {
            representations.append(representation)
        }
    }

    var randomId: Int64 = 0
    arc4random_buf(&randomId, 8)
    let scaledSize = pixelSize.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
    let resource = PhotoLibraryMediaResource(localIdentifier: identifier, uniqueId: Int64.random(in: Int64.min ... Int64.max), forceHd: forceHd)
    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
    return TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: randomId), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
}

func chatMediaSendLegacyConversionPreset(_ preset: MediaQualityPreset?) -> TGMediaVideoConversionPreset {
    switch preset ?? .compressedMedium {
    case .compressedDefault:
        return TGMediaVideoConversionPresetCompressedDefault
    case .compressedVeryLow:
        return TGMediaVideoConversionPresetCompressedVeryLow
    case .compressedLow:
        return TGMediaVideoConversionPresetCompressedLow
    case .compressedMedium:
        return TGMediaVideoConversionPresetCompressedMedium
    case .compressedHigh:
        return TGMediaVideoConversionPresetCompressedHigh
    case .compressedVeryHigh:
        return TGMediaVideoConversionPresetCompressedVeryHigh
    case .animation:
        return TGMediaVideoConversionPresetAnimation
    default:
        return TGMediaVideoConversionPresetCompressedMedium
    }
}

private func chatMediaSendVideoFile(resource: TelegramMediaResource, dimensions: PixelDimensions, duration: Double, estimatedSize: UInt, fileName: String, previewRepresentations: [TelegramMediaImageRepresentation], videoCover: TelegramMediaImage?, stickerFiles: [TelegramMediaFile], isAnimated: Bool = false) -> TelegramMediaFile {
    var fileAttributes: [TelegramMediaFileAttribute] = []
    fileAttributes.append(.FileName(fileName: fileName))
    fileAttributes.append(.Video(duration: duration, size: dimensions, flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil))
    if isAnimated {
        fileAttributes.append(.Animated)
    }
    if estimatedSize > 10 * 1024 * 1024 {
        fileAttributes.append(.hintFileIsLarge)
    }
    if !stickerFiles.isEmpty {
        fileAttributes.append(.HasLinkedStickers)
    }
    return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], videoCover: videoCover, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: fileAttributes, alternativeRepresentations: [])
}

func chatMediaSendEditedVideoFile(resource: TelegramMediaResource, values: MediaEditorValues, duration: Double, fileName: String, thumbnail: UIImage?, cover: UIImage?, stickerFiles: [TelegramMediaFile], storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaFile {
    let finalDuration = chatMediaEditorVideoDuration(values: values, duration: duration)
    let finalDimensions = chatMediaEditorVideoFileDimensions(values: values, duration: duration)

    var previewRepresentations: [TelegramMediaImageRepresentation] = []
    if let thumbnail {
        if let representation = chatMediaSendThumbnailRepresentation(thumbnail: thumbnail, fittedTo: finalDimensions.cgSize, storeResourceData: storeResourceData) {
            previewRepresentations.append(representation)
        }
    }
    let videoCover = cover.flatMap { chatMediaSendVideoCover($0, storeResourceData: storeResourceData) }

    let estimatedSize = TGMediaVideoConverter.estimatedSize(for: chatMediaSendLegacyConversionPreset(values.qualityPreset), duration: finalDuration, hasAudio: !values.videoIsMuted)
    return chatMediaSendVideoFile(resource: resource, dimensions: finalDimensions, duration: finalDuration, estimatedSize: estimatedSize, fileName: fileName, previewRepresentations: previewRepresentations, videoCover: videoCover, stickerFiles: stickerFiles, isAnimated: values.videoIsMuted)
}

func chatMediaSendUneditedVideoConversionPreset(dimensions: CGSize) -> TGMediaVideoConversionPreset {
    var preset = TGMediaVideoConverter.preset(from: nil)
    let unclampedPresets: [TGMediaVideoConversionPreset] = [
        TGMediaVideoConversionPresetAnimation,
        TGMediaVideoConversionPresetVideoMessage,
        TGMediaVideoConversionPresetProfile,
        TGMediaVideoConversionPresetProfileLow,
        TGMediaVideoConversionPresetProfileHigh,
        TGMediaVideoConversionPresetProfileVeryHigh,
        TGMediaVideoConversionPresetPassthrough
    ]
    if dimensions != .zero && !unclampedPresets.contains(preset) {
        let bestPreset = TGMediaVideoConverter.bestAvailablePreset(forDimensions: dimensions)
        if preset.rawValue > bestPreset.rawValue {
            preset = bestPreset
        }
    }
    return preset
}

func chatMediaSendUneditedVideoFile(resource: TelegramMediaResource, dimensions: CGSize, duration: Double, fileName: String, thumbnail: UIImage?, cover: UIImage?, stickerFiles: [TelegramMediaFile], storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaFile {
    var previewRepresentations: [TelegramMediaImageRepresentation] = []
    if let thumbnail {
        if let representation = chatMediaSendThumbnailRepresentation(thumbnail: thumbnail, fittedTo: dimensions, storeResourceData: storeResourceData) {
            previewRepresentations.append(representation)
        }
    }
    let videoCover = cover.flatMap { chatMediaSendVideoCover($0, storeResourceData: storeResourceData) }

    let preset = chatMediaSendUneditedVideoConversionPreset(dimensions: dimensions)
    let finalDimensions = TGMediaVideoConverter.dimensions(for: dimensions, adjustments: nil, preset: preset)
    let estimatedSize = TGMediaVideoConverter.estimatedSize(for: preset, duration: duration, hasAudio: true)
    return chatMediaSendVideoFile(resource: resource, dimensions: PixelDimensions(finalDimensions), duration: duration, estimatedSize: estimatedSize, fileName: fileName, previewRepresentations: previewRepresentations, videoCover: videoCover, stickerFiles: stickerFiles)
}

func chatMediaSendVideoSendValues(_ values: MediaEditorValues) -> MediaEditorValues {
    if values.videoIsMuted {
        return values.withUpdatedQualityPreset(.animation)
    } else {
        return values
    }
}

let chatMediaSendGifPlaceholderPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0))

func chatMediaSendGifValues(_ values: MediaEditorValues?, converted: ChatMediaSendConvertedGif) -> MediaEditorValues {
    let base = values ?? chatMediaEditorValues(peerId: chatMediaSendGifPlaceholderPeerId, originalDimensions: converted.dimensions, qualityPreset: .animation)
    return base.withUpdatedQualityPreset(.animation).withUpdatedVideoIsMuted(true)
}

private func chatMediaSendLibraryFileName(_ fileName: String?) -> String {
    if let fileName, !fileName.isEmpty {
        return (fileName as NSString).lastPathComponent
    } else {
        return "video.mp4"
    }
}

private func chatMediaSendItemMedia(item: ChatMediaSendItem, forceHd: Bool, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> (media: EngineRawMedia, stickerFiles: [TelegramMediaFile])? {
    if let preparedImage = item.preparedImage {
        return (preparedImage, item.stickers)
    }
    if chatMediaSendItemIsAnimatedPhoto(item) {
        guard let file = chatMediaSendAnimatedPhotoFile(item: item, storeResourceData: storeResourceData) else {
            return nil
        }
        return (file, item.stickers)
    }
    switch item.source {
    case let .libraryAsset(identifier, pixelSize, isVideo, duration):
        if isVideo {
            let fileName = chatMediaSendLibraryFileName(item.fileName)
            if let values = item.values.map(chatMediaSendVideoSendValues) {
                guard let adjustments = chatMediaEditorVideoAdjustments(values: values) else {
                    return nil
                }
                let resource = VideoLibraryMediaResource(localIdentifier: identifier, conversion: .compress(adjustments))
                return (chatMediaSendEditedVideoFile(resource: resource, values: values, duration: duration, fileName: fileName, thumbnail: item.thumbnail, cover: item.coverImage, stickerFiles: item.stickers, storeResourceData: storeResourceData), item.stickers)
            } else {
                let resource = VideoLibraryMediaResource(localIdentifier: identifier, conversion: .compress(nil))
                return (chatMediaSendUneditedVideoFile(resource: resource, dimensions: pixelSize, duration: duration, fileName: fileName, thumbnail: item.thumbnail, cover: item.coverImage, stickerFiles: item.stickers, storeResourceData: storeResourceData), item.stickers)
            }
        } else if let renderedImage = item.renderedImage {
            let nominalDimensions = item.values.map(chatMediaEditorCroppedNominalDimensions(values:)) ?? PixelDimensions(pixelSize)
            guard let media = chatMediaSendRenderedImageMedia(image: renderedImage, nominalDimensions: nominalDimensions, thumbnail: item.thumbnail, stickerFiles: item.stickers, forceHd: forceHd, storeResourceData: storeResourceData) else {
                return nil
            }
            return (media, item.stickers)
        } else {
            return (chatMediaSendLibraryPhotoMedia(identifier: identifier, pixelSize: pixelSize, thumbnail: item.thumbnail, forceHd: forceHd, storeResourceData: storeResourceData), [])
        }
    case let .image(image):
        let sourceImage = item.renderedImage ?? image
        let nominalDimensions = item.values.map(chatMediaEditorCroppedNominalDimensions(values:)) ?? PixelDimensions(sourceImage.size)
        guard let media = chatMediaSendRenderedImageMedia(image: sourceImage, nominalDimensions: nominalDimensions, thumbnail: item.thumbnail, stickerFiles: item.stickers, forceHd: forceHd, storeResourceData: storeResourceData) else {
            return nil
        }
        return (media, item.stickers)
    case let .imageFile(path, dimensions):
        let nominalDimensions = item.values.map(chatMediaEditorCroppedNominalDimensions(values:)) ?? dimensions
        let sourceImage: UIImage
        if let renderedImage = item.renderedImage {
            sourceImage = renderedImage
        } else {
            let sendSize = chatMediaEditorImageSendSize(nominalDimensions: nominalDimensions, forceHd: forceHd)
            guard let scaledImage = chatMediaSendScaledFileImage(path: path, maxPixelSide: max(sendSize.width, sendSize.height)) else {
                return nil
            }
            sourceImage = scaledImage
        }
        guard let media = chatMediaSendRenderedImageMedia(image: sourceImage, nominalDimensions: nominalDimensions, thumbnail: item.thumbnail ?? sourceImage, stickerFiles: item.stickers, forceHd: forceHd, storeResourceData: storeResourceData) else {
            return nil
        }
        return (media, item.stickers)
    case let .tempVideo(path, dimensions, duration):
        if let values = item.values.map(chatMediaSendVideoSendValues) {
            guard let adjustments = chatMediaEditorVideoAdjustments(values: values) else {
                return nil
            }
            let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: path, adjustments: adjustments)
            return (chatMediaSendEditedVideoFile(resource: resource, values: values, duration: duration, fileName: "video.mp4", thumbnail: item.thumbnail, cover: item.coverImage, stickerFiles: item.stickers, storeResourceData: storeResourceData), item.stickers)
        } else {
            let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: path, adjustments: nil)
            return (chatMediaSendUneditedVideoFile(resource: resource, dimensions: dimensions.cgSize, duration: duration, fileName: "video.mp4", thumbnail: item.thumbnail, cover: item.coverImage, stickerFiles: item.stickers, storeResourceData: storeResourceData), item.stickers)
        }
    case .gifAsset:
        guard let converted = item.convertedGif else {
            return nil
        }
        let values = chatMediaSendGifValues(item.values, converted: converted)
        guard let adjustments = chatMediaEditorVideoAdjustments(values: values) else {
            return nil
        }
        let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: converted.path, adjustments: adjustments)
        return (chatMediaSendEditedVideoFile(resource: resource, values: values, duration: converted.duration, fileName: "video.mp4", thumbnail: item.thumbnail, cover: nil, stickerFiles: item.stickers, storeResourceData: storeResourceData), item.stickers)
    case let .livePhoto(_, pixelSize, mode):
        guard let media = chatMediaSendLivePhotoMedia(item: item, pixelSize: pixelSize, mode: mode, storeResourceData: storeResourceData) else {
            return nil
        }
        return (media, item.stickers)
    case let .prebuilt(media):
        guard let media else {
            return nil
        }
        return (media, item.stickers)
    }
}

func chatMediaSendBuildMessages(items: [ChatMediaSendItem], plan: [ChatMediaSendPlannedItem], forceHd: Bool, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> [LegacyAssetPickerEnqueueMessage] {
    return chatMediaSendBuildMessagesReportingSkipped(items: items, plan: plan, forceHd: forceHd, storeResourceData: storeResourceData).messages
}

func chatMediaSendBuildMessagesReportingSkipped(items: [ChatMediaSendItem], plan: [ChatMediaSendPlannedItem], forceHd: Bool, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> (messages: [LegacyAssetPickerEnqueueMessage], skippedIndices: [Int]) {
    struct PaidMessage {
        var price: Int64
        var text: String
        var entities: [MessageTextEntity]
        var media: [EngineRawMedia]
    }

    var messages: [LegacyAssetPickerEnqueueMessage] = []
    var paidMessage: PaidMessage?
    var skippedIndices: [Int] = []

    for planned in plan {
        guard planned.index >= 0 && planned.index < items.count else {
            continue
        }
        let item = items[planned.index]
        guard let (media, stickerFiles) = chatMediaSendItemMedia(item: item, forceHd: forceHd && item.options.allowsHd, storeResourceData: storeResourceData) else {
            skippedIndices.append(planned.index)
            continue
        }
        let caption = chatMediaSendCaption(planned.caption)

        if let price = planned.price {
            if var current = paidMessage {
                if current.text.isEmpty && !caption.text.isEmpty {
                    current.text = caption.text
                    current.entities = caption.entities
                }
                current.media.append(media)
                paidMessage = current
            } else {
                paidMessage = PaidMessage(price: price, text: caption.text, entities: caption.entities, media: [media])
            }
        } else {
            messages.append(chatMediaSendMessage(media: media, caption: caption, stickerFiles: stickerFiles, timer: planned.timer, spoiler: planned.spoiler, groupingKey: planned.groupingKey, uniqueId: item.uniqueId))
        }
    }

    if let paidMessage {
        var attributes: [EngineMessage.Attribute] = []
        if !paidMessage.entities.isEmpty {
            attributes.append(TextEntitiesMessageAttribute(entities: paidMessage.entities))
        }
        messages.append(LegacyAssetPickerEnqueueMessage(
            message: .message(
                text: paidMessage.text,
                attributes: attributes,
                inlineStickers: [:],
                mediaReference: .standalone(media: TelegramMediaPaidContent(amount: paidMessage.price, extendedMedia: paidMessage.media.map { .full(media: $0) })),
                threadId: nil,
                replyToMessageId: nil,
                replyToStoryId: nil,
                localGroupingKey: nil,
                correlationId: nil,
                bubbleUpEmojiOrStickersets: []
            ),
            uniqueId: nil,
            isFile: false
        ))
    }

    return (messages, skippedIndices)
}
