#import "TGPhotoEditorCollectionView.h"

#import "LegacyComponentsInternal.h"

#import "PGPhotoFilter.h"

#import "TGPhotoFilterCell.h"
#import "TGPhotoToolCell.h"

#import "TGPhotoEditorSliderView.h"

const CGPoint TGPhotoEditorEdgeScrollTriggerOffset = { 100, 150 };

@interface TGPhotoEditorCollectionView () <UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate>
{
    NSIndexPath *_selectedItemIndexPath;
    UICollectionViewFlowLayout *_layout;
    
    bool _landscape;
    CGFloat _nameWidth;
}

@property (nonatomic, weak) id<UICollectionViewDelegate> realDelegate;

@end

@implementation TGPhotoEditorCollectionView

- (instancetype)initWithLandscape:(bool)landscape nameWidth:(CGFloat)nameWidth
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 6.0f;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    
    self = [super initWithFrame:CGRectZero collectionViewLayout:layout];
    if (self != nil)
    {
        _layout = layout;
        _landscape = landscape;
        _nameWidth = nameWidth;
        self.dataSource = self;
        self.delegate = self;
        self.showsHorizontalScrollIndicator = false;
        self.showsVerticalScrollIndicator = false;
        
        [self registerClass:[TGPhotoFilterCell class] forCellWithReuseIdentifier:TGPhotoFilterCellKind];
        [self registerClass:[TGPhotoToolCell class] forCellWithReuseIdentifier:TGPhotoToolCellKind];
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view
{
    if ([view isKindOfClass:[TGPhotoEditorSliderView class]] && !((TGPhotoEditorSliderView *)view).knobStartedDragging)
        return true;
    
    return [super touchesShouldCancelInContentView:view];
}

- (void)dealloc
{
    self.dataSource = nil;
    self.delegate = nil;
}

- (bool)hasAnyTracking
{
    if (self.isTracking)
        return true;
    
    for (UICollectionViewCell *cell in self.visibleCells)
    {
        if ([cell isKindOfClass:[TGPhotoToolCell class]] && [(TGPhotoToolCell *)cell isTracking])
            return true;
    }
    
    return false;
}

- (void)setDelegate:(id<UICollectionViewDelegate>)delegate
{
    if (delegate == nil)
    {
        [super setDelegate:nil];
        self.realDelegate = nil;
    }
    else
    {
        [super setDelegate:self];
        if (delegate != self)
            self.realDelegate = delegate;
    }
}

- (void)setMinimumLineSpacing:(CGFloat)minimumLineSpacing
{
    [(UICollectionViewFlowLayout *)self.collectionViewLayout setMinimumLineSpacing:minimumLineSpacing];
    [self.collectionViewLayout invalidateLayout];
}

- (void)setMinimumInteritemSpacing:(CGFloat)minimumInteritemSpacing
{
    [(UICollectionViewFlowLayout *)self.collectionViewLayout setMinimumInteritemSpacing:minimumInteritemSpacing];
    [self.collectionViewLayout invalidateLayout];
}

- (void)setSelectedItemIndexPath:(NSIndexPath *)indexPath
{
    NSArray *visibleItemsIndexPathes = self.indexPathsForVisibleItems;
    for (NSIndexPath *i in visibleItemsIndexPathes)
    {
        UICollectionViewCell *cell = [self cellForItemAtIndexPath:i];
        if ([cell isKindOfClass:[TGPhotoFilterCell class]])
            [(TGPhotoFilterCell *)cell setFilterSelected:[i isEqual:indexPath]];
    }
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
    _selectedItemIndexPath = indexPath;
    [super selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
    
    [self setSelectedItemIndexPath:indexPath];
}

- (void)reloadData
{
    [super reloadData];
    
    if (_selectedItemIndexPath != nil)
        [self selectItemAtIndexPath:_selectedItemIndexPath animated:false scrollPosition:UICollectionViewScrollPositionNone];
}

#pragma mark - Collection View Data Source & Delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return CGSizeMake(collectionView.frame.size.width, 46.0f);
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    id <TGPhotoEditorCollectionViewFiltersDataSource> filtersDataSource = self.filtersDataSource;
    id <TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource = self.toolsDataSource;
    
    if ([filtersDataSource respondsToSelector:@selector(numberOfFiltersInCollectionView:)])
        return [filtersDataSource numberOfFiltersInCollectionView:self];
    else if ([toolsDataSource respondsToSelector:@selector(numberOfToolsInCollectionView:)])
        return [toolsDataSource numberOfToolsInCollectionView:self];
    
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)__unused collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<TGPhotoEditorCollectionViewFiltersDataSource> filtersDataSource = self.filtersDataSource;
    id<TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource = self.toolsDataSource;
    
    UICollectionViewCell *cell = nil;
    
    if ([filtersDataSource respondsToSelector:@selector(collectionView:filterAtIndex:)])
    {
        PGPhotoFilter *filter = [filtersDataSource collectionView:self filterAtIndex:indexPath.row];
        
        cell = [self dequeueReusableCellWithReuseIdentifier:TGPhotoFilterCellKind forIndexPath:indexPath];
        [(TGPhotoFilterCell *)cell setPhotoFilter:filter];
        [(TGPhotoFilterCell *)cell setFilterSelected:[_selectedItemIndexPath isEqual:indexPath]];
        
        [filtersDataSource collectionView:self requestThumbnailImageForFilterAtIndex:indexPath.row completion:^(UIImage *thumbnailImage, bool cached, __unused bool finished)
        {
            TGDispatchOnMainThread(^
            {
                if ([[(TGPhotoFilterCell *)cell filterIdentifier] isEqualToString:filter.identifier])
                    [(TGPhotoFilterCell *)cell setImage:thumbnailImage animated:!cached];
            });
        }];
    }
    else if ([toolsDataSource respondsToSelector:@selector(collectionView:toolAtIndex:)])
    {
        cell = [self dequeueReusableCellWithReuseIdentifier:TGPhotoToolCellKind forIndexPath:indexPath];
        cell.alpha = 1.0f;
        void (^changeBlock)(PGPhotoTool *, id, bool) = [toolsDataSource changeBlockForCollectionView:self];
        
        __weak TGPhotoEditorCollectionView *weakSelf = self;
        __weak TGPhotoToolCell *weakCell = (TGPhotoToolCell *)cell;
        void (^interactionBegan)(void) = ^
        {
            __strong TGPhotoEditorCollectionView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.interactionBegan != nil)
                strongSelf.interactionBegan();
            
            __strong TGPhotoToolCell *strongCell = weakCell;
            if (strongCell != nil)
                [strongSelf setCellsHidden:true excludeCell:strongCell animated:false];
        };
        
        void (^interactionEnded)(void) = ^
        {
            __strong TGPhotoEditorCollectionView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.interactionEnded != nil)
                strongSelf.interactionEnded();
            
            __strong TGPhotoToolCell *strongCell = weakCell;
            if (strongCell != nil)
                [strongSelf setCellsHidden:false excludeCell:strongCell animated:true];
        };
        
        [(TGPhotoToolCell *)cell setPhotoTool:[toolsDataSource collectionView:self toolAtIndex:indexPath.row] landscape:_landscape nameWidth:_nameWidth changeBlock:changeBlock interactionBegan:interactionBegan interactionEnded:interactionEnded];
    }
    
    return cell;
}

