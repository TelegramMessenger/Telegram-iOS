#import <MtProtoKit/MTProto.h>

#import <inttypes.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTOutputStream.h>
#import <MtProtoKit/MTInputStream.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTTransportScheme.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTSessionInfo.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import <MtProtoKit/MTTimeFixContext.h>

#import <MtProtoKit/MTMessageService.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTTimeSyncMessageService.h>
#import <MtProtoKit/MTResendMessageService.h>

#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTPreparedMessage.h>
#import <MtProtoKit/MTMessageEncryptionKey.h>

#import <MtProtoKit/MTTransport.h>
#import <MtProtoKit/MTTransportTransaction.h>

#import <MtProtoKit/MTTcpTransport.h>

#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTEncryption.h>

#import <MtProtoKit/MTTimer.h>

#import "MTBuffer.h"
#import "MTInternalMessageParser.h"
#import "MTMsgContainerMessage.h"
#import "MTMessage.h"
#import "MTBadMsgNotificationMessage.h"
#import "MTMsgsAckMessage.h"
#import "MTMsgDetailedInfoMessage.h"
#import "MTNewSessionCreatedMessage.h"
#import "MTPongMessage.h"
#import "MTRpcResultMessage.h"
#import <MtProtoKit/MTRpcError.h>

#import "MTConnectionProbing.h"

#import <MtProtoKit/MTApiEnvironment.h>

#import <MtProtoKit/MTTime.h>

#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTQueue.h>

typedef enum {
    MTProtoStateAwaitingDatacenterScheme = 1,
    MTProtoStateAwaitingDatacenterAuthorization = 2,
    MTProtoStateAwaitingDatacenterAuthToken = 8,
    MTProtoStateAwaitingTimeFixAndSalts = 16,
    MTProtoStateAwaitingLostMessages = 32,
    MTProtoStateStopped = 64,
    MTProtoStatePaused = 128
} MTProtoState;

static const NSUInteger MTMaxContainerSize = 3 * 1024;
static const NSUInteger MTMaxUnacknowledgedMessageSize = 1 * 1024 * 1024;
static const NSUInteger MTMaxUnacknowledgedMessageCount = 64;

@implementation MTProtoConnectionState

- (instancetype)initWithIsConnected:(bool)isConnected proxyAddress:(NSString *)proxyAddress proxyHasConnectionIssues:(bool)proxyHasConnectionIssues {
    self = [super init];
    if (self != nil) {
        _isConnected = isConnected;
        _proxyAddress = proxyAddress;
        _proxyHasConnectionIssues = proxyHasConnectionIssues;
    }
    return self;
}

@end

@interface MTProtoValidAuthInfo : NSObject

@property (nonatomic, strong, readonly) MTDatacenterAuthInfo *authInfo;
@property (nonatomic, readonly) MTDatacenterAuthInfoSelector selector;

@end

@implementation MTProtoValidAuthInfo

- (instancetype)initWithAuthInfo:(MTDatacenterAuthInfo *)authInfo selector:(MTDatacenterAuthInfoSelector)selector {
    self = [super init];
    if (self != nil) {
        _authInfo = authInfo;
        _selector = selector;
    }
    return self;
}

@end

@interface MTProto () <MTContextChangeListener, MTTransportDelegate, MTTimeSyncMessageServiceDelegate, MTResendMessageServiceDelegate>
{
    NSMutableArray *_messageServices;
    
    MTProtoValidAuthInfo *_validAuthInfo;
    NSNumber *_awaitingAuthInfoForSelector;
    
    MTSessionInfo *_sessionInfo;
    MTTimeFixContext *_timeFixContext;
    
    MTTransport *_transport;
    
    int _mtState;
    
    bool _willRequestTransactionOnNextQueuePass;
    
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
    
    MTProtoConnectionState *_connectionState;
    
    bool _isProbing;
    MTMetaDisposable *_probingDisposable;
    NSNumber *_probingStatus;
    
    bool _isConnectionThrottled;
    MTTimer *_unthrottleConnectionTimer;
}

@end

@implementation MTProto

+ (MTQueue *)managerQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.managerQueue"];
    });
    return queue;
}

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo requiredAuthToken:(id)requiredAuthToken authTokenMasterDatacenterId:(NSInteger)authTokenMasterDatacenterId
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(context.serialization != nil, @"context serialization should not be nil");
    NSAssert(datacenterId != 0, @"datacenterId should not be 0");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _datacenterId = datacenterId;
        _usageCalculationInfo = usageCalculationInfo;
        _apiEnvironment = context.apiEnvironment;
        _requiredAuthToken = requiredAuthToken;
        _authTokenMasterDatacenterId = authTokenMasterDatacenterId;
        
        [_context addChangeListener:self];
        
        _messageServices = [[NSMutableArray alloc] init];
        
        _sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:_context];
        
        _shouldStayConnected = true;
        
        _mtState |= MTProtoStatePaused;
        
        [self setMtState:_mtState | MTProtoStatePaused];
    }
    return self;
}

- (void)dealloc
{
    MTTransport *transport = _transport;
    _transport.delegate = nil;
    _transport = nil;
    id<MTDisposable> probingDisposable = _probingDisposable;
    
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        [transport stop];
        [probingDisposable dispose];
    }];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    [[MTProto managerQueue] dispatchOnQueue:^{
        _usageCalculationInfo = usageCalculationInfo;
        [_transport setUsageCalculationInfo:usageCalculationInfo];
    }];
}

- (void)pause
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ((_mtState & MTProtoStatePaused) == 0)
        {
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p pause]", self, _context);
            }
            MTShortLog(@"[MTProto#%p@%p pause]", self, _context);
            
            _mtState |= MTProtoStatePaused;
            
            [self setMtState:_mtState | MTProtoStatePaused];
            [self setTransport:nil];
        }
    }];
}

- (void)resume
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_mtState & MTProtoStatePaused)
        {
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p resume]", self, _context);
            }
            MTShortLog(@"[MTProto#%p@%p resume]", self, _context);
            
            [self setMtState:_mtState & (~MTProtoStatePaused)];
            
            [self resetTransport];
            [self requestTransportTransaction];
        }
    }];
}

- (void)stop
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ((_mtState & MTProtoStateStopped) == 0)
        {
            [self setMtState:_mtState | MTProtoStateStopped];
            [_context removeChangeListener:self];
            if (_transport != nil)
            {
                _transport.delegate = nil;
                [_transport stop];
                [self setTransport:nil];
            }
        }
    }];
}

- (void)updateConnectionState
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != nil)
            [_transport updateConnectionState];
        else
        {
            id<MTProtoDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(mtProtoNetworkAvailabilityChanged:isNetworkAvailable:)])
                [delegate mtProtoNetworkAvailabilityChanged:self isNetworkAvailable:false];
            if ([delegate respondsToSelector:@selector(mtProtoConnectionStateChanged:state:)])
                [delegate mtProtoConnectionStateChanged:self state:nil];
            if ([delegate respondsToSelector:@selector(mtProtoConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate mtProtoConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

- (void)setTransport:(MTTransport *)transport
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p changing transport %@#%p to %@#%p]", self, _context, [_transport class] == nil ? @"" : NSStringFromClass([_transport class]), _transport, [transport class] == nil ? @"" : NSStringFromClass([transport class]), transport);
        }
        
        [self allTransactionsMayHaveFailed];
        
        MTTransport *previousTransport = _transport;
        [_transport activeTransactionIds:^(NSArray *transactionIds)
        {
            [self transportTransactionsMayHaveFailed:previousTransport transactionIds:transactionIds];
        }];
        
        _timeFixContext = nil;
        
        if (_transport != nil)
            [self removeMessageService:_transport];
        
        _transport = transport;
        [previousTransport stop];
        
        if (_transport != nil)
            [self addMessageService:_transport];
        
        [self updateConnectionState];
    }];
}

- (void)resetTransport
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_mtState & MTProtoStateStopped)
            return;
        
        if (_transport != nil)
        {
            _transport.delegate = nil;
            [_transport stop];
            [self setTransport:nil];
        }
        
        NSArray<MTTransportScheme *> *transportSchemes = [_context transportSchemesForDatacenterWithId:_datacenterId media:_media enforceMedia:_enforceMedia isProxy:_apiEnvironment.socksProxySettings != nil];
        
        if (transportSchemes.count == 0) {
            if ((_mtState & MTProtoStateAwaitingDatacenterScheme) == 0) {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterScheme];
                
                [_context transportSchemeForDatacenterWithIdRequired:_datacenterId media:_media];
            }
        }
        else if (_requiredAuthToken != nil && !_useUnauthorizedMode && ![_requiredAuthToken isEqual:[_context authTokenForDatacenterWithId:_datacenterId]]) {
            if ((_mtState & MTProtoStateAwaitingDatacenterAuthToken) == 0) {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterAuthToken];
                
                [_context authTokenForDatacenterWithIdRequired:_datacenterId authToken:_requiredAuthToken masterDatacenterId:_authTokenMasterDatacenterId];
            }
        } else {
            assert(transportSchemes.count != 0);
            MTTransport *transport = [[MTTcpTransport alloc] initWithDelegate:self context:_context datacenterId:_datacenterId schemes:transportSchemes proxySettings:_context.apiEnvironment.socksProxySettings usageCalculationInfo:_usageCalculationInfo getLogPrefix:_getLogPrefix];
            
            [self setTransport:transport];
        }
    }];
}

- (void)resetSessionInfo
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p resetting session]", self, _context);
        }
        MTShortLog(@"[MTProto#%p@%p resetting session]", self, _context);
        
        _sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:_context];
        _timeFixContext = nil;
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            if ([messageService respondsToSelector:@selector(mtProtoDidChangeSession:)])
                [messageService mtProtoDidChangeSession:self];
        }
        
        [self resetTransport];
        [self requestTransportTransaction];
    }];
}

- (void)finalizeSession {
}

- (void)requestTimeResync
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        bool alreadySyncing = false;
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            if ([messageService isKindOfClass:[MTTimeSyncMessageService class]])
            {
                alreadySyncing = true;
                break;
            }
        }
        
        if (!alreadySyncing)
        {
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p begin time sync]", self, _context);
            }
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p begin time sync]", self, _context);
            
            MTTimeSyncMessageService *timeSyncService = [[MTTimeSyncMessageService alloc] init];
            timeSyncService.delegate = self;
            [self addMessageService:timeSyncService];
        }
    }];
}

- (void)setMtState:(int)mtState
{
    bool wasPerformingServiceTasks = _mtState & MTProtoStateAwaitingTimeFixAndSalts;
    
    _mtState = mtState;
    
    bool performingServiceTasks = _mtState & MTProtoStateAwaitingTimeFixAndSalts;
    
    if (performingServiceTasks != wasPerformingServiceTasks)
    {
        bool haveResendMessagesPending = false;
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService isKindOfClass:[MTResendMessageService class]])
            {
                haveResendMessagesPending = true;
                
                break;
            }
        }
        
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, haveResendMessagesPending ? "yes" : "no");
        }
        MTShortLog(@"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, haveResendMessagesPending ? "yes" : "no");
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
                [messageService mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:performingServiceTasks || haveResendMessagesPending];
        }
        
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
            [delegate mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:performingServiceTasks || haveResendMessagesPending];
    }
}

