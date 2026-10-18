#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

typedef void (^UIBarButtonItemSetTitleListener)(NSString *);
typedef void (^UIBarButtonItemSetEnabledListener)(BOOL);

@interface UIBarButtonItem (Proxy)

@property (nonatomic, strong, readonly) ASDisplayNode *customDisplayNode;
@property (nonatomic, readonly) bool backButtonAppearance;
/// The glass navigation bar gives this item a pill of its own, as it does a text item; by default an image item shares
/// one with the image items beside it (UIKit's `sharesBackground = false`, which exists only from iOS 26).
@property (nonatomic) bool requiresOwnSection;

- (instancetype)initWithCustomDisplayNode:(ASDisplayNode *)customDisplayNode;
- (instancetype)initWithBackButtonAppearanceWithTitle:(NSString *)title target:(id)target action:(SEL)action;

- (void)performActionOnTarget;

- (NSInteger)addSetTitleListener:(UIBarButtonItemSetTitleListener)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetEnabledListener:(UIBarButtonItemSetEnabledListener)listener;
- (void)removeSetEnabledListener:(NSInteger)key;

- (void)setCustomAction:(void (^)())customAction;

@end
