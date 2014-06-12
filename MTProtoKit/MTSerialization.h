/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@protocol MTSerialization <NSObject>

- (NSData *)serializeMessage:(id)message;
- (id)parseMessage:(NSInputStream *)is responseParsingBlock:(int32_t (^)(int64_t, bool *))responseParsingBlock;
- (NSString *)messageDescription:(id)messageBody messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo;

- (id)reqPq:(NSData *)nonce;
- (id)reqDhParams:(NSData *)nonce serverNonce:(NSData *)serverNonce p:(NSData *)p q:(NSData *)q publicKeyFingerprint:(int64_t)publicKeyFingerprint encryptedData:(NSData *)encryptedData;
- (id)setDhParams:(NSData *)nonce serverNonce:(NSData *)serverNonce encryptedData:(NSData *)encryptedData;

- (id)pqInnerData:(NSData *)nonce serverNonce:(NSData *)serverNonce pq:(NSData *)pq p:(NSData *)p q:(NSData *)q newNonce:(NSData *)newNonce;
- (id)clientDhInnerData:(NSData *)nonce serverNonce:(NSData *)serverNonce g_b:(NSData *)g_b retryId:(int32_t)retryId;

- (bool)isMessageResPq:(id)message;
- (NSData *)resPqNonce:(id)message;
- (NSData *)resPqServerNonce:(id)message;
- (NSData *)resPqPq:(id)message;
- (NSArray *)resPqServerPublicKeyFingerprints:(id)message;

- (bool)isMessageServerDhParams:(id)message;
- (NSData *)serverDhParamsNonce:(id)message;
- (NSData *)serverDhParamsServerNonce:(id)message;
- (bool)isMessageServerDhParamsOk:(id)message;
- (NSData *)serverDhParamsOkEncryptedAnswer:(id)message;

- (bool)isMessageServerDhInnerData:(id)message;
- (NSData *)serverDhInnerDataNonce:(id)message;
- (NSData *)serverDhInnerDataServerNonce:(id)message;
- (int32_t)serverDhInnerDataG:(id)message;
- (NSData *)serverDhInnerDataDhPrime:(id)message;
- (NSData *)serverDhInnerDataGA:(id)message;

- (bool)isMessageSetClientDhParamsAnswer:(id)message;
- (bool)isMessageSetClientDhParamsAnswerOk:(id)message;
- (bool)isMessageSetClientDhParamsAnswerRetry:(id)message;
- (bool)isMessageSetClientDhParamsAnswerFail:(id)message;
- (NSData *)setClientDhParamsNonce:(id)message;
- (NSData *)setClientDhParamsServerNonce:(id)message;
- (NSData *)setClientDhParamsNewNonceHash1:(id)message;
- (NSData *)setClientDhParamsNewNonceHash2:(id)message;
- (NSData *)setClientDhParamsNewNonceHash3:(id)message;

- (id)exportAuthorization:(int32_t)datacenterId;
- (NSData *)exportedAuthorizationBytes:(id)message;
- (int32_t)exportedAuthorizationId:(id)message;

- (id)importAuthorization:(int32_t)authId bytes:(NSData *)bytes;

- (id)getConfig;
- (NSArray *)datacenterAddressListFromConfig:(id)config datacenterId:(NSInteger)datacenterId;

- (id)getFutureSalts:(int32_t)count;
- (bool)isMessageFutureSalts:(id)message;
- (int64_t)futureSaltsRequestMessageId:(id)message;
- (NSArray *)saltInfoListFromMessage:(id)message;

- (id)resendMessagesRequest:(NSArray *)messageIds;

- (id)connectionWithApiId:(int32_t)apiId deviceModel:(NSString *)deviceModel systemVersion:(NSString *)systemVersion appVersion:(NSString *)appVersion langCode:(NSString *)langCode query:(id)query;
- (id)invokeAfterMessageId:(int64_t)messageId query:(id)query;

- (bool)isMessageContainer:(id)message;
- (NSArray *)containerMessages:(id)message;
- (bool)isMessageProtoMessage:(id)message;
- (id)protoMessageBody:(id)message messageId:(int64_t *)messageId seqNo:(int32_t *)seqNo length:(int32_t *)length;
- (bool)isMessageProtoCopyMessage:(id)message;
- (id)protoCopyMessageBody:(id)message messageId:(int64_t *)messageId seqNo:(int32_t *)seqNo length:(int32_t *)length;

- (bool)isMessageRpcWithLayer:(id)message;
- (id)wrapInLayer:(id)message;
- (id)dropAnswerToMessageId:(int64_t)messageId;
- (bool)isRpcDroppedAnswer:(id)message;
- (int64_t)rpcDropedAnswerDropMessageId:(id)message;
- (bool)isMessageRpcResult:(id)message;
- (id)rpcResultBody:(id)message requestMessageId:(int64_t *)requestMessageId;
- (id)rpcResult:(id)resultBody requestBody:(id)requestBody isError:(bool *)isError;
- (int32_t)rpcRequestBodyResponseSignature:(id)requestBody;
- (NSString *)rpcErrorDescription:(id)error;
- (int32_t)rpcErrorCode:(id)error;
- (NSString *)rpcErrorText:(id)error;

- (id)ping:(int64_t)pingId;
- (bool)isMessagePong:(id)message;
- (int64_t)pongMessageId:(id)message;
- (int64_t)pongPingId:(id)message;

- (id)msgsAck:(NSArray *)messageIds;
- (bool)isMessageMsgsAck:(id)message;
- (NSArray *)msgsAckMessageIds:(id)message;

- (bool)isMessageBadMsgNotification:(id)message;
- (int64_t)badMessageBadMessageId:(id)message;
- (bool)isMessageBadServerSaltNotification:(id)message;
- (int64_t)badMessageNewServerSalt:(id)message;
- (int32_t)badMessageErrorCode:(id)message;

- (bool)isMessageDetailedInfo:(id)message;
- (bool)isMessageDetailedResponseInfo:(id)message;
- (int64_t)detailedInfoResponseRequestMessageId:(id)message;
- (int64_t)detailedInfoResponseMessageId:(id)message;
- (int64_t)detailedInfoResponseMessageLength:(id)message;

- (bool)isMessageMsgsStateInfo:(id)message forInfoRequestMessageId:(int64_t)infoRequestMessageId;

- (bool)isMessageNewSession:(id)message;
- (int64_t)messageNewSessionFirstValidMessageId:(id)message;

- (id)httpWaitWithMaxDelay:(int32_t)maxDelay waitAfter:(int32_t)waitAfter maxWait:(int32_t)maxWait;

@end
