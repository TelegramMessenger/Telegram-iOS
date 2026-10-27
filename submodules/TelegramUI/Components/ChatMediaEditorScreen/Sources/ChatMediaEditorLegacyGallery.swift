import Foundation
import UIKit
import Photos
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import LegacyComponents
import MediaAssetsContext
import ChatMediaSend

public final class ChatMediaEditorLegacyItemResolver {
    private weak var selectionContext: TGMediaSelectionContext?
    private let lookup: (String) -> NSObject?
    private var items: [String: NSObject] = [:]
    private var misses = Set<String>()

    public init(selectionContext: TGMediaSelectionContext?, items: [NSObject], lookup: @escaping (String) -> NSObject?) {
        self.selectionContext = selectionContext
        self.lookup = lookup
        for item in items {
            self.register(item)
        }
        for item in selectionContext?.selectedItems() ?? [] {
            if let item = item as? NSObject {
                self.register(item)
            }
        }
    }

    public func register(_ item: NSObject) {
        guard let uniqueId = (item as? TGMediaSelectableItem)?.uniqueIdentifier else {
            return
        }
        self.items[uniqueId] = item
        self.misses.remove(uniqueId)
    }

    public func item(for uniqueId: String) -> NSObject? {
        if let item = self.items[uniqueId] {
            return item
        }
        for item in self.selectionContext?.selectedItems() ?? [] {
            if let item = item as? NSObject, (item as? TGMediaSelectableItem)?.uniqueIdentifier == uniqueId {
                self.items[uniqueId] = item
                return item
            }
        }
        if self.misses.contains(uniqueId) {
            return nil
        }
        if let item = self.lookup(uniqueId) {
            self.register(item)
            self.items[uniqueId] = item
            return item
        }
        self.misses.insert(uniqueId)
        return nil
    }
}

public final class ChatMediaEditorLegacySelectionAdapter: ChatMediaEditorSelectionAdapter {
    private let selectionContext: TGMediaSelectionContext
    private let resolver: ChatMediaEditorLegacyItemResolver

    public init(selectionContext: TGMediaSelectionContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.selectionContext = selectionContext
        self.resolver = resolver
    }

    public var selectionLimit: Int {
        return Int(self.selectionContext.selectionLimit)
    }

    public func isSelected(_ uniqueId: String) -> Bool {
        return self.selectionContext.isIdentifierSelected(uniqueId)
    }

