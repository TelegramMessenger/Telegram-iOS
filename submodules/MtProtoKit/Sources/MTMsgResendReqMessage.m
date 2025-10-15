#import "MTMsgResendReqMessage.h"

@implementation MTMsgResendReqMessage

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
