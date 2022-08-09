#import "TGAttachmentCarouselItemView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGMenuSheetButtonItemView.h>
#import <LegacyComponents/TGMenuSheetView.h>

#import <LegacyComponents/UICollectionView+Utils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

#import "TGTransitionLayout.h"

#import "TGAttachmentCameraView.h"

#import "TGAttachmentPhotoCell.h"
#import "TGAttachmentVideoCell.h"
#import "TGAttachmentGifCell.h"

#import <LegacyComponents/TGMediaAssetsLibrary.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>

#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGMediaPickerModernGalleryMixin.h>
#import <LegacyComponents/TGMediaPickerGalleryItem.h>
#import <LegacyComponents/TGMediaAssetsUtils.h>

#import "TGMediaAvatarEditorTransition.h"
#import <LegacyComponents/TGPhotoEditorController.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGMediaAsset+TGMediaEditableItem.h>

const CGSize TGAttachmentCellSize = { 84.0f, 84.0f };
const CGFloat TGAttachmentEdgeInset = 8.0f;

const CGFloat TGAttachmentZoomedPhotoRemainer = 32.0f;

const CGFloat TGAttachmentZoomedPhotoHeight = 198.0f;
const CGFloat TGAttachmentZoomedPhotoMaxWidth = 250.0f;

const CGFloat TGAttachmentZoomedPhotoCondensedHeight = 141.0f;
const CGFloat TGAttachmentZoomedPhotoCondensedMaxWidth = 178.0f;

const CGFloat TGAttachmentZoomedPhotoAspectRatio = 1.2626f;

const NSUInteger TGAttachmentDisplayedAssetLimit = 500;

@interface TGAttachmentCarouselCollectionView () <TGModernGalleryTransitionHostScrollView>

@end

@implementation TGAttachmentCarouselCollectionView

- (bool)disableGalleryTransitionOffsetFix {
    return true;
}

@end

@interface TGAttachmentCarouselItemView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
{
    TGMediaAssetsLibrary *_assetsLibrary;
    SMetaDisposable *_assetsDisposable;
    TGMediaAssetFetchResult *_fetchResult;
    
    bool _document;
    bool _forProfilePhoto;
    
    SMetaDisposable *_selectionChangedDisposable;
    SMetaDisposable *_itemsSizeChangedDisposable;
    
    UICollectionViewFlowLayout *_smallLayout;
    UICollectionViewFlowLayout *_largeLayout;
    UICollectionView *_collectionView;
    TGMediaAssetsPreheatMixin *_preheatMixin;
    
    TGAttachmentCameraView *_cameraView;
    
    TGMenuSheetButtonItemView *_sendMediaItemView;
    TGMenuSheetButtonItemView *_sendFileItemView;
    
    TGMediaPickerModernGalleryMixin *_galleryMixin;
    TGMediaPickerModernGalleryMixin *_previewGalleryMixin;
    TGMediaAsset *_hiddenItem;
    
    bool _zoomedIn;
    bool _zoomingIn;
    CGFloat _zoomingProgress;
    
    NSInteger _pivotInItemIndex;
    NSInteger _pivotOutItemIndex;
    
    CGSize _imageSize;
    
    CGSize _maxPhotoSize;
    
    CGFloat _smallActivationHeight;
    bool _smallActivated;
    CGSize _smallMaxPhotoSize;
    
    CGFloat _carouselCorrection;
    
    id<LegacyComponentsContext> _context;
    bool _saveEditedPhotos;
    
    TGMenuSheetPallete *_pallete;
    
    bool _savingStartImage;
}
@end

@implementation TGAttachmentCarouselItemView

