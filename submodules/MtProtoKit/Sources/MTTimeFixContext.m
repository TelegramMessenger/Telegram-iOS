#import <MtProtoKit/MTTimeFixContext.h>

@implementation MTTimeFixContext

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId timeFixAbsoluteStartTime:(CFAbsoluteTime)timeFixAbsoluteStartTime
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _messageSeqNo = messageSeqNo;
        _transactionId = transactionId;
        _timeFixAbsoluteStartTime = timeFixAbsoluteStartTime;
    }
    return self;
}

@end
