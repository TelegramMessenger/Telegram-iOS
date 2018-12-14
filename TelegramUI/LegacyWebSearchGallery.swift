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
    
    init(result: ChatContextResult, dimensions: CGSize, thumbnailImage: Signal<UIImage, NoError>, originalImage: Signal<UIImage, NoError>) {
        self.result = result
        self.dimensions = dimensions
        self.thumbnailImage = thumbnailImage
        self.originalImage = originalImage
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
    
    func screenImageSignal(_ position: TimeInterval) -> SSignal! {
        return self.originalImageSignal(position)
    }
    
    func originalImageSignal(_ position: TimeInterval) -> SSignal! {
        return SSignal(generator: { subscriber -> SDisposable? in
            let disposable = self.originalImage.start(next: { image in
                subscriber?.putNext(image)
                subscriber?.putCompletion()
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
}

private class LegacyWebSearchGalleryItemView: TGModernGalleryImageItemView, TGModernGalleryEditableItemView
{
    func setHiddenAsBeingEdited(_ hidden: Bool) {
        self.imageView.isHidden = hidden
    }
    
    override func setItem(_ item: TGModernGalleryItem!, synchronously: Bool) {
        if let item = item as? LegacyWebSearchGalleryItem {
            self._setItem(item)
            self.imageSize = TGFitSize(item.editableMediaItem().originalSize!, CGSize(width: 1600, height: 1600))
            
            let signal = item.editingContext.imageSignal(for: item.editableMediaItem())?.map(toSignal: { result -> SSignal? in
                if let image = result as? UIImage {
                    return SSignal.single(image)
                } else if result == nil, let mediaItem = item.editableMediaItem() as? LegacyWebSearchItem {
                    return mediaItem.originalImageSignal(0.0)
                } else {
                    return SSignal.complete()
                }
            })
            
            self.imageView.setSignal(signal?.deliver(on: SQueue.main())?.afterNext({ [weak self] next in
                if let strongSelf = self, let image = next as? UIImage {
                    strongSelf.imageSize = image.size
                    strongSelf.reset()
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

private func galleryItems(account: Account, results: [ChatContextResult], current: ChatContextResult, selectionContext: TGMediaSelectionContext, editingContext: TGMediaEditingContext) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    for result in results {
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
//                if let imageResource = imageResource {
//                    updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)
//                }
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
            var representations: [TelegramMediaImageRepresentation] = []
            if let thumbnailResource = thumbnailResource, let thumbnailDimensions = thumbnailDimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: thumbnailDimensions, resource: thumbnailResource))
            }
            representations.append(TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: imageResource))
            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, reference: nil, partialReference: nil)
            thumbnailSignal = chatMessagePhotoDatas(postbox: account.postbox, photoReference: .standalone(media: tmpImage), autoFetchFullSize: true)
            |> mapToSignal { (thumbnailData, fullSizeData, fullSizeComplete) -> Signal<UIImage, NoError> in
                if let data = fullSizeData, let image = UIImage(data: data) {
                    return .single(image)
                } else {
                    return .complete()
                }
            }
            originalSignal = thumbnailSignal
       
            let item = LegacyWebSearchItem(result: result, dimensions: imageDimensions, thumbnailImage: thumbnailSignal, originalImage: originalSignal)
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

func presentLegacyWebSearchGallery(account: Account, peer: Peer?, theme: PresentationTheme, results: [ChatContextResult], current: ChatContextResult, selectionContext: TGMediaSelectionContext, editingContext: TGMediaEditingContext, updateHiddenMedia: @escaping (String?) -> Void, initialLayout: ContainerViewLayout?, transitionHostView: @escaping () -> UIView?, transitionView: @escaping (ChatContextResult) -> UIView?, completed: @escaping (ChatContextResult) -> Void, present: (ViewController, Any?) -> Void) {
    let legacyController = LegacyController(presentation: .custom, theme: theme, initialLayout: initialLayout)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let controller = TGModernGalleryController(context: legacyController.context)!
    legacyController.bind(controller: controller)
    
    let (items, focusItem) = galleryItems(account: account, results: results, current: current, selectionContext: selectionContext, editingContext: editingContext)
    
    let model = TGMediaPickerGalleryModel(context: legacyController.context, items: items, focus: focusItem, selectionContext: selectionContext, editingContext: editingContext, hasCaptions: true, allowCaptionEntities: true, hasTimer: false, onlyCrop: false, inhibitDocumentCaptions: false, hasSelectionPanel: false, hasCamera: false, recipientName: peer?.displayTitle)!
    if let peer = peer {
        model.suggestionContext = legacySuggestionContext(account: account, peerId: peer.id)
    }
    controller.model = model
    model.controller = controller
    model.externalSelectionCount = {
        return 0
    }
    model.useGalleryImageAsEditableItemImage = true
    model.storeOriginalImageForItem = { item, image in
        editingContext.setOriginalImage(image, for: item, synchronous: false)
    }
    model.willFinishEditingItem = { item, adjustments, representation, hasChanges in
        if hasChanges {
            editingContext.setAdjustments(adjustments, for: item)
        }
        editingContext.setTemporaryRep(representation, for: item)
        //if let selectionContext = selectionContext,  {
        //    selectionContex
        //}
    }
    model.didFinishEditingItem = { item, adjustments, result, thumbnail in
        editingContext.setImage(result, thumbnailImage: thumbnail, for: item, synchronous: true)
    }
    model.saveItemCaption = { item, caption, entities in
        editingContext.setCaption(caption, entities: entities, for: item)
    }
    //[model.interfaceView updateSelectionInterface:[self totalSelectionCount] counterVisible:([self totalSelectionCount] > 0) animated:false];
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
    



//        if (item.selectionContext != nil && adjustments != nil && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
//        [item.selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
//    };


//    model.interfaceView.donePressed = ^(id<TGWebSearchResultsGalleryItem> item)
//    {
//        __strong TGWebSearchController *strongSelf = weakSelf;
//        if (strongSelf == nil)
//        return;
//
//        NSMutableArray *selectedItems = [strongSelf selectedItems];
//
//        if (selectedItems.count == 0)
//        [selectedItems addObject:[item webSearchResult]];
//
//        strongSelf->_selectedItems = selectedItems;
//        [strongSelf complete];
//    };
//    _galleryModel = model;
//    modernGallery.model = model;
//
//    __weak TGModernGalleryController *weakGallery = modernGallery;
//    modernGallery.itemFocused = ^(id<TGWebSearchResultsGalleryItem> item)
//    {
//        __strong TGWebSearchController *strongSelf = weakSelf;
//        __strong TGModernGalleryController *strongGallery = weakGallery;
//        if (strongSelf != nil)
//        {
//            if (strongGallery.previewMode)
//            return;
//
//            id<TGWebSearchListItem> listItem = [strongSelf listItemForSearchResult:[item webSearchResult]];
//            strongSelf->_hiddenItem = listItem;
//            [strongSelf updateHiddenItemAnimated:false];
//        }
//    };
//
}
