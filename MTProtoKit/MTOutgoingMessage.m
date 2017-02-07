/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTOutgoingMessage.h"

#import <libkern/OSAtomic.h>

@interface MTOutgoingMessageInternalId : NSObject <NSCopying>
{
    NSUInteger _value;
}

@end

@implementation MTOutgoingMessageInternalId

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        static int32_t nextValue = 1;
        _value = OSAtomicIncrement32(&nextValue);
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[MTOutgoingMessageInternalId class]] && ((MTOutgoingMessageInternalId *)object)->_value == _value;
}

- (NSUInteger)hash
{
    return _value;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    MTOutgoingMessageInternalId *another = [[MTOutgoingMessageInternalId alloc] init];
    if (another != nil)
        another->_value = _value;
    return another;
}

@end

@implementation MTOutgoingMessage

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata
{
    return [self initWithData:data metadata:metadata messageId:0 messageSeqNo:0];
}

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTOutgoingMessageInternalId alloc] init];
        _data = data;
        _metadata = metadata;
        _messageId = messageId;
        _messageSeqNo = messageSeqNo;
        _requiresConfirmation = true;
    }
    return self;
}

@end
