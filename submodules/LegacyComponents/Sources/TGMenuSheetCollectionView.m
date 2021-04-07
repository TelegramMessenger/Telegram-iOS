#import "TGMenuSheetCollectionView.h"

@implementation TGMenuSheetCollectionView

- (void)setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:contentOffset];
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if (!self.isTracking && contentOffset.y < -self.contentInset.top)
        return;
    
    [super setContentOffset:contentOffset animated:animated];
}

@end
