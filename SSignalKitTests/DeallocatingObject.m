#import "DeallocatingObject.h"

@interface DeallocatingObject ()
{
    bool *_deallocated;
}

@end

@implementation DeallocatingObject

- (instancetype)initWithDeallocated:(bool *)deallocated
{
    self = [super init];
    if (self != nil)
    {
        _deallocated = deallocated;
    }
    return self;
}

- (void)dealloc
{
    *_deallocated = true;
}

@end
