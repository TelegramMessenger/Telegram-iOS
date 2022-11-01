import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import SSignalKit
import TelegramPresentationData
import AccountContext
import LegacyComponents
import LegacyUI
import LegacyMediaPickerUI
import Photos

private func galleryFetchResultItems(fetchResult: PHFetchResult<PHAsset>, index: Int, reversed: Bool, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext, stickersContext: TGPhotoPaintStickersContext, immediateThumbnail: UIImage?) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    
    let legacyFetchResult = TGMediaAssetFetchResult(phFetchResult: fetchResult as? PHFetchResult<AnyObject>, reversed: reversed)
    
    for i in 0 ..< fetchResult.count {
        if let galleryItem = TGMediaPickerGalleryFetchResultItem(fetchResult: legacyFetchResult, index: UInt(i)) {
            galleryItem.selectionContext = selectionContext
            galleryItem.editingContext = editingContext
            galleryItem.stickersContext = stickersContext
            galleryItems.append(galleryItem)
            
            if i == index {
                galleryItem.immediateThumbnailImage = immediateThumbnail
                focusItem = galleryItem
            }
        }
    }
    return (galleryItems, focusItem)
}

private func gallerySelectionItems(item: TGMediaSelectableItem, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext, stickersContext: TGPhotoPaintStickersContext, immediateThumbnail: UIImage?) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    
    if let selectionContext = selectionContext {
        for case let selectedItem as TGMediaSelectableItem in selectionContext.selectedItems() {
            if let asset = selectedItem as? TGMediaAsset {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem)
                switch asset.type {
                    case TGMediaAssetVideoType:
                        galleryItem = TGMediaPickerGalleryVideoItem(asset: asset)
                    case TGMediaAssetGifType:
                        let convertedAsset = TGCameraCapturedVideo(asset: asset, livePhoto: false)
                        galleryItem = TGMediaPickerGalleryVideoItem(asset: convertedAsset)
                    default:
                        galleryItem = TGMediaPickerGalleryPhotoItem(asset: asset)
                }
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            } else if let asset = selectedItem as? UIImage {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem) = TGMediaPickerGalleryPhotoItem(asset: asset)
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            } else if let asset = selectedItem as? TGCameraCapturedVideo {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem) = TGMediaPickerGalleryVideoItem(asset: asset)
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            }
        }
    }
    
    return (galleryItems, focusItem)
}

enum LegacyMediaPickerGallerySource {
    case fetchResult(fetchResult: PHFetchResult<PHAsset>, index: Int, reversed: Bool)
    case selection(item: TGMediaSelectableItem)
}

