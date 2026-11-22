import Foundation
import UIKit
import Photos
import SwiftSignalKit
import TelegramCore
import AccountContext
import LegacyComponents
import LegacyMediaPickerUI
import MediaEditor
import MediaAssetsContext
import ChatMediaSend

final class MediaPickerChatMediaSendLegacyContext: MediaPickerChatMediaSendSelection, MediaPickerChatMediaSendEditing {
    private let editingContext: TGMediaEditingContext?
    private let isPasteboard: Bool
    private let itemsById: [String: NSObject]

    let selectedUniqueIds: [String]
    let grouping: Bool
    let forcedCaption: NSAttributedString?
    let isHighQualityPhoto: Bool

    init(selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext?, isPasteboard: Bool) {
        self.editingContext = editingContext
        self.isPasteboard = isPasteboard

        var selectedUniqueIds: [String] = []
        var itemsById: [String: NSObject] = [:]
        for item in selectionContext?.selectedItems() ?? [] {
            guard let item = item as? NSObject, let selectable = item as? TGMediaSelectableItem, let uniqueId = selectable.uniqueIdentifier else {
                continue
            }
            if itemsById[uniqueId] == nil {
                selectedUniqueIds.append(uniqueId)
            }
            itemsById[uniqueId] = item
        }
        self.selectedUniqueIds = selectedUniqueIds
        self.itemsById = itemsById
        self.grouping = selectionContext?.grouping ?? false

        var forcedCaption: NSAttributedString?
        if let signal = editingContext?.forcedCaption() {
            let disposable = signal.start(next: { value in
                forcedCaption = value as? NSAttributedString
            }, error: { _ in
            }, completed: {
            })
            disposable?.dispose()
        }
        self.forcedCaption = forcedCaption
        self.isHighQualityPhoto = isPasteboard ? false : (editingContext?.isHighQualityPhoto() ?? false)
    }

    func item(for uniqueId: String) -> NSObject? {
        return self.itemsById[uniqueId]
    }

    private func editableItem(for uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.itemsById[uniqueId] as? (NSObject & TGMediaEditableItem)
    }

    func caption(for uniqueId: String) -> NSAttributedString? {
        guard let item = self.editableItem(for: uniqueId) else {
            return nil
        }
        return self.editingContext?.caption(for: item)
    }

    func timer(for uniqueId: String) -> Int32? {
        guard let item = self.editableItem(for: uniqueId) else {
            return nil
        }
        return self.editingContext?.timer(for: item)?.int32Value
    }

    func spoiler(for uniqueId: String) -> Bool {
        guard let item = self.editableItem(for: uniqueId) else {
            return false
        }
        return self.editingContext?.spoiler(for: item) ?? false
    }

    func price(for uniqueId: String) -> Int64? {
        guard !self.isPasteboard, let item = self.editableItem(for: uniqueId) else {
            return nil
        }
        return self.editingContext?.price(for: item)?.int64Value
    }

    func coverImage(for uniqueId: String) -> UIImage? {
        guard let item = self.editableItem(for: uniqueId) else {
            return nil
        }
        return self.editingContext?.coverImage(for: item)
    }

    func hasLegacyAdjustments(for uniqueId: String) -> Bool {
        guard let item = self.editableItem(for: uniqueId) else {
            return false
        }
        return self.editingContext?.adjustments(for: item) != nil
    }

    func livePhotoMode(_ asset: TGMediaAsset) -> ChatMediaSendLivePhotoMode {
        guard let editingContext = self.editingContext else {
            return .off
        }
        let stored = editingContext.livePhotoMode(for: asset).map { ChatMediaSendLivePhotoMode(legacy: TGMediaLivePhotoMode(rawValue: $0.uintValue) ?? .off) }
        let isLiveAsset = asset.backingAsset?.mediaSubtypes.contains(.photoLive) ?? false
        return chatMediaSendResolvedLivePhotoMode(stored: stored, isLiveAsset: isLiveAsset, forceLivePhotoEnabled: editingContext.isForceLivePhotoEnabled())
    }

