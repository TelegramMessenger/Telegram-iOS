#import <UIKit/UIKit.h>

@interface TGModernGalleryZoomableScrollView : UIScrollView

@property (nonatomic) CGFloat normalZoomScale;

@property (nonatomic, copy) void (^singleTapped)();
@property (nonatomic, copy) void (^doubleTapped)(CGPoint point);

- (instancetype)initWithFrame:(CGRect)frame hasDoubleTap:(bool)hasDoubleTap;

@end