- (void)addMessageService:(id<MTMessageService>)messageService
{
    if ([messageService respondsToSelector:@selector(mtProtoWillAddService:)])
        [messageService mtProtoWillAddService:self];
    
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        bool notifyAboutServiceTask = false;
        
        if ([messageService isKindOfClass:[MTResendMessageService class]])
        {
            notifyAboutServiceTask = true;
            
            for (id<MTMessageService> currentService in _messageServices)
            {
                if ([currentService isKindOfClass:[MTResendMessageService class]])
                {
                    notifyAboutServiceTask = false;
                    
                    break;
                }
            }
        }
        
        if (![_messageServices containsObject:messageService])
        {
            [_messageServices addObject:messageService];
            
            if ([messageService respondsToSelector:@selector(mtProtoDidAddService:)])
                [messageService mtProtoDidAddService:self];
        }
        
        if (notifyAboutServiceTask)
        {
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, "yes");
            }
            MTShortLog(@"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, "yes");
            
            for (id<MTMessageService> messageService in _messageServices)
            {
                if ([messageService respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
                    [messageService mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:true];
            }
            
            id<MTProtoDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
                [delegate mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:true];
        }
    }];
}

- (void)removeMessageService:(id<MTMessageService>)messageService
{
    if (messageService == nil)
        return;
    
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ([_messageServices containsObject:messageService])
        {
            [_messageServices removeObject:messageService];
            
            if ([messageService respondsToSelector:@selector(mtProtoDidRemoveService:)])
                [messageService mtProtoDidRemoveService:self];
            
            bool notifyAboutServiceTask = false;
            if ([messageService isKindOfClass:[MTResendMessageService class]])
            {
                notifyAboutServiceTask = true;
                
                for (id<MTMessageService> currentService in _messageServices)
                {
                    if ([currentService isKindOfClass:[MTResendMessageService class]])
                    {
                        notifyAboutServiceTask = false;
                        
                        break;
                    }
                }
            }
            
            if (notifyAboutServiceTask)
            {
                bool performingServiceTasks = _mtState & MTProtoStateAwaitingTimeFixAndSalts;
                if (!performingServiceTasks)
                {
                    if (MTLogEnabled()) {
                        MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, "no");
                    }
                    MTShortLog(@"[MTProto#%p@%p service tasks state: %d, resend: %s]", self, _context, _mtState, "no");
                    
                    for (id<MTMessageService> messageService in _messageServices)
                    {
                        if ([messageService respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
                            [messageService mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:false];
                    }
                    
                    id<MTProtoDelegate> delegate = _delegate;
                    if ([delegate respondsToSelector:@selector(mtProtoServiceTasksStateChanged:isPerformingServiceTasks:)])
                        [delegate mtProtoServiceTasksStateChanged:self isPerformingServiceTasks:false];
                }
            }
        }
    }];
}

- (MTQueue *)messageServiceQueue
{
    return [MTProto managerQueue];
}

- (void)initiateTimeSync
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ((_mtState & MTProtoStateAwaitingTimeFixAndSalts) == 0)
        {
            [self setMtState:_mtState | MTProtoStateAwaitingTimeFixAndSalts];
            
            [self requestTimeResync];
        }
    }];
}

- (void)completeTimeSync
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ((_mtState & MTProtoStateAwaitingTimeFixAndSalts) != 0)
        {
            [self setMtState:_mtState & (~MTProtoStateAwaitingTimeFixAndSalts)];
            
            for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
            {
                id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
                
                if ([messageService isKindOfClass:[MTTimeSyncMessageService class]])
                {
                    ((MTTimeSyncMessageService *)messageService).delegate = nil;
                    [self removeMessageService:messageService];
                }
            }
        }
    }];
}

- (void)requestMessageWithId:(int64_t)messageId
{
    bool alreadyRequestingThisMessage = false;
    
    for (id<MTMessageService> messageService in _messageServices)
    {
        if ([messageService isKindOfClass:[MTResendMessageService class]])
        {
            if (((MTResendMessageService *)messageService).messageId == messageId)
            {
                alreadyRequestingThisMessage = true;
                
                break;
            }
        }
    }
    
    if (!alreadyRequestingThisMessage && ![_sessionInfo messageProcessed:messageId])
    {
        MTResendMessageService *resendService = [[MTResendMessageService alloc] initWithMessageId:messageId];
        resendService.delegate = self;
        [self addMessageService:resendService];
    }
}

- (void)resendMessageServiceCompleted:(MTResendMessageService *)resendService
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        resendService.delegate = nil;
        [self removeMessageService:resendService];
    }];
}

- (void)requestTransportTransaction
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (!_willRequestTransactionOnNextQueuePass)
        {
            _willRequestTransactionOnNextQueuePass = true;
            
            dispatch_async([MTProto managerQueue].nativeQueue, ^
            {
                _willRequestTransactionOnNextQueuePass = false;
                
                if ([self isStopped] || [self isPaused] || _isConnectionThrottled) {
                    return;
                }
                
                if (_transport == nil)
                    [self resetTransport];
                
                [_transport setDelegateNeedsTransaction];
            });
        }
    }];
}

- (void)requestSecureTransportReset
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ([self isStopped])
            return;
        
        if (_transport != nil)
            [_transport reset];
    }];
}

- (bool)canAskForTransactions
{
    return (_mtState & (MTProtoStateAwaitingDatacenterScheme | MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterAuthToken | MTProtoStateAwaitingTimeFixAndSalts | MTProtoStateStopped)) == 0;
}

- (bool)canAskForServiceTransactions
{
    return (_mtState & (MTProtoStateAwaitingDatacenterScheme | MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterAuthToken | MTProtoStateStopped)) == 0;
}

- (bool)timeFixOrSaltsMissing
{
    return _mtState & MTProtoStateAwaitingTimeFixAndSalts;
}

- (bool)isStopped
{
    return (_mtState & MTProtoStateStopped) != 0;
}

- (bool)isPaused
{
    return (_mtState & MTProtoStatePaused) != 0;
}

- (void)transportNetworkAvailabilityChanged:(MTTransport *)transport isNetworkAvailable:(bool)isNetworkAvailable
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p network state: %s]", self, _context, isNetworkAvailable ? "available" : "waiting");
        }
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProtoNetworkAvailabilityChanged:isNetworkAvailable:)])
                [messageService mtProtoNetworkAvailabilityChanged:self isNetworkAvailable:isNetworkAvailable];
        }
        
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoNetworkAvailabilityChanged:isNetworkAvailable:)])
            [delegate mtProtoNetworkAvailabilityChanged:self isNetworkAvailable:isNetworkAvailable];
    }];
}

- (void)transportConnectionFailed:(MTTransport *)transport scheme:(MTTransportScheme *)scheme {
    [[MTProto managerQueue] dispatchOnQueue:^{
        if (transport != _transport)
            return;
        [_context reportTransportSchemeFailureForDatacenterId:_datacenterId transportScheme:scheme];
    }];
}

- (void)transportConnectionStateChanged:(MTTransport *)transport isConnected:(bool)isConnected proxySettings:(MTSocksProxySettings *)proxySettings
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p transport #%p connection state: %s]", self, _context, transport, isConnected ? "connected" : "connecting");
        }
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProtoConnectionStateChanged:isConnected:)])
                [messageService mtProtoConnectionStateChanged:self isConnected:isConnected];
        }
        
        MTProtoConnectionState *connectionState = [[MTProtoConnectionState alloc] initWithIsConnected:isConnected proxyAddress:proxySettings.ip proxyHasConnectionIssues:[_probingStatus boolValue]];
        _connectionState = connectionState;
        
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoConnectionStateChanged:state:)]) {
            [delegate mtProtoConnectionStateChanged:self state:connectionState];
        }
    }];
}

- (void)transportConnectionContextUpdateStateChanged:(MTTransport *)transport isUpdatingConnectionContext:(bool)isUpdatingConnectionContext
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p connection context update state: %s]", self, _context, isUpdatingConnectionContext ? "updating" : "up to date");
        }
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProtoConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [messageService mtProtoConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:isUpdatingConnectionContext];
        }
        
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate mtProtoConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:isUpdatingConnectionContext];
    }];
}

- (void)transportConnectionProblemsStatusChanged:(MTTransport *)transport scheme:(MTTransportScheme *)scheme hasConnectionProblems:(bool)hasConnectionProblems isProbablyHttp:(bool)isProbablyHttp
{
    [[MTProto managerQueue] dispatchOnQueue:^ {
        if (_transport != transport) {
            return;
        }
        
        if (hasConnectionProblems) {
            [_context reportTransportSchemeFailureForDatacenterId:_datacenterId transportScheme:scheme];
            [_context invalidateTransportSchemeForDatacenterId:_datacenterId transportScheme:scheme isProbablyHttp:isProbablyHttp media:_media];
        } else {
            [_context revalidateTransportSchemeForDatacenterId:_datacenterId transportScheme:scheme media:_media];
        }
        
        if (!hasConnectionProblems || transport.proxySettings == nil || !_checkForProxyConnectionIssues) {
            if (_isProbing) {
                _isProbing = false;
                [_probingDisposable setDisposable:nil];
                if (_probingStatus != nil) {
                    _probingStatus = nil;
                    [self _updateConnectionIssuesStatus:false];
                }
            }
        } else {
            if (!_isProbing) {
                
                _isProbing = true;
                __weak MTProto *weakSelf = self;
                MTSignal *checkSignal = [[MTConnectionProbing probeProxyWithContext:_context datacenterId:_datacenterId settings:transport.proxySettings] delay:5.0 onQueue:[MTQueue concurrentDefaultQueue]];
                checkSignal = [[checkSignal then:[[MTSignal complete] delay:20.0 onQueue:[MTQueue concurrentDefaultQueue]]] restart];
                [_probingDisposable setDisposable:[checkSignal startWithNext:^(NSNumber *next) {
                    [[MTProto managerQueue] dispatchOnQueue:^{
                        __strong MTProto *strongSelf = weakSelf;
                        if (strongSelf == nil) {
                            return;
                        }
                        if (strongSelf->_isProbing) {
                            strongSelf->_probingStatus = next;
                            [strongSelf _updateConnectionIssuesStatus:[strongSelf->_probingStatus boolValue]];
                        }
                    }];
                }]];
            }
        }
    }];
}
    
- (void)_updateConnectionIssuesStatus:(bool)value {
    if (_connectionState != nil) {
        _connectionState = [[MTProtoConnectionState alloc] initWithIsConnected:_connectionState.isConnected proxyAddress:_connectionState.proxyAddress proxyHasConnectionIssues:value];
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoConnectionStateChanged:state:)]) {
            [delegate mtProtoConnectionStateChanged:self state:_connectionState];
        }
    }
}

- (NSString *)outgoingMessageDescription:(MTOutgoingMessage *)message messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    return [[NSString alloc] initWithFormat:@"%@%@ (%" PRId64 "/%" PRId32 ")", message.metadata, message.additionalDebugDescription != nil ? message.additionalDebugDescription : @"", message.messageId == 0 ? messageId : message.messageId, message.messageSeqNo == 0 ? message.messageSeqNo : messageSeqNo];
}