func presentLegacyMediaPickerGallery(context: AccountContext, peer: EnginePeer?, chatLocation: ChatLocation?, presentationData: PresentationData, source: LegacyMediaPickerGallerySource, immediateThumbnail: UIImage?, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext, hasSilentPosting: Bool, hasSchedule: Bool, hasTimer: Bool, updateHiddenMedia: @escaping (String?) -> Void, initialLayout: ContainerViewLayout?, transitionHostView: @escaping () -> UIView?, transitionView: @escaping (String) -> UIView?, completed: @escaping (TGMediaSelectableItem & TGMediaEditableItem, Bool, Int32?, @escaping () -> Void) -> Void, presentStickers: ((@escaping (TelegramMediaFile, Bool, UIView, CGRect) -> Void) -> TGPhotoPaintStickersScreen?)?, presentSchedulePicker: @escaping (Bool, @escaping (Int32) -> Void) -> Void, presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void, getCaptionPanelView: @escaping () -> TGCaptionPanelView?, present: @escaping (ViewController, Any?) -> Void, finishedTransitionIn: @escaping () -> Void, willTransitionOut: @escaping () -> Void, dismissAll: @escaping () -> Void) -> TGModernGalleryController {
    let reminder = peer?.id == context.account.peerId
    let hasSilentPosting = hasSilentPosting && peer?.id != context.account.peerId
    
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
    legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    
    let paintStickersContext = LegacyPaintStickersContext(context: context)
    paintStickersContext.captionPanelView = {
        return getCaptionPanelView()
    }
    paintStickersContext.presentStickersController = { completion in
        if let presentStickers = presentStickers {
            return presentStickers({ file, animated, view, rect in
                let coder = PostboxEncoder()
                coder.encodeRootObject(file)
                completion?(coder.makeData(), animated, view, rect)
            })
        } else {
            return nil
        }
    }
    
    let controller = TGModernGalleryController(context: legacyController.context)!
    controller.asyncTransitionIn = true
    legacyController.bind(controller: controller)
    
    let (items, focusItem): ([TGModernGalleryItem], TGModernGalleryItem?)
    switch source {
        case let .fetchResult(fetchResult, index, reversed):
            (items, focusItem) = galleryFetchResultItems(fetchResult: fetchResult, index: index, reversed: reversed, selectionContext: selectionContext, editingContext: editingContext, stickersContext: paintStickersContext, immediateThumbnail: immediateThumbnail)
        case let .selection(item):
            (items, focusItem) = gallerySelectionItems(item: item, selectionContext: selectionContext, editingContext: editingContext, stickersContext: paintStickersContext, immediateThumbnail: immediateThumbnail)
    }
    
    let recipientName: String?
    if peer?.id == context.account.peerId {
        recipientName = presentationData.strings.DialogList_SavedMessages
    } else {
        recipientName = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    }
    
    let model = TGMediaPickerGalleryModel(context: legacyController.context, items: items, focus: focusItem, selectionContext: selectionContext, editingContext: editingContext, hasCaptions: true, allowCaptionEntities: true, hasTimer: hasTimer, onlyCrop: false, inhibitDocumentCaptions: false, hasSelectionPanel: true, hasCamera: false, recipientName: recipientName)!
    model.stickersContext = paintStickersContext
    controller.model = model
    model.controller = controller
    model.willFinishEditingItem = { item, adjustments, representation, hasChanges in
        if hasChanges {
            editingContext.setAdjustments(adjustments, for: item)
            editingContext.setTemporaryRep(representation, for: item)
        }
        
        if let selectionContext = selectionContext, adjustments != nil, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    model.didFinishEditingItem = { item, adjustments, result, thumbnail in
        editingContext.setImage(result, thumbnailImage: thumbnail, for: item, synchronous: false)
    }
    model.saveItemCaption = { item, caption in
        editingContext.setCaption(caption, for: item)
        if let selectionContext = selectionContext, let caption = caption, caption.length > 0, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    model.didFinishRenderingFullSizeImage = { item, result in
        editingContext.setFullSizeImage(result, for: item)
    }
    model.requestAdjustments = { item in
        return editingContext.adjustments(for: item)
    }
    if let selectionContext = selectionContext {
        model.interfaceView.updateSelectionInterface(selectionContext.count(), counterVisible: selectionContext.count() > 0, animated: false)
    }
    controller.transitionHost = {
        return transitionHostView()
    }
    var transitionedIn = false
    controller.itemFocused = { item in
        if let item = item as? TGMediaPickerGalleryItem, transitionedIn {
            updateHiddenMedia(item.asset.uniqueIdentifier)
        }
    }
    controller.beginTransitionIn = { item, itemView in
        if let item = item as? TGMediaPickerGalleryItem {
            if let itemView = itemView as? TGMediaPickerGalleryVideoItemView {
                itemView.setIsCurrent(true)
            }
            
            return transitionView(item.asset.uniqueIdentifier)
        } else {
            return nil
        }
    }
    
    controller.startedTransitionIn = {
        transitionedIn = true
        if let focusItem = focusItem as? TGModernGallerySelectableItem {
            updateHiddenMedia(focusItem.selectableMediaItem().uniqueIdentifier)
        }
    }
    controller.beginTransitionOut = { item, itemView in
        willTransitionOut()
        
        if let item = item as? TGMediaPickerGalleryItem {
            if let itemView = itemView as? TGMediaPickerGalleryVideoItemView {
                itemView.stop()
            }
            return transitionView(item.asset.uniqueIdentifier)
        } else {
            return nil
        }
    }
    controller.finishedTransitionIn = { [weak model] _, _ in
        model?.interfaceView.setSelectedItemsModel(model?.selectedItemsModel)
        
        finishedTransitionIn()
    }
    controller.completedTransitionOut = { [weak legacyController] in
        updateHiddenMedia(nil)
        legacyController?.dismiss()
    }

    model.interfaceView.donePressed = { [weak controller] item in
        if let item = item as? TGMediaPickerGalleryItem {
            completed(item.asset, false, nil, {
                controller?.dismissWhenReady(animated: true)
                dismissAll()
            })
        }
    }
    model.interfaceView.doneLongPressed = { [weak selectionContext, weak editingContext, weak legacyController, weak model] item in
        if let legacyController = legacyController, let item = item as? TGMediaPickerGalleryItem, let model = model, let selectionContext = selectionContext {
            var effectiveHasSchedule = hasSchedule
    
            if let editingContext = editingContext {
                for item in selectionContext.selectedItems() {
                    if let editableItem = item as? TGMediaEditableItem, let timer = editingContext.timer(for: editableItem)?.intValue, timer > 0 {
                        effectiveHasSchedule = false
                        break
                    }
                }
            }
                        
            let legacySheetController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
            let controller = TGMediaPickerSendActionSheetController(context: legacyController.context, isDark: true, sendButtonFrame: model.interfaceView.doneButtonFrame, canSendSilently: hasSilentPosting, canSchedule: effectiveHasSchedule, reminder: reminder, hasTimer: hasTimer)
            let dismissImpl = { [weak model] in
                model?.dismiss(true, false)
            }
            controller.send = {
                completed(item.asset, false, nil, {
                    dismissImpl()
                })
            }
            controller.sendSilently = {
                completed(item.asset, true, nil, {
                    dismissImpl()
                })
            }
            controller.schedule = {
                presentSchedulePicker(true, { time in
                    completed(item.asset, false, time, {
                        dismissImpl()
                    })
                })
            }
            controller.sendWithTimer = {
                presentTimerPicker { time in
                    var items = selectionContext.selectedItems() ?? []
                    items.append(item.asset as Any)
                    
                    for case let item as TGMediaEditableItem in items {
                        editingContext?.setTimer(time as NSNumber, for: item)
                    }
                    
                    completed(item.asset, false, nil, {
                        dismissImpl()
                    })
                }
            }
            controller.customDismissBlock = { [weak legacySheetController] in
                legacySheetController?.dismiss()
            }
            legacySheetController.bind(controller: controller)
            present(legacySheetController, nil)
            
            let hapticFeedback = HapticFeedback()
            hapticFeedback.impact()
        }
    }
    model.interfaceView.setThumbnailSignalForItem { item in
        let imageSignal = SSignal(generator: { subscriber in
            var asset: PHAsset?
            if let item = item as? TGCameraCapturedVideo, item.originalAsset != nil {
                asset = item.originalAsset.backingAsset
            } else if let item = item as? TGMediaAsset {
                asset = item.backingAsset
            }
            var disposable: Disposable?
            if let asset = asset {
                let scale = min(2.0, UIScreenScale)
                disposable = assetImage(asset: asset, targetSize: CGSize(width: 128.0 * scale, height: 128.0 * scale), exact: false).start(next: { image in
                    subscriber.putNext(image)
                }, completed: {
                    subscriber.putCompletion()
                })
            } else {
                subscriber.putCompletion()
            }
            return SBlockDisposable(block: {
                disposable?.dispose()
            })
        })
        if let item = item as? TGMediaEditableItem {
            return editingContext.thumbnailImageSignal(for: item).map(toSignal: { result in
                if let result = result {
                    return SSignal.single(result)
                } else {
                    return imageSignal
                }
            })
        } else {
            return imageSignal
        }
    }
    present(legacyController, nil)
    
    return controller
}
