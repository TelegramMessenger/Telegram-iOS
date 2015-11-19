#import <UIKit/UIKit.h>

@interface UIWindow (OrientationChange)

- (bool)isRotating;
+ (void)addPostDeviceOrientationDidChangeBlock:(void (^)())block;
+ (bool)isDeviceRotating;

- (void)_updateToInterfaceOrientation:(int)arg1 duration:(double)arg2 force:(BOOL)arg3;

@end

@interface UINavigationBar (Condensed)

- (void)setCondensed:(BOOL)condensed;

@end
