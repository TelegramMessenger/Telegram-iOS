#import "TGClipboardPreviewItemView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGClipboardGalleryMixin.h>

#import "TGClipboardPreviewCell.h"

const CGFloat TGClipboardPreviewMaxWidth = 250.0f;
const CGFloat TGClipboardPreviewCellHeight = 198.0f;
const CGFloat TGClipboardPreviewEdgeInset = 8.0f;

@interface TGClipboardPreviewItemView () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
{
    id<LegacyComponentsContext> _context;
    
    NSArray *_images;
    
    UICollectionView *_collectionView;
    UICollectionViewFlowLayout *_collectionLayout;
    
    TGClipboardGalleryMixin *_galleryMixin;
    UIImage *_hiddenItem;
    
    SMetaDisposable *_selectionChangedDisposable;
    
    bool _collapsed;
    
    UIImage *_cornersImage;
}
@end

@implementation TGClipboardPreviewItemView

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context images:(NSArray *)images allowGrouping:(bool)allowGrouping
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        _context = context;
        _images = images;
     
        self.backgroundColor = [UIColor whiteColor];
        
        _collectionLayout = [[UICollectionViewFlowLayout alloc] init];
        _collectionLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionLayout.minimumLineSpacing = 8.0f;
        
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, TGClipboardPreviewCellHeight + TGClipboardPreviewEdgeInset * 2) collectionViewLayout:_collectionLayout];
        if (@available(iOS 11.0, *)) {
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.showsVerticalScrollIndicator = false;
        [_collectionView registerClass:[TGClipboardPreviewCell class] forCellWithReuseIdentifier:TGClipboardPreviewCellIdentifier];
        [self addSubview:_collectionView];
        
        _selectionContext = [[TGMediaSelectionContext alloc] initWithGroupingAllowed:allowGrouping selectionLimit:100];
        if (allowGrouping)
            _selectionContext.grouping = true;
        
        for (UIImage *image in _images)
        {
            [_selectionContext setItem:(id<TGMediaSelectableItem>)image selected:true];
        }
        
        __weak TGClipboardPreviewItemView *weakSelf = self;
        _selectionChangedDisposable = [[SMetaDisposable alloc] init];
        [_selectionChangedDisposable setDisposable:[[_selectionContext selectionChangedSignal] startWithNext:^(__unused TGMediaSelectionChange *change)
        {
            __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.selectionChanged != nil)
                strongSelf.selectionChanged(strongSelf->_selectionContext.count);
        }]];
        
        _editingContext = [[TGMediaEditingContext alloc] init];
    }
    return self;
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    [super setPallete:pallete];
    
    self.backgroundColor = pallete.backgroundColor;
    _collectionView.backgroundColor = pallete.backgroundColor;
    
    CGFloat radius = 5.5f;
    CGRect rect = CGRectMake(0, 0, 12.0f, 12.0f);
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, pallete.backgroundColor.CGColor);
    CGContextFillRect(context, rect);
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillEllipseInRect(context, rect);
    
    _cornersImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(radius, radius, radius, radius)];
    
    UIGraphicsEndImageContext();
}

- (void)setCollapsed:(bool)collapsed animated:(bool)animated
{
    _collapsed = collapsed;
 
    [self _updateHeightAnimated:animated];
}

- (CGFloat)contentHeightCorrection
{
    return _collapsed ? -TGMenuSheetButtonItemViewHeight : 0.0f;
}

- (SSignal *)_signalForImage:(UIImage *)image
{
    SSignal *originalSignal = [SSignal single:image];
    if (_editingContext == nil)
        return originalSignal;
    
    SSignal *editedSignal = [_editingContext fastImageSignalForItem:image withUpdates:true];
    return [editedSignal mapToSignal:^SSignal *(id result)
    {
        if (result != nil)
            return [SSignal single:result];
        else
            return originalSignal;
    }];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGClipboardPreviewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:TGClipboardPreviewCellIdentifier forIndexPath:indexPath];
    cell.selectionContext = _selectionContext;
    cell.editingContext = _editingContext;
    [cell setCornersImage:_cornersImage];
    
    UIImage *image = _images[indexPath.row];
    [cell setImage:image signal:[self _signalForImage:image] hasCheck:_images.count > 1];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)__unused collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    _galleryMixin = [self galleryMixinForIndexPath:indexPath];
    [_galleryMixin present];
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    return _images.count;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    return UIEdgeInsetsMake(TGClipboardPreviewEdgeInset, TGClipboardPreviewEdgeInset, TGClipboardPreviewEdgeInset, TGClipboardPreviewEdgeInset);
}

