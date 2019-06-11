#import "TGMediaAssetsMomentsCollectionLayout.h"

#import "TGMediaAssetsMomentsSectionHeader.h"

@interface TGMediaAssetsMomentsCollectionLayout ()
{
    bool _updatingCollectionItems;
    NSArray *_sectionHeaders;
}
@end

@implementation TGMediaAssetsMomentsCollectionLayout

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (_updatingCollectionItems || itemIndexPath.section != 0)
        return [super initialLayoutAttributesForAppearingItemAtIndexPath:itemIndexPath];
    
    return nil;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (_updatingCollectionItems || itemIndexPath.section != 0)
        return [super finalLayoutAttributesForDisappearingItemAtIndexPath:itemIndexPath];
    
    return [self layoutAttributesForItemAtIndexPath:itemIndexPath];
}

- (void)prepareLayout
{
    [super prepareLayout];
    
    NSMutableArray *sectionHeaders = [[NSMutableArray alloc] init];
    
    id<UICollectionViewDataSource> dataSource = self.collectionView.dataSource;
    NSUInteger numberOfSections = 1;
    if ([dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)])
        numberOfSections = [dataSource numberOfSectionsInCollectionView:self.collectionView];
    
    for (NSUInteger i = 0; i < numberOfSections; i++)
    {
        NSUInteger itemCount = [dataSource collectionView:self.collectionView numberOfItemsInSection:i];
        if (itemCount != 0)
        {
            UICollectionViewLayoutAttributes *firstItemAttributes = [self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:i]];
            UICollectionViewLayoutAttributes *lastItemAttributes = [self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:itemCount - 1 inSection:i]];
            
            TGMediaAssetsMomentsSectionHeader *sectionHeader = [[TGMediaAssetsMomentsSectionHeader alloc] init];
            sectionHeader.index = i;
            CGFloat headerHeight = 48.0f;
            sectionHeader.bounds = CGRectMake(0.0f, 0.0f, self.collectionView.bounds.size.width, headerHeight);
            sectionHeader.floatingFrame = CGRectMake(0.0f, firstItemAttributes.frame.origin.y - sectionHeader.bounds.size.height, sectionHeader.bounds.size.width, CGRectGetMaxY(lastItemAttributes.frame) - (firstItemAttributes.frame.origin.y - sectionHeader.bounds.size.height));
            [sectionHeaders addObject:sectionHeader];
        }
    }
    
    _sectionHeaders = sectionHeaders;
}

- (NSArray *)sectionHeaders
{
    return _sectionHeaders;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)__unused newBounds
{
    return false;
}

@end
