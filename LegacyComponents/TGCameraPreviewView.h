#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class PGCamera;

@interface TGCameraPreviewView : UIView

@property (nonatomic, readonly) PGCamera *camera;
@property (nonatomic, readonly) AVCaptureConnection *captureConnection;

- (void)setupWithCamera:(PGCamera *)camera;
- (void)invalidate;

- (void)beginTransitionWithSnapshotImage:(UIImage *)image animated:(bool)animated;
- (void)endTransitionAnimated:(bool)animated;

- (void)beginResetTransitionAnimated:(bool)animated;
- (void)endResetTransitionAnimated:(bool)animated;

- (void)fadeInAnimated:(bool)animated;
- (void)fadeOutAnimated:(bool)animated;

- (void)blink;

- (CGPoint)devicePointOfInterestForPoint:(CGPoint)point;

@end
