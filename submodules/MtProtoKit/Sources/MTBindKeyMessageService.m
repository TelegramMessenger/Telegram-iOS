#import <MtProtoKit/MTBindKeyMessageService.h>

#import <MtProtoKit/MTTime.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTPreparedMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import <MtProtoKit/MTSessionInfo.h>
#import <MtProtoKit/MTRpcError.h>
#import <MtProtoKit/MTLogging.h>
#import "MTInternalMessageParser.h"
#import "MTRpcResultMessage.h"
#import "MTBuffer.h"

@interface MTBindKeyMessageService () {
    MTDatacenterAuthKey *_persistentKey;
    MTDatacenterAuthKey *_ephemeralKey;
    void (^_completion)(bool);
    
    int64_t _currentMessageId;
    id _currentTransactionId;
}

@end

@implementation MTBindKeyMessageService

- (instancetype)initWithPersistentKey:(MTDatacenterAuthKey *)persistentKey ephemeralKey:(MTDatacenterAuthKey *)ephemeralKey completion:(void (^)(bool))completion {
    self = [super init];
    if (self != nil) {
        _persistentKey = persistentKey;
        _ephemeralKey = ephemeralKey;
        _completion = [completion copy];
    }
    return self;
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [mtProto requestTransportTransaction];
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector sessionInfo:(MTSessionInfo *)sessionInfo scheme:(MTTransportScheme *)scheme
{
    if (_currentTransactionId != nil) {
        return nil;
    }
    
    int64_t bindingMessageId = [sessionInfo generateClientMessageId:NULL];
    int32_t bindingSeqNo = [sessionInfo takeSeqNo:true];
    
    int32_t expiresAt = (int32_t)([mtProto.context globalTime] + mtProto.context.tempKeyExpiration);
    
    int64_t randomId = 0;
    arc4random_buf(&randomId, 8);
    
    int64_t nonce = 0;
    arc4random_buf(&nonce, 8);
    
    MTBuffer *decryptedMessage = [[MTBuffer alloc] init];
    //bind_auth_key_inner#75a3f765 nonce:long temp_auth_key_id:long perm_auth_key_id:long temp_session_id:long expires_at:int = BindAuthKeyInner;
    [decryptedMessage appendInt32:(int32_t)0x75a3f765];
    [decryptedMessage appendInt64:nonce];
    [decryptedMessage appendInt64:_ephemeralKey.authKeyId];
    [decryptedMessage appendInt64:_persistentKey.authKeyId];
    [decryptedMessage appendInt64:sessionInfo.sessionId];
    [decryptedMessage appendInt32:expiresAt];
    
    NSData *encryptedMessage = [MTProto _manuallyEncryptedMessage:[decryptedMessage data] messageId:bindingMessageId authKey:_persistentKey];
    
    MTBuffer *bindRequestData = [[MTBuffer alloc] init];
    
    //auth.bindTempAuthKey#cdd42a05 perm_auth_key_id:long nonce:long expires_at:int encrypted_message:bytes = Bool;
    
    [bindRequestData appendInt32:(int32_t)0xcdd42a05];
    [bindRequestData appendInt64:_persistentKey.authKeyId];
    [bindRequestData appendInt64:nonce];
    [bindRequestData appendInt32:expiresAt];
    [bindRequestData appendTLBytes:encryptedMessage];
    
    MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:bindRequestData.data metadata:[NSString stringWithFormat:@"auth.bindTempAuthKey"] additionalDebugDescription:nil shortMetadata:@"auth.bindTempAuthKey" messageId:bindingMessageId messageSeqNo:bindingSeqNo];
    
    return [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId) {
        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[outgoingMessage.internalId];
        if (preparedMessage != nil && messageInternalIdToTransactionId[outgoingMessage.internalId] != nil) {
            _currentMessageId = preparedMessage.messageId;
            _currentTransactionId = messageInternalIdToTransactionId[outgoingMessage.internalId];
        }
    }];
    
    return nil;
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId {
    if (messageId == _currentMessageId) {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds {
    if (_currentTransactionId != nil && [transactionIds containsObject:_currentTransactionId]) {
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto {
    if (_currentTransactionId != nil) {
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoDidChangeSession:(MTProto *)mtProto {
    _currentMessageId = 0;
    _currentTransactionId = nil;
    
    [mtProto requestTransportTransaction];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId messageIdsInFirstValidContainer:(NSArray *)messageIdsInFirstValidContainer {
    if (_currentMessageId != 0 && _currentMessageId < firstValidMessageId && ![messageIdsInFirstValidContainer containsObject:@(_currentMessageId)]) {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector {
    if ([message.body isKindOfClass:[MTRpcResultMessage class]]) {
        MTRpcResultMessage *rpcResultMessage = message.body;
        if (rpcResultMessage.requestMessageId == _currentMessageId) {
            bool success = false;
            if (rpcResultMessage.data.length >= 4) {
                uint32_t signature = 0;
                [rpcResultMessage.data getBytes:&signature range:NSMakeRange(0, 4)];

                id parsedMessage = [MTInternalMessageParser parseMessage:rpcResultMessage.data];
                if ([parsedMessage isKindOfClass:[MTRpcError class]]) {
                    if (MTLogEnabled()) {
                        MTRpcError *rpcError = (MTRpcError *)parsedMessage;
                        MTLog(@"[MTRequestMessageService#%p response for %" PRId64 " is error: %d: %@]", self, _currentMessageId, (int)rpcError.errorCode, rpcError.errorDescription);
                    }
                }
                
                //boolTrue#997275b5 = Bool;
                if (signature == 0x997275b5U) {
                    success = true;
                }
            }
            _completion(success);
        }
    }
}

@end
