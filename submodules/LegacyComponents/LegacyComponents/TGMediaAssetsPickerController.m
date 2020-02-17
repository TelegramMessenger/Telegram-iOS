#import "TGMediaAssetsPickerController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UICollectionView+Utils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGMediaPickerLayoutMetrics.h>
#import "TGMediaAssetsPhotoCell.h"
#import "TGMediaAssetsVideoCell.h"
#import "TGMediaAssetsGifCell.h"

#import <LegacyComponents/TGMediaAssetsUtils.h>

#import <LegacyComponents/TGMediaAssetsUtils.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/TGMediaAssetFetchResultChange.h>

#import "TGModernBarButton.h"

#import <LegacyComponents/TGMediaAsset+TGMediaEditableItem.h>
#import <LegacyComponents/TGPhotoEditorController.h>
#import <LegacyComponents/PGPhotoEditorValues.h>

#import <LegacyComponents/TGMediaPickerModernGalleryMixin.h>
#import <LegacyComponents/TGMediaPickerGalleryItem.h>

@interface TGMediaAssetsPickerController () <UIViewControllerPreviewingDelegate>
{
    TGMediaAssetsControllerIntent _intent;
    TGMediaAssetsLibrary *_assetsLibrary;
    
    SMetaDisposable *_assetsDisposable;
    
    TGMediaAssetFetchResult *_fetchResult;
    
    TGModernBarButton *_searchBarButton;
    
    TGMediaPickerModernGalleryMixin *_galleryMixin;
    TGMediaPickerModernGalleryMixin *_previewGalleryMixin;
    NSIndexPath *_previewIndexPath;
    
    id<SDisposable> _selectionChangedDisposable;
    
    bool _checked3dTouch;
    
    id<LegacyComponentsContext> _context;
    bool _saveEditedPhotos;
}

@end

@implementation TGMediaAssetsPickerController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext saveEditedPhotos:(bool)saveEditedPhotos
{
    bool hasSelection = false;
    bool hasEditing = false;
    
    switch (intent)
    {
        case TGMediaAssetsControllerSendMediaIntent:
        case TGMediaAssetsControllerPassportMultipleIntent:
            hasSelection = true;
            hasEditing = true;
            break;
            
        case TGMediaAssetsControllerSendFileIntent:
            hasSelection = true;
            hasEditing = true;
            break;
            
        case TGMediaAssetsControllerSetProfilePhotoIntent:
        case TGMediaAssetsControllerSetSignupProfilePhotoIntent:
        case TGMediaAssetsControllerPassportIntent:
            hasEditing = true;
            break;
            
        default:
            break;
    }
    
    self = [super initWithContext:context selectionContext:hasSelection ? selectionContext : nil editingContext:hasEditing ? editingContext : nil];
    if (self != nil)
    {
        _context = context;
        _saveEditedPhotos = saveEditedPhotos;
        _assetsLibrary = assetsLibrary;
        _assetGroup = assetGroup;
        _intent = intent;
        
        [self setTitle:_assetGroup.title];
        
        _assetsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_assetsDisposable dispose];
    [_selectionChangedDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    [_collectionView registerClass:[TGMediaAssetsPhotoCell class] forCellWithReuseIdentifier:TGMediaAssetsPhotoCellKind];
    [_collectionView registerClass:[TGMediaAssetsVideoCell class] forCellWithReuseIdentifier:TGMediaAssetsVideoCellKind];
    [_collectionView registerClass:[TGMediaAssetsGifCell class] forCellWithReuseIdentifier:TGMediaAssetsGifCellKind];
    
    __weak TGMediaAssetsPickerController *weakSelf = self;
    _preheatMixin = [[TGMediaAssetsPreheatMixin alloc] initWithCollectionView:_collectionView scrollDirection:UICollectionViewScrollDirectionVertical];
    _preheatMixin.imageType = TGMediaAssetImageTypeThumbnail;
    _preheatMixin.assetCount = ^NSInteger
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return 0;
        
        return [strongSelf _numberOfItems];
    };
    _preheatMixin.assetAtIndexPath = ^TGMediaAsset *(NSIndexPath *indexPath)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        return [strongSelf _itemAtIndexPath:indexPath];
    };
    
    _selectionChangedDisposable = [[self.selectionContext selectionChangedSignal] startWithNext:^(id next)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            return [strongSelf updateSelectionIndexes];
    }];
}

