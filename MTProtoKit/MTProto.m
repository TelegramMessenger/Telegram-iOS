/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTProto.h"

#import <inttypes.h>

#import "MTLogging.h"
#import "MTQueue.h"
#import "MTOutputStream.h"
#import "MTInputStream.h"

#import "MTContext.h"

#import "MTDatacenterAddressSet.h"
#import "MTTransportScheme.h"
#import "MTDatacenterAuthInfo.h"
#import "MTSessionInfo.h"
#import "MTDatacenterSaltInfo.h"
#import "MTTimeFixContext.h"
#import "MTBindingTempAuthKeyContext.h"

#import "MTMessageService.h"
#import "MTMessageTransaction.h"
#import "MTTimeSyncMessageService.h"
#import "MTResendMessageService.h"

#import "MTIncomingMessage.h"
#import "MTOutgoingMessage.h"
#import "MTPreparedMessage.h"
#import "MTMessageEncryptionKey.h"

#import "MTTransport.h"
#import "MTTransportTransaction.h"

#import "MTTcpTransport.h"
#import "MTHttpTransport.h"

#import "MTSerialization.h"
#import "MTEncryption.h"

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
#import "MTRpcError.h"

#import "MTApiEnvironment.h"

#import "MTTime.h"

#define MTProtoV2 1

typedef enum {
    MTProtoStateAwaitingDatacenterScheme = 1,
    MTProtoStateAwaitingDatacenterAuthorization = 2,
    MTProtoStateAwaitingDatacenterTempAuthKey = 4,
    MTProtoStateAwaitingDatacenterAuthToken = 8,
    MTProtoStateAwaitingTimeFixAndSalts = 16,
    MTProtoStateAwaitingLostMessages = 32,
    MTProtoStateStopped = 64,
    MTProtoStatePaused = 128,
    MTProtoStateBindingTempAuthKey = 256
} MTProtoState;

static const NSUInteger MTMaxContainerSize = 3 * 1024;
static const NSUInteger MTMaxUnacknowledgedMessageSize = 1 * 1024 * 1024;
static const NSUInteger MTMaxUnacknowledgedMessageCount = 64;

@implementation MTProtoConnectionState

- (instancetype)initWithIsConnected:(bool)isConnected isUsingProxy:(bool)isUsingProxy {
    self = [super init];
    if (self != nil) {
        _isConnected = isConnected;
        _isUsingProxy = isUsingProxy;
    }
    return self;
}

@end

@interface MTProto () <MTContextChangeListener, MTTransportDelegate, MTTimeSyncMessageServiceDelegate, MTResendMessageServiceDelegate>
{
    NSMutableArray *_messageServices;
    
    MTDatacenterAuthInfo *_authInfo;
    MTSessionInfo *_sessionInfo;
    MTTimeFixContext *_timeFixContext;
    
    MTDatacenterAuthKey *_bindPersistentKey;
    void (^_bindPersistentKeyCompletion)();
    MTBindingTempAuthKeyContext *_bindingTempAuthKeyContext;
    
    MTTransportScheme *_transportScheme;
    MTTransport *_transport;
    
    int _mtState;
    
    bool _willRequestTransactionOnNextQueuePass;
    
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
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

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo
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
        
        [_context addChangeListener:self];
        
        _messageServices = [[NSMutableArray alloc] init];
        
        _sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:_context];
        _authInfo = [_context authInfoForDatacenterWithId:_datacenterId];
        
        _shouldStayConnected = true;
    }
    return self;
}

- (void)dealloc
{
    MTTransport *transport = _transport;
    _transport.delegate = nil;
    _transport = nil;
    
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        [transport stop];
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
                MTLog(@"[MTProto#%p pause]", self);
            }
            
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
                MTLog(@"[MTProto#%p resume]", self);
            }
            
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
            if ([delegate respondsToSelector:@selector(mtProtoConnectionStateChanged:isConnected:)])
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
            MTLog(@"[MTProto#%p changing transport %@#%p to %@#%p]", self, [_transport class] == nil ? @"" : NSStringFromClass([_transport class]), _transport, [transport class] == nil ? @"" : NSStringFromClass([transport class]), transport);
        }
        
        [self allTransactionsMayHaveFailed];
        
        MTTransport *previousTransport = _transport;
        [_transport activeTransactionIds:^(NSArray *transactionIds)
        {
            [self transportTransactionsMayHaveFailed:previousTransport transactionIds:transactionIds];
        }];
        
        _timeFixContext = nil;
        _bindingTempAuthKeyContext = nil;
        
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
        
        _transportScheme = [_context transportSchemeForDatacenterWithId:_datacenterId media:_media isProxy:_apiEnvironment.socksProxySettings != nil];
        
        if (_transportScheme == nil)
        {
            if ((_mtState & MTProtoStateAwaitingDatacenterScheme) == 0)
            {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterScheme];
                
                [_context transportSchemeForDatacenterWithIdRequired:_datacenterId media:_media];
            }
        }
        else if (!_useUnauthorizedMode && [_context authInfoForDatacenterWithId:_datacenterId] == nil)
        {
            if ((_mtState & MTProtoStateAwaitingDatacenterAuthorization) == 0)
            {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterAuthorization];
                
                [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:_cdn];
            }
        }
        else if (!_useUnauthorizedMode && _useTempAuthKeys && [_context authInfoForDatacenterWithId:_datacenterId].tempAuthKey == nil) {
            if ((_mtState & MTProtoStateAwaitingDatacenterTempAuthKey) == 0)
            {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterTempAuthKey];
                
                [_context tempAuthKeyForDatacenterWithIdRequired:_datacenterId];
            }
        }
        else if (_requiredAuthToken != nil && !_useUnauthorizedMode && ![_requiredAuthToken isEqual:[_context authTokenForDatacenterWithId:_datacenterId]])
        {
            if ((_mtState & MTProtoStateAwaitingDatacenterAuthToken) == 0)
            {
                [self setMtState:_mtState | MTProtoStateAwaitingDatacenterAuthToken];
                
                [_context authTokenForDatacenterWithIdRequired:_datacenterId authToken:_requiredAuthToken masterDatacenterId:_authTokenMasterDatacenterId];
            }
        }
        else
        {
            MTTransport *transport = nil;
            
            transport = [_transportScheme createTransportWithContext:_context datacenterId:_datacenterId delegate:self usageCalculationInfo:_usageCalculationInfo];
            
            [self setTransport:transport];
        }
    }];
}

