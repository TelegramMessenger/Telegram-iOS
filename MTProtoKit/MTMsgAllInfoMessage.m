#import "MTMsgAllInfoMessage.h"

@implementation MTMsgAllInfoMessage

- (instancetype)initWithMessageIds:(NSArray *)messageIds info:(NSData *)info
{
    self = [super init];
    if (self != nil)
    {
        _messageIds = messageIds;
        _info = info;
    }
    return self;
}

@end
