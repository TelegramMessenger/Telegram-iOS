#import "MTDropRpcResultMessage.h"

@implementation MTDropRpcResultMessage

@end

@implementation MTDropRpcResultUnknownMessage

@end

@implementation MTDropRpcResultDroppedRunningMessage

@end

@implementation MTDropRpcResultDroppedMessage

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo size:(int32_t)size
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _seqNo = seqNo;
        _size = size;
    }
    return self;
}

@end
