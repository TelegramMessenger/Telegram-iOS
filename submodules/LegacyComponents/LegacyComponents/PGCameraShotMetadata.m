#import "PGCameraShotMetadata.h"

@implementation PGCameraShotMetadata

+ (CGFloat)relativeDeviceAngleFromAngle:(CGFloat)angle orientation:(UIInterfaceOrientation)orientation
{
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            angle -= 180.0f;
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            angle -= 90.0f;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            angle -= 270.0f;
            break;
            
        default:
            if (angle > 180.0f)
                angle = angle - 360.0f;
            break;
    }
    
    if (ABS(angle) < 45.0f)
        return angle;
    
    return 0.0f;
}

@end