    public func index(of uniqueId: String) -> Int? {
        guard self.isSelected(uniqueId), let item = self.resolver.item(for: uniqueId) as? TGMediaSelectableItem else {
            return nil
        }
        return chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: Int(self.selectionContext.index(of: item)))
    }

    public func selectedIds() -> [String] {
        return (self.selectionContext.selectedItemsIdentifiers()?.array ?? []).compactMap { $0 as? String }
    }

    public func setSelected(_ uniqueId: String, _ selected: Bool, sender: AnyObject?) -> Bool {
        guard let item = self.resolver.item(for: uniqueId) as? TGMediaSelectableItem else {
            return false
        }
        return self.selectionContext.setItem(item, selected: selected, animated: true, sender: sender)
    }

    public var changes: Signal<Void, NoError> {
        let selectionContext = self.selectionContext
        return Signal { subscriber in
            let disposable = selectionContext.selectionChangedSignal().start(next: { _ in
                subscriber.putNext(Void())
            }, error: { _ in
            }, completed: {
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
}

public protocol ChatMediaEditorLegacyThumbnailTarget: AnyObject {
    func hasAdjustments(_ uniqueId: String) -> Bool
    func clearAdjustments(_ uniqueId: String)
    func setTemporaryRep(_ image: UIImage, for uniqueId: String)
    func setImage(_ image: UIImage?, for uniqueId: String)
    func originalThumbnail(_ uniqueId: String) -> Signal<UIImage, NoError>
}

public final class ChatMediaEditorLegacyThumbnailWriter {
    private let target: ChatMediaEditorLegacyThumbnailTarget
    private let generations = Atomic<[String: Int]>(value: [:])

    public init(target: ChatMediaEditorLegacyThumbnailTarget) {
        self.target = target
    }

    public func hasExternalEdits(for uniqueId: String) -> Bool {
        return self.target.hasAdjustments(uniqueId)
    }

    public func write(_ image: UIImage?, for uniqueId: String) {
        let target = self.target
        if target.hasAdjustments(uniqueId) {
            target.clearAdjustments(uniqueId)
        }
        let generation = self.generations.modify { current in
            var current = current
            current[uniqueId] = (current[uniqueId] ?? 0) + 1
            return current
        }[uniqueId] ?? 0
        if let image {
            target.setTemporaryRep(chatMediaEditorDetachedImage(image), for: uniqueId)
            target.setImage(image, for: uniqueId)
            return
        }
        target.setImage(nil, for: uniqueId)
        let generations = self.generations
        let _ = (target.originalThumbnail(uniqueId)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { original in
            guard generations.with({ $0[uniqueId] }) == generation else {
                return
            }
            target.setTemporaryRep(chatMediaEditorDetachedImage(original), for: uniqueId)
        })
    }
}

private func chatMediaEditorDetachedImage(_ image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage else {
        return image
    }
    return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
}

private final class ChatMediaEditorLegacyEditingThumbnailTarget: ChatMediaEditorLegacyThumbnailTarget {
    private let editingContext: TGMediaEditingContext
    private let resolver: ChatMediaEditorLegacyItemResolver

    init(editingContext: TGMediaEditingContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.editingContext = editingContext
        self.resolver = resolver
    }

    private func editableItem(_ uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.resolver.item(for: uniqueId) as? (NSObject & TGMediaEditableItem)
    }

    func hasAdjustments(_ uniqueId: String) -> Bool {
        guard let item = self.editableItem(uniqueId) else {
            return false
        }
        return self.editingContext.adjustments(for: item) != nil
    }

    func clearAdjustments(_ uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setAdjustments(nil, for: item)
    }

    func setTemporaryRep(_ image: UIImage, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setTemporaryRep(image, for: item)
    }

    func setImage(_ image: UIImage?, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setImage(image, thumbnailImage: image, for: item, synchronous: false)
    }

    func originalThumbnail(_ uniqueId: String) -> Signal<UIImage, NoError> {
        guard let item = self.editableItem(uniqueId) else {
            return .complete()
        }
        return chatMediaEditorLegacyOriginalThumbnail(item)
    }
}

public final class ChatMediaEditorLegacyTimerAdapter: ChatMediaEditorTimerAdapter {
    private let editingContext: TGMediaEditingContext
    private let resolver: ChatMediaEditorLegacyItemResolver

    public init(editingContext: TGMediaEditingContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.editingContext = editingContext
        self.resolver = resolver
    }

    private func editableItem(_ uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.resolver.item(for: uniqueId) as? (NSObject & TGMediaEditableItem)
    }

    public func timer(for uniqueId: String) -> Int32? {
        guard let item = self.editableItem(uniqueId) else {
            return nil
        }
        return chatMediaEditorTimerValue(self.editingContext.timer(for: item)?.int32Value)
    }

    public func setTimer(_ timer: Int32?, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setTimer(chatMediaEditorTimerValue(timer).flatMap { NSNumber(value: $0) }, for: item)
    }
}

public final class ChatMediaEditorLegacyCoverAdapter: ChatMediaEditorCoverAdapter {
    private let editingContext: TGMediaEditingContext
    private let resolver: ChatMediaEditorLegacyItemResolver

    public init(editingContext: TGMediaEditingContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.editingContext = editingContext
        self.resolver = resolver
    }

    private func editableItem(_ uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.resolver.item(for: uniqueId) as? (NSObject & TGMediaEditableItem)
    }

    public func coverImage(for uniqueId: String) -> UIImage? {
        guard let item = self.editableItem(uniqueId) else {
            return nil
        }
        return self.editingContext.coverImage(for: item)
    }

    public func coverPosition(for uniqueId: String) -> Double? {
        guard let item = self.editableItem(uniqueId) else {
            return nil
        }
        return self.editingContext.coverPosition(for: item)?.doubleValue
    }

    public func setCoverImage(_ image: UIImage, position: Double?, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setCover(image, position: position.flatMap { NSNumber(value: $0) }, for: item)
    }
}

public final class ChatMediaEditorLegacyLivePhotoAdapter: ChatMediaEditorLivePhotoAdapter {
    private let editingContext: TGMediaEditingContext
    private let resolver: ChatMediaEditorLegacyItemResolver

    public init(editingContext: TGMediaEditingContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.editingContext = editingContext
        self.resolver = resolver
    }

    private func editableItem(_ uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.resolver.item(for: uniqueId) as? (NSObject & TGMediaEditableItem)
    }

    public var isForceLivePhotoEnabled: Bool {
        return self.editingContext.isForceLivePhotoEnabled()
    }

    public func livePhotoMode(for uniqueId: String) -> ChatMediaSendLivePhotoMode? {
        guard let item = self.editableItem(uniqueId), let mode = self.editingContext.livePhotoMode(for: item) else {
            return nil
        }
        return ChatMediaSendLivePhotoMode(legacy: TGMediaLivePhotoMode(rawValue: mode.uintValue) ?? .off)
    }

    public func setLivePhotoMode(_ mode: ChatMediaSendLivePhotoMode, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setLivePhotoMode(mode.legacyMode, for: item)
    }
}

public final class ChatMediaEditorLegacyCaptionAdapter: ChatMediaEditorCaptionAdapter {
    private let editingContext: TGMediaEditingContext
    private let resolver: ChatMediaEditorLegacyItemResolver
    private let thumbnailWriter: ChatMediaEditorLegacyThumbnailWriter

    public init(editingContext: TGMediaEditingContext, resolver: ChatMediaEditorLegacyItemResolver) {
        self.editingContext = editingContext
        self.resolver = resolver
        self.thumbnailWriter = ChatMediaEditorLegacyThumbnailWriter(target: ChatMediaEditorLegacyEditingThumbnailTarget(editingContext: editingContext, resolver: resolver))
    }

    private func editableItem(_ uniqueId: String) -> (NSObject & TGMediaEditableItem)? {
        return self.resolver.item(for: uniqueId) as? (NSObject & TGMediaEditableItem)
    }

    public var isForced: Bool {
        var isForced = false
        if let signal = self.editingContext.forcedCaption() {
            let disposable = signal.start(next: { value in
                isForced = value is NSAttributedString
            }, error: { _ in
            }, completed: {
            })
            disposable?.dispose()
        }
        return isForced
    }

    public func caption(for uniqueId: String) -> NSAttributedString? {
        guard let item = self.editableItem(uniqueId) else {
            return nil
        }
        return self.editingContext.caption(for: item)
    }

    public func setCaption(_ caption: NSAttributedString?, for uniqueId: String) {
        guard let item = self.editableItem(uniqueId) else {
            return
        }
        self.editingContext.setCaption(caption, for: item)
    }

    public var captionAbove: Bool {
        get {
            return self.editingContext.isCaptionAbove()
        }
        set {
            self.editingContext.setCaptionAbove(newValue)
        }
    }

    public var isHighQualityPhoto: Bool {
        get {
            return self.editingContext.isHighQualityPhoto()
        }
        set {
            self.editingContext.setHighQualityPhoto(newValue)
        }
    }

    public func hasExternalEdits(for uniqueId: String) -> Bool {
        return self.thumbnailWriter.hasExternalEdits(for: uniqueId)
    }

    public func setEditedThumbnail(_ image: UIImage?, for uniqueId: String) {
        self.thumbnailWriter.write(image, for: uniqueId)
    }
}

private func chatMediaEditorLegacyOriginalThumbnail(_ item: NSObject & TGMediaEditableItem) -> Signal<UIImage, NoError> {
    let size = CGSize(width: 384.0, height: 384.0)
    let signal: Signal<UIImage?, NoError>
    if let image = item as? UIImage {
        signal = .single(image)
    } else if let asset = item as? TGMediaAsset, let backingAsset = asset.backingAsset {
        signal = assetImage(asset: backingAsset, targetSize: size, exact: false)
    } else if let video = item as? TGCameraCapturedVideo, let backingAsset = video.originalAsset?.backingAsset {
        signal = assetImage(asset: backingAsset, targetSize: size, exact: false)
    } else {
        signal = Signal { subscriber in
            let disposable = item.thumbnailImageSignal?().start(next: { next in
                if let next = next as? UIImage {
                    subscriber.putNext(next)
                }
            }, error: { _ in
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    }
    return signal
    |> mapToSignal { image -> Signal<UIImage, NoError> in
        if let image {
            return .single(image)
        }
        return .complete()
    }
}

public func chatMediaEditorGalleryItem(legacyItem: NSObject) -> ChatMediaEditorItem? {
    guard let uniqueId = (legacyItem as? TGMediaSelectableItem)?.uniqueIdentifier else {
        return nil
    }
    if let image = legacyItem as? UIImage {
        return ChatMediaEditorItem(uniqueId: uniqueId, source: .image(image))
    }
    if let asset = legacyItem as? TGMediaAsset, let backingAsset = asset.backingAsset {
        return ChatMediaEditorItem(uniqueId: uniqueId, source: .asset(backingAsset), isAnimation: asset.type == TGMediaAssetGifType)
    }
    if let video = legacyItem as? TGCameraCapturedVideo {
        if let originalAsset = video.originalAsset, let backingAsset = originalAsset.backingAsset {
            return ChatMediaEditorItem(uniqueId: uniqueId, source: .asset(backingAsset), isAnimation: originalAsset.type == TGMediaAssetGifType)
        }
        if let avAsset = video.immediateAVAsset {
            let size = video.dimensions
            guard size.width > 0.0, size.height > 0.0, video.videoDuration > 0.0 else {
                return nil
            }
            return ChatMediaEditorItem(uniqueId: uniqueId, source: .video(path: avAsset.url.path, dimensions: PixelDimensions(width: Int32(size.width), height: Int32(size.height)), duration: video.videoDuration))
        }
    }
    return nil
}

public func chatMediaEditorGalleryDoneButton(isScheduledMessages: Bool, isActionButtonDone: Bool) -> TGPhotoEditorDoneButton {
    if isScheduledMessages {
        return TGPhotoEditorDoneButtonSchedule
    }
    return isActionButtonDone ? TGPhotoEditorDoneButtonCheck : TGPhotoEditorDoneButtonSend
}

public func makeChatMediaEditorGalleryController(context: AccountContext, parameters: ChatMediaGalleryParameters) -> ViewController? {
    guard let store = parameters.itemStore as? ChatMediaEditorItemStore, let editingContext = parameters.editingContext as? TGMediaEditingContext else {
        return nil
    }
    let selectionContext = parameters.selectionContext as? TGMediaSelectionContext

    let itemsSource: ChatMediaEditorItemsSource
    let initialIndex: Int
    var initialItems: [NSObject] = []
    let keepsDeselectedItems: Bool
    switch parameters.source {
    case let .fetchResult(fetchResult, index, reversed):
        guard fetchResult.count > 0 else {
            return nil
        }
        itemsSource = ChatMediaEditorFetchResultSource(fetchResult: fetchResult, reversed: reversed)
        initialIndex = index
        keepsDeselectedItems = false
    case let .selection(focusUniqueId):
        guard let selectionContext else {
            return nil
        }
        var items: [ChatMediaEditorItem] = []
        for case let legacyItem as NSObject in selectionContext.selectedItems() ?? [] {
            guard let item = chatMediaEditorGalleryItem(legacyItem: legacyItem) else {
                return nil
            }
            initialItems.append(legacyItem)
            items.append(item)
        }
        guard !items.isEmpty else {
            return nil
        }
        itemsSource = ChatMediaEditorListSource(items: items)
        initialIndex = items.firstIndex(where: { $0.uniqueId == focusUniqueId }) ?? 0
        keepsDeselectedItems = true
    }

    let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: initialItems, lookup: { uniqueId in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [uniqueId], options: nil).firstObject else {
            return nil
        }
        return TGMediaAsset(phAsset: asset)
    })

    var selection: ChatMediaEditorSelectionAdapter?
    if let selectionContext, chatMediaGalleryUsesSelection(selectionLimit: Int(selectionContext.selectionLimit)) {
        selection = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)
    }
    let captions = ChatMediaEditorLegacyCaptionAdapter(editingContext: editingContext, resolver: resolver)
    let timers = ChatMediaEditorLegacyTimerAdapter(editingContext: editingContext, resolver: resolver)
    let covers = ChatMediaEditorLegacyCoverAdapter(editingContext: editingContext, resolver: resolver)
    let livePhotos = ChatMediaEditorLegacyLivePhotoAdapter(editingContext: editingContext, resolver: resolver)

    let sendSelected = parameters.sendSelected
    let gallery = ChatMediaEditorGalleryConfiguration(
        doneButton: chatMediaEditorGalleryDoneButton(isScheduledMessages: parameters.isScheduledMessages, isActionButtonDone: parameters.isActionButtonDone),
        hasSendMenu: parameters.hasSendMenu,
        hasTimer: parameters.hasTimer && !parameters.isFilePreview,
        timers: timers,
        presentTimerPicker: parameters.presentTimerPicker,
        hasCoverButton: parameters.hasCoverButton && !parameters.isFilePreview,
        covers: covers,
        editCover: parameters.editCover,
        hasLivePhotoButton: parameters.hasLivePhotoButton && !parameters.isFilePreview,
        livePhotos: livePhotos,
        sendWhenOnlineAvailable: parameters.sendWhenOnlineAvailable,
        sendInProgress: parameters.sendInProgress,
        keepsDeselectedItems: keepsDeselectedItems,
        immediateThumbnail: parameters.immediateThumbnail,
        transitionHostView: parameters.transitionHostView,
        transitionView: parameters.transitionView,
        updateHiddenMedia: parameters.updateHiddenMedia,
        finishedTransitionIn: parameters.finishedTransitionIn,
        willTransitionOut: parameters.willTransitionOut,
        send: { uniqueId, silently, scheduleTime, completion in
            guard let item = resolver.item(for: uniqueId) else {
                return false
            }
            return sendSelected(item, silently, scheduleTime, completion)
        },
        dismissAll: parameters.dismissAll,
        tabPolicy: parameters.isFilePreview ? .filePreview : (parameters.isCropOnly ? .cropOnly : .standard)
    )

    let getCaptionPanelView = parameters.getCaptionPanelView
    return ChatMediaEditorScreen(
        context: context,
        itemsSource: itemsSource,
        initialIndex: initialIndex,
        store: store,
        selection: selection,
        captions: captions,
        recipientName: parameters.recipientName,
        getCaptionPanelView: {
            return getCaptionPanelView() as? TGCaptionPanelView
        },
        hasSilentPosting: parameters.hasSilentPosting,
        hasSchedule: parameters.hasSchedule,
        reminder: parameters.reminder,
        presentSchedulePicker: parameters.presentSchedulePicker,
        gallery: gallery,
        completion: { _, _, _, _ in
        }
    )
}
