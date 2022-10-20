#import "UICollectionView+Utils.h"

@implementation UICollectionView (Utils)

- (NSArray *)indexPathsForElementsInRect:(CGRect)rect
{
    NSArray *allLayoutAttributes = [self.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0)
        return nil;
    
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes)
    {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    
    return indexPaths;
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect direction:(UICollectionViewScrollDirection)direction removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler
{
    if (CGRectIntersectsRect(newRect, oldRect))
    {
        if (direction == UICollectionViewScrollDirectionHorizontal)
        {
            CGFloat oldMaxX = CGRectGetMaxX(oldRect);
            CGFloat oldMinX = CGRectGetMinX(oldRect);
            CGFloat newMaxX = CGRectGetMaxX(newRect);
            CGFloat newMinX = CGRectGetMinX(newRect);
            if (newMaxX > oldMaxX)
            {
                CGRect rectToAdd = CGRectMake(oldMaxX, newRect.origin.y, (newMaxX - oldMaxX), newRect.size.height);
                addedHandler(rectToAdd);
            }
            if (oldMinX > newMinX)
            {
                CGRect rectToAdd = CGRectMake(newMinX, newRect.origin.y, (oldMinX - newMinX), newRect.size.height);
                addedHandler(rectToAdd);
            }
            if (newMaxX < oldMaxX)
            {
                CGRect rectToRemove = CGRectMake(newMaxX, newRect.origin.y, (oldMaxX - newMaxX), newRect.size.height);
                removedHandler(rectToRemove);
            }
            if (oldMinX < newMinX)
            {
                CGRect rectToRemove = CGRectMake(oldMinX, newRect.origin.y, (newMinX - oldMinX), newRect.size.height);
                removedHandler(rectToRemove);
            }
        }
        else
        {
            CGFloat oldMaxY = CGRectGetMaxY(oldRect);
            CGFloat oldMinY = CGRectGetMinY(oldRect);
            CGFloat newMaxY = CGRectGetMaxY(newRect);
            CGFloat newMinY = CGRectGetMinY(newRect);
            if (newMaxY > oldMaxY)
            {
                CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
                addedHandler(rectToAdd);
            }
            if (oldMinY > newMinY)
            {
                CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
                addedHandler(rectToAdd);
            }
            if (newMaxY < oldMaxY)
            {
                CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
                removedHandler(rectToRemove);
            }
            if (oldMinY < newMinY)
            {
                CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
                removedHandler(rectToRemove);
            }
        }
    }
    else
    {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

@end
