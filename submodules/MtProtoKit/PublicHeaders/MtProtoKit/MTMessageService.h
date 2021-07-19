

#import <Foundation/Foundation.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

@class MTProto;
@class MTIncomingMessage;
@class MTMessageTransaction;
@class MTApiEnvironment;
@class MTSessionInfo;
@class MTTransportScheme;

@protocol MTMessageService <NSObject>

@optional

- (void)mtProtoWillAddService:(MTProto *)mtProto;
- (void)mtProtoDidAddService:(MTProto *)mtProto;
- (void)mtProtoDidRemoveService:(MTProto *)mtProto;
- (void)mtProtoPublicKeysUpdated:(MTProto *)mtProto datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys;
- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector sessionInfo:(MTSessionInfo *)sessionInfo scheme:(MTTransportScheme *)scheme;
- (void)mtProtoDidChangeSession:(MTProto *)mtProto;
- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds;
- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector;
- (void)mtProto:(MTProto *)mtProto receivedQuickAck:(int32_t)quickAckId;
- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds;
- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto;
- (void)mtProto:(MTProto *)mtProto messageDeliveryFailed:(int64_t)messageId;
- (void)mtProto:(MTProto *)mtProto messageDeliveryConfirmed:(NSArray *)messageIds;
- (void)mtProto:(MTProto *)mtProto messageResendRequestFailed:(int64_t)messageId;
- (void)mtProto:(MTProto *)mtProto protocolErrorReceived:(int32_t)errorCode;
- (bool)mtProto:(MTProto *)mtProto shouldRequestMessageWithId:(int64_t)responseMessageId inResponseToMessageId:(int64_t)messageId currentTransactionId:(id)currentTransactionId;
- (void)mtProto:(MTProto *)mtProto updateReceiveProgressForToken:(id)progressToken progress:(float)progress packetLength:(NSInteger)packetLength;

- (void)mtProtoNetworkAvailabilityChanged:(MTProto *)mtProto isNetworkAvailable:(bool)isNetworkAvailable;
- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto isConnected:(bool)isConnected;
- (void)mtProtoConnectionContextUpdateStateChanged:(MTProto *)mtProto isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)mtProtoServiceTasksStateChanged:(MTProto *)mtProto isPerformingServiceTasks:(bool)isPerformingServiceTasks;

- (void)mtProtoAuthTokenUpdated:(MTProto *)mtProto;
    
- (void)mtProtoApiEnvironmentUpdated:(MTProto *)mtProto apiEnvironment:(MTApiEnvironment *)apiEnvironment;

@end
