#import <UIKit/UIKit.h>

typedef void (^UINavigationItemSetTitleListener)(NSString *);
typedef void (^UINavigationItemSetTitleViewListener)(UIView *);
typedef void (^UINavigationItemSetBarButtonItemListener)(UIBarButtonItem *, BOOL);
typedef void (^UITabBarItemSetBadgeListener)(NSString *);

@interface UINavigationItem (Proxy)

- (void)setTargetItem:(UINavigationItem *)targetItem;

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetTitleViewListener:(UINavigationItemSetTitleViewListener)listener;
- (void)removeSetTitleViewListener:(NSInteger)key;
- (NSInteger)addSetLeftBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener;
- (void)removeSetLeftBarButtonItemListener:(NSInteger)key;
- (NSInteger)addSetRightBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener;
- (void)removeSetRightBarButtonItemListener:(NSInteger)key;

@end

NSInteger UITabBarItem_addSetBadgeListener(UITabBarItem *item, UITabBarItemSetBadgeListener listener);

@interface UITabBarItem (Proxy)

- (void)removeSetBadgeListener:(NSInteger)key;

@end