- (CGSize)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize dimensions = [(UIImage *)_images[indexPath.row] size];
    
    CGSize maxPhotoSize = CGSizeMake(TGClipboardPreviewMaxWidth, TGClipboardPreviewCellHeight);
    CGFloat width = MIN(maxPhotoSize.width, ceil(dimensions.width * maxPhotoSize.height / dimensions.height));
    return CGSizeMake(width, maxPhotoSize.height);
}

- (void)scrollViewDidScroll:(UIScrollView *)__unused scrollView
{
    for (UICollectionViewCell *cell in _collectionView.visibleCells)
    {
        if ([cell isKindOfClass:[TGClipboardPreviewCell class]])
            [(TGClipboardPreviewCell *)cell setNeedsLayout];
    }
}

- (bool)requiresDivider
{
    return false;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    return TGClipboardPreviewCellHeight + TGClipboardPreviewEdgeInset * 2.0f;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _collectionView.frame = self.bounds;
}

#pragma mark -

- (void)_setupGalleryMixin:(TGClipboardGalleryMixin *)mixin
{
    __weak TGClipboardPreviewItemView *weakSelf = self;
    mixin.referenceViewForItem = ^UIView *(TGClipboardGalleryPhotoItem *item)
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
            return [strongSelf referenceViewForAsset:item.image];
        
        return nil;
    };
    
    mixin.itemFocused = ^(TGClipboardGalleryPhotoItem *item)
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_hiddenItem = item.image;
        [strongSelf updateHiddenCellAnimated:false];
    };
    
    mixin.willTransitionIn = ^
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.superview bringSubviewToFront:strongSelf];
    };
    
    mixin.willTransitionOut = ^
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    };
    
    mixin.didTransitionOut = ^
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_hiddenItem = nil;
        [strongSelf updateHiddenCellAnimated:true];
        
        strongSelf->_galleryMixin = nil;
    };

    
    mixin.completeWithItem = ^(TGClipboardGalleryPhotoItem *item, bool silentPosting, int32_t scheduleTime)
    {
        __strong TGClipboardPreviewItemView *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.sendPressed != nil)
            strongSelf.sendPressed(item.image, silentPosting, scheduleTime);
    };
}

- (TGClipboardGalleryMixin *)galleryMixinForIndexPath:(NSIndexPath *)indexPath
{
    UIImage *image = _images[indexPath.row];
    UIImage *thumbnailImage = nil;
    
    TGClipboardPreviewCell *cell = (TGClipboardPreviewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[TGClipboardPreviewCell class]])
        thumbnailImage = cell.imageView.image;
    
    TGClipboardGalleryMixin *mixin = [[TGClipboardGalleryMixin alloc] initWithContext:_context image:image images:_images parentController:self.parentController thumbnailImage:thumbnailImage selectionContext:_selectionContext editingContext:_editingContext stickersContext:self.stickersContext hasCaptions:self.allowCaptions hasTimer:self.hasTimer hasSilentPosting:self.hasSilentPosting hasSchedule:self.hasSchedule reminder:self.reminder recipientName:self.recipientName];
    mixin.presentScheduleController = self.presentScheduleController;
    mixin.presentTimerController = self.presentTimerController;
    
    [self _setupGalleryMixin:mixin];
    
    return mixin;
}

- (UIView *)referenceViewForAsset:(UIImage *)image
{
    for (TGClipboardPreviewCell *cell in [_collectionView visibleCells])
    {
        if ([cell.image isEqual:image])
            return cell;
    }
    
    return nil;
}

- (void)updateHiddenCellAnimated:(bool)animated
{
    for (TGClipboardPreviewCell *cell in [_collectionView visibleCells])
        [cell setHidden:([cell.image isEqual:_hiddenItem]) animated:animated];
}

@end
