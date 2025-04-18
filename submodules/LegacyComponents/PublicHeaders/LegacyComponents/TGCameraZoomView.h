#import <UIKit/UIKit.h>

@interface TGCameraZoomView : UIView

@property (copy, nonatomic) void(^activityChanged)(bool active);

@property (nonatomic, assign) CGFloat zoomLevel;
- (void)setZoomLevel:(CGFloat)zoomLevel displayNeeded:(bool)displayNeeded;

- (void)interactionEnded;

- (bool)isActive;

- (void)hideAnimated:(bool)animated;

@end


@interface TGCameraZoomModeView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (copy, nonatomic) void(^zoomChanged)(CGFloat zoomLevel, bool done, bool animated);

@property (nonatomic, assign) CGFloat zoomLevel;
- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated;

- (void)setHidden:(bool)hidden animated:(bool)animated;

- (void)panGesture:(UIPanGestureRecognizer *)gestureRecognizer;

- (instancetype)initWithFrame:(CGRect)frame hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera minZoomLevel:(CGFloat)minZoomLevel maxZoomLevel:(CGFloat)maxZoomLevel;

@end


@interface TGCameraZoomWheelView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (copy, nonatomic) void(^panGesture)(UIPanGestureRecognizer *gestureRecognizer);

@property (nonatomic, assign) CGFloat zoomLevel;
- (void)setZoomLevel:(CGFloat)zoomLevel panning:(bool)panning;

- (void)setHidden:(bool)hidden animated:(bool)animated;

- (instancetype)initWithFrame:(CGRect)frame hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera;

@end
