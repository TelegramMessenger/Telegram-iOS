import Foundation
import UIKit
import LegacyComponents
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import DeviceAccess
import AccountContext
import LegacyUI
import SaveToCameraRoll

public func defaultVideoPresetForContext(_ context: AccountContext) -> TGMediaVideoConversionPreset {
    var networkType: NetworkType = .wifi
    let _ = (context.account.networkType
    |> take(1)).start(next: { value in
        networkType = value
    })
    
    let autodownloadSettings = context.sharedContext.currentAutodownloadSettings.with { $0 }
    let presetSettings: AutodownloadPresetSettings
    switch networkType {
    case .wifi:
        presetSettings = autodownloadSettings.highPreset
    default:
        presetSettings = autodownloadSettings.mediumPreset
    }
    
    let effectiveValue: Int
    if presetSettings.videoUploadMaxbitrate == 0 {
        effectiveValue = 0
    } else {
        effectiveValue = Int(presetSettings.videoUploadMaxbitrate) * 5 / 100
    }
    
    switch effectiveValue {
    case 0:
        return TGMediaVideoConversionPresetCompressedMedium
    case 1:
        return TGMediaVideoConversionPresetCompressedVeryLow
    case 2:
        return TGMediaVideoConversionPresetCompressedLow
    case 3:
        return TGMediaVideoConversionPresetCompressedMedium
    case 4:
        return TGMediaVideoConversionPresetCompressedHigh
    case 5:
        return TGMediaVideoConversionPresetCompressedVeryHigh
    default:
        return TGMediaVideoConversionPresetCompressedMedium
    }
}

public enum LegacyAttachmentMenuMediaEditing {
    case none
    case imageOrVideo(AnyMediaReference?)
    case file
}