- (NSString *)outgoingShortMessageDescription:(MTOutgoingMessage *)message messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    return [[NSString alloc] initWithFormat:@"%@ (%" PRId64 "/%" PRId32 ")", message.shortMetadata, message.messageId == 0 ? messageId : message.messageId, message.messageSeqNo == 0 ? message.messageSeqNo : messageSeqNo];
}

- (NSString *)incomingMessageDescription:(MTIncomingMessage *)message
{
    return [[NSString alloc] initWithFormat:@"%@ (%" PRId64", %" PRId64"/%" PRId64")", message.body, message.messageId, message.authKeyId, message.sessionId];
}

- (MTDatacenterAuthKey *)getAuthKeyForCurrentScheme:(MTTransportScheme *)scheme createIfNeeded:(bool)createIfNeeded authInfoSelector:(MTDatacenterAuthInfoSelector *)authInfoSelector {
    if (_useExplicitAuthKey) {
        MTDatacenterAuthInfoSelector selector = MTDatacenterAuthInfoSelectorEphemeralMain;
        if (authInfoSelector != nil) {
            *authInfoSelector = selector;
        }
        
        if (_validAuthInfo != nil && _validAuthInfo.selector == selector) {
            return [[MTDatacenterAuthKey alloc] initWithAuthKey:_validAuthInfo.authInfo.authKey authKeyId:_validAuthInfo.authInfo.authKeyId notBound:false];
        }
        
        MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:_useExplicitAuthKey.authKey authKeyId:_useExplicitAuthKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:0 lastValidMessageId:0]] authKeyAttributes:nil];
        
        _validAuthInfo = [[MTProtoValidAuthInfo alloc] initWithAuthInfo:authInfo selector:selector];
        return [[MTDatacenterAuthKey alloc] initWithAuthKey:_validAuthInfo.authInfo.authKey authKeyId:_validAuthInfo.authInfo.authKeyId notBound:false];
    } else {
        MTDatacenterAuthInfoSelector selector = MTDatacenterAuthInfoSelectorPersistent;
        
        if (_cdn) {
            selector = MTDatacenterAuthInfoSelectorPersistent;
        } else {
            if (_useTempAuthKeys) {
                if (scheme.address.preferForMedia) {
                    selector = MTDatacenterAuthInfoSelectorEphemeralMedia;
                } else {
                    selector = MTDatacenterAuthInfoSelectorEphemeralMain;
                }
            } else {
                selector = MTDatacenterAuthInfoSelectorPersistent;
            }
        }
        
        if (authInfoSelector != nil) {
            *authInfoSelector = selector;
        }
        
        if (_validAuthInfo != nil && _validAuthInfo.selector == selector) {
            return [[MTDatacenterAuthKey alloc] initWithAuthKey:_validAuthInfo.authInfo.authKey authKeyId:_validAuthInfo.authInfo.authKeyId notBound:false];
        } else {
            _validAuthInfo = nil;
            if (createIfNeeded) {
                MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_datacenterId selector:selector];
                if (authInfo != nil) {
                    _validAuthInfo = [[MTProtoValidAuthInfo alloc] initWithAuthInfo:authInfo selector:selector];
                    return [[MTDatacenterAuthKey alloc] initWithAuthKey:_validAuthInfo.authInfo.authKey authKeyId:_validAuthInfo.authInfo.authKeyId notBound:false];
                } else {
                    [_context performBatchUpdates:^{
                        [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil selector:selector];
                        [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:_cdn selector:selector allowUnboundEphemeralKeys:_allowUnboundEphemeralKeys];
                    }];
                    _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
                    _awaitingAuthInfoForSelector = @(selector);
                    
                    return nil;
                }
            } else {
                return nil;
            }
        }
    }
}

