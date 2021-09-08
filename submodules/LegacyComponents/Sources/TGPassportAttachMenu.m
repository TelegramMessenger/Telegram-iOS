#import "TGPassportAttachMenu.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/TGMenuSheetController.h>
#import "TGOverlayFormsheetWindow.h"

#import <LegacyComponents/TGAttachmentCarouselItemView.h>
#import "TGAttachmentCameraView.h"

#import <LegacyComponents/TGCameraController.h>

@interface TGPassportDocumentPickerDelegate : NSObject <UIDocumentPickerDelegate>
{
    TGPassportDocumentPickerDelegate *_self;
}

@property (nonatomic, copy, readonly) void (^completionBlock)(TGPassportDocumentPickerDelegate *, NSArray *);

- (instancetype)initWithCompletionBlock:(void (^)(TGPassportDocumentPickerDelegate *, NSArray *))completionBlock;
- (void)cleanup;

@end

@implementation TGPassportAttachMenu

+ (TGMenuSheetController *)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController menuController:(TGMenuSheetController *)menuController title:(NSString *)title intent:(TGPassportAttachIntent)intent uploadAction:(void (^)(SSignal *, void (^)(void)))uploadAction sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect barButtonItem:(UIBarButtonItem *)barButtonItem
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
    TGAttachmentCarouselItemView *carouselItem = [[TGAttachmentCarouselItemView alloc] initWithContext:context camera:true selfPortrait:intent == TGPassportAttachIntentSelfie forProfilePhoto:false assetType:TGMediaAssetPhotoType saveEditedPhotos:false allowGrouping:false allowSelection:intent == TGPassportAttachIntentMultiple allowEditing:true document:true selectionLimit:10];
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
        
        [TGPassportAttachMenu _displayCameraWithView:cameraView menuController:strongController parentController:strongParentController context:context intent:intent uploadAction:uploadAction];
    };
    carouselItem.sendPressed = ^(TGMediaAsset *currentItem, __unused bool asFiles, __unused bool silentPosting, __unused int32_t scheduleTime, __unused bool fromPicker)
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        __strong TGAttachmentCarouselItemView *strongCarouselItem = weakCarouselItem;

        uploadAction([TGPassportAttachMenu resultSignalForEditingContext:strongCarouselItem.editingContext selectionContext:strongCarouselItem.selectionContext currentItem:(id<TGMediaEditableItem>)currentItem],
        ^{
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController != nil)
                [strongController dismissAnimated:true];
        });
    };
    [itemViews addObject:carouselItem];
    
    TGMenuSheetButtonItemView *galleryItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.ChoosePhoto") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        __strong TGViewController *strongParentController = weakParentController;
        if (strongParentController == nil)
            return;
        
        [strongController dismissAnimated:true];
        [TGPassportAttachMenu _displayMediaPickerWithParentController:strongParentController context:context intent:intent uploadAction:uploadAction];
    }];
    [itemViews addObject:galleryItem];
    
    if (iosMajorVersion() >= 8 && intent != TGPassportAttachIntentSelfie)
    {
        TGMenuSheetButtonItemView *icloudItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.FileICloudDrive") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            __strong TGViewController *strongParentController = weakParentController;
            if (strongParentController == nil)
                return;
            
            [strongController dismissAnimated:true];
            [TGPassportAttachMenu _presentICloudPickerWithParentController:strongParentController uploadAction:uploadAction];
        }];
        [itemViews addObject:icloudItem];
        
        carouselItem.underlyingViews = @[ galleryItem, icloudItem ];
    }
    else
    {
        carouselItem.underlyingViews = @[ galleryItem ];
    }
    carouselItem.remainingHeight = TGMenuSheetButtonItemViewHeight * (itemViews.count - 1);
    
    TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissAnimated:true manual:true];
    }];
    [itemViews addObject:cancelItem];
    controller.permittedArrowDirections = (UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown);
    controller.forceFullScreen = true;

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

+ (void)_displayMediaPickerWithParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context intent:(TGPassportAttachIntent)intent uploadAction:(void (^)(SSignal *, void (^)(void)))uploadAction
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
        __strong TGViewController *strongParentController = weakParentController;
        if (strongParentController == nil) {
            return;
        }
        
        TGMediaAssetsControllerIntent assetsIntent = (intent == TGPassportAttachIntentMultiple) ? TGMediaAssetsControllerPassportMultipleIntent : TGMediaAssetsControllerPassportIntent;
        
        [strongParentController presentWithContext:^UIViewController *(id<LegacyComponentsContext> context) {
            TGMediaAssetsController *controller = [TGMediaAssetsController controllerWithContext:context assetGroup:group intent:assetsIntent recipientName:nil saveEditedPhotos:false allowGrouping:false selectionLimit:10];
            controller.onlyCrop = true;
            __weak TGMediaAssetsController *weakController = controller;
            controller.singleCompletionBlock = ^(id<TGMediaEditableItem> currentItem, TGMediaEditingContext *editingContext) {
                __strong TGMediaAssetsController *strongController = weakController;
                uploadAction([TGPassportAttachMenu resultSignalForEditingContext:editingContext selectionContext:strongController.selectionContext currentItem:(id<TGMediaEditableItem>)currentItem], ^{
                    __strong TGMediaAssetsController *strongController = weakController;
                    if (strongController != nil && strongController.dismissalBlock != nil)
                        strongController.dismissalBlock();
                });
            };
            controller.dismissalBlock = ^{
                __strong TGMediaAssetsController *strongController = weakController;
                if (strongController == nil) {
                    return;
                }
                if (strongController.customDismissSelf != nil) {
                    strongController.customDismissSelf();
                } else {
                    [strongController.presentingViewController dismissViewControllerAnimated:true completion:nil];
                }
            };
            //presentBlock(controller);
            return controller;
        }];
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

