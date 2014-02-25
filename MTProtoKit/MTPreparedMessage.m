/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTPreparedMessage.h>

#import <MTProtoKit/MTInternalId.h>

MTInternalIdClass(MTPreparedMessage)

@implementation MTPreparedMessage

- (instancetype)initWithData:(NSData *)data messageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt requiresConfirmation:(bool)requiresConfirmation hasHighPriority:(bool)hasHighPriority
{
    return [self initWithData:data messageId:messageId seqNo:seqNo salt:salt requiresConfirmation:requiresConfirmation hasHighPriority:hasHighPriority inResponseToMessageId:0];
}

- (instancetype)initWithData:(NSData *)data messageId:(int64_t)messageId seqNo:(int32_t)seqNo salt:(int64_t)salt requiresConfirmation:(bool)requiresConfirmation hasHighPriority:(bool)hasHighPriority inResponseToMessageId:(int64_t)inResponseToMessageId
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTPreparedMessage) alloc] init];
        
        _data = data;
        _messageId = messageId;
        _seqNo = seqNo;
        _salt = salt;
        _requiresConfirmation = requiresConfirmation;
        _hasHighPriority = hasHighPriority;
        _inResponseToMessageId = inResponseToMessageId;
    }
    return self;
}

@end
