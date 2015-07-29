#import "NavigationBarProxy.h"

@interface NavigationBarProxy ()
{
    NSArray *_items;
}

@end

@implementation NavigationBarProxy

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
    }
    return self;
}

- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated
{
    [self setItems:[[self items] arrayByAddingObject:item] animated:animated];
}

- (UINavigationItem *)popNavigationItemAnimated:(BOOL)animated
{
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:[self items]];
    UINavigationItem *lastItem = [items lastObject];
    [items removeLastObject];
    [self setItems:items animated:animated];
    return lastItem;
}

- (UINavigationItem *)topItem
{
    return [[self items] lastObject];
}

- (UINavigationItem *)backItem
{
    NSLog(@"backItem");
    return nil;
}

- (NSArray *)items
{
    if (_items == nil)
        return @[];
    return _items;
}

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:false];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    NSArray *previousItems = _items;
    _items = items;
    
    if (_setItemsProxy)
        _setItemsProxy(previousItems, items, animated);
}

@end
