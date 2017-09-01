#import <UIKit/UIKit.h>

@interface TGVideoMessageTrimView : UIControl

@property (nonatomic, copy) void(^didBeginEditing)(bool start);
@property (nonatomic, copy) void(^startHandleMoved)(CGPoint translation);
@property (nonatomic, copy) void(^endHandleMoved)(CGPoint translation);
@property (nonatomic, copy) void(^didEndEditing)(bool start);

@property (nonatomic, assign) bool trimmingEnabled;

- (void)setTrimming:(bool)trimming animated:(bool)animated;

@end
