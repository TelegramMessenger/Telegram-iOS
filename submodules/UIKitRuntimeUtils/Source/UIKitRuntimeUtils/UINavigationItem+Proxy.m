#import "UINavigationItem+Proxy.h"

#import "NSBag.h"
#import <ObjCRuntimeUtils/RuntimeUtils.h>
#import "NSWeakReference.h"

static const void *sourceItemKey = &sourceItemKey;
static const void *targetItemKey = &targetItemKey;
static const void *setTitleListenerBagKey = &setTitleListenerBagKey;
static const void *setImageListenerBagKey = &setImageListenerBagKey;
static const void *setSelectedImageListenerBagKey = &setSelectedImageListenerBagKey;
static const void *setTitleViewListenerBagKey = &setTitleViewListenerBagKey;
static const void *setLeftBarButtonItemListenerBagKey = &setLeftBarButtonItemListenerBagKey;
static const void *setRightBarButtonItemListenerBagKey = &setRightBarButtonItemListenerBagKey;
static const void *setMultipleRightBarButtonItemsListenerKey = &setMultipleRightBarButtonItemsListenerKey;
static const void *setBackBarButtonItemListenerBagKey = &setBackBarButtonItemListenerBagKey;
static const void *setBadgeListenerBagKey = &setBadgeListenerBagKey;
static const void *badgeKey = &badgeKey;
static const void *animationNameKey = &animationNameKey;
static const void *animationOffsetKey = &animationOffsetKey;

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
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setRightBarButtonItems:) newSelector:@selector(_ac91f40f_setRightBarButtonItems:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setRightBarButtonItems:animated:) newSelector:@selector(_ac91f40f_setRightBarButtonItems:animated:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UINavigationItem class] currentSelector:@selector(setBackBarButtonItem:) newSelector:@selector(_ac91f40f_setBackBarButtonItem:)];
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
            listener(title, false);
        }];
    }
}

- (void)setTitle:(NSString * _Nullable)title animated:(bool)animated {
    [self _ac91f40f_setTitle:title];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setTitle:title];
    } else {
        [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] enumerateItems:^(UINavigationItemSetTitleListener listener) {
            listener(title, animated);
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
    UIBarButtonItem *previousItem = self.leftBarButtonItem;
    
    [self _ac91f40f_setLeftBarButtonItem:leftBarButtonItem animated:animated];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setLeftBarButtonItem:leftBarButtonItem animated:animated];
    } else {
        [(NSBag *)[self associatedObjectForKey:setLeftBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
            listener(previousItem, leftBarButtonItem, animated);
        }];
    }
}

- (void)_ac91f40f_setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem {
    [self setRightBarButtonItem:rightBarButtonItem animated:false];
}

- (void)_ac91f40f_setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated
{
    UIBarButtonItem *previousItem = self.rightBarButtonItem;
    
    [self _ac91f40f_setRightBarButtonItem:rightBarButtonItem animated:animated];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setRightBarButtonItem:rightBarButtonItem animated:animated];
    } else {
        [(NSBag *)[self associatedObjectForKey:setRightBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
            listener(previousItem, rightBarButtonItem, animated);
        }];
    }
}

- (void)_ac91f40f_setRightBarButtonItems:(NSArray<UIBarButtonItem *> *)rightBarButtonItems {
    [self setRightBarButtonItems:rightBarButtonItems animated:false];
}

- (void)_ac91f40f_setRightBarButtonItems:(NSArray<UIBarButtonItem *> *)rightBarButtonItems animated:(BOOL)animated
{
    [self _ac91f40f_setRightBarButtonItems:rightBarButtonItems animated:animated];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setRightBarButtonItems:rightBarButtonItems animated:animated];
    } else {
        [(NSBag *)[self associatedObjectForKey:setMultipleRightBarButtonItemsListenerKey] enumerateItems:^(UINavigationItemSetMutipleBarButtonItemsListener listener) {
            listener(rightBarButtonItems, animated);
        }];
    }
}

