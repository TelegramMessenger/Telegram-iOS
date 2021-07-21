#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PGRectangle;

@interface PGCameraShotMetadata : NSObject

@property (nonatomic, assign) CGFloat deviceAngle;
@property (nonatomic, strong) PGRectangle *rectangle;

+ (CGFloat)relativeDeviceAngleFromAngle:(CGFloat)angle orientation:(UIInterfaceOrientation)orientation;

@end
