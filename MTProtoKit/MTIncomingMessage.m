/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTIncomingMessage.h"

@implementation MTIncomingMessage

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt timestamp:(NSTimeInterval)timestamp size:(NSInteger)size body:(id)body
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _seqNo = seqNo;
        _salt = salt;
        _timestamp = timestamp;
        _size = size;
        _body = body;
    }
    return self;
}

@end
