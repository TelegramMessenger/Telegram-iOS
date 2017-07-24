#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PGCameraShotMetadata : NSObject

@property (nonatomic, assign) CGFloat deviceAngle;

+ (CGFloat)relativeDeviceAngleFromAngle:(CGFloat)angle orientation:(UIInterfaceOrientation)orientation;

@end
