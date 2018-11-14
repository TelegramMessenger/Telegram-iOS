#import "TGInterfaceController.h"
#import "WKInterfaceTable+TGDataDrivenTable.h"

@interface TGInterfaceControllerContext : NSObject

@property (nonatomic, weak) TGInterfaceController *presentingController;
@property (nonatomic, strong) id context;

@end

@implementation TGInterfaceControllerContext

+ (TGInterfaceControllerContext *)contextWithPresentingController:(TGInterfaceController *)presentingController
                                                          context:(id<TGInterfaceContext>)context
{
    NSParameterAssert(presentingController);
    
    TGInterfaceControllerContext *controllerContext = [[TGInterfaceControllerContext alloc] init];
    controllerContext.presentingController = presentingController;
    controllerContext.context = context;
    return controllerContext;
}

@end


@interface TGInterfaceController ()
{
    NSString *_title;
    void (^_pendingInterfaceUpdate)(bool animated);
}
@end

@implementation TGInterfaceController

@dynamic title;

- (void)configureWithContext:(id<TGInterfaceContext>)context
{
    
}

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];
    
    _visible = true;
    
    id<TGInterfaceContext> unwrappedContext = nil;
    if ([context isKindOfClass:[TGInterfaceControllerContext class]])
    {
        TGInterfaceControllerContext *controllerContext = (TGInterfaceControllerContext *)context;
        _presentingController = controllerContext.presentingController;
        unwrappedContext = controllerContext.context;
    }
    
    [self configureWithContext:unwrappedContext];
}

- (void)pushControllerWithClass:(Class)controllerClass context:(id<TGInterfaceContext>)context
{
    NSParameterAssert([controllerClass isSubclassOfClass:[TGInterfaceController class]]);
    
    TGInterfaceControllerContext *controllerContext = [TGInterfaceControllerContext contextWithPresentingController:self context:context];
    
    [self pushControllerWithName:[controllerClass identifier] context:controllerContext];
}

- (void)presentControllerWithClass:(Class)controllerClass context:(id<TGInterfaceContext>)context
{
    NSParameterAssert([controllerClass isSubclassOfClass:[TGInterfaceController class]]);
    
    TGInterfaceControllerContext *controllerContext = [TGInterfaceControllerContext contextWithPresentingController:self context:context];
    
    [self presentControllerWithName:[controllerClass identifier] context:controllerContext];
}

- (void)willActivate
{
    [super willActivate];
    
    _visible = true;
        
    if (_pendingInterfaceUpdate != nil)
    {
        _pendingInterfaceUpdate(false);
        _pendingInterfaceUpdate = nil;
    }
}

- (void)didDeactivate
{
    [super didDeactivate];
    
    _visible = false;
}

- (bool)isPresenting
{
    return !_visible;
}

- (void)_willPresentController
{
    _visible = false;
}

- (void)presentControllerWithName:(NSString *)name context:(id)context
{
    [self _willPresentController];
    
    [super presentControllerWithName:name context:context];
}

- (void)presentControllerWithNames:(NSArray *)names contexts:(NSArray *)contexts
{
    [self _willPresentController];
    
    [super presentControllerWithNames:names contexts:contexts];
}

- (void)presentTextInputControllerWithSuggestions:(NSArray *)suggestions allowedInputMode:(WKTextInputMode)inputMode completion:(void (^)(NSArray *))completion
{
    [self _willPresentController];
    
    [super presentTextInputControllerWithSuggestions:suggestions allowedInputMode:inputMode completion:completion];
}

- (void)performInterfaceUpdate:(void (^)(bool))updates
{
    if (updates == nil)
        return;
    
    if (self.isVisible)
        updates(true);
    else
        _pendingInterfaceUpdate = [updates copy];
}

- (TGInterfaceControllerContext *)contextForSegueWithIdentifier:(NSString *)segueIdentifier inTable:(WKInterfaceTable *)table rowIndex:(NSInteger)rowIndex
{
    TGIndexPath *indexPath = [table indexPathForRowIndex:rowIndex];
    return [TGInterfaceControllerContext contextWithPresentingController:self context:[self contextForSegueWithIdentifer:segueIdentifier table:table indexPath:indexPath]];
}
            
- (id<TGInterfaceContext>)contextForSegueWithIdentifer:(NSString *)segueIdentifier table:(WKInterfaceTable *)table indexPath:(TGIndexPath *)indexPath
{
    return nil;
}

#pragma mark - Properties

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    if ([title isEqualToString:_title])
        return;
    
    _title = title;
    
    [super setTitle:title];
}

#pragma mark -

+ (NSString *)identifier
{
    NSAssert(true, @"Do not use TGInterfaceController directly");
    return nil;
}

@end
