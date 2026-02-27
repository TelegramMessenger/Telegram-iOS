#import <WatchKit/WatchKit.h>

@class TGIndexPath;

@protocol TGInterfaceContext <NSObject>

@end

@interface TGInterfaceController : WKInterfaceController

@property (nonatomic, strong) NSString *title;
@property (nonatomic, readonly, getter=isVisible) bool visible;
@property (nonatomic, readonly, getter=isPresenting) bool presenting;

@property (nonatomic, weak, readonly) TGInterfaceController *presentingController;
@property (nonatomic, readonly) NSArray *presentedControllers;

- (void)configureWithContext:(id<TGInterfaceContext>)context;

- (void)pushControllerWithClass:(Class)controllerClass context:(id<TGInterfaceContext>)context;
- (void)presentControllerWithClass:(Class)controllerClass context:(id<TGInterfaceContext>)context;

- (void)performInterfaceUpdate:(void (^)(bool animated))update;

- (id<TGInterfaceContext>)contextForSegueWithIdentifer:(NSString *)segueIdentifier table:(WKInterfaceTable *)table indexPath:(TGIndexPath *)indexPath;

+ (NSString *)identifier;

@end
