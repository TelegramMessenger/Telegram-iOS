import Foundation
import TelegramLegacyComponents
import Display
import UIKit

func presentedLegacyCamera(cameraView: TGAttachmentCameraView?, menuController: TGMenuSheetController?, parentController: ViewController, sendMessagesWithSignals: @escaping ([Any]?) -> Void) {
    let controller: TGCameraController
    if let cameraView = cameraView, let previewView = cameraView.previewView() {
        controller = TGCameraController(camera: previewView.camera, previewView: previewView, intent: TGCameraControllerGenericIntent)
    } else {
        controller = TGCameraController()
    }
    
    controller.isImportant = true
    controller.shouldStoreCapturedAssets = true
    controller.allowCaptions = false//true
    controller.inhibitDocumentCaptions = false
    controller.suggestionContext = nil
    
    let screenSize = parentController.view.bounds.size
    var standalone = true
    var startFrame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)
    if let cameraView = cameraView, let menuController = menuController {
        standalone = false
        startFrame = menuController.view.convert(cameraView.previewView()!.frame, from: cameraView)
    }
    
    let legacyController = LegacyController(legacyController: controller, presentation: .custom)
    legacyController.controllerLoaded = { [weak controller, weak legacyController] in
        if let controller = controller, let legacyController = legacyController {
            cameraView?.detachPreviewView()
            controller.beginTransitionIn(from: startFrame)
        }
    }
    
    controller.presentOverlayController = { [weak legacyController] controller in
        if let legacyController = legacyController {
            let childController = LegacyController(legacyController: controller!, presentation: .custom)
            legacyController.present(childController, in: .window)
            return { [weak childController] in
                childController?.dismiss()
            }
        } else {
            return {
                
            }
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
    
    controller.finishedTransitionOut = { [weak cameraView] in
        if let cameraView = cameraView {
            cameraView.attachPreviewView(animated: true)
        }
    }
    
    controller.customDismiss = { [weak legacyController] in
        legacyController?.dismiss()
    }
    
    controller.finishedWithPhoto = { [weak menuController] image, caption, stickers in
        if let image = image {
            let description = NSMutableDictionary()
            description["type"] = "capturedPhoto"
            description["image"] = image
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil) {
                sendMessagesWithSignals([SSignal.single(item)])
            }
        }
        
        menuController?.dismiss(animated: false)
    }
    
    controller.finishedWithVideo = { [weak menuController] videoURL, previewImage, duration, dimensions, adjustments, caption, stickers in
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
            if let item = legacyAssetPickerItemGenerator()(description, caption, nil) {
                sendMessagesWithSignals([SSignal.single(item)])
            }
        }
        menuController?.dismiss(animated: false)
    }
    
    parentController.present(legacyController, in: .window)
    
    /*
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    controllerWindow.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
    
    __weak TGModernConversationController *weakSelf = self;
    __weak TGCameraController *weakCameraController = controller;
    __weak TGAttachmentCameraView *weakCameraView = cameraView;
    
    controller.beginTransitionOut = ^CGRect
    {
        __strong TGCameraController *strongCameraController = weakCameraController;
        if (strongCameraController == nil)
        return CGRectZero;
        
        __strong TGAttachmentCameraView *strongCameraView = weakCameraView;
        if (strongCameraView != nil)
        {
            [strongCameraView willAttachPreviewView];
            if (TGIsPad())
            return CGRectZero;
            
            return [strongCameraController.view convertRect:strongCameraView.frame fromView:strongCameraView.superview];
        }
        
        return CGRectZero;
    };
    
    controller.finishedTransitionOut = ^
        {
            __strong TGAttachmentCameraView *strongCameraView = weakCameraView;
            if (strongCameraView == nil)
            return;
            
            [strongCameraView attachPreviewViewAnimated:true];
    };
    
    controller.finishedWithPhoto = ^(UIImage *resultImage, NSString *caption, NSArray *stickers)
    {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __autoreleasing NSString *disabledMessage = nil;
        if (![TGApplicationFeatures isPhotoUploadEnabledForPeerType:[_companion applicationFeaturePeerType] disabledMessage:&disabledMessage])
        {
            [[[TGAlertView alloc] initWithTitle:TGLocalized(@"FeatureDisabled.Oops") message:disabledMessage cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil] show];
            return;
        }
        
        NSDictionary *imageDescription = [strongSelf->_companion imageDescriptionFromImage:resultImage stickers:stickers caption:caption optionalAssetUrl:nil];
        NSMutableArray *descriptions = [[NSMutableArray alloc] init];
        if (imageDescription != nil)
        [descriptions addObject:imageDescription];
        [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:descriptions asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:nil];
        
        [menuController dismissAnimated:false];
    };
    
    controller.finishedWithVideo = ^(NSURL *videoURL, UIImage *previewImage, NSTimeInterval duration, CGSize dimensions, TGVideoEditAdjustments *adjustments, NSString *caption, NSArray *stickers)
    {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __autoreleasing NSString *disabledMessage = nil;
        if (![TGApplicationFeatures isFileUploadEnabledForPeerType:[_companion applicationFeaturePeerType] disabledMessage:&disabledMessage])
        {
            [[[TGAlertView alloc] initWithTitle:TGLocalized(@"FeatureDisabled.Oops") message:disabledMessage cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil] show];
            return;
        }
        
        NSDictionary *desc = [strongSelf->_companion videoDescriptionFromVideoURL:videoURL previewImage:previewImage dimensions:dimensions duration:duration adjustments:adjustments stickers:stickers caption:caption];
        [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:@[ desc ] asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:nil];
        
        [menuController dismissAnimated:true];
    };*/
}
