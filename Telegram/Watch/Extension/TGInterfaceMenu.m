#import "TGInterfaceMenu.h"

#import "TGInterfaceController.h"

#import <objc/runtime.h>

@interface TGInterfaceMenuItem ()

@property (nonatomic, readonly) NSString *uniqueIdentifier;
@property (nonatomic, copy) TGInterfaceMenuItemActionBlock actionBlock;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *imageName;
@property (nonatomic, assign) WKMenuItemIcon itemIcon;

@end

@implementation TGInterfaceMenuItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _uniqueIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock
{
    self = [self init];
    if (self != nil)
    {
        self.title = title;
        self.image = image;;
        self.actionBlock = actionBlock;
    }
    return self;
}

- (instancetype)initWithImageNamed:(NSString *)imageName title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock
{
    self = [self init];
    if (self != nil)
    {
        self.title = title;
        self.imageName = imageName;
        self.actionBlock = actionBlock;
    }
    return self;
}

- (instancetype)initWithItemIcon:(WKMenuItemIcon)itemIcon title:(NSString *)title actionBlock:(TGInterfaceMenuItemActionBlock)actionBlock
{
    self = [self init];
    if (self != nil)
    {
        self.title = title;
        self.itemIcon = itemIcon;
        self.actionBlock = actionBlock;
    }
    return self;
}

@end

#pragma mark - 

@interface TGInterfaceMenu ()

@property (nonatomic, readonly) NSString *uniqueIdentifier;
@property (nonatomic, weak) TGInterfaceController *interfaceController;
@property (nonatomic, strong) NSArray *items;

@end

@implementation TGInterfaceMenu

- (instancetype)initForInterfaceController:(TGInterfaceController *)interfaceController
{
    return [self initForInterfaceController:interfaceController items:nil];
}

- (instancetype)initForInterfaceController:(TGInterfaceController *)interfaceController items:(NSArray *)items
{
    NSParameterAssert(interfaceController);
    
    self = [super init];
    if (self != nil)
    {
        _uniqueIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
        
        self.interfaceController = interfaceController;
        self.items = items;
        
        for (TGInterfaceMenuItem *item in self.items)
        {
            if (![item isKindOfClass:[TGInterfaceMenuItem class]])
                continue;
            
            [self _appendItem:item];
        }
    }
    return self;
}

- (void)addItem:(TGInterfaceMenuItem *)item
{
    NSParameterAssert(item);
    
    [self _appendItem:item];
    
    if (self.items != nil)
        self.items = [self.items arrayByAddingObject:item];
    else
        self.items = @[ item ];
}

- (void)addItems:(NSArray *)items
{
    NSParameterAssert(items);
    
    NSMutableArray *addedItems = [NSMutableArray array];
    
    for (TGInterfaceMenuItem *item in items)
    {
        if (![item isKindOfClass:[TGInterfaceMenuItem class]])
            continue;
        
        [self _appendItem:item];
        [addedItems addObject:item];
    }
    
    if (self.items != nil)
        self.items = [self.items arrayByAddingObjectsFromArray:addedItems];
    else
        self.items = addedItems;
}

- (void)_appendItem:(TGInterfaceMenuItem *)item
{
    NSParameterAssert(item);
    
    SEL actionSelector = [self _actionSelectorForItem:item];
    
    if (self.interfaceController != nil && ![self.interfaceController respondsToSelector:actionSelector])
    {
        bool succeed = class_addMethod([self.interfaceController class], actionSelector, imp_implementationWithBlock(^(id receiver)
        {
            if (item.actionBlock != nil)
                item.actionBlock(receiver, item);
        }), [[NSString stringWithFormat: @"%s%s%s", @encode(id), @encode(id), @encode(SEL)] UTF8String]);

        if (succeed)
        {
            if (item.image != nil)
                [self.interfaceController addMenuItemWithImage:item.image title:item.title action:actionSelector];
            else if (item.imageName != nil)
                [self.interfaceController addMenuItemWithImageNamed:item.imageName title:item.title action:actionSelector];
            else
                [self.interfaceController addMenuItemWithItemIcon:item.itemIcon title:item.title action:actionSelector];
        }
    }
}

- (void)clearItems
{
    for (TGInterfaceMenuItem *item in self.items)
    {
        SEL actionSelector = [self _actionSelectorForItem:item];
        Method method = class_getInstanceMethod([self.interfaceController class], actionSelector);
        imp_removeBlock(method_getImplementation(method));
        method_setImplementation(method, NULL);
    }

    [self.interfaceController clearAllMenuItems];
    self.items = nil;
}

#pragma mark - 

NSString *const TGInterfaceMenuActionSelectorPrefix = @"tg_interfaceMenuAction_";

- (SEL)_actionSelectorForItem:(TGInterfaceMenuItem *)item
{
    return NSSelectorFromString([TGInterfaceMenuActionSelectorPrefix stringByAppendingFormat:@"%lx_%lx", (unsigned long)self.uniqueIdentifier.hash, (unsigned long)item.uniqueIdentifier.hash]);
}

@end
