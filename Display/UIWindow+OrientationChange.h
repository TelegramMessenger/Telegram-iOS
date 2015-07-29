#import <UIKit/UIKit.h>

@interface UIWindow (OrientationChange)

- (bool)isRotating;

@end

@interface UINavigationBar (Condensed)

- (void)setCondensed:(BOOL)condensed;

@end
