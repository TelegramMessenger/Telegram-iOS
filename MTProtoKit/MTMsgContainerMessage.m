#import "MTMsgContainerMessage.h"

@implementation MTMsgContainerMessage

- (instancetype)initWithMessages:(NSArray *)messages
{
    self = [super init];
    if (self != nil)
    {
        _messages = messages;
    }
    return self;
}

@end
