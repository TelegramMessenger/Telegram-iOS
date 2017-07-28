#import <UIKit/UIKit.h>

@interface TGPhotoCropRotationView : UIControl

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, assign) CGFloat angle;

@property (nonatomic, readonly) bool isTracking;

@property (nonatomic, copy) bool(^shouldBeginChanging)(void);
@property (nonatomic, copy) void(^didBeginChanging)(void);
@property (nonatomic, copy) void(^angleChanged)(CGFloat angle, bool resetting);
@property (nonatomic, copy) void(^didEndChanging)(void);

- (void)setAngle:(CGFloat)angle animated:(bool)animated;
- (void)resetAnimated:(bool)animated;

@end
