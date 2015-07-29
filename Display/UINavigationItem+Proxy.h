#import <UIKit/UIKit.h>

typedef void (^UINavigationItemSetTitleListener)(NSString *);
typedef void (^UINavigationItemSetBarButtonItemListener)(UIBarButtonItem *, BOOL);

@interface UINavigationItem (Proxy)

- (NSInteger)addSetTitleListener:(UINavigationItemSetTitleListener)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetLeftBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener;
- (void)removeSetLeftBarButtonItemListener:(NSInteger)key;
- (NSInteger)addSetRightBarButtonItemListener:(UINavigationItemSetBarButtonItemListener)listener;
- (void)removeSetRightBarButtonItemListener:(NSInteger)key;

@end
