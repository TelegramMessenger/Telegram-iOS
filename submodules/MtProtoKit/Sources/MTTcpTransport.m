#import <MtProtoKit/MTTcpTransport.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTTime.h>
#import <MtProtoKit/MTTransportScheme.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTTransportTransaction.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTPreparedMessage.h>

#import "MTTcpConnection.h"
#import "MTTcpConnectionBehaviour.h"

#import <MtProtoKit/MTSerialization.h>
#import "MTBuffer.h"
#import "MTPongMessage.h"

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>

static const NSTimeInterval MTTcpTransportSleepWatchdogTimeout = 60.0;

@interface MTTcpTransportContext : NSObject

@property (nonatomic, strong) NSArray<MTTransportScheme *> * _Nonnull schemes;
@property (nonatomic, strong) MTTcpConnection *connection;
@property (nonatomic, strong) MTSocksProxySettings *proxySettings;

@property (nonatomic) bool connectionConnected;
@property (nonatomic) bool connectionIsValid;
@property (nonatomic, strong) MTTcpConnectionBehaviour *connectionBehaviour;
@property (nonatomic) bool stopped;

@property (nonatomic) bool isNetworkAvailable;

@property (nonatomic) bool willRequestTransactionOnNextQueuePass;

@property (nonatomic) NSTimeInterval transactionLockTime;
@property (nonatomic) bool isWaitingForTransactionToBecomeReady;
@property (nonatomic) bool requestAnotherTransactionWhenReady;

@property (nonatomic) bool didSendActualizationPingAfterConnection;
@property (nonatomic) int64_t currentActualizationPingMessageId;
@property (nonatomic, strong) MTTimer *actualizationPingResendTimer;

@property (nonatomic, strong) MTTimer *connectionWatchdogTimer;
@property (nonatomic, strong) MTTimer *sleepWatchdogTimer;
@property (nonatomic) CFAbsoluteTime sleepWatchdogTimerLastTime;

@end

@implementation MTTcpTransportContext



@end

@interface MTTcpTransport () <MTTcpConnectionDelegate, MTTcpConnectionBehaviourDelegate>
{
    MTTcpTransportContext *_transportContext;
    __weak MTContext *_context;
    NSInteger _datacenterId;
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
}

@end

@implementation MTTcpTransport

+ (MTQueue *)tcpTransportQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.tcpTransportQueue"];
    });
    return queue;
}

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes proxySettings:(MTSocksProxySettings *)proxySettings usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo getLogPrefix:(NSString *(^)())getLogPrefix
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(datacenterId != 0, @"datacenterId should not be nil");
    NSAssert(schemes.count != 0, @"schemes should not be empty");
#endif
    
    self = [super initWithDelegate:delegate context:context datacenterId:datacenterId schemes:schemes proxySettings:proxySettings usageCalculationInfo:usageCalculationInfo getLogPrefix:getLogPrefix];
    if (self != nil)
    {
        _context = context;
        _datacenterId = datacenterId;
        _usageCalculationInfo = usageCalculationInfo;
        
        MTTcpTransportContext *transportContext = [[MTTcpTransportContext alloc] init];
        _transportContext = transportContext;
        
        [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
            transportContext.schemes = schemes;
            
            transportContext.connectionBehaviour = [[MTTcpConnectionBehaviour alloc] initWithQueue:[MTTcpTransport tcpTransportQueue]];
            transportContext.connectionBehaviour.delegate = self;
            
            transportContext.isNetworkAvailable = true;
            
            transportContext.proxySettings = context.apiEnvironment.socksProxySettings;
        }];
    }
    return self;
}

- (void)dealloc
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
        transportContext.connection.delegate = nil;
        
        transportContext.connectionBehaviour.needsReconnection = false;
        transportContext.connectionBehaviour.delegate = nil;
        
        [transportContext.actualizationPingResendTimer invalidate];
        transportContext.actualizationPingResendTimer = nil;
        
        [transportContext.connectionWatchdogTimer invalidate];
        transportContext.connectionWatchdogTimer = nil;
        
        [transportContext.sleepWatchdogTimer invalidate];
        transportContext.sleepWatchdogTimer = nil;
    }];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
        _usageCalculationInfo = usageCalculationInfo;
        [_transportContext.connection setUsageCalculationInfo:usageCalculationInfo];
    }];
}