- (bool)disableGalleryTransitionOffsetFix {
    return true;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context camera:(bool)hasCamera selfPortrait:(bool)selfPortrait forProfilePhoto:(bool)forProfilePhoto assetType:(TGMediaAssetType)assetType saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping
{
    return [self initWithContext:context camera:hasCamera selfPortrait:selfPortrait forProfilePhoto:forProfilePhoto assetType:assetType saveEditedPhotos:saveEditedPhotos allowGrouping:allowGrouping allowSelection:true allowEditing:!selfPortrait document:false selectionLimit:30];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context camera:(bool)hasCamera selfPortrait:(bool)selfPortrait forProfilePhoto:(bool)forProfilePhoto assetType:(TGMediaAssetType)assetType saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping allowSelection:(bool)allowSelection allowEditing:(bool)allowEditing document:(bool)document selectionLimit:(int)selectionLimit
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        _context = context;
        _saveEditedPhotos = saveEditedPhotos;
        
#if TARGET_IPHONE_SIMULATOR
        hasCamera = true;
#endif
        
        __weak TGAttachmentCarouselItemView *weakSelf = self;
        _document = document;
        _forProfilePhoto = forProfilePhoto;
        
        _assetsLibrary = [TGMediaAssetsLibrary libraryForAssetType:assetType];
        _assetsDisposable = [[SMetaDisposable alloc] init];
        
        if (!forProfilePhoto && allowSelection)
        {
            _selectionContext = [[TGMediaSelectionContext alloc] initWithGroupingAllowed:allowGrouping selectionLimit:selectionLimit];
            _selectionContext.selectionLimitExceeded = ^{
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                if (strongSelf->_selectionLimitExceeded) {
                    strongSelf->_selectionLimitExceeded();
                }
            };
            if (allowGrouping)
                _selectionContext.grouping = true;
            [_selectionContext setItemSourceUpdatedSignal:[_assetsLibrary libraryChanged]];
            _selectionContext.updatedItemsSignal = ^SSignal *(NSArray *items)
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                return [strongSelf->_assetsLibrary updatedAssetsForAssets:items];
            };
            
            _selectionChangedDisposable = [[SMetaDisposable alloc] init];
            [_selectionChangedDisposable setDisposable:[[[_selectionContext selectionChangedSignal] mapToSignal:^SSignal *(id value)
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return [SSignal complete];
                
                return [[strongSelf->_collectionView noOngoingTransitionSignal] then:[SSignal single:value]];
            }] startWithNext:^(__unused TGMediaSelectionChange *change)
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                NSInteger index = 0;
                if ([change.item isKindOfClass:[TGCameraCapturedVideo class]]) {
                    index = [strongSelf->_fetchResult indexOfAsset:((TGCameraCapturedVideo *)change.item).originalAsset];
                } else {
                    index = [strongSelf->_fetchResult indexOfAsset:(TGMediaAsset *)change.item];
                }
                
                [strongSelf updateSendButtonsFromIndex:index];
                
                [strongSelf updateSelectionIndexes];
            }]];
        }
        
        if (allowEditing)
        {
            _editingContext = [[TGMediaEditingContext alloc] init];
            
            _itemsSizeChangedDisposable = [[SMetaDisposable alloc] init];
            [_itemsSizeChangedDisposable setDisposable:[[[_editingContext cropAdjustmentsUpdatedSignal] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next)
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf->_zoomedIn)
                {
                    [strongSelf->_largeLayout invalidateLayout];
                    [strongSelf->_collectionView layoutSubviews];
                    
                    UICollectionViewCell *pivotCell = (UICollectionViewCell *)[strongSelf->_galleryMixin currentReferenceView];
                    if (pivotCell != nil)
                    {
                        NSIndexPath *indexPath = [strongSelf->_collectionView indexPathForCell:pivotCell];
                        if (indexPath != nil)
                            [strongSelf centerOnItemWithIndex:indexPath.row animated:false];
                    }
                }
            }]];
        }
        
        _smallLayout = [[UICollectionViewFlowLayout alloc] init];
        _smallLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _smallLayout.minimumLineSpacing = TGAttachmentEdgeInset;
        
        _largeLayout = [[UICollectionViewFlowLayout alloc] init];
        _largeLayout.scrollDirection = _smallLayout.scrollDirection;
        _largeLayout.minimumLineSpacing = _smallLayout.minimumLineSpacing;
        
        if (hasCamera)
        {
            _cameraView = [[TGAttachmentCameraView alloc] initForSelfPortrait:selfPortrait];
            _cameraView.frame = CGRectMake(_smallLayout.minimumLineSpacing, 0, TGAttachmentCellSize.width, TGAttachmentCellSize.height);
            [_cameraView startPreview];
            
            _cameraView.pressed = ^
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf.superview bringSubviewToFront:strongSelf];
                
                if (strongSelf.cameraPressed != nil)
                    strongSelf.cameraPressed(strongSelf->_cameraView);
            };
        }
        
        _collectionView = [[TGAttachmentCarouselCollectionView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, TGAttachmentZoomedPhotoHeight + TGAttachmentEdgeInset * 2) collectionViewLayout:_smallLayout];
        if (@available(iOS 11.0, *)) {
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.showsVerticalScrollIndicator = false;
        [_collectionView registerClass:[TGAttachmentPhotoCell class] forCellWithReuseIdentifier:TGAttachmentPhotoCellIdentifier];
        [_collectionView registerClass:[TGAttachmentVideoCell class] forCellWithReuseIdentifier:TGAttachmentVideoCellIdentifier];
        [_collectionView registerClass:[TGAttachmentGifCell class] forCellWithReuseIdentifier:TGAttachmentGifCellIdentifier];
        if (iosMajorVersion() >= 9)
            _collectionView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        [self addSubview:_collectionView];
        
        if (_cameraView)
            [_collectionView addSubview:_cameraView];
    
        _sendMediaItemView = [[TGMenuSheetButtonItemView alloc] initWithTitle:nil type:TGMenuSheetButtonTypeSend fontSize:20.0 action:^
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.sendPressed != nil)
            {
                if (strongSelf->_selectionContext.allowGrouping)
                    [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
                strongSelf.sendPressed(nil, false, false, 0, false);
            }
        }];
        [_sendMediaItemView setHidden:true animated:false];
        [self addSubview:_sendMediaItemView];
        
        if (!_document)
        {
            _sendFileItemView = [[TGMenuSheetButtonItemView alloc] initWithTitle:nil type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
            {
                __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
                if (strongSelf != nil && strongSelf.sendPressed != nil)
                    strongSelf.sendPressed(nil, true, false, 0, false);
            }];
            _sendFileItemView.requiresDivider = false;
            [_sendFileItemView setHidden:true animated:false];
            [self addSubview:_sendFileItemView];
        }
        
        [self setSignal:[[TGMediaAssetsLibrary authorizationStatusSignal] mapToSignal:^SSignal *(NSNumber *statusValue)
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return [SSignal complete];
            
            TGMediaLibraryAuthorizationStatus status = [statusValue intValue];
            if (status == TGMediaLibraryAuthorizationStatusAuthorized)
            {
                return [[strongSelf->_assetsLibrary cameraRollGroup] mapToSignal:^SSignal *(TGMediaAssetGroup *cameraRollGroup)
                {
                    return [strongSelf->_assetsLibrary assetsOfAssetGroup:cameraRollGroup reversed:true];
                }];
            }
            else
            {
                return [SSignal fail:nil];
            }
        }]];
        
        _preheatMixin = [[TGMediaAssetsPreheatMixin alloc] initWithCollectionView:_collectionView scrollDirection:UICollectionViewScrollDirectionHorizontal];
        _preheatMixin.imageType = TGMediaAssetImageTypeThumbnail;
        _preheatMixin.assetCount = ^NSInteger
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return 0;
            
            return [strongSelf collectionView:strongSelf->_collectionView numberOfItemsInSection:0];
        };
        _preheatMixin.assetAtIndexPath = ^TGMediaAsset *(NSIndexPath *indexPath)
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            return [strongSelf->_fetchResult assetAtIndex:indexPath.row];
        };
        
        [self _updateImageSize];        
        _preheatMixin.imageSize = _imageSize;
        
        [self setCondensed:false];
        
        _pivotInItemIndex = NSNotFound;
        _pivotOutItemIndex = NSNotFound;
    }
    return self;
}

