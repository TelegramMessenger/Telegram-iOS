#import <UIKit/UIKit.h>

@interface TGLocationWavesView : UIView

@property (nonatomic, strong) UIColor *color;

- (void)invalidate;
- (void)start;
- (void)stop;

@end
