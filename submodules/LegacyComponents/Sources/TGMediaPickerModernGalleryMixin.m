#import "TGMediaPickerModernGalleryMixin.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGModernGalleryController.h>
#import "TGMediaPickerGalleryItem.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"
#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGMediaPickerSendActionSheetController.h"

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetMoment.h>

@interface TGMediaPickerModernGalleryMixin ()
{
    TGMediaEditingContext *_editingContext;
    id<TGPhotoPaintStickersContext> _stickersContext;
    bool _asFile;
    
    __weak TGViewController *_parentController;
    __weak TGModernGalleryController *_galleryController;
    TGModernGalleryController *_strongGalleryController;
    
    NSUInteger _itemsLimit;
    
    id<LegacyComponentsContext> _context;
    
    id<LegacyComponentsOverlayWindowManager> _windowManager;
}
@end

@implementation TGMediaPickerModernGalleryMixin

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id)item fetchResult:(TGMediaAssetFetchResult *)fetchResult parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions inhibitMute:(bool)inhibitMute asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit recipientName:(NSString *)recipientName hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext
{
    return [self initWithContext:context item:item fetchResult:fetchResult momentList:nil parentController:parentController thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext hasCaptions:hasCaptions allowCaptionEntities:allowCaptionEntities hasTimer:hasTimer onlyCrop:onlyCrop inhibitDocumentCaptions:inhibitDocumentCaptions inhibitMute:inhibitMute asFile:asFile itemsLimit:itemsLimit recipientName:recipientName hasSilentPosting:hasSilentPosting hasSchedule:hasSchedule reminder:reminder stickersContext:stickersContext];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id)item momentList:(TGMediaAssetMomentList *)momentList parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions inhibitMute:(bool)inhibitMute asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext
{
    return [self initWithContext:context item:item fetchResult:nil momentList:momentList parentController:parentController thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext hasCaptions:hasCaptions allowCaptionEntities:allowCaptionEntities hasTimer:hasTimer onlyCrop:onlyCrop inhibitDocumentCaptions:inhibitDocumentCaptions inhibitMute:inhibitMute asFile:asFile itemsLimit:itemsLimit recipientName:nil hasSilentPosting:hasSilentPosting hasSchedule:hasSchedule reminder:reminder stickersContext:stickersContext];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id)item fetchResult:(TGMediaAssetFetchResult *)fetchResult momentList:(TGMediaAssetMomentList *)momentList parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions inhibitMute:(bool)inhibitMute asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit recipientName:(NSString *)recipientName hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _parentController = parentController;
        _editingContext = asFile ? nil : editingContext;
        _stickersContext = asFile? nil : stickersContext;
        _asFile = asFile;
        _itemsLimit = itemsLimit;
        
        __weak TGMediaPickerModernGalleryMixin *weakSelf = self;
        
        _windowManager = [_context makeOverlayWindowManager];
        
        TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:[_windowManager context]];
        _galleryController = modernGallery;
        _strongGalleryController = modernGallery;
        modernGallery.isImportant = true;
        
        __block id<TGModernGalleryItem> focusItem = nil;
        void (^enumerationBlock)(TGMediaPickerGalleryItem *) = ^(TGMediaPickerGalleryItem *galleryItem)
        {
            if (focusItem == nil) {
                if (([item isKindOfClass:[TGMediaAsset class]] && [galleryItem.asset.uniqueIdentifier isEqual:((TGMediaAsset *)item).uniqueIdentifier]) || [galleryItem.asset isEqual:item]) {
                    focusItem = galleryItem;
                    galleryItem.immediateThumbnailImage = thumbnailImage;
                }
            }
        };
        
        NSArray *galleryItems = [self prepareGalleryItemsForFetchResult:fetchResult selectionContext:selectionContext editingContext:editingContext stickersContext:stickersContext asFile:asFile enumerationBlock:enumerationBlock];
        
        TGMediaPickerGalleryModel *model = [[TGMediaPickerGalleryModel alloc] initWithContext:[_windowManager context] items:galleryItems focusItem:focusItem selectionContext:selectionContext editingContext:editingContext hasCaptions:hasCaptions allowCaptionEntities:allowCaptionEntities hasTimer:hasTimer onlyCrop:onlyCrop inhibitDocumentCaptions:inhibitDocumentCaptions hasSelectionPanel:true hasCamera:false recipientName:recipientName];
        _galleryModel = model;
        model.stickersContext = stickersContext;
        model.inhibitMute = inhibitMute;
        model.controller = modernGallery;
        model.willFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, id<TGMediaEditAdjustments> adjustments, id representation, bool hasChanges)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
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
        
        model.requestAdjustments = ^id<TGMediaEditAdjustments> (id<TGMediaEditableItem> editableItem)
        {
            return [editingContext adjustmentsForItem:editableItem];
        };
        
        model.interfaceView.usesSimpleLayout = asFile;
        [model.interfaceView updateSelectionInterface:selectionContext.count counterVisible:(selectionContext.count > 0) animated:false];
        model.interfaceView.donePressed = ^(TGMediaPickerGalleryItem *item)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_galleryModel.dismiss(true, false);
            
            if (strongSelf.completeWithItem != nil)
                strongSelf.completeWithItem(item, false, 0);
        };
        
        model.interfaceView.doneLongPressed = ^(TGMediaPickerGalleryItem *item) {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
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
                __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_galleryModel.dismiss(true, false);
                
                if (strongSelf.completeWithItem != nil)
                    strongSelf.completeWithItem(item, false, 0);
            };
            controller.sendSilently = ^{
                __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf->_galleryModel.dismiss(true, false);
                
                if (strongSelf.completeWithItem != nil)
                    strongSelf.completeWithItem(item, true, 0);
            };
            controller.schedule = ^{
                __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentScheduleController(true, ^(int32_t time) {
                    __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_galleryModel.dismiss(true, false);
                    
                    if (strongSelf.completeWithItem != nil)
                        strongSelf.completeWithItem(item, false, time);
                });
            };
            controller.sendWithTimer = ^{
                __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentTimerController(^(int32_t time) {
                    __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_galleryModel.dismiss(true, false);
                    
                    TGMediaEditingContext *editingContext = strongSelf->_editingContext;
                    NSMutableArray *items = [strongSelf->_galleryModel.selectionContext.selectedItems mutableCopy];
                    [items addObject:item.asset];
                    
                    for (id<TGMediaEditableItem> editableItem in items) {
                        [editingContext setTimer:@(time) forItem:editableItem];
                    }
                    
                    if (strongSelf.completeWithItem != nil)
                        strongSelf.completeWithItem(item, false, 0);
                });
            };
            
            TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:[strongSelf->_context makeOverlayWindowManager] parentController:strongSelf->_parentController contentController:controller];
            controllerWindow.hidden = false;
        };
        
        modernGallery.model = model;
        modernGallery.itemFocused = ^(TGMediaPickerGalleryItem *item)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.itemFocused != nil)
                strongSelf.itemFocused(item);
        };

        modernGallery.beginTransitionIn = ^UIView *(TGMediaPickerGalleryItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf.willTransitionIn != nil)
                strongSelf.willTransitionIn();
            
            if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
                [itemView setIsCurrent:true];
            
            if (strongSelf.referenceViewForItem != nil)
                return strongSelf.referenceViewForItem(item);
            
            return nil;
        };
        
        modernGallery.finishedTransitionIn = ^(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_galleryModel.interfaceView setSelectedItemsModel:strongSelf->_galleryModel.selectedItemsModel];
            
            if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            {
                if (strongSelf->_galleryController.previewMode)
                    [(TGMediaPickerGalleryVideoItemView *)itemView playIfAvailable];
            }
        };

        modernGallery.beginTransitionOut = ^UIView *(TGMediaPickerGalleryItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf.willTransitionOut != nil)
                    strongSelf.willTransitionOut();
                
                if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
                    [(TGMediaPickerGalleryVideoItemView *)itemView stop];
                
                if (strongSelf.referenceViewForItem != nil)
                    return strongSelf.referenceViewForItem(item);
            }
            return nil;
        };

        modernGallery.completedTransitionOut = ^
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
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
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:_windowManager parentController:_parentController contentController:_galleryController];
    controllerWindow.hidden = false;
    _galleryController.view.clipsToBounds = true;
    
    _strongGalleryController = nil;
}