- (void)dealloc
{
    [_assetsDisposable dispose];
    [_selectionChangedDisposable dispose];
    [_itemsSizeChangedDisposable dispose];
}

- (void)saveStartImage {
    _savingStartImage = true;
    __weak TGAttachmentCameraView *weakCameraView = _cameraView;
    [_cameraView saveStartImage:^{
        __strong TGAttachmentCameraView *strongCameraView = weakCameraView;
        [strongCameraView stopPreview];
    }];
}

- (UIView *)getItemSnapshot:(NSString *)uniqueId {
    for (UIView *cell in _collectionView.visibleCells) {
        if ([cell isKindOfClass:[TGAttachmentAssetCell class]]) {
            TGAttachmentAssetCell *assetCell = (TGAttachmentAssetCell *)cell;
            if (assetCell.asset.identifier != nil && [assetCell.asset.identifier isEqualToString:uniqueId]) {
                UIView *snapshotView = [assetCell snapshotViewAfterScreenUpdates:false];
                snapshotView.frame = [assetCell convertRect:assetCell.bounds toView:nil];
                assetCell.alpha = 0.01f;
                return snapshotView;
            }
        }
    }
    return nil;
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _pallete = pallete;
    
    _cameraView.pallete = pallete;
    [_sendMediaItemView setPallete:pallete];
    [_sendFileItemView setPallete:pallete];
}

- (void)setRemainingHeight:(CGFloat)remainingHeight
{
    _remainingHeight = remainingHeight;
    [self setCondensed:_condensed];
}

- (void)updateSelectionIndexes
{
    for (TGAttachmentAssetCell *cell in _collectionView.visibleCells)
    {
        NSUInteger index = [self.selectionContext indexOfItem:cell.asset];
        [cell.checkButton setNumber:index];
    }
}

- (void)setCondensed:(bool)condensed
{
    _condensed = condensed;
    
    if (condensed)
        _maxPhotoSize = CGSizeMake(TGAttachmentZoomedPhotoCondensedMaxWidth, TGAttachmentZoomedPhotoCondensedHeight);
    else
        _maxPhotoSize = CGSizeMake(TGAttachmentZoomedPhotoMaxWidth, TGAttachmentZoomedPhotoHeight);
    
    if (_remainingHeight > TGMenuSheetButtonItemViewHeight * (condensed ? 3 : 4))
        _maxPhotoSize.height += TGAttachmentZoomedPhotoRemainer;

    CGSize screenSize = TGScreenSize();
    _smallActivationHeight = screenSize.width;

    CGFloat smallHeight = MAX(95, screenSize.width - 225);
    _smallMaxPhotoSize = CGSizeMake(ceil(smallHeight * TGAttachmentZoomedPhotoAspectRatio), smallHeight);
    
    CGRect frame = _collectionView.frame;
    frame.size.height = _maxPhotoSize.height + TGAttachmentEdgeInset * 2;
    _collectionView.frame = frame;
}

- (void)setSignal:(SSignal *)signal
{
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    [_assetsDisposable setDisposable:[[[signal mapToSignal:^SSignal *(id value)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return [SSignal complete];
        
        return [[strongSelf->_collectionView noOngoingTransitionSignal] then:[SSignal single:value]];
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([next isKindOfClass:[TGMediaAssetFetchResult class]])
        {
            TGMediaAssetFetchResult *fetchResult = (TGMediaAssetFetchResult *)next;
            strongSelf->_fetchResult = fetchResult;
            [strongSelf->_collectionView reloadData];
        }
        else if ([next isKindOfClass:[TGMediaAssetFetchResultChange class]])
        {
            TGMediaAssetFetchResultChange *change = (TGMediaAssetFetchResultChange *)next;
            strongSelf->_fetchResult = change.fetchResultAfterChanges;
            [TGMediaAssetsCollectionViewIncrementalUpdater updateCollectionView:strongSelf->_collectionView withChange:change completion:nil];
         
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [strongSelf scrollViewDidScroll:strongSelf->_collectionView];
            });
        }
        
        if (strongSelf->_galleryMixin != nil && strongSelf->_fetchResult != nil)
            [strongSelf->_galleryMixin updateWithFetchResult:strongSelf->_fetchResult];
    }]];
}

- (SSignal *)_signalForItem:(TGMediaAsset *)asset
{
    return [self _signalForItem:asset refresh:false onlyThumbnail:false];
}

