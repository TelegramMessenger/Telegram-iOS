/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTContext.h>

@class MTDatacenterAddress;
@class MTTransport;
@class MTTransportTransaction;
@class MTOutgoingMessage;
@class MTIncomingMessage;
@class MTMessageTransaction;

#import <MTProtoKit/MTMessageService.h>

@protocol MTTransportDelegate <NSObject>

@optional

- (void)transportNetworkAvailabilityChanged:(MTTransport *)transport isNetworkAvailable:(bool)isNetworkAvailable;
- (void)transportConnectionStateChanged:(MTTransport *)transport isConnected:(bool)isConnected;
- (void)transportConnectionContextUpdateStateChanged:(MTTransport *)transport isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)transportConnectionProblemsStatusChanged:(MTTransport *)transport hasConnectionProblems:(bool)hasConnectionProblems isProbablyHttp:(bool)isProbablyHttp;

- (void)transportReadyForTransaction:(MTTransport *)transport transportSpecificTransaction:(MTMessageTransaction *)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^)(NSArray *))transactionReady;
- (void)transportHasIncomingData:(MTTransport *)transport data:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult;
- (void)transportTransactionsMayHaveFailed:(MTTransport *)transport transactionIds:(NSArray *)transactionIds;
- (void)transportReceivedQuickAck:(MTTransport *)transport quickAckId:(int32_t)quickAckId;
- (void)transportDecodeProgressToken:(MTTransport *)transport data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id progressToken))completion;
- (void)transportUpdatedDataReceiveProgress:(MTTransport *)transport progressToken:(id)progressToken packetLength:(NSInteger)packetLength progress:(float)progress;

@end

@interface MTTransport : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTransportDelegate> delegate;

@property (nonatomic, strong, readonly) MTContext *context;
@property (nonatomic, readonly) NSInteger datacenterId;
@property (nonatomic) bool simultaneousTransactionsEnabled;
@property (nonatomic) bool reportTransportConnectionContextUpdateStates;

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address;

- (bool)needsParityCorrection;

- (void)reset;
- (void)stop;
- (void)updateConnectionState;
- (void)setDelegateNeedsTransaction;
- (void)_processIncomingData:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult;
- (void)_networkAvailabilityChanged:(bool)networkAvailable;

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion;

@end
