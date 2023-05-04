#import "TGPhotoVideoEditor.h"

#import "TGMediaEditingContext.h"

#import "TGMediaPickerGalleryModel.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"

#import "TGMediaPickerGalleryVideoItemView.h"

#import "LegacyComponentsInternal.h"

@implementation TGPhotoVideoEditor

+ (void)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController image:(UIImage *)image video:(NSURL *)video stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext transitionView:(UIView *)transitionView senderName:(NSString *)senderName didFinishWithImage:(void (^)(UIImage *image))didFinishWithImage didFinishWithVideo:(void (^)(UIImage *image, NSURL *url, TGVideoEditAdjustments *adjustments))didFinishWithVideo dismissed:(void (^)(void))dismissed
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    id<TGMediaEditableItem> editableItem;
    if (video != nil) {
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
    } else if (image != nil) {
        editableItem = image;
    }
    
    void (^present)(UIImage *) = ^(UIImage *screenImage) {
        TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:[windowManager context] item:editableItem intent:TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSuggestedAvatarIntent adjustments:nil caption:nil screenImage:screenImage availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent:true] selectedTab:TGPhotoEditorCropTab];
        controller.senderName = senderName;
        controller.stickersContext = stickersContext;
        
        TGMediaAvatarEditorTransition *transition;
        if (transitionView != nil) {
            transition = [[TGMediaAvatarEditorTransition alloc] initWithController:controller fromView:transitionView];
        } else {
            controller.skipInitialTransition = true;
            controller.dontHideStatusBar = true;
        }
        
        controller.didFinishEditing = ^(__unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, __unused bool hasChanges, void(^commit)(void))
        {
            if (didFinishWithImage != nil)
                didFinishWithImage(resultImage);
            
            commit();
        };
        controller.didFinishEditingVideo = ^(AVAsset *asset, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges, void(^commit)(void)) {
            if (didFinishWithVideo != nil) {
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    didFinishWithVideo(resultImage, [(AVURLAsset *)asset URL], adjustments);
                }
                
                commit();
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
        
        if (transitionView != nil) {
            transition.referenceFrame = ^CGRect
            {
                UIView *referenceView = transitionView;
                return [referenceView.superview convertRect:referenceView.frame toView:nil];
            };
            transition.referenceImageSize = ^CGSize
            {
                return image.size;
            };
            transition.referenceScreenImageSignal = ^SSignal *
            {
                return [SSignal single:image];
            };
            [transition presentAnimated:true];
            
            transitionView.alpha = 0.0;
            TGDispatchAfter(0.4, dispatch_get_main_queue(), ^{
                transitionView.alpha = 1.0;
            });
            
            controller.beginCustomTransitionOut = ^(CGRect outReferenceFrame, UIView *repView, void (^completion)(void))
            {
                transition.outReferenceFrame = outReferenceFrame;
                transition.repView = repView;
                
                transitionView.alpha = 0.0;
                [transition dismissAnimated:true completion:^
                {
                    transitionView.alpha = 1.0;
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        if (completion != nil)
                            completion();
                            dismissed();
                    });
                }];
            };
        }
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

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSAttributedString *)caption withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item paint:(bool)paint adjustments:(bool)adjustments recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext fromRect:(CGRect)fromRect mainSnapshot:(UIView *)mainSnapshot snapshots:(NSArray *)snapshots immediate:(bool)immediate appeared:(void (^)(void))appeared completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed
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
    
    model.didFinishRenderingFullSizeImage = ^(id<TGMediaEditableItem> editableItem, UIImage *resultImage)
    {
        [editingContext setFullSizeImage:resultImage forItem:editableItem];
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
    
    if (paint || adjustments) {
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
            [model presentPhotoEditorForItem:galleryItem tab:TGPhotoEditorPaintTab snapshots:snapshots fromRect:fromRect];
        });
    } else if (adjustments) {
        TGDispatchAfter(0.05, dispatch_get_main_queue(), ^{
            [model presentPhotoEditorForItem:galleryItem tab:TGPhotoEditorToolsTab snapshots:snapshots fromRect:fromRect];
        });
    }
}

+ (void)presentEditorWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller withItem:(id<TGMediaEditableItem>)item cropRect:(CGRect)cropRect adjustments:(id<TGMediaEditAdjustments>)adjustments referenceView:(UIView *)referenceView completion:(void (^)(UIImage *, id<TGMediaEditAdjustments>))completion fullSizeCompletion:(void (^)(UIImage *))fullSizeCompletion beginTransitionOut:(void (^)(bool))beginTransitionOut finishTransitionOut:(void (^)())finishTransitionOut;
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    TGMediaEditingContext *editingContext = [[TGMediaEditingContext alloc] init];
    
    UIImage *thumbnailImage;
    
    NSDictionary *toolValues;
    if (adjustments != nil) {
        toolValues = adjustments.toolValues;
    } else {
        toolValues = @{};
    }
    PGPhotoEditorValues *editorValues = [PGPhotoEditorValues editorValuesWithOriginalSize:item.originalSize cropRect:cropRect cropRotation:0.0f cropOrientation:UIImageOrientationUp cropLockedAspectRatio:0.0 cropMirrored:false toolValues:toolValues paintingData:nil sendAsGif:false];
    
    TGPhotoEditorController *editorController = [[TGPhotoEditorController alloc] initWithContext:[windowManager context] item:item intent:TGPhotoEditorControllerWallpaperIntent adjustments:editorValues caption:nil screenImage:thumbnailImage availableTabs:TGPhotoEditorToolsTab selectedTab:TGPhotoEditorToolsTab];
    editorController.editingContext = editingContext;
    editorController.dontHideStatusBar = true;
    editorController.ignoreCropForResult = true;
    
    CGRect fromRect = referenceView.frame;
    editorController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView)
    {
        *referenceFrame = fromRect;
        *parentView = referenceView.superview;
        
        return referenceView;
    };
    
    editorController.beginTransitionOut = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool saving)
    {
        CGRect startFrame = CGRectZero;
        if (referenceFrame != NULL)
        {
            startFrame = *referenceFrame;
            *referenceFrame = fromRect;
            *parentView = referenceView.superview;
        }
        
        if (beginTransitionOut) {
            beginTransitionOut(saving);
        }
        
        return referenceView;
    };
    
    __weak TGPhotoEditorController *weakController = editorController;
    editorController.finishedTransitionOut = ^(bool saved) {
        TGPhotoEditorController *strongGalleryController = weakController;
        if (strongGalleryController != nil && strongGalleryController.overlayWindow == nil)
        {
            TGNavigationController *navigationController = (TGNavigationController *)strongGalleryController.navigationController;
            TGOverlayControllerWindow *window = (TGOverlayControllerWindow *)navigationController.view.window;
            if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                [window dismiss];
        }
        if (finishTransitionOut) {
            finishTransitionOut();
        }
    };
        
    editorController.didFinishRenderingFullSizeImage = ^(UIImage *resultImage)
    {
        fullSizeCompletion(resultImage);
    };
    
    editorController.didFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, __unused bool hasChanges, void(^commit)(void))
    {
        if (!hasChanges)
            return;
        
        __strong TGPhotoEditorController *strongController = weakController;
        if (strongController == nil)
            return;
        
        completion(resultImage, adjustments);
        
    };
    editorController.requestThumbnailImage = ^(id<TGMediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    editorController.requestOriginalScreenSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    
    editorController.requestOriginalFullSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem originalImageSignal:position];
    };
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:controller contentController:editorController];
    controllerWindow.hidden = false;
    controller.view.clipsToBounds = true;
}


@end