- (SSignal *)_signalForItem:(TGMediaAsset *)asset refresh:(bool)refresh onlyThumbnail:(bool)onlyThumbnail
{
    bool thumbnail = onlyThumbnail || !_zoomedIn;
    CGSize imageSize = onlyThumbnail ? [self imageSizeForThumbnail:true] : _imageSize;
    
    TGMediaAssetImageType screenImageType = refresh ? TGMediaAssetImageTypeLargeThumbnail : TGMediaAssetImageTypeFastLargeThumbnail;
    TGMediaAssetImageType imageType = thumbnail ? TGMediaAssetImageTypeAspectRatioThumbnail : screenImageType;
    
    TGMediaAsset *concreteAsset = asset;
    if ([concreteAsset isKindOfClass:[TGCameraCapturedVideo class]]) {
        concreteAsset = [(TGCameraCapturedVideo *)asset originalAsset];
    }
    
    SSignal *assetSignal = [TGMediaAssetImageSignals imageForAsset:concreteAsset imageType:imageType size:imageSize];
    if (_editingContext == nil)
        return assetSignal;
    
    SSignal *editedSignal =  thumbnail ? [_editingContext thumbnailImageSignalForItem:asset] : [_editingContext fastImageSignalForItem:asset withUpdates:true];
    return [editedSignal mapToSignal:^SSignal *(id result)
    {
        if (result != nil)
            return [SSignal single:result];
        else
            return assetSignal;
    }];
}

#pragma mark -

- (void)setCameraZoomedIn:(bool)zoomedIn progress:(CGFloat)progress
{
    if (_cameraView == nil)
        return;
    
    CGFloat size = TGAttachmentCellSize.height;
    progress = zoomedIn ? progress : 1.0f - progress;
    _cameraView.frame = CGRectMake(_smallLayout.minimumLineSpacing - (size + _smallLayout.minimumLineSpacing) * progress, 0, TGAttachmentCellSize.width + (size - TGAttachmentCellSize.width) * progress, TGAttachmentCellSize.height + (size - TGAttachmentCellSize.height) * progress);
    [_cameraView setZoomedProgress:progress];
}

- (void)setZoomedMode:(bool)zoomed animated:(bool)animated index:(NSInteger)index
{
    if (zoomed == _zoomedIn)
    {
        if (_zoomedIn)
            [self centerOnItemWithIndex:index animated:animated];
        
        return;
    }
    
    _zoomedIn = zoomed;
    _zoomingIn = true;
    _collectionView.userInteractionEnabled = false;
    
    if (zoomed)
        _pivotInItemIndex = index;
    else
        _pivotOutItemIndex = index;
    
    UICollectionViewFlowLayout *toLayout = _zoomedIn ? _largeLayout : _smallLayout;

    [self _updateImageSize];
    
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    TGTransitionLayout *layout = (TGTransitionLayout *)[_collectionView transitionToCollectionViewLayout:toLayout duration:0.3f completion:^(__unused BOOL completed, __unused BOOL finished)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_zoomingIn = false;
        strongSelf->_collectionView.userInteractionEnabled = true;
        [strongSelf centerOnItemWithIndex:index animated:false];
    }];
    layout.progressChanged = ^(CGFloat progress)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_zoomingProgress = progress;
        [strongSelf requestMenuLayoutUpdate];
        [strongSelf _layoutButtonItemViews];
        [strongSelf setCameraZoomedIn:strongSelf->_zoomedIn progress:progress];
    };
    layout.transitionAlmostFinished = ^
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_pivotInItemIndex = NSNotFound;
        strongSelf->_pivotOutItemIndex = NSNotFound;
    };
    
    CGPoint toOffset = [_collectionView toContentOffsetForLayout:layout indexPath:[NSIndexPath indexPathForRow:index inSection:0] toSize:_collectionView.bounds.size toContentInset:[self collectionView:_collectionView layout:toLayout insetForSectionAtIndex:0]];
    toOffset.y = 0;
    layout.toContentOffset = toOffset;
    
    for (TGMenuSheetItemView *itemView in self.underlyingViews)
        [itemView setHidden:zoomed animated:animated];
    
    [_sendMediaItemView setHidden:!zoomed animated:animated];
    [_sendFileItemView setHidden:!zoomed animated:animated];
    
    [self _updateVisibleItems];
}

- (void)updateSendButtonsFromIndex:(NSInteger)index
{
    __block NSInteger photosCount = 0;
    __block NSInteger videosCount = 0;
    __block NSInteger gifsCount = 0;
    
    [_selectionContext enumerateSelectedItems:^(id<TGMediaSelectableItem> item)
    {
        TGMediaAsset *asset = (TGMediaAsset *)item;
        if (![asset isKindOfClass:[TGMediaAsset class]])
            return;
        
        switch (asset.type)
        {
            case TGMediaAssetVideoType:
                videosCount++;
                break;
                
            case TGMediaAssetGifType:
                gifsCount++;
                break;
                
            default:
                photosCount++;
                break;
        }
    }];
    
    NSInteger totalCount = photosCount + videosCount + gifsCount;
    bool activated = (totalCount > 0);
    if ([self zoomedModeSupported])
        [self setZoomedMode:activated animated:true index:index];
    else
        [self setSelectedMode:activated animated:true];
    
    if (_document)
    {
        _sendMediaItemView.title = TGLocalized(@"Common.Done");
        return;
    }
    
    if (totalCount == 0)
        return;
    
    if (photosCount > 0 && videosCount == 0 && gifsCount == 0)
    {
        NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendPhoto_" value:photosCount]);
        _sendMediaItemView.title = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", photosCount]];
    }
    else if (videosCount > 0 && photosCount == 0 && gifsCount == 0)
    {
        NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendVideo_" value:videosCount]);
        _sendMediaItemView.title = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", videosCount]];
    }
    else if (gifsCount > 0 && photosCount == 0 && videosCount == 0)
    {
        NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendGif_" value:gifsCount]);
        _sendMediaItemView.title = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", gifsCount]];
    }
    else
    {
        NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendItem_" value:totalCount]);
        _sendMediaItemView.title = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", totalCount]];
    }
    
    if (totalCount == 1)
        _sendFileItemView.title = TGLocalized(@"AttachmentMenu.SendAsFile");
    else
        _sendFileItemView.title = TGLocalized(@"AttachmentMenu.SendAsFiles");
}

