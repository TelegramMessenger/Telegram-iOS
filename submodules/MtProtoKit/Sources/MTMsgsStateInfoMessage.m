#import "MTMsgsStateInfoMessage.h"

@implementation MTMsgsStateInfoMessage

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId info:(NSData *)info
{
    self = [super init];
    if (self != nil)
    {
        _requestMessageId = requestMessageId;
        _info = info;
    }
    return self;
}

@end