- (void)updateSelectionIndexes
{
    for (TGMediaPickerCell *cell in _collectionView.visibleCells)
    {
        NSUInteger index = [self.selectionContext indexOfItem:(id<TGMediaSelectableItem>)cell.item];
        [cell.checkButton setNumber:index];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SSignal *groupSignal = nil;
    if (_assetGroup != nil)
        groupSignal = [SSignal single:_assetGroup];
    else
        groupSignal = [_assetsLibrary cameraRollGroup];
    
    __weak TGMediaAssetsPickerController *weakSelf = self;
    [_assetsDisposable setDisposable:[[[[groupSignal deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(TGMediaAssetGroup *assetGroup)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        if (strongSelf->_assetGroup == nil)
            strongSelf->_assetGroup = assetGroup;
        
        [strongSelf setTitle:assetGroup.title];
        
        return [strongSelf->_assetsLibrary assetsOfAssetGroup:assetGroup reversed:false];
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_layoutMetrics == nil)
        {
            if (strongSelf->_assetGroup.subtype == TGMediaAssetGroupSubtypePanoramas)
                strongSelf->_layoutMetrics = [TGMediaPickerLayoutMetrics panoramaLayoutMetrics];
            else
                strongSelf->_layoutMetrics = [TGMediaPickerLayoutMetrics defaultLayoutMetrics];
            
            strongSelf->_preheatMixin.imageSize = [strongSelf->_layoutMetrics imageSize];
        }
        
        if ([next isKindOfClass:[TGMediaAssetFetchResult class]])
        {
            TGMediaAssetFetchResult *fetchResult = (TGMediaAssetFetchResult *)next;
            
            bool scrollToBottom = (strongSelf->_fetchResult == nil);
            
            strongSelf->_fetchResult = fetchResult;
            [strongSelf->_collectionView reloadData];
            
            if (scrollToBottom)
            {
                [strongSelf->_collectionView layoutSubviews];
                [strongSelf _adjustContentOffsetToBottom];
            }
        }
        else if ([next isKindOfClass:[TGMediaAssetFetchResultChange class]])
        {
            TGMediaAssetFetchResultChange *change = (TGMediaAssetFetchResultChange *)next;
            
            strongSelf->_fetchResult = change.fetchResultAfterChanges;
            [TGMediaAssetsCollectionViewIncrementalUpdater updateCollectionView:strongSelf->_collectionView withChange:change completion:nil];
        }
        
        if (strongSelf->_galleryMixin != nil && strongSelf->_fetchResult != nil)
            [strongSelf->_galleryMixin updateWithFetchResult:strongSelf->_fetchResult];
    }]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setup3DTouch];
    [self setRightBarButtonItem:[(TGMediaAssetsController *)self.navigationController rightBarButtonItem]];
}

#pragma mark -

- (NSUInteger)_numberOfItems
{
    return _fetchResult.count;
}

- (id)_itemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_fetchResult assetAtIndex:indexPath.row];
}

- (SSignal *)_signalForItem:(id)item
{
    SSignal *assetSignal = [TGMediaAssetImageSignals imageForAsset:item imageType:TGMediaAssetImageTypeThumbnail size:[_layoutMetrics imageSize]];
    if (self.editingContext == nil)
        return assetSignal;
    
    return [[self.editingContext thumbnailImageSignalForItem:item] mapToSignal:^SSignal *(id result)
    {
        if (result != nil)
            return [SSignal single:result];
        else
            return assetSignal;
    }];
}

- (NSString *)_cellKindForItem:(id)item
{
    TGMediaAsset *asset = (TGMediaAsset *)item;
    if ([asset isKindOfClass:[TGMediaAsset class]])
    {
        switch (asset.type)
        {
            case TGMediaAssetVideoType:
                return TGMediaAssetsVideoCellKind;
                
            case TGMediaAssetGifType:
                if (_intent == TGMediaAssetsControllerSetProfilePhotoIntent || _intent == TGMediaAssetsControllerSetSignupProfilePhotoIntent || _intent == TGMediaAssetsControllerPassportIntent || _intent == TGMediaAssetsControllerPassportMultipleIntent)
                    return TGMediaAssetsPhotoCellKind;
                else
                    return TGMediaAssetsGifCellKind;
                
            default:
                break;
        }
    }
    return TGMediaAssetsPhotoCellKind;
}