- (UIViewController *)galleryController
{
    return _galleryController;
}

- (void)setPreviewMode
{
    _galleryController.previewMode = true;
    _strongGalleryController = nil;
}

- (void)updateWithFetchResult:(TGMediaAssetFetchResult *)fetchResult
{
    TGMediaAsset *currentAsset = ((TGMediaPickerGalleryItem *)_galleryController.currentItem).asset;
    
    bool exists;
    if ([currentAsset isKindOfClass:[TGCameraCapturedVideo class]]) {
        exists = [fetchResult indexOfAsset:((TGCameraCapturedVideo *)currentAsset).originalAsset] != NSNotFound;
    } else {
        exists =  ([fetchResult indexOfAsset:currentAsset] != NSNotFound);
    }
    if (!exists)
    {
        _galleryModel.dismiss(true, false);
        return;
    }
    
    __block id<TGModernGalleryItem> focusItem = nil;
    NSArray *galleryItems = [self prepareGalleryItemsForFetchResult:fetchResult selectionContext:_galleryModel.selectionContext editingContext:_editingContext stickersContext:_stickersContext asFile:_asFile enumerationBlock:^(TGMediaPickerGalleryItem *item)
    {
        if (focusItem == nil && [item isEqual:_galleryController.currentItem])
            focusItem = item;
    }];
    
    [_galleryModel _replaceItems:galleryItems focusingOnItem:focusItem];
}