- (void)resetSessionInfo
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (MTLogEnabled()) {
            MTLog(@"[MTProto#%p resetting session]", self);
        }
        
        _sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:_context];
        _timeFixContext = nil;
        _bindingTempAuthKeyContext = nil;
        
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
                MTLog(@"[MTProto#%p begin time sync]", self);
            }
            
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
            MTLog(@"[MTProto#%p service tasks state: %d, resend: %s]", self, _mtState, haveResendMessagesPending ? "yes" : "no");
        }
        
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
                MTLog(@"[MTProto#%p service tasks state: %d, resend: %s]", self, _mtState, true ? "yes" : "no");
            }
            
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
                        MTLog(@"[MTProto#%p service tasks state: %d, resend: %s]", self, _mtState, false ? "yes" : "no");
                    }
                    
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
                
                if ([self isStopped] || [self isPaused])
                    return;
                
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
    return (_mtState & (MTProtoStateAwaitingDatacenterScheme | MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterTempAuthKey | MTProtoStateAwaitingDatacenterAuthToken | MTProtoStateAwaitingTimeFixAndSalts | MTProtoStateBindingTempAuthKey | MTProtoStateStopped)) == 0;
}

- (bool)canAskForServiceTransactions
{
    return (_mtState & (MTProtoStateAwaitingDatacenterScheme | MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterTempAuthKey | MTProtoStateAwaitingDatacenterAuthToken | MTProtoStateStopped)) == 0;
}

- (bool)timeFixOrSaltsMissing
{
    return _mtState & MTProtoStateAwaitingTimeFixAndSalts;
}

- (bool)bindingTempAuthKey
{
    return _mtState & MTProtoStateBindingTempAuthKey;
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
            MTLog(@"[MTProto#%p network state: %s]", self, isNetworkAvailable ? "available" : "waiting");
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

- (void)transportConnectionStateChanged:(MTTransport *)transport isConnected:(bool)isConnected isUsingProxy:(bool)isUsingProxy
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        if (MTLogEnabled()) {
            MTLog(@"[MTProto#%p connection state: %s]", self, isConnected ? "connected" : "connecting");
        }
        
        for (id<MTMessageService> messageService in _messageServices)
        {
            if ([messageService respondsToSelector:@selector(mtProtoConnectionStateChanged:isConnected:)])
                [messageService mtProtoConnectionStateChanged:self isConnected:isConnected];
        }
        
        id<MTProtoDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(mtProtoConnectionStateChanged:state:)])
            [delegate mtProtoConnectionStateChanged:self state:[[MTProtoConnectionState alloc] initWithIsConnected:isConnected isUsingProxy:isUsingProxy]];
    }];
}

- (void)transportConnectionContextUpdateStateChanged:(MTTransport *)transport isUpdatingConnectionContext:(bool)isUpdatingConnectionContext
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport)
            return;
        
        if (MTLogEnabled()) {
            MTLog(@"[MTProto#%p connection context update state: %s]", self, isUpdatingConnectionContext ? "updating" : "up to date");
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

- (void)transportConnectionProblemsStatusChanged:(MTTransport *)transport hasConnectionProblems:(bool)hasConnectionProblems isProbablyHttp:(bool)isProbablyHttp
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport || _transportScheme == nil)
            return;
        
        if (hasConnectionProblems)
        {
            [_context invalidateTransportSchemeForDatacenterId:_datacenterId transportScheme:_transportScheme isProbablyHttp:isProbablyHttp media:_media];
        }
        else
        {
            [_context revalidateTransportSchemeForDatacenterId:_datacenterId transportScheme:_transportScheme media:_media];
        }
    }];
}

