#import <LegacyComponents/TGMediaAvatarMenuMixin.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/PGCamera.h>

#import <LegacyComponents/TGMenuSheetController.h>
#import "TGOverlayFormsheetWindow.h"

#import <LegacyComponents/TGCameraPreviewView.h>
#import "TGAttachmentCameraView.h"
#import "TGAttachmentCarouselItemView.h"

#import <LegacyComponents/TGCameraController.h>
#import <LegacyComponents/TGMediaAssetsController.h>

@interface TGMediaAvatarMenuMixin ()
{
    TGViewController *_parentController;
    bool _hasSearchButton;
    bool _hasDeleteButton;
    bool _hasViewButton;
    bool _personalPhoto;
    id<LegacyComponentsContext> _context;
    bool _saveCapturedMedia;
    bool _saveEditedPhotos;
    bool _signup;
    bool _isVideo;
}
@end

@implementation TGMediaAvatarMenuMixin

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia
{
    return [self initWithContext:context parentController:parentController hasDeleteButton:hasDeleteButton personalPhoto:false saveEditedPhotos:saveEditedPhotos saveCapturedMedia:saveCapturedMedia];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasDeleteButton:(bool)hasDeleteButton personalPhoto:(bool)personalPhoto saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia
{
    return [self initWithContext:context parentController:parentController hasSearchButton:false hasDeleteButton:hasDeleteButton hasViewButton:false personalPhoto:personalPhoto isVideo:false saveEditedPhotos:saveEditedPhotos saveCapturedMedia:saveCapturedMedia signup:false];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController hasSearchButton:(bool)hasSearchButton hasDeleteButton:(bool)hasDeleteButton hasViewButton:(bool)hasViewButton personalPhoto:(bool)personalPhoto isVideo:(bool)isVideo saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia signup:(bool)signup
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _saveCapturedMedia = saveCapturedMedia;
        _saveEditedPhotos = saveEditedPhotos;
        _parentController = parentController;
        _hasSearchButton = hasSearchButton;
        _hasDeleteButton = hasDeleteButton;
        _hasViewButton = hasViewButton;
        _personalPhoto = personalPhoto;
        _isVideo = isVideo;
        _signup = signup;
    }
    return self;
}

- (TGMenuSheetController *)present
{
    [_parentController.view endEditing:true];

    return [self _presentAvatarMenu];
}

- (TGMenuSheetController *)_presentAvatarMenu
{
    __weak TGMediaAvatarMenuMixin *weakSelf = self;
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:self.forceDark];
    controller.dismissesByOutsideTap = true;
    controller.hasSwipeGesture = true;
    controller.didDismiss = ^(bool manual)
    {
        if (!manual)
            return;
        
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.didDismiss != nil)
            strongSelf.didDismiss();
    };
    
    __weak TGMenuSheetController *weakController = controller;
    
    NSMutableArray *itemViews = [[NSMutableArray alloc] init];
    
    TGAttachmentCarouselItemView *carouselItem = [[TGAttachmentCarouselItemView alloc] initWithContext:_context camera:true selfPortrait:_personalPhoto forProfilePhoto:true assetType:_signup ? TGMediaAssetPhotoType : TGMediaAssetAnyType saveEditedPhotos:_saveEditedPhotos allowGrouping:false];
    carouselItem.stickersContext = _stickersContext;
    carouselItem.parentController = _parentController;
    carouselItem.openEditor = true;
    if (_signup) {
        carouselItem.disableStickers = true;
    }
    carouselItem.cameraPressed = ^(TGAttachmentCameraView *cameraView)
    {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongSelf _displayCameraWithView:cameraView menuController:strongController];
    };
    carouselItem.avatarCompletionBlock = ^(UIImage *resultImage)
    {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        if (strongSelf.didFinishWithImage != nil)
            strongSelf.didFinishWithImage(resultImage);
        
        [strongController dismissAnimated:false];
    };
    carouselItem.avatarVideoCompletionBlock = ^(UIImage *image, AVAsset *asset, TGVideoEditAdjustments *adjustments) {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        if (strongSelf.didFinishWithVideo != nil)
            strongSelf.didFinishWithVideo(image, asset, adjustments);
        
        [strongController dismissAnimated:false];
    };
    [itemViews addObject:carouselItem];
    
    TGMenuSheetButtonItemView *galleryItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"ProfilePhoto.OpenGallery") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
    {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissAnimated:true];
        [strongSelf _displayMediaPicker];
    }];
    [itemViews addObject:galleryItem];
    
    if (_hasSearchButton)
    {
        TGMenuSheetButtonItemView *viewItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"ProfilePhoto.SearchWeb") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true];
            if (strongSelf != nil)
                strongSelf.requestSearchController(nil);
        }];
        [itemViews addObject:viewItem];
    }
    
    if (_hasViewButton)
    {
        TGMenuSheetButtonItemView *viewItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:_isVideo ? TGLocalized(@"Settings.ViewVideo") : TGLocalized(@"Settings.ViewPhoto") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true];
            [strongSelf _performView];
        }];
        [itemViews addObject:viewItem];
    }
        
    if (_hasDeleteButton)
    {
        TGMenuSheetButtonItemView *deleteItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:_isVideo ? TGLocalized(@"Settings.RemoveVideo") : TGLocalized(@"GroupInfo.SetGroupPhotoDelete") type:TGMenuSheetButtonTypeDestructive fontSize:20.0 action:^
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true];
            [strongSelf _performDelete];
        }];
        [itemViews addObject:deleteItem];
    }
    
    TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
    {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissAnimated:true manual:true];
    }];
    [itemViews addObject:cancelItem];
    controller.forceFullScreen = true;
    controller.permittedArrowDirections = (UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown);
    [controller setItemViews:itemViews];
    [controller presentInViewController:_parentController sourceView:nil animated:true];
    return controller;
}

