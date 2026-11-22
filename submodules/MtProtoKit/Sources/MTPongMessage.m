#import "MTPongMessage.h"

@implementation MTPongMessage

- (instancetype)initWithMessageId:(int64_t)messageId pingId:(int64_t)pingId
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _pingId = pingId;
    }
    return self;
}

@end