- (NSString *)outgoingMessageDescription:(MTOutgoingMessage *)message messageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo
{
    return [[NSString alloc] initWithFormat:@"%@ (%" PRId64 "/%" PRId32 ")", message.metadata, message.messageId == 0 ? messageId : message.messageId, message.messageSeqNo == 0 ? message.messageSeqNo : messageSeqNo];
}

- (NSString *)incomingMessageDescription:(MTIncomingMessage *)message
{
    return [[NSString alloc] initWithFormat:@"%@ (%" PRId64")", message.body, message.messageId];
}

- (void)transportReadyForTransaction:(MTTransport *)transport transportSpecificTransaction:(MTMessageTransaction *)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^)(NSArray *))transactionReady
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport)
        {
            if (transactionReady)
                transactionReady(nil);
        }
        else if ([self canAskForTransactions])
        {
            MTSessionInfo *transactionSessionInfo = _sessionInfo;
            
            NSMutableArray *messageTransactions = [[NSMutableArray alloc] init];
            
            if (transportSpecificTransaction != nil)
            {
                if (!(transportSpecificTransaction.requiresEncryption && _useUnauthorizedMode) && (!transportSpecificTransaction.requiresEncryption || _authInfo != nil))
                {
                    [messageTransactions addObject:transportSpecificTransaction];
                }
            }
            
            bool anyTransactionHasHighPriorityMessages = false;
            
            NSMutableArray *messageServiceTransactions = [[NSMutableArray alloc] init];
            for (id<MTMessageService> messageService in _messageServices)
            {
                if ([messageService respondsToSelector:@selector(mtProtoMessageTransaction:)])
                {
                    MTMessageTransaction *messageTransaction = [messageService mtProtoMessageTransaction:self];
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
                    
                    MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:msgsAckBuffer.data metadata:@"msgsAck"];
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
                messageSalt = [_authInfo authSaltForMessageId:[transactionSessionInfo actualClientMessagId]];
                if (messageSalt == 0)
                    saltSetEmpty = true;
            }
            
            bool transactionNeedsQuickAck = false;
            bool transactionExpectsDataInResponse = false;
            
            for (MTMessageTransaction *messageTransaction in messageTransactions)
            {
                for (MTOutgoingMessage *outgoingMessage in messageTransaction.messagePayload)
                {
                    NSData *messageData = outgoingMessage.data;
                    
                    if (outgoingMessage.dynamicDecorator != nil)
                    {
                        id decoratedData = outgoingMessage.dynamicDecorator(messageData, messageInternalIdToPreparedMessage);
                        if (decoratedData != nil)
                            messageData = decoratedData;
                    }
                    
                    NSData *data = messageData;
                    
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
                    
                    if (MTLogEnabled()) {
                        MTLog(@"[MTProto#%p preparing %@]", self, [self outgoingMessageDescription:outgoingMessage messageId:messageId messageSeqNo:messageSeqNo]);
                    }
                    
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
                        MTLog(@"[MTProto#%p client message id monotonity violated]", self);
                    }
                    
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
                            NSMutableArray *currentContainerMessages = [[NSMutableArray alloc] init];
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
                            
                            if (currentContainerMessages.count == 1)
                            {
                                int32_t quickAckId = 0;
                                NSData *messageData = [self _dataForEncryptedMessage:currentContainerMessages[0] sessionInfo:transactionSessionInfo quickAckId:&quickAckId];
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
                                NSData *containerData = [self _dataForEncryptedContainerWithMessages:currentContainerMessages sessionInfo:transactionSessionInfo quickAckId:&quickAckId];
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
                            NSData *messageData = [self _dataForPlainMessage:preparedMessage];
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
                                            MTLog(@"[MTProto#%p transport did not accept transactions with messages (%@)]", self, idsString);
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
                MTLog(@"[MTProto#%x sending time fix ping (%" PRId64 "/%" PRId32 ")]", self, timeFixMessageId, timeFixSeqNo);
            }
            
            [decryptedOs writeInt64:[_authInfo authSaltForMessageId:timeFixMessageId]]; // salt
            [decryptedOs writeInt64:_sessionInfo.sessionId];
            [decryptedOs writeInt64:timeFixMessageId];
            [decryptedOs writeInt32:timeFixSeqNo];
            
            [decryptedOs writeInt32:(int32_t)messageData.length];
            [decryptedOs writeData:messageData];
            
            NSData *decryptedData = [self paddedData:[decryptedOs currentBytes]];
            
            MTDatacenterAuthKey *effectiveAuthKey;
            if (_useTempAuthKeys) {
                NSAssert(_authInfo.tempAuthKey != nil, @"_authInfo.tempAuthKey == nil");
                effectiveAuthKey = _authInfo.tempAuthKey;
            } else {
                effectiveAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:_authInfo.authKey authKeyId:_authInfo.authKeyId];
            }
            
#if MTProtoV2
            int xValue = 0;
            NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
            [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
            [msgKeyLargeData appendData:decryptedData];
            
            NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
            NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
#else
            NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + messageData.length);
            NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
#endif
            
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
        else if (![self timeFixOrSaltsMissing] && [self bindingTempAuthKey] && [self canAskForServiceTransactions] && (_bindingTempAuthKeyContext == nil || _bindingTempAuthKeyContext.transactionId == nil))
        {
            int64_t bindingMessageId = [_sessionInfo generateClientMessageId:NULL];
            int32_t bindingSeqNo = [_sessionInfo takeSeqNo:true];
            
            int32_t expiresAt = (int32_t)([_context globalTime] + 60 * 60 * 32);
            
            int64_t randomId = 0;
            arc4random_buf(&randomId, 8);
            
            int64_t nonce = 0;
            arc4random_buf(&nonce, 8);
            
            MTBuffer *decryptedMessage = [[MTBuffer alloc] init];
            //bind_auth_key_inner#75a3f765 nonce:long temp_auth_key_id:long perm_auth_key_id:long temp_session_id:long expires_at:int = BindAuthKeyInner;
            [decryptedMessage appendInt32:(int32_t)0x75a3f765];
            [decryptedMessage appendInt64:nonce];
            [decryptedMessage appendInt64:_authInfo.authKeyId];
            [decryptedMessage appendInt64:_bindPersistentKey.authKeyId];
            [decryptedMessage appendInt64:_sessionInfo.sessionId];
            [decryptedMessage appendInt32:expiresAt];
            
            NSData *encryptedMessage = [self _manuallyEncryptedMessage:[decryptedMessage data] messageId:bindingMessageId authKey:_bindPersistentKey];
            
            MTBuffer *bindRequestData = [[MTBuffer alloc] init];
            
            //auth.bindTempAuthKey#cdd42a05 perm_auth_key_id:long nonce:long expires_at:int encrypted_message:bytes = Bool;
            
            [bindRequestData appendInt32:(int32_t)0xcdd42a05];
            [bindRequestData appendInt64:_bindPersistentKey.authKeyId];
            [bindRequestData appendInt64:nonce];
            [bindRequestData appendInt32:expiresAt];
            [bindRequestData appendTLBytes:encryptedMessage];
            
            NSData *messageData = bindRequestData.data;
            
            MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
            
            if (MTLogEnabled()) {
                MTLog(@"[MTProto#%llx sending temp key binding message (%" PRId64 "/%" PRId32 ")]", self, bindingMessageId, bindingSeqNo);
            }
            
            [decryptedOs writeInt64:[_authInfo authSaltForMessageId:bindingMessageId]];
            [decryptedOs writeInt64:_sessionInfo.sessionId];
            [decryptedOs writeInt64:bindingMessageId];
            [decryptedOs writeInt32:bindingSeqNo];
            
            [decryptedOs writeInt32:(int32_t)messageData.length];
            [decryptedOs writeData:messageData];
            
            NSData *decryptedData = [self paddedData:[decryptedOs currentBytes]];
            
#if MTProtoV2
            int xValue = 0;
            NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
            [msgKeyLargeData appendBytes:_authInfo.authKey.bytes + 88 + xValue length:32];
            [msgKeyLargeData appendData:decryptedData];
            
            NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
            NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:_authInfo.authKey messageKey:messageKey toClient:false];
#else
            NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + messageData.length);
            NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:_authInfo.authKey messageKey:messageKey toClient:false];
