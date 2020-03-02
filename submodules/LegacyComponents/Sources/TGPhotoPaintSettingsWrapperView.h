#import <UIKit/UIKit.h>

@interface TGPhotoPaintSettingsWrapperView : UIButton

@property (nonatomic, copy) void (^pressed)(CGPoint location);
@property (nonatomic, copy) bool (^suppressTouchAtPoint)(CGPoint location);

@end
