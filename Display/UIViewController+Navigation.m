#import "UIViewController+Navigation.h"

#import "RuntimeUtils.h"

static const void *UIViewControllerIgnoreAppearanceMethodInvocationsKey = &UIViewControllerIgnoreAppearanceMethodInvocationsKey;

@implementation UIViewController (Navigation)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillAppear:) newSelector:@selector(_65087dc8_viewWillAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidAppear:) newSelector:@selector(_65087dc8_viewDidAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillDisappear:) newSelector:@selector(_65087dc8_viewWillDisappear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidDisappear:) newSelector:@selector(_65087dc8_viewDidDisappear:)];
    });
}

- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations
{
    [self setAssociatedObject:@(ignoreAppearanceMethodInvocations) forKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey];
}

- (BOOL)ignoreAppearanceMethodInvocations
{
    return [[self associatedObjectForKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey] boolValue];
}

- (void)_65087dc8_viewWillAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillAppear:animated];
}

- (void)_65087dc8_viewDidAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidAppear:animated];
}

- (void)_65087dc8_viewWillDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillDisappear:animated];
}

- (void)_65087dc8_viewDidDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidDisappear:animated];
}

@end
