import Foundation
import UIKit
import LegacyComponents
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

func legacyAttachmentMenu(account: Account, peer: Peer, saveEditedPhotos: Bool, allowGrouping: Bool, theme: PresentationTheme, strings: PresentationStrings, parentController: LegacyController, recentlyUsedInlineBots: [Peer], openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, openFileGallery: @escaping () -> Void, openMap: @escaping () -> Void, openContacts: @escaping () -> Void, sendMessagesWithSignals: @escaping ([Any]?) -> Void, selectRecentlyUsedInlineBot: @escaping (Peer) -> Void) -> TGMenuSheetController {
    let controller = TGMenuSheetController(context: parentController.context, dark: false)!
    controller.dismissesByOutsideTap = true
    controller.hasSwipeGesture = true
    controller.maxHeight = 445.0// - TGMenuSheetButtonItemViewHeight
    
    var itemViews: [Any] = []
    let carouselItem = TGAttachmentCarouselItemView(context: parentController.context, camera: PGCamera.cameraAvailable(), selfPortrait: false, forProfilePhoto: false, assetType: TGMediaAssetAnyType, saveEditedPhotos: saveEditedPhotos, allowGrouping: allowGrouping)!
    //carouselItem.defaultStatusBarStyle = theme.rootController.statusBar.style.style.systemStyle
    carouselItem.suggestionContext = legacySuggestionContext(account: account, peerId: peer.id)
    carouselItem.recipientName = peer.displayTitle
    carouselItem.cameraPressed = { [weak controller] cameraView in
        if let controller = controller {
            openCamera(cameraView, controller)
        }
    }
    if peer is TelegramUser || peer is TelegramSecretChat {
        carouselItem.hasTimer = true
    }
    carouselItem.sendPressed = { [weak controller, weak carouselItem] currentItem, asFiles in
        if let controller = controller, let carouselItem = carouselItem {
            controller.dismiss(animated: true)
            let intent: TGMediaAssetsControllerIntent = asFiles ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent
            let signals = TGMediaAssetsController.resultSignals(for: carouselItem.selectionContext, editingContext: carouselItem.editingContext, intent: intent, currentItem: currentItem, storeAssets: true, useMediaCache: false, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: saveEditedPhotos)
            sendMessagesWithSignals(signals)
        }
    };
    carouselItem.allowCaptions = true
    itemViews.append(carouselItem)
    
    let galleryItem = TGMenuSheetButtonItemView(title: strings.AttachmentMenu_PhotoOrVideo, type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
        controller?.dismiss(animated: true)
        openGallery()
    })!
    itemViews.append(galleryItem)
    
    let fileItem = TGMenuSheetButtonItemView(title: strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, action: {[weak controller] in
        controller?.dismiss(animated: true)
        openFileGallery()
    })!
    itemViews.append(fileItem)
    
    let locationItem = TGMenuSheetButtonItemView(title: strings.Conversation_Location, type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
        controller?.dismiss(animated: true)
        openMap()
    })!
    itemViews.append(locationItem)
    
    let contactItem = TGMenuSheetButtonItemView(title: strings.Conversation_Contact, type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
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
    
    let cancelItem = TGMenuSheetButtonItemView(title: strings.Common_Cancel, type: TGMenuSheetButtonTypeCancel, action: { [weak controller] in
        controller?.dismiss(animated: true)
    })!
    itemViews.append(cancelItem)
    
    controller.setItemViews(itemViews)
    
    return controller
}

func legacyPasteMenu(account: Account, peer: Peer, saveEditedPhotos: Bool, allowGrouping: Bool, theme: PresentationTheme, strings: PresentationStrings, images: [UIImage], sendMessagesWithSignals: @escaping ([Any]?) -> Void) -> ViewController {
    
    let legacyController = LegacyController(presentation: .custom, theme: theme)
    legacyController.statusBar.statusBarStyle = .Hide
    let baseController = TGViewController(context: legacyController.context)!
    legacyController.bind(controller: baseController)
    var hasTimer = false
    if peer is TelegramUser || peer is TelegramSecretChat {
        hasTimer = true
    }
    let recipientName = peer.displayTitle
    
    legacyController.presentationCompleted = { [weak legacyController, weak baseController] in
        if let strongLegacyController = legacyController, let baseController = baseController {
            TGClipboardMenu.present(inParentController: baseController, context: strongLegacyController.context, images: images, hasCaption: true, hasTimer: hasTimer, recipientName: recipientName, completed: { selectionContext, editingContext, currentItem in
                let signals = TGClipboardMenu.resultSignals(for: selectionContext, editingContext: editingContext, currentItem: currentItem, descriptionGenerator: legacyAssetPickerItemGenerator())
                sendMessagesWithSignals(signals)
            }, dismissed: {
                if let strongLegacyController = legacyController {
                    strongLegacyController.dismiss()
                }
            }, sourceView: baseController.view, sourceRect: nil)
        }
    }
    return legacyController
}