- (void)setSelectedMode:(bool)selected animated:(bool)animated
{
    [self.underlyingViews.firstObject setHidden:selected animated:animated];
    [_sendMediaItemView setHidden:!selected animated:animated];
}

- (bool)zoomedModeSupported
{
    return [TGMediaAssetsLibrary usesPhotoFramework];
}

- (CGPoint)contentOffsetForItemAtIndex:(NSInteger)index
{
    CGRect cellFrame = [_collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]].frame;
    
    CGFloat x = cellFrame.origin.x - (_collectionView.frame.size.width - cellFrame.size.width) / 2.0f;
    CGFloat contentOffset = MAX(0.0f, MIN(x, _collectionView.contentSize.width - _collectionView.frame.size.width));
    
    return CGPointMake(contentOffset, 0);
}

- (void)centerOnItemWithIndex:(NSInteger)index animated:(bool)animated
{
    [_collectionView setContentOffset:[self contentOffsetForItemAtIndex:index] animated:animated];
}

#pragma mark -

- (CGFloat)_preferredHeightForZoomedIn:(bool)zoomedIn progress:(CGFloat)progress screenHeight:(CGFloat)__unused screenHeight
{
    progress = zoomedIn ? progress : 1.0f - progress;
    
    CGFloat inset = TGAttachmentEdgeInset * 2;
    CGFloat cellHeight = TGAttachmentCellSize.height;
    CGFloat targetCellHeight = _smallActivated ? _smallMaxPhotoSize.height : _maxPhotoSize.height;
    
    cellHeight = cellHeight + (targetCellHeight - cellHeight) * progress;
    
    return cellHeight + inset;
}

- (CGFloat)_heightCorrectionForZoomedIn:(bool)zoomedIn progress:(CGFloat)progress
{
    progress = zoomedIn ? progress : 1.0f - progress;

    CGFloat correction = self.remainingHeight - (_document ? 1 : 2) * TGMenuSheetButtonItemViewHeight;
    return -(correction * progress);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)screenHeight
{
    if (_collapsed) {
        self.alpha = 0.0f;
        return 0.0f;
    }
    
    CGFloat progress = _zoomingIn ? _zoomingProgress : 1.0f;
    return [self _preferredHeightForZoomedIn:_zoomedIn progress:progress screenHeight:screenHeight];
}

- (CGFloat)contentHeightCorrection
{
    CGFloat progress = _zoomingIn ? _zoomingProgress : 1.0f;
    return [self _heightCorrectionForZoomedIn:_zoomedIn progress:progress];
}

#pragma mark -

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!_sendMediaItemView.userInteractionEnabled)
        return [super pointInside:point withEvent:event];
    
    return CGRectContainsPoint(self.bounds, point) || CGRectContainsPoint(_sendMediaItemView.frame, point) || CGRectContainsPoint(_sendFileItemView.frame, point);
}

#pragma mark -

- (void)_updateVisibleItems
{
    for (NSIndexPath *indexPath in _collectionView.indexPathsForVisibleItems)
    {
        TGMediaAsset *asset = [_fetchResult assetAtIndex:indexPath.row];
        TGAttachmentAssetCell *cell = (TGAttachmentAssetCell *)[_collectionView cellForItemAtIndexPath:indexPath];
        if (cell.isZoomed != _zoomedIn)
        {
            cell.isZoomed = _zoomedIn;
            if (cell.asset == nil)
                [cell setAsset:asset signal:[self _signalForItem:asset refresh:true onlyThumbnail:false]];
            else
                [cell setSignal:[self _signalForItem:asset refresh:true onlyThumbnail:false]];
        }
    }
}

- (void)_updateImageSize
{
    _imageSize = [self imageSizeForThumbnail:!_zoomedIn];
}

- (CGSize)imageSizeForThumbnail:(bool)forThumbnail
{
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    if (forThumbnail)
        return CGSizeMake(TGAttachmentCellSize.width * scale, TGAttachmentCellSize.height * scale);
    else
        return CGSizeMake(floor(TGAttachmentZoomedPhotoMaxWidth * scale), floor(TGAttachmentZoomedPhotoMaxWidth * scale));
}

- (bool)hasCameraInCurrentMode
{
    return (!_zoomedIn && _cameraView != nil);
}

#pragma mark - 

- (void)_setupGalleryMixin:(TGMediaPickerModernGalleryMixin *)mixin
{
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    mixin.referenceViewForItem = ^UIView *(TGMediaPickerGalleryItem *item)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
            return [strongSelf referenceViewForAsset:item.asset];
        
        return nil;
    };
    
    mixin.itemFocused = ^(TGMediaPickerGalleryItem *item)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_hiddenItem = item.asset;
        [strongSelf updateHiddenCellAnimated:false];
    };
    
    mixin.willTransitionIn = ^
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.superview bringSubviewToFront:strongSelf];
        [strongSelf->_cameraView pausePreview];
    };
    
    mixin.willTransitionOut = ^
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_cameraView resumePreview];
    };
    
    mixin.didTransitionOut = ^
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_hiddenItem = nil;
        [strongSelf updateHiddenCellAnimated:true];
        
        strongSelf->_galleryMixin = nil;
    };
    
    mixin.completeWithItem = ^(TGMediaPickerGalleryItem *item, bool silentPosting, int32_t scheduleTime)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.sendPressed != nil)
        {
            if (strongSelf->_selectionContext.allowGrouping)
                [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
            strongSelf.sendPressed(item.asset, strongSelf.asFile, silentPosting, scheduleTime, true);
        }
    };
    
    mixin.editorOpened = self.editorOpened;
    mixin.editorClosed = self.editorClosed;
}

