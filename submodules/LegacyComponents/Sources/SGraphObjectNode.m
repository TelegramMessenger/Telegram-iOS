#import "SGraphObjectNode.h"

@implementation SGraphObjectNode

@synthesize object = _object;

- (id)initWithObject:(id)object
{
    self = [super init];
    if (self != nil)
    {
        _object = object;
    }
    return self;
}

@end
