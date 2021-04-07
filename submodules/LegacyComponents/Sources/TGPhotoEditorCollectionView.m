#import "TGPhotoEditorCollectionView.h"

#import "LegacyComponentsInternal.h"

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
    id <TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource = self.toolsDataSource;
    
    if ([toolsDataSource respondsToSelector:@selector(numberOfToolsInCollectionView:)])
        return [toolsDataSource numberOfToolsInCollectionView:self];
    
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)__unused collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource = self.toolsDataSource;
    
    UICollectionViewCell *cell = nil;
    
    if ([toolsDataSource respondsToSelector:@selector(collectionView:toolAtIndex:)])
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