public func legacyAttachmentMenu(context: AccountContext, peer: Peer, editMediaOptions: LegacyAttachmentMenuMediaEditing?, saveEditedPhotos: Bool, allowGrouping: Bool, hasSchedule: Bool, canSendPolls: Bool, presentationData: PresentationData, parentController: LegacyController, recentlyUsedInlineBots: [Peer], initialCaption: String, openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, openFileGallery: @escaping () -> Void, openWebSearch: @escaping () -> Void, openMap: @escaping () -> Void, openContacts: @escaping () -> Void, openPoll: @escaping () -> Void, presentSelectionLimitExceeded: @escaping () -> Void, presentCantSendMultipleFiles: @escaping () -> Void, presentSchedulePicker: @escaping (@escaping (Int32) -> Void) -> Void, sendMessagesWithSignals: @escaping ([Any]?, Bool, Int32) -> Void, selectRecentlyUsedInlineBot: @escaping (Peer) -> Void, present: @escaping (ViewController, Any?) -> Void) -> TGMenuSheetController {
    let defaultVideoPreset = defaultVideoPresetForContext(context)
    UserDefaults.standard.set(defaultVideoPreset.rawValue as NSNumber, forKey: "TG_preferredVideoPreset_v0")
    
    let actionSheetTheme = ActionSheetControllerTheme(presentationData: presentationData)
    let fontSize = floor(actionSheetTheme.baseFontSize * 20.0 / 17.0)
    
    let isSecretChat = peer.id.namespace == Namespaces.Peer.SecretChat
    
    let controller = TGMenuSheetController(context: parentController.context, dark: false)!
    controller.dismissesByOutsideTap = true
    controller.hasSwipeGesture = true
    controller.maxHeight = 445.0
    controller.forceFullScreen = true
    
    var itemViews: [Any] = []
    
    var editing = false
    var canSendImageOrVideo = false
    var canEditFile = false
    var editCurrentMedia: AnyMediaReference?
    if let editMediaOptions = editMediaOptions {
        switch editMediaOptions {
        case .none:
            break
        case let .imageOrVideo(anyReference):
            editCurrentMedia = anyReference
        case .file:
            canEditFile = true
        }
        canSendImageOrVideo = true
        editing = true
    } else {
        canSendImageOrVideo = true
    }
    
    var carouselItemView: TGAttachmentCarouselItemView?
    
    var underlyingViews: [UIView] = []
    
    var selectionLimit: Int32 = 100
    var slowModeEnabled = false
    if let channel = peer as? TelegramChannel, channel.isRestrictedBySlowmode {
        slowModeEnabled = true
        selectionLimit = 10
    }
    
    if canSendImageOrVideo {
        let carouselItem = TGAttachmentCarouselItemView(context: parentController.context, camera: PGCamera.cameraAvailable(), selfPortrait: false, forProfilePhoto: false, assetType: TGMediaAssetAnyType, saveEditedPhotos: !isSecretChat && saveEditedPhotos, allowGrouping: editMediaOptions == nil && allowGrouping, allowSelection: editMediaOptions == nil, allowEditing: true, document: false, selectionLimit: selectionLimit)!
        carouselItemView = carouselItem
        carouselItem.suggestionContext = legacySuggestionContext(context: context, peerId: peer.id)
        carouselItem.recipientName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        carouselItem.cameraPressed = { [weak controller, weak parentController] cameraView in
            if let controller = controller {
                if let parentController = parentController, parentController.context.currentlyInSplitView() {
                    return
                }
                
                DeviceAccess.authorizeAccess(to: .camera, presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
                    if value {
                        openCamera(cameraView, controller)
                    }
                })
            }
        }
        carouselItem.selectionLimitExceeded = {
            presentSelectionLimitExceeded()
        }
        if peer.id != context.account.peerId {
            if peer is TelegramUser {
                carouselItem.hasTimer = hasSchedule
            }
            carouselItem.hasSilentPosting = !isSecretChat
        }
        carouselItem.hasSchedule = hasSchedule
        carouselItem.reminder = peer.id == context.account.peerId
        carouselItem.presentScheduleController = { done in
            presentSchedulePicker { time in
                done?(time)
            }
        }
        carouselItem.sendPressed = { [weak controller, weak carouselItem] currentItem, asFiles, silentPosting, scheduleTime in
            if let controller = controller, let carouselItem = carouselItem {
                let intent: TGMediaAssetsControllerIntent = asFiles ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent
                let signals = TGMediaAssetsController.resultSignals(for: carouselItem.selectionContext, editingContext: carouselItem.editingContext, intent: intent, currentItem: currentItem, storeAssets: true, useMediaCache: false, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: saveEditedPhotos)
                if slowModeEnabled, let signals = signals, signals.count > 1 {
                    presentCantSendMultipleFiles()
                } else {
                    controller.dismiss(animated: true)
                    sendMessagesWithSignals(signals, silentPosting, scheduleTime)
                }
            }
        };
        carouselItem.allowCaptions = true
        carouselItem.editingContext.setInitialCaption(initialCaption, entities: [])
        itemViews.append(carouselItem)
        
        let galleryItem = TGMenuSheetButtonItemView(title: editing ? presentationData.strings.Conversation_EditingMessageMediaChange : presentationData.strings.AttachmentMenu_PhotoOrVideo, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
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
        let fileItem = TGMenuSheetButtonItemView(title: presentationData.strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
        underlyingViews.append(fileItem)
    }
    
    if canEditFile {
        let fileItem = TGMenuSheetButtonItemView(title: presentationData.strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
    }
    
    if let editCurrentMedia = editCurrentMedia {
        let title: String
        if editCurrentMedia.media is TelegramMediaImage {
            title = presentationData.strings.Conversation_EditingMessageMediaEditCurrentPhoto
        } else {
            title = presentationData.strings.Conversation_EditingMessageMediaEditCurrentVideo
        }
        let editCurrentItem = TGMenuSheetButtonItemView(title: title, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
            controller?.dismiss(animated: true)
            
            let _ = (fetchMediaData(context: context, postbox: context.account.postbox, mediaReference: editCurrentMedia)
            |> deliverOnMainQueue).start(next: { (value, isImage) in
                guard case let .data(data) = value, data.complete else {
                    return
                }
                
                let item: TGMediaEditableItem & TGMediaSelectableItem
                if let image = UIImage(contentsOfFile: data.path) {
                    item = TGCameraCapturedPhoto(existing: image)
                } else {
                    item = TGCameraCapturedVideo(url: URL(fileURLWithPath: data.path))
                }
                
                let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
                legacyController.statusBar.statusBarStyle = .Ignore
                legacyController.controllerLoaded = { [weak legacyController] in
                    legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                }
                
                let emptyController = LegacyEmptyController(context: legacyController.context)!
                emptyController.navigationBarShouldBeHidden = true
                let navigationController = makeLegacyNavigationController(rootController: emptyController)
                navigationController.setNavigationBarHidden(true, animated: false)
                legacyController.bind(controller: navigationController)
                
                var hasTimer = false
                var hasSilentPosting = false
                if peer.id != context.account.peerId {
                    if peer is TelegramUser {
                        hasTimer = true
                    }
                    hasSilentPosting = true
                }
                let recipientName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                
                legacyController.enableSizeClassSignal = true
                
                let presentationDisposable = context.sharedContext.presentationData.start(next: { [weak legacyController] presentationData in
                    if let legacyController = legacyController, let controller = legacyController.legacyController as? TGMenuSheetController  {
                        controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme)
                    }
                })
                legacyController.disposables.add(presentationDisposable)
                
                present(legacyController, nil)
                
                TGPhotoVideoEditor.present(with: legacyController.context, controller: emptyController, caption: "", entities: [], withItem: item, recipientName: recipientName, completion: { result, editingContext in
                    let intent: TGMediaAssetsControllerIntent = TGMediaAssetsControllerSendMediaIntent
                    let signals = TGCameraController.resultSignals(for: nil, editingContext: editingContext, currentItem: result as! TGMediaSelectableItem, storeAssets: false, saveEditedPhotos: false, descriptionGenerator: legacyAssetPickerItemGenerator())
                    sendMessagesWithSignals(signals, false, 0)
                    /*
                     [TGCameraController resultSignalsForSelectionContext:nil editingContext:editingContext currentItem:result storeAssets:false saveEditedPhotos:false descriptionGenerator:^id(id result, NSString *caption, NSArray *entities, NSString *hash)
                     {
                         __strong TGModernConversationController *strongSelf = weakSelf;
                         if (strongSelf == nil)
                             return nil;
                         
                         NSDictionary *desc = [strongSelf _descriptionForItem:result caption:caption entities:entities hash:hash allowRemoteCache:allowRemoteCache];
                         return [strongSelf _descriptionForReplacingMedia:desc message:message];
                     }]]
                     */
                    //let signals = TGMediaAssetsController.resultSignals(for: nil, editingContext: editingContext, intent: intent, currentItem: result, storeAssets: true, useMediaCache: false, descriptionGenerator: legacyAssetPickerItemGenerator(), saveEditedPhotos: saveEditedPhotos)
                    //sendMessagesWithSignals(signals, silentPosting, scheduleTime)
                }, dismissed: { [weak legacyController] in
                    legacyController?.dismiss()
                })
            })
            /*
             
             
                 bool allowRemoteCache = [strongSelf->_companion controllerShouldCacheServerAssets];
                 [TGPhotoVideoEditor presentWithContext:[TGLegacyComponentsContext shared] controller:strongSelf caption:text entities:entities withItem:item recipientName:[strongSelf->_companion title] completion:^(id result, TGMediaEditingContext *editingContext)
                 {
                     [strongSelf _asyncProcessMediaAssetSignals:[TGCameraController resultSignalsForSelectionContext:nil editingContext:editingContext currentItem:result storeAssets:false saveEditedPhotos:false descriptionGenerator:^id(id result, NSString *caption, NSArray *entities, NSString *hash)
                     {
                         __strong TGModernConversationController *strongSelf = weakSelf;
                         if (strongSelf == nil)
                             return nil;
                         
                         NSDictionary *desc = [strongSelf _descriptionForItem:result caption:caption entities:entities hash:hash allowRemoteCache:allowRemoteCache];
                         return [strongSelf _descriptionForReplacingMedia:desc message:message];
                     }]];
                     [strongSelf endMessageEditing:true];
                 }];
             */
        })!
        itemViews.append(editCurrentItem)
    }
    
    if editMediaOptions == nil {
        let locationItem = TGMenuSheetButtonItemView(title: presentationData.strings.Conversation_Location, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
            controller?.dismiss(animated: true)
            openMap()
        })!
        itemViews.append(locationItem)
        
        var peerSupportsPolls = false
        if peer is TelegramGroup || peer is TelegramChannel {
            peerSupportsPolls = true
        } else if let user = peer as? TelegramUser, let _ = user.botInfo {
            peerSupportsPolls = true
        }
        if peerSupportsPolls && canSendMessagesToPeer(peer) && canSendPolls {
            let pollItem = TGMenuSheetButtonItemView(title: presentationData.strings.AttachmentMenu_Poll, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
                controller?.dismiss(animated: true)
                openPoll()
            })!
            itemViews.append(pollItem)
        }
    
        let contactItem = TGMenuSheetButtonItemView(title: presentationData.strings.Conversation_Contact, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
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
                let botItem = TGMenuSheetButtonItemView(title: "@" + addressName, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
                    controller?.dismiss(animated: true)
                    
                    selectRecentlyUsedInlineBot(peer)
                })!
                botItem.overflow = true
                itemViews.append(botItem)
            }
        }
    }
    
    carouselItemView?.remainingHeight = TGMenuSheetButtonItemViewHeight * CGFloat(itemViews.count - 1)
    
    let cancelItem = TGMenuSheetButtonItemView(title: presentationData.strings.Common_Cancel, type: TGMenuSheetButtonTypeCancel, fontSize: actionSheetTheme.baseFontSize, action: { [weak controller] in
        controller?.dismiss(animated: true)
    })!
    itemViews.append(cancelItem)
    
    controller.setItemViews(itemViews)
    
    return controller
}

