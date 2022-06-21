import Foundation
import UIKit
import LegacyComponents
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import ShareController
import LegacyUI
import LegacyMediaPickerUI

func presentedLegacyCamera(context: AccountContext, peer: Peer, chatLocation: ChatLocation, cameraView: TGAttachmentCameraView?, menuController: TGMenuSheetController?, parentController: ViewController, attachmentController: ViewController? = nil, editingMedia: Bool, saveCapturedPhotos: Bool, mediaGrouping: Bool, initialCaption: NSAttributedString, hasSchedule: Bool, photoOnly: Bool, sendMessagesWithSignals: @escaping ([Any]?, Bool, Int32) -> Void, recognizedQRCode: @escaping (String) -> Void = { _ in }, presentSchedulePicker: @escaping (Bool, @escaping (Int32) -> Void) -> Void, presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void, presentStickers: @escaping (@escaping (TelegramMediaFile, Bool, UIView, CGRect) -> Void) -> TGPhotoPaintStickersScreen?, getCaptionPanelView: @escaping () -> TGCaptionPanelView?, dismissedWithResult: @escaping () -> Void = {}, finishedTransitionIn: @escaping () -> Void = {}) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
    legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
    legacyController.statusBar.statusBarStyle = .Hide
    
    legacyController.deferScreenEdgeGestures = [.top]

    let isSecretChat = peer.id.namespace == Namespaces.Peer.SecretChat

    let controller: TGCameraController
    if let cameraView = cameraView, let previewView = cameraView.previewView() {
        controller = TGCameraController(context: legacyController.context, saveEditedPhotos: saveCapturedPhotos && !isSecretChat, saveCapturedMedia: saveCapturedPhotos && !isSecretChat, camera: previewView.camera, previewView: previewView, intent: photoOnly ? TGCameraControllerGenericPhotoOnlyIntent : TGCameraControllerGenericIntent)
    } else {
        controller = TGCameraController(context: legacyController.context, saveEditedPhotos: saveCapturedPhotos && !isSecretChat, saveCapturedMedia: saveCapturedPhotos && !isSecretChat)
    }
    controller.inhibitMultipleCapture = editingMedia
    
    if !initialCaption.string.isEmpty {
        controller.forcedCaption = initialCaption
    }
    
    controller.presentScheduleController = { _, done in
        presentSchedulePicker(true, { time in
            done?(time)
        })
    }
    controller.presentTimerController = { done in
        presentTimerPicker { time in
            done?(time)
        }
    }
    
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
    } else {
        controller.customPresentOverlayController = { [weak legacyController] generateController in
            guard let legacyController = legacyController, let generateController = generateController else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let overlayLegacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
            overlayLegacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
            overlayLegacyController.statusBar.statusBarStyle = .Hide
            
            let overlayController = generateController(overlayLegacyController.context)!
            
            overlayLegacyController.bind(controller: overlayController)
            overlayController.customDismissSelf = { [weak overlayLegacyController] in
                overlayLegacyController?.dismiss()
            }
            
            legacyController.present(overlayLegacyController, in: .window(.root))
        }
    }
    
    let paintStickersContext = LegacyPaintStickersContext(context: context)
    paintStickersContext.captionPanelView = {
        return getCaptionPanelView()
    }
    paintStickersContext.presentStickersController = { completion in
        return presentStickers({ file, animated, view, rect in
            let coder = PostboxEncoder()
            coder.encodeRootObject(file)
            completion?(coder.makeData(), animated, view, rect)
        })
    }
    
    controller.stickersContext = paintStickersContext
    controller.isImportant = true
    controller.shouldStoreCapturedAssets = saveCapturedPhotos && !isSecretChat
    controller.allowCaptions = true
    controller.allowCaptionEntities = true
    controller.allowGrouping = mediaGrouping
    controller.inhibitDocumentCaptions = false
    controller.recipientName = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    if peer.id != context.account.peerId {
        if peer is TelegramUser {
            controller.hasTimer = hasSchedule
        }
        controller.hasSilentPosting = true
    }
    controller.hasSchedule = hasSchedule
    controller.reminder = peer.id == context.account.peerId
    
    let screenSize = parentController.view.bounds.size
    var startFrame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)
    if let cameraView = cameraView  {
        if let attachmentController = attachmentController {
            startFrame = attachmentController.view.convert(cameraView.previewView()!.frame, from: cameraView)
        } else if let menuController = menuController {
            startFrame = menuController.view.convert(cameraView.previewView()!.frame, from: cameraView)
        } else {
            startFrame = parentController.view.convert(cameraView.previewView()!.frame, from: cameraView)
        }
    }
    
    legacyController.bind(controller: controller)
    legacyController.controllerLoaded = { [weak controller] in
        if let controller = controller {
            cameraView?.detachPreviewView()
            controller.beginTransitionIn(from: startFrame)
            controller.view.disablesInteractiveTransitionGestureRecognizer = true
        }
    }
    controller.finishedTransitionIn = {
        finishedTransitionIn()
    }
    controller.beginTransitionOut = { [weak controller, weak cameraView] in
        if let controller = controller, let cameraView = cameraView {
            cameraView.willAttachPreviewView()
            return controller.view.convert(cameraView.frame, from: cameraView.superview)
        } else {
            return CGRect()
        }
    }
    
    controller.finishedTransitionOut = { [weak cameraView, weak legacyController] in
        if let cameraView = cameraView {
            cameraView.attachPreviewView(animated: true)
        }
        legacyController?.dismiss()
    }
    
    controller.finishedWithResults = { [weak menuController, weak legacyController] overlayController, selectionContext, editingContext, currentItem, silentPosting, scheduleTime in
        if let selectionContext = selectionContext, let editingContext = editingContext {
            let nativeGenerator = legacyAssetPickerItemGenerator()
            let signals = TGCameraController.resultSignals(for: selectionContext, editingContext: editingContext, currentItem: currentItem, storeAssets: saveCapturedPhotos && !isSecretChat, saveEditedPhotos: saveCapturedPhotos && !isSecretChat, descriptionGenerator: { _1, _2, _3 in
                nativeGenerator(_1, _2, _3, nil)
            })
            sendMessagesWithSignals(signals, silentPosting, scheduleTime)
        }
        
        menuController?.dismiss(animated: false)
        legacyController?.dismissWithAnimation()
        dismissedWithResult()
    }
    
    controller.finishedWithPhoto = { [weak menuController, weak legacyController] overlayController, image, caption, stickers, timer in
        if let image = image {
            let description = NSMutableDictionary()
            description["type"] = "capturedPhoto"
            description["image"] = image
            if let timer = timer {
                description["timer"] = timer
            }
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil, nil) {
                sendMessagesWithSignals([SSignal.single(item)], false, 0)
            }
        }
        
        menuController?.dismiss(animated: false)
        legacyController?.dismissWithAnimation()
        dismissedWithResult()
    }
    
    controller.finishedWithVideo = { [weak menuController, weak legacyController] overlayController, videoURL, previewImage, duration, dimensions, adjustments, caption, stickers, timer in
        if let videoURL = videoURL {
            let description = NSMutableDictionary()
            description["type"] = "video"
            description["url"] = videoURL.path
            if let previewImage = previewImage {
                description["previewImage"] = previewImage
            }
            if let adjustments = adjustments {
                description["adjustments"] = adjustments
            }
            description["duration"] = duration as NSNumber
            description["dimensions"] = NSValue(cgSize: dimensions)
            if let timer = timer {
                description["timer"] = timer
            }
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil, nil) {
                sendMessagesWithSignals([SSignal.single(item)], false, 0)
            }
        }
        menuController?.dismiss(animated: false)
        legacyController?.dismissWithAnimation()
        dismissedWithResult()
    }
    
    controller.recognizedQRCode = { code in
        if let code = code {
            recognizedQRCode(code)
        }
    }
    
    parentController.present(legacyController, in: .window(.root))
}