#endif
            
            NSData *transactionData = nil;
            
            if (encryptionKey != nil)
            {
                NSMutableData *encryptedData = [[NSMutableData alloc] initWithCapacity:14 + decryptedData.length];
                [encryptedData appendData:decryptedData];
                MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);
                
                int64_t authKeyId = _authInfo.authKeyId;
                [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
                [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];
                
                transactionData = encryptedData;
            }
            
            if (transactionReady != nil)
            {
                if (transactionData != nil)
                {
                    __weak MTProto *weakSelf = self;
                    transactionReady(@[[[MTTransportTransaction alloc] initWithPayload:transactionData completion:^(bool success, id transactionId) {
                        [[MTProto managerQueue] dispatchOnQueue:^{
                            if (success) {
                                if (transactionId != nil) {
                                    _bindingTempAuthKeyContext = [[MTBindingTempAuthKeyContext alloc] initWithMessageId:bindingMessageId messageSeqNo:bindingSeqNo transactionId:transactionId];
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
    }];
}

- (NSData *)_dataForEncryptedContainerWithMessages:(NSArray *)preparedMessages sessionInfo:(MTSessionInfo *)sessionInfo quickAckId:(int32_t *)quickAckId
{
    MTDatacenterAuthKey *effectiveAuthKey;
    if (_useTempAuthKeys) {
        NSAssert(_authInfo.tempAuthKey != nil, @"_authInfo.tempAuthKey == nil");
        effectiveAuthKey = _authInfo.tempAuthKey;
    } else {
        effectiveAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:_authInfo.authKey authKeyId:_authInfo.authKeyId];
    }
    
    NSMutableArray *containerMessageIds = [[NSMutableArray alloc] init];
    
    MTOutputStream *containerOs = [[MTOutputStream alloc] init];
    
    [containerOs writeInt32:0x73f1f8dc]; // msg_container
    [containerOs writeInt32:(int32_t)preparedMessages.count];
    
    int64_t salt = 0;
    for (MTPreparedMessage *preparedMessage in preparedMessages)
    {
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
    if (containerMessageIds.count != 0)
    {
        [sessionInfo addContainerMessageIdMapping:containerMessageId childMessageIds:containerMessageIds];
        
#ifdef DEBUG
        NSMutableString *idsString = [[NSMutableString alloc] init];
        for (NSNumber *nMessageId in containerMessageIds)
        {
            if (idsString.length != 0)
                [idsString appendString:@","];
            [idsString appendFormat:@"%lld", [nMessageId longLongValue]];
        }
        if (MTLogEnabled()) {
            MTLog(@"    container (%" PRId64 ") of (%@)", containerMessageId, idsString);
        }
#endif
    }
    
    [decryptedOs writeInt64:salt];
    [decryptedOs writeInt64:sessionInfo.sessionId];
    [decryptedOs writeInt64:containerMessageId];
    [decryptedOs writeInt32:[sessionInfo takeSeqNo:false]];
    
    [decryptedOs writeInt32:(int32_t)containerData.length];
    [decryptedOs writeData:containerData];
    
    NSData *decryptedData = [self paddedData:[decryptedOs currentBytes]];
    
#if MTProtoV2
    int xValue = 0;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
    int32_t nQuickAckId = *((int32_t *)(msgKeyLarge.bytes));
#else
    NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + containerData.length);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
    int32_t nQuickAckId = *((int32_t *)(messageKeyFull.bytes));
#endif
    
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

- (NSData *)_dataForPlainMessage:(MTPreparedMessage *)preparedMessage
{
    MTOutputStream *os = [[MTOutputStream alloc] init];
    
    [os writeInt64:0];
    [os writeInt64:preparedMessage.messageId];
    [os writeInt32:(int32_t)preparedMessage.data.length];
    [os writeData:preparedMessage.data];
    
    NSData *messageData = [os currentBytes];
    
    return messageData;
}

- (NSData *)paddedDataV1:(NSData *)data {
    NSMutableData *padded = [[NSMutableData alloc] initWithData:data];
    uint8_t randomBytes[128];
    arc4random_buf(randomBytes, 128);
    for (int i = 0; ((int)data.length + i) % 16 != 0; i++) {
        [padded appendBytes:randomBytes + i length:1];
    }
    return padded;
}

- (NSData *)paddedData:(NSData *)data {
    NSMutableData *padded = [[NSMutableData alloc] initWithData:data];
    uint8_t randomBytes[128];
    arc4random_buf(randomBytes, 128);
#if MTProtoV2
    int take = 0;
    while (take < 12) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
    
    while (padded.length % 16 != 0) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
    
    int remainingCount = arc4random_uniform(72 + 1 - take);
    while (remainingCount % 16 != 0) {
        remainingCount--;
    }
    
    for (int i = 0; i < remainingCount; i++) {
        [padded appendBytes:randomBytes + take length:1];
        take++;
    }
#else
    for (int i = 0; ((int)data.length + i) % 16 != 0; i++) {
        [padded appendBytes:randomBytes + i length:1];
    }
#endif
    return padded;
}

- (NSData *)_manuallyEncryptedMessage:(NSData *)preparedData messageId:(int64_t)messageId authKey:(MTDatacenterAuthKey *)authKey {
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
    
    NSData *decryptedData = [self paddedDataV1:[decryptedOs currentBytes]];
    
#if false && MTProtoV2
    int xValue = 0;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:authKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:authKey.authKey messageKey:messageKey toClient:false];
#else
    NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + preparedData.length);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
    
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:authKey.authKey messageKey:messageKey toClient:false];
#endif
    
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

- (NSData *)_dataForEncryptedMessage:(MTPreparedMessage *)preparedMessage sessionInfo:(MTSessionInfo *)sessionInfo quickAckId:(int32_t *)quickAckId
{
    MTDatacenterAuthKey *effectiveAuthKey;
    if (_useTempAuthKeys) {
        NSAssert(_authInfo.tempAuthKey != nil, @"_authInfo.tempAuthKey == nil");
        effectiveAuthKey = _authInfo.tempAuthKey;
    } else {
        effectiveAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:_authInfo.authKey authKeyId:_authInfo.authKeyId];
    }
    
    MTOutputStream *decryptedOs = [[MTOutputStream alloc] init];
    
    [decryptedOs writeInt64:preparedMessage.salt];
    [decryptedOs writeInt64:sessionInfo.sessionId];
    [decryptedOs writeInt64:preparedMessage.messageId];
    [decryptedOs writeInt32:preparedMessage.seqNo];
    
    [decryptedOs writeInt32:(int32_t)preparedMessage.data.length];
    [decryptedOs writeData:preparedMessage.data];
    
    NSData *decryptedData = [self paddedData:[decryptedOs currentBytes]];
    
#if MTProtoV2
    int xValue = 0;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
#else
    NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + preparedMessage.data.length);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
    
    int32_t nQuickAckId = *((int32_t *)(messageKeyFull.bytes));
    nQuickAckId = nQuickAckId & 0x7fffffff;
    if (quickAckId != NULL)
        *quickAckId = nQuickAckId;
    
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:false];
#endif
    
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
        
        if (_bindingTempAuthKeyContext != nil && _bindingTempAuthKeyContext.transactionId != nil && [transactionIds containsObject:_bindingTempAuthKeyContext.transactionId])
        {
            _bindingTempAuthKeyContext = nil;
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
    
    if (_bindingTempAuthKeyContext != nil && _bindingTempAuthKeyContext.transactionId != nil)
    {
        _bindingTempAuthKeyContext = nil;
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

- (void)transportDecodeProgressToken:(MTTransport *)transport data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id progressToken))completion
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (transport != _transport || completion == nil)
            return;
        
        MTDatacenterAuthKey *effectiveAuthKey;
        if (_useTempAuthKeys) {
            NSAssert(_authInfo.tempAuthKey != nil, @"_authInfo.tempAuthKey == nil");
            effectiveAuthKey = _authInfo.tempAuthKey;
        } else {
            effectiveAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:_authInfo.authKey authKeyId:_authInfo.authKeyId];
        }
        
        MTInputStream *is = [[MTInputStream alloc] initWithData:data];
        
        int64_t keyId = [is readInt64];
        
        if (keyId != 0 && _authInfo != nil)
        {
            NSData *messageKey = [is readData:16];
#if MTProtoV2
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:true];
#else
            MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:effectiveAuthKey.authKey messageKey:messageKey toClient:true];
#endif
            
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
                
                if (true)
                {
                    while (!stop && reqMsgId == 0)
                    {
                        int32_t signature = [messageIs readInt32:&stop];
                        [self findReqMsgId:messageIs signature:signature reqMsgId:&reqMsgId failed:&stop];
                    }
                }
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
                }
                
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