- (bool)needsParityCorrection
{
    return true;
}

- (void)updateConnectionState
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportNetworkAvailabilityChanged:isNetworkAvailable:)])
            [delegate transportNetworkAvailabilityChanged:self isNetworkAvailable:transportContext.isNetworkAvailable];
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:proxySettings:)])
            [delegate transportConnectionStateChanged:self isConnected:transportContext.connectionConnected proxySettings:transportContext.proxySettings];
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:transportContext.currentActualizationPingMessageId != 0];
    }];
}

- (void)setDelegateNeedsTransaction
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (!transportContext.willRequestTransactionOnNextQueuePass)
        {
            transportContext.willRequestTransactionOnNextQueuePass = true;
            
            dispatch_async([MTTcpTransport tcpTransportQueue].nativeQueue, ^
            {
                transportContext.willRequestTransactionOnNextQueuePass = false;
                
                if (transportContext.connection == nil)
                    [transportContext.connectionBehaviour requestConnection];
                else if (transportContext.connectionConnected)
                    [self _requestTransactionFromDelegate];
            });
        }
    }];
}

- (void)startIfNeeded
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection == nil)
        {
            MTContext *context = _context;
            MTTransportScheme *scheme = [context chooseTransportSchemeForConnectionToDatacenterId:_datacenterId schemes:transportContext.schemes];
            if (scheme != nil) {
                [self startConnectionWatchdogTimer:scheme];
                [self startSleepWatchdogTimer];
                
                transportContext.connection = [[MTTcpConnection alloc] initWithContext:context datacenterId:_datacenterId scheme:scheme interface:nil usageCalculationInfo:_usageCalculationInfo getLogPrefix:self.getLogPrefix];
                transportContext.connection.delegate = self;
                [transportContext.connection start];
            }
        }
    }];
}

- (void)reset
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.connection stop];
    }];
}

- (void)stop
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self activeTransactionIds:^(NSArray *activeTransactionId)
        {
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
                [delegate transportTransactionsMayHaveFailed:self transactionIds:activeTransactionId];
        }];
        
        transportContext.stopped = true;
        transportContext.connectionConnected = false;
        transportContext.connectionIsValid = false;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:proxySettings:)])
            [delegate transportConnectionStateChanged:self isConnected:false proxySettings:transportContext.proxySettings];
        
        transportContext.connectionBehaviour.needsReconnection = false;
        
        transportContext.connection.delegate = nil;
        [transportContext.connection stop];
        transportContext.connection = nil;
        
        [self stopConnectionWatchdogTimer];
        [self stopSleepWatchdogTimer];
        
        [transportContext.actualizationPingResendTimer invalidate];
        transportContext.actualizationPingResendTimer = nil;
    }];
}

- (void)startSleepWatchdogTimer
{
/*#if false
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.sleepWatchdogTimer == nil)
        {
            transportContext.sleepWatchdogTimerLastTime = MTAbsoluteSystemTime();
            
            __weak MTTcpTransport *weakSelf = self;
            transportContext.sleepWatchdogTimer = [[MTTimer alloc] initWithTimeout:MTTcpTransportSleepWatchdogTimeout repeat:true completion:^
            {
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                
                __strong MTTcpTransport *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if (ABS(currentTime - strongSelf->_transportContext.sleepWatchdogTimerLastTime) > MTTcpTransportSleepWatchdogTimeout * 2.0)
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTTcpTransport#%p system sleep detected, resetting connection]", strongSelf);
                        }
                        [strongSelf reset];
                    }
                    strongSelf->_transportContext.sleepWatchdogTimerLastTime = currentTime;
                }
            } queue:[MTTcpConnection tcpQueue].nativeQueue];
            [_sleepWatchdogTimer start];
        }
    }];
#endif*/
}

- (void)restartSleepWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        transportContext.sleepWatchdogTimerLastTime = MTAbsoluteSystemTime();
        [transportContext.sleepWatchdogTimer resetTimeout:MTTcpTransportSleepWatchdogTimeout];
    }];
}

- (void)stopSleepWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.sleepWatchdogTimer invalidate];
        transportContext.sleepWatchdogTimer = nil;
    }];
}