+ (void)_displayCameraWithView:(TGAttachmentCameraView *)cameraView menuController:(TGMenuSheetController *)menuController parentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context intent:(TGPassportAttachIntent)intent uploadAction:(void (^)(SSignal *, void (^)(void)))uploadAction
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkCameraAuthorizationStatusForIntent:TGCameraAccessIntentDefault completion:^(BOOL allowed) { } alertDismissCompletion:nil])
        return;
    
    if ([context currentlyInSplitView])
        return;
       
    TGCameraController *controller = nil;
    CGSize screenSize = TGScreenSize();
    
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    
    TGCameraControllerIntent cameraIntent = TGCameraControllerPassportIntent;
    if (intent == TGPassportAttachIntentIdentityCard)
        cameraIntent = TGCameraControllerPassportIdIntent;
    else if (intent == TGPassportAttachIntentMultiple)
        cameraIntent = TGCameraControllerPassportMultipleIntent;
    
    if (cameraView.previewView != nil)
    {
        if (intent == TGPassportAttachIntentSelfie)
            cameraView.previewView.camera.disableResultMirroring = true;
        controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:false saveCapturedMedia:false camera:cameraView.previewView.camera previewView:cameraView.previewView intent:cameraIntent];
    }
    else
    {
        controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:false saveCapturedMedia:false intent:cameraIntent];
    }
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
    controller.finishedWithResults = ^(__unused TGOverlayController *controller, TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem, __unused bool silentPosting, __unused int32_t scheduleTime)
    {
        __strong TGMenuSheetController *strongMenuController = weakMenuController;
        if (strongMenuController == nil)
            return;
        
        [strongMenuController dismissAnimated:false];
        
        uploadAction([TGPassportAttachMenu resultSignalForEditingContext:editingContext selectionContext:selectionContext currentItem:(id<TGMediaEditableItem>)currentItem],^
        {
        });
    };
}

+ (void)_presentICloudPickerWithParentController:(TGViewController *)parentController uploadAction:(void (^)(SSignal *, void (^)(void)))uploadAction
{
    TGPassportDocumentPickerDelegate *delegate = [[TGPassportDocumentPickerDelegate alloc] initWithCompletionBlock:^(TGPassportDocumentPickerDelegate *delegate, NSArray *urls)
    {
        if (urls.count > 0)
        {
            NSURL *url = urls.firstObject;
            uploadAction([SSignal single:url], ^{});
        }
        
        [delegate cleanup];
    }];
    
    UIDocumentPickerViewController *controller = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeOpen];
    controller.view.backgroundColor = [UIColor whiteColor];
    controller.delegate = delegate;
    
    if (TGIsPad())
        controller.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [parentController presentViewController:controller animated:true completion:nil];
}

+ (SSignal *)resultSignalForEditingContext:(TGMediaEditingContext *)editingContext selectionContext:(TGMediaSelectionContext *)selectionContext currentItem:(id<TGMediaEditableItem>)currentItem
{
    SSignal *signal = [SSignal complete];
    NSMutableArray *selectedItems = selectionContext.selectedItems ? [selectionContext.selectedItems mutableCopy] : [[NSMutableArray alloc] init];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    for (id<TGMediaEditableItem> item in selectedItems)
    {
        SSignal *inlineSignal = nil;
        if ([item isKindOfClass:[TGMediaAsset class]])
            inlineSignal = [TGMediaAssetImageSignals imageForAsset:(TGMediaAsset *)item imageType:TGMediaAssetImageTypeScreen size:CGSizeMake(2048, 2048) allowNetworkAccess:false];
        else if ([item isKindOfClass:[TGCameraCapturedPhoto class]])
            inlineSignal = [item originalImageSignal:0.0];

        SSignal *assetSignal = inlineSignal;
        SSignal *imageSignal = assetSignal;
        if (editingContext != nil)
        {
            imageSignal = [[[[[editingContext imageSignalForItem:item withUpdates:true] filter:^bool(id result)
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
        
        signal = [signal then:[[imageSignal catch:^SSignal *(__unused id error)
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
        }]];
    }
    
    return signal;
}

@end


@implementation TGPassportDocumentPickerDelegate

- (instancetype)initWithCompletionBlock:(void (^)(TGPassportDocumentPickerDelegate *, NSArray *))completionBlock
{
    self = [super init];
    if (self != nil)
    {
        _self = self;
        _completionBlock = [completionBlock copy];
    }
    return self;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    if (self.completionBlock != nil)
        self.completionBlock(self, @[url]);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    if (self.completionBlock != nil)
        self.completionBlock(self, urls);
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    if (self.completionBlock != nil)
        self.completionBlock(self, nil);
}

- (void)cleanup
{
    _self = nil;
}

@end