- (void)transportReadyForTransaction:(MTTransport *)transport scheme:(MTTransportScheme *)scheme transportSpecificTransaction:(MTMessageTransaction *)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^)(NSArray *))transactionReady
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport)
        {
            if (transactionReady)
                transactionReady(nil);
            return;
        }
        
        if (!([self canAskForServiceTransactions] || [self canAskForTransactions])) {
            if (transactionReady) {
                transactionReady(nil);
            }
            return;
        }
        
        MTDatacenterAuthKey *authKey = nil;
        MTDatacenterAuthInfoSelector authInfoSelector = MTDatacenterAuthInfoSelectorPersistent;
        if (!_useUnauthorizedMode) {
            authKey = [self getAuthKeyForCurrentScheme:scheme createIfNeeded:true authInfoSelector:&authInfoSelector];
        
            if (authKey == nil) {
                if (transactionReady) {
                    transactionReady(nil);
                }
                return;
            }
        }
        
        bool extendedPadding = false;
        if (transport.proxySettings != nil && transport.proxySettings.secret != nil) {
            MTProxySecret *parsedSecret = [MTProxySecret parseData:transport.proxySettings.secret];
            if ([parsedSecret isKindOfClass:[MTProxySecretType1 class]] || [parsedSecret isKindOfClass:[MTProxySecretType2 class]]) {
                extendedPadding = true;
            }
        } else if (scheme.address.secret != nil) {
            MTProxySecret *parsedSecret = [MTProxySecret parseData:scheme.address.secret];
            if ([parsedSecret isKindOfClass:[MTProxySecretType1 class]] || [parsedSecret isKindOfClass:[MTProxySecretType2 class]]) {
                extendedPadding = true;
            }
        }
        
        if ([self canAskForTransactions])
        {
            MTSessionInfo *transactionSessionInfo = _sessionInfo;
            
            NSMutableArray *messageTransactions = [[NSMutableArray alloc] init];
            
            if (transportSpecificTransaction != nil)
            {
                if (!(transportSpecificTransaction.requiresEncryption && _useUnauthorizedMode) && (!transportSpecificTransaction.requiresEncryption || authKey != nil))
                {
                    [messageTransactions addObject:transportSpecificTransaction];
                }
            }
            
            bool anyTransactionHasHighPriorityMessages = false;
            
            NSMutableArray *messageServiceTransactions = [[NSMutableArray alloc] init];
            for (id<MTMessageService> messageService in _messageServices)
            {
                if ([messageService respondsToSelector:@selector(mtProtoMessageTransaction:authInfoSelector:sessionInfo:scheme:)])
                {
                    MTMessageTransaction *messageTransaction = [messageService mtProtoMessageTransaction:self authInfoSelector:authInfoSelector sessionInfo:transactionSessionInfo scheme:scheme];
                    if (messageTransaction != nil)
                    {
                        for (MTOutgoingMessage *message in messageTransaction.messagePayload)
                        {
                            if (message.hasHighPriority)
                            {
                                anyTransactionHasHighPriorityMessages = true;
                                break;
                            }
                        }
                        
                        [messageServiceTransactions addObject:messageTransaction];
                    }
                }
            }
            
            if (forceConfirmations || !anyTransactionHasHighPriorityMessages || [transactionSessionInfo scheduledMessageConfirmationsExceedSize:MTMaxUnacknowledgedMessageSize orCount:MTMaxUnacknowledgedMessageCount])
            {
                NSArray *scheduledMessageConfirmations = [transactionSessionInfo scheduledMessageConfirmations];
                if (scheduledMessageConfirmations.count != 0)
                {
                    MTBuffer *msgsAckBuffer = [[MTBuffer alloc] init];
                    [msgsAckBuffer appendInt32:(int32_t)0x62d6b459];
                    [msgsAckBuffer appendInt32:481674261];
                    [msgsAckBuffer appendInt32:(int32_t)scheduledMessageConfirmations.count];
                    for (NSNumber *nMessageId in scheduledMessageConfirmations)
                    {
                        [msgsAckBuffer appendInt64:(int64_t)[nMessageId longLongValue]];
                    }
                    
                    MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:msgsAckBuffer.data metadata:@"msgsAck" additionalDebugDescription:nil shortMetadata:@"msgsAck"];
                    outgoingMessage.requiresConfirmation = false;
                    
                    [messageTransactions addObject:[[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(__unused NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                    {
                        if (messageInternalIdToTransactionId[outgoingMessage.internalId] != nil && messageInternalIdToPreparedMessage[outgoingMessage.internalId] != nil)
                        {
                            [transactionSessionInfo assignTransactionId:messageInternalIdToTransactionId[outgoingMessage.internalId] toScheduledMessageConfirmationsWithIds:scheduledMessageConfirmations];
                        }
                    }]];
                }
            }
            
            [messageTransactions addObjectsFromArray:messageServiceTransactions];
            
            NSMutableArray *transactionMessageList = [[NSMutableArray alloc] init];
            NSMutableDictionary *messageInternalIdToPreparedMessage = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *preparedMessageInternalIdToMessageInternalId = [[NSMutableDictionary alloc] init];
            
            bool monotonityViolated = false;
            bool saltSetEmpty = false;
            
            int64_t messageSalt = 0;
            if (!_useUnauthorizedMode)
            {
                messageSalt = [_validAuthInfo.authInfo authSaltForMessageId:[transactionSessionInfo actualClientMessagId]];
                if (messageSalt == 0)
                    saltSetEmpty = true;
            }
            
            bool transactionNeedsQuickAck = false;
            bool transactionExpectsDataInResponse = false;
            
            for (MTMessageTransaction *messageTransaction in messageTransactions)
            {
                for (MTOutgoingMessage *outgoingMessage in messageTransaction.messagePayload)
                {
                    int64_t messageId = 0;
                    int32_t messageSeqNo = 0;
                    if (outgoingMessage.messageId == 0)
                    {
                        messageId = [transactionSessionInfo generateClientMessageId:&monotonityViolated];
                        messageSeqNo = [transactionSessionInfo takeSeqNo:outgoingMessage.requiresConfirmation];
                    }
                    else
                    {
                        messageId = outgoingMessage.messageId;
                        messageSeqNo = outgoingMessage.messageSeqNo;
                    }
                    
                    NSData *messageData = outgoingMessage.data;
                    
                    if (outgoingMessage.dynamicDecorator != nil)
                    {
                        id decoratedData = outgoingMessage.dynamicDecorator(messageId, messageData, messageInternalIdToPreparedMessage);
                        if (decoratedData != nil)
                            messageData = decoratedData;
                    }
                    
                    NSData *data = messageData;
                    
                    if (MTLogEnabled()) {
                        NSString *messageDescription = [self outgoingMessageDescription:outgoingMessage messageId:messageId messageSeqNo:messageSeqNo];
                        MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p preparing %@]", self, _context, messageDescription);
                    }
                    NSString *shortMessageDescription = [self outgoingShortMessageDescription:outgoingMessage messageId:messageId messageSeqNo:messageSeqNo];
                    MTShortLog(@"[MTProto#%p@%p preparing %@]", self, _context, shortMessageDescription);
                    
                    if (!monotonityViolated || _useUnauthorizedMode)
                    {
                        MTPreparedMessage *preparedMessage = [[MTPreparedMessage alloc] initWithData:data messageId:messageId seqNo:messageSeqNo salt:messageSalt requiresConfirmation:outgoingMessage.requiresConfirmation hasHighPriority:outgoingMessage.hasHighPriority inResponseToMessageId:outgoingMessage.inResponseToMessageId];
                        
                        if (outgoingMessage.needsQuickAck)
                            transactionNeedsQuickAck = true;
                        if (outgoingMessage.requiresConfirmation)
                            transactionExpectsDataInResponse = true;
                        
                        messageInternalIdToPreparedMessage[outgoingMessage.internalId] = preparedMessage;
                        preparedMessageInternalIdToMessageInternalId[preparedMessage.internalId] = outgoingMessage.internalId;
                        
                        [transactionMessageList addObject:preparedMessage];
                    }
                }
                
                if ([transport needsParityCorrection] && !transactionExpectsDataInResponse)
                    transactionNeedsQuickAck = true;
            }
            
            for (MTMessageTransaction *messageTransaction in messageTransactions)
            {
                if (messageTransaction.prepared) {
                    messageTransaction.prepared(messageInternalIdToPreparedMessage);
                }
            }
            
            if (monotonityViolated || saltSetEmpty)
            {
                for (MTMessageTransaction *messageTransaction in messageTransactions)
                {
                    if (messageTransaction.completion)
                        messageTransaction.completion(nil, nil, nil);
                }
                
                if (transactionReady != nil)
                    transactionReady(nil);
                
                if (monotonityViolated)
                {
                    if (MTLogEnabled()) {
                        MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p client message id monotonity violated]", self, _context);
                    }
                    MTShortLog(@"[MTProto#%p@%p client message id monotonity violated]", self, _context);
                    
                    [self resetSessionInfo];
                }
                else if (saltSetEmpty)
                    [self initiateTimeSync];
            }
            else if (transactionReady != nil)
            {
                if (transactionMessageList.count != 0)
                {
                    if (transactionMessageList.count != 1)
                    {
                        [transactionMessageList sortUsingComparator:^NSComparisonResult(MTPreparedMessage *message1, MTPreparedMessage *message2)
                        {
                            return message1.messageId < message2.messageId ? NSOrderedAscending : NSOrderedDescending;
                        }];
                        
                        if (!forceConfirmations)
                        {
                            NSMutableArray *highPriorityMessages = nil;
                            for (NSInteger i = 0; i < (NSInteger)transactionMessageList.count; i++)
                            {
                                MTPreparedMessage *preparedMessage = transactionMessageList[(NSUInteger)i];
                                if (preparedMessage.hasHighPriority)
                                {
                                    if (highPriorityMessages == nil)
                                        highPriorityMessages = [[NSMutableArray alloc] init];
                                    
                                    [highPriorityMessages addObject:preparedMessage];
                                    [transactionMessageList removeObjectAtIndex:(NSUInteger)i];
                                    i--;
                                }
                            }
                            
                            if (highPriorityMessages != nil)
                            {
                                [highPriorityMessages addObjectsFromArray:transactionMessageList];
                                transactionMessageList = highPriorityMessages;
                            }
                        }
                    }
                    
                    NSMutableArray *transactionPayloadList = [[NSMutableArray alloc] init];
                    NSMutableArray *messageInternalIdsByPayload = [[NSMutableArray alloc] init];
                    NSMutableArray *quickAckIdsByPayload = [[NSMutableArray alloc] init];
                    
                    bool currentlyProcessingHighPriority = false;
                    for (NSUInteger i = 0; i < transactionMessageList.count; )
                    {
                        if (!_useUnauthorizedMode)
                        {
                            NSMutableArray<MTPreparedMessage *> *currentContainerMessages = [[NSMutableArray alloc] init];
                            NSUInteger currentContainerSize = 0;
                            
                            for (NSUInteger j = i; j < transactionMessageList.count; j++, i++)
                            {
                                MTPreparedMessage *preparedMessage = transactionMessageList[j];
                                
                                bool breakContainer = false;
                                
                                if (!forceConfirmations)
                                {
                                    if (preparedMessage.hasHighPriority)
                                        currentlyProcessingHighPriority = true;
                                    else if (currentlyProcessingHighPriority)
                                    {
                                        currentlyProcessingHighPriority = false;
                                        breakContainer = true;
                                    }
                                }
                                
                                if (currentContainerSize + preparedMessage.data.length > MTMaxContainerSize || (breakContainer && currentContainerSize != 0))
                                {
                                    if (currentContainerSize == 0)
                                    {
                                        [currentContainerMessages addObject:preparedMessage];
                                        currentContainerSize += preparedMessage.data.length;
                                        i++;
                                    }
                                    
                                    break;
                                }
                                else
                                {
                                    [currentContainerMessages addObject:preparedMessage];
                                    currentContainerSize += preparedMessage.data.length;
                                }
                            }
                            
                            if (currentContainerMessages.count == 1 && ![transactionSessionInfo wasMessageSentOnce:currentContainerMessages[0].messageId])
                            {
                                [transactionSessionInfo setMessageWasSentOnce:currentContainerMessages[0].messageId];
                                int32_t quickAckId = 0;
                                NSData *messageData = [self _dataForEncryptedMessage:currentContainerMessages[0] authKey:authKey sessionInfo:transactionSessionInfo quickAckId:&quickAckId address:scheme.address extendedPadding:extendedPadding];
                                if (messageData != nil)
                                {
                                    [transactionPayloadList addObject:messageData];
                                    [messageInternalIdsByPayload addObject:@[preparedMessageInternalIdToMessageInternalId[((MTPreparedMessage *)currentContainerMessages[0]).internalId]]];
                                    [quickAckIdsByPayload addObject:@(quickAckId)];
                                }
                            }
                            else if (currentContainerMessages.count != 0)
                            {
                                int32_t quickAckId = 0;
                                NSData *containerData = [self _dataForEncryptedContainerWithMessages:currentContainerMessages authKey:authKey sessionInfo:transactionSessionInfo quickAckId:&quickAckId address:scheme.address extendedPadding:extendedPadding];
                                if (containerData != nil)
                                {
                                    [transactionPayloadList addObject:containerData];
                                    
                                    NSMutableArray *messageInternalIds = [[NSMutableArray alloc] initWithCapacity:currentContainerMessages.count];
                                    for (MTPreparedMessage *preparedMessage in currentContainerMessages)
                                    {
                                        [messageInternalIds addObject:preparedMessageInternalIdToMessageInternalId[preparedMessage.internalId]];
                                    }
                                    [messageInternalIdsByPayload addObject:messageInternalIds];
                                    [quickAckIdsByPayload addObject:@(quickAckId)];
                                }
                            }
                        }
                        else
                        {
                            MTPreparedMessage *preparedMessage = transactionMessageList[i];
                            NSData *messageData = [self _dataForPlainMessage:preparedMessage extendedPadding:extendedPadding];
                            i++;
                            if (messageData != nil)
                            {
                                [transactionPayloadList addObject:messageData];
                                [messageInternalIdsByPayload addObject:@[preparedMessageInternalIdToMessageInternalId[preparedMessage.internalId]]];
                                [quickAckIdsByPayload addObject:@(0)];
                            }
                        }
                    }
                    
                    if (transactionPayloadList.count != 0)
                    {
                        NSMutableArray *transportTransactions = [[NSMutableArray alloc] initWithCapacity:transactionPayloadList.count];
                        
                        for (NSUInteger i = 0; i < transactionPayloadList.count; i++)
                        {
                            [transportTransactions addObject:[[MTTransportTransaction alloc] initWithPayload:transactionPayloadList[i] completion:^(bool success, id transactionId)
                            {
                                [[MTProto managerQueue] dispatchOnQueue:^
                                {
                                    if (success)
                                    {
                                        NSMutableDictionary *messageInternalIdToTransactionId = [[NSMutableDictionary alloc] init];
                                        NSMutableDictionary *messageInternalIdToQuickAckId = [[NSMutableDictionary alloc] init];
                                        NSMutableDictionary *transactionMessageInternalIdToPreparedMessage = [[NSMutableDictionary alloc] init];
                                        for (id messageInternalId in messageInternalIdsByPayload[i])
                                        {
                                            messageInternalIdToTransactionId[messageInternalId] = transactionId;
                                            messageInternalIdToQuickAckId[messageInternalId] = quickAckIdsByPayload[i];
                                            
                                            MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                                            if (preparedMessage != nil)
                                                transactionMessageInternalIdToPreparedMessage[messageInternalId] = preparedMessage;
                                        }
                                        
                                        for (MTMessageTransaction *messageTransaction in messageTransactions)
                                        {
                                            if (messageTransaction.completion)
                                                messageTransaction.completion(messageInternalIdToTransactionId, transactionMessageInternalIdToPreparedMessage, messageInternalIdToQuickAckId);
                                        }
                                    }
                                    else
                                    {
                                        NSMutableString *idsString = [[NSMutableString alloc] init];
                                        for (id messageInternalId in messageInternalIdsByPayload[i])
                                        {
                                            MTOutgoingMessage *outgoingMessage = messageInternalIdToPreparedMessage[messageInternalId];
                                            if (outgoingMessage != nil)
                                            {
                                                if (idsString.length != 0)
                                                    [idsString appendString:@", "];
                                                [idsString appendFormat:@"%" PRId64 "", outgoingMessage.messageId];
                                            }
                                        }
                                        
                                        for (MTMessageTransaction *messageTransaction in messageTransactions)
                                        {
                                            if (messageTransaction.completion) {
                                                messageTransaction.completion(nil, nil, nil);
                                            }
                                        }
                                        
                                        if (MTLogEnabled()) {
                                            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p transport did not accept transactions with messages (%@)]", self, _context, idsString);
                                        }
                                    }
                                }];
                            } needsQuickAck:transactionNeedsQuickAck expectsDataInResponse:transactionExpectsDataInResponse]];
                        }
                        
                        transactionReady(transportTransactions);
                    }
                    else
                    {
                        for (MTMessageTransaction *messageTransaction in messageTransactions)
                        {
                            if (messageTransaction.completion)
                                messageTransaction.completion(nil, nil, nil);
                        }
                        
                        transactionReady(nil);
                    }
                }
                else {
                    for (MTMessageTransaction *messageTransaction in messageTransactions)
                    {
                        if (messageTransaction.completion) {
                            messageTransaction.completion(nil, nil, nil);
                        }
                    }
                    
                    transactionReady(nil);
                }
            } else {
                for (MTMessageTransaction *messageTransaction in messageTransactions)
                {
                    if (messageTransaction.completion) {
                        messageTransaction.completion(nil, nil, nil);
                    }
                }
            }
        }
        else if ([self timeFixOrSaltsMissing] && [self canAskForServiceTransactions] && (_timeFixContext == nil || _timeFixContext.transactionId == nil))
        {
            int64_t timeFixMessageId = [_sessionInfo generateClientMessageId:NULL];
            int32_t timeFixSeqNo = [_sessionInfo takeSeqNo:false];
            
            int64_t randomId = 0;
            arc4random_buf(&randomId, 8);
            
            MTBuffer *pingBuffer = [[MTBuffer alloc] init];
            [pingBuffer appendInt32:(int32_t)0x7abe77ec];
            [pingBuffer appendInt64:randomId];
            
            NSData *messageData = pingBuffer.data;
            
            MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
            
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p sending time fix ping (%" PRId64 "/%" PRId32 ", %" PRId64 ")]", self, _context, timeFixMessageId, timeFixSeqNo, _sessionInfo.sessionId);
            }
            MTShortLog(@"[MTProto#%p@%p sending time fix ping (%" PRId64 "/%" PRId32 ", %" PRId64 ")]", self, _context, timeFixMessageId, timeFixSeqNo, _sessionInfo.sessionId);
            
            [decryptedOs writeInt64:[_validAuthInfo.authInfo authSaltForMessageId:timeFixMessageId]]; // salt
            [decryptedOs writeInt64:_sessionInfo.sessionId];
            [decryptedOs writeInt64:timeFixMessageId];
            [decryptedOs writeInt32:timeFixSeqNo];
            
            [decryptedOs writeInt32:(int32_t)messageData.length];
            [decryptedOs writeData:messageData];
            
            NSData *decryptedData = [self paddedData:[decryptedOs currentBytes] extendedPadding:extendedPadding];
            
            MTDatacenterAuthKey *effectiveAuthKey = authKey;
            
            int xValue = 0;
            NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
            [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
            [msgKeyLargeData appendData:decryptedData];
            
            NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
            NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
            
            NSData *transactionData = nil;
            
            if (encryptionKey != nil)
            {
                NSMutableData *encryptedData = [[NSMutableData alloc] initWithCapacity:14 + decryptedData.length];
                [encryptedData appendData:decryptedData];
                MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);
                
                int64_t authKeyId = effectiveAuthKey.authKeyId;
                [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
                [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];
                
                transactionData = encryptedData;
            }
            
            if (transactionReady != nil)
            {
                if (transactionData != nil)
                {
                    __weak MTProto *weakSelf = self;
                    transactionReady(@[[[MTTransportTransaction alloc] initWithPayload:transactionData completion:^(bool success, id transactionId)
                    {
                        [[MTProto managerQueue] dispatchOnQueue:^
                        {
                            if (success)
                            {
                                if (transactionId != nil)
                                {
                                    _timeFixContext = [[MTTimeFixContext alloc] initWithMessageId:timeFixMessageId messageSeqNo:timeFixSeqNo transactionId:transactionId timeFixAbsoluteStartTime:MTAbsoluteSystemTime()];
                                }
                            }
                            else
                            {
                                __strong MTProto *strongSelf = weakSelf;
                                [strongSelf requestTransportTransaction];
                            }
                        }];
                    } needsQuickAck:false expectsDataInResponse:true]]);
                }
                else
                    transactionReady(nil);
            }
        }
        else if (transactionReady != nil)
            transactionReady(nil);
        
        /*if (debugResetTransport) {
            [self resetTransport];
            [self requestTransportTransaction];
        }*/
    }];
}

