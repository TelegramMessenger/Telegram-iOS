#import "TGPassportAttachMenu.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/TGMenuSheetController.h>
#import "TGOverlayFormsheetWindow.h"

#import <LegacyComponents/TGAttachmentCarouselItemView.h>
#import "TGAttachmentCameraView.h"

#import <LegacyComponents/TGCameraController.h>

@implementation TGPassportAttachMenu

+ (TGMenuSheetController *)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController menuController:(TGMenuSheetController *)menuController title:(NSString *)title uploadAction:(void (^)(SSignal *))uploadAction sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect barButtonItem:(UIBarButtonItem *)barButtonItem
{
    if (uploadAction == nil)
        return nil;
    
    TGMenuSheetController *controller = nil;
    if (menuController == nil)
    {
        controller = [[TGMenuSheetController alloc] initWithContext:context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.hasSwipeGesture = true;
    }
    else
    {
        controller = menuController;
    }
    controller.permittedArrowDirections = UIPopoverArrowDirectionAny;
    controller.sourceRect = sourceRect;
    controller.barButtonItem = barButtonItem;
    
    NSMutableArray *itemViews = [[NSMutableArray alloc] init];
    
    __weak TGMenuSheetController *weakController = controller;
    __weak TGViewController *weakParentController = parentController;
    TGAttachmentCarouselItemView *carouselItem = [[TGAttachmentCarouselItemView alloc] initWithContext:context camera:true selfPortrait:false forProfilePhoto:false assetType:TGMediaAssetPhotoType saveEditedPhotos:false allowGrouping:false document:true];
    __weak TGAttachmentCarouselItemView *weakCarouselItem = carouselItem;
    carouselItem.onlyCrop = true;
    carouselItem.parentController = parentController;
    carouselItem.cameraPressed = ^(TGAttachmentCameraView *cameraView)
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;

        __strong TGViewController *strongParentController = weakParentController;
        if (strongParentController == nil)
            return;
        
        [TGPassportAttachMenu _displayCameraWithView:cameraView menuController:strongController parentController:strongParentController context:context uploadAction:uploadAction];
    };
    carouselItem.sendPressed = ^(TGMediaAsset *currentItem, __unused bool asFiles)
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        __strong TGAttachmentCarouselItemView *strongCarouselItem = weakCarouselItem;

        [strongController dismissAnimated:true];
        
        uploadAction([TGPassportAttachMenu resultSignalForEditingContext:strongCarouselItem.editingContext currentItem:(id<TGMediaEditableItem>)currentItem]);
    };
    [itemViews addObject:carouselItem];
    
    TGMenuSheetButtonItemView *galleryItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.ChoosePhoto") type:TGMenuSheetButtonTypeDefault action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        __strong TGViewController *strongParentController = weakParentController;
        if (strongParentController == nil)
            return;
        
        [strongController dismissAnimated:true];
        [TGPassportAttachMenu _displayMediaPickerWithParentController:strongParentController context:context];
    }];
    [itemViews addObject:galleryItem];
    
    TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissAnimated:true manual:true];
    }];
    [itemViews addObject:cancelItem];
    controller.permittedArrowDirections = (UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown);

    if (menuController == nil)
    {
        [controller setItemViews:itemViews];
        [controller presentInViewController:parentController sourceView:sourceView animated:true];
    }
    else
    {
        [controller setItemViews:itemViews animated:true];
    }
    
    return controller;
}

