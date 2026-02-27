#import <UIKit/UIKit.h>

@interface TGPhotoEditorLinearBlurView : UIView

@property (nonatomic, copy) void (^valueChanged)(CGPoint centerPoint, CGFloat falloff, CGFloat size, CGFloat angle);

@property (nonatomic, readonly) bool isTracking;
@property (nonatomic, copy) void(^interactionEnded)(void);

@property (nonatomic, assign) CGSize actualAreaSize;

@property (nonatomic, assign) CGPoint centerPoint;
@property (nonatomic, assign) CGFloat falloff;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat angle;

@end
