

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

- (void)transportNetworkAvailabilityChanged:(MTTransport * _Nonnull)transport isNetworkAvailable:(bool)isNetworkAvailable;
- (void)transportConnectionStateChanged:(MTTransport * _Nonnull)transport isConnected:(bool)isConnected proxySettings:(MTSocksProxySettings * _Nullable)proxySettings;
- (void)transportConnectionFailed:(MTTransport * _Nonnull)transport scheme:(MTTransportScheme * _Nonnull)scheme;
- (void)transportConnectionContextUpdateStateChanged:(MTTransport * _Nonnull)transport isUpdatingConnectionContext:(bool)isUpdatingConnectionContext;
- (void)transportConnectionProblemsStatusChanged:(MTTransport * _Nonnull)transport scheme:(MTTransportScheme * _Nonnull)scheme hasConnectionProblems:(bool)hasConnectionProblems isProbablyHttp:(bool)isProbablyHttp;

- (void)transportReadyForTransaction:(MTTransport * _Nonnull)transport scheme:(MTTransportScheme * _Nonnull)scheme transportSpecificTransaction:(MTMessageTransaction * _Nonnull)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^ _Nonnull)(NSArray * _Nonnull))transactionReady;
- (void)transportHasIncomingData:(MTTransport * _Nonnull)transport scheme:(MTTransportScheme * _Nonnull)scheme data:(NSData * _Nonnull)data transactionId:(id _Nonnull)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^ _Nonnull)(id _Nonnull transactionId, bool success))decodeResult;
- (void)transportTransactionsMayHaveFailed:(MTTransport * _Nonnull)transport transactionIds:(NSArray * _Nonnull)transactionIds;
- (void)transportReceivedQuickAck:(MTTransport * _Nonnull)transport quickAckId:(int32_t)quickAckId;
- (void)transportDecodeProgressToken:(MTTransport * _Nonnull)transport scheme:(MTTransportScheme * _Nonnull)scheme data:(NSData * _Nonnull)data token:(int64_t)token completion:(void (^ _Nonnull)(int64_t token, id _Nonnull progressToken))completion;
- (void)transportUpdatedDataReceiveProgress:(MTTransport * _Nonnull)transport progressToken:(id _Nonnull)progressToken packetLength:(NSInteger)packetLength progress:(float)progress;

@end

@interface MTTransport : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTransportDelegate> _Nullable delegate;

@property (nonatomic, strong, readonly) MTContext * _Nullable context;
@property (nonatomic, readonly) NSInteger datacenterId;
@property (nonatomic, strong, readonly) MTSocksProxySettings * _Nullable proxySettings;
@property (nonatomic) bool simultaneousTransactionsEnabled;
@property (nonatomic) bool reportTransportConnectionContextUpdateStates;
@property (nonatomic, strong) NSString * _Nullable (^ _Nullable getLogPrefix)();

- (instancetype _Nonnull)initWithDelegate:(id<MTTransportDelegate> _Nullable)delegate context:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes proxySettings:(MTSocksProxySettings * _Null_unspecified)proxySettings usageCalculationInfo:(MTNetworkUsageCalculationInfo * _Nullable)usageCalculationInfo getLogPrefix:(NSString * _Nullable (^ _Nullable)())getLogPrefix;

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo * _Null_unspecified)usageCalculationInfo;

- (bool)needsParityCorrection;

- (void)reset;
- (void)stop;
- (void)updateConnectionState;
- (void)setDelegateNeedsTransaction;
- (void)_processIncomingData:(NSData * _Nonnull)data scheme:(MTTransportScheme * _Nonnull)scheme transactionId:(id _Nonnull)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^ _Nonnull)(id _Nonnull transactionId, bool success))decodeResult;
- (void)_networkAvailabilityChanged:(bool)networkAvailable;

- (void)activeTransactionIds:(void (^ _Nonnull)(NSArray * _Nonnull activeTransactionId))completion;

- (void)updateSchemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes;

@end