- (void)transportHasIncomingData:(MTTransport *)transport data:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult
{   
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (_transport != transport || [self isStopped])
            return;
        
        _transport.simultaneousTransactionsEnabled = true;
        
        if (data.length == 4)
        {
            int32_t protocolErrorCode = 0;
            [data getBytes:&protocolErrorCode range:NSMakeRange(0, 4)];
            
            if (MTLogEnabled()) {
                MTLog(@"[MTProto#%p protocol error %" PRId32 "", self, protocolErrorCode);
            }
            
            if (decodeResult != nil)
                decodeResult(transactionId, false);
            
            id currentTransport = _transport;
            
            [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
            
            for (NSInteger i = (NSInteger)_messageServices.count - 1; i >= 0; i--)
            {
                id<MTMessageService> messageService = _messageServices[(NSUInteger)i];
                
                if ([messageService respondsToSelector:@selector(mtProto:protocolErrorReceived:)])
                    [messageService mtProto:self protocolErrorReceived:protocolErrorCode];
            }
            
            if (protocolErrorCode == -404) {
                if (_cdn) {
                    _authInfo = nil;
                    [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:nil];
                    [_context authInfoForDatacenterWithIdRequired:_datacenterId isCdn:true];
                    _mtState |= MTProtoStateAwaitingDatacenterAuthorization;
                } else if (_useTempAuthKeys) {
                    _authInfo = [_authInfo withUpdatedTempAuthKey:nil];
                    _mtState |= MTProtoStateAwaitingDatacenterTempAuthKey;
                    [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:_authInfo];
                    [_context tempAuthKeyForDatacenterWithIdRequired:_datacenterId];
                }
            }
            
            if (currentTransport == _transport)
                [self requestSecureTransportReset];
            
            return;
        }
        
        NSData *decryptedData = nil;
        
        if (_useUnauthorizedMode)
            decryptedData = data;
        else
            decryptedData = [self _decryptIncomingTransportData:data];
        
        if (decryptedData != nil)
        {
            if (decodeResult != nil)
                decodeResult(transactionId, true);
            
            int64_t dataMessageId = 0;
            bool parseError = false;
            NSArray *parsedMessages = [self _parseIncomingMessages:decryptedData dataMessageId:&dataMessageId parseError:&parseError];
            if (parseError)
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTProto#%p incoming data parse error]", self);
                }
                
                [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
                
                [self resetSessionInfo];
            }
            else
            {
                [self transportTransactionsSucceeded:@[transactionId]];
                
                for (MTIncomingMessage *incomingMessage in parsedMessages)
                {
                    [self _processIncomingMessage:incomingMessage withTransactionId:transactionId];
                }
                
                if (requestTransactionAfterProcessing)
                    [self requestTransportTransaction];
            }
        }
        else
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTProto#%p couldn't decrypt incoming data]", self);
            }
            
            if (decodeResult != nil)
                decodeResult(transactionId, false);
            
            [self transportTransactionsMayHaveFailed:transport transactionIds:@[transactionId]];
            
            [self requestSecureTransportReset];
        }
    }];
}