    func source(for uniqueId: String, thumbnail: UIImage?) -> MediaPickerChatMediaSendSource? {
        guard let item = self.itemsById[uniqueId] else {
            return nil
        }
        if let image = item as? UIImage {
            return .image(image)
        }
        if let video = item as? TGCameraCapturedVideo {
            if let originalAsset = video.originalAsset {
                if let backingAsset = originalAsset.backingAsset {
                    return .capturedLibraryVideo(identifier: backingAsset.localIdentifier, pixelSize: CGSize(width: CGFloat(backingAsset.pixelWidth), height: CGFloat(backingAsset.pixelHeight)), duration: backingAsset.duration, isGif: originalAsset.type == TGMediaAssetGifType)
                }
            } else if let avAsset = video.immediateAVAsset {
                let size = video.dimensions
                if size.width > 0.0, size.height > 0.0, video.videoDuration > 0.0 {
                    return .capturedVideo(path: avAsset.url.path, dimensions: PixelDimensions(width: Int32(size.width), height: Int32(size.height)), duration: video.videoDuration)
                }
            }
            return .unsupported(.capturedVideo)
        }
        guard let asset = item as? TGMediaAsset, let backingAsset = asset.backingAsset else {
            return nil
        }
        let pixelSize = CGSize(width: CGFloat(backingAsset.pixelWidth), height: CGFloat(backingAsset.pixelHeight))
        if asset.type == TGMediaAssetGifType {
            return .gif(identifier: backingAsset.localIdentifier, pixelSize: pixelSize, thumbnail: thumbnail)
        }
        if backingAsset.mediaType == .video {
            return .video(identifier: backingAsset.localIdentifier, pixelSize: pixelSize, duration: backingAsset.duration, thumbnail: thumbnail)
        }
        let livePhotoMode = self.livePhotoMode(asset)
        if livePhotoMode != .off {
            return .livePhoto(identifier: backingAsset.localIdentifier, pixelSize: pixelSize, mode: livePhotoMode, thumbnail: thumbnail)
        }
        return .photo(identifier: backingAsset.localIdentifier, pixelSize: pixelSize, thumbnail: thumbnail)
    }

    func backingAsset(for uniqueId: String) -> PHAsset? {
        return (self.itemsById[uniqueId] as? TGMediaAsset)?.backingAsset
    }
}

func mediaPickerChatMediaSendLegacyMedia(context: AccountContext, legacyContext: MediaPickerChatMediaSendLegacyContext, editingContext: TGMediaEditingContext?, uniqueIds: [String], isPasteboard: Bool, saveEditedPhotos: Bool) -> Signal<[String: ChatMediaSendLegacyMedia], NoError> {
    var signals: [Signal<(String, ChatMediaSendLegacyMedia?), NoError>] = []
    for uniqueId in uniqueIds {
        guard let item = legacyContext.item(for: uniqueId) as? TGMediaSelectableItem, let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 1) else {
            signals.append(.single((uniqueId, nil)))
            continue
        }
        selectionContext.setItem(item, selected: true)
        let resultSignals: [Any]?
        if isPasteboard {
            resultSignals = TGMediaAssetsController.pasteboardResultSignals(for: selectionContext, editingContext: editingContext, intent: TGMediaAssetsControllerSendMediaIntent, currentItem: nil, descriptionGenerator: legacyAssetPickerItemGenerator())
        } else {
            resultSignals = TGMediaAssetsController.resultSignals(for: selectionContext, editingContext: editingContext, intent: TGMediaAssetsControllerSendMediaIntent, currentItem: nil, storeAssets: true, convertToJpeg: false, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: saveEditedPhotos)
        }
        guard let resultSignals, !resultSignals.isEmpty else {
            signals.append(.single((uniqueId, nil)))
            continue
        }
        let media: Signal<ChatMediaSendLegacyMedia?, NoError> = legacyAssetPickerEnqueueMessages(context: context, account: context.account, signals: resultSignals)
        |> map { messages -> ChatMediaSendLegacyMedia? in
            return chatMediaSendLegacyMedia(messages: messages)
        }
        |> `catch` { _ -> Signal<ChatMediaSendLegacyMedia?, NoError> in
            return .single(nil)
        }
        signals.append((media
        |> then(.single(nil))
        |> take(1))
        |> map { media -> (String, ChatMediaSendLegacyMedia?) in
            return (uniqueId, media)
        })
    }
    if signals.isEmpty {
        return .single([:])
    }
    return chatMediaSendBoundedCombine(signals, maxConcurrent: 1)
    |> map { results -> [String: ChatMediaSendLegacyMedia] in
        var result: [String: ChatMediaSendLegacyMedia] = [:]
        for case let (uniqueId, media)? in results {
            if let media {
                result[uniqueId] = media
            }
        }
        return result
    }
}