- (NSData *)_dataForEncryptedContainerWithMessages:(NSArray *)preparedMessages authKey:(MTDatacenterAuthKey *)authKey sessionInfo:(MTSessionInfo *)sessionInfo quickAckId:(int32_t *)quickAckId address:(MTDatacenterAddress *)address extendedPadding:(bool)extendedPadding {
    MTDatacenterAuthKey *effectiveAuthKey = authKey;
    
    NSMutableArray *containerMessageIds = [[NSMutableArray alloc] init];
    
    MTOutputStream *containerOs = [[MTOutputStream alloc] init];
    
    [containerOs writeInt32:0x73f1f8dc]; // msg_container
    [containerOs writeInt32:(int32_t)preparedMessages.count];
    
    int64_t salt = 0;
    for (MTPreparedMessage *preparedMessage in preparedMessages) {
        salt = preparedMessage.salt;
        
        [containerOs writeInt64:preparedMessage.messageId];
        [containerOs writeInt32:preparedMessage.seqNo];
        [containerOs writeInt32:(int32_t)preparedMessage.data.length];
        [containerOs writeData:preparedMessage.data];
        
        if (preparedMessage.requiresConfirmation)
            [containerMessageIds addObject:@(preparedMessage.messageId)];
    }
    
    NSData *containerData = [containerOs currentBytes];
    
    MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
    
    int64_t containerMessageId = [sessionInfo generateClientMessageId:NULL];
    if (containerMessageIds.count != 0) {
        [sessionInfo addContainerMessageIdMapping:containerMessageId childMessageIds:containerMessageIds];
        
        NSMutableString *idsString = [[NSMutableString alloc] init];
        for (NSNumber *nMessageId in containerMessageIds) {
            if (idsString.length != 0)
                [idsString appendString:@","];
            [idsString appendFormat:@"%lld", [nMessageId longLongValue]];
        }
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"    container (%" PRId64 ") of (%@), in %" PRId64 "", containerMessageId, idsString, sessionInfo.sessionId);
        }
        MTShortLog(@"    container (%" PRId64 ") of (%@), in %" PRId64 "", containerMessageId, idsString, sessionInfo.sessionId);
    }
    
    [decryptedOs writeInt64:salt];
    [decryptedOs writeInt64:sessionInfo.sessionId];
    [decryptedOs writeInt64:containerMessageId];
    [decryptedOs writeInt32:[sessionInfo takeSeqNo:false]];
    
    [decryptedOs writeInt32:(int32_t)containerData.length];
    [decryptedOs writeData:containerData];
    
    NSData *decryptedData = [self paddedData:[decryptedOs currentBytes] extendedPadding:extendedPadding];
    
    int xValue = 0;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
    int32_t nQuickAckId = *((int32_t *)(msgKeyLarge.bytes));
    
    nQuickAckId = nQuickAckId & 0x7fffffff;
    if (quickAckId != NULL)
        *quickAckId = nQuickAckId;
    
    if (encryptionKey != nil)
    {
        NSMutableData *encryptedData = [[NSMutableData alloc] init];
        [encryptedData appendData:decryptedData];
        MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);
        
        int64_t authKeyId = effectiveAuthKey.authKeyId;
        [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
        [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];
        
        return encryptedData;
    }
    
    return nil;
}

- (NSData *)_dataForPlainMessage:(MTPreparedMessage *)preparedMessage extendedPadding:(bool)extendedPadding
{
    MTOutputStream *os = [[MTOutputStream alloc] init];
    
    [os writeInt64:0];
    [os writeInt64:preparedMessage.messageId];
    [os writeInt32:(int32_t)preparedMessage.data.length];
    [os writeData:preparedMessage.data];
    
    uint32_t paddingSize = 0;
    if (extendedPadding) {
        paddingSize = arc4random_uniform((256 - 16) / 4) * 4;
    }
    
    uint8_t padding[256];
    if (paddingSize > 0) {
        arc4random_buf(padding, paddingSize);
        [os write:padding maxLength:paddingSize];
    }
    
    NSData *messageData = [os currentBytes];
    
    return messageData;
}

+ (NSData *)paddedDataV1:(NSData *)data {
    NSMutableData *padded = [[NSMutableData alloc] initWithData:data];
    uint8_t randomBytes[128];
    arc4random_buf(randomBytes, 128);
    for (int i = 0; ((int)data.length + i) % 16 != 0; i++) {
        [padded appendBytes:randomBytes + i length:1];
    }
    return padded;
}

- (NSData *)paddedData:(NSData *)data extendedPadding:(bool)extendedPadding {
    NSMutableData *padded = [[NSMutableData alloc] initWithData:data];
    
    uint8_t randomBytes[256];
    arc4random_buf(randomBytes, 256);

    int take = 0;
    while (take < 12) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
    
    while (padded.length % 16 != 0) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
    
    uint32_t extraPaddingSize = 72;
    if (extendedPadding) {
        extraPaddingSize = 256;
    }
    
    int remainingCount = arc4random_uniform(extraPaddingSize + 1 - take);
    while (remainingCount % 16 != 0) {
        remainingCount--;
    }
    
    for (int i = 0; i < remainingCount; i++) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
    
    assert(padded.length % 16 == 0);

    return padded;
}

+ (NSData *)_manuallyEncryptedMessage:(NSData *)preparedData messageId:(int64_t)messageId authKey:(MTDatacenterAuthKey *)authKey {
    MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
    
    int64_t random1 = 0;
    int64_t random2 = 0;
    arc4random_buf(&random1, 8);
    arc4random_buf(&random2, 8);
    
    [decryptedOs writeInt64:random1];
    [decryptedOs writeInt64:random2];
    [decryptedOs writeInt64:messageId];
    [decryptedOs writeInt32:0];
    
    [decryptedOs writeInt32:(int32_t)preparedData.length];
    [decryptedOs writeData:preparedData];
    
    NSData *decryptedData = [MTProto paddedDataV1:[decryptedOs currentBytes]];
    
    NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + preparedData.length);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
    
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:authKey.authKey messageKey:messageKey toClient:false];
    
    if (encryptionKey != nil)
    {
        NSMutableData *encryptedData = [[NSMutableData alloc] initWithCapacity:14 + decryptedData.length];
        [encryptedData appendData:decryptedData];
        MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);
        
        int64_t authKeyId = authKey.authKeyId;
        [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
        [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];
        
        return encryptedData;
    }
    else
        return nil;
}

- (NSData *)_dataForEncryptedMessage:(MTPreparedMessage *)preparedMessage authKey:(MTDatacenterAuthKey *)authKey sessionInfo:(MTSessionInfo *)sessionInfo quickAckId:(int32_t *)quickAckId address:(MTDatacenterAddress *)address extendedPadding:(bool)extendedPadding
{
    MTDatacenterAuthKey *effectiveAuthKey = authKey;
    NSAssert(effectiveAuthKey != nil, @"effectiveAuthKey == nil");
    
    MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
    
    [decryptedOs writeInt64:preparedMessage.salt];
    [decryptedOs writeInt64:sessionInfo.sessionId];
    [decryptedOs writeInt64:preparedMessage.messageId];
    [decryptedOs writeInt32:preparedMessage.seqNo];
    
    [decryptedOs writeInt32:(int32_t)preparedMessage.data.length];
    [decryptedOs writeData:preparedMessage.data];
    
    NSData *decryptedData = [self paddedData:[decryptedOs currentBytes] extendedPadding:extendedPadding];
    
    int xValue = 0;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
    
    if (encryptionKey != nil)
    {
        NSMutableData *encryptedData = [[NSMutableData alloc] initWithCapacity:14 + decryptedData.length];
        [encryptedData appendData:decryptedData];
        MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);
        
        int64_t authKeyId = effectiveAuthKey.authKeyId;
        [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
        [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];
        
        return encryptedData;
    }
    else
        return nil;
}

- (void)transportTransactionsMayHaveFailed:(MTTransport *)__unused transport transactionIds:(NSArray *)transactionIds
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if ([self isStopped])
            return;
        
        bool requestTransaction = false;
        
        if (_timeFixContext != nil && _timeFixContext.transactionId != nil && [transactionIds containsObject:_timeFixContext.transactionId])
        {
            _timeFixContext = nil;
            requestTransaction = true;
        }
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProto:transactionsMayHaveFailed:)])
                [messageService mtProto:self transactionsMayHaveFailed:transactionIds];
        }
        
        if (requestTransaction && ![self isPaused])
            [self requestTransportTransaction];
    }];
}

