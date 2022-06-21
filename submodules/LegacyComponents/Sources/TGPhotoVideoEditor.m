#import "TGPhotoVideoEditor.h"

#import "TGMediaEditingContext.h"

#import "TGMediaPickerGalleryModel.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"

#import "TGMediaPickerGalleryVideoItemView.h"

#import "LegacyComponentsInternal.h"

@implementation TGPhotoVideoEditor

+ (void)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController image:(UIImage *)image video:(NSURL *)video didFinishWithImage:(void (^)(UIImage *image))didFinishWithImage didFinishWithVideo:(void (^)(UIImage *image, NSURL *url, TGVideoEditAdjustments *adjustments))didFinishWithVideo dismissed:(void (^)(void))dismissed
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    id<TGMediaEditableItem> editableItem;
    if (image != nil) {
        editableItem = image;
    } else if (video != nil) {
        if (![video.path.lowercaseString hasSuffix:@".mp4"]) {
            NSString *tmpPath = NSTemporaryDirectory();
            int64_t fileId = 0;
            arc4random_buf(&fileId, sizeof(fileId));
            NSString *videoMp4FilePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%" PRId64 ".mp4", fileId]];
            [[NSFileManager defaultManager] removeItemAtPath:videoMp4FilePath error:nil];
            [[NSFileManager defaultManager] copyItemAtPath:video.path toPath:videoMp4FilePath error:nil];
            video = [NSURL fileURLWithPath:videoMp4FilePath];
        }
        
        editableItem = [[TGCameraCapturedVideo alloc] initWithURL:video];
    }
    
    void (^present)(UIImage *) = ^(UIImage *screenImage) {
        TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:[windowManager context] item:editableItem intent:TGPhotoEditorControllerAvatarIntent adjustments:nil caption:nil screenImage:screenImage availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent] selectedTab:TGPhotoEditorCropTab];
        //    controller.stickersContext = _stickersContext;
        controller.skipInitialTransition = true;
        controller.dontHideStatusBar = true;
        controller.didFinishEditing = ^(__unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, __unused bool hasChanges)
        {
            if (didFinishWithImage != nil)
                didFinishWithImage(resultImage);
        };
        controller.didFinishEditingVideo = ^(AVAsset *asset, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges) {
            if (didFinishWithVideo != nil) {
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    didFinishWithVideo(resultImage, [(AVURLAsset *)asset URL], adjustments);
                }
            }
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
    };
    
    if (image != nil) {
        present(image);
    } else if (video != nil) {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:[AVURLAsset assetWithURL:video]];
        imageGenerator.appliesPreferredTrackTransform = true;
        imageGenerator.maximumSize = CGSizeMake(1280, 1280);
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        
        [imageGenerator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:kCMTimeZero] ] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
            if (result == AVAssetImageGeneratorSucceeded) {
                UIImage *screenImage = [UIImage imageWithCGImage:image];
                TGDispatchOnMainThread(^{
                    present(screenImage);
                });
            }
        }];
    }
}

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSAttributedString *)caption withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item paint:(bool)paint recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext snapshots:(NSArray *)snapshots immediate:(bool)immediate appeared:(void (^)(void))appeared completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    id<LegacyComponentsContext> windowContext = [windowManager context];
    
    TGMediaEditingContext *editingContext = [[TGMediaEditingContext alloc] init];
    [editingContext setForcedCaption:caption];
    
    TGModernGalleryController *galleryController = [[TGModernGalleryController alloc] initWithContext:windowContext];
    galleryController.adjustsStatusBarVisibility = true;
    galleryController.animateTransition = !immediate;
    galleryController.finishedTransitionIn = ^(id<TGModernGalleryItem> item, TGModernGalleryItemView *itemView) {
        appeared();
    };
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
    
    model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSAttributedString *caption)
    {
        [editingContext setCaption:caption forItem:editableItem];
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
    
    if (paint) {
        [model.interfaceView immediateEditorTransitionIn];
    }
    
    for (UIView *view in snapshots) {
        [galleryController.view addSubview:view];
    }
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:controller contentController:galleryController];
    controllerWindow.hidden = false;
    galleryController.view.clipsToBounds = true;
    
    if (paint) {
        TGDispatchAfter(0.05, dispatch_get_main_queue(), ^{
            [model presentPhotoEditorForItem:galleryItem tab:TGPhotoEditorPaintTab snapshots:snapshots];
        });
    }
}

@end