- (NSData *)_decryptIncomingTransportData:(NSData *)data
{
    MTDatacenterAuthKey *effectiveAuthKey;
    if (_useTempAuthKeys) {
        NSAssert(_authInfo.tempAuthKey != nil, @"_authInfo.tempAuthKey == nil");
        effectiveAuthKey = _authInfo.tempAuthKey;
    } else {
        effectiveAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:_authInfo.authKey authKeyId:_authInfo.authKeyId];
    }
    
    if (effectiveAuthKey == nil)
        return nil;
    
    if (data.length < 24 + 36)
        return nil;
    
    int64_t authKeyId = 0;
    [data getBytes:&authKeyId range:NSMakeRange(0, 8)];
    if (authKeyId != effectiveAuthKey.authKeyId)
        return nil;
    
    NSData *embeddedMessageKey = [data subdataWithRange:NSMakeRange(8, 16)];
    
#if MTProtoV2
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:effectiveAuthKey.authKey messageKey:embeddedMessageKey toClient:true];
#else
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyForAuthKey:effectiveAuthKey.authKey messageKey:embeddedMessageKey toClient:true];
#endif
    
    if (encryptionKey == nil)
        return nil;
    
    NSData *decryptedData = MTAesDecrypt([data subdataWithRange:NSMakeRange(24, data.length - 24)], encryptionKey.key, encryptionKey.iv);
    
    int32_t messageDataLength = 0;
    [decryptedData getBytes:&messageDataLength range:NSMakeRange(28, 4)];
    
    int32_t paddingLength = ((int32_t)decryptedData.length) - messageDataLength;
    if (paddingLength < 12 || paddingLength > 1024) {
#if MTProtoV2
        __unused NSData *result = MTSha256(decryptedData);
#endif
        return nil;
    }
    
    if (messageDataLength < 0 || messageDataLength > (int32_t)decryptedData.length) {
#if MTProtoV2
        __unused NSData *result = MTSha256(decryptedData);
#endif
        return nil;
    }
    
