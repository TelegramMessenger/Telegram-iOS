/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTimeFixContext.h>

@implementation MTTimeFixContext

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId timeFixAbsoluteStartTime:(MTAbsoluteTime)timeFixAbsoluteStartTime
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
