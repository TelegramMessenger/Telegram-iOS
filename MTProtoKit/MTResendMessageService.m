/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTResendMessageService.h>

#import <MTProtoKit/MTProto.h>
#import <MTProtoKit/MTContext.h>
#import <MTProtoKit/MTSerialization.h>
#import <MTProtoKit/MTMessageTransaction.h>
#import <MTProtoKit/MTOutgoingMessage.h>
#import <MTProtoKit/MTPreparedMessage.h>
#import <MTProtoKit/MTIncomingMessage.h>

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

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto
{
    if (_currentRequestMessageId == 0 || _currentRequestTransactionId == nil)
    {
        _currentRequestTransactionId = nil;
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:[mtProto.context.serialization resendMessagesRequest:@[@(_messageId)]]];
        outgoingMessage.requiresConfirmation = false;
        
        return [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
        {
            if ( messageInternalIdToTransactionId[outgoingMessage.internalId] != nil && messageInternalIdToPreparedMessage[outgoingMessage.internalId] != nil)
            {
                _currentRequestMessageId = ((MTPreparedMessage *)messageInternalIdToPreparedMessage[outgoingMessage.internalId]).messageId;
                _currentRequestTransactionId = messageInternalIdToTransactionId[outgoingMessage.internalId];
                
                MTLog(@"[MTResendMessageService#%p request %" PRId64 " for %" PRId64 "]", self, _currentRequestMessageId, _messageId);
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

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
{
    if (message.messageId == _messageId)
    {
        id<MTResendMessageServiceDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
            [delegate resendMessageServiceCompleted:self];
    }
    else if ([mtProto.context.serialization isMessageMsgsStateInfo:message.body forInfoRequestMessageId:_currentRequestMessageId])
    {
        id<MTResendMessageServiceDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(resendMessageServiceCompleted:)])
            [delegate resendMessageServiceCompleted:self];
    }
}

@end
