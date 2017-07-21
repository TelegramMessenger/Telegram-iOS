#import "TGKeyCommandController.h"

#import "LegacyComponentsInternal.h"
#import "TGViewController.h"
#import "TGViewController+TGRecursiveEnumeration.h"

@interface TGKeyCommandController ()
{
    TGViewController *_rootController;
    NSMutableDictionary *_keyCommandToOwnerMap;
    NSMutableArray *_currentKeyCommands;
}
@end

@implementation TGKeyCommandController

- (instancetype)initWithRootController:(TGViewController *)rootController
{
    self = [super init];
    if (self != nil)
    {
        _rootController = rootController;
    }
    return self;
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
    NSMutableArray *concreteCommands = [[NSMutableArray alloc] init];
    NSMutableDictionary *commandOwners = [[NSMutableDictionary alloc] init];
    
    _currentKeyCommands = [[NSMutableArray alloc] init];
    
    NSArray *fixCommands = @
    [
     [[TGKeyCommand keyCommandWithTitle:nil input:nil modifierFlags:UIKeyModifierCommand] UIKeyCommand],
     [[TGKeyCommand keyCommandWithTitle:nil input:nil modifierFlags:UIKeyModifierAlternate] UIKeyCommand]
    ];

    [concreteCommands addObjectsFromArray:fixCommands];

    __block bool hasExclusiveResponder = false;
    [_rootController enumerateChildViewControllersRecursivelyWithBlock:^(UIViewController *viewController)
    {
        if (hasExclusiveResponder)
            return;
        
        if (![viewController conformsToProtocol:@protocol(TGKeyCommandResponder)])
            return;
        
        id <TGKeyCommandResponder> keyCommandResponder = (id<TGKeyCommandResponder>)viewController;
        if ([(id)keyCommandResponder respondsToSelector:@selector(isExclusive)] && [keyCommandResponder isExclusive])
        {
            hasExclusiveResponder = true;
            
            [_currentKeyCommands removeAllObjects];
            [commandOwners removeAllObjects];
            [concreteCommands removeAllObjects];
            [concreteCommands addObjectsFromArray:fixCommands];
        }
        
        NSArray *controllerCommands = [keyCommandResponder availableKeyCommands];
        if (controllerCommands.count == 0)
            return;
        
        for (TGKeyCommand *command in controllerCommands)
        {
            UIKeyCommand *concreteKeyCommand = [command UIKeyCommand];
            if (concreteKeyCommand != nil)
            {
                [_currentKeyCommands addObject:command];
                [concreteCommands addObject:concreteKeyCommand];
                commandOwners[command] = viewController;
            }
        }
    }];

    _keyCommandToOwnerMap = commandOwners;
    
    return concreteCommands;
}

- (void)processKeyCommand:(UIKeyCommand *)__unused keyCommand
{

}

- (void)performActionForKeyCommand:(TGKeyCommand *)keyCommand
{
    id<TGKeyCommandResponder> responder = _keyCommandToOwnerMap[keyCommand];
    if (responder == nil)
        return;
    
    [responder processKeyCommand:[keyCommand UIKeyCommand]];
}

- (bool)isKeyCommandOccupied:(TGKeyCommand *)keyCommand
{
    for (TGKeyCommand *command in _currentKeyCommands)
    {
        if ([command.input isEqualToString:keyCommand.input] && command.modifierFlags == keyCommand.modifierFlags)
            return true;
    }
    
    return false;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (![sender isKindOfClass:[UIKeyCommand class]])
        return [super canPerformAction:action withSender:sender];
    
    TGKeyCommand *keyCommand = [TGKeyCommand keyCommandWithUIKeyCommand:sender];
    if (_keyCommandToOwnerMap[keyCommand] != nil || [keyCommand.input isEqualToString:@""])
        return true;
    
    return false;
}

- (id)targetForAction:(SEL)__unused action withSender:(id)sender
{
    if (![sender isKindOfClass:[UIKeyCommand class]])
        return nil;
    
    TGKeyCommand *keyCommand = [TGKeyCommand keyCommandWithUIKeyCommand:sender];
    if ([keyCommand.input isEqualToString:@""])
        return self;
    
    return _keyCommandToOwnerMap[keyCommand];
}

- (BOOL)canBecomeFirstResponder
{
    return true;
}

+ (bool)keyCommandsSupported
{
    static dispatch_once_t onceToken;
    static bool keyCommandsSupported = false;
    dispatch_once(&onceToken, ^
    {
        keyCommandsSupported = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && iosMajorVersion() >= 8);
    });
    
    return keyCommandsSupported;
}

@end