- (void)allTransactionsMayHaveFailed
{
    if ([self isStopped])
        return;
    
    bool requestTransaction = false;
    
    if (_timeFixContext != nil && _timeFixContext.transactionId != nil)
    {
        _timeFixContext = nil;
        requestTransaction = true;
    }
    
    for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
    {
        id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
        
        if ([messageService respondsToSelector:@selector(mtProtoAllTransactionsMayHaveFailed:)])
            [messageService mtProtoAllTransactionsMayHaveFailed:self];
    }
    
    if (requestTransaction && ![self isPaused])
        [self requestTransportTransaction];
}

- (void)transportReceivedQuickAck:(MTTransport *)transport quickAckId:(int32_t)quickAckId
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport || [self isStopped])
            return;
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProto:receivedQuickAck:)])
                [messageService mtProto:self receivedQuickAck:quickAckId];
        }
    }];
}

- (void)transportDecodeProgressToken:(MTTransport *)transport scheme:(MTTransportScheme *)scheme data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id progressToken))completion
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport || completion == nil) {
            return;
        }
        
        if (_useUnauthorizedMode) {
            return;
        }
        
        MTDatacenterAuthKey *authKey = [self getAuthKeyForCurrentScheme:scheme createIfNeeded:false authInfoSelector:nil];
        if (authKey == nil) {
            return;
        }
        
        MTDatacenterAuthKey *effectiveAuthKey = authKey;
        
        MTInputStream *is = [[MTInputStream alloc] initWithData:data];
        
        int64_t keyId = [is readInt64];
        
        if (keyId == authKey.authKeyId)
        {
            NSData *messageKey = [is readData:16];

            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:true];
            
            NSMutableData *encryptedMessageData = [is readMutableData:(data.length - 24)];
            while (encryptedMessageData.length % 16 != 0) {
                   [encryptedMessageData setLength:encryptedMessageData.length - 1];
            }
            if (encryptedMessageData.length != 0)
            {
                NSData *decryptedData = MTAesDecrypt(encryptedMessageData, encryptionKey.key, encryptionKey.iv);
                
                MTInputStream *messageIs = [[MTInputStream alloc] initWithData:decryptedData];
                [messageIs readInt64];
                [messageIs readInt64];
                
                [messageIs readInt64];
                [messageIs readInt32];
                [messageIs readInt32];
                
                bool stop = false;
                int64_t reqMsgId = 0;
                
                /*if (true)
                {*/
                    while (!stop && reqMsgId == 0)
                    {
                        int32_t signature = [messageIs readInt32:&stop];
                        [self findReqMsgId:messageIs signature:signature reqMsgId:&reqMsgId failed:&stop];
                    }
                /*}
                else
                {
                    int32_t signature = [messageIs readInt32];
                    if (signature == (int)0xf35c6d01)
                        reqMsgId = [messageIs readInt64];
                    else if (signature == (int)0x73f1f8dc)
                    {
                        int count = [messageIs readInt32];
                        if (count != 0)
                        {
                            [messageIs readInt64];
                            [messageIs readInt32];
                            [messageIs readInt32];
                            
                            signature = [messageIs readInt32];
                            if (signature == (int)0xf35c6d01)
                                reqMsgId = [messageIs readInt64];
                        }
                    }
                }*/
                
                if (reqMsgId != 0)
                    completion(token, @(reqMsgId));
            }
        }
    }];
}

- (void)findReqMsgId:(MTInputStream *)is signature:(int32_t)signature reqMsgId:(int64_t *)reqMsgId failed:(bool *)failed
{
    if (signature == (int)0x73f1f8dc) //msg_container
    {
        int count = [is readInt32:failed];
        if (*failed)
            return;
        
        for (int i = 0; i < count; i++)
        {
            [is readInt64:failed];
            [is readInt32:failed];
            [is readInt32:failed];
            if (*failed)
                return;
            
            int innerSignature = [is readInt32:failed];
            if (*failed)
                return;
            
            [self findReqMsgId:is signature:innerSignature reqMsgId:reqMsgId failed:failed];
            if (*failed || *reqMsgId != 0)
                return;
        }
    }
    else if (signature == (int)0xf35c6d01) //rpc_result
    {
        int64_t value = [is readInt64:failed];
        if (*failed)
            return;
        
        *reqMsgId = value;
    }
    else if (signature == (int)0x62d6b459) // msgs_ack
    {
        [is readInt32:failed];
        if (*failed)
            return;
        
        int count = [is readInt32:failed];
        if (*failed)
            return;
        
        for (int i = 0; i < count; i++)
        {
            [is readInt32:failed];
            if (*failed)
                return;
        }
    }
    else if (signature == (int)0x347773c5) // pong
    {
        [is readInt64:failed];
        [is readInt64:failed];
        if (*failed)
            return;
    }
}

- (void)transportUpdatedDataReceiveProgress:(MTTransport *)transport progressToken:(id)progressToken packetLength:(NSInteger)packetLength progress:(float)progress
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProto:updateReceiveProgressForToken:progress:packetLength:)])
                [messageService mtProto:self updateReceiveProgressForToken:progressToken progress:progress packetLength:packetLength];
        }
    }];
}

- (void)transportTransactionsSucceeded:(NSArray *)transactionIds
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        [_sessionInfo removeScheduledMessageConfirmationsWithTransactionIds:transactionIds];
    }];
}

static NSString *dumpHexString(NSData *data, int maxLength) {
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    if (dataBuffer == NULL)
        return [NSString string];
    
    NSUInteger dataLength = MIN(data.length, 128);
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < (int)dataLength; i++) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    if (dataLength < data.length) {
        [hexString appendString:@"..."];
    }
    
    return hexString;
}

- (void)transportHasIncomingData:(MTTransport *)transport scheme:(MTTransportScheme *)scheme data:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult
{
    /*__block bool simulateError = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        simulateError = true;
    });
    if (simulateError) {
        int32_t protocolErrorCode = -404;
        data = [NSData dataWithBytes:&protocolErrorCode length:4];
    }*/
    
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport || [self isStopped])
            return;
        
        _transport.simultaneousTransactionsEnabled = true;
        
        if (data.length <= 4 + 15) {
            int32_t protocolErrorCode = 0;
            [data getBytes:&protocolErrorCode range:NSMakeRange(0, 4)];
            
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p protocol error %" PRId32 "", self, _context, protocolErrorCode);
            }
            MTShortLog(@"[MTProto#%p@%p protocol error %" PRId32 "", self, _context, protocolErrorCode);
            
            if (decodeResult != nil)
                decodeResult(transactionId, false);
            
            id currentTransport = _transport;
            
            for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
            {
                id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
                
                if ([messageService respondsToSelector:@selector(mtProto:protocolErrorReceived:)])
                    [messageService mtProto:self protocolErrorReceived:protocolErrorCode];
            }
            
            if (protocolErrorCode == -404) {
                [self handleMissingKey:scheme];
            }
            
            if (protocolErrorCode == -429) {
                _isConnectionThrottled = true;
                if (_unthrottleConnectionTimer == nil) {
                    __weak MTProto *weakSelf = self;
                    _unthrottleConnectionTimer = [[MTTimer alloc] initWithTimeout:5.0 repeat:false completion:^{
                        __strong MTProto *strongSelf = weakSelf;
                        if (strongSelf == nil) {
                            return;
                        }
                        
                        strongSelf->_isConnectionThrottled = false;
                        strongSelf->_unthrottleConnectionTimer = nil;
                        [strongSelf requestTransportTransaction];
                    } queue:[MTProto managerQueue].nativeQueue];
                }
            } else {
                if (currentTransport == _transport) {
                    [self requestSecureTransportReset];
                }
                
                [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
            }
            
            return;
        }
        
        NSData *decryptedData = nil;
        
        int64_t embeddedAuthKeyId = 0;
        MTDatacenterAuthInfoSelector authInfoSelector = MTDatacenterAuthInfoSelectorPersistent;
        if (_useUnauthorizedMode) {
            decryptedData = data;
        } else {
            MTDatacenterAuthKey *authKey = [self getAuthKeyForCurrentScheme:scheme createIfNeeded:false authInfoSelector:&authInfoSelector];
            if (authKey != nil) {
                embeddedAuthKeyId = authKey.authKeyId;
                decryptedData = [self _decryptIncomingTransportData:data address:scheme.address authKey:authKey];
            }
        }
        
        if (decryptedData != nil)
        {
            if (decodeResult != nil)
                decodeResult(transactionId, true);
            
            int64_t dataMessageId = 0;
            bool parseError = false;
            NSArray *parsedMessages = [self _parseIncomingMessages:decryptedData dataMessageId:&dataMessageId embeddedAuthKeyId:embeddedAuthKeyId parseError:&parseError];
            
            for (MTIncomingMessage *message in parsedMessages) {
                if ([message.body isKindOfClass:[MTRpcResultMessage class]]) {
                    MTRpcResultMessage *rpcResultMessage = message.body;
                    id maybeInternalMessage = [MTInternalMessageParser parseMessage:rpcResultMessage.data];
                    if ([maybeInternalMessage isKindOfClass:[MTRpcError class]]) {
                        MTRpcError *rpcError = maybeInternalMessage;
                        if (rpcError.errorCode == 401 && [rpcError.errorDescription isEqualToString:@"AUTH_KEY_PERM_EMPTY"]) {
                            if (MTLogEnabled()) {
                                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p received AUTH_KEY_PERM_EMPTY]", self, _context);
                            }
                            MTShortLog(@"[MTProto#%p@%p received AUTH_KEY_PERM_EMPTY]", self, _context);
                            [self handleMissingKey:scheme];
                            [self requestSecureTransportReset];

                            return;
                        }
                    }
                }
            }
            if (parseError) {
                if (MTLogEnabled()) {
                    MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p incoming data parse error, header: %d:%@]", self, _context, (int)decryptedData.length, dumpHexString(decryptedData, 128));
                }
                MTShortLog(@"[MTProto#%p@%p incoming data parse error, header: %d:%@]", self, _context, (int)decryptedData.length, dumpHexString(decryptedData, 128));
                
                [_context reportTransportSchemeFailureForDatacenterId:_datacenterId transportScheme:scheme];
                [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
                
                [self resetSessionInfo];
            } else {
                [_context reportTransportSchemeSuccessForDatacenterId:_datacenterId transportScheme:scheme];
                [self transportTransactionsSucceeded:@[transactionId]];
                
                for (MTIncomingMessage *incomingMessage in parsedMessages)
                {
                    [self _processIncomingMessage:incomingMessage totalSize:(int)data.length withTransactionId:transactionId address:scheme.address authInfoSelector:authInfoSelector];
                }
                
                if (requestTransactionAfterProcessing)
                    [self requestTransportTransaction];
            }
        } else {
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p couldn't decrypt incoming data]", self, _context);
            }
            MTShortLog(@"[MTProto#%p@%p couldn't decrypt incoming data]", self, _context);
            
            if (decodeResult != nil)
                decodeResult(transactionId, false);
            
            [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
            [_context reportTransportSchemeFailureForDatacenterId:_datacenterId transportScheme:scheme];
            
            [self requestSecureTransportReset];
        }
    }];
}
                                  
