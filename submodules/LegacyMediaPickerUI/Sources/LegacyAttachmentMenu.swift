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

public struct LegacyAttachmentMenuMediaEditing: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let imageOrVideo = LegacyAttachmentMenuMediaEditing(rawValue: 1 << 0)
}

public func legacyAttachmentMenu(context: AccountContext, peer: Peer, editMediaOptions: LegacyAttachmentMenuMediaEditing?, saveEditedPhotos: Bool, allowGrouping: Bool, hasSchedule: Bool, canSendPolls: Bool, presentationData: PresentationData, parentController: LegacyController, recentlyUsedInlineBots: [Peer], initialCaption: String, openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, openFileGallery: @escaping () -> Void, openWebSearch: @escaping () -> Void, openMap: @escaping () -> Void, openContacts: @escaping () -> Void, openPoll: @escaping () -> Void, presentSelectionLimitExceeded: @escaping () -> Void, presentCantSendMultipleFiles: @escaping () -> Void, presentSchedulePicker: @escaping (@escaping (Int32) -> Void) -> Void, sendMessagesWithSignals: @escaping ([Any]?, Bool, Int32) -> Void, selectRecentlyUsedInlineBot: @escaping (Peer) -> Void) -> TGMenuSheetController {
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
        carouselItem.cameraPressed = { [weak controller] cameraView in
            if let controller = controller {
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
        let fileItem = TGMenuSheetButtonItemView(title: presentationData.strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: {[weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
        underlyingViews.append(fileItem)
    }
    
    if canEditCurrent {
        let fileItem = TGMenuSheetButtonItemView(title: presentationData.strings.AttachmentMenu_File, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: {[weak controller] in
            controller?.dismiss(animated: true)
            openFileGallery()
        })!
        itemViews.append(fileItem)
    }
    
    if editMediaOptions == nil {
        let locationItem = TGMenuSheetButtonItemView(title: presentationData.strings.Conversation_Location, type: TGMenuSheetButtonTypeDefault, fontSize: fontSize, action: { [weak controller] in
            controller?.dismiss(animated: true)
            openMap()
        })!
        itemViews.append(locationItem)
        
        if (peer is TelegramGroup || peer is TelegramChannel) && canSendMessagesToPeer(peer) && canSendPolls {
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