- (void)startConnectionWatchdogTimer:(MTTransportScheme *)scheme
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connectionWatchdogTimer == nil)
        {
            __weak MTTcpTransport *weakSelf = self;
            transportContext.connectionWatchdogTimer = [[MTTimer alloc] initWithTimeout:20.0 repeat:false completion:^
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionWatchdogTimeout:scheme];
            } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
            [transportContext.connectionWatchdogTimer start];
        }
    }];
}

- (void)stopConnectionWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.connectionWatchdogTimer invalidate];
        transportContext.connectionWatchdogTimer = nil;
    }];
}

- (void)connectionWatchdogTimeout:(MTTransportScheme *)scheme
{
    MTTcpTransportContext *transportContext = _transportContext;
    [transportContext.connectionWatchdogTimer invalidate];
    transportContext.connectionWatchdogTimer = nil;
    
    id<MTTransportDelegate> delegate = self.delegate;
    if (scheme != nil) {
        if ([delegate respondsToSelector:@selector(transportConnectionFailed:scheme:)]) {
            [delegate transportConnectionFailed:self scheme:scheme];
        }
        if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:scheme:hasConnectionProblems:isProbablyHttp:)]) {
            [delegate transportConnectionProblemsStatusChanged:self scheme:scheme hasConnectionProblems:true isProbablyHttp:false];
        }
    }
}

- (void)startActualizationPingResendTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.actualizationPingResendTimer != nil)
            [transportContext.actualizationPingResendTimer invalidate];
        
        __weak MTTcpTransport *weakSelf = self;
        transportContext.actualizationPingResendTimer = [[MTTimer alloc] initWithTimeout:3 repeat:false completion:^
        {
            __strong MTTcpTransport *strongSelf = weakSelf;
            [strongSelf resendActualizationPing];
        } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
        [transportContext.actualizationPingResendTimer start];
    }];
}

- (void)stopActualizationPingResendTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.actualizationPingResendTimer != nil)
        {
            [transportContext.actualizationPingResendTimer invalidate];
            transportContext.actualizationPingResendTimer = nil;
        }
    }];
}

- (void)resendActualizationPing
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        
        if (transportContext.currentActualizationPingMessageId != 0)
        {
            transportContext.didSendActualizationPingAfterConnection = false;
            transportContext.currentActualizationPingMessageId = 0;
            
            [self _requestTransactionFromDelegate];
        }
    }];
}

- (void)tcpConnectionOpened:(MTTcpConnection *)connection
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        transportContext.connectionConnected = true;
        transportContext.connectionIsValid = false;
        [transportContext.connectionBehaviour connectionOpened];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:proxySettings:)])
            [delegate transportConnectionStateChanged:self isConnected:true proxySettings:transportContext.proxySettings];
        
        transportContext.didSendActualizationPingAfterConnection = false;
        transportContext.currentActualizationPingMessageId = 0;
        
        [self _requestTransactionFromDelegate];
    }];
}

- (void)tcpConnectionClosed:(MTTcpConnection *)connection error:(bool)error
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        transportContext.connectionConnected = false;
        transportContext.connectionIsValid = false;
        transportContext.connection.delegate = nil;
        transportContext.connection = nil;
        
        [transportContext.connectionBehaviour connectionClosed];
        
        transportContext.didSendActualizationPingAfterConnection = false;
        transportContext.currentActualizationPingMessageId = 0;
        
        [self restartSleepWatchdogTimer];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:proxySettings:)])
            [delegate transportConnectionStateChanged:self isConnected:false proxySettings:transportContext.proxySettings];
        
        if (error) {
            if ([delegate respondsToSelector:@selector(transportConnectionFailed:scheme:)]) {
                [delegate transportConnectionFailed:self scheme:connection.scheme];
            }
        }
        
        if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
            [delegate transportTransactionsMayHaveFailed:self transactionIds:@[connection.internalId]];
    }];
}

- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        if (transportContext.currentActualizationPingMessageId != 0 && transportContext.actualizationPingResendTimer == nil)
            [self startActualizationPingResendTimer];
        
        __weak MTTcpTransport *weakSelf = self;
        [self _processIncomingData:data scheme:connection.scheme transactionId:connection.internalId requestTransactionAfterProcessing:false decodeResult:^(id transactionId, bool success)
        {
            if (success)
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsValid:transactionId];
            }
            else
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsInvalid];
            }
        }];
    }];
}