- (TGMenuSheetController *)_presentLegacyAvatarMenu
{
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    
    if ([PGCamera cameraAvailable]) {
        [actions addObject:[[LegacyComponentsActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.TakePhoto") action:@"camera"]];
    }
    
    [actions addObject:[[LegacyComponentsActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.ChoosePhoto") action:@"choosePhoto"]];
    
    if (_hasDeleteButton)
    {
        [actions addObject:[[LegacyComponentsActionSheetAction alloc] initWithTitle:TGLocalized(@"GroupInfo.SetGroupPhotoDelete") action:@"delete" type:LegacyComponentsActionSheetActionTypeDestructive]];
    }
    
    [actions addObject:[[LegacyComponentsActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:LegacyComponentsActionSheetActionTypeCancel]];
    
    __weak TGMediaAvatarMenuMixin *weakSelf = self;
    [_context presentActionSheet:actions view:_parentController.view sourceRect:self.sourceRect completion:^(LegacyComponentsActionSheetAction *actionData) {
        __strong TGMediaAvatarMenuMixin *controller = weakSelf;
        if (controller != nil) {
            NSString *action = actionData.action;
            if ([action isEqualToString:@"camera"])
                [controller _displayCameraWithView:nil menuController:nil];
            else if ([action isEqualToString:@"choosePhoto"])
                [controller _displayMediaPicker];
            else if ([action isEqualToString:@"delete"])
                [controller _performDelete];
            else if ([action isEqualToString:@"cancel"] && controller.didDismiss != nil)
                controller.didDismiss();
        }
    }];
    return nil;
}

- (void)_displayCameraWithView:(TGAttachmentCameraView *)cameraView menuController:(TGMenuSheetController *)menuController
{
    [[[LegacyComponentsGlobals provider] accessChecker] checkCameraAuthorizationStatusForIntent:TGCameraAccessIntentDefault completion:^(BOOL allowed) {
        if (!allowed)
            return;
        if ([_context currentlyInSplitView])
            return;
            
        TGCameraController *controller = nil;
        CGSize screenSize = TGScreenSize();
        
        id<LegacyComponentsOverlayWindowManager> windowManager = [_context makeOverlayWindowManager];
        
        if (cameraView.previewView != nil)
            controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:_saveEditedPhotos saveCapturedMedia:_saveCapturedMedia camera:cameraView.previewView.camera previewView:cameraView.previewView intent:_signup ? TGCameraControllerSignupAvatarIntent : TGCameraControllerAvatarIntent];
        else
            controller = [[TGCameraController alloc] initWithContext:[windowManager context] saveEditedPhotos:_saveEditedPhotos saveCapturedMedia:_saveCapturedMedia intent:_signup ? TGCameraControllerSignupAvatarIntent : TGCameraControllerAvatarIntent];
        controller.stickersContext = _stickersContext;
        controller.shouldStoreCapturedAssets = true;
        
        TGCameraControllerWindow *controllerWindow = [[TGCameraControllerWindow alloc] initWithManager:windowManager parentController:_parentController contentController:controller];
        controllerWindow.hidden = false;
        controllerWindow.clipsToBounds = true;
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
            controllerWindow.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
        else
            controllerWindow.frame = [_context fullscreenBounds];
        
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
        
        __weak TGMediaAvatarMenuMixin *weakSelf = self;
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
        
        controller.finishedWithPhoto = ^(__unused TGOverlayController *controller, UIImage *resultImage, __unused NSAttributedString *caption, __unused NSArray *stickers, __unused NSNumber *timer)
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.didFinishWithImage != nil)
                strongSelf.didFinishWithImage(resultImage);
            
            [menuController dismissAnimated:false];
        };
        
        controller.finishedWithVideo = ^(__unused TGOverlayController *controller, NSURL *url, UIImage *previewImage, __unused NSTimeInterval duration, __unused CGSize dimensions, TGVideoEditAdjustments *adjustments, __unused NSAttributedString *caption, __unused NSArray *stickers, __unused NSNumber *timer){
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.didFinishWithVideo != nil)
                strongSelf.didFinishWithVideo(previewImage, [[AVURLAsset alloc] initWithURL:url options:nil], adjustments);
            
            [menuController dismissAnimated:false];
        };
    } alertDismissCompletion:nil];
}

- (void)_displayMediaPicker
{
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkPhotoAuthorizationStatusForIntent:TGPhotoAccessIntentRead alertDismissCompletion:nil])
        return;
    
    __weak TGMediaAvatarMenuMixin *weakSelf = self;
    UIViewController *(^presentBlock)(TGMediaAssetsController *) = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        presentBlock = ^UIViewController * (TGMediaAssetsController *controller)
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            __weak TGMediaAssetsController *weakController = controller;
            controller.dismissalBlock = ^
            {
                __strong TGMediaAssetsController *strongController = weakController;
                if (strongController != nil) {
                    [strongController dismissViewControllerAnimated:false completion:nil];
                }
                
                __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf->_parentController dismissViewControllerAnimated:false completion:nil];
                
                if (strongSelf.didDismiss != nil)
                    strongSelf.didDismiss();
            };
            
            return controller;
        };
    }
    else
    {
        presentBlock = ^UIViewController * (TGMediaAssetsController *controller)
        {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            controller.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
            controller.modalPresentationStyle = UIModalPresentationFormSheet;
            
            TGOverlayFormsheetWindow *formSheetWindow = [[TGOverlayFormsheetWindow alloc] initWithContext:strongSelf->_context parentController:strongSelf->_parentController contentController:controller];
            [formSheetWindow showAnimated:true];
            
            __weak TGNavigationController *weakNavController = controller;
            __weak TGOverlayFormsheetWindow *weakFormSheetWindow = formSheetWindow;
            controller.dismissalBlock = ^
            {
                __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
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
                
                if (strongSelf.didDismiss != nil)
                    strongSelf.didDismiss();
            };
            return nil;
        };
    }
    
    void (^showMediaPicker)(TGMediaAssetGroup *) = ^(TGMediaAssetGroup *group)
    {
        __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        UIViewController *(^initPresent)(id<LegacyComponentsContext>) = ^UIViewController * (id<LegacyComponentsContext> context) {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            TGMediaAssetsController *controller = [TGMediaAssetsController controllerWithContext:context assetGroup:group intent:strongSelf->_signup ? TGMediaAssetsControllerSetSignupProfilePhotoIntent : TGMediaAssetsControllerSetProfilePhotoIntent recipientName:nil saveEditedPhotos:strongSelf->_saveEditedPhotos allowGrouping:false selectionLimit:10];
            __weak TGMediaAssetsController *weakController = controller;
            controller.stickersContext = _stickersContext;
            controller.avatarCompletionBlock = ^(UIImage *resultImage)
            {
                __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf.didFinishWithImage != nil)
                    strongSelf.didFinishWithImage(resultImage);
                
                __strong TGMediaAssetsController *strongController = weakController;
                if (strongController != nil && strongController.dismissalBlock != nil)
                    strongController.dismissalBlock();
            };
            controller.avatarVideoCompletionBlock = ^(UIImage *image, AVAsset *asset, TGVideoEditAdjustments *adjustments) {
                __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf.didFinishWithVideo != nil)
                    strongSelf.didFinishWithVideo(image, asset, adjustments);
                
                __strong TGMediaAssetsController *strongController = weakController;
                if (strongController != nil && strongController.dismissalBlock != nil)
                    strongController.dismissalBlock();
            };
            return presentBlock(controller);
        };
        
        [strongSelf->_parentController presentWithContext:^UIViewController *(id<LegacyComponentsContext> context) {
            __strong TGMediaAvatarMenuMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            return initPresent(context);
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

- (void)_performDelete
{
    if (self.didFinishWithDelete != nil)
        self.didFinishWithDelete();
}

- (void)_performView
{
    if (self.didFinishWithView != nil)
        self.didFinishWithView();
}

@end
