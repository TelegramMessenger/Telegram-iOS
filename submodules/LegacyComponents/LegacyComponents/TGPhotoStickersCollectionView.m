#import "TGPhotoStickersCollectionView.h"

#import "TGPhotoStickersCollectionLayout.h"
#import "TGPhotoStickersSectionHeader.h"
#import "TGPhotoStickersSectionHeaderView.h"

@interface TGPhotoStickersCollectionView ()
{
    NSMutableArray *_sectionHeaderViewQueue;
    NSMutableArray *_visibleSectionHeaderViews;
}

@end

@implementation TGPhotoStickersCollectionView

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self != nil)
    {
        _sectionHeaderViewQueue = [[NSMutableArray alloc] init];
        _visibleSectionHeaderViews = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)reloadData
{
    for (TGPhotoStickersSectionHeaderView *headerView in _visibleSectionHeaderViews)
    {
        [self enqueueSectionHeaderView:headerView];
    }
    [_visibleSectionHeaderViews removeAllObjects];
    
    [super reloadData];
}

- (TGPhotoStickersSectionHeaderView *)dequeueSectionHeaderView
{
    TGPhotoStickersSectionHeaderView *headerView = [_sectionHeaderViewQueue lastObject];
    if (headerView != nil)
    {
        [_sectionHeaderViewQueue removeLastObject];
        return headerView;
    }
    else
    {
        headerView = [[TGPhotoStickersSectionHeaderView alloc] init];
        if (self.headerTextColor != nil)
            [headerView setTextColor:self.headerTextColor];
        return headerView;
    }
}

- (void)enqueueSectionHeaderView:(TGPhotoStickersSectionHeaderView *)headerView
{
    [headerView removeFromSuperview];
    [_sectionHeaderViewQueue addObject:headerView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    UIEdgeInsets insets = self.contentInset;
    
    for (TGPhotoStickersSectionHeader *sectionHeader in [(TGPhotoStickersCollectionLayout *)self.collectionViewLayout sectionHeaders])
    {
        CGRect headerFloatingBounds = sectionHeader.floatingFrame;
        
        if (CGRectIntersectsRect(bounds, headerFloatingBounds))
        {
            TGPhotoStickersSectionHeaderView *headerView = nil;
            for (TGPhotoStickersSectionHeaderView *visibleHeaderView in _visibleSectionHeaderViews)
            {
                if (visibleHeaderView.index == sectionHeader.index)
                {
                    headerView = visibleHeaderView;
                    break;
                }
            }
            
            if (headerView == nil)
            {
                headerView = [self dequeueSectionHeaderView];
                headerView.index = sectionHeader.index;
                id<TGPhotoStickersCollectionViewDelegate> delegate = (id<TGPhotoStickersCollectionViewDelegate>)self.delegate;
                [delegate collectionView:self setupSectionHeaderView:headerView forSectionHeader:sectionHeader];
                [_visibleSectionHeaderViews addObject:headerView];

                [_headersParentView addSubview:headerView];
            }
            
            CGRect headerFrame = sectionHeader.bounds;
            headerFrame.origin.y = MIN(headerFloatingBounds.origin.y + 8.0f + headerFloatingBounds.size.height - headerFrame.size.height, MAX(headerFloatingBounds.origin.y, bounds.origin.y + insets.top));
            headerView.frame = [self convertRect:headerFrame toView:_headersParentView];
            [headerView.layer removeAllAnimations];
            
            CGFloat alpha = MAX(0.0f, MIN(1.0f, (headerView.frame.origin.y - 80.0f) / 24.0f));
            headerView.alpha = alpha;
        }
        else
        {
            NSInteger index = -1;
            for (TGPhotoStickersSectionHeaderView *headerView in _visibleSectionHeaderViews)
            {
                index++;
                if (headerView.index == sectionHeader.index)
                {
                    [self enqueueSectionHeaderView:headerView];
                    [_visibleSectionHeaderViews removeObjectAtIndex:index];
                    break;
                }
            }
        }
    }
}

@end