- (TGMediaPickerModernGalleryMixin *)galleryMixinForIndexPath:(NSIndexPath *)indexPath previewMode:(bool)previewMode outAsset:(TGMediaAsset **)outAsset
{
    TGMediaAsset *asset = [_fetchResult assetAtIndex:indexPath.row];
    if (outAsset != NULL)
        *outAsset = asset;
    
    UIImage *thumbnailImage = nil;
    
    TGAttachmentAssetCell *cell = (TGAttachmentAssetCell *)[_collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[TGAttachmentAssetCell class]])
        thumbnailImage = cell.imageView.image;
    
    TGMediaPickerModernGalleryMixin *mixin = [[TGMediaPickerModernGalleryMixin alloc] initWithContext:_context item:asset fetchResult:_fetchResult parentController:self.parentController thumbnailImage:thumbnailImage selectionContext:_selectionContext editingContext:_editingContext hasCaptions:(_allowCaptions && !_forProfilePhoto) allowCaptionEntities:self.allowCaptionEntities hasTimer:self.hasTimer onlyCrop:self.onlyCrop inhibitDocumentCaptions:_inhibitDocumentCaptions inhibitMute:self.inhibitMute asFile:self.asFile itemsLimit:TGAttachmentDisplayedAssetLimit recipientName:self.recipientName hasSilentPosting:self.hasSilentPosting hasSchedule:self.hasSchedule reminder:self.reminder stickersContext:self.stickersContext];
    mixin.presentScheduleController = self.presentScheduleController;
    mixin.presentTimerController = self.presentTimerController;
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    mixin.thumbnailSignalForItem = ^SSignal *(id item)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        return [strongSelf _signalForItem:item refresh:false onlyThumbnail:true];
    };
    
    if (!previewMode)
        [self _setupGalleryMixin:mixin];
    
    return mixin;
}