#pragma mark - Collection View Delegate

- (void)_setupGalleryMixin:(TGMediaPickerModernGalleryMixin *)mixin
{
    __weak TGMediaAssetsPickerController *weakSelf = self;
    mixin.referenceViewForItem = ^UIView *(TGMediaPickerGalleryItem *item)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        for (TGMediaPickerCell *cell in [strongSelf->_collectionView visibleCells])
        {
            if ([cell.item isEqual:item.asset])
                return cell;
        }
        
        return nil;
    };
    
    mixin.itemFocused = ^(TGMediaPickerGalleryItem *item)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf _hideCellForItem:item.asset animated:false];
    };
    
    mixin.didTransitionOut = ^
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf _hideCellForItem:nil animated:true];
        strongSelf->_galleryMixin = nil;
    };
    
    mixin.completeWithItem = ^(TGMediaPickerGalleryItem *item, bool silentPosting, int32_t scheduleTime)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [(TGMediaAssetsController *)strongSelf.navigationController completeWithCurrentItem:item.asset silentPosting:silentPosting scheduleTime:scheduleTime];
    };
}

- (TGMediaPickerModernGalleryMixin *)_galleryMixinForContext:(id<LegacyComponentsContext>)context item:(id)item thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities inhibitDocumentCaptions:(bool)inhibitDocumentCaptions asFile:(bool)asFile
{
    return [[TGMediaPickerModernGalleryMixin alloc] initWithContext:context item:item fetchResult:_fetchResult parentController:self thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext suggestionContext:suggestionContext hasCaptions:hasCaptions allowCaptionEntities:allowCaptionEntities hasTimer:self.hasTimer onlyCrop:self.onlyCrop inhibitDocumentCaptions:inhibitDocumentCaptions inhibitMute:self.inhibitMute asFile:asFile itemsLimit:0 recipientName:self.recipientName hasSilentPosting:self.hasSilentPosting hasSchedule:self.hasSchedule reminder:self.reminder];
}

- (TGMediaPickerModernGalleryMixin *)galleryMixinForIndexPath:(NSIndexPath *)indexPath previewMode:(bool)previewMode outAsset:(TGMediaAsset **)outAsset
{
    TGMediaAsset *asset = [self _itemAtIndexPath:indexPath];
    if (outAsset != NULL)
        *outAsset = asset;
    
    UIImage *thumbnailImage = nil;
    
    TGMediaPickerCell *cell = (TGMediaPickerCell *)[_collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[TGMediaPickerCell class]])
        thumbnailImage = cell.imageView.image;
    
    bool asFile = (_intent == TGMediaAssetsControllerSendFileIntent);
    
    TGMediaPickerModernGalleryMixin *mixin = [self _galleryMixinForContext:_context item:asset thumbnailImage:thumbnailImage selectionContext:self.selectionContext editingContext:self.editingContext suggestionContext:self.suggestionContext hasCaptions:self.captionsEnabled allowCaptionEntities:self.allowCaptionEntities inhibitDocumentCaptions:self.inhibitDocumentCaptions asFile:asFile];
    mixin.presentScheduleController = self.presentScheduleController;
    __weak TGMediaAssetsPickerController *weakSelf = self;
    mixin.thumbnailSignalForItem = ^SSignal *(id item)
    {
        __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        return [strongSelf _signalForItem:item];
    };
    
    if (!previewMode)
        [self _setupGalleryMixin:mixin];
    
    return mixin;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGMediaAsset *asset = [self _itemAtIndexPath:indexPath];

    TGMediaSelectionContext *selectionContext = ((TGMediaAssetsController *)self.navigationController).selectionContext;
    if (UIAccessibilityIsVoiceOverRunning() && selectionContext != nil) {
        [selectionContext toggleItemSelection:asset success:nil];
        return;
    }
    
    __block UIImage *thumbnailImage = nil;
    if ([TGMediaAssetsLibrary usesPhotoFramework])
    {
        TGMediaPickerCell *cell = (TGMediaPickerCell *)[collectionView cellForItemAtIndexPath:indexPath];
        if ([cell isKindOfClass:[TGMediaPickerCell class]])
            thumbnailImage = cell.imageView.image;
    }
    else
    {
        [[TGMediaAssetImageSignals imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeZero] startWithNext:^(UIImage *next)
        {
            thumbnailImage = next;
        }];
    }
    
    if (((TGMediaAssetsController *)self.navigationController).selectionBlock != nil) {
        ((TGMediaAssetsController *)self.navigationController).selectionBlock(asset, thumbnailImage);
        return;
    }

    __weak TGMediaAssetsPickerController *weakSelf = self;
    if (_intent == TGMediaAssetsControllerSetProfilePhotoIntent || _intent == TGMediaAssetsControllerSetSignupProfilePhotoIntent)
    {
        TGPhotoEditorControllerIntent intent = TGPhotoEditorControllerAvatarIntent;
        if (_intent == TGMediaAssetsControllerSetSignupProfilePhotoIntent) {
            intent = TGPhotoEditorControllerSignupAvatarIntent;
        }
        TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:_context item:asset intent:intent adjustments:nil caption:nil screenImage:thumbnailImage availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent] selectedTab:TGPhotoEditorCropTab];
        controller.editingContext = self.editingContext;
        controller.didFinishRenderingFullSizeImage = ^(UIImage *resultImage)
        {
            __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
            if (strongSelf == nil || !strongSelf->_saveEditedPhotos)
                return;
            
            [[strongSelf->_assetsLibrary saveAssetWithImage:resultImage] startWithNext:nil];
        };
        controller.didFinishEditing = ^(__unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, bool hasChanges)
        {
            if (!hasChanges)
                return;
            
            __strong TGMediaAssetsPickerController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [(TGMediaAssetsController *)strongSelf.navigationController completeWithAvatarImage:resultImage];
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
            return [editableItem originalImageSignal:position];
        };
        
        [self.navigationController pushViewController:controller animated:true];
    }
    else
    {
        _galleryMixin = [self galleryMixinForIndexPath:indexPath previewMode:false outAsset:NULL];
        [_galleryMixin present];
    }
}

