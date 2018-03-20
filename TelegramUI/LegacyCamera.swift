import Foundation
import LegacyComponents
import Display
import UIKit
import TelegramCore
import Postbox

func presentedLegacyCamera(account: Account, peer: Peer, cameraView: TGAttachmentCameraView?, menuController: TGMenuSheetController?, parentController: ViewController, sendMessagesWithSignals: @escaping ([Any]?) -> Void) {
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
    legacyController.supportedOrientations = .portrait
    legacyController.statusBar.statusBarStyle = .Hide
    
    legacyController.deferScreenEdgeGestures = [.top]
    
    let controller: TGCameraController
    if let cameraView = cameraView, let previewView = cameraView.previewView() {
        controller = TGCameraController(context: legacyController.context, saveEditedPhotos: true, saveCapturedMedia: true, camera: previewView.camera, previewView: previewView, intent: TGCameraControllerGenericIntent)
    } else {
        controller = TGCameraController()
    }
    
    controller.isImportant = true
    controller.shouldStoreCapturedAssets = true
    controller.allowCaptions = true
    controller.inhibitDocumentCaptions = false
    controller.suggestionContext = legacySuggestionContext(account: account, peerId: peer.id)
    controller.recipientName = peer.displayTitle
    if (peer is TelegramUser || peer is TelegramSecretChat) && peer.id != account.peerId {
        controller.hasTimer = true
    }
    
    let screenSize = parentController.view.bounds.size
    var startFrame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)
    if let cameraView = cameraView, let menuController = menuController {
        startFrame = menuController.view.convert(cameraView.previewView()!.frame, from: cameraView)
    }
    
    legacyController.bind(controller: controller)
    legacyController.controllerLoaded = { [weak controller] in
        if let controller = controller {
            cameraView?.detachPreviewView()
            controller.beginTransitionIn(from: startFrame)
        }
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
    
    controller.finishedWithPhoto = { [weak menuController, weak legacyController] overlayController, image, caption, stickers, timer in
        if let image = image {
            let description = NSMutableDictionary()
            description["type"] = "capturedPhoto"
            description["image"] = image
            if let timer = timer {
                description["timer"] = timer
            }
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil) {
                sendMessagesWithSignals([SSignal.single(item)])
            }
        }
        
        menuController?.dismiss(animated: false)
        legacyController?.dismissWithAnimation()
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
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil) {
                sendMessagesWithSignals([SSignal.single(item)])
            }
        }
        menuController?.dismiss(animated: false)
        legacyController?.dismissWithAnimation()
    }
    
    parentController.present(legacyController, in: .window(.root))
}
