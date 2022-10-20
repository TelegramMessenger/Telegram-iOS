#import <WatchKit/WatchKit.h>

@class TGInterfaceMenuItem;
@class TGInterfaceController;

typedef void (^TGInterfaceMenuItemActionBlock)(TGInterfaceController *controller, TGInterfaceMenuItem *sender);

@interface TGInterfaceMenuItem : NSObject

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock;
- (instancetype)initWithImageNamed:(NSString *)imageName title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock;
- (instancetype)initWithItemIcon:(WKMenuItemIcon)itemIcon title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock;

@end

@interface TGInterfaceMenu : NSObject

- (instancetype)initForInterfaceController:(TGInterfaceController *)interfaceController;
- (instancetype)initForInterfaceController:(TGInterfaceController *)interfaceController items:(NSArray *)items;

- (void)addItem:(TGInterfaceMenuItem *)item;
- (void)addItems:(NSArray *)items;
- (void)clearItems;

@end
