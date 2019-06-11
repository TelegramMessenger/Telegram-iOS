#import "TGDraggableCollectionViewFlowLayout.h"

@implementation TGDraggableCollectionViewFlowLayout

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (itemIndexPath == nil)
        return nil;
    
    UICollectionViewLayoutAttributes *attributes = [super initialLayoutAttributesForAppearingItemAtIndexPath:itemIndexPath];
    attributes.transform3D = CATransform3DMakeTranslation(0, 0, itemIndexPath.row + 1);
    attributes.zIndex = itemIndexPath.row + 1;
    
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (itemIndexPath == nil)
        return nil;
    
    UICollectionViewLayoutAttributes *attributes = [super layoutAttributesForItemAtIndexPath:itemIndexPath];
    attributes.transform3D = CATransform3DMakeTranslation(0, 0, 1000 + itemIndexPath.row + 1);
    attributes.zIndex = 1000 + itemIndexPath.row + 1;
    
    return attributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *originalAttributes = [super layoutAttributesForElementsInRect:rect];
    
    if (self.destinationIndexPath == nil)
    {
        if (self.hiddenIndexPath == nil)
            return originalAttributes;
        
        for (UICollectionViewLayoutAttributes *layoutAttributes in originalAttributes)
        {
            if (layoutAttributes.representedElementCategory != UICollectionElementCategoryCell)
                continue;
            
            if ([layoutAttributes.indexPath isEqual:self.hiddenIndexPath])
                layoutAttributes.hidden = true;
        }
        return originalAttributes;
    }
    
    for (UICollectionViewLayoutAttributes *layoutAttributes in originalAttributes)
    {
        if (layoutAttributes.representedElementCategory != UICollectionElementCategoryCell)
            continue;
        
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        if ([indexPath isEqual:self.hiddenIndexPath])
            layoutAttributes.hidden = true;
        
        if ([indexPath isEqual:self.destinationIndexPath])
        {
            layoutAttributes.indexPath = self.sourceIndexPath;
        }
        else
        {
            if (indexPath.item <= self.sourceIndexPath.item && indexPath.item > self.destinationIndexPath.item)
                layoutAttributes.indexPath = [NSIndexPath indexPathForItem:indexPath.item - 1 inSection:indexPath.section];
            else if (indexPath.item >= self.sourceIndexPath.item && indexPath.item < self.destinationIndexPath.item)
                layoutAttributes.indexPath = [NSIndexPath indexPathForItem:indexPath.item + 1 inSection:indexPath.section];
        }
    }
    
    return originalAttributes;
}

@end
