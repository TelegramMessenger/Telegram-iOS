#import "TGClipboardGalleryMixin.h"

#import <LegacyComponents/LegacyComponents.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGModernGalleryController.h>
#import "TGClipboardGalleryPhotoItem.h"
#import "TGClipboardGalleryModel.h"

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetMoment.h>

#import "TGMediaPickerSendActionSheetController.h"

@interface TGClipboardGalleryMixin ()
{
    TGMediaEditingContext *_editingContext;
    bool _asFile;
    
    __weak TGViewController *_parentController;
    __weak TGModernGalleryController *_galleryController;
    TGModernGalleryController *_strongGalleryController;
    
    NSUInteger _itemsLimit;
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, weak, readonly) TGClipboardGalleryModel *galleryModel;

@end

@implementation TGClipboardGalleryMixin

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image images:(NSArray *)images parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder recipientName:(NSString *)recipientName
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _parentController = parentController;
        _editingContext = editingContext;
        
        __weak TGClipboardGalleryMixin *weakSelf = self;
        
        TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:_context];
        _galleryController = modernGallery;
        _strongGalleryController = modernGallery;
        modernGallery.isImportant = true;
        
        __block NSUInteger focusIndex = 0;
        [images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * _Nonnull stop)
        {
            if (obj == image)
            {
                focusIndex = idx;
                *stop = true;
            }
        }];
        
        TGClipboardGalleryModel *model = [[TGClipboardGalleryModel alloc] initWithContext:_context images:images focusIndex:focusIndex selectionContext:selectionContext editingContext:editingContext stickersContext:stickersContext hasCaptions:hasCaptions hasTimer:hasTimer hasSelectionPanel:false recipientName:recipientName];
        _galleryModel = model;
        model.controller = modernGallery;
        model.willFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, id<TGMediaEditAdjustments> adjustments, id representation, bool hasChanges)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (hasChanges)
            {
                [editingContext setAdjustments:adjustments forItem:editableItem];
                [editingContext setTemporaryRep:representation forItem:editableItem];
            }
            
            if (selectionContext != nil && adjustments != nil && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
                [selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
        };
        
        model.didFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, __unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage)
        {
            [editingContext setImage:resultImage thumbnailImage:thumbnailImage forItem:editableItem synchronous:false];
        };
        
        model.didFinishRenderingFullSizeImage = ^(id<TGMediaEditableItem> editableItem, UIImage *resultImage)
        {
            [editingContext setFullSizeImage:resultImage forItem:editableItem];
        };
        
        model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSAttributedString *caption)
        {
            [editingContext setCaption:caption forItem:editableItem];
            
            if (selectionContext != nil && caption.length > 0 && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
                [selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
        };
        
        [model.interfaceView updateSelectionInterface:selectionContext.count counterVisible:(selectionContext.count > 0) animated:false];
        model.interfaceView.donePressed = ^(id<TGModernGalleryItem> item)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_galleryModel.dismiss(true, false);
            
            if (strongSelf.completeWithItem != nil)
                strongSelf.completeWithItem((TGClipboardGalleryPhotoItem *)item, false, 0);
        };
        
        model.interfaceView.doneLongPressed = ^(id<TGModernGalleryItem> item) {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil || !(hasSilentPosting || hasSchedule))
                return;
            
            if (iosMajorVersion() >= 10) {
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [generator impactOccurred];
            }
            
            bool effectiveHasSchedule = hasSchedule;
            for (id item in strongSelf->_galleryModel.selectionContext.selectedItems)
            {
                if ([item isKindOfClass:[TGMediaAsset class]])
                {
                    if ([[strongSelf->_editingContext timerForItem:item] integerValue] > 0)
                    {
                        effectiveHasSchedule = false;
                        break;
                    }
                }
            }
            
            TGMediaPickerSendActionSheetController *controller = [[TGMediaPickerSendActionSheetController alloc] initWithContext:strongSelf->_context isDark:true sendButtonFrame:strongSelf.galleryModel.interfaceView.doneButtonFrame canSendSilently:hasSilentPosting canSchedule:effectiveHasSchedule reminder:reminder hasTimer:hasTimer];
            controller.send = ^{
                __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_galleryModel.dismiss(true, false);
                
                if (strongSelf.completeWithItem != nil)
                    strongSelf.completeWithItem((TGClipboardGalleryPhotoItem *)item, false, 0);
            };
            controller.sendSilently = ^{
                __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_galleryModel.dismiss(true, false);
                
                if (strongSelf.completeWithItem != nil)
                    strongSelf.completeWithItem((TGClipboardGalleryPhotoItem *)item, true, 0);
            };
            controller.schedule = ^{
                __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentScheduleController(^(int32_t time) {
                    __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_galleryModel.dismiss(true, false);
                    
                    if (strongSelf.completeWithItem != nil)
                        strongSelf.completeWithItem((TGClipboardGalleryPhotoItem *)item, false, time);
                });
            };
            controller.sendWithTimer = ^{
                __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentTimerController(^(int32_t time) {
                    __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_galleryModel.dismiss(true, false);
                    
                    TGMediaEditingContext *editingContext = strongSelf->_editingContext;
                    NSMutableArray *items = [strongSelf->_galleryModel.selectionContext.selectedItems mutableCopy];
                    [items addObject:((TGClipboardGalleryPhotoItem *)item).image];
                    
                    for (id<TGMediaEditableItem> editableItem in items) {
                        [editingContext setTimer:@(time) forItem:editableItem];
                    }
                    
                    if (strongSelf.completeWithItem != nil)
                        strongSelf.completeWithItem((TGClipboardGalleryPhotoItem *)item, false, 0);
                });
            };
            
            TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:[strongSelf->_context makeOverlayWindowManager] parentController:strongSelf->_parentController contentController:controller];
            controllerWindow.hidden = false;
        };
        
        modernGallery.model = model;
        modernGallery.itemFocused = ^(id<TGModernGalleryItem> item)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.itemFocused != nil)
                strongSelf.itemFocused((TGClipboardGalleryPhotoItem *)item);
        };
        
        modernGallery.beginTransitionIn = ^UIView *(id<TGModernGalleryItem> item, TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf.willTransitionIn != nil)
                strongSelf.willTransitionIn();
            
            if (strongSelf.referenceViewForItem != nil)
                return strongSelf.referenceViewForItem((TGClipboardGalleryPhotoItem *)item);
            
            return nil;
        };
        
        modernGallery.finishedTransitionIn = ^(__unused id<TGModernGalleryItem> item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_galleryModel.interfaceView setSelectedItemsModel:strongSelf->_galleryModel.selectedItemsModel];
        };
        
        modernGallery.beginTransitionOut = ^UIView *(id<TGModernGalleryItem> item, TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf.willTransitionOut != nil)
                    strongSelf.willTransitionOut();
                
                if (strongSelf.referenceViewForItem != nil)
                    return strongSelf.referenceViewForItem((TGClipboardGalleryPhotoItem *)item);
            }
            return nil;
        };
        
        modernGallery.completedTransitionOut = ^
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.didTransitionOut != nil)
                strongSelf.didTransitionOut();
        };
    }
    return self;
}

- (void)present
{
    _galleryModel.editorOpened = self.editorOpened;
    _galleryModel.editorClosed = self.editorClosed;
    
    [_galleryController setPreviewMode:false];
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:[_context makeOverlayWindowManager] parentController:_parentController contentController:_galleryController];
    controllerWindow.hidden = false;
    _galleryController.view.clipsToBounds = true;
    
    _strongGalleryController = nil;
}

- (UIViewController *)galleryController
{
    return _galleryController;
}

@end
