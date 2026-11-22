#import "MTBindingTempAuthKeyContext.h"

@implementation MTBindingTempAuthKeyContext

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _messageSeqNo = messageSeqNo;
        _transactionId = transactionId;
    }
    return self;
}

@end