- (void)connectionIsValid:(id)transactionId
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != nil && [transportContext.connection.internalId isEqual:transactionId])
        {
            transportContext.connectionIsValid = true;
            [transportContext.connectionBehaviour connectionValidDataReceived];
        }
        
        [self stopConnectionWatchdogTimer];
    }];
}

- (void)connectionIsInvalid
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        MTTransportScheme *scheme = _transportContext.connection.scheme;
        if (scheme != nil) {
            if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:scheme:hasConnectionProblems:isProbablyHttp:)]) {
                [delegate transportConnectionProblemsStatusChanged:self scheme:scheme hasConnectionProblems:true isProbablyHttp:true];
            }
        }
    }];
}

- (void)tcpConnectionReceivedQuickAck:(MTTcpConnection *)connection quickAck:(int32_t)quickAck
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportReceivedQuickAck:quickAckId:)])
            [delegate transportReceivedQuickAck:self quickAckId:quickAck];
    }];
}

- (void)tcpConnectionDecodePacketProgressToken:(MTTcpConnection *)connection data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id packetProgressToken))completion
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportDecodeProgressToken:scheme:data:token:completion:)])
            [delegate transportDecodeProgressToken:self scheme:connection.scheme data:data token:token completion:completion];
    }];
}

- (void)tcpConnectionProgressUpdated:(MTTcpConnection *)connection packetProgressToken:(id)packetProgressToken packetLength:(NSUInteger)packetLength progress:(float)progress
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportUpdatedDataReceiveProgress:progressToken:packetLength:progress:)])
            [delegate transportUpdatedDataReceiveProgress:self progressToken:packetProgressToken packetLength:packetLength progress:progress];
    }];
}

- (void)tcpConnectionBehaviourRequestsReconnection:(MTTcpConnectionBehaviour *)behaviour error:(bool)error
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connectionBehaviour != behaviour)
            return;
        
        if (!transportContext.stopped) {
            [self startIfNeeded];
        }
    }];
}

- (void)_requestTransactionFromDelegate
{
    MTTcpTransportContext *transportContext = _transportContext;
    if (transportContext.isWaitingForTransactionToBecomeReady)
    {
        if (!transportContext.didSendActualizationPingAfterConnection)
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%" PRIxPTR " unlocking transaction processing due to connection context update task]", (intptr_t)self);
            }
            transportContext.isWaitingForTransactionToBecomeReady = false;
            transportContext.transactionLockTime = 0.0;
        }
        else if (CFAbsoluteTimeGetCurrent() > transportContext.transactionLockTime + 1.0)
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%" PRIxPTR " unlocking transaction processing due to timeout]", (intptr_t)self);
            }
            transportContext.isWaitingForTransactionToBecomeReady = false;
            transportContext.transactionLockTime = 0.0;
        }
        else
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%" PRIxPTR " skipping transaction request]", (intptr_t)self);
            }
            transportContext.requestAnotherTransactionWhenReady = true;
            
            return;
        }
    }
    
    id<MTTransportDelegate> delegate = self.delegate;
    MTTransportScheme *scheme = transportContext.connection.scheme;
    if (scheme != nil && [delegate respondsToSelector:@selector(transportReadyForTransaction:scheme:transportSpecificTransaction:forceConfirmations:transactionReady:)])
    {
        transportContext.isWaitingForTransactionToBecomeReady = true;
        transportContext.transactionLockTime = CFAbsoluteTimeGetCurrent();
        
        MTMessageTransaction *transportSpecificTransaction = nil;
        if (!transportContext.didSendActualizationPingAfterConnection)
        {
            transportContext.didSendActualizationPingAfterConnection = true;
            
            int64_t randomId = 0;
            arc4random_buf(&randomId, 8);
            
            MTBuffer *pingBuffer = [[MTBuffer alloc] init];
            [pingBuffer appendInt32:(int32_t)0x7abe77ec];
            [pingBuffer appendInt64:randomId];
            
            MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:pingBuffer.data metadata:@"ping" additionalDebugDescription:nil shortMetadata:@"ping"];
            outgoingMessage.requiresConfirmation = false;
            
            __weak MTTcpTransport *weakSelf = self;
            transportSpecificTransaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(__unused NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
            {
                MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[outgoingMessage.internalId];
                [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                {
                    if (preparedMessage != nil)
                    {
                        __strong MTTcpTransport *strongSelf = weakSelf;
                        if (strongSelf != nil) {
                            transportContext.currentActualizationPingMessageId = preparedMessage.messageId;
                            
                            id<MTTransportDelegate> delegate = strongSelf.delegate;
                            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)]) {
                                [delegate transportConnectionContextUpdateStateChanged:strongSelf isUpdatingConnectionContext:true];
                            }
                        }
                    }
                }];
            }];
            transportSpecificTransaction.requiresEncryption = true;
        }
        
        __weak MTTcpTransport *weakSelf = self;
        [delegate transportReadyForTransaction:self scheme:scheme transportSpecificTransaction:transportSpecificTransaction forceConfirmations:transportSpecificTransaction != nil transactionReady:^(NSArray *transactionList)
        {
            [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    for (MTTransportTransaction *transaction in transactionList)
                    {
                        if (transaction.payload.length != 0)
                        {
                            bool acceptTransaction = true;
/*#ifdef DEBUG
                            if (arc4random_uniform(10) < 5) {
                                acceptTransaction = false;
                            }
#endif*/
                            if (transportContext.connection != nil && acceptTransaction)
                            {
                                id transactionId = transportContext.connection.internalId;
                                [transportContext.connection sendDatas:@[transaction.payload] completion:^(bool success)
                                {
                                    if (transaction.completion)
                                        transaction.completion(success, transactionId);
                                } requestQuickAck:transaction.needsQuickAck expectDataInResponse:transaction.expectsDataInResponse];
                            }
                            else if (transaction.completion != nil)
                                transaction.completion(false, nil);
                        }
                    }
                    
                    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                    {
                        transportContext.isWaitingForTransactionToBecomeReady = false;
                        
                        if (transportContext.requestAnotherTransactionWhenReady)
                        {
                            transportContext.requestAnotherTransactionWhenReady = false;
                            [strongSelf _requestTransactionFromDelegate];
                        }
                    }];
                }
            }];
        }];
    }
}

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (completion && transportContext.connection != nil)
            completion(@[transportContext.connection.internalId]);
    }];
}