- (UIView *)referenceViewForAsset:(TGMediaAsset *)asset
{
    for (TGAttachmentAssetCell *cell in [_collectionView visibleCells])
    {
        if ([cell.asset.uniqueIdentifier isEqual:asset.uniqueIdentifier])
            return cell;
    }
    
    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row;
    TGMediaAsset *asset = [_fetchResult assetAtIndex:index];
    
    __block UIImage *thumbnailImage = nil;
    if ([TGMediaAssetsLibrary usesPhotoFramework])
    {
        TGAttachmentAssetCell *cell = (TGAttachmentAssetCell *)[collectionView cellForItemAtIndexPath:indexPath];
        if ([cell isKindOfClass:[TGAttachmentAssetCell class]])
            thumbnailImage = cell.imageView.image;
    }
    else
    {
        [[TGMediaAssetImageSignals imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeZero] startWithNext:^(UIImage *next)
        {
            thumbnailImage = next;
        }];
    }
    
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    UIView *(^referenceViewForAsset)(TGMediaAsset *) = ^UIView *(TGMediaAsset *asset)
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
            return [strongSelf referenceViewForAsset:asset];
        
        return nil;
    };
    
    if (self.openEditor)
    {
        id<LegacyComponentsOverlayWindowManager> windowManager = [_context makeOverlayWindowManager];
        
        id<TGMediaEditableItem> editableItem = asset;
        if (asset.type == TGMediaAssetGifType) {
            editableItem = [[TGCameraCapturedVideo alloc] initWithAsset:asset livePhoto:false];
        }
        
        TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:[windowManager context] item:editableItem intent:_disableStickers ? TGPhotoEditorControllerSignupAvatarIntent : TGPhotoEditorControllerAvatarIntent adjustments:nil caption:nil screenImage:thumbnailImage availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent] selectedTab:TGPhotoEditorCropTab];
        controller.editingContext = _editingContext;
        controller.stickersContext = _stickersContext;
        controller.dontHideStatusBar = true;
        
        TGMediaAvatarEditorTransition *transition = [[TGMediaAvatarEditorTransition alloc] initWithController:controller fromView:referenceViewForAsset(asset)];
        
        controller.didFinishRenderingFullSizeImage = ^(UIImage *resultImage)
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil || !strongSelf->_saveEditedPhotos)
                return;
            
            [[strongSelf->_assetsLibrary saveAssetWithImage:resultImage] startWithNext:nil];
        };
        
        __weak TGPhotoEditorController *weakController = controller;
        controller.didFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, __unused UIImage *thumbnailImage, __unused bool hasChanges)
        {
            if (!hasChanges)
                return;
            
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGPhotoEditorController *strongController = weakController;
            if (strongController == nil)
                return;
            
            if (adjustments.paintingData.hasAnimation) {
                TGVideoEditAdjustments *videoAdjustments = adjustments;
                if ([videoAdjustments isKindOfClass:[PGPhotoEditorValues class]]) {
                    videoAdjustments = [TGVideoEditAdjustments editAdjustmentsWithPhotoEditorValues:(PGPhotoEditorValues *)adjustments preset:TGMediaVideoConversionPresetProfileVeryHigh];
                }
                
                NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"gifvideo_%x.jpg", (int)arc4random()]];
                NSData *data = UIImageJPEGRepresentation(resultImage, 0.8);
                [data writeToFile:filePath atomically:true];
                
                UIImage *previewImage = resultImage;
                if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                {
                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                    if (paintingImage == nil) {
                        paintingImage = adjustments.paintingData.image;
                    }
                    UIImage *croppedPaintingImage = TGPhotoEditorPaintingCrop(paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, resultImage.size, adjustments.originalSize, true, true, false);
                    UIImage *thumbnailImage = TGPhotoEditorVideoExtCrop(resultImage, croppedPaintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, TGScaleToFill(asset.dimensions, CGSizeMake(800, 800)), adjustments.originalSize, true, true, true, true);
                    if (thumbnailImage != nil) {
                        previewImage = thumbnailImage;
                    }
                }
                if (strongSelf.avatarVideoCompletionBlock != nil)
                    strongSelf.avatarVideoCompletionBlock(previewImage, [NSURL fileURLWithPath:filePath], videoAdjustments);
            } else {
                if (strongSelf.avatarCompletionBlock != nil)
                    strongSelf.avatarCompletionBlock(resultImage);
            }
        };
        controller.didFinishEditingVideo = ^(AVAsset *asset, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges) {
            if (!hasChanges)
                return;
            
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGPhotoEditorController *strongController = weakController;
            if (strongController == nil)
                return;
            
            if (strongSelf.avatarVideoCompletionBlock != nil)
                strongSelf.avatarVideoCompletionBlock(resultImage, asset, adjustments);
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
        
        TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:_parentController contentController:controller];
        controllerWindow.hidden = false;
        controller.view.clipsToBounds = true;
    
        transition.referenceFrame = ^CGRect
        {
            UIView *referenceView = referenceViewForAsset(asset);
            return [referenceView.superview convertRect:referenceView.frame toView:nil];
        };
        transition.referenceImageSize = ^CGSize
        {
            return asset.dimensions;
        };
        transition.referenceScreenImageSignal = ^SSignal *
        {
            return [TGMediaAssetImageSignals imageForAsset:asset imageType:TGMediaAssetImageTypeFastScreen size:CGSizeMake(640, 640)];
        };
        [transition presentAnimated:true];
        
        controller.beginCustomTransitionOut = ^(CGRect outReferenceFrame, UIView *repView, void (^completion)(void))
        {
            __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            transition.outReferenceFrame = outReferenceFrame;
            transition.repView = repView;
            [transition dismissAnimated:true completion:^
            {
                strongSelf->_hiddenItem = nil;
                [strongSelf updateHiddenCellAnimated:true];

                dispatch_async(dispatch_get_main_queue(), ^
                {
                    if (completion != nil)
                        completion();
                });
            }];
        };
        
        _hiddenItem = asset;
        [self updateHiddenCellAnimated:false];
    }
    else
    {
        _galleryMixin = [self galleryMixinForIndexPath:indexPath previewMode:false outAsset:NULL];
        [_galleryMixin present];
    }
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    return MIN(_fetchResult.count, TGAttachmentDisplayedAssetLimit);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row;

    TGMediaAsset *asset = [_fetchResult assetAtIndex:index];
    NSString *cellIdentifier = nil;
    switch (asset.type)
    {
        case TGMediaAssetVideoType:
            cellIdentifier = TGAttachmentVideoCellIdentifier;
            break;
            
        case TGMediaAssetGifType:
            cellIdentifier = TGAttachmentGifCellIdentifier;
            break;
            
        default:
            cellIdentifier = TGAttachmentPhotoCellIdentifier;
            break;
    }
    
    TGAttachmentAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.pallete = _pallete;
    NSInteger pivotIndex = NSNotFound;
    NSInteger limit = 0;
    if (_pivotInItemIndex != NSNotFound)
    {
        if (self.frame.size.width <= 320)
            limit = 2;
        else
            limit = 3;
            
        pivotIndex = _pivotInItemIndex;
    }
    else if (_pivotOutItemIndex != NSNotFound)
    {
        pivotIndex = _pivotOutItemIndex;

        if (self.frame.size.width <= 320)
            limit = 4;
        else
            limit = 6;
    }
    
    cell.selectionContext = _selectionContext;
    cell.editingContext = _editingContext;
    
    if (!(pivotIndex != NSNotFound && (indexPath.row < pivotIndex - limit || indexPath.row > pivotIndex + limit)))
    {
        if (![asset isEqual:cell.asset] || cell.isZoomed != _zoomedIn)
        {
            cell.isZoomed = _zoomedIn;
            [cell setAsset:asset signal:[self _signalForItem:asset refresh:[cell.asset isEqual:asset] onlyThumbnail:false]];
        }
    }
    
    if (self.selectionContext != nil)
        [cell.checkButton setNumber:[self.selectionContext indexOfItem:asset]];
    
    return cell;
}

- (void)updateHiddenCellAnimated:(bool)animated
{
    for (TGAttachmentAssetCell *cell in [_collectionView visibleCells])
        [cell setHidden:([cell.asset.uniqueIdentifier isEqual:_hiddenItem.uniqueIdentifier]) animated:animated];
}

#pragma mark -

