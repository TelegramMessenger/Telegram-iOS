#import "MTMsgsStateReqMessage.h"

@implementation MTMsgsStateReqMessage

- (instancetype)initWithMessageIds:(NSArray *)messageIds
{
    self = [super init];
    if (self != nil)
    {
        _messageIds = messageIds;
    }
    return self;
}

@end