#if MTProtoV2
    int xValue = 8;
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:effectiveAuthKey.authKey.bytes + 88 + xValue length:32];
    [msgKeyLargeData appendData:decryptedData];
    
    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
#else
    NSData *messageKeyFull = MTSubdataSha1(decryptedData, 0, 32 + messageDataLength);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
#endif
    
    if (![messageKey isEqualToData:embeddedMessageKey])
        return nil;
    
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

- (NSArray *)_parseIncomingMessages:(NSData *)data dataMessageId:(out int64_t *)dataMessageId parseError:(out bool *)parseError
{
    MTInputStream *is = [[MTInputStream alloc] initWithData:data];
    
    bool readError = false;
    
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
        
        int64_t embeddedSessionId = [is readInt64:&readError];
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
    
#warning check message id
    
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
            [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:subMessageId seqNo:subMessageSeqNo salt:embeddedSalt timestamp:timestamp size:subMessageLength body:subObject]];
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
        [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:subMessageId seqNo:subMessageSeqNo salt:embeddedSalt timestamp:timestamp size:subMessageLength body:subObject]];
    }
    else
        [messages addObject:[[MTIncomingMessage alloc] initWithMessageId:embeddedMessageId seqNo:embeddedSeqNo salt:embeddedSalt timestamp:timestamp size:topMessageSize body:topObject]];
    
    return messages;
}