- (NSArray *)prepareGalleryItemsForFetchResult:(TGMediaAssetFetchResult *)fetchResult selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext asFile:(bool)asFile enumerationBlock:(void (^)(TGMediaPickerGalleryItem *))enumerationBlock
{
    NSMutableArray *galleryItems = [[NSMutableArray alloc] init];
    
    NSUInteger count = fetchResult.count;
    if (_itemsLimit > 0)
        count = MIN(count, _itemsLimit);
    
    for (NSUInteger i = 0; i < count; i++)
    {
//        TGMediaAsset *asset = [fetchResult assetAtIndex:i];
//
//        TGMediaPickerGalleryItem<TGModernGallerySelectableItem, TGModernGalleryEditableItem> *galleryItem = nil;
//        switch (asset.type)
//        {
//            case TGMediaAssetVideoType:
//            {
//                galleryItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:(id<TGMediaEditableItem,TGMediaSelectableItem>)asset];
//            }
//                break;
//
//            case TGMediaAssetGifType:
//            {
//                TGCameraCapturedVideo *convertedAsset = [[TGCameraCapturedVideo alloc] initWithAsset:asset livePhoto:false];
//                galleryItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:convertedAsset];
//            }
//                break;
//
//            default:
//            {
//                galleryItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:(id<TGMediaEditableItem,TGMediaSelectableItem>)asset];
//            }
//                break;
//        }
        
        TGMediaPickerGalleryFetchResultItem *galleryItem = [[TGMediaPickerGalleryFetchResultItem alloc] initWithFetchResult:fetchResult index:i];
        galleryItem.selectionContext = selectionContext;
        galleryItem.editingContext = editingContext;
        galleryItem.stickersContext = stickersContext;
        
        if (enumerationBlock != nil)
            enumerationBlock(galleryItem);
        
        galleryItem.asFile = asFile;
        
        if (galleryItem != nil)
            [galleryItems addObject:galleryItem];
    }
    
    return galleryItems;
}

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem
{
    [_galleryModel.interfaceView setThumbnailSignalForItem:thumbnailSignalForItem];
}

- (UIView *)currentReferenceView
{
    if (self.referenceViewForItem != nil)
        return self.referenceViewForItem(_galleryController.currentItem);
    
    return nil;
}

@end
