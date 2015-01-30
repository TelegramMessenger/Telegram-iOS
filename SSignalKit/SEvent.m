#import "SEvent.h"

@implementation SEvent

- (instancetype)initWithNext:(id)next
{
    self = [super init];
    if (self != nil)
    {
        _type = SEventTypeNext;
        _data = next;
    }
    return self;
}

- (instancetype)initWithError:(id)error
{
    self = [super init];
    if (self != nil)
    {
        _type = SEventTypeError;
        _data = error;
    }
    return self;
}

- (instancetype)initWithCompleted
{
    self = [super init];
    if (self != nil)
    {
        _type = SEventTypeCompleted;
    }
    return self;
}

@end
