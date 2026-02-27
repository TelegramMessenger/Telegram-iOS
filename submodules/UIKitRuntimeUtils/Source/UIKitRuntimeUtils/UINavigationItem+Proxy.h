#import <UIKit/UIKit.h>

typedef void (^UINavigationItemSetTitleListener)(NSString * _Nullable, bool);
typedef void (^UINavigationItemSetTitleViewListener)(UIView * _Nullable);
typedef void (^UINavigationItemSetImageListener)(UIImage * _Nullable);
typedef void (^UINavigationItemSetBarButtonItemListener)(UIBarButtonItem * _Nullable, UIBarButtonItem * _Nullable, BOOL);
typedef void (^UINavigationItemSetMutipleBarButtonItemsListener)(NSArray<UIBarButtonItem *> * _Nullable, BOOL);
typedef void (^UITabBarItemSetBadgeListener)(NSString * _Nullable);

@interface UINavigationItem (Proxy)

- (void)setTargetItem:(UINavigationItem * _Nullable)targetItem;
- (BOOL)hasTargetItem;

- (void)setTitle:(NSString * _Nullable)title animated:(bool)animated;

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener _Nonnull)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetTitleViewListener:(UINavigationItemSetTitleViewListener _Nonnull)listener;
- (void)removeSetTitleViewListener:(NSInteger)key;
- (NSInteger)addSetLeftBarButtonItemListener:(UINavigationItemSetBarButtonItemListener _Nonnull)listener;
- (void)removeSetLeftBarButtonItemListener:(NSInteger)key;
- (NSInteger)addSetRightBarButtonItemListener:(UINavigationItemSetBarButtonItemListener _Nonnull)listener;
- (void)removeSetRightBarButtonItemListener:(NSInteger)key;
- (NSInteger)addSetMultipleRightBarButtonItemsListener:(UINavigationItemSetMutipleBarButtonItemsListener _Nonnull)listener;
- (void)removeSetMultipleRightBarButtonItemsListener:(NSInteger)key;
- (NSInteger)addSetBackBarButtonItemListener:(UINavigationItemSetBarButtonItemListener _Nonnull)listener;
- (void)removeSetBackBarButtonItemListener:(NSInteger)key;
- (NSInteger)addSetBadgeListener:(UITabBarItemSetBadgeListener _Nonnull)listener;
- (void)removeSetBadgeListener:(NSInteger)key;

@property (nonatomic, strong) NSString * _Nullable badge;

@end

NSInteger UITabBarItem_addSetBadgeListener(UITabBarItem * _Nonnull item, UITabBarItemSetBadgeListener  _Nonnull listener);

@interface UITabBarItem (Proxy)

- (void)removeSetBadgeListener:(NSInteger)key;

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener _Nonnull)listener;
- (void)removeSetTitleListener:(NSInteger)key;

- (NSInteger)addSetImageListener:(UINavigationItemSetImageListener _Nonnull)listener;
- (void)removeSetImageListener:(NSInteger)key;

- (NSInteger)addSetSelectedImageListener:(UINavigationItemSetImageListener _Nonnull)listener;
- (void)removeSetSelectedImageListener:(NSInteger)key;

@property (nonatomic, strong) NSString * _Nullable animationName;
@property (nonatomic, assign) CGPoint animationOffset;
@property (nonatomic, assign) bool ringSelection;

@end
