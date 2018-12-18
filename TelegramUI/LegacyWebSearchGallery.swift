import Foundation
import LegacyComponents
import SwiftSignalKit
import TelegramCore
import Postbox
import SSignalKit
import UIKit
import Display

class LegacyWebSearchItem: NSObject, TGMediaEditableItem, TGMediaSelectableItem {
    var isVideo: Bool {
        return false
    }
    
    var uniqueIdentifier: String! {
        return self.result.id
    }
    
    let result: ChatContextResult
    let dimensions: CGSize
    let thumbnailImage: Signal<UIImage, NoError>
    let originalImage: Signal<UIImage, NoError>
    let progress: Signal<Float, NoError>
    
    init(result: ChatContextResult) {
        self.result = result
        self.dimensions = CGSize()
        self.thumbnailImage = .complete()
        self.originalImage = .complete()
        self.progress = .complete()
    }
    
    init(result: ChatContextResult, dimensions: CGSize, thumbnailImage: Signal<UIImage, NoError>, originalImage: Signal<UIImage, NoError>, progress: Signal<Float, NoError>) {
        self.result = result
        self.dimensions = dimensions
        self.thumbnailImage = thumbnailImage
        self.originalImage = originalImage
        self.progress = progress
    }
    
    var originalSize: CGSize {
        return self.dimensions
    }
    