- (CGSize)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (_zoomedIn)
    {
        CGSize maxPhotoSize = _maxPhotoSize;
        if (_smallActivated)
            maxPhotoSize = _smallMaxPhotoSize;
        
        if (_pivotInItemIndex != NSNotFound && (indexPath.row < _pivotInItemIndex - 2 || indexPath.row > _pivotInItemIndex + 2))
            return CGSizeMake(maxPhotoSize.height, maxPhotoSize.height);
        
        TGMediaAsset *asset = [_fetchResult assetAtIndex:indexPath.row];
        if (asset != nil)
        {
            CGSize dimensions = asset.dimensions;
            if (dimensions.width < 1.0f)
                dimensions.width = 1.0f;
            if (dimensions.height < 1.0f)
                dimensions.height = 1.0f;
            
            id<TGMediaEditAdjustments> adjustments = [_editingContext adjustmentsForItem:asset];
            if ([adjustments cropAppliedForAvatar:false])
            {
                dimensions = adjustments.cropRect.size;
                
                bool sideward = TGOrientationIsSideward(adjustments.cropOrientation, NULL);
                if (sideward)
                    dimensions = CGSizeMake(dimensions.height, dimensions.width);
            }
            
            CGFloat width = MIN(maxPhotoSize.width, ceil(dimensions.width * maxPhotoSize.height / dimensions.height));
            return CGSizeMake(width, maxPhotoSize.height);
        }
        
        return CGSizeMake(maxPhotoSize.height, maxPhotoSize.height);
    }
    
    return TGAttachmentCellSize;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    CGFloat edgeInset = TGAttachmentEdgeInset;
    CGFloat leftInset = [self hasCameraInCurrentMode] ? 2 * edgeInset + 84.0f : edgeInset;
    
    CGFloat height = self.frame.size.height;
    
    if (collectionViewLayout == _smallLayout)
        height = [self _preferredHeightForZoomedIn:false progress:1.0f screenHeight:self.screenHeight];
    else if (collectionViewLayout == _largeLayout)
        height = [self _preferredHeightForZoomedIn:true progress:1.0f screenHeight:self.screenHeight];
    
    CGFloat cellHeight = height - 2 * edgeInset;
    CGFloat topInset = _collectionView.frame.size.height - cellHeight - edgeInset;
    CGFloat bottomInset = edgeInset;
    
    return UIEdgeInsetsMake(topInset, leftInset, bottomInset, edgeInset);
}

- (CGFloat)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return _smallLayout.minimumLineSpacing;
}

- (UICollectionViewTransitionLayout *)collectionView:(UICollectionView *)__unused collectionView transitionLayoutForOldLayout:(UICollectionViewLayout *)fromLayout newLayout:(UICollectionViewLayout *)toLayout
{
    return [[TGTransitionLayout alloc] initWithCurrentLayout:fromLayout nextLayout:toLayout];
}

#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)__unused scrollView
{
    if (_zoomingIn)
        return;
    
    if (!_zoomedIn)
        [_preheatMixin update];
    
    for (UICollectionViewCell *cell in _collectionView.visibleCells)
    {
        if ([cell isKindOfClass:[TGAttachmentAssetCell class]])
            [(TGAttachmentAssetCell *)cell setNeedsLayout];
    }
}

#pragma mark -

- (void)menuView:(TGMenuSheetView *)menuView willAppearAnimated:(bool)__unused animated
{
    __weak TGAttachmentCarouselItemView *weakSelf = self;
    menuView.tapDismissalAllowed = ^bool
    {
        __strong TGAttachmentCarouselItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return true;
        
        return !strongSelf->_collectionView.isDecelerating && !strongSelf->_collectionView.isTracking;
    };
}

- (void)menuView:(TGMenuSheetView *)menuView willDisappearAnimated:(bool)animated
{
    [super menuView:menuView didDisappearAnimated:animated];
    menuView.tapDismissalAllowed = nil;
    if (!_savingStartImage) {
        [_cameraView stopPreview];
    }
}

#pragma mark -

- (void)setScreenHeight:(CGFloat)screenHeight
{
    _screenHeight = screenHeight;
    [self _updateSmallActivated];
    
}

- (void)setSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    _sizeClass = sizeClass;
    [self _updateSmallActivated];
}

- (void)_updateSmallActivated
{
    _smallActivated = (fabs(_screenHeight - _smallActivationHeight) < FLT_EPSILON && _sizeClass == UIUserInterfaceSizeClassCompact);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = _collectionView.frame;
    frame.size.width = self.frame.size.width;
    
    frame.size.height = (_smallActivated ? _smallMaxPhotoSize.height : _maxPhotoSize.height) + TGAttachmentEdgeInset * 2;
    frame.origin.y = self.frame.size.height - frame.size.height;
    
    if (!CGRectEqualToRect(frame, _collectionView.frame))
    {
        bool invalidate = fabs(_collectionView.frame.size.height - frame.size.height) > FLT_EPSILON;
        
        _collectionView.frame = frame;

        if (invalidate)
        {
            [_smallLayout invalidateLayout];
            [_largeLayout invalidateLayout];
            [_collectionView layoutSubviews];
        }
    }
    
    CGFloat height = self.frame.size.height;
    CGFloat cellHeight = height - 2 * TGAttachmentEdgeInset;
    CGFloat topInset = _collectionView.frame.size.height - cellHeight - TGAttachmentEdgeInset;
    
    frame = _cameraView.frame;
    frame.origin.y = topInset;
    _cameraView.frame = frame;
    
    [self _layoutButtonItemViews];
}

- (void)_layoutButtonItemViews
{
    _sendMediaItemView.frame = CGRectMake(0, [self preferredHeightForWidth:self.frame.size.width screenHeight:self.screenHeight], self.frame.size.width, [_sendMediaItemView preferredHeightForWidth:self.frame.size.width screenHeight:self.screenHeight]);
    _sendFileItemView.frame = CGRectMake(0, CGRectGetMaxY(_sendMediaItemView.frame), self.frame.size.width, [_sendFileItemView preferredHeightForWidth:self.frame.size.width screenHeight:self.screenHeight]);
}

#pragma mark - 

- (UIView *)previewSourceView
{
    return _collectionView;
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    if (self.openEditor) {
        return nil;
    }
    
    NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:location];
    if (indexPath == nil)
        return nil;
    
    CGRect cellFrame = [_collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath].frame;
    previewingContext.sourceRect = cellFrame;
    
    TGMediaAsset *asset = nil;
    _previewGalleryMixin = [self galleryMixinForIndexPath:indexPath previewMode:true outAsset:&asset];
    UIViewController *controller = [_previewGalleryMixin galleryController];
    
    CGSize screenSize = TGScreenSize();
    controller.preferredContentSize = TGFitSize(asset.dimensions, screenSize);
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

@end
