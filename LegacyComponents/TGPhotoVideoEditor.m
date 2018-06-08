#import "TGPhotoVideoEditor.h"

#import "TGMediaEditingContext.h"b

#import "TGMediaPickerGalleryModel.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"

#import "TGMediaPickerGalleryVideoItemView.h"

@implementation TGPhotoVideoEditor

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item recipientName:(NSString *)recipientName completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion
{
    id<LegacyComponentsOverlayWindowManager> windowManager = [context makeOverlayWindowManager];
    id<LegacyComponentsContext> windowContext = [windowManager context];
    
    TGMediaEditingContext *editingContext = [[TGMediaEditingContext alloc] init];
    
    TGModernGalleryController *galleryController = [[TGModernGalleryController alloc] initWithContext:windowContext];
    galleryController.adjustsStatusBarVisibility = true;
    //galleryController.hasFadeOutTransition = true;
    
    id<TGModernGalleryEditableItem> galleryItem = nil;
    if (item.isVideo)
        galleryItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:item];
    else
        galleryItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:item];
    galleryItem.editingContext = editingContext;
    
    TGMediaPickerGalleryModel *model = [[TGMediaPickerGalleryModel alloc] initWithContext:windowContext items:@[galleryItem] focusItem:galleryItem selectionContext:nil editingContext:editingContext hasCaptions:false allowCaptionEntities:false hasTimer:false onlyCrop:false inhibitDocumentCaptions:false hasSelectionPanel:false hasCamera:false recipientName:recipientName];
    model.controller = galleryController;
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
    __weak TGMediaPickerGalleryModel *weakModel = model;
    
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
        
        [UIView animateWithDuration:0.3f delay:0.0f options:(7 << 16) animations:^
        {
            strongController.view.frame = CGRectOffset(strongController.view.frame, 0, strongController.view.frame.size.height);
        } completion:^(__unused BOOL finished)
        {
            [strongController dismiss];
        }];
    };
    
//    CGSize snapshotSize = TGScaleToFill(CGSizeMake(480, 640), CGSizeMake(self.view.frame.size.width, self.view.frame.size.width));
//    UIView *snapshotView = [_previewView snapshotViewAfterScreenUpdates:false];
//    snapshotView.contentMode = UIViewContentModeScaleAspectFill;
//    snapshotView.frame = CGRectMake(_previewView.center.x - snapshotSize.width / 2, _previewView.center.y - snapshotSize.height / 2, snapshotSize.width, snapshotSize.height);
//    snapshotView.hidden = true;
//    [_previewView.superview insertSubview:snapshotView aboveSubview:_previewView];
    
    galleryController.beginTransitionIn = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
    {
        TGModernGalleryController *strongGalleryController = weakGalleryController;
        strongGalleryController.view.alpha = 0.0f;
        [UIView animateWithDuration:0.3f animations:^
        {
            strongGalleryController.view.alpha = 1.0f;
        }];
            //return snapshotView;
        return nil;
    };
    
    galleryController.beginTransitionOut = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
    {
//        __strong TGCameraController *strongSelf = weakSelf;
//        if (strongSelf != nil)
//        {
            TGMediaPickerGalleryModel *strongModel = weakModel;
            if (strongModel == nil)
                return nil;
        
//            [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveLinear animations:^
//             {
//                 strongSelf->_interfaceView.alpha = 1.0f;
//             } completion:nil];
            
//            return snapshotView;
//        }
        return nil;
    };
    
    galleryController.completedTransitionOut = ^
    {
        //[snapshotView removeFromSuperview];
        
        TGModernGalleryController *strongGalleryController = weakGalleryController;
        if (strongGalleryController != nil && strongGalleryController.overlayWindow == nil)
        {
            TGNavigationController *navigationController = (TGNavigationController *)strongGalleryController.navigationController;
            TGOverlayControllerWindow *window = (TGOverlayControllerWindow *)navigationController.view.window;
            if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                [window dismiss];
        }
    };
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:controller contentController:galleryController];
    controllerWindow.hidden = false;
    //controllerWindow.windowLevel = self.view.window.windowLevel + 0.0001f;
    galleryController.view.clipsToBounds = true;
}

@end