public func legacyMenuPaletteFromTheme(_ theme: PresentationTheme) -> TGMenuSheetPallete {
    let sheetTheme = theme.actionSheet
    return TGMenuSheetPallete(dark: theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
}

public func presentLegacyPasteMenu(context: AccountContext, peer: Peer, saveEditedPhotos: Bool, allowGrouping: Bool, presentationData: PresentationData, images: [UIImage], sendMessagesWithSignals: @escaping ([Any]?) -> Void, present: (ViewController, Any?) -> Void, initialLayout: ContainerViewLayout? = nil) -> ViewController {
    let defaultVideoPreset = defaultVideoPresetForContext(context)
    UserDefaults.standard.set(defaultVideoPreset.rawValue as NSNumber, forKey: "TG_preferredVideoPreset_v0")
    
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: initialLayout)
    legacyController.statusBar.statusBarStyle = .Ignore
    legacyController.controllerLoaded = { [weak legacyController] in
        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    let emptyController = LegacyEmptyController(context: legacyController.context)!
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    legacyController.bind(controller: navigationController)
    
    var hasTimer = false
    var hasSilentPosting = false
    if peer.id != context.account.peerId {
        if peer is TelegramUser {
            hasTimer = true
        }
        hasSilentPosting = true
    }
    let recipientName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    
    legacyController.enableSizeClassSignal = true

    let controller = TGClipboardMenu.present(inParentController: emptyController, context: legacyController.context, images: images, hasCaption: true, hasTimer: hasTimer, recipientName: recipientName, completed: { selectionContext, editingContext, currentItem in
        let signals = TGClipboardMenu.resultSignals(for: selectionContext, editingContext: editingContext, currentItem: currentItem, descriptionGenerator: legacyAssetPickerItemGenerator())
        sendMessagesWithSignals(signals)
    }, dismissed: { [weak legacyController] in
        legacyController?.dismiss()
    }, sourceView: emptyController.view, sourceRect: nil)!
    controller.customRemoveFromParentViewController = { [weak legacyController] in
        legacyController?.dismiss()
    }
    
    let presentationDisposable = context.sharedContext.presentationData.start(next: { [weak legacyController] presentationData in
        if let legacyController = legacyController, let controller = legacyController.legacyController as? TGMenuSheetController  {
            controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme)
        }
    })
    legacyController.disposables.add(presentationDisposable)
    
    present(legacyController, nil)
    controller.present(in: emptyController, sourceView: nil, animated: true)
    
    return legacyController
}
