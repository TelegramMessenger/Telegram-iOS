#import "MTMessage.h"

@implementation MTMessage

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo data:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _seqNo = seqNo;
        _data = data;
    }
    return self;
}

@end