func presentedLegacyShortcutCamera(context: AccountContext, saveCapturedMedia: Bool, saveEditedPhotos: Bool, mediaGrouping: Bool, parentController: ViewController) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
    legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
    legacyController.statusBar.statusBarStyle = .Hide
    
    legacyController.deferScreenEdgeGestures = [.top]
    
    let controller = TGCameraController(context: legacyController.context, saveEditedPhotos: saveEditedPhotos, saveCapturedMedia: saveCapturedMedia)!
    controller.shortcut = false
    controller.isImportant = true
    controller.shouldStoreCapturedAssets = saveCapturedMedia
    controller.allowCaptions = true
    controller.allowCaptionEntities = true
    controller.allowGrouping = mediaGrouping
    
    let screenSize = parentController.view.bounds.size
    let startFrame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)
    
    legacyController.bind(controller: controller)
    legacyController.controllerLoaded = { [weak controller] in
        if let controller = controller {
            controller.beginTransitionIn(from: startFrame)
        }
    }
    
    controller.finishedTransitionOut = { [weak legacyController] in
        legacyController?.dismiss()
    }
    
    controller.customDismissBlock = { [weak legacyController] in
        legacyController?.dismiss()
    }
    
    controller.finishedWithResults = { [weak parentController] overlayController, selectionContext, editingContext, currentItem, _, _ in
        if let selectionContext = selectionContext, let editingContext = editingContext {
            let nativeGenerator = legacyAssetPickerItemGenerator()
            let signals = TGCameraController.resultSignals(for: selectionContext, editingContext: editingContext, currentItem: currentItem, storeAssets: saveCapturedMedia, saveEditedPhotos: saveEditedPhotos, descriptionGenerator: { _1, _2, _3 in
                nativeGenerator(_1, _2, _3, nil)
            })
            if let parentController = parentController {
                parentController.present(ShareController(context: context, subject: .fromExternal({ peerIds, text, account, silently in
                    return legacyAssetPickerEnqueueMessages(account: account, signals: signals!)
                    |> `catch` { _ -> Signal<[LegacyAssetPickerEnqueueMessage], NoError> in
                        return .single([])
                    }
                    |> mapToSignal { messages -> Signal<ShareControllerExternalStatus, NoError> in
                        let resultSignals = peerIds.map({ peerId in
                            return enqueueMessages(account: account, peerId: peerId, messages: messages.map { $0.message })
                            |> mapToSignal { _ -> Signal<ShareControllerExternalStatus, NoError> in
                                return .complete()
                            }
                        })
                        return combineLatest(resultSignals)
                        |> mapToSignal { _ -> Signal<ShareControllerExternalStatus, NoError> in
                            return .complete()
                        }
                        |> then(.single(ShareControllerExternalStatus.done))
                    }
                }), showInChat: nil, externalShare: false), in: .window(.root))
            }
        }
    }
    
    parentController.present(legacyController, in: .window(.root))
}