- (void)_ac91f40f_setBackBarButtonItem:(UIBarButtonItem *)backBarButtonItem
{
    UIBarButtonItem *previousItem = self.backBarButtonItem;
    
    [self _ac91f40f_setBackBarButtonItem:backBarButtonItem];
    
    UINavigationItem *targetItem = [self associatedObjectForKey:targetItemKey];
    if (targetItem != nil) {
        [targetItem setBackBarButtonItem:backBarButtonItem];
    } else {
        [(NSBag *)[self associatedObjectForKey:setBackBarButtonItemListenerBagKey] enumerateItems:^(UINavigationItemSetBarButtonItemListener listener) {
            listener(previousItem, backBarButtonItem, false);
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

- (BOOL)hasTargetItem {
    return [self associatedObjectForKey:targetItemKey] != nil;
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

- (NSInteger)addSetMultipleRightBarButtonItemsListener:(UINavigationItemSetMutipleBarButtonItemsListener _Nonnull)listener {
    NSBag *bag = [self associatedObjectForKey:setMultipleRightBarButtonItemsListenerKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setMultipleRightBarButtonItemsListenerKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetMultipleRightBarButtonItemsListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setMultipleRightBarButtonItemsListenerKey] removeItem:key];
}

- (NSInteger)addSetBackBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener {
    NSBag *bag = [self associatedObjectForKey:setBackBarButtonItemListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setBackBarButtonItemListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetBackBarButtonItemListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setBackBarButtonItemListenerBagKey] removeItem:key];
}

- (NSInteger)addSetBadgeListener:(UITabBarItemSetBadgeListener)listener {
    NSBag *bag = [self associatedObjectForKey:setBadgeListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setBadgeListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetBadgeListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setBadgeListenerBagKey] removeItem:key];
}

- (void)setBadge:(NSString *)badge {
    [self setAssociatedObject:badge forKey:badgeKey];
    
    [(NSBag *)[self associatedObjectForKey:setBadgeListenerBagKey] enumerateItems:^(UITabBarItemSetBadgeListener listener) {
        listener(badge);
    }];
}

- (NSString *)badge {
    return [self associatedObjectForKey:badgeKey];
}

@end

@implementation UITabBarItem (Proxy)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UITabBarItem class] currentSelector:@selector(setBadgeValue:) newSelector:@selector(_ac91f40f_setBadgeValue:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UITabBarItem class] currentSelector:@selector(setTitle:) newSelector:@selector(_ac91f40f_setTitle:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UITabBarItem class] currentSelector:@selector(setImage:) newSelector:@selector(_ac91f40f_setImage:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UITabBarItem class] currentSelector:@selector(setSelectedImage:) newSelector:@selector(_ac91f40f_setSelectedImage:)];
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

- (void)_ac91f40f_setTitle:(NSString *)value {
    [self _ac91f40f_setTitle:value];
    
    [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] enumerateItems:^(UINavigationItemSetTitleListener listener) {
        listener(value, false);
    }];
}

- (void)_ac91f40f_setImage:(UIImage *)value {
    [self _ac91f40f_setImage:value];
    
    [(NSBag *)[self associatedObjectForKey:setImageListenerBagKey] enumerateItems:^(UINavigationItemSetImageListener listener) {
        listener(value);
    }];
}

- (void)_ac91f40f_setSelectedImage:(UIImage *)value {
    [self _ac91f40f_setSelectedImage:value];
    
    [(NSBag *)[self associatedObjectForKey:setSelectedImageListenerBagKey] enumerateItems:^(UINavigationItemSetImageListener listener) {
        listener(value);
    }];
}

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener)listener {
    NSBag *bag = [self associatedObjectForKey:setTitleListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setTitleListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetTitleListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setTitleListenerBagKey] removeItem:key];
}

- (NSInteger)addSetImageListener:(UINavigationItemSetImageListener)listener {
    NSBag *bag = [self associatedObjectForKey:setImageListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setImageListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetImageListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setImageListenerBagKey] removeItem:key];
}

- (NSInteger)addSetSelectedImageListener:(UINavigationItemSetImageListener)listener {
    NSBag *bag = [self associatedObjectForKey:setSelectedImageListenerBagKey];
    if (bag == nil)
    {
        bag = [[NSBag alloc] init];
        [self setAssociatedObject:bag forKey:setSelectedImageListenerBagKey];
    }
    return [bag addItem:[listener copy]];
}

- (void)removeSetSelectedImageListener:(NSInteger)key {
    [(NSBag *)[self associatedObjectForKey:setSelectedImageListenerBagKey] removeItem:key];
}

- (void)setAnimationName:(NSString *)animationName {
    [self setAssociatedObject:animationName forKey:animationNameKey];
}

- (NSString *)animationName {
    return [self associatedObjectForKey:animationNameKey];
}

- (void)setAnimationOffset:(CGPoint)animationOffset {
    [self setAssociatedObject:[NSValue valueWithCGPoint:animationOffset] forKey:animationOffsetKey];
}

- (CGPoint)animationOffset {
    return ((NSValue *)[self associatedObjectForKey:animationOffsetKey]).CGPointValue;
}

@end