- (void)setCellsHidden:(bool)hidden excludeCell:(UICollectionViewCell *)excludeCell animated:(bool)animated
{
    void (^block)(void) = ^
    {
        for (UICollectionViewCell *cell in self.visibleCells)
            cell.alpha = (cell == excludeCell || !hidden) ? 1.0f : 0.0f;
    };
    
    if (animated)
        [UIView animateWithDuration:0.15 animations:block];
    else
        block();
}

- (void)collectionView:(UICollectionView *)__unused collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<TGPhotoEditorCollectionViewFiltersDataSource> filtersDataSource = self.filtersDataSource;
    
    if ([filtersDataSource respondsToSelector:@selector(collectionView:didSelectFilterWithIndex:)])
    {
        bool vertical = false;
        if (self.frame.size.height > self.frame.size.width)
            vertical = true;
    
        CGFloat screenSize = 0;
        CGFloat contentSize = 0;
        CGFloat contentOffset = 0;
        CGFloat itemPosition = 0;
        CGFloat itemSize = 0;
        CGFloat targetOverlap = 0;
        CGFloat startInset = 0;
        CGFloat endInset = 0;
        
        CGFloat triggerOffset = 0;
        
        if (!vertical)
        {
            screenSize = self.frame.size.width;
            contentSize = self.contentSize.width;
            contentOffset = self.contentOffset.x;
            itemPosition = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath].frame.origin.x;
            itemSize = ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize.width;
            startInset = self.contentInset.left;
            endInset = self.contentInset.right;
            triggerOffset = TGPhotoEditorEdgeScrollTriggerOffset.x;
            targetOverlap = itemSize / 2 + ((UICollectionViewFlowLayout *)self.collectionViewLayout).minimumLineSpacing;
        }
        else
        {
            screenSize = self.frame.size.height;
            contentSize = self.contentSize.height;
            contentOffset = self.contentOffset.y;
            itemPosition = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath].frame.origin.y;
            itemSize = ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize.height;
            startInset = self.contentInset.top;
            endInset = self.contentInset.bottom;
            triggerOffset = TGPhotoEditorEdgeScrollTriggerOffset.y;
            targetOverlap = itemSize + 2 * ((UICollectionViewFlowLayout *)self.collectionViewLayout).minimumLineSpacing;
        }
        
        CGFloat itemsScreenPosition = itemPosition - contentOffset;
        
        if (itemsScreenPosition < triggerOffset)
        {
            CGFloat targetContentOffset = MAX(-startInset, itemPosition - targetOverlap);
            
            if (!vertical && targetContentOffset < startInset + itemSize)
                targetContentOffset = -startInset;
            
            if (contentOffset > targetContentOffset)
            {
                if (!vertical)
                    [self setContentOffset:CGPointMake(targetContentOffset, -self.contentInset.top) animated:YES];
                else
                    [self setContentOffset:CGPointMake(-self.contentInset.left, targetContentOffset) animated:YES];
                
                self.scrollEnabled = false;
            }
        }
        else if (itemsScreenPosition > screenSize - triggerOffset)
        {
            CGFloat targetContentOffset = MIN(contentSize - screenSize + endInset,
                                              itemPosition - screenSize + itemSize + targetOverlap);
            
            if (!vertical && targetContentOffset > contentSize - screenSize - endInset - itemSize)
                targetContentOffset = contentSize - screenSize + endInset;
            
            if (contentOffset < targetContentOffset)
            {
                if (!vertical)
                    [self setContentOffset:CGPointMake(targetContentOffset, -self.contentInset.top) animated:YES];
                else
                    [self setContentOffset:CGPointMake(-self.contentInset.left, targetContentOffset) animated:YES];
                
                self.scrollEnabled = false;
            }
        }
        
        [filtersDataSource collectionView:self didSelectFilterWithIndex:indexPath.row];
        
        _selectedItemIndexPath = indexPath;
        [self setSelectedItemIndexPath:indexPath];
    }
}

- (BOOL)collectionView:(UICollectionView *)__unused collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return false;
}

#pragma mark - Scroll View Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    id<UICollectionViewDelegate> realDelegate = self.realDelegate;
    
    if ([realDelegate respondsToSelector:_cmd])
        [realDelegate scrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)__unused scrollView
{
    self.scrollEnabled = true;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)__unused scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (self.interactionEnded != nil)
                self.interactionEnded();
        });
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)__unused scrollView
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.interactionEnded != nil)
            self.interactionEnded();
    });
}

@end
