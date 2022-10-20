#import "TGViewController+TGRecursiveEnumeration.h"

@implementation UIViewController (TGRecursiveEnumeration)

- (void)enumerateChildViewControllersRecursivelyWithBlock:(void (^)(UIViewController *))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    enumerationBlock(self);
    for (UIViewController *childViewController in self.childViewControllers)
        [childViewController enumerateChildViewControllersRecursivelyWithBlock:enumerationBlock];
}

@end


@implementation TGViewController (TGRecursiveEnumeration)

- (void)enumerateChildViewControllersRecursivelyWithBlock:(void (^)(UIViewController *))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    if (self.associatedWindowStack.count > 0)
    {
        for (UIWindow *window in self.associatedWindowStack)
            [window.rootViewController enumerateChildViewControllersRecursivelyWithBlock:enumerationBlock];
    }
    
    enumerationBlock(self);
    for (UIViewController *childViewController in self.childViewControllers)
        [childViewController enumerateChildViewControllersRecursivelyWithBlock:enumerationBlock];
}

@end


@implementation UINavigationController (TGRecursiveEnumeration)

- (void)enumerateChildViewControllersRecursivelyWithBlock:(void (^)(UIViewController *))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    enumerationBlock(self);
    [self.topViewController enumerateChildViewControllersRecursivelyWithBlock:enumerationBlock];
}

@end


@implementation UITabBarController (TGRecursiveEnumeration)

- (void)enumerateChildViewControllersRecursivelyWithBlock:(void (^)(UIViewController *))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    enumerationBlock(self);
    [self.selectedViewController enumerateChildViewControllersRecursivelyWithBlock:enumerationBlock];
}

@end