+ (void)_displayMediaPickerWithParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentRead alertDismissCompletion:nil])
        return;
    
    __weak TGViewController *weakParentController = parentController;
    void (^presentBlock)(TGMediaAssetsController *) = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        presentBlock = ^(TGMediaAssetsController *controller)
        {
            __strong TGViewController *strongParentController = weakParentController;
            if (strongParentController == nil)
                return;
            
            controller.dismissalBlock = ^
            {
                __strong TGViewController *strongParentController = weakParentController;
                if (strongParentController == nil)
                    return;
                
                [strongParentController dismissViewControllerAnimated:true completion:nil];
                
                //if (strongSelf.didDismiss != nil)
                //    strongSelf.didDismiss();
            };
            
            [strongParentController presentViewController:controller animated:true completion:nil];
        };
    }
    else
    {
        presentBlock = ^(TGMediaAssetsController *controller)
        {
            __strong TGViewController *strongParentController = weakParentController;
            if (strongParentController == nil)
                return;
            
            controller.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
            controller.modalPresentationStyle = UIModalPresentationFormSheet;
            
            TGOverlayFormsheetWindow *formSheetWindow = [[TGOverlayFormsheetWindow alloc] initWithContext:context parentController:strongParentController contentController:controller];
            [formSheetWindow showAnimated:true];
            
            __weak TGNavigationController *weakNavController = controller;
            __weak TGOverlayFormsheetWindow *weakFormSheetWindow = formSheetWindow;
            controller.dismissalBlock = ^
            {
                __strong TGOverlayFormsheetWindow *strongFormSheetWindow = weakFormSheetWindow;
                if (strongFormSheetWindow == nil)
                    return;
                
                __strong TGNavigationController *strongNavController = weakNavController;
                if (strongNavController != nil)
                {
                    if (strongNavController.presentingViewController != nil)
                        [strongNavController.presentingViewController dismissViewControllerAnimated:true completion:nil];
                    else
                        [strongFormSheetWindow dismissAnimated:true];
                }
                
                //if (strongSelf.didDismiss != nil)
                //    strongSelf.didDismiss();
            };
        };
    }
    
    void (^showMediaPicker)(TGMediaAssetGroup *) = ^(TGMediaAssetGroup *group)
    {
        TGMediaAssetsController *controller = [TGMediaAssetsController controllerWithContext:context assetGroup:group intent:TGMediaAssetsControllerPassportIntent recipientName:nil saveEditedPhotos:false allowGrouping:false];
        controller.onlyCrop = true;
        __weak TGMediaAssetsController *weakController = controller;
//        controller.avatarCompletionBlock = ^(UIImage *resultImage)
//        {
//            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
//            if (strongSelf == nil)
//                return;
//
//            if (strongSelf.didFinishWithImage != nil)
//                strongSelf.didFinishWithImage(resultImage);
//
//            __strong TGMediaAssetsController *strongController = weakController;
//            if (strongController != nil && strongController.dismissalBlock != nil)
//                strongController.dismissalBlock();
//        };
        presentBlock(controller);
    };
    
    if ([TGMediaAssetsLibrary authorizationStatus] == TGMediaLibraryAuthorizationStatusNotDetermined)
    {
        [TGMediaAssetsLibrary requestAuthorizationForAssetType:TGMediaAssetAnyType completion:^(__unused TGMediaLibraryAuthorizationStatus status, TGMediaAssetGroup *cameraRollGroup)
        {
            if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentRead alertDismissCompletion:nil])
                return;
             
            showMediaPicker(cameraRollGroup);
        }];
    }
    else
    {
        showMediaPicker(nil);
    }
}