#pragma mark - 

- (void)setup3DTouch
{
    if (_checked3dTouch)
        return;
    
    _checked3dTouch = true;
    
    if (_intent == TGMediaAssetsControllerSetProfilePhotoIntent || _intent == TGMediaAssetsControllerSetSignupProfilePhotoIntent || _intent == TGMediaAssetsControllerSetCustomWallpaperIntent) {
        return;
    }
    
    if (iosMajorVersion() >= 9)
    {
        if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)
            [self registerForPreviewingWithDelegate:(id)self sourceView:self.view];
    }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    CGPoint point = [self.view convertPoint:location toView:_collectionView];
    NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:point];
    if (indexPath == nil)
        return nil;
    
    [self _cancelSelectionGestureRecognizer];
    
    CGRect cellFrame = [_collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath].frame;
    previewingContext.sourceRect = [self.view convertRect:cellFrame fromView:_collectionView];
    
    TGMediaAsset *asset = nil;
    _previewGalleryMixin = [self galleryMixinForIndexPath:indexPath previewMode:true outAsset:&asset];
    UIViewController *controller = [_previewGalleryMixin galleryController];
    controller.preferredContentSize = TGFitSize(asset.dimensions, self.view.frame.size);
    [_previewGalleryMixin setPreviewMode];
    return controller;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)__unused previewingContext commitViewController:(UIViewController *)__unused viewControllerToCommit
{
    _galleryMixin = _previewGalleryMixin;
    _previewGalleryMixin = nil;
    
    [self _setupGalleryMixin:_galleryMixin];
    [_galleryMixin present];
}

#pragma mark - Asset Image Preheating

- (void)scrollViewDidScroll:(UIScrollView *)__unused scrollView
{
    bool isViewVisible = (self.isViewLoaded && self.view.window != nil);
    if (!isViewVisible)
        return;
    
    [_preheatMixin update];
}

- (NSArray *)_assetsAtIndexPaths:(NSArray *)indexPaths
{
    if (indexPaths.count == 0)
        return nil;
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths)
    {
        if ((NSUInteger)indexPath.row < [self _numberOfItems])
            [assets addObject:[self _itemAtIndexPath:indexPath]];
    }
    
    return assets;
}

@end
