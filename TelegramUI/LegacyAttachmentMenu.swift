import Foundation
import UIKit
import LegacyComponents
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

func legacyAttachmentMenu(account: Account, peer: Peer, editMediaOptions: MessageMediaEditingOptions?, saveEditedPhotos: Bool, allowGrouping: Bool, theme: PresentationTheme, strings: PresentationStrings, parentController: LegacyController, recentlyUsedInlineBots: [Peer], openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, openFileGallery: @escaping () -> Void, openWebSearch: @escaping () -> Void, openMap: @escaping () -> Void, openContacts: @escaping () -> Void, sendMessagesWithSignals: @escaping ([Any]?) -> Void, selectRecentlyUsedInlineBot: @escaping (Peer) -> Void) -> TGMenuSheetController {
    let isSecretChat = peer.id.namespace == Namespaces.Peer.SecretChat
    
    let controller = TGMenuSheetController(context: parentController.context, dark: false)!
    controller.dismissesByOutsideTap = true
    controller.hasSwipeGesture = true
    controller.maxHeight = 445.0
    controller.forceFullScreen = true
    
    var itemViews: [Any] = []
    
    var editing = false
    var canSendImageOrVideo = false
    var canEditCurrent = false
    if let editMediaOptions = editMediaOptions, editMediaOptions.contains(.imageOrVideo) {
        canSendImageOrVideo = true
        editing = true
        canEditCurrent = true
    } else {
        canSendImageOrVideo = true
    }
    
    var carouselItemView: TGAttachmentCarouselItemView?
    
    var underlyingViews: [UIView] = []
    
    if canSendImageOrVideo {
        let carouselItem = TGAttachmentCarouselItemView(context: parentController.context, camera: PGCamera.cameraAvailable(), selfPortrait: false, forProfilePhoto: false, assetType: TGMediaAssetAnyType, saveEditedPhotos: !isSecretChat && saveEditedPhotos, allowGrouping: editMediaOptions == nil && allowGrouping, allowSelection: editMediaOptions == nil, allowEditing: true, document: false)!
        carouselItemView = carouselItem
        carouselItem.suggestionContext = legacySuggestionContext(account: account, peerId: peer.id)
        carouselItem.recipientName = peer.displayTitle
        carouselItem.cameraPressed = { [weak controller] cameraView in
            if let controller = controller {
                DeviceAccess.authorizeAccess(to: .camera, presentationData: account.telegramApplicationContext.currentPresentationData.with { $0 }, present: account.telegramApplicationContext.presentGlobalController, openSettings: account.telegramApplicationContext.applicationBindings.openSettings, { value in
                    if value {
                        openCamera(cameraView, controller)
                    }
                })
            }
        }
        if (peer is TelegramUser) && peer.id != account.peerId {
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
        
        let galleryItem = TGMenuSheetButtonItemView(title: editing ? strings.Conversation_EditingMessageMediaChange : strings.AttachmentMenu_PhotoOrVideo, type: TGMenuSheetButtonTypeDefault, action: { [weak controller] in
            controller?.dismiss(animated: true)
            openGallery()
        })!
        if !editing {
            galleryItem.longPressAction = { [weak controller] in
                if let controller = controller {
                    controller.dismiss(animated: true)
                }
                openWebSearch()
            }
        }
        itemViews.append(galleryItem)
        
        underlyingViews.append(galleryItem)
    }
    
    if !editing {
        let fileItem = TGMenuSheetButtonItemView(title: strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, action: {[weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
        underlyingViews.append(fileItem)
    }
    
    if canEditCurrent {
        let fileItem = TGMenuSheetButtonItemView(title: strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, action: {[weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
    }
    
    if editMediaOptions == nil {
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
    }
    
    carouselItemView?.underlyingViews = underlyingViews
    
    if editMediaOptions == nil {
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
    }
    
    carouselItemView?.remainingHeight = TGMenuSheetButtonItemViewHeight * CGFloat(itemViews.count - 1)
    
    let cancelItem = TGMenuSheetButtonItemView(title: strings.Common_Cancel, type: TGMenuSheetButtonTypeCancel, action: { [weak controller] in
        controller?.dismiss(animated: true)
    })!
    itemViews.append(cancelItem)
    
    controller.setItemViews(itemViews)
    
    return controller
}

func legacyMenuPaletteFromTheme(_ theme: PresentationTheme) -> TGMenuSheetPallete {
    let sheetTheme = theme.actionSheet
    return TGMenuSheetPallete(dark: theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
}

func legacyPasteMenu(account: Account, peer: Peer, saveEditedPhotos: Bool, allowGrouping: Bool, theme: PresentationTheme, strings: PresentationStrings, images: [UIImage], sendMessagesWithSignals: @escaping ([Any]?) -> Void) -> ViewController {
    
    let legacyController = LegacyController(presentation: .custom, theme: theme)
    legacyController.statusBar.statusBarStyle = .Hide
    legacyController.controllerLoaded = { [weak legacyController] in
        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    let baseController = TGViewController(context: legacyController.context)!
    legacyController.bind(controller: baseController)
    var hasTimer = false
    if (peer is TelegramUser) && peer.id != account.peerId {
        hasTimer = true
    }
    let recipientName = peer.displayTitle
    
    legacyController.enableSizeClassSignal = true
    legacyController.presentationCompleted = { [weak legacyController, weak baseController] in
        if let strongLegacyController = legacyController, let baseController = baseController {
            let controller = TGClipboardMenu.present(inParentController: baseController, context: strongLegacyController.context, images: images, hasCaption: true, hasTimer: hasTimer, recipientName: recipientName, completed: { selectionContext, editingContext, currentItem in
                let signals = TGClipboardMenu.resultSignals(for: selectionContext, editingContext: editingContext, currentItem: currentItem, descriptionGenerator: legacyAssetPickerItemGenerator())
                sendMessagesWithSignals(signals)
            }, dismissed: {
                if let strongLegacyController = legacyController {
                    strongLegacyController.dismiss()
                }
            }, sourceView: baseController.view, sourceRect: nil)
            controller?.customRemoveFromParentViewController = { [weak legacyController] in
                legacyController?.dismiss()
            }
        }
    }
    
    let presentationDisposable = account.telegramApplicationContext.presentationData.start(next: { [weak legacyController] presentationData in
        if let legacyController = legacyController, let controller = legacyController.legacyController as? TGMenuSheetController  {
            controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme)
        }
    })
    legacyController.disposables.add(presentationDisposable)
    
    return legacyController
}