func mediaPickerAssetOriginalFileName(_ asset: PHAsset) -> String? {
    let resources = PHAssetResource.assetResources(for: asset)
    let preferredTypes: [PHAssetResourceType] = asset.mediaType == .video ? [.video, .fullSizeVideo] : [.photo, .fullSizePhoto]
    for type in preferredTypes {
        if let resource = resources.first(where: { $0.type == type }), !resource.originalFilename.isEmpty {
            return resource.originalFilename
        }
    }
    return resources.first(where: { !$0.originalFilename.isEmpty })?.originalFilename
}

let mediaPickerChatMediaSendAssetThumbnailSize = CGSize(width: 256.0, height: 256.0)

private func mediaPickerChatMediaSendAssetThumbnail(_ asset: PHAsset) -> Signal<UIImage?, NoError> {
    return last(signal: assetImage(asset: asset, targetSize: mediaPickerChatMediaSendAssetThumbnailSize, exact: false, deliveryMode: .highQualityFormat))
    |> map { image -> UIImage? in
        return image ?? nil
    }
}

func mediaPickerChatMediaSendPrepareThumbnails(context: AccountContext, legacyContext: MediaPickerChatMediaSendLegacyContext, store: ChatMediaEditorItemStore) -> Signal<[String: UIImage], NoError> {
    var signals: [Signal<(String, UIImage?, Bool), NoError>] = []
    var editedVideoSignals: [Signal<(String, UIImage?, Bool), NoError>] = []
    for uniqueId in legacyContext.selectedUniqueIds {
        guard let asset = legacyContext.backingAsset(for: uniqueId) else {
            continue
        }
        let editedValues = mediaPickerChatMediaSendEditedValues(store: store, uniqueId: uniqueId)
        if asset.mediaType == .video, let editedValues {
            editedVideoSignals.append(chatMediaSendEditedVideoThumbnail(context: context, identifier: asset.localIdentifier, values: editedValues)
            |> mapToSignal { image -> Signal<(String, UIImage?, Bool), NoError> in
                if let image {
                    return .single((uniqueId, image, true))
                }
                return mediaPickerChatMediaSendAssetThumbnail(asset)
                |> map { image in
                    return (uniqueId, image, false)
                }
            })
        } else if editedValues == nil || store.entry(for: uniqueId)?.thumbnail == nil {
            signals.append(mediaPickerChatMediaSendAssetThumbnail(asset)
            |> map { image in
                return (uniqueId, image, false)
            })
        }
    }
    return combineLatest(combineLatest(signals), chatMediaSendBoundedCombine(editedVideoSignals, maxConcurrent: chatMediaSendMaxConcurrentVideoThumbnails))
    |> take(1)
    |> deliverOnMainQueue
    |> map { assetResults, editedVideoResults -> [String: UIImage] in
        let results = assetResults + editedVideoResults.compactMap { $0 }
        var assetThumbnails: [String: UIImage] = [:]
        for (uniqueId, image, isEditedVideo) in results {
            guard let image else {
                continue
            }
            if isEditedVideo {
                store.update(uniqueId) { entry in
                    entry.thumbnail = image
                }
            } else {
                assetThumbnails[uniqueId] = image
            }
        }
        return assetThumbnails
    }
}
