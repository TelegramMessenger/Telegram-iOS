#import "UINavigationItem+Proxy.h"

#import "NSBag.h"
#import "RuntimeUtils.h"

static const void *setTitleListenerBagKey = &setTitleListenerBagKey;
static const void *setTitleViewListenerBagKey = &setTitleViewListenerBagKey;
static const void *setLeftBarButtonItemListenerBagKey = &setLeftBarButtonItemListenerBagKey;
static const void *setRightBarButtonItemListenerBagKey = &setRightBarButtonItemListenerBagKey;

@implementation UINavigationItem (Proxy)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setTitle:) newSelector:@selector(_ac91f40f_setTitle:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setTitleView:) newSelector:@selector(_ac91f40f_setTitleView:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setLeftBarButtonItem:) newSelector:@selector(_ac91f40f_setLeftBarButtonItem:animated:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setRightBarButtonItem:) newSelector:@selector(_ac91f40f_setRightBarButtonItem:animated:)];
    });
}

- (void)_ac91f40f_setTitle:(NSString *)title
{
    [self _ac91f40f_setTitle:title];
    
    [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] enumerateItems:^(UINavigationItemSetTitleListener listener) {
        listener(title);
    }];
}

- (void)_ac91f40f_setTitleView:(UIView *)titleView
{
    [self _ac91f40f_setTitleView:titleView];
    
    [(NSBag *)[self associatedObjectForKey:setTitleViewListenerBagKey] enumerateItems:^(UINavigationItemSetTitleViewListener listener) {
        listener(titleView);
    }];
}

- (void)_ac91f40f_setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem animated:(BOOL)animated
{
    [self _ac91f40f_setLeftBarButtonItem:leftBarButtonItem animated:animated];
    
    [(NSBag *)[self associatedObjectForKey:setLeftBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
        listener(leftBarButtonItem, animated);
    }];
}

- (void)_ac91f40f_setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated
{
    [self _ac91f40f_setRightBarButtonItem:rightBarButtonItem animated:animated];
    
    [(NSBag *)[self associatedObjectForKey:setRightBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
        listener(rightBarButtonItem, animated);
    }];
}

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener)listener
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

- (NSInteger)addSetTitleViewListener:(UINavigationItemSetTitleViewListener)listener
{
    NSBag *bag = [self associatedObjectForKey:setTitleViewListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setTitleViewListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetTitleViewListener:(NSInteger)key
{
    [(NSBag *)[self associatedObjectForKey:setTitleViewListenerBagKey] removeItem:key];
}

- (NSInteger)addSetLeftBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener
{
    NSBag *bag = [self associatedObjectForKey:setLeftBarButtonItemListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setLeftBarButtonItemListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetLeftBarButtonItemListener:(NSInteger)key
{
    [(NSBag *)[self associatedObjectForKey:setLeftBarButtonItemListenerBagKey] removeItem:key];
}

- (NSInteger)addSetRightBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener
{
    NSBag *bag = [self associatedObjectForKey:setRightBarButtonItemListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setRightBarButtonItemListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetRightBarButtonItemListener:(NSInteger)key
{
    [(NSBag *)[self associatedObjectForKey:setRightBarButtonItemListenerBagKey] removeItem:key];
}

@end
