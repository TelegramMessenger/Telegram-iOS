/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

@class MTProto;
@class MTIncomingMessage;
@class MTMessageTransaction;

@protocol MTMessageService <NSObject>

@optional

- (void)mtProtoWillAddService:(MTProto *)mtProto;
- (void)mtProtoDidAddService:(MTProto *)mtProto;
- (void)mtProtoDidRemoveService:(MTProto *)mtProto;
- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto;
- (void)mtProtoDidChangeSession:(MTProto *)mtProto;
- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds;
- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message;
- (void)mtProto:(MTProto *)mtProto receivedQuickAck:(int32_t)quickAckId;
- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds;
- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto;
- (void)mtProto:(MTProto *)mtProto messageDeliveryFailed:(int64_t)messageId;
- (void)mtProto:(MTProto *)mtProto messageDeliveryConfirmed:(NSArray *)messageIds;
- (void)mtProto:(MTProto *)mtProto protocolErrorReceived:(int32_t)errorCode;
- (bool)mtProto:(MTProto *)mtProto shouldRequestMessageInResponseToMessageId:(int64_t)messageId currentTransactionId:(id)currentTransactionId;
- (void)mtProto:(MTProto *)mtProto updateReceiveProgressForToken:(id)progressToken progress:(float)progress packetLength:(NSInteger)packetLength;

- (void)mtProtoNetworkAvailabilityChanged:(MTProto *)mtProto isNetworkAvailable:(bool)isNetworkAvailable;
- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto isConnected:(bool)isConnected;
- (void)mtProtoConnectionContextUpdateStateChanged:(MTProto *)mtProto isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)mtProtoServiceTasksStateChanged:(MTProto *)mtProto isPerformingServiceTasks:(bool)isPerformingServiceTasks;

- (int32_t)possibleSignatureForResult:(int64_t)messageId found:(bool *)found;

@end
