import Foundation
import UIKit
import TelegramLegacyComponents
import Display
import SwiftSignalKit
import Postbox

func legacyAttachmentMenu(parentController: LegacyController, recentlyUsedInlineBots: [Peer], presentOverlayController: @escaping (UIViewController) -> (() -> Void), openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, openFileGallery: @escaping () -> Void, openMap: @escaping () -> Void, openContacts: @escaping () -> Void, sendMessagesWithSignals: @escaping ([Any]?) -> Void, selectRecentlyUsedInlineBot: @escaping (Peer) -> Void) -> TGMenuSheetController {
    let controller = TGMenuSheetController()
    controller.applicationInterface = parentController.applicationInterface
    controller.dismissesByOutsideTap = true
    controller.hasSwipeGesture = true
    controller.maxHeight = 445.0 - TGMenuSheetButtonItemViewHeight
    
    var itemViews: [Any] = []
    
    let carouselItem = TGAttachmentCarouselItemView(camera: PGCamera.cameraAvailable(), selfPortrait: false, forProfilePhoto: false, assetType: TGMediaAssetAnyType)!
    carouselItem.presentOverlayController = { controller in
        return presentOverlayController(controller!)
    }
    carouselItem.cameraPressed = { [weak controller] cameraView in
        if let controller = controller {
            openCamera(cameraView, controller)
        }
    }
    carouselItem.sendPressed = { [weak controller, weak carouselItem] currentItem, asFiles in
        if let controller = controller, let carouselItem = carouselItem {
            controller.dismiss(animated: true)
            let intent: TGMediaAssetsControllerIntent = asFiles ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent
            let signals = TGMediaAssetsController.resultSignals(for: carouselItem.selectionContext, editingContext: carouselItem.editingContext, intent: intent, currentItem: currentItem, storeAssets: true, useMediaCache: false, descriptionGenerator: legacyAssetPickerItemGenerator())
            sendMessagesWithSignals(signals)
        }
    };
    carouselItem.allowCaptions = false
    itemViews.append(carouselItem)
    
    let galleryItem = TGMenuSheetButtonItemView(title: "Photo or Video", type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
        controller?.dismiss(animated: true)
        openGallery()
    })!
    itemViews.append(galleryItem)
    
    let fileItem = TGMenuSheetButtonItemView(title: "File", type: TGMenuSheetButtonTypeDefault, action: {[weak controller] in
        controller?.dismiss(animated: true)
        openFileGallery()
    })!
    itemViews.append(fileItem)
    
    let locationItem = TGMenuSheetButtonItemView(title: "Location", type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
        controller?.dismiss(animated: true)
        openMap()
    })!
    itemViews.append(locationItem)
    
    let contactItem = TGMenuSheetButtonItemView(title: "Contact", type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
        controller?.dismiss(animated: true)
        openContacts()
    })!
    itemViews.append(contactItem)
    
    carouselItem.underlyingViews = [galleryItem, fileItem]
    
    for i in 0 ..< min(20, recentlyUsedInlineBots.count) {
        let peer = recentlyUsedInlineBots[i]
        let addressName = peer.addressName
        if let addressName = addressName {
            let botItem = TGMenuSheetButtonItemView(title: "@" + addressName, type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
                controller?.dismiss(animated: true)
                
                selectRecentlyUsedInlineBot(peer)
            })!
            botItem.overflow = true
            itemViews.append(botItem)
        }
    }
    
    carouselItem.remainingHeight = TGMenuSheetButtonItemViewHeight * CGFloat(itemViews.count - 1)
    
    let cancelItem = TGMenuSheetButtonItemView(title: "Cancel", type: TGMenuSheetButtonTypeCancel, action: { [weak controller] in
        controller?.dismiss(animated: true)
    })!
    itemViews.append(cancelItem)
    
    controller.setItemViews(itemViews)
    
    return controller
}

func legacyFileAttachmentMenu(menuSheetController: TGMenuSheetController) {
    
}
