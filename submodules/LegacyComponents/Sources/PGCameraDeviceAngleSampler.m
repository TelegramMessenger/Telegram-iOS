#import "PGCameraDeviceAngleSampler.h"

#import <CoreMotion/CoreMotion.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "LegacyComponentsInternal.h"

@interface PGCameraDeviceAngleSampler ()
{
    CMMotionManager *_motionManager;
    NSOperationQueue *_motionQueue;
}
@end

@implementation PGCameraDeviceAngleSampler

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _deviceOrientation = UIDeviceOrientationUnknown;
        
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1.0f;
        _motionManager.deviceMotionUpdateInterval = 1.0f;
        _motionManager.gyroUpdateInterval = 1.0f;
        _motionManager.magnetometerUpdateInterval = 1.0f;
        _motionQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self stopMeasuring];
}

- (bool)isMeasuring
{
    return [_motionManager isDeviceMotionActive];
}

- (void)stopMeasuring
{
    [_motionManager stopDeviceMotionUpdates];
}

- (void)startMeasuring
{    
    if (![_motionManager isDeviceMotionAvailable])
        return;
    
    __weak PGCameraDeviceAngleSampler *weakSelf = self;
    [_motionManager startAccelerometerUpdatesToQueue:_motionQueue withHandler:^(CMAccelerometerData *accelerometerData, __unused NSError *error)
    {
        __strong PGCameraDeviceAngleSampler *strongSelf = weakSelf;
        if (strongSelf == nil || accelerometerData == nil || error != nil)
            return;
        
        CMAcceleration acceleration = accelerometerData.acceleration;
        CGFloat xx = -acceleration.x;
        CGFloat yy = acceleration.y;
        CGFloat z = acceleration.z;
        CGFloat angle = atan2(yy, xx);
        
        UIDeviceOrientation deviceOrientation = strongSelf.deviceOrientation;
        CGFloat absoluteZ = fabs(z);
        
        if (deviceOrientation == UIDeviceOrientationFaceUp || deviceOrientation == UIDeviceOrientationFaceDown)
        {
            if (absoluteZ < 0.845f)
            {
                if (angle < -2.6f)
                    deviceOrientation = UIDeviceOrientationLandscapeRight;
                else if (angle > -2.05f && angle < -1.1f)
                    deviceOrientation = UIDeviceOrientationPortrait;
                else if (angle > -0.48f && angle < 0.48f)
                    deviceOrientation = UIDeviceOrientationLandscapeLeft;
                else if (angle > 1.08f && angle < 2.08f)
                    deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
            }
            else if (z < 0.f)
            {
                deviceOrientation = UIDeviceOrientationFaceUp;
            }
            else if (z > 0.f)
            {
                deviceOrientation = UIDeviceOrientationFaceDown;
            }
        }
        else
        {
            if (z > 0.875f)
            {
                deviceOrientation = UIDeviceOrientationFaceDown;
            }
            else if (z < -0.875f)
            {
                deviceOrientation = UIDeviceOrientationFaceUp;
            }
            else
            {
                switch (deviceOrientation)
                {
                    case UIDeviceOrientationLandscapeLeft:
                        if (angle < -1.07f) deviceOrientation = UIDeviceOrientationPortrait;
                        if (angle > 1.08f) deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
                        break;
                        
                    case UIDeviceOrientationLandscapeRight:
                        if (angle < 0.f && angle > -2.05f) deviceOrientation = UIDeviceOrientationPortrait;
                        if (angle > 0.f && angle < 2.05f) deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
                        break;
                        
                    case UIDeviceOrientationPortraitUpsideDown:
                        if (angle > 2.66f) deviceOrientation = UIDeviceOrientationLandscapeRight;
                        if (angle < 0.48f) deviceOrientation = UIDeviceOrientationLandscapeLeft;
                        break;
                        
                    case UIDeviceOrientationPortrait:
                    default:
                        if (angle > -0.47f) deviceOrientation = UIDeviceOrientationLandscapeLeft;
                        if (angle < -2.64f) deviceOrientation = UIDeviceOrientationLandscapeRight;
                        break;
                }
            }
        }
        
        if (deviceOrientation != strongSelf.deviceOrientation)
        {
            strongSelf->_deviceOrientation = deviceOrientation;
            
            TGDispatchOnMainThread(^
            {
                if (strongSelf.deviceOrientationChanged != nil)
                    strongSelf.deviceOrientationChanged(deviceOrientation);
            });
        }

    }];
    
    [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical toQueue:_motionQueue withHandler:^(CMDeviceMotion *motion, __unused NSError *error)
    {
        __strong PGCameraDeviceAngleSampler *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_currentDeviceAngle = TGRadiansToDegrees((CGFloat)(atan2(motion.gravity.x, motion.gravity.y) - M_PI)) * -1;
    }];
}

@end
