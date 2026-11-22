#import <UIKit/UIKit.h>
#import "UICollectionView+TGTransitioning.h"

@interface TGTransitionLayout : UICollectionViewTransitionLayout <TGTransitionAnimatorLayout>

@property (nonatomic) CGPoint toContentOffset;
@property (nonatomic, strong) void(^progressChanged)(CGFloat progress);
@property (nonatomic, strong) void(^transitionAlmostFinished)();

@end
