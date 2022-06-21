#import "TGMediaPickerGalleryModel.h"

#import "TGMediaPickerGallerySelectedItemsModel.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGModernGalleryController.h>
#import <LegacyComponents/TGModernGalleryItem.h>
#import "TGModernGallerySelectableItem.h"
#import "TGModernGalleryEditableItem.h"
#import "TGModernGalleryEditableItemView.h"
#import "TGMediaPickerGalleryItem.h"
#import <LegacyComponents/TGModernGalleryZoomableItemView.h>
#import "TGMediaPickerGalleryVideoItem.h"
#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGModernMediaListItem.h"
#import "TGModernMediaListSelectableItem.h"

#import <LegacyComponents/PGPhotoEditorValues.h>

#import <LegacyComponents/TGSecretTimerMenu.h>

#import "TGPhotoEntitiesContainerView.h"

@interface TGMediaPickerGalleryModel ()
{
    TGMediaPickerGalleryInterfaceView *_interfaceView;
    
    id<TGModernGalleryEditableItem> _itemBeingEdited;
    TGMediaEditingContext *_editingContext;
    
    id<LegacyComponentsContext> _context;
    
    id<TGModernGalleryItem> _initialFocusItem;
    bool _hasCaptions;
    bool _allowCaptionEntities;
    bool _hasTimer;
    bool _onlyCrop;
    bool _hasSelectionPanel;
    bool _inhibitDocumentCaptions;
    NSString *_recipientName;
    bool _hasCamera;
}

@property (nonatomic, weak) TGPhotoEditorController *editorController;

@end

@implementation TGMediaPickerGalleryModel

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context items:(NSArray *)items focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions hasSelectionPanel:(bool)hasSelectionPanel hasCamera:(bool)hasCamera recipientName:(NSString *)recipientName
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        
        [self _replaceItems:items focusingOnItem:focusItem];
        
        _editingContext = editingContext;
        _selectionContext = selectionContext;
        
        _initialFocusItem = focusItem;
        _hasCaptions = hasCaptions;
        _allowCaptionEntities = allowCaptionEntities;
        _hasTimer = hasTimer;
        _onlyCrop = onlyCrop;
        _hasSelectionPanel = hasSelectionPanel;
        _inhibitDocumentCaptions = inhibitDocumentCaptions;
        _recipientName = recipientName;
        _hasCamera = hasCamera;
        
        __weak TGMediaPickerGalleryModel *weakSelf = self;
        if (selectionContext != nil)
        {
            if (_hasCamera)
            {
                NSMutableArray *selectableItems = [[NSMutableArray alloc] init];
                for (TGMediaPickerGalleryItem *item in items)
                {
                    [selectableItems addObject:item.asset];
                }
                _selectedItemsModel = [[TGMediaPickerGallerySelectedItemsModel alloc] initWithSelectionContext:selectionContext items:selectableItems];
            }
            else
            {
                _selectedItemsModel = [[TGMediaPickerGallerySelectedItemsModel alloc] initWithSelectionContext:selectionContext];
            }
            _selectedItemsModel.selectionUpdated = ^(bool reload, bool incremental, bool add, NSInteger index)
            {
                __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;

                [strongSelf.interfaceView updateSelectionInterface:[strongSelf selectionCount] counterVisible:([strongSelf selectionCount] > 0) animated:incremental];
                [strongSelf.interfaceView updateSelectedPhotosView:reload incremental:incremental add:add index:index];
            };
        }
    }
    return self;
}

- (NSInteger)selectionCount
{
    if (self.externalSelectionCount != nil)
        return self.externalSelectionCount();
    
    return _selectedItemsModel.selectedCount;
}