- (void)_networkAvailabilityChanged:(bool)networkAvailable
{
    MTTcpTransportContext *transportContext = _transportContext;
    [super _networkAvailabilityChanged:networkAvailable];
    
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        transportContext.isNetworkAvailable = networkAvailable;
        
        if (networkAvailable)
            [transportContext.connectionBehaviour clearBackoff];
        
        [transportContext.connection stop];
    }];
}

- (void)mtProtoDidChangeSession:(MTProto *)__unused mtProto
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        transportContext.currentActualizationPingMessageId = 0;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
    }];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)__unused mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.currentActualizationPingMessageId != 0 && (transportContext.currentActualizationPingMessageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(transportContext.currentActualizationPingMessageId)]))
        {
            [self stopActualizationPingResendTimer];
            
            transportContext.currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)incomingMessage authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    if ([incomingMessage.body isKindOfClass:[MTPongMessage class]])
    {
        MTTcpTransportContext *transportContext = _transportContext;
        [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
        {
            if (transportContext.currentActualizationPingMessageId != 0 && ((MTPongMessage *)incomingMessage.body).messageId == transportContext.currentActualizationPingMessageId)
            {
                [self stopActualizationPingResendTimer];
                
                transportContext.currentActualizationPingMessageId = 0;
                
                id<MTTransportDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                    [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
            }
        }];
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        MTTcpTransportContext *transportContext = _transportContext;
        if (transportContext.currentActualizationPingMessageId != 0 && messageId == transportContext.currentActualizationPingMessageId)
        {
            [self stopActualizationPingResendTimer];
            transportContext.currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

- (void)updateSchemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes {
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
        if ([transportContext.schemes isEqualToArray:schemes]) {
            return;
        }
        transportContext.schemes = schemes;
        bool reset = false;
        if (![transportContext.schemes containsObject:transportContext.connection.scheme]) {
            reset = true;
        } else if (!transportContext.connectionIsValid) {
            reset = true;
        }
        if (reset) {
            [transportContext.connectionBehaviour requestConnection];
        }
    }];
}

@end
