

#import <Foundation/Foundation.h>

@class MTContext;
@class MTTransportScheme;
@class MTTransport;
@class MTTransportTransaction;
@class MTOutgoingMessage;
@class MTIncomingMessage;
@class MTMessageTransaction;
@class MTNetworkUsageCalculationInfo;
@class MTSocksProxySettings;

#import <MtProtoKit/MTMessageService.h>


@protocol MTTransportDelegate <NSObject>

@optional

- (void)transportNetworkAvailabilityChanged:(MTTransport *)transport isNetworkAvailable:(bool)isNetworkAvailable;
- (void)transportConnectionStateChanged:(MTTransport *)transport isConnected:(bool)isConnected proxySettings:(MTSocksProxySettings *)proxySettings;
- (void)transportConnectionFailed:(MTTransport *)transport scheme:(MTTransportScheme *)scheme;
- (void)transportConnectionContextUpdateStateChanged:(MTTransport *)transport isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)transportConnectionProblemsStatusChanged:(MTTransport *)transport scheme:(MTTransportScheme *)scheme hasConnectionProblems:(bool)hasConnectionProblems isProbablyHttp:(bool)isProbablyHttp;

- (void)transportReadyForTransaction:(MTTransport *)transport scheme:(MTTransportScheme *)scheme transportSpecificTransaction:(MTMessageTransaction *)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^)(NSArray *))transactionReady;
- (void)transportHasIncomingData:(MTTransport *)transport scheme:(MTTransportScheme *)scheme data:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult;
- (void)transportTransactionsMayHaveFailed:(MTTransport *)transport transactionIds:(NSArray *)transactionIds;
- (void)transportReceivedQuickAck:(MTTransport *)transport quickAckId:(int32_t)quickAckId;
- (void)transportDecodeProgressToken:(MTTransport *)transport scheme:(MTTransportScheme *)scheme data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id progressToken))completion;
- (void)transportUpdatedDataReceiveProgress:(MTTransport *)transport progressToken:(id)progressToken packetLength:(NSInteger)packetLength progress:(float)progress;

@end

@interface MTTransport : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTransportDelegate> delegate;

@property (nonatomic, strong, readonly) MTContext *context;
@property (nonatomic, readonly) NSInteger datacenterId;
@property (nonatomic, strong, readonly) MTSocksProxySettings *proxySettings;
@property (nonatomic) bool simultaneousTransactionsEnabled;
@property (nonatomic) bool reportTransportConnectionContextUpdateStates;

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes proxySettings:(MTSocksProxySettings *)proxySettings usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (bool)needsParityCorrection;

- (void)reset;
- (void)stop;
- (void)updateConnectionState;
- (void)setDelegateNeedsTransaction;
- (void)_processIncomingData:(NSData *)data scheme:(MTTransportScheme *)scheme transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult;
- (void)_networkAvailabilityChanged:(bool)networkAvailable;

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion;

- (void)updateSchemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes;

@end
