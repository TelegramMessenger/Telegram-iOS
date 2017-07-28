#import <UIKit/UIKit.h>

@interface TGCameraZoomView : UIView

@property (copy, nonatomic) void(^activityChanged)(bool active);

@property (nonatomic, assign) CGFloat zoomLevel;
- (void)setZoomLevel:(CGFloat)zoomLevel displayNeeded:(bool)displayNeeded;

- (void)interactionEnded;

- (bool)isActive;

- (void)hideAnimated:(bool)animated;

@end
