import Foundation
import UIKit
import TelegramLegacyComponents
import Display
import SwiftSignalKit

func legacyAttachmentMenu(parentController: LegacyController, presentOverlayController: @escaping (UIViewController) -> (() -> Void), openGallery: @escaping () -> Void, openCamera: @escaping (TGAttachmentCameraView?, TGMenuSheetController?) -> Void, sendMessagesWithSignals: @escaping ([Any]?) -> Void) -> TGMenuSheetController {
    let controller = TGMenuSheetController()
    controller.applicationInterface = parentController.applicationInterface
    controller.dismissesByOutsideTap = true
    controller.hasSwipeGesture = true
    //controller.maxHeight = 445.0 - TGMenuSheetButtonItemViewHeight
    
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
    })
    itemViews.append(galleryItem)
    
    let fileItem = TGMenuSheetButtonItemView(title: "File", type: TGMenuSheetButtonTypeDefault, action: {
    })
    itemViews.append(fileItem)
    
    let locationItem = TGMenuSheetButtonItemView(title: "Location", type: TGMenuSheetButtonTypeDefault, action: {
    })
    itemViews.append(locationItem)
    
    let contactItem = TGMenuSheetButtonItemView(title: "Contact", type: TGMenuSheetButtonTypeDefault, action: {
    })
    itemViews.append(contactItem)
    
    carouselItem.underlyingViews = [galleryItem, fileItem]
    
    carouselItem.remainingHeight = TGMenuSheetButtonItemViewHeight * CGFloat(itemViews.count - 1)
    
    let cancelItem = TGMenuSheetButtonItemView(title: "Cancel", type: TGMenuSheetButtonTypeCancel, action: { [weak controller] in
        controller?.dismiss(animated: true)
    })
    itemViews.append(cancelItem)
    
    controller.setItemViews(itemViews)
    
    return controller
    
    /*
    carouselItem.condensed = !hasContactItem;
    carouselItem.parentController = self;
    carouselItem.allowCaptions = [_companion allowCaptionedMedia];
    carouselItem.inhibitDocumentCaptions = [_companion encryptUploads];
    
    __weak TGAttachmentCarouselItemView *weakCarouselItem = carouselItem;
    carouselItem.suggestionContext = [self _suggestionContext];
    carouselItem.cameraPressed = ^(TGAttachmentCameraView *cameraView)
    {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
        return;
        
        [strongSelf _displayCameraWithView:cameraView menuController:strongController];
    };
    carouselItem.sendPressed = ^(TGMediaAsset *currentItem, bool asFiles)
    {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
        return;
        
        __strong TGAttachmentCarouselItemView *strongCarouselItem = weakCarouselItem;
        if (strongController == nil)
        return;
        
        [strongController dismissAnimated:true];
        
        TGMediaAssetsControllerIntent intent = asFiles ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent;
        [strongSelf _asyncProcessMediaAssetSignals:[TGMediaAssetsController resultSignalsForSelectionContext:strongCarouselItem.selectionContext editingContext:strongCarouselItem.editingContext intent:intent currentItem:currentItem storeAssets:[strongSelf->_companion controllerShouldStoreCapturedAssets] useMediaCache:[strongSelf->_companion controllerShouldCacheServerAssets] descriptionGenerator:^id(id result, NSString *caption, NSString *hash)
            {
            __strong TGModernConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
            return nil;
            
            return [strongSelf _descriptionForItem:result caption:caption hash:hash];
            }]];
    };
    carouselItem.editorOpened = ^
        {
            __strong TGModernConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
            return;
            
            [strongSelf _updateCanReadHistory:TGModernConversationActivityChangeInactive];
    };
    carouselItem.editorClosed = ^
        {
            __strong TGModernConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
            return;
            
            [strongSelf _updateCanReadHistory:TGModernConversationActivityChangeActive];
    };
    [itemViews addObject:carouselItem];
    
    TGMenuSheetButtonItemView *galleryItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"AttachmentMenu.PhotoOrVideo") type:TGMenuSheetButtonTypeDefault action:^
        {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
        return;
        
        [strongController dismissAnimated:true];
        [strongSelf _displayMediaPicker:false fromFileMenu:false];
        }];
    galleryItem.longPressAction = ^
        {
            __strong TGModernConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
            return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
            return;
            
            [strongController dismissAnimated:true];
            [strongSelf _displayWebImagePicker];
    };
    [itemViews addObject:galleryItem];
    
    TGMenuSheetButtonItemView *fileItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"AttachmentMenu.File") type:TGMenuSheetButtonTypeDefault action:^
        {
        __strong TGModernConversationController *strongSelf = weakSelf;
        if (strongSelf == nil)
        return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
        return;
        
        [strongSelf _displayFileMenuWithController:strongController];
        }];
    [itemViews addObject:fileItem];
    
    carouselItem.underlyingViews = @[ galleryItem, fileItem ];
    
    TGMenuSheetButtonItemView *locationItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.Location") type:TGMenuSheetButtonTypeDefault action:^
    {
    __strong TGModernConversationController *strongSelf = weakSelf;
    if (strongSelf == nil)
    return;
    
    __strong TGMenuSheetController *strongController = weakController;
    if (strongController == nil)
    return;
    
    [strongController dismissAnimated:true];
    [strongSelf _displayLocationPicker];
    }];
    [itemViews addObject:locationItem];
    
    if (hasContactItem)
    {
        TGMenuSheetButtonItemView *contactItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.Contact")  type:TGMenuSheetButtonTypeDefault action:^
            {
            __strong TGModernConversationController *strongSelf = weakSelf;
            if (strongSelf == nil)
            return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
            return;
            
            [strongController dismissAnimated:true];
            [strongSelf _displayContactPicker];
            }];
        [itemViews addObject:contactItem];
    }
    
    if (!TGIsPad()) {
        NSArray<TGUser *> *inlineBots = [TGDatabaseInstance() _syncCachedRecentInlineBots];
        NSUInteger counter = 0;
        for (TGUser *user in inlineBots) {
            if (user.userName.length == 0)
            continue;
            
            TGMenuSheetButtonItemView *botItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:[@"@" stringByAppendingString:user.userName] type:TGMenuSheetButtonTypeDefault action:^
                {
                __strong TGModernConversationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                return;
                
                __strong TGMenuSheetController *strongController = weakController;
                if (strongController == nil)
                return;
                
                [strongController dismissAnimated:true];
                strongSelf->_inputTextPanel.inputField.userInteractionEnabled = true;
                [strongSelf->_inputTextPanel.inputField setText:[NSString stringWithFormat:@"@%@ ", user.userName]];
                [strongSelf openKeyboard];
                }];
            botItem.overflow = true;
            [itemViews addObject:botItem];
            counter++;
            if (counter == 20) {
                break;
            }
        }
    }
    
    carouselItem.remainingHeight = TGMenuSheetButtonItemViewHeight * (itemViews.count - 1);
    
    TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
    {
    __strong TGModernConversationController *strongSelf = weakSelf;
    if (strongSelf == nil)
    return;
    
    __strong TGMenuSheetController *strongController = weakController;
    if (strongController == nil)
    return;
    
    [strongController dismissAnimated:true];
    }];
    [itemViews addObject:cancelItem];
    
    [controller setItemViews:itemViews];
    
    [self.view endEditing:true];
    [controller presentInViewController:self sourceView:_inputTextPanel.attachButton animated:true];*/
}
