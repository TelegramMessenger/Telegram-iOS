#import <UIKit/UIKit.h>

#import "TGPasscodeBackground.h"

@interface TGPasscodePinDotView : UIView

@property (nonatomic) bool filled;

- (void)setFilled:(bool)filled animated:(bool)animated;

- (void)setBackground:(id<TGPasscodeBackground>)background;
- (void)setAbsoluteOffset:(CGPoint)absoluteOffset;

@end
