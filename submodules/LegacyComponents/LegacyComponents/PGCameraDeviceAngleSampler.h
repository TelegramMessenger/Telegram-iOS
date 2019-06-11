#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PGCameraDeviceAngleSampler : NSObject

@property (nonatomic, copy) void(^deviceOrientationChanged)(UIDeviceOrientation orientation);

@property (nonatomic, readonly) UIDeviceOrientation deviceOrientation;
@property (nonatomic, readonly) bool isMeasuring;
@property (nonatomic, readonly) CGFloat currentDeviceAngle;

- (void)startMeasuring;
- (void)stopMeasuring;

@end
