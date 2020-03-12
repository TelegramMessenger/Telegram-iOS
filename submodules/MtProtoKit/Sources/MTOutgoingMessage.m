#import <MtProtoKit/MTOutgoingMessage.h>

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

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata additionalDebugDescription:(NSString *)additionalDebugDescription shortMetadata:(id)shortMetadata
{
    return [self initWithData:data metadata:metadata additionalDebugDescription:additionalDebugDescription shortMetadata:shortMetadata messageId:0 messageSeqNo:0];
}

- (instancetype)initWithData:(NSData *)data metadata:(id)metadata additionalDebugDescription:(NSString *)additionalDebugDescription shortMetadata:(id)shortMetadata messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTOutgoingMessageInternalId alloc] init];
        _data = data;
        _metadata = metadata;
        _additionalDebugDescription = additionalDebugDescription;
        _shortMetadata = shortMetadata;
        _messageId = messageId;
        _messageSeqNo = messageSeqNo;
        _requiresConfirmation = true;
    }
    return self;
}

@end
