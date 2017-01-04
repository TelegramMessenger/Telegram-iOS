#import "UINavigationItem+Proxy.h"

#import "NSBag.h"
#import "RuntimeUtils.h"
#import "NSWeakReference.h"

static const void *sourceItemKey = &sourceItemKey;
static const void *targetItemKey = &targetItemKey;
static const void *setTitleListenerBagKey = &setTitleListenerBagKey;
static const void *setTitleViewListenerBagKey = &setTitleViewListenerBagKey;
static const void *setLeftBarButtonItemListenerBagKey = &setLeftBarButtonItemListenerBagKey;
static const void *setRightBarButtonItemListenerBagKey = &setRightBarButtonItemListenerBagKey;
static const void *setBadgeListenerBagKey = &setBadgeListenerBagKey;

@implementation UINavigationItem (Proxy)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setTitle:) newSelector:@selector(_ac91f40f_setTitle:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setTitleView:) newSelector:@selector(_ac91f40f_setTitleView:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setLeftBarButtonItem:) newSelector:@selector(_ac91f40f_setLeftBarButtonItem:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setLeftBarButtonItem:animated:) newSelector:@selector(_ac91f40f_setLeftBarButtonItem:animated:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setRightBarButtonItem:) newSelector:@selector(_ac91f40f_setRightBarButtonItem:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setRightBarButtonItem:animated:) newSelector:@selector(_ac91f40f_setRightBarButtonItem:animated:)];
    });
}

- (void)_ac91f40f_setTitle:(NSString *)title
{
    [self _ac91f40f_setTitle:title];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setTitle:title];
    } else {
        [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] enumerateItems:^(UINavigationItemSetTitleListener listener) {
            listener(title);
        }];
    }
}

- (void)_ac91f40f_setTitleView:(UIView *)titleView
{
    [self _ac91f40f_setTitleView:titleView];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setTitleView:titleView];
    } else {
        [(NSBag *)[self associatedObjectForKey:setTitleViewListenerBagKey] enumerateItems:^(UINavigationItemSetTitleViewListener listener) {
            listener(titleView);
        }];
    }
}

- (void)_ac91f40f_setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem {
    [self setLeftBarButtonItem:leftBarButtonItem animated:false];
}

- (void)_ac91f40f_setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem animated:(BOOL)animated
{
    [self _ac91f40f_setLeftBarButtonItem:leftBarButtonItem animated:animated];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setLeftBarButtonItem:leftBarButtonItem animated:animated];
    } else {
        [(NSBag *)[self associatedObjectForKey:setLeftBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
            listener(leftBarButtonItem, animated);
        }];
    }
}

- (void)_ac91f40f_setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem {
    [self setRightBarButtonItem:rightBarButtonItem animated:false];
}

- (void)_ac91f40f_setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated
{
    [self _ac91f40f_setRightBarButtonItem:rightBarButtonItem animated:animated];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setRightBarButtonItem:rightBarButtonItem animated:animated];
    } else {
        [(NSBag *)[self associatedObjectForKey:setRightBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
            listener(rightBarButtonItem, animated);
        }];
    }
}

- (void)setTargetItem:(UINavigationItem *)targetItem {
    NSWeakReference *previousSourceItem = [targetItem associatedObjectForKey:sourceItemKey];
    [(UINavigationItem *)previousSourceItem.value setAssociatedObject:nil forKey:targetItemKey associationPolicy:NSObjectAssociationPolicyRetain];
    
    [self setAssociatedObject:targetItem forKey:targetItemKey associationPolicy:NSObjectAssociationPolicyRetain];
    [targetItem setAssociatedObject:[[NSWeakReference alloc] initWithValue:self] forKey:sourceItemKey associationPolicy:NSObjectAssociationPolicyRetain];
    
    if ((targetItem.title != nil) != (self.title != nil) || ![targetItem.title isEqualToString:self.title]) {
        targetItem.title = self.title;
    }
    if (targetItem.titleView != self.titleView) {
        [targetItem setTitleView:self.titleView];
    }
    if (targetItem.leftBarButtonItem != self.leftBarButtonItem) {
        [targetItem setLeftBarButtonItem:self.leftBarButtonItem];
    }
    if (targetItem.rightBarButtonItem != self.rightBarButtonItem) {
        [targetItem setRightBarButtonItem:self.rightBarButtonItem];
    }
    if (targetItem.backBarButtonItem != self.backBarButtonItem) {
        [targetItem setBackBarButtonItem:self.backBarButtonItem];
    }
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

@implementation UITabBarItem (Proxy)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UITabBarItem class] currentSelector:@selector(setBadgeValue:) newSelector:@selector(_ac91f40f_setBadgeValue:)];
    });
}

NSInteger UITabBarItem_addSetBadgeListener(UITabBarItem *item, UITabBarItemSetBadgeListener listener) {
    NSBag *bag = [item associatedObjectForKey:setBadgeListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [item setAssociatedObject:bag forKey:setBadgeListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetBadgeListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setBadgeListenerBagKey] removeItem:key];
}

- (void)_ac91f40f_setBadgeValue:(NSString *)value {
    [self _ac91f40f_setBadgeValue:value];
    
    [(NSBag *)[self associatedObjectForKey:setBadgeListenerBagKey] enumerateItems:^(UITabBarItemSetBadgeListener listener) {
        listener(value);
    }];
}

@end
