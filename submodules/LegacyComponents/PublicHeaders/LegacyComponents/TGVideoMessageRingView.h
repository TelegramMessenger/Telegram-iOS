#import <UIKit/UIKit.h>

@interface TGVideoMessageShimmerView : UIView

- (void)updateAbsoluteRect:(CGRect)absoluteRect containerSize:(CGSize)containerSize;
    
@end


@interface TGVideoMessageRingView : UIView

@property (nonatomic, strong) UIColor *accentColor;
- (void)setValue:(CGFloat)value;

@end