    func thumbnailImageSignal() -> SSignal! {
        return SSignal(generator: { subscriber -> SDisposable? in
            let disposable = self.thumbnailImage.start(next: { image in
                subscriber?.putNext(image)
                subscriber?.putCompletion()
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        })
    }
    
    func screenImageAndProgressSignal() -> SSignal {
        return SSignal { subscriber in
            let imageDisposable = self.originalImage.start(next: { image in
                if !image.degraded() {
                    subscriber?.putNext(1.0)
                }
                subscriber?.putNext(image)
                if !image.degraded() {
                    subscriber?.putCompletion()
                }
            })
            
            let progressDisposable = (self.progress
            |> deliverOnMainQueue).start(next: { next in
                subscriber?.putNext(next)
            })
            
            return SBlockDisposable {
                imageDisposable.dispose()
                progressDisposable.dispose()
            }
        }
    }
    
    func screenImageSignal(_ position: TimeInterval) -> SSignal! {
        return self.originalImageSignal(position)
    }
    
    func originalImageSignal(_ position: TimeInterval) -> SSignal! {
        return SSignal(generator: { subscriber -> SDisposable? in
            let disposable = self.originalImage.start(next: { image in
                subscriber?.putNext(image)
                if !image.degraded() {
                    subscriber?.putCompletion()
                }
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        })
    }
}

private class LegacyWebSearchGalleryItem: TGModernGalleryImageItem, TGModernGalleryEditableItem, TGModernGallerySelectableItem {
    var selectionContext: TGMediaSelectionContext!
    
    var editingContext: TGMediaEditingContext!
    let item: LegacyWebSearchItem
    
    init(item: LegacyWebSearchItem) {
        self.item = item
        super.init()
    }
    
    func editableMediaItem() -> TGMediaEditableItem! {
        return self.item
    }
    
    func selectableMediaItem() -> TGMediaSelectableItem! {
        return self.item
    }
    
    func toolbarTabs() -> TGPhotoEditorTab {
        return [.cropTab, .paintTab, .toolsTab]
    }
    
    func uniqueId() -> String! {
        return self.item.uniqueIdentifier
    }
    
    override func viewClass() -> AnyClass! {
        return LegacyWebSearchGalleryItemView.self
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let item = object as? LegacyWebSearchGalleryItem {
            return item.item.result.id == self.item.result.id
        }
        return false
    }
}

private class LegacyWebSearchGalleryItemView: TGModernGalleryImageItemView, TGModernGalleryEditableItemView {
    private let readyForTransition = SVariable()!
    
    func setHiddenAsBeingEdited(_ hidden: Bool) {
        self.imageView.isHidden = hidden
    }
    
    override func readyForTransitionIn() -> SSignal! {
        return self.readyForTransition.signal()!.take(1)
    }
    
    override func setItem(_ item: TGModernGalleryItem!, synchronously: Bool) {
        if let item = item as? LegacyWebSearchGalleryItem {
            self._setItem(item)
            self.imageSize = TGFitSize(item.editableMediaItem().originalSize!, CGSize(width: 1600, height: 1600))
            
            let signal = item.editingContext.imageSignal(for: item.editableMediaItem())?.map(toSignal: { result -> SSignal? in
                if let image = result as? UIImage {
                    return SSignal.single(image)
                } else if result == nil, let mediaItem = item.editableMediaItem() as? LegacyWebSearchItem {
                    return mediaItem.screenImageAndProgressSignal()
                } else {
                    return SSignal.complete()
                }
            })
            
            self.imageView.setSignal(signal?.deliver(on: SQueue.main())?.afterNext({ [weak self] next in
                if let strongSelf = self, let image = next as? UIImage {
                    strongSelf.imageSize = image.size
                    strongSelf.reset()
                    strongSelf.readyForTransition.set(SSignal.single(true))
                }
            }))
            
            self.reset()
        } else {
            self.imageView.setSignal(nil)
            super.setItem(item, synchronously: synchronously)
        }
    }
    
    override func contentView() -> UIView! {
        return self.imageView
    }
    
    override func transitionContentView() -> UIView! {
        return self.contentView()
    }
    
    override func transitionViewContentRect() -> CGRect {
        let contentView = self.transitionContentView()!
        return contentView.convert(contentView.bounds, to: self.transitionView())
    }
}

func legacyWebSearchItem(account: Account, result: ChatContextResult) -> LegacyWebSearchItem? {
    var thumbnailDimensions: CGSize?
    var thumbnailResource: TelegramMediaResource?
    var imageResource: TelegramMediaResource?
    var imageDimensions = CGSize()
    
    let thumbnailSignal: Signal<UIImage, NoError>
    let originalSignal: Signal<UIImage, NoError>
    
    switch result {
        case let .externalReference(_, _, _, _, _, _, content, thumbnail, _):
            if let content = content {
                imageResource = content.resource
            }
            if let thumbnail = thumbnail {
                thumbnailResource = thumbnail.resource
                thumbnailDimensions = thumbnail.dimensions
            }
            if let dimensions = content?.dimensions {
                imageDimensions = dimensions
            }
        case let .internalReference(_, _, _, _, _, image, _, _):
            if let image = image {
                if let largestRepresentation = largestImageRepresentation(image.representations) {
                    imageDimensions = largestRepresentation.dimensions
                    imageResource = imageRepresentationLargerThan(image.representations, size: CGSize(width: 1000.0, height: 800.0))?.resource
                }
                if let thumbnailRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 200.0, height: 100.0)) {
                    thumbnailDimensions = thumbnailRepresentation.dimensions
                    thumbnailResource = thumbnailRepresentation.resource
                }
            }
    }
    
    if let imageResource = imageResource {
        let progressSignal = account.postbox.mediaBox.resourceStatus(imageResource)
        |> map { status -> Float in
            switch status {
                case .Local:
                    return 1.0
                case .Remote:
                    return 0.0
                case let .Fetching(_, progress):
                    return progress
            }
        }
        
        var representations: [TelegramMediaImageRepresentation] = []
        if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
            representations.append(TelegramMediaImageRepresentation(dimensions: thumbnailDimensions, resource: thumbnailResource))
        }
        representations.append(TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: imageResource))
        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, reference: nil, partialReference: nil)
        thumbnailSignal = chatMessagePhotoDatas(postbox: account.postbox, photoReference: .standalone(media: tmpImage), autoFetchFullSize: false)
        |> mapToSignal { (thumbnailData, _, _) -> Signal<UIImage, NoError> in
            if let data = thumbnailData, let image = UIImage(data: data) {
                return .single(image)
            } else {
                return .complete()
            }
        }
        originalSignal = chatMessagePhotoDatas(postbox: account.postbox, photoReference: .standalone(media: tmpImage), autoFetchFullSize: true)
        |> mapToSignal { (thumbnailData, fullSizeData, fullSizeComplete) -> Signal<UIImage, NoError> in
            if fullSizeComplete, let data = fullSizeData, let image = UIImage(data: data) {
                return .single(image)
            } else if let data = thumbnailData, let image = UIImage(data: data) {
                image.setDegraded(true)
                return .single(image)
            } else {
                return .complete()
            }
        }
        