- (void)_processIncomingMessage:(MTIncomingMessage *)incomingMessage withTransactionId:(id)transactionId
{
    if ([_sessionInfo messageProcessed:incomingMessage.messageId])
    {
        if (MTLogEnabled()) {
            MTLog(@"[MTProto#%p received duplicate message %" PRId64 "]", self, incomingMessage.messageId);
        }
        [_sessionInfo scheduleMessageConfirmation:incomingMessage.messageId size:incomingMessage.size];
        
        if ([_sessionInfo scheduledMessageConfirmationsExceedSize:MTMaxUnacknowledgedMessageSize orCount:MTMaxUnacknowledgedMessageCount])
            [self requestTransportTransaction];
        
        return;
    }
    
    if (MTLogEnabled()) {
        MTLog(@"[MTProto#%p received %@]", self, [self incomingMessageDescription:incomingMessage]);
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
                [self timeSyncInfoChanged:timeDifference saltList:@[[[MTDatacenterSaltInfo alloc] initWithSalt:validSalt firstValidMessageId:incomingMessage.messageId lastValidMessageId:incomingMessage.messageId + (4294967296 * 30 * 60)]]];
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
                        [self timeSyncInfoChanged:timeDifference saltList:nil];
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
        
        if (_bindingTempAuthKeyContext != nil && badMessageId == _bindingTempAuthKeyContext.messageId)
        {
            _bindingTempAuthKeyContext = nil;
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
                MTLog(@"[MTProto#%p detailed info %" PRId64 " is for %" PRId64 "", self, incomingMessage.messageId, requestMessageId);
            }
            
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
                MTLog(@"[MTProto#%p will request message %" PRId64 "", self, detailedInfoMessage.responseMessageId);
            }
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
            
            if ([messageService respondsToSelector:@selector(mtProto:receivedMessage:)])
                [messageService mtProto:self receivedMessage:incomingMessage];
        }
        
        if (_timeFixContext != nil && [incomingMessage.body isKindOfClass:[MTPongMessage class]] && ((MTPongMessage *)incomingMessage.body).messageId == _timeFixContext.messageId)
        {
            _timeFixContext = nil;
            [self completeTimeSync];
            
            if ([self canAskForTransactions] || [self canAskForServiceTransactions])
                [self requestTransportTransaction];
        }
        
        if (_bindingTempAuthKeyContext != nil && [incomingMessage.body isKindOfClass:[MTRpcResultMessage class]] && ((MTRpcResultMessage *)incomingMessage.body).requestMessageId == _bindingTempAuthKeyContext.messageId) {
            MTRpcResultMessage *rpcResultMessage = (MTRpcResultMessage *)incomingMessage.body;
            
            _bindingTempAuthKeyContext = nil;
            
            id maybeInternalMessage = [MTInternalMessageParser parseMessage:rpcResultMessage.data];
            
            id rpcResult = nil;
            MTRpcError *rpcError = nil;
            
            if ([maybeInternalMessage isKindOfClass:[MTRpcError class]])
                rpcError = maybeInternalMessage;
            else
            {
                if (rpcResultMessage.data.length == 4) {
                    int32_t signature = 0;
                    [rpcResultMessage.data getBytes:&signature range:NSMakeRange(0, 4)];
                    if (signature == (int32_t)0xbc799737) {
                        rpcResult = @true;
                    } else if (signature == (int32_t)0x997275b5) {
                        rpcResult = @false;
                    }
                }
                if (rpcResult == nil) {
                    rpcResult = @true;
                    rpcError = [[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"TL_PARSING_ERROR"];
                }
            }
            
            if ([rpcResult respondsToSelector:@selector(boolValue)] && [rpcResult boolValue]) {
                if ((_mtState & MTProtoStateBindingTempAuthKey) != 0) {
                    [self setMtState:_mtState & (~MTProtoStateBindingTempAuthKey)];
                }
                if (_bindPersistentKeyCompletion) {
                    _bindPersistentKeyCompletion();
                }
            } else {
                
            }
        }
    }
}

- (void)contextDatacenterTransportSchemeUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (context == _context && datacenterId == _datacenterId && media == _media && ![self isStopped] && (_transportScheme == nil || ![_transportScheme isEqualToScheme:transportScheme]))
        {
            if (_mtState & MTProtoStateAwaitingDatacenterScheme)
                [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterScheme)];
            
            [self resetTransport];
            [self requestTransportTransaction];
        }
    }];
}

- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo
{
    [[MTProto managerQueue] dispatchOnQueue:^
    {
        if (!_useUnauthorizedMode && context == _context && datacenterId == _datacenterId && authInfo != nil)
        {
            _authInfo = authInfo;
            
            bool wasSuspended = _mtState & (MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterTempAuthKey);
            
            if (_mtState & MTProtoStateAwaitingDatacenterAuthorization)
            {
                [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterAuthorization)];
            }
            
            if (_mtState & MTProtoStateAwaitingDatacenterTempAuthKey)
            {
                if (_authInfo.tempAuthKey != nil) {
                    [self setMtState:_mtState & (~MTProtoStateAwaitingDatacenterTempAuthKey)];
                }
            }
            
            if ((_mtState & (MTProtoStateAwaitingDatacenterAuthorization | MTProtoStateAwaitingDatacenterTempAuthKey)) == 0) {
                if (wasSuspended) {
                    [self resetTransport];
                    [self requestTransportTransaction];
                }
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

- (void)timeSyncServiceCompleted:(MTTimeSyncMessageService *)timeSyncService timeDifference:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList
{
    if ([_messageServices containsObject:timeSyncService])
    {
        [self completeTimeSync];
        [_messageServices removeObject:timeSyncService];
        
        [self timeSyncInfoChanged:timeDifference saltList:saltList];
    }
}

- (void)timeSyncInfoChanged:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList
{
    [_context setGlobalTimeDifference:timeDifference];
    
    if (saltList != nil)
    {
        MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_datacenterId];
        if (authInfo != nil)
        {
            MTDatacenterAuthInfo *updatedAuthInfo = [authInfo mergeSaltSet:saltList forTimestamp:[_context globalTime]];
            [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:updatedAuthInfo];
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

- (void)bindToPersistentKey:(MTDatacenterAuthKey *)persistentKey completion:(void (^)())completion {
    [[MTProto managerQueue] dispatchOnQueue:^{
        _bindPersistentKey = persistentKey;
        _bindPersistentKeyCompletion = [completion copy];
        _bindingTempAuthKeyContext = nil;
        _mtState |= MTProtoStateBindingTempAuthKey;
        
        [self resetTransport];
        [self requestTransportTransaction];
    }];
}

@end
