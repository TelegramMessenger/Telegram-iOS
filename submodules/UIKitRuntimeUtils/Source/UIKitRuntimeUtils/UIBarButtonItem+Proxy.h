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
/// iPhone Duo: the item stays in the navigation bar's row rather than moving into the side column. For an item that
/// takes turns with a text item in the same place (Done after Edit), so the toggle does not jump between row and column.
@property (nonatomic) bool staysInRow;

- (instancetype)initWithCustomDisplayNode:(ASDisplayNode *)customDisplayNode;
- (instancetype)initWithBackButtonAppearanceWithTitle:(NSString *)title target:(id)target action:(SEL)action;

- (void)performActionOnTarget;

- (NSInteger)addSetTitleListener:(UIBarButtonItemSetTitleListener)listener;
- (void)removeSetTitleListener:(NSInteger)key;
- (NSInteger)addSetEnabledListener:(UIBarButtonItemSetEnabledListener)listener;
- (void)removeSetEnabledListener:(NSInteger)key;

- (void)setCustomAction:(void (^)())customAction;

@end
