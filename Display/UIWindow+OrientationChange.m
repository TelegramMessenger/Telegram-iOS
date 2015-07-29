#import "UIWindow+OrientationChange.h"

#import "RuntimeUtils.h"
#import "NotificationCenterUtils.h"

static const void *isRotatingKey = &isRotatingKey;

@implementation UIWindow (OrientationChange)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [NotificationCenterUtils addNotificationHandler:^bool(NSString *name, id object, NSDictionary *userInfo)
        {
            if ([name isEqualToString:@"UIWindowWillRotateNotification"])
            {
                [(UIWindow *)object setRotating:true];
                
                if (NSClassFromString(@"NSUserActivity") == NULL)
                {
                    UIInterfaceOrientation orientation = [userInfo[@"UIWindowNewOrientationUserInfoKey"] integerValue];
                    CGSize screenSize = [UIScreen mainScreen].bounds.size;
                    if (screenSize.width > screenSize.height)
                    {
                        CGFloat tmp = screenSize.height;
                        screenSize.height = screenSize.width;
                        screenSize.width = tmp;
                    }
                    CGSize windowSize = CGSizeZero;
                    CGFloat windowRotation = 0.0;
                    bool landscape = false;
                    switch (orientation) {
                        case UIInterfaceOrientationPortrait:
                            windowSize = screenSize;
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:
                            windowRotation = (CGFloat)(M_PI);
                            windowSize = screenSize;
                            break;
                        case UIInterfaceOrientationLandscapeLeft:
                            landscape = true;
                            windowRotation = (CGFloat)(-M_PI / 2.0);
                            windowSize = CGSizeMake(screenSize.height, screenSize.width);
                            break;
                        case UIInterfaceOrientationLandscapeRight:
                            landscape = true;
                            windowRotation = (CGFloat)(M_PI / 2.0);
                            windowSize = CGSizeMake(screenSize.height, screenSize.width);
                            break;
                        default:
                            break;
                    }
                    
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        CGAffineTransform transform = CGAffineTransformIdentity;
                        transform = CGAffineTransformRotate(transform, windowRotation);
                        ((UIWindow *)object).transform = transform;
                        ((UIWindow *)object).bounds = CGRectMake(0.0f, 0.0f, windowSize.width, windowSize.height);
                    }];
                }
            }
            else if ([name isEqualToString:@"UIWindowDidRotateNotification"])
            {
                [(UIWindow *)object setRotating:false];
            }
            
            return false;
        }];
    });
}

- (void)setRotating:(bool)rotating
{
    [self setAssociatedObject:@(rotating) forKey:isRotatingKey];
}

- (bool)isRotating
{
    return [[self associatedObjectForKey:isRotatingKey] boolValue];
}

@end
