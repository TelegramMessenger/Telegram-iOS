#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef void (^UIBarButtonItemSetTitleListener)(NSString *);
typedef void (^UIBarButtonItemSetEnabledListener)(BOOL);

@interface UIBarButtonItem (Proxy)

@property (nonatomic, strong, readonly) ASDisplayNode *customDisplayNode;

- (instancetype)initWithCustomDisplayNode:(ASDisplayNode *)customDisplayNode;

- (void)performActionOnTarget;

- (NSInteger)addSetTitleListener:(UIBarButtonItemSetTitleListener)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetEnabledListener:(UIBarButtonItemSetEnabledListener)listener;
- (void)removeSetEnabledListener:(NSInteger)key;

@end