- (void)handleMissingKey:(MTTransportScheme *)scheme {
    NSAssert([[MTProto managerQueue] isCurrentQueue], @"invalid queue");
    
    if (_useUnauthorizedMode) {
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p don't handleMissingKey when useUnauthorizedMode]", self, _context);
        }
        return;
    }
    
    MTDatacenterAuthInfoSelector authInfoSelector;
    [self getAuthKeyForCurrentScheme:scheme createIfNeeded:false authInfoSelector:&authInfoSelector];
    
    if (MTLogEnabled()) {
        MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p missing key %lld selector %d useExplicitAuthKey: %lld, canResetAuthData: %s]", self, _context, _validAuthInfo.authInfo.authKeyId, authInfoSelector, _useExplicitAuthKey.authKeyId, _canResetAuthData ? "true" : "false");
    }
    
    if (_useExplicitAuthKey != nil) {
    } else if (_cdn) {
        _validAuthInfo = nil;
        
        [_context performBatchUpdates:^{
            [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil selector:authInfoSelector];
            [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:true selector:authInfoSelector  allowUnboundEphemeralKeys:_allowUnboundEphemeralKeys];
        }];
        _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
        _awaitingAuthInfoForSelector = @(authInfoSelector);
    } else {
        MTDatacenterAuthInfoSelector authInfoSelector;
        [self getAuthKeyForCurrentScheme:scheme createIfNeeded:false authInfoSelector:&authInfoSelector];
        
        if (_requiredAuthToken != nil && _authTokenMasterDatacenterId != _datacenterId) {
            _validAuthInfo = nil;
            
            [_context removeTokenForDatacenterWithId:_datacenterId];
            [_context performBatchUpdates:^{
                [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil selector:authInfoSelector];
                [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:false selector:authInfoSelector  allowUnboundEphemeralKeys:_allowUnboundEphemeralKeys];
            }];
            _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
            _awaitingAuthInfoForSelector = @(authInfoSelector);
        } else if (_canResetAuthData) {
            _validAuthInfo = nil;
            
            [_context performBatchUpdates:^{
                [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil selector:authInfoSelector];
                [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:false selector:authInfoSelector  allowUnboundEphemeralKeys:_allowUnboundEphemeralKeys];
            }];
            _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
            _awaitingAuthInfoForSelector = @(authInfoSelector);
        } else {
            switch (authInfoSelector) {
                case MTDatacenterAuthInfoSelectorEphemeralMain:
                case MTDatacenterAuthInfoSelectorEphemeralMedia: {
                    _validAuthInfo = nil;
                    
                    [_context performBatchUpdates:^{
                        [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil selector:authInfoSelector];
                        [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:false selector:authInfoSelector  allowUnboundEphemeralKeys:_allowUnboundEphemeralKeys];
                    }];
                    _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
                    _awaitingAuthInfoForSelector = @(authInfoSelector);
                    break;
                }
                default:
                    [_context checkIfLoggedOut:_datacenterId];
                    break;
            }
        }
    }
}

static bool isDataEqualToDataConstTime(NSData *data1, NSData *data2) {
    if (data1.length != data2.length) {
        return false;
    }
    uint8_t const *bytes1 = data1.bytes;
    uint8_t const *bytes2 = data2.bytes;
    int result = 0;
    for (int i = 0; i < data1.length; i++) {
        result |= bytes1[i] != bytes2[i];
    }
    return result == 0;
}

- (NSData *)_decryptIncomingTransportData:(NSData *)transportData address:(MTDatacenterAddress *)address authKey:(MTDatacenterAuthKey *)authKey
{
    MTDatacenterAuthKey *effectiveAuthKey = authKey;
    
    if (effectiveAuthKey == nil)
        return nil;
    
    if (transportData.length < 24 + 36)
        return nil;
    
    int64_t authKeyId = 0;
    [transportData getBytes:&authKeyId range:NSMakeRange(0, 8)];
    if (authKeyId != effectiveAuthKey.authKeyId)
        return nil;
    
    NSData *embeddedMessageKey = [transportData subdataWithRange:NSMakeRange(8, 16)];
    
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:embeddedMessageKey toClient:true];
    
    if (encryptionKey == nil)
        return nil;
    
    NSData *dataToDecrypt = [transportData subdataWithRange:NSMakeRange(24, ((int32_t)(transportData.length - 24)) & (~15))];
    
    NSData *decryptedData = MTAesDecrypt(dataToDecrypt, encryptionKey.key, encryptionKey.iv);
    
    int xValue = 8;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    
    if (!isDataEqualToDataConstTime(messageKey, embeddedMessageKey)) {
        return nil;
    }

    int32_t messageDataLength = 0;
    [decryptedData getBytes:&messageDataLength range:NSMakeRange(28, 4)];

    int32_t paddingLength = ((int32_t)decryptedData.length) - messageDataLength;
    if (paddingLength < 12 || paddingLength > 1024) {
        return nil;
    }

    if (messageDataLength < 0 || messageDataLength > (int32_t)decryptedData.length) {
        return nil;
    }
    
    return decryptedData;
}

- (id)parseMessage:(NSData *)data
{
    NSData *unwrappedData = [MTInternalMessageParser unwrapMessage:data];
    id internalMessage = [MTInternalMessageParser parseMessage:unwrappedData];
    if (internalMessage != nil)
        return internalMessage;
    
    return [_context.serialization parseMessage:unwrappedData];
}

- (NSArray *)_parseIncomingMessages:(NSData *)data dataMessageId:(out int64_t *)dataMessageId embeddedAuthKeyId:(int64_t)embeddedAuthKeyId parseError:(out bool *)parseError
{
    MTInputStream *is = [[MTInputStream alloc] initWithData:data];
    
    bool readError = false;
    
    int64_t embeddedSessionId = 0;
    int64_t embeddedMessageId = 0;
    int32_t embeddedSeqNo = 0;
    int64_t embeddedSalt = 0;
    int32_t topMessageSize = 0;
    
    if (_useUnauthorizedMode)
    {
        int64_t authKeyId = [is readInt64];
        if (authKeyId != 0)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        embeddedMessageId = [is readInt64:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        topMessageSize = [is readInt32:&readError];
        if (readError || topMessageSize < 4)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        if (dataMessageId != 0)
            *dataMessageId = embeddedMessageId;
    }
    else
    {
        embeddedSalt = [is readInt64:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        embeddedSessionId = [is readInt64:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        if (embeddedSessionId != _sessionInfo.sessionId)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        embeddedMessageId = [is readInt64:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        embeddedSeqNo = [is readInt32:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        [is readInt32:&readError];
        if (readError)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
    }
    
    NSMutableData *topMessageData = [[NSMutableData alloc] init];
    uint8_t buffer[128];
    while (true)
    {
        NSInteger readBytes = [[is wrappedInputStream] read:buffer maxLength:128];
        if (readBytes <= 0)
            break;
        [topMessageData appendBytes:buffer length:readBytes];
    }
    
    id topObject = [self parseMessage:topMessageData];
    if (topObject == nil)
    {
        if (parseError != NULL)
            *parseError = true;
        return nil;
    }
    
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    NSTimeInterval timestamp = embeddedMessageId / 4294967296.0;
    
    if ([topObject isKindOfClass:[MTMsgContainerMessage class]])
    {
        for (MTMessage *subMessage in ((MTMsgContainerMessage *)topObject).messages)
        {
            id subObject = [self parseMessage:subMessage.data];
            if (subObject == nil)
            {
                if (parseError != NULL)
                    *parseError = true;
                return nil;
            }
            
            int64_t subMessageId = subMessage.messageId;
            int32_t subMessageSeqNo = subMessage.seqNo;
            int32_t subMessageLength = (int32_t)subMessage.data.length;
            [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:subMessageId seqNo:subMessageSeqNo authKeyId:embeddedAuthKeyId sessionId:embeddedSessionId salt:embeddedSalt timestamp:timestamp size:subMessageLength body:subObject]];
        }
    }
    else if ([topObject isKindOfClass:[MTMessage class]])
    {
        MTMessage *message = topObject;
        id subObject = [self parseMessage:message.data];
        if (subObject == nil)
        {
            if (parseError != NULL)
                *parseError = true;
            return nil;
        }
        
        int64_t subMessageId = message.messageId;
        int32_t subMessageSeqNo = message.seqNo;
        int32_t subMessageLength = (int32_t)message.data.length;
        [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:subMessageId seqNo:subMessageSeqNo authKeyId:embeddedAuthKeyId sessionId:embeddedSessionId salt:embeddedSalt timestamp:timestamp size:subMessageLength body:subObject]];
    }
    else
        [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:embeddedMessageId seqNo:embeddedSeqNo authKeyId:embeddedAuthKeyId sessionId:embeddedSessionId salt:embeddedSalt timestamp:timestamp size:topMessageSize body:topObject]];
    
    return messages;
}

- (void)_processIncomingMessage:(MTIncomingMessage *)incomingMessage totalSize:(int)totalSize withTransactionId:(id)transactionId address:(MTDatacenterAddress *)address authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    if ([_sessionInfo messageProcessed:incomingMessage.messageId])
    {
        if (MTLogEnabled()) {
            MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p received duplicate message %" PRId64 "]", self, _context, incomingMessage.messageId);
        }
        MTShortLog(@"[MTProto#%p@%p received duplicate message %" PRId64 "]", self, _context, incomingMessage.messageId);
        [_sessionInfo scheduleMessageConfirmation:incomingMessage.messageId size:incomingMessage.size];
        
        if ([_sessionInfo scheduledMessageConfirmationsExceedSize:MTMaxUnacknowledgedMessageSize orCount:MTMaxUnacknowledgedMessageCount])
            [self requestTransportTransaction];
        
        return;
    }
    
    if (MTLogEnabled()) {
        MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p [%d] received %@]", self, _context, totalSize, [self incomingMessageDescription:incomingMessage]);
    }
    
    [_sessionInfo setMessageProcessed:incomingMessage.messageId];
    if (!_useUnauthorizedMode && incomingMessage.seqNo % 2 != 0)
    {
        [_sessionInfo scheduleMessageConfirmation:incomingMessage.messageId size:incomingMessage.size];
        
        if ([_sessionInfo scheduledMessageConfirmationsExceedSize:MTMaxUnacknowledgedMessageSize orCount:MTMaxUnacknowledgedMessageCount])
            [self requestTransportTransaction];
    }
    
    if (!_useUnauthorizedMode && [incomingMessage.body isKindOfClass:[MTBadMsgNotificationMessage class]])
    {
        MTBadMsgNotificationMessage *badMsgNotification = incomingMessage.body;
        
        int64_t badMessageId = badMsgNotification.badMessageId;
        
        NSArray *containerMessageIds = [_sessionInfo messageIdsInContainer:badMessageId];
        
        if ([badMsgNotification isKindOfClass:[MTBadServerSaltNotificationMessage class]])
        {
            if (_timeFixContext != nil && badMessageId == _timeFixContext.messageId)
            {
                _timeFixContext = nil;
                
                int64_t validSalt = ((MTBadServerSaltNotificationMessage *)badMsgNotification).nextServerSalt;
                NSTimeInterval timeDifference = incomingMessage.messageId / 4294967296.0 - [[NSDate date] timeIntervalSince1970];
                [self completeTimeSync];
                [self timeSyncInfoChanged:timeDifference saltList:@[[[MTDatacenterSaltInfo alloc] initWithSalt:validSalt firstValidMessageId:incomingMessage.messageId lastValidMessageId:incomingMessage.messageId + (4294967296 * 30 * 60)]] authInfoSelector:authInfoSelector];
            }
            else
                [self initiateTimeSync];
        }
        else
        {
            switch (badMsgNotification.errorCode)
            {
                case 16:
                case 17:
                {
                    if (_timeFixContext != nil && badMessageId == _timeFixContext.messageId)
                    {
                        _timeFixContext = nil;
                        
                        NSTimeInterval timeDifference = incomingMessage.messageId / 4294967296.0 - [[NSDate date] timeIntervalSince1970];
                        [self completeTimeSync];
                        [self timeSyncInfoChanged:timeDifference saltList:nil authInfoSelector:authInfoSelector];
                    }
                    else
                        [self initiateTimeSync];
                    
                    break;
                }
                case 32:
                case 33:
                {
                    [self resetSessionInfo];
                    [self initiateTimeSync];
                    
                    break;
                }
                case 48:
                {
                    [self initiateTimeSync];
                    
                    break;
                }
                default:
                    break;
            }
        }
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProto:messageDeliveryFailed:)])
            {
                [messageService mtProto:self messageDeliveryFailed:badMessageId];
                
                if (containerMessageIds != nil)
                {
                    for (NSNumber *nMessageId in containerMessageIds)
                        [messageService mtProto:self messageDeliveryFailed:(int64_t)[nMessageId longLongValue]];
                }
            }
        }
        
        if ([self canAskForTransactions] || [self canAskForServiceTransactions])
            [self requestTransportTransaction];
    }
    else if ([incomingMessage.body isKindOfClass:[MTMsgsAckMessage class]])
    {
        NSArray *messageIds = ((MTMsgsAckMessage *)incomingMessage.body).messageIds;
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProto:messageDeliveryConfirmed:)])
                [messageService mtProto:self messageDeliveryConfirmed:messageIds];
        }
    }
    else if ([incomingMessage.body isKindOfClass:[MTMsgDetailedInfoMessage class]])
    {
        MTMsgDetailedInfoMessage *detailedInfoMessage = incomingMessage.body;
        
        bool shouldRequest = false;
        
        if ([detailedInfoMessage isKindOfClass:[MTMsgDetailedResponseInfoMessage class]])
        {
            int64_t requestMessageId = ((MTMsgDetailedResponseInfoMessage *)detailedInfoMessage).requestMessageId;
            
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p detailed info %" PRId64 " is for %" PRId64 "", self, _context, incomingMessage.messageId, requestMessageId);
            }
            MTShortLog(@"[MTProto#%p@%p detailed info %" PRId64 " is for %" PRId64 "", self, _context, incomingMessage.messageId, requestMessageId);
            
            for (id<MTMessageService> messageService in _messageServices)
            {
                if ([messageService respondsToSelector:@selector(mtProto:shouldRequestMessageWithId:inResponseToMessageId:currentTransactionId:)])
                {
                    if ([messageService mtProto:self shouldRequestMessageWithId:detailedInfoMessage.responseMessageId inResponseToMessageId:requestMessageId currentTransactionId:transactionId])
                    {
                        shouldRequest = true;
                        break;
                    }
                }
            }
        }
        else
            shouldRequest = true;
        
        if (shouldRequest)
        {
            [self requestMessageWithId:detailedInfoMessage.responseMessageId];
            if (MTLogEnabled()) {
                MTLogWithPrefix(_getLogPrefix, @"[MTProto#%p@%p will request message %" PRId64 "", self, _context, detailedInfoMessage.responseMessageId);
            }
            MTShortLog(@"[MTProto#%p@%p will request message %" PRId64 "", self, _context, detailedInfoMessage.responseMessageId);
        }
        else
        {
            [_sessionInfo scheduleMessageConfirmation:detailedInfoMessage.responseMessageId size:(NSInteger)detailedInfoMessage.responseLength];
            [self requestTransportTransaction];
        }
    }
    else if ([incomingMessage.body isKindOfClass:[MTNewSessionCreatedMessage class]])
    {
        int64_t firstValidMessageId = ((MTNewSessionCreatedMessage *)incomingMessage.body).firstMessageId;
        
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProtoServerDidChangeSession:firstValidMessageId:otherValidMessageIds:)])
                [messageService mtProtoServerDidChangeSession:self firstValidMessageId:firstValidMessageId otherValidMessageIds:[_sessionInfo messageIdsInContainersAfterMessageId:firstValidMessageId]];
        }
    }
    else
    {
        for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
        {
            id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
            
            if ([messageService respondsToSelector:@selector(mtProto:receivedMessage:authInfoSelector:)])
                [messageService mtProto:self receivedMessage:incomingMessage authInfoSelector:authInfoSelector];
        }
        
        if (_timeFixContext != nil && [incomingMessage.body isKindOfClass:[MTPongMessage class]] && ((MTPongMessage *)incomingMessage.body).messageId == _timeFixContext.messageId)
        {
            _timeFixContext = nil;
            [self completeTimeSync];
            
            if ([self canAskForTransactions] || [self canAskForServiceTransactions])
                [self requestTransportTransaction];
        }
    }
}

- (void)contextDatacenterTransportSchemesUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId shouldReset:(bool)shouldReset {
    [[MTProto managerQueue] dispatchOnQueue:^ {
        if (context == _context && datacenterId == _datacenterId && ![self isStopped]) {
            bool resolvedShouldReset = shouldReset;
            
            if (_mtState & MTProtoStateAwaitingDatacenterScheme) {
                [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterScheme)];
                resolvedShouldReset = true;
            }
            
            if ((_mtState & MTProtoStateAwaitingDatacenterAuthorization) == 0 && (_mtState & MTProtoStatePaused) == 0) {
                if (resolvedShouldReset) {
                    [self resetTransport];
                    [self requestTransportTransaction];
                }
            }
        }
    }];
}

- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo selector:(MTDatacenterAuthInfoSelector)selector
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (!_useUnauthorizedMode && context == _context && datacenterId == _datacenterId)
        {
            if (_awaitingAuthInfoForSelector != nil) {
                if ([_awaitingAuthInfoForSelector intValue] != selector) {
                    return;
                } else if (authInfo != nil) {
                    _awaitingAuthInfoForSelector = nil;
                }
            } else if (_validAuthInfo != nil) {
                if (_validAuthInfo.selector != selector) {
                    return;
                }
            } else {
                return;
            }
            
            if (authInfo == nil) {
                _validAuthInfo = nil;
                _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
                _awaitingAuthInfoForSelector = @(selector);
            }
            
            bool wasSuspended = _mtState & (MTProtoStateAwaitingDatacenterAuthorization);
            
            if (authInfo != nil) {
                if (_mtState & MTProtoStateAwaitingDatacenterAuthorization) {
                    [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterAuthorization)];
                }

                if ((_mtState & (MTProtoStateAwaitingDatacenterAuthorization)) == 0) {
                    if (wasSuspended) {
                        [self resetTransport];
                        [self requestTransportTransaction];
                    }
                }
            } else {
                [self resetTransport];
            }
        }
    }];
}

- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (!_useUnauthorizedMode && context == _context && datacenterId == _datacenterId && _requiredAuthToken != nil && [_requiredAuthToken isEqual:authToken])
        {
            if (_mtState & MTProtoStateAwaitingDatacenterAuthToken)
            {
                [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterAuthToken)];
                
                [self resetTransport];
                [self requestTransportTransaction];
            }
            
            for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
            {
                id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
                
                if ([messageService respondsToSelector:@selector(mtProtoAuthTokenUpdated:)])
                    [messageService mtProtoAuthTokenUpdated:self];
            }
        }
    }];
}

- (void)timeSyncServiceCompleted:(MTTimeSyncMessageService *)timeSyncService timeDifference:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    if ([_messageServices containsObject:timeSyncService])
    {
        [self completeTimeSync];
        [_messageServices removeObject:timeSyncService];
        
        [self timeSyncInfoChanged:timeDifference saltList:saltList authInfoSelector:authInfoSelector];
    }
}

- (void)timeSyncInfoChanged:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    [_context setGlobalTimeDifference:timeDifference];
    
    if (!_useUnauthorizedMode && saltList != nil)
    {
        if (_useExplicitAuthKey) {
            if (_validAuthInfo != nil && _validAuthInfo.selector == authInfoSelector) {
                MTDatacenterAuthInfo *updatedAuthInfo = [_validAuthInfo.authInfo mergeSaltSet:saltList forTimestamp:[_context globalTime]];
                _validAuthInfo = [[MTProtoValidAuthInfo alloc] initWithAuthInfo:updatedAuthInfo selector:authInfoSelector];
            }
        } else {
            MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_datacenterId selector:authInfoSelector];
            if (authInfo != nil)
            {
                MTDatacenterAuthInfo *updatedAuthInfo = [authInfo mergeSaltSet:saltList forTimestamp:[_context globalTime]];
                [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:updatedAuthInfo selector:authInfoSelector];
                if (_validAuthInfo != nil && _validAuthInfo.selector == authInfoSelector) {
                    _validAuthInfo = [[MTProtoValidAuthInfo alloc] initWithAuthInfo:updatedAuthInfo selector:authInfoSelector];
                }
            }
        }
    }
    
    if ([self canAskForTransactions] || [self canAskForServiceTransactions])
        [self requestTransportTransaction];
}

- (void)_messageResendRequestFailed:(int64_t)messageId
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        for (id<MTMessageService> service in _messageServices)
        {
            if ([service respondsToSelector:@selector(mtProto:messageResendRequestFailed:)])
            {
                [service mtProto:self messageResendRequestFailed:messageId];
            }
        }
    }];
}
    
- (void)contextDatacenterPublicKeysUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys {
    [[MTProto managerQueue] dispatchOnQueue:^{
        for (id<MTMessageService> service in _messageServices) {
            if ([service respondsToSelector:@selector(mtProtoPublicKeysUpdated:datacenterId:publicKeys:)]) {
                [service mtProtoPublicKeysUpdated:self datacenterId:datacenterId publicKeys:publicKeys];
            }
        }
    }];
}
    
- (void)contextApiEnvironmentUpdated:(MTContext *)context apiEnvironment:(MTApiEnvironment *)apiEnvironment {
    [[MTProto managerQueue] dispatchOnQueue:^{
        NSString *previousLangPackCode = _apiEnvironment.langPackCode;
        MTSocksProxySettings *previousSocksProxySettings = _apiEnvironment.socksProxySettings;
        
        _apiEnvironment = apiEnvironment;
        
        bool resetConnection = false;
        
        if ((_apiEnvironment.socksProxySettings != nil) != (previousSocksProxySettings != nil) || (previousSocksProxySettings != nil && ![_apiEnvironment.socksProxySettings isEqual:previousSocksProxySettings])) {
            resetConnection = true;
        }
        
        if (![_apiEnvironment.langPackCode isEqualToString:previousLangPackCode]) {
            resetConnection = true;
        }
        
        for (id<MTMessageService> service in _messageServices) {
            if ([service respondsToSelector:@selector(mtProtoApiEnvironmentUpdated:apiEnvironment:)]) {
                [service mtProtoApiEnvironmentUpdated:self apiEnvironment:apiEnvironment];
            }
        }
        
        if (resetConnection) {
            [self resetTransport];
            [self requestTransportTransaction];
        }
    }];
}

@end
