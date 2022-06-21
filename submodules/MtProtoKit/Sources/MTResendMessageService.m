#import <MtProtoKit/MTResendMessageService.h>

#import <Foundation/Foundation.h>
#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTPreparedMessage.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import "MTBuffer.h"
#import "MTMsgsStateInfoMessage.h"

@interface MTResendMessageService ()
{
    int64_t _currentRequestMessageId;
    id _currentRequestTransactionId;
}

@end

@implementation MTResendMessageService

- (instancetype)initWithMessageId:(int64_t)messageId
{
#ifdef DEBUG
    NSAssert(messageId != 0, @"messageId should not be 0");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
    }
    return self;
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [mtProto requestTransportTransaction];
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector sessionInfo:(MTSessionInfo *)sessionInfo scheme:(MTTransportScheme *)scheme
{
    if (_currentRequestMessageId == 0 || _currentRequestTransactionId == nil)
    {
        _currentRequestTransactionId = nil;
        
        MTBuffer *resendRequestBuffer = [[MTBuffer alloc] init];
        [resendRequestBuffer appendInt32:(int32_t)0x7d861a08];
        [resendRequestBuffer appendInt32:481674261];
        [resendRequestBuffer appendInt32:1];
        [resendRequestBuffer appendInt64:_messageId];
        
        NSData *resentMessagesRequestData = resendRequestBuffer.data;
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:resentMessagesRequestData metadata:@"resendMessages" additionalDebugDescription:nil shortMetadata:@"resendMessages"];
        outgoingMessage.requiresConfirmation = false;
        
        return [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
        {
            if ( messageInternalIdToTransactionId[outgoingMessage.internalId] != nil && messageInternalIdToPreparedMessage[outgoingMessage.internalId] != nil)
            {
                _currentRequestMessageId = ((MTPreparedMessage *)messageInternalIdToPreparedMessage[outgoingMessage.internalId]).messageId;
                _currentRequestTransactionId = messageInternalIdToTransactionId[outgoingMessage.internalId];
                
                if (MTLogEnabled()) {
                    MTLog(@"[MTResendMessageService#%p request %" PRId64 " for %" PRId64 "]", self, _currentRequestMessageId, _messageId);
                }
            }
        }];
    }
    
    return nil;
}

- (void)mtProto:(MTProto *)mtProto messageDeliveryFailed:(int64_t)messageId
{
    if (messageId == _currentRequestMessageId)
    {
        _currentRequestMessageId = 0;
        _currentRequestTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoDidChangeSession:(MTProto *)__unused mtProto
{
    id<MTResendMessageServiceDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
        [delegate resendMessageServiceCompleted:self];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)__unused mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    if (_currentRequestMessageId != 0 && _currentRequestMessageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(_currentRequestMessageId)])
    {
        id<MTResendMessageServiceDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
            [delegate resendMessageServiceCompleted:self];
    }
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    if (_currentRequestTransactionId != nil && [transactionIds containsObject:_currentRequestTransactionId])
    {
        _currentRequestTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    if (_currentRequestTransactionId != nil)
    {
        _currentRequestTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    if (message.messageId == _messageId)
    {
        id<MTResendMessageServiceDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
            [delegate resendMessageServiceCompleted:self];
    }
    else if ([message.body isKindOfClass:[MTMsgsStateInfoMessage class]] && ((MTMsgsStateInfoMessage *)message.body).requestMessageId == _currentRequestMessageId)
    {
        [mtProto _messageResendRequestFailed:_messageId];
        
        id<MTResendMessageServiceDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
            [delegate resendMessageServiceCompleted:self];
    }
}

@end
