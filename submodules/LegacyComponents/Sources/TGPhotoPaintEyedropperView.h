#import <UIKit/UIKit.h>

@interface TGPhotoPaintEyedropperView : UIView

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) void(^locationChanged)(CGPoint, bool);

- (void)update;
- (void)present;
- (void)dismiss;

@end

