#import <UIKit/UIKit.h>

@protocol TGModernGalleryScrollViewDelegate <NSObject>

- (bool)scrollViewShouldScrollWithTouchAtPoint:(CGPoint)point;
- (void)scrollViewBoundsChanged:(CGRect)bounds;

@end

@interface TGModernGalleryScrollView : UIScrollView

@property (nonatomic, weak) id<TGModernGalleryScrollViewDelegate> scrollDelegate;

- (void)setFrameAndBoundsInTransaction:(CGRect)frame bounds:(CGRect)bounds;

@end
