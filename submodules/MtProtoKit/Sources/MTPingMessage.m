#import "MTPingMessage.h"

@implementation MTPingMessage

- (instancetype)initWithPingId:(int64_t)pingId
{
    self = [super init];
    if (self != nil)
    {
        _pingId = pingId;
    }
    return self;
}

@end