- (void)setCurrentItem:(id<TGMediaSelectableItem>)item direction:(TGModernGalleryScrollAnimationDirection)direction
{
    if (![(id)item conformsToProtocol:@protocol(TGMediaSelectableItem)])
        return;
    
    id<TGMediaSelectableItem> targetSelectableItem = (id<TGMediaSelectableItem>)item;
    
    __block NSUInteger newIndex = NSNotFound;
    [self.items enumerateObjectsUsingBlock:^(id<TGModernGalleryItem> galleryItem, NSUInteger idx, BOOL *stop)
    {
         if ([galleryItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
         {
             id<TGMediaSelectableItem> selectableItem = ((id<TGModernGallerySelectableItem>)galleryItem).selectableMediaItem;
             
             if ([selectableItem.uniqueIdentifier isEqual:targetSelectableItem.uniqueIdentifier])
             {
                 newIndex = idx;
                 *stop = true;
             }
         }
    }];
    
    TGModernGalleryController *galleryController = self.controller;
    [galleryController setCurrentItemIndex:newIndex direction:direction animated:false];
}

- (void)setCurrentItemWithIndex:(NSUInteger)index
{
    if (_selectedItemsModel == nil)
        return;
    
    TGModernGalleryController *galleryController = self.controller;
    
    if (![galleryController.currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
        return;
    
    id<TGModernGallerySelectableItem> currentGalleryItem = (id<TGModernGallerySelectableItem>)galleryController.currentItem;

    __block NSUInteger currentSelectedItemIndex = NSNotFound;
    [_selectedItemsModel.items enumerateObjectsUsingBlock:^(id<TGMediaSelectableItem> item, NSUInteger index, BOOL *stop)
    {
        if ([item.uniqueIdentifier isEqualToString:currentGalleryItem.selectableMediaItem.uniqueIdentifier])
        {
            currentSelectedItemIndex = index;
            *stop = true;
        }
    }];

    id<TGMediaSelectableItem> item = _selectedItemsModel.items[index];
    
    TGModernGalleryScrollAnimationDirection direction = TGModernGalleryScrollAnimationDirectionLeft;
    if (currentSelectedItemIndex < index)
        direction = TGModernGalleryScrollAnimationDirectionRight;
    
    [self setCurrentItem:item direction:direction];
}

- (UIView <TGModernGalleryInterfaceView> *)interfaceView
{
    if (_interfaceView != nil)
        return _interfaceView;
    
    return [self createInterfaceView];
}

- (UIView <TGModernGalleryInterfaceView> *)createInterfaceView
{
    if (_interfaceView == nil)
    {
        __weak TGMediaPickerGalleryModel *weakSelf = self;
        _interfaceView = [[TGMediaPickerGalleryInterfaceView alloc] initWithContext:_context focusItem:_initialFocusItem selectionContext:_selectionContext editingContext:_editingContext stickersContext:_stickersContext hasSelectionPanel:_hasSelectionPanel hasCameraButton:_hasCamera recipientName:_recipientName];
        _interfaceView.hasCaptions = _hasCaptions;
        _interfaceView.allowCaptionEntities = _allowCaptionEntities;
        _interfaceView.hasTimer = _hasTimer;
        _interfaceView.onlyCrop = _onlyCrop;
        _interfaceView.inhibitDocumentCaptions = _inhibitDocumentCaptions;
        _interfaceView.inhibitMute = _inhibitMute;
        [_interfaceView setEditorTabPressed:^(TGPhotoEditorTab tab)
        {
             __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
             if (strongSelf == nil)
                 return;
             
             __strong TGModernGalleryController *controller = strongSelf.controller;
             if ([controller.currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
                 [strongSelf presentPhotoEditorForItem:(id<TGModernGalleryEditableItem>)controller.currentItem tab:tab];
        }];
        _interfaceView.photoStripItemSelected = ^(NSInteger index)
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf setCurrentItemWithIndex:index];
        };
        _interfaceView.captionSet = ^(id<TGModernGalleryItem> item, NSAttributedString *caption)
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.saveItemCaption == nil)
                return;
            
            __strong TGModernGalleryController *controller = strongSelf.controller;
            if ([controller.currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
                strongSelf.saveItemCaption(((id<TGModernGalleryEditableItem>)item).editableMediaItem, caption);
        };
        _interfaceView.timerRequested = ^
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGModernGalleryController *controller = strongSelf.controller;
            id<TGMediaEditableItem> editableMediaItem = ((id<TGModernGalleryEditableItem>)controller.currentItem).editableMediaItem;
            
            NSString *description = editableMediaItem.isVideo ? TGLocalized(@"SecretTimer.VideoDescription") : TGLocalized(@"SecretTimer.ImageDescription");
            
            NSString *lastValueKey = @"mediaPickerLastTimerValue_v0";
            NSNumber *value = [strongSelf->_editingContext timerForItem:editableMediaItem];
            if (value == nil)
                value = [[NSUserDefaults standardUserDefaults] objectForKey:lastValueKey];
            
            [TGSecretTimerMenu presentInParentController:controller context:strongSelf->_context dark:true description:description values:[TGSecretTimerMenu secretMediaTimerValues] value:value completed:^(NSNumber *value)
             {
                 __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                 if (strongSelf == nil)
                     return;
                 
                 if (value == nil)
                     [[NSUserDefaults standardUserDefaults] removeObjectForKey:lastValueKey];
                 else
                     [[NSUserDefaults standardUserDefaults] setObject:value forKey:lastValueKey];
                 
                 if (value.integerValue != 0)
                 {
                     __strong TGModernGalleryController *controller = strongSelf.controller;
                     id<TGMediaSelectableItem> selectableItem = nil;
                     if ([controller.currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
                     {
                         selectableItem = ((id<TGModernGallerySelectableItem>)controller.currentItem).selectableMediaItem;
                         
                         if (selectableItem != nil) {
                             [strongSelf->_selectionContext setItem:selectableItem selected:true animated:false sender:nil];
                         }
                     }
                 }
                 
                 [strongSelf->_editingContext setTimer:value forItem:editableMediaItem];
             } dismissed:^
             {
                 __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                 if (strongSelf != nil)
                     [strongSelf->_interfaceView setAllInterfaceHidden:false delay:0.0f animated:true];
             } sourceView:controller.view sourceRect:^CGRect
             {
                 __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                 if (strongSelf == nil)
                     return CGRectZero;
                 
                 __strong TGModernGalleryController *controller = strongSelf.controller;
                 return [strongSelf->_interfaceView.timerButton convertRect:strongSelf->_interfaceView.timerButton.bounds toView:controller.view];
             }];
        };
        
        if (@available(iOS 11.0, *)) {
            _interfaceView.accessibilityIgnoresInvertColors = true;
        }
    }
    return _interfaceView;
}

- (UIView *)referenceViewForItem:(id<TGModernGalleryItem>)item frame:(CGRect *)frame
{
    TGModernGalleryController *galleryController = self.controller;
    TGModernGalleryItemView *galleryItemView = [galleryController itemViewForItem:item];
    
    if ([galleryItemView isKindOfClass:[TGModernGalleryZoomableItemView class]])
    {
        TGModernGalleryZoomableItemView *zoomableItemView = (TGModernGalleryZoomableItemView *)galleryItemView;
        
        if (zoomableItemView.contentView != nil)
        {
            if (frame != NULL)
                *frame = [zoomableItemView transitionViewContentRect];
            
            return (UIImageView *)zoomableItemView.transitionContentView;
        }
    }
    else if ([galleryItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
    {
        TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)galleryItemView;
        
        if (frame != NULL)
            *frame = [videoItemView transitionViewContentRect];
        
        return (UIView *)videoItemView;
    }
    
    return nil;
}

- (void)updateHiddenItem
{
    TGModernGalleryController *galleryController = self.controller;
    
    for (TGModernGalleryItemView *itemView in galleryController.visibleItemViews)
    {
        if ([itemView conformsToProtocol:@protocol(TGModernGalleryEditableItemView)])
            [(TGModernGalleryItemView <TGModernGalleryEditableItemView> *)itemView setHiddenAsBeingEdited:[itemView.item isEqual:_itemBeingEdited]];
    }
}

- (void)updateEditedItemView
{
    TGModernGalleryController *galleryController = self.controller;
    
    for (TGModernGalleryItemView *itemView in galleryController.visibleItemViews)
    {
        if ([itemView conformsToProtocol:@protocol(TGModernGalleryEditableItemView)])
        {
            if ([itemView.item isEqual:_itemBeingEdited])
            {
                [(TGModernGalleryItemView <TGModernGalleryEditableItemView> *)itemView setItem:_itemBeingEdited synchronously:true];
                if (self.itemsUpdated != nil)
                    self.itemsUpdated(_itemBeingEdited);
            }
        }
    }
}

- (void)presentPhotoEditorForItem:(id<TGModernGalleryEditableItem>)item tab:(TGPhotoEditorTab)tab
{
    [self presentPhotoEditorForItem:item tab:tab snapshots:@[]];
}

- (void)presentPhotoEditorForItem:(id<TGModernGalleryEditableItem>)item tab:(TGPhotoEditorTab)tab snapshots:(NSArray *)snapshots
{
    __weak TGMediaPickerGalleryModel *weakSelf = self;
    
    if (_itemBeingEdited != nil)
        return;
    
    _itemBeingEdited = item;

    id<TGMediaEditAdjustments> adjustments = [item.editingContext adjustmentsForItem:item.editableMediaItem];
    
    NSAttributedString *caption = [item.editingContext captionForItem:item.editableMediaItem];

    CGRect refFrame = CGRectZero;
    UIView *editorReferenceView = [self referenceViewForItem:item frame:&refFrame];
    UIView *referenceView = nil;
    UIImage *screenImage = nil;
    UIView *referenceParentView = nil;
    UIImage *image = nil;
    
    TGPhotoEntitiesContainerView *entitiesView = nil;
    
    id<TGMediaEditableItem> editableMediaItem = item.editableMediaItem;
    
    bool isVideo = false;
    if ([editorReferenceView isKindOfClass:[UIImageView class]])
    {
        screenImage = [(UIImageView *)editorReferenceView image];
        referenceView = editorReferenceView;
        
        if ([editorReferenceView.subviews.firstObject.subviews.firstObject.subviews.firstObject isKindOfClass:[TGPhotoEntitiesContainerView class]]) {
            entitiesView = editorReferenceView.subviews.firstObject.subviews.firstObject.subviews.firstObject;
        }
    }
    else if ([editorReferenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
    {
        TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)editorReferenceView;
        [videoItemView prepareForEditing];
        
        refFrame = [videoItemView editorTransitionViewRect];
        screenImage = [videoItemView transitionImage];
        image = [videoItemView screenImage];
        referenceView = [[UIImageView alloc] initWithImage:screenImage];
        referenceParentView = editorReferenceView;
        
        entitiesView = [videoItemView entitiesView];
        
        isVideo = true;
        
        editableMediaItem = videoItemView.editableMediaItem;
    }
    
    if (self.useGalleryImageAsEditableItemImage && self.storeOriginalImageForItem != nil)
        self.storeOriginalImageForItem(item.editableMediaItem, screenImage);
    
    TGPhotoEditorControllerIntent intent = isVideo ? TGPhotoEditorControllerVideoIntent : TGPhotoEditorControllerGenericIntent;
    TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:_context item:editableMediaItem intent:intent adjustments:adjustments caption:caption screenImage:screenImage availableTabs:_interfaceView.currentTabs selectedTab:tab];
    controller.entitiesView = entitiesView;
    controller.editingContext = _editingContext;
    controller.stickersContext = _stickersContext;
    self.editorController = controller;
    controller.willFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, id temporaryRep, bool hasChanges)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_itemBeingEdited = nil;
        
        if (strongSelf.willFinishEditingItem != nil)
            strongSelf.willFinishEditingItem(item.editableMediaItem, adjustments, temporaryRep, hasChanges);
    };
    
    void (^didFinishEditingItem)(id<TGMediaEditableItem>item, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage) = self.didFinishEditingItem;
    controller.didFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil) {
            TGLegacyLog(@"controller.didFinishEditing strongSelf == nil");
        }
        
#ifdef DEBUG
        if (adjustments != nil && hasChanges && !isVideo)
            NSAssert(resultImage != nil, @"resultImage should not be nil");
#endif
        
        if (hasChanges)
        {
            if (didFinishEditingItem != nil) {
                didFinishEditingItem(editableMediaItem, adjustments, resultImage, thumbnailImage);
            }
        }
        
        if ([editorReferenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
        {
            TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)editorReferenceView;
            [videoItemView setScrubbingPanelApperanceLocked:false];
            [videoItemView presentScrubbingPanelAfterReload:hasChanges];
        }
    };
    
    controller.didFinishRenderingFullSizeImage = ^(UIImage *image)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.didFinishRenderingFullSizeImage != nil)
            strongSelf.didFinishRenderingFullSizeImage(editableMediaItem, image);
    };
    
    controller.captionSet = ^(NSAttributedString *caption)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.saveItemCaption != nil)
            strongSelf.saveItemCaption(item.editableMediaItem, caption);
    };
    
    controller.requestToolbarsHidden = ^(bool hidden, bool animated)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.interfaceView setToolbarsHidden:hidden animated:animated];
    };

    controller.beginTransitionIn = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        if (strongSelf.editorOpened != nil)
            strongSelf.editorOpened();
        
        [strongSelf updateHiddenItem];
        [strongSelf.interfaceView editorTransitionIn];
        
        *referenceFrame = refFrame;
        
        if (referenceView.superview == nil)
            *parentView = referenceParentView;
        
        if (iosMajorVersion() >= 7)
            [strongSelf.controller setNeedsStatusBarAppearanceUpdate];
        else
            [_context setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
        
        return referenceView;
    };
    
    controller.finishedTransitionIn = ^
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGModernGalleryController *galleryController = strongSelf.controller;
        TGModernGalleryItemView *galleryItemView = [galleryController itemViewForItem:strongSelf->_itemBeingEdited];
        if (![galleryItemView isKindOfClass:[TGModernGalleryZoomableItemView class]])
            return;
        
        TGModernGalleryZoomableItemView *zoomableItemView = (TGModernGalleryZoomableItemView *)galleryItemView;
        [zoomableItemView reset];
    };
    
    controller.beginTransitionOut = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        [strongSelf.interfaceView editorTransitionOut];
        
        CGRect refFrame;
        UIView *referenceView = [strongSelf referenceViewForItem:item frame:&refFrame];
        if ([referenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
        {
            TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)referenceView;
            refFrame = [videoItemView editorTransitionViewRect];
            UIImage *screenImage = [videoItemView transitionImage];
            *parentView = referenceView;
            referenceView = [[UIImageView alloc] initWithImage:screenImage];
        }
        
        *referenceFrame = refFrame;
        
        return referenceView;
    };
    
    controller.finishedTransitionOut = ^(__unused bool saved)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.editorClosed != nil)
            strongSelf.editorClosed();
        
        [strongSelf updateHiddenItem];
        
        UIView *referenceView = [strongSelf referenceViewForItem:item frame:NULL];
        if ([referenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            [(TGMediaPickerGalleryVideoItemView *)referenceView returnFromEditing];
        
        if (iosMajorVersion() >= 7)
            [strongSelf.controller setNeedsStatusBarAppearanceUpdate];
        else {
            [_context setStatusBarHidden:false withAnimation:UIStatusBarAnimationNone];
        }
        
        if (@available(iOS 11.0, *)) {
            [strongSelf.controller setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
        }
    };
    
    controller.requestThumbnailImage = ^SSignal *(id<TGMediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    controller.requestOriginalScreenSizeImage = ^SSignal *(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    
    controller.requestOriginalFullSizeImage = ^SSignal *(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
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
    
    controller.requestAdjustments = ^id<TGMediaEditAdjustments> (id<TGMediaEditableItem> editableItem)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.requestAdjustments != nil)
            return strongSelf.requestAdjustments(editableItem);
    
        return nil;
    };
    
    controller.requestImage = ^
    {
        return image;
    };
    
    [self.controller addChildViewController:controller];
    [self.controller.view addSubview:controller.view];
    
    for (UIView *view in snapshots) {
        [self.controller.view addSubview:view];
        [UIView animateWithDuration:0.3 animations:^{
            view.alpha = 0.0;
        } completion:^(__unused BOOL finished) {
            [view removeFromSuperview];
        }];
    }
}

- (void)_replaceItems:(NSArray *)items focusingOnItem:(id<TGModernGalleryItem>)item
{
    [super _replaceItems:items focusingOnItem:item];
 
    TGModernGalleryController *controller = self.controller;
    
    NSArray *itemViews = [controller.visibleItemViews copy];
    for (TGModernGalleryItemView *itemView in itemViews)
        [itemView setItem:itemView.item synchronously:false];
}

- (bool)_shouldAutorotate
{
    TGPhotoEditorController *editorController = self.editorController;
    return (!editorController || [editorController shouldAutorotate]);
}

@end
