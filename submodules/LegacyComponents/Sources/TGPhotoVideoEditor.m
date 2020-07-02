#import "TGPhotoVideoEditor.h"

#import "TGMediaEditingContext.h"

#import "TGMediaPickerGalleryModel.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"

#import "TGMediaPickerGalleryVideoItemView.h"

@implementation TGPhotoVideoEditor

+ (void)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController screenImage:(UIImage *)screenImage image:(UIImage *)image video:(NSURL *)video didFinishWithImage:(void (^)(UIImage *image))didFinishWithImage didFinishWithVideo:(void (^)(UIImage *image, NSURL *url, TGVideoEditAdjustments *adjustments))didFinishWithVideo dismissed:(void (^)(void))dismissed
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    id<TGMediaEditableItem> editableItem;
    if (image != nil) {
        editableItem = image;
    } else if (video != nil) {
        editableItem = [[TGCameraCapturedVideo alloc] initWithURL:video];
    }
    
    TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:[windowManager context] item:editableItem intent:TGPhotoEditorControllerAvatarIntent adjustments:nil caption:nil screenImage:screenImage availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent] selectedTab:TGPhotoEditorCropTab];
//    controller.stickersContext = _stickersContext;
    controller.skipInitialTransition = true;
    controller.dontHideStatusBar = true;
    controller.didFinishEditing = ^(__unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, __unused bool hasChanges)
    {
        if (didFinishWithImage != nil)
            didFinishWithImage(resultImage);
    };
    controller.didFinishEditingVideo = ^(NSURL *url, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges) {
        if (didFinishWithVideo != nil)
            didFinishWithVideo(resultImage, url, adjustments);
    };
    controller.requestThumbnailImage = ^(id<TGMediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    controller.requestOriginalScreenSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    controller.requestOriginalFullSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        if (editableItem.isVideo) {
            if ([editableItem isKindOfClass:[TGMediaAsset class]]) {
                return [TGMediaAssetImageSignals avAssetForVideoAsset:(TGMediaAsset *)editableItem allowNetworkAccess:true];
            } else if ([editableItem isKindOfClass:[TGCameraCapturedVideo class]]) {
                return ((TGCameraCapturedVideo *)editableItem).avAsset;
            } else {
                return [editableItem originalImageSignal:position];
            }
        } else {
            return [editableItem originalImageSignal:position];
        }
    };
    controller.onDismiss = ^{
        dismissed();
    };
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:controller contentController:controller];
    controllerWindow.hidden = false;
    controller.view.clipsToBounds = true;
}

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSString *)caption entities:(NSArray *)entities withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    id<LegacyComponentsContext> windowContext = [windowManager context];
    
    TGMediaEditingContext *editingContext = [[TGMediaEditingContext alloc] init];
    [editingContext setForcedCaption:caption entities:entities];
    
    TGModernGalleryController *galleryController = [[TGModernGalleryController alloc] initWithContext:windowContext];
    galleryController.adjustsStatusBarVisibility = true;
    //galleryController.hasFadeOutTransition = true;
    
    id<TGModernGalleryEditableItem> galleryItem = nil;
    if (item.isVideo)
        galleryItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:item];
    else
        galleryItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:item];
    galleryItem.editingContext = editingContext;
    galleryItem.stickersContext = stickersContext;
    
    TGMediaPickerGalleryModel *model = [[TGMediaPickerGalleryModel alloc] initWithContext:windowContext items:@[galleryItem] focusItem:galleryItem selectionContext:nil editingContext:editingContext hasCaptions:true allowCaptionEntities:true hasTimer:false onlyCrop:false inhibitDocumentCaptions:false hasSelectionPanel:false hasCamera:false recipientName:recipientName];
    model.controller = galleryController;
    model.stickersContext = stickersContext;
    //model.suggestionContext = self.suggestionContext;
    
    model.willFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, id<TGMediaEditAdjustments> adjustments, id representation, bool hasChanges)
    {
        if (hasChanges)
        {
            [editingContext setAdjustments:adjustments forItem:editableItem];
            [editingContext setTemporaryRep:representation forItem:editableItem];
        }
    };
    
    model.didFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, __unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage)
    {
        [editingContext setImage:resultImage thumbnailImage:thumbnailImage forItem:editableItem synchronous:false];
    };
    
    model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSString *caption, NSArray *entities)
    {
        [editingContext setCaption:caption entities:entities forItem:editableItem];
    };
    
    model.interfaceView.hasSwipeGesture = false;
    galleryController.model = model;
    
    __weak TGModernGalleryController *weakGalleryController = galleryController;
    
    [model.interfaceView updateSelectionInterface:1 counterVisible:false animated:false];
    model.interfaceView.thumbnailSignalForItem = ^SSignal *(id item)
    {
        return nil;
    };
    model.interfaceView.donePressed = ^(TGMediaPickerGalleryItem *item)
    {
        __strong TGModernGalleryController *strongController = weakGalleryController;
        if (strongController == nil)
            return;
        
        if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
        {
            TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
            [itemView stop];
            [itemView setPlayButtonHidden:true animated:true];
        }
        
        if (completion != nil)
            completion(item.asset, editingContext);
        
        [strongController dismissWhenReadyAnimated:true];
        
        /*[UIView animateWithDuration:0.3f delay:0.0f options:(7 << 16) animations:^
        {
            strongController.view.frame = CGRectOffset(strongController.view.frame, 0, strongController.view.frame.size.height);
        } completion:^(__unused BOOL finished)
        {
            [strongController dismiss];
        }];*/
    };
    
    galleryController.beginTransitionIn = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
    {
        return nil;
    };
    
    galleryController.beginTransitionOut = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
    {
        return nil;
    };
    
    galleryController.completedTransitionOut = ^
    {
        TGModernGalleryController *strongGalleryController = weakGalleryController;
        if (strongGalleryController != nil && strongGalleryController.overlayWindow == nil)
        {
            TGNavigationController *navigationController = (TGNavigationController *)strongGalleryController.navigationController;
            TGOverlayControllerWindow *window = (TGOverlayControllerWindow *)navigationController.view.window;
            if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                [window dismiss];
        }
        if (dismissed) {
            dismissed();
        }
    };
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:controller contentController:galleryController];
    controllerWindow.hidden = false;
    galleryController.view.clipsToBounds = true;
}

@end
