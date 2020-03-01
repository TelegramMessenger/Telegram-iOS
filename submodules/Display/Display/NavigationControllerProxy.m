#import "NavigationControllerProxy.h"

#import "NavigationBarProxy.h"

@implementation NavigationControllerProxy

- (instancetype)init
{
    self = [super initWithNavigationBarClass:[NavigationBarProxy class] toolbarClass:[UIToolbar class]];
    if (self != nil) {
    }
    return self;
}

@end
