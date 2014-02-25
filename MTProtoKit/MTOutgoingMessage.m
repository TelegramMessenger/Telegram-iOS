/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTOutgoingMessage.h>

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
        static NSUInteger nextValue = 1;
        _value = nextValue++;
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

- (instancetype)initWithBody:(id)body
{
    return [self initWithBody:body messageId:0 messageSeqNo:0];
}

- (instancetype)initWithBody:(id)body messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTOutgoingMessageInternalId alloc] init];
        _body = body;
        _messageId = messageId;
        _messageSeqNo = messageSeqNo;
        _requiresConfirmation = true;
    }
    return self;
}

@end
