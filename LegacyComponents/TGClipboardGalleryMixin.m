#import "TGClipboardGalleryMixin.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGModernGalleryController.h>
#import "TGClipboardGalleryPhotoItem.h"
#import "TGClipboardGalleryModel.h"

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGSuggestionContext.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetMoment.h>

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

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image images:(NSArray *)images parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer recipientName:(NSString *)recipientName
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
        
        TGClipboardGalleryModel *model = [[TGClipboardGalleryModel alloc] initWithContext:_context images:images focusIndex:focusIndex selectionContext:selectionContext editingContext:editingContext hasCaptions:hasCaptions hasTimer:hasTimer hasSelectionPanel:false recipientName:recipientName];
        _galleryModel = model;
        model.controller = modernGallery;
        model.suggestionContext = suggestionContext;
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
        
        model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSString *caption, NSArray *entities)
        {
            [editingContext setCaption:caption entities:entities forItem:editableItem];
            
            if (selectionContext != nil && caption.length > 0 && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
                [selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
        };
        
        [model.interfaceView updateSelectionInterface:selectionContext.count counterVisible:(selectionContext.count > 0) animated:false];
        model.interfaceView.donePressed = ^(TGClipboardGalleryPhotoItem *item)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_galleryModel.dismiss(true, false);
            
            if (strongSelf.completeWithItem != nil)
                strongSelf.completeWithItem(item);
        };
        
        modernGallery.model = model;
        modernGallery.itemFocused = ^(TGClipboardGalleryPhotoItem *item)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.itemFocused != nil)
                strongSelf.itemFocused(item);
        };
        
        modernGallery.beginTransitionIn = ^UIView *(TGClipboardGalleryPhotoItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf.willTransitionIn != nil)
                strongSelf.willTransitionIn();
            
            if (strongSelf.referenceViewForItem != nil)
                return strongSelf.referenceViewForItem(item);
            
            return nil;
        };
        
        modernGallery.finishedTransitionIn = ^(__unused TGClipboardGalleryPhotoItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_galleryModel.interfaceView setSelectedItemsModel:strongSelf->_galleryModel.selectedItemsModel];
        };
        
        modernGallery.beginTransitionOut = ^UIView *(TGClipboardGalleryPhotoItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGClipboardGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf.willTransitionOut != nil)
                    strongSelf.willTransitionOut();
                
                if (strongSelf.referenceViewForItem != nil)
                    return strongSelf.referenceViewForItem(item);
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
