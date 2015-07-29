#import "UIBarButtonItem+Proxy.h"

#import "NSBag.h"
#import "RuntimeUtils.h"

static const void *setEnabledListenerBagKey = &setEnabledListenerBagKey;
static const void *setTitleListenerBagKey = &setTitleListenerBagKey;

@implementation UIBarButtonItem (Proxy)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIBarButtonItem class] currentSelector:@selector(setEnabled:) newSelector:@selector(_c1e56039_setEnabled:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIBarButtonItem class] currentSelector:@selector(setTitle:) newSelector:@selector(_c1e56039_setTitle:)];
    });
}

- (void)_c1e56039_setEnabled:(BOOL)enabled
{
    [self _c1e56039_setEnabled:enabled];
    
    [(NSBag *)[self associatedObjectForKey:setEnabledListenerBagKey] enumerateItems:^(UIBarButtonItemSetEnabledListener listener)
    {
        listener(enabled);
    }];
}

- (void)_c1e56039_setTitle:(NSString *)title
{
    [self _c1e56039_setTitle:title];
    
    [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] enumerateItems:^(UIBarButtonItemSetTitleListener listener)
    {
        listener(title);
    }];
}

- (void)performActionOnTarget
{
    NSAssert(self.target != nil, @"self.target != nil");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.action];
#pragma clang diagnostic pop
}

- (NSInteger)addSetTitleListener:(UIBarButtonItemSetTitleListener)listener
{
    NSBag *bag = [self associatedObjectForKey:setTitleListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setTitleListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetTitleListener:(NSInteger)key
{
    [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] removeItem:key];
}

- (NSInteger)addSetEnabledListener:(UIBarButtonItemSetEnabledListener)listener
{
    NSBag *bag = [self associatedObjectForKey:setEnabledListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setEnabledListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetEnabledListener:(NSInteger)key
{
    [(NSBag *)[self associatedObjectForKey:setEnabledListenerBagKey] removeItem:key];
}

@end