        return LegacyWebSearchItem(result: result, dimensions: imageDimensions, thumbnailImage: thumbnailSignal, originalImage: originalSignal, progress: progressSignal)
    } else {
        return nil
    }
}

private func galleryItems(account: Account, results: [ChatContextResult], current: ChatContextResult, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    for result in results {
        if let item = legacyWebSearchItem(account: account, result: result) {
            let galleryItem = LegacyWebSearchGalleryItem(item: item)
            galleryItem.selectionContext = selectionContext
            galleryItem.editingContext = editingContext
            if result.id == current.id {
                focusItem = galleryItem
            }
            galleryItems.append(galleryItem)
        }
    }
    return (galleryItems, focusItem)
}

func presentLegacyWebSearchGallery(account: Account, peer: Peer?, theme: PresentationTheme, results: [ChatContextResult], current: ChatContextResult, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext, updateHiddenMedia: @escaping (String?) -> Void, initialLayout: ContainerViewLayout?, transitionHostView: @escaping () -> UIView?, transitionView: @escaping (ChatContextResult) -> UIView?, completed: @escaping (ChatContextResult) -> Void, present: (ViewController, Any?) -> Void) {
    let legacyController = LegacyController(presentation: .custom, theme: theme, initialLayout: initialLayout)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let controller = TGModernGalleryController(context: legacyController.context)!
    controller.asyncTransitionIn = true
    legacyController.bind(controller: controller)
    
    let (items, focusItem) = galleryItems(account: account, results: results, current: current, selectionContext: selectionContext, editingContext: editingContext)
    
    let model = TGMediaPickerGalleryModel(context: legacyController.context, items: items, focus: focusItem, selectionContext: selectionContext, editingContext: editingContext, hasCaptions: true, allowCaptionEntities: true, hasTimer: false, onlyCrop: false, inhibitDocumentCaptions: false, hasSelectionPanel: false, hasCamera: false, recipientName: peer?.displayTitle)!
    if let peer = peer {
        model.suggestionContext = legacySuggestionContext(account: account, peerId: peer.id)
    }
    controller.model = model
    model.controller = controller
    model.useGalleryImageAsEditableItemImage = true
    model.storeOriginalImageForItem = { item, image in
        editingContext.setOriginalImage(image, for: item, synchronous: false)
    }
    model.willFinishEditingItem = { item, adjustments, representation, hasChanges in
        if hasChanges {
            editingContext.setAdjustments(adjustments, for: item)
        }
        editingContext.setTemporaryRep(representation, for: item)
        if let selectionContext = selectionContext, adjustments != nil, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    model.didFinishEditingItem = { item, adjustments, result, thumbnail in
        editingContext.setImage(result, thumbnailImage: thumbnail, for: item, synchronous: true)
    }
    model.saveItemCaption = { item, caption, entities in
        editingContext.setCaption(caption, entities: entities, for: item)
        if let selectionContext = selectionContext, let caption = caption, caption.count > 0, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    if let selectionContext = selectionContext {
        model.interfaceView.updateSelectionInterface(selectionContext.count(), counterVisible: selectionContext.count() > 0, animated: false)
    }
    model.interfaceView.donePressed = { item in
        if let item = item as? LegacyWebSearchGalleryItem {
            controller.dismissWhenReady(animated: false)
            completed(item.item.result)
        }
    }
    controller.transitionHost = {
        return transitionHostView()
    }
    controller.itemFocused = { item in
        if let item = item as? LegacyWebSearchGalleryItem {
            updateHiddenMedia(item.item.result.id)
        }
    }
    controller.beginTransitionIn = { item, _ in
        if let item = item as? LegacyWebSearchGalleryItem {
            return transitionView(item.item.result)
        } else {
            return nil
        }
    }
    controller.beginTransitionOut = { item, _ in
        if let item = item as? LegacyWebSearchGalleryItem {
            return transitionView(item.item.result)
        } else {
            return nil
        }
    }
    controller.completedTransitionOut = { [weak legacyController] in
        updateHiddenMedia(nil)
        legacyController?.dismiss()
    }
    present(legacyController, nil)
}
