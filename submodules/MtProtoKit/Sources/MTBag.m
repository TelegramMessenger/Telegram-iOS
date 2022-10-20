#import <MtProtoKit/MTBag.h>

@interface MTBag ()
{
    NSInteger _nextKey;
    NSMutableArray *_items;
    NSMutableArray *_itemKeys;
}

@end

@implementation MTBag

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _items = [[NSMutableArray alloc] init];
        _itemKeys = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSInteger)addItem:(id)item
{
    if (item == nil)
        return -1;
    
    NSInteger key = _nextKey;
    [_items addObject:item];
    [_itemKeys addObject:@(key)];
    _nextKey++;
    
    return key;
}

- (void)enumerateItems:(void (^)(id))block
{
    if (block)
    {
        for (id item in _items)
        {
            block(item);
        }
    }
}

- (void)removeItem:(NSInteger)key
{
    NSUInteger index = 0;
    for (NSNumber *itemKey in _itemKeys)
    {
        if ([itemKey integerValue] == key)
        {
            [_items removeObjectAtIndex:index];
            [_itemKeys removeObjectAtIndex:index];
            break;
        }
        index++;
    }
}

- (bool)isEmpty
{
    return _items.count == 0;
}

- (NSArray *)copyItems
{
    return [[NSArray alloc] initWithArray:_items];
}

@end
