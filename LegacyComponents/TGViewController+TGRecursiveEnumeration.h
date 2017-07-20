#import <LegacyComponents/TGViewController.h>

@interface TGViewController (TGRecursiveEnumeration)

- (void)enumerateChildViewControllersRecursivelyWithBlock:(void (^)(UIViewController *))enumerationBlock;

@end
