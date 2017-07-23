#import "SGraphListNode.h"

@implementation SGraphListNode

@synthesize items = _items;

- (id)initWithItems:(NSArray *)items
{
    self = [super init];
    if (self != nil)
    {
        _items = items;
    }
    return self;
}

@end
