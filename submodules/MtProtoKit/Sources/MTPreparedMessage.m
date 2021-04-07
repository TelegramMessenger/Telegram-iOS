#import <MtProtoKit/MTPreparedMessage.h>

#import <MtProtoKit/MTInternalId.h>

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