+ (void)_displayCameraWithView:(TGAttachmentCameraView *)cameraView menuController:(TGMenuSheetController *)menuController parentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context uploadAction:(void (^)(SSignal *))uploadAction
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkCameraAuthorizationStatusForIntent:TGCameraAccessIntentDefault alertDismissCompletion:nil])
        return;
    
    if ([context currentlyInSplitView])
        return;
    
    if ([TGCameraController useLegacyCamera])
    {
        return;
    }
    
    TGCameraController *controller = nil;
    CGSize screenSize = TGScreenSize();
    
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    if (cameraView.previewView != nil)
        controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:false saveCapturedMedia:false camera:cameraView.previewView.camera previewView:cameraView.previewView intent:TGCameraControllerPassportIntent];
    else
        controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:false saveCapturedMedia:false intent:TGCameraControllerPassportIntent];
    
    controller.shouldStoreCapturedAssets = false;
    
    TGCameraControllerWindow *controllerWindow = [[TGCameraControllerWindow alloc] initWithManager:windowManager parentController:parentController contentController:controller];
    controllerWindow.hidden = false;
    controllerWindow.clipsToBounds = true;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
        controllerWindow.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
    else
        controllerWindow.frame = [context fullscreenBounds];
    
    bool standalone = true;
    CGRect startFrame = CGRectMake(0, screenSize.height, screenSize.width, screenSize.height);
    if (cameraView != nil)
    {
        standalone = false;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            startFrame = CGRectZero;
        else
            startFrame = [controller.view convertRect:cameraView.previewView.frame fromView:cameraView];
    }
    
    [cameraView detachPreviewView];
    [controller beginTransitionInFromRect:startFrame];
    
    __weak TGCameraController *weakCameraController = controller;
    __weak TGAttachmentCameraView *weakCameraView = cameraView;
    __weak TGMenuSheetController *weakMenuController = menuController;
    
    controller.beginTransitionOut = ^CGRect
    {
        __strong TGCameraController *strongCameraController = weakCameraController;
        if (strongCameraController == nil)
            return CGRectZero;
        
        __strong TGAttachmentCameraView *strongCameraView = weakCameraView;
        if (strongCameraView != nil)
        {
            [strongCameraView willAttachPreviewView];
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
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
    controller.finishedWithResults = ^(__unused TGOverlayController *controller, TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem)
    {
        __strong TGMenuSheetController *strongMenuController = weakMenuController;
        if (strongMenuController == nil)
            return;
        
        [strongMenuController dismissAnimated:false];
        
        uploadAction([TGPassportAttachMenu resultSignalForEditingContext:editingContext currentItem:(id<TGMediaEditableItem>)currentItem]);
    };
}


+ (SSignal *)resultSignalForEditingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaEditableItem>)currentItem
{
    SSignal *inlineSignal = nil;
    if ([currentItem isKindOfClass:[TGMediaAsset class]])
        inlineSignal = [TGMediaAssetImageSignals imageForAsset:(TGMediaAsset *)currentItem imageType:TGMediaAssetImageTypeScreen size:CGSizeMake(1280, 1280) allowNetworkAccess:false];
    else if ([currentItem isKindOfClass:[TGCameraCapturedPhoto class]])
        inlineSignal = [currentItem screenImageSignal:0.0];

    SSignal *assetSignal = inlineSignal;
    SSignal *imageSignal = assetSignal;
    if (editingContext != nil)
    {
        imageSignal = [[[[[editingContext imageSignalForItem:currentItem withUpdates:true] filter:^bool(id result)
        {
            return result == nil || ([result isKindOfClass:[UIImage class]] && !((UIImage *)result).degraded);
        }] take:1] mapToSignal:^SSignal *(id result)
        {
            if (result == nil)
            {
                return [SSignal fail:nil];
            }
            else if ([result isKindOfClass:[UIImage class]])
            {
                UIImage *image = (UIImage *)result;
                image.edited = true;
                return [SSignal single:image];
            }
            
            return [SSignal complete];
        }] onCompletion:^
        {
            __strong TGMediaEditingContext *strongEditingContext = editingContext;
            [strongEditingContext description];
        }];
    }
    
    return [[imageSignal catch:^SSignal *(__unused id error)
    {
        return inlineSignal;
    }] map:^id(UIImage *image)
    {
        CGFloat maxSide = 2048.0f;
        CGSize imageSize = TGFitSize(image.size, CGSizeMake(maxSide, maxSide));
        UIImage *scaledImage = MAX(image.size.width, image.size.height) > maxSide ? TGScaleImageToPixelSize(image, imageSize) : image;
        
        CGFloat thumbnailSide = 60.0f * TGScreenScaling();
        CGSize thumbnailSize = TGFitSize(scaledImage.size, CGSizeMake(thumbnailSide, thumbnailSide));
        UIImage *thumbnailImage = TGScaleImageToPixelSize(scaledImage, thumbnailSize);
        
        return @{ @"image": scaledImage, @"thumbnail": thumbnailImage };
    }];
}

@end
